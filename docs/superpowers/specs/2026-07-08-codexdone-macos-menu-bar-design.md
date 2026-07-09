# CodexDone macOS Menu Bar App Design

## Summary

CodexDone will evolve from a single `codex-done` notification script into a macOS-native menu bar app with a settings window. The app will configure and test completion reminders, while the existing CLI entry point remains the automation bridge that Codex calls when a task finishes.

The first version focuses on a practical local workflow: configure alert behavior, customize spoken content, test voice/sound/mobile notifications, and copy Codex integration instructions. It will not attempt to automatically detect Codex task state.

## Goals

- Provide a lightweight macOS menu bar app that stays out of the way during normal work.
- Offer a settings window for notification, voice, sound, mobile push, and Codex integration settings.
- Keep `codex-done` as the stable command-line entry point for Codex workflows.
- Support global reminder modes in version one: silent, sound, voice, and voice plus sound.
- Let the user customize spoken reminder content.
- Use macOS system speech and sounds in version one.
- Design the configuration model so future realistic TTS providers can be added without replacing the app structure.

## Non-Goals For Version One

- No automatic monitoring of Codex task state.
- No AI realistic voice provider integration yet.
- No per-event reminder configuration UI yet.
- No account system, cloud sync, or multi-device sync.
- No Windows or Linux desktop support.

## Product Shape

CodexDone will be a macOS-native SwiftUI app with two visible surfaces.

The menu bar popover contains high-frequency actions:

- Test reminder.
- Open settings.
- Copy Codex work rule.
- Show current reminder mode and mobile push status.

The settings window contains four pages:

- Status.
- Reminder Mode.
- Voice Content.
- Codex Integration.

This shape keeps daily use compact while still giving enough room for configuration.

## Architecture

```text
CodexDone.app
  -> macOS menu bar UI
  -> settings window
  -> configuration editor
  -> reminder test runner
  -> Codex rule generator
  -> writes ~/.codex-done/config.json

codex-done
  -> command-line entry point
  -> reads ~/.codex-done/config.json
  -> applies defaults if config is missing or damaged
  -> performs sound, voice, desktop notification, and mobile push actions

Alert Engine
  -> evaluates reminder mode
  -> renders message templates
  -> plays sound
  -> speaks message
  -> sends macOS notification
  -> sends ntfy push when configured
```

The app owns configuration and user experience. The CLI owns automation. This split keeps Codex integration simple and preserves script compatibility.

## Configuration

Version one should use JSON instead of an env file because the data will grow beyond a few flat variables.

Recommended path:

```text
~/.codex-done/config.json
```

Initial configuration shape:

```json
{
  "version": 1,
  "alert": {
    "mode": "voice_and_sound",
    "desktopNotification": true,
    "mobilePush": true
  },
  "sound": {
    "provider": "macos",
    "name": "Ping",
    "repeatCount": 1,
    "customFilePath": null
  },
  "voice": {
    "provider": "macos",
    "language": "zh-CN",
    "voiceName": null,
    "rate": 180,
    "messageTemplate": "{project} 的任务已经完成"
  },
  "mobile": {
    "provider": "ntfy",
    "topic": "",
    "title": "Codex 任务完成"
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
```

The `events` section is reserved for later per-event configuration. Version one reads only global settings.

## Reminder Modes

Version one supports one global reminder mode:

```text
silent
sound
voice
voice_and_sound
```

Behavior:

- `silent`: do not play sound or voice; desktop/mobile notifications can still run.
- `sound`: play the configured prompt sound.
- `voice`: speak the rendered message template.
- `voice_and_sound`: play the configured prompt sound, then speak the rendered message.

## Message Templates

The user can edit the default spoken text. Version one supports these variables:

```text
{project}
{message}
{time}
```

Example:

```text
{project} 的任务已经完成
```

Future variables can include:

```text
{duration}
{status}
{branch}
{testResult}
```

## Voice Design

Version one uses macOS system speech. The UI should expose:

- Language.
- System voice name.
- Speech rate.
- Message template.
- Test voice button.

The implementation should not hard-code one voice. It should query available macOS voices where practical and store the selected voice name in config.

Future realistic TTS providers should fit behind the same voice interface:

```text
provider: openai | azure | elevenlabs
voiceId: provider-specific voice
genderPreference: female | male | neutral
style: calm | energetic | professional
cacheAudio: true | false
```

If a future AI voice provider fails, the system should fall back to macOS system speech when possible.

## Sound Design

Version one supports macOS system sounds and may later support a custom audio file path.

The UI should expose:

- Sound name.
- Repeat count.
- Test sound button.

The CLI should skip sound playback without failing if the selected sound is unavailable.

## Mobile Push

Version one supports ntfy.

The UI should expose:

- Topic.
- Notification title.
- Test mobile push button.

The CLI should support both a raw topic and a full ntfy URL. Push failure must not cause `codex-done` to exit with failure during a Codex workflow.

## Settings Window Pages

### Status

Shows current system status:

- Local reminder availability.
- Mobile push configuration status.
- Current reminder mode.
- Configuration file path.
- Test full reminder button.

### Reminder Mode

Controls global alert behavior:

- Segmented control or equivalent for silent, sound, voice, voice plus sound.
- Sound picker.
- Repeat count.
- Test sound button.

### Voice Content

Controls spoken output:

- Message template editor.
- Language picker.
- Voice picker.
- Rate control.
- Test voice button.
- Future provider fields hidden or disabled for version one.

### Codex Integration

Helps connect the tool to Codex:

- Shows the command path for `codex-done`.
- Generates a Codex work rule.
- Provides copy button for the rule.
- Shows example usage.

Suggested generated rule:

```text
每当你完成一个阶段性任务并准备回复我时，如果当前项目中存在 `codex-done`、`scripts/codex-done.sh` 或全局可用的 `codex-done` 命令，请在最终回复前运行它，通知内容用一句话概括本阶段完成的工作。如果脚本不存在或通知失败，请不要中断任务，正常回复即可。
```

## Error Handling

Reminder failures should never block Codex from completing a task.

Expected behavior:

- Missing config: use defaults.
- Damaged config: use defaults and show repair warning in the app.
- Missing `say`: skip voice.
- Missing or unavailable sound: skip sound.
- ntfy failure: record or display the error, but do not fail the CLI in normal mode.
- Future AI voice failure: fall back to macOS speech where possible.

## Testing Requirements

Core behavior to test:

- `codex-done` runs with no config.
- `codex-done` reads JSON config when present.
- Global alert modes produce the expected actions.
- Message templates render `{project}`, `{message}`, and `{time}`.
- ntfy push is skipped when not configured.
- ntfy failure does not fail normal completion flow.
- Damaged config falls back to defaults.
- The app can save and reload config.
- The app can generate the Codex work rule.

## Delivery Criteria

Version one is complete when:

- The macOS menu bar app launches.
- The menu bar popover exposes test reminder, settings, and copy rule actions.
- The settings window contains the four planned pages.
- Global reminder mode can be saved and read.
- Spoken message template can be edited and tested.
- Sound selection can be tested.
- ntfy topic and title can be configured and tested.
- Codex integration rule can be copied.
- `codex-done` reads the app config and performs reminders.
- Automated tests cover CLI configuration and failure behavior.

## Open Implementation Notes

- The implementation plan should decide whether to keep `codex-done` in Bash or move the CLI core to Swift or another compiled helper.
- The first implementation should favor a minimal reliable path over packaging polish.
- If the workspace remains outside git, implementation checkpoints should be tracked by files and test output rather than commits.
