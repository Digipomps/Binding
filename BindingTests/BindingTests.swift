//
//  BindingTests.swift
//  BindingTests
//
//  Created by Kjetil Hustveit on 16/12/2025.
//

import Foundation
import Testing
import CellBase
@testable import CellApple
@testable import Binding

@Suite(.serialized)
struct BindingTests {

    @Test func componentMergeReusesExistingReferenceLabelAndRewritesFragmentKeypaths() {
        let recipe = ComponentPaletteCatalog.embeddedChatCard(endpoint: "cell:///Chat").recipe
        let existingReferences = [CellReference(endpoint: "cell:///Chat", label: "teamChat")]

        let mergeResult = ReferenceMergeService.merge(
            recipeReferences: recipe.referenceTemplate,
            into: existingReferences,
            fragment: recipe.skeletonTemplate
        )

        #expect(mergeResult.mergedReferences.count == 1)
        #expect(mergeResult.mergedReferences.first?.label == "teamChat")
        #expect(skeletonContainsTextArea(targetKeypath: "teamChat.compose.body", in: mergeResult.rewrittenFragment))
        #expect(!skeletonContainsTextArea(targetKeypath: "chat.compose.body", in: mergeResult.rewrittenFragment))
        #expect(skeletonContainsList(keypath: "teamChat.messages", topic: nil, in: mergeResult.rewrittenFragment))
    }

    @Test func componentMergeRewritesListSelectionKeypathsForAssistantComponent() {
        var suggestionList = SkeletonList(topic: "catalog.matching.suggestions", keypath: nil, flowElementSkeleton: nil)
        suggestionList.selectionMode = .single
        suggestionList.selectionPayloadMode = .itemID
        suggestionList.selectionValueKeypath = "rank"
        suggestionList.selectionStateKeypath = "catalog.matching.selectedIndex"
        suggestionList.selectionActionKeypath = "catalog.matching.selectedIndex"
        suggestionList.activationActionKeypath = "catalog.matching.loadSelectedToPorthole"

        let mergeResult = ReferenceMergeService.merge(
            recipeReferences: [CellReference(endpoint: "cell:///ConfigurationCatalog", label: "catalog")],
            into: [CellReference(endpoint: "cell:///ConfigurationCatalog", label: "assistantCatalog")],
            fragment: .List(suggestionList)
        )

        guard case let .List(rewrittenList) = mergeResult.rewrittenFragment else {
            Issue.record("Forventet list-fragment etter merge")
            return
        }

        #expect(rewrittenList.topic == "assistantCatalog.matching.suggestions")
        #expect(rewrittenList.selectionStateKeypath == "assistantCatalog.matching.selectedIndex")
        #expect(rewrittenList.selectionActionKeypath == "assistantCatalog.matching.selectedIndex")
        #expect(rewrittenList.activationActionKeypath == "assistantCatalog.matching.loadSelectedToPorthole")
    }

    @Test func referenceUsageAnalyzerCountsListSelectionKeypathsAsReferenceUsage() {
        var suggestionList = SkeletonList(topic: nil, keypath: nil, flowElementSkeleton: nil)
        suggestionList.selectionMode = .single
        suggestionList.selectionPayloadMode = .itemID
        suggestionList.selectionValueKeypath = "rank"
        suggestionList.selectionStateKeypath = "catalog.matching.selectedIndex"
        suggestionList.selectionActionKeypath = "catalog.matching.selectedIndex"
        suggestionList.activationActionKeypath = "catalog.matching.loadSelectedToPorthole"

        let report = ReferenceUsageAnalyzer.analyze(
            skeleton: .List(suggestionList),
            references: [CellReference(endpoint: "cell:///ConfigurationCatalog", label: "catalog")]
        )

        #expect(report.referencedLabels == ["catalog"])
        #expect(report.unusedTopLevelLabels.isEmpty)
    }

    @Test func componentPaletteOffersChatVaultAndAssistantWidgets() {
        let ids = Set(ComponentPaletteCatalog.defaultItems().map(\.id))
        #expect(ids.contains("chat.embedded.card"))
        #expect(ids.contains("vault.embedded.snapshot"))
        #expect(ids.contains("catalog.embedded.purposeAssistant"))
    }

    @Test func libraryEmbeddedComponentFallsBackToEditorContainersWhenCatalogKindsAreExternal() {
        var configuration = CellConfiguration(name: "Vault Compact")
        configuration.description = "Embedded vault snapshot"
        configuration.addReference(CellReference(endpoint: "cell:///Vault", label: "vault"))
        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "vault.summary.title"))
        ]))

        let component = ComponentPaletteCatalog.libraryEmbeddedComponent(
            configuration: configuration,
            displayName: "Vault Compact",
            summary: "Embedded vault snapshot",
            supportedTargetKinds: ["menu", "porthole", "library"]
        )

        #expect(component?.sourceKind == .library)
        #expect(component?.recipe.supportedTargetKinds == ["root", "vstack", "section", "scrollview", "grid"])
        #expect(component?.recipe.referenceTemplate.first?.endpoint == "cell:///Vault")
    }

    @Test func libraryEmbeddedComponentReturnsNilWithoutSkeleton() {
        var configuration = CellConfiguration(name: "Agent Shell")
        configuration.description = "No skeleton yet"
        configuration.skeleton = nil
        configuration.addReference(CellReference(endpoint: "cell:///ConfigurationCatalog", label: "catalog"))

        let component = ComponentPaletteCatalog.libraryEmbeddedComponent(
            configuration: configuration,
            displayName: "Agent Shell",
            summary: "No skeleton yet",
            supportedTargetKinds: ["root"]
        )

        #expect(component == nil)
    }

    @MainActor
    @Test func editorAppliesPreferredChatComponentIntoSelectedContainer() {
        let recipe = ComponentPaletteCatalog.defaultItems()[0].recipe
        var configuration = CellConfiguration(name: "Host")
        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(text: "Host"))
        ]))

        let editorState = EditorState()
        editorState.beginEditing(configuration: configuration)

        #expect(editorState.applyPreferredComponent(recipe))
        #expect(editorState.selectedNodePath == .root.appending(1))

        guard let workingSkeleton = editorState.workingCopy else {
            Issue.record("Forventet working skeleton etter component insert")
            return
        }

        let references = editorState.workingConfiguration?.cellReferences ?? []
        #expect(references.contains(where: { $0.endpoint == "cell://staging.haven.digipomps.org/Chat" && $0.label == "chat" }))
        #expect(skeletonContainsTextArea(targetKeypath: "chat.compose.body", in: workingSkeleton))
        #expect(skeletonContainsList(keypath: "chat.messages", topic: nil, in: workingSkeleton))
    }

    @Test func localOnlyCellsAreNotRetargetedToStaging() {
        let contentView = ContentView()

        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///EntityScanner") == "cell:///EntityScanner")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///AppleIntelligence") == "cell:///AppleIntelligence")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///Chat") == "cell://staging.haven.digipomps.org/Chat")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///ConferenceParticipantPreviewShell") == "cell://staging.haven.digipomps.org/ConferenceParticipantPreviewShell")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///AIGateway") == "cell://staging.haven.digipomps.org/AIGateway")
    }

    @Test func fullLibraryCanPreferRemoteCatalogEndpointsBeforeLocalFallback() {
        let ordered = RemoteCatalogSupport.orderedCatalogCandidateEndpoints(from: [
            "cell:///ConfigurationCatalog",
            "cell://staging.haven.digipomps.org/ConfigurationCatalog"
        ], preference: .preferRemote)

        #expect(ordered == [
            "cell://staging.haven.digipomps.org/ConfigurationCatalog",
            "cell:///ConfigurationCatalog"
        ])
    }

    @Test func fullLibraryPrefersLocalCatalogWhenPolicyAllowsCache() {
        let ordered = RemoteCatalogSupport.orderedCatalogCandidateEndpoints(from: [
            "cell:///ConfigurationCatalog",
            "cell://staging.haven.digipomps.org/ConfigurationCatalog"
        ], preference: .preferLocal)

        #expect(ordered == [
            "cell:///ConfigurationCatalog",
            "cell://staging.haven.digipomps.org/ConfigurationCatalog"
        ])
    }

    @Test func fullLibraryAppendsLocalCatalogFallbackWhenOnlyRemoteEndpointsAreProvided() {
        let ordered = RemoteCatalogSupport.orderedCatalogCandidateEndpoints(from: [
            "cell://staging.haven.digipomps.org/ConfigurationCatalog"
        ], preference: .preferRemote)

        #expect(ordered == [
            "cell://staging.haven.digipomps.org/ConfigurationCatalog",
            "cell:///ConfigurationCatalog"
        ])
    }

    @MainActor
    @Test func fullLibrarySummarizesSourceLimitWarningsForHumans() {
        let presentation = FullLibraryViewModel.presentWarnings([
            "cell://staging.haven.digipomps.org/AdminFunding:maxSourcesLimit",
            "cell://staging.haven.digipomps.org/AdminOverview:maxSourcesLimit"
        ])

        #expect(presentation.messages == [
            "2 eksterne kilder ble hoppet over for å holde biblioteket raskt."
        ])
        #expect(presentation.details.count == 2)
    }

    @MainActor
    @Test func fullLibrarySummarizesRemoteFallbackWarningsForHumans() {
        let presentation = FullLibraryViewModel.presentWarnings([
            "Remote tilgang til cell://staging.haven.digipomps.org/ConfigurationCatalog feilet. Fortsetter til neste kilde.",
            "Kilden støtter ikke facetCounts. Viser lokale fasetter for treffene."
        ])

        #expect(presentation.messages == [
            "En ekstern katalogkilde var treg eller utilgjengelig. Biblioteket fortsatte med lokale data.",
            "Filtertellinger er beregnet lokalt for denne visningen."
        ])
    }

    @MainActor
    @Test func fullLibraryPrefersQueryBestMatchForPreviewSelection() {
        let model = FullLibraryViewModel(
            catalogEndpoints: ["cell:///ConfigurationCatalog"],
            queryContext: FullLibraryQueryContext(editMode: false, selectedNodeKind: nil, insertionIntent: .unknown),
            fallbackFavorites: [],
            fallbackTemplates: []
        )
        model.queryText = "control tower"

        let results = [
            FullLibraryViewModel.SearchResult(
                id: "participant",
                configurationId: "participant",
                displayName: "Conference Participant Portal Dashboard",
                summary: "Participant-shell over preview-wrapper.",
                sourceRef: "cell://staging.haven.digipomps.org/ConferenceParticipantPreviewShell",
                route: "directPurpose",
                score: 0.64,
                scoreBreakdown: .init(text: 0.5, purpose: 0.5, interest: 0.5, compatibility: 1.0, connectivity: 1.0, resourceFit: 1.0, recency: 1.0),
                badges: ["conference", "participant"],
                configuration: CellConfiguration(name: "Conference Participant Portal Dashboard"),
                componentItem: nil
            ),
            FullLibraryViewModel.SearchResult(
                id: "control-tower",
                configurationId: "control-tower",
                displayName: "Conference Control Tower",
                summary: "Organizer/admin-shell med drift, innhold og innsikt over staging.",
                sourceRef: "cell://staging.haven.digipomps.org/ConferenceAdminShell",
                route: "directPurpose",
                score: 0.64,
                scoreBreakdown: .init(text: 0.5, purpose: 0.5, interest: 0.5, compatibility: 1.0, connectivity: 1.0, resourceFit: 1.0, recency: 1.0),
                badges: ["conference", "admin"],
                configuration: CellConfiguration(name: "Conference Control Tower"),
                componentItem: nil
            )
        ]

        let preferred = model.preferredSelectionID(in: results, currentSelectionID: "participant")
        #expect(preferred == "control-tower")
    }

    @Test func remoteCatalogSyncRunsOnlyForLocalCatalogEndpoint() {
        #expect(RemoteCatalogSupport.shouldSyncCatalogBeforeQuery(for: "cell:///ConfigurationCatalog"))
        #expect(!RemoteCatalogSupport.shouldSyncCatalogBeforeQuery(for: "cell://staging.haven.digipomps.org/ConfigurationCatalog"))
        #expect(!RemoteCatalogSupport.shouldSyncCatalogBeforeQuery(for: "wss://staging.haven.digipomps.org/bridgehead/ConfigurationCatalog"))
    }

    @Test func remoteCatalogAdmissionRunsOnlyForRemoteCatalogEndpoints() {
        #expect(!RemoteCatalogSupport.shouldAttemptAdmission(for: "cell:///ConfigurationCatalog"))
        #expect(RemoteCatalogSupport.shouldAttemptAdmission(for: "cell://staging.haven.digipomps.org/ConfigurationCatalog"))
        #expect(RemoteCatalogSupport.shouldAttemptAdmission(for: "wss://staging.haven.digipomps.org/bridgehead/ConfigurationCatalog"))
    }

    @Test func remoteMenuRecoverySkipsStagingEndpointsDuringMenuBuild() {
        #expect(RemoteCatalogSupport.shouldEagerlyRecoverMenuEndpoint("cell:///Vault"))
        #expect(!RemoteCatalogSupport.shouldEagerlyRecoverMenuEndpoint("cell://staging.haven.digipomps.org/Vault"))
        #expect(!RemoteCatalogSupport.shouldEagerlyRecoverMenuEndpoint("wss://staging.haven.digipomps.org/bridgehead/Vault"))
    }

    @Test func thinRemoteConfigurationsRecoverOnlyWhenUserActuallyOpensThem() {
        var thinRemoteConfiguration = CellConfiguration(name: "Thin Remote Vault")
        thinRemoteConfiguration.addReference(CellReference(
            endpoint: "cell://staging.haven.digipomps.org/Vault",
            label: "vault"
        ))
        thinRemoteConfiguration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(text: "Vault"))
        ]))

        #expect(RemoteCatalogSupport.shouldRecoverConfigurationOnDemand(thinRemoteConfiguration))

        var dynamicRemoteConfiguration = thinRemoteConfiguration
        dynamicRemoteConfiguration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "vault.summary.title"))
        ]))

        #expect(!RemoteCatalogSupport.shouldRecoverConfigurationOnDemand(dynamicRemoteConfiguration))
    }

    @Test func conferenceShortcutUsesDesignedScrollSurface() {
        let configuration = ConfigurationCatalogCell.conferenceMVPWorkbenchMenuConfiguration(
            endpoint: "cell://staging.haven.digipomps.org/ConferenceUIRouter"
        )

        #expect(configuration.cellReferences?.first?.label == "conferenceUIRouter")
        #expect(configuration.cellReferences?.first?.endpoint == "cell://staging.haven.digipomps.org/ConferenceUIRouter")

        guard case .ScrollView? = configuration.skeleton else {
            Issue.record("Conference MVP should use a designed scroll surface")
            return
        }
    }

    @Test func conferenceAIAssistantWorkbenchSeedsConferenceAndAIGatewayState() {
        let configuration = ConfigurationCatalogCell.conferenceAIAssistantWorkbenchConfiguration(
            conferenceEndpoint: "cell://staging.haven.digipomps.org/ConferenceParticipantPreviewShell",
            aiEndpoint: "cell://staging.haven.digipomps.org/AIGateway"
        )

        #expect(configuration.name == "Conference AI Assistant")
        #expect(configuration.cellReferences?.count == 2)
        #expect(configuration.cellReferences?.first?.label == "conferenceParticipantShell")
        #expect(configuration.cellReferences?.first?.setKeysAndValues.contains(where: { $0.key == "state" }) == true)
        #expect(configuration.cellReferences?.last?.label == "aiGateway")
        #expect(configuration.cellReferences?.last?.endpoint == "cell://staging.haven.digipomps.org/AIGateway")

        guard case .ScrollView? = configuration.skeleton else {
            Issue.record("Conference AI Assistant should use a designed scroll surface")
            return
        }
    }

    @Test func conferenceAdminPublicAndSponsorWorkbenchesSeedStateAndUseScrollSurfaces() {
        let configurations = [
            ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
                endpoint: "cell://staging.haven.digipomps.org/ConferenceAdminShell"
            ),
            ConfigurationCatalogCell.conferencePublicWorkbenchConfiguration(
                endpoint: "cell://staging.haven.digipomps.org/ConferencePublicShell"
            ),
            ConfigurationCatalogCell.conferenceSponsorWorkbenchConfiguration(
                endpoint: "cell://staging.haven.digipomps.org/ConferenceSponsorShell"
            )
        ]

        for configuration in configurations {
            #expect(configuration.cellReferences?.count == 1)
            #expect(configuration.cellReferences?.first?.setKeysAndValues.contains(where: { $0.key == "state" }) == true)

            guard case .ScrollView? = configuration.skeleton else {
                Issue.record("\(configuration.name) should use a designed scroll surface")
                continue
            }
        }
    }

    @Test func conferenceRequesterDescriptorsMatchConferenceShellOwnershipModel() {
        let contentView = ContentView()

        #expect(
            contentView.preferredRequesterDescriptor(
                for: "cell://staging.haven.digipomps.org/ConferenceAdminShell"
            ) == .init(identityContext: "conference-organizer", displayName: "Conference Organizer")
        )
        #expect(
            contentView.preferredRequesterDescriptor(
                for: "cell://staging.haven.digipomps.org/ConferenceUIRouter"
            ) == .init(identityContext: "conference-organizer", displayName: "Conference Organizer")
        )
        #expect(
            contentView.preferredRequesterDescriptor(
                for: "cell://staging.haven.digipomps.org/ConferencePublicShell"
            ) == .init(identityContext: "conference-public-publisher", displayName: "Conference Public Publisher")
        )
        #expect(
            contentView.preferredRequesterDescriptor(
                for: "cell://staging.haven.digipomps.org/ConferenceSponsorShell"
            ) == .init(
                identityContext: "conference-sponsor:sponsor-ai-digital-independence",
                displayName: "sponsor-ai-digital-independence"
            )
        )
    }

    @Test func bindingLocalCellRegistrationMakesConferencePreviewFallbacksReadable() async throws {
        await BindingLocalCellRegistration.shared.ensureRegistered()
        let resolver = CellResolver.sharedInstance
        CellBase.defaultCellResolver = resolver

        let owner = await makeOwnerIdentity()

        guard let participant = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: owner
        ) as? Meddle else {
            Issue.record("Could not resolve local conference participant preview fallback")
            return
        }

        let participantTitle = try await participant.get(
            keypath: "state.workspace.title",
            requester: owner
        )
        #expect(participantTitle == .string("Conference Participant Portal Dashboard"))

        guard let admin = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceAdminPreviewShell",
            requester: owner
        ) as? Meddle else {
            Issue.record("Could not resolve local conference admin preview fallback")
            return
        }

        let adminTitle = try await admin.get(
            keypath: "state.workspace.title",
            requester: owner
        )
        #expect(adminTitle == .string("Conference Control Tower"))
    }

    @Test func conferenceWorkbenchFallsBackToLocalPreviewWhenStagingPreviewIsDenied() {
        let contentView = ContentView()

        let participantConfiguration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell://staging.haven.digipomps.org/ConferenceParticipantPreviewShell"
        )
        let participantFallback = contentView.localConferencePreviewFallbackConfiguration(
            for: participantConfiguration,
            failureDetails: ["denied: preview owner required"]
        )

        #expect(participantFallback?.cellReferences?.first?.endpoint == "cell:///ConferenceParticipantPreviewShell")
        #expect(participantFallback?.discovery?.sourceCellEndpoint == "cell:///ConferenceParticipantPreviewShell")

        let adminConfiguration = ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
            endpoint: "cell://staging.haven.digipomps.org/ConferenceAdminPreviewShell"
        )
        let adminFallback = contentView.localConferencePreviewFallbackConfiguration(
            for: adminConfiguration,
            failureDetails: ["denied: organizer VC required"]
        )

        #expect(adminFallback?.cellReferences?.first?.endpoint == "cell:///ConferenceAdminPreviewShell")
        #expect(adminFallback?.discovery?.sourceCellEndpoint == "cell:///ConferenceAdminPreviewShell")

        let aiAssistantConfiguration = ConfigurationCatalogCell.conferenceAIAssistantWorkbenchConfiguration(
            conferenceEndpoint: "cell://staging.haven.digipomps.org/ConferenceParticipantPreviewShell",
            aiEndpoint: "cell://staging.haven.digipomps.org/AIGateway"
        )
        #expect(
            contentView.localConferencePreviewFallbackConfiguration(
                for: aiAssistantConfiguration,
                failureDetails: ["denied: preview owner required"]
            ) == nil
        )

        #expect(
            contentView.localConferencePreviewFallbackConfiguration(
                for: participantConfiguration,
                failureDetails: ["Timeout ved lasting av conference preview"]
            ) == nil
        )
    }

    @Test func conferenceAdminWorkbenchPrefersOrganizerRequesterDescriptor() {
        let contentView = ContentView()
        let configuration = ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
            endpoint: "cell://staging.haven.digipomps.org/ConferenceAdminShell"
        )

        #expect(
            contentView.preferredRequesterDescriptor(for: configuration)
            == .init(identityContext: "conference-organizer", displayName: "Conference Organizer")
        )
    }

    @Test func mixedConferenceAndAIWorkbenchDoesNotForceSingleSpecialRequester() {
        let contentView = ContentView()
        let configuration = ConfigurationCatalogCell.conferenceAIAssistantWorkbenchConfiguration(
            conferenceEndpoint: "cell://staging.haven.digipomps.org/ConferenceParticipantPreviewShell",
            aiEndpoint: "cell://staging.haven.digipomps.org/AIGateway"
        )

        #expect(contentView.preferredRequesterDescriptor(for: configuration) == nil)
    }

    @Test func validationServiceFlagsUnresolvedSkeletonBindings() {
        var configuration = CellConfiguration(name: "Broken")
        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "ghost.value")),
            .Text(SkeletonText(keypath: "ghost.status"))
        ]))

        let report = CellConfigurationValidationService.validate(configuration)

        #expect(report.errorCount > 0)
        #expect(report.issues.contains(where: { $0.title == "Mangler CellReferences" }))
        #expect(report.issues.contains(where: { $0.title == "Bindings uten matchende reference" }))
    }

    @Test func validationServiceIgnoresDispatchActionPayloadKeypaths() {
        var configuration = CellConfiguration(name: "Dispatch Action")
        configuration.addReference(
            CellReference(
                endpoint: "cell://staging.haven.digipomps.org/ConferenceParticipantPreviewShell",
                label: "conferenceParticipantShell"
            )
        )

        let actionButton = SkeletonButton(
            keypath: "conferenceParticipantShell.dispatchAction",
            label: "Vis for deg",
            payload: .object([
                "keypath": .string("agenda.setView"),
                "payload": .object(["view": .string("forYou")])
            ])
        )

        configuration.skeleton = .VStack(
            SkeletonVStack(elements: [
                .Text(SkeletonText(keypath: "conferenceParticipantShell.state.workspace.title")),
                .Button(actionButton)
            ])
        )

        let report = CellConfigurationValidationService.validate(configuration)

        #expect(!report.issues.contains(where: {
            $0.title == "Bindings uten matchende reference"
        }))
    }

    @Test func skeletonBindingProbeSupportExtractsConferenceParticipantStateRoot() {
        let configuration = makeConferenceParticipantPortalConfiguration()
        let probes = SkeletonBindingProbeSupport.rootProbes(for: configuration)

        #expect(probes.contains(where: {
            $0.label == "conferenceParticipantShell" && $0.rootKeypath == "state"
        }))
    }

    @Test func skeletonBindingProbeSupportSkipsButtonActionKeypaths() {
        var configuration = CellConfiguration(name: "Action Probe")
        configuration.addReference(CellReference(endpoint: "cell:///Chat", label: "chat"))
        configuration.skeleton = .VStack(
            SkeletonVStack(elements: [
                .Text(SkeletonText(keypath: "chat.status")),
                .Button(SkeletonButton(keypath: "chat.dispatchAction", label: "Open"))
            ])
        )

        let probes = SkeletonBindingProbeSupport.rootProbes(for: configuration)

        #expect(probes.contains(where: {
            $0.label == "chat" && $0.rootKeypath == "status"
        }))
        #expect(!probes.contains(where: {
            $0.label == "chat" && $0.rootKeypath == "dispatchAction"
        }))
    }

    @Test func remoteEndpointAccessTreatsStagingCellsAsScaffoldAdmissions() {
        #expect(RemoteEndpointAccessSupport.authorizationKind(for: "cell://staging.haven.digipomps.org/Chat") == .scaffoldAdmission)
        #expect(RemoteEndpointAccessSupport.authorizationKind(for: "wss://staging.haven.digipomps.org/bridgehead/ConfigurationCatalog") == .scaffoldAdmission)
    }

    @Test func stagingWebSocketEndpointsCanonicalizeToBridgeheadRoute() {
        let publishersRoute = RemoteEndpointAccessSupport.canonicalRoute(
            for: "wss://staging.haven.digipomps.org/publishersws/ConferenceUIRouter"
        )
        let bridgeheadRoute = RemoteEndpointAccessSupport.canonicalRoute(
            for: "wss://staging.haven.digipomps.org/bridgehead/ConferenceUIRouter"
        )

        #expect(publishersRoute?.websocketEndpoint == "bridgehead")
        #expect(bridgeheadRoute?.websocketEndpoint == "bridgehead")
    }

    @Test func remoteEndpointAccessTreatsLoopbackBridgeheadAsLiveControlAgreement() {
        #expect(RemoteEndpointAccessSupport.authorizationKind(for: "ws://127.0.0.1:43110/bridgehead/agent/identity") == .liveControlAgreement)
        #expect(RemoteEndpointAccessSupport.authorizationKind(for: "ws://localhost:43110/bridgehead") == .liveControlAgreement)
    }

    @Test func remoteEndpointAccessLeavesLocalCellsUnmanaged() {
        #expect(RemoteEndpointAccessSupport.authorizationKind(for: "cell:///ConfigurationCatalog") == .none)
        #expect(RemoteEndpointAccessSupport.authorizationKind(for: "cell:///Perspective") == .none)
    }

    @Test func entityScannerWorkbenchConfigurationsStayLocalToBinding() {
        let configurations = [
            ConfigurationCatalogCell.entityScannerWorkbenchConfiguration(),
            ConfigurationCatalogCell.entityScannerTestHelperConfiguration(),
            ConfigurationCatalogCell.entityScannerPairingChecklistConfiguration()
        ]

        for configuration in configurations {
            let references = configuration.cellReferences ?? []
            #expect(references.contains(where: { $0.endpoint == "cell:///EntityScanner" }))
            #expect(!references.contains(where: { $0.endpoint.contains("staging.haven.digipomps.org/EntityScanner") }))
        }
    }

    @Test func conferenceParticipantPortalWorkbenchIncludesDiscoveryAndLocalScannerEnrichment() {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration()
        let references = configuration.cellReferences ?? []

        #expect(references.contains(where: { $0.label == "conferenceParticipantShell" }))
        #expect(references.contains(where: { $0.label == "nearbyRadar" && $0.endpoint == "cell:///ConferenceNearbyRadar" }))

        guard let skeleton = configuration.skeleton else {
            Issue.record("Conference participant portal mangler skeleton")
            return
        }

        #expect(skeletonContainsTextKeypath("conferenceParticipantShell.state.discovery.status", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceParticipantShell.state.discovery.nextAction", in: skeleton))
        #expect(skeletonContainsTextKeypath("nearbyRadar.state.summary", in: skeleton))
        #expect(skeletonContainsTextKeypath("nearbyRadar.state.actionSummary", in: skeleton))
        #expect(skeletonContainsButton(keypath: "nearbyRadar.dispatchAction", in: skeleton))
        #expect(skeletonContainsButton(keypath: "dispatchAction", in: skeleton))
        #expect(skeletonContainsTextKeypath("purposeSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("purposeDetail", in: skeleton))
        #expect(skeletonContainsGrid(keypath: "conferenceParticipantShell.state.discovery.candidates", in: skeleton))
        #expect(skeletonContainsReference(keypath: "nearbyRadar", topic: "nearbyRadar.snapshot", in: skeleton))
    }

    @Test func conferenceParticipantPortalRepairRestoresNearbyRadarDispatchWiring() {
        var staleConfiguration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )
        staleConfiguration.cellReferences?.removeAll { $0.label == "nearbyRadar" }

        let repaired = BindingConferenceConfigurationRepair.updatedConfigurationIfNeeded(staleConfiguration)

        #expect(repaired != nil)
        #expect(repaired?.cellReferences?.contains(where: {
            $0.label == "nearbyRadar" && $0.endpoint == "cell:///ConferenceNearbyRadar"
        }) == true)

        guard let skeleton = repaired?.skeleton else {
            Issue.record("Expected repaired conference participant portal skeleton")
            return
        }

        #expect(skeletonContainsButton(keypath: "nearbyRadar.dispatchAction", in: skeleton))
        #expect(skeletonContainsReference(keypath: "nearbyRadar", topic: "nearbyRadar.snapshot", in: skeleton))
    }

    @Test func bindingLocalCellRegistrationMakesConferenceNearbyRadarReadable() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after app initialization")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Missing private identity")
            return
        }
        guard let radar = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceNearbyRadar",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceNearbyRadar did not resolve as Meddle")
            return
        }

        let stateValue = try await radar.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue else {
            Issue.record("Expected object from ConferenceNearbyRadar.state, got \(stateValue)")
            return
        }

        #expect(object["summary"] != nil)
        #expect(object["precisionSummary"] != nil)
        #expect(object["actionSummary"] != nil)
        #expect(object["sectors"] != nil)
        #expect(object["nearby"] != nil)
    }

    @Test func bindingLaunchWarmupMakesConferenceNearbyRadarReadable() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault

        await BindingLaunchWarmup.preloadLocalRuntime()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after launch warmup")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Missing private identity")
            return
        }
        guard let radar = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceNearbyRadar",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceNearbyRadar did not resolve as Meddle after launch warmup")
            return
        }

        let stateValue = try await radar.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue else {
            Issue.record("Expected object from ConferenceNearbyRadar.state after launch warmup, got \(stateValue)")
            return
        }

        #expect(object["summary"] != nil)
        #expect(object["precisionSummary"] != nil)
        #expect(object["actionSummary"] != nil)
    }

    @Test func conferenceNearbyRadarDispatchActionReturnsSnapshotObject() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await BindingLaunchWarmup.preloadLocalRuntime()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after launch warmup")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Missing private identity")
            return
        }
        guard let radar = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceNearbyRadar",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceNearbyRadar did not resolve as Meddle")
            return
        }

        let response = try await radar.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("start"),
                "payload": .bool(true)
            ]),
            requester: identity
        )

        guard case let .object(object) = response else {
            Issue.record("Expected snapshot object from ConferenceNearbyRadar.dispatchAction, got \(response)")
            return
        }

        #expect(object["summary"] != nil)
        #expect(object["actionSummary"] != nil)
    }

    @Test func portholeRoutesNearbyRadarDispatchActionForConferenceParticipantPortal() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await BindingLaunchWarmup.preloadLocalRuntime()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after launch warmup")
            return
        }
        guard let owner = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Missing private identity")
            return
        }
        guard let porthole = try await resolver.cellAtEndpoint(
            endpoint: "cell:///Porthole",
            requester: owner
        ) as? OrchestratorCell else {
            Issue.record("Could not resolve Porthole")
            return
        }

        porthole.detachAll(requester: owner)

        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )
        try await porthole.loadCellConfiguration(configuration, requester: owner)

        let beforeSummary = try await porthole.get(
            keypath: "nearbyRadar.state.actionSummary",
            requester: owner
        )
        #expect(beforeSummary == .string("Nearby radar is ready. Request contact to unlock verified purpose and interest matching."))

        let response = try await porthole.set(
            keypath: "nearbyRadar.dispatchAction",
            value: .object([
                "keypath": .string("start"),
                "payload": .bool(true)
            ]),
            requester: owner
        )

        guard case let .object(snapshot) = response else {
            Issue.record("Expected snapshot object from Porthole nearbyRadar.dispatchAction, got \(response)")
            return
        }

        #expect(snapshot["summary"] != nil)
        #expect(snapshot["actionSummary"] != nil)

        let afterSummary = try await porthole.get(
            keypath: "nearbyRadar.state.actionSummary",
            requester: owner
        )
        guard case let .string(afterSummaryText) = afterSummary else {
            Issue.record("Expected string action summary after dispatch through Porthole")
            return
        }
        #expect(afterSummaryText.contains("Starting scanner") || afterSummaryText.contains("Scanner started"))
    }

    @Test func conferenceNearbyFollowUpSupportBuildsDiscoveryPayloadFromVerifiedEncounter() {
        let encounter: Object = [
            "remoteIdentityUUID": .string("identity-remote-123"),
            "remoteDisplayName": .string("Nora Berg"),
            "remotePerspective": .object([
                "identityProfile": .object([
                    "state": .object([
                        "participantId": .string("participant-102"),
                        "name": .string("Nora Berg"),
                        "company": .string("Polar Systems"),
                        "role": .string("speaker")
                    ])
                ])
            ])
        ]

        let target = ConferenceNearbyFollowUpSupport.target(
            from: encounter,
            fallbackRemoteUUID: "remote-session-abc",
            fallbackDisplayName: "Fallback Name"
        )

        #expect(target.remoteUUID == "remote-session-abc")
        #expect(target.participantId == "participant-102")
        #expect(target.identityUUID == "identity-remote-123")
        #expect(target.displayName == "Nora Berg")
        #expect(target.company == "Polar Systems")
        #expect(target.role == "speaker")

        let payload = ConferenceNearbyFollowUpSupport.discoveryPayload(for: target, source: "nearby-verified-contact")

        #expect(payload["source"] == .string("nearby-verified-contact"))
        #expect(payload["displayName"] == .string("Nora Berg"))
        #expect(payload["company"] == .string("Polar Systems"))
        #expect(payload["role"] == .string("speaker"))

        guard case let .list(participantIds)? = payload["participantIds"] else {
            Issue.record("Expected participantIds in discovery payload")
            return
        }
        #expect(participantIds == [.string("participant-102")])

        guard case let .list(identityUUIDs)? = payload["identityUUIDs"] else {
            Issue.record("Expected identityUUIDs in discovery payload")
            return
        }
        #expect(identityUUIDs == [.string("identity-remote-123")])

        guard case let .list(targets)? = payload["targets"],
              case let .object(firstTarget)? = targets.first else {
            Issue.record("Expected targets in discovery payload")
            return
        }
        #expect(firstTarget["participantId"] == .string("participant-102"))
        #expect(firstTarget["displayName"] == .string("Nora Berg"))
        #expect(firstTarget["company"] == .string("Polar Systems"))
        #expect(firstTarget["role"] == .string("speaker"))
        #expect(firstTarget["identityUUID"] == .string("identity-remote-123"))
    }

    @Test func conferenceParticipantPreviewFallbackSupportsNearbyDiscoveryChat() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after app initialization")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Missing private identity")
            return
        }
        guard let preview = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantPreviewShell did not resolve as Meddle")
            return
        }

        let dispatchPayload: Object = [
            "keypath": .string("discovery.startChat"),
            "payload": .object([
                "source": .string("nearby-verified-contact"),
                "participantIds": .list([.string("participant-102")]),
                "targets": .list([
                    .object([
                        "participantId": .string("participant-102"),
                        "displayName": .string("Nora Berg"),
                        "company": .string("Polar Systems"),
                        "role": .string("speaker")
                    ])
                ])
            ])
        ]

        _ = try await preview.set(keypath: "dispatchAction", value: .object(dispatchPayload), requester: identity)
        let stateValue = try await preview.get(keypath: "state", requester: identity)
        guard case let .object(stateObject) = stateValue,
              case let .object(workspace)? = stateObject["workspace"],
              case let .object(sharedConnections)? = stateObject["sharedConnections"] else {
            Issue.record("Expected state object from conference participant preview fallback")
            return
        }

        #expect(workspace["nextStep"] == .string("Startet oppfølgingschat med Nora Berg i lokal preview."))
        #expect(sharedConnections["chatSummary"] == .string("3 aktive oppfølgingstråder er klare."))

        guard case let .list(connections)? = sharedConnections["connections"] else {
            Issue.record("Expected shared connections list")
            return
        }
        #expect(connections.count == 3)

        guard case let .list(recentMessages)? = sharedConnections["recentMessages"],
              case let .object(firstMessage)? = recentMessages.first else {
            Issue.record("Expected recent messages list")
            return
        }
        #expect(firstMessage["detail"] == .string("Nearby follow-up med Nora Berg er klar i discovery chat."))
    }

    @Test func conferenceParticipantPortalDashboardIsWrappedInScrollView() {
        var configuration = CellConfiguration(name: "Conference Participant Portal Dashboard")
        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(text: "Hero"))
        ]))

        let adjusted = ConfigurationPresentationSupport.viewportSafeConfiguration(configuration)

        guard case let .ScrollView(scroll)? = adjusted.skeleton else {
            Issue.record("Forventet ScrollView-wrapper for conference dashboard")
            return
        }

        #expect(scroll.axis == "vertical")
        #expect(scroll.elements.count == 1)
    }

    @Test func unrelatedConfigurationsKeepOriginalSkeletonShape() {
        var configuration = CellConfiguration(name: "Agent Setup Workbench")
        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(text: "Agent"))
        ]))

        let adjusted = ConfigurationPresentationSupport.viewportSafeConfiguration(configuration)

        guard case .VStack? = adjusted.skeleton else {
            Issue.record("Urelatert konfigurasjon skulle ikke blitt scroll-wrappet")
            return
        }
    }

    @Test func appleIntelligencePurposeMatcherUsesPickerForSuggestionSelection() {
        let configuration = ConfigurationCatalogCell.appleIntelligenceLandingConfiguration()

        guard let skeleton = configuration.skeleton else {
            Issue.record("Forventet skeleton for Apple Intelligence Purpose Matcher")
            return
        }

        #expect(skeletonContainsPicker(
            keypath: "catalog.matching.suggestions",
            selectionStateKeypath: "catalog.matching.state",
            selectionActionKeypath: "catalog.matching.select",
            in: skeleton
        ))
        #expect(!skeletonContainsTextField(targetKeypath: "catalog.matching.selectedIndex", in: skeleton))
    }

    @MainActor
    @Test func deletingComponentPrunesNewlyUnusedReferences() {
        var configuration = CellConfiguration(name: "Delete Chat Component")
        configuration.addReference(CellReference(endpoint: "cell:///Chat", label: "chat"))
        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(text: "Header")),
            .VStack(SkeletonVStack(elements: [
                .Text(SkeletonText(keypath: "chat.status"))
            ]))
        ]))

        let editorState = EditorState()
        editorState.beginEditing(configuration: configuration)
        editorState.deleteNode(at: .root.appending(1))

        let references = editorState.workingConfiguration?.cellReferences ?? []
        #expect(references.isEmpty)

        guard let workingSkeleton = editorState.workingCopy else {
            Issue.record("Forventet skeleton etter delete")
            return
        }

        #expect(!skeletonContainsTextKeypath("chat.status", in: workingSkeleton))
    }

    @Test func configurationCatalogSeedsRichLibrary() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        _ = try await cell.set(keypath: "syncScaffoldPurposeGoals", value: .null, requester: owner)
        let configurations = try await cell.get(keypath: "configurations", requester: owner)
        guard case let .list(items) = configurations else {
            Issue.record("Forventet liste fra configurations")
            return
        }

        #expect(items.count >= 12)
    }

    @Test func configurationCatalogIncludesAgentSetupWorkbench() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        let configurations = try await cell.get(keypath: "configurations", requester: owner)
        guard case let .list(items) = configurations else {
            Issue.record("Forventet liste fra configurations")
            return
        }

        let agentWorkbench = items.compactMap { value -> CellConfiguration? in
            guard case let .cellConfiguration(configuration) = value else { return nil }
            return configuration
        }.first(where: { $0.name == "Agent Setup Workbench" })

        guard let agentWorkbench else {
            Issue.record("Fant ikke Agent Setup Workbench i katalogen")
            return
        }

        #expect(agentWorkbench.cellReferences?.contains(where: { $0.endpoint == "cell:///AgentProvisioning" }) == true)
        #expect(agentWorkbench.cellReferences?.contains(where: { $0.endpoint == "cell:///AgentEnrollment" }) == true)
        #expect(agentWorkbench.cellReferences?.contains(where: { $0.endpoint == "cell:///Perspective" }) == true)
        #expect(agentWorkbench.cellReferences?.contains(where: { $0.endpoint == "cell:///Porthole" }) == true)

        guard let skeleton = agentWorkbench.skeleton else {
            Issue.record("Agent Setup Workbench mangler skeleton")
            return
        }

        #expect(skeletonContainsButton(keypath: "agent.setup.install", in: skeleton))
        #expect(skeletonContainsButton(keypath: "agent.setup.start", in: skeleton))
        #expect(skeletonContainsButton(keypath: "agent.setup.connect", in: skeleton))
        #expect(skeletonContainsButton(keypath: "enrollment.createPairingArtifact", in: skeleton))
        #expect(skeletonContainsButton(keypath: "agent.setup.review.approveSelected", in: skeleton))
        #expect(skeletonContainsButton(keypath: "agent.setup.review.rejectSelected", in: skeleton))
        #expect(skeletonContainsTextField(targetKeypath: "agent.setup.purpose.name", in: skeleton))
        #expect(skeletonContainsTextField(targetKeypath: "agent.setup.review.noteDraft", in: skeleton))
        #expect(skeletonContainsTextKeypath("agent.setup.status.controlBridgeState", in: skeleton))
        #expect(skeletonContainsTextKeypath("agent.setup.status.controlBridgeEndpoint", in: skeleton))
        #expect(skeletonContainsTextKeypath("enrollment.status.summary", in: skeleton))
        #expect(skeletonContainsTextKeypath("enrollment.status.agentIdentityStatus", in: skeleton))
        #expect(skeletonContainsTextKeypath("enrollment.status.starterAuthStatus", in: skeleton))
        #expect(skeletonContainsTextKeypath("enrollment.status.entityLinkStatus", in: skeleton))
        #expect(skeletonContainsList(keypath: "agent.setup.pipeline", topic: nil, in: skeleton))
        #expect(skeletonContainsList(keypath: "agent.setup.review.pending", topic: nil, in: skeleton))
        #expect(skeletonContainsList(keypath: "agent.setup.review.audit", topic: nil, in: skeleton))
    }

    @Test func agentProvisioningCellUsesSingleControlPortholeStrategy() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await AgentProvisioningCell(owner: owner)

        let strategy = try await cell.get(keypath: "agent.setup.status.portholeStrategy", requester: owner)
        guard case let .string(strategyText) = strategy else {
            Issue.record("Forventet streng for portholeStrategy")
            return
        }

        #expect(strategyText.contains("one local control porthole"))
        #expect(strategyText.contains("without a dedicated porthole per connection"))

        let purposeName = try await cell.get(keypath: "agent.setup.purpose.name", requester: owner)
        #expect(purposeName == .string("Operate local HAVEN agent"))

        let reviewSummary = try await cell.get(keypath: "agent.setup.review.selectedSummary", requester: owner)
        #expect(reviewSummary == .string("Select a pending intent to inspect its action, issuer and argument summary."))

        let controlBridgeEndpoint = try await cell.get(keypath: "agent.setup.status.controlBridgeEndpoint", requester: owner)
        #expect(controlBridgeEndpoint == .string("ws://127.0.0.1:43110/bridgehead"))
    }

    @Test func agentEnrollmentCellStartsWithPurposeBoundPairingState() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await AgentEnrollmentCell(owner: owner)

        let summary = try await cell.get(keypath: "enrollment.status.summary", requester: owner)
        guard case let .string(summaryText) = summary else {
            Issue.record("Forventet streng for enrollment summary")
            return
        }

        #expect(summaryText.contains("Waiting for a running agent identity") || summaryText.contains("ready for purpose-bound pairing"))
        #expect(try await cell.get(keypath: "enrollment.status.scaffoldDomain", requester: owner) == .string("staging.haven.digipomps.org"))
        #expect(try await cell.get(keypath: "enrollment.status.purposeRef", requester: owner) == .string("purpose://operate-local-haven-agent"))
        #expect(try await cell.get(keypath: "enrollment.status.starterAuthStatus", requester: owner) == .string("No starter auth materialized yet."))
        #expect(try await cell.get(keypath: "enrollment.status.entityLinkStatus", requester: owner) == .string("No entity-link evidence materialized yet."))
    }

    @Test func configurationCatalogQueryReturnsRankedResults() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        let payload = makeCatalogPayload(
            name: "Prosessmonitor",
            endpoint: "cell:///AdminProcesses",
            insertionMode: "component"
        )
        _ = try await cell.set(keypath: "addConfiguration", value: .object(payload), requester: owner)

        let queryPayload: Object = [
            "requestId": .string("query-test-1"),
            "q": .string("monitor prosesser"),
            "filters": .object([
                "sourceRefs": .list([.string("cell:///AdminProcesses")])
            ]),
            "context": .object([
                "editMode": .bool(true),
                "insertionIntent": .string("component")
            ]),
            "constraints": .object([
                "maxResults": .integer(5),
                "maxSources": .integer(3),
                "latencyBudgetMs": .integer(300)
            ])
        ]
        let response = try await cell.set(keypath: "query", value: .object(queryPayload), requester: owner)
        guard case let .object(result)? = response else {
            Issue.record("Forventet object-respons fra query")
            return
        }

        #expect(result["status"] == .string("ok"))
        if case let .list(results)? = result["results"] {
            #expect(!results.isEmpty)
        } else {
            Issue.record("Mangler results-list i query-respons")
        }
    }

    @Test func configurationCatalogBrowseQueryIncludesConferenceParticipantPortalEvenWithLowSourceLimit() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        let queryPayload: Object = [
            "requestId": .string("query-browse-participant-portal"),
            "q": .string(""),
            "constraints": .object([
                "maxResults": .integer(80),
                "maxSources": .integer(1),
                "latencyBudgetMs": .integer(300)
            ])
        ]

        let response = try await cell.set(keypath: "query", value: .object(queryPayload), requester: owner)
        guard case let .object(result)? = response else {
            Issue.record("Forventet object-respons fra browse query")
            return
        }

        guard case let .list(results)? = result["results"] else {
            Issue.record("Mangler results-list i browse query")
            return
        }

        let names = results.compactMap { value -> String? in
            guard case let .object(object) = value else { return nil }
            guard case let .string(name)? = object["displayName"] else { return nil }
            return name
        }

        #expect(names.contains("Conference Participant Portal Dashboard"))

        if case let .list(warnings)? = result["warnings"] {
            let warningStrings = warnings.compactMap { value -> String? in
                guard case let .string(message) = value else { return nil }
                return message
            }
            #expect(!warningStrings.contains(where: { $0.contains("ConferenceParticipantPreviewShell:maxSourcesLimit") }))
        }
    }

    @Test func configurationCatalogConferenceControlTowerUsesWorkbenchSkeletonForPreviewShell() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        let queryPayload: Object = [
            "requestId": .string("query-control-tower"),
            "q": .string("control tower"),
            "constraints": .object([
                "maxResults": .integer(12),
                "maxSources": .integer(4),
                "latencyBudgetMs": .integer(300)
            ])
        ]

        let response = try await cell.set(keypath: "query", value: .object(queryPayload), requester: owner)
        guard case let .object(result)? = response else {
            Issue.record("Forventet object-respons fra control tower query")
            return
        }

        guard case let .list(results)? = result["results"] else {
            Issue.record("Mangler results-list i control tower query")
            return
        }

        let matchedConfiguration = results.compactMap { value -> CellConfiguration? in
            guard case let .object(object) = value else { return nil }
            guard case let .string(displayName)? = object["displayName"], displayName == "Conference Control Tower" else {
                return nil
            }
            switch object["configuration"] {
            case .cellConfiguration(let configuration):
                return configuration
            case .object(let configurationObject):
                guard let data = try? JSONEncoder().encode(configurationObject) else { return nil }
                return try? JSONDecoder().decode(CellConfiguration.self, from: data)
            default:
                return nil
            }
        }.first

        guard let configuration = matchedConfiguration else {
            Issue.record("Fant ikke Conference Control Tower i query-resultatene")
            return
        }

        let configurationData = try JSONEncoder().encode(configuration)
        let configurationString = String(decoding: configurationData, as: UTF8.self)
        #expect(configuration.discovery?.sourceCellEndpoint == "cell://staging.haven.digipomps.org/ConferenceAdminPreviewShell")
        #expect(configurationString.contains("conferenceAdminShell.state.workspace.title"))
        #expect(configurationString.contains("conferenceAdminShell.state.content.intro"))
    }

    @Test func conferenceAdminPreviewShellUsesOrganizerRequesterDescriptor() async throws {
        let subject = ContentView()
        let descriptor = subject.preferredRequesterDescriptor(
            for: "cell://staging.haven.digipomps.org/ConferenceAdminPreviewShell"
        )

        #expect(descriptor?.identityContext == "conference-organizer")
        #expect(descriptor?.displayName == "Conference Organizer")
    }

    @Test func configurationCatalogFacetCountsIncludesInsertionModes() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        let payload = makeCatalogPayload(
            name: "Prosesskort",
            endpoint: "cell:///AdminProcesses",
            insertionMode: "component"
        )
        _ = try await cell.set(keypath: "addConfiguration", value: .object(payload), requester: owner)

        let facetPayload: Object = [
            "requestId": .string("facet-test-1"),
            "baseQuery": .object([
                "q": .string("prosess"),
                "constraints": .object([
                    "maxSources": .integer(3)
                ])
            ]),
            "facetKeys": .list([.string("supportedInsertionModes")]),
            "maxBucketsPerFacet": .integer(10)
        ]

        let response = try await cell.set(keypath: "facetCounts", value: .object(facetPayload), requester: owner)
        guard case let .object(result)? = response else {
            Issue.record("Forventet object-respons fra facetCounts")
            return
        }
        #expect(result["status"] == .string("ok"))

        guard case let .object(facets)? = result["facets"],
              case let .list(modeBuckets)? = facets["supportedInsertionModes"] else {
            Issue.record("Mangler supportedInsertionModes-facet")
            return
        }

        let hasComponent = modeBuckets.contains { value in
            guard case let .object(bucket) = value else { return false }
            return bucket["value"] == .string("component")
        }
        #expect(hasComponent)
    }

    @Test func portholeAbsorbsCatalogReference() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await AppInitializer.initialize()
        let resolver: CellResolver
        if let existing = CellBase.defaultCellResolver as? CellResolver {
            resolver = existing
        } else {
            resolver = CellResolver.sharedInstance
            CellBase.defaultCellResolver = resolver
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Missing private identity")
            return
        }

        // Binding registers this in BootstrapView, tests need explicit registration.
        try? await resolver.addCellResolve(
            name: "Porthole",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: OrchestratorCell.self
        )
        try? await resolver.addCellResolve(
            name: "ConfigurationCatalog",
            cellScope: .scaffoldUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: ConfigurationCatalogCell.self
        )

        guard let porthole = try await resolver.cellAtEndpoint(endpoint: "cell:///Porthole", requester: identity) as? OrchestratorCell else {
            Issue.record("Could not resolve Porthole")
            return
        }

        porthole.detachAll(requester: identity)

        var config = CellConfiguration(name: "Catalog Absorb Test")
        config.addReference(CellReference(endpoint: "cell:///ConfigurationCatalog", label: "catalog"))

        _ = try await resolver.loadCell(from: config, into: porthole, requester: identity)

        let status = try await porthole.attachedStatus(for: "catalog", requester: identity)
        #expect(status.name == "catalog")
        #expect(status.active)

        let stateValue = try await porthole.get(keypath: "catalog.state", requester: identity)
        guard case .object = stateValue else {
            Issue.record("Expected object from catalog.state, got \(stateValue)")
            return
        }
    }

    @Test func bindingLocalCellRegistrationMakesConfigurationCatalogResolvable() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after app initialization")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Missing private identity")
            return
        }

        let emit = try await resolver.cellAtEndpoint(endpoint: "cell:///ConfigurationCatalog", requester: identity)
        #expect(emit is ConfigurationCatalogCell)
    }

    @Test func bindingLocalConfigurationCatalogServesEntriesAndQueryResults() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after app initialization")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Missing private identity")
            return
        }
        guard let catalog = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConfigurationCatalog",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConfigurationCatalog did not resolve as Meddle")
            return
        }

        let entries = try await catalog.get(keypath: "catalogEntries", requester: identity)
        guard case let .list(entryList) = entries else {
            Issue.record("Expected catalogEntries list, got \(String(describing: entries))")
            return
        }
        #expect(!entryList.isEmpty)

        let queryResponse = try await catalog.set(
            keypath: "query",
            value: .object([
                "q": .string("conference"),
                "constraints": .object([
                    "maxResults": .integer(12)
                ])
            ]),
            requester: identity
        )
        guard case let .object(queryObject) = queryResponse else {
            Issue.record("Expected object query response, got \(String(describing: queryResponse))")
            return
        }
        guard case let .list(resultList)? = queryObject["results"] else {
            Issue.record("Expected query response with results list")
            return
        }
        #expect(!resultList.isEmpty)
    }

    @Test func fullLibraryRefreshCompletesAndYieldsResults() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        let model = await MainActor.run {
            FullLibraryViewModel(
                catalogEndpoints: ["cell:///ConfigurationCatalog"],
                queryContext: FullLibraryQueryContext(
                    editMode: false,
                    selectedNodeKind: nil,
                    insertionIntent: .unknown
                ),
                fallbackFavorites: [],
                fallbackTemplates: []
            )
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                await model.refreshNow()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 4_000_000_000)
                throw CancellationError()
            }

            _ = try await group.next()
            group.cancelAll()
        }

        await MainActor.run {
            #expect(!model.isLoading)
            #expect(model.statusLine != "Laster ConfigurationCatalog...")
            #expect(!model.results.isEmpty)
        }
    }

    @Test func applePortholeLoadCellConfigurationReplacesPreviousReferences() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        await AppInitializer.initialize()
        let resolver: CellResolver
        if let existing = CellBase.defaultCellResolver as? CellResolver {
            resolver = existing
        } else {
            resolver = CellResolver.sharedInstance
            CellBase.defaultCellResolver = resolver
        }

        let owner = await makeOwnerIdentity()

        try? await resolver.addCellResolve(
            name: "Porthole",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: OrchestratorCell.self
        )
        try? await resolver.addCellResolve(
            name: "ConfigurationCatalog",
            cellScope: .scaffoldUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: ConfigurationCatalogCell.self
        )
        try? await resolver.addCellResolve(
            name: "RootOnlyState",
            cellScope: .scaffoldUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: RootOnlyStateCell.self
        )

        guard let porthole = try await resolver.cellAtEndpoint(endpoint: "cell:///Porthole", requester: owner) as? OrchestratorCell else {
            Issue.record("Could not resolve Porthole")
            return
        }

        try await porthole.setCellConfiguration(cellConfig: CellConfiguration(name: "Empty Porthole"))

        var catalogConfiguration = CellConfiguration(name: "Catalog Workspace")
        catalogConfiguration.addReference(CellReference(endpoint: "cell:///ConfigurationCatalog", label: "catalog"))
        try await porthole.loadCellConfiguration(catalogConfiguration, requester: owner)

        var rootStateConfiguration = CellConfiguration(name: "Root State Workspace")
        rootStateConfiguration.addReference(CellReference(endpoint: "cell:///RootOnlyState", label: "rootState"))
        try await porthole.loadCellConfiguration(rootStateConfiguration, requester: owner)

        #expect(porthole.getCellConfiguration()?.name == "Root State Workspace")
        #expect(porthole.getCellConfiguration()?.cellReferences?.map(\.label) == ["rootState"])

        let catalogEmitter = await porthole.getEmitterWithLabel("catalog", requester: owner)
        let rootStateEmitter = await porthole.getEmitterWithLabel("rootState", requester: owner)
        #expect(catalogEmitter == nil)
        #expect(rootStateEmitter != nil)
    }

    @Test func applePortholeLoadCellConfigurationRollsBackOnFailure() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        await AppInitializer.initialize()
        let resolver: CellResolver
        if let existing = CellBase.defaultCellResolver as? CellResolver {
            resolver = existing
        } else {
            resolver = CellResolver.sharedInstance
            CellBase.defaultCellResolver = resolver
        }

        let owner = await makeOwnerIdentity()

        try? await resolver.addCellResolve(
            name: "Porthole",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: OrchestratorCell.self
        )
        try? await resolver.addCellResolve(
            name: "ConfigurationCatalog",
            cellScope: .scaffoldUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: ConfigurationCatalogCell.self
        )

        guard let porthole = try await resolver.cellAtEndpoint(endpoint: "cell:///Porthole", requester: owner) as? OrchestratorCell else {
            Issue.record("Could not resolve Porthole")
            return
        }

        try await porthole.setCellConfiguration(cellConfig: CellConfiguration(name: "Empty Porthole"))

        var validConfiguration = CellConfiguration(name: "Catalog Workspace")
        validConfiguration.addReference(CellReference(endpoint: "cell:///ConfigurationCatalog", label: "catalog"))
        try await porthole.loadCellConfiguration(validConfiguration, requester: owner)

        var invalidConfiguration = CellConfiguration(name: "Broken Workspace")
        invalidConfiguration.addReference(CellReference(endpoint: "cell:///MissingCell", label: "missing"))

        do {
            try await porthole.loadCellConfiguration(invalidConfiguration, requester: owner)
            Issue.record("Expected loadCellConfiguration to fail for missing endpoint")
        } catch {
            // Expected: rollback should restore the previous working configuration.
        }

        #expect(porthole.getCellConfiguration()?.name == "Catalog Workspace")
        #expect(porthole.getCellConfiguration()?.cellReferences?.map(\.label) == ["catalog"])

        let missingEmitter = await porthole.getEmitterWithLabel("missing", requester: owner)
        #expect(missingEmitter == nil)
    }

    @Test func nestedStateLookupFallsBackToRootStateIntercept() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await makeOwnerIdentity()
        let cell = await RootOnlyStateCell(owner: owner)

        let titleValue = try await cell.get(keypath: "state.workspace.title", requester: owner)
        #expect(titleValue == .string("Conference Participant Portal"))

        let sessionValue = try await cell.get(keypath: "state.program.savedSessions[1].title", requester: owner)
        #expect(sessionValue == .string("Shared Relations Roundtable"))
    }

    @Test func portholeResolvesNestedStateKeypathsForAttachedRootOnlyStateCells() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        await AppInitializer.initialize()
        let resolver: CellResolver
        if let existing = CellBase.defaultCellResolver as? CellResolver {
            resolver = existing
        } else {
            resolver = CellResolver.sharedInstance
            CellBase.defaultCellResolver = resolver
        }

        let owner = await makeOwnerIdentity()

        try? await resolver.addCellResolve(
            name: "Porthole",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: OrchestratorCell.self
        )
        try? await resolver.addCellResolve(
            name: "RootOnlyState",
            cellScope: .scaffoldUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: RootOnlyStateCell.self
        )

        guard let porthole = try await resolver.cellAtEndpoint(endpoint: "cell:///Porthole", requester: owner) as? OrchestratorCell else {
            Issue.record("Could not resolve Porthole")
            return
        }

        porthole.detachAll(requester: owner)

        var configuration = CellConfiguration(name: "Root State Portal")
        configuration.addReference(CellReference(endpoint: "cell:///RootOnlyState", label: "rootState"))

        _ = try await resolver.loadCell(from: configuration, into: porthole, requester: owner)

        let titleValue = try await porthole.get(keypath: "rootState.state.workspace.title", requester: owner)
        #expect(titleValue == .string("Conference Participant Portal"))

        let sessionValue = try await porthole.get(
            keypath: "rootState.state.program.savedSessions[0].title",
            requester: owner
        )
        #expect(sessionValue == .string("Opening Keynote"))
    }

    @Test func conferenceParticipantPortalResolvesPreviewWrapperStateKeypathsThroughPorthole() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        await AppInitializer.initialize()
        let resolver: CellResolver
        if let existing = CellBase.defaultCellResolver as? CellResolver {
            resolver = existing
        } else {
            resolver = CellResolver.sharedInstance
            CellBase.defaultCellResolver = resolver
        }

        let owner = await makeOwnerIdentity()

        try? await resolver.addCellResolve(
            name: "Porthole",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: OrchestratorCell.self
        )
        try? await resolver.addCellResolve(
            name: "ConferenceParticipantPreviewShell",
            cellScope: .scaffoldUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: ConferenceParticipantPreviewShellFixtureCell.self
        )

        guard let porthole = try await resolver.cellAtEndpoint(endpoint: "cell:///Porthole", requester: owner) as? OrchestratorCell else {
            Issue.record("Could not resolve Porthole")
            return
        }

        porthole.detachAll(requester: owner)

        let configuration = makeConferenceParticipantPortalConfiguration()
        guard let skeleton = configuration.skeleton else {
            Issue.record("Conference participant portal mangler skeleton")
            return
        }

        #expect(skeletonContainsTextKeypath("conferenceParticipantShell.state.workspace.title", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceParticipantShell.state.program.agendaSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceParticipantShell.state.matches.recommendationSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceParticipantShell.state.meetings.meetingSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceParticipantShell.state.sharedConnections.chatSummary", in: skeleton))
        #expect(skeletonContainsList(keypath: "conferenceParticipantShell.state.program.savedSessions", topic: "conference.agenda.saved", in: skeleton))
        #expect(skeletonContainsList(keypath: "conferenceParticipantShell.state.matches.recommendations", topic: "conference.match.recommendation", in: skeleton))
        #expect(skeletonContainsList(keypath: "conferenceParticipantShell.state.meetings.confirmedMeetings", topic: "conference.meeting.confirmed", in: skeleton))
        #expect(skeletonContainsList(keypath: "conferenceParticipantShell.state.sharedConnections.connections", topic: "conference.shared.connection", in: skeleton))

        try await porthole.loadCellConfiguration(configuration, requester: owner)

        let titleValue = try await porthole.get(keypath: "conferenceParticipantShell.state.workspace.title", requester: owner)
        #expect(titleValue == .string("Conference Participant Portal Dashboard"))

        let agendaSummaryValue = try await porthole.get(
            keypath: "conferenceParticipantShell.state.program.agendaSummary",
            requester: owner
        )
        #expect(agendaSummaryValue == .string("6 sessions saved, 2 focus tracks selected."))

        let recommendationSummaryValue = try await porthole.get(
            keypath: "conferenceParticipantShell.state.matches.recommendationSummary",
            requester: owner
        )
        #expect(recommendationSummaryValue == .string("4 high-signal people recommended for your goals."))

        let meetingSummaryValue = try await porthole.get(
            keypath: "conferenceParticipantShell.state.meetings.meetingSummary",
            requester: owner
        )
        #expect(meetingSummaryValue == .string("3 confirmed meetings and 2 pending requests."))

        let chatSummaryValue = try await porthole.get(
            keypath: "conferenceParticipantShell.state.sharedConnections.chatSummary",
            requester: owner
        )
        #expect(chatSummaryValue == .string("2 active shared threads are ready for follow-up."))

        let savedSessionsValue = try await porthole.get(
            keypath: "conferenceParticipantShell.state.program.savedSessions",
            requester: owner
        )
        guard case let .list(savedSessions) = savedSessionsValue else {
            Issue.record("Expected saved sessions list, got \(savedSessionsValue)")
            return
        }
        #expect(savedSessions.count == 2)

        let recommendationsValue = try await porthole.get(
            keypath: "conferenceParticipantShell.state.matches.recommendations",
            requester: owner
        )
        guard case let .list(recommendations) = recommendationsValue else {
            Issue.record("Expected recommendations list, got \(recommendationsValue)")
            return
        }
        #expect(recommendations.count == 2)

        let confirmedMeetingsValue = try await porthole.get(
            keypath: "conferenceParticipantShell.state.meetings.confirmedMeetings",
            requester: owner
        )
        guard case let .list(confirmedMeetings) = confirmedMeetingsValue else {
            Issue.record("Expected confirmed meetings list, got \(confirmedMeetingsValue)")
            return
        }
        #expect(confirmedMeetings.count == 2)

        let connectionsValue = try await porthole.get(
            keypath: "conferenceParticipantShell.state.sharedConnections.connections",
            requester: owner
        )
        guard case let .list(connections) = connectionsValue else {
            Issue.record("Expected shared connections list, got \(connectionsValue)")
            return
        }
        #expect(connections.count == 2)
    }

    @Test func configurationCatalogRemovesBlockedReferencesWhenOtherReferencesExist() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        var configuration = CellConfiguration(name: "Mixed References")
        configuration.addReference(CellReference(endpoint: "cell:///EventEmitter", label: "signals"))
        configuration.addReference(CellReference(endpoint: "cell:///Chat", label: "chat"))

        let payload: Object = [
            "sourceCellEndpoint": .string("cell:///EventEmitter"),
            "sourceCellName": .string("MixedCell"),
            "purpose": .string("Test blocked filtering"),
            "interests": .list([.string("chat")]),
            "menuSlots": .list([.string("upperLeft")]),
            "configuration": .cellConfiguration(configuration),
            "goal": .cellConfiguration(configuration)
        ]

        _ = try await cell.set(keypath: "addConfiguration", value: .object(payload), requester: owner)

        let entriesValue = try await cell.get(keypath: "catalogEntries", requester: owner)
        guard case let .list(entries) = entriesValue,
              let match = entries.first(where: { value in
                  guard case let .object(object) = value,
                        case let .cellConfiguration(configuration)? = object["configuration"] else {
                      return false
                  }
                  return configuration.name == "Mixed References"
              }),
              case let .object(object) = match,
              case let .cellConfiguration(storedConfiguration)? = object["configuration"],
              let references = storedConfiguration.cellReferences
        else {
            Issue.record("Expected stored catalog entry with configuration references")
            return
        }

        #expect(references.contains(where: { $0.endpoint == "cell:///Chat" }))
        #expect(!references.contains(where: { $0.endpoint.lowercased().contains("eventemitter") }))
    }

    @Test func configurationCatalogRejectsConfigurationsWithOnlyBlockedReferences() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        var configuration = CellConfiguration(name: "Only Blocked")
        configuration.addReference(CellReference(endpoint: "cell:///TimesWrapper", label: "times"))

        let payload: Object = [
            "sourceCellEndpoint": .string("cell:///TimesWrapper"),
            "sourceCellName": .string("TimesOnlyCell"),
            "purpose": .string("Should be rejected"),
            "interests": .list([.string("time")]),
            "menuSlots": .list([.string("upperLeft")]),
            "configuration": .cellConfiguration(configuration),
            "goal": .cellConfiguration(configuration)
        ]

        let response = try await cell.set(keypath: "addConfiguration", value: .object(payload), requester: owner)
        #expect(response == .string("error: invalid payload for addConfiguration"))
    }

    @Test func scaffoldChatConfigurationUsesRichStagingWorkbench() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        _ = try await cell.set(keypath: "syncScaffoldPurposeGoals", value: .null, requester: owner)
        let configurations = try await cell.get(keypath: "configurations", requester: owner)
        guard case let .list(items) = configurations else {
            Issue.record("Forventet liste fra configurations")
            return
        }

        let chatConfiguration = items.compactMap { value -> CellConfiguration? in
            guard case let .cellConfiguration(configuration) = value else { return nil }
            return configuration.name == "Scaffold Chat" ? configuration : nil
        }.first

        guard let chatConfiguration else {
            Issue.record("Fant ikke Scaffold Chat i configurations")
            return
        }

        let endpoints = chatConfiguration.cellReferences?.map(\.endpoint) ?? []
        #expect(endpoints.contains("cell://staging.haven.digipomps.org/Chat"))

        guard let skeleton = chatConfiguration.skeleton else {
            Issue.record("Scaffold Chat mangler skeleton")
            return
        }

        #expect(skeletonContainsTextArea(targetKeypath: "chat.compose.body", in: skeleton))
        #expect(skeletonContainsButton(keypath: "chat.sendComposedMessage", in: skeleton))
        #expect(skeletonContainsList(keypath: "chat.messages", topic: "chat.message", in: skeleton))
        #expect(skeletonContainsList(keypath: "chat.participants", topic: "chat.participant", in: skeleton))
        #expect(skeletonContainsList(keypath: "chat.compose.previewRows", topic: nil, in: skeleton))
        #expect(skeletonContainsTextKeypath("ownerInitials", in: skeleton))
        #expect(skeletonContainsTextKeypath("contentRichText", in: skeleton))
        #expect(skeletonContainsTextKeypath("formatLabel", in: skeleton))
        #expect(skeletonContainsTextKeypath("formatDescription", in: skeleton))
        #expect(skeletonContainsTextKeypath("previewRichText", in: skeleton))
        #expect(skeletonContainsTextKeypath("initials", in: skeleton))
        #expect(skeletonContainsTextKeypath("activitySummary", in: skeleton))
    }

    private func makeOwnerIdentity() async -> Identity {
        CellBase.defaultIdentityVault = Self.testIdentityVault
        return await Self.testIdentityVault.identity(for: "private", makeNewIfNotFound: true)!
    }

    private func makeCatalogPayload(name: String, endpoint: String, insertionMode: String) -> Object {
        var configuration = CellConfiguration(name: name)
        configuration.description = "Testkonfig for query/facet"
        var reference = CellReference(endpoint: endpoint, label: "source")
        reference.setKeysAndValues = [KeyValue(key: "adminProcesses.query", value: .string("top"))]
        configuration.addReference(reference)

        return [
            "sourceCellEndpoint": .string(endpoint),
            "sourceCellName": .string("AdminProcessesCell"),
            "purpose": .string("System monitorering"),
            "purposeDescription": .string("Overvåkning av systemprosesser"),
            "interests": .list([.string("process"), .string("alerts")]),
            "menuSlots": .list([.string("lowerMid")]),
            "categoryPath": .list([.string("ops"), .string("monitoring")]),
            "tags": .list([.string("ops"), .string("monitoring")]),
            "supportedInsertionModes": .list([.string(insertionMode)]),
            "flowDriven": .bool(true),
            "editable": .bool(true),
            "configuration": .cellConfiguration(configuration),
            "goal": .cellConfiguration(configuration)
        ]
    }

    private func makeConferenceParticipantPortalConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Conference Participant Portal Dashboard")
        configuration.description = "Representative portal config using the preview-wrapper state contract."

        var reference = CellReference(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            subscribeFeed: false,
            label: "conferenceParticipantShell"
        )
        reference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(reference)

        var savedSessions = SkeletonList(
            topic: "conference.agenda.saved",
            keypath: "conferenceParticipantShell.state.program.savedSessions",
            flowElementSkeleton: nil
        )
        savedSessions.flowElementSkeleton = SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "title")),
            .Text(SkeletonText(keypath: "subtitle"))
        ])

        var recommendations = SkeletonList(
            topic: "conference.match.recommendation",
            keypath: "conferenceParticipantShell.state.matches.recommendations",
            flowElementSkeleton: nil
        )
        recommendations.flowElementSkeleton = SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "displayName")),
            .Text(SkeletonText(keypath: "headline"))
        ])

        var confirmedMeetings = SkeletonList(
            topic: "conference.meeting.confirmed",
            keypath: "conferenceParticipantShell.state.meetings.confirmedMeetings",
            flowElementSkeleton: nil
        )
        confirmedMeetings.flowElementSkeleton = SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "title")),
            .Text(SkeletonText(keypath: "time"))
        ])

        var sharedConnections = SkeletonList(
            topic: "conference.shared.connection",
            keypath: "conferenceParticipantShell.state.sharedConnections.connections",
            flowElementSkeleton: nil
        )
        sharedConnections.flowElementSkeleton = SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "displayName")),
            .Text(SkeletonText(keypath: "relation"))
        ])

        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "conferenceParticipantShell.state.workspace.title")),
            .Text(SkeletonText(keypath: "conferenceParticipantShell.state.program.agendaSummary")),
            .Text(SkeletonText(keypath: "conferenceParticipantShell.state.matches.recommendationSummary")),
            .Text(SkeletonText(keypath: "conferenceParticipantShell.state.meetings.meetingSummary")),
            .Text(SkeletonText(keypath: "conferenceParticipantShell.state.sharedConnections.chatSummary")),
            .List(savedSessions),
            .List(recommendations),
            .List(confirmedMeetings),
            .List(sharedConnections)
        ]))
        return configuration
    }

    private func skeletonContainsButton(keypath: String, url: String? = nil, in element: SkeletonElement) -> Bool {
        switch element {
        case .Button(let button):
            return button.keypath == keypath && button.url == url
        case .VStack(let stack):
            return stack.elements.contains { skeletonContainsButton(keypath: keypath, url: url, in: $0) }
        case .HStack(let stack):
            return stack.elements.contains { skeletonContainsButton(keypath: keypath, url: url, in: $0) }
        case .ScrollView(let scroll):
            return scroll.elements.contains { skeletonContainsButton(keypath: keypath, url: url, in: $0) }
        case .Section(let section):
            return (section.header.map { skeletonContainsButton(keypath: keypath, url: url, in: $0) } ?? false) ||
                section.content.contains { skeletonContainsButton(keypath: keypath, url: url, in: $0) } ||
                (section.footer.map { skeletonContainsButton(keypath: keypath, url: url, in: $0) } ?? false)
        case .Reference(let reference):
            return reference.flowElementSkeleton.map { skeletonContainsButton(keypath: keypath, url: url, in: .VStack($0)) } ?? false
        case .List(let list):
            return list.flowElementSkeleton.map { skeletonContainsButton(keypath: keypath, url: url, in: .VStack($0)) } ?? false
        case .Grid(let grid):
            return grid.elements.contains { skeletonContainsButton(keypath: keypath, url: url, in: $0) }
        case .ZStack(let stack):
            return stack.elements.contains { skeletonContainsButton(keypath: keypath, url: url, in: $0) }
        case .Object(let object):
            return object.elements.values.contains { skeletonContainsButton(keypath: keypath, url: url, in: $0) }
        default:
            return false
        }
    }

    private func skeletonContainsTextArea(targetKeypath: String, in element: SkeletonElement) -> Bool {
        switch element {
        case .TextArea(let textArea):
            return textArea.targetKeypath == targetKeypath
        case .VStack(let stack):
            return stack.elements.contains { skeletonContainsTextArea(targetKeypath: targetKeypath, in: $0) }
        case .HStack(let stack):
            return stack.elements.contains { skeletonContainsTextArea(targetKeypath: targetKeypath, in: $0) }
        case .ScrollView(let scroll):
            return scroll.elements.contains { skeletonContainsTextArea(targetKeypath: targetKeypath, in: $0) }
        case .Section(let section):
            return (section.header.map { skeletonContainsTextArea(targetKeypath: targetKeypath, in: $0) } ?? false) ||
                section.content.contains { skeletonContainsTextArea(targetKeypath: targetKeypath, in: $0) } ||
                (section.footer.map { skeletonContainsTextArea(targetKeypath: targetKeypath, in: $0) } ?? false)
        case .Reference(let reference):
            return reference.flowElementSkeleton.map { skeletonContainsTextArea(targetKeypath: targetKeypath, in: .VStack($0)) } ?? false
        case .List(let list):
            return list.flowElementSkeleton.map { skeletonContainsTextArea(targetKeypath: targetKeypath, in: .VStack($0)) } ?? false
        case .Grid(let grid):
            return grid.elements.contains { skeletonContainsTextArea(targetKeypath: targetKeypath, in: $0) }
        case .ZStack(let stack):
            return stack.elements.contains { skeletonContainsTextArea(targetKeypath: targetKeypath, in: $0) }
        case .Object(let object):
            return object.elements.values.contains { skeletonContainsTextArea(targetKeypath: targetKeypath, in: $0) }
        default:
            return false
        }
    }

    private func skeletonContainsTextField(targetKeypath: String, in element: SkeletonElement) -> Bool {
        switch element {
        case .TextField(let textField):
            return textField.targetKeypath == targetKeypath
        case .VStack(let stack):
            return stack.elements.contains { skeletonContainsTextField(targetKeypath: targetKeypath, in: $0) }
        case .HStack(let stack):
            return stack.elements.contains { skeletonContainsTextField(targetKeypath: targetKeypath, in: $0) }
        case .ScrollView(let scroll):
            return scroll.elements.contains { skeletonContainsTextField(targetKeypath: targetKeypath, in: $0) }
        case .Section(let section):
            return (section.header.map { skeletonContainsTextField(targetKeypath: targetKeypath, in: $0) } ?? false) ||
                section.content.contains { skeletonContainsTextField(targetKeypath: targetKeypath, in: $0) } ||
                (section.footer.map { skeletonContainsTextField(targetKeypath: targetKeypath, in: $0) } ?? false)
        case .Reference(let reference):
            return reference.flowElementSkeleton.map { skeletonContainsTextField(targetKeypath: targetKeypath, in: .VStack($0)) } ?? false
        case .List(let list):
            return list.flowElementSkeleton.map { skeletonContainsTextField(targetKeypath: targetKeypath, in: .VStack($0)) } ?? false
        case .Grid(let grid):
            return grid.elements.contains { skeletonContainsTextField(targetKeypath: targetKeypath, in: $0) }
        case .ZStack(let stack):
            return stack.elements.contains { skeletonContainsTextField(targetKeypath: targetKeypath, in: $0) }
        case .Object(let object):
            return object.elements.values.contains { skeletonContainsTextField(targetKeypath: targetKeypath, in: $0) }
        default:
            return false
        }
    }

    private func skeletonContainsPicker(
        keypath: String,
        selectionStateKeypath: String,
        selectionActionKeypath: String,
        in element: SkeletonElement
    ) -> Bool {
        switch element {
        case .Picker(let picker):
            return picker.keypath == keypath &&
                picker.selectionStateKeypath == selectionStateKeypath &&
                picker.selectionActionKeypath == selectionActionKeypath
        case .VStack(let stack):
            return stack.elements.contains {
                skeletonContainsPicker(
                    keypath: keypath,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    in: $0
                )
            }
        case .HStack(let stack):
            return stack.elements.contains {
                skeletonContainsPicker(
                    keypath: keypath,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    in: $0
                )
            }
        case .ScrollView(let scroll):
            return scroll.elements.contains {
                skeletonContainsPicker(
                    keypath: keypath,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    in: $0
                )
            }
        case .Section(let section):
            return (section.header.map {
                skeletonContainsPicker(
                    keypath: keypath,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    in: $0
                )
            } ?? false) ||
                section.content.contains {
                    skeletonContainsPicker(
                        keypath: keypath,
                        selectionStateKeypath: selectionStateKeypath,
                        selectionActionKeypath: selectionActionKeypath,
                        in: $0
                    )
                } ||
                (section.footer.map {
                    skeletonContainsPicker(
                        keypath: keypath,
                        selectionStateKeypath: selectionStateKeypath,
                        selectionActionKeypath: selectionActionKeypath,
                        in: $0
                    )
                } ?? false)
        case .Reference(let reference):
            return reference.flowElementSkeleton.map {
                skeletonContainsPicker(
                    keypath: keypath,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    in: .VStack($0)
                )
            } ?? false
        case .List(let list):
            return list.flowElementSkeleton.map {
                skeletonContainsPicker(
                    keypath: keypath,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    in: .VStack($0)
                )
            } ?? false
        case .Grid(let grid):
            return grid.elements.contains {
                skeletonContainsPicker(
                    keypath: keypath,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    in: $0
                )
            }
        case .ZStack(let stack):
            return stack.elements.contains {
                skeletonContainsPicker(
                    keypath: keypath,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    in: $0
                )
            }
        case .Object(let object):
            return object.elements.values.contains {
                skeletonContainsPicker(
                    keypath: keypath,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    in: $0
                )
            }
        default:
            return false
        }
    }

    private func skeletonContainsList(keypath: String, topic: String?, in element: SkeletonElement) -> Bool {
        switch element {
        case .List(let list):
            if list.keypath == keypath && list.topic == topic {
                return true
            }
            return list.flowElementSkeleton.map { skeletonContainsList(keypath: keypath, topic: topic, in: .VStack($0)) } ?? false
        case .VStack(let stack):
            return stack.elements.contains { skeletonContainsList(keypath: keypath, topic: topic, in: $0) }
        case .HStack(let stack):
            return stack.elements.contains { skeletonContainsList(keypath: keypath, topic: topic, in: $0) }
        case .ScrollView(let scroll):
            return scroll.elements.contains { skeletonContainsList(keypath: keypath, topic: topic, in: $0) }
        case .Section(let section):
            return (section.header.map { skeletonContainsList(keypath: keypath, topic: topic, in: $0) } ?? false) ||
                section.content.contains { skeletonContainsList(keypath: keypath, topic: topic, in: $0) } ||
                (section.footer.map { skeletonContainsList(keypath: keypath, topic: topic, in: $0) } ?? false)
        case .Reference(let reference):
            return reference.flowElementSkeleton.map { skeletonContainsList(keypath: keypath, topic: topic, in: .VStack($0)) } ?? false
        case .Grid(let grid):
            return grid.elements.contains { skeletonContainsList(keypath: keypath, topic: topic, in: $0) }
        case .ZStack(let stack):
            return stack.elements.contains { skeletonContainsList(keypath: keypath, topic: topic, in: $0) }
        case .Object(let object):
            return object.elements.values.contains { skeletonContainsList(keypath: keypath, topic: topic, in: $0) }
        default:
            return false
        }
    }

    private func skeletonContainsTextKeypath(_ keypath: String, in element: SkeletonElement) -> Bool {
        switch element {
        case .Text(let text):
            return text.keypath == keypath
        case .VStack(let stack):
            return stack.elements.contains { skeletonContainsTextKeypath(keypath, in: $0) }
        case .HStack(let stack):
            return stack.elements.contains { skeletonContainsTextKeypath(keypath, in: $0) }
        case .ScrollView(let scroll):
            return scroll.elements.contains { skeletonContainsTextKeypath(keypath, in: $0) }
        case .Section(let section):
            return (section.header.map { skeletonContainsTextKeypath(keypath, in: $0) } ?? false) ||
                section.content.contains { skeletonContainsTextKeypath(keypath, in: $0) } ||
                (section.footer.map { skeletonContainsTextKeypath(keypath, in: $0) } ?? false)
        case .Reference(let reference):
            return reference.flowElementSkeleton.map { skeletonContainsTextKeypath(keypath, in: .VStack($0)) } ?? false
        case .List(let list):
            return list.flowElementSkeleton.map { skeletonContainsTextKeypath(keypath, in: .VStack($0)) } ?? false
        case .Grid(let grid):
            return grid.elements.contains { skeletonContainsTextKeypath(keypath, in: $0) }
        case .ZStack(let stack):
            return stack.elements.contains { skeletonContainsTextKeypath(keypath, in: $0) }
        case .Object(let object):
            return object.elements.values.contains { skeletonContainsTextKeypath(keypath, in: $0) }
        default:
            return false
        }
    }

    private func skeletonContainsGrid(keypath: String, in element: SkeletonElement) -> Bool {
        switch element {
        case .Grid(let grid):
            if grid.keypath == keypath {
                return true
            }
            if let itemSkeleton = grid.itemSkeleton, skeletonContainsGrid(keypath: keypath, in: itemSkeleton) {
                return true
            }
            return grid.elements.contains { skeletonContainsGrid(keypath: keypath, in: $0) }
        case .VStack(let stack):
            return stack.elements.contains { skeletonContainsGrid(keypath: keypath, in: $0) }
        case .HStack(let stack):
            return stack.elements.contains { skeletonContainsGrid(keypath: keypath, in: $0) }
        case .ScrollView(let scroll):
            return scroll.elements.contains { skeletonContainsGrid(keypath: keypath, in: $0) }
        case .Section(let section):
            return (section.header.map { skeletonContainsGrid(keypath: keypath, in: $0) } ?? false) ||
                section.content.contains { skeletonContainsGrid(keypath: keypath, in: $0) } ||
                (section.footer.map { skeletonContainsGrid(keypath: keypath, in: $0) } ?? false)
        case .Reference(let reference):
            return reference.flowElementSkeleton.map { skeletonContainsGrid(keypath: keypath, in: .VStack($0)) } ?? false
        case .List(let list):
            return list.flowElementSkeleton.map { skeletonContainsGrid(keypath: keypath, in: .VStack($0)) } ?? false
        case .ZStack(let stack):
            return stack.elements.contains { skeletonContainsGrid(keypath: keypath, in: $0) }
        case .Object(let object):
            return object.elements.values.contains { skeletonContainsGrid(keypath: keypath, in: $0) }
        default:
            return false
        }
    }

    private func skeletonContainsReference(keypath: String, topic: String, in element: SkeletonElement) -> Bool {
        switch element {
        case .Reference(let reference):
            return reference.keypath == keypath && reference.topic == topic
        case .VStack(let stack):
            return stack.elements.contains { skeletonContainsReference(keypath: keypath, topic: topic, in: $0) }
        case .HStack(let stack):
            return stack.elements.contains { skeletonContainsReference(keypath: keypath, topic: topic, in: $0) }
        case .ScrollView(let scroll):
            return scroll.elements.contains { skeletonContainsReference(keypath: keypath, topic: topic, in: $0) }
        case .Section(let section):
            if let header = section.header, skeletonContainsReference(keypath: keypath, topic: topic, in: header) {
                return true
            }
            if let footer = section.footer, skeletonContainsReference(keypath: keypath, topic: topic, in: footer) {
                return true
            }
            return section.content.contains { skeletonContainsReference(keypath: keypath, topic: topic, in: $0) }
        case .Grid(let grid):
            if let itemSkeleton = grid.itemSkeleton,
               skeletonContainsReference(keypath: keypath, topic: topic, in: itemSkeleton) {
                return true
            }
            return grid.elements.contains { skeletonContainsReference(keypath: keypath, topic: topic, in: $0) }
        case .ZStack(let stack):
            return stack.elements.contains { skeletonContainsReference(keypath: keypath, topic: topic, in: $0) }
        case .Object(let object):
            return object.elements.values.contains { skeletonContainsReference(keypath: keypath, topic: topic, in: $0) }
        default:
            return false
        }
    }

}

private actor BindingTestIdentityVault: IdentityVaultProtocol {
    private var identitiesByContext: [String: Identity] = [:]
    private var idCounter = 1

    func initialize() async -> IdentityVaultProtocol {
        self
    }

    func addIdentity(identity: inout Identity, for identityContext: String) async {
        identity.identityVault = self
        identitiesByContext[identityContext] = identity
    }

    func identity(for identityContext: String, makeNewIfNotFound: Bool) async -> Identity? {
        if let existing = identitiesByContext[identityContext] {
            return existing
        }
        guard makeNewIfNotFound else { return nil }

        let suffix = String(format: "%012d", idCounter)
        idCounter += 1
        let uuidString = "00000000-0000-0000-0000-\(suffix)"
        let identity = Identity(uuidString, displayName: identityContext, identityVault: self)
        identitiesByContext[identityContext] = identity
        return identity
    }

    func saveIdentity(_ identity: Identity) async {
        identitiesByContext[identity.displayName] = identity
    }

    func signMessageForIdentity(messageData: Data, identity: Identity) async throws -> Data {
        messageData + identity.uuid.data(using: .utf8, allowLossyConversion: false)!
    }

    func verifySignature(signature: Data, messageData: Data, for identity: Identity) async throws -> Bool {
        let expected = messageData + identity.uuid.data(using: .utf8, allowLossyConversion: false)!
        return signature == expected
    }

    func randomBytes64() async -> Data? {
        Data(repeating: 0xAB, count: 64)
    }

    func aquireKeyForTag(tag: String) async throws -> (key: String, iv: String) {
        ("binding-test-key-\(tag)", "binding-test-iv-\(tag)")
    }
}

private extension BindingTests {
    static let testIdentityVault = BindingTestIdentityVault()
}

private final class RootOnlyStateCell: GeneralCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
        agreementTemplate.addGrant("r---", for: "state")
        await addInterceptForGet(requester: owner, key: "state") { _, _ in
            .object(Self.stateObject)
        }
    }

    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private static let stateObject: Object = [
        "workspace": .object([
            "title": .string("Conference Participant Portal"),
            "subtitle": .string("Profile, recommended people, and meetings in one low-friction flow.")
        ]),
        "program": .object([
            "savedSessions": .list([
                .object(["title": .string("Opening Keynote")]),
                .object(["title": .string("Shared Relations Roundtable")])
            ])
        ])
    ]
}

private final class ConferenceParticipantPreviewShellFixtureCell: GeneralCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("r---", for: "skeletonConfiguration")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")

        await addInterceptForGet(requester: owner, key: "state") { _, _ in
            .object(Self.stateObject)
        }
        await addInterceptForGet(requester: owner, key: "skeletonConfiguration") { _, _ in
            .null
        }
        await addInterceptForSet(requester: owner, key: "dispatchAction") { _, _, _ in
            .object([
                "status": .string("ok"),
                "state": .object(Self.stateObject)
            ])
        }
    }

    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private static let stateObject: Object = [
        "workspace": .object([
            "title": .string("Conference Participant Portal Dashboard"),
            "subtitle": .string("Agenda, meetings, and shared relations in one workspace."),
            "participantBadge": .string("Participant"),
            "programBadge": .string("Program: ready"),
            "matchBadge": .string("Matches: active"),
            "meetingBadge": .string("Meetings: 3 confirmed"),
            "nextStep": .string("Review your recommended sessions and confirm the next meeting request."),
            "previewNotice": .string("Preview wrapper is exposing the same state contract as the real participant shell.")
        ]),
        "access": .object([
            "headline": .string("Conference access overview")
        ]),
        "program": .object([
            "intro": .string("Your agenda is tuned for policy, coordination, and follow-up."),
            "agendaSummary": .string("6 sessions saved, 2 focus tracks selected."),
            "viewSummary": .string("Currently showing your saved agenda."),
            "trackSummary": .string("Governance and implementation are both in focus."),
            "status": .string("Agenda sync is healthy."),
            "storageSummary": .string("All agenda selections are stored."),
            "savedSessions": .list([
                .object([
                    "title": .string("Opening Keynote"),
                    "subtitle": .string("Shared language for trusted infrastructure")
                ]),
                .object([
                    "title": .string("Shared Relations Roundtable"),
                    "subtitle": .string("Operational follow-up between ecosystem teams")
                ])
            ])
        ]),
        "matches": .object([
            "intro": .string("These people are aligned with your current goals."),
            "filterSummary": .string("Filter is set to governance and interoperability."),
            "status": .string("Recommendations refreshed recently."),
            "recommendationSummary": .string("4 high-signal people recommended for your goals."),
            "recommendations": .list([
                .object([
                    "displayName": .string("Ane Solberg"),
                    "headline": .string("Public sector interoperability lead")
                ]),
                .object([
                    "displayName": .string("Mads Hovden"),
                    "headline": .string("Policy and compliance facilitator")
                ])
            ])
        ]),
        "meetings": .object([
            "intro": .string("Meeting planning stays inside the participant shell."),
            "requestSummary": .string("2 requests are awaiting response."),
            "slotSummary": .string("5 viable slots overlap with your saved sessions."),
            "meetingSummary": .string("3 confirmed meetings and 2 pending requests."),
            "exportStatus": .string("iCal export is ready."),
            "confirmedMeetings": .list([
                .object([
                    "title": .string("Coordination with municipal platform team"),
                    "time": .string("10:30")
                ]),
                .object([
                    "title": .string("Follow-up on shared trust registry"),
                    "time": .string("14:15")
                ])
            ])
        ]),
        "sharedConnections": .object([
            "intro": .string("Shared relations help you continue the right conversations."),
            "accessSummary": .string("Shared threads are visible to participating parties."),
            "connectionSummary": .string("2 active shared relations and 1 dormant connection."),
            "chatSummary": .string("2 active shared threads are ready for follow-up."),
            "connections": .list([
                .object([
                    "displayName": .string("Digital Governance Forum"),
                    "relation": .string("Shared contact")
                ]),
                .object([
                    "displayName": .string("Trust Infrastructure Lab"),
                    "relation": .string("Meeting collaborator")
                ])
            ]),
            "recentMessages": .list([
                .object([
                    "text": .string("Let's align on the next governance checkpoint.")
                ])
            ])
        ])
    ]
}
