import Foundation

public enum TaskEngine {
    public static let completionDisplayDuration: TimeInterval = 60
    public static let suggestionLifetime: TimeInterval = 7 * 24 * 60 * 60

    public static func approve(_ task: inout TaskItem, now: Date = Date()) {
        guard task.state == .suggested else { return }
        task.state = .active
        task.completedAt = nil
        task.archivedAt = nil
        task.archiveReason = nil
        task.archivedFromState = nil
        record("Approved suggestion.", in: &task, now: now)
    }

    public static func snooze(_ task: inout TaskItem, until date: Date, now: Date = Date()) {
        guard task.state != .archived, !task.isCompleted, date > task.dueDate else { return }
        let previousDate = task.dueDate
        task.dueDate = date
        record(
            "Changed due date from \(dateDescription(previousDate)) to \(dateDescription(date)).",
            in: &task,
            now: now
        )
    }

    public static func complete(_ task: inout TaskItem, now: Date = Date()) {
        guard task.state == .active, !task.isCompleted else { return }
        task.completedAt = now
        record("Marked done.", in: &task, now: now)
    }

    public static func undoCompletion(_ task: inout TaskItem, now: Date = Date()) {
        guard task.isCompleted else { return }
        guard task.state == .active || (task.state == .archived && task.archiveReason == .completed) else {
            return
        }
        task.state = .active
        task.completedAt = nil
        task.archivedAt = nil
        task.archiveReason = nil
        task.archivedFromState = nil
        record("Reopened completed task.", in: &task, now: now)
    }

    public static func archive(_ task: inout TaskItem, reason: ArchiveReason, now: Date = Date()) {
        guard task.state != .archived else { return }
        task.archivedFromState = task.state
        task.state = .archived
        task.archivedAt = now
        task.archiveReason = reason
        if reason == .completed {
            task.completedAt = task.completedAt ?? now
        } else {
            task.completedAt = nil
        }
        record(archiveDescription(reason), in: &task, now: now)
    }

    public static func restore(_ task: inout TaskItem, now: Date = Date()) {
        guard task.state == .archived else { return }
        let previousState = task.archivedFromState ?? restoredState(for: task.archiveReason)
        task.state = previousState == .suggested ? .suggested : .active
        task.completedAt = nil
        task.archivedAt = nil
        task.archiveReason = nil
        task.archivedFromState = nil
        if task.state == .suggested {
            task.reviewSessionIDs = []
            task.suggestionCycleStartedAt = now
        }
        record("Restored from archive.", in: &task, now: now)
    }

    public static func markReviewed(_ task: inout TaskItem, sessionID: UUID, now: Date = Date()) {
        guard task.state == .suggested, !task.reviewSessionIDs.contains(sessionID) else { return }
        task.reviewSessionIDs.append(sessionID)
        record("Reviewed suggestion.", in: &task, now: now)
    }

    public static func maintenance(
        _ tasks: inout [TaskItem],
        now: Date = Date(),
        endingReviewSessionID: UUID? = nil
    ) {
        for index in tasks.indices {
            if tasks[index].state == .active,
               let completedAt = tasks[index].completedAt,
               now.timeIntervalSince(completedAt) >= completionDisplayDuration {
                archive(&tasks[index], reason: .completed, now: now)
                continue
            }

            guard tasks[index].state == .suggested else { continue }
            if now.timeIntervalSince(tasks[index].suggestionAgeReferenceDate) > suggestionLifetime {
                archive(&tasks[index], reason: .expired, now: now)
            } else if let sessionID = endingReviewSessionID,
                      tasks[index].reviewSessionIDs.contains(sessionID),
                      Set(tasks[index].reviewSessionIDs).count >= 2 {
                archive(&tasks[index], reason: .reviewedTwice, now: now)
            }
        }
    }

    public static func sorted(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted { left, right in
            if left.dueDate != right.dueDate { return left.dueDate < right.dueDate }
            if left.createdAt != right.createdAt { return left.createdAt < right.createdAt }
            return left.id.uuidString < right.id.uuidString
        }
    }

    private static func record(_ description: String, in task: inout TaskItem, now: Date) {
        task.history.append(TaskChange(date: now, description: description))
    }

    private static func dateDescription(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func archiveDescription(_ reason: ArchiveReason) -> String {
        switch reason {
        case .completed: return "Archived completed task."
        case .removed: return "Removed task."
        case .dismissed: return "Dismissed suggestion."
        case .reviewedTwice: return "Archived after two review sessions."
        case .expired: return "Archived suggestion older than seven days."
        }
    }

    private static func restoredState(for reason: ArchiveReason?) -> TaskState {
        switch reason {
        case .dismissed, .reviewedTwice, .expired: return .suggested
        case .completed, .removed, nil: return .active
        }
    }
}
