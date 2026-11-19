import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var engine: AlarmEngine
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if engine.isRinging {
                MathLockView()
                    .transition(.opacity)
                    .zIndex(100)
            } else {
                TabView(selection: $selectedTab) {
                    AlarmListView()
                        .tabItem {
                            Label("Sveglie", systemImage: "alarm.fill")
                        }
                        .tag(0)

                    PracticeAndSettingsView()
                        .tabItem {
                            Label("Allenamento & Sistema", systemImage: "shield.lefthalf.filled")
                        }
                        .tag(1)
                }
                .tint(Color(red: 1.0, green: 0.45, blue: 0.18))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: engine.isRinging)
    }
}
