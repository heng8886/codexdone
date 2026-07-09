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
