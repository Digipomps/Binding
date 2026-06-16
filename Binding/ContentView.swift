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

private struct BindingHostingWindowReader: NSViewRepresentable {
    let onResolve: @MainActor (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            onResolve(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onResolve(nsView.window)
        }
    }
}
#endif

nonisolated enum ConfigurationPresentationSupport {
    private static let viewportBoundConfigurationNames: Set<String> = [
        "conference participant portal dashboard"
    ]

    static func viewportSafeConfiguration(_ configuration: CellConfiguration) -> CellConfiguration {
        let normalizedName = configuration.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard viewportBoundConfigurationNames.contains(normalizedName),
              let skeleton = configuration.skeleton
        else {
            return configuration
        }

        if case .ScrollView = skeleton {
            return configuration
        }

        var adjusted = configuration
        adjusted.skeleton = .ScrollView(SkeletonScrollView(axis: "vertical", elements: [skeleton]))
        return adjusted
    }
}

nonisolated enum SkeletonBindingProbeSupport {
    struct RootProbe: Hashable {
        let label: String
        let rootKeypath: String

        var qualifiedKeypath: String {
            "\(label).\(rootKeypath)"
        }
    }

    private static let skeletonElementKinds: Set<String> = [
        "Text", "TextField", "TextArea", "List", "Object", "Reference",
        "Toggle", "Image", "Button", "Spacer", "HStack", "VStack",
        "ScrollView", "Section", "ZStack", "Grid", "Divider"
    ]
    private static let readableBindingKeys: Set<String> = [
        "keypath",
        "sourceKeypath"
    ]

    static func rootProbes(for configuration: CellConfiguration) -> [RootProbe] {
        guard let skeleton = configuration.skeleton,
              let rawObject = rawObject(from: skeleton)
        else {
            return []
        }

        let labels = Set(
            (configuration.cellReferences ?? [])
                .map { $0.label.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        guard !labels.isEmpty else { return [] }

        var collected: [RootProbe] = []
        collectRootProbes(from: rawObject, currentElementKind: nil, labels: labels, into: &collected)
        return collected
    }

    static func failureDetail(from value: ValueType) -> String? {
        guard case let .string(text) = value else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.lowercased()
        if normalized.hasPrefix("error:") ||
            normalized.hasPrefix("denied") ||
            normalized.hasPrefix("failure") ||
            normalized.contains("notfound") ||
            normalized.contains("midlertidig utilgjengelig") ||
            normalized.contains("ikke tilgjengelig akkurat nå") ||
            normalized.contains("bad response from the server") ||
            normalized.contains("notconnected") {
            return trimmed
        }
        return nil
    }

    private static func rawObject<T: Encodable>(from value: T) -> Any? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private static func collectRootProbes(
        from value: Any,
        currentElementKind: String?,
        labels: Set<String>,
        into collected: inout [RootProbe]
    ) {
        switch value {
        case let dictionary as [String: Any]:
            if dictionary.count == 1,
               let onlyKey = dictionary.keys.first,
               skeletonElementKinds.contains(onlyKey),
               let child = dictionary[onlyKey] {
                collectRootProbes(
                    from: child,
                    currentElementKind: onlyKey,
                    labels: labels,
                    into: &collected
                )
                return
            }

            for (key, child) in dictionary {
                if readableBindingKeys.contains(key),
                   currentElementKind != "Button",
                   let bindingValue = child as? String,
                   let probe = rootProbe(from: bindingValue, labels: labels),
                   !collected.contains(probe) {
                    collected.append(probe)
                }

                collectRootProbes(
                    from: child,
                    currentElementKind: currentElementKind,
                    labels: labels,
                    into: &collected
                )
            }
        case let array as [Any]:
            for child in array {
                collectRootProbes(
                    from: child,
                    currentElementKind: currentElementKind,
                    labels: labels,
                    into: &collected
                )
            }
        default:
            break
        }
    }

    private static func rootProbe(from bindingValue: String, labels: Set<String>) -> RootProbe? {
        let trimmed = bindingValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalizedBinding: String
        if trimmed.hasPrefix("cell:///Porthole/") {
            normalizedBinding = String(trimmed.dropFirst("cell:///Porthole/".count))
        } else if trimmed.hasPrefix("cell://") || trimmed.hasPrefix("ws://") || trimmed.hasPrefix("wss://") {
            return nil
        } else {
            normalizedBinding = trimmed
        }

        guard let separatorIndex = normalizedBinding.firstIndex(of: ".") else {
            return nil
        }

        let label = String(normalizedBinding[..<separatorIndex])
        guard labels.contains(label) else { return nil }

        let remainder = String(normalizedBinding[normalizedBinding.index(after: separatorIndex)...])
        guard let rootSeparator = remainder.firstIndex(where: { $0 == "." || $0 == "[" }) else {
            guard !remainder.isEmpty else { return nil }
            return RootProbe(label: label, rootKeypath: remainder)
        }

        let rootKeypath = String(remainder[..<rootSeparator])
        guard !rootKeypath.isEmpty else { return nil }
        return RootProbe(label: label, rootKeypath: rootKeypath)
    }
}

private func contentViewModifier(_ configure: (inout SkeletonModifiers) -> Void) -> SkeletonModifiers {
    var modifiers = SkeletonModifiers()
    configure(&modifiers)
    return modifiers
}

private extension Color {
    init?(bindingHex: String) {
        var value = bindingHex
        if value.hasPrefix("#") {
            value.removeFirst()
        }

        var rgba: UInt64 = 0
        guard Scanner(string: value).scanHexInt64(&rgba) else {
            return nil
        }

        switch value.count {
        case 6:
            let red = Double((rgba & 0xFF0000) >> 16) / 255.0
            let green = Double((rgba & 0x00FF00) >> 8) / 255.0
            let blue = Double(rgba & 0x0000FF) / 255.0
            self = Color(red: red, green: green, blue: blue)
        case 8:
            let red = Double((rgba & 0xFF000000) >> 24) / 255.0
            let green = Double((rgba & 0x00FF0000) >> 16) / 255.0
            let blue = Double((rgba & 0x0000FF00) >> 8) / 255.0
            let alpha = Double(rgba & 0x000000FF) / 255.0
            self = Color(red: red, green: green, blue: blue).opacity(alpha)
        default:
            return nil
        }
    }
}

enum BindingPersonalCopilotPhoneTab: String, CaseIterable, Identifiable {
    case home
    case matches
    case chat
    case vault
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .matches:
            return "Matches"
        case .chat:
            return "Chat"
        case .vault:
            return "Vault"
        case .profile:
            return "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "house.fill"
        case .matches:
            return "person.2.fill"
        case .chat:
            return "bubble.left.and.bubble.right.fill"
        case .vault:
            return "rectangle.stack.fill"
        case .profile:
            return "person.crop.circle.fill"
        }
    }
}

enum BindingPersonalCopilotDestination: String, CaseIterable, Identifiable {
    case personalHome = "Personal Home"
    case myProfile = "My Profile"
    case publishPublicProfile = "Publish Public Profile"
    case publicProfileDirectory = "Public Profile Directory"
    case matches = "Matches"
    case inviteChat = "Co-Pilot Chat"
    case agendaContext = "Agenda Context"
    case vaultIdeas = "Vault / Ideas"
    case meetingIntent = "Meeting Intent"
    case privacyAudit = "Privacy Audit"
    case personalCopilotCatalog = "Personal Co-Pilot Catalog"
    case appleIntelligence = "Apple Intelligence"
    case entityScanner = "Entity Scanner"
    case workflowStudio = "Workflow Studio"

    var id: String { rawValue }
    var title: String { rawValue }

    var phoneTab: BindingPersonalCopilotPhoneTab {
        switch self {
        case .personalHome, .agendaContext, .meetingIntent, .appleIntelligence, .entityScanner, .workflowStudio:
            return .home
        case .publicProfileDirectory, .matches:
            return .matches
        case .inviteChat:
            return .chat
        case .vaultIdeas, .personalCopilotCatalog:
            return .vault
        case .myProfile, .publishPublicProfile, .privacyAudit:
            return .profile
        }
    }

    var sidebarSectionTitle: String {
        switch self {
        case .personalHome, .myProfile, .publishPublicProfile, .privacyAudit:
            return "Personal"
        case .publicProfileDirectory, .matches, .inviteChat, .meetingIntent:
            return "Network"
        case .agendaContext, .vaultIdeas, .personalCopilotCatalog, .appleIntelligence, .entityScanner, .workflowStudio:
            return "Workspace"
        }
    }

    var systemImage: String {
        configuration.skeletonIconName
    }

    var configuration: CellConfiguration {
        switch self {
        case .personalHome:
            return ConfigurationCatalogCell.personalHomeMenuConfiguration()
        case .myProfile:
            return ConfigurationCatalogCell.personalProfileMenuConfiguration()
        case .publishPublicProfile:
            return ConfigurationCatalogCell.personalPublicProfileMenuConfiguration()
        case .publicProfileDirectory:
            return ConfigurationCatalogCell.personalPublicProfileDirectoryMenuConfiguration()
        case .matches:
            return ConfigurationCatalogCell.personalMatchesMenuConfiguration()
        case .inviteChat:
            return ConfigurationCatalogCell.personalInviteChatMenuConfiguration()
        case .agendaContext:
            return ConfigurationCatalogCell.personalAgendaContextMenuConfiguration()
        case .vaultIdeas:
            return ConfigurationCatalogCell.personalVaultIdeasMenuConfiguration()
        case .meetingIntent:
            return ConfigurationCatalogCell.personalMeetingIntentMenuConfiguration()
        case .privacyAudit:
            return ConfigurationCatalogCell.personalPrivacyAuditMenuConfiguration()
        case .personalCopilotCatalog:
            return ConfigurationCatalogCell.personalCopilotCatalogMenuConfiguration()
        case .appleIntelligence:
            return ConfigurationCatalogCell.appleIntelligenceLandingForPersonalCopilotConfiguration()
        case .entityScanner:
            return ConfigurationCatalogCell.entityScannerForPersonalCopilotConfiguration()
        case .workflowStudio:
            return ConfigurationCatalogCell.workflowStudioForPersonalCopilotConfiguration()
        }
    }

    static var phonePrimaryTabs: [BindingPersonalCopilotPhoneTab] {
        BindingPersonalCopilotPhoneTab.allCases
    }

    static var sidebarSections: [(title: String, destinations: [BindingPersonalCopilotDestination])] {
        [
            ("Personal", [.personalHome, .myProfile, .publishPublicProfile, .privacyAudit]),
            ("Network", [.matches, .publicProfileDirectory, .inviteChat, .meetingIntent]),
            ("Workspace", [.agendaContext, .vaultIdeas, .personalCopilotCatalog, .appleIntelligence, .entityScanner, .workflowStudio])
        ]
    }

    static func matching(configurationName: String?) -> BindingPersonalCopilotDestination? {
        guard let configurationName else { return nil }
        let normalized = configurationName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "invite chat" {
            return .inviteChat
        }
        return allCases.first { $0.rawValue.lowercased() == normalized }
    }

    static func destinations(for tab: BindingPersonalCopilotPhoneTab) -> [BindingPersonalCopilotDestination] {
        allCases.filter { $0.phoneTab == tab }
    }

    static func defaultDestination(for tab: BindingPersonalCopilotPhoneTab) -> BindingPersonalCopilotDestination {
        destinations(for: tab).first ?? .personalHome
    }
}

struct ContentView: View {
    private enum ConferenceNavigationMode {
        case automatic
        case reset
        case skipPush
    }

    enum ConferenceAutomationHook: String, Equatable {
        case openLauncher = "open-launcher"
        case openParticipantPortal = "open-participant-portal"
        case openConferenceMVP = "open-conference-mvp"
        case openPublicSurface = "open-public-surface"
        case openControlTower = "open-control-tower"
        case openSponsorFollowUp = "open-sponsor-follow-up"
        case openAIAssistant = "open-ai-assistant"
        case logAIAssistantState = "log-ai-assistant-state"
        case openIdentityLink = "open-identity-link"
        case openAgentSetupWorkbench = "open-agent-setup-workbench"
        case installAgent = "install-agent"
        case startAgent = "start-agent"
        case connectAgent = "connect-agent"
        case queueAgentSafariReview = "queue-agent-safari-review"
        case approveAgentReview = "approve-agent-review"
        case stopAgent = "stop-agent"
        case focusAneSolberg = "focus-ane-solberg"
        case startChatWithFocusedParticipant = "start-chat-with-focused-participant"
        case openFocusedChatWorkbench = "open-focused-chat-workbench"
#if canImport(AppKit)
        case windowCompact = "window-compact"
        case windowTall = "window-tall"
        case windowWide = "window-wide"
        case centerWindow = "center-window"
#endif

        var title: String {
            switch self {
            case .openLauncher:
                return "Open Conference Demo Launcher"
            case .openParticipantPortal:
                return "Open Conference Participant Portal"
            case .openConferenceMVP:
                return "Open Conference MVP"
            case .openPublicSurface:
                return "Open Conference Public Surface"
            case .openControlTower:
                return "Open Conference Control Tower"
            case .openSponsorFollowUp:
                return "Open Conference Sponsor Follow-up"
            case .openAIAssistant:
                return "Open Conference AI Assistant"
            case .logAIAssistantState:
                return "Log Conference AI State"
            case .openIdentityLink:
                return "Open Conference Scaffold Setup & Identity Link"
            case .openAgentSetupWorkbench:
                return "Open Agent Setup Workbench"
            case .installAgent:
                return "Install HAVENAgentD"
            case .startAgent:
                return "Start HAVENAgentD"
            case .connectAgent:
                return "Run HAVENAgentD Once"
            case .queueAgentSafariReview:
                return "Queue Agent Safari Review"
            case .approveAgentReview:
                return "Approve Agent Review"
            case .stopAgent:
                return "Stop HAVENAgentD"
            case .focusAneSolberg:
                return "Focus Ane Solberg"
            case .startChatWithFocusedParticipant:
                return "Start chat with focused participant"
            case .openFocusedChatWorkbench:
                return "Open focused chat workbench"
#if canImport(AppKit)
            case .windowCompact:
                return "Viewport: Compact 900 × 640"
            case .windowTall:
                return "Viewport: Tall 900 × 1100"
            case .windowWide:
                return "Viewport: Wide 1280 × 900"
            case .centerWindow:
                return "Center window"
#endif
            }
        }
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private static let stagingHost = "staging.haven.digipomps.org"
    private static let defaultRemoteWebSocketPath = "bridgehead"
    private static let stagingRemoteWebSocketPath = "bridgehead"
    private static let portholeEndpoint = "cell:///Porthole"
    private static let defaultConferenceSponsorOrganizationID = "sponsor-ai-digital-independence"
    private static let defaultConferenceParticipantPreviewID = "preview-demo"
    private static let defaultConferenceAdminPreviewID = "preview-control-tower-v2"
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
        "aigateway",
        "conferenceuirouter",
        "conferenceadminshell",
        "conferenceparticipantshell",
        "conferencepublicprofileeditorpreview",
        "conferencepublicprofilepreview",
        "conferencepublicshell",
        "conferencesponsorshell",
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
        "devicecallbackbridge",
        "markdownrenderer",
        "mermaidrenderer"
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

    nonisolated struct RemoteRequesterDescriptor: Hashable {
        let identityContext: String
        let displayName: String
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
    @State private var legacyPortholeViewModel = PortholeViewModel()
    @StateObject private var editorState = EditorState()
    @StateObject private var bridgeStatusStore = BridgeConnectionStatusStore()
    @State private var floatingPanelsController = SkeletonEditorFloatingPanelsController()
    @AppStorage("edgeMenus.topExpansionStyle")
    private var edgeMenuTopExpansionStyleRaw = EdgeMenuExpansionStyle.auto.rawValue
    @AppStorage("edgeMenus.bottomExpansionStyle")
    private var edgeMenuBottomExpansionStyleRaw = EdgeMenuExpansionStyle.auto.rawValue
    @AppStorage("edgeMenus.showTitles")
    private var edgeMenuShowsTitles = true
    @AppStorage("binding.demoStartConfigurationJSON")
    private var demoStartConfigurationJSON = ""
    @State private var editorMode: EditorMode = .view
    @State private var menusHidden: Bool = false
    @State private var rotationAccumulator: Angle = .zero
    @State private var didApplyStoredDemoStart = false
    @State private var didRepairPersistedConferenceLauncher = false
    @State private var didRepairPersistedConferencePortal = false
    @State private var didRepairPersistedConferenceControlTower = false
    @State private var activeConfiguration: CellConfiguration?
    @State private var activeSourceBackedContext: EditorSourceBackedContext?
    @State private var presentingFullLibrary: Bool = false
    @State private var loadErrorMessage: String?
    @State private var isLoadingConfiguration = false
    @State private var loadingStatusMessage: String?
    @State private var topChromeHeight: CGFloat = 0
    @State private var topSafeAreaInset: CGFloat = 0
    @State private var activeLoadingRequestID: UUID?
    @State private var copyStatusMessage: String?
    @State private var catalogMenuPool: [CellConfiguration] = []
    @State private var lastPerspectiveMenuSignature: String = ""
    @State private var compactEditorDrawerVisible = false
    @State private var compactComponentsExpanded = true
    @State private var compactElementsExpanded = true
    @State private var compactInspectorExpanded = true
    @State private var componentCanvasDropTargeted = false
    @State private var configurationLoadTask: Task<Void, Never>?
    @State private var initialRuntimeBootstrapTask: Task<Void, Never>?
    @State private var conferenceNavigationStack: [CellConfiguration] = []
    @State private var hostingWindowNumber: Int?
    @StateObject private var componentPlacementState = ComponentPlacementState()
    @StateObject private var diagnosticsStore = BindingRuntimeDiagnostics.shared
    @State private var personalCopilotDestination: BindingPersonalCopilotDestination = .personalHome
    @State private var personalCopilotPhoneTab: BindingPersonalCopilotPhoneTab = .home

    private static let defaultRemoteRoute = RemoteCellHostRoute(
        websocketEndpoint: Self.defaultRemoteWebSocketPath,
        schemePreference: .automatic
    )
    private static let stagingRemoteRoute = RemoteCellHostRoute(
        websocketEndpoint: Self.stagingRemoteWebSocketPath,
        schemePreference: .wss,
        pathLayout: .endpointThenPublisherUUID
    )

    var body: some View {
        shellRoot
        .gesture(rotationHideShowGesture)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: TopSafeAreaInsetPreferenceKey.self, value: proxy.safeAreaInsets.top)
            }
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            topChrome
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: TopChromeHeightPreferenceKey.self, value: proxy.size.height)
                    }
                )
        }
        .overlay(alignment: .topLeading) {
#if os(macOS)
            EmptyView()
#else
            if editorMode == .edit && !usesCompactEditorChrome {
                VStack(alignment: .leading, spacing: 12) {
                    ComponentPalettePanel(
                        editorState: editorState,
                        placementState: componentPlacementState,
                        items: componentPaletteItems,
                        onArmComponent: { item in
                            armComponentPlacement(item)
                        },
                        onInsertError: { message in
                            loadErrorMessage = message
                        }
                    )
                    .frame(width: 340)

                    SkeletonTreePanel(editorState: editorState)
                }
                .padding(.leading, 12)
                .padding(.top, topChromeHeight + 12)
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
                    .padding(.top, topChromeHeight + 12)
            }
#endif
        }
        .overlay(alignment: .topTrailing) {
#if os(macOS)
            if diagnosticsStore.panelVisible {
                BindingDiagnosticsPanel(
                    diagnostics: diagnosticsStore,
                    bridgeStatus: bridgeStatusStore.primaryStatus,
                    onRefreshValidation: refreshDiagnosticsValidation,
                    runtimeIdentityTitle: runtimeIdentityTitle,
                    runtimeIdentitySubtitle: runtimeIdentitySubtitle,
                    onResetToDemoLauncher: resetToConferenceDemoLauncher
                )
                .padding(.trailing, 14)
                .padding(.top, topChromeHeight + 14)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
#else
            EmptyView()
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
                if let context = editorState.currentSourceBackedContext,
                   editorState.isDirty {
                    loadErrorMessage = editorState.sourceBackedChangeNotice ?? (context.canEdit
                        ? "Bruk \(editorApplyButtonTitle) for å lagre draften, eller Discard for å forkaste den, før du går tilbake til view-modus."
                        : context.readOnlyMessage)
                    editorMode = .edit
                    return
                }
                applyWorkingCopyToViewer()
                editorState.endEditing()
                compactEditorDrawerVisible = false
                componentPlacementState.clear()
            case .edit:
                if let context = activeSourceBackedContext,
                   !context.canEdit {
                    loadErrorMessage = context.readOnlyMessage
                    editorMode = .view
                    return
                }
                editorState.beginEditing(
                    configuration: currentEditorSeedConfiguration(),
                    sourceBackedContext: currentEditorSeedSourceBackedContext(),
                    fallbackSkeleton: viewModel.currentSkeleton
                )
                compactComponentsExpanded = true
                compactElementsExpanded = true
                compactInspectorExpanded = editorState.selectedNodePath != nil
                componentPlacementState.clear()
            }
            floatingPanelsController.setEditing(
                mode == .edit,
                editorState: editorState,
                componentsPanelRootView: componentsFloatingPanelRootView
            )
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
            floatingPanelsController.setEditing(
                editorMode == .edit,
                editorState: editorState,
                componentsPanelRootView: componentsFloatingPanelRootView
            )
        }
        .onDisappear {
            floatingPanelsController.closePanels()
            configurationLoadTask?.cancel()
        }
        .onReceive(viewModel.$currentSkeleton) { next in
            if !editorState.isEditing {
                editorState.captureViewerSnapshot(
                    currentEditorSeedConfiguration(),
                    sourceBackedContext: currentEditorSeedSourceBackedContext(),
                    fallbackSkeleton: next
                )
            }
        }
        .onChange(of: editorState.revision) { _, _ in
            refreshDiagnosticsValidation()
        }
        .onChange(of: activeConfiguration?.uuid) { _, _ in
            refreshDiagnosticsValidation()
        }
        .onChange(of: activeConfiguration?.name) { _, nextName in
            guard let destination = BindingPersonalCopilotDestination.matching(configurationName: nextName) else {
                return
            }
            personalCopilotDestination = destination
            personalCopilotPhoneTab = destination.phoneTab
        }
        .onChange(of: editorMode) { _, _ in
            refreshDiagnosticsValidation()
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: ConfigurationCatalogPreviewBridge.notificationName)
                .compactMap(ConfigurationCatalogPreviewBridge.configuration)
        ) { configuration in
            editorMode = .edit
            queueConfigurationLoad(configuration)
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: BindingPortholeLoadBridge.notificationName)
                .compactMap(BindingPortholeLoadBridge.configuration)
        ) { configuration in
            if editorMode == .edit {
                editorMode = .view
            }
            queueConfigurationLoad(configuration)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: BindingConferenceNavigationBridge.notificationName)
        ) { notification in
            guard BindingConferenceNavigationBridge.isPopRequest(notification) else { return }
            popConferenceNavigation(
                fallbackConfiguration: BindingConferenceNavigationBridge.fallbackConfiguration(from: notification)
            )
        }
        .onReceive(
            NotificationCenter.default.publisher(for: BindingIncomingURLBridge.notificationName)
        ) { notification in
            guard let url = BindingIncomingURLBridge.url(from: notification) else { return }
            handleIncomingURL(
                url,
                targetWindowNumber: BindingIncomingURLBridge.targetWindowNumber(from: notification)
            )
        }
        .onReceive(
            NotificationCenter.default.publisher(for: BindingConferenceAutomationBridge.notificationName)
        ) { notification in
            guard let hook = BindingConferenceAutomationBridge.hook(from: notification) else { return }
            handleConferenceAutomationNotification(
                hook,
                targetWindowNumber: BindingConferenceAutomationBridge.targetWindowNumber(from: notification)
            )
        }
#if os(iOS)
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
        ) { _ in
            handleMemoryWarning()
        }
#endif
        .onPreferenceChange(TopChromeHeightPreferenceKey.self) { topChromeHeight in
            self.topChromeHeight = topChromeHeight
        }
        .onPreferenceChange(TopSafeAreaInsetPreferenceKey.self) { topSafeAreaInset in
            self.topSafeAreaInset = topSafeAreaInset
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
                    queueConfigurationLoad(configuration)
                },
                onSetDemoStartConfiguration: { configuration in
                    storeDemoStartConfiguration(configuration)
                    editorMode = .view
                    queueConfigurationLoad(configuration, navigationMode: .reset)
                    presentingFullLibrary = false
                },
                onAddComponent: { item in
                    let inserted = applyComponentPaletteItem(item)
                    if !inserted {
                        loadErrorMessage = "Ingen gyldig drop-target for \(item.title.lowercased()) i valgt kontekst."
                    }
                    return inserted
                },
                armedComponentID: componentPlacementState.armedItem?.id,
                onArmComponent: { item in
                    armComponentPlacement(item)
                },
                onComponentDragStateChange: { item in
                    componentPlacementState.activeDragItem = item
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
        .sheet(isPresented: compactDiagnosticsSheetBinding) {
#if os(macOS)
            EmptyView()
#else
            NavigationStack {
                ScrollView {
                    BindingDiagnosticsPanel(
                        diagnostics: diagnosticsStore,
                        bridgeStatus: bridgeStatusStore.primaryStatus,
                        onRefreshValidation: refreshDiagnosticsValidation,
                        runtimeIdentityTitle: runtimeIdentityTitle,
                        runtimeIdentitySubtitle: runtimeIdentitySubtitle,
                        onResetToDemoLauncher: resetToConferenceDemoLauncher
                    )
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .navigationTitle("Debug")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
#endif
        }
        .task {
            diagnosticsStore.configureIfNeeded()
            let fallbackMenus = curatedMenuSeedConfigurations()
            if usesPerspectiveDrivenEdgeMenus {
                applyPerspectiveDrivenMenus(from: [], fallback: fallbackMenus, profile: .empty)
            } else {
                applyFixedMenuPlacement(fallbackMenus)
            }
            editorState.captureViewerSnapshot(
                currentEditorSeedConfiguration(),
                sourceBackedContext: currentEditorSeedSourceBackedContext(),
                fallbackSkeleton: viewModel.currentSkeleton
            )
            refreshDiagnosticsValidation()
            startInitialRuntimeBootstrapIfNeeded()
        }
        .task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                ensureDefaultDemoStartVisibleIfNeeded(reason: "independent startup watchdog")
            }
        }
        .task {
            await monitorPerspectiveDrivenMenus()
        }
        .environmentObject(legacyPortholeViewModel)
    }

    @ViewBuilder
    private var shellRoot: some View {
        if usesPersonalCopilotShell {
            personalCopilotShell
        } else {
            legacyShell
        }
    }

    private var usesPersonalCopilotShell: Bool {
        guard BindingPersonalCopilotV1Policy.appStoreCatalogGateEnabled,
              editorMode == .view else {
            return false
        }
        guard let activeConfiguration else { return true }
        return BindingPersonalCopilotV1Policy.isAllowedInPersonalCopilotV1(activeConfiguration)
    }

    private var showsPersonalCopilotInspector: Bool {
#if os(iOS)
        horizontalSizeClass != .compact
#else
        true
#endif
    }

    private var portholeCanvas: some View {
        PortholeCanvas(
            skeleton: renderedSkeleton,
            isEditing: editorMode == .edit,
            activeConfigurationName: activeConfiguration?.name,
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
                componentPlacementState.armedItem = nil
            },
            onApplyComponentDrop: { item, placement in
                let inserted = applyComponentPaletteItem(item, placement: placement)
                if !inserted {
                    loadErrorMessage = "Kunne ikke sette inn \(item.title.lowercased()) på valgt punkt."
                }
                return inserted
            }
        )
#if canImport(AppKit)
        .background(
            BindingHostingWindowReader { window in
                let nextWindowNumber = window?.windowNumber
                if hostingWindowNumber != nextWindowNumber {
                    hostingWindowNumber = nextWindowNumber
                }
            }
        )
#endif
        .environmentObject(viewModel)
        .dropDestination(for: CellConfiguration.self) { items, location in
            queueConfigurationLoad(items.first)
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
    }

    private var legacyShell: some View {
        ZStack {
            portholeCanvas
                .ignoresSafeArea(.container, edges: [.leading, .trailing, .bottom])

            if !usesCompactConvenienceMenus && !menusHidden {
                EdgeMenusOverlay(
                    upperLeft: menuItems(from: viewModel.upperLeftMenu),
                    upperMid: menuItems(from: viewModel.upperMidMenu),
                    upperRight: menuItems(from: viewModel.upperRightMenu),
                    lowerLeft: menuItems(from: viewModel.lowerLeftMenu),
                    lowerMid: menuItems(from: viewModel.lowerMidMenu),
                    lowerRight: menuItems(from: viewModel.lowerRightMenu),
                    reservedTopInset: max(0, topSafeAreaInset + topChromeHeight + 2),
                    topExpansionStyle: edgeMenuTopExpansionStyle,
                    bottomExpansionStyle: edgeMenuBottomExpansionStyle,
                    labelMode: edgeMenuLabelMode,
                    onPrimaryAction: { position in
                        guard position == .upperMid else { return false }
                        presentingFullLibrary = true
                        return true
                    },
                    onSelect: { config in
                        queueConfigurationLoad(config)
                    }
                )
                .allowsHitTesting(true)
                .ignoresSafeArea(.container, edges: [.top, .leading, .trailing, .bottom])
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
    }

    @ViewBuilder
    private var personalCopilotShell: some View {
#if os(iOS)
        if usesCompactEditorChrome {
            personalCopilotPhoneShell
        } else {
            personalCopilotSplitShell
        }
#else
        personalCopilotSplitShell
#endif
    }

    private var personalCopilotPhoneShell: some View {
        TabView(
            selection: Binding(
                get: { personalCopilotPhoneTab },
                set: { selectPersonalCopilotPhoneTab($0) }
            )
        ) {
            ForEach(BindingPersonalCopilotDestination.phonePrimaryTabs) { tab in
                personalCopilotDetailContainer(
                    for: personalCopilotDestination.phoneTab == tab ? personalCopilotDestination : .defaultDestination(for: tab),
                    showInspector: false,
                    isActive: personalCopilotPhoneTab == tab
                )
                .tag(tab)
                .tabItem {
                    Label(tab.title, systemImage: tab.systemImage)
                }
            }
        }
        .padding(.top, personalCopilotShellTopPadding)
        .background(personalCopilotShellBackground)
    }

    private var personalCopilotSplitShell: some View {
        NavigationSplitView {
            personalCopilotSidebar
        } detail: {
            personalCopilotDetailContainer(
                for: personalCopilotDestination,
                showInspector: showsPersonalCopilotInspector,
                isActive: true
            )
        }
        .padding(.top, personalCopilotShellTopPadding)
        .background(personalCopilotShellBackground)
    }

    private var personalCopilotSidebar: some View {
        List {
            ForEach(BindingPersonalCopilotDestination.sidebarSections, id: \.title) { section in
                personalCopilotSidebarSection(section)
            }
        }
        .scrollContentBackground(.hidden)
        .background(personalCopilotPlatformSurfaceColor)
        .navigationTitle("Binding")
    }

    private func personalCopilotSidebarSection(
        _ section: (title: String, destinations: [BindingPersonalCopilotDestination])
    ) -> some View {
        Section(section.title) {
            ForEach(section.destinations) { destination in
                personalCopilotSidebarRow(for: destination)
            }
        }
    }

    private func personalCopilotSidebarRow(for destination: BindingPersonalCopilotDestination) -> some View {
        let isSelected = personalCopilotDestination == destination
        let iconTint = isSelected
            ? (Color(bindingHex: BindingPersonalCopilotDesignSystem.brandPrimary) ?? .accentColor)
            : .primary

        return Button {
            selectPersonalCopilotDestination(destination)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: destination.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconTint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(destination.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(destination.configuration.description ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var personalCopilotShellBackground: some View {
        ZStack {
            Color(bindingHex: BindingPersonalCopilotDesignSystem.canvas) ?? personalCopilotPlatformCanvasColor
            LinearGradient(
                colors: [
                    (Color(bindingHex: BindingPersonalCopilotDesignSystem.brandSubtle) ?? .clear).opacity(0.45),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill((Color(bindingHex: BindingPersonalCopilotDesignSystem.brandSubtle) ?? .clear).opacity(0.35))
                .frame(width: 220, height: 220)
                .offset(x: 160, y: -120)
        }
        .ignoresSafeArea()
    }

    private func personalCopilotDetailContainer(
        for destination: BindingPersonalCopilotDestination,
        showInspector: Bool,
        isActive: Bool
    ) -> some View {
        let configuration = personalCopilotVisibleConfiguration(for: destination)
        let metadata = BindingPersonalCopilotSurfaceMetadata(configuration: configuration)
        let showsSurfaceHeader = shouldShowPersonalCopilotSurfaceHeader(configuration: configuration)

        return ZStack {
            personalCopilotShellBackground
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 18) {
                    if showsSurfaceHeader {
                        personalCopilotSurfaceHeader(configuration: configuration, metadata: metadata)
                    }
                    portholeCanvas
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(Color(bindingHex: BindingPersonalCopilotDesignSystem.surface) ?? .white)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(
                                    Color(bindingHex: BindingPersonalCopilotDesignSystem.border) ?? .gray.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                }
                .frame(maxWidth: personalCopilotContentMaxWidth(for: metadata), maxHeight: .infinity, alignment: .top)
                .frame(maxWidth: .infinity, alignment: .center)

                if showInspector {
                    personalCopilotInspector(metadata: metadata)
                        .frame(width: 220)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .task(id: destination.id) {
            guard isActive else { return }
            if activeConfigurationIsAdHocPersonalCopilotSurface {
                return
            }
            guard activeConfiguration?.name != destination.title else { return }
            queueConfigurationLoad(destination.configuration, navigationMode: .reset)
        }
    }

    private func personalCopilotVisibleConfiguration(
        for destination: BindingPersonalCopilotDestination
    ) -> CellConfiguration {
        guard let activeConfiguration,
              BindingPersonalCopilotV1Policy.isAllowedInPersonalCopilotV1(activeConfiguration)
        else {
            return destination.configuration
        }
        if activeConfiguration.name == destination.title {
            return activeConfiguration
        }
        if BindingPersonalCopilotDestination.matching(configurationName: activeConfiguration.name) == nil {
            return activeConfiguration
        }
        return destination.configuration
    }

    private var activeConfigurationIsAdHocPersonalCopilotSurface: Bool {
        guard let activeConfiguration,
              BindingPersonalCopilotV1Policy.isAllowedInPersonalCopilotV1(activeConfiguration)
        else {
            return false
        }
        return BindingPersonalCopilotDestination.matching(configurationName: activeConfiguration.name) == nil
    }

    private func shouldShowPersonalCopilotSurfaceHeader(configuration: CellConfiguration) -> Bool {
        guard let skeleton = configuration.skeleton else {
            return true
        }
        if skeletonHasLeadingStaticTitle(configuration.name, in: skeleton) {
            return false
        }
        return true
    }

    private func skeletonHasLeadingStaticTitle(_ title: String, in element: SkeletonElement) -> Bool {
        let target = normalizedPersonalCopilotTitle(title)
        guard !target.isEmpty else { return false }
        return leadingStaticSkeletonText(in: element, maxDepth: 5, limit: 10)
            .map(normalizedPersonalCopilotTitle)
            .contains(target)
    }

    private func leadingStaticSkeletonText(
        in element: SkeletonElement,
        maxDepth: Int,
        limit: Int
    ) -> [String] {
        guard maxDepth >= 0, limit > 0 else { return [] }
        switch element {
        case .Text(let text):
            guard let value = text.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { return [] }
            return [value]
        case .ScrollView(let scrollView):
            return leadingStaticSkeletonText(in: scrollView.elements, maxDepth: maxDepth - 1, limit: limit)
        case .VStack(let stack):
            return leadingStaticSkeletonText(in: stack.elements, maxDepth: maxDepth - 1, limit: limit)
        case .HStack(let stack):
            return leadingStaticSkeletonText(in: stack.elements, maxDepth: maxDepth - 1, limit: limit)
        case .ZStack(let stack):
            return leadingStaticSkeletonText(in: stack.elements, maxDepth: maxDepth - 1, limit: limit)
        case .Section(let section):
            var elements: [SkeletonElement] = []
            if let header = section.header {
                elements.append(header)
            }
            elements.append(contentsOf: section.content)
            if let footer = section.footer {
                elements.append(footer)
            }
            return leadingStaticSkeletonText(in: elements, maxDepth: maxDepth - 1, limit: limit)
        case .Object(let object):
            let elements = object.elements.keys.sorted().compactMap { object.elements[$0] }
            return leadingStaticSkeletonText(in: elements, maxDepth: maxDepth - 1, limit: limit)
        case .Grid(let grid):
            var elements = grid.elements
            if let itemSkeleton = grid.itemSkeleton {
                elements.append(itemSkeleton)
            }
            return leadingStaticSkeletonText(in: elements, maxDepth: maxDepth - 1, limit: limit)
        default:
            return []
        }
    }

    private func leadingStaticSkeletonText(
        in elements: [SkeletonElement],
        maxDepth: Int,
        limit: Int
    ) -> [String] {
        var output: [String] = []
        for element in elements {
            output.append(contentsOf: leadingStaticSkeletonText(
                in: element,
                maxDepth: maxDepth,
                limit: limit - output.count
            ))
            if output.count >= limit {
                return Array(output.prefix(limit))
            }
        }
        return output
    }

    private func normalizedPersonalCopilotTitle(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    private func personalCopilotSurfaceHeader(
        configuration: CellConfiguration,
        metadata: BindingPersonalCopilotSurfaceMetadata
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(configuration.name)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color(bindingHex: BindingPersonalCopilotDesignSystem.textPrimary) ?? .primary)
                    Text(configuration.discovery?.purposeDescription ?? configuration.description ?? "")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color(bindingHex: BindingPersonalCopilotDesignSystem.textSecondary) ?? .secondary)
                        .lineLimit(3)
                }
                Spacer(minLength: 12)
                personalCopilotBadge(metadata.sourceKind.badgeTitle, tint: badgeTint(for: metadata.sourceKind))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let surfaceFamily = metadata.surfaceFamily {
                        personalCopilotBadge(surfaceFamily.uppercased(), tint: Color(bindingHex: BindingPersonalCopilotDesignSystem.brandPrimary) ?? .accentColor)
                    }
                    if let presentationClass = metadata.presentationClass {
                        personalCopilotBadge(presentationClass.uppercased(), tint: Color(bindingHex: BindingPersonalCopilotDesignSystem.borderStrong) ?? .gray)
                    }
                    if metadata.requiresModeration {
                        personalCopilotBadge("MODERATED", tint: Color(bindingHex: BindingPersonalCopilotDesignSystem.warning) ?? .orange)
                    }
                    if let gate = metadata.permissionGateSummary, !gate.isEmpty {
                        personalCopilotBadge("GATED", tint: Color(bindingHex: BindingPersonalCopilotDesignSystem.success) ?? .green)
                    }
                }
            }

            if let reviewSummary = metadata.reviewSummary, !reviewSummary.isEmpty {
                Text(reviewSummary)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(bindingHex: BindingPersonalCopilotDesignSystem.textTertiary) ?? .secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(Color(bindingHex: BindingPersonalCopilotDesignSystem.brandSubtle) ?? .secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(bindingHex: BindingPersonalCopilotDesignSystem.brandPrimary) ?? .accentColor, lineWidth: 1)
        )
    }

    private func personalCopilotInspector(metadata: BindingPersonalCopilotSurfaceMetadata) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Context")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(bindingHex: BindingPersonalCopilotDesignSystem.textPrimary) ?? .primary)

            personalCopilotInspectorRow(title: "Policy", value: metadata.policyCategory ?? "Undeclared")
            personalCopilotInspectorRow(title: "Source", value: metadata.sourceEndpoint ?? "No source endpoint")
            personalCopilotInspectorRow(title: "Login", value: metadata.requiresLogin ? "Required" : "Optional")
            personalCopilotInspectorRow(title: "Moderation", value: metadata.requiresModeration ? "Required" : "Not declared")
            personalCopilotInspectorRow(
                title: "Permissions",
                value: metadata.nativePermissionRequests.isEmpty
                    ? "No native permissions by default"
                    : metadata.nativePermissionRequests.joined(separator: ", ")
            )
            if let universalLink = metadata.universalLink {
                personalCopilotInspectorRow(title: "Universal link", value: universalLink)
            }
        }
        .padding(16)
        .background(Color(bindingHex: BindingPersonalCopilotDesignSystem.surfaceElevated) ?? .white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(bindingHex: BindingPersonalCopilotDesignSystem.border) ?? .gray.opacity(0.2), lineWidth: 1)
        )
    }

    private func personalCopilotInspectorRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(bindingHex: BindingPersonalCopilotDesignSystem.textTertiary) ?? .secondary)
            Text(value)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color(bindingHex: BindingPersonalCopilotDesignSystem.textPrimary) ?? .primary)
                .lineLimit(3)
        }
    }

    private func personalCopilotBadge(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color(bindingHex: BindingPersonalCopilotDesignSystem.textPrimary) ?? .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.55), lineWidth: 1)
            )
    }

    private func badgeTint(for sourceKind: BindingPersonalCopilotSurfaceMetadata.SourceKind) -> Color {
        switch sourceKind {
        case .local:
            return Color(bindingHex: BindingPersonalCopilotDesignSystem.success) ?? .green
        case .remoteTrusted:
            return Color(bindingHex: BindingPersonalCopilotDesignSystem.brandPrimary) ?? .accentColor
        case .remoteUnapproved:
            return Color(bindingHex: BindingPersonalCopilotDesignSystem.danger) ?? .red
        }
    }

    private func personalCopilotContentMaxWidth(for metadata: BindingPersonalCopilotSurfaceMetadata) -> CGFloat {
        switch metadata.presentationClass {
        case "grid":
            return 980
        case "list":
            return 860
        case "hero":
            return 760
        case "form":
            return 760
        default:
            return 720
        }
    }

    private var personalCopilotPlatformCanvasColor: Color {
#if os(iOS)
        Color(uiColor: .systemGroupedBackground)
#else
        Color(nsColor: .windowBackgroundColor)
#endif
    }

    private var personalCopilotPlatformSurfaceColor: Color {
#if os(iOS)
        Color(uiColor: .systemBackground)
#else
        Color(nsColor: .controlBackgroundColor)
#endif
    }

    private var personalCopilotShellTopPadding: CGFloat {
#if os(iOS)
        horizontalSizeClass == .compact ? 8 : 12
#else
        12
#endif
    }

    private func selectPersonalCopilotDestination(_ destination: BindingPersonalCopilotDestination) {
        personalCopilotDestination = destination
        personalCopilotPhoneTab = destination.phoneTab
        guard activeConfiguration?.name != destination.title else { return }
        queueConfigurationLoad(destination.configuration, navigationMode: .reset)
    }

    private func selectPersonalCopilotPhoneTab(_ tab: BindingPersonalCopilotPhoneTab) {
        personalCopilotPhoneTab = tab
        guard personalCopilotDestination.phoneTab != tab else { return }
        selectPersonalCopilotDestination(.defaultDestination(for: tab))
    }

    @ViewBuilder
    private var topChrome: some View {
        VStack(spacing: 6) {
            if usesPersonalCopilotShell {
                personalCopilotTopChrome
            } else {
                appToolbar
            }
            if isLoadingConfiguration, let loadingStatusMessage {
                LoadingStatusBanner(message: loadingStatusMessage)
            }
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
            if let sourceBackedStatus = sourceBackedStatusMessage {
                HStack(spacing: 8) {
                    Image(systemName: sourceBackedStatus.systemImage)
                        .foregroundColor(sourceBackedStatus.tint)
                    Text(sourceBackedStatus.message)
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
            if let bridgeStatus = bridgeStatusStore.primaryStatus, !usesPersonalCopilotShell {
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
            if !usesPersonalCopilotShell && usesCompactConvenienceMenus {
                compactConvenienceTray
            }
        }
    }

    private var personalCopilotTopChrome: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Binding")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color(bindingHex: BindingPersonalCopilotDesignSystem.textPrimary) ?? .primary)
                Text("Personal Co-Pilot")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(bindingHex: BindingPersonalCopilotDesignSystem.textSecondary) ?? .secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Menu {
                ForEach(BindingPersonalCopilotDestination.destinations(for: personalCopilotPhoneTab)) { destination in
                    Button {
                        selectPersonalCopilotDestination(destination)
                    } label: {
                        Label(destination.title, systemImage: destination.systemImage)
                    }
                }
            } label: {
                Label("Surfaces", systemImage: "square.grid.2x2")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                presentingFullLibrary = true
            } label: {
                Label("Library", systemImage: "books.vertical")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Menu {
                Button {
                    copyLoadedConfigurationJSONToClipboard()
                } label: {
                    Label("Copy JSON", systemImage: "doc.on.doc")
                }

                Button {
                    editorMode = .edit
                } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                }

                Button {
                    diagnosticsStore.panelVisible.toggle()
                } label: {
                    Label("Debug", systemImage: diagnosticsStore.panelVisible ? "ladybug.fill" : "ladybug")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @MainActor
    private func startInitialRuntimeBootstrapIfNeeded() {
        guard initialRuntimeBootstrapTask == nil else { return }

        initialRuntimeBootstrapTask = Task { @MainActor in
            applyStoredDemoStartConfigurationIfNeeded()
            editorState.captureViewerSnapshot(
                currentEditorSeedConfiguration(),
                sourceBackedContext: currentEditorSeedSourceBackedContext(),
                fallbackSkeleton: viewModel.currentSkeleton
            )
            refreshDiagnosticsValidation()
            ensureDefaultDemoStartVisibleIfNeeded(reason: "post-bootstrap")

            let startupConfiguration = activeConfiguration
                ?? Self.effectiveDemoStartConfiguration(
                    storedConfiguration: decodeStoredDemoStartConfiguration()
                )

            if shouldLoadWithoutAuthenticatedRuntimeBootstrap(startupConfiguration) {
                await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
                await repairPersistedConferenceLauncherIfNeeded()
                await repairPersistedConferencePortalIfNeeded()
                await repairPersistedConferenceControlTowerIfNeeded()
                diagnosticsStore.record(
                    domain: "binding.demo",
                    message: "Utsetter runtime-bootstrap til brukeren åpner en conference-flate som faktisk trenger identitet, resolver eller bridge."
                )
                return
            }

            if BindingRuntimeBootstrap.shouldUseLocalRuntimeOnlyForVerifier() {
                await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
            } else {
                await AppInitializer.initialize()
            }
            await BindingLocalCellRegistration.shared.ensureRegistered()
            await repairPersistedConferencePortalIfNeeded()
            await repairPersistedConferenceControlTowerIfNeeded()
            await viewModel.connectIfNeeded()
            editorState.captureViewerSnapshot(
                currentEditorSeedConfiguration(),
                sourceBackedContext: currentEditorSeedSourceBackedContext(),
                fallbackSkeleton: viewModel.currentSkeleton
            )
            refreshDiagnosticsValidation()

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                ensureDefaultDemoStartVisibleIfNeeded(reason: "bootstrap watchdog")
            }
        }
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
        await BindingLocalCellRegistration.shared.ensureRegistered()
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

            guard let catalog = try? await RemoteEndpointAccessSupport.resolveMeddle(
                endpoint: source.endpoint,
                resolver: resolver,
                requester: identity,
                accessLabel: "binding.catalogMenus"
            )
            else {
                continue
            }

            if source.allowSync && RemoteCatalogSupport.shouldSyncCatalogBeforeQuery(for: source.endpoint) {
                _ = try? await catalog.set(keypath: "syncScaffoldPurposeGoals", value: .object([:]), requester: identity)
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
            guard RemoteCatalogSupport.shouldEagerlyRecoverMenuEndpoint(endpoint) else { continue }
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
            guard runtimeBootstrapIsReady else {
                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                } catch {
                    return
                }
                continue
            }

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
        var normalized = BindingConferenceConfigurationRepair.reconcile(configuration)
        normalized = CellConfigurationEndpointRetargeting.rewritingEndpoints(in: normalized) { endpoint in
            normalizeEndpointForResolver(endpoint, origin: origin, resolver: resolver)
        }
        normalized = ensureCatalogReferenceBindingIfNeeded(normalized, origin: origin, resolver: resolver)
        normalized = canonicalizeSkeletonReferencesIfNeeded(in: normalized)
        normalized = stabilizeKnownConferenceConfigurationIfNeeded(normalized)
        registerRemoteRoutesIfNeeded(for: normalized, resolver: resolver)
        return ConfigurationPresentationSupport.viewportSafeConfiguration(normalized)
    }

    func registerRemoteRoutesIfNeeded(for configuration: CellConfiguration, resolver: CellResolver) {
        for endpoint in remoteRegistrationEndpoints(in: configuration) {
            RemoteEndpointAccessSupport.registerRemoteRouteIfNeeded(for: endpoint, resolver: resolver)
        }
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

    private func stabilizeKnownConferenceConfigurationIfNeeded(_ configuration: CellConfiguration) -> CellConfiguration {
        guard let skeleton = configuration.skeleton else {
            return configuration
        }

        let keypathRewrites = knownConferenceKeypathRewrites(for: configuration)
        guard !keypathRewrites.isEmpty,
              let rewrittenSkeleton = rewrittenSkeleton(skeleton, keypathRewrites: keypathRewrites)
        else {
            return configuration
        }

        var stabilized = configuration
        stabilized.skeleton = rewrittenSkeleton
        return stabilized
    }

    private func knownConferenceKeypathRewrites(for configuration: CellConfiguration) -> [String: String] {
        let normalizedName = configuration.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalizedName {
        case "conference participant portal dashboard", "conference ai assistant":
            return [
                "conferenceParticipantShell.state.program.trackSummary": "conferenceParticipantShell.state.program.timelineSummary"
            ]
        default:
            return [:]
        }
    }

    private func rewrittenSkeleton(
        _ skeleton: SkeletonElement,
        keypathRewrites: [String: String]
    ) -> SkeletonElement? {
        guard let data = try? JSONEncoder().encode(skeleton),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let rewrittenObject = rewrittenSkeletonJSONValue(jsonObject, keypathRewrites: keypathRewrites),
              JSONSerialization.isValidJSONObject(rewrittenObject),
              let rewrittenData = try? JSONSerialization.data(withJSONObject: rewrittenObject),
              let rewrittenSkeleton = try? JSONDecoder().decode(SkeletonElement.self, from: rewrittenData)
        else {
            return nil
        }

        return rewrittenSkeleton
    }

    private func rewrittenSkeletonJSONValue(
        _ value: Any,
        keypathRewrites: [String: String]
    ) -> Any? {
        switch value {
        case let dictionary as [String: Any]:
            var rewritten: [String: Any] = [:]
            rewritten.reserveCapacity(dictionary.count)
            for (key, childValue) in dictionary {
                rewritten[key] = rewrittenSkeletonJSONValue(childValue, keypathRewrites: keypathRewrites) ?? childValue
            }
            for key in ["keypath", "sourceKeypath", "targetKeypath"] {
                guard let current = rewritten[key] as? String,
                      let replacement = keypathRewrites[current]
                else {
                    continue
                }
                rewritten[key] = replacement
            }
            return rewritten
        case let array as [Any]:
            return array.map { rewrittenSkeletonJSONValue($0, keypathRewrites: keypathRewrites) ?? $0 }
        default:
            return value
        }
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

    private var displayedSourceBackedContext: EditorSourceBackedContext? {
        if editorMode == .edit {
            return editorState.currentSourceBackedContext ?? activeSourceBackedContext
        }
        return activeSourceBackedContext
    }

    private var editorApplyButtonTitle: String {
        guard let context = editorState.currentSourceBackedContext else {
            return "Apply"
        }
        return context.canEdit ? "Apply to source" : "Read-only"
    }

    private var editorApplyButtonDisabled: Bool {
        guard editorState.workingCopy != nil else { return true }
        if editorState.sourceBackedChangeNotice != nil {
            return true
        }
        if let context = editorState.currentSourceBackedContext {
            return !context.canEdit
        }
        return false
    }

    private var sourceBackedStatusMessage: (systemImage: String, tint: Color, message: String)? {
        guard let context = displayedSourceBackedContext else { return nil }

        if let notice = editorState.sourceBackedChangeNotice {
            return (
                systemImage: "exclamationmark.triangle.fill",
                tint: .orange,
                message: notice
            )
        }

        if !context.canEdit {
            return (
                systemImage: "lock.fill",
                tint: .orange,
                message: context.readOnlyMessage
            )
        }

        let sourceLabel = context.sourceCellName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? context.sourceCellEndpoint
            : context.sourceCellName

        if editorMode == .edit {
            return (
                systemImage: "square.and.pencil",
                tint: .accentColor,
                message: "Source-backed konfigurasjon. Endringer ligger som lokal draft i Porthole til du trykker \(editorApplyButtonTitle) for å skrive tilbake til \(sourceLabel)."
            )
        }

        return (
            systemImage: "square.and.pencil",
            tint: .accentColor,
            message: "Source-backed konfigurasjon. Gå til Edit for å lage en lokal draft; \(editorApplyButtonTitle) skriver tilbake til \(sourceLabel)."
        )
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

    private var compactDiagnosticsSheetBinding: Binding<Bool> {
        Binding(
            get: { usesCompactEditorChrome && diagnosticsStore.panelVisible },
            set: { diagnosticsStore.panelVisible = $0 }
        )
    }

    private var edgeMenuTopExpansionStyle: EdgeMenuExpansionStyle {
        get { EdgeMenuExpansionStyle(rawValue: edgeMenuTopExpansionStyleRaw) ?? .auto }
        nonmutating set { edgeMenuTopExpansionStyleRaw = newValue.rawValue }
    }

    private var edgeMenuBottomExpansionStyle: EdgeMenuExpansionStyle {
        get { EdgeMenuExpansionStyle(rawValue: edgeMenuBottomExpansionStyleRaw) ?? .auto }
        nonmutating set { edgeMenuBottomExpansionStyleRaw = newValue.rawValue }
    }

    private var edgeMenuLabelMode: EdgeMenuLabelMode {
        edgeMenuShowsTitles ? .titleOnOpen : .iconOnly
    }

    private var appToolbar: some View {
        appToolbarContent
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var appToolbarContent: some View {
        if usesCompactEditorChrome {
            compactAppToolbar
        } else {
            regularAppToolbar
        }
    }

    private var regularAppToolbar: some View {
        HStack(spacing: 10) {
            if canPopConferenceNavigation {
                Button {
                    popConferenceNavigation()
                } label: {
                    Label(conferenceNavigationBackLabel, systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Gå tilbake i conference-demo-stacken")
            }

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

            if isLoadingConfiguration {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(loadingStatusMessage ?? "Laster…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: 220, alignment: .leading)
            }

            runtimeIdentityBadge

            if showsConferenceAutomationControls {
                conferenceAutomationToolbarItem
            }

            if showsConferenceParticipantQuickActions {
                conferenceParticipantQuickActions
            }

            Spacer(minLength: 8)

            Menu {
                convenienceMenuSettingsControls
            } label: {
                Label("Menus", systemImage: "menucard")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                diagnosticsStore.panelVisible.toggle()
            } label: {
                Label("Debug", systemImage: diagnosticsStore.panelVisible ? "ladybug.fill" : "ladybug")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

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
                    Button(editorApplyButtonTitle) {
                        applyWorkingCopyToViewer()
                    }
                    .disabled(editorApplyButtonDisabled)
                }
                .font(.caption)
            }
        }
    }

    private var compactAppToolbar: some View {
        HStack(spacing: 8) {
            if canPopConferenceNavigation {
                Button {
                    popConferenceNavigation()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel(conferenceNavigationBackLabel)
            }

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

            if isLoadingConfiguration {
                ProgressView()
                    .controlSize(.small)
            }

            if showsConferenceAutomationControls {
                conferenceAutomationToolbarItem
            }

            Picker("Mode", selection: $editorMode) {
                ForEach(EditorMode.allCases) { mode in
                    Image(systemName: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Button {
                diagnosticsStore.panelVisible.toggle()
            } label: {
                Image(systemName: diagnosticsStore.panelVisible ? "ladybug.fill" : "ladybug")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Debug")

            Menu {
                convenienceMenuSettingsControls
            } label: {
                Image(systemName: "menucard")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Menu settings")

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
                    Button(editorApplyButtonTitle) {
                        applyWorkingCopyToViewer()
                    }
                    .disabled(editorApplyButtonDisabled)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Editor actions")
            }
        }
    }

    @ViewBuilder
    private var convenienceMenuSettingsControls: some View {
        Picker("Top menus", selection: $edgeMenuTopExpansionStyleRaw) {
            ForEach(EdgeMenuExpansionStyle.allCases) { style in
                Text(style.title).tag(style.rawValue)
            }
        }

        Picker("Bottom menus", selection: $edgeMenuBottomExpansionStyleRaw) {
            ForEach(EdgeMenuExpansionStyle.allCases) { style in
                Text(style.title).tag(style.rawValue)
            }
        }

        Divider()

        Toggle("Show names in open menus", isOn: $edgeMenuShowsTitles)

        Divider()

        Button("Reset til Conference Demo Launcher") {
            resetToConferenceDemoLauncher()
        }
    }

    private var showsConferenceAutomationControls: Bool {
        conferenceAutomationOptInEnabled && isConferenceNavigationEligible(activeConfiguration)
    }

    private var showsConferenceParticipantQuickActions: Bool {
        conferenceAutomationOptInEnabled
            && normalizedActiveConferenceConfigurationName == "conference participant portal dashboard"
    }

    private var conferenceAutomationOptInEnabled: Bool {
        Self.conferenceAutomationEnabled(
            debugPanelVisible: diagnosticsStore.panelVisible,
            environment: ProcessInfo.processInfo.environment,
            launchArguments: ProcessInfo.processInfo.arguments,
            persistedOptIn: UserDefaults.standard.bool(forKey: Self.conferenceAutomationDefaultsKey)
        )
    }

    private var normalizedActiveConferenceConfigurationName: String? {
        activeConfiguration?.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private var conferenceAutomationToolbarItem: some View {
        Menu {
            conferenceAutomationMenuContent
        } label: {
            Label("Automation", systemImage: "switch.2")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel("Conference automation")
        .accessibilityIdentifier("conference-automation-menu")
        .help("Debug-only conference hooks for GUI automation and deterministic demo navigation.")
    }

    private var conferenceParticipantQuickActions: some View {
        HStack(spacing: 8) {
            Button("Ane Solberg") {
                runConferenceAutomation(.focusAneSolberg)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Focus Ane Solberg")
            .accessibilityIdentifier("conference-focus-ane-solberg")
            .help("Fokuser Ane Solberg uten å måtte scrolle til recommendation-kortene.")

            Button("Start chat") {
                runConferenceAutomation(.startChatWithFocusedParticipant)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Start chat with focused participant")
            .accessibilityIdentifier("conference-start-chat")
            .help("Starter chat med valgt conference-deltaker fra native toolbar.")

            Button("Åpne chat") {
                runConferenceAutomation(.openFocusedChatWorkbench)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityLabel("Open focused chat workbench")
            .accessibilityIdentifier("conference-open-chat")
            .help("Åpner chatflaten for valgt deltaker uten å måtte finne knappen i scrollflaten.")
        }
    }

    @ViewBuilder
    private var conferenceAutomationMenuContent: some View {
        Button(ConferenceAutomationHook.openLauncher.title) {
            runConferenceAutomation(.openLauncher)
        }
        Button(ConferenceAutomationHook.openParticipantPortal.title) {
            runConferenceAutomation(.openParticipantPortal)
        }
        Button(ConferenceAutomationHook.openConferenceMVP.title) {
            runConferenceAutomation(.openConferenceMVP)
        }
        Button(ConferenceAutomationHook.openPublicSurface.title) {
            runConferenceAutomation(.openPublicSurface)
        }
        Button(ConferenceAutomationHook.openControlTower.title) {
            runConferenceAutomation(.openControlTower)
        }
        Button(ConferenceAutomationHook.openSponsorFollowUp.title) {
            runConferenceAutomation(.openSponsorFollowUp)
        }
        Button(ConferenceAutomationHook.openAIAssistant.title) {
            runConferenceAutomation(.openAIAssistant)
        }
        Button(ConferenceAutomationHook.logAIAssistantState.title) {
            runConferenceAutomation(.logAIAssistantState)
        }
        Button(ConferenceAutomationHook.openIdentityLink.title) {
            runConferenceAutomation(.openIdentityLink)
        }
        if BindingPersonalCopilotV1Policy.agentSetupWorkbenchEnabled {
            Button(ConferenceAutomationHook.openAgentSetupWorkbench.title) {
                runConferenceAutomation(.openAgentSetupWorkbench)
            }
            Button(ConferenceAutomationHook.installAgent.title) {
                runConferenceAutomation(.installAgent)
            }
            Button(ConferenceAutomationHook.startAgent.title) {
                runConferenceAutomation(.startAgent)
            }
            Button(ConferenceAutomationHook.connectAgent.title) {
                runConferenceAutomation(.connectAgent)
            }
            Button(ConferenceAutomationHook.queueAgentSafariReview.title) {
                runConferenceAutomation(.queueAgentSafariReview)
            }
            Button(ConferenceAutomationHook.approveAgentReview.title) {
                runConferenceAutomation(.approveAgentReview)
            }
            Button(ConferenceAutomationHook.stopAgent.title) {
                runConferenceAutomation(.stopAgent)
            }
        }

        Divider()

        Button(ConferenceAutomationHook.focusAneSolberg.title) {
            runConferenceAutomation(.focusAneSolberg)
        }
        Button(ConferenceAutomationHook.startChatWithFocusedParticipant.title) {
            runConferenceAutomation(.startChatWithFocusedParticipant)
        }
        Button(ConferenceAutomationHook.openFocusedChatWorkbench.title) {
            runConferenceAutomation(.openFocusedChatWorkbench)
        }

#if canImport(AppKit)
        Divider()

        Button(ConferenceAutomationHook.windowCompact.title) {
            runConferenceAutomation(.windowCompact)
        }
        Button(ConferenceAutomationHook.windowTall.title) {
            runConferenceAutomation(.windowTall)
        }
        Button(ConferenceAutomationHook.windowWide.title) {
            runConferenceAutomation(.windowWide)
        }
        Button(ConferenceAutomationHook.centerWindow.title) {
            runConferenceAutomation(.centerWindow)
        }
#endif
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
                            queueConfigurationLoad(configuration)
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

    private var compatibleComponentCount: Int {
        componentPaletteItems.filter { !editorState.dropTargets(for: $0.recipe).isEmpty }.count
    }

    private var workingNodeCount: Int {
        guard let workingCopy = editorState.workingCopy else { return 0 }
        return SkeletonTreeQueries.linearizedNodes(in: workingCopy).count
    }

    @MainActor
    private var selectedElementTitle: String? {
        guard let selectedElement = editorState.selectedElement else { return nil }
        return SkeletonTreeQueries.displayName(for: selectedElement)
    }

    private var compactEditorDrawerMaxHeight: CGFloat {
        420
    }

    private var activeComponentInsertionItem: ComponentPaletteItem? {
        componentPlacementState.activeInsertionItem
    }

    private var isComponentPlacementArmed: Bool {
        componentPlacementState.isPlacementArmed
    }

    private var activeComponentDropTargets: [DropTargetDescriptor] {
        guard editorMode == .edit, let activeComponentInsertionItem else { return [] }
        return editorState.dropTargets(for: activeComponentInsertionItem.recipe)
    }

    private var componentsFloatingPanelRootView: AnyView? {
#if os(macOS)
        AnyView(
            ComponentPalettePanel(
                editorState: editorState,
                placementState: componentPlacementState,
                items: componentPaletteItems,
                onArmComponent: { item in
                    armComponentPlacement(item)
                },
                onInsertError: { message in
                    loadErrorMessage = message
                }
            )
            .padding(10)
        )
#else
        nil
#endif
    }

    private var compactEditorDrawer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Capsule(style: .continuous)
                .fill(Color.secondary.opacity(0.28))
                .frame(width: 38, height: 5)
                .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Editor")
                        .font(.headline)
                    Text(editorState.selectedNodePath == nil ? "Velg et element for å styre hvor komponenter legges inn." : "Komponenter, elementer og Inspector ligger samlet her.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)

                if isComponentPlacementArmed {
                    Button("Avbryt plassering") {
                        componentPlacementState.clear()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

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

            if editorState.selectedNodePath != nil || isComponentPlacementArmed {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if let selectedElementTitle {
                            PanelBadge(text: selectedElementTitle, tint: .accentColor)
                        }
                        if editorState.selectedNodePath != nil {
                            PanelBadge(text: editorState.selectionSummary)
                        }
                        if isComponentPlacementArmed {
                            PanelBadge(text: "Plassering aktiv", tint: .accentColor)
                        }
                    }
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    DisclosureGroup(isExpanded: $compactComponentsExpanded) {
                        ComponentPalettePanel(
                            editorState: editorState,
                            placementState: componentPlacementState,
                            items: componentPaletteItems,
                            onArmComponent: { item in
                                armComponentPlacement(item)
                            },
                            onInsertError: { message in
                                loadErrorMessage = message
                            }
                        )
                        .padding(.top, 8)
                    } label: {
                        compactDrawerSectionLabel(
                            title: "Components",
                            badge: "\(compatibleComponentCount)",
                            tint: .accentColor
                        )
                    }

                    DisclosureGroup(isExpanded: $compactElementsExpanded) {
                        SkeletonTreePanel(
                            editorState: editorState,
                            preferredWidth: nil,
                            maximumHeight: nil,
                            showsBackground: false
                        )
                        .padding(.top, 8)
                    } label: {
                        compactDrawerSectionLabel(
                            title: "Elements",
                            badge: "\(workingNodeCount)"
                        )
                    }

                    DisclosureGroup(isExpanded: $compactInspectorExpanded) {
                        SkeletonModifierInspectorPanel(
                            editorState: editorState,
                            preferredWidth: nil,
                            maximumHeight: nil,
                            modifierListMaximumHeight: nil,
                            showsBackground: false
                        )
                        .padding(.top, 8)
                    } label: {
                        compactDrawerSectionLabel(
                            title: "Inspector",
                            badge: selectedElementTitle ?? "Velg",
                            tint: selectedElementTitle == nil ? .secondary : .accentColor
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxHeight: compactEditorDrawerMaxHeight)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func applyWorkingCopyToViewer() {
        guard let workingDocument = editorState.currentWorkingDocument else { return }
        if let notice = editorState.sourceBackedChangeNotice {
            loadErrorMessage = notice
            return
        }
        let workingConfiguration = canonicalizeSkeletonReferencesIfNeeded(in: workingDocument.configuration)

        if let sourceBackedContext = workingDocument.sourceBackedContext {
            guard sourceBackedContext.canEdit else {
                loadErrorMessage = sourceBackedContext.readOnlyMessage
                return
            }

            Task {
                await applyWorkingCopyToSource(
                    workingConfiguration,
                    sourceBackedContext: sourceBackedContext
                )
            }
            return
        }

        guard let committedDocument = editorState.commitDocumentChanges() else { return }
        let committedConfiguration = canonicalizeSkeletonReferencesIfNeeded(in: committedDocument.configuration)
        activeConfiguration = committedConfiguration
        diagnosticsStore.record(
            domain: "binding.load",
            message: "Apply working copy: \(committedConfiguration.name)"
        )
        queueConfigurationLoad(committedConfiguration, navigationMode: .skipPush)
    }

    @MainActor
    private func applyWorkingCopyToSource(
        _ configuration: CellConfiguration,
        sourceBackedContext: EditorSourceBackedContext
    ) async {
        let fallbackIdentity = await privateRequesterIdentity()
        guard let requester = await requesterIdentity(
            for: preferredRequesterDescriptor(for: configuration),
            fallback: fallbackIdentity
        ) ?? fallbackIdentity else {
            loadErrorMessage = "Kunne ikke finne requester-identitet for å skrive tilbake til source-cellen."
            return
        }

        do {
            let appliedState = try await BindingSourceBackedConfigurationEditingSupport.apply(
                configuration,
                expectedRevision: sourceBackedContext.committedSourceRevision,
                toSourceEndpoint: sourceBackedContext.sourceCellEndpoint,
                requester: requester
            )
            let prepared = prepareEditableConfiguration(
                appliedState.configuration,
                fallback: configuration
            )
            activeSourceBackedContext = makeSourceBackedContext(from: appliedState)
            activeConfiguration = prepared
            loadErrorMessage = nil
            diagnosticsStore.record(
                domain: "binding.load",
                message: "Applied source-backed working copy: \(prepared.name)"
            )
            queueConfigurationLoad(prepared, navigationMode: .skipPush)
        } catch let error as BindingEditableCellConfigurationError {
            switch error {
            case .missingSourceEndpoint:
                loadErrorMessage = "Source-backed konfigurasjon mangler sourceCellEndpoint."
            case .sourceCellNotMeddle(let endpoint):
                loadErrorMessage = "Kunne ikke nå source-cellen på \(endpoint)."
            case .invalidStatePayload:
                loadErrorMessage = "Source-cellen svarte med en ugyldig editable-state under apply."
            }
        } catch {
            loadErrorMessage = "Kunne ikke skrive tilbake til source-cellen: \(error)"
        }
    }

    private func storeDemoStartConfiguration(_ configuration: CellConfiguration) {
        let persistedConfiguration = canonicalizeSkeletonReferencesIfNeeded(in: configuration)
        do {
            let data = try JSONEncoder().encode(persistedConfiguration)
            demoStartConfigurationJSON = String(decoding: data, as: UTF8.self)
            didApplyStoredDemoStart = false
            diagnosticsStore.record(
                domain: "binding.demo",
                message: "Demo-start satt til \(persistedConfiguration.name)"
            )
        } catch {
            diagnosticsStore.record(
                domain: "binding.demo",
                message: "Kunne ikke lagre demo-start: \(error)"
            )
        }
    }

    @MainActor
    private func resetToConferenceDemoLauncher() {
        let demoLauncher = Self.defaultDemoStartConfiguration()
        storeDemoStartConfiguration(demoLauncher)
        editorMode = .view
        presentingFullLibrary = false
        loadErrorMessage = nil
        presentImmediatePreviewIfNeeded(for: demoLauncher)
        diagnosticsStore.record(
            domain: "binding.demo",
            message: "Resetter til Conference Demo Launcher fra \(runtimeIdentityTitle)."
        )
        queueConfigurationLoad(demoLauncher, navigationMode: .reset)
    }

    private func decodeStoredDemoStartConfiguration() -> CellConfiguration? {
        guard !demoStartConfigurationJSON.isEmpty,
              let data = demoStartConfigurationJSON.data(using: .utf8) else {
            return nil
        }

        do {
            var decoded = try JSONDecoder().decode(CellConfiguration.self, from: data)
            if let updated = BindingConferenceConfigurationRepair.updatedConfigurationIfNeeded(decoded) {
                decoded = updated
                if let updatedData = try? JSONEncoder().encode(updated) {
                    demoStartConfigurationJSON = String(decoding: updatedData, as: UTF8.self)
                }
                diagnosticsStore.record(
                    domain: "binding.demo",
                    message: "Oppgraderte lagret demo-start til nyeste conference-konfigurasjon."
                )
            }
            if decoded.name == "Conference Sponsor Follow-up" {
                let demoLauncher = ConfigurationCatalogCell.conferenceDemoLauncherWorkbenchConfiguration()
                if let updatedData = try? JSONEncoder().encode(demoLauncher) {
                    demoStartConfigurationJSON = String(decoding: updatedData, as: UTF8.self)
                }
                diagnosticsStore.record(
                    domain: "binding.demo",
                    message: "Erstatter lagret sponsor-start med Conference Demo Launcher, så demoen starter i samme faste rekkefølge som CellScaffold."
                )
                return demoLauncher
            }
            return decoded
        } catch {
            diagnosticsStore.record(
                domain: "binding.demo",
                message: "Kunne ikke lese demo-start. Nullstiller lagret verdi: \(error)"
            )
            demoStartConfigurationJSON = ""
            return nil
        }
    }

    @MainActor
    private func applyStoredDemoStartConfigurationIfNeeded() {
        guard !didApplyStoredDemoStart else { return }
        didApplyStoredDemoStart = true
        let decodedStoredConfiguration = decodeStoredDemoStartConfiguration()
        let storedConfiguration = Self.effectiveDemoStartConfiguration(
            storedConfiguration: decodedStoredConfiguration
        )
        if let decoded = decodedStoredConfiguration,
           decoded.name != storedConfiguration.name {
            if let data = try? JSONEncoder().encode(storedConfiguration) {
                demoStartConfigurationJSON = String(decoding: data, as: UTF8.self)
            }
            diagnosticsStore.record(
                domain: "binding.demo",
                message: "Overstyrer lagret demo-start med Conference Demo Launcher inntil demoen er ferdig."
            )
        } else if let decoded = decodedStoredConfiguration,
                  Self.shouldRefreshStoredDemoStartConfiguration(
                    decoded,
                    defaultConfiguration: storedConfiguration
                  ) {
            if let data = try? JSONEncoder().encode(storedConfiguration) {
                demoStartConfigurationJSON = String(decoding: data, as: UTF8.self)
            }
            diagnosticsStore.record(
                domain: "binding.demo",
                message: "Oppgraderte lagret demo-start til nyeste Co-Pilot Chat-konfigurasjon."
            )
        } else if decodedStoredConfiguration == nil {
            if let data = try? JSONEncoder().encode(storedConfiguration) {
                demoStartConfigurationJSON = String(decoding: data, as: UTF8.self)
            }
            diagnosticsStore.record(
                domain: "binding.demo",
                message: "Ingen lagret demo-start funnet. Bruker Conference Demo Launcher som standard inntil demoen er ferdig."
            )
        }
        diagnosticsStore.record(
            domain: "binding.demo",
            message: "Laster demo-start: \(storedConfiguration.name)"
        )
        editorMode = .view
        presentImmediatePreviewIfNeeded(for: storedConfiguration)
        queueConfigurationLoad(storedConfiguration, navigationMode: .reset)
    }

    @MainActor
    private func ensureDefaultDemoStartVisibleIfNeeded(reason: String) {
        guard activeConfiguration == nil else { return }
        let storedConfiguration = Self.effectiveDemoStartConfiguration(
            storedConfiguration: decodeStoredDemoStartConfiguration()
        )
        diagnosticsStore.record(
            severity: .warning,
            domain: "binding.demo",
            message: "Ingen aktiv konfig var synlig etter \(reason). Laster \(storedConfiguration.name) eksplisitt."
        )
        editorMode = .view
        presentImmediatePreviewIfNeeded(for: storedConfiguration)
        queueConfigurationLoad(storedConfiguration, navigationMode: .reset)
    }

    @MainActor
    private func rebuildLegacyPortholeViewModel(reason: String) {
        legacyPortholeViewModel = PortholeViewModel()
        diagnosticsStore.record(
            domain: "binding.porthole",
            message: "Kobler opp legacy Porthole-binder på nytt etter \(reason)."
        )
    }

    @MainActor
    private func presentImmediatePreviewIfNeeded(for configuration: CellConfiguration) {
        guard shouldLoadWithoutAuthenticatedRuntimeBootstrap(configuration) else { return }
        activeConfiguration = configuration
        if let skeleton = configuration.skeleton {
            viewModel.currentSkeleton = skeleton
        }
        viewModel.cellReferences = configuration.cellReferences ?? []
    }

    static func effectiveDemoStartConfiguration(
        storedConfiguration: CellConfiguration?
    ) -> CellConfiguration {
        let defaultConfiguration = defaultDemoStartConfiguration()
        guard let storedConfiguration else {
            return defaultConfiguration
        }

        guard storedConfiguration.name == defaultConfiguration.name else {
            return defaultConfiguration
        }

        if shouldRefreshStoredDemoStartConfiguration(
            storedConfiguration,
            defaultConfiguration: defaultConfiguration
        ) {
            return defaultConfiguration
        }

        return storedConfiguration
    }

    static func shouldRefreshStoredDemoStartConfiguration(
        _ storedConfiguration: CellConfiguration,
        defaultConfiguration: CellConfiguration = defaultDemoStartConfiguration()
    ) -> Bool {
        let storedName = storedConfiguration.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let defaultName = defaultConfiguration.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard storedName == defaultName else { return false }
        return defaultName == "co-pilot chat"
    }

    @MainActor
    private func repairPersistedConferenceLauncherIfNeeded() async {
        guard !didRepairPersistedConferenceLauncher else { return }
        didRepairPersistedConferenceLauncher = true

        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let identity = await startupRequesterIdentity(),
              let porthole = try? await resolver.cellAtEndpoint(
                endpoint: Self.portholeEndpoint,
                requester: identity
              ) as? OrchestratorCell
        else {
            return
        }

        let statusValue = try? await porthole.get(
            keypath: "conferenceDemoLauncher.state.statusSummary",
            requester: identity
        )
        let skeletonValue = try? await porthole.get(
            keypath: "skeleton",
            requester: identity
        )
        let skeletonText: String?
        if case let .string(text)? = skeletonValue {
            skeletonText = text
        } else {
            skeletonText = nil
        }

        let currentlyLooksLikeLauncher =
            activeConfiguration?.name == "Conference Demo Launcher"
            || skeletonText?.contains("Conference Demo Launcher") == true

        guard currentlyLooksLikeLauncher else {
            return
        }

        if let statusValue,
           SkeletonBindingProbeSupport.failureDetail(from: statusValue) == nil {
            return
        }

        diagnosticsStore.record(
            severity: .warning,
            domain: "binding.demo",
            message: "Fant ustabil eller persisted Conference Demo Launcher i Porthole. Laster launcheren pa nytt med aktiv local requester."
        )

        let repairedConfiguration = Self.defaultDemoStartConfiguration()
        do {
            try await porthole.loadCellConfiguration(repairedConfiguration, requester: identity)
            activeConfiguration = repairedConfiguration
            loadErrorMessage = nil
            diagnosticsStore.refreshValidation(for: repairedConfiguration)
        } catch {
            diagnosticsStore.record(
                severity: .warning,
                domain: "binding.demo",
                message: "Direkte reparasjon av Conference Demo Launcher feilet. Prover vanlig last: \(error)"
            )
            queueConfigurationLoad(repairedConfiguration, navigationMode: .reset)
        }
    }

    @MainActor
    private func repairPersistedConferencePortalIfNeeded() async {
        guard !didRepairPersistedConferencePortal else { return }
        didRepairPersistedConferencePortal = true

        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let identity = await startupRequesterIdentity(),
              let porthole = try? await resolver.cellAtEndpoint(
                endpoint: Self.portholeEndpoint,
                requester: identity
              ) as? OrchestratorCell
        else {
            return
        }

        let titleValue = try? await porthole.get(
            keypath: "conferenceParticipantShell.state.workspace.title",
            requester: identity
        )
        let skeletonValue = try? await porthole.get(
            keypath: "skeleton",
            requester: identity
        )
        let skeletonText: String?
        if case let .string(text)? = skeletonValue {
            skeletonText = text
        } else {
            skeletonText = nil
        }

        let currentlyLooksLikeParticipantPortal =
            titleValue == .string("Conference Participant Portal Dashboard")
            || activeConfiguration?.name == "Conference Participant Portal Dashboard"
            || skeletonText?.contains("Conference Participant Portal") == true

        guard currentlyLooksLikeParticipantPortal else {
            return
        }

        let nearbySummary = try? await porthole.get(
            keypath: "nearbyRadar.state.summary",
            requester: identity
        )
        let matchmakingSummary = try? await porthole.get(
            keypath: "matchmakingSnapshot.state.statusSummary",
            requester: identity
        )
        let discoveryStatus = try? await porthole.get(
            keypath: "discoverySnapshot.state.statusSummary",
            requester: identity
        )
        if let nearbySummary,
           SkeletonBindingProbeSupport.failureDetail(from: nearbySummary) == nil,
           let matchmakingSummary,
           SkeletonBindingProbeSupport.failureDetail(from: matchmakingSummary) == nil,
           let discoveryStatus,
           SkeletonBindingProbeSupport.failureDetail(from: discoveryStatus) == nil {
            return
        }

        diagnosticsStore.record(
            severity: .warning,
            domain: "binding.demo",
            message: "Fant gammel eller ustabil persisted participant-portal i Porthole. Reparerer til ny conference-konfigurasjon med lokale matchmaking-, discovery- og nearby-snapshots."
        )

        let repairedConfiguration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration()
        do {
            try await porthole.loadCellConfiguration(repairedConfiguration, requester: identity)
            activeConfiguration = repairedConfiguration
            diagnosticsStore.refreshValidation(for: repairedConfiguration)
        } catch {
            diagnosticsStore.record(
                severity: .warning,
                domain: "binding.demo",
                message: "Direkte reparasjon av persisted participant-portal feilet. Prøver vanlig last: \(error)"
            )
            queueConfigurationLoad(repairedConfiguration, navigationMode: .reset)
        }
    }

    @MainActor
    private func repairPersistedConferenceControlTowerIfNeeded() async {
        guard !didRepairPersistedConferenceControlTower else { return }
        didRepairPersistedConferenceControlTower = true

        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let identity = await startupRequesterIdentity(),
              let porthole = try? await resolver.cellAtEndpoint(
                endpoint: Self.portholeEndpoint,
                requester: identity
              ) as? OrchestratorCell
        else {
            return
        }

        let titleValue = try? await porthole.get(
            keypath: "conferenceAdminShell.state.workspace.title",
            requester: identity
        )
        let skeletonValue = try? await porthole.get(
            keypath: "skeleton",
            requester: identity
        )
        let skeletonText: String?
        if case let .string(text)? = skeletonValue {
            skeletonText = text
        } else {
            skeletonText = nil
        }

        let currentlyLooksLikeControlTower =
            titleValue == .string("Conference Control Tower")
            || activeConfiguration?.name == "Conference Control Tower"
            || skeletonText?.contains("Conference Control Tower") == true

        guard currentlyLooksLikeControlTower else {
            return
        }

        func hasReadableBindingValue(_ value: ValueType?) -> Bool {
            guard let value else { return false }
            if SkeletonBindingProbeSupport.failureDetail(from: value) != nil {
                return false
            }
            if case let .string(text) = value {
                return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            }
            return true
        }

        let contentIntro = try? await porthole.get(
            keypath: "conferenceAdminShell.state.content.intro",
            requester: identity
        )
        let operationsIntro = try? await porthole.get(
            keypath: "conferenceAdminShell.state.operations.intro",
            requester: identity
        )
        let insightsSummary = try? await porthole.get(
            keypath: "conferenceAdminShell.state.insights.dashboardSummary",
            requester: identity
        )

        if hasReadableBindingValue(contentIntro),
           hasReadableBindingValue(operationsIntro),
           hasReadableBindingValue(insightsSummary) {
            return
        }

        diagnosticsStore.record(
            severity: .warning,
            domain: "binding.demo",
            message: "Fant gammel eller ustabil persisted control tower i Porthole. Reparerer til ny organizer-konfigurasjon."
        )

        let repairedConfiguration = ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
            endpoint: "cell:///ConferenceAdminPreviewShell"
        )
        do {
            try await porthole.loadCellConfiguration(repairedConfiguration, requester: identity)
            activeConfiguration = repairedConfiguration
            loadErrorMessage = nil
            diagnosticsStore.refreshValidation(for: repairedConfiguration)
        } catch {
            diagnosticsStore.record(
                severity: .warning,
                domain: "binding.demo",
                message: "Direkte reparasjon av persisted control tower feilet. Prøver vanlig last: \(error)"
            )
            queueConfigurationLoad(repairedConfiguration, navigationMode: .reset)
        }
    }

    private func queueConfigurationLoad(
        _ configuration: CellConfiguration?,
        navigationMode: ConferenceNavigationMode = .automatic
    ) {
        prepareConferenceNavigation(for: configuration, mode: navigationMode)
        configurationLoadTask?.cancel()
        configurationLoadTask = Task {
            await loadConfigurationForEditing(configuration)
        }
    }

    private func prepareConferenceNavigation(
        for configuration: CellConfiguration?,
        mode: ConferenceNavigationMode
    ) {
        guard let configuration else { return }

        switch mode {
        case .reset:
            conferenceNavigationStack.removeAll(keepingCapacity: false)
        case .skipPush:
            return
        case .automatic:
            guard let current = activeConfiguration,
                  isConferenceNavigationEligible(current),
                  isConferenceNavigationEligible(configuration) else {
                return
            }

            let currentIdentity = conferenceNavigationIdentity(for: current)
            let nextIdentity = conferenceNavigationIdentity(for: configuration)
            guard currentIdentity != nextIdentity else { return }
            guard conferenceNavigationStack.last.map({ conferenceNavigationIdentity(for: $0) }) != currentIdentity else { return }
            conferenceNavigationStack.append(current)
        }
    }

    private func popConferenceNavigation(fallbackConfiguration: CellConfiguration? = nil) {
        if let previous = conferenceNavigationStack.popLast() {
            queueConfigurationLoad(previous, navigationMode: .skipPush)
            return
        }

        guard let fallbackConfiguration else { return }
        queueConfigurationLoad(fallbackConfiguration, navigationMode: .reset)
    }

    private func handleIncomingURL(_ url: URL, targetWindowNumber: Int? = nil) {
        Task {
            guard shouldHandleIncomingURL(targetWindowNumber: targetWindowNumber) else { return }
            if let hook = Self.conferenceAutomationHook(from: url) {
                let automationEnabled = await MainActor.run {
                    conferenceAutomationOptInEnabled
                }
                guard automationEnabled else {
                    await MainActor.run {
                        loadErrorMessage = "Conference automation-deeplinks er av inntil du eksplisitt aktiverer debug-automation."
                        diagnosticsStore.record(
                            severity: .warning,
                            domain: "binding.automation",
                            message: "Ignorerte \(url.absoluteString) fordi conference automation ikke er aktivert."
                        )
                    }
                    return
                }
                await performConferenceAutomation(hook)
                return
            }
            let accepted = await ConferenceIdentityLinkInboxStore.shared.ingest(url: url)
            guard accepted else { return }
            await MainActor.run {
                diagnosticsStore.record(
                    domain: "binding.identityLink",
                    message: "Åpner Conference Scaffold Setup & Identity Link fra \(url.absoluteString)"
                )
                if editorMode == .edit {
                    editorMode = .view
                }
                queueConfigurationLoad(
                    Self.conferenceIdentityLinkMenuSeedConfiguration(),
                    navigationMode: .automatic
                )
            }
        }
    }

    private func handleConferenceAutomationNotification(
        _ hook: ConferenceAutomationHook,
        targetWindowNumber: Int?
    ) {
        Task {
            let shouldHandle = await MainActor.run {
                shouldHandleIncomingURL(targetWindowNumber: targetWindowNumber)
            }
            guard shouldHandle else { return }

            let automationEnabled = await MainActor.run {
                conferenceAutomationOptInEnabled
            }
            guard automationEnabled else {
                await MainActor.run {
                    diagnosticsStore.record(
                        severity: .warning,
                        domain: "binding.automation",
                        message: "Ignorerte automation hook \(hook.rawValue) fordi conference automation ikke er aktivert."
                    )
                }
                return
            }

            await performConferenceAutomation(hook)
        }
    }

    @MainActor
    private func shouldHandleIncomingURL(targetWindowNumber: Int?) -> Bool {
#if canImport(AppKit)
        guard let targetWindowNumber else { return true }
        return Self.matchesConferenceAutomationWindow(
            targetWindowNumber: targetWindowNumber,
            hostingWindowNumber: hostingWindowNumber
        )
#else
        _ = targetWindowNumber
        return true
#endif
    }

    private func runConferenceAutomation(_ hook: ConferenceAutomationHook) {
        Task {
            await performConferenceAutomation(hook)
        }
    }

    private func performConferenceAutomation(_ hook: ConferenceAutomationHook) async {
        await MainActor.run {
            focusConferenceAutomationWindow()
        }
        switch hook {
        case .openLauncher:
            await MainActor.run {
                loadConferenceAutomationConfiguration(
                    Self.defaultDemoStartConfiguration(),
                    navigationMode: .reset
                )
            }
        case .openParticipantPortal:
            await MainActor.run {
                loadConferenceAutomationConfiguration(
                    Self.conferenceParticipantPortalMenuSeedConfiguration(),
                    navigationMode: .automatic
                )
            }
        case .openConferenceMVP:
            await MainActor.run {
                loadConferenceAutomationConfiguration(
                    Self.conferenceMVPAutomationConfiguration(),
                    navigationMode: .automatic
                )
            }
        case .openPublicSurface:
            await MainActor.run {
                loadConferenceAutomationConfiguration(
                    Self.conferencePublicAutomationConfiguration(),
                    navigationMode: .automatic
                )
            }
        case .openControlTower:
            await MainActor.run {
                loadConferenceAutomationConfiguration(
                    Self.conferenceAdminMenuSeedConfiguration(),
                    navigationMode: .automatic
                )
            }
        case .openSponsorFollowUp:
            await MainActor.run {
                loadConferenceAutomationConfiguration(
                    Self.conferenceSponsorAutomationConfiguration(),
                    navigationMode: .automatic
                )
            }
        case .openAIAssistant:
            await MainActor.run {
                loadConferenceAutomationConfiguration(
                    Self.conferenceAIAssistantAutomationConfiguration(),
                    navigationMode: .automatic
                )
            }
        case .logAIAssistantState:
            await logConferenceAIAssistantState()
        case .openIdentityLink:
            await MainActor.run {
                loadConferenceAutomationConfiguration(
                    Self.conferenceIdentityLinkMenuSeedConfiguration(),
                    navigationMode: .automatic
                )
            }
        case .openAgentSetupWorkbench:
            await MainActor.run {
                loadConferenceAutomationConfiguration(
                    Self.agentSetupAutomationConfiguration(),
                    navigationMode: .automatic
                )
            }
        case .installAgent:
            _ = await dispatchDirectConferenceAutomationAction(
                endpoint: "cell:///AgentProvisioning",
                actionKeypath: "agent.setup.install",
                payload: .bool(true)
            )
        case .startAgent:
            _ = await dispatchDirectConferenceAutomationAction(
                endpoint: "cell:///AgentProvisioning",
                actionKeypath: "agent.setup.start",
                payload: .bool(true)
            )
        case .connectAgent:
            _ = await dispatchDirectConferenceAutomationAction(
                endpoint: "cell:///AgentProvisioning",
                actionKeypath: "agent.setup.connect",
                payload: .bool(true)
            )
        case .queueAgentSafariReview:
            _ = await dispatchDirectConferenceAutomationAction(
                endpoint: "cell:///AgentProvisioning",
                actionKeypath: "agent.setup.review.queueSafariTest",
                payload: .bool(true)
            )
        case .approveAgentReview:
            _ = await dispatchDirectConferenceAutomationAction(
                endpoint: "cell:///AgentProvisioning",
                actionKeypath: "agent.setup.review.approveSelected",
                payload: .bool(true)
            )
        case .stopAgent:
            _ = await dispatchDirectConferenceAutomationAction(
                endpoint: "cell:///AgentProvisioning",
                actionKeypath: "agent.setup.stop",
                payload: .bool(true)
            )
        case .focusAneSolberg:
            let focused = await dispatchConferenceAutomationAction(
                endpoint: "cell:///ConferenceParticipantMatchmakingSnapshot",
                actionKeypath: "matchmaking.focusPerson",
                payload: .object([
                    "displayName": .string("Ane Solberg"),
                    "subtitle": .string("Public sector interoperability")
                ])
            )
            guard focused else { return }
            await MainActor.run {
                if normalizedActiveConferenceConfigurationName != "conference participant portal dashboard" {
                    loadConferenceAutomationConfiguration(
                        Self.conferenceParticipantPortalMenuSeedConfiguration(),
                        navigationMode: .automatic
                    )
                }
            }
        case .startChatWithFocusedParticipant:
            let started = await dispatchConferenceAutomationAction(
                endpoint: "cell:///ConferenceParticipantMatchmakingSnapshot",
                actionKeypath: "discovery.startChatWithFocusedPerson"
            )
            guard started else { return }
            await MainActor.run {
                let normalizedName = normalizedActiveConferenceConfigurationName
                if normalizedName != "conference participant portal dashboard",
                   normalizedName?.contains("conference chat") != true {
                    loadConferenceAutomationConfiguration(
                        Self.conferenceParticipantPortalMenuSeedConfiguration(),
                        navigationMode: .automatic
                    )
                }
            }
        case .openFocusedChatWorkbench:
            _ = await dispatchConferenceAutomationAction(
                endpoint: "cell:///ConferenceChatLaunch",
                actionKeypath: "openChatWorkbenchForSelectedParticipant"
            )
#if canImport(AppKit)
        case .windowCompact:
            await MainActor.run {
                applyConferenceAutomationWindowPreset(width: 900, height: 640)
            }
        case .windowTall:
            await MainActor.run {
                applyConferenceAutomationWindowPreset(width: 900, height: 1100)
            }
        case .windowWide:
            await MainActor.run {
                applyConferenceAutomationWindowPreset(width: 1280, height: 900)
            }
        case .centerWindow:
            await MainActor.run {
                centerConferenceAutomationWindow()
            }
#endif
        }
    }

    private func logConferenceAIAssistantState() async {
        await BindingLocalCellRegistration.shared.ensureConferenceDemoRuntimeReady()
        guard let requester = await startupRequesterIdentity() else {
            await MainActor.run {
                let message = "Conference AI state-log mangler startup-identitet."
                loadErrorMessage = message
                diagnosticsStore.record(
                    severity: .error,
                    domain: "binding.automation",
                    message: message
                )
            }
            return
        }

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            await MainActor.run {
                let message = "Conference AI state-log mangler CellResolver."
                loadErrorMessage = message
                diagnosticsStore.record(
                    severity: .error,
                    domain: "binding.automation",
                    message: message
                )
            }
            return
        }

        do {
            guard let gatewayPreview = try await resolver.cellAtEndpoint(
                endpoint: "cell://\(Self.stagingHost)/ConferenceAIGatewayPreview",
                requester: requester
            ) as? Meddle else {
                throw ConferenceAutomationAIAccessError.proxyMissing
            }

            let value = try await gatewayPreview.get(keypath: "state", requester: requester)
            let summary = conferenceAutomationAISummary(from: value)
            print(summary)
            await MainActor.run {
                diagnosticsStore.record(
                    domain: "binding.automation",
                    message: summary
                )
            }
        } catch {
            let message = "Conference AI state-log feilet: \(error.localizedDescription)"
            print(message)
            await MainActor.run {
                loadErrorMessage = message
                diagnosticsStore.record(
                    severity: .error,
                    domain: "binding.automation",
                    message: message
                )
            }
        }
    }

    private func conferenceAutomationAISummary(from value: ValueType) -> String {
        func object(_ value: ValueType?) -> Object? {
            guard case let .object(object)? = value else { return nil }
            return object
        }

        func string(_ value: ValueType?) -> String? {
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

        guard case let .object(root) = value else {
            return "Conference AI state log: uventet svar \(value)"
        }

        let setup = object(root["setup"])
        let invocation = object(root["lastInvocation"])
        let status = string(setup?["statusLabel"]) ?? "mangler status"
        let provider = string(setup?["providerLabel"]) ?? "mangler provider"
        let credential = string(setup?["credentialStatus"]) ?? "mangler credential-status"
        let message = string(setup?["lastMessage"]) ?? "ingen lastMessage"
        let output = string(invocation?["outputPreview"]) ?? "ingen outputPreview"

        return "Conference AI state log: status=\(status) | provider=\(provider) | credential=\(credential) | lastMessage=\(message) | outputPreview=\(output)"
    }

    @MainActor
    private func loadConferenceAutomationConfiguration(
        _ configuration: CellConfiguration,
        navigationMode: ConferenceNavigationMode
    ) {
        let preparedConfiguration: CellConfiguration
        if let resolver = CellBase.defaultCellResolver as? CellResolver {
            preparedConfiguration = normalizeConfigurationForResolver(
                configuration,
                origin: nil,
                resolver: resolver
            )
        } else {
            preparedConfiguration = configuration
        }
        diagnosticsStore.record(
            domain: "binding.automation",
            message: "Automation åpner \(preparedConfiguration.name)."
        )
        if editorMode == .edit {
            editorMode = .view
        }
        queueConfigurationLoad(preparedConfiguration, navigationMode: navigationMode)
    }

    private func dispatchConferenceAutomationAction(
        endpoint: String,
        actionKeypath: String,
        payload: ValueType = .null
    ) async -> Bool {
        await BindingLocalCellRegistration.shared.ensureConferenceDemoRuntimeReady()
        guard let requester = await startupRequesterIdentity() else {
            await MainActor.run {
                loadErrorMessage = "Conference automation mangler startup-identitet."
                diagnosticsStore.record(
                    severity: .error,
                    domain: "binding.automation",
                    message: "Startup-identitet mangler for conference automation."
                )
            }
            return false
        }
        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            await MainActor.run {
                loadErrorMessage = "Conference automation mangler CellResolver."
                diagnosticsStore.record(
                    severity: .error,
                    domain: "binding.automation",
                    message: "CellResolver mangler for conference automation."
                )
            }
            return false
        }
        guard let cell = try? await resolver.cellAtEndpoint(endpoint: endpoint, requester: requester) as? Meddle else {
            await MainActor.run {
                loadErrorMessage = "Conference automation fant ikke \(endpoint)."
                diagnosticsStore.record(
                    severity: .error,
                    domain: "binding.automation",
                    message: "Fant ikke automation-endpoint \(endpoint)."
                )
            }
            return false
        }

        let action: ValueType = .object([
            "keypath": .string(actionKeypath),
            "payload": payload
        ])

        do {
            let result = try await cell.set(keypath: "dispatchAction", value: action, requester: requester) ?? .null
            if let failure = conferenceAutomationFailureMessage(from: result) {
                await MainActor.run {
                    loadErrorMessage = failure
                    diagnosticsStore.record(
                        severity: .warning,
                        domain: "binding.automation",
                        message: failure
                    )
                }
                return false
            }
            await MainActor.run {
                diagnosticsStore.record(
                    domain: "binding.automation",
                    message: "Automation utførte \(actionKeypath) på \(endpoint)."
                )
                refreshLegacyPortholeBindings(reason: "conference automation \(actionKeypath)")
            }
            return true
        } catch {
            let message = "Conference automation feilet for \(actionKeypath) på \(endpoint): \(error)"
            await MainActor.run {
                loadErrorMessage = message
                diagnosticsStore.record(
                    severity: .error,
                    domain: "binding.automation",
                    message: message
                )
            }
            return false
        }
    }

    private func dispatchDirectConferenceAutomationAction(
        endpoint: String,
        actionKeypath: String,
        payload: ValueType = .null
    ) async -> Bool {
        await BindingLocalCellRegistration.shared.ensureConferenceDemoRuntimeReady()
        guard let requester = await startupRequesterIdentity() else {
            await MainActor.run {
                loadErrorMessage = "Conference automation mangler startup-identitet."
                diagnosticsStore.record(
                    severity: .error,
                    domain: "binding.automation",
                    message: "Startup-identitet mangler for conference automation."
                )
            }
            return false
        }
        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            await MainActor.run {
                loadErrorMessage = "Conference automation mangler CellResolver."
                diagnosticsStore.record(
                    severity: .error,
                    domain: "binding.automation",
                    message: "CellResolver mangler for conference automation."
                )
            }
            return false
        }
        guard let cell = try? await resolver.cellAtEndpoint(endpoint: endpoint, requester: requester) as? Meddle else {
            await MainActor.run {
                loadErrorMessage = "Conference automation fant ikke \(endpoint)."
                diagnosticsStore.record(
                    severity: .error,
                    domain: "binding.automation",
                    message: "Fant ikke automation-endpoint \(endpoint)."
                )
            }
            return false
        }

        do {
            let result = try await cell.set(keypath: actionKeypath, value: payload, requester: requester) ?? .null
            if let failure = conferenceAutomationFailureMessage(from: result) {
                await MainActor.run {
                    loadErrorMessage = failure
                    diagnosticsStore.record(
                        severity: .warning,
                        domain: "binding.automation",
                        message: failure
                    )
                }
                return false
            }
            await MainActor.run {
                diagnosticsStore.record(
                    domain: "binding.automation",
                    message: "Automation utførte \(actionKeypath) på \(endpoint)."
                )
                refreshLegacyPortholeBindings(reason: "conference automation \(actionKeypath)")
            }
            return true
        } catch {
            let message = "Conference automation feilet for \(actionKeypath) på \(endpoint): \(error)"
            await MainActor.run {
                loadErrorMessage = message
                diagnosticsStore.record(
                    severity: .error,
                    domain: "binding.automation",
                    message: message
                )
            }
            return false
        }
    }

    private func conferenceAutomationFailureMessage(from value: ValueType) -> String? {
        if case let .string(text) = value {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("error:") || trimmed == "denied" || trimmed == "failure" {
                return trimmed
            }
        }
        guard case let .object(object) = value else { return nil }
        if let status = stringValue(from: object["status"]),
           status == "error" || status == "denied" || status == "failure" {
            if case let .object(state)? = object["state"] {
                return stringValue(from: state["actionSummary"])
                    ?? stringValue(from: state["status"])
                    ?? stringValue(from: state["statusSummary"])
                    ?? "Conference automation rapporterte \(status)."
            }
            return "Conference automation rapporterte \(status)."
        }
        return nil
    }

    private enum ConferenceAutomationAIAccessError: LocalizedError {
        case proxyMissing

        var errorDescription: String? {
            switch self {
            case .proxyMissing:
                return "ConferenceAIGatewayPreview kunne ikke resolves fra scaffold-runtime."
            }
        }
    }

    private func isConferenceNavigationEligible(_ configuration: CellConfiguration?) -> Bool {
        guard let configuration else { return false }
        let normalizedName = configuration.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return normalizedName == "conference demo launcher"
            || normalizedName == "conference participant portal dashboard"
            || normalizedName.contains("conference chat")
            || normalizedName == "conference control tower"
            || normalizedName == "conference public surface"
            || normalizedName == "conference ai assistant"
            || normalizedName == "agent setup workbench"
            || normalizedName == "conference scaffold setup & identity link"
            || normalizedName.contains("conference nearby radar")
            || normalizedName.contains("profilflate")
    }

    private func conferenceNavigationIdentity(for configuration: CellConfiguration) -> String {
        let firstEndpoint = configuration.cellReferences?.first?.endpoint ?? ""
        return "\(configuration.name.lowercased())|\(firstEndpoint.lowercased())"
    }

    private func updateLoadingStatus(_ message: String, requestID: UUID? = nil) {
        if let requestID, activeLoadingRequestID != requestID {
            return
        }
        loadingStatusMessage = message
        diagnosticsStore.record(domain: "binding.load", message: message)
    }

    @MainActor
    private var runtimeBootstrapIsReady: Bool {
        BindingRuntimeBootstrap.authenticatedRuntimeIsReady
    }

    @MainActor
    private func waitForRuntimeBootstrapIfNeeded(
        requestID: UUID,
        configurationName: String
    ) async -> Bool {
        if runtimeBootstrapIsReady {
            await BindingLocalCellRegistration.shared.ensureRegistered()
            return true
        }

        if BindingRuntimeBootstrap.shouldUseLocalRuntimeOnlyForVerifier() {
            await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
            return true
        }

        updateLoadingStatus(
            "Venter på autentisering og runtime-bootstrap for \(configurationName)…",
            requestID: requestID
        )
        await BindingRuntimeBootstrap.ensureBaseline()
        if !BindingRuntimeBootstrap.shouldUseLocalRuntimeOnlyForVerifier() {
            await AppInitializer.initialize()
        }
        await BindingRuntimeBootstrap.ensureBaseline()
        await BindingLocalCellRegistration.shared.ensureRegistered()
        if runtimeBootstrapIsReady {
            return true
        }

        let maxAttempts = 60
        let retryDelayNanoseconds: UInt64 = 250_000_000

        for attempt in 1...maxAttempts {
            guard !Task.isCancelled else { return false }
            if runtimeBootstrapIsReady {
                return true
            }
            if attempt == 1 || attempt.isMultiple(of: 10) {
                await BindingRuntimeBootstrap.ensureBaseline()
            }
            if attempt < maxAttempts {
                updateLoadingStatus(
                    "Venter på autentisering og runtime-bootstrap for \(configurationName)… (\(attempt)/\(maxAttempts))",
                    requestID: requestID
                )
                try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
            }
        }

        let message = "Runtime ble ikke klar i tide. Bekreft autentisering og prøv igjen."
        loadErrorMessage = message
        diagnosticsStore.record(
            severity: .error,
            domain: "binding.load",
            message: "\(message) [\(configurationName)]"
        )
        return false
    }

    private func refreshDiagnosticsValidation() {
        diagnosticsStore.refreshValidation(for: diagnosticConfiguration)
    }

    @MainActor
    private func handleMemoryWarning() {
        diagnosticsStore.record(
            severity: .warning,
            domain: "binding.memory",
            message: "iOS rapporterte memory pressure. Rydder midlertidige buffere og editorhistorikk."
        )
        configurationLoadTask?.cancel()
        bridgeStatusStore.handleMemoryPressure()
        diagnosticsStore.handleMemoryPressure()
        editorState.discardTransientHistory()
        componentPlacementState.clear()

        Task {
            await ConferenceParticipantPreviewFallbackStateStore.shared.handleMemoryPressure()
            await ConferenceParticipantSelectionStore.shared.handleMemoryPressure()
        }
    }

    private var runtimeDerivedDataToken: String {
        let components = Bundle.main.bundleURL.pathComponents
        if let derivedDataComponent = components.last(where: { $0.hasPrefix("Binding-") && $0 != "Binding.app" }) {
            return derivedDataComponent
        }
        return Bundle.main.bundleURL.deletingPathExtension().lastPathComponent
    }

    private var runtimeIdentityTitle: String {
        "PID \(ProcessInfo.processInfo.processIdentifier) · \(runtimeDerivedDataToken)"
    }

    private var runtimeIdentitySubtitle: String {
        let activeName = activeConfiguration?.name ?? "Ingen konfig lastet"
        return "\(activeName) · \(Bundle.main.bundleURL.path)"
    }

    @ViewBuilder
    private var runtimeIdentityBadge: some View {
        Text(runtimeIdentityTitle)
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12), in: Capsule())
            .help(runtimeIdentitySubtitle)
    }

    private var canPopConferenceNavigation: Bool {
        !conferenceNavigationStack.isEmpty && isConferenceNavigationEligible(activeConfiguration)
    }

    private var conferenceNavigationBackLabel: String {
        guard let previous = conferenceNavigationStack.last else {
            return "Back"
        }
        return "Tilbake til \(previous.name)"
    }

    private var diagnosticConfiguration: CellConfiguration? {
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

    @MainActor
    private func loadConfigurationForEditing(_ configuration: CellConfiguration?) async {
        guard let configuration else { return }
        let requestID = UUID()
        activeLoadingRequestID = requestID
        isLoadingConfiguration = true
        updateLoadingStatus("Laster \(configuration.name)…", requestID: requestID)
        defer {
            if activeLoadingRequestID == requestID {
                isLoadingConfiguration = false
                loadingStatusMessage = nil
                activeLoadingRequestID = nil
            }
        }

        guard let sanitizedConfiguration = sanitizedLoadedConfiguration(configuration, allowReferenceFree: true) else {
            loadErrorMessage = "Konfigurasjonen ble filtrert bort fordi den mangler gyldige CellReferences."
            diagnosticsStore.record(
                severity: .warning,
                domain: "binding.load",
                message: "Sanitization removed configuration \(configuration.name)"
            )
            return
        }
        loadErrorMessage = nil
        diagnosticsStore.refreshValidation(for: sanitizedConfiguration)
        guard !Task.isCancelled else { return }
        if shouldLoadWithoutAuthenticatedRuntimeBootstrap(sanitizedConfiguration) {
            await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
            await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
            updateLoadingStatus("Laster lokal konfigurasjon for \(sanitizedConfiguration.name)…", requestID: requestID)
            let startupRequester = await startupRequesterIdentity()
            let localRequester: Identity?
            if let startupRequester {
                localRequester = startupRequester
            } else {
                localRequester = await privateRequesterIdentity()
            }
            if let localRequester,
               let editableResolution = await resolveEditableConfigurationForCurrentRequester(
                sanitizedConfiguration,
                requester: localRequester
               ) {
                activeConfiguration = editableResolution.configuration
                activeSourceBackedContext = editableResolution.context
            } else {
                activeConfiguration = sanitizedConfiguration
                activeSourceBackedContext = nil
            }
            let didLoad = await loadConfigurationIntoPorthole(
                activeConfiguration ?? sanitizedConfiguration,
                requestID: requestID,
                allowConferencePreviewFallback: false
            )
            guard didLoad else { return }
            refreshDiagnosticsValidation()
            loadErrorMessage = nil
            return
        }
        if requiresAuthenticatedRuntimeBootstrap(sanitizedConfiguration) {
            guard await waitForRuntimeBootstrapIfNeeded(
                requestID: requestID,
                configurationName: sanitizedConfiguration.name
            ) else { return }
        } else {
            await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
            await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
        }

        updateLoadingStatus("Normaliserer references for \(sanitizedConfiguration.name)…", requestID: requestID)
        var normalizedConfiguration = retargetConfigurationToStagingIfNeeded(sanitizedConfiguration)
        let fallbackIdentity = await privateRequesterIdentity()
        let loadRequester = await requesterIdentity(
            for: preferredRequesterDescriptor(for: normalizedConfiguration),
            fallback: fallbackIdentity
        ) ?? fallbackIdentity
        if let resolver = CellBase.defaultCellResolver as? CellResolver {
            if let identity = loadRequester {
                if shouldWarmConferenceRuntime(for: normalizedConfiguration) {
                    updateLoadingStatus("Varmer opp lokal conference-runtime for \(sanitizedConfiguration.name)…", requestID: requestID)
                    await BindingLocalCellRegistration.shared.warmConferenceRuntime(requester: identity)
                }
                guard !Task.isCancelled else { return }
                updateLoadingStatus("Henter fjernkonfigurasjon for \(sanitizedConfiguration.name)…", requestID: requestID)
                normalizedConfiguration = await recoverRemoteConfigurationOnDemandIfNeeded(
                    normalizedConfiguration,
                    resolver: resolver,
                    identity: identity
                )
                guard !Task.isCancelled else { return }
                normalizedConfiguration = await hydrateSparseConfigurationIfNeeded(
                    normalizedConfiguration,
                    resolver: resolver,
                    identity: identity
                )
            }
            guard !Task.isCancelled else { return }
            normalizedConfiguration = normalizeConfigurationForResolver(
                normalizedConfiguration,
                origin: nil,
                resolver: resolver
            )
            if shouldResolveSourceBackedConfiguration(normalizedConfiguration, editorMode: editorMode) {
                if let editableResolution = await resolveEditableConfigurationForCurrentRequester(
                    normalizedConfiguration,
                    requester: loadRequester,
                    timeoutNanoseconds: editorMode == .edit ? nil : 700_000_000
                ) {
                    let sourceBackedOrigin = catalogOrigin(
                        from: normalizedConfiguration.discovery?.sourceCellEndpoint
                            ?? editableResolution.context.sourceCellEndpoint
                    )
                    normalizedConfiguration = normalizeConfigurationForResolver(
                        editableResolution.configuration,
                        origin: sourceBackedOrigin,
                        resolver: resolver
                    )
                    var context = editableResolution.context
                    context.sourceCellEndpoint = normalizeEndpointForResolver(
                        context.sourceCellEndpoint,
                        origin: sourceBackedOrigin,
                        resolver: resolver
                    )
                    activeSourceBackedContext = context
                } else {
                    activeSourceBackedContext = nil
                }
            } else {
                activeSourceBackedContext = nil
            }
        } else {
            activeSourceBackedContext = nil
        }
        activeConfiguration = normalizedConfiguration
        diagnosticsStore.refreshValidation(for: normalizedConfiguration)
        guard !Task.isCancelled else { return }

        var loadConfiguration = normalizedConfiguration
        if activeSourceBackedContext == nil,
           let references = normalizedConfiguration.cellReferences,
           !references.isEmpty {
            updateLoadingStatus("Sjekker tilgjengelige bridge-references…", requestID: requestID)
            let probeResult = await probeFailingTopLevelReferences(in: normalizedConfiguration)
            if let fallbackConfiguration = localConferencePreviewFallbackConfiguration(
                for: loadConfiguration,
                failureDetails: [probeResult.firstFailureMessage].compactMap { $0 }
            ) {
                activeSourceBackedContext = nil
                diagnosticsStore.record(
                    severity: .warning,
                    domain: "binding.load",
                    message: "Staging preview denied access for \(loadConfiguration.name). Falling back to local conference preview."
                )
                updateLoadingStatus(
                    "Staging preview svarte denied. Bytter til lokal conference-preview…",
                    requestID: requestID
                )
                loadConfiguration = fallbackConfiguration
                activeConfiguration = fallbackConfiguration
                diagnosticsStore.refreshValidation(for: fallbackConfiguration)
            } else if !probeResult.failingReferenceEndpoints.isEmpty {
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
                        diagnosticsStore.record(
                            severity: .error,
                            domain: "binding.load",
                            message: "Critical reference failure for \(normalizedConfiguration.name): \(probeResult.firstFailureMessage ?? "unknown")"
                        )
                        return
                    }
                    loadConfiguration.cellReferences = retainedReferences
                    if retainedReferences.isEmpty {
                        loadErrorMessage = "Ingen referanser kunne lastes. \(probeResult.firstFailureMessage ?? "")"
                    } else {
                        loadErrorMessage = "Noen referanser feilet og ble hoppet over (\(removedCount)). \(probeResult.firstFailureMessage ?? "")"
                    }
                    diagnosticsStore.record(
                        severity: retainedReferences.isEmpty ? .error : .warning,
                        domain: "binding.load",
                        message: "Dropped \(removedCount) failing references while loading \(normalizedConfiguration.name)"
                    )
                }
            }
        }

        guard !Task.isCancelled else { return }
        updateLoadingStatus("Absorberer \(loadConfiguration.name) i porthole…", requestID: requestID)
        let didLoad = await loadConfigurationIntoPorthole(loadConfiguration, requestID: requestID)
        guard didLoad else { return }
        diagnosticsStore.record(
            domain: "binding.load",
            message: "Loaded configuration \(loadConfiguration.name) [\(requestID.uuidString.prefix(6))]"
        )
        if editorMode == .edit {
            editorState.beginEditing(
                configuration: loadConfiguration,
                sourceBackedContext: activeSourceBackedContext,
                fallbackSkeleton: loadConfiguration.skeleton ?? viewModel.currentSkeleton
            )
        }
        refreshDiagnosticsValidation()
    }

    private func shouldLoadWithoutAuthenticatedRuntimeBootstrap(_ configuration: CellConfiguration) -> Bool {
        if configurationUsesOnlyLocalEndpoints(configuration) {
            return true
        }

        let normalizedName = configuration.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let localConferenceWorkbenchNames: Set<String> = [
            "conference demo launcher",
            "conference scaffold setup & identity link",
            "conference participant portal dashboard",
            "agent setup workbench",
            "conference ai assistant",
            "conference chat · oppfølging",
            "conference control tower",
            "conference nearby radar · full oversikt",
            "valgt nearby-deltager · profilflate"
        ]

        return localConferenceWorkbenchNames.contains(normalizedName)
            || normalizedName.contains("conference chat")
            || normalizedName.contains("profilflate")
            || normalizedName == "conference public surface"
    }

    func requiresAuthenticatedRuntimeBootstrap(_ configuration: CellConfiguration) -> Bool {
        !shouldLoadWithoutAuthenticatedRuntimeBootstrap(configuration)
    }

    func shouldResolveSourceBackedConfiguration(
        _ configuration: CellConfiguration,
        editorMode: EditorMode
    ) -> Bool {
        if editorMode == .edit {
            return true
        }

        let metadata = BindingPersonalCopilotSurfaceMetadata(configuration: configuration)
        return metadata.appStoreScope != BindingPersonalCopilotV1Policy.appStoreScope
    }

    private func configurationUsesOnlyLocalEndpoints(_ configuration: CellConfiguration) -> Bool {
        let endpoints = runtimeBootstrapEndpoints(for: configuration)
        guard !endpoints.isEmpty else {
            return true
        }
        return endpoints.allSatisfy { endpoint in
            !RemoteCatalogSupport.isRemoteEndpoint(endpoint)
        }
    }

    private func runtimeBootstrapEndpoints(for configuration: CellConfiguration) -> [String] {
        var endpoints = (configuration.cellReferences ?? []).map(\.endpoint)
        if let discoveryEndpoint = configuration.discovery?.sourceCellEndpoint,
           !discoveryEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            endpoints.append(discoveryEndpoint)
        }

        var seen = Set<String>()
        return endpoints.filter { endpoint in
            let key = endpoint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { return false }
            return seen.insert(key).inserted
        }
    }

    private func shouldWarmConferenceRuntime(for configuration: CellConfiguration) -> Bool {
        let endpoints = (configuration.cellReferences ?? []).map(\.endpoint)
        let discoveryEndpoint = configuration.discovery?.sourceCellEndpoint.map { [$0] } ?? []

        return (endpoints + discoveryEndpoint).contains { endpoint in
            let normalized = endpoint
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return normalized == "cell:///conferenceparticipantpreviewshell"
                || normalized == "cell:///conferenceparticipantagendasnapshot"
                || normalized == "cell:///conferenceadminpreviewshell"
                || normalized == "cell:///conferenceparticipantdiscoverysnapshot"
                || normalized == "cell:///conferenceparticipantmatchmakingsnapshot"
                || normalized == "cell:///conferenceparticipantchatsnapshot"
                || normalized == "cell:///conferencenearbyradar"
        }
    }

    private func loadConfigurationIntoPorthole(
        _ configuration: CellConfiguration,
        requestID: UUID,
        allowConferencePreviewFallback: Bool = true
    ) async -> Bool {
        let unauthenticatedConferenceLoad = shouldLoadWithoutAuthenticatedRuntimeBootstrap(configuration)
        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let portholeIdentity = await (unauthenticatedConferenceLoad ? startupRequesterIdentity() : privateRequesterIdentity()),
              let porthole = try? await resolver.cellAtEndpoint(endpoint: Self.portholeEndpoint, requester: portholeIdentity) as? OrchestratorCell
        else {
            await viewModel.load(configuration: configuration)
            return true
        }

        let loadRequester: Identity
        if unauthenticatedConferenceLoad {
            loadRequester = portholeIdentity
        } else {
            loadRequester = await requesterIdentity(
                for: preferredRequesterDescriptor(for: configuration),
                fallback: portholeIdentity
            ) ?? portholeIdentity
        }
        let intendedSkeleton = configuration.skeleton ?? viewModel.currentSkeleton
        let rootProbes = SkeletonBindingProbeSupport.rootProbes(for: configuration)

        await MainActor.run {
            legacyPortholeViewModel.rememberRequesterIdentity(loadRequester)
        }
        viewModel.cellReferences = configuration.cellReferences ?? []
        viewModel.currentSkeleton = loadingPlaceholderSkeleton(for: configuration)

        do {
            try await loadConfigurationIntoPortholeWithTimeout(
                configuration,
                on: porthole,
                requester: loadRequester
            )
        } catch {
            if allowConferencePreviewFallback,
               let fallbackConfiguration = localConferencePreviewFallbackConfiguration(
                for: configuration,
                failureDetails: [String(describing: error)]
               ) {
                diagnosticsStore.record(
                    severity: .warning,
                    domain: "binding.load",
                    message: "Absorb of \(configuration.name) failed against staging preview. Retrying with local conference preview."
                )
                activeConfiguration = fallbackConfiguration
                diagnosticsStore.refreshValidation(for: fallbackConfiguration)
                updateLoadingStatus(
                    "Staging preview svarte denied. Prøver lokal conference-preview…",
                    requestID: requestID
                )
                return await loadConfigurationIntoPorthole(
                    fallbackConfiguration,
                    requestID: requestID,
                    allowConferencePreviewFallback: false
                )
            }
            let message = "Kunne ikke absorbere \(configuration.name) i porthole: \(error)"
            diagnosticsStore.record(
                severity: .error,
                domain: "binding.load",
                message: message
            )
            loadErrorMessage = message
            viewModel.currentSkeleton = failurePlaceholderSkeleton(for: configuration, detail: String(describing: error))
            return false
        }

        guard !Task.isCancelled else { return false }
        viewModel.currentSkeleton = intendedSkeleton
        guard !rootProbes.isEmpty else {
            refreshLegacyPortholeBindings(reason: "absorbed \(configuration.name)")
            return true
        }

        let availability = await waitForReadableBindingRoots(
            rootProbes,
            on: porthole,
            requester: loadRequester,
            configurationName: configuration.name,
            requestID: requestID
        )

        let resolvedAvailability: RootBindingAvailability
        switch availability {
        case .failed(let failures) where shouldWarmConferenceRuntime(for: configuration):
            diagnosticsStore.record(
                severity: .warning,
                domain: "binding.load",
                message: "Readable roots for \(configuration.name) were not ready after initial absorb. Rewarming local conference runtime and probing once more."
            )
            updateLoadingStatus(
                "Varmer opp lokal conference-runtime på nytt for \(configuration.name)…",
                requestID: requestID
            )
            await BindingLocalCellRegistration.shared.warmConferenceRuntime(requester: loadRequester)
            resolvedAvailability = await waitForReadableBindingRoots(
                rootProbes,
                on: porthole,
                requester: loadRequester,
                configurationName: configuration.name,
                requestID: requestID
            )
            if case .failed = resolvedAvailability {
                diagnosticsStore.record(
                    severity: .warning,
                    domain: "binding.load",
                    message: "Conference rewarm did not fully clear unreadable roots for \(configuration.name): \(summarizeBindingFailures(failures))"
                )
            }
        default:
            resolvedAvailability = availability
        }

        switch resolvedAvailability {
        case .ready(let attempts):
            loadErrorMessage = nil
            if attempts > 1 {
                diagnosticsStore.record(
                    domain: "binding.load",
                    message: "Readable roots became available for \(configuration.name) after \(attempts) attempts."
                )
            }
            refreshLegacyPortholeBindings(reason: "readable roots ready for \(configuration.name)")
            return true
        case .failed(let failures):
            if allowConferencePreviewFallback,
               let fallbackConfiguration = localConferencePreviewFallbackConfiguration(
                for: configuration,
                failureDetails: Array(failures.values)
               ) {
                diagnosticsStore.record(
                    severity: .warning,
                    domain: "binding.load",
                    message: "Readable roots for \(configuration.name) were denied. Falling back to local conference preview."
                )
                activeConfiguration = fallbackConfiguration
                diagnosticsStore.refreshValidation(for: fallbackConfiguration)
                loadErrorMessage = nil
                updateLoadingStatus(
                    "Staging preview svarte denied. Laster lokal conference-preview…",
                    requestID: requestID
                )
                return await loadConfigurationIntoPorthole(
                    fallbackConfiguration,
                    requestID: requestID,
                    allowConferencePreviewFallback: false
                )
            }
            let failureSummary = summarizeBindingFailures(failures)
            let message = "Noen data for \(configuration.name) er fortsatt utilgjengelige. Viser UI mens forbindelsen varmes opp. \(failureSummary)"
            diagnosticsStore.record(
                severity: .warning,
                domain: "binding.load",
                message: message
            )
            loadErrorMessage = message
            refreshLegacyPortholeBindings(reason: "best-effort readable roots for \(configuration.name)")
            return true
        }
    }

    @MainActor
    private func refreshLegacyPortholeBindings(reason: String) {
        rebuildLegacyPortholeViewModel(reason: reason)
        legacyPortholeViewModel.markLocalMutation()
    }

    private func loadConfigurationIntoPortholeWithTimeout(
        _ configuration: CellConfiguration,
        on porthole: OrchestratorCell,
        requester: Identity
    ) async throws {
        let timeoutNanoseconds = configurationLoadTimeoutNanoseconds(for: configuration)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await prepareRemoteReferenceAdmissionIfNeeded(
                    for: configuration,
                    requester: requester
                )
                try await porthole.loadCellConfiguration(configuration, requester: requester)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw ConfigurationLoadTimeoutError(configurationName: configuration.name)
            }

            guard let _ = try await group.next() else {
                throw ConfigurationLoadTimeoutError(configurationName: configuration.name)
            }
            group.cancelAll()
        }
    }

    private func prepareRemoteReferenceAdmissionIfNeeded(
        for configuration: CellConfiguration,
        requester: Identity
    ) async throws {
        guard let resolver = CellBase.defaultCellResolver as? CellResolver else { return }
        for endpoint in remoteRegistrationEndpoints(in: configuration) {
            guard await RemoteEndpointAccessSupport.authorizationKind(for: endpoint) != .none else {
                continue
            }
            _ = try await RemoteEndpointAccessSupport.resolveEmit(
                endpoint: endpoint,
                resolver: resolver,
                requester: requester,
                accessLabel: "Binding load: \(configuration.name)"
            )
        }
    }

    func configurationLoadTimeoutNanoseconds(for configuration: CellConfiguration) -> UInt64 {
        let normalizedName = configuration.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalizedName == "conference ai assistant" {
            return 30_000_000_000
        }
        if normalizedName == "conference public surface" {
            return 20_000_000_000
        }
        return 10_000_000_000
    }

    private func waitForReadableBindingRoots(
        _ probes: [SkeletonBindingProbeSupport.RootProbe],
        on porthole: Meddle,
        requester: Identity,
        configurationName: String,
        requestID: UUID
    ) async -> RootBindingAvailability {
        let maxAttempts = 5
        let retryDelayNanoseconds: UInt64 = 300_000_000
        let perProbeTimeoutNanoseconds: UInt64 = 900_000_000
        var failures: [SkeletonBindingProbeSupport.RootProbe: String] = [:]

        for attempt in 1...maxAttempts {
            guard !Task.isCancelled else {
                return .failed(failures)
            }

            failures = await readBindingProbeFailures(
                probes,
                on: porthole,
                requester: requester,
                timeoutNanoseconds: perProbeTimeoutNanoseconds
            )

            if failures.isEmpty {
                return .ready(attempts: attempt)
            }

            if attempt < maxAttempts {
                updateLoadingStatus(
                    "Venter på preview-state for \(configurationName)… (\(attempt)/\(maxAttempts))",
                    requestID: requestID
                )
                try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
            }
        }

        return .failed(failures)
    }

    private func readBindingProbeFailures(
        _ probes: [SkeletonBindingProbeSupport.RootProbe],
        on porthole: Meddle,
        requester: Identity,
        timeoutNanoseconds: UInt64
    ) async -> [SkeletonBindingProbeSupport.RootProbe: String] {
        await withTaskGroup(of: (SkeletonBindingProbeSupport.RootProbe, String?).self) { group in
            for probe in probes {
                group.addTask {
                    do {
                        let value = try await readBindingProbeValue(
                            probe,
                            on: porthole,
                            requester: requester,
                            timeoutNanoseconds: timeoutNanoseconds
                        )
                        return (probe, SkeletonBindingProbeSupport.failureDetail(from: value))
                    } catch {
                        return (probe, String(describing: error))
                    }
                }
            }

            var failures: [SkeletonBindingProbeSupport.RootProbe: String] = [:]
            for await (probe, failure) in group {
                if let failure {
                    failures[probe] = failure
                }
            }
            return failures
        }
    }

    private func readBindingProbeValue(
        _ probe: SkeletonBindingProbeSupport.RootProbe,
        on porthole: Meddle,
        requester: Identity,
        timeoutNanoseconds: UInt64
    ) async throws -> ValueType {
        try await withThrowingTaskGroup(of: ValueType.self) { group in
            group.addTask {
                try await porthole.get(keypath: probe.qualifiedKeypath, requester: requester)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw BindingProbeTimeoutError(keypath: probe.qualifiedKeypath)
            }

            guard let firstResult = try await group.next() else {
                throw BindingProbeTimeoutError(keypath: probe.qualifiedKeypath)
            }
            group.cancelAll()
            return firstResult
        }
    }

    private func summarizeBindingFailures(
        _ failures: [SkeletonBindingProbeSupport.RootProbe: String]
    ) -> String {
        failures
            .sorted { lhs, rhs in
                lhs.key.qualifiedKeypath < rhs.key.qualifiedKeypath
            }
            .prefix(3)
            .map { probe, detail in
                "\(probe.qualifiedKeypath): \(detail)"
            }
            .joined(separator: " | ")
    }

    func localConferencePreviewFallbackConfiguration(
        for configuration: CellConfiguration,
        failureDetails: [String]
    ) -> CellConfiguration? {
        guard failureDetails.contains(where: isConferencePreviewFallbackFailure) else {
            return nil
        }
        guard let references = configuration.cellReferences else {
            return nil
        }

        let normalizedName = configuration.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if normalizedName == "conference ai assistant" {
            return ConfigurationCatalogCell.conferenceAIAssistantWorkbenchConfiguration(
                conferenceEndpoint: "cell:///ConferenceParticipantPreviewShell",
                aiEndpoint: "cell:///ConferenceAIAssistantGatewayProxy"
            )
        }

        let remoteReferences = references.filter { reference in
            RemoteCatalogSupport.isRemoteEndpoint(reference.endpoint)
        }
        guard remoteReferences.count == 1,
              let primaryReference = remoteReferences.first,
              RemoteCatalogSupport.isRemoteEndpoint(primaryReference.endpoint)
        else {
            return nil
        }

        switch remoteCellName(from: primaryReference.endpoint) {
        case "conferenceparticipantpreviewshell":
            return ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
                endpoint: "cell:///ConferenceParticipantPreviewShell"
            )
        case "conferenceadminpreviewshell":
            return ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
                endpoint: "cell:///ConferenceAdminPreviewShell"
            )
        default:
            return nil
        }
    }

    private func isConferencePreviewFallbackFailure(_ detail: String) -> Bool {
        let normalized = detail
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized.contains("denied")
            || normalized.contains("timeout")
            || normalized.contains("notconnected")
            || normalized.contains("finishedwithoutvalue")
            || normalized.contains("websocket must be connected")
            || normalized.contains("bad response from the server")
            || normalized.contains("ikke tilgjengelig akkurat nå")
            || normalized.contains("midlertidig utilgjengelig")
    }

    private func loadingPlaceholderSkeleton(for configuration: CellConfiguration) -> SkeletonElement {
        placeholderSkeleton(
            title: configuration.name,
            status: "Laster innhold…",
            detail: "Binding venter på at preview-state og bridge-references skal bli lesbare."
        )
    }

    private func failurePlaceholderSkeleton(for configuration: CellConfiguration, detail: String) -> SkeletonElement {
        placeholderSkeleton(
            title: configuration.name,
            status: "Kunne ikke hente innhold",
            detail: detail
        )
    }

    private func placeholderSkeleton(title: String, status: String, detail: String) -> SkeletonElement {
        var titleText = SkeletonText(text: title)
        titleText.modifiers = contentViewModifier {
            $0.fontStyle = "title2"
            $0.fontWeight = "semibold"
            $0.padding = 4
        }

        var statusText = SkeletonText(text: status)
        statusText.modifiers = contentViewModifier {
            $0.fontWeight = "semibold"
            $0.padding = 4
        }

        var detailText = SkeletonText(text: detail)
        detailText.modifiers = contentViewModifier {
            $0.foregroundColor = "#475569"
            $0.padding = 4
            $0.lineLimit = 6
        }

        var stack = SkeletonVStack(elements: [
            .Text(titleText),
            .Text(statusText),
            .Text(detailText)
        ])
        stack.modifiers = contentViewModifier {
            $0.padding = 20
            $0.background = "#F8FAFC"
            $0.cornerRadius = 18
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
            $0.maxWidthInfinity = true
        }

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(stack)])
        scroll.modifiers = contentViewModifier {
            $0.background = "#EDF2F7"
            $0.padding = 16
        }
        return .ScrollView(scroll)
    }

    nonisolated private enum RootBindingAvailability {
        case ready(attempts: Int)
        case failed([SkeletonBindingProbeSupport.RootProbe: String])
    }

    nonisolated private struct BindingProbeTimeoutError: LocalizedError {
        let keypath: String

        var errorDescription: String? {
            "Timeout while reading \(keypath)"
        }
    }

    nonisolated private struct ConfigurationLoadTimeoutError: LocalizedError {
        let configurationName: String

        var errorDescription: String? {
            "Timeout while loading \(configurationName) into Porthole"
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

    private func currentEditorSeedSourceBackedContext() -> EditorSourceBackedContext? {
        if let context = activeSourceBackedContext {
            return context
        }
        return editorState.currentSourceBackedContext
    }

    private func makeSourceBackedContext(
        from editableState: BindingEditableCellConfigurationContract.State
    ) -> EditorSourceBackedContext {
        EditorSourceBackedContext(
            committedSourceRevision: editableState.revision,
            hasStoredOverride: editableState.hasStoredOverride,
            canEdit: editableState.canEdit,
            sourceCellEndpoint: editableState.sourceCellEndpoint,
            sourceCellName: editableState.sourceCellName,
            accessSummary: editableState.accessSummary
        )
    }

    private func prepareEditableConfiguration(
        _ configuration: CellConfiguration,
        fallback: CellConfiguration
    ) -> CellConfiguration {
        var prepared = configuration
        if prepared.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prepared.name = fallback.name
        }
        if prepared.description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            prepared.description = fallback.description
        }
        if prepared.discovery == nil {
            prepared.discovery = fallback.discovery
        }
        if prepared.skeleton == nil {
            prepared.skeleton = fallback.skeleton ?? viewModel.currentSkeleton
        }
        return canonicalizeSkeletonReferencesIfNeeded(in: prepared)
    }

    private func resolveEditableConfigurationForCurrentRequester(
        _ configuration: CellConfiguration,
        requester: Identity?,
        timeoutNanoseconds: UInt64? = nil
    ) async -> (configuration: CellConfiguration, context: EditorSourceBackedContext)? {
        guard let requester,
              let editableState = await editableStateForCurrentRequester(
                configuration,
                requester: requester,
                timeoutNanoseconds: timeoutNanoseconds
              ) else {
            return nil
        }

        let prepared = prepareEditableConfiguration(
            editableState.configuration,
            fallback: editableState.fallbackConfiguration
        )
        return (
            configuration: prepared,
            context: makeSourceBackedContext(from: editableState)
        )
    }

    private func editableStateForCurrentRequester(
        _ configuration: CellConfiguration,
        requester: Identity,
        timeoutNanoseconds: UInt64?
    ) async -> BindingEditableCellConfigurationContract.State? {
        guard let timeoutNanoseconds else {
            return await BindingSourceBackedConfigurationEditingSupport.editableState(
                for: configuration,
                requester: requester
            )
        }

        return await withTaskGroup(of: BindingEditableCellConfigurationContract.State?.self) { group in
            group.addTask {
                await BindingSourceBackedConfigurationEditingSupport.editableState(
                    for: configuration,
                    requester: requester
                )
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return nil
            }

            let state = await group.next() ?? nil
            group.cancelAll()
            return state
        }
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
            componentPlacementState.clear()
            compactComponentsExpanded = false
            compactInspectorExpanded = true
            withAnimation(.easeInOut(duration: 0.2)) {
                compactEditorDrawerVisible = true
            }
        }
        return inserted
    }

    private func hydrateSparseConfigurationIfNeeded(
        _ configuration: CellConfiguration,
        resolver: CellResolver,
        identity: Identity
    ) async -> CellConfiguration {
        let hasSkeleton = configuration.skeleton != nil
        let hasReferences = !(configuration.cellReferences?.isEmpty ?? true)
        guard !hasSkeleton, hasReferences else {
            return configuration
        }

        guard let references = configuration.cellReferences else {
            return configuration
        }

        for reference in references {
            guard let recovered = await recoverConfigurationFromEndpoint(
                reference.endpoint,
                resolver: resolver,
                identity: identity
            ) else {
                continue
            }

            var merged = recovered
            if merged.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                merged.name = configuration.name
            }
            if merged.description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                merged.description = configuration.description
            }
            if merged.discovery == nil {
                merged.discovery = configuration.discovery
            }
            return merged
        }

        return configuration
    }

    private func recoverRemoteConfigurationOnDemandIfNeeded(
        _ configuration: CellConfiguration,
        resolver: CellResolver,
        identity: Identity
    ) async -> CellConfiguration {
        guard RemoteCatalogSupport.shouldRecoverConfigurationOnDemand(configuration) else {
            return configuration
        }
        guard let references = configuration.cellReferences else {
            return configuration
        }

        for reference in references {
            guard RemoteCatalogSupport.isRemoteEndpoint(reference.endpoint) else { continue }
            guard let recovered = await recoverConfigurationFromEndpoint(
                reference.endpoint,
                resolver: resolver,
                identity: identity
            ) else {
                continue
            }

            var merged = recovered
            if merged.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                merged.name = configuration.name
            }
            if merged.description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                merged.description = configuration.description
            }
            if merged.discovery == nil {
                merged.discovery = configuration.discovery
            }
            return merged
        }

        return configuration
    }

    private func armComponentPlacement(_ item: ComponentPaletteItem?) {
        componentPlacementState.activeDragItem = nil
        componentPlacementState.armedItem = item

        guard item != nil else { return }
        compactComponentsExpanded = true
        compactInspectorExpanded = true
        withAnimation(.easeInOut(duration: 0.2)) {
            compactEditorDrawerVisible = true
        }
    }

    @ViewBuilder
    private func compactDrawerSectionLabel(title: String, badge: String, tint: Color = .secondary) -> some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer(minLength: 0)
            PanelBadge(text: badge, tint: tint)
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

    func preferredRequesterDescriptor(for configuration: CellConfiguration) -> RemoteRequesterDescriptor? {
        var descriptors = Set((configuration.cellReferences ?? []).compactMap { preferredRequesterDescriptor(for: $0.endpoint) })
        if descriptors.isEmpty,
           let endpoint = configuration.discovery?.sourceCellEndpoint,
           let descriptor = preferredRequesterDescriptor(for: endpoint) {
            descriptors.insert(descriptor)
        }
        guard descriptors.count == 1 else {
            return nil
        }
        return descriptors.first
    }

    func preferredRequesterDescriptor(for endpoint: String) -> RemoteRequesterDescriptor? {
        guard let cellName = remoteCellName(from: endpoint) else {
            return nil
        }

        let organizerContext = remoteScopedIdentityContext(
            baseContext: "conference-organizer",
            endpoint: endpoint
        )
        let publicPublisherContext = remoteScopedIdentityContext(
            baseContext: "conference-public-publisher",
            endpoint: endpoint
        )

        switch cellName {
        case "conferenceparticipantpreviewshell",
             "conferenceaigatewaypreview",
             "conferencepublicprofilepreview",
             "conferencepublicprofileeditorpreview":
            return previewRequesterDescriptor(
                baseContext: "conference-participant-preview:\(Self.defaultConferenceParticipantPreviewID)",
                displayName: "Conference Participant Preview",
                endpoint: endpoint
            )
        case "conferenceadminpreviewshell":
            return previewRequesterDescriptor(
                baseContext: "conference-admin-preview:\(Self.defaultConferenceAdminPreviewID)",
                displayName: "Conference Admin Preview",
                endpoint: endpoint
            )
        case "conferenceadminshell", "conferenceuirouter":
            return RemoteRequesterDescriptor(
                identityContext: organizerContext,
                displayName: "Conference Organizer"
            )
        case "conferencepublicshell":
            return RemoteRequesterDescriptor(
                identityContext: publicPublisherContext,
                displayName: "Conference Public Publisher"
            )
        case "conferencesponsorshell":
            let sponsorOrganizationID = Self.defaultConferenceSponsorOrganizationID
            return RemoteRequesterDescriptor(
                identityContext: remoteScopedIdentityContext(
                    baseContext: "conference-sponsor:\(sponsorOrganizationID)",
                    endpoint: endpoint
                ),
                displayName: sponsorOrganizationID
            )
        default:
            return nil
        }
    }

    private func previewRequesterDescriptor(
        baseContext: String,
        displayName: String,
        endpoint: String
    ) -> RemoteRequesterDescriptor {
        RemoteRequesterDescriptor(
            identityContext: remoteScopedIdentityContext(
                baseContext: baseContext,
                endpoint: endpoint
            ),
            displayName: displayName
        )
    }

    private func remoteScopedIdentityContext(baseContext: String, endpoint: String) -> String {
        guard let components = URLComponents(string: endpoint),
              let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              host.isEmpty == false else {
            return baseContext
        }

        if let port = components.port {
            return "\(baseContext)@\(host):\(port)"
        }
        return "\(baseContext)@\(host)"
    }

    private func remoteCellName(from endpoint: String) -> String? {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let components = URLComponents(string: trimmed) {
            let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if let last = path.split(separator: "/").last {
                return String(last).lowercased()
            }
        }

        return trimmed
            .split(separator: "/")
            .last
            .map(String.init)?
            .lowercased()
    }

    private func privateRequesterIdentity() async -> Identity? {
        await CellBase.defaultIdentityVault?.identity(for: "private", makeNewIfNotFound: true)
    }

    private func startupRequesterIdentity() async -> Identity? {
        await BindingStartupIdentityVault.shared.identity(for: "private", makeNewIfNotFound: true)
    }

#if !canImport(AppKit)
    @MainActor
    private func focusConferenceAutomationWindow() {
        // iOS has no top-level app window automation to focus.
    }
#endif

#if canImport(AppKit)
    @MainActor
    private func focusConferenceAutomationWindow() {
        guard let window = conferenceAutomationWindow else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @MainActor
    private func applyConferenceAutomationWindowPreset(width: CGFloat, height: CGFloat) {
        guard let window = conferenceAutomationWindow else { return }
        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? window.frame
        let targetWidth = min(width, visibleFrame.width)
        let targetHeight = min(height, visibleFrame.height)
        var frame = window.frame
        frame.size = CGSize(width: targetWidth, height: targetHeight)
        frame.origin.x = visibleFrame.midX - (targetWidth / 2)
        frame.origin.y = visibleFrame.midY - (targetHeight / 2)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.setFrame(frame.integral, display: true, animate: true)
    }

    @MainActor
    private func centerConferenceAutomationWindow() {
        guard let window = conferenceAutomationWindow else { return }
        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? window.frame
        var frame = window.frame
        frame.origin.x = visibleFrame.midX - (frame.width / 2)
        frame.origin.y = visibleFrame.midY - (frame.height / 2)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.setFrame(frame.integral, display: true, animate: true)
    }

    @MainActor
    private var conferenceAutomationWindow: NSWindow? {
        if let hostingWindowNumber,
           let matchingWindow = NSApp.windows.first(where: { $0.windowNumber == hostingWindowNumber }) {
            return matchingWindow
        }
        return NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible })
    }
#endif

    private func requesterIdentity(
        for descriptor: RemoteRequesterDescriptor?,
        fallback: Identity?
    ) async -> Identity? {
        guard let descriptor else {
            return fallback
        }
        guard let vault = CellBase.defaultIdentityVault else {
            return fallback
        }

        if let identity = await vault.identity(for: descriptor.identityContext, makeNewIfNotFound: false) {
            identity.displayName = descriptor.displayName
            return identity
        }
        if let identity = await vault.identity(for: descriptor.identityContext, makeNewIfNotFound: true) {
            identity.displayName = descriptor.displayName
            return identity
        }
        return fallback
    }

    private func routesMatch(_ lhs: RemoteCellHostRoute, _ rhs: RemoteCellHostRoute) -> Bool {
        let lhsPath = lhs.websocketEndpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        let rhsPath = rhs.websocketEndpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        guard lhsPath == rhsPath else { return false }
        guard schemePreferenceLabel(lhs.schemePreference) == schemePreferenceLabel(rhs.schemePreference) else {
            return false
        }
        return pathLayoutLabel(lhs.pathLayout) == pathLayoutLabel(rhs.pathLayout)
    }

    private func schemePreferenceLabel(_ preference: RemoteCellHostRoute.SchemePreference) -> String {
        switch preference {
        case .automatic: return "automatic"
        case .ws: return "ws"
        case .wss: return "wss"
        }
    }

    private func pathLayoutLabel(_ layout: RemoteCellHostRoute.PathLayout) -> String {
        switch layout {
        case .endpointThenPublisherUUID:
            return "endpoint-then-publisher"
        case .publisherUUIDThenEndpoint:
            return "publisher-then-endpoint"
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
        guard BindingRuntimeBootstrap.authenticatedRuntimeIsReady else {
            return .empty
        }

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
            return ["scaffold chat", "conference public surface", "conference mvp", "todo mvp", "notification outbox"]
        case .upperMid:
            return ["conference scaffold setup & identity link", "apple intelligence purpose matcher", "conference ai assistant", "conference participant portal dashboard", "catalog workbench", "perspective context", "porthole control surface"]
        case .upperRight:
            return ["conference mvp", "conference participant portal dashboard", "conference scaffold setup & identity link", "conference sponsor follow-up", "conference control tower", "obsidian vault", "vault control surface", "porthole control surface", "lead vault"]
        case .lowerLeft:
            return ["entity scanner", "perspective context", "entity anchor records", "trusted issuers registry", "entity scanner test helper", "entity scanner pairing checklist"]
        case .lowerMid:
            return ["conference scaffold setup & identity link", "todo mvp", "conference participant portal dashboard", "conference ai assistant", "conference sponsor follow-up", "catalog workbench", "folder watch automation", "graph index control", "perspective context", "device registration"]
        case .lowerRight:
            return ["obsidian vault", "vault control surface", "graph index control", "porthole control surface", "trusted issuers registry", "consent receipt"]
        }
    }

    private func convenienceDomainKeywords(for slot: ConvenienceMenuSlot) -> [String] {
        switch slot {
        case .upperLeft:
            return ["chat", "communication", "collaboration", "conference", "public"]
        case .upperMid:
            return ["assistant", "purpose", "matching", "tools", "conference", "copilot", "identity-link", "setup", "enrollment"]
        case .upperRight:
            return ["conference", "event", "lead", "consent", "sponsor", "operations", "admin", "identity-link", "setup"]
        case .lowerLeft:
            return ["scanner", "identity", "trust", "credentials", "proofs", "nearby"]
        case .lowerMid:
            return ["todo", "tasks", "planning", "productivity", "context", "conference", "meetings", "identity-link", "setup", "proofs"]
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
        guard let identity = await privateRequesterIdentity() else {
            return ReferenceProbeResult(
                failingReferenceEndpoints: Set(references.map { endpointIdentity($0.endpoint) }),
                firstFailureMessage: "Identity 'private' mangler. Kunne ikke laste konfigurasjonen."
            )
        }

        let outcomes = await withTaskGroup(of: (endpoint: String, failure: String?).self) { group in
            for reference in references {
                group.addTask {
                    let failure = await probeReferenceTree(
                        reference,
                        resolver: resolver,
                        identity: identity,
                        probeDirectEndpoint: true
                    )
                    return (reference.endpoint, failure)
                }
            }

            var outcomes: [(endpoint: String, failure: String?)] = []
            for await outcome in group {
                outcomes.append(outcome)
            }
            return outcomes
        }

        var failures = Set<String>()
        var firstMessage: String?
        for outcome in outcomes {
            if let failure = outcome.failure {
                if isNonBlockingProbeFailure(failure) {
                    diagnosticsStore.record(
                        severity: .warning,
                        domain: "binding.probe",
                        message: "Non-blocking bridge preflight issue for \(outcome.endpoint): \(failure)"
                    )
                } else {
                    failures.insert(endpointIdentity(outcome.endpoint))
                    if firstMessage == nil {
                        firstMessage = failure
                    }
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
            let requester = await requesterIdentity(
                for: preferredRequesterDescriptor(for: reference.endpoint),
                fallback: identity
            ) ?? identity
            do {
                _ = try await probeRemoteEndpoint(
                    endpoint: reference.endpoint,
                    resolver: resolver,
                    requester: requester,
                    accessLabel: "binding.probe"
                )
            } catch {
                if await tryProbeEndpointWithFallbackRoutes(reference.endpoint, resolver: resolver, identity: requester) {
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
            let requester = await requesterIdentity(
                for: preferredRequesterDescriptor(for: target),
                fallback: identity
            ) ?? identity
            do {
                _ = try await probeRemoteEndpoint(
                    endpoint: target,
                    resolver: resolver,
                    requester: requester,
                    accessLabel: "binding.probe"
                )
            } catch {
                if await tryProbeEndpointWithFallbackRoutes(target, resolver: resolver, identity: requester) {
                    continue
                }
                return probeFailureMessage(endpoint: target, error: error)
            }
        }

        return nil
    }

    private func probeRemoteEndpoint(
        endpoint: String,
        resolver: CellResolver,
        requester: Identity,
        accessLabel: String
    ) async throws -> Emit {
        let timeoutNanoseconds: UInt64 = 1_500_000_000

        return try await withThrowingTaskGroup(of: Emit.self) { group in
            group.addTask {
                try await RemoteEndpointAccessSupport.resolveEmit(
                    endpoint: endpoint,
                    resolver: resolver,
                    requester: requester,
                    accessLabel: accessLabel
                )
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw BindingProbeTimeoutError(keypath: endpoint)
            }

            guard let emit = try await group.next() else {
                throw BindingProbeTimeoutError(keypath: endpoint)
            }
            group.cancelAll()
            return emit
        }
    }

    private func tryProbeEndpointWithFallbackRoutes(_ endpoint: String, resolver: CellResolver, identity: Identity) async -> Bool {
        guard let components = URLComponents(string: endpoint),
              components.scheme?.lowercased() == "cell",
              let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              host == Self.stagingHost
        else {
            return false
        }

        let canonicalRoute = RemoteCellHostRoute(
            websocketEndpoint: Self.stagingRemoteWebSocketPath,
            schemePreference: .wss,
            pathLayout: .endpointThenPublisherUUID
        )
        registerRemoteHostIfNeeded(host, route: canonicalRoute, resolver: resolver)
        do {
            _ = try await probeRemoteEndpoint(
                endpoint: endpoint,
                resolver: resolver,
                requester: identity,
                accessLabel: "binding.probe"
            )
            return true
        } catch {
            return false
        }
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

    private func probeFailureMessage(endpoint: String, error: Error) -> String {
        let errorText = String(describing: error)
        let normalized = errorText.lowercased()
        if normalized.contains("bad response from the server") || normalized.contains("502") {
            return "Staging svarte med ugyldig websocket-respons for \(endpoint). Sjekk bridgehead/nginx."
        }
        if normalized.contains("notconnected") || normalized.contains("transportunavailable") {
            return "Bridge-forbindelsen til \(endpoint) ble brutt før data kunne leses."
        }
        if normalized.contains("timeout") {
            return "Timeout ved lasting av \(endpoint). Sjekk staging websocket-route (bridgehead)."
        }
        return "Kunne ikke laste \(endpoint): \(errorText)"
    }

    private func isNonBlockingProbeFailure(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("timeout ved lasting") ||
            normalized.contains("bridge-forbindelsen") ||
            normalized.contains("transport")
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
        let requester = await requesterIdentity(
            for: preferredRequesterDescriptor(for: endpoint),
            fallback: identity
        ) ?? identity

        guard let cell = try? await resolveRemoteConfigurationCell(
            endpoint: endpoint,
            resolver: resolver,
            requester: requester
        )
        else {
            return await cachedRecoveredConfiguration(
                for: endpoint,
                resolver: resolver
            )
        }

        let recoveryKeypaths = ["skeletonConfiguration", "purposeGoal", "configuration"]
        let recoveredValues = await recoveredConfigurationValues(
            from: cell,
            requester: requester,
            keypaths: recoveryKeypaths
        )

        for keypath in recoveryKeypaths {
            guard let value = recoveredValues[keypath],
                  let recoveredConfiguration = PortableSurfaceContractSupport.extractConfiguration(from: value)
            else {
                continue
            }

            await PortableSurfaceCacheStore.shared.storeConfiguration(
                recoveredConfiguration,
                endpoint: endpoint
            )
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

        return await cachedRecoveredConfiguration(
            for: endpoint,
            resolver: resolver
        )
    }

    private func resolveRemoteConfigurationCell(
        endpoint: String,
        resolver: CellResolver,
        requester: Identity
    ) async throws -> Meddle {
        guard RemoteCatalogSupport.isRemoteEndpoint(endpoint) else {
            return try await RemoteEndpointAccessSupport.resolveMeddle(
                endpoint: endpoint,
                resolver: resolver,
                requester: requester,
                accessLabel: "binding.recoverConfiguration"
            )
        }

        let timeoutNanoseconds: UInt64 = 4_000_000_000
        return try await withThrowingTaskGroup(of: Meddle.self) { group in
            group.addTask {
                try await RemoteEndpointAccessSupport.resolveMeddle(
                    endpoint: endpoint,
                    resolver: resolver,
                    requester: requester,
                    accessLabel: "binding.recoverConfiguration"
                )
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw BindingProbeTimeoutError(keypath: endpoint)
            }

            guard let cell = try await group.next() else {
                throw BindingProbeTimeoutError(keypath: endpoint)
            }
            group.cancelAll()
            return cell
        }
    }

    private func recoveredConfigurationValues(
        from cell: Meddle,
        requester: Identity,
        keypaths: [String]
    ) async -> [String: ValueType] {
        await withTaskGroup(of: (String, ValueType?).self) { group in
            for keypath in keypaths {
                group.addTask {
                    let value = await readRecoveredConfigurationValue(
                        keypath,
                        from: cell,
                        requester: requester,
                        timeoutNanoseconds: 2_000_000_000
                    )
                    return (keypath, value)
                }
            }

            var values: [String: ValueType] = [:]
            for await (keypath, value) in group {
                if let value {
                    values[keypath] = value
                }
            }
            return values
        }
    }

    private func readRecoveredConfigurationValue(
        _ keypath: String,
        from cell: Meddle,
        requester: Identity,
        timeoutNanoseconds: UInt64
    ) async -> ValueType? {
        await withTaskGroup(of: ValueType?.self) { group in
            group.addTask {
                try? await cell.get(keypath: keypath, requester: requester)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return nil
            }

            let value = await group.next() ?? nil
            group.cancelAll()
            return value
        }
    }

    private func extractConfigurationFromRecoveredValue(_ value: ValueType) -> CellConfiguration? {
        PortableSurfaceContractSupport.extractConfiguration(from: value)
    }

    private func decodeCellConfiguration(from value: ValueType?) -> CellConfiguration? {
        PortableSurfaceContractSupport.decodeCellConfiguration(from: value)
    }

    private func cachedRecoveredConfiguration(
        for endpoint: String,
        resolver: CellResolver
    ) async -> CellConfiguration? {
        guard let recoveredConfiguration = await PortableSurfaceCacheStore.shared.configuration(for: endpoint) else {
            return nil
        }

        let origin = catalogOrigin(from: endpoint)
        let normalized = normalizeConfigurationForResolver(
            recoveredConfiguration,
            origin: origin,
            resolver: resolver
        )
        return sanitizedLoadedConfiguration(normalized, allowReferenceFree: false)
    }

    private func remoteRegistrationEndpoints(in configuration: CellConfiguration) -> Set<String> {
        var endpoints: Set<String> = []
        if let discoveryEndpoint = configuration.discovery?.sourceCellEndpoint?.trimmingCharacters(in: .whitespacesAndNewlines),
           !discoveryEndpoint.isEmpty {
            endpoints.insert(discoveryEndpoint)
        }

        for reference in configuration.cellReferences ?? [] {
            collectEndpointStrings(from: reference, into: &endpoints)
        }
        return endpoints
    }

    private func collectEndpointStrings(from reference: CellReference, into endpoints: inout Set<String>) {
        let endpoint = reference.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if !endpoint.isEmpty {
            endpoints.insert(endpoint)
        }

        for subscription in reference.subscriptions {
            collectEndpointStrings(from: subscription, into: &endpoints)
        }

        for keyValue in reference.setKeysAndValues {
            guard let target = keyValue.target?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !target.isEmpty
            else {
                continue
            }
            endpoints.insert(target)
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

    static func conferenceAdminMenuSeedConfiguration() -> CellConfiguration {
        ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration()
    }

    static func conferenceParticipantPortalMenuSeedConfiguration() -> CellConfiguration {
        ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration()
    }

    static func conferenceDemoLauncherMenuSeedConfiguration() -> CellConfiguration {
        ConfigurationCatalogCell.conferenceDemoLauncherWorkbenchConfiguration()
    }

    static func defaultDemoStartConfiguration() -> CellConfiguration {
        if BindingPersonalCopilotV1Policy.appStoreCatalogGateEnabled {
            return ConfigurationCatalogCell.personalInviteChatMenuConfiguration()
        }
        return conferenceDemoLauncherMenuSeedConfiguration()
    }

    static func conferenceIdentityLinkMenuSeedConfiguration() -> CellConfiguration {
        ConfigurationCatalogCell.conferenceIdentityLinkWorkbenchConfiguration()
    }

    static func conferenceAIAssistantAutomationConfiguration() -> CellConfiguration {
        ConfigurationCatalogCell.conferenceAIAssistantWorkbenchConfiguration(
            conferenceEndpoint: "cell:///ConferenceParticipantPreviewShell",
            aiEndpoint: "cell:///ConferenceAIAssistantGatewayProxy"
        )
    }

    static func conferenceMVPAutomationConfiguration() -> CellConfiguration {
        ConfigurationCatalogCell.conferenceMVPWorkbenchMenuConfiguration(
            endpoint: "cell://\(Self.stagingHost)/ConferenceUIRouter"
        )
    }

    static func conferencePublicAutomationConfiguration() -> CellConfiguration {
        ConfigurationCatalogCell.conferencePublicWorkbenchConfiguration(
            endpoint: "cell://\(Self.stagingHost)/ConferencePublicShell"
        )
    }

    static func conferenceSponsorAutomationConfiguration() -> CellConfiguration {
        ConfigurationCatalogCell.conferenceSponsorWorkbenchConfiguration(
            endpoint: "cell://\(Self.stagingHost)/ConferenceSponsorShell"
        )
    }

    static func agentSetupAutomationConfiguration() -> CellConfiguration {
        ConfigurationCatalogCell.agentSetupWorkbenchConfiguration()
    }

    static let conferenceAutomationDefaultsKey = "Binding.EnableConferenceAutomation"

    static func conferenceAutomationGlobalOptInEnabled(
        environment: [String: String],
        launchArguments: [String],
        persistedOptIn: Bool
    ) -> Bool {
        conferenceAutomationEnabled(
            debugPanelVisible: false,
            environment: environment,
            launchArguments: launchArguments,
            persistedOptIn: persistedOptIn
        )
    }

    static func conferenceAutomationEnabled(
        debugPanelVisible: Bool,
        environment: [String: String],
        launchArguments: [String],
        persistedOptIn: Bool
    ) -> Bool {
#if DEBUG
        if debugPanelVisible || persistedOptIn {
            return true
        }

        if launchArguments.contains("--enable-conference-automation") {
            return true
        }

        let rawValue = environment["BINDING_ENABLE_CONFERENCE_AUTOMATION"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return rawValue == "1" || rawValue == "true" || rawValue == "yes"
#else
        _ = debugPanelVisible
        _ = environment
        _ = launchArguments
        _ = persistedOptIn
        return false
#endif
    }

    static func matchesConferenceAutomationWindow(
        targetWindowNumber: Int,
        hostingWindowNumber: Int?
    ) -> Bool {
        guard let hostingWindowNumber else { return false }
        return hostingWindowNumber == targetWindowNumber
    }

    static func conferenceAutomationHook(from url: URL) -> ConferenceAutomationHook? {
        guard url.scheme?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "haven" else {
            return nil
        }

        let normalizedHost = url.host?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let normalizedPath = url.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()

        let isAutomationRoute = normalizedHost == "conference-automation"
            || normalizedPath == "conference-automation"
        guard isAutomationRoute else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryAction = components?.queryItems?.first(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "action"
        })?.value

        let pathComponents = normalizedPath
            .split(separator: "/")
            .map(String.init)
        let fallbackAction = pathComponents.last.flatMap { last -> String? in
            guard last != "conference-automation" else { return nil }
            return last
        }

        let rawAction = (queryAction ?? fallbackAction)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard let rawAction, !rawAction.isEmpty else { return nil }
        return ConferenceAutomationHook(rawValue: rawAction)
    }

    private func curatedMenuSeedConfigurations() -> MenuConfigurationBuckets {
        guard !BindingPersonalCopilotV1Policy.conferenceDemoMenusEnabled else {
            return conferenceDemoMenuSeedConfigurations()
        }

        let personalHome = ConfigurationCatalogCell.personalHomeMenuConfiguration()
        let myProfile = ConfigurationCatalogCell.personalProfileMenuConfiguration()
        let publishProfile = ConfigurationCatalogCell.personalPublicProfileMenuConfiguration()
        let matches = ConfigurationCatalogCell.personalMatchesMenuConfiguration()
        let inviteChat = ConfigurationCatalogCell.personalInviteChatMenuConfiguration()
        let agendaContext = ConfigurationCatalogCell.personalAgendaContextMenuConfiguration()
        let vaultIdeas = ConfigurationCatalogCell.personalVaultIdeasMenuConfiguration()
        let meetingIntent = ConfigurationCatalogCell.personalMeetingIntentMenuConfiguration()
        let privacyAudit = ConfigurationCatalogCell.personalPrivacyAuditMenuConfiguration()
        let appleIntelligence = ConfigurationCatalogCell.appleIntelligenceLandingForPersonalCopilotConfiguration()
        let entityScanner = ConfigurationCatalogCell.entityScannerForPersonalCopilotConfiguration()
        let workflowStudio = ConfigurationCatalogCell.workflowStudioForPersonalCopilotConfiguration()
        var upperMid = [myProfile, publishProfile, appleIntelligence, workflowStudio]
        var upperRight = [agendaContext, vaultIdeas, meetingIntent]
        var lowerLeft = [entityScanner, privacyAudit]
        var lowerMid = [workflowStudio, inviteChat, matches]
        var lowerRight = [agendaContext, vaultIdeas, meetingIntent, privacyAudit]
        if BindingPersonalCopilotV1Policy.conferenceShowcaseEnabled {
            let conferenceCodex = ConfigurationCatalogCell.conferenceCodexLiveConfigurationsMenuConfiguration()
            let conferenceClaude = ConfigurationCatalogCell.conferenceClaudeDesignReferenceMenuConfiguration()
            upperMid.append(conferenceCodex)
            upperRight.append(contentsOf: [conferenceCodex, conferenceClaude])
            lowerLeft.append(conferenceCodex)
            lowerMid.append(contentsOf: [conferenceCodex, conferenceClaude])
            lowerRight.append(contentsOf: [conferenceCodex, conferenceClaude])
        }

        return (
            upperLeft: [personalHome, inviteChat, matches],
            upperMid: upperMid,
            upperRight: upperRight,
            lowerLeft: lowerLeft,
            lowerMid: lowerMid,
            lowerRight: lowerRight
        )
    }

    private func conferenceDemoMenuSeedConfigurations() -> MenuConfigurationBuckets {
        func stagingEndpoint(_ cellName: String) -> String {
            "cell://\(Self.stagingHost)/\(cellName)"
        }

        let chat = ConfigurationCatalogCell.scaffoldChatWorkbenchMenuConfiguration(
            endpoint: stagingEndpoint("Chat")
        )
        let conferenceDemoLauncher = Self.conferenceDemoLauncherMenuSeedConfiguration()
        let conferenceIdentityLink = Self.conferenceIdentityLinkMenuSeedConfiguration()
        let conferenceParticipantPortal = Self.conferenceParticipantPortalMenuSeedConfiguration()
        let conferenceMVP = Self.conferenceMVPAutomationConfiguration()
        let conferenceAIAssistant = ConfigurationCatalogCell.conferenceAIAssistantWorkbenchConfiguration(
            conferenceEndpoint: "cell:///ConferenceParticipantPreviewShell",
            aiEndpoint: "cell:///ConferenceAIAssistantGatewayProxy"
        )
        let conferenceAdmin = Self.conferenceAdminMenuSeedConfiguration()
        let conferencePublic = ConfigurationCatalogCell.conferencePublicWorkbenchConfiguration(
            endpoint: stagingEndpoint("ConferencePublicShell")
        )
        let conferenceSponsor = Self.conferenceSponsorAutomationConfiguration()
        let conferenceCodex = ConfigurationCatalogCell.conferenceCodexLiveConfigurationsMenuConfiguration()
        let conferenceClaude = ConfigurationCatalogCell.conferenceClaudeDesignReferenceMenuConfiguration()
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
        let entityAnchorWorkbench = ConfigurationCatalogCell.entityAnchorWorkbenchMenuConfiguration()
        let vaultWorkbench = ConfigurationCatalogCell.vaultWorkbenchMenuConfiguration()
        let trustedIssuersWorkbench = ConfigurationCatalogCell.trustedIssuersWorkbenchMenuConfiguration()
        let portholeWorkbench = ConfigurationCatalogCell.portholeWorkbenchMenuConfiguration()
        let folderWatchWorkbench = ConfigurationCatalogCell.folderWatchWorkbenchMenuConfiguration()
        let graphIndexWorkbench = ConfigurationCatalogCell.graphIndexWorkbenchMenuConfiguration()
        let workflowStudioWorkbench = ConfigurationCatalogCell.workflowStudioWorkbenchMenuConfiguration()
        let workflowStudioPortable = ConfigurationCatalogCell.workflowStudioPortableMenuConfiguration()
        let localEntityScanner = ConfigurationCatalogCell.entityScannerWorkbenchConfiguration()
        let localEntityScannerHelper = ConfigurationCatalogCell.entityScannerTestHelperConfiguration()
        let localEntityScannerChecklist = ConfigurationCatalogCell.entityScannerPairingChecklistConfiguration()
        let agentSetup = ConfigurationCatalogCell.agentSetupWorkbenchMenuConfiguration()

        let upperLeft = [conferenceDemoLauncher, conferencePublic, conferenceMVP, chat, todo, conferenceCodex]
        var upperMid = [conferenceDemoLauncher, conferenceIdentityLink, appleIntelligence, conferenceParticipantPortal, conferenceAIAssistant, conferenceSponsor, conferenceClaude, catalogWorkbench, workflowStudioWorkbench, workflowStudioPortable, perspectiveWorkbench, portholeWorkbench]
        let upperRight = [conferenceDemoLauncher, conferenceParticipantPortal, conferencePublic, conferenceAdmin, conferenceSponsor, conferenceIdentityLink, conferenceCodex, conferenceClaude, workflowStudioPortable, obsidian, portholeWorkbench]
        let lowerLeft = [localEntityScanner, workflowStudioWorkbench, workflowStudioPortable, perspectiveWorkbench, entityAnchorWorkbench, trustedIssuersWorkbench, localEntityScannerHelper, localEntityScannerChecklist]
        let lowerMid = [conferenceDemoLauncher, conferenceIdentityLink, conferenceParticipantPortal, conferenceAIAssistant, conferencePublic, conferenceMVP, conferenceSponsor, conferenceCodex, conferenceClaude, todo, catalogWorkbench, workflowStudioWorkbench, workflowStudioPortable, folderWatchWorkbench, graphIndexWorkbench]
        var lowerRight = [obsidian, vaultWorkbench, workflowStudioWorkbench, workflowStudioPortable, graphIndexWorkbench, trustedIssuersWorkbench, conferenceCodex, conferenceClaude]

        if BindingPersonalCopilotV1Policy.agentSetupWorkbenchEnabled {
            upperMid.append(agentSetup)
            lowerRight.append(agentSetup)
        }

        return (
            upperLeft: upperLeft,
            upperMid: upperMid,
            upperRight: upperRight,
            lowerLeft: lowerLeft,
            lowerMid: lowerMid,
            lowerRight: lowerRight
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
        CellConfigurationEndpointRetargeting.rewritingEndpoints(in: configuration) {
            maybeRetargetLocalEndpointToStaging($0)
        }
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
    var activeConfigurationName: String?
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
                canvasContent
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

    @ViewBuilder
    private var canvasContent: some View {
        if isEditing {
            EditorSelectableSkeletonView(
                element: skeleton,
                path: .root,
                selectedPath: selectedNodePath,
                highlightedDropTargetPaths: Set(highlightedDropTargets.map(\.path)),
                onSelect: onSelectPath
            )
        } else {
            if let mode = nativeNearbyRadarMode {
                nativeNearbyRadarCanvas(mode: mode)
            } else {
                SkeletonView(element: skeleton)
            }
        }
    }

    private var nativeNearbyRadarMode: ConferenceNearbyRadarSurfaceMode? {
        guard !isEditing,
              let normalizedName = activeConfigurationName?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() else {
            return nil
        }

        if normalizedName.contains("conference nearby radar") {
            return .full
        }

        if normalizedName == "conference participant portal dashboard" {
            return .compact
        }

        return nil
    }

    private func nativeNearbyRadarCanvas(mode: ConferenceNearbyRadarSurfaceMode) -> some View {
        let maxWidth: CGFloat = mode == .full ? 1080 : 940
        return ScrollView {
            VStack(spacing: mode == .full ? 16 : 12) {
                ConferenceNearbyRadarSurfaceView(mode: mode)
                SkeletonView(element: skeleton)
            }
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
            .padding(.vertical, mode == .full ? 10 : 0)
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

private struct TopChromeHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct TopSafeAreaInsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct LoadingStatusBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
    var reservedTopInset: CGFloat
    var topExpansionStyle: EdgeMenuExpansionStyle
    var bottomExpansionStyle: EdgeMenuExpansionStyle
    var labelMode: EdgeMenuLabelMode
    var onPrimaryAction: (EdgePosition) -> Bool
    var onSelect: (CellConfiguration) -> Void

    @State private var expanded: Set<EdgePosition> = []

    var body: some View {
        ZStack {
            if !expanded.isEmpty {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.18)) {
                            expanded.removeAll()
                        }
                    }
            }

            alignedMenu(.upperLeft, items: upperLeft, alignment: .topLeading)
            alignedMenu(.upperMid, items: upperMid, alignment: .top)
            alignedMenu(.upperRight, items: upperRight, alignment: .topTrailing)
            alignedMenu(.lowerLeft, items: lowerLeft, alignment: .bottomLeading)
            alignedMenu(.lowerMid, items: lowerMid, alignment: .bottom)
            alignedMenu(.lowerRight, items: lowerRight, alignment: .bottomTrailing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onPreferenceChange(EdgeMenuToggleKey.self) { pos in
            if let pos { toggle(pos) }
        }
    }

    @ViewBuilder
    private func alignedMenu(_ position: EdgePosition, items: [MenuItem], alignment: Alignment) -> some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .overlay(alignment: alignment) {
                EdgeMenu(
                    position: position,
                    items: items,
                    isExpanded: expanded.contains(position),
                    expansionStyle: expansionStyle(for: position),
                    labelMode: labelMode,
                    showsSubtitle: subtitleVisibility(for: position)
                ) {
                    action(position, $0)
                }
                .padding(edgeInsets(for: position))
            }
    }

    private func edgeInsets(for position: EdgePosition) -> EdgeInsets {
        switch position {
        case .upperLeft:
            return EdgeInsets(top: reservedTopInset, leading: 14, bottom: 0, trailing: 0)
        case .upperMid:
            return EdgeInsets(top: reservedTopInset, leading: 0, bottom: 0, trailing: 0)
        case .upperRight:
            return EdgeInsets(top: reservedTopInset, leading: 0, bottom: 0, trailing: 14)
        case .lowerLeft:
            return EdgeInsets(top: 0, leading: 14, bottom: 14, trailing: 0)
        case .lowerMid:
            return EdgeInsets(top: 0, leading: 0, bottom: 14, trailing: 0)
        case .lowerRight:
            return EdgeInsets(top: 0, leading: 0, bottom: 14, trailing: 14)
        }
    }

    private func action(_ position: EdgePosition, _ config: CellConfiguration?) {
        if let config {
            expanded.removeAll()
            onSelect(config)
            return
        }

        let items = menuItems(for: position)
        if items.isEmpty {
            _ = onPrimaryAction(position)
            return
        }

        if items.count == 1, let only = items.first?.configuration {
            expanded.removeAll()
            onSelect(only)
            return
        }

        toggle(position)
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
            if expanded.contains(position) {
                expanded.remove(position)
            } else {
                expanded = [position]
            }
        }
    }

    private func expansionStyle(for position: EdgePosition) -> EdgeMenuExpansionStyle {
        switch position {
        case .upperLeft, .upperMid, .upperRight:
            return topExpansionStyle
        case .lowerLeft, .lowerMid, .lowerRight:
            return bottomExpansionStyle
        }
    }

    private func subtitleVisibility(for position: EdgePosition) -> Bool {
        switch position {
        case .upperMid, .lowerMid:
            return true
        default:
            return false
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
    private static let maximumRetainedStatuses = 16

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

        if statusesByEndpoint.count > Self.maximumRetainedStatuses {
            let retained = statusesByEndpoint.values
                .sorted { $0.updatedAt > $1.updatedAt }
                .prefix(Self.maximumRetainedStatuses)
            statusesByEndpoint = Dictionary(uniqueKeysWithValues: retained.map { ($0.endpoint, $0) })
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

    func handleMemoryPressure() {
        statusesByEndpoint.removeAll(keepingCapacity: false)
        visibleStatuses.removeAll(keepingCapacity: false)
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


// MARK: - Preview
#Preview {
    ContentView()
}
