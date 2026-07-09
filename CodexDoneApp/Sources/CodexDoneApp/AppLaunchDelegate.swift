import AppKit

final class AppLaunchDelegate: NSObject, NSApplicationDelegate {
    static var showSettingsWindow: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard Self.shouldShowSettingsOnLaunch else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            Self.showSettingsWindow?()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Self.showSettingsWindow?()
        return true
    }

    private static var shouldShowSettingsOnLaunch: Bool {
        let value = ProcessInfo.processInfo.environment["CODEX_DONE_SHOW_SETTINGS_ON_LAUNCH"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return value != "0" && value != "false" && value != "no"
    }
}
