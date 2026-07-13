// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import SwiftUI
import Combine
import CellBase

nonisolated enum ConferenceNearbyRadarSurfaceMode: Equatable {
    case compact
    case full
}

nonisolated struct ConferenceNearbyRadarSurfaceNode: Identifiable, Hashable {
    var id: String { remoteUUID }

    var remoteUUID: String
    var title: String
    var subtitle: String
    var detail: String
    var distanceText: String
    var xNormalized: Double?
    var yNormalized: Double?
    var radiusNormalized: Double
    var azimuthRadians: Double?
    var positionPrecision: String
    var directionConfidence: String
    var uncertaintySummary: String
    var isSelected: Bool
    var isStale: Bool
    var connected: Bool
    var freshnessLabel: String
    var relevanceBadge: String
    var tierLabel: String
    var relationBadge: String
    var followUpReady: Bool
    var followUpMarked: Bool

    var hasPrecisePosition: Bool {
        positionPrecision == "precise" && xNormalized != nil && yNormalized != nil
    }

    var initials: String {
        let parts = title
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
        let value = String(parts).uppercased()
        return value.isEmpty ? "?" : value
    }

    init?(object: Object) {
        guard let remoteUUID = Self.string(from: object["remoteUUID"])?.trimmingCharacters(in: .whitespacesAndNewlines),
              !remoteUUID.isEmpty else {
            return nil
        }

        self.remoteUUID = remoteUUID
        self.title = Self.string(from: object["title"]) ?? Self.string(from: object["displayName"]) ?? remoteUUID
        self.subtitle = Self.string(from: object["subtitle"]) ?? ""
        self.detail = Self.string(from: object["detail"]) ?? ""
        self.distanceText = Self.string(from: object["distanceText"]) ?? ""
        self.xNormalized = Self.double(from: object["xNormalized"])
        self.yNormalized = Self.double(from: object["yNormalized"])
        self.radiusNormalized = Self.double(from: object["radiusNormalized"]) ?? 0.72
        self.azimuthRadians = Self.double(from: object["azimuthRadians"])
        self.positionPrecision = Self.string(from: object["positionPrecision"]) ?? "unknown"
        self.directionConfidence = Self.string(from: object["directionConfidence"]) ?? "unknown"
        self.uncertaintySummary = Self.string(from: object["uncertaintySummary"]) ?? ""
        self.isSelected = Self.bool(from: object["isSelected"]) ?? false
        self.isStale = Self.bool(from: object["isStale"]) ?? false
        self.connected = Self.bool(from: object["connected"]) ?? false
        self.freshnessLabel = Self.string(from: object["freshnessLabel"]) ?? ""
        self.relevanceBadge = Self.string(from: object["relevanceBadge"]) ?? ""
        self.tierLabel = Self.string(from: object["tierLabel"]) ?? ""
        self.relationBadge = Self.string(from: object["relationBadge"]) ?? ""
        self.followUpReady = Self.bool(from: object["followUpReady"]) ?? false
        self.followUpMarked = Self.bool(from: object["followUpMarked"]) ?? false
    }

    private static func string(from value: ValueType?) -> String? {
        guard case let .string(string)? = value else { return nil }
        return string
    }

    private static func bool(from value: ValueType?) -> Bool? {
        guard case let .bool(bool)? = value else { return nil }
        return bool
    }

    private static func double(from value: ValueType?) -> Double? {
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
}

nonisolated struct ConferenceNearbyRadarSurfaceSnapshot: Hashable {
    var headline: String
    var statusSummary: String
    var precisionSummary: String
    var spatialTruthSummary: String
    var transportBadge: String
    var precisionBadge: String
    var surfaceSummary: String
    var selectedRemoteUUID: String?
    var selectedNode: ConferenceNearbyRadarSurfaceNode?
    var preciseNodes: [ConferenceNearbyRadarSurfaceNode]
    var approximateNodes: [ConferenceNearbyRadarSurfaceNode]
    var updatedAtEpoch: Double
    var lastError: String?

    static let empty = ConferenceNearbyRadarSurfaceSnapshot(
        headline: "Nearby Participants",
        statusSummary: "Nearby-radaren venter på lokal runtime.",
        precisionSummary: "Precision status is not loaded yet.",
        spatialTruthSummary: "Retning vises først når nearby-signalet faktisk inneholder retning.",
        transportBadge: "MPC",
        precisionBadge: "UNKNOWN",
        surfaceSummary: "Ingen live nearby-noder ennå.",
        selectedRemoteUUID: nil,
        selectedNode: nil,
        preciseNodes: [],
        approximateNodes: [],
        updatedAtEpoch: 0,
        lastError: nil
    )

    init(
        headline: String,
        statusSummary: String,
        precisionSummary: String,
        spatialTruthSummary: String,
        transportBadge: String,
        precisionBadge: String,
        surfaceSummary: String,
        selectedRemoteUUID: String?,
        selectedNode: ConferenceNearbyRadarSurfaceNode?,
        preciseNodes: [ConferenceNearbyRadarSurfaceNode],
        approximateNodes: [ConferenceNearbyRadarSurfaceNode],
        updatedAtEpoch: Double,
        lastError: String?
    ) {
        self.headline = headline
        self.statusSummary = statusSummary
        self.precisionSummary = precisionSummary
        self.spatialTruthSummary = spatialTruthSummary
        self.transportBadge = transportBadge
        self.precisionBadge = precisionBadge
        self.surfaceSummary = surfaceSummary
        self.selectedRemoteUUID = selectedRemoteUUID
        self.selectedNode = selectedNode
        self.preciseNodes = preciseNodes
        self.approximateNodes = approximateNodes
        self.updatedAtEpoch = updatedAtEpoch
        self.lastError = lastError
    }

    init(value: ValueType) {
        guard let state = Self.object(from: value) else {
            self = .empty
            return
        }

        let radarLayout = Self.object(from: state["radarLayout"])
        let surface = Self.object(from: radarLayout?["surface"])
        let selectedRemoteUUID = Self.nonEmptyString(from: surface?["selectedRemoteUUID"])
            ?? Self.nonEmptyString(from: state["selectedRemoteUUID"])
        let selectedNode = Self.object(from: surface?["selectedNode"]).flatMap(ConferenceNearbyRadarSurfaceNode.init)
        let preciseNodes = Self.nodes(from: surface?["preciseNodes"])
        let approximateNodes = Self.nodes(from: surface?["approximateNodes"])

        self.headline = Self.string(from: state["headline"]) ?? "Nearby Participants"
        self.statusSummary = Self.string(from: state["statusSummary"]) ?? ""
        self.precisionSummary = Self.string(from: state["precisionSummary"]) ?? ""
        self.spatialTruthSummary = Self.string(from: state["spatialTruthSummary"]) ?? ""
        self.transportBadge = Self.string(from: state["transportBadge"]) ?? ""
        self.precisionBadge = Self.string(from: state["precisionBadge"]) ?? ""
        self.surfaceSummary = Self.string(from: surface?["summary"]) ?? ""
        self.selectedRemoteUUID = selectedRemoteUUID
        self.selectedNode = selectedNode ?? preciseNodes.first(where: \.isSelected) ?? approximateNodes.first(where: \.isSelected)
        self.preciseNodes = preciseNodes
        self.approximateNodes = approximateNodes
        self.updatedAtEpoch = Self.double(from: surface?["updatedAtEpoch"]) ?? 0
        self.lastError = Self.nonEmptyString(from: state["lastError"])
    }

    init(flowContent: FlowElementValueType) {
        switch flowContent {
        case let .object(object):
            self.init(value: .object(object))
        case let .list(list):
            self.init(value: .list(list))
        case let .string(string):
            self.init(value: .string(string))
        case let .number(number):
            self.init(value: .number(number))
        case let .bool(bool):
            self.init(value: .bool(bool))
        case let .data(data):
            self.init(value: .data(data))
        }
    }

    private static func nodes(from value: ValueType?) -> [ConferenceNearbyRadarSurfaceNode] {
        guard case let .list(values)? = value else { return [] }
        return values.compactMap { value in
            guard case let .object(object) = value else { return nil }
            return ConferenceNearbyRadarSurfaceNode(object: object)
        }
    }

    private static func object(from value: ValueType?) -> Object? {
        guard case let .object(object)? = value else { return nil }
        return object
    }

    private static func string(from value: ValueType?) -> String? {
        guard case let .string(string)? = value else { return nil }
        return string
    }

    private static func nonEmptyString(from value: ValueType?) -> String? {
        guard let string = string(from: value)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty else {
            return nil
        }
        return string
    }

    private static func double(from value: ValueType?) -> Double? {
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
}

@MainActor
final class ConferenceNearbyRadarSurfaceModel: ObservableObject {
    @Published var snapshot = ConferenceNearbyRadarSurfaceSnapshot.empty
    @Published var connectionSummary = "Kobler til nearby radar..."

    private var meddle: Meddle?
    private var requester: Identity?
    private var flowCancellable: AnyCancellable?
    private var connectTask: Task<Void, Never>?

    deinit {
        connectTask?.cancel()
        flowCancellable?.cancel()
    }

    func connectIfNeeded() {
        guard connectTask == nil else { return }
        connectTask = Task { [weak self] in
            await self?.connect()
        }
    }

    func refresh() {
        Task { [weak self] in
            await self?.refreshSnapshot()
        }
    }

    func select(_ node: ConferenceNearbyRadarSurfaceNode) {
        Task { [weak self] in
            await self?.dispatchRadarAction(
                "selectEntity",
                payload: .object(["remoteUUID": .string(node.remoteUUID)])
            )
        }
    }

    func startScanner() {
        Task { [weak self] in
            await self?.dispatchRadarAction("start", payload: .bool(true))
        }
    }

    func stopScanner() {
        Task { [weak self] in
            await self?.dispatchRadarAction("stop", payload: .bool(true))
        }
    }

    func requestContact() {
        guard let remoteUUID = snapshot.selectedRemoteUUID else { return }
        Task { [weak self] in
            await self?.dispatchRadarAction("requestContact", payload: .string(remoteUUID))
        }
    }

    func toggleFollowUp() {
        guard let remoteUUID = snapshot.selectedRemoteUUID else { return }
        Task { [weak self] in
            await self?.dispatchRadarAction(
                "toggleFollowUp",
                payload: .object(["remoteUUID": .string(remoteUUID)])
            )
        }
    }

    func openFollowUpChat() {
        guard let remoteUUID = snapshot.selectedRemoteUUID else { return }
        Task { [weak self] in
            await self?.dispatchRadarAction(
                "openFollowUpChat",
                payload: .object(["remoteUUID": .string(remoteUUID)])
            )
        }
    }

    func openSelectedParticipantWorkbench() {
        guard snapshot.selectedRemoteUUID != nil else { return }
        Task { [weak self] in
            await self?.dispatchRadarAction("openSelectedParticipantWorkbench", payload: .bool(true))
        }
    }

    private func connect() async {
        guard await BindingLocalCellRegistration.shared.ensureConferenceDemoRuntimeReady() else {
            connectionSummary = "Kunne ikke validere lokal conference-runtime."
            return
        }

        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let vault = CellBase.defaultIdentityVault,
              let identity = await vault.identity(for: "private", makeNewIfNotFound: true) else {
            connectionSummary = "Kunne ikke finne lokal CellResolver eller requester identity."
            return
        }

        do {
            let cell = try await resolver.cellAtEndpoint(endpoint: "cell:///ConferenceNearbyRadar", requester: identity)
            guard let radarMeddle = cell as? Meddle else {
                connectionSummary = "ConferenceNearbyRadar er ikke tilgjengelig som Meddle."
                return
            }

            requester = identity
            meddle = radarMeddle
            connectionSummary = "Live nearby radar tilkoblet."

            let publisher = try await cell.flow(requester: identity)
            flowCancellable = publisher
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    if case let .failure(error) = completion {
                        self?.connectionSummary = "Radar-flow stoppet: \(error)"
                    }
                }, receiveValue: { [weak self] element in
                    guard element.topic == "nearbyRadar.snapshot" else { return }
                    self?.snapshot = ConferenceNearbyRadarSurfaceSnapshot(flowContent: element.content)
                })

            await refreshSnapshot()
        } catch {
            connectionSummary = "Kunne ikke koble til nearby radar: \(error)"
        }
    }

    private func refreshSnapshot() async {
        guard let meddle, let requester else { return }
        do {
            snapshot = ConferenceNearbyRadarSurfaceSnapshot(
                value: try await meddle.get(keypath: "state", requester: requester)
            )
        } catch {
            connectionSummary = "Kunne ikke lese nearby radar: \(error)"
        }
    }

    private func dispatchRadarAction(_ keypath: String, payload: ValueType) async {
        guard let meddle, let requester else { return }
        do {
            let response = try await meddle.set(
                keypath: "dispatchAction",
                value: .object([
                    "keypath": .string(keypath),
                    "payload": payload
                ]),
                requester: requester
            )
            if let response {
                snapshot = ConferenceNearbyRadarSurfaceSnapshot(value: response)
            } else {
                await refreshSnapshot()
            }
        } catch {
            connectionSummary = "Radar-handling feilet: \(error)"
        }
    }
}

struct ConferenceNearbyRadarSurfaceView: View {
    let mode: ConferenceNearbyRadarSurfaceMode

    @StateObject private var model = ConferenceNearbyRadarSurfaceModel()

    var body: some View {
        VStack(alignment: .leading, spacing: mode == .full ? 14 : 10) {
            header
            RadarPlotView(
                snapshot: model.snapshot,
                mode: mode,
                onSelect: model.select
            )
            .frame(height: mode == .full ? 420 : 230)

            if mode == .full {
                selectedActionStrip
            }
        }
        .padding(mode == .full ? 16 : 12)
        .background(surfaceBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task {
            model.connectIfNeeded()
        }
    }

    private var surfaceBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(uiColorOrNSColor: .windowLike).opacity(0.94))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(mode == .full ? "Live Nearby Radar" : "Nearby Radar")
                    .font(mode == .full ? .title3.weight(.semibold) : .headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(model.snapshot.surfaceSummary.isEmpty ? model.connectionSummary : model.snapshot.surfaceSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            badge(model.snapshot.transportBadge.isEmpty ? "MPC" : model.snapshot.transportBadge)
            badge(model.snapshot.precisionBadge.isEmpty ? "UNKNOWN" : model.snapshot.precisionBadge)

            Button {
                model.startScanner()
            } label: {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("Start scanner")

            Button {
                model.stopScanner()
            } label: {
                Image(systemName: "stop.fill")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("Stop scanner")

            Button {
                model.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("Refresh radar")
        }
    }

    private var selectedActionStrip: some View {
        let selected = model.snapshot.selectedNode
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(selected?.title ?? "Ingen deltager valgt")
                    .font(.headline)
                Text(selected?.detail ?? "Velg en node i radaren for å holde personen i sentrum.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                radarActionButton("Profil", systemImage: "person.crop.square", disabled: selected == nil) {
                    model.openSelectedParticipantWorkbench()
                }
                radarActionButton("Kontakt", systemImage: "person.badge.plus", disabled: selected == nil) {
                    model.requestContact()
                }
                radarActionButton(
                    selected?.followUpMarked == true ? "Fjern markering" : "Marker",
                    systemImage: selected?.followUpMarked == true ? "bookmark.slash" : "bookmark",
                    disabled: selected == nil
                ) {
                    model.toggleFollowUp()
                }
                radarActionButton("Chat", systemImage: "message", disabled: selected?.followUpReady != true) {
                    model.openFollowUpChat()
                }
            }
        }
    }

    private func radarActionButton(
        _ title: String,
        systemImage: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(disabled)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.08), in: Capsule())
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

private struct RadarPlotView: View {
    let snapshot: ConferenceNearbyRadarSurfaceSnapshot
    let mode: ConferenceNearbyRadarSurfaceMode
    let onSelect: (ConferenceNearbyRadarSurfaceNode) -> Void

    @State private var sweepRotation: Angle = .degrees(0)

    var body: some View {
        GeometryReader { proxy in
            let railWidth = mode == .full ? min(220, proxy.size.width * 0.28) : 0
            let plotWidth = mode == .full ? max(220, proxy.size.width - railWidth - 12) : proxy.size.width
            let diameter = min(plotWidth, proxy.size.height)
            let radius = diameter / 2
            let center = CGPoint(x: plotWidth / 2, y: proxy.size.height / 2)

            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    radarGrid(diameter: diameter)
                        .frame(width: diameter, height: diameter)
                        .position(center)

                    sweep(radius: radius)
                        .position(center)
                        .rotationEffect(sweepRotation)
                        .opacity(snapshot.preciseNodes.isEmpty ? 0.2 : 0.5)

                    ForEach(snapshot.preciseNodes) { node in
                        RadarNodeButton(node: node, mode: mode) {
                            onSelect(node)
                        }
                        .position(point(for: node, center: center, radius: radius))
                        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: node)
                    }

                    RadarCenterFocusView(
                        node: snapshot.selectedNode,
                        nodeCount: snapshot.preciseNodes.count + snapshot.approximateNodes.count,
                        mode: mode
                    )
                    .frame(width: mode == .full ? 172 : 132)
                    .position(center)
                }
                .frame(width: plotWidth, height: proxy.size.height)

                if mode == .full {
                    UncertaintyRailView(nodes: snapshot.approximateNodes, onSelect: onSelect)
                        .frame(width: railWidth, height: proxy.size.height)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if mode == .compact, !snapshot.approximateNodes.isEmpty {
                    UncertaintyCompactStrip(nodes: snapshot.approximateNodes, onSelect: onSelect)
                        .padding(8)
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 3.4).repeatForever(autoreverses: false)) {
                sweepRotation = .degrees(360)
            }
        }
    }

    private func point(
        for node: ConferenceNearbyRadarSurfaceNode,
        center: CGPoint,
        radius: CGFloat
    ) -> CGPoint {
        let x = node.xNormalized ?? 0
        let y = node.yNormalized ?? 0
        return CGPoint(
            x: center.x + CGFloat(x) * radius,
            y: center.y - CGFloat(y) * radius
        )
    }

    private func radarGrid(diameter: CGFloat) -> some View {
        ZStack {
            ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { scale in
                Circle()
                    .stroke(Color.primary.opacity(scale == 1.0 ? 0.18 : 0.1), lineWidth: scale == 1.0 ? 1.4 : 1)
                    .frame(width: diameter * scale, height: diameter * scale)
            }

            Rectangle()
                .fill(Color.primary.opacity(0.09))
                .frame(width: 1, height: diameter)
            Rectangle()
                .fill(Color.primary.opacity(0.09))
                .frame(width: diameter, height: 1)
            Text("FORAN")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .offset(y: -diameter / 2 + 14)
        }
    }

    private func sweep(radius: CGFloat) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.6), Color.accentColor.opacity(0.0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: radius, height: 2)
            .offset(x: radius / 2)
    }
}

private struct RadarCenterFocusView: View {
    let node: ConferenceNearbyRadarSurfaceNode?
    let nodeCount: Int
    let mode: ConferenceNearbyRadarSurfaceMode

    var body: some View {
        VStack(spacing: 4) {
            Text(node?.title ?? "Velg deltager")
                .font(mode == .full ? .subheadline.weight(.semibold) : .caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(node?.distanceText.isEmpty == false ? node?.distanceText ?? "" : "\(nodeCount) nearby")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let node {
                Text(node.positionPrecision == "precise" ? "presis retning" : "retning usikker")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(node.positionPrecision == "precise" ? Color.green : Color.orange)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct RadarNodeButton: View {
    let node: ConferenceNearbyRadarSurfaceNode
    let mode: ConferenceNearbyRadarSurfaceMode
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(node.initials)
                    .font(.caption.weight(.bold))
                    .frame(width: mode == .full ? 34 : 28, height: mode == .full ? 34 : 28)
                    .background(nodeColor, in: Circle())
                    .foregroundStyle(.white)
                    .overlay(
                        Circle()
                            .stroke(node.isSelected ? Color.white : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: nodeColor.opacity(node.isStale ? 0.12 : 0.38), radius: 8, y: 3)

                if mode == .full {
                    Text(node.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .frame(width: 88)
                }
            }
            .opacity(node.isStale ? 0.48 : 1)
        }
        .buttonStyle(.plain)
        .help("\(node.title) · \(node.detail)")
    }

    private var nodeColor: Color {
        switch node.tierLabel {
        case "strong":
            return .green
        case "promising":
            return .cyan
        case "good", "moderate":
            return .yellow
        case "low":
            return .red
        default:
            return .blue
        }
    }
}

private struct UncertaintyRailView: View {
    let nodes: [ConferenceNearbyRadarSurfaceNode]
    let onSelect: (ConferenceNearbyRadarSurfaceNode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Retning usikker")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if nodes.isEmpty {
                Text("Ingen omtrentlige treff.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(nodes) { node in
                    Button {
                        onSelect(node)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(node.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(node.distanceText)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Text(node.uncertaintySummary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(node.isSelected ? 0.18 : 0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

private struct UncertaintyCompactStrip: View {
    let nodes: [ConferenceNearbyRadarSurfaceNode]
    let onSelect: (ConferenceNearbyRadarSurfaceNode) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(nodes) { node in
                    Button {
                        onSelect(node)
                    } label: {
                        Text("\(node.title) · \(node.distanceText)")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.orange.opacity(0.14), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private extension Color {
    enum PlatformSurfaceColor {
        case windowLike
    }

    init(uiColorOrNSColor platformColor: PlatformSurfaceColor) {
        switch platformColor {
        case .windowLike:
#if canImport(UIKit)
            self = Color(uiColor: .secondarySystemBackground)
#elseif canImport(AppKit)
            self = Color(nsColor: .controlBackgroundColor)
#else
            self = Color(.white)
#endif
        }
    }
}
