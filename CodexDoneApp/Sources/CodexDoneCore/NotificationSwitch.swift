public enum NotificationSwitch {
    public static func setEnabled(
        _ enabled: Bool,
        config: inout CodexDoneConfig,
        save: (CodexDoneConfig) throws -> Void
    ) throws {
        let previousValue = config.alert.enabled
        config.alert.enabled = enabled

        do {
            try save(config)
        } catch {
            config.alert.enabled = previousValue
            throw error
        }
    }

    public static func shouldTerminate(
        pausingNotifications: Bool,
        pause: () -> Bool
    ) -> Bool {
        !pausingNotifications || pause()
    }
}
