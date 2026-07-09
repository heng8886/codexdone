import XCTest
@testable import CodexDoneCore

final class CodexGlobalHookManagerTests: XCTestCase {
    func testEnableInstallsWrapperRuleAndPreviousNotifyHook() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.home) }

        try """
        model = "gpt-test"
        notify = ["\(fixture.skyClientPath)", "turn-ended"]
        """.write(to: fixture.configURL, atomically: true, encoding: .utf8)

        try fixture.manager.enable()

        let config = try String(contentsOf: fixture.configURL, encoding: .utf8)
        let agents = try String(contentsOf: fixture.agentsURL, encoding: .utf8)

        XCTAssertTrue(config.contains("SkyComputerUseClient"))
        XCTAssertTrue(config.contains("--previous-notify"))
        XCTAssertTrue(config.contains("codexdone-notify-wrapper.sh"))
        XCTAssertTrue(agents.contains("CodexDone Task Completion Notification"))
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: fixture.wrapperURL.path))
        XCTAssertTrue(fixture.manager.inspect().fullyEnabled)
    }

    func testDisableRemovesCodexDoneHookAndKeepsOriginalNotify() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.home) }

        try """
        model = "gpt-test"
        notify = ["\(fixture.skyClientPath)", "turn-ended"]
        """.write(to: fixture.configURL, atomically: true, encoding: .utf8)

        try fixture.manager.enable()
        try fixture.manager.disable()

        let config = try String(contentsOf: fixture.configURL, encoding: .utf8)
        let agents = try String(contentsOf: fixture.agentsURL, encoding: .utf8)
        let status = fixture.manager.inspect()

        XCTAssertTrue(config.contains("SkyComputerUseClient"))
        XCTAssertFalse(config.contains("codexdone-notify-wrapper.sh"))
        XCTAssertFalse(config.contains("--previous-notify"))
        XCTAssertFalse(agents.contains("CodexDone Task Completion Notification"))
        XCTAssertFalse(status.enabled)
        XCTAssertTrue(status.wrapperInstalled)
    }

    func testDisableRemovesLegacyAgentsBlockWithoutTouchingOtherRules() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.home) }

        try """
        # Keep this rule

        ## CodexDone Task Completion Notification

        Whenever you complete a stage of work and are about to send the final reply, run `codex-done`.

        ## Other Rule

        Leave this alone.
        """.write(to: fixture.agentsURL, atomically: true, encoding: .utf8)

        try fixture.manager.disable()

        let agents = try String(contentsOf: fixture.agentsURL, encoding: .utf8)
        XCTAssertTrue(agents.contains("# Keep this rule"))
        XCTAssertTrue(agents.contains("## Other Rule"))
        XCTAssertTrue(agents.contains("Leave this alone."))
        XCTAssertFalse(agents.contains("CodexDone Task Completion Notification"))
    }

    private func makeFixture() throws -> Fixture {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexDoneGlobalHookTests-\(UUID().uuidString)", isDirectory: true)
        let codexDirectory = home.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)

        let manager = CodexGlobalHookManager(homeDirectory: home, cliPath: "/tmp/codex-done-test")
        let skyClientPath = codexDirectory
            .appendingPathComponent("computer-use", isDirectory: true)
            .appendingPathComponent("Codex Computer Use.app", isDirectory: true)
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("SharedSupport", isDirectory: true)
            .appendingPathComponent("SkyComputerUseClient.app", isDirectory: true)
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent("SkyComputerUseClient")
            .path

        return Fixture(
            home: home,
            manager: manager,
            configURL: codexDirectory.appendingPathComponent("config.toml"),
            agentsURL: codexDirectory.appendingPathComponent("AGENTS.md"),
            wrapperURL: codexDirectory.appendingPathComponent("codexdone-notify-wrapper.sh"),
            skyClientPath: skyClientPath
        )
    }

    private struct Fixture {
        let home: URL
        let manager: CodexGlobalHookManager
        let configURL: URL
        let agentsURL: URL
        let wrapperURL: URL
        let skyClientPath: String
    }
}
