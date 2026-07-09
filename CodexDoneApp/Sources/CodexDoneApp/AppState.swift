import AppKit
import Combine
import CodexDoneCore
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var config: CodexDoneConfig
    @Published var lastStatusMessage: String = "准备就绪"
    @Published var systemVoices: [MacOSVoice] = []
    @Published var isLoadingVoices = false
    @Published var systemSounds: [MacOSSound] = []
    @Published var isLoadingSounds = false
    @Published var openAIKeyConfigured = false
    @Published var openAIKeyMasked = ""
    @Published var openAIKeySource = ""
    @Published var recentEvents: [CodexDoneEvent] = []
    @Published var healthChecks: [HealthCheckItem] = []
    @Published var lastHealthCheckAt: Date?
    @Published var codexHookStatus: CodexGlobalHookStatus

    private let store: ConfigStore
    private let envStore: EnvStore
    private let eventStore: EventStore
    private var activeTestProcess: Process?
    private var activeTestProcessID: UUID?
    private var activeVoicePreviewProcess: Process?
    private var activeVoicePreviewProcessID: UUID?
    private var activeSoundPreviewProcess: Process?
    private var activeSoundPreviewProcessID: UUID?

    init(
        store: ConfigStore = ConfigStore(),
        envStore: EnvStore = EnvStore(),
        eventStore: EventStore = EventStore()
    ) {
        self.store = store
        self.envStore = envStore
        self.eventStore = eventStore
        self.codexHookStatus = CodexGlobalHookManager(cliPath: "/usr/local/bin/codex-done").inspect()
        do {
            self.config = try store.load()
        } catch {
            self.config = .default
        }
        refreshOpenAIKeyStatus()
        runHealthChecks()
        loadRecentEvents()
        loadSystemVoices()
        loadSystemSounds()
        refreshCodexHookStatus()
    }

    var configPath: String {
        store.configURL.path
    }

    var cliPath: String {
        CodexDonePaths.defaultCLIPath()
    }

    var cliAvailable: Bool {
        FileManager.default.isExecutableFile(atPath: cliPath)
    }

    var preferredGlobalCLIPath: String {
        let localBinPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("codex-done")
            .path

        if FileManager.default.isExecutableFile(atPath: localBinPath) {
            return localBinPath
        }

        return cliPath
    }

    var envPath: String {
        envStore.envURL.path
    }

    var eventsPath: String {
        eventStore.eventsURL.path
    }

    var notifyStatePath: String {
        eventStore.notifyStateURL.path
    }

    var voiceProviderDisplayName: String {
        switch config.futureVoice.provider {
        case nil:
            return "macOS say（本机默认）"
        case "openai":
            return "OpenAI TTS"
        case "elevenlabs":
            return "ElevenLabs"
        case "azure":
            return "Azure Speech"
        case "google":
            return "Google Cloud TTS"
        case "amazon_polly":
            return "Amazon Polly"
        case "edge_tts":
            return "Edge TTS"
        case "custom":
            return "自定义 HTTP"
        default:
            return config.futureVoice.provider ?? "macOS say（本机默认）"
        }
    }

    var openAIKeyStatusText: String {
        openAIKeyConfigured
            ? "已配置（\(openAIKeySource)\(openAIKeyMasked.isEmpty ? "" : " · \(openAIKeyMasked)")）"
            : "未配置"
    }

    var healthSummary: HealthCheckSummary {
        HealthCheckSummary(checks: healthChecks)
    }

    func showSettingsWindow() {
        SettingsWindowManager.shared.show(appState: self)
    }

    func quitApp() {
        activeTestProcess?.terminate()
        activeVoicePreviewProcess?.terminate()
        activeSoundPreviewProcess?.terminate()
        NSApp.terminate(nil)
    }

    @discardableResult
    func save() -> Bool {
        do {
            try store.save(config)
            lastStatusMessage = "配置已保存"
            runHealthChecks()
            return true
        } catch {
            lastStatusMessage = "配置保存失败：\(error.localizedDescription)"
            return false
        }
    }

    func reload() {
        do {
            config = try store.load()
        } catch {
            config = .default
        }
        refreshOpenAIKeyStatus()
        runHealthChecks()
        loadRecentEvents()
        lastStatusMessage = "配置已重新读取"
    }

    func runHealthChecks() {
        let service = HealthCheckService()
        healthChecks = service.run(
            config: config,
            cliPath: cliPath,
            configPath: configPath,
            envPath: envPath,
            eventsPath: eventsPath,
            openAIKeyConfigured: openAIKeyConfigured
        )
        lastHealthCheckAt = Date()
    }

    func refreshCodexHookStatus() {
        codexHookStatus = CodexGlobalHookManager(cliPath: preferredGlobalCLIPath).inspect()
    }

    func enableCodexGlobalHook() {
        do {
            try CodexGlobalHookManager(cliPath: preferredGlobalCLIPath).enable()
            refreshCodexHookStatus()
            runHealthChecks()
            lastStatusMessage = "Codex 全局 hook 已启用"
        } catch {
            refreshCodexHookStatus()
            lastStatusMessage = "启用 Codex 全局 hook 失败：\(error.localizedDescription)"
        }
    }

    func disableCodexGlobalHook() {
        do {
            try CodexGlobalHookManager(cliPath: preferredGlobalCLIPath).disable()
            refreshCodexHookStatus()
            runHealthChecks()
            lastStatusMessage = "Codex 全局 hook 已停用"
        } catch {
            refreshCodexHookStatus()
            lastStatusMessage = "停用 Codex 全局 hook 失败：\(error.localizedDescription)"
        }
    }

    func loadRecentEvents() {
        do {
            recentEvents = try eventStore.loadRecent(limit: 20)
        } catch {
            recentEvents = []
        }
    }

    func clearEvents() {
        do {
            try eventStore.clear()
            recentEvents = []
            lastStatusMessage = "完成记录已清空"
        } catch {
            lastStatusMessage = "完成记录清空失败：\(error.localizedDescription)"
        }
    }

    func refreshOpenAIKeyStatus() {
        let localKey = (try? envStore.loadOpenAIAPIKey()) ?? nil
        if let localKey, !localKey.isEmpty {
            openAIKeyConfigured = true
            openAIKeyMasked = maskSecret(localKey)
            openAIKeySource = "本机密钥文件"
            runHealthChecks()
            return
        }

        let inheritedKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let inheritedKey, !inheritedKey.isEmpty {
            openAIKeyConfigured = true
            openAIKeyMasked = maskSecret(inheritedKey)
            openAIKeySource = "启动环境"
            runHealthChecks()
            return
        }

        openAIKeyConfigured = false
        openAIKeyMasked = ""
        openAIKeySource = ""
        runHealthChecks()
    }

    @discardableResult
    func saveOpenAIKey(_ apiKey: String) -> Bool {
        do {
            try envStore.saveOpenAIAPIKey(apiKey)
            refreshOpenAIKeyStatus()
            runHealthChecks()
            lastStatusMessage = "API Key 已保存到本机密钥文件"
            return true
        } catch {
            lastStatusMessage = "API Key 保存失败：\(error.localizedDescription)"
            return false
        }
    }

    func clearOpenAIKey() {
        do {
            try envStore.clearOpenAIAPIKey()
            refreshOpenAIKeyStatus()
            runHealthChecks()
            lastStatusMessage = "已清除本机保存的 API Key"
        } catch {
            lastStatusMessage = "API Key 清除失败：\(error.localizedDescription)"
        }
    }

    func loadSystemVoices() {
        guard !isLoadingVoices else {
            return
        }

        isLoadingVoices = true
        Task {
            let voices = await Task.detached(priority: .utility) {
                MacOSVoiceCatalog.availableVoices()
            }.value

            systemVoices = voices
            isLoadingVoices = false
            if voices.isEmpty {
                lastStatusMessage = "未读取到系统语音"
            }
        }
    }

    func loadSystemSounds() {
        guard !isLoadingSounds else {
            return
        }

        isLoadingSounds = true
        Task {
            let sounds = await Task.detached(priority: .utility) {
                MacOSSoundCatalog.availableSounds()
            }.value

            systemSounds = sounds
            isLoadingSounds = false
            if sounds.isEmpty {
                lastStatusMessage = "未读取到系统提示音"
            }
        }
    }

    func previewVoice() {
        guard activeVoicePreviewProcess == nil else {
            lastStatusMessage = "语音试听仍在运行"
            return
        }

        let message = previewMessage()
        let process = Process()
        let processID = UUID()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = sayArguments(for: message)
        process.terminationHandler = { [weak self] completedProcess in
            let terminationStatus = completedProcess.terminationStatus

            Task { @MainActor [weak self] in
                guard let self, self.activeVoicePreviewProcessID == processID else {
                    return
                }

                self.activeVoicePreviewProcess = nil
                self.activeVoicePreviewProcessID = nil
                self.lastStatusMessage = terminationStatus == 0
                    ? "语音试听已完成"
                    : "语音试听失败：退出码 \(terminationStatus)"
            }
        }

        do {
            activeVoicePreviewProcess = process
            activeVoicePreviewProcessID = processID
            try process.run()
            lastStatusMessage = "语音试听运行中"
        } catch {
            activeVoicePreviewProcess = nil
            activeVoicePreviewProcessID = nil
            lastStatusMessage = "无法试听语音：\(error.localizedDescription)"
        }
    }

    func previewSound() {
        guard activeSoundPreviewProcess == nil else {
            lastStatusMessage = "提示音试听仍在运行"
            return
        }

        guard let soundURL = MacOSSoundCatalog.soundURL(
            named: config.sound.name,
            customFilePath: config.sound.customFilePath
        ) else {
            lastStatusMessage = "未找到可试听的提示音"
            return
        }

        let process = Process()
        let processID = UUID()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
        process.arguments = [soundURL.path]
        process.terminationHandler = { [weak self] completedProcess in
            let terminationStatus = completedProcess.terminationStatus

            Task { @MainActor [weak self] in
                guard let self, self.activeSoundPreviewProcessID == processID else {
                    return
                }

                self.activeSoundPreviewProcess = nil
                self.activeSoundPreviewProcessID = nil
                self.lastStatusMessage = terminationStatus == 0
                    ? "提示音试听已完成"
                    : "提示音试听失败：退出码 \(terminationStatus)"
            }
        }

        do {
            activeSoundPreviewProcess = process
            activeSoundPreviewProcessID = processID
            try process.run()
            lastStatusMessage = "提示音试听运行中"
        } catch {
            activeSoundPreviewProcess = nil
            activeSoundPreviewProcessID = nil
            lastStatusMessage = "无法试听提示音：\(error.localizedDescription)"
        }
    }

    func testReminder(
        eventType: String = "taskCompleted",
        message: String = "CodexDone 测试提醒"
    ) {
        guard activeTestProcess == nil else {
            lastStatusMessage = "测试提醒仍在运行"
            return
        }

        guard save() else {
            return
        }

        let process = Process()
        let processID = UUID()
        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = ["--event", eventType, message]
        process.environment = processEnvironmentForReminder()
        process.terminationHandler = { [weak self] completedProcess in
            let terminationStatus = completedProcess.terminationStatus

            Task { @MainActor [weak self] in
                guard let self, self.activeTestProcessID == processID else {
                    return
                }

                self.activeTestProcess = nil
                self.activeTestProcessID = nil
                if terminationStatus == 0 {
                    self.loadRecentEvents()
                    self.runHealthChecks()
                    self.lastStatusMessage = "测试提醒已完成"
                } else {
                    self.lastStatusMessage = "codex-done 执行失败：退出码 \(terminationStatus)"
                }
            }
        }

        do {
            activeTestProcess = process
            activeTestProcessID = processID
            try process.run()
            lastStatusMessage = "测试提醒运行中"
        } catch {
            activeTestProcess = nil
            activeTestProcessID = nil
            lastStatusMessage = "无法运行 codex-done：\(error.localizedDescription)"
        }
    }

    func copyCodexRule() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let copied = pasteboard.setString(
            CodexRuleGenerator.rule(commandName: "codex-done"),
            forType: .string
        )
        lastStatusMessage = copied ? "Codex 工作规则已复制" : "Codex 工作规则复制失败"
    }

    private func previewMessage() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let rendered = TemplateRenderer.render(
            config.voice.messageTemplate,
            context: TemplateContext(
                project: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).lastPathComponent,
                message: "这是 CodexDone 语音试听",
                time: formatter.string(from: Date())
            )
        )

        return rendered.isEmpty ? "这是 CodexDone 语音试听" : rendered
    }

    private func sayArguments(for message: String) -> [String] {
        var arguments: [String] = []
        if let voiceName = config.voice.voiceName, !voiceName.isEmpty {
            arguments.append(contentsOf: ["-v", voiceName])
        }
        arguments.append(contentsOf: ["-r", "\(config.voice.rate)", message])
        return arguments
    }

    private func processEnvironmentForReminder() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["CODEX_DONE_CONFIG"] = store.configURL.path
        environment["CODEX_DONE_ENV"] = envStore.envURL.path
        environment["CODEX_DONE_EVENTS"] = eventStore.eventsURL.path
        environment["CODEX_DONE_NOTIFY_STATE"] = eventStore.notifyStateURL.path
        if let localKey = try? envStore.loadOpenAIAPIKey(), !localKey.isEmpty {
            environment["OPENAI_API_KEY"] = localKey
        }
        return environment
    }

    private func maskSecret(_ value: String) -> String {
        guard value.count > 8 else {
            return "••••"
        }

        return "\(value.prefix(3))…\(value.suffix(4))"
    }
}
