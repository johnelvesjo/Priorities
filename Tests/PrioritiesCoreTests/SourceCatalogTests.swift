import Foundation
import XCTest
@testable import PrioritiesCore

final class SourceCatalogTests: XCTestCase {
    func testCatalogHasUniqueStableIDsAndCoversEveryCategory() {
        let providers = SourceCatalog.providers
        XCTAssertEqual(providers.count, 60)
        XCTAssertEqual(Set(providers.map(\.id)).count, providers.count)
        XCTAssertEqual(Set(providers.map(\.category)), Set(SourceCategory.allCases))
        XCTAssertTrue(providers.allSatisfy { !$0.id.isEmpty && !$0.name.isEmpty && !$0.connectionLabel.isEmpty })

        XCTAssertEqual(SourceCatalog.provider(id: "goldfish")?.name, "Goldfish")
        XCTAssertEqual(SourceCatalog.provider(id: "outlook")?.name, "Outlook and Microsoft 365")
        XCTAssertEqual(SourceCatalog.provider(id: "apple-messages")?.name, "Apple Messages")
        XCTAssertEqual(SourceCatalog.provider(id: "microsoft-to-do")?.name, "Microsoft To Do")
        XCTAssertEqual(SourceCatalog.provider(id: "zendesk")?.category, .support)
        XCTAssertEqual(SourceCatalog.provider(id: "google-tasks")?.category, .projects)
        XCTAssertNil(SourceCatalog.provider(id: "unknown-provider"))
    }

    func testPriorityProvidersMatchTheRequestedInitialFocus() {
        let expected: Set<String> = ["goldfish", "outlook", "gmail", "slack", "taalk", "granola", "monday"]
        XCTAssertEqual(Set(SourceCatalog.providers.filter(\.isPriority).map(\.id)), expected)
    }

    func testSeveralAccountsForOneProviderHaveIndependentIdentityAndRoundTrip() throws {
        let date = Date(timeIntervalSinceReferenceDate: 800_000_000.125)
        let connections = [
            SourceConnection(providerID: "outlook", label: "Work", accountHint: "work@example.com", createdAt: date),
            SourceConnection(providerID: "outlook", label: "Other work", accountHint: "other@example.com", createdAt: date),
            SourceConnection(providerID: "slack", label: "First workspace", createdAt: date),
            SourceConnection(providerID: "slack", label: "Second workspace", createdAt: date)
        ]

        XCTAssertEqual(Set(connections.map(\.id)).count, connections.count)
        XCTAssertEqual(connections.filter { $0.providerID == "outlook" }.count, 2)
        let encoded = try JSONEncoder().encode(connections)
        XCTAssertEqual(try JSONDecoder().decode([SourceConnection].self, from: encoded), connections)
    }

    func testUnknownFutureProviderSurvivesSerializationWithoutCatalogEntry() throws {
        let connection = SourceConnection(providerID: "future-provider-v2", label: "Keep this source", accountHint: "Team")
        let data = try JSONEncoder().encode(connection)
        let restored = try JSONDecoder().decode(SourceConnection.self, from: data)

        XCTAssertEqual(restored, connection)
        XCTAssertEqual(restored.providerID, "future-provider-v2")
        XCTAssertNil(SourceCatalog.provider(id: restored.providerID))
    }

    func testSearchMatchesAliasesAndRequiresAllQueryWords() {
        XCTAssertEqual(SourceCatalog.search(query: "iMessage").map(\.id), ["apple-messages"])
        XCTAssertEqual(Set(SourceCatalog.search(query: "M365", category: .calendar).map(\.id)), ["outlook-calendar"])
        XCTAssertEqual(SourceCatalog.search(query: "G Suite email").map(\.id), ["gmail"])
        XCTAssertTrue(SourceCatalog.search(query: "Slack impossible-word").isEmpty)
    }

    func testSearchHandlesCaseWhitespaceAndDiacriticsWithCategoryFiltering() {
        XCTAssertEqual(SourceCatalog.search(query: "  GOLDfíSH \n").map(\.id), ["goldfish"])
        XCTAssertTrue(SourceCatalog.search(query: "Goldfish", category: .email).isEmpty)
        XCTAssertTrue(SourceCatalog.search(query: "dríve", category: .documents).contains { $0.id == "google-drive" })
        XCTAssertEqual(SourceCatalog.search(query: " \n\t").map(\.id), SourceCatalog.providers.map(\.id))
        XCTAssertEqual(
            SourceCatalog.search(query: "", category: .messaging).map(\.id),
            SourceCatalog.providers.filter { $0.category == .messaging }.map(\.id)
        )
    }

    func testRestrictedPersonalMessageSourcesHaveCautiousAccessNotes() {
        for id in ["whatsapp", "apple-messages", "signal", "messenger"] {
            let provider = SourceCatalog.provider(id: id)
            XCTAssertNotNil(provider, id)
            XCTAssertFalse(provider?.accessNote?.isEmpty ?? true, id)
        }
    }

    func testConnectionStoresPlanningDetailsWithoutConnectionClaimsOrSecrets() throws {
        let connection = SourceConnection(providerID: "gmail", label: "Personal")
        XCTAssertEqual(connection.accountHint, "")
        let data = try JSONEncoder().encode(connection)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["id", "providerID", "label", "accountHint", "createdAt"])
    }
}
