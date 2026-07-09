import CodexDoneCore
import Foundation

enum HealthCheckStatus: String, CaseIterable, Identifiable {
    case pass
    case warn
    case fail

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pass:
            return "正常"
        case .warn:
            return "注意"
        case .fail:
            return "需处理"
        }
    }

    var systemImage: String {
        switch self {
        case .pass:
            return "checkmark.circle.fill"
        case .warn:
            return "exclamationmark.triangle.fill"
        case .fail:
            return "xmark.octagon.fill"
        }
    }
}

struct HealthCheckItem: Identifiable, Equatable {
    let id: String
    let label: String
    let status: HealthCheckStatus
    let summary: String
    let detail: String
}

struct HealthCheckSummary: Equatable {
    var pass: Int
    var warn: Int
    var fail: Int

    init(checks: [HealthCheckItem]) {
        pass = checks.filter { $0.status == .pass }.count
        warn = checks.filter { $0.status == .warn }.count
        fail = checks.filter { $0.status == .fail }.count
    }

    var overallStatus: HealthCheckStatus {
        if fail > 0 {
            return .fail
        }
        if warn > 0 {
            return .warn
        }
        return .pass
    }
}

struct HealthCheckService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func run(
        config: CodexDoneConfig,
        cliPath: String,
        configPath: String,
        envPath: String,
        eventsPath: String,
        openAIKeyConfigured: Bool
    ) -> [HealthCheckItem] {
        let configDirectory = writableDirectory(for: configPath)
        let eventsDirectory = writableDirectory(for: eventsPath)
        let topicConfigured = hasText(config.mobile.topic)
            || hasText(ProcessInfo.processInfo.environment["CODEX_NOTIFY_TOPIC"])
        let futureVoiceProvider = config.futureVoice.provider?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let launchAgentPath = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("local.codexdone.app.plist")
            .path
        let bundlePath = Bundle.main.bundlePath

        var checks: [HealthCheckItem] = []

        checks.append(item(
            id: "cli",
            label: "codex-done 命令",
            status: fileManager.isExecutableFile(atPath: cliPath) ? .pass : .fail,
            summary: fileManager.isExecutableFile(atPath: cliPath) ? "可执行脚本可用" : "未找到可执行脚本",
            detail: cliPath
        ))

        checks.append(configFileItem(configPath: configPath))

        checks.append(item(
            id: "config-directory",
            label: "配置目录",
            status: configDirectory.ok ? .pass : .fail,
            summary: configDirectory.ok ? "配置目录可写" : "配置目录不可写",
            detail: configDirectory.detail
        ))

        checks.append(commandItem(
            id: "say",
            label: "macOS say",
            commandPath: "/usr/bin/say",
            availableSummary: "本机语音命令可用",
            missingSummary: "缺少 /usr/bin/say"
        ))

        checks.append(commandItem(
            id: "osascript",
            label: "桌面通知",
            commandPath: "/usr/bin/osascript",
            availableSummary: "通知中心脚本命令可用",
            missingSummary: "缺少 /usr/bin/osascript"
        ))

        checks.append(commandItem(
            id: "afplay",
            label: "提示音播放",
            commandPath: "/usr/bin/afplay",
            availableSummary: "提示音播放命令可用",
            missingSummary: "缺少 /usr/bin/afplay"
        ))

        checks.append(item(
            id: "events",
            label: "事件日志",
            status: eventsDirectory.ok ? .pass : .fail,
            summary: eventsDirectory.ok ? "事件日志目录可写" : "事件日志目录不可写",
            detail: eventsDirectory.detail
        ))

        checks.append(item(
            id: "ntfy",
            label: "手机推送 ntfy",
            status: config.alert.mobilePush ? (topicConfigured ? .pass : .warn) : .warn,
            summary: config.alert.mobilePush
                ? (topicConfigured ? "手机推送 Topic 已配置" : "手机推送已开启，但还没有 Topic")
                : "手机推送已关闭",
            detail: hasText(config.mobile.topic) ? config.mobile.topic : "CODEX_NOTIFY_TOPIC / mobile.topic"
        ))

        let curlAvailable = fileManager.isExecutableFile(atPath: "/usr/bin/curl")
        checks.append(item(
            id: "curl",
            label: "手机推送网络命令",
            status: curlAvailable ? .pass : (config.alert.mobilePush && topicConfigured ? .fail : .warn),
            summary: curlAvailable ? "curl 可用，可发送 ntfy 请求" : "缺少 curl，手机推送将无法发送",
            detail: "/usr/bin/curl"
        ))

        checks.append(item(
            id: "future-voice",
            label: "真人语音服务商",
            status: futureVoiceStatus(provider: futureVoiceProvider, openAIKeyConfigured: openAIKeyConfigured),
            summary: futureVoiceSummary(provider: futureVoiceProvider, openAIKeyConfigured: openAIKeyConfigured),
            detail: futureVoiceProvider == "openai" ? envPath : (futureVoiceProvider.isEmpty ? "macOS say" : futureVoiceProvider)
        ))

        checks.append(item(
            id: "launch-agent",
            label: "开机启动",
            status: fileManager.fileExists(atPath: launchAgentPath) ? .pass : .warn,
            summary: fileManager.fileExists(atPath: launchAgentPath) ? "LaunchAgent 已安装" : "尚未安装 LaunchAgent，需手动启动 App",
            detail: launchAgentPath
        ))

        checks.append(item(
            id: "app-bundle",
            label: "macOS App 包",
            status: bundlePath.hasSuffix(".app") ? .pass : .warn,
            summary: bundlePath.hasSuffix(".app") ? "当前以 App 包运行" : "当前不是从 .app 包运行，打包后会变为正常",
            detail: bundlePath
        ))

        return checks
    }

    private func item(
        id: String,
        label: String,
        status: HealthCheckStatus,
        summary: String,
        detail: String
    ) -> HealthCheckItem {
        HealthCheckItem(id: id, label: label, status: status, summary: summary, detail: detail)
    }

    private func commandItem(
        id: String,
        label: String,
        commandPath: String,
        availableSummary: String,
        missingSummary: String
    ) -> HealthCheckItem {
        item(
            id: id,
            label: label,
            status: fileManager.isExecutableFile(atPath: commandPath) ? .pass : .fail,
            summary: fileManager.isExecutableFile(atPath: commandPath) ? availableSummary : missingSummary,
            detail: commandPath
        )
    }

    private func configFileItem(configPath: String) -> HealthCheckItem {
        guard fileManager.fileExists(atPath: configPath) else {
            return item(
                id: "config",
                label: "配置文件",
                status: .warn,
                summary: "尚未创建配置文件，当前使用默认配置",
                detail: configPath
            )
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
            _ = try JSONDecoder().decode(CodexDoneConfig.self, from: data)
            return item(
                id: "config",
                label: "配置文件",
                status: .pass,
                summary: "配置文件已加载",
                detail: configPath
            )
        } catch {
            return item(
                id: "config",
                label: "配置文件",
                status: .fail,
                summary: "配置文件读取失败",
                detail: error.localizedDescription
            )
        }
    }

    private func writableDirectory(for filePath: String) -> (ok: Bool, detail: String) {
        let directory = URL(fileURLWithPath: filePath).deletingLastPathComponent()

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return (
                fileManager.isWritableFile(atPath: directory.path),
                directory.path
            )
        } catch {
            return (false, error.localizedDescription)
        }
    }

    private func futureVoiceStatus(
        provider: String,
        openAIKeyConfigured: Bool
    ) -> HealthCheckStatus {
        if provider == "openai" {
            return openAIKeyConfigured ? .pass : .fail
        }
        if provider.isEmpty {
            return .pass
        }
        return .warn
    }

    private func futureVoiceSummary(
        provider: String,
        openAIKeyConfigured: Bool
    ) -> String {
        if provider == "openai" {
            return openAIKeyConfigured ? "OpenAI TTS 已具备 Key" : "已选择 OpenAI TTS，但还缺 API Key"
        }
        if provider.isEmpty {
            return "当前使用 macOS say，不需要云端 Key"
        }
        return "该服务商已保存为预留配置，当前 CLI 会回退到 macOS say"
    }

    private func hasText(_ value: String?) -> Bool {
        !(value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
}
