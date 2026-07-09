import Foundation

public struct MacOSVoice: Equatable, Hashable, Identifiable, Sendable {
    public var name: String
    public var languageCode: String
    public var sample: String

    public var id: String {
        "\(name)|\(languageCode)"
    }

    public init(name: String, languageCode: String, sample: String) {
        self.name = name
        self.languageCode = languageCode
        self.sample = sample
    }
}

public enum MacOSVoiceCatalog {
    public static func availableVoices() -> [MacOSVoice] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = ["-v", "?"]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        guard process.terminationStatus == 0 else {
            return []
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else {
            return []
        }

        return parseSayVoiceList(text)
    }

    public static func parseSayVoiceList(_ text: String) -> [MacOSVoice] {
        text
            .split(whereSeparator: \.isNewline)
            .compactMap { parseLine(String($0)) }
    }

    private static func parseLine(_ line: String) -> MacOSVoice? {
        let parts = line.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        guard let left = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !left.isEmpty,
              let languageRange = left.range(
                of: #"[A-Za-z]{2,3}_[A-Za-z0-9]+$"#,
                options: .regularExpression
              ) else {
            return nil
        }

        let name = left[..<languageRange.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return nil
        }

        let languageCode = String(left[languageRange])
            .replacingOccurrences(of: "_", with: "-")
        let sample = parts.count > 1
            ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            : ""

        return MacOSVoice(
            name: String(name),
            languageCode: languageCode,
            sample: sample
        )
    }
}
