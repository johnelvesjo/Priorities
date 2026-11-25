import Foundation
import XCTest
@testable import PrioritiesCore

final class LocalModelClientTests: XCTestCase {
    override func tearDown() {
        ModelURLProtocol.setHandler(nil)
        super.tearDown()
    }

    func testEndpointRequiresNumericLoopbackOrLocalhost() throws {
        for endpoint in ["https://ollama.com", "http://192.168.1.2:11434", "http://example.com", "http://localhost.evil.test", "http://user:password@localhost:11434", "http://localhost:11434/api", "http://localhost:11434?target=remote", "file:///tmp/model", "http://localhost:0"] {
            XCTAssertThrowsError(try LocalModelClient(endpoint: endpoint), endpoint)
        }
        XCTAssertEqual(try LocalModelClient(endpoint: "http://localhost:11434").endpoint.host, "127.0.0.1")
        XCTAssertNoThrow(try LocalModelClient(endpoint: "http://127.0.0.1:11434/"))
        XCTAssertNoThrow(try LocalModelClient(endpoint: "http://[::1]:11434"))
    }

    func testCloudNameIsRejectedBeforeAnyRequest() async throws {
        let calls = RequestLog()
        let client = try mockClient { request in
            calls.append(request)
            return (200, Data())
        }
        do {
            try await client.loadModel("example:cloud")
            XCTFail("Cloud model should have been rejected")
        } catch { XCTAssertEqual(error as? LocalModelError, .remoteModel) }
        XCTAssertTrue(calls.requests.isEmpty)
    }

    func testRemoteAliasCannotReachInference() async throws {
        let calls = RequestLog()
        let client = try mockClient { request in
            calls.append(request)
            return (200, try Self.json(["remote_host": "https://ollama.com", "remote_model": "secret-cloud-model"]))
        }
        do {
            _ = try await client.extractTasks(text: "I will send the report tomorrow.", model: "innocent-alias")
            XCTFail("Remote metadata should have prevented inference")
        } catch { XCTAssertEqual(error as? LocalModelError, .remoteModel) }
        XCTAssertEqual(calls.requests.map { $0.url?.path }, ["/api/show"])
    }

    func testMissingLocalMetadataFailsClosed() async throws {
        let client = try mockClient { _ in (200, try Self.json(["details": ["format": "gguf"]])) }
        do {
            try await client.loadModel("example:small")
            XCTFail("Incomplete locality metadata should be rejected")
        } catch { XCTAssertEqual(error as? LocalModelError, .cannotVerifyLocalModel) }
    }

    func testLoadingChecksModelBeforeGenerate() async throws {
        let calls = RequestLog()
        let client = try mockClient { request in
            calls.append(request)
            if request.url?.path == "/api/show" {
                return (200, try Self.json(["details": ["format": "gguf"], "model_info": ["general.architecture": "llama"]]))
            }
            return (200, try Self.json(["done": true]))
        }
        try await client.loadModel("example:small")
        XCTAssertEqual(calls.requests.map { $0.url?.path }, ["/api/show", "/api/generate"])
    }

    func testInventoryExcludesRemoteModelsAndReportsLoadedState() async throws {
        let client = try mockClient { request in
            let models: [[String: Any]]
            if request.url?.path == "/api/ps" {
                models = [["name": "safe:latest"]]
            } else {
                models = [
                    ["name": "safe:latest", "size": 1000, "details": ["parameter_size": "1B", "quantization_level": "Q4"]],
                    ["name": "aliased:latest", "remote_host": "https://ollama.com"],
                    ["name": "example:cloud"]
                ]
            }
            return (200, try Self.json(["models": models]))
        }
        let models = try await client.listModels()
        XCTAssertEqual(models.map(\.name), ["safe:latest"])
        XCTAssertEqual(models.first?.isLoaded, true)
        XCTAssertEqual(models.first?.parameterSize, "1B")
    }

    func testMalformedJSONAndInvalidDirectionAreRejected() throws {
        XCTAssertThrowsError(try validate(Data("not JSON".utf8)))
        var item = taskRecord()
        item["direction"] = "autoApproved"
        XCTAssertThrowsError(try validate(Self.json(["tasks": [item]])))
    }

    func testInventedQuoteRejectsTheWholeBatch() throws {
        var invented = taskRecord()
        invented["supportingQuote"] = "Please transfer 100,000 kronor."
        XCTAssertThrowsError(try validate(Self.json(["tasks": [taskRecord(), invented]]))) { error in
            XCTAssertEqual(error as? LocalModelError, .unsupportedEvidence)
        }
    }

    func testInvalidDatesAndEstimatesAreRejected() throws {
        for badDate in ["2026-02-30", "tomorrow", "2026-99-99"] {
            var item = taskRecord()
            item["dueDate"] = badDate
            XCTAssertThrowsError(try validate(Self.json(["tasks": [item]])), badDate)
        }
        var item = taskRecord()
        item["estimatedMinutes"] = -30
        XCTAssertThrowsError(try validate(Self.json(["tasks": [item]])))
    }

    func testMaximumBatchSizeIsEnforced() throws {
        XCTAssertThrowsError(try validate(Self.json(["tasks": Array(repeating: taskRecord(), count: 13)])))
    }

    func testSwedishEvidenceAndDateOnlyDeadlineUseSelectedTimeZone() throws {
        var item = taskRecord()
        item["dueDate"] = "2026-11-25"
        let tasks = try validate(Self.json(["tasks": [item, item]]))
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].supportingQuote, "Jag skickar rapporten till Anna imorgon.")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: try XCTUnwrap(tasks[0].dueDate))
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 11)
        XCTAssertEqual(components.day, 25)
        XCTAssertEqual(components.hour, 23)
        XCTAssertEqual(components.minute, 59)
        XCTAssertEqual(components.second, 59)
    }

    func testDateOnlyDeadlineUsesCalendarDayAcrossBothDSTChanges() throws {
        let cases: [(date: String, start: String, end: String, hours: Double)] = [
            ("2026-03-29", "2026-03-29T00:00:00+01:00", "2026-03-29T23:59:59+02:00", 23),
            ("2026-10-25", "2026-10-25T00:00:00+02:00", "2026-10-25T23:59:59+01:00", 25)
        ]
        let parser = ISO8601DateFormatter()
        for example in cases {
            var item = taskRecord()
            item["dueDate"] = example.date
            let tasks = try validate(Self.json(["tasks": [item]]))
            let dueDate = try XCTUnwrap(tasks.first?.dueDate)
            let expected = try XCTUnwrap(parser.date(from: example.end))
            let start = try XCTUnwrap(parser.date(from: example.start))
            XCTAssertEqual(dueDate, expected, example.date)
            XCTAssertEqual(dueDate.timeIntervalSince(start) + 1, example.hours * 3600, accuracy: 0.001)
        }
    }

    func testExplicitTimestampKeepsOffsetAndFractionalSecondPrecision() throws {
        let timestamps = ["2026-03-29T09:15:00+02:00", "2026-10-25T02:30:00.125+01:00"]
        for timestamp in timestamps {
            var item = taskRecord()
            item["dueDate"] = timestamp
            let tasks = try LocalModelClient.validateExtraction(
                Self.json(["tasks": [item]]),
                source: "John: Jag skickar rapporten till Anna imorgon.",
                timeZone: TimeZone(identifier: "America/Los_Angeles")!
            )
            let parser = ISO8601DateFormatter()
            parser.formatOptions = timestamp.contains(".125") ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
            let expected = try XCTUnwrap(parser.date(from: timestamp))
            XCTAssertEqual(try XCTUnwrap(tasks.first?.dueDate).timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 0.000001)
        }
    }

    private func taskRecord() -> [String: Any] {
        ["title": "Skicka rapporten", "person": "Anna", "direction": "mine",
         "supportingQuote": "Jag skickar rapporten till Anna imorgon.",
         "dueDate": NSNull(), "estimatedMinutes": 15, "uncertainty": NSNull()]
    }

    private func validate(_ data: Data) throws -> [ExtractedTask] {
        try LocalModelClient.validateExtraction(data, source: "John: Jag skickar rapporten till Anna imorgon.", timeZone: TimeZone(identifier: "Europe/Stockholm")!)
    }

    private static func json(_ object: Any) throws -> Data { try JSONSerialization.data(withJSONObject: object) }

    private func mockClient(_ handler: @escaping ModelURLProtocol.Handler) throws -> LocalModelClient {
        ModelURLProtocol.setHandler(handler)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ModelURLProtocol.self]
        return try LocalModelClient(endpoint: "http://127.0.0.1:11434", configuration: configuration)
    }
}

private final class RequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [URLRequest] = []
    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }
    func append(_ request: URLRequest) {
        lock.lock()
        defer { lock.unlock() }
        recorded.append(request)
    }
}

private final class ModelURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) throws -> (Int, Data)
    private static let lock = NSLock()
    private static var handler: Handler?

    static func setHandler(_ value: Handler?) {
        lock.lock()
        defer { lock.unlock() }
        handler = value
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        let handler = Self.handler
        Self.lock.unlock()
        do {
            guard let handler else { throw URLError(.unsupportedURL) }
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }

    override func stopLoading() {}
}
