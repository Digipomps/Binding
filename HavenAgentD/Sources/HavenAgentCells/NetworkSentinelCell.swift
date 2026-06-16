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
    public static let flowTopicHealth = NetworkSentinelFlowTopics.health
    public static let flowTopicFlood = NetworkSentinelFlowTopics.flood
    public static let eventDetected = NetworkSentinelFlowTopics.detected
    public static let eventResolved = NetworkSentinelFlowTopics.resolved

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
        agreementTemplate.addGrant("rw--", for: "selectTab")
        agreementTemplate.addGrant("rw--", for: "probe")
        agreementTemplate.addGrant("rw--", for: "probeTarget")
        agreementTemplate.addGrant("rw--", for: "captureNow")
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

        // Flat read for the Toggle control to bind its current on/off state.
        await addInterceptForGet(requester: owner, key: "notificationsEnabled", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.authorized("r---", "notificationsEnabled", requester) else { return .string("denied") }
            let enabled = await AgentRuntimeBridge.shared.networkHealthSnapshot()?.notificationsEnabled ?? true
            return .bool(enabled)
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

        await addInterceptForSet(requester: owner, key: "selectTab", setValueIntercept: { [weak self] _, newValue, requester in
            guard let self else { return nil }
            guard await self.authorized("rw--", "selectTab", requester) else { return .string("denied") }
            if let tab = Self.stringFromValue(newValue),
               let control = await AgentRuntimeBridge.shared.networkSentinelControlSnapshot() {
                await control.setActiveTab(tab)
            }
            return await self.makeStateValue()
        })

        await addInterceptForSet(requester: owner, key: "probeTarget", setValueIntercept: { [weak self] _, newValue, requester in
            guard let self else { return nil }
            guard await self.authorized("rw--", "probeTarget", requester) else { return .string("denied") }
            if let target = Self.stringFromValue(newValue),
               let control = await AgentRuntimeBridge.shared.networkSentinelControlSnapshot() {
                await control.setProbeTarget(target)
            }
            return await self.makeStateValue()
        })

        await addInterceptForSet(requester: owner, key: "probe", setValueIntercept: { [weak self] _, newValue, requester in
            guard let self else { return nil }
            guard await self.authorized("rw--", "probe", requester) else { return .string("denied") }
            guard let control = await AgentRuntimeBridge.shared.networkSentinelControlSnapshot() else {
                return .string("Sensor ikke tilgjengelig.")
            }
            if let target = Self.stringFromValue(newValue), target.isEmpty == false {
                await control.setProbeTarget(target)
            }
            return .string(await control.runProbe())
        })

        await addInterceptForSet(requester: owner, key: "captureNow", setValueIntercept: { [weak self] _, _, requester in
            guard let self else { return nil }
            guard await self.authorized("rw--", "captureNow", requester) else { return .string("denied") }
            guard let control = await AgentRuntimeBridge.shared.networkSentinelControlSnapshot() else {
                return .string("Sensor ikke tilgjengelig.")
            }
            return .string(await control.captureNow())
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

        // Purpose/Goal evaluation travels in the payload so an in-HAVEN surface sees
        // WHY this matters (which formål is at risk), not just raw metrics.
        let evaluation = NetworkHealthPurposeCatalog.evaluate(snapshot: snapshot, transition: event)
        payload["purpose"] = .string(evaluation.purposeRef)
        payload["goalID"] = .string(evaluation.goalID)
        payload["goalStatus"] = .string(evaluation.status.rawValue)
        payload["goalProgress"] = .float(evaluation.progress)

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

    /// The GUI tabs (stable order). Bound by the skeleton's Tabs element via
    /// `navigation.tabs` (labels) and `navigation.activeTab` (selection).
    private static let tabDefinitions: [(id: String, title: String)] = [
        ("dashboard", "Oversikt"),
        ("devices", "Enheter"),
        ("events", "Hendelser"),
        ("tools", "Verktøy"),
        ("settings", "Innstillinger")
    ]

    private func navigationValue(activeTab: String) -> ValueType {
        let tabs = Self.tabDefinitions.map { tab in
            ValueType.object(["id": .string(tab.id), "title": .string(tab.title)])
        }
        return .object(["activeTab": .string(activeTab), "tabs": .list(tabs)])
    }

    /// Rich, display-ready projection bound by the CellConfiguration skeleton.
    /// Always includes `navigation` so the tabbed GUI renders even before the
    /// first measurement or when the interface is unavailable.
    private func makeStateValue() async -> ValueType {
        guard let snapshot = await AgentRuntimeBridge.shared.networkHealthSnapshot() else {
            return .object([
                "status": .string("unavailable"),
                "statusText": .string("Sensor ikke startet ennå."),
                "navigation": navigationValue(activeTab: "dashboard"),
                "metrics": metricsValue(nil),
                "events": .list([]),
                "interfaces": .list([]),
                "history": .list([]),
                "activeEventText": .string("Venter på sensoren …"),
                "hasActiveEvent": .bool(false)
            ])
        }

        let goal = NetworkHealthPurposeCatalog.evaluate(snapshot: snapshot, transition: nil)

        var object: Object = [
            "interface": .string(snapshot.interface),
            "status": .string(snapshot.status),
            "statusText": .string(Self.statusText(snapshot)),
            "updatedAt": .string(snapshot.updatedAt),
            "notificationsEnabled": .bool(snapshot.notificationsEnabled),
            "navigation": navigationValue(activeTab: snapshot.activeTab),
            "metrics": metricsValue(snapshot.latest),
            "goal": .object([
                "status": .string(goal.status.rawValue),
                "statusText": .string(Self.goalStatusText(goal.status)),
                "purpose": .string(goal.purposeRef)
            ]),
            "thresholds": thresholdsValue(snapshot.thresholds),
            "probe": .object([
                "target": .string(snapshot.probeTarget),
                "result": .string(snapshot.probeResult ?? "Ingen test kjørt ennå.")
            ]),
            "capture": .object([
                "summary": .string(snapshot.lastCaptureSummary ?? "Ingen manuell capture ennå.")
            ]),
            "events": .list(snapshot.recentEvents.reversed().map { eventRowValue($0) }),
            "interfaces": .list(snapshot.interfaces.map { interfaceRowValue($0) }),
            "history": .list(snapshot.recentSamples.suffix(20).reversed().map { historyRowValue($0) })
        ]
        if let active = snapshot.activeEvent {
            object["activeEvent"] = eventValue(active)
            object["activeEventText"] = .string(active.summary)
            object["hasActiveEvent"] = .bool(true)
        } else {
            object["activeEvent"] = .null
            object["activeEventText"] = .string("Ingen aktiv hendelse — nettet er rolig.")
            object["hasActiveEvent"] = .bool(false)
        }
        return .object(object)
    }

    private static func statusText(_ snapshot: NetworkHealthSnapshot) -> String {
        switch snapshot.status {
        case "flooding": return "⚠︎ Mulig flom pågår"
        case "unavailable": return "Grensesnitt utilgjengelig"
        default: return "✓ Rolig"
        }
    }

    private static func goalStatusText(_ status: GoalStatus) -> String {
        switch status {
        case .satisfied: return "Sunt nett"
        case .atRisk: return "Formål truet"
        case .missed: return "Vedvarende problem"
        case .unknown: return "Ukjent (ingen fersk data)"
        default: return status.rawValue
        }
    }

    private static func phaseText(_ phase: NetworkFloodPhase) -> String {
        switch phase {
        case .started: return "Startet"
        case .ongoing: return "Pågår"
        case .resolved: return "Løst"
        }
    }

    private func metricsValue(_ sample: NetworkHealthSample?) -> ValueType {
        guard let sample else {
            return .object([
                "pps": .integer(0),
                "ppsText": .string("0 pk/s"),
                "mbpsText": .string("0.0 Mbps"),
                "errorsPerSecond": .integer(0),
                "summary": .string("Venter på første måling …")
            ])
        }
        let mbps = String(format: "%.1f", sample.megabitsPerSecond)
        return .object([
            "pps": .integer(sample.packetsPerSecond),
            "ppsText": .string("\(sample.packetsPerSecond) pk/s"),
            "mbps": .float(sample.megabitsPerSecond),
            "mbpsText": .string("\(mbps) Mbps"),
            "errorsPerSecond": .integer(sample.errorsPerSecond),
            "summary": .string("\(sample.packetsPerSecond) pk/s · \(mbps) Mbps · \(sample.errorsPerSecond) feil/s")
        ])
    }

    private func eventRowValue(_ event: NetworkFloodEvent) -> ValueType {
        .object([
            "id": .string(event.id),
            "title": .string(event.summary),
            "subtitle": .string("\(Self.phaseText(event.phase)) · \(event.classification.rawValue)"),
            "detail": .string("Start: \(event.startedAt)" + (event.resolvedAt.map { " · Slutt: \($0)" } ?? "")),
            "note": .string(event.capturePath.map { "pcap: \($0)" } ?? "")
        ])
    }

    private func interfaceRowValue(_ info: InterfaceInfo) -> ValueType {
        .object([
            "id": .string(info.name),
            "title": .string("\(info.name)  \(info.isUp ? "● oppe" : "○ nede")"),
            "subtitle": .string(info.addressSummary),
            "detail": .string(info.macAddress.map { "MAC: \($0)" } ?? "")
        ])
    }

    private func historyRowValue(_ sample: NetworkHealthSample) -> ValueType {
        let mbps = String(format: "%.1f", sample.megabitsPerSecond)
        return .object([
            "id": .string(sample.sampledAt),
            "title": .string("\(sample.packetsPerSecond) pk/s · \(mbps) Mbps"),
            "subtitle": .string(sample.sampledAt)
        ])
    }

    private static func stringFromValue(_ value: ValueType) -> String? {
        switch value {
        case .string(let string):
            return string
        case .integer(let integer):
            return String(integer)
        case .object(let object):
            for key in ["id", "value", "tab", "target", "selected"] {
                if case let .string(string)? = object[key] { return string }
            }
            if case let .object(selected)? = object["selected"], case let .string(string)? = selected["id"] {
                return string
            }
            return nil
        default:
            return nil
        }
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
