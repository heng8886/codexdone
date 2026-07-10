import SwiftUI

@main
struct CodexDoneApp: App {
    @NSApplicationDelegateAdaptor(AppLaunchDelegate.self) private var appLaunchDelegate
    @StateObject private var appState: AppState

    init() {
        let state = AppState()
        _appState = StateObject(wrappedValue: state)
        AppLaunchDelegate.showSettingsWindow = {
            Task { @MainActor in
                SettingsWindowManager.shared.show(appState: state)
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appState)
        } label: {
            Label(
                "CodexDone",
                systemImage: appState.config.alert.enabled ? "checkmark.circle" : "pause.circle"
            )
        }
        .menuBarExtraStyle(.window)
    }
}
