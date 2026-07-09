import Foundation

public struct ConfigStore {
    public let configURL: URL

    public init(configURL: URL = CodexDonePaths.defaultConfigURL()) {
        self.configURL = configURL
    }

    public func load() throws -> CodexDoneConfig {
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            return .default
        }

        do {
            let data = try Data(contentsOf: configURL)
            return try JSONDecoder().decode(CodexDoneConfig.self, from: data)
        } catch {
            return .default
        }
    }

    public func save(_ config: CodexDoneConfig) throws {
        let parent = configURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configURL, options: [.atomic])
    }
}
