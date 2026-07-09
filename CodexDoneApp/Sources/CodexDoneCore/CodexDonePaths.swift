import Foundation

public enum CodexDonePaths {
    public static func defaultConfigURL(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        homeDirectory
            .appendingPathComponent(".codex-done", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    public static func defaultEnvURL(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        let environmentPath = ProcessInfo.processInfo.environment["CODEX_DONE_ENV"]
        if let environmentPath, !environmentPath.isEmpty {
            return URL(fileURLWithPath: environmentPath)
        }

        return homeDirectory
            .appendingPathComponent(".codex-done", isDirectory: true)
            .appendingPathComponent("env")
    }

    public static func defaultEventsURL(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        let environmentPath = ProcessInfo.processInfo.environment["CODEX_DONE_EVENTS"]
        if let environmentPath, !environmentPath.isEmpty {
            return URL(fileURLWithPath: environmentPath)
        }

        return homeDirectory
            .appendingPathComponent(".codex-done", isDirectory: true)
            .appendingPathComponent("events.jsonl")
    }

    public static func defaultNotifyStateURL(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        let environmentPath = ProcessInfo.processInfo.environment["CODEX_DONE_NOTIFY_STATE"]
        if let environmentPath, !environmentPath.isEmpty {
            return URL(fileURLWithPath: environmentPath)
        }

        return homeDirectory
            .appendingPathComponent(".codex-done", isDirectory: true)
            .appendingPathComponent("notify-state.json")
    }

    public static func defaultCLIPath(
        currentDirectory: String = FileManager.default.currentDirectoryPath
    ) -> String {
        let environmentPath = ProcessInfo.processInfo.environment["CODEX_DONE_CLI_PATH"]
        if let environmentPath, !environmentPath.isEmpty {
            return environmentPath
        }

        if let bundledPath = Bundle.main.resourceURL?
            .appendingPathComponent("codex-done")
            .path,
            FileManager.default.isExecutableFile(atPath: bundledPath) {
            return bundledPath
        }

        let rootRelativePath = URL(fileURLWithPath: currentDirectory)
            .deletingLastPathComponent()
            .appendingPathComponent("codex-done")
            .path

        if FileManager.default.isExecutableFile(atPath: rootRelativePath) {
            return rootRelativePath
        }

        return "/usr/local/bin/codex-done"
    }
}
