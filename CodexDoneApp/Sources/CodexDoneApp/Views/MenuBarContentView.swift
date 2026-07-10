import CodexDoneCore
import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingQuitOptions = false

    private var notificationPresentation: NotificationSwitchPresentation {
        NotificationSwitchPresentation(isEnabled: appState.config.alert.enabled)
    }

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
                    Label(
                        notificationPresentation.statusText,
                        systemImage: notificationPresentation.statusSymbolName
                    )
                        .font(.caption)
                        .foregroundStyle(appState.config.alert.enabled ? .green : .orange)
                }
                Spacer()
            }

            Divider()

            Button {
                appState.testReminder()
            } label: {
                Label("测试提醒", systemImage: "speaker.wave.2")
            }
            .disabled(!appState.config.alert.enabled)

            Button {
                appState.showSettingsWindow()
            } label: {
                Label("打开设置", systemImage: "gearshape")
            }

            Button {
                appState.copyCodexRule()
            } label: {
                Label("复制 Codex 工作规则", systemImage: "doc.on.doc")
            }

            Button {
                appState.setNotificationsEnabled(!appState.config.alert.enabled)
            } label: {
                Label(
                    notificationPresentation.actionTitle,
                    systemImage: notificationPresentation.actionSymbolName
                )
            }

            Button(role: .destructive) {
                isShowingQuitOptions = true
            } label: {
                Label("退出 CodexDone", systemImage: "power")
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
        .confirmationDialog(
            "退出 CodexDone",
            isPresented: $isShowingQuitOptions,
            titleVisibility: .visible
        ) {
            Button("仅退出界面") {
                appState.quitApp()
            }
            Button("暂停通知并退出", role: .destructive) {
                appState.quitApp(pausingNotifications: true)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("仅退出界面不会停止 Codex 任务调用通知命令。")
        }
    }
}
