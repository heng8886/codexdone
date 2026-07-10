import Foundation

public enum AlertMode: String, Codable, CaseIterable, Identifiable {
    case silent
    case sound
    case voice
    case voiceAndSound = "voice_and_sound"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .silent: return "静音"
        case .sound: return "提示音"
        case .voice: return "语音"
        case .voiceAndSound: return "语音 + 提示音"
        }
    }
}

public struct CodexDoneConfig: Codable, Equatable {
    public var version: Int
    public var alert: AlertConfig
    public var sound: SoundConfig
    public var voice: VoiceConfig
    public var mobile: MobileConfig
    public var events: EventsConfig
    public var queue: QueueConfig
    public var futureVoice: FutureVoiceConfig

    public init(
        version: Int,
        alert: AlertConfig,
        sound: SoundConfig,
        voice: VoiceConfig,
        mobile: MobileConfig,
        events: EventsConfig,
        queue: QueueConfig,
        futureVoice: FutureVoiceConfig
    ) {
        self.version = version
        self.alert = alert
        self.sound = sound
        self.voice = voice
        self.mobile = mobile
        self.events = events
        self.queue = queue
        self.futureVoice = futureVoice
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case alert
        case sound
        case voice
        case mobile
        case events
        case queue
        case futureVoice
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = CodexDoneConfig.default
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? fallback.version
        alert = try container.decodeIfPresent(AlertConfig.self, forKey: .alert) ?? fallback.alert
        sound = try container.decodeIfPresent(SoundConfig.self, forKey: .sound) ?? fallback.sound
        voice = try container.decodeIfPresent(VoiceConfig.self, forKey: .voice) ?? fallback.voice
        mobile = try container.decodeIfPresent(MobileConfig.self, forKey: .mobile) ?? fallback.mobile
        events = try container.decodeIfPresent(EventsConfig.self, forKey: .events) ?? fallback.events
        queue = try container.decodeIfPresent(QueueConfig.self, forKey: .queue) ?? fallback.queue
        futureVoice = try container.decodeIfPresent(FutureVoiceConfig.self, forKey: .futureVoice) ?? fallback.futureVoice
    }

    public static let `default` = CodexDoneConfig(
        version: 1,
        alert: AlertConfig(
            enabled: true,
            mode: .voiceAndSound,
            desktopNotification: true,
            mobilePush: true
        ),
        sound: SoundConfig(
            provider: "macos",
            name: "Ping",
            repeatCount: 1,
            customFilePath: nil
        ),
        voice: VoiceConfig(
            provider: "macos",
            language: "zh-CN",
            voiceName: nil,
            rate: 180,
            messageTemplate: "{project}: {message}"
        ),
        mobile: MobileConfig(
            provider: "ntfy",
            topic: "",
            recipient: "",
            title: "Codex 任务完成"
        ),
        events: EventsConfig(
            taskCompleted: nil,
            testPassed: nil,
            testFailed: nil,
            needsAttention: nil
        ),
        queue: QueueConfig(
            mergeNotifications: true,
            batchDelaySeconds: 2,
            retentionCount: 200
        ),
        futureVoice: FutureVoiceConfig(
            provider: nil,
            voiceId: nil,
            genderPreference: nil,
            style: nil,
            cacheAudio: true
        )
    )
}

public struct AlertConfig: Codable, Equatable {
    public var enabled: Bool
    public var mode: AlertMode
    public var desktopNotification: Bool
    public var mobilePush: Bool

    private enum CodingKeys: String, CodingKey {
        case enabled
        case mode
        case desktopNotification
        case mobilePush
    }

    public init(
        enabled: Bool = true,
        mode: AlertMode,
        desktopNotification: Bool,
        mobilePush: Bool
    ) {
        self.enabled = enabled
        self.mode = mode
        self.desktopNotification = desktopNotification
        self.mobilePush = mobilePush
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        mode = try container.decodeIfPresent(AlertMode.self, forKey: .mode) ?? .voiceAndSound
        desktopNotification = try container.decodeIfPresent(Bool.self, forKey: .desktopNotification) ?? true
        mobilePush = try container.decodeIfPresent(Bool.self, forKey: .mobilePush) ?? true
    }
}

public struct SoundConfig: Codable, Equatable {
    public var provider: String
    public var name: String
    public var repeatCount: Int
    public var customFilePath: String?

    private enum CodingKeys: String, CodingKey {
        case provider
        case name
        case repeatCount
        case customFilePath
    }

    public init(
        provider: String,
        name: String,
        repeatCount: Int,
        customFilePath: String?
    ) {
        self.provider = provider
        self.name = name
        self.repeatCount = repeatCount
        self.customFilePath = customFilePath
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(provider, forKey: .provider)
        try container.encode(name, forKey: .name)
        try container.encode(repeatCount, forKey: .repeatCount)
        try container.encodeExplicitNil(customFilePath, forKey: .customFilePath)
    }
}

public struct VoiceConfig: Codable, Equatable {
    public var provider: String
    public var language: String
    public var voiceName: String?
    public var rate: Int
    public var messageTemplate: String

    private enum CodingKeys: String, CodingKey {
        case provider
        case language
        case voiceName
        case rate
        case messageTemplate
    }

    public init(
        provider: String,
        language: String,
        voiceName: String?,
        rate: Int,
        messageTemplate: String
    ) {
        self.provider = provider
        self.language = language
        self.voiceName = voiceName
        self.rate = rate
        self.messageTemplate = messageTemplate
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(provider, forKey: .provider)
        try container.encode(language, forKey: .language)
        try container.encodeExplicitNil(voiceName, forKey: .voiceName)
        try container.encode(rate, forKey: .rate)
        try container.encode(messageTemplate, forKey: .messageTemplate)
    }
}

public struct MobileConfig: Codable, Equatable {
    public var provider: String
    public var topic: String
    public var recipient: String
    public var title: String

    private enum CodingKeys: String, CodingKey {
        case provider
        case topic
        case recipient
        case title
    }

    public init(
        provider: String,
        topic: String,
        recipient: String,
        title: String
    ) {
        self.provider = provider
        self.topic = topic
        self.recipient = recipient
        self.title = title
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        provider = try container.decodeIfPresent(String.self, forKey: .provider) ?? "ntfy"
        topic = try container.decodeIfPresent(String.self, forKey: .topic) ?? ""
        recipient = try container.decodeIfPresent(String.self, forKey: .recipient) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Codex 任务完成"
    }
}

public struct EventsConfig: Codable, Equatable {
    public var taskCompleted: EventAlertConfig?
    public var testPassed: EventAlertConfig?
    public var testFailed: EventAlertConfig?
    public var needsAttention: EventAlertConfig?

    private enum CodingKeys: String, CodingKey {
        case taskCompleted
        case testPassed
        case testFailed
        case needsAttention
    }

    public init(
        taskCompleted: EventAlertConfig?,
        testPassed: EventAlertConfig?,
        testFailed: EventAlertConfig?,
        needsAttention: EventAlertConfig?
    ) {
        self.taskCompleted = taskCompleted
        self.testPassed = testPassed
        self.testFailed = testFailed
        self.needsAttention = needsAttention
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeExplicitNil(taskCompleted, forKey: .taskCompleted)
        try container.encodeExplicitNil(testPassed, forKey: .testPassed)
        try container.encodeExplicitNil(testFailed, forKey: .testFailed)
        try container.encodeExplicitNil(needsAttention, forKey: .needsAttention)
    }
}

public struct EventAlertConfig: Codable, Equatable {
    public var mode: AlertMode?
    public var messageTemplate: String?
    public var soundName: String?

    private enum CodingKeys: String, CodingKey {
        case mode
        case messageTemplate
        case soundName
    }

    public init(
        mode: AlertMode?,
        messageTemplate: String?,
        soundName: String?
    ) {
        self.mode = mode
        self.messageTemplate = messageTemplate
        self.soundName = soundName
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeExplicitNil(mode, forKey: .mode)
        try container.encodeExplicitNil(messageTemplate, forKey: .messageTemplate)
        try container.encodeExplicitNil(soundName, forKey: .soundName)
    }
}

public struct QueueConfig: Codable, Equatable {
    public var mergeNotifications: Bool
    public var batchDelaySeconds: Int
    public var retentionCount: Int

    public init(
        mergeNotifications: Bool,
        batchDelaySeconds: Int,
        retentionCount: Int
    ) {
        self.mergeNotifications = mergeNotifications
        self.batchDelaySeconds = batchDelaySeconds
        self.retentionCount = retentionCount
    }
}

public struct FutureVoiceConfig: Codable, Equatable {
    public var provider: String?
    public var voiceId: String?
    public var genderPreference: String?
    public var style: String?
    public var cacheAudio: Bool

    private enum CodingKeys: String, CodingKey {
        case provider
        case voiceId
        case genderPreference
        case style
        case cacheAudio
    }

    public init(
        provider: String?,
        voiceId: String?,
        genderPreference: String?,
        style: String?,
        cacheAudio: Bool
    ) {
        self.provider = provider
        self.voiceId = voiceId
        self.genderPreference = genderPreference
        self.style = style
        self.cacheAudio = cacheAudio
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeExplicitNil(provider, forKey: .provider)
        try container.encodeExplicitNil(voiceId, forKey: .voiceId)
        try container.encodeExplicitNil(genderPreference, forKey: .genderPreference)
        try container.encodeExplicitNil(style, forKey: .style)
        try container.encode(cacheAudio, forKey: .cacheAudio)
    }
}

private extension KeyedEncodingContainer {
    mutating func encodeExplicitNil<Value: Encodable>(
        _ value: Value?,
        forKey key: Key
    ) throws {
        if let value = value {
            try encode(value, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }
}
