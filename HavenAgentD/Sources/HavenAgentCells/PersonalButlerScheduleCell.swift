import Foundation
import CellBase
import HavenAgentRuntime

public final class PersonalButlerScheduleCell: HavenAgentRuntimeBindingCell {
    private enum CodingKeys: String, CodingKey {
        case version
    }

    public required init(owner: Identity) async {
        await super.init(owner: owner)
        await installRuntimeBindings(owner: owner)
        await markRuntimeBindingsInstalled()
    }

    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("1", forKey: .version)
    }

    override func installRuntimeBindings(owner: Identity) async {
        ensureAgreementGrant("r---", for: "state")
        ensureAgreementGrant("rw--", for: "preferences.configure")
        ensureAgreementGrant("r---", for: "flow")
        await setupExploreContracts(owner: owner)

        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.hasAccess("r---", at: "state", requester: requester) else {
                return .string("denied")
            }
            return await self.stateValue()
        })

        await addInterceptForSet(
            requester: owner,
            key: "preferences.configure",
            setValueIntercept: { [weak self] _, value, requester in
                guard let self else { return .string("failure") }
                guard await self.hasAccess("rw--", at: "preferences.configure", requester: requester) else {
                    return .string("denied")
                }
                return await self.configure(value: value, requester: requester)
            }
        )
    }

    private func hasAccess(_ access: String, at key: String, requester: Identity) async -> Bool {
        if await validateAccess(access, at: key, for: requester) { return true }
        return await LocalControlCellAccess.isPairedOperator(requester)
    }

    private func setupExploreContracts(owner: Identity) async {
        let preferencesInput = ExploreContract.objectSchema(
            properties: [
                "ownerApproved": ExploreContract.schema(type: "bool"),
                "enabled": ExploreContract.schema(type: "bool"),
                "minimumIntervalHours": ExploreContract.schema(type: "integer"),
                "quietHoursEnabled": ExploreContract.schema(type: "bool"),
                "quietHoursStart": ExploreContract.schema(type: "integer"),
                "quietHoursEnd": ExploreContract.schema(type: "integer"),
                "appLaunchEnabled": ExploreContract.schema(type: "bool"),
                "taskCompletionEnabled": ExploreContract.schema(type: "bool"),
                "userScheduleEnabled": ExploreContract.schema(type: "bool"),
                "userScheduleKind": ExploreContract.schema(type: "string"),
                "userScheduleLocalTime": ExploreContract.schema(type: "string"),
                "userScheduleWeekday": ExploreContract.schema(type: "integer"),
                "stagingWakeEnabled": ExploreContract.schema(type: "bool"),
                "lastOfferedAt": ExploreContract.schema(type: "string"),
                "snoozedUntil": ExploreContract.schema(type: "string"),
                "sourceDeviceID": ExploreContract.schema(type: "string")
            ],
            requiredKeys: ["ownerApproved", "enabled"]
        )
        await registerExploreContract(
            requester: owner,
            key: "state",
            method: .get,
            returns: ExploreContract.objectSchema(),
            permissions: ["r---"],
            description: .string("Returns privacy-safe daemon cadence, schedule, wake consent and audit status.")
        )
        await registerExploreContract(
            requester: owner,
            key: "preferences.configure",
            method: .set,
            input: preferencesInput,
            returns: ExploreContract.objectSchema(),
            permissions: ["rw--"],
            flowEffects: [
                ExploreContract.flowEffect(
                    trigger: .set,
                    topic: "agent.personal-butler.schedule",
                    contentType: "object"
                )
            ],
            description: .string("Stores only owner-approved cadence and wake preferences in HAVENAgentD; no chat or personality content is accepted.")
        )
    }

    private func configure(value: ValueType, requester: Identity) async -> ValueType {
        guard case let .object(input) = value else {
            return failure("invalid_preferences", "Expected an object with Butler cadence preferences.")
        }
        guard let service = await AgentRuntimeBridge.shared.personalButlerScheduleServiceSnapshot() else {
            return failure("daemon_schedule_unavailable", "HAVENAgentD schedule service is not running.")
        }

        let current = await service.snapshot().preferences
        let ownerApproved = bool(input["ownerApproved"]) ?? current.ownerApproved
        let preferences = PersonalButlerDaemonPreferences(
            ownerApproved: ownerApproved,
            enabled: bool(input["enabled"]) ?? current.enabled,
            minimumIntervalHours: integer(input["minimumIntervalHours"]) ?? current.minimumIntervalHours,
            quietHoursEnabled: bool(input["quietHoursEnabled"]) ?? current.quietHoursEnabled,
            quietHoursStart: integer(input["quietHoursStart"]) ?? current.quietHoursStart,
            quietHoursEnd: integer(input["quietHoursEnd"]) ?? current.quietHoursEnd,
            appLaunchEnabled: bool(input["appLaunchEnabled"]) ?? current.appLaunchEnabled,
            taskCompletionEnabled: bool(input["taskCompletionEnabled"]) ?? current.taskCompletionEnabled,
            userScheduleEnabled: bool(input["userScheduleEnabled"]) ?? current.userScheduleEnabled,
            userScheduleKind: string(input["userScheduleKind"]) ?? current.userScheduleKind,
            userScheduleLocalTime: string(input["userScheduleLocalTime"]) ?? current.userScheduleLocalTime,
            userScheduleWeekday: integer(input["userScheduleWeekday"]) ?? current.userScheduleWeekday,
            stagingWakeEnabled: bool(input["stagingWakeEnabled"]) ?? current.stagingWakeEnabled,
            lastOfferedAt: input.keys.contains("lastOfferedAt")
                ? nullableString(input["lastOfferedAt"])
                : current.lastOfferedAt,
            snoozedUntil: input.keys.contains("snoozedUntil")
                ? nullableString(input["snoozedUntil"])
                : current.snoozedUntil,
            sourceDeviceID: input.keys.contains("sourceDeviceID")
                ? nullableString(input["sourceDeviceID"])
                : current.sourceDeviceID,
            approvedByIdentityUUID: ownerApproved ? requester.uuid : nil,
            approvedBySigningKeyFingerprint: ownerApproved ? requester.signingPublicKeyFingerprint : nil
        )

        do {
            let configured = try await service.configure(preferences)
            await publishConfigurationEvent(state: configured, requester: requester)
            return stateValue(configured)
        } catch {
            return failure("persistence_failed", error.localizedDescription)
        }
    }

    private func stateValue() async -> ValueType {
        guard let service = await AgentRuntimeBridge.shared.personalButlerScheduleServiceSnapshot() else {
            return .object([
                "status": .string("unavailable"),
                "runtimeOwner": .string("havenagentd"),
                "storesChatContent": .bool(false),
                "storesPersonalityContent": .bool(false)
            ])
        }
        return stateValue(await service.snapshot())
    }

    private func stateValue(_ state: PersonalButlerDaemonState) -> ValueType {
        let preferences = state.preferences
        return .object([
            "status": .string("ready"),
            "schema": .string(state.schema),
            "runtimeOwner": .string("havenagentd"),
            "purposeRefs": .list([
                .string("purpose://human-agency"),
                .string("purpose://preference.owner-controlled"),
                .string("purpose://access.audit.privacy")
            ]),
            "remoteWakeActionID": .string(PersonalButlerScheduleService.remoteWakeActionID),
            "remoteWakeTopic": .string(PersonalButlerScheduleService.remoteWakeTopic),
            "storesChatContent": .bool(false),
            "storesPersonalityContent": .bool(false),
            "preferences": .object([
                "ownerApproved": .bool(preferences.ownerApproved),
                "enabled": .bool(preferences.enabled),
                "minimumIntervalHours": .integer(preferences.minimumIntervalHours),
                "quietHoursEnabled": .bool(preferences.quietHoursEnabled),
                "quietHoursStart": .integer(preferences.quietHoursStart),
                "quietHoursEnd": .integer(preferences.quietHoursEnd),
                "appLaunchEnabled": .bool(preferences.appLaunchEnabled),
                "taskCompletionEnabled": .bool(preferences.taskCompletionEnabled),
                "userScheduleEnabled": .bool(preferences.userScheduleEnabled),
                "userScheduleKind": .string(preferences.userScheduleKind),
                "userScheduleLocalTime": .string(preferences.userScheduleLocalTime),
                "userScheduleWeekday": .integer(preferences.userScheduleWeekday),
                "stagingWakeEnabled": .bool(preferences.stagingWakeEnabled),
                "lastOfferedAt": preferences.lastOfferedAt.map(ValueType.string) ?? .null,
                "snoozedUntil": preferences.snoozedUntil.map(ValueType.string) ?? .null,
                "sourceDeviceID": preferences.sourceDeviceID.map(ValueType.string) ?? .null,
                "approvedByIdentityUUID": preferences.approvedByIdentityUUID.map(ValueType.string) ?? .null,
                "approvedBySigningKeyFingerprint": preferences.approvedBySigningKeyFingerprint.map(ValueType.string) ?? .null,
                "updatedAt": .string(preferences.updatedAt)
            ]),
            "lastScheduleSlot": state.lastScheduleSlot.map(ValueType.string) ?? .null,
            "lastScheduleOutcome": state.lastScheduleOutcome.map(ValueType.string) ?? .null,
            "lastWakeReason": state.lastWakeReason.map(ValueType.string) ?? .null,
            "lastWakeAttemptAt": state.lastWakeAttemptAt.map(ValueType.string) ?? .null,
            "lastWakeSucceededAt": state.lastWakeSucceededAt.map(ValueType.string) ?? .null,
            "lastWakeError": state.lastWakeError.map(ValueType.string) ?? .null,
            "lastRemoteIntentID": state.lastRemoteIntentID.map(ValueType.string) ?? .null,
            "updatedAt": .string(state.updatedAt)
        ])
    }

    private func publishConfigurationEvent(
        state: PersonalButlerDaemonState,
        requester: Identity
    ) async {
        let payload: Object = [
            "source": .string("PersonalButlerScheduleCell"),
            "ownerApproved": .bool(state.preferences.ownerApproved),
            "enabled": .bool(state.preferences.enabled),
            "userScheduleEnabled": .bool(state.preferences.userScheduleEnabled),
            "stagingWakeEnabled": .bool(state.preferences.stagingWakeEnabled),
            "minimumIntervalHours": .integer(state.preferences.minimumIntervalHours),
            "updatedAt": .string(state.updatedAt)
        ]
        var flowElement = FlowElement(
            title: "agent.personal-butler.schedule.configured",
            content: .object(payload),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flowElement.topic = "agent.personal-butler.schedule"
        flowElement.origin = uuid
        pushFlowElement(flowElement, requester: requester)
    }

    private func failure(_ status: String, _ message: String) -> ValueType {
        .object([
            "ok": .bool(false),
            "status": .string(status),
            "message": .string(message)
        ])
    }

    private func bool(_ value: ValueType?) -> Bool? {
        guard case let .bool(result)? = value else { return nil }
        return result
    }

    private func integer(_ value: ValueType?) -> Int? {
        switch value {
        case .integer(let result)?: return result
        case .float(let result)?: return Int(result)
        default: return nil
        }
    }

    private func string(_ value: ValueType?) -> String? {
        guard case let .string(result)? = value else { return nil }
        return result
    }

    private func nullableString(_ value: ValueType?) -> String? {
        switch value {
        case .string(let result)?: return result
        case .null?: return nil
        default: return nil
        }
    }
}
