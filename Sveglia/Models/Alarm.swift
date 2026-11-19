import Foundation
import SwiftUI

enum MathDifficulty: String, Codable, CaseIterable, Identifiable, Sendable {
    case easy
    case medium
    case hard
    case extreme

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: return "Facile"
        case .medium: return "Medio"
        case .hard: return "Difficile"
        case .extreme: return "Estremo"
        }
    }

    var subtitle: String {
        switch self {
        case .easy: return "Addizioni e sottrazioni a 2 cifre"
        case .medium: return "Moltiplicazioni con somme o sottrazioni"
        case .hard: return "Espressioni combinate a 3 termini"
        case .extreme: return "Doppie moltiplicazioni e differenze"
        }
    }

    var sampleExpression: String {
        switch self {
        case .easy: return "27 + 48"
        case .medium: return "(14 × 6) - 19"
        case .hard: return "(23 × 8) + 67 - 39"
        case .extreme: return "(34 × 12) - (16 × 7) + 45"
        }
    }

    var accentColor: Color {
        switch self {
        case .easy: return Color(red: 0.20, green: 0.84, blue: 0.48)
        case .medium: return Color(red: 1.00, green: 0.72, blue: 0.18)
        case .hard: return Color(red: 1.00, green: 0.42, blue: 0.18)
        case .extreme: return Color(red: 1.00, green: 0.22, blue: 0.28)
        }
    }
}

enum AlarmSound: String, Codable, CaseIterable, Identifiable, Sendable {
    case radar
    case digital
    case extreme
    case gentle

    var id: String { rawValue }

    var baseName: String {
        switch self {
        case .radar: return "alarm_radar"
        case .digital: return "alarm_digital"
        case .extreme: return "alarm_extreme"
        case .gentle: return "alarm_gentle"
        }
    }

    var fileName: String {
        "\(baseName).wav"
    }

    var displayName: String {
        switch self {
        case .radar: return "Radar Pro"
        case .digital: return "Sirena Digitale"
        case .extreme: return "Allarme Estremo"
        case .gentle: return "Armonia Progressiva"
        }
    }

    var subtitle: String {
        switch self {
        case .radar: return "Impulsi netti ad alta penetrazione"
        case .digital: return "Doppio tono sveglia classica ad alto contrasto"
        case .extreme: return "Sirena modulata anti-sonno pesante"
        case .gentle: return "Accordo crescente nei primi secondi"
        }
    }
}

struct AlarmItem: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var hour: Int
    var minute: Int
    var label: String
    var isEnabled: Bool
    /// 1 = Lunedì ... 7 = Domenica
    var repeatDays: Set<Int>
    var difficulty: MathDifficulty
    var problemCount: Int
    var sound: AlarmSound
    var lockVolume: Bool
    var smartQuietWhileTyping: Bool
    var fadeIn: Bool
    var wakeUpCheckEnabled: Bool
    var snoozeEnabled: Bool

    init(
        id: UUID = UUID(),
        hour: Int = 7,
        minute: Int = 0,
        label: String = "Sveglia",
        isEnabled: Bool = true,
        repeatDays: Set<Int> = [],
        difficulty: MathDifficulty = .medium,
        problemCount: Int = 3,
        sound: AlarmSound = .radar,
        lockVolume: Bool = true,
        smartQuietWhileTyping: Bool = true,
        fadeIn: Bool = false,
        wakeUpCheckEnabled: Bool = true,
        snoozeEnabled: Bool = false
    ) {
        self.id = id
        self.hour = max(0, min(23, hour))
        self.minute = max(0, min(59, minute))
        self.label = label
        self.isEnabled = isEnabled
        self.repeatDays = Set(repeatDays.filter { (1...7).contains($0) })
        self.difficulty = difficulty
        self.problemCount = max(1, min(10, problemCount))
        self.sound = sound
        self.lockVolume = lockVolume
        self.smartQuietWhileTyping = smartQuietWhileTyping
        self.fadeIn = fadeIn
        self.wakeUpCheckEnabled = wakeUpCheckEnabled
        self.snoozeEnabled = snoozeEnabled
    }

    var formattedTime: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var repeatSummary: String {
        if repeatDays.isEmpty {
            return "Una volta"
        }
        if repeatDays == Set(1...7) {
            return "Ogni giorno"
        }
        if repeatDays == Set(1...5) {
            return "Lun - Ven"
        }
        if repeatDays == Set([6, 7]) {
            return "Weekend"
        }
        let names = ["", "Lun", "Mar", "Mer", "Gio", "Ven", "Sab", "Dom"]
        return repeatDays.sorted().compactMap { idx in
            (1...7).contains(idx) ? names[idx] : nil
        }.joined(separator: ", ")
    }

    /// Converte Calendar `.weekday` (1=Dom ... 7=Sab) in ISO (1=Lun ... 7=Dom)
    static func isoWeekday(from calendarWeekday: Int) -> Int {
        calendarWeekday == 1 ? 7 : (calendarWeekday - 1)
    }

    func nextTriggerDate(from referenceDate: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard isEnabled else { return nil }

        if repeatDays.isEmpty {
            var comps = calendar.dateComponents([.year, .month, .day], from: referenceDate)
            comps.hour = hour
            comps.minute = minute
            comps.second = 0
            guard let todayCandidate = calendar.date(from: comps) else { return nil }
            if todayCandidate > referenceDate {
                return todayCandidate
            }
            return calendar.date(byAdding: .day, value: 1, to: todayCandidate)
        }

        for dayOffset in 0...7 {
            guard let baseDay = calendar.date(byAdding: .day, value: dayOffset, to: referenceDate) else {
                continue
            }
            var comps = calendar.dateComponents([.year, .month, .day], from: baseDay)
            comps.hour = hour
            comps.minute = minute
            comps.second = 0
            guard let candidate = calendar.date(from: comps) else { continue }
            let calWeekday = calendar.component(.weekday, from: candidate)
            let iso = Self.isoWeekday(from: calWeekday)
            if candidate > referenceDate && repeatDays.contains(iso) {
                return candidate
            }
        }
        return nil
    }

    static var defaultSamples: [AlarmItem] {
        [
            AlarmItem(
                hour: 7,
                minute: 0,
                label: "Sveglia Lavoro",
                isEnabled: false,
                repeatDays: [1, 2, 3, 4, 5],
                difficulty: .medium,
                problemCount: 3,
                sound: .radar,
                lockVolume: true,
                smartQuietWhileTyping: true,
                fadeIn: false,
                wakeUpCheckEnabled: true,
                snoozeEnabled: false
            ),
            AlarmItem(
                hour: 8,
                minute: 30,
                label: "Weekend",
                isEnabled: false,
                repeatDays: [6, 7],
                difficulty: .easy,
                problemCount: 2,
                sound: .gentle,
                lockVolume: true,
                smartQuietWhileTyping: true,
                fadeIn: true,
                wakeUpCheckEnabled: false,
                snoozeEnabled: false
            )
        ]
    }
}
