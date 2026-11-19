import AVFoundation
import Foundation
import UIKit

@MainActor
final class AudioSirenService: ObservableObject {
    static let shared = AudioSirenService()

    @Published private(set) var isPlaying = false
    @Published private(set) var previewingSound: AlarmSound?
    @Published private(set) var isQuietWindowActive = false
    @Published private(set) var quietRemainingSeconds: Double = 0

    let quietWindowDuration: TimeInterval = 6.0

    private var player: AVAudioPlayer?
    private var previewPlayer: AVAudioPlayer?
    private var fadeTimer: Timer?
    private var quietTimer: Timer?
    private var quietDeadline: Date?
    private var currentVolumeTarget: Float = 1.0
    private var currentFadeElapsed: TimeInterval = 0
    private var isFadeInEnabled = false

    private init() {}

    func startSiren(sound: AlarmSound, fadeIn: Bool) {
        stopPreview()
        configureAudioSessionForAlarm()

        guard let audioPlayer = makePlayer(for: sound) else {
            return
        }

        player?.stop()
        player = audioPlayer
        player?.numberOfLoops = -1
        isFadeInEnabled = fadeIn
        currentFadeElapsed = 0
        currentVolumeTarget = fadeIn ? 0.15 : 1.0
        player?.volume = currentVolumeTarget
        player?.prepareToPlay()
        player?.play()

        isPlaying = true
        resetQuietState()

        fadeTimer?.invalidate()
        if fadeIn {
            fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.stepFadeIn()
                }
            }
        }
    }

    func stopSiren() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        resetQuietState()

        player?.stop()
        player = nil
        isPlaying = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func registerTypingActivity(smartQuietEnabled: Bool) {
        guard isPlaying, smartQuietEnabled else { return }

        quietDeadline = Date().addingTimeInterval(quietWindowDuration)
        quietRemainingSeconds = quietWindowDuration
        isQuietWindowActive = true
        player?.volume = 0.20

        if quietTimer == nil {
            quietTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateQuietCountdown()
                }
            }
        }
    }

    func togglePreview(sound: AlarmSound) {
        if previewingSound == sound {
            stopPreview()
            return
        }
        stopPreview()
        configureAudioSessionForAlarm()

        guard let preview = makePlayer(for: sound) else { return }
        preview.numberOfLoops = -1
        preview.volume = 0.55
        preview.prepareToPlay()
        preview.play()
        previewPlayer = preview
        previewingSound = sound
    }

    func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
        previewingSound = nil
    }

    private func stepFadeIn() {
        guard isPlaying, isFadeInEnabled else {
            fadeTimer?.invalidate()
            fadeTimer = nil
            return
        }
        currentFadeElapsed += 0.25
        let progress = min(1.0, Float(currentFadeElapsed / 22.0))
        currentVolumeTarget = 0.15 + 0.85 * progress

        if !isQuietWindowActive {
            player?.volume = currentVolumeTarget
        }
        if progress >= 1.0 {
            isFadeInEnabled = false
            fadeTimer?.invalidate()
            fadeTimer = nil
        }
    }

    private func updateQuietCountdown() {
        guard isPlaying, let deadline = quietDeadline else {
            resetQuietState()
            return
        }
        let remaining = deadline.timeIntervalSinceNow
        if remaining <= 0 {
            resetQuietState()
            player?.volume = max(currentVolumeTarget, 1.0)
            isFadeInEnabled = false
            let haptic = UIImpactFeedbackGenerator(style: .heavy)
            haptic.impactOccurred()
        } else {
            quietRemainingSeconds = remaining
        }
    }

    private func resetQuietState() {
        quietTimer?.invalidate()
        quietTimer = nil
        quietDeadline = nil
        quietRemainingSeconds = 0
        isQuietWindowActive = false
    }

    private func configureAudioSessionForAlarm() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Errore configurazione AVAudioSession: \(error)")
        }
    }

    private func makePlayer(for sound: AlarmSound) -> AVAudioPlayer? {
        if let url = Bundle.main.url(forResource: sound.baseName, withExtension: "wav")
            ?? Bundle.main.url(forResource: sound.baseName, withExtension: "wav", subdirectory: "Sounds") {
            if let audioPlayer = try? AVAudioPlayer(contentsOf: url) {
                return audioPlayer
            }
        }
        let fallbackData = synthesizeEmergencyBeepWAV()
        return try? AVAudioPlayer(data: fallbackData)
    }

    /// Fallback PCM in memoria nel caso estremo in cui una risorsa bundle mancasse.
    private func synthesizeEmergencyBeepWAV() -> Data {
        let sampleRate: Int32 = 22050
        let durationSeconds = 2.0
        let sampleCount = Int(Double(sampleRate) * durationSeconds)
        var pcm = Data(capacity: 44 + sampleCount * 2)

        func appendUInt32(_ value: UInt32) {
            var le = value.littleEndian
            pcm.append(Data(bytes: &le, count: 4))
        }
        func appendUInt16(_ value: UInt16) {
            var le = value.littleEndian
            pcm.append(Data(bytes: &le, count: 2))
        }

        let dataSize = UInt32(sampleCount * 2)
        pcm.append(contentsOf: "RIFF".utf8)
        appendUInt32(36 + dataSize)
        pcm.append(contentsOf: "WAVEfmt ".utf8)
        appendUInt32(16)
        appendUInt16(1)
        appendUInt16(1)
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(sampleRate * 2))
        appendUInt16(2)
        appendUInt16(16)
        pcm.append(contentsOf: "data".utf8)
        appendUInt32(dataSize)

        for i in 0..<sampleCount {
            let t = Double(i) / Double(sampleRate)
            let cycle = t.truncatingRemainder(dividingBy: 0.5)
            let amp = cycle < 0.28 ? 26000.0 : 0.0
            let freq = cycle < 0.14 ? 1480.0 : 1975.0
            let sample = Int16(amp * sin(2.0 * .pi * freq * t))
            var le = sample.littleEndian
            pcm.append(Data(bytes: &le, count: 2))
        }
        return pcm
    }
}
