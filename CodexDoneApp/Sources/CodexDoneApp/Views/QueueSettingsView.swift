import SwiftUI

struct QueueSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SettingsPage(
            title: "队列设置",
            subtitle: "控制多个 Codex 线程接近完成时如何合并提醒。",
            systemImage: "tray.full"
        ) {
            SettingsSectionCard("合并通知") {
                Toggle("合并短时间内的完成通知", isOn: $appState.config.queue.mergeNotifications)

                LabeledContent("合并等待时间") {
                    Stepper(
                        "\(appState.config.queue.batchDelaySeconds) 秒",
                        value: $appState.config.queue.batchDelaySeconds,
                        in: 0...60
                    )
                    .frame(maxWidth: 150)
                }

                Text("多个 Codex 线程接近同时完成时，会在这个时间窗口内合并为一次语音、桌面通知和手机推送。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SettingsSectionCard("完成记录") {
                LabeledContent("保留记录") {
                    Stepper(
                        "\(appState.config.queue.retentionCount) 条",
                        value: $appState.config.queue.retentionCount,
                        in: 1...5000,
                        step: 10
                    )
                    .frame(maxWidth: 170)
                }

                LabeledContent("事件日志") {
                    SettingsPathText(value: appState.eventsPath)
                }

                LabeledContent("处理状态") {
                    SettingsPathText(value: appState.notifyStatePath)
                }

                HStack(spacing: 10) {
                    Button("刷新完成记录") { appState.loadRecentEvents() }
                    Button("清空完成记录", role: .destructive) { appState.clearEvents() }
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
