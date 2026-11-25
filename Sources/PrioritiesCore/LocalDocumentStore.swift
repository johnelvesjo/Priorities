import Darwin
import Foundation

public enum LocalDocumentStoreError: Error, LocalizedError, Equatable {
    case unreadableData(String)
    case unsupportedSchemaVersion(Int)

    public var errorDescription: String? {
        switch self {
        case .unreadableData(let detail):
            return "Saved workspace data could not be read. The existing file has been left unchanged. \(detail)"
        case .unsupportedSchemaVersion(let version):
            return "The saved workspace uses schema version \(version), which this app does not support. The file has been left unchanged."
        }
    }
}

public struct LocalDocumentStore<Document: Codable>: Sendable {
    public let fileURL: URL

    public init(directory: URL, fileName: String = "workspace.json") {
        fileURL = directory.appendingPathComponent(fileName, isDirectory: false)
    }

    public func load() throws -> Document? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let header = try decoder.decode(LocalDocumentHeader.self, from: data)
            guard header.schemaVersion == 1 else {
                throw LocalDocumentStoreError.unsupportedSchemaVersion(header.schemaVersion)
            }
            return try decoder.decode(LocalDocumentEnvelope<Document>.self, from: data).document
        } catch let error as LocalDocumentStoreError {
            throw error
        } catch {
            throw LocalDocumentStoreError.unreadableData(error.localizedDescription)
        }
    }

    public func save(_ document: Document) throws {
        // A failed load must never be followed by silently replacing the saved workspace.
        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try load()
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(LocalDocumentEnvelope(schemaVersion: 1, document: document))
        let directory = fileURL.deletingLastPathComponent()
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)

        let temporaryURL = directory.appendingPathComponent(".workspace-\(UUID().uuidString).tmp")
        defer { try? fileManager.removeItem(at: temporaryURL) }
        try data.write(to: temporaryURL, options: .withoutOverwriting)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporaryURL.path)

        // Rename within the same directory atomically replaces the complete document.
        let result = temporaryURL.path.withCString { source in
            fileURL.path.withCString { destination in
                Darwin.rename(source, destination)
            }
        }
        if result != 0 {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
    }
}

private struct LocalDocumentHeader: Decodable {
    let schemaVersion: Int
}

private struct LocalDocumentEnvelope<Document: Codable>: Codable {
    let schemaVersion: Int
    let document: Document
}
