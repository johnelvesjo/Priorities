import Foundation

public enum TaskRepositoryError: Error, LocalizedError, Equatable {
    case unreadableData(String)
    case unsupportedFormatVersion(Int)
    case invalidTaskData(String)

    public var errorDescription: String? {
        switch self {
        case .unreadableData(let detail):
            return "Saved tasks could not be read. The existing file has been left unchanged. \(detail)"
        case .unsupportedFormatVersion(let version):
            return "The saved tasks use format version \(version), which this app does not support. The file has been left unchanged."
        case .invalidTaskData(let detail):
            return "Tasks could not be saved or loaded. \(detail)"
        }
    }
}

public struct TaskRepository: Sendable {
    public let fileURL: URL

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("tasks.json", isDirectory: false)
    }

    public func load() throws -> [TaskItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw TaskRepositoryError.unreadableData(error.localizedDescription)
        }
        return try decode(data)
    }

    public func save(_ tasks: [TaskItem]) throws {
        try validate(tasks)

        // Validate an existing file before replacing it, including after a failed load.
        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try load()
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        // The default date representation preserves Date values without truncating fractions.
        let data = try encoder.encode(StorageDocument(formatVersion: 1, tasks: tasks))
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try data.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    private func decode(_ data: Data) throws -> [TaskItem] {
        let decoder = JSONDecoder()
        let document: StorageDocument
        do {
            let header = try decoder.decode(StorageHeader.self, from: data)
            guard header.formatVersion == 1 else {
                throw TaskRepositoryError.unsupportedFormatVersion(header.formatVersion)
            }
            document = try decoder.decode(StorageDocument.self, from: data)
        } catch let error as TaskRepositoryError {
            throw error
        } catch {
            throw TaskRepositoryError.unreadableData(error.localizedDescription)
        }
        try validate(document.tasks)
        return document.tasks
    }

    private func validate(_ tasks: [TaskItem]) throws {
        guard Set(tasks.map(\.id)).count == tasks.count else {
            throw TaskRepositoryError.invalidTaskData("Task identifiers must be unique.")
        }
        for task in tasks {
            guard !task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw TaskRepositoryError.invalidTaskData("A task needs a title.")
            }
            if let minutes = task.estimatedMinutes, minutes < 0 {
                throw TaskRepositoryError.invalidTaskData("Estimated time cannot be negative.")
            }
            let dates = [task.createdAt, task.dueDate]
                + [task.promisedDueDate, task.completedAt, task.archivedAt, task.suggestionCycleStartedAt].compactMap { $0 }
                + task.history.map(\.date)
            guard dates.allSatisfy({ $0.timeIntervalSinceReferenceDate.isFinite }) else {
                throw TaskRepositoryError.invalidTaskData("Task dates must be finite.")
            }
        }
    }
}

private struct StorageHeader: Decodable {
    let formatVersion: Int
}

private struct StorageDocument: Codable {
    let formatVersion: Int
    let tasks: [TaskItem]
}
