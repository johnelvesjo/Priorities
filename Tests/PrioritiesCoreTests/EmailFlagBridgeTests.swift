import Foundation
import XCTest
@testable import PrioritiesCore

final class EmailFlagBridgeTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func testFlagCreatesActiveTaskWithoutAIApproval() {
        let due = now.addingTimeInterval(86_400)
        var tasks: [TaskItem] = []
        let result = EmailFlagBridge.upsert(email(flaggedDueDate: due), tasks: &tasks, now: now, proposedDueDate: now)

        XCTAssertEqual(result, .created(tasks[0].id))
        XCTAssertEqual(tasks[0].state, .active)
        XCTAssertEqual(tasks[0].origin, .emailFlag)
        XCTAssertEqual(tasks[0].dueDate, due)
        XCTAssertEqual(tasks[0].createdAt, now)
        XCTAssertNil(tasks[0].promisedDueDate)
        XCTAssertEqual(tasks[0].person, "Example Sender")
    }

    func testMissingFlagDueDateUsesProposedDate() {
        let proposed = now.addingTimeInterval(7_200)
        var tasks: [TaskItem] = []
        EmailFlagBridge.upsert(email(), tasks: &tasks, now: now, proposedDueDate: proposed)
        XCTAssertEqual(tasks[0].dueDate, proposed)
    }

    func testReplayIsIdempotentAndSourceIdentityProducesStableTaskID() {
        var first: [TaskItem] = []
        var second: [TaskItem] = []
        let source = email()
        EmailFlagBridge.upsert(source, tasks: &first, now: now, proposedDueDate: now)
        let original = first[0]
        let replay = EmailFlagBridge.upsert(source, tasks: &first, now: now.addingTimeInterval(30), proposedDueDate: now)
        EmailFlagBridge.upsert(source, tasks: &second, now: now, proposedDueDate: now)

        XCTAssertEqual(replay, .unchanged(original.id))
        XCTAssertEqual(first, [original])
        XCTAssertEqual(second[0].id, original.id)
    }

    func testUpdatedEvidencePreservesUserEditsAndSnoozedDate() {
        var tasks: [TaskItem] = []
        EmailFlagBridge.upsert(email(), tasks: &tasks, now: now, proposedDueDate: now)
        tasks[0].title = "My edited action"
        tasks[0].person = "My edited person"
        tasks[0].notes = "My notes"
        let snoozed = now.addingTimeInterval(3 * 86_400)
        TaskEngine.snooze(&tasks[0], until: snoozed, now: now)
        let changed = email(evidence: "Updated source evidence", flaggedDueDate: now.addingTimeInterval(60))

        EmailFlagBridge.upsert(changed, tasks: &tasks, now: now.addingTimeInterval(120), proposedDueDate: now)

        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].dueDate, snoozed)
        XCTAssertEqual(tasks[0].title, "My edited action")
        XCTAssertEqual(tasks[0].person, "My edited person")
        XCTAssertEqual(tasks[0].notes, "My notes")
        XCTAssertEqual(tasks[0].createdAt, now)
        XCTAssertEqual(tasks[0].sourceText, "Updated source evidence")
    }

    func testSameMessageIDInDifferentAccountsOrProvidersRemainsDistinct() {
        var tasks: [TaskItem] = []
        EmailFlagBridge.upsert(email(accountID: "first"), tasks: &tasks, now: now, proposedDueDate: now)
        EmailFlagBridge.upsert(email(accountID: "second"), tasks: &tasks, now: now, proposedDueDate: now)
        EmailFlagBridge.upsert(email(provider: .gmail, accountID: "first"), tasks: &tasks, now: now, proposedDueDate: now, gmailStarsAreFollowUp: true)
        XCTAssertEqual(tasks.count, 3)
        XCTAssertEqual(Set(tasks.map(\.id)).count, 3)
    }

    func testSourceIdentityIsCaseSensitiveAndIgnoresChangingURLs() {
        let first = SourceReference(provider: .outlook, accountID: "account", messageID: "Message", sourceURL: "https://example.com/old")
        let moved = SourceReference(provider: .outlook, accountID: "account", messageID: "Message", sourceURL: "https://example.com/new")
        let different = SourceReference(provider: .outlook, accountID: "account", messageID: "message")
        XCTAssertEqual(first.sourceKey, moved.sourceKey)
        XCTAssertNotEqual(first.sourceKey, different.sourceKey)
    }

    func testReplayNeverReopensCompletedOrArchivedTask() {
        var tasks: [TaskItem] = []
        EmailFlagBridge.upsert(email(), tasks: &tasks, now: now, proposedDueDate: now)
        TaskEngine.complete(&tasks[0], now: now)
        EmailFlagBridge.upsert(email(evidence: "New evidence"), tasks: &tasks, now: now, proposedDueDate: now)
        XCTAssertEqual(tasks[0].completedAt, now)
        TaskEngine.maintenance(&tasks, now: now.addingTimeInterval(60))
        EmailFlagBridge.upsert(email(), tasks: &tasks, now: now.addingTimeInterval(120), proposedDueDate: now)
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].state, .archived)
        XCTAssertEqual(tasks[0].archiveReason, .completed)
    }

    func testExplicitFlagApprovesExistingLinkedSuggestionWithoutChangingDueDate() {
        let incoming = email(flaggedDueDate: now)
        let editedDue = now.addingTimeInterval(86_400)
        var tasks = [TaskItem(title: "Existing interpretation", dueDate: editedDue, state: .suggested, sourceReference: incoming.source, createdAt: now)]

        EmailFlagBridge.upsert(incoming, tasks: &tasks, now: now, proposedDueDate: now)

        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].state, .active)
        XCTAssertEqual(tasks[0].dueDate, editedDue)
    }

    func testUnflaggedInputDoesNotCreateOrCompleteTasks() {
        var tasks: [TaskItem] = []
        XCTAssertNil(EmailFlagBridge.upsert(email(isFlagged: false), tasks: &tasks, now: now, proposedDueDate: now))
        EmailFlagBridge.upsert(email(), tasks: &tasks, now: now, proposedDueDate: now)
        let original = tasks
        XCTAssertNil(EmailFlagBridge.upsert(email(isFlagged: false), tasks: &tasks, now: now, proposedDueDate: now))
        XCTAssertEqual(tasks, original)
    }

    func testGmailStarsRequireExplicitMapping() {
        var tasks: [TaskItem] = []
        XCTAssertNil(EmailFlagBridge.upsert(email(provider: .gmail), tasks: &tasks, now: now, proposedDueDate: now))
        XCTAssertTrue(tasks.isEmpty)
        EmailFlagBridge.upsert(email(provider: .gmail), tasks: &tasks, now: now, proposedDueDate: now, gmailStarsAreFollowUp: true)
        XCTAssertEqual(tasks.count, 1)
    }

    func testOutlookCompletionCreatesPendingClearFlagIntentOnlyWhenSupported() throws {
        var tasks: [TaskItem] = []
        EmailFlagBridge.upsert(email(), tasks: &tasks, now: now, proposedDueDate: now)
        XCTAssertNil(EmailFlagBridge.clearFlagIntent(for: tasks[0], supportsFlagClearing: true, now: now))
        TaskEngine.complete(&tasks[0], now: now)
        XCTAssertNil(EmailFlagBridge.clearFlagIntent(for: tasks[0], supportsFlagClearing: false, now: now))

        let intent = try XCTUnwrap(EmailFlagBridge.clearFlagIntent(for: tasks[0], supportsFlagClearing: true, now: now))
        XCTAssertEqual(intent.state, .pending)
        XCTAssertEqual(intent.operation, .clearOutlookFollowUpFlag)
        XCTAssertEqual(intent.outlookFlagStatus, "notFlagged")
        XCTAssertTrue(intent.gmailLabelIDsToRemove.isEmpty)
        XCTAssertEqual(intent.source.accountID, "account")
    }

    func testGmailCompletionUsesStarRemovalWithExplicitMapping() throws {
        var tasks: [TaskItem] = []
        EmailFlagBridge.upsert(email(provider: .gmail), tasks: &tasks, now: now, proposedDueDate: now, gmailStarsAreFollowUp: true)
        TaskEngine.complete(&tasks[0], now: now)
        XCTAssertNil(EmailFlagBridge.clearFlagIntent(for: tasks[0], supportsFlagClearing: true, now: now))
        let intent = try XCTUnwrap(EmailFlagBridge.clearFlagIntent(for: tasks[0], supportsFlagClearing: true, now: now, gmailStarsAreFollowUp: true))
        XCTAssertEqual(intent.operation, .removeGmailStar)
        XCTAssertEqual(intent.gmailLabelIDsToRemove, ["STARRED"])
        XCTAssertNil(intent.outlookFlagStatus)
    }

    func testClearIntentIsIdempotentAndInvalidatedByUndo() throws {
        var tasks: [TaskItem] = []
        EmailFlagBridge.upsert(email(), tasks: &tasks, now: now, proposedDueDate: now)
        TaskEngine.complete(&tasks[0], now: now)
        let first = try XCTUnwrap(EmailFlagBridge.clearFlagIntent(for: tasks[0], supportsFlagClearing: true, now: now))
        let retry = try XCTUnwrap(EmailFlagBridge.clearFlagIntent(for: tasks[0], supportsFlagClearing: true, now: now.addingTimeInterval(10)))
        XCTAssertEqual(first.id, retry.id)
        XCTAssertTrue(EmailFlagBridge.isStillApplicable(first, to: tasks[0]))
        TaskEngine.undoCompletion(&tasks[0], now: now.addingTimeInterval(20))
        XCTAssertFalse(EmailFlagBridge.isStillApplicable(first, to: tasks[0]))
        TaskEngine.complete(&tasks[0], now: now.addingTimeInterval(30))
        let later = try XCTUnwrap(EmailFlagBridge.clearFlagIntent(for: tasks[0], supportsFlagClearing: true, now: now))
        XCTAssertNotEqual(first.id, later.id)
    }

    private func email(
        provider: EmailProvider = .outlook,
        accountID: String = "account",
        evidence: String = "Please send the example.",
        flaggedDueDate: Date? = nil,
        isFlagged: Bool = true
    ) -> FlaggedEmail {
        FlaggedEmail(
            source: SourceReference(provider: provider, accountID: accountID, messageID: "message", sourceURL: "https://example.com/mail"),
            sender: "Example Sender",
            subject: "Requested example",
            evidence: evidence,
            date: now.addingTimeInterval(-86_400),
            flaggedDueDate: flaggedDueDate,
            isFlagged: isFlagged
        )
    }
}
