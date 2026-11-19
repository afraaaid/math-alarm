import SwiftUI

@main
struct SvegliaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var engine = AlarmEngine.shared
    @StateObject private var audio = AudioSirenService.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .environmentObject(audio)
                .preferredColorScheme(.dark)
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        engine.handleReturnedToForeground()
                    case .background:
                        if engine.isRinging {
                            engine.handleMovedToBackgroundWhileRinging()
                        }
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }
}
