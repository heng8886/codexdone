import CodexDoneCore
import SwiftUI

struct StatusSettingsView: View {
    @EnvironmentObject private var appState: AppState

    private var mobilePushStatus: String {
        guard appState.config.alert.mobilePush else {
            return "已关闭"
        }

        return appState.config.mobile.topic.isEmpty ? "未配置" : "ntfy 已配置"
    }

    var body: some View {
        SettingsPage(
            title: "状态",
            subtitle: "查看当前提醒链路、配置路径和最近完成记录。",
            systemImage: "checkmark.circle"
        ) {
            SettingsSectionCard("运行概览") {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 180), spacing: 12)],
                    alignment: .leading,
                    spacing: 12
                ) {
                    SettingsMetricTile(
                        title: "本机提醒",
                        value: appState.cliAvailable ? "可用" : "未找到",
                        level: appState.cliAvailable ? .ok : .error
                    )
                    SettingsMetricTile(
                        title: "手机推送",
                        value: mobilePushStatus,
                        level: appState.config.alert.mobilePush && !appState.config.mobile.topic.isEmpty ? .ok : .warning
                    )
                    SettingsMetricTile(
                        title: "当前模式",
                        value: appState.config.alert.mode.displayName,
                        level: .neutral
                    )
                    SettingsMetricTile(
                        title: "队列合并",
                        value: appState.config.queue.mergeNotifications
                            ? "\(appState.config.queue.batchDelaySeconds) 秒窗口"
                            : "已关闭",
                        level: appState.config.queue.mergeNotifications ? .ok : .warning
                    )
                }

                Divider()

                LabeledContent("语音服务商", value: appState.voiceProviderDisplayName)
                LabeledContent("OpenAI API Key", value: appState.openAIKeyStatusText)
            }

            SettingsSectionCard("本机文件") {
                LabeledContent("配置文件") {
                    SettingsPathText(value: appState.configPath)
                }
                LabeledContent("密钥文件") {
                    SettingsPathText(value: appState.envPath)
                }
                LabeledContent("事件日志") {
                    SettingsPathText(value: appState.eventsPath)
                }
                LabeledContent("处理状态") {
                    SettingsPathText(value: appState.notifyStatePath)
                }
            }

            SettingsSectionCard("最近完成记录") {
                if appState.recentEvents.isEmpty {
                    Text("暂无完成记录")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.recentEvents.prefix(8)) { event in
                        StatusEventRow(
                            event: event,
                            eventLabel: eventLabel(event.eventType),
                            formattedTime: formattedEventTime(event.timestamp)
                        )

                        if event.id != appState.recentEvents.prefix(8).last?.id {
                            Divider()
                        }
                    }
                }

                Button("刷新完成记录") {
                    appState.loadRecentEvents()
                }
            }

            SettingsSectionCard("测试") {
                SettingsActions(
                    status: appState.lastStatusMessage,
                    actions: [
                        SettingsAction("测试完整提醒") { appState.testReminder() },
                        SettingsAction("刷新完成记录") { appState.loadRecentEvents() },
                    ]
                )
            }
        }
    }

    private func formattedEventTime(_ timestamp: String) -> String {
        let parser = ISO8601DateFormatter()
        guard let date = parser.date(from: timestamp) else {
            return timestamp
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func eventLabel(_ eventType: String?) -> String {
        switch eventType {
        case "testPassed":
            return "测试通过"
        case "testFailed":
            return "测试失败"
        case "needsAttention":
            return "需要处理"
        default:
            return "任务完成"
        }
    }
}

private struct StatusEventRow: View {
    let event: CodexDoneEvent
    let eventLabel: String
    let formattedTime: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(event.project.isEmpty ? "未知项目" : event.project)
                        .font(.headline)
                    SettingsStatusBadge(text: eventLabel, level: badgeLevel)
                }

                Text(event.rawMessage.isEmpty ? event.message : event.rawMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            Text(formattedTime)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 5)
    }

    private var badgeLevel: SettingsStatusBadge.Level {
        switch event.eventType {
        case "testFailed":
            return .error
        case "needsAttention":
            return .warning
        default:
            return .ok
        }
    }
}
