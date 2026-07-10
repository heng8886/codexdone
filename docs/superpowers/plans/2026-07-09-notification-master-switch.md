# CodexDone Notification Master Switch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a durable master switch that immediately suppresses every CodexDone notification channel, even when an already-open Codex task still calls the CLI.

**Architecture:** Store the state as backward-compatible `alert.enabled` configuration shared by Bash, Swift, and Web Preview. Make the CLI the enforcement boundary by exiting before event recording or notification dispatch when paused; expose state-management commands and native menu bar controls on top of the same value.

**Tech Stack:** Bash, Python 3 standard library for atomic JSON updates, Swift 5.9/SwiftUI/AppKit, XCTest, Node.js, macOS app bundle scripts.

---

## File Structure

- Modify `codex-done`: parse control commands, atomically update the switch, and enforce it before side effects.
- Modify `tests/test_codex_done.sh`: add CLI red/green coverage for disabled, enabled, status, and missing-config behavior.
- Modify `CodexDoneApp/Sources/CodexDoneCore/CodexDoneConfig.swift`: add backward-compatible `AlertConfig.enabled`.
- Modify `CodexDoneApp/Tests/CodexDoneCoreTests/CodexDoneConfigTests.swift`: cover defaults, round trips, and legacy JSON.
- Modify `CodexDoneApp/Sources/CodexDoneApp/AppState.swift`: persist pause/resume and pause-before-quit actions.
- Modify `CodexDoneApp/Sources/CodexDoneApp/Views/MenuBarContentView.swift`: expose status, pause/resume, and explicit quit choices.
- Modify `CodexDoneApp/Sources/CodexDoneApp/CodexDoneApp.swift`: make the menu bar icon reflect the switch.
- Modify `CodexDoneWebPreview/server.js`: default and normalize `alert.enabled`.
- Modify `CodexDoneWebPreview/public/app.js`: display and edit the switch.
- Modify `README.md` and `docs/codex-done.md`: document lifecycle semantics and CLI commands.

### Task 1: CLI Master-Switch Contract

**Files:**
- Modify: `tests/test_codex_done.sh`
- Modify: `codex-done`

- [ ] **Step 1: Write failing shell tests**

Add tests that invoke the real script with temporary config and stub commands. Assert that `--disable` prints `disabled`, writes `alert.enabled=false`, and does not create event or notification logs. Invoke a normal completion and assert the same no-side-effect behavior. Assert `--status` prints `disabled`, then run `--enable`, assert `enabled`, and verify a subsequent completion creates one event and calls the configured stubs.

- [ ] **Step 2: Run the focused test and verify RED**

Run `bash tests/test_codex_done.sh`. Expected: the new assertions fail because `--disable`, `--enable`, and `--status` are currently treated as message text and notifications still run.

- [ ] **Step 3: Implement the minimal CLI behavior**

Add `control_action` argument parsing. Add `set_notifications_enabled()` that uses Python to load a JSON object, ensure a complete `alert` object, set `enabled`, write a mode-0600 temporary file in the same directory, and replace the target atomically. Add `notifications_enabled()` using `config_value "alert.enabled" "true"`. Handle control actions before rendering; for normal invocations return 0 immediately when disabled.

- [ ] **Step 4: Run shell tests and verify GREEN**

Run `bash tests/test_codex_done.sh`. Expected: `ok - codex-done behavior verified`.

### Task 2: Swift Configuration And App State

**Files:**
- Modify: `CodexDoneApp/Tests/CodexDoneCoreTests/CodexDoneConfigTests.swift`
- Modify: `CodexDoneApp/Sources/CodexDoneCore/CodexDoneConfig.swift`
- Modify: `CodexDoneApp/Sources/CodexDoneApp/AppState.swift`

- [ ] **Step 1: Write failing Swift tests**

Assert `CodexDoneConfig.default.alert.enabled == true`, round-trip a disabled configuration, and decode legacy alert JSON without `enabled` while preserving `true`.

- [ ] **Step 2: Run Swift tests and verify RED**

Run `swift test --package-path CodexDoneApp`. Expected: compile failure because `AlertConfig` has no `enabled` property.

- [ ] **Step 3: Implement backward-compatible model and state actions**

Add `enabled` to `AlertConfig`, explicit coding keys, and a decoder that falls back to true. Add `setNotificationsEnabled(_:) -> Bool` to `AppState`; preserve the old value on save failure. Add `quitApp(pausingNotifications:)` that saves disabled state before terminating and returns without terminating if save fails. Keep `quitApp()` as the UI-only path if needed by existing call sites.

- [ ] **Step 4: Run Swift tests and verify GREEN**

Run `swift test --package-path CodexDoneApp`. Expected: all tests pass.

### Task 3: Native Menu Bar Controls

**Files:**
- Modify: `CodexDoneApp/Sources/CodexDoneApp/Views/MenuBarContentView.swift`
- Modify: `CodexDoneApp/Sources/CodexDoneApp/CodexDoneApp.swift`

- [ ] **Step 1: Implement state-forward UI**

Show “通知已开启” with green state or “通知已暂停” with orange state. Add one direct pause/resume button with `pause.circle` or `play.circle`. Disable “测试提醒” while paused and explain its disabled state through the visible status, without adding instructional copy.

- [ ] **Step 2: Implement explicit quit choices**

Use a SwiftUI `confirmationDialog` owned by `MenuBarContentView`. Provide “仅退出界面”, “暂停通知并退出”, and cancel. Route both actions through `AppState` so persistence remains outside the view.

- [ ] **Step 3: Make the menu icon reflect state**

Use `checkmark.circle` while enabled and `pause.circle` while disabled. Keep menu labels concise and system-native.

- [ ] **Step 4: Build the App**

Run `swift build --package-path CodexDoneApp`. Expected: `Build complete!` with exit 0.

### Task 4: Web Preview Compatibility

**Files:**
- Modify: `CodexDoneWebPreview/server.js`
- Modify: `CodexDoneWebPreview/public/app.js`

- [ ] **Step 1: Add normalized server state**

Add `enabled: true` to the default alert and normalize it with `booleanValue`. This must preserve `false` through API saves and default missing legacy values to `true`.

- [ ] **Step 2: Add status and reminder controls**

Show the master state in the status metrics and add a checkbox labeled “启用所有通知” to the reminder section. Keep the existing mode, desktop, and mobile controls unchanged.

- [ ] **Step 3: Verify JavaScript syntax**

Run `node --check CodexDoneWebPreview/server.js` and `node --check CodexDoneWebPreview/public/app.js`. Expected: both exit 0 without output.

### Task 5: Documentation, Packaging, And Completion Audit

**Files:**
- Modify: `README.md`
- Modify: `docs/codex-done.md`
- Generated, ignored: `dist/CodexDone.app`

- [ ] **Step 1: Document exact semantics**

Document `--enable`, `--disable`, and `--status`; clarify that quitting the App can leave CLI notifications active; explain the two quit choices and that pause affects existing tasks immediately without uninstalling the hook.

- [ ] **Step 2: Run the complete verification suite**

Run:

```bash
bash -n codex-done tests/test_codex_done.sh scripts/install.sh tests/test_install_scripts.sh
bash tests/test_codex_done.sh
bash tests/test_install_scripts.sh
swift test --package-path CodexDoneApp
swift build --package-path CodexDoneApp
node --check CodexDoneWebPreview/server.js
node --check CodexDoneWebPreview/public/app.js
scripts/build-codexdone-app.sh
```

Expected: every command exits 0; both behavior suites print their `ok` line; Swift reports all tests passed and a successful build; the app builder reports `Built .../dist/CodexDone.app`.

- [ ] **Step 3: Verify real pause behavior with isolated state**

Use a temporary `CODEX_DONE_CONFIG`, `CODEX_DONE_EVENTS`, and stub `say`/`afplay`/`osascript`. Run `codex-done --disable`, then a completion. Verify no event or stub output exists. Re-enable, run a completion, and verify exactly one event exists.

- [ ] **Step 4: Inspect privacy and diff scope**

Run `git diff --check`, inspect `git diff --stat`, and scan tracked changes for API-key/token patterns and user-home absolute paths. Expected: no whitespace errors, secrets, personal recipients, event data, or machine-specific paths.

- [ ] **Step 5: Integrate and publish**

Commit the feature branch, merge it to `main`, rerun the verification suite on the merged tree, rebuild `dist/CodexDone.app`, reinstall the local CLI symlink if needed, and push `main` to `origin`. Confirm local and remote `main` resolve to the same commit.
