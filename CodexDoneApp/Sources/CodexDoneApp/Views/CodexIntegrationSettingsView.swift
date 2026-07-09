import CodexDoneCore
import SwiftUI

struct CodexIntegrationSettingsView: View {
    @EnvironmentObject private var appState: AppState

    private var rule: String { CodexRuleGenerator.rule(commandName: "codex-done") }

    var body: some View {
        SettingsPage(
            title: "Codex 集成",
            subtitle: "复制给 Codex 的工作规则，并确认命令入口路径。",
            systemImage: "terminal"
        ) {
            SettingsSectionCard("安全开关", subtitle: "控制 CodexDone 是否接入 Codex 全局完成通知。停用后不会删除 CodexDone App，只会停止全局 hook 和全局工作规则。") {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    SettingsStatusBadge(
                        text: appState.codexHookStatus.displayName,
                        level: appState.codexHookStatus.fullyEnabled
                            ? .ok
                            : (appState.codexHookStatus.enabled ? .warning : .neutral)
                    )

                    Text(appState.codexHookStatus.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text("notify hook")
                            .foregroundStyle(.secondary)
                        hookStatusText(appState.codexHookStatus.hookConfigured)
                    }
                    GridRow {
                        Text("全局规则")
                            .foregroundStyle(.secondary)
                        hookStatusText(appState.codexHookStatus.ruleConfigured)
                    }
                    GridRow {
                        Text("wrapper")
                            .foregroundStyle(.secondary)
                        hookStatusText(appState.codexHookStatus.wrapperInstalled)
                    }
                }
                .font(.callout)

                SettingsActions(
                    status: appState.lastStatusMessage,
                    actions: [
                        SettingsAction("刷新状态") { appState.refreshCodexHookStatus() },
                        SettingsAction("启用全局 hook") { appState.enableCodexGlobalHook() },
                        SettingsAction("停用全局 hook", role: .destructive) { appState.disableCodexGlobalHook() },
                    ]
                )
            }

            SettingsSectionCard("命令路径") {
                LabeledContent("codex-done") {
                    SettingsPathText(value: appState.cliPath)
                }
            }

            SettingsSectionCard("全局文件位置") {
                LabeledContent("Codex 配置") {
                    SettingsPathText(value: appState.codexHookStatus.configURL.path)
                }
                LabeledContent("Codex 全局规则") {
                    SettingsPathText(value: appState.codexHookStatus.agentsURL.path)
                }
                LabeledContent("通知 wrapper") {
                    SettingsPathText(value: appState.codexHookStatus.wrapperURL.path)
                }
            }

            SettingsSectionCard("Codex 工作规则") {
                Text(rule)
                    .font(.body)
                    .lineSpacing(3)
                    .textSelection(.enabled)

                SettingsActions(
                    status: appState.lastStatusMessage,
                    actions: [
                        SettingsAction("复制工作规则") { appState.copyCodexRule() },
                    ]
                )
            }

            SettingsSectionCard("示例") {
                Text("./codex-done \"代码修改完成，测试已通过\"")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder
    private func hookStatusText(_ enabled: Bool) -> some View {
        Label(enabled ? "已配置" : "未配置", systemImage: enabled ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(enabled ? .green : .secondary)
    }
}
