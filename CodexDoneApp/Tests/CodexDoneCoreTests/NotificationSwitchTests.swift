import XCTest
@testable import CodexDoneCore

final class NotificationSwitchTests: XCTestCase {
    func testSuccessfulUpdatePersistsDisabledState() throws {
        var config = CodexDoneConfig.default
        var savedConfig: CodexDoneConfig?

        try NotificationSwitch.setEnabled(false, config: &config) { value in
            savedConfig = value
        }

        XCTAssertFalse(config.alert.enabled)
        XCTAssertFalse(try XCTUnwrap(savedConfig).alert.enabled)
    }

    func testFailedUpdateRestoresPreviousState() {
        var config = CodexDoneConfig.default

        XCTAssertThrowsError(
            try NotificationSwitch.setEnabled(false, config: &config) { _ in
                throw TestError.saveFailed
            }
        )

        XCTAssertTrue(config.alert.enabled)
    }

    func testQuitDecisionRequiresSuccessfulPause() {
        XCTAssertFalse(
            NotificationSwitch.shouldTerminate(pausingNotifications: true) {
                false
            }
        )
        XCTAssertTrue(
            NotificationSwitch.shouldTerminate(pausingNotifications: true) {
                true
            }
        )
    }

    func testInterfaceOnlyQuitDoesNotAttemptPause() {
        var pauseAttempted = false

        let shouldTerminate = NotificationSwitch.shouldTerminate(pausingNotifications: false) {
            pauseAttempted = true
            return false
        }

        XCTAssertTrue(shouldTerminate)
        XCTAssertFalse(pauseAttempted)
    }

    func testPresentationReflectsEnabledAndPausedStates() {
        let enabled = NotificationSwitchPresentation(isEnabled: true)
        XCTAssertEqual(enabled.statusText, "通知已开启")
        XCTAssertEqual(enabled.actionTitle, "暂停所有通知")
        XCTAssertEqual(enabled.statusSymbolName, "checkmark.circle.fill")
        XCTAssertEqual(enabled.actionSymbolName, "pause.circle")

        let paused = NotificationSwitchPresentation(isEnabled: false)
        XCTAssertEqual(paused.statusText, "通知已暂停")
        XCTAssertEqual(paused.actionTitle, "恢复所有通知")
        XCTAssertEqual(paused.statusSymbolName, "pause.circle.fill")
        XCTAssertEqual(paused.actionSymbolName, "play.circle")
    }

    private enum TestError: Error {
        case saveFailed
    }
}
