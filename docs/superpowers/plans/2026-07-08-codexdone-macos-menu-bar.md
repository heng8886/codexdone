# CodexDone macOS Menu Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS-native menu bar app that configures, tests, and integrates the existing `codex-done` completion notifier.

**Architecture:** Add a SwiftPM macOS app under `CodexDoneApp/` with a reusable `CodexDoneCore` library for config, template rendering, and Codex rule generation. Keep the root `codex-done` Bash command as the automation entry point, but teach it to read `~/.codex-done/config.json` written by the app.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, XCTest, Bash, macOS `say`, `osascript`, `afplay`, `curl`.

---

## Version Control Note

The workspace root is currently not a git repository. Each task ends with a checkpoint command. If a git repository is initialized before execution, replace checkpoint steps with normal `git add ... && git commit -m "..."` commits.

## File Structure

- Create `CodexDoneApp/Package.swift`: Swift package manifest for the app, core library, and tests.
- Create `CodexDoneApp/Sources/CodexDoneCore/CodexDoneConfig.swift`: Codable configuration model and defaults.
- Create `CodexDoneApp/Sources/CodexDoneCore/ConfigStore.swift`: Load and save `~/.codex-done/config.json`.
- Create `CodexDoneApp/Sources/CodexDoneCore/TemplateRenderer.swift`: Render `{project}`, `{message}`, and `{time}`.
- Create `CodexDoneApp/Sources/CodexDoneCore/CodexRuleGenerator.swift`: Produce the Codex work rule text.
- Create `CodexDoneApp/Sources/CodexDoneCore/CodexDonePaths.swift`: Resolve config and CLI paths.
- Create `CodexDoneApp/Sources/CodexDoneApp/CodexDoneApp.swift`: SwiftUI menu bar app entry point.
- Create `CodexDoneApp/Sources/CodexDoneApp/AppState.swift`: Observable state and reminder test actions.
- Create `CodexDoneApp/Sources/CodexDoneApp/Views/MenuBarContentView.swift`: Menu bar popover actions and status.
- Create `CodexDoneApp/Sources/CodexDoneApp/Views/SettingsWindowView.swift`: Four-page settings window shell.
- Create `CodexDoneApp/Sources/CodexDoneApp/Views/StatusSettingsView.swift`: Status page.
- Create `CodexDoneApp/Sources/CodexDoneApp/Views/ReminderModeSettingsView.swift`: Reminder mode and sound settings.
- Create `CodexDoneApp/Sources/CodexDoneApp/Views/VoiceContentSettingsView.swift`: Message, language, voice, and rate settings.
- Create `CodexDoneApp/Sources/CodexDoneApp/Views/CodexIntegrationSettingsView.swift`: Work rule and CLI path page.
- Create `CodexDoneApp/Tests/CodexDoneCoreTests/*.swift`: Unit tests for config, templates, rule generation, and path logic.
- Modify `codex-done`: Read JSON config, support alert modes, play sound, render templates, and keep failures non-blocking.
- Modify `tests/test_codex_done.sh`: Cover JSON config, alert modes, sound, template rendering, damaged config, and push failure.
- Modify `docs/codex-done.md`: Document the app configuration file and new reminder modes.

---

### Task 1: Scaffold Swift Package And Config Model

**Files:**
- Create: `CodexDoneApp/Package.swift`
- Create: `CodexDoneApp/Sources/CodexDoneCore/CodexDoneConfig.swift`
- Create: `CodexDoneApp/Tests/CodexDoneCoreTests/CodexDoneConfigTests.swift`

- [ ] **Step 1: Write the failing config model tests**

Create `CodexDoneApp/Tests/CodexDoneCoreTests/CodexDoneConfigTests.swift`:

```swift
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
        XCTAssertEqual(config.voice.provider, "macos")
        XCTAssertEqual(config.voice.language, "zh-CN")
        XCTAssertEqual(config.voice.rate, 180)
        XCTAssertEqual(config.voice.messageTemplate, "{project} 的任务已经完成")
        XCTAssertEqual(config.mobile.provider, "ntfy")
        XCTAssertEqual(config.mobile.title, "Codex 任务完成")
        XCTAssertNil(config.events.taskCompleted)
        XCTAssertNil(config.futureVoice.provider)
        XCTAssertTrue(config.futureVoice.cacheAudio)
    }

    func testConfigRoundTripsThroughJson() throws {
        var config = CodexDoneConfig.default
        config.alert.mode = .sound
        config.mobile.topic = "codex-test-topic"
        config.voice.voiceName = "Tingting"
        config.futureVoice.provider = "openai"
        config.futureVoice.genderPreference = "female"

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(config)
        let decoded = try JSONDecoder().decode(CodexDoneConfig.self, from: data)

        XCTAssertEqual(decoded, config)
    }
}
```

- [ ] **Step 2: Add the Swift package manifest**

Create `CodexDoneApp/Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexDone",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "CodexDoneCore", targets: ["CodexDoneCore"]),
        .executable(name: "CodexDoneApp", targets: ["CodexDoneApp"])
    ],
    targets: [
        .target(name: "CodexDoneCore"),
        .executableTarget(
            name: "CodexDoneApp",
            dependencies: ["CodexDoneCore"]
        ),
        .testTarget(
            name: "CodexDoneCoreTests",
            dependencies: ["CodexDoneCore"]
        )
    ]
)
```

- [ ] **Step 3: Run tests to verify they fail before implementation**

Run:

```bash
swift test --package-path CodexDoneApp
```

Expected: fail because `CodexDoneCore` and `CodexDoneConfig` do not exist yet.

- [ ] **Step 4: Implement the config model**

Create `CodexDoneApp/Sources/CodexDoneCore/CodexDoneConfig.swift`:

```swift
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
    public var futureVoice: FutureVoiceConfig

    public static let `default` = CodexDoneConfig(
        version: 1,
        alert: AlertConfig(
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
            messageTemplate: "{project} 的任务已经完成"
        ),
        mobile: MobileConfig(
            provider: "ntfy",
            topic: "",
            title: "Codex 任务完成"
        ),
        events: EventsConfig(
            taskCompleted: nil,
            testPassed: nil,
            testFailed: nil,
            needsAttention: nil
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
    public var mode: AlertMode
    public var desktopNotification: Bool
    public var mobilePush: Bool
}

public struct SoundConfig: Codable, Equatable {
    public var provider: String
    public var name: String
    public var repeatCount: Int
    public var customFilePath: String?
}

public struct VoiceConfig: Codable, Equatable {
    public var provider: String
    public var language: String
    public var voiceName: String?
    public var rate: Int
    public var messageTemplate: String
}

public struct MobileConfig: Codable, Equatable {
    public var provider: String
    public var topic: String
    public var title: String
}

public struct EventsConfig: Codable, Equatable {
    public var taskCompleted: EventAlertConfig?
    public var testPassed: EventAlertConfig?
    public var testFailed: EventAlertConfig?
    public var needsAttention: EventAlertConfig?
}

public struct EventAlertConfig: Codable, Equatable {
    public var mode: AlertMode?
    public var messageTemplate: String?
    public var soundName: String?
}

public struct FutureVoiceConfig: Codable, Equatable {
    public var provider: String?
    public var voiceId: String?
    public var genderPreference: String?
    public var style: String?
    public var cacheAudio: Bool
}
```

- [ ] **Step 5: Run tests to verify config passes**

Run:

```bash
swift test --package-path CodexDoneApp
```

Expected: pass.

- [ ] **Step 6: Checkpoint**

Run:

```bash
test -f CodexDoneApp/Package.swift
test -f CodexDoneApp/Sources/CodexDoneCore/CodexDoneConfig.swift
test -f CodexDoneApp/Tests/CodexDoneCoreTests/CodexDoneConfigTests.swift
```

Expected: all commands exit 0.

---

### Task 2: Add Config Store

**Files:**
- Create: `CodexDoneApp/Sources/CodexDoneCore/ConfigStore.swift`
- Create: `CodexDoneApp/Tests/CodexDoneCoreTests/ConfigStoreTests.swift`

- [ ] **Step 1: Write failing config store tests**

Create `CodexDoneApp/Tests/CodexDoneCoreTests/ConfigStoreTests.swift`:

```swift
import XCTest
@testable import CodexDoneCore

final class ConfigStoreTests: XCTestCase {
    func testLoadMissingConfigReturnsDefaultAndCreatesParentDirectoryOnSave() throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("nested/config.json")
        let store = ConfigStore(configURL: url)

        XCTAssertEqual(try store.load(), .default)

        var config = CodexDoneConfig.default
        config.mobile.topic = "codex-topic"
        try store.save(config)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try store.load().mobile.topic, "codex-topic")
    }

    func testDamagedConfigReturnsDefault() throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("config.json")
        try "{ broken json".write(to: url, atomically: true, encoding: .utf8)

        let store = ConfigStore(configURL: url)

        XCTAssertEqual(try store.load(), .default)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexDoneConfigStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
swift test --package-path CodexDoneApp --filter ConfigStoreTests
```

Expected: fail because `ConfigStore` does not exist.

- [ ] **Step 3: Implement `ConfigStore`**

Create `CodexDoneApp/Sources/CodexDoneCore/ConfigStore.swift`:

```swift
import Foundation

public struct ConfigStore {
    public let configURL: URL

    public init(configURL: URL = CodexDonePaths.defaultConfigURL()) {
        self.configURL = configURL
    }

    public func load() throws -> CodexDoneConfig {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return .default
        }

        do {
            let data = try Data(contentsOf: configURL)
            return try JSONDecoder().decode(CodexDoneConfig.self, from: data)
        } catch {
            return .default
        }
    }

    public func save(_ config: CodexDoneConfig) throws {
        let parent = configURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configURL, options: [.atomic])
    }
}
```

- [ ] **Step 4: Add path helper used by the config store**

Create `CodexDoneApp/Sources/CodexDoneCore/CodexDonePaths.swift`:

```swift
import Foundation

public enum CodexDonePaths {
    public static func defaultConfigURL(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        homeDirectory
            .appendingPathComponent(".codex-done", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    public static func defaultCLIPath(
        currentDirectory: String = FileManager.default.currentDirectoryPath
    ) -> String {
        let environmentPath = ProcessInfo.processInfo.environment["CODEX_DONE_CLI_PATH"]
        if let environmentPath, !environmentPath.isEmpty {
            return environmentPath
        }

        let rootRelativePath = URL(fileURLWithPath: currentDirectory)
            .deletingLastPathComponent()
            .appendingPathComponent("codex-done")
            .path

        if FileManager.default.isExecutableFile(atPath: rootRelativePath) {
            return rootRelativePath
        }

        return "/usr/local/bin/codex-done"
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run:

```bash
swift test --package-path CodexDoneApp --filter ConfigStoreTests
```

Expected: pass.

- [ ] **Step 6: Run all Swift tests**

Run:

```bash
swift test --package-path CodexDoneApp
```

Expected: pass.

---

### Task 3: Add Template Rendering And Codex Rule Generation

**Files:**
- Create: `CodexDoneApp/Sources/CodexDoneCore/TemplateRenderer.swift`
- Create: `CodexDoneApp/Sources/CodexDoneCore/CodexRuleGenerator.swift`
- Create: `CodexDoneApp/Tests/CodexDoneCoreTests/TemplateRendererTests.swift`
- Create: `CodexDoneApp/Tests/CodexDoneCoreTests/CodexRuleGeneratorTests.swift`

- [ ] **Step 1: Write failing template renderer tests**

Create `CodexDoneApp/Tests/CodexDoneCoreTests/TemplateRendererTests.swift`:

```swift
import XCTest
@testable import CodexDoneCore

final class TemplateRendererTests: XCTestCase {
    func testRendersSupportedVariables() {
        let context = TemplateContext(
            project: "13codexdone",
            message: "代码修改完成",
            time: "09:30"
        )

        let rendered = TemplateRenderer.render(
            "{project}: {message} at {time}",
            context: context
        )

        XCTAssertEqual(rendered, "13codexdone: 代码修改完成 at 09:30")
    }

    func testLeavesUnknownVariablesVisible() {
        let context = TemplateContext(project: "A", message: "B", time: "C")

        let rendered = TemplateRenderer.render("{duration} {project}", context: context)

        XCTAssertEqual(rendered, "{duration} A")
    }
}
```

- [ ] **Step 2: Write failing rule generator tests**

Create `CodexDoneApp/Tests/CodexDoneCoreTests/CodexRuleGeneratorTests.swift`:

```swift
import XCTest
@testable import CodexDoneCore

final class CodexRuleGeneratorTests: XCTestCase {
    func testGeneratedRuleIncludesCommandAndFailureGuidance() {
        let rule = CodexRuleGenerator.rule(commandName: "codex-done")

        XCTAssertTrue(rule.contains("每当你完成一个阶段性任务"))
        XCTAssertTrue(rule.contains("codex-done"))
        XCTAssertTrue(rule.contains("通知失败"))
        XCTAssertTrue(rule.contains("不要中断任务"))
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```bash
swift test --package-path CodexDoneApp --filter TemplateRendererTests
```

Expected: fail because `TemplateRenderer` does not exist.

Run:

```bash
swift test --package-path CodexDoneApp --filter CodexRuleGeneratorTests
```

Expected: fail because `CodexRuleGenerator` does not exist.

- [ ] **Step 4: Implement template renderer**

Create `CodexDoneApp/Sources/CodexDoneCore/TemplateRenderer.swift`:

```swift
import Foundation

public struct TemplateContext: Equatable {
    public var project: String
    public var message: String
    public var time: String

    public init(project: String, message: String, time: String) {
        self.project = project
        self.message = message
        self.time = time
    }
}

public enum TemplateRenderer {
    public static func render(_ template: String, context: TemplateContext) -> String {
        template
            .replacingOccurrences(of: "{project}", with: context.project)
            .replacingOccurrences(of: "{message}", with: context.message)
            .replacingOccurrences(of: "{time}", with: context.time)
    }
}
```

- [ ] **Step 5: Implement rule generator**

Create `CodexDoneApp/Sources/CodexDoneCore/CodexRuleGenerator.swift`:

```swift
import Foundation

public enum CodexRuleGenerator {
    public static func rule(commandName: String) -> String {
        """
        每当你完成一个阶段性任务并准备回复我时，如果当前项目中存在 `codex-done`、`scripts/codex-done.sh` 或全局可用的 `\(commandName)` 命令，请在最终回复前运行它，通知内容用一句话概括本阶段完成的工作。如果脚本不存在或通知失败，请不要中断任务，正常回复即可。
        """
    }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run:

```bash
swift test --package-path CodexDoneApp --filter TemplateRendererTests
swift test --package-path CodexDoneApp --filter CodexRuleGeneratorTests
swift test --package-path CodexDoneApp
```

Expected: all pass.

---

### Task 4: Update `codex-done` Tests For JSON Config And Alert Modes

**Files:**
- Modify: `tests/test_codex_done.sh`

- [ ] **Step 1: Add failing tests for JSON config, sound mode, and ntfy failure**

Modify `tests/test_codex_done.sh` by adding these helpers after `assert_not_exists()`:

```bash
assert_exists() {
  local file="$1"

  if [[ ! -e "$file" ]]; then
    fail "$file should exist"
  fi
}

write_config() {
  local file="$1"
  local mode="$2"
  local topic="$3"
  local template="$4"

  mkdir -p "$(dirname "$file")"
  cat >"$file" <<JSON
{
  "version": 1,
  "alert": {
    "mode": "$mode",
    "desktopNotification": true,
    "mobilePush": true
  },
  "sound": {
    "provider": "macos",
    "name": "Ping",
    "repeatCount": 2,
    "customFilePath": null
  },
  "voice": {
    "provider": "macos",
    "language": "zh-CN",
    "voiceName": "Tingting",
    "rate": 180,
    "messageTemplate": "$template"
  },
  "mobile": {
    "provider": "ntfy",
    "topic": "$topic",
    "title": "JSON 标题"
  },
  "events": {
    "taskCompleted": null,
    "testPassed": null,
    "testFailed": null,
    "needsAttention": null
  },
  "futureVoice": {
    "provider": null,
    "voiceId": null,
    "genderPreference": null,
    "style": null,
    "cacheAudio": true
  }
}
JSON
}
```

Modify `create_stubs()` by adding the `afplay` stub:

```bash
  cat >"$STUB_DIR/afplay" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CODEX_DONE_TEST_LOG/afplay.log"
STUB

  chmod +x "$STUB_DIR/afplay"
```

Modify `run_codex_done()` to pass an isolated config path:

```bash
run_codex_done() {
  CODEX_DONE_CONFIG="$LOG_DIR/config.json" CODEX_DONE_TEST_LOG="$LOG_DIR" PATH="$STUB_DIR:$PATH" "$SCRIPT" "$@" >"$LOG_DIR/stdout" 2>"$LOG_DIR/stderr"
}
```

Add these tests before `main()`:

```bash
test_json_voice_and_sound_config() {
  reset_logs
  write_config "$LOG_DIR/config.json" "voice_and_sound" "json-topic" "{project}: {message}"

  run_codex_done "代码修改完成"

  assert_contains "$LOG_DIR/afplay.log" "Ping.aiff"
  assert_contains "$LOG_DIR/say.log" "-v Tingting"
  assert_contains "$LOG_DIR/say.log" "13codexdone: 代码修改完成"
  assert_contains "$LOG_DIR/curl.log" "https://ntfy.sh/json-topic"
  assert_contains "$LOG_DIR/curl.log" "Title: JSON 标题"
}

test_json_sound_mode_skips_voice() {
  reset_logs
  write_config "$LOG_DIR/config.json" "sound" "" "{message}"

  run_codex_done "只响提示音"

  assert_contains "$LOG_DIR/afplay.log" "Ping.aiff"
  assert_not_exists "$LOG_DIR/say.log"
  assert_not_exists "$LOG_DIR/curl.log"
}

test_json_silent_mode_skips_sound_and_voice() {
  reset_logs
  write_config "$LOG_DIR/config.json" "silent" "" "{message}"

  run_codex_done "静音测试"

  assert_not_exists "$LOG_DIR/afplay.log"
  assert_not_exists "$LOG_DIR/say.log"
  assert_contains "$LOG_DIR/osascript.log" "静音测试"
}

test_damaged_config_uses_defaults() {
  reset_logs
  printf '{ broken json' >"$LOG_DIR/config.json"

  run_codex_done "损坏配置测试"

  assert_contains "$LOG_DIR/say.log" "损坏配置测试"
  assert_contains "$LOG_DIR/osascript.log" "损坏配置测试"
}

test_ntfy_failure_does_not_fail_completion() {
  reset_logs
  write_config "$LOG_DIR/config.json" "voice" "json-topic" "{message}"
  cat >"$STUB_DIR/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CODEX_DONE_TEST_LOG/curl.log"
exit 22
STUB
  chmod +x "$STUB_DIR/curl"

  run_codex_done "手机推送失败也继续"

  assert_contains "$LOG_DIR/say.log" "手机推送失败也继续"
  assert_contains "$LOG_DIR/stderr" "ntfy push failed"
}
```

Modify `main()` to call the new tests:

```bash
  test_json_voice_and_sound_config
  test_json_sound_mode_skips_voice
  test_json_silent_mode_skips_sound_and_voice
  test_damaged_config_uses_defaults
  test_ntfy_failure_does_not_fail_completion
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bash tests/test_codex_done.sh
```

Expected: fail because `codex-done` does not read JSON config, does not play sounds, and exits on curl failure.

---

### Task 5: Implement JSON Config, Template Rendering, Sound, And Non-Blocking Push In `codex-done`

**Files:**
- Modify: `codex-done`

- [ ] **Step 1: Replace `codex-done` with JSON-aware implementation**

Replace `codex-done` with:

```bash
#!/usr/bin/env bash
set -euo pipefail

DEFAULT_MESSAGE="本阶段工作已经完成"
DEFAULT_TITLE="Codex 任务完成"
DEFAULT_TEMPLATE="{message}"
DEFAULT_MODE="voice"
DEFAULT_SOUND_NAME="Ping"
DEFAULT_SOUND_REPEAT_COUNT="1"
DEFAULT_VOICE_RATE="180"

raw_message="${*:-$DEFAULT_MESSAGE}"
project_name="$(basename "${PWD}")"
current_time="$(date '+%H:%M')"
config_path="${CODEX_DONE_CONFIG:-$HOME/.codex-done/config.json}"

config_value() {
  local key_path="$1"
  local fallback="$2"

  if [[ ! -f "$config_path" ]] || ! command -v python3 >/dev/null 2>&1; then
    printf '%s' "$fallback"
    return 0
  fi

  python3 - "$config_path" "$key_path" "$fallback" <<'PY'
import json
import sys

config_path, key_path, fallback = sys.argv[1:4]

try:
    with open(config_path, "r", encoding="utf-8") as handle:
        value = json.load(handle)
    for part in key_path.split("."):
        value = value[part]
    if value is None:
        print(fallback, end="")
    elif isinstance(value, bool):
        print("true" if value else "false", end="")
    else:
        print(value, end="")
except Exception:
    print(fallback, end="")
PY
}

render_template() {
  local template="$1"
  local rendered="$template"

  rendered="${rendered//\{project\}/$project_name}"
  rendered="${rendered//\{message\}/$raw_message}"
  rendered="${rendered//\{time\}/$current_time}"
  printf '%s' "$rendered"
}

escape_applescript_text() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}

sound_file_for_name() {
  local sound_name="$1"
  local candidate

  for candidate in \
    "$HOME/Library/Sounds/$sound_name.aiff" \
    "$HOME/Library/Sounds/$sound_name.wav" \
    "/System/Library/Sounds/$sound_name.aiff" \
    "/Library/Sounds/$sound_name.aiff"; do
    if [[ -f "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done

  printf '/System/Library/Sounds/Ping.aiff'
}

notify_by_sound() {
  if ! command -v afplay >/dev/null 2>&1; then
    return 0
  fi

  local sound_name repeat_count sound_file index
  sound_name="$(config_value "sound.name" "$DEFAULT_SOUND_NAME")"
  repeat_count="$(config_value "sound.repeatCount" "$DEFAULT_SOUND_REPEAT_COUNT")"
  sound_file="$(sound_file_for_name "$sound_name")"

  if ! [[ "$repeat_count" =~ ^[0-9]+$ ]] || [[ "$repeat_count" -lt 1 ]]; then
    repeat_count="1"
  fi

  for ((index = 0; index < repeat_count; index++)); do
    afplay "$sound_file" >/dev/null 2>&1 || true
  done
}

notify_by_voice() {
  if ! command -v say >/dev/null 2>&1; then
    return 0
  fi

  local voice_name voice_rate
  voice_name="$(config_value "voice.voiceName" "")"
  voice_rate="$(config_value "voice.rate" "$DEFAULT_VOICE_RATE")"

  if [[ -n "$voice_name" ]]; then
    say -v "$voice_name" -r "$voice_rate" "$message"
  else
    say -r "$voice_rate" "$message"
  fi
}

notify_by_macos_notification_center() {
  if ! command -v osascript >/dev/null 2>&1; then
    return 0
  fi

  local escaped_message escaped_title
  escaped_message="$(escape_applescript_text "$message")"
  escaped_title="$(escape_applescript_text "$title")"
  osascript -e "display notification \"$escaped_message\" with title \"$escaped_title\""
}

notify_by_ntfy() {
  if [[ "$mobile_push" != "true" ]] || [[ -z "$topic" ]] || ! command -v curl >/dev/null 2>&1; then
    return 0
  fi

  local endpoint="$topic"
  if [[ "$endpoint" != http://* && "$endpoint" != https://* ]]; then
    endpoint="https://ntfy.sh/$endpoint"
  fi

  if ! curl -fsS \
    -H "Title: $title" \
    -H "Tags: white_check_mark" \
    -d "$message" \
    "$endpoint" >/dev/null; then
    printf 'codex-done: ntfy push failed\n' >&2
  fi
}

main() {
  local mode template
  mode="$(config_value "alert.mode" "$DEFAULT_MODE")"
  template="$(config_value "voice.messageTemplate" "$DEFAULT_TEMPLATE")"
  title="$(config_value "mobile.title" "${CODEX_NOTIFY_TITLE:-$DEFAULT_TITLE}")"
  topic="$(config_value "mobile.topic" "${CODEX_NOTIFY_TOPIC:-}")"
  mobile_push="$(config_value "alert.mobilePush" "true")"
  message="$(render_template "$template")"

  case "$mode" in
    sound)
      notify_by_sound
      ;;
    voice)
      notify_by_voice
      ;;
    voice_and_sound)
      notify_by_sound
      notify_by_voice
      ;;
    silent)
      ;;
    *)
      notify_by_voice
      ;;
  esac

  notify_by_macos_notification_center
  notify_by_ntfy
}

main "$@"
```

- [ ] **Step 2: Make the script executable and syntax-check it**

Run:

```bash
chmod +x codex-done
bash -n codex-done
```

Expected: exit 0.

- [ ] **Step 3: Run shell tests**

Run:

```bash
bash tests/test_codex_done.sh
```

Expected: pass.

- [ ] **Step 4: Run a real local smoke test**

Run:

```bash
./codex-done "CodexDone JSON 配置支持已完成"
```

Expected: command exits 0 and produces local notification behavior available on this Mac.

---

### Task 6: Build SwiftUI Menu Bar App Shell

**Files:**
- Create: `CodexDoneApp/Sources/CodexDoneApp/CodexDoneApp.swift`
- Create: `CodexDoneApp/Sources/CodexDoneApp/AppState.swift`
- Create: `CodexDoneApp/Sources/CodexDoneApp/Views/MenuBarContentView.swift`
- Create: `CodexDoneApp/Sources/CodexDoneApp/Views/SettingsWindowView.swift`

- [ ] **Step 1: Implement app state**

Create `CodexDoneApp/Sources/CodexDoneApp/AppState.swift`:

```swift
import AppKit
import Combine
import CodexDoneCore
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var config: CodexDoneConfig
    @Published var lastStatusMessage: String = "准备就绪"

    private let store: ConfigStore

    init(store: ConfigStore = ConfigStore()) {
        self.store = store
        do {
            self.config = try store.load()
        } catch {
            self.config = .default
        }
    }

    var configPath: String {
        store.configURL.path
    }

    var cliPath: String {
        CodexDonePaths.defaultCLIPath()
    }

    func save() {
        do {
            try store.save(config)
            lastStatusMessage = "配置已保存"
        } catch {
            lastStatusMessage = "配置保存失败：\(error.localizedDescription)"
        }
    }

    func reload() {
        do {
            config = try store.load()
        } catch {
            config = .default
        }
        lastStatusMessage = "配置已重新读取"
    }

    func testReminder() {
        save()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = ["CodexDone 测试提醒"]

        do {
            try process.run()
            lastStatusMessage = "已触发测试提醒"
        } catch {
            lastStatusMessage = "无法运行 codex-done：\(error.localizedDescription)"
        }
    }

    func copyCodexRule() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(
            CodexRuleGenerator.rule(commandName: "codex-done"),
            forType: .string
        )
        lastStatusMessage = "Codex 工作规则已复制"
    }
}
```

- [ ] **Step 2: Implement menu bar view**

Create `CodexDoneApp/Sources/CodexDoneApp/Views/MenuBarContentView.swift`:

```swift
import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CodexDone")
                        .font(.headline)
                    Text("通知器运行中")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(.green)
                    .frame(width: 10, height: 10)
            }

            Divider()

            Button("测试提醒") {
                appState.testReminder()
            }

            Button("打开设置") {
                openWindow(id: "settings")
            }

            Button("复制 Codex 工作规则") {
                appState.copyCodexRule()
            }

            Divider()

            Text("当前模式：\(appState.config.alert.mode.displayName)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("手机推送：\(appState.config.mobile.topic.isEmpty ? "未配置" : "ntfy 已配置")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(appState.lastStatusMessage)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(width: 280)
    }
}
```

- [ ] **Step 3: Implement settings shell**

Create `CodexDoneApp/Sources/CodexDoneApp/Views/SettingsWindowView.swift`:

```swift
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case status = "状态"
    case reminder = "提醒方式"
    case voice = "语音内容"
    case codex = "Codex 集成"

    var id: String { rawValue }
}

struct SettingsWindowView: View {
    @State private var selectedSection: SettingsSection? = .status

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Text(section.rawValue)
            }
            .navigationTitle("CodexDone")
        } detail: {
            let section = selectedSection == nil ? SettingsSection.status : selectedSection!
            switch section {
            case .status:
                StatusSettingsView()
            case .reminder:
                ReminderModeSettingsView()
            case .voice:
                VoiceContentSettingsView()
            case .codex:
                CodexIntegrationSettingsView()
            }
        }
        .frame(minWidth: 760, minHeight: 460)
    }
}
```

- [ ] **Step 4: Implement app entry point**

Create `CodexDoneApp/Sources/CodexDoneApp/CodexDoneApp.swift`:

```swift
import SwiftUI

@main
struct CodexDoneApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("CodexDone", systemImage: "checkmark.circle") {
            MenuBarContentView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        Window("CodexDone 设置", id: "settings") {
            SettingsWindowView()
                .environmentObject(appState)
        }
    }
}
```

- [ ] **Step 5: Run build to verify missing page views are the next failure**

Run:

```bash
swift build --package-path CodexDoneApp
```

Expected: fail because `StatusSettingsView`, `ReminderModeSettingsView`, `VoiceContentSettingsView`, and `CodexIntegrationSettingsView` are not implemented yet.

---

### Task 7: Implement Settings Pages

**Files:**
- Create: `CodexDoneApp/Sources/CodexDoneApp/Views/StatusSettingsView.swift`
- Create: `CodexDoneApp/Sources/CodexDoneApp/Views/ReminderModeSettingsView.swift`
- Create: `CodexDoneApp/Sources/CodexDoneApp/Views/VoiceContentSettingsView.swift`
- Create: `CodexDoneApp/Sources/CodexDoneApp/Views/CodexIntegrationSettingsView.swift`

- [ ] **Step 1: Implement status page**

Create `CodexDoneApp/Sources/CodexDoneApp/Views/StatusSettingsView.swift`:

```swift
import SwiftUI

struct StatusSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("状态") {
                LabeledContent("本机提醒", value: "可用")
                LabeledContent("手机推送", value: appState.config.mobile.topic.isEmpty ? "未配置" : "ntfy 已配置")
                LabeledContent("当前模式", value: appState.config.alert.mode.displayName)
                LabeledContent("配置文件", value: appState.configPath)
            }

            Section("测试") {
                Button("测试完整提醒") {
                    appState.testReminder()
                }
                Text(appState.lastStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .navigationTitle("状态")
    }
}
```

- [ ] **Step 2: Implement reminder mode page**

Create `CodexDoneApp/Sources/CodexDoneApp/Views/ReminderModeSettingsView.swift`:

```swift
import SwiftUI
import CodexDoneCore

struct ReminderModeSettingsView: View {
    @EnvironmentObject private var appState: AppState

    private let systemSounds = ["Ping", "Glass", "Pop", "Submarine", "Tink"]

    var body: some View {
        Form {
            Section("全局提醒模式") {
                Picker("提醒模式", selection: $appState.config.alert.mode) {
                    ForEach(AlertMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("提示音") {
                Picker("声音", selection: $appState.config.sound.name) {
                    ForEach(systemSounds, id: \.self) { sound in
                        Text(sound).tag(sound)
                    }
                }

                Stepper(
                    "重复次数：\(appState.config.sound.repeatCount)",
                    value: $appState.config.sound.repeatCount,
                    in: 1...3
                )
            }

            Section("操作") {
                Button("保存配置") {
                    appState.save()
                }
                Button("测试完整提醒") {
                    appState.testReminder()
                }
            }
        }
        .padding()
        .navigationTitle("提醒方式")
    }
}
```

- [ ] **Step 3: Implement voice content page**

Create `CodexDoneApp/Sources/CodexDoneApp/Views/VoiceContentSettingsView.swift`:

```swift
import SwiftUI

struct VoiceContentSettingsView: View {
    @EnvironmentObject private var appState: AppState

    private let languages = ["zh-CN", "en-US", "ja-JP"]
    private let suggestedVoices = ["", "Tingting", "Meijia", "Sinji", "Samantha", "Alex"]

    var body: some View {
        Form {
            Section("播报内容") {
                TextField("播报模板", text: $appState.config.voice.messageTemplate, axis: .vertical)
                    .lineLimit(2...4)

                Text("可用变量：{project}、{message}、{time}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("系统语音") {
                Picker("语言", selection: $appState.config.voice.language) {
                    ForEach(languages, id: \.self) { language in
                        Text(language).tag(language)
                    }
                }

                Picker("声音", selection: Binding(
                    get: {
                        appState.config.voice.voiceName == nil ? "" : appState.config.voice.voiceName!
                    },
                    set: { appState.config.voice.voiceName = $0.isEmpty ? nil : $0 }
                )) {
                    ForEach(suggestedVoices, id: \.self) { voice in
                        Text(voice.isEmpty ? "系统默认" : voice).tag(voice)
                    }
                }

                Slider(
                    value: Binding(
                        get: { Double(appState.config.voice.rate) },
                        set: { appState.config.voice.rate = Int($0) }
                    ),
                    in: 120...260,
                    step: 10
                ) {
                    Text("语速")
                }

                Text("语速：\(appState.config.voice.rate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("操作") {
                Button("保存配置") {
                    appState.save()
                }
                Button("测试语音") {
                    appState.testReminder()
                }
            }
        }
        .padding()
        .navigationTitle("语音内容")
    }
}
```

- [ ] **Step 4: Implement Codex integration page**

Create `CodexDoneApp/Sources/CodexDoneApp/Views/CodexIntegrationSettingsView.swift`:

```swift
import SwiftUI
import CodexDoneCore

struct CodexIntegrationSettingsView: View {
    @EnvironmentObject private var appState: AppState

    private var rule: String {
        CodexRuleGenerator.rule(commandName: "codex-done")
    }

    var body: some View {
        Form {
            Section("命令路径") {
                LabeledContent("codex-done", value: appState.cliPath)
            }

            Section("Codex 工作规则") {
                Text(rule)
                    .font(.body)
                    .textSelection(.enabled)

                Button("复制工作规则") {
                    appState.copyCodexRule()
                }
            }

            Section("示例") {
                Text("./codex-done \"代码修改完成，测试已通过\"")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .padding()
        .navigationTitle("Codex 集成")
    }
}
```

- [ ] **Step 5: Build and test**

Run:

```bash
swift build --package-path CodexDoneApp
swift test --package-path CodexDoneApp
```

Expected: both pass.

---

### Task 8: Add App Core Tests For Paths And CLI Rule

**Files:**
- Create: `CodexDoneApp/Tests/CodexDoneCoreTests/CodexDonePathsTests.swift`

- [ ] **Step 1: Write path tests**

Create `CodexDoneApp/Tests/CodexDoneCoreTests/CodexDonePathsTests.swift`:

```swift
import XCTest
@testable import CodexDoneCore

final class CodexDonePathsTests: XCTestCase {
    func testDefaultConfigURLUsesDotCodexDoneDirectory() {
        let home = URL(fileURLWithPath: "/tmp/test-home", isDirectory: true)

        let url = CodexDonePaths.defaultConfigURL(homeDirectory: home)

        XCTAssertEqual(url.path, "/tmp/test-home/.codex-done/config.json")
    }
}
```

- [ ] **Step 2: Run tests**

Run:

```bash
swift test --package-path CodexDoneApp --filter CodexDonePathsTests
swift test --package-path CodexDoneApp
```

Expected: pass.

---

### Task 9: Update Documentation

**Files:**
- Modify: `docs/codex-done.md`

- [ ] **Step 1: Update usage documentation**

Replace `docs/codex-done.md` with:

```markdown
# Codex 任务完成通知器

`codex-done` 是 CodexDone 的命令行入口。Codex 完成阶段性任务时调用它，它会读取配置并执行本机提醒、桌面通知和手机推送。

## 快速使用

```bash
./codex-done
./codex-done "代码修改完成，测试已通过"
```

## 配置文件

桌面 App 会写入：

```text
~/.codex-done/config.json
```

如果配置文件不存在或损坏，`codex-done` 会使用默认配置，不会中断任务。

## 提醒模式

```text
silent           静音，只发桌面/手机通知
sound            只播放提示音
voice            只语音播报
voice_and_sound  先提示音，再语音播报
```

## 语音模板

支持变量：

```text
{project}
{message}
{time}
```

示例：

```text
{project} 的任务已经完成
```

## 手机推送

第一版支持 ntfy。可以在 App 中配置 topic，也可以继续使用环境变量：

```bash
export CODEX_NOTIFY_TOPIC="my-codex-topic"
export CODEX_NOTIFY_TITLE="Codex 任务完成"
```

## Codex 工作规则

建议给 Codex 使用：

```text
每当你完成一个阶段性任务并准备回复我时，如果当前项目中存在 `codex-done`、`scripts/codex-done.sh` 或全局可用的 `codex-done` 命令，请在最终回复前运行它，通知内容用一句话概括本阶段完成的工作。如果脚本不存在或通知失败，请不要中断任务，正常回复即可。
```

## 开发验证

```bash
bash tests/test_codex_done.sh
bash -n codex-done tests/test_codex_done.sh
swift test --package-path CodexDoneApp
swift build --package-path CodexDoneApp
```
```

- [ ] **Step 2: Verify documentation references real paths**

Run:

```bash
test -f codex-done
test -f tests/test_codex_done.sh
test -d CodexDoneApp
```

Expected: all commands exit 0.

---

### Task 10: Full Verification And Manual Run

**Files:**
- Verify: `codex-done`
- Verify: `tests/test_codex_done.sh`
- Verify: `CodexDoneApp/`
- Verify: `docs/codex-done.md`

- [ ] **Step 1: Run full shell verification**

Run:

```bash
bash -n codex-done tests/test_codex_done.sh
bash tests/test_codex_done.sh
```

Expected: both commands pass.

- [ ] **Step 2: Run full Swift verification**

Run:

```bash
swift test --package-path CodexDoneApp
swift build --package-path CodexDoneApp
```

Expected: both commands pass.

- [ ] **Step 3: Run CLI smoke test**

Run:

```bash
./codex-done "CodexDone 第一版核心功能验证完成"
```

Expected: command exits 0.

- [ ] **Step 4: Run app manually for visual inspection**

Run:

```bash
CODEX_DONE_CLI_PATH="/path/to/codexdone/codex-done" swift run --package-path CodexDoneApp CodexDoneApp
```

Expected:

- Menu bar item appears.
- Popover shows test reminder, open settings, and copy rule actions.
- Settings window opens.
- Four settings pages are present.
- Test reminder triggers `codex-done`.

- [ ] **Step 5: Record non-git checkpoint**

Run:

```bash
find CodexDoneApp docs tests -maxdepth 4 -type f | sort
bash tests/test_codex_done.sh
swift test --package-path CodexDoneApp
```

Expected: file list prints, shell tests pass, Swift tests pass.
