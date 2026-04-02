import XCTest
import CellBase
import CellApple
@testable import Binding

#if canImport(AppKit)
import AppKit
#endif

@MainActor
final class CellConfigurationVerifierXCTest: XCTestCase {
    @MainActor
    func testConferencePreviewCellsStayLocalWhenRetargeting() {
        let contentView = ContentView()

        XCTAssertEqual(
            contentView.maybeRetargetLocalEndpointToStaging("cell:///ConferenceParticipantPreviewShell"),
            "cell:///ConferenceParticipantPreviewShell"
        )
        XCTAssertEqual(
            contentView.maybeRetargetLocalEndpointToStaging("cell:///ConferenceAdminPreviewShell"),
            "cell:///ConferenceAdminPreviewShell"
        )
        XCTAssertEqual(
            contentView.maybeRetargetLocalEndpointToStaging("cell:///ConferenceParticipantDiscoverySnapshot"),
            "cell:///ConferenceParticipantDiscoverySnapshot"
        )
        XCTAssertEqual(
            contentView.maybeRetargetLocalEndpointToStaging("cell:///ConferenceIdentityLinkIntake"),
            "cell:///ConferenceIdentityLinkIntake"
        )
        XCTAssertEqual(
            contentView.maybeRetargetLocalEndpointToStaging("cell:///Chat"),
            "cell://staging.haven.digipomps.org/Chat"
        )
    }

    func testConferenceParticipantPortalContract() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Vis for deg",
                "Vis timeline",
                "Vis lagret",
                "Fokuser governance",
                "Finn governance-matcher",
                "Åpne chatflate"
            ],
            rootProbes: [
                .init(label: "agendaSnapshot", rootKeypath: "state"),
                .init(label: "matchmakingSnapshot", rootKeypath: "state"),
                .init(label: "discoverySnapshot", rootKeypath: "state"),
                .init(label: "nearbyRadar", rootKeypath: "state"),
                .init(label: "chatSnapshot", rootKeypath: "state")
            ]
        )

        XCTAssertEqual(
            report.validation.errorCount,
            0,
            "Validation issues: \(report.validation.issues)"
        )
        XCTAssertTrue(
            report.unresolvedReferences.isEmpty,
            "Unresolved references: \(report.unresolvedReferences)"
        )
        XCTAssertTrue(
            report.unreadableRootProbes.isEmpty,
            "Unreadable root probes: \(report.unreadableRootProbes)"
        )
        XCTAssertTrue(
            report.failedActions.isEmpty,
            "Failed actions: \(report.failedActions)"
        )
    }

    func testConferenceDemoLauncherContract() async throws {
        let configuration = ConfigurationCatalogCell.conferenceDemoLauncherWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Open public surface",
                "Open identity link setup",
                "Open participant cockpit",
                "Open participant chat",
                "Open control tower",
                "Open AI assistant"
            ],
            rootProbes: [
                .init(label: "conferenceDemoLauncher", rootKeypath: "state")
            ]
        )

        XCTAssertEqual(
            report.validation.errorCount,
            0,
            "Validation issues: \(report.validation.issues)"
        )
        XCTAssertTrue(
            report.unresolvedReferences.isEmpty,
            "Unresolved references: \(report.unresolvedReferences)"
        )
        XCTAssertTrue(
            report.unreadableRootProbes.isEmpty,
            "Unreadable root probes: \(report.unreadableRootProbes)"
        )
        XCTAssertTrue(
            report.failedActions.isEmpty,
            "Failed actions: \(report.failedActions)"
        )
    }

    func testConferenceControlTowerContract() async throws {
        let configuration = ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
            endpoint: "cell:///ConferenceAdminPreviewShell"
        )

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Publish content",
                "Discard draft"
            ]
        )

        XCTAssertEqual(
            report.validation.errorCount,
            0,
            "Validation issues: \(report.validation.issues)"
        )
        XCTAssertTrue(
            report.unresolvedReferences.isEmpty,
            "Unresolved references: \(report.unresolvedReferences)"
        )
        XCTAssertTrue(
            report.unreadableRootProbes.isEmpty,
            "Unreadable root probes: \(report.unreadableRootProbes)"
        )
        XCTAssertTrue(
            report.failedActions.isEmpty,
            "Failed actions: \(report.failedActions)"
        )
    }

    func testConferenceNearbyRadarContract() async throws {
        let configuration = ConfigurationCatalogCell.conferenceNearbyRadarWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Start scanner",
                "Stop scanner",
                "Tilbake til portalen"
            ],
            rootProbes: [
                .init(label: "nearbyRadar", rootKeypath: "state")
            ]
        )

        XCTAssertEqual(report.validation.errorCount, 0, "Validation issues: \(report.validation.issues)")
        XCTAssertTrue(report.unresolvedReferences.isEmpty, "Unresolved references: \(report.unresolvedReferences)")
        XCTAssertTrue(report.unreadableRootProbes.isEmpty, "Unreadable root probes: \(report.unreadableRootProbes)")
        XCTAssertTrue(report.failedActions.isEmpty, "Failed actions: \(report.failedActions)")
    }

    func testConferenceNearbyParticipantProfileContract() async throws {
        let configuration = ConfigurationCatalogCell.conferenceNearbyParticipantWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Åpne full radar",
                "Tilbake til portalen"
            ],
            rootProbes: [
                .init(label: "nearbyRadar", rootKeypath: "state")
            ]
        )

        XCTAssertEqual(report.validation.errorCount, 0, "Validation issues: \(report.validation.issues)")
        XCTAssertTrue(report.unresolvedReferences.isEmpty, "Unresolved references: \(report.unresolvedReferences)")
        XCTAssertTrue(report.unreadableRootProbes.isEmpty, "Unreadable root probes: \(report.unreadableRootProbes)")
        XCTAssertTrue(report.failedActions.isEmpty, "Failed actions: \(report.failedActions)")
    }

    func testConferenceParticipantChatContract() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantChatWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Tilbake til portalen"
            ],
            rootProbes: [
                .init(label: "chatSnapshot", rootKeypath: "state")
            ]
        )

        XCTAssertEqual(report.validation.errorCount, 0, "Validation issues: \(report.validation.issues)")
        XCTAssertTrue(report.unresolvedReferences.isEmpty, "Unresolved references: \(report.unresolvedReferences)")
        XCTAssertTrue(report.unreadableRootProbes.isEmpty, "Unreadable root probes: \(report.unreadableRootProbes)")
        XCTAssertTrue(report.failedActions.isEmpty, "Failed actions: \(report.failedActions)")
    }

    func testConferenceParticipantNearbyFollowUpContract() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )

        let report = try await CellConfigurationVerifier.nearbyFollowUpReport(for: configuration)

        XCTAssertEqual(report.startOutcome, "ok")
        XCTAssertEqual(report.statusAfterStart, "started")
        XCTAssertEqual(report.requestContactOutcome, "ok")
        XCTAssertEqual(report.requestContactLabel, "Kontakt venter")
        XCTAssertEqual(report.requestContactSummary, "Signert kontaktforespørsel sendt. Venter på godkjenning.")
        XCTAssertEqual(report.requestContactActionSummary, "Signert kontaktforespørsel sendt. Venter på godkjenning.")
        XCTAssertEqual(report.openChatOutcome, "ok")
        XCTAssertEqual(report.nearbyCardLabel, "Åpne chatflate")
        XCTAssertTrue(report.nearbyCardPurposeSummary?.contains("verified overlap") == true)
        XCTAssertEqual(report.nearbyActionSummary, "Startet conference-chat med Nora Berg.")
        XCTAssertEqual(report.workspaceNextStep, "Started follow-up chat with Nora Berg in local preview.")
        XCTAssertEqual(report.sharedChatSummary, "2 shared message(s) visible.")
        XCTAssertEqual(report.firstRecentMessage, "Ja, gjerne. Jobber med tillit, relasjoner og hvordan identitet og oppfølging kan flyte mellom team. Hvis du vil, kan vi ta et kort neste steg etter sesjonen.")
        XCTAssertEqual(report.stopOutcome, "ok")
        XCTAssertEqual(report.statusAfterStop, "stopped")
    }

    func testConferenceParticipantPreviewRecommendationFocusAndFollowUpActions() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            XCTFail("Expected shared CellResolver after app initialization")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            XCTFail("Missing private identity")
            return
        }
        guard let preview = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: identity
        ) as? Meddle else {
            XCTFail("ConferenceParticipantPreviewShell did not resolve as Meddle")
            return
        }

        _ = try await preview.set(
            keypath: "dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("agenda.setView"),
                "payload": ValueType.object([
                    "view": ValueType.string("timeline")
                ])
            ]),
            requester: identity
        )

        _ = try await preview.set(
            keypath: "dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("agenda.setTrackFocus"),
                "payload": ValueType.object([
                    "trackId": ValueType.string("track-governance")
                ])
            ]),
            requester: identity
        )

        _ = try await preview.set(
            keypath: "dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("matchmaking.focusPerson"),
                "payload": ValueType.object([
                    "displayName": ValueType.string("Ane Solberg"),
                    "subtitle": ValueType.string("Public sector interoperability")
                ])
            ]),
            requester: identity
        )

        _ = try await preview.set(
            keypath: "dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("matchmaking.toggleFollowUp"),
                "payload": ValueType.object([
                    "displayName": ValueType.string("Governance Forum"),
                    "subtitle": ValueType.string("Nearby people")
                ])
            ]),
            requester: identity
        )

        let stateValue = try await preview.get(keypath: "state", requester: identity)
        guard case let .object(stateObject) = stateValue else {
            XCTFail("Expected state object from conference participant preview fallback")
            return
        }
        guard let workspaceValue = stateObject["workspace"],
              case let .object(workspace) = workspaceValue else {
            XCTFail("Expected workspace object from conference participant preview fallback")
            return
        }
        guard let programValue = stateObject["program"],
              case let .object(program) = programValue else {
            XCTFail("Expected program object from conference participant preview fallback")
            return
        }
        guard let matchesValue = stateObject["matches"],
              case let .object(matches) = matchesValue else {
            XCTFail("Expected matches object from conference participant preview fallback")
            return
        }

        XCTAssertEqual(workspace["nextStep"], ValueType.string("Marked Governance Forum for follow-up in local preview."))
        XCTAssertEqual(program["viewSummary"], ValueType.string("Current view: Timeline."))
        XCTAssertEqual(program["trackSummary"], ValueType.string("Track focus: Governance."))
        XCTAssertEqual(program["timelineSummary"], ValueType.string("8 session(s) visible in timeline view."))
        XCTAssertEqual(matches["recommendationSummary"], ValueType.string("Focused recommendation: Ane Solberg. Open chat or mark follow-up when you are ready."))
        XCTAssertEqual(matches["status"], ValueType.string("Focused on Ane Solberg. The next natural step is to start chat or mark follow-up."))
        XCTAssertEqual(matches["searchSummary"], ValueType.string("Search broadening: people. 1 person(s) marked for follow-up."))

        guard let recommendationsValue = matches["recommendations"],
              case let .list(recommendations) = recommendationsValue,
              case let .object(firstRecommendation)? = recommendations.first else {
            XCTFail("Expected recommendations list in preview fallback state")
            return
        }
        XCTAssertEqual(firstRecommendation["label"], ValueType.string("Start chat"))

        guard let searchResultsValue = matches["searchResults"],
              case let .list(searchResults) = searchResultsValue,
              case let .object(firstSearchResult)? = searchResults.first else {
            XCTFail("Expected search results list in preview fallback state")
            return
        }
        XCTAssertEqual(firstSearchResult["label"], ValueType.string("Fjern markering"))
    }

    func testConferenceParticipantMatchmakingSnapshotSupportsInlineSelectionAndActions() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            XCTFail("Expected shared CellResolver after app initialization")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            XCTFail("Missing private identity")
            return
        }
        guard let snapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantMatchmakingSnapshot",
            requester: identity
        ) as? Meddle else {
            XCTFail("ConferenceParticipantMatchmakingSnapshot did not resolve as Meddle")
            return
        }

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("matchmaking.focusPerson"),
                "payload": ValueType.object([
                    "displayName": ValueType.string("Ane Solberg"),
                    "subtitle": ValueType.string("Public sector interoperability")
                ])
            ]),
            requester: identity
        )

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("matchmaking.toggleFollowUp"),
                "payload": ValueType.object([
                    "displayName": ValueType.string("Ane Solberg"),
                    "subtitle": ValueType.string("Public sector interoperability")
                ])
            ]),
            requester: identity
        )

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("discovery.startChat"),
                "payload": ValueType.object([
                    "source": ValueType.string("binding-test"),
                    "targets": ValueType.list([
                        ValueType.object([
                            "displayName": ValueType.string("Ane Solberg"),
                            "headline": ValueType.string("Public sector interoperability")
                        ])
                    ])
                ])
            ]),
            requester: identity
        )

        let stateValue = try await snapshot.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue else {
            XCTFail("Expected object from matchmaking snapshot")
            return
        }
        guard let focusedProfileValue = object["focusedProfile"],
              case let .object(focusedProfile) = focusedProfileValue,
              let focusedActionsValue = object["focusedActions"],
              case let .list(focusedActions) = focusedActionsValue,
              let recommendationsValue = object["recommendations"],
              case let .list(recommendations) = recommendationsValue,
              case let .object(firstRecommendation)? = recommendations.first else {
            XCTFail("Expected focused profile, actions, and recommendations in matchmaking snapshot")
            return
        }

        XCTAssertEqual(object["selectionSummary"], ValueType.string("Viser Ane Solberg i denne siden."))
        XCTAssertEqual(focusedProfile["title"], ValueType.string("Ane Solberg"))
        XCTAssertEqual(focusedProfile["publicProfileSummary"], ValueType.string("Offentlig profil: Public sector interoperability."))
        XCTAssertEqual(
            focusedProfile["nextStep"],
            ValueType.string("Bruk Start chat, Marker for oppfølging eller Be om møte med Ane Solberg.")
        )
        XCTAssertEqual(firstRecommendation["label"], ValueType.string("Valgt i siden"))

        guard case let .object(chatAction)? = focusedActions.first,
              case let .object(followUpAction)? = focusedActions.dropFirst().first,
              case let .object(meetingAction)? = focusedActions.dropFirst(2).first else {
            XCTFail("Expected three focused actions")
            return
        }

        XCTAssertEqual(chatAction["label"], ValueType.string("Åpne chatflate"))
        XCTAssertEqual(followUpAction["label"], ValueType.string("Fjern markering"))
        XCTAssertEqual(meetingAction["label"], ValueType.string("Be om møte"))

        guard let preview = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: identity
        ) as? Meddle else {
            XCTFail("ConferenceParticipantPreviewShell did not resolve as Meddle")
            return
        }

        let previewState = try await preview.get(keypath: "state", requester: identity)
        guard case let .object(previewObject) = previewState,
              case let .object(sharedConnections)? = previewObject["sharedConnections"],
              case let .list(connections)? = sharedConnections["connections"],
              case let .object(firstConnection)? = connections.first else {
            XCTFail("Expected shared connection after start chat")
            return
        }

        XCTAssertEqual(sharedConnections["connectionSummary"], ValueType.string("1 shared relation(s) visible."))
        XCTAssertEqual(sharedConnections["chatSummary"], ValueType.string("2 shared message(s) visible."))
        XCTAssertEqual(firstConnection["title"], ValueType.string("Ane Solberg"))

        guard let chatSnapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantChatSnapshot",
            requester: identity
        ) as? Meddle else {
            XCTFail("ConferenceParticipantChatSnapshot did not resolve as Meddle")
            return
        }

        let chatState = try await chatSnapshot.get(keypath: "state", requester: identity)
        guard case let .object(chatObject) = chatState,
              case let .object(focusedThread)? = chatObject["focusedThread"] else {
            XCTFail("Expected chat snapshot state after start chat")
            return
        }

        XCTAssertEqual(chatObject["selectionSummary"], ValueType.string("Viser den delte tråden med Ane Solberg."))
        XCTAssertEqual(focusedThread["title"], ValueType.string("Ane Solberg"))
    }

    func testConferenceParticipantPortalSearchGovernanceButtonUsesRendererExecutionPath() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )
        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        let button = SkeletonButton(
            keypath: "matchmakingSnapshot.dispatchAction",
            label: "Finn governance-matcher",
            payload: .object([
                "keypath": .string("matchmaking.searchPeople"),
                "payload": .object(["query": .string("governance")])
            ])
        )

        let response = await button.execute()
        XCTAssertNotNil(response, "Renderer button path returned nil for Finn governance-matcher")
        if let response {
            XCTAssertNil(
                SkeletonBindingProbeSupport.failureDetail(from: response),
                "Renderer button path returned failure payload for Finn governance-matcher: \(response)"
            )
        }

        let actionSummary = try await context.porthole.get(
            keypath: "matchmakingSnapshot.state.actionSummary",
            requester: context.owner
        )
        XCTAssertEqual(actionSummary, .string("Viser governance-relevante personer i anbefalingene."))

        let searchSummary = try await context.porthole.get(
            keypath: "matchmakingSnapshot.state.searchSummary",
            requester: context.owner
        )
        if case let .string(searchSummaryText) = searchSummary {
            XCTAssertTrue(
                searchSummaryText.localizedCaseInsensitiveContains("governance"),
                "Expected governance-focused search summary, got: \(searchSummaryText)"
            )
        } else {
            XCTFail("Expected string searchSummary after Finn governance-matcher, got \(searchSummary)")
        }
    }

    func testConferenceParticipantDiscoverySnapshotSupportsInlineSelectionAndActions() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            XCTFail("Expected shared CellResolver after app initialization")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            XCTFail("Missing private identity")
            return
        }
        guard let snapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantDiscoverySnapshot",
            requester: identity
        ) as? Meddle else {
            XCTFail("ConferenceParticipantDiscoverySnapshot did not resolve as Meddle")
            return
        }

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("discovery.focusPerson"),
                "payload": ValueType.object([
                    "displayName": ValueType.string("Ane Solberg"),
                    "subtitle": ValueType.string("Public sector interoperability")
                ])
            ]),
            requester: identity
        )

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("matchmaking.toggleFollowUp"),
                "payload": ValueType.object([
                    "displayName": ValueType.string("Ane Solberg"),
                    "subtitle": ValueType.string("Public sector interoperability")
                ])
            ]),
            requester: identity
        )

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("discovery.startChat"),
                "payload": ValueType.object([
                    "source": ValueType.string("binding-test"),
                    "targets": ValueType.list([
                        ValueType.object([
                            "displayName": ValueType.string("Ane Solberg"),
                            "headline": ValueType.string("Public sector interoperability")
                        ])
                    ])
                ])
            ]),
            requester: identity
        )

        let stateValue = try await snapshot.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue else {
            XCTFail("Expected object from discovery snapshot")
            return
        }
        guard let focusedProfileValue = object["focusedProfile"],
              case let .object(focusedProfile) = focusedProfileValue,
              let focusedActionsValue = object["focusedActions"],
              case let .list(focusedActions) = focusedActionsValue,
              let candidatesValue = object["candidates"],
              case let .list(candidates) = candidatesValue,
              case let .object(firstCandidate)? = candidates.first else {
            XCTFail("Expected focused discovery state")
            return
        }

        XCTAssertEqual(object["selectionSummary"], ValueType.string("Viser Ane Solberg i discovery-delen."))
        XCTAssertEqual(focusedProfile["title"], ValueType.string("Ane Solberg"))
        XCTAssertEqual(firstCandidate["label"], ValueType.string("Åpne chatflate"))

        guard case let .object(chatAction)? = focusedActions.first,
              case let .object(followUpAction)? = focusedActions.dropFirst().first,
              case let .object(meetingAction)? = focusedActions.dropFirst(2).first else {
            XCTFail("Expected three focused discovery actions")
            return
        }

        XCTAssertEqual(chatAction["label"], ValueType.string("Åpne chatflate"))
        XCTAssertEqual(followUpAction["label"], ValueType.string("Fjern markering"))
        XCTAssertEqual(meetingAction["label"], ValueType.string("Be om møte"))
    }

    func testConferenceParticipantAgendaSnapshotSupportsInlineSelectionAndActions() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            XCTFail("Expected shared CellResolver after app initialization")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            XCTFail("Missing private identity")
            return
        }
        guard let snapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantAgendaSnapshot",
            requester: identity
        ) as? Meddle else {
            XCTFail("ConferenceParticipantAgendaSnapshot did not resolve as Meddle")
            return
        }

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("agenda.setView"),
                "payload": .object([
                    "view": .string("timeline")
                ])
            ]),
            requester: identity
        )

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("agenda.setTrackFocus"),
                "payload": .object([
                    "trackId": .string("track-governance")
                ])
            ]),
            requester: identity
        )

        let stateValue = try await snapshot.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue,
              case let .list(modeChoices)? = object["modeChoices"],
              case let .object(firstModeChoice)? = modeChoices.first,
              case let .object(secondModeChoice)? = modeChoices.dropFirst().first,
              case let .list(trackChoices)? = object["trackChoices"],
              case let .object(firstTrackChoice)? = trackChoices.first,
              case let .object(secondTrackChoice)? = trackChoices.dropFirst().first else {
            XCTFail("Expected agenda snapshot state with mode and track choices")
            return
        }

        XCTAssertEqual(object["statusSummary"], ValueType.string("Viser timeline med governance i fokus."))
        XCTAssertEqual(object["selectionSummary"], ValueType.string("Viser timeline med Governance i fokus."))
        XCTAssertEqual(object["actionSummary"], ValueType.string("Governance er nå i fokus i denne siden."))
        XCTAssertEqual(firstModeChoice["label"], ValueType.string("Vis for deg"))
        XCTAssertEqual(secondModeChoice["selectionBadge"], ValueType.string("AKTIV NÅ"))
        XCTAssertEqual(secondModeChoice["label"], ValueType.string("Viser nå"))
        XCTAssertEqual(firstTrackChoice["label"], ValueType.string("Vis alle spor"))
        XCTAssertEqual(secondTrackChoice["selectionBadge"], ValueType.string("FOKUS NÅ"))
        XCTAssertEqual(secondTrackChoice["label"], ValueType.string("Viser nå"))
    }

    func testConferenceParticipantPortalProxyActionsCanOpenChatWorkbench() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )
        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        let focusResponse = try await context.porthole.set(
            keypath: "matchmakingSnapshot.dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("matchmaking.focusRecommendationAtIndex"),
                "payload": ValueType.object([
                    "index": ValueType.integer(0)
                ])
            ]),
            requester: context.owner
        )
        guard let focusResponse else {
            XCTFail("Focus action returned nil response")
            return
        }
        let focusFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: focusResponse)
        }
        XCTAssertNil(focusFailure)

        let focusedTitle = try await context.porthole.get(
            keypath: "matchmakingSnapshot.state.focusedProfile.title",
            requester: context.owner
        )
        XCTAssertEqual(focusedTitle, ValueType.string("Ane Solberg"))

        let chatStartResponse = try await context.porthole.set(
            keypath: "matchmakingSnapshot.dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("discovery.startChatWithFocusedPerson"),
                "payload": ValueType.bool(true)
            ]),
            requester: context.owner
        )
        guard let chatStartResponse else {
            XCTFail("Start chat action returned nil response")
            return
        }
        let chatStartFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: chatStartResponse)
        }
        XCTAssertNil(chatStartFailure)

        let chatActionLabel = try await context.porthole.get(
            keypath: "matchmakingSnapshot.state.focusedActions[0].label",
            requester: context.owner
        )
        XCTAssertEqual(chatActionLabel, ValueType.string("Åpne chatflate"))

        let expectedWorkbenchLoad = Task {
            await waitForPortholeLoadBridgeConfiguration(containingName: "Conference Chat")
        }
        let openChatResponse = try await context.porthole.set(
            keypath: "chatSnapshot.dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("openChatWorkbench"),
                "payload": ValueType.object([
                    "displayName": ValueType.string("Ane Solberg"),
                    "subtitle": ValueType.string("Public sector interoperability")
                ])
            ]),
            requester: context.owner
        )
        guard let openChatResponse else {
            XCTFail("Open chat workbench action returned nil response")
            return
        }
        let openChatFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: openChatResponse)
        }
        XCTAssertNil(openChatFailure)

        guard let configuration = await expectedWorkbenchLoad.value else {
            let actionSummaryValue = try? await context.porthole.get(
                keypath: "chatSnapshot.state.actionSummary",
                requester: context.owner
            )
            let statusSummaryValue = try? await context.porthole.get(
                keypath: "chatSnapshot.state.statusSummary",
                requester: context.owner
            )

            XCTFail(
                """
                Expected BindingPortholeLoadBridge request for Conference Chat.
                actionSummary=\(String(describing: actionSummaryValue))
                statusSummary=\(String(describing: statusSummaryValue))
                """
            )
            return
        }
        XCTAssertTrue(configuration.name.contains("Conference Chat"))
        XCTAssertTrue(configuration.cellReferences?.contains(where: { $0.label == "chatSnapshot" }) == true)

        guard let preview = try await context.resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: context.owner
        ) as? Meddle else {
            XCTFail("ConferenceParticipantPreviewShell did not resolve after opening chat workbench")
            return
        }
        guard let chatSnapshot = try await context.resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantChatSnapshot",
            requester: context.owner
        ) as? Meddle else {
            XCTFail("ConferenceParticipantChatSnapshot did not resolve after opening chat workbench")
            return
        }

        let previewState = try await preview.get(keypath: "state", requester: context.owner)
        guard case let .object(previewObject) = previewState,
              case let .object(sharedConnections)? = previewObject["sharedConnections"] else {
            XCTFail("Expected preview state with sharedConnections after opening chat workbench")
            return
        }

        XCTAssertEqual(sharedConnections["connectionSummary"], ValueType.string("1 shared relation(s) visible."))
        XCTAssertEqual(sharedConnections["chatSummary"], ValueType.string("2 shared message(s) visible."))

        let chatState = try await chatSnapshot.get(keypath: "state", requester: context.owner)
        guard case let .object(chatObject) = chatState,
              case let .object(focusedThread)? = chatObject["focusedThread"],
              case let .list(recentMessages)? = chatObject["recentMessages"],
              case let .object(firstRecentMessage)? = recentMessages.first else {
            XCTFail("Expected populated chat snapshot after opening chat workbench")
            return
        }

        XCTAssertEqual(chatObject["selectionSummary"], ValueType.string("Viser den delte tråden med Ane Solberg."))
        XCTAssertEqual(chatObject["personaSummary"], ValueType.string("Ane Solberg · Public sector interoperability"))
        XCTAssertEqual(
            chatObject["simulationSummary"],
            ValueType.string("Demo-svarene holder seg til en bounded persona som representerer offentlig samhandling og governance.")
        )
        XCTAssertEqual(focusedThread["title"], ValueType.string("Ane Solberg"))
        XCTAssertEqual(
            focusedThread["nextMessage"],
            ValueType.string("Hei Ane. Jeg vil gjerne snakke mer om governance-sporet og hvordan du jobber med interoperabilitet i praksis.")
        )
        XCTAssertEqual(
            chatObject["draftMessage"],
            ValueType.string("Hei Ane. Jeg vil gjerne snakke mer om governance-sporet og hvordan du jobber med interoperabilitet i praksis.")
        )
        XCTAssertEqual(firstRecentMessage["title"], ValueType.string("Deg"))

        _ = try await chatSnapshot.set(
            keypath: "setDraftMessage",
            value: .string("Hei Ane.  Jeg vil gjerne snakke mer om governance-sporet etter neste sesjon.  "),
            requester: context.owner
        )

        let draftAfterTyping = try await chatSnapshot.get(keypath: "state", requester: context.owner)
        guard case let .object(draftStateObject) = draftAfterTyping else {
            XCTFail("Expected chat snapshot state after updating draft")
            return
        }
        XCTAssertEqual(
            draftStateObject["draftMessage"],
            ValueType.string("Hei Ane.  Jeg vil gjerne snakke mer om governance-sporet etter neste sesjon.  ")
        )

        let sendResponse = try await chatSnapshot.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("chat.sendDraftMessage"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        guard let sendResponse else {
            XCTFail("Send draft message action returned nil response")
            return
        }
        let sendFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: sendResponse)
        }
        XCTAssertNil(sendFailure)

        let updatedPreviewState = try await preview.get(keypath: "state", requester: context.owner)
        guard case let .object(updatedPreviewObject) = updatedPreviewState,
              case let .object(updatedSharedConnections)? = updatedPreviewObject["sharedConnections"],
              case let .list(updatedMessages)? = updatedSharedConnections["recentMessages"],
              case let .object(latestReply)? = updatedMessages.first,
              case let .object(latestOutgoing)? = updatedMessages.dropFirst().first else {
            XCTFail("Expected populated shared chat messages after sending custom draft")
            return
        }

        XCTAssertEqual(updatedSharedConnections["chatSummary"], ValueType.string("4 shared message(s) visible."))
        XCTAssertEqual(latestReply["title"], ValueType.string("Ane Solberg"))
        XCTAssertEqual(
            latestReply["detail"],
            ValueType.string("Ja, governance er fortsatt mest relevant for meg. Hvis du vil, kan vi gjøre det konkret og se på neste steg rett etter sesjonen.")
        )
        XCTAssertEqual(latestOutgoing["title"], ValueType.string("Deg"))
        XCTAssertEqual(
            latestOutgoing["detail"],
            ValueType.string("Hei Ane.  Jeg vil gjerne snakke mer om governance-sporet etter neste sesjon.")
        )

        let updatedChatState = try await chatSnapshot.get(keypath: "state", requester: context.owner)
        guard case let .object(updatedChatObject) = updatedChatState else {
            XCTFail("Expected updated chat snapshot state after sending custom draft")
            return
        }
        XCTAssertEqual(updatedChatObject["draftMessage"], ValueType.string(""))
        XCTAssertEqual(
            updatedChatObject["chatSummary"],
            ValueType.string("4 meldinger synlige i tråden med Ane Solberg, eldste først.")
        )

        let expectedPortalPop = Task {
            await waitForConferenceNavigationPopFallbackConfiguration(containingName: "Conference Participant Portal")
        }
        let returnResponse = try await chatSnapshot.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("openParticipantPortalWorkbench"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        guard let returnResponse else {
            XCTFail("Return to participant portal action returned nil response")
            return
        }
        let returnFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: returnResponse)
        }
        XCTAssertNil(returnFailure)

        guard let participantPortalConfiguration = await expectedPortalPop.value else {
            XCTFail("Expected BindingConferenceNavigationBridge pop request for Conference Participant Portal")
            return
        }
        XCTAssertTrue(participantPortalConfiguration.name.contains("Conference Participant Portal"))

        let focusedTitleAfterReturn = try await context.porthole.get(
            keypath: "matchmakingSnapshot.state.focusedProfile.title",
            requester: context.owner
        )
        XCTAssertEqual(focusedTitleAfterReturn, ValueType.string("Ane Solberg"))
    }

    func testConferenceParticipantChatWorkbenchWarmsThreadFromSelectedParticipant() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )
        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        _ = try await context.porthole.set(
            keypath: "matchmakingSnapshot.dispatchAction",
            value: .object([
                "keypath": .string("matchmaking.focusPerson"),
                "payload": .object([
                    "displayName": .string("Ane Solberg"),
                    "subtitle": .string("Public sector interoperability")
                ])
            ]),
            requester: context.owner
        )

        let expectedWorkbenchLoad = Task {
            await waitForPortholeLoadBridgeConfiguration(containingName: "Conference Chat")
        }
        let openChatResponse = try await context.porthole.set(
            keypath: "chatSnapshot.dispatchAction",
            value: .object([
                "keypath": .string("openChatWorkbench"),
                "payload": .object([
                    "displayName": .string("Ane Solberg"),
                    "subtitle": .string("Public sector interoperability")
                ])
            ]),
            requester: context.owner
        )
        guard let openChatResponse else {
            XCTFail("Open chat workbench action returned nil response")
            return
        }
        let openChatFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: openChatResponse)
        }
        XCTAssertNil(openChatFailure)

        guard let workbenchConfiguration = await expectedWorkbenchLoad.value else {
            let actionSummaryValue = try? await context.porthole.get(
                keypath: "chatSnapshot.state.actionSummary",
                requester: context.owner
            )
            let statusSummaryValue = try? await context.porthole.get(
                keypath: "chatSnapshot.state.statusSummary",
                requester: context.owner
            )
            XCTFail(
                """
                Expected BindingPortholeLoadBridge request for Conference Chat after warming thread.
                actionSummary=\(String(describing: actionSummaryValue))
                statusSummary=\(String(describing: statusSummaryValue))
                """
            )
            return
        }
        XCTAssertTrue(workbenchConfiguration.name.contains("Conference Chat"))

        guard let preview = try await context.resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: context.owner
        ) as? Meddle else {
            XCTFail("ConferenceParticipantPreviewShell did not resolve after warming chat workbench")
            return
        }
        let previewState = try await preview.get(keypath: "state", requester: context.owner)
        guard case let .object(previewObject) = previewState,
              case let .object(sharedConnections)? = previewObject["sharedConnections"] else {
            XCTFail("Expected preview state with sharedConnections after warming chat workbench")
            return
        }

        XCTAssertEqual(sharedConnections["connectionSummary"], ValueType.string("1 shared relation(s) visible."))
        XCTAssertEqual(sharedConnections["chatSummary"], ValueType.string("2 shared message(s) visible."))

        let selectionSummary = try await context.porthole.get(
            keypath: "chatSnapshot.state.selectionSummary",
            requester: context.owner
        )
        XCTAssertEqual(selectionSummary, ValueType.string("Viser den delte tråden med Ane Solberg."))
    }

    func testConferenceDemoLauncherCanOpenIdentityLinkSetup() async throws {
        let configuration = ConfigurationCatalogCell.conferenceDemoLauncherWorkbenchConfiguration()
        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        let expectedIdentityLinkLoad = Task {
            await waitForPortholeLoadBridgeConfiguration(containingName: "Conference Scaffold Setup & Identity Link")
        }
        let openIdentityLinkResponse = try await context.porthole.set(
            keypath: "conferenceDemoLauncher.dispatchAction",
            value: .object([
                "keypath": .string("launcher.openIdentityLink"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        guard let openIdentityLinkResponse else {
            XCTFail("Open identity link action returned nil response")
            return
        }
        let openIdentityLinkFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: openIdentityLinkResponse)
        }
        XCTAssertNil(openIdentityLinkFailure)

        guard let identityLinkConfiguration = await expectedIdentityLinkLoad.value else {
            XCTFail("Expected BindingPortholeLoadBridge request for Conference Scaffold Setup & Identity Link")
            return
        }
        XCTAssertTrue(identityLinkConfiguration.name.contains("Conference Scaffold Setup & Identity Link"))
        XCTAssertTrue(identityLinkConfiguration.cellReferences?.contains(where: { $0.label == "identityLink" }) == true)
    }

    func testConferenceDemoLauncherCanOpenPublicSurfaceAndControlTower() async throws {
        let configuration = ConfigurationCatalogCell.conferenceDemoLauncherWorkbenchConfiguration()
        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        let expectedPublicSurfaceLoad = Task {
            await waitForPortholeLoadBridgeConfiguration(containingName: "Conference Public Surface")
        }
        let openPublicSurfaceResponse = try await context.porthole.set(
            keypath: "conferenceDemoLauncher.dispatchAction",
            value: .object([
                "keypath": .string("launcher.openPublicSurface"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        guard let openPublicSurfaceResponse else {
            XCTFail("Open public surface action returned nil response")
            return
        }
        let openPublicSurfaceFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: openPublicSurfaceResponse)
        }
        XCTAssertNil(openPublicSurfaceFailure)

        guard let publicSurfaceConfiguration = await expectedPublicSurfaceLoad.value else {
            XCTFail("Expected BindingPortholeLoadBridge request for Conference Public Surface")
            return
        }
        XCTAssertTrue(publicSurfaceConfiguration.name.contains("Conference Public Surface"))
        XCTAssertTrue(publicSurfaceConfiguration.cellReferences?.contains(where: { $0.label == "conferencePublicShell" }) == true)

        let expectedControlTowerLoad = Task {
            await waitForPortholeLoadBridgeConfiguration(containingName: "Conference Control Tower")
        }
        let openControlTowerResponse = try await context.porthole.set(
            keypath: "conferenceDemoLauncher.dispatchAction",
            value: .object([
                "keypath": .string("launcher.openControlTower"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        guard let openControlTowerResponse else {
            XCTFail("Open control tower action returned nil response")
            return
        }
        let openControlTowerFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: openControlTowerResponse)
        }
        XCTAssertNil(openControlTowerFailure)

        guard let controlTowerConfiguration = await expectedControlTowerLoad.value else {
            XCTFail("Expected BindingPortholeLoadBridge request for Conference Control Tower")
            return
        }
        XCTAssertTrue(controlTowerConfiguration.name.contains("Conference Control Tower"))
        XCTAssertTrue(controlTowerConfiguration.cellReferences?.contains(where: { $0.label == "conferenceAdminShell" }) == true)
    }

    private func waitForPortholeSkeleton(
        on porthole: OrchestratorCell,
        requester: Identity,
        containing expectedFragments: [String],
        timeout: TimeInterval = 1.5,
        pollInterval: UInt64 = 100_000_000
    ) async throws -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let skeletonValue = try await porthole.get(
                keypath: "skeleton",
                requester: requester
            )
            if case let .string(skeletonString) = skeletonValue,
               expectedFragments.allSatisfy(skeletonString.contains) {
                return skeletonString
            }
            try await Task.sleep(nanoseconds: pollInterval)
        }

        let finalValue = try await porthole.get(
            keypath: "skeleton",
            requester: requester
        )
        if case let .string(skeletonString) = finalValue {
            return skeletonString
        }
        return nil
    }

    private func waitForPortholeLoadBridgeConfiguration(
        containingName expectedNameFragment: String,
        timeout: TimeInterval = 2.0
    ) async -> CellConfiguration? {
        let notificationCenter = NotificationCenter.default
        return await withCheckedContinuation { continuation in
            var token: NSObjectProtocol?
            var didResume = false

            func finish(_ configuration: CellConfiguration?) {
                guard !didResume else { return }
                didResume = true
                if let token {
                    notificationCenter.removeObserver(token)
                }
                continuation.resume(returning: configuration)
            }

            let deadline = DispatchTime.now() + timeout

            token = notificationCenter.addObserver(
                forName: BindingPortholeLoadBridge.notificationName,
                object: nil,
                queue: nil
            ) { notification in
                guard let configuration = BindingPortholeLoadBridge.configuration(from: notification) else {
                    return
                }
                guard configuration.name.contains(expectedNameFragment) else {
                    return
                }
                finish(configuration)
            }

            DispatchQueue.main.asyncAfter(deadline: deadline) {
                finish(nil)
            }
        }
    }

    private func waitForConferenceNavigationPopFallbackConfiguration(
        containingName expectedNameFragment: String,
        timeout: TimeInterval = 2.0
    ) async -> CellConfiguration? {
        let notificationCenter = NotificationCenter.default
        return await withCheckedContinuation { continuation in
            var token: NSObjectProtocol?
            var didResume = false

            func finish(_ configuration: CellConfiguration?) {
                guard !didResume else { return }
                didResume = true
                if let token {
                    notificationCenter.removeObserver(token)
                }
                continuation.resume(returning: configuration)
            }

            let deadline = DispatchTime.now() + timeout

            token = notificationCenter.addObserver(
                forName: BindingConferenceNavigationBridge.notificationName,
                object: nil,
                queue: nil
            ) { notification in
                guard BindingConferenceNavigationBridge.isPopRequest(notification),
                      let configuration = BindingConferenceNavigationBridge.fallbackConfiguration(from: notification),
                      configuration.name.contains(expectedNameFragment) else {
                    return
                }
                finish(configuration)
            }

            DispatchQueue.main.asyncAfter(deadline: deadline) {
                finish(nil)
            }
        }
    }

#if canImport(AppKit)
    @MainActor
    func testConferenceParticipantPortalRenderer() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "Conference Participant Portal",
                "Entity Discovery",
                "Start scanner",
                "Match nå",
                "Radar i siden",
                "Åpne full radar",
                "Visning nå",
                "Fokus nå"
            ]
        )

        XCTAssertGreaterThan(report.snapshotByteCount, 0, "Expected rendered snapshot bytes")
        XCTAssertGreaterThan(report.subviewCount, 0, "Expected rendered subviews")
        XCTAssertGreaterThan(report.totalRenderMilliseconds, 0, "Expected positive render duration")
        XCTAssertEqual(report.unavailableNowCount, 0, "Participant-portalen skal ikke rendre utilgjengelighets-tekster i lokal verifier")
    }

    @MainActor
    func testConferenceControlTowerRenderer() async throws {
        let configuration = ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
            endpoint: "cell:///ConferenceAdminPreviewShell"
        )

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "Conference Control Tower",
                "Publish content",
                "Operations & Insights"
            ]
        )

        XCTAssertGreaterThan(report.snapshotByteCount, 0, "Expected rendered snapshot bytes")
        XCTAssertGreaterThan(report.subviewCount, 0, "Expected rendered subviews")
        XCTAssertGreaterThan(report.totalRenderMilliseconds, 0, "Expected positive render duration")
        XCTAssertEqual(report.unavailableNowCount, 0, "Control tower skal ikke rendre utilgjengelighets-tekster i lokal verifier")
    }

    @MainActor
    func testConferenceNearbyRadarRenderer() async throws {
        let configuration = ConfigurationCatalogCell.conferenceNearbyRadarWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "Conference Nearby Radar · Full oversikt",
                "Start scanner",
                "Match nå",
                "Tilbake til portalen",
                "Valgt deltager"
            ]
        )

        XCTAssertGreaterThan(report.snapshotByteCount, 0, "Expected rendered snapshot bytes")
        XCTAssertGreaterThan(report.subviewCount, 0, "Expected rendered subviews")
        XCTAssertGreaterThan(report.totalRenderMilliseconds, 0, "Expected positive render duration")
    }

    @MainActor
    func testConferenceNearbyParticipantProfileRenderer() async throws {
        let configuration = ConfigurationCatalogCell.conferenceNearbyParticipantWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "Valgt deltager · profilflate",
                "Match nå",
                "Åpne full radar",
                "Tilbake til portalen",
                "Neste steg"
            ]
        )

        XCTAssertGreaterThan(report.snapshotByteCount, 0, "Expected rendered snapshot bytes")
        XCTAssertGreaterThan(report.subviewCount, 0, "Expected rendered subviews")
        XCTAssertGreaterThan(report.totalRenderMilliseconds, 0, "Expected positive render duration")
    }

    @MainActor
    func testConferenceParticipantChatRenderer() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantChatWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "Conference Chat · Oppfølging",
                "Conference chat · oppfølging",
                "Delte tråder",
                "Demo-deltager",
                "Samtalen nå",
                "Skriv melding",
                "Send melding",
                "Meldinger i tråden",
                "Tilbake til portalen"
            ]
        )

        XCTAssertGreaterThan(report.snapshotByteCount, 0, "Expected rendered snapshot bytes")
        XCTAssertGreaterThan(report.subviewCount, 0, "Expected rendered subviews")
        XCTAssertGreaterThan(report.totalRenderMilliseconds, 0, "Expected positive render duration")
    }
#endif
}
