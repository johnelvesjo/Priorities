import Foundation
import XCTest
@testable import PrioritiesCore

final class TaskEngineTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func testSnoozePreservesCreationPromiseAndDirection() {
        let created = now.addingTimeInterval(-10_000)
        let promise = now.addingTimeInterval(-1_000)
        var task = TaskItem(
            title: "Receive the revised proposal",
            dueDate: promise,
            direction: .owedToMe,
            createdAt: created,
            promisedDueDate: promise
        )
        let tomorrow = now.addingTimeInterval(86_400)

        TaskEngine.snooze(&task, until: tomorrow, now: now)

        XCTAssertEqual(task.dueDate, tomorrow)
        XCTAssertEqual(task.createdAt, created)
        XCTAssertEqual(task.promisedDueDate, promise)
        XCTAssertEqual(task.direction, .owedToMe)
        XCTAssertEqual(task.history.count, 1)
        XCTAssertFalse(task.isOverdue(at: now))
    }

    func testSnoozeCannotBringFutureDeadlineForwardOrRepeatIt() {
        let due = now.addingTimeInterval(7 * 86_400)
        for direction in TaskDirection.allCases {
            for state in [TaskState.active, .suggested] {
                let original = TaskItem(
                    title: "Review the proposal next week",
                    dueDate: due,
                    direction: direction,
                    state: state,
                    createdAt: now,
                    promisedDueDate: due
                )
                for invalidDate in [now.addingTimeInterval(7200), due.addingTimeInterval(-1), due] {
                    var task = original
                    TaskEngine.snooze(&task, until: invalidDate, now: now)
                    XCTAssertEqual(task, original, "An invalid snooze must preserve the entire task and history.")
                }
            }
        }
    }

    func testSnoozeExtendsFutureDeadlineWithoutChangingItsPromise() {
        let due = now.addingTimeInterval(7 * 86_400)
        var task = TaskItem(title: "Send the final draft", dueDate: due, createdAt: now, promisedDueDate: due)
        let later = due.addingTimeInterval(60)

        TaskEngine.snooze(&task, until: later, now: now)

        XCTAssertEqual(task.dueDate, later)
        XCTAssertEqual(task.promisedDueDate, due)
        XCTAssertEqual(task.createdAt, now)
        XCTAssertEqual(task.state, .active)
        XCTAssertEqual(task.history.count, 1)
    }

    func testCompletionStopsOverdueImmediatelyAndArchivesAfterSixtySeconds() {
        var task = TaskItem(title: "Send the agenda", dueDate: now.addingTimeInterval(-60), createdAt: now)
        XCTAssertTrue(task.isOverdue(at: now))

        TaskEngine.complete(&task, now: now)
        TaskEngine.complete(&task, now: now.addingTimeInterval(20))
        XCTAssertEqual(task.completedAt, now)
        XCTAssertEqual(task.history.count, 1)
        XCTAssertEqual(task.state, .active)
        XCTAssertFalse(task.isOverdue(at: now))

        var tasks = [task]
        TaskEngine.maintenance(&tasks, now: now.addingTimeInterval(59.999))
        XCTAssertEqual(tasks[0].state, .active)
        TaskEngine.maintenance(&tasks, now: now.addingTimeInterval(60))
        XCTAssertEqual(tasks[0].state, .archived)
        XCTAssertEqual(tasks[0].archiveReason, .completed)
        XCTAssertEqual(tasks[0].completedAt, now)
        XCTAssertEqual(tasks[0].archivedAt, now.addingTimeInterval(60))
    }

    func testUndoCompletionPreventsScheduledArchival() {
        var task = TaskItem(title: "Check the draft", dueDate: now, createdAt: now)
        TaskEngine.complete(&task, now: now)
        TaskEngine.undoCompletion(&task, now: now.addingTimeInterval(30))
        var tasks = [task]

        TaskEngine.maintenance(&tasks, now: now.addingTimeInterval(120))

        XCTAssertEqual(tasks[0].state, .active)
        XCTAssertNil(tasks[0].completedAt)
        XCTAssertNil(tasks[0].archiveReason)
    }

    func testReviewCountsOncePerSessionAndArchivesOnlyWhenSecondSessionEnds() {
        let firstSession = UUID()
        let secondSession = UUID()
        var task = suggestion()
        TaskEngine.markReviewed(&task, sessionID: firstSession, now: now)
        let onceReviewed = task
        TaskEngine.markReviewed(&task, sessionID: firstSession, now: now)
        XCTAssertEqual(task.reviewSessionIDs, [firstSession])
        XCTAssertEqual(task, onceReviewed)

        var tasks = [task]
        TaskEngine.maintenance(&tasks, now: now, endingReviewSessionID: firstSession)
        XCTAssertEqual(tasks[0].state, .suggested)

        TaskEngine.markReviewed(&tasks[0], sessionID: secondSession, now: now)
        TaskEngine.maintenance(&tasks, now: now)
        TaskEngine.maintenance(&tasks, now: now, endingReviewSessionID: UUID())
        XCTAssertEqual(tasks[0].state, .suggested)

        TaskEngine.maintenance(&tasks, now: now, endingReviewSessionID: secondSession)
        XCTAssertEqual(tasks[0].state, .archived)
        XCTAssertEqual(tasks[0].archiveReason, .reviewedTwice)
    }

    func testApprovalWinsOverPendingReviewExpiry() {
        var task = suggestion()
        let session = UUID()
        TaskEngine.markReviewed(&task, sessionID: UUID(), now: now)
        TaskEngine.markReviewed(&task, sessionID: session, now: now)
        TaskEngine.approve(&task, now: now)
        var tasks = [task]

        TaskEngine.maintenance(&tasks, now: now.addingTimeInterval(8 * 86_400), endingReviewSessionID: session)

        XCTAssertEqual(tasks[0].state, .active)
        XCTAssertNil(tasks[0].archiveReason)
    }

    func testSuggestionExpiresOnlyAfterSevenDaysAndActiveTaskNeverExpires() {
        let oldCreation = now.addingTimeInterval(-TaskEngine.suggestionLifetime)
        let suggested = suggestion(createdAt: oldCreation)
        let active = TaskItem(title: "A long-running task", dueDate: oldCreation, createdAt: oldCreation)
        var tasks = [suggested, active]

        TaskEngine.maintenance(&tasks, now: now)
        XCTAssertEqual(tasks.map(\.state), [.suggested, .active])
        TaskEngine.maintenance(&tasks, now: now.addingTimeInterval(0.001))
        XCTAssertEqual(tasks.map(\.state), [.archived, .active])
        XCTAssertEqual(tasks[0].archiveReason, .expired)
    }

    func testRestoringExpiredSuggestionStartsNewReviewPeriodWithoutChangingCreation() {
        let originalCreation = now.addingTimeInterval(-30 * 86_400)
        var task = suggestion(createdAt: originalCreation)
        task.direction = .owedToMe
        let session = UUID()
        TaskEngine.markReviewed(&task, sessionID: session, now: now)
        TaskEngine.archive(&task, reason: .expired, now: now)
        TaskEngine.restore(&task, now: now)
        var tasks = [task]

        TaskEngine.maintenance(&tasks, now: now, endingReviewSessionID: session)

        XCTAssertEqual(tasks[0].state, .suggested)
        XCTAssertEqual(tasks[0].createdAt, originalCreation)
        XCTAssertEqual(tasks[0].direction, .owedToMe)
        XCTAssertEqual(tasks[0].suggestionAgeReferenceDate, now)
        XCTAssertTrue(tasks[0].reviewSessionIDs.isEmpty)
        XCTAssertNil(tasks[0].archivedAt)
        XCTAssertNil(tasks[0].archiveReason)

        TaskEngine.maintenance(&tasks, now: now.addingTimeInterval(TaskEngine.suggestionLifetime + 1))
        XCTAssertEqual(tasks[0].archiveReason, .expired)
    }

    func testRestoringRemovedTaskPreservesItsOriginalState() {
        var task = suggestion()
        TaskEngine.archive(&task, reason: .removed, now: now)
        TaskEngine.restore(&task, now: now)
        XCTAssertEqual(task.state, .suggested)

        TaskEngine.approve(&task, now: now)
        TaskEngine.archive(&task, reason: .removed, now: now)
        TaskEngine.restore(&task, now: now)
        XCTAssertEqual(task.state, .active)
    }

    func testRestoringCompletedTaskPreservesDueDateAndOriginalMetadata() {
        let due = now.addingTimeInterval(-86_400)
        let creation = now.addingTimeInterval(-2 * 86_400)
        var task = TaskItem(
            title: "Receive the final example",
            dueDate: due,
            direction: .owedToMe,
            createdAt: creation,
            promisedDueDate: due
        )
        TaskEngine.complete(&task, now: now)
        var tasks = [task]
        TaskEngine.maintenance(&tasks, now: now.addingTimeInterval(60))
        TaskEngine.restore(&tasks[0], now: now.addingTimeInterval(120))

        XCTAssertEqual(tasks[0].state, .active)
        XCTAssertNil(tasks[0].completedAt)
        XCTAssertNil(tasks[0].archivedAt)
        XCTAssertNil(tasks[0].archiveReason)
        XCTAssertEqual(tasks[0].dueDate, due)
        XCTAssertEqual(tasks[0].promisedDueDate, due)
        XCTAssertEqual(tasks[0].createdAt, creation)
        XCTAssertEqual(tasks[0].direction, .owedToMe)
        XCTAssertTrue(tasks[0].isOverdue(at: now))
    }

    func testArchivedTaskCannotBeChangedBySnoozeReviewOrApproval() {
        var task = suggestion()
        TaskEngine.archive(&task, reason: .dismissed, now: now)
        let archived = task

        TaskEngine.snooze(&task, until: now.addingTimeInterval(86_400), now: now)
        TaskEngine.markReviewed(&task, sessionID: UUID(), now: now)
        TaskEngine.approve(&task, now: now)
        TaskEngine.complete(&task, now: now)

        XCTAssertEqual(task, archived)
    }

    func testOrderingUsesDueDateThenCreationThenIdentifier() {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let first = TaskItem(id: firstID, title: "First", dueDate: now, createdAt: now)
        let second = TaskItem(id: secondID, title: "Second", dueDate: now, createdAt: now)
        let older = TaskItem(title: "Older", dueDate: now, createdAt: now.addingTimeInterval(-1))
        let overdue = TaskItem(title: "Overdue", dueDate: now.addingTimeInterval(-1), createdAt: now)
        let later = TaskItem(title: "Later", dueDate: now.addingTimeInterval(1), createdAt: now)

        XCTAssertEqual(TaskEngine.sorted([later, second, older, overdue, first]).map(\.id), [overdue.id, older.id, first.id, second.id, later.id])
    }

    func testDueBoundaryAndCompletedTaskOverdueStatus() {
        var task = TaskItem(title: "Exact deadline", dueDate: now, createdAt: now)
        XCTAssertFalse(task.isOverdue(at: now))
        XCTAssertTrue(task.isOverdue(at: now.addingTimeInterval(0.001)))
        TaskEngine.complete(&task, now: now)
        XCTAssertFalse(task.isOverdue(at: now.addingTimeInterval(1)))
    }

    private func suggestion(createdAt: Date? = nil) -> TaskItem {
        TaskItem(
            title: "Review the proposed agenda",
            dueDate: now.addingTimeInterval(86_400),
            state: .suggested,
            origin: .imported,
            createdAt: createdAt ?? now
        )
    }
}
