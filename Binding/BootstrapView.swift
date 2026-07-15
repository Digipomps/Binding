import SwiftUI
import CellBase
import CellApple
import CryptoKit
#if canImport(Combine)
import Combine
#else
import OpenCombine
#endif

actor BindingLocalCellRegistration {
    static let shared = BindingLocalCellRegistration()
    private struct RuntimeIdentityBinding: Equatable {
        let uuid: String
        let signingFingerprint: String?
        let vaultReference: String?

        init(_ identity: Identity) {
            uuid = identity.uuid
            signingFingerprint = identity.signingPublicKeyFingerprint
            vaultReference = identity.homeVaultReference
        }
    }
    private static let warmupEndpointTimeoutNanoseconds: UInt64 = 1_200_000_000
    private static let warmupStateTimeoutNanoseconds: UInt64 = 1_200_000_000
    private static let localRegistrationValidationAttemptLimit = 2
    private static let criticalLocalEndpoints = [
        "cell:///Porthole",
        "cell:///Perspective",
        "cell:///ConfigurationCatalog",
        BindingRuntimeSurfaceLaunchSupport.adapterEndpoint,
        "cell:///PersonalCopilotNavigator"
    ]
    private static let safeConferenceWarmupEndpoints: [String] = [
        "cell:///Perspective",
        "cell:///Vault",
        "cell:///GraphIndex",
        "cell:///PersonalAgendaContext",
        "cell:///ConferenceParticipantPreviewShell",
        "cell:///ConferenceParticipantAgendaSnapshot",
        "cell:///ConferenceParticipantDiscoverySnapshot",
        "cell:///ConferenceParticipantMatchmakingSnapshot",
        "cell:///ConferencePublicShellFixture",
        "cell:///ConferenceSponsorShellFixture",
        "cell:///ConferenceNearbyRadar",
        "cell:///EntityScanner",
        "cell:///ConferenceChatLaunch",
        "cell:///ConferenceParticipantChatSnapshot",
        "cell:///ConferenceAdminPreviewShell",
    ]

    private var isLocallyRegistered = false
    private var isRegistered = false
    private var agentAdminCellsRegistered = false
    private var localRegistrationIdentityBinding: RuntimeIdentityBinding?
    private var localRegistrationTask: Task<Bool, Never>?
    private var registrationTask: Task<Bool, Never>?
#if DEBUG
    private var forceLocalRegistrationValidationFailureForTesting = false
    private var localRegistrationValidationCountForTesting = 0
#endif

    @discardableResult
    func ensureLocallyRegistered() async -> Bool {
        if let localRegistrationTask {
            return await localRegistrationTask.value
        }
        let task = Task { [weak self] in
            guard let self else { return false }
            return await self.performLocalRegistration()
        }
        localRegistrationTask = task
        let registered = await task.value
        localRegistrationTask = nil
        return registered
    }

    private func performLocalRegistration() async -> Bool {
        // Registration is identity-scoped. Bootstrap the active vault first so
        // we never validate (or reuse) local cells against a stale startup
        // identity after the authenticated vault takes over.
        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        if let resolver = CellBase.defaultCellResolver as? CellResolver {
            // Named identity-unique resolves survive process-local bootstrap
            // state. Rebind their owner descriptors before deciding whether
            // existing instances are usable under a replacement vault.
            await resolver.refreshNamedResolveOwnersFromCurrentVault()
        }

        if isLocallyRegistered {
            if !(await localRegistrationStillUsableForActiveIdentity()) {
                isLocallyRegistered = false
                isRegistered = false
                agentAdminCellsRegistered = false
                localRegistrationIdentityBinding = nil
            } else {
                if BindingPersonalCopilotV1Policy.agentSetupWorkbenchEnabled,
                   !agentAdminCellsRegistered,
                   let resolver = CellBase.defaultCellResolver as? CellResolver {
                    await Self.registerOptInAgentAdminCells(on: resolver)
                    agentAdminCellsRegistered = true
                }
                return true
            }
        }

        for attempt in 1...Self.localRegistrationValidationAttemptLimit {
            let resolver = CellResolver.sharedInstance
            // Register owner-scoped workbench cells as persistent on first resolve.
            // An ephemeral first registration cannot later be upgraded safely.
            await Self.registerChatWorkbenchParityCells(on: resolver)
            await Self.registerVaultGraphLocalCells(on: resolver)
            // Keep the launch path free of eager Porthole setup, owner-access
            // checks, LocalAuthentication and keychain prompts. Binding owns
            // local startup registration explicitly; AppInitializer.prepareLocalRuntime()
            // also schedules setupPorthole(), which is only safe once a user
            // surface asks for authenticated runtime work.
            await Self.registerAll(on: resolver)
            if let activeResolver = CellBase.defaultCellResolver as? CellResolver {
                await activeResolver.refreshNamedResolveOwnersFromCurrentVault()
            }
            localRegistrationIdentityBinding = await activePrivateRuntimeIdentity().map(RuntimeIdentityBinding.init)
            isLocallyRegistered = true
            agentAdminCellsRegistered = BindingPersonalCopilotV1Policy.agentSetupWorkbenchEnabled

            if await localRegistrationStillUsableForActiveIdentity() {
                return true
            }
            isLocallyRegistered = false
            isRegistered = false
            agentAdminCellsRegistered = false
            localRegistrationIdentityBinding = nil
            if attempt < Self.localRegistrationValidationAttemptLimit {
                continue
            }
        }
        print("HAVEN local cell registration remained unusable after \(Self.localRegistrationValidationAttemptLimit) attempts.")
        return false
    }

    private func activePrivateRuntimeIdentity() async -> Identity? {
        guard let identityVault = CellBase.defaultIdentityVault else {
            return nil
        }
        return await identityVault.identity(
            for: "private",
            makeNewIfNotFound: true
        )
    }

    private func localRegistrationStillUsableForActiveIdentity() async -> Bool {
#if DEBUG
        localRegistrationValidationCountForTesting += 1
        if forceLocalRegistrationValidationFailureForTesting {
            return false
        }
#endif
        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              resolver === CellResolver.sharedInstance
        else {
            return false
        }

        guard let requester = await activePrivateRuntimeIdentity(),
              localRegistrationIdentityBinding == RuntimeIdentityBinding(requester) else {
            return false
        }

        for endpoint in Self.criticalLocalEndpoints {
            guard let cell = try? await resolver.cellAtEndpoint(
                endpoint: endpoint,
                requester: requester
            ),
                  let generalCell = cell as? GeneralCell,
                  Self.criticalCellTypeMatches(endpoint: endpoint, cell: cell),
                  let owner = try? await cell.getOwner(requester: requester),
                  owner.referencesSameSigningIdentity(as: requester) else {
                return false
            }
            if let bindingCell = cell as? BindingRuntimeBindingEnsuring {
                do {
                    try await bindingCell.ensureRuntimeBindings()
                } catch {
                    return false
                }
            }

            switch endpoint {
            case "cell:///ConfigurationCatalog":
                guard case let .list(configurations)? = try? await generalCell.get(
                    keypath: "configurations",
                    requester: requester
                ), configurations.isEmpty == false else {
                    return false
                }
            case "cell:///PersonalCopilotNavigator":
                guard case .object? = try? await generalCell.get(
                    keypath: "state",
                    requester: requester
                ) else {
                    return false
                }
            default:
                break
            }
        }
        return true
    }

    nonisolated static func criticalCellTypeMatches(
        endpoint: String,
        cell: any Emit
    ) -> Bool {
        switch endpoint {
        case "cell:///Porthole":
            return cell is OrchestratorCell
        case "cell:///Perspective":
            return cell is PerspectiveCell
        case "cell:///ConfigurationCatalog":
            return cell is ConfigurationCatalogCell
        case BindingRuntimeSurfaceLaunchSupport.adapterEndpoint:
            return cell is BindingRuntimeSurfaceLaunchAdapterCell
        case "cell:///PersonalCopilotNavigator":
            return cell is PersonalCopilotNavigatorLocalCell
        default:
            return false
        }
    }

#if DEBUG
    func setForcedLocalRegistrationValidationFailureForTesting(_ forced: Bool) {
        forceLocalRegistrationValidationFailureForTesting = forced
        localRegistrationValidationCountForTesting = 0
        if forced {
            isLocallyRegistered = false
            isRegistered = false
            agentAdminCellsRegistered = false
            localRegistrationIdentityBinding = nil
        }
    }

    func localRegistrationValidationCountForTestingSnapshot() -> Int {
        localRegistrationValidationCountForTesting
    }
#endif

    @discardableResult
    func ensureRegistered() async -> Bool {
        if isRegistered {
            if await localRegistrationStillUsableForActiveIdentity() {
                return true
            }
            isRegistered = false
            isLocallyRegistered = false
            agentAdminCellsRegistered = false
            localRegistrationIdentityBinding = nil
        }
        if let registrationTask {
            return await registrationTask.value
        }

        if BindingRuntimeBootstrap.shouldUseLocalRuntimeOnlyForVerifier() {
            let registered = await ensureLocallyRegistered()
            isRegistered = registered
            return registered
        }

        let task = Task {
            let resolver = CellResolver.sharedInstance
            await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
            await Self.registerChatWorkbenchParityCells(on: resolver)
            await Self.registerVaultGraphLocalCells(on: resolver)
            await AppInitializer.initialize()
            await Self.registerAll(on: resolver)
            return await ensureLocallyRegistered()
        }
        registrationTask = task
        let registered = await task.value
        isRegistered = registered
        registrationTask = nil
        return registered
    }

    @discardableResult
    func ensureConferenceDemoRuntimeReady() async -> Bool {
        await ensureLocallyRegistered()
    }

    func warmConferenceRuntime(requester: Identity? = nil) async {
        guard await ensureConferenceDemoRuntimeReady() else {
            return
        }

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            return
        }

        let effectiveRequester: Identity?
        if let requester {
            effectiveRequester = requester
        } else {
            effectiveRequester = await BindingStartupIdentityVault.shared.identity(for: "private", makeNewIfNotFound: true)
        }

        guard let effectiveRequester else {
            return
        }

        for endpoint in Self.safeConferenceWarmupEndpoints {
            guard let meddle = try? await Self.resolveWarmupMeddle(
                endpoint: endpoint,
                resolver: resolver,
                requester: effectiveRequester
            ) else {
                continue
            }
            _ = try? await Self.readStateForWarmup(
                from: meddle,
                requester: effectiveRequester
            )
        }
    }

    private static func resolveWarmupMeddle(
        endpoint: String,
        resolver: CellResolver,
        requester: Identity
    ) async throws -> Meddle {
        try await withThrowingTaskGroup(of: Meddle.self) { group in
            group.addTask {
                guard let meddle = try await resolver.cellAtEndpoint(
                    endpoint: endpoint,
                    requester: requester
                ) as? Meddle else {
                    throw WarmupEndpointResolutionError(endpoint: endpoint)
                }
                return meddle
            }
            group.addTask {
                try await Task.sleep(nanoseconds: Self.warmupEndpointTimeoutNanoseconds)
                throw WarmupEndpointTimeoutError(endpoint: endpoint)
            }

            guard let firstResult = try await group.next() else {
                throw WarmupEndpointTimeoutError(endpoint: endpoint)
            }
            group.cancelAll()
            return firstResult
        }
    }

    private static func readStateForWarmup(
        from meddle: Meddle,
        requester: Identity
    ) async throws -> ValueType {
        try await withThrowingTaskGroup(of: ValueType.self) { group in
            group.addTask {
                try await meddle.get(keypath: "state", requester: requester)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: Self.warmupStateTimeoutNanoseconds)
                throw WarmupStateTimeoutError()
            }

            guard let firstResult = try await group.next() else {
                throw WarmupStateTimeoutError()
            }
            group.cancelAll()
            return firstResult
        }
    }

    private static func registerAll(on resolver: CellResolver) async {
        await register(
            name: BindingRuntimeSurfaceLaunchSupport.adapterCellName,
            cellScope: .identityUnique,
            identityDomain: "private",
            type: BindingRuntimeSurfaceLaunchAdapterCell.self,
            resolver: resolver
        )
        await registerCellAppleUtilityCells(on: resolver)
        await registerChatWorkbenchParityCells(on: resolver)
        await register(
            name: "EventEmitter",
            cellScope: .template,
            identityDomain: "private",
            type: EventEmitterCell.self,
            resolver: resolver
        )
        await register(
            name: "FolderWatch",
            cellScope: .template,
            identityDomain: "private",
            type: FolderWatchCell.self,
            resolver: resolver
        )
        await register(
            name: "ConfigurationCatalog",
            cellScope: .scaffoldUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: ConfigurationCatalogCell.self,
            resolver: resolver
        )
        await register(
            name: "Porthole",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: OrchestratorCell.self,
            resolver: resolver
        )
        await register(
            name: "Perspective",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: PerspectiveCell.self,
            resolver: resolver
        )
        await registerVaultGraphLocalCells(on: resolver)
        await register(
            name: "PersonalAgendaContext",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: PersonalAgendaContextCell.self,
            resolver: resolver
        )
        await register(
            name: CalendarContract.storeCellName,
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: CalendarStoreCell.self,
            resolver: resolver
        )
        await register(
            name: CalendarContract.importExportCellName,
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: CalendarImportExportCell.self,
            resolver: resolver
        )
        await register(
            name: CalendarContract.nativeBridgeCellName,
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: NativeCalendarBridgeCell.self,
            resolver: resolver
        )
        await register(
            name: "PersonalIdentity",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: PersonalIdentityLocalCell.self,
            resolver: resolver
        )
        await register(
            name: "PersonalProfileDraft",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: PersonalProfileDraftLocalCell.self,
            resolver: resolver
        )
        await register(
            name: PersonalProfilePublisherContract.cellName,
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: PersonalProfilePublisherLocalCell.self,
            resolver: resolver
        )
        await register(
            name: PublicProfileDirectoryContract.cellName,
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: PublicProfileDirectoryLocalCell.self,
            resolver: resolver
        )
        await register(
            name: PersonalMatchmakingContract.cellName,
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: PersonalMatchmakingLocalCell.self,
            resolver: resolver
        )
        await register(
            name: "PersonalChatClient",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: PersonalChatClientLocalCell.self,
            resolver: resolver
        )
        await register(
            name: "PersonalMeetingIntent",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: PersonalMeetingIntentLocalCell.self,
            resolver: resolver
        )
        await register(
            name: PersonalMeetingCoordinatorContract.cellName,
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: PersonalMeetingCoordinatorLocalCell.self,
            resolver: resolver
        )
        await register(
            name: PersonalCopilotAppStoreV1Contract.catalogCellName,
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: PersonalCopilotCatalogLocalCell.self,
            resolver: resolver
        )
        await register(
            name: "PersonalPrivacyAudit",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: PersonalPrivacyAuditLocalCell.self,
            resolver: resolver
        )
        await register(
            name: "PersonalUsageQuota",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: PersonalUsageQuotaLocalCell.self,
            resolver: resolver
        )
        await register(
            name: "PersonalCopilotNavigator",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: PersonalCopilotNavigatorLocalCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceParticipantPreviewShell",
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferenceParticipantPreviewShellLocalFallbackCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceAdminPreviewShell",
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferenceAdminPreviewShellLocalFallbackCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferencePublicShellFixture",
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferencePublicShellFixtureCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceSponsorShellFixture",
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferenceSponsorShellFixtureCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceNearbyRadar",
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferenceNearbyRadarLocalCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceParticipantAgendaSnapshot",
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferenceParticipantAgendaSnapshotLocalCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceParticipantDiscoverySnapshot",
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferenceParticipantDiscoverySnapshotLocalCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceParticipantMatchmakingSnapshot",
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferenceParticipantMatchmakingSnapshotLocalCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceParticipantChatSnapshot",
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferenceParticipantChatSnapshotLocalCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceChatLaunch",
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferenceParticipantChatSnapshotLocalCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceIdentityLinkIntake",
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferenceIdentityLinkIntakeCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceAIAssistantGatewayProxy",
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferenceAIAssistantGatewayProxyCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceDemoLauncher",
            cellScope: .identityUnique,
            identityDomain: "private",
            type: ConferenceDemoLauncherLocalCell.self,
            resolver: resolver
        )
        await register(
            name: "ConferenceConfigurationNavigator",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: ConferenceConfigurationNavigatorLocalCell.self,
            resolver: resolver
        )
        await registerOptInAgentAdminCells(on: resolver)
        await register(
            name: "WorkflowStudio",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: WorkflowStudioCell.self,
            resolver: resolver
        )
        await register(
            name: "Lobby",
            cellScope: .scaffoldUnique,
            identityDomain: "private",
            type: GeneralCell.self,
            resolver: resolver
        )
    }

    private static func registerCellAppleUtilityCells(on resolver: CellResolver) async {
        // EntityScanner is implemented and owned by CellApple. Use its
        // registration-only host API so Binding cannot silently drift from the
        // default runtime while still avoiding AppInitializer side effects.
        try? await AppInitializer.registerEntityScannerResolve(on: resolver)
        await register(
            name: "GeneralCell",
            cellScope: .template,
            identityDomain: "private",
            type: GeneralCell.self,
            resolver: resolver
        )
        await register(
            name: "GeneralCellTemplate",
            cellScope: .template,
            identityDomain: "private",
            type: GeneralCell.self,
            resolver: resolver
        )
        await register(
            name: "CloudBridge",
            cellScope: .template,
            identityDomain: "private",
            type: BridgeBase.self,
            resolver: resolver
        )
        await register(
            name: "EntityAnchor",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: EntityAnchorCell.self,
            resolver: resolver
        )
        await register(
            name: "ShoppingHandler",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: ShoppingHandlerCell.self,
            resolver: resolver
        )
        await register(
            name: "FileCrypto",
            cellScope: .template,
            identityDomain: "private",
            type: FileCryptoCell.self,
            resolver: resolver
        )
        await register(
            name: "CommonsResolver",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: CommonsResolverCell.self,
            resolver: resolver
        )
        await register(
            name: "CommonsTaxonomy",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: CommonsTaxonomyCell.self,
            resolver: resolver
        )
        await register(
            name: "EntityAtlas",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: EntityAtlasInspectorCell.self,
            resolver: resolver
        )
        await register(
            name: "FlowProbe",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: FlowProbeCell.self,
            resolver: resolver
        )
        await register(
            name: "StateSnapshot",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: StateSnapshotCell.self,
            resolver: resolver
        )
        await register(
            name: "TrustedIssuers",
            cellScope: .scaffoldUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: TrustedIssuerCell.self,
            resolver: resolver
        )
        await register(
            name: "Chat",
            cellScope: .scaffoldUnique,
            identityDomain: "private",
            type: ChatCell.self,
            resolver: resolver
        )
        await register(
            name: "Identities",
            cellScope: .scaffoldUnique,
            identityDomain: "private",
            type: IdentitiesCell.self,
            resolver: resolver
        )
    }

    private static func registerChatWorkbenchParityCells(
        on resolver: CellResolver,
        persistency: Persistancy? = .persistant
    ) async {
        await register(
            name: "PersonalChatHub",
            cellScope: .identityUnique,
            persistency: persistency,
            identityDomain: "private",
            type: BindingPersonalChatHubCell.self,
            resolver: resolver
        )
        await register(
            name: "AppleIntelligence",
            cellScope: .identityUnique,
            persistency: persistency,
            identityDomain: "private",
            type: BindingAppleIntelligenceProviderCell.self,
            resolver: resolver
        )
        await register(
            name: "LocalLLM",
            cellScope: .identityUnique,
            persistency: persistency,
            identityDomain: "private",
            type: BindingLocalLLMCell.self,
            resolver: resolver
        )
        await register(
            name: "ContactEndpoint",
            cellScope: .identityUnique,
            persistency: persistency,
            identityDomain: "private",
            type: BindingContactEndpointCell.self,
            resolver: resolver
        )
    }

    private static func registerVaultGraphLocalCells(on resolver: CellResolver) async {
        await register(
            name: "Vault",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: VaultCell.self,
            resolver: resolver
        )
        await register(
            name: "GraphIndex",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: BindingGraphIndexCell.self,
            resolver: resolver
        )
    }

    private static func registerOptInAgentAdminCells(on resolver: CellResolver) async {
        if BindingPersonalCopilotV1Policy.agentSetupWorkbenchEnabled {
            await register(
                name: "AgentProvisioning",
                cellScope: .identityUnique,
                identityDomain: "private",
                type: AgentProvisioningCell.self,
                resolver: resolver
            )
            await register(
                name: "AgentEnrollment",
                cellScope: .identityUnique,
                identityDomain: "private",
                type: AgentEnrollmentCell.self,
                resolver: resolver
            )
        }
    }

    private static func register<CellType: Emit & OwnerInstantiable>(
        name: String,
        cellScope: CellUsageScope,
        persistency: Persistancy? = nil,
        identityDomain: String,
        type: CellType.Type,
        resolver: CellResolver
    ) async {
        do {
            if let persistency {
                try await resolver.addCellResolve(
                    name: name,
                    cellScope: cellScope,
                    persistency: persistency,
                    identityDomain: identityDomain,
                    type: type
                )
            } else {
                try await resolver.addCellResolve(
                    name: name,
                    cellScope: cellScope,
                    identityDomain: identityDomain,
                    type: type
                )
            }
        } catch {
            let errorDescription = String(describing: error).lowercased()
            guard !errorDescription.contains("duplicatedendpointname"),
                  !errorDescription.contains("registeratalreadytakenendpoint"),
                  !errorDescription.contains("duplicatedcodingname") else {
                return
            }
            print("HAVEN local cell registration failed for \(name): \(error)")
        }
    }
}

private struct WarmupStateTimeoutError: LocalizedError {
    var errorDescription: String? {
        "Conference runtime warmup timed out while reading state."
    }
}

private struct WarmupEndpointTimeoutError: LocalizedError {
    let endpoint: String

    var errorDescription: String? {
        "Conference runtime warmup timed out while resolving \(endpoint)."
    }
}

private struct WarmupEndpointResolutionError: LocalizedError {
    let endpoint: String

    var errorDescription: String? {
        "Conference runtime warmup could not resolve meddle at \(endpoint)."
    }
}

private enum ConferenceSnapshotRetrySupport {
    private static let retryableFragments: [String] = [
        "ikke tilgjengelig",
        "kunne ikke",
        "notfound",
        "denied",
        "timeout",
        "finishedwithoutvalue",
        "siste stabile snapshot",
        "siste lokale snapshot",
        "beholdt siste stabile snapshot"
    ]

    static func shouldRetryImmediately(
        cachedState: Object,
        statusKeys: [String]
    ) -> Bool {
        statusKeys.contains { key in
            containsRetryableFailure(cachedState[key])
        }
    }

    private static func containsRetryableFailure(_ value: ValueType?) -> Bool {
        guard case let .string(text)? = value else {
            return false
        }

        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalized.isEmpty else {
            return false
        }

        return retryableFragments.contains(where: normalized.contains)
    }
}

class PersonalCopilotLocalCell: BindingRuntimeBindingCell {
    private enum CodingKeys: String, CodingKey {
        case cachedState
    }

    nonisolated(unsafe) private var cachedState: Object = [:]
    private let cachedStateLock = NSLock()

    var readableKeys: [String] {
        ["state"]
    }

    var writableKeys: [String] {
        []
    }

    required init(owner: Identity) async {
        await super.init(owner: owner)
        replaceState(initialState())
        await installRuntimeBindings(owner: owner)
        await markRuntimeBindingsInstalled()
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)

        let container = try decoder.container(keyedBy: CodingKeys.self)
        restoreState(try container.decodeIfPresent(Object.self, forKey: .cachedState) ?? [:])
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(stateObject(), forKey: .cachedState)
    }

    nonisolated func initialState() -> Object {
        [
            "status": .string("ready"),
            "updatedAt": .float(Date().timeIntervalSince1970)
        ]
    }

    func handleSet(key: String, value: ValueType) async -> ValueType {
        mutateState { state in
            setNestedValue(
                value,
                for: key.split(separator: ".").map(String.init),
                in: &state
            )
            state["lastAction"] = .string(key)
        }
        return response(status: "ok", message: "\(key) updated locally.")
    }

    nonisolated func stateObject() -> Object {
        withCachedState { $0 }
    }

    nonisolated func replaceState(_ object: Object) {
        withCachedState { state in
            state = object
            state["updatedAt"] = .float(Date().timeIntervalSince1970)
        }
    }

    /// Decoding is restoration, not a user-visible mutation. Preserve the
    /// persisted snapshot exactly so immediate reads match the encoded cell.
    nonisolated private func restoreState(_ object: Object) {
        withCachedState { state in
            state = object
        }
    }

    nonisolated func mergeState(_ updates: Object) {
        mutateState { state in
            for (key, value) in updates {
                state[key] = value
            }
        }
    }

    func response(status: String, message: String) -> ValueType {
        let snapshot: Object = mutateState { state in
            state["status"] = .string(message)
            return state
        }
        return .object([
            "status": .string(status),
            "message": .string(message),
            "state": .object(snapshot)
        ])
    }

    func stringValue(_ value: ValueType) -> String {
        switch value {
        case let .string(text):
            return text
        case let .integer(number):
            return String(number)
        case let .float(number):
            return String(number)
        case let .bool(flag):
            return flag ? "true" : "false"
        default:
            return String(describing: value)
        }
    }

    nonisolated func setStateValue(_ value: ValueType, for dottedKey: String) {
        mutateState { state in
            setNestedValue(
                value,
                for: dottedKey.split(separator: ".").map(String.init),
                in: &state
            )
        }
    }

    nonisolated func stateValue(for dottedKey: String) -> ValueType? {
        withCachedState { state in
            nestedValue(
                for: dottedKey.split(separator: ".").map(String.init),
                in: state
            )
        }
    }

    nonisolated func appendStateListValue(_ value: ValueType, for dottedKey: String) {
        mutateState { state in
            let path = dottedKey.split(separator: ".").map(String.init)
            var values: [ValueType] = []
            if case let .list(existing)? = nestedValue(for: path, in: state) {
                values = existing
            }
            values.append(value)
            setNestedValue(.list(values), for: path, in: &state)
        }
    }

    @discardableResult
    nonisolated private func mutateState<T>(_ operation: (inout Object) -> T) -> T {
        withCachedState { state in
            let result = operation(&state)
            state["updatedAt"] = .float(Date().timeIntervalSince1970)
            return result
        }
    }

    nonisolated private func withCachedState<T>(_ operation: (inout Object) -> T) -> T {
        cachedStateLock.lock()
        defer { cachedStateLock.unlock() }
        return operation(&cachedState)
    }

    override func installRuntimeBindings(owner: Identity) async {
        if stateObject().isEmpty {
            replaceState(initialState())
        } else if stateValue(for: "updatedAt") == nil {
            mergeState([:])
        }

        for key in readableKeys {
            ensureAgreementGrant("r---", for: key)
            await addInterceptForGet(requester: owner, key: key, getValueIntercept: { [weak self] _, requester in
                guard let self else { return .string("failure") }
                guard await self.validateAccess("r---", at: key, for: requester) else { return .string("denied") }
                if key == "state" {
                    return .object(self.stateObject())
                }
                return self.stateValue(for: key) ?? .object(self.stateObject())
            })
        }

        for key in writableKeys {
            ensureAgreementGrant("rw--", for: key)
            await addInterceptForSet(requester: owner, key: key, setValueIntercept: { [weak self] _, value, requester in
                guard let self else { return .string("failure") }
                guard await self.validateAccess("rw--", at: key, for: requester) else { return .string("denied") }
                return await self.handleSet(key: key, value: value)
            })
        }
    }

    nonisolated private func nestedValue(for path: [String], in object: Object) -> ValueType? {
        guard let first = path.first else { return .object(object) }
        guard let value = object[first] else { return nil }
        guard path.count > 1 else { return value }
        guard case let .object(child) = value else { return nil }
        return nestedValue(for: Array(path.dropFirst()), in: child)
    }

    nonisolated private func setNestedValue(_ value: ValueType, for path: [String], in object: inout Object) {
        guard let first = path.first else { return }
        guard path.count > 1 else {
            object[first] = value
            return
        }

        var child: Object
        if case let .object(existing)? = object[first] {
            child = existing
        } else {
            child = [:]
        }
        setNestedValue(value, for: Array(path.dropFirst()), in: &child)
        object[first] = .object(child)
    }
}

final class PersonalIdentityLocalCell: PersonalCopilotLocalCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override var writableKeys: [String] {
        ["requestExport", "requestAccountDelete", "cancelAccountDelete"]
    }

    nonisolated override func initialState() -> Object {
        [
            "title": .string("Personal Home"),
            "identityMode": .string("private requester on device"),
            "publicIdentityStatus": .string("not published"),
            "exportStatus": .string("not requested"),
            "deleteStatus": .string("not requested"),
            "deleteRequiresConfirmation": .bool(true),
            "status": .string("Identity stays local until an explicit publish or account action."),
            "updatedAt": .float(Date().timeIntervalSince1970)
        ]
    }

    override func handleSet(key: String, value: ValueType) async -> ValueType {
        switch key {
        case "requestExport":
            mergeState([
                "exportStatus": .string("export requested locally"),
                "lastAction": .string("requestExport")
            ])
            return response(status: "ok", message: "Account export request recorded locally.")
        case "requestAccountDelete":
            mergeState([
                "deleteStatus": .string("delete requested - confirmation required"),
                "lastAction": .string("requestAccountDelete")
            ])
            return response(status: "ok", message: "Account delete request is staged and still requires confirmation.")
        case "cancelAccountDelete":
            mergeState([
                "deleteStatus": .string("not requested"),
                "lastAction": .string("cancelAccountDelete")
            ])
            return response(status: "ok", message: "Account delete request cancelled.")
        default:
            return await super.handleSet(key: key, value: value)
        }
    }
}

private final class PersonalProfileDraftLocalCell: PersonalCopilotLocalCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override var writableKeys: [String] {
        [
            "profile.displayName",
            "profile.headline",
            "profile.summary",
            "preparePublishPreview",
            "recordPublishConsent",
            "resetDraft"
        ]
    }

    nonisolated override func initialState() -> Object {
        [
            "draft": .object([
                "displayName": .string(""),
                "headline": .string(""),
                "summary": .string("")
            ]),
            "publishPreview": .object([
                "ready": .bool(false),
                "summary": .string("Draft stays local until publish preview is prepared.")
            ]),
            "publishedStatus": .string("localOnly"),
            "requiresExplicitConsent": .bool(true),
            "status": .string("Profile draft is private on this device."),
            "updatedAt": .float(Date().timeIntervalSince1970)
        ]
    }

    override func handleSet(key: String, value: ValueType) async -> ValueType {
        switch key {
        case "profile.displayName":
            setStateValue(value, for: "draft.displayName")
            return response(status: "ok", message: "Display name updated in local draft.")
        case "profile.headline":
            setStateValue(value, for: "draft.headline")
            return response(status: "ok", message: "Headline updated in local draft.")
        case "profile.summary":
            setStateValue(value, for: "draft.summary")
            return response(status: "ok", message: "Summary updated in local draft.")
        case "preparePublishPreview":
            let draft = stateValue(for: "draft") ?? .object([:])
            mergeState([
                "publishPreview": .object([
                    "ready": .bool(true),
                    "draft": draft,
                    "summary": .string("Preview ready. Publishing still requires explicit consent.")
                ]),
                "publishedStatus": .string("previewReady"),
                "lastAction": .string("preparePublishPreview")
            ])
            return response(status: "ok", message: "Publish preview prepared without uploading.")
        case "recordPublishConsent":
            mergeState([
                "publishedStatus": .string("consentRecorded"),
                "lastAction": .string("recordPublishConsent")
            ])
            return response(status: "ok", message: "Publish consent recorded. CellScaffold publisher may now receive the approved preview.")
        case "resetDraft":
            replaceState(initialState())
            return response(status: "ok", message: "Profile draft reset locally.")
        default:
            return await super.handleSet(key: key, value: value)
        }
    }
}

private final class PersonalProfilePublisherLocalCell: PersonalCopilotLocalCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override var readableKeys: [String] {
        [
            PersonalProfilePublisherContract.stateKeypath,
            PersonalProfilePublisherContract.publicReadModelKeypath,
            "profileStatus",
            "purposeGoal",
            "skeletonConfiguration"
        ]
    }

    override var writableKeys: [String] {
        [
            PersonalProfilePublisherContract.publishKeypath,
            "publishProfile",
            PersonalProfilePublisherContract.unpublishKeypath,
            "unpublishProfile",
            PersonalProfilePublisherContract.deleteKeypath,
            "deleteProfile",
            "publishDraft.displayName",
            "publishDraft.headline",
            "publishDraft.summary",
            "publishDraft.interestsText"
        ]
    }

    nonisolated override func initialState() -> Object {
        [
            "publishDraft": .object(Self.emptyDraft()),
            "publicReadModel": .object(Self.emptyReadModel()),
            "publishStatus": .string("local draft only"),
            "profileStatus": .string("not published"),
            "visibility": .string("private"),
            "requiresExplicitPublishConsent": .bool(true),
            "status": .string("Profile publishing is staged locally until an explicit signed cloud publish is available."),
            "updatedAt": .float(Date().timeIntervalSince1970)
        ]
    }

    override func handleSet(key: String, value: ValueType) async -> ValueType {
        switch key {
        case "publishDraft.displayName":
            return updateDraft(field: "displayName", value: payloadString(value))
        case "publishDraft.headline":
            return updateDraft(field: "headline", value: payloadString(value))
        case "publishDraft.summary":
            return updateDraft(field: "summary", value: payloadString(value))
        case "publishDraft.interestsText":
            return updateDraft(field: "interestsText", value: payloadString(value))
        case PersonalProfilePublisherContract.publishKeypath, "publishProfile":
            let draft = currentDraft()
            mergeState([
                "publicReadModel": .object(Self.readModel(from: draft)),
                "publishStatus": .string("ready for signed cloud publish"),
                "profileStatus": .string("publish consent staged locally"),
                "visibility": .string("pending signed publish"),
                "lastAction": .string("publishProfile")
            ])
            return response(status: "ok", message: "Publish consent staged locally. No cloud profile was published without a signed contract.")
        case PersonalProfilePublisherContract.unpublishKeypath, "unpublishProfile":
            mergeState([
                "publishStatus": .string("unpublish staged locally"),
                "profileStatus": .string("unpublish requested"),
                "visibility": .string("private"),
                "lastAction": .string("unpublishProfile")
            ])
            return response(status: "ok", message: "Unpublish request staged locally.")
        case PersonalProfilePublisherContract.deleteKeypath, "deleteProfile":
            replaceState(initialState())
            return response(status: "ok", message: "Local publish draft and read model cleared.")
        default:
            return await super.handleSet(key: key, value: value)
        }
    }

    private func updateDraft(field: String, value: String) -> ValueType {
        var draft = currentDraft()
        draft[field] = .string(value)
        setStateValue(.object(draft), for: "publishDraft")
        return response(status: "ok", message: "Publish draft updated locally.")
    }

    private func currentDraft() -> Object {
        if case let .object(draft)? = stateValue(for: "publishDraft") {
            return draft
        }
        return Self.emptyDraft()
    }

    private func payloadString(_ value: ValueType) -> String {
        if case let .object(object) = value {
            if case let .string(text)? = object["text"] ?? object["value"] {
                return text
            }
            return ""
        }
        return stringValue(value)
    }

    private static func emptyDraft() -> Object {
        [
            "displayName": .string(""),
            "headline": .string(""),
            "summary": .string(""),
            "interestsText": .string("")
        ]
    }

    private static func emptyReadModel() -> Object {
        [
            "displayName": .string(""),
            "headline": .string(""),
            "summary": .string("")
        ]
    }

    private static func readModel(from draft: Object) -> Object {
        [
            "displayName": draft["displayName"] ?? .string(""),
            "headline": draft["headline"] ?? .string(""),
            "summary": draft["summary"] ?? .string(""),
            "moderationStatus": .string("pending signed publish")
        ]
    }
}

private final class PublicProfileDirectoryLocalCell: PersonalCopilotLocalCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override var readableKeys: [String] {
        [
            PublicProfileDirectoryContract.stateKeypath,
            PublicProfileDirectoryContract.blockedProfilesKeypath,
            "directoryModerationStatus",
            "purposeGoal",
            "skeletonConfiguration"
        ]
    }

    override var writableKeys: [String] {
        [
            "query",
            PublicProfileDirectoryContract.searchKeypath,
            "searchProfiles",
            "profileDetail",
            PublicProfileDirectoryContract.reportProfileKeypath,
            PublicProfileDirectoryContract.hideProfileKeypath,
            PublicProfileDirectoryContract.blockProfileKeypath
        ]
    }

    nonisolated override func initialState() -> Object {
        [
            "query": .string(""),
            "lastSearch": .object([
                "results": .list([]),
                "status": .string("No signed public directory scope has been loaded yet.")
            ]),
            "selectedProfileID": .string(""),
            "blockedProfiles": .list([]),
            "blockedProfileCount": .integer(0),
            "moderationStatus": .string("local safe mode"),
            "status": .string("Directory is available as an owner-scoped local surface until a signed remote directory grant is active."),
            "updatedAt": .float(Date().timeIntervalSince1970)
        ]
    }

    override func handleSet(key: String, value: ValueType) async -> ValueType {
        switch key {
        case "query":
            let query = payloadString(value)
            setStateValue(.string(query), for: "query")
            return response(status: "ok", message: "Directory query updated locally.")
        case PublicProfileDirectoryContract.searchKeypath, "searchProfiles":
            return searchProfiles(payload: value)
        case "profileDetail":
            return profileDetail(payload: value)
        case PublicProfileDirectoryContract.reportProfileKeypath:
            return markSelectedProfile(action: "reported", payload: value)
        case PublicProfileDirectoryContract.hideProfileKeypath:
            return markSelectedProfile(action: "hidden", payload: value)
        case PublicProfileDirectoryContract.blockProfileKeypath:
            return blockSelectedProfile(payload: value)
        default:
            return await super.handleSet(key: key, value: value)
        }
    }

    private func searchProfiles(payload: ValueType) -> ValueType {
        let query = payloadString(payload).isEmpty ? currentQuery() : payloadString(payload)
        setStateValue(.string(query), for: "query")
        let results = Self.localProfiles.filter { profile in
            guard !query.isEmpty else { return true }
            return profile.values.contains { value in
                if case let .string(text) = value {
                    return text.localizedCaseInsensitiveContains(query)
                }
                return false
            }
        }
        let selectedID = Self.firstID(in: results) ?? ""
        mergeState([
            "lastSearch": .object([
                "results": .list(results.map(ValueType.object)),
                "status": .string(results.isEmpty ? "No local public profiles matched." : "Local public-safe profiles matched.")
            ]),
            "selectedProfileID": .string(selectedID),
            "lastAction": .string("searchProfiles")
        ])
        return .object([
            "ok": .bool(true),
            "status": .string("ok"),
            "results": .list(results.map(ValueType.object)),
            "state": .object(stateObject())
        ])
    }

    private func profileDetail(payload: ValueType) -> ValueType {
        let selectedID = profileID(from: payload) ?? selectedProfileID() ?? Self.firstID(in: Self.localProfiles) ?? ""
        setStateValue(.string(selectedID), for: "selectedProfileID")
        let profile = Self.localProfiles.first { Self.string("id", in: $0) == selectedID } ?? [:]
        return .object([
            "ok": .bool(true),
            "status": .string(profile.isEmpty ? "not_found" : "ok"),
            "profile": .object(profile),
            "state": .object(stateObject())
        ])
    }

    private func markSelectedProfile(action: String, payload: ValueType) -> ValueType {
        let selectedID = profileID(from: payload) ?? selectedProfileID() ?? Self.firstID(in: Self.localProfiles) ?? ""
        setStateValue(.string(selectedID), for: "selectedProfileID")
        mergeState([
            "moderationStatus": .string("\(action): \(selectedID)"),
            "lastAction": .string(action)
        ])
        return response(status: "ok", message: "Directory \(action) action recorded locally for review.")
    }

    private func blockSelectedProfile(payload: ValueType) -> ValueType {
        let selectedID = profileID(from: payload) ?? selectedProfileID() ?? Self.firstID(in: Self.localProfiles) ?? ""
        var blocked = strings(stateValue(for: "blockedProfiles"))
        if !selectedID.isEmpty, !blocked.contains(selectedID) {
            blocked.append(selectedID)
        }
        mergeState([
            "selectedProfileID": .string(selectedID),
            "blockedProfiles": .list(blocked.map(ValueType.string)),
            "blockedProfileCount": .integer(blocked.count),
            "moderationStatus": .string("blocked locally: \(selectedID)"),
            "lastAction": .string("blockProfile")
        ])
        return response(status: "ok", message: "Profile block recorded locally.")
    }

    private func currentQuery() -> String {
        if case let .string(query)? = stateValue(for: "query") {
            return query
        }
        return ""
    }

    private func selectedProfileID() -> String? {
        if case let .string(id)? = stateValue(for: "selectedProfileID"), !id.isEmpty {
            return id
        }
        return nil
    }

    private func payloadString(_ value: ValueType) -> String {
        if case let .object(object) = value {
            if case let .string(text)? = object["query"] ?? object["text"] ?? object["value"] {
                return text
            }
            return ""
        }
        return stringValue(value)
    }

    private func profileID(from value: ValueType) -> String? {
        if case let .object(object) = value,
           case let .string(id)? = object["profileID"] ?? object["id"] {
            return id
        }
        if case let .string(id) = value, !id.isEmpty {
            return id
        }
        return nil
    }

    private func strings(_ value: ValueType?) -> [String] {
        guard case let .list(values)? = value else { return [] }
        return values.compactMap {
            if case let .string(text) = $0 { return text }
            return nil
        }
    }

    private static func firstID(in profiles: [Object]) -> String? {
        profiles.compactMap { string("id", in: $0) }.first
    }

    private static func string(_ key: String, in object: Object) -> String? {
        if case let .string(text)? = object[key] {
            return text
        }
        return nil
    }

    private static let localProfiles: [Object] = [
        [
            "id": .string("local-profile-example"),
            "displayName": .string("Lokal eksempelprofil"),
            "headline": .string("Public-safe preview"),
            "summary": .string("Viser hvordan katalogen fungerer uten aa hente privat eller usignert skydata."),
            "moderationStatus": .string("local-safe")
        ]
    ]
}

private final class PersonalMatchmakingLocalCell: PersonalCopilotLocalCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override var readableKeys: [String] {
        [
            PersonalMatchmakingContract.stateKeypath,
            PersonalMatchmakingContract.preferencesKeypath,
            PersonalMatchmakingContract.suggestionsKeypath,
            "purposeGoal",
            "skeletonConfiguration"
        ]
    }

    override var writableKeys: [String] {
        [
            "preferencesText",
            PersonalMatchmakingContract.setPreferencesKeypath,
            "refreshSuggestions",
            PersonalMatchmakingContract.requestConsentKeypath,
            "requestMatchConsent",
            PersonalMatchmakingContract.approveMatchKeypath,
            "acceptMatchConsent",
            PersonalMatchmakingContract.declineMatchKeypath,
            "declineMatchConsent",
            "clearMatchSuggestion"
        ]
    }

    nonisolated override func initialState() -> Object {
        [
            "preferencesText": .string(""),
            "preferences": .list([]),
            "matchSuggestions": .list([]),
            "suggestions": .list([]),
            "requiresMutualApprovalForChat": .bool(true),
            "matchConsentStatus": .string("not requested"),
            "status": .string("Matching is owner-scoped locally until a signed remote matching grant is active."),
            "updatedAt": .float(Date().timeIntervalSince1970)
        ]
    }

    override func handleSet(key: String, value: ValueType) async -> ValueType {
        switch key {
        case "preferencesText", PersonalMatchmakingContract.setPreferencesKeypath:
            let text = payloadString(value)
            let preferences = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            mergeState([
                "preferencesText": .string(text),
                "preferences": .list(preferences.map(ValueType.string)),
                "lastAction": .string("setPreferences")
            ])
            return response(status: "ok", message: "Match preferences updated locally.")
        case "refreshSuggestions":
            let suggestion = localSuggestion()
            mergeState([
                "matchSuggestions": .list([.object(suggestion)]),
                "suggestions": .list([.object(suggestion)]),
                "matchConsentStatus": .string("suggestion requires explicit consent"),
                "lastAction": .string("refreshSuggestions")
            ])
            return response(status: "ok", message: "Local match suggestion prepared without starting a chat.")
        case PersonalMatchmakingContract.requestConsentKeypath, "requestMatchConsent":
            mergeState([
                "matchConsentStatus": .string("consent requested locally"),
                "lastAction": .string("requestMatchConsent")
            ])
            return response(status: "ok", message: "Consent request staged locally.")
        case PersonalMatchmakingContract.approveMatchKeypath, "acceptMatchConsent":
            mergeState([
                "matchConsentStatus": .string("local approval recorded"),
                "lastAction": .string("acceptMatchConsent")
            ])
            return response(status: "ok", message: "Local match approval recorded. Chat still requires the other party.")
        case PersonalMatchmakingContract.declineMatchKeypath, "declineMatchConsent":
            mergeState([
                "matchConsentStatus": .string("declined locally"),
                "lastAction": .string("declineMatchConsent")
            ])
            return response(status: "ok", message: "Match declined locally.")
        case "clearMatchSuggestion":
            mergeState([
                "matchSuggestions": .list([]),
                "suggestions": .list([]),
                "matchConsentStatus": .string("cleared"),
                "lastAction": .string("clearMatchSuggestion")
            ])
            return response(status: "ok", message: "Local match suggestion cleared.")
        default:
            return await super.handleSet(key: key, value: value)
        }
    }

    private func payloadString(_ value: ValueType) -> String {
        if case let .object(object) = value {
            if case let .string(text)? = object["preferencesText"] ?? object["text"] ?? object["value"] {
                return text
            }
            return ""
        }
        return stringValue(value)
    }

    private func localSuggestion() -> Object {
        [
            "id": .string("local-match-review"),
            "profile": .object([
                "displayName": .string("Lokal match-vurdering"),
                "headline": .string("Samtykke kreves"),
                "summary": .string("Forslaget er lokalt og starter ingen chat.")
            ]),
            "reasons": .string("Basert paa lokale preferanser. Krever eksplisitt godkjenning fra begge parter."),
            "chatEligible": .bool(false)
        ]
    }
}

private final class PersonalChatClientLocalCell: PersonalCopilotLocalCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override var readableKeys: [String] {
        ["state", "compose.body", "compose.contentType", "blockedUsers", "moderationStatus"]
    }

    override var writableKeys: [String] {
        [
            "invite",
            "acceptInvite",
            "declineInvite",
            "compose.body",
            "compose.contentType",
            "sendComposedMessage",
            "clearComposer",
            "reportMessage",
            "blockUser"
        ]
    }

    nonisolated override func initialState() -> Object {
        [
            "inviteStatus": .string("not invited"),
            "moderationStatus": .string("ready: filtering, report and block controls are visible"),
            "filteringStatus": .string("client-side safety gate active"),
            "blockedUsers": .list([]),
            "blockedUsersSummary": .string("No blocked users"),
            "compose": .object([
                "body": .string(""),
                "contentType": .string("text/plain")
            ]),
            "messages": .list([]),
            "messageCount": .integer(0),
            "meetingBridge": .object([
                "provider": .string("jitsi"),
                "joinURL": .string("disabled in v1"),
                "roomName": .string(""),
                "scheduledAt": .string(""),
                "requiresCameraMicrophoneConsent": .string("true - HAVEN does not request camera or microphone in v1")
            ]),
            "status": .string("Invite-only chat client is ready."),
            "updatedAt": .float(Date().timeIntervalSince1970)
        ]
    }

    override func handleSet(key: String, value: ValueType) async -> ValueType {
        switch key {
        case "invite":
            mergeState([
                "inviteStatus": .string("invite pending explicit acceptance"),
                "lastAction": .string("invite")
            ])
            return response(status: "ok", message: "Invite staged. Chat will not start until accepted.")
        case "acceptInvite":
            mergeState([
                "inviteStatus": .string("accepted"),
                "lastAction": .string("acceptInvite")
            ])
            return response(status: "ok", message: "Invite accepted locally.")
        case "declineInvite":
            mergeState([
                "inviteStatus": .string("declined"),
                "lastAction": .string("declineInvite")
            ])
            return response(status: "ok", message: "Invite declined locally.")
        case "compose.body":
            setStateValue(value, for: "compose.body")
            return response(status: "ok", message: "Composer draft updated locally.")
        case "compose.contentType":
            setStateValue(value, for: "compose.contentType")
            return response(status: "ok", message: "Composer content type updated.")
        case "sendComposedMessage":
            return sendComposedMessage()
        case "clearComposer":
            setStateValue(.string(""), for: "compose.body")
            return response(status: "ok", message: "Composer cleared.")
        case "reportMessage":
            mergeState([
                "moderationStatus": .string("latest visible message reported for review"),
                "lastAction": .string("reportMessage")
            ])
            return response(status: "ok", message: "Report recorded locally and ready for PersonalChatHub.")
        case "blockUser":
            mergeState([
                "blockedUsers": .list([.string("blocked-user")]),
                "blockedUsersSummary": .string("1 blocked user"),
                "moderationStatus": .string("blocked user cannot continue this conversation"),
                "inviteStatus": .string("blocked"),
                "lastAction": .string("blockUser")
            ])
            return response(status: "ok", message: "User blocked. Local send flow is disabled.")
        default:
            return await super.handleSet(key: key, value: value)
        }
    }

    private func sendComposedMessage() -> ValueType {
        guard case let .string(inviteStatus)? = stateValue(for: "inviteStatus"),
              inviteStatus == "accepted"
        else {
            return response(status: "blocked", message: "Invite must be accepted before sending.")
        }

        if case let .list(blocked)? = stateValue(for: "blockedUsers"), !blocked.isEmpty {
            return response(status: "blocked", message: "Message not sent because a participant is blocked.")
        }

        let body = stringValue(stateValue(for: "compose.body") ?? .string(""))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else {
            return response(status: "blocked", message: "Write a message before sending.")
        }

        let contentType = stringValue(stateValue(for: "compose.contentType") ?? .string("text/plain"))
        let timestamp = Date().timeIntervalSince1970
        var messages: [ValueType] = []
        if case let .list(existing)? = stateValue(for: "messages") {
            messages = existing
        }
        messages.append(.object([
            "id": .string(UUID().uuidString),
            "sender": .string("local-requester"),
            "body": .string(body),
            "contentType": .string(contentType),
            "sentAt": .float(timestamp),
            "delivery": .string("local-pending-hub-sync")
        ]))
        mergeState([
            "messages": .list(messages),
            "messageCount": .integer(messages.count),
            "compose": .object([
                "body": .string(""),
                "contentType": .string(contentType)
            ]),
            "lastAction": .string("sendComposedMessage")
        ])
        return response(status: "ok", message: "Message added locally and ready for hub sync.")
    }
}

private final class PersonalMeetingIntentLocalCell: PersonalCopilotLocalCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override var writableKeys: [String] {
        ["meeting.intent", "meeting.propose", "meeting.clear"]
    }

    nonisolated override func initialState() -> Object {
        [
            "intent": .string(""),
            "proposalStatus": .string("not proposed"),
            "calendarPermissionStatus": .string("not requested"),
            "nativeMediaPermissionStatus": .string("not requested"),
            "meetingBridge": .object([
                "provider": .string("jitsi"),
                "joinURL": .string("disabled in v1"),
                "roomName": .string(""),
                "scheduledAt": .string(""),
                "requiresCameraMicrophoneConsent": .string("true - no embed or media request in v1")
            ]),
            "status": .string("Meeting intent can be drafted without Calendar/EventKit or camera/microphone permissions."),
            "updatedAt": .float(Date().timeIntervalSince1970)
        ]
    }

    override func handleSet(key: String, value: ValueType) async -> ValueType {
        switch key {
        case "meeting.intent":
            mergeState([
                "intent": .string(stringValue(value)),
                "proposalStatus": .string("draft"),
                "lastAction": .string("meeting.intent")
            ])
            return response(status: "ok", message: "Meeting intent updated locally.")
        case "meeting.propose":
            mergeState([
                "proposalStatus": .string("ready for coordinator"),
                "lastAction": .string("meeting.propose")
            ])
            return response(status: "ok", message: "Meeting proposal staged as data only.")
        case "meeting.clear":
            replaceState(initialState())
            return response(status: "ok", message: "Meeting intent cleared.")
        default:
            return await super.handleSet(key: key, value: value)
        }
    }
}

private final class PersonalMeetingCoordinatorLocalCell: PersonalCopilotLocalCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
        refreshMeetingBridge(requesterUUID: owner.uuid)
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override var readableKeys: [String] {
        [
            PersonalMeetingCoordinatorContract.stateKeypath,
            PersonalMeetingCoordinatorContract.meetingBridgeKeypath
        ]
    }

    override var writableKeys: [String] {
        [
            PersonalMeetingCoordinatorContract.proposeMeetingKeypath,
            "proposeTimes",
            "acceptTime",
            "declineTime",
            "updateMeetingIntent",
            "clearMeetingIntent",
            "draft.title",
            "draft.targetProfileID",
            "draft.proposedTimesText"
        ]
    }

    nonisolated override func initialState() -> Object {
        let bridge = Self.defaultMeetingBridge(requesterUUID: "binding-local")
        return [
            "draft": .object(Self.emptyDraft()),
            "currentIntent": .null,
            "meetingIntent": .null,
            "proposedTimes": .list([]),
            "participants": .list([]),
            "coordinationStatus": .string("draft"),
            "meetingBridge": .object(bridge),
            "nativePermissionRequests": .list([]),
            "requiresExplicitCapabilityConsent": .bool(true),
            "status": .string("Meeting intent is staged locally as metadata only."),
            "updatedAt": .float(Date().timeIntervalSince1970)
        ]
    }

    override func handleSet(key: String, value: ValueType) async -> ValueType {
        switch key {
        case "draft.title":
            return updateDraft(field: "title", value: payloadString(value))
        case "draft.targetProfileID":
            return updateDraft(field: "targetProfileID", value: payloadString(value))
        case "draft.proposedTimesText":
            return updateDraft(field: "proposedTimesText", value: payloadString(value))
        case PersonalMeetingCoordinatorContract.proposeMeetingKeypath, "proposeTimes", "updateMeetingIntent":
            return proposeMeeting(payload: value)
        case "acceptTime":
            return updateCurrentIntent(status: "accepted", payload: value)
        case "declineTime":
            return updateCurrentIntent(status: "declined", payload: value)
        case "clearMeetingIntent":
            replaceState(initialState())
            return .object([
                "ok": .bool(true),
                "status": .string("cleared"),
                "meetingIntent": .null,
                "state": .object(stateObject())
            ])
        default:
            return await super.handleSet(key: key, value: value)
        }
    }

    private func updateDraft(field: String, value: String) -> ValueType {
        var draft = currentDraft()
        draft[field] = .string(value)
        setStateValue(.object(draft), for: "draft")
        mergeState([
            "coordinationStatus": .string("draft"),
            "lastAction": .string("draft.\(field)")
        ])
        return .object([
            "ok": .bool(true),
            "status": .string("ok"),
            "draft": .object(draft),
            "state": .object(stateObject())
        ])
    }

    private func proposeMeeting(payload: ValueType) -> ValueType {
        let object = objectValue(from: payload)
        let draft = currentDraft()
        let targetProfileID = stringValue("profileID", in: object)
            ?? stringValue("targetProfileID", in: object)
            ?? nonEmptyString(draft["targetProfileID"])
        let title = stringValue("title", in: object)
            ?? nonEmptyString(draft["title"])
            ?? "Personal Co-Pilot meeting intent"
        let proposedTimes = stringList("proposedTimes", in: object)
        let proposedTimesText = stringValue("proposedTimesText", in: object)
            ?? nonEmptyString(draft["proposedTimesText"])
            ?? ""
        let fallbackTimes = csvValues(proposedTimesText)
        let scheduledAt = stringValue("scheduledAt", in: object)
            ?? proposedTimes.first
            ?? fallbackTimes.first
            ?? Self.now()
        let allTimes = proposedTimes.isEmpty
            ? (fallbackTimes.isEmpty ? [scheduledAt] : fallbackTimes)
            : proposedTimes
        let requesterUUID = stringValue("requesterUUID", in: stateObject()) ?? "binding-local"
        let roomName = "haven-personal-\(Self.safeSlug(requesterUUID + "-" + (targetProfileID ?? "solo")))"
        let bridge = meetingBridge(
            roomName: roomName,
            scheduledAt: scheduledAt
        )
        var intent = meetingIntent(
            id: "meeting-\(UUID().uuidString)",
            requesterUUID: requesterUUID,
            targetProfileID: targetProfileID,
            title: title,
            scheduledAt: scheduledAt,
            createdAt: Self.now(),
            bridge: bridge,
            proposedTimes: allTimes,
            participants: normalize([requesterUUID] + [targetProfileID].compactMap { $0 }),
            acceptedTime: nil,
            declinedTimes: [],
            coordinationStatus: "proposed"
        )
        intent["ok"] = .bool(true)
        intent["status"] = .string("proposed")
        mergeState([
            "currentIntent": .object(intent),
            "meetingIntent": .object(intent),
            "proposedTimes": .list(allTimes.map(ValueType.string)),
            "participants": .list(strings(intent["participants"]).map(ValueType.string)),
            "coordinationStatus": .string("proposed"),
            "meetingBridge": .object(bridge),
            "nativePermissionRequests": .list([]),
            "lastAction": .string("proposeTimes")
        ])
        intent["state"] = .object(stateObject())
        return .object(intent)
    }

    private func updateCurrentIntent(status: String, payload: ValueType) -> ValueType {
        var state = stateObject()
        let intent: Object
        if case let .object(existing)? = state["currentIntent"] {
            intent = existing
        } else {
            _ = proposeMeeting(payload: payload)
            state = stateObject()
            intent = object(state["currentIntent"]) ?? [:]
        }

        var updated = intent
        let scheduledAt = stringValue("scheduledAt", in: objectValue(from: payload))
            ?? stringValue("time", in: objectValue(from: payload))
            ?? firstString(in: intent["proposedTimes"])
            ?? stringValue("scheduledAt", in: intent)
            ?? Self.now()
        updated["coordinationStatus"] = .string(status)
        updated["status"] = .string(status)
        if status == "accepted" {
            updated["acceptedTime"] = .string(scheduledAt)
            updated["scheduledAt"] = .string(scheduledAt)
        } else if status == "declined" {
            var declinedTimes = strings(intent["declinedTimes"])
            declinedTimes.append(scheduledAt)
            updated["declinedTimes"] = .list(normalize(declinedTimes).map(ValueType.string))
        }

        if var bridge = object(updated["meetingBridge"]) {
            bridge["scheduledAt"] = .string(scheduledAt)
            updated["meetingBridge"] = .object(bridge)
            state["meetingBridge"] = .object(bridge)
        }

        state["currentIntent"] = .object(updated)
        state["meetingIntent"] = .object(updated)
        state["coordinationStatus"] = .string(status)
        state["lastAction"] = .string(status == "accepted" ? "acceptTime" : "declineTime")
        replaceState(state)
        updated["ok"] = .bool(true)
        updated["state"] = .object(stateObject())
        return .object(updated)
    }

    private func refreshMeetingBridge(requesterUUID: String) {
        guard object(stateValue(for: "currentIntent")) == nil else { return }
        mergeState([
            "requesterUUID": .string(requesterUUID),
            "meetingBridge": .object(Self.defaultMeetingBridge(requesterUUID: requesterUUID))
        ])
    }

    private func currentDraft() -> Object {
        object(stateValue(for: "draft")) ?? Self.emptyDraft()
    }

    private static func emptyDraft() -> Object {
        [
            "title": .string(""),
            "targetProfileID": .string(""),
            "proposedTimesText": .string("")
        ]
    }

    private static func defaultMeetingBridge(requesterUUID: String) -> Object {
        let roomName = "haven-personal-\(safeSlug(requesterUUID))"
        return meetingBridge(roomName: roomName, scheduledAt: now())
    }

    private static func meetingBridge(roomName: String, scheduledAt: String) -> Object {
        [
            "provider": .string("jitsi"),
            "joinURL": .string("https://meet.jit.si/\(roomName)"),
            "roomName": .string(roomName),
            "scheduledAt": .string(scheduledAt),
            "requiresCameraMicrophoneConsent": .bool(true),
            "nativePermissionRequests": .list([])
        ]
    }

    private func meetingBridge(roomName: String, scheduledAt: String) -> Object {
        Self.meetingBridge(roomName: roomName, scheduledAt: scheduledAt)
    }

    private func meetingIntent(
        id: String,
        requesterUUID: String,
        targetProfileID: String?,
        title: String,
        scheduledAt: String,
        createdAt: String,
        bridge: Object,
        proposedTimes: [String],
        participants: [String],
        acceptedTime: String?,
        declinedTimes: [String],
        coordinationStatus: String
    ) -> Object {
        [
            "id": .string(id),
            "requesterUUID": .string(requesterUUID),
            "targetProfileID": targetProfileID.map(ValueType.string) ?? .null,
            "title": .string(title),
            "scheduledAt": .string(scheduledAt),
            "createdAt": .string(createdAt),
            "proposedTimes": .list(proposedTimes.map(ValueType.string)),
            "participants": .list(participants.map(ValueType.string)),
            "acceptedTime": acceptedTime.map(ValueType.string) ?? .null,
            "declinedTimes": .list(declinedTimes.map(ValueType.string)),
            "coordinationStatus": .string(coordinationStatus),
            "meetingBridge": .object(bridge)
        ]
    }

    private func payloadString(_ payload: ValueType) -> String {
        switch payload {
        case let .string(text):
            return text
        case let .object(object):
            return stringValue("value", in: object)
                ?? stringValue("text", in: object)
                ?? stringValue("body", in: object)
                ?? ""
        default:
            return stringValue(payload)
        }
    }

    private func objectValue(from payload: ValueType) -> Object {
        object(payload) ?? [:]
    }

    private func stringValue(_ key: String, in object: Object) -> String? {
        nonEmptyString(object[key])
    }

    private func nonEmptyString(_ value: ValueType?) -> String? {
        guard let value else { return nil }
        let string: String?
        switch value {
        case let .string(text):
            string = text
        case let .integer(number):
            string = String(number)
        case let .number(number):
            string = String(number)
        case let .float(number):
            string = String(number)
        case let .bool(flag):
            string = flag ? "true" : "false"
        default:
            string = nil
        }
        let trimmed = string?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func firstString(in value: ValueType?) -> String? {
        strings(value).first
    }

    private func stringList(_ key: String, in object: Object) -> [String] {
        guard let value = object[key] else { return [] }
        return strings(value)
    }

    private func object(_ value: ValueType?) -> Object? {
        guard case let .object(object)? = value else { return nil }
        return object
    }

    private func strings(_ value: ValueType?) -> [String] {
        switch value {
        case let .list(values):
            return normalize(values.compactMap { nonEmptyString($0) })
        case let .string(text):
            return normalize(text.split(separator: ",").map(String.init))
        default:
            return []
        }
    }

    private func csvValues(_ value: String) -> [String] {
        normalize(value.split(separator: ",").map(String.init))
    }

    private func normalize(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var normalized: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            normalized.append(trimmed)
        }
        return normalized
    }

    private static func safeSlug(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let scalars = raw.lowercased().unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let slug = String(scalars).split(separator: "-").joined(separator: "-")
        return slug.isEmpty ? UUID().uuidString.lowercased() : slug
    }

    private static func now() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}

private final class PersonalCopilotCatalogLocalCell: PersonalCopilotLocalCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override var readableKeys: [String] {
        [
            PersonalCopilotAppStoreV1Contract.catalogStateKeypath,
            PersonalCopilotAppStoreV1Contract.catalogEntriesKeypath,
            PersonalCopilotAppStoreV1Contract.catalogConfigurationsKeypath,
            "policySummary",
            "purposeGoal",
            "skeletonConfiguration"
        ]
    }

    nonisolated override func initialState() -> Object {
        let configurations = ConfigurationCatalogCell.personalCopilotV1MenuConfigurations()
        let entries = configurations.map(Self.catalogEntry)
        return [
            "appStoreScope": .string(PersonalCopilotAppStoreV1Contract.appStoreScope),
            "configurationCount": .integer(configurations.count),
            "policySummary": .string("HAVEN viser kun allowlistede Personal Co-Pilot V1-flater i lokal katalog."),
            "catalogEntries": .list(entries.map(ValueType.object)),
            "configurations": .list(configurations.map(ValueType.cellConfiguration)),
            "status": .string("Local Personal Co-Pilot catalog is ready."),
            "updatedAt": .float(Date().timeIntervalSince1970)
        ]
    }

    private static func catalogEntry(_ configuration: CellConfiguration) -> Object {
        let metadata = BindingPersonalCopilotSurfaceMetadata(configuration: configuration)
        return [
            "id": .string(configuration.uuid),
            "displayName": .string(configuration.name),
            "summary": .string(configuration.description ?? configuration.discovery?.purposeDescription ?? ""),
            "sourceCellEndpoint": .string(configuration.discovery?.sourceCellEndpoint ?? ""),
            "configuration": .object(configurationObject(configuration)),
            "metadata": .object([
                "appStoreScope": .string(metadata.appStoreScope ?? ""),
                "policyCategory": .string(metadata.policyCategory ?? ""),
                "surfaceFamily": .string(metadata.surfaceFamily ?? ""),
                "presentationClass": .string(metadata.presentationClass ?? ""),
                "executionScope": .string(metadata.sourceKind.rawValue),
                "reviewSummary": .string(metadata.reviewSummary ?? "")
            ])
        ]
    }

    private static func configurationObject(_ configuration: CellConfiguration) -> Object {
        guard let data = try? JSONEncoder().encode(configuration),
              let decoded = try? JSONDecoder().decode(ValueType.self, from: data),
              case let .object(object) = decoded
        else {
            return [
                "name": .string(configuration.name),
                "uuid": .string(configuration.uuid)
            ]
        }
        return object
    }
}

private final class PersonalPrivacyAuditLocalCell: PersonalCopilotLocalCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override var writableKeys: [String] {
        ["audit.record"]
    }

    nonisolated override func initialState() -> Object {
        [
            "audit": .object([
                "entries": .list([
                    .object([
                        "kind": .string("system"),
                        "summary": .string("Personal Co-Pilot privacy audit started locally."),
                        "createdAt": .float(Date().timeIntervalSince1970)
                    ])
                ])
            ]),
            "status": .string("Privacy audit is local to this device."),
            "updatedAt": .float(Date().timeIntervalSince1970)
        ]
    }

    override func handleSet(key: String, value: ValueType) async -> ValueType {
        guard key == "audit.record" else {
            return await super.handleSet(key: key, value: value)
        }

        appendStateListValue(.object([
            "kind": .string("user-action"),
            "summary": .string(stringValue(value)),
            "createdAt": .float(Date().timeIntervalSince1970)
        ]), for: "audit.entries")
        return response(status: "ok", message: "Privacy audit entry recorded locally.")
    }
}

private final class PersonalCopilotNavigatorLocalCell: PersonalCopilotLocalCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override var writableKeys: [String] {
        ["dispatchAction"]
    }

    nonisolated override func initialState() -> Object {
        [
            "status": .string("Ready to open personal surfaces."),
            "lastOpened": .string(""),
            "updatedAt": .float(Date().timeIntervalSince1970)
        ]
    }

    override func handleSet(key: String, value: ValueType) async -> ValueType {
        guard key == "dispatchAction" else {
            return await super.handleSet(key: key, value: value)
        }
        guard case let .object(actionObject) = value,
              case let .string(actionKeypath)? = actionObject["keypath"] else {
            return response(status: "error", message: "Navigator action payload is missing a keypath.")
        }
        guard let configuration = configuration(for: actionKeypath) else {
            return response(status: "error", message: "Navigator action is not supported yet.")
        }

        let openingMessage = "Opening \(configuration.name)…"
        mergeState([
            "lastAction": .string(actionKeypath),
            "lastOpened": .string(configuration.name)
        ])

        Task { @MainActor [weak self] in
            BindingPortholeLoadBridge.post(configuration: configuration)
            self?.mergeState([
                "status": .string("Opened \(configuration.name)."),
                "lastAction": .string(actionKeypath),
                "lastOpened": .string(configuration.name)
            ])
        }

        return response(status: "ok", message: openingMessage)
    }

    private func configuration(for actionKeypath: String) -> CellConfiguration? {
        switch actionKeypath {
        case "navigator.openCopilot":
            return ConfigurationCatalogCell.personalInviteChatMenuConfiguration()
        case "navigator.openMyProfile":
            return ConfigurationCatalogCell.personalProfileMenuConfiguration()
        case "navigator.openPublishPublicProfile":
            return ConfigurationCatalogCell.personalPublicProfileMenuConfiguration()
        case "navigator.openPrivacyAudit":
            return ConfigurationCatalogCell.personalPrivacyAuditMenuConfiguration()
        default:
            return nil
        }
    }
}

private final class PersonalUsageQuotaLocalCell: PersonalCopilotLocalCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override var readableKeys: [String] {
        ["state", "policy", "balance", "topUp"]
    }

    override var writableKeys: [String] {
        ["requestTopUp", "recordRemoteSnapshot", "applyPolicyUpdate"]
    }

    nonisolated override func initialState() -> Object {
        let now = Date().timeIntervalSince1970
        return [
            "title": .string("Brukskvote"),
            "status": .string("Klar. HAVEN viser registrert brukskvote og rettighetsstatus."),
            "productVariant": .string("usage_quota"),
            "paymentRole": .string("entitlement_client"),
            "transferability": .string("none"),
            "cashOut": .bool(false),
            "externalAcceptance": .bool(false),
            "nativePurchaseCTA": .string("disabled"),
            "unitModel": .object(Self.unitModelObject()),
            "balance": .object(Self.defaultBalanceObject(updatedAt: now)),
            "policy": .object(Self.defaultPolicyObject(updatedAt: now)),
            "topUp": .object(Self.defaultTopUpObject(updatedAt: now)),
            "hardStops": .list([
                .string("no_p2p_transfer"),
                .string("no_cash_out"),
                .string("no_external_acceptance"),
                .string("no_native_purchase_cta_in_app_store_mode"),
                .string("no_psp_direct_wallet_write")
            ]),
            "updatedAt": .float(now)
        ]
    }

    override func handleSet(key: String, value: ValueType) async -> ValueType {
        switch key {
        case "requestTopUp":
            return handleTopUpRequest(value)
        case "recordRemoteSnapshot":
            return recordRemoteSnapshot(value)
        case "applyPolicyUpdate":
            return applyPolicyUpdate(value)
        default:
            return await super.handleSet(key: key, value: value)
        }
    }

    private func handleTopUpRequest(_ value: ValueType) -> ValueType {
        let request = objectValue(value) ?? [:]
        let amountMinorUnits = intValue(request["amountMinorUnits"]) ?? 0
        let rail = normalizedRail(optionalStringValue(request["rail"]) ?? "stripe_checkout")
        let now = Date().timeIntervalSince1970

        guard amountMinorUnits > 0 else {
            return response(status: "error", message: "Brukskvote-forespørsel krever et positivt beløp.")
        }

        var topUp = topUpObject()
        topUp["lastRequestedAmountMinorUnits"] = .integer(amountMinorUnits)
        topUp["lastRequestedRail"] = .string(rail)
        topUp["lastRequestedAt"] = .float(now)
        topUp["providerRole"] = .string("external_top_up_only")
        topUp["checkoutEndpoint"] = .string("/chat-mvp/api/top-up/checkout")
        topUp["nativePurchaseCTA"] = .string("disabled")

        if BindingPersonalCopilotV1Policy.appStoreCatalogGateEnabled {
            topUp["status"] = .string("blocked_in_app_store_mode")
            topUp["nextStep"] = .string("HAVEN kan fortsette når en gyldig brukskvote er registrert.")
            mergeState([
                "topUp": .object(topUp),
                "lastAction": .string("requestTopUp"),
                "updatedAt": .float(now)
            ])
            return response(status: "blocked", message: "Brukskvote-påfyll er ikke tilgjengelig i denne HAVEN-flaten.")
        }

        topUp["status"] = .string("checkout_delegated")
        topUp["nextStep"] = .string("Åpne påfyll i CellScaffold og registrer signert brukskvotehendelse når den er bekreftet.")
        mergeState([
            "topUp": .object(topUp),
            "lastAction": .string("requestTopUp"),
            "updatedAt": .float(now)
        ])
        return .object([
            "status": .string("delegated"),
            "providerRole": .string("external_top_up_only"),
            "checkoutEndpoint": .string("/chat-mvp/api/top-up/checkout"),
            "amountMinorUnits": .integer(amountMinorUnits),
            "rail": .string(rail),
            "requiresServerCheckout": .bool(true),
            "state": .object(stateObject())
        ])
    }

    private func recordRemoteSnapshot(_ value: ValueType) -> ValueType {
        guard var snapshot = objectValue(value) else {
            return response(status: "error", message: "Remote usage-quota snapshot must be an object.")
        }

        let variant = optionalStringValue(snapshot["productVariant"]) ?? "usage_quota"
        guard variant == "usage_quota" || variant == "access_entitlement" else {
            return response(status: "blocked", message: "Rejected money-like remote snapshot variant.")
        }

        snapshot["productVariant"] = .string(variant)
        snapshot["transferability"] = .string("none")
        snapshot["cashOut"] = .bool(false)
        snapshot["externalAcceptance"] = .bool(false)
        snapshot["updatedAt"] = .float(Date().timeIntervalSince1970)

        var state = stateObject()
        if let balance = objectValue(snapshot["balance"]) {
            state["balance"] = .object(normalizedBalanceObject(balance))
        }
        state["remoteSnapshot"] = .object(snapshot)
        state["lastAction"] = .string("recordRemoteSnapshot")
        replaceState(state)
        return response(status: "ok", message: "Remote usage-quota snapshot recorded.")
    }

    private func applyPolicyUpdate(_ value: ValueType) -> ValueType {
        guard let update = objectValue(value) else {
            return response(status: "error", message: "Policy update must be an object.")
        }

        var policy = policyObject()
        for (key, value) in update {
            switch key {
            case "monthlyTopUpCapMinorUnits", "maxSpendPerActionMinorUnits", "receiptMode", "lowBalanceBehavior":
                policy[key] = value
            default:
                continue
            }
        }
        policy["productVariant"] = .string("usage_quota")
        policy["transferability"] = .string("none")
        policy["cashOut"] = .bool(false)
        policy["externalAcceptance"] = .bool(false)
        policy["autoTopUpEnabled"] = .bool(false)
        policy["updatedAt"] = .float(Date().timeIntervalSince1970)

        mergeState([
            "policy": .object(policy),
            "lastAction": .string("applyPolicyUpdate")
        ])
        return response(status: "ok", message: "Usage-quota policy updated locally.")
    }

    private func policyObject() -> Object {
        objectValue(stateValue(for: "policy")) ?? Self.defaultPolicyObject(updatedAt: Date().timeIntervalSince1970)
    }

    private func topUpObject() -> Object {
        objectValue(stateValue(for: "topUp")) ?? Self.defaultTopUpObject(updatedAt: Date().timeIntervalSince1970)
    }

    private func normalizedBalanceObject(_ raw: Object) -> Object {
        let now = Date().timeIntervalSince1970
        return [
            "quotaUnits": .integer(max(0, intValue(raw["quotaUnits"]) ?? intValue(raw["tokenUnits"]) ?? 0)),
            "settlementMinorUnits": .integer(max(0, intValue(raw["settlementMinorUnits"]) ?? intValue(raw["balanceMinorUnits"]) ?? 0)),
            "currency": .string(optionalStringValue(raw["currency"]) ?? "NOK"),
            "source": .string(optionalStringValue(raw["source"]) ?? "cellscaffold"),
            "updatedAt": .float(now)
        ]
    }

    private func normalizedRail(_ raw: String) -> String {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "stripe", "stripe_card", "stripe_apple_pay", "stripe_google_pay":
            return "stripe_checkout"
        case "vipps", "vipps_mobilepay":
            return "vipps_mobilepay"
        default:
            return "stripe_checkout"
        }
    }

    private func objectValue(_ value: ValueType?) -> Object? {
        guard case let .object(object)? = value else { return nil }
        return object
    }

    private func optionalStringValue(_ value: ValueType?) -> String? {
        guard let value else { return nil }
        return stringValue(value)
    }

    private func intValue(_ value: ValueType?) -> Int? {
        switch value {
        case let .integer(number)?:
            return number
        case let .number(number)?:
            return number
        case let .float(number)?:
            return Int(number)
        case let .string(text)?:
            return Int(text)
        default:
            return nil
        }
    }

    private static func unitModelObject() -> Object {
        [
            "settlementCurrency": .string("NOK"),
            "settlementMinorUnitsPerMajorUnit": .integer(100),
            "quotaUnitsPerSettlementMinorUnit": .integer(1_000),
            "userFacingUnit": .string("usage_quota_unit"),
            "internalLedgerUnit": .string("value_unit"),
            "externalRailsRole": .string("top_up_only"),
            "microtransactionSettlement": .string("internal_ledger"),
            "productVariant": .string("usage_quota"),
            "transferability": .string("none"),
            "cashOut": .bool(false),
            "externalAcceptance": .bool(false)
        ]
    }

    private static func defaultBalanceObject(updatedAt: TimeInterval) -> Object {
        [
            "quotaUnits": .integer(0),
            "settlementMinorUnits": .integer(0),
            "currency": .string("NOK"),
            "source": .string("local_empty"),
            "updatedAt": .float(updatedAt)
        ]
    }

    private static func defaultPolicyObject(updatedAt: TimeInterval) -> Object {
        [
            "productVariant": .string("usage_quota"),
            "monthlyTopUpCapMinorUnits": .integer(20_000),
            "maxSpendPerActionMinorUnits": .integer(10),
            "receiptMode": .string("always"),
            "lowBalanceBehavior": .string("ask_before_topup"),
            "autoTopUpEnabled": .bool(false),
            "transferability": .string("none"),
            "cashOut": .bool(false),
            "externalAcceptance": .bool(false),
            "updatedAt": .float(updatedAt)
        ]
    }

    private static func defaultTopUpObject(updatedAt: TimeInterval) -> Object {
        [
            "status": .string("not_requested"),
            "providerRole": .string("external_top_up_only"),
            "checkoutEndpoint": .string("/chat-mvp/api/top-up/checkout"),
            "nativePurchaseCTA": .string("disabled"),
            "appStoreCatalogGateEnabled": .bool(BindingPersonalCopilotV1Policy.appStoreCatalogGateEnabled),
            "allowedRails": .list([
                .string("stripe_checkout"),
                .string("stripe_apple_pay"),
                .string("vipps_mobilepay")
            ]),
            "updatedAt": .float(updatedAt)
        ]
    }
}

private final class ConferenceConfigurationNavigatorLocalCell: PersonalCopilotLocalCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override var writableKeys: [String] {
        ["dispatchAction"]
    }

    nonisolated override func initialState() -> Object {
        [
            "status": .string("Ready to open conference configurations."),
            "lastOpened": .string(""),
            "updatedAt": .float(Date().timeIntervalSince1970)
        ]
    }

    override func handleSet(key: String, value: ValueType) async -> ValueType {
        guard key == "dispatchAction" else {
            return await super.handleSet(key: key, value: value)
        }
        guard case let .object(actionObject) = value,
              case let .string(actionKeypath)? = actionObject["keypath"] else {
            return response(status: "error", message: "Conference navigator action payload is missing a keypath.")
        }
        guard let configuration = configuration(for: actionKeypath) else {
            return response(status: "error", message: "Conference navigator action is not supported yet.")
        }

        let openingMessage = "Opening \(configuration.name)…"
        mergeState([
            "lastAction": .string(actionKeypath),
            "lastOpened": .string(configuration.name)
        ])

        Task { @MainActor [weak self] in
            BindingPortholeLoadBridge.post(configuration: configuration)
            self?.mergeState([
                "status": .string("Opened \(configuration.name)."),
                "lastAction": .string(actionKeypath),
                "lastOpened": .string(configuration.name)
            ])
        }

        return response(status: "ok", message: openingMessage)
    }

    private func configuration(for actionKeypath: String) -> CellConfiguration? {
        switch actionKeypath {
        case "navigator.openConferenceCodexLiveConfigurations":
            return ConfigurationCatalogCell.conferenceCodexLiveConfigurationsMenuConfiguration()
        case "navigator.openConferenceClaudeDesignReference":
            return ConfigurationCatalogCell.conferenceClaudeDesignReferenceMenuConfiguration()
        case "navigator.openConferenceDemoLauncher":
            return ConfigurationCatalogCell.conferenceDemoLauncherWorkbenchConfiguration()
        case "navigator.openConferenceParticipantPortal":
            return ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
                endpoint: "cell:///ConferenceParticipantPreviewShell"
            )
        case "navigator.openConferenceAIAssistant":
            return ConfigurationCatalogCell.conferenceAIAssistantWorkbenchConfiguration(
                conferenceEndpoint: "cell:///ConferenceParticipantPreviewShell",
                aiEndpoint: "cell:///ConferenceAIAssistantGatewayProxy"
            )
        case "navigator.openConferenceControlTower":
            return ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
                endpoint: "cell:///ConferenceAdminPreviewShell"
            )
        case "navigator.openConferencePublicSurface":
            return ConfigurationCatalogCell.conferencePublicWorkbenchConfiguration(
                endpoint: "cell:///ConferencePublicShellFixture"
            )
        case "navigator.openConferenceSponsorFollowUp":
            return ConfigurationCatalogCell.conferenceSponsorWorkbenchConfiguration(
                endpoint: "cell:///ConferenceSponsorShellFixture"
            )
        case "navigator.openConferenceNearbyRadar":
            return ConfigurationCatalogCell.conferenceNearbyRadarWorkbenchConfiguration(
                participantEndpoint: "cell:///ConferenceParticipantPreviewShell"
            )
        case "navigator.openConferenceParticipantChat":
            return ConfigurationCatalogCell.conferenceParticipantChatWorkbenchConfiguration(
                participantEndpoint: "cell:///ConferenceParticipantPreviewShell"
            )
        default:
            return nil
        }
    }
}

private final class ConferenceAIAssistantGatewayProxyCell: GeneralCell {
    private static let localGatewayEndpoint = "cell:///AIGateway"
    private static let stagingGatewayEndpoint = "cell://staging.haven.digipomps.org/ConferenceAIGatewayPreview"
    private static let resolveTimeoutNanoseconds: UInt64 = 15_000_000_000
    private static let remoteResolveRetryDelayNanoseconds: UInt64 = 2_000_000_000
    private static let remoteResolveRetryAttempts = 8
    private static let stateReadTimeoutNanoseconds: UInt64 = 20_000_000_000
    private static let mutationTimeoutNanoseconds: UInt64 = 25_000_000_000
    private var pendingAPIKeyEntry = ""
    private var lastResolvedGatewayEndpoint: String?
    private var lastFailureMessage: String?
    private var cachedGateway: Meddle?
    private var cachedGatewayEndpoint: String?
    private var cachedStateValue: ValueType?
    private var cachedStateUpdatedAt: Date?
    private var pendingStateLoadTask: Task<(endpoint: String, value: ValueType), Error>?
    private var draftPrompt = ""
    private var draftSystemPrompt = ""
    private var draftProviderID = "openai-compatible"
    private var draftModel = "gpt-4.1-mini"
    private var draftBaseURL = ""
    private var draftAPIKeyAlias = ""
    private var draftTemperatureText = ""
    private var draftMaxTokensText = ""
    private var draftDeterministicMode = false
    private var draftRequiresAPIKey = true
    private var activeCredentialSource = "environment"
    private var lastInvocationOutputPreview = "Conference copilot is ready in HAVEN local preview. Load a prompt or session key to keep drafting while the scaffold gateway warms up."
    private var lastInvocationWarningsText = ""
    private var lastInvocationErrorsText = ""
    private var lastInvocationQuotaStatus = "localPreview"
    private var lastInvocationHasResult = false

    private static let readableKeys = [
        "state",
        "contracts",
        "purposeGoal",
        "configuration",
        "skeletonConfiguration"
    ]
    private static let writableKeys = [
        "applyDraftProfile",
        "setDraftPrompt",
        "setDraftSystemPrompt",
        "setDraftProviderID",
        "setDraftModel",
        "setDraftBaseURL",
        "setDraftAPIKeyAlias",
        "setDraftTemperatureText",
        "setDraftMaxTokensText",
        "setDraftDeterministicMode",
        "setDraftRequiresAPIKey",
        "setDraftAPIKeyEntry",
        "commitDraftAPIKeyEntry",
        "setDraftAPIKey",
        "clearDraftAPIKey",
        "persistDraftAPIKey",
        "invokeDraft",
        "ai.invoke",
        "invokeAI"
    ]
    private static let stateCacheLifetime: TimeInterval = 3

    required init(owner: Identity) async {
        await super.init(owner: owner)
        Self.readableKeys.forEach { agreementTemplate.addGrant("r---", for: $0) }
        Self.writableKeys.forEach { agreementTemplate.addGrant("rw--", for: $0) }

        for key in Self.readableKeys {
            await addInterceptForGet(requester: owner, key: key) { [weak self] _, requester in
                guard let self else { return .string("failure") }
                return await self.forwardGet(keypath: key, requester: requester)
            }
        }

        for key in Self.writableKeys {
            await addInterceptForSet(requester: owner, key: key) { [weak self] _, value, requester in
                guard let self else { return .string("failure") }
                return await self.forwardSet(keypath: key, value: value, requester: requester)
            }
        }
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private func resolveGateway(requester: Identity) async throws -> (endpoint: String, gateway: Meddle) {
        guard await BindingLocalCellRegistration.shared.ensureConferenceDemoRuntimeReady() else {
            throw CellBaseError.noResolver
        }
        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            throw CellBaseError.noResolver
        }

        if let cachedGateway, let cachedGatewayEndpoint {
            return (cachedGatewayEndpoint, cachedGateway)
        }

        var failureMessages: [String] = []
        for endpoint in [Self.stagingGatewayEndpoint, Self.localGatewayEndpoint] {
            let maxAttempts = endpoint == Self.stagingGatewayEndpoint ? Self.remoteResolveRetryAttempts : 1
            var lastError: Error?

            for attempt in 1...maxAttempts {
                do {
                    let gateway = try await resolveGateway(
                        at: endpoint,
                        with: resolver,
                        requester: requester
                    )
                    cachedGateway = gateway
                    cachedGatewayEndpoint = endpoint
                    lastResolvedGatewayEndpoint = endpoint
                    lastFailureMessage = nil
                    return (endpoint, gateway)
                } catch {
                    lastError = error
                    let shouldRetry = endpoint == Self.stagingGatewayEndpoint
                        && attempt < maxAttempts
                        && shouldRetryRemoteGatewayResolution(after: error)
                    if shouldRetry {
                        try? await Task.sleep(nanoseconds: Self.remoteResolveRetryDelayNanoseconds)
                        continue
                    }
                    break
                }
            }

            if let lastError {
                failureMessages.append("\(endpoint): \(lastError.localizedDescription)")
            }
        }

        throw ConferenceAIGatewayProxyResolutionError(
            endpoint: Self.stagingGatewayEndpoint,
            details: failureMessages
        )
    }

    private func resolveGateway(
        at endpoint: String,
        with resolver: CellResolver,
        requester: Identity
    ) async throws -> Meddle {
        try await withThrowingTaskGroup(of: Meddle.self) { group in
            group.addTask {
                let gateway = try await RemoteEndpointAccessSupport.resolveMeddle(
                    endpoint: endpoint,
                    resolver: resolver,
                    requester: requester,
                    accessLabel: "conferenceAIGatewayProxy"
                )
                return gateway
            }
            group.addTask {
                try await Task.sleep(nanoseconds: Self.resolveTimeoutNanoseconds)
                throw ConferenceAIGatewayProxyTimeoutError(
                    operation: "resolve",
                    endpoint: endpoint
                )
            }

            guard let firstResult = try await group.next() else {
                throw ConferenceAIGatewayProxyTimeoutError(
                    operation: "resolve",
                    endpoint: endpoint
                )
            }
            group.cancelAll()
            return firstResult
        }
    }

    private func shouldRetryRemoteGatewayResolution(after error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if error is ConferenceAIGatewayProxyTimeoutError {
            return true
        }

        if case let RemoteEndpointAccessSupport.AccessError.contractRejected(_, state) = error,
           state == ConnectState.notConnected.rawValue {
            return true
        }

        let description = error.localizedDescription.lowercased()
        if description.contains("notconnected") || description.contains("timeout") {
            return true
        }

        return false
    }

    private func gatewayGet(
        _ keypath: String,
        from gateway: Meddle,
        requester: Identity
    ) async throws -> ValueType {
        try await withThrowingTaskGroup(of: ValueType.self) { group in
            group.addTask {
                try await gateway.get(keypath: keypath, requester: requester)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: Self.stateReadTimeoutNanoseconds)
                throw ConferenceAIGatewayProxyTimeoutError(
                    operation: "get(\(keypath))",
                    endpoint: "gateway"
                )
            }

            guard let firstResult = try await group.next() else {
                throw ConferenceAIGatewayProxyTimeoutError(
                    operation: "get(\(keypath))",
                    endpoint: "gateway"
                )
            }
            group.cancelAll()
            return firstResult
        }
    }

    private func gatewaySet(
        _ keypath: String,
        value: ValueType,
        on gateway: Meddle,
        requester: Identity
    ) async throws -> ValueType? {
        try await withThrowingTaskGroup(of: ValueType?.self) { group in
            group.addTask {
                try await gateway.set(keypath: keypath, value: value, requester: requester)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: Self.mutationTimeoutNanoseconds)
                throw ConferenceAIGatewayProxyTimeoutError(
                    operation: "set(\(keypath))",
                    endpoint: "gateway"
                )
            }

            guard let firstResult = try await group.next() else {
                throw ConferenceAIGatewayProxyTimeoutError(
                    operation: "set(\(keypath))",
                    endpoint: "gateway"
                )
            }
            group.cancelAll()
            return firstResult
        }
    }

    private func cachedStateIfFresh() -> ValueType? {
        guard lastResolvedGatewayEndpoint == Self.localGatewayEndpoint,
              let cachedStateValue,
              let cachedStateUpdatedAt,
              Date().timeIntervalSince(cachedStateUpdatedAt) <= Self.stateCacheLifetime else {
            return nil
        }
        return cachedStateValue
    }

    private func storeCachedState(_ value: ValueType) {
        cachedStateValue = value
        cachedStateUpdatedAt = Date()
    }

    private func clearCachedState() {
        cachedStateValue = nil
        cachedStateUpdatedAt = nil
    }

    private func persistedSnapshot(for keypath: String, requester: Identity) async -> ValueType? {
        // Remote snapshots have no Storage-authority receipt yet, so they
        // cannot outlive a fresh admission decision. Local preview state is
        // requester-owned and may remain available while the bridge recovers.
        await PortableSurfaceCacheStore.shared.snapshot(
            for: Self.localGatewayEndpoint,
            keypath: keypath,
            requester: requester
        )
    }

    private func purgeRemoteStateAfterAuthorizationDenial(requester: Identity) async {
        cachedGateway = nil
        cachedGatewayEndpoint = nil
        clearCachedState()
        await PortableSurfaceCacheStore.shared.remove(
            endpoint: Self.stagingGatewayEndpoint,
            requester: requester
        )
        if let lastResolvedGatewayEndpoint,
           lastResolvedGatewayEndpoint != Self.localGatewayEndpoint {
            await PortableSurfaceCacheStore.shared.remove(
                endpoint: lastResolvedGatewayEndpoint,
                requester: requester
            )
        }
    }

    private func fetchGatewayState(requester: Identity) async throws -> (endpoint: String, value: ValueType) {
        let resolved = try await resolveGateway(requester: requester)
        do {
            let value = try await gatewayGet("state", from: resolved.gateway, requester: requester)
            if let failureDetail = gatewayFailureDetail(from: value) {
                throw ConferenceAIGatewayProxyResolutionError(
                    endpoint: resolved.endpoint,
                    details: [failureDetail]
                )
            }
            return (resolved.endpoint, value)
        } catch {
            if RemoteEndpointAccessSupport.isAuthorizationDenied(error),
               let emit = resolved.gateway as? Emit {
                RemoteEndpointAccessAuthorizer.shared.invalidate(
                    endpoint: resolved.endpoint,
                    emit: emit,
                    requester: requester,
                    kind: RemoteEndpointAccessSupport.authorizationKind(for: resolved.endpoint)
                )
            }
            cachedGateway = nil
            cachedGatewayEndpoint = nil
            if resolved.endpoint != Self.localGatewayEndpoint {
                let retried = try await resolveGateway(requester: requester)
                let value = try await gatewayGet("state", from: retried.gateway, requester: requester)
                if let failureDetail = gatewayFailureDetail(from: value) {
                    throw ConferenceAIGatewayProxyResolutionError(
                        endpoint: retried.endpoint,
                        details: [failureDetail]
                    )
                }
                return (retried.endpoint, value)
            }
            throw error
        }
    }

    private func loadGatewayState(requester: Identity) async -> ValueType {
        if let cached = cachedStateIfFresh(),
           gatewayFailureDetail(from: cached) == nil {
            return augmentGatewayState(cached)
        }

        if let pendingStateLoadTask {
            do {
                let result = try await pendingStateLoadTask.value
                return augmentGatewayState(result.value)
            } catch {
                if RemoteEndpointAccessSupport.isAuthorizationDenied(error) {
                    await purgeRemoteStateAfterAuthorizationDenial(requester: requester)
                }
                let message = "Conference AI gateway proxy get failed: \(error.localizedDescription)"
                lastFailureMessage = localPreviewMessage(after: message)
                print(message)
                if let cached = cachedStateIfFresh(),
                   gatewayFailureDetail(from: cached) == nil {
                    return augmentGatewayState(cached)
                }
                let fallback = localPreviewGatewayState()
                storeCachedState(fallback)
                return augmentGatewayState(fallback)
            }
        }

        let task = Task<(endpoint: String, value: ValueType), Error> { [weak self] in
            guard let self else { throw CancellationError() }
            return try await self.fetchGatewayState(requester: requester)
        }
        pendingStateLoadTask = task

        defer {
            pendingStateLoadTask = nil
        }

        do {
            let result = try await task.value
            storeCachedState(result.value)
            await PortableSurfaceCacheStore.shared.storeSnapshot(
                result.value,
                endpoint: result.endpoint,
                keypath: "state",
                requester: requester
            )
            lastFailureMessage = nil
            return augmentGatewayState(result.value)
        } catch {
            if RemoteEndpointAccessSupport.isAuthorizationDenied(error) {
                await purgeRemoteStateAfterAuthorizationDenial(requester: requester)
            }
            let message = "Conference AI gateway proxy get failed: \(error.localizedDescription)"
            lastFailureMessage = localPreviewMessage(after: message)
            print(message)
            if let cached = cachedStateIfFresh(),
               gatewayFailureDetail(from: cached) == nil {
                return augmentGatewayState(cached)
            }
            if let persisted = await persistedSnapshot(for: "state", requester: requester) {
                if gatewayFailureDetail(from: persisted) == nil {
                    storeCachedState(persisted)
                    return augmentGatewayState(persisted)
                }
            }
            let fallback = localPreviewGatewayState()
            storeCachedState(fallback)
            return augmentGatewayState(fallback)
        }
    }

    private func forwardGet(keypath: String, requester: Identity) async -> ValueType {
        if keypath == "state" {
            return await loadGatewayState(requester: requester)
        }

        do {
            let resolved = try await resolveGateway(requester: requester)
            let value: ValueType
            do {
                value = try await gatewayGet(keypath, from: resolved.gateway, requester: requester)
            } catch {
                if RemoteEndpointAccessSupport.isAuthorizationDenied(error),
                   let emit = resolved.gateway as? Emit {
                    RemoteEndpointAccessAuthorizer.shared.invalidate(
                        endpoint: resolved.endpoint,
                        emit: emit,
                        requester: requester,
                        kind: RemoteEndpointAccessSupport.authorizationKind(for: resolved.endpoint)
                    )
                }
                cachedGateway = nil
                cachedGatewayEndpoint = nil
                if resolved.endpoint != Self.localGatewayEndpoint {
                    let retried = try await resolveGateway(requester: requester)
                    value = try await gatewayGet(keypath, from: retried.gateway, requester: requester)
                } else {
                    throw error
                }
            }
            await PortableSurfaceCacheStore.shared.storeSnapshot(
                value,
                endpoint: lastResolvedGatewayEndpoint ?? resolved.endpoint,
                keypath: keypath,
                requester: requester
            )
            if let recoveredConfiguration = PortableSurfaceContractSupport.extractConfiguration(from: value) {
                await PortableSurfaceCacheStore.shared.storeConfiguration(
                    recoveredConfiguration,
                    endpoint: lastResolvedGatewayEndpoint ?? resolved.endpoint,
                    requester: requester
                )
            }
            return value
        } catch {
            if RemoteEndpointAccessSupport.isAuthorizationDenied(error) {
                await purgeRemoteStateAfterAuthorizationDenial(requester: requester)
            }
            let message = "Conference AI gateway proxy get failed: \(error.localizedDescription)"
            lastFailureMessage = message
            print(message)
            if let persisted = await persistedSnapshot(for: keypath, requester: requester) {
                return persisted
            }
            return .string(message)
        }
    }

    private func forwardSet(keypath: String, value: ValueType, requester: Identity) async -> ValueType {
        if let localResponse = handleLocalPreviewMutation(keypath: keypath, value: value) {
            return localResponse
        }

        do {
            clearCachedState()
            let resolved = try await resolveGateway(requester: requester)
            let gateway = resolved.gateway

            switch keypath {
            case "setDraftAPIKeyEntry":
                pendingAPIKeyEntry = conferenceMutationString(from: value)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let state = try await gatewayGet("state", from: gateway, requester: requester)
                storeCachedState(state)
                await PortableSurfaceCacheStore.shared.storeSnapshot(
                    state,
                    endpoint: resolved.endpoint,
                    keypath: "state",
                    requester: requester
                )
                return augmentGatewayState(state)
            case "commitDraftAPIKeyEntry":
                let response = try await gatewaySet(
                    "setDraftAPIKey",
                    value: .string(pendingAPIKeyEntry),
                    on: gateway,
                    requester: requester
                )
                let stateValue: ValueType
                if let response {
                    stateValue = response
                } else {
                    stateValue = try await gatewayGet("state", from: gateway, requester: requester)
                }
                storeCachedState(stateValue)
                await PortableSurfaceCacheStore.shared.storeSnapshot(
                    stateValue,
                    endpoint: resolved.endpoint,
                    keypath: "state",
                    requester: requester
                )
                return augmentGatewayState(stateValue)
            case "persistDraftAPIKey", "invokeDraft":
                if pendingAPIKeyEntry.isEmpty == false {
                    _ = try await gatewaySet(
                        "setDraftAPIKey",
                        value: .string(pendingAPIKeyEntry),
                        on: gateway,
                        requester: requester
                    )
                }
            case "clearDraftAPIKey":
                pendingAPIKeyEntry = ""
            case "setDraftAPIKey":
                pendingAPIKeyEntry = conferenceMutationString(from: value)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            default:
                break
            }

            if let response = try await gatewaySet(
                keypath,
                value: value,
                on: gateway,
                requester: requester
            ) {
                if gatewayFailureDetail(from: response) != nil {
                    return localPreviewResponse()
                }
                storeCachedState(response)
                await PortableSurfaceCacheStore.shared.storeSnapshot(
                    response,
                    endpoint: resolved.endpoint,
                    keypath: "state",
                    requester: requester
                )
                return augmentGatewayState(response)
            }
            let state = try await gatewayGet("state", from: gateway, requester: requester)
            if gatewayFailureDetail(from: state) != nil {
                return localPreviewResponse()
            }
            storeCachedState(state)
            await PortableSurfaceCacheStore.shared.storeSnapshot(
                state,
                endpoint: resolved.endpoint,
                keypath: "state",
                requester: requester
            )
            return augmentGatewayState(state)
        } catch {
            let message = "Conference AI gateway proxy set failed: \(error.localizedDescription)"
            lastFailureMessage = localPreviewMessage(after: message)
            cachedGateway = nil
            cachedGatewayEndpoint = nil
            clearCachedState()
            print(message)
            if let localResponse = handleLocalPreviewMutation(keypath: keypath, value: value) {
                return localResponse
            }
            return .object([
                "status": .string("error"),
                "state": localPreviewGatewayState()
            ])
        }
    }

    private func augmentGatewayState(_ value: ValueType) -> ValueType {
        guard case let .object(initialRootObject) = value else {
            return value
        }

        var rootObject: Object = initialRootObject
        guard case let .object(existingSetup)? = rootObject["setup"] else {
            return value
        }

        var setupObject: Object = existingSetup
        let pendingEntryPresent = pendingAPIKeyEntry.isEmpty == false
        setupObject["pendingEntryPresent"] = .bool(pendingEntryPresent)
        setupObject["pendingEntryStatus"] = .string(
            pendingEntryPresent
                ? "A local session key is buffered in this field. Invoke and Save API key will load it automatically."
                : ""
        )
        rootObject["setup"] = .object(setupObject)
        return .object(rootObject)
    }

    private func handleLocalPreviewMutation(keypath: String, value: ValueType) -> ValueType? {
        switch keypath {
        case "applyDraftProfile":
            if case let .object(object) = value {
                if case let .string(providerID)? = object["providerID"] {
                    draftProviderID = providerID
                }
                if case let .string(model)? = object["model"] {
                    draftModel = model
                }
                if case let .string(baseURL)? = object["baseURL"] {
                    draftBaseURL = baseURL
                }
                if case let .string(apiKeyAlias)? = object["apiKeyAlias"] {
                    draftAPIKeyAlias = apiKeyAlias
                }
                if case let .bool(requiresAPIKey)? = object["requiresAPIKey"] {
                    draftRequiresAPIKey = requiresAPIKey
                }
            }
        case "setDraftPrompt":
            draftPrompt = conferenceMutationString(from: value) ?? ""
        case "setDraftSystemPrompt":
            draftSystemPrompt = conferenceMutationString(from: value) ?? ""
        case "setDraftProviderID":
            draftProviderID = conferenceMutationString(from: value) ?? draftProviderID
        case "setDraftModel":
            draftModel = conferenceMutationString(from: value) ?? draftModel
        case "setDraftBaseURL":
            draftBaseURL = conferenceMutationString(from: value) ?? ""
        case "setDraftAPIKeyAlias":
            draftAPIKeyAlias = conferenceMutationString(from: value) ?? ""
        case "setDraftTemperatureText":
            draftTemperatureText = conferenceMutationString(from: value) ?? ""
        case "setDraftMaxTokensText":
            draftMaxTokensText = conferenceMutationString(from: value) ?? ""
        case "setDraftDeterministicMode":
            if case let .bool(isDeterministic) = value {
                draftDeterministicMode = isDeterministic
            }
        case "setDraftRequiresAPIKey":
            if case let .bool(requiresAPIKey) = value {
                draftRequiresAPIKey = requiresAPIKey
            }
        case "setDraftAPIKeyEntry":
            pendingAPIKeyEntry = conferenceMutationString(from: value)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        case "setDraftAPIKey":
            pendingAPIKeyEntry = conferenceMutationString(from: value)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if pendingAPIKeyEntry.isEmpty == false {
                activeCredentialSource = "session"
            }
        case "commitDraftAPIKeyEntry", "persistDraftAPIKey":
            if pendingAPIKeyEntry.isEmpty == false {
                activeCredentialSource = "session"
            }
        case "clearDraftAPIKey":
            pendingAPIKeyEntry = ""
            activeCredentialSource = draftRequiresAPIKey ? "environment" : "noAuth"
        case "invokeDraft", "ai.invoke", "invokeAI":
            let trimmedPrompt = draftPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedPrompt.isEmpty {
                lastInvocationHasResult = false
                lastInvocationQuotaStatus = "draftPromptRequired"
                lastInvocationWarningsText = "Draft prompt is required before invoke."
                lastInvocationErrorsText = ""
                lastInvocationOutputPreview = "Write or load a conference request before invoking the copilot."
                return localPreviewResponse()
            }
            lastInvocationHasResult = true
            lastInvocationQuotaStatus = "localPreview"
            lastInvocationWarningsText = "HAVEN is using local preview state while the scaffold gateway is unavailable."
            lastInvocationErrorsText = ""
            lastInvocationOutputPreview = "Local preview captured the current conference request and setup. Live AI invocation resumes automatically once a readable gateway is available."
        default:
            return nil
        }

        if activeCredentialSource != "session" {
            activeCredentialSource = draftRequiresAPIKey ? "environment" : "noAuth"
        }

        return localPreviewResponse()
    }

    private func localPreviewResponse() -> ValueType {
        let state = localPreviewGatewayState()
        storeCachedState(state)
        return .object([
            "status": .string("ok"),
            "state": state
        ])
    }

    private func localPreviewGatewayState() -> ValueType {
        let pendingEntryPresent = pendingAPIKeyEntry.isEmpty == false
        let credentialStatus: String
        switch activeCredentialSource {
        case "session":
            credentialStatus = "Session API key is loaded in HAVEN local preview."
        case "noAuth":
            credentialStatus = "Current preview profile does not require an API key."
        default:
            credentialStatus = "HAVEN local preview keeps the conference copilot editable even when the scaffold gateway is unavailable."
        }

        let pendingStatus: String
        if pendingEntryPresent {
            pendingStatus = "A local session key is buffered and can be loaded without leaving the workspace."
        } else if activeCredentialSource == "session" {
            pendingStatus = "Session API key is active in local preview."
        } else {
            pendingStatus = ""
        }

        let message = lastFailureMessage
            ?? "HAVEN local preview is active for Conference AI Assistant."

        return .object([
            "setup": .object([
                "statusLabel": .string("Conference AI setup is available in HAVEN local preview."),
                "nextStep": .string("Draft prompts, profile changes, and session-key loading all work locally while the scaffold gateway reconnects."),
                "providerLabel": .string("\(draftProviderID) · \(draftModel)"),
                "credentialStatus": .string(credentialStatus),
                "storageHint": .string("HAVEN keeps AI draft setup, prompt text, and session-key state available locally for the conference copilot."),
                "activeCredentialSource": .string(activeCredentialSource),
                "lastMessage": .string(message),
                "pendingEntryPresent": .bool(pendingEntryPresent),
                "pendingEntryStatus": .string(pendingStatus),
                "sessionCredentialAvailable": .bool(activeCredentialSource == "session")
            ]),
            "draft": .object([
                "prompt": .string(draftPrompt),
                "systemPrompt": .string(draftSystemPrompt),
                "providerID": .string(draftProviderID),
                "model": .string(draftModel),
                "baseURL": .string(draftBaseURL),
                "apiKeyAlias": .string(draftAPIKeyAlias),
                "temperatureText": .string(draftTemperatureText),
                "maxTokensText": .string(draftMaxTokensText),
                "deterministicMode": .bool(draftDeterministicMode),
                "requiresAPIKey": .bool(draftRequiresAPIKey),
                "cachePolicy": .string("useCache")
            ]),
            "lastInvocation": .object([
                "hasResult": .bool(lastInvocationHasResult),
                "providerID": .string(draftProviderID),
                "model": .string(draftModel),
                "cacheHit": .bool(false),
                "invokeTimeMs": .integer(0),
                "attempts": .integer(0),
                "quotaStatus": .string(lastInvocationQuotaStatus),
                "warningsText": .string(lastInvocationWarningsText),
                "errorsText": .string(lastInvocationErrorsText),
                "outputPreview": .string(lastInvocationOutputPreview)
            ]),
            "lastError": .string(lastInvocationErrorsText)
        ])
    }

    private func localPreviewMessage(after remoteFailure: String) -> String {
        "HAVEN local preview is active because the scaffold AI gateway is currently unavailable. \(remoteFailure)"
    }

    private func gatewayFailureDetail(from value: ValueType) -> String? {
        SkeletonBindingProbeSupport.failureDetail(from: value)
    }

    private func gatewayFailureState(message: String) -> Object {
        let pendingEntryPresent = pendingAPIKeyEntry.isEmpty == false
        let resolvedEndpoint = lastResolvedGatewayEndpoint ?? "Ingen lesbar gateway-route"

        return [
            "setup": .object([
                "statusLabel": .string("Conference AI gateway er utilgjengelig i HAVEN."),
                "nextStep": .string("Participant-konteksten er lastet, men embedded AIGateway ble ikke lesbar. Dette er en gateway-/bridge-feil, ikke en manglende prompt."),
                "providerLabel": .string(resolvedEndpoint),
                "credentialStatus": .string("En session key kan buffers lokalt, men ingen lesbar gateway var tilgjengelig for aa bruke den."),
                "storageHint": .string("HAVEN registrerer forelopig ikke en lokal AIGateway-cell. Live AI-path avhenger derfor av en lesbar scaffold-gateway over bridgehead."),
                "activeCredentialSource": .string("Ingen aktiv gateway"),
                "lastMessage": .string(lastFailureMessage ?? message),
                "pendingEntryPresent": .bool(pendingEntryPresent),
                "pendingEntryStatus": .string(
                    pendingEntryPresent
                        ? "En lokal session key ligger i buffer, men gatewayen er fortsatt utilgjengelig."
                        : ""
                )
            ]),
            "draft": .object([
                "prompt": .string(""),
                "systemPrompt": .string(""),
                "providerID": .string("openai-compatible"),
                "model": .string("gpt-4.1-mini"),
                "baseURL": .string(""),
                "apiKeyAlias": .string(""),
                "temperatureText": .string(""),
                "maxTokensText": .string(""),
                "deterministicMode": .bool(false),
                "requiresAPIKey": .bool(true),
                "cachePolicy": .string("useCache")
            ]),
            "lastInvocation": .object([
                "hasResult": .bool(false),
                "providerID": .string(""),
                "model": .string(""),
                "cacheHit": .bool(false),
                "invokeTimeMs": .integer(0),
                "attempts": .integer(0),
                "quotaStatus": .string("gatewayUnavailable"),
                "warningsText": .string(lastFailureMessage ?? message),
                "errorsText": .string(lastFailureMessage ?? message),
                "outputPreview": .string("Conference AI Assistant fant participant-konteksten, men ikke en lesbar AIGateway.")
            ])
        ]
    }
}

private struct ConferenceAIGatewayProxyTimeoutError: LocalizedError {
    let operation: String
    let endpoint: String

    var errorDescription: String? {
        "Conference AI gateway proxy timed out during \(operation) at \(endpoint)."
    }
}

private struct ConferenceAIGatewayProxyResolutionError: LocalizedError {
    let endpoint: String
    let details: [String]

    var errorDescription: String? {
        if details.isEmpty {
            return "Conference AI gateway proxy could not resolve meddle at \(endpoint)."
        }
        return "Conference AI gateway proxy could not resolve a readable gateway. Attempts: \(details.joined(separator: " | "))"
    }
}

private func conferenceMutationString(from value: ValueType?) -> String? {
    guard let value else { return nil }
    switch value {
    case let .string(string):
        return string
    case let .integer(integer):
        return String(integer)
    case let .number(number):
        return String(number)
    case let .float(float):
        return String(float)
    case let .bool(bool):
        return bool ? "true" : "false"
    default:
        return nil
    }
}

private func conferenceMutationErrorDescription(from value: ValueType?) -> String? {
    guard let value else { return "Ukjent conference-feil." }
    switch value {
    case let .string(string):
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        let normalized = trimmed.lowercased()
        if normalized == "denied"
            || normalized == "notfound"
            || normalized == "not found"
            || normalized == "timeout"
            || normalized == "finishedwithoutvalue"
            || normalized.hasPrefix("error:")
            || normalized.hasPrefix("failure")
            || normalized.contains("notfound")
            || normalized.contains("finishedwithoutvalue") {
            return trimmed
        }
        return nil
    case let .object(object):
        if let status = conferenceMutationString(from: object["status"])?.lowercased(),
           ["error", "denied", "notfound", "timeout", "finishedwithoutvalue"].contains(status),
           let message = conferenceMutationString(from: object["message"]) {
            return message
        }
        if let error = conferenceMutationString(from: object["error"])?.trimmingCharacters(in: .whitespacesAndNewlines),
           error.isEmpty == false {
            return error
        }
        return nil
    default:
        return nil
    }
}

private func conferenceSharedConnectionNames(from sharedConnections: Object?) -> [String] {
    guard case let .list(values)? = sharedConnections?["connections"] else {
        return []
    }

    return values.compactMap { value in
        guard case let .object(object) = value else { return nil }
        let raw = conferenceMutationString(from: object["title"])
            ?? conferenceMutationString(from: object["displayName"])
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

private func conferenceObject(from value: ValueType?) -> Object? {
    guard case let .object(object)? = value else {
        return nil
    }
    return object
}

private func conferenceActionKeypath(from value: ValueType?) -> String? {
    guard case let .object(object)? = value,
          case let .string(keypath)? = object["keypath"] else {
        return nil
    }
    return keypath
}

private func conferenceActionPayload(from value: ValueType?) -> ValueType? {
    guard case let .object(object)? = value else {
        return nil
    }
    return object["payload"]
}


actor ConferenceParticipantSelectionStore {
    static let shared = ConferenceParticipantSelectionStore()
    private static let maximumRetainedOwners = 12
    private static let memoryPressureRetainedOwners = 4

    private var selectedParticipantByOwnerUUID: [String: String] = [:]
    private var ownerRecency: [String] = []

    func load(for ownerUUID: String) -> String? {
        guard let selection = selectedParticipantByOwnerUUID[ownerUUID] else {
            return nil
        }
        touch(ownerUUID)
        return selection
    }

    func save(_ displayName: String?, for ownerUUID: String) {
        guard let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            selectedParticipantByOwnerUUID.removeValue(forKey: ownerUUID)
            ownerRecency.removeAll { $0 == ownerUUID }
            return
        }
        selectedParticipantByOwnerUUID[ownerUUID] = trimmed
        touch(ownerUUID)
        trimIfNeeded(limit: Self.maximumRetainedOwners)
    }

    func handleMemoryPressure() {
        trimIfNeeded(limit: Self.memoryPressureRetainedOwners)
    }

    private func touch(_ ownerUUID: String) {
        ownerRecency.removeAll { $0 == ownerUUID }
        ownerRecency.append(ownerUUID)
    }

    private func trimIfNeeded(limit: Int) {
        guard ownerRecency.count > limit else { return }
        let staleOwners = ownerRecency.prefix(ownerRecency.count - limit)
        for ownerUUID in staleOwners {
            selectedParticipantByOwnerUUID.removeValue(forKey: ownerUUID)
        }
        ownerRecency = Array(ownerRecency.suffix(limit))
    }
}

struct ConferenceNearbyFollowUpTarget: Equatable {
    var remoteUUID: String
    var participantId: String
    var identityUUID: String?
    var displayName: String
    var company: String?
    var role: String?

    func discoveryTargetObject(includeIdentityUUID: Bool = false) -> Object {
        var object: Object = [
            "participantId": .string(participantId),
            "displayName": .string(displayName),
            "company": .string(company ?? ""),
            "role": .string(role ?? "")
        ]
        if includeIdentityUUID, let identityUUID {
            object["identityUUID"] = .string(identityUUID)
        }
        return object
    }
}

enum ConferenceNearbyFollowUpSupport {
    static func target(
        from encounter: Object,
        fallbackRemoteUUID: String,
        fallbackDisplayName: String
    ) -> ConferenceNearbyFollowUpTarget {
        let remotePerspective = object(from: encounter["remotePerspective"])
        let identityUUID = normalizedString(from: encounter["remoteIdentityUUID"])
        let participantId = prioritizedString(
            in: remotePerspective,
            keypaths: [
                ["participantId"],
                ["profile", "participantId"],
                ["participant", "participantId"],
                ["identityProfile", "state", "participantId"],
                ["publicProfile", "profile", "participantId"],
                ["publicProfile", "state", "profile", "participantId"],
                ["editorState", "participantId"]
            ]
        ) ?? synthesizedParticipantId(remoteUUID: fallbackRemoteUUID, identityUUID: identityUUID)
        let displayName = normalizedString(from: encounter["remoteDisplayName"])
            ?? prioritizedString(
                in: remotePerspective,
                keypaths: [
                    ["displayName"],
                    ["name"],
                    ["profile", "displayName"],
                    ["profile", "name"],
                    ["participant", "name"],
                    ["identityProfile", "state", "name"],
                    ["publicProfile", "profile", "displayName"],
                    ["publicProfile", "profile", "name"],
                    ["publicProfile", "state", "profile", "displayName"],
                    ["publicProfile", "state", "profile", "name"]
                ]
            )
            ?? fallbackDisplayName
        let company = prioritizedString(
            in: remotePerspective,
            keypaths: [
                ["company"],
                ["profile", "company"],
                ["participant", "company"],
                ["identityProfile", "state", "company"],
                ["publicProfile", "profile", "company"],
                ["publicProfile", "state", "profile", "company"]
            ]
        )
        let role = prioritizedString(
            in: remotePerspective,
            keypaths: [
                ["role"],
                ["profile", "role"],
                ["participant", "role"],
                ["identityProfile", "state", "role"],
                ["publicProfile", "profile", "role"],
                ["publicProfile", "state", "profile", "role"]
            ]
        )

        return ConferenceNearbyFollowUpTarget(
            remoteUUID: fallbackRemoteUUID,
            participantId: participantId,
            identityUUID: identityUUID,
            displayName: displayName,
            company: company,
            role: role
        )
    }

    static func discoveryPayload(for target: ConferenceNearbyFollowUpTarget, source: String) -> Object {
        var payload: Object = [
            "source": .string(source),
            "participantIds": .list([.string(target.participantId)]),
            "displayName": .string(target.displayName),
            "company": .string(target.company ?? ""),
            "role": .string(target.role ?? ""),
            "targets": .list([.object(target.discoveryTargetObject(includeIdentityUUID: true))])
        ]
        if let identityUUID = target.identityUUID {
            payload["identityUUIDs"] = .list([.string(identityUUID)])
        }
        return payload
    }

    static func synthesizedParticipantId(remoteUUID: String, identityUUID: String?) -> String {
        let seed = identityUUID ?? remoteUUID
        let sanitized = seed
            .lowercased()
            .map { character -> Character in
                if character.isLetter || character.isNumber {
                    return character
                }
                return "-"
            }
            .reduce(into: "") { partial, character in
                if character == "-", partial.last == "-" {
                    return
                }
                partial.append(character)
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        if sanitized.isEmpty {
            return "nearby-participant"
        }
        return "nearby-\(sanitized)"
    }

    private static func prioritizedString(in object: Object?, keypaths: [[String]]) -> String? {
        for keypath in keypaths {
            if let string = string(at: keypath, in: object) {
                return string
            }
        }
        return nil
    }

    private static func string(at keypath: [String], in object: Object?) -> String? {
        guard let object else { return nil }
        var current: ValueType = .object(object)
        for key in keypath {
            guard case let .object(dictionary) = current,
                  let nextValue = dictionary[key] else {
                return nil
            }
            current = nextValue
        }
        return normalizedString(from: current)
    }

    private static func normalizedString(from value: ValueType?) -> String? {
        guard case let .string(raw)? = value else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func object(from value: ValueType?) -> Object? {
        guard case let .object(object)? = value else { return nil }
        return object
    }
}

@MainActor
private final class ConferenceNearbyRadarLocalCell: GeneralCell {
    private enum CompassSector: String, CaseIterable {
        case left
        case ahead
        case right
        case behind
        case uncertain

        var title: String {
            switch self {
            case .left: return "Venstre"
            case .ahead: return "Foran"
            case .right: return "Høyre"
            case .behind: return "Bak"
            case .uncertain: return "Retning usikker"
            }
        }
    }

    private struct ContactSignal {
        var status: String
        var summary: String
        var actionLabel: String
    }

    private struct PurposeSignal {
        var count: Int
        var score: Double?
        var summary: String
        var detail: String
    }

    private struct RelevanceSignal {
        var badge: String
        var summary: String
        var detail: String
        var tier: String
        var scoreText: String
        var visibleByDefault: Bool
    }

    private let bootstrapRequester: Identity
    private var scannerEmit: Emit?
    private var scannerMeddle: Meddle?
    private var activeRequester: Identity?
    private var flowCancellable: AnyCancellable?
    private var connectionTask: Task<Void, Never>?

    private var entitiesById: [String: NearbyEntity] = [:]
    private var scannerStatus = "idle"
    private var scannerLifecycleStatus = "idle"
    private var requestedScannerStatus: String?
    private var transportMode = "multipeerconnectivity"
    private var precisionMode = "unknown"
    private var capabilityDescription = "Start the scanner to evaluate nearby transport and precision."
    private var supportsNearbyPrecision = false
    private var contactSignalsById: [String: ContactSignal] = [:]
    private var purposeSignalsById: [String: PurposeSignal] = [:]
    private var followUpTargetsById: [String: ConferenceNearbyFollowUpTarget] = [:]
    private var selectedRemoteUUID: String?
    private var followUpMarkedRemoteUUIDs: Set<String> = []
    private var launchedChatRemoteUUIDs: Set<String> = []
    private var testInjectedRemoteUUIDs: Set<String> = []
    private var showLowerMatches = false
    private var lastError: String?
    private var lastActionSummary = "Nearby-radaren er klar. Be om kontakt for å verifisere formål og interesser."

    private var scannerAccessRequester: Identity {
        bootstrapRequester
    }

    required init(owner: Identity) async {
        self.bootstrapRequester = owner
        await super.init(owner: owner)
        await configure(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        fatalError("ConferenceNearbyRadarLocalCell does not support decoding")
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    deinit {
        flowCancellable?.cancel()
    }

    private func configure(owner: Identity) async {
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("rw--", for: "start")
        agreementTemplate.addGrant("rw--", for: "stop")
        agreementTemplate.addGrant("rw--", for: "invite")
        agreementTemplate.addGrant("rw--", for: "requestContact")
        agreementTemplate.addGrant("rw--", for: "acceptContact")
        agreementTemplate.addGrant("rw--", for: "openFollowUpChat")
        agreementTemplate.addGrant("rw--", for: "openExpandedRadarWorkbench")
        agreementTemplate.addGrant("rw--", for: "openSelectedParticipantWorkbench")
        agreementTemplate.addGrant("rw--", for: "openParticipantPortalWorkbench")
        agreementTemplate.addGrant("rw--", for: "selectEntity")
        agreementTemplate.addGrant("rw--", for: "toggleLowerMatches")
        agreementTemplate.addGrant("rw--", for: "toggleFollowUp")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")
#if DEBUG
        agreementTemplate.addGrant("rw--", for: "testInjectNearbyCandidate")
        agreementTemplate.addGrant("rw--", for: "testInjectVerifiedContact")
#endif

        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("r---", at: "state", for: requester) else { return .string("denied") }
            await self.connectScannerIfNeeded(requester: requester)
            return .object(self.snapshotObject())
        })

        await addInterceptForSet(requester: owner, key: "start", setValueIntercept: { [weak self] _, _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "start", for: requester) else { return .string("denied") }
            return await self.forwardMutation(keypath: "start", value: .bool(true), requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "stop", setValueIntercept: { [weak self] _, _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "stop", for: requester) else { return .string("denied") }
            return await self.forwardMutation(keypath: "stop", value: .bool(true), requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "invite", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "invite", for: requester) else { return .string("denied") }
            return await self.forwardMutation(keypath: "invite", value: value, requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "requestContact", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "requestContact", for: requester) else { return .string("denied") }
            return await self.forwardMutation(keypath: "requestContact", value: value, requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "acceptContact", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "acceptContact", for: requester) else { return .string("denied") }
            return await self.forwardMutation(keypath: "acceptContact", value: value, requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "openFollowUpChat", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "openFollowUpChat", for: requester) else { return .string("denied") }
            return await self.openFollowUpChat(value: value, requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "openExpandedRadarWorkbench", setValueIntercept: { [weak self] _, _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "openExpandedRadarWorkbench", for: requester) else { return .string("denied") }
            return await self.openExpandedRadarWorkbench(requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "openSelectedParticipantWorkbench", setValueIntercept: { [weak self] _, _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "openSelectedParticipantWorkbench", for: requester) else { return .string("denied") }
            return await self.openSelectedParticipantWorkbench(requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "openParticipantPortalWorkbench", setValueIntercept: { [weak self] _, _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "openParticipantPortalWorkbench", for: requester) else { return .string("denied") }
            return await self.openParticipantPortalWorkbench(requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "selectEntity", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "selectEntity", for: requester) else { return .string("denied") }
            return await self.selectEntity(value: value, requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "toggleLowerMatches", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "toggleLowerMatches", for: requester) else { return .string("denied") }
            return await self.toggleLowerMatches(value: value, requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "toggleFollowUp", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "toggleFollowUp", for: requester) else { return .string("denied") }
            return await self.toggleFollowUp(value: value, requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "dispatchAction", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "dispatchAction", for: requester) else { return .string("denied") }
            return await self.forwardDispatchAction(value: value, requester: requester)
        })

#if DEBUG
        await addInterceptForSet(requester: owner, key: "testInjectNearbyCandidate", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "testInjectNearbyCandidate", for: requester) else { return .string("denied") }
            return await self.injectNearbyCandidate(value: value, requester: requester, verifiedByDefault: false)
        })

        await addInterceptForSet(requester: owner, key: "testInjectVerifiedContact", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "testInjectVerifiedContact", for: requester) else { return .string("denied") }
            return await self.injectNearbyCandidate(value: value, requester: requester, verifiedByDefault: true)
        })
#endif

        Task { [weak self] in
            guard let self else { return }
            await self.connectScannerIfNeeded(requester: owner)
            self.emitSnapshot(requester: owner)
        }
    }

    private func connectScannerIfNeeded(requester: Identity) async {
        let scannerRequester = scannerAccessRequester
        if scannerEmit != nil, scannerMeddle != nil {
            activeRequester = requester
            return
        }
        if let connectionTask {
            await connectionTask.value
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            guard await BindingLocalCellRegistration.shared.ensureConferenceDemoRuntimeReady() else {
                self.lastError = "Local runtime registration failed"
                self.emitSnapshot(requester: requester)
                return
            }
            guard let resolver = CellBase.defaultCellResolver else {
                self.lastError = "Cell resolver missing"
                self.emitSnapshot(requester: requester)
                return
            }

            do {
                let emit = try await resolver.cellAtEndpoint(endpoint: "cell:///EntityScanner", requester: scannerRequester)
                guard let meddle = emit as? Meddle else {
                    self.lastError = "EntityScanner does not support meddle"
                    self.emitSnapshot(requester: requester)
                    return
                }

                self.activeRequester = requester
                self.scannerEmit = emit
                self.scannerMeddle = meddle
                self.lastError = nil
                try await self.subscribeToScannerFlow(emitter: emit, requester: scannerRequester)
                await self.refreshCapabilitySnapshot(requester: scannerRequester)
                await self.refreshEncounterSnapshot(requester: scannerRequester)
                self.emitSnapshot(requester: requester)
            } catch {
                self.lastError = "Failed to connect nearby scanner: \(error)"
                self.emitSnapshot(requester: requester)
            }
        }

        connectionTask = task
        await task.value
        connectionTask = nil
    }

    private func subscribeToScannerFlow(emitter: Emit, requester: Identity) async throws {
        flowCancellable?.cancel()
        let publisher = try await emitter.flow(requester: requester)
        flowCancellable = publisher.sink(
            receiveCompletion: { [weak self] completion in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if case let .failure(error) = completion {
                        self.lastError = "Nearby scanner flow ended: \(error)"
                        let snapshotRequester = self.activeRequester ?? self.bootstrapRequester
                        self.emitSnapshot(requester: snapshotRequester)
                    }
                }
            },
            receiveValue: { [weak self] flowElement in
                guard let self else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    await self.consume(flowElement: flowElement)
                }
            }
        )
    }

    private func forwardMutation(keypath: String, value: ValueType, requester: Identity) async -> ValueType {
        if keypath == "requestContact",
           let remoteUUID = normalizedRemoteUUID(string(from: value)),
           testInjectedRemoteUUIDs.contains(remoteUUID) {
            selectedRemoteUUID = remoteUUID
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "sent",
                summary: "Signert kontaktforespørsel sendt. Venter på godkjenning.",
                actionLabel: "Kontakt venter"
            )
            lastError = nil
            lastActionSummary = "Signert kontaktforespørsel sendt. Venter på godkjenning."
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }

        let localLifecycleSummary: String?
        switch keypath {
        case "start":
            scannerStatus = "started"
            scannerLifecycleStatus = "started"
            requestedScannerStatus = "started"
            localLifecycleSummary = "Scanner-start ble bedt om lokalt. Live nearby-tjeneste er ikke klar ennå."
            lastActionSummary = "Starter scanner og lytter etter nearby-signaler."
        case "stop":
            scannerStatus = "stopped"
            scannerLifecycleStatus = "stopped"
            requestedScannerStatus = "stopped"
            localLifecycleSummary = "Scanner-stopp ble bedt om lokalt. Live nearby-tjeneste er ikke klar ennå."
            lastActionSummary = "Stopper scanner og rydder live nearby-signaler."
        default:
            localLifecycleSummary = nil
        }

        await connectScannerIfNeeded(requester: requester)
        guard let scannerMeddle else {
            lastError = "EntityScanner unavailable"
            if let localLifecycleSummary {
                lastActionSummary = localLifecycleSummary
            }
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }
        let scannerRequester = scannerAccessRequester

        do {
            let result = try await scannerMeddle.set(keypath: keypath, value: value, requester: scannerRequester)
            lastError = nil
            applyMutationResult(keypath: keypath, result: result, payload: value)
            await refreshCapabilitySnapshot(requester: scannerRequester)
            if keypath == "requestContact" {
                await refreshEncounterSnapshot(requester: scannerRequester)
            } else if keypath == "start" {
                scannerStatus = "started"
                scannerLifecycleStatus = "started"
                requestedScannerStatus = "started"
                lastActionSummary = "Scanner kjører. Venter på nearby-deltagere."
            } else if keypath == "stop" {
                scannerStatus = "stopped"
                scannerLifecycleStatus = "stopped"
                requestedScannerStatus = "stopped"
                lastActionSummary = "Scanner er stoppet."
            }
        } catch {
            lastError = "Nearby scanner action \(keypath) failed: \(error)"
            switch keypath {
            case "start":
                scannerStatus = "started"
                scannerLifecycleStatus = "started"
                requestedScannerStatus = "started"
                lastActionSummary = "Scanner-start ble bedt om lokalt. Live nearby-tjeneste er ikke klar ennå: \(error)"
            case "stop":
                scannerStatus = "stopped"
                scannerLifecycleStatus = "stopped"
                requestedScannerStatus = "stopped"
                lastActionSummary = "Scanner-stopp ble bedt om lokalt. Live nearby-tjeneste er ikke klar ennå: \(error)"
            default:
                requestedScannerStatus = nil
                lastActionSummary = "Nearby-handlingen feilet: \(error)"
            }
        }

        emitSnapshot(requester: requester)
        return .object(snapshotObject())
    }

    private func forwardDispatchAction(value: ValueType, requester: Identity) async -> ValueType {
        guard case let .object(actionObject) = value,
              let actionKeypath = string(from: actionObject["keypath"]),
              actionKeypath.isEmpty == false else {
            lastError = "Nearby-handlingen mangler keypath."
            lastActionSummary = "Nearby-handlingen mangler keypath."
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }

        let actionPayload = actionObject["payload"] ?? .bool(true)
        switch actionKeypath {
        case "start", "stop", "invite", "requestContact", "acceptContact":
            return await forwardMutation(keypath: actionKeypath, value: actionPayload, requester: requester)
        case "openFollowUpChat":
            return await openFollowUpChat(value: actionPayload, requester: requester)
        case "selectEntity":
            return await selectEntity(value: actionPayload, requester: requester)
        case "toggleLowerMatches":
            return await toggleLowerMatches(value: actionPayload, requester: requester)
        case "toggleFollowUp":
            return await toggleFollowUp(value: actionPayload, requester: requester)
        case "openExpandedRadarWorkbench":
            return await openExpandedRadarWorkbench(requester: requester)
        case "openSelectedParticipantWorkbench":
            return await openSelectedParticipantWorkbench(requester: requester)
        case "openParticipantPortalWorkbench":
            return await openParticipantPortalWorkbench(requester: requester)
        case "noop":
            lastError = nil
            lastActionSummary = "This action is informational until signed identity exchange is complete."
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        default:
            lastError = "Nearby-handlingen \(actionKeypath) er ikke støttet."
            lastActionSummary = "Nearby-handlingen \(actionKeypath) er ikke støttet."
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }
    }

    private func toggleLowerMatches(value: ValueType, requester: Identity) async -> ValueType {
        if let explicitValue = bool(from: value) {
            showLowerMatches = explicitValue
        } else if let explicitValue = bool(from: object(from: value)?["show"]) {
            showLowerMatches = explicitValue
        } else {
            showLowerMatches.toggle()
        }

        lastError = nil
        lastActionSummary = showLowerMatches
            ? "Viser lavere og nearby-only treff. Bruk dem som svak kontekst, ikke som anbefalte treff."
            : "Skjuler lavere og nearby-only treff fra primærlisten."
        emitSnapshot(requester: requester)
        return .object(snapshotObject())
    }

    private func refreshCapabilitySnapshot(requester: Identity) async {
        guard let scannerMeddle else {
            return
        }
        do {
            let capabilityValue = try await scannerMeddle.get(keypath: "capabilities", requester: requester)
            if case let .object(capabilityObject) = capabilityValue {
                applyCapabilities(from: capabilityObject)
            }
        } catch {
            lastError = "Could not refresh scanner capabilities: \(error)"
        }
    }

    private func refreshEncounterSnapshot(requester: Identity) async {
        guard let scannerMeddle else {
            return
        }
        do {
            let encountersValue = try await scannerMeddle.get(keypath: "encounters", requester: requester)
            applyEncounterSummaries(from: encountersValue)
        } catch {
            lastError = "Could not refresh nearby encounter summaries: \(error)"
        }
    }

    private func openFollowUpChat(value: ValueType, requester: Identity) async -> ValueType {
        guard let remoteUUID = normalizedRemoteUUID(string(from: object(from: value)?["remoteUUID"]) ?? string(from: value)),
              let target = followUpTargetsById[remoteUUID] else {
            lastError = "Nearby-oppfølging er ikke klar ennå. Fullfør signert kontakt først."
            lastActionSummary = "Nearby-oppfølging er ikke klar ennå. Fullfør signert kontakt først."
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }
        guard let resolver = CellBase.defaultCellResolver else {
            lastError = "Cell resolver missing"
            lastActionSummary = "Could not open discovery chat because the local resolver is missing."
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }
        selectedRemoteUUID = remoteUUID

        let dispatchPayload: Object = [
            "keypath": .string("discovery.startChat"),
            "payload": .object(
                ConferenceNearbyFollowUpSupport.discoveryPayload(
                    for: target,
                    source: "nearby-verified-contact"
                )
            )
        ]

        if await dispatchLocalParticipantFallback(
            payload: dispatchPayload,
            requester: requester,
            resolver: resolver,
            targetName: target.displayName
        ) {
            lastError = nil
            launchedChatRemoteUUIDs.insert(remoteUUID)
            lastActionSummary = "Startet conference-chat med \(target.displayName)."
            if var contactSignal = contactSignalsById[remoteUUID] {
                contactSignal.summary = "Verifisert kontakt lagret. Chatten er klar for oppfølging."
                contactSignal.actionLabel = "Åpne chat"
                contactSignalsById[remoteUUID] = contactSignal
            }
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }

        do {
            guard let porthole = try await resolver.cellAtEndpoint(endpoint: "cell:///Porthole", requester: requester) as? Meddle else {
                lastError = "Porthole unavailable"
                lastActionSummary = "Could not open discovery chat because Porthole is unavailable."
                emitSnapshot(requester: requester)
                return .object(snapshotObject())
            }

            let preDispatchState = await participantFollowUpState(via: porthole, requester: requester)
            let result = try await porthole.set(
                keypath: "conferenceParticipantShell.dispatchAction",
                value: .object(dispatchPayload),
                requester: requester
            )
            let postDispatchState = await participantFollowUpState(via: porthole, requester: requester)

            let localFallbackSucceededOnError: Bool
            if mutationErrorDescription(from: result) != nil {
                localFallbackSucceededOnError = await dispatchLocalParticipantFallback(
                    payload: dispatchPayload,
                    requester: requester,
                    resolver: resolver,
                    targetName: target.displayName
                )
            } else {
                localFallbackSucceededOnError = false
            }

            let localFallbackSucceededAfterNoop = await dispatchLocalParticipantFallback(
                payload: dispatchPayload,
                requester: requester,
                resolver: resolver,
                expectedBeforeState: postDispatchState,
                targetName: target.displayName
            )

            if let errorDescription = mutationErrorDescription(from: result),
               localFallbackSucceededOnError == false {
                lastError = errorDescription
                lastActionSummary = errorDescription
            } else if participantFollowUpStateDidAdvance(
                from: preDispatchState,
                to: postDispatchState,
                targetName: target.displayName
            ) || localFallbackSucceededAfterNoop {
                lastError = nil
                launchedChatRemoteUUIDs.insert(remoteUUID)
                lastActionSummary = "Startet conference-chat med \(target.displayName)."
                if var contactSignal = contactSignalsById[remoteUUID] {
                    contactSignal.summary = "Verifisert kontakt lagret. Chatten er klar for oppfølging."
                    contactSignal.actionLabel = "Åpne chat"
                    contactSignalsById[remoteUUID] = contactSignal
                }
            } else {
                lastError = "Nearby follow-up did not update participant preview state."
                lastActionSummary = "Nearby follow-up did not update participant preview state."
            }
        } catch {
            if await dispatchLocalParticipantFallback(
                payload: [
                    "keypath": .string("discovery.startChat"),
                    "payload": .object(
                        ConferenceNearbyFollowUpSupport.discoveryPayload(
                            for: target,
                            source: "nearby-verified-contact"
                        )
                    )
                ],
                requester: requester,
                resolver: resolver,
                targetName: target.displayName
            ) {
                lastError = nil
                launchedChatRemoteUUIDs.insert(remoteUUID)
                lastActionSummary = "Startet conference-chat med \(target.displayName)."
                if var contactSignal = contactSignalsById[remoteUUID] {
                    contactSignal.summary = "Verifisert kontakt lagret. Chatten er klar for oppfølging."
                    contactSignal.actionLabel = "Åpne chat"
                    contactSignalsById[remoteUUID] = contactSignal
                }
            } else {
                lastError = "Nearby-chatten kunne ikke startes: \(error)"
                lastActionSummary = "Nearby-chatten kunne ikke startes: \(error)"
            }
        }

        emitSnapshot(requester: requester)
        return .object(snapshotObject())
    }

    private func selectEntity(value: ValueType, requester: Identity) async -> ValueType {
        let requestedRemoteUUID = normalizedRemoteUUID(string(from: object(from: value)?["remoteUUID"]) ?? string(from: value))
            ?? selectedRemoteUUID

        guard let requestedRemoteUUID,
              let entity = entitiesById[requestedRemoteUUID] else {
            lastError = "Could not focus nearby participant because the selection was missing."
            lastActionSummary = "Could not focus nearby participant because the selection was missing."
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }

        selectedRemoteUUID = requestedRemoteUUID
        lastError = nil
        lastActionSummary = "Focused nearby view on \(entity.displayName)."
        emitSnapshot(requester: requester)
        return .object(snapshotObject())
    }

    private func toggleFollowUp(value: ValueType, requester: Identity) async -> ValueType {
        let requestedRemoteUUID = normalizedRemoteUUID(string(from: object(from: value)?["remoteUUID"]) ?? string(from: value))
            ?? selectedRemoteUUID

        guard let requestedRemoteUUID,
              let entity = entitiesById[requestedRemoteUUID] else {
            lastError = "Could not update follow-up mark because no nearby participant was selected."
            lastActionSummary = "Could not update follow-up mark because no nearby participant was selected."
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }

        selectedRemoteUUID = requestedRemoteUUID
        if followUpMarkedRemoteUUIDs.contains(requestedRemoteUUID) {
            followUpMarkedRemoteUUIDs.remove(requestedRemoteUUID)
            lastActionSummary = "Removed \(entity.displayName) from follow-up."
        } else {
            followUpMarkedRemoteUUIDs.insert(requestedRemoteUUID)
            lastActionSummary = "Marked \(entity.displayName) for follow-up."
        }
        lastError = nil
        emitSnapshot(requester: requester)
        return .object(snapshotObject())
    }

    private func openExpandedRadarWorkbench(requester: Identity) async -> ValueType {
        let configuration = ConfigurationCatalogCell.conferenceNearbyRadarWorkbenchConfiguration(
            participantEndpoint: "cell:///ConferenceParticipantPreviewShell"
        )
        return await loadWorkbenchConfiguration(
            configuration,
            requester: requester,
            successSummary: "Åpnet radarflaten i egen arbeidsflate."
        )
    }

    private func openSelectedParticipantWorkbench(requester: Identity) async -> ValueType {
        guard let selectedRemoteUUID,
              let entity = entitiesById[selectedRemoteUUID] else {
            lastError = "Velg en nearby deltager før du åpner profilflaten."
            lastActionSummary = "Velg en nearby deltager før du åpner profilflaten."
            emitSnapshot(requester: requester)
            return .object(snapshotObject())
        }

        let configuration = ConfigurationCatalogCell.conferenceNearbyParticipantWorkbenchConfiguration(
            participantEndpoint: "cell:///ConferenceParticipantPreviewShell",
            displayName: "\(entity.displayName) · Profilflate",
            summary: "Valgt nearby-deltager med oppfølging, chat og spatial kontekst i én arbeidsflate."
        )
        return await loadWorkbenchConfiguration(
            configuration,
            requester: requester,
            successSummary: "Åpnet profilflaten for \(entity.displayName)."
        )
    }

    private func openParticipantPortalWorkbench(requester: Identity) async -> ValueType {
        lastError = nil
        lastActionSummary = "Går tilbake til deltagerportalen…"
        emitSnapshot(requester: requester)
        await MainActor.run {
            BindingConferenceNavigationBridge.postPop(
                fallbackConfiguration: ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
                    endpoint: "cell:///ConferenceParticipantPreviewShell"
                )
            )
        }
        lastActionSummary = "Tilbake i deltagerportalen."
        emitSnapshot(requester: requester)
        return .object(snapshotObject())
    }

    private func loadWorkbenchConfiguration(
        _ configuration: CellConfiguration,
        requester: Identity,
        successSummary: String
    ) async -> ValueType {
        lastError = nil
        lastActionSummary = "Åpner arbeidsflaten…"
        emitSnapshot(requester: requester)
        scheduleWorkbenchLoad(configuration, requester: requester, successSummary: successSummary)
        return .object(snapshotObject())
    }

    private func scheduleWorkbenchLoad(
        _ configuration: CellConfiguration,
        requester: Identity,
        successSummary: String
    ) {
        Task { @MainActor [weak self] in
            BindingPortholeLoadBridge.post(configuration: configuration)
            self?.lastError = nil
            self?.lastActionSummary = successSummary
            self?.emitSnapshot(requester: requester)
        }
    }

    private func participantFollowUpState(via porthole: Meddle, requester: Identity) async -> (nextStep: String?, chatSummary: String?, firstRecentMessage: String?) {
        let stateValue = try? await porthole.get(
            keypath: "conferenceParticipantShell.state",
            requester: requester
        )
        return participantFollowUpState(from: stateValue)
    }

    private func participantFollowUpStateDidAdvance(
        from before: (nextStep: String?, chatSummary: String?, firstRecentMessage: String?),
        to after: (nextStep: String?, chatSummary: String?, firstRecentMessage: String?),
        targetName: String
    ) -> Bool {
        let normalizedTarget = targetName.lowercased()
        if after.nextStep?.lowercased().contains(normalizedTarget) == true {
            return true
        }
        if after.firstRecentMessage?.lowercased().contains(normalizedTarget) == true {
            return true
        }
        return before != after
    }

    private func dispatchLocalParticipantFallback(
        payload: Object,
        requester: Identity,
        resolver: any CellResolverProtocol,
        expectedBeforeState: (nextStep: String?, chatSummary: String?, firstRecentMessage: String?)? = nil,
        targetName: String? = nil
    ) async -> Bool {
        guard let localPreview = try? await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: requester
        ) as? Meddle else {
            return false
        }

        let beforeState: (nextStep: String?, chatSummary: String?, firstRecentMessage: String?)
        if let expectedBeforeState {
            beforeState = expectedBeforeState
        } else {
            beforeState = await participantPreviewFallbackState(from: localPreview, requester: requester)
        }

        let result = try? await localPreview.set(
            keypath: "dispatchAction",
            value: .object(payload),
            requester: requester
        )
        if let errorDescription = mutationErrorDescription(from: result) {
            lastError = errorDescription
            return false
        }

        let afterState: (nextStep: String?, chatSummary: String?, firstRecentMessage: String?)
        if let mutationState = participantFollowUpState(fromMutationResult: result) {
            afterState = mutationState
        } else {
            afterState = await participantPreviewFallbackState(from: localPreview, requester: requester)
        }
        return participantFollowUpStateDidAdvance(
            from: beforeState,
            to: afterState,
            targetName: targetName ?? ""
        )
    }

    private func participantPreviewFallbackState(
        from participantPreview: Meddle,
        requester: Identity
    ) async -> (nextStep: String?, chatSummary: String?, firstRecentMessage: String?) {
        let stateValue = try? await participantPreview.get(keypath: "state", requester: requester)
        return participantFollowUpState(from: stateValue)
    }

    private func participantFollowUpState(from stateValue: ValueType?) -> (nextStep: String?, chatSummary: String?, firstRecentMessage: String?) {
        guard case let .object(stateObject)? = stateValue else {
            return (nil, nil, nil)
        }
        let workspace = object(from: stateObject["workspace"])
        let sharedConnections = object(from: stateObject["sharedConnections"])
        let firstRecentMessage: String?
        if case let .list(messages)? = sharedConnections?["recentMessages"],
           case let .object(firstMessage)? = messages.first {
            firstRecentMessage = string(from: firstMessage["detail"])
        } else {
            firstRecentMessage = nil
        }

        return (
            nextStep: string(from: workspace?["nextStep"]),
            chatSummary: string(from: sharedConnections?["chatSummary"]),
            firstRecentMessage: firstRecentMessage
        )
    }

    private func participantFollowUpState(fromMutationResult value: ValueType?) -> (nextStep: String?, chatSummary: String?, firstRecentMessage: String?)? {
        guard case let .object(resultObject)? = value,
              case let .object(stateObject)? = resultObject["state"] else {
            return nil
        }
        return participantFollowUpState(from: .object(stateObject))
    }

#if DEBUG
    private func injectNearbyCandidate(
        value: ValueType,
        requester: Identity,
        verifiedByDefault: Bool
    ) async -> ValueType {
        let input = object(from: value)
        let verified = bool(from: input?["verified"]) ?? verifiedByDefault
        let remoteUUID = normalizedRemoteUUID(string(from: input?["remoteUUID"])) ?? "nearby-test-contact"
        let displayName = string(from: input?["displayName"]) ?? "Nora Berg"
        let identityUUID = normalizedRemoteUUID(string(from: input?["identityUUID"]))
        let participantId = string(from: input?["participantId"])
            ?? ConferenceNearbyFollowUpSupport.synthesizedParticipantId(
                remoteUUID: remoteUUID,
                identityUUID: identityUUID
            )
        let company = string(from: input?["company"]) ?? "Polar Systems"
        let role = string(from: input?["role"]) ?? "speaker"
        let matchCount = int(from: input?["matchCount"]) ?? 2
        let matchScore = double(from: input?["matchScore"]) ?? 0.92
        let distanceMeters = double(from: input?["distanceMeters"]) ?? 1.6
        let hasDirection = bool(from: input?["hasDirection"]) ?? true
        let direction = hasDirection ? RadarDirection3D(
            x: double(from: input?["directionX"]) ?? 0.0,
            y: double(from: input?["directionY"]) ?? 0.0,
            z: double(from: input?["directionZ"]) ?? 1.0
        ) : nil

        let update = RadarEntityUpdate(
            remoteUUID: remoteUUID,
            displayName: displayName,
            status: "nearby",
            connected: true,
            distanceMeters: distanceMeters,
            direction: direction,
            matchScore: matchScore
        )
        entitiesById[remoteUUID] = NearbyEntity(update: update, defaultStatus: "nearby")
        selectedRemoteUUID = remoteUUID
        testInjectedRemoteUUIDs.insert(remoteUUID)
        if verified {
            purposeSignalsById[remoteUUID] = PurposeSignal(
                count: matchCount,
                score: matchScore,
                summary: "\(matchCount) verified overlap(s) via governance",
                detail: "Top verified match score \(String(format: "%.2f", matchScore))"
            )
            followUpTargetsById[remoteUUID] = ConferenceNearbyFollowUpTarget(
                remoteUUID: remoteUUID,
                participantId: participantId,
                identityUUID: identityUUID,
                displayName: displayName,
                company: company,
                role: role
            )
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "verified",
                summary: "Identity saved with \(matchCount) verified purpose/interest overlap(s). Relation persisted and proof saved.",
                actionLabel: "Identity saved"
            )
            lastActionSummary = "Injected verified nearby contact for \(displayName)."
        } else {
            purposeSignalsById.removeValue(forKey: remoteUUID)
            followUpTargetsById.removeValue(forKey: remoteUUID)
            contactSignalsById.removeValue(forKey: remoteUUID)
            launchedChatRemoteUUIDs.remove(remoteUUID)
            lastActionSummary = "Injected nearby candidate for \(displayName)."
        }
        scannerStatus = "started"
        scannerLifecycleStatus = "started"
        requestedScannerStatus = "started"
        lastError = nil
        emitSnapshot(requester: requester)
        return .object(snapshotObject())
    }
#endif

    private func consume(flowElement: FlowElement) async {
        if case let .object(object) = flowElement.content {
            applyCapabilities(from: object)
            applyContactEvent(topic: flowElement.topic, object: object)
        }

        guard let scannerEvent = RadarEventParser.parse(flowElement) else {
            let snapshotRequester = activeRequester ?? bootstrapRequester
            if flowElement.topic == "scanner.encounter.saved" || flowElement.topic == "scanner.contact.established" {
                await refreshEncounterSnapshot(requester: scannerAccessRequester)
            }
            emitSnapshot(requester: snapshotRequester)
            return
        }

        switch scannerEvent {
        case let .found(update):
            upsert(update, fallbackStatus: "found")
        case var .connected(update):
            if update.remoteUUID != nil, update.connected == nil {
                update.connected = true
            }
            upsert(update, fallbackStatus: "connected")
        case let .lost(update):
            handleLost(update)
        case let .proximity(update):
            upsert(update, fallbackStatus: "nearby")
        case let .status(update):
            if let status = update.status, !status.isEmpty {
                scannerStatus = status
                if status == "started" || status == "stopped" {
                    scannerLifecycleStatus = status
                }
                if requestedScannerStatus == status,
                   (status == "started" || status == "stopped") {
                    requestedScannerStatus = nil
                }
            }
            upsert(update, fallbackStatus: scannerStatus)
        }

        pruneStaleEntities()
        let snapshotRequester = activeRequester ?? bootstrapRequester
        if flowElement.topic == "scanner.encounter.saved" || flowElement.topic == "scanner.contact.established" {
            await refreshEncounterSnapshot(requester: scannerAccessRequester)
        }
        emitSnapshot(requester: snapshotRequester)
    }

    private func applyCapabilities(from object: Object) {
        if let transport = string(from: object["transportMode"]), !transport.isEmpty {
            transportMode = transport
        }
        if let precision = string(from: object["precisionMode"]), !precision.isEmpty {
            precisionMode = precision
        }
        if let description = string(from: object["description"]), !description.isEmpty {
            capabilityDescription = description
        }
        if let status = string(from: object["status"]), !status.isEmpty {
            scannerStatus = status
            if status == "started" || status == "stopped" || status == "idle" || status == "scannerNotStarted" {
                scannerLifecycleStatus = lifecycleBadgeStatus(from: status)
            }
        }
        if let supportsNearby = bool(from: object["supportsNearbyPrecision"]) {
            supportsNearbyPrecision = supportsNearby
        }
    }

    private func lifecycleBadgeStatus(from rawStatus: String) -> String {
        switch rawStatus {
        case "started":
            return "started"
        case "stopped":
            return "stopped"
        case "scannerNotStarted", "idle":
            return "idle"
        default:
            return scannerLifecycleStatus
        }
    }

    private func upsert(_ update: RadarEntityUpdate, fallbackStatus: String) {
        guard let remoteUUID = normalizedRemoteUUID(update.remoteUUID) else {
            return
        }

        var normalizedUpdate = update
        normalizedUpdate.remoteUUID = remoteUUID
        if normalizedUpdate.status == nil || normalizedUpdate.status?.isEmpty == true {
            normalizedUpdate.status = fallbackStatus
        }

        if var entity = entitiesById[remoteUUID] {
            entity.merge(update: normalizedUpdate, defaultStatus: fallbackStatus)
            entitiesById[remoteUUID] = entity
        } else {
            entitiesById[remoteUUID] = NearbyEntity(update: normalizedUpdate, defaultStatus: fallbackStatus)
        }
    }

    private func handleLost(_ update: RadarEntityUpdate) {
        guard let remoteUUID = normalizedRemoteUUID(update.remoteUUID) else {
            return
        }
        if var entity = entitiesById[remoteUUID] {
            var lostUpdate = update
            lostUpdate.remoteUUID = remoteUUID
            if lostUpdate.status == nil {
                lostUpdate.status = "lost"
            }
            lostUpdate.connected = false
            entity.merge(update: lostUpdate, defaultStatus: "lost")
            entitiesById[remoteUUID] = entity
        }
    }

    private func pruneStaleEntities() {
        guard !entitiesById.isEmpty else {
            return
        }

        let now = Date()
        let staleCutoff = now.addingTimeInterval(-20.0)
        let lostCutoff = now.addingTimeInterval(-4.0)

        let keysToRemove = entitiesById.compactMap { key, entity -> String? in
            if entity.status == "lost", entity.lastSeenAt < lostCutoff {
                return key
            }
            if !entity.connected, entity.lastSeenAt < staleCutoff {
                return key
            }
            return nil
        }

        keysToRemove.forEach { entitiesById.removeValue(forKey: $0) }
        let remainingRemoteUUIDs = Set(entitiesById.keys)
        followUpMarkedRemoteUUIDs.formIntersection(remainingRemoteUUIDs)
        if let selectedRemoteUUID, remainingRemoteUUIDs.contains(selectedRemoteUUID) == false {
            self.selectedRemoteUUID = nil
        }
    }

    private func applyMutationResult(keypath: String, result: ValueType?, payload: ValueType) {
        guard keypath == "requestContact" || keypath == "acceptContact",
              let resultObject = object(from: result),
              let remoteUUID = normalizedRemoteUUID(string(from: resultObject["remoteUUID"]) ?? string(from: payload)) else {
            return
        }

        if keypath == "acceptContact" {
            selectedRemoteUUID = remoteUUID
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "verified",
                summary: "Signed identity exchange complete. Relation persisted and encounter proof saved locally.",
                actionLabel: "Identity saved"
            )
            lastActionSummary = "Signed identity exchange complete. Relation persisted and encounter proof saved locally."
            return
        }

        switch string(from: resultObject["status"]) ?? "" {
        case "pendingConnection":
            selectedRemoteUUID = remoteUUID
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "pendingConnection",
                summary: "Invitasjon sendt. Signert kontakt starter når enhetslenken er klar.",
                actionLabel: "Kobler til..."
            )
            lastActionSummary = "Invitasjon sendt. Signert kontakt starter når enhetslenken er klar."
        case "sent":
            selectedRemoteUUID = remoteUUID
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "sent",
                summary: "Signert kontaktforespørsel sendt. Venter på at den andre siden godkjenner.",
                actionLabel: "Kontakt venter"
            )
            lastActionSummary = "Signert kontaktforespørsel sendt. Venter på at den andre siden godkjenner."
        case "error":
            let message = string(from: resultObject["message"]) ?? "Nearby contact request failed."
            lastError = message
            lastActionSummary = message
        default:
            break
        }
    }

    private func applyContactEvent(topic: String, object: Object) {
        guard let remoteUUID = normalizedRemoteUUID(string(from: object["remoteUUID"])) else {
            if topic == "scanner.status",
               let status = string(from: object["status"]),
               status == "error",
               let message = string(from: object["message"]) {
                lastError = message
                lastActionSummary = message
            }
            return
        }

        switch topic {
        case "scanner.contact.pending":
            selectedRemoteUUID = remoteUUID
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "pendingConnection",
                summary: string(from: object["message"]) ?? "Invitasjon sendt. Venter på direkte enhetslenke.",
                actionLabel: "Kobler til..."
            )
            lastActionSummary = "Invitasjon sendt. Venter på direkte enhetslenke før signert kontakt."
        case "scanner.contact.outgoing":
            selectedRemoteUUID = remoteUUID
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "sent",
                summary: "Signed contact request sent. Awaiting signed identity exchange.",
                actionLabel: "Awaiting exchange"
            )
            lastActionSummary = "Signed contact request sent. Awaiting signed identity exchange."
        case "scanner.contact.received":
            selectedRemoteUUID = remoteUUID
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "incoming",
                summary: "Incoming signed contact request. Accepting completes identity exchange and saves the relation locally.",
                actionLabel: "Accept + exchange"
            )
            lastActionSummary = "Incoming signed contact request. Accepting completes identity exchange and saves the relation locally."
        case "scanner.contact.established", "scanner.encounter.saved":
            selectedRemoteUUID = remoteUUID
            let matchCount = purposeSignalsById[remoteUUID]?.count ?? int(from: object["matchCount"]) ?? 0
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "verified",
                summary: matchCount > 0
                    ? "Identity saved with \(matchCount) verified purpose/interest overlap(s). Relation persisted and proof saved."
                    : "Identity saved. Relation persisted and encounter proof saved locally.",
                actionLabel: "Identity saved"
            )
            lastActionSummary = contactSignalsById[remoteUUID]?.summary ?? "Identity saved."
        default:
            break
        }
    }

    private func applyEncounterSummaries(from value: ValueType) {
        guard case let .list(encounters) = value else {
            return
        }

        var refreshedPurposeSignals: [String: PurposeSignal] = [:]
        var refreshedFollowUpTargets: [String: ConferenceNearbyFollowUpTarget] = [:]
        for encounterValue in encounters {
            guard let encounter = object(from: encounterValue),
                  let remoteUUID = normalizedRemoteUUID(string(from: encounter["remoteUUID"])) else {
                continue
            }

            let purposeSignal = makePurposeSignal(from: encounter)
            refreshedPurposeSignals[remoteUUID] = purposeSignal
            refreshedFollowUpTargets[remoteUUID] = ConferenceNearbyFollowUpSupport.target(
                from: encounter,
                fallbackRemoteUUID: remoteUUID,
                fallbackDisplayName: string(from: encounter["remoteDisplayName"])
                    ?? entitiesById[remoteUUID]?.displayName
                    ?? remoteUUID
            )
            contactSignalsById[remoteUUID] = ContactSignal(
                status: "verified",
                summary: purposeSignal.count > 0
                    ? "Identity saved with \(purposeSignal.count) verified purpose/interest overlap(s). Relation persisted and proof saved."
                    : "Identity saved. Relation persisted and encounter proof saved locally.",
                actionLabel: "Identity saved"
            )
        }

        purposeSignalsById = refreshedPurposeSignals
        followUpTargetsById = refreshedFollowUpTargets
        launchedChatRemoteUUIDs.formIntersection(Set(refreshedFollowUpTargets.keys))
    }

    private func makePurposeSignal(from encounter: Object) -> PurposeSignal {
        let matchCount = int(from: encounter["matchCount"]) ?? 0
        let matchObject = object(from: encounter["match"])
        let topHit = list(from: matchObject?["allHits"])?.compactMap { object(from: $0) }.first
        let topScore = double(from: topHit?["matchScore"])
        let sourcePurpose = string(from: topHit?["sourcePurposeName"])
        let targetPurpose = string(from: topHit?["targetPurposeName"])
        let interestName = string(from: topHit?["interestName"])

        if matchCount > 0 {
            let summary: String
            if let interestName, !interestName.isEmpty {
                summary = "\(matchCount) verified overlap(s) via \(interestName)"
            } else if let sourcePurpose, let targetPurpose {
                summary = "\(matchCount) verified overlap(s): \(sourcePurpose) <-> \(targetPurpose)"
            } else {
                summary = "\(matchCount) verified purpose/interest overlap(s)"
            }

            let detail: String
            if let topScore {
                detail = "Top verified match score \(String(format: "%.2f", topScore))"
            } else {
                detail = "Verified after signed contact proof."
            }

            return PurposeSignal(
                count: matchCount,
                score: topScore,
                summary: summary,
                detail: detail
            )
        }

        let remotePerspective = object(from: encounter["remotePerspective"])
        let advertisedPurpose = remotePerspective.flatMap(advertisedPurposeSummary(from:))
        return PurposeSignal(
            count: 0,
            score: nil,
            summary: advertisedPurpose ?? "No verified purpose overlap yet",
            detail: "Purpose signal becomes verified after signed contact proof."
        )
    }

    private func fallbackPurposeSummary(for remoteUUID: String, liveScore: Double?) -> String {
        if let liveScore {
            return "Live proximity fit \(String(format: "%.2f", liveScore))"
        }
        if let purposeSignal = purposeSignalsById[remoteUUID] {
            return purposeSignal.summary
        }
        return "Proximity only · request contact to verify purpose and interest fit"
    }

    private func advertisedPurposeSummary(from remotePerspective: Object) -> String? {
        guard let advertisedPurpose = object(from: remotePerspective["advertisedPurpose"]),
              let firstPurpose = advertisedPurpose.values.compactMap(string(from:)).first,
              !firstPurpose.isEmpty else {
            return nil
        }
        return "Advertised purpose: \(firstPurpose)"
    }

    private func snapshotObject() -> Object {
        pruneStaleEntities()
        let effectiveScannerStatus = requestedScannerStatus ?? scannerLifecycleStatus

        let entities = sortedEntities()
        let primaryVisibleEntities = entities.filter(shouldShowEntityByDefault)
        let hiddenEntities = entities.filter { !shouldShowEntityByDefault($0) }
        let displayEntities = showLowerMatches ? entities : primaryVisibleEntities
        let focusedRemoteUUID = ensureSelectedRemoteUUID(in: displayEntities.isEmpty ? primaryVisibleEntities : displayEntities)
        let sectors = CompassSector.allCases.map { sector in
            makeRadarSectorNode(for: sector, entities: displayEntities.filter { compassSector(for: $0) == sector })
        }

        let nearbyCards = displayEntities.prefix(8).map(makeNearbyCard(for:))
        let hiddenNearbyCards = hiddenEntities.prefix(8).map(makeNearbyCard(for:))
        let allNearbyCards = entities.prefix(12).map(makeNearbyCard(for:))
        let connectedCount = displayEntities.filter(\.connected).count
        let verifiedMatchCount = purposeSignalsById.values.filter { $0.count > 0 }.count
        let followUpCount = followUpTargetsById.count
        let directionalCount = displayEntities.filter { hasDirectionalPosition($0) }.count
        let uncertainCount = displayEntities.count - directionalCount
        let summary = entities.isEmpty
            ? "Ingen nearby peers enda. Start scanner for å bygge et lokalt spatialt bilde."
            : "\(primaryVisibleEntities.count) relevant · \(hiddenEntities.count) hidden lower match(es) · \(connectedCount) connected · \(verifiedMatchCount) verified purpose fit(s) · \(followUpCount) follow-up chat(s) ready."
        let statusSummary = scannerStatusSummary(
            effectiveScannerStatus: effectiveScannerStatus,
            visibleEntityCount: primaryVisibleEntities.count
        )
        let lowerMatchesSummary = hiddenEntities.isEmpty
            ? "No lower nearby matches hidden."
            : "\(hiddenEntities.count) lower or nearby-only match(es) hidden by default."
        let showLowerMatchesLabel = showLowerMatches ? "Hide lower matches" : "Show lower matches"

        let precisionSummary: String
        if precisionMode.lowercased().contains("uwb") || supportsNearbyPrecision {
            precisionSummary = "UWB-precision is available on this device. MPC remains the base transport."
        } else {
            precisionSummary = "Using MPC-only proximity. Direction and distance stay less precise until UWB is available."
        }

        let localityNote = "HAVEN-local spatial enrichment over EntityScanner. This augments conference discovery without replacing the portable scaffold contract."
        let spatialTruthSummary: String
        if displayEntities.isEmpty {
            spatialTruthSummary = "Når nearby-signaler dukker opp, viser vi presis retning bare når sensoren faktisk gir retning."
        } else if directionalCount > 0, uncertainCount > 0 {
            spatialTruthSummary = "Presis retning vises for \(directionalCount) deltager(e). \(uncertainCount) treff mangler retning og samles under retning usikker."
        } else if directionalCount > 0 {
            spatialTruthSummary = "Alle synlige treff har en faktisk retningsmåling akkurat nå."
        } else {
            spatialTruthSummary = "Ingen treff har presis retning akkurat nå. Nearby-signaler vises derfor som retning usikker."
        }
        let selectionSummary: String
        if let focusedRemoteUUID,
           let focusedEntity = entitiesById[focusedRemoteUUID] {
            selectionSummary = "Fokuserer på \(focusedEntity.displayName) i denne siden."
        } else {
            selectionSummary = "Trykk Vis i siden på en nearby-deltager for å fokusere på personen her."
        }
        let nextStepSummary = nextStepSummary(
            focusedRemoteUUID: focusedRemoteUUID,
            effectiveScannerStatus: effectiveScannerStatus
        )
        let matchSummary = focusedRemoteUUID.flatMap { remoteUUID in
            entitiesById[remoteUUID].map { entity in
                relevanceSignal(for: remoteUUID, entity: entity).summary
            }
        } ?? strongestRelevanceSummary(in: displayEntities)
        let navigationSummary = focusedRemoteUUID == nil
            ? "Første klikk skjer i denne siden. Full radar og profilflate åpnes bare når du ber om en egen arbeidsflate."
            : "Du ser nå valgt deltager i denne siden. Åpne profilflate og full radar når du vil fordype deg i egne arbeidsflater."
        let selectedEntity = focusedRemoteUUID.flatMap { selectedEntityObject(for: $0) }
            ?? [
                "selectionBadge": .string("VALGT DELTAGER"),
                "title": .string("Ingen deltager valgt ennå"),
                "subtitle": .string("Velg en nearby deltager fra listen under."),
                "detail": .string("Når en deltager er valgt, viser vi avstand, retning og neste steg her."),
                "relevanceBadge": .string("AVVENTER VALG"),
                "tierLabel": .string("none"),
                "scoreText": .string(""),
                "proximitySummary": .string("No local proximity target selected."),
                "directionConfidence": .string("unknown"),
                "publicSectionLabel": .string("OPENLY PUBLISHED"),
                "publicHeadline": .string("Select an entity to load openly published information."),
                "publicInterests": .string(""),
                "publicLookingFor": .string(""),
                "publicOverlap": .string(""),
                "relationBadge": .string("Not established"),
                "identityPersistenceSummary": .string("Signed identity exchange has not completed."),
                "chatAvailability": .string("Chat available after signed identity exchange."),
                "relevanceSummary": .string("Velg en deltager for å se hvor sterk matchen ser ut akkurat nå."),
                "purposeSummary": .string("Ingen valgt deltager ennå"),
                "purposeDetail": .string("Verifisert purpose/interest-match vises først etter signert kontakt."),
                "followUpSummary": .string("Ingen oppfølging startet ennå."),
                "chatSummary": .string("Chat blir tilgjengelig når en valgt deltager er verifisert."),
                "note": .string("Bruk kortene under til å fokusere på en deltager.")
            ]
        let selectedEntityActions = focusedRemoteUUID.map { selectedEntityActionCards(for: $0) } ?? []
        let radarLayout = makeRadarLayout(
            entities: displayEntities,
            focusedRemoteUUID: focusedRemoteUUID,
            effectiveScannerStatus: effectiveScannerStatus
        )

        return [
            "headline": .string("Nearby Participants"),
            "summary": .string(summary),
            "visibleEntityCount": .integer(primaryVisibleEntities.count),
            "detectedEntityCount": .integer(entities.count),
            "hiddenEntityCount": .integer(hiddenEntities.count),
            "showingLowerMatches": .bool(showLowerMatches),
            "lowerMatchesSummary": .string(lowerMatchesSummary),
            "showLowerMatchesLabel": .string(showLowerMatchesLabel),
            "statusSummary": .string(statusSummary),
            "precisionSummary": .string(precisionSummary),
            "actionSummary": .string(lastActionSummary),
            "selectionSummary": .string(selectionSummary),
            "nextStepSummary": .string(nextStepSummary),
            "matchSummary": .string(matchSummary),
            "navigationSummary": .string(navigationSummary),
            "spatialTruthSummary": .string(spatialTruthSummary),
            "transportBadge": .string(transportMode.uppercased()),
            "precisionBadge": .string(precisionMode.uppercased()),
            "statusBadge": .string(effectiveScannerStatus),
            "localityNote": .string(localityNote),
            "description": .string(capabilityDescription),
            "radarLayout": .object(radarLayout),
            "selectedEntity": .object(selectedEntity),
            "selectedEntityActions": .list(selectedEntityActions.map(ValueType.object)),
            "sectors": .list(sectors.map(ValueType.object)),
            "nearby": .list(nearbyCards.map(ValueType.object)),
            "hiddenNearby": .list(hiddenNearbyCards.map(ValueType.object)),
            "allNearby": .list(allNearbyCards.map(ValueType.object)),
            "emptyState": .string(primaryVisibleEntities.isEmpty ? "No relevant entities nearby." : ""),
            "lastError": .string(lastError ?? "")
        ]
    }

    private func emitSnapshot(requester: Identity) {
        var flowElement = FlowElement(
            title: "Nearby Radar Snapshot",
            content: .object(snapshotObject()),
            properties: FlowElement.Properties(type: .content, contentType: .object)
        )
        flowElement.topic = "nearbyRadar.snapshot"
        flowElement.origin = self.uuid
        pushFlowElement(flowElement, requester: requester)
    }

    private func sortedEntities() -> [NearbyEntity] {
        entitiesById.values.sorted { lhs, rhs in
            let lhsDistance = lhs.distanceMeters ?? .greatestFiniteMagnitude
            let rhsDistance = rhs.distanceMeters ?? .greatestFiniteMagnitude
            let lhsSelected = lhs.remoteUUID == selectedRemoteUUID
            let rhsSelected = rhs.remoteUUID == selectedRemoteUUID
            if lhsSelected != rhsSelected {
                return lhsSelected
            }
            let lhsMarked = followUpMarkedRemoteUUIDs.contains(lhs.remoteUUID)
            let rhsMarked = followUpMarkedRemoteUUIDs.contains(rhs.remoteUUID)
            if lhsMarked != rhsMarked {
                return lhsMarked
            }
            if lhs.connected != rhs.connected {
                return lhs.connected && !rhs.connected
            }
            let lhsVerified = followUpTargetsById[lhs.remoteUUID] != nil
            let rhsVerified = followUpTargetsById[rhs.remoteUUID] != nil
            if lhsVerified != rhsVerified {
                return lhsVerified
            }
            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }
            return lhs.lastSeenAt > rhs.lastSeenAt
        }
    }

    private func makeSectorCard(for sector: CompassSector, entities: [NearbyEntity]) -> Object {
        let closest = entities
            .compactMap(\.distanceMeters)
            .min()
            .map { String(format: "%.1f m", $0) }
            ?? "No distance yet"

        let previewNames = entities
            .prefix(2)
            .map(\.displayName)
            .joined(separator: " · ")

        return [
            "title": .string(sector.title),
            "subtitle": .string("\(entities.count) peer(s)"),
            "detail": .string(sector == .uncertain
                ? (entities.isEmpty ? "Ingen usikre nearby-signaler" : "MPC-only eller ventende retning · nærmest \(closest)")
                : (entities.isEmpty ? "No active signals" : "Closest: \(closest)")),
            "note": .string(previewNames.isEmpty
                ? (sector == .uncertain ? "Waiting for approximate signals" : "Waiting for directional signals")
                : previewNames)
        ]
    }

    private func makeRadarLayout(
        entities: [NearbyEntity],
        focusedRemoteUUID: String?,
        effectiveScannerStatus: String
    ) -> Object {
        let groupedEntities = Dictionary(grouping: entities, by: compassSector)
        return [
            "surface": .object(makeRadarSurface(
                entities: entities,
                focusedRemoteUUID: focusedRemoteUUID,
                effectiveScannerStatus: effectiveScannerStatus
            )),
            "ahead": .object(makeRadarSectorNode(for: .ahead, entities: groupedEntities[.ahead] ?? [])),
            "left": .object(makeRadarSectorNode(for: .left, entities: groupedEntities[.left] ?? [])),
            "center": .object(makeRadarCenterNode(
                focusedRemoteUUID: focusedRemoteUUID,
                entities: entities,
                effectiveScannerStatus: effectiveScannerStatus
            )),
            "right": .object(makeRadarSectorNode(for: .right, entities: groupedEntities[.right] ?? [])),
            "behind": .object(makeRadarSectorNode(for: .behind, entities: groupedEntities[.behind] ?? [])),
            "uncertain": .object(makeRadarSectorNode(for: .uncertain, entities: groupedEntities[.uncertain] ?? []))
        ]
    }

    private func makeRadarSurface(
        entities: [NearbyEntity],
        focusedRemoteUUID: String?,
        effectiveScannerStatus: String
    ) -> Object {
        let now = Date()
        let allNodes = entities.map { makeRadarSurfaceNode(for: $0, focusedRemoteUUID: focusedRemoteUUID, now: now) }
        let preciseNodes = allNodes.filter { string(from: $0["positionPrecision"]) == "precise" }
        let approximateNodes = allNodes.filter { string(from: $0["positionPrecision"]) != "precise" }
        let selectedNode = focusedRemoteUUID.flatMap { remoteUUID in
            entitiesById[remoteUUID].map { makeRadarSurfaceNode(for: $0, focusedRemoteUUID: focusedRemoteUUID, now: now) }
        }

        let summary: String
        if entities.isEmpty {
            summary = "Ingen live nearby-noder ennå."
        } else if approximateNodes.isEmpty {
            summary = "\(preciseNodes.count) node(r) har device-relative retning og avstand."
        } else if preciseNodes.isEmpty {
            summary = "\(approximateNodes.count) node(r) mangler retning og vises i usikkerhetsfeltet."
        } else {
            summary = "\(preciseNodes.count) presise node(r), \(approximateNodes.count) omtrentlige node(r)."
        }

        return [
            "kind": .string("conference-nearby-radar-surface"),
            "renderingOwner": .string("binding-native-swiftui"),
            "coordinateSpace": .string("device-relative"),
            "status": .string(effectiveScannerStatus),
            "summary": .string(summary),
            "selectedRemoteUUID": .string(focusedRemoteUUID ?? ""),
            "maxDistanceMeters": .float(8.0),
            "updatedAtEpoch": .float(now.timeIntervalSince1970),
            "ringMeters": .list([1.0, 2.0, 4.0, 8.0].map { .float($0) }),
            "preciseCount": .integer(preciseNodes.count),
            "approximateCount": .integer(approximateNodes.count),
            "allCount": .integer(allNodes.count),
            "allNodes": .list(allNodes.map(ValueType.object)),
            "preciseNodes": .list(preciseNodes.map(ValueType.object)),
            "approximateNodes": .list(approximateNodes.map(ValueType.object)),
            "selectedNode": selectedNode.map(ValueType.object) ?? .null
        ]
    }

    private func makeRadarSurfaceNode(
        for entity: NearbyEntity,
        focusedRemoteUUID: String?,
        now: Date
    ) -> Object {
        let directionIsPrecise = hasDirectionalPosition(entity)
        let relevance = relevanceSignal(for: entity.remoteUUID, entity: entity)
        let ageSeconds = max(0, now.timeIntervalSince(entity.lastSeenAt))
        let distanceText = entity.distanceMeters.map { String(format: "%.1f m", $0) } ?? "distance pending"
        let position = normalizedRadarSurfacePosition(for: entity)
        let positionPrecision: String
        if directionIsPrecise {
            positionPrecision = "precise"
        } else if entity.distanceMeters != nil || entity.connected {
            positionPrecision = "approximate"
        } else {
            positionPrecision = "unknown"
        }

        return [
            "remoteUUID": .string(entity.remoteUUID),
            "displayName": .string(entity.displayName),
            "title": .string(entity.displayName),
            "subtitle": .string(directionSubtitle(for: entity, directionIsPrecise: directionIsPrecise)),
            "detail": .string(positionDetail(for: entity, directionIsPrecise: directionIsPrecise)),
            "distanceText": .string(distanceText),
            "distanceMeters": entity.distanceMeters.map(ValueType.float) ?? .null,
            "xNormalized": position.map { .float($0.x) } ?? .null,
            "yNormalized": position.map { .float($0.y) } ?? .null,
            "radiusNormalized": .float(position?.radius ?? radarRadiusNormalized(forDistanceMeters: entity.distanceMeters)),
            "azimuthRadians": position.map { .float($0.azimuthRadians) } ?? .null,
            "sector": .string(compassSector(for: entity).rawValue),
            "positionPrecision": .string(positionPrecision),
            "directionConfidence": .string(directionIsPrecise ? "precise direction" : "direction uncertain"),
            "uncertaintySummary": .string(directionIsPrecise
                ? "Retning kommer fra live nearby direction vector."
                : "Ingen live retning i signalet. Noden plasseres ikke som presis retning."),
            "connected": .bool(entity.connected),
            "status": .string(entity.status),
            "isSelected": .bool(entity.remoteUUID == focusedRemoteUUID),
            "isStale": .bool(entity.status == "lost" || (!entity.connected && ageSeconds > 4.0)),
            "ageSeconds": .float(ageSeconds),
            "freshnessLabel": .string(freshnessLabel(ageSeconds: ageSeconds, status: entity.status)),
            "relevanceBadge": .string(relevance.badge),
            "tierLabel": .string(relevance.tier),
            "scoreText": .string(relevance.scoreText),
            "relevanceSummary": .string(relevance.summary),
            "purposeSummary": .string(purposeSignalsById[entity.remoteUUID]?.summary ?? fallbackPurposeSummary(for: entity.remoteUUID, liveScore: entity.matchScore)),
            "relationBadge": .string(contactSignalsById[entity.remoteUUID]?.actionLabel ?? ""),
            "followUpReady": .bool(followUpTargetsById[entity.remoteUUID] != nil),
            "followUpMarked": .bool(followUpMarkedRemoteUUIDs.contains(entity.remoteUUID)),
            "actionKeypath": .string("nearbyRadar.dispatchAction"),
            "actionPayload": .object([
                "keypath": .string("selectEntity"),
                "payload": .object(["remoteUUID": .string(entity.remoteUUID)])
            ])
        ]
    }

    private func normalizedRadarSurfacePosition(for entity: NearbyEntity) -> (x: Double, y: Double, radius: Double, azimuthRadians: Double)? {
        guard let direction = entity.direction else {
            return nil
        }
        let radius = radarRadiusNormalized(forDistanceMeters: entity.distanceMeters)
        let azimuthRadians = direction.azimuthRadians
        return (
            x: sin(azimuthRadians) * radius,
            y: cos(azimuthRadians) * radius,
            radius: radius,
            azimuthRadians: azimuthRadians
        )
    }

    private func radarRadiusNormalized(forDistanceMeters distanceMeters: Double?) -> Double {
        guard let distanceMeters else {
            return 0.72
        }
        return min(max(distanceMeters / 8.0, 0.12), 0.98)
    }

    private func freshnessLabel(ageSeconds: TimeInterval, status: String) -> String {
        if status == "lost" {
            return "lost"
        }
        switch ageSeconds {
        case ..<1.5:
            return "live"
        case ..<5.0:
            return "recent"
        default:
            return "stale"
        }
    }

    private func makeRadarSectorNode(for sector: CompassSector, entities: [NearbyEntity]) -> Object {
        var card = makeSectorCard(for: sector, entities: entities)
        if let strongestEntity = entities.first {
            let relevance = relevanceSignal(for: strongestEntity.remoteUUID, entity: strongestEntity)
            card["relevanceBadge"] = .string(relevance.badge)
            card["summary"] = .string(relevance.summary)
            card["note"] = .string(relevance.detail)
        } else {
            card["relevanceBadge"] = .string(sector == .uncertain ? "NÆRHET FØRST" : "AVVENTER TREFF")
            card["summary"] = .string(sector == .uncertain
                ? "Treff her vil først bli vist som usikker nearby-nærhet."
                : "Når treff dukker opp her, viser vi også hvor sterke matchene ser ut.")
        }
        card["badge"] = .string(sector == .uncertain ? "USIKKER NÆRHET" : "ROMLIG SEKTOR")
        if entities.isEmpty {
            card["note"] = .string(sector == .uncertain
                ? "Ingen usikre nearby-signaler akkurat nå."
                : "Ingen treff i denne retningen akkurat nå.")
        }
        return card
    }

    private func makeRadarCenterNode(
        focusedRemoteUUID: String?,
        entities: [NearbyEntity],
        effectiveScannerStatus: String
    ) -> Object {
        guard let focusedRemoteUUID,
              let focusedEntity = entitiesById[focusedRemoteUUID] else {
            let startGuidance = effectiveScannerStatus == "started"
                ? "Scanner kjører. Velg en nearby deltager når et treff dukker opp."
                : "Start scanner for å bygge et lokalt spatialt bilde."
            return [
                "badge": .string("FOKUS"),
                "title": .string("Velg en nearby deltager"),
                "subtitle": .string("\(entities.count) treff synlige i nærheten"),
                "detail": .string(startGuidance),
                "note": .string("Når en deltager er valgt, viser vi neste handling og chat-oppfølging her.")
            ]
        }

        let purposeSignal = purposeSignalsById[focusedRemoteUUID]
        let hasVerifiedContact = contactSignalsById[focusedRemoteUUID]?.status == "verified"
        let hasFollowUpChat = launchedChatRemoteUUIDs.contains(focusedRemoteUUID)
        let nextStep: String
        if hasVerifiedContact, hasFollowUpChat {
            nextStep = "Chatten er klar. Neste steg er å åpne den eller markere deltakeren for videre oppfølging."
        } else if hasVerifiedContact {
            nextStep = "Kontakten er verifisert. Neste steg er å starte chat eller markere deltakeren for oppfølging."
        } else {
            nextStep = "Neste steg er å be om kontakt for å verifisere purpose- og interesse-matchen."
        }

        return [
            "badge": .string("FOKUS"),
            "title": .string(focusedEntity.displayName),
            "subtitle": .string(directionSubtitle(for: focusedEntity, directionIsPrecise: hasDirectionalPosition(focusedEntity))),
            "detail": .string(purposeSignal?.summary ?? fallbackPurposeSummary(for: focusedRemoteUUID, liveScore: focusedEntity.matchScore)),
            "relevanceBadge": .string(relevanceSignal(for: focusedRemoteUUID, entity: focusedEntity).badge),
            "summary": .string(relevanceSignal(for: focusedRemoteUUID, entity: focusedEntity).summary),
            "note": .string(nextStep)
        ]
    }

    private func makeNearbyCard(for entity: NearbyEntity) -> Object {
        let directionIsPrecise = hasDirectionalPosition(entity)
        let purposeSignal = purposeSignalsById[entity.remoteUUID]
        let contactSignal = contactSignalsById[entity.remoteUUID]
        let followUpMarked = followUpMarkedRemoteUUIDs.contains(entity.remoteUUID)
        let selected = entity.remoteUUID == selectedRemoteUUID
        let relevance = relevanceSignal(for: entity.remoteUUID, entity: entity)
        let distanceText = entity.distanceMeters.map { String(format: "%.1f m", $0) } ?? "distance pending"
        let relationBadge = contactSignal?.actionLabel ?? ""
        let directionConfidence = directionIsPrecise ? "precise direction" : "direction uncertain"
        let noteParts = [
            selected ? "Valgt i fokus." : nil,
            followUpMarked ? "Markert for oppfølging." : nil,
            contactSignal?.summary ?? positionTrustSummary(for: entity, directionIsPrecise: directionIsPrecise)
        ].compactMap { $0 }

        return [
            "title": .string(entity.displayName),
            "subtitle": .string(directionSubtitle(for: entity, directionIsPrecise: directionIsPrecise)),
            "detail": .string(positionDetail(for: entity, directionIsPrecise: directionIsPrecise)),
            "relevanceBadge": .string(relevance.badge),
            "tierLabel": .string(relevance.tier),
            "scoreText": .string(relevance.scoreText),
            "distanceText": .string(distanceText),
            "directionConfidence": .string(directionConfidence),
            "relationBadge": .string(relationBadge),
            "relevanceSummary": .string(relevance.summary),
            "purposeSummary": .string(purposeSignal?.summary ?? fallbackPurposeSummary(for: entity.remoteUUID, liveScore: entity.matchScore)),
            "purposeDetail": .string(purposeSignal?.detail ?? "Purpose fit remains approximate until signed contact is established."),
            "publicPreviewSummary": .string(purposeSignal?.summary ?? "Openly published profile preview loads only after selection."),
            "note": .string(noteParts.joined(separator: " ")),
            "keypath": .string("nearbyRadar.dispatchAction"),
            "label": .string(selected ? "Valgt i siden" : "Vis i siden"),
            "payload": .object([
                "keypath": .string("selectEntity"),
                "payload": .object(["remoteUUID": .string(entity.remoteUUID)])
            ])
        ]
    }

    private func mutationErrorDescription(from value: ValueType?) -> String? {
        guard let value else { return "Unknown nearby follow-up failure." }
        switch value {
        case let .string(string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return nil }
            if trimmed == "denied" || trimmed.hasPrefix("error:") || trimmed.hasPrefix("failure") {
                return trimmed
            }
            return nil
        case let .object(object):
            if case let .string(status)? = object["status"],
               status == "error",
               let message = string(from: object["message"]) {
                return message
            }
            return nil
        default:
            return nil
        }
    }

    private func compassSector(for entity: NearbyEntity) -> CompassSector {
        guard let direction = entity.direction else {
            return .uncertain
        }
        let angle = direction.azimuthRadians
        if angle >= -.pi / 4, angle < .pi / 4 {
            return .ahead
        }
        if angle >= .pi / 4, angle < 3 * .pi / 4 {
            return .right
        }
        if angle <= -.pi / 4, angle > -3 * .pi / 4 {
            return .left
        }
        return .behind
    }

    private func hasDirectionalPosition(_ entity: NearbyEntity) -> Bool {
        entity.direction != nil
    }

    private func ensureSelectedRemoteUUID(in entities: [NearbyEntity]) -> String? {
        let validRemoteUUIDs = Set(entities.map(\.remoteUUID))
        if let selectedRemoteUUID, validRemoteUUIDs.contains(selectedRemoteUUID) {
            return selectedRemoteUUID
        }

        let preferredRemoteUUID = entities.sorted { lhs, rhs in
            let lhsMarked = followUpMarkedRemoteUUIDs.contains(lhs.remoteUUID)
            let rhsMarked = followUpMarkedRemoteUUIDs.contains(rhs.remoteUUID)
            if lhsMarked != rhsMarked {
                return lhsMarked
            }
            let lhsVerified = followUpTargetsById[lhs.remoteUUID] != nil
            let rhsVerified = followUpTargetsById[rhs.remoteUUID] != nil
            if lhsVerified != rhsVerified {
                return lhsVerified
            }
            let lhsDirectional = hasDirectionalPosition(lhs)
            let rhsDirectional = hasDirectionalPosition(rhs)
            if lhsDirectional != rhsDirectional {
                return lhsDirectional
            }
            let lhsDistance = lhs.distanceMeters ?? .greatestFiniteMagnitude
            let rhsDistance = rhs.distanceMeters ?? .greatestFiniteMagnitude
            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }
            return lhs.lastSeenAt > rhs.lastSeenAt
        }.first?.remoteUUID

        selectedRemoteUUID = preferredRemoteUUID
        return preferredRemoteUUID
    }

    private func selectedEntityObject(for remoteUUID: String) -> Object? {
        guard let entity = entitiesById[remoteUUID] else {
            return nil
        }
        let purposeSignal = purposeSignalsById[remoteUUID]
        let contactSignal = contactSignalsById[remoteUUID]
        let target = followUpTargetsById[remoteUUID]
        let markedForFollowUp = followUpMarkedRemoteUUIDs.contains(remoteUUID)
        let hasVerifiedContact = contactSignal?.status == "verified"
        let hasLaunchedChat = launchedChatRemoteUUIDs.contains(remoteUUID)
        let relevance = relevanceSignal(for: remoteUUID, entity: entity)
        let selectionBadge = markedForFollowUp ? "VALGT · MARKERT FOR OPPFØLGING" : "VALGT DELTAGER"
        let directionIsPrecise = hasDirectionalPosition(entity)
        let subtitleParts = [target?.company, target?.role].compactMap { value -> String? in
            guard let value, value.isEmpty == false else { return nil }
            return value
        }
        let noteParts = [
            contactSignal?.summary,
            markedForFollowUp ? "Denne deltakeren er markert for oppfølging." : nil
        ].compactMap { $0 }

        return [
            "selectionBadge": .string(selectionBadge),
            "title": .string(entity.displayName),
            "subtitle": .string(subtitleParts.isEmpty ? directionSubtitle(for: entity, directionIsPrecise: directionIsPrecise) : subtitleParts.joined(separator: " · ")),
            "detail": .string(positionDetail(for: entity, directionIsPrecise: directionIsPrecise)),
            "relevanceBadge": .string(relevance.badge),
            "tierLabel": .string(relevance.tier),
            "scoreText": .string(relevance.scoreText),
            "proximitySummary": .string(positionDetail(for: entity, directionIsPrecise: directionIsPrecise)),
            "directionConfidence": .string(directionIsPrecise ? "precise direction" : "direction uncertain"),
            "publicSectionLabel": .string("OPENLY PUBLISHED"),
            "publicHeadline": .string(target?.role ?? "No public headline available yet."),
            "publicInterests": .string(purposeSignal?.summary ?? "No public interests loaded yet."),
            "publicLookingFor": .string("No public looking-for field loaded yet."),
            "publicOverlap": .string(purposeSignal?.detail ?? "Overlap remains local until a public profile reference is selected."),
            "relationBadge": .string(contactSignal?.actionLabel ?? "Not established"),
            "identityPersistenceSummary": .string(hasVerifiedContact
                ? "Signed identity exchange complete · relation persisted · proof saved"
                : "Signed identity exchange not complete. Chat stays locked."),
            "chatAvailability": .string(hasVerifiedContact
                ? (hasLaunchedChat ? "Open chat" : "Chat ready after identity save")
                : "Chat available after signed identity exchange."),
            "relevanceSummary": .string(relevance.summary),
            "purposeSummary": .string(purposeSignal?.summary ?? fallbackPurposeSummary(for: remoteUUID, liveScore: entity.matchScore)),
            "purposeDetail": .string(purposeSignal?.detail ?? "Verifisert purpose/interest-fit kommer først etter signert kontakt."),
            "followUpSummary": .string(followUpSummary(
                remoteUUID: remoteUUID,
                displayName: entity.displayName,
                hasVerifiedContact: hasVerifiedContact,
                hasLaunchedChat: hasLaunchedChat,
                markedForFollowUp: markedForFollowUp
            )),
            "chatSummary": .string(chatSummary(
                remoteUUID: remoteUUID,
                displayName: entity.displayName,
                hasVerifiedContact: hasVerifiedContact,
                hasLaunchedChat: hasLaunchedChat
            )),
            "note": .string(noteParts.isEmpty ? positionTrustSummary(for: entity, directionIsPrecise: hasDirectionalPosition(entity)) : noteParts.joined(separator: " "))
        ]
    }

    private func selectedEntityActionCards(for remoteUUID: String) -> [Object] {
        guard let entity = entitiesById[remoteUUID] else {
            return []
        }

        let profileAction: Object = [
            "title": .string("Profilflate"),
            "subtitle": .string("Åpne valgt deltager i egen flate"),
            "detail": .string("Vis valgt deltager som en hybrid av offentlig profil, lokal spatial kontekst og neste oppfølgingssteg."),
            "note": .string("Bruk dette når du vil fordype deg uten å miste conference-konteksten."),
            "keypath": .string("dispatchAction"),
            "label": .string("Åpne profilflate"),
            "payload": .object([
                "keypath": .string("openSelectedParticipantWorkbench"),
                "payload": .bool(true)
            ])
        ]

        let contactStatus = contactSignalsById[remoteUUID]?.status
        let primaryAction: Object
        if followUpTargetsById[remoteUUID] != nil,
           contactSignalsById[remoteUUID]?.status == "verified" {
            let hasLaunchedChat = launchedChatRemoteUUIDs.contains(remoteUUID)
            primaryAction = [
                "title": .string("Chat"),
                "subtitle": .string(hasLaunchedChat ? "Fortsett oppfølging" : "Start oppfølging"),
                "detail": .string(hasLaunchedChat
                    ? "Discovery-chatten er klar. Åpne chatflaten for å fortsette samtalen med \(entity.displayName)."
                    : "Opprett en conference-chat med \(entity.displayName) fra denne nearby-matchen."),
                "note": .string("Dette er tilgjengelig fordi kontakten allerede er verifisert."),
                "keypath": .string(hasLaunchedChat ? "chatSnapshot.dispatchAction" : "nearbyRadar.dispatchAction"),
                "label": .string(hasLaunchedChat ? "Åpne chatflate" : "Start chat"),
                "payload": hasLaunchedChat
                    ? .object([
                        "keypath": .string("openChatWorkbench"),
                        "payload": .object([
                            "displayName": .string(entity.displayName)
                        ])
                    ])
                    : .object([
                        "keypath": .string("openFollowUpChat"),
                        "payload": .object(["remoteUUID": .string(remoteUUID)])
                    ])
            ]
        } else {
            let isIncoming = contactStatus == "incoming"
            let isWaiting = contactStatus == "sent" || contactStatus == "pendingConnection"
            primaryAction = [
                "title": .string("Kontakt"),
                "subtitle": .string(isIncoming ? "Fullfør signert identitetsutveksling" : "Be om signert kontakt"),
                "detail": .string(isIncoming
                    ? "Accepting completes signed identity exchange, persists the relation and saves encounter proof locally."
                    : "Etabler kontakt først. Når identiteten er lagret, kan du starte chat med høyere presisjon i match-signalet."),
                "note": .string(contactSignalsById[remoteUUID]?.summary ?? "Kontaktbeviset er første steg før verifisert purpose/interest-match."),
                "keypath": .string("nearbyRadar.dispatchAction"),
                "label": .string(isIncoming ? "Accept + exchange" : (isWaiting ? "Awaiting exchange" : "Request contact")),
                "payload": .object([
                    "keypath": .string(isIncoming ? "acceptContact" : "requestContact"),
                    "payload": .string(remoteUUID)
                ])
            ]
        }

        let inviteAction: Object = [
            "title": .string("Invite"),
            "subtitle": .string("Low-friction invitation"),
            "detail": .string("Send invite is separate from signed contact. It never implies automatic chat or profile access."),
            "note": .string(contactStatus == nil ? "Available for relevant nearby entities." : "Contact state already exists for this entity."),
            "keypath": .string("nearbyRadar.dispatchAction"),
            "label": .string("Send invite"),
            "payload": .object([
                "keypath": .string("invite"),
                "payload": .string(remoteUUID)
            ])
        ]

        let chatLockedAction: Object = [
            "title": .string("Chat"),
            "subtitle": .string("Visible but locked"),
            "detail": .string("Chat available after signed identity exchange."),
            "note": .string("The skeleton renderer has no true disabled-button semantic yet, so this appears as an explanatory card rather than an active chat button."),
            "keypath": .string("nearbyRadar.dispatchAction"),
            "label": .string("Chat locked"),
            "payload": .object([
                "keypath": .string("noop"),
                "payload": .string(remoteUUID)
            ])
        ]

        let markedForFollowUp = followUpMarkedRemoteUUIDs.contains(remoteUUID)
        let followUpAction: Object = [
            "title": .string("Oppfølging"),
            "subtitle": .string(markedForFollowUp ? "Fjern markering" : "Marker for oppfølging"),
            "detail": .string(markedForFollowUp
                ? "\(entity.displayName) er allerede markert for senere oppfølging."
                : "Legg denne deltakeren i oppfølgingsbunken uten å starte chat med en gang."),
            "note": .string(markedForFollowUp
                ? "Bruk dette hvis du vil rydde fokuslisten igjen."
                : "Passer når du vil komme tilbake etter sesjonen eller senere i dagen."),
            "keypath": .string("nearbyRadar.dispatchAction"),
            "label": .string(markedForFollowUp ? "Fjern markering" : "Marker for oppfølging"),
            "payload": .object([
                "keypath": .string("toggleFollowUp"),
                "payload": .object(["remoteUUID": .string(remoteUUID)])
            ])
        ]

        if contactStatus == "verified" {
            return [profileAction, primaryAction, followUpAction]
        }
        return [profileAction, inviteAction, primaryAction, chatLockedAction, followUpAction]
    }

    private func scannerStatusSummary(
        effectiveScannerStatus: String,
        visibleEntityCount: Int
    ) -> String {
        switch effectiveScannerStatus {
        case "started":
            return visibleEntityCount == 0
                ? "Scanner kjører. Når første nearby-treff dukker opp, vises det her."
                : "Scanner kjører og oppdaterer nearby-treffene løpende."
        case "stopped":
            return "Scanner er stoppet. Start den når du vil lete etter nearby-deltagere."
        case "starting":
            return "Scanner starter nå. Nearby-signaler vil dukke opp her så snart første treff kommer inn."
        case "stopping":
            return "Scanner stopper nå og rydder live nearby-signaler."
        default:
            return visibleEntityCount == 0
                ? "Nearby-radaren er klar, men har ingen live treff ennå."
                : "Nearby-radaren er klar med siste kjente nearby-treff."
        }
    }

    private func nextStepSummary(
        focusedRemoteUUID: String?,
        effectiveScannerStatus: String
    ) -> String {
        guard let focusedRemoteUUID,
              let entity = entitiesById[focusedRemoteUUID] else {
            return effectiveScannerStatus == "started"
                ? "Trykk Vis i siden på en nearby-deltager for å fokusere på personen her."
                : "Start scanner og velg deretter en nearby-deltager med Vis i siden."
        }

        let hasVerifiedContact = contactSignalsById[focusedRemoteUUID]?.status == "verified"
        let hasFollowUpChat = launchedChatRemoteUUIDs.contains(focusedRemoteUUID)
        if hasVerifiedContact, hasFollowUpChat {
            return "Chatten med \(entity.displayName) er klar. Neste steg er å åpne chatten eller markere deltakeren for oppfølging."
        }
        if hasVerifiedContact {
            return "Kontakten med \(entity.displayName) er verifisert. Neste steg er å starte chat eller markere deltakeren for oppfølging."
        }
        return "Neste steg er å be om kontakt med \(entity.displayName) for å verifisere formål og interesser."
    }

    private func strongestRelevanceSummary(in entities: [NearbyEntity]) -> String {
        guard let strongest = entities.first else {
            return "Ingen match vurdert ennå. Start scanner for å hente nearby-signaler."
        }
        return relevanceSignal(for: strongest.remoteUUID, entity: strongest).summary
    }

    private func relevanceSignal(for remoteUUID: String, entity: NearbyEntity) -> RelevanceSignal {
        let purposeSignal = purposeSignalsById[remoteUUID]
        let score = purposeSignal?.score ?? entity.matchScore
        let hasVerifiedContact = contactSignalsById[remoteUUID]?.status == "verified"

        guard let score else {
            return RelevanceSignal(
                badge: "NÆRHET FØRST",
                summary: "Nearby-signal oppdaget, men matchen må verifiseres videre.",
                detail: "Be om kontakt for å gå fra nearby-nærhet til en mer presis vurdering.",
                tier: "nearby",
                scoreText: "",
                visibleByDefault: false
            )
        }

        if hasVerifiedContact, score >= 0.8 {
            return RelevanceSignal(
                badge: "GRØNN MATCH",
                summary: "Sterk verifisert match. Denne personen er klar for oppfølging nå.",
                detail: "Formål og interesser overlapper tydelig etter signert kontakt.",
                tier: "strong",
                scoreText: String(format: "%.2f", score),
                visibleByDefault: true
            )
        }
        if hasVerifiedContact, score >= 0.55 {
            return RelevanceSignal(
                badge: "GUL MATCH",
                summary: "God verifisert match. Det er verdt å følge opp videre.",
                detail: "Kontakten er verifisert, men relevansen er mer moderat enn toppmatchene.",
                tier: "good",
                scoreText: String(format: "%.2f", score),
                visibleByDefault: true
            )
        }
        if hasVerifiedContact {
            return RelevanceSignal(
                badge: "RØD MATCH",
                summary: "Svakt verifisert treff. Vurder om denne personen bør følges opp videre.",
                detail: "Kontakten er verifisert, men formål og interesser overlapper svakt.",
                tier: "low",
                scoreText: String(format: "%.2f", score),
                visibleByDefault: false
            )
        }
        if score >= 0.65 {
            return RelevanceSignal(
                badge: "LOVENDE MATCH",
                summary: "Lovende nearby-match. Det neste naturlige steget er å be om kontakt.",
                detail: "Scanneren ser høy relevans, men den er ikke verifisert ennå.",
                tier: "promising",
                scoreText: String(format: "%.2f", score),
                visibleByDefault: true
            )
        }
        if score >= 0.35 {
            return RelevanceSignal(
                badge: "GUL MATCH",
                summary: "Moderat nearby-match. Bruk dette som en kandidat, ikke som en bekreftet prioritet.",
                detail: "Det kan være verdt å be om kontakt hvis samtalen virker relevant.",
                tier: "moderate",
                scoreText: String(format: "%.2f", score),
                visibleByDefault: true
            )
        }
        return RelevanceSignal(
            badge: "RØD MATCH",
            summary: "Lav nearby-relevans akkurat nå. Se gjerne videre før du følger opp.",
            detail: "Dette treffet er nærme, men scorer lavt på nåværende matchsignal.",
            tier: "low",
            scoreText: String(format: "%.2f", score),
            visibleByDefault: false
        )
    }

    private func shouldShowEntityByDefault(_ entity: NearbyEntity) -> Bool {
        if entity.remoteUUID == selectedRemoteUUID {
            return true
        }
        if followUpMarkedRemoteUUIDs.contains(entity.remoteUUID) {
            return true
        }
        if launchedChatRemoteUUIDs.contains(entity.remoteUUID) {
            return true
        }
        if let contactStatus = contactSignalsById[entity.remoteUUID]?.status,
           ["verified", "sent", "incoming", "pendingConnection"].contains(contactStatus) {
            return true
        }
        return relevanceSignal(for: entity.remoteUUID, entity: entity).visibleByDefault
    }

    private func followUpSummary(
        remoteUUID: String,
        displayName: String,
        hasVerifiedContact: Bool,
        hasLaunchedChat: Bool,
        markedForFollowUp: Bool
    ) -> String {
        if hasLaunchedChat, markedForFollowUp {
            return "\(displayName) er både markert for oppfølging og har en chat klar."
        }
        if hasLaunchedChat {
            return "Chatten med \(displayName) er klar til videre oppfølging."
        }
        if markedForFollowUp {
            return "\(displayName) er markert for oppfølging senere."
        }
        if hasVerifiedContact {
            return "Identity saved. Nå kan du starte chat eller markere for oppfølging."
        }
        if contactSignalsById[remoteUUID]?.status == "sent" || contactSignalsById[remoteUUID]?.status == "pendingConnection" {
            return "Kontaktforespørselen er sendt. Vent på signert identitetsutveksling før du starter chat."
        }
        return "Ingen oppfølging startet ennå. Be om kontakt eller marker deltakeren for senere."
    }

    private func chatSummary(
        remoteUUID: String,
        displayName: String,
        hasVerifiedContact: Bool,
        hasLaunchedChat: Bool
    ) -> String {
        if hasLaunchedChat {
            return "Åpne chatten for å fortsette samtalen med \(displayName)."
        }
        if hasVerifiedContact {
            return "Chat er ikke startet ennå. Identity saved gjør at du kan trykke Start chat."
        }
        if contactSignalsById[remoteUUID]?.status == "sent" || contactSignalsById[remoteUUID]?.status == "pendingConnection" {
            return "Chat blir tilgjengelig når signert identitetsutveksling er fullført."
        }
        return "Chat er låst til fullført signert identitetsutveksling i denne nearby-flyten."
    }

    private func directionSubtitle(for entity: NearbyEntity, directionIsPrecise: Bool) -> String {
        if directionIsPrecise {
            return "\(compassSector(for: entity).title) · presis retning"
        }
        return "Retning usikker · nearby via MPC"
    }

    private func positionDetail(for entity: NearbyEntity, directionIsPrecise: Bool) -> String {
        let distanceText = entity.distanceMeters.map { String(format: "%.1f m", $0) } ?? "Avstand avventer"
        let visibilityText = entity.connected ? "tilkoblet" : "synlig"
        if directionIsPrecise {
            return "\(compassSector(for: entity).title) · \(distanceText) · \(visibilityText)"
        }
        return "Retning usikker · \(distanceText) · \(visibilityText)"
    }

    private func positionTrustSummary(for entity: NearbyEntity, directionIsPrecise: Bool) -> String {
        if directionIsPrecise {
            return "Retning og avstand er basert på levende nearby-signaler."
        }
        if entity.matchScore != nil {
            return "Dette treffet er synlig nearby, men retningen er foreløpig usikker."
        }
        return "Nearby-signal oppdaget. Retning og presis match må bekreftes videre."
    }

    private func normalizedRemoteUUID(_ remoteUUID: String?) -> String? {
        guard let remoteUUID else {
            return nil
        }
        let normalizedUUID = remoteUUID.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedUUID.isEmpty ? nil : normalizedUUID
    }

    private func string(from value: ValueType?) -> String? {
        guard let value else { return nil }
        if case let .string(string) = value {
            return string
        }
        return nil
    }

    private func bool(from value: ValueType?) -> Bool? {
        guard let value else { return nil }
        if case let .bool(bool) = value {
            return bool
        }
        return nil
    }

    private func int(from value: ValueType?) -> Int? {
        guard let value else { return nil }
        switch value {
        case let .integer(integer):
            return integer
        case let .float(float):
            return Int(float)
        case let .number(number):
            return number
        case let .string(string):
            return Int(string)
        default:
            return nil
        }
    }

    private func double(from value: ValueType?) -> Double? {
        guard let value else { return nil }
        switch value {
        case let .float(float):
            return float
        case let .integer(integer):
            return Double(integer)
        case let .number(number):
            return Double(number)
        case let .string(string):
            return Double(string)
        default:
            return nil
        }
    }

    private func object(from value: ValueType?) -> Object? {
        guard case let .object(object)? = value else {
            return nil
        }
        return object
    }

    private func list(from value: ValueType?) -> [ValueType]? {
        guard case let .list(list)? = value else {
            return nil
        }
        return list
    }
}

struct BootstrapView<Content: View>: View {
    @State private var isReady = false
    @State private var startupFailed = false
    @State private var startupAttemptID = UUID()
    let content: () -> Content

    var body: some View {
        Group {
            if isReady {
                content()
            } else if startupFailed {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("HAVEN-runtime kunne ikke startes")
                        .font(.headline)
                    Text("De lokale HAVEN-cellene kunne ikke valideres. Ingen delvis initialisert arbeidsflate ble åpnet.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Prøv igjen") {
                        startupFailed = false
                        startupAttemptID = UUID()
                    }
                }
                .padding()
            } else {
                ProgressView("Starter opp…")
            }
        }
        .task(id: startupAttemptID) {
            let registered = await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
            isReady = registered
            startupFailed = !registered
        }
    }
}


@MainActor
private final class ConferenceParticipantAgendaSnapshotLocalCell: GeneralCell {
    private var cachedAgendaState: Object = ConferenceParticipantAgendaSnapshotLocalCell.defaultAgendaState()
    private var lastRefreshAt: Date?
    private var refreshTask: Task<Void, Never>?
    private var activeView = "forYou"
    private var activeTrackID = "all"
    private var recentActionSummary = "Velg hvordan agendaen skal vises. Endringen skjer i denne siden med en gang."

    required init(owner: Identity) async {
        await super.init(owner: owner)
        await configure(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        fatalError("ConferenceParticipantAgendaSnapshotLocalCell does not support decoding")
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private func configure(owner: Identity) async {
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("rw--", for: "refresh")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")

        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("r---", at: "state", for: requester) else { return .string("denied") }
            await self.refreshSnapshotIfNeeded(force: false, forwardAction: nil, requester: requester)
            return .object(self.cachedAgendaState)
        })

        await addInterceptForSet(requester: owner, key: "refresh", setValueIntercept: { [weak self] _, _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "refresh", for: requester) else { return .string("denied") }
            let refreshAction: ValueType = .object([
                "keypath": .string("agenda.setView"),
                "payload": .object([
                    "view": .string(self.activeView)
                ])
            ])
            await self.refreshSnapshotIfNeeded(force: true, forwardAction: refreshAction, requester: requester)
            return .object([
                "status": .string("ok"),
                "state": .object(self.cachedAgendaState)
            ])
        })

        await addInterceptForSet(requester: owner, key: "dispatchAction", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "dispatchAction", for: requester) else { return .string("denied") }
            return await self.handleDispatchAction(value, requester: requester)
        })

        Task { [weak self] in
            guard let self else { return }
            await self.refreshSnapshotIfNeeded(force: true, forwardAction: nil, requester: owner)
        }
    }

    private func handleDispatchAction(_ value: ValueType, requester: Identity) async -> ValueType {
        guard case let .object(object) = value,
              let actionKeypath = string(from: object["keypath"]),
              actionKeypath.isEmpty == false else {
            cachedAgendaState = Self.agendaStateWithStatus(
                basedOn: cachedAgendaState,
                status: "Agenda-handlingen mangler keypath.",
                actionSummary: "Kunne ikke oppdatere agendaen fordi handlingspayloaden var ugyldig."
            )
            return .object([
                "status": .string("error"),
                "state": .object(cachedAgendaState)
            ])
        }

        let payload = object["payload"] ?? .null

        switch actionKeypath {
        case "agenda.setView":
            if case let .object(viewObject) = payload,
               let view = string(from: viewObject["view"]),
               view.isEmpty == false {
                activeView = normalizedView(view)
                recentActionSummary = actionSummaryForView(activeView)
            }
        case "agenda.setTrackFocus":
            if case let .object(trackObject) = payload,
               let trackID = string(from: trackObject["trackId"]),
               trackID.isEmpty == false {
                activeTrackID = normalizedTrackID(trackID)
                recentActionSummary = actionSummaryForTrack(activeTrackID)
            }
        default:
            recentActionSummary = "Utførte \(actionKeypath) i agenda-snapshotet."
        }

        cachedAgendaState = mergedAgendaState(from: cachedAgendaState, preserveCurrentSelection: true)
        let forwardedAction: ValueType = .object([
            "keypath": .string(actionKeypath),
            "payload": payload
        ])
        await refreshSnapshotIfNeeded(force: true, forwardAction: forwardedAction, requester: requester)
        return .object([
            "status": .string("ok"),
            "state": .object(cachedAgendaState)
        ])
    }

    private func refreshSnapshotIfNeeded(
        force: Bool,
        forwardAction: ValueType?,
        requester: Identity
    ) async {
        let shouldRetryImmediately = ConferenceSnapshotRetrySupport.shouldRetryImmediately(
            cachedState: cachedAgendaState,
            statusKeys: ["storageSummary", "persistenceStatus"]
        )

        if !force,
           !shouldRetryImmediately,
           let lastRefreshAt,
           Date().timeIntervalSince(lastRefreshAt) < 1 {
            return
        }

        if let refreshTask {
            await refreshTask.value
            let shouldRetryAfterInflight = ConferenceSnapshotRetrySupport.shouldRetryImmediately(
                cachedState: cachedAgendaState,
                statusKeys: ["storageSummary", "persistenceStatus"]
            )
            if !force && !shouldRetryAfterInflight {
                return
            }
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performRefresh(
                forwardAction: forwardAction,
                requester: requester
            )
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    @MainActor
    private func performRefresh(
        forwardAction: ValueType?,
        requester: Identity
    ) async {
        guard await BindingLocalCellRegistration.shared.ensureConferenceDemoRuntimeReady() else {
            cachedAgendaState = Self.agendaStateWithSyncWarning(
                basedOn: mergedAgendaState(from: cachedAgendaState, preserveCurrentSelection: true),
                storageSummary: "Agenda-valg vises lokalt mens runtime registreres på nytt.",
                persistenceStatus: "Kunne ikke validere lokal conference-runtime."
            )
            lastRefreshAt = Date()
            return
        }

        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let porthole = try? await resolver.cellAtEndpoint(
                endpoint: "cell:///Porthole",
                requester: requester
              ) as? Meddle else {
            cachedAgendaState = Self.agendaStateWithSyncWarning(
                basedOn: mergedAgendaState(from: cachedAgendaState, preserveCurrentSelection: true),
                storageSummary: "Agenda-valg vises lokalt mens Porthole kobler seg til igjen.",
                persistenceStatus: "Kunne ikke synkronisere agendaen akkurat nå. Valget ditt vises fortsatt i denne siden."
            )
            lastRefreshAt = Date()
            return
        }

        if let forwardAction {
            let mutationResult = try? await porthole.set(
                keypath: "conferenceParticipantShell.dispatchAction",
                value: forwardAction,
                requester: requester
            )
            if let errorDescription = mutationErrorDescription(from: mutationResult) {
                cachedAgendaState = Self.agendaStateWithSyncWarning(
                    basedOn: mergedAgendaState(from: cachedAgendaState, preserveCurrentSelection: true),
                    storageSummary: "Agenda-valget ditt vises lokalt mens vi prøver å synkronisere mot deltagerportalen.",
                    persistenceStatus: "Kunne ikke synkronisere agendahandlingen akkurat nå: \(errorDescription)"
                )
            }
        }

        do {
            let programValue = try await porthole.get(
                keypath: "conferenceParticipantShell.state.program",
                requester: requester
            )
            guard case let .object(programObject) = programValue else {
                cachedAgendaState = Self.agendaStateWithSyncWarning(
                    basedOn: mergedAgendaState(from: cachedAgendaState, preserveCurrentSelection: true),
                    storageSummary: "Agendaen bruker siste stabile data mens deltagerportalen blir lesbar igjen.",
                    persistenceStatus: "Kunne ikke lese oppdatert agenda akkurat nå. Valget ditt vises fortsatt lokalt."
                )
                lastRefreshAt = Date()
                return
            }

            cachedAgendaState = mergedAgendaState(from: programObject)
            lastRefreshAt = Date()
        } catch {
            cachedAgendaState = Self.agendaStateWithSyncWarning(
                basedOn: mergedAgendaState(from: cachedAgendaState, preserveCurrentSelection: true),
                storageSummary: "Agendaen viser siste stabile valg mens oppdateringen kobler seg til igjen.",
                persistenceStatus: "Kunne ikke hente oppdatert agenda akkurat nå: \(error)"
            )
            lastRefreshAt = Date()
        }
    }

    private func mergedAgendaState(from object: Object, preserveCurrentSelection: Bool = false) -> Object {
        var merged = Self.defaultAgendaState()
        for (key, value) in object {
            merged[key] = value
        }

        if !preserveCurrentSelection {
            synchronizeSelections(from: merged)
        }

        let rawTrackOptions = listObjects(from: merged["trackOptions"])
        let rawRecommended = listObjects(from: merged["recommendedSessions"])
        let rawSaved = listObjects(from: merged["savedSessions"])
        let rawTimeline = listObjects(from: merged["timelineSessions"])

        let trackOptions = rawTrackOptions.map { trackOptionCard(from: $0) }
        let recommendedSessions = rawRecommended.map { sessionCard(from: $0, category: .recommended) }
        let savedSessions = rawSaved.map { sessionCard(from: $0, category: .saved) }
        let timelineSessions = rawTimeline.map { sessionCard(from: $0, category: .timeline) }

        let activeViewLabel = viewLabel(activeView)
        let activeTrackLabel = trackLabel(activeTrackID)
        let activeViewCount = visibleSessionCount(
            recommendedCount: recommendedSessions.count,
            savedCount: savedSessions.count,
            timelineCount: timelineSessions.count
        )

        merged["intro"] = .string("Velg hvordan agendaen skal vises. Oppsummeringene under forklarer alltid hvilken visning og hvilket fokus som er aktivt akkurat nå.")
        merged["agendaSummary"] = .string("\(savedSessions.count) lagrede sesjoner · \(recommendedSessions.count) anbefalte sesjoner.")
        merged["viewSummary"] = .string("Aktiv visning: \(activeViewLabel).")
        merged["trackSummary"] = .string(activeTrackID == "all" ? "Aktivt spor: alle spor er synlige." : "Aktivt spor: \(activeTrackLabel).")
        merged["timelineSummary"] = .string(timelineSummaryText(for: activeView, visibleCount: activeViewCount))
        merged["status"] = .string(statusSummary(for: activeView, trackID: activeTrackID))
        merged["storageSummary"] = .string("Agenda-valg holdes stabile i deltagerportalen og speiles tilbake i denne siden.")
        merged["persistenceStatus"] = .string("Valgene dine blir husket lokalt, så siden ikke hopper når du bytter visning.")
        merged["recommendedSummary"] = .string("\(recommendedSessions.count) anbefalte sesjoner er klare når du bruker For deg.")
        merged["savedSummary"] = .string("\(savedSessions.count) lagrede sesjoner er klare når du åpner Lagret.")
        merged["statusSummary"] = .string(statusSummary(for: activeView, trackID: activeTrackID))
        merged["selectionSummary"] = .string("Viser \(activeViewLabel.lowercased()) med \(trackSelectionLabel(activeTrackID)).")
        merged["navigationSummary"] = .string("Knappene over bytter visning i denne siden med en gang. Handlingskortene under forklarer hva hver visning gjør.")
        merged["nextStepSummary"] = .string(nextStepSummary(for: activeView, trackID: activeTrackID))
        merged["actionSummary"] = .string(recentActionSummary)
        merged["modeChoices"] = .list(modeChoiceCards())
        merged["trackChoices"] = .list(trackChoiceCards())
        merged["trackOptions"] = .list(trackOptions)
        merged["recommendedSessions"] = .list(recommendedSessions)
        merged["savedSessions"] = .list(savedSessions)
        merged["timelineSessions"] = .list(timelineSessions)
        merged["focusedActions"] = .list(focusedActionCards())

        return merged
    }

    private func synchronizeSelections(from object: Object) {
        if let viewSummary = string(from: object["viewSummary"]) {
            activeView = inferredView(from: viewSummary)
        }
        if let trackSummary = string(from: object["trackSummary"]) {
            activeTrackID = inferredTrackID(from: trackSummary)
        }
    }

    private func modeChoiceCards() -> [ValueType] {
        [
            selectionChipCard(
                badge: activeView == "forYou" ? "AKTIV NÅ" : "MODUS",
                title: "For deg",
                subtitle: activeView == "forYou" ? "Anbefalingene dine vises nå" : "Anbefalte sesjoner først",
                detail: "Bruk denne når du vil tilbake til de mest relevante sesjonene for deg.",
                note: activeView == "forYou"
                    ? "For deg er aktiv i denne siden."
                    : "Bytter tilbake til anbefalt deltageragenda.",
                label: activeView == "forYou" ? "Viser nå" : "Vis for deg",
                actionKeypath: "agenda.setView",
                payload: .object(["view": .string("forYou")])
            ),
            selectionChipCard(
                badge: activeView == "timeline" ? "AKTIV NÅ" : "MODUS",
                title: "Timeline",
                subtitle: activeView == "timeline" ? "Hele programmet vises nå" : "Hele programmet i rekkefølge",
                detail: "Bruk denne når du vil orientere deg i hele programflyten.",
                note: activeView == "timeline"
                    ? "Timeline er aktiv i denne siden."
                    : "Bytter til full tidslinje uten å forlate siden.",
                label: activeView == "timeline" ? "Viser nå" : "Vis timeline",
                actionKeypath: "agenda.setView",
                payload: .object(["view": .string("timeline")])
            ),
            selectionChipCard(
                badge: activeView == "saved" ? "AKTIV NÅ" : "MODUS",
                title: "Lagret",
                subtitle: activeView == "saved" ? "Lagrede sesjoner vises nå" : "Bare det du har lagret",
                detail: "Bruk denne når du vil se bare det du allerede har valgt å ta vare på.",
                note: activeView == "saved"
                    ? "Lagret er aktiv i denne siden."
                    : "Bytter til kun lagrede sesjoner.",
                label: activeView == "saved" ? "Viser nå" : "Vis lagret",
                actionKeypath: "agenda.setView",
                payload: .object(["view": .string("saved")])
            )
        ]
    }

    private func trackChoiceCards() -> [ValueType] {
        [
            selectionChipCard(
                badge: activeTrackID == "all" ? "FOKUS NÅ" : "SPOR",
                title: "Alle spor",
                subtitle: activeTrackID == "all" ? "Hele bredden er synlig" : "Slå av innsnevret fokus",
                detail: "Bruk denne når du vil se hele konferansebredden igjen.",
                note: activeTrackID == "all"
                    ? "Alle spor er synlige nå."
                    : "Går tilbake til full oversikt uten spor-fokus.",
                label: activeTrackID == "all" ? "Viser nå" : "Vis alle spor",
                actionKeypath: "agenda.setTrackFocus",
                payload: .object(["trackId": .string("all")])
            ),
            selectionChipCard(
                badge: activeTrackID == "track-governance" ? "FOKUS NÅ" : "SPOR",
                title: "Governance",
                subtitle: activeTrackID == "track-governance" ? "Governance er valgt nå" : "Snevr inn til governance",
                detail: "Bruk denne når du vil se governance-sporet tydeligere i agendaen.",
                note: activeTrackID == "track-governance"
                    ? "Governance er aktivt fokus i denne siden."
                    : "Setter governance i fokus uten å åpne en ny flate.",
                label: activeTrackID == "track-governance" ? "Viser nå" : "Fokuser governance",
                actionKeypath: "agenda.setTrackFocus",
                payload: .object(["trackId": .string("track-governance")])
            )
        ]
    }

    private func selectionChipCard(
        badge: String,
        title: String,
        subtitle: String,
        detail: String,
        note: String,
        label: String,
        actionKeypath: String,
        payload: ValueType
    ) -> ValueType {
        .object([
            "selectionBadge": .string(badge),
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(note),
            "keypath": .string("agendaSnapshot.dispatchAction"),
            "label": .string(label),
            "payload": .object([
                "keypath": .string(actionKeypath),
                "payload": payload
            ])
        ])
    }

    private func focusedActionCards() -> [ValueType] {
        [
            agendaActionCard(
                title: "For deg",
                subtitle: activeView == "forYou" ? "Vises nå" : "Anbefalte sesjoner først",
                detail: "Bruk denne når du vil se de mest relevante sesjonene for deg akkurat nå.",
                note: activeView == "forYou"
                    ? "For deg er aktiv. Herfra er neste steg å velge en sesjon eller fokusere et spor."
                    : "Bytter tilbake til den anbefalte deltageragendaen.",
                label: activeView == "forYou" ? "Viser nå" : "Vis for deg",
                actionKeypath: "agenda.setView",
                payload: .object(["view": .string("forYou")])
            ),
            agendaActionCard(
                title: "Timeline",
                subtitle: activeView == "timeline" ? "Vises nå" : "Hele programmet i rekkefølge",
                detail: "Bruk denne når du vil se hele programflyten og orientere deg i konferansen.",
                note: activeView == "timeline"
                    ? "Timeline er aktiv. Nå ser du hele programmet i rekkefølge."
                    : "Bytter til den fulle tidslinjen for konferansen.",
                label: activeView == "timeline" ? "Viser nå" : "Vis timeline",
                actionKeypath: "agenda.setView",
                payload: .object(["view": .string("timeline")])
            ),
            agendaActionCard(
                title: "Lagret",
                subtitle: activeView == "saved" ? "Vises nå" : "Bare sesjonene du har lagret",
                detail: "Bruk denne når du vil se bare det du allerede har valgt å ta vare på.",
                note: activeView == "saved"
                    ? "Lagret er aktiv. Nå ser du bare det du allerede har valgt."
                    : "Bytter til kun lagrede sesjoner.",
                label: activeView == "saved" ? "Viser nå" : "Vis lagret",
                actionKeypath: "agenda.setView",
                payload: .object(["view": .string("saved")])
            ),
            agendaActionCard(
                title: activeTrackID == "track-governance" ? "Alle spor" : "Governance",
                subtitle: activeTrackID == "track-governance" ? "Slå av spor-fokus" : "Sett governance i fokus",
                detail: activeTrackID == "track-governance"
                    ? "Bruk denne når du vil gå tilbake til alle spor igjen."
                    : "Bruk denne når du vil se hva som er mest relevant innen governance.",
                note: activeTrackID == "track-governance"
                    ? "Governance er allerede fokusert. Neste steg er ofte å åpne timeline eller gå tilbake til alle spor."
                    : "Setter governance i fokus uten å forlate siden.",
                label: activeTrackID == "track-governance" ? "Vis alle spor" : "Fokuser governance",
                actionKeypath: "agenda.setTrackFocus",
                payload: .object(["trackId": .string(activeTrackID == "track-governance" ? "all" : "track-governance")])
            )
        ]
    }

    private func agendaActionCard(
        title: String,
        subtitle: String,
        detail: String,
        note: String,
        label: String,
        actionKeypath: String,
        payload: ValueType
    ) -> ValueType {
        .object([
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(note),
            "keypath": .string("agendaSnapshot.dispatchAction"),
            "label": .string(label),
            "payload": .object([
                "keypath": .string(actionKeypath),
                "payload": payload
            ])
        ])
    }

    private func trackOptionCard(from raw: Object) -> ValueType {
        let title = cardTitle(from: raw)
        let subtitle = cardSubtitle(from: raw)
        let detail = cardDetail(from: raw)
        let trackID = trackID(forTitle: title)
        let note: String
        if trackID == activeTrackID {
            note = "Aktivt fokus nå."
        } else if activeTrackID == "all" {
            note = "Tilgjengelig for fokus."
        } else {
            note = "Tilgjengelig, men ikke i aktivt fokus nå."
        }
        let selectionBadge = trackID == activeTrackID ? "AKTIVT FOKUS" : "SPOR"

        return .object([
            "selectionBadge": .string(selectionBadge),
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(note)
        ])
    }

    private enum SessionCategory {
        case recommended
        case saved
        case timeline
    }

    private func sessionCard(from raw: Object, category: SessionCategory) -> ValueType {
        let title = cardTitle(from: raw)
        let subtitle = cardSubtitle(from: raw)
        let detail = cardDetail(from: raw)
        let note = sessionNote(baseNote: cardNote(from: raw), category: category)
        let selectionBadge = sessionBadge(for: category)

        return .object([
            "selectionBadge": .string(selectionBadge),
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(note)
        ])
    }

    private func sessionBadge(for category: SessionCategory) -> String {
        switch category {
        case .recommended:
            return activeView == "forYou" ? "VISES NÅ" : "FOR DEG"
        case .saved:
            return activeView == "saved" ? "VISES NÅ" : "LAGRET"
        case .timeline:
            return activeView == "timeline" ? "VISES NÅ" : "TIMELINE"
        }
    }

    private func sessionNote(baseNote: String, category: SessionCategory) -> String {
        switch category {
        case .recommended:
            return activeView == "forYou" ? "\(baseNote) · Vises nå i For deg." : "\(baseNote) · Klar når du går til For deg."
        case .saved:
            return activeView == "saved" ? "\(baseNote) · Vises nå i Lagret." : "\(baseNote) · Klar når du åpner Lagret."
        case .timeline:
            return activeView == "timeline" ? "\(baseNote) · Vises nå i Timeline." : "\(baseNote) · Klar når du åpner Timeline."
        }
    }

    private func visibleSessionCount(recommendedCount: Int, savedCount: Int, timelineCount: Int) -> Int {
        switch activeView {
        case "timeline":
            return timelineCount
        case "saved":
            return savedCount
        default:
            return recommendedCount
        }
    }

    private func statusSummary(for view: String, trackID: String) -> String {
        switch (view, trackID) {
        case ("timeline", "track-governance"):
            return "Viser timeline med governance i fokus."
        case ("timeline", _):
            return "Viser timeline med alle spor tilgjengelige."
        case ("saved", "track-governance"):
            return "Viser lagrede sesjoner med governance i fokus."
        case ("saved", _):
            return "Viser bare lagrede sesjoner akkurat nå."
        case (_, "track-governance"):
            return "Viser anbefalte sesjoner med governance i fokus."
        default:
            return "Viser anbefalte sesjoner med alle spor tilgjengelige."
        }
    }

    private func nextStepSummary(for view: String, trackID: String) -> String {
        switch (view, trackID) {
        case ("timeline", "track-governance"):
            return "Neste steg er å velge en governance-sesjon eller slå av spor-fokus for å se hele bredden igjen."
        case ("timeline", _):
            return "Neste steg er å velge en sesjon fra timeline eller fokusere et spor for å snevre inn oversikten."
        case ("saved", _):
            return "Neste steg er å bekrefte hva du faktisk vil delta på, eller gå tilbake til For deg for nye forslag."
        case (_, "track-governance"):
            return "Neste steg er å se hvilke governance-sesjoner som nå er mest relevante, eller åpne timeline for mer kontekst."
        default:
            return "Neste steg er å velge en anbefalt sesjon, åpne timeline, eller fokusere governance hvis du vil snevre inn."
        }
    }

    private func timelineSummaryText(for view: String, visibleCount: Int) -> String {
        switch view {
        case "timeline":
            return "\(visibleCount) sesjoner vises i timeline akkurat nå."
        case "saved":
            return "\(visibleCount) lagrede sesjoner vises akkurat nå."
        default:
            return "\(visibleCount) anbefalte sesjoner vises akkurat nå."
        }
    }

    private func trackSelectionLabel(_ trackID: String) -> String {
        trackID == "all" ? "alle spor synlige" : "\(trackLabel(trackID)) i fokus"
    }

    private func actionSummaryForView(_ view: String) -> String {
        switch view {
        case "timeline":
            return "Viser timeline i denne siden."
        case "saved":
            return "Viser lagrede sesjoner i denne siden."
        default:
            return "Viser anbefalte sesjoner for deg i denne siden."
        }
    }

    private func actionSummaryForTrack(_ trackID: String) -> String {
        trackID == "all"
            ? "Viser alle spor igjen."
            : "Governance er nå i fokus i denne siden."
    }

    private func viewLabel(_ view: String) -> String {
        switch normalizedView(view) {
        case "timeline": return "Timeline"
        case "saved": return "Lagret"
        default: return "For deg"
        }
    }

    private func trackLabel(_ trackID: String) -> String {
        switch normalizedTrackID(trackID) {
        case "track-governance":
            return "Governance"
        case "track-identity":
            return "Identity"
        default:
            return "alle spor"
        }
    }

    private func normalizedView(_ view: String) -> String {
        let normalized = view.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "timeline":
            return "timeline"
        case "saved":
            return "saved"
        default:
            return "forYou"
        }
    }

    private func normalizedTrackID(_ trackID: String) -> String {
        let normalized = trackID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "track-governance", "governance":
            return "track-governance"
        case "track-identity", "identity":
            return "track-identity"
        default:
            return "all"
        }
    }

    private func inferredView(from summary: String) -> String {
        let normalized = summary.lowercased()
        if normalized.contains("timeline") {
            return "timeline"
        }
        if normalized.contains("lagret") || normalized.contains("saved") {
            return "saved"
        }
        return "forYou"
    }

    private func inferredTrackID(from summary: String) -> String {
        let normalized = summary.lowercased()
        if normalized.contains("governance") {
            return "track-governance"
        }
        if normalized.contains("identity") {
            return "track-identity"
        }
        return "all"
    }

    private func trackID(forTitle title: String) -> String {
        let normalized = title.lowercased()
        if normalized.contains("governance") {
            return "track-governance"
        }
        if normalized.contains("identity") {
            return "track-identity"
        }
        return "all"
    }

    private func cardTitle(from object: Object) -> String {
        string(from: object["title"]) ?? "Ukjent kort"
    }

    private func cardSubtitle(from object: Object) -> String {
        string(from: object["subtitle"]) ?? "Ingen undertittel"
    }

    private func cardDetail(from object: Object) -> String {
        string(from: object["detail"]) ?? "Ingen detalj tilgjengelig."
    }

    private func cardNote(from object: Object) -> String {
        string(from: object["note"]) ?? "Ingen ekstra agenda-kontekst tilgjengelig ennå."
    }

    private func listObjects(from value: ValueType?) -> [Object] {
        guard case let .list(values)? = value else { return [] }
        return values.compactMap {
            guard case let .object(object) = $0 else { return nil }
            return object
        }
    }

    private func mutationErrorDescription(from value: ValueType?) -> String? {
        guard let value else { return "Ukjent agenda-feil." }
        switch value {
        case let .string(string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return nil }
            if trimmed == "denied" || trimmed.hasPrefix("error:") || trimmed.hasPrefix("failure") {
                return trimmed
            }
            return nil
        case let .object(object):
            if case let .string(status)? = object["status"],
               status == "error",
               let message = string(from: object["message"]) {
                return message
            }
            return nil
        default:
            return nil
        }
    }

    private func string(from value: ValueType?) -> String? {
        guard let value else { return nil }
        switch value {
        case let .string(string):
            return string
        case let .integer(integer):
            return String(integer)
        case let .number(number):
            return String(number)
        case let .float(float):
            return String(float)
        case let .bool(bool):
            return bool ? "true" : "false"
        default:
            return nil
        }
    }

    private static func agendaStateWithStatus(
        basedOn base: Object,
        status: String,
        actionSummary: String
    ) -> Object {
        var updated = base
        updated["status"] = .string(status)
        updated["statusSummary"] = .string(status)
        updated["actionSummary"] = .string(actionSummary)
        updated["nextStepSummary"] = .string(actionSummary)
        return updated
    }

    private static func agendaStateWithSyncWarning(
        basedOn base: Object,
        storageSummary: String,
        persistenceStatus: String
    ) -> Object {
        var updated = base
        updated["storageSummary"] = .string(storageSummary)
        updated["persistenceStatus"] = .string(persistenceStatus)
        return updated
    }

    private static func defaultAgendaState() -> Object {
        [
            "intro": .string("Velg hvordan agendaen skal vises. Oppsummeringene under forklarer alltid hvilken visning og hvilket fokus som er aktivt akkurat nå."),
            "agendaSummary": .string("2 lagrede sesjoner · 6 anbefalte sesjoner."),
            "viewSummary": .string("Aktiv visning: For deg."),
            "trackSummary": .string("Aktivt spor: alle spor er synlige."),
            "timelineSummary": .string("3 anbefalte sesjoner vises akkurat nå."),
            "status": .string("Viser anbefalte sesjoner med alle spor tilgjengelige."),
            "storageSummary": .string("Agenda-valg holdes stabile i deltagerportalen og speiles tilbake i denne siden."),
            "persistenceStatus": .string("Valgene dine blir husket lokalt, så siden ikke hopper når du bytter visning."),
            "recommendedSummary": .string("3 anbefalte sesjoner er klare når du bruker For deg."),
            "savedSummary": .string("2 lagrede sesjoner er klare når du åpner Lagret."),
            "statusSummary": .string("Viser anbefalte sesjoner med alle spor tilgjengelige."),
            "selectionSummary": .string("Viser for deg med alle spor synlige."),
            "navigationSummary": .string("Knappene over bytter visning i denne siden med en gang. Handlingskortene under forklarer hva hver visning gjør."),
            "nextStepSummary": .string("Neste steg er å velge en anbefalt sesjon, åpne timeline, eller fokusere governance hvis du vil snevre inn."),
            "actionSummary": .string("Velg hvordan agendaen skal vises. Endringen skjer i denne siden med en gang."),
            "trackOptions": .list([
                .object([
                    "title": .string("Applied AI"),
                    "subtitle": .string("4 sesjoner"),
                    "detail": .string("Praktiske AI-systemer og verktøy."),
                    "note": .string("Tilgjengelig for fokus.")
                ]),
                .object([
                    "title": .string("Identity"),
                    "subtitle": .string("4 sesjoner"),
                    "detail": .string("Tillit, verifikasjon og claims."),
                    "note": .string("Tilgjengelig for fokus.")
                ]),
                .object([
                    "title": .string("Governance"),
                    "subtitle": .string("4 sesjoner"),
                    "detail": .string("Policy, regulering og koordinering."),
                    "note": .string("Tilgjengelig for fokus.")
                ])
            ]),
            "recommendedSessions": .list([
                .object([
                    "title": .string("Identity Session 8"),
                    "subtitle": .string("Identity · 09:30-10:00"),
                    "detail": .string("Forum: identity, AI and digital independence."),
                    "note": .string("Matches interests")
                ]),
                .object([
                    "title": .string("Governance Session 15"),
                    "subtitle": .string("Governance · 10:00-10:30"),
                    "detail": .string("Library: governance, AI and digital independence."),
                    "note": .string("Visible in current view")
                ]),
                .object([
                    "title": .string("Infra Session 3"),
                    "subtitle": .string("Infra · 13:00-13:30"),
                    "detail": .string("Shared infrastructure and deployment patterns."),
                    "note": .string("Recommended next")
                ])
            ]),
            "savedSessions": .list([
                .object([
                    "title": .string("Opening keynote"),
                    "subtitle": .string("Main stage · 08:30"),
                    "detail": .string("Framing digital independence across sectors."),
                    "note": .string("Saved")
                ]),
                .object([
                    "title": .string("Shared relations roundtable"),
                    "subtitle": .string("Studio 2 · 11:15"),
                    "detail": .string("Operational follow-up between ecosystem teams."),
                    "note": .string("Saved")
                ])
            ]),
            "timelineSessions": .list([
                .object([
                    "title": .string("Governance Session 3"),
                    "subtitle": .string("Studio 2 · 08:00"),
                    "detail": .string("Governance, AI and digital independence."),
                    "note": .string("Visible in timeline")
                ]),
                .object([
                    "title": .string("Identity Session 2"),
                    "subtitle": .string("Hall B · 08:30"),
                    "detail": .string("Identity, AI and digital independence."),
                    "note": .string("Visible in timeline")
                ]),
                .object([
                    "title": .string("Governance Session 9"),
                    "subtitle": .string("Bridge · 09:00"),
                    "detail": .string("Cross-team governance patterns."),
                    "note": .string("Visible in timeline")
                ])
            ]),
            "focusedActions": .list([])
        ]
    }
}

@MainActor
private final class ConferenceParticipantDiscoverySnapshotLocalCell: GeneralCell {
    private var cachedDiscoveryState: Object = ConferenceParticipantDiscoverySnapshotLocalCell.defaultDiscoveryState()
    private var lastRefreshAt: Date?
    private var refreshTask: Task<Void, Never>?
    private var storeKey = ""
    private var focusedDiscoveryName: String?
    private var followUpMarkedNames: Set<String> = []
    private var launchedDiscoveryChatNames: [String] = []
    private var recentActionSummary = "Trykk Vis i siden for å fokusere på en person i discovery."

    required init(owner: Identity) async {
        await super.init(owner: owner)
        await configure(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        fatalError("ConferenceParticipantDiscoverySnapshotLocalCell does not support decoding")
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private func configure(owner: Identity) async {
        storeKey = owner.uuid
        await restoreSelectedParticipantIfAvailable()
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("rw--", for: "refresh")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")

        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("r---", at: "state", for: requester) else { return .string("denied") }
            await self.refreshSnapshotIfNeeded(force: false, forwardAction: nil, requester: requester)
            return .object(self.cachedDiscoveryState)
        })

        await addInterceptForSet(requester: owner, key: "refresh", setValueIntercept: { [weak self] _, _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "refresh", for: requester) else { return .string("denied") }
            let refreshPayload: ValueType = .object([
                "keypath": .string("discovery.refresh"),
                "payload": .bool(true)
            ])
            await self.refreshSnapshotIfNeeded(force: true, forwardAction: refreshPayload, requester: requester)
            return .object([
                "status": .string("ok"),
                "state": .object(self.cachedDiscoveryState)
            ])
        })

        await addInterceptForSet(requester: owner, key: "dispatchAction", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "dispatchAction", for: requester) else { return .string("denied") }
            return await self.handleDispatchAction(value, requester: requester)
        })

        Task { [weak self] in
            guard let self else { return }
            await self.refreshSnapshotIfNeeded(force: true, forwardAction: nil, requester: owner)
        }
    }

    private func handleDispatchAction(_ value: ValueType, requester: Identity) async -> ValueType {
        guard case let .object(object) = value,
              let actionKeypath = string(from: object["keypath"]),
              actionKeypath.isEmpty == false else {
            cachedDiscoveryState = Self.discoveryStateWithStatus(
                basedOn: cachedDiscoveryState,
                status: "Discovery-handlingen mangler keypath.",
                actionSummary: "Kunne ikke oppdatere discovery fordi action-payloaden var ugyldig."
            )
            return .object([
                "status": .string("error"),
                "state": .object(cachedDiscoveryState)
            ])
        }

        let payload = object["payload"] ?? .null
        var forwardedAction: ValueType?

        switch actionKeypath {
        case "refresh", "discovery.refresh":
            recentActionSummary = "Oppdaterte discovery-snapshotet."
            forwardedAction = .object([
                "keypath": .string("discovery.refresh"),
                "payload": .bool(true)
            ])
        case "discovery.focusPerson":
            if case let .object(personObject) = payload,
               let displayName = string(from: personObject["displayName"])?.trimmingCharacters(in: .whitespacesAndNewlines),
               displayName.isEmpty == false {
                focusedDiscoveryName = displayName
                await rememberSelectedParticipant(displayName)
                recentActionSummary = "Viser \(displayName) i discovery-delen."
            }
        case "matchmaking.toggleFollowUp":
            if case let .object(personObject) = payload,
               let displayName = string(from: personObject["displayName"])?.trimmingCharacters(in: .whitespacesAndNewlines),
               displayName.isEmpty == false {
                focusedDiscoveryName = displayName
                await rememberSelectedParticipant(displayName)
                if followUpMarkedNames.contains(displayName) {
                    followUpMarkedNames.remove(displayName)
                    recentActionSummary = "Fjernet \(displayName) fra oppfølging."
                } else {
                    followUpMarkedNames.insert(displayName)
                    recentActionSummary = "Markerte \(displayName) for oppfølging."
                }
                forwardedAction = .object([
                    "keypath": .string(actionKeypath),
                    "payload": payload
                ])
            }
        case "discovery.startChat":
            let targetNames = discoveryTargetNames(from: payload)
            if let firstTarget = targetNames.first {
                focusedDiscoveryName = firstTarget
                await rememberSelectedParticipant(firstTarget)
                recentActionSummary = "Starter chat med \(firstTarget) fra discovery…"
            } else {
                recentActionSummary = "Starter chat fra discovery…"
            }
            forwardedAction = .object([
                "keypath": .string(actionKeypath),
                "payload": payload
            ])
        case "scheduling.createMeetingRequest":
            if let focusedDiscoveryName {
                recentActionSummary = "La til møteforespørsel for \(focusedDiscoveryName)."
            } else {
                recentActionSummary = "La til en ny møteforespørsel fra discovery."
            }
            forwardedAction = .object([
                "keypath": .string(actionKeypath),
                "payload": payload
            ])
        case "discovery.startGroupChat":
            recentActionSummary = "Startet gruppesamtale fra discovery."
            forwardedAction = .object([
                "keypath": .string(actionKeypath),
                "payload": payload
            ])
        default:
            recentActionSummary = "Utførte \(actionKeypath) i discovery-snapshotet."
            forwardedAction = .object([
                "keypath": .string(actionKeypath),
                "payload": payload
            ])
        }

        cachedDiscoveryState = mergedDiscoveryState(from: cachedDiscoveryState)
        await refreshSnapshotIfNeeded(force: true, forwardAction: forwardedAction, requester: requester)
        return .object([
            "status": .string("ok"),
            "state": .object(cachedDiscoveryState)
        ])
    }

    private func refreshSnapshotIfNeeded(
        force: Bool,
        forwardAction: ValueType?,
        requester: Identity
    ) async {
        let shouldRetryImmediately = ConferenceSnapshotRetrySupport.shouldRetryImmediately(
            cachedState: cachedDiscoveryState,
            statusKeys: ["status", "actionSummary", "sourceSummary"]
        )

        if !force,
           !shouldRetryImmediately,
           let lastRefreshAt,
           Date().timeIntervalSince(lastRefreshAt) < 1 {
            return
        }

        if let refreshTask {
            await refreshTask.value
            let shouldRetryAfterInflight = ConferenceSnapshotRetrySupport.shouldRetryImmediately(
                cachedState: cachedDiscoveryState,
                statusKeys: ["status", "actionSummary", "sourceSummary"]
            )
            if !force && !shouldRetryAfterInflight {
                return
            }
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performRefresh(
                forwardAction: forwardAction,
                requester: requester
            )
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    @MainActor
    private func performRefresh(
        forwardAction: ValueType?,
        requester: Identity
    ) async {
        guard await BindingLocalCellRegistration.shared.ensureConferenceDemoRuntimeReady() else {
            cachedDiscoveryState = Self.discoveryStateWithStatus(
                basedOn: cachedDiscoveryState,
                status: "Discovery bruker siste lokale snapshot fordi runtime-validering feilet.",
                actionSummary: "Kunne ikke oppdatere discovery akkurat nå."
            )
            lastRefreshAt = Date()
            return
        }

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            cachedDiscoveryState = Self.discoveryStateWithStatus(
                basedOn: cachedDiscoveryState,
                status: "Discovery bruker siste lokale snapshot fordi resolver mangler.",
                actionSummary: "Kunne ikke oppdatere discovery akkurat nå."
            )
            lastRefreshAt = Date()
            return
        }

        guard let previewShell = try? await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: requester
        ) as? Meddle else {
            cachedDiscoveryState = Self.discoveryStateWithStatus(
                basedOn: cachedDiscoveryState,
                status: "Discovery bruker siste lokale snapshot fordi ingen preview-shell er tilgjengelig.",
                actionSummary: "Kunne ikke oppdatere discovery akkurat nå."
            )
            lastRefreshAt = Date()
            return
        }

        if let forwardAction {
            let mutationResult = try? await previewShell.set(
                keypath: "dispatchAction",
                value: forwardAction,
                requester: requester
            )
            if let errorDescription = mutationErrorDescription(from: mutationResult) {
                cachedDiscoveryState = Self.discoveryStateWithStatus(
                    basedOn: cachedDiscoveryState,
                    status: "Discovery beholdt siste stabile snapshot fordi preview-handlingen feilet.",
                    actionSummary: errorDescription
                )
            }
        }

        do {
            let stateValue = try await previewShell.get(
                keypath: "state",
                requester: requester
            )
            guard case let .object(stateObject) = stateValue,
                  case let .object(discoveryObject)? = stateObject["discovery"] else {
                cachedDiscoveryState = Self.discoveryStateWithStatus(
                    basedOn: cachedDiscoveryState,
                    status: "Discovery returnerte ikke et lesbart preview-snapshot.",
                    actionSummary: "Bruker siste stabile data."
                )
                lastRefreshAt = Date()
                return
            }

            let sharedConnections = conferenceObject(from: stateObject["sharedConnections"])
            synchronizeLaunchedChats(
                from: sharedConnections,
                forwardedAction: forwardAction
            )

            var mergedDiscovery = mergedDiscoveryState(from: discoveryObject)
            mergedDiscovery["sourceSummary"] = .string("Discovery bruker lokal preview i HAVEN for å holde deltagerportalen stabil mens øvrige data kobler seg til.")
            cachedDiscoveryState = mergedDiscovery
            lastRefreshAt = Date()
        } catch {
            cachedDiscoveryState = Self.discoveryStateWithStatus(
                basedOn: cachedDiscoveryState,
                status: "Discovery bruker siste stabile snapshot.",
                actionSummary: "Kunne ikke hente oppdatert discovery akkurat nå: \(error)"
            )
            lastRefreshAt = Date()
        }
    }

    private func synchronizeLaunchedChats(
        from sharedConnections: Object?,
        forwardedAction: ValueType?
    ) {
        let sharedNames = conferenceSharedConnectionNames(from: sharedConnections)
        launchedDiscoveryChatNames = sharedNames

        guard conferenceActionKeypath(from: forwardedAction) == "discovery.startChat" else {
            return
        }

        let targetNames = discoveryTargetNames(from: conferenceActionPayload(from: forwardedAction) ?? .null)
        guard let firstTarget = targetNames.first else {
            return
        }

        if sharedNames.contains(firstTarget) {
            recentActionSummary = "Chatten med \(firstTarget) er klar."
        } else {
            recentActionSummary = "Chatten med \(firstTarget) ble ikke klar ennå. Prøv Start chat igjen."
        }
    }

    private func mergedDiscoveryState(from object: Object) -> Object {
        var merged = Self.defaultDiscoveryState()
        for (key, value) in object {
            merged[key] = value
        }

        let candidateRows = listObjects(from: merged["candidates"])
        let proofCandidateRows = listObjects(from: merged["proofCandidates"])
        let groupRows = listObjects(from: merged["groupSuggestions"])
        let derivedCandidates = candidateRows.map { discoveryCandidateCard(from: $0) }
        let derivedProofCandidates = proofCandidateRows.map { discoveryCandidateCard(from: $0) }
        let derivedGroupSuggestions = groupRows.map { groupSuggestionCard(from: $0) }
        let focusedCard = focusedDiscoveryCard(
            candidates: candidateRows,
            proofCandidates: proofCandidateRows
        )

        merged["candidates"] = .list(derivedCandidates)
        merged["proofCandidates"] = .list(derivedProofCandidates)
        merged["groupSuggestions"] = .list(derivedGroupSuggestions)
        merged["statusSummary"] = .string(statusSummary(for: candidateRows, proofCandidates: proofCandidateRows))
        merged["selectionSummary"] = .string(selectionSummary(for: focusedCard))
        merged["navigationSummary"] = .string(navigationSummary(for: focusedCard))
        merged["nextStepSummary"] = .string(nextStepSummary(for: focusedCard))
        merged["actionSummary"] = .string(recentActionSummary)
        merged["focusedProfile"] = .object(focusedProfileObject(from: focusedCard, publicProfileSummary: string(from: merged["publicProfileSummary"])))
        merged["focusedActions"] = .list(focusedActionCards(for: focusedCard))

        if string(from: merged["status"])?.isEmpty != false {
            merged["status"] = .string("Discovery er klar for oppfølging.")
        }
        if string(from: merged["refreshSummary"])?.isEmpty != false {
            merged["refreshSummary"] = .string("Discovery-snapshotet er oppdatert lokalt.")
        }

        return merged
    }

    private func discoveryCandidateCard(from raw: Object) -> ValueType {
        let title = cardTitle(from: raw)
        let subtitle = cardSubtitle(from: raw)
        let detail = cardDetail(from: raw)
        let baseNote = cardNote(from: raw)
        let isFocused = focusedDiscoveryName == title
        let chatReady = launchedDiscoveryChatNames.contains(title)
        let label = isFocused ? (chatReady ? "Åpne chatflate" : "Start chat") : "Vis i siden"
        let actionKeypath = isFocused
            ? (chatReady ? "openChatWorkbench" : "discovery.startChat")
            : "discovery.focusPerson"
        let note: String
        if isFocused {
            note = chatReady ? "\(baseNote) · Chat klar i egen flate." : "\(baseNote) · Vises i discovery nå."
        } else {
            note = "\(baseNote) · Trykk Vis i siden for å fokusere."
        }

        let payload: ValueType = isFocused
            ? (chatReady
                ? .object([
                    "displayName": .string(title),
                    "subtitle": .string(subtitle)
                ])
                : discoveryChatPayload(for: title, subtitle: subtitle))
            : .object([
                "displayName": .string(title),
                "subtitle": .string(subtitle)
            ])

        return .object([
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(note),
            "demoPersona": raw["demoPersona"] ?? .object(conferenceDemoPersonaSeedObject(named: title)),
            "keypath": .string(isFocused && chatReady ? "chatSnapshot.dispatchAction" : "discoverySnapshot.dispatchAction"),
            "label": .string(label),
            "payload": .object([
                "keypath": .string(actionKeypath),
                "payload": payload
            ])
        ])
    }

    private func groupSuggestionCard(from raw: Object) -> ValueType {
        let title = cardTitle(from: raw)
        let subtitle = cardSubtitle(from: raw)
        let detail = cardDetail(from: raw)
        let note = "\(cardNote(from: raw)) · Åpner gruppesamtale når gruppen er klar."
        return .object([
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(note),
            "keypath": .string("discoverySnapshot.dispatchAction"),
            "label": .string("Start gruppesamtale"),
            "payload": .object([
                "keypath": .string("discovery.startGroupChat"),
                "payload": .object([
                    "source": .string("binding-discovery-snapshot"),
                    "targets": .list([
                        .object([
                            "displayName": .string(title),
                            "headline": .string(subtitle)
                        ])
                    ])
                ])
            ])
        ])
    }

    private func statusSummary(for candidates: [Object], proofCandidates: [Object]) -> String {
        if candidates.isEmpty && proofCandidates.isEmpty {
            return "Ingen discovery-kandidater er klare ennå."
        }
        return "\(candidates.count) åpne kandidater og \(proofCandidates.count) proof-klare kandidater er klare for gjennomgang."
    }

    private func selectionSummary(for focusedCard: Object?) -> String {
        guard let focusedCard else {
            return "Trykk Vis i siden på en discovery-kandidat for å fokusere på personen her."
        }
        return "Viser \(cardTitle(from: focusedCard)) i discovery-delen."
    }

    private func navigationSummary(for focusedCard: Object?) -> String {
        if focusedCard == nil {
            return "Første klikk skjer i denne siden. Du trenger ikke åpne en egen arbeidsflate for å se hvem discovery-kortet gjelder."
        }
        return "Du ser nå valgt discovery-deltaker i denne siden. Herfra kan du starte chat, markere oppfølging eller be om møte."
    }

    private func nextStepSummary(for focusedCard: Object?) -> String {
        guard let focusedCard else {
            return "Velg en discovery-kandidat med Vis i siden før du tar neste steg."
        }
        let title = cardTitle(from: focusedCard)
        if launchedDiscoveryChatNames.contains(title) {
            return "Chatten med \(title) er klar. Neste steg er å åpne chatten eller be om møte."
        }
        if followUpMarkedNames.contains(title) {
            return "\(title) er markert for oppfølging. Neste steg er å starte chat eller be om møte."
        }
        return "Neste steg for \(title) er å starte chat, markere oppfølging eller be om møte."
    }

    private func focusedProfileObject(from focusedCard: Object?, publicProfileSummary: String?) -> Object {
        let publicSummary = publicProfileSummary ?? "Bare minimal offentlig profil vises til du ber om mer."
        guard let focusedCard else {
            return [
                "selectionBadge": .string("VALGT I DISCOVERY"),
                "title": .string("Ingen deltaker valgt ennå"),
                "subtitle": .string("Entity Discovery"),
                "detail": .string("Trykk Vis i siden på en discovery-kandidat for å se personens offentlige og lokale oppsummering her."),
                "note": .string(publicSummary),
                "publicProfileSummary": .string(publicSummary),
                "profileDetail": .string("Vi viser offentlig profil, lokal begrunnelse og neste steg når en kandidat er valgt."),
                "fitSummary": .string("Ingen discovery-kandidat er valgt ennå."),
                "nextStep": .string("Velg en kandidat først, og bruk deretter chat, oppfølging eller møte."),
                "conversationStyle": .string("Når en kandidat er valgt, viser vi hvordan demo-personaen typisk svarer i chat."),
                "openingPrompt": .string("Velg en kandidat først for å se et godt forslag til åpningsmelding."),
                "simulationSummary": .string("Demo-svarene er bounded og følger valgt deltagerprofil.")
            ]
        }

        let persona = conferenceDemoPersona(named: cardTitle(from: focusedCard), source: focusedCard)
        return [
            "selectionBadge": .string("VALGT I DISCOVERY"),
            "title": .string(cardTitle(from: focusedCard)),
            "subtitle": .string(cardSubtitle(from: focusedCard)),
            "detail": .string(cardDetail(from: focusedCard)),
            "note": .string("\(cardNote(from: focusedCard)) · \(publicSummary)"),
            "publicProfileSummary": .string(publicSummary),
            "profileDetail": .string("Offentlig profil: \(cardSubtitle(from: focusedCard)). \(cardDetail(from: focusedCard)) \(persona.publicProfileDetail)"),
            "fitSummary": .string(cardNote(from: focusedCard)),
            "nextStep": .string("Bruk Start chat, Marker for oppfølging eller Be om møte med \(cardTitle(from: focusedCard))."),
            "conversationStyle": .string(persona.conversationStyle),
            "openingPrompt": .string(persona.suggestedOpening),
            "simulationSummary": .string(persona.simulatedAgentSummary)
        ]
    }

    private func focusedActionCards(for focusedCard: Object?) -> [ValueType] {
        guard let focusedCard else { return [] }
        let title = cardTitle(from: focusedCard)
        let subtitle = cardSubtitle(from: focusedCard)
        let chatReady = launchedDiscoveryChatNames.contains(title)
        let followUpMarked = followUpMarkedNames.contains(title)

        let chatAction: ValueType = .object([
            "title": .string("Chat"),
            "subtitle": .string(chatReady ? "Fortsett discovery-chatten" : "Start discovery-chat"),
            "detail": .string(chatReady ? "Åpne chatflaten med \(title) og fortsett oppfølgingen." : "Start en discovery-chat med \(title) fra denne siden."),
            "note": .string("Dette er det tydeligste neste steget når discovery-kandidaten virker lovende."),
            "keypath": .string(chatReady ? "chatSnapshot.dispatchAction" : "discoverySnapshot.dispatchAction"),
            "label": .string(chatReady ? "Åpne chatflate" : "Start chat"),
            "payload": .object([
                "keypath": .string(chatReady ? "openChatWorkbench" : "discovery.startChat"),
                "payload": chatReady
                    ? .object([
                        "displayName": .string(title),
                        "subtitle": .string(subtitle)
                    ])
                    : discoveryChatPayload(for: title, subtitle: subtitle)
            ])
        ])

        let followUpAction: ValueType = .object([
            "title": .string("Oppfølging"),
            "subtitle": .string(followUpMarked ? "Allerede markert" : "Marker neste steg"),
            "detail": .string(followUpMarked ? "\(title) er markert for oppfølging." : "Marker \(title) for oppfølging så discovery-sporet blir lett å komme tilbake til."),
            "note": .string("Bruk dette når du vil holde fast i kandidaten uten å starte chat med en gang."),
            "keypath": .string("discoverySnapshot.dispatchAction"),
            "label": .string(followUpMarked ? "Fjern markering" : "Marker for oppfølging"),
            "payload": .object([
                "keypath": .string("matchmaking.toggleFollowUp"),
                "payload": .object([
                    "displayName": .string(title),
                    "subtitle": .string(subtitle)
                ])
            ])
        ])

        let meetingAction: ValueType = .object([
            "title": .string("Møte"),
            "subtitle": .string("Foreslå et konkret neste steg"),
            "detail": .string("Be om møte med \(title) hvis du vil gå fra discovery til konkret plan."),
            "note": .string("Bra når du allerede vet at kandidaten er relevant og vil sette opp et faktisk møtetidspunkt."),
            "keypath": .string("discoverySnapshot.dispatchAction"),
            "label": .string("Be om møte"),
            "payload": .object([
                "keypath": .string("scheduling.createMeetingRequest"),
                "payload": .object([
                    "source": .string("binding-discovery-snapshot"),
                    "displayName": .string(title)
                ])
            ])
        ])

        return [chatAction, followUpAction, meetingAction]
    }

    private func focusedDiscoveryCard(candidates: [Object], proofCandidates: [Object]) -> Object? {
        guard let focusedDiscoveryName else { return nil }
        if let candidate = candidates.first(where: { cardTitle(from: $0) == focusedDiscoveryName }) {
            return candidate
        }
        if let proofCandidate = proofCandidates.first(where: { cardTitle(from: $0) == focusedDiscoveryName }) {
            return proofCandidate
        }
        return nil
    }

    private func listObjects(from value: ValueType?) -> [Object] {
        guard case let .list(values)? = value else { return [] }
        return values.compactMap {
            guard case let .object(object) = $0 else { return nil }
            return object
        }
    }

    private func restoreSelectedParticipantIfAvailable() async {
        guard focusedDiscoveryName == nil,
              !storeKey.isEmpty,
              let storedSelection = await ConferenceParticipantSelectionStore.shared.load(for: storeKey) else {
            return
        }
        focusedDiscoveryName = storedSelection
    }

    private func rememberSelectedParticipant(_ displayName: String?) async {
        guard !storeKey.isEmpty else { return }
        await ConferenceParticipantSelectionStore.shared.save(displayName, for: storeKey)
    }

    private func cardTitle(from object: Object) -> String {
        string(from: object["title"]) ??
        string(from: object["displayName"]) ??
        "Ukjent deltaker"
    }

    private func cardSubtitle(from object: Object) -> String {
        string(from: object["subtitle"]) ??
        string(from: object["headline"]) ??
        "Discovery-kandidat"
    }

    private func cardDetail(from object: Object) -> String {
        string(from: object["detail"]) ??
        "Ingen detalj tilgjengelig."
    }

    private func cardNote(from object: Object) -> String {
        string(from: object["note"]) ??
        "Ingen ekstra discovery-kontekst tilgjengelig ennå."
    }

    private func discoveryChatPayload(for title: String, subtitle: String) -> ValueType {
        .object([
            "source": .string("binding-discovery-snapshot"),
            "targets": .list([
                .object([
                    "displayName": .string(title),
                    "headline": .string(subtitle)
                ])
            ])
        ])
    }

    private func discoveryTargetNames(from payload: ValueType) -> [String] {
        guard case let .object(payloadObject) = payload else { return [] }
        if case let .list(targets)? = payloadObject["targets"] {
            let names = targets.compactMap { target -> String? in
                guard case let .object(targetObject) = target else { return nil }
                if let displayName = string(from: targetObject["displayName"])?.trimmingCharacters(in: .whitespacesAndNewlines),
                   displayName.isEmpty == false {
                    return displayName
                }
                if let participantId = string(from: targetObject["participantId"])?.trimmingCharacters(in: .whitespacesAndNewlines),
                   participantId.isEmpty == false {
                    return participantId
                }
                return nil
            }
            if names.isEmpty == false {
                return names
            }
        }
        if case let .list(participantIds)? = payloadObject["participantIds"] {
            return participantIds.compactMap { value in
                guard let raw = string(from: value) else { return nil }
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        }
        return []
    }

    private func mutationErrorDescription(from value: ValueType?) -> String? {
        conferenceMutationErrorDescription(from: value)
    }

    private func string(from value: ValueType?) -> String? {
        guard let value else { return nil }
        switch value {
        case let .string(string):
            return string
        case let .integer(integer):
            return String(integer)
        case let .number(number):
            return String(number)
        case let .float(float):
            return String(float)
        case let .bool(bool):
            return bool ? "true" : "false"
        default:
            return nil
        }
    }

    private static func discoveryStateWithStatus(
        basedOn base: Object,
        status: String,
        actionSummary: String
    ) -> Object {
        var updated = base
        updated["status"] = .string(status)
        updated["statusSummary"] = .string(status)
        updated["actionSummary"] = .string(actionSummary)
        updated["refreshSummary"] = .string(actionSummary)
        return updated
    }

    private static func defaultDiscoveryState() -> Object {
        [
            "intro": .string("Conference discovery combines portable participant discovery with local nearby enrichment."),
            "status": .string("Discovery-snapshotet varmer opp lokalt."),
            "alignmentSummary": .string("Portable og lokale discovery-signaler holdes samlet i ett stabilt snapshot."),
            "proofSummary": .string("Verifisert kontakt kan åpne for rikere purpose- og interest-matching."),
            "sourceSummary": .string("Vi bruker et lokalt cached snapshot så discovery-delen holder seg stabil mens live-data oppdateres."),
            "publicProfileSummary": .string("Bare minimal offentlig profil vises til du eksplisitt ber om mer."),
            "chatSummary": .string("0 discovery-chat(er) klare."),
            "nextAction": .string("Oppdater discovery, vurder lovende personer, og start en oppfølgingschat når det føles riktig."),
            "refreshSummary": .string("Forbereder første discovery-snapshot."),
            "statusSummary": .string("Discovery-snapshotet bruker en lokal startflate mens livedata kobler seg til."),
            "selectionSummary": .string("Trykk Vis i siden på en discovery-kandidat for å fokusere på personen her."),
            "navigationSummary": .string("Første klikk skjer i denne siden."),
            "nextStepSummary": .string("Velg en discovery-kandidat før du tar neste steg."),
            "actionSummary": .string("Trykk Vis i siden for å fokusere på en person i discovery."),
            "candidates": .list([
                .object([
                    "title": .string("Ane Solberg"),
                    "subtitle": .string("Public sector interoperability"),
                    "detail": .string("Strong alignment on governance, delivery, and shared trust patterns."),
                    "note": .string("Recommended")
                ]),
                .object([
                    "title": .string("Mads Hovden"),
                    "subtitle": .string("Policy and compliance"),
                    "detail": .string("Good match for claims, compliance, and organizer follow-up."),
                    "note": .string("Nearby-capable")
                ]),
                .object([
                    "title": .string("Lea Heger"),
                    "subtitle": .string("Digital service design"),
                    "detail": .string("Connects participant needs to service and product design decisions."),
                    "note": .string("Suggested follow-up")
                ])
            ]),
            "proofCandidates": .list([
                .object([
                    "title": .string("Shared Relations Forum"),
                    "subtitle": .string("Proof-backed discovery"),
                    "detail": .string("Participants who can expose stronger matching once contact is verified."),
                    "note": .string("Proof ready")
                ]),
                .object([
                    "title": .string("Trust Infrastructure Lab"),
                    "subtitle": .string("Policy and operations"),
                    "detail": .string("Good candidate set for deeper follow-up if you want more precision."),
                    "note": .string("Consent gated")
                ])
            ]),
            "groupSuggestions": .list([
                .object([
                    "title": .string("Identity and Governance Circle"),
                    "subtitle": .string("3 people"),
                    "detail": .string("A small group with overlapping agenda and meeting goals."),
                    "note": .string("Suggested group chat")
                ]),
                .object([
                    "title": .string("Applied AI Follow-up"),
                    "subtitle": .string("2 people"),
                    "detail": .string("Focused on practical AI systems, trust, and delivery."),
                    "note": .string("Suggested nearby cluster")
                ])
            ]),
            "focusedProfile": .object([
                "selectionBadge": .string("VALGT I DISCOVERY"),
                "title": .string("Ingen deltaker valgt ennå"),
                "subtitle": .string("Entity Discovery"),
                "detail": .string("Trykk Vis i siden på en discovery-kandidat for å se personens offentlige og lokale oppsummering her."),
                "note": .string("Bare minimal offentlig profil vises til du eksplisitt ber om mer.")
            ]),
            "focusedActions": .list([])
        ]
    }
}

@MainActor
private final class ConferenceParticipantMatchmakingSnapshotLocalCell: GeneralCell {
    private var cachedMatchmakingState: Object = ConferenceParticipantMatchmakingSnapshotLocalCell.defaultMatchmakingState()
    private var lastRefreshAt: Date?
    private var refreshTask: Task<Void, Never>?
    private var storeKey = ""
    private var focusedRecommendationName: String?
    private var followUpMarkedNames: Set<String> = []
    private var launchedChatNames: [String] = []
    private var recentActionSummary = "Velg Vis i siden for å fokusere på en anbefalt deltaker her."

    required init(owner: Identity) async {
        await super.init(owner: owner)
        await configure(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        fatalError("ConferenceParticipantMatchmakingSnapshotLocalCell does not support decoding")
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private func configure(owner: Identity) async {
        storeKey = owner.uuid
        await restoreSelectedParticipantIfAvailable()
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("rw--", for: "refresh")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")

        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("r---", at: "state", for: requester) else { return .string("denied") }
            await self.refreshSnapshotIfNeeded(force: false, forwardAction: nil, requester: requester)
            return .object(self.cachedMatchmakingState)
        })

        await addInterceptForSet(requester: owner, key: "refresh", setValueIntercept: { [weak self] _, _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "refresh", for: requester) else { return .string("denied") }
            let payload: Object = [
                "keypath": .string("matchmaking.refreshRecommendations"),
                "payload": .bool(true)
            ]
            await self.refreshSnapshotIfNeeded(force: true, forwardAction: .object(payload), requester: requester)
            return .object([
                "status": .string("ok"),
                "state": .object(self.cachedMatchmakingState)
            ])
        })

        await addInterceptForSet(requester: owner, key: "dispatchAction", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "dispatchAction", for: requester) else { return .string("denied") }
            return await self.handleDispatchAction(value, requester: requester)
        })

        Task { [weak self] in
            guard let self else { return }
            await self.refreshSnapshotIfNeeded(force: true, forwardAction: nil, requester: owner)
        }
    }

    private func handleDispatchAction(_ value: ValueType, requester: Identity) async -> ValueType {
        guard case let .object(object) = value,
              let actionKeypath = string(from: object["keypath"]),
              actionKeypath.isEmpty == false else {
            cachedMatchmakingState = Self.matchmakingStateWithStatus(
                basedOn: cachedMatchmakingState,
                status: "Anbefalingshandlingen mangler keypath.",
                actionSummary: "Kunne ikke utføre handlingen fordi payloaden var ugyldig."
            )
            return .object([
                "status": .string("error"),
                "state": .object(cachedMatchmakingState)
            ])
        }

        let payload = object["payload"] ?? .null
        let recommendationRows = listObjects(from: cachedMatchmakingState["recommendations"])
        let searchRows = listObjects(from: cachedMatchmakingState["searchResults"])
        var forwardedAction: ValueType? = .object([
            "keypath": .string(actionKeypath),
            "payload": payload
        ])

        switch actionKeypath {
        case "matchmaking.focusRecommendationAtIndex":
            let index = recommendationIndex(from: payload)
            if let index,
               recommendationRows.indices.contains(index) {
                let focusedCard = recommendationRows[index]
                let displayName = cardTitle(from: focusedCard)
                let subtitle = cardSubtitle(from: focusedCard)
                focusedRecommendationName = displayName
                await rememberSelectedParticipant(displayName)
                recentActionSummary = "Viser \(displayName) i denne siden."
                forwardedAction = .object([
                    "keypath": .string("matchmaking.focusPerson"),
                    "payload": .object([
                        "displayName": .string(displayName),
                        "subtitle": .string(subtitle)
                    ])
                ])
            } else {
                recentActionSummary = "Kunne ikke finne anbefalingen du prøvde å fokusere."
                forwardedAction = nil
            }
        case "matchmaking.focusPerson":
            if case let .object(personObject) = payload,
               let displayName = string(from: personObject["displayName"])?.trimmingCharacters(in: .whitespacesAndNewlines),
               displayName.isEmpty == false {
                focusedRecommendationName = displayName
                await rememberSelectedParticipant(displayName)
                recentActionSummary = "Viser \(displayName) i denne siden."
            }
        case "discovery.startChatWithFocusedPerson":
            if let focusedCard = focusedRecommendationCard(
                recommendations: recommendationRows,
                searchResults: searchRows
            ) {
                let displayName = cardTitle(from: focusedCard)
                let subtitle = cardSubtitle(from: focusedCard)
                focusedRecommendationName = displayName
                await rememberSelectedParticipant(displayName)
                recentActionSummary = "Starter chat med \(displayName)…"
                forwardedAction = .object([
                    "keypath": .string("discovery.startChat"),
                    "payload": discoveryChatPayload(for: displayName, subtitle: subtitle)
                ])
            } else {
                recentActionSummary = "Velg Vis i siden på en anbefaling før du starter chat."
                forwardedAction = nil
            }
        case "matchmaking.toggleFollowUpForFocusedPerson":
            if let focusedCard = focusedRecommendationCard(
                recommendations: recommendationRows,
                searchResults: searchRows
            ) {
                let displayName = cardTitle(from: focusedCard)
                let subtitle = cardSubtitle(from: focusedCard)
                focusedRecommendationName = displayName
                await rememberSelectedParticipant(displayName)
                if followUpMarkedNames.contains(displayName) {
                    followUpMarkedNames.remove(displayName)
                    recentActionSummary = "Fjernet \(displayName) fra oppfølging."
                } else {
                    followUpMarkedNames.insert(displayName)
                    recentActionSummary = "Markerte \(displayName) for oppfølging."
                }
                forwardedAction = .object([
                    "keypath": .string("matchmaking.toggleFollowUp"),
                    "payload": .object([
                        "displayName": .string(displayName),
                        "subtitle": .string(subtitle)
                    ])
                ])
            } else {
                recentActionSummary = "Velg Vis i siden på en anbefaling før du markerer oppfølging."
                forwardedAction = nil
            }
        case "scheduling.createMeetingRequestForFocusedPerson":
            if let focusedCard = focusedRecommendationCard(
                recommendations: recommendationRows,
                searchResults: searchRows
            ) {
                let displayName = cardTitle(from: focusedCard)
                focusedRecommendationName = displayName
                await rememberSelectedParticipant(displayName)
                recentActionSummary = "La til møteforespørsel for \(displayName)."
                forwardedAction = .object([
                    "keypath": .string("scheduling.createMeetingRequest"),
                    "payload": .object([
                        "source": .string("binding-matchmaking-focused-person"),
                        "displayName": .string(displayName)
                    ])
                ])
            } else {
                recentActionSummary = "Velg Vis i siden på en anbefaling før du ber om møte."
                forwardedAction = nil
            }
        case "matchmaking.toggleFollowUp":
            if case let .object(personObject) = payload,
               let displayName = string(from: personObject["displayName"])?.trimmingCharacters(in: .whitespacesAndNewlines),
               displayName.isEmpty == false {
                focusedRecommendationName = displayName
                await rememberSelectedParticipant(displayName)
                if followUpMarkedNames.contains(displayName) {
                    followUpMarkedNames.remove(displayName)
                    recentActionSummary = "Fjernet \(displayName) fra oppfølging."
                } else {
                    followUpMarkedNames.insert(displayName)
                    recentActionSummary = "Markerte \(displayName) for oppfølging."
                }
            }
        case "discovery.startChat":
            let targetNames = discoveryTargetNames(from: payload)
            if let firstTarget = targetNames.first {
                focusedRecommendationName = firstTarget
                await rememberSelectedParticipant(firstTarget)
                recentActionSummary = "Starter chat med \(firstTarget)…"
            } else {
                recentActionSummary = "Starter chat fra anbefalingsflaten…"
            }
        case "scheduling.createMeetingRequest":
            if let focusedRecommendationName {
                recentActionSummary = "La til møteforespørsel for \(focusedRecommendationName)."
            } else {
                recentActionSummary = "La til en ny møteforespørsel."
            }
        case "matchmaking.setFilters":
            recentActionSummary = "Oppdaterte anbefalingsfilteret."
        case "matchmaking.searchPeople":
            recentActionSummary = "Viser governance-relevante personer i anbefalingene."
        case "matchmaking.refreshRecommendations":
            recentActionSummary = "Oppdaterte anbefalingene."
        default:
            recentActionSummary = "Utførte \(actionKeypath) i anbefalingssnapshotet."
        }

        cachedMatchmakingState = mergedMatchmakingState(from: cachedMatchmakingState)
        await refreshSnapshotIfNeeded(force: true, forwardAction: forwardedAction, requester: requester)
        return .object([
            "status": .string("ok"),
            "state": .object(cachedMatchmakingState)
        ])
    }

    private func refreshSnapshotIfNeeded(
        force: Bool,
        forwardAction: ValueType?,
        requester: Identity
    ) async {
        let shouldRetryImmediately = ConferenceSnapshotRetrySupport.shouldRetryImmediately(
            cachedState: cachedMatchmakingState,
            statusKeys: ["status", "actionSummary", "searchSummary"]
        )

        if !force,
           !shouldRetryImmediately,
           let lastRefreshAt,
           Date().timeIntervalSince(lastRefreshAt) < 1 {
            return
        }

        if let refreshTask {
            await refreshTask.value
            let shouldRetryAfterInflight = ConferenceSnapshotRetrySupport.shouldRetryImmediately(
                cachedState: cachedMatchmakingState,
                statusKeys: ["status", "actionSummary", "searchSummary"]
            )
            if !force && forwardAction == nil && !shouldRetryAfterInflight {
                return
            }
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performRefresh(
                forwardAction: forwardAction,
                requester: requester
            )
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    @MainActor
    private func performRefresh(
        forwardAction: ValueType?,
        requester: Identity
    ) async {
        guard await BindingLocalCellRegistration.shared.ensureConferenceDemoRuntimeReady() else {
            cachedMatchmakingState = Self.matchmakingStateWithStatus(
                basedOn: cachedMatchmakingState,
                status: "Anbefalingene bruker siste lokale snapshot fordi runtime-validering feilet.",
                actionSummary: "Kunne ikke oppdatere anbefalingene akkurat nå."
            )
            lastRefreshAt = Date()
            return
        }

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            cachedMatchmakingState = Self.matchmakingStateWithStatus(
                basedOn: cachedMatchmakingState,
                status: "Anbefalingene bruker siste lokale snapshot fordi resolver mangler.",
                actionSummary: "Kunne ikke oppdatere anbefalingene akkurat nå."
            )
            lastRefreshAt = Date()
            return
        }

        guard let previewShell = try? await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: requester
        ) as? Meddle else {
            cachedMatchmakingState = Self.matchmakingStateWithStatus(
                basedOn: cachedMatchmakingState,
                status: "Anbefalingene bruker siste lokale snapshot fordi ingen preview-shell er tilgjengelig.",
                actionSummary: "Kunne ikke oppdatere anbefalingene akkurat nå."
            )
            lastRefreshAt = Date()
            return
        }

        if let forwardAction {
            let mutationResult = try? await previewShell.set(
                keypath: "dispatchAction",
                value: forwardAction,
                requester: requester
            )
            if let errorDescription = mutationErrorDescription(from: mutationResult) {
                cachedMatchmakingState = Self.matchmakingStateWithStatus(
                    basedOn: cachedMatchmakingState,
                    status: "Anbefalingene beholdt siste stabile snapshot fordi handlingen feilet.",
                    actionSummary: errorDescription
                )
            }
        }

        do {
            let stateValue = try await previewShell.get(
                keypath: "state",
                requester: requester
            )
            guard case let .object(stateObject) = stateValue,
                  case let .object(matchesObject)? = stateObject["matches"] else {
                cachedMatchmakingState = Self.matchmakingStateWithStatus(
                    basedOn: cachedMatchmakingState,
                    status: "Anbefalingene returnerte ikke et lesbart snapshot.",
                    actionSummary: "Bruker siste stabile data."
                )
                lastRefreshAt = Date()
                return
            }

            let sharedConnections = conferenceObject(from: stateObject["sharedConnections"])
            synchronizeLaunchedChats(
                from: sharedConnections,
                forwardedAction: forwardAction
            )

            cachedMatchmakingState = mergedMatchmakingState(from: matchesObject)
            lastRefreshAt = Date()
        } catch {
            cachedMatchmakingState = Self.matchmakingStateWithStatus(
                basedOn: cachedMatchmakingState,
                status: "Anbefalingene bruker siste stabile snapshot.",
                actionSummary: "Kunne ikke hente oppdatert anbefalingsdata akkurat nå: \(error)"
            )
            lastRefreshAt = Date()
        }
    }

    private func synchronizeLaunchedChats(
        from sharedConnections: Object?,
        forwardedAction: ValueType?
    ) {
        let sharedNames = conferenceSharedConnectionNames(from: sharedConnections)
        launchedChatNames = sharedNames

        guard conferenceActionKeypath(from: forwardedAction) == "discovery.startChat" else {
            return
        }

        let targetNames = discoveryTargetNames(from: conferenceActionPayload(from: forwardedAction) ?? .null)
        guard let firstTarget = targetNames.first else {
            return
        }

        if sharedNames.contains(firstTarget) {
            recentActionSummary = "Chatten med \(firstTarget) er klar."
        } else {
            if launchedChatNames.contains(firstTarget) == false {
                launchedChatNames.insert(firstTarget, at: 0)
                launchedChatNames = Array(Set(launchedChatNames)).sorted {
                    if $0 == firstTarget { return true }
                    if $1 == firstTarget { return false }
                    return $0 < $1
                }
            }
            recentActionSummary = "Chatten med \(firstTarget) klargjøres. Du kan åpne chatflaten nå."
        }
    }

    private func mergedMatchmakingState(from object: Object) -> Object {
        var merged = Self.defaultMatchmakingState()
        for (key, value) in object {
            merged[key] = value
        }

        let recommendationRows = listObjects(from: merged["recommendations"])
        let searchRows = listObjects(from: merged["searchResults"])
        let derivedRecommendations = recommendationRows.map { recommendationCard(from: $0) }
        let derivedSearchResults = searchRows.map { followUpConnectionCard(from: $0) }
        let focusedCard = focusedRecommendationCard(
            recommendations: recommendationRows,
            searchResults: searchRows
        )

        merged["recommendations"] = .list(derivedRecommendations)
        merged["searchResults"] = .list(derivedSearchResults)
        merged["statusSummary"] = .string(statusSummary(for: recommendationRows))
        merged["selectionSummary"] = .string(selectionSummary(for: focusedCard))
        merged["navigationSummary"] = .string(navigationSummary(for: focusedCard))
        merged["nextStepSummary"] = .string(nextStepSummary(for: focusedCard))
        merged["actionSummary"] = .string(recentActionSummary)
        merged["focusedProfile"] = .object(focusedProfileObject(from: focusedCard))
        merged["focusedActions"] = .list(focusedActionCards(for: focusedCard))
        return merged
    }

    private func recommendationCard(from raw: Object) -> ValueType {
        let title = cardTitle(from: raw)
        let subtitle = cardSubtitle(from: raw)
        let detail = cardDetail(from: raw)
        let baseNote = cardNote(from: raw)
        let isFocused = focusedRecommendationName == title
        let note: String
        if isFocused {
            note = "\(baseNote) · Vises i siden nå."
        } else {
            note = "\(baseNote) · Trykk Vis i siden for å fokusere."
        }

        return .object([
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(note),
            "demoPersona": raw["demoPersona"] ?? .object(conferenceDemoPersonaSeedObject(named: title)),
            "keypath": .string("matchmakingSnapshot.dispatchAction"),
            "label": .string(isFocused ? "Valgt i siden" : "Vis i siden"),
            "payload": .object([
                "keypath": .string("matchmaking.focusPerson"),
                "payload": .object([
                    "displayName": .string(title),
                    "subtitle": .string(subtitle)
                ])
            ])
        ])
    }

    private func followUpConnectionCard(from raw: Object) -> ValueType {
        let title = cardTitle(from: raw)
        let subtitle = cardSubtitle(from: raw)
        let detail = cardDetail(from: raw)
        let baseNote = cardNote(from: raw)
        let marked = followUpMarkedNames.contains(title)
        return .object([
            "title": .string(title),
            "subtitle": .string(subtitle),
            "detail": .string(detail),
            "note": .string(marked ? "\(baseNote) · Markert for oppfølging." : "\(baseNote) · Kan markeres for oppfølging."),
            "demoPersona": raw["demoPersona"] ?? .object(conferenceDemoPersonaSeedObject(named: title)),
            "keypath": .string("matchmakingSnapshot.dispatchAction"),
            "label": .string(marked ? "Fjern markering" : "Marker for oppfølging"),
            "payload": .object([
                "keypath": .string("matchmaking.toggleFollowUp"),
                "payload": .object([
                    "displayName": .string(title),
                    "subtitle": .string(subtitle)
                ])
            ])
        ])
    }

    private func statusSummary(for recommendationRows: [Object]) -> String {
        if recommendationRows.isEmpty {
            return "Ingen anbefalte deltakere er klare ennå."
        }
        return "\(recommendationRows.count) anbefalte deltakere er klare for gjennomgang."
    }

    private func selectionSummary(for focusedCard: Object?) -> String {
        guard let focusedCard else {
            return "Trykk Vis i siden på en anbefaling for å fokusere på personen her."
        }
        return "Viser \(cardTitle(from: focusedCard)) i denne siden."
    }

    private func navigationSummary(for focusedCard: Object?) -> String {
        if focusedCard == nil {
            return "Første klikk skjer i denne siden. Du trenger ikke åpne en ny arbeidsflate for å se hvem anbefalingen gjelder."
        }
        return "Du ser nå valgt deltaker i denne siden. Herfra kan du starte chat, markere oppfølging eller be om møte."
    }

    private func nextStepSummary(for focusedCard: Object?) -> String {
        guard let focusedCard else {
            return "Velg en anbefalt deltaker med Vis i siden før du tar neste steg."
        }
        let title = cardTitle(from: focusedCard)
        if launchedChatNames.contains(title) {
            return "Chatten med \(title) er klar. Neste steg er å åpne chatflaten eller be om møte."
        }
        if followUpMarkedNames.contains(title) {
            return "\(title) er markert for oppfølging. Neste steg er å starte chat eller be om møte."
        }
        return "Neste steg for \(title) er å starte chat, markere oppfølging eller be om møte."
    }

    private func focusedProfileObject(from focusedCard: Object?) -> Object {
        guard let focusedCard else {
            return [
                "selectionBadge": .string("VALGT DELTAKER"),
                "title": .string("Ingen deltaker valgt ennå"),
                "subtitle": .string("Anbefalinger"),
                "detail": .string("Trykk Vis i siden på en anbefaling for å se personens offentlige og lokale oppsummering her."),
                "note": .string("Dette er standardvisningen før du velger en anbefalt deltaker."),
                "publicProfileSummary": .string("Velg en anbefaling for å se en tydelig offentlig profil og lokal oppsummering her."),
                "profileDetail": .string("Vi viser fagområde, begrunnelse og anbefalt neste steg når en deltaker er valgt."),
                "fitSummary": .string("Ingen anbefalt deltaker er valgt ennå."),
                "nextStep": .string("Velg en anbefaling først, og bruk deretter chat, oppfølging eller møte."),
                "conversationStyle": .string("Når en deltaker er valgt, viser vi hvordan demo-personaen typisk svarer i chat."),
                "openingPrompt": .string("Velg en anbefaling først for å se et konkret forslag til åpningsmelding."),
                "simulationSummary": .string("Demo-svarene er bounded og følger valgt deltagerprofil.")
            ]
        }

        let persona = conferenceDemoPersona(named: cardTitle(from: focusedCard), source: focusedCard)
        let title = cardTitle(from: focusedCard)
        let chatReady = launchedChatNames.contains(title)
        let followUpMarked = followUpMarkedNames.contains(title)
        let note: String
        if chatReady {
            note = "\(cardNote(from: focusedCard)) · Chatten er klar i chat og oppfølging."
        } else if followUpMarked {
            note = "\(cardNote(from: focusedCard)) · Markert for oppfølging."
        } else {
            note = cardNote(from: focusedCard)
        }
        let nextStep: String
        if chatReady {
            nextStep = "Åpne chatflaten eller be om møte med \(title)."
        } else if followUpMarked {
            nextStep = "Fortsett med chat eller be om møte med \(title)."
        } else {
            nextStep = "Bruk Klargjør chat, Marker for oppfølging eller Be om møte med \(title)."
        }
        return [
            "selectionBadge": .string("VALGT DELTAKER"),
            "title": .string(title),
            "subtitle": .string(cardSubtitle(from: focusedCard)),
            "detail": .string(cardDetail(from: focusedCard)),
            "note": .string(note),
            "publicProfileSummary": .string("Offentlig profil: \(cardSubtitle(from: focusedCard))."),
            "profileDetail": .string("\(cardDetail(from: focusedCard)) \(persona.publicProfileDetail)"),
            "fitSummary": .string("\(cardNote(from: focusedCard)) · \(persona.fitContext)"),
            "nextStep": .string(nextStep),
            "conversationStyle": .string(persona.conversationStyle),
            "openingPrompt": .string(persona.suggestedOpening),
            "simulationSummary": .string(persona.simulatedAgentSummary)
        ]
    }

    private func focusedActionCards(for focusedCard: Object?) -> [ValueType] {
        guard let focusedCard else { return [] }
        let title = cardTitle(from: focusedCard)
        let subtitle = cardSubtitle(from: focusedCard)
        let chatReady = launchedChatNames.contains(title)
        let followUpMarked = followUpMarkedNames.contains(title)

        let chatAction: ValueType = .object([
            "title": .string("Chat"),
            "subtitle": .string(chatReady ? "Fortsett samtalen" : "Start samtalen"),
            "detail": .string(chatReady ? "Åpne chatflaten med \(title) og fortsett oppfølgingen." : "Start en conference-chat med \(title) fra denne siden."),
            "note": .string("Dette er den tydeligste neste handlingen når du vil ta kontakt."),
            "keypath": .string(chatReady ? "chatSnapshot.dispatchAction" : "matchmakingSnapshot.dispatchAction"),
            "label": .string(chatReady ? "Åpne chatflate" : "Start chat"),
            "payload": .object([
                "keypath": .string(chatReady ? "openChatWorkbench" : "discovery.startChat"),
                "payload": chatReady
                    ? .object([
                        "displayName": .string(title),
                        "subtitle": .string(subtitle)
                    ])
                    : discoveryChatPayload(for: title, subtitle: subtitle)
            ])
        ])

        let followUpAction: ValueType = .object([
            "title": .string("Oppfølging"),
            "subtitle": .string(followUpMarked ? "Allerede markert" : "Marker neste steg"),
            "detail": .string(followUpMarked ? "\(title) er markert for oppfølging." : "Marker \(title) for oppfølging så den er lett å finne igjen."),
            "note": .string("Bruk dette når du vil huske personen uten å starte chat med en gang."),
            "keypath": .string("matchmakingSnapshot.dispatchAction"),
            "label": .string(followUpMarked ? "Fjern markering" : "Marker for oppfølging"),
            "payload": .object([
                "keypath": .string("matchmaking.toggleFollowUp"),
                "payload": .object([
                    "displayName": .string(title),
                    "subtitle": .string(subtitle)
                ])
            ])
        ])

        let meetingAction: ValueType = .object([
            "title": .string("Møte"),
            "subtitle": .string("Foreslå et konkret neste steg"),
            "detail": .string("Be om møte med \(title) hvis du vil gå fra anbefaling til konkret plan."),
            "note": .string("Bra når du allerede vet at personen er relevant og vil sette opp et faktisk møtetidspunkt."),
            "keypath": .string("matchmakingSnapshot.dispatchAction"),
            "label": .string("Be om møte"),
            "payload": .object([
                "keypath": .string("scheduling.createMeetingRequest"),
                "payload": .object([
                    "source": .string("binding-matchmaking-snapshot"),
                    "displayName": .string(title)
                ])
            ])
        ])

        return [chatAction, followUpAction, meetingAction]
    }

    private func focusedRecommendationCard(
        recommendations: [Object],
        searchResults: [Object]
    ) -> Object? {
        guard let focusedRecommendationName else { return nil }
        if let recommendation = recommendations.first(where: { cardTitle(from: $0) == focusedRecommendationName }) {
            return recommendation
        }
        if let searchResult = searchResults.first(where: { cardTitle(from: $0) == focusedRecommendationName }) {
            return searchResult
        }
        return nil
    }

    private func restoreSelectedParticipantIfAvailable() async {
        guard focusedRecommendationName == nil,
              !storeKey.isEmpty,
              let storedSelection = await ConferenceParticipantSelectionStore.shared.load(for: storeKey) else {
            return
        }
        focusedRecommendationName = storedSelection
    }

    private func rememberSelectedParticipant(_ displayName: String?) async {
        guard !storeKey.isEmpty else { return }
        await ConferenceParticipantSelectionStore.shared.save(displayName, for: storeKey)
    }

    private func listObjects(from value: ValueType?) -> [Object] {
        guard case let .list(values)? = value else { return [] }
        return values.compactMap {
            guard case let .object(object) = $0 else { return nil }
            return object
        }
    }

    private func cardTitle(from object: Object) -> String {
        string(from: object["title"]) ??
        string(from: object["displayName"]) ??
        "Ukjent deltaker"
    }

    private func cardSubtitle(from object: Object) -> String {
        string(from: object["subtitle"]) ??
        string(from: object["headline"]) ??
        "Anbefalt deltaker"
    }

    private func cardDetail(from object: Object) -> String {
        string(from: object["detail"]) ??
        "Ingen detalj tilgjengelig."
    }

    private func cardNote(from object: Object) -> String {
        string(from: object["note"]) ??
        "Ingen ekstra kontekst tilgjengelig ennå."
    }

    private func discoveryChatPayload(for title: String, subtitle: String) -> ValueType {
        .object([
            "source": .string("binding-participant-portal-recommendation"),
            "targets": .list([
                .object([
                    "displayName": .string(title),
                    "headline": .string(subtitle)
                ])
            ])
        ])
    }

    private func discoveryTargetNames(from payload: ValueType) -> [String] {
        guard case let .object(payloadObject) = payload else { return [] }
        if case let .list(targets)? = payloadObject["targets"] {
            let names = targets.compactMap { target -> String? in
                guard case let .object(targetObject) = target else { return nil }
                if let displayName = string(from: targetObject["displayName"])?.trimmingCharacters(in: .whitespacesAndNewlines),
                   displayName.isEmpty == false {
                    return displayName
                }
                if let participantId = string(from: targetObject["participantId"])?.trimmingCharacters(in: .whitespacesAndNewlines),
                   participantId.isEmpty == false {
                    return participantId
                }
                return nil
            }
            if names.isEmpty == false {
                return names
            }
        }
        if case let .list(participantIds)? = payloadObject["participantIds"] {
            return participantIds.compactMap { value in
                guard let raw = string(from: value) else { return nil }
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        }
        return []
    }

    private func recommendationIndex(from payload: ValueType) -> Int? {
        if let direct = int(from: payload) {
            return direct
        }
        guard case let .object(payloadObject) = payload else {
            return nil
        }
        return int(from: payloadObject["index"])
    }

    private func string(from value: ValueType?) -> String? {
        guard let value else { return nil }
        switch value {
        case let .string(string):
            return string
        case let .integer(integer):
            return String(integer)
        case let .number(number):
            return String(number)
        case let .float(float):
            return String(float)
        case let .bool(bool):
            return bool ? "true" : "false"
        default:
            return nil
        }
    }

    private func int(from value: ValueType?) -> Int? {
        guard let value else { return nil }
        switch value {
        case let .integer(integer):
            return integer
        case let .float(float):
            return Int(float)
        case let .number(number):
            return number
        case let .string(string):
            return Int(string)
        default:
            return nil
        }
    }

    private func mutationErrorDescription(from value: ValueType?) -> String? {
        conferenceMutationErrorDescription(from: value)
    }

    private static func matchmakingStateWithStatus(
        basedOn base: Object,
        status: String,
        actionSummary: String
    ) -> Object {
        var updated = base
        updated["statusSummary"] = .string(status)
        updated["actionSummary"] = .string(actionSummary)
        return updated
    }

    private static func defaultMatchmakingState() -> Object {
        [
            "intro": .string("Disse anbefalingene samler deltakerens formål, interesser og conference-kontekst i én stabil lokal snapshot-flate."),
            "filterSummary": .string("Filter: alle anbefalte deltakere."),
            "status": .string("Anbefalingene er klare for gjennomgang."),
            "recommendationSummary": .string("3 anbefalte deltakere klare for gjennomgang."),
            "searchSummary": .string("Søkeutvidelsen er klar når du vil spisse treffene. Ingen personer er markert for oppfølging ennå."),
            "statusSummary": .string("Anbefalingssnapshotet bruker en lokal startflate mens livedata kobler seg til."),
            "selectionSummary": .string("Trykk Vis i siden på en anbefaling for å fokusere på personen her."),
            "navigationSummary": .string("Første klikk skjer i denne siden."),
            "nextStepSummary": .string("Velg en anbefalt deltaker før du tar neste steg."),
            "actionSummary": .string("Velg Vis i siden for å fokusere på en anbefalt deltaker her."),
            "recommendations": .list([
                .object([
                    "title": .string("Ane Solberg"),
                    "subtitle": .string("Public sector interoperability"),
                    "detail": .string("Strong match on governance and delivery."),
                    "note": .string("92% match")
                ]),
                .object([
                    "title": .string("Mads Hovden"),
                    "subtitle": .string("Policy and compliance"),
                    "detail": .string("Works with claims, trust, and organization."),
                    "note": .string("88% match")
                ]),
                .object([
                    "title": .string("Lea Heger"),
                    "subtitle": .string("Digital service design"),
                    "detail": .string("Can connect the program to concrete product choices."),
                    "note": .string("84% match")
                ])
            ]),
            "searchResults": .list([
                .object([
                    "title": .string("Governance Forum"),
                    "subtitle": .string("Nearby people"),
                    "detail": .string("Found people mentioning governance."),
                    "note": .string("Local preview")
                ]),
                .object([
                    "title": .string("Trust Infrastructure Lab"),
                    "subtitle": .string("Shared interests"),
                    "detail": .string("Shared focus on trust, claims, and operations."),
                    "note": .string("Suggested follow-up")
                ])
            ]),
            "focusedProfile": .object([
                "selectionBadge": .string("VALGT DELTAKER"),
                "title": .string("Ingen deltaker valgt ennå"),
                "subtitle": .string("Anbefalinger"),
                "detail": .string("Trykk Vis i siden på en anbefaling for å se personens offentlige og lokale oppsummering her."),
                "note": .string("Dette er standardvisningen før du velger en anbefalt deltaker.")
            ]),
            "focusedActions": .list([])
        ]
    }
}

@MainActor
private final class ConferenceParticipantChatSnapshotLocalCell: GeneralCell {
    private var cachedChatState: Object = ConferenceParticipantChatSnapshotLocalCell.defaultChatState()
    private var lastRefreshAt: Date?
    private var refreshTask: Task<Void, Never>?
    private var storeKey = ""
    private var focusedChatName: String?
    private var draftMessage = ""
    private var draftSeedName: String?
    private var recentActionSummary = "Start chat fra deltagerportalen for å gjøre en delt tråd klar her."

    required init(owner: Identity) async {
        await super.init(owner: owner)
        await configure(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        fatalError("ConferenceParticipantChatSnapshotLocalCell does not support decoding")
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private func configure(owner: Identity) async {
        storeKey = owner.uuid
        await restoreSelectedParticipantIfAvailable()
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("r---", for: "editorDraft")
        agreementTemplate.addGrant("rw--", for: "refresh")
        agreementTemplate.addGrant("rw--", for: "setDraft")
        agreementTemplate.addGrant("rw--", for: "sendMessage")
        agreementTemplate.addGrant("rw--", for: "setDraftMessage")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")

        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("r---", at: "state", for: requester) else { return .string("denied") }
            await self.refreshSnapshotIfNeeded(force: false, forwardAction: nil, requester: requester)
            return .object(self.cachedChatState)
        })

        await addInterceptForSet(requester: owner, key: "refresh", setValueIntercept: { [weak self] _, _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "refresh", for: requester) else { return .string("denied") }
            await self.refreshSnapshotIfNeeded(force: true, forwardAction: nil, requester: requester)
            return .object([
                "status": .string("ok"),
                "state": .object(self.cachedChatState)
            ])
        })

        await addInterceptForGet(requester: owner, key: "editorDraft", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("r---", at: "editorDraft", for: requester) else { return .string("denied") }
            await self.refreshSnapshotIfNeeded(force: false, forwardAction: nil, requester: requester)
            return .string(self.draftMessage)
        })

        await addInterceptForSet(requester: owner, key: "setDraft", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "setDraft", for: requester) else { return .string("denied") }
            self.draftMessage = self.draftText(from: value) ?? ""
            self.recentActionSummary = self.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Meldingsutkastet er tomt igjen."
                : "Meldingsutkastet er oppdatert i Conference Participant Chat."
            self.cachedChatState = self.mergedChatState(from: self.cachedChatState)
            return .object([
                "status": .string("ok"),
                "state": .object(self.cachedChatState)
            ])
        })

        await addInterceptForSet(requester: owner, key: "sendMessage", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "sendMessage", for: requester) else { return .string("denied") }
            if let directText = self.draftText(from: value),
               directText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                self.draftMessage = directText
            }
            return await self.sendDraftMessage(requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "setDraftMessage", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "setDraftMessage", for: requester) else { return .string("denied") }
            self.draftMessage = self.draftText(from: value) ?? ""
            self.recentActionSummary = self.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Meldingsutkastet er tomt igjen."
                : "Meldingsutkastet er oppdatert i chatflaten."
            self.cachedChatState = self.mergedChatState(from: self.cachedChatState)
            return .object([
                "status": .string("ok"),
                "state": .object(self.cachedChatState)
            ])
        })

        await addInterceptForSet(requester: owner, key: "dispatchAction", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "dispatchAction", for: requester) else { return .string("denied") }
            return await self.handleDispatchAction(value, requester: requester)
        })

        Task { [weak self] in
            guard let self else { return }
            await self.refreshSnapshotIfNeeded(force: true, forwardAction: nil, requester: owner)
        }
    }

    private func handleDispatchAction(_ value: ValueType, requester: Identity) async -> ValueType {
        guard case let .object(object) = value,
              let actionKeypath = string(from: object["keypath"]),
              actionKeypath.isEmpty == false else {
            cachedChatState = Self.chatStateWithStatus(
                basedOn: cachedChatState,
                status: "Chat-handlingen mangler keypath.",
                actionSummary: "Kunne ikke utføre handlingen fordi payloaden var ugyldig."
            )
            return .object([
                "status": .string("error"),
                "state": .object(cachedChatState)
            ])
        }

        let payload = object["payload"] ?? .null

        switch actionKeypath {
        case "chat.focusThread":
            if case let .object(threadObject) = payload,
               let displayName = string(from: threadObject["displayName"])?.trimmingCharacters(in: .whitespacesAndNewlines),
               displayName.isEmpty == false {
                focusedChatName = displayName
                await rememberSelectedParticipant(displayName)
                recentActionSummary = "Viser den delte tråden med \(displayName)."
                cachedChatState = mergedChatState(from: cachedChatState)
            }
            return .object([
                "status": .string("ok"),
                "state": .object(cachedChatState)
            ])

        case "chat.sendDraftMessage":
            return await sendDraftMessage(requester: requester)

        case "openChatWorkbenchForSelectedParticipant":
            if let storedSelection = await selectedParticipantFromStore() {
                focusedChatName = storedSelection
                await rememberSelectedParticipant(storedSelection)
            }
            let selectedName = focusedChatName ?? "valgt deltaker"
            recentActionSummary = "Åpner chatflaten for \(selectedName)…"
            let selectedThreadReady = await ensureSharedThreadReady(requester: requester)
            if !selectedThreadReady {
                let currentState = mergedChatState(from: cachedChatState)
                cachedChatState = Self.chatStateWithStatus(
                    basedOn: currentState,
                    status: string(from: currentState["statusSummary"]) ?? "Ingen delt tråd er klar ennå.",
                    actionSummary: recentActionSummary
                )
                return .object([
                    "status": .string("error"),
                    "state": .object(cachedChatState)
                ])
            }
            return await openChatWorkbench(requester: requester)

        case "openChatWorkbench":
            if case let .object(threadObject) = payload,
               let displayName = string(from: threadObject["displayName"])?.trimmingCharacters(in: .whitespacesAndNewlines),
               displayName.isEmpty == false {
                focusedChatName = displayName
                await rememberSelectedParticipant(displayName)
            }
            let threadReady = await ensureSharedThreadReady(requester: requester)
            if !threadReady {
                let currentState = mergedChatState(from: cachedChatState)
                cachedChatState = Self.chatStateWithStatus(
                    basedOn: currentState,
                    status: string(from: currentState["statusSummary"]) ?? "Ingen delt tråd er klar ennå.",
                    actionSummary: recentActionSummary
                )
                return .object([
                    "status": .string("error"),
                    "state": .object(cachedChatState)
                ])
            }
            return await openChatWorkbench(requester: requester)

        case "openParticipantPortalWorkbench":
            return await openParticipantPortalWorkbench(requester: requester)

        case "connections.postSharedMessage", "scheduling.createMeetingRequest":
            let forwardedAction: ValueType = .object([
                "keypath": .string(actionKeypath),
                "payload": payload
            ])
            if actionKeypath == "connections.postSharedMessage" {
                recentActionSummary = "Sendte en oppfølgingsmelding i delt tråd."
            } else {
                recentActionSummary = "La til en møteforespørsel fra chatflaten."
            }
            await refreshSnapshotIfNeeded(force: true, forwardAction: forwardedAction, requester: requester)
            return .object([
                "status": .string("ok"),
                "state": .object(cachedChatState)
            ])

        default:
            recentActionSummary = "Utførte \(actionKeypath) i chat-snapshotet."
            let forwardedAction: ValueType = .object([
                "keypath": .string(actionKeypath),
                "payload": payload
            ])
            await refreshSnapshotIfNeeded(force: true, forwardAction: forwardedAction, requester: requester)
            return .object([
                "status": .string("ok"),
                "state": .object(cachedChatState)
            ])
        }
    }

    private func refreshSnapshotIfNeeded(
        force: Bool,
        forwardAction: ValueType?,
        requester: Identity
    ) async {
        let shouldRetryImmediately = ConferenceSnapshotRetrySupport.shouldRetryImmediately(
            cachedState: cachedChatState,
            statusKeys: ["statusSummary", "actionSummary", "threadSummary", "recentMessagesSummary"]
        )

        if !force,
           !shouldRetryImmediately,
           let lastRefreshAt,
           Date().timeIntervalSince(lastRefreshAt) < 1 {
            return
        }

        if let refreshTask {
            await refreshTask.value
            let shouldRetryAfterInflight = ConferenceSnapshotRetrySupport.shouldRetryImmediately(
                cachedState: cachedChatState,
                statusKeys: ["statusSummary", "actionSummary", "threadSummary", "recentMessagesSummary"]
            )
            if !force && forwardAction == nil && !shouldRetryAfterInflight {
                return
            }
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performRefresh(forwardAction: forwardAction, requester: requester)
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    @MainActor
    private func performRefresh(
        forwardAction: ValueType?,
        requester: Identity
    ) async {
        guard await BindingLocalCellRegistration.shared.ensureConferenceDemoRuntimeReady() else {
            cachedChatState = Self.chatStateWithStatus(
                basedOn: cachedChatState,
                status: "Chatflaten bruker siste lokale snapshot fordi runtime-validering feilet.",
                actionSummary: "Kunne ikke oppdatere chat akkurat nå."
            )
            lastRefreshAt = Date()
            return
        }

        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let previewShell = try? await resolver.cellAtEndpoint(
                endpoint: "cell:///ConferenceParticipantPreviewShell",
                requester: requester
              ) as? Meddle else {
            cachedChatState = Self.chatStateWithStatus(
                basedOn: cachedChatState,
                status: "Chatflaten bruker siste lokale snapshot fordi deltager-preview ikke er tilgjengelig.",
                actionSummary: "Kunne ikke oppdatere chat akkurat nå."
            )
            lastRefreshAt = Date()
            return
        }

        if let forwardAction {
            let mutationResult = try? await previewShell.set(
                keypath: "dispatchAction",
                value: forwardAction,
                requester: requester
            )
            if let errorDescription = mutationErrorDescription(from: mutationResult) {
                cachedChatState = Self.chatStateWithStatus(
                    basedOn: cachedChatState,
                    status: "Chatflaten beholdt siste stabile snapshot fordi handlingen feilet.",
                    actionSummary: errorDescription
                )
                lastRefreshAt = Date()
                return
            }
        }

        do {
            let stateValue = try await previewShell.get(keypath: "state", requester: requester)
            guard case let .object(stateObject) = stateValue else {
                cachedChatState = Self.chatStateWithStatus(
                    basedOn: cachedChatState,
                    status: "Chatflaten returnerte ikke et lesbart preview-snapshot.",
                    actionSummary: "Bruker siste stabile data."
                )
                lastRefreshAt = Date()
                return
            }

            let workspace = object(from: stateObject["workspace"])
            let sharedConnections = object(from: stateObject["sharedConnections"])
            cachedChatState = mergedChatState(
                workspace: workspace,
                sharedConnections: sharedConnections
            )
            lastRefreshAt = Date()
        } catch {
            cachedChatState = Self.chatStateWithStatus(
                basedOn: cachedChatState,
                status: "Chatflaten bruker siste stabile snapshot.",
                actionSummary: "Kunne ikke hente oppdatert chat akkurat nå: \(error)"
            )
            lastRefreshAt = Date()
        }
    }

    private func mergedChatState(
        workspace: Object?,
        sharedConnections: Object?
    ) -> Object {
        var merged = Self.defaultChatState()

        if let intro = string(from: sharedConnections?["intro"]) {
            merged["intro"] = .string(intro)
        }
        if let chatSummary = string(from: sharedConnections?["chatSummary"]) {
            merged["chatSummary"] = .string(chatSummary)
            merged["recentMessagesSummary"] = .string(chatSummary)
        }
        if let connectionSummary = string(from: sharedConnections?["connectionSummary"]) {
            merged["threadSummary"] = .string(connectionSummary)
            merged["statusSummary"] = .string(connectionSummary)
        }

        let connectionRows = listObjects(from: sharedConnections?["connections"])
        let recentMessageRows = listObjects(from: sharedConnections?["recentMessages"])
        let transcriptRows = Array(recentMessageRows.reversed())
        let effectiveFocusedName = ensureFocusedChatName(in: connectionRows)
        let focusedPersona = resolvedPersona(focusedName: effectiveFocusedName, connectionRows: connectionRows)
        seedDraftIfNeeded(persona: focusedPersona)

        merged["selectionSummary"] = .string(selectionSummary(
            focusedName: effectiveFocusedName,
            connectionCount: connectionRows.count
        ))
        merged["nextStepSummary"] = .string(nextStepSummary(
            focusedName: effectiveFocusedName,
            workspaceNextStep: string(from: workspace?["nextStep"]),
            connectionCount: connectionRows.count
        ))
        merged["actionSummary"] = .string(recentActionSummary)
        merged["recentMessagesSummary"] = .string(transcriptSummary(
            focusedName: effectiveFocusedName,
            messageCount: transcriptRows.count
        ))
        merged["chatSummary"] = .string(transcriptSummary(
            focusedName: effectiveFocusedName,
            messageCount: transcriptRows.count
        ))
        merged["personaSummary"] = .string(personaSummary(persona: focusedPersona))
        merged["personaDetail"] = .string(personaDetail(persona: focusedPersona))
        merged["simulationSummary"] = .string(simulationSummary(persona: focusedPersona))
        merged["focusedThread"] = .object(focusedThreadObject(
            persona: focusedPersona,
            connectionRows: connectionRows,
            messageRows: recentMessageRows
        ))
        merged["draftMessage"] = .string(draftMessage)
        merged["draftSummary"] = .string(draftSummary(focusedName: effectiveFocusedName, connectionCount: connectionRows.count))
        merged["draftHint"] = .string(draftHint(persona: focusedPersona))
        merged["focusedActions"] = .list(focusedActionCards(persona: focusedPersona).map(ValueType.object))
        merged["connections"] = .list(connectionRows.map { connectionCard(from: $0, focusedName: effectiveFocusedName) })
        merged["recentMessages"] = .list(transcriptRows.map(messageCard))
        merged["headline"] = .string(effectiveFocusedName.map { "Chat with \($0)" } ?? "Conference Participant Chat")
        merged["status"] = .string(string(from: merged["statusSummary"]) ?? "Ingen delt tråd er klar ennå.")
        merged["launchSummary"] = .string(string(from: merged["selectionSummary"]) ?? "Start chat fra deltagerportalen for å gjøre en delt tråd klar her.")
        merged["conversationSummary"] = .string(string(from: merged["threadSummary"]) ?? "0 delte tråder synlige.")
        merged["messageSummary"] = .string(string(from: merged["recentMessagesSummary"]) ?? "0 delte meldinger synlige.")
        merged["bridgeSummary"] = .string("HAVEN local adapter exposing ConferenceChatLaunch-style bindings over shared relation-state.")
        merged["nextAction"] = .string(string(from: merged["nextStepSummary"]) ?? "Start en chat i deltagerportalen først.")
        merged["participantsSummary"] = .string(participantSummary(focusedName: effectiveFocusedName, connectionCount: connectionRows.count))
        merged["participants"] = .list(participantRows(focusedName: effectiveFocusedName, persona: focusedPersona, connectionRows: connectionRows).map(ValueType.object))
        merged["conversations"] = .list(connectionRows.map { ValueType.object(conversationRow(from: $0, focusedName: effectiveFocusedName)) })
        merged["messages"] = .list(transcriptRows.map { ValueType.object(messageRow(from: $0)) })
        merged["editorDraft"] = .string(draftMessage)
        merged["editor"] = .object([
            "draft": .string(draftMessage),
            "placeholder": .string("Skriv en fri konferansemelding"),
            "toolingHint": .string("Use conferenceChat.editorDraft, conferenceChat.setDraft and conferenceChat.sendMessage for the canonical participant-chat flow."),
            "setDraftKeypath": .string("conferenceChat.setDraft"),
            "submitKeypath": .string("conferenceChat.sendMessage")
        ])

        return merged
    }

    private func participantSummary(focusedName: String?, connectionCount: Int) -> String {
        if let focusedName {
            return "Delt tråd aktiv med \(focusedName)."
        }
        if connectionCount == 0 {
            return "Ingen delte deltakere synlige ennå."
        }
        if connectionCount == 1 {
            return "1 delt deltaker synlig i aktiv chat."
        }
        return "\(connectionCount) delte deltakere synlige i aktive chatter."
    }

    private func participantRows(
        focusedName: String?,
        persona: ConferenceDemoPersona?,
        connectionRows: [Object]
    ) -> [Object] {
        var rows: [Object] = [[
            "title": .string("Deg"),
            "subtitle": .string("You"),
            "detail": .string("Conference participant using HAVEN"),
            "note": .string("Shared-relation safe sender")
        ]]

        rows.append(contentsOf: connectionRows.map { raw in
            let title = cardTitle(from: raw)
            return [
                "title": .string(title),
                "subtitle": .string(title == focusedName ? "Focused participant" : cardSubtitle(from: raw)),
                "detail": .string(title == focusedName ? (persona?.publicProfileDetail ?? cardDetail(from: raw)) : cardDetail(from: raw)),
                "note": .string(cardNote(from: raw))
            ]
        })

        return rows
    }

    private func conversationRow(from raw: Object, focusedName: String?) -> Object {
        let title = cardTitle(from: raw)
        return [
            "title": .string(title),
            "subtitle": .string(title == focusedName ? "Focused conversation" : cardSubtitle(from: raw)),
            "detail": .string(cardDetail(from: raw)),
            "note": .string(cardNote(from: raw))
        ]
    }

    private func messageRow(from raw: Object) -> Object {
        return [
            "title": .string(cardTitle(from: raw)),
            "subtitle": .string(cardSubtitle(from: raw)),
            "detail": .string(cardDetail(from: raw)),
            "note": .string(cardNote(from: raw))
        ]
    }

    private func ensureFocusedChatName(in connectionRows: [Object]) -> String? {
        if let focusedChatName,
           connectionRows.isEmpty || connectionRows.contains(where: { cardTitle(from: $0) == focusedChatName }) {
            return focusedChatName
        }
        let firstName = connectionRows.first.map { cardTitle(from: $0) }
        focusedChatName = firstName
        return firstName
    }

    private func resolvedPersona(focusedName: String?, connectionRows: [Object]) -> ConferenceDemoPersona? {
        guard let focusedName else { return nil }
        let sourceObject = connectionRows.first(where: { cardTitle(from: $0) == focusedName })
        return conferenceDemoPersona(named: focusedName, source: sourceObject)
    }

    private func selectionSummary(focusedName: String?, connectionCount: Int) -> String {
        if let focusedName {
            return "Viser den delte tråden med \(focusedName)."
        }
        if connectionCount == 0 {
            return "Ingen delt tråd er klar ennå. Start chat i deltagerportalen først."
        }
        return "Velg en delt tråd for å fokusere samtalen her."
    }

    private func nextStepSummary(
        focusedName: String?,
        workspaceNextStep: String?,
        connectionCount: Int
    ) -> String {
        if let focusedName {
            return "Neste steg for \(focusedName) er å sende en kort oppfølging eller gå tilbake til deltagerportalen."
        }
        if connectionCount == 0 {
            return workspaceNextStep ?? "Start en chat fra recommendations, discovery eller nearby for å gjøre chatflaten aktiv."
        }
        return "Velg en delt tråd og fortsett oppfølgingen derfra."
    }

    private func personaSummary(persona: ConferenceDemoPersona?) -> String {
        guard let persona else {
            return "Ingen demo-deltager er valgt ennå."
        }
        return "\(persona.name) · \(persona.roleSummary)"
    }

    private func personaDetail(persona: ConferenceDemoPersona?) -> String {
        guard let persona else {
            return "Når en tråd er valgt, viser vi offentlig profil og samtalestil for demo-deltageren her."
        }
        return persona.publicProfileDetail
    }

    private func simulationSummary(persona: ConferenceDemoPersona?) -> String {
        guard let persona else {
            return "Svarene i demoen er bounded og følger valgt deltagerprofil."
        }
        return persona.simulatedAgentSummary
    }

    private func transcriptSummary(focusedName: String?, messageCount: Int) -> String {
        if let focusedName {
            if messageCount == 0 {
                return "Ingen meldinger synlige ennå i tråden med \(focusedName)."
            }
            if messageCount == 1 {
                return "1 melding synlig i tråden med \(focusedName), eldste først."
            }
            return "\(messageCount) meldinger synlige i tråden med \(focusedName), eldste først."
        }
        if messageCount == 0 {
            return "Ingen delte meldinger synlige ennå."
        }
        if messageCount == 1 {
            return "1 delt melding synlig, eldste først."
        }
        return "\(messageCount) delte meldinger synlige, eldste først."
    }

    private func draftSummary(focusedName: String?, connectionCount: Int) -> String {
        if let focusedName {
            return "Skriv en kort oppfølging til \(focusedName) og send den direkte fra denne flaten."
        }
        if connectionCount == 0 {
            return "Start en chat i deltagerportalen først, så kan du skrive en egen melding her."
        }
        return "Velg en tråd, og skriv deretter en konkret oppfølging i compose-feltet."
    }

    private func draftHint(persona: ConferenceDemoPersona?) -> String {
        if let persona {
            return "Hold meldingen kort og konkret. \(persona.conversationStyle) Svarene i demoen følger denne personaen."
        }
        return "Når en tråd er valgt, kan du skrive en egen melding eller bruke forslagsteksten som utgangspunkt."
    }

    private func focusedThreadObject(
        persona: ConferenceDemoPersona?,
        connectionRows: [Object],
        messageRows: [Object]
    ) -> Object {
        guard let persona,
              let focusedName = Optional(persona.name),
              let connection = connectionRows.first(where: { cardTitle(from: $0) == focusedName }) else {
            return [
                "selectionBadge": .string("VALGT TRÅD"),
                "title": .string("Ingen delt tråd valgt ennå"),
                "subtitle": .string("Conference chat"),
                "detail": .string("Start chat fra deltagerportalen eller velg en delt tråd fra listen under."),
                "note": .string("Når en tråd er valgt, viser vi siste oppsummering og neste steg her."),
                "nextMessage": .string("Velg en delt tråd for å se forslag til neste melding."),
                "nextMessageHint": .string("Når tråden er klar, kan du skrive en egen melding eller sende forslagsteksten herfra.")
            ]
        }

        let latestMessage = messageRows.first.flatMap { string(from: $0["detail"]) }
        let note = latestMessage.map { "Siste melding: \($0)" }
            ?? "Ingen melding sendt ennå. Send en kort oppfølging for å gjøre chatten tydelig i demoen."
        let suggestedNextMessage = persona.suggestedOpening

        return [
            "selectionBadge": .string("VALGT TRÅD"),
            "title": .string(cardTitle(from: connection)),
            "subtitle": .string(cardSubtitle(from: connection)),
            "detail": .string(cardDetail(from: connection)),
            "note": .string(note),
            "nextMessage": .string(suggestedNextMessage),
            "nextMessageHint": .string("Bruk compose-feltet under for å skrive en egen melding, eller send forslagsteksten med ett trykk. Demo-svaret holder seg til \(persona.roleSummary.lowercased()).")
        ]
    }

    private func focusedActionCards(persona: ConferenceDemoPersona?) -> [Object] {
        guard let persona else {
            return []
        }
        let focusedName = persona.name

        let sendAction: Object = [
            "title": .string("Send forslag"),
            "subtitle": .string("Bruk standardsvaret"),
            "detail": .string("Send en ferdig oppfølgingsmelding til \(focusedName) hvis du vil demonstrere flyten raskt."),
            "note": .string("Bruk compose-feltet over hvis du vil skrive en egen melding."),
            "keypath": .string("chatSnapshot.dispatchAction"),
            "label": .string("Send forslag"),
            "payload": .object([
                "keypath": .string("connections.postSharedMessage"),
                "payload": .object([
                    "text": .string(persona.suggestedOpening),
                    "contentType": .string("text/plain")
                ])
            ])
        ]

        let meetingAction: Object = [
            "title": .string("Be om møte"),
            "subtitle": .string("Foreslå neste steg"),
            "detail": .string("Be om møte med \(focusedName) når chatten ser relevant ut."),
            "note": .string("Dette binder chat og scheduling sammen i samme conference-flyt."),
            "keypath": .string("chatSnapshot.dispatchAction"),
            "label": .string("Be om møte"),
            "payload": .object([
                "keypath": .string("scheduling.createMeetingRequest"),
                "payload": .object([
                    "source": .string("binding-chat-snapshot"),
                    "displayName": .string(focusedName)
                ])
            ])
        ]

        return [sendAction, meetingAction]
    }

    private func connectionCard(from raw: Object, focusedName: String?) -> ValueType {
        let title = cardTitle(from: raw)
        let isFocused = focusedName == title
        let note = cardNote(from: raw)
        let updatedNote = isFocused ? "\(note) · Vises i chatflaten nå." : "\(note) · Velg tråden for å fokusere den her."
        return .object([
            "title": .string(title),
            "subtitle": .string(cardSubtitle(from: raw)),
            "detail": .string(cardDetail(from: raw)),
            "note": .string(updatedNote),
            "keypath": .string("chatSnapshot.dispatchAction"),
            "label": .string(isFocused ? "Valgt tråd" : "Vis tråd"),
            "payload": .object([
                "keypath": .string("chat.focusThread"),
                "payload": .object([
                    "displayName": .string(title)
                ])
            ])
        ])
    }

    private func messageCard(from raw: Object) -> ValueType {
        let title = cardTitle(from: raw)
        return .object([
            "title": .string(title),
            "subtitle": .string(cardSubtitle(from: raw)),
            "detail": .string(cardDetail(from: raw)),
            "note": .string(cardNote(from: raw)),
            "senderInitials": .string(senderInitials(for: title))
        ])
    }

    private func senderInitials(for title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "?" }
        if trimmed == "Deg" {
            return "DU"
        }

        let components = trimmed
            .split(whereSeparator: \.isWhitespace)
            .prefix(2)
            .compactMap { $0.first }

        let initials = String(components).uppercased()
        return initials.isEmpty ? String(trimmed.prefix(1)).uppercased() : initials
    }

    private func draftText(from value: ValueType) -> String? {
        if case let .string(text) = value {
            return text
        }
        if case let .object(object) = value,
           case let .string(text)? = object["text"] {
            return text
        }
        return nil
    }

    private func sendDraftMessage(requester: Identity) async -> ValueType {
        let outgoingText = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard outgoingText.isEmpty == false else {
            cachedChatState = Self.chatStateWithStatus(
                basedOn: mergedChatState(from: cachedChatState),
                status: "Skriv en melding før du sender.",
                actionSummary: "Meldingsutkastet var tomt."
            )
            return .object([
                "status": .string("error"),
                "state": .object(cachedChatState)
            ])
        }

        let focusedName = focusedChatName ?? "delt tråd"
        let forwardedAction: ValueType = .object([
            "keypath": .string("connections.postSharedMessage"),
            "payload": .object([
                "text": .string(outgoingText),
                "contentType": .string("text/plain")
            ])
        ])

        recentActionSummary = "Sender meldingen til \(focusedName)…"
        guard await BindingLocalCellRegistration.shared.ensureConferenceDemoRuntimeReady() else {
            recentActionSummary = "Kunne ikke sende meldingen fordi runtime-validering feilet."
            return .object([
                "status": .string("error"),
                "state": .object(cachedChatState)
            ])
        }

        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let previewShell = try? await resolver.cellAtEndpoint(
                endpoint: "cell:///ConferenceParticipantPreviewShell",
                requester: requester
              ) as? Meddle else {
            cachedChatState = Self.chatStateWithStatus(
                basedOn: mergedChatState(from: cachedChatState),
                status: "Chatflaten bruker siste lokale snapshot fordi deltager-preview ikke er tilgjengelig.",
                actionSummary: "Kunne ikke sende meldingen akkurat nå."
            )
            return .object([
                "status": .string("error"),
                "state": .object(cachedChatState)
            ])
        }

        do {
            let mutationResult = try await previewShell.set(
                keypath: "dispatchAction",
                value: forwardedAction,
                requester: requester
            )
            if let errorDescription = mutationErrorDescription(from: mutationResult) {
                cachedChatState = Self.chatStateWithStatus(
                    basedOn: mergedChatState(from: cachedChatState),
                    status: "Chatflaten beholdt meldingsutkastet fordi sendingen feilet.",
                    actionSummary: errorDescription
                )
                return .object([
                    "status": .string("error"),
                    "state": .object(cachedChatState)
                ])
            }

            draftMessage = ""
            draftSeedName = focusedName
            recentActionSummary = "Sendte meldingen til \(focusedName). Demo-personaen svarte i samme tråd."

            let stateValue = try await previewShell.get(keypath: "state", requester: requester)
            guard case let .object(stateObject) = stateValue else {
                cachedChatState = Self.chatStateWithStatus(
                    basedOn: mergedChatState(from: cachedChatState),
                    status: "Meldingen ble sendt, men chatflaten fikk ikke lest nytt snapshot.",
                    actionSummary: "Bruker siste stabile data."
                )
                return .object([
                    "status": .string("ok"),
                    "state": .object(cachedChatState)
                ])
            }

            let workspace = object(from: stateObject["workspace"])
            let sharedConnections = object(from: stateObject["sharedConnections"])
            cachedChatState = mergedChatState(
                workspace: workspace,
                sharedConnections: sharedConnections
            )
            lastRefreshAt = Date()
            return .object([
                "status": .string("ok"),
                "state": .object(cachedChatState)
            ])
        } catch {
            cachedChatState = Self.chatStateWithStatus(
                basedOn: mergedChatState(from: cachedChatState),
                status: "Chatflaten beholdt meldingsutkastet fordi sendingen feilet.",
                actionSummary: "Kunne ikke sende meldingen akkurat nå: \(error)"
            )
            return .object([
                "status": .string("error"),
                "state": .object(cachedChatState)
            ])
        }
    }

    private func ensureSharedThreadReady(requester: Identity) async -> Bool {
        guard await BindingLocalCellRegistration.shared.ensureConferenceDemoRuntimeReady() else {
            recentActionSummary = "Kunne ikke åpne chatflaten fordi runtime-validering feilet."
            return false
        }

        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let previewShell = try? await resolver.cellAtEndpoint(
                endpoint: "cell:///ConferenceParticipantPreviewShell",
                requester: requester
              ) as? Meddle else {
            recentActionSummary = "Kunne ikke åpne chatflaten fordi deltager-preview ikke er tilgjengelig."
            cachedChatState = Self.chatStateWithStatus(
                basedOn: mergedChatState(from: cachedChatState),
                status: "Chatflaten bruker siste lokale snapshot fordi deltager-preview ikke er tilgjengelig.",
                actionSummary: recentActionSummary
            )
            return false
        }

        let currentState = try? await previewShell.get(keypath: "state", requester: requester)
        if let currentObject = object(from: currentState),
           let workspace = object(from: currentObject["workspace"]),
           let sharedConnections = object(from: currentObject["sharedConnections"]) {
            cachedChatState = mergedChatState(workspace: workspace, sharedConnections: sharedConnections)
            let sharedNames = conferenceSharedConnectionNames(from: sharedConnections)
            if let focusedChatName, sharedNames.contains(focusedChatName) {
                recentActionSummary = "Chatten med \(focusedChatName) er klar."
                cachedChatState = mergedChatState(from: cachedChatState)
                return true
            }
            if let firstSharedName = sharedNames.first {
                focusedChatName = firstSharedName
                await rememberSelectedParticipant(firstSharedName)
                recentActionSummary = "Viser den delte tråden med \(firstSharedName)."
                cachedChatState = mergedChatState(from: cachedChatState)
                return true
            }
        }

        guard let bootstrapTarget = focusedChatName?.trimmingCharacters(in: .whitespacesAndNewlines),
              bootstrapTarget.isEmpty == false else {
            recentActionSummary = "Velg en deltager i portalen eller trykk Start chat før du åpner chatflaten."
            cachedChatState = Self.chatStateWithStatus(
                basedOn: mergedChatState(from: cachedChatState),
                status: "Ingen delt tråd er klar ennå.",
                actionSummary: recentActionSummary
            )
            return false
        }

        let persona = conferenceDemoPersona(named: bootstrapTarget)
        let bootstrapAction: ValueType = .object([
            "keypath": .string("discovery.startChat"),
            "payload": .object([
                "source": .string("binding-chat-workbench"),
                "targets": .list([
                    .object([
                        "displayName": .string(bootstrapTarget),
                        "headline": .string(persona.roleSummary)
                    ])
                ])
            ])
        ])

        recentActionSummary = "Gjør chatten med \(bootstrapTarget) klar…"
        let mutationResult = try? await previewShell.set(
            keypath: "dispatchAction",
            value: bootstrapAction,
            requester: requester
        )
        if let errorDescription = mutationErrorDescription(from: mutationResult) {
            recentActionSummary = errorDescription
            cachedChatState = Self.chatStateWithStatus(
                basedOn: mergedChatState(from: cachedChatState),
                status: "Chatflaten beholdt siste stabile snapshot fordi chatten ikke ble klar.",
                actionSummary: recentActionSummary
            )
            return false
        }

        let refreshedState = try? await previewShell.get(keypath: "state", requester: requester)
        guard let refreshedObject = object(from: refreshedState),
              let refreshedWorkspace = object(from: refreshedObject["workspace"]),
              let refreshedConnections = object(from: refreshedObject["sharedConnections"]) else {
            recentActionSummary = "Chatten med \(bootstrapTarget) ble ikke klar ennå. Prøv Start chat i portalen igjen."
            cachedChatState = Self.chatStateWithStatus(
                basedOn: mergedChatState(from: cachedChatState),
                status: "Ingen delt tråd er klar ennå.",
                actionSummary: recentActionSummary
            )
            return false
        }

        cachedChatState = mergedChatState(workspace: refreshedWorkspace, sharedConnections: refreshedConnections)
        let refreshedNames = conferenceSharedConnectionNames(from: refreshedConnections)
        if refreshedNames.contains(bootstrapTarget) {
            focusedChatName = bootstrapTarget
            await rememberSelectedParticipant(bootstrapTarget)
            recentActionSummary = "Chatten med \(bootstrapTarget) er klar."
            cachedChatState = mergedChatState(from: cachedChatState)
            return true
        }

        if let firstSharedName = refreshedNames.first {
            focusedChatName = firstSharedName
            await rememberSelectedParticipant(firstSharedName)
        }
        recentActionSummary = "Chatten med \(bootstrapTarget) ble ikke klar ennå. Prøv Start chat i portalen igjen."
        cachedChatState = Self.chatStateWithStatus(
            basedOn: mergedChatState(from: cachedChatState),
            status: "Ingen delt tråd er klar ennå.",
            actionSummary: recentActionSummary
        )
        return false
    }

    private func openChatWorkbench(requester: Identity) async -> ValueType {
        let displayName = focusedChatName.map { "Conference Participant Chat · \($0)" } ?? "Conference Participant Chat"
        let configuration = ConfigurationCatalogCell.conferenceParticipantChatWorkbenchConfiguration(
            participantEndpoint: "cell:///ConferenceParticipantPreviewShell",
            displayName: displayName,
            summary: "Conference participant chat aligned with ConferenceChatLaunch for shared messages, free-text follow-up and explicit next steps."
        )
        return await loadWorkbenchConfiguration(
            configuration,
            requester: requester,
            successSummary: "Åpnet chatflaten i egen arbeidsflate."
        )
    }

    private func openParticipantPortalWorkbench(requester: Identity) async -> ValueType {
        recentActionSummary = "Går tilbake til deltagerportalen…"
        cachedChatState = mergedChatState(from: cachedChatState)
        await MainActor.run {
            BindingConferenceNavigationBridge.postPop(
                fallbackConfiguration: ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
                    endpoint: "cell:///ConferenceParticipantPreviewShell"
                )
            )
        }
        recentActionSummary = "Tilbake i deltagerportalen."
        cachedChatState = Self.chatStateWithStatus(
            basedOn: cachedChatState,
            status: "Chatflaten lukket. Deltagerportalen er aktiv igjen.",
            actionSummary: recentActionSummary
        )
        return .object([
            "status": .string("ok"),
            "state": .object(cachedChatState)
        ])
    }

    private func loadWorkbenchConfiguration(
        _ configuration: CellConfiguration,
        requester: Identity,
        successSummary: String
    ) async -> ValueType {
        recentActionSummary = "Åpner chatflaten…"
        cachedChatState = mergedChatState(from: cachedChatState)
        scheduleWorkbenchLoad(configuration, requester: requester, successSummary: successSummary)
        return .object([
            "status": .string("ok"),
            "state": .object(cachedChatState)
        ])
    }

    private func scheduleWorkbenchLoad(
        _ configuration: CellConfiguration,
        requester: Identity,
        successSummary: String
    ) {
        Task { @MainActor [weak self] in
            BindingPortholeLoadBridge.post(configuration: configuration)
            self?.recentActionSummary = successSummary
            if let self {
                self.cachedChatState = Self.chatStateWithStatus(
                    basedOn: self.cachedChatState,
                    status: "Chatflaten åpnes i egen arbeidsflate.",
                    actionSummary: successSummary
                )
            }
        }
    }

    private func mergedChatState(from object: Object) -> Object {
        var merged = object
        merged["actionSummary"] = .string(recentActionSummary)
        let focusedName = self.object(from: merged["focusedThread"]).flatMap { string(from: $0["title"]) }
        let normalizedFocusedName = (focusedName == "Ingen delt tråd valgt ennå") ? nil : focusedName
        let focusedPersona = normalizedFocusedName.map { conferenceDemoPersona(named: $0) }
        seedDraftIfNeeded(persona: focusedPersona)
        let connectionCount = listObjects(from: merged["connections"]).count
        merged["draftMessage"] = .string(draftMessage)
        merged["draftSummary"] = .string(draftSummary(focusedName: normalizedFocusedName, connectionCount: connectionCount))
        merged["draftHint"] = .string(draftHint(persona: focusedPersona))
        merged["status"] = .string(string(from: merged["statusSummary"]) ?? "Ingen delt tråd er klar ennå.")
        merged["launchSummary"] = .string(string(from: merged["selectionSummary"]) ?? "Start chat fra deltagerportalen for å gjøre en delt tråd klar her.")
        merged["conversationSummary"] = .string(string(from: merged["threadSummary"]) ?? "0 delte tråder synlige.")
        merged["messageSummary"] = .string(string(from: merged["recentMessagesSummary"]) ?? "0 delte meldinger synlige.")
        merged["nextAction"] = .string(string(from: merged["nextStepSummary"]) ?? "Start en chat i deltagerportalen først.")
        merged["editorDraft"] = .string(draftMessage)
        merged["editor"] = .object([
            "draft": .string(draftMessage),
            "placeholder": .string("Skriv en fri konferansemelding"),
            "toolingHint": .string("Use conferenceChat.editorDraft, conferenceChat.setDraft and conferenceChat.sendMessage for the canonical participant-chat flow."),
            "setDraftKeypath": .string("conferenceChat.setDraft"),
            "submitKeypath": .string("conferenceChat.sendMessage")
        ])
        return merged
    }

    private func listObjects(from value: ValueType?) -> [Object] {
        guard case let .list(values)? = value else { return [] }
        return values.compactMap {
            guard case let .object(object) = $0 else { return nil }
            return object
        }
    }

    private func cardTitle(from object: Object) -> String {
        string(from: object["title"]) ??
        string(from: object["displayName"]) ??
        "Delt tråd"
    }

    private func cardSubtitle(from object: Object) -> String {
        string(from: object["subtitle"]) ?? "Conference chat"
    }

    private func cardDetail(from object: Object) -> String {
        string(from: object["detail"]) ?? "Ingen detalj tilgjengelig ennå."
    }

    private func cardNote(from object: Object) -> String {
        string(from: object["note"]) ?? "Ingen ekstra chat-kontekst tilgjengelig ennå."
    }

    private func string(from value: ValueType?) -> String? {
        guard let value else { return nil }
        switch value {
        case let .string(string):
            return string
        case let .integer(integer):
            return String(integer)
        case let .number(number):
            return String(number)
        case let .float(float):
            return String(float)
        case let .bool(bool):
            return bool ? "true" : "false"
        default:
            return nil
        }
    }

    private func object(from value: ValueType?) -> Object? {
        guard case let .object(object)? = value else { return nil }
        return object
    }

    private func mutationErrorDescription(from value: ValueType?) -> String? {
        conferenceMutationErrorDescription(from: value)
    }

    private func restoreSelectedParticipantIfAvailable() async {
        guard focusedChatName == nil,
              let storedSelection = await selectedParticipantFromStore() else {
            return
        }
        focusedChatName = storedSelection
    }

    private func selectedParticipantFromStore() async -> String? {
        guard !storeKey.isEmpty,
              let storedSelection = await ConferenceParticipantSelectionStore.shared.load(for: storeKey) else {
            return nil
        }
        let trimmed = storedSelection.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func rememberSelectedParticipant(_ displayName: String?) async {
        guard !storeKey.isEmpty else { return }
        await ConferenceParticipantSelectionStore.shared.save(displayName, for: storeKey)
    }

    private func seedDraftIfNeeded(persona: ConferenceDemoPersona?) {
        guard let persona else {
            if draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draftSeedName = nil
            }
            return
        }
        guard draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        guard draftSeedName != persona.name else {
            return
        }
        draftMessage = persona.suggestedOpening
        draftSeedName = persona.name
    }

    private static func chatStateWithStatus(
        basedOn base: Object,
        status: String,
        actionSummary: String
    ) -> Object {
        var updated = base
        updated["statusSummary"] = .string(status)
        updated["status"] = .string(status)
        updated["actionSummary"] = .string(actionSummary)
        return updated
    }

    private static func defaultChatState() -> Object {
        [
            "headline": .string("Conference Participant Chat"),
            "intro": .string("Denne flaten viser når en conference-chat faktisk er klar, og gjør det tydelig hvordan du fortsetter oppfølgingen."),
            "statusSummary": .string("Ingen delt tråd er klar ennå."),
            "status": .string("Ingen delt tråd er klar ennå."),
            "selectionSummary": .string("Start chat fra deltagerportalen for å gjøre en delt tråd klar her."),
            "launchSummary": .string("Start chat fra deltagerportalen for å gjøre en delt tråd klar her."),
            "nextStepSummary": .string("Når en delt tråd finnes, kan du sende oppfølging eller gå tilbake til portalen."),
            "nextAction": .string("Når en delt tråd finnes, kan du sende oppfølging eller gå tilbake til portalen."),
            "actionSummary": .string("Start chat fra deltagerportalen for å gjøre en delt tråd klar her."),
            "threadSummary": .string("0 delte tråder synlige."),
            "conversationSummary": .string("0 delte tråder synlige."),
            "recentMessagesSummary": .string("0 delte meldinger synlige."),
            "messageSummary": .string("0 delte meldinger synlige."),
            "chatSummary": .string("0 delte meldinger synlige."),
            "bridgeSummary": .string("HAVEN local adapter exposing ConferenceChatLaunch-style bindings over shared relation-state."),
            "personaSummary": .string("Ingen demo-deltager er valgt ennå."),
            "personaDetail": .string("Når en tråd er valgt, viser vi offentlig profil og samtalestil for demo-deltageren her."),
            "simulationSummary": .string("Svarene i demoen er bounded og følger valgt deltagerprofil."),
            "draftMessage": .string(""),
            "editorDraft": .string(""),
            "draftSummary": .string("Start en chat i deltagerportalen først, så kan du skrive en egen melding her."),
            "draftHint": .string("Når en tråd er valgt, kan du skrive en egen melding eller bruke forslagsteksten som utgangspunkt."),
            "participantsSummary": .string("Ingen delte deltakere synlige ennå."),
            "focusedThread": .object([
                "selectionBadge": .string("VALGT TRÅD"),
                "title": .string("Ingen delt tråd valgt ennå"),
                "subtitle": .string("Conference chat"),
                "detail": .string("Start chat fra deltagerportalen eller velg en delt tråd når en blir synlig."),
                "note": .string("Når en tråd er valgt, viser vi siste oppsummering og neste steg her."),
                "nextMessage": .string("Velg en delt tråd for å se forslag til neste melding."),
                "nextMessageHint": .string("Når tråden er klar, kan du skrive en egen melding eller sende forslagsteksten herfra.")
            ]),
            "editor": .object([
                "draft": .string(""),
                "placeholder": .string("Skriv en fri konferansemelding"),
                "toolingHint": .string("Use conferenceChat.editorDraft, conferenceChat.setDraft and conferenceChat.sendMessage for the canonical participant-chat flow."),
                "setDraftKeypath": .string("conferenceChat.setDraft"),
                "submitKeypath": .string("conferenceChat.sendMessage")
            ]),
            "focusedActions": .list([]),
            "participants": .list([]),
            "conversations": .list([]),
            "messages": .list([]),
            "connections": .list([]),
            "recentMessages": .list([])
        ]
    }
}

struct ConferenceIdentityLinkParsedChallenge {
    var requestID: String?
    var purpose: String
    var audience: String?
    var origin: String?
    var entityAnchorReference: String?
    var deviceLabel: String?
    var identityLabel: String?
    var requestedDomains: [String]
    var requestedIdentityContexts: [String]
    var requestedScopes: [String]
    var expiresAt: String?
    var challenge: String?
    var proofAlgorithm: String?
    var sourceSummary: String
    var statusSummary: String
    var challengeSummary: String
    var audienceSummary: String
    var originSummary: String
    var entitySummary: String
    var deviceSummary: String
    var domainSummary: String
    var contextSummary: String
    var scopeSummary: String
    var expirySummary: String
    var proofSummary: String
    var rawPreview: String
    var admission: BindingAdmissionChallengeSnapshot?
}

nonisolated enum ConferenceIdentityLinkSupport {
    private static let emptySummary = "Ingen challenge lastet ennå."
    private static let maximumDeepLinkLength = 8_192
    private static let maximumRawPayloadLength = 131_072
    private static let maximumListItems = 32

    static func parse(url: URL) -> ConferenceIdentityLinkParsedChallenge? {
        guard url.absoluteString.utf8.count <= maximumDeepLinkLength else {
            return nil
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let scheme = components.scheme?.lowercased()
        let host = components.host?.lowercased()
        let normalizedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        let matchesIdentityLinkRoute = scheme == "haven" && (
            (host == "identity-link" && normalizedPath.isEmpty)
                || (host == nil && normalizedPath == "identity-link")
                || (host == "binding" && normalizedPath == "add-device")
        )

        guard matchesIdentityLinkRoute else {
            return nil
        }

        var queryMap: [String: String] = [:]
        for item in components.queryItems ?? [] {
            let key = item.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard key.isEmpty == false, queryMap[key] == nil,
                  let value = item.value,
                  value.utf8.count <= maximumRawPayloadLength else {
                return nil
            }
            queryMap[key] = value
        }
        if let payload = queryMap["payload"] ?? queryMap["request"],
           let parsed = parse(raw: payload, sourceSummary: "Deep link fra \(host ?? "ukjent vert")") {
            return parsed
        }

        return buildChallenge(
            sourceSummary: "Deep link fra \(host ?? "lokal app-lenke")",
            requestID: queryMap["requestid"] ?? queryMap["request_id"],
            purpose: queryMap["purpose"] ?? "link_identity",
            audience: queryMap["audience"],
            origin: queryMap["origin"] ?? "haven://identity-link",
            entityAnchorReference: queryMap["entityanchorreference"] ?? queryMap["entity"],
            deviceLabel: queryMap["devicelabel"] ?? queryMap["device"],
            identityLabel: queryMap["displayname"] ?? queryMap["identity"],
            requestedDomains: splitCSV(queryMap["domains"]),
            requestedIdentityContexts: splitCSV(queryMap["contexts"]),
            requestedScopes: splitCSV(queryMap["scopes"]),
            expiresAt: queryMap["expiresat"] ?? queryMap["expires_at"],
            challenge: queryMap["challenge"] ?? queryMap["nonce"],
            proofAlgorithm: queryMap["algorithm"],
            rawPreview: "haven://\(host ?? "identity-link")/\(normalizedPath)"
        )
    }

    static func parse(raw: String, sourceSummary: String = "Innlimt challenge-data") -> ConferenceIdentityLinkParsedChallenge? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf8.count <= maximumRawPayloadLength else { return nil }

        if let url = URL(string: trimmed),
           let parsedURL = parse(url: url) {
            return parsedURL
        }

        if let decodedPayload = decodePotentialBase64URL(trimmed),
           let decodedText = String(data: decodedPayload, encoding: .utf8),
           let parsedDecoded = parseJSONObjectString(decodedText, sourceSummary: sourceSummary) {
            return parsedDecoded
        }

        return parseJSONObjectString(trimmed, sourceSummary: sourceSummary)
    }

    private static func parseJSONObjectString(_ value: String, sourceSummary: String) -> ConferenceIdentityLinkParsedChallenge? {
        guard value.utf8.count <= maximumRawPayloadLength,
              let data = value.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let typedAdmission = BindingAdmissionChallengeSupport.decodePayload(from: value).map(BindingAdmissionChallengeSnapshot.init)

        return buildChallenge(
            sourceSummary: sourceSummary,
            requestID: string(in: json, path: ["requestId"]),
            purpose: string(in: json, path: ["purpose"]) ?? "link_identity",
            audience: string(in: json, path: ["audience"]),
            origin: string(in: json, path: ["origin"]),
            entityAnchorReference: string(in: json, path: ["entityAnchorReference"]),
            deviceLabel: string(in: json, path: ["device", "label"]),
            identityLabel: string(in: json, path: ["newIdentity", "displayName"]),
            requestedDomains: strings(in: json, path: ["requestedDomains"]),
            requestedIdentityContexts: strings(in: json, path: ["requestedIdentityContexts"]),
            requestedScopes: strings(in: json, path: ["requestedScopes"]),
            expiresAt: string(in: json, path: ["expiresAt"]),
            challenge: string(in: json, path: ["nonce"]),
            proofAlgorithm: string(in: json, path: ["proof", "algorithm"]),
            admission: typedAdmission,
            rawPreview: value
        )
    }

    private static func buildChallenge(
        sourceSummary: String,
        requestID: String?,
        purpose: String,
        audience: String?,
        origin: String?,
        entityAnchorReference: String?,
        deviceLabel: String?,
        identityLabel: String?,
        requestedDomains: [String],
        requestedIdentityContexts: [String],
        requestedScopes: [String],
        expiresAt: String?,
        challenge: String?,
        proofAlgorithm: String?,
        admission: BindingAdmissionChallengeSnapshot? = nil,
        rawPreview: String
    ) -> ConferenceIdentityLinkParsedChallenge {
        let effectiveAudience = audience?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveOrigin = origin?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveRequestID = requestID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveChallenge = challenge?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveDeviceLabel = deviceLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveIdentityLabel = identityLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveEntity = entityAnchorReference?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveExpiresAt = expiresAt?.trimmingCharacters(in: .whitespacesAndNewlines)

        let challengeSummary: String
        if let effectiveRequestID, !effectiveRequestID.isEmpty {
            challengeSummary = "Request \(effectiveRequestID)"
        } else if let effectiveChallenge, !effectiveChallenge.isEmpty {
            challengeSummary = "Challenge \(effectiveChallenge)"
        } else if let admissionSessionID = admission?.sessionId,
                  !admissionSessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            challengeSummary = "Admission session \(admissionSessionID)"
        } else {
            challengeSummary = Self.emptySummary
        }

        let compactPreview = rawPreview
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let admissionStatusSummary: String?
        if let admissionObject = admission?.asObject(),
           case let .string(value)? = admissionObject["statusSummary"] {
            admissionStatusSummary = value
        } else {
            admissionStatusSummary = nil
        }

        return ConferenceIdentityLinkParsedChallenge(
            requestID: effectiveRequestID,
            purpose: purpose,
            audience: effectiveAudience,
            origin: effectiveOrigin,
            entityAnchorReference: effectiveEntity,
            deviceLabel: effectiveDeviceLabel,
            identityLabel: effectiveIdentityLabel,
            requestedDomains: requestedDomains,
            requestedIdentityContexts: requestedIdentityContexts,
            requestedScopes: requestedScopes,
            expiresAt: effectiveExpiresAt,
            challenge: effectiveChallenge,
            proofAlgorithm: proofAlgorithm,
            sourceSummary: sourceSummary,
            statusSummary: admissionStatusSummary
                ?? "Incoming identity-link challenge klar for review. HAVEN viser challenge-data og lokal key-possession før scaffold/web fullfører approval.",
            challengeSummary: challengeSummary,
            audienceSummary: effectiveAudience.map { "Audience: \($0)" } ?? "Audience mangler i challenge-data.",
            originSummary: effectiveOrigin.map { "Origin: \($0)" } ?? "Origin mangler i challenge-data.",
            entitySummary: effectiveEntity.map { "Entity anchor: \($0)" } ?? "Entity anchor ikke oppgitt i challenge-data.",
            deviceSummary: {
                let identityPart = effectiveIdentityLabel.map { "Ny HAVEN-identitet: \($0)" } ?? "Ny HAVEN-identitet ikke navngitt ennå."
                let devicePart = effectiveDeviceLabel.map { "Device: \($0)" } ?? "Device label mangler."
                return "\(identityPart) · \(devicePart)"
            }(),
            domainSummary: requestedDomains.isEmpty ? "Ingen requested domains oppgitt." : "Requested domains: \(requestedDomains.joined(separator: ", "))",
            contextSummary: requestedIdentityContexts.isEmpty ? "Ingen requested identity contexts oppgitt." : "Requested contexts: \(requestedIdentityContexts.joined(separator: ", "))",
            scopeSummary: requestedScopes.isEmpty ? "Ingen requested scopes oppgitt." : "Requested scopes: \(requestedScopes.joined(separator: ", "))",
            expirySummary: effectiveExpiresAt.map { "Expires: \($0)" } ?? "Expiry mangler i challenge-data.",
            proofSummary: {
                var components = ["Purpose: \(purpose)", "Proof alg: \(proofAlgorithm ?? "ikke oppgitt")"]
                if let requiredAction = admission?.requiredAction,
                   !requiredAction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    components.append("Required action: \(requiredAction)")
                }
                return components.joined(separator: " · ")
            }(),
            rawPreview: compactPreview.isEmpty ? Self.emptySummary : compactPreview,
            admission: admission
        )
    }

    private static func splitCSV(_ value: String?) -> [String] {
        guard let value else { return [] }
        let values = value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard values.count <= maximumListItems,
              values.allSatisfy({ $0.utf8.count <= 256 }) else {
            return []
        }
        return values
    }

    private static func decodePotentialBase64URL(_ value: String) -> Data? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var normalized = trimmed
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while normalized.count % 4 != 0 {
            normalized.append("=")
        }
        return Data(base64Encoded: normalized)
    }

    private static func string(in object: [String: Any], path: [String]) -> String? {
        var current: Any = object
        for component in path {
            guard let dictionary = current as? [String: Any],
                  let next = dictionary[component] else {
                return nil
            }
            current = next
        }
        return current as? String
    }

    private static func strings(in object: [String: Any], path: [String]) -> [String] {
        var current: Any = object
        for component in path {
            guard let dictionary = current as? [String: Any],
                  let next = dictionary[component] else {
                return []
            }
            current = next
        }
        guard let values = current as? [Any], values.count <= maximumListItems else { return [] }
        let strings = values.compactMap { $0 as? String }
        guard strings.count == values.count,
              strings.allSatisfy({ $0.utf8.count <= 256 }) else {
            return []
        }
        return strings
    }
}

actor ConferenceIdentityLinkInboxStore {
    static let shared = ConferenceIdentityLinkInboxStore()

    private var draftInput = ""
    private var incomingChallenge: ConferenceIdentityLinkParsedChallenge?
    private var localIdentitySummary = "Ingen lokal HAVEN-identitet er bekreftet i denne flaten ennå."
    private var confirmationStatus = "Lokal brukerbekreftelse mangler."
    private var actionSummary = "Åpne en haven://identity-link-lenke eller lim inn challenge-data for å starte review."
    private var lastIntakeSource = "Ingen challenge mottatt ennå."
    private var localProofSummary = "Ingen signert IdentityEnrollmentRequest er laget ennå."
    private var enrollmentRequestPreview = "Ingen enrollment request klar ennå."
    private var enrollmentRequestValue: ValueType = .null
    private var signedEnrollmentRequestHash: String?
    private var completionPackageInput = ""
    private var completionStatus = "Ingen completion package er importert ennå."
    private var completionSummary = "Lim inn en ekte CellProtocol IdentityLinkCompletionEnvelope fra staging når approval, SameEntityIdentityLinkCredential og verifier-bound VP er laget."
    private var completionRecordPreview = "Ingen active IdentityLinkRecord er skrevet ennå."
    private var limitationSummary = "HAVEN gjør ekte challenge-intake, signerer CellProtocol IdentityEnrollmentRequest lokalt og fullfører bare mot EntityAnchor identityLinks når staging leverer en verifiserbar completion envelope."
    private var nextStepSummary = "Når requesten er signert, godkjenn den i staging og lim inn completion envelope her for å skrive IdentityLinkRecord uten demo-bypass."

    private func defaultAdmissionState() -> Object {
        [
            "statusSummary": .string("Ingen typed admission challenge lest ennå."),
            "state": .string("unknown"),
            "connectState": .string("unknown"),
            "issueCount": .integer(0),
            "issueSummary": .string("0 challenge-issues registrert."),
            "requiredActionSummary": .string("Ingen requiredAction oppgitt i challenge payload."),
            "userMessage": .string("Ingen typed userMessage i challenge payload."),
            "autoResolveSummary": .string("Challenge krever eksplisitt review eller remediation."),
            "helperSummary": .string("Ingen helper-konfigurasjon fulgte med challenge payload."),
            "retrySummary": .string("Ingen admission retry-request tilgjengelig."),
            "sessionSummary": .string("Ingen admission-session eksponert i challenge payload.")
        ]
    }

    func ingest(url: URL) -> Bool {
        guard let parsed = ConferenceIdentityLinkSupport.parse(url: url) else {
            return false
        }
        resetDerivedStateForNewChallenge()
        incomingChallenge = parsed
        lastIntakeSource = parsed.sourceSummary
        actionSummary = "Lastet challenge-data fra deep link. Kontroller audience, scopes og lokal identitet før du går videre."
        nextStepSummary = "Signer lokal CellProtocol IdentityEnrollmentRequest i HAVEN, godkjenn den i staging, og lim inn completion envelope her."
        return true
    }

    func setDraftInput(_ input: String) {
        draftInput = input
    }

    func setCompletionPackageInput(_ input: String) {
        completionPackageInput = input
    }

    func importDraft() -> Bool {
        guard let parsed = ConferenceIdentityLinkSupport.parse(raw: draftInput) else {
            actionSummary = "Klarte ikke å tolke innlimt challenge-data."
            return false
        }
        resetDerivedStateForNewChallenge()
        incomingChallenge = parsed
        lastIntakeSource = parsed.sourceSummary
        actionSummary = "Tolket challenge-data fra innlimt payload. Kontroller audience, scopes og origin før du går videre."
        nextStepSummary = "Signer lokal CellProtocol IdentityEnrollmentRequest i HAVEN, godkjenn den i staging, og lim inn completion envelope her."
        return true
    }

    func clear() {
        draftInput = ""
        incomingChallenge = nil
        localIdentitySummary = "Ingen lokal HAVEN-identitet er bekreftet i denne flaten ennå."
        confirmationStatus = "Lokal brukerbekreftelse mangler."
        actionSummary = "Åpne en haven://identity-link-lenke eller lim inn challenge-data for å starte review."
        lastIntakeSource = "Ingen challenge mottatt ennå."
        localProofSummary = "Ingen signert IdentityEnrollmentRequest er laget ennå."
        enrollmentRequestPreview = "Ingen enrollment request klar ennå."
        enrollmentRequestValue = .null
        signedEnrollmentRequestHash = nil
        completionPackageInput = ""
        completionStatus = "Ingen completion package er importert ennå."
        completionSummary = "Lim inn en ekte CellProtocol IdentityLinkCompletionEnvelope fra staging når approval, SameEntityIdentityLinkCredential og verifier-bound VP er laget."
        completionRecordPreview = "Ingen active IdentityLinkRecord er skrevet ennå."
        nextStepSummary = "Når challenge-data er synlig, signer lokal IdentityEnrollmentRequest i HAVEN, godkjenn den i staging, og lim inn completion envelope her."
    }

    func helperConfiguration() -> CellConfiguration? {
        incomingChallenge?.admission?.helperCellConfiguration
    }

    func confirmLocalReview(with identity: Identity?) async {
        guard let challenge = incomingChallenge else {
            confirmationStatus = "Last en identity-link challenge før du bekrefter lokal review."
            actionSummary = "Ingen challenge er lastet ennå."
            return
        }
        guard let identity else {
            confirmationStatus = "HAVEN fant ingen lokal private-identitet å bekrefte."
            actionSummary = "Lokal key-possession kunne ikke bekreftes."
            return
        }
        guard let signedRequest = await makeSignedEnrollmentRequest(from: challenge, identity: identity) else {
            return
        }

        let label = identity.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let identityLabel = label.isEmpty ? identity.uuid : label
        localIdentitySummary = "HAVEN signerte en CellProtocol IdentityEnrollmentRequest for \(identityLabel) i private-domenet. Lokal private key ble brukt uten å eksporteres."
        confirmationStatus = "Signert enrollment request klar. Dette er lokal proof-of-possession, ikke ferdig same-entity approval."
        localProofSummary = "Request hash \(signedRequest.requestHashBase64URL) · \(signedRequest.algorithmSummary) · signature \(signedRequest.signaturePreview)"
        enrollmentRequestPreview = signedRequest.preview
        enrollmentRequestValue = signedRequest.value
        signedEnrollmentRequestHash = signedRequest.requestHashBase64URL
        completionSummary = "Requesten er klar for staging approval. Completion krever en envelope med approval, SameEntityIdentityLinkCredential, verifier-bound VP, issuerIdentity og expected verifier binding."
        actionSummary = "Lokal HAVEN-identitet har signert requesten. Fullfør approval i staging, og lim inn completion envelope under."
        nextStepSummary = "Gå tilbake til Scaffold Setup & Identity Link i web, godkjenn requesten der, utsted SameEntityIdentityLinkCredential/VP, og fullfør så her via EntityAnchor identityLinks.completeEnrollment."
    }

    func completeApprovedLink(with identity: Identity?) async {
        guard let identity else {
            completionStatus = "HAVEN fant ingen lokal private-identitet å fullføre mot."
            completionSummary = "Completion ble ikke sendt til EntityAnchor fordi lokal key-possession mangler."
            return
        }
        guard let payload = Self.decodeCompletionEnvelope(from: completionPackageInput) else {
            completionStatus = "Klarte ikke å lese completion package som CellProtocol IdentityLinkCompletionEnvelope."
            completionSummary = "Lim inn rå JSON eller base64url-enkodet JSON fra staging-kontrakten. HAVEN lager ikke syntetisk approval eller VP."
            return
        }
        guard payload.envelope.request.newIdentity.uuid == identity.uuid else {
            completionStatus = "Completion package gjelder ikke denne lokale HAVEN-identiteten."
            completionSummary = "Envelope subject \(payload.envelope.request.newIdentity.uuid) matcher ikke lokal identitet \(identity.uuid). Importer riktig package eller bytt lokal identitet."
            return
        }
        guard let signedEnrollmentRequestHash else {
            completionStatus = "Ingen lokalt signert enrollment request er aktiv for denne completion package."
            completionSummary = "Importer challenge på nytt og signer requesten før completion."
            return
        }
        do {
            let completionRequestHash = Self.base64URL(
                try IdentityLinkProtocolService.requestHash(for: payload.envelope.request)
            )
            guard completionRequestHash == signedEnrollmentRequestHash else {
                completionStatus = "Completion package matcher ikke den lokalt signerte enrollment requesten."
                completionSummary = "Request hash, nonce, audience eller scopes avviker. HAVEN nekter completion."
                return
            }
        } catch {
            completionStatus = "Completion package inneholder en ugyldig enrollment request."
            completionSummary = "HAVEN kunne ikke beregne og verifisere request hash."
            return
        }

        do {
            guard await BindingLocalCellRegistration.shared.ensureLocallyRegistered() else {
                completionStatus = "Lokal HAVEN-runtime kunne ikke valideres."
                completionSummary = "Identity-link completion ble ikke skrevet. Prøv igjen."
                return
            }
            let response = try await identity.set(
                keypath: "identity.identityLinks.completeEnrollment",
                value: payload.value,
                requester: identity
            )
            guard Self.statusString(from: response) == "completed" else {
                completionStatus = "EntityAnchor returnerte ikke completed for identityLinks.completeEnrollment."
                completionSummary = Self.responseSummary(from: response)
                return
            }
            completionStatus = "Identity-link completion er verifisert og lagret i EntityAnchor."
            completionSummary = "Approval JTI er markert brukt, SameEntityIdentityLinkCredential/VP er verifisert, og replay vil avvises av identityLinks-store."
            completionRecordPreview = Self.recordPreview(from: response)
            actionSummary = "EntityAnchor skrev en active IdentityLinkRecord fra ekte completion envelope."
            nextStepSummary = "Identity-link er aktiv. Du kan nå bruke identityLinks-recorden som bevis på at HAVEN-identiteten hører til samme Entity."
        } catch {
            completionStatus = "identityLinks.completeEnrollment feilet: \(error)"
            completionSummary = "Completion ble avvist av CellProtocol/EntityAnchor. Ingen record ble skrevet."
        }
    }

    func stateObject() -> Object {
        let challenge = incomingChallenge
        return [
            "workspace": .object([
                "title": .string("Conference Scaffold Setup & Identity Link"),
                "subtitle": .string("Mobil intake for scaffold setup og cross-vault identity-link challenges. Denne flaten viser hva som faktisk er på vei inn til HAVEN, og hva som fortsatt må fullføres i den delte protokollen."),
                "notice": .string("Ingen skjult global identitet. Ingen demo-bypass. HAVEN viser incoming challenge-data, requested scopes og lokal key-possession eksplisitt.")
            ]),
            "incoming": .object([
                "statusSummary": .string(challenge?.statusSummary ?? "Ingen identity-link challenge synlig ennå."),
                "sourceSummary": .string(lastIntakeSource),
                "challengeSummary": .string(challenge?.challengeSummary ?? "Ingen request eller challenge lastet ennå."),
                "audienceSummary": .string(challenge?.audienceSummary ?? "Audience mangler til en challenge er lastet."),
                "originSummary": .string(challenge?.originSummary ?? "Origin mangler til en challenge er lastet."),
                "entitySummary": .string(challenge?.entitySummary ?? "Entity anchor blir vist når requesten er lastet."),
                "deviceSummary": .string(challenge?.deviceSummary ?? "Ny HAVEN-identitet og device label vises når requesten er lest."),
                "domainSummary": .string(challenge?.domainSummary ?? "Requested domains vises når challenge-data er lastet."),
                "contextSummary": .string(challenge?.contextSummary ?? "Requested contexts vises når challenge-data er lastet."),
                "scopeSummary": .string(challenge?.scopeSummary ?? "Requested scopes vises når challenge-data er lastet."),
                "expirySummary": .string(challenge?.expirySummary ?? "Expiry vises når challenge-data er lastet."),
                "proofSummary": .string(challenge?.proofSummary ?? "Proof metadata vises når challenge-data er lastet."),
                "rawPreview": .string(challenge?.rawPreview ?? "Ingen raw preview tilgjengelig ennå.")
            ]),
            "admission": .object(challenge?.admission?.asObject() ?? defaultAdmissionState()),
            "review": .object([
                "localIdentitySummary": .string(localIdentitySummary),
                "confirmationStatus": .string(confirmationStatus),
                "localProofSummary": .string(localProofSummary),
                "enrollmentRequestPreview": .string(enrollmentRequestPreview),
                "enrollmentRequest": enrollmentRequestValue,
                "actionSummary": .string(actionSummary),
                "limitationSummary": .string(limitationSummary),
                "nextStepSummary": .string(nextStepSummary)
            ]),
            "completion": .object([
                "packageInput": .string(completionPackageInput),
                "status": .string(completionStatus),
                "summary": .string(completionSummary),
                "recordPreview": .string(completionRecordPreview)
            ]),
            "draftInput": .string(draftInput)
        ]
    }

    private struct SignedEnrollmentRequestState {
        var value: ValueType
        var requestHashBase64URL: String
        var algorithmSummary: String
        var signaturePreview: String
        var preview: String
    }

    private func makeSignedEnrollmentRequest(
        from challenge: ConferenceIdentityLinkParsedChallenge,
        identity: Identity
    ) async -> SignedEnrollmentRequestState? {
        guard let publicSecureKey = identity.publicSecureKey,
              let publicKey = publicSecureKey.compressedKey,
              publicKey.isEmpty == false else {
            confirmationStatus = "HAVEN fant ingen offentlig signeringsnøkkel for lokal identitet."
            actionSummary = "Kan ikke lage CellProtocol IdentityEnrollmentRequest uten lokal signeringsnøkkel."
            return nil
        }
        guard let challengeNonce = challenge.challenge,
              challengeNonce.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            confirmationStatus = "Challenge/nonce mangler, så HAVEN nekter å signere enrollment request."
            actionSummary = "Importer en challenge med nonce før lokal proof-of-possession kan lages."
            return nil
        }
        guard let nonceData = Self.decodeBase64URL(challengeNonce),
              nonceData.count >= 16 else {
            confirmationStatus = "Challenge/nonce er ikke gyldig base64url med minst 128 bit. HAVEN nekter å signere."
            actionSummary = "Hent en ny identity-link challenge med kryptografisk sterk nonce."
            return nil
        }
        guard challenge.purpose == "link_identity" else {
            confirmationStatus = "Purpose er \(challenge.purpose), ikke link_identity. HAVEN nekter å signere."
            actionSummary = "Importer en identity-link challenge med riktig CellProtocol purpose."
            return nil
        }
        guard let audience = challenge.audience,
              audience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            confirmationStatus = "Audience mangler, så HAVEN nekter å signere enrollment request."
            actionSummary = "Importer en audience-bound challenge før lokal proof-of-possession kan lages."
            return nil
        }
        guard Self.isTrustedIdentityLinkAudience(audience) else {
            confirmationStatus = "Audience er ikke en betrodd HAVEN identity-link-mottaker."
            actionSummary = "HAVEN nekter å signere en angriperstyrt audience."
            return nil
        }
        guard let origin = challenge.origin,
              origin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            confirmationStatus = "Origin mangler, så HAVEN nekter å signere enrollment request."
            actionSummary = "Importer en origin-bound challenge før lokal proof-of-possession kan lages."
            return nil
        }
        guard Self.isTrustedIdentityLinkOrigin(origin) else {
            confirmationStatus = "Origin er ikke en betrodd HAVEN identity-link-rute."
            actionSummary = "HAVEN nekter å signere en request fra ukjent origin."
            return nil
        }
        guard !challenge.requestedDomains.isEmpty,
              !challenge.requestedIdentityContexts.isEmpty,
              !challenge.requestedScopes.isEmpty else {
            confirmationStatus = "Domains, identity contexts eller scopes mangler. HAVEN nekter å signere."
            actionSummary = "Importer en scope-bound challenge før lokal proof-of-possession kan lages."
            return nil
        }
        guard let requestedExpiry = challenge.expiresAt,
              let expiryDate = ISO8601DateFormatter().date(from: requestedExpiry) else {
            confirmationStatus = "Expiry mangler eller er ugyldig. HAVEN nekter å signere enrollment request."
            actionSummary = "Importer en kortlivet challenge med gyldig expiresAt."
            return nil
        }
        guard expiryDate >= Date() else {
            confirmationStatus = "Challenge er utløpt. HAVEN nekter å signere enrollment request."
            actionSummary = "Hent en ny identity-link challenge før du fortsetter."
            return nil
        }
        guard expiryDate.timeIntervalSinceNow <= 3_600 else {
            confirmationStatus = "Challenge varer for lenge. HAVEN krever maks én times TTL."
            actionSummary = "Hent en ny, kortlivet identity-link challenge."
            return nil
        }

        let now = Date()
        let createdAt = Self.iso8601String(now)
        let expiresAt = requestedExpiry
        let displayName = identity.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = IdentityPublicKeyDescriptor(
            uuid: identity.uuid,
            displayName: displayName.isEmpty ? nil : displayName,
            publicKey: publicKey,
            algorithm: publicSecureKey.algorithm,
            curveType: publicSecureKey.curveType
        )
        let entityBinding = EntityBindingDescriptor(
            mode: .localEntityAnchor,
            entityAnchorReference: challenge.entityAnchorReference ?? identity.entityAnchorReference,
            audience: audience
        )

        var request = IdentityEnrollmentRequest(
            requestID: challenge.requestID ?? UUID().uuidString,
            purpose: challenge.purpose,
            entityBinding: entityBinding,
            newIdentity: subject,
            requestedDomains: challenge.requestedDomains,
            requestedIdentityContexts: challenge.requestedIdentityContexts,
            requestedScopes: challenge.requestedScopes,
            audience: audience,
            origin: origin,
            createdAt: createdAt,
            expiresAt: expiresAt,
            nonce: nonceData,
            platform: "macOS",
            deviceLabel: challenge.deviceLabel ?? displayName
        )

        do {
            let canonicalPayload = try request.canonicalPayloadData()
            guard let signature = try await identity.sign(data: canonicalPayload) else {
                confirmationStatus = "Lokal IdentityVault returnerte ingen signatur."
                actionSummary = "Kan ikke fortsette før HAVEN kan signere enrollment requesten."
                return nil
            }
            request.proof = IdentityEnrollmentRequestProof(
                byIdentityUUID: identity.uuid,
                algorithm: publicSecureKey.algorithm,
                curveType: publicSecureKey.curveType,
                signature: signature
            )
            let requestHash = Self.sha256Base64URL(canonicalPayload)
            let value = Self.valueType(from: request) ?? .null
            let signatureBase64URL = Self.base64URL(signature)
            let preview = "IdentityEnrollmentRequest \(request.requestID) · audience \(request.audience) · scopes \(request.requestedScopes.joined(separator: ", ")) · hash \(requestHash)"
            return SignedEnrollmentRequestState(
                value: value,
                requestHashBase64URL: requestHash,
                algorithmSummary: "\(publicSecureKey.algorithm.rawValue)/\(publicSecureKey.curveType.rawValue)",
                signaturePreview: String(signatureBase64URL.prefix(18)) + "...",
                preview: preview
            )
        } catch {
            confirmationStatus = "Signering av IdentityEnrollmentRequest feilet: \(error)"
            actionSummary = "HAVEN laget ikke noe proof fordi signeringen feilet."
            return nil
        }
    }

    private static func iso8601String(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func isTrustedIdentityLinkAudience(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "staging.haven.digipomps.org"
            || normalized == "haven.digipomps.org"
    }

    private static func isTrustedIdentityLinkOrigin(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              components.query == nil,
              components.fragment == nil else {
            return false
        }
        let scheme = components.scheme?.lowercased()
        let host = components.host?.lowercased()
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        if scheme == "haven" {
            return (host == "binding" && path == "add-device")
                || (host == "identity-link" && path.isEmpty)
        }
        if scheme == "https" {
            return (host == "staging.haven.digipomps.org" || host == "haven.digipomps.org")
                && (path == "identity-link" || path == "binding/add-device")
        }
        return false
    }

    private func resetDerivedStateForNewChallenge() {
        localIdentitySummary = "Ingen lokal HAVEN-identitet er bekreftet i denne flaten ennå."
        confirmationStatus = "Lokal brukerbekreftelse mangler."
        localProofSummary = "Ingen signert IdentityEnrollmentRequest er laget ennå."
        enrollmentRequestPreview = "Ingen enrollment request klar ennå."
        enrollmentRequestValue = .null
        signedEnrollmentRequestHash = nil
        completionPackageInput = ""
        completionStatus = "Ingen completion package er importert ennå."
        completionSummary = "Lim inn en ekte CellProtocol IdentityLinkCompletionEnvelope fra staging når approval, SameEntityIdentityLinkCredential og verifier-bound VP er laget."
        completionRecordPreview = "Ingen active IdentityLinkRecord er skrevet ennå."
    }

    private static func sha256Base64URL(_ data: Data) -> String {
        base64URL(Data(SHA256.hash(data: data)))
    }

    private static func valueType<T: Encodable>(from value: T) -> ValueType? {
        guard let data = try? JSONEncoder().encode(value) else {
            return nil
        }
        return try? JSONDecoder().decode(ValueType.self, from: data)
    }

    private struct CompletionEnvelopePayload {
        var envelope: IdentityLinkCompletionEnvelope
        var value: ValueType
    }

    private static func decodeCompletionEnvelope(from input: String) -> CompletionEnvelopePayload? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var candidates = [trimmed]
        if let decodedPayload = decodeBase64URL(trimmed),
           let decodedText = String(data: decodedPayload, encoding: .utf8) {
            candidates.append(decodedText)
        }

        for candidate in candidates {
            guard let data = candidate.data(using: .utf8) else { continue }
            if let payload = decodeCompletionEnvelopeData(data) {
                return payload
            }
        }
        return nil
    }

    private static func decodeCompletionEnvelopeData(_ data: Data) -> CompletionEnvelopePayload? {
        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(IdentityLinkCompletionEnvelope.self, from: data),
           let value = try? decoder.decode(ValueType.self, from: data) {
            return CompletionEnvelopePayload(envelope: envelope, value: value)
        }

        guard case let .object(object)? = try? decoder.decode(ValueType.self, from: data) else {
            return nil
        }
        guard let nested = object["completionEnvelope"] ?? object["envelope"] ?? object["identityLinkCompletion"] else {
            return nil
        }
        guard let nestedData = try? JSONEncoder().encode(nested),
              let envelope = try? decoder.decode(IdentityLinkCompletionEnvelope.self, from: nestedData) else {
            return nil
        }
        return CompletionEnvelopePayload(envelope: envelope, value: nested)
    }

    private static func statusString(from response: ValueType?) -> String? {
        guard case let .object(object)? = response,
              case let .string(status)? = object["status"] else {
            return nil
        }
        return status
    }

    private static func responseSummary(from response: ValueType?) -> String {
        guard let response else {
            return "EntityAnchor returnerte ingen response."
        }
        guard case let .object(object) = response else {
            return "EntityAnchor response: \(response)"
        }
        if case let .string(error)? = object["error"] {
            return "EntityAnchor error: \(error)"
        }
        if case let .string(status)? = object["status"] {
            return "EntityAnchor status: \(status)"
        }
        return "EntityAnchor response manglet status-felt."
    }

    private static func recordPreview(from response: ValueType?) -> String {
        guard case let .object(object)? = response,
              case let .object(record)? = object["record"] else {
            return "Completion ble lagret, men HAVEN fant ikke record preview i response."
        }
        let linkID = stringValue(record["linkID"]) ?? "ukjent linkID"
        let status = stringValue(record["status"]) ?? "ukjent status"
        let scopes = stringList(record["approvedScopes"]).joined(separator: ", ")
        let linkedIdentity: String
        if case let .object(identityObject)? = record["linkedIdentity"] {
            linkedIdentity = stringValue(identityObject["displayName"])
                ?? stringValue(identityObject["uuid"])
                ?? "ukjent identitet"
        } else {
            linkedIdentity = "ukjent identitet"
        }
        let proofKeypath = stringValue(object["proofKeypath"]) ?? "proof keypath mangler"
        return "Record \(linkID) · \(status) · \(linkedIdentity) · scopes \(scopes.isEmpty ? "ikke oppgitt" : scopes) · \(proofKeypath)"
    }

    private static func stringValue(_ value: ValueType?) -> String? {
        guard case let .string(string)? = value else {
            return nil
        }
        return string
    }

    private static func stringList(_ value: ValueType?) -> [String] {
        guard case let .list(values)? = value else {
            return []
        }
        return values.compactMap { stringValue($0) }
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func decodeBase64URL(_ value: String) -> Data? {
        var normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while normalized.count % 4 != 0 {
            normalized.append("=")
        }
        return Data(base64Encoded: normalized)
    }
}

private final class ConferenceIdentityLinkIntakeCell: GeneralCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
        await configure(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        fatalError("ConferenceIdentityLinkIntakeCell does not support decoding")
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private func configure(owner: Identity) async {
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("rw--", for: "setDraftInput")
        agreementTemplate.addGrant("rw--", for: "setCompletionPackageInput")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")

        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { _, _ in
            .object(await ConferenceIdentityLinkInboxStore.shared.stateObject())
        })

        await addInterceptForSet(requester: owner, key: "setDraftInput", setValueIntercept: { _, value, _ in
            await ConferenceIdentityLinkInboxStore.shared.setDraftInput(Self.string(from: value))
            return .object([
                "status": .string("ok"),
                "state": .object(await ConferenceIdentityLinkInboxStore.shared.stateObject())
            ])
        })

        await addInterceptForSet(requester: owner, key: "setCompletionPackageInput", setValueIntercept: { _, value, _ in
            await ConferenceIdentityLinkInboxStore.shared.setCompletionPackageInput(Self.string(from: value))
            return .object([
                "status": .string("ok"),
                "state": .object(await ConferenceIdentityLinkInboxStore.shared.stateObject())
            ])
        })

        await addInterceptForSet(requester: owner, key: "dispatchAction", setValueIntercept: { _, value, requester in
            await self.handleDispatchAction(value, requester: requester)
        })
    }

    private func handleDispatchAction(_ value: ValueType, requester: Identity) async -> ValueType {
        guard case let .object(object) = value,
              case let .string(actionKeypath)? = object["keypath"] else {
            return .object([
                "status": .string("error"),
                "state": .object(await ConferenceIdentityLinkInboxStore.shared.stateObject())
            ])
        }

        switch actionKeypath {
        case "identityLink.importDraft":
            let imported = await ConferenceIdentityLinkInboxStore.shared.importDraft()
            return .object([
                "status": .string(imported ? "ok" : "error"),
                "state": .object(await ConferenceIdentityLinkInboxStore.shared.stateObject())
            ])
        case "identityLink.clear":
            await ConferenceIdentityLinkInboxStore.shared.clear()
            return .object([
                "status": .string("ok"),
                "state": .object(await ConferenceIdentityLinkInboxStore.shared.stateObject())
            ])
        case "identityLink.confirmLocalReview":
            let localIdentity = await BindingStartupIdentityVault.shared.identity(for: "private", makeNewIfNotFound: true) ?? requester
            await ConferenceIdentityLinkInboxStore.shared.confirmLocalReview(with: localIdentity)
            return .object([
                "status": .string("ok"),
                "state": .object(await ConferenceIdentityLinkInboxStore.shared.stateObject())
            ])
        case "identityLink.completeApprovedLink":
            let localIdentity = await BindingStartupIdentityVault.shared.identity(for: "private", makeNewIfNotFound: true) ?? requester
            await ConferenceIdentityLinkInboxStore.shared.completeApprovedLink(with: localIdentity)
            return .object([
                "status": .string("ok"),
                "state": .object(await ConferenceIdentityLinkInboxStore.shared.stateObject())
            ])
        case "identityLink.openLauncher":
            await MainActor.run {
                BindingConferenceNavigationBridge.postPop(
                    fallbackConfiguration: ConfigurationCatalogCell.conferenceDemoLauncherWorkbenchConfiguration()
                )
            }
            return .object([
                "status": .string("ok"),
                "state": .object(await ConferenceIdentityLinkInboxStore.shared.stateObject())
            ])
        case "identityLink.openHelper":
            guard let helperConfiguration = await ConferenceIdentityLinkInboxStore.shared.helperConfiguration() else {
                return .object([
                    "status": .string("error"),
                    "state": .object(await ConferenceIdentityLinkInboxStore.shared.stateObject())
                ])
            }
            await MainActor.run {
                BindingPortholeLoadBridge.post(configuration: helperConfiguration)
            }
            return .object([
                "status": .string("ok"),
                "state": .object(await ConferenceIdentityLinkInboxStore.shared.stateObject())
            ])
        default:
            return .object([
                "status": .string("error"),
                "state": .object(await ConferenceIdentityLinkInboxStore.shared.stateObject())
            ])
        }
    }

    private static func string(from value: ValueType) -> String {
        switch value {
        case let .string(string):
            return string
        default:
            return ""
        }
    }
}

private final class ConferenceDemoLauncherLocalCell: GeneralCell {
    private static let stagingHost = "staging.haven.digipomps.org"

    private var cachedState: Object = ConferenceDemoLauncherLocalCell.defaultState()

    required init(owner: Identity) async {
        await super.init(owner: owner)
        await configure(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        fatalError("ConferenceDemoLauncherLocalCell does not support decoding")
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private func configure(owner: Identity) async {
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")

        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, _ in
            guard let self else { return .string("failure") }
            return .object(self.cachedState)
        })

        await addInterceptForSet(requester: owner, key: "dispatchAction", setValueIntercept: { [weak self] _, value, _ in
            guard let self else { return .string("failure") }
            return await self.handleDispatchAction(value)
        })
    }

    private func handleDispatchAction(_ value: ValueType) async -> ValueType {
        guard case let .object(object) = value,
              case let .string(actionKeypath)? = object["keypath"] else {
            cachedState = Self.stateWithStatus(
                basedOn: cachedState,
                status: "Launcheren kunne ikke lese handlingen.",
                actionSummary: "Payloaden manglet action-keypath."
            )
            return .object([
                "status": .string("error"),
                "state": .object(cachedState)
            ])
        }

        guard let configuration = configuration(for: actionKeypath) else {
            cachedState = Self.stateWithStatus(
                basedOn: cachedState,
                status: "Launcheren støtter ikke denne handlingen ennå.",
                actionSummary: "Ukjent launcher-handling: \(actionKeypath)"
            )
            return .object([
                "status": .string("error"),
                "state": .object(cachedState)
            ])
        }

        let successSummary = successSummary(for: actionKeypath, configurationName: configuration.name)
        cachedState = Self.stateWithStatus(
            basedOn: cachedState,
            status: "Åpner \(configuration.name)…",
            actionSummary: successSummary
        )
        scheduleWorkbenchLoad(configuration, successSummary: successSummary)
        return .object([
            "status": .string("ok"),
            "state": .object(cachedState)
        ])
    }

    private func scheduleWorkbenchLoad(
        _ configuration: CellConfiguration,
        successSummary: String
    ) {
        Task { @MainActor [weak self] in
            BindingPortholeLoadBridge.post(configuration: configuration)
            guard let self else { return }
            self.cachedState = Self.stateWithStatus(
                basedOn: self.cachedState,
                status: "Launcheren åpnet \(configuration.name).",
                actionSummary: successSummary
            )
        }
    }

    private func configuration(for actionKeypath: String) -> CellConfiguration? {
        switch actionKeypath {
        case "launcher.openPublicSurface":
            return ConfigurationCatalogCell.conferencePublicWorkbenchConfiguration(
                endpoint: "cell:///ConferencePublicShellFixture"
            )
        case "launcher.openIdentityLink":
            return ConfigurationCatalogCell.conferenceIdentityLinkWorkbenchConfiguration()
        case "launcher.openParticipantCockpit":
            return ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
                endpoint: "cell:///ConferenceParticipantPreviewShell"
            )
        case "launcher.openParticipantChat":
            return ConfigurationCatalogCell.conferenceParticipantChatWorkbenchConfiguration(
                participantEndpoint: "cell:///ConferenceParticipantPreviewShell"
            )
        case "launcher.openControlTower":
            return ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
                endpoint: "cell:///ConferenceAdminPreviewShell"
            )
        case "launcher.openAIAssistant":
            return ConfigurationCatalogCell.conferenceAIAssistantWorkbenchConfiguration(
                conferenceEndpoint: "cell:///ConferenceParticipantPreviewShell",
                aiEndpoint: "cell:///ConferenceAIAssistantGatewayProxy"
            )
        default:
            return nil
        }
    }

    private func successSummary(for actionKeypath: String, configurationName: String) -> String {
        switch actionKeypath {
        case "launcher.openPublicSurface":
            return "Åpner den publiserte conference-flaten først."
        case "launcher.openIdentityLink":
            return "Åpner scaffold setup og identity-link review i HAVEN."
        case "launcher.openParticipantCockpit":
            return "Åpner deltagerportalen i samme demo-løp."
        case "launcher.openParticipantChat":
            return "Åpner den eksplisitte chatflaten for participant-flyten."
        case "launcher.openControlTower":
            return "Bytter til organizer-perspektivet i control tower."
        case "launcher.openAIAssistant":
            return "Åpner conference-copiloten fra scaffold-preview med samme contracts som staging."
        default:
            return "Åpner \(configurationName)."
        }
    }

    private static func stateWithStatus(
        basedOn base: Object,
        status: String,
        actionSummary: String
    ) -> Object {
        var updated = base
        updated["statusSummary"] = .string(status)
        updated["actionSummary"] = .string(actionSummary)
        return updated
    }

    private static func defaultState() -> Object {
        [
            "intro": .string("Dette er HAVEN sin parity-launcher for conference-demoen. Den holder seg til eksisterende conference-konfigurasjoner og bruker samme Porthole-session hele veien."),
            "statusSummary": .string("Launcheren er klar. Start med den publiserte public surface før du går videre til participant eller organizer."),
            "actionSummary": .string("Velg en act under for å åpne neste conference-flate."),
            "nextStepSummary": .string("Act 0 åpner public surface. Act 0.5 åpner scaffold setup og identity-link review. Derfra går du videre til participant cockpit, chat og control tower."),
            "readinessSummary": .string("Public opener, scaffold setup / identity link review, participant cockpit, explicit chat, control tower og AI assistant er tilgjengelige som egne konfigurasjoner i HAVEN."),
            "stretchSummary": .string("Nearby-radar forblir en tydelig merket HAVEN-only stretch, og er ikke del av den staging-first demo-historien."),
            "publicActSummary": .string("Vis publisert landing, spor og program som faktisk kommer fra CellScaffold på staging."),
            "identityLinkActSummary": .string("Åpne scaffold setup og review incoming identity-link challenge-data i HAVEN uten å omgå den delte cross-vault-protokollen."),
            "participantActSummary": .string("Fortsett i participant-portalen og åpne chatflaten eksplisitt når samtalen er startet."),
            "organizerActSummary": .string("Bytt deretter til control tower eller AI assistant for organizer-/briefing-perspektivet.")
        ]
    }
}
