import XCTest
@testable import CodexDoneCore

final class EventStoreTests: XCTestCase {
    func testLoadRecentReturnsNewestEventsFirst() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let eventsURL = directory.appendingPathComponent("events.jsonl")
        try """
        {"id":"1","timestamp":"2026-07-08T00:00:00Z","epoch":1,"project":"A","rawMessage":"one","message":"A: one","cwd":"/tmp/a","pid":1,"source":"codex-done","status":"completed"}
        broken json
        {"id":"2","timestamp":"2026-07-08T00:00:01Z","epoch":2,"project":"B","rawMessage":"two","message":"B: two","cwd":"/tmp/b","pid":2,"source":"codex-done","status":"completed"}
        {"id":"3","timestamp":"2026-07-08T00:00:02Z","epoch":3,"project":"C","rawMessage":"three","message":"C: three","cwd":"/tmp/c","pid":3,"source":"codex-done","status":"completed"}

        """.write(to: eventsURL, atomically: true, encoding: .utf8)

        let events = try EventStore(eventsURL: eventsURL).loadRecent(limit: 2)

        XCTAssertEqual(events.map(\.id), ["3", "2"])
        XCTAssertEqual(events.first?.rawMessage, "three")
    }

    func testLoadRecentReturnsEmptyArrayForMissingFile() throws {
        let eventsURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("events.jsonl")

        let events = try EventStore(eventsURL: eventsURL).loadRecent()

        XCTAssertTrue(events.isEmpty)
    }

    func testClearRemovesEventsAndNotifyStateFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let eventsURL = directory.appendingPathComponent("events.jsonl")
        let notifyStateURL = directory.appendingPathComponent("notify-state.json")
        try "{}\n".write(to: eventsURL, atomically: true, encoding: .utf8)
        try "{}\n".write(to: notifyStateURL, atomically: true, encoding: .utf8)

        try EventStore(eventsURL: eventsURL, notifyStateURL: notifyStateURL).clear()

        XCTAssertFalse(FileManager.default.fileExists(atPath: eventsURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: notifyStateURL.path))
    }
}
