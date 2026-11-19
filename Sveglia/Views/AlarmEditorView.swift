import SwiftUI

struct AlarmEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var audio = AudioSirenService.shared

    let isEditing: Bool
    @State private var draft: AlarmItem
    @State private var selectedTime: Date
    @State private var previewProblem: MathProblem

    let onSave: (AlarmItem) -> Void
    var onDelete: ((UUID) -> Void)?

    init(
        alarm: AlarmItem?,
        onSave: @escaping (AlarmItem) -> Void,
        onDelete: ((UUID) -> Void)? = nil
    ) {
        self.isEditing = (alarm != nil)
        let base = alarm ?? AlarmItem(isEnabled: true)
        _draft = State(initialValue: base)

        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = base.hour
        comps.minute = base.minute
        let initialDate = Calendar.current.date(from: comps) ?? Date()
        _selectedTime = State(initialValue: initialDate)
        _previewProblem = State(initialValue: MathGenerator.generate(difficulty: base.difficulty))

        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        timePickerCard
                        labelAndRepeatCard
                        mathDifficultyCard
                        soundPickerCard
                        protectionsCard

                        if isEditing, let onDelete {
                            Button(role: .destructive) {
                                audio.stopPreview()
                                onDelete(draft.id)
                                dismiss()
                            } label: {
                                Label("Elimina Sveglia", systemImage: "trash.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.red.opacity(0.16))
                                    .foregroundStyle(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle(isEditing ? "Modifica Sveglia" : "Nuova Sveglia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") {
                        audio.stopPreview()
                        dismiss()
                    }
                    .foregroundStyle(.white.opacity(0.75))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Salva") {
                        audio.stopPreview()
                        var finalAlarm = draft
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
                        finalAlarm.hour = comps.hour ?? draft.hour
                        finalAlarm.minute = comps.minute ?? draft.minute
                        finalAlarm.isEnabled = true
                        if finalAlarm.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            finalAlarm.label = "Sveglia"
                        }
                        onSave(finalAlarm)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.18))
                }
            }
            .onDisappear {
                audio.stopPreview()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var timePickerCard: some View {
        DatePicker("Orario", selection: $selectedTime, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(cardBackground)
    }

    private var labelAndRepeatCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Etichetta")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                TextField("Nome sveglia", text: $draft.label)
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Ripetizione")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))

                let dayLabels = [(1, "L"), (2, "M"), (3, "M"), (4, "G"), (5, "V"), (6, "S"), (7, "D")]
                HStack(spacing: 8) {
                    ForEach(dayLabels, id: \.0) { day, letter in
                        let selected = draft.repeatDays.contains(day)
                        Button {
                            if selected {
                                draft.repeatDays.remove(day)
                            } else {
                                draft.repeatDays.insert(day)
                            }
                        } label: {
                            Text(letter)
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(
                                    selected
                                        ? Color(red: 1.0, green: 0.45, blue: 0.18)
                                        : Color.white.opacity(0.08)
                                )
                                .foregroundStyle(selected ? .black : .white)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 8) {
                    presetButton("Feriali", days: [1, 2, 3, 4, 5])
                    presetButton("Weekend", days: [6, 7])
                    presetButton("Tutti", days: [1, 2, 3, 4, 5, 6, 7])
                    presetButton("Mai", days: [])
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private func presetButton(_ title: String, days: Set<Int>) -> some View {
        let isActive = draft.repeatDays == days
        return Button {
            draft.repeatDays = days
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isActive ? Color.white.opacity(0.22) : Color.white.opacity(0.07))
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var mathDifficultyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sfida Matematica per Spegnere")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(MathDifficulty.allCases) { level in
                    let isSelected = draft.difficulty == level
                    Button {
                        draft.difficulty = level
                        previewProblem = MathGenerator.generate(difficulty: level)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(level.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(isSelected ? .black : level.accentColor)
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.black)
                                }
                            }
                            Text(level.subtitle)
                                .font(.caption2)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(isSelected ? .black.opacity(0.8) : .white.opacity(0.6))
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? level.accentColor : Color.white.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Anteprima calcolo")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                    Text("\(previewProblem.expression) = \(previewProblem.answer)")
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button {
                    previewProblem = MathGenerator.generate(difficulty: draft.difficulty)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline.weight(.bold))
                        .padding(10)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Stepper(value: $draft.problemCount, in: 1...10) {
                HStack {
                    Text("Numero di calcoli richiesti")
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(draft.problemCount)")
                        .font(.headline.monospacedDigit().weight(.bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.18))
                }
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var soundPickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suoneria Sirena")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            ForEach(AlarmSound.allCases) { sound in
                let isSelected = draft.sound == sound
                let isPreviewing = audio.previewingSound == sound
                HStack(spacing: 12) {
                    Button {
                        draft.sound = sound
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isSelected ? Color(red: 1.0, green: 0.45, blue: 0.18) : .white.opacity(0.35))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sound.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(sound.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        audio.togglePreview(sound: sound)
                    } label: {
                        Image(systemName: isPreviewing ? "stop.fill" : "play.fill")
                            .font(.caption.weight(.bold))
                            .frame(width: 34, height: 34)
                            .background(isPreviewing ? Color.red.opacity(0.25) : Color.white.opacity(0.1))
                            .foregroundStyle(isPreviewing ? .red : .white)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Color.white.opacity(0.08) : Color.clear)
                )
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var protectionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Protezioni Anti-Sonno & Anti-Chiusura")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Toggle(isOn: $draft.lockVolume) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Blocco Volume Fisico al 100%")
                        .font(.subheadline.weight(.medium))
                    Text("Impedisce di abbassare la sirena coi tasti volume")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
            .tint(Color(red: 1.0, green: 0.45, blue: 0.18))

            Divider().overlay(Color.white.opacity(0.08))

            Toggle(isOn: $draft.smartQuietWhileTyping) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Attenua Sirena mentre digiti (6s)")
                        .font(.subheadline.weight(.medium))
                    Text("Abbassa il volume mentre scrivi; se ti fermi >6s torna al 100%")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
            .tint(Color(red: 1.0, green: 0.45, blue: 0.18))

            Divider().overlay(Color.white.opacity(0.08))

            Toggle(isOn: $draft.wakeUpCheckEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Controllo Post-Sveglia (+5 min)")
                        .font(.subheadline.weight(.medium))
                    Text("Se non confermi di essere sveglio dopo 5 minuti, la sirena riparte")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
            .tint(Color(red: 1.0, green: 0.45, blue: 0.18))

            Divider().overlay(Color.white.opacity(0.08))

            Toggle(isOn: $draft.fadeIn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fade-in Audio Graduale")
                        .font(.subheadline.weight(.medium))
                    Text("Volume crescente nei primi 20 secondi")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
            .tint(Color(red: 1.0, green: 0.45, blue: 0.18))

            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.18))
                Text("Snooze disabilitato: spegnimento consentito solo risolvendo tutti i calcoli.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 1.0, green: 0.45, blue: 0.18).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .background(cardBackground)
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
