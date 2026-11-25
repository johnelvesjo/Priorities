import CryptoKit
import Foundation

public enum EmailProvider: String, Codable, CaseIterable, Sendable {
    case outlook
    case gmail
}

public struct SourceReference: Codable, Equatable, Sendable {
    public let provider: EmailProvider
    public let accountID: String
    public let messageID: String
    public var sourceURL: String?

    public init(provider: EmailProvider, accountID: String, messageID: String, sourceURL: String? = nil) {
        self.provider = provider
        self.accountID = accountID
        self.messageID = messageID
        self.sourceURL = sourceURL
    }

    public var sourceKey: String {
        // Preserve case and use length prefixes so separators inside IDs cannot collide.
        "\(provider.rawValue):\(accountID.utf8.count):\(accountID):\(messageID.utf8.count):\(messageID)"
    }

    public var hasValidIdentity: Bool {
        !accountID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !messageID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public struct FlaggedEmail: Codable, Equatable, Sendable {
    public let source: SourceReference
    public let sender: String
    public let subject: String
    public let evidence: String
    public let date: Date
    public let flaggedDueDate: Date?
    public let isFlagged: Bool

    public init(
        source: SourceReference,
        sender: String,
        subject: String,
        evidence: String,
        date: Date,
        flaggedDueDate: Date? = nil,
        isFlagged: Bool = true
    ) {
        self.source = source
        self.sender = sender
        self.subject = subject
        self.evidence = evidence
        self.date = date
        self.flaggedDueDate = flaggedDueDate
        self.isFlagged = isFlagged
    }
}

public enum EmailFlagUpsertResult: Equatable, Sendable {
    case created(UUID)
    case updated(UUID)
    case unchanged(UUID)

    public var taskID: UUID {
        switch self {
        case .created(let id), .updated(let id), .unchanged(let id): return id
        }
    }
}

public enum SourceWriteOperation: String, Codable, Sendable {
    case clearOutlookFollowUpFlag
    case removeGmailStar
}

public enum SourceWriteState: String, Codable, Sendable {
    case pending
}

public struct SourceWriteIntent: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let taskID: UUID
    public let source: SourceReference
    public let operation: SourceWriteOperation
    public let state: SourceWriteState
    public let createdAt: Date
    public let taskCompletedAt: Date

    public var outlookFlagStatus: String? {
        operation == .clearOutlookFollowUpFlag ? "notFlagged" : nil
    }

    public var gmailLabelIDsToRemove: [String] {
        operation == .removeGmailStar ? ["STARRED"] : []
    }
}

public enum EmailFlagBridge {
    @discardableResult
    public static func upsert(
        _ email: FlaggedEmail,
        tasks: inout [TaskItem],
        now: Date = Date(),
        proposedDueDate: Date,
        gmailStarsAreFollowUp: Bool = false
    ) -> EmailFlagUpsertResult? {
        guard email.isFlagged, email.source.hasValidIdentity else { return nil }
        guard email.source.provider != .gmail || gmailStarsAreFollowUp else { return nil }
        guard [now, email.date, proposedDueDate, email.flaggedDueDate].compactMap({ $0 })
            .allSatisfy({ $0.timeIntervalSinceReferenceDate.isFinite }) else { return nil }

        if let index = tasks.firstIndex(where: { $0.sourceReference?.sourceKey == email.source.sourceKey }) {
            let before = tasks[index]
            if !email.evidence.isEmpty { tasks[index].sourceText = email.evidence }
            if let url = email.source.sourceURL {
                tasks[index].sourceURL = url
                tasks[index].sourceReference?.sourceURL = url
            }
            if tasks[index].state == .suggested, !tasks[index].isCompleted {
                TaskEngine.approve(&tasks[index], now: now)
            }
            guard tasks[index] != before else { return .unchanged(tasks[index].id) }
            tasks[index].history.append(TaskChange(date: now, description: "Updated linked flagged email."))
            return .updated(tasks[index].id)
        }

        let subject = email.subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let messageDate = ISO8601DateFormatter().string(from: email.date)
        let task = TaskItem(
            id: stableID("Priorities.emailFlag.v1:\(email.source.sourceKey)"),
            title: subject.isEmpty ? "Follow up on email" : subject,
            dueDate: email.flaggedDueDate ?? proposedDueDate,
            person: email.sender,
            direction: .mine,
            state: .active,
            origin: .emailFlag,
            sourceText: email.evidence.isEmpty ? nil : email.evidence,
            sourceURL: email.source.sourceURL,
            sourceReference: email.source,
            createdAt: now,
            history: [TaskChange(date: now, description: "Added from a flagged email dated \(messageDate).")]
        )
        // Deterministic IDs also prevent a duplicate if a prior task lost its source reference.
        guard !tasks.contains(where: { $0.id == task.id }) else { return .unchanged(task.id) }
        tasks.append(task)
        return .created(task.id)
    }

    public static func clearFlagIntent(
        for task: TaskItem,
        supportsFlagClearing: Bool,
        now: Date = Date(),
        gmailStarsAreFollowUp: Bool = false
    ) -> SourceWriteIntent? {
        guard supportsFlagClearing,
              let completedAt = task.completedAt,
              let source = task.sourceReference,
              source.hasValidIdentity,
              completedAt.timeIntervalSinceReferenceDate.isFinite,
              now.timeIntervalSinceReferenceDate.isFinite,
              task.state == .active || (task.state == .archived && task.archiveReason == .completed)
        else { return nil }
        guard source.provider != .gmail || gmailStarsAreFollowUp else { return nil }

        let completionKey = String(completedAt.timeIntervalSinceReferenceDate.bitPattern, radix: 16)
        return SourceWriteIntent(
            id: stableID("Priorities.clearEmailFlag.v1:\(task.id.uuidString):\(source.sourceKey):\(completionKey)"),
            taskID: task.id,
            source: source,
            operation: source.provider == .outlook ? .clearOutlookFollowUpFlag : .removeGmailStar,
            state: .pending,
            createdAt: now,
            taskCompletedAt: completedAt
        )
    }

    public static func isStillApplicable(_ intent: SourceWriteIntent, to task: TaskItem) -> Bool {
        task.id == intent.taskID
            && task.completedAt == intent.taskCompletedAt
            && task.sourceReference?.sourceKey == intent.source.sourceKey
            && (task.state == .active || (task.state == .archived && task.archiveReason == .completed))
    }

    private static func stableID(_ value: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data(value.utf8)).prefix(16))
        // UUID version 8 permits this application-defined deterministic SHA-256 mapping.
        bytes[6] = (bytes[6] & 0x0f) | 0x80
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
