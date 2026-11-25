import Foundation
import XCTest
@testable import PrioritiesCore

final class LocalDocumentStoreTests: XCTestCase {
    private var directory: URL!
    private var store: LocalDocumentStore<Snapshot>!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalDocumentStoreTests-\(UUID().uuidString)", isDirectory: true)
        store = LocalDocumentStore(directory: directory)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func testMissingDocumentReturnsNilWithoutCreatingStorage() throws {
        XCTAssertNil(try store.load())
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testWholeSnapshotRoundTripsAndReplacesPreviousSnapshot() throws {
        let first = Snapshot(tasks: ["First task"], jobs: [UUID()], voiceDrafts: ["First draft"], enabled: false)
        let second = Snapshot(tasks: ["Second task"], jobs: [], voiceDrafts: [], enabled: true)

        try store.save(first)
        XCTAssertEqual(try store.load(), first)
        try store.save(second)
        XCTAssertEqual(try store.load(), second)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["workspace.json"])
    }

    func testCorruptDocumentBlocksLoadAndSubsequentSave() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let original = Data("{truncated workspace".utf8)
        try original.write(to: store.fileURL)

        XCTAssertThrowsError(try store.load())
        XCTAssertThrowsError(try store.save(emptySnapshot))
        XCTAssertEqual(try Data(contentsOf: store.fileURL), original)
    }

    func testNewerSchemaIsReportedAndNeverReplaced() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let original = Data("{\"schemaVersion\":2,\"document\":{}}".utf8)
        try original.write(to: store.fileURL)

        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? LocalDocumentStoreError, .unsupportedSchemaVersion(2))
        }
        XCTAssertThrowsError(try store.save(emptySnapshot))
        XCTAssertEqual(try Data(contentsOf: store.fileURL), original)
    }

    func testInvalidPayloadWithValidHeaderCannotBeOverwritten() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let original = Data("{\"schemaVersion\":1,\"document\":{\"tasks\":123}}".utf8)
        try original.write(to: store.fileURL)

        XCTAssertThrowsError(try store.load())
        XCTAssertThrowsError(try store.save(emptySnapshot))
        XCTAssertEqual(try Data(contentsOf: store.fileURL), original)
    }

    func testEncodingFailurePreservesLastGoodDocument() throws {
        let numberStore = LocalDocumentStore<Double>(directory: directory, fileName: "number.json")
        try numberStore.save(42)
        let original = try Data(contentsOf: numberStore.fileURL)

        XCTAssertThrowsError(try numberStore.save(.infinity))
        XCTAssertEqual(try Data(contentsOf: numberStore.fileURL), original)
        XCTAssertEqual(try numberStore.load(), 42)
    }

    func testSavedFileAndDirectoryHavePrivatePermissions() throws {
        try store.save(emptySnapshot)
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: store.fileURL.path)
        let directoryAttributes = try FileManager.default.attributesOfItem(atPath: directory.path)

        XCTAssertEqual((fileAttributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        XCTAssertEqual((directoryAttributes[.posixPermissions] as? NSNumber)?.intValue, 0o700)
    }

    private var emptySnapshot: Snapshot {
        Snapshot(tasks: [], jobs: [], voiceDrafts: [], enabled: false)
    }
}

private struct Snapshot: Codable, Equatable {
    let tasks: [String]
    let jobs: [UUID]
    let voiceDrafts: [String]
    let enabled: Bool
}
