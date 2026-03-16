//
//  ContentView.swift
//  Binding
//
//  Created by Kjetil Hustveit on 16/12/2025.
//

import SwiftUI
import Combine
import CellBase
import CellApple
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private static let stagingHost = "staging.haven.digipomps.org"
    private static let defaultRemoteWebSocketPath = "publishersws"
    private static let stagingRemoteWebSocketPath = "bridgehead"
    private static let portholeEndpoint = "cell:///Porthole"
    private static let blockedLoadedReferenceNames: Set<String> = [
        "eventemitter",
        "entitieswrapper",
        "timeswrapper",
        "locationswrapper"
    ]
    // Only cells that are actually hosted by CellScaffold should be auto-retargeted
    // from `cell:///...` to the staging scaffold. Local CellApple-only cells must stay local.
    private static let stagingFallbackCells: Set<String> = [
        "chat",
        "conferenceuirouter",
        "vault",
        "todo",
        "adminentry",
        "adminoverview",
        "adminfunding",
        "adminfundingqueue",
        "adminresolverstats",
        "adminstoragestats",
        "adminhostmetrics",
        "adminprocesses",
        "adminroleenrollment",
        "adminsecuritypolicy",
        "leadvault",
        "consentreceipt",
        "exhibitoraccess",
        "deviceregistration",
        "notificationoutbox",
        "notificationpolicy",
        "devicecallbackbridge"
    ]

    private struct CatalogSource {
        let endpoint: String
        let allowSync: Bool
    }

    private struct CatalogOrigin {
        let host: String
        let port: Int?
        let route: RemoteCellHostRoute
        let websocketScheme: String
        let useDirectWebSocketForLocalReferences: Bool
    }

    private typealias MenuConfigurationBuckets = (
        upperLeft: [CellConfiguration],
        upperMid: [CellConfiguration],
        upperRight: [CellConfiguration],
        lowerLeft: [CellConfiguration],
        lowerMid: [CellConfiguration],
        lowerRight: [CellConfiguration]
    )

    @StateObject private var viewModel = PortholeBindingViewModel()
    @StateObject private var legacyPortholeViewModel = PortholeViewModel()
    @StateObject private var editorState = EditorState()
    @StateObject private var bridgeStatusStore = BridgeConnectionStatusStore()
    @State private var floatingPanelsController = SkeletonEditorFloatingPanelsController()
    @State private var editorMode: EditorMode = .view
    @State private var menusHidden: Bool = false
    @State private var rotationAccumulator: Angle = .zero
    @State private var didAttemptCatalogMenuSync: Bool = false
    @State private var activeConfiguration: CellConfiguration?
    @State private var presentingFullLibrary: Bool = false
    @State private var loadErrorMessage: String?
    @State private var copyStatusMessage: String?
    @State private var catalogMenuPool: [CellConfiguration] = []
    @State private var lastPerspectiveMenuSignature: String = ""
    @State private var compactEditorDrawerVisible = false
    @State private var compactComponentsExpanded = true
    @State private var compactElementsExpanded = true
    @State private var compactInspectorExpanded = true
    @State private var componentCanvasDropTargeted = false
    @State private var activeComponentDragItem: ComponentPaletteItem?
    @State private var armedComponentItem: ComponentPaletteItem?

    private static let defaultRemoteRoute = RemoteCellHostRoute(
        websocketEndpoint: Self.defaultRemoteWebSocketPath,
        schemePreference: .automatic
    )
    private static let stagingRemoteRoute = RemoteCellHostRoute(
        websocketEndpoint: Self.stagingRemoteWebSocketPath,
        schemePreference: .wss
    )

    var body: some View {
        ZStack {
            // Full-screen porthole canvas rendering current skeleton
            PortholeCanvas(
                skeleton: renderedSkeleton,
                isEditing: editorMode == .edit,
                selectedNodePath: editorState.selectedNodePath,
                highlightedDropTargets: activeComponentDropTargets,
                activeComponent: activeComponentInsertionItem,
                isPlacementArmed: isComponentPlacementArmed,
                onSelectPath: { selectedPath in
                    editorState.selectNode(selectedPath)
                    if usesCompactEditorChrome, editorMode == .edit {
                        compactInspectorExpanded = true
                        withAnimation(.easeInOut(duration: 0.2)) {
                            compactEditorDrawerVisible = true
                        }
                    }
                },
                onCancelComponentPlacement: {
                    armedComponentItem = nil
                },
                onApplyComponentDrop: { item, placement in
                    let inserted = applyComponentPaletteItem(item, placement: placement)
                    if !inserted {
                        loadErrorMessage = "Kunne ikke sette inn \(item.title.lowercased()) på valgt punkt."
                    }
                    return inserted
                }
            )
                .environmentObject(viewModel)
                .ignoresSafeArea(.container, edges: [.leading, .trailing, .bottom])
                .dropDestination(for: CellConfiguration.self) { items, location in
                    // On drop, load the configuration into the porthole
                    Task { await loadConfigurationForEditing(items.first) }
                    return !items.isEmpty
                }
                .dropDestination(for: ComponentPaletteItem.self) { items, _ in
                    guard editorMode == .edit else { return false }
                    guard let item = items.first else { return false }
                    let inserted = applyComponentPaletteItem(item)
                    if !inserted {
                        loadErrorMessage = "Ingen gyldig drop-target for \(item.title.lowercased()) i valgt kontekst."
                    }
                    return inserted
                } isTargeted: { isTargeted in
                    componentCanvasDropTargeted = isTargeted
                }
                .overlay {
                    if editorMode == .edit && componentCanvasDropTargeted {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10, 8]))
                            .padding(10)
                            .allowsHitTesting(false)
                    }
                }

            if !usesCompactConvenienceMenus && !menusHidden {
                // Edge menus overlay
                EdgeMenusOverlay(
                    upperLeft: menuItems(from: viewModel.upperLeftMenu),
                    upperMid: menuItems(from: viewModel.upperMidMenu),
                    upperRight: menuItems(from: viewModel.upperRightMenu),
                    lowerLeft: menuItems(from: viewModel.lowerLeftMenu),
                    lowerMid: menuItems(from: viewModel.lowerMidMenu),
                    lowerRight: menuItems(from: viewModel.lowerRightMenu),
                    onPrimaryAction: { position in
                        guard position == .upperMid else { return false }
                        presentingFullLibrary = true
                        return true
                    },
                    onSelect: { config in
                        Task { await loadConfigurationForEditing(config) }
                    }
                )
                .allowsHitTesting(true)
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .gesture(rotationHideShowGesture)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 6) {
                appToolbar
                if let loadErrorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(loadErrorMessage)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Button("Dismiss") {
                            self.loadErrorMessage = nil
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                if let bridgeStatus = bridgeStatusStore.primaryStatus {
                    BridgeStatusBanner(
                        status: bridgeStatus,
                        additionalCount: max(0, bridgeStatusStore.visibleStatuses.count - 1)
                    )
                }
                if let copyStatusMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(copyStatusMessage)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                if usesCompactConvenienceMenus {
                    compactConvenienceTray
                }
            }
                .padding(.horizontal, 12)
                .padding(.top, 6)
        }
        .overlay(alignment: .topLeading) {
#if os(macOS)
            EmptyView()
#else
            if editorMode == .edit && !usesCompactEditorChrome {
                SkeletonTreePanel(editorState: editorState)
                    .padding(.leading, 12)
                    .padding(.top, 72)
            }
#endif
        }
        .overlay(alignment: .topTrailing) {
#if os(macOS)
            EmptyView()
#else
            if editorMode == .edit && !usesCompactEditorChrome {
                SkeletonModifierInspectorPanel(editorState: editorState)
                    .padding(.trailing, 12)
                    .padding(.top, 72)
            }
#endif
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
#if os(macOS)
            EmptyView()
#else
            if editorMode == .edit && usesCompactEditorChrome && compactEditorDrawerVisible {
                compactEditorDrawer
            }
#endif
        }
        .onChange(of: editorMode) { _, mode in
            switch mode {
            case .view:
                applyWorkingCopyToViewer()
                editorState.endEditing()
                compactEditorDrawerVisible = false
                activeComponentDragItem = nil
                armedComponentItem = nil
            case .edit:
                editorState.beginEditing(
                    configuration: currentEditorSeedConfiguration(),
                    fallbackSkeleton: viewModel.currentSkeleton
                )
                compactComponentsExpanded = true
                compactElementsExpanded = true
                compactInspectorExpanded = editorState.selectedNodePath != nil
                activeComponentDragItem = nil
                armedComponentItem = nil
            }
            floatingPanelsController.setEditing(mode == .edit, editorState: editorState)
        }
        .onChange(of: editorState.selectedNodePath) { _, selectedPath in
            guard usesCompactEditorChrome, editorMode == .edit else { return }
            if selectedPath != nil {
                compactInspectorExpanded = true
                withAnimation(.easeInOut(duration: 0.2)) {
                    compactEditorDrawerVisible = true
                }
            }
        }
        .onAppear {
            floatingPanelsController.setEditing(editorMode == .edit, editorState: editorState)
        }
        .onDisappear {
            floatingPanelsController.closePanels()
        }
        .onReceive(viewModel.$currentSkeleton) { next in
            if !editorState.isEditing {
                editorState.captureViewerSnapshot(currentEditorSeedConfiguration(), fallbackSkeleton: next)
            }
        }
        .sheet(isPresented: $presentingFullLibrary) {
            FullLibraryView(
                catalogEndpoints: configuredCatalogSources().map(\.endpoint),
                queryContext: FullLibraryQueryContext(
                    editMode: editorMode == .edit,
                    selectedNodeKind: selectedNodeKindForLibrary,
                    insertionIntent: editorMode == .edit ? .component : .root
                ),
                favorites: viewModel.upperRightMenu,
                templates: viewModel.lowerLeftMenu,
                onAddConfiguration: { configuration in
                    Task { await loadConfigurationForEditing(configuration) }
                },
                onAddComponent: { item in
                    let inserted = applyComponentPaletteItem(item)
                    if !inserted {
                        loadErrorMessage = "Ingen gyldig drop-target for \(item.title.lowercased()) i valgt kontekst."
                    }
                    return inserted
                },
                armedComponentID: armedComponentItem?.id,
                onArmComponent: { item in
                    armComponentPlacement(item)
                },
                onComponentDragStateChange: { item in
                    activeComponentDragItem = item
                }
            )
            .environmentObject(bridgeStatusStore)
#if os(macOS)
            .frame(minWidth: 1020, minHeight: 720)
#else
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
#endif
        }
        .task {
            // Ensure IdentityVault is available for the model
            if CellBase.defaultIdentityVault == nil {
                CellBase.defaultIdentityVault = IdentityVault.shared
                _ = await IdentityVault.shared.initialize()
            }
            // SkeletonList.getElements() uses makeNewIfNotFound=false.
            // Ensure the default private identity exists before list tasks execute.
            _ = await CellBase.defaultIdentityVault?.identity(for: "private", makeNewIfNotFound: true)
            await viewModel.connectIfNeeded()
            let fallbackMenus = curatedMenuSeedConfigurations()
            if usesPerspectiveDrivenEdgeMenus {
                applyPerspectiveDrivenMenus(from: [], fallback: fallbackMenus, profile: .empty)
            } else {
                applyFixedMenuPlacement(fallbackMenus)
            }
            if !didAttemptCatalogMenuSync {
                didAttemptCatalogMenuSync = true
                await refreshMenusFromCatalogIfAvailable()
            }
            editorState.captureViewerSnapshot(currentEditorSeedConfiguration(), fallbackSkeleton: viewModel.currentSkeleton)
        }
        .task {
            await monitorPerspectiveDrivenMenus()
        }
        .environmentObject(legacyPortholeViewModel)
    }

    // MARK: - Rotation gesture to hide/show menus
    private var rotationHideShowGesture: some Gesture {
        RotationGesture()
            .onChanged { angle in
                rotationAccumulator = angle
            }
            .onEnded { angle in
                guard !usesCompactConvenienceMenus else {
                    rotationAccumulator = .zero
                    return
                }
                let threshold: Angle = .degrees(15) // ~0.26 rad ~ 15 degrees
                if angle.radians > threshold.radians {
                    withAnimation(.spring()) { menusHidden = true }
                } else if angle.radians < -threshold.radians {
                    withAnimation(.spring()) { menusHidden = false }
                }
                rotationAccumulator = .zero
            }
    }

    // MARK: - Sample data for menus (replace with real data later)
    private func sampleMenuItems(prefix: String) -> [MenuItem] {
        // Create a few configurations with simple skeletons
        return [
            MenuItem(
                icon: "square.grid.2x2",
                configuration: CellConfiguration(name: "\(prefix) Grid", cellReferences: nil)
            ),
            MenuItem(
                icon: "text.justify",
                configuration: {
                    var conf = CellConfiguration(name: "\(prefix) Text")
                    conf.skeleton = .VStack(
                        SkeletonVStack(elements: [
                            .Text(SkeletonText(text: "\(prefix) – Tittel")),
                            .Text(SkeletonText(text: "Dette er et eksempel på Skeleton UI."))
                        ])
                    )
                    return conf
                }()
            ),
            MenuItem(
                icon: "photo",
                configuration: {
                    var conf = CellConfiguration(name: "\(prefix) Bilde")
                    conf.skeleton = .Image(SkeletonImage(name: "AppIcon"))
                    return conf
                }()
            )
        ]
    }

    private func menuItems(from configs: [CellConfiguration]) -> [MenuItem] {
        return configs
            .map { config in
            // Choose an icon heuristically; you can expand this mapping later
            let icon = config.skeletonIconName
            return MenuItem(icon: icon, configuration: config)
        }
    }

    private var usesPerspectiveDrivenEdgeMenus: Bool {
#if os(macOS)
        false
#else
        true
#endif
    }

    @MainActor
    private func applyFixedMenuPlacement(_ menus: MenuConfigurationBuckets) {
        viewModel.upperLeftMenu = menus.upperLeft
        viewModel.upperMidMenu = menus.upperMid
        viewModel.upperRightMenu = menus.upperRight
        viewModel.lowerLeftMenu = menus.lowerLeft
        viewModel.lowerMidMenu = menus.lowerMid
        viewModel.lowerRightMenu = menus.lowerRight
    }

    @MainActor
    private func refreshMenusFromCatalogIfAvailable() async {
        guard let resolver = CellBase.defaultCellResolver as? CellResolver else { return }
        guard let identity = await CellBase.defaultIdentityVault?.identity(for: "private", makeNewIfNotFound: true) else { return }

        registerRemoteHostIfNeeded(
            Self.stagingHost,
            route: remoteRoute(forHost: Self.stagingHost),
            resolver: resolver
        )

        var mergedUpperLeft: [CellConfiguration] = []
        var mergedUpperMid: [CellConfiguration] = []
        var mergedUpperRight: [CellConfiguration] = []
        var mergedLowerLeft: [CellConfiguration] = []
        var mergedLowerMid: [CellConfiguration] = []
        var mergedLowerRight: [CellConfiguration] = []
        var discoveredByEndpoint: [String: CellConfiguration] = [:]

        for source in configuredCatalogSources() {
            let origin = catalogOrigin(from: source.endpoint)
            if let origin {
                registerRemoteCatalogHostIfNeeded(origin, resolver: resolver)
            }

            guard let catalogEmit = try? await resolver.cellAtEndpoint(endpoint: source.endpoint, requester: identity),
                  let catalog = catalogEmit as? Meddle
            else {
                continue
            }

            if source.allowSync {
                _ = try? await catalog.set(keypath: "syncScaffoldPurposeGoals", value: .null, requester: identity)
            }

            func fetchMenu(_ keypath: String, allowReferenceFree: Bool = false) async -> [CellConfiguration] {
                guard let value = try? await catalog.get(keypath: keypath, requester: identity) else { return [] }
                let normalized = normalizeCatalogMenu(
                    value.cellConfigurations,
                    origin: origin,
                    resolver: resolver,
                    allowReferenceFree: allowReferenceFree
                )
                return normalized.filter { !isEmitterConfiguration($0) }
            }

            let discoveredConfigurations = await fetchMenu("configurations", allowReferenceFree: true)
            for discovered in discoveredConfigurations {
                indexDiscoveredConfiguration(discovered, into: &discoveredByEndpoint)
            }

            let upperLeft = await fetchMenu("upperLeftMenu")
            let upperMid = await fetchMenu("upperMidMenu")
            let upperRight = await fetchMenu("upperRightMenu")
            let lowerLeft = await fetchMenu("lowerLeftMenu")
            let lowerMid = await fetchMenu("lowerMidMenu")
            let lowerRight = await fetchMenu("lowerRightMenu")

            appendUnique(upperLeft, into: &mergedUpperLeft)
            appendUnique(upperMid, into: &mergedUpperMid)
            appendUnique(upperRight, into: &mergedUpperRight)
            appendUnique(lowerLeft, into: &mergedLowerLeft)
            appendUnique(lowerMid, into: &mergedLowerMid)
            appendUnique(lowerRight, into: &mergedLowerRight)
        }

        let curated = curatedMenuSeedConfigurations()
        let fallbackEndpoints = curatedFallbackEndpoints(from: curated)
        for endpoint in fallbackEndpoints {
            let endpointKey = endpointIdentity(endpoint)
            guard discoveredByEndpoint[endpointKey] == nil else { continue }
            if let recovered = await recoverConfigurationFromEndpoint(
                endpoint,
                resolver: resolver,
                identity: identity
            ) {
                indexDiscoveredConfiguration(recovered, into: &discoveredByEndpoint)
            }
        }

        let enrichedCurated = enrichCuratedMenuSeedConfigurations(curated, discoveredByEndpoint: discoveredByEndpoint)
        appendUnique(enrichedCurated.upperLeft, into: &mergedUpperLeft)
        appendUnique(enrichedCurated.upperMid, into: &mergedUpperMid)
        appendUnique(enrichedCurated.upperRight, into: &mergedUpperRight)
        appendUnique(enrichedCurated.lowerLeft, into: &mergedLowerLeft)
        appendUnique(enrichedCurated.lowerMid, into: &mergedLowerMid)
        appendUnique(enrichedCurated.lowerRight, into: &mergedLowerRight)

        let menuPool = buildConvenienceMenuPool(
            merged: (
                upperLeft: mergedUpperLeft,
                upperMid: mergedUpperMid,
                upperRight: mergedUpperRight,
                lowerLeft: mergedLowerLeft,
                lowerMid: mergedLowerMid,
                lowerRight: mergedLowerRight
            ),
            discoveredByEndpoint: discoveredByEndpoint,
            curated: enrichedCurated
        )

        catalogMenuPool = menuPool
        let profile = await fetchPerspectiveMenuProfile()
        lastPerspectiveMenuSignature = profile.signature
        if usesPerspectiveDrivenEdgeMenus {
            applyPerspectiveDrivenMenus(from: menuPool, fallback: enrichedCurated, profile: profile)
        } else {
            applyFixedMenuPlacement(enrichedCurated)
        }
    }

    @MainActor
    private func monitorPerspectiveDrivenMenus() async {
        guard usesPerspectiveDrivenEdgeMenus else { return }
        while !Task.isCancelled {
            let profile = await fetchPerspectiveMenuProfile()
            if profile.signature != lastPerspectiveMenuSignature {
                lastPerspectiveMenuSignature = profile.signature
                let fallback = curatedMenuSeedConfigurations()
                applyPerspectiveDrivenMenus(from: catalogMenuPool, fallback: fallback, profile: profile)
            }

            do {
                try await Task.sleep(nanoseconds: 12_000_000_000)
            } catch {
                return
            }
        }
    }

    private func configuredCatalogSources() -> [CatalogSource] {
        let raw = ProcessInfo.processInfo.environment["BINDING_REMOTE_CATALOG_ENDPOINTS"] ?? ""
        let separators = CharacterSet(charactersIn: ",;\n")
        let remoteEndpoints = raw
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var sources: [CatalogSource] = []
        var seen: Set<String> = []
        let localEndpoint = "cell:///ConfigurationCatalog"
        sources.append(CatalogSource(endpoint: localEndpoint, allowSync: true))
        seen.insert(localEndpoint.lowercased())

        for endpoint in remoteEndpoints + ["cell://\(Self.stagingHost)/ConfigurationCatalog"] {
            let key = endpoint.lowercased()
            guard seen.insert(key).inserted else { continue }
            sources.append(CatalogSource(endpoint: endpoint, allowSync: false))
        }
        return sources
    }

    private func catalogOrigin(from endpoint: String) -> CatalogOrigin? {
        guard let components = URLComponents(string: endpoint),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              !host.isEmpty
        else {
            return nil
        }

        switch scheme {
        case "cell":
            guard host.lowercased() != "localhost" else { return nil }
            let route = remoteRoute(forHost: host)
            return CatalogOrigin(
                host: host,
                port: components.port,
                route: route,
                websocketScheme: CellBase.allowsInsecureWebSockets ? "ws" : "wss",
                useDirectWebSocketForLocalReferences: false
            )
        case "ws", "wss":
            let routePath = inferredWebsocketRoutePath(fromCatalogEndpointPath: components.path)
            let schemePreference: RemoteCellHostRoute.SchemePreference = scheme == "ws" ? .ws : .wss
            let route = RemoteCellHostRoute(websocketEndpoint: routePath, schemePreference: schemePreference)
            return CatalogOrigin(
                host: host,
                port: components.port,
                route: route,
                websocketScheme: scheme,
                useDirectWebSocketForLocalReferences: host.lowercased() == "localhost"
            )
        default:
            return nil
        }
    }

    private func registerRemoteCatalogHostIfNeeded(_ origin: CatalogOrigin, resolver: CellResolver) {
        registerRemoteHostIfNeeded(origin.host, route: origin.route, resolver: resolver)
    }

    private func registerRemoteHostIfNeeded(_ host: String, route: RemoteCellHostRoute, resolver: CellResolver) {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedHost.isEmpty, normalizedHost != "localhost" else { return }
        let snapshot = resolver.remoteCellHostRoutesSnapshot()
        if let existing = snapshot[normalizedHost], routesMatch(existing, route) {
            return
        }
        resolver.registerRemoteCellHost(host, route: route)
    }

    private func inferredWebsocketRoutePath(fromCatalogEndpointPath path: String) -> String {
        let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !normalizedPath.isEmpty else { return Self.defaultRemoteWebSocketPath }

        let components = normalizedPath.split(separator: "/").map(String.init)
        guard components.count > 1 else { return "" }
        return components.dropLast().joined(separator: "/")
    }

    private func normalizeCatalogMenu(
        _ configs: [CellConfiguration],
        origin: CatalogOrigin?,
        resolver: CellResolver,
        allowReferenceFree: Bool = false
    ) -> [CellConfiguration] {
        configs.compactMap { config in
            let normalized = normalizeConfigurationForResolver(config, origin: origin, resolver: resolver)
            return sanitizedLoadedConfiguration(normalized, allowReferenceFree: allowReferenceFree)
        }
    }

    private func normalizeConfigurationForResolver(_ configuration: CellConfiguration, origin: CatalogOrigin?, resolver: CellResolver) -> CellConfiguration {
        var normalized = configuration
        if let references = configuration.cellReferences {
            normalized.cellReferences = references.map { normalizeReferenceForResolver($0, origin: origin, resolver: resolver) }
        }
        normalized = ensureCatalogReferenceBindingIfNeeded(normalized, origin: origin, resolver: resolver)
        return canonicalizeSkeletonReferencesIfNeeded(in: normalized)
    }

    private func ensureCatalogReferenceBindingIfNeeded(
        _ configuration: CellConfiguration,
        origin: CatalogOrigin?,
        resolver: CellResolver
    ) -> CellConfiguration {
        guard skeletonUsesCatalogNamespace(configuration.skeleton) else { return configuration }

        var normalized = configuration
        var references = normalized.cellReferences ?? []

        if let index = references.firstIndex(where: referenceTargetsConfigurationCatalog) {
            var reference = references[index]
            reference.label = "catalog"
            references[index] = normalizeReferenceForResolver(reference, origin: origin, resolver: resolver)
        } else {
            // Keep catalog-binding local to avoid remote bridge dependency for catalog.* keypaths.
            var catalogReference = CellReference(endpoint: "cell:///ConfigurationCatalog", label: "catalog")
            catalogReference.subscribeFeed = false
            references.append(catalogReference)
        }

        normalized.cellReferences = references
        return normalized
    }

    private func canonicalizeSkeletonReferencesIfNeeded(in configuration: CellConfiguration) -> CellConfiguration {
        guard let skeleton = configuration.skeleton,
              let references = configuration.cellReferences,
              !references.isEmpty
        else {
            return configuration
        }

        let labelsByEndpoint = referenceLabelsByEndpointIdentity(from: references)
        guard !labelsByEndpoint.isEmpty,
              let rewrittenSkeleton = canonicalizedSkeleton(skeleton, labelsByEndpoint: labelsByEndpoint)
        else {
            return configuration
        }

        var rewritten = configuration
        rewritten.skeleton = rewrittenSkeleton
        return rewritten
    }

    private func referenceLabelsByEndpointIdentity(from references: [CellReference]) -> [String: String] {
        var labelsByEndpoint: [String: String] = [:]
        for reference in references {
            collectReferenceLabels(from: reference, into: &labelsByEndpoint)
        }
        return labelsByEndpoint
    }

    private func collectReferenceLabels(from reference: CellReference, into labelsByEndpoint: inout [String: String]) {
        let trimmedLabel = reference.label.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLabel.isEmpty {
            labelsByEndpoint[endpointIdentity(reference.endpoint)] = trimmedLabel
        }

        for subscription in reference.subscriptions {
            collectReferenceLabels(from: subscription, into: &labelsByEndpoint)
        }
    }

    private func canonicalizedSkeleton(
        _ skeleton: SkeletonElement,
        labelsByEndpoint: [String: String]
    ) -> SkeletonElement? {
        guard let data = try? JSONEncoder().encode(skeleton),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let rewrittenObject = canonicalizedSkeletonJSONValue(jsonObject, labelsByEndpoint: labelsByEndpoint),
              JSONSerialization.isValidJSONObject(rewrittenObject),
              let rewrittenData = try? JSONSerialization.data(withJSONObject: rewrittenObject),
              let rewrittenSkeleton = try? JSONDecoder().decode(SkeletonElement.self, from: rewrittenData)
        else {
            return nil
        }
        return rewrittenSkeleton
    }

    private func canonicalizedSkeletonJSONValue(
        _ value: Any,
        labelsByEndpoint: [String: String]
    ) -> Any? {
        switch value {
        case let dictionary as [String: Any]:
            var rewritten: [String: Any] = [:]
            rewritten.reserveCapacity(dictionary.count)
            for (key, childValue) in dictionary {
                rewritten[key] = canonicalizedSkeletonJSONValue(childValue, labelsByEndpoint: labelsByEndpoint) ?? childValue
            }
            return canonicalizedSkeletonDictionary(rewritten, labelsByEndpoint: labelsByEndpoint)
        case let array as [Any]:
            return array.map { canonicalizedSkeletonJSONValue($0, labelsByEndpoint: labelsByEndpoint) ?? $0 }
        default:
            return value
        }
    }

    private func canonicalizedSkeletonDictionary(
        _ dictionary: [String: Any],
        labelsByEndpoint: [String: String]
    ) -> [String: Any] {
        var rewritten = dictionary

        if let urlValue = rewritten["url"] as? String {
            let trimmedURL = urlValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let baseKeypath = relativeKeypath(forEndpointLikeValue: trimmedURL, labelsByEndpoint: labelsByEndpoint) {
                if let currentKeypath = rewritten["keypath"] as? String {
                    rewritten["keypath"] = mergedRelativeKeypath(baseKeypath, with: canonicalizedRelativeKeypath(currentKeypath, labelsByEndpoint: labelsByEndpoint))
                    rewritten.removeValue(forKey: "url")
                } else {
                    rewritten["url"] = portholeURLString(for: baseKeypath)
                }
            } else if isPortholeRootURL(trimmedURL), let currentKeypath = rewritten["keypath"] as? String {
                rewritten["keypath"] = canonicalizedRelativeKeypath(currentKeypath, labelsByEndpoint: labelsByEndpoint)
                rewritten.removeValue(forKey: "url")
            }
        }

        for key in ["keypath", "sourceKeypath", "targetKeypath"] {
            guard let currentValue = rewritten[key] as? String else { continue }
            rewritten[key] = canonicalizedRelativeKeypath(currentValue, labelsByEndpoint: labelsByEndpoint)
        }

        return rewritten
    }

    private func canonicalizedRelativeKeypath(
        _ keypath: String,
        labelsByEndpoint: [String: String]
    ) -> String {
        let trimmedKeypath = keypath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeypath.isEmpty else { return keypath }

        if let relative = relativeKeypath(forEndpointLikeValue: trimmedKeypath, labelsByEndpoint: labelsByEndpoint) {
            return relative
        }

        return trimmedKeypath
    }

    private func relativeKeypath(
        forEndpointLikeValue value: String,
        labelsByEndpoint: [String: String]
    ) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }

        if let portholeRelative = relativeKeypathFromPortholeURL(trimmedValue) {
            return portholeRelative
        }

        guard let components = URLComponents(string: trimmedValue),
              components.scheme?.lowercased() == "cell"
        else {
            return nil
        }

        let pathComponents = components.path
            .split(separator: "/")
            .map(String.init)
        guard !pathComponents.isEmpty else { return nil }

        for prefixCount in stride(from: pathComponents.count, through: 1, by: -1) {
            let endpoint = cellEndpointString(
                host: components.host,
                port: components.port,
                pathComponents: Array(pathComponents.prefix(prefixCount))
            )
            guard let label = labelsByEndpoint[endpointIdentity(endpoint)] else { continue }
            let remainder = Array(pathComponents.dropFirst(prefixCount))
            return mergedRelativeKeypath(label, with: remainder.joined(separator: "."))
        }

        return nil
    }

    private func relativeKeypathFromPortholeURL(_ value: String) -> String? {
        guard let components = URLComponents(string: value),
              components.scheme?.lowercased() == "cell"
        else {
            return nil
        }

        let pathComponents = components.path
            .split(separator: "/")
            .map(String.init)
        guard let firstComponent = pathComponents.first?.lowercased(),
              firstComponent == "porthole"
        else {
            return nil
        }

        let remainder = Array(pathComponents.dropFirst()).joined(separator: ".")
        guard !remainder.isEmpty else { return nil }
        return remainder
    }

    private func mergedRelativeKeypath(_ baseKeypath: String, with suffix: String) -> String {
        let trimmedBase = baseKeypath.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSuffix = suffix.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedBase.isEmpty else { return trimmedSuffix }
        guard !trimmedSuffix.isEmpty else { return trimmedBase }
        if trimmedSuffix == trimmedBase || trimmedSuffix.hasPrefix("\(trimmedBase).") {
            return trimmedSuffix
        }
        return "\(trimmedBase).\(trimmedSuffix)"
    }

    private func portholeURLString(for relativeKeypath: String) -> String {
        "\(Self.portholeEndpoint)/\(relativeKeypath)"
    }

    private func isPortholeRootURL(_ value: String) -> Bool {
        endpointIdentity(value) == endpointIdentity(Self.portholeEndpoint)
    }

    private func cellEndpointString(host: String?, port: Int?, pathComponents: [String]) -> String {
        let path = pathComponents.joined(separator: "/")
        guard let host, !host.isEmpty else {
            return "cell:///\(path)"
        }

        if let port {
            return "cell://\(host):\(port)/\(path)"
        }
        return "cell://\(host)/\(path)"
    }

    private func skeletonUsesCatalogNamespace(_ skeleton: SkeletonElement?) -> Bool {
        guard let skeleton,
              let data = try? JSONEncoder().encode(skeleton),
              let raw = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        else {
            return false
        }
        return raw.contains("\"catalog.")
    }

    private func referenceTargetsConfigurationCatalog(_ reference: CellReference) -> Bool {
        guard let components = URLComponents(string: reference.endpoint) else { return false }
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        guard !path.isEmpty else { return false }
        return path.split(separator: "/").contains { $0 == "configurationcatalog" }
    }

    private func normalizeReferenceForResolver(_ reference: CellReference, origin: CatalogOrigin?, resolver: CellResolver) -> CellReference {
        var normalized = reference
        normalized.endpoint = normalizeEndpointForResolver(reference.endpoint, origin: origin, resolver: resolver)
        normalized.subscriptions = reference.subscriptions.map { normalizeReferenceForResolver($0, origin: origin, resolver: resolver) }
        normalized.setKeysAndValues = reference.setKeysAndValues.map { kv in
            var current = kv
            if let target = current.target {
                current.target = normalizeEndpointForResolver(target, origin: origin, resolver: resolver)
            }
            return current
        }
        return normalized
    }

    private func normalizeEndpointForResolver(_ endpoint: String, origin: CatalogOrigin?, resolver: CellResolver) -> String {
        guard var components = URLComponents(string: endpoint),
              let scheme = components.scheme?.lowercased()
        else {
            return endpoint
        }
        if scheme == "ws" || scheme == "wss" {
            return endpoint
        }
        guard scheme == "cell" else {
            return endpoint
        }

        let normalizedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !normalizedPath.isEmpty else { return endpoint }

        let currentHost = components.host?.trimmingCharacters(in: .whitespacesAndNewlines)
        let isLocal = currentHost == nil || currentHost?.isEmpty == true || currentHost?.lowercased() == "localhost"

        if isLocal {
            guard let origin else { return endpoint }

            if origin.useDirectWebSocketForLocalReferences {
                return makeWebSocketEndpoint(forCellPath: normalizedPath, origin: origin) ?? endpoint
            }

            registerRemoteCatalogHostIfNeeded(origin, resolver: resolver)

            var rewritten = URLComponents()
            rewritten.scheme = "cell"
            rewritten.host = origin.host
            rewritten.port = origin.port
            rewritten.path = "/" + normalizedPath
            return rewritten.string ?? endpoint
        }

        if let host = currentHost {
            let fallbackRoute = origin?.route ?? remoteRoute(forHost: host)
            registerRemoteHostIfNeeded(host, route: fallbackRoute, resolver: resolver)
        }

        components.path = "/" + normalizedPath
        return components.string ?? endpoint
    }

    private func makeWebSocketEndpoint(forCellPath cellPath: String, origin: CatalogOrigin) -> String? {
        var components = URLComponents()
        components.scheme = origin.websocketScheme
        components.host = origin.host
        components.port = origin.port

        let routePath = origin.route.websocketEndpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if routePath.isEmpty {
            components.path = "/\(cellPath)"
        } else {
            components.path = "/\(routePath)/\(cellPath)"
        }
        return components.string
    }

    private var renderedSkeleton: SkeletonElement {
        if editorMode == .edit, let workingCopy = editorState.workingCopy {
            return workingCopy
        }
        return viewModel.currentSkeleton
    }

    private var usesCompactEditorChrome: Bool {
#if os(iOS)
        horizontalSizeClass == .compact
#else
        false
#endif
    }

    private var usesCompactConvenienceMenus: Bool {
        usesCompactEditorChrome
    }

    private var appToolbar: some View {
        Group {
            if usesCompactEditorChrome {
                compactAppToolbar
            } else {
                regularAppToolbar
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var regularAppToolbar: some View {
        HStack(spacing: 10) {
            Button {
                presentingFullLibrary = true
            } label: {
                Label("Library", systemImage: "books.vertical")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                copyLoadedConfigurationJSONToClipboard()
            } label: {
                Label("Copy JSON", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(activeConfiguration == nil && editorState.workingCopy == nil)

            Picker("Mode", selection: $editorMode) {
                ForEach(EditorMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            Spacer(minLength: 8)

            if editorMode == .edit {
                HStack(spacing: 8) {
                    Button("Undo") { editorState.undo() }
                        .disabled(!editorState.canUndo)
                    Button("Redo") { editorState.redo() }
                        .disabled(!editorState.canRedo)
                }
                .font(.caption)

                HStack(spacing: 8) {
                    Button("Discard") {
                        editorState.discardChanges()
                    }
                    Button("Apply") {
                        applyWorkingCopyToViewer()
                    }
                    .disabled(editorState.workingCopy == nil)
                }
                .font(.caption)
            }
        }
    }

    private var compactAppToolbar: some View {
        HStack(spacing: 8) {
            Button {
                presentingFullLibrary = true
            } label: {
                Image(systemName: "books.vertical")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityLabel("Library")

            Button {
                copyLoadedConfigurationJSONToClipboard()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(activeConfiguration == nil && editorState.workingCopy == nil)
            .accessibilityLabel("Copy JSON")

            Picker("Mode", selection: $editorMode) {
                ForEach(EditorMode.allCases) { mode in
                    Image(systemName: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if editorMode == .edit {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        compactEditorDrawerVisible.toggle()
                    }
                } label: {
                    Image(systemName: compactEditorDrawerVisible ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel(compactEditorDrawerVisible ? "Skjul editorpaneler" : "Vis editorpaneler")

                Menu {
                    Button("Undo") { editorState.undo() }
                        .disabled(!editorState.canUndo)
                    Button("Redo") { editorState.redo() }
                        .disabled(!editorState.canRedo)
                    Divider()
                    Button("Discard") {
                        editorState.discardChanges()
                    }
                    Button("Apply") {
                        applyWorkingCopyToViewer()
                    }
                    .disabled(editorState.workingCopy == nil)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Editor actions")
            }
        }
    }

    private var compactConvenienceTray: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("Snarveier", systemImage: "square.grid.2x2")
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 0)
                Text("\(compactConvenienceConfigurations.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(compactConvenienceConfigurations, id: \.name) { configuration in
                        Button {
                            Task { await loadConfigurationForEditing(configuration) }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: configuration.skeletonIconName)
                                    .font(.headline)
                                    .foregroundStyle(Color.accentColor)
                                Text(configuration.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                if let summary = configuration.description, !summary.isEmpty {
                                    Text(summary)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .frame(width: 132, alignment: .leading)
                            .padding(10)
                            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var compactConvenienceConfigurations: [CellConfiguration] {
        let orderedGroups = [
            viewModel.upperLeftMenu,
            viewModel.upperMidMenu,
            viewModel.upperRightMenu,
            viewModel.lowerLeftMenu,
            viewModel.lowerMidMenu,
            viewModel.lowerRightMenu
        ]

        var result: [CellConfiguration] = []
        var seen: Set<String> = []

        for group in orderedGroups {
            for configuration in group {
                let key = menuIdentityKey(for: configuration)
                guard seen.insert(key).inserted else { continue }
                result.append(configuration)
                if result.count == 12 {
                    return result
                }
            }
        }

        return result
    }

    private var componentPaletteItems: [ComponentPaletteItem] {
        ComponentPaletteCatalog.defaultItems()
    }

    private var activeComponentInsertionItem: ComponentPaletteItem? {
        activeComponentDragItem ?? armedComponentItem
    }

    private var isComponentPlacementArmed: Bool {
        activeComponentDragItem == nil && armedComponentItem != nil
    }

    private var activeComponentDropTargets: [DropTargetDescriptor] {
        guard editorMode == .edit, let activeComponentInsertionItem else { return [] }
        return editorState.dropTargets(for: activeComponentInsertionItem.recipe)
    }

    private var compactEditorDrawer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Editor")
                        .font(.headline)
                    Text(editorState.selectedNodePath == nil ? "Velg et element for å styre hvor komponenter legges inn." : "Komponenter, elementer og inspector ligger samlet her.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button {
                    let shouldCollapse = compactComponentsExpanded || compactElementsExpanded || compactInspectorExpanded
                    withAnimation(.easeInOut(duration: 0.2)) {
                        compactComponentsExpanded = !shouldCollapse
                        compactElementsExpanded = !shouldCollapse
                        compactInspectorExpanded = !shouldCollapse
                    }
                } label: {
                    Image(systemName: compactComponentsExpanded || compactElementsExpanded || compactInspectorExpanded ? "chevron.down" : "chevron.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Collapse editor sections")

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        compactEditorDrawerVisible = false
                    }
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityLabel("Lukk editorpaneler")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    DisclosureGroup("Components", isExpanded: $compactComponentsExpanded) {
                        ComponentPalettePanel(
                            editorState: editorState,
                            items: componentPaletteItems,
                            armedItemID: armedComponentItem?.id,
                            onDragStateChange: { item in
                                activeComponentDragItem = item
                            },
                            onArmComponent: { item in
                                armComponentPlacement(item)
                            },
                            onInsertError: { message in
                                loadErrorMessage = message
                            }
                        )
                        .padding(.top, 8)
                    }

                    DisclosureGroup("Elements", isExpanded: $compactElementsExpanded) {
                        SkeletonTreePanel(
                            editorState: editorState,
                            preferredWidth: nil,
                            maximumHeight: nil,
                            showsBackground: false
                        )
                        .padding(.top, 8)
                    }

                    DisclosureGroup("Inspector", isExpanded: $compactInspectorExpanded) {
                        SkeletonModifierInspectorPanel(
                            editorState: editorState,
                            preferredWidth: nil,
                            maximumHeight: nil,
                            modifierListMaximumHeight: nil,
                            showsBackground: false
                        )
                        .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func applyWorkingCopyToViewer() {
        guard let committedDocument = editorState.commitDocumentChanges() else { return }
        let committedConfiguration = canonicalizeSkeletonReferencesIfNeeded(in: committedDocument.configuration)
        activeConfiguration = committedConfiguration
        Task { await viewModel.load(configuration: committedConfiguration) }
    }

    @MainActor
    private func loadConfigurationForEditing(_ configuration: CellConfiguration?) async {
        guard let configuration else { return }
        guard let sanitizedConfiguration = sanitizedLoadedConfiguration(configuration, allowReferenceFree: true) else {
            loadErrorMessage = "Konfigurasjonen ble filtrert bort fordi den mangler gyldige CellReferences."
            return
        }
        loadErrorMessage = nil
        var normalizedConfiguration = retargetConfigurationToStagingIfNeeded(sanitizedConfiguration)
        if let resolver = CellBase.defaultCellResolver as? CellResolver {
            normalizedConfiguration = normalizeConfigurationForResolver(
                normalizedConfiguration,
                origin: nil,
                resolver: resolver
            )
        }
        activeConfiguration = normalizedConfiguration

        var loadConfiguration = normalizedConfiguration
        if let references = normalizedConfiguration.cellReferences, !references.isEmpty {
            let probeResult = await probeFailingTopLevelReferences(in: normalizedConfiguration)
            if !probeResult.failingReferenceEndpoints.isEmpty {
                let (retainedReferences, removedReferences) = references.reduce(into: ([CellReference](), [CellReference]())) { acc, reference in
                    if probeResult.failingReferenceEndpoints.contains(endpointIdentity(reference.endpoint)) {
                        acc.1.append(reference)
                    } else {
                        acc.0.append(reference)
                    }
                }
                let removedCount = references.count - retainedReferences.count
                if removedCount > 0 {
                    let removedLabels = removedReferences.compactMap { reference in
                        let trimmed = reference.label.trimmingCharacters(in: .whitespacesAndNewlines)
                        return trimmed.isEmpty ? nil : trimmed.lowercased()
                    }
                    if skeletonDependsOnRemovedReferenceLabels(loadConfiguration.skeleton, removedLabels: removedLabels) {
                        loadErrorMessage = "Kritisk referanse kunne ikke lastes (\(removedCount)). \(probeResult.firstFailureMessage ?? "")"
                        return
                    }
                    loadConfiguration.cellReferences = retainedReferences
                    if retainedReferences.isEmpty {
                        loadErrorMessage = "Ingen referanser kunne lastes. \(probeResult.firstFailureMessage ?? "")"
                    } else {
                        loadErrorMessage = "Noen referanser feilet og ble hoppet over (\(removedCount)). \(probeResult.firstFailureMessage ?? "")"
                    }
                }
            }
        }

        await viewModel.load(configuration: loadConfiguration)
        if editorMode == .edit {
            editorState.beginEditing(configuration: loadConfiguration, fallbackSkeleton: loadConfiguration.skeleton ?? viewModel.currentSkeleton)
        }
    }

    private func copyLoadedConfigurationJSONToClipboard() {
        guard let configuration = configurationForClipboardExport() else {
            loadErrorMessage = "Ingen CellConfiguration er lastet i Porthole."
            copyStatusMessage = nil
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(configuration)
            guard let json = String(data: data, encoding: .utf8) else {
                loadErrorMessage = "Kunne ikke lage tekst fra serialisert CellConfiguration."
                copyStatusMessage = nil
                return
            }
            guard copyTextToClipboard(json) else {
                loadErrorMessage = "Clipboard er ikke tilgjengelig i denne plattformen."
                copyStatusMessage = nil
                return
            }
            loadErrorMessage = nil
            let message = "CellConfiguration kopiert som JSON."
            copyStatusMessage = message
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if copyStatusMessage == message {
                    copyStatusMessage = nil
                }
            }
        } catch {
            loadErrorMessage = "Kunne ikke serialisere CellConfiguration: \(error)"
            copyStatusMessage = nil
        }
    }

    private func configurationForClipboardExport() -> CellConfiguration? {
        if editorMode == .edit, let workingConfiguration = editorState.workingConfiguration {
            return canonicalizeSkeletonReferencesIfNeeded(in: workingConfiguration)
        }

        if var activeConfiguration {
            if activeConfiguration.skeleton == nil {
                activeConfiguration.skeleton = viewModel.currentSkeleton
            }
            return canonicalizeSkeletonReferencesIfNeeded(in: activeConfiguration)
        }

        return nil
    }

    private func currentEditorSeedConfiguration() -> CellConfiguration {
        if let workingConfiguration = editorState.workingConfiguration {
            return workingConfiguration
        }

        if var activeConfiguration {
            if activeConfiguration.skeleton == nil {
                activeConfiguration.skeleton = viewModel.currentSkeleton
            }
            return activeConfiguration
        }

        var fallback = CellConfiguration(name: "Edited Skeleton")
        fallback.skeleton = viewModel.currentSkeleton
        return fallback
    }

    @discardableResult
    private func applyComponentPaletteItem(_ item: ComponentPaletteItem, placement: DropPlacement? = nil) -> Bool {
        let inserted: Bool
        if let placement {
            inserted = editorState.applyComponentDrop(recipe: item.recipe, placement: placement)
        } else {
            inserted = editorState.applyPreferredComponent(item.recipe)
        }
        if inserted {
            loadErrorMessage = nil
            activeComponentDragItem = nil
            armedComponentItem = nil
            compactInspectorExpanded = true
            withAnimation(.easeInOut(duration: 0.2)) {
                compactEditorDrawerVisible = true
            }
        }
        return inserted
    }

    private func armComponentPlacement(_ item: ComponentPaletteItem?) {
        activeComponentDragItem = nil
        armedComponentItem = item

        guard item != nil else { return }
        compactInspectorExpanded = true
        withAnimation(.easeInOut(duration: 0.2)) {
            compactEditorDrawerVisible = true
        }
    }

    private func copyTextToClipboard(_ text: String) -> Bool {
#if canImport(UIKit)
        UIPasteboard.general.string = text
        return true
#elseif canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
#else
        return false
#endif
    }

    private func remoteRoute(forHost host: String) -> RemoteCellHostRoute {
        if host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == Self.stagingHost {
            return Self.stagingRemoteRoute
        }
        return Self.defaultRemoteRoute
    }

    private func routesMatch(_ lhs: RemoteCellHostRoute, _ rhs: RemoteCellHostRoute) -> Bool {
        let lhsPath = lhs.websocketEndpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        let rhsPath = rhs.websocketEndpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        guard lhsPath == rhsPath else { return false }
        return schemePreferenceLabel(lhs.schemePreference) == schemePreferenceLabel(rhs.schemePreference)
    }

    private func schemePreferenceLabel(_ preference: RemoteCellHostRoute.SchemePreference) -> String {
        switch preference {
        case .automatic: return "automatic"
        case .ws: return "ws"
        case .wss: return "wss"
        }
    }

    private enum ConvenienceMenuSlot: String, CaseIterable {
        case upperLeft
        case upperMid
        case upperRight
        case lowerLeft
        case lowerMid
        case lowerRight
    }

    private struct PerspectiveMenuProfile {
        var activePurposeCount: Int
        var keywordWeights: [String: Double]

        static let empty = PerspectiveMenuProfile(activePurposeCount: 0, keywordWeights: [:])

        var signature: String {
            let sortedPairs = keywordWeights
                .sorted(by: { lhs, rhs in
                    if lhs.key == rhs.key {
                        return lhs.value < rhs.value
                    }
                    return lhs.key < rhs.key
                })
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: "|")
            return "\(activePurposeCount)::\(sortedPairs)"
        }
    }

    private func fetchPerspectiveMenuProfile() async -> PerspectiveMenuProfile {
        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let identity = await CellBase.defaultIdentityVault?.identity(for: "private", makeNewIfNotFound: true),
              let perspective = try? await resolver.cellAtEndpoint(endpoint: "cell:///Perspective", requester: identity) as? Meddle
        else {
            return .empty
        }

        let activePurposeValue = try? await perspective.get(keypath: "activePurpose", requester: identity)
        let activeInterestValue = try? await perspective.set(
            keypath: "perspective.query.interestsFromActivePurposes",
            value: .object([
                "limit": .integer(24),
                "referenceMode": .string("both")
            ]),
            requester: identity
        )

        return perspectiveMenuProfile(activePurposes: activePurposeValue, activeInterests: activeInterestValue)
    }

    private func perspectiveMenuProfile(activePurposes: ValueType?, activeInterests: ValueType?) -> PerspectiveMenuProfile {
        var keywordWeights: [String: Double] = [:]
        var activePurposeCount = 0

        if case let .object(object)? = activePurposes {
            if case let .integer(count)? = object["count"] {
                activePurposeCount = count
            }
            if case let .list(purposes)? = object["purposes"] {
                for value in purposes {
                    guard case let .object(purposeObject) = value else { continue }
                    let weight = numericValue(from: purposeObject["purposeWeight"]) ?? 1.0
                    addWeightedKeywords(from: stringValue(from: purposeObject["purposeName"]), weight: weight, into: &keywordWeights)
                    addWeightedKeywords(from: stringValue(from: purposeObject["purposeRef"]), weight: weight * 0.6, into: &keywordWeights)
                    addWeightedKeywords(from: stringValue(from: purposeObject["portablePurposeRef"]), weight: weight * 0.6, into: &keywordWeights)

                    if case let .list(interests)? = purposeObject["interests"] {
                        for interest in interests {
                            guard case let .object(interestObject) = interest else { continue }
                            let interestWeight = numericValue(from: interestObject["interestWeight"]) ?? 1.0
                            addWeightedKeywords(
                                from: stringValue(from: interestObject["interestName"]),
                                weight: weight * interestWeight,
                                into: &keywordWeights
                            )
                            addWeightedKeywords(
                                from: stringValue(from: interestObject["portableInterestRef"]),
                                weight: weight * interestWeight * 0.6,
                                into: &keywordWeights
                            )
                        }
                    }
                }
            }
        }

        if case let .object(object)? = activeInterests,
           case let .list(interests)? = object["interests"] {
            for value in interests {
                guard case let .object(interestObject) = value else { continue }
                let weight = numericValue(from: interestObject["interestWeight"]) ?? 1.0
                addWeightedKeywords(from: stringValue(from: interestObject["interestName"]), weight: weight, into: &keywordWeights)
                addWeightedKeywords(from: stringValue(from: interestObject["interestRef"]), weight: weight * 0.6, into: &keywordWeights)
                addWeightedKeywords(from: stringValue(from: interestObject["portableInterestRef"]), weight: weight * 0.6, into: &keywordWeights)
            }
        }

        return PerspectiveMenuProfile(activePurposeCount: activePurposeCount, keywordWeights: keywordWeights)
    }

    private func addWeightedKeywords(from raw: String?, weight: Double, into dictionary: inout [String: Double]) {
        guard let raw, raw.isEmpty == false, weight > 0 else { return }
        for token in semanticTokens(from: raw) {
            dictionary[token, default: 0] += weight
        }
    }

    private func semanticTokens(from raw: String) -> [String] {
        let normalized = raw
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let components = normalized.split { !$0.isLetter && !$0.isNumber }
        var tokens = components.map(String.init).filter { $0.count >= 3 }

        for token in components {
            let current = String(token)
            if current.contains("conference") || current.contains("event") {
                tokens.append("conference")
                tokens.append("event")
            }
            if current.contains("chat") || current.contains("message") || current.contains("kommun") {
                tokens.append("chat")
                tokens.append("communication")
            }
            if current.contains("scan") || current.contains("nearby") || current.contains("peer") || current.contains("meet") {
                tokens.append("scanner")
                tokens.append("nearby")
            }
            if current.contains("trust") || current.contains("issuer") || current.contains("credential") || current.contains("verify") {
                tokens.append("trust")
                tokens.append("credentials")
            }
            if current.contains("vault") || current.contains("note") || current.contains("knowledge") {
                tokens.append("vault")
                tokens.append("notes")
            }
            if current.contains("todo") || current.contains("task") || current.contains("plan") {
                tokens.append("todo")
                tokens.append("tasks")
            }
        }

        return Array(Set(tokens))
    }

    private func stringValue(from value: ValueType?) -> String? {
        guard let value else { return nil }
        switch value {
        case .string(let string):
            return string
        case .integer(let integer):
            return String(integer)
        case .float(let double):
            return String(double)
        case .number(let number):
            return String(number)
        case .bool(let bool):
            return bool ? "true" : "false"
        default:
            return nil
        }
    }

    private func numericValue(from value: ValueType?) -> Double? {
        guard let value else { return nil }
        switch value {
        case .float(let double):
            return double
        case .integer(let integer):
            return Double(integer)
        case .number(let number):
            return Double(number)
        case .string(let string):
            return Double(string)
        default:
            return nil
        }
    }

    private func buildConvenienceMenuPool(
        merged: MenuConfigurationBuckets,
        discoveredByEndpoint: [String: CellConfiguration],
        curated: MenuConfigurationBuckets
    ) -> [CellConfiguration] {
        let allConfigurations =
            merged.upperLeft + merged.upperMid + merged.upperRight +
            merged.lowerLeft + merged.lowerMid + merged.lowerRight +
            Array(discoveredByEndpoint.values) +
            curated.upperLeft + curated.upperMid + curated.upperRight +
            curated.lowerLeft + curated.lowerMid + curated.lowerRight

        var deduplicatedByName: [String: CellConfiguration] = [:]
        for configuration in allConfigurations where !isEmitterConfiguration(configuration) {
            let key = configuration.name.lowercased()
            if let existing = deduplicatedByName[key] {
                deduplicatedByName[key] = shouldPreferDiscoveredConfiguration(configuration, over: existing) ? configuration : existing
            } else {
                deduplicatedByName[key] = configuration
            }
        }
        return Array(deduplicatedByName.values)
    }

    @MainActor
    private func applyPerspectiveDrivenMenus(
        from pool: [CellConfiguration],
        fallback: MenuConfigurationBuckets,
        profile: PerspectiveMenuProfile
    ) {
        let slots = ConvenienceMenuSlot.allCases
        var selectedNames = Set<String>()
        var selections: [ConvenienceMenuSlot: [CellConfiguration]] = [:]

        for slot in slots {
            let picked = selectConvenienceConfigurations(
                for: slot,
                from: pool,
                fallback: fallbackConfigurations(for: slot, in: fallback),
                selectedNames: selectedNames,
                profile: profile
            )
            if !picked.isEmpty {
                selections[slot] = picked
                picked.forEach { selectedNames.insert($0.name.lowercased()) }
            }
        }

        viewModel.upperLeftMenu = selections[.upperLeft] ?? fallback.upperLeft
        viewModel.upperMidMenu = selections[.upperMid] ?? fallback.upperMid
        viewModel.upperRightMenu = selections[.upperRight] ?? fallback.upperRight
        viewModel.lowerLeftMenu = selections[.lowerLeft] ?? fallback.lowerLeft
        viewModel.lowerMidMenu = selections[.lowerMid] ?? fallback.lowerMid
        viewModel.lowerRightMenu = selections[.lowerRight] ?? fallback.lowerRight
    }

    private func selectConvenienceConfigurations(
        for slot: ConvenienceMenuSlot,
        from pool: [CellConfiguration],
        fallback: [CellConfiguration],
        selectedNames: Set<String>,
        profile: PerspectiveMenuProfile
    ) -> [CellConfiguration] {
        let limit = convenienceMenuLimit(for: slot)
        let candidateNames = Set(convenienceCandidateNames(for: slot))
        let preferred = pool.filter { configuration in
            let name = configuration.name.lowercased()
            guard candidateNames.contains(name) else { return false }
            return !selectedNames.contains(name)
        }
        .sorted { lhs, rhs in
            convenienceMenuScore(for: lhs, slot: slot, profile: profile) > convenienceMenuScore(for: rhs, slot: slot, profile: profile)
        }

        var selections: [CellConfiguration] = []
        appendConvenienceSelections(preferred, into: &selections, limit: limit, excluding: selectedNames)

        if selections.count < limit {
            let semanticFallback = pool
                .filter { configuration in
                    let name = configuration.name.lowercased()
                    return !selectedNames.contains(name) && !selections.contains(where: { $0.name.lowercased() == name })
                }
                .sorted { lhs, rhs in
                    convenienceMenuScore(for: lhs, slot: slot, profile: profile) > convenienceMenuScore(for: rhs, slot: slot, profile: profile)
                }
            appendConvenienceSelections(semanticFallback, into: &selections, limit: limit, excluding: selectedNames)
        }

        if selections.count < limit {
            appendConvenienceSelections(fallback, into: &selections, limit: limit, excluding: selectedNames)
        }

        return selections
    }

    private func appendConvenienceSelections(
        _ candidates: [CellConfiguration],
        into selections: inout [CellConfiguration],
        limit: Int,
        excluding selectedNames: Set<String>
    ) {
        for candidate in candidates {
            guard selections.count < limit else { return }
            let loweredName = candidate.name.lowercased()
            guard !selectedNames.contains(loweredName) else { continue }
            guard !selections.contains(where: { $0.name.lowercased() == loweredName }) else { continue }
            selections.append(candidate)
        }
    }

    private func convenienceMenuLimit(for slot: ConvenienceMenuSlot) -> Int {
        switch slot {
        case .upperMid:
            return 4
        default:
            return 3
        }
    }

    private func convenienceMenuScore(
        for configuration: CellConfiguration,
        slot: ConvenienceMenuSlot,
        profile: PerspectiveMenuProfile
    ) -> Double {
        let orderedNames = convenienceCandidateNames(for: slot)
        let loweredName = configuration.name.lowercased()
        let base = Double(max(0, 180 - ((orderedNames.firstIndex(of: loweredName) ?? orderedNames.count) * 24)))
        let semanticTokens = configurationSemanticTokens(configuration)
        let domainTokens = Set(convenienceDomainKeywords(for: slot))

        var score = base
        score += Double(domainTokens.intersection(semanticTokens).count) * 10.0

        for token in semanticTokens {
            score += profile.keywordWeights[token, default: 0] * 18.0
        }

        if slot == .upperMid, loweredName == "apple intelligence purpose matcher" {
            score += 1_000
        }
        if profile.activePurposeCount == 0 {
            if loweredName == "perspective context" {
                score += 220
            }
            if loweredName == "apple intelligence purpose matcher" {
                score += 80
            }
        }
        if loweredName == "entity scanner" {
            score += profile.keywordWeights["conference", default: 0] * 10.0
            score += profile.keywordWeights["identity", default: 0] * 8.0
        }
        if loweredName == "trusted issuers registry" {
            score += profile.keywordWeights["trust", default: 0] * 18.0
            score += profile.keywordWeights["credentials", default: 0] * 18.0
        }
        if loweredName == "vault control surface" || loweredName == "obsidian vault" {
            score += profile.keywordWeights["vault", default: 0] * 16.0
            score += profile.keywordWeights["notes", default: 0] * 16.0
        }

        return score
    }

    private func convenienceCandidateNames(for slot: ConvenienceMenuSlot) -> [String] {
        switch slot {
        case .upperLeft:
            return ["scaffold chat", "conference mvp", "todo mvp", "notification outbox"]
        case .upperMid:
            return ["apple intelligence purpose matcher", "catalog workbench", "perspective context", "porthole control surface"]
        case .upperRight:
            return ["conference mvp", "obsidian vault", "vault control surface", "porthole control surface", "lead vault"]
        case .lowerLeft:
            return ["entity scanner", "perspective context", "entity anchor records", "trusted issuers registry", "entity scanner test helper", "entity scanner pairing checklist"]
        case .lowerMid:
            return ["todo mvp", "catalog workbench", "folder watch automation", "graph index control", "perspective context", "device registration"]
        case .lowerRight:
            return ["obsidian vault", "vault control surface", "graph index control", "porthole control surface", "trusted issuers registry", "consent receipt"]
        }
    }

    private func convenienceDomainKeywords(for slot: ConvenienceMenuSlot) -> [String] {
        switch slot {
        case .upperLeft:
            return ["chat", "communication", "collaboration", "conference"]
        case .upperMid:
            return ["assistant", "purpose", "matching", "tools"]
        case .upperRight:
            return ["conference", "event", "lead", "consent"]
        case .lowerLeft:
            return ["scanner", "identity", "trust", "credentials", "proofs", "nearby"]
        case .lowerMid:
            return ["todo", "tasks", "planning", "productivity", "context"]
        case .lowerRight:
            return ["vault", "notes", "knowledge", "records", "consent"]
        }
    }

    private func configurationSemanticTokens(_ configuration: CellConfiguration) -> Set<String> {
        var tokens = semanticTokens(from: configuration.name)
        if let description = configuration.description {
            tokens.append(contentsOf: semanticTokens(from: description))
        }
        if let discovery = configuration.discovery {
            if let purpose = discovery.purpose {
                tokens.append(contentsOf: semanticTokens(from: purpose))
            }
            if let purposeDescription = discovery.purposeDescription {
                tokens.append(contentsOf: semanticTokens(from: purposeDescription))
            }
            for interest in discovery.interests {
                tokens.append(contentsOf: semanticTokens(from: interest))
            }
            if let endpoint = discovery.sourceCellEndpoint {
                tokens.append(contentsOf: semanticTokens(from: endpoint))
            }
            if let sourceCellName = discovery.sourceCellName {
                tokens.append(contentsOf: semanticTokens(from: sourceCellName))
            }
        }
        return Set(tokens)
    }

    private func fallbackConfigurations(for slot: ConvenienceMenuSlot, in fallback: MenuConfigurationBuckets) -> [CellConfiguration] {
        switch slot {
        case .upperLeft:
            return fallback.upperLeft
        case .upperMid:
            return fallback.upperMid
        case .upperRight:
            return fallback.upperRight
        case .lowerLeft:
            return fallback.lowerLeft
        case .lowerMid:
            return fallback.lowerMid
        case .lowerRight:
            return fallback.lowerRight
        }
    }

    private struct ReferenceProbeResult {
        var failingReferenceEndpoints: Set<String>
        var firstFailureMessage: String?
    }

    private func probeFailingTopLevelReferences(in configuration: CellConfiguration) async -> ReferenceProbeResult {
        guard let references = configuration.cellReferences, !references.isEmpty else {
            return ReferenceProbeResult(failingReferenceEndpoints: [], firstFailureMessage: nil)
        }
        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            return ReferenceProbeResult(
                failingReferenceEndpoints: Set(references.map { endpointIdentity($0.endpoint) }),
                firstFailureMessage: "CellResolver mangler. Kunne ikke laste konfigurasjonen."
            )
        }
        guard let identity = await CellBase.defaultIdentityVault?.identity(for: "private", makeNewIfNotFound: true) else {
            return ReferenceProbeResult(
                failingReferenceEndpoints: Set(references.map { endpointIdentity($0.endpoint) }),
                firstFailureMessage: "Identity 'private' mangler. Kunne ikke laste konfigurasjonen."
            )
        }

        var failures = Set<String>()
        var firstMessage: String?
        for reference in references {
            if let failure = await probeReferenceTree(
                reference,
                resolver: resolver,
                identity: identity,
                probeDirectEndpoint: false
            ) {
                failures.insert(endpointIdentity(reference.endpoint))
                if firstMessage == nil {
                    firstMessage = failure
                }
            }
        }
        return ReferenceProbeResult(failingReferenceEndpoints: failures, firstFailureMessage: firstMessage)
    }

    private func probeReferenceTree(
        _ reference: CellReference,
        resolver: CellResolver,
        identity: Identity,
        probeDirectEndpoint: Bool
    ) async -> String? {
        if probeDirectEndpoint, shouldProbeEndpoint(reference.endpoint) {
            ensureRemoteHostRouteRegistered(for: reference.endpoint, resolver: resolver)
            do {
                _ = try await resolver.cellAtEndpoint(endpoint: reference.endpoint, requester: identity)
            } catch {
                if await tryProbeEndpointWithFallbackRoutes(reference.endpoint, resolver: resolver, identity: identity) {
                    // A fallback route worked; keep this reference.
                } else {
                    return probeFailureMessage(endpoint: reference.endpoint, error: error)
                }
            }
        }

        for subscription in reference.subscriptions {
            if let failure = await probeReferenceTree(
                subscription,
                resolver: resolver,
                identity: identity,
                probeDirectEndpoint: true
            ) {
                return failure
            }
        }

        for keyValue in reference.setKeysAndValues {
            guard let target = keyValue.target, shouldProbeEndpoint(target) else { continue }
            ensureRemoteHostRouteRegistered(for: target, resolver: resolver)
            do {
                _ = try await resolver.cellAtEndpoint(endpoint: target, requester: identity)
            } catch {
                if await tryProbeEndpointWithFallbackRoutes(target, resolver: resolver, identity: identity) {
                    continue
                }
                return probeFailureMessage(endpoint: target, error: error)
            }
        }

        return nil
    }

    private func tryProbeEndpointWithFallbackRoutes(_ endpoint: String, resolver: CellResolver, identity: Identity) async -> Bool {
        guard let components = URLComponents(string: endpoint),
              components.scheme?.lowercased() == "cell",
              let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              host == Self.stagingHost
        else {
            return false
        }

        let fallbackCandidates: [RemoteCellHostRoute] = [
            RemoteCellHostRoute(websocketEndpoint: Self.stagingRemoteWebSocketPath, schemePreference: .wss),
            RemoteCellHostRoute(websocketEndpoint: Self.defaultRemoteWebSocketPath, schemePreference: .wss)
        ]

        for route in fallbackCandidates {
            registerRemoteHostIfNeeded(host, route: route, resolver: resolver)
            do {
                _ = try await resolver.cellAtEndpoint(endpoint: endpoint, requester: identity)
                return true
            } catch {
                continue
            }
        }
        return false
    }

    private func endpointIdentity(_ endpoint: String) -> String {
        endpoint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func shouldProbeEndpoint(_ endpoint: String) -> Bool {
        guard let components = URLComponents(string: endpoint),
              let scheme = components.scheme?.lowercased()
        else {
            return false
        }
        let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isStagingHost = host == Self.stagingHost

        switch scheme {
        case "ws", "wss":
            return isStagingHost
        case "cell":
            return isStagingHost
        default:
            return false
        }
    }

    private func ensureRemoteHostRouteRegistered(for endpoint: String, resolver: CellResolver) {
        guard let components = URLComponents(string: endpoint),
              components.scheme?.lowercased() == "cell",
              let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              !host.isEmpty
        else {
            return
        }
        registerRemoteHostIfNeeded(host, route: remoteRoute(forHost: host), resolver: resolver)
    }

    private func probeFailureMessage(endpoint: String, error: Error) -> String {
        let errorText = String(describing: error)
        if errorText.lowercased().contains("timeout") {
            return "Timeout ved lasting av \(endpoint). Sjekk staging websocket-route (bridgehead/publishersws)."
        }
        return "Kunne ikke laste \(endpoint): \(errorText)"
    }

    private func skeletonDependsOnRemovedReferenceLabels(_ skeleton: SkeletonElement?, removedLabels: [String]) -> Bool {
        guard let skeleton,
              !removedLabels.isEmpty,
              let data = try? JSONEncoder().encode(skeleton),
              let raw = String(data: data, encoding: .utf8)?.lowercased()
        else {
            return false
        }

        for label in removedLabels where !label.isEmpty {
            if raw.contains("\(label).") {
                return true
            }
        }
        return false
    }

    private var selectedNodeKindForLibrary: String? {
        guard editorMode == .edit,
              let workingCopy = editorState.workingCopy,
              let selectedPath = editorState.selectedNodePath,
              let element = SkeletonTreeQueries.element(in: workingCopy, at: selectedPath)
        else {
            return nil
        }
        return SkeletonTreeQueries.displayName(for: element).lowercased()
    }

    private func indexDiscoveredConfiguration(_ configuration: CellConfiguration, into index: inout [String: CellConfiguration]) {
        let endpointIdentities = allReferenceEndpointIdentities(in: configuration)
        guard !endpointIdentities.isEmpty else { return }

        for endpoint in endpointIdentities {
            if let existing = index[endpoint] {
                if shouldPreferDiscoveredConfiguration(configuration, over: existing) {
                    index[endpoint] = configuration
                }
            } else {
                index[endpoint] = configuration
            }
        }
    }

    private func curatedFallbackEndpoints(from curated: MenuConfigurationBuckets) -> Set<String> {
        let allConfigurations = curated.upperLeft + curated.upperMid + curated.upperRight + curated.lowerLeft + curated.lowerMid + curated.lowerRight
        var endpoints: Set<String> = []
        for configuration in allConfigurations {
            guard let references = configuration.cellReferences else { continue }
            for reference in references {
                let endpoint = reference.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
                if !endpoint.isEmpty {
                    endpoints.insert(endpoint)
                }
            }
        }
        return endpoints
    }

    private func enrichCuratedMenuSeedConfigurations(
        _ curated: MenuConfigurationBuckets,
        discoveredByEndpoint: [String: CellConfiguration]
    ) -> MenuConfigurationBuckets {
        (
            upperLeft: curated.upperLeft.map { enrichCuratedConfiguration($0, discoveredByEndpoint: discoveredByEndpoint) },
            upperMid: curated.upperMid.map { enrichCuratedConfiguration($0, discoveredByEndpoint: discoveredByEndpoint) },
            upperRight: curated.upperRight.map { enrichCuratedConfiguration($0, discoveredByEndpoint: discoveredByEndpoint) },
            lowerLeft: curated.lowerLeft.map { enrichCuratedConfiguration($0, discoveredByEndpoint: discoveredByEndpoint) },
            lowerMid: curated.lowerMid.map { enrichCuratedConfiguration($0, discoveredByEndpoint: discoveredByEndpoint) },
            lowerRight: curated.lowerRight.map { enrichCuratedConfiguration($0, discoveredByEndpoint: discoveredByEndpoint) }
        )
    }

    private func enrichCuratedConfiguration(
        _ configuration: CellConfiguration,
        discoveredByEndpoint: [String: CellConfiguration]
    ) -> CellConfiguration {
        let endpointIdentities = allReferenceEndpointIdentities(in: configuration)
        guard !endpointIdentities.isEmpty else { return configuration }

        let candidates = endpointIdentities.compactMap { discoveredByEndpoint[$0] }
        guard let first = candidates.first else { return configuration }
        let bestCandidate = candidates.dropFirst().reduce(first) { currentBest, candidate in
            shouldPreferDiscoveredConfiguration(candidate, over: currentBest) ? candidate : currentBest
        }
        return shouldPreferDiscoveredConfiguration(bestCandidate, over: configuration) ? bestCandidate : configuration
    }

    private func recoverConfigurationFromEndpoint(
        _ endpoint: String,
        resolver: CellResolver,
        identity: Identity
    ) async -> CellConfiguration? {
        ensureRemoteHostRouteRegistered(for: endpoint, resolver: resolver)
        guard let emit = try? await resolver.cellAtEndpoint(endpoint: endpoint, requester: identity),
              let cell = emit as? Meddle
        else {
            return nil
        }

        for keypath in ["skeletonConfiguration", "purposeGoal", "configuration"] {
            guard let value = try? await cell.get(keypath: keypath, requester: identity),
                  let recoveredConfiguration = extractConfigurationFromRecoveredValue(value)
            else {
                continue
            }

            let origin = catalogOrigin(from: endpoint)
            let normalized = normalizeConfigurationForResolver(
                recoveredConfiguration,
                origin: origin,
                resolver: resolver
            )
            guard let sanitized = sanitizedLoadedConfiguration(normalized, allowReferenceFree: false),
                  !isEmitterConfiguration(sanitized)
            else {
                continue
            }
            return sanitized
        }

        return nil
    }

    private func extractConfigurationFromRecoveredValue(_ value: ValueType) -> CellConfiguration? {
        if let direct = decodeCellConfiguration(from: value) {
            return direct
        }
        guard case let .object(object) = value else { return nil }
        if let configuration = decodeCellConfiguration(from: object["configuration"]) {
            return configuration
        }
        if let configuration = decodeCellConfiguration(from: object["goal"]) {
            return configuration
        }
        if let configuration = decodeCellConfiguration(from: object["skeletonConfiguration"]) {
            return configuration
        }
        return nil
    }

    private func decodeCellConfiguration(from value: ValueType?) -> CellConfiguration? {
        guard let value else { return nil }
        switch value {
        case .cellConfiguration(let configuration):
            return configuration
        case .object(let object):
            guard let data = try? JSONEncoder().encode(object) else { return nil }
            return try? JSONDecoder().decode(CellConfiguration.self, from: data)
        default:
            return nil
        }
    }

    private func allReferenceEndpointIdentities(in configuration: CellConfiguration) -> Set<String> {
        guard let references = configuration.cellReferences else { return [] }
        var endpoints: Set<String> = []
        for reference in references {
            collectEndpointIdentities(from: reference, into: &endpoints)
        }
        return endpoints
    }

    private func collectEndpointIdentities(from reference: CellReference, into endpoints: inout Set<String>) {
        let endpoint = reference.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if !endpoint.isEmpty {
            endpoints.insert(endpointIdentity(endpoint))
        }

        for subscription in reference.subscriptions {
            collectEndpointIdentities(from: subscription, into: &endpoints)
        }

        for keyValue in reference.setKeysAndValues {
            guard let target = keyValue.target else { continue }
            let endpoint = target.trimmingCharacters(in: .whitespacesAndNewlines)
            if !endpoint.isEmpty {
                endpoints.insert(endpointIdentity(endpoint))
            }
        }
    }

    private func shouldPreferDiscoveredConfiguration(_ candidate: CellConfiguration, over existing: CellConfiguration) -> Bool {
        let candidateScore = configurationRichnessScore(candidate)
        let existingScore = configurationRichnessScore(existing)
        if candidateScore == existingScore {
            let candidateDescriptionCount = candidate.description?.count ?? 0
            let existingDescriptionCount = existing.description?.count ?? 0
            return candidateDescriptionCount > existingDescriptionCount
        }
        return candidateScore > existingScore
    }

    private func configurationRichnessScore(_ configuration: CellConfiguration) -> Int {
        var score = 0
        if configuration.skeleton != nil {
            score += 1000
        }
        score += allReferenceEndpointIdentities(in: configuration).count * 20
        if let description = configuration.description, !description.isEmpty {
            score += 4
        }
        if !configuration.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            score += 1
        }
        return score
    }

    private func appendUnique(_ incoming: [CellConfiguration], into target: inout [CellConfiguration]) {
        for configuration in incoming where !isEmitterConfiguration(configuration) {
            if let existingIndex = target.firstIndex(where: { $0.name.lowercased() == configuration.name.lowercased() }) {
                let existing = target[existingIndex]
                if shouldPreferDiscoveredConfiguration(configuration, over: existing) {
                    target[existingIndex] = configuration
                }
                continue
            }
            let key = menuIdentityKey(for: configuration)
            guard !target.contains(where: { menuIdentityKey(for: $0) == key }) else { continue }
            target.append(configuration)
        }
    }

    private func menuIdentityKey(for configuration: CellConfiguration) -> String {
        let refs = configuration.cellReferences?.map(\.endpoint).joined(separator: "|") ?? ""
        return "\(configuration.name.lowercased())|\(refs.lowercased())"
    }

    private func isEmitterConfiguration(_ configuration: CellConfiguration) -> Bool {
        let loweredName = configuration.name.lowercased()
        if loweredName.contains("emitter") || loweredName.contains("signal workbench") {
            return true
        }
        if let description = configuration.description?.lowercased(),
           description.contains("event emitter") {
            return true
        }
        guard let references = configuration.cellReferences else { return false }
        return references.contains(where: containsEmitterReference)
    }

    private func containsEmitterReference(_ reference: CellReference) -> Bool {
        if endpointLooksEmitter(reference.endpoint) {
            return true
        }
        if reference.subscriptions.contains(where: containsEmitterReference) {
            return true
        }
        return reference.setKeysAndValues.contains { item in
            if let target = item.target {
                return endpointLooksEmitter(target)
            }
            return false
        }
    }

    private func endpointLooksEmitter(_ endpoint: String) -> Bool {
        let lowered = endpoint.lowercased()
        return lowered.contains("eventemitter") || lowered.contains("/emitter") || lowered.hasSuffix("emitter")
    }

    private func sanitizedLoadedConfiguration(_ configuration: CellConfiguration, allowReferenceFree: Bool) -> CellConfiguration? {
        guard let references = configuration.cellReferences, !references.isEmpty else {
            return allowReferenceFree ? configuration : nil
        }
        let sanitizedReferences = references.compactMap { sanitizedLoadedReference($0) }
        guard !sanitizedReferences.isEmpty else { return nil }

        var sanitized = configuration
        sanitized.cellReferences = sanitizedReferences
        return sanitized
    }

    private func sanitizedLoadedReference(_ reference: CellReference) -> CellReference? {
        if endpointShouldBeRemovedFromLoadedConfiguration(reference.endpoint) {
            return nil
        }

        var sanitized = reference
        sanitized.subscriptions = reference.subscriptions.compactMap { sanitizedLoadedReference($0) }
        sanitized.setKeysAndValues = reference.setKeysAndValues.compactMap { item in
            guard let target = item.target else { return item }
            if endpointShouldBeRemovedFromLoadedConfiguration(target) {
                return nil
            }
            return item
        }
        return sanitized
    }

    private func endpointShouldBeRemovedFromLoadedConfiguration(_ endpoint: String) -> Bool {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lowered = trimmed.lowercased()
        if Self.blockedLoadedReferenceNames.contains(lowered) {
            return true
        }

        let pathName: String = {
            if let components = URLComponents(string: trimmed) {
                let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if let last = path.split(separator: "/").last {
                    return String(last).lowercased()
                }
            }
            return lowered
                .split(separator: "/")
                .last
                .map(String.init)?
                .lowercased() ?? lowered
        }()
        return Self.blockedLoadedReferenceNames.contains(pathName)
    }

    private func curatedMenuSeedConfigurations() -> MenuConfigurationBuckets {
        func stagingEndpoint(_ cellName: String) -> String {
            "cell://\(Self.stagingHost)/\(cellName)"
        }

        let chat = ConfigurationCatalogCell.scaffoldChatWorkbenchMenuConfiguration(
            endpoint: stagingEndpoint("Chat")
        )
        let conference = referenceMenuConfiguration(
            name: "Conference MVP",
            endpoint: stagingEndpoint("ConferenceUIRouter"),
            label: "conference",
            title: "Conference",
            subtitle: "Konferanseflyt med routing, matchmaking og scheduling."
        )
        let todo = referenceMenuConfiguration(
            name: "Todo MVP",
            endpoint: stagingEndpoint("Todo"),
            label: "todo",
            title: "Todo",
            subtitle: "Personlig oppgaveliste fra CellScaffold."
        )
        let obsidian = referenceMenuConfiguration(
            name: "Obsidian Vault",
            endpoint: stagingEndpoint("Vault"),
            label: "vault",
            title: "Obsidian",
            subtitle: "Vault-notater og knowledge graph fra CellScaffold."
        )
        let appleIntelligence = ConfigurationCatalogCell.appleIntelligenceLandingConfiguration()
        let catalogWorkbench = ConfigurationCatalogCell.catalogWorkbenchMenuConfiguration()
        let perspectiveWorkbench = ConfigurationCatalogCell.perspectiveWorkbenchMenuConfiguration()
        let agentSetupWorkbench = ConfigurationCatalogCell.agentSetupWorkbenchMenuConfiguration()
        let entityAnchorWorkbench = ConfigurationCatalogCell.entityAnchorWorkbenchMenuConfiguration()
        let vaultWorkbench = ConfigurationCatalogCell.vaultWorkbenchMenuConfiguration()
        let trustedIssuersWorkbench = ConfigurationCatalogCell.trustedIssuersWorkbenchMenuConfiguration()
        let portholeWorkbench = ConfigurationCatalogCell.portholeWorkbenchMenuConfiguration()
        let folderWatchWorkbench = ConfigurationCatalogCell.folderWatchWorkbenchMenuConfiguration()
        let graphIndexWorkbench = ConfigurationCatalogCell.graphIndexWorkbenchMenuConfiguration()
        let localEntityScanner = ConfigurationCatalogCell.entityScannerWorkbenchConfiguration()
        let localEntityScannerHelper = ConfigurationCatalogCell.entityScannerTestHelperConfiguration()
        let localEntityScannerChecklist = ConfigurationCatalogCell.entityScannerPairingChecklistConfiguration()

        return (
            upperLeft: [chat, conference, todo],
            upperMid: [appleIntelligence, catalogWorkbench, perspectiveWorkbench, agentSetupWorkbench, portholeWorkbench],
            upperRight: [conference, obsidian, portholeWorkbench],
            lowerLeft: [localEntityScanner, perspectiveWorkbench, entityAnchorWorkbench, trustedIssuersWorkbench, localEntityScannerHelper, localEntityScannerChecklist],
            lowerMid: [todo, catalogWorkbench, agentSetupWorkbench, folderWatchWorkbench, graphIndexWorkbench],
            lowerRight: [obsidian, vaultWorkbench, graphIndexWorkbench, trustedIssuersWorkbench]
        )
    }

    private func referenceMenuConfiguration(
        name: String,
        endpoint: String,
        label: String,
        title: String,
        subtitle: String
    ) -> CellConfiguration {
        var configuration = CellConfiguration(name: name)
        configuration.description = subtitle
        configuration.addReference(CellReference(endpoint: endpoint, label: label))

        let headline = SkeletonText(text: title)
        let body = SkeletonText(text: subtitle)
        let endpointText = SkeletonText(text: endpoint)
        configuration.skeleton = .VStack(
            SkeletonVStack(elements: [
                .Text(headline),
                .Text(body),
                .Text(endpointText)
            ])
        )
        return configuration
    }

    private func retargetConfigurationToStagingIfNeeded(_ configuration: CellConfiguration) -> CellConfiguration {
        var updated = configuration
        guard let references = configuration.cellReferences, !references.isEmpty else { return updated }
        updated.cellReferences = references.map { retargetReferenceToStagingIfNeeded($0) }
        return updated
    }

    private func retargetReferenceToStagingIfNeeded(_ reference: CellReference) -> CellReference {
        var updated = reference
        updated.endpoint = maybeRetargetLocalEndpointToStaging(reference.endpoint)
        updated.subscriptions = reference.subscriptions.map { retargetReferenceToStagingIfNeeded($0) }
        updated.setKeysAndValues = reference.setKeysAndValues.map { item in
            var next = item
            if let target = item.target {
                next.target = maybeRetargetLocalEndpointToStaging(target)
            }
            return next
        }
        return updated
    }

    func maybeRetargetLocalEndpointToStaging(_ endpoint: String) -> String {
        guard var components = URLComponents(string: endpoint),
              components.scheme?.lowercased() == "cell"
        else {
            return endpoint
        }
        let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isLocal = host == nil || host?.isEmpty == true || host == "localhost"
        guard isLocal else { return endpoint }

        let pathParts = components.path.split(separator: "/").map(String.init)
        guard let firstPart = pathParts.first?.lowercased(),
              Self.stagingFallbackCells.contains(firstPart)
        else {
            return endpoint
        }

        components.host = Self.stagingHost
        components.port = nil
        components.path = "/" + pathParts.joined(separator: "/")
        return components.string ?? endpoint
    }
}

private extension ValueType {
    var cellConfigurations: [CellConfiguration] {
        guard case let .list(values) = self else { return [] }
        return values.compactMap { value in
            switch value {
            case .cellConfiguration(let configuration):
                return configuration
            case .object(let object):
                guard let data = try? JSONEncoder().encode(object) else { return nil }
                return try? JSONDecoder().decode(CellConfiguration.self, from: data)
            default:
                return nil
            }
        }
    }
}

// MARK: - Porthole canvas hosting the Skeleton renderer
private struct PortholeCanvas: View {
    var skeleton: SkeletonElement
    var isEditing: Bool
    var selectedNodePath: SkeletonNodePath?
    var highlightedDropTargets: [DropTargetDescriptor]
    var activeComponent: ComponentPaletteItem?
    var isPlacementArmed: Bool
    var onSelectPath: (SkeletonNodePath) -> Void
    var onCancelComponentPlacement: () -> Void
    var onApplyComponentDrop: (ComponentPaletteItem, DropPlacement) -> Bool
    @EnvironmentObject private var viewModel: PortholeBindingViewModel

    var body: some View {
        ZStack {
#if canImport(UIKit)
            Color(UIColor.systemBackground)
#elseif canImport(AppKit)
            Color(NSColor.windowBackgroundColor)
#else
            Color(.white)
#endif
            GeometryReader { proxy in
                Group {
                    if isEditing {
                        EditorSelectableSkeletonView(
                            element: skeleton,
                            path: .root,
                            selectedPath: selectedNodePath,
                            highlightedDropTargetPaths: Set(highlightedDropTargets.map(\.path)),
                            onSelect: onSelectPath
                        )
                    } else {
                        SkeletonView(element: skeleton)
                    }
                }
                    .environmentObject(viewModel)
                    .padding()
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .overlayPreferenceValue(EditorSkeletonNodeBoundsPreferenceKey.self) { anchors in
                        GeometryReader { overlayProxy in
                            if let activeComponent {
                                if isPlacementArmed || highlightedDropTargets.isEmpty {
                                    HStack(spacing: 10) {
                                        Text(componentStatusLine(for: activeComponent, hasTargets: !highlightedDropTargets.isEmpty))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if isPlacementArmed {
                                            Button("Avbryt") {
                                                onCancelComponentPlacement()
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .position(x: overlayProxy.size.width / 2, y: 26)
                                }

                                ForEach(highlightedDropTargets) { target in
                                    if let anchor = anchors[target.path.description] {
                                        let rect = overlayProxy[anchor]
                                        ComponentDropSlotView(
                                            descriptor: target,
                                            activeItem: activeComponent,
                                            activeTitle: activeComponent.title,
                                            onApplyComponentDrop: onApplyComponentDrop
                                        )
                                        .position(
                                            slotPosition(
                                                for: target,
                                                rect: rect,
                                                canvasSize: overlayProxy.size
                                            )
                                        )
                                    }
                                }
                            }
                        }
                    }
            }
        }
    }

    private func slotPosition(
        for target: DropTargetDescriptor,
        rect: CGRect,
        canvasSize: CGSize
    ) -> CGPoint {
        let rawPoint: CGPoint
        switch target.placement {
        case .intoContainer:
            rawPoint = CGPoint(x: rect.maxX - 84, y: rect.minY + 20)
        case .afterNode:
            rawPoint = CGPoint(x: rect.midX, y: rect.maxY + 18)
        case .beforeNode:
            rawPoint = CGPoint(x: rect.midX, y: rect.minY - 18)
        case .replaceNode:
            rawPoint = CGPoint(x: rect.midX, y: rect.midY)
        case .root:
            rawPoint = CGPoint(x: rect.midX, y: rect.minY + 20)
        }

        return CGPoint(
            x: min(max(rawPoint.x, 90), max(90, canvasSize.width - 90)),
            y: min(max(rawPoint.y, 26), max(26, canvasSize.height - 26))
        )
    }

    private func componentStatusLine(for item: ComponentPaletteItem, hasTargets: Bool) -> String {
        if hasTargets {
            return "Plasserer \(item.title.lowercased()). Klikk et innsettingspunkt i lerretet."
        }
        return "Ingen gyldige innsettingspunkter for \(item.title.lowercased()). Velg en container eller et annet element."
    }
}

private struct ComponentDropSlotView: View {
    let descriptor: DropTargetDescriptor
    let activeItem: ComponentPaletteItem?
    let activeTitle: String
    let onApplyComponentDrop: (ComponentPaletteItem, DropPlacement) -> Bool

    @State private var isTargeted = false

    var body: some View {
        Button {
            guard let activeItem else { return }
            _ = onApplyComponentDrop(activeItem, descriptor.placement)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: descriptor.targetKind == "root" ? "square.grid.2x2" : "plus.circle.fill")
                    .font(.caption)
                Text(slotLabel)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .disabled(activeItem == nil)
        .foregroundStyle(isTargeted ? Color.white : Color.accentColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isTargeted ? Color.accentColor : Color.accentColor.opacity(0.14))
        )
        .overlay(
            Capsule()
                .stroke(Color.accentColor.opacity(isTargeted ? 0 : 0.25), lineWidth: 1)
        )
        .dropDestination(for: ComponentPaletteItem.self) { items, _ in
            guard let item = items.first else { return false }
            return onApplyComponentDrop(item, descriptor.placement)
        } isTargeted: { targeted in
            isTargeted = targeted
        }
        .accessibilityLabel("\(slotLabel) for \(activeTitle)")
    }

    private var slotLabel: String {
        switch descriptor.placement {
        case .intoContainer:
            return "Legg inn"
        case .afterNode:
            return "Etter"
        case .beforeNode:
            return "Før"
        case .replaceNode:
            return "Erstatt"
        case .root:
            return "Sett som rot"
        }
    }
}

// MARK: - Overlay that places six edge menus
// Documentation: See Prompts/EdgeMenusOverlay.md for concepts and guidelines
// Additional project rules: See Prompts/CONTRIBUTING.md and Prompts/Architecture.md
private struct EdgeMenusOverlay: View {
    var upperLeft: [MenuItem]
    var upperMid: [MenuItem]
    var upperRight: [MenuItem]
    var lowerLeft: [MenuItem]
    var lowerMid: [MenuItem]
    var lowerRight: [MenuItem]
    var onPrimaryAction: (EdgePosition) -> Bool
    var onSelect: (CellConfiguration) -> Void

    @State private var expanded: Set<EdgePosition> = []

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                EdgeMenu(position: EdgePosition.upperLeft, items: upperLeft, isExpanded: expanded.contains(EdgePosition.upperLeft)) { action(EdgePosition.upperLeft, $0) }
                    .position(x: 32, y: 32)

                EdgeMenu(position: EdgePosition.upperMid, items: upperMid, isExpanded: expanded.contains(EdgePosition.upperMid)) { action(EdgePosition.upperMid, $0) }
                    .position(x: proxy.size.width / 2, y: 32)

                EdgeMenu(position: EdgePosition.upperRight, items: upperRight, isExpanded: expanded.contains(EdgePosition.upperRight)) { action(EdgePosition.upperRight, $0) }
                    .position(x: proxy.size.width - 32, y: 32)

                EdgeMenu(position: EdgePosition.lowerLeft, items: lowerLeft, isExpanded: expanded.contains(EdgePosition.lowerLeft)) { action(EdgePosition.lowerLeft, $0) }
                    .position(x: 32, y: proxy.size.height - 32)

                EdgeMenu(position: EdgePosition.lowerMid, items: lowerMid, isExpanded: expanded.contains(EdgePosition.lowerMid)) { action(EdgePosition.lowerMid, $0) }
                    .position(x: proxy.size.width / 2, y: proxy.size.height - 32)

                EdgeMenu(position: EdgePosition.lowerRight, items: lowerRight, isExpanded: expanded.contains(EdgePosition.lowerRight)) { action(EdgePosition.lowerRight, $0) }
                    .position(x: proxy.size.width - 32, y: proxy.size.height - 32)
            }
            .onPreferenceChange(EdgeMenuToggleKey.self) { pos in
                if let pos { toggle(pos) }
            }
        }
    }

    private func action(_ position: EdgePosition, _ config: CellConfiguration?) {
        if let config { onSelect(config) }
        else if !onPrimaryAction(position) {
            let items = menuItems(for: position)
            if items.count == 1, let only = items.first?.configuration {
                onSelect(only)
                return
            }
            toggle(position)
        }
    }

    private func menuItems(for position: EdgePosition) -> [MenuItem] {
        switch position {
        case .upperLeft:
            return upperLeft
        case .upperMid:
            return upperMid
        case .upperRight:
            return upperRight
        case .lowerLeft:
            return lowerLeft
        case .lowerMid:
            return lowerMid
        case .lowerRight:
            return lowerRight
        }
    }

    private func toggle(_ position: EdgePosition) {
        withAnimation(.spring()) {
            if expanded.contains(position) { expanded.remove(position) } else { expanded.insert(position) }
        }
    }
}

private extension CellConfiguration {
    var skeletonIconName: String {
        let loweredName = name.lowercased()
        let loweredEndpoints = (cellReferences ?? []).map { $0.endpoint.lowercased() }

        func contains(_ token: String) -> Bool {
            loweredName.contains(token) || loweredEndpoints.contains(where: { $0.contains(token) })
        }

        if contains("chat") { return "bubble.left.and.bubble.right.fill" }
        if contains("conference") { return "person.3.sequence.fill" }
        if contains("todo") { return "checkmark.circle.fill" }
        if contains("admin") { return "shield.lefthalf.filled.badge.checkmark" }
        if contains("appleintelligence") || contains("intelligence") { return "sparkles" }
        if contains("entityscanner") || contains("entities") { return "point.3.connected.trianglepath.dotted" }
        if contains("locations") { return "map.fill" }
        if contains("times") { return "clock.fill" }
        if contains("funding") { return "creditcard.fill" }
        if contains("leadvault") || contains("consent") { return "lock.doc.fill" }

        guard let s = skeleton else { return "square.grid.2x2" }
        switch s {
        case .Image:
            return "photo"
        case .List:
            return "list.bullet"
        case .Button:
            return "square.and.arrow.down"
        case .Reference:
            return "link"
        case .HStack, .VStack:
            return "square.grid.2x2"
        case .Text:
            return "text.justify"
        case .Object:
            return "square.grid.3x3"
        case .Spacer:
            return "rectangle.dashed"
        default:
            // Fallback for any future or platform-specific cases to keep the switch exhaustive
            return "square.grid.2x2"
        }
    }
}

@MainActor
final class BridgeConnectionStatusStore: ObservableObject {
    @Published private(set) var visibleStatuses: [LightweightBridgeConnectionStatus] = []

    private var statusesByEndpoint: [String: LightweightBridgeConnectionStatus] = [:]
    private var statusCancellable: AnyCancellable?
    private var cleanupTask: Task<Void, Never>?

    init(notificationCenter: NotificationCenter = .default) {
        statusCancellable = notificationCenter
            .publisher(for: .lightweightBridgeConnectionStatusDidChange)
            .compactMap(LightweightBridgeConnectionStatus.init(notification:))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.store(status)
            }

        cleanupTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                self?.pruneExpiredStatuses()
            }
        }
    }

    deinit {
        statusCancellable?.cancel()
        cleanupTask?.cancel()
    }

    var primaryStatus: LightweightBridgeConnectionStatus? {
        visibleStatuses.first
    }

    private func store(_ status: LightweightBridgeConnectionStatus) {
        statusesByEndpoint[status.endpoint] = status
        rebuildVisibleStatuses(referenceDate: Date())
    }

    private func pruneExpiredStatuses() {
        rebuildVisibleStatuses(referenceDate: Date())
    }

    private func rebuildVisibleStatuses(referenceDate now: Date) {
        statusesByEndpoint = statusesByEndpoint.filter { _, status in
            !status.isExpired(relativeTo: now)
        }

        visibleStatuses = statusesByEndpoint.values
            .filter { $0.shouldDisplay(relativeTo: now) }
            .sorted { lhs, rhs in
                if lhs.severityRank == rhs.severityRank {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.severityRank > rhs.severityRank
            }
    }
}

struct BridgeStatusBanner: View {
    let status: LightweightBridgeConnectionStatus
    let additionalCount: Int

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: status.iconName)
                .foregroundStyle(status.tintColor)
                .font(.headline)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(status.titleText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)

                    if additionalCount > 0 {
                        Text("+\(additionalCount)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                    }
                }

                Text(status.subtitleText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(status.tintColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(status.tintColor.opacity(0.22), lineWidth: 1)
        }
    }
}

private extension LightweightBridgeConnectionStatus {
    var severityRank: Int {
        switch phase {
        case .failed:
            return 5
        case .disconnected:
            return 4
        case .reconnecting:
            return 3
        case .connecting:
            return 2
        case .connected:
            return 1
        }
    }

    func shouldDisplay(relativeTo now: Date) -> Bool {
        let age = now.timeIntervalSince(updatedAt)
        switch phase {
        case .connected:
            return age <= 10
        case .connecting:
            return age <= 20
        case .reconnecting, .disconnected, .failed:
            return age <= 90
        }
    }

    func isExpired(relativeTo now: Date) -> Bool {
        let age = now.timeIntervalSince(updatedAt)
        switch phase {
        case .connected:
            return age > 20
        case .connecting:
            return age > 40
        case .reconnecting, .disconnected, .failed:
            return age > 180
        }
    }

    var titleText: String {
        switch phase {
        case .connecting:
            return "Kobler til bridge"
        case .connected:
            return "Bridge tilkoblet"
        case .reconnecting:
            return "Kobler til igjen"
        case .disconnected:
            return "Bridge frakoblet"
        case .failed:
            return "Bridge-feil"
        }
    }

    var subtitleText: String {
        var parts: [String] = [endpointSummary]
        if let attempt {
            parts.append("forsøk \(attempt)")
        }
        if let detail, !detail.isEmpty {
            parts.append(detail)
        }
        return parts.joined(separator: " • ")
    }

    var tintColor: Color {
        switch phase {
        case .connecting:
            return .blue
        case .connected:
            return .green
        case .reconnecting:
            return .orange
        case .disconnected:
            return .orange
        case .failed:
            return .red
        }
    }

    var iconName: String {
        switch phase {
        case .connecting:
            return "bolt.horizontal.circle.fill"
        case .connected:
            return "checkmark.circle.fill"
        case .reconnecting:
            return "arrow.trianglehead.2.clockwise.rotate.90.circle.fill"
        case .disconnected:
            return "wifi.slash"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    var endpointSummary: String {
        guard let components = URLComponents(string: endpoint) else {
            return endpoint
        }

        let host = components.host ?? endpoint
        let lastPath = components.path
            .split(separator: "/")
            .last
            .map(String.init)

        if let lastPath, !lastPath.isEmpty, lastPath.lowercased() != host.lowercased() {
            return "\(host)/\(lastPath)"
        }

        return host
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
