import SwiftUI

struct VoiceContentSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var openAIAPIKeyInput = ""

    private let fallbackLanguages = ["zh-CN", "en-US", "en-GB", "ja-JP", "ko-KR"]
    private let preferredLanguages: [(value: String, label: String)] = [
        ("zh-CN", "中文（简体）"),
        ("zh-TW", "中文（繁体）"),
        ("zh-HK", "中文（香港）"),
        ("en-US", "English (US)"),
        ("en-GB", "English (UK)"),
        ("ja-JP", "日本語"),
        ("ko-KR", "한국어"),
        ("fr-FR", "Français"),
        ("de-DE", "Deutsch"),
        ("es-ES", "Español"),
        ("pt-BR", "Português")
    ]
    private let futureVoiceProviders: [(value: String, label: String)] = [
        ("", "macOS say（本机默认）"),
        ("openai", "OpenAI TTS"),
        ("elevenlabs", "ElevenLabs"),
        ("azure", "Azure Speech"),
        ("google", "Google Cloud TTS"),
        ("amazon_polly", "Amazon Polly"),
        ("edge_tts", "Edge TTS"),
        ("custom", "自定义 HTTP")
    ]
    private let openAIVoices = ["marin", "cedar", "alloy", "ash", "ballad", "coral", "echo", "fable", "nova", "onyx", "sage", "shimmer", "verse"]
    private let genderPreferences = ["", "female", "male", "neutral"]
    private let voiceStyles = ["", "natural", "warm", "calm", "energetic", "formal"]

    private var languageOptions: [String] {
        let discoveredLanguages = Set(appState.systemVoices.map(\.languageCode))
        var baseLanguages = discoveredLanguages.isEmpty
            ? fallbackLanguages
            : preferredLanguages.map(\.value).filter { discoveredLanguages.contains($0) }
        if baseLanguages.isEmpty {
            baseLanguages = fallbackLanguages
        }
        let currentLanguage = appState.config.voice.language
        guard !currentLanguage.isEmpty, !baseLanguages.contains(currentLanguage) else {
            return baseLanguages
        }

        return baseLanguages + [currentLanguage]
    }

    private var voiceOptions: [String] {
        let matchingVoices = appState.systemVoices
            .filter { $0.languageCode == appState.config.voice.language }
        let visibleVoices = matchingVoices.isEmpty ? appState.systemVoices : matchingVoices
        var options = [""] + visibleVoices.map(\.name)

        if let currentVoice = appState.config.voice.voiceName,
           !currentVoice.isEmpty,
           !options.contains(currentVoice) {
            options.append(currentVoice)
        }

        return Array(NSOrderedSet(array: options)) as? [String] ?? options
    }

    private var voiceCountText: String {
        if appState.isLoadingVoices {
            return "正在读取系统语音..."
        }

        return appState.systemVoices.isEmpty
            ? "未读取到系统语音，仍可手动保留当前声音"
            : "已读取 \(appState.systemVoices.count) 个系统语音"
    }

    private func voiceLabel(for voiceName: String) -> String {
        guard !voiceName.isEmpty else {
            return "系统默认"
        }

        guard let voice = appState.systemVoices.first(where: { $0.name == voiceName }) else {
            return voiceName
        }

        return "\(voice.name) (\(voice.languageCode))"
    }

    private func futureOptionLabel(_ value: String, emptyLabel: String) -> String {
        value.isEmpty ? emptyLabel : value
    }

    private func languageLabel(for language: String) -> String {
        preferredLanguages.first(where: { $0.value == language })?.label ?? language
    }

    private func futureProviderLabel(_ provider: String?) -> String {
        let value = provider ?? ""
        return futureVoiceProviders.first(where: { $0.value == value })?.label ?? value
    }

    private var futureProviderStatusText: String {
        switch appState.config.futureVoice.provider {
        case nil:
            return "当前使用 macOS say"
        case "openai":
            return appState.openAIKeyConfigured ? "OpenAI TTS 已可用" : "还缺 OPENAI_API_KEY"
        default:
            return "预留配置，当前回退 macOS say"
        }
    }

    private var futureProviderReady: Bool {
        appState.config.futureVoice.provider == nil
            || (appState.config.futureVoice.provider == "openai" && appState.openAIKeyConfigured)
    }

    private var futureProviderGuide: [String] {
        switch appState.config.futureVoice.provider {
        case nil:
            return [
                "使用上方 macOS say 语言、声音和语速配置。",
                "不需要 API Key，也不会调用云端语音服务。",
                "保存配置后运行一次完整提醒测试。"
            ]
        case "openai":
            return [
                "服务商选择 OpenAI TTS。",
                "选择一个 OpenAI 声音，例如 marin。",
                "在下方输入并保存 API Key。",
                "保存配置后运行一次完整提醒测试。"
            ]
        default:
            return [
                "\(futureProviderLabel(appState.config.futureVoice.provider)) 目前作为预留服务商保存配置。",
                "可以先填写服务商侧的声音 ID、性别偏好和风格。",
                "当前 CLI 尚未接入该服务商，运行时会回退到 macOS say。"
            ]
        }
    }

    var body: some View {
        SettingsPage(
            title: "语音内容",
            subtitle: "设置播报模板、本机 macOS say 和后续真人语音服务商。",
            systemImage: "speaker.wave.2"
        ) {
            SettingsSectionCard("播报内容") {
                LabeledContent("播报模板") {
                    TextField("例如 {project}: {message}", text: $appState.config.voice.messageTemplate, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                }

                Text("可用变量：{project}、{message}、{time}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SettingsSectionCard("macOS say（本机）", subtitle: voiceCountText) {
                LabeledContent("语言") {
                    Picker("语言", selection: $appState.config.voice.language) {
                        ForEach(languageOptions, id: \.self) { language in
                            Text(languageLabel(for: language)).tag(language)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 260)
                    .onChange(of: appState.config.voice.language) { _ in
                        appState.config.voice.voiceName = nil
                    }
                }

                LabeledContent("声音") {
                    Picker("声音", selection: Binding(
                        get: { appState.config.voice.voiceName ?? "" },
                        set: { appState.config.voice.voiceName = $0.isEmpty ? nil : $0 }
                    )) {
                        ForEach(voiceOptions, id: \.self) { voice in
                            Text(voiceLabel(for: voice)).tag(voice)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 440)
                }

                LabeledContent("语速") {
                    HStack(spacing: 12) {
                        Slider(
                            value: Binding(
                                get: { Double(appState.config.voice.rate) },
                                set: { appState.config.voice.rate = Int($0) }
                            ),
                            in: 120...260,
                            step: 10
                        )
                        Text("\(appState.config.voice.rate)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }

            SettingsSectionCard("完成提醒语音服务商") {
                VStack(alignment: .leading, spacing: 6) {
                    SettingsStatusBadge(
                        text: futureProviderStatusText,
                        level: futureProviderReady ? .ok : .warning
                    )

                    ForEach(futureProviderGuide, id: \.self) { item in
                        Text("• \(item)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("服务商") {
                    Picker("服务商", selection: Binding(
                        get: { appState.config.futureVoice.provider ?? "" },
                        set: { appState.config.futureVoice.provider = $0.isEmpty ? nil : $0 }
                    )) {
                        ForEach(futureVoiceProviders, id: \.value) { provider in
                            Text(provider.label).tag(provider.value)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 320)
                }

                if appState.config.futureVoice.provider == "openai" {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OpenAI API Key")
                            .font(.headline)
                        Text("保存到本机密钥文件，不写入 config.json；页面不会回显完整 Key。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(appState.openAIKeyStatusText)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(appState.openAIKeyConfigured ? .green : .orange)
                        SettingsPathText(value: appState.envPath)

                        SecureField("输入 OpenAI API Key", text: $openAIAPIKeyInput)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button("保存 Key") {
                                if appState.saveOpenAIKey(openAIAPIKeyInput) {
                                    openAIAPIKeyInput = ""
                                }
                            }
                            Button("清除") {
                                appState.clearOpenAIKey()
                                openAIAPIKeyInput = ""
                            }
                            .disabled(!appState.openAIKeyConfigured)
                        }
                    }
                }

                if appState.config.futureVoice.provider == "openai" {
                    LabeledContent("OpenAI 内置声音") {
                        Picker("OpenAI 内置声音", selection: Binding(
                            get: { appState.config.futureVoice.voiceId ?? "marin" },
                            set: { appState.config.futureVoice.voiceId = $0 }
                        )) {
                            ForEach(openAIVoices, id: \.self) { voice in
                                Text(voice).tag(voice)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 260)
                    }
                } else if appState.config.futureVoice.provider != nil {
                    LabeledContent("声音 ID") {
                        TextField("服务商侧声音 ID", text: Binding(
                            get: { appState.config.futureVoice.voiceId ?? "" },
                            set: { appState.config.futureVoice.voiceId = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                    }
                }

                if appState.config.futureVoice.provider != nil {
                    LabeledContent("性别偏好") {
                        Picker("性别偏好", selection: Binding(
                            get: { appState.config.futureVoice.genderPreference ?? "" },
                            set: { appState.config.futureVoice.genderPreference = $0.isEmpty ? nil : $0 }
                        )) {
                            ForEach(genderPreferences, id: \.self) { gender in
                                Text(futureOptionLabel(gender, emptyLabel: "不指定")).tag(gender)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 220)
                    }

                    LabeledContent("风格") {
                        Picker("风格", selection: Binding(
                            get: { appState.config.futureVoice.style ?? "" },
                            set: { appState.config.futureVoice.style = $0.isEmpty ? nil : $0 }
                        )) {
                            ForEach(voiceStyles, id: \.self) { style in
                                Text(futureOptionLabel(style, emptyLabel: "不指定")).tag(style)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 220)
                    }

                    Toggle("缓存生成的音频", isOn: $appState.config.futureVoice.cacheAudio)
                }

                Text("选择 macOS say 时使用上方本机语音设置；OpenAI TTS 已接入并需要 OPENAI_API_KEY；其他云端服务商目前仅保存配置，运行时会回退到 macOS say。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SettingsSectionCard("操作") {
                SettingsActions(
                    status: appState.lastStatusMessage,
                    actions: [
                        SettingsAction("保存配置") { appState.save() },
                        SettingsAction("试听语音") { appState.previewVoice() },
                        SettingsAction("重新读取系统语音") { appState.loadSystemVoices() },
                        SettingsAction("测试完整提醒") { appState.testReminder() },
                    ]
                )
            }
        }
    }
}
