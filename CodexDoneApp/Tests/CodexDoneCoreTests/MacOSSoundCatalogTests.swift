import XCTest
@testable import CodexDoneCore

final class MacOSSoundCatalogTests: XCTestCase {
    func testLoadsSupportedSoundFilesAndIgnoresOthers() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let ping = directory.appendingPathComponent("Ping.aiff")
        let custom = directory.appendingPathComponent("custom-notification.wav")
        let ignored = directory.appendingPathComponent("notes.txt")
        try Data().write(to: ping)
        try Data().write(to: custom)
        try Data().write(to: ignored)

        let sounds = MacOSSoundCatalog.availableSounds(searchDirectories: [directory])

        XCTAssertEqual(sounds.map(\.name), ["custom-notification", "Ping"])
    }

    func testSoundURLFallsBackToPing() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let ping = directory.appendingPathComponent("Ping.aiff")
        try Data().write(to: ping)

        let url = MacOSSoundCatalog.soundURL(
            named: "Missing",
            searchDirectories: [directory]
        )

        XCTAssertEqual(url, ping)
    }
}
