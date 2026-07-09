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

            SettingsSectionCard("链路诊断", subtitle: "检查 Codex notify、CodexDone wrapper、全局规则和最近 hook 日志。") {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    SettingsStatusBadge(
                        text: diagnosticTitle(appState.codexHookDiagnosticReport.overallSeverity),
                        level: badgeLevel(appState.codexHookDiagnosticReport.overallSeverity)
                    )

                    Text(appState.codexHookDiagnosticReport.notifyRoute)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    SettingsMetricTile(
                        title: "CodexDone notify",
                        value: appState.codexHookDiagnosticReport.codexDoneNotifyConfigured ? "已接入" : "未接入",
                        level: appState.codexHookDiagnosticReport.codexDoneNotifyConfigured ? .ok : .error
                    )
                    SettingsMetricTile(
                        title: "原 Codex 通知器",
                        value: appState.codexHookDiagnosticReport.originalNotifyConfigured ? "已保留" : "未检测",
                        level: appState.codexHookDiagnosticReport.originalNotifyConfigured ? .ok : .neutral
                    )
                    SettingsMetricTile(
                        title: "最近日志",
                        value: "\(appState.codexHookDiagnosticReport.recentLogEntries.count) 条",
                        level: appState.codexHookDiagnosticReport.recentLogEntries.isEmpty ? .warning : .ok
                    )
                }

                LabeledContent("notify 配置") {
                    SettingsPathText(value: appState.codexHookDiagnosticReport.notifyLine ?? "未配置")
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(appState.codexHookDiagnosticReport.findings) { item in
                        DiagnosticFindingRow(item: item)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("最近 hook 日志")
                            .font(.headline)
                        Spacer()
                        SettingsPathText(value: appState.codexHookDiagnosticReport.logURL.path)
                    }

                    if appState.codexHookDiagnosticReport.recentLogEntries.isEmpty {
                        Text("暂无日志")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(appState.codexHookDiagnosticReport.recentLogEntries) { entry in
                                Text(entry.rawLine)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .lineLimit(3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(10)
                        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                    }
                }

                HStack(spacing: 10) {
                    Button("刷新诊断") {
                        appState.refreshCodexHookStatus()
                    }

                    Button(appState.isRunningCodexHookTest ? "自测运行中" : "测试全局 hook") {
                        appState.runCodexGlobalHookSelfTest()
                    }
                    .disabled(appState.isRunningCodexHookTest)

                    Button("复制日志") {
                        appState.copyCodexHookLogs()
                    }
                    .disabled(appState.codexHookDiagnosticReport.recentLogEntries.isEmpty)
                }

                if !appState.lastStatusMessage.isEmpty {
                    Text(appState.lastStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

    private func diagnosticTitle(_ severity: CodexHookDiagnosticSeverity) -> String {
        switch severity {
        case .pass:
            return "链路正常"
        case .warn:
            return "需要注意"
        case .fail:
            return "需要处理"
        }
    }

    private func badgeLevel(_ severity: CodexHookDiagnosticSeverity) -> SettingsStatusBadge.Level {
        switch severity {
        case .pass:
            return .ok
        case .warn:
            return .warning
        case .fail:
            return .error
        }
    }
}

private struct DiagnosticFindingRow: View {
    let item: CodexHookDiagnosticItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.callout)
                    .fontWeight(.semibold)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var systemImage: String {
        switch item.severity {
        case .pass:
            return "checkmark.circle.fill"
        case .warn:
            return "exclamationmark.triangle.fill"
        case .fail:
            return "xmark.octagon.fill"
        }
    }

    private var color: Color {
        switch item.severity {
        case .pass:
            return .green
        case .warn:
            return .orange
        case .fail:
            return .red
        }
    }
}
