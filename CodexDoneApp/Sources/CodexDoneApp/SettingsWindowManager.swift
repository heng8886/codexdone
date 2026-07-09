import AppKit
import SwiftUI

@MainActor
final class SettingsWindowManager {
    static let shared = SettingsWindowManager()

    private var window: NSWindow?

    private init() {}

    func show(appState: AppState) {
        let settingsWindow = window ?? makeWindow(appState: appState)

        if !settingsWindow.isVisible {
            settingsWindow.center()
        }
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow(appState: AppState) -> NSWindow {
        let hostingController = NSHostingController(
            rootView: SettingsWindowView()
                .environmentObject(appState)
        )
        let settingsWindow = NSWindow(contentViewController: hostingController)
        settingsWindow.title = "CodexDone 设置"
        settingsWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        settingsWindow.minSize = NSSize(width: 760, height: 460)
        settingsWindow.setContentSize(NSSize(width: 860, height: 540))
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.setFrameAutosaveName("CodexDoneSettingsWindow")
        window = settingsWindow
        return settingsWindow
    }
}
