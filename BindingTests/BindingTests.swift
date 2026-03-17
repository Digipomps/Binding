//
//  BindingTests.swift
//  BindingTests
//
//  Created by Kjetil Hustveit on 16/12/2025.
//

import Foundation
import Testing
import CellBase
import CellApple
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
    }

    @Test func fullLibraryPrefersRemoteCatalogEndpointsBeforeLocalFallback() {
        let ordered = RemoteCatalogSupport.orderedCatalogCandidateEndpoints(from: [
            "cell:///ConfigurationCatalog",
            "cell://staging.haven.digipomps.org/ConfigurationCatalog"
        ])

        #expect(ordered == [
            "cell://staging.haven.digipomps.org/ConfigurationCatalog",
            "cell:///ConfigurationCatalog"
        ])
    }

    @Test func fullLibraryAppendsLocalCatalogFallbackWhenOnlyRemoteEndpointsAreProvided() {
        let ordered = RemoteCatalogSupport.orderedCatalogCandidateEndpoints(from: [
            "cell://staging.haven.digipomps.org/ConfigurationCatalog"
        ])

        #expect(ordered == [
            "cell://staging.haven.digipomps.org/ConfigurationCatalog",
            "cell:///ConfigurationCatalog"
        ])
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

        guard case .VStack = adjusted.skeleton else {
            Issue.record("Urelatert konfigurasjon skulle ikke blitt scroll-wrappet")
            return
        }
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

    private func skeletonContainsButton(keypath: String, in element: SkeletonElement) -> Bool {
        switch element {
        case .Button(let button):
            return button.keypath == keypath
        case .VStack(let stack):
            return stack.elements.contains { skeletonContainsButton(keypath: keypath, in: $0) }
        case .HStack(let stack):
            return stack.elements.contains { skeletonContainsButton(keypath: keypath, in: $0) }
        case .ScrollView(let scroll):
            return scroll.elements.contains { skeletonContainsButton(keypath: keypath, in: $0) }
        case .Section(let section):
            return (section.header.map { skeletonContainsButton(keypath: keypath, in: $0) } ?? false) ||
                section.content.contains { skeletonContainsButton(keypath: keypath, in: $0) } ||
                (section.footer.map { skeletonContainsButton(keypath: keypath, in: $0) } ?? false)
        case .Reference(let reference):
            return reference.flowElementSkeleton.map { skeletonContainsButton(keypath: keypath, in: .VStack($0)) } ?? false
        case .List(let list):
            return list.flowElementSkeleton.map { skeletonContainsButton(keypath: keypath, in: .VStack($0)) } ?? false
        case .Grid(let grid):
            return grid.elements.contains { skeletonContainsButton(keypath: keypath, in: $0) }
        case .ZStack(let stack):
            return stack.elements.contains { skeletonContainsButton(keypath: keypath, in: $0) }
        case .Object(let object):
            return object.elements.values.contains { skeletonContainsButton(keypath: keypath, in: $0) }
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
