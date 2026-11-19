import AVFoundation
import Foundation
import MediaPlayer
import UIKit

@MainActor
final class VolumeGuard {
    static let shared = VolumeGuard()

    private var volumeView: MPVolumeView?
    private var volumeObservation: NSKeyValueObservation?
    private var reinforceTimer: Timer?
    private var isGuarding = false
    private let targetVolume: Float = 1.0

    private init() {}

    func startGuarding() {
        guard !isGuarding else {
            forceMaxSystemVolume()
            return
        }
        isGuarding = true
        attachHiddenVolumeViewIfNeeded()
        forceMaxSystemVolume()

        let session = AVAudioSession.sharedInstance()
        volumeObservation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            let newVol = change.newValue ?? 1.0
            if newVol < 0.92 {
                Task { @MainActor [weak self] in
                    self?.forceMaxSystemVolume()
                }
            }
        }

        reinforceTimer?.invalidate()
        reinforceTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isGuarding else { return }
                if AVAudioSession.sharedInstance().outputVolume < 0.94 {
                    self.forceMaxSystemVolume()
                }
            }
        }
    }

    func stopGuarding() {
        isGuarding = false
        reinforceTimer?.invalidate()
        reinforceTimer = nil
        volumeObservation?.invalidate()
        volumeObservation = nil
        volumeView?.removeFromSuperview()
        volumeView = nil
    }

    func forceMaxSystemVolume() {
        attachHiddenVolumeViewIfNeeded()
        guard let slider = volumeView?.subviews.compactMap({ $0 as? UISlider }).first else {
            return
        }
        if slider.value < targetVolume - 0.02 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak slider] in
                slider?.setValue(1.0, animated: false)
                slider?.sendActions(for: .touchUpInside)
            }
        }
    }

    private func attachHiddenVolumeViewIfNeeded() {
        if volumeView?.superview != nil { return }

        let view = volumeView ?? MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
        view.alpha = 0.001
        view.isUserInteractionEnabled = false
        volumeView = view

        if let window = activeKeyWindow() {
            window.addSubview(view)
        }
    }

    private func activeKeyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first
    }
}
