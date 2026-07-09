import CodexDoneCore
import SwiftUI

struct SetupGuideSettingsView: View {
    @EnvironmentObject private var appState: AppState

    private var mobilePushReady: Bool {
        guard appState.config.alert.mobilePush else {
            return false
        }

        if appState.config.mobile.provider == "apple_messages" {
            return !appState.config.mobile.recipient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        return !appState.config.mobile.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        SettingsPage(
            title: "首次设置",
            subtitle: "按顺序完成本机命令、Codex hook、自测和推送配置。",
            systemImage: "wand.and.stars"
        ) {
            SettingsSectionCard("安装状态") {
                SetupGuideRow(
                    title: "codex-done 命令",
                    detail: appState.cliAvailable ? appState.cliPath : "未找到可执行命令",
                    level: appState.cliAvailable ? .ok : .error
                )

                SetupGuideRow(
                    title: "Codex 全局 hook",
                    detail: appState.codexHookDiagnosticReport.notifyRoute,
                    level: appState.codexHookStatus.fullyEnabled ? .ok : (appState.codexHookStatus.enabled ? .warning : .error)
                )

                SetupGuideRow(
                    title: "wrapper 日志",
                    detail: appState.codexHookDiagnosticReport.recentLogEntries.isEmpty
                        ? "暂无日志，可运行自测生成第一条记录"
                        : "已读取 \(appState.codexHookDiagnosticReport.recentLogEntries.count) 条最近日志",
                    level: appState.codexHookDiagnosticReport.recentLogEntries.isEmpty ? .warning : .ok
                )

                HStack(spacing: 10) {
                    Button("刷新状态") {
                        appState.refreshCodexHookStatus()
                        appState.runHealthChecks()
                    }

                    Button("启用全局 hook") {
                        appState.enableCodexGlobalHook()
                    }

                    Button("测试全局 hook") {
                        appState.runCodexGlobalHookSelfTest()
                    }
                    .disabled(appState.isRunningCodexHookTest)
                }
            }

            SettingsSectionCard("提醒测试") {
                SetupGuideRow(
                    title: "本机语音/桌面通知",
                    detail: appState.cliAvailable ? "可运行完整提醒测试" : "请先安装 codex-done 命令",
                    level: appState.cliAvailable ? .ok : .error
                )

                SetupGuideRow(
                    title: "手机推送",
                    detail: mobilePushSummary,
                    level: mobilePushReady ? .ok : .warning
                )

                HStack(spacing: 10) {
                    Button("测试完整提醒") {
                        appState.testReminder()
                    }

                    Button("保存配置") {
                        appState.save()
                    }
                }
            }

            SettingsSectionCard("发布版安装") {
                Text("终端中可以运行 `scripts/install.sh` 完成本机安装；需要恢复时运行 `scripts/uninstall.sh`。恢复脚本会保留 `~/.codex-done` 下的用户配置和日志。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                SettingsActions(
                    status: appState.lastStatusMessage,
                    actions: [
                        SettingsAction("复制工作规则") { appState.copyCodexRule() },
                        SettingsAction("刷新诊断") { appState.refreshCodexHookStatus() },
                    ]
                )
            }
        }
    }

    private var mobilePushSummary: String {
        guard appState.config.alert.mobilePush else {
            return "已关闭，可在手机推送页面开启"
        }

        if appState.config.mobile.provider == "apple_messages" {
            return mobilePushReady ? "Apple Messages 接收人已配置" : "缺少 Apple Messages 接收人"
        }

        return mobilePushReady ? "ntfy Topic 已配置" : "缺少 ntfy Topic"
    }
}

private struct SetupGuideRow: View {
    let title: String
    let detail: String
    let level: SettingsStatusBadge.Level

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var systemImage: String {
        switch level {
        case .ok:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        case .neutral:
            return "circle"
        }
    }

    private var color: Color {
        switch level {
        case .ok:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        case .neutral:
            return .secondary
        }
    }
}
