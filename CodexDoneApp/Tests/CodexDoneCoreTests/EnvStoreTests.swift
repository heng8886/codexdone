import XCTest
@testable import CodexDoneCore

final class EnvStoreTests: XCTestCase {
    func testSaveLoadAndClearOpenAIAPIKey() throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("env")
        let store = EnvStore(envURL: url)

        XCTAssertNil(try store.loadOpenAIAPIKey())

        try store.saveOpenAIAPIKey("test-openai-key")

        XCTAssertEqual(try store.loadOpenAIAPIKey(), "test-openai-key")
        XCTAssertEqual(try fileMode(at: url), 0o600)

        try store.clearOpenAIAPIKey()

        XCTAssertNil(try store.loadOpenAIAPIKey())
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testPreservesOtherEnvValuesWhenUpdatingOpenAIAPIKey() throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("env")
        try "CODEX_NOTIFY_TOPIC='topic-one'\nOPENAI_API_KEY='old-key'\n"
            .write(to: url, atomically: true, encoding: .utf8)
        let store = EnvStore(envURL: url)

        try store.saveOpenAIAPIKey("new-key")

        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("CODEX_NOTIFY_TOPIC='topic-one'"))
        XCTAssertTrue(text.contains("OPENAI_API_KEY='new-key'"))

        try store.clearOpenAIAPIKey()

        let clearedText = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(clearedText.contains("CODEX_NOTIFY_TOPIC='topic-one'"))
        XCTAssertFalse(clearedText.contains("OPENAI_API_KEY"))
    }

    func testRejectsEmptyAndMultilineKeys() throws {
        let directory = try temporaryDirectory()
        let store = EnvStore(envURL: directory.appendingPathComponent("env"))

        XCTAssertThrowsError(try store.saveOpenAIAPIKey("   "))
        XCTAssertThrowsError(try store.saveOpenAIAPIKey("test-openai-key\nnext-line"))
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexDoneEnvStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func fileMode(at url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.posixPermissions] as? Int ?? 0
    }
}
