import Foundation

public struct EnvStore {
    public let envURL: URL

    public init(envURL: URL = CodexDonePaths.defaultEnvURL()) {
        self.envURL = envURL
    }

    public func loadOpenAIAPIKey() throws -> String? {
        let values = try loadValues()
        return nonEmpty(values["OPENAI_API_KEY"])
    }

    public func saveOpenAIAPIKey(_ apiKey: String) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw EnvStoreError.emptyAPIKey
        }
        guard trimmed.rangeOfCharacter(from: .newlines) == nil else {
            throw EnvStoreError.invalidAPIKey
        }

        var values = try loadValues()
        values["OPENAI_API_KEY"] = trimmed
        try saveValues(values)
    }

    public func clearOpenAIAPIKey() throws {
        var values = try loadValues()
        values.removeValue(forKey: "OPENAI_API_KEY")
        try saveValues(values)
    }

    private func loadValues() throws -> [String: String] {
        guard FileManager.default.fileExists(atPath: envURL.path) else {
            return [:]
        }

        let text = try String(contentsOf: envURL, encoding: .utf8)
        var values: [String: String] = [:]
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#"), let equalsIndex = line.firstIndex(of: "=") else {
                continue
            }

            let key = String(line[..<equalsIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let rawValue = String(line[line.index(after: equalsIndex)...])
            guard isValidKey(key) else {
                continue
            }
            values[key] = parseValue(rawValue)
        }
        return values
    }

    private func saveValues(_ values: [String: String]) throws {
        let filtered = values
            .filter { isValidKey($0.key) && nonEmpty($0.value) != nil }
            .sorted { $0.key < $1.key }

        if filtered.isEmpty {
            try? FileManager.default.removeItem(at: envURL)
            return
        }

        let parent = envURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let text = filtered
            .map { "\($0.key)=\(quoteValue($0.value))" }
            .joined(separator: "\n") + "\n"
        let temporaryURL = envURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(envURL.lastPathComponent).\(UUID().uuidString).tmp")
        try text.write(to: temporaryURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporaryURL.path)
        if FileManager.default.fileExists(atPath: envURL.path) {
            try FileManager.default.removeItem(at: envURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: envURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: envURL.path)
    }

    private func parseValue(_ rawValue: String) -> String {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = value.first, let last = value.last else {
            return ""
        }

        if (first == "'" || first == "\""), first == last {
            value.removeFirst()
            value.removeLast()
        }

        if first == "'" {
            return value.replacingOccurrences(of: "'\\''", with: "'")
        }

        if first == "\"" {
            return value
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
        }

        return value
    }

    private func quoteValue(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func isValidKey(_ key: String) -> Bool {
        guard let first = key.unicodeScalars.first,
              CharacterSet.letters.union(CharacterSet(charactersIn: "_")).contains(first) else {
            return false
        }

        return key.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).contains($0)
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

public enum EnvStoreError: LocalizedError {
    case emptyAPIKey
    case invalidAPIKey

    public var errorDescription: String? {
        switch self {
        case .emptyAPIKey:
            return "API Key 不能为空"
        case .invalidAPIKey:
            return "API Key 不能包含换行"
        }
    }
}
