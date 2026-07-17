import CellBase

enum HavenAgentRuntimeBindingError: Error {
    case ownerProofUnavailable
}

private actor HavenAgentRuntimeBindingState {
    private var installTask: Task<Result<Void, HavenAgentRuntimeBindingError>, Never>?
    private var installGeneration: UInt = 0
    private var installed = false

    func markInstalled() {
        installed = true
    }

    func ensure(
        _ operation: @escaping @Sendable () async -> Result<Void, HavenAgentRuntimeBindingError>
    ) async throws {
        if installed {
            return
        }

        let activeTask: Task<Result<Void, HavenAgentRuntimeBindingError>, Never>
        let activeGeneration: UInt
        if let installTask {
            activeTask = installTask
            activeGeneration = installGeneration
        } else {
            let newTask = Task { await operation() }
            installGeneration &+= 1
            installTask = newTask
            activeTask = newTask
            activeGeneration = installGeneration
        }

        let result = await activeTask.value
        if installGeneration == activeGeneration {
            installTask = nil
            if case .success = result {
                installed = true
            }
        }
        try result.get()
    }
}

public class HavenAgentRuntimeBindingCell: GeneralCell {
    private let runtimeBindingState = HavenAgentRuntimeBindingState()

    public required init(owner: Identity) async {
        await super.init(owner: owner)
    }

    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    func installRuntimeBindings(owner: Identity) async {}

    func markRuntimeBindingsInstalled() async {
        await runtimeBindingState.markInstalled()
    }

    func ensureAgreementGrant(_ permissions: String, for keypath: String) {
        guard !agreementTemplate.grants.contains(where: { $0.keypath == keypath }) else {
            return
        }
        agreementTemplate.addGrant(permissions, for: keypath)
    }

    func ensureRuntimeBindings(requester: Identity? = nil) async throws {
        let cell = UncheckedSendableReference(value: self)
        let requesterReference = requester.map { UncheckedSendableReference(value: $0) }
        try await runtimeBindingState.ensure {
            guard let owner = await cell.value.proofCapableStoredOwner(
                requester: requesterReference?.value
            ) else {
                return .failure(.ownerProofUnavailable)
            }
            await cell.value.installRuntimeBindings(owner: owner)
            return .success(())
        }
    }

    public override func get(keypath: String, requester: Identity) async throws -> ValueType {
        try await ensureRuntimeBindings(requester: requester)
        return try await super.get(keypath: keypath, requester: requester)
    }

    public override func set(keypath: String, value: ValueType, requester: Identity) async throws -> ValueType? {
        try await ensureRuntimeBindings(requester: requester)
        return try await super.set(keypath: keypath, value: value, requester: requester)
    }

    private func proofCapableStoredOwner(requester: Identity?) async -> Identity? {
        let storedOwner = storedOwnerIdentity
        if await requesterProvesOwnership(storedOwner) {
            return storedOwner
        }
        if let requester,
           await restoreStoredOwnerIdentity(using: requester) {
            return requester
        }
        guard
            let hydratedOwner = await CellBase.defaultIdentityVault?.identity(forUUID: storedOwner.uuid),
            await restoreStoredOwnerIdentity(using: hydratedOwner)
        else {
            return nil
        }
        return hydratedOwner
    }
}
