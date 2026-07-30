import SwiftUI

@main
struct GinApp: App {
    @State private var audio = AudioService()
    @State private var progress = ProgressStore()
    @State private var settings = SettingsStore()
    @State private var usage = UsageTracker()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(audio)
                .environment(progress)
                .environment(settings)
                .environment(usage)
                // A toddler app should never dim mid-activity while they are
                // looking at it and thinking about the answer.
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        usage.startCounting()
                    default:
                        // Time only counts while the app is actually in front.
                        usage.stopCounting()
                    }
                }
        }
    }
}
