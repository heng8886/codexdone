import Foundation

public struct CodexDoneEvent: Codable, Identifiable, Equatable {
    public var id: String
    public var timestamp: String
    public var epoch: Double?
    public var eventType: String?
    public var project: String
    public var rawMessage: String
    public var message: String
    public var cwd: String?
    public var pid: Int?
    public var taskId: String?
    public var threadId: String?
    public var source: String?
    public var status: String?

    public init(
        id: String,
        timestamp: String,
        epoch: Double? = nil,
        eventType: String? = nil,
        project: String,
        rawMessage: String,
        message: String,
        cwd: String? = nil,
        pid: Int? = nil,
        taskId: String? = nil,
        threadId: String? = nil,
        source: String? = nil,
        status: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.epoch = epoch
        self.eventType = eventType
        self.project = project
        self.rawMessage = rawMessage
        self.message = message
        self.cwd = cwd
        self.pid = pid
        self.taskId = taskId
        self.threadId = threadId
        self.source = source
        self.status = status
    }
}

public struct EventStore {
    public let eventsURL: URL
    public let notifyStateURL: URL

    public init(
        eventsURL: URL = CodexDonePaths.defaultEventsURL(),
        notifyStateURL: URL = CodexDonePaths.defaultNotifyStateURL()
    ) {
        self.eventsURL = eventsURL
        self.notifyStateURL = notifyStateURL
    }

    public func loadRecent(limit: Int = 20) throws -> [CodexDoneEvent] {
        guard FileManager.default.fileExists(atPath: eventsURL.path) else {
            return []
        }

        let text = try String(contentsOf: eventsURL, encoding: .utf8)
        let decoder = JSONDecoder()
        let events = text
            .components(separatedBy: .newlines)
            .compactMap { line -> CodexDoneEvent? in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
                    return nil
                }
                return try? decoder.decode(CodexDoneEvent.self, from: data)
            }

        guard limit > 0 else {
            return []
        }
        return Array(events.suffix(limit).reversed())
    }

    public func clear() throws {
        try? FileManager.default.removeItem(at: eventsURL)
        try? FileManager.default.removeItem(at: notifyStateURL)
    }
}
