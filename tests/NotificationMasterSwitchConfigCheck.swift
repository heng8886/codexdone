import Foundation

@main
struct NotificationMasterSwitchConfigCheck {
    static func main() throws {
        guard CodexDoneConfig.default.alert.enabled else {
            throw CheckError.failed("default alert.enabled must be true")
        }

        let legacyData = try JSONSerialization.data(withJSONObject: [
            "version": 1,
            "alert": [
                "mode": "voice",
                "desktopNotification": true,
                "mobilePush": false,
            ],
        ])
        let legacy = try JSONDecoder().decode(CodexDoneConfig.self, from: legacyData)
        guard legacy.alert.enabled else {
            throw CheckError.failed("legacy alert config must default enabled")
        }

        var disabled = CodexDoneConfig.default
        disabled.alert.enabled = false
        let roundTrip = try JSONDecoder().decode(
            CodexDoneConfig.self,
            from: JSONEncoder().encode(disabled)
        )
        guard roundTrip.alert.enabled == false else {
            throw CheckError.failed("disabled state did not survive JSON round trip")
        }

        var savedConfig: CodexDoneConfig?
        try NotificationSwitch.setEnabled(false, config: &disabled) { config in
            savedConfig = config
        }
        guard disabled.alert.enabled == false, savedConfig?.alert.enabled == false else {
            throw CheckError.failed("successful switch update was not persisted")
        }

        var rollbackConfig = CodexDoneConfig.default
        do {
            try NotificationSwitch.setEnabled(false, config: &rollbackConfig) { _ in
                throw CheckError.failed("simulated save failure")
            }
            throw CheckError.failed("save failure was not propagated")
        } catch CheckError.failed(let message) where message == "simulated save failure" {
            guard rollbackConfig.alert.enabled else {
                throw CheckError.failed("failed switch update did not roll back")
            }
        }

        var pauseAttempted = false
        let blockedQuit = NotificationSwitch.shouldTerminate(pausingNotifications: true) {
            pauseAttempted = true
            return false
        }
        guard pauseAttempted, blockedQuit == false else {
            throw CheckError.failed("failed pause must block App termination")
        }

        pauseAttempted = false
        let interfaceOnlyQuit = NotificationSwitch.shouldTerminate(pausingNotifications: false) {
            pauseAttempted = true
            return false
        }
        guard interfaceOnlyQuit, pauseAttempted == false else {
            throw CheckError.failed("interface-only quit must not change notification state")
        }

        let enabledPresentation = NotificationSwitchPresentation(isEnabled: true)
        guard enabledPresentation.statusText == "通知已开启",
              enabledPresentation.actionTitle == "暂停所有通知",
              enabledPresentation.statusSymbolName == "checkmark.circle.fill",
              enabledPresentation.actionSymbolName == "pause.circle" else {
            throw CheckError.failed("enabled menu presentation is incorrect")
        }

        let pausedPresentation = NotificationSwitchPresentation(isEnabled: false)
        guard pausedPresentation.statusText == "通知已暂停",
              pausedPresentation.actionTitle == "恢复所有通知",
              pausedPresentation.statusSymbolName == "pause.circle.fill",
              pausedPresentation.actionSymbolName == "play.circle" else {
            throw CheckError.failed("paused menu presentation is incorrect")
        }

        print("ok - Swift notification switch config verified")
    }
}

private enum CheckError: Error {
    case failed(String)
}
