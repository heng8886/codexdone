import Foundation

public struct CodexGlobalHookStatus: Equatable {
    public let configURL: URL
    public let agentsURL: URL
    public let wrapperURL: URL
    public let hookConfigured: Bool
    public let ruleConfigured: Bool
    public let wrapperInstalled: Bool
    public let detail: String

    public var enabled: Bool {
        hookConfigured || ruleConfigured
    }

    public var fullyEnabled: Bool {
        hookConfigured && ruleConfigured && wrapperInstalled
    }

    public var displayName: String {
        if fullyEnabled {
            return "已启用"
        }
        if enabled {
            return "部分启用"
        }
        return "已停用"
    }
}

public struct CodexGlobalHookManager {
    private let fileManager: FileManager
    private let codexDirectoryURL: URL
    private let cliPath: String
    private let skyClientPath: String

    private var configURL: URL {
        codexDirectoryURL.appendingPathComponent("config.toml")
    }

    private var agentsURL: URL {
        codexDirectoryURL.appendingPathComponent("AGENTS.md")
    }

    private var wrapperURL: URL {
        codexDirectoryURL.appendingPathComponent("codexdone-notify-wrapper.sh")
    }

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        cliPath: String,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.codexDirectoryURL = homeDirectory.appendingPathComponent(".codex", isDirectory: true)
        self.cliPath = cliPath
        self.skyClientPath = homeDirectory
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent("computer-use", isDirectory: true)
            .appendingPathComponent("Codex Computer Use.app", isDirectory: true)
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("SharedSupport", isDirectory: true)
            .appendingPathComponent("SkyComputerUseClient.app", isDirectory: true)
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent("SkyComputerUseClient")
            .path
    }

    public func inspect() -> CodexGlobalHookStatus {
        let configText = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        let agentsText = (try? String(contentsOf: agentsURL, encoding: .utf8)) ?? ""
        let hookConfigured = configText.contains(wrapperURL.path)
            || configText.contains("codexdone-notify-wrapper.sh")
        let ruleConfigured = agentsText.contains(codexDoneRuleHeader)
            || agentsText.contains("codex-done")
        let wrapperInstalled = fileManager.isExecutableFile(atPath: wrapperURL.path)

        let detail: String
        if hookConfigured && ruleConfigured && wrapperInstalled {
            detail = "Codex notify hook、全局规则和 wrapper 均已配置。"
        } else if hookConfigured || ruleConfigured || wrapperInstalled {
            detail = "检测到部分 CodexDone 全局集成，请按需启用或停用以恢复一致状态。"
        } else {
            detail = "CodexDone 没有接管 Codex 全局完成通知。"
        }

        return CodexGlobalHookStatus(
            configURL: configURL,
            agentsURL: agentsURL,
            wrapperURL: wrapperURL,
            hookConfigured: hookConfigured,
            ruleConfigured: ruleConfigured,
            wrapperInstalled: wrapperInstalled,
            detail: detail
        )
    }

    public func enable() throws {
        try fileManager.createDirectory(at: codexDirectoryURL, withIntermediateDirectories: true)
        try installWrapper()
        try upsertNotifyHook()
        try upsertAgentsRule()
    }

    public func disable() throws {
        try disableNotifyHook()
        try removeAgentsRule()
    }

    private func installWrapper() throws {
        let content = wrapperScript()
        if let current = try? String(contentsOf: wrapperURL, encoding: .utf8), current == content {
            try makeExecutable(wrapperURL)
            return
        }

        try content.write(to: wrapperURL, atomically: true, encoding: .utf8)
        try makeExecutable(wrapperURL)
    }

    private func makeExecutable(_ url: URL) throws {
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    private func upsertNotifyHook() throws {
        var text = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        let lines = text.components(separatedBy: .newlines)
        var replaced = false
        var output: [String] = []

        for line in lines {
            guard isNotifyLine(line) else {
                output.append(line)
                continue
            }

            replaced = true
            if line.contains(wrapperURL.path) || line.contains("codexdone-notify-wrapper.sh") {
                output.append(line)
                continue
            }

            let values = parseNotifyValues(from: line)
            if let first = values.first, first.contains("SkyComputerUseClient") {
                output.append(tomlNotifyLine(values: valuesWithCodexDonePreviousNotify(values)))
            } else {
                output.append("# CodexDone saved previous notify: \(line)")
                output.append(tomlNotifyLine(values: directCodexDoneNotifyValues()))
            }
        }

        if !replaced {
            if !text.isEmpty, !text.hasSuffix("\n") {
                text.append("\n")
            }
            text.append(tomlNotifyLine(values: directCodexDoneNotifyValues()))
            text.append("\n")
        } else {
            text = output.joined(separator: "\n")
            if !text.hasSuffix("\n") {
                text.append("\n")
            }
        }

        try text.write(to: configURL, atomically: true, encoding: .utf8)
    }

    private func disableNotifyHook() throws {
        guard fileManager.fileExists(atPath: configURL.path) else {
            return
        }

        let text = try String(contentsOf: configURL, encoding: .utf8)
        let lines = text.components(separatedBy: .newlines)
        var output: [String] = []

        for line in lines {
            guard isNotifyLine(line), line.contains("codexdone-notify-wrapper.sh") else {
                output.append(line)
                continue
            }

            let values = parseNotifyValues(from: line)
            if let first = values.first, first.contains("SkyComputerUseClient") {
                let stripped = valuesWithoutCodexDonePreviousNotify(values)
                if stripped.isEmpty {
                    output.append("# CodexDone disabled previous notify: \(line)")
                } else {
                    output.append(tomlNotifyLine(values: stripped))
                }
            } else {
                output.append("# CodexDone disabled notify: \(line)")
            }
        }

        var updated = output.joined(separator: "\n")
        if !updated.hasSuffix("\n") {
            updated.append("\n")
        }
        try updated.write(to: configURL, atomically: true, encoding: .utf8)
    }

    private func upsertAgentsRule() throws {
        let existing = (try? String(contentsOf: agentsURL, encoding: .utf8)) ?? ""
        guard !existing.contains(codexDoneRuleHeader), !existing.contains(codexDoneMarkerStart) else {
            return
        }

        var text = existing
        if !text.isEmpty, !text.hasSuffix("\n") {
            text.append("\n")
        }
        if !text.isEmpty {
            text.append("\n")
        }
        text.append(codexDoneAgentsBlock)
        text.append("\n")
        try text.write(to: agentsURL, atomically: true, encoding: .utf8)
    }

    private func removeAgentsRule() throws {
        guard fileManager.fileExists(atPath: agentsURL.path) else {
            return
        }

        let text = try String(contentsOf: agentsURL, encoding: .utf8)
        let updated = removeMarkedBlock(from: text) ?? removeLegacyRuleBlock(from: text) ?? text
        guard updated != text else {
            return
        }

        try updated.write(to: agentsURL, atomically: true, encoding: .utf8)
    }

    private func removeMarkedBlock(from text: String) -> String? {
        guard let startRange = text.range(of: codexDoneMarkerStart),
              let endRange = text.range(of: codexDoneMarkerEnd, range: startRange.upperBound..<text.endIndex) else {
            return nil
        }

        var updated = text
        updated.removeSubrange(startRange.lowerBound..<endRange.upperBound)
        return collapseBlankLines(updated)
    }

    private func removeLegacyRuleBlock(from text: String) -> String? {
        guard let startRange = text.range(of: "## \(codexDoneRuleHeader)") else {
            return nil
        }

        let searchStart = startRange.upperBound
        let nextHeaderRange = text.range(
            of: "\n## ",
            options: [],
            range: searchStart..<text.endIndex
        )
        let endIndex = nextHeaderRange?.lowerBound ?? text.endIndex
        var updated = text
        updated.removeSubrange(startRange.lowerBound..<endIndex)
        return collapseBlankLines(updated)
    }

    private func collapseBlankLines(_ text: String) -> String {
        var value = text
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty {
            value.append("\n")
        }
        return value
    }

    private func isNotifyLine(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix("notify =")
    }

    private func parseNotifyValues(from line: String) -> [String] {
        guard let equalsIndex = line.firstIndex(of: "=") else {
            return []
        }

        let rawArray = String(line[line.index(after: equalsIndex)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = rawArray.data(using: .utf8),
              let values = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return []
        }

        return values
    }

    private func tomlNotifyLine(values: [String]) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: values, options: [])) ?? Data("[]".utf8)
        let arrayText = String(data: data, encoding: .utf8) ?? "[]"
        return "notify = \(arrayText)"
    }

    private func directCodexDoneNotifyValues() -> [String] {
        [wrapperURL.path, "turn-ended"]
    }

    private func valuesWithCodexDonePreviousNotify(_ values: [String]) -> [String] {
        var output = valuesWithoutCodexDonePreviousNotify(values)
        output.append("--previous-notify")
        output.append(jsonString(directCodexDoneNotifyValues()))
        return output
    }

    private func valuesWithoutCodexDonePreviousNotify(_ values: [String]) -> [String] {
        var output: [String] = []
        var index = 0
        while index < values.count {
            let value = values[index]
            if value == "--previous-notify", index + 1 < values.count {
                let previous = values[index + 1]
                if previous.contains(wrapperURL.path) || previous.contains("codexdone-notify-wrapper.sh") {
                    index += 2
                    continue
                }
            }

            output.append(value)
            index += 1
        }
        return output
    }

    private func jsonString(_ values: [String]) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: values, options: [])) ?? Data("[]".utf8)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private func wrapperScript() -> String {
        """
        #!/usr/bin/env bash
        set -u

        SKY_CLIENT="\(escapeForBashDoubleQuoted(skyClientPath))"
        CODEX_DONE_COMMAND="${CODEX_DONE_COMMAND:-\(escapeForBashDoubleQuoted(cliPath))}"
        LOG_FILE="${HOME}/.codex/codexdone-notify-wrapper.log"
        EVENT_NAME="${1:-turn-ended}"
        MESSAGE="${CODEX_DONE_NOTIFY_MESSAGE:-Codex 本轮工作已完成}"

        log() {
          printf '[%s] %s\\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" >> "${LOG_FILE}" 2>/dev/null || true
        }

        recent_same_cwd_event_exists() {
          python3 - "$PWD" "${HOME}/.codex-done/events.jsonl" <<'PY'
        import json
        import os
        import sys
        import time
        from pathlib import Path

        cwd = sys.argv[1]
        events_path = Path(sys.argv[2])
        window = float(os.environ.get("CODEX_DONE_NOTIFY_DEDUP_SECONDS", "5"))

        if window <= 0 or not events_path.exists():
            sys.exit(1)

        try:
            lines = events_path.read_text(encoding="utf-8").splitlines()
        except OSError:
            sys.exit(1)

        now = time.time()
        for line in reversed(lines[-50:]):
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue

            epoch = float(event.get("epoch") or 0)
            age = now - epoch
            if age > window:
                break

            if event.get("source") == "codex-done" and event.get("cwd") == cwd:
                sys.exit(0)

        sys.exit(1)
        PY
        }

        log "notify hook received event=${EVENT_NAME} cwd=${PWD}"

        if [[ -x "${SKY_CLIENT}" ]]; then
          if [[ "${EVENT_NAME}" == "turn-ended" && "$#" -lt 2 ]]; then
            log "skip original notify client because payload was not supplied"
          else
            "${SKY_CLIENT}" "$@" >> "${LOG_FILE}" 2>&1 || log "original notify client failed"
          fi
        fi

        case "${EVENT_NAME}" in
          turn-ended|taskCompleted|completed|done|"")
            if recent_same_cwd_event_exists; then
              log "skip codex-done because a recent same-cwd event already exists"
              exit 0
            fi

            if [[ -x "${CODEX_DONE_COMMAND}" ]]; then
              "${CODEX_DONE_COMMAND}" --event taskCompleted "${MESSAGE}" >> "${LOG_FILE}" 2>&1 || log "codex-done command failed"
            elif command -v codex-done >/dev/null 2>&1; then
              codex-done --event taskCompleted "${MESSAGE}" >> "${LOG_FILE}" 2>&1 || log "codex-done command failed"
            else
              log "codex-done command not found"
            fi
            ;;
          *)
            log "skip codex-done for unsupported event=${EVENT_NAME}"
            ;;
        esac

        exit 0
        """
    }

    private func escapeForBashDoubleQuoted(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")
    }
}

private let codexDoneRuleHeader = "CodexDone Task Completion Notification"
private let codexDoneMarkerStart = "<!-- codexdone:global-hook:start -->"
private let codexDoneMarkerEnd = "<!-- codexdone:global-hook:end -->"

private let codexDoneAgentsBlock = """
\(codexDoneMarkerStart)
## \(codexDoneRuleHeader)

Whenever you complete a stage of work and are about to send the final reply, run `codex-done` if it is available. Use one short sentence to summarize what was completed.

Examples:

```bash
codex-done "本阶段工作已经完成"
codex-done --event testPassed "测试已通过"
codex-done --event testFailed "测试失败，需要查看日志"
codex-done --event needsAttention "需要你确认下一步"
```

If `codex-done` is unavailable or the notification fails, do not interrupt the task; reply normally and mention the notification failure briefly.
\(codexDoneMarkerEnd)
"""
