import XCTest
import Foundation
import CellBase
import CellApple
@testable import Binding

final class SkeletonParityRemoteXCTest: XCTestCase {
    private static let sentinelPath = "/tmp/binding-enable-remote-parity.flag"

    private struct FixtureDescriptor {
        let slug: String
        let title: String
        let endpoint: String
        let httpRoute: String
        let configurationRoute: String
        let stateRoute: String
    }

    private struct ActionRequest: Encodable {
        let keypath: String
        let payload: ValueType?
    }

    private enum RemoteParityError: LocalizedError, CustomStringConvertible {
        case missingFixture(String)
        case unexpectedStatus(Int, expected: Int, path: String)
        case invalidResponse(String)
        case invalidValueShape(String)
        case missingConfiguration(String)
        case bridgeOperationFailed(endpoint: String, operation: String, underlying: String)

        var errorDescription: String? {
            switch self {
            case .missingFixture(let slug):
                return "Remote skeleton parity fixture mangler i katalogen: \(slug)"
            case .unexpectedStatus(let received, let expected, let path):
                return "Forventet HTTP \(expected) fra \(path), fikk \(received)"
            case .invalidResponse(let path):
                return "Ugyldig respons fra \(path)"
            case .invalidValueShape(let context):
                return "Uventet ValueType-shape for \(context)"
            case .missingConfiguration(let context):
                return "Kunne ikke dekode CellConfiguration for \(context)"
            case .bridgeOperationFailed(let endpoint, let operation, let underlying):
                return """
                Remote bridge-fixturen svarte ikke på \(operation) for \(endpoint): \(underlying). HTTP-fixturene er oppe, så dette peker på staging bridge command-response eller fixture exposure, ikke på Binding sin skeleton-renderer.
                """
            }
        }

        var description: String {
            errorDescription ?? "Remote skeleton parity error"
        }
    }

    private var session: URLSession!

    override func setUpWithError() throws {
        try super.setUpWithError()
        try skipUnlessRemoteParityEnabled()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration)
    }

    override func tearDownWithError() throws {
        session?.invalidateAndCancel()
        session = nil
        try super.tearDownWithError()
    }

    func testCatalogAdvertisesExpectedFixtureRoutes() async throws {
        let descriptors = try await fetchCatalog()
        let bySlug = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.slug, $0) })

        for slug in [
            "text",
            "list",
            "grid",
            "form",
            "markdown",
            "relative-keypath",
            "nested-reference",
            "remote-bridge",
            "unavailable",
            "invalid"
        ] {
            guard let descriptor = bySlug[slug] else {
                throw RemoteParityError.missingFixture(slug)
            }
            XCTAssertTrue(descriptor.endpoint.hasPrefix("cell:///SkeletonParity"), "Unexpected endpoint for \(slug): \(descriptor.endpoint)")
            XCTAssertEqual(descriptor.httpRoute, "/skeleton-parity/\(slug)")
            XCTAssertEqual(descriptor.configurationRoute, "/skeleton-parity/\(slug)/api/configuration")
            XCTAssertEqual(descriptor.stateRoute, "/skeleton-parity/\(slug)/api/state")
        }
    }

    func testTextFixturePublishesConfigurationStateAndActionContract() async throws {
        let descriptor = try await fixture(named: "text")
        let configuration = try await fetchConfiguration(route: descriptor.configurationRoute)
        XCTAssertEqual(configuration.discovery?.sourceCellName, "SkeletonParityTextFixture")
        XCTAssertEqual(configuration.discovery?.sourceCellEndpoint, "cell:///SkeletonParityTextFixture")

        let state = try await fetchValue(route: descriptor.stateRoute)
        assertContainsStrings(state, [
            "Basic structure",
            "public-safe",
            "deterministic"
        ], context: "text.state")

        let actionResponse = try await postAction(
            route: "/skeleton-parity/text/api/action",
            keypath: "dispatchAction",
            payload: .object([
                "keypath": .string("acknowledge"),
                "payload": .bool(true)
            ])
        )
        assertContainsStrings(actionResponse, ["Ack mottatt 1 gang(er)."], context: "text.action")

        let refreshedState = try await fetchValue(route: descriptor.stateRoute)
        assertContainsStrings(refreshedState, ["Ack mottatt 1 gang(er)."], context: "text.state.afterAction")
    }

    func testListFixturePublishesRepeatedRows() async throws {
        let descriptor = try await fixture(named: "list")
        let configuration = try await fetchConfiguration(route: descriptor.configurationRoute)
        XCTAssertEqual(configuration.discovery?.sourceCellName, "SkeletonParityListFixture")
        XCTAssertEqual(configuration.discovery?.sourceCellEndpoint, "cell:///SkeletonParityListFixture")

        let state = try await fetchValue(route: descriptor.stateRoute)
        assertContainsStrings(state, [
            "Repeated list rows",
            "Alpha row",
            "Gamma row"
        ], context: "list.state")
    }

    func testGridFixturePublishesAdaptiveCards() async throws {
        let descriptor = try await fixture(named: "grid")
        let configuration = try await fetchConfiguration(route: descriptor.configurationRoute)
        XCTAssertEqual(configuration.discovery?.sourceCellName, "SkeletonParityGridFixture")
        XCTAssertEqual(configuration.discovery?.sourceCellEndpoint, "cell:///SkeletonParityGridFixture")

        let state = try await fetchValue(route: descriptor.stateRoute)
        assertContainsStrings(state, [
            "Adaptive grid cards",
            "Card one",
            "Card three"
        ], context: "grid.state")
    }

    func testFormFixtureKeepsCookieScopedDeterministicMutations() async throws {
        let descriptor = try await fixture(named: "form")
        let configuration = try await fetchConfiguration(route: descriptor.configurationRoute)
        XCTAssertEqual(configuration.discovery?.sourceCellName, "SkeletonParityFormFixture")
        XCTAssertEqual(configuration.discovery?.sourceCellEndpoint, "cell:///SkeletonParityFormFixture")

        let initialState = try await fetchValue(route: descriptor.stateRoute)
        assertContainsStrings(initialState, [
            "Interactive form",
            "Remote parity draft"
        ], context: "form.initialState")

        let updatedTitle = "Binding parity title"
        let updatedBody = "Binding parity body from remote fixture."
        _ = try await postAction(route: "/skeleton-parity/form/api/action", keypath: "setDraftTitle", payload: .string(updatedTitle))
        _ = try await postAction(route: "/skeleton-parity/form/api/action", keypath: "setDraftBody", payload: .string(updatedBody))

        let mutatedState = try await fetchValue(route: descriptor.stateRoute)
        assertContainsStrings(mutatedState, [updatedTitle, updatedBody], context: "form.mutatedState")

        let savedState = try await postAction(
            route: "/skeleton-parity/form/api/action",
            keypath: "dispatchAction",
            payload: .object([
                "keypath": .string("saveDraft"),
                "payload": .bool(true)
            ])
        )
        assertContainsSubstrings(savedState, ["Form draft lagret deterministisk"], context: "form.saveDraft.substring")

        let resetState = try await postAction(
            route: "/skeleton-parity/form/api/action",
            keypath: "dispatchAction",
            payload: .object([
                "keypath": .string("resetDraft"),
                "payload": .bool(true)
            ])
        )
        assertContainsStrings(resetState, [
            "Form draft nullstilt.",
            "Remote parity draft"
        ], context: "form.resetDraft")
    }

    func testMarkdownFixturePublishesRenderedHTMLAndToggleAction() async throws {
        let descriptor = try await fixture(named: "markdown")
        let configuration = try await fetchConfiguration(route: descriptor.configurationRoute)
        XCTAssertEqual(configuration.discovery?.sourceCellName, "SkeletonParityMarkdownFixture")
        XCTAssertEqual(configuration.discovery?.sourceCellEndpoint, "cell:///SkeletonParityMarkdownFixture")
        assertContainsStrings(.cellConfiguration(configuration), ["Toggle mode"], context: "markdown.configuration")
        assertContainsSubstrings(.cellConfiguration(configuration), ["rendered-html"], context: "markdown.configuration.styleRole")

        let state = try await fetchValue(route: descriptor.stateRoute)
        assertContainsStrings(state, [
            "Markdown and rendered HTML",
            "Ingen handlinger kjørt ennå."
        ], context: "markdown.state")
        assertContainsSubstrings(state, [
            "This fixture keeps **source**",
            "<strong>Rendered HTML</strong>"
        ], context: "markdown.state.content")

        let toggledState = try await postAction(
            route: "/skeleton-parity/markdown/api/action",
            keypath: "dispatchAction",
            payload: .object([
                "keypath": .string("toggleMode"),
                "payload": .bool(true)
            ])
        )
        assertContainsStrings(toggledState, [
            "Markdown and rendered HTML",
            "Markdown view satt til rendered."
        ], context: "markdown.action")
    }

    func testRelativeKeypathFixturePublishesAbsoluteAndRelativeBindings() async throws {
        let descriptor = try await fixture(named: "relative-keypath")
        let configuration = try await fetchConfiguration(route: descriptor.configurationRoute)
        XCTAssertEqual(configuration.discovery?.sourceCellName, "SkeletonParityRelativeKeypathFixture")
        XCTAssertEqual(configuration.discovery?.sourceCellEndpoint, "cell:///SkeletonParityRelativeKeypathFixture")

        let state = try await fetchValue(route: descriptor.stateRoute)
        assertContainsStrings(state, [
            "Relative vs absolute keypaths",
            "Denne linjen bruker absolutt keypath fra rotnivå.",
            "Relative row A",
            "Relative row B",
            "detail.a",
            "detail.b",
            "11",
            "22"
        ], context: "relative-keypath.state")
    }

    func testNestedReferenceFixturePublishesNestedObjectsAcrossTwoLabels() async throws {
        let descriptor = try await fixture(named: "nested-reference")
        let configuration = try await fetchConfiguration(route: descriptor.configurationRoute)
        XCTAssertEqual(configuration.discovery?.sourceCellName, "SkeletonParityNestedReferenceFixture")
        XCTAssertEqual(configuration.discovery?.sourceCellEndpoint, "cell:///SkeletonParityNestedReferenceFixture")

        let state = try await fetchValue(route: descriptor.stateRoute)
        assertContainsStrings(state, [
            "Nested reference payload",
            "Primary workspace",
            "Nested title",
            "Nested subtitle",
            "Secondary projection",
            "Shared row",
            "visible through second label"
        ], context: "nested-reference.state")
    }

    func testRemoteBridgeFixtureDocumentsCanonicalRemoteRoutes() async throws {
        let descriptor = try await fixture(named: "remote-bridge")
        let configuration = try await fetchConfiguration(route: descriptor.configurationRoute)
        XCTAssertEqual(configuration.discovery?.sourceCellName, "SkeletonParityRemoteBridgeFixture")
        XCTAssertEqual(configuration.discovery?.sourceCellEndpoint, "cell:///SkeletonParityRemoteBridgeFixture")

        let state = try await fetchValue(route: descriptor.stateRoute)
        assertContainsStrings(state, [
            "Remote bridge contract",
            "cell://staging.haven.digipomps.org/SkeletonParityTextFixture",
            "https://staging.haven.digipomps.org/skeleton-parity/text/api/configuration",
            "wss://staging.haven.digipomps.org/bridgehead/Porthole/SkeletonParityTextFixture"
        ], context: "remote-bridge.state")

        let ackedState = try await postAction(
            route: "/skeleton-parity/remote-bridge/api/action",
            keypath: "dispatchAction",
            payload: .object([
                "keypath": .string("acknowledge"),
                "payload": .bool(true)
            ])
        )
        assertContainsStrings(ackedState, ["Ack mottatt 1 gang(er)."], context: "remote-bridge.action")
    }

    func testUnavailableFixtureTogglesBetweenUnavailableAndLoadingStates() async throws {
        let descriptor = try await fixture(named: "unavailable")
        let configuration = try await fetchConfiguration(route: descriptor.configurationRoute)
        XCTAssertEqual(configuration.discovery?.sourceCellName, "SkeletonParityUnavailableFixture")
        XCTAssertEqual(configuration.discovery?.sourceCellEndpoint, "cell:///SkeletonParityUnavailableFixture")
        assertContainsStrings(.cellConfiguration(configuration), ["Toggle placeholder"], context: "unavailable.configuration")
        assertContainsSubstrings(.cellConfiguration(configuration), ["#20313B", "#D9FBFF"], context: "unavailable.configuration.badgeModifiers")

        let initialState = try await fetchValue(route: descriptor.stateRoute)
        assertContainsStrings(initialState, [
            "Unavailable and loading",
            "unavailable",
            "Unavailable by design for parity.",
            "Ingen handlinger kjørt ennå."
        ], context: "unavailable.initialState")

        let toggledState = try await postAction(
            route: "/skeleton-parity/unavailable/api/action",
            keypath: "dispatchAction",
            payload: .object([
                "keypath": .string("toggleUnavailable"),
                "payload": .bool(true)
            ])
        )
        assertContainsStrings(toggledState, [
            "Unavailable and loading",
            "loading",
            "Loading placeholder for parity.",
            "Loading-placeholder aktiv."
        ], context: "unavailable.toggledState")
    }

    func testInvalidFixtureFailsLoudlyWith422Diagnostic() async throws {
        let descriptor = try await fixture(named: "invalid")
        let value = try await fetchValue(
            route: descriptor.configurationRoute,
            expectedStatus: 422
        )

        guard case let .object(object) = value else {
            throw RemoteParityError.invalidValueShape("invalid.configuration")
        }

        XCTAssertEqual(object["code"], .string("intentional_invalid_fixture"))
        assertContainsStrings(value, ["intentional_invalid_fixture"], context: "invalid.configuration")
    }

    @MainActor
    func testBridgeBackedFixtureResolvesThroughBindingAndExecutesAction() async throws {
        try XCTSkipIf(
            Self.shouldSkipBridgeCanary,
            "Remote HTTP parity kjører uten bridge-canary. Kjør remote-bridge eller fjern BINDING_REMOTE_PARITY_SKIP_BRIDGE for å verifisere staging bridge command-response."
        )

        let endpoint = "cell://staging.haven.digipomps.org/SkeletonParityTextFixture"
        var configuration = CellConfiguration(name: "Skeleton Parity Remote Bridge")
        configuration.description = "Binding-side remote bridge verification for CellScaffold skeleton parity."
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: endpoint,
            sourceCellName: "SkeletonParityTextFixture",
            purpose: "Skeleton parity remote bridge",
            purposeDescription: "Loads the staging-hosted text fixture through Binding's remote resolver path.",
            interests: ["skeleton", "parity", "remote", "bridge"],
            menuSlots: []
        )

        var reference = CellReference(endpoint: endpoint, label: "fixture")
        reference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(reference)
        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "fixture.state.headline")),
            .Text(SkeletonText(keypath: "fixture.state.status")),
            .Button(SkeletonButton(
                keypath: "fixture.dispatchAction",
                label: "Acknowledge",
                payload: .object([
                    "keypath": .string("acknowledge"),
                    "payload": .bool(true)
                ])
            ))
        ]))

        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        RemoteEndpointAccessSupport.registerRemoteRouteIfNeeded(for: endpoint, resolver: context.resolver)
        let bridgeMeddle = try await RemoteEndpointAccessSupport.resolveMeddle(
            endpoint: endpoint,
            resolver: context.resolver,
            requester: context.owner,
            accessLabel: "Skeleton parity bridge fixture"
        )

        let directBridgeState = try await readBridgeValue(
            bridgeMeddle,
            endpoint: endpoint,
            operation: "get(state)",
            keypath: "state",
            requester: context.owner
        )
        assertContainsStrings(directBridgeState, ["Basic structure"], context: "bridge.direct.state.before")

        XCTAssertEqual(context.validation.errorCount, 0, "Validation issues: \(context.validation.issues)")

        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        let stateBeforeAction = try await readBridgeValue(
            context.porthole,
            endpoint: endpoint,
            operation: "Porthole get(fixture.state)",
            keypath: "fixture.state",
            requester: context.owner
        )
        assertContainsStrings(stateBeforeAction, ["Basic structure"], context: "bridge.state.before")

        let actionResponse = try await writeBridgeValue(
            context.porthole,
            endpoint: endpoint,
            operation: "Porthole set(fixture.dispatchAction)",
            keypath: "fixture.dispatchAction",
            value: .object([
                "keypath": .string("acknowledge"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        if let actionResponse {
            XCTAssertNil(SkeletonBindingProbeSupport.failureDetail(from: actionResponse))
            assertContainsStrings(actionResponse, ["Ack mottatt"], context: "bridge.action")
        } else {
            XCTFail("Expected bridge action response from remote fixture")
        }

        let stateAfterAction = try await readBridgeValue(
            context.porthole,
            endpoint: endpoint,
            operation: "Porthole get(fixture.state) after action",
            keypath: "fixture.state",
            requester: context.owner
        )
        assertContainsStrings(stateAfterAction, ["Ack mottatt"], context: "bridge.state.after")
    }

    func testPersonalChatHubConfigurationPublishesAssistantAndPollContractQuickly() async throws {
        let startedAt = Date()
        let configuration = try await fetchConfiguration(route: "/personal-copilot-v1/chat/api/configuration")
        let elapsed = Date().timeIntervalSince(startedAt)

        XCTAssertLessThan(
            elapsed,
            1.5,
            "PersonalChatHub configuration should be fast enough for first-load UX on staging."
        )
        XCTAssertEqual(configuration.name, "Invite Chat")
        XCTAssertEqual(configuration.discovery?.sourceCellName, "PersonalChatHubCell")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]
        let data = try encoder.encode(configuration)
        guard let json = String(data: data, encoding: .utf8) else {
            throw RemoteParityError.invalidResponse("personal-copilot chat configuration JSON")
        }

        for expected in [
            "\"keypath\":\"chatHub.assistant.analyzeDraft\"",
            "\"keypath\":\"chatHub.assistant.acceptSuggestion\"",
            "\"keypath\":\"chatHub.assistant.dismissSuggestion\"",
            "\"targetKeypath\":\"chatHub.assistant.setCandidateQuery\"",
            "\"selectionActionKeypath\":\"chatHub.assistant.selectCandidate\"",
            "\"selectionPayloadMode\":\"item_id\"",
            "\"targetKeypath\":\"chatHub.poll.setQuestion\"",
            "\"targetKeypath\":\"chatHub.poll.setOptions\"",
            "\"keypath\":\"chatHub.poll.create\"",
            "\"keypath\":\"chatHub.poll.vote\"",
            "\"keypath\":\"chatHub.poll.close\"",
            "purposeRef=personal.chat.assist.invite",
            "purposeRef=personal.chat.assist.poll"
        ] {
            XCTAssertTrue(json.contains(expected), "Staging PersonalChatHub config missing \(expected)")
        }

        XCTAssertFalse(
            json.contains("\"selectionPayloadMode\":\"itemID\""),
            "Staging must publish the CellProtocol wire value item_id, not the Swift case name itemID."
        )
    }

    private static var shouldSkipBridgeCanary: Bool {
        let flag = ProcessInfo.processInfo.environment["BINDING_REMOTE_PARITY_SKIP_BRIDGE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return flag == "1" || flag == "true" || flag == "yes"
    }

    private func skipUnlessRemoteParityEnabled() throws {
        let environment = ProcessInfo.processInfo.environment
        let flag = environment["BINDING_ENABLE_REMOTE_PARITY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let enabledFromEnvironment = flag == "1" || flag == "true" || flag == "yes"
        let enabledFromSentinel = FileManager.default.fileExists(atPath: Self.sentinelPath)
        let enabled = enabledFromEnvironment || enabledFromSentinel
        try XCTSkipUnless(
            enabled,
            "Create \(Self.sentinelPath) or set BINDING_ENABLE_REMOTE_PARITY=1 to run staging-backed skeleton parity tests."
        )
    }

    private func fixture(named slug: String) async throws -> FixtureDescriptor {
        let descriptors = try await fetchCatalog()
        guard let descriptor = descriptors.first(where: { $0.slug == slug }) else {
            throw RemoteParityError.missingFixture(slug)
        }
        return descriptor
    }

    private func fetchCatalog() async throws -> [FixtureDescriptor] {
        let value = try await fetchValue(route: "/skeleton-parity/api/catalog")
        guard case let .object(object) = value,
              case let .list(fixtures)? = object["fixtures"] else {
            throw RemoteParityError.invalidValueShape("catalog")
        }

        return try fixtures.map { item in
            guard case let .object(descriptor) = item,
                  case let .string(slug)? = descriptor["slug"],
                  case let .string(title)? = descriptor["title"],
                  case let .string(endpoint)? = descriptor["endpoint"],
                  case let .string(httpRoute)? = descriptor["httpRoute"],
                  case let .string(configurationRoute)? = descriptor["configurationRoute"],
                  case let .string(stateRoute)? = descriptor["stateRoute"] else {
                throw RemoteParityError.invalidValueShape("catalog.fixture")
            }

            return FixtureDescriptor(
                slug: slug,
                title: title,
                endpoint: endpoint,
                httpRoute: httpRoute,
                configurationRoute: configurationRoute,
                stateRoute: stateRoute
            )
        }
    }

    private func fetchConfiguration(route: String) async throws -> CellConfiguration {
        let value = try await fetchValue(route: route)
        guard let configuration = decodeCellConfiguration(from: value) else {
            throw RemoteParityError.missingConfiguration(route)
        }
        return configuration
    }

    private func fetchValue(
        route: String,
        expectedStatus: Int = 200
    ) async throws -> ValueType {
        let request = URLRequest(url: try makeURL(route: route))
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteParityError.invalidResponse(route)
        }
        guard http.statusCode == expectedStatus else {
            throw RemoteParityError.unexpectedStatus(http.statusCode, expected: expectedStatus, path: route)
        }
        return try JSONDecoder().decode(ValueType.self, from: data)
    }

    private func postAction(
        route: String,
        keypath: String,
        payload: ValueType?
    ) async throws -> ValueType {
        var request = URLRequest(url: try makeURL(route: route))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ActionRequest(keypath: keypath, payload: payload))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteParityError.invalidResponse(route)
        }
        guard http.statusCode == 200 else {
            throw RemoteParityError.unexpectedStatus(http.statusCode, expected: 200, path: route)
        }
        return try JSONDecoder().decode(ValueType.self, from: data)
    }

    private func readBridgeValue(
        _ meddle: Meddle,
        endpoint: String,
        operation: String,
        keypath: String,
        requester: Identity
    ) async throws -> ValueType {
        do {
            return try await meddle.get(keypath: keypath, requester: requester)
        } catch {
            throw RemoteParityError.bridgeOperationFailed(
                endpoint: endpoint,
                operation: operation,
                underlying: String(describing: error)
            )
        }
    }

    private func writeBridgeValue(
        _ meddle: Meddle,
        endpoint: String,
        operation: String,
        keypath: String,
        value: ValueType,
        requester: Identity
    ) async throws -> ValueType? {
        do {
            return try await meddle.set(keypath: keypath, value: value, requester: requester)
        } catch {
            throw RemoteParityError.bridgeOperationFailed(
                endpoint: endpoint,
                operation: operation,
                underlying: String(describing: error)
            )
        }
    }

    private func makeURL(route: String) throws -> URL {
        guard let url = URL(string: route, relativeTo: baseURL)?.absoluteURL else {
            throw RemoteParityError.invalidResponse(route)
        }
        return url
    }

    private var baseURL: URL {
        if let raw = ProcessInfo.processInfo.environment["BINDING_SKELETON_PARITY_BASE_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }
        return URL(string: "https://staging.haven.digipomps.org")!
    }

    private func decodeCellConfiguration(from value: ValueType) -> CellConfiguration? {
        switch value {
        case .cellConfiguration(let configuration):
            return configuration
        case .object(let object):
            guard let data = try? JSONEncoder().encode(object) else { return nil }
            return try? JSONDecoder().decode(CellConfiguration.self, from: data)
        default:
            return nil
        }
    }

    private func assertContainsStrings(
        _ value: ValueType,
        _ expectedStrings: [String],
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let visibleStrings = collectStrings(in: value)
        for expected in expectedStrings {
            XCTAssertTrue(
                visibleStrings.contains(expected),
                "Expected '\(expected)' in \(context), got \(visibleStrings.sorted())",
                file: file,
                line: line
            )
        }
    }

    private func assertContainsSubstrings(
        _ value: ValueType,
        _ expectedSubstrings: [String],
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let visibleStrings = collectStrings(in: value)
        for expected in expectedSubstrings {
            XCTAssertTrue(
                visibleStrings.contains(where: { $0.contains(expected) }),
                "Expected substring '\(expected)' in \(context), got \(visibleStrings.sorted())",
                file: file,
                line: line
            )
        }
    }

    private func collectStrings(in value: ValueType) -> Set<String> {
        switch value {
        case .string(let string):
            return [string]
        case .object(let object):
            return object.values.reduce(into: Set<String>()) { partial, nested in
                partial.formUnion(collectStrings(in: nested))
            }
        case .list(let list):
            return list.reduce(into: Set<String>()) { partial, nested in
                partial.formUnion(collectStrings(in: nested))
            }
        case .cellConfiguration(let configuration):
            guard let data = try? JSONEncoder().encode(configuration),
                  let decoded = try? JSONDecoder().decode(ValueType.self, from: data) else {
                return []
            }
            return collectStrings(in: decoded)
        default:
            return []
        }
    }
}
