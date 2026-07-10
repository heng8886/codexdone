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

    private enum TestError: Error {
        case saveFailed
    }
}
