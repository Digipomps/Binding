//
//  ConfigurationCatalogCell.swift
//  Binding
//
//  Created by Codex on 11/02/2026.
//

import Foundation
import CellBase

enum ConfigurationCatalogPreviewBridge {
    nonisolated static let notificationName = Notification.Name("ConfigurationCatalogPreviewBridge.requested")

    nonisolated private static let configurationDataKey = "configurationData"

    nonisolated static func post(configuration: CellConfiguration, notificationCenter: NotificationCenter = .default) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(configuration) else { return }
        notificationCenter.post(
            name: notificationName,
            object: nil,
            userInfo: [configurationDataKey: data]
        )
    }

    nonisolated static func configuration(from notification: Notification) -> CellConfiguration? {
        guard let data = notification.userInfo?[configurationDataKey] as? Data else { return nil }
        return try? JSONDecoder().decode(CellConfiguration.self, from: data)
    }
}

enum BindingPortholeLoadBridge {
    nonisolated static let notificationName = Notification.Name("BindingPortholeLoadBridge.requested")

    nonisolated private static let configurationDataKey = "configurationData"

    nonisolated static func post(configuration: CellConfiguration, notificationCenter: NotificationCenter = .default) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(configuration) else { return }
        notificationCenter.post(
            name: notificationName,
            object: nil,
            userInfo: [configurationDataKey: data]
        )
    }

    nonisolated static func configuration(from notification: Notification) -> CellConfiguration? {
        guard let data = notification.userInfo?[configurationDataKey] as? Data else { return nil }
        return try? JSONDecoder().decode(CellConfiguration.self, from: data)
    }
}

enum BindingPersonalCopilotV1Policy {
    nonisolated static let appStoreScope = "personal-copilot-v1"
    nonisolated static let approvedRemoteHosts: Set<String> = [
        "staging.haven.digipomps.org"
    ]
    nonisolated static let allowedStyleRoles: Set<String> = [
        "markdown",
        "tabstrip",
        "personal-hero",
        "personal-section-header",
        "personal-card",
        "personal-badge",
        "personal-action-row",
        "personal-key-value-block",
        "personal-inline-field",
        "personal-draft-composer",
        "personal-list-row",
        "personal-grid-tile",
        "personal-consent-prompt",
        "personal-publish-confirmation",
        "personal-match-card",
        "personal-chat-item",
        "personal-message-bubble",
        "personal-audit-row",
        "personal-scanner-result",
        "personal-workflow-step",
        "personal-graph-preview",
        "personal-knowledge-graph",
        "personal-chat-page",
        "personal-chat-hero",
        "personal-chat-section",
        "personal-chat-composer-field",
        "chat-primary-action",
        "chat-safety-hint",
        "chat-prompt-log",
        "chat-active-tool-chips",
        "chat-helper-tabs",
        "chat-helper-tabs-compact"
    ]

    nonisolated static var appStoreCatalogGateEnabled: Bool {
        !conferenceDemoMenusEnabled
    }

    nonisolated static var stagingSurfaceTestingEnabled: Bool {
        stagingSurfaceTestingEnabled(
            environment: ProcessInfo.processInfo.environment,
            launchArguments: ProcessInfo.processInfo.arguments
        )
    }

    nonisolated static func stagingSurfaceTestingEnabled(
        environment: [String: String],
        launchArguments: [String]
    ) -> Bool {
        #if DEBUG
        if launchArguments.contains("--disable-staging-surface-testing") {
            return false
        }
        if let raw = environment["BINDING_ENABLE_STAGING_SURFACE_TESTING"] {
            return isTruthyFlag(raw)
        }
        if let raw = environment["BINDING_DISABLE_STAGING_SURFACE_TESTING"], isTruthyFlag(raw) {
            return false
        }
        return true
        #else
        _ = environment
        _ = launchArguments
        return false
        #endif
    }

    nonisolated static let conferenceDemoMenusDefaultsKey = "Binding.EnableConferenceDemoMenus"

    nonisolated static var conferenceDemoMenusEnabled: Bool {
        conferenceDemoMenusEnabled(
            environment: ProcessInfo.processInfo.environment,
            launchArguments: ProcessInfo.processInfo.arguments,
            persistedOptIn: UserDefaults.standard.bool(forKey: conferenceDemoMenusDefaultsKey)
        )
    }

    nonisolated static func conferenceDemoMenusEnabled(
        environment: [String: String],
        launchArguments: [String],
        persistedOptIn: Bool
    ) -> Bool {
        #if DEBUG
        if persistedOptIn {
            return true
        }

        return isTruthyFlag(environment["BINDING_ENABLE_CONFERENCE_DEMO_MENUS"])
            || launchArguments.contains("--conference-demo-menus")
        #else
        _ = environment
        _ = launchArguments
        _ = persistedOptIn
        return false
        #endif
    }

    nonisolated static var conferenceShowcaseEnabled: Bool {
        conferenceDemoMenusEnabled
    }

    nonisolated static let agentSetupWorkbenchDefaultsKey = "Binding.EnableAgentSetupWorkbench"

    nonisolated static var agentSetupWorkbenchEnabled: Bool {
        agentSetupWorkbenchEnabled(
            environment: ProcessInfo.processInfo.environment,
            launchArguments: ProcessInfo.processInfo.arguments,
            persistedOptIn: UserDefaults.standard.bool(forKey: agentSetupWorkbenchDefaultsKey)
        )
    }

    nonisolated static func agentSetupWorkbenchEnabled(
        environment: [String: String],
        launchArguments: [String],
        persistedOptIn: Bool
    ) -> Bool {
        #if DEBUG
        if persistedOptIn {
            return true
        }

        if launchArguments.contains("--enable-agent-setup-workbench")
            || launchArguments.contains("--enable-conference-automation")
            || launchArguments.contains("--conference-demo-menus") {
            return true
        }

        return isTruthyFlag(environment["BINDING_ENABLE_AGENT_SETUP_WORKBENCH"])
            || isTruthyFlag(environment["BINDING_ENABLE_AGENT_SETUP"])
            || isTruthyFlag(environment["BINDING_ENABLE_CONFERENCE_AUTOMATION"])
            || isTruthyFlag(environment["BINDING_ENABLE_CONFERENCE_DEMO_MENUS"])
        #else
        _ = environment
        _ = launchArguments
        _ = persistedOptIn
        return false
        #endif
    }

    nonisolated private static func isTruthyFlag(_ value: String?) -> Bool {
        guard let value else { return false }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "1" || normalized == "true" || normalized == "yes"
    }

    nonisolated static func metadataHints(
        policyCategory: String,
        ageRatingHint: String = "12+",
        requiresLogin: Bool,
        requiresUserGeneratedContentModeration: Bool,
        nativePermissionRequests: [String] = [],
        universalLink: String,
        reviewSummary: String
    ) -> [String] {
        let surfaceFamily = defaultSurfaceFamily(for: policyCategory)
        let presentationClass = defaultPresentationClass(for: policyCategory)
        return [
            "appStoreScope=\(appStoreScope)",
            "policyCategory=\(policyCategory)",
            "surfaceFamily=\(surfaceFamily)",
            "presentationClass=\(presentationClass)",
            "ageRatingHint=\(ageRatingHint)",
            "requiresLogin=\(requiresLogin)",
            "requiresUserGeneratedContentModeration=\(requiresUserGeneratedContentModeration)",
            "nativePermissionRequests=\(nativePermissionRequests.isEmpty ? "none" : nativePermissionRequests.joined(separator: ","))",
            "universalLink=\(universalLink)",
            "reviewSummary=\(reviewSummary)"
        ]
    }

    nonisolated static func discoveryInterests(
        _ interests: [String],
        policyCategory: String
    ) -> [String] {
        uniqueOrdered([
            appStoreScope,
            "appStoreScope:\(appStoreScope)",
            "policy:\(policyCategory)",
            "surfaceFamily:\(defaultSurfaceFamily(for: policyCategory))",
            "presentationClass:\(defaultPresentationClass(for: policyCategory))"
        ] + interests)
    }

    nonisolated static func defaultSurfaceFamily(for policyCategory: String) -> String {
        switch policyCategory {
        case "identity-and-account", "profile-draft", "profile-publish", "privacy-audit":
            return "identity"
        case "matching", "invite-only-chat", "purpose-driven-chat", "public-profile-directory", "public-directory":
            return "relationship"
        case "local-vault", "catalog", "catalog-policy":
            return "content"
        case "meeting-intent", "meeting-coordinator", "agenda-context", "apple-intelligence", "hardware-scanner", "workflow-studio":
            return "intelligence"
        default:
            return "governance"
        }
    }

    nonisolated static func defaultPresentationClass(for policyCategory: String) -> String {
        switch policyCategory {
        case "identity-and-account", "profile-draft", "profile-publish", "privacy-audit":
            return "detail"
        case "matching", "public-profile-directory", "public-directory", "catalog", "catalog-policy":
            return "list"
        case "invite-only-chat", "purpose-driven-chat":
            return "detail"
        case "local-vault":
            return "grid"
        case "meeting-intent", "meeting-coordinator", "agenda-context", "calendar-store", "workflow-studio":
            return "form"
        case "apple-intelligence", "hardware-scanner":
            return "hero"
        default:
            return "detail"
        }
    }

    nonisolated static func isAllowedInPersonalCopilotV1(_ configuration: CellConfiguration) -> Bool {
        guard hasPersonalCopilotScope(configuration) else { return false }
        guard !containsHiddenConferenceSurface(configuration) else { return false }
        return referencedEndpoints(in: configuration).allSatisfy(isApprovedEndpoint)
    }

    nonisolated static func isApprovedEndpoint(_ endpoint: String) -> Bool {
        guard let components = URLComponents(string: endpoint),
              components.scheme?.lowercased() == "cell"
        else {
            return false
        }

        let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if host == nil || host?.isEmpty == true || host == "localhost" {
            return true
        }
        return approvedRemoteHosts.contains(host ?? "")
    }

    nonisolated static func unavailableMessage(for configurationName: String) -> String {
        "\(configurationName) er ikke del av Personal Co-Pilot V1 i App Store-modus. Den kan åpnes i utviklingsmodus eller via eksplisitt godkjent katalog senere."
    }

    nonisolated static func referencedEndpoints(in configuration: CellConfiguration) -> [String] {
        guard let references = configuration.cellReferences else { return [] }
        return references.flatMap(Self.referencedEndpoints(in:))
    }

    nonisolated private static func referencedEndpoints(in reference: CellReference) -> [String] {
        [reference.endpoint] + reference.subscriptions.flatMap(Self.referencedEndpoints(in:))
    }

    nonisolated private static func hasPersonalCopilotScope(_ configuration: CellConfiguration) -> Bool {
        let interests = configuration.discovery?.interests ?? []
        return interests.contains { token in
            let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized == appStoreScope
                || normalized == "appstorescope:\(appStoreScope)"
                || normalized == "appstorescope=\(appStoreScope)"
        }
    }

    nonisolated private static func containsHiddenConferenceSurface(_ configuration: CellConfiguration) -> Bool {
        var haystack: [String] = [
            configuration.name,
            configuration.description ?? "",
            configuration.discovery?.purpose ?? "",
            configuration.discovery?.purposeDescription ?? "",
            configuration.discovery?.sourceCellEndpoint ?? "",
            configuration.discovery?.sourceCellName ?? ""
        ]
        haystack.append(contentsOf: configuration.discovery?.interests ?? [])

        let foldingOptions: String.CompareOptions = [.diacriticInsensitive, .caseInsensitive]
        let normalized = haystack
            .joined(separator: " ")
            .folding(options: foldingOptions, locale: Locale.current)
            .lowercased()

        let blockedTokens = [
            "conference",
            "konferanse",
            "sponsor",
            "control tower",
            "demo launcher",
            "participant portal",
            "exhibitor"
        ]
        return blockedTokens.contains { normalized.contains($0) }
    }

    nonisolated private static func uniqueOrdered(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { value in
            let key = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { return false }
            return seen.insert(key).inserted
        }
    }
}

struct BindingPersonalCopilotSurfaceMetadata: Equatable {
    enum SourceKind: String {
        case local
        case remoteTrusted
        case remoteUnapproved

        var badgeTitle: String {
            switch self {
            case .local:
                return "Local core"
            case .remoteTrusted:
                return "Remote trusted"
            case .remoteUnapproved:
                return "Remote unavailable"
            }
        }
    }

    let appStoreScope: String?
    let policyCategory: String?
    let surfaceFamily: String?
    let presentationClass: String?
    let requiresLogin: Bool
    let requiresModeration: Bool
    let nativePermissionRequests: [String]
    let universalLink: String?
    let reviewSummary: String?
    let sourceEndpoint: String?
    let sourceKind: SourceKind

    init(configuration: CellConfiguration) {
        let interests = configuration.discovery?.interests ?? []
        let sourceEndpoint = configuration.discovery?.sourceCellEndpoint

        self.appStoreScope = Self.metadataValue(for: "appStoreScope", in: interests)
        self.policyCategory = Self.metadataValue(for: "policyCategory", in: interests)
        self.surfaceFamily = Self.metadataValue(for: "surfaceFamily", in: interests)
        self.presentationClass = Self.metadataValue(for: "presentationClass", in: interests)
        self.requiresLogin = Self.boolValue(for: "requiresLogin", in: interests)
        self.requiresModeration = Self.boolValue(for: "requiresUserGeneratedContentModeration", in: interests)
        self.nativePermissionRequests = Self.listValue(for: "nativePermissionRequests", in: interests)
        self.universalLink = Self.metadataValue(for: "universalLink", in: interests)
        self.reviewSummary = Self.metadataValue(for: "reviewSummary", in: interests)
        self.sourceEndpoint = sourceEndpoint
        self.sourceKind = Self.sourceKind(for: sourceEndpoint)
    }

    var permissionGateSummary: String? {
        guard !nativePermissionRequests.isEmpty else { return nil }
        return nativePermissionRequests.joined(separator: ", ")
    }

    private static func sourceKind(for endpoint: String?) -> SourceKind {
        guard let endpoint,
              let components = URLComponents(string: endpoint),
              components.scheme?.lowercased() == "cell"
        else {
            return .local
        }

        let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if host == nil || host?.isEmpty == true || host == "localhost" {
            return .local
        }
        return BindingPersonalCopilotV1Policy.approvedRemoteHosts.contains(host ?? "")
            ? .remoteTrusted
            : .remoteUnapproved
    }

    private static func metadataValue(for key: String, in interests: [String]) -> String? {
        let prefix = "\(key.lowercased())="
        for token in interests {
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowered = trimmed.lowercased()
            guard lowered.hasPrefix(prefix) else { continue }
            return String(trimmed.dropFirst(prefix.count))
        }
        return nil
    }

    private static func boolValue(for key: String, in interests: [String]) -> Bool {
        metadataValue(for: key, in: interests)?.lowercased() == "true"
    }

    private static func listValue(for key: String, in interests: [String]) -> [String] {
        guard let raw = metadataValue(for: key, in: interests) else { return [] }
        if raw.lowercased() == "none" {
            return []
        }
        return raw
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

enum BindingPersonalCopilotDesignSystem {
    nonisolated static let canvas = "#F4EFE6"
    nonisolated static let shell = "#FBF8F1"
    nonisolated static let surface = "#FFFDF8"
    nonisolated static let surfaceElevated = "#FFFFFF"
    nonisolated static let surfaceMuted = "#F8F3EA"
    nonisolated static let brandPrimary = "#534AB7"
    nonisolated static let brandSubtle = "#EEEDFE"
    nonisolated static let brandStrong = "#433C98"
    nonisolated static let textPrimary = "#1E1B16"
    nonisolated static let textSecondary = "#5C5449"
    nonisolated static let textTertiary = "#857C70"
    nonisolated static let border = "#D8D0C2"
    nonisolated static let borderStrong = "#B8AD9A"
    nonisolated static let success = "#0F766E"
    nonisolated static let warning = "#B45309"
    nonisolated static let danger = "#B91C1C"
    nonisolated static let successSoft = "#DFF6EF"
    nonisolated static let warningSoft = "#FCEFD9"
    nonisolated static let dangerSoft = "#FBE4E4"

    nonisolated static func pageCard() -> SkeletonModifiers {
        modifier {
            $0.padding = 16
            $0.background = shell
            $0.cornerRadius = 24
            $0.borderWidth = 1
            $0.borderColor = border
        }
    }

    nonisolated static func chatPageShell() -> SkeletonModifiers {
        modifier {
            $0.padding = 8
            $0.background = surface
            $0.cornerRadius = 14
            $0.maxWidthInfinity = true
            $0.styleRole = "personal-chat-page"
        }
    }

    nonisolated static func chatHeroPanel() -> SkeletonModifiers {
        modifier {
            $0.padding = 10
            $0.background = surfaceElevated
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = border
            $0.styleRole = "personal-chat-hero"
        }
    }

    nonisolated static func chatSectionCard() -> SkeletonModifiers {
        modifier {
            $0.padding = 10
            $0.background = surfaceElevated
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = border
            $0.styleRole = "personal-chat-section"
        }
    }

    nonisolated static func heroPanel() -> SkeletonModifiers {
        modifier {
            $0.padding = 16
            $0.background = brandSubtle
            $0.cornerRadius = 18
            $0.borderWidth = 1
            $0.borderColor = brandPrimary
            $0.styleRole = "personal-hero"
        }
    }

    nonisolated static func compactHeroPanel() -> SkeletonModifiers {
        modifier {
            $0.padding = 12
            $0.background = surface
            $0.cornerRadius = 16
            $0.borderWidth = 1
            $0.borderColor = borderStrong
            $0.styleRole = "personal-hero"
        }
    }

    nonisolated static func dangerSectionCard(role: String = "personal-card") -> SkeletonModifiers {
        modifier {
            $0.padding = 12
            $0.background = dangerSoft
            $0.cornerRadius = 16
            $0.borderWidth = 1
            $0.borderColor = danger
            $0.styleRole = role
        }
    }

    nonisolated static func sectionCard(role: String = "personal-card") -> SkeletonModifiers {
        modifier {
            $0.padding = 12
            $0.background = surfaceElevated
            $0.cornerRadius = 16
            $0.borderWidth = 1
            $0.borderColor = border
            $0.styleRole = role
        }
    }

    nonisolated static func keyValueCard() -> SkeletonModifiers {
        modifier {
            $0.padding = 12
            $0.background = surface
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = border
            $0.styleRole = "personal-key-value-block"
        }
    }

    nonisolated static func fieldCard() -> SkeletonModifiers {
        modifier {
            $0.padding = 10
            $0.background = surfaceElevated
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = borderStrong
            $0.styleRole = "personal-inline-field"
        }
    }

    nonisolated static func chatComposerFieldCard() -> SkeletonModifiers {
        modifier {
            $0.padding = 8
            $0.background = surfaceElevated
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = borderStrong
            $0.styleRole = "personal-chat-composer-field"
        }
    }

    nonisolated static func listCard(height: Double? = nil, role: String = "personal-list-row") -> SkeletonModifiers {
        modifier {
            $0.padding = 8
            $0.background = surfaceElevated
            $0.cornerRadius = 16
            $0.borderWidth = 1
            $0.borderColor = border
            $0.styleRole = role
            if let height {
                $0.height = height
            }
        }
    }

    nonisolated static func primaryButton() -> SkeletonModifiers {
        modifier {
            $0.padding = 10
            $0.background = brandPrimary
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = brandStrong
            $0.foregroundColor = "#FFFFFF"
        }
    }

    nonisolated static func promptIconButton() -> SkeletonModifiers {
        modifier {
            $0.padding = 10
            $0.width = 58
            $0.height = 58
            $0.background = brandPrimary
            $0.cornerRadius = 29
            $0.borderWidth = 1
            $0.borderColor = brandStrong
            $0.foregroundColor = "#FFFFFF"
            $0.fontSize = 28
            $0.fontWeight = "semibold"
            $0.styleRole = "chat-primary-action"
        }
    }

    nonisolated static func secondaryButton() -> SkeletonModifiers {
        modifier {
            $0.padding = 10
            $0.background = surfaceMuted
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = borderStrong
            $0.foregroundColor = textPrimary
        }
    }

    nonisolated static func warningButton() -> SkeletonModifiers {
        modifier {
            $0.padding = 10
            $0.background = warningSoft
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = warning
            $0.foregroundColor = textPrimary
        }
    }

    nonisolated static func badgeModifier(
        background: String = brandSubtle,
        borderColor: String = brandPrimary,
        foregroundColor: String = textPrimary
    ) -> SkeletonModifiers {
        modifier {
            $0.padding = 6
            $0.background = background
            $0.cornerRadius = 99
            $0.borderWidth = 1
            $0.borderColor = borderColor
            $0.foregroundColor = foregroundColor
            $0.fontSize = 11
            $0.fontWeight = "medium"
            $0.styleRole = "personal-badge"
        }
    }

    nonisolated static func headingText(_ text: String, role: String = "personal-section-header") -> SkeletonText {
        var label = SkeletonText(text: text)
        label.modifiers = modifier {
            $0.foregroundColor = textPrimary
            $0.fontWeight = "medium"
            $0.fontSize = 18
            $0.styleRole = role
        }
        return label
    }

    nonisolated static func titleText(_ text: String) -> SkeletonText {
        var label = SkeletonText(text: text)
        label.modifiers = modifier {
            $0.foregroundColor = textPrimary
            $0.fontWeight = "medium"
            $0.fontStyle = "title3"
        }
        return label
    }

    nonisolated static func bodyText(_ text: String, color: String = textSecondary, size: Double = 14) -> SkeletonText {
        var label = SkeletonText(text: text)
        label.modifiers = modifier {
            $0.foregroundColor = color
            $0.fontSize = size
            $0.lineLimit = 4
        }
        return label
    }

    nonisolated static func metadataText(_ text: String) -> SkeletonText {
        var label = SkeletonText(text: text)
        label.modifiers = modifier {
            $0.foregroundColor = textTertiary
            $0.fontSize = 12
            $0.lineLimit = 3
        }
        return label
    }

    nonisolated private static func modifier(_ configure: (inout SkeletonModifiers) -> Void) -> SkeletonModifiers {
        var modifiers = SkeletonModifiers()
        configure(&modifiers)
        return modifiers
    }
}

enum BindingConferenceNavigationBridge {
    nonisolated static let notificationName = Notification.Name("BindingConferenceNavigationBridge.requested")

    nonisolated private static let actionKey = "action"
    nonisolated private static let fallbackConfigurationDataKey = "fallbackConfigurationData"

    nonisolated static func postPop(
        fallbackConfiguration: CellConfiguration? = nil,
        notificationCenter: NotificationCenter = .default
    ) {
        let encoder = JSONEncoder()
        let fallbackData = fallbackConfiguration.flatMap { try? encoder.encode($0) }
        var userInfo: [String: Any] = [actionKey: "pop"]
        if let fallbackData {
            userInfo[fallbackConfigurationDataKey] = fallbackData
        }
        notificationCenter.post(
            name: notificationName,
            object: nil,
            userInfo: userInfo
        )
    }

    nonisolated static func isPopRequest(_ notification: Notification) -> Bool {
        notification.userInfo?[actionKey] as? String == "pop"
    }

    nonisolated static func fallbackConfiguration(from notification: Notification) -> CellConfiguration? {
        guard let data = notification.userInfo?[fallbackConfigurationDataKey] as? Data else { return nil }
        return try? JSONDecoder().decode(CellConfiguration.self, from: data)
    }
}

final class ConfigurationCatalogCell: GeneralCell {
    private static let blockedCatalogReferenceNames: Set<String> = [
        "eventemitter",
        "entitieswrapper",
        "timeswrapper",
        "locationswrapper"
    ]
    nonisolated private static let maximumAgreementHistoryEntries = 48
    nonisolated private static let maximumAgreementPreviewSnapshots = 32
    nonisolated private static let maximumAgreementNonComplianceReports = 96
    nonisolated private static let maximumAgreementAuditEntries = 160
    nonisolated private static let maximumMatchingSuggestionEntries = 24
    nonisolated private static let maximumMatchingBookmarkEntries = 30

    private enum MenuSlot: String, Codable, CaseIterable {
        case upperLeft
        case upperMid
        case upperRight
        case lowerLeft
        case lowerMid
        case lowerRight

        var keypath: String { "\(rawValue)Menu" }
    }

    private enum SupportedInsertionMode: String, Codable, CaseIterable {
        case root
        case component
        case both
        case unknown
    }

    private struct CatalogEntry: Codable {
        var id: String
        var sourceCellEndpoint: String
        var sourceCellName: String
        var purpose: String
        var purposeDescription: String?
        var interests: [String]
        var menuSlots: [MenuSlot]
        var goal: CellConfiguration
        var configuration: CellConfiguration
        var displayName: String?
        var summary: String?
        var categoryPath: [String]?
        var tags: [String]?
        var purposeRefs: [String]?
        var interestRefs: [String]?
        var supportedInsertionModes: [SupportedInsertionMode]?
        var supportedTargetKinds: [String]?
        var ioGetKeys: [String]?
        var ioSetKeys: [String]?
        var ioTopics: [String]?
        var ioFilterTypes: [String]?
        var authRequired: Bool?
        var policyHints: [String]?
        var flowDriven: Bool?
        var editable: Bool?
        var recommendedContexts: [String]?
        var updatedAt: Double

        func asObject() -> Object {
            var object: Object = [
                "id": .string(id),
                "sourceCellEndpoint": .string(sourceCellEndpoint),
                "sourceCellName": .string(sourceCellName),
                "purpose": .string(purpose),
                "interests": .list(interests.map { .string($0) }),
                "menuSlots": .list(menuSlots.map { .string($0.rawValue) }),
                "goal": .cellConfiguration(goal),
                "configuration": .cellConfiguration(configuration),
                "updatedAt": .float(updatedAt)
            ]
            if let displayName, !displayName.isEmpty {
                object["displayName"] = .string(displayName)
            }
            if let summary, !summary.isEmpty {
                object["summary"] = .string(summary)
            }
            if let categoryPath, !categoryPath.isEmpty {
                object["categoryPath"] = .list(categoryPath.map { .string($0) })
            }
            if let tags, !tags.isEmpty {
                object["tags"] = .list(tags.map { .string($0) })
            }
            if let purposeRefs, !purposeRefs.isEmpty {
                object["purposeRefs"] = .list(purposeRefs.map { .string($0) })
            }
            if let interestRefs, !interestRefs.isEmpty {
                object["interestRefs"] = .list(interestRefs.map { .string($0) })
            }
            if let supportedInsertionModes, !supportedInsertionModes.isEmpty {
                object["supportedInsertionModes"] = .list(supportedInsertionModes.map { .string($0.rawValue) })
            }
            if let supportedTargetKinds, !supportedTargetKinds.isEmpty {
                object["supportedTargetKinds"] = .list(supportedTargetKinds.map { .string($0) })
            }
            var ioSignature: Object = [:]
            if let ioGetKeys, !ioGetKeys.isEmpty {
                ioSignature["getKeys"] = .list(ioGetKeys.map { .string($0) })
            }
            if let ioSetKeys, !ioSetKeys.isEmpty {
                ioSignature["setKeys"] = .list(ioSetKeys.map { .string($0) })
            }
            if let ioTopics, !ioTopics.isEmpty {
                ioSignature["topics"] = .list(ioTopics.map { .string($0) })
            }
            if let ioFilterTypes, !ioFilterTypes.isEmpty {
                ioSignature["filterTypes"] = .list(ioFilterTypes.map { .string($0) })
            }
            if !ioSignature.isEmpty {
                object["ioSignature"] = .object(ioSignature)
            }
            if let authRequired {
                object["authRequired"] = .bool(authRequired)
            }
            if let policyHints, !policyHints.isEmpty {
                object["policyHints"] = .list(policyHints.map { .string($0) })
            }
            if let flowDriven {
                object["flowDriven"] = .bool(flowDriven)
            }
            if let editable {
                object["editable"] = .bool(editable)
            }
            if let recommendedContexts, !recommendedContexts.isEmpty {
                object["recommendedContexts"] = .list(recommendedContexts.map { .string($0) })
            }
            if let purposeDescription {
                object["purposeDescription"] = .string(purposeDescription)
            }
            return object
        }
    }

    private struct CatalogPayload {
        var id: String?
        var sourceCellEndpoint: String
        var sourceCellName: String
        var purpose: String
        var purposeDescription: String?
        var interests: [String]
        var menuSlots: [MenuSlot]
        var goal: CellConfiguration
        var configuration: CellConfiguration
        var displayName: String? = nil
        var summary: String? = nil
        var categoryPath: [String]? = nil
        var tags: [String]? = nil
        var purposeRefs: [String]? = nil
        var interestRefs: [String]? = nil
        var supportedInsertionModes: [SupportedInsertionMode]? = nil
        var supportedTargetKinds: [String]? = nil
        var ioGetKeys: [String]? = nil
        var ioSetKeys: [String]? = nil
        var ioTopics: [String]? = nil
        var ioFilterTypes: [String]? = nil
        var authRequired: Bool? = nil
        var policyHints: [String]? = nil
        var flowDriven: Bool? = nil
        var editable: Bool? = nil
        var recommendedContexts: [String]? = nil
    }

    private struct ScaffoldPurposeTemplate {
        var sourceCellEndpoint: String
        var sourceCellName: String
        var purpose: String
        var purposeDescription: String
        var interests: [String]
        var menuSlots: [MenuSlot]
        var goal: CellConfiguration
        var configuration: CellConfiguration
        var displayName: String? = nil
        var summary: String? = nil
        var categoryPath: [String]? = nil
        var tags: [String]? = nil
        var purposeRefs: [String]? = nil
        var interestRefs: [String]? = nil
        var supportedInsertionModes: [SupportedInsertionMode]? = nil
        var supportedTargetKinds: [String]? = nil
        var ioGetKeys: [String]? = nil
        var ioSetKeys: [String]? = nil
        var ioTopics: [String]? = nil
        var ioFilterTypes: [String]? = nil
        var authRequired: Bool? = nil
        var policyHints: [String]? = nil
        var flowDriven: Bool? = nil
        var editable: Bool? = nil
        var recommendedContexts: [String]? = nil
        var forceRefreshExisting: Bool = false
        var skipResolverLookup: Bool = false
    }

    private struct StaticCatalogDescriptor {
        var sourceCellEndpoint: String
        var sourceCellName: String
        var displayName: String
        var purpose: String
        var purposeDescription: String
        var interests: [String]
        var summary: String
        var categoryPath: [String]
        var tags: [String]
        var menuSlots: [MenuSlot] = []
        var chip: String = "CELL"
        var borderColor: String = "#94A3B8"
        var startKey: String? = nil
        var authRequired: Bool? = false
        var policyHints: [String]? = nil
        var flowDriven: Bool? = false
        var editable: Bool? = true
        var recommendedContexts: [String]? = nil
        var ioGetKeys: [String]? = nil
        var ioSetKeys: [String]? = nil
        var ioTopics: [String]? = nil
        var ioFilterTypes: [String]? = nil
        var supportedTargetKinds: [String]? = ["tool", "porthole", "library"]
        var skipResolverLookup: Bool = true
        var forceRefreshExisting: Bool = false
    }

    private enum ConferenceSurfacePalette {
        nonisolated static let canvas = "#F6F1E8"
        nonisolated static let shell = "#FFFCF7"
        nonisolated static let shellStrong = "#FFFCF6"
        nonisolated static let shellMuted = "#F7EFE4"
        nonisolated static let stroke = "#C7A57F"
        nonisolated static let strokeStrong = "#A77044"
        nonisolated static let textMain = "#1F1A15"
        nonisolated static let textMuted = "#5C4E40"
        nonisolated static let accentWarm = "#D86A3A"
        nonisolated static let accentWarmSoft = "#F3E0CF"
        nonisolated static let accentCool = "#2F7D7A"
        nonisolated static let accentCoolSoft = "#DCEEEB"
        nonisolated static let accentCoolBorder = "#6C9D9A"
        nonisolated static let cautionSoft = "#F9ECD7"
        nonisolated static let shadow = "#38220B29"
    }

    nonisolated private static func conferenceCardModifier(
        padding: Double,
        background: String,
        borderColor: String,
        cornerRadius: Double = 18,
        shadowRadius: Double? = nil,
        shadowY: Double = 0,
        shadowColor: String = ConferenceSurfacePalette.shadow
    ) -> SkeletonModifiers {
        modifier {
            $0.padding = padding
            $0.background = background
            $0.cornerRadius = cornerRadius
            $0.borderWidth = 1
            $0.borderColor = borderColor
            if let shadowRadius {
                $0.shadowRadius = shadowRadius
                $0.shadowY = shadowY
                $0.shadowColor = shadowColor
            }
        }
    }

    nonisolated private static func conferenceButtonModifier(
        background: String,
        borderColor: String,
        foregroundColor: String? = nil
    ) -> SkeletonModifiers {
        modifier {
            $0.padding = 8
            $0.background = background
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = borderColor
            $0.foregroundColor = foregroundColor
        }
    }

    nonisolated private static func conferenceChipModifier(
        background: String,
        borderColor: String,
        foregroundColor: String
    ) -> SkeletonModifiers {
        modifier {
            $0.padding = 6
            $0.background = background
            $0.cornerRadius = 999
            $0.borderWidth = 1
            $0.borderColor = borderColor
            $0.foregroundColor = foregroundColor
            $0.fontSize = 11
            $0.fontWeight = "semibold"
        }
    }

    private struct CatalogErrorEntry: Codable {
        var id: String
        var endpoint: String
        var operation: String
        var message: String
        var firstSeenAt: Double
        var lastSeenAt: Double
        var count: Int

        func asObject() -> Object {
            [
                "id": .string(id),
                "endpoint": .string(endpoint),
                "operation": .string(operation),
                "message": .string(message),
                "firstSeenAt": .float(firstSeenAt),
                "lastSeenAt": .float(lastSeenAt),
                "count": .integer(count)
            ]
        }
    }

    private struct MatchingSuggestion: Codable {
        var id: String
        var sourceEntryID: String
        var prompt: String
        var purpose: String
        var interests: [String]
        var overlappingInterests: [String]
        var menuSlots: [MenuSlot]
        var configuration: CellConfiguration
        var matchScore: Double
        var matchMeaning: String
        var hasSkeleton: Bool
        var matchedAt: Double

        func asObject() -> Object {
            let interestsSummary = interests.joined(separator: ", ")
            let overlapSummary = overlappingInterests.isEmpty
                ? "Ingen direkte interesseoverlapp."
                : "Interesseoverlapp: \(overlappingInterests.joined(separator: ", "))."
            let slotSummary = menuSlots.isEmpty ? "Ingen anbefalt meny-slot." : menuSlots.map(\.rawValue).joined(separator: ", ")
            let scoreLabel = String(format: "%.2f", matchScore)
            let skeletonStatus = hasSkeleton ? "Har skeleton - klar for preview/load i Porthole." : "Ingen skeleton i konfigurasjonen."
            let description = configuration.description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? configuration.description!
                : "CellConfiguration som kan hjelpe med formaalet \"\(purpose)\"."
            var object: Object = [
                "id": .string(id),
                "sourceEntryId": .string(sourceEntryID),
                "prompt": .string(prompt),
                "purpose": .string(purpose),
                "interests": .list(interests.map { .string($0) }),
                "interestsSummary": .string(interestsSummary),
                "overlappingInterests": .list(overlappingInterests.map { .string($0) }),
                "overlapSummary": .string(overlapSummary),
                "menuSlots": .list(menuSlots.map { .string($0.rawValue) }),
                "menuSlotsSummary": .string(slotSummary),
                "configuration": .cellConfiguration(configuration),
                "name": .string(configuration.name),
                "matchScore": .float(matchScore),
                "matchScoreLabel": .string(scoreLabel),
                "match_score": .string(scoreLabel),
                "matchMeaning": .string(matchMeaning),
                "reasoning": .string(matchMeaning),
                "hasSkeleton": .bool(hasSkeleton),
                "skeletonStatus": .string(skeletonStatus),
                "scoreAndSkeleton": .string("Score \(scoreLabel) | \(hasSkeleton ? "skeleton klar" : "ingen skeleton")"),
                "matchedAt": .float(matchedAt),
                "description": .string(description)
            ]
            if let firstReference = configuration.cellReferences?.first {
                object["primaryEndpoint"] = .string(firstReference.endpoint)
            }
            if let skeleton = configuration.skeleton,
               let skeletonData = try? JSONEncoder().encode(skeleton),
               let skeletonString = String(data: skeletonData, encoding: .utf8) {
                let preview = String(skeletonString.prefix(240))
                object["skeletonPreview"] = .string(preview)
            }
            return object
        }
    }

    private struct PurposeUsageStat: Codable {
        var purpose: String
        var useCount: Int
        var achievedCount: Int
        var effectiveness: Double
        var currentWeight: Double
        var lastUsedAt: Double

        func asObject() -> Object {
            let effectivenessPercent = Int((effectiveness * 100.0).rounded())
            let usageSummary = "\(achievedCount) av \(useCount) oppnadd maal."
            return [
                "purpose": .string(purpose),
                "useCount": .integer(useCount),
                "achievedCount": .integer(achievedCount),
                "effectiveness": .float(effectiveness),
                "effectivenessPercent": .string("\(effectivenessPercent)%"),
                "currentWeight": .float(currentWeight),
                "weightLabel": .string(String(format: "%.2f", currentWeight)),
                "usageSummary": .string(usageSummary),
                "lastUsedAt": .float(lastUsedAt)
            ]
        }
    }

    private struct PublishedEntityPurpose: Codable {
        var id: String
        var entityName: String
        var entityType: String
        var entitySubtype: String?
        var purpose: String
        var sourceSuggestionID: String?
        var note: String?
        var publishedAt: Double

        func asObject() -> Object {
            let typeLabel: String = {
                if let entitySubtype, !entitySubtype.isEmpty {
                    return "\(entityType) (\(entitySubtype))"
                }
                return entityType
            }()
            let meaning = "\(entityName) publiserer formaal: \(purpose)."
            var object: Object = [
                "id": .string(id),
                "entityName": .string(entityName),
                "entityType": .string(entityType),
                "entityTypeLabel": .string(typeLabel),
                "purpose": .string(purpose),
                "meaning": .string(meaning),
                "publishedAt": .float(publishedAt)
            ]
            if let entitySubtype, !entitySubtype.isEmpty {
                object["entitySubtype"] = .string(entitySubtype)
            }
            if let sourceSuggestionID, !sourceSuggestionID.isEmpty {
                object["sourceSuggestionId"] = .string(sourceSuggestionID)
            }
            if let note, !note.isEmpty {
                object["note"] = .string(note)
            }
            return object
        }
    }

    private struct DetailedCatalogMatch {
        var entry: CatalogEntry
        var score: Double
        var overlapInterests: [String]
        var reasons: [String]
    }

    private enum QueryResourceBudget: String {
        case low
        case balanced
        case high
    }

    private enum QueryNetworkPolicy: String {
        case preferHealthyThenCached
        case healthyOnly
        case cacheOnly
    }

    private struct QueryConstraints {
        var maxResults: Int
        var maxSources: Int
        var latencyBudgetMs: Int
        var resourceBudget: QueryResourceBudget
        var networkPolicy: QueryNetworkPolicy
        var allowDegradedSources: Bool
    }

    private struct QueryContext {
        var editMode: Bool
        var selectedNodeKind: String?
        var insertionIntent: SupportedInsertionMode
    }

    private struct QueryFilters {
        var categoryPath: Set<String>
        var sourceRefs: Set<String>
        var authRequired: Set<Bool>
        var supportedInsertionModes: Set<SupportedInsertionMode>
        var flowDriven: Set<Bool>
        var editable: Set<Bool>
    }

    private enum SourceHealth: String {
        case online
        case degraded
        case offline
    }

    private struct SourceCandidate {
        var endpoint: String
        var health: SourceHealth
        var purposeFit: Double
        var interestFit: Double
        var sizePenalty: Double
        var score: Double
        var reason: String
        var estimatedRttMs: Int
    }

    private struct QueryScoreBreakdown {
        var text: Double
        var purpose: Double
        var interest: Double
        var compatibility: Double
        var connectivity: Double
        var resourceFit: Double
        var recency: Double

        var finalScore: Double {
            (0.32 * text) +
            (0.24 * purpose) +
            (0.16 * interest) +
            (0.10 * compatibility) +
            (0.08 * connectivity) +
            (0.06 * resourceFit) +
            (0.04 * recency)
        }
    }

    private enum AgreementRolloutMode: String, Codable {
        case newConnectionsOnly = "new_connections_only"
        case reEvaluateExisting = "re_evaluate_existing"
    }

    private enum AgreementNonCompliancePolicy: String, Codable, CaseIterable {
        case manualOnly = "manual_only"
        case autoEscalate = "auto_escalate"
        case autoRequestResign = "auto_request_resign"
        case autoRestrictUntilResolved = "auto_restrict_until_resolved"
    }

    private struct AgreementAccessDelegation: Codable {
        var identityKey: String
        var displayName: String
        var capabilities: [String]
        var grantedByIdentityKey: String
        var grantedAt: Double
        var expiresAt: Double?

        func asObject() -> Object {
            var object: Object = [
                "identityKey": .string(identityKey),
                "displayName": .string(displayName),
                "capabilities": .list(capabilities.map { .string($0) }),
                "grantedByIdentityKey": .string(grantedByIdentityKey),
                "grantedAt": .float(grantedAt)
            ]
            if let expiresAt {
                object["expiresAt"] = .float(expiresAt)
            }
            return object
        }
    }

    private struct AgreementSignature: Codable {
        var identityKey: String
        var signature: String
        var signedAt: Double
        var entityContext: String?

        func asObject() -> Object {
            var object: Object = [
                "identityKey": .string(identityKey),
                "signature": .string(signature),
                "signedAt": .float(signedAt)
            ]
            if let entityContext, !entityContext.isEmpty {
                object["entityContext"] = .string(entityContext)
            }
            return object
        }
    }

    private struct AgreementRecord: Codable {
        var agreementID: String
        var version: Int
        var templateHash: String
        var template: ValueType
        var rolloutMode: AgreementRolloutMode
        var forceSignContract: Bool
        var evictIfNonCompliant: Bool
        var requiresAllPartiesSignature: Bool
        var parties: [String]
        var signatures: [AgreementSignature]
        var createdByIdentityKey: String
        var createdAt: Double
        var status: String

        func asObject() -> Object {
            [
                "agreementId": .string(agreementID),
                "version": .integer(version),
                "templateHash": .string(templateHash),
                "template": template,
                "rolloutMode": .string(rolloutMode.rawValue),
                "forceSignContract": .bool(forceSignContract),
                "evictIfNonCompliant": .bool(evictIfNonCompliant),
                "requiresAllPartiesSignature": .bool(requiresAllPartiesSignature),
                "parties": .list(parties.map { .string($0) }),
                "signatures": .list(signatures.map { .object($0.asObject()) }),
                "createdByIdentityKey": .string(createdByIdentityKey),
                "createdAt": .float(createdAt),
                "status": .string(status)
            ]
        }
    }

    private struct AgreementPreviewSnapshot: Codable {
        var token: String
        var template: ValueType
        var rolloutMode: AgreementRolloutMode
        var forceSignContract: Bool
        var evictIfNonCompliant: Bool
        var requestedByIdentityKey: String
        var requestedAt: Double
        var affectedIdentityKeys: [String]

        func asObject() -> Object {
            [
                "previewToken": .string(token),
                "template": template,
                "rolloutMode": .string(rolloutMode.rawValue),
                "forceSignContract": .bool(forceSignContract),
                "evictIfNonCompliant": .bool(evictIfNonCompliant),
                "requestedByIdentityKey": .string(requestedByIdentityKey),
                "requestedAt": .float(requestedAt),
                "affectedExisting": .integer(affectedIdentityKeys.count),
                "affectedIdentityKeys": .list(affectedIdentityKeys.map { .string($0) })
            ]
        }
    }

    private struct AgreementNonComplianceReport: Codable {
        var id: String
        var agreementID: String?
        var reporterIdentityKey: String
        var reason: String
        var evidenceRef: String?
        var entityContext: String?
        var policy: AgreementNonCompliancePolicy
        var status: String
        var createdAt: Double

        func asObject() -> Object {
            var object: Object = [
                "id": .string(id),
                "reporterIdentityKey": .string(reporterIdentityKey),
                "reason": .string(reason),
                "policy": .string(policy.rawValue),
                "status": .string(status),
                "createdAt": .float(createdAt)
            ]
            if let agreementID, !agreementID.isEmpty {
                object["agreementId"] = .string(agreementID)
            }
            if let evidenceRef, !evidenceRef.isEmpty {
                object["evidenceRef"] = .string(evidenceRef)
            }
            if let entityContext, !entityContext.isEmpty {
                object["entityContext"] = .string(entityContext)
            }
            return object
        }
    }

    private struct AgreementAuditEntry: Codable {
        var id: String
        var action: String
        var actorIdentityKey: String
        var payload: ValueType
        var createdAt: Double

        func asObject() -> Object {
            [
                "id": .string(id),
                "action": .string(action),
                "actorIdentityKey": .string(actorIdentityKey),
                "payload": payload,
                "createdAt": .float(createdAt)
            ]
        }
    }

    enum CodingKeys: CodingKey {
        case generalCell
        case owner
        case entries
        case errors
        case agreementTemplateVersion
        case agreementTemplateDocument
        case agreementAccessDelegationsByIdentity
        case agreementCurrentRecord
        case agreementHistory
        case agreementPreviewsByToken
        case agreementNonComplianceReports
        case agreementNonCompliancePolicyByIdentity
        case agreementAuditLog
        case matchingPromptText
        case matchingSelectedIndex
        case matchingSuggestions
        case matchingBookmarks
        case matchingPurposeStatsByPurpose
        case matchingPublishedEntityPurposes
        case matchingPublishPersonName
        case matchingPublishGroupName
        case matchingPublishGroupType
        case matchingPublishNote
    }

    private let stateQueue = DispatchQueue(label: "Binding.ConfigurationCatalogCell.State")
    nonisolated(unsafe) private var entriesByID: [String: CatalogEntry] = [:]
    nonisolated(unsafe) private var catalogErrorsByEndpoint: [String: CatalogErrorEntry] = [:]
    nonisolated(unsafe) private var syncInProgress: Bool = false
    nonisolated(unsafe) private var agreementTemplateVersion: Int = 1
    nonisolated(unsafe) private var agreementTemplateDocument: ValueType = ConfigurationCatalogCell.defaultAgreementTemplateDocument()
    nonisolated(unsafe) private var agreementAccessDelegationsByIdentity: [String: AgreementAccessDelegation] = [:]
    nonisolated(unsafe) private var agreementCurrentRecord: AgreementRecord?
    nonisolated(unsafe) private var agreementHistory: [AgreementRecord] = []
    nonisolated(unsafe) private var agreementPreviewsByToken: [String: AgreementPreviewSnapshot] = [:]
    nonisolated(unsafe) private var agreementNonComplianceReports: [AgreementNonComplianceReport] = []
    nonisolated(unsafe) private var agreementNonCompliancePolicyByIdentity: [String: AgreementNonCompliancePolicy] = [:]
    nonisolated(unsafe) private var agreementAuditLog: [AgreementAuditEntry] = []
    nonisolated(unsafe) private var matchingPromptText: String = ""
    nonisolated(unsafe) private var matchingSelectedIndex: Int = -1
    nonisolated(unsafe) private var matchingSuggestions: [MatchingSuggestion] = []
    nonisolated(unsafe) private var matchingBookmarks: [MatchingSuggestion] = []
    nonisolated(unsafe) private var matchingPurposeStatsByPurpose: [String: PurposeUsageStat] = [:]
    nonisolated(unsafe) private var matchingPublishedEntityPurposes: [PublishedEntityPurpose] = []
    nonisolated(unsafe) private var matchingPublishPersonName: String = ""
    nonisolated(unsafe) private var matchingPublishGroupName: String = ""
    nonisolated(unsafe) private var matchingPublishGroupType: String = "selskap"
    nonisolated(unsafe) private var matchingPublishNote: String = ""
    nonisolated(unsafe) private var lastQueryState: ValueType = .object([:])

    required init(owner: Identity) async {
        await super.init(owner: owner)
        migrateEntriesForMetadataIfNeeded()
        await setupPermissions(owner: owner)
        await setupKeys(owner: owner)
        await bootstrapDefaultsIfNeeded(requester: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try super.init(from: decoder)
        self.entriesByID = (try? container.decode([String: CatalogEntry].self, forKey: .entries)) ?? [:]
        self.catalogErrorsByEndpoint = (try? container.decode([String: CatalogErrorEntry].self, forKey: .errors)) ?? [:]
        self.agreementTemplateVersion = (try? container.decode(Int.self, forKey: .agreementTemplateVersion)) ?? 1
        self.agreementTemplateDocument = (try? container.decode(ValueType.self, forKey: .agreementTemplateDocument)) ?? ConfigurationCatalogCell.defaultAgreementTemplateDocument()
        self.agreementAccessDelegationsByIdentity = (try? container.decode([String: AgreementAccessDelegation].self, forKey: .agreementAccessDelegationsByIdentity)) ?? [:]
        self.agreementCurrentRecord = try? container.decode(AgreementRecord.self, forKey: .agreementCurrentRecord)
        self.agreementHistory = ConfigurationCatalogCell.trimmedAgreementHistory(
            (try? container.decode([AgreementRecord].self, forKey: .agreementHistory)) ?? []
        )
        self.agreementPreviewsByToken = ConfigurationCatalogCell.trimmedAgreementPreviews(
            (try? container.decode([String: AgreementPreviewSnapshot].self, forKey: .agreementPreviewsByToken)) ?? [:]
        )
        self.agreementNonComplianceReports = ConfigurationCatalogCell.trimmedAgreementNonComplianceReports(
            (try? container.decode([AgreementNonComplianceReport].self, forKey: .agreementNonComplianceReports)) ?? []
        )
        self.agreementNonCompliancePolicyByIdentity = (try? container.decode([String: AgreementNonCompliancePolicy].self, forKey: .agreementNonCompliancePolicyByIdentity)) ?? [:]
        self.agreementAuditLog = ConfigurationCatalogCell.trimmedAgreementAuditLog(
            (try? container.decode([AgreementAuditEntry].self, forKey: .agreementAuditLog)) ?? []
        )
        self.matchingPromptText = (try? container.decode(String.self, forKey: .matchingPromptText)) ?? ""
        self.matchingSelectedIndex = (try? container.decode(Int.self, forKey: .matchingSelectedIndex)) ?? -1
        self.matchingSuggestions = ConfigurationCatalogCell.trimmedMatchingSuggestions(
            (try? container.decode([MatchingSuggestion].self, forKey: .matchingSuggestions)) ?? []
        )
        self.matchingBookmarks = ConfigurationCatalogCell.trimmedMatchingBookmarks(
            (try? container.decode([MatchingSuggestion].self, forKey: .matchingBookmarks)) ?? []
        )
        if self.matchingSuggestions.isEmpty {
            self.matchingSelectedIndex = -1
        } else {
            self.matchingSelectedIndex = min(self.matchingSelectedIndex, self.matchingSuggestions.count - 1)
        }
        self.matchingPurposeStatsByPurpose = (try? container.decode([String: PurposeUsageStat].self, forKey: .matchingPurposeStatsByPurpose)) ?? [:]
        self.matchingPublishedEntityPurposes = (try? container.decode([PublishedEntityPurpose].self, forKey: .matchingPublishedEntityPurposes)) ?? []
        self.matchingPublishPersonName = (try? container.decode(String.self, forKey: .matchingPublishPersonName)) ?? ""
        self.matchingPublishGroupName = (try? container.decode(String.self, forKey: .matchingPublishGroupName)) ?? ""
        self.matchingPublishGroupType = (try? container.decode(String.self, forKey: .matchingPublishGroupType)) ?? "selskap"
        self.matchingPublishNote = (try? container.decode(String.self, forKey: .matchingPublishNote)) ?? ""
        let decodedOwner = try container.decodeIfPresent(Identity.self, forKey: .owner)
        Task { @MainActor in
            self.migrateEntriesForMetadataIfNeeded()
            if let owner = decodedOwner {
                await self.setupPermissions(owner: owner)
                await self.setupKeys(owner: owner)
                await self.bootstrapDefaultsIfNeeded(requester: owner)
            }
        }
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(entriesByID, forKey: .entries)
        try container.encode(catalogErrorsByEndpoint, forKey: .errors)
        try container.encode(agreementTemplateVersion, forKey: .agreementTemplateVersion)
        try container.encode(agreementTemplateDocument, forKey: .agreementTemplateDocument)
        try container.encode(agreementAccessDelegationsByIdentity, forKey: .agreementAccessDelegationsByIdentity)
        try container.encodeIfPresent(agreementCurrentRecord, forKey: .agreementCurrentRecord)
        try container.encode(agreementHistory, forKey: .agreementHistory)
        try container.encode(agreementPreviewsByToken, forKey: .agreementPreviewsByToken)
        try container.encode(agreementNonComplianceReports, forKey: .agreementNonComplianceReports)
        try container.encode(agreementNonCompliancePolicyByIdentity, forKey: .agreementNonCompliancePolicyByIdentity)
        try container.encode(agreementAuditLog, forKey: .agreementAuditLog)
        try container.encode(matchingPromptText, forKey: .matchingPromptText)
        try container.encode(matchingSelectedIndex, forKey: .matchingSelectedIndex)
        try container.encode(matchingSuggestions, forKey: .matchingSuggestions)
        try container.encode(matchingBookmarks, forKey: .matchingBookmarks)
        try container.encode(matchingPurposeStatsByPurpose, forKey: .matchingPurposeStatsByPurpose)
        try container.encode(matchingPublishedEntityPurposes, forKey: .matchingPublishedEntityPurposes)
        try container.encode(matchingPublishPersonName, forKey: .matchingPublishPersonName)
        try container.encode(matchingPublishGroupName, forKey: .matchingPublishGroupName)
        try container.encode(matchingPublishGroupType, forKey: .matchingPublishGroupType)
        try container.encode(matchingPublishNote, forKey: .matchingPublishNote)
    }

    nonisolated private static func trimmedAgreementHistory(_ history: [AgreementRecord]) -> [AgreementRecord] {
        Array(history.suffix(maximumAgreementHistoryEntries))
    }

    nonisolated private static func trimmedAgreementPreviews(_ previews: [String: AgreementPreviewSnapshot]) -> [String: AgreementPreviewSnapshot] {
        guard previews.count > maximumAgreementPreviewSnapshots else { return previews }
        let retained = previews.values
            .sorted { $0.requestedAt > $1.requestedAt }
            .prefix(maximumAgreementPreviewSnapshots)
        return Dictionary(uniqueKeysWithValues: retained.map { ($0.token, $0) })
    }

    nonisolated private static func trimmedAgreementNonComplianceReports(_ reports: [AgreementNonComplianceReport]) -> [AgreementNonComplianceReport] {
        Array(reports.suffix(maximumAgreementNonComplianceReports))
    }

    nonisolated private static func trimmedAgreementAuditLog(_ entries: [AgreementAuditEntry]) -> [AgreementAuditEntry] {
        Array(entries.suffix(maximumAgreementAuditEntries))
    }

    nonisolated private static func trimmedMatchingSuggestions(_ suggestions: [MatchingSuggestion]) -> [MatchingSuggestion] {
        Array(suggestions.prefix(maximumMatchingSuggestionEntries))
    }

    nonisolated private static func trimmedMatchingBookmarks(_ bookmarks: [MatchingSuggestion]) -> [MatchingSuggestion] {
        Array(bookmarks.prefix(maximumMatchingBookmarkEntries))
    }

    private func appendAgreementHistory(_ agreement: AgreementRecord) {
        agreementHistory.append(agreement)
        agreementHistory = Self.trimmedAgreementHistory(agreementHistory)
    }

    private func appendAgreementNonComplianceReport(_ report: AgreementNonComplianceReport) {
        agreementNonComplianceReports.append(report)
        agreementNonComplianceReports = Self.trimmedAgreementNonComplianceReports(agreementNonComplianceReports)
    }

    private func appendAgreementAuditEntry(_ entry: AgreementAuditEntry) {
        agreementAuditLog.append(entry)
        agreementAuditLog = Self.trimmedAgreementAuditLog(agreementAuditLog)
    }

    private func setupPermissions(owner: Identity) async {
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("r---", for: "configurations")
        agreementTemplate.addGrant("r---", for: "catalogEntries")
        agreementTemplate.addGrant("r---", for: "catalogContracts")
        agreementTemplate.addGrant("r---", for: "errorLog")
        MenuSlot.allCases.forEach { agreementTemplate.addGrant("r---", for: $0.keypath) }
        agreementTemplate.addGrant("rw--", for: "addConfiguration")
        agreementTemplate.addGrant("rw--", for: "editConfiguration")
        agreementTemplate.addGrant("rw--", for: "updateConfiguration")
        agreementTemplate.addGrant("rw--", for: "removeConfiguration")
        agreementTemplate.addGrant("rw--", for: "match")
        agreementTemplate.addGrant("rw--", for: "matchPurpose")
        agreementTemplate.addGrant("rw--", for: "matchInterests")
        agreementTemplate.addGrant("rw--", for: "query")
        agreementTemplate.addGrant("rw--", for: "facetCounts")
        agreementTemplate.addGrant("r---", for: "query.state")
        agreementTemplate.addGrant("r---", for: "matching.state")
        agreementTemplate.addGrant("r---", for: "matching.promptText")
        agreementTemplate.addGrant("rw--", for: "matching.promptText")
        agreementTemplate.addGrant("r---", for: "matching.suggestions")
        agreementTemplate.addGrant("r---", for: "matching.selectedSuggestion")
        agreementTemplate.addGrant("r---", for: "matching.selectedIndex")
        agreementTemplate.addGrant("rw--", for: "matching.selectedIndex")
        agreementTemplate.addGrant("r---", for: "matching.bookmarks")
        agreementTemplate.addGrant("r---", for: "matching.purposeStats")
        agreementTemplate.addGrant("r---", for: "matching.entityPurposePublications")
        agreementTemplate.addGrant("r---", for: "matching.publish.personName")
        agreementTemplate.addGrant("rw--", for: "matching.publish.personName")
        agreementTemplate.addGrant("r---", for: "matching.publish.groupName")
        agreementTemplate.addGrant("rw--", for: "matching.publish.groupName")
        agreementTemplate.addGrant("r---", for: "matching.publish.groupType")
        agreementTemplate.addGrant("rw--", for: "matching.publish.groupType")
        agreementTemplate.addGrant("r---", for: "matching.publish.note")
        agreementTemplate.addGrant("rw--", for: "matching.publish.note")
        agreementTemplate.addGrant("r---", for: "matching.runPrompt")
        agreementTemplate.addGrant("rw--", for: "matching.runPrompt")
        agreementTemplate.addGrant("r---", for: "matching.runPromptInput")
        agreementTemplate.addGrant("rw--", for: "matching.runPromptInput")
        agreementTemplate.addGrant("rw--", for: "matching.select")
        agreementTemplate.addGrant("rw--", for: "matching.selectIndex")
        agreementTemplate.addGrant("rw--", for: "matching.loadSelectedToPorthole")
        agreementTemplate.addGrant("rw--", for: "matching.previewSelected")
        agreementTemplate.addGrant("rw--", for: "matching.saveSelectedToMenu")
        agreementTemplate.addGrant("rw--", for: "matching.bookmarkSelected")
        agreementTemplate.addGrant("rw--", for: "matching.markSelectedUsed")
        agreementTemplate.addGrant("rw--", for: "matching.markSelectedGoalAchieved")
        agreementTemplate.addGrant("rw--", for: "matching.publishEntityPurpose")
        agreementTemplate.addGrant("rw--", for: "matching.clear")
        agreementTemplate.addGrant("r---", for: "syncScaffoldPurposeGoals")
        agreementTemplate.addGrant("rw--", for: "syncScaffoldPurposeGoals")
        agreementTemplate.addGrant("r---", for: "feed")
        agreementTemplate.addGrant("r---", for: "agreementTemplate.state")
        agreementTemplate.addGrant("rw--", for: "agreementTemplate.preview")
        agreementTemplate.addGrant("rw--", for: "agreementTemplate.apply")
        agreementTemplate.addGrant("rw--", for: "agreementTemplate.access.grant")
        agreementTemplate.addGrant("rw--", for: "agreementTemplate.access.revoke")
        agreementTemplate.addGrant("r---", for: "agreementTemplate.auditLog")
        agreementTemplate.addGrant("r---", for: "agreements.current")
        agreementTemplate.addGrant("r---", for: "agreements.history")
        agreementTemplate.addGrant("rw--", for: "agreements.sign")
        agreementTemplate.addGrant("rw--", for: "agreements.nonCompliant.report")
        agreementTemplate.addGrant("rw--", for: "agreements.nonCompliant.policy")
    }

    private func setupKeys(owner: Identity) async {
        await registerGet(key: "state", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "state", for: requester) else { return .string("denied") }
            return self.stateValue()
        }

        await registerGet(key: "configurations", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "configurations", for: requester) else { return .string("denied") }
            return .list(self.sortedEntries().map { .cellConfiguration($0.configuration) })
        }

        await registerGet(key: "catalogEntries", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "catalogEntries", for: requester) else { return .string("denied") }
            return .list(self.sortedEntries().map { .object($0.asObject()) })
        }

        await registerGet(key: "catalogContracts", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "catalogContracts", for: requester) else { return .string("denied") }
            return .list(self.sortedEntries().map { .object($0.asObject()) })
        }

        await registerGet(key: "errorLog", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "errorLog", for: requester) else { return .string("denied") }
            return .list(self.sortedCatalogErrors().map { .object($0.asObject()) })
        }

        for slot in MenuSlot.allCases {
            await registerGet(key: slot.keypath, owner: owner) { [weak self] requester in
                guard let self = self else { return .null }
                guard await self.validateAccess("r---", at: slot.keypath, for: requester) else { return .string("denied") }
                return .list(self.menuConfigurations(for: slot).map { .cellConfiguration($0) })
            }
        }

        await registerSet(key: "addConfiguration", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "addConfiguration", for: requester) else { return .string("denied") }
            guard let catalogPayload = self.decodeCatalogPayload(payload, requireID: false) else {
                return .string("error: invalid payload for addConfiguration")
            }
            let entry = self.upsert(from: catalogPayload, keepExistingIDWhenMissing: false)
            await self.emitCatalogEvent(operation: "addConfiguration", entry: entry, requester: requester)
            return self.stateValue()
        }

        await registerSet(key: "editConfiguration", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "editConfiguration", for: requester) else { return .string("denied") }
            guard let catalogPayload = self.decodeCatalogPayload(payload, requireID: true) else {
                return .string("error: invalid payload for editConfiguration")
            }
            let entry = self.upsert(from: catalogPayload, keepExistingIDWhenMissing: true)
            await self.emitCatalogEvent(operation: "editConfiguration", entry: entry, requester: requester)
            return self.stateValue()
        }

        await registerSet(key: "updateConfiguration", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "updateConfiguration", for: requester) else { return .string("denied") }
            guard let catalogPayload = self.decodeCatalogPayload(payload, requireID: true) else {
                return .string("error: invalid payload for updateConfiguration")
            }
            let entry = self.upsert(from: catalogPayload, keepExistingIDWhenMissing: true)
            await self.emitCatalogEvent(operation: "updateConfiguration", entry: entry, requester: requester)
            return self.stateValue()
        }

        await registerSet(key: "removeConfiguration", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "removeConfiguration", for: requester) else { return .string("denied") }
            guard let id = self.extractID(payload), !id.isEmpty else {
                return .string("error: missing id")
            }
            let removed = self.remove(id: id)
            if removed {
                await self.emitCatalogEvent(operation: "removeConfiguration", entry: nil, requester: requester)
            }
            return self.stateValue()
        }

        await registerSet(key: "matchPurpose", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matchPurpose", for: requester) else { return .string("denied") }
            guard let purposeTerm = self.extractPurposeTerm(payload), !purposeTerm.isEmpty else {
                return .list([])
            }
            let result = self.matchConfigurations(purpose: purposeTerm, interests: nil, menuSlot: nil, limit: nil)
            return .list(result.map { .cellConfiguration($0.configuration) })
        }

        await registerSet(key: "matchInterests", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matchInterests", for: requester) else { return .string("denied") }
            guard let interests = self.extractInterests(payload), !interests.isEmpty else {
                return .list([])
            }
            let result = self.matchConfigurations(purpose: nil, interests: interests, menuSlot: nil, limit: nil)
            return .list(result.map { .cellConfiguration($0.configuration) })
        }

        await registerSet(key: "match", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "match", for: requester) else { return .string("denied") }
            let purpose = self.extractPurposeTerm(payload)
            let interests = self.extractInterests(payload)
            let menuSlot = self.extractMenuSlot(payload)
            let limit = self.extractLimit(payload)
            let result = self.matchConfigurations(purpose: purpose, interests: interests, menuSlot: menuSlot, limit: limit)
            return .list(result.map { .cellConfiguration($0.configuration) })
        }

        await registerSet(key: "query", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "query", for: requester) else { return .string("denied") }
            return self.queryCatalog(payload: payload, requester: requester)
        }

        await registerSet(key: "facetCounts", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "facetCounts", for: requester) else { return .string("denied") }
            return self.queryFacetCounts(payload: payload, requester: requester)
        }

        await registerGet(key: "query.state", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "query.state", for: requester) else { return .string("denied") }
            return self.stateQueue.sync { self.lastQueryState }
        }

        await registerGet(key: "matching.state", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.state", for: requester) else { return .string("denied") }
            return self.matchingStateValue()
        }

        await registerGet(key: "matching.promptText", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.promptText", for: requester) else { return .string("denied") }
            return self.matchingPromptTextValue()
        }

        await registerSet(key: "matching.promptText", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.promptText", for: requester) else { return .string("denied") }
            return self.updateMatchingPromptText(payload)
        }

        await registerGet(key: "matching.publish.personName", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.publish.personName", for: requester) else { return .string("denied") }
            return self.matchingPublishPersonNameValue()
        }

        await registerSet(key: "matching.publish.personName", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.publish.personName", for: requester) else { return .string("denied") }
            return self.updateMatchingPublishField(payload, field: .personName)
        }

        await registerGet(key: "matching.publish.groupName", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.publish.groupName", for: requester) else { return .string("denied") }
            return self.matchingPublishGroupNameValue()
        }

        await registerSet(key: "matching.publish.groupName", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.publish.groupName", for: requester) else { return .string("denied") }
            return self.updateMatchingPublishField(payload, field: .groupName)
        }

        await registerGet(key: "matching.publish.groupType", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.publish.groupType", for: requester) else { return .string("denied") }
            return self.matchingPublishGroupTypeValue()
        }

        await registerSet(key: "matching.publish.groupType", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.publish.groupType", for: requester) else { return .string("denied") }
            return self.updateMatchingPublishField(payload, field: .groupType)
        }

        await registerGet(key: "matching.publish.note", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.publish.note", for: requester) else { return .string("denied") }
            return self.matchingPublishNoteValue()
        }

        await registerSet(key: "matching.publish.note", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.publish.note", for: requester) else { return .string("denied") }
            return self.updateMatchingPublishField(payload, field: .note)
        }

        await registerGet(key: "matching.suggestions", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.suggestions", for: requester) else { return .string("denied") }
            return self.matchingSuggestionsValue()
        }

        await registerGet(key: "matching.selectedSuggestion", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.selectedSuggestion", for: requester) else { return .string("denied") }
            return self.matchingSelectedSuggestionValue()
        }

        await registerGet(key: "matching.selectedIndex", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.selectedIndex", for: requester) else { return .string("denied") }
            return self.matchingSelectedIndexValue()
        }

        await registerSet(key: "matching.selectedIndex", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.selectedIndex", for: requester) else { return .string("denied") }
            return self.selectMatchingSuggestionByIndexPayload(payload)
        }

        await registerGet(key: "matching.bookmarks", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.bookmarks", for: requester) else { return .string("denied") }
            return self.matchingBookmarksValue()
        }

        await registerGet(key: "matching.purposeStats", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.purposeStats", for: requester) else { return .string("denied") }
            return self.matchingPurposeStatsValue()
        }

        await registerGet(key: "matching.entityPurposePublications", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.entityPurposePublications", for: requester) else { return .string("denied") }
            return self.matchingEntityPurposePublicationsValue()
        }

        await registerGet(key: "matching.runPrompt", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.runPrompt", for: requester) else { return .string("denied") }
            return .object([
                "status": .string("ready"),
                "promptText": .string(self.stateQueue.sync { self.matchingPromptText }),
                "state": self.matchingStateValue()
            ])
        }

        await registerSet(key: "matching.runPrompt", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.runPrompt", for: requester) else { return .string("denied") }
            return await self.runMatchingPrompt(payload, requester: requester)
        }

        await registerGet(key: "matching.runPromptInput", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.runPromptInput", for: requester) else { return .string("denied") }
            return .object([
                "status": .string("ready"),
                "promptText": .string(self.stateQueue.sync { self.matchingPromptText }),
                "state": self.matchingStateValue()
            ])
        }

        await registerSet(key: "matching.runPromptInput", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.runPromptInput", for: requester) else { return .string("denied") }
            return await self.runMatchingPrompt(payload, requester: requester)
        }

        await registerSet(key: "matching.select", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.select", for: requester) else { return .string("denied") }
            return self.selectMatchingSuggestion(payload)
        }

        await registerSet(key: "matching.selectIndex", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.selectIndex", for: requester) else { return .string("denied") }
            return self.selectMatchingSuggestionByIndexPayload(payload)
        }

        await registerSet(key: "matching.loadSelectedToPorthole", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.loadSelectedToPorthole", for: requester) else { return .string("denied") }
            return await self.loadSelectedMatchingSuggestionToPorthole(requester: requester)
        }

        await registerSet(key: "matching.previewSelected", owner: owner) { [weak self] requester, _ in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.previewSelected", for: requester) else { return .string("denied") }
            return self.previewSelectedMatchingSuggestion()
        }

        await registerSet(key: "matching.saveSelectedToMenu", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.saveSelectedToMenu", for: requester) else { return .string("denied") }
            return await self.saveSelectedMatchingSuggestionToMenu(payload: payload, requester: requester)
        }

        await registerSet(key: "matching.bookmarkSelected", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.bookmarkSelected", for: requester) else { return .string("denied") }
            return self.bookmarkSelectedMatchingSuggestion()
        }

        await registerSet(key: "matching.markSelectedUsed", owner: owner) { [weak self] requester, _ in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.markSelectedUsed", for: requester) else { return .string("denied") }
            return await self.markSelectedSuggestionUsage(achievedGoal: false, requester: requester)
        }

        await registerSet(key: "matching.markSelectedGoalAchieved", owner: owner) { [weak self] requester, _ in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.markSelectedGoalAchieved", for: requester) else { return .string("denied") }
            return await self.markSelectedSuggestionUsage(achievedGoal: true, requester: requester)
        }

        await registerSet(key: "matching.publishEntityPurpose", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.publishEntityPurpose", for: requester) else { return .string("denied") }
            return await self.publishEntityPurpose(payload: payload, requester: requester)
        }

        await registerSet(key: "matching.clear", owner: owner) { [weak self] requester, _ in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.clear", for: requester) else { return .string("denied") }
            return self.clearMatchingSuggestions()
        }

        await registerGet(key: "syncScaffoldPurposeGoals", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "syncScaffoldPurposeGoals", for: requester) else { return .string("denied") }
            return .object([
                "status": .string("ready"),
                "state": self.stateValue()
            ])
        }

        await registerSet(key: "syncScaffoldPurposeGoals", owner: owner) { [weak self] requester, _ in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "syncScaffoldPurposeGoals", for: requester) else { return .string("denied") }
            let importedCount = await self.syncScaffoldPurposeGoals(requester: requester)
            await self.emitCatalogEvent(operation: "syncScaffoldPurposeGoals", entry: nil, requester: requester)
            var result: Object = [:]
            result["importedCount"] = .integer(importedCount)
            result["state"] = self.stateValue()
            return .object(result)
        }

        await registerGet(key: "agreementTemplate.state", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.hasAgreementCapability("agreementTemplate.read", requester: requester) else {
                return .string("denied")
            }
            return await self.agreementTemplateStateValue(requester: requester)
        }

        await registerSet(key: "agreementTemplate.preview", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            return await self.handleAgreementTemplatePreview(payload: payload, requester: requester)
        }

        await registerSet(key: "agreementTemplate.apply", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            return await self.handleAgreementTemplateApply(payload: payload, requester: requester)
        }

        await registerSet(key: "agreementTemplate.access.grant", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            return await self.handleAgreementAccessGrant(payload: payload, requester: requester)
        }

        await registerSet(key: "agreementTemplate.access.revoke", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            return await self.handleAgreementAccessRevoke(payload: payload, requester: requester)
        }

        await registerGet(key: "agreementTemplate.auditLog", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.hasAgreementCapability("agreementTemplate.read", requester: requester) else {
                return .string("denied")
            }
            let items = self.stateQueue.sync { self.agreementAuditLog.map { ValueType.object($0.asObject()) } }
            return .list(items)
        }

        await registerGet(key: "agreements.current", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.hasAgreementCapability("agreementTemplate.read", requester: requester) else {
                return .string("denied")
            }
            return self.stateQueue.sync {
                guard let current = self.agreementCurrentRecord else { return .null }
                return .object(current.asObject())
            }
        }

        await registerGet(key: "agreements.history", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.hasAgreementCapability("agreementTemplate.read", requester: requester) else {
                return .string("denied")
            }
            let history = self.stateQueue.sync { self.agreementHistory.map { ValueType.object($0.asObject()) } }
            return .list(history)
        }

        await registerSet(key: "agreements.sign", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            return await self.handleAgreementSign(payload: payload, requester: requester)
        }

        await registerSet(key: "agreements.nonCompliant.report", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            return await self.handleNonCompliantReport(payload: payload, requester: requester)
        }

        await registerSet(key: "agreements.nonCompliant.policy", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            return await self.handleNonCompliantPolicy(payload: payload, requester: requester)
        }
    }

    private func stateValue() -> ValueType {
        let entries = sortedEntries()
        var object: Object = [:]
        object["count"] = .integer(entries.count)
        object["purposes"] = .list(Array(Set(entries.map { $0.purpose })).sorted().map { .string($0) })
        let (errorCount, syncActive, agreementVersion, delegationCount, nonCompliantOpenCount, currentAgreementID) = stateQueue.sync {
            let openCount = agreementNonComplianceReports.filter { $0.status != "resolved" }.count
            return (
                catalogErrorsByEndpoint.count,
                syncInProgress,
                agreementTemplateVersion,
                agreementAccessDelegationsByIdentity.count,
                openCount,
                agreementCurrentRecord?.agreementID
            )
        }
        object["errorCount"] = .integer(errorCount)
        object["syncInProgress"] = .bool(syncActive)
        object["agreementTemplateVersion"] = .integer(agreementVersion)
        object["agreementDelegationCount"] = .integer(delegationCount)
        object["agreementNonCompliantOpenCount"] = .integer(nonCompliantOpenCount)
        let matchingSnapshot = stateQueue.sync { (matchingSuggestions.count, matchingBookmarks.count) }
        object["matchingSuggestionCount"] = .integer(matchingSnapshot.0)
        object["matchingBookmarkCount"] = .integer(matchingSnapshot.1)
        if let currentAgreementID {
            object["currentAgreementId"] = .string(currentAgreementID)
        }
        for slot in MenuSlot.allCases {
            let count = entries.filter { $0.menuSlots.contains(slot) }.count
            object["\(slot.rawValue)Count"] = .integer(count)
        }
        return .object(object)
    }

    private func sortedEntries() -> [CatalogEntry] {
        stateQueue.sync {
            entriesByID.values.sorted {
                if $0.purpose == $1.purpose {
                    return $0.configuration.name.localizedCaseInsensitiveCompare($1.configuration.name) == .orderedAscending
                }
                return $0.purpose.localizedCaseInsensitiveCompare($1.purpose) == .orderedAscending
            }
        }
    }

    private func menuConfigurations(for slot: MenuSlot) -> [CellConfiguration] {
        sortedEntries()
            .filter { $0.menuSlots.contains(slot) }
            .map(\.configuration)
    }

    private func sortedCatalogErrors() -> [CatalogErrorEntry] {
        stateQueue.sync {
            catalogErrorsByEndpoint.values.sorted { lhs, rhs in
                if lhs.lastSeenAt == rhs.lastSeenAt {
                    return lhs.endpoint.localizedCaseInsensitiveCompare(rhs.endpoint) == .orderedAscending
                }
                return lhs.lastSeenAt > rhs.lastSeenAt
            }
        }
    }

    nonisolated private static var supportedAgreementCapabilities: [String] {
        [
            "agreementTemplate.read",
            "agreementTemplate.write",
            "agreementTemplate.apply.newConnections",
            "agreementTemplate.apply.reEvaluateExisting",
            "agreementTemplate.contracts.enforce",
            "agreementTemplate.access.manage"
        ]
    }

    nonisolated private static func defaultAgreementTemplateDocument() -> ValueType {
        .object([
            "description": .string("Capability-based agreement template."),
            "requiresAllPartiesSignature": .bool(true),
            "capabilities": .list(supportedAgreementCapabilities.map { .string($0) })
        ])
    }

    private func identityKey(for identity: Identity) -> String {
        if let data = try? JSONEncoder().encode(identity) {
            return data.base64EncodedString()
        }
        return String(describing: identity)
    }

    private func identityLabel(for identityKey: String) -> String {
        if identityKey.count <= 14 {
            return identityKey
        }
        return "\(identityKey.prefix(8))...\(identityKey.suffix(4))"
    }

    private func isOwnerIdentity(_ requester: Identity) async -> Bool {
        guard let owner = try? await getOwner(requester: requester) else { return false }
        return identityKey(for: owner) == identityKey(for: requester)
    }

    private func capabilitiesForIdentity(_ identityKey: String) -> Set<String> {
        stateQueue.sync {
            guard let delegation = agreementAccessDelegationsByIdentity[identityKey] else { return [] }
            if let expiresAt = delegation.expiresAt, expiresAt <= Date().timeIntervalSince1970 {
                agreementAccessDelegationsByIdentity.removeValue(forKey: identityKey)
                return []
            }
            return Set(delegation.capabilities)
        }
    }

    private func hasAgreementCapability(_ capability: String, requester: Identity) async -> Bool {
        if await isOwnerIdentity(requester) {
            return true
        }
        let requesterKey = identityKey(for: requester)
        let granted = capabilitiesForIdentity(requesterKey)
        if granted.contains(capability) {
            return true
        }

        if capability == "agreementTemplate.read", granted.contains("agreementTemplate.write") {
            return true
        }
        return false
    }

    private func extractString(_ value: ValueType?) -> String? {
        guard let value else { return nil }
        if case let .string(result) = value, !result.isEmpty {
            return result
        }
        return nil
    }

    private func extractBool(_ value: ValueType?, default defaultValue: Bool) -> Bool {
        guard let value else { return defaultValue }
        if case let .bool(flag) = value {
            return flag
        }
        return defaultValue
    }

    private func extractInt(_ value: ValueType?, default defaultValue: Int) -> Int {
        guard let value else { return defaultValue }
        switch value {
        case .integer(let number):
            return number
        case .number(let number):
            return number
        case .float(let number):
            return Int(number)
        default:
            return defaultValue
        }
    }

    private func extractDouble(_ value: ValueType?, default defaultValue: Double) -> Double {
        guard let value else { return defaultValue }
        switch value {
        case .float(let number):
            return number
        case .integer(let number):
            return Double(number)
        case .number(let number):
            return Double(number)
        default:
            return defaultValue
        }
    }

    private func extractCapabilityList(_ value: ValueType?) -> [String] {
        guard let value else { return [] }
        switch value {
        case .string(let capability):
            return capability.isEmpty ? [] : [capability]
        case .list(let values):
            return values.compactMap {
                if case let .string(capability) = $0, !capability.isEmpty {
                    return capability
                }
                return nil
            }
        default:
            return []
        }
    }

    private func rolloutMode(from object: Object) -> AgreementRolloutMode {
        if case let .string(mode)? = object["rolloutMode"] {
            return AgreementRolloutMode(rawValue: mode) ?? .newConnectionsOnly
        }
        return .newConnectionsOnly
    }

    private func identityKeyFromObject(_ object: Object) -> String? {
        if let direct = extractString(object["identityKey"]) {
            return direct
        }
        if let direct = extractString(object["targetIdentityKey"]) {
            return direct
        }
        if let direct = extractString(object["identity"]) {
            return direct
        }
        if case let .identity(identity)? = object["identity"] {
            return identityKey(for: identity)
        }
        return nil
    }

    private func activeAgreementIdentityKeys() -> [String] {
        stateQueue.sync {
            var keys = Set<String>()
            keys.formUnion(agreementAccessDelegationsByIdentity.keys)
            if let current = agreementCurrentRecord {
                keys.formUnion(current.parties)
                keys.formUnion(current.signatures.map(\.identityKey))
            }
            return keys.sorted()
        }
    }

    private func normalizeTemplateValue(_ payloadTemplate: ValueType?) -> ValueType {
        guard let payloadTemplate else {
            return stateQueue.sync { agreementTemplateDocument }
        }
        return payloadTemplate
    }

    private func agreementTemplateStateValue(requester: Identity) async -> ValueType {
        let requesterKey = identityKey(for: requester)
        let ownerKey: String
        if let owner = try? await getOwner(requester: requester) {
            ownerKey = identityKey(for: owner)
        } else {
            ownerKey = ""
        }

        return stateQueue.sync {
            let grants = agreementAccessDelegationsByIdentity.values
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                .map { ValueType.object($0.asObject()) }

            let reports = agreementNonComplianceReports.map { ValueType.object($0.asObject()) }
            let openReports = agreementNonComplianceReports.filter { $0.status != "resolved" }.count

            var object: Object = [
                "ownerIdentityKey": .string(ownerKey),
                "requesterIdentityKey": .string(requesterKey),
                "agreementTemplateVersion": .integer(agreementTemplateVersion),
                "template": agreementTemplateDocument,
                "capabilities": .list(Self.supportedAgreementCapabilities.map { .string($0) }),
                "accessDelegations": .list(grants),
                "activePreviewCount": .integer(agreementPreviewsByToken.count),
                "nonCompliantOpenCount": .integer(openReports),
                "nonCompliantReports": .list(reports)
            ]
            if let current = agreementCurrentRecord {
                object["currentAgreement"] = .object(current.asObject())
            }
            return .object(object)
        }
    }

    private func handleAgreementTemplatePreview(payload: ValueType, requester: Identity) async -> ValueType {
        guard await hasAgreementCapability("agreementTemplate.write", requester: requester) else {
            return .string("denied")
        }
        guard case let .object(object) = payload else {
            return .string("error: invalid payload for agreementTemplate.preview")
        }

        let mode = rolloutMode(from: object)
        let template = normalizeTemplateValue(object["template"])
        let requesterKey = identityKey(for: requester)
        let forceSignContract = extractBool(object["forceSignContract"], default: mode == .reEvaluateExisting)
        let evictIfNonCompliant = extractBool(object["evictIfNonCompliant"], default: false)
        let affected = activeAgreementIdentityKeys()
        let token = UUID().uuidString
        let now = Date().timeIntervalSince1970

        let snapshot = AgreementPreviewSnapshot(
            token: token,
            template: template,
            rolloutMode: mode,
            forceSignContract: forceSignContract,
            evictIfNonCompliant: evictIfNonCompliant,
            requestedByIdentityKey: requesterKey,
            requestedAt: now,
            affectedIdentityKeys: affected
        )

        stateQueue.sync {
            agreementPreviewsByToken[token] = snapshot
            if agreementPreviewsByToken.count > Self.maximumAgreementPreviewSnapshots {
                let keysToDrop = agreementPreviewsByToken.values
                    .sorted { $0.requestedAt < $1.requestedAt }
                    .prefix(agreementPreviewsByToken.count - Self.maximumAgreementPreviewSnapshots)
                    .map(\.token)
                keysToDrop.forEach { agreementPreviewsByToken.removeValue(forKey: $0) }
            }
            appendAgreementAuditEntry(
                AgreementAuditEntry(
                    id: UUID().uuidString,
                    action: "agreementTemplate.preview",
                    actorIdentityKey: requesterKey,
                    payload: .object(snapshot.asObject()),
                    createdAt: now
                )
            )
        }

        var response = snapshot.asObject()
        response["requiresSignContract"] = .bool(forceSignContract && mode == .reEvaluateExisting)
        response["wouldBeRevoked"] = evictIfNonCompliant ? .list(affected.map { .string($0) }) : .list([])
        response["state"] = await agreementTemplateStateValue(requester: requester)

        await emitAgreementEvent(
            action: "agreement.preview",
            payload: [
                "previewToken": .string(token),
                "rolloutMode": .string(mode.rawValue),
                "affectedExisting": .integer(affected.count)
            ],
            requester: requester
        )
        return .object(response)
    }

    private func handleAgreementTemplateApply(payload: ValueType, requester: Identity) async -> ValueType {
        guard case let .object(object) = payload else {
            return .string("error: invalid payload for agreementTemplate.apply")
        }

        let requesterKey = identityKey(for: requester)
        let ownerKey: String
        if let owner = try? await getOwner(requester: requester) {
            ownerKey = identityKey(for: owner)
        } else {
            ownerKey = requesterKey
        }

        let requestedPreviewToken = extractString(object["previewToken"])
        let mode: AgreementRolloutMode
        let template: ValueType
        let forceSignContract: Bool
        let evictIfNonCompliant: Bool
        let affectedIdentityKeys: [String]

        if let requestedPreviewToken,
           let cachedPreview = stateQueue.sync(execute: { agreementPreviewsByToken[requestedPreviewToken] }) {
            mode = cachedPreview.rolloutMode
            template = cachedPreview.template
            forceSignContract = cachedPreview.forceSignContract
            evictIfNonCompliant = cachedPreview.evictIfNonCompliant
            affectedIdentityKeys = cachedPreview.affectedIdentityKeys
        } else {
            mode = rolloutMode(from: object)
            template = normalizeTemplateValue(object["template"])
            forceSignContract = extractBool(object["forceSignContract"], default: mode == .reEvaluateExisting)
            evictIfNonCompliant = extractBool(object["evictIfNonCompliant"], default: false)
            affectedIdentityKeys = activeAgreementIdentityKeys()
        }

        let requiredCapability: String = (mode == .reEvaluateExisting)
            ? "agreementTemplate.apply.reEvaluateExisting"
            : "agreementTemplate.apply.newConnections"
        guard await hasAgreementCapability(requiredCapability, requester: requester) else {
            return .string("denied")
        }

        let requiresAllPartiesSignature = extractBool(object["requiresAllPartiesSignature"], default: true)
        var parties = extractCapabilityList(object["parties"])
        if parties.isEmpty {
            parties = Array(Set(affectedIdentityKeys + [ownerKey, requesterKey])).sorted()
        }

        let now = Date().timeIntervalSince1970
        let templateHash = {
            if let data = try? JSONEncoder().encode(template) {
                return data.base64EncodedString()
            }
            return UUID().uuidString
        }()

        let currentVersion = stateQueue.sync { agreementTemplateVersion }
        let agreement = AgreementRecord(
            agreementID: UUID().uuidString,
            version: currentVersion + 1,
            templateHash: templateHash,
            template: template,
            rolloutMode: mode,
            forceSignContract: forceSignContract,
            evictIfNonCompliant: evictIfNonCompliant,
            requiresAllPartiesSignature: requiresAllPartiesSignature,
            parties: parties,
            signatures: [],
            createdByIdentityKey: requesterKey,
            createdAt: now,
            status: requiresAllPartiesSignature ? "pending_signatures" : "active"
        )

        var generatedReports: [AgreementNonComplianceReport] = []
        stateQueue.sync {
            agreementTemplateVersion = agreement.version
            agreementTemplateDocument = template
            agreementCurrentRecord = agreement
            appendAgreementHistory(agreement)
            if let requestedPreviewToken {
                agreementPreviewsByToken.removeValue(forKey: requestedPreviewToken)
            }
            if mode == .reEvaluateExisting && forceSignContract {
                for identityKey in affectedIdentityKeys where identityKey != requesterKey {
                    let policy = agreementNonCompliancePolicyByIdentity[identityKey] ?? .manualOnly
                    let report = AgreementNonComplianceReport(
                        id: UUID().uuidString,
                        agreementID: agreement.agreementID,
                        reporterIdentityKey: identityKey,
                        reason: "Agreement template updated; renewed signContract required.",
                        evidenceRef: "agreement://\(agreement.agreementID)",
                        entityContext: nil,
                        policy: policy,
                        status: policy == .autoRestrictUntilResolved || evictIfNonCompliant ? "restricted" : "open",
                        createdAt: now
                    )
                    appendAgreementNonComplianceReport(report)
                    generatedReports.append(report)
                }
            }
            appendAgreementAuditEntry(
                AgreementAuditEntry(
                    id: UUID().uuidString,
                    action: "agreementTemplate.apply",
                    actorIdentityKey: requesterKey,
                    payload: .object([
                        "agreementId": .string(agreement.agreementID),
                        "rolloutMode": .string(mode.rawValue),
                        "affectedExisting": .integer(affectedIdentityKeys.count),
                        "generatedNonCompliantReports": .integer(generatedReports.count)
                    ]),
                    createdAt: now
                )
            )
        }

        await emitAgreementEvent(
            action: "agreement.applied",
            payload: [
                "agreementId": .string(agreement.agreementID),
                "version": .integer(agreement.version),
                "rolloutMode": .string(mode.rawValue),
                "generatedNonCompliantReports": .integer(generatedReports.count)
            ],
            requester: requester
        )

        let response: Object = [
            "agreement": .object(agreement.asObject()),
            "generatedNonCompliantReports": .list(generatedReports.map { .object($0.asObject()) }),
            "state": await agreementTemplateStateValue(requester: requester)
        ]
        return .object(response)
    }

    private func handleAgreementAccessGrant(payload: ValueType, requester: Identity) async -> ValueType {
        guard await hasAgreementCapability("agreementTemplate.access.manage", requester: requester) else {
            return .string("denied")
        }
        guard case let .object(object) = payload else {
            return .string("error: invalid payload for agreementTemplate.access.grant")
        }
        guard let targetIdentityKey = identityKeyFromObject(object), !targetIdentityKey.isEmpty else {
            return .string("error: missing identityKey")
        }

        let capabilities = extractCapabilityList(object["capabilities"])
        guard !capabilities.isEmpty else {
            return .string("error: no capabilities provided")
        }
        let unsupported = capabilities.filter { !Self.supportedAgreementCapabilities.contains($0) }
        guard unsupported.isEmpty else {
            return .string("error: unsupported capabilities \(unsupported.joined(separator: ", "))")
        }

        let requesterKey = identityKey(for: requester)
        let isOwner = await isOwnerIdentity(requester)
        if !isOwner {
            let requesterCapabilities = capabilitiesForIdentity(requesterKey)
            let illegalDelegation = capabilities.first { !requesterCapabilities.contains($0) }
            if let illegalDelegation {
                return .string("denied: cannot delegate capability '\(illegalDelegation)'")
            }
        }

        let expiresAt: Double? = {
            if case let .float(value)? = object["expiresAt"] { return value }
            if case let .integer(value)? = object["expiresAt"] { return Double(value) }
            if case let .number(value)? = object["expiresAt"] { return Double(value) }
            return nil
        }()

        let displayName = extractString(object["displayName"]) ?? identityLabel(for: targetIdentityKey)
        let now = Date().timeIntervalSince1970
        let delegation = AgreementAccessDelegation(
            identityKey: targetIdentityKey,
            displayName: displayName,
            capabilities: Array(Set(capabilities)).sorted(),
            grantedByIdentityKey: requesterKey,
            grantedAt: now,
            expiresAt: expiresAt
        )

        stateQueue.sync {
            agreementAccessDelegationsByIdentity[targetIdentityKey] = delegation
            appendAgreementAuditEntry(
                AgreementAuditEntry(
                    id: UUID().uuidString,
                    action: "agreementTemplate.access.grant",
                    actorIdentityKey: requesterKey,
                    payload: .object(delegation.asObject()),
                    createdAt: now
                )
            )
        }

        await emitAgreementEvent(
            action: "agreement.access.grant",
            payload: [
                "identityKey": .string(targetIdentityKey),
                "capabilities": .list(delegation.capabilities.map { .string($0) })
            ],
            requester: requester
        )

        return .object([
            "delegation": .object(delegation.asObject()),
            "state": await agreementTemplateStateValue(requester: requester)
        ])
    }

    private func handleAgreementAccessRevoke(payload: ValueType, requester: Identity) async -> ValueType {
        guard await hasAgreementCapability("agreementTemplate.access.manage", requester: requester) else {
            return .string("denied")
        }
        guard case let .object(object) = payload else {
            return .string("error: invalid payload for agreementTemplate.access.revoke")
        }
        guard let targetIdentityKey = identityKeyFromObject(object), !targetIdentityKey.isEmpty else {
            return .string("error: missing identityKey")
        }

        let capabilitiesToRevoke = Set(extractCapabilityList(object["capabilities"]))
        let requesterKey = identityKey(for: requester)
        let now = Date().timeIntervalSince1970

        let revokedObject: Object? = stateQueue.sync {
            guard var delegation = agreementAccessDelegationsByIdentity[targetIdentityKey] else { return nil }
            if capabilitiesToRevoke.isEmpty {
                agreementAccessDelegationsByIdentity.removeValue(forKey: targetIdentityKey)
            } else {
                delegation.capabilities.removeAll { capabilitiesToRevoke.contains($0) }
                if delegation.capabilities.isEmpty {
                    agreementAccessDelegationsByIdentity.removeValue(forKey: targetIdentityKey)
                } else {
                    agreementAccessDelegationsByIdentity[targetIdentityKey] = delegation
                }
            }
            let payload: Object = [
                "identityKey": .string(targetIdentityKey),
                "revokedCapabilities": .list(Array(capabilitiesToRevoke).sorted().map { .string($0) })
            ]
            appendAgreementAuditEntry(
                AgreementAuditEntry(
                    id: UUID().uuidString,
                    action: "agreementTemplate.access.revoke",
                    actorIdentityKey: requesterKey,
                    payload: .object(payload),
                    createdAt: now
                )
            )
            return payload
        }

        guard let revokedObject else {
            return .string("error: delegation not found")
        }

        await emitAgreementEvent(action: "agreement.access.revoke", payload: revokedObject, requester: requester)
        return .object([
            "revoked": .object(revokedObject),
            "state": await agreementTemplateStateValue(requester: requester)
        ])
    }

    private func handleAgreementSign(payload: ValueType, requester: Identity) async -> ValueType {
        let requesterKey = identityKey(for: requester)
        let currentAgreement = stateQueue.sync { agreementCurrentRecord }
        guard let currentAgreement else {
            return .string("error: no active agreement")
        }

        let agreementID: String
        let signature: String
        let entityContext: String?
        if case let .object(object) = payload {
            agreementID = extractString(object["agreementId"]) ?? currentAgreement.agreementID
            signature = extractString(object["signature"]) ?? "signed"
            entityContext = extractString(object["entityContext"])
        } else {
            agreementID = currentAgreement.agreementID
            signature = "signed"
            entityContext = nil
        }

        guard agreementID == currentAgreement.agreementID else {
            return .string("error: only current agreement can be signed in this endpoint")
        }
        let isParty = currentAgreement.parties.contains(requesterKey)
        let hasReadCapability = await hasAgreementCapability("agreementTemplate.read", requester: requester)
        guard isParty || hasReadCapability else {
            return .string("denied")
        }

        let now = Date().timeIntervalSince1970
        var updatedAgreement: AgreementRecord?
        stateQueue.sync {
            guard var agreement = agreementCurrentRecord, agreement.agreementID == agreementID else { return }
            if let existingIndex = agreement.signatures.firstIndex(where: { $0.identityKey == requesterKey }) {
                agreement.signatures[existingIndex] = AgreementSignature(identityKey: requesterKey, signature: signature, signedAt: now, entityContext: entityContext)
            } else {
                agreement.signatures.append(AgreementSignature(identityKey: requesterKey, signature: signature, signedAt: now, entityContext: entityContext))
            }
            let signedKeys = Set(agreement.signatures.map(\.identityKey))
            if agreement.requiresAllPartiesSignature {
                let partiesSigned = Set(agreement.parties).isSubset(of: signedKeys)
                agreement.status = partiesSigned ? "active" : "pending_signatures"
            } else {
                agreement.status = "active"
            }
            agreementCurrentRecord = agreement
            if let historyIndex = agreementHistory.firstIndex(where: { $0.agreementID == agreementID }) {
                agreementHistory[historyIndex] = agreement
            }
            appendAgreementAuditEntry(
                AgreementAuditEntry(
                    id: UUID().uuidString,
                    action: "agreements.sign",
                    actorIdentityKey: requesterKey,
                    payload: .object([
                        "agreementId": .string(agreementID),
                        "entityContext": entityContext.map { .string($0) } ?? .null
                    ]),
                    createdAt: now
                )
            )
            updatedAgreement = agreement
        }

        guard let updatedAgreement else {
            return .string("error: failed to update agreement")
        }
        await emitAgreementEvent(
            action: "agreement.signed",
            payload: [
                "agreementId": .string(updatedAgreement.agreementID),
                "identityKey": .string(requesterKey),
                "status": .string(updatedAgreement.status)
            ],
            requester: requester
        )
        return .object(updatedAgreement.asObject())
    }

    private func handleNonCompliantReport(payload: ValueType, requester: Identity) async -> ValueType {
        let requesterKey = identityKey(for: requester)
        guard case let .object(object) = payload else {
            return .string("error: invalid payload for agreements.nonCompliant.report")
        }
        let reason = extractString(object["reason"]) ?? "Marked as non-compliant"
        let agreementID = extractString(object["agreementId"]) ?? stateQueue.sync { agreementCurrentRecord?.agreementID }
        let evidenceRef = extractString(object["evidenceRef"])
        let entityContext = extractString(object["entityContext"])

        let hasReadAccess = await hasAgreementCapability("agreementTemplate.read", requester: requester)
        let isParty = stateQueue.sync { agreementCurrentRecord?.parties.contains(requesterKey) == true }
        guard hasReadAccess || isParty else {
            return .string("denied")
        }

        let now = Date().timeIntervalSince1970
        let policy = stateQueue.sync { agreementNonCompliancePolicyByIdentity[requesterKey] ?? .manualOnly }
        let report = AgreementNonComplianceReport(
            id: UUID().uuidString,
            agreementID: agreementID,
            reporterIdentityKey: requesterKey,
            reason: reason,
            evidenceRef: evidenceRef,
            entityContext: entityContext,
            policy: policy,
            status: policy == .autoRestrictUntilResolved ? "restricted" : "open",
            createdAt: now
        )

        stateQueue.sync {
            appendAgreementNonComplianceReport(report)
            appendAgreementAuditEntry(
                AgreementAuditEntry(
                    id: UUID().uuidString,
                    action: "agreements.nonCompliant.report",
                    actorIdentityKey: requesterKey,
                    payload: .object(report.asObject()),
                    createdAt: now
                )
            )
        }

        await emitAgreementEvent(
            action: "agreement.nonCompliant.reported",
            payload: report.asObject(),
            requester: requester
        )
        return .object(report.asObject())
    }

    private func handleNonCompliantPolicy(payload: ValueType, requester: Identity) async -> ValueType {
        guard case let .object(object) = payload else {
            return .string("error: invalid payload for agreements.nonCompliant.policy")
        }

        let requesterKey = identityKey(for: requester)
        let targetIdentityKey = identityKeyFromObject(object) ?? requesterKey
        guard let policyRaw = extractString(object["policy"]),
              let policy = AgreementNonCompliancePolicy(rawValue: policyRaw) else {
            return .string("error: invalid policy")
        }

        if targetIdentityKey != requesterKey {
            guard await hasAgreementCapability("agreementTemplate.access.manage", requester: requester) else {
                return .string("denied")
            }
        }

        let now = Date().timeIntervalSince1970
        stateQueue.sync {
            agreementNonCompliancePolicyByIdentity[targetIdentityKey] = policy
            appendAgreementAuditEntry(
                AgreementAuditEntry(
                    id: UUID().uuidString,
                    action: "agreements.nonCompliant.policy",
                    actorIdentityKey: requesterKey,
                    payload: .object([
                        "identityKey": .string(targetIdentityKey),
                        "policy": .string(policy.rawValue)
                    ]),
                    createdAt: now
                )
            )
        }

        await emitAgreementEvent(
            action: "agreement.nonCompliant.policy",
            payload: [
                "identityKey": .string(targetIdentityKey),
                "policy": .string(policy.rawValue)
            ],
            requester: requester
        )
        return .object([
            "identityKey": .string(targetIdentityKey),
            "policy": .string(policy.rawValue),
            "state": await agreementTemplateStateValue(requester: requester)
        ])
    }

    private func extractID(_ payload: ValueType) -> String? {
        switch payload {
        case .string(let id):
            return id
        case .object(let object):
            if case let .string(id)? = object["id"] {
                return id
            }
            if case let .string(id)? = object["uuid"] {
                return id
            }
            return nil
        default:
            return nil
        }
    }

    private func decodeCatalogPayload(_ payload: ValueType, requireID: Bool) -> CatalogPayload? {
        guard case let .object(object) = payload else { return nil }
        let id = extractID(payload)
        if requireID && (id == nil || id?.isEmpty == true) {
            return nil
        }

        guard let decodedConfiguration = decodeConfiguration(from: object["configuration"]),
              let configuration = sanitizeCatalogConfiguration(decodedConfiguration)
        else {
            return nil
        }

        let decodedGoal = decodeConfiguration(from: object["goal"]) ?? decodedConfiguration
        let goal = sanitizeCatalogConfiguration(decodedGoal) ?? configuration

        let sourceCellEndpoint: String
        if case let .string(endpoint)? = object["sourceCellEndpoint"],
           !endpoint.isEmpty,
           !isBlockedCatalogEndpoint(endpoint) {
            sourceCellEndpoint = endpoint
        } else if let firstEndpoint = configuration.cellReferences?.first?.endpoint {
            sourceCellEndpoint = firstEndpoint
        } else {
            sourceCellEndpoint = "cell:///Unknown"
        }

        let sourceCellName: String
        if case let .string(name)? = object["sourceCellName"], !name.isEmpty {
            sourceCellName = name
        } else {
            sourceCellName = configuration.name
        }

        let purpose: String
        if case let .string(purposeName)? = object["purpose"], !purposeName.isEmpty {
            purpose = purposeName
        } else {
            purpose = configuration.name
        }

        let purposeDescription: String?
        if case let .string(description)? = object["purposeDescription"], !description.isEmpty {
            purposeDescription = description
        } else {
            purposeDescription = nil
        }

        let interests = extractInterestList(from: object["interests"]) ?? []
        let menuSlots = extractMenuSlots(from: object["menuSlots"]) ?? [.upperLeft]
        let displayName = extractString(object["displayName"])
        let summary = extractString(object["summary"])
        let categoryPath = extractStringList(from: object["categoryPath"])
        let tags = extractStringList(from: object["tags"])
        let purposeRefs = extractStringList(from: object["purposeRefs"])
        let interestRefs = extractStringList(from: object["interestRefs"])

        let compatibilityObject: Object = {
            if case let .object(object)? = object["compatibility"] {
                return object
            }
            return [:]
        }()
        let supportedInsertionModes = extractInsertionModes(
            from: object["supportedInsertionModes"] ?? compatibilityObject["supportedInsertionModes"]
        )
        let supportedTargetKinds = extractStringList(
            from: object["supportedTargetKinds"] ?? compatibilityObject["supportedTargetKinds"]
        )

        let ioSignature: Object = {
            if case let .object(object)? = object["ioSignature"] {
                return object
            }
            return [:]
        }()
        let ioGetKeys = extractStringList(from: ioSignature["getKeys"])
        let ioSetKeys = extractStringList(from: ioSignature["setKeys"])
        let ioTopics = extractStringList(from: ioSignature["topics"])
        let ioFilterTypes = extractStringList(from: ioSignature["filterTypes"])

        let authPolicyHints: Object = {
            if case let .object(object)? = object["authPolicyHints"] {
                return object
            }
            return [:]
        }()
        let authRequired = extractOptionalBool(object["authRequired"] ?? authPolicyHints["authRequired"])
        let policyHints = extractStringList(from: object["policyHints"] ?? authPolicyHints["policyHints"])
        let flowDriven = extractOptionalBool(object["flowDriven"])
        let editable = extractOptionalBool(object["editable"])
        let recommendedContexts = extractStringList(from: object["recommendedContexts"])

        return CatalogPayload(
            id: id,
            sourceCellEndpoint: sourceCellEndpoint,
            sourceCellName: sourceCellName,
            purpose: purpose,
            purposeDescription: purposeDescription,
            interests: interests,
            menuSlots: menuSlots,
            goal: goal,
            configuration: configuration,
            displayName: displayName,
            summary: summary,
            categoryPath: categoryPath,
            tags: tags,
            purposeRefs: purposeRefs,
            interestRefs: interestRefs,
            supportedInsertionModes: supportedInsertionModes,
            supportedTargetKinds: supportedTargetKinds,
            ioGetKeys: ioGetKeys,
            ioSetKeys: ioSetKeys,
            ioTopics: ioTopics,
            ioFilterTypes: ioFilterTypes,
            authRequired: authRequired,
            policyHints: policyHints,
            flowDriven: flowDriven,
            editable: editable,
            recommendedContexts: recommendedContexts
        )
    }

    private func decodeConfiguration(from value: ValueType?) -> CellConfiguration? {
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

    private func extractInterestList(from value: ValueType?) -> [String]? {
        guard let value else { return nil }
        switch value {
        case .string(let single):
            return [single]
        case .list(let list):
            return list.compactMap {
                if case let .string(s) = $0, !s.isEmpty {
                    return s
                }
                return nil
            }
        default:
            return nil
        }
    }

    private func extractStringList(from value: ValueType?) -> [String]? {
        guard let values = extractInterestList(from: value) else { return nil }
        let normalized = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return normalized.isEmpty ? nil : Array(Set(normalized)).sorted()
    }

    private func extractOptionalBool(_ value: ValueType?) -> Bool? {
        guard let value else { return nil }
        if case let .bool(flag) = value {
            return flag
        }
        return nil
    }

    private func extractInsertionModes(from value: ValueType?) -> [SupportedInsertionMode]? {
        guard let value else { return nil }
        switch value {
        case .string(let single):
            if let mode = SupportedInsertionMode(rawValue: single.lowercased()) {
                return [mode]
            }
            return nil
        case .list(let list):
            let modes = list.compactMap { current -> SupportedInsertionMode? in
                guard case let .string(raw) = current else { return nil }
                return SupportedInsertionMode(rawValue: raw.lowercased())
            }
            return modes.isEmpty ? nil : Array(Set(modes)).sorted(by: { $0.rawValue < $1.rawValue })
        default:
            return nil
        }
    }

    private func extractMenuSlots(from value: ValueType?) -> [MenuSlot]? {
        guard let value else { return nil }
        switch value {
        case .string(let slot):
            if let parsed = parseMenuSlot(slot) {
                return [parsed]
            }
            return nil
        case .list(let list):
            let parsed = list.compactMap { current -> MenuSlot? in
                if case let .string(slot) = current {
                    return parseMenuSlot(slot)
                }
                return nil
            }
            return parsed.isEmpty ? nil : parsed
        default:
            return nil
        }
    }

    private func parseMenuSlot(_ slot: String) -> MenuSlot? {
        let cleaned = slot.replacingOccurrences(of: "Menu", with: "")
        return MenuSlot(rawValue: cleaned)
    }

    private func upsert(from payload: CatalogPayload, keepExistingIDWhenMissing: Bool) -> CatalogEntry {
        let resolvedID: String = {
            if let id = payload.id, !id.isEmpty {
                return id
            }
            if keepExistingIDWhenMissing {
                if let existing = sortedEntries().first(where: { $0.configuration.uuid == payload.configuration.uuid }) {
                    return existing.id
                }
            }
            return UUID().uuidString
        }()

        var updatedEntry = CatalogEntry(
            id: resolvedID,
            sourceCellEndpoint: payload.sourceCellEndpoint,
            sourceCellName: payload.sourceCellName,
            purpose: payload.purpose,
            purposeDescription: payload.purposeDescription,
            interests: payload.interests,
            menuSlots: payload.menuSlots,
            goal: payload.goal,
            configuration: payload.configuration,
            displayName: payload.displayName,
            summary: payload.summary,
            categoryPath: payload.categoryPath,
            tags: payload.tags,
            purposeRefs: payload.purposeRefs,
            interestRefs: payload.interestRefs,
            supportedInsertionModes: payload.supportedInsertionModes,
            supportedTargetKinds: payload.supportedTargetKinds,
            ioGetKeys: payload.ioGetKeys,
            ioSetKeys: payload.ioSetKeys,
            ioTopics: payload.ioTopics,
            ioFilterTypes: payload.ioFilterTypes,
            authRequired: payload.authRequired,
            policyHints: payload.policyHints,
            flowDriven: payload.flowDriven,
            editable: payload.editable,
            recommendedContexts: payload.recommendedContexts,
            updatedAt: Date().timeIntervalSince1970
        )
        updatedEntry = enrichCatalogEntryMetadata(updatedEntry)

        stateQueue.sync {
            entriesByID[resolvedID] = updatedEntry
        }
        return updatedEntry
    }

    private func remove(id: String) -> Bool {
        stateQueue.sync {
            entriesByID.removeValue(forKey: id) != nil
        }
    }

    private func extractPurposeTerm(_ payload: ValueType) -> String? {
        switch payload {
        case .string(let term):
            return term
        case .object(let object):
            if case let .string(term)? = object["purpose"] {
                return term
            }
            if case let .string(term)? = object["term"] {
                return term
            }
            return nil
        default:
            return nil
        }
    }

    private func extractInterests(_ payload: ValueType) -> [String]? {
        switch payload {
        case .list:
            return extractInterestList(from: payload)
        case .string(let value):
            return [value]
        case .object(let object):
            return extractInterestList(from: object["interests"])
        default:
            return nil
        }
    }

    private func extractMenuSlot(_ payload: ValueType) -> MenuSlot? {
        guard case let .object(object) = payload else { return nil }
        if case let .string(slotName)? = object["menuSlot"] {
            return parseMenuSlot(slotName)
        }
        return nil
    }

    private func extractLimit(_ payload: ValueType) -> Int? {
        guard case let .object(object) = payload else { return nil }
        if case let .integer(limit)? = object["limit"] {
            return max(1, limit)
        }
        if case let .number(limit)? = object["limit"] {
            return max(1, limit)
        }
        return nil
    }

    private func migrateEntriesForMetadataIfNeeded() {
        stateQueue.sync {
            entriesByID = entriesByID.reduce(into: [:]) { sanitized, item in
                var entry = item.value
                guard let configuration = sanitizeCatalogConfiguration(entry.configuration) else { return }
                let goal = sanitizeCatalogConfiguration(entry.goal) ?? configuration
                entry.configuration = configuration
                entry.goal = goal
                if isBlockedCatalogEndpoint(entry.sourceCellEndpoint),
                   let firstEndpoint = configuration.cellReferences?.first?.endpoint {
                    entry.sourceCellEndpoint = firstEndpoint
                }
                sanitized[item.key] = enrichCatalogEntryMetadata(entry)
            }
        }
    }

    private func sanitizeCatalogConfiguration(_ configuration: CellConfiguration) -> CellConfiguration? {
        guard let references = configuration.cellReferences else { return nil }
        let sanitizedReferences = references.compactMap { sanitizeCatalogReference($0) }
        guard !sanitizedReferences.isEmpty else { return nil }

        var sanitized = configuration
        sanitized.cellReferences = sanitizedReferences
        return sanitized
    }

    private func sanitizeCatalogReference(_ reference: CellReference) -> CellReference? {
        if isBlockedCatalogEndpoint(reference.endpoint) {
            return nil
        }

        var sanitized = reference
        sanitized.subscriptions = reference.subscriptions.compactMap { sanitizeCatalogReference($0) }
        sanitized.setKeysAndValues = reference.setKeysAndValues.compactMap { item in
            guard let target = item.target else { return item }
            if isBlockedCatalogEndpoint(target) {
                return nil
            }
            return item
        }
        return sanitized
    }

    private func isBlockedCatalogEndpoint(_ endpoint: String) -> Bool {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let lowered = trimmed.lowercased()

        if Self.blockedCatalogReferenceNames.contains(lowered) {
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
        return Self.blockedCatalogReferenceNames.contains(pathName)
    }

    private func enrichCatalogEntryMetadata(_ entry: CatalogEntry) -> CatalogEntry {
        var enriched = entry

        if enriched.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            enriched.displayName = entry.configuration.name
        }

        if enriched.summary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            enriched.summary = entry.purposeDescription ?? entry.configuration.description ?? "Ingen sammendrag tilgjengelig."
        }

        if enriched.categoryPath?.isEmpty ?? true {
            enriched.categoryPath = ["purpose", slugify(entry.purpose)]
        }

        if enriched.purposeRefs?.isEmpty ?? true {
            enriched.purposeRefs = [portablePurposeRef(for: entry.purpose)]
        }

        if enriched.interestRefs?.isEmpty ?? true {
            let refs = entry.interests.map { portableInterestRef(for: $0) }
            enriched.interestRefs = refs.isEmpty ? nil : refs
        }

        if enriched.supportedInsertionModes?.isEmpty ?? true {
            enriched.supportedInsertionModes = [.unknown]
        }

        if enriched.supportedTargetKinds?.isEmpty ?? true {
            enriched.supportedTargetKinds = nil
        }

        let derivedSetKeys = Set(entry.configuration.cellReferences?.flatMap { reference in
            reference.setKeysAndValues.map(\.key)
        } ?? [])

        if enriched.ioSetKeys?.isEmpty ?? true {
            enriched.ioSetKeys = derivedSetKeys.isEmpty ? nil : Array(derivedSetKeys).sorted()
        }

        if enriched.ioGetKeys?.isEmpty ?? true {
            enriched.ioGetKeys = nil
        }

        if enriched.ioTopics?.isEmpty ?? true {
            let topicKeys = derivedSetKeys.filter { $0.lowercased().contains("topic") }
            enriched.ioTopics = topicKeys.isEmpty ? nil : Array(topicKeys).sorted()
        }

        if enriched.ioFilterTypes?.isEmpty ?? true {
            enriched.ioFilterTypes = nil
        }

        if enriched.authRequired == nil {
            let source = entry.sourceCellEndpoint.lowercased()
            let looksProtected = source.contains("auth") || source.contains("security") || source.contains("agreement")
            enriched.authRequired = looksProtected
        }

        if enriched.policyHints?.isEmpty ?? true {
            if enriched.authRequired == true {
                enriched.policyHints = ["auth-required"]
            } else {
                enriched.policyHints = nil
            }
        }

        if enriched.flowDriven == nil {
            enriched.flowDriven = !(enriched.ioTopics?.isEmpty ?? true)
        }

        if enriched.editable == nil {
            enriched.editable = entry.configuration.skeleton != nil
        }

        if enriched.recommendedContexts?.isEmpty ?? true {
            let contexts = entry.menuSlots.map { "menu.\($0.rawValue)" }
            enriched.recommendedContexts = contexts.isEmpty ? nil : contexts
        }

        if enriched.tags?.isEmpty ?? true {
            var all = Set<String>()
            all.insert(slugify(entry.purpose))
            entry.interests.forEach { all.insert(slugify($0)) }
            enriched.categoryPath?.forEach { all.insert(slugify($0)) }
            if let insertion = enriched.supportedInsertionModes {
                insertion.forEach { all.insert($0.rawValue) }
            }
            enriched.tags = all.isEmpty ? nil : Array(all).sorted()
        }

        return enriched
    }

    private func slugify(_ value: String) -> String {
        let lowered = value.lowercased()
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) { return Character(String(scalar)) }
            return "-"
        }
        let collapsed = String(scalars)
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return collapsed.isEmpty ? "unknown" : collapsed
    }

    private func portablePurposeRef(for purpose: String) -> String {
        "purpose://\(slugify(purpose))"
    }

    private func portableInterestRef(for interest: String) -> String {
        "interest://\(slugify(interest))"
    }

    private func normalizePurposeRef(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("purpose://") {
            return trimmed.lowercased()
        }
        return portablePurposeRef(for: trimmed)
    }

    private func normalizeInterestRef(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("interest://") {
            return trimmed.lowercased()
        }
        return portableInterestRef(for: trimmed)
    }

    private func parseQueryConstraints(from value: ValueType?) -> QueryConstraints {
        guard case let .object(object)? = value else {
            return QueryConstraints(
                maxResults: 50,
                maxSources: 24,
                latencyBudgetMs: 350,
                resourceBudget: .balanced,
                networkPolicy: .preferHealthyThenCached,
                allowDegradedSources: true
            )
        }

        let maxResults = min(200, max(1, extractInt(object["maxResults"], default: 50)))
        let maxSources = min(64, max(1, extractInt(object["maxSources"], default: 24)))
        let latencyBudgetMs = min(5000, max(100, extractInt(object["latencyBudgetMs"], default: 350)))
        let resourceBudget = QueryResourceBudget(rawValue: extractString(object["resourceBudget"]) ?? "") ?? .balanced
        let networkPolicy = QueryNetworkPolicy(rawValue: extractString(object["networkPolicy"]) ?? "") ?? .preferHealthyThenCached
        let allowDegradedSources = extractBool(object["allowDegradedSources"], default: true)

        return QueryConstraints(
            maxResults: maxResults,
            maxSources: maxSources,
            latencyBudgetMs: latencyBudgetMs,
            resourceBudget: resourceBudget,
            networkPolicy: networkPolicy,
            allowDegradedSources: allowDegradedSources
        )
    }

    private func parseQueryContext(from value: ValueType?) -> QueryContext {
        guard case let .object(object)? = value else {
            return QueryContext(editMode: true, selectedNodeKind: nil, insertionIntent: .unknown)
        }

        let editMode = extractBool(object["editMode"], default: true)
        let selectedNodeKind = extractString(object["selectedNodeKind"])
        let insertionIntent: SupportedInsertionMode = {
            let raw = (extractString(object["insertionIntent"]) ?? "").lowercased()
            return SupportedInsertionMode(rawValue: raw) ?? .unknown
        }()

        return QueryContext(
            editMode: editMode,
            selectedNodeKind: selectedNodeKind,
            insertionIntent: insertionIntent
        )
    }

    private func extractBoolSet(from value: ValueType?) -> Set<Bool> {
        guard let value else { return [] }
        switch value {
        case .bool(let value):
            return [value]
        case .list(let list):
            return Set(list.compactMap {
                if case let .bool(value) = $0 { return value }
                return nil
            })
        default:
            return []
        }
    }

    private func parseQueryFilters(from value: ValueType?) -> QueryFilters {
        guard case let .object(object)? = value else {
            return QueryFilters(
                categoryPath: [],
                sourceRefs: [],
                authRequired: [],
                supportedInsertionModes: [],
                flowDriven: [],
                editable: []
            )
        }

        let categoryPath = Set((extractStringList(from: object["categoryPath"]) ?? []).map { $0.lowercased() })
        let sourceRefs = Set((extractStringList(from: object["sourceRefs"]) ?? []).map { $0.lowercased() })
        let authRequired = extractBoolSet(from: object["authRequired"])
        let supportedInsertionModes = Set(extractInsertionModes(from: object["supportedInsertionModes"]) ?? [])
        let flowDriven = extractBoolSet(from: object["flowDriven"])
        let editable = extractBoolSet(from: object["editable"])

        return QueryFilters(
            categoryPath: categoryPath,
            sourceRefs: sourceRefs,
            authRequired: authRequired,
            supportedInsertionModes: supportedInsertionModes,
            flowDriven: flowDriven,
            editable: editable
        )
    }

    private func mergeFilters(_ lhs: QueryFilters, _ rhs: QueryFilters) -> QueryFilters {
        QueryFilters(
            categoryPath: lhs.categoryPath.union(rhs.categoryPath),
            sourceRefs: lhs.sourceRefs.union(rhs.sourceRefs),
            authRequired: lhs.authRequired.union(rhs.authRequired),
            supportedInsertionModes: lhs.supportedInsertionModes.union(rhs.supportedInsertionModes),
            flowDriven: lhs.flowDriven.union(rhs.flowDriven),
            editable: lhs.editable.union(rhs.editable)
        )
    }

    private func entryMatchesFilters(_ entry: CatalogEntry, filters: QueryFilters) -> Bool {
        if !filters.categoryPath.isEmpty {
            let entryPath = (entry.categoryPath ?? []).map { $0.lowercased() }
            let joined = entryPath.joined(separator: "/")
            let hasCategory = filters.categoryPath.contains(where: { filter in
                joined.contains(filter) || entryPath.contains(filter)
            })
            if !hasCategory { return false }
        }

        if !filters.sourceRefs.isEmpty, !filters.sourceRefs.contains(entry.sourceCellEndpoint.lowercased()) {
            return false
        }

        if !filters.authRequired.isEmpty {
            let authValue = entry.authRequired ?? false
            if !filters.authRequired.contains(authValue) {
                return false
            }
        }

        if !filters.supportedInsertionModes.isEmpty {
            let entryModes = Set(entry.supportedInsertionModes ?? [.unknown])
            if entryModes.intersection(filters.supportedInsertionModes).isEmpty {
                return false
            }
        }

        if !filters.flowDriven.isEmpty {
            let value = entry.flowDriven ?? false
            if !filters.flowDriven.contains(value) {
                return false
            }
        }

        if !filters.editable.isEmpty {
            let value = entry.editable ?? false
            if !filters.editable.contains(value) {
                return false
            }
        }

        return true
    }

    private func tokenize(_ text: String) -> [String] {
        text
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 1 }
    }

    private func sourceHealth(for endpoint: String, errors: [String: CatalogErrorEntry]) -> SourceHealth {
        guard let error = errors[endpoint] else { return .online }
        if error.count >= 5 { return .offline }
        return .degraded
    }

    private func sourceHealthScore(_ health: SourceHealth) -> Double {
        switch health {
        case .online: return 1.0
        case .degraded: return 0.55
        case .offline: return 0.15
        }
    }

    private func scoreSource(
        endpoint: String,
        entries: [CatalogEntry],
        purposeRefs: Set<String>,
        interestRefs: Set<String>,
        queryTokens: [String],
        errors: [String: CatalogErrorEntry]
    ) -> SourceCandidate {
        let purposeUniverse = Set(entries.flatMap { ($0.purposeRefs ?? []).map { $0.lowercased() } })
        let interestUniverse = Set(entries.flatMap { ($0.interestRefs ?? []).map { $0.lowercased() } })

        let purposeFit: Double = {
            guard !purposeRefs.isEmpty else { return 0.5 }
            return Double(purposeRefs.intersection(purposeUniverse).count) / Double(max(1, purposeRefs.count))
        }()

        let interestFit: Double = {
            guard !interestRefs.isEmpty else { return 0.5 }
            return Double(interestRefs.intersection(interestUniverse).count) / Double(max(1, interestRefs.count))
        }()

        let textFit: Double = {
            guard !queryTokens.isEmpty else { return 0.5 }
            let corpus = entries.map {
                [
                    $0.displayName ?? "",
                    $0.summary ?? "",
                    $0.purpose,
                    ($0.tags ?? []).joined(separator: " "),
                    ($0.interests).joined(separator: " ")
                ].joined(separator: " ").lowercased()
            }.joined(separator: " ")
            let matches = Set(queryTokens.filter { corpus.contains($0) })
            return Double(matches.count) / Double(max(1, Set(queryTokens).count))
        }()

        let health = sourceHealth(for: endpoint, errors: errors)
        let healthScore = sourceHealthScore(health)
        let sizePenalty = min(1.0, Double(entries.count) / 1200.0)
        let score = (0.32 * purposeFit) + (0.22 * interestFit) + (0.16 * textFit) + (0.20 * healthScore) + (0.10 * (1.0 - sizePenalty))
        let estimatedRttMs: Int = {
            switch health {
            case .online: return 20 + min(80, entries.count / 6)
            case .degraded: return 120 + min(250, entries.count / 3)
            case .offline: return 700
            }
        }()

        return SourceCandidate(
            endpoint: endpoint,
            health: health,
            purposeFit: purposeFit,
            interestFit: interestFit,
            sizePenalty: sizePenalty,
            score: score,
            reason: "source_rank",
            estimatedRttMs: estimatedRttMs
        )
    }

    private func isLocalSource(_ endpoint: String) -> Bool {
        endpoint.lowercased().hasPrefix("cell:///")
    }

    private func selectSources(
        entries: [CatalogEntry],
        purposeRefs: Set<String>,
        interestRefs: Set<String>,
        queryTokens: [String],
        constraints: QueryConstraints,
        applySourceLimit: Bool = true
    ) -> (selected: [SourceCandidate], skipped: [SourceCandidate]) {
        let grouped = Dictionary(grouping: entries, by: \.sourceCellEndpoint)
        let errors = stateQueue.sync { catalogErrorsByEndpoint }
        var selectedPool: [SourceCandidate] = []
        var skipped: [SourceCandidate] = []

        for (endpoint, sourceEntries) in grouped {
            var candidate = scoreSource(
                endpoint: endpoint,
                entries: sourceEntries,
                purposeRefs: purposeRefs,
                interestRefs: interestRefs,
                queryTokens: queryTokens,
                errors: errors
            )

            switch constraints.networkPolicy {
            case .healthyOnly where candidate.health != .online:
                candidate.reason = "healthyOnlyPolicy"
                skipped.append(candidate)
                continue
            case .cacheOnly where !isLocalSource(endpoint):
                candidate.reason = "cacheOnlyPolicy"
                skipped.append(candidate)
                continue
            default:
                break
            }

            if !constraints.allowDegradedSources, candidate.health != .online {
                candidate.reason = "degradedSourcesNotAllowed"
                skipped.append(candidate)
                continue
            }

            selectedPool.append(candidate)
        }

        selectedPool.sort { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.endpoint.localizedCaseInsensitiveCompare(rhs.endpoint) == .orderedAscending
            }
            return lhs.score > rhs.score
        }

        guard applySourceLimit else {
            return (selectedPool, skipped)
        }

        let selected = Array(selectedPool.prefix(constraints.maxSources))
        if selectedPool.count > constraints.maxSources {
            for candidate in selectedPool.dropFirst(constraints.maxSources) {
                var skippedCandidate = candidate
                skippedCandidate.reason = "maxSourcesLimit"
                skipped.append(skippedCandidate)
            }
        }

        return (selected, skipped)
    }

    private func queryWorkingSet(
        from object: Object,
        additionalFilters: QueryFilters? = nil
    ) -> (
        requestId: String,
        queryText: String,
        purposeRefs: Set<String>,
        interestRefs: Set<String>,
        constraints: QueryConstraints,
        context: QueryContext,
        entries: [CatalogEntry],
        selectedSources: [SourceCandidate],
        skippedSources: [SourceCandidate]
    ) {
        let requestId = extractString(object["requestId"]) ?? UUID().uuidString
        let queryText = extractString(object["q"]) ?? extractString(object["query"]) ?? ""
        var purposeRefs = Set((extractStringList(from: object["purposeRefs"]) ?? []).map { normalizePurposeRef($0) })
        var interestRefs = Set((extractStringList(from: object["interestRefs"]) ?? []).map { normalizeInterestRef($0) })

        if let fallbackPurposes = extractStringList(from: object["purposes"]) {
            fallbackPurposes.forEach { purposeRefs.insert(normalizePurposeRef($0)) }
        }
        if let fallbackInterests = extractStringList(from: object["interests"]) {
            fallbackInterests.forEach { interestRefs.insert(normalizeInterestRef($0)) }
        }

        var queryTokens = tokenize(queryText)
        if case let .list(tokenList)? = object["tokens"] {
            for token in tokenList {
                guard case let .object(tokenObject) = token else { continue }
                let kind = (extractString(tokenObject["kind"]) ?? "").lowercased()
                guard let value = extractString(tokenObject["value"]), !value.isEmpty else { continue }
                switch kind {
                case "purpose":
                    purposeRefs.insert(normalizePurposeRef(value))
                case "interest":
                    interestRefs.insert(normalizeInterestRef(value))
                default:
                    queryTokens.append(contentsOf: tokenize(value))
                }
            }
        }

        let filters = parseQueryFilters(from: object["filters"])
        let mergedFilters = mergeFilters(filters, additionalFilters ?? QueryFilters(
            categoryPath: [],
            sourceRefs: [],
            authRequired: [],
            supportedInsertionModes: [],
            flowDriven: [],
            editable: []
        ))
        let constraints = parseQueryConstraints(from: object["constraints"])
        let context = parseQueryContext(from: object["context"])
        let hasDiscoverySignal = !queryTokens.isEmpty || !purposeRefs.isEmpty || !interestRefs.isEmpty

        let allEntries = sortedEntries().map { enrichCatalogEntryMetadata($0) }
        let sourceSelection = selectSources(
            entries: allEntries,
            purposeRefs: purposeRefs,
            interestRefs: interestRefs,
            queryTokens: queryTokens,
            constraints: constraints,
            applySourceLimit: hasDiscoverySignal
        )
        let selectedSet = Set(sourceSelection.selected.map { $0.endpoint.lowercased() })
        let filteredEntries = allEntries.filter { entry in
            selectedSet.contains(entry.sourceCellEndpoint.lowercased()) &&
            entryMatchesFilters(entry, filters: mergedFilters)
        }

        return (
            requestId: requestId,
            queryText: queryText,
            purposeRefs: purposeRefs,
            interestRefs: interestRefs,
            constraints: constraints,
            context: context,
            entries: filteredEntries,
            selectedSources: sourceSelection.selected,
            skippedSources: sourceSelection.skipped
        )
    }

    private func textScore(for entry: CatalogEntry, queryText: String) -> Double {
        let tokens = tokenize(queryText)
        guard !tokens.isEmpty else { return 0.5 }
        let corpus = [
            entry.displayName ?? "",
            entry.summary ?? "",
            entry.purpose,
            entry.purposeDescription ?? "",
            (entry.tags ?? []).joined(separator: " "),
            entry.interests.joined(separator: " "),
            (entry.categoryPath ?? []).joined(separator: " "),
            entry.configuration.name,
            entry.configuration.description ?? ""
        ].joined(separator: " ").lowercased()
        let matches = Set(tokens.filter { corpus.contains($0) })
        return Double(matches.count) / Double(max(1, Set(tokens).count))
    }

    private func purposeScore(for entry: CatalogEntry, purposeRefs: Set<String>) -> Double {
        guard !purposeRefs.isEmpty else { return 0.5 }
        let entryRefs = Set((entry.purposeRefs ?? []).map { $0.lowercased() })
        let overlap = purposeRefs.intersection(entryRefs)
        return Double(overlap.count) / Double(max(1, purposeRefs.count))
    }

    private func interestScore(for entry: CatalogEntry, interestRefs: Set<String>) -> Double {
        guard !interestRefs.isEmpty else { return 0.5 }
        let entryRefs = Set((entry.interestRefs ?? []).map { $0.lowercased() })
        let overlap = interestRefs.intersection(entryRefs)
        return Double(overlap.count) / Double(max(1, interestRefs.count))
    }

    private func compatibilityScore(for entry: CatalogEntry, context: QueryContext) -> Double {
        var score = 0.5
        let modes = Set(entry.supportedInsertionModes ?? [.unknown])
        switch context.insertionIntent {
        case .unknown:
            score = 0.5
        case .root:
            score = modes.contains(.root) || modes.contains(.both) ? 1.0 : (modes.contains(.unknown) ? 0.35 : 0.0)
        case .component:
            score = modes.contains(.component) || modes.contains(.both) ? 1.0 : (modes.contains(.unknown) ? 0.35 : 0.0)
        case .both:
            score = modes.contains(.both) ? 1.0 : 0.7
        }

        if let selectedNodeKind = context.selectedNodeKind?.lowercased(),
           let kinds = entry.supportedTargetKinds?.map({ $0.lowercased() }),
           !kinds.isEmpty {
            if kinds.contains(selectedNodeKind) {
                score = min(1.0, score + 0.2)
            } else {
                score *= 0.5
            }
        }

        return min(1.0, max(0.0, score))
    }

    private func resourceScore(for entry: CatalogEntry, budget: QueryResourceBudget) -> Double {
        let references = entry.configuration.cellReferences?.count ?? 0
        let setOps = entry.configuration.cellReferences?.reduce(0, { $0 + $1.setKeysAndValues.count }) ?? 0
        let complexity = Double(references) + (entry.configuration.skeleton != nil ? 1.5 : 0.5) + (Double(setOps) * 0.2)

        switch budget {
        case .low:
            return max(0.0, 1.0 - min(1.0, complexity / 8.0))
        case .balanced:
            return max(0.0, 1.0 - min(1.0, abs(complexity - 3.0) / 7.0))
        case .high:
            return min(1.0, 0.35 + min(0.65, complexity / 9.0))
        }
    }

    private func recencyScore(for entry: CatalogEntry) -> Double {
        let ageSeconds = max(0.0, Date().timeIntervalSince1970 - entry.updatedAt)
        let ageDays = ageSeconds / 86400.0
        return exp(-ageDays / 30.0)
    }

    private func badges(for entry: CatalogEntry) -> [String] {
        var badges: [String] = []
        let insertion = Set(entry.supportedInsertionModes ?? [.unknown])
        if insertion.contains(.both) {
            badges.append("Both")
        } else if insertion.contains(.root) {
            badges.append("Root")
        } else if insertion.contains(.component) {
            badges.append("Component")
        } else {
            badges.append("Unknown")
        }
        if entry.authRequired == true {
            badges.append("Auth-required")
        }
        if entry.flowDriven == true {
            badges.append("Flow-driven")
        }
        if entry.editable == true {
            badges.append("Editable")
        }
        return badges
    }

    private func queryCatalog(payload: ValueType, requester: Identity) -> ValueType {
        guard case let .object(object) = payload else {
            return .object([
                "status": .string("error"),
                "message": .string("query forventer object payload")
            ])
        }

        let startedAt = Date()
        let sourceSelectionStarted = Date()
        let workingSet = queryWorkingSet(from: object)
        let sourceSelectionMs = Int(Date().timeIntervalSince(sourceSelectionStarted) * 1000.0)
        let selectedByEndpoint = Dictionary(uniqueKeysWithValues: workingSet.selectedSources.map { ($0.endpoint.lowercased(), $0) })
        let scoringStarted = Date()

        struct ScoredItem {
            var entry: CatalogEntry
            var score: QueryScoreBreakdown
            var route: String
        }

        let hasSignal = !workingSet.queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !workingSet.purposeRefs.isEmpty || !workingSet.interestRefs.isEmpty

        let scored: [ScoredItem] = workingSet.entries.compactMap { entry in
            let entryHealth = selectedByEndpoint[entry.sourceCellEndpoint.lowercased()]?.health ?? .online
            let breakdown = QueryScoreBreakdown(
                text: textScore(for: entry, queryText: workingSet.queryText),
                purpose: purposeScore(for: entry, purposeRefs: workingSet.purposeRefs),
                interest: interestScore(for: entry, interestRefs: workingSet.interestRefs),
                compatibility: compatibilityScore(for: entry, context: workingSet.context),
                connectivity: sourceHealthScore(entryHealth),
                resourceFit: resourceScore(for: entry, budget: workingSet.constraints.resourceBudget),
                recency: recencyScore(for: entry)
            )

            if hasSignal && breakdown.text <= 0.0 && breakdown.purpose <= 0.0 && breakdown.interest <= 0.0 {
                return nil
            }

            let route: String = {
                if breakdown.purpose > 0.0 && breakdown.purpose >= breakdown.interest { return "directPurpose" }
                if breakdown.interest > 0.0 { return "viaInterest" }
                return "text"
            }()

            return ScoredItem(entry: entry, score: breakdown, route: route)
        }
        .sorted { lhs, rhs in
            if lhs.score.finalScore == rhs.score.finalScore {
                if lhs.score.purpose == rhs.score.purpose {
                    let lhsName = lhs.entry.displayName ?? lhs.entry.configuration.name
                    let rhsName = rhs.entry.displayName ?? rhs.entry.configuration.name
                    if lhsName.caseInsensitiveCompare(rhsName) == .orderedSame {
                        return lhs.entry.id.localizedCaseInsensitiveCompare(rhs.entry.id) == .orderedAscending
                    }
                    return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
                }
                return lhs.score.purpose > rhs.score.purpose
            }
            return lhs.score.finalScore > rhs.score.finalScore
        }

        let limited = Array(scored.prefix(workingSet.constraints.maxResults))
        let scoringMs = Int(Date().timeIntervalSince(scoringStarted) * 1000.0)

        let resultObjects: [ValueType] = limited.map { item in
            let entry = item.entry
            let purposeRefs = entry.purposeRefs ?? [portablePurposeRef(for: entry.purpose)]
            let interestRefs = entry.interestRefs ?? entry.interests.map { portableInterestRef(for: $0) }
            let supportedModes = (entry.supportedInsertionModes ?? [.unknown]).map { ValueType.string($0.rawValue) }
            let targetKinds = (entry.supportedTargetKinds ?? []).map { ValueType.string($0) }
            let overlapPurposes = purposeRefs.filter { workingSet.purposeRefs.contains($0.lowercased()) }
            let overlapInterests = interestRefs.filter { workingSet.interestRefs.contains($0.lowercased()) }
            let purposeSupport = (overlapPurposes.isEmpty ? Array(purposeRefs.prefix(1)) : overlapPurposes)
                .map { ValueType.object(["portablePurposeRef": .string($0), "weight": .float(item.score.purpose)]) }
            let interestSupport = (overlapInterests.isEmpty ? Array(interestRefs.prefix(2)) : overlapInterests)
                .map { ValueType.object(["portableInterestRef": .string($0), "weight": .float(item.score.interest)]) }

            return .object([
                "configurationId": .string(entry.id),
                "displayName": .string(entry.displayName ?? entry.configuration.name),
                "summary": .string(entry.summary ?? ""),
                "sourceRef": .string(entry.sourceCellEndpoint),
                "score": .float(item.score.finalScore),
                "scoreBreakdown": .object([
                    "text": .float(item.score.text),
                    "purpose": .float(item.score.purpose),
                    "interest": .float(item.score.interest),
                    "compatibility": .float(item.score.compatibility),
                    "connectivity": .float(item.score.connectivity),
                    "resourceFit": .float(item.score.resourceFit),
                    "recency": .float(item.score.recency)
                ]),
                "route": .string(item.route),
                "supportingPurposes": .list(purposeSupport),
                "supportingInterests": .list(interestSupport),
                "compatibility": .object([
                    "supportedInsertionModes": .list(supportedModes),
                    "supportedTargetKinds": .list(targetKinds)
                ]),
                "badges": .list(badges(for: entry).map { .string($0) }),
                "configuration": .cellConfiguration(entry.configuration)
            ])
        }

        let selectedSourceObjects: [ValueType] = workingSet.selectedSources.map { source in
            .object([
                "sourceRef": .string(source.endpoint),
                "reason": .string(source.reason),
                "health": .string(source.health.rawValue),
                "rttMs": .integer(source.estimatedRttMs)
            ])
        }

        let skippedSourceObjects: [ValueType] = workingSet.skippedSources.map { source in
            .object([
                "sourceRef": .string(source.endpoint),
                "reason": .string(source.reason),
                "health": .string(source.health.rawValue)
            ])
        }

        let totalMs = Int(Date().timeIntervalSince(startedAt) * 1000.0)
        let responseObject: Object = [
            "requestId": .string(workingSet.requestId),
            "status": .string("ok"),
            "resultCount": .integer(resultObjects.count),
            "results": .list(resultObjects),
            "sourceSelection": .object([
                "selected": .list(selectedSourceObjects),
                "skipped": .list(skippedSourceObjects)
            ]),
            "timing": .object([
                "sourceSelectionMs": .integer(sourceSelectionMs),
                "rankMs": .integer(scoringMs),
                "totalMs": .integer(totalMs)
            ]),
            "connectivity": .object([
                "onlineSources": .integer(workingSet.selectedSources.filter { $0.health == .online }.count),
                "degradedSources": .integer(workingSet.selectedSources.filter { $0.health == .degraded }.count),
                "offlineSources": .integer(workingSet.selectedSources.filter { $0.health == .offline }.count)
            ]),
            "warnings": .list(workingSet.skippedSources.map { .string("\($0.endpoint): \($0.reason)") })
        ]

        stateQueue.sync {
            lastQueryState = .object(responseObject)
        }
        return .object(responseObject)
    }

    private func queryFacetCounts(payload: ValueType, requester: Identity) -> ValueType {
        guard case let .object(object) = payload else {
            return .object([
                "status": .string("error"),
                "message": .string("facetCounts forventer object payload")
            ])
        }

        let requestId = extractString(object["requestId"]) ?? UUID().uuidString
        let maxBuckets = min(50, max(1, extractInt(object["maxBucketsPerFacet"], default: 20)))
        let countMode = (extractString(object["countMode"]) ?? "exactOrApprox").lowercased()
        let baseQueryObject: Object = {
            if case let .object(base)? = object["baseQuery"] {
                return base
            }
            return [:]
        }()
        let activeFilters = parseQueryFilters(from: object["activeFilters"])
        var mergedBase = baseQueryObject
        mergedBase["requestId"] = .string(requestId)
        if mergedBase["constraints"] == nil, let constraints = object["constraints"] {
            mergedBase["constraints"] = constraints
        }

        let startedAt = Date()
        let workingSet = queryWorkingSet(from: mergedBase, additionalFilters: activeFilters)
        let exact = workingSet.skippedSources.isEmpty && countMode != "approxonly"
        let facetKeys = extractStringList(from: object["facetKeys"]) ?? [
            "categoryPath",
            "sourceRef",
            "supportedInsertionModes",
            "authRequired"
        ]

        var facetsObject: Object = [:]
        for facetKey in facetKeys {
            var counts: [String: Int] = [:]
            for entry in workingSet.entries {
                switch facetKey {
                case "categoryPath":
                    let value = (entry.categoryPath ?? ["unknown"]).joined(separator: "/")
                    counts[value, default: 0] += 1
                case "sourceRef":
                    counts[entry.sourceCellEndpoint, default: 0] += 1
                case "supportedInsertionModes", "compatibility":
                    for mode in (entry.supportedInsertionModes ?? [.unknown]) {
                        counts[mode.rawValue, default: 0] += 1
                    }
                case "authRequired":
                    let value = entry.authRequired == nil ? "unknown" : ((entry.authRequired ?? false) ? "true" : "false")
                    counts[value, default: 0] += 1
                case "flowDriven":
                    let value = (entry.flowDriven ?? false) ? "true" : "false"
                    counts[value, default: 0] += 1
                case "editable":
                    let value = (entry.editable ?? false) ? "true" : "false"
                    counts[value, default: 0] += 1
                case "purposeRef":
                    for purposeRef in entry.purposeRefs ?? [portablePurposeRef(for: entry.purpose)] {
                        counts[purposeRef, default: 0] += 1
                    }
                case "interestRef":
                    for interestRef in entry.interestRefs ?? entry.interests.map({ portableInterestRef(for: $0) }) {
                        counts[interestRef, default: 0] += 1
                    }
                default:
                    continue
                }
            }

            let buckets: [ValueType] = counts
                .map { ($0.key, $0.value) }
                .sorted { lhs, rhs in
                    if lhs.1 == rhs.1 {
                        return lhs.0.localizedCaseInsensitiveCompare(rhs.0) == .orderedAscending
                    }
                    return lhs.1 > rhs.1
                }
                .prefix(maxBuckets)
                .map { value, count in
                    var bucket: Object = [
                        "value": .string(value),
                        "count": .integer(count),
                        "exact": .bool(exact)
                    ]
                    if !exact {
                        bucket["note"] = .string("partial due to source limits/policy")
                    }
                    return .object(bucket)
                }

            facetsObject[facetKey] = .list(Array(buckets))
        }

        let responseObject: Object = [
            "requestId": .string(requestId),
            "status": .string("ok"),
            "facets": .object(facetsObject),
            "coverage": .object([
                "sourcesConsidered": .integer(workingSet.selectedSources.count + workingSet.skippedSources.count),
                "sourcesResponded": .integer(workingSet.selectedSources.count),
                "fromCache": .integer(workingSet.selectedSources.filter { isLocalSource($0.endpoint) }.count)
            ]),
            "timing": .object([
                "totalMs": .integer(Int(Date().timeIntervalSince(startedAt) * 1000.0))
            ]),
            "warnings": .list(workingSet.skippedSources.map { .string("\($0.endpoint): \($0.reason)") })
        ]

        return .object(responseObject)
    }

    private enum MatchingPublishField {
        case personName
        case groupName
        case groupType
        case note
    }

    private func extractTextInput(_ payload: ValueType, preferredKey: String? = nil) -> String? {
        switch payload {
        case .string(let value):
            return value
        case .object(let object):
            if let preferredKey,
               case let .string(value)? = object[preferredKey] {
                return value
            }
            if case let .string(value)? = object["value"] {
                return value
            }
            if case let .string(value)? = object["text"] {
                return value
            }
            return nil
        default:
            return nil
        }
    }

    private func matchingPublishPersonNameValue() -> ValueType {
        stateQueue.sync {
            .string(matchingPublishPersonName)
        }
    }

    private func matchingPublishGroupNameValue() -> ValueType {
        stateQueue.sync {
            .string(matchingPublishGroupName)
        }
    }

    private func matchingPublishGroupTypeValue() -> ValueType {
        stateQueue.sync {
            .string(matchingPublishGroupType)
        }
    }

    private func matchingPublishNoteValue() -> ValueType {
        stateQueue.sync {
            .string(matchingPublishNote)
        }
    }

    private func updateMatchingPublishField(_ payload: ValueType, field: MatchingPublishField) -> ValueType {
        let preferredKey: String = {
            switch field {
            case .personName: return "personName"
            case .groupName: return "groupName"
            case .groupType: return "groupType"
            case .note: return "note"
            }
        }()
        guard let rawValue = extractTextInput(payload, preferredKey: preferredKey) else {
            return .string("error: invalid publish field payload")
        }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        stateQueue.sync {
            switch field {
            case .personName:
                matchingPublishPersonName = value
            case .groupName:
                matchingPublishGroupName = value
            case .groupType:
                matchingPublishGroupType = value.isEmpty ? "selskap" : value
            case .note:
                matchingPublishNote = value
            }
        }
        switch field {
        case .personName:
            return matchingPublishPersonNameValue()
        case .groupName:
            return matchingPublishGroupNameValue()
        case .groupType:
            return matchingPublishGroupTypeValue()
        case .note:
            return matchingPublishNoteValue()
        }
    }

    private func matchingPromptTextValue() -> ValueType {
        stateQueue.sync {
            .string(matchingPromptText)
        }
    }

    private func matchingSuggestionsValue() -> ValueType {
        stateQueue.sync {
            .list(matchingSuggestions.map { .object($0.asObject()) })
        }
    }

    private func matchingBookmarksValue() -> ValueType {
        stateQueue.sync {
            .list(matchingBookmarks.map { .object($0.asObject()) })
        }
    }

    private func matchingPurposeStatsValue() -> ValueType {
        stateQueue.sync {
            let sorted = matchingPurposeStatsByPurpose.values.sorted { lhs, rhs in
                if lhs.effectiveness == rhs.effectiveness {
                    return lhs.lastUsedAt > rhs.lastUsedAt
                }
                return lhs.effectiveness > rhs.effectiveness
            }
            return .list(sorted.map { .object($0.asObject()) })
        }
    }

    private func matchingEntityPurposePublicationsValue() -> ValueType {
        stateQueue.sync {
            .list(matchingPublishedEntityPurposes.map { .object($0.asObject()) })
        }
    }

    private func matchingSelectedSuggestionValue() -> ValueType {
        stateQueue.sync {
            guard matchingSelectedIndex >= 0, matchingSelectedIndex < matchingSuggestions.count else {
                return .list([])
            }
            return .list([.object(matchingSuggestions[matchingSelectedIndex].asObject())])
        }
    }

    private func matchingSelectedIndexValue() -> ValueType {
        stateQueue.sync {
            .integer(matchingSelectedIndex)
        }
    }

    private func matchingStateValue() -> ValueType {
        stateQueue.sync {
            var object: Object = [
                "promptText": .string(matchingPromptText),
                "suggestionCount": .integer(matchingSuggestions.count),
                "bookmarkCount": .integer(matchingBookmarks.count),
                "purposeStatsCount": .integer(matchingPurposeStatsByPurpose.count),
                "entityPurposePublicationCount": .integer(matchingPublishedEntityPurposes.count),
                "selectedIndex": .integer(matchingSelectedIndex),
                "publishPersonName": .string(matchingPublishPersonName),
                "publishGroupName": .string(matchingPublishGroupName),
                "publishGroupType": .string(matchingPublishGroupType),
                "publishNote": .string(matchingPublishNote)
            ]
            if matchingSelectedIndex >= 0, matchingSelectedIndex < matchingSuggestions.count {
                object["selectedName"] = .string(matchingSuggestions[matchingSelectedIndex].configuration.name)
                object["selectedId"] = .string(matchingSuggestions[matchingSelectedIndex].id)
                object["selectedMeaning"] = .string(matchingSuggestions[matchingSelectedIndex].matchMeaning)
            }
            return .object(object)
        }
    }

    private func updateMatchingPromptText(_ payload: ValueType) -> ValueType {
        let prompt = extractMatchingPrompt(from: payload)
        guard let prompt else { return .string("error: invalid prompt payload") }
        stateQueue.sync {
            matchingPromptText = prompt
        }
        return .string(prompt)
    }

    private func extractMatchingPrompt(from payload: ValueType) -> String? {
        let rawPrompt: String?
        switch payload {
        case .string(let prompt):
            rawPrompt = prompt
        case .object(let object):
            if case let .string(prompt)? = object["prompt"] {
                rawPrompt = prompt
            } else if case let .string(promptText)? = object["promptText"] {
                rawPrompt = promptText
            } else if case let .string(value)? = object["value"] {
                rawPrompt = value
            } else if case let .string(text)? = object["text"] {
                rawPrompt = text
            } else {
                rawPrompt = nil
            }
        default:
            rawPrompt = nil
        }
        guard let rawPrompt else { return nil }
        let trimmed = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func emitMatchingSuggestionsFlow(
        prompt: String,
        queryPurpose: String?,
        queryInterests: [String],
        suggestions: [MatchingSuggestion],
        requester: Identity
    ) {
        var summaryPayload: Object = [
            "prompt": .string(prompt),
            "queryInterests": .list(queryInterests.map { .string($0) }),
            "count": .integer(suggestions.count)
        ]
        summaryPayload["queryPurpose"] = queryPurpose.map { .string($0) } ?? .null
        var summaryFlow = FlowElement(
            title: "catalog.matching.suggestions.summary",
            content: .object(summaryPayload),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        summaryFlow.topic = "catalog.matching.suggestions.meta"
        summaryFlow.origin = uuid
        pushFlowElement(summaryFlow, requester: requester)

        if suggestions.isEmpty {
            var selectedFlow = FlowElement(
                title: "catalog.matching.selectedSuggestion.empty",
                content: .object(["count": .integer(0)]),
                properties: FlowElement.Properties(type: .event, contentType: .object)
            )
            selectedFlow.topic = "catalog.matching.selectedSuggestion"
            selectedFlow.origin = uuid
            pushFlowElement(selectedFlow, requester: requester)
            return
        }

        for (index, suggestion) in suggestions.enumerated() {
            var suggestionPayload = suggestion.asObject()
            suggestionPayload["rank"] = .integer(index)
            suggestionPayload["queryInterests"] = .list(queryInterests.map { .string($0) })
            suggestionPayload["queryPurpose"] = queryPurpose.map { .string($0) } ?? .null

            var suggestionFlow = FlowElement(
                title: "catalog.matching.suggestion",
                content: .object(suggestionPayload),
                properties: FlowElement.Properties(type: .event, contentType: .object)
            )
            suggestionFlow.topic = "catalog.matching.suggestions"
            suggestionFlow.origin = uuid
            pushFlowElement(suggestionFlow, requester: requester)
        }

        var selectedFlow = FlowElement(
            title: "catalog.matching.selectedSuggestion",
            content: .object(suggestions[0].asObject()),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        selectedFlow.topic = "catalog.matching.selectedSuggestion"
        selectedFlow.origin = uuid
        pushFlowElement(selectedFlow, requester: requester)
    }

    private func runMatchingPrompt(_ payload: ValueType, requester: Identity) async -> ValueType {
        let explicitPrompt = extractMatchingPrompt(from: payload)
        let browseAll = matchingBrowseAllRequested(from: payload)

        let prompt = stateQueue.sync {
            if browseAll {
                let resolved = explicitPrompt ?? "Browse all cell configurations"
                matchingPromptText = resolved
                return resolved
            }

            let resolved = explicitPrompt ?? ""
            if !resolved.isEmpty {
                matchingPromptText = resolved
                return resolved
            }
            return matchingPromptText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let query: (purpose: String?, interests: [String]) = {
            if browseAll || prompt.isEmpty {
                return (nil, [])
            }
            return deriveMatchingQuery(from: prompt)
        }()
        let matchedEntries = matchConfigurationsDetailed(
            purpose: query.purpose,
            interests: query.interests,
            menuSlot: nil,
            limit: query.purpose == nil && query.interests.isEmpty ? 40 : 16
        )

        let now = Date().timeIntervalSince1970
        let suggestions: [MatchingSuggestion] = matchedEntries.map { entry in
            MatchingSuggestion(
                id: UUID().uuidString,
                sourceEntryID: entry.entry.id,
                prompt: prompt,
                purpose: entry.entry.purpose,
                interests: entry.entry.interests,
                overlappingInterests: entry.overlapInterests,
                menuSlots: entry.entry.menuSlots,
                configuration: entry.entry.configuration,
                matchScore: entry.score,
                matchMeaning: entry.reasons.joined(separator: " | "),
                hasSkeleton: entry.entry.configuration.skeleton != nil,
                matchedAt: now
            )
        }

        stateQueue.sync {
            matchingSuggestions = Self.trimmedMatchingSuggestions(suggestions)
            matchingSelectedIndex = suggestions.isEmpty ? -1 : 0
        }

        emitMatchingSuggestionsFlow(
            prompt: prompt,
            queryPurpose: query.purpose,
            queryInterests: query.interests,
            suggestions: suggestions,
            requester: requester
        )

        return .integer(suggestions.count)
    }

    private func matchingBrowseAllRequested(from payload: ValueType) -> Bool {
        switch payload {
        case .object(let object):
            if case let .bool(value)? = object["browseAll"] {
                return value
            }
            if case let .bool(value)? = object["exploreAll"] {
                return value
            }
            if case let .string(mode)? = object["mode"] {
                let lowered = mode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if lowered == "browseall" || lowered == "browse_all" || lowered == "exploreall" || lowered == "explore_all" {
                    return true
                }
            }
            if let prompt = extractMatchingPrompt(from: payload) {
                return isBrowseAllPrompt(prompt)
            }
            return false
        case .string(let prompt):
            return isBrowseAllPrompt(prompt)
        default:
            return false
        }
    }

    private func isBrowseAllPrompt(_ prompt: String) -> Bool {
        let lowered = prompt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lowered.isEmpty else { return false }
        let browseTokens = ["all", "alle", "browse", "utforsk", "explore", "vis"]
        let catalogTokens = ["cell", "cells", "celle", "celler", "configuration", "configurations", "konfigurasjon", "konfigurasjoner", "tools", "verktoy"]
        let hasBrowseToken = browseTokens.contains { lowered.contains($0) }
        let hasCatalogToken = catalogTokens.contains { lowered.contains($0) }
        return hasBrowseToken && hasCatalogToken
    }

    private func selectMatchingSuggestion(_ payload: ValueType) -> ValueType {
        if let index = matchingIndex(from: payload) {
            return selectMatchingSuggestion(at: index)
        }

        let selectedID: String?
        switch payload {
        case .string(let id):
            selectedID = id
        case .object(let object):
            if case let .string(id)? = object["id"] {
                selectedID = id
            } else if case let .string(id)? = object["selectedId"] {
                selectedID = id
            } else {
                selectedID = nil
            }
        default:
            selectedID = nil
        }

        guard let selectedID else { return .string("error: invalid select payload") }
        let index = stateQueue.sync {
            matchingSuggestions.firstIndex(where: { $0.id == selectedID })
        }
        guard let index else { return .string("error: suggestion not found") }
        return selectMatchingSuggestion(at: index)
    }

    private func selectMatchingSuggestionByIndexPayload(_ payload: ValueType) -> ValueType {
        guard let index = matchingIndex(from: payload) else {
            return .string("error: invalid index")
        }
        return selectMatchingSuggestion(at: index)
    }

    private func selectMatchingSuggestion(at index: Int) -> ValueType {
        let normalized = stateQueue.sync {
            guard !matchingSuggestions.isEmpty else { return -1 }
            let clamped = max(0, min(index, matchingSuggestions.count - 1))
            matchingSelectedIndex = clamped
            return clamped
        }
        guard normalized >= 0 else { return .string("error: no suggestions") }
        return .object([
            "status": .string("ok"),
            "selectedIndex": .integer(normalized),
            "selected": matchingSelectedSuggestionValue(),
            "state": matchingStateValue()
        ])
    }

    private func matchingIndex(from payload: ValueType) -> Int? {
        switch payload {
        case .integer(let index):
            return index
        case .number(let index):
            return index
        case .string(let value):
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        case .object(let object):
            if case let .integer(index)? = object["index"] {
                return index
            }
            if case let .number(index)? = object["index"] {
                return index
            }
            if case let .string(value)? = object["index"] {
                return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return nil
        default:
            return nil
        }
    }

    private func selectedMatchingSuggestion() -> MatchingSuggestion? {
        stateQueue.sync {
            guard matchingSelectedIndex >= 0, matchingSelectedIndex < matchingSuggestions.count else { return nil }
            return matchingSuggestions[matchingSelectedIndex]
        }
    }

    private func loadSelectedMatchingSuggestionToPorthole(requester: Identity) async -> ValueType {
        guard let selected = selectedMatchingSuggestion() else {
            return .string("error: no selected suggestion")
        }
        guard let resolver = CellBase.defaultCellResolver else {
            return .string("error: no resolver")
        }
        do {
            guard let porthole = try await resolver.cellAtEndpoint(endpoint: "cell:///Porthole", requester: requester) as? Meddle else {
                return .string("error: porthole unavailable")
            }
            _ = try await porthole.set(
                keypath: "setConfiguration",
                value: .cellConfiguration(selected.configuration),
                requester: requester
            )
            let usageResult = await markSelectedSuggestionUsage(achievedGoal: false, requester: requester)
            return .object([
                "status": .string("loaded"),
                "selected": .list([.object(selected.asObject())]),
                "usage": usageResult,
                "state": matchingStateValue()
            ])
        } catch {
            return .string("error: failed loading selected suggestion")
        }
    }

    private func previewSelectedMatchingSuggestion() -> ValueType {
        guard let selected = selectedMatchingSuggestion() else {
            return .string("error: no selected suggestion")
        }
        ConfigurationCatalogPreviewBridge.post(configuration: selected.configuration)
        return .object([
            "status": .string("previewed"),
            "selected": .list([.object(selected.asObject())]),
            "state": matchingStateValue()
        ])
    }

    private func saveSelectedMatchingSuggestionToMenu(payload: ValueType, requester: Identity) async -> ValueType {
        guard let selected = selectedMatchingSuggestion() else {
            return .string("error: no selected suggestion")
        }

        let menuSlot = extractMenuSlot(payload) ?? .upperMid
        var purpose = selected.purpose
        if case let .object(object) = payload,
           case let .string(value)? = object["purpose"],
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            purpose = value
        }

        let payloadObject = CatalogPayload(
            id: nil,
            sourceCellEndpoint: selected.configuration.cellReferences?.first?.endpoint ?? "cell:///Unknown",
            sourceCellName: selected.configuration.name,
            purpose: purpose,
            purposeDescription: selected.configuration.description,
            interests: selected.interests,
            menuSlots: [menuSlot],
            goal: selected.configuration,
            configuration: selected.configuration
        )
        let entry = upsert(from: payloadObject, keepExistingIDWhenMissing: true)
        await emitCatalogEvent(operation: "matching.saveSelectedToMenu", entry: entry, requester: requester)

        return .object([
            "status": .string("saved"),
            "menuSlot": .string(menuSlot.rawValue),
            "entry": .object(entry.asObject()),
            "state": stateValue()
        ])
    }

    private func bookmarkSelectedMatchingSuggestion() -> ValueType {
        guard let selected = selectedMatchingSuggestion() else {
            return .string("error: no selected suggestion")
        }
        stateQueue.sync {
            if matchingBookmarks.contains(where: { $0.configuration.uuid == selected.configuration.uuid }) == false {
                matchingBookmarks.insert(selected, at: 0)
                matchingBookmarks = Self.trimmedMatchingBookmarks(matchingBookmarks)
            }
        }
        return .object([
            "status": .string("bookmarked"),
            "bookmarks": matchingBookmarksValue(),
            "state": matchingStateValue()
        ])
    }

    private func markSelectedSuggestionUsage(achievedGoal: Bool, requester: Identity) async -> ValueType {
        guard let selected = selectedMatchingSuggestion() else {
            return .string("error: no selected suggestion")
        }

        let timestamp = Date().timeIntervalSince1970
        let updated = stateQueue.sync {
            var stat = matchingPurposeStatsByPurpose[selected.purpose] ?? PurposeUsageStat(
                purpose: selected.purpose,
                useCount: 0,
                achievedCount: 0,
                effectiveness: 0.0,
                currentWeight: 0.4,
                lastUsedAt: timestamp
            )
            stat.useCount += 1
            if achievedGoal {
                stat.achievedCount += 1
            }
            stat.effectiveness = stat.useCount > 0 ? Double(stat.achievedCount) / Double(stat.useCount) : 0.0
            let usageSignal = achievedGoal ? 0.55 : 0.04
            let effectivenessSignal = achievedGoal ? (0.2 * stat.effectiveness) : 0.0
            stat.currentWeight = min(5.0, max(0.1, stat.currentWeight + usageSignal + effectivenessSignal))
            stat.lastUsedAt = timestamp
            matchingPurposeStatsByPurpose[selected.purpose] = stat
            return stat
        }

        await nudgePerspectivePurposeWeight(
            purpose: selected.purpose,
            suggestedWeight: updated.currentWeight,
            achievedGoal: achievedGoal,
            requester: requester
        )

        var payload: Object = [
            "purpose": .string(selected.purpose),
            "suggestionId": .string(selected.id),
            "achievedGoal": .bool(achievedGoal),
            "useCount": .integer(updated.useCount),
            "achievedCount": .integer(updated.achievedCount),
            "effectiveness": .float(updated.effectiveness),
            "currentWeight": .float(updated.currentWeight)
        ]
        payload["state"] = matchingStateValue()
        var flow = FlowElement(
            title: achievedGoal ? "purpose.goalAchieved" : "purpose.activated",
            content: .object(payload),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flow.topic = "purpose.outcome"
        flow.origin = uuid
        pushFlowElement(flow, requester: requester)

        return .object([
            "status": .string(achievedGoal ? "goal_achieved" : "used"),
            "purposeStat": .object(updated.asObject()),
            "state": matchingStateValue()
        ])
    }

    private func nudgePerspectivePurposeWeight(
        purpose: String,
        suggestedWeight: Double,
        achievedGoal: Bool,
        requester: Identity
    ) async {
        guard let resolver = CellBase.defaultCellResolver else { return }
        guard let perspective = try? await resolver.cellAtEndpoint(endpoint: "cell:///Perspective", requester: requester) as? Meddle else { return }

        let purposeObject: Object = [
            "name": .string(purpose),
            "description": .string(achievedGoal ? "Goal achieved via AppleIntelligence matcher." : "Activated via AppleIntelligence matcher."),
            "types": .list([]),
            "subTypes": .list([]),
            "parts": .list([]),
            "partOf": .list([]),
            "purposes": .list([]),
            "interests": .list([]),
            "entities": .list([]),
            "states": .list([])
        ]
        let payload: Object = [
            "purpose": .object(purposeObject),
            "purposeWeight": .float(suggestedWeight)
        ]
        _ = try? await perspective.set(keypath: "addPurpose", value: .object(payload), requester: requester)
    }

    private func publishEntityPurpose(payload: ValueType, requester: Identity) async -> ValueType {
        let object: Object = {
            if case let .object(value) = payload {
                return value
            }
            return [:]
        }()
        let publishDefaults = stateQueue.sync {
            (
                personName: matchingPublishPersonName.trimmingCharacters(in: .whitespacesAndNewlines),
                groupName: matchingPublishGroupName.trimmingCharacters(in: .whitespacesAndNewlines),
                groupType: matchingPublishGroupType.trimmingCharacters(in: .whitespacesAndNewlines),
                note: matchingPublishNote.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        let entityTypeRaw: String = {
            if case let .string(value)? = object["entityType"], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            return "person"
        }()
        let entityType: String = (entityTypeRaw == "group" || entityTypeRaw == "person") ? entityTypeRaw : "person"

        let payloadEntityName: String? = {
            if case let .string(value)? = object["entityName"] {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            return nil
        }()

        let fallbackEntityName = entityType == "group"
            ? (publishDefaults.groupName.isEmpty ? "Ukjent gruppe" : publishDefaults.groupName)
            : (publishDefaults.personName.isEmpty ? "Ukjent person" : publishDefaults.personName)
        let entityName = payloadEntityName ?? fallbackEntityName

        let entitySubtype: String? = {
            if case let .string(value)? = object["entitySubtype"] {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
            if case let .string(value)? = object["groupType"] {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
            if entityType == "group" {
                return publishDefaults.groupType.isEmpty ? "selskap" : publishDefaults.groupType
            }
            return nil
        }()

        let selected = selectedMatchingSuggestion()
        let purpose: String = {
            if case let .string(value)? = object["purpose"], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return selected?.purpose ?? "Unknown Purpose"
        }()
        let note: String? = {
            if case let .string(value)? = object["note"] {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
            return publishDefaults.note.isEmpty ? nil : publishDefaults.note
        }()

        let publication = PublishedEntityPurpose(
            id: UUID().uuidString,
            entityName: entityName,
            entityType: entityType,
            entitySubtype: entitySubtype,
            purpose: purpose,
            sourceSuggestionID: selected?.id,
            note: note,
            publishedAt: Date().timeIntervalSince1970
        )

        stateQueue.sync {
            matchingPublishedEntityPurposes.insert(publication, at: 0)
            if matchingPublishedEntityPurposes.count > 100 {
                matchingPublishedEntityPurposes = Array(matchingPublishedEntityPurposes.prefix(100))
            }
        }

        var flow = FlowElement(
            title: "purpose.entity.published",
            content: .object(publication.asObject()),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flow.topic = "purpose.entity.publications"
        flow.origin = uuid
        pushFlowElement(flow, requester: requester)

        return .object([
            "status": .string("published"),
            "publication": .object(publication.asObject()),
            "publications": matchingEntityPurposePublicationsValue(),
            "state": matchingStateValue()
        ])
    }

    private func clearMatchingSuggestions() -> ValueType {
        stateQueue.sync {
            matchingSuggestions = []
            matchingSelectedIndex = -1
        }
        return .object([
            "status": .string("cleared"),
            "state": matchingStateValue()
        ])
    }

    private func deriveMatchingQuery(from prompt: String) -> (purpose: String?, interests: [String]) {
        let lower = prompt.lowercased()
        var interests = Set<String>()
        var purpose: String?

        if lower.contains("chat") || lower.contains("venn") || lower.contains("melding") || lower.contains("snakk") {
            purpose = "Kommunikasjon og samarbeid"
            interests.formUnion(["chat", "communication", "collaboration"])
        }
        if lower.contains("ai") || lower.contains("personvern") || lower.contains("privacy") || lower.contains("konfer") || lower.contains("conference") {
            if purpose == nil { purpose = "Tidslinje og planlegging" }
            interests.formUnion(["ai", "privacy", "conference", "events"])
        }
        if lower.contains("asiat") || lower.contains("spicy") || lower.contains("restaurant") || lower.contains("mat") || lower.contains("frisk") {
            if purpose == nil { purpose = "Stedsbevissthet" }
            interests.formUnion(["location", "restaurant", "maps", "presence"])
        }
        if lower.contains("lignende") || lower.contains("interesser") || lower.contains("personer") || lower.contains("nettverk") {
            if purpose == nil { purpose = "Entitetsoversikt" }
            interests.formUnion(["entities", "network", "people"])
        }

        if interests.isEmpty {
            let tokens = lower.split { !$0.isLetter && !$0.isNumber }.map(String.init)
            for token in tokens where token.count > 2 {
                interests.insert(token)
                if interests.count >= 6 { break }
            }
        }

        return (purpose, Array(interests).sorted())
    }

    private func matchConfigurationsDetailed(
        purpose: String?,
        interests: [String]?,
        menuSlot: MenuSlot?,
        limit: Int?
    ) -> [DetailedCatalogMatch] {
        let normalizedPurpose = purpose?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedInterestSet: Set<String> = Set((interests ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty })
        let purposeStats: [String: PurposeUsageStat] = stateQueue.sync {
            matchingPurposeStatsByPurpose.values.reduce(into: [:]) { partialResult, stat in
                partialResult[stat.purpose.lowercased()] = stat
            }
        }
        let isBroadQuery = (normalizedPurpose == nil || normalizedPurpose?.isEmpty == true) && normalizedInterestSet.isEmpty

        let scored: [DetailedCatalogMatch] = sortedEntries()
            .filter { entry in
                if let menuSlot {
                    return entry.menuSlots.contains(menuSlot)
                }
                return true
            }
            .compactMap { entry in
                var score = 0.0
                var reasons: [String] = []
                let entryPurposeLower = entry.purpose.lowercased()
                let entryNameLower = entry.configuration.name.lowercased()
                let entryDescriptionLower = (entry.purposeDescription ?? entry.configuration.description ?? "").lowercased()

                if let normalizedPurpose, !normalizedPurpose.isEmpty {
                    if entryPurposeLower == normalizedPurpose {
                        score += 2.8
                        reasons.append("Direkte formaal-treff.")
                    } else if entryPurposeLower.contains(normalizedPurpose) {
                        score += 2.1
                        reasons.append("Formaal matcher delvis.")
                    } else if normalizedPurpose.contains(entryPurposeLower), entryPurposeLower.count >= 4 {
                        score += 1.4
                        reasons.append("Konfigurasjonens formaal dekker forespurt tema.")
                    }

                    if entryNameLower.contains(normalizedPurpose) {
                        score += 0.8
                        reasons.append("Navn matcher formaal.")
                    }
                    if entryDescriptionLower.contains(normalizedPurpose) {
                        score += 0.6
                        reasons.append("Beskrivelse matcher formaal.")
                    }
                }

                var overlapInterests: [String] = []
                if !normalizedInterestSet.isEmpty {
                    let entryInterestsLower = Set(entry.interests.map { $0.lowercased() })
                    let overlap = normalizedInterestSet.intersection(entryInterestsLower)
                    overlapInterests = overlap.sorted()
                    if !overlapInterests.isEmpty {
                        let ratio = Double(overlapInterests.count) / Double(normalizedInterestSet.count)
                        score += 2.4 * ratio
                        reasons.append("Interessematch: \(overlapInterests.joined(separator: ", ")).")
                    } else {
                        reasons.append("Ingen direkte interesse-overlapp.")
                    }
                }

                if entry.configuration.skeleton != nil {
                    score += 0.55
                    reasons.append("Har skeleton og kan lastes direkte i Porthole.")
                } else {
                    score += 0.1
                    reasons.append("Ingen skeleton i konfigurasjonen.")
                }

                if let stat = purposeStats[entry.purpose.lowercased()] {
                    let learnedBoost = min(1.5, (stat.effectiveness * 1.0) + (stat.currentWeight * 0.2))
                    if learnedBoost > 0 {
                        score += learnedBoost
                        let effectivenessPercent = Int((stat.effectiveness * 100.0).rounded())
                        reasons.append("Historikk: \(effectivenessPercent)% maaloppnaaelse for dette formaalet.")
                    }
                }

                if isBroadQuery {
                    score += 0.2
                    reasons.append("Bredt soek - rangerer etter generell egnethet.")
                    if !entry.menuSlots.isEmpty {
                        score += 1.2
                        reasons.append("Kurert som convenience-verktøy i menyene.")
                    }
                    if entry.authRequired == true {
                        score -= 0.25
                        reasons.append("Krever autorisasjon før bruk.")
                    }
                    let loweredTags = Set((entry.tags ?? []).map { $0.lowercased() })
                    if loweredTags.contains("test") || loweredTags.contains("qa") {
                        score -= 0.55
                        reasons.append("Test/QA-verktøy prioriteres lavere i bred utforskning.")
                    }
                    if loweredTags.contains("admin") || loweredTags.contains("operations") {
                        score -= 0.35
                        reasons.append("Admin/operasjonsverktøy prioriteres lavere i bred utforskning.")
                    }
                }

                if !isBroadQuery && score <= 0.0 {
                    return nil
                }

                return DetailedCatalogMatch(
                    entry: entry,
                    score: score,
                    overlapInterests: overlapInterests,
                    reasons: reasons
                )
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.entry.configuration.name.localizedCaseInsensitiveCompare(rhs.entry.configuration.name) == .orderedAscending
                }
                return lhs.score > rhs.score
            }

        if let limit {
            return Array(scored.prefix(limit))
        }
        return scored
    }

    private func matchConfigurations(
        purpose: String?,
        interests: [String]?,
        menuSlot: MenuSlot?,
        limit: Int?
    ) -> [CatalogEntry] {
        matchConfigurationsDetailed(
            purpose: purpose,
            interests: interests,
            menuSlot: menuSlot,
            limit: limit
        ).map(\.entry)
    }

    private func bootstrapDefaultsIfNeeded(requester: Identity) async {
        let hasEntries = stateQueue.sync { !entriesByID.isEmpty }
        if hasEntries { return }
        _ = await syncScaffoldPurposeGoals(requester: requester, includeResolverLookups: false)
    }

    private func syncScaffoldPurposeGoals(requester: Identity, includeResolverLookups: Bool = true) async -> Int {
        guard beginSyncIfPossible() else { return 0 }
        defer { endSync() }

        var importedCount = 0
        let templates = await Self.scaffoldPurposeTemplates()

        for template in templates {
            let existingMatch = sortedEntries().first {
                $0.sourceCellEndpoint == template.sourceCellEndpoint && $0.purpose == template.purpose
            }

            var payload = CatalogPayload(
                id: nil,
                sourceCellEndpoint: template.sourceCellEndpoint,
                sourceCellName: template.sourceCellName,
                purpose: template.purpose,
                purposeDescription: template.purposeDescription,
                interests: template.interests,
                menuSlots: template.menuSlots,
                goal: template.goal,
                configuration: template.configuration,
                displayName: template.displayName,
                summary: template.summary,
                categoryPath: template.categoryPath,
                tags: template.tags,
                purposeRefs: template.purposeRefs,
                interestRefs: template.interestRefs,
                supportedInsertionModes: template.supportedInsertionModes,
                supportedTargetKinds: template.supportedTargetKinds,
                ioGetKeys: template.ioGetKeys,
                ioSetKeys: template.ioSetKeys,
                ioTopics: template.ioTopics,
                ioFilterTypes: template.ioFilterTypes,
                authRequired: template.authRequired,
                policyHints: template.policyHints,
                flowDriven: template.flowDriven,
                editable: template.editable,
                recommendedContexts: template.recommendedContexts
            )

            let shouldRefreshExisting = template.forceRefreshExisting && existingMatch != nil
            if shouldRefreshExisting, let existingID = existingMatch?.id {
                payload.id = existingID
            }

            if existingMatch == nil || shouldRefreshExisting {
                _ = upsert(from: payload, keepExistingIDWhenMissing: true)
                importedCount += 1
            }
        }

        guard includeResolverLookups else { return importedCount }

        if let resolver = CellBase.defaultCellResolver as? CellResolver {
            let uniqueEndpoints = Array(Set(
                templates
                    .filter { !$0.skipResolverLookup }
                    .map(\.sourceCellEndpoint)
            )).sorted()
            for endpoint in uniqueEndpoints {
                if shouldSkipResolverLookup(for: endpoint) {
                    continue
                }
                guard let meddle = try? await RemoteEndpointAccessSupport.resolveMeddle(
                        endpoint: endpoint,
                        resolver: resolver,
                        requester: requester,
                        accessLabel: "configurationCatalog.syncPurposeGoals"
                      ),
                      let purposeGoalPayload = try? await meddle.get(keypath: "purposeGoal", requester: requester),
                      let parsedPayload = decodeCatalogPayload(purposeGoalPayload, requireID: false)
                else {
                    await reportMissingEndpoint(endpoint: endpoint, operation: "syncScaffoldPurposeGoals", message: "Cell unavailable or missing purposeGoal.", requester: requester)
                    continue
                }

                _ = upsert(from: parsedPayload, keepExistingIDWhenMissing: true)
                importedCount += 1
                clearCatalogError(for: endpoint)
            }
        }

        return importedCount
    }

    private func beginSyncIfPossible() -> Bool {
        stateQueue.sync {
            if syncInProgress { return false }
            syncInProgress = true
            return true
        }
    }

    private func endSync() {
        stateQueue.sync {
            syncInProgress = false
        }
    }

    private func shouldSkipResolverLookup(for endpoint: String) -> Bool {
        guard let url = URL(string: endpoint) else { return false }
        let pathName = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        return pathName == "configurationcatalog" || pathName == "appleintelligence"
    }

    private func clearCatalogError(for endpoint: String) {
        _ = stateQueue.sync {
            catalogErrorsByEndpoint.removeValue(forKey: endpoint)
        }
    }

    private func upsertCatalogError(endpoint: String, operation: String, message: String) -> (CatalogErrorEntry, Bool) {
        stateQueue.sync {
            let now = Date().timeIntervalSince1970
            if var existing = catalogErrorsByEndpoint[endpoint] {
                existing.count += 1
                existing.lastSeenAt = now
                existing.message = message
                existing.operation = operation
                catalogErrorsByEndpoint[endpoint] = existing
                return (existing, false)
            }

            let created = CatalogErrorEntry(
                id: UUID().uuidString,
                endpoint: endpoint,
                operation: operation,
                message: message,
                firstSeenAt: now,
                lastSeenAt: now,
                count: 1
            )
            catalogErrorsByEndpoint[endpoint] = created
            return (created, true)
        }
    }

    private func reportMissingEndpoint(endpoint: String, operation: String, message: String, requester: Identity) async {
        let (entry, isNew) = upsertCatalogError(endpoint: endpoint, operation: operation, message: message)
        guard isNew else { return }

        CellBase.defaultCellResolver?.logAction(
            context: ConnectContext(source: nil, target: self, identity: requester),
            action: "missing_cell_endpoint",
            param: endpoint
        )

        var payload: Object = [
            "endpoint": .string(entry.endpoint),
            "operation": .string(entry.operation),
            "message": .string(entry.message),
            "count": .integer(entry.count),
            "lastSeenAt": .float(entry.lastSeenAt)
        ]
        payload["state"] = stateValue()

        var flowElement = FlowElement(
            title: "configuration.catalog.error",
            content: .object(payload),
            properties: FlowElement.Properties(type: .alert, contentType: .object)
        )
        flowElement.topic = "configurationCatalog.error"
        flowElement.origin = uuid
        pushFlowElement(flowElement, requester: requester)
    }

    private static func scaffoldPurposeTemplates() async -> [ScaffoldPurposeTemplate] {
        let chatEndpoint = "cell://staging.haven.digipomps.org/Chat"
        let chatConfig = scaffoldChatWorkbenchConfiguration(
            endpoint: chatEndpoint,
            displayName: "Scaffold Chat",
            summary: "Del meldinger i sanntid fra staging, se deltagere og absorber samme chat i andre klienter."
        )
        let catalogWorkbench = catalogWorkbenchConfiguration()
        let agreementWorkbench = agreementTemplateWorkbenchConfiguration()
        let purposeLanding = appleIntelligenceLandingConfiguration()
        let entityScannerWorkbench = entityScannerWorkbenchConfiguration()
        let entityScannerHelper = entityScannerTestHelperConfiguration()
        let entityScannerChecklist = entityScannerPairingChecklistConfiguration()

        let entityScannerGoal = referenceCardConfiguration(
            name: "Entity Scanner Launch Card",
            endpoint: "cell:///EntityScanner",
            label: "scanner",
            title: "Entity Scanner",
            subtitle: "Oppdag andre enheter, be om kontakt, signer motet og eksporter bevis som JSON.",
            chip: "LOCAL",
            borderColor: "#0891B2",
            startKey: "start"
        )
        let entityScannerHelperGoal = referenceCardConfiguration(
            name: "Entity Scanner Test Helper Card",
            endpoint: "cell:///EntityScanner",
            label: "scanner",
            title: "Scanner Test Helper",
            subtitle: "Test discovery, capabilities, perspective snapshot og lagrede encounter proofs.",
            chip: "TEST",
            borderColor: "#0F766E",
            startKey: "start"
        )
        let entityScannerChecklistGoal = referenceCardConfiguration(
            name: "Entity Scanner Checklist Card",
            endpoint: "cell:///EntityScanner",
            label: "scanner",
            title: "Pairing Checklist",
            subtitle: "Stegvis QA for to enheter med og uten UWB.",
            chip: "QA",
            borderColor: "#1D4ED8",
            startKey: "start"
        )

        var templates: [ScaffoldPurposeTemplate] = [
            ScaffoldPurposeTemplate(
                sourceCellEndpoint: chatEndpoint,
                sourceCellName: "ChatCell",
                purpose: "Kommunikasjon og samarbeid",
                purposeDescription: "Faa delt meldinger i sanntid mellom deltakere.",
                interests: ["chat", "communication", "collaboration"],
                menuSlots: [.upperLeft],
                goal: chatConfig,
                configuration: chatConfig,
                displayName: "Scaffold Chat",
                summary: "Direkte inngang til sanntidschat og koordinering.",
                categoryPath: ["communication", "chat"],
                tags: ["chat", "communication", "collaboration"],
                purposeRefs: ["purpose://communication-and-collaboration"],
                interestRefs: ["interest://chat", "interest://communication", "interest://collaboration"],
                supportedInsertionModes: [.root],
                supportedTargetKinds: ["menu", "porthole", "tool"],
                ioGetKeys: ["status", "state", "messages", "participants", "members", "compose.body", "compose.contentType", "compose.availableFormats", "compose.state", "compose.previewRows"],
                ioSetKeys: ["compose.body", "compose.contentType", "sendMessage", "sendComposedMessage", "clearComposer"],
                ioTopics: ["chat.message", "chat.participant", "chat.status"],
                ioFilterTypes: ["event"],
                authRequired: false,
                flowDriven: true,
                editable: true,
                recommendedContexts: ["conference", "team", "coordination"],
                skipResolverLookup: true
            ),
            ScaffoldPurposeTemplate(
                sourceCellEndpoint: "cell:///ConfigurationCatalog",
                sourceCellName: "ConfigurationCatalogCell",
                purpose: "Katalogoperasjoner",
                purposeDescription: "Synk katalogen, inspiser entries og observer katalog-events.",
                interests: ["catalog", "configurations", "operations"],
                menuSlots: [],
                goal: catalogWorkbench,
                configuration: catalogWorkbench,
                displayName: "Catalog Workbench",
                summary: "Administrer katalogentries, query, facets og matching i samme verktøy.",
                categoryPath: ["operations", "catalog"],
                tags: ["catalog", "operations", "matching", "query", "admin"],
                purposeRefs: ["purpose://catalog-operations"],
                interestRefs: ["interest://catalog", "interest://configurations"],
                supportedInsertionModes: [.root],
                supportedTargetKinds: ["menu", "porthole", "tool"],
                ioGetKeys: ["state", "catalogEntries", "catalogContracts", "configurations", "errorLog"],
                ioSetKeys: ["syncScaffoldPurposeGoals", "query", "facetCounts", "match", "addConfiguration", "editConfiguration", "updateConfiguration", "removeConfiguration"],
                ioTopics: ["configurationCatalog", "configurationCatalog.error"],
                ioFilterTypes: ["event", "alert"],
                authRequired: false,
                flowDriven: true,
                editable: true,
                recommendedContexts: ["operations", "catalog-curation", "library"],
                skipResolverLookup: true
            ),
            ScaffoldPurposeTemplate(
                sourceCellEndpoint: "cell:///ConfigurationCatalog",
                sourceCellName: "ConfigurationCatalogCell",
                purpose: "Agreement template styring",
                purposeDescription: "Preview og apply av agreementTemplate med non-compliant policy og signering.",
                interests: ["agreement", "contract", "access", "signcontract"],
                menuSlots: [],
                goal: agreementWorkbench,
                configuration: agreementWorkbench,
                displayName: "Agreement Template Workbench",
                summary: "Preview, apply, access grants og signering rundt agreementTemplate.",
                categoryPath: ["security", "agreement"],
                tags: ["agreement", "contract", "policy", "signing", "admin"],
                purposeRefs: ["purpose://agreement-governance"],
                interestRefs: ["interest://agreement", "interest://contract", "interest://access"],
                supportedInsertionModes: [.root],
                supportedTargetKinds: ["menu", "porthole", "tool"],
                authRequired: true,
                flowDriven: true,
                editable: true,
                recommendedContexts: ["governance", "security", "policy-review"],
                skipResolverLookup: true
            ),
            ScaffoldPurposeTemplate(
                sourceCellEndpoint: "cell:///AppleIntelligence",
                sourceCellName: "AppleIntelligenceCell",
                purpose: "Semantisk utforskning av kontroll-laget",
                purposeDescription: "Generell inngang til alle tilgjengelige CellConfigurations og verktøy via semantisk matching.",
                interests: ["purpose", "assistant", "onboarding", "explore", "configurations", "tools"],
                menuSlots: [.upperMid],
                goal: purposeLanding,
                configuration: purposeLanding,
                displayName: "Apple Intelligence Purpose Matcher",
                summary: "Det semantiske laget over kontroll-konfigurasjonene. Utforsk, match og last verktøy direkte i Porthole.",
                categoryPath: ["assistant", "purpose"],
                tags: ["assistant", "purpose", "matching", "onboarding", "exploration"],
                purposeRefs: ["purpose://semantic-tool-exploration"],
                interestRefs: ["interest://assistant", "interest://purpose", "interest://matching", "interest://tools"],
                supportedInsertionModes: [.root],
                supportedTargetKinds: ["menu", "porthole", "tool"],
                authRequired: false,
                flowDriven: true,
                editable: true,
                recommendedContexts: ["onboarding", "discovery", "matching", "tool-exploration"],
                forceRefreshExisting: true,
                skipResolverLookup: true
            ),
            ScaffoldPurposeTemplate(
                sourceCellEndpoint: "cell:///SkeletonParityTextFixture",
                sourceCellName: "SkeletonParityTextFixture",
                purpose: "Skeleton parity text fixture",
                purposeDescription: "Deterministisk fixture for tekst-skeletoner brukt til Scaffold/HAVEN-paritet.",
                interests: ["skeleton", "parity", "fixture", "binding"],
                menuSlots: [],
                goal: referenceCardConfiguration(
                    name: "Skeleton Parity Text Fixture",
                    endpoint: "cell:///SkeletonParityTextFixture",
                    label: "skeletonParityText",
                    title: "Skeleton Parity Text Fixture",
                    subtitle: "Deterministic text fixture for Scaffold and HAVEN parity checks.",
                    chip: "FIXTURE",
                    borderColor: "#475569"
                ),
                configuration: referenceCardConfiguration(
                    name: "Skeleton Parity Text Fixture",
                    endpoint: "cell:///SkeletonParityTextFixture",
                    label: "skeletonParityText",
                    title: "Skeleton Parity Text Fixture",
                    subtitle: "Deterministic text fixture for Scaffold and HAVEN parity checks.",
                    chip: "FIXTURE",
                    borderColor: "#475569"
                ),
                displayName: "Skeleton Parity Text Fixture",
                summary: "Deterministic text fixture contract for Scaffold and HAVEN skeleton parity.",
                categoryPath: ["skeleton-parity", "fixtures"],
                tags: ["skeleton", "parity", "fixture", "text"],
                purposeRefs: ["purpose://skeleton-parity-text-fixture"],
                interestRefs: ["interest://skeleton", "interest://parity", "interest://binding"],
                supportedInsertionModes: [.root],
                supportedTargetKinds: ["tool", "porthole", "library"],
                ioGetKeys: ["purposeGoal", "state"],
                ioSetKeys: ["dispatchAction", "acknowledge"],
                ioTopics: ["skeleton.parity"],
                ioFilterTypes: ["event"],
                authRequired: false,
                policyHints: ["deterministic_fixture", "public_safe"],
                flowDriven: true,
                editable: false,
                recommendedContexts: ["binding", "scaffold", "parity"],
                forceRefreshExisting: true,
                skipResolverLookup: true
            ),
            entityScannerTemplate(
                purpose: "Entity discovery og sikker kontaktetablering",
                purposeDescription: "Oppdag andre i naerheten, send kontaktforespoersel, signer motet og eksporter encounter som bevis.",
                interests: ["scanner", "nearby", "identity", "conference", "peer"],
                menuSlots: [.lowerLeft],
                goal: entityScannerGoal,
                configuration: entityScannerWorkbench,
                displayName: "Entity Scanner",
                summary: "Full workbench for nearby peers, invite/contact flow, encounter proofs og JSON-eksport."
            ),
            entityScannerTemplate(
                purpose: "Entity scanner test og verifikasjon",
                purposeDescription: "Manualtest discovery, signeringsflyt, local perspective snapshot og lagrede encounter-bevis.",
                interests: ["scanner", "testing", "verification", "identity", "multipeer"],
                menuSlots: [],
                goal: entityScannerHelperGoal,
                configuration: entityScannerHelper,
                displayName: "Entity Scanner Test Helper",
                summary: "Test-helper med perspective snapshot, live events, encounter storage og reset/export."
            ),
            entityScannerTemplate(
                purpose: "Entity scanner pairing QA",
                purposeDescription: "Stegvis pairing-checkliste for to enheter, inkludert fallback uten UWB.",
                interests: ["scanner", "qa", "pairing", "uwb", "multipeer"],
                menuSlots: [],
                goal: entityScannerChecklistGoal,
                configuration: entityScannerChecklist,
                displayName: "Entity Scanner Pairing Checklist",
                summary: "Kort QA-verktøy for to-enhets test, verifisering og eksport av encounter JSON."
            )
        ]

        let conferenceShowcaseTemplates = staticCatalogTemplates(from: conferenceShowcaseCatalogDescriptors())
        let optInTemplates = staticCatalogTemplates(from: optInLocalCatalogDescriptors())

        templates.append(contentsOf: staticCatalogTemplates(from: personalCopilotV1CatalogDescriptors()))
        if !BindingPersonalCopilotV1Policy.appStoreCatalogGateEnabled {
            templates.append(contentsOf: staticCatalogTemplates(from: userFacingRemoteCatalogDescriptors()))
            templates.append(contentsOf: staticCatalogTemplates(from: runtimeControlCatalogDescriptors()))
            templates.append(contentsOf: staticCatalogTemplates(from: remoteSupportCatalogDescriptors()))
            templates.append(contentsOf: staticCatalogTemplates(from: stagingSurfaceTestingCatalogDescriptors(includeAgentOperatorSurfaces: false)))
        } else {
            templates = templates.filter(isPersonalCopilotV1Template)
        }
        templates.append(contentsOf: conferenceShowcaseTemplates)
        templates.append(contentsOf: optInTemplates)
        let knownEndpoints = Set(templates.map { $0.sourceCellEndpoint.lowercased() })
        if !BindingPersonalCopilotV1Policy.appStoreCatalogGateEnabled {
            templates.append(contentsOf: await resolverSnapshotCatalogTemplates(excluding: knownEndpoints))
        }

        var seenTemplateKeys = Set<String>()
        return templates.filter { template in
            let key = "\(template.sourceCellEndpoint.lowercased())|\(template.purpose.lowercased())"
            return seenTemplateKeys.insert(key).inserted
        }
    }

    nonisolated private static func isPersonalCopilotV1Template(_ template: ScaffoldPurposeTemplate) -> Bool {
        let scopedTokens = template.interests + (template.policyHints ?? [])
        let hasScope = scopedTokens.contains { token in
            let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized == BindingPersonalCopilotV1Policy.appStoreScope
                || normalized == "appstorescope:\(BindingPersonalCopilotV1Policy.appStoreScope)"
                || normalized == "appstorescope=\(BindingPersonalCopilotV1Policy.appStoreScope)"
        }
        guard hasScope else { return false }
        guard BindingPersonalCopilotV1Policy.isApprovedEndpoint(template.sourceCellEndpoint) else { return false }
        return BindingPersonalCopilotV1Policy.isAllowedInPersonalCopilotV1(template.configuration)
    }

    private static func resolverSnapshotCatalogTemplates(excluding endpoints: Set<String>) async -> [ScaffoldPurposeTemplate] {
        guard let resolver = CellBase.defaultCellResolver,
              let identity = await CellBase.defaultIdentityVault?.identity(for: "private", makeNewIfNotFound: true)
        else {
            return []
        }

        let snapshot = await resolver.resolverRegistrySnapshot(requester: identity)
        let resolvesByName = Dictionary(uniqueKeysWithValues: snapshot.resolves.map { ($0.name.lowercased(), $0) })
        var coveredEndpoints = endpoints
        var descriptors: [StaticCatalogDescriptor] = []

        for resolve in snapshot.resolves {
            let endpoint = "cell:///\(resolve.name)"
            let endpointKey = endpoint.lowercased()
            guard coveredEndpoints.insert(endpointKey).inserted else { continue }
            descriptors.append(dynamicCatalogDescriptor(for: resolve))
        }

        let liveInstances = snapshot.sharedNamedInstances + snapshot.identityNamedInstances.filter { $0.identityUUID == identity.uuid }
        for instance in liveInstances {
            guard !looksLikeOpaqueRuntimeInstance(instance.name) else { continue }
            let endpointKey = instance.endpoint.lowercased()
            guard coveredEndpoints.insert(endpointKey).inserted else { continue }
            let matchingResolve = resolvesByName[instance.name.lowercased()]
            descriptors.append(dynamicCatalogDescriptor(for: instance, resolve: matchingResolve))
        }

        return staticCatalogTemplates(from: descriptors)
    }

    nonisolated private static func dynamicCatalogDescriptor(for resolve: CellResolverResolveSnapshot) -> StaticCatalogDescriptor {
        let displayName = humanizedRuntimeName(resolve.name)
        let semanticTokens = inferredRuntimeTokens(from: [resolve.name, resolve.cellType])
        let categoryPath = inferredRuntimeCategoryPath(from: semanticTokens)
        let tags = inferredRuntimeTags(from: semanticTokens, chip: runtimeChip(for: resolve.cellScope))
        let interestTokens = inferredRuntimeInterests(from: semanticTokens)
        let flowDriven = inferredRuntimeFlowDriven(from: semanticTokens)
        let policyHints = [
            "scope=\(resolve.cellScope.rawValue)",
            "persistency=\(resolve.persistancy.rawValue)",
            "identityDomain=\(resolve.identityDomain)"
        ]

        return StaticCatalogDescriptor(
            sourceCellEndpoint: "cell:///\(resolve.name)",
            sourceCellName: resolve.cellType,
            displayName: displayName,
            purpose: "Utforsk og bruk \(displayName)",
            purposeDescription: "Generisk workbench for \(displayName) fra lokal resolver. Viser metadata, status/state og lar brukeren se hvilke kontrollflater som er eksponert.",
            interests: interestTokens,
            summary: "Automatisk generert workbench for \(displayName) (\(resolve.cellType)).",
            categoryPath: categoryPath,
            tags: tags,
            chip: runtimeChip(for: resolve.cellScope),
            borderColor: inferredRuntimeBorderColor(from: semanticTokens),
            authRequired: resolve.identityDomain.lowercased() != "private",
            policyHints: policyHints,
            flowDriven: flowDriven,
            editable: true,
            recommendedContexts: inferredRuntimeContexts(from: semanticTokens),
            ioGetKeys: ["status", "state"],
            ioSetKeys: inferredRuntimeSetKeys(from: semanticTokens),
            ioTopics: flowDriven ? inferredRuntimeTopics(from: semanticTokens) : nil,
            supportedTargetKinds: ["tool", "porthole", "library"],
            skipResolverLookup: true
        )
    }

    nonisolated private static func dynamicCatalogDescriptor(
        for instance: CellResolverNamedInstanceSnapshot,
        resolve: CellResolverResolveSnapshot?
    ) -> StaticCatalogDescriptor {
        let sourceName = instance.name.hasPrefix("cell:///") ? endpointLabel(for: instance.endpoint) : instance.name
        let displayName = "\(humanizedRuntimeName(sourceName)) Live"
        let semanticTokens = inferredRuntimeTokens(from: [instance.name, resolve?.cellType ?? "live instance"])
        let categoryPath = ["runtime", "instances"]
        let tags = inferredRuntimeTags(from: semanticTokens, chip: "LIVE") + ["live-instance"]
        let interestTokens = inferredRuntimeInterests(from: semanticTokens)

        return StaticCatalogDescriptor(
            sourceCellEndpoint: instance.endpoint,
            sourceCellName: resolve?.cellType ?? "RuntimeInstance",
            displayName: displayName,
            purpose: "Inspeksjon av kjørende celleinstans",
            purposeDescription: "Direkte workbench for en aktiv celleinstans. Nyttig for debugging, QA og runtime-inspeksjon.",
            interests: interestTokens,
            summary: "Automatisk generert live-instanskort for \(displayName).",
            categoryPath: categoryPath,
            tags: tags,
            chip: "LIVE",
            borderColor: inferredRuntimeBorderColor(from: semanticTokens),
            authRequired: false,
            policyHints: ["instance=\(instance.uuid.prefix(8))", "identityBound=\(instance.identityUUID != nil ? "true" : "false")"],
            flowDriven: inferredRuntimeFlowDriven(from: semanticTokens),
            editable: false,
            recommendedContexts: ["runtime", "debugging", "inspection"],
            ioGetKeys: ["status", "state"],
            supportedTargetKinds: ["tool", "porthole", "library"],
            skipResolverLookup: true
        )
    }

    nonisolated private static func humanizedRuntimeName(_ raw: String) -> String {
        let endpointTail: String = {
            if raw.contains("://") {
                return endpointLabel(for: raw)
            }
            return raw
        }()
        let separated = endpointTail.reduce(into: "") { partialResult, character in
            if !partialResult.isEmpty,
               character.isUppercase,
               let previous = partialResult.last,
               previous.isLowercase {
                partialResult.append(" ")
            }
            if character == "_" || character == "-" || character == "/" {
                partialResult.append(" ")
            } else {
                partialResult.append(character)
            }
        }
        let compact = separated
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .joined(separator: " ")
        return compact.isEmpty ? "Runtime Cell" : compact
    }

    nonisolated private static func inferredRuntimeTokens(from inputs: [String]) -> Set<String> {
        let text = inputs.joined(separator: " ")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        var tokens = Set(
            text
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count >= 3 }
        )

        if text.contains("scanner") || text.contains("radar") || text.contains("peer") || text.contains("nearby") {
            tokens.formUnion(["scanner", "nearby", "identity"])
        }
        if text.contains("vault") || text.contains("note") || text.contains("obsidian") {
            tokens.formUnion(["vault", "notes", "knowledge"])
        }
        if text.contains("trust") || text.contains("issuer") || text.contains("credential") || text.contains("attestation") {
            tokens.formUnion(["trust", "credentials", "verification"])
        }
        if text.contains("chat") || text.contains("message") || text.contains("notification") {
            tokens.formUnion(["communication", "messaging"])
        }
        if text.contains("taxonom") || text.contains("graph") || text.contains("resolver") || text.contains("commons") {
            tokens.formUnion(["knowledge", "lookup", "infrastructure"])
        }
        if text.contains("shop") || text.contains("wallet") || text.contains("pricing") || text.contains("payment") {
            tokens.formUnion(["commerce", "payments"])
        }
        if text.contains("identity") || text.contains("anchor") || text.contains("identities") {
            tokens.formUnion(["identity", "records"])
        }
        if text.contains("event") || text.contains("emitter") || text.contains("watch") || text.contains("signal") {
            tokens.formUnion(["events", "automation"])
        }
        return tokens
    }

    nonisolated private static func inferredRuntimeInterests(from tokens: Set<String>) -> [String] {
        let preferred = [
            "identity", "scanner", "nearby", "communication", "vault", "notes", "knowledge",
            "trust", "credentials", "verification", "events", "automation", "commerce", "payments",
            "infrastructure", "records", "lookup"
        ]
        let ordered = preferred.filter(tokens.contains)
        return ordered.isEmpty ? ["runtime", "control"] : Array(ordered.prefix(5))
    }

    nonisolated private static func inferredRuntimeCategoryPath(from tokens: Set<String>) -> [String] {
        if tokens.contains("scanner") || tokens.contains("nearby") { return ["identity", "nearby"] }
        if tokens.contains("vault") || tokens.contains("notes") { return ["knowledge", "vault"] }
        if tokens.contains("trust") || tokens.contains("credentials") { return ["trust", "credentials"] }
        if tokens.contains("commerce") || tokens.contains("payments") { return ["commerce", "runtime"] }
        if tokens.contains("events") || tokens.contains("automation") { return ["automation", "signals"] }
        if tokens.contains("knowledge") || tokens.contains("lookup") { return ["knowledge", "runtime"] }
        if tokens.contains("identity") || tokens.contains("records") { return ["identity", "runtime"] }
        return ["runtime", "cells"]
    }

    nonisolated private static func inferredRuntimeContexts(from tokens: Set<String>) -> [String] {
        if tokens.contains("scanner") || tokens.contains("nearby") { return ["conference", "pairing", "identity"] }
        if tokens.contains("vault") || tokens.contains("notes") { return ["notes", "knowledge-work", "research"] }
        if tokens.contains("trust") || tokens.contains("credentials") { return ["verification", "trust", "credentials"] }
        if tokens.contains("events") || tokens.contains("automation") { return ["automation", "testing", "signals"] }
        return ["runtime", "tool-exploration", "inspection"]
    }

    nonisolated private static func inferredRuntimeTags(from tokens: Set<String>, chip: String) -> [String] {
        let ordered = inferredRuntimeInterests(from: tokens)
        return Array(Set(ordered + ["runtime", chip.lowercased()])).sorted()
    }

    nonisolated private static func inferredRuntimeBorderColor(from tokens: Set<String>) -> String {
        if tokens.contains("scanner") || tokens.contains("nearby") { return "#0891B2" }
        if tokens.contains("vault") || tokens.contains("notes") { return "#9333EA" }
        if tokens.contains("trust") || tokens.contains("credentials") { return "#B45309" }
        if tokens.contains("commerce") || tokens.contains("payments") { return "#15803D" }
        if tokens.contains("identity") || tokens.contains("records") { return "#0F766E" }
        if tokens.contains("events") || tokens.contains("automation") { return "#475569" }
        return "#64748B"
    }

    nonisolated private static func inferredRuntimeFlowDriven(from tokens: Set<String>) -> Bool {
        tokens.contains("scanner") ||
        tokens.contains("events") ||
        tokens.contains("automation") ||
        tokens.contains("communication") ||
        tokens.contains("messaging")
    }

    nonisolated private static func inferredRuntimeSetKeys(from tokens: Set<String>) -> [String]? {
        if tokens.contains("scanner") {
            return ["start", "stop", "invite", "requestContact"]
        }
        if tokens.contains("events") || tokens.contains("automation") {
            return ["start", "stop"]
        }
        if tokens.contains("trust") || tokens.contains("credentials") {
            return ["seed", "evaluate", "remove"]
        }
        return nil
    }

    nonisolated private static func inferredRuntimeTopics(from tokens: Set<String>) -> [String]? {
        if tokens.contains("scanner") {
            return ["scanner.status", "scanner.found", "scanner.connected"]
        }
        if tokens.contains("events") || tokens.contains("automation") {
            return ["event", "status"]
        }
        if tokens.contains("communication") || tokens.contains("messaging") {
            return ["message", "notification"]
        }
        return nil
    }

    nonisolated private static func runtimeChip(for scope: CellUsageScope) -> String {
        switch scope {
        case .template:
            return "TEMPLATE"
        case .identityUnique:
            return "LOCAL"
        case .scaffoldUnique:
            return "LOCAL"
        }
    }

    nonisolated private static func looksLikeOpaqueRuntimeInstance(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let candidate = trimmed.replacingOccurrences(of: "cell:///", with: "")
        let hexish = candidate.replacingOccurrences(of: "-", with: "")
        return candidate.count >= 32 && hexish.allSatisfy { $0.isHexDigit }
    }

    nonisolated private static func personalCopilotV1CatalogDescriptors() -> [StaticCatalogDescriptor] {
        func scopedInterests(_ interests: [String], policyCategory: String) -> [String] {
            BindingPersonalCopilotV1Policy.discoveryInterests(interests, policyCategory: policyCategory)
        }

        func hints(
            _ policyCategory: String,
            requiresLogin: Bool = false,
            requiresUserGeneratedContentModeration: Bool = false,
            nativePermissionRequests: [String] = [],
            universalLinkPath: String
        ) -> [String] {
            BindingPersonalCopilotV1Policy.metadataHints(
                policyCategory: policyCategory,
                requiresLogin: requiresLogin,
                requiresUserGeneratedContentModeration: requiresUserGeneratedContentModeration,
                nativePermissionRequests: nativePermissionRequests,
                universalLink: "https://staging.haven.digipomps.org/app/\(universalLinkPath)",
                reviewSummary: "Curated Personal Co-Pilot V1 surface for \(policyCategory)."
            )
        }

        return [
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///PersonalIdentity",
                sourceCellName: "PersonalIdentityCell",
                displayName: "Personal Home",
                purpose: "Personal Co-Pilot startside",
                purposeDescription: "Lokal requester, public/private identity og konto-livssyklus.",
                interests: scopedInterests(["identity", "privacy", "account", "export", "delete"], policyCategory: "identity-and-account"),
                summary: "Startside for identitet, samtykker, eksport og sletting.",
                categoryPath: ["personal-copilot", "identity"],
                tags: ["personal-copilot", "identity", "privacy"],
                menuSlots: [.upperLeft],
                chip: "LOCAL",
                borderColor: "#0F766E",
                policyHints: hints("identity-and-account", universalLinkPath: "personal/home"),
                recommendedContexts: ["personal-copilot", "daily-use", "privacy"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///PersonalProfileDraft",
                sourceCellName: "PersonalProfileDraftCell",
                displayName: "My Profile",
                purpose: "Privat profilutkast",
                purposeDescription: "Lokal profil-draft med publish preview og eksplisitt samtykke for sky-publisering.",
                interests: scopedInterests(["profile", "draft", "consent", "public-profile"], policyCategory: "profile-draft"),
                summary: "Privat profilutkast som blir pa telefonen til brukeren publiserer.",
                categoryPath: ["personal-copilot", "profile"],
                tags: ["profile", "draft", "consent"],
                menuSlots: [.upperMid],
                chip: "LOCAL DRAFT",
                borderColor: "#0E7490",
                policyHints: hints("profile-draft", requiresUserGeneratedContentModeration: true, universalLinkPath: "personal/profile"),
                recommendedContexts: ["personal-copilot", "profile", "privacy"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/PersonalProfilePublisher",
                sourceCellName: "PersonalProfilePublisherCell",
                displayName: "Publish Public Profile",
                purpose: "Publisering av offentlig profil",
                purposeDescription: "Mottar eksplisitt publiserte profiler og stoetter unpublish/delete.",
                interests: scopedInterests(["profile", "publish", "unpublish", "delete", "consent"], policyCategory: "profile-publish"),
                summary: "Publiser, avpubliser eller slett offentlig profil etter tydelig samtykke.",
                categoryPath: ["personal-copilot", "profile", "publishing"],
                tags: ["profile", "publish", "moderation", "delete"],
                menuSlots: [.upperMid],
                chip: "REMOTE",
                borderColor: "#2563EB",
                policyHints: hints("profile-publish", requiresLogin: true, requiresUserGeneratedContentModeration: true, universalLinkPath: "personal/profile/publish"),
                flowDriven: true,
                recommendedContexts: ["personal-copilot", "profile", "publishing"],
                ioGetKeys: ["state", "publicReadModel", "profileStatus", "skeletonConfiguration"],
                ioSetKeys: ["publishDraft.displayName", "publishDraft.headline", "publishDraft.summary", "publishDraft.interestsText", "publishProfile", "unpublishProfile", "deleteProfile"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/PublicProfileDirectory",
                sourceCellName: "PublicProfileDirectoryCell",
                displayName: "Public Profile Directory",
                purpose: "Offentlig profilkatalog",
                purposeDescription: "Lesbar offentlig katalog med rapportering, skjuling og blokkering.",
                interests: scopedInterests(["profiles", "directory", "search", "report", "block"], policyCategory: "public-directory"),
                summary: "Sok i offentlige profiler med rapporterings- og skjulingskontroller.",
                categoryPath: ["personal-copilot", "profile", "directory"],
                tags: ["profiles", "directory", "report", "block"],
                chip: "REMOTE",
                borderColor: "#2563EB",
                policyHints: hints("public-directory", requiresLogin: true, requiresUserGeneratedContentModeration: true, universalLinkPath: "personal/directory"),
                flowDriven: true,
                recommendedContexts: ["personal-copilot", "profile-discovery"],
                ioGetKeys: ["state", "blockedProfiles", "directoryModerationStatus", "skeletonConfiguration"],
                ioSetKeys: ["query", "searchProfiles", "profileDetail", "reportProfile", "hideProfile", "blockProfile"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/PersonalMatchmaking",
                sourceCellName: "PersonalMatchmakingCell",
                displayName: "Matches",
                purpose: "Samtykkebasert matching",
                purposeDescription: "Returnerer match-forslag uten aa starte chat for begge parter samtykker.",
                interests: scopedInterests(["matching", "consent", "profile", "invite-only-chat"], policyCategory: "matching"),
                summary: "Forslag til personer og samarbeid uten automatisk chat-start.",
                categoryPath: ["personal-copilot", "matching"],
                tags: ["matching", "consent", "invite"],
                menuSlots: [.upperLeft],
                chip: "REMOTE",
                borderColor: "#B45309",
                policyHints: hints("matching", requiresLogin: true, requiresUserGeneratedContentModeration: true, universalLinkPath: "personal/matches"),
                flowDriven: true,
                recommendedContexts: ["personal-copilot", "matching", "consent"],
                ioGetKeys: ["state", "preferences", "suggestions", "skeletonConfiguration"],
                ioSetKeys: ["preferencesText", "setPreferences", "refreshSuggestions", "requestMatchConsent", "acceptMatchConsent", "declineMatchConsent", "clearMatchSuggestion"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///PersonalChatHub",
                sourceCellName: "PersonalChatHubCell",
                displayName: "Co-Pilot",
                purpose: "Central purpose-driven co-pilot chat",
                purposeDescription: "Kompakt chat-first arbeidsflate som matcher naturlig sprak mot formaal, interesser, CellConfigurations, RAG-cases og trygge agent-action metadata. Alle sideeffekter krever klikk.",
                interests: scopedInterests([
                    "chat",
                    "invite-only",
                    "moderation",
                    "report",
                    "block",
                    "chat-assistant",
                    "invite-person",
                    "poll",
                    "meeting-video-intent",
                    "schedule-meeting-intent",
                    "project-intent",
                    "todo-intent",
                    "reminder-intent",
                    "capability-gap",
                    "resource-router",
                    "rag-query",
                    "cell-scoped-ai-provider",
                    "provider-slot",
                    "voice-input",
                    "speech-to-text",
                    "dictation",
                    "local-agent-action",
                    "signed-remote-intent",
                    "component-surface",
                    "requires-user-approval",
                    "purpose-interest-weighted",
                    "production-ready",
                    "quality-gate",
                    "failure-budget",
                    "gui-evaluation",
                    "purposeRef=personal.chat.assist.invite",
                    "purposeRef=personal.chat.assist.poll",
                    "purposeRef=personal.chat.assist.resource-router",
                    "purposeRef=personal.chat.assist.rag-query",
                    "purposeRef=personal.chat.assist.provider-route",
                    "purposeRef=personal.production.readiness",
                    "purposeRef=personal.chat.assist.meeting.video",
                    "purposeRef=personal.chat.assist.meeting.schedule",
                    "purposeRef=personal.chat.assist.project",
                    "purposeRef=personal.chat.assist.todo",
                    "purposeRef=personal.chat.assist.reminder",
                    "purposeRef=personal.chat.assist.capability-request",
                    "purposeRef=personal.chat.assist.local-agent-action",
                    "purposeRef=personal.agent.local.gui.finder.close-windows"
                ], policyCategory: "purpose-driven-chat"),
                summary: "Cell-scoped chat hub for Personal Co-Pilot.",
                categoryPath: ["personal-copilot", "chat"],
                tags: ["chat", "moderation", "invite", "poll", "assistant", "copilot"],
                menuSlots: [.upperLeft, .lowerLeft],
                chip: "LOCAL",
                borderColor: "#0F766E",
                policyHints: hints("purpose-driven-chat", requiresLogin: true, requiresUserGeneratedContentModeration: true, universalLinkPath: "personal/chat/copilot"),
                flowDriven: true,
                recommendedContexts: ["personal-copilot", "chat", "safety"],
                ioGetKeys: ["state", "assistantState", "assistantSuggestions", "assistantPolicy", "assistantProviders", "providerRecommendation", "threads", "messages", "blockedUsers", "moderationStatus", "meetingBridge", "polls", "pollDraft", "workbenchState", "workbenchModules", "capabilityRequestDraft", "capabilityRequests", "entityExtension", "voiceState", "purposeWeights", "purposeGoal", "skeletonConfiguration"],
                ioSetKeys: ["invite", "acceptInvite", "declineInvite", "setComposer", "sendComposedMessage", "clearComposer", "reportMessage", "blockUser", "unblockUser", "assistant.analyzeDraft", "assistant.acceptSuggestion", "assistant.dismissSuggestion", "assistant.queryResource", "assistant.provider.register", "assistant.provider.recommend", "assistant.setCandidateQuery", "assistant.selectCandidate", "entityExtension.scan", "voice.requestPermission", "voice.startListening", "voice.stopListening", "voice.acceptTranscript", "voice.acceptTranscriptAndAnalyze", "voice.clearTranscript", "ui.openSuggestedHelper", "ui.openComponentSurface", "ui.minimizeComponentSurface", "ui.restoreComponentSurface", "ui.dismissComponentSurface", "ui.pinComponentSurface", "ui.setCurrentThread", "ui.setActiveHelper", "ui.setActiveMoreTab", "ui.setCapabilityDiscoveryEnabled", "poll.setQuestion", "poll.setOptions", "poll.create", "poll.vote", "poll.close", "idea.title", "idea.content", "idea.capture", "todo.title", "todo.note", "todo.dueAtText", "todo.assigneeUUID", "todo.create", "project.title", "project.description", "project.membersText", "project.create", "reminder.title", "reminder.scheduledAtText", "reminder.scope", "reminder.create", "meeting.title", "meeting.targetProfileID", "meeting.proposedTimesText", "meeting.setBridgeMetadata", "meeting.schedule", "agent.review.actionID", "agent.review.reason", "agent.review.argumentsText", "agent.review.signatureBase64", "agent.review.create", "agent.review.execute", "capabilityRequest.title", "capabilityRequest.summary", "capabilityRequest.destination", "capabilityRequest.category", "capabilityRequest.submit"],
                forceRefreshExisting: true
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///PersonalAgendaContext",
                sourceCellName: "PersonalAgendaContextCell",
                displayName: "Agenda Context",
                purpose: "Dagens agenda for personlig co-pilot",
                purposeDescription: "Lokal agenda-context som leser Calendar og Reminders etter eksplisitt samtykke, svarer på dagens/neste agenda, og kan dele purpose-signaler med Perspective.",
                interests: scopedInterests(["agenda", "calendar", "reminders", "daily-planning", "agenda-aspects", "purpose-interest-weighted"], policyCategory: "agenda-context"),
                summary: "Lokal agenda over kalender og påminnelser for Co-Pilot.",
                categoryPath: ["personal-copilot", "agenda"],
                tags: ["agenda", "calendar", "reminders", "planning"],
                menuSlots: [.upperRight, .lowerRight],
                chip: "LOCAL",
                borderColor: "#0F766E",
                policyHints: hints("agenda-context", nativePermissionRequests: ["calendar", "reminders"], universalLinkPath: "personal/agenda"),
                flowDriven: true,
                recommendedContexts: ["personal-copilot", "daily-use", "planning"],
                ioGetKeys: ["state", "agenda.today", "agenda.next", "agenda.items", "agenda.summary", "agenda.permissionStatus", "agenda.purposeSignals", "providerDescriptor", "skeletonConfiguration"],
                ioSetKeys: ["agenda.refresh", "agenda.answerQuery", "agenda.requestAccess", "agenda.requestCalendarAccess", "agenda.requestReminderAccess", "agenda.publishPerspectiveSignals", "agenda.clearCache"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: CalendarContract.endpoint,
                sourceCellName: CalendarContract.storeCellName,
                displayName: "Calendar Store",
                purpose: "Canonical kalender for personlig co-pilot",
                purposeDescription: "Lokal HAVEN-kalenderkontrakt med CalendarItem/CalendarOccurrence, portable calendar visualization og eksplisitt ICS import/export.",
                interests: scopedInterests(["calendar", "agenda", "schedule", "ics", "recurrence", "planning"], policyCategory: "calendar-store"),
                summary: "Canonical kalenderdata med portable visning og liste-fallback.",
                categoryPath: ["personal-copilot", "calendar"],
                tags: ["calendar", "agenda", "schedule", "ics"],
                menuSlots: [.upperRight, .lowerRight],
                chip: "LOCAL",
                borderColor: "#2563EB",
                policyHints: hints("calendar-store", universalLinkPath: "personal/calendar"),
                flowDriven: true,
                recommendedContexts: ["personal-copilot", "daily-use", "planning"],
                ioGetKeys: [CalendarContract.Keys.state, CalendarContract.Keys.collections, CalendarContract.Keys.items, CalendarContract.Keys.occurrences, CalendarContract.Keys.permissionStatus],
                ioSetKeys: [CalendarContract.Keys.queryOccurrences, CalendarContract.Keys.createItem, CalendarContract.Keys.updateItem, CalendarContract.Keys.deleteItem, CalendarContract.Keys.importCalendar, CalendarContract.Keys.exportCalendar],
                ioTopics: [CalendarContract.flowTopic]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///Vault",
                sourceCellName: "VaultCell",
                displayName: "Vault / Ideas",
                purpose: "Personlig vault for ideer og prosjekter",
                purposeDescription: "Lokal Obsidian-lignende vault. Remote konfigurasjoner faar ikke vault-tilgang uten eksplisitt brukerhandling.",
                interests: scopedInterests(["vault", "ideas", "projects", "notes", "markdown"], policyCategory: "local-vault"),
                summary: "Organiser ideer, prosjekter og notater lokalt.",
                categoryPath: ["personal-copilot", "vault"],
                tags: ["vault", "notes", "projects", "ideas"],
                menuSlots: [.upperRight, .lowerRight],
                chip: "LOCAL",
                borderColor: "#9333EA",
                policyHints: hints("local-vault", nativePermissionRequests: ["vault"], universalLinkPath: "personal/vault"),
                recommendedContexts: ["personal-copilot", "knowledge-work", "projects"],
                forceRefreshExisting: true
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/PersonalMeetingCoordinator",
                sourceCellName: "PersonalMeetingCoordinatorCell",
                displayName: "Meeting Intent",
                purpose: "Trygg koordinering av moteintensjon",
                purposeDescription: "Foreslar motetider og Jitsi-metadata som trygg placeholder uten native calendar, camera eller mic-permission.",
                interests: scopedInterests(["meeting", "coordination", "intent", "scheduling", "jitsi-ready"], policyCategory: "meeting-intent"),
                summary: "Koordinerer moteintensjoner som data, ikke native permissions.",
                categoryPath: ["personal-copilot", "meetings"],
                tags: ["meeting", "coordination", "jitsi-ready"],
                menuSlots: [.upperRight, .lowerRight],
                chip: "HYBRID",
                borderColor: "#0D9488",
                policyHints: hints("meeting-intent", requiresLogin: true, requiresUserGeneratedContentModeration: true, universalLinkPath: "personal/meeting"),
                flowDriven: true,
                recommendedContexts: ["personal-copilot", "meetings", "scheduling"],
                ioGetKeys: ["state", "meetingBridge", "skeletonConfiguration"],
                ioSetKeys: ["draft.title", "draft.targetProfileID", "draft.proposedTimesText", "proposeTimes", "acceptTime", "declineTime", "clearMeetingIntent"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///PersonalPrivacyAudit",
                sourceCellName: "PersonalPrivacyAuditCell",
                displayName: "Privacy Audit",
                purpose: "Lokal personvernlogg",
                purposeDescription: "Logg for profile publish, match consent, chat invite, remote config loads og permission grants.",
                interests: scopedInterests(["privacy", "audit", "consent", "permissions", "remote-config"], policyCategory: "privacy-audit"),
                summary: "Lokal audit over samtykker og capability-gater.",
                categoryPath: ["personal-copilot", "privacy"],
                tags: ["privacy", "audit", "consent"],
                menuSlots: [.lowerLeft],
                chip: "LOCAL",
                borderColor: "#334155",
                policyHints: hints("privacy-audit", universalLinkPath: "personal/privacy/audit"),
                flowDriven: true,
                recommendedContexts: ["personal-copilot", "privacy", "review"],
                ioGetKeys: ["state", "audit.entries"],
                ioSetKeys: ["audit.record"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/PersonalCopilotConfigurationCatalog",
                sourceCellName: "PersonalCopilotConfigurationCatalogCell",
                displayName: "Personal Co-Pilot Catalog",
                purpose: "Allowlisted Personal Co-Pilot catalog",
                purposeDescription: "Returnerer bare App Store-godkjente Personal Co-Pilot CellConfigurations med review metadata.",
                interests: scopedInterests(["catalog", "allowlist", "review-metadata", "personal-copilot"], policyCategory: "catalog"),
                summary: "Katalog for godkjente Personal Co-Pilot-flater.",
                categoryPath: ["personal-copilot", "catalog"],
                tags: ["catalog", "allowlist", "review"],
                chip: "REMOTE",
                borderColor: "#2563EB",
                policyHints: hints("catalog", universalLinkPath: "personal/catalog"),
                flowDriven: true,
                recommendedContexts: ["personal-copilot", "catalog", "app-store"],
                ioGetKeys: ["state", "catalogEntries", "configurations", "policySummary"],
                ioSetKeys: []
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///AppleIntelligence",
                sourceCellName: "AppleIntelligenceCell",
                displayName: "Apple Intelligence",
                purpose: "Apple Intelligence for personlig co-pilot",
                purposeDescription: "Semantisk matching og forslag med eksplisitt brukerhandling for AI-capabilities.",
                interests: scopedInterests(["assistant", "apple-intelligence", "semantic-matching"], policyCategory: "apple-intelligence"),
                summary: "Semantisk inngang til godkjente Personal Co-Pilot-flater.",
                categoryPath: ["personal-copilot", "assistant"],
                tags: ["assistant", "ai", "matching"],
                menuSlots: [.upperMid],
                chip: "LOCAL",
                borderColor: "#2563EB",
                policyHints: hints("apple-intelligence", nativePermissionRequests: ["apple-intelligence-on-explicit-action"], universalLinkPath: "personal/assistant"),
                recommendedContexts: ["personal-copilot", "assistant", "matching"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///EntityScanner",
                sourceCellName: "EntityScannerCell",
                displayName: "Entity Scanner",
                purpose: "Entity Scanner for personlig kontaktetablering",
                purposeDescription: "Nearby discovery og signerte encounter proofs med eksplisitte hardware-permissions.",
                interests: scopedInterests(["scanner", "nearby", "identity", "peer", "proofs"], policyCategory: "hardware-scanner"),
                summary: "Oppdag naerliggende enheter og etabler kontakt trygt.",
                categoryPath: ["personal-copilot", "hardware"],
                tags: ["scanner", "nearby", "identity"],
                menuSlots: [.lowerLeft],
                chip: "LOCAL",
                borderColor: "#0891B2",
                policyHints: hints("hardware-scanner", nativePermissionRequests: ["nearby", "bluetooth"], universalLinkPath: "personal/scanner"),
                flowDriven: true,
                recommendedContexts: ["personal-copilot", "nearby", "identity"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///WorkflowStudio",
                sourceCellName: "WorkflowStudioCell",
                displayName: "Workflow Studio",
                purpose: "Workflow Studio for personlig co-pilot",
                purposeDescription: "Bygg og test personlige arbeidsflyter innenfor godkjent Personal Co-Pilot-scope.",
                interests: scopedInterests(["workflow", "automation", "studio", "personal-productivity"], policyCategory: "workflow-studio"),
                summary: "Lag personlige workflows uten skjulte remote features.",
                categoryPath: ["personal-copilot", "workflow"],
                tags: ["workflow", "automation", "studio"],
                menuSlots: [.upperMid, .lowerMid],
                chip: "LOCAL",
                borderColor: "#0F766E",
                policyHints: hints("workflow-studio", universalLinkPath: "personal/workflow"),
                recommendedContexts: ["personal-copilot", "workflow", "automation"]
            )
        ]
    }

    nonisolated private static func userFacingRemoteCatalogDescriptors() -> [StaticCatalogDescriptor] {
        [
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/ConferenceUIRouter",
                sourceCellName: "ConferenceUIRouterCell",
                displayName: "Conference MVP",
                purpose: "Konferanseflyt og matchmaking",
                purposeDescription: "Routing, partnering, scheduling og konferanseflyt for deltakere.",
                interests: ["conference", "matchmaking", "scheduling", "events"],
                summary: "Konferanseflyt med routing, matchmaking og scheduling.",
                categoryPath: ["experiences", "conference"],
                tags: ["conference", "events", "matchmaking", "scheduling"],
                menuSlots: [.upperRight],
                chip: "REMOTE",
                borderColor: "#2563EB",
                flowDriven: true,
                recommendedContexts: ["conference", "partnering", "event-day"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///ConferenceConfigurationNavigator",
                sourceCellName: "ConferenceConfigurationNavigatorLocalCell",
                displayName: "Conference Codex Live Configurations",
                purpose: "Conference live configuration launcher",
                purposeDescription: "Last inn de kjørbare konferanse-CellConfigurationene som finnes i HAVEN akkurat na, uten aa gjette paa skjulte demo-ruter eller stale dokumentasjonsfiler.",
                interests: ["conference", "codex", "binding", "configurations", "launcher", "participant", "organizer", "sponsor", "public"],
                summary: "Operator-/demo-innngang til de faktiske konferanseflatene som kan lastes i HAVEN na.",
                categoryPath: ["experiences", "conference", "demo"],
                tags: ["conference", "codex", "binding", "launcher", "configurations"],
                menuSlots: [.upperMid, .lowerMid],
                chip: "LOCAL DEMO",
                borderColor: "#A77044",
                flowDriven: true,
                recommendedContexts: ["conference", "demo", "meeting", "binding"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///ConferenceConfigurationNavigator",
                sourceCellName: "ConferenceConfigurationNavigatorLocalCell",
                displayName: "Conference Claude Design Reference",
                purpose: "Conference Claude design reference",
                purposeDescription: "Loadbar designreferanse som oppsummerer den repo-lokale Claude-guiden og peker til de naavaerende konferanseflatene som matcher hver rolle best.",
                interests: ["conference", "claude", "design", "reference", "visual-direction", "binding"],
                summary: "Claude-designreferanse i HAVEN med tydelig mapping til dagens kjørbare conference-flater.",
                categoryPath: ["experiences", "conference", "design"],
                tags: ["conference", "claude", "design", "reference", "visual"],
                menuSlots: [.upperRight, .lowerRight],
                chip: "LOCAL REFERENCE",
                borderColor: "#5B4BC8",
                flowDriven: false,
                recommendedContexts: ["conference", "design-review", "meeting", "showcase"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///ConferenceDemoLauncher",
                sourceCellName: "ConferenceDemoLauncherLocalCell",
                displayName: "Conference Demo Launcher",
                purpose: "Conference demo launcher",
                purposeDescription: "Fast startflate for konferansedemoen i HAVEN. Hver knapp laster en eksisterende conference-konfigurasjon i samme Porthole-session, tett opp mot CellScaffold-historien.",
                interests: ["conference", "demo", "launcher", "participant", "organizer", "binding", "web"],
                summary: "Deterministisk launcher for konferansedemoen i HAVEN, med public opener, participant cockpit, chat og control tower i fast rekkefølge.",
                categoryPath: ["experiences", "conference", "demo"],
                tags: ["conference", "demo", "launcher", "participant", "organizer"],
                menuSlots: [.upperMid, .lowerMid],
                chip: "LOCAL FLOW",
                borderColor: "#0F766E",
                flowDriven: true,
                recommendedContexts: ["conference", "demo", "story"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///ConferenceIdentityLinkIntake",
                sourceCellName: "ConferenceIdentityLinkIntakeCell",
                displayName: "Conference Scaffold Setup & Identity Link",
                purpose: "Conference scaffold setup and identity link review",
                purposeDescription: "Mobil intake for scaffold setup og identity-link challenges. HAVEN viser incoming challenge-data, requested scopes og lokal key-ownership før web/scaffold fullfører approval.",
                interests: ["conference", "identity-link", "setup", "enrollment", "scaffold", "proofs"],
                summary: "Mobil inngang for scaffold setup, QR/deep-link challenge review og lokal key-possession før approval.",
                categoryPath: ["experiences", "conference", "setup"],
                tags: ["conference", "identity-link", "setup", "enrollment", "proofs"],
                menuSlots: [.upperMid, .lowerMid],
                chip: "LOCAL FLOW",
                borderColor: "#2563EB",
                flowDriven: true,
                recommendedContexts: ["conference", "setup", "identity-link"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///ConferenceParticipantPreviewShell",
                sourceCellName: "ConferenceParticipantPreviewShellLocalFallbackCell",
                displayName: "Conference Participant Portal Dashboard",
                purpose: "Conference participantportal",
                purposeDescription: "Participant-shell med agenda, people, meetings og shared relations over en lokal preview-wrapper i HAVEN.",
                interests: ["conference", "participant", "dashboard", "agenda", "sessions", "matchmaking", "meetings"],
                summary: "Participant-shell med agenda, anbefalinger og meeting timeline over lokal preview-wrapper i HAVEN.",
                categoryPath: ["experiences", "conference", "participant"],
                tags: ["conference", "participant", "agenda", "matchmaking", "meetings"],
                menuSlots: [.upperMid, .lowerMid],
                chip: "LOCAL PREVIEW",
                borderColor: "#0F766E",
                flowDriven: true,
                recommendedContexts: ["conference", "event-day", "participant"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///ConferenceParticipantPreviewShell",
                sourceCellName: "ConferenceParticipantPreviewShellLocalFallbackCell",
                displayName: "Conference AI Assistant",
                purpose: "Conference copilot",
                purposeDescription: "Participant preview-state side om side med AIGateway for briefing, prioritering og oppfølging.",
                interests: ["conference", "ai", "copilot", "prompting", "matchmaking", "meetings"],
                summary: "Conference copilot som kombinerer participant preview-state med AIGateway i samme arbeidsflate.",
                categoryPath: ["experiences", "conference", "ai"],
                tags: ["conference", "ai", "copilot", "prompting"],
                menuSlots: [.upperMid],
                chip: "LOCAL DEMO",
                borderColor: "#7C3AED",
                flowDriven: true,
                recommendedContexts: ["conference", "briefing", "follow-up"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///ConferenceAdminPreviewShell",
                sourceCellName: "ConferenceAdminPreviewShellLocalFallbackCell",
                displayName: "Conference Control Tower",
                purpose: "Conference control tower",
                purposeDescription: "Organizer-fokusert preview-wrapper for drift, innhold, innsikt og sponsor-oversikt i HAVEN.",
                interests: ["conference", "admin", "control-tower", "operations", "insights"],
                summary: "Organizer control tower via lokal preview-wrapper i HAVEN.",
                categoryPath: ["experiences", "conference", "operations"],
                tags: ["conference", "admin", "operations", "insights"],
                menuSlots: [.upperRight],
                chip: "LOCAL PREVIEW",
                borderColor: "#B45309",
                flowDriven: true,
                recommendedContexts: ["conference", "operations", "organizer"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///ConferencePublicShellFixture",
                sourceCellName: "ConferencePublicShellFixtureCell",
                displayName: "Conference Public Surface",
                purpose: "Conference public website",
                purposeDescription: "Landing, tracks, sessions, people, articles og facilities i samme public shell.",
                interests: ["conference", "public", "landing", "tracks", "sessions", "articles"],
                summary: "Public shell med landing, tracks, sessions, people og facilities via lokal demo-fixture i HAVEN.",
                categoryPath: ["experiences", "conference", "public"],
                tags: ["conference", "public", "landing", "program"],
                menuSlots: [.upperLeft],
                chip: "LOCAL DEMO",
                borderColor: "#2563EB",
                flowDriven: true,
                recommendedContexts: ["conference", "public", "website"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///ConferenceSponsorShellFixture",
                sourceCellName: "ConferenceSponsorShellFixtureCell",
                displayName: "Conference Sponsor Follow-up",
                purpose: "Conference sponsor follow-up",
                purposeDescription: "Sponsor-owned shell for lead inbox, consent, unlock, export og retention.",
                interests: ["conference", "sponsor", "lead-vault", "consent", "handoff", "retention"],
                summary: "Sponsor shell med lead inbox, consent, unlock og retention via lokal demo-fixture i HAVEN.",
                categoryPath: ["experiences", "conference", "sponsor"],
                tags: ["conference", "sponsor", "leads", "retention", "consent"],
                menuSlots: [.upperRight, .lowerMid],
                chip: "LOCAL DEMO",
                borderColor: "#C2410C",
                flowDriven: true,
                recommendedContexts: ["conference", "sponsor", "lead-followup"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/Todo",
                sourceCellName: "TodoCell",
                displayName: "Todo MVP",
                purpose: "Personlig oppgaveflyt",
                purposeDescription: "Opprett, prioriter og foelg opp personlige oppgaver.",
                interests: ["todo", "tasks", "planning", "productivity"],
                summary: "Personlig oppgaveliste med prioriteter og oppfoelging.",
                categoryPath: ["productivity", "tasks"],
                tags: ["todo", "tasks", "planning", "productivity"],
                menuSlots: [.lowerMid],
                chip: "REMOTE",
                borderColor: "#16A34A",
                flowDriven: true,
                recommendedContexts: ["personal-productivity", "planning", "daily-use"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/Vault",
                sourceCellName: "VaultCell",
                displayName: "Obsidian Vault",
                purpose: "Notater og kunnskapsgraf",
                purposeDescription: "Utforsk og organiser notater, lenker og kunnskapsstruktur.",
                interests: ["vault", "notes", "obsidian", "knowledge-graph", "markdown"],
                summary: "Vault-notater og knowledge graph i Obsidian-stil.",
                categoryPath: ["knowledge", "vault"],
                tags: ["vault", "notes", "obsidian", "knowledge-graph"],
                menuSlots: [.lowerRight],
                chip: "REMOTE",
                borderColor: "#9333EA",
                flowDriven: true,
                recommendedContexts: ["research", "notes", "knowledge-work"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/LeadVault",
                sourceCellName: "LeadVaultCell",
                displayName: "Lead Vault",
                purpose: "Lead capture og oppfoelging",
                purposeDescription: "Haandter leads, consent og tilgangsstyring i konferanse- og salgsflyt.",
                interests: ["leads", "consent", "conference", "sales-ops", "crm"],
                summary: "Conference leads, consent og tilgangsstyring.",
                categoryPath: ["sales", "lead-management"],
                tags: ["leads", "consent", "conference", "crm"],
                chip: "REMOTE",
                borderColor: "#0F766E",
                flowDriven: true,
                recommendedContexts: ["conference", "sales", "lead-followup"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/ConsentReceipt",
                sourceCellName: "ConsentReceiptCell",
                displayName: "Consent Receipt",
                purpose: "Samtykkebevis og logg",
                purposeDescription: "Vis og etterproev samtykkelogg og mottatte kvitteringer.",
                interests: ["consent", "receipts", "compliance", "audit"],
                summary: "Samtykkelogg og kvitteringer fra consent-flyten.",
                categoryPath: ["compliance", "consent"],
                tags: ["consent", "compliance", "audit", "receipts"],
                chip: "REMOTE",
                borderColor: "#D97706",
                recommendedContexts: ["compliance", "audit", "conference"]
            )
        ]
    }

    nonisolated private static func runtimeControlCatalogDescriptors() -> [StaticCatalogDescriptor] {
        [
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///Porthole",
                sourceCellName: "OrchestratorCell",
                displayName: "Porthole Control Surface",
                purpose: "Laste og rendere CellConfigurations",
                purposeDescription: "Hovedflate for aa laste, rendere og orkestrere kontroll-konfigurasjoner.",
                interests: ["porthole", "rendering", "workspace", "orchestration"],
                summary: "Kontrollflate for lasting og rendering av valgte CellConfigurations.",
                categoryPath: ["runtime", "orchestration"],
                tags: ["porthole", "orchestration", "workspace", "runtime"],
                chip: "LOCAL",
                borderColor: "#1D4ED8",
                flowDriven: true,
                recommendedContexts: ["tool-exploration", "composition"],
                ioGetKeys: ["outwardMenu", "historyMenu", "connectedCellEmitters", "skeleton"],
                ioSetKeys: ["setConfiguration", "addConfiguration", "addReference"],
                ioTopics: ["porthole"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///Perspective",
                sourceCellName: "PerspectiveCell",
                displayName: "Perspective Context",
                purpose: "Lokal kontekst og preferanser",
                purposeDescription: "Holder aktiv purpose-state, interesser og kontekst som paavirker anbefalinger.",
                interests: ["perspective", "purpose", "interests", "context"],
                summary: "Lokal context-store for purpose, interests og vektede preferanser.",
                categoryPath: ["identity", "context"],
                tags: ["perspective", "purpose", "interests", "context"],
                chip: "LOCAL",
                borderColor: "#0F766E",
                recommendedContexts: ["matching", "personalization", "identity"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///PersonalAgendaContext",
                sourceCellName: "PersonalAgendaContextCell",
                displayName: "Agenda Context",
                purpose: "Lokal agenda-context",
                purposeDescription: "Leser Calendar/Reminders etter eksplisitt samtykke og gjør dagens/neste agenda tilgjengelig for chat og Perspective.",
                interests: ["agenda", "calendar", "reminders", "daily-planning", "perspective", "context"],
                summary: "Owner-local agenda context for kalender, påminnelser og rolleavklaring.",
                categoryPath: ["identity", "context"],
                tags: ["agenda", "calendar", "reminders", "context"],
                menuSlots: [.upperRight],
                chip: "LOCAL",
                borderColor: "#0F766E",
                flowDriven: true,
                recommendedContexts: ["daily-use", "planning", "personalization"],
                ioGetKeys: ["state", "agenda.today", "agenda.next", "agenda.items", "agenda.summary", "agenda.permissionStatus", "agenda.purposeSignals"],
                ioSetKeys: ["agenda.refresh", "agenda.answerQuery", "agenda.requestAccess", "agenda.publishPerspectiveSignals"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///EntityAnchor",
                sourceCellName: "EntityAnchorCell",
                displayName: "Entity Anchor Records",
                purpose: "Lokal entity-lagring og proofs",
                purposeDescription: "Holder lokal entity-data, relasjoner, encounters og proofs.",
                interests: ["entity", "identity", "proofs", "storage"],
                summary: "Vedvarende lagring for lokal entitet, relasjoner og proofs.",
                categoryPath: ["identity", "storage"],
                tags: ["entity", "identity", "proofs", "storage"],
                chip: "LOCAL",
                borderColor: "#0F766E",
                recommendedContexts: ["identity", "proofs", "records"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///Vault",
                sourceCellName: "VaultCell",
                displayName: "Vault Control Surface",
                purpose: "Lokal vault-lagring",
                purposeDescription: "Lokal vault for notater, innhold og strukturer.",
                interests: ["vault", "notes", "storage", "knowledge"],
                summary: "Lokal vault-kontrollflate for innhold og lenket kunnskap.",
                categoryPath: ["knowledge", "storage"],
                tags: ["vault", "notes", "knowledge", "storage"],
                chip: "LOCAL",
                borderColor: "#9333EA",
                recommendedContexts: ["notes", "knowledge-work"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///CommonsResolver",
                sourceCellName: "CommonsResolverCell",
                displayName: "Commons Resolver Control",
                purpose: "Oppslag i felles ressurser",
                purposeDescription: "Resolver for delte commons-ressurser og semantiske oppslag.",
                interests: ["resolver", "commons", "lookup", "knowledge"],
                summary: "Kontrollflate for commons-oppslag og delte ressurser.",
                categoryPath: ["infrastructure", "resolver"],
                tags: ["resolver", "commons", "lookup", "infrastructure"],
                chip: "LOCAL",
                borderColor: "#475569"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///CommonsTaxonomy",
                sourceCellName: "CommonsTaxonomyCell",
                displayName: "Commons Taxonomy Browser",
                purpose: "Taksonomi og begrepsnavigasjon",
                purposeDescription: "Utforsk commons-taksonomi og begrepshierarkier.",
                interests: ["taxonomy", "concepts", "classification", "commons"],
                summary: "Browser for begreper, kategorier og taksonomier.",
                categoryPath: ["knowledge", "taxonomy"],
                tags: ["taxonomy", "concepts", "classification", "commons"],
                chip: "LOCAL",
                borderColor: "#475569"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///TrustedIssuers",
                sourceCellName: "TrustedIssuerCell",
                displayName: "Trusted Issuers Registry",
                purpose: "Haandtering av betrodde utstedere",
                purposeDescription: "Vedlikehold og oppslag av trusted issuers for claims og credentials.",
                interests: ["issuers", "credentials", "trust", "verification"],
                summary: "Register over trusted issuers for claims og credentials.",
                categoryPath: ["trust", "credentials"],
                tags: ["issuers", "credentials", "trust", "verification"],
                chip: "LOCAL",
                borderColor: "#B45309",
                recommendedContexts: ["credentials", "verification", "trust"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///Identities",
                sourceCellName: "IdentitiesCell",
                displayName: "Identities Access Control",
                purpose: "Identitetsvalg og tilgangsflate",
                purposeDescription: "Utforsk identiteter uten aa eksponere private nøkler eller vault-innhold direkte.",
                interests: ["identities", "access", "permissions", "identity"],
                summary: "Kontrollflate for identiteter og tilgangsrelaterte operasjoner.",
                categoryPath: ["identity", "access"],
                tags: ["identities", "access", "permissions", "identity"],
                chip: "LOCAL",
                borderColor: "#0F766E"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///FolderWatch",
                sourceCellName: "FolderWatchCell",
                displayName: "Folder Watch Automation",
                purpose: "Observere lokale mapper",
                purposeDescription: "Overvaak mapper og trigge arbeidsflyt naar filer endrer seg.",
                interests: ["files", "watch", "automation", "folder"],
                summary: "Overvaak mapper og trigge flyt ved filendringer.",
                categoryPath: ["automation", "files"],
                tags: ["files", "watch", "automation", "folder"],
                chip: "LOCAL",
                borderColor: "#475569",
                flowDriven: true,
                ioGetKeys: ["state"],
                ioSetKeys: ["configure", "start", "stop"],
                ioTopics: ["filesystem.watch"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///EventEmitter",
                sourceCellName: "EventEmitterCell",
                displayName: "Event Emitter Workbench",
                purpose: "Lokale signaler og test-events",
                purposeDescription: "Emit og observer lokale signaler i runtime.",
                interests: ["events", "signals", "testing", "flow"],
                summary: "Verktoy for aa emitte og observere lokale signaler.",
                categoryPath: ["testing", "signals"],
                tags: ["events", "signals", "testing", "flow"],
                chip: "LOCAL",
                borderColor: "#475569",
                flowDriven: true
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///ShoppingHandler",
                sourceCellName: "ShoppingHandlerCell",
                displayName: "Shopping Handler Control",
                purpose: "Handlekurv- og shoppinglogikk",
                purposeDescription: "Kontrollflate for shopping- og handlekurvrelatert runtime-logikk.",
                interests: ["shopping", "cart", "commerce", "checkout"],
                summary: "Kontrollflate for shopping- og checkout-relatert runtime-logikk.",
                categoryPath: ["commerce", "shopping"],
                tags: ["shopping", "cart", "commerce", "checkout"],
                chip: "LOCAL",
                borderColor: "#16A34A"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///GraphIndex",
                sourceCellName: "GraphIndexCell",
                displayName: "Graph Index Control",
                purpose: "Indeksering av grafer og relasjoner",
                purposeDescription: "Bygg og les indekser over grafer og relasjoner.",
                interests: ["graph", "index", "relations", "search"],
                summary: "Kontrollflate for grafindeks og relasjonell oppslag.",
                categoryPath: ["knowledge", "graph"],
                tags: ["graph", "index", "relations", "search"],
                chip: "LOCAL",
                borderColor: "#475569",
                ioGetKeys: ["graph.state"],
                ioSetKeys: ["graph.reindex", "graph.outgoing", "graph.incoming", "graph.neighbors"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///CloudBridge",
                sourceCellName: "BridgeBase",
                displayName: "Cloud Bridge Transport",
                purpose: "Bro mellom lokal runtime og ekstern transport",
                purposeDescription: "Transport- og bridge-lag for tilkobling mot eksterne celler.",
                interests: ["bridge", "transport", "network", "integration"],
                summary: "Transport- og bridge-lag for ekstern kommunikasjon.",
                categoryPath: ["infrastructure", "transport"],
                tags: ["bridge", "transport", "network", "integration"],
                chip: "LOCAL",
                borderColor: "#475569"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///GeneralCell",
                sourceCellName: "GeneralCell",
                displayName: "General Cell Runtime",
                purpose: "Generisk celle-runtime",
                purposeDescription: "Generisk celle som kan brukes som basis for enkel runtime-logikk.",
                interests: ["general", "cells", "runtime", "prototype"],
                summary: "Generisk celle-runtime for enkle kontroller og prototyper.",
                categoryPath: ["development", "runtime"],
                tags: ["general", "cells", "runtime", "prototype"],
                chip: "LOCAL",
                borderColor: "#475569"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///GeneralCellTemplate",
                sourceCellName: "GeneralCell",
                displayName: "General Cell Template",
                purpose: "Generisk cellemal",
                purposeDescription: "Utgangspunkt for generiske celler og skreddersydd kontroll-lag.",
                interests: ["template", "general", "cells", "prototype"],
                summary: "Generisk cellemal for nye kontrollflater og prototyper.",
                categoryPath: ["development", "templates"],
                tags: ["template", "general", "cells", "prototype"],
                chip: "LOCAL",
                borderColor: "#475569"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///DiMyWallet",
                sourceCellName: "DiMyWalletRuntimeCell",
                displayName: "DiMy Wallet Runtime",
                purpose: "Lommebok og betalingskontekst",
                purposeDescription: "Runtime for wallet-relaterte operasjoner i DiMy.",
                interests: ["wallet", "payments", "identity", "commerce"],
                summary: "Runtime for wallet- og betalingsrelaterte operasjoner.",
                categoryPath: ["commerce", "payments"],
                tags: ["wallet", "payments", "identity", "commerce"],
                chip: "LOCAL",
                borderColor: "#15803D"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///DiMyAccess",
                sourceCellName: "DiMyAccessRuntimeCell",
                displayName: "DiMy Access Runtime",
                purpose: "Tilgangsstyring for DiMy",
                purposeDescription: "Runtime for access, entitlements og policy-kontroll.",
                interests: ["access", "entitlements", "policy", "identity"],
                summary: "Runtime for tilgang, entitlements og policy-kontroll.",
                categoryPath: ["identity", "access"],
                tags: ["access", "entitlements", "policy", "identity"],
                chip: "LOCAL",
                borderColor: "#0F766E"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///DiMyPricingPolicy",
                sourceCellName: "DiMyPricingPolicyCell",
                displayName: "DiMy Pricing Policy",
                purpose: "Prisregler og betalingspolicy",
                purposeDescription: "Runtime for pricing policy og prisrelaterte regler.",
                interests: ["pricing", "policy", "payments", "commerce"],
                summary: "Runtime for prisregler og betalingspolicy.",
                categoryPath: ["commerce", "pricing"],
                tags: ["pricing", "policy", "payments", "commerce"],
                chip: "LOCAL",
                borderColor: "#15803D"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///AppleIntelligence",
                sourceCellName: "AppleIntelligenceCell",
                displayName: "Apple Intelligence Cell",
                purpose: "Semantiske assistentoperasjoner",
                purposeDescription: "Den underliggende AppleIntelligence-cellen som stoetter semantiske arbeidsflyter.",
                interests: ["assistant", "semantics", "matching", "ai"],
                summary: "Den underliggende AI-cellen for semantiske arbeidsflyter.",
                categoryPath: ["assistant", "runtime"],
                tags: ["assistant", "semantics", "matching", "ai"],
                chip: "LOCAL",
                borderColor: "#2563EB",
                recommendedContexts: ["matching", "tool-exploration"]
            )
        ]
    }

    nonisolated private static func remoteSupportCatalogDescriptors() -> [StaticCatalogDescriptor] {
        [
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/AdminEntry",
                sourceCellName: "AdminEntryCell",
                displayName: "Admin Entry",
                purpose: "Admin-startpunkt",
                purposeDescription: "Inngang til admin- og driftsflyt paa staging.",
                interests: ["admin", "operations", "entry"],
                summary: "Startpunkt for admin-relaterte verktøy.",
                categoryPath: ["operations", "admin"],
                tags: ["admin", "operations"],
                chip: "ADMIN",
                borderColor: "#7F1D1D"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/AdminOverview",
                sourceCellName: "AdminOverviewCell",
                displayName: "Admin Overview",
                purpose: "Admin drift og sikkerhet",
                purposeDescription: "Dashboard med admin-celler for resolver, lagring, host og sikkerhet.",
                interests: ["admin", "operations", "security", "metrics"],
                summary: "Drift og sikkerhet via admin-celler.",
                categoryPath: ["operations", "admin"],
                tags: ["admin", "operations", "security"],
                chip: "ADMIN",
                borderColor: "#7F1D1D"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/AdminFunding",
                sourceCellName: "AdminFundingCell",
                displayName: "Admin Funding",
                purpose: "Funding-administrasjon",
                purposeDescription: "Adminverktøy for fundingpolicy og tilknyttede operasjoner.",
                interests: ["admin", "funding", "operations"],
                summary: "Administrer funding-policy og tilhørende operasjoner.",
                categoryPath: ["operations", "admin"],
                tags: ["admin", "funding", "operations"],
                chip: "ADMIN",
                borderColor: "#7F1D1D"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/AdminFundingQueue",
                sourceCellName: "AdminFundingQueueCell",
                displayName: "Admin Funding Queue",
                purpose: "Funding-koe og godkjenning",
                purposeDescription: "Godkjenning og avslag av funding-requests.",
                interests: ["admin", "funding", "approvals", "queue"],
                summary: "Funding queue for godkjenning eller avslag.",
                categoryPath: ["operations", "admin"],
                tags: ["admin", "funding", "approvals", "queue"],
                chip: "ADMIN",
                borderColor: "#7F1D1D"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/AdminResolverStats",
                sourceCellName: "AdminResolverStatsCell",
                displayName: "Admin Resolver Stats",
                purpose: "Resolver-metrikk",
                purposeDescription: "Statistikk og innsikt om resolver-aktivitet.",
                interests: ["admin", "resolver", "metrics", "operations"],
                summary: "Resolver-statistikk og runtime-innsikt.",
                categoryPath: ["operations", "admin"],
                tags: ["admin", "resolver", "metrics"],
                chip: "ADMIN",
                borderColor: "#7F1D1D"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/AdminStorageStats",
                sourceCellName: "AdminStorageStatsCell",
                displayName: "Admin Storage Stats",
                purpose: "Lagringsmetrikker",
                purposeDescription: "Statistikk og innsikt om lagringsbruk.",
                interests: ["admin", "storage", "metrics", "operations"],
                summary: "Lagringsstatistikk og kapasitetsinnsikt.",
                categoryPath: ["operations", "admin"],
                tags: ["admin", "storage", "metrics"],
                chip: "ADMIN",
                borderColor: "#7F1D1D"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/AdminHostMetrics",
                sourceCellName: "AdminHostMetricsCell",
                displayName: "Admin Host Metrics",
                purpose: "Host-metrikker",
                purposeDescription: "Host- og nodemetrikker for driftsovervaaking.",
                interests: ["admin", "host", "metrics", "operations"],
                summary: "Host- og nodemetrikker for driftsovervaaking.",
                categoryPath: ["operations", "admin"],
                tags: ["admin", "host", "metrics"],
                chip: "ADMIN",
                borderColor: "#7F1D1D"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/AdminProcesses",
                sourceCellName: "AdminProcessesCell",
                displayName: "Admin Processes",
                purpose: "Prosessovervaaking",
                purposeDescription: "Overvaak og inspiser prosesser i drift.",
                interests: ["admin", "processes", "operations", "runtime"],
                summary: "Innsikt i prosesser og runtime-tilstand.",
                categoryPath: ["operations", "admin"],
                tags: ["admin", "processes", "operations"],
                chip: "ADMIN",
                borderColor: "#7F1D1D"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/AdminRoleEnrollment",
                sourceCellName: "AdminRoleEnrollmentCell",
                displayName: "Admin Role Enrollment",
                purpose: "Rolleopptak og tildeling",
                purposeDescription: "Haandter rolleopptak og tilgangstildeling.",
                interests: ["admin", "roles", "access", "identity"],
                summary: "Rolleopptak og tilgangstildeling.",
                categoryPath: ["operations", "admin"],
                tags: ["admin", "roles", "access", "identity"],
                chip: "ADMIN",
                borderColor: "#7F1D1D"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/AdminSecurityPolicy",
                sourceCellName: "AdminSecurityPolicyCell",
                displayName: "Admin Security Policy",
                purpose: "Sikkerhetspolicy",
                purposeDescription: "Vis og forvalt sikkerhetspolicyer.",
                interests: ["admin", "security", "policy", "compliance"],
                summary: "Forvaltning av sikkerhetspolicyer.",
                categoryPath: ["operations", "admin"],
                tags: ["admin", "security", "policy", "compliance"],
                chip: "ADMIN",
                borderColor: "#7F1D1D"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/ExhibitorAccess",
                sourceCellName: "ExhibitorAccessCell",
                displayName: "Exhibitor Access",
                purpose: "Utstilleradgang",
                purposeDescription: "Haandter utstiller- og messeadgang.",
                interests: ["conference", "exhibitor", "access", "events"],
                summary: "Utstiller- og messeadgang.",
                categoryPath: ["events", "access"],
                tags: ["conference", "exhibitor", "access"],
                chip: "REMOTE",
                borderColor: "#1D4ED8"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/DeviceRegistration",
                sourceCellName: "DeviceRegistrationCell",
                displayName: "Device Registration",
                purpose: "Enhetsregistrering",
                purposeDescription: "Registrer enheter og knytt dem til riktige flyter.",
                interests: ["devices", "registration", "identity", "access"],
                summary: "Registrer og forvalt enheter.",
                categoryPath: ["devices", "identity"],
                tags: ["devices", "registration", "identity"],
                chip: "REMOTE",
                borderColor: "#2563EB"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/NotificationOutbox",
                sourceCellName: "NotificationOutboxCell",
                displayName: "Notification Outbox",
                purpose: "Utgaaende varsler",
                purposeDescription: "Koordiner utgaaende varsler og meldingslevering.",
                interests: ["notifications", "outbox", "messaging", "delivery"],
                summary: "Utgaaende varsler og leveringskoe.",
                categoryPath: ["communication", "notifications"],
                tags: ["notifications", "outbox", "messaging"],
                chip: "REMOTE",
                borderColor: "#2563EB"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/NotificationPolicy",
                sourceCellName: "NotificationPolicyCell",
                displayName: "Notification Policy",
                purpose: "Varslingspolicy",
                purposeDescription: "Definer regler og policy for varslinger.",
                interests: ["notifications", "policy", "rules", "messaging"],
                summary: "Policy og regler for varslinger.",
                categoryPath: ["communication", "notifications"],
                tags: ["notifications", "policy", "rules"],
                chip: "REMOTE",
                borderColor: "#2563EB"
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/DeviceCallbackBridge",
                sourceCellName: "DeviceCallbackBridgeCell",
                displayName: "Device Callback Bridge",
                purpose: "Device callback-bridge",
                purposeDescription: "Bro for callback-flyt mellom enheter og tjenester.",
                interests: ["devices", "callbacks", "bridge", "integration"],
                summary: "Bridge for callback-flyt mellom enheter og tjenester.",
                categoryPath: ["devices", "integration"],
                tags: ["devices", "callbacks", "bridge", "integration"],
                chip: "REMOTE",
                borderColor: "#2563EB"
            )
        ]
    }

    nonisolated private static func stagingSurfaceTestingCatalogDescriptors(
        includeAgentOperatorSurfaces: Bool
    ) -> [StaticCatalogDescriptor] {
        var descriptors: [StaticCatalogDescriptor] = [
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/ArendalsukaParticipantProgram",
                sourceCellName: "ArendalsukaParticipantProgramCell",
                displayName: "Arendalsuka Participant Program",
                purpose: "Arendalsuka participant program",
                purposeDescription: "Remote staging surface for participant-facing Arendalsuka program navigation and event context.",
                interests: ["staging", "remote-surface", "arendalsuka", "participant", "program", "agenda", "navigation"],
                summary: "Participant program surface loaded from staging and rendered inside HAVEN.",
                categoryPath: ["staging", "arendalsuka", "participant"],
                tags: ["staging", "arendalsuka", "program", "participant"],
                menuSlots: [.upperMid, .lowerMid],
                chip: "STAGING",
                borderColor: "#2563EB",
                flowDriven: true,
                recommendedContexts: ["staging-test", "event", "program"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/ArendalsukaEventAtlas",
                sourceCellName: "ArendalsukaEventAtlasCell",
                displayName: "Arendalsuka Event Atlas",
                purpose: "Arendalsuka event atlas",
                purposeDescription: "Remote staging atlas for importing, inspecting and matching Arendalsuka event data.",
                interests: ["staging", "remote-surface", "arendalsuka", "event-atlas", "program", "matching"],
                summary: "Event atlas loaded from staging for Arendalsuka program inspection.",
                categoryPath: ["staging", "arendalsuka", "atlas"],
                tags: ["staging", "arendalsuka", "atlas", "events"],
                menuSlots: [.upperMid, .lowerMid],
                chip: "STAGING",
                borderColor: "#2563EB",
                flowDriven: true,
                recommendedContexts: ["staging-test", "event", "program-import"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/WorkItem",
                sourceCellName: "WorkItemCell",
                displayName: "HAVEN Workbench",
                purpose: "HAVEN project workbench",
                purposeDescription: "Remote staging project workbench spanning work items, portfolio, GitHub sync and idea/project flow.",
                interests: ["staging", "remote-surface", "haven", "workbench", "projects", "work-items", "portfolio", "github", "ideas"],
                summary: "Project and work-item workbench loaded from staging.",
                categoryPath: ["staging", "workbench", "projects"],
                tags: ["staging", "haven", "workbench", "projects"],
                menuSlots: [.upperMid, .lowerMid],
                chip: "STAGING",
                borderColor: "#0F766E",
                flowDriven: true,
                recommendedContexts: ["staging-test", "project-management", "workbench"],
                ioGetKeys: ["state", "syncStatus", "skeletonConfiguration"],
                ioSetKeys: ["refresh", "create", "update", "openProject"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell://staging.haven.digipomps.org/MermaidRenderer",
                sourceCellName: "MermaidRendererCell",
                displayName: "Mermaid Renderer",
                purpose: "Mermaid diagram renderer",
                purposeDescription: "Remote staging surface for writing, loading and rendering Mermaid diagrams inside HAVEN.",
                interests: ["staging", "remote-surface", "mermaid", "diagram", "graph", "markdown", "visualization"],
                summary: "Mermaid diagram renderer loaded from staging.",
                categoryPath: ["staging", "tools", "diagrams"],
                tags: ["staging", "mermaid", "diagram", "graph"],
                menuSlots: [.lowerMid, .lowerRight],
                chip: "STAGING",
                borderColor: "#7C3AED",
                flowDriven: true,
                recommendedContexts: ["staging-test", "diagramming", "knowledge-work"],
                ioGetKeys: ["state", "skeletonConfiguration"],
                ioSetKeys: ["source", "render", "loadMermaid"]
            )
        ]

        let requestedAdminNames: Set<String> = ["Admin Entry", "Admin Overview"]
        descriptors.append(contentsOf: remoteSupportCatalogDescriptors().filter {
            requestedAdminNames.contains($0.displayName)
        })

        if includeAgentOperatorSurfaces {
            let requestedAgentNames: Set<String> = ["Agent Setup Workbench", "Network Sentinel"]
            descriptors.append(contentsOf: optInLocalCatalogDescriptors().filter {
                requestedAgentNames.contains($0.displayName)
            })
        }

        return descriptors
    }

    nonisolated private static func optInLocalCatalogDescriptors() -> [StaticCatalogDescriptor] {
        guard BindingPersonalCopilotV1Policy.agentSetupWorkbenchEnabled else {
            return []
        }

        return [
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///AgentProvisioning",
                sourceCellName: "AgentProvisioningCell",
                displayName: "Agent Setup Workbench",
                purpose: "Local HAVEN agent install and review boundary",
                purposeDescription: "Install, start, connect and review `haven-agentd` from HAVEN without bypassing CellProtocol review boundaries.",
                interests: ["agent", "haven-agentd", "automation", "review", "cellprotocol", "launchd"],
                summary: "Operatorflate for lokal HAVEN-agent, control bridge og review queue i HAVEN.",
                categoryPath: ["operations", "agent"],
                tags: ["agent", "automation", "review", "launchd"],
                menuSlots: [.upperMid, .lowerRight],
                chip: "LOCAL OPERATOR",
                borderColor: "#0F766E",
                flowDriven: true,
                recommendedContexts: ["agent", "operator", "automation", "review"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///agent/network/sentinel",
                sourceCellName: "NetworkSentinelCell",
                displayName: "Network Sentinel",
                purpose: "Local network health sentinel",
                purposeDescription: "Operate haven-agentd's local network tracker over the loopback control bridge.",
                interests: ["agent", "haven-agentd", "network", "diagnostics", "security", "local"],
                summary: "Live nettverksstatus, historikk, grensesnitt, probe, pakkefangst og lytteverktøy fra lokal agent.",
                categoryPath: ["operations", "agent", "network"],
                tags: ["agent", "network", "diagnostics", "bridge", "local"],
                menuSlots: [.upperMid],
                chip: "LOCAL SENSOR",
                borderColor: "#0F766E",
                authRequired: true,
                policyHints: ["loopback-only", "local-control-bridge-token", "paired-operator"],
                flowDriven: true,
                editable: false,
                recommendedContexts: ["agent", "operator", "network", "diagnostics"]
            )
        ]
    }

    nonisolated private static func conferenceShowcaseCatalogDescriptors() -> [StaticCatalogDescriptor] {
        guard BindingPersonalCopilotV1Policy.conferenceShowcaseEnabled else {
            return []
        }

        return [
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///ConferenceConfigurationNavigator",
                sourceCellName: "ConferenceConfigurationNavigatorLocalCell",
                displayName: "Conference Codex Live Configurations",
                purpose: "Conference live configuration launcher",
                purposeDescription: "Last inn de kjørbare konferanse-CellConfigurationene som finnes i HAVEN akkurat na, uten aa gjette paa skjulte demo-ruter eller stale dokumentasjonsfiler.",
                interests: ["conference", "codex", "binding", "configurations", "launcher", "participant", "organizer", "sponsor", "public"],
                summary: "Operator-/demo-innngang til de faktiske konferanseflatene som kan lastes i HAVEN na.",
                categoryPath: ["experiences", "conference", "demo"],
                tags: ["conference", "codex", "binding", "launcher", "configurations"],
                menuSlots: [.upperMid, .upperRight, .lowerMid],
                chip: "LOCAL DEMO",
                borderColor: "#A77044",
                flowDriven: true,
                recommendedContexts: ["conference", "demo", "meeting", "binding"]
            ),
            StaticCatalogDescriptor(
                sourceCellEndpoint: "cell:///ConferenceConfigurationNavigator",
                sourceCellName: "ConferenceConfigurationNavigatorLocalCell",
                displayName: "Conference Claude Design Reference",
                purpose: "Conference Claude design reference",
                purposeDescription: "Loadbar designreferanse som oppsummerer den repo-lokale Claude-guiden og peker til de naavaerende konferanseflatene som matcher hver rolle best.",
                interests: ["conference", "claude", "design", "reference", "visual-direction", "binding"],
                summary: "Claude-designreferanse i HAVEN med tydelig mapping til dagens kjørbare conference-flater.",
                categoryPath: ["experiences", "conference", "design"],
                tags: ["conference", "claude", "design", "reference", "visual"],
                menuSlots: [.upperRight, .lowerRight],
                chip: "LOCAL REFERENCE",
                borderColor: "#5B4BC8",
                flowDriven: false,
                recommendedContexts: ["conference", "design-review", "meeting", "showcase"]
            )
        ]
    }

    nonisolated private static func staticCatalogTemplates(from descriptors: [StaticCatalogDescriptor]) -> [ScaffoldPurposeTemplate] {
        descriptors.map(staticCatalogTemplate(from:))
    }

    nonisolated private static func staticCatalogTemplate(from descriptor: StaticCatalogDescriptor) -> ScaffoldPurposeTemplate {
        let label = endpointLabel(for: descriptor.sourceCellEndpoint)
        var configuration = specializedWorkbenchConfiguration(for: descriptor) ?? descriptorWorkbenchConfiguration(
            for: descriptor,
            label: label
        )
        if configuration.skeleton == nil {
            configuration = referenceCardConfiguration(
            name: descriptor.displayName,
            endpoint: descriptor.sourceCellEndpoint,
            label: label,
            title: descriptor.displayName,
            subtitle: descriptor.summary,
            chip: descriptor.chip,
            borderColor: descriptor.borderColor,
            startKey: descriptor.startKey
            )
        }
        configuration.name = descriptor.displayName
        configuration.description = descriptor.summary
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: descriptor.sourceCellEndpoint,
            sourceCellName: descriptor.sourceCellName,
            purpose: descriptor.purpose,
            purposeDescription: descriptor.purposeDescription,
            interests: descriptor.interests,
            menuSlots: descriptor.menuSlots.map(\.rawValue)
        )

        return ScaffoldPurposeTemplate(
            sourceCellEndpoint: descriptor.sourceCellEndpoint,
            sourceCellName: descriptor.sourceCellName,
            purpose: descriptor.purpose,
            purposeDescription: descriptor.purposeDescription,
            interests: descriptor.interests,
            menuSlots: descriptor.menuSlots,
            goal: configuration,
            configuration: configuration,
            displayName: descriptor.displayName,
            summary: descriptor.summary,
            categoryPath: descriptor.categoryPath,
            tags: descriptor.tags,
            purposeRefs: ["purpose://\(catalogSlug(for: descriptor.purpose))"],
            interestRefs: descriptor.interests.map { "interest://\(catalogSlug(for: $0))" },
            supportedInsertionModes: [.root],
            supportedTargetKinds: descriptor.supportedTargetKinds,
            ioGetKeys: descriptor.ioGetKeys,
            ioSetKeys: descriptor.ioSetKeys,
            ioTopics: descriptor.ioTopics,
            ioFilterTypes: descriptor.ioFilterTypes,
            authRequired: descriptor.authRequired,
            policyHints: descriptor.policyHints,
            flowDriven: descriptor.flowDriven,
            editable: descriptor.editable,
            recommendedContexts: descriptor.recommendedContexts,
            forceRefreshExisting: descriptor.forceRefreshExisting,
            skipResolverLookup: descriptor.skipResolverLookup
        )
    }

    nonisolated private static func specializedWorkbenchConfiguration(for descriptor: StaticCatalogDescriptor) -> CellConfiguration? {
        switch descriptor.sourceCellEndpoint.lowercased() {
        case "cell:///personalidentity":
            return personalHomeMenuConfiguration()
        case "cell:///personalprofiledraft":
            return personalProfileMenuConfiguration()
        case "cell://staging.haven.digipomps.org/personalprofilepublisher":
            return personalPublicProfileMenuConfiguration()
        case "cell://staging.haven.digipomps.org/publicprofiledirectory":
            return personalPublicProfileDirectoryMenuConfiguration()
        case "cell://staging.haven.digipomps.org/personalmatchmaking":
            return personalMatchesMenuConfiguration()
        case "cell:///personalchathub":
            return personalInviteChatMenuConfiguration()
        case "cell:///personalchatclient":
            return personalInviteChatMenuConfiguration()
        case "cell://staging.haven.digipomps.org/personalchathub":
            return personalInviteChatMenuConfiguration(chatHubEndpoint: descriptor.sourceCellEndpoint)
        case "cell:///personalagendacontext":
            return personalAgendaContextMenuConfiguration()
        case "cell:///calendarstore":
            return personalCalendarStoreMenuConfiguration()
        case "cell:///personalmeetingintent", "cell://staging.haven.digipomps.org/personalmeetingcoordinator":
            return personalMeetingIntentMenuConfiguration()
        case "cell:///personalprivacyaudit":
            return personalPrivacyAuditMenuConfiguration()
        case "cell://staging.haven.digipomps.org/personalcopilotconfigurationcatalog":
            return personalCopilotCatalogMenuConfiguration()
        case "cell:///workflowstudio":
            return workflowStudioForPersonalCopilotConfiguration()
        case "cell:///conferenceuirouter", "cell://staging.haven.digipomps.org/conferenceuirouter":
            return conferenceMVPWorkbenchConfiguration(
                endpoint: descriptor.sourceCellEndpoint,
                displayName: descriptor.displayName,
                summary: descriptor.summary
            )
        case "cell:///conferenceconfigurationnavigator":
            if descriptor.displayName == "Conference Claude Design Reference" {
                return conferenceClaudeDesignReferenceMenuConfiguration()
            }
            return conferenceCodexLiveConfigurationsMenuConfiguration()
        case "cell:///conferencedemolauncher":
            return conferenceDemoLauncherWorkbenchConfiguration()
        case "cell:///conferenceparticipantpreviewshell", "cell://staging.haven.digipomps.org/conferenceparticipantpreviewshell":
            if descriptor.displayName == "Conference AI Assistant" {
                return conferenceAIAssistantWorkbenchConfiguration(
                    conferenceEndpoint: "cell:///ConferenceParticipantPreviewShell",
                    aiEndpoint: "cell:///ConferenceAIAssistantGatewayProxy",
                    displayName: descriptor.displayName,
                    summary: descriptor.summary
                )
            }
            return conferenceParticipantPortalWorkbenchConfiguration(
                endpoint: descriptor.sourceCellEndpoint,
                displayName: descriptor.displayName,
                summary: descriptor.summary
            )
        case "cell:///conferenceadminshell",
             "cell://staging.haven.digipomps.org/conferenceadminshell",
             "cell:///conferenceadminpreviewshell",
             "cell://staging.haven.digipomps.org/conferenceadminpreviewshell":
            return conferenceAdminWorkbenchConfiguration(
                endpoint: descriptor.sourceCellEndpoint,
                displayName: descriptor.displayName,
                summary: descriptor.summary
            )
        case "cell:///conferencepublicshell",
             "cell://staging.haven.digipomps.org/conferencepublicshell",
             "cell:///conferencepublicshellfixture":
            return conferencePublicWorkbenchConfiguration(
                endpoint: descriptor.sourceCellEndpoint,
                displayName: descriptor.displayName,
                summary: descriptor.summary
            )
        case "cell:///conferencesponsorshell",
             "cell://staging.haven.digipomps.org/conferencesponsorshell",
             "cell:///conferencesponsorshellfixture":
            return conferenceSponsorWorkbenchConfiguration(
                endpoint: descriptor.sourceCellEndpoint,
                displayName: descriptor.displayName,
                summary: descriptor.summary
            )
        case "cell:///agentprovisioning":
            return agentSetupWorkbenchConfiguration(
                displayName: descriptor.displayName,
                summary: descriptor.summary
            )
        case "cell:///agent/network/sentinel":
            return networkSentinelWorkbenchConfiguration(
                displayName: descriptor.displayName,
                summary: descriptor.summary
            )
        case "cell:///chat", "cell://staging.haven.digipomps.org/chat":
            return scaffoldChatWorkbenchConfiguration(
                endpoint: descriptor.sourceCellEndpoint,
                displayName: descriptor.displayName,
                summary: descriptor.summary
            )
        case "cell:///perspective":
            return perspectiveWorkbenchConfiguration()
        case "cell:///entityanchor":
            return entityAnchorWorkbenchConfiguration()
        case "cell:///vault":
            if descriptor.displayName == "Vault / Ideas" {
                return personalVaultIdeasMenuConfiguration()
            }
            return vaultWorkbenchConfiguration()
        case "cell:///porthole":
            return portholeWorkbenchConfiguration()
        case "cell:///trustedissuers":
            return trustedIssuersWorkbenchConfiguration()
        case "cell:///commonsresolver":
            return commonsResolverWorkbenchConfiguration()
        case "cell:///commonstaxonomy":
            return commonsTaxonomyWorkbenchConfiguration()
        case "cell:///folderwatch":
            return folderWatchWorkbenchConfiguration()
        case "cell:///graphindex":
            return graphIndexWorkbenchConfiguration()
        case "cell:///eventemitter":
            return signalWorkbenchConfiguration()
        case "cell:///appleintelligence":
            return appleIntelligenceLandingConfiguration()
        case "cell:///entityscanner":
            return entityScannerWorkbenchConfiguration()
        default:
            return nil
        }
    }

    nonisolated private static func endpointLabel(for endpoint: String) -> String {
        let raw: String = {
            guard let url = URL(string: endpoint) else { return "cell" }
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard let last = path.split(separator: "/").last else { return "cell" }
            return String(last)
        }()

        let sanitized = raw.filter { $0.isLetter || $0.isNumber }
        guard !sanitized.isEmpty else { return "cell" }
        return sanitized.prefix(1).lowercased() + String(sanitized.dropFirst())
    }

    nonisolated private static func catalogSlug(for text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "æ", with: "ae")
            .replacingOccurrences(of: "ø", with: "o")
            .replacingOccurrences(of: "å", with: "a")
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    nonisolated private static func descriptorWorkbenchConfiguration(
        for descriptor: StaticCatalogDescriptor,
        label: String
    ) -> CellConfiguration {
        var configuration = CellConfiguration(name: descriptor.displayName)
        configuration.description = descriptor.summary

        var reference = CellReference(endpoint: descriptor.sourceCellEndpoint, label: label)
        if let startKey = descriptor.startKey {
            reference.addKeyAndValue(KeyValue(key: startKey))
        }
        configuration.addReference(reference)

        let isRemote = descriptor.sourceCellEndpoint.lowercased().hasPrefix("cell://")

        let shellCard = modifier {
            $0.padding = 10
            $0.background = "#F8FAFC"
            $0.cornerRadius = 16
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }
        let heroCard = modifier {
            $0.padding = 14
            $0.background = isRemote ? "#EFF6FF" : "#F0FDF4"
            $0.cornerRadius = 16
            $0.borderWidth = 1
            $0.borderColor = descriptor.borderColor
            $0.shadowRadius = 6
            $0.shadowY = 2
            $0.shadowColor = "#0F172A18"
        }
        let sectionCard = modifier {
            $0.padding = 10
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#D7E0F0"
        }
        let chipModifier = modifier {
            $0.padding = 6
            $0.background = "#E2E8F0"
            $0.cornerRadius = 999
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
            $0.fontSize = 11
            $0.fontWeight = "semibold"
        }
        let primaryButton = modifier {
            $0.padding = 8
            $0.background = "#DBEAFE"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#60A5FA"
        }

        func infoText(_ text: String, color: String = "#334155", size: Double = 12) -> SkeletonText {
            var label = SkeletonText(text: text)
            label.modifiers = modifier {
                $0.foregroundColor = color
                $0.fontSize = size
                $0.lineLimit = 3
            }
            return label
        }

        func sectionTitle(_ text: String) -> SkeletonText {
            var label = SkeletonText(text: text)
            label.modifiers = modifier {
                $0.foregroundColor = "#0F172A"
                $0.fontWeight = "semibold"
                $0.fontSize = 12
            }
            return label
        }

        let tagLine = (descriptor.tags.isEmpty ? ["none"] : descriptor.tags).joined(separator: ", ")
        let interestLine = (descriptor.interests.isEmpty ? ["none"] : descriptor.interests).joined(separator: ", ")
        let contextLine = (descriptor.recommendedContexts?.isEmpty == false ? descriptor.recommendedContexts! : ["general"]).joined(separator: ", ")
        let getLine = (descriptor.ioGetKeys?.isEmpty == false ? descriptor.ioGetKeys! : ["No explicit get keys registered"]).joined(separator: ", ")
        let setLine = (descriptor.ioSetKeys?.isEmpty == false ? descriptor.ioSetKeys! : ["No explicit set keys registered"]).joined(separator: ", ")
        let topicLine = (descriptor.ioTopics?.isEmpty == false ? descriptor.ioTopics! : ["No explicit flow topics registered"]).joined(separator: ", ")
        let policyLine = (descriptor.policyHints?.isEmpty == false ? descriptor.policyHints! : ["Private policy requirements are not declared in catalog metadata"]).joined(separator: " | ")
        let availabilityLine = isRemote
            ? "Dette er en remote/staging-konfigurasjon. Den er oppdagbar i katalogen hele tiden, men full runtime-funksjon avhenger av at remote cell er oppe."
            : "Dette er en lokal runtime-konfigurasjon. Den skal virke uten staging sa lenge HAVEN registrerer cellen lokalt."
        let isFlowDriven = descriptor.flowDriven ?? false
        let requiresAuth = descriptor.authRequired ?? false
        let behaviorLine = isFlowDriven
            ? "Flow-driven: denne cellen forventes aa sende events/topics under bruk."
            : "State/control-driven: denne cellen brukes hovedsakelig via direkte get/set."

        var titleText = SkeletonText(text: descriptor.displayName)
        titleText.modifiers = modifier {
            $0.fontStyle = "title3"
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var purposeText = SkeletonText(text: descriptor.purpose)
        purposeText.modifiers = modifier {
            $0.foregroundColor = "#1D4ED8"
            $0.fontWeight = "semibold"
            $0.fontSize = 12
            $0.lineLimit = 2
        }

        var descriptionText = SkeletonText(text: descriptor.purposeDescription)
        descriptionText.modifiers = modifier {
            $0.foregroundColor = "#334155"
            $0.fontSize = 12
            $0.lineLimit = 3
        }

        var endpointText = SkeletonText(text: descriptor.sourceCellEndpoint)
        endpointText.modifiers = modifier {
            $0.foregroundColor = "#64748B"
            $0.fontSize = 11
            $0.lineLimit = 2
        }

        var sourceCellText = SkeletonText(text: "Source cell: \(descriptor.sourceCellName)")
        sourceCellText.modifiers = modifier {
            $0.foregroundColor = "#475569"
            $0.fontSize = 11
        }

        var chipText = SkeletonText(text: descriptor.chip)
        chipText.modifiers = chipModifier

        var runtimeChip = SkeletonText(text: isRemote ? "REMOTE" : "LOCAL")
        runtimeChip.modifiers = chipModifier

        var flowChip = SkeletonText(text: isFlowDriven ? "FLOW" : "CONTROL")
        flowChip.modifiers = chipModifier

        var authChip = SkeletonText(text: requiresAuth ? "AUTH" : "OPEN")
        authChip.modifiers = chipModifier

        var launchButton = SkeletonButton(
            keypath: descriptor.startKey.map { "\(label).\($0)" } ?? "",
            label: descriptor.startKey == nil ? "Launch handled by load" : "Run \(descriptor.startKey!)",
            payload: .bool(true)
        )
        launchButton.modifiers = primaryButton

        var hero = SkeletonVStack(elements: [
            .HStack(SkeletonHStack(elements: [.VStack(SkeletonVStack(elements: [.Text(titleText), .Text(purposeText)])), .Spacer(SkeletonSpacer()), .Text(chipText)])),
            .Text(descriptionText),
            .Text(sourceCellText),
            .Text(endpointText),
            .HStack(SkeletonHStack(elements: [.Text(runtimeChip), .Text(flowChip), .Text(authChip)]))
        ])
        if descriptor.startKey != nil {
            hero.elements.append(SkeletonElement.HStack(SkeletonHStack(elements: [.Button(launchButton)])))
        }
        hero.modifiers = heroCard

        var useCaseSection = SkeletonSection(
            header: .Text(sectionTitle("Hva dette verktøyet løser")),
            content: [
                .Text(infoText(descriptor.summary)),
                .Text(infoText("Interesser: \(interestLine)")),
                .Text(infoText("Tags: \(tagLine)")),
                .Text(infoText("Contexts: \(contextLine)"))
            ]
        )
        useCaseSection.modifiers = sectionCard

        var ioSection = SkeletonSection(
            header: .Text(sectionTitle("Kontroll-lag / IO-signatur")),
            content: [
                .Text(infoText("Get: \(getLine)")),
                .Text(infoText("Set: \(setLine)")),
                .Text(infoText("Topics: \(topicLine)")),
                .Text(infoText(behaviorLine))
            ]
        )
        ioSection.modifiers = sectionCard

        var runtimeStatusTitle = SkeletonText(text: "Status")
        runtimeStatusTitle.modifiers = modifier {
            $0.foregroundColor = "#0F172A"
            $0.fontWeight = "semibold"
            $0.fontSize = 11
        }
        var runtimeStatus = SkeletonText(url: URL(string: "cell:///Porthole/\(label).status")!)
        runtimeStatus.modifiers = modifier {
            $0.foregroundColor = "#334155"
            $0.fontSize = 11
            $0.lineLimit = 4
        }

        var runtimeStateTitle = SkeletonText(text: "State")
        runtimeStateTitle.modifiers = modifier {
            $0.foregroundColor = "#0F172A"
            $0.fontWeight = "semibold"
            $0.fontSize = 11
        }
        var runtimeState = SkeletonText(url: URL(string: "cell:///Porthole/\(label).state")!)
        runtimeState.modifiers = modifier {
            $0.foregroundColor = "#334155"
            $0.fontSize = 11
            $0.lineLimit = 8
        }

        var runtimeSection = SkeletonSection(
            header: .Text(sectionTitle("Direkte runtime-inspeksjon")),
            content: [
                .Text(infoText("Denne seksjonen leser direkte fra `status` og `state` hvis cellen eksponerer disse nøklene.", color: "#475569")),
                .Text(runtimeStatusTitle),
                .Text(runtimeStatus),
                .Text(runtimeStateTitle),
                .Text(runtimeState)
            ]
        )
        runtimeSection.modifiers = sectionCard

        var availabilitySection = SkeletonSection(
            header: .Text(sectionTitle("Tilgjengelighet og policy")),
            content: [
                .Text(infoText(availabilityLine)),
                .Text(infoText(policyLine, color: "#92400E"))
            ]
        )
        availabilitySection.modifiers = sectionCard

        var root = SkeletonVStack(elements: [
            .VStack(hero),
            .Section(useCaseSection),
            .Section(ioSection),
            .Section(runtimeSection),
            .Section(availabilitySection)
        ])
        root.modifiers = shellCard

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.background = isRemote ? "#F8FBFF" : "#F8FAFC"
        }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    private static func entityScannerTemplate(
        purpose: String,
        purposeDescription: String,
        interests: [String],
        menuSlots: [MenuSlot],
        goal: CellConfiguration,
        configuration: CellConfiguration,
        displayName: String,
        summary: String
    ) -> ScaffoldPurposeTemplate {
        let interestRefs = interests.map { "interest://\($0)" }
        let purposeSlug = purpose
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "æ", with: "ae")
            .replacingOccurrences(of: "ø", with: "o")
            .replacingOccurrences(of: "å", with: "a")

        return ScaffoldPurposeTemplate(
            sourceCellEndpoint: "cell:///EntityScanner",
            sourceCellName: "EntityScannerCell",
            purpose: purpose,
            purposeDescription: purposeDescription,
            interests: interests,
            menuSlots: menuSlots,
            goal: goal,
            configuration: configuration,
            displayName: displayName,
            summary: summary,
            categoryPath: ["identity", "nearby", "entity-scanner"],
            tags: ["entity", "scanner", "multipeer", "uwb", "proofs", "json-export"],
            purposeRefs: ["purpose://\(purposeSlug)"],
            interestRefs: interestRefs,
            supportedInsertionModes: [.root],
            supportedTargetKinds: ["menu", "porthole", "tool", "test"],
            ioGetKeys: ["capabilities", "encounters", "verificationMethods"],
            ioSetKeys: ["start", "stop", "invite", "requestContact", "acceptContact", "exportEncounter", "exportEncounterJSON"],
            ioTopics: [
                "scanner.capabilities",
                "scanner.status",
                "scanner.found",
                "scanner.connected",
                "scanner.proximity",
                "scanner.contact.outgoing",
                "scanner.contact.received",
                "scanner.encounter.saved",
                "scanner.encounter.exported",
                "scanner.encounter.jsonExported"
            ],
            ioFilterTypes: ["content", "event"],
            authRequired: false,
            policyHints: [
                "Private key stays on device.",
                "Works without UWB by falling back to MultipeerConnectivity.",
                "Encounter proofs are stored under EntityAnchor proofs.encounters."
            ],
            flowDriven: true,
            editable: true,
            recommendedContexts: ["conference", "meetup", "nearby pairing", "identity expansion"],
            skipResolverLookup: true
        )
    }

    nonisolated static func entityScannerWorkbenchConfiguration() -> CellConfiguration {
        entityScannerToolConfiguration(
            name: "Entity Scanner",
            description: "Judged-proximity scanner for relevant nearby entities, signed identity exchange, saved relations, encounter proofs and JSON export.",
            title: "Entity Scanner",
            subtitle: "Start scanning explicitly, inspect only relevant nearby entities, then invite, exchange signed identities and hand off to chat after relation persistence.",
            checklist: [
                "Start scanner only when you want live nearby discovery.",
                "Use capability/status chips to distinguish UWB precision from BT/MPC-only proximity.",
                "Treat low and nearby-only hits as hidden by default; use Show lower matches only for audit.",
                "Openly published profile data must come from the public profile reference, not from proximity.",
                "Accept + exchange completes signed identity exchange, relation persistence and encounter proof storage before chat."
            ],
            includePerspectiveSection: true
        )
    }

    nonisolated static func entityScannerTestHelperConfiguration() -> CellConfiguration {
        entityScannerToolConfiguration(
            name: "Entity Scanner Test Helper",
            description: "Manuell test-hjelper for discovery, signeringsflyt, Perspective-snapshot og encounter storage.",
            title: "Entity Scanner Test Helper",
            subtitle: "Viser local Perspective, live scanner-events, encounter proofs og reset/export handling for test av to enheter.",
            checklist: [
                "Bruk denne for manuell validering av discovery og signed contact flow.",
                "Perspective-listen viser lokal kontekst som blir brukt i request/accept.",
                "Encounter-listen lar deg eksportere proof og copy json uten aa forlate skjermen."
            ],
            includePerspectiveSection: true
        )
    }

    nonisolated static func entityScannerPairingChecklistConfiguration() -> CellConfiguration {
        entityScannerToolConfiguration(
            name: "Entity Scanner Pairing Checklist",
            description: "Kort QA-skjerm for to-enhets test med og uten UWB.",
            title: "Entity Scanner Pairing Checklist",
            subtitle: "Fokusert pairing-view for konferanse/demo: capabilities, live checkpoints og encounter-verifisering.",
            checklist: [
                "1. Start scanner pa begge enheter.",
                "2. Kontroller at precisionMode er 'uwb' eller 'multipeer-only'.",
                "3. Bekreft scanner.found og opprett kontakt.",
                "4. Bekreft scanner.encounter.saved og exporter JSON-bevis."
            ],
            includePerspectiveSection: false
        )
    }

    nonisolated static func scaffoldChatWorkbenchMenuConfiguration(endpoint: String = "cell://staging.haven.digipomps.org/Chat") -> CellConfiguration {
        scaffoldChatWorkbenchConfiguration(
            endpoint: endpoint,
            displayName: "Chat",
            summary: "Direktemeldinger fra staging med deltakere, tråder og samme samtale på tvers av klienter."
        )
    }

    nonisolated static func conferenceMVPWorkbenchMenuConfiguration(endpoint: String = "cell://staging.haven.digipomps.org/ConferenceUIRouter") -> CellConfiguration {
        conferenceMVPWorkbenchConfiguration(
            endpoint: endpoint,
            displayName: "Conference",
            summary: "Agenda, matchmaking og møtescheduling fra conference-routeren på staging."
        )
    }

    nonisolated static func conferenceParticipantPortalWorkbenchConfiguration(endpoint: String = "cell:///ConferenceParticipantPreviewShell") -> CellConfiguration {
        conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: endpoint,
            displayName: "Conference Participant Portal Dashboard",
            summary: "Participant-shell med agenda, anbefalinger og meeting timeline over lokal preview-wrapper i HAVEN."
        )
    }

    nonisolated static func conferenceDemoLauncherWorkbenchConfiguration() -> CellConfiguration {
        conferenceDemoLauncherWorkbenchConfiguration(
            displayName: "Conference Demo Launcher",
            summary: "Deterministisk launcher for konferansedemoen i HAVEN, tett opp mot CellScaffold sin demo-historie."
        )
    }

    nonisolated static func conferenceIdentityLinkWorkbenchConfiguration() -> CellConfiguration {
        conferenceIdentityLinkWorkbenchConfiguration(
            displayName: "Conference Scaffold Setup & Identity Link",
            summary: "Mobil inngang for scaffold setup, QR/deep-link challenge review og lokal key-possession før approval."
        )
    }

    nonisolated static func conferenceNearbyRadarWorkbenchConfiguration(
        participantEndpoint: String = "cell:///ConferenceParticipantPreviewShell"
    ) -> CellConfiguration {
        conferenceNearbyRadarWorkbenchConfiguration(
            participantEndpoint: participantEndpoint,
            displayName: "Conference Nearby Radar · Full oversikt",
            summary: "HAVEN-lokal nearby radar med scanner, retningssignal og conference follow-up-chat i en større arbeidsflate."
        )
    }

    nonisolated static func conferenceNearbyParticipantWorkbenchConfiguration(
        participantEndpoint: String = "cell:///ConferenceParticipantPreviewShell"
    ) -> CellConfiguration {
        conferenceNearbyParticipantWorkbenchConfiguration(
            participantEndpoint: participantEndpoint,
            displayName: "Valgt nearby-deltager · Profilflate",
            summary: "Valgt nearby-deltager med profil, oppfølging og chat i én conference-konsistent arbeidsflate."
        )
    }

    nonisolated static func conferenceParticipantChatWorkbenchConfiguration(
        participantEndpoint: String = "cell:///ConferenceParticipantPreviewShell"
    ) -> CellConfiguration {
        conferenceParticipantChatWorkbenchConfiguration(
            participantEndpoint: participantEndpoint,
            displayName: "Conference Participant Chat",
            summary: "Conference participant chat aligned with ConferenceChatLaunch for free-text follow-up, shared messages and explicit next steps."
        )
    }

    nonisolated static func conferenceAIAssistantWorkbenchConfiguration(
        conferenceEndpoint: String = "cell:///ConferenceParticipantPreviewShell",
        aiEndpoint: String = "cell:///ConferenceAIAssistantGatewayProxy"
    ) -> CellConfiguration {
        conferenceAIAssistantWorkbenchConfiguration(
            conferenceEndpoint: conferenceEndpoint,
            aiEndpoint: aiEndpoint,
            displayName: "Conference AI Assistant",
            summary: "Conference copilot som kombinerer participant preview-state med AIGateway i samme arbeidsflate."
        )
    }

    nonisolated static func conferenceAdminWorkbenchConfiguration(endpoint: String = "cell:///ConferenceAdminPreviewShell") -> CellConfiguration {
        conferenceAdminWorkbenchConfiguration(
            endpoint: endpoint,
            displayName: "Conference Control Tower",
            summary: "Organizer control tower aligned with the current ConferenceAdminShell contract via lokal preview-wrapper i HAVEN."
        )
    }

    nonisolated static func conferencePublicWorkbenchConfiguration(endpoint: String = "cell:///ConferencePublicShellFixture") -> CellConfiguration {
        conferencePublicWorkbenchConfiguration(
            endpoint: endpoint,
            displayName: "Conference Public Surface",
            summary: "Public shell aligned with the current ConferencePublicShell contract for landing, publication/access, tracks, sessions, people and facilities."
        )
    }

    nonisolated static func conferenceSponsorWorkbenchConfiguration(endpoint: String = "cell:///ConferenceSponsorShellFixture") -> CellConfiguration {
        conferenceSponsorWorkbenchConfiguration(
            endpoint: endpoint,
            displayName: "Conference Sponsor Follow-up",
            summary: "Sponsor shell med lead inbox, consent, unlock og retention via lokal demo-fixture i HAVEN."
        )
    }

    nonisolated static func agentSetupWorkbenchMenuConfiguration() -> CellConfiguration {
        agentSetupWorkbenchConfiguration(
            displayName: "Agent Setup Workbench",
            summary: "Install, start, connect and review the local HAVEN agent directly from HAVEN."
        )
    }

    nonisolated static func agentSetupWorkbenchConfiguration() -> CellConfiguration {
        agentSetupWorkbenchMenuConfiguration()
    }

    nonisolated static func networkSentinelWorkbenchConfiguration() -> CellConfiguration {
        networkSentinelWorkbenchConfiguration(
            displayName: "Network Sentinel",
            summary: "Live nettverksstatus, historikk, grensesnitt, probe, pakkefangst og lytteverktøy fra lokal agent."
        )
    }

    nonisolated static func catalogWorkbenchMenuConfiguration() -> CellConfiguration {
        var configuration = catalogWorkbenchConfiguration()
        configuration.name = "Catalog"
        configuration.description = "Søk, sync og vedlikehold av konfigurasjoner i ConfigurationCatalog."
        return configuration
    }

    nonisolated static func perspectiveWorkbenchMenuConfiguration() -> CellConfiguration {
        var configuration = perspectiveWorkbenchConfiguration()
        configuration.name = "Perspective"
        configuration.description = "Lokal kontekst for formaal, interesser og menyvalg."
        return configuration
    }

    nonisolated static func entityAnchorWorkbenchMenuConfiguration() -> CellConfiguration {
        var configuration = entityAnchorWorkbenchConfiguration()
        configuration.name = "Entity Anchor"
        configuration.description = "Entiteter, relasjoner og proofs lagret lokalt i EntityAnchor."
        return configuration
    }

    nonisolated static func vaultWorkbenchMenuConfiguration() -> CellConfiguration {
        var configuration = vaultWorkbenchConfiguration()
        configuration.name = "Vault"
        configuration.description = "Notater, lenker og state i lokal Vault."
        return configuration
    }

    nonisolated static func trustedIssuersWorkbenchMenuConfiguration() -> CellConfiguration {
        var configuration = trustedIssuersWorkbenchConfiguration()
        configuration.name = "Trusted Issuers"
        configuration.description = "Policy, issuers og attestation-regler for trusted issuer-flyten."
        return configuration
    }

    nonisolated static func portholeWorkbenchMenuConfiguration() -> CellConfiguration {
        var configuration = portholeWorkbenchConfiguration()
        configuration.name = "Porthole"
        configuration.description = "Last inn flater, se menyer og inspiser tidligere layouts."
        return configuration
    }

    nonisolated static func folderWatchWorkbenchMenuConfiguration() -> CellConfiguration {
        var configuration = folderWatchWorkbenchConfiguration()
        configuration.name = "Folder Watch"
        configuration.description = "Overvåk mapper og følg siste filsystem-events direkte i UI."
        return configuration
    }

    nonisolated static func graphIndexWorkbenchMenuConfiguration() -> CellConfiguration {
        var configuration = graphIndexWorkbenchConfiguration()
        configuration.name = "Graph Index"
        configuration.description = "Reindekser demo-grafen og inspiser nabolag, inn- og ut-kanter."
        return configuration
    }

    nonisolated static func workflowStudioWorkbenchMenuConfiguration() -> CellConfiguration {
        WorkflowStudioCell.menuConfiguration()
    }

    nonisolated static func workflowStudioWorkbenchConfiguration() -> CellConfiguration {
        WorkflowStudioCell.workbenchConfiguration()
    }

    nonisolated static func workflowStudioPortableMenuConfiguration() -> CellConfiguration {
        WorkflowStudioCell.portableMenuConfiguration()
    }

    nonisolated static func workflowStudioPortableConfiguration() -> CellConfiguration {
        WorkflowStudioCell.portableConfiguration()
    }

    nonisolated static func personalCopilotV1MenuConfigurations() -> [CellConfiguration] {
        var configurations = [
            personalHomeMenuConfiguration(),
            personalProfileMenuConfiguration(),
            personalPublicProfileMenuConfiguration(),
            personalPublicProfileDirectoryMenuConfiguration(),
            personalMatchesMenuConfiguration(),
            personalInviteChatMenuConfiguration(),
            personalAgendaContextMenuConfiguration(),
            personalCalendarStoreMenuConfiguration(),
            personalVaultIdeasMenuConfiguration(),
            personalMeetingIntentMenuConfiguration(),
            personalPrivacyAuditMenuConfiguration(),
            personalCopilotCatalogMenuConfiguration(),
            appleIntelligenceLandingForPersonalCopilotConfiguration(),
            entityScannerForPersonalCopilotConfiguration(),
            workflowStudioForPersonalCopilotConfiguration()
        ]

        if BindingPersonalCopilotV1Policy.agentSetupWorkbenchEnabled {
            configurations.append(agentSetupWorkbenchMenuConfiguration())
        }

        return configurations
    }

    nonisolated static func stagingSurfaceTestingMenuConfigurations(
        includeAgentOperatorSurfaces: Bool = BindingPersonalCopilotV1Policy.agentSetupWorkbenchEnabled
    ) -> [CellConfiguration] {
        staticCatalogTemplates(
            from: stagingSurfaceTestingCatalogDescriptors(
                includeAgentOperatorSurfaces: includeAgentOperatorSurfaces
            )
        )
        .map(\.configuration)
    }

    nonisolated private static func conferenceConfigurationNavigatorReference(
        label: String = "conferenceNavigator"
    ) -> CellReference {
        var reference = CellReference(
            endpoint: "cell:///ConferenceConfigurationNavigator",
            subscribeFeed: false,
            label: label
        )
        reference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        return reference
    }

    nonisolated private static func conferenceShowcaseStaticText(
        _ text: String,
        fontSize: Double? = nil,
        fontWeight: String? = nil,
        foregroundColor: String? = ConferenceSurfacePalette.textMuted,
        lineLimit: Int? = nil
    ) -> SkeletonElement {
        var label = SkeletonText(text: text)
        label.modifiers = modifier {
            $0.fontSize = fontSize
            $0.fontWeight = fontWeight
            $0.foregroundColor = foregroundColor
            $0.lineLimit = lineLimit
        }
        return .Text(label)
    }

    nonisolated private static func conferenceShowcaseKeyText(
        _ keypath: String,
        fontSize: Double? = nil,
        fontWeight: String? = nil,
        foregroundColor: String? = ConferenceSurfacePalette.textMain,
        lineLimit: Int? = nil
    ) -> SkeletonElement {
        var label = SkeletonText(keypath: keypath)
        label.modifiers = modifier {
            $0.fontSize = fontSize
            $0.fontWeight = fontWeight
            $0.foregroundColor = foregroundColor
            $0.lineLimit = lineLimit
        }
        return .Text(label)
    }

    nonisolated private static func conferenceShowcaseSection(
        _ title: String,
        content: SkeletonElementList,
        background: String = ConferenceSurfacePalette.shellStrong,
        borderColor: String = ConferenceSurfacePalette.strokeStrong
    ) -> SkeletonElement {
        var header = SkeletonText(text: title)
        header.modifiers = modifier {
            $0.fontSize = 16
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.textMain
        }

        var section = SkeletonSection(header: .Text(header), content: content)
        section.modifiers = conferenceCardModifier(
            padding: 14,
            background: background,
            borderColor: borderColor,
            cornerRadius: 18,
            shadowRadius: 6,
            shadowY: 2
        )
        return .Section(section)
    }

    nonisolated private static func conferenceShowcaseActionButton(
        _ referenceLabel: String = "conferenceNavigator",
        actionKeypath: String,
        label: String,
        background: String = ConferenceSurfacePalette.accentWarmSoft,
        borderColor: String = ConferenceSurfacePalette.strokeStrong,
        foregroundColor: String = ConferenceSurfacePalette.textMain
    ) -> SkeletonElement {
        let actionObject: Object = [
            "keypath": .string(actionKeypath),
            "payload": .bool(true)
        ]
        var button = SkeletonButton(
            keypath: "\(referenceLabel).dispatchAction",
            label: label,
            payload: .object(actionObject)
        )
        button.modifiers = conferenceButtonModifier(
            background: background,
            borderColor: borderColor,
            foregroundColor: foregroundColor
        )
        return .Button(button)
    }

    nonisolated static func conferenceCodexLiveConfigurationsMenuConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Conference Codex Live Configurations")
        configuration.description = "Launcher for de kjørbare konferanse-CellConfigurationene som finnes i HAVEN akkurat na."
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: "cell:///ConferenceConfigurationNavigator",
            sourceCellName: "ConferenceConfigurationNavigatorLocalCell",
            purpose: "Conference live configuration launcher",
            purposeDescription: "Last inn de faktiske konferansekonfigurasjonene som finnes i HAVEN, med raske entry points for public, participant, AI assistant, control tower, sponsor, nearby og chat.",
            interests: ["conference", "codex", "binding", "configurations", "launcher", "participant", "organizer", "public", "sponsor"],
            menuSlots: ["upperMid", "lowerMid"]
        )
        configuration.addReference(conferenceConfigurationNavigatorReference())

        var root = SkeletonVStack(elements: [
            conferenceShowcaseSection(
                "Conference Configurations",
                content: [
                    conferenceShowcaseStaticText(
                        "Dette er de konferanseflatene vi faktisk kan laste i HAVEN na. Bruk denne som demo-/operatorinngang i stedet for aa jakte paa skjulte testveier.",
                        fontSize: 13,
                        foregroundColor: ConferenceSurfacePalette.textMuted,
                        lineLimit: 4
                    ),
                    conferenceShowcaseStaticText(
                        "Knappene under aapner neste conference-flate i HAVEN, slik at hele vinduet bytter til riktig CellConfiguration.",
                        fontSize: 12,
                        foregroundColor: ConferenceSurfacePalette.accentCool,
                        lineLimit: 3
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            conferenceShowcaseActionButton(
                                actionKeypath: "navigator.openConferenceDemoLauncher",
                                label: "Open demo launcher"
                            ),
                            conferenceShowcaseActionButton(
                                actionKeypath: "navigator.openConferenceClaudeDesignReference",
                                label: "Open Claude reference",
                                background: "#EFEDFF",
                                borderColor: "#5B4BC8"
                            )
                        ])
                    )
                ],
                background: ConferenceSurfacePalette.shellStrong,
                borderColor: ConferenceSurfacePalette.strokeStrong
            ),
            conferenceShowcaseSection(
                "Core Surfaces",
                content: [
                    conferenceShowcaseStaticText(
                        "Start her hvis du vil vise den faktiske conference-opplevelsen i HAVEN.",
                        fontSize: 12,
                        foregroundColor: ConferenceSurfacePalette.textMuted,
                        lineLimit: 3
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            conferenceShowcaseActionButton(
                                actionKeypath: "navigator.openConferenceParticipantPortal",
                                label: "Participant portal",
                                background: "#EFEDFF",
                                borderColor: "#5B4BC8"
                            ),
                            conferenceShowcaseActionButton(
                                actionKeypath: "navigator.openConferenceAIAssistant",
                                label: "AI assistant",
                                background: "#EFEDFF",
                                borderColor: "#5B4BC8"
                            )
                        ])
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            conferenceShowcaseActionButton(
                                actionKeypath: "navigator.openConferenceControlTower",
                                label: "Control tower"
                            ),
                            conferenceShowcaseActionButton(
                                actionKeypath: "navigator.openConferencePublicSurface",
                                label: "Public surface",
                                background: ConferenceSurfacePalette.shellMuted,
                                borderColor: ConferenceSurfacePalette.stroke
                            )
                        ])
                    )
                ],
                background: ConferenceSurfacePalette.shell,
                borderColor: ConferenceSurfacePalette.stroke
            ),
            conferenceShowcaseSection(
                "Supporting Surfaces",
                content: [
                    conferenceShowcaseStaticText(
                        "Disse flatene er nyttige når du vil zoome inn paa sponsor, nearby eller chat-bevis.",
                        fontSize: 12,
                        foregroundColor: ConferenceSurfacePalette.textMuted,
                        lineLimit: 3
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            conferenceShowcaseActionButton(
                                actionKeypath: "navigator.openConferenceSponsorFollowUp",
                                label: "Sponsor follow-up",
                                background: "#DCEEEB",
                                borderColor: "#0B7A5A"
                            ),
                            conferenceShowcaseActionButton(
                                actionKeypath: "navigator.openConferenceNearbyRadar",
                                label: "Nearby radar",
                                background: "#E8F1FF",
                                borderColor: "#2F65B8"
                            )
                        ])
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            conferenceShowcaseActionButton(
                                actionKeypath: "navigator.openConferenceParticipantChat",
                                label: "Participant chat",
                                background: ConferenceSurfacePalette.accentCoolSoft,
                                borderColor: ConferenceSurfacePalette.accentCoolBorder
                            )
                        ])
                    )
                ],
                background: ConferenceSurfacePalette.shell,
                borderColor: ConferenceSurfacePalette.stroke
            ),
            conferenceShowcaseSection(
                "Scope Note",
                content: [
                    conferenceShowcaseStaticText(
                        "Jeg fant ikke en separat, ferdig implementert Claude-runtime i repoet. Derfor skiller denne launcheren mellom det som faktisk er kjørbart na og den separate Claude-designreferansen.",
                        fontSize: 12,
                        foregroundColor: ConferenceSurfacePalette.textMuted,
                        lineLimit: 6
                    )
                ],
                background: "#FBF7F1",
                borderColor: "#D9D5CB"
            )
        ])
        root.modifiers = modifier {
            $0.padding = 14
            $0.background = ConferenceSurfacePalette.canvas
        }

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.background = ConferenceSurfacePalette.canvas
        }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated static func conferenceClaudeDesignReferenceMenuConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Conference Claude Design Reference")
        configuration.description = "Loadbar Claude-designreferanse med aerlige notater om hva som faktisk er implementert i HAVEN na."
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: "cell:///ConferenceConfigurationNavigator",
            sourceCellName: "ConferenceConfigurationNavigatorLocalCell",
            purpose: "Conference Claude design reference",
            purposeDescription: "Oppsummerer den repo-lokale Claude-designretningen for public, participant, organizer, sponsor og nearby, og lar brukeren aapne den naavaerende live-flaten for hver rolle.",
            interests: ["conference", "claude", "design", "reference", "visual-direction", "public", "participant", "organizer", "sponsor", "nearby"],
            menuSlots: ["upperRight", "lowerRight"]
        )
        configuration.addReference(conferenceConfigurationNavigatorReference())

        var root = SkeletonVStack(elements: [
            conferenceShowcaseSection(
                "Claude Design Reference",
                content: [
                    conferenceShowcaseStaticText(
                        "Denne flaten er en designreferanse, ikke en paastand om at det finnes en separat skjult Claude-runtime i HAVEN. Bruk knappene under for aa aapne dagens kjørbare flater side om side med designretningen.",
                        fontSize: 13,
                        foregroundColor: ConferenceSurfacePalette.textMuted,
                        lineLimit: 6
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            conferenceShowcaseActionButton(
                                actionKeypath: "navigator.openConferenceDemoLauncher",
                                label: "Open demo launcher",
                                background: ConferenceSurfacePalette.shellMuted,
                                borderColor: ConferenceSurfacePalette.stroke
                            ),
                            conferenceShowcaseActionButton(
                                actionKeypath: "navigator.openConferenceParticipantPortal",
                                label: "Open participant portal",
                                background: ConferenceSurfacePalette.accentWarmSoft,
                                borderColor: ConferenceSurfacePalette.strokeStrong
                            )
                        ])
                    )
                ],
                background: "#FBFAF6",
                borderColor: "#D9D5CB"
            ),
            conferenceShowcaseSection(
                "Public",
                content: [
                    conferenceShowcaseStaticText(
                        "Claude public skal kjennes som en editorial konferanseflate med tydelig hero, program, speakers og CTAs. Ikke intern participant-drift eller debug-tekst.",
                        fontSize: 12,
                        foregroundColor: ConferenceSurfacePalette.textMain,
                        lineLimit: 5
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            conferenceShowcaseActionButton(
                                actionKeypath: "navigator.openConferencePublicSurface",
                                label: "Open public surface",
                                background: "#EFEDFF",
                                borderColor: "#5B4BC8"
                            )
                        ])
                    )
                ],
                background: "#EFEDFF",
                borderColor: "#5B4BC8"
            ),
            conferenceShowcaseSection(
                "Participant",
                content: [
                    conferenceShowcaseStaticText(
                        "Claude participant er en varm day workspace: agenda, people, chats og meetings med store touch targets og indigo/lavender-aksenter.",
                        fontSize: 12,
                        foregroundColor: ConferenceSurfacePalette.textMain,
                        lineLimit: 5
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            conferenceShowcaseActionButton(
                                actionKeypath: "navigator.openConferenceParticipantPortal",
                                label: "Open participant portal",
                                background: "#EFEDFF",
                                borderColor: "#5B4BC8"
                            ),
                            conferenceShowcaseActionButton(
                                actionKeypath: "navigator.openConferenceAIAssistant",
                                label: "Open AI assistant",
                                background: "#EFEDFF",
                                borderColor: "#5B4BC8"
                            )
                        ])
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            conferenceShowcaseActionButton(
                                actionKeypath: "navigator.openConferenceParticipantChat",
                                label: "Open participant chat",
                                background: "#EFEDFF",
                                borderColor: "#5B4BC8"
                            )
                        ])
                    )
                ],
                background: "#F4F0FF",
                borderColor: "#7C6BE3"
            ),
            conferenceShowcaseSection(
                "Organizer",
                content: [
                    conferenceShowcaseStaticText(
                        "Claude organizer/control tower skal vaere lys, varm og amber-orientert, med tydelig KPI-historie og mindre teknisk stoy.",
                        fontSize: 12,
                        foregroundColor: ConferenceSurfacePalette.textMain,
                        lineLimit: 5
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            conferenceShowcaseActionButton(
                                actionKeypath: "navigator.openConferenceControlTower",
                                label: "Open control tower",
                                background: "#F9ECD7",
                                borderColor: "#B76A00"
                            )
                        ])
                    )
                ],
                background: "#F9ECD7",
                borderColor: "#B76A00"
            ),
            conferenceShowcaseSection(
                "Sponsor & Nearby",
                content: [
                    conferenceShowcaseStaticText(
                        "Claude sponsor skal foeles som en consent-pipeline i groent. Claude nearby skal vaere lett og signalpreget i blaatt uten unsupported-stoy i normalflyten.",
                        fontSize: 12,
                        foregroundColor: ConferenceSurfacePalette.textMain,
                        lineLimit: 6
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            conferenceShowcaseActionButton(
                                actionKeypath: "navigator.openConferenceSponsorFollowUp",
                                label: "Open sponsor follow-up",
                                background: "#DCEEEB",
                                borderColor: "#0B7A5A"
                            ),
                            conferenceShowcaseActionButton(
                                actionKeypath: "navigator.openConferenceNearbyRadar",
                                label: "Open nearby radar",
                                background: "#E8F1FF",
                                borderColor: "#2F65B8"
                            )
                        ])
                    )
                ],
                background: "#FBFAF6",
                borderColor: "#D9D5CB"
            )
        ])
        root.modifiers = modifier {
            $0.padding = 14
            $0.background = ConferenceSurfacePalette.canvas
        }

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.background = ConferenceSurfacePalette.canvas
        }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated static func personalHomeMenuConfiguration() -> CellConfiguration {
        var configuration = personalReferenceCardConfiguration(
            name: "Personal Home",
            endpoint: "cell:///PersonalIdentity",
            label: "identity",
            title: "Personal Home",
            subtitle: "Startside for identitet, samtykker, eksport og sletting. Alt personlig starter lokalt pa telefonen.",
            chip: "LOCAL",
            borderColor: "#0F766E",
            sourceCellName: "PersonalIdentityCell",
            purpose: "Personal Co-Pilot startside",
            purposeDescription: "Lokal inngang til requester, public/private identity og konto-livssyklus uten sky-publisering for brukeren samtykker.",
            interests: ["identity", "privacy", "account", "export", "delete"],
            menuSlots: [.upperLeft],
            policyCategory: "identity-and-account"
        )
        configuration.addReference(CellReference(endpoint: "cell:///PersonalProfileDraft", subscribeFeed: false, label: "profileDraft"))
        configuration.addReference(CellReference(endpoint: "cell:///PersonalPrivacyAudit", subscribeFeed: false, label: "privacyAudit"))
        configuration.skeleton = personalIdentitySurfaceSkeleton()
        return configuration
    }

    nonisolated static func personalProfileMenuConfiguration() -> CellConfiguration {
        var configuration = personalReferenceCardConfiguration(
            name: "My Profile",
            endpoint: "cell:///PersonalProfileDraft",
            label: "profileDraft",
            title: "My Profile",
            subtitle: "Privat profilutkast. Preview og publisering krever eksplisitt samtykke.",
            chip: "LOCAL DRAFT",
            borderColor: "#0E7490",
            sourceCellName: "PersonalProfileDraftCell",
            purpose: "Privat profilutkast",
            purposeDescription: "Holder arbeidsutkast, publiseringspreview og samtykkestatus lokalt for profilen sendes til CellScaffold.",
            interests: ["profile", "draft", "consent", "public-profile"],
            menuSlots: [.upperMid],
            policyCategory: "profile-draft",
            requiresUserGeneratedContentModeration: true
        )
        configuration.skeleton = personalProfileDraftSurfaceSkeleton()
        return configuration
    }

    nonisolated static func personalPublicProfileMenuConfiguration() -> CellConfiguration {
        var configuration = personalReferenceCardConfiguration(
            name: "Publish Public Profile",
            endpoint: "cell://staging.haven.digipomps.org/PersonalProfilePublisher",
            label: "profilePublisher",
            title: "Publish Public Profile",
            subtitle: "Publiser, avpubliser eller slett offentlig profil etter tydelig samtykke.",
            chip: "REMOTE",
            borderColor: "#2563EB",
            sourceCellName: "PersonalProfilePublisherCell",
            purpose: "Publisering av offentlig profil",
            purposeDescription: "Sender bare eksplisitt godkjent profilutkast til CellScaffold og gir unpublish/delete-kontroller.",
            interests: ["profile", "publish", "unpublish", "delete", "consent"],
            menuSlots: [.upperMid],
            policyCategory: "profile-publish",
            requiresLogin: true,
            requiresUserGeneratedContentModeration: true,
            universalLinkPath: "personal/profile/publish"
        )
        configuration.addReference(CellReference(endpoint: "cell:///PersonalProfileDraft", subscribeFeed: false, label: "profileDraft"))
        configuration.addReference(CellReference(endpoint: "cell:///PersonalPrivacyAudit", subscribeFeed: false, label: "privacyAudit"))
        configuration.skeleton = personalPublishPublicProfileSurfaceSkeleton()
        return configuration
    }

    nonisolated static func personalPublicProfileDirectoryMenuConfiguration() -> CellConfiguration {
        var configuration = personalReferenceCardConfiguration(
            name: "Public Profile Directory",
            endpoint: "cell://staging.haven.digipomps.org/PublicProfileDirectory",
            label: "directory",
            title: "Public Profile Directory",
            subtitle: "Sok i offentlige profiler med rapporterings-, skjulings- og blokkeringskontroller.",
            chip: "REMOTE",
            borderColor: "#2563EB",
            sourceCellName: "PublicProfileDirectoryCell",
            purpose: "Search public profiles safely",
            purposeDescription: "Sok i publiserte profiler og la brukeren rapportere, skjule eller blokkere profiler fra samme flate.",
            interests: ["profiles", "directory", "search", "report", "block"],
            menuSlots: [.upperLeft],
            policyCategory: "public-directory",
            requiresLogin: true,
            requiresUserGeneratedContentModeration: true,
            universalLinkPath: "personal/directory"
        )
        configuration.skeleton = personalPublicProfileDirectorySurfaceSkeleton()
        return configuration
    }

    nonisolated static func personalMatchesMenuConfiguration() -> CellConfiguration {
        var configuration = personalReferenceCardConfiguration(
            name: "Matches",
            endpoint: "cell://staging.haven.digipomps.org/PersonalMatchmaking",
            label: "matchmaking",
            title: "Matches",
            subtitle: "Samtykkebaserte forslag. Chat starter aldri for begge parter har akseptert.",
            chip: "REMOTE",
            borderColor: "#B45309",
            sourceCellName: "PersonalMatchmakingCell",
            purpose: "Samtykkebasert matching",
            purposeDescription: "Viser match-forslag og krever eksplisitt gjensidig aksept for chat-invitasjon.",
            interests: ["matching", "consent", "profile", "invite-only-chat"],
            menuSlots: [.upperLeft],
            policyCategory: "matching",
            requiresLogin: true,
            requiresUserGeneratedContentModeration: true,
            universalLinkPath: "personal/matches"
        )
        configuration.addReference(CellReference(endpoint: "cell:///PersonalProfileDraft", subscribeFeed: false, label: "profileDraft"))
        configuration.addReference(CellReference(endpoint: "cell:///PersonalChatClient", subscribeFeed: false, label: "chatClient"))
        configuration.addReference(CellReference(endpoint: "cell:///PersonalPrivacyAudit", subscribeFeed: false, label: "privacyAudit"))
        configuration.skeleton = personalMatchesSurfaceSkeleton()
        return configuration
    }

    nonisolated static func personalVaultIdeasMenuConfiguration() -> CellConfiguration {
        var configuration = personalReferenceCardConfiguration(
            name: "Vault / Ideas",
            endpoint: "cell:///Vault",
            label: "vault",
            title: "Vault / Ideas",
            subtitle: "Organiser ideer, prosjekter og notater lokalt. Remote flater far ikke vault-tilgang uten eksplisitt handling.",
            chip: "LOCAL",
            borderColor: "#9333EA",
            sourceCellName: "VaultCell",
            purpose: "Personlig vault for ideer og prosjekter",
            purposeDescription: "Obsidian-lignende lokal notatflate for ideer, prosjekter, markdown og kunnskapsstruktur.",
            interests: ["vault", "ideas", "projects", "notes", "markdown"],
            menuSlots: [.upperRight, .lowerRight],
            policyCategory: "local-vault",
            nativePermissionRequests: ["vault"]
        )
        configuration.addReference(CellReference(endpoint: "cell:///GraphIndex", subscribeFeed: false, label: "graph"))
        configuration.skeleton = personalVaultIdeasSurfaceSkeleton()
        return configuration
    }

    nonisolated static func personalMeetingIntentMenuConfiguration() -> CellConfiguration {
        var configuration = personalReferenceCardConfiguration(
            name: "Meeting Intent",
            endpoint: "cell://staging.haven.digipomps.org/PersonalMeetingCoordinator",
            label: "meetingCoordinator",
            title: "Meeting Intent",
            subtitle: "Foresla motetider og Jitsi-metadata som trygg placeholder uten native calendar, camera eller mic-permission.",
            chip: "HYBRID",
            borderColor: "#0D9488",
            sourceCellName: "PersonalMeetingCoordinatorCell",
            purpose: "Coordinate meeting intent safely",
            purposeDescription: "Foreslaa motetider og Jitsi-metadata som trygg placeholder uten native calendar, camera eller mic-permission.",
            interests: ["meeting", "coordination", "intent", "scheduling", "jitsi-ready"],
            menuSlots: [.upperRight, .lowerRight],
            policyCategory: "meeting-intent",
            requiresLogin: true,
            requiresUserGeneratedContentModeration: true,
            universalLinkPath: "personal/meeting"
        )
        configuration.skeleton = personalMeetingIntentSurfaceSkeleton()
        return configuration
    }

    nonisolated static func personalAgendaContextMenuConfiguration() -> CellConfiguration {
        let configuration = withPersonalCopilotMetadata(
            PersonalAgendaContextCell.menuConfiguration(),
            sourceCellEndpoint: "cell:///PersonalAgendaContext",
            sourceCellName: "PersonalAgendaContextCell",
            purpose: "Dagens agenda for personlig co-pilot",
            purposeDescription: "Lokal agenda-context som leser Calendar og Reminders etter eksplisitt samtykke, svarer på dagens/neste agenda, og kan dele purpose-signaler med Perspective.",
            interests: ["agenda", "calendar", "reminders", "daily-planning", "agenda-aspects", "purpose-interest-weighted"],
            menuSlots: [.upperRight, .lowerRight],
            policyCategory: "agenda-context",
            nativePermissionRequests: ["calendar", "reminders"],
            universalLinkPath: "personal/agenda"
        )
        return withPersonalCopilotRecoveryAction(configuration)
    }

    nonisolated static func personalCalendarStoreMenuConfiguration() -> CellConfiguration {
        let configuration = withPersonalCopilotMetadata(
            CalendarConfigurationFactory.makeStoreConfiguration(),
            sourceCellEndpoint: CalendarContract.endpoint,
            sourceCellName: CalendarContract.storeCellName,
            purpose: "Canonical kalender for personlig co-pilot",
            purposeDescription: "Lokal HAVEN-kalenderkontrakt med CalendarItem/CalendarOccurrence, portable calendar visualization og eksplisitt ICS import/export.",
            interests: ["calendar", "agenda", "schedule", "ics", "recurrence", "planning"],
            menuSlots: [.upperRight, .lowerRight],
            policyCategory: "calendar-store",
            universalLinkPath: "personal/calendar"
        )
        return withPersonalCopilotRecoveryAction(configuration)
    }

    nonisolated static func personalPrivacyAuditMenuConfiguration() -> CellConfiguration {
        var configuration = personalReferenceCardConfiguration(
            name: "Privacy Audit",
            endpoint: "cell:///PersonalPrivacyAudit",
            label: "privacyAudit",
            title: "Privacy Audit",
            subtitle: "Lokal logg for profilpublisering, match-samtykke, chat-invitasjoner, remote config loads og permissions.",
            chip: "LOCAL",
            borderColor: "#334155",
            sourceCellName: "PersonalPrivacyAuditCell",
            purpose: "Lokal personvernlogg",
            purposeDescription: "Gir brukeren en aarlig oversikt over viktige samtykker og capability-gater i Personal Co-Pilot.",
            interests: ["privacy", "audit", "consent", "permissions", "remote-config"],
            menuSlots: [.lowerLeft],
            policyCategory: "privacy-audit"
        )
        configuration.skeleton = personalPrivacyAuditSurfaceSkeleton()
        return configuration
    }

    nonisolated static func personalCopilotCatalogMenuConfiguration() -> CellConfiguration {
        var configuration = personalReferenceCardConfiguration(
            name: "Personal Co-Pilot Catalog",
            endpoint: "cell://staging.haven.digipomps.org/PersonalCopilotConfigurationCatalog",
            label: "personalCatalog",
            title: "Personal Co-Pilot Catalog",
            subtitle: "App Store-godkjent katalog som kun returnerer Personal Co-Pilot V1-konfigurasjoner.",
            chip: "REMOTE",
            borderColor: "#2563EB",
            sourceCellName: "PersonalCopilotConfigurationCatalogCell",
            purpose: "Personal Co-Pilot approved catalog",
            purposeDescription: "Returnerer bare personal-copilot-v1-konfigurasjoner med policy, scope og execution metadata.",
            interests: ["catalog", "allowlist", "review-metadata", "personal-copilot"],
            menuSlots: [.lowerRight],
            policyCategory: "catalog",
            universalLinkPath: "personal/catalog"
        )
        configuration.skeleton = personalCopilotCatalogSurfaceSkeleton()
        return configuration
    }

    nonisolated static func appleIntelligenceLandingForPersonalCopilotConfiguration() -> CellConfiguration {
        withPersonalCopilotMetadata(
            appleIntelligenceLandingConfiguration(),
            sourceCellEndpoint: "cell:///ConfigurationCatalog",
            sourceCellName: "ConfigurationCatalogCell",
            purpose: "Apple Intelligence for personlig co-pilot",
            purposeDescription: "Lokal semantisk matching mot ConfigurationCatalog for aa finne CellConfigurations som kan hjelpe brukerens formulerte intensjon.",
            interests: ["assistant", "apple-intelligence", "semantic-matching", "configuration-catalog"],
            menuSlots: [.upperMid],
            policyCategory: "apple-intelligence",
            nativePermissionRequests: []
        )
    }

    nonisolated static func entityScannerForPersonalCopilotConfiguration() -> CellConfiguration {
        withPersonalCopilotMetadata(
            entityScannerWorkbenchConfiguration(),
            sourceCellEndpoint: "cell:///EntityScanner",
            sourceCellName: "EntityScannerCell",
            purpose: "Entity Scanner for personlig kontaktetablering",
            purposeDescription: "Oppdag naerliggende enheter og etabler kontakt med tydelige permissions og lokale proofs.",
            interests: ["scanner", "nearby", "identity", "peer", "proofs"],
            menuSlots: [.lowerLeft],
            policyCategory: "hardware-scanner",
            nativePermissionRequests: ["nearby", "bluetooth"]
        )
    }

    nonisolated static func workflowStudioForPersonalCopilotConfiguration() -> CellConfiguration {
        let configuration = withPersonalCopilotMetadata(
            workflowStudioWorkbenchMenuConfiguration(),
            sourceCellEndpoint: "cell:///WorkflowStudio",
            sourceCellName: "WorkflowStudioCell",
            purpose: "Workflow Studio for personlig co-pilot",
            purposeDescription: "Bygg og test personlige arbeidsflyter uten aa eksponere skjulte remote features.",
            interests: ["workflow", "automation", "studio", "personal-productivity"],
            menuSlots: [.upperMid, .lowerMid],
            policyCategory: "workflow-studio"
        )
        return withPersonalCopilotRecoveryAction(configuration)
    }

    nonisolated static func personalInviteChatMenuConfiguration(
        chatHubEndpoint: String = "cell:///PersonalChatHub"
    ) -> CellConfiguration {
        var configuration = CellConfiguration(name: "Co-Pilot")
        configuration.description = "Chat-first arbeidsflate. Skriv naturlig hva du vil oppnaa, finn forslag, og apne bare de hjelperne du ber om. Alle sideeffekter krever eget trykk."
        configuration.addReference(CellReference(endpoint: chatHubEndpoint, label: "chatHub"))
        configuration.addReference(CellReference(endpoint: "cell:///Perspective", subscribeFeed: false, label: "perspective"))
        configuration = withPersonalCopilotMetadata(
            configuration,
            sourceCellEndpoint: chatHubEndpoint,
            sourceCellName: "PersonalChatHubCell",
            purpose: "Central purpose-driven co-pilot chat",
            purposeDescription: "Kompakt chat-first arbeidsflate som matcher naturlig sprak mot synlige formaal, interesser, CellConfigurations, tilgjengelige RAG-cases og trygge agent-action metadata. Alle sideeffekter krever klikk og scope-godkjenning.",
            interests: [
                "chat",
                "invite-only",
                "moderation",
                "report",
                "block",
                "chat-assistant",
                "invite-person",
                "poll",
                "meeting-video-intent",
                "schedule-meeting-intent",
                "project-intent",
                "todo-intent",
                "reminder-intent",
                "work-item",
                "bug-report",
                "work-item-capture",
                "guided-onboarding",
                "entity-enrichment",
                "profile-visibility",
                "capability-gap",
                "feature-request",
                "user-controlled-submission",
                "resource-router",
                "rag-query",
                "cell-scoped-ai-provider",
                "provider-slot",
                "voice-input",
                "speech-to-text",
                "dictation",
                "local-agent-action",
                "signed-remote-intent",
                "component-surface",
                "requires-user-approval",
                "purpose-interest-weighted",
                "purposeRef=personal.chat.assist.invite",
                "purposeRef=personal.chat.assist.poll",
                "purposeRef=personal.chat.assist.resource-router",
                "purposeRef=personal.chat.assist.rag-query",
                "purposeRef=personal.chat.assist.provider-route",
                "purposeRef=personal.chat.assist.meeting.video",
                "purposeRef=personal.chat.assist.meeting.schedule",
                "purposeRef=personal.chat.assist.project",
                "purposeRef=personal.chat.assist.todo",
                "purposeRef=personal.chat.assist.reminder",
                "purposeRef=personal.chat.assist.work-item.capture",
                "purposeRef=personal.chat.assist.guided-onboarding",
                "purposeRef=personal.chat.assist.capability-request",
                "purposeRef=personal.chat.assist.local-agent-action",
                "purposeRef=personal.agent.local.gui.finder.close-windows"
            ],
            menuSlots: [.upperLeft, .lowerLeft],
            policyCategory: "purpose-driven-chat",
            requiresLogin: true,
            requiresUserGeneratedContentModeration: true,
            universalLinkPath: "personal/chat/copilot"
        )

        let fieldCard = BindingPersonalCopilotDesignSystem.fieldCard()
        let composerFieldCard = BindingPersonalCopilotDesignSystem.chatComposerFieldCard()
        func button(
            _ keypath: String,
            _ title: String,
            payload: ValueType = .object([:]),
            style: PersonalButtonStyle = .primary
        ) -> SkeletonButton {
            personalActionButton(
                keypath: keypath,
                label: title,
                payload: payload,
                style: style
            )
        }
        let composer = SkeletonTextArea(
            text: nil,
            sourceKeypath: "chatHub.state.composer.body",
            targetKeypath: "chatHub.setComposer",
            placeholder: nil,
            minLines: 2,
            maxLines: 3,
            submitOnEnter: true,
            submitActionKeypath: "chatHub.prompt.submit",
            modifiers: composerFieldCard
        )
        let candidateField = SkeletonTextField(
            text: nil,
            sourceKeypath: "chatHub.state.assistant.candidateQuery",
            targetKeypath: "chatHub.assistant.setCandidateQuery",
            placeholder: "Avgrens med navn, kallenavn eller relasjon",
            modifiers: fieldCard
        )
        let inviteTitleField = SkeletonTextField(
            text: nil,
            sourceKeypath: "chatHub.state.inviteDraft.title",
            targetKeypath: "chatHub.inviteDraft.title",
            placeholder: "Gi chatten en kort tittel",
            modifiers: fieldCard
        )
        let pollQuestionField = SkeletonTextField(
            text: nil,
            sourceKeypath: "chatHub.state.pollDraft.question",
            targetKeypath: "chatHub.poll.setQuestion",
            placeholder: "Hva skal dere stemme over?",
            modifiers: fieldCard
        )
        let pollOptionsField = SkeletonTextArea(
            text: nil,
            sourceKeypath: "chatHub.state.pollDraft.optionsText",
            targetKeypath: "chatHub.poll.setOptions",
            placeholder: "Ett alternativ per linje",
            minLines: 2,
            maxLines: 6,
            submitOnEnter: false,
            modifiers: fieldCard
        )
        let meetingTitleField = SkeletonTextField(
            text: nil,
            sourceKeypath: "chatHub.state.workbench.meetingDraft.title",
            targetKeypath: "chatHub.meeting.title",
            placeholder: "Hva skal motet handle om?",
            modifiers: fieldCard
        )
        let meetingTimesField = SkeletonTextField(
            text: nil,
            sourceKeypath: "chatHub.state.workbench.meetingDraft.proposedTimesText",
            targetKeypath: "chatHub.meeting.proposedTimesText",
            placeholder: "Forslag som \"i morgen formiddag, fredag ettermiddag\"",
            modifiers: fieldCard
        )
        let todoTitleField = SkeletonTextField(
            text: nil,
            sourceKeypath: "chatHub.state.workbench.todoDraft.title",
            targetKeypath: "chatHub.todo.title",
            placeholder: "Oppgave",
            modifiers: fieldCard
        )
        let todoNoteField = SkeletonTextArea(
            text: nil,
            sourceKeypath: "chatHub.state.workbench.todoDraft.note",
            targetKeypath: "chatHub.todo.note",
            placeholder: "Detaljer",
            minLines: 2,
            maxLines: 5,
            submitOnEnter: false,
            modifiers: fieldCard
        )
        let todoDueField = SkeletonTextField(
            text: nil,
            sourceKeypath: "chatHub.state.workbench.todoDraft.dueAtText",
            targetKeypath: "chatHub.todo.dueAtText",
            placeholder: "Frist eller tidspunkt",
            modifiers: fieldCard
        )
        let projectTitleField = SkeletonTextField(
            text: nil,
            sourceKeypath: "chatHub.state.workbench.projectDraft.title",
            targetKeypath: "chatHub.project.title",
            placeholder: "Prosjekttittel",
            modifiers: fieldCard
        )
        let projectDescriptionField = SkeletonTextArea(
            text: nil,
            sourceKeypath: "chatHub.state.workbench.projectDraft.description",
            targetKeypath: "chatHub.project.description",
            placeholder: "Hva skal lages?",
            minLines: 3,
            maxLines: 7,
            submitOnEnter: false,
            modifiers: fieldCard
        )
        let reminderTitleField = SkeletonTextField(
            text: nil,
            sourceKeypath: "chatHub.state.workbench.reminderDraft.title",
            targetKeypath: "chatHub.reminder.title",
            placeholder: "Hva skal huskes?",
            modifiers: fieldCard
        )
        let reminderTimeField = SkeletonTextField(
            text: nil,
            sourceKeypath: "chatHub.state.workbench.reminderDraft.scheduledAtText",
            targetKeypath: "chatHub.reminder.scheduledAtText",
            placeholder: "Tidspunkt",
            modifiers: fieldCard
        )
        let ideaTitleField = SkeletonTextField(
            text: nil,
            sourceKeypath: "chatHub.state.workbench.ideaDraft.title",
            targetKeypath: "chatHub.idea.title",
            placeholder: "Kort ide-tittel",
            modifiers: fieldCard
        )
        let ideaContentField = SkeletonTextArea(
            text: nil,
            sourceKeypath: "chatHub.state.workbench.ideaDraft.content",
            targetKeypath: "chatHub.idea.content",
            placeholder: "Skriv ideen her",
            minLines: 3,
            maxLines: 8,
            submitOnEnter: false,
            modifiers: fieldCard
        )
        let agentActionField = SkeletonTextField(
            text: nil,
            sourceKeypath: "chatHub.state.workbench.agentReviewDraft.actionID",
            targetKeypath: "chatHub.agent.review.actionID",
            placeholder: "Agent action ID",
            modifiers: fieldCard
        )
        let agentReasonField = SkeletonTextArea(
            text: nil,
            sourceKeypath: "chatHub.state.workbench.agentReviewDraft.reason",
            targetKeypath: "chatHub.agent.review.reason",
            placeholder: "Hvorfor skal dette til lokal review?",
            minLines: 2,
            maxLines: 5,
            submitOnEnter: false,
            modifiers: fieldCard
        )
        let capabilityTitleField = SkeletonTextField(
            text: nil,
            sourceKeypath: "chatHub.state.workbench.capabilityRequestDraft.title",
            targetKeypath: "chatHub.capabilityRequest.title",
            placeholder: "Kort behovstittel",
            modifiers: fieldCard
        )
        let capabilitySummaryField = SkeletonTextArea(
            text: nil,
            sourceKeypath: "chatHub.state.workbench.capabilityRequestDraft.summary",
            targetKeypath: "chatHub.capabilityRequest.summary",
            placeholder: "Hva provde du aa faa til?",
            minLines: 3,
            maxLines: 7,
            submitOnEnter: false,
            modifiers: fieldCard
        )
        let docsRAGQueryField = SkeletonTextArea(
            text: nil,
            sourceKeypath: "chatHub.state.docsRAG.query",
            targetKeypath: "chatHub.docsRAG.setQuery",
            placeholder: "Spør om dokumentasjon, arkitektur, skeleton, formål/interesser eller et tilgjengelig RAG-case",
            minLines: 3,
            maxLines: 7,
            submitOnEnter: false,
            modifiers: fieldCard
        )
        let mermaidSourceField = SkeletonTextArea(
            text: nil,
            sourceKeypath: "chatHub.state.assistant.candidateQuery",
            targetKeypath: "chatHub.assistant.setCandidateQuery",
            placeholder: "Lim inn eller skriv Mermaid-kode, for eksempel: flowchart TD\\n  A[Idé] --> B[Prosjekt]",
            minLines: 5,
            maxLines: 10,
            submitOnEnter: false,
            modifiers: fieldCard
        )
        let workItemTitleField = SkeletonTextField(
            text: nil,
            sourceKeypath: "chatHub.state.workbench.workItemDraft.title",
            targetKeypath: "chatHub.workItem.title",
            placeholder: "Kort tittel",
            modifiers: fieldCard
        )
        let workItemSummaryField = SkeletonTextArea(
            text: nil,
            sourceKeypath: "chatHub.state.workbench.workItemDraft.summary",
            targetKeypath: "chatHub.workItem.summary",
            placeholder: "Hva skjer, hvor skjer det, og hvorfor betyr det noe?",
            minLines: 3,
            maxLines: 8,
            submitOnEnter: false,
            modifiers: fieldCard
        )
        let workItemKindField = SkeletonTextField(
            text: nil,
            sourceKeypath: "chatHub.state.workbench.workItemDraft.kind",
            targetKeypath: "chatHub.workItem.kind",
            placeholder: "bug, feature, docs, chore ...",
            modifiers: fieldCard
        )
        let workItemCurrentField = SkeletonTextArea(
            text: nil,
            sourceKeypath: "chatHub.state.workbench.workItemDraft.currentBehavior",
            targetKeypath: "chatHub.workItem.currentBehavior",
            placeholder: "Observerte symptomer / repro",
            minLines: 2,
            maxLines: 6,
            submitOnEnter: false,
            modifiers: fieldCard
        )
        let workItemExpectedField = SkeletonTextArea(
            text: nil,
            sourceKeypath: "chatHub.state.workbench.workItemDraft.expectedBehavior",
            targetKeypath: "chatHub.workItem.expectedBehavior",
            placeholder: "Forventet oppførsel",
            minLines: 2,
            maxLines: 5,
            submitOnEnter: false,
            modifiers: fieldCard
        )

        var messageRow = SkeletonVStack(elements: [
            .Text(personalBoundText("authorDisplayName", lineLimit: 1)),
            .Text(personalBoundText("body", lineLimit: 4))
        ], spacing: 4)
        messageRow.modifiers = BindingPersonalCopilotDesignSystem.sectionCard(role: "personal-message-bubble")
        var messages = SkeletonList(topic: nil, keypath: "chatHub.state.messages", flowElementSkeleton: messageRow)
        messages.modifiers = BindingPersonalCopilotDesignSystem.listCard(height: 220, role: "personal-message-bubble")

        var threadRow = SkeletonVStack(elements: [
            .Text(personalBoundText("title", lineLimit: 1)),
            .Text(personalBoundText("lastMessagePreview", lineLimit: 3)),
            .Text(personalBoundText("statusText", lineLimit: 1))
        ], spacing: 4)
        threadRow.modifiers = BindingPersonalCopilotDesignSystem.sectionCard(role: "personal-list-row")
        var threads = SkeletonList(topic: nil, keypath: "chatHub.state.threads", flowElementSkeleton: threadRow)
        threads.selectionMode = .single
        threads.selectionStateKeypath = "chatHub.state.currentThread.id"
        threads.selectionValueKeypath = "id"
        threads.selectionActionKeypath = "chatHub.ui.setCurrentThread"
        threads.selectionPayloadMode = .itemID
        threads.modifiers = BindingPersonalCopilotDesignSystem.listCard(height: 160, role: "personal-list-row")

        var promptMessageRow = SkeletonVStack(elements: [
            .Text(personalBoundText("speaker", lineLimit: 1)),
            .Text(personalBoundText("body", lineLimit: 2)),
            .Text(personalBoundText("statusText", lineLimit: 1))
        ], spacing: 3)
        promptMessageRow.modifiers = BindingPersonalCopilotDesignSystem.sectionCard(role: "chat-prompt-message")
        var promptMessages = SkeletonList(topic: nil, keypath: "chatHub.state.ui.promptMessages", flowElementSkeleton: promptMessageRow)
        promptMessages.modifiers = BindingPersonalCopilotDesignSystem.listCard(height: 112, role: "chat-prompt-log")

        var candidateRow = SkeletonVStack(elements: [
            .Text(personalBoundText("displayName", lineLimit: 1)),
            .Text(personalBoundText("headline", lineLimit: 2)),
            .Text(personalBoundText("summary", lineLimit: 3))
        ], spacing: 4)
        candidateRow.modifiers = BindingPersonalCopilotDesignSystem.sectionCard(role: "personal-list-row")
        var candidates = SkeletonList(
            topic: nil,
            keypath: "chatHub.state.assistant.latestSuggestion.candidates",
            flowElementSkeleton: candidateRow
        )
        candidates.selectionMode = .single
        candidates.selectionStateKeypath = "chatHub.state.assistant.latestSuggestion.selectedCandidateProfileID"
        candidates.selectionValueKeypath = "id"
        candidates.selectionActionKeypath = "chatHub.assistant.selectCandidate"
        candidates.selectionPayloadMode = .itemID
        candidates.modifiers = BindingPersonalCopilotDesignSystem.listCard(height: 220, role: "personal-list-row")

        var inviteRow = SkeletonVStack(elements: [
            .Text(personalBoundText("title", lineLimit: 1))
        ], spacing: 4)
        inviteRow.modifiers = BindingPersonalCopilotDesignSystem.sectionCard(role: "personal-chat-item")
        var invites = SkeletonList(topic: nil, keypath: "chatHub.state.invites", flowElementSkeleton: inviteRow)
        invites.modifiers = BindingPersonalCopilotDesignSystem.listCard(height: 160, role: "personal-chat-item")

        var pollRow = SkeletonVStack(elements: [
            .Text(personalBoundText("question", lineLimit: 2)),
            .Text(personalBoundText("status", lineLimit: 1))
        ], spacing: 4)
        pollRow.modifiers = BindingPersonalCopilotDesignSystem.sectionCard(role: "personal-list-row")
        var polls = SkeletonList(topic: nil, keypath: "chatHub.state.polls", flowElementSkeleton: pollRow)
        polls.modifiers = BindingPersonalCopilotDesignSystem.listCard(height: 180, role: "personal-list-row")

        var moduleRow = SkeletonVStack(elements: [
            .Text(personalBoundText("title", lineLimit: 1)),
            .Text(personalBoundText("kind", lineLimit: 1)),
            .Text(personalBoundText("status", lineLimit: 1))
        ], spacing: 4)
        moduleRow.modifiers = BindingPersonalCopilotDesignSystem.sectionCard(role: "personal-list-row")
        var workbenchModules = SkeletonList(topic: nil, keypath: "chatHub.state.workbench.modules", flowElementSkeleton: moduleRow)
        workbenchModules.modifiers = BindingPersonalCopilotDesignSystem.listCard(height: 180, role: "personal-list-row")

        var capabilityRow = SkeletonVStack(elements: [
            .Text(personalBoundText("title", lineLimit: 1)),
            .Text(personalBoundText("destination", lineLimit: 1)),
            .Text(personalBoundText("status", lineLimit: 1))
        ], spacing: 4)
        capabilityRow.modifiers = BindingPersonalCopilotDesignSystem.sectionCard(role: "personal-list-row")
        var capabilityRequests = SkeletonList(topic: nil, keypath: "chatHub.state.capabilityRequests", flowElementSkeleton: capabilityRow)
        capabilityRequests.modifiers = BindingPersonalCopilotDesignSystem.listCard(height: 160, role: "personal-list-row")

        var surfaceRow = SkeletonVStack(elements: [
            .Text(personalBoundText("title", lineLimit: 1)),
            .Text(personalBoundText("state", lineLimit: 1))
        ], spacing: 4)
        surfaceRow.modifiers = modifier {
            $0.padding = 12
            $0.background = BindingPersonalCopilotDesignSystem.surfaceElevated
            $0.cornerRadius = 8
            $0.borderWidth = 1
            $0.borderColor = BindingPersonalCopilotDesignSystem.border
            $0.styleRole = "personal-list-row"
            $0.motionHint = .appear
            $0.motionSourceRole = "personal-chat-helper"
        }
        var componentSurfaces = SkeletonList(topic: nil, keypath: "chatHub.state.ui.componentSurfaces", flowElementSkeleton: surfaceRow)
        componentSurfaces.modifiers = BindingPersonalCopilotDesignSystem.listCard(height: 180, role: "personal-list-row")

        var resourceRow = SkeletonVStack(elements: [
            .Text(personalBoundText("title", lineLimit: 1)),
            .Text(personalBoundText("kindLabel", lineLimit: 1)),
            .Text(personalBoundText("summary", lineLimit: 2)),
            .Text(personalBoundText("openHint", lineLimit: 2))
        ], spacing: 4)
        resourceRow.modifiers = BindingPersonalCopilotDesignSystem.sectionCard(role: "personal-list-row")
        var resourceMatches = SkeletonList(topic: nil, keypath: "chatHub.state.assistant.resourceMatches", flowElementSkeleton: resourceRow)
        resourceMatches.selectionMode = .single
        resourceMatches.selectionValueKeypath = "id"
        resourceMatches.selectionActionKeypath = "chatHub.ui.openMatchedResourceLibrary"
        resourceMatches.selectionPayloadMode = .itemID
        resourceMatches.modifiers = BindingPersonalCopilotDesignSystem.listCard(height: 180, role: "personal-list-row")

        var docsRow = SkeletonVStack(elements: [
            .Text(personalBoundText("title", lineLimit: 1)),
            .Text(personalBoundText("summary", lineLimit: 3))
        ], spacing: 4)
        docsRow.modifiers = BindingPersonalCopilotDesignSystem.sectionCard(role: "personal-list-row")
        var docsMatches = SkeletonList(topic: nil, keypath: "chatHub.state.docsRAG.documentationMatches", flowElementSkeleton: docsRow)
        docsMatches.selectionMode = .single
        docsMatches.selectionValueKeypath = "id"
        docsMatches.selectionActionKeypath = "chatHub.docsRAG.openTopDocument"
        docsMatches.selectionPayloadMode = .itemID
        docsMatches.modifiers = BindingPersonalCopilotDesignSystem.listCard(height: 160, role: "personal-list-row")

        var ragMatches = SkeletonList(topic: nil, keypath: "chatHub.state.docsRAG.ragMatches", flowElementSkeleton: docsRow)
        ragMatches.selectionMode = .single
        ragMatches.selectionValueKeypath = "id"
        ragMatches.selectionActionKeypath = "chatHub.docsRAG.askRAG"
        ragMatches.selectionPayloadMode = .itemID
        ragMatches.modifiers = BindingPersonalCopilotDesignSystem.listCard(height: 160, role: "personal-list-row")

        var activeToolChipRow = SkeletonVStack(elements: [
            .HStack(SkeletonHStack(elements: [
                .Text(personalBoundText("title", lineLimit: 1)),
                .Button(button("chatHub.ui.dismissComponentSurface", "Fjern", style: .secondary))
            ], spacing: 6))
        ], spacing: 4)
        activeToolChipRow.modifiers = modifier {
            $0.padding = 6
            $0.background = BindingPersonalCopilotDesignSystem.surfaceMuted
            $0.cornerRadius = 999
            $0.borderWidth = 1
            $0.borderColor = BindingPersonalCopilotDesignSystem.border
            $0.styleRole = "chat-active-tool-chip"
            $0.styleClasses = ["chat-active-tool-chip"]
        }
        var activeToolChips = SkeletonList(
            topic: nil,
            keypath: "chatHub.state.ui.activeToolChips",
            flowElementSkeleton: activeToolChipRow
        )
        activeToolChips.activationActionKeypath = "chatHub.ui.dismissComponentSurface"
        activeToolChips.selectionValueKeypath = "id"
        activeToolChips.selectionPayloadMode = .itemID
        activeToolChips.modifiers = modifier {
            $0.styleRole = "chat-active-tool-chips"
            $0.styleClasses = ["chat-active-tool-chips"]
        }

        var providerRow = SkeletonVStack(elements: [
            .Text(personalBoundText("title", lineLimit: 1)),
            .Text(personalBoundText("availability", lineLimit: 1)),
            .Text(personalBoundText("kind", lineLimit: 1))
        ], spacing: 4)
        providerRow.modifiers = BindingPersonalCopilotDesignSystem.sectionCard(role: "personal-list-row")
        var providerList = SkeletonList(topic: nil, keypath: "chatHub.state.assistant.assistantProviders", flowElementSkeleton: providerRow)
        providerList.modifiers = BindingPersonalCopilotDesignSystem.listCard(height: 180, role: "personal-list-row")

        var helpSourceRow = SkeletonVStack(elements: [
            .Text(personalBoundText("title", lineLimit: 1)),
            .Text(personalBoundText("status", lineLimit: 1)),
            .Text(personalBoundText("summary", lineLimit: 3))
        ], spacing: 4)
        helpSourceRow.modifiers = BindingPersonalCopilotDesignSystem.sectionCard(role: "personal-list-row")
        var helpSources = SkeletonList(topic: nil, keypath: "chatHub.state.help.availableSources", flowElementSkeleton: helpSourceRow)
        helpSources.modifiers = BindingPersonalCopilotDesignSystem.listCard(height: 160, role: "personal-list-row")

        var perspectivePurposeName = SkeletonText(keypath: "purposeName")
        perspectivePurposeName.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = BindingPersonalCopilotDesignSystem.textPrimary
            $0.lineLimit = 1
        }
        var perspectivePurposeWeight = SkeletonText(keypath: "purposeWeight")
        perspectivePurposeWeight.modifiers = modifier {
            $0.foregroundColor = BindingPersonalCopilotDesignSystem.textSecondary
            $0.fontSize = 11
            $0.lineLimit = 1
        }
        var perspectivePurposeRow = SkeletonVStack(elements: [
            .Text(perspectivePurposeName),
            .Text(perspectivePurposeWeight)
        ], spacing: 4)
        perspectivePurposeRow.modifiers = BindingPersonalCopilotDesignSystem.sectionCard(role: "personal-list-row")
        var activePerspectivePurposes = SkeletonList(
            topic: nil,
            keypath: "perspective.activePurpose.purposes",
            flowElementSkeleton: perspectivePurposeRow
        )
        activePerspectivePurposes.modifiers = BindingPersonalCopilotDesignSystem.listCard(height: 140, role: "personal-list-row")

        let perspectiveContextPanel = personalSection(
            "Kontekst",
            content: [
                .Text(personalBodyText("Co-Pilot bruker lokal Perspective-kontekst for aa tolke utkastet mot formaal og interesser.")),
                .HStack(SkeletonHStack(elements: [
                    .VStack(SkeletonVStack(elements: [
                        .Text(personalLabelText("Aktive formål")),
                        .Text(personalBoundText("perspective.perspective.state.activePurposeCount", lineLimit: 1))
                    ], spacing: 2)),
                    .VStack(SkeletonVStack(elements: [
                        .Text(personalLabelText("Aktive interesser")),
                        .Text(personalBoundText("perspective.perspective.state.activeInterestCount", lineLimit: 1))
                    ], spacing: 2))
                ], spacing: 10)),
                .List(activePerspectivePurposes)
            ]
        )

        let inviteHelper = personalSection(
            "Inviter",
            role: "personal-consent-prompt",
            content: [
                .Text(personalBoundText("chatHub.state.assistant.latestSuggestion.explanation", lineLimit: 3)),
                .TextField(candidateField),
                .List(candidates),
                .TextField(inviteTitleField),
                .HStack(SkeletonHStack(elements: [
                    .Button(button("chatHub.invite", "Send invitasjon")),
                    .Button(button("chatHub.ui.minimizeComponentSurface", "Skjul", style: .secondary))
                ], spacing: 8))
            ],
            modifiers: BindingPersonalCopilotDesignSystem.sectionCard(role: "personal-consent-prompt")
        )

        let pollHelper = personalSection(
            "Avstemning",
            content: [
                .Text(personalBoundText("chatHub.state.assistant.pollPrerequisite", lineLimit: 2)),
                .TextField(pollQuestionField),
                .TextArea(pollOptionsField),
                .HStack(SkeletonHStack(elements: [
                    .Button(button("chatHub.poll.create", "Publiser avstemning")),
                    .Button(button("chatHub.poll.vote", "Stem forste", payload: .object(["optionID": .string("option-1")]), style: .secondary)),
                    .Button(button("chatHub.poll.close", "Lukk", style: .secondary))
                ], spacing: 8))
            ]
        )

        let resourceRouterHelper = personalSection(
            "Finn verktøy",
            content: [
                .Text(personalBoundText("chatHub.state.assistant.latestSuggestion.targetPhrase", lineLimit: 2)),
                .List(resourceMatches),
                .HStack(SkeletonHStack(elements: [
                    .Button(button("chatHub.ui.openMatchedResourceLibrary", "Last inn flaten", payload: .object(["autoOpen": .bool(true)]))),
                    .Button(button("chatHub.ui.openMatchedResourceLibrary", "Velg selv", payload: .object(["autoOpen": .bool(false)]), style: .secondary)),
                    .Button(button("chatHub.entityExtension.scan", "Skann tilgang", style: .secondary))
                ], spacing: 8))
            ]
        )

        let mermaidHelper = personalSection(
            "Mermaid diagram",
            content: [
                .Text(personalBoundText("chatHub.state.assistant.latestSuggestion.explanation", lineLimit: 3)),
                .TextArea(mermaidSourceField),
                .List(resourceMatches),
                .HStack(SkeletonHStack(elements: [
                    .Button(button("chatHub.ui.openMatchedResourceLibrary", "Åpne diagramflate", payload: .object([
                        "resourceID": .string("configuration:mermaid-renderer-playground"),
                        "autoOpen": .bool(true)
                    ]))),
                    .Button(button("chatHub.ui.openMatchedResourceLibrary", "Velg i Library", payload: .object([
                        "resourceID": .string("configuration:mermaid-renderer-playground"),
                        "autoOpen": .bool(false)
                    ]), style: .secondary))
                ], spacing: 8))
            ]
        )

        let docsRAGHelper = personalSection(
            "Spør docs/RAG",
            content: [
                .TextArea(docsRAGQueryField),
                .HStack(SkeletonHStack(elements: [
                    .Button(button("chatHub.docsRAG.search", "Finn kilder")),
                    .Button(button("chatHub.docsRAG.openTopDocument", "Apne dokument", style: .secondary)),
                    .Button(button("chatHub.docsRAG.askRAG", "Spør RAG", style: .secondary))
                ], spacing: 8)),
                .Text(personalBoundText("chatHub.state.docsRAG.summary", lineLimit: 3)),
                .List(docsMatches),
                .Text(personalBoundText("chatHub.state.docsRAG.answer", lineLimit: 4)),
                .List(ragMatches)
            ]
        )

        let ideaHelper = personalSection(
            "Ide",
            content: [
                .TextField(ideaTitleField),
                .TextArea(ideaContentField),
                .HStack(SkeletonHStack(elements: [
                    .Button(button("chatHub.idea.capture", "Lagre ide")),
                    .Button(button("chatHub.ui.openMatchedResourceLibrary", "Apne ideflate", payload: .object([
                        "configurationName": .string("Idea Task Workspace"),
                        "sourceCellEndpoint": .string("cell:///IdeaTaskWorkspace"),
                        "autoOpen": .bool(true)
                    ]), style: .secondary))
                ], spacing: 8))
            ]
        )

        let workItemHelper = personalSection(
            "Feil / work item",
            content: [
                .TextField(workItemTitleField),
                .TextArea(workItemSummaryField),
                .TextField(workItemKindField),
                .TextArea(workItemCurrentField),
                .TextArea(workItemExpectedField),
                .HStack(SkeletonHStack(elements: [
                    .Button(button("chatHub.workItem.capture", "Registrer feil")),
                    .Button(button("chatHub.ui.minimizeComponentSurface", "Skjul", style: .secondary))
                ], spacing: 8))
            ]
        )

        let todoHelper = personalSection(
            "Oppgave",
            content: [
                .TextField(todoTitleField),
                .TextArea(todoNoteField),
                .TextField(todoDueField),
                .Button(button("chatHub.todo.create", "Opprett oppgave"))
            ]
        )

        let projectHelper = personalSection(
            "Prosjekt / ide",
            content: [
                .TextField(projectTitleField),
                .TextArea(projectDescriptionField),
                .Button(button("chatHub.project.create", "Opprett ide"))
            ]
        )

        let reminderHelper = personalSection(
            "Påminnelse",
            content: [
                .TextField(reminderTitleField),
                .TextField(reminderTimeField),
                .Button(button("chatHub.reminder.create", "Lagre paaminnelse"))
            ]
        )

        let meetingHelper = personalSection(
            "Møte / video",
            content: [
                .TextField(meetingTitleField),
                .TextField(meetingTimesField),
                .Button(button("chatHub.meeting.schedule", "Foresla mote"))
            ]
        )

        let voiceHelper = personalSection(
            "Tale",
            content: [
                .Text(personalBoundText("chatHub.state.voice.message", lineLimit: 2)),
                .Text(personalBoundText("chatHub.state.voice.finalTranscript", lineLimit: 3)),
                .HStack(SkeletonHStack(elements: [
                    .Button(button("chatHub.voice.requestPermission", "Mikrofon", style: .secondary)),
                    .Button(button("chatHub.voice.startListening", "Snakk", style: .secondary)),
                    .Button(button("chatHub.voice.stopListening", "Stopp", style: .secondary))
                ], spacing: 8)),
                .HStack(SkeletonHStack(elements: [
                    .Button(button("chatHub.voice.acceptTranscript", "Bruk tekst", style: .secondary)),
                    .Button(button("chatHub.voice.acceptTranscriptAndAnalyze", "Bruk + finn forslag", style: .secondary)),
                    .Button(button("chatHub.voice.clearTranscript", "Tøm tale", style: .secondary))
                ], spacing: 8))
            ]
        )

        let agentReviewHelper = personalSection(
            "Agent-review",
            content: [
                .TextField(agentActionField),
                .TextArea(agentReasonField),
                .HStack(SkeletonHStack(elements: [
                    .Button(button("chatHub.agent.review.create", "Lag review")),
                    .Button(button("chatHub.agent.review.execute", "Send til lokal review", style: .secondary))
                ], spacing: 8))
            ]
        )

        let capabilityHelper = personalSection(
            "Meld behov",
            content: [
                .TextField(capabilityTitleField),
                .TextArea(capabilitySummaryField),
                .HStack(SkeletonHStack(elements: [
                    .Button(button("chatHub.ui.setCapabilityDiscoveryEnabled", "Skru paa behovsradar", payload: .bool(true), style: .secondary)),
                    .Button(button("chatHub.capabilityRequest.submit", "Send behov"))
                ], spacing: 8))
            ]
        )

        func helperTabs(activeOnly: Bool = false, compact: Bool = false) -> SkeletonTabs {
            var panels = [
                SkeletonTabPanel(id: "invite", content: [inviteHelper]),
                SkeletonTabPanel(id: "poll", content: [pollHelper]),
                SkeletonTabPanel(id: "resource-router", content: [resourceRouterHelper]),
                SkeletonTabPanel(id: "mermaid-diagram", content: [mermaidHelper]),
                SkeletonTabPanel(id: "docs-rag", content: [docsRAGHelper]),
                SkeletonTabPanel(id: "idea-capture", content: [ideaHelper]),
                SkeletonTabPanel(id: "work-item", content: [workItemHelper]),
                SkeletonTabPanel(id: "todo", content: [todoHelper]),
                SkeletonTabPanel(id: "project", content: [projectHelper]),
                SkeletonTabPanel(id: "reminder", content: [reminderHelper]),
                SkeletonTabPanel(id: "meeting", content: [meetingHelper]),
                SkeletonTabPanel(id: "agent-review", content: [agentReviewHelper]),
                SkeletonTabPanel(id: "capability-request", content: [capabilityHelper])
            ]
            if activeOnly == false {
                panels.insert(SkeletonTabPanel(id: "voice-input", content: [voiceHelper]), at: 11)
            }
            var tabs = SkeletonTabs(
                tabsKeypath: activeOnly ? "chatHub.state.ui.activeHelpers" : "chatHub.state.ui.helpers",
                activeTabStateKeypath: "chatHub.state.ui.activeHelper",
                selectionActionKeypath: "chatHub.ui.setActiveHelper",
                idKeypath: "id",
                labelKeypath: "title",
                panels: panels
            )
            tabs.modifiers = modifier {
                $0.styleRole = compact ? "chat-helper-tabs-compact" : "chat-helper-tabs"
                $0.styleClasses = compact ? ["chat-helper-tabs", "chat-helper-tabs-compact"] : ["chat-helper-tabs"]
            }
            return tabs
        }

        var primaryActionHint = personalBoundText("chatHub.state.ui.primaryActionHint", lineLimit: 3)
        primaryActionHint.modifiers?.foregroundColor = BindingPersonalCopilotDesignSystem.textSecondary
        primaryActionHint.modifiers?.styleRole = "chat-safety-hint"
        primaryActionHint.modifiers?.fontSize = 12

        let primaryPromptButton = button(
            "chatHub.ui.openSuggestedHelper",
            "↑",
            style: .iconPrimary
        )
        var primaryActionStack = SkeletonVStack(
            elements: [
                .Button(primaryPromptButton)
            ],
            spacing: 0
        )
        primaryActionStack.modifiers = modifier {
            $0.hAlignment = "trailing"
            $0.styleRole = "chat-primary-action"
        }
        var composerStack = SkeletonVStack(elements: [
            .TextArea(composer),
            .VStack(primaryActionStack)
        ], spacing: 10)
        composerStack.modifiers = modifier {
            $0.maxWidthInfinity = true
            $0.styleRole = "personal-draft-composer"
        }

        let conversationPanel: [SkeletonElement] = [
            personalCompactSection(
                "Skriv",
                role: "personal-draft-composer",
                content: [
                    .Text(personalBodyText("Hva vil du få gjort?", lineLimit: 1)),
                    .Text(personalLabelText("Logg")),
                    .List(promptMessages),
                    .VStack(composerStack),
                    .Text(primaryActionHint),
                    .Text(personalBoundText("chatHub.state.assistant.whySummary", lineLimit: 3)),
                    .List(activeToolChips),
                    .Tabs(helperTabs(activeOnly: true, compact: true))
                ],
                modifiers: BindingPersonalCopilotDesignSystem.chatSectionCard()
            )
        ]

        let activePanel: [SkeletonElement] = [
            personalSection(
                "Chat-tråder",
                content: [
                    .Text(personalBodyText("Sendte chatmeldinger grupperes her. Forslag og helperåpning ligger i promptloggen og sender ikke melding.")),
                    .List(threads),
                    .List(messages)
                ]
            ),
            personalSection(
                "Apne hjelpere",
                content: [
                    .Text(personalBodyText("Hjelpere som apnes fra forslag vises her som UI-flater. De oppretter ikke poll, invite eller agentjobb uten eget bekreftelsestrinn.")),
                    .List(activeToolChips),
                    .List(componentSurfaces),
                    .HStack(SkeletonHStack(elements: [
                        .Button(button("chatHub.ui.minimizeComponentSurface", "Minimer", style: .secondary)),
                        .Button(button("chatHub.ui.restoreComponentSurface", "Gjenopprett", style: .secondary)),
                        .Button(button("chatHub.ui.dismissComponentSurface", "Lukk", style: .secondary))
                    ]))
                ]
            ),
            personalSection(
                "Ventende invitasjoner",
                content: [
                    .Text(personalBodyText("Nye invitasjoner dukker opp her. Godta eller avslutt dem eksplisitt.")),
                    .List(invites),
                    .HStack(SkeletonHStack(elements: [
                        .Button(button("chatHub.acceptInvite", "Godta", style: .secondary)),
                        .Button(button("chatHub.declineInvite", "Avslaa", style: .warning))
                    ]))
                ]
            ),
            personalSection(
                "Avstemninger",
                content: [
                    .Text(personalBodyText("Aktive polls i chatten vises her naar de finnes.")),
                    .List(polls),
                    .HStack(SkeletonHStack(elements: [
                        .Button(button("chatHub.poll.vote", "Stem forste", payload: .object(["optionID": .string("option-1")]), style: .secondary)),
                        .Button(button("chatHub.poll.close", "Lukk poll", style: .secondary))
                    ]))
                ]
            ),
            personalSection(
                "Opprettet fra chat",
                content: [
                    .Text(personalBodyText("Dette er ting chatten faktisk har opprettet eller delegert videre etter et eksplisitt klikk.")),
                    .List(workbenchModules)
                ]
            ),
            personalSection(
                "Meldte behov",
                content: [
                    .Text(personalBodyText("Behov vises bare etter frivillig innsending fra denne chatten.")),
                    .List(capabilityRequests)
                ]
            )
        ]

        let toolsPanel = personalSection(
            "Verktoy",
            content: [
                .HStack(SkeletonHStack(elements: [
                    .Button(button("chatHub.clearComposer", "Rydd utkast", style: .secondary)),
                    .Button(button("chatHub.assistant.dismissSuggestion", "Avvis forslag", style: .secondary))
                ], spacing: 8)),
                .Tabs(helperTabs())
            ]
        )

        let helpPanel = personalSection(
            "Hjelp",
            content: [
                .Text(personalBodyText("Skriv hva du vil oppnaa i klartekst. Flaten er laget for chat-first, ikke for tekniske felt.")),
                .Text(personalBodyText("Bruk navn, kallenavn eller relasjoner som \"naermeste kollega\". Assistenten kan foreslaa neste steg, men sender aldri noe alene.")),
                .HStack(SkeletonHStack(elements: [
                    .Button(button("chatHub.help.openContextual", "Bruk aktiv kontekst")),
                    .Button(button("chatHub.docsRAG.search", "Finn kilder", style: .secondary))
                ], spacing: 8)),
                .Text(personalBoundText("chatHub.state.help.summary", lineLimit: 3)),
                .Text(personalBoundText("chatHub.state.help.suggestedPrompt", lineLimit: 5)),
                .List(helpSources),
                perspectiveContextPanel
            ]
        )

        let aiPanel = personalSection(
            "AI",
            content: [
                .Text(personalBodyText("Provider velges bare blant provider-celler som finnes i denne chat-scopen.")),
                .Text(personalBoundText("chatHub.state.assistant.providerRecommendation.title", lineLimit: 1)),
                .Text(personalBoundText("chatHub.state.assistant.providerRecommendation.reason", lineLimit: 3)),
                .HStack(SkeletonHStack(elements: [
                    .Button(button("chatHub.assistant.provider.recommend", "Velg beste provider")),
                    .Button(button("chatHub.assistant.queryResource", "Spor tilgjengelig RAG", style: .secondary))
                ]))
            ]
        )

        let moderationPanel = personalSection(
            "Moderering",
            role: "personal-audit-row",
            content: [
                .Text(personalBodyText("Rapportering og blokkering overstyrer alltid assistentforslag.")),
                .HStack(SkeletonHStack(elements: [
                    .Button(button("chatHub.reportMessage", "Rapporter siste", payload: .object(["reason": .string("user_reported_from_chat")]), style: .warning)),
                    .Button(button("chatHub.blockUser", "Blokker deltaker", style: .warning)),
                    .Button(button("chatHub.unblockUser", "Opphev blokk", style: .secondary))
                ]))
            ],
            modifiers: BindingPersonalCopilotDesignSystem.sectionCard(role: "personal-audit-row")
        )

        let privacyPanel = personalSection(
            "Personvern",
            content: [
                .Text(personalBodyText("Co-piloten leser kun utkastet ditt naar du ber om forslag. RAG og agent-review krever egne klikk.")),
                .HStack(SkeletonHStack(elements: [
                    .Button(button("chatHub.ui.setLearningEnabled", "Stopp laering", payload: .bool(false), style: .secondary)),
                    .Button(button("chatHub.ui.setLearningEnabled", "Tillat laering", payload: .bool(true), style: .secondary)),
                    .Button(button("chatHub.ui.setCapabilityDiscoveryEnabled", "Skru av behovsradar", payload: .bool(false), style: .secondary)),
                    .Button(button("chatHub.ui.setShowAdvanced", "Vis avansert", payload: .bool(true), style: .secondary))
                ]))
            ]
        )

        let advancedPanel = personalSection(
            "Avansert",
            content: [
                .Text(personalBodyText("Tekniske detaljer ligger her for feilsoking og paritetstesting, ikke i standard Samtale-visning.")),
                .Text(personalBoundText("chatHub.state.assistant.providerRecommendation.kind", lineLimit: 1)),
                .Text(personalBoundText("chatHub.state.assistant.providerRecommendation.executionScope", lineLimit: 1)),
                .Text(personalBoundText("chatHub.state.assistant.whySummary", lineLimit: 4)),
                .Text(personalBoundText("chatHub.state.assistant.promptUnderstanding.userGoal", lineLimit: 3)),
                .Text(personalBoundText("chatHub.state.assistant.groundedActionPlan.explanation", lineLimit: 4)),
                .Text(personalBoundText("chatHub.state.assistant.purposeContext.summary", lineLimit: 3)),
                .Text(personalBoundText("chatHub.state.assistant.purposeContext.purposeTreeExcerpt", lineLimit: 4)),
                .Text(personalBoundText("chatHub.state.assistant.purposeContext.interestTreeExcerpt", lineLimit: 4)),
                .List(providerList)
            ]
        )

        var moreTabs = SkeletonTabs(
            tabsKeypath: "chatHub.state.ui.moreTabs",
            activeTabStateKeypath: "chatHub.state.ui.activeMoreTab",
            selectionActionKeypath: "chatHub.ui.setActiveMoreTab",
            idKeypath: "id",
            labelKeypath: "title",
            panels: [
                SkeletonTabPanel(id: "verktoy", content: [toolsPanel]),
                SkeletonTabPanel(id: "hjelp", content: [helpPanel]),
                SkeletonTabPanel(id: "ai", content: [aiPanel]),
                SkeletonTabPanel(id: "moderering", content: [moderationPanel]),
                SkeletonTabPanel(id: "personvern", content: [privacyPanel]),
                SkeletonTabPanel(id: "avansert", content: [advancedPanel])
            ]
        )
        moreTabs.modifiers = modifier {
            $0.styleRole = "tabstrip"
        }

        let morePanel: [SkeletonElement] = [
            .Tabs(moreTabs)
        ]

        var tabs = SkeletonTabs(
            tabsKeypath: "chatHub.state.ui.tabs",
            activeTabStateKeypath: "chatHub.state.ui.activeTab",
            selectionActionKeypath: "chatHub.ui.setActiveTab",
            idKeypath: "id",
            labelKeypath: "title",
            panels: [
                SkeletonTabPanel(id: "samtale", content: conversationPanel),
                SkeletonTabPanel(id: "aktivt", content: activePanel),
                SkeletonTabPanel(id: "mer", content: morePanel)
            ]
        )
        tabs.modifiers = modifier {
            $0.styleRole = "tabstrip"
        }

        configuration.skeleton = personalChatSurfacePage(
            title: "Co-Pilot",
            subtitle: "Skriv hva du vil oppnaa. Jeg foreslaar riktig hjelper før noe skjer.",
            chip: "CHAT",
            content: [
                .Tabs(tabs)
            ]
        )
        return configuration
    }

    nonisolated private static func personalIdentitySurfaceSkeleton() -> SkeletonElement {
        let exportButton = personalActionButton(
            keypath: "requestExport",
            label: "Request account export",
            url: "cell:///PersonalIdentity",
            payload: .bool(true)
        )
        let deleteButton = personalActionButton(
            keypath: "requestAccountDelete",
            label: "Request account deletion",
            url: "cell:///PersonalIdentity",
            payload: .bool(true),
            style: .warning
        )
        let cancelDeleteButton = personalActionButton(
            keypath: "cancelAccountDelete",
            label: "Cancel deletion request",
            url: "cell:///PersonalIdentity",
            payload: .bool(true),
            style: .secondary
        )
        let openPublishButton = personalDispatchActionButton(
            "personalNavigator",
            endpoint: "cell:///PersonalCopilotNavigator",
            actionKeypath: "navigator.openPublishPublicProfile",
            label: "Manage public identity",
            style: .secondary
        )
        let openProfileButton = personalDispatchActionButton(
            "personalNavigator",
            endpoint: "cell:///PersonalCopilotNavigator",
            actionKeypath: "navigator.openMyProfile",
            label: "Open profile",
            style: .secondary
        )
        let openPrivacyAuditButton = personalDispatchActionButton(
            "personalNavigator",
            endpoint: "cell:///PersonalCopilotNavigator",
            actionKeypath: "navigator.openPrivacyAudit",
            label: "Open privacy audit",
            style: .secondary
        )

        return personalSurfacePage(
            title: "Personal Home",
            subtitle: "Start med profil og personvern. Eksport og sletting ligger som egne kontohandlinger.",
            chip: "ON DEVICE",
            content: [
                personalSection(
                    "Quick actions",
                    role: "personal-action-row",
                    content: [
                        .Text(personalBoundText("identity.state.status", lineLimit: 3)),
                        .HStack(SkeletonHStack(elements: [
                            .Button(exportButton)
                        ], spacing: 8)),
                        personalKeyValueRow("Identity mode", keypath: "identity.state.identityMode", accent: BindingPersonalCopilotDesignSystem.warning),
                        personalKeyValueRow("Export", keypath: "identity.state.exportStatus", accent: BindingPersonalCopilotDesignSystem.textTertiary)
                    ]
                ),
                personalSection(
                    "Overview",
                    role: "personal-card",
                    content: [
                        personalStatusActionCard(
                            "Public identity",
                            keypath: "identity.state.publicIdentityStatus",
                            accent: BindingPersonalCopilotDesignSystem.brandPrimary,
                            button: openPublishButton,
                            supportingText: "Publisering og avpublisering skjer i en egen, samtykkestyrt flate."
                        ),
                        personalStatusActionCard(
                            "Profile",
                            keypath: "profileDraft.state.publishedStatus",
                            accent: BindingPersonalCopilotDesignSystem.success,
                            button: openProfileButton,
                            supportingText: "Rediger det private profilutkastet ditt uten å forlate lokal modus."
                        ),
                        personalStatusActionCard(
                            "Privacy audit",
                            keypath: "privacyAudit.state.status",
                            accent: BindingPersonalCopilotDesignSystem.textTertiary,
                            button: openPrivacyAuditButton,
                            supportingText: "Se lokal samtykke- og aktivitetshistorikk før du går videre."
                        )
                    ]
                ),
                personalSection(
                    "Danger zone",
                    role: "personal-card",
                    content: [
                        .Text(personalBodyText("Sletting er separat fra vanlig profilbruk og krever en tydelig ekstra bekreftelse.")),
                        personalKeyValueRow("Deletion", keypath: "identity.state.deleteStatus", accent: BindingPersonalCopilotDesignSystem.danger),
                        .HStack(SkeletonHStack(elements: [
                            .Button(deleteButton),
                            .Button(cancelDeleteButton)
                        ], spacing: 8))
                    ],
                    modifiers: BindingPersonalCopilotDesignSystem.dangerSectionCard()
                )
            ]
        )
    }

    nonisolated private static func personalProfileDraftSurfaceSkeleton() -> SkeletonElement {
        let displayNameField = SkeletonTextField(
            text: nil,
            sourceKeypath: "profileDraft.state.draft.displayName",
            targetKeypath: "profileDraft.profile.displayName",
            placeholder: "Display name",
            modifiers: BindingPersonalCopilotDesignSystem.fieldCard()
        )
        let headlineField = SkeletonTextField(
            text: nil,
            sourceKeypath: "profileDraft.state.draft.headline",
            targetKeypath: "profileDraft.profile.headline",
            placeholder: "Headline",
            modifiers: BindingPersonalCopilotDesignSystem.fieldCard()
        )
        let summaryField = SkeletonTextArea(
            text: nil,
            sourceKeypath: "profileDraft.state.draft.summary",
            targetKeypath: "profileDraft.profile.summary",
            placeholder: "Kort privat profiltekst. Publisering krever preview og eksplisitt samtykke.",
            minLines: 4,
            maxLines: 8,
            submitOnEnter: false,
            modifiers: BindingPersonalCopilotDesignSystem.fieldCard()
        )

        let previewButton = personalActionButton(
            keypath: "profileDraft.preparePublishPreview",
            label: "Prepare preview",
            payload: .bool(true)
        )
        let consentButton = personalActionButton(
            keypath: "profileDraft.recordPublishConsent",
            label: "Record consent",
            payload: .bool(true),
            style: .secondary
        )
        let resetButton = personalActionButton(
            keypath: "profileDraft.resetDraft",
            label: "Reset draft",
            payload: .bool(true),
            style: .warning
        )

        return personalSurfacePage(
            title: "My Profile",
            subtitle: "Rediger privat profilutkast lokalt. Preview og publisering skjer som eksplisitte steg.",
            chip: "LOCAL DRAFT",
            content: [
                personalSection(
                    "Draft fields",
                    role: "personal-draft-composer",
                    content: [
                        .Text(personalLabelText("DISPLAY NAME")),
                        .TextField(displayNameField),
                        .Text(personalLabelText("HEADLINE")),
                        .TextField(headlineField),
                        .Text(personalLabelText("SUMMARY")),
                        .TextArea(summaryField)
                    ]
                ),
                personalSection(
                    "Publish readiness",
                    role: "personal-publish-confirmation",
                    content: [
                        personalKeyValueRow("Status", keypath: "profileDraft.state.publishedStatus", accent: BindingPersonalCopilotDesignSystem.brandPrimary),
                        personalKeyValueRow("Preview", keypath: "profileDraft.state.publishPreview.summary", accent: BindingPersonalCopilotDesignSystem.success),
                        personalKeyValueRow("Consent", keypath: "profileDraft.state.requiresExplicitConsent", accent: BindingPersonalCopilotDesignSystem.warning),
                        .HStack(SkeletonHStack(elements: [
                            .Button(previewButton),
                            .Button(consentButton),
                            .Button(resetButton)
                        ], spacing: 8)),
                        .Text(personalBoundText("profileDraft.state.status", lineLimit: 3))
                    ]
                )
            ]
        )
    }

    nonisolated private static func personalPublishPublicProfileSurfaceSkeleton() -> SkeletonElement {
        let previewButton = personalActionButton(
            keypath: "profileDraft.preparePublishPreview",
            label: "Prepare preview",
            payload: .bool(true)
        )
        let consentButton = personalActionButton(
            keypath: "profileDraft.recordPublishConsent",
            label: "Record consent",
            payload: .bool(true),
            style: .secondary
        )
        let auditButton = personalActionButton(
            keypath: "privacyAudit.audit.record",
            label: "Record audit",
            payload: .string("Public profile publish consent reviewed."),
            style: .secondary
        )
        let publishButton = personalActionButton(
            keypath: "profilePublisher.publishProfile",
            label: "Publish approved preview",
            payload: .object(["explicitPublishIntent": .bool(true)])
        )
        let unpublishButton = personalActionButton(
            keypath: "profilePublisher.unpublishProfile",
            label: "Unpublish",
            payload: .object([:]),
            style: .secondary
        )
        let deleteButton = personalActionButton(
            keypath: "profilePublisher.deleteProfile",
            label: "Delete public profile",
            payload: .object([:]),
            style: .warning
        )
        let displayNameField = SkeletonTextField(
            text: nil,
            sourceKeypath: "profilePublisher.state.publishDraft.displayName",
            targetKeypath: "profilePublisher.publishDraft.displayName",
            placeholder: "Public display name",
            modifiers: BindingPersonalCopilotDesignSystem.fieldCard()
        )
        let headlineField = SkeletonTextField(
            text: nil,
            sourceKeypath: "profilePublisher.state.publishDraft.headline",
            targetKeypath: "profilePublisher.publishDraft.headline",
            placeholder: "Public headline",
            modifiers: BindingPersonalCopilotDesignSystem.fieldCard()
        )
        let summaryField = SkeletonTextArea(
            text: nil,
            sourceKeypath: "profilePublisher.state.publishDraft.summary",
            targetKeypath: "profilePublisher.publishDraft.summary",
            placeholder: "Public summary",
            minLines: 3,
            maxLines: 7,
            submitOnEnter: false,
            modifiers: BindingPersonalCopilotDesignSystem.fieldCard()
        )
        let interestsField = SkeletonTextField(
            text: nil,
            sourceKeypath: "profilePublisher.state.publishDraft.interestsText",
            targetKeypath: "profilePublisher.publishDraft.interestsText",
            placeholder: "Public interests, comma separated",
            modifiers: BindingPersonalCopilotDesignSystem.fieldCard()
        )

        return personalSurfacePage(
            title: "Publish Public Profile",
            subtitle: "Publisering er en egen consent-gate: lokalt preview forst, eksplisitt samtykke, deretter remote publisher.",
            chip: "CONSENT GATED",
            content: [
                personalSection(
                    "Local readiness",
                    role: "personal-publish-confirmation",
                    content: [
                        personalKeyValueRow("Draft", keypath: "profileDraft.state.status", accent: BindingPersonalCopilotDesignSystem.brandPrimary),
                        personalKeyValueRow("Preview", keypath: "profileDraft.state.publishPreview.summary", accent: BindingPersonalCopilotDesignSystem.success),
                        personalKeyValueRow("Consent", keypath: "profileDraft.state.publishedStatus", accent: BindingPersonalCopilotDesignSystem.warning),
                        personalKeyValueRow("Audit", keypath: "privacyAudit.state.status", accent: BindingPersonalCopilotDesignSystem.textTertiary),
                        .HStack(SkeletonHStack(elements: [
                            .Button(previewButton),
                            .Button(consentButton),
                            .Button(auditButton)
                        ], spacing: 8))
                    ]
                ),
                personalSection(
                    "Remote publisher",
                    role: "personal-consent-prompt",
                    content: [
                        .Text(personalBodyText("Remote publisher brukes bare etter at preview og samtykke er registrert. Hvis remote ikke er tilgjengelig, skal wrapperen vise det aerlig.")),
                        personalKeyValueRow("Publish", keypath: "profilePublisher.state.publishStatus", accent: BindingPersonalCopilotDesignSystem.brandPrimary),
                        personalKeyValueRow("Visibility", keypath: "profilePublisher.state.visibility", accent: BindingPersonalCopilotDesignSystem.success),
                        .Text(personalLabelText("PUBLIC DISPLAY NAME")),
                        .TextField(displayNameField),
                        .Text(personalLabelText("PUBLIC HEADLINE")),
                        .TextField(headlineField),
                        .Text(personalLabelText("PUBLIC SUMMARY")),
                        .TextArea(summaryField),
                        .Text(personalLabelText("PUBLIC INTERESTS")),
                        .TextField(interestsField),
                        .HStack(SkeletonHStack(elements: [
                            .Button(publishButton),
                            .Button(unpublishButton),
                            .Button(deleteButton)
                        ], spacing: 8)),
                        personalKeyValueRow("Public name", keypath: "profilePublisher.state.publicReadModel.displayName", accent: BindingPersonalCopilotDesignSystem.brandPrimary),
                        personalKeyValueRow("Public summary", keypath: "profilePublisher.state.publicReadModel.summary", accent: BindingPersonalCopilotDesignSystem.textTertiary)
                    ]
                )
            ]
        )
    }

    nonisolated private static func personalPublicProfileDirectorySurfaceSkeleton() -> SkeletonElement {
        let queryField = SkeletonTextField(
            text: nil,
            sourceKeypath: "directory.state.query",
            targetKeypath: "directory.query",
            placeholder: "Search public profiles",
            modifiers: BindingPersonalCopilotDesignSystem.fieldCard()
        )
        let searchButton = personalActionButton(
            keypath: "directory.searchProfiles",
            label: "Search",
            payload: .object([:])
        )
        let detailButton = personalActionButton(
            keypath: "directory.profileDetail",
            label: "Profile detail",
            payload: .object([:]),
            style: .secondary
        )
        let reportButton = personalActionButton(
            keypath: "directory.reportProfile",
            label: "Report result",
            payload: .object(["reason": .string("user_reported_from_directory")]),
            style: .warning
        )
        let hideButton = personalActionButton(
            keypath: "directory.hideProfile",
            label: "Hide result",
            payload: .object([:]),
            style: .secondary
        )
        let blockButton = personalActionButton(
            keypath: "directory.blockProfile",
            label: "Block result",
            payload: .object([:]),
            style: .warning
        )

        var resultRow = SkeletonVStack(elements: [
            .Text(personalBoundText("displayName", lineLimit: 1)),
            .Text(personalBoundText("headline", lineLimit: 2)),
            .Text(personalBoundText("summary", lineLimit: 3)),
            .Text(personalBoundText("moderationStatus", lineLimit: 1))
        ], spacing: 4)
        resultRow.modifiers = BindingPersonalCopilotDesignSystem.sectionCard(role: "personal-list-row")

        var results = SkeletonList(
            topic: nil,
            keypath: "directory.state.lastSearch.results",
            flowElementSkeleton: resultRow
        )
        results.selectionMode = .single
        results.selectionValueKeypath = "id"
        results.modifiers = BindingPersonalCopilotDesignSystem.listCard(height: 260, role: "personal-list-row")

        return personalSurfacePage(
            title: "Public Profile Directory",
            subtitle: "Sok i profiler brukere har publisert. Report, hide og block virker paa valgt eller forste synlige resultat.",
            chip: "SAFE DIRECTORY",
            content: [
                personalSection(
                    "Directory search",
                    role: "personal-inline-field",
                    content: [
                        personalKeyValueRow("Moderation", keypath: "directory.state.moderationStatus", accent: BindingPersonalCopilotDesignSystem.warning),
                        .TextField(queryField),
                        .HStack(SkeletonHStack(elements: [
                            .Button(searchButton),
                            .Button(detailButton)
                        ], spacing: 8))
                    ]
                ),
                personalSection(
                    "Results",
                    role: "personal-list-row",
                    content: [
                        .List(results),
                        personalKeyValueRow("Blocked", keypath: "directory.state.blockedProfileCount", accent: BindingPersonalCopilotDesignSystem.textTertiary),
                        .HStack(SkeletonHStack(elements: [
                            .Button(reportButton),
                            .Button(hideButton),
                            .Button(blockButton)
                        ], spacing: 8))
                    ]
                )
            ]
        )
    }

    nonisolated private static func personalMatchesSurfaceSkeleton() -> SkeletonElement {
        let preferencesField = SkeletonTextField(
            text: nil,
            sourceKeypath: "matchmaking.state.preferencesText",
            targetKeypath: "matchmaking.preferencesText",
            placeholder: "Preferences, comma separated",
            modifiers: BindingPersonalCopilotDesignSystem.fieldCard()
        )
        let refreshButton = personalActionButton(
            keypath: "matchmaking.refreshSuggestions",
            label: "Refresh suggestions",
            payload: .object([:])
        )
        let requestConsentButton = personalActionButton(
            keypath: "matchmaking.requestMatchConsent",
            label: "Request consent",
            payload: .object([:]),
            style: .secondary
        )
        let approveButton = personalActionButton(
            keypath: "matchmaking.acceptMatchConsent",
            label: "Approve match",
            payload: .object([:])
        )
        let declineButton = personalActionButton(
            keypath: "matchmaking.declineMatchConsent",
            label: "Decline",
            payload: .object([:]),
            style: .warning
        )
        let clearButton = personalActionButton(
            keypath: "matchmaking.clearMatchSuggestion",
            label: "Clear suggestion",
            payload: .object([:]),
            style: .secondary
        )
        let auditButton = personalActionButton(
            keypath: "privacyAudit.audit.record",
            label: "Record match audit",
            payload: .string("Match consent action reviewed."),
            style: .secondary
        )

        var suggestionRow = SkeletonVStack(elements: [
            .Text(personalBoundText("profile.displayName", lineLimit: 1)),
            .Text(personalBoundText("profile.headline", lineLimit: 2)),
            .Text(personalBoundText("reasons", lineLimit: 3)),
            .Text(personalBoundText("chatEligible", lineLimit: 1))
        ], spacing: 4)
        suggestionRow.modifiers = BindingPersonalCopilotDesignSystem.sectionCard(role: "personal-match-card")

        var suggestions = SkeletonList(
            topic: nil,
            keypath: "matchmaking.state.matchSuggestions",
            flowElementSkeleton: suggestionRow
        )
        suggestions.selectionMode = .single
        suggestions.selectionValueKeypath = "id"
        suggestions.modifiers = BindingPersonalCopilotDesignSystem.listCard(height: 260, role: "personal-match-card")

        return personalSurfacePage(
            title: "Matches",
            subtitle: "Matchforslag er remote i V1, men flaten viser tydelig samtykke, profilforutsetning og chat-gate lokalt.",
            chip: "CONSENT MATCHING",
            content: [
                personalSection(
                    "Matchmaking contract",
                    role: "personal-match-card",
                    content: [
                        personalKeyValueRow("Mutual approval", keypath: "matchmaking.state.requiresMutualApprovalForChat", accent: BindingPersonalCopilotDesignSystem.brandPrimary),
                        .TextField(preferencesField),
                        .HStack(SkeletonHStack(elements: [
                            .Button(refreshButton),
                            .Button(requestConsentButton)
                        ], spacing: 8)),
                        .HStack(SkeletonHStack(elements: [
                            .Button(approveButton),
                            .Button(declineButton),
                            .Button(clearButton)
                        ], spacing: 8)),
                        .List(suggestions),
                        personalKeyValueRow("Consent", keypath: "matchmaking.state.matchConsentStatus", accent: BindingPersonalCopilotDesignSystem.success)
                    ]
                ),
                personalSection(
                    "Local guardrails",
                    role: "personal-consent-prompt",
                    content: [
                        personalKeyValueRow("Profile", keypath: "profileDraft.state.publishedStatus", accent: BindingPersonalCopilotDesignSystem.warning),
                        personalKeyValueRow("Chat", keypath: "chatClient.state.inviteStatus", accent: BindingPersonalCopilotDesignSystem.success),
                        personalKeyValueRow("Audit", keypath: "privacyAudit.state.status", accent: BindingPersonalCopilotDesignSystem.textTertiary),
                        .Text(personalBodyText("Chat kan ikke starte bare fordi matching foreslar noen. Begge parter maa eksplisitt akseptere invitasjon.")),
                        .Button(auditButton)
                    ]
                )
            ]
        )
    }

    nonisolated private static func personalVaultIdeasSurfaceSkeleton() -> SkeletonElement {
        let ideaPayload: ValueType = .object([
            "id": .string("personal-idea-seed"),
            "title": .string("Personal idea seed"),
            "content": .string("En lokal ide som kan utvikles videre uten at remote flater faar vault-tilgang."),
            "tags": .list([.string("personal"), .string("idea")]),
            "createdAtEpochMs": .integer(0),
            "updatedAtEpochMs": .integer(0)
        ])
        let projectPayload: ValueType = .object([
            "id": .string("personal-project-seed"),
            "title": .string("Personal project seed"),
            "content": .string("Et lokalt prosjektkort med neste steg, notater og koblinger til [[personal-idea-seed]]."),
            "tags": .list([.string("personal"), .string("project")]),
            "createdAtEpochMs": .integer(0),
            "updatedAtEpochMs": .integer(0)
        ])
        let graphPayload: ValueType = .object([
            "notes": .list([
                ideaPayload,
                projectPayload,
                .object([
                    "id": .string("next-step-seed"),
                    "title": .string("Next step"),
                    "content": .string("Avklar første leveranse og koble den til [[personal-project-seed]]."),
                    "tags": .list([.string("personal"), .string("next-step")]),
                    "createdAtEpochMs": .integer(0),
                    "updatedAtEpochMs": .integer(0)
                ])
            ])
        ])
        let graphSpec: ValueType = .object([
            "nodes": .list([
                .object([
                    "id": .string("personal-idea-seed"),
                    "label": .string("Ide"),
                    "x": .float(0.2),
                    "y": .float(0.35),
                    "color": .string("#9333EA")
                ]),
                .object([
                    "id": .string("personal-project-seed"),
                    "label": .string("Prosjekt"),
                    "x": .float(0.55),
                    "y": .float(0.5),
                    "color": .string("#2563EB")
                ]),
                .object([
                    "id": .string("next-step-seed"),
                    "label": .string("Neste steg"),
                    "x": .float(0.82),
                    "y": .float(0.32),
                    "color": .string("#059669")
                ])
            ]),
            "edges": .list([
                .object([
                    "id": .string("idea-project"),
                    "source": .string("personal-idea-seed"),
                    "target": .string("personal-project-seed")
                ]),
                .object([
                    "id": .string("project-next-step"),
                    "source": .string("personal-project-seed"),
                    "target": .string("next-step-seed")
                ])
            ])
        ])
        let seedIdea = personalActionButton(
            keypath: "vault.note.create",
            label: "Seed idea",
            url: "cell:///Vault",
            payload: ideaPayload
        )
        let seedProject = personalActionButton(
            keypath: "vault.note.create",
            label: "Seed project",
            url: "cell:///Vault",
            payload: projectPayload,
            style: .secondary
        )
        let reindexGraph = personalActionButton(
            keypath: "graph.reindex",
            label: "Reindex graf",
            url: "cell:///GraphIndex",
            payload: graphPayload
        )
        let neighbors = personalActionButton(
            keypath: "graph.neighbors",
            label: "Naboer",
            url: "cell:///GraphIndex",
            payload: .string("personal-project-seed"),
            style: .secondary
        )
        let noteRow = SkeletonVStack(elements: [
            .Text(personalBoundText("title", lineLimit: 1)),
            .Text(personalBoundText("content", lineLimit: 3))
        ], spacing: 4)
        var noteList = SkeletonList(topic: nil, keypath: "vault.vault.state.notes", flowElementSkeleton: noteRow)
        noteList.modifiers = BindingPersonalCopilotDesignSystem.listCard(height: 180, role: "personal-list-row")
        var graphPreview = SkeletonVisualization(
            kind: "graph",
            keypath: nil,
            stateKeypath: nil,
            actionKeypath: nil,
            spec: graphSpec
        )
        graphPreview.modifiers = modifier {
            $0.styleRole = "personal-knowledge-graph"
            $0.styleClasses = ["personal-knowledge-graph", "obsidian-graph-preview"]
            $0.background = "#F8FAFC"
            $0.borderColor = "#CBD5E1"
            $0.borderWidth = 1
            $0.cornerRadius = 12
            $0.padding = 8
        }

        return personalSurfacePage(
            title: "Vault / Ideas",
            subtitle: "Opprett lokale ideer, prosjektnotater og en Obsidian-lignende graf. Remote flater faar ikke vault-innhold uten eksplisitt eksport eller deling.",
            chip: "LOCAL VAULT",
            content: [
                personalSection(
                    "Vault status",
                    role: "personal-grid-tile",
                    content: [
                        personalKeyValueRow("State", keypath: "vault.vault.state", accent: BindingPersonalCopilotDesignSystem.success)
                    ]
                ),
                personalSection(
                    "Local seeds",
                    role: "personal-action-row",
                    content: [
                        .Text(personalBodyText("Seed-knappene skriver bare til lokal VaultCell. Dette gir flaten en faktisk testbar ide/prosjekt-flyt i stedet for et statisk kort.")),
                        .HStack(SkeletonHStack(elements: [.Button(seedIdea), .Button(seedProject)], spacing: 8))
                    ]
                ),
                personalSection(
                    "Prosjektstyring",
                    role: "personal-list-row",
                    content: [
                        .Text(personalBodyText("Ideer og prosjekter vises fra lokal vault-state etter eksplisitt seed eller senere capture.")),
                        .List(noteList)
                    ]
                ),
                personalSection(
                    "Obsidian graph",
                    role: "personal-graph-preview",
                    content: [
                        .Visualization(graphPreview),
                        .HStack(SkeletonHStack(elements: [.Button(reindexGraph), .Button(neighbors)], spacing: 8)),
                        personalKeyValueRow("Nodes", keypath: "graph.state.node_count", accent: BindingPersonalCopilotDesignSystem.brandPrimary),
                        personalKeyValueRow("Edges", keypath: "graph.state.edge_count", accent: BindingPersonalCopilotDesignSystem.success)
                    ]
                )
            ]
        )
    }

    nonisolated private static func personalMeetingIntentSurfaceSkeleton() -> SkeletonElement {
        let titleField = SkeletonTextField(
            text: nil,
            sourceKeypath: "meetingCoordinator.state.draft.title",
            targetKeypath: "meetingCoordinator.draft.title",
            placeholder: "Skriv en kort møtetittel",
            modifiers: BindingPersonalCopilotDesignSystem.fieldCard()
        )
        let targetProfileField = SkeletonTextField(
            text: nil,
            sourceKeypath: "meetingCoordinator.state.draft.targetProfileID",
            targetKeypath: "meetingCoordinator.draft.targetProfileID",
            placeholder: "Navn eller profil du vil avtale med",
            modifiers: BindingPersonalCopilotDesignSystem.fieldCard()
        )
        let proposedTimesField = SkeletonTextField(
            text: nil,
            sourceKeypath: "meetingCoordinator.state.draft.proposedTimesText",
            targetKeypath: "meetingCoordinator.draft.proposedTimesText",
            placeholder: "Foreslå tider i vanlig tekst",
            modifiers: BindingPersonalCopilotDesignSystem.fieldCard()
        )
        let proposeButton = personalActionButton(
            keypath: "meetingCoordinator.proposeTimes",
            label: "Foreslå tider",
            payload: .object([:])
        )
        let acceptButton = personalActionButton(
            keypath: "meetingCoordinator.acceptTime",
            label: "Godta første forslag",
            payload: .object([:]),
            style: .secondary
        )
        let declineButton = personalActionButton(
            keypath: "meetingCoordinator.declineTime",
            label: "Avslå første forslag",
            payload: .object([:]),
            style: .warning
        )
        let clearButton = personalActionButton(
            keypath: "meetingCoordinator.clearMeetingIntent",
            label: "Tøm utkast",
            payload: .object([:]),
            style: .secondary
        )

        return personalSurfacePage(
            title: "Meeting Intent",
            subtitle: "Foresla tider og vis Jitsi som metadata. Kamera, mikrofon og kalender bes ikke om her.",
            chip: "HYBRID INTENT",
            content: [
                personalSection(
                    "Møteutkast",
                    role: "personal-draft-composer",
                    content: [
                        .Text(personalLabelText("TITTEL")),
                        .TextField(titleField),
                        .Text(personalLabelText("HVEM")),
                        .TextField(targetProfileField),
                        .Text(personalLabelText("TIDER")),
                        .TextField(proposedTimesField),
                        .HStack(SkeletonHStack(elements: [
                            .Button(proposeButton),
                            .Button(acceptButton),
                            .Button(declineButton),
                            .Button(clearButton)
                        ], spacing: 8))
                    ]
                ),
                personalSection(
                    "Forslag",
                    role: "personal-key-value-block",
                    content: [
                        personalKeyValueRow("Status", keypath: "meetingCoordinator.state.coordinationStatus", accent: BindingPersonalCopilotDesignSystem.brandPrimary),
                        personalKeyValueRow("Video", keypath: "meetingCoordinator.state.meetingBridge.provider", accent: BindingPersonalCopilotDesignSystem.success),
                        personalKeyValueRow("Lenke", keypath: "meetingCoordinator.state.meetingBridge.joinURL", accent: BindingPersonalCopilotDesignSystem.textTertiary),
                        personalKeyValueRow("Samtykke", keypath: "meetingCoordinator.state.meetingBridge.requiresCameraMicrophoneConsent", accent: BindingPersonalCopilotDesignSystem.warning),
                        personalKeyValueRow("Enhetstilganger", keypath: "meetingCoordinator.state.nativePermissionRequests", accent: BindingPersonalCopilotDesignSystem.warning)
                    ]
                )
            ]
        )
    }

    nonisolated private static func personalPrivacyAuditSurfaceSkeleton() -> SkeletonElement {
        var entryKind = SkeletonText(keypath: "kind")
        entryKind.modifiers = modifier {
            $0.foregroundColor = BindingPersonalCopilotDesignSystem.brandPrimary
            $0.fontSize = 11
            $0.fontWeight = "medium"
            $0.lineLimit = 1
        }
        var entrySummary = SkeletonText(keypath: "summary")
        entrySummary.modifiers = modifier {
            $0.foregroundColor = BindingPersonalCopilotDesignSystem.textPrimary
            $0.fontSize = 13
            $0.lineLimit = 3
        }
        var entryCreated = SkeletonText(keypath: "createdAt")
        entryCreated.modifiers = modifier {
            $0.foregroundColor = BindingPersonalCopilotDesignSystem.textTertiary
            $0.fontSize = 11
            $0.lineLimit = 1
        }
        var entryRow = SkeletonVStack(elements: [.Text(entryKind), .Text(entrySummary), .Text(entryCreated)], spacing: 4)
        entryRow.modifiers = BindingPersonalCopilotDesignSystem.sectionCard(role: "personal-audit-row")

        var auditList = SkeletonList(
            topic: nil,
            keypath: "privacyAudit.state.audit.entries",
            flowElementSkeleton: entryRow
        )
        auditList.modifiers = BindingPersonalCopilotDesignSystem.listCard(height: 220, role: "personal-audit-row")

        let recordButton = personalActionButton(
            keypath: "privacyAudit.audit.record",
            label: "Record local audit entry",
            payload: .string("Manual privacy check from Privacy Audit surface.")
        )

        return personalSurfacePage(
            title: "Privacy Audit",
            subtitle: "Lokal logg for samtykker, publish-previews, chat-invitasjoner, remote loads og capability-gater.",
            chip: "LOCAL AUDIT",
            content: [
                personalSection(
                    "Audit state",
                    role: "personal-key-value-block",
                    content: [
                        personalKeyValueRow("Status", keypath: "privacyAudit.state.status", accent: BindingPersonalCopilotDesignSystem.success),
                        personalKeyValueRow("Updated", keypath: "privacyAudit.state.updatedAt", accent: BindingPersonalCopilotDesignSystem.textTertiary),
                        .HStack(SkeletonHStack(elements: [.Button(recordButton)], spacing: 8))
                    ]
                ),
                personalSection(
                    "Entries",
                    role: "personal-audit-row",
                    content: [
                        .List(auditList)
                    ]
                )
            ]
        )
    }

    nonisolated private static func personalCopilotCatalogSurfaceSkeleton() -> SkeletonElement {
        var entryRow = SkeletonVStack(elements: [
            .Text(personalBoundText("configuration.name", lineLimit: 1)),
            .Text(personalBoundText("metadata.policyCategory", lineLimit: 1)),
            .Text(personalBoundText("metadata.surfaceFamily", lineLimit: 1)),
            .Text(personalBoundText("metadata.executionScope", lineLimit: 1)),
            .Text(personalBoundText("metadata.reviewSummary", lineLimit: 3))
        ], spacing: 4)
        entryRow.modifiers = BindingPersonalCopilotDesignSystem.sectionCard(role: "personal-list-row")

        var entries = SkeletonList(
            topic: nil,
            keypath: "personalCatalog.catalogEntries",
            flowElementSkeleton: entryRow
        )
        entries.selectionMode = .none
        entries.modifiers = BindingPersonalCopilotDesignSystem.listCard(height: 320, role: "personal-list-row")

        return personalSurfacePage(
            title: "Personal Co-Pilot Catalog",
            subtitle: "Katalogen viser bare App Store-godkjente Personal Co-Pilot V1-flater.",
            chip: "APP STORE SCOPE",
            content: [
                personalSection(
                    "Policy",
                    role: "personal-key-value-block",
                    content: [
                        personalKeyValueRow("Scope", keypath: "personalCatalog.state.appStoreScope", accent: BindingPersonalCopilotDesignSystem.brandPrimary),
                        personalKeyValueRow("Count", keypath: "personalCatalog.state.configurationCount", accent: BindingPersonalCopilotDesignSystem.success),
                        personalKeyValueRow("Policy", keypath: "personalCatalog.state.policySummary", accent: BindingPersonalCopilotDesignSystem.textTertiary)
                    ]
                ),
                personalSection(
                    "Entries",
                    role: "personal-list-row",
                    content: [.List(entries)]
                )
            ]
        )
    }

    private enum PersonalButtonStyle {
        case primary
        case iconPrimary
        case secondary
        case warning
    }

    nonisolated private static func personalActionButton(
        keypath: String,
        label: String,
        url: String? = nil,
        payload: ValueType?,
        style: PersonalButtonStyle = .primary
    ) -> SkeletonButton {
        var button = SkeletonButton(keypath: keypath, label: label, url: url, payload: payload)
        switch style {
        case .primary:
            button.modifiers = BindingPersonalCopilotDesignSystem.primaryButton()
        case .iconPrimary:
            button.modifiers = BindingPersonalCopilotDesignSystem.promptIconButton()
        case .secondary:
            button.modifiers = BindingPersonalCopilotDesignSystem.secondaryButton()
        case .warning:
            button.modifiers = BindingPersonalCopilotDesignSystem.warningButton()
        }
        return button
    }

    nonisolated private static func personalDispatchActionButton(
        _ referenceLabel: String,
        endpoint: String? = nil,
        actionKeypath: String,
        label: String,
        payload: ValueType = .bool(true),
        style: PersonalButtonStyle = .secondary
    ) -> SkeletonButton {
        personalActionButton(
            keypath: endpoint == nil ? "\(referenceLabel).dispatchAction" : "dispatchAction",
            label: label,
            url: endpoint,
            payload: .object([
                "keypath": .string(actionKeypath),
                "payload": payload
            ]),
            style: style
        )
    }

    nonisolated private static func personalSurfacePage(
        title: String,
        subtitle: String,
        chip: String,
        content: [SkeletonElement],
        showsCopilotReturnAction: Bool = true
    ) -> SkeletonElement {
        var titleText = BindingPersonalCopilotDesignSystem.headingText(title)
        titleText.modifiers?.styleRole = "personal-hero"
        titleText.modifiers?.lineLimit = 1
        var chipText = SkeletonText(text: chip)
        chipText.modifiers = BindingPersonalCopilotDesignSystem.badgeModifier()
        let subtitleText = personalBodyText(subtitle, lineLimit: 2)
        let assistantButton = personalDispatchActionButton(
            "personalNavigator",
            endpoint: "cell:///PersonalCopilotNavigator",
            actionKeypath: "navigator.openCopilot",
            label: "Assistent",
            style: .secondary
        )

        var heroHeaderElements: [SkeletonElement] = [
            .Text(titleText),
            .Spacer(SkeletonSpacer()),
            .Text(chipText)
        ]
        if showsCopilotReturnAction {
            heroHeaderElements.append(.Button(assistantButton))
        }

        var heroHeader = SkeletonHStack(elements: heroHeaderElements, spacing: 10)
        heroHeader.modifiers = modifier {
            $0.maxWidthInfinity = true
        }

        var hero = SkeletonVStack(elements: [
            .HStack(heroHeader),
            .HStack(SkeletonHStack(elements: [
                .Text(subtitleText),
                .Spacer(SkeletonSpacer())
            ], spacing: 8))
        ], spacing: 6)
        hero.modifiers = BindingPersonalCopilotDesignSystem.compactHeroPanel()

        var root = SkeletonVStack(elements: [.VStack(hero)] + content, spacing: 10)
        root.modifiers = BindingPersonalCopilotDesignSystem.pageCard()

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.padding = 6
            $0.background = BindingPersonalCopilotDesignSystem.canvas
            $0.maxWidthInfinity = true
        }
        return .ScrollView(scroll)
    }

    nonisolated private static func personalChatSurfacePage(
        title: String,
        subtitle: String,
        chip: String,
        content: [SkeletonElement]
    ) -> SkeletonElement {
        var titleText = BindingPersonalCopilotDesignSystem.headingText(title)
        titleText.modifiers?.styleRole = "personal-chat-hero"
        titleText.modifiers?.lineLimit = 1
        var chipText = SkeletonText(text: chip)
        chipText.modifiers = BindingPersonalCopilotDesignSystem.badgeModifier()
        var subtitleText = personalBodyText(subtitle, lineLimit: 2)
        subtitleText.modifiers?.fontSize = 13

        var heroHeader = SkeletonHStack(elements: [
            .Text(titleText),
            .Spacer(SkeletonSpacer()),
            .Text(chipText)
        ], spacing: 8)
        heroHeader.modifiers = modifier {
            $0.maxWidthInfinity = true
        }

        var hero = SkeletonVStack(elements: [
            .HStack(heroHeader),
            .Text(subtitleText)
        ], spacing: 4)
        hero.modifiers = BindingPersonalCopilotDesignSystem.chatHeroPanel()

        var root = SkeletonVStack(elements: [.VStack(hero)] + content, spacing: 8)
        root.modifiers = BindingPersonalCopilotDesignSystem.chatPageShell()

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.background = BindingPersonalCopilotDesignSystem.surface
            $0.maxWidthInfinity = true
        }
        return .ScrollView(scroll)
    }

    nonisolated private static func withPersonalCopilotRecoveryAction(_ configuration: CellConfiguration) -> CellConfiguration {
        guard let skeleton = configuration.skeleton else { return configuration }

        var updated = configuration
        let assistantButton = personalDispatchActionButton(
            "personalNavigator",
            endpoint: "cell:///PersonalCopilotNavigator",
            actionKeypath: "navigator.openCopilot",
            label: "Assistent",
            style: .secondary
        )
        var container = SkeletonVStack(elements: [
            skeleton,
            .Button(assistantButton)
        ], spacing: 12)
        container.modifiers = modifier {
            $0.maxWidthInfinity = true
        }
        updated.skeleton = .VStack(container)
        return updated
    }

    nonisolated private static func personalSection(
        _ title: String,
        role: String = "personal-card",
        content: [SkeletonElement],
        modifiers: SkeletonModifiers? = nil
    ) -> SkeletonElement {
        var section = SkeletonSection(
            header: .Text(BindingPersonalCopilotDesignSystem.titleText(title)),
            content: content
        )
        section.modifiers = modifiers ?? BindingPersonalCopilotDesignSystem.sectionCard(role: role)
        return .Section(section)
    }

    nonisolated private static func personalCompactSection(
        _ title: String,
        role: String = "personal-card",
        content: [SkeletonElement],
        modifiers: SkeletonModifiers? = nil
    ) -> SkeletonElement {
        var sectionTitle = BindingPersonalCopilotDesignSystem.headingText(title)
        sectionTitle.modifiers?.styleRole = role
        var section = SkeletonSection(
            header: .Text(sectionTitle),
            content: content
        )
        section.modifiers = modifiers ?? BindingPersonalCopilotDesignSystem.chatSectionCard()
        return .Section(section)
    }

    nonisolated private static func personalKeyValueRow(
        _ key: String,
        keypath: String,
        accent: String
    ) -> SkeletonElement {
        var keyText = SkeletonText(text: key.uppercased())
        keyText.modifiers = modifier {
            $0.foregroundColor = BindingPersonalCopilotDesignSystem.textTertiary
            $0.fontSize = 11
            $0.fontWeight = "medium"
            $0.styleRole = "personal-section-header"
        }
        var valueText = personalBoundText(keypath, lineLimit: 3)
        valueText.modifiers?.fontSize = 14
        valueText.modifiers?.maxWidthInfinity = true
        var accentText = SkeletonText(text: " ")
        accentText.modifiers = modifier {
            $0.width = 4
            $0.height = 32
            $0.background = accent
            $0.cornerRadius = 99
        }
        var textColumn = SkeletonVStack(elements: [
            .Text(keyText),
            .Text(valueText)
        ], spacing: 3)
        textColumn.modifiers = modifier {
            $0.maxWidthInfinity = true
        }
        var row = SkeletonHStack(elements: [
            .Text(accentText),
            .VStack(textColumn),
            .Spacer(SkeletonSpacer())
        ], spacing: 8)
        row.modifiers = modifier {
            $0.padding = 8
            $0.background = BindingPersonalCopilotDesignSystem.surface
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = BindingPersonalCopilotDesignSystem.border
            $0.styleRole = "personal-key-value-block"
        }
        return .HStack(row)
    }

    nonisolated private static func personalStatusActionCard(
        _ title: String,
        keypath: String,
        accent: String,
        button: SkeletonButton,
        supportingText: String? = nil
    ) -> SkeletonElement {
        var accentText = SkeletonText(text: " ")
        accentText.modifiers = modifier {
            $0.width = 4
            $0.height = 40
            $0.background = accent
            $0.cornerRadius = 99
        }

        let titleText = personalLabelText(title.uppercased())
        var valueText = personalBoundText(keypath, lineLimit: 3)
        valueText.modifiers?.fontSize = 14

        var textColumn = SkeletonVStack(
            elements: [
                .Text(titleText),
                .Text(valueText)
            ],
            spacing: 4
        )
        textColumn.modifiers = modifier {
            $0.hAlignment = "leading"
        }

        var row = SkeletonHStack(
            elements: [
                .Text(accentText),
                .VStack(textColumn),
                .Spacer(SkeletonSpacer())
            ],
            spacing: 8
        )
        row.modifiers = modifier {
            $0.maxWidthInfinity = true
        }

        var elements: [SkeletonElement] = [
            .HStack(row),
            .Button(button)
        ]
        if let supportingText,
           !supportingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            elements.append(.Text(personalBodyText(supportingText, lineLimit: 2)))
        }

        var card = SkeletonVStack(elements: elements, spacing: 10)
        card.modifiers = BindingPersonalCopilotDesignSystem.keyValueCard()
        return .VStack(card)
    }

    nonisolated private static func personalLabelText(_ text: String) -> SkeletonText {
        var label = SkeletonText(text: text)
        label.modifiers = modifier {
            $0.foregroundColor = BindingPersonalCopilotDesignSystem.textTertiary
            $0.fontSize = 11
            $0.fontWeight = "medium"
            $0.styleRole = "personal-section-header"
        }
        return label
    }

    nonisolated private static func personalBodyText(
        _ text: String,
        lineLimit: Int = 3
    ) -> SkeletonText {
        var body = BindingPersonalCopilotDesignSystem.bodyText(text)
        body.modifiers?.lineLimit = lineLimit
        return body
    }

    nonisolated private static func personalBoundText(
        _ keypath: String,
        lineLimit: Int = 2
    ) -> SkeletonText {
        var text = SkeletonText(keypath: keypath)
        text.modifiers = modifier {
            $0.foregroundColor = BindingPersonalCopilotDesignSystem.textPrimary
            $0.fontSize = 13
            $0.lineLimit = lineLimit
        }
        return text
    }

    nonisolated private static func personalReferenceCardConfiguration(
        name: String,
        endpoint: String,
        label: String,
        title: String,
        subtitle: String,
        chip: String,
        borderColor: String,
        sourceCellName: String,
        purpose: String,
        purposeDescription: String,
        interests: [String],
        menuSlots: [MenuSlot],
        policyCategory: String,
        requiresLogin: Bool = false,
        requiresUserGeneratedContentModeration: Bool = false,
        nativePermissionRequests: [String] = [],
        universalLinkPath: String? = nil
    ) -> CellConfiguration {
        var configuration = CellConfiguration(name: name)
        configuration.description = subtitle
        configuration.addReference(CellReference(endpoint: endpoint, label: label))

        let surfaceFamily = BindingPersonalCopilotV1Policy.defaultSurfaceFamily(for: policyCategory)
        let presentationClass = BindingPersonalCopilotV1Policy.defaultPresentationClass(for: policyCategory)

        var heroChip = SkeletonText(text: chip)
        heroChip.modifiers = BindingPersonalCopilotDesignSystem.badgeModifier(
            background: BindingPersonalCopilotDesignSystem.brandSubtle,
            borderColor: borderColor,
            foregroundColor: BindingPersonalCopilotDesignSystem.textPrimary
        )

        var familyChip = SkeletonText(text: surfaceFamily.uppercased())
        familyChip.modifiers = BindingPersonalCopilotDesignSystem.badgeModifier(
            background: BindingPersonalCopilotDesignSystem.surfaceMuted,
            borderColor: BindingPersonalCopilotDesignSystem.borderStrong,
            foregroundColor: BindingPersonalCopilotDesignSystem.textSecondary
        )

        var titleText = BindingPersonalCopilotDesignSystem.headingText(title)
        titleText.modifiers?.styleRole = "personal-hero"

        let subtitleText = BindingPersonalCopilotDesignSystem.bodyText(subtitle)
        let purposeText = BindingPersonalCopilotDesignSystem.bodyText(purposeDescription, color: BindingPersonalCopilotDesignSystem.textTertiary, size: 13)
        let endpointText = BindingPersonalCopilotDesignSystem.metadataText(endpoint)

        var reviewSummaryText = BindingPersonalCopilotDesignSystem.metadataText("Presentation: \(presentationClass) · Policy: \(policyCategory)")
        reviewSummaryText.modifiers?.styleRole = "personal-key-value-block"

        let summaryRows: [SkeletonElement] = [
            personalCopilotSummaryRow(
                key: "Source",
                value: sourceCellName,
                accent: borderColor
            ),
            personalCopilotSummaryRow(
                key: "Purpose",
                value: purpose,
                accent: BindingPersonalCopilotDesignSystem.brandPrimary
            ),
            personalCopilotSummaryRow(
                key: "Access",
                value: requiresLogin ? "Login required" : "Requester-local where possible",
                accent: requiresLogin ? BindingPersonalCopilotDesignSystem.warning : BindingPersonalCopilotDesignSystem.success
            ),
            personalCopilotSummaryRow(
                key: "Permissions",
                value: nativePermissionRequests.isEmpty ? "No native permissions by default" : nativePermissionRequests.joined(separator: ", "),
                accent: nativePermissionRequests.isEmpty ? BindingPersonalCopilotDesignSystem.textTertiary : BindingPersonalCopilotDesignSystem.warning
            )
        ]

        var summarySection = SkeletonSection(
            header: .Text(BindingPersonalCopilotDesignSystem.titleText("Surface summary")),
            content: summaryRows
        )
        summarySection.modifiers = BindingPersonalCopilotDesignSystem.keyValueCard()

        var actionRowText = BindingPersonalCopilotDesignSystem.bodyText("Portable content still lives in the attached `CellConfiguration` contract. HAVEN owns shell chrome, loading state and policy context around it.", color: BindingPersonalCopilotDesignSystem.textSecondary, size: 13)
        actionRowText.modifiers?.styleRole = "personal-action-row"

        var actionSection = SkeletonSection(
            header: .Text(BindingPersonalCopilotDesignSystem.titleText("Host behavior")),
            content: [
                .Text(actionRowText),
                .Text(endpointText)
            ]
        )
        actionSection.modifiers = BindingPersonalCopilotDesignSystem.sectionCard(role: "personal-card")

        var heroSection = SkeletonSection(
            header: nil,
            content: [
                .HStack(SkeletonHStack(elements: [
                    .VStack(SkeletonVStack(elements: [
                        .Text(titleText),
                        .Text(subtitleText),
                        .Text(purposeText)
                    ])),
                    .Spacer(SkeletonSpacer()),
                    .Text(heroChip)
                ])),
                .HStack(SkeletonHStack(elements: [
                    .Text(familyChip),
                    .Text(BindingPersonalCopilotDesignSystem.metadataText("Portable shell seed"))
                ])),
                .Text(reviewSummaryText)
            ]
        )
        heroSection.modifiers = BindingPersonalCopilotDesignSystem.heroPanel()

        var root = SkeletonVStack(elements: [
            .Section(heroSection),
            .Section(summarySection),
            .Section(actionSection)
        ])
        root.modifiers = BindingPersonalCopilotDesignSystem.pageCard()

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.padding = 6
            $0.background = BindingPersonalCopilotDesignSystem.canvas
        }
        configuration.skeleton = .ScrollView(scroll)

        return withPersonalCopilotMetadata(
            configuration,
            sourceCellEndpoint: endpoint,
            sourceCellName: sourceCellName,
            purpose: purpose,
            purposeDescription: purposeDescription,
            interests: interests,
            menuSlots: menuSlots,
            policyCategory: policyCategory,
            requiresLogin: requiresLogin,
            requiresUserGeneratedContentModeration: requiresUserGeneratedContentModeration,
            nativePermissionRequests: nativePermissionRequests,
            universalLinkPath: universalLinkPath
        )
    }

    nonisolated private static func withPersonalCopilotMetadata(
        _ configuration: CellConfiguration,
        sourceCellEndpoint: String,
        sourceCellName: String,
        purpose: String,
        purposeDescription: String,
        interests: [String],
        menuSlots: [MenuSlot],
        policyCategory: String,
        requiresLogin: Bool = false,
        requiresUserGeneratedContentModeration: Bool = false,
        nativePermissionRequests: [String] = [],
        universalLinkPath: String? = nil
    ) -> CellConfiguration {
        var updated = configuration
        let universalPath = universalLinkPath ?? "personal/\(catalogSlug(for: updated.name))"
        updated.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: sourceCellEndpoint,
            sourceCellName: sourceCellName,
            purpose: purpose,
            purposeDescription: purposeDescription,
            interests: BindingPersonalCopilotV1Policy.discoveryInterests(interests, policyCategory: policyCategory),
            menuSlots: menuSlots.map(\.rawValue)
        )
        let reviewSummary = "Curated Personal Co-Pilot surface: \(updated.name)"
        let metadata = BindingPersonalCopilotV1Policy.metadataHints(
            policyCategory: policyCategory,
            requiresLogin: requiresLogin,
            requiresUserGeneratedContentModeration: requiresUserGeneratedContentModeration,
            nativePermissionRequests: nativePermissionRequests,
            universalLink: "https://staging.haven.digipomps.org/app/\(universalPath)",
            reviewSummary: reviewSummary
        )
        let existingInterests = updated.discovery?.interests ?? []
        let mergedInterests = BindingPersonalCopilotV1Policy.discoveryInterests(
            existingInterests + metadata,
            policyCategory: policyCategory
        )
        var discovery = updated.discovery
        discovery?.interests = mergedInterests
        updated.discovery = discovery
        return updated
    }

    nonisolated private static func personalCopilotSummaryRow(
        key: String,
        value: String,
        accent: String
    ) -> SkeletonElement {
        var keyText = SkeletonText(text: key.uppercased())
        keyText.modifiers = modifier {
            $0.foregroundColor = BindingPersonalCopilotDesignSystem.textTertiary
            $0.fontSize = 11
            $0.fontWeight = "medium"
            $0.styleRole = "personal-section-header"
        }

        var valueText = SkeletonText(text: value)
        valueText.modifiers = modifier {
            $0.foregroundColor = BindingPersonalCopilotDesignSystem.textPrimary
            $0.fontSize = 14
            $0.lineLimit = 3
        }

        var accentText = SkeletonText(text: " ")
        accentText.modifiers = modifier {
            $0.width = 4
            $0.height = 32
            $0.background = accent
            $0.cornerRadius = 99
        }

        var row = SkeletonHStack(elements: [
            .Text(accentText),
            .VStack(SkeletonVStack(elements: [
                .Text(keyText),
                .Text(valueText)
            ]))
        ])
        row.modifiers = modifier {
            $0.padding = 8
            $0.background = BindingPersonalCopilotDesignSystem.surface
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = BindingPersonalCopilotDesignSystem.border
            $0.styleRole = "personal-key-value-block"
        }
        return .HStack(row)
    }

    nonisolated private static func conferenceMVPWorkbenchConfiguration(
        endpoint: String,
        displayName: String,
        summary: String
    ) -> CellConfiguration {
        var configuration = CellConfiguration(name: displayName)
        configuration.description = summary
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: endpoint,
            sourceCellName: "ConferenceUIRouterCell",
            purpose: "Conference partnering og flyt",
            purposeDescription: "Preview-drevet konferanseflate rendret fra skeleton, slik at HAVEN og web kan bruke samme CellConfiguration.",
            interests: ["conference", "events", "matchmaking", "scheduling", "agenda"],
            menuSlots: ["upperLeft", "upperRight"]
        )

        configuration.addReference(CellReference(endpoint: endpoint, subscribeFeed: false, label: "conferenceUIRouter"))

        let pageCard = conferenceCardModifier(
            padding: 12,
            background: ConferenceSurfacePalette.canvas,
            borderColor: ConferenceSurfacePalette.canvas,
            cornerRadius: 26
        )
        let heroCard = conferenceCardModifier(
            padding: 14,
            background: ConferenceSurfacePalette.shellStrong,
            borderColor: ConferenceSurfacePalette.accentCoolBorder,
            cornerRadius: 22,
            shadowRadius: 14,
            shadowY: 4
        )
        let sectionCard = conferenceCardModifier(
            padding: 12,
            background: ConferenceSurfacePalette.shell,
            borderColor: ConferenceSurfacePalette.stroke,
            cornerRadius: 18
        )
        let listCard = modifier {
            $0.padding = 8
            $0.background = ConferenceSurfacePalette.shellMuted
            $0.cornerRadius = 16
            $0.borderWidth = 1
            $0.borderColor = ConferenceSurfacePalette.stroke
            $0.height = 210
        }
        let heroChip = conferenceChipModifier(
            background: ConferenceSurfacePalette.accentWarmSoft,
            borderColor: ConferenceSurfacePalette.strokeStrong,
            foregroundColor: ConferenceSurfacePalette.textMain
        )
        let neutralChip = conferenceChipModifier(
            background: ConferenceSurfacePalette.accentCoolSoft,
            borderColor: ConferenceSurfacePalette.accentCoolBorder,
            foregroundColor: ConferenceSurfacePalette.textMain
        )
        let primaryButton = conferenceButtonModifier(
            background: ConferenceSurfacePalette.accentCoolSoft,
            borderColor: ConferenceSurfacePalette.accentCoolBorder,
            foregroundColor: ConferenceSurfacePalette.textMain
        )
        let secondaryButton = conferenceButtonModifier(
            background: ConferenceSurfacePalette.accentWarmSoft,
            borderColor: ConferenceSurfacePalette.strokeStrong,
            foregroundColor: ConferenceSurfacePalette.textMain
        )

        func sectionTitle(_ text: String) -> SkeletonText {
            var label = SkeletonText(text: text)
            label.modifiers = modifier {
                $0.fontWeight = "semibold"
                $0.foregroundColor = ConferenceSurfacePalette.textMain
                $0.fontSize = 13
            }
            return label
        }

        func bodyText(_ text: String, color: String = ConferenceSurfacePalette.textMuted) -> SkeletonText {
            var label = SkeletonText(text: text)
            label.modifiers = modifier {
                $0.foregroundColor = color
                $0.fontSize = 12
                $0.lineLimit = 4
            }
            return label
        }

        func keyText(_ keypath: String, color: String = ConferenceSurfacePalette.textMain, size: Double = 13) -> SkeletonText {
            var label = SkeletonText(keypath: keypath)
            label.modifiers = modifier {
                $0.foregroundColor = color
                $0.fontSize = size
                $0.lineLimit = 4
            }
            return label
        }

        func actionButton(_ screenID: String, label: String, style: SkeletonModifiers) -> SkeletonElement {
            var button = SkeletonButton(
                keypath: "conferenceUIRouter.navigate",
                label: label,
                payload: .object(["screenId": .string(screenID)])
            )
            button.modifiers = style
            return .Button(button)
        }

        func screenCardRow() -> SkeletonVStack {
            var title = SkeletonText(keypath: "title")
            title.modifiers = modifier {
                $0.fontWeight = "semibold"
                $0.foregroundColor = ConferenceSurfacePalette.textMain
                $0.fontSize = 13
            }
            var subtitle = SkeletonText(keypath: "subtitle")
            subtitle.modifiers = modifier {
                $0.foregroundColor = ConferenceSurfacePalette.textMuted
                $0.fontSize = 12
                $0.lineLimit = 3
            }
            var detail = SkeletonText(keypath: "detail")
            detail.modifiers = modifier {
                $0.foregroundColor = ConferenceSurfacePalette.accentCool
                $0.fontSize = 12
                $0.lineLimit = 2
            }
            var note = SkeletonText(keypath: "note")
            note.modifiers = modifier {
                $0.foregroundColor = ConferenceSurfacePalette.textMuted
                $0.fontSize = 11
                $0.lineLimit = 2
            }

            var row = SkeletonVStack(elements: [
                .Text(title),
                .Text(subtitle),
                .Text(detail),
                .Text(note)
            ])
            row.modifiers = sectionCard
            return row
        }

        func titleDetailRow() -> SkeletonVStack {
            var title = SkeletonText(keypath: "title")
            title.modifiers = modifier {
                $0.fontWeight = "semibold"
                $0.foregroundColor = ConferenceSurfacePalette.textMain
                $0.fontSize = 13
            }
            var detail = SkeletonText(keypath: "detail")
            detail.modifiers = modifier {
                $0.foregroundColor = ConferenceSurfacePalette.textMuted
                $0.fontSize = 12
                $0.lineLimit = 3
            }

            var row = SkeletonVStack(elements: [.Text(title), .Text(detail)])
            row.modifiers = sectionCard
            return row
        }

        var title = SkeletonText(text: displayName)
        title.modifiers = modifier {
            $0.fontStyle = "title2"
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.textMain
        }

        var subtitle = SkeletonText(text: "Rendret som skeleton-preview over `ConferenceUIRouter`, slik at samme referanse og state kan absorberes i HAVEN, library og web.")
        subtitle.modifiers = modifier {
            $0.foregroundColor = ConferenceSurfacePalette.textMuted
            $0.fontSize = 12
            $0.lineLimit = 4
        }

        var endpointText = SkeletonText(text: endpoint)
        endpointText.modifiers = modifier {
            $0.foregroundColor = ConferenceSurfacePalette.accentCool
            $0.fontSize = 11
            $0.lineLimit = 2
        }

        var liveChip = SkeletonText(text: "STAGING REMOTE")
        liveChip.modifiers = heroChip
        var matchingChip = SkeletonText(text: "Matchmaking")
        matchingChip.modifiers = neutralChip
        var scheduleChip = SkeletonText(text: "Scheduling")
        scheduleChip.modifiers = neutralChip
        var routingChip = SkeletonText(text: "Router state")
        routingChip.modifiers = neutralChip

        var heroSection = SkeletonSection(
            header: nil,
            footer: .Text(bodyText("Hvis bridge eller preview-shell er treg, skal denne fortsatt vise en tydelig skeleton-basert surface mens runtime-jobben pågår.")),
            content: [
                .HStack(SkeletonHStack(elements: [
                    .VStack(SkeletonVStack(elements: [
                        .Text(title),
                        .Text(subtitle),
                        .Text(endpointText)
                    ])),
                    .Spacer(SkeletonSpacer()),
                    .Text(liveChip)
                ])),
                .HStack(SkeletonHStack(elements: [.Text(matchingChip), .Text(scheduleChip), .Text(routingChip)])),
                .Text(sectionTitle("Current workspace")),
                .Text(keyText("conferenceUIRouter.state.workspace.title")),
                .Text(keyText("conferenceUIRouter.state.workspace.subtitle", color: ConferenceSurfacePalette.textMuted, size: 12)),
                .Text(keyText("conferenceUIRouter.state.workspace.activeScreenTitle", color: ConferenceSurfacePalette.accentCool)),
                .Text(keyText("conferenceUIRouter.state.workspace.nextActionHint", color: ConferenceSurfacePalette.textMuted, size: 12))
            ]
        )
        heroSection.modifiers = heroCard

        var workflowList = SkeletonList(
            topic: nil,
            keypath: "conferenceUIRouter.state.screenCards",
            flowElementSkeleton: screenCardRow()
        )
        workflowList.modifiers = listCard

        var workflowSection = SkeletonSection(
            header: .Text(sectionTitle("Workflow map")),
            footer: .Text(bodyText("Screen cards gir et kompakt kart over onboarding, people, meetings og organizer-innsikt uten at HAVEN trenger en egen conference-view.")),
            content: [
                .List(workflowList),
                .HStack(SkeletonHStack(elements: [
                    actionButton("onboarding", label: "Onboarding", style: secondaryButton),
                    actionButton("peopleMatches", label: "People", style: primaryButton),
                    actionButton("meetings", label: "Meetings", style: primaryButton)
                ]))
            ]
        )
        workflowSection.modifiers = sectionCard

        var matchesList = SkeletonList(
            topic: nil,
            keypath: "conferenceUIRouter.state.peopleMatches.recommendations",
            flowElementSkeleton: titleDetailRow()
        )
        matchesList.modifiers = listCard

        var meetingsList = SkeletonList(
            topic: nil,
            keypath: "conferenceUIRouter.state.meetings.confirmedMeetings",
            flowElementSkeleton: titleDetailRow()
        )
        meetingsList.modifiers = listCard

        var operationsSection = SkeletonSection(
            header: .Text(sectionTitle("People and schedule")),
            footer: .Text(bodyText("Denne flaten holder fast i `CellConfiguration` + `skeleton`: runtime-data kommer fra `conferenceUIRouter` og ikke fra HAVEN-spesifikke views.")),
            content: [
                .Text(keyText("conferenceUIRouter.state.peopleMatches.status", color: ConferenceSurfacePalette.textMuted, size: 12)),
                .List(matchesList),
                .Text(keyText("conferenceUIRouter.state.meetings.meetingSummary", color: ConferenceSurfacePalette.textMuted, size: 12)),
                .List(meetingsList),
                .HStack(SkeletonHStack(elements: [
                    actionButton("peopleMatches", label: "Open matches", style: primaryButton),
                    actionButton("meetings", label: "Open meetings", style: secondaryButton),
                    actionButton("insights", label: "Insights", style: secondaryButton)
                ]))
            ]
        )
        operationsSection.modifiers = sectionCard

        var notesSection = SkeletonSection(
            header: .Text(sectionTitle("Runtime notes")),
            content: [
                .Text(bodyText("HAVEN skal oversette remote host og bridgehead, men ellers behandle conference-surface likt som scaffolden.")),
                .Text(bodyText("Hvis en keypath gir `notFound`, er det en runtime-/preview-avvik vi vil se i debug-panelet og ikke skjule med en HAVEN-only fallback.", color: ConferenceSurfacePalette.accentWarm))
            ]
        )
        notesSection.modifiers = sectionCard

        var root = SkeletonVStack(elements: [
            .Section(heroSection),
            .Section(workflowSection),
            .Section(operationsSection),
            .Section(notesSection)
        ])
        root.modifiers = pageCard

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.background = ConferenceSurfacePalette.canvas
        }

        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func conferenceParticipantPortalWorkbenchConfiguration(
        endpoint: String,
        displayName: String,
        summary: String
    ) -> CellConfiguration {
        let usesLocalPreview = endpoint.caseInsensitiveCompare("cell:///ConferenceParticipantPreviewShell") == .orderedSame
        var configuration = CellConfiguration(name: displayName)
        configuration.description = summary
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: endpoint,
            sourceCellName: usesLocalPreview
                ? "ConferenceParticipantPreviewShellLocalFallbackCell"
                : "ConferenceParticipantPreviewShellCell",
            purpose: "Conference participantportal",
            purposeDescription: usesLocalPreview
                ? "Participant-shell med agenda, discovery, anbefalte personer, møter og shared network, levert over en lokal preview-wrapper i HAVEN. HAVEN legger i tillegg på lokal scanner-enrichment."
                : "Participant-shell med agenda, discovery, anbefalte personer, møter og shared network, levert over preview-wrapper så samme contract kan brukes i HAVEN og scaffold. HAVEN legger i tillegg på lokal scanner-enrichment.",
            interests: ["conference", "participant", "agenda", "sessions", "matchmaking", "meetings", "network", "discovery", "nearby", "scanner"],
            menuSlots: ["upperMid", "lowerMid"]
        )

        var reference = CellReference(endpoint: endpoint, subscribeFeed: false, label: "conferenceParticipantShell")
        reference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(reference)

        var agendaSnapshotReference = CellReference(
            endpoint: "cell:///ConferenceParticipantAgendaSnapshot",
            subscribeFeed: false,
            label: "agendaSnapshot"
        )
        agendaSnapshotReference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(agendaSnapshotReference)

        var discoverySnapshotReference = CellReference(
            endpoint: "cell:///ConferenceParticipantDiscoverySnapshot",
            subscribeFeed: false,
            label: "discoverySnapshot"
        )
        discoverySnapshotReference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(discoverySnapshotReference)

        var matchmakingSnapshotReference = CellReference(
            endpoint: "cell:///ConferenceParticipantMatchmakingSnapshot",
            subscribeFeed: false,
            label: "matchmakingSnapshot"
        )
        matchmakingSnapshotReference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(matchmakingSnapshotReference)

        var nearbyRadarReference = CellReference(endpoint: "cell:///ConferenceNearbyRadar", subscribeFeed: true, label: "nearbyRadar")
        nearbyRadarReference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(nearbyRadarReference)

        var chatSnapshotReference = CellReference(
            endpoint: "cell:///ConferenceParticipantChatSnapshot",
            subscribeFeed: false,
            label: "chatSnapshot"
        )
        chatSnapshotReference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(chatSnapshotReference)

        var root = SkeletonVStack(elements: [
            bindingConferencePortalHeroSection(referenceLabel: "conferenceParticipantShell"),
            bindingConferencePortalAgendaSection(referenceLabel: "agendaSnapshot"),
            bindingConferencePortalSessionMatrixSection(referenceLabel: "agendaSnapshot"),
            bindingConferencePortalRecommendationsSection(referenceLabel: "matchmakingSnapshot"),
            bindingConferencePortalDiscoverySection(referenceLabel: "discoverySnapshot"),
            bindingConferencePortalNearbyScannerSection(scannerReferenceLabel: "nearbyRadar"),
            bindingConferencePortalChatSection(referenceLabel: "chatSnapshot"),
            bindingConferencePortalTimelineSection(referenceLabel: "conferenceParticipantShell"),
            bindingConferencePortalNetworkSection(referenceLabel: "conferenceParticipantShell"),
            bindingConferencePortalCardSection(
                "Runtime Notes",
                content: [
                    bindingConferencePortalStaticText(
                        "Denne flaten holder seg til CellConfiguration + skeleton. HAVEN skal bare oversette remote host/bridgehead og ellers laste samme conference-kontrakt som scaffolden.",
                        fontSize: 12,
                        foregroundColor: "#9AB3C3"
                    ),
                    bindingConferencePortalStaticText(
                        "Hvis preview-wrapper eller bridge er treg, skal brukeren fortsatt se en tydelig loading/failure-surface i stedet for svart porthole.",
                        fontSize: 12,
                        foregroundColor: "#D7E7F2"
                    )
                ]
            )
        ])
        root.modifiers = modifier {
            $0.padding = 12
            $0.background = ConferenceSurfacePalette.canvas
        }

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.background = ConferenceSurfacePalette.canvas
        }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func conferenceNearbyRadarWorkbenchConfiguration(
        participantEndpoint: String,
        displayName: String,
        summary: String
    ) -> CellConfiguration {
        var configuration = CellConfiguration(name: displayName)
        configuration.description = summary
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: "cell:///ConferenceNearbyRadar",
            sourceCellName: "ConferenceNearbyRadarLocalCell",
            purpose: "Conference nearby radar",
            purposeDescription: "HAVEN-lokal nearby-radar over EntityScanner for fysisk retning, nærhet og rask chat-oppfølging i konferanseflyten.",
            interests: ["conference", "nearby", "scanner", "radar", "uwb", "multipeer", "follow-up-chat"],
            menuSlots: ["upperMid", "lowerMid"]
        )

        var participantReference = CellReference(endpoint: participantEndpoint, subscribeFeed: false, label: "conferenceParticipantShell")
        participantReference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(participantReference)

        var nearbyRadarReference = CellReference(endpoint: "cell:///ConferenceNearbyRadar", subscribeFeed: true, label: "nearbyRadar")
        nearbyRadarReference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(nearbyRadarReference)

        let chatSnapshotReference = CellReference(
            endpoint: "cell:///ConferenceParticipantChatSnapshot",
            subscribeFeed: false,
            label: "chatSnapshot"
        )
        configuration.addReference(chatSnapshotReference)

        var root = SkeletonVStack(elements: [
            bindingConferencePortalCardSection(
                "Conference Nearby Radar",
                content: [
                    bindingConferencePortalStaticText(
                        "Nearby radar · full oversikt",
                        fontSize: 18,
                        fontWeight: "bold",
                        foregroundColor: "#F5FBFF"
                    ),
                    bindingConferencePortalStaticText(
                        "Dette er den store radarflaten i Porthole. Bruk den når du vil ha mer romlig oversikt enn det den innebygde radaren i deltagerportalen gir.",
                        fontSize: 12,
                        foregroundColor: "#B9FBC0",
                        lineLimit: 4
                    ),
                    bindingConferencePortalKeyText("conferenceParticipantShell.state.workspace.title"),
                    bindingConferencePortalKeyText("conferenceParticipantShell.state.workspace.nextStep", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                    bindingConferencePortalKeyText("nearbyRadar.state.summary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                    .Grid(
                        SkeletonGrid(
                            columns: [.adaptive(min: 220, max: 320)],
                            spacing: 12,
                            elements: [
                                bindingConferencePortalStateSummaryCard(
                                    title: "Scannerstatus",
                                    detailKeypath: "nearbyRadar.state.statusSummary",
                                    noteKeypath: "nearbyRadar.state.actionSummary",
                                    accentBorder: "#2F6B56",
                                    accentText: "#B9FBC0",
                                    height: 132
                                ),
                                bindingConferencePortalStateSummaryCard(
                                    title: "Valg nå",
                                    detailKeypath: "nearbyRadar.state.selectionSummary",
                                    noteKeypath: "nearbyRadar.state.navigationSummary",
                                    accentBorder: "#2A4D61",
                                    accentText: "#B9E6FF",
                                    height: 132
                                ),
                                bindingConferencePortalStateSummaryCard(
                                    title: "Neste steg",
                                    detailKeypath: "nearbyRadar.state.nextStepSummary",
                                    noteKeypath: "nearbyRadar.state.precisionSummary",
                                    accentBorder: "#4D3F2A",
                                    accentText: "#F4D58D",
                                    height: 132
                                ),
                                bindingConferencePortalStateSummaryCard(
                                    title: "Match nå",
                                    detailKeypath: "nearbyRadar.state.matchSummary",
                                    noteKeypath: "nearbyRadar.state.selectedEntity.followUpSummary",
                                    accentBorder: "#2F6B56",
                                    accentText: "#B9FBC0",
                                    height: 132
                                )
                            ]
                        )
                    ),
                    bindingConferencePortalKeyText("nearbyRadar.state.selectionSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                    bindingConferencePortalKeyText("nearbyRadar.state.precisionSummary", fontSize: 12, foregroundColor: "#9AB3C3", lineLimit: 3),
                    bindingConferencePortalKeyText("nearbyRadar.state.actionSummary", fontSize: 12, foregroundColor: "#B9FBC0", lineLimit: 3),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferencePortalActionButton(
                                "nearbyRadar",
                                actionKeypath: "start",
                                label: "Start scanner"
                            ),
                            bindingConferencePortalActionButton(
                                "nearbyRadar",
                                actionKeypath: "stop",
                                label: "Stop scanner"
                            ),
                            bindingConferencePortalActionButton(
                                "nearbyRadar",
                                actionKeypath: "openParticipantPortalWorkbench",
                                label: "Tilbake til portalen"
                            )
                        ])
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferencePortalBadgeKeyText("nearbyRadar.state.transportBadge"),
                            bindingConferencePortalBadgeKeyText("nearbyRadar.state.precisionBadge"),
                            bindingConferencePortalBadgeKeyText("nearbyRadar.state.statusBadge")
                        ])
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Valgt deltager",
                content: [
                    bindingConferencePortalStaticText(
                        "Velg en nearby deltager først. Her ser du hvem som er valgt, hvor sikre signalene er, og hva neste naturlige handling er.",
                        fontSize: 12,
                        foregroundColor: "#9AB3C3",
                        lineLimit: 4
                    ),
                    bindingConferencePortalKeyText("nearbyRadar.state.selectedEntity.selectionBadge", fontSize: 12, fontWeight: "bold", foregroundColor: "#7FD6D0"),
                    bindingConferencePortalKeyText("nearbyRadar.state.selectedEntity.title", fontSize: 18, fontWeight: "bold", foregroundColor: "#F5FBFF", lineLimit: 2),
                    bindingConferencePortalKeyText("nearbyRadar.state.selectedEntity.subtitle", fontSize: 12, foregroundColor: "#8DE1DA", lineLimit: 2),
                    bindingConferencePortalKeyText("nearbyRadar.state.selectedEntity.detail", fontSize: 12, foregroundColor: "#D5E4ED", lineLimit: 3),
                    bindingConferencePortalKeyText("nearbyRadar.state.selectedEntity.relevanceBadge", fontSize: 12, fontWeight: "bold", foregroundColor: "#B9FBC0", lineLimit: 1),
                    bindingConferencePortalKeyText("nearbyRadar.state.selectedEntity.relevanceSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                    bindingConferencePortalKeyText("nearbyRadar.state.selectedEntity.purposeSummary", fontSize: 12, foregroundColor: "#B9FBC0", lineLimit: 3),
                    bindingConferencePortalKeyText("nearbyRadar.state.selectedEntity.purposeDetail", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 3),
                    bindingConferencePortalKeyText("nearbyRadar.state.selectedEntity.followUpSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                    bindingConferencePortalKeyText("nearbyRadar.state.selectedEntity.chatSummary", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 3),
                    bindingConferencePortalKeyText("nearbyRadar.state.selectedEntity.note", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 3),
                    bindingConferencePortalCollectionGrid(
                        keypath: "nearbyRadar.state.selectedEntityActions",
                        min: 240,
                        max: 320,
                        itemSkeleton: bindingConferencePortalActionConnectionCardSkeleton()
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Spatial Overview",
                content: [
                    bindingConferencePortalStaticText(
                        "Treff grupperes som sektorer og nearby-kort. Vi viser bare harde retninger når sensoren faktisk har retning. Resten samles under retning usikker.",
                        fontSize: 12,
                        foregroundColor: "#9AB3C3",
                        lineLimit: 4
                    ),
                    bindingConferencePortalKeyText("nearbyRadar.state.spatialTruthSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 4),
                    bindingConferencePortalEmbeddedRadarLayout(baseKeypath: "nearbyRadar.state.radarLayout"),
                    bindingConferencePortalCollectionGrid(
                        keypath: "nearbyRadar.state.nearby",
                        min: 260,
                        max: 360,
                        itemSkeleton: bindingConferencePortalNearbyCardSkeleton()
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "What To Do Next",
                content: [
                    bindingConferencePortalStaticText(
                        "Bruk Velg for å fokusere på en deltager. Deretter kan du be om kontakt, markere for oppfølging eller starte chat når kontakten er verifisert. Det er den korteste, tryggeste conference-flyten akkurat nå.",
                        fontSize: 12,
                        foregroundColor: "#D7E7F2",
                        lineLimit: 5
                    ),
                    bindingConferencePortalKeyText("conferenceParticipantShell.state.discovery.nextAction", fontSize: 12, foregroundColor: "#B9FBC0", lineLimit: 4),
                    bindingConferencePortalKeyText("conferenceParticipantShell.state.sharedConnections.chatSummary", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 3)
                ]
            )
        ])
        root.modifiers = modifier {
            $0.padding = 12
            $0.background = ConferenceSurfacePalette.canvas
        }

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.background = ConferenceSurfacePalette.canvas
        }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated static func conferenceNearbyParticipantWorkbenchConfiguration(
        participantEndpoint: String,
        displayName: String,
        summary: String
    ) -> CellConfiguration {
        var configuration = CellConfiguration(name: displayName)
        configuration.description = summary
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: "cell:///ConferenceNearbyRadar",
            sourceCellName: "ConferenceNearbyRadarLocalCell",
            purpose: "Conference nearby participant profile",
            purposeDescription: "HAVEN-lokal profilflate for valgt nearby-deltager med spatial kontekst, purpose-fit og rask oppfølging/chat.",
            interests: ["conference", "nearby", "profile", "chat", "follow-up", "scanner"],
            menuSlots: ["upperMid", "lowerMid"]
        )

        var participantReference = CellReference(endpoint: participantEndpoint, subscribeFeed: false, label: "conferenceParticipantShell")
        participantReference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(participantReference)

        var nearbyRadarReference = CellReference(endpoint: "cell:///ConferenceNearbyRadar", subscribeFeed: true, label: "nearbyRadar")
        nearbyRadarReference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(nearbyRadarReference)

        let chatSnapshotReference = CellReference(
            endpoint: "cell:///ConferenceParticipantChatSnapshot",
            subscribeFeed: false,
            label: "chatSnapshot"
        )
        configuration.addReference(chatSnapshotReference)

        var root = SkeletonVStack(elements: [
            bindingConferencePortalCardSection(
                "Valgt deltager · profilflate",
                content: [
                    bindingConferencePortalStaticText(
                        "Valgt nearby-deltager · profilflate",
                        fontSize: 18,
                        fontWeight: "bold",
                        foregroundColor: "#F5FBFF"
                    ),
                    bindingConferencePortalStaticText(
                        "Dette er en egen profilflate i Porthole. Her viser vi en hybrid av offentlig profil, lokal spatial kontekst og neste anbefalte handling.",
                        fontSize: 12,
                        foregroundColor: "#B9FBC0",
                        lineLimit: 4
                    ),
                    bindingConferencePortalKeyText("nearbyRadar.state.selectedEntity.selectionBadge", fontSize: 12, fontWeight: "bold", foregroundColor: "#7FD6D0"),
                    bindingConferencePortalKeyText("nearbyRadar.state.selectedEntity.title", fontSize: 20, fontWeight: "bold", foregroundColor: "#F5FBFF", lineLimit: 2),
                    bindingConferencePortalKeyText("nearbyRadar.state.selectedEntity.subtitle", fontSize: 12, foregroundColor: "#8DE1DA", lineLimit: 2),
                    bindingConferencePortalKeyText("nearbyRadar.state.selectedEntity.detail", fontSize: 12, foregroundColor: "#D5E4ED", lineLimit: 3),
                    bindingConferencePortalKeyText("nearbyRadar.state.selectedEntity.purposeSummary", fontSize: 12, foregroundColor: "#B9FBC0", lineLimit: 3),
                    bindingConferencePortalKeyText("nearbyRadar.state.selectedEntity.purposeDetail", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 3),
                    bindingConferencePortalKeyText("nearbyRadar.state.selectedEntity.note", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 3),
                    .Grid(
                        SkeletonGrid(
                            columns: [.adaptive(min: 220, max: 320)],
                            spacing: 12,
                            elements: [
                                bindingConferencePortalStateSummaryCard(
                                    title: "Scannerstatus",
                                    detailKeypath: "nearbyRadar.state.statusSummary",
                                    noteKeypath: "nearbyRadar.state.actionSummary",
                                    accentBorder: "#2F6B56",
                                    accentText: "#B9FBC0",
                                    height: 132
                                ),
                                bindingConferencePortalStateSummaryCard(
                                    title: "Valg nå",
                                    detailKeypath: "nearbyRadar.state.selectionSummary",
                                    noteKeypath: "nearbyRadar.state.navigationSummary",
                                    accentBorder: "#2A4D61",
                                    accentText: "#B9E6FF",
                                    height: 132
                                ),
                                bindingConferencePortalStateSummaryCard(
                                    title: "Neste steg",
                                    detailKeypath: "nearbyRadar.state.nextStepSummary",
                                    noteKeypath: "nearbyRadar.state.precisionSummary",
                                    accentBorder: "#4D3F2A",
                                    accentText: "#F4D58D",
                                    height: 132
                                ),
                                bindingConferencePortalStateSummaryCard(
                                    title: "Match nå",
                                    detailKeypath: "nearbyRadar.state.matchSummary",
                                    noteKeypath: "nearbyRadar.state.selectedEntity.followUpSummary",
                                    accentBorder: "#2F6B56",
                                    accentText: "#B9FBC0",
                                    height: 132
                                )
                            ]
                        )
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferencePortalBadgeKeyText("nearbyRadar.state.transportBadge"),
                            bindingConferencePortalBadgeKeyText("nearbyRadar.state.precisionBadge"),
                            bindingConferencePortalBadgeKeyText("nearbyRadar.state.statusBadge")
                        ])
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Neste steg",
                content: [
                    bindingConferencePortalStaticText(
                        "Her skal det være helt tydelig hva som skjer videre: åpne profil for kontekst, be om kontakt for å verifisere match, og start chat når kontakten er klar.",
                        fontSize: 12,
                        foregroundColor: "#D7E7F2",
                        lineLimit: 4
                    ),
                    bindingConferencePortalKeyText("nearbyRadar.state.actionSummary", fontSize: 12, foregroundColor: "#B9FBC0", lineLimit: 3),
                    bindingConferencePortalKeyText("nearbyRadar.state.selectionSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                    bindingConferencePortalKeyText("conferenceParticipantShell.state.sharedConnections.chatSummary", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 2),
                    bindingConferencePortalCollectionGrid(
                        keypath: "nearbyRadar.state.selectedEntityActions",
                        min: 240,
                        max: 320,
                        itemSkeleton: bindingConferencePortalActionConnectionCardSkeleton()
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Spatial Context",
                content: [
                    bindingConferencePortalKeyText("nearbyRadar.state.summary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                    bindingConferencePortalKeyText("nearbyRadar.state.precisionSummary", fontSize: 12, foregroundColor: "#9AB3C3", lineLimit: 3),
                    bindingConferencePortalKeyText("nearbyRadar.state.spatialTruthSummary", fontSize: 12, foregroundColor: "#9AB3C3", lineLimit: 3),
                    bindingConferencePortalEmbeddedRadarLayout(baseKeypath: "nearbyRadar.state.radarLayout")
                ]
            ),
            bindingConferencePortalCardSection(
                "Arbeidsflater",
                content: [
                    bindingConferencePortalStaticText(
                        "Beveg deg mellom portal, full radar og profil uten å miste kontekst. Det gjør demo-flyten mye enklere å følge.",
                        fontSize: 12,
                        foregroundColor: "#9AB3C3",
                        lineLimit: 4
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferencePortalActionButton(
                                "nearbyRadar",
                                actionKeypath: "openExpandedRadarWorkbench",
                                label: "Åpne full radar"
                            ),
                            bindingConferencePortalActionButton(
                                "nearbyRadar",
                                actionKeypath: "openParticipantPortalWorkbench",
                                label: "Tilbake til portalen"
                            )
                        ])
                    )
                ]
            )
        ])
        root.modifiers = modifier {
            $0.padding = 12
            $0.background = ConferenceSurfacePalette.canvas
        }

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.background = ConferenceSurfacePalette.canvas
        }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated static func conferenceParticipantChatWorkbenchConfiguration(
        participantEndpoint: String,
        displayName: String,
        summary: String
    ) -> CellConfiguration {
        var configuration = CellConfiguration(name: displayName)
        configuration.description = summary
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: "cell:///ConferenceChatLaunch",
            sourceCellName: "ConferenceChatLaunchLocalAdapterCell",
            purpose: "Conference participant chat",
            purposeDescription: "Participant chat surface aligned with the ConferenceChatLaunch contract for shared-relation messaging, draft handling and explicit next steps.",
            interests: ["conference", "participant", "chat", "follow-up", "shared-relations", "binding", "web"],
            menuSlots: ["upperMid", "lowerMid"]
        )

        var participantReference = CellReference(endpoint: participantEndpoint, subscribeFeed: false, label: "conferenceParticipantShell")
        participantReference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(participantReference)

        var conferenceChatReference = CellReference(
            endpoint: "cell:///ConferenceChatLaunch",
            subscribeFeed: false,
            label: "conferenceChat"
        )
        conferenceChatReference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(conferenceChatReference)

        var root = SkeletonVStack(elements: [
            bindingConferencePortalCardSection(
                "Conference Participant Chat",
                content: [
                    bindingConferencePortalStaticText(
                        "Conference Participant Chat",
                        fontSize: 20,
                        fontWeight: "bold",
                        foregroundColor: "#F5FBFF"
                    ),
                    bindingConferencePortalStaticText(
                        "HAVEN consumes the current ConferenceChatLaunch-style contract here: shared participants, active conversations, free-text composer and explicit send/draft actions.",
                        fontSize: 12,
                        foregroundColor: "#B9FBC0",
                        lineLimit: 4
                    ),
                    bindingConferencePortalKeyText("conferenceChat.state.headline", fontSize: 18, fontWeight: "bold", foregroundColor: "#F5FBFF", lineLimit: 2),
                    bindingConferencePortalKeyText("conferenceChat.state.status", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                    .Grid(
                        SkeletonGrid(
                            columns: [.adaptive(min: 220, max: 320)],
                            spacing: 12,
                            elements: [
                                bindingConferencePortalStateSummaryCard(
                                    title: "Launch state",
                                    detailKeypath: "conferenceChat.state.launchSummary",
                                    noteKeypath: "conferenceChat.state.nextAction",
                                    accentBorder: "#2F6B56",
                                    accentText: "#B9FBC0",
                                    height: 132
                                ),
                                bindingConferencePortalStateSummaryCard(
                                    title: "Conversation scope",
                                    detailKeypath: "conferenceChat.state.conversationSummary",
                                    noteKeypath: "conferenceChat.state.participantsSummary",
                                    accentBorder: "#2A4D61",
                                    accentText: "#B9E6FF",
                                    height: 132
                                ),
                                bindingConferencePortalStateSummaryCard(
                                    title: "Messages",
                                    detailKeypath: "conferenceChat.state.messageSummary",
                                    noteKeypath: "conferenceChat.state.bridgeSummary",
                                    accentBorder: "#4D3F2A",
                                    accentText: "#F4D58D",
                                    height: 132
                                ),
                                bindingConferencePortalStateSummaryCard(
                                    title: "Canonical draft path",
                                    detailKeypath: "conferenceChat.state.editor.toolingHint",
                                    noteKeypath: "conferenceChat.state.nextAction",
                                    accentBorder: "#2A4D61",
                                    accentText: "#B9E6FF",
                                    height: 132
                                )
                            ]
                        )
                    ),
                    bindingConferencePortalKeyText("conferenceChat.state.nextAction", fontSize: 12, foregroundColor: "#9AB3C3", lineLimit: 3)
                ]
            ),
            bindingConferencePortalCardSection(
                "Participants & Conversations",
                content: [
                    bindingConferencePortalKeyText("conferenceChat.state.participantsSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceChat.state.participants",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    ),
                    bindingConferencePortalKeyText("conferenceChat.state.conversationSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceChat.state.conversations",
                            flowElementSkeleton: bindingConferencePortalActionConnectionRowSkeleton()
                        )
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Recent Messages",
                content: [
                    bindingConferencePortalKeyText("conferenceChat.state.messageSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceChat.state.messages",
                            flowElementSkeleton: bindingConferencePortalTranscriptMessageRowSkeleton()
                        )
                    ),
                    bindingConferencePortalStaticText(
                        "Messages stay shared-relation safe here. HAVEN should show the same chat contract without pretending this is organizer-owned private state.",
                        fontSize: 12,
                        foregroundColor: "#88A2B1",
                        lineLimit: 4
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Free-text Composer",
                content: [
                    bindingConferencePortalKeyText("conferenceChat.state.editor.toolingHint", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                    .TextArea(
                        SkeletonTextArea(
                            text: nil,
                            sourceKeypath: "conferenceChat.editorDraft",
                            targetKeypath: "conferenceChat.sendMessage",
                            placeholder: "Skriv en fri konferansemelding",
                            minLines: 4,
                            maxLines: 10,
                            submitOnEnter: true,
                            editorMode: .plain,
                            modifiers: modifier {
                                $0.padding = 10
                                $0.background = "#10212D"
                                $0.cornerRadius = 12
                                $0.borderWidth = 1
                                $0.borderColor = "#2D566B"
                                $0.foregroundColor = "#F5FBFF"
                            }
                        )
                    ),
                    .HStack(
                        SkeletonHStack(
                            elements: [
                                bindingConferenceDirectActionButton(
                                    keypath: "conferenceChat.sendMessage",
                                    label: "Send fri melding"
                                ),
                                bindingConferenceDirectActionButton(
                                    keypath: "conferenceChat.setDraft",
                                    label: "Tøm utkast",
                                    payload: .object(["text": .string("")])
                                ),
                                bindingConferencePortalActionButton(
                                    "conferenceChat",
                                    actionKeypath: "openParticipantPortalWorkbench",
                                    label: "Tilbake til portalen"
                                )
                            ],
                            spacing: 10
                        )
                    ),
                ]
            ),
            bindingConferencePortalCardSection(
                "Demo Actions",
                content: [
                    bindingConferencePortalStaticText(
                        "These buttons exercise the same direct send path with concrete free-text payloads, so HAVEN verifies remote-style chat actions instead of a legacy snapshot-only flow.",
                        fontSize: 12,
                        foregroundColor: "#9AB3C3",
                        lineLimit: 4
                    ),
                    .HStack(
                        SkeletonHStack(
                            elements: [
                                bindingConferenceDirectActionButton(
                                    keypath: "conferenceChat.sendMessage",
                                    label: "Skal vi møtes i løpet av dagen?",
                                    payload: .object(["text": .string("Skal vi møtes i løpet av dagen?")])
                                ),
                                bindingConferenceDirectActionButton(
                                    keypath: "conferenceChat.sendMessage",
                                    label: "Send lett oppfølging",
                                    payload: .object(["text": .string("Hei! Skal vi fortsette praten her?")])
                                )
                            ]
                        )
                    )
                ]
            )
        ])
        root.modifiers = modifier {
            $0.padding = 12
            $0.background = ConferenceSurfacePalette.canvas
        }

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.background = ConferenceSurfacePalette.canvas
        }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func conferenceDemoLauncherWorkbenchConfiguration(
        displayName: String,
        summary: String
    ) -> CellConfiguration {
        var configuration = CellConfiguration(name: displayName)
        configuration.description = summary
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: "cell:///ConferenceDemoLauncher",
            sourceCellName: "ConferenceDemoLauncherLocalCell",
            purpose: "Conference demo launcher",
            purposeDescription: "Deterministisk startflate for conference-demoen i HAVEN. Hver knapp åpner en eksisterende conference-konfigurasjon i samme Porthole-session.",
            interests: ["conference", "demo", "launcher", "participant", "organizer", "binding", "web"],
            menuSlots: ["upperMid", "lowerMid"]
        )

        var launcherReference = CellReference(
            endpoint: "cell:///ConferenceDemoLauncher",
            subscribeFeed: false,
            label: "conferenceDemoLauncher"
        )
        launcherReference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(launcherReference)

        var root = SkeletonVStack(elements: [
            bindingConferencePortalCardSection(
                "Conference Demo Launcher",
                content: [
                    bindingConferencePortalStaticText(
                        "Conference Demo Launcher",
                        fontSize: 18,
                        fontWeight: "bold",
                        foregroundColor: "#F5FBFF"
                    ),
                    bindingConferencePortalKeyText("conferenceDemoLauncher.state.intro", fontSize: 12, foregroundColor: "#B9FBC0", lineLimit: 4),
                    .Grid(
                        SkeletonGrid(
                            columns: [.adaptive(min: 220, max: 320)],
                            spacing: 12,
                            elements: [
                                bindingConferencePortalStateSummaryCard(
                                    title: "Status nå",
                                    detailKeypath: "conferenceDemoLauncher.state.statusSummary",
                                    noteKeypath: "conferenceDemoLauncher.state.actionSummary",
                                    accentBorder: "#2F6B56",
                                    accentText: "#B9FBC0",
                                    height: 132
                                ),
                                bindingConferencePortalStateSummaryCard(
                                    title: "Readiness",
                                    detailKeypath: "conferenceDemoLauncher.state.readinessSummary",
                                    noteKeypath: "conferenceDemoLauncher.state.stretchSummary",
                                    accentBorder: "#2A4D61",
                                    accentText: "#B9E6FF",
                                    height: 132
                                ),
                                bindingConferencePortalStateSummaryCard(
                                    title: "Neste steg",
                                    detailKeypath: "conferenceDemoLauncher.state.nextStepSummary",
                                    noteKeypath: "conferenceDemoLauncher.state.identityLinkActSummary",
                                    accentBorder: "#4D3F2A",
                                    accentText: "#F4D58D",
                                    height: 132
                                )
                            ]
                        )
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Act 0 · Public Opener",
                content: [
                    bindingConferencePortalKeyText("conferenceDemoLauncher.state.publicActSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 4),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferencePortalActionButton(
                                "conferenceDemoLauncher",
                                actionKeypath: "launcher.openPublicSurface",
                                label: "Open public surface"
                            ),
                            bindingConferencePortalActionButton(
                                "conferenceDemoLauncher",
                                actionKeypath: "launcher.openParticipantCockpit",
                                label: "Open participant cockpit"
                            )
                        ])
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Act 0.5 · Scaffold Setup & Identity Link",
                content: [
                    bindingConferencePortalKeyText("conferenceDemoLauncher.state.identityLinkActSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 4),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferencePortalActionButton(
                                "conferenceDemoLauncher",
                                actionKeypath: "launcher.openIdentityLink",
                                label: "Open identity link setup"
                            )
                        ])
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Act 1 · Participant Cockpit",
                content: [
                    bindingConferencePortalKeyText("conferenceDemoLauncher.state.participantActSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 4),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferencePortalActionButton(
                                "conferenceDemoLauncher",
                                actionKeypath: "launcher.openParticipantCockpit",
                                label: "Open participant cockpit"
                            ),
                            bindingConferencePortalActionButton(
                                "conferenceDemoLauncher",
                                actionKeypath: "launcher.openParticipantChat",
                                label: "Open participant chat"
                            )
                        ])
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Act 2 · Organizer Perspective",
                content: [
                    bindingConferencePortalKeyText("conferenceDemoLauncher.state.organizerActSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 4),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferencePortalActionButton(
                                "conferenceDemoLauncher",
                                actionKeypath: "launcher.openControlTower",
                                label: "Open control tower"
                            ),
                            bindingConferencePortalActionButton(
                                "conferenceDemoLauncher",
                                actionKeypath: "launcher.openAIAssistant",
                                label: "Open AI assistant"
                            )
                        ])
                    )
                ]
            )
        ])
        root.modifiers = modifier {
            $0.padding = 12
            $0.background = ConferenceSurfacePalette.canvas
        }

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.background = ConferenceSurfacePalette.canvas
        }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func conferenceIdentityLinkWorkbenchConfiguration(
        displayName: String,
        summary: String
    ) -> CellConfiguration {
        var configuration = CellConfiguration(name: displayName)
        configuration.description = summary
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: "cell:///ConferenceIdentityLinkIntake",
            sourceCellName: "ConferenceIdentityLinkIntakeCell",
            purpose: "Conference scaffold setup and identity link",
            purposeDescription: "Mobil intake for scaffold setup og cross-vault identity-link challenges. HAVEN viser incoming challenge-data, requested scopes og lokal key-possession før web/scaffold fullfører approval.",
            interests: ["conference", "identity-link", "setup", "enrollment", "proofs", "scaffold"],
            menuSlots: ["upperMid", "lowerMid"]
        )

        var identityLinkReference = CellReference(
            endpoint: "cell:///ConferenceIdentityLinkIntake",
            subscribeFeed: false,
            label: "identityLink"
        )
        identityLinkReference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(identityLinkReference)

        var root = SkeletonVStack(elements: [
            bindingConferencePortalCardSection(
                "Conference Scaffold Setup & Identity Link",
                content: [
                    bindingConferencePortalKeyText("identityLink.state.workspace.title", fontSize: 18, fontWeight: "bold", foregroundColor: "#F5FBFF", lineLimit: 2),
                    bindingConferencePortalKeyText("identityLink.state.workspace.subtitle", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 4),
                    bindingConferencePortalKeyText("identityLink.state.workspace.notice", fontSize: 12, foregroundColor: "#B9FBC0", lineLimit: 4),
                    .Grid(
                        SkeletonGrid(
                            columns: [.adaptive(min: 220, max: 320)],
                            spacing: 12,
                            elements: [
                                bindingConferencePortalStateSummaryCard(
                                    title: "Status nå",
                                    detailKeypath: "identityLink.state.incoming.statusSummary",
                                    noteKeypath: "identityLink.state.review.actionSummary",
                                    accentBorder: "#2F6B56",
                                    accentText: "#B9FBC0",
                                    height: 132
                                ),
                                bindingConferencePortalStateSummaryCard(
                                    title: "Lokal review",
                                    detailKeypath: "identityLink.state.review.confirmationStatus",
                                    noteKeypath: "identityLink.state.review.localIdentitySummary",
                                    accentBorder: "#2A4D61",
                                    accentText: "#B9E6FF",
                                    height: 132
                                ),
                                bindingConferencePortalStateSummaryCard(
                                    title: "Neste steg",
                                    detailKeypath: "identityLink.state.review.nextStepSummary",
                                    noteKeypath: "identityLink.state.review.limitationSummary",
                                    accentBorder: "#4D3F2A",
                                    accentText: "#F4D58D",
                                    height: 132
                                )
                            ]
                        )
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Incoming challenge",
                content: [
                    bindingConferencePortalKeyText("identityLink.state.incoming.sourceSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                    bindingConferencePortalKeyText("identityLink.state.incoming.challengeSummary", fontSize: 12, foregroundColor: "#B9FBC0", lineLimit: 3),
                    bindingConferencePortalKeyText("identityLink.state.incoming.deviceSummary", fontSize: 12, foregroundColor: "#8DE1DA", lineLimit: 3),
                    bindingConferencePortalKeyText("identityLink.state.incoming.audienceSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                    bindingConferencePortalKeyText("identityLink.state.incoming.originSummary", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 3),
                    bindingConferencePortalKeyText("identityLink.state.incoming.entitySummary", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 3),
                    bindingConferencePortalKeyText("identityLink.state.incoming.domainSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                    bindingConferencePortalKeyText("identityLink.state.incoming.contextSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                    bindingConferencePortalKeyText("identityLink.state.incoming.scopeSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                    bindingConferencePortalKeyText("identityLink.state.incoming.expirySummary", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 3),
                    bindingConferencePortalKeyText("identityLink.state.incoming.proofSummary", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 3)
                ]
            ),
            bindingConferencePortalCardSection(
                "Open or paste challenge data",
                content: [
                    bindingConferencePortalStaticText(
                        "Åpne `haven://identity-link?...`, `haven://binding/add-device?...` eller lim inn QR/deep-link payload direkte her. HAVEN parser challenge-data uten å late som approval allerede er fullført.",
                        fontSize: 12,
                        foregroundColor: "#D7E7F2",
                        lineLimit: 5
                    ),
                    bindingConferencePortalTextArea(
                        sourceKeypath: "identityLink.state.draftInput",
                        targetKeypath: "identityLink.setDraftInput",
                        placeholder: "Lim inn haven://identity-link… eller JSON request her",
                        minLines: 4,
                        maxLines: 8
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferencePortalPrimaryActionButton(
                                "identityLink",
                                actionKeypath: "identityLink.importDraft",
                                label: "Import challenge"
                            ),
                            bindingConferencePortalActionButton(
                                "identityLink",
                                actionKeypath: "identityLink.clear",
                                label: "Clear"
                            )
                        ])
                    ),
                    bindingConferencePortalKeyText("identityLink.state.incoming.rawPreview", fontSize: 11, foregroundColor: "#88A2B1", lineLimit: 8)
                ]
            ),
            bindingConferencePortalCardSection(
                "Local HAVEN review",
                content: [
                    bindingConferencePortalKeyText("identityLink.state.review.localIdentitySummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 4),
                    bindingConferencePortalKeyText("identityLink.state.review.confirmationStatus", fontSize: 12, foregroundColor: "#B9FBC0", lineLimit: 4),
                    bindingConferencePortalKeyText("identityLink.state.review.localProofSummary", fontSize: 12, foregroundColor: "#8DE1DA", lineLimit: 4),
                    bindingConferencePortalKeyText("identityLink.state.review.enrollmentRequestPreview", fontSize: 11, foregroundColor: "#88A2B1", lineLimit: 5),
                    bindingConferencePortalKeyText("identityLink.state.review.limitationSummary", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 4),
                    bindingConferencePortalKeyText("identityLink.state.review.nextStepSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 4),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferencePortalPrimaryActionButton(
                                "identityLink",
                                actionKeypath: "identityLink.confirmLocalReview",
                                label: "Confirm local key & continue"
                            ),
                            bindingConferencePortalActionButton(
                                "identityLink",
                                actionKeypath: "identityLink.openLauncher",
                                label: "Back to launcher"
                            )
                        ])
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Complete same-Entity link",
                content: [
                    bindingConferencePortalStaticText(
                        "Lim inn completion envelope fra staging etter approval. HAVEN sender payloaden direkte til `identity.identityLinks.completeEnrollment`; ingen lokal mock, ingen antatt godkjenning.",
                        fontSize: 12,
                        foregroundColor: "#D7E7F2",
                        lineLimit: 5
                    ),
                    bindingConferencePortalKeyText("identityLink.state.completion.status", fontSize: 12, foregroundColor: "#B9FBC0", lineLimit: 4),
                    bindingConferencePortalKeyText("identityLink.state.completion.summary", fontSize: 12, foregroundColor: "#8DE1DA", lineLimit: 5),
                    bindingConferencePortalTextArea(
                        sourceKeypath: "identityLink.state.completion.packageInput",
                        targetKeypath: "identityLink.setCompletionPackageInput",
                        placeholder: "Lim inn IdentityLinkCompletionEnvelope JSON fra staging",
                        minLines: 5,
                        maxLines: 12
                    ),
                    bindingConferencePortalPrimaryActionButton(
                        "identityLink",
                        actionKeypath: "identityLink.completeApprovedLink",
                        label: "Complete via EntityAnchor"
                    ),
                    bindingConferencePortalKeyText("identityLink.state.completion.recordPreview", fontSize: 11, foregroundColor: "#88A2B1", lineLimit: 8)
                ]
            )
        ])
        root.modifiers = modifier {
            $0.padding = 12
            $0.background = ConferenceSurfacePalette.canvas
        }

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.background = ConferenceSurfacePalette.canvas
        }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func bindingConferencePortalCardSection(_ title: String, content: SkeletonElementList) -> SkeletonElement {
        var header = SkeletonText(text: title)
        header.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#F5FBFF"
        }

        var modifiers = SkeletonModifiers()
        modifiers.padding = 12
        modifiers.background = "#0F1B24"
        modifiers.cornerRadius = 12
        modifiers.borderWidth = 1
        modifiers.borderColor = "#1F3442"

        var section = SkeletonSection(header: .Text(header), content: content)
        section.modifiers = modifiers
        return .Section(section)
    }

    nonisolated private static func bindingConferencePortalStaticText(
        _ text: String,
        fontSize: Double? = nil,
        fontWeight: String? = nil,
        foregroundColor: String? = "#D7E7F2",
        lineLimit: Int? = nil
    ) -> SkeletonElement {
        var label = SkeletonText(text: text)
        if fontSize != nil || fontWeight != nil || foregroundColor != nil || lineLimit != nil {
            label.modifiers = modifier {
                $0.fontSize = fontSize
                $0.fontWeight = fontWeight
                $0.foregroundColor = foregroundColor
                $0.lineLimit = lineLimit
            }
        }
        return .Text(label)
    }

    nonisolated private static func bindingConferencePortalKeyText(
        _ keypath: String,
        fontSize: Double? = nil,
        fontWeight: String? = nil,
        foregroundColor: String? = "#D7E7F2",
        lineLimit: Int? = nil
    ) -> SkeletonElement {
        var label = SkeletonText(keypath: keypath)
        if fontSize != nil || fontWeight != nil || foregroundColor != nil || lineLimit != nil {
            label.modifiers = modifier {
                $0.fontSize = fontSize
                $0.fontWeight = fontWeight
                $0.foregroundColor = foregroundColor
                $0.lineLimit = lineLimit
            }
        }
        return .Text(label)
    }

    nonisolated private static func bindingConferencePortalInlineCardModifier() -> SkeletonModifiers {
        modifier {
            $0.padding = 12
            $0.background = "#122734"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#244457"
        }
    }

    nonisolated private static func bindingConferencePortalEmbeddedRadarLayout(baseKeypath: String) -> SkeletonElement {
        .VStack(
            SkeletonVStack(elements: [
                bindingConferencePortalRadarNodeCard(
                    keypath: "\(baseKeypath).ahead",
                    accentBorder: "#2A4D61",
                    accentText: "#B9E6FF",
                    height: 140
                ),
                .HStack(
                    SkeletonHStack(elements: [
                        bindingConferencePortalRadarNodeCard(
                            keypath: "\(baseKeypath).left",
                            accentBorder: "#244457",
                            accentText: "#8DE1DA",
                            height: 172
                        ),
                        bindingConferencePortalRadarNodeCard(
                            keypath: "\(baseKeypath).center",
                            accentBorder: "#2F6B56",
                            accentText: "#B9FBC0",
                            background: "#133226",
                            height: 188
                        ),
                        bindingConferencePortalRadarNodeCard(
                            keypath: "\(baseKeypath).right",
                            accentBorder: "#244457",
                            accentText: "#8DE1DA",
                            height: 172
                        )
                    ])
                ),
                bindingConferencePortalRadarNodeCard(
                    keypath: "\(baseKeypath).behind",
                    accentBorder: "#2A4D61",
                    accentText: "#B9E6FF",
                    height: 140
                ),
                bindingConferencePortalRadarNodeCard(
                    keypath: "\(baseKeypath).uncertain",
                    accentBorder: "#5E5531",
                    accentText: "#F6D679",
                    background: "#2A2213",
                    height: 140
                )
            ])
        )
    }

    nonisolated private static func bindingConferencePortalRadarNodeCard(
        keypath: String,
        accentBorder: String,
        accentText: String,
        background: String = "#122734",
        height: Double
    ) -> SkeletonElement {
        var section = SkeletonSection(content: [
            bindingConferencePortalKeyText("\(keypath).badge", fontSize: 11, fontWeight: "bold", foregroundColor: accentText, lineLimit: 1),
            bindingConferencePortalKeyText("\(keypath).relevanceBadge", fontSize: 11, fontWeight: "bold", foregroundColor: "#B9FBC0", lineLimit: 1),
            bindingConferencePortalKeyText("\(keypath).title", fontSize: 16, fontWeight: "bold", foregroundColor: "#F5FBFF", lineLimit: 2),
            bindingConferencePortalKeyText("\(keypath).subtitle", fontSize: 12, foregroundColor: accentText, lineLimit: 2),
            bindingConferencePortalKeyText("\(keypath).detail", fontSize: 12, foregroundColor: "#D5E4ED", lineLimit: 3),
            bindingConferencePortalKeyText("\(keypath).summary", fontSize: 12, foregroundColor: "#BFD4E0", lineLimit: 3),
            bindingConferencePortalKeyText("\(keypath).note", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 2)
        ])
        section.modifiers = modifier {
            $0.padding = 12
            $0.background = background
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = accentBorder
            $0.height = height
            $0.maxWidthInfinity = true
        }
        return .Section(section)
    }

    nonisolated private static func bindingConferencePortalStateSummaryCard(
        title: String,
        detailKeypath: String,
        noteKeypath: String? = nil,
        accentBorder: String = "#244457",
        accentText: String = "#8DE1DA",
        background: String = "#122734",
        height: Double = 148
    ) -> SkeletonElement {
        var sectionContent: SkeletonElementList = [
            bindingConferencePortalStaticText(
                title,
                fontSize: 11,
                fontWeight: "bold",
                foregroundColor: accentText,
                lineLimit: 1
            ),
            bindingConferencePortalKeyText(
                detailKeypath,
                fontSize: 13,
                fontWeight: "semibold",
                foregroundColor: "#F5FBFF",
                lineLimit: 3
            )
        ]

        if let noteKeypath {
            sectionContent.append(
                bindingConferencePortalKeyText(
                    noteKeypath,
                    fontSize: 12,
                    foregroundColor: "#9AB3C3",
                    lineLimit: 4
                )
            )
        }

        var section = SkeletonSection(content: sectionContent)
        section.modifiers = modifier {
            $0.padding = 12
            $0.background = background
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = accentBorder
            $0.height = height
        }
        return .Section(section)
    }

    nonisolated private static func bindingConferencePortalCollectionGrid(
        keypath: String,
        min: Double = 220,
        max: Double = 320,
        itemSkeleton: SkeletonElement
    ) -> SkeletonElement {
        .Grid(
            SkeletonGrid(
                columns: [.adaptive(min: min, max: max)],
                spacing: 12,
                keypath: keypath,
                itemSkeleton: itemSkeleton
            )
        )
    }

    nonisolated private static func bindingConferencePortalTranscriptList(keypath: String) -> SkeletonElement {
        var transcriptList = SkeletonList(
            keypath: keypath,
            flowElementSkeleton: bindingConferencePortalTranscriptMessageRowSkeleton()
        )
        transcriptList.modifiers = modifier {
            $0.padding = 10
            $0.background = "#10212D"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = "#244457"
            $0.height = 380
        }
        return .List(transcriptList)
    }

    nonisolated private static func bindingConferencePortalCompactActionList(keypath: String) -> SkeletonElement {
        var actionList = SkeletonList(
            keypath: keypath,
            flowElementSkeleton: bindingConferencePortalCompactActionRowSkeleton()
        )
        actionList.modifiers = modifier {
            $0.padding = 10
            $0.background = "#10212D"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = "#244457"
            $0.height = 210
        }
        return .List(actionList)
    }

    nonisolated private static func bindingConferencePortalBadgeKeyText(_ keypath: String) -> SkeletonElement {
        var label = SkeletonText(keypath: keypath)
        label.modifiers = modifier {
            $0.padding = 6
            $0.background = "#122734"
            $0.cornerRadius = 8
            $0.borderWidth = 1
            $0.borderColor = "#244457"
            $0.foregroundColor = "#C6F5EE"
            $0.fontSize = 12
            $0.fontWeight = "semibold"
        }
        return .Text(label)
    }

    nonisolated private static func bindingConferencePortalTitleDetailRowSkeleton() -> SkeletonVStack {
        SkeletonVStack(elements: [
            bindingConferencePortalKeyText("title", fontSize: 15, fontWeight: "bold", foregroundColor: "#F5FBFF"),
            bindingConferencePortalKeyText("detail", fontSize: 12, foregroundColor: "#D5E4ED"),
            .Divider(SkeletonDivider())
        ])
    }

    nonisolated private static func bindingConferencePortalTitleSubtitleDetailRowSkeleton() -> SkeletonVStack {
        SkeletonVStack(elements: [
            bindingConferencePortalKeyText("title", fontSize: 15, fontWeight: "bold", foregroundColor: "#F5FBFF"),
            bindingConferencePortalKeyText("subtitle", fontSize: 12, foregroundColor: "#8DE1DA"),
            bindingConferencePortalKeyText("detail", fontSize: 12, foregroundColor: "#D5E4ED"),
            .Divider(SkeletonDivider())
        ])
    }

    nonisolated private static func bindingConferencePortalActionConnectionRowSkeleton() -> SkeletonVStack {
        SkeletonVStack(elements: [
            bindingConferencePortalKeyText("title", fontSize: 15, fontWeight: "bold", foregroundColor: "#F5FBFF"),
            bindingConferencePortalKeyText("subtitle", fontSize: 12, foregroundColor: "#8DE1DA"),
            bindingConferencePortalKeyText("detail", fontSize: 12, foregroundColor: "#D5E4ED"),
            bindingConferencePortalKeyText("note", fontSize: 11, foregroundColor: "#88A2B1", lineLimit: 2),
            .Divider(SkeletonDivider())
        ])
    }

    nonisolated private static func bindingConferencePublicFeatureCardSkeleton() -> SkeletonVStack {
        var stack = SkeletonVStack(elements: [
            bindingConferencePortalKeyText("subtitle", fontSize: 11, fontWeight: "semibold", foregroundColor: "#7FD6D0", lineLimit: 1),
            bindingConferencePortalKeyText("title", fontSize: 18, fontWeight: "bold", foregroundColor: "#F5FBFF", lineLimit: 2),
            bindingConferencePortalKeyText("detail", fontSize: 13, foregroundColor: "#D7E7F2", lineLimit: 5),
            bindingConferencePortalKeyText("note", fontSize: 11, foregroundColor: "#88A2B1", lineLimit: 2),
            .Divider(SkeletonDivider())
        ])
        stack.modifiers = modifier {
            $0.padding = 14
            $0.background = "#102432"
            $0.cornerRadius = 16
            $0.borderWidth = 1
            $0.borderColor = "#35617A"
            $0.height = 176
        }
        return stack
    }

    nonisolated private static func bindingConferencePublicAccessCardSkeleton() -> SkeletonVStack {
        var stack = SkeletonVStack(elements: [
            bindingConferencePortalKeyText("title", fontSize: 14, fontWeight: "bold", foregroundColor: "#F5FBFF", lineLimit: 2),
            bindingConferencePortalKeyText("detail", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 4),
            bindingConferencePortalKeyText("note", fontSize: 11, foregroundColor: "#88A2B1", lineLimit: 2),
            .Divider(SkeletonDivider())
        ])
        stack.modifiers = modifier {
            $0.padding = 12
            $0.background = "#112938"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = "#2D566B"
            $0.height = 144
        }
        return stack
    }

    nonisolated private static func bindingConferencePortalActionButton(
        _ referenceLabel: String,
        actionKeypath: String,
        label: String,
        payload: ValueType = .bool(true),
        responseMode: String? = nil,
        url: String? = nil
    ) -> SkeletonElement {
        var actionObject: Object = [
            "keypath": .string(actionKeypath),
            "payload": payload
        ]
        if let responseMode,
           !responseMode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            actionObject["responseMode"] = .string(responseMode)
        }
        var button = SkeletonButton(
            keypath: url == nil ? "\(referenceLabel).dispatchAction" : "dispatchAction",
            label: label,
            url: url,
            payload: .object(actionObject)
        )
        button.modifiers = modifier {
            $0.padding = 8
            $0.background = "#173140"
            $0.cornerRadius = 8
            $0.borderWidth = 1
            $0.borderColor = "#2D566B"
            $0.foregroundColor = "#D9FBFF"
        }
        return .Button(button)
    }

    nonisolated private static func bindingConferencePortalPrimaryActionButton(
        _ referenceLabel: String,
        actionKeypath: String,
        label: String,
        payload: ValueType = .bool(true)
    ) -> SkeletonElement {
        let actionObject: Object = [
            "keypath": .string(actionKeypath),
            "payload": payload
        ]
        var button = SkeletonButton(
            keypath: "\(referenceLabel).dispatchAction",
            label: label,
            payload: .object(actionObject)
        )
        button.modifiers = modifier {
            $0.padding = 8
            $0.background = "#1E5C49"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#2F6B56"
            $0.foregroundColor = "#F5FBFF"
            $0.fontWeight = "semibold"
        }
        return .Button(button)
    }

    nonisolated private static func bindingConferenceDirectActionButton(
        keypath: String,
        label: String,
        payload: ValueType = .bool(true),
        url: String? = nil
    ) -> SkeletonElement {
        var button = SkeletonButton(
            keypath: keypath,
            label: label,
            url: url,
            payload: payload
        )
        button.modifiers = modifier {
            $0.padding = 8
            $0.background = "#173140"
            $0.cornerRadius = 8
            $0.borderWidth = 1
            $0.borderColor = "#2D566B"
            $0.foregroundColor = "#D9FBFF"
        }
        return .Button(button)
    }

    nonisolated private static func bindingConferencePortalTextField(
        sourceKeypath: String?,
        targetKeypath: String,
        placeholder: String
    ) -> SkeletonElement {
        .TextField(
            SkeletonTextField(
                text: nil,
                sourceKeypath: sourceKeypath,
                targetKeypath: targetKeypath,
                placeholder: placeholder,
                modifiers: modifier {
                    $0.padding = 8
                    $0.background = "#10212D"
                    $0.cornerRadius = 8
                    $0.borderWidth = 1
                    $0.borderColor = "#2D566B"
                    $0.foregroundColor = "#EAF7FF"
                }
            )
        )
    }

    nonisolated private static func bindingConferencePortalTextArea(
        sourceKeypath: String?,
        targetKeypath: String,
        placeholder: String,
        minLines: Int,
        maxLines: Int
    ) -> SkeletonElement {
        .TextArea(
            SkeletonTextArea(
                text: nil,
                sourceKeypath: sourceKeypath,
                targetKeypath: targetKeypath,
                placeholder: placeholder,
                minLines: minLines,
                maxLines: maxLines,
                submitOnEnter: false,
                modifiers: modifier {
                    $0.padding = 8
                    $0.background = "#10212D"
                    $0.cornerRadius = 8
                    $0.borderWidth = 1
                    $0.borderColor = "#2D566B"
                    $0.foregroundColor = "#EAF7FF"
                }
            )
        )
    }

    nonisolated private static func bindingConferencePortalChatTextArea(
        sourceKeypath: String?,
        targetKeypath: String,
        placeholder: String,
        minLines: Int,
        maxLines: Int
    ) -> SkeletonElement {
        .TextArea(
            SkeletonTextArea(
                text: nil,
                sourceKeypath: sourceKeypath,
                targetKeypath: targetKeypath,
                placeholder: placeholder,
                minLines: minLines,
                maxLines: maxLines,
                submitOnEnter: false,
                modifiers: modifier {
                    $0.padding = 10
                    $0.background = "#10212D"
                    $0.cornerRadius = 12
                    $0.borderWidth = 1
                    $0.borderColor = "#2D566B"
                    $0.foregroundColor = "#F5FBFF"
                }
            )
        )
    }

    nonisolated private static func bindingConferencePortalHeroSection(referenceLabel: String) -> SkeletonElement {
        bindingConferencePortalCardSection(
            "Portal Header",
            content: [
                .HStack(
                    SkeletonHStack(elements: [
                        .VStack(
                            SkeletonVStack(elements: [
                                bindingConferencePortalStaticText(
                                    "DELTAGERPORTAL",
                                    fontSize: 12,
                                    fontWeight: "bold",
                                    foregroundColor: "#7FD6D0"
                                ),
                                bindingConferencePortalKeyText(
                                    "\(referenceLabel).state.workspace.title",
                                    fontSize: 20,
                                    fontWeight: "bold",
                                    foregroundColor: "#F5FBFF"
                                ),
                                bindingConferencePortalKeyText(
                                    "\(referenceLabel).state.workspace.subtitle",
                                    fontSize: 13,
                                    foregroundColor: "#9AB3C3"
                                ),
                                bindingConferencePortalBadgeKeyText("\(referenceLabel).state.workspace.conferenceBadge"),
                                bindingConferencePortalBadgeKeyText("\(referenceLabel).state.workspace.privacyBadge")
                            ])
                        ),
                        .Spacer(SkeletonSpacer()),
                        .VStack(
                            SkeletonVStack(elements: [
                                bindingConferencePortalBadgeKeyText("\(referenceLabel).state.workspace.participantBadge"),
                                bindingConferencePortalBadgeKeyText("\(referenceLabel).state.workspace.programBadge"),
                                bindingConferencePortalBadgeKeyText("\(referenceLabel).state.workspace.matchBadge"),
                                bindingConferencePortalBadgeKeyText("\(referenceLabel).state.workspace.meetingBadge")
                            ])
                        )
                    ])
                ),
                bindingConferencePortalKeyText(
                    "\(referenceLabel).state.workspace.nextStep",
                    fontSize: 13,
                    foregroundColor: "#D7E7F2"
                ),
                bindingConferencePortalKeyText(
                    "\(referenceLabel).state.workspace.previewNotice",
                    fontSize: 12,
                    foregroundColor: "#88A2B1"
                )
            ]
        )
    }

    nonisolated private static func bindingConferencePortalAgendaSection(referenceLabel: String) -> SkeletonElement {
        bindingConferencePortalCardSection(
            "Min Agenda",
            content: [
                bindingConferencePortalStaticText(
                    "Velg hvordan agendaen skal vises. Oppsummeringene under forklarer alltid hvilken visning og hvilket fokus som er aktivt akkurat nå.",
                    fontSize: 12,
                    foregroundColor: "#9AB3C3",
                    lineLimit: 4
                ),
                bindingConferencePortalKeyText("\(referenceLabel).state.intro"),
                bindingConferencePortalKeyText("\(referenceLabel).state.agendaSummary"),
                .Grid(
                    SkeletonGrid(
                        columns: [.adaptive(min: 220, max: 320)],
                        spacing: 12,
                        elements: [
                            bindingConferencePortalStateSummaryCard(
                                title: "Visning nå",
                                detailKeypath: "\(referenceLabel).state.viewSummary",
                                noteKeypath: "\(referenceLabel).state.timelineSummary",
                                accentBorder: "#2A4D61",
                                accentText: "#B9E6FF"
                            ),
                            bindingConferencePortalStateSummaryCard(
                                title: "Fokus nå",
                                detailKeypath: "\(referenceLabel).state.trackSummary",
                                noteKeypath: "\(referenceLabel).state.status",
                                accentBorder: "#2F6B56",
                                accentText: "#B9FBC0"
                            ),
                            bindingConferencePortalStateSummaryCard(
                                title: "Lagring",
                                detailKeypath: "\(referenceLabel).state.storageSummary",
                                noteKeypath: "\(referenceLabel).state.persistenceStatus",
                                accentBorder: "#4D3F2A",
                                accentText: "#F6D679"
                            ),
                            bindingConferencePortalStateSummaryCard(
                                title: "Klar til neste steg",
                                detailKeypath: "\(referenceLabel).state.recommendedSummary",
                                noteKeypath: "\(referenceLabel).state.savedSummary",
                                accentBorder: "#244457",
                                accentText: "#8DE1DA"
                            )
                        ]
                    )
                ),
                bindingConferencePortalStaticText(
                    "Raskt valg viser alltid hva som er aktivt nå. Første klikk skjer i denne siden, og valgkortene under oppdateres med en gang.",
                    fontSize: 12,
                    foregroundColor: "#9AB3C3",
                    lineLimit: 3
                ),
                .Grid(
                    SkeletonGrid(
                        columns: [.adaptive(min: 220, max: 320)],
                        spacing: 12,
                        keypath: "\(referenceLabel).state.modeChoices",
                        itemSkeleton: bindingConferencePortalSelectionChipCardSkeleton()
                    )
                ),
                .Grid(
                    SkeletonGrid(
                        columns: [.adaptive(min: 220, max: 320)],
                        spacing: 12,
                        keypath: "\(referenceLabel).state.trackChoices",
                        itemSkeleton: bindingConferencePortalSelectionChipCardSkeleton()
                    )
                ),
                bindingConferencePortalKeyText("\(referenceLabel).state.actionSummary", fontSize: 12, foregroundColor: "#B9FBC0", lineLimit: 3),
                bindingConferencePortalKeyText("\(referenceLabel).state.selectionSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                bindingConferencePortalKeyText("\(referenceLabel).state.navigationSummary", fontSize: 12, foregroundColor: "#9AB3C3", lineLimit: 4),
                bindingConferencePortalKeyText("\(referenceLabel).state.nextStepSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 4),
                bindingConferencePortalCollectionGrid(
                    keypath: "\(referenceLabel).state.focusedActions",
                    min: 240,
                    max: 320,
                    itemSkeleton: bindingConferencePortalActionConnectionCardSkeleton()
                ),
                .Grid(
                    SkeletonGrid(
                        columns: [.adaptive(min: 220, max: 280)],
                        spacing: 12,
                        keypath: "\(referenceLabel).state.trackOptions",
                        itemSkeleton: bindingConferencePortalSessionCardSkeleton()
                    )
                ),
                .Grid(
                    SkeletonGrid(
                        columns: [.adaptive(min: 220, max: 320)],
                        spacing: 12,
                        keypath: "\(referenceLabel).state.recommendedSessions",
                        itemSkeleton: bindingConferencePortalSessionCardSkeleton()
                    )
                ),
                bindingConferencePortalCollectionGrid(
                    keypath: "\(referenceLabel).state.savedSessions",
                    itemSkeleton: bindingConferencePortalActionTimelineCardSkeleton()
                ),
                bindingConferencePortalCollectionGrid(
                    keypath: "\(referenceLabel).state.timelineSessions",
                    itemSkeleton: bindingConferencePortalActionTimelineCardSkeleton()
                )
            ]
        )
    }

    nonisolated private static func bindingConferencePortalSessionMatrixSection(referenceLabel: String) -> SkeletonElement {
        bindingConferencePortalCardSection(
            "Program Matrix",
            content: [
                bindingConferencePortalStaticText(
                    "Dette er den strammere programvisningen for dagen: rask filtrering øverst, så spor og sesjoner som kompakte handlingskort. Vi holder oss til samme portable data-kontrakt som resten av agendaen.",
                    fontSize: 12,
                    foregroundColor: "#9AB3C3",
                    lineLimit: 4
                ),
                bindingConferencePortalKeyText("\(referenceLabel).state.viewSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                bindingConferencePortalKeyText("\(referenceLabel).state.selectionSummary", fontSize: 12, foregroundColor: "#B9FBC0", lineLimit: 3),
                bindingConferencePortalKeyText("\(referenceLabel).state.navigationSummary", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 3),
                .Grid(
                    SkeletonGrid(
                        columns: [.adaptive(min: 220, max: 320)],
                        spacing: 12,
                        elements: [
                            bindingConferencePortalStateSummaryCard(
                                title: "Filter nå",
                                detailKeypath: "\(referenceLabel).state.trackSummary",
                                noteKeypath: "\(referenceLabel).state.status",
                                accentBorder: "#2A4D61",
                                accentText: "#B9E6FF",
                                height: 132
                            ),
                            bindingConferencePortalStateSummaryCard(
                                title: "Anbefalt nå",
                                detailKeypath: "\(referenceLabel).state.recommendedSummary",
                                noteKeypath: "\(referenceLabel).state.nextStepSummary",
                                accentBorder: "#4D3F2A",
                                accentText: "#F6D679",
                                height: 132
                            ),
                            bindingConferencePortalStateSummaryCard(
                                title: "Lagret nå",
                                detailKeypath: "\(referenceLabel).state.savedSummary",
                                noteKeypath: "\(referenceLabel).state.persistenceStatus",
                                accentBorder: "#2F6B56",
                                accentText: "#B9FBC0",
                                height: 132
                            )
                        ]
                    )
                ),
                bindingConferencePortalStaticText(
                    "Rask filtrering uttrykkes fortsatt med vanlige selection-kort. Det gir samme handlinger som tabs, men uten ny skeleton-primitive.",
                    fontSize: 12,
                    foregroundColor: "#D7E7F2",
                    lineLimit: 3
                ),
                .Grid(
                    SkeletonGrid(
                        columns: [.adaptive(min: 220, max: 320)],
                        spacing: 12,
                        keypath: "\(referenceLabel).state.modeChoices",
                        itemSkeleton: bindingConferencePortalSelectionChipCardSkeleton()
                    )
                ),
                .Grid(
                    SkeletonGrid(
                        columns: [.adaptive(min: 220, max: 320)],
                        spacing: 12,
                        keypath: "\(referenceLabel).state.trackChoices",
                        itemSkeleton: bindingConferencePortalSelectionChipCardSkeleton()
                    )
                ),
                bindingConferencePortalStaticText(
                    "Spor først, deretter anbefalte økter. Hvert kort er fortsatt et vanlig skeleton-kort med action-routing gjennom dataene det bærer.",
                    fontSize: 12,
                    foregroundColor: "#9AB3C3",
                    lineLimit: 3
                ),
                bindingConferencePortalCollectionGrid(
                    keypath: "\(referenceLabel).state.trackOptions",
                    min: 220,
                    max: 280,
                    itemSkeleton: bindingConferencePortalSessionMatrixCardSkeleton()
                ),
                bindingConferencePortalCollectionGrid(
                    keypath: "\(referenceLabel).state.recommendedSessions",
                    min: 220,
                    max: 320,
                    itemSkeleton: bindingConferencePortalSessionMatrixCardSkeleton()
                ),
                bindingConferencePortalCollectionGrid(
                    keypath: "\(referenceLabel).state.timelineSessions",
                    min: 220,
                    max: 320,
                    itemSkeleton: bindingConferencePortalSessionMatrixCardSkeleton()
                )
            ]
        )
    }

    nonisolated private static func bindingConferencePortalRecommendationsSection(referenceLabel: String) -> SkeletonElement {
        bindingConferencePortalCardSection(
            "Dine Personlige Anbefalinger",
            content: [
                bindingConferencePortalStaticText(
                    "Bruk anbefalingene til å velge hvem du vil følge opp. Første klikk skjer i denne siden: bruk Vis i siden for å fokusere på en person her. Deretter blir neste steg tydelig under anbefalingene.",
                    fontSize: 12,
                    foregroundColor: "#9AB3C3",
                    lineLimit: 4
                ),
                bindingConferencePortalKeyText("\(referenceLabel).state.intro"),
                bindingConferencePortalKeyText("\(referenceLabel).state.filterSummary"),
                bindingConferencePortalKeyText("\(referenceLabel).state.status"),
                bindingConferencePortalKeyText("\(referenceLabel).state.recommendationSummary"),
                .Grid(
                    SkeletonGrid(
                        columns: [.adaptive(min: 220, max: 320)],
                        spacing: 12,
                        elements: [
                            bindingConferencePortalStateSummaryCard(
                                title: "Status nå",
                                detailKeypath: "\(referenceLabel).state.statusSummary",
                                noteKeypath: "\(referenceLabel).state.actionSummary",
                                accentBorder: "#2F6B56",
                                accentText: "#B9FBC0",
                                height: 132
                            ),
                            bindingConferencePortalStateSummaryCard(
                                title: "Valg nå",
                                detailKeypath: "\(referenceLabel).state.selectionSummary",
                                noteKeypath: "\(referenceLabel).state.navigationSummary",
                                accentBorder: "#2A4D61",
                                accentText: "#B9E6FF",
                                height: 132
                            ),
                            bindingConferencePortalStateSummaryCard(
                                title: "Neste steg",
                                detailKeypath: "\(referenceLabel).state.nextStepSummary",
                                noteKeypath: "\(referenceLabel).state.searchSummary",
                                accentBorder: "#4D3F2A",
                                accentText: "#F4D58D",
                                height: 132
                            )
                        ]
                    )
                ),
                .Grid(
                    SkeletonGrid(
                        columns: [.adaptive(min: 220, max: 320)],
                        spacing: 12,
                        elements: [
                            bindingConferencePortalStateSummaryCard(
                                title: "Offentlig profil",
                                detailKeypath: "\(referenceLabel).state.focusedProfile.publicProfileSummary",
                                noteKeypath: "\(referenceLabel).state.focusedProfile.profileDetail",
                                accentBorder: "#2A4D61",
                                accentText: "#B9E6FF",
                                height: 148
                            ),
                            bindingConferencePortalStateSummaryCard(
                                title: "Match nå",
                                detailKeypath: "\(referenceLabel).state.focusedProfile.fitSummary",
                                noteKeypath: "\(referenceLabel).state.focusedProfile.note",
                                accentBorder: "#2F6B56",
                                accentText: "#B9FBC0",
                                height: 148
                            ),
                            bindingConferencePortalStateSummaryCard(
                                title: "Neste steg",
                                detailKeypath: "\(referenceLabel).state.focusedProfile.nextStep",
                                noteKeypath: "\(referenceLabel).state.navigationSummary",
                                accentBorder: "#4D3F2A",
                                accentText: "#F4D58D",
                                height: 148
                            ),
                            bindingConferencePortalStateSummaryCard(
                                title: "Bra åpning",
                                detailKeypath: "\(referenceLabel).state.focusedProfile.openingPrompt",
                                noteKeypath: "\(referenceLabel).state.focusedProfile.simulationSummary",
                                accentBorder: "#2F6B56",
                                accentText: "#B9FBC0",
                                height: 148
                            )
                        ]
                    )
                ),
                bindingConferencePortalKeyText("\(referenceLabel).state.focusedProfile.selectionBadge", fontSize: 12, fontWeight: "bold", foregroundColor: "#7FD6D0", lineLimit: 1),
                bindingConferencePortalKeyText("\(referenceLabel).state.focusedProfile.title", fontSize: 18, fontWeight: "bold", foregroundColor: "#F5FBFF", lineLimit: 2),
                bindingConferencePortalKeyText("\(referenceLabel).state.focusedProfile.subtitle", fontSize: 12, foregroundColor: "#8DE1DA", lineLimit: 2),
                bindingConferencePortalKeyText("\(referenceLabel).state.focusedProfile.detail", fontSize: 12, foregroundColor: "#D5E4ED", lineLimit: 3),
                bindingConferencePortalKeyText("\(referenceLabel).state.focusedProfile.note", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 3),
                .HStack(
                    SkeletonHStack(
                        elements: [
                            bindingConferencePortalPrimaryActionButton(
                                referenceLabel,
                                actionKeypath: "discovery.startChatWithFocusedPerson",
                                label: "Klargjør chat"
                            ),
                            bindingConferenceDirectActionButton(
                                keypath: "chatSnapshot.dispatchAction",
                                label: "Åpne chatflate",
                                payload: .object([
                                    "keypath": .string("openChatWorkbenchForSelectedParticipant"),
                                    "payload": .bool(true)
                                ])
                            ),
                            bindingConferencePortalActionButton(
                                referenceLabel,
                                actionKeypath: "matchmaking.toggleFollowUpForFocusedPerson",
                                label: "Marker for oppfølging"
                            ),
                            bindingConferencePortalActionButton(
                                referenceLabel,
                                actionKeypath: "scheduling.createMeetingRequestForFocusedPerson",
                                label: "Be om møte"
                            )
                        ]
                    )
                ),
                bindingConferencePortalStaticText(
                    "Flere anbefalte deltakere",
                    fontSize: 12,
                    fontWeight: "bold",
                    foregroundColor: "#9AB3C3",
                    lineLimit: 1
                ),
                bindingConferencePortalRecommendationCards(referenceLabel: referenceLabel),
                bindingConferencePortalCollectionGrid(
                    keypath: "\(referenceLabel).state.searchResults",
                    itemSkeleton: bindingConferencePortalActionConnectionCardSkeleton()
                ),
                .HStack(
                    SkeletonHStack(elements: [
                        bindingConferencePortalActionButton(
                            referenceLabel,
                            actionKeypath: "matchmaking.refreshRecommendations",
                            label: "Oppdater treff"
                        ),
                        bindingConferencePortalActionButton(
                            referenceLabel,
                            actionKeypath: "matchmaking.setFilters",
                            label: "Bytt filter"
                        ),
                        bindingConferencePortalActionButton(
                            referenceLabel,
                            actionKeypath: "matchmaking.searchPeople",
                            label: "Finn governance-matcher",
                            payload: .object(["query": .string("governance")])
                        ),
                        bindingConferencePortalActionButton(
                            referenceLabel,
                            actionKeypath: "scheduling.createMeetingRequest",
                            label: "Be om møte",
                            payload: .object(["source": .string("participant-shell")])
                        )
                    ])
                )
            ]
        )
    }

    nonisolated private static func bindingConferencePortalTimelineSection(referenceLabel: String) -> SkeletonElement {
        bindingConferencePortalCardSection(
            "Min Tidslinje",
            content: [
                bindingConferencePortalKeyText("\(referenceLabel).state.meetings.intro"),
                bindingConferencePortalKeyText("\(referenceLabel).state.meetings.requestSummary"),
                bindingConferencePortalKeyText("\(referenceLabel).state.meetings.slotSummary"),
                bindingConferencePortalKeyText("\(referenceLabel).state.meetings.meetingSummary"),
                bindingConferencePortalKeyText("\(referenceLabel).state.meetings.chatSummary"),
                bindingConferencePortalKeyText("\(referenceLabel).state.meetings.exportStatus"),
                bindingConferencePortalCollectionGrid(
                    keypath: "\(referenceLabel).state.meetings.requests",
                    itemSkeleton: bindingConferencePortalTimelineCardSkeleton()
                ),
                bindingConferencePortalCollectionGrid(
                    keypath: "\(referenceLabel).state.meetings.confirmedMeetings",
                    itemSkeleton: bindingConferencePortalTimelineCardSkeleton()
                ),
                .HStack(
                    SkeletonHStack(elements: [
                        bindingConferencePortalActionButton(
                            referenceLabel,
                            actionKeypath: "scheduling.createMeetingRequest",
                            label: "Be om møte",
                            payload: .object(["source": .string("binding-participant-portal")])
                        ),
                        bindingConferencePortalActionButton(
                            referenceLabel,
                            actionKeypath: "scheduling.exportICal",
                            label: "Forbered iCal"
                        ),
                        bindingConferencePortalActionButton(
                            referenceLabel,
                            actionKeypath: "scheduling.respondMeetingRequest",
                            label: "Godta ventende"
                        )
                    ])
                )
            ]
        )
    }

    nonisolated private static func bindingConferencePortalChatSection(referenceLabel: String) -> SkeletonElement {
        bindingConferencePortalCardSection(
            "Chat og Oppfølging",
            content: [
                bindingConferencePortalStaticText(
                    "Når en chat er klar, skal det være synlig her med én gang. Denne seksjonen gjør handoffen fra deltagervalg til faktisk samtaleflate mye tydeligere.",
                    fontSize: 12,
                    foregroundColor: "#9AB3C3",
                    lineLimit: 4
                ),
                .Grid(
                    SkeletonGrid(
                        columns: [.adaptive(min: 220, max: 320)],
                        spacing: 12,
                        elements: [
                            bindingConferencePortalStateSummaryCard(
                                title: "Status nå",
                                detailKeypath: "\(referenceLabel).state.statusSummary",
                                noteKeypath: "\(referenceLabel).state.actionSummary",
                                accentBorder: "#2F6B56",
                                accentText: "#B9FBC0",
                                height: 132
                            ),
                            bindingConferencePortalStateSummaryCard(
                                title: "Valg nå",
                                detailKeypath: "\(referenceLabel).state.selectionSummary",
                                noteKeypath: "\(referenceLabel).state.threadSummary",
                                accentBorder: "#2A4D61",
                                accentText: "#B9E6FF",
                                height: 132
                            ),
                            bindingConferencePortalStateSummaryCard(
                                title: "Neste steg",
                                detailKeypath: "\(referenceLabel).state.nextStepSummary",
                                noteKeypath: "\(referenceLabel).state.recentMessagesSummary",
                                accentBorder: "#4D3F2A",
                                accentText: "#F4D58D",
                                height: 132
                            )
                        ]
                    )
                ),
                bindingConferencePortalKeyText("\(referenceLabel).state.focusedThread.selectionBadge", fontSize: 12, fontWeight: "bold", foregroundColor: "#7FD6D0", lineLimit: 1),
                bindingConferencePortalKeyText("\(referenceLabel).state.focusedThread.title", fontSize: 16, fontWeight: "bold", foregroundColor: "#F5FBFF", lineLimit: 2),
                bindingConferencePortalKeyText("\(referenceLabel).state.focusedThread.subtitle", fontSize: 12, foregroundColor: "#8DE1DA", lineLimit: 2),
                bindingConferencePortalKeyText("\(referenceLabel).state.focusedThread.detail", fontSize: 12, foregroundColor: "#D5E4ED", lineLimit: 3),
                bindingConferencePortalKeyText("\(referenceLabel).state.focusedThread.note", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 3),
                bindingConferencePortalCollectionGrid(
                    keypath: "\(referenceLabel).state.focusedActions",
                    itemSkeleton: bindingConferencePortalActionConnectionCardSkeleton()
                ),
                .HStack(
                    SkeletonHStack(elements: [
                        bindingConferencePortalActionButton(
                            referenceLabel,
                            actionKeypath: "openChatWorkbench",
                            label: "Åpne chatflate"
                        )
                    ])
                )
            ]
        )
    }

    nonisolated private static func bindingConferencePortalDiscoverySection(referenceLabel: String) -> SkeletonElement {
        var snapshotReference = SkeletonCellReference(
            keypath: referenceLabel,
            topic: "discoverySnapshot.snapshot"
        )
        snapshotReference.flowElementSkeleton = SkeletonVStack(elements: [
            bindingConferencePortalCardSection(
                "Entity Discovery",
                content: [
                    bindingConferencePortalStaticText(
                        "Når en person eller gruppe ser lovende ut, skal første klikk fortsatt skje i denne siden. Bruk Vis i siden for å fokusere på kandidaten her, og ta deretter neste steg fra den valgte discovery-flaten.",
                        fontSize: 12,
                        foregroundColor: "#9AB3C3",
                        lineLimit: 4
                    ),
                    bindingConferencePortalKeyText("intro"),
                    bindingConferencePortalKeyText("status"),
                    bindingConferencePortalKeyText("alignmentSummary"),
                    bindingConferencePortalKeyText("proofSummary"),
                    bindingConferencePortalKeyText("sourceSummary"),
                    bindingConferencePortalKeyText("publicProfileSummary"),
                    bindingConferencePortalKeyText("chatSummary"),
                    bindingConferencePortalKeyText("nextAction"),
                    bindingConferencePortalKeyText("refreshSummary"),
                    .Grid(
                        SkeletonGrid(
                            columns: [.adaptive(min: 220, max: 320)],
                            spacing: 12,
                            elements: [
                                bindingConferencePortalStateSummaryCard(
                                    title: "Status nå",
                                    detailKeypath: "statusSummary",
                                    noteKeypath: "actionSummary",
                                    accentBorder: "#2F6B56",
                                    accentText: "#B9FBC0",
                                    height: 132
                                ),
                                bindingConferencePortalStateSummaryCard(
                                    title: "Valg nå",
                                    detailKeypath: "selectionSummary",
                                    noteKeypath: "navigationSummary",
                                    accentBorder: "#2A4D61",
                                    accentText: "#B9E6FF",
                                    height: 132
                                ),
                                bindingConferencePortalStateSummaryCard(
                                    title: "Neste steg",
                                    detailKeypath: "nextStepSummary",
                                    noteKeypath: "chatSummary",
                                    accentBorder: "#4D3F2A",
                                    accentText: "#F4D58D",
                                    height: 132
                                )
                            ]
                        )
                    ),
                    bindingConferencePortalCollectionGrid(
                        keypath: "candidates",
                        itemSkeleton: bindingConferencePortalActionConnectionCardSkeleton()
                    ),
                    bindingConferencePortalCollectionGrid(
                        keypath: "proofCandidates",
                        itemSkeleton: bindingConferencePortalActionConnectionCardSkeleton()
                    ),
                    bindingConferencePortalKeyText("focusedProfile.selectionBadge", fontSize: 12, fontWeight: "bold", foregroundColor: "#7FD6D0", lineLimit: 1),
                    bindingConferencePortalKeyText("focusedProfile.title", fontSize: 16, fontWeight: "bold", foregroundColor: "#F5FBFF", lineLimit: 2),
                    bindingConferencePortalKeyText("focusedProfile.subtitle", fontSize: 12, foregroundColor: "#8DE1DA", lineLimit: 2),
                    bindingConferencePortalKeyText("focusedProfile.detail", fontSize: 12, foregroundColor: "#D5E4ED", lineLimit: 3),
                    bindingConferencePortalKeyText("focusedProfile.note", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 3),
                    bindingConferencePortalCollectionGrid(
                        keypath: "focusedActions",
                        itemSkeleton: bindingConferencePortalActionConnectionCardSkeleton()
                    ),
                    bindingConferencePortalCollectionGrid(
                        keypath: "groupSuggestions",
                        itemSkeleton: bindingConferencePortalActionTimelineCardSkeleton()
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferenceDirectActionButton(
                                keypath: "\(referenceLabel).dispatchAction",
                                label: "Oppdater discovery",
                                payload: .object([
                                    "keypath": .string("refresh"),
                                    "payload": .bool(true)
                                ])
                            )
                        ])
                    )
                ]
            )
        ])
        return .Reference(snapshotReference)
    }

    nonisolated private static func bindingConferencePortalNearbyScannerSection(scannerReferenceLabel: String) -> SkeletonElement {
        return bindingConferencePortalCardSection(
            "Nearby Scanner Enrichment",
            content: [
            bindingConferencePortalStaticText(
                "HAVEN enriches conference discovery with a local nearby-radar snapshot over EntityScanner. This stays Apple-local and does not replace the portable discovery contract from web/staging.",
                fontSize: 12,
                foregroundColor: "#9AB3C3",
                lineLimit: 4
            ),
            bindingConferencePortalStaticText(
                "Nearby people appear below as et lite kompass: foran, venstre, fokus, høyre, bak og retning usikker. Første klikk skjer i denne siden: bruk Vis i siden for å fokusere på en person her. Åpne full radar og Åpne profilflate åpner egne arbeidsflater når du vil fordype deg.",
                fontSize: 12,
                foregroundColor: "#D7E7F2",
                lineLimit: 4
            ),
            bindingConferencePortalKeyText("\(scannerReferenceLabel).state.summary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 2),
            .Grid(
                SkeletonGrid(
                    columns: [.adaptive(min: 220, max: 320)],
                    spacing: 12,
                    elements: [
                        bindingConferencePortalStateSummaryCard(
                            title: "Scannerstatus",
                            detailKeypath: "\(scannerReferenceLabel).state.statusSummary",
                            noteKeypath: "\(scannerReferenceLabel).state.actionSummary",
                            accentBorder: "#2F6B56",
                            accentText: "#B9FBC0",
                            height: 132
                        ),
                        bindingConferencePortalStateSummaryCard(
                            title: "Valg nå",
                            detailKeypath: "\(scannerReferenceLabel).state.selectionSummary",
                            noteKeypath: "\(scannerReferenceLabel).state.navigationSummary",
                            accentBorder: "#2A4D61",
                            accentText: "#B9E6FF",
                            height: 132
                        ),
                        bindingConferencePortalStateSummaryCard(
                            title: "Neste steg",
                            detailKeypath: "\(scannerReferenceLabel).state.nextStepSummary",
                            noteKeypath: "\(scannerReferenceLabel).state.precisionSummary",
                            accentBorder: "#4D3F2A",
                            accentText: "#F4D58D",
                            height: 132
                        )
                    ]
                )
            ),
            bindingConferencePortalKeyText("\(scannerReferenceLabel).state.precisionSummary", fontSize: 12, foregroundColor: "#9AB3C3", lineLimit: 3),
            bindingConferencePortalKeyText("\(scannerReferenceLabel).state.actionSummary", fontSize: 12, foregroundColor: "#B9FBC0", lineLimit: 3),
            bindingConferencePortalCardSection(
                "Radar i siden",
                content: [
                    bindingConferencePortalStaticText(
                        "Dette er den innebygde radaren i deltagerportalen. Den skal gjøre det lett å oppdage nearby-deltagere uten at du mister resten av conference-siden.",
                        fontSize: 12,
                        foregroundColor: "#9AB3C3",
                        lineLimit: 4
                    ),
                    bindingConferencePortalKeyText("\(scannerReferenceLabel).state.spatialTruthSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                    bindingConferencePortalKeyText("\(scannerReferenceLabel).state.navigationSummary", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 3),
                    bindingConferencePortalStaticText(
                        "Åpne full radar når du vil bruke en større arbeidsflate til romlig oversikt og valg.",
                        fontSize: 12,
                        foregroundColor: "#B9FBC0",
                        lineLimit: 3
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferencePortalBadgeKeyText("\(scannerReferenceLabel).state.transportBadge"),
                            bindingConferencePortalBadgeKeyText("\(scannerReferenceLabel).state.precisionBadge")
                        ])
                    ),
                    bindingConferencePortalEmbeddedRadarLayout(baseKeypath: "\(scannerReferenceLabel).state.radarLayout")
                ]
            ),
            .HStack(
                SkeletonHStack(elements: [
                        bindingConferencePortalActionButton(
                            scannerReferenceLabel,
                            actionKeypath: "start",
                            label: "Start scanner"
                        ),
                        bindingConferencePortalActionButton(
                            scannerReferenceLabel,
                            actionKeypath: "stop",
                            label: "Stop scanner"
                        ),
                        bindingConferencePortalActionButton(
                            scannerReferenceLabel,
                            actionKeypath: "openExpandedRadarWorkbench",
                            label: "Åpne full radar"
                        ),
                    ])
                ),
                bindingConferencePortalKeyText("\(scannerReferenceLabel).state.selectionSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                bindingConferencePortalNearbyFocusPanelSection(scannerReferenceLabel: scannerReferenceLabel)
            ]
        )
    }

    nonisolated private static func bindingConferencePortalNetworkSection(referenceLabel: String) -> SkeletonElement {
        bindingConferencePortalCardSection(
            "Nettverks-Hub",
            content: [
                bindingConferencePortalKeyText("\(referenceLabel).state.sharedConnections.intro"),
                bindingConferencePortalKeyText("\(referenceLabel).state.sharedConnections.accessSummary"),
                bindingConferencePortalKeyText("\(referenceLabel).state.sharedConnections.agreementBoundary"),
                bindingConferencePortalKeyText("\(referenceLabel).state.sharedConnections.connectionSummary"),
                bindingConferencePortalKeyText("\(referenceLabel).state.sharedConnections.requestSummary"),
                bindingConferencePortalKeyText("\(referenceLabel).state.sharedConnections.meetingSummary"),
                bindingConferencePortalKeyText("\(referenceLabel).state.sharedConnections.chatSummary"),
                bindingConferencePortalCollectionGrid(
                    keypath: "\(referenceLabel).state.sharedConnections.connections",
                    itemSkeleton: bindingConferencePortalConnectionCardSkeleton()
                ),
                bindingConferencePortalCollectionGrid(
                    keypath: "\(referenceLabel).state.sharedConnections.confirmedMeetings",
                    itemSkeleton: bindingConferencePortalTimelineCardSkeleton()
                ),
                bindingConferencePortalCollectionGrid(
                    keypath: "\(referenceLabel).state.sharedConnections.recentMessages",
                    itemSkeleton: bindingConferencePortalMessageCardSkeleton()
                ),
                .HStack(
                    SkeletonHStack(elements: [
                        bindingConferencePortalActionButton(
                            referenceLabel,
                            actionKeypath: "connections.postSharedMessage",
                            label: "Send oppfølging",
                            payload: .object([
                                "text": .string("Takk for praten. Skal vi fortsette etter neste sesjon?"),
                                "contentType": .string("text/plain")
                            ])
                        ),
                        bindingConferencePortalActionButton(
                            referenceLabel,
                            actionKeypath: "scheduling.respondMeetingRequest",
                            label: "Vurder forespørsel"
                        )
                    ])
                )
            ]
        )
    }

    nonisolated private static func bindingConferencePortalRecommendationCardSkeleton() -> SkeletonElement {
        var section = SkeletonSection(content: [
            bindingConferencePortalKeyText("title", fontSize: 15, fontWeight: "bold", foregroundColor: "#F5FBFF", lineLimit: 2),
            bindingConferencePortalKeyText("subtitle", fontSize: 12, foregroundColor: "#8DE1DA", lineLimit: 1),
            bindingConferencePortalKeyText("detail", fontSize: 12, foregroundColor: "#D5E4ED", lineLimit: 2),
            bindingConferencePortalKeyText("note", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 1),
            bindingConferencePortalDynamicCardButton(defaultLabel: "Vis i siden")
        ])
        section.modifiers = modifier {
            $0.padding = 12
            $0.background = "#122734"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#244457"
            $0.height = 164
        }
        return .Section(section)
    }

    nonisolated private static func bindingConferencePortalRecommendationCards(referenceLabel: String) -> SkeletonElement {
        .Grid(
            SkeletonGrid(
                columns: [.adaptive(min: 200, max: 280)],
                spacing: 12,
                elements: [
                    bindingConferencePortalIndexedRecommendationCard(referenceLabel: referenceLabel, index: 0),
                    bindingConferencePortalIndexedRecommendationCard(referenceLabel: referenceLabel, index: 1),
                    bindingConferencePortalIndexedRecommendationCard(referenceLabel: referenceLabel, index: 2)
                ]
            )
        )
    }

    nonisolated private static func bindingConferencePortalIndexedRecommendationCard(referenceLabel: String, index: Int) -> SkeletonElement {
        let base = "\(referenceLabel).state.recommendations[\(index)]"
        var section = SkeletonSection(content: [
            bindingConferencePortalKeyText("\(base).title", fontSize: 15, fontWeight: "bold", foregroundColor: "#F5FBFF", lineLimit: 2),
            bindingConferencePortalKeyText("\(base).subtitle", fontSize: 12, foregroundColor: "#8DE1DA", lineLimit: 1),
            bindingConferencePortalKeyText("\(base).detail", fontSize: 12, foregroundColor: "#D5E4ED", lineLimit: 2),
            bindingConferencePortalKeyText("\(base).note", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 2),
            bindingConferencePortalActionButton(
                referenceLabel,
                actionKeypath: "matchmaking.focusRecommendationAtIndex",
                label: "Vis i siden",
                payload: .object([
                    "index": .integer(index)
                ])
            )
        ])
        section.modifiers = modifier {
            $0.padding = 12
            $0.background = "#122734"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#244457"
            $0.height = 172
        }
        return .Section(section)
    }

    nonisolated private static func bindingConferencePortalSessionCardSkeleton() -> SkeletonElement {
        var section = SkeletonSection(content: [
            bindingConferencePortalKeyText("title", fontSize: 15, fontWeight: "bold", foregroundColor: "#F5FBFF", lineLimit: 2),
            bindingConferencePortalKeyText("subtitle", fontSize: 12, foregroundColor: "#8DE1DA", lineLimit: 1),
            bindingConferencePortalKeyText("detail", fontSize: 12, foregroundColor: "#D5E4ED", lineLimit: 3),
            bindingConferencePortalKeyText("note", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 2),
            bindingConferencePortalDynamicCardButton(defaultLabel: "Oppdater agenda")
        ])
        section.modifiers = modifier {
            $0.padding = 12
            $0.background = "#122734"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#244457"
            $0.height = 188
        }
        return .Section(section)
    }

    nonisolated private static func bindingConferencePortalSessionMatrixCardSkeleton() -> SkeletonElement {
        var section = SkeletonSection(content: [
            bindingConferencePortalKeyText("selectionBadge", fontSize: 11, fontWeight: "bold", foregroundColor: "#7FD6D0", lineLimit: 1),
            bindingConferencePortalKeyText("subtitle", fontSize: 11, fontWeight: "semibold", foregroundColor: "#B9E6FF", lineLimit: 1),
            bindingConferencePortalKeyText("title", fontSize: 16, fontWeight: "bold", foregroundColor: "#F5FBFF", lineLimit: 2),
            bindingConferencePortalKeyText("detail", fontSize: 12, foregroundColor: "#D5E4ED", lineLimit: 3),
            bindingConferencePortalKeyText("note", fontSize: 11, foregroundColor: "#88A2B1", lineLimit: 2),
            bindingConferencePortalDynamicCardButton(defaultLabel: "Åpne sesjon")
        ])
        section.modifiers = modifier {
            $0.padding = 12
            $0.background = "#102432"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#2D566B"
            $0.height = 196
        }
        return .Section(section)
    }

    nonisolated private static func bindingConferencePortalTitleDetailCardSkeleton() -> SkeletonElement {
        var section = SkeletonSection(content: [
            bindingConferencePortalKeyText("title", fontSize: 15, fontWeight: "bold", foregroundColor: "#F5FBFF", lineLimit: 2),
            bindingConferencePortalKeyText("detail", fontSize: 12, foregroundColor: "#D5E4ED", lineLimit: 3)
        ])
        section.modifiers = modifier {
            $0.padding = 12
            $0.background = "#122734"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#244457"
            $0.height = 128
        }
        return .Section(section)
    }

    nonisolated private static func bindingConferencePortalTimelineCardSkeleton() -> SkeletonElement {
        var section = SkeletonSection(content: [
            bindingConferencePortalKeyText("title", fontSize: 15, fontWeight: "bold", foregroundColor: "#F5FBFF", lineLimit: 2),
            bindingConferencePortalKeyText("subtitle", fontSize: 12, foregroundColor: "#9AB3C3", lineLimit: 1),
            bindingConferencePortalKeyText("detail", fontSize: 12, foregroundColor: "#D5E4ED", lineLimit: 3),
            bindingConferencePortalKeyText("note", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 2)
        ])
        section.modifiers = modifier {
            $0.padding = 12
            $0.background = "#122734"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#244457"
            $0.height = 148
        }
        return .Section(section)
    }

    nonisolated private static func bindingConferencePortalConnectionCardSkeleton() -> SkeletonElement {
        var section = SkeletonSection(content: [
            bindingConferencePortalKeyText("title", fontSize: 15, fontWeight: "bold", foregroundColor: "#F5FBFF"),
            bindingConferencePortalKeyText("subtitle", fontSize: 12, foregroundColor: "#8DE1DA"),
            bindingConferencePortalKeyText("detail", fontSize: 12, foregroundColor: "#D5E4ED"),
            bindingConferencePortalKeyText("note", fontSize: 12, foregroundColor: "#88A2B1")
        ])
        section.modifiers = bindingConferencePortalInlineCardModifier()
        return .Section(section)
    }

    nonisolated private static func bindingConferencePortalActionTimelineCardSkeleton() -> SkeletonElement {
        var section = SkeletonSection(content: [
            bindingConferencePortalKeyText("title", fontSize: 15, fontWeight: "bold", foregroundColor: "#F5FBFF", lineLimit: 2),
            bindingConferencePortalKeyText("subtitle", fontSize: 12, foregroundColor: "#9AB3C3", lineLimit: 1),
            bindingConferencePortalKeyText("detail", fontSize: 12, foregroundColor: "#D5E4ED", lineLimit: 3),
            bindingConferencePortalKeyText("note", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 2),
            bindingConferencePortalDynamicCardButton(defaultLabel: "Åpne neste steg")
        ])
        section.modifiers = modifier {
            $0.padding = 12
            $0.background = "#122734"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#244457"
            $0.height = 188
        }
        return .Section(section)
    }

    nonisolated private static func bindingConferencePortalActionConnectionCardSkeleton() -> SkeletonElement {
        var section = SkeletonSection(content: [
            bindingConferencePortalKeyText("title", fontSize: 15, fontWeight: "bold", foregroundColor: "#F5FBFF"),
            bindingConferencePortalKeyText("subtitle", fontSize: 12, foregroundColor: "#8DE1DA"),
            bindingConferencePortalKeyText("detail", fontSize: 12, foregroundColor: "#D5E4ED"),
            bindingConferencePortalKeyText("note", fontSize: 12, foregroundColor: "#88A2B1"),
            bindingConferencePortalDynamicCardButton(defaultLabel: "Neste steg")
        ])
        section.modifiers = modifier {
            $0.padding = 12
            $0.background = "#122734"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#244457"
            $0.height = 188
        }
        return .Section(section)
    }

    nonisolated private static func bindingConferencePortalSelectionChipCardSkeleton() -> SkeletonElement {
        var section = SkeletonSection(content: [
            bindingConferencePortalKeyText("selectionBadge", fontSize: 11, fontWeight: "bold", foregroundColor: "#7FD6D0", lineLimit: 1),
            bindingConferencePortalKeyText("title", fontSize: 15, fontWeight: "bold", foregroundColor: "#F5FBFF", lineLimit: 1),
            bindingConferencePortalKeyText("subtitle", fontSize: 12, foregroundColor: "#8DE1DA", lineLimit: 2),
            bindingConferencePortalKeyText("detail", fontSize: 12, foregroundColor: "#D5E4ED", lineLimit: 2),
            bindingConferencePortalKeyText("note", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 2),
            bindingConferencePortalDynamicCardButton(defaultLabel: "Velg")
        ])
        section.modifiers = modifier {
            $0.padding = 12
            $0.background = "#122734"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#244457"
            $0.height = 204
        }
        return .Section(section)
    }

    nonisolated private static func bindingConferencePortalNearbyCardSkeleton() -> SkeletonElement {
        var section = SkeletonSection(content: [
            bindingConferencePortalKeyText("title", fontSize: 15, fontWeight: "bold", foregroundColor: "#F5FBFF", lineLimit: 2),
            bindingConferencePortalKeyText("subtitle", fontSize: 12, foregroundColor: "#8DE1DA", lineLimit: 1),
            bindingConferencePortalKeyText("distanceText", fontSize: 12, fontWeight: "bold", foregroundColor: "#D5E4ED", lineLimit: 1),
            bindingConferencePortalKeyText("directionConfidence", fontSize: 11, foregroundColor: "#88A2B1", lineLimit: 1),
            bindingConferencePortalKeyText("relevanceBadge", fontSize: 11, fontWeight: "bold", foregroundColor: "#B9FBC0", lineLimit: 1),
            bindingConferencePortalKeyText("relationBadge", fontSize: 11, fontWeight: "bold", foregroundColor: "#7FD6D0", lineLimit: 1),
            bindingConferencePortalKeyText("relevanceSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 2),
            bindingConferencePortalKeyText("publicPreviewSummary", fontSize: 12, foregroundColor: "#B9FBC0", lineLimit: 2),
            bindingConferencePortalKeyText("note", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 2),
            bindingConferencePortalDynamicCardButton(defaultLabel: "Vis i siden")
        ])
        section.modifiers = modifier {
            $0.padding = 12
            $0.background = "#122734"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#244457"
            $0.height = 260
        }
        return .Section(section)
    }

    nonisolated private static func bindingConferencePortalNearbyFocusPanelSection(scannerReferenceLabel: String) -> SkeletonElement {
        bindingConferencePortalCardSection(
            "Selected entity",
            content: [
                bindingConferencePortalStaticText(
                    "The selected entity is split into two zones: local scanner proximity/relevance, and openly published information. Proximity never implies access to private profile data.",
                    fontSize: 12,
                    foregroundColor: "#9AB3C3",
                    lineLimit: 4
                ),
                .Grid(
                    SkeletonGrid(
                        columns: [.adaptive(min: 220, max: 320)],
                        spacing: 12,
                        elements: [
                            bindingConferencePortalStateSummaryCard(
                                title: "Match nå",
                                detailKeypath: "\(scannerReferenceLabel).state.selectedEntity.relevanceBadge",
                                noteKeypath: "\(scannerReferenceLabel).state.selectedEntity.relevanceSummary",
                                accentBorder: "#2F6B56",
                                accentText: "#B9FBC0",
                                height: 132
                            ),
                            bindingConferencePortalStateSummaryCard(
                                title: "Purpose fit",
                                detailKeypath: "\(scannerReferenceLabel).state.selectedEntity.purposeSummary",
                                noteKeypath: "\(scannerReferenceLabel).state.selectedEntity.purposeDetail",
                                accentBorder: "#2A4D61",
                                accentText: "#B9E6FF",
                                height: 132
                            ),
                            bindingConferencePortalStateSummaryCard(
                                title: "Neste steg",
                                detailKeypath: "\(scannerReferenceLabel).state.selectedEntity.followUpSummary",
                                noteKeypath: "\(scannerReferenceLabel).state.selectedEntity.chatSummary",
                                accentBorder: "#4D3F2A",
                                accentText: "#F4D58D",
                                height: 132
                            )
                        ]
                    )
                ),
                bindingConferencePortalKeyText("\(scannerReferenceLabel).state.selectedEntity.selectionBadge", fontSize: 12, fontWeight: "bold", foregroundColor: "#7FD6D0", lineLimit: 1),
                bindingConferencePortalKeyText("\(scannerReferenceLabel).state.selectedEntity.title", fontSize: 18, fontWeight: "bold", foregroundColor: "#F5FBFF", lineLimit: 2),
                bindingConferencePortalKeyText("\(scannerReferenceLabel).state.selectedEntity.subtitle", fontSize: 12, foregroundColor: "#8DE1DA", lineLimit: 2),
                bindingConferencePortalKeyText("\(scannerReferenceLabel).state.selectedEntity.detail", fontSize: 12, foregroundColor: "#D5E4ED", lineLimit: 2),
                bindingConferencePortalStaticText("LOCAL PROXIMITY / RELEVANCE", fontSize: 11, foregroundColor: "#F4D58D", lineLimit: 1),
                bindingConferencePortalKeyText("\(scannerReferenceLabel).state.selectedEntity.proximitySummary", fontSize: 12, foregroundColor: "#D5E4ED", lineLimit: 3),
                bindingConferencePortalKeyText("\(scannerReferenceLabel).state.selectedEntity.directionConfidence", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 1),
                bindingConferencePortalKeyText("\(scannerReferenceLabel).state.selectedEntity.relationBadge", fontSize: 12, fontWeight: "bold", foregroundColor: "#7FD6D0", lineLimit: 1),
                bindingConferencePortalKeyText("\(scannerReferenceLabel).state.selectedEntity.identityPersistenceSummary", fontSize: 12, foregroundColor: "#B9FBC0", lineLimit: 2),
                bindingConferencePortalKeyText("\(scannerReferenceLabel).state.selectedEntity.chatAvailability", fontSize: 12, foregroundColor: "#F4D58D", lineLimit: 2),
                bindingConferencePortalStaticText("OPENLY PUBLISHED", fontSize: 11, foregroundColor: "#9AB3C3", lineLimit: 1),
                bindingConferencePortalKeyText("\(scannerReferenceLabel).state.selectedEntity.publicHeadline", fontSize: 12, foregroundColor: "#F5FBFF", lineLimit: 2),
                bindingConferencePortalKeyText("\(scannerReferenceLabel).state.selectedEntity.publicInterests", fontSize: 12, foregroundColor: "#D5E4ED", lineLimit: 3),
                bindingConferencePortalKeyText("\(scannerReferenceLabel).state.selectedEntity.publicLookingFor", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 2),
                bindingConferencePortalKeyText("\(scannerReferenceLabel).state.selectedEntity.publicOverlap", fontSize: 12, foregroundColor: "#B9FBC0", lineLimit: 3),
                bindingConferencePortalKeyText("\(scannerReferenceLabel).state.selectedEntity.note", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 3),
                .HStack(
                    SkeletonHStack(elements: [
                        bindingConferencePortalActionButton(
                            scannerReferenceLabel,
                            actionKeypath: "openSelectedParticipantWorkbench",
                            label: "Åpne profilflate"
                        ),
                        bindingConferencePortalActionButton(
                            scannerReferenceLabel,
                            actionKeypath: "openExpandedRadarWorkbench",
                            label: "Åpne full radar"
                        )
                    ])
                ),
                bindingConferencePortalCollectionGrid(
                    keypath: "\(scannerReferenceLabel).state.selectedEntityActions",
                    min: 220,
                    max: 280,
                    itemSkeleton: bindingConferencePortalActionConnectionCardSkeleton()
                )
            ]
        )
    }

    nonisolated private static func bindingConferencePortalDynamicCardButton(defaultLabel: String) -> SkeletonElement {
        var button = SkeletonButton(keypath: "dispatchAction", label: defaultLabel)
        button.modifiers = modifier {
            $0.padding = 8
            $0.background = "#173140"
            $0.cornerRadius = 8
            $0.borderWidth = 1
            $0.borderColor = "#2D566B"
            $0.foregroundColor = "#D9FBFF"
        }
        return .Button(button)
    }

    nonisolated private static func bindingConferencePortalMessageCardSkeleton() -> SkeletonElement {
        var section = SkeletonSection(content: [
            bindingConferencePortalKeyText("title", fontSize: 13, fontWeight: "bold", foregroundColor: "#B9FBC0"),
            bindingConferencePortalKeyText("subtitle", fontSize: 11, foregroundColor: "#8DE1DA"),
            bindingConferencePortalKeyText("detail", fontSize: 13, foregroundColor: "#F5FBFF", lineLimit: 10),
            bindingConferencePortalKeyText("note", fontSize: 11, foregroundColor: "#88A2B1", lineLimit: 3)
        ])
        section.modifiers = bindingConferencePortalInlineCardModifier()
        return .Section(section)
    }

    nonisolated private static func bindingConferencePortalTranscriptMessageRowSkeleton() -> SkeletonVStack {
        var avatar = SkeletonText(keypath: "senderInitials")
        avatar.modifiers = modifier {
            $0.padding = 8
            $0.width = 34
            $0.height = 34
            $0.background = "#173140"
            $0.cornerRadius = 17
            $0.borderWidth = 1
            $0.borderColor = "#2D566B"
            $0.foregroundColor = "#B9FBC0"
            $0.fontSize = 11
            $0.fontWeight = "bold"
            $0.multilineTextAlignment = "center"
        }

        var sender = SkeletonText(keypath: "title")
        sender.modifiers = modifier {
            $0.fontSize = 13
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#F5FBFF"
            $0.lineLimit = 1
        }

        var meta = SkeletonText(keypath: "subtitle")
        meta.modifiers = modifier {
            $0.fontSize = 11
            $0.foregroundColor = "#8DE1DA"
            $0.lineLimit = 2
        }

        var body = SkeletonText(keypath: "detail")
        body.modifiers = modifier {
            $0.fontSize = 13
            $0.foregroundColor = "#F5FBFF"
            $0.lineLimit = 12
            $0.multilineTextAlignment = "leading"
        }

        var note = SkeletonText(keypath: "note")
        note.modifiers = modifier {
            $0.fontSize = 11
            $0.foregroundColor = "#88A2B1"
            $0.lineLimit = 3
        }

        var bubble = SkeletonVStack(
            elements: [
                .Text(body),
                .Text(note)
            ],
            spacing: 6
        )
        bubble.modifiers = modifier {
            $0.padding = 10
            $0.background = "#173140"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = "#2D566B"
        }

        var messageColumn = SkeletonVStack(
            elements: [
                .Text(sender),
                .Text(meta),
                .VStack(bubble)
            ],
            spacing: 4
        )
        messageColumn.modifiers = modifier {
            $0.hAlignment = "leading"
        }

        var row = SkeletonVStack(
            elements: [
                .HStack(
                    SkeletonHStack(
                        elements: [
                            .Text(avatar),
                            .VStack(messageColumn)
                        ],
                        spacing: 10
                    )
                )
            ]
        )
        row.modifiers = modifier {
            $0.padding = 2
        }
        return row
    }

    nonisolated private static func bindingConferencePortalCompactActionRowSkeleton() -> SkeletonVStack {
        var title = SkeletonText(keypath: "title")
        title.modifiers = modifier {
            $0.fontSize = 14
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#F5FBFF"
            $0.lineLimit = 1
        }

        var subtitle = SkeletonText(keypath: "subtitle")
        subtitle.modifiers = modifier {
            $0.fontSize = 11
            $0.foregroundColor = "#8DE1DA"
            $0.lineLimit = 2
        }

        var detail = SkeletonText(keypath: "detail")
        detail.modifiers = modifier {
            $0.fontSize = 12
            $0.foregroundColor = "#D5E4ED"
            $0.lineLimit = 3
        }

        var note = SkeletonText(keypath: "note")
        note.modifiers = modifier {
            $0.fontSize = 11
            $0.foregroundColor = "#88A2B1"
            $0.lineLimit = 2
        }

        var rowButton = SkeletonButton(keypath: "dispatchAction", label: "Neste steg")
        rowButton.modifiers = modifier {
            $0.padding = 8
            $0.background = "#173140"
            $0.cornerRadius = 8
            $0.borderWidth = 1
            $0.borderColor = "#2D566B"
            $0.foregroundColor = "#D9FBFF"
        }

        var textColumn = SkeletonVStack(
            elements: [
                .Text(title),
                .Text(subtitle),
                .Text(detail),
                .Text(note)
            ],
            spacing: 4
        )
        textColumn.modifiers = modifier {
            $0.hAlignment = "leading"
        }

        var row = SkeletonVStack(
            elements: [
                .HStack(
                    SkeletonHStack(
                        elements: [
                            .VStack(textColumn),
                            .Spacer(SkeletonSpacer()),
                            .Button(rowButton)
                        ],
                        spacing: 10
                    )
                ),
                .Divider(SkeletonDivider())
            ],
            spacing: 8
        )
        row.modifiers = modifier {
            $0.padding = 2
        }
        return row
    }

    nonisolated private static func bindingConferencePortalTimelineRowSkeleton() -> SkeletonVStack {
        SkeletonVStack(elements: [
            bindingConferencePortalKeyText("title", fontSize: 15, fontWeight: "bold", foregroundColor: "#F5FBFF"),
            bindingConferencePortalKeyText("subtitle", fontSize: 12, foregroundColor: "#9AB3C3"),
            bindingConferencePortalKeyText("detail", fontSize: 12, foregroundColor: "#D5E4ED"),
            bindingConferencePortalKeyText("note", fontSize: 12, foregroundColor: "#88A2B1"),
            .Divider(SkeletonDivider())
        ])
    }

    nonisolated private static func bindingConferencePortalConnectionRowSkeleton() -> SkeletonVStack {
        SkeletonVStack(elements: [
            bindingConferencePortalKeyText("title", fontSize: 15, fontWeight: "bold", foregroundColor: "#F5FBFF"),
            bindingConferencePortalKeyText("subtitle", fontSize: 12, foregroundColor: "#8DE1DA"),
            bindingConferencePortalKeyText("detail", fontSize: 12, foregroundColor: "#D5E4ED"),
            bindingConferencePortalKeyText("note", fontSize: 12, foregroundColor: "#88A2B1"),
            .Divider(SkeletonDivider())
        ])
    }

    nonisolated private static func bindingConferencePortalMessageRowSkeleton() -> SkeletonVStack {
        SkeletonVStack(elements: [
            bindingConferencePortalKeyText("title", fontSize: 14, fontWeight: "semibold", foregroundColor: "#F5FBFF"),
            bindingConferencePortalKeyText("detail", fontSize: 12, foregroundColor: "#D5E4ED"),
            bindingConferencePortalKeyText("note", fontSize: 12, foregroundColor: "#88A2B1"),
            .Divider(SkeletonDivider())
        ])
    }

    nonisolated private static func conferenceAIAssistantWorkbenchConfiguration(
        conferenceEndpoint: String,
        aiEndpoint: String,
        displayName: String,
        summary: String
    ) -> CellConfiguration {
        let usesLocalPreview = conferenceEndpoint.caseInsensitiveCompare("cell:///ConferenceParticipantPreviewShell") == .orderedSame
        var configuration = CellConfiguration(name: displayName)
        configuration.description = summary
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: conferenceEndpoint,
            sourceCellName: usesLocalPreview
                ? "ConferenceParticipantPreviewShellLocalFallbackCell"
                : "ConferenceParticipantPreviewShellCell",
            purpose: "Conference copilot",
            purposeDescription: usesLocalPreview
                ? "Kombiner den lokale participant-previewen med lokal AI-gateway for briefing, prioritering, matchmaking og follow-up i HAVEN."
                : "Kombiner participant-shellens levende kontekst med embedded AIGateway for briefing, prioritering, matchmaking og follow-up.",
            interests: ["conference", "ai", "copilot", "participant", "matchmaking", "meetings", "prompting"],
            menuSlots: ["upperMid", "lowerMid"]
        )

        var conferenceReference = CellReference(endpoint: conferenceEndpoint, subscribeFeed: false, label: "conferenceParticipantShell")
        conferenceReference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(conferenceReference)

        var aiReference = CellReference(endpoint: aiEndpoint, label: "aiGateway")
        aiReference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(aiReference)

        let conferenceSystemPrompt = """
        You are a conference copilot. Use only the participant context visible in this workspace. Stay concrete, concise, and action-oriented. Prioritize the next sessions, the best people to meet, and the shortest path to meaningful follow-up.
        """

        var root = SkeletonVStack(elements: [
            bindingConferencePortalCardSection(
                "Conference Snapshot",
                content: [
                    bindingConferencePortalStaticText(
                        "Conference AI Assistant",
                        fontSize: 18,
                        fontWeight: "bold",
                        foregroundColor: "#F5FBFF"
                    ),
                    bindingConferencePortalStaticText(
                        "Participant preview-state og AIGateway i samme arbeidsflate. Presets setter nyttige draft-prompts uten aa forlate conference-konteksten.",
                        fontSize: 12,
                        foregroundColor: "#9AB3C3"
                    ),
                    bindingConferencePortalKeyText("conferenceParticipantShell.state.workspace.title"),
                    bindingConferencePortalKeyText("conferenceParticipantShell.state.workspace.subtitle"),
                    bindingConferencePortalBadgeKeyText("conferenceParticipantShell.state.workspace.participantBadge"),
                    bindingConferencePortalBadgeKeyText("conferenceParticipantShell.state.workspace.programBadge"),
                    bindingConferencePortalBadgeKeyText("conferenceParticipantShell.state.workspace.matchBadge"),
                    bindingConferencePortalBadgeKeyText("conferenceParticipantShell.state.workspace.meetingBadge"),
                    bindingConferencePortalKeyText("conferenceParticipantShell.state.workspace.nextStep"),
                    bindingConferencePortalKeyText("conferenceParticipantShell.state.workspace.previewNotice")
                ]
            ),
            bindingConferencePortalCardSection(
                "Prompt-Ready Context",
                content: [
                    bindingConferencePortalStaticText(
                        "Dette er de viktigste oppsummeringsfeltene fra participant-shellen akkurat naa. De skal vaere synlige side om side med agenten, slik at prompten kan finjusteres uten aa navigere bort.",
                        fontSize: 12,
                        foregroundColor: "#9AB3C3"
                    ),
                    bindingConferencePortalKeyText("conferenceParticipantShell.state.program.agendaSummary"),
                    bindingConferencePortalKeyText("conferenceParticipantShell.state.program.timelineSummary"),
                    bindingConferencePortalKeyText("conferenceParticipantShell.state.matches.recommendationSummary"),
                    bindingConferencePortalKeyText("conferenceParticipantShell.state.matches.filterSummary"),
                    bindingConferencePortalKeyText("conferenceParticipantShell.state.meetings.meetingSummary"),
                    bindingConferencePortalKeyText("conferenceParticipantShell.state.meetings.requestSummary"),
                    bindingConferencePortalKeyText("conferenceParticipantShell.state.sharedConnections.connectionSummary"),
                    bindingConferencePortalKeyText("conferenceParticipantShell.state.sharedConnections.chatSummary")
                ]
            ),
            bindingConferencePortalCardSection(
                "Copilot Setup",
                content: [
                    bindingConferencePortalStaticText(
                        "Conference-copiloten bruker participant-konteksten fra denne arbeidsflaten og leser setup direkte fra `ConferenceAIGatewayPreview`. Hvis preview-wrapperen eller gatewayen ikke er lesbar, skal setup-seksjonen under vise den konkrete kontrakt- eller tilgangsfeilen i stedet for at flaten later som invoke bare mangler input.",
                        fontSize: 12,
                        foregroundColor: "#9AB3C3"
                    ),
                    bindingConferencePortalKeyText("aiGateway.state.setup.statusLabel"),
                    bindingConferencePortalKeyText("aiGateway.state.setup.nextStep"),
                    bindingConferencePortalKeyText("aiGateway.state.setup.providerLabel"),
                    bindingConferencePortalKeyText("aiGateway.state.setup.credentialStatus"),
                    bindingConferencePortalKeyText("aiGateway.state.setup.storageHint"),
                    bindingConferencePortalKeyText("aiGateway.state.setup.activeCredentialSource"),
                    bindingConferencePortalKeyText("aiGateway.state.setup.lastMessage"),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferenceDirectActionButton(
                                keypath: "aiGateway.applyDraftProfile",
                                label: "Hosted API (API key)",
                                payload: .object([
                                    "providerID": .string("openai-compatible"),
                                    "model": .string("gpt-4.1-mini"),
                                    "requiresAPIKey": .bool(true),
                                    "cachePolicy": .string("useCache")
                                ])
                            ),
                            bindingConferenceDirectActionButton(
                                keypath: "aiGateway.applyDraftProfile",
                                label: "No-auth gateway",
                                payload: .object([
                                    "providerID": .string("openai-compatible"),
                                    "model": .string("gpt-4.1-mini"),
                                    "requiresAPIKey": .bool(false),
                                    "cachePolicy": .string("useCache")
                                ])
                            ),
                            bindingConferenceDirectActionButton(
                                keypath: "aiGateway.setDraftRequiresAPIKey",
                                label: "API key on",
                                payload: .bool(true)
                            ),
                            bindingConferenceDirectActionButton(
                                keypath: "aiGateway.setDraftRequiresAPIKey",
                                label: "API key off",
                                payload: .bool(false)
                            ),
                            bindingConferenceDirectActionButton(
                                keypath: "aiGateway.setDraftDeterministicMode",
                                label: "Deterministic on",
                                payload: .bool(true)
                            ),
                            bindingConferenceDirectActionButton(
                                keypath: "aiGateway.setDraftDeterministicMode",
                                label: "Deterministic off",
                                payload: .bool(false)
                            )
                        ])
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Conference Prompt Presets",
                content: [
                    bindingConferencePortalStaticText(
                        "Load copilot system prompt fyller bare det valgfrie systemprompt-feltet. Preset-knappene under fyller bare den store request-boksen som faktisk kreves for invoke.",
                        fontSize: 12,
                        foregroundColor: "#9AB3C3"
                    ),
                    bindingConferencePortalStaticText(
                        "System prompt preview",
                        fontSize: 11,
                        fontWeight: "semibold",
                        foregroundColor: "#8DE1DA"
                    ),
                    bindingConferencePortalKeyText(
                        "aiGateway.state.draft.systemPrompt",
                        fontSize: 12,
                        foregroundColor: "#D7E7F2",
                        lineLimit: 3
                    ),
                    bindingConferencePortalStaticText(
                        "Request preview",
                        fontSize: 11,
                        fontWeight: "semibold",
                        foregroundColor: "#8DE1DA"
                    ),
                    bindingConferencePortalKeyText(
                        "aiGateway.state.draft.prompt",
                        fontSize: 12,
                        foregroundColor: "#D7E7F2",
                        lineLimit: 3
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferenceDirectActionButton(
                                keypath: "aiGateway.setDraftSystemPrompt",
                                label: "Load copilot system prompt",
                                payload: .string(conferenceSystemPrompt)
                            ),
                            bindingConferenceDirectActionButton(
                                keypath: "aiGateway.setDraftPrompt",
                                label: "Fill request: Daily brief",
                                payload: .string("Use the visible conference summaries in this workspace and give me a crisp brief for the rest of today: what matters most, what I should prepare for, and which session or conversation is highest leverage next.")
                            ),
                            bindingConferenceDirectActionButton(
                                keypath: "aiGateway.setDraftPrompt",
                                label: "Fill request: Who should I meet?",
                                payload: .string("Based on the visible matchmaking, meeting, and shared-connection summaries, identify the three strongest people for me to meet next. Explain why each one matters and suggest a short opener for each conversation.")
                            )
                        ])
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferenceDirectActionButton(
                                keypath: "aiGateway.setDraftPrompt",
                                label: "Fill request: Follow-up plan",
                                payload: .string("Using the visible meeting and shared-connection summaries, draft a practical follow-up plan with owners, message drafts, and the next concrete step for each item.")
                            ),
                            bindingConferenceDirectActionButton(
                                keypath: "aiGateway.setDraftPrompt",
                                label: "Fill request: Session priorities",
                                payload: .string("Use the agenda and program summaries in this workspace to rank the next sessions or activities for me. Explain the tradeoffs, what to skip, and what questions I should be ready to ask.")
                            )
                        ])
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Prompt Draft",
                content: [
                    bindingConferencePortalStaticText(
                        "Feltene under speiler draft-oppsettet for AIGateway. Hvis gatewayen ikke er lesbar, skal setup-seksjonen over forklare hvorfor, i stedet for at denne delen later som invoke bare mangler input.",
                        fontSize: 12,
                        foregroundColor: "#9AB3C3"
                    ),
                    bindingConferencePortalStaticText(
                        "Provider ID",
                        fontSize: 11,
                        fontWeight: "semibold",
                        foregroundColor: "#8DE1DA"
                    ),
                    bindingConferencePortalTextField(
                        sourceKeypath: "aiGateway.state.draft.providerID",
                        targetKeypath: "aiGateway.setDraftProviderID",
                        placeholder: "Provider ID"
                    ),
                    bindingConferencePortalStaticText(
                        "Model",
                        fontSize: 11,
                        fontWeight: "semibold",
                        foregroundColor: "#8DE1DA"
                    ),
                    bindingConferencePortalTextField(
                        sourceKeypath: "aiGateway.state.draft.model",
                        targetKeypath: "aiGateway.setDraftModel",
                        placeholder: "Model"
                    ),
                    bindingConferencePortalStaticText(
                        "Base URL (optional)",
                        fontSize: 11,
                        fontWeight: "semibold",
                        foregroundColor: "#8DE1DA"
                    ),
                    bindingConferencePortalTextField(
                        sourceKeypath: "aiGateway.state.draft.baseURL",
                        targetKeypath: "aiGateway.setDraftBaseURL",
                        placeholder: "Optional base URL"
                    ),
                    bindingConferencePortalStaticText(
                        "API key alias",
                        fontSize: 11,
                        fontWeight: "semibold",
                        foregroundColor: "#8DE1DA"
                    ),
                    bindingConferencePortalTextField(
                        sourceKeypath: "aiGateway.state.draft.apiKeyAlias",
                        targetKeypath: "aiGateway.setDraftAPIKeyAlias",
                        placeholder: "API key alias"
                    ),
                    bindingConferencePortalStaticText(
                        "Session API key",
                        fontSize: 11,
                        fontWeight: "semibold",
                        foregroundColor: "#8DE1DA"
                    ),
                    bindingConferencePortalStaticText(
                        "Lim inn API key her. Load, Save API key og Invoke conference copilot vil alle kunne bruke den lokale key-bufferen uten at Enter maa treffe perfekt.",
                        fontSize: 12,
                        foregroundColor: "#D7E7F2"
                    ),
                    bindingConferencePortalTextArea(
                        sourceKeypath: nil,
                        targetKeypath: "aiGateway.setDraftAPIKeyEntry",
                        placeholder: "Paste API key here",
                        minLines: 1,
                        maxLines: 3
                    ),
                    bindingConferencePortalKeyText("aiGateway.state.setup.pendingEntryStatus"),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferenceDirectActionButton(keypath: "aiGateway.commitDraftAPIKeyEntry", label: "Load session key"),
                            bindingConferenceDirectActionButton(keypath: "aiGateway.persistDraftAPIKey", label: "Save API key"),
                            bindingConferenceDirectActionButton(keypath: "aiGateway.clearDraftAPIKey", label: "Clear session key")
                        ])
                    ),
                    bindingConferencePortalStaticText(
                        "Copilot system prompt (optional)",
                        fontSize: 11,
                        fontWeight: "semibold",
                        foregroundColor: "#8DE1DA"
                    ),
                    bindingConferencePortalTextArea(
                        sourceKeypath: "aiGateway.state.draft.systemPrompt",
                        targetKeypath: "aiGateway.setDraftSystemPrompt",
                        placeholder: "Optional system prompt. Load the preset above or write your own.",
                        minLines: 4,
                        maxLines: 10
                    ),
                    bindingConferencePortalStaticText(
                        "Copilot request (required)",
                        fontSize: 11,
                        fontWeight: "semibold",
                        foregroundColor: "#8DE1DA"
                    ),
                    bindingConferencePortalStaticText(
                        "Dette er feltet som maa inneholde den faktiske oppgaven. Hvis det er tomt, vil invoke feile med en draft prompt-melding.",
                        fontSize: 12,
                        foregroundColor: "#D7E7F2"
                    ),
                    bindingConferencePortalTextArea(
                        sourceKeypath: "aiGateway.state.draft.prompt",
                        targetKeypath: "aiGateway.setDraftPrompt",
                        placeholder: "Required: what should the conference copilot help with right now?",
                        minLines: 7,
                        maxLines: 18
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferenceDirectActionButton(keypath: "aiGateway.invokeDraft", label: "Invoke conference copilot")
                        ])
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Latest AI Result",
                content: [
                    bindingConferencePortalKeyText("aiGateway.state.lastInvocation.outputPreview"),
                    bindingConferencePortalKeyText("aiGateway.state.lastInvocation.providerID"),
                    bindingConferencePortalKeyText("aiGateway.state.lastInvocation.model"),
                    bindingConferencePortalKeyText("aiGateway.state.lastInvocation.cacheHit"),
                    bindingConferencePortalKeyText("aiGateway.state.lastInvocation.invokeTimeMs"),
                    bindingConferencePortalKeyText("aiGateway.state.lastInvocation.quotaStatus"),
                    bindingConferencePortalKeyText("aiGateway.state.lastInvocation.warningsText"),
                    bindingConferencePortalKeyText("aiGateway.state.lastInvocation.errorsText"),
                    bindingConferencePortalKeyText("aiGateway.state.lastError")
                ]
            )
        ])
        root.modifiers = modifier { $0.background = ConferenceSurfacePalette.canvas }

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.background = ConferenceSurfacePalette.canvas
        }

        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func conferenceAdminWorkbenchConfiguration(
        endpoint: String,
        displayName: String,
        summary: String
    ) -> CellConfiguration {
        let usesLocalPreview = endpoint.caseInsensitiveCompare("cell:///ConferenceAdminPreviewShell") == .orderedSame
        var configuration = CellConfiguration(name: displayName)
        configuration.description = summary
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: endpoint,
            sourceCellName: usesLocalPreview
                ? "ConferenceAdminPreviewShellLocalFallbackCell"
                : "ConferenceAdminPreviewShellCell",
            purpose: "Conference control tower",
            purposeDescription: usesLocalPreview
                ? "Organizer-focused local preview wrapper in HAVEN for operations, content publishing, insights and sponsor overview."
                : "Organizer-focused preview wrapper for operations, content publishing, insights and sponsor overview.",
            interests: ["conference", "admin", "control-tower", "insights", "sponsor", "operations", "preview"],
            menuSlots: ["upperMid", "lowerMid"]
        )

        var reference = CellReference(endpoint: endpoint, subscribeFeed: false, label: "conferenceAdminShell")
        reference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(reference)

        var root = SkeletonVStack(elements: [
            bindingConferencePortalCardSection(
                "Control Tower",
                content: [
                    bindingConferencePortalKeyText("conferenceAdminShell.state.workspace.title", fontSize: 18, fontWeight: "bold", foregroundColor: "#F5FBFF"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.workspace.subtitle"),
                    bindingConferencePortalBadgeKeyText("conferenceAdminShell.state.workspace.conferenceBadge"),
                    bindingConferencePortalBadgeKeyText("conferenceAdminShell.state.workspace.opsBadge"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.workspace.nextAction"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.workspace.previewNotice")
                ]
            ),
            bindingConferencePortalCardSection(
                "Same Conference Reality",
                content: [
                    bindingConferencePortalKeyText("conferenceAdminShell.state.followUpStory.headline"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.followUpStory.intro"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.followUpStory.sharedRelationSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.followUpStory.followUpSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.followUpStory.agreementSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.followUpStory.sponsorSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.followUpStory.boundaryNote"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.followUpStory.nextAction"),
                    bindingConferencePortalCollectionGrid(
                        keypath: "conferenceAdminShell.state.followUpStory.pulseCards",
                        itemSkeleton: bindingConferencePortalTimelineCardSkeleton()
                    ),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceAdminShell.state.followUpStory.evidenceRows",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Organizer Insight Story",
                content: [
                    bindingConferencePortalKeyText("conferenceAdminShell.state.insightStory.headline"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.insightStory.intro"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.insightStory.organizerValueSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.insightStory.participantValueContract"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.insightStory.boundaryNote"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.insightStory.nextAction"),
                    bindingConferencePortalCollectionGrid(
                        keypath: "conferenceAdminShell.state.insightStory.kpiCards",
                        itemSkeleton: bindingConferencePortalTitleDetailCardSkeleton()
                    ),
                    bindingConferencePortalCollectionGrid(
                        keypath: "conferenceAdminShell.state.insightStory.topicTrendCards",
                        itemSkeleton: bindingConferencePortalTitleDetailCardSkeleton()
                    ),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceAdminShell.state.insightStory.evidenceRows",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Ownership & Access",
                content: [
                    bindingConferencePortalKeyText("conferenceAdminShell.state.access.headline"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.access.ownerScope"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.access.readScope"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.access.writeScope"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.access.deliveryScope"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.access.storageScope"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.access.notes"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.access.agreementSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.access.coverageSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.access.selectionSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.access.recommendedConfigurationSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.access.surfaceSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.access.nextAction"),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceAdminShell.state.access.surfaceMatrix",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    ),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceAdminShell.state.access.liveAgreementRows",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferencePortalActionButton("conferenceAdminShell", actionKeypath: "accessRequests.createRequest", label: "Create request", responseMode: "ack"),
                            bindingConferencePortalActionButton("conferenceAdminShell", actionKeypath: "accessRequests.approveSelectedRequest", label: "Approve selected", responseMode: "ack"),
                            bindingConferencePortalActionButton("conferenceAdminShell", actionKeypath: "accessRequests.expireSelectedGrant", label: "Expire grant", responseMode: "ack")
                        ])
                    ),
                    bindingConferencePortalCollectionGrid(
                        keypath: "conferenceAdminShell.state.access.keypathMatrix",
                        itemSkeleton: bindingConferencePortalTimelineCardSkeleton()
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Published Content",
                content: [
                    bindingConferencePortalKeyText("conferenceAdminShell.state.content.intro"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.content.editorScope"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.content.lifecycleSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.content.status"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.content.publishedAtLabel"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.content.lastEditedAtLabel"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.content.lastEditedBy"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.content.lastEditSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.content.draftWarning"),
                    bindingConferencePortalStaticText("Landing title", fontSize: 11, fontWeight: "semibold", foregroundColor: "#8DE1DA"),
                    bindingConferencePortalTextField(
                        sourceKeypath: "conferenceAdminShell.state.content.draft.title",
                        targetKeypath: "conferenceAdminShell.contentPublishing.setDraftTitle",
                        placeholder: "Landing title"
                    ),
                    bindingConferencePortalStaticText("Landing subtitle", fontSize: 11, fontWeight: "semibold", foregroundColor: "#8DE1DA"),
                    bindingConferencePortalTextField(
                        sourceKeypath: "conferenceAdminShell.state.content.draft.subtitle",
                        targetKeypath: "conferenceAdminShell.contentPublishing.setDraftSubtitle",
                        placeholder: "Landing subtitle"
                    ),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.content.preview.programSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.content.preview.trackSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.content.preview.sessionSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.content.preview.facilitySummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.content.preview.peopleSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.content.preview.articleSummary"),
                    bindingConferencePortalCollectionGrid(
                        keypath: "conferenceAdminShell.state.content.draftTracks",
                        itemSkeleton: bindingConferencePortalTimelineCardSkeleton()
                    ),
                    bindingConferencePortalCollectionGrid(
                        keypath: "conferenceAdminShell.state.content.draftSessions",
                        itemSkeleton: bindingConferencePortalTimelineCardSkeleton()
                    ),
                    bindingConferencePortalCollectionGrid(
                        keypath: "conferenceAdminShell.state.content.draftFacilities",
                        itemSkeleton: bindingConferencePortalTimelineCardSkeleton()
                    ),
                    bindingConferencePortalCollectionGrid(
                        keypath: "conferenceAdminShell.state.content.draftPeople",
                        itemSkeleton: bindingConferencePortalTimelineCardSkeleton()
                    ),
                    bindingConferencePortalCollectionGrid(
                        keypath: "conferenceAdminShell.state.content.draftArticles",
                        itemSkeleton: bindingConferencePortalTimelineCardSkeleton()
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferencePortalActionButton(
                                "conferenceAdminShell",
                                actionKeypath: "contentPublishing.publishDraft",
                                label: "Publish content",
                                responseMode: "ack"
                            ),
                            bindingConferencePortalActionButton(
                                "conferenceAdminShell",
                                actionKeypath: "contentPublishing.discardDraft",
                                label: "Discard draft",
                                responseMode: "ack"
                            )
                        ])
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Audience Discovery",
                content: [
                    bindingConferencePortalKeyText("conferenceAdminShell.state.audienceDiscovery.headline"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.audienceDiscovery.intro"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.audienceDiscovery.status"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.audienceDiscovery.scenarioSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.audienceDiscovery.alignmentSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.audienceDiscovery.permissionSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.audienceDiscovery.selectedSegmentSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.audienceDiscovery.nextAction"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.audienceDiscovery.refreshSummary"),
                    bindingConferencePortalCollectionGrid(
                        keypath: "conferenceAdminShell.state.audienceDiscovery.segments",
                        itemSkeleton: bindingConferencePortalTitleDetailCardSkeleton()
                    ),
                    bindingConferencePortalCollectionGrid(
                        keypath: "conferenceAdminShell.state.audienceDiscovery.queryReadyEntities",
                        itemSkeleton: bindingConferencePortalTitleDetailCardSkeleton()
                    ),
                    bindingConferencePortalCollectionGrid(
                        keypath: "conferenceAdminShell.state.audienceDiscovery.accessNeededEntities",
                        itemSkeleton: bindingConferencePortalTitleDetailCardSkeleton()
                    ),
                    bindingConferencePortalCollectionGrid(
                        keypath: "conferenceAdminShell.state.audienceDiscovery.recommendedQuerySurfaces",
                        itemSkeleton: bindingConferencePortalTitleDetailCardSkeleton()
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferencePortalActionButton("conferenceAdminShell", actionKeypath: "audienceDiscovery.refreshDiscovery", label: "Refresh discovery", responseMode: "ack")
                        ])
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Access Requests",
                content: [
                    bindingConferencePortalKeyText("conferenceAdminShell.state.accessRequests.headline"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.accessRequests.intro"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.accessRequests.status"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.accessRequests.policySummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.accessRequests.requestSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.accessRequests.coverageSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.accessRequests.selectionSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.accessRequests.grantBoundary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.accessRequests.recommendedConfigurationSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.accessRequests.nextAction"),
                    bindingConferencePortalStaticText("Requested surface", fontSize: 11, fontWeight: "semibold", foregroundColor: "#8DE1DA"),
                    bindingConferencePortalTextField(
                        sourceKeypath: "conferenceAdminShell.state.accessRequests.editor.requestedSurface",
                        targetKeypath: "conferenceAdminShell.accessRequests.setRequestedSurface",
                        placeholder: "Requested surface"
                    ),
                    bindingConferencePortalStaticText("Request window hours", fontSize: 11, fontWeight: "semibold", foregroundColor: "#8DE1DA"),
                    bindingConferencePortalTextField(
                        sourceKeypath: "conferenceAdminShell.state.accessRequests.editor.requestedWindowHours",
                        targetKeypath: "conferenceAdminShell.accessRequests.setRequestedWindowHours",
                        placeholder: "Window hours"
                    ),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceAdminShell.state.accessRequests.pendingRequests",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    ),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceAdminShell.state.accessRequests.activeGrants",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    ),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceAdminShell.state.accessRequests.history",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferencePortalActionButton("conferenceAdminShell", actionKeypath: "accessRequests.createRequest", label: "Create request", responseMode: "ack"),
                            bindingConferencePortalActionButton("conferenceAdminShell", actionKeypath: "accessRequests.approveSelectedRequest", label: "Approve selected", responseMode: "ack"),
                            bindingConferencePortalActionButton("conferenceAdminShell", actionKeypath: "accessRequests.denySelectedRequest", label: "Deny selected", responseMode: "ack"),
                            bindingConferencePortalActionButton("conferenceAdminShell", actionKeypath: "accessRequests.expireSelectedGrant", label: "Expire grant", responseMode: "ack")
                        ])
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Session Threads",
                content: [
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sessionThread.headline"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sessionThread.intro"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sessionThread.sessionSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sessionThread.participationSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sessionThread.discoverySummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sessionThread.privacySummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sessionThread.lastActionSummary"),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceAdminShell.state.sessionThread.sessions",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    ),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceAdminShell.state.sessionThread.messages",
                            flowElementSkeleton: bindingConferencePortalTranscriptMessageRowSkeleton()
                        )
                    ),
                    bindingConferencePortalCollectionGrid(
                        keypath: "conferenceAdminShell.state.sessionThread.topicClusters",
                        itemSkeleton: bindingConferencePortalTitleDetailCardSkeleton()
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferencePortalActionButton("conferenceAdminShell", actionKeypath: "sessionThread.postMessage", label: "Post message", payload: .object(["text": .string("Organizer note from HAVEN control tower")]), responseMode: "ack")
                        ])
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Session Polling",
                content: [
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sessionPolling.headline"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sessionPolling.intro"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sessionPolling.sessionSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sessionPolling.privacySummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sessionPolling.questionSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sessionPolling.voteSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sessionPolling.revealSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sessionPolling.lastActionSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sessionPolling.nextAction"),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceAdminShell.state.sessionPolling.sessions",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    ),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceAdminShell.state.sessionPolling.options",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    ),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceAdminShell.state.sessionPolling.results",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferencePortalActionButton("conferenceAdminShell", actionKeypath: "sessionPolling.toggleRevealResults", label: "Toggle reveal", responseMode: "ack")
                        ])
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Simulation Studio",
                content: [
                    bindingConferencePortalKeyText("conferenceAdminShell.state.simulation.headline"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.simulation.intro"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.simulation.status"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.simulation.nextStep"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.simulation.scenario.scenarioSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.simulation.scenario.typeSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.simulation.scenario.scaleSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.simulation.scenario.sizeSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.simulation.scenario.compositionSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.simulation.clock.headline"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.simulation.clock.statusSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.simulation.clock.simulatedNowLabel"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.simulation.population.headline"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.simulation.population.summary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.simulation.playback.headline"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.simulation.playback.recordingSummary"),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferencePortalActionButton("conferenceAdminShell", actionKeypath: "simulation.start", label: "Start simulation", responseMode: "ack"),
                            bindingConferencePortalActionButton("conferenceAdminShell", actionKeypath: "simulation.pause", label: "Pause", responseMode: "ack"),
                            bindingConferencePortalActionButton("conferenceAdminShell", actionKeypath: "simulation.resume", label: "Resume", responseMode: "ack"),
                            bindingConferencePortalActionButton("conferenceAdminShell", actionKeypath: "simulation.reset", label: "Reset", responseMode: "ack")
                        ])
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Operations",
                content: [
                    bindingConferencePortalKeyText("conferenceAdminShell.state.operations.intro"),
                    bindingConferencePortalCollectionGrid(
                        keypath: "conferenceAdminShell.state.operations.runOfShow",
                        itemSkeleton: bindingConferencePortalTitleDetailCardSkeleton()
                    ),
                    bindingConferencePortalCollectionGrid(
                        keypath: "conferenceAdminShell.state.operations.alerts",
                        itemSkeleton: bindingConferencePortalTitleDetailCardSkeleton()
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "System Load & Storage",
                content: [
                    bindingConferencePortalKeyText("conferenceAdminShell.state.system.headline"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.system.intro"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.system.status"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.system.accessSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.system.resolverSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.system.storageSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.system.hostSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.system.loadSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.system.memorySummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.system.ioSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.system.topProcessSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.system.persistedCellSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.system.timestampSummary"),
                    bindingConferencePortalCollectionGrid(
                        keypath: "conferenceAdminShell.state.system.resolverHighlights",
                        itemSkeleton: bindingConferencePortalTitleDetailCardSkeleton()
                    ),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceAdminShell.state.system.topProcesses",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    ),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceAdminShell.state.system.persistedCells",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Organizer Insights",
                content: [
                    bindingConferencePortalKeyText("conferenceAdminShell.state.insights.intro"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.insights.dashboardSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.insights.consentSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.insights.aggregateBoundary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.insights.chartDirection"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.insights.status"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.insights.exportStatus"),
                    bindingConferencePortalCollectionGrid(
                        keypath: "conferenceAdminShell.state.insights.kpis",
                        itemSkeleton: bindingConferencePortalTitleDetailCardSkeleton()
                    ),
                    bindingConferencePortalCollectionGrid(
                        keypath: "conferenceAdminShell.state.insights.topicTrends",
                        itemSkeleton: bindingConferencePortalTitleDetailCardSkeleton()
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Sponsor / Exhibitor",
                content: [
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sponsor.intro"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sponsor.status"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sponsor.aggregateBoundary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sponsor.dashboardSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sponsor.engagementSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sponsor.candidateSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sponsor.capturedSummary"),
                    bindingConferencePortalKeyText("conferenceAdminShell.state.sponsor.handoffSummary"),
                    bindingConferencePortalCollectionGrid(
                        keypath: "conferenceAdminShell.state.sponsor.dashboardCards",
                        itemSkeleton: bindingConferencePortalTitleDetailCardSkeleton()
                    ),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceAdminShell.state.sponsor.dashboardRows",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    ),
                    bindingConferencePortalCollectionGrid(
                        keypath: "conferenceAdminShell.state.sponsor.interestHeatmap",
                        itemSkeleton: bindingConferencePortalTitleDetailCardSkeleton()
                    ),
                    bindingConferencePortalCollectionGrid(
                        keypath: "conferenceAdminShell.state.sponsor.leadCandidates",
                        itemSkeleton: bindingConferencePortalTimelineCardSkeleton()
                    ),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceAdminShell.state.sponsor.capturedLeads",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    ),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceAdminShell.state.sponsor.handoffs",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferencePortalActionButton("conferenceAdminShell", actionKeypath: "sponsorExhibitor.refreshDashboard", label: "Refresh dashboard", responseMode: "ack"),
                            bindingConferencePortalActionButton("conferenceAdminShell", actionKeypath: "sponsorExhibitor.captureLeadOptIn", label: "Capture lead", responseMode: "ack")
                        ])
                    )
                ]
            )
        ])
        root.modifiers = modifier { $0.background = ConferenceSurfacePalette.canvas }

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier { $0.background = ConferenceSurfacePalette.canvas }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func conferencePublicWorkbenchConfiguration(
        endpoint: String,
        displayName: String,
        summary: String
    ) -> CellConfiguration {
        let usesLocalFixture = endpoint.caseInsensitiveCompare("cell:///ConferencePublicShellFixture") == .orderedSame
        var configuration = CellConfiguration(name: displayName)
        configuration.description = summary
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: endpoint,
            sourceCellName: usesLocalFixture
                ? "ConferencePublicShellFixtureCell"
                : "ConferencePublicShellCell",
            purpose: "Conference public website",
            purposeDescription: usesLocalFixture
                ? "Public-facing shell for landing, tracks, program, articles, people and facilities, served from a deterministic local demo fixture in HAVEN."
                : "Public-facing shell for landing, tracks, program, articles, people and facilities.",
            interests: ["conference", "public", "landing", "tracks", "sessions", "articles"],
            menuSlots: ["upperMid", "lowerMid"]
        )

        var reference = CellReference(endpoint: endpoint, subscribeFeed: true, label: "conferencePublicShell")
        reference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(reference)

        var root = SkeletonVStack(elements: [
            bindingConferencePortalCardSection(
                "AI & Digital Independence",
                content: [
                    bindingConferencePortalKeyText("conferencePublicShell.state.workspace.title", fontSize: 18, fontWeight: "bold", foregroundColor: "#F5FBFF"),
                    bindingConferencePortalKeyText("conferencePublicShell.state.workspace.subtitle"),
                    bindingConferencePortalBadgeKeyText("conferencePublicShell.state.workspace.dateBadge"),
                    bindingConferencePortalBadgeKeyText("conferencePublicShell.state.workspace.venueBadge"),
                    bindingConferencePortalKeyText("conferencePublicShell.state.workspace.ctaTitle", fontSize: 16, fontWeight: "bold", foregroundColor: "#B9E6FF", lineLimit: 2),
                    bindingConferencePortalKeyText("conferencePublicShell.state.workspace.ctaDetail", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                    .Grid(
                        SkeletonGrid(
                            columns: [.adaptive(min: 220, max: 320)],
                            spacing: 12,
                            elements: [
                                bindingConferencePortalStateSummaryCard(
                                    title: "Public promise",
                                    detailKeypath: "conferencePublicShell.state.workspace.ctaTitle",
                                    noteKeypath: "conferencePublicShell.state.workspace.ctaDetail",
                                    accentBorder: "#2A4D61",
                                    accentText: "#B9E6FF",
                                    height: 136
                                ),
                                bindingConferencePortalStateSummaryCard(
                                    title: "When & where",
                                    detailKeypath: "conferencePublicShell.state.workspace.dateBadge",
                                    noteKeypath: "conferencePublicShell.state.workspace.venueBadge",
                                    accentBorder: "#4D3F2A",
                                    accentText: "#F4D58D",
                                    height: 136
                                ),
                                bindingConferencePortalStateSummaryCard(
                                    title: "Publishing scope",
                                    detailKeypath: "conferencePublicShell.state.access.headline",
                                    noteKeypath: "conferencePublicShell.state.access.notes",
                                    accentBorder: "#2F6B56",
                                    accentText: "#B9FBC0",
                                    height: 136
                                )
                            ]
                        )
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Publication & Access",
                content: [
                    bindingConferencePortalKeyText("conferencePublicShell.state.access.headline"),
                    bindingConferencePortalKeyText("conferencePublicShell.state.access.ownerScope"),
                    bindingConferencePortalKeyText("conferencePublicShell.state.access.readScope"),
                    bindingConferencePortalKeyText("conferencePublicShell.state.access.writeScope"),
                    bindingConferencePortalKeyText("conferencePublicShell.state.access.deliveryScope"),
                    bindingConferencePortalKeyText("conferencePublicShell.state.access.storageScope"),
                    bindingConferencePortalKeyText("conferencePublicShell.state.access.notes"),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferencePublicShell.state.access.keypathMatrix",
                            flowElementSkeleton: bindingConferencePublicAccessCardSkeleton()
                        )
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Tracks & Program Highlights",
                content: [
                    bindingConferencePortalKeyText("conferencePublicShell.state.tracksIntro"),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferencePublicShell.state.tracks",
                            flowElementSkeleton: bindingConferencePublicFeatureCardSkeleton()
                        )
                    ),
                    bindingConferencePortalKeyText("conferencePublicShell.state.sessionsIntro"),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferencePublicShell.state.sessions",
                            flowElementSkeleton: bindingConferencePublicFeatureCardSkeleton()
                        )
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "People, Articles & Facilities",
                content: [
                    bindingConferencePortalKeyText("conferencePublicShell.state.peopleIntro"),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferencePublicShell.state.people",
                            flowElementSkeleton: bindingConferencePublicFeatureCardSkeleton()
                        )
                    ),
                    bindingConferencePortalKeyText("conferencePublicShell.state.articlesIntro"),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferencePublicShell.state.articles",
                            flowElementSkeleton: bindingConferencePublicFeatureCardSkeleton()
                        )
                    ),
                    bindingConferencePortalKeyText("conferencePublicShell.state.facilitiesIntro"),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferencePublicShell.state.facilities",
                            flowElementSkeleton: bindingConferencePublicFeatureCardSkeleton()
                        )
                    )
                ]
            )
        ])
        root.modifiers = modifier {
            $0.padding = 12
            $0.background = ConferenceSurfacePalette.canvas
        }

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier { $0.background = ConferenceSurfacePalette.canvas }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func conferenceSponsorWorkbenchConfiguration(
        endpoint: String,
        displayName: String,
        summary: String
    ) -> CellConfiguration {
        let usesLocalFixture = endpoint.caseInsensitiveCompare("cell:///ConferenceSponsorShellFixture") == .orderedSame
        var configuration = CellConfiguration(name: displayName)
        configuration.description = summary
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: endpoint,
            sourceCellName: usesLocalFixture
                ? "ConferenceSponsorShellFixtureCell"
                : "ConferenceSponsorShellCell",
            purpose: "Conference sponsor follow-up",
            purposeDescription: usesLocalFixture
                ? "Sponsor-owned shell for lead inbox, consent, unlock and retention flow, served from a deterministic local demo fixture in HAVEN."
                : "Sponsor-owned shell for lead inbox, consent, unlock and retention flow.",
            interests: ["conference", "sponsor", "lead-vault", "consent", "handoff", "retention"],
            menuSlots: ["upperMid", "lowerMid"]
        )

        var reference = CellReference(endpoint: endpoint, subscribeFeed: false, label: "conferenceSponsorShell")
        reference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(reference)

        var root = SkeletonVStack(elements: [
            bindingConferencePortalCardSection(
                "Sponsor Follow-up",
                content: [
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.workspace.title", fontSize: 18, fontWeight: "bold", foregroundColor: "#F5FBFF"),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.workspace.subtitle"),
                    bindingConferencePortalBadgeKeyText("conferenceSponsorShell.state.workspace.conferenceBadge"),
                    bindingConferencePortalBadgeKeyText("conferenceSponsorShell.state.workspace.sponsorBadge"),
                    bindingConferencePortalBadgeKeyText("conferenceSponsorShell.state.workspace.pipelineBadge"),
                    bindingConferencePortalBadgeKeyText("conferenceSponsorShell.state.workspace.retentionBadge"),
                    bindingConferencePortalBadgeKeyText("conferenceSponsorShell.state.workspace.creditBadge"),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.workspace.nextStep"),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.workspace.previewNotice")
                ]
            ),
            bindingConferencePortalCardSection(
                "Ownership & Access",
                content: [
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.access.headline"),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.access.ownerScope"),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.access.readScope"),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.access.writeScope"),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.access.deliveryScope"),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.access.storageScope"),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.access.notes"),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceSponsorShell.state.access.keypathMatrix",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Lead Inbox",
                content: [
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.followUp.intro"),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.followUp.pickupSummary"),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.followUp.qualificationSummary"),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.followUp.status"),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceSponsorShell.state.followUp.pickupLeads",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    ),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceSponsorShell.state.followUp.qualifiedLeads",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferencePortalActionButton("conferenceSponsorShell", actionKeypath: "sponsorInbox.refreshState", label: "Refresh inbox"),
                            bindingConferencePortalActionButton("conferenceSponsorShell", actionKeypath: "sponsorInbox.exportPack", label: "Prepare export")
                        ])
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Consent, Unlock & Retention",
                content: [
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.compliance.intro"),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.compliance.consentSummary"),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.compliance.agreementSummary"),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.compliance.chronicleSummary"),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.compliance.status"),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceSponsorShell.state.compliance.consentReceipts",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    ),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.retention.creditSummary"),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.retention.unlockSummary"),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.retention.reclaimSummary"),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.retention.reviewSummary"),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.retention.policySummary"),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.retention.slaSummary"),
                    bindingConferencePortalKeyText("conferenceSponsorShell.state.retention.exportStatus"),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceSponsorShell.state.retention.reviewQueue",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    ),
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "conferenceSponsorShell.state.retention.unlockedLeads",
                            flowElementSkeleton: bindingConferencePortalTimelineRowSkeleton()
                        )
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferencePortalActionButton("conferenceSponsorShell", actionKeypath: "sponsorInbox.runRetentionSweep", label: "Run retention sweep")
                        ])
                    )
                ]
            )
        ])
        root.modifiers = modifier { $0.background = ConferenceSurfacePalette.canvas }

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier { $0.background = ConferenceSurfacePalette.canvas }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func agentSetupWorkbenchConfiguration(
        displayName: String,
        summary: String
    ) -> CellConfiguration {
        var configuration = CellConfiguration(name: displayName)
        configuration.description = summary
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: "cell:///AgentProvisioning",
            sourceCellName: "AgentProvisioningCell",
            purpose: "Local HAVEN agent install and review boundary",
            purposeDescription: "Install, start, connect and review `haven-agentd` from HAVEN without bypassing CellProtocol review boundaries.",
            interests: ["agent", "haven-agentd", "automation", "review", "cellprotocol", "launchd"],
            menuSlots: ["upperMid", "lowerRight"]
        )

        var reference = CellReference(endpoint: "cell:///AgentProvisioning", subscribeFeed: true, label: "agentSetup")
        reference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(reference)

        var root = SkeletonVStack(elements: [
            bindingConferencePortalCardSection(
                "HAVEN Agent",
                content: [
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.status.installStage", fontSize: 18, fontWeight: "bold", foregroundColor: "#F5FBFF"),
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.status.runtimeStage"),
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.status.connectStage"),
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.status.controlBridgeState"),
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.status.portholePhase"),
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.status.connectedContractID"),
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.status.lastHeartbeatAt"),
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.status.lastEventSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.status.lastError", fontSize: 12, foregroundColor: "#F4D58D", lineLimit: 3)
                ]
            ),
            bindingConferencePortalCardSection(
                "Purpose & Policy",
                content: [
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.purpose.name", fontSize: 16, fontWeight: "bold", foregroundColor: "#B9E6FF"),
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.purpose.goal", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.purpose.source"),
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.purpose.interests", fontSize: 12, foregroundColor: "#8DE1DA", lineLimit: 3),
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.status.domain"),
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.status.discoveryURL"),
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.status.portholeStrategy", fontSize: 11, foregroundColor: "#88A2B1", lineLimit: 4)
                ]
            ),
            bindingConferencePortalCardSection(
                "Pipeline",
                content: [
                    bindingConferencePortalCollectionGrid(
                        keypath: "agentSetup.state.agent.setup.pipeline",
                        itemSkeleton: bindingConferencePortalTitleDetailCardSkeleton()
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Install & Connect",
                content: [
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.environment.sourceRoot", fontSize: 11, foregroundColor: "#88A2B1", lineLimit: 2),
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.environment.sproutBinaryPath", fontSize: 11, foregroundColor: "#88A2B1", lineLimit: 2),
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.environment.configPath", fontSize: 11, foregroundColor: "#88A2B1", lineLimit: 2),
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.environment.installBinaryPath", fontSize: 11, foregroundColor: "#88A2B1", lineLimit: 2),
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.environment.launchAgentPlistPath", fontSize: 11, foregroundColor: "#88A2B1", lineLimit: 2),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferenceDirectActionButton(keypath: "agentSetup.agent.setup.install", label: "Install agent"),
                            bindingConferenceDirectActionButton(keypath: "agentSetup.agent.setup.start", label: "Start agent"),
                            bindingConferenceDirectActionButton(keypath: "agentSetup.agent.setup.connect", label: "Run once")
                        ])
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferenceDirectActionButton(keypath: "agentSetup.agent.setup.stop", label: "Stop agent")
                        ])
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Review Boundary",
                content: [
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.review.queueState"),
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.review.selectedSummary", fontSize: 12, foregroundColor: "#D7E7F2", lineLimit: 3),
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.review.auditState", fontSize: 12, foregroundColor: "#88A2B1", lineLimit: 3),
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.review.lastOutcome"),
                    bindingConferencePortalKeyText("agentSetup.state.agent.setup.review.lastRecordedAt"),
                    .HStack(
                        SkeletonHStack(elements: [
                            bindingConferenceDirectActionButton(keypath: "agentSetup.agent.setup.review.queueSafariTest", label: "Queue Safari review"),
                            bindingConferenceDirectActionButton(keypath: "agentSetup.agent.setup.review.approveSelected", label: "Approve selected"),
                            bindingConferenceDirectActionButton(keypath: "agentSetup.agent.setup.review.rejectSelected", label: "Reject selected")
                        ])
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Recent Activity",
                content: [
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "agentSetup.state.agent.setup.activity",
                            flowElementSkeleton: bindingConferencePortalTitleDetailRowSkeleton()
                        )
                    )
                ]
            )
        ])
        root.modifiers = modifier {
            $0.padding = 12
            $0.background = ConferenceSurfacePalette.canvas
        }

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier { $0.background = ConferenceSurfacePalette.canvas }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func networkSentinelWorkbenchConfiguration(
        displayName: String,
        summary: String
    ) -> CellConfiguration {
        let endpoint = "cell:///agent/network/sentinel"
        var configuration = CellConfiguration(name: displayName)
        configuration.description = summary
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: endpoint,
            sourceCellName: "NetworkSentinelCell",
            purpose: "Local network health sentinel",
            purposeDescription: "Operate haven-agentd's local network tracker over the loopback control bridge.",
            interests: ["agent", "haven-agentd", "network", "diagnostics", "security", "local"],
            menuSlots: ["upperMid"]
        )

        var reference = CellReference(endpoint: endpoint, subscribeFeed: true, label: "networkSentinel")
        reference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(reference)

        var probeTargetField = SkeletonTextField(
            sourceKeypath: "networkSentinel.state.probe.target",
            targetKeypath: "probeTarget",
            placeholder: "vert:port (f.eks. 1.1.1.1:443)"
        )
        probeTargetField.modifiers = modifier {
            $0.padding = 8
            $0.background = "#0C1A22"
            $0.cornerRadius = 6
            $0.borderWidth = 1
            $0.borderColor = "#244457"
            $0.foregroundColor = "#F5FBFF"
        }

        var notificationsToggle = SkeletonToggle(label: "Vis nettverksvarsler", keypath: "notificationsEnabled", isOn: true)
        notificationsToggle.modifiers = modifier { $0.foregroundColor = "#F5FBFF" }

        var root = SkeletonVStack(elements: [
            bindingConferencePortalCardSection(
                "Nettverkssensor",
                content: [
                    bindingConferencePortalKeyText("networkSentinel.state.statusText", fontSize: 20, fontWeight: "bold", foregroundColor: "#F5FBFF"),
                    bindingConferencePortalKeyText("networkSentinel.state.metrics.summary", fontSize: 13, foregroundColor: "#D5E4ED", lineLimit: 2),
                    bindingConferencePortalKeyText("networkSentinel.state.activeEventText", fontSize: 12, foregroundColor: "#F4D58D", lineLimit: 3),
                    bindingConferencePortalKeyText("networkSentinel.state.goal.statusText", fontSize: 12, foregroundColor: "#8DE1DA"),
                    networkSentinelMetricRow("Grensesnitt:", "networkSentinel.state.interface", "Oppdatert:", "networkSentinel.state.updatedAt")
                ]
            ),
            bindingConferencePortalCardSection(
                "Trend",
                content: [
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "networkSentinel.state.history",
                            flowElementSkeleton: bindingConferencePortalTitleDetailRowSkeleton()
                        )
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Grensesnitt",
                content: [
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "networkSentinel.state.interfaces",
                            flowElementSkeleton: bindingConferencePortalTitleDetailRowSkeleton()
                        )
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Hendelser",
                content: [
                    .List(
                        SkeletonList(
                            topic: nil,
                            keypath: "networkSentinel.state.events",
                            flowElementSkeleton: bindingConferencePortalTitleDetailRowSkeleton()
                        )
                    ),
                    .HStack(
                        SkeletonHStack(elements: [
                            networkSentinelActionButton(keypath: "acknowledge", label: "Kvitter ut aktiv hendelse")
                        ], spacing: 8)
                    )
                ]
            ),
            bindingConferencePortalCardSection(
                "Verktøy",
                content: [
                    bindingConferencePortalStaticText("Tilkoblingstest", fontSize: 13, fontWeight: "semibold", foregroundColor: "#8DE1DA"),
                    .TextField(probeTargetField),
                    .HStack(
                        SkeletonHStack(elements: [
                            networkSentinelActionButton(keypath: "probe", label: "Test tilkobling")
                        ], spacing: 8)
                    ),
                    bindingConferencePortalKeyText("networkSentinel.state.probe.result", fontSize: 12, foregroundColor: "#8DE1DA", lineLimit: 3),
                    bindingConferencePortalStaticText("Pakkefangst og lyttemåling", fontSize: 13, fontWeight: "semibold", foregroundColor: "#8DE1DA"),
                    .HStack(
                        SkeletonHStack(elements: [
                            networkSentinelActionButton(keypath: "captureNow", label: "Capture nå"),
                            networkSentinelActionButton(keypath: "runListen", label: "Lytt 1 min", payload: .integer(1))
                        ], spacing: 8)
                    ),
                    bindingConferencePortalKeyText("networkSentinel.state.capture.summary", fontSize: 12, foregroundColor: "#8FB6C8", lineLimit: 3),
                    networkSentinelMetricRow("Lytt:", "networkSentinel.state.listen.status", "Varighet sek:", "networkSentinel.state.listen.durationSeconds"),
                    networkSentinelMetricRow("Snitt pk/s:", "networkSentinel.state.listen.averagePacketsPerSecond", "Topp pk/s:", "networkSentinel.state.listen.peakPacketsPerSecond"),
                    networkSentinelMetricRow("Snitt Mbps:", "networkSentinel.state.listen.averageMegabitsPerSecond", "Topp Mbps:", "networkSentinel.state.listen.peakMegabitsPerSecond"),
                    networkSentinelMetricRow("Hendelser:", "networkSentinel.state.listen.floodEventCount", "Samples:", "networkSentinel.state.listen.totalSamples")
                ]
            ),
            bindingConferencePortalCardSection(
                "Innstillinger",
                content: [
                    .Toggle(notificationsToggle),
                    bindingConferencePortalStaticText("Av/på gjelder brukervarsel. Hendelser logges uansett.", fontSize: 11, foregroundColor: "#88A2B1", lineLimit: 3),
                    networkSentinelMetricRow("Pakker/s:", "networkSentinel.state.thresholds.packetsPerSecond", "Mbps:", "networkSentinel.state.thresholds.megabitsPerSecond"),
                    networkSentinelMetricRow("Feil/s:", "networkSentinel.state.thresholds.errorsPerSecond", "Resolve:", "networkSentinel.state.thresholds.resolveSamples")
                ]
            )
        ])
        root.modifiers = modifier {
            $0.padding = 12
            $0.background = ConferenceSurfacePalette.canvas
        }

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier { $0.background = ConferenceSurfacePalette.canvas }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func networkSentinelMetricRow(
        _ firstLabel: String,
        _ firstKeypath: String,
        _ secondLabel: String,
        _ secondKeypath: String
    ) -> SkeletonElement {
        .HStack(
            SkeletonHStack(elements: [
                bindingConferencePortalStaticText(firstLabel, fontSize: 12, foregroundColor: "#D5E4ED"),
                bindingConferencePortalKeyText(firstKeypath, fontSize: 12, fontWeight: "semibold", foregroundColor: "#F5FBFF", lineLimit: 1),
                bindingConferencePortalStaticText(secondLabel, fontSize: 12, foregroundColor: "#D5E4ED"),
                bindingConferencePortalKeyText(secondKeypath, fontSize: 12, fontWeight: "semibold", foregroundColor: "#F5FBFF", lineLimit: 1)
            ], spacing: 8)
        )
    }

    nonisolated private static func networkSentinelActionButton(
        keypath: String,
        label: String,
        payload: ValueType? = .bool(true)
    ) -> SkeletonElement {
        var button = SkeletonButton(
            keypath: keypath,
            label: label,
            url: "cell:///agent/network/sentinel",
            payload: payload
        )
        button.modifiers = modifier {
            $0.padding = 8
            $0.background = "#173140"
            $0.cornerRadius = 8
            $0.borderWidth = 1
            $0.borderColor = "#2D566B"
            $0.foregroundColor = "#D9FBFF"
        }
        return .Button(button)
    }

    nonisolated private static func entityScannerToolConfiguration(
        name: String,
        description: String,
        title: String,
        subtitle: String,
        checklist: [String],
        includePerspectiveSection: Bool
    ) -> CellConfiguration {
        var configuration = CellConfiguration(name: name)
        configuration.description = description

        var scannerReference = CellReference(endpoint: "cell:///EntityScanner", label: "scanner")
        scannerReference.addKeyAndValue(KeyValue(key: "start"))
        configuration.addReference(scannerReference)
        var nearbyRadarReference = CellReference(endpoint: "cell:///ConferenceNearbyRadar", label: "nearbyRadar")
        nearbyRadarReference.addKeyAndValue(KeyValue(key: "start"))
        configuration.addReference(nearbyRadarReference)
        configuration.addReference(CellReference(endpoint: "cell:///Perspective", label: "perspective"))
        configuration.addReference(CellReference(endpoint: "cell:///EntityAnchor", label: "entity"))
        configuration.addReference(CellReference(endpoint: "cell://staging.haven.digipomps.org/PublicProfileDirectory", label: "publicProfiles"))
        configuration.addReference(CellReference(endpoint: "cell://staging.haven.digipomps.org/PersonalChatHub", label: "chatHub"))
        configuration.addReference(CellReference(endpoint: "cell:///Vault", label: "vault"))

        let card = conferenceCardModifier(
            padding: 10,
            background: ConferenceSurfacePalette.shellMuted,
            borderColor: ConferenceSurfacePalette.stroke,
            cornerRadius: 18
        )

        let heroCard = conferenceCardModifier(
            padding: 14,
            background: ConferenceSurfacePalette.shellStrong,
            borderColor: ConferenceSurfacePalette.strokeStrong,
            cornerRadius: 22,
            shadowRadius: 12,
            shadowY: 4
        )

        let sectionCard = conferenceCardModifier(
            padding: 8,
            background: ConferenceSurfacePalette.shell,
            borderColor: ConferenceSurfacePalette.stroke,
            cornerRadius: 14
        )

        let stepsSectionCard = conferenceCardModifier(
            padding: 10,
            background: ConferenceSurfacePalette.accentWarmSoft,
            borderColor: ConferenceSurfacePalette.strokeStrong,
            cornerRadius: 16
        )

        let perspectiveSectionCard = conferenceCardModifier(
            padding: 10,
            background: ConferenceSurfacePalette.accentCoolSoft,
            borderColor: ConferenceSurfacePalette.accentCoolBorder,
            cornerRadius: 16
        )

        let liveSectionCard = conferenceCardModifier(
            padding: 10,
            background: ConferenceSurfacePalette.shellStrong,
            borderColor: ConferenceSurfacePalette.accentCoolBorder,
            cornerRadius: 16
        )

        let diagnosticsSectionCard = conferenceCardModifier(
            padding: 10,
            background: ConferenceSurfacePalette.cautionSoft,
            borderColor: ConferenceSurfacePalette.strokeStrong,
            cornerRadius: 16
        )

        let storageSectionCard = conferenceCardModifier(
            padding: 10,
            background: ConferenceSurfacePalette.shell,
            borderColor: ConferenceSurfacePalette.stroke,
            cornerRadius: 16
        )

        let listCard = modifier {
            $0.padding = 6
            $0.background = ConferenceSurfacePalette.shell
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = ConferenceSurfacePalette.stroke
            $0.height = 220
        }

        let badgeModifier = conferenceChipModifier(
            background: ConferenceSurfacePalette.accentCoolSoft,
            borderColor: ConferenceSurfacePalette.accentCoolBorder,
            foregroundColor: ConferenceSurfacePalette.textMain
        )

        let primaryButton = conferenceButtonModifier(
            background: ConferenceSurfacePalette.accentCoolSoft,
            borderColor: ConferenceSurfacePalette.accentCoolBorder,
            foregroundColor: ConferenceSurfacePalette.textMain
        )

        let neutralButton = conferenceButtonModifier(
            background: ConferenceSurfacePalette.shellMuted,
            borderColor: ConferenceSurfacePalette.stroke,
            foregroundColor: ConferenceSurfacePalette.textMain
        )

        let warningButton = conferenceButtonModifier(
            background: ConferenceSurfacePalette.accentWarmSoft,
            borderColor: ConferenceSurfacePalette.strokeStrong,
            foregroundColor: ConferenceSurfacePalette.textMain
        )

        var titleText = SkeletonText(text: title)
        titleText.modifiers = modifier {
            $0.fontStyle = "title2"
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.textMain
        }

        var subtitleText = SkeletonText(text: subtitle)
        subtitleText.modifiers = modifier {
            $0.foregroundColor = ConferenceSurfacePalette.textMuted
            $0.fontSize = 13
            $0.lineLimit = 3
        }

        var localRuntimeText = SkeletonText(text: "Runs locally in HAVEN. This surface stays off CellScaffold because EntityScanner depends on Apple device frameworks such as MultipeerConnectivity.")
        localRuntimeText.modifiers = modifier {
            $0.foregroundColor = ConferenceSurfacePalette.accentWarm
            $0.fontSize = 12
            $0.lineLimit = 3
        }

        var privacyNoteText = SkeletonText(text: "Private keys stay on device. UWB is optional; MultipeerConnectivity remains the base transport.")
        privacyNoteText.modifiers = modifier {
            $0.foregroundColor = ConferenceSurfacePalette.accentCool
            $0.fontSize = 12
            $0.lineLimit = 3
        }

        var heroChip = SkeletonText(text: "BINDING LOCAL")
        heroChip.modifiers = conferenceChipModifier(
            background: ConferenceSurfacePalette.accentWarm,
            borderColor: ConferenceSurfacePalette.strokeStrong,
            foregroundColor: ConferenceSurfacePalette.shell
        )

        var badgeMPC = SkeletonText(text: "MPC base")
        badgeMPC.modifiers = badgeModifier
        var badgeSigned = SkeletonText(text: "Signed proofs")
        badgeSigned.modifiers = badgeModifier
        var badgeJSON = SkeletonText(text: "JSON export")
        badgeJSON.modifiers = badgeModifier
        var badgeUWB = SkeletonText(text: "UWB optional")
        badgeUWB.modifiers = badgeModifier

        var startButton = SkeletonButton(keypath: "scanner.start", label: "Start scanner", payload: .bool(true))
        startButton.modifiers = primaryButton

        var stopButton = SkeletonButton(keypath: "scanner.stop", label: "Stop", payload: .bool(true))
        stopButton.modifiers = neutralButton

        var clearButton = SkeletonButton(
            keypath: "encounters",
            label: "Clear encounter proofs",
            url: "cell:///EntityAnchor",
            payload: .object(Object())
        )
        clearButton.modifiers = warningButton

        var capabilityReference = SkeletonCellReference(keypath: "scanner", topic: "scanner.capabilities")
        let capabilityReferenceElements: SkeletonElementList = [
            .Text(SkeletonText(text: "Capabilities")),
            .Text(SkeletonText(keypath: "transportMode")),
            .Text(SkeletonText(keypath: "precisionMode")),
            .Text(SkeletonText(keypath: "supportsNearbyPrecision")),
            .Text(SkeletonText(keypath: "supportsMultipeerConnectivity")),
            .Text(SkeletonText(keypath: "sessionUUID")),
            .Text(SkeletonText(keypath: "description")),
            .Text(SkeletonText(keypath: "status"))
        ]
        var capabilityStack = SkeletonVStack(elements: capabilityReferenceElements)
        capabilityStack.modifiers = sectionCard
        capabilityReference.flowElementSkeleton = capabilityStack

        var statusReference = SkeletonCellReference(keypath: "scanner", topic: "scanner.status")
        let statusReferenceElements: SkeletonElementList = [
            .Text(SkeletonText(text: "Status")),
            .Text(SkeletonText(keypath: "status")),
            .Text(SkeletonText(keypath: "remoteUUID")),
            .Text(SkeletonText(keypath: "timestamp")),
            .Text(SkeletonText(keypath: "transportMode")),
            .Text(SkeletonText(keypath: "precisionMode")),
            .Text(SkeletonText(keypath: "description"))
        ]
        var statusStack = SkeletonVStack(elements: statusReferenceElements)
        statusStack.modifiers = sectionCard
        statusReference.flowElementSkeleton = statusStack

        var lostReference = SkeletonCellReference(keypath: "scanner", topic: "scanner.lost")
        let lostReferenceElements: SkeletonElementList = [
            .Text(SkeletonText(text: "Lost peer")),
            .Text(SkeletonText(keypath: "displayName")),
            .Text(SkeletonText(keypath: "remoteUUID")),
            .Text(SkeletonText(keypath: "timestamp"))
        ]
        var lostStack = SkeletonVStack(elements: lostReferenceElements)
        lostStack.modifiers = sectionCard
        lostReference.flowElementSkeleton = lostStack

        var pendingReference = SkeletonCellReference(keypath: "scanner", topic: "scanner.contact.pending")
        let pendingReferenceElements: SkeletonElementList = [
            .Text(SkeletonText(text: "Pending contact")),
            .Text(SkeletonText(keypath: "remoteUUID")),
            .Text(SkeletonText(keypath: "status")),
            .Text(SkeletonText(keypath: "message"))
        ]
        var pendingStack = SkeletonVStack(elements: pendingReferenceElements)
        pendingStack.modifiers = sectionCard
        pendingReference.flowElementSkeleton = pendingStack

        var foundReference = SkeletonCellReference(keypath: "scanner", topic: "scanner.found")
        let foundReferenceElements: SkeletonElementList = [
            .Text(SkeletonText(text: "Found peer")),
            .Text(SkeletonText(keypath: "displayName")),
            .Text(SkeletonText(keypath: "remoteUUID")),
            .Text(SkeletonText(keypath: "precisionMode")),
            .Button(SkeletonButton(keypath: "invite", label: "Send invite")),
            .Button(SkeletonButton(keypath: "requestContact", label: "Request contact"))
        ]
        var foundStack = SkeletonVStack(elements: foundReferenceElements)
        foundStack.modifiers = sectionCard
        foundReference.flowElementSkeleton = foundStack

        var outgoingReference = SkeletonCellReference(keypath: "scanner", topic: "scanner.contact.outgoing")
        let outgoingReferenceElements: SkeletonElementList = [
            .Text(SkeletonText(text: "Outgoing request")),
            .Text(SkeletonText(keypath: "requesterDisplayName")),
            .Text(SkeletonText(keypath: "requestId")),
            .Text(SkeletonText(keypath: "status"))
        ]
        var outgoingStack = SkeletonVStack(elements: outgoingReferenceElements)
        outgoingStack.modifiers = sectionCard
        outgoingReference.flowElementSkeleton = outgoingStack

        var incomingReference = SkeletonCellReference(keypath: "scanner", topic: "scanner.contact.received")
        let incomingReferenceElements: SkeletonElementList = [
            .Text(SkeletonText(text: "Incoming request")),
            .Text(SkeletonText(keypath: "requesterDisplayName")),
            .Text(SkeletonText(keypath: "requestId")),
            .Text(SkeletonText(keypath: "verification.status")),
            .Text(SkeletonText(text: "Accepting completes signed identity exchange and saves the relation locally.")),
            .Button(SkeletonButton(keypath: "acceptContact", label: "Accept + exchange"))
        ]
        var incomingStack = SkeletonVStack(elements: incomingReferenceElements)
        incomingStack.modifiers = sectionCard
        incomingReference.flowElementSkeleton = incomingStack

        var connectedReference = SkeletonCellReference(keypath: "scanner", topic: "scanner.connected")
        let connectedReferenceElements: SkeletonElementList = [
            .Text(SkeletonText(text: "Connected peers")),
            .Text(SkeletonText(keypath: "connectedCount")),
            .Text(SkeletonText(keypath: "connectedDevices"))
        ]
        var connectedStack = SkeletonVStack(elements: connectedReferenceElements)
        connectedStack.modifiers = sectionCard
        connectedReference.flowElementSkeleton = connectedStack

        var proximityReference = SkeletonCellReference(keypath: "scanner", topic: "scanner.proximity")
        let proximityReferenceElements: SkeletonElementList = [
            .Text(SkeletonText(text: "Proximity")),
            .Text(SkeletonText(keypath: "remoteUUID")),
            .Text(SkeletonText(keypath: "distanceMeters")),
            .Text(SkeletonText(keypath: "direction.x")),
            .Text(SkeletonText(keypath: "direction.y")),
            .Text(SkeletonText(keypath: "direction.z"))
        ]
        var proximityStack = SkeletonVStack(elements: proximityReferenceElements)
        proximityStack.modifiers = sectionCard
        proximityReference.flowElementSkeleton = proximityStack

        var savedReference = SkeletonCellReference(keypath: "scanner", topic: "scanner.encounter.saved")
        let savedReferenceElements: SkeletonElementList = [
            .Text(SkeletonText(text: "Saved encounter")),
            .Text(SkeletonText(keypath: "remoteDisplayName")),
            .Text(SkeletonText(keypath: "matchCount")),
            .Text(SkeletonText(keypath: "acceptedAt")),
            .Text(SkeletonText(keypath: "requestVerification.status")),
            .Text(SkeletonText(keypath: "acceptanceVerification.status"))
        ]
        var savedStack = SkeletonVStack(elements: savedReferenceElements)
        savedStack.modifiers = sectionCard
        savedReference.flowElementSkeleton = savedStack

        var establishedReference = SkeletonCellReference(keypath: "scanner", topic: "scanner.contact.established")
        let establishedReferenceElements: SkeletonElementList = [
            .Text(SkeletonText(text: "Identity saved")),
            .Text(SkeletonText(keypath: "remoteDisplayName")),
            .Text(SkeletonText(keypath: "precisionMode")),
            .Text(SkeletonText(keypath: "acceptedAt")),
            .Text(SkeletonText(text: "Signed identity exchange complete · Relation persisted · Proof saved"))
        ]
        var establishedStack = SkeletonVStack(elements: establishedReferenceElements)
        establishedStack.modifiers = sectionCard
        establishedReference.flowElementSkeleton = establishedStack

        var exportedProofReference = SkeletonCellReference(keypath: "scanner", topic: "scanner.encounter.exported")
        let exportedProofReferenceElements: SkeletonElementList = [
            .Text(SkeletonText(text: "Encounter proof exported")),
            .Text(SkeletonText(keypath: "remoteDisplayName")),
            .Text(SkeletonText(keypath: "encounterId")),
            .Text(SkeletonText(keypath: "requestVerification.status")),
            .Text(SkeletonText(keypath: "acceptanceVerification.status"))
        ]
        var exportedProofStack = SkeletonVStack(elements: exportedProofReferenceElements)
        exportedProofStack.modifiers = sectionCard
        exportedProofReference.flowElementSkeleton = exportedProofStack

        var exportedJSONReference = SkeletonCellReference(keypath: "scanner", topic: "scanner.encounter.jsonExported")
        var exportedJSONName = SkeletonText(text: "Encounter JSON exported")
        exportedJSONName.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.textMain
        }
        var exportedJSONPayload = SkeletonText(keypath: "json")
        exportedJSONPayload.modifiers = modifier {
            $0.fontSize = 11
            $0.foregroundColor = ConferenceSurfacePalette.textMuted
            $0.lineLimit = 8
        }
        let exportedJSONReferenceElements: SkeletonElementList = [
            .Text(exportedJSONName),
            .Text(SkeletonText(keypath: "remoteDisplayName")),
            .Text(SkeletonText(keypath: "fileName")),
            .Text(SkeletonText(keypath: "copiedToClipboard")),
            .Text(SkeletonText(keypath: "characterCount")),
            .Text(exportedJSONPayload)
        ]
        var exportedJSONStack = SkeletonVStack(elements: exportedJSONReferenceElements)
        exportedJSONStack.modifiers = sectionCard
        exportedJSONReference.flowElementSkeleton = exportedJSONStack

        var encounterList = SkeletonList(keypath: "scanner.encounters")
        var encounterRow = SkeletonElementList()
        var encounterLabel = SkeletonText(text: "Encounter")
        encounterLabel.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.textMain
        }
        encounterRow.append(.Text(encounterLabel))
        encounterRow.append(.Text(SkeletonText(keypath: "remoteDisplayName")))
        encounterRow.append(.Text(SkeletonText(keypath: "matchCount")))
        encounterRow.append(.Text(SkeletonText(keypath: "precisionMode")))
        encounterRow.append(.Text(SkeletonText(keypath: "acceptedAt")))
        encounterRow.append(.Text(SkeletonText(keypath: "requestVerification.status")))
        encounterRow.append(.Text(SkeletonText(keypath: "acceptanceVerification.status")))
        encounterRow.append(.Button(SkeletonButton(keypath: "exportEncounter", label: "export")))
        encounterRow.append(.Button(SkeletonButton(keypath: "exportEncounterJSON", label: "copy json")))
        encounterList.flowElementSkeleton = SkeletonVStack(elements: encounterRow)
        encounterList.modifiers = listCard

        var root = SkeletonElementList()
        var heroHeader = SkeletonHStack(elements: [
            .VStack(SkeletonVStack(elements: [.Text(titleText), .Text(subtitleText), .Text(privacyNoteText)])),
            .Spacer(SkeletonSpacer()),
            .Text(heroChip)
        ])
        heroHeader.modifiers = modifier { $0.padding = 2 }

        var heroBadges = SkeletonHStack(elements: [
            .Text(badgeMPC),
            .Text(badgeSigned),
            .Text(badgeJSON),
            .Text(badgeUWB)
        ])
        heroBadges.modifiers = modifier { $0.padding = 2 }

        var heroStack = SkeletonVStack(elements: [
            .HStack(heroHeader),
            .Divider(SkeletonDivider()),
            .Text(localRuntimeText),
            .Text(privacyNoteText),
            .HStack(heroBadges),
            .HStack(SkeletonHStack(elements: [.Button(startButton), .Button(stopButton), .Button(clearButton)]))
        ])
        heroStack.modifiers = heroCard
        root.append(.VStack(heroStack))

        if !checklist.isEmpty {
            var checklistContent = SkeletonElementList()
            for item in checklist {
                var itemText = SkeletonText(text: item)
                itemText.modifiers = modifier {
                    $0.foregroundColor = ConferenceSurfacePalette.strokeStrong
                    $0.fontSize = 12
                }
                checklistContent.append(.Text(itemText))
            }
            var howToHeader = SkeletonText(text: "How to use")
            howToHeader.modifiers = modifier {
                $0.fontWeight = "semibold"
                $0.foregroundColor = ConferenceSurfacePalette.strokeStrong
            }
            var section = SkeletonSection(
                header: .Text(howToHeader),
                content: checklistContent
            )
            section.modifiers = stepsSectionCard
            root.append(.Section(section))
        }

        var diagnosticsHeader = SkeletonText(text: "Troubleshooting")
        diagnosticsHeader.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#854D0E"
        }
        let diagnosticsLines = [
            "Mac kan brukes som scanner-peer via MultipeerConnectivity, men ikke UWB. Forvent precisionMode = multipeer-only.",
            "Pa iPhone og macOS ma Local Network/Bonjour godkjennes for discovery. Hvis du tidligere har avslatt, sla det pa igjen i systeminnstillingene.",
            "Hvis du bare ser 'started' og ingen peers: sjekk at begge enheter kjorer samme build, er pa samme lokale nett og at appen ikke er blokkert av Local Network permission.",
            "Hvis capabilities ikke viser sessionUUID eller transportMode etter start, kom scanner ikke ordentlig opp.",
            "Hvis peers blir funnet men kontakt ikke etableres, se etter 'connecting', 'connected', 'pendingConnection' og 'connectedDevices'."
        ]
        var diagnosticsContent = SkeletonElementList()
        for line in diagnosticsLines {
            var info = SkeletonText(text: line)
            info.modifiers = modifier {
                $0.foregroundColor = ConferenceSurfacePalette.textMuted
                $0.fontSize = 12
                $0.lineLimit = 4
            }
            diagnosticsContent.append(.Text(info))
        }
        var diagnosticsSection = SkeletonSection(
            header: .Text(diagnosticsHeader),
            content: diagnosticsContent
        )
        diagnosticsSection.modifiers = diagnosticsSectionCard
        root.append(.Section(diagnosticsSection))

        let radarSectionContent: SkeletonElementList = [
            bindingConferencePortalStaticText(
                "Judged proximity: EntityScanner stays calm until explicitly started, then HAVEN filters nearby entities into a relevant primary list. Lower and nearby-only hits stay hidden by default and are counted separately.",
                fontSize: 12,
                foregroundColor: ConferenceSurfacePalette.textMuted,
                lineLimit: 4
            ),
            .Grid(
                SkeletonGrid(
                    columns: [.adaptive(min: 220, max: 320)],
                    spacing: 12,
                    elements: [
                        bindingConferencePortalStateSummaryCard(
                            title: "Scanner",
                            detailKeypath: "nearbyRadar.state.statusSummary",
                            noteKeypath: "nearbyRadar.state.actionSummary",
                            accentBorder: ConferenceSurfacePalette.accentCoolBorder,
                            accentText: ConferenceSurfacePalette.accentCool,
                            height: 132
                        ),
                        bindingConferencePortalStateSummaryCard(
                            title: "Entities",
                            detailKeypath: "nearbyRadar.state.summary",
                            noteKeypath: "nearbyRadar.state.lowerMatchesSummary",
                            accentBorder: ConferenceSurfacePalette.strokeStrong,
                            accentText: ConferenceSurfacePalette.accentWarm,
                            height: 132
                        ),
                        bindingConferencePortalStateSummaryCard(
                            title: "Focus",
                            detailKeypath: "nearbyRadar.state.selectedEntity.relevanceBadge",
                            noteKeypath: "nearbyRadar.state.selectedEntity.relevanceSummary",
                            accentBorder: "#2F6B56",
                            accentText: "#B9FBC0",
                            height: 132
                        )
                    ]
                )
            ),
            .HStack(
                SkeletonHStack(elements: [
                    bindingConferencePortalActionButton(
                        "nearbyRadar",
                        actionKeypath: "toggleLowerMatches",
                        label: "Show / hide lower matches"
                    ),
                    bindingConferencePortalActionButton(
                        "nearbyRadar",
                        actionKeypath: "start",
                        label: "Start scanning"
                    ),
                    bindingConferencePortalActionButton(
                        "nearbyRadar",
                        actionKeypath: "stop",
                        label: "Stop"
                    )
                ])
            ),
            bindingConferencePortalKeyText("nearbyRadar.state.showLowerMatchesLabel", fontSize: 12, fontWeight: "bold", foregroundColor: "#F4D58D", lineLimit: 1),
            bindingConferencePortalKeyText("nearbyRadar.state.spatialTruthSummary", fontSize: 12, foregroundColor: ConferenceSurfacePalette.textMuted, lineLimit: 4),
            bindingConferencePortalEmbeddedRadarLayout(baseKeypath: "nearbyRadar.state.radarLayout"),
            bindingConferencePortalCollectionGrid(
                keypath: "nearbyRadar.state.nearby",
                min: 220,
                max: 320,
                itemSkeleton: bindingConferencePortalNearbyCardSkeleton()
            ),
            bindingConferencePortalNearbyFocusPanelSection(scannerReferenceLabel: "nearbyRadar")
        ]
        var radarHeader = SkeletonText(text: "Live nearby radar")
        radarHeader.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.accentCool
        }
        var radarSection = SkeletonSection(
            header: .Text(radarHeader),
            content: radarSectionContent
        )
        radarSection.modifiers = liveSectionCard
        root.append(.Section(radarSection))

        if includePerspectiveSection {
            var activePurposeList = SkeletonList(keypath: "cell:///Perspective/activePurpose.purposes")
            var activePurposeRow = SkeletonElementList()
            activePurposeRow.append(.Text(SkeletonText(text: "Purpose")))
            activePurposeRow.append(.Text(SkeletonText(keypath: "purposeName")))
            activePurposeRow.append(.Text(SkeletonText(keypath: "purposeWeight")))
            activePurposeRow.append(.Text(SkeletonText(keypath: "portablePurposeRef")))
            activePurposeList.flowElementSkeleton = SkeletonVStack(elements: activePurposeRow)
            activePurposeList.modifiers = listCard

            let perspectiveContent: SkeletonElementList = [
                .Text(SkeletonText(text: "Local Perspective snapshot used in request/accept payloads.")),
                .List(activePurposeList)
            ]
            var perspectiveHeader = SkeletonText(text: "Perspective")
            perspectiveHeader.modifiers = modifier {
                $0.fontWeight = "semibold"
                $0.foregroundColor = ConferenceSurfacePalette.accentCool
            }
            var section = SkeletonSection(
                header: .Text(perspectiveHeader),
                content: perspectiveContent
            )
            section.modifiers = perspectiveSectionCard
            root.append(.Section(section))
        }

        let liveSectionContent: SkeletonElementList = [
            .Reference(capabilityReference),
            .Reference(statusReference),
            .Reference(foundReference),
            .Reference(lostReference),
            .Reference(connectedReference),
            .Reference(proximityReference),
            .Reference(pendingReference),
            .Reference(outgoingReference),
            .Reference(incomingReference),
            .Reference(establishedReference),
            .Reference(savedReference),
            .Reference(exportedProofReference),
            .Reference(exportedJSONReference)
        ]
        var liveHeader = SkeletonText(text: "Live scanner flow")
        liveHeader.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.accentCool
        }
        var liveSection = SkeletonSection(
            header: .Text(liveHeader),
            content: liveSectionContent
        )
        liveSection.modifiers = liveSectionCard
        root.append(.Section(liveSection))

        let storageContent: SkeletonElementList = [
            .Text(SkeletonText(text: "Encounter proofs lagres lokalt i EntityAnchor og kan eksporteres eller nullstilles herfra.")),
            .List(encounterList)
        ]
        var storageHeader = SkeletonText(text: "Stored encounters")
        storageHeader.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.textMain
        }
        var storageSection = SkeletonSection(
            header: .Text(storageHeader),
            content: storageContent
        )
        storageSection.modifiers = storageSectionCard
        root.append(.Section(storageSection))

        var rootStack = SkeletonVStack(elements: root)
        rootStack.modifiers = card
        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(rootStack)])
        scroll.modifiers = modifier {
            $0.padding = 4
            $0.background = ConferenceSurfacePalette.canvas
        }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func scaffoldChatWorkbenchConfiguration(
        endpoint: String,
        displayName: String,
        summary: String
    ) -> CellConfiguration {
        var configuration = CellConfiguration(name: displayName)
        configuration.description = summary

        var chatReference = CellReference(endpoint: endpoint, label: "chat")
        chatReference.subscribeFeed = true
        configuration.addReference(chatReference)

        let pageCard = modifier {
            $0.padding = 10
            $0.background = "#F7F7FC"
            $0.cornerRadius = 18
            $0.borderWidth = 1
            $0.borderColor = "#D7D8F5"
        }

        let heroCard = modifier {
            $0.padding = 14
            $0.background = "#F5F3FF"
            $0.cornerRadius = 18
            $0.borderWidth = 1
            $0.borderColor = "#A78BFA"
            $0.shadowRadius = 8
            $0.shadowY = 3
            $0.shadowColor = "#0F172A18"
        }

        let sectionCard = modifier {
            $0.padding = 10
            $0.background = "#FFFFFF"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = "#DDD6FE"
        }

        let fieldCard = modifier {
            $0.padding = 10
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#C4B5FD"
        }

        let messagesListCard = modifier {
            $0.padding = 6
            $0.background = "#FFFFFF"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = "#DDD6FE"
            $0.height = 320
        }

        let participantsListCard = modifier {
            $0.padding = 6
            $0.background = "#FFFFFF"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = "#DDD6FE"
            $0.height = 180
        }

        let previewListCard = modifier {
            $0.padding = 6
            $0.background = "#FFFFFF"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = "#DDD6FE"
            $0.height = 220
        }

        let primaryButton = modifier {
            $0.padding = 10
            $0.background = "#7C3AED"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#6D28D9"
            $0.foregroundColor = "#FFFFFF"
        }

        let secondaryButton = modifier {
            $0.padding = 10
            $0.background = "#EDE9FE"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#C4B5FD"
        }

        let warningButton = modifier {
            $0.padding = 10
            $0.background = "#FEF3C7"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#F59E0B"
        }

        let chipModifier = modifier {
            $0.padding = 6
            $0.background = "#EDE9FE"
            $0.cornerRadius = 999
            $0.borderWidth = 1
            $0.borderColor = "#C4B5FD"
            $0.fontSize = 11
            $0.fontWeight = "semibold"
        }

        let subtleMetaModifier = modifier {
            $0.foregroundColor = "#64748B"
            $0.fontSize = 11
            $0.lineLimit = 2
        }

        let avatarModifier = modifier {
            $0.width = 36
            $0.height = 36
            $0.background = "#DDD6FE"
            $0.cornerRadius = 999
            $0.borderWidth = 1
            $0.borderColor = "#C4B5FD"
            $0.foregroundColor = "#5B21B6"
            $0.fontSize = 12
            $0.fontWeight = "bold"
        }

        func bodyText(_ text: String, color: String = "#475569", size: Double = 12) -> SkeletonText {
            var label = SkeletonText(text: text)
            label.modifiers = modifier {
                $0.foregroundColor = color
                $0.fontSize = size
                $0.lineLimit = 4
            }
            return label
        }

        func sectionTitle(_ text: String, color: String = "#1F2937") -> SkeletonText {
            var label = SkeletonText(text: text)
            label.modifiers = modifier {
                $0.fontWeight = "semibold"
                $0.foregroundColor = color
                $0.fontSize = 13
            }
            return label
        }

        var title = SkeletonText(text: displayName)
        title.modifiers = modifier {
            $0.fontStyle = "title2"
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#1F2937"
        }

        var subtitle = SkeletonText(text: "Kjores mot staging slik at flere klienter kan absorbere samme chat og se samme historikk.")
        subtitle.modifiers = modifier {
            $0.foregroundColor = "#475569"
            $0.fontSize = 12
            $0.lineLimit = 4
        }

        var endpointText = SkeletonText(text: endpoint)
        endpointText.modifiers = modifier {
            $0.foregroundColor = "#6D28D9"
            $0.fontSize = 11
            $0.lineLimit = 2
        }

        var liveChip = SkeletonText(text: "STAGING LIVE")
        liveChip.modifiers = chipModifier
        var sharedChip = SkeletonText(text: "Shared conversation")
        sharedChip.modifiers = chipModifier
        var feedChip = SkeletonText(text: "State + feed")
        feedChip.modifiers = chipModifier
        var markdownChip = SkeletonText(text: "Markdown ready")
        markdownChip.modifiers = chipModifier

        var statusValue = SkeletonText(url: URL(string: "cell:///Porthole/chat.status")!)
        statusValue.modifiers = modifier {
            $0.foregroundColor = "#312E81"
            $0.fontSize = 12
            $0.lineLimit = 4
        }

        var statusReference = SkeletonCellReference(keypath: "chat", topic: "chat.status")
        var statusReferenceStack = SkeletonVStack(elements: [
            .Text(sectionTitle("Live chat status", color: "#5B21B6")),
            .Text(SkeletonText(keypath: "summary")),
            .Text(SkeletonText(keypath: "participantCount")),
            .Text(SkeletonText(keypath: "messageCount")),
            .Text(SkeletonText(keypath: "latestMessagePreview")),
            .Text(SkeletonText(keypath: "latestMessageRelativeAt")),
            .Text(SkeletonText(keypath: "latestMessageDisplayAt"))
        ])
        statusReferenceStack.modifiers = sectionCard
        statusReference.flowElementSkeleton = statusReferenceStack

        let composerArea = SkeletonTextArea(
            text: nil,
            sourceKeypath: "chat.compose.body",
            targetKeypath: "chat.compose.body",
            placeholder: "Skriv melding. Velg markdown hvis du vil bruke formatering som **fet**, punktlister eller lenker.",
            minLines: 4,
            maxLines: 8,
            submitOnEnter: false,
            modifiers: fieldCard
        )

        var plainFormatButton = SkeletonButton(
            keypath: "chat.compose.contentType",
            label: "Plain text",
            payload: .string("text/plain")
        )
        plainFormatButton.modifiers = secondaryButton

        var markdownFormatButton = SkeletonButton(
            keypath: "chat.compose.contentType",
            label: "Markdown",
            payload: .string("text/markdown")
        )
        markdownFormatButton.modifiers = secondaryButton

        var sendButton = SkeletonButton(
            keypath: "chat.sendComposedMessage",
            label: "Send message",
            payload: .bool(true)
        )
        sendButton.modifiers = primaryButton

        var clearButton = SkeletonButton(
            keypath: "chat.clearComposer",
            label: "Clear draft",
            payload: .bool(true)
        )
        clearButton.modifiers = warningButton

        var composerPreviewFormat = SkeletonText(keypath: "formatLabel")
        composerPreviewFormat.modifiers = chipModifier

        var composerPreviewCharacterCount = SkeletonText(keypath: "characterCountLabel")
        composerPreviewCharacterCount.modifiers = subtleMetaModifier

        var composerPreviewLineCount = SkeletonText(keypath: "lineCountLabel")
        composerPreviewLineCount.modifiers = subtleMetaModifier

        var composerPreviewDescription = SkeletonText(keypath: "formatDescription")
        composerPreviewDescription.modifiers = modifier {
            $0.foregroundColor = "#334155"
            $0.fontSize = 12
            $0.lineLimit = 3
        }

        var composerPreviewHelper = SkeletonText(keypath: "helperText")
        composerPreviewHelper.modifiers = subtleMetaModifier

        var composerPreviewBody = SkeletonText(keypath: "previewRichText")
        composerPreviewBody.modifiers = modifier {
            $0.foregroundColor = "#1F2937"
            $0.fontSize = 13
            $0.lineLimit = 12
            $0.multilineTextAlignment = "leading"
            $0.styleRole = "markdown"
        }

        var composerPreviewSummary = SkeletonText(keypath: "previewSummary")
        composerPreviewSummary.modifiers = subtleMetaModifier

        var composerPreviewSendHint = SkeletonText(keypath: "sendHint")
        composerPreviewSendHint.modifiers = modifier {
            $0.foregroundColor = "#5B21B6"
            $0.fontSize = 12
            $0.lineLimit = 3
        }

        var composerPreviewRow = SkeletonVStack(elements: [
            .HStack(SkeletonHStack(elements: [
                .Text(composerPreviewFormat),
                .Spacer(SkeletonSpacer()),
                .Text(composerPreviewCharacterCount),
                .Text(composerPreviewLineCount)
            ])),
            .Text(composerPreviewDescription),
            .Text(composerPreviewHelper),
            .Text(composerPreviewBody),
            .Text(composerPreviewSummary),
            .Text(composerPreviewSendHint)
        ])
        composerPreviewRow.modifiers = sectionCard

        var composerPreviewList = SkeletonList(
            keypath: "chat.compose.previewRows",
            flowElementSkeleton: composerPreviewRow
        )
        composerPreviewList.modifiers = previewListCard

        var messageAvatar = SkeletonText(keypath: "ownerInitials")
        messageAvatar.modifiers = avatarModifier

        var messageAuthor = SkeletonText(keypath: "ownerDisplayName")
        messageAuthor.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#1F2937"
            $0.fontSize = 13
        }

        var messageRelativeTimestamp = SkeletonText(keypath: "relativeTimestamp")
        messageRelativeTimestamp.modifiers = subtleMetaModifier

        var messageTimestamp = SkeletonText(keypath: "displayTimestamp")
        messageTimestamp.modifiers = subtleMetaModifier

        var messageFormat = SkeletonText(keypath: "formatLabel")
        messageFormat.modifiers = chipModifier

        var messageBody = SkeletonText(keypath: "contentRichText")
        messageBody.modifiers = modifier {
            $0.foregroundColor = "#334155"
            $0.fontSize = 13
            $0.lineLimit = 14
            $0.multilineTextAlignment = "leading"
            $0.styleRole = "markdown"
        }

        var messagePreview = SkeletonText(keypath: "contentPreview")
        messagePreview.modifiers = subtleMetaModifier

        var messageRow = SkeletonHStack(elements: [
            .Text(messageAvatar),
            .VStack(SkeletonVStack(elements: [
                .HStack(SkeletonHStack(elements: [
                    .Text(messageAuthor),
                    .Spacer(SkeletonSpacer()),
                    .Text(messageRelativeTimestamp)
                ])),
                .HStack(SkeletonHStack(elements: [
                    .Text(messageFormat),
                    .Spacer(SkeletonSpacer()),
                    .Text(messageTimestamp)
                ])),
                .Text(messageBody),
                .Text(messagePreview)
            ]))
        ])
        messageRow.modifiers = sectionCard

        var messagesList = SkeletonList(
            topic: "chat.message",
            keypath: "chat.messages",
            flowElementSkeleton: SkeletonVStack(elements: [.HStack(messageRow)])
        )
        messagesList.modifiers = messagesListCard

        var participantAvatar = SkeletonText(keypath: "initials")
        participantAvatar.modifiers = avatarModifier

        var participantName = SkeletonText(keypath: "displayName")
        participantName.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#1F2937"
            $0.fontSize = 13
        }

        var participantPresence = SkeletonText(keypath: "presenceLabel")
        participantPresence.modifiers = chipModifier

        var participantMeta = SkeletonText(keypath: "activitySummary")
        participantMeta.modifiers = subtleMetaModifier

        var participantCount = SkeletonText(keypath: "lastSeenDisplay")
        participantCount.modifiers = subtleMetaModifier

        var participantRow = SkeletonHStack(elements: [
            .Text(participantAvatar),
            .VStack(SkeletonVStack(elements: [
                .HStack(SkeletonHStack(elements: [
                    .Text(participantName),
                    .Spacer(SkeletonSpacer()),
                    .Text(participantPresence)
                ])),
                .Text(participantMeta),
                .Text(participantCount)
            ]))
        ])
        participantRow.modifiers = sectionCard

        var participantsList = SkeletonList(
            topic: "chat.participant",
            keypath: "chat.participants",
            flowElementSkeleton: SkeletonVStack(elements: [.HStack(participantRow)])
        )
        participantsList.modifiers = participantsListCard

        var heroSection = SkeletonSection(
            header: nil,
            content: [
                .HStack(SkeletonHStack(elements: [
                    .VStack(SkeletonVStack(elements: [
                        .Text(title),
                        .Text(subtitle),
                        .Text(endpointText)
                    ])),
                    .Spacer(SkeletonSpacer()),
                    .Text(liveChip)
                ])),
                .HStack(SkeletonHStack(elements: [.Text(sharedChip), .Text(feedChip), .Text(markdownChip)])),
                .Text(sectionTitle("Current status", color: "#5B21B6")),
                .Text(statusValue)
            ]
        )
        heroSection.modifiers = heroCard

        var participantsSection = SkeletonSection(
            header: .Text(sectionTitle("Who is here", color: "#5B21B6")),
            footer: .Text(bodyText("Participants listen combines current state with live participant events from staging.")),
            content: [
                .List(participantsList)
            ]
        )
        participantsSection.modifiers = sectionCard

        var conversationSection = SkeletonSection(
            header: .Text(sectionTitle("Conversation", color: "#5B21B6")),
            footer: .Text(bodyText("Historikk hentes fra `chat.messages`, nye meldinger kommer via `chat.message`, og markdown-meldinger rendres direkte i workbenchen.")),
            content: [
                .List(messagesList),
                .Reference(statusReference)
            ]
        )
        conversationSection.modifiers = sectionCard

        var composerSection = SkeletonSection(
            header: .Text(sectionTitle("Compose and send", color: "#5B21B6")),
            footer: .Text(bodyText("Draften er privat per requester og hentes via get-state, mens sendte meldinger fortsatt går på delt state + feed. Andre klienter som absorberer staging-chat vil se den samme meldingen etter sending.")),
            content: [
                .Text(bodyText("Recommended: bruk markdown for lister, fremheving og lenker. Plain text er tryggest hvis mottakerne ikke render markdown.")),
                .List(composerPreviewList),
                .TextArea(composerArea),
                .HStack(SkeletonHStack(elements: [
                    .Button(plainFormatButton),
                    .Button(markdownFormatButton)
                ])),
                .HStack(SkeletonHStack(elements: [
                    .Button(sendButton),
                    .Button(clearButton)
                ]))
            ]
        )
        composerSection.modifiers = sectionCard

        var root = SkeletonVStack(elements: [
            .Section(heroSection),
            .Section(participantsSection),
            .Section(conversationSection),
            .Section(composerSection)
        ])
        root.modifiers = pageCard

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.padding = 4
            $0.background = "#F5F3FF"
        }

        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func perspectiveWorkbenchConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Perspective Context")
        configuration.description = "Kontrollflate for lokale formaal, interesser og kontekst som styrer menyer og semantisk matching."
        configuration.addReference(CellReference(endpoint: "cell:///Perspective", label: "perspective"))

        let card = conferenceCardModifier(
            padding: 10,
            background: ConferenceSurfacePalette.shellMuted,
            borderColor: ConferenceSurfacePalette.stroke,
            cornerRadius: 18
        )
        let heroCard = conferenceCardModifier(
            padding: 12,
            background: ConferenceSurfacePalette.shellStrong,
            borderColor: ConferenceSurfacePalette.accentCoolBorder,
            cornerRadius: 20,
            shadowRadius: 10,
            shadowY: 3
        )
        let sectionCard = conferenceCardModifier(
            padding: 10,
            background: ConferenceSurfacePalette.shell,
            borderColor: ConferenceSurfacePalette.stroke,
            cornerRadius: 14
        )
        let listCard = modifier {
            $0.padding = 6
            $0.background = ConferenceSurfacePalette.shell
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = ConferenceSurfacePalette.stroke
            $0.height = 220
        }
        let primaryButton = conferenceButtonModifier(
            background: ConferenceSurfacePalette.accentCoolSoft,
            borderColor: ConferenceSurfacePalette.accentCoolBorder,
            foregroundColor: ConferenceSurfacePalette.textMain
        )
        let secondaryButton = conferenceButtonModifier(
            background: ConferenceSurfacePalette.accentWarmSoft,
            borderColor: ConferenceSurfacePalette.strokeStrong,
            foregroundColor: ConferenceSurfacePalette.textMain
        )
        let chipModifier = conferenceChipModifier(
            background: ConferenceSurfacePalette.accentCoolSoft,
            borderColor: ConferenceSurfacePalette.accentCoolBorder,
            foregroundColor: ConferenceSurfacePalette.textMain
        )

        var title = SkeletonText(text: "Perspective Context")
        title.modifiers = modifier {
            $0.fontStyle = "title2"
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.textMain
        }
        var subtitle = SkeletonText(text: "Lokal purpose-state. Denne flaten styrer baade convenience-menyene og hva Apple Intelligence boer anbefale videre.")
        subtitle.modifiers = modifier {
            $0.foregroundColor = ConferenceSurfacePalette.textMuted
            $0.fontSize = 12
            $0.lineLimit = 3
        }
        var localChip = SkeletonText(text: "LOCAL CONTEXT")
        localChip.modifiers = chipModifier
        var matchingChip = SkeletonText(text: "MATCH SIGNAL")
        matchingChip.modifiers = chipModifier
        var purposeCount = SkeletonText(url: URL(string: "cell:///Perspective/perspective.state.activePurposeCount")!)
        purposeCount.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.accentCool
            $0.fontSize = 18
        }
        var interestCount = SkeletonText(url: URL(string: "cell:///Perspective/perspective.state.activeInterestCount")!)
        interestCount.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.accentWarm
            $0.fontSize = 18
        }

        var addConnections = SkeletonButton(
            keypath: "addPurpose",
            label: "Nye relasjoner",
            url: "cell:///Perspective",
            payload: .object([
                "name": .string("Make new connections"),
                "description": .string("Finn mennesker med relevante interesser og bygg nye relasjoner.")
            ])
        )
        addConnections.modifiers = primaryButton

        var addLearning = SkeletonButton(
            keypath: "addPurpose",
            label: "Laere noe nytt",
            url: "cell:///Perspective",
            payload: .object([
                "name": .string("Learn something useful"),
                "description": .string("Prioriter laering, faglig utbytte og relevante samtaler.")
            ])
        )
        addLearning.modifiers = primaryButton

        var addTrust = SkeletonButton(
            keypath: "addPurpose",
            label: "Bygge tillit",
            url: "cell:///Perspective",
            payload: .object([
                "name": .string("Build trusted credential relationships"),
                "description": .string("Utforsk identitet, proof chains og trusted issuers.")
            ])
        )
        addTrust.modifiers = secondaryButton

        var addNotes = SkeletonButton(
            keypath: "addPurpose",
            label: "Fange innsikt",
            url: "cell:///Perspective",
            payload: .object([
                "name": .string("Capture ideas and notes"),
                "description": .string("Hold orden paa notater, oppfoelging og kunnskap.")
            ])
        )
        addNotes.modifiers = secondaryButton

        var activePurposeHeader = SkeletonText(text: "Aktive formaal")
        activePurposeHeader.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.textMain
        }

        var purposeName = SkeletonText(keypath: "purposeName")
        purposeName.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.textMain
        }
        var purposeWeight = SkeletonText(keypath: "purposeWeight")
        purposeWeight.modifiers = modifier {
            $0.foregroundColor = ConferenceSurfacePalette.accentCool
            $0.fontSize = 12
        }
        var purposeRef = SkeletonText(keypath: "portablePurposeRef")
        purposeRef.modifiers = modifier {
            $0.foregroundColor = ConferenceSurfacePalette.textMuted
            $0.fontSize = 11
            $0.lineLimit = 2
        }
        var purposeRow = SkeletonVStack(elements: [
            .Text(purposeName),
            .Text(purposeWeight),
            .Text(purposeRef)
        ])
        purposeRow.modifiers = sectionCard

        var activePurposeList = SkeletonList(keypath: "cell:///Perspective/activePurpose.purposes", flowElementSkeleton: purposeRow)
        activePurposeList.modifiers = listCard

        var stateHeader = SkeletonText(text: "Perspektiv-state (JSON)")
        stateHeader.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.textMain
        }
        var rawState = SkeletonText(url: URL(string: "cell:///Perspective/perspective.state")!)
        rawState.modifiers = modifier {
            $0.foregroundColor = ConferenceSurfacePalette.textMuted
            $0.fontSize = 11
            $0.lineLimit = 10
        }

        var hero = SkeletonVStack(elements: [
            .Text(title),
            .Text(subtitle),
            .HStack(SkeletonHStack(elements: [.Text(localChip), .Text(matchingChip)])),
            .HStack(SkeletonHStack(elements: [
                .VStack(SkeletonVStack(elements: [.Text(SkeletonText(text: "Active purposes")), .Text(purposeCount)])),
                .VStack(SkeletonVStack(elements: [.Text(SkeletonText(text: "Active interests")), .Text(interestCount)]))
            ])),
            .HStack(SkeletonHStack(elements: [.Button(addConnections), .Button(addLearning)])),
            .HStack(SkeletonHStack(elements: [.Button(addTrust), .Button(addNotes)]))
        ])
        hero.modifiers = heroCard

        var summarySection = SkeletonSection(
            header: .Text(activePurposeHeader),
            content: [.List(activePurposeList)]
        )
        summarySection.modifiers = sectionCard

        var stateSection = SkeletonSection(
            header: .Text(stateHeader),
            content: [.Text(rawState)]
        )
        stateSection.modifiers = sectionCard

        var root = SkeletonVStack(elements: [
            .VStack(hero),
            .Section(summarySection),
            .Section(stateSection)
        ])
        root.modifiers = card

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.background = ConferenceSurfacePalette.canvas
        }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func entityAnchorWorkbenchConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Entity Anchor Records")
        configuration.description = "Inspeksjon av lokal entitet, relasjoner og proofs som andre verktoy lagrer i EntityAnchor."
        configuration.addReference(CellReference(endpoint: "cell:///EntityAnchor", label: "entity"))

        let card = conferenceCardModifier(
            padding: 10,
            background: ConferenceSurfacePalette.shellMuted,
            borderColor: ConferenceSurfacePalette.stroke,
            cornerRadius: 18
        )
        let heroCard = conferenceCardModifier(
            padding: 12,
            background: ConferenceSurfacePalette.shellStrong,
            borderColor: ConferenceSurfacePalette.strokeStrong,
            cornerRadius: 20,
            shadowRadius: 10,
            shadowY: 3
        )
        let sectionCard = conferenceCardModifier(
            padding: 10,
            background: ConferenceSurfacePalette.shell,
            borderColor: ConferenceSurfacePalette.stroke,
            cornerRadius: 14
        )
        let listCard = modifier {
            $0.padding = 6
            $0.background = ConferenceSurfacePalette.shell
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = ConferenceSurfacePalette.stroke
            $0.height = 180
        }
        let primaryButton = conferenceButtonModifier(
            background: ConferenceSurfacePalette.accentCoolSoft,
            borderColor: ConferenceSurfacePalette.accentCoolBorder,
            foregroundColor: ConferenceSurfacePalette.textMain
        )
        let warningButton = conferenceButtonModifier(
            background: ConferenceSurfacePalette.cautionSoft,
            borderColor: ConferenceSurfacePalette.strokeStrong,
            foregroundColor: ConferenceSurfacePalette.textMain
        )
        let chipModifier = conferenceChipModifier(
            background: ConferenceSurfacePalette.accentWarmSoft,
            borderColor: ConferenceSurfacePalette.strokeStrong,
            foregroundColor: ConferenceSurfacePalette.textMain
        )

        var title = SkeletonText(text: "Entity Anchor Records")
        title.modifiers = modifier {
            $0.fontStyle = "title2"
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.textMain
        }
        var subtitle = SkeletonText(text: "Les person, relasjoner og proofs direkte. Entity Scanner og andre identitetsflyter legger sporene sine her.")
        subtitle.modifiers = modifier {
            $0.foregroundColor = ConferenceSurfacePalette.textMuted
            $0.fontSize = 12
            $0.lineLimit = 3
        }
        var proofsChip = SkeletonText(text: "PROOFS + RELATIONS")
        proofsChip.modifiers = chipModifier

        var reloadStorage = SkeletonButton(keypath: "reloadStorage", label: "Reload storage", url: "cell:///EntityAnchor")
        reloadStorage.modifiers = primaryButton
        var clearEncounters = SkeletonButton(
            keypath: "proofs.encounters",
            label: "Clear encounter proofs",
            url: "cell:///EntityAnchor",
            payload: .object([:])
        )
        clearEncounters.modifiers = warningButton

        func jsonText(_ label: String, urlString: String) -> SkeletonSection {
            var header = SkeletonText(text: label)
            header.modifiers = modifier {
                $0.fontWeight = "semibold"
                $0.foregroundColor = ConferenceSurfacePalette.textMain
            }
            var body = SkeletonText(url: URL(string: urlString)!)
            body.modifiers = modifier {
                $0.foregroundColor = ConferenceSurfacePalette.textMuted
                $0.fontSize = 11
                $0.lineLimit = 8
            }
            var section = SkeletonSection(header: .Text(header), content: [.Text(body)])
            section.modifiers = sectionCard
            return section
        }

        var eventTitle = SkeletonText(keypath: "title")
        eventTitle.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.textMain
        }
        var eventKeypath = SkeletonText(keypath: "content.keypath")
        eventKeypath.modifiers = modifier {
            $0.foregroundColor = ConferenceSurfacePalette.accentCool
            $0.fontSize = 11
        }
        var eventPayload = SkeletonText(keypath: "content.data")
        eventPayload.modifiers = modifier {
            $0.foregroundColor = ConferenceSurfacePalette.textMuted
            $0.fontSize = 11
            $0.lineLimit = 3
        }
        var eventRow = SkeletonVStack(elements: [.Text(eventTitle), .Text(eventKeypath), .Text(eventPayload)])
        eventRow.modifiers = sectionCard
        var eventList = SkeletonList(topic: "entity", keypath: nil, flowElementSkeleton: eventRow)
        eventList.filterTypes = ["content"]
        eventList.modifiers = listCard

        var hero = SkeletonVStack(elements: [
            .Text(title),
            .Text(subtitle),
            .Text(proofsChip),
            .HStack(SkeletonHStack(elements: [.Button(reloadStorage), .Button(clearEncounters)]))
        ])
        hero.modifiers = heroCard

        var eventsHeader = SkeletonText(text: "Entity updates")
        eventsHeader.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.textMain
        }
        var eventsSection = SkeletonSection(header: .Text(eventsHeader), content: [.List(eventList)])
        eventsSection.modifiers = sectionCard

        var root = SkeletonVStack(elements: [
            .VStack(hero),
            .Section(jsonText("Person", urlString: "cell:///EntityAnchor/person")),
            .Section(jsonText("Relations.identities", urlString: "cell:///EntityAnchor/relations.identities")),
            .Section(jsonText("Relations.issuers", urlString: "cell:///EntityAnchor/relations.issuers")),
            .Section(jsonText("Proofs.encounters", urlString: "cell:///EntityAnchor/proofs.encounters")),
            .Section(eventsSection)
        ])
        root.modifiers = card

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.background = ConferenceSurfacePalette.canvas
        }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func vaultWorkbenchConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Vault Control Surface")
        configuration.description = "Lokal kontrollflate for notater, linkede notater og state i VaultCell."
        configuration.addReference(CellReference(endpoint: "cell:///Vault", label: "vault"))

        let card = conferenceCardModifier(
            padding: 10,
            background: ConferenceSurfacePalette.shellMuted,
            borderColor: ConferenceSurfacePalette.stroke,
            cornerRadius: 18
        )
        let heroCard = conferenceCardModifier(
            padding: 12,
            background: ConferenceSurfacePalette.shellStrong,
            borderColor: ConferenceSurfacePalette.strokeStrong,
            cornerRadius: 20,
            shadowRadius: 10,
            shadowY: 3
        )
        let sectionCard = conferenceCardModifier(
            padding: 10,
            background: ConferenceSurfacePalette.shell,
            borderColor: ConferenceSurfacePalette.stroke,
            cornerRadius: 14
        )
        let listCard = modifier {
            $0.padding = 6
            $0.background = ConferenceSurfacePalette.shell
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = ConferenceSurfacePalette.stroke
            $0.height = 180
        }
        let primaryButton = conferenceButtonModifier(
            background: ConferenceSurfacePalette.accentWarmSoft,
            borderColor: ConferenceSurfacePalette.strokeStrong,
            foregroundColor: ConferenceSurfacePalette.textMain
        )
        let chipModifier = conferenceChipModifier(
            background: ConferenceSurfacePalette.accentCoolSoft,
            borderColor: ConferenceSurfacePalette.accentCoolBorder,
            foregroundColor: ConferenceSurfacePalette.textMain
        )

        let noteSeedA: Object = [
            "id": .string("conference-capture"),
            "title": .string("Conference Capture"),
            "content": .string("Notater fra konferansegulvet, folk aa folge opp og ting aa lese senere."),
            "tags": .list([.string("conference"), .string("notes")]),
            "createdAtEpochMs": .integer(0),
            "updatedAtEpochMs": .integer(0)
        ]
        let noteSeedB: Object = [
            "id": .string("follow-up-map"),
            "title": .string("Follow-up Map"),
            "content": .string("Neste steg, avtaler og lenker mellom notater som maa holdes samlet."),
            "tags": .list([.string("followup"), .string("networking")]),
            "createdAtEpochMs": .integer(0),
            "updatedAtEpochMs": .integer(0)
        ]

        var title = SkeletonText(text: "Vault Control Surface")
        title.modifiers = modifier {
            $0.fontStyle = "title2"
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.textMain
        }
        var subtitle = SkeletonText(text: "Seed lokale notater, koble dem sammen og les vault-state uten aa vaere avhengig av staging.")
        subtitle.modifiers = modifier {
            $0.foregroundColor = ConferenceSurfacePalette.textMuted
            $0.fontSize = 12
            $0.lineLimit = 3
        }
        var localChip = SkeletonText(text: "LOCAL NOTES")
        localChip.modifiers = chipModifier
        var noteCount = SkeletonText(url: URL(string: "cell:///Vault/vault.state.note_count")!)
        noteCount.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.accentWarm
            $0.fontSize = 18
        }
        var linkCount = SkeletonText(url: URL(string: "cell:///Vault/vault.state.link_count")!)
        linkCount.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.accentCool
            $0.fontSize = 18
        }

        var seedCapture = SkeletonButton(keypath: "vault.note.create", label: "Seed capture note", url: "cell:///Vault", payload: .object(noteSeedA))
        seedCapture.modifiers = primaryButton
        var seedFollowup = SkeletonButton(keypath: "vault.note.create", label: "Seed follow-up note", url: "cell:///Vault", payload: .object(noteSeedB))
        seedFollowup.modifiers = primaryButton
        var linkNotes = SkeletonButton(
            keypath: "vault.link.add",
            label: "Link notes",
            url: "cell:///Vault",
            payload: .object([
                "fromNoteID": .string("conference-capture"),
                "toNoteID": .string("follow-up-map"),
                "relationship": .string("followup"),
                "createdAtEpochMs": .integer(0)
            ])
        )
        linkNotes.modifiers = primaryButton

        var operationText = SkeletonText(keypath: "operation")
        operationText.modifiers = modifier {
            $0.foregroundColor = ConferenceSurfacePalette.textMain
            $0.fontSize = 12
        }
        var operationsList = SkeletonList(keypath: "cell:///Vault/vault.state.operations", flowElementSkeleton: SkeletonVStack(elements: [.Text(operationText)]))
        operationsList.modifiers = listCard

        var rawState = SkeletonText(url: URL(string: "cell:///Vault/vault.state")!)
        rawState.modifiers = modifier {
            $0.foregroundColor = ConferenceSurfacePalette.textMuted
            $0.fontSize = 11
            $0.lineLimit = 10
        }

        var operationsHeader = SkeletonText(text: "Supported operations")
        operationsHeader.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.textMain
        }
        var stateHeader = SkeletonText(text: "Vault state (JSON)")
        stateHeader.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.textMain
        }

        var hero = SkeletonVStack(elements: [
            .Text(title),
            .Text(subtitle),
            .Text(localChip),
            .HStack(SkeletonHStack(elements: [
                .VStack(SkeletonVStack(elements: [.Text(SkeletonText(text: "Notes")), .Text(noteCount)])),
                .VStack(SkeletonVStack(elements: [.Text(SkeletonText(text: "Links")), .Text(linkCount)]))
            ])),
            .HStack(SkeletonHStack(elements: [.Button(seedCapture), .Button(seedFollowup)])),
            .HStack(SkeletonHStack(elements: [.Button(linkNotes)]))
        ])
        hero.modifiers = heroCard

        var operationsSection = SkeletonSection(header: .Text(operationsHeader), content: [.List(operationsList)])
        operationsSection.modifiers = sectionCard
        var stateSection = SkeletonSection(header: .Text(stateHeader), content: [.Text(rawState)])
        stateSection.modifiers = sectionCard

        var root = SkeletonVStack(elements: [
            .VStack(hero),
            .Section(operationsSection),
            .Section(stateSection)
        ])
        root.modifiers = card

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.background = ConferenceSurfacePalette.canvas
        }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func trustedIssuersWorkbenchConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Trusted Issuers Registry")
        configuration.description = "Policy-, issuer- og attestation-workbench for trusted issuer-flyten."
        configuration.addReference(CellReference(endpoint: "cell:///TrustedIssuers", label: "trusted"))

        let card = conferenceCardModifier(
            padding: 10,
            background: ConferenceSurfacePalette.shellMuted,
            borderColor: ConferenceSurfacePalette.stroke,
            cornerRadius: 18
        )
        let heroCard = conferenceCardModifier(
            padding: 12,
            background: ConferenceSurfacePalette.shellStrong,
            borderColor: ConferenceSurfacePalette.strokeStrong,
            cornerRadius: 20,
            shadowRadius: 10,
            shadowY: 3
        )
        let sectionCard = conferenceCardModifier(
            padding: 10,
            background: ConferenceSurfacePalette.shell,
            borderColor: ConferenceSurfacePalette.stroke,
            cornerRadius: 14
        )
        let listCard = modifier {
            $0.padding = 6
            $0.background = ConferenceSurfacePalette.shell
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = ConferenceSurfacePalette.stroke
            $0.height = 200
        }
        let primaryButton = conferenceButtonModifier(
            background: ConferenceSurfacePalette.accentWarmSoft,
            borderColor: ConferenceSurfacePalette.strokeStrong,
            foregroundColor: ConferenceSurfacePalette.textMain
        )
        let secondaryButton = conferenceButtonModifier(
            background: ConferenceSurfacePalette.shellMuted,
            borderColor: ConferenceSurfacePalette.stroke,
            foregroundColor: ConferenceSurfacePalette.textMain
        )
        let chipModifier = conferenceChipModifier(
            background: ConferenceSurfacePalette.accentCoolSoft,
            borderColor: ConferenceSurfacePalette.accentCoolBorder,
            foregroundColor: ConferenceSurfacePalette.textMain
        )

        let seededContextId = "conference.access"
        let seededIssuerId = "did:key:conference-host"

        var title = SkeletonText(text: "Trusted Issuers Registry")
        title.modifiers = modifier {
            $0.fontStyle = "title2"
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.textMain
        }
        var subtitle = SkeletonText(text: "Vedlikehold policy, issuers og attestations for credential-verifikasjon. Denne flaten er lokal og idempotent for seed-data.")
        subtitle.modifiers = modifier {
            $0.foregroundColor = ConferenceSurfacePalette.textMuted
            $0.fontSize = 12
            $0.lineLimit = 3
        }
        var trustChip = SkeletonText(text: "LOCAL TRUST POLICY")
        trustChip.modifiers = chipModifier
        var policyCount = SkeletonText(url: URL(string: "cell:///TrustedIssuers/trustedIssuers.state.policyCount")!)
        policyCount.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.accentCool
            $0.fontSize = 18
        }
        var issuerCount = SkeletonText(url: URL(string: "cell:///TrustedIssuers/trustedIssuers.state.issuerCount")!)
        issuerCount.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.accentWarm
            $0.fontSize = 18
        }
        var attestationCount = SkeletonText(url: URL(string: "cell:///TrustedIssuers/trustedIssuers.state.attestationCount")!)
        attestationCount.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.strokeStrong
            $0.fontSize = 18
        }

        var seedPolicy = SkeletonButton(
            keypath: "trustedIssuers.policy.upsert",
            label: "Seed policy",
            url: "cell:///TrustedIssuers",
            payload: .object([
                "contextId": .string(seededContextId),
                "displayName": .string("Conference Access"),
                "threshold": .float(0.55),
                "requireRevocationCheck": .bool(false),
                "requireSubjectBinding": .bool(false),
                "requireIndependentSources": .integer(0),
                "maxGraphDepth": .integer(2),
                "acceptedIssuerKinds": .list([.string("institution")]),
                "acceptedDidMethods": .list([.string("did:key")]),
                "timeDecayHalfLifeDays": .float(180),
                "status": .string("active")
            ])
        )
        seedPolicy.modifiers = primaryButton

        var seedIssuer = SkeletonButton(
            keypath: "trustedIssuers.issuer.upsert",
            label: "Seed issuer",
            url: "cell:///TrustedIssuers",
            payload: .object([
                "issuerId": .string(seededIssuerId),
                "displayName": .string("Conference Host"),
                "issuerKind": .string("institution"),
                "baseWeight": .float(0.82),
                "contexts": .list([.string(seededContextId)]),
                "metadata": .object(["role": .string("organizer")]),
                "status": .string("active")
            ])
        )
        seedIssuer.modifiers = primaryButton

        var seedAttestation = SkeletonButton(
            keypath: "trustedIssuers.attestation.publish",
            label: "Publish attestation",
            url: "cell:///TrustedIssuers",
            payload: .object([
                "attestationId": .string("seed-conference-endorsement"),
                "subjectIssuerId": .string(seededIssuerId),
                "contextId": .string(seededContextId),
                "statement": .string("trusted_for_context"),
                "weight": .float(0.35),
                "scope": .string("public"),
                "issuer": .string("did:key:peer-endorser")
            ])
        )
        seedAttestation.modifiers = primaryButton

        var removeIssuer = SkeletonButton(
            keypath: "trustedIssuers.issuer.delete",
            label: "Remove issuer",
            url: "cell:///TrustedIssuers",
            payload: .object(["issuerId": .string(seededIssuerId)])
        )
        removeIssuer.modifiers = secondaryButton

        var removePolicy = SkeletonButton(
            keypath: "trustedIssuers.policy.delete",
            label: "Remove policy",
            url: "cell:///TrustedIssuers",
            payload: .object(["contextId": .string(seededContextId)])
        )
        removePolicy.modifiers = secondaryButton

        func makeListRow(_ fields: [String]) -> SkeletonVStack {
            let elements = fields.map { field -> SkeletonElement in
                var text = SkeletonText(keypath: field)
                text.modifiers = modifier {
                    $0.foregroundColor = field == fields.first ? ConferenceSurfacePalette.textMain : ConferenceSurfacePalette.textMuted
                    $0.fontWeight = field == fields.first ? "semibold" : "regular"
                    $0.fontSize = field == fields.first ? 13 : 11
                    $0.lineLimit = 2
                }
                return .Text(text)
            }
            var row = SkeletonVStack(elements: elements)
            row.modifiers = sectionCard
            return row
        }

        var policiesList = SkeletonList(keypath: "cell:///TrustedIssuers/trustedIssuers.policies", flowElementSkeleton: makeListRow(["displayName", "contextId", "threshold", "status"]))
        policiesList.modifiers = listCard

        var issuersList = SkeletonList(keypath: "cell:///TrustedIssuers/trustedIssuers.issuers", flowElementSkeleton: makeListRow(["displayName", "issuerId", "issuerKind", "baseWeight", "status"]))
        issuersList.modifiers = listCard

        var attestationList = SkeletonList(keypath: "cell:///TrustedIssuers/trustedIssuers.attestations", flowElementSkeleton: makeListRow(["subjectIssuerId", "contextId", "issuer", "weight", "status"]))
        attestationList.modifiers = listCard

        var evaluationList = SkeletonList(keypath: "cell:///TrustedIssuers/trustedIssuers.evaluations.current", flowElementSkeleton: makeListRow(["issuerId", "contextId", "decision", "score", "reasons"]))
        evaluationList.modifiers = listCard

        var rawStateHeader = SkeletonText(text: "Registry state (JSON)")
        rawStateHeader.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.textMain
        }
        var rawState = SkeletonText(url: URL(string: "cell:///TrustedIssuers/trustedIssuers.state")!)
        rawState.modifiers = modifier {
            $0.foregroundColor = ConferenceSurfacePalette.textMuted
            $0.fontSize = 11
            $0.lineLimit = 8
        }

        var hero = SkeletonVStack(elements: [
            .Text(title),
            .Text(subtitle),
            .Text(trustChip),
            .HStack(SkeletonHStack(elements: [
                .VStack(SkeletonVStack(elements: [.Text(SkeletonText(text: "Policies")), .Text(policyCount)])),
                .VStack(SkeletonVStack(elements: [.Text(SkeletonText(text: "Issuers")), .Text(issuerCount)])),
                .VStack(SkeletonVStack(elements: [.Text(SkeletonText(text: "Attestations")), .Text(attestationCount)]))
            ])),
            .HStack(SkeletonHStack(elements: [.Button(seedPolicy), .Button(seedIssuer), .Button(seedAttestation)])),
            .HStack(SkeletonHStack(elements: [.Button(removeIssuer), .Button(removePolicy)]))
        ])
        hero.modifiers = heroCard

        func listSection(_ title: String, list: SkeletonList) -> SkeletonSection {
            var header = SkeletonText(text: title)
            header.modifiers = modifier {
                $0.fontWeight = "semibold"
                $0.foregroundColor = ConferenceSurfacePalette.textMain
            }
            var section = SkeletonSection(header: .Text(header), content: [.List(list)])
            section.modifiers = sectionCard
            return section
        }

        var rawStateSection = SkeletonSection(header: .Text(rawStateHeader), content: [.Text(rawState)])
        rawStateSection.modifiers = sectionCard

        var root = SkeletonVStack(elements: [
            .VStack(hero),
            .Section(listSection("Policies", list: policiesList)),
            .Section(listSection("Issuers", list: issuersList)),
            .Section(listSection("Attestations", list: attestationList)),
            .Section(listSection("Current evaluations", list: evaluationList)),
            .Section(rawStateSection)
        ])
        root.modifiers = card

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.background = ConferenceSurfacePalette.canvas
        }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func commonsResolverWorkbenchConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Commons Resolver Control")
        configuration.description = "Inspeksjon av commons-resolver, sample keypath requests og registrerte operations."
        configuration.addReference(CellReference(endpoint: "cell:///CommonsResolver", label: "commons"))

        let card = modifier {
            $0.padding = 10
            $0.background = "#F8FAFC"
            $0.cornerRadius = 16
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }
        let heroCard = modifier {
            $0.padding = 12
            $0.background = "#EFF6FF"
            $0.cornerRadius = 16
            $0.borderWidth = 1
            $0.borderColor = "#60A5FA"
        }
        let sectionCard = modifier {
            $0.padding = 10
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#D7E0F0"
        }
        let listCard = modifier {
            $0.padding = 6
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#D7E0F0"
            $0.height = 190
        }

        var title = SkeletonText(text: "Commons Resolver Control")
        title.modifiers = modifier {
            $0.fontStyle = "title2"
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }
        var subtitle = SkeletonText(text: "Se commons-root, registrerte keypaths og dokumenterte sample-requests. Dette er en lokal inspeksjonsflate for resolver-laget.")
        subtitle.modifiers = modifier {
            $0.foregroundColor = "#1D4ED8"
            $0.fontSize = 12
            $0.lineLimit = 3
        }
        var serviceLoaded = SkeletonText(url: URL(string: "cell:///CommonsResolver/commons.status.service_loaded")!)
        serviceLoaded.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#1D4ED8"
            $0.fontSize = 18
        }
        var keypathCount = SkeletonText(url: URL(string: "cell:///CommonsResolver/commons.status.registered_keypaths_count")!)
        keypathCount.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F766E"
            $0.fontSize = 18
        }
        var routeCount = SkeletonText(url: URL(string: "cell:///CommonsResolver/commons.status.registered_routes_count")!)
        routeCount.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F766E"
            $0.fontSize = 18
        }
        var rootPath = SkeletonText(url: URL(string: "cell:///CommonsResolver/commons.status.commons_root_path")!)
        rootPath.modifiers = modifier {
            $0.foregroundColor = "#475569"
            $0.fontSize = 11
            $0.lineLimit = 2
        }
        var rawState = SkeletonText(url: URL(string: "cell:///CommonsResolver/commons.status")!)
        rawState.modifiers = modifier {
            $0.foregroundColor = "#334155"
            $0.fontSize = 11
            $0.lineLimit = 8
        }

        var operationRowText = SkeletonText(keypath: "operation")
        operationRowText.modifiers = modifier {
            $0.foregroundColor = "#1E3A8A"
            $0.fontSize = 12
        }
        var operationList = SkeletonList(
            keypath: "cell:///CommonsResolver/commons.status.operations",
            flowElementSkeleton: SkeletonVStack(elements: [.Text(operationRowText)])
        )
        operationList.modifiers = listCard

        var sampleEntity = SkeletonText(keypath: "entity_id")
        sampleEntity.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
            $0.fontSize = 12
        }
        var samplePath = SkeletonText(keypath: "path")
        samplePath.modifiers = modifier {
            $0.foregroundColor = "#1D4ED8"
            $0.fontSize = 11
            $0.lineLimit = 2
        }
        var sampleRole = SkeletonText(keypath: "context.role")
        sampleRole.modifiers = modifier {
            $0.foregroundColor = "#475569"
            $0.fontSize = 11
        }
        var sampleRow = SkeletonVStack(elements: [.Text(sampleEntity), .Text(samplePath), .Text(sampleRole)])
        sampleRow.modifiers = sectionCard
        var sampleList = SkeletonList(
            keypath: "cell:///CommonsResolver/commons.samples.keypathRequests.items",
            flowElementSkeleton: sampleRow
        )
        sampleList.modifiers = listCard

        var operationsHeader = SkeletonText(text: "Resolver operations")
        operationsHeader.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }
        var samplesHeader = SkeletonText(text: "Sample keypath requests")
        samplesHeader.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }
        var stateHeader = SkeletonText(text: "Status (JSON)")
        stateHeader.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var hero = SkeletonVStack(elements: [
            .Text(title),
            .Text(subtitle),
            .Text(rootPath),
            .HStack(SkeletonHStack(elements: [
                .VStack(SkeletonVStack(elements: [.Text(SkeletonText(text: "Service loaded")), .Text(serviceLoaded)])),
                .VStack(SkeletonVStack(elements: [.Text(SkeletonText(text: "Keypaths")), .Text(keypathCount)])),
                .VStack(SkeletonVStack(elements: [.Text(SkeletonText(text: "Routes")), .Text(routeCount)]))
            ]))
        ])
        hero.modifiers = heroCard

        var operationsSection = SkeletonSection(header: .Text(operationsHeader), content: [.List(operationList)])
        operationsSection.modifiers = sectionCard
        var samplesSection = SkeletonSection(header: .Text(samplesHeader), content: [.List(sampleList)])
        samplesSection.modifiers = sectionCard
        var stateSection = SkeletonSection(header: .Text(stateHeader), content: [.Text(rawState)])
        stateSection.modifiers = sectionCard

        var root = SkeletonVStack(elements: [
            .VStack(hero),
            .Section(operationsSection),
            .Section(samplesSection),
            .Section(stateSection)
        ])
        root.modifiers = card

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.background = "#F8FAFC"
        }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func commonsTaxonomyWorkbenchConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Commons Taxonomy Browser")
        configuration.description = "Inspeksjon av taxonomy-resolver, sample term requests og namespace guidance."
        configuration.addReference(CellReference(endpoint: "cell:///CommonsTaxonomy", label: "taxonomy"))

        let card = modifier {
            $0.padding = 10
            $0.background = "#F8FAFC"
            $0.cornerRadius = 16
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }
        let heroCard = modifier {
            $0.padding = 12
            $0.background = "#F5F3FF"
            $0.cornerRadius = 16
            $0.borderWidth = 1
            $0.borderColor = "#A78BFA"
        }
        let sectionCard = modifier {
            $0.padding = 10
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#DDD6FE"
        }
        let listCard = modifier {
            $0.padding = 6
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#DDD6FE"
            $0.height = 200
        }

        var title = SkeletonText(text: "Commons Taxonomy Browser")
        title.modifiers = modifier {
            $0.fontStyle = "title2"
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }
        var subtitle = SkeletonText(text: "Se taxonomy-pakker, sample term requests og guidance/validation payloads for commons-taxonomien.")
        subtitle.modifiers = modifier {
            $0.foregroundColor = "#6D28D9"
            $0.fontSize = 12
            $0.lineLimit = 3
        }
        var serviceLoaded = SkeletonText(url: URL(string: "cell:///CommonsTaxonomy/taxonomy.status.service_loaded")!)
        serviceLoaded.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#6D28D9"
            $0.fontSize = 18
        }
        var packageCount = SkeletonText(url: URL(string: "cell:///CommonsTaxonomy/taxonomy.status.taxonomy_packages")!)
        packageCount.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#7C3AED"
            $0.fontSize = 18
        }
        var rootPath = SkeletonText(url: URL(string: "cell:///CommonsTaxonomy/taxonomy.status.commons_root_path")!)
        rootPath.modifiers = modifier {
            $0.foregroundColor = "#475569"
            $0.fontSize = 11
            $0.lineLimit = 2
        }
        var rawState = SkeletonText(url: URL(string: "cell:///CommonsTaxonomy/taxonomy.status")!)
        rawState.modifiers = modifier {
            $0.foregroundColor = "#334155"
            $0.fontSize = 11
            $0.lineLimit = 8
        }

        var operationRowText = SkeletonText(keypath: "operation")
        operationRowText.modifiers = modifier {
            $0.foregroundColor = "#6D28D9"
            $0.fontSize = 12
        }
        var operationList = SkeletonList(
            keypath: "cell:///CommonsTaxonomy/taxonomy.status.operations",
            flowElementSkeleton: SkeletonVStack(elements: [.Text(operationRowText)])
        )
        operationList.modifiers = listCard

        var sampleTerm = SkeletonText(keypath: "term_id")
        sampleTerm.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
            $0.fontSize = 12
        }
        var sampleNamespace = SkeletonText(keypath: "namespace")
        sampleNamespace.modifiers = modifier {
            $0.foregroundColor = "#6D28D9"
            $0.fontSize = 11
        }
        var sampleMode = SkeletonText(keypath: "mode")
        sampleMode.modifiers = modifier {
            $0.foregroundColor = "#475569"
            $0.fontSize = 11
        }
        var sampleLang = SkeletonText(keypath: "lang")
        sampleLang.modifiers = modifier {
            $0.foregroundColor = "#475569"
            $0.fontSize = 11
        }
        var sampleRow = SkeletonVStack(elements: [.Text(sampleTerm), .Text(sampleNamespace), .Text(sampleMode), .Text(sampleLang)])
        sampleRow.modifiers = sectionCard
        var sampleList = SkeletonList(
            keypath: "cell:///CommonsTaxonomy/taxonomy.samples.termRequests.items",
            flowElementSkeleton: sampleRow
        )
        sampleList.modifiers = listCard

        var operationsHeader = SkeletonText(text: "Taxonomy operations")
        operationsHeader.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }
        var samplesHeader = SkeletonText(text: "Sample term/guidance requests")
        samplesHeader.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }
        var stateHeader = SkeletonText(text: "Status (JSON)")
        stateHeader.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var hero = SkeletonVStack(elements: [
            .Text(title),
            .Text(subtitle),
            .Text(rootPath),
            .HStack(SkeletonHStack(elements: [
                .VStack(SkeletonVStack(elements: [.Text(SkeletonText(text: "Service loaded")), .Text(serviceLoaded)])),
                .VStack(SkeletonVStack(elements: [.Text(SkeletonText(text: "Packages")), .Text(packageCount)]))
            ]))
        ])
        hero.modifiers = heroCard

        var operationsSection = SkeletonSection(header: .Text(operationsHeader), content: [.List(operationList)])
        operationsSection.modifiers = sectionCard
        var samplesSection = SkeletonSection(header: .Text(samplesHeader), content: [.List(sampleList)])
        samplesSection.modifiers = sectionCard
        var stateSection = SkeletonSection(header: .Text(stateHeader), content: [.Text(rawState)])
        stateSection.modifiers = sectionCard

        var root = SkeletonVStack(elements: [
            .VStack(hero),
            .Section(operationsSection),
            .Section(samplesSection),
            .Section(stateSection)
        ])
        root.modifiers = card

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.background = "#F5F3FF"
        }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func portholeWorkbenchConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Porthole Control Surface")
        configuration.description = "Last nyttige kontrollflater inn i Porthole, se tilgjengelige menyer og inspiser historikken for tidligere layouts."
        configuration.addReference(CellReference(endpoint: "cell:///Porthole", label: "porthole"))

        let card = conferenceCardModifier(
            padding: 10,
            background: ConferenceSurfacePalette.shellMuted,
            borderColor: ConferenceSurfacePalette.stroke,
            cornerRadius: 18
        )
        let heroCard = conferenceCardModifier(
            padding: 12,
            background: ConferenceSurfacePalette.shellStrong,
            borderColor: ConferenceSurfacePalette.accentCoolBorder,
            cornerRadius: 20,
            shadowRadius: 10,
            shadowY: 3
        )
        let sectionCard = conferenceCardModifier(
            padding: 10,
            background: ConferenceSurfacePalette.shell,
            borderColor: ConferenceSurfacePalette.stroke,
            cornerRadius: 14
        )
        let listCard = modifier {
            $0.padding = 6
            $0.background = ConferenceSurfacePalette.shell
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = ConferenceSurfacePalette.stroke
            $0.height = 180
        }
        let primaryButton = conferenceButtonModifier(
            background: ConferenceSurfacePalette.accentCoolSoft,
            borderColor: ConferenceSurfacePalette.accentCoolBorder,
            foregroundColor: ConferenceSurfacePalette.textMain
        )
        let neutralButton = conferenceButtonModifier(
            background: ConferenceSurfacePalette.accentWarmSoft,
            borderColor: ConferenceSurfacePalette.strokeStrong,
            foregroundColor: ConferenceSurfacePalette.textMain
        )
        let chipModifier = conferenceChipModifier(
            background: ConferenceSurfacePalette.accentCoolSoft,
            borderColor: ConferenceSurfacePalette.accentCoolBorder,
            foregroundColor: ConferenceSurfacePalette.textMain
        )

        let appleConfig = appleIntelligenceLandingConfiguration()
        let scannerConfig = entityScannerWorkbenchConfiguration()
        let perspectiveConfig = perspectiveWorkbenchConfiguration()
        let catalogConfig = catalogWorkbenchConfiguration()

        func header(_ text: String) -> SkeletonText {
            var label = SkeletonText(text: text)
            label.modifiers = modifier {
                $0.fontWeight = "semibold"
                $0.foregroundColor = ConferenceSurfacePalette.textMain
                $0.fontSize = 12
            }
            return label
        }

        var title = SkeletonText(text: "Porthole Control Surface")
        title.modifiers = modifier {
            $0.fontStyle = "title2"
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.textMain
        }
        var subtitle = SkeletonText(text: "Bytt raskt mellom viktige control surfaces og se hva Porthole selv eksponerer som outward menu og historikk.")
        subtitle.modifiers = modifier {
            $0.foregroundColor = ConferenceSurfacePalette.textMuted
            $0.fontSize = 12
            $0.lineLimit = 3
        }
        var controlChip = SkeletonText(text: "OPERATOR PORTHOLE")
        controlChip.modifiers = chipModifier
        var connectedEmitters = SkeletonText(url: URL(string: "cell:///Porthole/connectedCellEmitters")!)
        connectedEmitters.modifiers = modifier {
            $0.foregroundColor = ConferenceSurfacePalette.textMuted
            $0.fontSize = 11
            $0.lineLimit = 6
        }

        var loadAI = SkeletonButton(keypath: "porthole.setConfiguration", label: "Load Apple Intelligence", payload: .cellConfiguration(appleConfig))
        loadAI.modifiers = primaryButton
        var loadScanner = SkeletonButton(keypath: "porthole.setConfiguration", label: "Load Entity Scanner", payload: .cellConfiguration(scannerConfig))
        loadScanner.modifiers = primaryButton
        var loadPerspective = SkeletonButton(keypath: "porthole.setConfiguration", label: "Load Perspective", payload: .cellConfiguration(perspectiveConfig))
        loadPerspective.modifiers = neutralButton
        var loadCatalog = SkeletonButton(keypath: "porthole.setConfiguration", label: "Load Catalog", payload: .cellConfiguration(catalogConfig))
        loadCatalog.modifiers = neutralButton

        var configName = SkeletonText(keypath: "name")
        configName.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.textMain
        }
        var configDescription = SkeletonText(keypath: "description")
        configDescription.modifiers = modifier {
            $0.foregroundColor = ConferenceSurfacePalette.textMuted
            $0.fontSize = 11
            $0.lineLimit = 2
        }
        var configRow = SkeletonVStack(elements: [.Text(configName), .Text(configDescription)])
        configRow.modifiers = sectionCard

        var outwardMenu = SkeletonList(keypath: "cell:///Porthole/outwardMenu", flowElementSkeleton: configRow)
        outwardMenu.modifiers = listCard

        var historyMenu = SkeletonList(keypath: "cell:///Porthole/historyMenu", flowElementSkeleton: configRow)
        historyMenu.modifiers = listCard

        var eventTitle = SkeletonText(keypath: "title")
        eventTitle.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = ConferenceSurfacePalette.textMain
            $0.fontSize = 12
        }
        var eventBody = SkeletonText(keypath: "content")
        eventBody.modifiers = modifier {
            $0.foregroundColor = ConferenceSurfacePalette.textMuted
            $0.fontSize = 11
            $0.lineLimit = 2
        }
        var eventRow = SkeletonVStack(elements: [.Text(eventTitle), .Text(eventBody)])
        eventRow.modifiers = sectionCard
        var eventList = SkeletonList(topic: "porthole", keypath: nil, flowElementSkeleton: eventRow)
        eventList.filterTypes = ["event"]
        eventList.modifiers = listCard

        var hero = SkeletonVStack(elements: [
            .Text(title),
            .Text(subtitle),
            .Text(controlChip),
            .Text(header("Connected emitters (raw)")),
            .Text(connectedEmitters),
            .HStack(SkeletonHStack(elements: [.Button(loadAI), .Button(loadScanner)])),
            .HStack(SkeletonHStack(elements: [.Button(loadPerspective), .Button(loadCatalog)]))
        ])
        hero.modifiers = heroCard

        var outwardSection = SkeletonSection(header: .Text(header("Outward menu fra Porthole")), content: [.List(outwardMenu)])
        outwardSection.modifiers = sectionCard
        var historySection = SkeletonSection(header: .Text(header("Tidligere layouts")), content: [.List(historyMenu)])
        historySection.modifiers = sectionCard
        var eventsSection = SkeletonSection(header: .Text(header("Porthole events")), content: [.List(eventList)])
        eventsSection.modifiers = sectionCard

        var root = SkeletonVStack(elements: [
            .VStack(hero),
            .Section(outwardSection),
            .Section(historySection),
            .Section(eventsSection)
        ])
        root.modifiers = card

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.background = ConferenceSurfacePalette.canvas
        }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func folderWatchWorkbenchConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Folder Watch Automation")
        configuration.description = "Konfigurer mappeovervaking, start eller stopp watcheren, og se siste filesystem-events direkte i UI."
        configuration.addReference(CellReference(endpoint: "cell:///FolderWatch", label: "watch"))

        let card = modifier {
            $0.padding = 10
            $0.background = "#F7FEE7"
            $0.cornerRadius = 16
            $0.borderWidth = 1
            $0.borderColor = "#D9F99D"
        }
        let heroCard = modifier {
            $0.padding = 12
            $0.background = "#ECFCCB"
            $0.cornerRadius = 16
            $0.borderWidth = 1
            $0.borderColor = "#84CC16"
        }
        let sectionCard = modifier {
            $0.padding = 10
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#D9E7B5"
        }
        let listCard = modifier {
            $0.padding = 6
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#D9E7B5"
            $0.height = 180
        }
        let inputModifier = modifier {
            $0.padding = 7
            $0.background = "#FFFFFF"
            $0.cornerRadius = 8
            $0.borderWidth = 1
            $0.borderColor = "#C8D5A1"
        }
        let primaryButton = modifier {
            $0.padding = 6
            $0.background = "#DCFCE7"
            $0.borderWidth = 1
            $0.borderColor = "#4ADE80"
            $0.cornerRadius = 8
        }
        let neutralButton = modifier {
            $0.padding = 6
            $0.background = "#F1F5F9"
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
            $0.cornerRadius = 8
        }

        let defaultEvents: ValueType = .list([
            .string("write"),
            .string("delete"),
            .string("rename"),
            .string("attrib")
        ])

        func header(_ text: String) -> SkeletonText {
            var label = SkeletonText(text: text)
            label.modifiers = modifier {
                $0.fontWeight = "semibold"
                $0.foregroundColor = "#0F172A"
                $0.fontSize = 12
            }
            return label
        }

        var title = SkeletonText(text: "Folder Watch Automation")
        title.modifiers = modifier {
            $0.fontStyle = "title2"
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }
        var subtitle = SkeletonText(text: "Overvaak en lokal mappe og send filesystem-events som flow. Standardtopic holdes paa `filesystem.watch` slik at listen under er nyttig uten ekstra oppsett.")
        subtitle.modifiers = modifier {
            $0.foregroundColor = "#3F6212"
            $0.fontSize = 12
            $0.lineLimit = 3
        }

        let pathField = SkeletonTextField(
            text: nil,
            sourceKeypath: "watch.state.path",
            targetKeypath: "watch.configure",
            placeholder: "Skriv path, f.eks. ~/Documents",
            modifiers: inputModifier
        )

        var useDocuments = SkeletonButton(
            keypath: "watch.configure",
            label: "Use ~/Documents",
            payload: .object([
                "path": .string("~/Documents"),
                "topic": .string("filesystem.watch"),
                "events": defaultEvents
            ])
        )
        useDocuments.modifiers = neutralButton

        var useLibrary = SkeletonButton(
            keypath: "watch.configure",
            label: "Use ~/Library",
            payload: .object([
                "path": .string("~/Library"),
                "topic": .string("filesystem.watch"),
                "events": defaultEvents
            ])
        )
        useLibrary.modifiers = neutralButton

        var startWatching = SkeletonButton(keypath: "watch.start", label: "Start watch", payload: .null)
        startWatching.modifiers = primaryButton
        var stopWatching = SkeletonButton(keypath: "watch.stop", label: "Stop", payload: .bool(true))
        stopWatching.modifiers = neutralButton

        var running = SkeletonText(keypath: "watch.state.running")
        running.modifiers = modifier {
            $0.foregroundColor = "#166534"
            $0.fontWeight = "semibold"
            $0.fontSize = 18
        }
        var configuredPath = SkeletonText(keypath: "watch.state.path")
        configuredPath.modifiers = modifier {
            $0.foregroundColor = "#334155"
            $0.fontSize = 11
            $0.lineLimit = 2
        }
        var configuredTopic = SkeletonText(keypath: "watch.state.topic")
        configuredTopic.modifiers = modifier {
            $0.foregroundColor = "#3F6212"
            $0.fontSize = 11
        }
        var configuredEvents = SkeletonText(keypath: "watch.state.events")
        configuredEvents.modifiers = modifier {
            $0.foregroundColor = "#475569"
            $0.fontSize = 11
            $0.lineLimit = 2
        }
        var lastEventAt = SkeletonText(keypath: "watch.state.lastEventAt")
        lastEventAt.modifiers = modifier {
            $0.foregroundColor = "#475569"
            $0.fontSize = 11
        }
        var lastEventRaw = SkeletonText(keypath: "watch.state.lastEvent")
        lastEventRaw.modifiers = modifier {
            $0.foregroundColor = "#334155"
            $0.fontSize = 11
            $0.lineLimit = 6
        }

        var eventPath = SkeletonText(keypath: "content.path")
        eventPath.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
            $0.fontSize = 12
        }
        var eventFlags = SkeletonText(keypath: "content.events")
        eventFlags.modifiers = modifier {
            $0.foregroundColor = "#3F6212"
            $0.fontSize = 11
        }
        var eventDiff = SkeletonText(keypath: "content.modified")
        eventDiff.modifiers = modifier {
            $0.foregroundColor = "#475569"
            $0.fontSize = 11
            $0.lineLimit = 2
        }
        var eventRow = SkeletonVStack(elements: [.Text(eventPath), .Text(eventFlags), .Text(eventDiff)])
        eventRow.modifiers = sectionCard
        var eventList = SkeletonList(topic: "filesystem.watch", keypath: nil, flowElementSkeleton: eventRow)
        eventList.filterTypes = ["event"]
        eventList.modifiers = listCard

        var hero = SkeletonVStack(elements: [
            .Text(title),
            .Text(subtitle),
            .TextField(pathField),
            .HStack(SkeletonHStack(elements: [.Button(useDocuments), .Button(useLibrary)])),
            .HStack(SkeletonHStack(elements: [.Button(startWatching), .Button(stopWatching)]))
        ])
        hero.modifiers = heroCard

        var stateSection = SkeletonSection(
            header: .Text(header("Watch state")),
            content: [
                .Text(header("Running")),
                .Text(running),
                .Text(configuredPath),
                .Text(configuredTopic),
                .Text(configuredEvents),
                .Text(lastEventAt),
                .Text(lastEventRaw)
            ]
        )
        stateSection.modifiers = sectionCard

        var eventsSection = SkeletonSection(header: .Text(header("Incoming filesystem events")), content: [.List(eventList)])
        eventsSection.modifiers = sectionCard

        var root = SkeletonVStack(elements: [
            .VStack(hero),
            .Section(stateSection),
            .Section(eventsSection)
        ])
        root.modifiers = card

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.background = "#F7FEE7"
        }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func graphIndexWorkbenchConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Graph Index Control")
        configuration.description = "Reindex en demo-graf fra notater og bruk graf-operasjonene for outgoing, incoming og neighbors."
        configuration.addReference(CellReference(endpoint: "cell:///GraphIndex", label: "graph"))

        let card = modifier {
            $0.padding = 10
            $0.background = "#F0F9FF"
            $0.cornerRadius = 16
            $0.borderWidth = 1
            $0.borderColor = "#BAE6FD"
        }
        let heroCard = modifier {
            $0.padding = 12
            $0.background = "#E0F2FE"
            $0.cornerRadius = 16
            $0.borderWidth = 1
            $0.borderColor = "#38BDF8"
        }
        let sectionCard = modifier {
            $0.padding = 10
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#D5E6F6"
        }
        let listCard = modifier {
            $0.padding = 6
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#D5E6F6"
            $0.height = 140
        }
        let primaryButton = modifier {
            $0.padding = 6
            $0.background = "#E0F2FE"
            $0.borderWidth = 1
            $0.borderColor = "#38BDF8"
            $0.cornerRadius = 8
        }
        let neutralButton = modifier {
            $0.padding = 6
            $0.background = "#F1F5F9"
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
            $0.cornerRadius = 8
        }

        let demoNotes: ValueType = .object([
            "notes": .list([
                .object([
                    "id": .string("Home"),
                    "content": .string("Links to [[Scanner]] and [[Trust]].")
                ]),
                .object([
                    "id": .string("Scanner"),
                    "content": .string("Nearby discovery links back to [[Home]] and relates to [[Trust]].")
                ]),
                .object([
                    "id": .string("Trust"),
                    "content": .string("Verification note linked from [[Home]].")
                ])
            ])
        ])

        func header(_ text: String) -> SkeletonText {
            var label = SkeletonText(text: text)
            label.modifiers = modifier {
                $0.fontWeight = "semibold"
                $0.foregroundColor = "#0F172A"
                $0.fontSize = 12
            }
            return label
        }

        var title = SkeletonText(text: "Graph Index Control")
        title.modifiers = modifier {
            $0.fontStyle = "title2"
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }
        var subtitle = SkeletonText(text: "Bygg en liten demo-graf fra tre notater. Etter reindex er `Home`, `Scanner` og `Trust` gyldige noder for query-knappene.")
        subtitle.modifiers = modifier {
            $0.foregroundColor = "#0369A1"
            $0.fontSize = 12
            $0.lineLimit = 3
        }
        var nodeCount = SkeletonText(keypath: "graph.state.node_count")
        nodeCount.modifiers = modifier {
            $0.foregroundColor = "#0369A1"
            $0.fontWeight = "semibold"
            $0.fontSize = 18
        }
        var edgeCount = SkeletonText(keypath: "graph.state.edge_count")
        edgeCount.modifiers = modifier {
            $0.foregroundColor = "#0284C7"
            $0.fontWeight = "semibold"
            $0.fontSize = 18
        }
        var rawState = SkeletonText(url: URL(string: "cell:///GraphIndex/graph.state")!)
        rawState.modifiers = modifier {
            $0.foregroundColor = "#334155"
            $0.fontSize = 11
            $0.lineLimit = 8
        }

        var reindexDemo = SkeletonButton(keypath: "graph.reindex", label: "Reindex demo graph", payload: demoNotes)
        reindexDemo.modifiers = primaryButton
        var clearGraph = SkeletonButton(keypath: "graph.reindex", label: "Clear graph", payload: .object(["notes": .list([])]))
        clearGraph.modifiers = neutralButton

        var queryOutgoing = SkeletonButton(keypath: "graph.outgoing", label: "Outgoing from Home", payload: .string("Home"))
        queryOutgoing.modifiers = neutralButton
        var queryIncoming = SkeletonButton(keypath: "graph.incoming", label: "Incoming to Scanner", payload: .string("Scanner"))
        queryIncoming.modifiers = neutralButton
        var queryNeighbors = SkeletonButton(keypath: "graph.neighbors", label: "Neighbors of Trust", payload: .string("Trust"))
        queryNeighbors.modifiers = neutralButton

        var operationText = SkeletonText(keypath: ".")
        operationText.modifiers = modifier {
            $0.foregroundColor = "#0369A1"
            $0.fontSize = 12
        }
        var operationsList = SkeletonList(keypath: "graph.state.operations", flowElementSkeleton: SkeletonVStack(elements: [.Text(operationText)]))
        operationsList.modifiers = listCard

        var hero = SkeletonVStack(elements: [
            .Text(title),
            .Text(subtitle),
            .HStack(SkeletonHStack(elements: [
                .VStack(SkeletonVStack(elements: [.Text(header("Nodes")), .Text(nodeCount)])),
                .VStack(SkeletonVStack(elements: [.Text(header("Edges")), .Text(edgeCount)]))
            ])),
            .HStack(SkeletonHStack(elements: [.Button(reindexDemo), .Button(clearGraph)])),
            .HStack(SkeletonHStack(elements: [.Button(queryOutgoing), .Button(queryIncoming)])),
            .HStack(SkeletonHStack(elements: [.Button(queryNeighbors)]))
        ])
        hero.modifiers = heroCard

        var operationsSection = SkeletonSection(header: .Text(header("Supported graph operations")), content: [.List(operationsList)])
        operationsSection.modifiers = sectionCard
        var stateSection = SkeletonSection(header: .Text(header("Graph state (JSON)")), content: [.Text(rawState)])
        stateSection.modifiers = sectionCard

        var root = SkeletonVStack(elements: [
            .VStack(hero),
            .Section(operationsSection),
            .Section(stateSection)
        ])
        root.modifiers = card

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.background = "#F0F9FF"
        }
        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func referenceCardConfiguration(
        name: String,
        endpoint: String,
        label: String,
        title: String,
        subtitle: String,
        chip: String,
        borderColor: String,
        startKey: String? = nil
    ) -> CellConfiguration {
        var configuration = CellConfiguration(name: name)
        configuration.description = subtitle

        var reference = CellReference(endpoint: endpoint, label: label)
        if let startKey {
            reference.addKeyAndValue(KeyValue(key: startKey))
        }
        configuration.addReference(reference)

        var titleText = SkeletonText(text: title)
        titleText.modifiers = modifier {
            $0.fontStyle = "title3"
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var subtitleText = SkeletonText(text: subtitle)
        subtitleText.modifiers = modifier {
            $0.foregroundColor = "#334155"
            $0.padding = 2
        }

        var chipText = SkeletonText(text: chip)
        chipText.modifiers = modifier {
            $0.foregroundColor = "#0F172A"
            $0.fontWeight = "semibold"
            $0.background = "#E2E8F0"
            $0.cornerRadius = 8
            $0.padding = 6
        }

        var hintText = SkeletonText(text: endpoint)
        hintText.modifiers = modifier {
            $0.foregroundColor = "#64748B"
            $0.fontSize = 12
        }

        var header = SkeletonHStack(elements: [.Text(titleText), .Spacer(SkeletonSpacer()), .Text(chipText)])
        header.modifiers = modifier { $0.padding = 2 }

        var card = SkeletonVStack(elements: [.HStack(header), .Text(subtitleText), .Text(hintText)])
        card.modifiers = modifier {
            $0.padding = 14
            $0.background = "#FFFFFF"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = borderColor
            $0.shadowRadius = 6
            $0.shadowY = 2
            $0.shadowColor = "#0F172A22"
        }

        configuration.skeleton = .VStack(card)
        return configuration
    }

    nonisolated private static func signalWorkbenchConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Signal Workbench")
        configuration.description = "Kontroller lokale signaler og se innkommende flow i samme visning."

        var signalRef = CellReference(endpoint: "cell:///EventEmitter", label: "signals")
        signalRef.subscribeFeed = true
        configuration.addReference(signalRef)

        var title = SkeletonText(text: "Signal Workbench")
        title.modifiers = modifier {
            $0.fontStyle = "title3"
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var subtitle = SkeletonText(text: "Kjør start/stop og følg innkommende test-events i listen under.")
        subtitle.modifiers = modifier {
            $0.foregroundColor = "#334155"
        }

        var startButton = SkeletonButton(keypath: "signals.start", label: "Start", payload: .bool(true))
        startButton.modifiers = modifier {
            $0.padding = 10
            $0.background = "#DCFCE7"
            $0.borderWidth = 1
            $0.borderColor = "#16A34A"
            $0.cornerRadius = 10
        }

        var stopButton = SkeletonButton(keypath: "signals.stop", label: "Stop", payload: .bool(true))
        stopButton.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FEE2E2"
            $0.borderWidth = 1
            $0.borderColor = "#DC2626"
            $0.cornerRadius = 10
        }

        var signalRowTitle = SkeletonText(text: "Signal")
        signalRowTitle.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var signalRowValue = SkeletonText(keypath: "content.key")
        signalRowValue.modifiers = modifier {
            $0.foregroundColor = "#475569"
        }

        var signalRow = SkeletonVStack(elements: [
            .Text(signalRowTitle),
            .Text(signalRowValue)
        ])
        signalRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#F8FAFC"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#E2E8F0"
        }

        var incomingSignals = SkeletonList(topic: "test", keypath: nil, flowElementSkeleton: signalRow)
        incomingSignals.filterTypes = ["content"]
        incomingSignals.modifiers = modifier {
            $0.padding = 4
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        var root = SkeletonVStack(elements: [
            .Text(title),
            .Text(subtitle),
            .HStack(SkeletonHStack(elements: [.Button(startButton), .Button(stopButton)])),
            .List(incomingSignals)
        ])
        root.modifiers = modifier {
            $0.padding = 14
            $0.background = "#FFFFFF"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = "#94A3B8"
        }

        configuration.skeleton = .VStack(root)
        return configuration
    }

    nonisolated private static func catalogWorkbenchConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Catalog Workbench")
        configuration.description = "Driftspanel for sync, query/match og add/edit/update/remove i ConfigurationCatalog."

        var catalogRef = CellReference(endpoint: "cell:///ConfigurationCatalog", label: "catalog")
        catalogRef.subscribeFeed = true
        configuration.addReference(catalogRef)

        var title = SkeletonText(text: "Catalog Workbench")
        title.modifiers = modifier {
            $0.fontStyle = "title3"
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var subtitle = SkeletonText(text: "Workbench for sync, query/facets, match og CRUD-operasjoner mot ConfigurationCatalog.")
        subtitle.modifiers = modifier {
            $0.foregroundColor = "#334155"
        }

        var syncButton = SkeletonButton(keypath: "catalog.syncScaffoldPurposeGoals", label: "Sync fra Scaffold", payload: .null)
        syncButton.modifiers = modifier {
            $0.padding = 10
            $0.background = "#DBEAFE"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#2563EB"
        }

        var matchButton = SkeletonButton(
            keypath: "catalog.matchPurpose",
            label: "Match: plan",
            payload: .object(["purpose": .string("plan")])
        )
        matchButton.modifiers = modifier {
            $0.padding = 10
            $0.background = "#E2E8F0"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#64748B"
        }

        var matchInterestsButton = SkeletonButton(
            keypath: "catalog.matchInterests",
            label: "Match interesser",
            payload: .object([
                "interests": .list([.string("chat"), .string("privacy"), .string("conference")])
            ])
        )
        matchInterestsButton.modifiers = modifier {
            $0.padding = 10
            $0.background = "#E2E8F0"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#64748B"
        }

        var matchCombinedButton = SkeletonButton(
            keypath: "catalog.match",
            label: "Match kombinert",
            payload: .object([
                "purpose": .string("kommunikasjon"),
                "interests": .list([.string("chat"), .string("ai"), .string("privacy")]),
                "menuSlot": .string("upperMid"),
                "limit": .integer(6)
            ])
        )
        matchCombinedButton.modifiers = modifier {
            $0.padding = 10
            $0.background = "#E2E8F0"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#64748B"
        }

        var stateButton = SkeletonButton(keypath: "catalog.state", label: "Les State")
        stateButton.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FEF3C7"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#D97706"
        }

        var queryButton = SkeletonButton(
            keypath: "catalog.query",
            label: "Kjor query",
            payload: .object([
                "queryText": .string("chat privacy conference"),
                "purposeRefs": .list([.string("purpose://kommunikasjon-og-samarbeid")]),
                "interestRefs": .list([.string("interest://chat"), .string("interest://privacy")]),
                "constraints": .object([
                    "maxResults": .integer(8),
                    "maxSources": .integer(8),
                    "latencyBudgetMs": .integer(450),
                    "resourceBudget": .string("balanced"),
                    "networkPolicy": .string("preferHealthyThenCached")
                ]),
                "context": .object([
                    "editMode": .bool(false),
                    "insertionIntent": .string("root")
                ])
            ])
        )
        queryButton.modifiers = modifier {
            $0.padding = 10
            $0.background = "#DBEAFE"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#2563EB"
        }

        var facetButton = SkeletonButton(
            keypath: "catalog.facetCounts",
            label: "Kjor facets",
            payload: .object([
                "facetKeys": .list([
                    .string("categoryPath"),
                    .string("sourceRef"),
                    .string("supportedInsertionModes"),
                    .string("interestRef")
                ]),
                "maxBucketsPerFacet": .integer(10),
                "baseQuery": .object([
                    "queryText": .string("chat"),
                    "interestRefs": .list([.string("interest://chat")])
                ])
            ])
        )
        facetButton.modifiers = modifier {
            $0.padding = 10
            $0.background = "#DBEAFE"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#2563EB"
        }

        let workbenchDemoConfiguration = referenceCardConfiguration(
            name: "Catalog Workbench Demo",
            endpoint: "cell:///Perspective",
            label: "perspective",
            title: "Catalog Workbench Demo",
            subtitle: "Lokal demo-entry brukt for add/edit/update/remove i workbench.",
            chip: "DEMO",
            borderColor: "#1D4ED8"
        )

        let demoAddPayload: Object = [
            "id": .string("workbench-demo-entry"),
            "sourceCellEndpoint": .string("cell:///Perspective"),
            "sourceCellName": .string("PerspectiveCell"),
            "purpose": .string("Workbench demo"),
            "purposeDescription": .string("Demo purpose for catalog mutation tests."),
            "interests": .list([.string("catalog"), .string("demo"), .string("workbench")]),
            "menuSlots": .list([.string("upperMid"), .string("lowerMid")]),
            "goal": .cellConfiguration(workbenchDemoConfiguration),
            "configuration": .cellConfiguration(workbenchDemoConfiguration),
            "displayName": .string("Catalog Workbench Demo Entry"),
            "summary": .string("Opprettet fra Catalog Workbench."),
            "categoryPath": .list([.string("workbench"), .string("demo")]),
            "tags": .list([.string("catalog"), .string("mutation"), .string("demo")]),
            "purposeRefs": .list([.string("purpose://workbench-demo")]),
            "interestRefs": .list([.string("interest://catalog"), .string("interest://demo")]),
            "supportedInsertionModes": .list([.string("root"), .string("component")]),
            "supportedTargetKinds": .list([.string("menu"), .string("porthole")]),
            "editable": .bool(true),
            "flowDriven": .bool(false)
        ]

        let demoUpdatePayload: Object = [
            "id": .string("workbench-demo-entry"),
            "sourceCellEndpoint": .string("cell:///Perspective"),
            "sourceCellName": .string("PerspectiveCell"),
            "purpose": .string("Workbench demo"),
            "purposeDescription": .string("Updated demo purpose from Catalog Workbench."),
            "interests": .list([.string("catalog"), .string("demo"), .string("updated")]),
            "menuSlots": .list([.string("upperMid"), .string("lowerRight")]),
            "goal": .cellConfiguration(workbenchDemoConfiguration),
            "configuration": .cellConfiguration(workbenchDemoConfiguration),
            "displayName": .string("Catalog Workbench Demo Entry"),
            "summary": .string("Oppdatert fra Catalog Workbench."),
            "categoryPath": .list([.string("workbench"), .string("updated")]),
            "tags": .list([.string("catalog"), .string("mutation"), .string("updated")]),
            "purposeRefs": .list([.string("purpose://workbench-demo")]),
            "interestRefs": .list([.string("interest://catalog"), .string("interest://updated")]),
            "supportedInsertionModes": .list([.string("root"), .string("component")]),
            "supportedTargetKinds": .list([.string("menu"), .string("porthole")]),
            "editable": .bool(true),
            "flowDriven": .bool(false)
        ]

        var addDemoButton = SkeletonButton(
            keypath: "catalog.addConfiguration",
            label: "Add demo entry",
            payload: .object(demoAddPayload)
        )
        addDemoButton.modifiers = modifier {
            $0.padding = 10
            $0.background = "#DCFCE7"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#16A34A"
        }

        var editDemoButton = SkeletonButton(
            keypath: "catalog.editConfiguration",
            label: "Edit demo entry",
            payload: .object(demoUpdatePayload)
        )
        editDemoButton.modifiers = modifier {
            $0.padding = 10
            $0.background = "#DCFCE7"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#16A34A"
        }

        var updateDemoButton = SkeletonButton(
            keypath: "catalog.updateConfiguration",
            label: "Update demo entry",
            payload: .object(demoUpdatePayload)
        )
        updateDemoButton.modifiers = modifier {
            $0.padding = 10
            $0.background = "#DCFCE7"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#16A34A"
        }

        var removeDemoButton = SkeletonButton(
            keypath: "catalog.removeConfiguration",
            label: "Remove demo entry",
            payload: .string("workbench-demo-entry")
        )
        removeDemoButton.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FEE2E2"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#DC2626"
        }

        var entryPurpose = SkeletonText(keypath: "purpose")
        entryPurpose.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var entryDescription = SkeletonText(keypath: "purposeDescription")
        entryDescription.modifiers = modifier {
            $0.foregroundColor = "#475569"
        }

        var entryEndpoint = SkeletonText(keypath: "sourceCellEndpoint")
        entryEndpoint.modifiers = modifier {
            $0.foregroundColor = "#64748B"
            $0.fontSize = 12
        }

        var entryRow = SkeletonVStack(elements: [
            .Text(entryPurpose),
            .Text(entryDescription),
            .Text(entryEndpoint)
        ])
        entryRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#F8FAFC"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#E2E8F0"
        }

        var entriesList = SkeletonList(topic: nil, keypath: "catalog.catalogContracts", flowElementSkeleton: entryRow)
        entriesList.modifiers = modifier {
            $0.padding = 4
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        var queryResultName = SkeletonText(keypath: "displayName")
        queryResultName.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var queryResultSummary = SkeletonText(keypath: "summary")
        queryResultSummary.modifiers = modifier {
            $0.foregroundColor = "#475569"
            $0.fontSize = 12
            $0.lineLimit = 2
        }

        var queryResultScore = SkeletonText(keypath: "score")
        queryResultScore.modifiers = modifier {
            $0.foregroundColor = "#1D4ED8"
            $0.fontSize = 12
        }

        var queryResultRoute = SkeletonText(keypath: "route")
        queryResultRoute.modifiers = modifier {
            $0.foregroundColor = "#334155"
            $0.fontSize = 12
        }

        var queryResultRow = SkeletonVStack(elements: [
            .Text(queryResultName),
            .Text(queryResultSummary),
            .Text(queryResultScore),
            .Text(queryResultRoute)
        ])
        queryResultRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FFFFFF"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#BFDBFE"
        }

        var queryResultsList = SkeletonList(topic: nil, keypath: "catalog.query.state.results", flowElementSkeleton: queryResultRow)
        queryResultsList.modifiers = modifier {
            $0.padding = 4
            $0.background = "#EFF6FF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#BFDBFE"
        }

        var queryResultCount = SkeletonText(keypath: "catalog.query.state.resultCount")
        queryResultCount.modifiers = modifier {
            $0.foregroundColor = "#1E40AF"
            $0.fontWeight = "semibold"
        }

        var queryTotalMs = SkeletonText(keypath: "catalog.query.state.timing.totalMs")
        queryTotalMs.modifiers = modifier {
            $0.foregroundColor = "#1E3A8A"
            $0.fontSize = 12
        }

        var eventOperation = SkeletonText(keypath: "content.operation")
        eventOperation.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var eventCount = SkeletonText(keypath: "content.state.count")
        eventCount.modifiers = modifier {
            $0.foregroundColor = "#334155"
        }

        var eventRow = SkeletonVStack(elements: [
            .Text(eventOperation),
            .Text(eventCount)
        ])
        eventRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FFFFFF"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#E2E8F0"
        }

        var catalogEvents = SkeletonList(topic: "configurationCatalog", keypath: nil, flowElementSkeleton: eventRow)
        catalogEvents.filterTypes = ["event"]
        catalogEvents.modifiers = modifier {
            $0.padding = 4
            $0.background = "#F8FAFC"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        var errorEndpoint = SkeletonText(keypath: "endpoint")
        errorEndpoint.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#7F1D1D"
        }

        var errorMessage = SkeletonText(keypath: "message")
        errorMessage.modifiers = modifier {
            $0.foregroundColor = "#B91C1C"
        }

        var errorCount = SkeletonText(keypath: "count")
        errorCount.modifiers = modifier {
            $0.foregroundColor = "#991B1B"
            $0.fontSize = 12
        }

        var errorRow = SkeletonVStack(elements: [
            .Text(errorEndpoint),
            .Text(errorMessage),
            .Text(errorCount)
        ])
        errorRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FEF2F2"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#FCA5A5"
        }

        var errorLogList = SkeletonList(topic: nil, keypath: "catalog.errorLog", flowElementSkeleton: errorRow)
        errorLogList.modifiers = modifier {
            $0.padding = 4
            $0.background = "#FFF1F2"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#FECACA"
        }

        var root = SkeletonVStack(elements: [
            .Text(title),
            .Text(subtitle),
            .HStack(SkeletonHStack(elements: [.Button(syncButton), .Button(stateButton), .Button(queryButton)])),
            .HStack(SkeletonHStack(elements: [.Button(facetButton), .Button(matchButton), .Button(matchInterestsButton)])),
            .HStack(SkeletonHStack(elements: [.Button(matchCombinedButton), .Button(addDemoButton), .Button(editDemoButton)])),
            .HStack(SkeletonHStack(elements: [.Button(updateDemoButton), .Button(removeDemoButton)])),
            .Text(SkeletonText(text: "Entries")),
            .List(entriesList),
            .Text(SkeletonText(text: "Query state / resultater")),
            .HStack(SkeletonHStack(elements: [.Text(queryResultCount), .Text(queryTotalMs)])),
            .List(queryResultsList),
            .Text(SkeletonText(text: "Catalog events")),
            .List(catalogEvents),
            .Text(SkeletonText(text: "Error log")),
            .List(errorLogList)
        ])
        root.modifiers = modifier {
            $0.padding = 14
            $0.background = "#FFFFFF"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = "#94A3B8"
        }

        configuration.skeleton = .VStack(root)
        return configuration
    }

    nonisolated private static func agreementTemplateWorkbenchConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Agreement Template Workbench")
        configuration.description = "Preview/apply av agreementTemplate, access grant/revoke, signering og non-compliant policy."

        var catalogRef = CellReference(endpoint: "cell:///ConfigurationCatalog", label: "catalog")
        catalogRef.subscribeFeed = true
        configuration.addReference(catalogRef)

        var title = SkeletonText(text: "Agreement Template Workbench")
        title.modifiers = modifier {
            $0.fontStyle = "title3"
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var subtitle = SkeletonText(text: "Capability-basert tilgang med preview/apply, grant/revoke, current agreement og signContract-flyt.")
        subtitle.modifiers = modifier {
            $0.foregroundColor = "#334155"
        }

        var readState = SkeletonButton(keypath: "catalog.agreementTemplate.state", label: "Les state")
        readState.modifiers = modifier {
            $0.padding = 10
            $0.background = "#E2E8F0"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#64748B"
        }

        let defaultTemplate: Object = [
            "description": .string("Drafted in Agreement Template Workbench"),
            "requiresAllPartiesSignature": .bool(true),
            "capabilities": .list([
                .string("agreementTemplate.read"),
                .string("agreementTemplate.write"),
                .string("agreementTemplate.apply.newConnections"),
                .string("agreementTemplate.apply.reEvaluateExisting"),
                .string("agreementTemplate.contracts.enforce"),
                .string("agreementTemplate.access.manage")
            ])
        ]

        var previewNew = SkeletonButton(
            keypath: "catalog.agreementTemplate.preview",
            label: "Preview (new)",
            payload: .object([
                "rolloutMode": .string("new_connections_only"),
                "template": .object(defaultTemplate)
            ])
        )
        previewNew.modifiers = modifier {
            $0.padding = 10
            $0.background = "#DBEAFE"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#2563EB"
        }

        var applyNew = SkeletonButton(
            keypath: "catalog.agreementTemplate.apply",
            label: "Apply (new)",
            payload: .object([
                "rolloutMode": .string("new_connections_only"),
                "template": .object(defaultTemplate),
                "requiresAllPartiesSignature": .bool(true)
            ])
        )
        applyNew.modifiers = modifier {
            $0.padding = 10
            $0.background = "#DCFCE7"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#16A34A"
        }

        var applyReEvaluate = SkeletonButton(
            keypath: "catalog.agreementTemplate.apply",
            label: "Apply + re-eval",
            payload: .object([
                "rolloutMode": .string("re_evaluate_existing"),
                "forceSignContract": .bool(true),
                "evictIfNonCompliant": .bool(false),
                "template": .object(defaultTemplate)
            ])
        )
        applyReEvaluate.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FEF3C7"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#D97706"
        }

        var signCurrent = SkeletonButton(
            keypath: "catalog.agreements.sign",
            label: "Sign current",
            payload: .object(["signature": .string("accepted")])
        )
        signCurrent.modifiers = modifier {
            $0.padding = 10
            $0.background = "#ECFCCB"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#65A30D"
        }

        var reportNonCompliant = SkeletonButton(
            keypath: "catalog.agreements.nonCompliant.report",
            label: "Report non-compliant",
            payload: .object([
                "reason": .string("Possible conflict with previously signed agreement"),
                "evidenceRef": .string("agreement://previous")
            ])
        )
        reportNonCompliant.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FEE2E2"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#DC2626"
        }

        var setPolicy = SkeletonButton(
            keypath: "catalog.agreements.nonCompliant.policy",
            label: "Policy: auto request resign",
            payload: .object(["policy": .string("auto_request_resign")])
        )
        setPolicy.modifiers = modifier {
            $0.padding = 10
            $0.background = "#EDE9FE"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#7C3AED"
        }

        var readCurrentAgreement = SkeletonButton(
            keypath: "catalog.agreements.current",
            label: "Les current agreement"
        )
        readCurrentAgreement.modifiers = modifier {
            $0.padding = 10
            $0.background = "#DBEAFE"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#2563EB"
        }

        var grantAccess = SkeletonButton(
            keypath: "catalog.agreementTemplate.access.grant",
            label: "Grant read/write",
            payload: .object([
                "identityKey": .string("delegate:agreement-workbench"),
                "displayName": .string("Agreement Workbench Delegate"),
                "capabilities": .list([
                    .string("agreementTemplate.read"),
                    .string("agreementTemplate.write")
                ])
            ])
        )
        grantAccess.modifiers = modifier {
            $0.padding = 10
            $0.background = "#DCFCE7"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#16A34A"
        }

        var revokeAccess = SkeletonButton(
            keypath: "catalog.agreementTemplate.access.revoke",
            label: "Revoke delegate",
            payload: .object([
                "identityKey": .string("delegate:agreement-workbench")
            ])
        )
        revokeAccess.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FEE2E2"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#DC2626"
        }

        var currentAgreementID = SkeletonText(keypath: "catalog.agreements.current.agreementId")
        currentAgreementID.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var currentAgreementStatus = SkeletonText(keypath: "catalog.agreements.current.status")
        currentAgreementStatus.modifiers = modifier {
            $0.foregroundColor = "#334155"
        }

        var currentAgreementVersion = SkeletonText(keypath: "catalog.agreements.current.version")
        currentAgreementVersion.modifiers = modifier {
            $0.foregroundColor = "#1E3A8A"
            $0.fontSize = 12
        }

        var currentAgreementMode = SkeletonText(keypath: "catalog.agreements.current.rolloutMode")
        currentAgreementMode.modifiers = modifier {
            $0.foregroundColor = "#475569"
            $0.fontSize = 12
        }

        var currentAgreementRow = SkeletonVStack(elements: [
            .Text(currentAgreementID),
            .Text(currentAgreementStatus),
            .Text(currentAgreementVersion),
            .Text(currentAgreementMode)
        ])
        currentAgreementRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#EFF6FF"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#BFDBFE"
        }

        var delegationName = SkeletonText(keypath: "displayName")
        delegationName.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var delegationIdentity = SkeletonText(keypath: "identityKey")
        delegationIdentity.modifiers = modifier {
            $0.foregroundColor = "#334155"
            $0.fontSize = 12
        }

        var delegationCapabilities = SkeletonText(keypath: "capabilities")
        delegationCapabilities.modifiers = modifier {
            $0.foregroundColor = "#475569"
            $0.fontSize = 12
            $0.lineLimit = 2
        }

        var delegationRow = SkeletonVStack(elements: [
            .Text(delegationName),
            .Text(delegationIdentity),
            .Text(delegationCapabilities)
        ])
        delegationRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#F8FAFC"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#E2E8F0"
        }

        var accessDelegations = SkeletonList(topic: nil, keypath: "catalog.agreementTemplate.state.accessDelegations", flowElementSkeleton: delegationRow)
        accessDelegations.modifiers = modifier {
            $0.padding = 4
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        var reportReason = SkeletonText(keypath: "reason")
        reportReason.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#7F1D1D"
        }

        var reportStatus = SkeletonText(keypath: "status")
        reportStatus.modifiers = modifier {
            $0.foregroundColor = "#B91C1C"
        }

        var reportPolicy = SkeletonText(keypath: "policy")
        reportPolicy.modifiers = modifier {
            $0.foregroundColor = "#7C2D12"
            $0.fontSize = 12
        }

        var reportRow = SkeletonVStack(elements: [
            .Text(reportReason),
            .Text(reportStatus),
            .Text(reportPolicy)
        ])
        reportRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FEF2F2"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#FCA5A5"
        }

        var nonCompliantReports = SkeletonList(topic: nil, keypath: "catalog.agreementTemplate.state.nonCompliantReports", flowElementSkeleton: reportRow)
        nonCompliantReports.modifiers = modifier {
            $0.padding = 4
            $0.background = "#FFF1F2"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#FECACA"
        }

        var openReportsCount = SkeletonText(keypath: "catalog.agreementTemplate.state.nonCompliantOpenCount")
        openReportsCount.modifiers = modifier {
            $0.foregroundColor = "#B91C1C"
            $0.fontWeight = "semibold"
        }

        var historyId = SkeletonText(keypath: "agreementId")
        historyId.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var historyStatus = SkeletonText(keypath: "status")
        historyStatus.modifiers = modifier {
            $0.foregroundColor = "#334155"
        }

        var historyMode = SkeletonText(keypath: "rolloutMode")
        historyMode.modifiers = modifier {
            $0.foregroundColor = "#64748B"
            $0.fontSize = 12
        }

        var historyRow = SkeletonVStack(elements: [
            .Text(historyId),
            .Text(historyStatus),
            .Text(historyMode)
        ])
        historyRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#F8FAFC"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#E2E8F0"
        }

        var agreementHistory = SkeletonList(topic: nil, keypath: "catalog.agreements.history", flowElementSkeleton: historyRow)
        agreementHistory.modifiers = modifier {
            $0.padding = 4
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        var auditAction = SkeletonText(keypath: "action")
        auditAction.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var auditActor = SkeletonText(keypath: "actorIdentityKey")
        auditActor.modifiers = modifier {
            $0.foregroundColor = "#475569"
        }

        var auditRow = SkeletonVStack(elements: [
            .Text(auditAction),
            .Text(auditActor)
        ])
        auditRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FFFFFF"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#E2E8F0"
        }

        var auditLog = SkeletonList(topic: nil, keypath: "catalog.agreementTemplate.auditLog", flowElementSkeleton: auditRow)
        auditLog.modifiers = modifier {
            $0.padding = 4
            $0.background = "#F8FAFC"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        var eventAction = SkeletonText(keypath: "content.action")
        eventAction.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var eventAgreement = SkeletonText(keypath: "content.agreementId")
        eventAgreement.modifiers = modifier {
            $0.foregroundColor = "#64748B"
            $0.fontSize = 12
        }

        var eventRow = SkeletonVStack(elements: [
            .Text(eventAction),
            .Text(eventAgreement)
        ])
        eventRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#F8FAFC"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#E2E8F0"
        }

        var events = SkeletonList(topic: "agreements", keypath: nil, flowElementSkeleton: eventRow)
        events.filterTypes = ["event"]
        events.modifiers = modifier {
            $0.padding = 4
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        var root = SkeletonVStack(elements: [
            .Text(title),
            .Text(subtitle),
            .HStack(SkeletonHStack(elements: [.Button(readState), .Button(previewNew), .Button(applyNew)])),
            .HStack(SkeletonHStack(elements: [.Button(applyReEvaluate), .Button(signCurrent), .Button(readCurrentAgreement)])),
            .HStack(SkeletonHStack(elements: [.Button(grantAccess), .Button(revokeAccess)])),
            .HStack(SkeletonHStack(elements: [.Button(reportNonCompliant), .Button(setPolicy), .Text(openReportsCount)])),
            .Text(SkeletonText(text: "Current agreement")),
            .VStack(currentAgreementRow),
            .Text(SkeletonText(text: "Access delegations")),
            .List(accessDelegations),
            .Text(SkeletonText(text: "Non-compliant reports")),
            .List(nonCompliantReports),
            .Text(SkeletonText(text: "Agreement history")),
            .List(agreementHistory),
            .Text(SkeletonText(text: "Audit log")),
            .List(auditLog),
            .Text(SkeletonText(text: "Agreement events")),
            .List(events)
        ])
        root.modifiers = modifier {
            $0.padding = 14
            $0.background = "#FFFFFF"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = "#94A3B8"
        }

        configuration.skeleton = .VStack(root)
        return configuration
    }

    nonisolated static func appleIntelligenceLandingConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Apple Intelligence Purpose Matcher")
        configuration.description = "Prompt-drevet Apple Intelligence-flate for matching av CellConfigurations, skeleton-preview, lasting i Porthole og lagring til senere."

        var catalogReference = CellReference(endpoint: "cell:///ConfigurationCatalog", label: "catalog")
        catalogReference.subscribeFeed = false
        configuration.addReference(catalogReference)

        let canvas = "#0D1117"
        let surface = "#161B22"
        let surfaceRaised = "#0F141B"
        let stroke = "#30363D"
        let accent = "#00F2EA"
        let textPrimary = "#F0F6FC"
        let textMuted = "#8B949E"
        let accentTextOnFill = "#0D1117"

        let shellModifier = modifier {
            $0.padding = 16
            $0.background = canvas
            $0.cornerRadius = 18
            $0.borderWidth = 1
            $0.borderColor = stroke
            $0.maxWidthInfinity = true
        }

        let sectionModifier = modifier {
            $0.padding = 12
            $0.background = surface
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = stroke
            $0.maxWidthInfinity = true
        }

        let listModifier = modifier {
            $0.padding = 8
            $0.background = surfaceRaised
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = stroke
            $0.height = 300
            $0.maxWidthInfinity = true
        }

        let compactListModifier = modifier {
            $0.padding = 8
            $0.background = surfaceRaised
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = stroke
            $0.height = 190
            $0.maxWidthInfinity = true
        }

        let inputModifier = modifier {
            $0.padding = 16
            $0.background = surface
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = stroke
            $0.foregroundColor = textPrimary
            $0.maxWidthInfinity = true
        }

        let primaryButton = modifier {
            $0.padding = 10
            $0.background = accent
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = accent
            $0.foregroundColor = accentTextOnFill
        }

        let secondaryButton = modifier {
            $0.padding = 10
            $0.background = surfaceRaised
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = stroke
            $0.foregroundColor = textPrimary
        }

        let utilityButton = modifier {
            $0.padding = 10
            $0.background = "#1B2230"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#40536B"
            $0.foregroundColor = textPrimary
        }

        let accentButton = modifier {
            $0.padding = 10
            $0.background = "#102E33"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = accent
            $0.foregroundColor = accent
        }

        let hintTextModifier = modifier {
            $0.foregroundColor = textMuted
            $0.fontSize = 12
            $0.lineLimit = 3
        }

        var titleIcon = SkeletonImage(name: "sparkles")
        titleIcon.type = "system"
        titleIcon.modifiers = modifier {
            $0.foregroundColor = accent
            $0.fontSize = 20
        }

        var titleText = SkeletonText(text: "APPLE INTELLIGENCE")
        titleText.modifiers = modifier {
            $0.fontWeight = "bold"
            $0.fontSize = 14
            $0.foregroundColor = accent
        }

        let header = SkeletonHStack(elements: [
            .Image(titleIcon),
            .Text(titleText),
            .Spacer(SkeletonSpacer())
        ], spacing: 10)

        var intro = SkeletonText(text: "Beskriv hva du vil oppnaa, saa matcher vi relevante CellConfigurations som kan lastes inn i Porthole.")
        intro.modifiers = modifier {
            $0.foregroundColor = textPrimary
            $0.fontSize = 14
            $0.lineLimit = 3
        }

        var tips = SkeletonText(text: "Tips: vaer konkret om maal, kontekst, interesser eller sted. Trykk paa et forslag for aa velge det. Aktiver raden for aa laste direkte i Porthole.")
        tips.modifiers = hintTextModifier

        var suggestionCountLabel = SkeletonText(text: "Forslag")
        suggestionCountLabel.modifiers = hintTextModifier

        var suggestionCountValue = SkeletonText(keypath: "catalog.matching.state.suggestionCount")
        suggestionCountValue.modifiers = modifier {
            $0.foregroundColor = accent
            $0.fontWeight = "bold"
            $0.fontSize = 14
        }

        var bookmarkCountLabel = SkeletonText(text: "Lagret")
        bookmarkCountLabel.modifiers = hintTextModifier

        var bookmarkCountValue = SkeletonText(keypath: "catalog.matching.state.bookmarkCount")
        bookmarkCountValue.modifiers = modifier {
            $0.foregroundColor = accent
            $0.fontWeight = "bold"
            $0.fontSize = 14
        }

        var selectedLabel = SkeletonText(text: "Valgt")
        selectedLabel.modifiers = hintTextModifier

        var selectedValue = SkeletonText(keypath: "catalog.matching.state.selectedName")
        selectedValue.modifiers = modifier {
            $0.foregroundColor = textPrimary
            $0.fontSize = 13
            $0.fontWeight = "semibold"
            $0.lineLimit = 1
        }

        func statCard(label: SkeletonText, value: SkeletonText) -> SkeletonElement {
            var stack = SkeletonVStack(elements: [.Text(label), .Text(value)], spacing: 4)
            stack.modifiers = modifier {
                $0.padding = 10
                $0.background = surfaceRaised
                $0.cornerRadius = 12
                $0.borderWidth = 1
                $0.borderColor = stroke
                $0.maxWidthInfinity = true
            }
            return .VStack(stack)
        }

        let promptField = SkeletonTextField(
            text: nil,
            sourceKeypath: "catalog.matching.promptText",
            targetKeypath: "catalog.matching.runPromptInput",
            placeholder: "Beskriv hva du vil oppnaa...",
            modifiers: inputModifier
        )

        var runMatching = SkeletonButton(
            keypath: "catalog.matching.runPromptInput",
            label: "Finn forslag"
        )
        runMatching.modifiers = primaryButton

        var browseAll = SkeletonButton(
            keypath: "catalog.matching.runPrompt",
            label: "Utforsk alle",
            payload: .object(["browseAll": .bool(true)])
        )
        browseAll.modifiers = secondaryButton

        var clearMatching = SkeletonButton(
            keypath: "catalog.matching.clear",
            label: "Nullstill",
            payload: .bool(true)
        )
        clearMatching.modifiers = utilityButton

        var quickChat = SkeletonButton(
            keypath: "catalog.matching.runPrompt",
            label: "Chatte med venn",
            payload: .object(["prompt": .string("jeg skal chatte med en venn")])
        )
        quickChat.modifiers = secondaryButton

        var quickConference = SkeletonButton(
            keypath: "catalog.matching.runPrompt",
            label: "AI og personvern",
            payload: .object(["prompt": .string("jeg vil laere om ai og personvern, hvilke konferanser boer jeg melde meg paa?")])
        )
        quickConference.modifiers = secondaryButton

        var quickRestaurant = SkeletonButton(
            keypath: "catalog.matching.runPrompt",
            label: "Asiatisk og spicy",
            payload: .object(["prompt": .string("jeg kan tenke meg noe asiatisk, friskt og spicy i dag hvilke restauranter boer jeg se paa?")])
        )
        quickRestaurant.modifiers = secondaryButton

        var quickPeople = SkeletonButton(
            keypath: "catalog.matching.runPrompt",
            label: "Lignende interesser",
            payload: .object(["prompt": .string("jeg har lyst til aa finne andre som har lignende interesser som meg")])
        )
        quickPeople.modifiers = secondaryButton

        var sectionPrompt = SkeletonText(text: "FORMULER INTENSJON")
        sectionPrompt.modifiers = modifier {
            $0.fontSize = 10
            $0.fontWeight = "bold"
            $0.foregroundColor = textMuted
        }

        var sectionSuggestions = SkeletonText(text: "FORSLAG BASERT PAA DIN INTENSJON")
        sectionSuggestions.modifiers = modifier {
            $0.fontSize = 10
            $0.fontWeight = "bold"
            $0.foregroundColor = textMuted
        }

        var sectionSelected = SkeletonText(text: "VALGT FORSLAG")
        sectionSelected.modifiers = modifier {
            $0.fontSize = 10
            $0.fontWeight = "bold"
            $0.foregroundColor = textMuted
        }

        var sectionSaved = SkeletonText(text: "LAGRET TIL SENERE")
        sectionSaved.modifiers = modifier {
            $0.fontSize = 10
            $0.fontWeight = "bold"
            $0.foregroundColor = textMuted
        }

        var rowIcon = SkeletonImage(name: "square.stack.3d.up.fill")
        rowIcon.type = "system"
        rowIcon.modifiers = modifier {
            $0.foregroundColor = accent
            $0.fontSize = 14
        }

        var rowName = SkeletonText(keypath: "name")
        rowName.modifiers = modifier {
            $0.fontWeight = "bold"
            $0.foregroundColor = textPrimary
            $0.fontSize = 14
            $0.lineLimit = 1
        }

        var rowScore = SkeletonText(keypath: "match_score")
        rowScore.modifiers = modifier {
            $0.fontSize = 12
            $0.foregroundColor = accent
            $0.fontWeight = "bold"
        }

        var rowDescription = SkeletonText(keypath: "description")
        rowDescription.modifiers = modifier {
            $0.fontSize = 13
            $0.foregroundColor = textPrimary
            $0.lineLimit = 2
        }

        var rowReasoning = SkeletonText(keypath: "reasoning")
        rowReasoning.modifiers = modifier {
            $0.fontSize = 12
            $0.foregroundColor = textMuted
            $0.lineLimit = 2
        }

        var rowSkeletonStatus = SkeletonText(keypath: "skeletonStatus")
        rowSkeletonStatus.modifiers = modifier {
            $0.fontSize = 11
            $0.foregroundColor = accent
            $0.lineLimit = 1
        }

        var rowEndpoint = SkeletonText(keypath: "primaryEndpoint")
        rowEndpoint.modifiers = modifier {
            $0.fontSize = 11
            $0.foregroundColor = textMuted
            $0.lineLimit = 1
        }

        let rowTop = SkeletonHStack(elements: [
            .Image(rowIcon),
            .Text(rowName),
            .Spacer(SkeletonSpacer()),
            .Text(rowScore)
        ], spacing: 8)

        let rowBottom = SkeletonHStack(elements: [
            .Text(rowSkeletonStatus),
            .Spacer(SkeletonSpacer()),
            .Text(rowEndpoint)
        ], spacing: 8)

        var suggestionRow = SkeletonVStack(elements: [
            .HStack(rowTop),
            .Text(rowDescription),
            .Text(rowReasoning),
            .HStack(rowBottom)
        ], spacing: 8)
        suggestionRow.modifiers = modifier {
            $0.padding = 12
            $0.background = surface
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = stroke
        }

        var suggestionList = SkeletonList(
            topic: nil,
            keypath: "catalog.matching.suggestions",
            flowElementSkeleton: suggestionRow
        )
        suggestionList.filterTypes = ["event"]
        suggestionList.selectionMode = .single
        suggestionList.selectionValueKeypath = "rank"
        suggestionList.selectionStateKeypath = "catalog.matching.selectedIndex"
        suggestionList.selectionActionKeypath = "catalog.matching.selectIndex"
        suggestionList.selectionPayloadMode = .itemID
        suggestionList.allowsEmptySelection = false
        suggestionList.activationActionKeypath = "catalog.matching.loadSelectedToPorthole"
        suggestionList.modifiers = listModifier

        var selectedName = SkeletonText(keypath: "name")
        selectedName.modifiers = modifier {
            $0.fontWeight = "bold"
            $0.fontSize = 14
            $0.foregroundColor = textPrimary
        }

        var selectedDescription = SkeletonText(keypath: "description")
        selectedDescription.modifiers = modifier {
            $0.fontSize = 13
            $0.foregroundColor = textPrimary
            $0.lineLimit = 2
        }

        var selectedReasoning = SkeletonText(keypath: "reasoning")
        selectedReasoning.modifiers = modifier {
            $0.fontSize = 12
            $0.foregroundColor = textMuted
            $0.lineLimit = 3
        }

        var selectedPreviewLabel = SkeletonText(text: "Skeleton preview")
        selectedPreviewLabel.modifiers = modifier {
            $0.fontSize = 11
            $0.fontWeight = "semibold"
            $0.foregroundColor = accent
        }

        var selectedPreview = SkeletonText(keypath: "skeletonPreview")
        selectedPreview.modifiers = modifier {
            $0.fontSize = 11
            $0.foregroundColor = textMuted
            $0.lineLimit = 4
        }

        var selectedCard = SkeletonVStack(elements: [
            .Text(selectedName),
            .Text(selectedDescription),
            .Text(selectedReasoning),
            .Text(selectedPreviewLabel),
            .Text(selectedPreview)
        ], spacing: 8)
        selectedCard.modifiers = modifier {
            $0.padding = 12
            $0.background = surface
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = stroke
        }

        var selectedSuggestion = SkeletonList(
            topic: nil,
            keypath: "catalog.matching.selectedSuggestion",
            flowElementSkeleton: selectedCard
        )
        selectedSuggestion.filterTypes = ["event"]
        selectedSuggestion.modifiers = compactListModifier

        var openSelected = SkeletonButton(
            keypath: "catalog.matching.loadSelectedToPorthole",
            label: "Last i Porthole",
            payload: .bool(true)
        )
        openSelected.modifiers = primaryButton

        var previewSelected = SkeletonButton(
            keypath: "catalog.matching.previewSelected",
            label: "Se struktur",
            payload: .bool(true)
        )
        previewSelected.modifiers = secondaryButton

        var bookmarkSelected = SkeletonButton(
            keypath: "catalog.matching.bookmarkSelected",
            label: "Lagre til senere",
            payload: .bool(true)
        )
        bookmarkSelected.modifiers = utilityButton

        var addToMenu = SkeletonButton(
            keypath: "catalog.matching.saveSelectedToMenu",
            label: "Legg i meny",
            payload: .object(["menuSlot": .string("upperMid")])
        )
        addToMenu.modifiers = utilityButton

        var goalAchieved = SkeletonButton(
            keypath: "catalog.matching.markSelectedGoalAchieved",
            label: "Loeste formaalet",
            payload: .bool(true)
        )
        goalAchieved.modifiers = accentButton

        var savedList = SkeletonList(
            topic: nil,
            keypath: "catalog.matching.bookmarks",
            flowElementSkeleton: suggestionRow
        )
        savedList.modifiers = compactListModifier

        var savedFootnote = SkeletonText(text: "Stretch: disse forslagene kan senere matches frem igjen eller brukes som byggesteiner i andre skeletons.")
        savedFootnote.modifiers = hintTextModifier

        var promptSection = SkeletonVStack(elements: [
            .Text(sectionPrompt),
            .TextField(promptField),
            .HStack(SkeletonHStack(elements: [.Button(runMatching), .Button(browseAll), .Button(clearMatching)], spacing: 8)),
            .HStack(SkeletonHStack(elements: [.Button(quickChat), .Button(quickConference)], spacing: 8)),
            .HStack(SkeletonHStack(elements: [.Button(quickRestaurant), .Button(quickPeople)], spacing: 8))
        ], spacing: 10)
        promptSection.modifiers = sectionModifier

        var suggestionsSection = SkeletonVStack(elements: [
            .Text(sectionSuggestions),
            .List(suggestionList)
        ], spacing: 10)
        suggestionsSection.modifiers = sectionModifier

        var selectedSection = SkeletonVStack(elements: [
            .Text(sectionSelected),
            .List(selectedSuggestion),
            .HStack(SkeletonHStack(elements: [.Button(openSelected), .Button(previewSelected)], spacing: 8)),
            .HStack(SkeletonHStack(elements: [.Button(bookmarkSelected), .Button(addToMenu)], spacing: 8)),
            .HStack(SkeletonHStack(elements: [.Button(goalAchieved)], spacing: 8))
        ], spacing: 10)
        selectedSection.modifiers = sectionModifier

        var savedSection = SkeletonVStack(elements: [
            .Text(sectionSaved),
            .List(savedList),
            .Text(savedFootnote)
        ], spacing: 10)
        savedSection.modifiers = sectionModifier

        let statsRow = SkeletonHStack(elements: [
            statCard(label: suggestionCountLabel, value: suggestionCountValue),
            statCard(label: bookmarkCountLabel, value: bookmarkCountValue),
            statCard(label: selectedLabel, value: selectedValue)
        ], spacing: 10)

        var root = SkeletonVStack(elements: [
            .HStack(header),
            .Text(intro),
            .Text(tips),
            .HStack(statsRow),
            .VStack(promptSection),
            .VStack(suggestionsSection),
            .VStack(selectedSection),
            .VStack(savedSection)
        ], spacing: 12)
        root.modifiers = shellModifier

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        scroll.modifiers = modifier {
            $0.maxWidthInfinity = true
            $0.maxHeightInfinity = true
            $0.background = canvas
        }

        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    nonisolated private static func modifier(_ configure: (inout SkeletonModifiers) -> Void) -> SkeletonModifiers {
        var modifiers = SkeletonModifiers()
        configure(&modifiers)
        return modifiers
    }

    private func emitAgreementEvent(action: String, payload: Object, requester: Identity) async {
        var flowPayload = payload
        flowPayload["action"] = .string(action)
        flowPayload["state"] = stateValue()

        var flowElement = FlowElement(
            title: "agreement.\(action)",
            content: .object(flowPayload),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flowElement.topic = "agreements"
        flowElement.origin = uuid

        if let owner = try? await getOwner(requester: requester) {
            pushFlowElement(flowElement, requester: owner)
        } else {
            pushFlowElement(flowElement, requester: requester)
        }
    }

    private func emitCatalogEvent(operation: String, entry: CatalogEntry?, requester: Identity) async {
        var payload: Object = ["operation": .string(operation), "state": stateValue()]
        if let entry {
            payload["entry"] = .object(entry.asObject())
        }

        var flowElement = FlowElement(
            title: "configuration.catalog.\(operation)",
            content: .object(payload),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flowElement.topic = "configurationCatalog"
        flowElement.origin = uuid

        if let owner = try? await getOwner(requester: requester) {
            pushFlowElement(flowElement, requester: owner)
        } else {
            pushFlowElement(flowElement, requester: requester)
        }
    }
}
