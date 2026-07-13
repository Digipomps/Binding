import XCTest
import Foundation
import CellBase
import CellApple
@testable import Binding

final class SkeletonParityRemoteXCTest: XCTestCase {
    private static let sentinelPath = "/tmp/binding-enable-remote-parity.flag"
    private static let skipBridgeSentinelPath = "/tmp/binding-skip-remote-bridge-canary.flag"
    private static let directStagingSurfaceSentinelPath = "/tmp/binding-require-direct-staging-surfaces.flag"

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

    private struct StagingSurfaceDescriptor {
        let displayName: String
        let endpoint: String
        let catalogNames: [String]
        let expectedVisibleStrings: Set<String>
        var configurationKeypaths: [String] = ["skeletonConfiguration", "configuration", "purposeGoal"]

        init(
            displayName: String,
            endpoint: String,
            catalogNames: [String]? = nil,
            expectedVisibleStrings: [String]? = nil,
            configurationKeypaths: [String] = ["skeletonConfiguration", "configuration", "purposeGoal"]
        ) {
            self.displayName = displayName
            self.endpoint = endpoint
            self.catalogNames = catalogNames ?? [displayName]
            self.expectedVisibleStrings = Set(expectedVisibleStrings ?? [catalogNames?.first ?? displayName])
            self.configurationKeypaths = configurationKeypaths
        }
    }

    private static let requestedStagingSurfaces: [StagingSurfaceDescriptor] = [
        StagingSurfaceDescriptor(
            displayName: "Arendalsuka Participant Program",
            endpoint: "cell://staging.haven.digipomps.org/ArendalsukaParticipantProgram"
        ),
        StagingSurfaceDescriptor(
            displayName: "Arendalsuka Event Atlas",
            endpoint: "cell://staging.haven.digipomps.org/ArendalsukaEventAtlas"
        ),
        StagingSurfaceDescriptor(
            displayName: "Todo MVP",
            endpoint: "cell://staging.haven.digipomps.org/Todo",
            catalogNames: ["Todo MVP", "Todo Planner Copilot"]
        ),
        StagingSurfaceDescriptor(
            displayName: "HAVEN Workbench",
            endpoint: "cell://staging.haven.digipomps.org/WorkItem",
            catalogNames: ["HAVEN Workbench", "Work Item Tracker"]
        ),
        StagingSurfaceDescriptor(
            displayName: "Project Portfolio",
            endpoint: "cell://staging.haven.digipomps.org/ProjectPortfolio"
        ),
        StagingSurfaceDescriptor(
            displayName: "Idea Task Workspace",
            endpoint: "cell://staging.haven.digipomps.org/IdeaTaskWorkspace"
        ),
        StagingSurfaceDescriptor(
            displayName: "Conference UI Router",
            endpoint: "cell://staging.haven.digipomps.org/ConferenceUIRouter",
            catalogNames: ["Conference MVP", "Conference Demo Story"]
        ),
        StagingSurfaceDescriptor(
            displayName: "Conference Participant Shell",
            endpoint: "cell://staging.haven.digipomps.org/ConferenceParticipantShell",
            catalogNames: ["Conference Participant Portal", "Conference Participant Preview Shell"]
        ),
        StagingSurfaceDescriptor(
            displayName: "Admin Entry",
            endpoint: "cell://staging.haven.digipomps.org/AdminEntry",
            catalogNames: ["Scaffold Setup & Identity Link"]
        ),
        StagingSurfaceDescriptor(
            displayName: "Admin Overview",
            endpoint: "cell://staging.haven.digipomps.org/AdminOverview",
            catalogNames: ["Admin Cell Dashboard", "Admin Copilot Workspace", "Conference Control Tower"]
        ),
        StagingSurfaceDescriptor(
            displayName: "Conference AI Gateway Preview",
            endpoint: "cell://staging.haven.digipomps.org/ConferenceAIGatewayPreview",
            catalogNames: ["Conference AI Assistant", "AI Gateway"]
        ),
        StagingSurfaceDescriptor(
            displayName: "Agent Conversation Inbox",
            endpoint: "cell://staging.haven.digipomps.org/AgentConversationInbox",
            catalogNames: ["Agent Conversation Inbox", "AI Agent Workspace", "Agent Setup Workbench"]
        )
    ]

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

    private final class BridgeStatusRecorder {
        private let notificationCenter: NotificationCenter
        private let lock = NSLock()
        private var token: NSObjectProtocol?
        private var statuses: [LightweightBridgeConnectionStatus] = []

        init(notificationCenter: NotificationCenter = .default) {
            self.notificationCenter = notificationCenter
            token = notificationCenter.addObserver(
                forName: .lightweightBridgeConnectionStatusDidChange,
                object: nil,
                queue: nil
            ) { [weak self] notification in
                guard let status = LightweightBridgeConnectionStatus(notification: notification) else {
                    return
                }
                self?.append(status)
            }
        }

        deinit {
            if let token {
                notificationCenter.removeObserver(token)
            }
        }

        var summary: String {
            lock.lock()
            let snapshot = statuses
            lock.unlock()

            guard !snapshot.isEmpty else {
                return "no bridge status notifications"
            }

            return snapshot
                .map { status in
                    let detail = status.detail.map { " (\($0))" } ?? ""
                    return "\(status.phase.rawValue) \(status.endpoint)\(detail)"
                }
                .joined(separator: " | ")
        }

        private func append(_ status: LightweightBridgeConnectionStatus) {
            lock.lock()
            statuses.append(status)
            lock.unlock()
        }
    }

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
        let bridgeMeddle = try await resolveBridgeMeddle(
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
            assertContainsSubstrings(actionResponse, ["Ack mottatt"], context: "bridge.action")
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
        assertContainsSubstrings(stateAfterAction, ["Ack mottatt"], context: "bridge.state.after")
    }

    func testPersonalChatHubConfigurationPublishesAssistantAndPollContractQuickly() async throws {
        let startedAt = Date()
        let json = try await fetchText(route: "/personal-copilot-v1/chat/api/configuration")
        let elapsed = Date().timeIntervalSince(startedAt)

        XCTAssertLessThan(
            elapsed,
            1.5,
            "PersonalChatHub configuration should be fast enough for first-load UX on staging."
        )
        XCTAssertTrue(json.contains("\"name\" : \"Co-Pilot Chat\""))
        XCTAssertTrue(json.contains("\"sourceCellName\" : \"PersonalChatHubCell\""))

        let compactJSON = json.filter { !$0.isWhitespace }
        for expected in [
            "visibleAction=assistant.analyzeDraft",
            "visibleAction=assistant.acceptSuggestion",
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
            XCTAssertTrue(compactJSON.contains(expected), "Staging PersonalChatHub config missing \(expected)")
        }

        XCTAssertFalse(
            compactJSON.contains("\"selectionPayloadMode\":\"itemID\""),
            "Staging must publish the CellProtocol wire value item_id, not the Swift case name itemID."
        )
    }

    func testConferenceParticipantPreviewPublishesConciergeAndLocationServices() async throws {
        let configuration = try await fetchConfiguration(route: "/conference-participant-preview/api/configuration")

        assertContainsStrings(.cellConfiguration(configuration), [
            "conferenceParticipantShell.state.concierge.toolCards",
            "conferenceParticipantShell.state.concierge.lastActionSummary",
            "conferenceParticipantShell.dispatchAction",
            "concierge.applyToolCard",
            "find-peer-location"
        ], context: "conference-participant-preview.configuration")

        let state = try await fetchValue(route: "/conference-participant-preview/api/state")
        assertContainsStrings(state, [
            "ConferenceConciergeCell",
            "ConferenceLocationShareCell",
            "Verktøykort er forslag. Ingenting sendes, deles eller opprettes før du trykker Bruk.",
            "Location sharing"
        ], context: "conference-participant-preview.state")
        assertContainsSubstrings(state, [
            "coarse conference venue",
            "does not read device GPS"
        ], context: "conference-participant-preview.state.location")

        let locationResponse = try await postAction(
            route: "/conference-participant-preview/api/action",
            keypath: "location.updatePresence",
            payload: .object([
                "zone": .string("Binding bridge test hall"),
                "proximity": .string("same venue")
            ])
        )
        assertContainsStrings(locationResponse, [
            "ConferenceLocationShareCell",
            "Updated coarse conference presence to Binding bridge test hall."
        ], context: "conference-participant-preview.location.updatePresence")

        let conciergeResponse = try await postAction(
            route: "/conference-participant-preview/api/action",
            keypath: "concierge.applyToolCard",
            payload: .object([
                "toolId": .string("find-peer-location"),
                "peerParticipantId": .string("participant-102"),
                "displayName": .string("Nora Berg")
            ])
        )
        assertContainsStrings(conciergeResponse, [
            "ConferenceConciergeCell",
            "Sjekket delt lokasjon med samtykkegrense. Uten aktiv tilgang vises lokasjon som ikke delt."
        ], context: "conference-participant-preview.concierge.findPeerLocation")
    }

    func testConferenceMVPScreenMapPublishesRouterMap() async throws {
        let status = try await fetchStatus(route: "/conference-mvp/api/screen-map")
        XCTAssertEqual(
            status,
            401,
            "Conference MVP screen-map is admin-gated over HTTP. Binding verifies the map service through the bridge canary."
        )
    }

    @MainActor
    func testConferenceMVPServicesResolveThroughBindingBridge() async throws {
        try XCTSkipIf(
            Self.shouldSkipBridgeCanary,
            "Remote HTTP parity kjører uten bridge-canary. Kjør uten BINDING_REMOTE_PARITY_SKIP_BRIDGE for å verifisere ConferenceUIRouter/ConferenceParticipantShell over Binding bridge."
        )
        try XCTSkipUnless(
            Self.shouldRequireDirectStagingSurfaceAccess,
            "ConferenceParticipantShell er owner-scoped på staging. Sett BINDING_REMOTE_PARITY_REQUIRE_STAGING_SURFACES=1 eller opprett \(Self.directStagingSurfaceSentinelPath) etter at staging-policy/grants er åpnet for denne testidentiteten."
        )

        let routerEndpoint = "cell://staging.haven.digipomps.org/ConferenceUIRouter"
        let participantEndpoint = "cell://staging.haven.digipomps.org/ConferenceParticipantShell"
        var configuration = CellConfiguration(name: "Conference Remote Services Bridge Canary")
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: routerEndpoint,
            sourceCellName: "ConferenceUIRouterCell",
            purpose: "Conference service bridge parity",
            purposeDescription: "Verifies Binding can reach CellScaffold conference map, concierge, and location services through the remote bridge.",
            interests: ["conference", "bridge", "concierge", "location", "screen-map"],
            menuSlots: []
        )
        configuration.addReference(CellReference(endpoint: routerEndpoint, label: "conferenceUIRouter"))
        configuration.addReference(CellReference(endpoint: participantEndpoint, label: "conferenceParticipantShell"))
        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "conferenceUIRouter.screenMap")),
            .Text(SkeletonText(keypath: "conferenceParticipantShell.state.concierge.headline")),
            .Text(SkeletonText(keypath: "conferenceParticipantShell.state.location.headline"))
        ]))

        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)

        let router = try await resolveBridgeMeddle(
            endpoint: routerEndpoint,
            resolver: context.resolver,
            requester: context.owner,
            accessLabel: "Conference router screen map"
        )
        let screenMap = try await readBridgeValue(
            router,
            endpoint: routerEndpoint,
            operation: "get(screenMap)",
            keypath: "screenMap",
            requester: context.owner
        )
        assertContainsStrings(screenMap, [
            "onboarding",
            "peopleMatches",
            "meetings",
            "insights",
            "sponsor"
        ], context: "bridge.conferenceUIRouter.screenMap")

        let participant = try await resolveBridgeMeddle(
            endpoint: participantEndpoint,
            resolver: context.resolver,
            requester: context.owner,
            accessLabel: "Conference participant services"
        )
        let participantState = try await readBridgeValue(
            participant,
            endpoint: participantEndpoint,
            operation: "get(state)",
            keypath: "state",
            requester: context.owner
        )
        assertContainsStrings(participantState, [
            "ConferenceConciergeCell",
            "ConferenceLocationShareCell",
            "Verktøykort er forslag. Ingenting sendes, deles eller opprettes før du trykker Bruk.",
            "Location sharing"
        ], context: "bridge.conferenceParticipantShell.state")

        let locationResponse = try await writeBridgeValue(
            participant,
            endpoint: participantEndpoint,
            operation: "set(dispatchAction location.updatePresence)",
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("location.updatePresence"),
                "payload": .object([
                    "zone": .string("Binding bridge test hall"),
                    "proximity": .string("same venue")
                ])
            ]),
            requester: context.owner
        )
        if let locationResponse {
            assertContainsStrings(locationResponse, [
                "ConferenceLocationShareCell",
                "Updated coarse conference presence to Binding bridge test hall."
            ], context: "bridge.conferenceParticipantShell.location.updatePresence")
        } else {
            XCTFail("Expected bridge response from ConferenceParticipantShell location.updatePresence")
        }
    }

#if canImport(AppKit)
    @MainActor
    func testRequestedStagingCatalogPublishesAvailableSkeletonConfigurationsAndRenderInBinding() async throws {
        try XCTSkipIf(
            Self.shouldSkipBridgeCanary,
            "Remote HTTP parity kjører uten bridge-canary. Kjør remote-contract for å hente og rendre catalog-publiserte staging-konfigurasjoner i HAVEN."
        )

        let context = try await CellConfigurationVerifier.makeRuntimeContext(
            for: CellConfiguration(name: "Remote Staging Catalog Fetch Probe")
        )
        let configurations = try await fetchStagingCatalogConfigurations(
            resolver: context.resolver,
            requester: context.owner
        )
        let requestedSurfaces = Self.requestedStagingSurfaces
        let matched = requestedSurfaces.compactMap { surface -> (StagingSurfaceDescriptor, CellConfiguration)? in
            let acceptedNames = Set(surface.catalogNames + [surface.displayName])
            guard let configuration = configurations.first(where: { acceptedNames.contains($0.name) }) else {
                return nil
            }
            return (surface, configuration)
        }
        let matchedDisplayNames = Set(matched.map { $0.0.displayName })
        let missing = requestedSurfaces
            .filter { !matchedDisplayNames.contains($0.displayName) }
            .map(\.displayName)
            .sorted()

        XCTAssertTrue(
            missing.isEmpty,
            "Remote ConfigurationCatalog did not publish the complete requested surface matrix. Missing: \(missing.joined(separator: ", "))"
        )

        var failures: [String] = []
        for (surface, configuration) in matched {
            do {
                guard configuration.skeleton != nil else {
                    failures.append("\(surface.displayName): ConfigurationCatalog published \(configuration.name) without skeleton")
                    continue
                }

                let validation = CellConfigurationValidationService.validate(configuration)
                guard validation.errorCount == 0 else {
                    failures.append("\(surface.displayName): invalid CellConfiguration \(validation.issues)")
                    continue
                }

                let report = try await CellConfigurationVerifier.renderReport(
                    for: configuration,
                    expectedVisibleStrings: surface.expectedVisibleStrings
                )
                guard report.snapshotByteCount > 0 else {
                    failures.append("\(surface.displayName): rendered a blank snapshot")
                    continue
                }
                guard report.subviewCount > 0 else {
                    failures.append("\(surface.displayName): rendered without SwiftUI subviews")
                    continue
                }
            } catch {
                failures.append("\(surface.displayName): \(String(describing: error).prefix(360))")
            }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "Remote staging catalog configuration render failed:\n- \(failures.joined(separator: "\n- "))"
        )
    }

    @MainActor
    func testRequestedDirectStagingSurfacesPublishSkeletonConfigurationsAndRenderInBindingWhenPolicyOpens() async throws {
        try XCTSkipIf(
            Self.shouldSkipBridgeCanary,
            "Remote HTTP parity kjører uten bridge-canary. Kjør remote-contract for å hente og rendre de konkrete staging-flatene i HAVEN."
        )
        try XCTSkipUnless(
            Self.shouldRequireDirectStagingSurfaceAccess,
            "Direkte staging-flater er grant-/owner-gated. Sett BINDING_REMOTE_PARITY_REQUIRE_STAGING_SURFACES=1 eller opprett \(Self.directStagingSurfaceSentinelPath) etter at staging-policy/grants er åpnet for denne testidentiteten."
        )

        let context = try await CellConfigurationVerifier.makeRuntimeContext(
            for: CellConfiguration(name: "Remote Direct Staging Surface Fetch Probe")
        )

        var failures: [String] = []
        for surface in Self.requestedStagingSurfaces {
            do {
                let configuration = try await fetchStagingSurfaceConfiguration(
                    surface,
                    resolver: context.resolver,
                    requester: context.owner
                )
                guard configuration.skeleton != nil else {
                    failures.append("\(surface.displayName): published CellConfiguration without skeleton from \(surface.endpoint)")
                    continue
                }

                let validation = CellConfigurationValidationService.validate(configuration)
                guard validation.errorCount == 0 else {
                    failures.append("\(surface.displayName): invalid CellConfiguration \(validation.issues)")
                    continue
                }

                let report = try await CellConfigurationVerifier.renderReport(
                    for: configuration,
                    expectedVisibleStrings: surface.expectedVisibleStrings
                )
                guard report.snapshotByteCount > 0 else {
                    failures.append("\(surface.displayName): rendered a blank snapshot")
                    continue
                }
                guard report.subviewCount > 0 else {
                    failures.append("\(surface.displayName): rendered without SwiftUI subviews")
                    continue
                }
            } catch {
                failures.append("\(surface.displayName): \(String(describing: error).prefix(360))")
            }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "Remote staging surface verification failed:\n- \(failures.joined(separator: "\n- "))"
        )
    }
#endif

    private static var shouldSkipBridgeCanary: Bool {
        let flag = ProcessInfo.processInfo.environment["BINDING_REMOTE_PARITY_SKIP_BRIDGE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let enabledFromEnvironment = flag == "1" || flag == "true" || flag == "yes"
        let enabledFromSentinel = FileManager.default.fileExists(atPath: Self.skipBridgeSentinelPath)
        return enabledFromEnvironment || enabledFromSentinel
    }

    private static var shouldRequireDirectStagingSurfaceAccess: Bool {
        let flag = ProcessInfo.processInfo.environment["BINDING_REMOTE_PARITY_REQUIRE_STAGING_SURFACES"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let enabledFromEnvironment = flag == "1" || flag == "true" || flag == "yes"
        let enabledFromSentinel = FileManager.default.fileExists(atPath: Self.directStagingSurfaceSentinelPath)
        return enabledFromEnvironment || enabledFromSentinel
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
        let request = URLRequest(url: try makeURL(route: route))
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteParityError.invalidResponse(route)
        }
        guard http.statusCode == 200 else {
            throw RemoteParityError.unexpectedStatus(http.statusCode, expected: 200, path: route)
        }
        if let configuration = try? JSONDecoder().decode(CellConfiguration.self, from: data) {
            return configuration
        }
        let value = try JSONDecoder().decode(ValueType.self, from: data)
        guard let configuration = decodeCellConfiguration(from: value) else {
            throw RemoteParityError.missingConfiguration(route)
        }
        return configuration
    }

    private func fetchStatus(route: String) async throws -> Int {
        let request = URLRequest(url: try makeURL(route: route))
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteParityError.invalidResponse(route)
        }
        return http.statusCode
    }

    private func fetchText(route: String) async throws -> String {
        let request = URLRequest(url: try makeURL(route: route))
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteParityError.invalidResponse(route)
        }
        guard http.statusCode == 200 else {
            throw RemoteParityError.unexpectedStatus(http.statusCode, expected: 200, path: route)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw RemoteParityError.invalidResponse(route)
        }
        return text
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
            return try await withBridgeOperationTimeout(endpoint: endpoint, operation: operation) {
                try await meddle.get(keypath: keypath, requester: requester)
            }
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
            return try await withBridgeOperationTimeout(endpoint: endpoint, operation: operation) {
                try await meddle.set(keypath: keypath, value: value, requester: requester)
            }
        } catch {
            throw RemoteParityError.bridgeOperationFailed(
                endpoint: endpoint,
                operation: operation,
                underlying: String(describing: error)
            )
        }
    }

    private func resolveBridgeMeddle(
        endpoint: String,
        resolver: CellResolver,
        requester: Identity,
        accessLabel: String
    ) async throws -> Meddle {
        let bridgeStatuses = BridgeStatusRecorder()
        do {
            return try await RemoteEndpointAccessSupport.resolveMeddle(
                endpoint: endpoint,
                resolver: resolver,
                requester: requester,
                accessLabel: accessLabel
            )
        } catch {
            throw RemoteParityError.bridgeOperationFailed(
                endpoint: endpoint,
                operation: "resolveMeddle",
                underlying: "\(String(describing: error)); bridge statuses: \(bridgeStatuses.summary)"
            )
        }
    }

    private func fetchStagingSurfaceConfiguration(
        _ surface: StagingSurfaceDescriptor,
        resolver: CellResolver,
        requester: Identity
    ) async throws -> CellConfiguration {
        let meddle = try await resolveBridgeMeddle(
            endpoint: surface.endpoint,
            resolver: resolver,
            requester: requester,
            accessLabel: "remote staging surface configuration: \(surface.displayName)"
        )

        var misses: [String] = []
        for keypath in surface.configurationKeypaths {
            let value = try await readBridgeValue(
                meddle,
                endpoint: surface.endpoint,
                operation: "get \(keypath)",
                keypath: keypath,
                requester: requester
            )
            if let configuration = PortableSurfaceContractSupport.extractConfiguration(from: value) {
                return configuration
            }
            misses.append("\(keypath)=\(String(describing: value).prefix(180))")
        }

        throw RemoteParityError.missingConfiguration(
            "\(surface.displayName) at \(surface.endpoint). Tried \(surface.configurationKeypaths.joined(separator: ", ")); got \(misses.joined(separator: " | "))"
        )
    }

    private func fetchStagingCatalogConfigurations(
        resolver: CellResolver,
        requester: Identity
    ) async throws -> [CellConfiguration] {
        let endpoint = "cell://staging.haven.digipomps.org/ConfigurationCatalog"
        let meddle: Meddle
        do {
            meddle = try await resolveBridgeMeddle(
                endpoint: endpoint,
                resolver: resolver,
                requester: requester,
                accessLabel: "remote staging ConfigurationCatalog"
            )
        } catch {
            if !Self.shouldRequireDirectStagingSurfaceAccess,
               Self.isOwnerApprovalAdmissionGate(error) {
                throw XCTSkip("""
                Remote ConfigurationCatalog krever owner-godkjent Agreement før admission (signContract). Kjør remote-direct først når CellScaffold publiserer en eksplisitt read-only owner-godkjent katalogprojeksjon eller denne testidentiteten har et owner-signert grant.
                """)
            }
            throw error
        }
        let value = try await readBridgeValue(
            meddle,
            endpoint: endpoint,
            operation: "get(configurations)",
            keypath: "configurations",
            requester: requester
        )
        guard case let .list(items) = value else {
            if !Self.shouldRequireDirectStagingSurfaceAccess,
               let reason = policyGateReason(from: value, context: "ConfigurationCatalog.configurations") {
                throw XCTSkip("""
                Remote ConfigurationCatalog.configurations er policy-/grant-gated for denne testidentiteten: \(reason). Kjør Scripts/run_skeleton_parity_suite.sh remote-direct etter at staging-policy/grants er åpnet for å gjøre dette til en hard verifikasjon.
                """)
            }
            throw RemoteParityError.invalidValueShape(
                "ConfigurationCatalog.configurations: \(Self.compactDescription(String(describing: value)))"
            )
        }

        return items.compactMap { PortableSurfaceContractSupport.extractConfiguration(from: $0) }
    }

    private static func isOwnerApprovalAdmissionGate(_ error: Error) -> Bool {
        guard let remoteError = error as? RemoteParityError,
              case let .bridgeOperationFailed(_, operation, underlying) = remoteError,
              operation == "resolveMeddle" else {
            return false
        }
        let normalized = underlying.lowercased()
        return normalized.contains("contractrejected") && normalized.contains("signcontract")
    }

    private func policyGateReason(from value: ValueType, context: String) -> String? {
        let description = Self.compactDescription(String(describing: value))
        guard Self.isPolicyGateDescription(description) else {
            return nil
        }
        return "\(context)=\(description)"
    }

    private static func compactDescription(_ description: String, limit: Int = 360) -> String {
        let singleLine = description
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        guard singleLine.count > limit else {
            return singleLine
        }
        return String(singleLine.prefix(limit)) + "..."
    }

    private static func isPolicyGateDescription(_ description: String) -> Bool {
        let lowercased = description.lowercased()
        return [
            "denied",
            "contractrejected",
            "contract rejected",
            "agreement_or_proof_required",
            "signcontract",
            "owner-scoped",
            "owner scoped",
            "grant-gated",
            "policy-gated"
        ].contains { lowercased.contains($0) }
    }

    private func withBridgeOperationTimeout<T: Sendable>(
        endpoint: String,
        operation: String,
        seconds: Double = 20,
        _ work: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var didResolve = false

            func resolve(_ result: Result<T, Error>) {
                lock.lock()
                guard !didResolve else {
                    lock.unlock()
                    return
                }
                didResolve = true
                lock.unlock()

                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let workTask = Task.detached {
                do {
                    resolve(.success(try await work()))
                } catch {
                    resolve(.failure(error))
                }
            }

            Task.detached {
                let duration = max(seconds, 0)
                do {
                    try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                } catch {
                    return
                }
                workTask.cancel()
                resolve(.failure(RemoteParityError.bridgeOperationFailed(
                    endpoint: endpoint,
                    operation: operation,
                    underlying: "timed out after \(duration)s"
                )))
            }
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
