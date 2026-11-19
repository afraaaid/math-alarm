import SwiftUI
import UIKit
import UserNotifications

struct PracticeAndSettingsView: View {
    @EnvironmentObject private var engine: AlarmEngine

    @State private var practiceDifficulty: MathDifficulty = .medium
    @State private var problem: MathProblem = MathGenerator.generate(difficulty: .medium)
    @State private var practiceInput: String = ""
    @State private var streak: Int = 0
    @State private var feedbackMessage: String?
    @State private var feedbackSuccess: Bool = false
    @FocusState private var isPracticeFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        practiceCard
                        systemStatusCard
                        shortcutsGuideCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Sistema & Allenamento")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var practiceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Allenamento Silenzioso", systemImage: "brain.head.profile")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("Serie: \(streak)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(red: 1.0, green: 0.45, blue: 0.18).opacity(0.2))
                    .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.18))
                    .clipShape(Capsule())
            }

            Picker("Difficoltà", selection: $practiceDifficulty) {
                ForEach(MathDifficulty.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: practiceDifficulty) { _, newValue in
                loadNewPracticeProblem(difficulty: newValue)
            }

            VStack(spacing: 10) {
                Text(problem.expression)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                HStack(spacing: 10) {
                    TextField("Risultato", text: $practiceInput)
                        .keyboardType(.numberPad)
                        .focused($isPracticeFieldFocused)
                        .font(.title3.monospacedDigit().weight(.bold))
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button("Verifica") {
                        isPracticeFieldFocused = false
                        checkPracticeAnswer()
                    }
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)
                    .background(Color(red: 1.0, green: 0.45, blue: 0.18))
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if let feedbackMessage {
                    Text(feedbackMessage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(feedbackSuccess ? Color(red: 0.22, green: 0.88, blue: 0.50) : .red)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(16)
        .background(cardBackground)
    }

    private var systemStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stato Motore Sveglia (iOS 27)")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            statusRow(
                title: "AlarmKit Nativo",
                value: engine.alarmKitStatusText,
                ok: engine.alarmKitAuthorized
            )
            Divider().overlay(Color.white.opacity(0.08))

            statusRow(
                title: "Notifiche Catena Hydra",
                value: notificationStatusLabel,
                ok: engine.notificationStatus == .authorized
            )
            Divider().overlay(Color.white.opacity(0.08))

            statusRow(
                title: "Sirena Background & VolumeGuard",
                value: "Pronto (UIBackgroundModes audio)",
                ok: true
            )

            HStack(spacing: 10) {
                Button {
                    Task {
                        await engine.requestAllPermissions()
                    }
                } label: {
                    Text("Aggiorna Permessi")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.white.opacity(0.11))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button {
                    let target = engine.alarms.first(where: \.isEnabled) ?? engine.alarms.first ?? AlarmItem()
                    engine.triggerTestAlarm(target)
                } label: {
                    Text("Simula Blocco Ora")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color(red: 1.0, green: 0.45, blue: 0.18))
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.top, 4)

            if engine.notificationStatus == .denied {
                Button("Apri Impostazioni iOS") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.18))
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var shortcutsGuideCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Blocco Hardware Totale (Opzionale iOS 27)", systemImage: "iphone.gen3.radiowaves.left.and.right")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Text("iOS non consente alle app di disabilitare il tasto di accensione o lo swipe-up dallo switcher a livello sistema. Con una semplice Automazione nell'app Comandi Rapidi puoi rendere il blocco 100% fisico:")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.70))

            VStack(alignment: .leading, spacing: 6) {
                guideStep("1.", "Apri Comandi Rapidi → Automazione → Crea Automazione Personale → Ora del giorno (es. 07:00) → Esegui immediatamente.")
                guideStep("2.", "Aggiungi azione \"Imposta volume multimediale\" al 100%.")
                guideStep("3.", "Aggiungi azione \"Apri app\" selezionando Sveglia.")
                guideStep("4.", "Opzionale: aggiungi \"Avvia Accesso Guidato\" (Impostazioni → Accessibilità) per bloccare anche lo swipe verso la Home finché non inserisci il PIN.")
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .background(cardBackground)
    }

    private func guideStep(_ num: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(num)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.18))
            Text(text)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.84))
        }
    }

    private func statusRow(title: String, value: String, ok: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ok ? Color(red: 0.22, green: 0.88, blue: 0.50) : .yellow)
        }
    }

    private var notificationStatusLabel: String {
        switch engine.notificationStatus {
        case .authorized: return "Autorizzate (Time-Sensitive attive)"
        case .provisional: return "Provvisorie"
        case .denied: return "Negate nelle Impostazioni iOS"
        case .notDetermined: return "Non ancora richieste"
        case .ephemeral: return "Temporanee"
        @unknown default: return "Sconosciuto"
        }
    }

    private func checkPracticeAnswer() {
        if let val = Int(practiceInput.trimmingCharacters(in: .whitespacesAndNewlines)),
           val == problem.answer {
            streak += 1
            feedbackSuccess = true
            feedbackMessage = "Esatto! (\(problem.expression) = \(problem.answer))"
            loadNewPracticeProblem(difficulty: practiceDifficulty, keepFeedback: true)
        } else {
            streak = 0
            feedbackSuccess = false
            feedbackMessage = "Sbagliato, riprova!"
            practiceInput = ""
        }
    }

    private func loadNewPracticeProblem(difficulty: MathDifficulty, keepFeedback: Bool = false) {
        problem = MathGenerator.generate(difficulty: difficulty)
        practiceInput = ""
        if !keepFeedback {
            feedbackMessage = nil
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(red: 0.08, green: 0.09, blue: 0.11))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.09), lineWidth: 1)
            )
    }
}
