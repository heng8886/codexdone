import Foundation

public enum CodexRuleGenerator {
    public static func rule(commandName: String) -> String {
        """
        每当你完成一个阶段性任务并准备回复我时，如果当前项目中存在 `codex-done`、`scripts/codex-done.sh` 或全局可用的 `\(commandName)` 命令，请在最终回复前运行它，通知内容用一句话概括本阶段完成的工作。普通完成使用默认事件；测试通过可用 `--event testPassed`，测试失败可用 `--event testFailed`，需要我处理时可用 `--event needsAttention`。如果脚本不存在或通知失败，请不要中断任务，正常回复即可。
        """
    }
}
