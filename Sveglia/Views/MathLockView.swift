import SwiftUI

struct MathLockView: View {
    @EnvironmentObject private var engine: AlarmEngine
    @EnvironmentObject private var audio: AudioSirenService
    @State private var pulseAura = false
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Bagliore OLED pulsante rosso/arancio
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.22, blue: 0.14).opacity(pulseAura ? 0.34 : 0.14),
                    Color.clear
                ],
                center: .top,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseAura = true
                }
            }

            VStack(spacing: 14) {
                headerSection
                progressSegments
                quietStatusBanner
                Spacer(minLength: 4)
                equationCard
                Spacer(minLength: 4)
                numericKeypad
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .interactiveDismissDisabled(true)
        .persistentSystemOverlays(.hidden)
        .onChange(of: engine.wrongAnswerAttempts) { _, _ in
            triggerShake()
        }
    }

    private var headerSection: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.caption2.weight(.bold))
                    Text("BLOCCO ATTIVO • RISOLVI PER SPEGNERE")
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.24))
                .foregroundStyle(Color(red: 1.0, green: 0.38, blue: 0.32))
                .clipShape(Capsule())

                Text(context.date, format: .dateTime.hour().minute().second())
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                if let alarm = engine.activeAlarm {
                    Text("\(alarm.label) • \(alarm.difficulty.title)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.68))
                }
            }
        }
    }

    private var progressSegments: some View {
        let total = max(1, engine.currentProblems.count)
        let currentIndex = min(engine.solvedCount + 1, total)

        return VStack(spacing: 6) {
            HStack {
                Text("Calcolo \(currentIndex) di \(total)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("\(engine.solvedCount)/\(total) risolti")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
            }

            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { idx in
                    Capsule()
                        .fill(segmentColor(for: idx))
                        .frame(height: 6)
                }
            }
        }
    }

    private func segmentColor(for idx: Int) -> Color {
        if idx < engine.solvedCount {
            return Color(red: 0.20, green: 0.86, blue: 0.50)
        }
        if idx == engine.solvedCount {
            return Color(red: 1.0, green: 0.50, blue: 0.16)
        }
        return Color.white.opacity(0.14)
    }

    @ViewBuilder
    private var quietStatusBanner: some View {
        if let alarm = engine.activeAlarm, alarm.smartQuietWhileTyping {
            if audio.isQuietWindowActive {
                let ratio = max(0, min(1, audio.quietRemainingSeconds / audio.quietWindowDuration))
                VStack(spacing: 5) {
                    HStack {
                        Image(systemName: "ear.badge.checkmark")
                            .foregroundStyle(Color(red: 0.25, green: 0.88, blue: 0.55))
                        Text("Sirena attenuata mentre scrivi")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Spacer()
                        Text(String(format: "%.1fs", audio.quietRemainingSeconds))
                            .font(.caption.monospacedDigit().weight(.bold))
                            .foregroundStyle(Color(red: 0.25, green: 0.88, blue: 0.55))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.12))
                            Capsule()
                                .fill(Color(red: 0.25, green: 0.88, blue: 0.55))
                                .frame(width: geo.size.width * ratio)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundStyle(.orange)
                    Text("Sirena al 100% — inizia a digitare per attenuare 6s")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var equationCard: some View {
        VStack(spacing: 14) {
            Text(engine.currentProblem?.expression ?? "...")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.45)
                .lineLimit(1)
                .foregroundStyle(.white)

            HStack {
                Text("=")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.48, blue: 0.18))

                Text(engine.userInput.isEmpty ? "Inserisci risposta" : engine.userInput)
                    .font(.system(size: engine.userInput.isEmpty ? 22 : 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(engine.userInput.isEmpty ? .white.opacity(0.30) : .white)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.65))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                engine.lastWrongBanner
                                    ? Color.red
                                    : Color.white.opacity(0.16),
                                lineWidth: engine.lastWrongBanner ? 2 : 1
                            )
                    )
            )
            .offset(x: shakeOffset)

            if engine.lastWrongBanner {
                Text("Risposta errata! Controlla il calcolo e riprova.")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.35, blue: 0.32))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.09, green: 0.10, blue: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var numericKeypad: some View {
        let rows: [[KeypadKey]] = [
            [.digit("1"), .digit("2"), .digit("3")],
            [.digit("4"), .digit("5"), .digit("6")],
            [.digit("7"), .digit("8"), .digit("9")],
            [.backspace, .digit("0"), .submit]
        ]

        return VStack(spacing: 10) {
            ForEach(0..<rows.count, id: \.self) { rowIdx in
                HStack(spacing: 10) {
                    ForEach(rows[rowIdx]) { key in
                        keypadButton(for: key)
                    }
                }
            }
        }
    }

    private func keypadButton(for key: KeypadKey) -> some View {
        Button {
            switch key {
            case .digit(let value):
                engine.appendDigit(value)
            case .backspace:
                engine.deleteLastDigit()
            case .submit:
                engine.submitAnswer()
            }
        } label: {
            Group {
                switch key {
                case .digit(let value):
                    Text(value)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                case .backspace:
                    Image(systemName: "delete.left.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                case .submit:
                    Image(systemName: "checkmark")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(buttonBackground(for: key))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(TactileKeypadStyle())
    }

    private func buttonBackground(for key: KeypadKey) -> Color {
        switch key {
        case .digit:
            return Color(red: 0.12, green: 0.13, blue: 0.16)
        case .backspace:
            return Color(red: 0.18, green: 0.12, blue: 0.12)
        case .submit:
            return engine.userInput.isEmpty
                ? Color(red: 1.0, green: 0.45, blue: 0.18).opacity(0.45)
                : Color(red: 0.22, green: 0.88, blue: 0.50)
        }
    }

    private func triggerShake() {
        let offsets: [(CGFloat, TimeInterval)] = [
            (-12, 0.0), (12, 0.05), (-10, 0.10), (10, 0.15), (-5, 0.20), (0, 0.25)
        ]
        for (value, delay) in offsets {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.linear(duration: 0.045)) {
                    shakeOffset = value
                }
            }
        }
    }
}

private enum KeypadKey: Identifiable, Hashable {
    case digit(String)
    case backspace
    case submit

    var id: String {
        switch self {
        case .digit(let d): return "d_\(d)"
        case .backspace: return "back"
        case .submit: return "ok"
        }
    }
}

private struct TactileKeypadStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
