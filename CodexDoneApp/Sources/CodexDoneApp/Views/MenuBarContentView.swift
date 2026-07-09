import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var appState: AppState

    private var mobilePushStatus: String {
        guard appState.config.alert.mobilePush else {
            return "已关闭"
        }

        if appState.config.mobile.provider == "apple_messages" {
            return appState.config.mobile.recipient.isEmpty ? "未配置" : "iMessage 已配置"
        }

        return appState.config.mobile.topic.isEmpty ? "未配置" : "ntfy 已配置"
    }

    private var latestEventSummary: String {
        let message = appState.recentEvents.first?.rawMessage ?? "暂无"
        guard message.count > 18 else {
            return message
        }
        return "\(message.prefix(18))…"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CodexDone")
                        .font(.headline)
                    Text("通知器运行中")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(.green)
                    .frame(width: 10, height: 10)
            }

            Divider()

            Button("测试提醒") {
                appState.testReminder()
            }

            Button("打开设置") {
                appState.showSettingsWindow()
            }

            Button("复制 Codex 工作规则") {
                appState.copyCodexRule()
            }

            Button("退出 CodexDone", role: .destructive) {
                appState.quitApp()
            }

            Divider()

            Text("当前模式：\(appState.config.alert.mode.displayName)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("语音：\(appState.voiceProviderDisplayName)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("手机推送：\(mobilePushStatus)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("最近完成：\(latestEventSummary)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(appState.lastStatusMessage)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(width: 280)
    }
}
