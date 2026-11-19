import SwiftUI
import UserNotifications

struct AlarmListView: View {
    @EnvironmentObject private var engine: AlarmEngine
    @State private var showingNewAlarm = false
    @State private var editingAlarm: AlarmItem?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        statusHeaderCard

                        if let pendingUntil = engine.wakeUpCheckPendingUntil {
                            wakeUpCheckCard(deadline: pendingUntil)
                        }

                        if needsPermissionsBanner {
                            permissionsBannerCard
                        }

                        if engine.alarms.isEmpty {
                            emptyStateView
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(engine.alarms) { alarm in
                                    AlarmRowCard(
                                        alarm: alarm,
                                        onToggle: { isOn in
                                            engine.toggleAlarm(id: alarm.id, isEnabled: isOn)
                                        },
                                        onTapEdit: {
                                            editingAlarm = alarm
                                        },
                                        onTestNow: {
                                            engine.triggerTestAlarm(alarm)
                                        },
                                        onDelete: {
                                            engine.deleteAlarm(id: alarm.id)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Sveglia")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewAlarm = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.18))
                    }
                    .accessibilityLabel("Nuova sveglia")
                }
            }
            .sheet(isPresented: $showingNewAlarm) {
                AlarmEditorView(alarm: nil) { newAlarm in
                    engine.upsertAlarm(newAlarm)
                }
            }
            .sheet(item: $editingAlarm) { alarm in
                AlarmEditorView(alarm: alarm) { updated in
                    engine.upsertAlarm(updated)
                } onDelete: { id in
                    engine.deleteAlarm(id: id)
                }
            }
        }
    }

    private var needsPermissionsBanner: Bool {
        engine.notificationStatus != .authorized ||
        (engine.alarmKitAvailable && !engine.alarmKitAuthorized)
    }

    private var statusHeaderCard: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let next = engine.nextScheduledSummary()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.shield.fill")
                        .foregroundStyle(Color(red: 0.25, green: 0.90, blue: 0.55))
                    Text("0% BATTERIA NOTTURNA • ANTI-CHIUSURA")
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(Color(red: 0.25, green: 0.90, blue: 0.55))
                    Spacer()
                }

                if let next {
                    Text("Prossima sveglia alle \(next.alarm.formattedTime)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text("\(next.alarm.label) • \(countdownText(to: next.date, from: context.date))")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                } else {
                    Text("Nessuna sveglia attiva")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Attiva una sveglia o premine il tasto Test per provare il blocco matematico.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.09, blue: 0.11))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
        }
    }

    private func wakeUpCheckCard(deadline: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(deadline.timeIntervalSince(context.date)))
            let minPart = remaining / 60
            let secPart = remaining % 60
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "eye.trianglebadge.exclamationmark.fill")
                        .foregroundStyle(.yellow)
                    Text("Controllo Sveglio in corso")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(String(format: "%02d:%02d", minPart, secPart))
                        .font(.subheadline.monospacedDigit().weight(.bold))
                        .foregroundStyle(.yellow)
                }

                Text("Conferma di essere sveglio prima dello scadere del timer, altrimenti la sirena ripartirà!")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))

                Button {
                    engine.confirmWakeUpCheck()
                } label: {
                    Text("Conferma: Sono Sveglio")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.20, green: 0.82, blue: 0.48))
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.16, green: 0.13, blue: 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.yellow.opacity(0.45), lineWidth: 1)
                    )
            )
        }
    }

    private var permissionsBannerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.18))
                Text("Permessi richiesti per suonare")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
            }

            Text("Abilita Notifiche Time-Sensitive e AlarmKit affinché la sveglia suoni anche con iPhone chiuso o in Silenzioso.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.70))

            Button {
                Task {
                    await engine.requestAllPermissions()
                }
            } label: {
                Text("Attiva Permessi Ora")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color(red: 1.0, green: 0.45, blue: 0.18))
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.14, green: 0.08, blue: 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(red: 1.0, green: 0.45, blue: 0.18).opacity(0.45), lineWidth: 1)
                )
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "alarm.waves.left.and.right.fill")
                .font(.system(size: 46))
                .foregroundStyle(Color(red: 1.0, green: 0.45, blue: 0.18))
            Text("Nessuna sveglia impostata")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Tocca + in alto a destra per creare la tua prima sveglia con blocco matematico.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity)
    }

    private func countdownText(to target: Date, from now: Date) -> String {
        let diff = max(0, Int(target.timeIntervalSince(now)))
        let days = diff / 86400
        let hours = (diff % 86400) / 3600
        let minutes = (diff % 3600) / 60
        if days > 0 {
            return "tra \(days)g \(hours)h"
        }
        if hours > 0 {
            return "tra \(hours)h \(minutes)m"
        }
        return "tra \(max(1, minutes)) min"
    }
}

private struct AlarmRowCard: View {
    let alarm: AlarmItem
    let onToggle: (Bool) -> Void
    let onTapEdit: () -> Void
    let onTestNow: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(alarm.formattedTime)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(alarm.isEnabled ? .white : .white.opacity(0.42))

                    Text("\(alarm.label) • \(alarm.repeatSummary)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(alarm.isEnabled ? .white.opacity(0.78) : .white.opacity(0.38))
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { alarm.isEnabled },
                    set: { onToggle($0) }
                ))
                .labelsHidden()
                .tint(Color(red: 1.0, green: 0.45, blue: 0.18))
            }

            Divider()
                .overlay(Color.white.opacity(0.08))

            HStack(spacing: 8) {
                Label("\(alarm.difficulty.title) ×\(alarm.problemCount)", systemImage: "function")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(alarm.difficulty.accentColor.opacity(0.18))
                    .foregroundStyle(alarm.difficulty.accentColor)
                    .clipShape(Capsule())

                if alarm.lockVolume {
                    Label("Vol 100%", systemImage: "speaker.wave.3.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .foregroundStyle(.white.opacity(0.8))
                        .clipShape(Capsule())
                }

                Spacer()

                Button {
                    onTestNow()
                } label: {
                    Label("Test", systemImage: "play.fill")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(alarm.isEnabled ? Color(red: 0.09, green: 0.10, blue: 0.12) : Color(red: 0.05, green: 0.05, blue: 0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            alarm.isEnabled
                                ? Color(red: 1.0, green: 0.45, blue: 0.18).opacity(0.35)
                                : Color.white.opacity(0.07),
                            lineWidth: 1
                        )
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTapEdit()
        }
        .contextMenu {
            Button {
                onTapEdit()
            } label: {
                Label("Modifica", systemImage: "pencil")
            }
            Button {
                onTestNow()
            } label: {
                Label("Simula Sveglia Ora", systemImage: "play.fill")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Elimina", systemImage: "trash")
            }
        }
    }
}
