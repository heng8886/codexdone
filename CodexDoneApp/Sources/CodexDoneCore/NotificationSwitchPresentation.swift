public struct NotificationSwitchPresentation: Equatable, Sendable {
    public let statusText: String
    public let actionTitle: String
    public let statusSymbolName: String
    public let actionSymbolName: String

    public init(isEnabled: Bool) {
        if isEnabled {
            statusText = "通知已开启"
            actionTitle = "暂停所有通知"
            statusSymbolName = "checkmark.circle.fill"
            actionSymbolName = "pause.circle"
        } else {
            statusText = "通知已暂停"
            actionTitle = "恢复所有通知"
            statusSymbolName = "pause.circle.fill"
            actionSymbolName = "play.circle"
        }
    }
}
