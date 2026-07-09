import Foundation

public struct MacOSSound: Equatable, Hashable, Identifiable, Sendable {
    public var name: String
    public var url: URL

    public var id: String {
        url.path
    }

    public init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}

public enum MacOSSoundCatalog {
    private static let supportedExtensions: Set<String> = [
        "aif",
        "aiff",
        "caf",
        "mp3",
        "wav"
    ]

    public static func defaultSearchDirectories(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [URL] {
        [
            homeDirectory.appendingPathComponent("Library/Sounds", isDirectory: true),
            URL(fileURLWithPath: "/System/Library/Sounds", isDirectory: true),
            URL(fileURLWithPath: "/Library/Sounds", isDirectory: true)
        ]
    }

    public static func availableSounds(
        searchDirectories: [URL] = defaultSearchDirectories()
    ) -> [MacOSSound] {
        let discoveredSounds = searchDirectories.flatMap { Self.sounds(in: $0) }
        var seenNames = Set<String>()

        return discoveredSounds
            .filter { sound in
                seenNames.insert(sound.name).inserted
            }
            .sorted { lhs, rhs in
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    public static func soundURL(
        named soundName: String,
        customFilePath: String? = nil,
        searchDirectories: [URL] = defaultSearchDirectories()
    ) -> URL? {
        if let customFilePath,
           !customFilePath.isEmpty,
           FileManager.default.fileExists(atPath: customFilePath) {
            return URL(fileURLWithPath: customFilePath)
        }

        let sounds = availableSounds(searchDirectories: searchDirectories)
        if let sound = sounds.first(where: { $0.name == soundName }) {
            return sound.url
        }

        return sounds.first(where: { $0.name == "Ping" })?.url
    }

    public static func sounds(in directory: URL) -> [MacOSSound] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return urls.compactMap { url in
            guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
                return nil
            }

            return MacOSSound(
                name: url.deletingPathExtension().lastPathComponent,
                url: url
            )
        }
    }
}
