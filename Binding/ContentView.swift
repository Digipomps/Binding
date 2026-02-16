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

struct ContentView: View {
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

    @StateObject private var viewModel = PortholeBindingViewModel()
    @StateObject private var editorState = EditorState()
    @State private var editorMode: EditorMode = .view
    @State private var menusHidden: Bool = false
    @State private var rotationAccumulator: Angle = .zero
    @State private var didAttemptCatalogMenuSync: Bool = false
    @State private var activeConfiguration: CellConfiguration?

    var body: some View {
        ZStack {
            // Full-screen porthole canvas rendering current skeleton
            PortholeCanvas(
                skeleton: renderedSkeleton,
                isEditing: editorMode == .edit,
                selectedNodePath: editorState.selectedNodePath,
                onSelectPath: { selectedPath in
                    editorState.selectNode(selectedPath)
                }
            )
                .environmentObject(viewModel)
                .ignoresSafeArea()
                .dropDestination(for: CellConfiguration.self) { items, location in
                    // On drop, load the configuration into the porthole
                    Task { await loadConfigurationForEditing(items.first) }
                    return !items.isEmpty
                }

            if !menusHidden {
                // Edge menus overlay
                EdgeMenusOverlay(
                    upperLeft: menuItems(from: viewModel.upperLeftMenu),
                    upperMid: menuItems(from: viewModel.upperMidMenu),
                    upperRight: menuItems(from: viewModel.upperRightMenu),
                    lowerLeft: menuItems(from: viewModel.lowerLeftMenu),
                    lowerMid: menuItems(from: viewModel.lowerMidMenu),
                    lowerRight: menuItems(from: viewModel.lowerRightMenu),
                    onSelect: { config in
                        Task { await loadConfigurationForEditing(config) }
                    }
                )
                .allowsHitTesting(true)
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .gesture(rotationHideShowGesture)
        .safeAreaInset(edge: .top, alignment: .trailing) {
            editorModePanel
                .padding(.trailing, 12)
                .padding(.top, 6)
        }
        .safeAreaInset(edge: .leading, alignment: .top) {
            if editorMode == .edit {
                SkeletonTreePanel(editorState: editorState)
                    .padding(.leading, 12)
                    .padding(.top, 56)
            }
        }
        .safeAreaInset(edge: .trailing, alignment: .top) {
            if editorMode == .edit {
                SkeletonModifierInspectorPanel(editorState: editorState)
                    .padding(.trailing, 12)
                    .padding(.top, 56)
            }
        }
        .onChange(of: editorMode) { _, mode in
            switch mode {
            case .view:
                applyWorkingCopyToViewer()
                editorState.endEditing()
            case .edit:
                editorState.beginEditing(from: viewModel.currentSkeleton)
            }
        }
        .onReceive(viewModel.$currentSkeleton) { next in
            if !editorState.isEditing {
                editorState.captureViewerSnapshot(next)
            }
        }
        .task {
            // Ensure IdentityVault is available for the model
            if CellBase.defaultIdentityVault == nil {
                CellBase.defaultIdentityVault = IdentityVault.shared
                _ = await IdentityVault.shared.initialize()
            }
            await viewModel.connectIfNeeded()
            if !didAttemptCatalogMenuSync {
                didAttemptCatalogMenuSync = true
                await refreshMenusFromCatalogIfAvailable()
            }
            editorState.captureViewerSnapshot(viewModel.currentSkeleton)
        }
    }

    // MARK: - Rotation gesture to hide/show menus
    private var rotationHideShowGesture: some Gesture {
        RotationGesture()
            .onChanged { angle in
                rotationAccumulator = angle
            }
            .onEnded { angle in
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
        return configs.map { config in
            // Choose an icon heuristically; you can expand this mapping later
            let icon = config.skeletonIconName
            return MenuItem(icon: icon, configuration: config)
        }
    }

    @MainActor
    private func refreshMenusFromCatalogIfAvailable() async {
        guard let resolver = CellBase.defaultCellResolver as? CellResolver else { return }
        guard let identity = await CellBase.defaultIdentityVault?.identity(for: "private", makeNewIfNotFound: true) else { return }

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

            func fetchMenu(_ keypath: String) async -> [CellConfiguration] {
                guard let value = try? await catalog.get(keypath: keypath, requester: identity) else { return [] }
                return normalizeCatalogMenu(value.cellConfigurations, origin: origin, resolver: resolver)
            }

            let upperLeft = await fetchMenu("upperLeftMenu")
            let upperMid = await fetchMenu("upperMidMenu")
            let upperRight = await fetchMenu("upperRightMenu")
            let lowerLeft = await fetchMenu("lowerLeftMenu")
            let lowerMid = await fetchMenu("lowerMidMenu")
            let lowerRight = await fetchMenu("lowerRightMenu")

            let hasCatalogData = !upperLeft.isEmpty || !upperMid.isEmpty || !upperRight.isEmpty || !lowerLeft.isEmpty || !lowerMid.isEmpty || !lowerRight.isEmpty
            guard hasCatalogData else { continue }

            viewModel.upperLeftMenu = upperLeft
            viewModel.upperMidMenu = upperMid
            viewModel.upperRightMenu = upperRight
            viewModel.lowerLeftMenu = lowerLeft
            viewModel.lowerMidMenu = lowerMid
            viewModel.lowerRightMenu = lowerRight
            return
        }
    }

    private func configuredCatalogSources() -> [CatalogSource] {
        let raw = ProcessInfo.processInfo.environment["BINDING_REMOTE_CATALOG_ENDPOINTS"] ?? ""
        let separators = CharacterSet(charactersIn: ",;\n")
        let remoteEndpoints = raw
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var sources = remoteEndpoints.map { CatalogSource(endpoint: $0, allowSync: false) }
        sources.append(CatalogSource(endpoint: "cell:///ConfigurationCatalog", allowSync: true))
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
            let route = RemoteCellHostRoute(websocketEndpoint: "publishersws", schemePreference: .automatic)
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
        if snapshot[normalizedHost] == nil {
            resolver.registerRemoteCellHost(host, route: route)
        }
    }

    private func inferredWebsocketRoutePath(fromCatalogEndpointPath path: String) -> String {
        let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !normalizedPath.isEmpty else { return "publishersws" }

        let components = normalizedPath.split(separator: "/").map(String.init)
        guard components.count > 1 else { return "" }
        return components.dropLast().joined(separator: "/")
    }

    private func normalizeCatalogMenu(_ configs: [CellConfiguration], origin: CatalogOrigin?, resolver: CellResolver) -> [CellConfiguration] {
        configs.map { normalizeConfigurationForResolver($0, origin: origin, resolver: resolver) }
    }

    private func normalizeConfigurationForResolver(_ configuration: CellConfiguration, origin: CatalogOrigin?, resolver: CellResolver) -> CellConfiguration {
        var normalized = configuration
        if let references = configuration.cellReferences {
            normalized.cellReferences = references.map { normalizeReferenceForResolver($0, origin: origin, resolver: resolver) }
        }
        return normalized
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
            let fallbackRoute = origin?.route ?? RemoteCellHostRoute(websocketEndpoint: "publishersws", schemePreference: .automatic)
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

    private var editorModePanel: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Picker("Mode", selection: $editorMode) {
                ForEach(EditorMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

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
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func applyWorkingCopyToViewer() {
        guard let committed = editorState.commitChanges() else { return }
        if var configuration = activeConfiguration {
            configuration.skeleton = committed
            activeConfiguration = configuration
            Task { await viewModel.load(configuration: configuration) }
        } else {
            var fallback = CellConfiguration(name: "Edited Skeleton")
            fallback.skeleton = committed
            activeConfiguration = fallback
            Task { await viewModel.load(configuration: fallback) }
        }
    }

    @MainActor
    private func loadConfigurationForEditing(_ configuration: CellConfiguration?) async {
        guard let configuration else { return }
        activeConfiguration = configuration
        await viewModel.load(configuration: configuration)
        if editorMode == .edit, let skeleton = configuration.skeleton {
            editorState.beginEditing(from: skeleton)
        }
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
    var onSelectPath: (SkeletonNodePath) -> Void
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
                
            }
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
        else { toggle(position) }
    }

    private func toggle(_ position: EdgePosition) {
        withAnimation(.spring()) {
            if expanded.contains(position) { expanded.remove(position) } else { expanded.insert(position) }
        }
    }
}

private extension CellConfiguration {
    var skeletonIconName: String {
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

// MARK: - Preview
#Preview {
    ContentView()
}
