import SwiftUI

struct MobilePushSettingsView: View {
    @EnvironmentObject private var appState: AppState

    private var mobilePushStatus: String {
        guard appState.config.alert.mobilePush else {
            return "已关闭"
        }

        return appState.config.mobile.topic.isEmpty ? "未配置 topic" : "ntfy 已配置"
    }

    var body: some View {
        SettingsPage(
            title: "手机推送",
            subtitle: "通过 ntfy 把 Codex 完成提醒推送到手机。",
            systemImage: "iphone"
        ) {
            SettingsSectionCard("手机推送") {
                Toggle("启用手机推送", isOn: $appState.config.alert.mobilePush)
                LabeledContent("服务", value: "ntfy")
                LabeledContent("状态") {
                    SettingsStatusBadge(
                        text: mobilePushStatus,
                        level: appState.config.alert.mobilePush && !appState.config.mobile.topic.isEmpty ? .ok : .warning
                    )
                }
            }

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
