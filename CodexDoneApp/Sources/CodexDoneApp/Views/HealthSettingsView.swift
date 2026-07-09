import SwiftUI

struct HealthSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SettingsPage(
            title: "健康检查",
            subtitle: "检查本机命令、配置文件、手机推送和语音服务是否可用。",
            systemImage: "checklist"
        ) {
            SettingsSectionCard("健康概览") {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
                    alignment: .leading,
                    spacing: 12
                ) {
                    SettingsMetricTile(
                        title: "整体状态",
                        value: appState.healthSummary.overallStatus.displayName,
                        level: metricLevel(appState.healthSummary.overallStatus)
                    )
                    SettingsMetricTile(
                        title: "正常",
                        value: "\(appState.healthSummary.pass)",
                        level: .ok
                    )
                    SettingsMetricTile(
                        title: "注意",
                        value: "\(appState.healthSummary.warn)",
                        level: .warning
                    )
                    SettingsMetricTile(
                        title: "需处理",
                        value: "\(appState.healthSummary.fail)",
                        level: .error
                    )
                }

                if let lastHealthCheckAt = appState.lastHealthCheckAt {
                    Text("最近检查：\(formattedDate(lastHealthCheckAt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("重新检查") {
                    appState.runHealthChecks()
                }
            }

            SettingsSectionCard("检查项") {
                ForEach(appState.healthChecks) { check in
                    HealthCheckRow(check: check)

                    if check.id != appState.healthChecks.last?.id {
                        Divider()
                    }
                }
            }

            SettingsSectionCard("快速验证") {
                Text("核心检查正常后，可以运行一次完整提醒测试，验证语音、桌面通知、手机推送和事件日志是否能完整串起来。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                SettingsActions(
                    status: appState.lastStatusMessage,
                    actions: [
                        SettingsAction("测试完整提醒") { appState.testReminder() },
                        SettingsAction("重新检查") { appState.runHealthChecks() },
                    ]
                )
            }
        }
        .onAppear {
            appState.runHealthChecks()
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private func metricLevel(_ status: HealthCheckStatus) -> SettingsStatusBadge.Level {
        switch status {
        case .pass:
            return .ok
        case .warn:
            return .warning
        case .fail:
            return .error
        }
    }
}

private struct HealthCheckRow: View {
    let check: HealthCheckItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: check.status.systemImage)
                .foregroundStyle(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(check.label)
                        .font(.headline)
                    Spacer()
                    SettingsStatusBadge(text: check.status.displayName, level: level)
                }

                Text(check.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !check.detail.isEmpty {
                    Text(check.detail)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var color: Color {
        switch check.status {
        case .pass:
            return .green
        case .warn:
            return .orange
        case .fail:
            return .red
        }
    }

    private var level: SettingsStatusBadge.Level {
        switch check.status {
        case .pass:
            return .ok
        case .warn:
            return .warning
        case .fail:
            return .error
        }
    }
}
