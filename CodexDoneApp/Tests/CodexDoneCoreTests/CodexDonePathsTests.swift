import XCTest
@testable import CodexDoneCore

final class CodexDonePathsTests: XCTestCase {
    func testDefaultConfigURLUsesDotCodexDoneDirectory() {
        let home = URL(fileURLWithPath: "/tmp/test-home", isDirectory: true)

        let url = CodexDonePaths.defaultConfigURL(homeDirectory: home)

        XCTAssertEqual(url.path, "/tmp/test-home/.codex-done/config.json")
    }

    func testDefaultEnvURLUsesDotCodexDoneDirectory() {
        let home = URL(fileURLWithPath: "/tmp/test-home", isDirectory: true)

        let url = CodexDonePaths.defaultEnvURL(homeDirectory: home)

        XCTAssertEqual(url.path, "/tmp/test-home/.codex-done/env")
    }

    func testDefaultEventsURLUsesDotCodexDoneDirectory() {
        let home = URL(fileURLWithPath: "/tmp/test-home", isDirectory: true)

        let url = CodexDonePaths.defaultEventsURL(homeDirectory: home)

        XCTAssertEqual(url.path, "/tmp/test-home/.codex-done/events.jsonl")
    }

    func testDefaultNotifyStateURLUsesDotCodexDoneDirectory() {
        let home = URL(fileURLWithPath: "/tmp/test-home", isDirectory: true)

        let url = CodexDonePaths.defaultNotifyStateURL(homeDirectory: home)

        XCTAssertEqual(url.path, "/tmp/test-home/.codex-done/notify-state.json")
    }
}
