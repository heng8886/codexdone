import SwiftUI

struct MobilePushSettingsView: View {
    @EnvironmentObject private var appState: AppState

    private let providers = [
        ("ntfy", "ntfy"),
        ("apple_messages", "Apple Messages / iMessage")
    ]

    private var usesAppleMessages: Bool {
        appState.config.mobile.provider == "apple_messages"
    }

    private var mobilePushStatus: String {
        guard appState.config.alert.mobilePush else {
            return "已关闭"
        }

        if usesAppleMessages {
            return appState.config.mobile.recipient.isEmpty ? "未配置接收人" : "iMessage 已配置"
        }

        return appState.config.mobile.topic.isEmpty ? "未配置 topic" : "ntfy 已配置"
    }

    private var mobilePushReady: Bool {
        guard appState.config.alert.mobilePush else {
            return false
        }

        return usesAppleMessages
            ? !appState.config.mobile.recipient.isEmpty
            : !appState.config.mobile.topic.isEmpty
    }

    var body: some View {
        SettingsPage(
            title: "手机推送",
            subtitle: "通过 ntfy 把 Codex 完成提醒推送到手机。",
            systemImage: "iphone"
        ) {
            SettingsSectionCard("手机推送") {
                Toggle("启用手机推送", isOn: $appState.config.alert.mobilePush)
                Picker("服务", selection: $appState.config.mobile.provider) {
                    ForEach(providers, id: \.0) { provider in
                        Text(provider.1).tag(provider.0)
                    }
                }
                .pickerStyle(.menu)
                LabeledContent("状态") {
                    SettingsStatusBadge(
                        text: mobilePushStatus,
                        level: mobilePushReady ? .ok : .warning
                    )
                }
            }

            if usesAppleMessages {
                SettingsSectionCard("Apple Messages / iMessage") {
                    LabeledContent("接收人") {
                        TextField("手机号或 Apple ID", text: $appState.config.mobile.recipient)
                            .textFieldStyle(.roundedBorder)
                    }

                    LabeledContent("推送标题") {
                        TextField("Codex 任务完成", text: $appState.config.mobile.title)
                            .textFieldStyle(.roundedBorder)
                    }

                    Text("CodexDone 会通过 macOS Messages app 给该接收人发送 iMessage。首次使用时，系统可能要求允许运行环境控制 Messages。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                SettingsSectionCard("ntfy") {
                    LabeledContent("Topic 或完整 ntfy URL") {
                        TextField("my-codex-topic 或 https://ntfy.sh/my-codex-topic", text: $appState.config.mobile.topic)
                            .textFieldStyle(.roundedBorder)
                    }

                    LabeledContent("推送标题") {
                        TextField("Codex 任务完成", text: $appState.config.mobile.title)
                            .textFieldStyle(.roundedBorder)
                    }

                    Text("Topic 可以填写普通 topic，例如 my-codex-topic，也可以填写完整地址，例如 https://ntfy.sh/my-codex-topic。留空时会回退到 CODEX_NOTIFY_TOPIC。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            SettingsSectionCard("操作") {
                SettingsActions(
                    status: appState.lastStatusMessage,
                    actions: [
                        SettingsAction("保存配置") { appState.save() },
                        SettingsAction("测试完整提醒") { appState.testReminder() },
                    ]
                )
            }
        }
    }
}
