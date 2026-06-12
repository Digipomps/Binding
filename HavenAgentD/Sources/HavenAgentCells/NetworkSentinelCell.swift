// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import CellBase
import HavenAgentRuntime

/// Protocol surface for the local network sentinel.
///
/// Read-only projection of live link health and recent flood events, plus the
/// operator toggle for user notifications. The cell owns no measurement or
/// automation: it reads `NetworkHealthSnapshot` from `AgentRuntimeBridge` and
/// pushes operator changes to the running `NetworkSentinelService` through the
/// bridge control surface. The running runtime drives `emitNetworkEvent(...)`
/// so flood transitions surface as FlowElements with this cell as origin.
public final class NetworkSentinelCell: GeneralCell {
    public static let flowTopicHealth = "network.health"
    public static let flowTopicFlood = "network.health.flood"
    public static let eventDetected = "network.flood.detected"
    public static let eventResolved = "network.flood.resolved"

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

    // MARK: - Permissions

    private func setupPermissions(owner: Identity) async {
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("r---", for: "events")
        agreementTemplate.addGrant("r---", for: "config")
        agreementTemplate.addGrant("rw--", for: "notificationsEnabled")
        agreementTemplate.addGrant("rw--", for: "thresholds")
        agreementTemplate.addGrant("rw--", for: "acknowledge")
        agreementTemplate.addGrant("r---", for: "flow")
    }

    private func authorized(_ access: String, _ key: String, _ requester: Identity) async -> Bool {
        if await validateAccess(access, at: key, for: requester) { return true }
        return await LocalControlCellAccess.isPairedOperator(requester)
    }

    // MARK: - Keys

    private func setupKeys(owner: Identity) async {
        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.authorized("r---", "state", requester) else { return .string("denied") }
            return await self.makeStateValue()
        })

        await addInterceptForGet(requester: owner, key: "events", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.authorized("r---", "events", requester) else { return .string("denied") }
            return await self.makeEventsValue()
        })

        await addInterceptForGet(requester: owner, key: "config", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.authorized("r---", "config", requester) else { return .string("denied") }
            return await self.makeConfigValue()
        })

        await addInterceptForSet(requester: owner, key: "notificationsEnabled", setValueIntercept: { [weak self] _, newValue, requester in
            guard let self else { return nil }
            guard await self.authorized("rw--", "notificationsEnabled", requester) else { return .string("denied") }
            let enabled = Self.boolValue(newValue) ?? true
            if let control = await AgentRuntimeBridge.shared.networkSentinelControlSnapshot() {
                await control.setNotificationsEnabled(enabled)
            }
            return await self.makeConfigValue()
        })

        await addInterceptForSet(requester: owner, key: "thresholds", setValueIntercept: { [weak self] _, newValue, requester in
            guard let self else { return nil }
            guard await self.authorized("rw--", "thresholds", requester) else { return .string("denied") }
            let current = await AgentRuntimeBridge.shared.networkHealthSnapshot()?.thresholds ?? NetworkSentinelThresholds()
            let updated = Self.parseThresholds(newValue, current: current)
            if let control = await AgentRuntimeBridge.shared.networkSentinelControlSnapshot() {
                await control.setThresholds(updated)
            }
            return await self.makeConfigValue()
        })

        await addInterceptForSet(requester: owner, key: "acknowledge", setValueIntercept: { [weak self] _, _, requester in
            guard let self else { return nil }
            guard await self.authorized("rw--", "acknowledge", requester) else { return .string("denied") }
            let acknowledged = await AgentRuntimeBridge.shared.networkSentinelControlSnapshot()?.acknowledgeActiveEvent() ?? false
            return .bool(acknowledged)
        })
    }

    // MARK: - Flow emission (driven by the runtime sentinel service)

    /// Called by the runtime on a flood lifecycle transition. Emits an `.alert`
    /// FlowElement when a flood starts/continues and an `.event` when it
    /// resolves. The flow is emitted regardless of `notificationsEnabled` so the
    /// audit/Porthole trail is always complete; only user-facing delivery is
    /// gated by the toggle (handled by the runtime dispatcher).
    public func emitNetworkEvent(snapshot: NetworkHealthSnapshot, transition: NetworkFloodEvent?) async {
        guard let event = transition else { return }
        let requester = (try? await getOwner(requester: Identity())) ?? Identity()
        let resolved = event.phase == .resolved

        var payload: Object = [
            "eventID": .string(event.id),
            "phase": .string(event.phase.rawValue),
            "classification": .string(event.classification.rawValue),
            "summary": .string(event.summary),
            "interface": .string(snapshot.interface),
            "peakPacketsPerSecond": .integer(event.peakPacketsPerSecond),
            "peakMegabitsPerSecond": .float(event.peakMegabitsPerSecond),
            "startedAt": .string(event.startedAt),
            "updatedAt": .string(event.updatedAt),
            "notificationsEnabled": .bool(snapshot.notificationsEnabled)
        ]
        payload["resolvedAt"] = event.resolvedAt.map(ValueType.string) ?? .null
        payload["capturePath"] = event.capturePath.map(ValueType.string) ?? .null

        var flow = FlowElement(
            title: resolved ? Self.eventResolved : Self.eventDetected,
            content: .object(payload),
            properties: FlowElement.Properties(type: resolved ? .event : .alert, contentType: .object)
        )
        flow.topic = resolved ? Self.flowTopicHealth : Self.flowTopicFlood
        flow.origin = uuid
        pushFlowElement(flow, requester: requester)
    }

    // MARK: - Value projections

    private func makeStateValue() async -> ValueType {
        guard let snapshot = await AgentRuntimeBridge.shared.networkHealthSnapshot() else {
            return .object(["status": .string("unavailable")])
        }
        var object: Object = [
            "interface": .string(snapshot.interface),
            "status": .string(snapshot.status),
            "notificationsEnabled": .bool(snapshot.notificationsEnabled),
            "updatedAt": .string(snapshot.updatedAt),
            "thresholds": thresholdsValue(snapshot.thresholds)
        ]
        object["latest"] = snapshot.latest.map { sampleValue($0) } ?? .null
        object["activeEvent"] = snapshot.activeEvent.map { eventValue($0) } ?? .null
        return .object(object)
    }

    private func makeEventsValue() async -> ValueType {
        guard let snapshot = await AgentRuntimeBridge.shared.networkHealthSnapshot() else {
            return .list([])
        }
        return .list(snapshot.recentEvents.map { eventValue($0) })
    }

    private func makeConfigValue() async -> ValueType {
        let snapshot = await AgentRuntimeBridge.shared.networkHealthSnapshot()
        let thresholds = snapshot?.thresholds ?? NetworkSentinelThresholds()
        return .object([
            "notificationsEnabled": .bool(snapshot?.notificationsEnabled ?? true),
            "thresholds": thresholdsValue(thresholds)
        ])
    }

    private func sampleValue(_ sample: NetworkHealthSample) -> ValueType {
        .object([
            "interface": .string(sample.interface),
            "packetsPerSecond": .integer(sample.packetsPerSecond),
            "bytesPerSecondIn": .integer(sample.bytesPerSecondIn),
            "bytesPerSecondOut": .integer(sample.bytesPerSecondOut),
            "megabitsPerSecond": .float(sample.megabitsPerSecond),
            "errorsPerSecond": .integer(sample.errorsPerSecond),
            "sampledAt": .string(sample.sampledAt)
        ])
    }

    private func eventValue(_ event: NetworkFloodEvent) -> ValueType {
        var object: Object = [
            "id": .string(event.id),
            "phase": .string(event.phase.rawValue),
            "classification": .string(event.classification.rawValue),
            "summary": .string(event.summary),
            "startedAt": .string(event.startedAt),
            "updatedAt": .string(event.updatedAt),
            "peakPacketsPerSecond": .integer(event.peakPacketsPerSecond),
            "peakMegabitsPerSecond": .float(event.peakMegabitsPerSecond),
            "acknowledged": .bool(event.acknowledged)
        ]
        object["resolvedAt"] = event.resolvedAt.map(ValueType.string) ?? .null
        object["capturePath"] = event.capturePath.map(ValueType.string) ?? .null
        return .object(object)
    }

    private func thresholdsValue(_ thresholds: NetworkSentinelThresholds) -> ValueType {
        .object([
            "packetsPerSecond": .integer(thresholds.packetsPerSecond),
            "megabitsPerSecond": .float(thresholds.megabitsPerSecond),
            "errorsPerSecond": .integer(thresholds.errorsPerSecond),
            "sustainedSamples": .integer(thresholds.sustainedSamples),
            "resolveSamples": .integer(thresholds.resolveSamples)
        ])
    }

    // MARK: - Parsing

    private static func boolValue(_ value: ValueType) -> Bool? {
        switch value {
        case .bool(let bool): return bool
        case .integer(let int): return int != 0
        case .number(let int): return int != 0
        case .string(let string):
            switch string.lowercased() {
            case "true", "1", "on", "yes": return true
            case "false", "0", "off", "no": return false
            default: return nil
            }
        default: return nil
        }
    }

    private static func intValue(_ value: ValueType?) -> Int? {
        switch value {
        case .integer(let int): return int
        case .number(let int): return int
        case .float(let double): return Int(double)
        case .string(let string): return Int(string)
        default: return nil
        }
    }

    private static func doubleValue(_ value: ValueType?) -> Double? {
        switch value {
        case .float(let double): return double
        case .integer(let int): return Double(int)
        case .number(let int): return Double(int)
        case .string(let string): return Double(string)
        default: return nil
        }
    }

    private static func parseThresholds(_ value: ValueType, current: NetworkSentinelThresholds) -> NetworkSentinelThresholds {
        guard case let .object(object) = value else { return current }
        return NetworkSentinelThresholds(
            packetsPerSecond: intValue(object["packetsPerSecond"]) ?? current.packetsPerSecond,
            megabitsPerSecond: doubleValue(object["megabitsPerSecond"]) ?? current.megabitsPerSecond,
            errorsPerSecond: intValue(object["errorsPerSecond"]) ?? current.errorsPerSecond,
            sustainedSamples: intValue(object["sustainedSamples"]) ?? current.sustainedSamples,
            resolveSamples: intValue(object["resolveSamples"]) ?? current.resolveSamples
        )
    }
}
