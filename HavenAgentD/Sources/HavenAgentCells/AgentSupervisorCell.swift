import Foundation
import CellBase
import HavenAgentRuntime

public final class AgentSupervisorCell: GeneralCell {
    private enum CodingKeys: String, CodingKey {
        case version
    }

    public required init(owner: Identity) async {
        await super.init(owner: owner)
        await setupPermissions(owner: owner)
        await setupKeys(owner: owner)
    }

    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        let cell = UncheckedSendableReference(value: self)
        Task {
            let requester = Identity()
            let decodedOwner = (try? await cell.value.getOwner(requester: requester)) ?? requester
            await cell.value.setupPermissions(owner: decodedOwner)
            await cell.value.setupKeys(owner: decodedOwner)
        }
    }

    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("1", forKey: .version)
    }

    private func setupPermissions(owner: Identity) async {
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("r---", for: "bootstrap")
        agreementTemplate.addGrant("r---", for: "porthole")
        agreementTemplate.addGrant("r---", for: "identity")
        agreementTemplate.addGrant("r---", for: "lastAction")
        agreementTemplate.addGrant("r---", for: "lastError")
        agreementTemplate.addGrant("rw--", for: "refresh")
        agreementTemplate.addGrant("r---", for: "flow")
    }

    private func setupKeys(owner: Identity) async {
        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            let directAccess = await self.validateAccess("r---", at: "state", for: requester)
            let hasAccess = directAccess ? true : await LocalControlCellAccess.isPairedOperator(requester)
            guard hasAccess else { return .string("denied") }
            return await self.makeStateValue()
        })

        await addInterceptForGet(requester: owner, key: "bootstrap", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            let directAccess = await self.validateAccess("r---", at: "bootstrap", for: requester)
            let hasAccess = directAccess ? true : await LocalControlCellAccess.isPairedOperator(requester)
            guard hasAccess else { return .string("denied") }
            return await self.makeBootstrapValue()
        })

        await addInterceptForGet(requester: owner, key: "porthole", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            let directAccess = await self.validateAccess("r---", at: "porthole", for: requester)
            let hasAccess = directAccess ? true : await LocalControlCellAccess.isPairedOperator(requester)
            guard hasAccess else { return .string("denied") }
            return await self.makePortholeValue()
        })

        await addInterceptForGet(requester: owner, key: "identity", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            let directAccess = await self.validateAccess("r---", at: "identity", for: requester)
            let hasAccess = directAccess ? true : await LocalControlCellAccess.isPairedOperator(requester)
            guard hasAccess else { return .string("denied") }
            return await self.makeIdentityValue()
        })

        await addInterceptForGet(requester: owner, key: "lastAction", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            let directAccess = await self.validateAccess("r---", at: "lastAction", for: requester)
            let hasAccess = directAccess ? true : await LocalControlCellAccess.isPairedOperator(requester)
            guard hasAccess else { return .string("denied") }
            return await self.makeLastActionValue()
        })

        await addInterceptForGet(requester: owner, key: "lastError", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            let directAccess = await self.validateAccess("r---", at: "lastError", for: requester)
            let hasAccess = directAccess ? true : await LocalControlCellAccess.isPairedOperator(requester)
            guard hasAccess else { return .string("denied") }
            return await self.makeLastErrorValue()
        })

        await addInterceptForSet(requester: owner, key: "refresh", setValueIntercept: { [weak self] _, _, requester in
            guard let self else { return .string("failure") }
            let directAccess = await self.validateAccess("rw--", at: "refresh", for: requester)
            let hasAccess = directAccess ? true : await LocalControlCellAccess.isPairedOperator(requester)
            guard hasAccess else { return .string("denied") }
            await self.publishRefreshEvent(requester: requester)
            return await self.makeStateValue()
        })
    }

    private func publishRefreshEvent(requester: Identity) async {
        var payload: Object = [
            "source": .string("AgentSupervisorCell"),
            "refreshedAt": .string(ISO8601DateFormatter().string(from: Date()))
        ]
        payload["state"] = await makeStateValue()
        var flowElement = FlowElement(
            title: "agent.supervisor.refresh",
            content: .object(payload),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flowElement.topic = "agent.supervisor"
        flowElement.origin = uuid
        pushFlowElement(flowElement, requester: requester)
    }

    private func makeStateValue() async -> ValueType {
        guard let snapshot = await AgentRuntimeBridge.shared.runtimeStateSnapshot() else {
            return .object([
                "status": .string("unavailable"),
                "activeWatchIDs": .list([]),
                "controlBridge": await makeControlBridgeObject()
            ])
        }

        var object: Object = [
            "instanceName": .string(snapshot.instanceName),
            "status": .string(snapshot.status),
            "activeWatchIDs": .list(snapshot.activeWatchIDs.map { .string($0) })
        ]
        object["bootstrap"] = makeBootstrapObject(from: snapshot.lastSproutBootstrap)
        object["porthole"] = makePortholeObject(from: snapshot.portholeIngress)
        object["identity"] = await makeIdentityValue()
        object["controlBridge"] = await makeControlBridgeObject()
        object["lastAction"] = makeExecutedActionObject(from: snapshot.lastExecutedAction)
        object["lastError"] = snapshot.lastError.map(ValueType.string) ?? .null
        object["lastEventSummary"] = snapshot.lastEventSummary.map(ValueType.string) ?? .null
        object["lastHeartbeatAt"] = snapshot.lastHeartbeatAt.map(ValueType.string) ?? .null
        return .object(object)
    }

    private func makeBootstrapValue() async -> ValueType {
        let snapshot = await AgentRuntimeBridge.shared.runtimeStateSnapshot()
        return makeBootstrapObject(from: snapshot?.lastSproutBootstrap)
    }

    private func makeLastActionValue() async -> ValueType {
        let snapshot = await AgentRuntimeBridge.shared.runtimeStateSnapshot()
        return makeExecutedActionObject(from: snapshot?.lastExecutedAction)
    }

    private func makePortholeValue() async -> ValueType {
        let snapshot = await AgentRuntimeBridge.shared.runtimeStateSnapshot()
        return makePortholeObject(from: snapshot?.portholeIngress)
    }

    private func makeLastErrorValue() async -> ValueType {
        let snapshot = await AgentRuntimeBridge.shared.runtimeStateSnapshot()
        return snapshot?.lastError.map(ValueType.string) ?? .null
    }

    private func makeIdentityValue() async -> ValueType {
        guard let descriptor = await AgentRuntimeBridge.shared.agentIdentityDescriptorSnapshot() else {
            return .null
        }
        return .object([
            "instanceName": .string(descriptor.instanceName),
            "identityContext": .string(descriptor.identityContext),
            "identityUUID": .string(descriptor.identityUUID),
            "displayName": .string(descriptor.displayName),
            "publicKeyBase64URL": .string(descriptor.publicKeyBase64URL),
            "didKey": .string(descriptor.didKey),
            "createdAt": .string(descriptor.createdAt),
            "storageKind": .string(descriptor.storageKind),
            "pairedOperator": await makePairedOperatorValue()
        ])
    }

    private func makePairedOperatorValue() async -> ValueType {
        guard let pairedOperator = await AgentRuntimeBridge.shared.pairedOperatorSnapshot(refresh: true) else {
            let pairingStatus = await AgentRuntimeBridge.shared.pairingArtifactStatusSnapshot()
            return .object([
                "status": .string(pairingStatus.lastError == nil ? "unpaired" : "invalid"),
                "path": pairingStatus.path.map(ValueType.string) ?? .null,
                "lastError": pairingStatus.lastError.map(ValueType.string) ?? .null
            ])
        }

        return .object([
            "status": .string("paired"),
            "pairingID": .string(pairedOperator.pairingID),
            "purposeRef": .string(pairedOperator.purposeRef),
            "scaffoldDomain": .string(pairedOperator.scaffoldDomain),
            "operatorIdentityUUID": .string(pairedOperator.operatorIdentityUUID),
            "operatorDid": .string(pairedOperator.operatorDid),
            "operatorPublicKeyBase64URL": .string(pairedOperator.operatorPublicKeyBase64URL),
            "approvedAt": .string(pairedOperator.approvedAt)
        ])
    }

    private func makeControlBridgeObject() async -> ValueType {
        guard let status = await AgentRuntimeBridge.shared.localControlBridgeStatusSnapshot() else {
            return .null
        }
        return .object([
            "phase": .string(status.phase.rawValue),
            "host": .string(status.host),
            "port": .integer(status.port),
            "websocketBaseURL": .string(status.websocketBaseURL),
            "lastError": status.lastError.map(ValueType.string) ?? .null,
            "routes": .list(status.routes.map { route in
                .object([
                    "name": .string(route.name),
                    "targetCellReference": .string(route.targetCellReference),
                    "description": .string(route.description)
                ])
            })
        ])
    }

    private func makeBootstrapObject(from record: SproutBootstrapInvocationRecord?) -> ValueType {
        guard let record else { return .null }
        var object: Object = [
            "mode": .string(record.mode.rawValue),
            "executablePath": .string(record.executablePath),
            "commandArguments": .list(record.commandArguments.map { .string($0) }),
            "resultSummary": .string(record.resultSummary),
            "recordedAt": .string(record.recordedAt)
        ]
        object["artifactPath"] = record.artifactPath.map(ValueType.string) ?? .null
        object["finalState"] = record.finalState.map(ValueType.string) ?? .null
        return .object(object)
    }

    private func makeExecutedActionObject(from record: ExecutedActionRecord?) -> ValueType {
        guard let record else { return .null }
        return .object([
            "kind": .string(record.kind.rawValue),
            "id": .string(record.id),
            "status": .string(record.status),
            "recordedAt": .string(record.recordedAt)
        ])
    }

    private func makePortholeObject(from status: PortholeIngressStatus?) -> ValueType {
        guard let status else { return .null }
        return .object([
            "phase": .string(status.phase.rawValue),
            "contractID": status.contractID.map(ValueType.string) ?? .null,
            "bridgeEndpoint": status.bridgeEndpoint.map(ValueType.string) ?? .null,
            "artifactExpiresAt": status.artifactExpiresAt.map(ValueType.string) ?? .null,
            "lastRenewedAt": status.lastRenewedAt.map(ValueType.string) ?? .null,
            "lastMessageAt": status.lastMessageAt.map(ValueType.string) ?? .null,
            "lastAcceptedIntentID": status.lastAcceptedIntentID.map(ValueType.string) ?? .null,
            "lastRejectedReason": status.lastRejectedReason.map(ValueType.string) ?? .null,
            "nextRetryAt": status.nextRetryAt.map(ValueType.string) ?? .null,
            "retryCount": status.retryCount.map { .string(String($0)) } ?? .null,
            "lastError": status.lastError.map(ValueType.string) ?? .null
        ])
    }
}
