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
            SettingsSectionCard("命令路径") {
                LabeledContent("codex-done") {
                    SettingsPathText(value: appState.cliPath)
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
}
