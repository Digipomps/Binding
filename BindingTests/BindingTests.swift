//
//  BindingTests.swift
//  BindingTests
//
//  Created by Kjetil Hustveit on 16/12/2025.
//

import Foundation
import Testing
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
import CellBase
@testable import CellApple
@testable import Binding

@Suite(.serialized)
struct BindingTests {

    @Test func bindingRuntimeBootstrapEnsuresDefaultsWhenMissing() async {
        CellBase.defaultIdentityVault = nil
        CellBase.defaultCellResolver = nil
        CellBase.typedCellUtility = nil
        CellBase.documentRootPath = ""

        await BindingRuntimeBootstrap.ensureBaseline()

        #expect(CellBase.defaultIdentityVault != nil)
        #expect(CellBase.defaultCellResolver is CellResolver)
        #expect(CellBase.typedCellUtility != nil)
        #expect(CellBase.documentRootPath != nil)
        #expect(!(CellBase.documentRootPath ?? "").isEmpty)
    }

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
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///ConferenceParticipantDiscoverySnapshot") == "cell:///ConferenceParticipantDiscoverySnapshot")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///ConferenceParticipantPreviewShell") == "cell:///ConferenceParticipantPreviewShell")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///ConferenceAdminPreviewShell") == "cell:///ConferenceAdminPreviewShell")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///ConferenceAIAssistantGatewayProxy") == "cell:///ConferenceAIAssistantGatewayProxy")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///ConferenceIdentityLinkIntake") == "cell:///ConferenceIdentityLinkIntake")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///AppleIntelligence") == "cell:///AppleIntelligence")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///Chat") == "cell://staging.haven.digipomps.org/Chat")
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
            aiEndpoint: "cell:///AIGateway"
        )

        #expect(configuration.name == "Conference AI Assistant")
        #expect(configuration.cellReferences?.count == 2)
        #expect(configuration.cellReferences?.first?.label == "conferenceParticipantShell")
        #expect(configuration.cellReferences?.first?.setKeysAndValues.contains(where: { $0.key == "state" }) == true)
        #expect(configuration.cellReferences?.last?.label == "aiGateway")
        #expect(configuration.cellReferences?.last?.endpoint == "cell:///ConferenceAIAssistantGatewayProxy")

        guard case .ScrollView? = configuration.skeleton else {
            Issue.record("Conference AI Assistant should use a designed scroll surface")
            return
        }
    }

    @Test func conferenceIdentityLinkWorkbenchSeedsLocalIntakeState() {
        let configuration = ConfigurationCatalogCell.conferenceIdentityLinkWorkbenchConfiguration()

        #expect(configuration.name == "Conference Scaffold Setup & Identity Link")
        #expect(configuration.cellReferences?.count == 1)
        #expect(configuration.cellReferences?.first?.label == "identityLink")
        #expect(configuration.cellReferences?.first?.endpoint == "cell:///ConferenceIdentityLinkIntake")
        #expect(configuration.cellReferences?.first?.setKeysAndValues.contains(where: { $0.key == "state" }) == true)

        guard case .ScrollView? = configuration.skeleton else {
            Issue.record("Conference identity-link workbench should use a designed scroll surface")
            return
        }
    }

    @Test func conferenceIdentityLinkInboxParsesDeepLinkChallenge() async throws {
        let store = ConferenceIdentityLinkInboxStore.shared
        await store.clear()

        let url = try #require(
            URL(string: "haven://identity-link?requestId=REQ-123&audience=staging.haven.digipomps.org&origin=haven://binding/add-device&entityAnchorReference=cell:///EntityAnchor&deviceLabel=Kjetil%20iPhone&identity=Kjetil%20iPhone&domains=private,scaffold&contexts=private,scaffold&scopes=entity-auth,personal-cells&challenge=nonce-123&expiresAt=2026-04-02T12:00:00Z&algorithm=P256-ES256")
        )

        #expect(await store.ingest(url: url))

        let state = await store.stateObject()
        guard case let .object(incoming)? = state["incoming"],
              case let .object(review)? = state["review"] else {
            Issue.record("Expected incoming/review identity-link state objects")
            await store.clear()
            return
        }

        #expect(incoming["challengeSummary"] == .string("Request REQ-123"))
        #expect(incoming["audienceSummary"] == .string("Audience: staging.haven.digipomps.org"))
        #expect(incoming["domainSummary"] == .string("Requested domains: private, scaffold"))
        #expect(incoming["scopeSummary"] == .string("Requested scopes: entity-auth, personal-cells"))
        #expect(review["confirmationStatus"] == .string("Lokal brukerbekreftelse mangler."))

        await store.clear()
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

    @Test func conferenceWorkbenchConfigurationsValidateWithoutBrokenBindings() {
        let configurations = [
            ConfigurationCatalogCell.conferenceDemoLauncherWorkbenchConfiguration(),
            ConfigurationCatalogCell.conferenceIdentityLinkWorkbenchConfiguration(),
            ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
                endpoint: "cell:///ConferenceParticipantPreviewShell"
            ),
            ConfigurationCatalogCell.conferenceParticipantChatWorkbenchConfiguration(
                participantEndpoint: "cell:///ConferenceParticipantPreviewShell"
            ),
            ConfigurationCatalogCell.conferenceNearbyRadarWorkbenchConfiguration(
                participantEndpoint: "cell:///ConferenceParticipantPreviewShell"
            ),
            ConfigurationCatalogCell.conferenceNearbyParticipantWorkbenchConfiguration(
                participantEndpoint: "cell:///ConferenceParticipantPreviewShell"
            ),
            ConfigurationCatalogCell.conferenceAIAssistantWorkbenchConfiguration(
                conferenceEndpoint: "cell:///ConferenceParticipantPreviewShell",
                aiEndpoint: "cell:///AIGateway"
            ),
            ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
                endpoint: "cell:///ConferenceAdminPreviewShell"
            ),
            ConfigurationCatalogCell.conferencePublicWorkbenchConfiguration(
                endpoint: "cell:///ConferencePublicShellFixture"
            ),
            ConfigurationCatalogCell.conferenceSponsorWorkbenchConfiguration(
                endpoint: "cell:///ConferenceSponsorShellFixture"
            )
        ]

        for configuration in configurations {
            let repaired = BindingConferenceConfigurationRepair.updatedConfigurationIfNeeded(configuration) ?? configuration
            let report = CellConfigurationValidationService.validate(repaired)
            #expect(report.errorCount == 0, "\(repaired.name): \(report.issues)")
        }
    }

    @Test func conferenceRequesterDescriptorsMatchConferenceShellOwnershipModel() {
        let contentView = ContentView()

        #expect(
            contentView.preferredRequesterDescriptor(
                for: "cell://staging.haven.digipomps.org/ConferenceAdminShell"
            ) == .init(
                identityContext: "conference-organizer@staging.haven.digipomps.org",
                displayName: "Conference Organizer"
            )
        )
        #expect(
            contentView.preferredRequesterDescriptor(
                for: "cell://staging.haven.digipomps.org/ConferenceUIRouter"
            ) == .init(
                identityContext: "conference-organizer@staging.haven.digipomps.org",
                displayName: "Conference Organizer"
            )
        )
        #expect(
            contentView.preferredRequesterDescriptor(
                for: "cell://staging.haven.digipomps.org/ConferencePublicShell"
            ) == .init(
                identityContext: "conference-public-publisher@staging.haven.digipomps.org",
                displayName: "Conference Public Publisher"
            )
        )
        #expect(
            contentView.preferredRequesterDescriptor(
                for: "cell://staging.haven.digipomps.org/ConferenceSponsorShell"
            ) == .init(
                identityContext: "conference-sponsor:sponsor-ai-digital-independence@staging.haven.digipomps.org",
                displayName: "sponsor-ai-digital-independence"
            )
        )
    }

    @Test func conferenceRequesterDescriptorsAreScopedPerRemoteHost() {
        let contentView = ContentView()

        let stagingDescriptor = contentView.preferredRequesterDescriptor(
            for: "cell://staging.haven.digipomps.org/ConferenceAdminShell"
        )
        let demoDescriptor = contentView.preferredRequesterDescriptor(
            for: "cell://demo.haven.digipomps.org/ConferenceAdminShell"
        )

        #expect(stagingDescriptor?.displayName == "Conference Organizer")
        #expect(demoDescriptor?.displayName == "Conference Organizer")
        #expect(stagingDescriptor?.identityContext == "conference-organizer@staging.haven.digipomps.org")
        #expect(demoDescriptor?.identityContext == "conference-organizer@demo.haven.digipomps.org")
        #expect(stagingDescriptor != demoDescriptor)
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
        #expect(participantTitle == .string("Conference Participant Portal"))

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

    @Test func conferenceAIAssistantGatewayProxyReturnsStateForPresetWrites() async throws {
        await BindingLocalCellRegistration.shared.ensureRegistered()
        let resolver = CellResolver.sharedInstance
        CellBase.defaultCellResolver = resolver

        let owner = await makeOwnerIdentity()

        guard let proxy = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceAIAssistantGatewayProxy",
            requester: owner
        ) as? Meddle else {
            Issue.record("Could not resolve ConferenceAIAssistantGatewayProxy as Meddle")
            return
        }

        let systemPromptResponse = try await proxy.set(
            keypath: "setDraftSystemPrompt",
            value: .string("Conference copilot system prompt"),
            requester: owner
        )
        #expect(systemPromptResponse != nil)

        let promptResponse = try await proxy.set(
            keypath: "setDraftPrompt",
            value: .string("Give me a concise conference brief."),
            requester: owner
        )
        #expect(promptResponse != nil)

        let stateValue = try await proxy.get(
            keypath: "state",
            requester: owner
        )
        guard case let .object(stateObject) = stateValue,
              case let .object(draftObject)? = stateObject["draft"] else {
            Issue.record("Expected draft object from conference AI gateway proxy state")
            return
        }

        #expect(draftObject["systemPrompt"] == .string("Conference copilot system prompt"))
        #expect(draftObject["prompt"] == .string("Give me a concise conference brief."))
    }

    @Test func conferenceAIAssistantGatewayProxyCanCommitBufferedSessionAPIKey() async throws {
        await BindingLocalCellRegistration.shared.ensureRegistered()
        let resolver = CellResolver.sharedInstance
        CellBase.defaultCellResolver = resolver

        let owner = await makeOwnerIdentity()

        guard let proxy = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceAIAssistantGatewayProxy",
            requester: owner
        ) as? Meddle else {
            Issue.record("Could not resolve ConferenceAIAssistantGatewayProxy as Meddle")
            return
        }

        let bufferResponse = try await proxy.set(
            keypath: "setDraftAPIKeyEntry",
            value: .string("sk-test-buffered-session-key"),
            requester: owner
        )
        #expect(bufferResponse != nil)

        let commitResponse = try await proxy.set(
            keypath: "commitDraftAPIKeyEntry",
            value: .null,
            requester: owner
        )
        #expect(commitResponse != nil)

        let stateValue = try await proxy.get(
            keypath: "state",
            requester: owner
        )
        guard case let .object(stateObject) = stateValue,
              case let .object(setupObject)? = stateObject["setup"] else {
            Issue.record("Expected setup object from conference AI gateway proxy state")
            return
        }

        #expect(setupObject["sessionCredentialAvailable"] == .bool(true))
        #expect(setupObject["activeCredentialSource"] == .string("session"))
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
            aiEndpoint: "cell:///AIGateway"
        )
        let aiAssistantFallback = contentView.localConferencePreviewFallbackConfiguration(
            for: aiAssistantConfiguration,
            failureDetails: ["denied: preview owner required"]
        )
        #expect(aiAssistantFallback?.cellReferences?.first?.endpoint == "cell:///ConferenceParticipantPreviewShell")
        #expect(aiAssistantFallback?.cellReferences?.contains(where: { $0.label == "aiGateway" && $0.endpoint == "cell:///ConferenceAIAssistantGatewayProxy" }) == true)
        #expect(aiAssistantFallback?.discovery?.sourceCellEndpoint == "cell:///ConferenceParticipantPreviewShell")

        #expect(
            contentView.localConferencePreviewFallbackConfiguration(
                for: participantConfiguration,
                failureDetails: ["Timeout ved lasting av conference preview"]
            )?.cellReferences?.first?.endpoint == "cell:///ConferenceParticipantPreviewShell"
        )

        #expect(
            contentView.localConferencePreviewFallbackConfiguration(
                for: adminConfiguration,
                failureDetails: ["Innholdet er ikke tilgjengelig akkurat nå."]
            )?.cellReferences?.first?.endpoint == "cell:///ConferenceAdminPreviewShell"
        )
    }

    @Test func conferenceAdminWorkbenchPrefersOrganizerRequesterDescriptor() {
        let contentView = ContentView()
        let configuration = ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
            endpoint: "cell://staging.haven.digipomps.org/ConferenceAdminShell"
        )

        #expect(
            contentView.preferredRequesterDescriptor(for: configuration)
            == .init(
                identityContext: "conference-organizer@staging.haven.digipomps.org",
                displayName: "Conference Organizer"
            )
        )
    }

    @Test func mixedConferenceAndAIWorkbenchDoesNotForceSingleSpecialRequester() {
        let contentView = ContentView()
        let configuration = ConfigurationCatalogCell.conferenceAIAssistantWorkbenchConfiguration(
            conferenceEndpoint: "cell://staging.haven.digipomps.org/ConferenceParticipantPreviewShell",
            aiEndpoint: "cell:///AIGateway"
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

    @Test func validationServiceIgnoresDirectDispatchActionPayloadKeypaths() {
        var configuration = CellConfiguration(name: "Direct Dispatch Action")
        configuration.addReference(
            CellReference(
                endpoint: "cell:///ConferenceNearbyRadar",
                label: "nearbyRadar"
            )
        )

        let actionButton = SkeletonButton(
            keypath: "dispatchAction",
            label: "Start scanner",
            url: "cell:///ConferenceNearbyRadar",
            payload: .object([
                "keypath": .string("start"),
                "payload": .bool(true)
            ])
        )

        configuration.skeleton = .VStack(
            SkeletonVStack(elements: [
                .Text(SkeletonText(keypath: "nearbyRadar.state.summary")),
                .Button(actionButton)
            ])
        )

        let report = CellConfigurationValidationService.validate(configuration)

        #expect(!report.issues.contains(where: {
            $0.title == "Bindings uten matchende reference"
        }))
    }

    @Test func validationServiceIgnoresRelativeBindingsInsideFlowElementSkeleton() {
        var configuration = CellConfiguration(name: "Flow Element Snapshot")
        configuration.addReference(
            CellReference(
                endpoint: "cell:///ConferenceNearbyRadar",
                label: "nearbyRadar"
            )
        )

        var snapshotReference = SkeletonCellReference(
            keypath: "nearbyRadar",
            topic: "nearbyRadar.snapshot"
        )
        snapshotReference.flowElementSkeleton = SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "radarLayout.ahead.title")),
            .Text(SkeletonText(keypath: "radarLayout.center.subtitle")),
            .Text(SkeletonText(keypath: "selectedEntity.title"))
        ])

        configuration.skeleton = .VStack(
            SkeletonVStack(elements: [
                .Reference(snapshotReference)
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
        #expect(references.contains(where: {
            $0.label == "conferenceParticipantShell" && $0.endpoint == "cell:///ConferenceParticipantPreviewShell"
        }))
        #expect(references.contains(where: {
            $0.label == "agendaSnapshot" && $0.endpoint == "cell:///ConferenceParticipantAgendaSnapshot"
        }))
        #expect(references.contains(where: {
            $0.label == "matchmakingSnapshot" && $0.endpoint == "cell:///ConferenceParticipantMatchmakingSnapshot"
        }))
        #expect(references.contains(where: {
            $0.label == "discoverySnapshot" && $0.endpoint == "cell:///ConferenceParticipantDiscoverySnapshot"
        }))
        #expect(references.contains(where: { $0.label == "nearbyRadar" && $0.endpoint == "cell:///ConferenceNearbyRadar" }))
        #expect(references.contains(where: { $0.label == "chatSnapshot" && $0.endpoint == "cell:///ConferenceParticipantChatSnapshot" }))

        guard let skeleton = configuration.skeleton else {
            Issue.record("Conference participant portal mangler skeleton")
            return
        }

        #expect(skeletonContainsTextKeypath("agendaSnapshot.state.statusSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("agendaSnapshot.state.selectionSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("agendaSnapshot.state.focusedActions", in: skeleton))
        #expect(skeletonContainsGrid(keypath: "agendaSnapshot.state.modeChoices", in: skeleton))
        #expect(skeletonContainsGrid(keypath: "agendaSnapshot.state.trackChoices", in: skeleton))
        #expect(skeletonContainsButton(keypath: "agendaSnapshot.dispatchAction", in: skeleton))
        #expect(skeletonContainsTextKeypath("matchmakingSnapshot.state.statusSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("matchmakingSnapshot.state.selectionSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("matchmakingSnapshot.state.focusedProfile.title", in: skeleton))
        #expect(skeletonContainsTextKeypath("matchmakingSnapshot.state.actionSummary", in: skeleton))
        #expect(skeletonContainsButton(keypath: "matchmakingSnapshot.dispatchAction", in: skeleton))
        #expect(skeletonContainsReference(keypath: "discoverySnapshot", topic: "discoverySnapshot.snapshot", in: skeleton))
        #expect(skeletonContainsTextKeypath("status", in: skeleton))
        #expect(skeletonContainsTextKeypath("nextAction", in: skeleton))
        #expect(skeletonContainsTextKeypath("statusSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("selectionSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("focusedProfile.title", in: skeleton))
        #expect(skeletonContainsTextKeypath("alignmentSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("proofSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("nearbyRadar.state.summary", in: skeleton))
        #expect(skeletonContainsTextKeypath("nearbyRadar.state.selectionSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("nearbyRadar.state.actionSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("chatSnapshot.state.statusSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("chatSnapshot.state.selectionSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("chatSnapshot.state.focusedThread.title", in: skeleton))
        #expect(skeletonContainsButton(keypath: "chatSnapshot.dispatchAction", in: skeleton))
        #expect(skeletonContainsButton(keypath: "nearbyRadar.dispatchAction", in: skeleton))
        #expect(skeletonContainsButton(keypath: "discoverySnapshot.dispatchAction", in: skeleton))
        #expect(skeletonContainsReference(keypath: "nearbyRadar", topic: "nearbyRadar.snapshot", in: skeleton))
        #expect(configuration.discovery?.sourceCellEndpoint == "cell:///ConferenceParticipantPreviewShell")
        #expect(configuration.discovery?.sourceCellName == "ConferenceParticipantPreviewShellLocalFallbackCell")
        #expect(configuration.description?.contains("lokal preview-wrapper") == true)
    }

    @Test func conferenceParticipantPortalMenuSeedUsesLocalPreviewInBinding() {
        let configuration = ContentView.conferenceParticipantPortalMenuSeedConfiguration()

        #expect(configuration.cellReferences?.contains(where: {
            $0.label == "conferenceParticipantShell" && $0.endpoint == "cell:///ConferenceParticipantPreviewShell"
        }) == true)
        #expect(configuration.discovery?.sourceCellEndpoint == "cell:///ConferenceParticipantPreviewShell")
        #expect(configuration.discovery?.sourceCellName == "ConferenceParticipantPreviewShellLocalFallbackCell")
    }

    @Test func defaultDemoStartConfigurationUsesConferenceDemoLauncher() {
        let configuration = ContentView.defaultDemoStartConfiguration()

        #expect(configuration.name == "Conference Demo Launcher")
        #expect(configuration.cellReferences?.contains(where: {
            $0.label == "conferenceDemoLauncher" && $0.endpoint == "cell:///ConferenceDemoLauncher"
        }) == true)
    }

    @Test func effectiveDemoStartConfigurationOverridesNonLauncherStoredConfiguration() {
        let effectiveWhenMissing = ContentView.effectiveDemoStartConfiguration(
            storedConfiguration: nil
        )
        #expect(effectiveWhenMissing.name == "Conference Demo Launcher")

        let effectiveWhenLauncherStored = ContentView.effectiveDemoStartConfiguration(
            storedConfiguration: ContentView.conferenceDemoLauncherMenuSeedConfiguration()
        )
        #expect(effectiveWhenLauncherStored.name == "Conference Demo Launcher")

        let effectiveWhenDifferentStored = ContentView.effectiveDemoStartConfiguration(
            storedConfiguration: ContentView.conferenceParticipantPortalMenuSeedConfiguration()
        )
        #expect(effectiveWhenDifferentStored.name == "Conference Demo Launcher")
    }

    @Test func conferenceParticipantPortalRepairRestoresDiscoveryAndNearbyWiring() {
        var staleConfiguration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )
        staleConfiguration.cellReferences?.removeAll { $0.label == "matchmakingSnapshot" }
        staleConfiguration.cellReferences?.removeAll { $0.label == "discoverySnapshot" }
        staleConfiguration.cellReferences?.removeAll { $0.label == "nearbyRadar" }
        staleConfiguration.cellReferences?.removeAll { $0.label == "agendaSnapshot" }

        let repaired = BindingConferenceConfigurationRepair.updatedConfigurationIfNeeded(staleConfiguration)

        #expect(repaired != nil)
        #expect(repaired?.cellReferences?.contains(where: {
            $0.label == "conferenceParticipantShell" && $0.endpoint == "cell:///ConferenceParticipantPreviewShell"
        }) == true)
        #expect(repaired?.cellReferences?.contains(where: {
            $0.label == "agendaSnapshot" && $0.endpoint == "cell:///ConferenceParticipantAgendaSnapshot"
        }) == true)
        #expect(repaired?.cellReferences?.contains(where: {
            $0.label == "matchmakingSnapshot" && $0.endpoint == "cell:///ConferenceParticipantMatchmakingSnapshot"
        }) == true)
        #expect(repaired?.cellReferences?.contains(where: {
            $0.label == "discoverySnapshot" && $0.endpoint == "cell:///ConferenceParticipantDiscoverySnapshot"
        }) == true)
        #expect(repaired?.cellReferences?.contains(where: {
            $0.label == "nearbyRadar" && $0.endpoint == "cell:///ConferenceNearbyRadar"
        }) == true)

        guard let skeleton = repaired?.skeleton else {
            Issue.record("Expected repaired conference participant portal skeleton")
            return
        }

        #expect(skeletonContainsButton(keypath: "agendaSnapshot.dispatchAction", in: skeleton))
        #expect(skeletonContainsGrid(keypath: "agendaSnapshot.state.modeChoices", in: skeleton))
        #expect(skeletonContainsGrid(keypath: "agendaSnapshot.state.trackChoices", in: skeleton))
        #expect(skeletonContainsReference(keypath: "discoverySnapshot", topic: "discoverySnapshot.snapshot", in: skeleton))
        #expect(skeletonContainsButton(keypath: "matchmakingSnapshot.dispatchAction", in: skeleton))
        #expect(skeletonContainsButton(keypath: "discoverySnapshot.dispatchAction", in: skeleton))
        #expect(skeletonContainsButton(keypath: "nearbyRadar.dispatchAction", in: skeleton))
        #expect(skeletonContainsReference(keypath: "nearbyRadar", topic: "nearbyRadar.snapshot", in: skeleton))
    }

    @Test func conferenceParticipantPortalUsesReferenceLabelsForLocalConferenceActions() {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )

        guard let skeleton = configuration.skeleton else {
            Issue.record("Conference participant portal mangler skeleton")
            return
        }

        #expect(skeletonContainsButton(keypath: "agendaSnapshot.dispatchAction", in: skeleton))
        #expect(skeletonContainsButton(keypath: "matchmakingSnapshot.dispatchAction", in: skeleton))
        #expect(skeletonContainsButton(keypath: "discoverySnapshot.dispatchAction", in: skeleton))
        #expect(skeletonContainsButton(keypath: "nearbyRadar.dispatchAction", in: skeleton))
        #expect(!skeletonContainsButton(keypath: "dispatchAction", url: "cell:///ConferenceParticipantAgendaSnapshot", in: skeleton))
        #expect(!skeletonContainsButton(keypath: "dispatchAction", url: "cell:///ConferenceParticipantMatchmakingSnapshot", in: skeleton))
        #expect(!skeletonContainsButton(keypath: "dispatchAction", url: "cell:///ConferenceParticipantDiscoverySnapshot", in: skeleton))
        #expect(!skeletonContainsButton(keypath: "dispatchAction", url: "cell:///ConferenceNearbyRadar", in: skeleton))
    }

    @Test func conferenceControlTowerRepairRestoresAdminPreviewWiring() {
        var staleConfiguration = ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
            endpoint: "cell://staging.haven.digipomps.org/ConferenceAdminPreviewShell"
        )
        staleConfiguration.cellReferences = []
        staleConfiguration.skeleton = .VStack(
            SkeletonVStack(elements: [
                .Text(SkeletonText(keypath: "conferenceAdminShell.state.workspace.title"))
            ])
        )

        let repaired = BindingConferenceConfigurationRepair.updatedConfigurationIfNeeded(staleConfiguration)

        #expect(repaired != nil)
        #expect(repaired?.cellReferences?.contains(where: {
            $0.label == "conferenceAdminShell" && $0.endpoint == "cell:///ConferenceAdminPreviewShell"
        }) == true)

        guard let skeleton = repaired?.skeleton else {
            Issue.record("Expected repaired conference control tower skeleton")
            return
        }

        #expect(skeletonContainsTextKeypath("conferenceAdminShell.state.workspace.title", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceAdminShell.state.content.intro", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceAdminShell.state.operations.intro", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceAdminShell.state.insights.dashboardSummary", in: skeleton))
        #expect(skeletonContainsButton(keypath: "conferenceAdminShell.dispatchAction", in: skeleton))
    }

    @Test func conferenceControlTowerDefaultsToLocalPreviewInBinding() {
        let configuration = ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration()
        let references = configuration.cellReferences ?? []

        #expect(references.contains(where: {
            $0.label == "conferenceAdminShell" && $0.endpoint == "cell:///ConferenceAdminPreviewShell"
        }))
        #expect(!references.contains(where: {
            $0.label == "conferenceAdminShell" && $0.endpoint.contains("staging.haven.digipomps.org")
        }))
        #expect(configuration.description?.contains("lokal preview-wrapper") == true)
        #expect(configuration.discovery?.sourceCellName == "ConferenceAdminPreviewShellLocalFallbackCell")
    }

    @Test func conferenceAdminMenuSeedUsesLocalPreviewInBinding() {
        let configuration = ContentView.conferenceAdminMenuSeedConfiguration()
        let references = configuration.cellReferences ?? []

        #expect(references.contains(where: {
            $0.label == "conferenceAdminShell" && $0.endpoint == "cell:///ConferenceAdminPreviewShell"
        }))
        #expect(configuration.discovery?.sourceCellEndpoint == "cell:///ConferenceAdminPreviewShell")
        #expect(configuration.discovery?.sourceCellName == "ConferenceAdminPreviewShellLocalFallbackCell")
    }

    @Test func conferenceControlTowerUsesReferenceLabelForOrganizerActions() {
        let configuration = ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
            endpoint: "cell:///ConferenceAdminPreviewShell"
        )

        guard let skeleton = configuration.skeleton else {
            Issue.record("Conference control tower mangler skeleton")
            return
        }

        #expect(skeletonContainsButton(keypath: "conferenceAdminShell.dispatchAction", in: skeleton))
        #expect(!skeletonContainsButton(keypath: "dispatchAction", url: "cell:///ConferenceAdminPreviewShell", in: skeleton))
    }

    @Test func conferenceControlTowerOrganizerActionsAckThroughProxyAndPreviewShell() async throws {
        let configuration = ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
            endpoint: "cell:///ConferenceAdminPreviewShell"
        )
        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        let actionPayload: ValueType = .object([
            "keypath": .string("contentPublishing.publishDraft"),
            "payload": .bool(true),
            "responseMode": .string("ack")
        ])

        let portholeResponse = try await context.porthole.set(
            keypath: "conferenceAdminShell.dispatchAction",
            value: actionPayload,
            requester: context.owner
        )
        #expect(portholeResponse != nil)
        if let portholeResponse {
            #expect(SkeletonBindingProbeSupport.failureDetail(from: portholeResponse) == nil)
        }

        guard let previewShell = try await context.resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceAdminPreviewShell",
            requester: context.owner
        ) as? Meddle else {
            Issue.record("ConferenceAdminPreviewShell did not resolve as Meddle")
            return
        }

        let previewResponse = try await previewShell.set(
            keypath: "dispatchAction",
            value: actionPayload,
            requester: context.owner
        )
        #expect(previewResponse != nil)
        if let previewResponse {
            #expect(SkeletonBindingProbeSupport.failureDetail(from: previewResponse) == nil)
        }
    }

    @Test func conferenceParticipantPortalProxyActionsFocusParticipantAndOpenChatWorkbench() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )
        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        let focusResponse = try await context.porthole.set(
            keypath: "matchmakingSnapshot.dispatchAction",
            value: .object([
                "keypath": .string("matchmaking.focusRecommendationAtIndex"),
                "payload": .object([
                    "index": .integer(0)
                ])
            ]),
            requester: context.owner
        )
        #expect(focusResponse != nil)
        if let focusResponse {
            let focusFailure = await MainActor.run {
                SkeletonBindingProbeSupport.failureDetail(from: focusResponse)
            }
            #expect(focusFailure == nil)
        }

        let focusedTitle = try await context.porthole.get(
            keypath: "matchmakingSnapshot.state.focusedProfile.title",
            requester: context.owner
        )
        #expect(focusedTitle == .string("Ane Solberg"))

        let chatStartResponse = try await context.porthole.set(
            keypath: "matchmakingSnapshot.dispatchAction",
            value: .object([
                "keypath": .string("discovery.startChatWithFocusedPerson"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        #expect(chatStartResponse != nil)
        if let chatStartResponse {
            let chatStartFailure = await MainActor.run {
                SkeletonBindingProbeSupport.failureDetail(from: chatStartResponse)
            }
            #expect(chatStartFailure == nil)
        }

        let chatActionLabel = try await context.porthole.get(
            keypath: "matchmakingSnapshot.state.focusedActions[0].label",
            requester: context.owner
        )
        #expect(chatActionLabel == .string("Åpne chatflate"))

        let nextStepSummary = try await context.porthole.get(
            keypath: "matchmakingSnapshot.state.nextStepSummary",
            requester: context.owner
        )
        #expect(nextStepSummary == .string("Chatten med Ane Solberg er klar. Neste steg er å åpne chatflaten eller be om møte."))

        let expectedWorkbenchLoad = Task {
            await CellConfigurationVerifier.waitForPortholeLoadBridgeConfiguration(
                containingName: "Conference Chat"
            )
        }
        let openChatResponse = try await context.porthole.set(
            keypath: "chatSnapshot.dispatchAction",
            value: .object([
                "keypath": .string("openChatWorkbenchForSelectedParticipant"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        #expect(openChatResponse != nil)
        if let openChatResponse {
            let openChatFailure = await MainActor.run {
                SkeletonBindingProbeSupport.failureDetail(from: openChatResponse)
            }
            #expect(openChatFailure == nil)
        }

        guard let configuration = await expectedWorkbenchLoad.value else {
            let actionSummary = try? await context.porthole.get(
                keypath: "chatSnapshot.state.actionSummary",
                requester: context.owner
            )
            let statusSummary = try? await context.porthole.get(
                keypath: "chatSnapshot.state.statusSummary",
                requester: context.owner
            )
            Issue.record(
                "Expected BindingPortholeLoadBridge request for Conference Chat. actionSummary=\(String(describing: actionSummary)) statusSummary=\(String(describing: statusSummary))"
            )
            return
        }

        #expect(configuration.name.contains("Conference Chat"))
        #expect(configuration.cellReferences?.contains(where: { $0.label == "chatSnapshot" }) == true)
    }

    @Test func bindingLocalCellRegistrationMakesConferenceParticipantAgendaSnapshotReadable() async throws {
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
        guard let snapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantAgendaSnapshot",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantAgendaSnapshot did not resolve as Meddle")
            return
        }

        let stateValue = try await snapshot.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue else {
            Issue.record("Expected object from ConferenceParticipantAgendaSnapshot.state, got \(stateValue)")
            return
        }

        #expect(object["statusSummary"] != nil)
        #expect(object["selectionSummary"] != nil)
        #expect(object["nextStepSummary"] != nil)
        #expect(object["actionSummary"] != nil)
        #expect(object["modeChoices"] != nil)
        #expect(object["trackChoices"] != nil)
        #expect(object["focusedActions"] != nil)
        #expect(object["trackOptions"] != nil)
    }

    @Test func conferenceParticipantAgendaSnapshotSupportsInlineSelectionAndActions() async throws {
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
        guard let snapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantAgendaSnapshot",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantAgendaSnapshot did not resolve as Meddle")
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
            Issue.record("Expected agenda snapshot state with mode and track choices")
            return
        }

        #expect(object["statusSummary"] == .string("Viser timeline med governance i fokus."))
        #expect(object["selectionSummary"] == .string("Viser timeline med Governance i fokus."))
        #expect(object["actionSummary"] == .string("Governance er nå i fokus i denne siden."))
        #expect(firstModeChoice["label"] == .string("Vis for deg"))
        #expect(secondModeChoice["selectionBadge"] == .string("AKTIV NÅ"))
        #expect(secondModeChoice["label"] == .string("Viser nå"))
        #expect(firstTrackChoice["label"] == .string("Vis alle spor"))
        #expect(secondTrackChoice["selectionBadge"] == .string("FOKUS NÅ"))
        #expect(secondTrackChoice["label"] == .string("Viser nå"))
    }

    @Test func bindingLocalCellRegistrationMakesConferenceDiscoverySnapshotReadable() async throws {
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
        guard let discoverySnapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantDiscoverySnapshot",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantDiscoverySnapshot did not resolve as Meddle")
            return
        }

        let stateValue = try await discoverySnapshot.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue else {
            Issue.record("Expected object from ConferenceParticipantDiscoverySnapshot.state, got \(stateValue)")
            return
        }

        #expect(object["status"] != nil)
        #expect(object["nextAction"] != nil)
        #expect(object["statusSummary"] != nil)
        #expect(object["selectionSummary"] != nil)
        #expect(object["focusedProfile"] != nil)
        #expect(object["focusedActions"] != nil)
        #expect(object["candidates"] != nil)
        #expect(object["proofCandidates"] != nil)
        #expect(object["groupSuggestions"] != nil)
    }

    @Test func conferenceParticipantDiscoverySnapshotSupportsInlineSelectionAndActions() async throws {
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
        guard let snapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantDiscoverySnapshot",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantDiscoverySnapshot did not resolve as Meddle")
            return
        }

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("discovery.focusPerson"),
                "payload": .object([
                    "displayName": .string("Ane Solberg"),
                    "subtitle": .string("Public sector interoperability")
                ])
            ]),
            requester: identity
        )

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("matchmaking.toggleFollowUp"),
                "payload": .object([
                    "displayName": .string("Ane Solberg"),
                    "subtitle": .string("Public sector interoperability")
                ])
            ]),
            requester: identity
        )

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("discovery.startChat"),
                "payload": .object([
                    "source": .string("binding-test"),
                    "targets": .list([
                        .object([
                            "displayName": .string("Ane Solberg"),
                            "headline": .string("Public sector interoperability")
                        ])
                    ])
                ])
            ]),
            requester: identity
        )

        let stateValue = try await snapshot.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue,
              case let .object(focusedProfile)? = object["focusedProfile"],
              case let .list(focusedActions)? = object["focusedActions"],
              case let .list(candidates)? = object["candidates"],
              case let .object(firstCandidate)? = candidates.first else {
            Issue.record("Expected discovery snapshot state with focused profile and actions")
            return
        }

        #expect(object["selectionSummary"] == .string("Viser Ane Solberg i discovery-delen."))
        #expect(focusedProfile["title"] == .string("Ane Solberg"))
        #expect(firstCandidate["label"] == .string("Åpne chatflate"))

        guard case let .object(chatAction)? = focusedActions.first,
              case let .object(followUpAction)? = focusedActions.dropFirst().first,
              case let .object(meetingAction)? = focusedActions.dropFirst(2).first else {
            Issue.record("Expected three focused actions in discovery snapshot")
            return
        }

        #expect(chatAction["label"] == .string("Åpne chatflate"))
        #expect(followUpAction["label"] == .string("Fjern markering"))
        #expect(meetingAction["label"] == .string("Be om møte"))

        guard let preview = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantPreviewShell did not resolve as Meddle")
            return
        }

        let previewState = try await preview.get(keypath: "state", requester: identity)
        guard case let .object(previewObject) = previewState,
              case let .object(sharedConnections)? = previewObject["sharedConnections"],
              case let .list(connections)? = sharedConnections["connections"],
              case let .object(firstConnection)? = connections.first else {
            Issue.record("Expected shared connection after start chat")
            return
        }

        #expect(sharedConnections["connectionSummary"] == .string("1 shared relation(s) visible."))
        #expect(sharedConnections["chatSummary"] == .string("2 shared message(s) visible."))
        #expect(firstConnection["title"] == .string("Ane Solberg"))

        guard let chatSnapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantChatSnapshot",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantChatSnapshot did not resolve as Meddle")
            return
        }

        let chatState = try await chatSnapshot.get(keypath: "state", requester: identity)
        guard case let .object(chatObject) = chatState,
              case let .object(focusedThread)? = chatObject["focusedThread"] else {
            Issue.record("Expected chat snapshot state after start chat")
            return
        }

        #expect(chatObject["selectionSummary"] == .string("Viser den delte tråden med Ane Solberg."))
        #expect(focusedThread["title"] == .string("Ane Solberg"))
    }

    @Test func bindingLocalCellRegistrationMakesConferenceMatchmakingSnapshotReadable() async throws {
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
        guard let snapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantMatchmakingSnapshot",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantMatchmakingSnapshot did not resolve as Meddle")
            return
        }

        let stateValue = try await snapshot.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue else {
            Issue.record("Expected object from ConferenceParticipantMatchmakingSnapshot.state, got \(stateValue)")
            return
        }

        #expect(object["statusSummary"] != nil)
        #expect(object["selectionSummary"] != nil)
        #expect(object["nextStepSummary"] != nil)
        #expect(object["focusedProfile"] != nil)
        #expect(object["focusedActions"] != nil)
        #expect(object["recommendations"] != nil)
    }

    @Test func bindingLocalCellRegistrationMakesConferenceChatSnapshotReadable() async throws {
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
        guard let snapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantChatSnapshot",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantChatSnapshot did not resolve as Meddle")
            return
        }

        _ = try await preview.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("discovery.startChat"),
                "payload": .object([
                    "source": .string("binding-test"),
                    "targets": .list([
                        .object([
                            "displayName": .string("Ane Solberg"),
                            "headline": .string("Public sector interoperability")
                        ])
                    ])
                ])
            ]),
            requester: identity
        )

        let stateValue = try await snapshot.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue,
              case let .object(focusedThread)? = object["focusedThread"],
              case let .list(focusedActions)? = object["focusedActions"] else {
            Issue.record("Expected chat snapshot state with focused thread and actions")
            return
        }

        #expect(object["statusSummary"] != nil)
        #expect(object["selectionSummary"] == .string("Viser den delte tråden med Ane Solberg."))
        #expect(object["draftSummary"] == .string("Skriv en kort oppfølging til Ane Solberg og send den direkte fra denne flaten."))
        #expect(object["personaSummary"] == .string("Ane Solberg · Public sector interoperability"))
        #expect(object["simulationSummary"] == .string("Demo-svarene holder seg til en bounded persona som representerer offentlig samhandling og governance."))
        #expect(focusedThread["title"] == .string("Ane Solberg"))
        #expect(focusedThread["nextMessage"] == .string("Hei Ane. Jeg vil gjerne snakke mer om governance-sporet og hvordan du jobber med interoperabilitet i praksis."))
        #expect(object["connections"] != nil)
        #expect(object["recentMessages"] != nil)

        guard case let .object(firstAction)? = focusedActions.first else {
            Issue.record("Expected at least one focused chat action")
            return
        }
        #expect(firstAction["label"] == .string("Send forslag"))
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
        #expect(object["selectionSummary"] != nil)
        #expect(object["spatialTruthSummary"] != nil)
        #expect(object["radarLayout"] != nil)
        #expect(object["selectedEntity"] != nil)
        #expect(object["selectedEntityActions"] != nil)
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
        #expect(object["selectionSummary"] != nil)
        #expect(object["radarLayout"] != nil)
    }

    @Test func bindingLaunchWarmupMakesConferenceParticipantPreviewAndChatReadable() async throws {
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
        guard let preview = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantPreviewShell did not resolve as Meddle after launch warmup")
            return
        }
        guard let chat = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantChatSnapshot",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantChatSnapshot did not resolve as Meddle after launch warmup")
            return
        }

        let previewState = try await preview.get(keypath: "state", requester: identity)
        guard case let .object(previewObject) = previewState else {
            Issue.record("Expected object from ConferenceParticipantPreviewShell.state after launch warmup, got \(previewState)")
            return
        }
        #expect(previewObject["workspace"] != nil)
        #expect(previewObject["sharedConnections"] != nil)

        let chatState = try await chat.get(keypath: "state", requester: identity)
        guard case let .object(chatObject) = chatState else {
            Issue.record("Expected object from ConferenceParticipantChatSnapshot.state after launch warmup, got \(chatState)")
            return
        }
        #expect(chatObject["statusSummary"] != nil)
        #expect(chatObject["selectionSummary"] != nil)
        #expect(chatObject["nextStepSummary"] != nil)
    }

    @Test func bindingLaunchWarmupMakesConferenceParticipantSurfacesReadable() async throws {
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

        let expectedRootKeys: [(String, [String])] = [
            ("cell:///ConferenceParticipantAgendaSnapshot", ["viewSummary", "trackSummary", "actionSummary"]),
            ("cell:///ConferenceParticipantDiscoverySnapshot", ["status", "sourceSummary", "actionSummary"]),
            ("cell:///ConferenceParticipantMatchmakingSnapshot", ["status", "searchSummary", "actionSummary"]),
            ("cell:///ConferenceNearbyRadar", ["statusSummary", "selectionSummary", "actionSummary"])
        ]

        for (endpoint, keys) in expectedRootKeys {
            guard let cell = try await resolver.cellAtEndpoint(
                endpoint: endpoint,
                requester: identity
            ) as? Meddle else {
                Issue.record("\(endpoint) did not resolve as Meddle after launch warmup")
                continue
            }

            let state = try await cell.get(keypath: "state", requester: identity)
            guard case let .object(object) = state else {
                Issue.record("Expected object from \(endpoint).state after launch warmup, got \(state)")
                continue
            }

            for key in keys {
                #expect(object[key] != nil, "\(endpoint) missing \(key) after launch warmup")
            }
        }
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

    @Test func conferenceNearbyRadarSeparatesApproximateSignalsFromFocusedParticipantActions() async throws {
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

        _ = try await radar.set(
            keypath: "testInjectNearbyCandidate",
            value: .object([
                "remoteUUID": .string("nearby-approx-001"),
                "displayName": .string("Approx Nearby"),
                "matchScore": .float(0.34),
                "distanceMeters": .float(2.4),
                "hasDirection": .bool(false)
            ]),
            requester: identity
        )

        _ = try await radar.set(
            keypath: "testInjectVerifiedContact",
            value: .object([
                "remoteUUID": .string("nearby-verified-001"),
                "displayName": .string("Nora Berg"),
                "participantId": .string("participant-102"),
                "identityUUID": .string("identity-remote-123"),
                "company": .string("Polar Systems"),
                "role": .string("speaker"),
                "matchCount": .integer(2),
                "matchScore": .float(0.92),
                "distanceMeters": .float(1.6),
                "directionX": .float(0.0),
                "directionY": .float(0.0),
                "directionZ": .float(1.0)
            ]),
            requester: identity
        )

        let stateValue = try await radar.get(keypath: "state", requester: identity)
        guard case let .object(stateObject) = stateValue else {
            Issue.record("Expected object from ConferenceNearbyRadar.state after injecting nearby candidates, got \(stateValue)")
            return
        }

        guard case let .string(selectionSummary)? = stateObject["selectionSummary"] else {
            Issue.record("Expected selectionSummary in nearby radar state")
            return
        }
        #expect(selectionSummary.contains("Nora Berg"))

        guard case let .string(spatialTruthSummary)? = stateObject["spatialTruthSummary"] else {
            Issue.record("Expected spatialTruthSummary in nearby radar state")
            return
        }
        #expect(spatialTruthSummary.contains("retning usikker"))

        guard case let .object(selectedEntity)? = stateObject["selectedEntity"] else {
            Issue.record("Expected selectedEntity in nearby radar state")
            return
        }
        #expect(selectedEntity["title"] == .string("Nora Berg"))
        #expect(selectedEntity["relevanceBadge"] == .string("GRØNN MATCH"))
        #expect(selectedEntity["followUpSummary"] == .string("Kontakten er verifisert. Nå kan du starte chat eller markere for oppfølging."))
        #expect(selectedEntity["chatSummary"] == .string("Chat er ikke startet ennå. Neste steg er å trykke Start chat."))

        guard case let .string(matchSummary)? = stateObject["matchSummary"] else {
            Issue.record("Expected matchSummary in nearby radar state")
            return
        }
        #expect(matchSummary.contains("Sterk verifisert match"))

        guard case let .object(radarLayout)? = stateObject["radarLayout"],
              case let .object(centerNode)? = radarLayout["center"] else {
            Issue.record("Expected radarLayout.center in nearby radar state")
            return
        }
        #expect(centerNode["title"] == .string("Nora Berg"))
        #expect(centerNode["relevanceBadge"] == .string("GRØNN MATCH"))

        guard case let .list(selectedEntityActions)? = stateObject["selectedEntityActions"],
              case let .object(primaryAction)? = selectedEntityActions.first else {
            Issue.record("Expected selectedEntityActions in nearby radar state")
            return
        }
        #expect(primaryAction["label"] == .string("Start chat"))

        guard case let .list(sectors)? = stateObject["sectors"],
              case let .object(uncertainSector)? = sectors.first(where: { value in
                  guard case let .object(object) = value,
                        case let .string(title)? = object["title"] else {
                      return false
                  }
                  return title == "Retning usikker"
              }) else {
            Issue.record("Expected a Retning usikker sector in nearby radar state")
            return
        }
        #expect(uncertainSector["subtitle"] == .string("1 peer(s)"))
        #expect(uncertainSector["relevanceBadge"] == .string("RØD MATCH"))
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
        guard case let .string(beforeSummaryText) = beforeSummary else {
            Issue.record("Expected string action summary before dispatch through Porthole")
            return
        }
        #expect(
            beforeSummaryText == "Nearby-radaren er klar. Be om kontakt for å verifisere formål og interesser." ||
                beforeSummaryText == "Scanner kjører. Venter på nearby-deltagere."
        )

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
        guard case let .string(snapshotActionSummary)? = snapshot["actionSummary"] else {
            Issue.record("Expected string actionSummary in nearby radar snapshot")
            return
        }
        #expect(snapshotActionSummary.contains("Starting scanner") || snapshotActionSummary.contains("Scanner started"))

        let afterSummary = try await porthole.get(
            keypath: "nearbyRadar.state.actionSummary",
            requester: owner
        )
        guard case let .string(afterSummaryText) = afterSummary else {
            Issue.record("Expected string action summary after dispatch through Porthole")
            return
        }
        #expect(afterSummaryText.isEmpty == false)
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

        #expect(workspace["nextStep"] == .string("Started follow-up chat with Nora Berg in local preview."))
        #expect(sharedConnections["chatSummary"] == .string("2 shared message(s) visible."))

        guard case let .list(connections)? = sharedConnections["connections"] else {
            Issue.record("Expected shared connections list")
            return
        }
        #expect(connections.count == 1)

        guard case let .list(recentMessages)? = sharedConnections["recentMessages"],
              case let .object(firstMessage)? = recentMessages.first else {
            Issue.record("Expected recent messages list")
            return
        }
        #expect(firstMessage["detail"] == .string("Ja, gjerne. Jobber med tillit, relasjoner og hvordan identitet og oppfølging kan flyte mellom team. Hvis du vil, kan vi ta et kort neste steg etter sesjonen."))
    }

    @Test func conferenceParticipantPreviewFallbackSupportsRecommendationFocusAndFollowUpActions() async throws {
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

        _ = try await preview.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("agenda.setView"),
                "payload": .object([
                    "view": .string("timeline")
                ])
            ]),
            requester: identity
        )

        _ = try await preview.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("agenda.setTrackFocus"),
                "payload": .object([
                    "trackId": .string("track-governance")
                ])
            ]),
            requester: identity
        )

        _ = try await preview.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("matchmaking.focusPerson"),
                "payload": .object([
                    "displayName": .string("Ane Solberg"),
                    "subtitle": .string("Public sector interoperability")
                ])
            ]),
            requester: identity
        )

        _ = try await preview.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("matchmaking.toggleFollowUp"),
                "payload": .object([
                    "displayName": .string("Governance Forum"),
                    "subtitle": .string("Nearby people")
                ])
            ]),
            requester: identity
        )

        let stateValue = try await preview.get(keypath: "state", requester: identity)
        guard case let .object(stateObject) = stateValue,
              case let .object(workspace)? = stateObject["workspace"],
              case let .object(program)? = stateObject["program"],
              case let .object(matches)? = stateObject["matches"] else {
            Issue.record("Expected state object from conference participant preview fallback")
            return
        }

        #expect(workspace["nextStep"] == .string("Marked Governance Forum for follow-up in local preview."))
        #expect(program["viewSummary"] == .string("Current view: Timeline."))
        #expect(program["trackSummary"] == .string("Track focus: Governance."))
        #expect(program["timelineSummary"] == .string("8 session(s) visible in timeline view."))
        #expect(matches["recommendationSummary"] == .string("Focused recommendation: Ane Solberg. Open chat or mark follow-up when you are ready."))
        #expect(matches["status"] == .string("Focused on Ane Solberg. The next natural step is to start chat or mark follow-up."))
        #expect(matches["searchSummary"] == .string("Search broadening: people. 1 person(s) marked for follow-up."))

        guard case let .list(recommendations)? = matches["recommendations"],
              case let .object(firstRecommendation)? = recommendations.first else {
            Issue.record("Expected recommendations list in preview fallback state")
            return
        }
        #expect(firstRecommendation["label"] == .string("Start chat"))

        guard case let .list(searchResults)? = matches["searchResults"],
              case let .object(firstSearchResult)? = searchResults.first else {
            Issue.record("Expected search results list in preview fallback state")
            return
        }
        #expect(firstSearchResult["label"] == .string("Fjern markering"))
    }

    @Test func conferenceParticipantMatchmakingSnapshotSupportsInlineSelectionAndActions() async throws {
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
        guard let snapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantMatchmakingSnapshot",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantMatchmakingSnapshot did not resolve as Meddle")
            return
        }

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("matchmaking.focusPerson"),
                "payload": .object([
                    "displayName": .string("Ane Solberg"),
                    "subtitle": .string("Public sector interoperability")
                ])
            ]),
            requester: identity
        )

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("matchmaking.toggleFollowUp"),
                "payload": .object([
                    "displayName": .string("Ane Solberg"),
                    "subtitle": .string("Public sector interoperability")
                ])
            ]),
            requester: identity
        )

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("discovery.startChat"),
                "payload": .object([
                    "source": .string("binding-test"),
                    "targets": .list([
                        .object([
                            "displayName": .string("Ane Solberg"),
                            "headline": .string("Public sector interoperability")
                        ])
                    ])
                ])
            ]),
            requester: identity
        )

        let stateValue = try await snapshot.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue,
              case let .object(focusedProfile)? = object["focusedProfile"],
              case let .list(focusedActions)? = object["focusedActions"],
              case let .list(recommendations)? = object["recommendations"],
              case let .object(firstRecommendation)? = recommendations.first else {
            Issue.record("Expected matchmaking snapshot state with focused profile and actions")
            return
        }

        #expect(object["selectionSummary"] == .string("Viser Ane Solberg i denne siden."))
        #expect(focusedProfile["title"] == .string("Ane Solberg"))
        #expect(focusedProfile["publicProfileSummary"] == .string("Offentlig profil: Public sector interoperability."))
        #expect(focusedProfile["nextStep"] == .string("Bruk Start chat, Marker for oppfølging eller Be om møte med Ane Solberg."))
        #expect(firstRecommendation["label"] == .string("Valgt i siden"))

        guard case let .object(chatAction)? = focusedActions.first,
              case let .object(followUpAction)? = focusedActions.dropFirst().first,
              case let .object(meetingAction)? = focusedActions.dropFirst(2).first else {
            Issue.record("Expected three focused actions in matchmaking snapshot")
            return
        }

        #expect(chatAction["label"] == .string("Åpne chatflate"))
        #expect(followUpAction["label"] == .string("Fjern markering"))
        #expect(meetingAction["label"] == .string("Be om møte"))
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

    @Test func appleIntelligencePurposeMatcherUsesRichSelectableListForSuggestionSelection() {
        let configuration = ConfigurationCatalogCell.appleIntelligenceLandingConfiguration()

        guard let skeleton = configuration.skeleton else {
            Issue.record("Forventet skeleton for Apple Intelligence Purpose Matcher")
            return
        }

        #expect(skeletonContainsSelectableList(
            keypath: "catalog.matching.suggestions",
            topic: "catalog.matching.suggestions",
            selectionStateKeypath: "catalog.matching.selectedIndex",
            selectionActionKeypath: "catalog.matching.selectIndex",
            selectionValueKeypath: "rank",
            activationActionKeypath: "catalog.matching.loadSelectedToPorthole",
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
        #expect(configuration.discovery?.sourceCellEndpoint == "cell:///ConferenceAdminPreviewShell")
        #expect(configuration.discovery?.sourceCellName == "ConferenceAdminPreviewShellLocalFallbackCell")
        #expect(configurationString.contains("conferenceAdminShell.state.workspace.title"))
        #expect(configurationString.contains("conferenceAdminShell.state.content.intro"))
    }

    @Test func conferenceAdminPreviewShellUsesOrganizerRequesterDescriptor() async throws {
        let subject = ContentView()
        let descriptor = subject.preferredRequesterDescriptor(
            for: "cell://staging.haven.digipomps.org/ConferenceAdminPreviewShell"
        )

        #expect(descriptor?.identityContext == "conference-organizer@staging.haven.digipomps.org")
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
        let fixtureEndpoint = "cell:///ConferenceParticipantPreviewShellFixture"

        try? await resolver.addCellResolve(
            name: "ConferenceParticipantPreviewShellFixture",
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

        let configuration = makeConferenceParticipantPortalConfiguration(endpoint: fixtureEndpoint)
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
        #expect(titleValue == .string("Conference Participant Portal"))

        let agendaSummaryValue = try await porthole.get(
            keypath: "conferenceParticipantShell.state.program.agendaSummary",
            requester: owner
        )
        #expect(agendaSummaryValue == .string("2 saved session(s) · 6 recommended session(s)."))

        let recommendationSummaryValue = try await porthole.get(
            keypath: "conferenceParticipantShell.state.matches.recommendationSummary",
            requester: owner
        )
        #expect(recommendationSummaryValue == .string("3 recommended people with explainability."))

        let meetingSummaryValue = try await porthole.get(
            keypath: "conferenceParticipantShell.state.meetings.meetingSummary",
            requester: owner
        )
        #expect(meetingSummaryValue == .string("0 shared meeting(s) visible."))

        let chatSummaryValue = try await porthole.get(
            keypath: "conferenceParticipantShell.state.sharedConnections.chatSummary",
            requester: owner
        )
        #expect(chatSummaryValue == .string("0 shared message(s) visible."))

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
        #expect(recommendations.count == 3)

        let confirmedMeetingsValue = try await porthole.get(
            keypath: "conferenceParticipantShell.state.meetings.confirmedMeetings",
            requester: owner
        )
        guard case let .list(confirmedMeetings) = confirmedMeetingsValue else {
            Issue.record("Expected confirmed meetings list, got \(confirmedMeetingsValue)")
            return
        }
        #expect(confirmedMeetings.count == 0)

        let connectionsValue = try await porthole.get(
            keypath: "conferenceParticipantShell.state.sharedConnections.connections",
            requester: owner
        )
        guard case let .list(connections) = connectionsValue else {
            Issue.record("Expected shared connections list, got \(connectionsValue)")
            return
        }
        #expect(connections.count == 0)
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

    private func makeConferenceParticipantPortalConfiguration(
        endpoint: String = "cell:///ConferenceParticipantPreviewShell"
    ) -> CellConfiguration {
        var configuration = CellConfiguration(name: "Conference Participant Portal Dashboard")
        configuration.description = "Representative portal config using the preview-wrapper state contract."

        var reference = CellReference(
            endpoint: endpoint,
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

    private func skeletonContainsSelectableList(
        keypath: String,
        topic: String?,
        selectionStateKeypath: String,
        selectionActionKeypath: String,
        selectionValueKeypath: String,
        activationActionKeypath: String,
        in element: SkeletonElement
    ) -> Bool {
        switch element {
        case .List(let list):
            if list.keypath == keypath &&
                list.topic == topic &&
                list.selectionMode == .single &&
                list.selectionStateKeypath == selectionStateKeypath &&
                list.selectionActionKeypath == selectionActionKeypath &&
                list.selectionValueKeypath == selectionValueKeypath &&
                list.activationActionKeypath == activationActionKeypath &&
                list.selectionPayloadMode == .itemID &&
                list.allowsEmptySelection == false {
                return true
            }
            return list.flowElementSkeleton.map {
                skeletonContainsSelectableList(
                    keypath: keypath,
                    topic: topic,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    selectionValueKeypath: selectionValueKeypath,
                    activationActionKeypath: activationActionKeypath,
                    in: .VStack($0)
                )
            } ?? false
        case .VStack(let stack):
            return stack.elements.contains {
                skeletonContainsSelectableList(
                    keypath: keypath,
                    topic: topic,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    selectionValueKeypath: selectionValueKeypath,
                    activationActionKeypath: activationActionKeypath,
                    in: $0
                )
            }
        case .HStack(let stack):
            return stack.elements.contains {
                skeletonContainsSelectableList(
                    keypath: keypath,
                    topic: topic,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    selectionValueKeypath: selectionValueKeypath,
                    activationActionKeypath: activationActionKeypath,
                    in: $0
                )
            }
        case .ScrollView(let scroll):
            return scroll.elements.contains {
                skeletonContainsSelectableList(
                    keypath: keypath,
                    topic: topic,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    selectionValueKeypath: selectionValueKeypath,
                    activationActionKeypath: activationActionKeypath,
                    in: $0
                )
            }
        case .Section(let section):
            return (section.header.map {
                skeletonContainsSelectableList(
                    keypath: keypath,
                    topic: topic,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    selectionValueKeypath: selectionValueKeypath,
                    activationActionKeypath: activationActionKeypath,
                    in: $0
                )
            } ?? false) ||
                section.content.contains {
                    skeletonContainsSelectableList(
                        keypath: keypath,
                        topic: topic,
                        selectionStateKeypath: selectionStateKeypath,
                        selectionActionKeypath: selectionActionKeypath,
                        selectionValueKeypath: selectionValueKeypath,
                        activationActionKeypath: activationActionKeypath,
                        in: $0
                    )
                } ||
                (section.footer.map {
                    skeletonContainsSelectableList(
                        keypath: keypath,
                        topic: topic,
                        selectionStateKeypath: selectionStateKeypath,
                        selectionActionKeypath: selectionActionKeypath,
                        selectionValueKeypath: selectionValueKeypath,
                        activationActionKeypath: activationActionKeypath,
                        in: $0
                    )
                } ?? false)
        case .Reference(let reference):
            return reference.flowElementSkeleton.map {
                skeletonContainsSelectableList(
                    keypath: keypath,
                    topic: topic,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    selectionValueKeypath: selectionValueKeypath,
                    activationActionKeypath: activationActionKeypath,
                    in: .VStack($0)
                )
            } ?? false
        case .Grid(let grid):
            return grid.elements.contains {
                skeletonContainsSelectableList(
                    keypath: keypath,
                    topic: topic,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    selectionValueKeypath: selectionValueKeypath,
                    activationActionKeypath: activationActionKeypath,
                    in: $0
                )
            }
        case .ZStack(let stack):
            return stack.elements.contains {
                skeletonContainsSelectableList(
                    keypath: keypath,
                    topic: topic,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    selectionValueKeypath: selectionValueKeypath,
                    activationActionKeypath: activationActionKeypath,
                    in: $0
                )
            }
        case .Object(let object):
            return object.elements.values.contains {
                skeletonContainsSelectableList(
                    keypath: keypath,
                    topic: topic,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    selectionValueKeypath: selectionValueKeypath,
                    activationActionKeypath: activationActionKeypath,
                    in: $0
                )
            }
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

enum ConferenceVerifierFixtureSupport {
    static func ensureRegistered(on resolver: CellResolver) async {
        await register(
            name: "ConferenceParticipantPreviewShellFixture",
            type: ConferenceParticipantPreviewShellFixtureCell.self,
            on: resolver
        )
        await register(
            name: "ConferencePublicShellFixture",
            type: ConferencePublicShellFixtureCell.self,
            on: resolver
        )
        await register(
            name: "ConferenceSponsorShellFixture",
            type: ConferenceSponsorShellFixtureCell.self,
            on: resolver
        )
    }

    private static func register<CellType: Emit & OwnerInstantiable>(
        name: String,
        type: CellType.Type,
        on resolver: CellResolver
    ) async {
        do {
            try await resolver.addCellResolve(
                name: name,
                cellScope: .scaffoldUnique,
                persistency: .persistant,
                identityDomain: "private",
                type: type
            )
        } catch {
            let description = String(describing: error).lowercased()
            guard !description.contains("duplicatedendpointname"),
                  !description.contains("registeratalreadytakenendpoint") else {
                return
            }
            Issue.record("Could not register \(name) fixture: \(error)")
        }
    }
}

private func timelineCard(
    title: String,
    subtitle: String,
    detail: String,
    note: String
) -> ValueType {
    .object([
        "title": .string(title),
        "subtitle": .string(subtitle),
        "detail": .string(detail),
        "note": .string(note)
    ])
}

private func titleDetailRow(
    title: String,
    detail: String
) -> ValueType {
    .object([
        "title": .string(title),
        "detail": .string(detail)
    ])
}

private func titleSubtitleDetailRow(
    title: String,
    subtitle: String,
    detail: String
) -> ValueType {
    .object([
        "title": .string(title),
        "subtitle": .string(subtitle),
        "detail": .string(detail)
    ])
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
            "title": .string("Conference Participant Portal"),
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
            "agendaSummary": .string("2 saved session(s) · 6 recommended session(s)."),
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
            "status": .string("Recommendations are derived from onboarding interests, purpose signals, and optional track focus."),
            "recommendationSummary": .string("3 recommended people with explainability."),
            "recommendations": .list([
                .object([
                    "displayName": .string("Ane Solberg"),
                    "headline": .string("Public sector interoperability lead")
                ]),
                .object([
                    "displayName": .string("Mads Hovden"),
                    "headline": .string("Policy and compliance facilitator")
                ]),
                .object([
                    "displayName": .string("Lea Heger"),
                    "headline": .string("Digital service design")
                ])
            ])
        ]),
        "meetings": .object([
            "intro": .string("Meeting planning stays inside the participant shell."),
            "requestSummary": .string("0 shared request(s) visible."),
            "slotSummary": .string("5 viable slots overlap with your saved sessions."),
            "meetingSummary": .string("0 shared meeting(s) visible."),
            "exportStatus": .string("No iCal export prepared yet."),
            "confirmedMeetings": .list([])
        ]),
        "sharedConnections": .object([
            "intro": .string("Shared relations help you continue the right conversations."),
            "accessSummary": .string("Shared threads are visible to participating parties."),
            "connectionSummary": .string("0 shared relation(s) visible."),
            "chatSummary": .string("0 shared message(s) visible."),
            "connections": .list([]),
            "recentMessages": .list([])
        ])
    ]
}

private final class ConferencePublicShellFixtureCell: GeneralCell {
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
            "title": .string("AI & Digital Independence"),
            "subtitle": .string("Conference public surface for the live program, people, articles and facilities."),
            "dateBadge": .string("30. mars"),
            "venueBadge": .string("Oslo"),
            "ctaTitle": .string("Join the public program"),
            "ctaDetail": .string("Tracks, sessions and facilities are now published for everyone.")
        ]),
        "access": .object([
            "headline": .string("Public conference publication scope"),
            "ownerScope": .string("Owner: conference public publisher"),
            "readScope": .string("Read: public audience"),
            "writeScope": .string("Write: public publishing pipeline"),
            "deliveryScope": .string("Delivery: published surfaces only"),
            "storageScope": .string("Storage: scaffold publication state"),
            "notes": .string("This fixture mirrors the public-shell contract without pretending to be staging."),
            "keypathMatrix": .list([
                timelineCard(title: "workspace.*", subtitle: "Public landing", detail: "Title, badges and CTA", note: "Readable"),
                timelineCard(title: "tracks/sessions", subtitle: "Published program", detail: "Tracks and sessions visible to attendees", note: "Readable")
            ])
        ]),
        "tracksIntro": .string("Tracks currently highlighted for the public audience."),
        "tracks": .list([
            titleDetailRow(title: "Trusted AI", detail: "Governance, controls and public interest deployment."),
            titleDetailRow(title: "Digital Independence", detail: "Infrastructure, procurement and resilient service design.")
        ]),
        "sessionsIntro": .string("Featured sessions from the published conference program."),
        "sessions": .list([
            titleSubtitleDetailRow(title: "Opening keynote", subtitle: "Main stage", detail: "Why trustworthy AI needs better institutional memory."),
            titleSubtitleDetailRow(title: "Implementation roundtable", subtitle: "Room B", detail: "How public-sector teams move from pilots to dependable delivery.")
        ]),
        "peopleIntro": .string("People currently highlighted on the public surface."),
        "people": .list([
            titleSubtitleDetailRow(title: "Ane Solberg", subtitle: "Public sector interoperability", detail: "Speaking on procurement, coordination and follow-up."),
            titleSubtitleDetailRow(title: "Mads Hovden", subtitle: "Policy and compliance", detail: "Moderating the governance track discussion.")
        ]),
        "articlesIntro": .string("Editorial highlights and conference explainers."),
        "articles": .list([
            titleSubtitleDetailRow(title: "Why this conference now", subtitle: "Editorial", detail: "Explains the public framing for AI and digital independence."),
            titleSubtitleDetailRow(title: "How to navigate the day", subtitle: "Guide", detail: "Program guide for attendees and visitors.")
        ]),
        "facilitiesIntro": .string("Facilities and practical venue information."),
        "facilities": .list([
            titleSubtitleDetailRow(title: "Main stage", subtitle: "Ground floor", detail: "Keynotes and plenary sessions."),
            titleSubtitleDetailRow(title: "Quiet work area", subtitle: "Second floor", detail: "Space for follow-up and focused conversation.")
        ])
    ]
}

private final class ConferenceSponsorShellFixtureCell: GeneralCell {
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
            "title": .string("Conference Sponsor Follow-up"),
            "subtitle": .string("Sponsor-owned inbox, compliance and retention overview."),
            "conferenceBadge": .string("Conference"),
            "sponsorBadge": .string("Sponsor"),
            "pipelineBadge": .string("Pipeline active"),
            "retentionBadge": .string("Retention ready"),
            "creditBadge": .string("Credits healthy"),
            "nextStep": .string("Refresh the inbox, prepare export, and clear the retention review queue."),
            "previewNotice": .string("Fixture mirrors the sponsor-shell contract for deterministic verification.")
        ]),
        "access": .object([
            "headline": .string("Sponsor follow-up access scope"),
            "ownerScope": .string("Owner: sponsor workspace"),
            "readScope": .string("Read: sponsor lead inbox"),
            "writeScope": .string("Write: sponsor follow-up operations"),
            "deliveryScope": .string("Delivery: sponsor exports and unlock handoff"),
            "storageScope": .string("Storage: consented sponsor data only"),
            "notes": .string("Retention and export steps stay inside sponsor-owned state."),
            "keypathMatrix": .list([
                timelineCard(title: "followUp.*", subtitle: "Lead inbox", detail: "Pickup and qualified leads", note: "Readable"),
                timelineCard(title: "retention.*", subtitle: "Retention controls", detail: "Unlocks, reclaim and review queue", note: "Readable")
            ])
        ]),
        "followUp": .object([
            "intro": .string("Lead inbox for sponsor-owned pickup and qualification."),
            "pickupSummary": .string("2 pickup leads waiting."),
            "qualificationSummary": .string("1 qualified lead ready for export."),
            "status": .string("Inbox is synchronized."),
            "pickupLeads": .list([
                timelineCard(title: "Ingrid Nilsen", subtitle: "Municipal AI lead", detail: "Asked for a short follow-up after the keynote.", note: "Pickup"),
                timelineCard(title: "Jon Hauge", subtitle: "Digital procurement", detail: "Interested in sponsor roundtable materials.", note: "Pickup")
            ]),
            "qualifiedLeads": .list([
                timelineCard(title: "Lea Heger", subtitle: "Service design", detail: "Qualified after consent review and sponsor handoff.", note: "Qualified")
            ])
        ]),
        "compliance": .object([
            "intro": .string("Consent, agreement and chronicle review for sponsor follow-up."),
            "consentSummary": .string("All exported leads have explicit consent receipts."),
            "agreementSummary": .string("Agreement template is current."),
            "chronicleSummary": .string("Chronicle entries ready for sponsor audit."),
            "status": .string("Compliance checks are green."),
            "consentReceipts": .list([
                timelineCard(title: "Receipt #104", subtitle: "Lea Heger", detail: "Consent captured for sponsor follow-up export.", note: "Valid")
            ])
        ]),
        "retention": .object([
            "creditSummary": .string("Credits remain within sponsor allocation."),
            "unlockSummary": .string("1 unlock action is pending approval."),
            "reclaimSummary": .string("No reclaims needed right now."),
            "reviewSummary": .string("2 review items in the retention queue."),
            "policySummary": .string("Retention policy is aligned with sponsor agreement."),
            "slaSummary": .string("Next retention review due tomorrow."),
            "exportStatus": .string("Last export pack prepared 10 minutes ago."),
            "reviewQueue": .list([
                timelineCard(title: "Review Lea Heger", subtitle: "Retention queue", detail: "Check unlock scope before export.", note: "Pending"),
                timelineCard(title: "Review Ingrid Nilsen", subtitle: "Retention queue", detail: "Confirm follow-up objective and SLA.", note: "Pending")
            ]),
            "unlockedLeads": .list([
                timelineCard(title: "Mads Hovden", subtitle: "Unlocked lead", detail: "Ready for sponsor-owned next step.", note: "Unlocked")
            ])
        ])
    ]
}

@Suite(.serialized)
struct CellConfigurationVerifierTests {
    @Test func conferenceParticipantPortalContractVerifierKeepsBindingsAndActionsReachable() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Vis for deg",
                "Vis timeline",
                "Vis lagret",
                "Fokuser governance"
            ],
            rootProbes: [
                .init(label: "agendaSnapshot", rootKeypath: "state"),
                .init(label: "matchmakingSnapshot", rootKeypath: "state"),
                .init(label: "discoverySnapshot", rootKeypath: "state"),
                .init(label: "nearbyRadar", rootKeypath: "state")
            ]
        )

        #expect(report.validation.errorCount == 0)
        #expect(report.unresolvedReferences.isEmpty)
        #expect(report.unreadableRootProbes.isEmpty)
        #expect(report.failedActions.isEmpty)
    }

    @Test func conferenceParticipantPortalNearbyVerifierCanOpenFollowUpChat() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )

        let report = try await CellConfigurationVerifier.nearbyFollowUpReport(for: configuration)

        #expect(report.startSucceeded)
        #expect(report.statusAfterStart == "started")
        #expect(report.requestContactSucceeded)
        #expect(report.requestContactLabel == "Kontakt venter")
        #expect(report.requestContactSummary == "Signert kontaktforespørsel sendt. Venter på godkjenning.")
        #expect(report.requestContactActionSummary == "Signert kontaktforespørsel sendt. Venter på godkjenning.")
        #expect(report.chatOpened)
        #expect(report.nearbyCardLabel == "Åpne chatflate")
        #expect(report.nearbyCardPurposeSummary?.contains("verified overlap") == true)
        #expect(report.nearbyActionSummary == "Startet conference-chat med Nora Berg.")
        #expect(report.workspaceNextStep == "Started follow-up chat with Nora Berg in local preview.")
        #expect(report.sharedChatSummary == "2 shared message(s) visible.")
        #expect(report.firstRecentMessage == "Ja, gjerne. La oss fortsette praten om governance og oppfølging etter neste sesjon.")
        #expect(report.stopSucceeded)
        #expect(report.statusAfterStop == "stopped")
    }

    @Test func conferenceNearbyRadarContractVerifierKeepsBindingsAndActionsReachable() async throws {
        let configuration = ConfigurationCatalogCell.conferenceNearbyRadarWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Start scanner",
                "Stop scanner",
                "Tilbake til portalen"
            ]
        )

        #expect(report.validation.errorCount == 0)
        #expect(report.unresolvedReferences.isEmpty)
        #expect(report.unreadableRootProbes.isEmpty)
        #expect(report.failedActions.isEmpty)
    }

    @Test func conferenceNearbyParticipantProfileContractVerifierKeepsBindingsAndActionsReachable() async throws {
        let configuration = ConfigurationCatalogCell.conferenceNearbyParticipantWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Åpne full radar",
                "Tilbake til portalen"
            ]
        )

        #expect(report.validation.errorCount == 0)
        #expect(report.unresolvedReferences.isEmpty)
        #expect(report.unreadableRootProbes.isEmpty)
        #expect(report.failedActions.isEmpty)
    }

    @Test func conferenceParticipantChatContractVerifierKeepsBindingsAndActionsReachable() async throws {
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

        #expect(report.validation.errorCount == 0)
        #expect(report.unresolvedReferences.isEmpty)
        #expect(report.unreadableRootProbes.isEmpty)
        #expect(report.failedActions.isEmpty)
    }

#if canImport(AppKit)
    @MainActor
    @Test func conferenceParticipantPortalRendererVerifierBuildsVisibleMacOSSurface() async throws {
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
                "Åpne full radar"
            ]
        )

        #expect(report.snapshotByteCount > 0, "Expected a non-empty rendered snapshot")
        #expect(report.subviewCount > 0)
        #expect(report.totalRenderMilliseconds > 0)
        #expect(report.unavailableNowCount == 0)
    }

    @MainActor
    @Test func conferenceNearbyRadarRendererVerifierBuildsVisibleMacOSSurface() async throws {
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

        #expect(report.snapshotByteCount > 0, "Expected a non-empty rendered snapshot")
        #expect(report.subviewCount > 0)
        #expect(report.totalRenderMilliseconds > 0)
    }

    @MainActor
    @Test func conferenceNearbyParticipantProfileRendererVerifierBuildsVisibleMacOSSurface() async throws {
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

        #expect(report.snapshotByteCount > 0, "Expected a non-empty rendered snapshot")
        #expect(report.subviewCount > 0)
        #expect(report.totalRenderMilliseconds > 0)
    }

    @MainActor
    @Test func conferenceParticipantChatRendererVerifierBuildsVisibleMacOSSurface() async throws {
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

        #expect(report.snapshotByteCount > 0, "Expected a non-empty rendered snapshot")
        #expect(report.subviewCount > 0)
        #expect(report.totalRenderMilliseconds > 0)
    }
#endif
}

enum CellConfigurationVerifier {
    struct ReferenceResolution: Hashable {
        let label: String
        let endpoint: String
        let durationMilliseconds: Double
        let outcome: String

        var resolved: Bool { outcome == "ok" }
    }

    struct RootProbeResolution: Hashable {
        let probe: SkeletonBindingProbeSupport.RootProbe
        let durationMilliseconds: Double
        let outcome: String

        var readable: Bool { outcome == "ok" }
    }

    struct ActionExecution: Hashable {
        let label: String
        let keypath: String
        let url: String?
        let durationMilliseconds: Double
        let outcome: String

        var succeeded: Bool { outcome == "ok" }
    }

    struct ContractReport {
        let configuration: CellConfiguration
        let validation: CellConfigurationValidationReport
        let referenceResolutions: [ReferenceResolution]
        let rootProbeResolutions: [RootProbeResolution]
        let actionExecutions: [ActionExecution]
        let loadMilliseconds: Double
        let totalMilliseconds: Double

        var unresolvedReferences: [ReferenceResolution] {
            referenceResolutions.filter { !$0.resolved }
        }

        var unreadableRootProbes: [SkeletonBindingProbeSupport.RootProbe: String] {
            Dictionary(
                uniqueKeysWithValues: rootProbeResolutions
                    .filter {
                        guard !$0.readable else { return false }
                        return !($0.probe.rootKeypath == "state" && $0.outcome == "denied")
                    }
                    .map { ($0.probe, $0.outcome) }
            )
        }

        var failedActions: [ActionExecution] {
            actionExecutions.filter { !$0.succeeded }
        }
    }

    struct NearbyFollowUpReport {
        let configuration: CellConfiguration
        let injectedRemoteUUID: String
        let startDurationMilliseconds: Double
        let requestContactDurationMilliseconds: Double
        let injectDurationMilliseconds: Double
        let openChatDurationMilliseconds: Double
        let stopDurationMilliseconds: Double
        let startOutcome: String
        let requestContactOutcome: String
        let nearbyCardLabel: String?
        let nearbyCardPurposeSummary: String?
        let nearbyActionSummary: String?
        let requestContactLabel: String?
        let requestContactSummary: String?
        let requestContactActionSummary: String?
        let workspaceNextStep: String?
        let sharedChatSummary: String?
        let firstRecentMessage: String?
        let openChatOutcome: String
        let stopOutcome: String
        let statusAfterStart: String?
        let statusAfterStop: String?

        var startSucceeded: Bool { startOutcome == "ok" }
        var requestContactSucceeded: Bool { requestContactOutcome == "ok" }
        var chatOpened: Bool { openChatOutcome == "ok" }
        var stopSucceeded: Bool { stopOutcome == "ok" }
    }

#if canImport(AppKit)
    @MainActor
    struct RenderReport {
        let visibleStrings: Set<String>
        let buttonTitles: Set<String>
        let snapshotByteCount: Int
        let subviewCount: Int
        let firstMeaningfulContentMilliseconds: Double
        let totalRenderMilliseconds: Double

        var unavailableNowCount: Int {
            visibleStrings.filter { $0.contains("Innholdet er ikke tilgjengelig akkurat nå.") }.count
        }
    }
#endif

    static func contractReport(
        for configuration: CellConfiguration,
        buttonsToExecute: Set<String> = [],
        rootProbes: [SkeletonBindingProbeSupport.RootProbe]? = nil
    ) async throws -> ContractReport {
        let clock = ContinuousClock()
        let overallStart = clock.now
        let context = try await makeRuntimeContext(for: configuration)
        let directBindingCandidates = directReadableBindings(for: context.configuration)
        let probes = rootProbes ?? SkeletonBindingProbeSupport.rootProbes(for: context.configuration)

        let referenceResolutions = try await resolveReferences(
            flattenReferences(from: context.configuration.cellReferences ?? []),
            resolver: context.resolver,
            requester: context.owner
        )

        let loadStart = clock.now
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)
        let loadMilliseconds = milliseconds(since: loadStart, clock: clock)

        let probeResolutions = try await readRootProbes(
            probes,
            bindingCandidates: directBindingCandidates,
            from: context.porthole,
            requester: context.owner
        )

        let actionExecutions = try await executeStaticButtons(
            in: context.configuration.skeleton,
            allowedLabels: buttonsToExecute,
            porthole: context.porthole,
            resolver: context.resolver,
            requester: context.owner
        )

        return ContractReport(
            configuration: context.configuration,
            validation: context.validation,
            referenceResolutions: referenceResolutions,
            rootProbeResolutions: probeResolutions,
            actionExecutions: actionExecutions,
            loadMilliseconds: loadMilliseconds,
            totalMilliseconds: milliseconds(since: overallStart, clock: clock)
        )
    }

    static func nearbyFollowUpReport(
        for configuration: CellConfiguration,
        remoteUUID: String = "nearby-verified-001",
        displayName: String = "Nora Berg"
    ) async throws -> NearbyFollowUpReport {
        typealias NearbySnapshot = (
            status: String?,
            actionSummary: String?,
            cardLabel: String?,
            purposeSummary: String?,
            note: String?
        )

        let clock = ContinuousClock()
        let context = try await makeRuntimeContext(for: configuration)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)
        guard let nearbyRadar = try await context.resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceNearbyRadar",
            requester: context.owner
        ) as? Meddle else {
            throw NSError(
                domain: "CellConfigurationVerifier",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Could not resolve ConferenceNearbyRadar for nearby follow-up verifier"]
            )
        }

        func nearbyStateSnapshot(
            from value: ValueType
        ) -> NearbySnapshot {
            guard case let .object(rawObject) = value else {
                return (nil, nil, nil, nil, nil)
            }

            let object: Object
            if rawObject["statusBadge"] != nil || rawObject["nearby"] != nil || rawObject["actionSummary"] != nil {
                object = rawObject
            } else if case let .object(stateObject)? = rawObject["state"] {
                object = stateObject
            } else {
                object = rawObject
            }

            let status = valueString(object["statusBadge"]) ?? valueString(object["status"])
            let actionSummary = valueString(object["actionSummary"])
            let selectedEntity: Object?
            if case let .object(value)? = object["selectedEntity"] {
                selectedEntity = value
            } else {
                selectedEntity = nil
            }
            let selectedActions: [ValueType]
            if case let .list(value)? = object["selectedEntityActions"] {
                selectedActions = value
            } else {
                selectedActions = []
            }
            let selectedPrimaryAction: Object?
            selectedPrimaryAction = selectedActions.compactMap { action -> Object? in
                guard case let .object(value) = action else {
                    return nil
                }
                let title = valueString(value["title"])?.lowercased()
                let label = valueString(value["label"])?.lowercased()
                if title == "kontakt" || title == "chat" {
                    return value
                }
                if label == "be om kontakt" ||
                    label == "kobler til..." ||
                    label == "kontakt venter" ||
                    label == "start chat" ||
                    label == "åpne chat" {
                    return value
                }
                return nil
            }.first ?? selectedActions.first.flatMap { action in
                guard case let .object(value) = action else {
                    return nil
                }
                return value
            }

            return (
                status,
                actionSummary,
                valueString(selectedPrimaryAction?["label"]),
                valueString(selectedEntity?["purposeSummary"]),
                valueString(selectedEntity?["note"])
            )
        }

        func readNearbyState(operation: String) async throws -> ValueType {
            try await withTimeout(
                seconds: 5,
                operation: operation
            ) {
                try await nearbyRadar.get(
                    keypath: "state",
                    requester: context.owner
                )
            }
        }

        func readNearbyStatus(
            expectedStatus: String,
            from response: ValueType?,
            readOperation: String
        ) async throws -> String? {
            func actionSummaryImpliesExpectedStatus(_ snapshot: NearbySnapshot?) -> Bool {
                guard let actionSummary = snapshot?.actionSummary?.lowercased() else {
                    return false
                }
                switch expectedStatus {
                case "started":
                    return actionSummary.contains("scanner started") || actionSummary.contains("starting scanner")
                case "stopped":
                    return actionSummary.contains("scanner stopped") || actionSummary.contains("stopping scanner")
                default:
                    return false
                }
            }

            let responseSnapshot = response.map(nearbyStateSnapshot(from:))
            if responseSnapshot?.status == expectedStatus {
                return responseSnapshot?.status
            }
            if actionSummaryImpliesExpectedStatus(responseSnapshot) {
                return expectedStatus
            }

            do {
                let awaitedSnapshot = try await waitForNearbySnapshot(
                    operation: readOperation,
                    timeoutSeconds: 3,
                    pollIntervalNanoseconds: 120_000_000
                ) { snapshot in
                    snapshot.status == expectedStatus || actionSummaryImpliesExpectedStatus(snapshot)
                }

                if awaitedSnapshot.status == expectedStatus {
                    return awaitedSnapshot.status
                }
                if actionSummaryImpliesExpectedStatus(awaitedSnapshot) {
                    return expectedStatus
                }
                return awaitedSnapshot.status ?? responseSnapshot?.status
            } catch {
                let stateSnapshot = nearbyStateSnapshot(
                    from: try await readNearbyState(operation: readOperation)
                )
                if stateSnapshot.status == expectedStatus {
                    return stateSnapshot.status
                }
                if actionSummaryImpliesExpectedStatus(stateSnapshot) {
                    return expectedStatus
                }
                return stateSnapshot.status ?? responseSnapshot?.status
            }
        }

        func waitForNearbySnapshot(
            operation: String,
            timeoutSeconds: Double = 5,
            pollIntervalNanoseconds: UInt64 = 50_000_000,
            until predicate: @escaping @Sendable (NearbySnapshot) -> Bool
        ) async throws -> NearbySnapshot {
            try await withTimeout(
                seconds: timeoutSeconds,
                operation: operation
            ) {
                while true {
                    let snapshot = nearbyStateSnapshot(
                        from: try await nearbyRadar.get(
                            keypath: "state",
                            requester: context.owner
                        )
                    )
                    if predicate(snapshot) {
                        return snapshot
                    }
                    try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
                }
            }
        }

        let startStart = clock.now
        let startResponse = try await withTimeout(
            seconds: 5,
            operation: "startNearbyScanner"
        ) {
            try await nearbyRadar.set(
                keypath: "dispatchAction",
                value: .object([
                    "keypath": .string("start"),
                    "payload": .bool(true)
                ]),
                requester: context.owner
            )
        }
        let startDuration = milliseconds(since: startStart, clock: clock)
        let startOutcome = startResponse.flatMap(SkeletonBindingProbeSupport.failureDetail(from:)) ?? "ok"
        let statusAfterStart = try await readNearbyStatus(
            expectedStatus: "started",
            from: startResponse,
            readOperation: "readNearbyStateAfterStart"
        )

        let candidateInjectPayload: Object = [
            "remoteUUID": .string(remoteUUID),
            "displayName": .string(displayName),
            "participantId": .string("participant-102"),
            "identityUUID": .string("identity-remote-123"),
            "company": .string("Polar Systems"),
            "role": .string("speaker"),
            "matchCount": .integer(0),
            "matchScore": .float(0.41),
            "distanceMeters": .float(1.6),
            "directionX": .float(0.0),
            "directionY": .float(0.0),
            "directionZ": .float(1.0)
        ]

        _ = try await withTimeout(
            seconds: 5,
            operation: "injectNearbyCandidate"
        ) {
            try await nearbyRadar.set(
                keypath: "testInjectNearbyCandidate",
                value: .object(candidateInjectPayload),
                requester: context.owner
            )
        }

        let requestContactStart = clock.now
        let requestContactResponse = try await withTimeout(
            seconds: 5,
            operation: "requestNearbyContact"
        ) {
            try await nearbyRadar.set(
                keypath: "dispatchAction",
                value: .object([
                    "keypath": .string("requestContact"),
                    "payload": .string(remoteUUID)
                ]),
                requester: context.owner
            )
        }
        let requestContactDuration = milliseconds(since: requestContactStart, clock: clock)
        let requestContactOutcome = requestContactResponse.flatMap(SkeletonBindingProbeSupport.failureDetail(from:)) ?? "ok"
        let immediateRequestContactSnapshot = requestContactResponse.map(nearbyStateSnapshot(from:))
        let requestContactSnapshot: NearbySnapshot
        if let immediateRequestContactSnapshot,
           immediateRequestContactSnapshot.cardLabel == "Kontakt venter" ||
           immediateRequestContactSnapshot.actionSummary == "Signert kontaktforespørsel sendt. Venter på godkjenning." {
            requestContactSnapshot = immediateRequestContactSnapshot
        } else {
            requestContactSnapshot = try await waitForNearbySnapshot(
                operation: "waitForNearbyStateAfterRequestContact"
            ) { snapshot in
                snapshot.cardLabel == "Kontakt venter" ||
                snapshot.actionSummary == "Signert kontaktforespørsel sendt. Venter på godkjenning."
            }
        }
        let requestContactLabel = requestContactSnapshot.cardLabel
        let requestContactSummary = requestContactSnapshot.note
        let requestContactActionSummary = requestContactSnapshot.actionSummary

        let injectPayload: Object = [
            "remoteUUID": .string(remoteUUID),
            "displayName": .string(displayName),
            "participantId": .string("participant-102"),
            "identityUUID": .string("identity-remote-123"),
            "company": .string("Polar Systems"),
            "role": .string("speaker"),
            "matchCount": .integer(2),
            "matchScore": .float(0.92),
            "distanceMeters": .float(1.6),
            "directionX": .float(0.0),
            "directionY": .float(0.0),
            "directionZ": .float(1.0)
        ]

        let injectStart = clock.now
        _ = try await withTimeout(
            seconds: 5,
            operation: "injectVerifiedNearbyContact"
        ) {
            try await nearbyRadar.set(
                keypath: "testInjectVerifiedContact",
                value: .object(injectPayload),
                requester: context.owner
            )
        }
        let injectDuration = milliseconds(since: injectStart, clock: clock)

        var nearbySnapshot = nearbyStateSnapshot(
            from: try await readNearbyState(operation: "readNearbyStateAfterVerifiedInjection")
        )
        var nearbyCardLabel = nearbySnapshot.cardLabel
        var nearbyCardPurposeSummary = nearbySnapshot.purposeSummary
        var nearbyActionSummary = nearbySnapshot.actionSummary

        let openChatStart = clock.now
        let openChatResponse: ValueType?
        do {
            openChatResponse = try await withTimeout(
                seconds: 5,
                operation: "openNearbyFollowUpChat"
            ) {
                try await nearbyRadar.set(
                    keypath: "dispatchAction",
                    value: .object([
                        "keypath": .string("openFollowUpChat"),
                        "payload": .object(["remoteUUID": .string(remoteUUID)])
                    ]),
                    requester: context.owner
                )
            }
        } catch {
            return NearbyFollowUpReport(
                configuration: context.configuration,
                injectedRemoteUUID: remoteUUID,
                startDurationMilliseconds: startDuration,
                requestContactDurationMilliseconds: requestContactDuration,
                injectDurationMilliseconds: injectDuration,
                openChatDurationMilliseconds: milliseconds(since: openChatStart, clock: clock),
                stopDurationMilliseconds: 0,
                startOutcome: startOutcome,
                requestContactOutcome: requestContactOutcome,
                nearbyCardLabel: nearbyCardLabel,
                nearbyCardPurposeSummary: nearbyCardPurposeSummary,
                nearbyActionSummary: nearbyActionSummary,
                requestContactLabel: requestContactLabel,
                requestContactSummary: requestContactSummary,
                requestContactActionSummary: requestContactActionSummary,
                workspaceNextStep: nil,
                sharedChatSummary: nil,
                firstRecentMessage: nil,
                openChatOutcome: String(describing: error),
                stopOutcome: "not-run",
                statusAfterStart: statusAfterStart,
                statusAfterStop: nil
            )
        }
        let openChatDuration = milliseconds(since: openChatStart, clock: clock)
        let openChatOutcome: String
        if let openChatResponse {
            openChatOutcome = SkeletonBindingProbeSupport.failureDetail(from: openChatResponse) ?? "ok"
        } else {
            openChatOutcome = "nil"
        }

        nearbySnapshot = nearbyStateSnapshot(
            from: try await readNearbyState(operation: "readNearbyStateAfterOpenChat")
        )
        nearbyActionSummary = nearbySnapshot.actionSummary
        nearbyCardLabel = nearbySnapshot.cardLabel
        nearbyCardPurposeSummary = nearbySnapshot.purposeSummary

        guard let participantPreview = try await context.resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: context.owner
        ) as? Meddle else {
            throw NSError(
                domain: "CellConfigurationVerifier",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: "Could not resolve ConferenceParticipantPreviewShell for nearby follow-up verifier"]
            )
        }

        let participantStateValue = try await withTimeout(
            seconds: 5,
            operation: "readParticipantPreviewStateAfterNearbyChat"
        ) {
            try await participantPreview.get(
                keypath: "state",
                requester: context.owner
            )
        }

        let firstRecentMessage: String?
        let workspaceNextStep: String?
        let sharedChatSummary: String?
        if case let .object(stateObject) = participantStateValue {
            let workspace: Object?
            if case let .object(workspaceObject)? = stateObject["workspace"] {
                workspace = workspaceObject
            } else {
                workspace = nil
            }
            let sharedConnections: Object?
            if case let .object(sharedConnectionsObject)? = stateObject["sharedConnections"] {
                sharedConnections = sharedConnectionsObject
            } else {
                sharedConnections = nil
            }

            workspaceNextStep = valueString(workspace?["nextStep"])
            sharedChatSummary = valueString(sharedConnections?["chatSummary"])
            if case let .list(messages)? = sharedConnections?["recentMessages"],
               case let .object(firstMessage)? = messages.first {
                firstRecentMessage = valueString(firstMessage["detail"])
            } else {
                firstRecentMessage = nil
            }
        } else {
            workspaceNextStep = nil
            sharedChatSummary = nil
            firstRecentMessage = nil
        }

        let stopStart = clock.now
        let stopResponse = try await withTimeout(
            seconds: 5,
            operation: "stopNearbyScanner"
        ) {
            try await nearbyRadar.set(
                keypath: "dispatchAction",
                value: .object([
                    "keypath": .string("stop"),
                    "payload": .bool(true)
                ]),
                requester: context.owner
            )
        }
        let stopDuration = milliseconds(since: stopStart, clock: clock)
        let stopOutcome = stopResponse.flatMap(SkeletonBindingProbeSupport.failureDetail(from:)) ?? "ok"
        let statusAfterStop = try await readNearbyStatus(
            expectedStatus: "stopped",
            from: stopResponse,
            readOperation: "readNearbyStateAfterStop"
        )

        return NearbyFollowUpReport(
            configuration: context.configuration,
            injectedRemoteUUID: remoteUUID,
            startDurationMilliseconds: startDuration,
            requestContactDurationMilliseconds: requestContactDuration,
            injectDurationMilliseconds: injectDuration,
            openChatDurationMilliseconds: openChatDuration,
            stopDurationMilliseconds: stopDuration,
            startOutcome: startOutcome,
            requestContactOutcome: requestContactOutcome,
            nearbyCardLabel: nearbyCardLabel,
            nearbyCardPurposeSummary: nearbyCardPurposeSummary,
            nearbyActionSummary: nearbyActionSummary,
            requestContactLabel: requestContactLabel,
            requestContactSummary: requestContactSummary,
            requestContactActionSummary: requestContactActionSummary,
            workspaceNextStep: workspaceNextStep,
            sharedChatSummary: sharedChatSummary,
            firstRecentMessage: firstRecentMessage,
            openChatOutcome: openChatOutcome,
            stopOutcome: stopOutcome,
            statusAfterStart: statusAfterStart,
            statusAfterStop: statusAfterStop
        )
    }

#if canImport(AppKit)
    @MainActor
    static func renderReport(
        for configuration: CellConfiguration,
        expectedVisibleStrings: Set<String>
    ) async throws -> RenderReport {
        let context = try await makeRuntimeContext(for: configuration)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        guard let skeleton = context.configuration.skeleton else {
            throw NSError(domain: "CellConfigurationVerifier", code: 1, userInfo: [NSLocalizedDescriptionKey: "Configuration mangler skeleton"])
        }

        let viewModel = PortholeViewModel()
        viewModel.cellReferences = context.configuration.cellReferences ?? []
        viewModel.applyCellConfiguration(cellConfiguration: context.configuration)
        viewModel.markLocalMutation()

        let hostingView = NSHostingView(
            rootView: SkeletonView(element: skeleton)
                .environmentObject(viewModel)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 1280, height: 2600)
        let containerView = NSView(frame: hostingView.frame)
        containerView.addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        containerView.layoutSubtreeIfNeeded()

        let clock = ContinuousClock()
        let renderStart = clock.now
        var firstMeaningfulContentMilliseconds = 0.0
        var visibleStrings = Set<String>()
        var buttonTitles = Set<String>()
        var snapshotByteCount = 0

        for iteration in 0..<16 {
            containerView.layoutSubtreeIfNeeded()
            hostingView.layoutSubtreeIfNeeded()
            hostingView.displayIfNeeded()
            visibleStrings = collectVisibleStrings(from: containerView)
            buttonTitles = collectButtonTitles(from: containerView)
            snapshotByteCount = max(snapshotByteCount, snapshotPNGByteCount(for: containerView))

            let combinedStrings = visibleStrings.union(buttonTitles)
            if firstMeaningfulContentMilliseconds == 0,
               expectedVisibleStrings.isSubset(of: combinedStrings) {
                firstMeaningfulContentMilliseconds = milliseconds(since: renderStart, clock: clock)
                break
            }

            if iteration < 15 {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }

        containerView.layoutSubtreeIfNeeded()
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()
        visibleStrings = collectVisibleStrings(from: containerView)
        buttonTitles = collectButtonTitles(from: containerView)
        snapshotByteCount = max(snapshotByteCount, snapshotPNGByteCount(for: containerView))

        if firstMeaningfulContentMilliseconds == 0 {
            firstMeaningfulContentMilliseconds = milliseconds(since: renderStart, clock: clock)
        }

        return RenderReport(
            visibleStrings: visibleStrings,
            buttonTitles: buttonTitles,
            snapshotByteCount: snapshotByteCount,
            subviewCount: countSubviews(in: containerView),
            firstMeaningfulContentMilliseconds: firstMeaningfulContentMilliseconds,
            totalRenderMilliseconds: milliseconds(since: renderStart, clock: clock)
        )
    }
#endif

    struct RuntimeContext {
        let configuration: CellConfiguration
        let validation: CellConfigurationValidationReport
        let resolver: CellResolver
        let owner: Identity
        let porthole: OrchestratorCell
    }

    private struct VerifierTimeoutError: Error, CustomStringConvertible {
        let operation: String
        let seconds: Double

        var description: String {
            "timeout(\(operation), \(seconds)s)"
        }
    }

    static func makeRuntimeContext(for configuration: CellConfiguration) async throws -> RuntimeContext {
        let identityVault = BindingTests.testIdentityVault
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await BindingLaunchWarmup.preloadLocalRuntime()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            throw NSError(domain: "CellConfigurationVerifier", code: 2, userInfo: [NSLocalizedDescriptionKey: "Expected CellResolver after local runtime warmup"])
        }

        await ConferenceVerifierFixtureSupport.ensureRegistered(on: resolver)

        let identityContext = "verifier-\(UUID().uuidString)"
        guard let owner = await identityVault.identity(for: identityContext, makeNewIfNotFound: true) else {
            throw NSError(domain: "CellConfigurationVerifier", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not create verifier identity"])
        }

        await ConferenceParticipantPreviewFallbackStateStore.shared.reset(for: owner.uuid)

        guard let porthole = try await resolver.cellAtEndpoint(
            endpoint: "cell:///Porthole",
            requester: owner
        ) as? OrchestratorCell else {
            throw NSError(domain: "CellConfigurationVerifier", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not resolve Porthole for verifier"])
        }

        let repaired = BindingConferenceConfigurationRepair.updatedConfigurationIfNeeded(configuration) ?? configuration
        return RuntimeContext(
            configuration: repaired,
            validation: CellConfigurationValidationService.validate(repaired),
            resolver: resolver,
            owner: owner,
            porthole: porthole
        )
    }

    fileprivate static func waitForPortholeLoadBridgeConfiguration(
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

    private static func withTimeout<T: Sendable>(
        seconds: Double,
        operation: String,
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
                resolve(.failure(VerifierTimeoutError(operation: operation, seconds: seconds)))
            }
        }
    }

    private static func resolveReferences(
        _ references: [CellReference],
        resolver: CellResolver,
        requester: Identity
    ) async throws -> [ReferenceResolution] {
        let clock = ContinuousClock()
        var results: [ReferenceResolution] = []

        for reference in references {
            let start = clock.now
            do {
                _ = try await withTimeout(
                    seconds: 5,
                    operation: "resolveReference:\(reference.endpoint)"
                ) {
                    try await resolver.cellAtEndpoint(endpoint: reference.endpoint, requester: requester)
                }
                results.append(
                    ReferenceResolution(
                        label: reference.label,
                        endpoint: reference.endpoint,
                        durationMilliseconds: milliseconds(since: start, clock: clock),
                        outcome: "ok"
                    )
                )
            } catch {
                results.append(
                    ReferenceResolution(
                        label: reference.label,
                        endpoint: reference.endpoint,
                        durationMilliseconds: milliseconds(since: start, clock: clock),
                        outcome: String(describing: error)
                    )
                )
            }
        }

        return results
    }

    private static func readRootProbes(
        _ probes: [SkeletonBindingProbeSupport.RootProbe],
        bindingCandidates: [SkeletonBindingProbeSupport.RootProbe: [String]],
        from porthole: OrchestratorCell,
        requester: Identity
    ) async throws -> [RootProbeResolution] {
        let clock = ContinuousClock()
        let maxAttempts = 3
        let retryDelayNanoseconds: UInt64 = 120_000_000
        let perProbeTimeoutSeconds = 0.6
        var latestOutcomes: [SkeletonBindingProbeSupport.RootProbe: String] = [:]
        var latestDurations: [SkeletonBindingProbeSupport.RootProbe: Double] = [:]

        for attempt in 1...maxAttempts {
            latestOutcomes.removeAll(keepingCapacity: true)

            for probe in probes {
                let start = clock.now
                let candidates = bindingCandidates[probe] ?? []
                if !candidates.isEmpty {
                    let candidateOutcome = try await firstReadableBindingOutcome(
                        for: probe,
                        initialFailure: "candidate-unreadable",
                        candidates: candidates,
                        on: porthole,
                        requester: requester,
                        timeoutSeconds: perProbeTimeoutSeconds
                    )
                    latestDurations[probe] = milliseconds(since: start, clock: clock)
                    if candidateOutcome == "ok" {
                        continue
                    }
                }
                do {
                    let value = try await withTimeout(
                        seconds: perProbeTimeoutSeconds,
                        operation: "readRootProbe:\(probe.qualifiedKeypath)"
                    ) {
                        try await porthole.get(keypath: probe.qualifiedKeypath, requester: requester)
                    }
                    latestDurations[probe] = milliseconds(since: start, clock: clock)
                    if let detail = SkeletonBindingProbeSupport.failureDetail(from: value) {
                        latestOutcomes[probe] = try await firstReadableBindingOutcome(
                            for: probe,
                            initialFailure: detail,
                            candidates: candidates,
                            on: porthole,
                            requester: requester,
                            timeoutSeconds: perProbeTimeoutSeconds
                        )
                    }
                } catch {
                    latestDurations[probe] = milliseconds(since: start, clock: clock)
                    latestOutcomes[probe] = try await firstReadableBindingOutcome(
                        for: probe,
                        initialFailure: String(describing: error),
                        candidates: candidates,
                        on: porthole,
                        requester: requester,
                        timeoutSeconds: perProbeTimeoutSeconds
                    )
                }
            }

            if latestOutcomes.isEmpty || attempt == maxAttempts {
                break
            }

            try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
        }

        return probes.map { probe in
            RootProbeResolution(
                probe: probe,
                durationMilliseconds: latestDurations[probe] ?? 0,
                outcome: latestOutcomes[probe] ?? "ok"
            )
        }
    }

    private static func firstReadableBindingOutcome(
        for probe: SkeletonBindingProbeSupport.RootProbe,
        initialFailure: String,
        candidates: [String],
        on porthole: OrchestratorCell,
        requester: Identity,
        timeoutSeconds: Double
    ) async throws -> String {
        let fallbackCandidates = candidates
            .filter { $0 != probe.qualifiedKeypath }
            .prefix(6)

        guard !fallbackCandidates.isEmpty else {
            return initialFailure
        }

        for candidate in fallbackCandidates {
            do {
                let value = try await withTimeout(
                    seconds: timeoutSeconds,
                    operation: "readBindingCandidate:\(candidate)"
                ) {
                    try await porthole.get(keypath: candidate, requester: requester)
                }
                if SkeletonBindingProbeSupport.failureDetail(from: value) == nil {
                    return "ok"
                }
            } catch {
                continue
            }
        }

        return initialFailure
    }

    private static func executeStaticButtons(
        in skeleton: SkeletonElement?,
        allowedLabels: Set<String>,
        porthole: OrchestratorCell,
        resolver: CellResolver,
        requester: Identity
    ) async throws -> [ActionExecution] {
        guard let skeleton, !allowedLabels.isEmpty else {
            return []
        }

        let buttons = collectButtons(in: skeleton)
            .filter { allowedLabels.contains($0.label) }
        let clock = ContinuousClock()
        var results: [ActionExecution] = []

        for button in buttons {
            let start = clock.now
            let response: ValueType?
            do {
                response = try await withTimeout(
                    seconds: 5,
                    operation: "executeButton:\(button.label)"
                ) {
                    try await executeButtonDeterministically(
                        button,
                        porthole: porthole,
                        resolver: resolver,
                        requester: requester
                    )
                }
            } catch {
                results.append(
                    ActionExecution(
                        label: button.label,
                        keypath: button.keypath,
                        url: button.url,
                        durationMilliseconds: milliseconds(since: start, clock: clock),
                        outcome: String(describing: error)
                    )
                )
                continue
            }
            let outcome: String
            if let response {
                outcome = SkeletonBindingProbeSupport.failureDetail(from: response) ?? "ok"
            } else {
                outcome = "nil"
            }
            results.append(
                ActionExecution(
                    label: button.label,
                    keypath: button.keypath,
                    url: button.url,
                    durationMilliseconds: milliseconds(since: start, clock: clock),
                    outcome: outcome
                )
            )
        }

        return results
    }

    private static func executeButtonDeterministically(
        _ button: SkeletonButton,
        porthole: OrchestratorCell,
        resolver: CellResolver,
        requester: Identity
    ) async throws -> ValueType? {
        let target: Meddle
        if let url = button.url {
            guard let resolved = try await resolver.cellAtEndpoint(
                endpoint: url,
                requester: requester
            ) as? Meddle else {
                throw NSError(
                    domain: "CellConfigurationVerifier",
                    code: 7,
                    userInfo: [NSLocalizedDescriptionKey: "Button target was not Meddle for \(button.label)"]
                )
            }
            target = resolved
        } else {
            target = porthole
        }

        if let payload = button.payload {
            return try await target.set(
                keypath: button.keypath,
                value: payload,
                requester: requester
            )
        }

        return try await target.get(
            keypath: button.keypath,
            requester: requester
        )
    }

    private static func directReadableBindings(
        for configuration: CellConfiguration
    ) -> [SkeletonBindingProbeSupport.RootProbe: [String]] {
        guard let skeleton = configuration.skeleton,
              let rawObject = rawObject(from: skeleton)
        else {
            return [:]
        }

        let labels = Set(
            (configuration.cellReferences ?? [])
                .map { $0.label.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        guard !labels.isEmpty else {
            return [:]
        }

        var collected: [SkeletonBindingProbeSupport.RootProbe: [String]] = [:]
        collectReadableBindings(
            from: rawObject,
            currentElementKind: nil,
            labels: labels,
            into: &collected
        )
        return collected
    }

    private static func rawObject<T: Encodable>(from value: T) -> Any? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private static func collectReadableBindings(
        from value: Any,
        currentElementKind: String?,
        labels: Set<String>,
        into collected: inout [SkeletonBindingProbeSupport.RootProbe: [String]]
    ) {
        let skeletonElementKinds: Set<String> = [
            "Text", "TextField", "TextArea", "List", "Object", "Reference",
            "Toggle", "Image", "Button", "Spacer", "HStack", "VStack",
            "ScrollView", "Section", "ZStack", "Grid", "Divider"
        ]
        let readableBindingKeys: Set<String> = ["keypath", "sourceKeypath"]

        switch value {
        case let dictionary as [String: Any]:
            if dictionary.count == 1,
               let onlyKey = dictionary.keys.first,
               skeletonElementKinds.contains(onlyKey),
               let child = dictionary[onlyKey] {
                collectReadableBindings(
                    from: child,
                    currentElementKind: onlyKey,
                    labels: labels,
                    into: &collected
                )
                return
            }

            for (key, child) in dictionary {
                if readableBindingKeys.contains(key),
                   currentElementKind != "Button",
                   let bindingValue = child as? String,
                   let normalizedBinding = normalizedReadableBinding(bindingValue, labels: labels),
                   let probe = rootProbe(for: normalizedBinding) {
                    var current = collected[probe] ?? []
                    if !current.contains(normalizedBinding) {
                        current.append(normalizedBinding)
                        collected[probe] = current
                    }
                }

                collectReadableBindings(
                    from: child,
                    currentElementKind: currentElementKind,
                    labels: labels,
                    into: &collected
                )
            }
        case let array as [Any]:
            for child in array {
                collectReadableBindings(
                    from: child,
                    currentElementKind: currentElementKind,
                    labels: labels,
                    into: &collected
                )
            }
        default:
            break
        }
    }

    private static func normalizedReadableBinding(_ bindingValue: String, labels: Set<String>) -> String? {
        let trimmed = bindingValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalizedBinding: String
        if trimmed.hasPrefix("cell:///Porthole/") {
            normalizedBinding = String(trimmed.dropFirst("cell:///Porthole/".count))
        } else if trimmed.hasPrefix("cell://") || trimmed.hasPrefix("ws://") || trimmed.hasPrefix("wss://") {
            return nil
        } else {
            normalizedBinding = trimmed
        }

        guard let separatorIndex = normalizedBinding.firstIndex(of: ".") else {
            return nil
        }

        let label = String(normalizedBinding[..<separatorIndex])
        guard labels.contains(label) else { return nil }
        return normalizedBinding
    }

    private static func rootProbe(for normalizedBinding: String) -> SkeletonBindingProbeSupport.RootProbe? {
        guard let separatorIndex = normalizedBinding.firstIndex(of: ".") else {
            return nil
        }

        let label = String(normalizedBinding[..<separatorIndex])
        let remainder = String(normalizedBinding[normalizedBinding.index(after: separatorIndex)...])
        guard let rootSeparator = remainder.firstIndex(where: { $0 == "." || $0 == "[" }) else {
            guard !remainder.isEmpty else { return nil }
            return SkeletonBindingProbeSupport.RootProbe(label: label, rootKeypath: remainder)
        }

        let rootKeypath = String(remainder[..<rootSeparator])
        guard !rootKeypath.isEmpty else { return nil }
        return SkeletonBindingProbeSupport.RootProbe(label: label, rootKeypath: rootKeypath)
    }

    private static func collectButtons(in element: SkeletonElement) -> [SkeletonButton] {
        switch element {
        case .Button(let button):
            return [button]
        case .VStack(let stack):
            return stack.elements.flatMap(collectButtons)
        case .HStack(let stack):
            return stack.elements.flatMap(collectButtons)
        case .ScrollView(let scroll):
            return scroll.elements.flatMap(collectButtons)
        case .Section(let section):
            return (section.header.map(collectButtons) ?? []) +
                section.content.flatMap(collectButtons) +
                (section.footer.map(collectButtons) ?? [])
        case .Reference(let reference):
            return reference.flowElementSkeleton?.elements.flatMap(collectButtons) ?? []
        case .List(let list):
            return []
        case .Grid(let grid):
            return grid.elements.flatMap(collectButtons)
        case .ZStack(let stack):
            return stack.elements.flatMap(collectButtons)
        case .Object(let object):
            return object.elements.values.flatMap(collectButtons)
        default:
            return []
        }
    }

    private static func flattenReferences(from references: [CellReference]) -> [CellReference] {
        var flattened: [CellReference] = []

        func visit(_ reference: CellReference) {
            if flattened.contains(where: { $0.id == reference.id }) {
                return
            }
            flattened.append(reference)
            reference.subscriptions.forEach(visit)
        }

        references.forEach(visit)
        return flattened
    }

    private static func milliseconds(
        since start: ContinuousClock.Instant,
        clock: ContinuousClock
    ) -> Double {
        let duration = clock.now - start
        let components = duration.components
        return (Double(components.seconds) * 1_000.0) + (Double(components.attoseconds) / 1_000_000_000_000_000.0)
    }

    private static func valueString(_ value: ValueType?) -> String? {
        guard case let .string(string)? = value else {
            return nil
        }
        return string
    }

#if canImport(AppKit)
    @MainActor
    private static func snapshotPNGByteCount(for view: NSView) -> Int {
        guard view.bounds.isEmpty == false,
              let imageRep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
        else {
            return 0
        }
        view.cacheDisplay(in: view.bounds, to: imageRep)
        return imageRep.representation(using: .png, properties: [:])?.count ?? 0
    }

    @MainActor
    private static func collectVisibleStrings(from view: NSView) -> Set<String> {
        var strings = Set<String>()
        if let textField = view as? NSTextField {
            let text = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty == false {
                strings.insert(text)
            }
        }
        for child in view.subviews {
            strings.formUnion(collectVisibleStrings(from: child))
        }
        return strings
    }

    @MainActor
    private static func collectButtonTitles(from view: NSView) -> Set<String> {
        var titles = Set<String>()
        if let button = view as? NSButton {
            let title = button.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if title.isEmpty == false {
                titles.insert(title)
            }
        }
        for child in view.subviews {
            titles.formUnion(collectButtonTitles(from: child))
        }
        return titles
    }

    @MainActor
    private static func countSubviews(in view: NSView) -> Int {
        1 + view.subviews.reduce(0) { partialResult, child in
            partialResult + countSubviews(in: child)
        }
    }
#endif
}
