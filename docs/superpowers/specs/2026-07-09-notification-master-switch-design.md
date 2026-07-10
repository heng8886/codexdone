# CodexDone Notification Master Switch Design

## Problem

CodexDone notifications are executed by the `codex-done` CLI, not by the settings App process. Closing the App therefore does not stop voice, sound, desktop, or mobile notifications. Removing the Codex global hook is too slow and indirect for already-open Codex tasks because they may retain instructions that continue to call the CLI.

## Goals

- Add one durable master switch that controls every notification channel.
- Make a paused CLI exit successfully before recording events, queueing work, or launching any notification process.
- Let the macOS menu bar App show and change the current state immediately.
- Make quitting the App distinguish between closing the UI and pausing notifications.
- Expose the same state in Web Preview so both configuration surfaces remain compatible.
- Preserve existing configurations by treating a missing switch as enabled.

## Non-Goals

- Do not uninstall the global Codex hook when notifications are paused.
- Do not stop Codex tasks or modify Codex application binaries.
- Do not add schedules, per-project pause state, or a temporary timer in this version.
- Do not bypass the master switch for test notifications.

## Architecture

`alert.enabled` in `~/.codex-done/config.json` is the single source of truth. It is a Boolean and defaults to `true` when missing, so existing installations continue to work.

The CLI supports three management commands:

- `codex-done --enable` atomically writes `alert.enabled=true` and prints `enabled`.
- `codex-done --disable` atomically writes `alert.enabled=false` and prints `disabled`.
- `codex-done --status` prints `enabled` or `disabled` without changing configuration.

Management commands never create completion events or notifications. A normal completion invocation checks `alert.enabled` immediately after argument parsing. When disabled it exits with status 0 and does not write the event log, acquire the queue lock, call `say`/`afplay`/`osascript`, or send network requests.

The Swift configuration model adds `AlertConfig.enabled` with backward-compatible decoding. `AppState` owns enable/disable actions and saves through the existing `ConfigStore`. The menu bar icon and status text reflect the current state. The menu offers a direct pause/resume action and disables the test button while paused.

Choosing “退出 CodexDone” presents two explicit actions:

- “仅退出界面”：terminate the App and preserve the current notification state.
- “暂停通知并退出”：persist `alert.enabled=false`, then terminate the App only after the save succeeds.

Web Preview adds the same master switch to status and reminder views. Its server normalizer defaults missing values to `true` and preserves the value on every save.

## Error Handling

- CLI control commands fail nonzero with a concise error if configuration cannot be written.
- App pause/resume actions keep the previous in-memory state if saving fails and show the existing status message.
- “暂停通知并退出” does not quit when persistence fails, so the UI cannot claim a paused state that was not saved.
- Damaged CLI configuration is replaced only when the user explicitly runs `--enable` or `--disable`; normal notification behavior retains the current fallback rules.

## Testing

- Shell tests prove disabled mode creates no event log and launches no notification stub.
- Shell tests prove enable, disable, status, persistence, missing config, and re-enable behavior.
- Swift tests prove default state, round-trip encoding, and backward-compatible decoding.
- Node syntax and normalization checks prove Web Preview preserves `alert.enabled`.
- Full shell and Swift test suites, release build, app bundle build, and a real temporary-config CLI test form the completion gate.

## Security And Privacy

The switch stores only a Boolean in the existing local configuration. Tests use temporary paths and placeholder data. No API keys, mobile recipients, event logs, or user-specific paths are added to the repository.
