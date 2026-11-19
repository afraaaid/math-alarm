import Foundation
import SwiftUI
import UIKit
import UserNotifications

#if canImport(AlarmKit)
import ActivityKit
import AlarmKit
import AppIntents
#endif

#if canImport(AlarmKit)
@available(iOS 26.0, *)
struct SvegliaAlarmMetadata: AlarmMetadata, Codable, Hashable, Sendable {}

@available(iOS 26.0, *)
struct OpenMathChallengeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Risolvi calcolo sveglia"
    static let description = IntentDescription("Apre Sveglia per risolvere i calcoli matematici e disattivare la sveglia.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Alarm ID")
    var alarmID: String?

    init() {}

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        let parsedID = alarmID.flatMap { UUID(uuidString: $0) }
        await MainActor.run {
            if let parsedID {
                AlarmEngine.shared.activateAlarmFromSystemTrigger(alarmID: parsedID)
            } else {
                AlarmEngine.shared.checkIfAnyAlarmShouldBeRingingNow()
            }
        }
        return .result()
    }
}
#endif

@MainActor
final class AlarmEngine: ObservableObject {
    static let shared = AlarmEngine()

    static let alarmCategoryID = "SVEGLIA_ALARM_CATEGORY"
    static let openMathActionID = "OPEN_MATH_CHALLENGE"
    static let wakeUpCategoryID = "SVEGLIA_WAKEUP_CHECK_CATEGORY"
    static let wakeUpConfirmActionID = "CONFIRM_AWAKE"

    @Published var alarms: [AlarmItem] = []
    @Published private(set) var activeAlarm: AlarmItem?
    @Published private(set) var currentProblems: [MathProblem] = []
    @Published private(set) var solvedCount: Int = 0
    @Published var userInput: String = ""
    @Published var wrongAnswerAttempts: Int = 0
    @Published var lastWrongBanner: Bool = false

    @Published private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var alarmKitAvailable: Bool = false
    @Published private(set) var alarmKitAuthorized: Bool = false
    @Published private(set) var alarmKitStatusText: String = "Verifica..."
    @Published private(set) var wakeUpCheckPendingUntil: Date?

    var isRinging: Bool {
        activeAlarm != nil
    }

    var currentProblem: MathProblem? {
        guard currentProblems.indices.contains(solvedCount) else { return nil }
        return currentProblems[solvedCount]
    }

    private let defaults = UserDefaults.standard
    private let alarmsKey = "sveglia.alarms.v1"
    private let activeAlarmIDKey = "sveglia.activeAlarmID.v1"
    private let solvedCountKey = "sveglia.solvedCount.v1"
    private let alarmKitIDsKey = "sveglia.alarmKitIDs.v1"
    private let completedSlotsKey = "sveglia.completedSlots.v1"
    private let wakeUpAlarmIDKey = "sveglia.wakeUpAlarmID.v1"
    private let wakeUpDeadlineKey = "sveglia.wakeUpDeadline.v1"

    private var foregroundCheckTimer: Timer?
    private var completedSlotTimestamps: [String: TimeInterval] = [:]

    private init() {
        loadState()
        registerNotificationCategories()
        refreshPermissionStatuses()
        restoreActiveRingingIfNeeded()
        startForegroundMonitor()
    }

    // MARK: - Setup & Permissions

    func requestAllPermissions() async {
        let center = UNUserNotificationCenter.current()
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            _ = try await center.requestAuthorization(options: options)
        } catch {
            print("Errore autorizzazione notifiche: \(error)")
        }

        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            alarmKitAvailable = true
            do {
                let state = try await AlarmManager.shared.requestAuthorization()
                alarmKitAuthorized = (state == .authorized)
                alarmKitStatusText = statusLabel(for: state)
            } catch {
                alarmKitAuthorized = false
                alarmKitStatusText = "Errore AlarmKit: \(error.localizedDescription)"
            }
        } else {
            alarmKitAvailable = false
            alarmKitStatusText = "Richiede iOS 26+ (attiva Catena Hydra)"
        }
        #else
        alarmKitAvailable = false
        alarmKitStatusText = "SDK iOS < 26 (attiva Catena Hydra)"
        #endif

        refreshPermissionStatuses()
        await rescheduleAllAsync()
    }

    func refreshPermissionStatuses() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let status = settings.authorizationStatus
            Task { @MainActor [weak self] in
                self?.notificationStatus = status
            }
        }

        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            alarmKitAvailable = true
            let state = AlarmManager.shared.authorizationState
            alarmKitAuthorized = (state == .authorized)
            alarmKitStatusText = statusLabel(for: state)
        } else {
            alarmKitAvailable = false
            alarmKitStatusText = "Richiede iOS 26+ (attiva Catena Hydra)"
        }
        #else
        alarmKitAvailable = false
        alarmKitStatusText = "SDK < 26 (attiva Catena Hydra)"
        #endif
    }

    #if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private func statusLabel(for state: AlarmManager.AuthorizationState) -> String {
        switch state {
        case .authorized:
            return "AlarmKit Attivo (0% Batteria)"
        case .denied:
            return "AlarmKit Negato (usa Catena Hydra)"
        case .notDetermined:
            return "Da autorizzare"
        @unknown default:
            return "Stato sconosciuto"
        }
    }
    #endif

    // MARK: - CRUD Sveglie

    func upsertAlarm(_ alarm: AlarmItem) {
        if let idx = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[idx] = alarm
        } else {
            alarms.append(alarm)
        }
        sortAlarms()
        saveAlarms()
        rescheduleAll()
    }

    func toggleAlarm(id: UUID, isEnabled: Bool) {
        guard let idx = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[idx].isEnabled = isEnabled
        saveAlarms()
        rescheduleAll()
    }

    func deleteAlarms(at offsets: IndexSet) {
        alarms.remove(atOffsets: offsets)
        saveAlarms()
        rescheduleAll()
    }

    func deleteAlarm(id: UUID) {
        alarms.removeAll { $0.id == id }
        saveAlarms()
        rescheduleAll()
    }

    func nextScheduledSummary() -> (alarm: AlarmItem, date: Date)? {
        let now = Date()
        return alarms
            .filter(\.isEnabled)
            .compactMap { alarm -> (AlarmItem, Date)? in
                guard let next = alarm.nextTriggerDate(from: now) else { return nil }
                return (alarm, next)
            }
            .min { $0.1 < $1.1 }
    }

    // MARK: - Trigger & Blocco Matematico

    func triggerTestAlarm(_ alarm: AlarmItem) {
        startRinging(alarm: alarm, persistAsActive: true)
    }

    func activateAlarmFromSystemTrigger(alarmID: UUID) {
        if let active = activeAlarm, active.id == alarmID {
            ensureSirenAndGuardActive(for: active)
            return
        }
        if let found = alarms.first(where: { $0.id == alarmID }) {
            startRinging(alarm: found, persistAsActive: true)
        } else if let firstEnabled = alarms.first(where: \.isEnabled) ?? alarms.first {
            startRinging(alarm: firstEnabled, persistAsActive: true)
        }
    }

    func checkIfAnyAlarmShouldBeRingingNow() {
        guard !isRinging else {
            if let active = activeAlarm {
                ensureSirenAndGuardActive(for: active)
            }
            return
        }

        // Controllo se è scaduto un controllo post-sveglia
        if let pendingAlarmIDString = defaults.string(forKey: wakeUpAlarmIDKey),
           let pendingAlarmID = UUID(uuidString: pendingAlarmIDString) {
            let deadline = defaults.double(forKey: wakeUpDeadlineKey)
            if deadline > 0 && Date().timeIntervalSince1970 >= deadline {
                clearWakeUpCheck()
                if let alarm = alarms.first(where: { $0.id == pendingAlarmID }) ?? alarms.first {
                    startRinging(alarm: alarm, persistAsActive: true)
                    return
                }
            }
        }

        let now = Date()
        let calendar = Calendar.current
        // Verifica se una sveglia abilitata doveva suonare negli ultimi 15 minuti
        // e non è ancora stata completata per questo minuto specifico.
        for alarm in alarms where alarm.isEnabled {
            for minutesAgo in 0...15 {
                guard let checkDate = calendar.date(byAdding: .minute, value: -minutesAgo, to: now) else {
                    continue
                }
                let hour = calendar.component(.hour, from: checkDate)
                let minute = calendar.component(.minute, from: checkDate)
                guard hour == alarm.hour && minute == alarm.minute else { continue }

                if !alarm.repeatDays.isEmpty {
                    let calWeekday = calendar.component(.weekday, from: checkDate)
                    let iso = AlarmItem.isoWeekday(from: calWeekday)
                    guard alarm.repeatDays.contains(iso) else { continue }
                }

                let slotKey = makeSlotKey(alarmID: alarm.id, date: checkDate)
                if completedSlotTimestamps[slotKey] == nil {
                    startRinging(alarm: alarm, persistAsActive: true)
                    return
                }
            }
        }
    }

    func appendDigit(_ digit: String) {
        guard isRinging, let alarm = activeAlarm else { return }
        if userInput.count >= 6 { return }
        userInput.append(digit)
        lastWrongBanner = false

        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()

        AudioSirenService.shared.registerTypingActivity(smartQuietEnabled: alarm.smartQuietWhileTyping)
    }

    func deleteLastDigit() {
        guard isRinging, let alarm = activeAlarm else { return }
        if !userInput.isEmpty {
            userInput.removeLast()
            let haptic = UIImpactFeedbackGenerator(style: .soft)
            haptic.impactOccurred()
        }
        AudioSirenService.shared.registerTypingActivity(smartQuietEnabled: alarm.smartQuietWhileTyping)
    }

    func clearInput() {
        userInput = ""
    }

    func submitAnswer() {
        guard isRinging, let problem = currentProblem, let alarm = activeAlarm else { return }

        AudioSirenService.shared.registerTypingActivity(smartQuietEnabled: alarm.smartQuietWhileTyping)

        guard let typedValue = Int(userInput), typedValue == problem.answer else {
            // Risposta sbagliata: feedback negativo, rigenera se troppi errori, reset input
            wrongAnswerAttempts += 1
            lastWrongBanner = true
            userInput = ""
            let notif = UINotificationFeedbackGenerator()
            notif.notificationOccurred(.error)
            return
        }

        // Risposta corretta!
        let notif = UINotificationFeedbackGenerator()
        notif.notificationOccurred(.success)
        lastWrongBanner = false
        userInput = ""
        solvedCount += 1
        defaults.set(solvedCount, forKey: solvedCountKey)

        if solvedCount >= currentProblems.count {
            completeMathChallenge()
        }
    }

    func confirmWakeUpCheck() {
        clearWakeUpCheck()
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["wakeup_check_prompt", "wakeup_check_failsafe"]
        )
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: ["wakeup_check_prompt", "wakeup_check_failsafe"]
        )
        let notif = UINotificationFeedbackGenerator()
        notif.notificationOccurred(.success)
    }

    // MARK: - Anti-Chiusura / Background Protection

    func handleMovedToBackgroundWhileRinging() {
        guard let alarm = activeAlarm else { return }
        // Continua l'audio in background e forza volume massimo
        if alarm.lockVolume {
            VolumeGuard.shared.startGuarding()
        }
        // Invia notifiche immediate per richiamare l'utente dentro l'app
        scheduleImmediateExitNudge(for: alarm)
    }

    func handleReturnedToForeground() {
        refreshPermissionStatuses()
        if let active = activeAlarm {
            ensureSirenAndGuardActive(for: active)
        } else {
            checkIfAnyAlarmShouldBeRingingNow()
        }
    }

    func handleWillTerminateWhileRinging() {
        guard let alarm = activeAlarm else { return }
        // Se l'utente fa swipe-up per killare l'app mentre suona,
        // accoda una raffica di emergenza immediata a 3s, 32s, 61s...
        let center = UNUserNotificationCenter.current()
        for idx in 0..<8 {
            let content = makeAlarmNotificationContent(
                for: alarm,
                title: "SVEGLIA NON SPENTA!",
                body: "Hai chiuso l'app prima di risolvere i calcoli. Riapri per spegnere la sirena."
            )
            let delay = TimeInterval(3 + idx * 29)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let request = UNNotificationRequest(
                identifier: "emergency_kill_\(idx)_\(UUID().uuidString)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    // MARK: - Private Ringing Lifecycle

    private func startRinging(alarm: AlarmItem, persistAsActive: Bool) {
        activeAlarm = alarm
        currentProblems = MathGenerator.generateBatch(difficulty: alarm.difficulty, count: alarm.problemCount)
        solvedCount = 0
        userInput = ""
        wrongAnswerAttempts = 0
        lastWrongBanner = false

        if persistAsActive {
            defaults.set(alarm.id.uuidString, forKey: activeAlarmIDKey)
            defaults.set(0, forKey: solvedCountKey)
        }

        ensureSirenAndGuardActive(for: alarm)
    }

    private func ensureSirenAndGuardActive(for alarm: AlarmItem) {
        UIApplication.shared.isIdleTimerDisabled = true
        if !AudioSirenService.shared.isPlaying {
            AudioSirenService.shared.startSiren(sound: alarm.sound, fadeIn: alarm.fadeIn)
        }
        if alarm.lockVolume {
            VolumeGuard.shared.startGuarding()
        }
    }

    private func completeMathChallenge() {
        let finishedAlarm = activeAlarm
        AudioSirenService.shared.stopSiren()
        VolumeGuard.shared.stopGuarding()
        UIApplication.shared.isIdleTimerDisabled = false

        if let finishedAlarm {
            let slotKey = makeSlotKey(alarmID: finishedAlarm.id, date: Date())
            completedSlotTimestamps[slotKey] = Date().timeIntervalSince1970
            pruneOldCompletedSlots()
            saveCompletedSlots()

            if finishedAlarm.repeatDays.isEmpty,
               let idx = alarms.firstIndex(where: { $0.id == finishedAlarm.id }) {
                alarms[idx].isEnabled = false
                saveAlarms()
            }

            if finishedAlarm.wakeUpCheckEnabled {
                scheduleWakeUpCheck(for: finishedAlarm)
            }
        }

        activeAlarm = nil
        currentProblems = []
        solvedCount = 0
        userInput = ""
        lastWrongBanner = false

        defaults.removeObject(forKey: activeAlarmIDKey)
        defaults.removeObject(forKey: solvedCountKey)

        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        rescheduleAll()
    }

    private func restoreActiveRingingIfNeeded() {
        guard let idStr = defaults.string(forKey: activeAlarmIDKey),
              let alarmID = UUID(uuidString: idStr) else {
            checkIfAnyAlarmShouldBeRingingNow()
            return
        }

        let targetAlarm = alarms.first(where: { $0.id == alarmID })
            ?? AlarmItem(id: alarmID, label: "Sveglia Attiva")
        let savedSolved = defaults.integer(forKey: solvedCountKey)
        let remainingCount = max(1, targetAlarm.problemCount - savedSolved)

        activeAlarm = targetAlarm
        currentProblems = MathGenerator.generateBatch(difficulty: targetAlarm.difficulty, count: remainingCount)
        solvedCount = 0
        userInput = ""
        ensureSirenAndGuardActive(for: targetAlarm)
    }

    // MARK: - Scheduling Dual-Engine (AlarmKit + Hydra)

    func rescheduleAll() {
        Task {
            await rescheduleAllAsync()
        }
    }

    func rescheduleAllAsync() async {
        let center = UNUserNotificationCenter.current()
        // Rimuovi le sveglie/raffiche precedenti lasciando eventuale wake-up check attivo
        let pending = await center.pendingNotificationRequests()
        let toRemove = pending
            .map(\.identifier)
            .filter { $0 != "wakeup_check_prompt" && $0 != "wakeup_check_failsafe" }
        center.removePendingNotificationRequests(withIdentifiers: toRemove)

        await cancelPreviousAlarmKitAlarms()

        let enabledAlarms = alarms.filter(\.isEnabled)
        guard !enabledAlarms.isEmpty else { return }

        // 1. Engine AlarmKit (iOS 26/27+: 0% batteria, buca Silenzioso & Focus)
        await scheduleAlarmKitAlarms(for: enabledAlarms)

        // 2. Engine Catena Hydra UNUserNotificationCenter (garantisce continuità anche se app chiusa/killata)
        await scheduleHydraNotifications(for: enabledAlarms, center: center)
    }

    private func scheduleAlarmKitAlarms(for enabledAlarms: [AlarmItem]) async {
        #if canImport(AlarmKit)
        guard #available(iOS 26.0, *) else { return }
        guard AlarmManager.shared.authorizationState == .authorized else { return }

        var newAlarmKitIDs: [String] = []

        for alarm in enabledAlarms {
            let kitID = UUID()
            let relativeTime = Alarm.Schedule.Relative.Time(hour: alarm.hour, minute: alarm.minute)
            let recurrence: Alarm.Schedule.Relative.Recurrence
            if alarm.repeatDays.isEmpty {
                recurrence = .never
            } else {
                let weekdays = alarm.repeatDays.compactMap { Self.localeWeekday(from: $0) }
                recurrence = weekdays.isEmpty ? .never : .weekly(weekdays)
            }
            let schedule = Alarm.Schedule.relative(.init(time: relativeTime, repeats: recurrence))

            let alertPresentation = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: "\(alarm.label) • Risolvi \(alarm.problemCount) calcoli"),
                secondaryButton: AlarmButton(
                    text: LocalizedStringResource(stringLiteral: "Risolvi Calcolo"),
                    textColor: .white,
                    systemImageName: "function"
                ),
                secondaryButtonBehavior: .custom
            )
            let attributes = AlarmAttributes<SvegliaAlarmMetadata>(
                presentation: AlarmPresentation(alert: alertPresentation),
                metadata: SvegliaAlarmMetadata(),
                tintColor: .orange
            )
            let intent = OpenMathChallengeIntent(alarmID: alarm.id.uuidString)
            let configuration = AlarmManager.AlarmConfiguration<SvegliaAlarmMetadata>.alarm(
                schedule: schedule,
                attributes: attributes,
                stopIntent: intent,
                secondaryIntent: intent,
                sound: .named(alarm.sound.fileName)
            )

            do {
                _ = try await AlarmManager.shared.schedule(id: kitID, configuration: configuration)
                newAlarmKitIDs.append(kitID.uuidString)
            } catch {
                alarmKitStatusText = "Fallback Catena Hydra (\(error.localizedDescription))"
            }
        }

        // Aggiunge 4 sveglie AlarmKit di backup scaglionate (+30s, +60s, +90s, +120s)
        // sulla prossima sveglia imminente: se si preme Stop senza aprire l'app, risuona!
        if let next = nextScheduledSummary() {
            for step in 1...4 {
                let backupID = UUID()
                let fireDate = next.date.addingTimeInterval(TimeInterval(step * 30))
                let alertPresentation = AlarmPresentation.Alert(
                    title: LocalizedStringResource(stringLiteral: "\(next.alarm.label) • SVEGLIA ATTIVA"),
                    secondaryButton: AlarmButton(
                        text: LocalizedStringResource(stringLiteral: "Apri Calcoli"),
                        textColor: .white,
                        systemImageName: "function"
                    ),
                    secondaryButtonBehavior: .custom
                )
                let attributes = AlarmAttributes<SvegliaAlarmMetadata>(
                    presentation: AlarmPresentation(alert: alertPresentation),
                    metadata: SvegliaAlarmMetadata(),
                    tintColor: .red
                )
                let intent = OpenMathChallengeIntent(alarmID: next.alarm.id.uuidString)
                let configuration = AlarmManager.AlarmConfiguration<SvegliaAlarmMetadata>.alarm(
                    schedule: .fixed(fireDate),
                    attributes: attributes,
                    stopIntent: intent,
                    secondaryIntent: intent,
                    sound: .named(next.alarm.sound.fileName)
                )
                if (try? await AlarmManager.shared.schedule(id: backupID, configuration: configuration)) != nil {
                    newAlarmKitIDs.append(backupID.uuidString)
                }
            }
        }

        defaults.set(newAlarmKitIDs, forKey: alarmKitIDsKey)
        #endif
    }

    private func cancelPreviousAlarmKitAlarms() async {
        #if canImport(AlarmKit)
        guard #available(iOS 26.0, *) else { return }
        let saved = defaults.stringArray(forKey: alarmKitIDsKey) ?? []
        for idStr in saved {
            if let uuid = UUID(uuidString: idStr) {
                try? AlarmManager.shared.stop(id: uuid)
                try? AlarmManager.shared.cancel(id: uuid)
            }
        }
        defaults.removeObject(forKey: alarmKitIDsKey)
        #endif
    }

    private func scheduleHydraNotifications(
        for enabledAlarms: [AlarmItem],
        center: UNUserNotificationCenter
    ) async {
        let now = Date()
        let nextPair = nextScheduledSummary()
        let calendar = Calendar.current

        // Budget massimo iOS = 64 notifiche locali. Teniamo un margine sicuro (max 52).
        var secondaryCount = 0
        for alarm in enabledAlarms where alarm.id != nextPair?.alarm.id {
            guard let fireDate = alarm.nextTriggerDate(from: now) else { continue }
            let content = makeAlarmNotificationContent(
                for: alarm,
                title: "⏰ \(alarm.label)",
                body: "Tocca per risolvere \(alarm.problemCount) calcoli (\(alarm.difficulty.title))."
            )
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let req = UNNotificationRequest(
                identifier: "alarm_secondary_\(alarm.id.uuidString)",
                content: content,
                trigger: trigger
            )
            try? await center.add(req)
            secondaryCount += 1
        }

        guard let nearest = nextPair else { return }
        let hydraSlots = max(1, min(42, 52 - secondaryCount))

        for index in 0..<hydraSlots {
            let fireDate = nearest.date.addingTimeInterval(TimeInterval(index * 29))
            let title = index == 0
                ? "⏰ \(nearest.alarm.label) (\(nearest.alarm.formattedTime))"
                : "🔥 SVEGLIA ATTIVA • Tentativo #\(index + 1)"
            let body = "Risolvi \(nearest.alarm.problemCount) calcoli (\(nearest.alarm.difficulty.title)) per disattivare."

            let content = makeAlarmNotificationContent(for: nearest.alarm, title: title, body: body)
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let req = UNNotificationRequest(
                identifier: "hydra_\(nearest.alarm.id.uuidString)_\(index)",
                content: content,
                trigger: trigger
            )
            try? await center.add(req)
        }
    }

    private func scheduleImmediateExitNudge(for alarm: AlarmItem) {
        let center = UNUserNotificationCenter.current()
        for (idx, delay) in [2.0, 7.0, 14.0].enumerated() {
            let content = makeAlarmNotificationContent(
                for: alarm,
                title: "⚠️ SVEGLIA IN CORSO",
                body: "Torna dentro Sveglia e risolvi i calcoli rimanenti!"
            )
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let req = UNNotificationRequest(
                identifier: "exit_nudge_\(idx)",
                content: content,
                trigger: trigger
            )
            center.add(req)
        }
    }

    private func scheduleWakeUpCheck(for alarm: AlarmItem) {
        let center = UNUserNotificationCenter.current()
        let promptDelay: TimeInterval = 5 * 60
        let failSafeDelay: TimeInterval = 6 * 60

        let promptContent = UNMutableNotificationContent()
        promptContent.title = "👀 Controllo Sveglio"
        promptContent.body = "Conferma entro 1 minuto che non ti sei riaddormentato, oppure la sveglia ripartirà!"
        promptContent.sound = UNNotificationSound(named: UNNotificationSoundName(alarm.sound.fileName))
        promptContent.interruptionLevel = .timeSensitive
        promptContent.categoryIdentifier = Self.wakeUpCategoryID
        promptContent.userInfo = ["alarmID": alarm.id.uuidString, "kind": "wakeup_prompt"]

        let promptReq = UNNotificationRequest(
            identifier: "wakeup_check_prompt",
            content: promptContent,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: promptDelay, repeats: false)
        )

        let failsafeContent = makeAlarmNotificationContent(
            for: alarm,
            title: "🚨 CONTROLLO FALLITO • SVEGLIA RIATTIVATA!",
            body: "Non hai confermato in tempo. Risolvi nuovi calcoli per spegnere!"
        )
        let failsafeReq = UNNotificationRequest(
            identifier: "wakeup_check_failsafe",
            content: failsafeContent,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: failSafeDelay, repeats: false)
        )

        center.add(promptReq)
        center.add(failsafeReq)

        let deadline = Date().addingTimeInterval(failSafeDelay)
        wakeUpCheckPendingUntil = deadline
        defaults.set(alarm.id.uuidString, forKey: wakeUpAlarmIDKey)
        defaults.set(deadline.timeIntervalSince1970, forKey: wakeUpDeadlineKey)
    }

    private func clearWakeUpCheck() {
        wakeUpCheckPendingUntil = nil
        defaults.removeObject(forKey: wakeUpAlarmIDKey)
        defaults.removeObject(forKey: wakeUpDeadlineKey)
    }

    private func makeAlarmNotificationContent(
        for alarm: AlarmItem,
        title: String,
        body: String
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound(named: UNNotificationSoundName(alarm.sound.fileName))
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = Self.alarmCategoryID
        content.userInfo = ["alarmID": alarm.id.uuidString]
        return content
    }

    private func registerNotificationCategories() {
        let solveAction = UNNotificationAction(
            identifier: Self.openMathActionID,
            title: "Risolvi Calcolo",
            options: [.foreground]
        )
        let alarmCategory = UNNotificationCategory(
            identifier: Self.alarmCategoryID,
            actions: [solveAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let confirmAwakeAction = UNNotificationAction(
            identifier: Self.wakeUpConfirmActionID,
            title: "Sono Sveglio!",
            options: [.foreground]
        )
        let wakeUpCategory = UNNotificationCategory(
            identifier: Self.wakeUpCategoryID,
            actions: [confirmAwakeAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([alarmCategory, wakeUpCategory])
    }

    // MARK: - Foreground Monitor

    private func startForegroundMonitor() {
        foregroundCheckTimer?.invalidate()
        foregroundCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForegroundSecondTick()
            }
        }
    }

    private func checkForegroundSecondTick() {
        guard !isRinging else { return }

        if let deadline = wakeUpCheckPendingUntil, Date() >= deadline {
            checkIfAnyAlarmShouldBeRingingNow()
            return
        }

        let now = Date()
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let second = cal.component(.second, from: now)
        guard second <= 2 else { return }

        let isoWeekday = AlarmItem.isoWeekday(from: cal.component(.weekday, from: now))
        for alarm in alarms where alarm.isEnabled && alarm.hour == hour && alarm.minute == minute {
            if !alarm.repeatDays.isEmpty && !alarm.repeatDays.contains(isoWeekday) {
                continue
            }
            let key = makeSlotKey(alarmID: alarm.id, date: now)
            if completedSlotTimestamps[key] == nil {
                startRinging(alarm: alarm, persistAsActive: true)
                return
            }
        }
    }

    // MARK: - Helpers & Persistence

    private func loadState() {
        if let data = defaults.data(forKey: alarmsKey),
           let decoded = try? JSONDecoder().decode([AlarmItem].self, from: data) {
            alarms = decoded
        } else {
            alarms = AlarmItem.defaultSamples
            saveAlarms()
        }
        sortAlarms()

        if let savedSlots = defaults.dictionary(forKey: completedSlotsKey) as? [String: TimeInterval] {
            completedSlotTimestamps = savedSlots
            pruneOldCompletedSlots()
        }

        let wakeDeadline = defaults.double(forKey: wakeUpDeadlineKey)
        if wakeDeadline > Date().timeIntervalSince1970 {
            wakeUpCheckPendingUntil = Date(timeIntervalSince1970: wakeDeadline)
        } else if wakeDeadline > 0 {
            // Se scaduto mentre l'app era chiusa verrà gestito in checkIfAnyAlarmShouldBeRingingNow
        }
    }

    private func saveAlarms() {
        if let data = try? JSONEncoder().encode(alarms) {
            defaults.set(data, forKey: alarmsKey)
        }
    }

    private func sortAlarms() {
        alarms.sort {
            ($0.hour * 60 + $0.minute) < ($1.hour * 60 + $1.minute)
        }
    }

    private func makeSlotKey(alarmID: UUID, date: Date) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        let h = cal.component(.hour, from: date)
        let min = cal.component(.minute, from: date)
        return "\(alarmID.uuidString)_\(y)-\(m)-\(d)_\(h):\(min)"
    }

    private func pruneOldCompletedSlots() {
        let cutoff = Date().timeIntervalSince1970 - 3600
        completedSlotTimestamps = completedSlotTimestamps.filter { $0.value >= cutoff }
    }

    private func saveCompletedSlots() {
        defaults.set(completedSlotTimestamps, forKey: completedSlotsKey)
    }

    #if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private static func localeWeekday(from isoDay: Int) -> Locale.Weekday? {
        switch isoDay {
        case 1: return .monday
        case 2: return .tuesday
        case 3: return .wednesday
        case 4: return .thursday
        case 5: return .friday
        case 6: return .saturday
        case 7: return .sunday
        default: return nil
        }
    }
    #endif
}
