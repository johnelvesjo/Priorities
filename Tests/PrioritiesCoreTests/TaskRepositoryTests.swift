import Foundation
import XCTest
@testable import PrioritiesCore

final class TaskRepositoryTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var repository: TaskRepository!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrioritiesCoreTests-\(UUID().uuidString)", isDirectory: true)
        repository = TaskRepository(directory: temporaryDirectory)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: temporaryDirectory.path) {
            try FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testMissingStorageLoadsEmptyWithoutCreatingFiles() throws {
        XCTAssertEqual(try repository.load(), [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: temporaryDirectory.path))
    }

    func testRoundTripPreservesFullTaskAndFractionalDatesAcrossSaves() throws {
        let date = Date(timeIntervalSinceReferenceDate: 800_000_000.1234567)
        var task = TaskItem(
            title: "Prepare a synthetic example",
            dueDate: date.addingTimeInterval(90_000),
            person: "Example Person",
            notes: "Synthetic test data only.",
            estimatedMinutes: 30,
            direction: .owedToMe,
            state: .suggested,
            origin: .imported,
            sourceText: "Please send the example.",
            sourceURL: "https://example.com/thread/1",
            createdAt: date,
            promisedDueDate: date.addingTimeInterval(86_400)
        )
        TaskEngine.markReviewed(&task, sessionID: UUID(), now: date)
        TaskEngine.archive(&task, reason: .dismissed, now: date)
        TaskEngine.restore(&task, now: date.addingTimeInterval(1))

        try repository.save([task])
        XCTAssertEqual(try repository.load(), [task])

        TaskEngine.approve(&task, now: date.addingTimeInterval(2))
        try repository.save([task])
        XCTAssertEqual(try repository.load(), [task])
    }

    func testCorruptFileCannotBeSilentlyReplaced() throws {
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        let original = Data("{broken json".utf8)
        try original.write(to: repository.fileURL)

        XCTAssertThrowsError(try repository.load())
        XCTAssertThrowsError(try repository.save([]))
        XCTAssertEqual(try Data(contentsOf: repository.fileURL), original)
    }

    func testUnknownFormatCannotBeSilentlyReplaced() throws {
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        let original = Data("{\"formatVersion\":99,\"tasks\":[]}".utf8)
        try original.write(to: repository.fileURL)

        XCTAssertThrowsError(try repository.load()) { error in
            XCTAssertEqual(error as? TaskRepositoryError, .unsupportedFormatVersion(99))
        }
        XCTAssertThrowsError(try repository.save([]))
        XCTAssertEqual(try Data(contentsOf: repository.fileURL), original)
    }

    func testCorruptionAfterSuccessfulLoadStillBlocksLaterUserSave() throws {
        let task = TaskItem(title: "Preserve this task", dueDate: Date())
        try repository.save([task])
        var loaded = try repository.load()
        let damaged = Data("truncated storage".utf8)
        try damaged.write(to: repository.fileURL)
        loaded[0].notes = "A later user edit."

        XCTAssertThrowsError(try repository.save(loaded))
        XCTAssertEqual(try Data(contentsOf: repository.fileURL), damaged)
    }

    func testPersistingSecondReviewDoesNotArchiveBeforeSessionEnds() throws {
        let date = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let firstSession = UUID()
        let secondSession = UUID()
        var task = TaskItem(title: "Review this suggestion", dueDate: date, state: .suggested, createdAt: date)
        TaskEngine.markReviewed(&task, sessionID: firstSession, now: date)
        TaskEngine.markReviewed(&task, sessionID: secondSession, now: date)
        try repository.save([task])
        var tasks = try repository.load()

        TaskEngine.maintenance(&tasks, now: date)
        XCTAssertEqual(tasks[0].state, .suggested)
        XCTAssertEqual(tasks[0].reviewSessionIDs, [firstSession, secondSession])
        TaskEngine.maintenance(&tasks, now: date, endingReviewSessionID: secondSession)
        try repository.save(tasks)
        let archived = try repository.load()[0]
        XCTAssertEqual(archived.state, .archived)
        XCTAssertEqual(archived.archiveReason, .reviewedTwice)
        XCTAssertEqual(archived.createdAt, date)
    }

    func testInvalidReplacementLeavesExistingTasksUnchanged() throws {
        let task = TaskItem(title: "Keep this task", dueDate: Date())
        try repository.save([task])
        let original = try Data(contentsOf: repository.fileURL)

        XCTAssertThrowsError(try repository.save([task, task]))
        XCTAssertEqual(try Data(contentsOf: repository.fileURL), original)
        XCTAssertEqual(try repository.load(), [task])
    }

    func testInvalidDatesDoNotCreateStorage() throws {
        let task = TaskItem(title: "Invalid deadline", dueDate: Date(timeIntervalSinceReferenceDate: .infinity))

        XCTAssertThrowsError(try repository.save([task]))
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.fileURL.path))
    }
}
