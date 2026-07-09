import XCTest
@testable import CodexDoneCore

final class CodexDoneConfigTests: XCTestCase {
    func testDefaultConfigMatchesVersionOneDefaults() {
        let config = CodexDoneConfig.default

        XCTAssertEqual(config.version, 1)
        XCTAssertEqual(config.alert.mode, .voiceAndSound)
        XCTAssertTrue(config.alert.desktopNotification)
        XCTAssertTrue(config.alert.mobilePush)
        XCTAssertEqual(config.sound.provider, "macos")
        XCTAssertEqual(config.sound.name, "Ping")
        XCTAssertEqual(config.sound.repeatCount, 1)
        XCTAssertNil(config.sound.customFilePath)
        XCTAssertEqual(config.voice.provider, "macos")
        XCTAssertEqual(config.voice.language, "zh-CN")
        XCTAssertNil(config.voice.voiceName)
        XCTAssertEqual(config.voice.rate, 180)
        XCTAssertEqual(config.voice.messageTemplate, "{project}: {message}")
        XCTAssertEqual(config.mobile.provider, "ntfy")
        XCTAssertEqual(config.mobile.topic, "")
        XCTAssertEqual(config.mobile.recipient, "")
        XCTAssertEqual(config.mobile.title, "Codex 任务完成")
        XCTAssertNil(config.events.taskCompleted)
        XCTAssertNil(config.events.testPassed)
        XCTAssertNil(config.events.testFailed)
        XCTAssertNil(config.events.needsAttention)
        XCTAssertTrue(config.queue.mergeNotifications)
        XCTAssertEqual(config.queue.batchDelaySeconds, 2)
        XCTAssertEqual(config.queue.retentionCount, 200)
        XCTAssertNil(config.futureVoice.provider)
        XCTAssertNil(config.futureVoice.voiceId)
        XCTAssertNil(config.futureVoice.genderPreference)
        XCTAssertNil(config.futureVoice.style)
        XCTAssertTrue(config.futureVoice.cacheAudio)
    }

    func testAlertModesExposeRawValuesAndDisplayNames() {
        XCTAssertEqual(AlertMode.silent.rawValue, "silent")
        XCTAssertEqual(AlertMode.silent.displayName, "静音")
        XCTAssertEqual(AlertMode.sound.rawValue, "sound")
        XCTAssertEqual(AlertMode.sound.displayName, "提示音")
        XCTAssertEqual(AlertMode.voice.rawValue, "voice")
        XCTAssertEqual(AlertMode.voice.displayName, "语音")
        XCTAssertEqual(AlertMode.voiceAndSound.rawValue, "voice_and_sound")
        XCTAssertEqual(AlertMode.voiceAndSound.displayName, "语音 + 提示音")
    }

    func testConfigRoundTripsThroughJson() throws {
        var config = CodexDoneConfig.default
        config.alert.mode = .sound
        config.mobile.topic = "codex-test-topic"
        config.mobile.recipient = "codex-user@example.com"
        config.voice.voiceName = "Tingting"
        config.futureVoice.provider = "openai"
        config.futureVoice.genderPreference = "female"
        config.queue.mergeNotifications = false
        config.queue.batchDelaySeconds = 10
        config.events.testFailed = EventAlertConfig(
            mode: .silent,
            messageTemplate: "{event}: {message}",
            soundName: "Ping"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(config)
        let decoded = try JSONDecoder().decode(CodexDoneConfig.self, from: data)

        XCTAssertEqual(decoded, config)
    }

    func testDefaultConfigEncodesExplicitNullKeys() throws {
        let data = try JSONEncoder().encode(CodexDoneConfig.default)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        let sound = try XCTUnwrap(json["sound"] as? [String: Any])
        XCTAssertTrue(sound["customFilePath"] is NSNull)

        let voice = try XCTUnwrap(json["voice"] as? [String: Any])
        XCTAssertTrue(voice["voiceName"] is NSNull)

        let events = try XCTUnwrap(json["events"] as? [String: Any])
        XCTAssertTrue(events["taskCompleted"] is NSNull)
        XCTAssertTrue(events["testPassed"] is NSNull)
        XCTAssertTrue(events["testFailed"] is NSNull)
        XCTAssertTrue(events["needsAttention"] is NSNull)

        let futureVoice = try XCTUnwrap(json["futureVoice"] as? [String: Any])
        XCTAssertTrue(futureVoice["provider"] is NSNull)
        XCTAssertTrue(futureVoice["voiceId"] is NSNull)
        XCTAssertTrue(futureVoice["genderPreference"] is NSNull)
        XCTAssertTrue(futureVoice["style"] is NSNull)

        let queue = try XCTUnwrap(json["queue"] as? [String: Any])
        XCTAssertEqual(queue["mergeNotifications"] as? Bool, true)
        XCTAssertEqual(queue["batchDelaySeconds"] as? Int, 2)
        XCTAssertEqual(queue["retentionCount"] as? Int, 200)
    }

    func testDecodingOldConfigWithoutQueueUsesDefaultQueue() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "version": 1
        ])

        let decoded = try JSONDecoder().decode(CodexDoneConfig.self, from: data)

        XCTAssertEqual(decoded.queue, CodexDoneConfig.default.queue)
    }
}
