import Foundation

public enum TaskDirection: String, Codable, CaseIterable, Sendable {
    case mine
    case owedToMe
}

public enum TaskState: String, Codable, CaseIterable, Sendable {
    case suggested
    case active
    case archived
}

public enum ArchiveReason: String, Codable, CaseIterable, Sendable {
    case completed
    case removed
    case dismissed
    case reviewedTwice
    case expired
}

public enum TaskOrigin: String, Codable, CaseIterable, Sendable {
    case manual
    case voice
    case imported
    case emailFlag
}

public struct TaskChange: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let description: String

    public init(id: UUID = UUID(), date: Date = Date(), description: String) {
        self.id = id
        self.date = date
        self.description = description
    }
}

public struct TaskItem: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var title: String
    public var person: String
    public var notes: String
    public var dueDate: Date
    public var estimatedMinutes: Int?
    public var direction: TaskDirection
    public var state: TaskState
    public var origin: TaskOrigin
    public var sourceText: String?
    public var sourceURL: String?
    public var sourceReference: SourceReference?
    public let createdAt: Date
    public var promisedDueDate: Date?
    public var completedAt: Date?
    public var archivedAt: Date?
    public var archiveReason: ArchiveReason?
    public var reviewSessionIDs: [UUID]
    public var history: [TaskChange]

    // A restored suggestion gets a new review period without changing its creation date.
    public var suggestionCycleStartedAt: Date?
    public var archivedFromState: TaskState?

    public init(
        id: UUID = UUID(),
        title: String,
        dueDate: Date,
        person: String = "",
        notes: String = "",
        estimatedMinutes: Int? = nil,
        direction: TaskDirection = .mine,
        state: TaskState = .active,
        origin: TaskOrigin = .manual,
        sourceText: String? = nil,
        sourceURL: String? = nil,
        sourceReference: SourceReference? = nil,
        createdAt: Date = Date(),
        promisedDueDate: Date? = nil,
        completedAt: Date? = nil,
        archivedAt: Date? = nil,
        archiveReason: ArchiveReason? = nil,
        reviewSessionIDs: [UUID] = [],
        history: [TaskChange] = [],
        suggestionCycleStartedAt: Date? = nil,
        archivedFromState: TaskState? = nil
    ) {
        self.id = id
        self.title = title
        self.person = person
        self.notes = notes
        self.dueDate = dueDate
        self.estimatedMinutes = estimatedMinutes
        self.direction = direction
        self.state = state
        self.origin = origin
        self.sourceText = sourceText
        self.sourceURL = sourceURL
        self.sourceReference = sourceReference
        self.createdAt = createdAt
        self.promisedDueDate = promisedDueDate
        self.completedAt = completedAt
        self.archivedAt = archivedAt
        self.archiveReason = archiveReason
        self.reviewSessionIDs = reviewSessionIDs
        self.history = history
        self.suggestionCycleStartedAt = suggestionCycleStartedAt
        self.archivedFromState = archivedFromState
    }

    public var isCompleted: Bool {
        completedAt != nil
    }

    public var suggestionAgeReferenceDate: Date {
        suggestionCycleStartedAt ?? createdAt
    }

    public func isOverdue(at now: Date = Date()) -> Bool {
        state == .active && !isCompleted && dueDate < now
    }
}
