import XCTest
import Foundation
import CellBase
import CellApple
@testable import Binding

#if canImport(AppKit)
import AppKit
#endif

@MainActor
final class CellConfigurationVerifierXCTest: XCTestCase {
    private static let remoteParitySentinelPath = "/tmp/binding-enable-remote-parity.flag"
    private static let cellScaffoldRoot = "/Users/kjetil/Build/Digipomps/HAVEN/CellScaffold"

    private func makeLocalConferenceRuntimeContext() async throws -> (resolver: CellResolver, identity: Identity) {
        CellBase.defaultIdentityVault = BindingStartupIdentityVault.shared

        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        await BindingLocalCellRegistration.shared.ensureLocallyRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            throw NSError(
                domain: "CellConfigurationVerifierXCTest",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Expected shared CellResolver after local startup bootstrap"]
            )
        }

        let identityVault = await BindingStartupIdentityVault.shared.initialize()
        CellBase.defaultIdentityVault = identityVault

        let identityContext = "conference-local-\(UUID().uuidString)"
        guard let identity = await identityVault.identity(for: identityContext, makeNewIfNotFound: true) else {
            throw NSError(
                domain: "CellConfigurationVerifierXCTest",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Missing startup identity for local conference runtime"]
            )
        }

        await ConferenceParticipantPreviewFallbackStateStore.shared.reset(for: identity.uuid)
        return (resolver, identity)
    }

    private static func spatialV2InspectorConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Spatial v2 AR Inspector")
        configuration.description = "Portable Binding verifier for a CellScaffold-matured spatial AR contract."
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: "cell:///BindingSpatialV2Fixture",
            sourceCellName: "BindingSpatialV2FixtureCell",
            purpose: "Inspect a platform-neutral Spatial v2 AR scene contract",
            purposeDescription: "Binding renders and reads pose, asset references and access policy without owning AR protocol semantics.",
            interests: ["spatial", "ar", "binding", "cellconfiguration"],
            menuSlots: ["debug"]
        )
        configuration.addReference(CellReference(endpoint: "cell:///BindingSpatialV2Fixture", label: "spatial"))
        configuration.skeleton = .ScrollView(
            SkeletonScrollView(axis: "vertical", elements: [
                .Text(SkeletonText(text: "Spatial v2 AR Inspector")),
                .Text(SkeletonText(keypath: "spatial.state.summary")),
                .Section(
                    SkeletonSection(
                        header: .Text(SkeletonText(text: "Anchor contract")),
                        content: [
                            .Text(SkeletonText(keypath: "spatial.state.schema")),
                            .Text(SkeletonText(keypath: "spatial.state.anchor.anchorId")),
                            .Text(SkeletonText(keypath: "spatial.state.anchor.coordinateFrame")),
                            .Text(SkeletonText(keypath: "spatial.state.anchor.locationSummary")),
                            .Text(SkeletonText(keypath: "spatial.state.anchor.poseSummary"))
                        ]
                    )
                ),
                .Section(
                    SkeletonSection(
                        header: .Text(SkeletonText(text: "Asset delivery")),
                        content: [
                            .Text(SkeletonText(keypath: "spatial.state.assetManifest.primaryAssetId")),
                            .Text(SkeletonText(keypath: "spatial.state.assetManifest.primaryAssetRef")),
                            .Text(SkeletonText(keypath: "spatial.state.assetManifest.primaryDigest")),
                            .Text(SkeletonText(keypath: "spatial.state.assetManifest.cachePolicy"))
                        ]
                    )
                ),
                .Section(
                    SkeletonSection(
                        header: .Text(SkeletonText(text: "Access policy")),
                        content: [
                            .Text(SkeletonText(keypath: "spatial.state.accessPolicy.viewerRoles")),
                            .Text(SkeletonText(keypath: "spatial.state.accessPolicy.policyRefs")),
                            .Text(SkeletonText(keypath: "spatial.state.accessPolicy.denialBehavior")),
                            .Text(SkeletonText(keypath: "spatial.state.accessPolicy.assetDeliverySummary"))
                        ]
                    )
                ),
                .Text(SkeletonText(keypath: "spatial.state.nativeAdapter")),
                .Button(
                    SkeletonButton(
                        keypath: "spatial.dispatchAction",
                        label: "Preview native AR adapter",
                        payload: .object([
                            "keypath": .string("ar.preview"),
                            "payload": .object([
                                "mode": .string("binding-native-adapter")
                            ])
                        ])
                    )
                )
            ])
        )
        return configuration
    }

    func testLocalConferenceDemoLauncherLoadsThroughStartupPorthole() async throws {
        CellBase.defaultIdentityVault = nil
        CellBase.defaultCellResolver = nil
        CellBase.typedCellUtility = nil

        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        await BindingLocalCellRegistration.shared.ensureLocallyRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            XCTFail("Expected CellResolver after local startup bootstrap")
            return
        }
        guard let owner = await CellBase.defaultIdentityVault?.identity(for: "private", makeNewIfNotFound: true) else {
            XCTFail("Expected startup identity for local conference launcher bootstrap")
            return
        }
        guard let porthole = try await resolver.cellAtEndpoint(
            endpoint: "cell:///Porthole",
            requester: owner
        ) as? OrchestratorCell else {
            XCTFail("Expected locally registered Porthole during startup bootstrap")
            return
        }

        let configuration = ConfigurationCatalogCell.conferenceDemoLauncherWorkbenchConfiguration()
        try await porthole.loadCellConfiguration(configuration, requester: owner)

        let stateValue = try await porthole.get(
            keypath: "conferenceDemoLauncher.state.statusSummary",
            requester: owner
        )

        guard case let .string(text) = stateValue else {
            XCTFail("Expected string statusSummary from conference demo launcher, got \(stateValue)")
            return
        }

        XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertNil(SkeletonBindingProbeSupport.failureDetail(from: stateValue))
    }

    func testPersonalCopilotLocalSurfacesLoadWithoutReferenceFailures() async throws {
        for configuration in [
            ConfigurationCatalogCell.personalHomeMenuConfiguration(),
            ConfigurationCatalogCell.personalProfileMenuConfiguration(),
            ConfigurationCatalogCell.personalPublicProfileMenuConfiguration(),
            ConfigurationCatalogCell.personalPublicProfileDirectoryMenuConfiguration(),
            ConfigurationCatalogCell.personalMatchesMenuConfiguration(),
            ConfigurationCatalogCell.personalVaultIdeasMenuConfiguration(),
            ConfigurationCatalogCell.personalMeetingIntentMenuConfiguration(),
            ConfigurationCatalogCell.personalPrivacyAuditMenuConfiguration(),
            ConfigurationCatalogCell.personalCopilotCatalogMenuConfiguration()
        ] {
            let localConfiguration = CellConfigurationEndpointRetargeting
                .rewritingStagingPersonalCopilotEndpointsToLocalFallbacks(in: configuration)
            let buttonsToExecute = personalCopilotButtonsToExecute(for: localConfiguration)
            let report = try await CellConfigurationVerifier.contractReport(
                for: localConfiguration,
                buttonsToExecute: buttonsToExecute,
                identityMode: .startup
            )

            XCTAssertEqual(
                report.validation.errorCount,
                0,
                "Validation issues for \(configuration.name): \(report.validation.issues)"
            )
            XCTAssertTrue(
                report.unresolvedReferences.isEmpty,
                "Unresolved references for \(configuration.name): \(report.unresolvedReferences)"
            )
            XCTAssertTrue(
                report.unreadableRootProbes.isEmpty,
                "Unreadable root probes for \(configuration.name): \(report.unreadableRootProbes)"
            )
            XCTAssertTrue(
                report.failedActions.isEmpty,
                "Failed actions for \(configuration.name): \(report.failedActions)"
            )
            for buttonLabel in buttonsToExecute {
                XCTAssertTrue(
                    report.actionExecutions.contains(where: { $0.label == buttonLabel && $0.succeeded }),
                    "Expected \(configuration.name) to execute \(buttonLabel), got: \(report.actionExecutions)"
                )
            }
        }
    }

    private func personalCopilotButtonsToExecute(for configuration: CellConfiguration) -> Set<String> {
        switch configuration.name {
        case "Personal Home":
            return [
                "Request account export",
                "Request account deletion",
                "Cancel deletion request",
                "Manage public identity",
                "Open profile",
                "Open privacy audit"
            ]
        case "Vault / Ideas":
            return [
                "Seed idea",
                "Seed project",
                "Reindex graf",
                "Naboer"
            ]
        case "Publish Public Profile":
            return [
                "Prepare preview",
                "Record consent",
                "Record audit",
                "Publish approved preview",
                "Unpublish",
                "Delete public profile"
            ]
        case "Public Profile Directory":
            return [
                "Search",
                "Profile detail",
                "Report result",
                "Hide result",
                "Block result"
            ]
        case "Matches":
            return [
                "Refresh suggestions",
                "Request consent",
                "Approve match",
                "Decline",
                "Clear suggestion"
            ]
        case "Meeting Intent":
            return [
                "Foreslå tider",
                "Godta første forslag",
                "Avslå første forslag",
                "Tøm utkast"
            ]
        default:
            return []
        }
    }

    func testConfigurationCatalogSkeletonsPassStaticStructureAudit() async throws {
        let owner = await makeStaticCatalogAuditOwnerIdentity()
        let catalog = await ConfigurationCatalogCell(owner: owner)
        _ = try? await catalog.set(keypath: "syncScaffoldPurposeGoals", value: .null, requester: owner)

        let value = try await catalog.get(keypath: "configurations", requester: owner)
        guard case let .list(items) = value else {
            XCTFail("Expected ConfigurationCatalog.configurations list, got \(value)")
            return
        }

        let configurations = items.compactMap(Self.decodeCatalogConfiguration)
            .filter { $0.skeleton != nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        XCTAssertGreaterThanOrEqual(
            configurations.count,
            12,
            "Expected the audit to cover the seeded Binding catalog, got \(configurations.count)"
        )

        let reports = configurations.map(Self.staticSkeletonAudit)
        let fatalIssues = reports.flatMap { report in
            report.issues
                .filter { $0.severity == .error }
                .map { "\(report.configurationName): \($0.detail)" }
        }
        let summary = Self.formatStaticSkeletonAudit(reports)
        print(summary)

        XCTAssertTrue(
            fatalIssues.isEmpty,
            summary
        )
    }

    private struct StaticSkeletonAuditIssue {
        let severity: BindingDiagnosticSeverity
        let detail: String
    }

    private struct StaticSkeletonAuditReport {
        let configurationName: String
        let referenceCount: Int
        var elementCount: Int = 0
        var buttonCount: Int = 0
        var inputCount: Int = 0
        var selectableCount: Int = 0
        var visualizationCount: Int = 0
        var issues: [StaticSkeletonAuditIssue] = []
    }

    private func makeStaticCatalogAuditOwnerIdentity() async -> Identity {
        let vault = await BindingStartupIdentityVault.shared.initialize()
        CellBase.defaultIdentityVault = vault
        return await vault.identity(
            for: "static-catalog-audit-\(UUID().uuidString)",
            makeNewIfNotFound: true
        )!
    }

    private static func decodeCatalogConfiguration(from value: ValueType) -> CellConfiguration? {
        guard case let .cellConfiguration(configuration) = value else { return nil }
        return configuration
    }

    private static func staticSkeletonAudit(_ configuration: CellConfiguration) -> StaticSkeletonAuditReport {
        var report = StaticSkeletonAuditReport(
            configurationName: configuration.name,
            referenceCount: configuration.cellReferences?.count ?? 0
        )
        let validation = CellConfigurationValidationService.validate(configuration)
        for issue in validation.issues where issue.severity == .error {
            report.issues.append(
                StaticSkeletonAuditIssue(
                    severity: .error,
                    detail: "validation: \(issue.title) - \(issue.detail)"
                )
            )
        }
        for issue in validation.issues where issue.severity == .warning {
            report.issues.append(
                StaticSkeletonAuditIssue(
                    severity: .warning,
                    detail: "validation: \(issue.title) - \(issue.detail)"
                )
            )
        }

        guard let skeleton = configuration.skeleton else {
            report.issues.append(StaticSkeletonAuditIssue(severity: .error, detail: "missing skeleton"))
            return report
        }

        inspectSkeleton(skeleton, path: ["root"], report: &report)
        return report
    }

    private static func inspectSkeleton(
        _ element: SkeletonElement,
        path: [String],
        report: inout StaticSkeletonAuditReport
    ) {
        report.elementCount += 1

        switch element {
        case .Text(let text):
            inspectVisibleText(text.text, at: path, report: &report)
        case .AttachmentField:
            report.inputCount += 1
        case .FileUpload:
            report.inputCount += 1
        case .TextField(let field):
            report.inputCount += 1
            inspectVisibleText(field.placeholder, at: path + ["placeholder"], report: &report)
            inspectInputBinding(
                sourceKeypath: field.sourceKeypath,
                targetKeypath: field.targetKeypath,
                staticText: field.text,
                elementName: "TextField",
                path: path,
                report: &report
            )
        case .TextArea(let field):
            report.inputCount += 1
            inspectVisibleText(field.placeholder, at: path + ["placeholder"], report: &report)
            inspectInputBinding(
                sourceKeypath: field.sourceKeypath,
                targetKeypath: field.targetKeypath,
                staticText: field.text,
                elementName: "TextArea",
                path: path,
                report: &report
            )
        case .Button(let button):
            report.buttonCount += 1
            let label = button.label.trimmingCharacters(in: .whitespacesAndNewlines)
            let keypath = button.keypath.trimmingCharacters(in: .whitespacesAndNewlines)
            if label.isEmpty {
                report.issues.append(StaticSkeletonAuditIssue(severity: .error, detail: "\(pathString(path)) button has empty label"))
            }
            if keypath.isEmpty && !SkeletonButtonNavigation.isNavigationButton(button) {
                report.issues.append(StaticSkeletonAuditIssue(severity: .error, detail: "\(pathString(path)) button has empty keypath"))
            } else if SkeletonButtonNavigation.isNavigationButton(button),
                      SkeletonButtonNavigation.resolveURL(
                          for: button,
                          relativeTo: URL(string: "https://binding-navigation.invalid")
                      ) == nil {
                report.issues.append(StaticSkeletonAuditIssue(severity: .error, detail: "\(pathString(path)) button has unsafe navigation URL"))
            }
            inspectVisibleText(label, at: path + ["label"], report: &report)
        case .Toggle(let toggle):
            report.inputCount += 1
            if toggle.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                report.issues.append(StaticSkeletonAuditIssue(severity: .error, detail: "\(pathString(path)) toggle has empty label"))
            }
            if toggle.keypath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                report.issues.append(StaticSkeletonAuditIssue(severity: .error, detail: "\(pathString(path)) toggle has empty keypath"))
            }
            inspectVisibleText(toggle.label, at: path + ["label"], report: &report)
        case .Picker(let picker):
            report.selectableCount += 1
            inspectVisibleText(picker.label, at: path + ["label"], report: &report)
            inspectVisibleText(picker.placeholder, at: path + ["placeholder"], report: &report)
            if picker.keypath == nil && picker.elements.isEmpty {
                report.issues.append(StaticSkeletonAuditIssue(severity: .warning, detail: "\(pathString(path)) picker has neither keypath nor static options"))
            }
            if picker.selectionStateKeypath != nil && picker.selectionActionKeypath == nil {
                report.issues.append(StaticSkeletonAuditIssue(severity: .warning, detail: "\(pathString(path)) picker shows selection state without selection action"))
            }
        case .List(let list):
            if list.keypath == nil && list.topic == nil && list.elements.isEmpty {
                report.issues.append(StaticSkeletonAuditIssue(severity: .warning, detail: "\(pathString(path)) list has neither keypath, topic nor static elements"))
            }
            if list.selectionStateKeypath != nil && list.selectionActionKeypath == nil && list.activationActionKeypath == nil {
                report.issues.append(StaticSkeletonAuditIssue(severity: .warning, detail: "\(pathString(path)) selectable list shows state without selection or activation action"))
            }
            if let row = list.flowElementSkeleton {
                inspectSkeleton(.VStack(row), path: path + ["row"], report: &report)
            }
        case .Reference(let reference):
            if let row = reference.flowElementSkeleton {
                inspectSkeleton(.VStack(row), path: path + ["referenceRow"], report: &report)
            }
        case .Section(let section):
            if let header = section.header {
                inspectSkeleton(header, path: path + ["header"], report: &report)
            }
            for (index, child) in section.content.enumerated() {
                inspectSkeleton(child, path: path + ["content[\(index)]"], report: &report)
            }
            if let footer = section.footer {
                inspectSkeleton(footer, path: path + ["footer"], report: &report)
            }
        case .HStack(let stack):
            for (index, child) in stack.elements.enumerated() {
                inspectSkeleton(child, path: path + ["h[\(index)]"], report: &report)
            }
        case .VStack(let stack):
            for (index, child) in stack.elements.enumerated() {
                inspectSkeleton(child, path: path + ["v[\(index)]"], report: &report)
            }
        case .ScrollView(let scroll):
            for (index, child) in scroll.elements.enumerated() {
                inspectSkeleton(child, path: path + ["scroll[\(index)]"], report: &report)
            }
        case .Tabs(let tabs):
            if tabs.activeTabStateKeypath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                report.issues.append(StaticSkeletonAuditIssue(severity: .error, detail: "\(pathString(path)) tabs has empty activeTabStateKeypath"))
            }
            if tabs.panels.isEmpty {
                report.issues.append(StaticSkeletonAuditIssue(severity: .error, detail: "\(pathString(path)) tabs has no panels"))
            }
            for panel in tabs.panels {
                for (index, child) in panel.content.enumerated() {
                    inspectSkeleton(child, path: path + ["tab:\(panel.id)", "content[\(index)]"], report: &report)
                }
            }
        case .Grid(let grid):
            for (index, child) in grid.elements.enumerated() {
                inspectSkeleton(child, path: path + ["grid[\(index)]"], report: &report)
            }
        case .ZStack(let stack):
            for (index, child) in stack.elements.enumerated() {
                inspectSkeleton(child, path: path + ["z[\(index)]"], report: &report)
            }
        case .Object(let object):
            for key in object.elements.keys.sorted() {
                if let child = object.elements[key] {
                    inspectSkeleton(child, path: path + ["object.\(key)"], report: &report)
                }
            }
        case .Visualization(let visualization):
            report.visualizationCount += 1
            if visualization.kind.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                report.issues.append(StaticSkeletonAuditIssue(severity: .error, detail: "\(pathString(path)) visualization has empty kind"))
            }
        case .Unsupported:
            report.issues.append(StaticSkeletonAuditIssue(severity: .error, detail: "\(pathString(path)) contains Unsupported skeleton element"))
        case .Spacer, .Image, .Divider:
            break
        }
    }

    private static func inspectInputBinding(
        sourceKeypath: String?,
        targetKeypath: String?,
        staticText: String?,
        elementName: String,
        path: [String],
        report: inout StaticSkeletonAuditReport
    ) {
        let hasSource = sourceKeypath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasTarget = targetKeypath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasStaticText = staticText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        if !hasSource && !hasTarget && !hasStaticText {
            report.issues.append(StaticSkeletonAuditIssue(severity: .error, detail: "\(pathString(path)) \(elementName) has no source, target or static text"))
        } else if hasSource && !hasTarget {
            report.issues.append(StaticSkeletonAuditIssue(severity: .warning, detail: "\(pathString(path)) \(elementName) is source-only; user edits will not be written"))
        }
    }

    private static func inspectVisibleText(
        _ text: String?,
        at path: [String],
        report: inout StaticSkeletonAuditReport
    ) {
        guard let text else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if visibleTextLooksTechnical(trimmed) {
            report.issues.append(
                StaticSkeletonAuditIssue(
                    severity: .warning,
                    detail: "\(pathString(path)) visible text looks technical: \(trimmed)"
                )
            )
        }
    }

    private static func visibleTextLooksTechnical(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        if lowercased.contains("cell:///") ||
            lowercased.contains("sourcekeypath") ||
            lowercased.contains("targetkeypath") ||
            lowercased.contains("dispatchaction") ||
            lowercased.contains("keypath") {
            return true
        }
        return lowercased.contains(".state") ||
            lowercased.contains(".dispatch") ||
            lowercased.contains(".query") ||
            lowercased.contains(".draft")
    }

    private static func pathString(_ path: [String]) -> String {
        path.joined(separator: "/")
    }

    private static func formatStaticSkeletonAudit(_ reports: [StaticSkeletonAuditReport]) -> String {
        let totalIssues = reports.reduce(0) { $0 + $1.issues.count }
        let totalErrors = reports.reduce(0) { count, report in
            count + report.issues.filter { $0.severity == .error }.count
        }
        let totalWarnings = reports.reduce(0) { count, report in
            count + report.issues.filter { $0.severity == .warning }.count
        }
        let header = "Static skeleton audit: \(reports.count) configs, \(totalErrors) errors, \(totalWarnings) warnings, \(totalIssues) total issues"
        let rows = reports.map { report -> String in
            let errorCount = report.issues.filter { $0.severity == .error }.count
            let warningCount = report.issues.filter { $0.severity == .warning }.count
            return "- \(report.configurationName): refs=\(report.referenceCount), elements=\(report.elementCount), buttons=\(report.buttonCount), inputs=\(report.inputCount), selectable=\(report.selectableCount), visualizations=\(report.visualizationCount), errors=\(errorCount), warnings=\(warningCount)"
        }
        let issueRows = reports.flatMap { report in
            report.issues.prefix(6).map { issue in
                "  \(issue.severity.rawValue.uppercased()) \(report.configurationName): \(issue.detail)"
            }
        }
        return ([header] + rows + issueRows).joined(separator: "\n")
    }

    func testPersonalHomeNavigatorCanOpenProfileAuditAndPublishSurfaces() async throws {
        let configuration = ConfigurationCatalogCell.personalHomeMenuConfiguration()
        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)
        guard let navigator = try await context.resolver.cellAtEndpoint(
            endpoint: "cell:///PersonalCopilotNavigator",
            requester: context.owner
        ) as? Meddle else {
            XCTFail("Expected PersonalCopilotNavigator to resolve")
            return
        }

        let expectedCopilotLoad = Task {
            await waitForPortholeLoadBridgeConfiguration(containingName: "Co-Pilot")
        }
        let openCopilotResponse = try await navigator.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("navigator.openCopilot"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        guard let openCopilotResponse else {
            XCTFail("Open Co-Pilot action returned nil response")
            return
        }
        let openCopilotFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: openCopilotResponse)
        }
        XCTAssertNil(openCopilotFailure)

        guard let copilotConfiguration = await expectedCopilotLoad.value else {
            XCTFail("Expected BindingPortholeLoadBridge request for Co-Pilot")
            return
        }
        XCTAssertEqual(copilotConfiguration.name, "Co-Pilot")
        XCTAssertTrue(copilotConfiguration.cellReferences?.contains(where: { $0.label == "chatHub" }) == true)

        let expectedProfileLoad = Task {
            await waitForPortholeLoadBridgeConfiguration(containingName: "My Profile")
        }
        let openProfileResponse = try await navigator.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("navigator.openMyProfile"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        guard let openProfileResponse else {
            XCTFail("Open profile action returned nil response")
            return
        }
        let openProfileFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: openProfileResponse)
        }
        XCTAssertNil(openProfileFailure)

        guard let profileConfiguration = await expectedProfileLoad.value else {
            XCTFail("Expected BindingPortholeLoadBridge request for My Profile")
            return
        }
        XCTAssertEqual(profileConfiguration.name, "My Profile")
        XCTAssertTrue(profileConfiguration.cellReferences?.contains(where: { $0.label == "profileDraft" }) == true)

        let expectedAuditLoad = Task {
            await waitForPortholeLoadBridgeConfiguration(containingName: "Privacy Audit")
        }
        let openAuditResponse = try await navigator.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("navigator.openPrivacyAudit"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        guard let openAuditResponse else {
            XCTFail("Open privacy audit action returned nil response")
            return
        }
        let openAuditFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: openAuditResponse)
        }
        XCTAssertNil(openAuditFailure)

        guard let auditConfiguration = await expectedAuditLoad.value else {
            XCTFail("Expected BindingPortholeLoadBridge request for Privacy Audit")
            return
        }
        XCTAssertEqual(auditConfiguration.name, "Privacy Audit")
        XCTAssertTrue(auditConfiguration.cellReferences?.contains(where: { $0.label == "privacyAudit" }) == true)

        let expectedPublishLoad = Task {
            await waitForPortholeLoadBridgeConfiguration(containingName: "Publish Public Profile")
        }
        let openPublishResponse = try await navigator.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("navigator.openPublishPublicProfile"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        guard let openPublishResponse else {
            XCTFail("Open publish public profile action returned nil response")
            return
        }
        let openPublishFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: openPublishResponse)
        }
        XCTAssertNil(openPublishFailure)

        guard let publishConfiguration = await expectedPublishLoad.value else {
            XCTFail("Expected BindingPortholeLoadBridge request for Publish Public Profile")
            return
        }
        XCTAssertEqual(publishConfiguration.name, "Publish Public Profile")
        XCTAssertTrue(publishConfiguration.cellReferences?.contains(where: { $0.label == "profilePublisher" }) == true)
    }

    func testConferenceShowcaseButtonsCanExecuteWithoutBrokenBindings() async throws {
        let configuration = ConfigurationCatalogCell.conferenceCodexLiveConfigurationsMenuConfiguration()
        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Open demo launcher",
                "Open Claude reference",
                "Participant portal",
                "AI assistant",
                "Control tower",
                "Public surface",
                "Sponsor follow-up",
                "Nearby radar",
                "Participant chat"
            ]
        )

        XCTAssertTrue(report.failedActions.isEmpty, "Expected direct showcase buttons to succeed, got: \(report.failedActions)")
        XCTAssertTrue(report.unresolvedReferences.isEmpty, "Conference showcase should resolve its navigator reference cleanly.")
        XCTAssertTrue(report.unreadableRootProbes.isEmpty, "Conference showcase should not expose unreadable status bindings anymore.")
    }

    func testConferenceShowcaseNavigatorPostsBindingLoadRequests() async throws {
        let configuration = ConfigurationCatalogCell.conferenceCodexLiveConfigurationsMenuConfiguration()
        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        let expectedParticipantLoad = Task {
            await waitForPortholeLoadBridgeConfiguration(containingName: "Conference Participant Portal")
        }
        let openParticipantResponse = try await context.porthole.set(
            keypath: "conferenceNavigator.dispatchAction",
            value: .object([
                "keypath": .string("navigator.openConferenceParticipantPortal"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        guard let openParticipantResponse else {
            XCTFail("Open participant portal action returned nil response")
            return
        }
        let openParticipantFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: openParticipantResponse)
        }
        XCTAssertNil(openParticipantFailure)

        guard let participantConfiguration = await expectedParticipantLoad.value else {
            XCTFail("Expected BindingPortholeLoadBridge request for Conference Participant Portal")
            return
        }
        XCTAssertTrue(participantConfiguration.name.contains("Conference Participant Portal"))
        XCTAssertTrue(participantConfiguration.cellReferences?.contains(where: { $0.label == "conferenceParticipantShell" }) == true)

        let expectedClaudeReferenceLoad = Task {
            await waitForPortholeLoadBridgeConfiguration(containingName: "Conference Claude Design Reference")
        }
        let openClaudeResponse = try await context.porthole.set(
            keypath: "conferenceNavigator.dispatchAction",
            value: .object([
                "keypath": .string("navigator.openConferenceClaudeDesignReference"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        guard let openClaudeResponse else {
            XCTFail("Open Claude reference action returned nil response")
            return
        }
        let openClaudeFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: openClaudeResponse)
        }
        XCTAssertNil(openClaudeFailure)

        guard let claudeConfiguration = await expectedClaudeReferenceLoad.value else {
            XCTFail("Expected BindingPortholeLoadBridge request for Conference Claude Design Reference")
            return
        }
        XCTAssertEqual(claudeConfiguration.name, "Conference Claude Design Reference")
    }

    func testPersonalCopilotInviteChatMatchesStagingAssistantAndPollContract() throws {
        let configuration = ConfigurationCatalogCell.personalInviteChatMenuConfiguration()
        let references = Set((configuration.cellReferences ?? []).map(\.endpoint))

        XCTAssertTrue(references.contains("cell:///PersonalChatHub"))
        XCTAssertTrue(references.contains("cell:///Perspective"))
        XCTAssertFalse(
            CellConfigurationValidationService.validate(configuration).unusedLabels.contains("perspective"),
            "Co-Pilot should use its Perspective reference for scoped context instead of carrying an unused grant."
        )
        XCTAssertEqual(
            CellConfigurationValidationService.validate(configuration).errorCount,
            0
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]
        let data = try encoder.encode(configuration)
        guard let json = String(data: data, encoding: .utf8) else {
            XCTFail("Expected Co-Pilot Chat configuration JSON")
            return
        }

        for expected in [
            "\"keypath\":\"chatHub.assistant.dismissSuggestion\"",
            "\"keypath\":\"chatHub.ui.openSuggestedHelper\"",
            "\"targetKeypath\":\"chatHub.assistant.setCandidateQuery\"",
            "\"selectionActionKeypath\":\"chatHub.assistant.selectCandidate\"",
            "\"selectionPayloadMode\":\"item_id\"",
            "\"selectionStateKeypath\":\"chatHub.state.assistant.latestSuggestion.selectedCandidateProfileID\"",
            "\"targetKeypath\":\"chatHub.inviteDraft.title\"",
            "\"targetKeypath\":\"chatHub.poll.setQuestion\"",
            "\"targetKeypath\":\"chatHub.poll.setOptions\"",
            "\"keypath\":\"chatHub.poll.create\"",
            "\"keypath\":\"chatHub.poll.vote\"",
            "\"keypath\":\"chatHub.poll.close\"",
            "\"keypath\":\"chatHub.idea.capture\"",
            "\"keypath\":\"chatHub.todo.create\"",
            "\"keypath\":\"chatHub.project.create\"",
            "\"keypath\":\"chatHub.reminder.create\"",
            "\"keypath\":\"chatHub.meeting.schedule\"",
            "\"keypath\":\"chatHub.agent.review.create\"",
            "\"keypath\":\"chatHub.capabilityRequest.submit\"",
            "\"keypath\":\"chatHub.ui.setCapabilityDiscoveryEnabled\"",
            "\"keypath\":\"chatHub.unblockUser\"",
            "\"targetKeypath\":\"chatHub.setComposer\"",
            "\"keypath\":\"chatHub.state.assistant.whySummary\"",
            "\"keypath\":\"perspective.perspective.state.activePurposeCount\"",
            "\"keypath\":\"perspective.perspective.state.activeInterestCount\"",
            "\"keypath\":\"perspective.activePurpose.purposes\""
        ] {
            XCTAssertTrue(json.contains(expected), "Co-Pilot Chat JSON missing \(expected)")
        }

        for unwanted in [
            "\"targetKeypath\":\"chatHub.inviteDraft.userUUID\"",
            "\"targetKeypath\":\"chatHub.inviteDraft.profileID\"",
            "Safety status",
            "\"keypath\":\"chatHub.assistant.acceptSuggestion\"",
            "\"keypath\":\"chatHub.state.blockedUsers\"",
            "\"keypath\":\"chatHub.state.purposeWeights\""
        ] {
            XCTAssertFalse(json.contains(unwanted), "Co-Pilot Chat JSON should not expose \(unwanted)")
        }

        XCTAssertFalse(
            json.contains("\"selectionPayloadMode\":\"itemID\""),
            "Selection payload mode must use the CellProtocol wire value item_id, not the Swift case name itemID."
        )
    }

    @MainActor
    func testConferencePreviewCellsStayLocalWhenRetargeting() {
        let contentView = ContentView()

        XCTAssertEqual(
            contentView.maybeRetargetLocalEndpointToStaging("cell:///ConferenceParticipantPreviewShell"),
            "cell:///ConferenceParticipantPreviewShell"
        )
        XCTAssertEqual(
            contentView.maybeRetargetLocalEndpointToStaging("cell:///ConferenceAdminPreviewShell"),
            "cell:///ConferenceAdminPreviewShell"
        )
        XCTAssertEqual(
            contentView.maybeRetargetLocalEndpointToStaging("cell:///ConferenceParticipantDiscoverySnapshot"),
            "cell:///ConferenceParticipantDiscoverySnapshot"
        )
        XCTAssertEqual(
            contentView.maybeRetargetLocalEndpointToStaging("cell:///ConferenceIdentityLinkIntake"),
            "cell:///ConferenceIdentityLinkIntake"
        )
        XCTAssertEqual(
            contentView.maybeRetargetLocalEndpointToStaging("cell:///Chat"),
            "cell://staging.haven.digipomps.org/Chat"
        )
    }

    func testConferenceParticipantPortalContract() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Vis for deg",
                "Vis timeline",
                "Vis lagret",
                "Fokuser governance",
                "Finn governance-matcher",
                "Åpne chatflate"
            ],
            rootProbes: [
                .init(label: "agendaSnapshot", rootKeypath: "state"),
                .init(label: "matchmakingSnapshot", rootKeypath: "state"),
                .init(label: "discoverySnapshot", rootKeypath: "state"),
                .init(label: "nearbyRadar", rootKeypath: "state"),
                .init(label: "chatSnapshot", rootKeypath: "state")
            ]
        )

        XCTAssertEqual(
            report.validation.errorCount,
            0,
            "Validation issues: \(report.validation.issues)"
        )
        XCTAssertTrue(
            report.unresolvedReferences.isEmpty,
            "Unresolved references: \(report.unresolvedReferences)"
        )
        XCTAssertTrue(
            report.unreadableRootProbes.isEmpty,
            "Unreadable root probes: \(report.unreadableRootProbes)"
        )
        XCTAssertTrue(
            report.failedActions.isEmpty,
            "Failed actions: \(report.failedActions)"
        )
    }

    func testConferenceDemoLauncherContract() async throws {
        let configuration = ConfigurationCatalogCell.conferenceDemoLauncherWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Open public surface",
                "Open identity link setup",
                "Open participant cockpit",
                "Open participant chat",
                "Open control tower",
                "Open AI assistant"
            ],
            rootProbes: [
                .init(label: "conferenceDemoLauncher", rootKeypath: "state")
            ]
        )

        XCTAssertEqual(
            report.validation.errorCount,
            0,
            "Validation issues: \(report.validation.issues)"
        )
        XCTAssertTrue(
            report.unresolvedReferences.isEmpty,
            "Unresolved references: \(report.unresolvedReferences)"
        )
        XCTAssertTrue(
            report.unreadableRootProbes.isEmpty,
            "Unreadable root probes: \(report.unreadableRootProbes)"
        )
        XCTAssertTrue(
            report.failedActions.isEmpty,
            "Failed actions: \(report.failedActions)"
        )
    }

    func testSpatialV2InspectorContractLoadsStateAndButton() async throws {
        let configuration = Self.spatialV2InspectorConfiguration()

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Preview native AR adapter"
            ],
            rootProbes: [
                .init(label: "spatial", rootKeypath: "state")
            ]
        )

        XCTAssertEqual(
            report.validation.errorCount,
            0,
            "Validation issues: \(report.validation.issues)"
        )
        XCTAssertTrue(
            report.unresolvedReferences.isEmpty,
            "Unresolved references: \(report.unresolvedReferences)"
        )
        XCTAssertTrue(
            report.unreadableRootProbes.isEmpty,
            "Unreadable root probes: \(report.unreadableRootProbes)"
        )
        XCTAssertTrue(
            report.failedActions.isEmpty,
            "Failed actions: \(report.failedActions)"
        )
        XCTAssertTrue(
            report.actionExecutions.contains { action in
                action.label == "Preview native AR adapter" && action.succeeded
            },
            "Expected Preview native AR adapter button to execute: \(report.actionExecutions)"
        )

        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        let schema = try await context.porthole.get(keypath: "spatial.state.schema", requester: context.owner)
        let anchorId = try await context.porthole.get(keypath: "spatial.state.anchor.anchorId", requester: context.owner)
        let coordinateFrame = try await context.porthole.get(keypath: "spatial.state.anchor.coordinateFrame", requester: context.owner)
        let assetDigest = try await context.porthole.get(keypath: "spatial.state.assetManifest.primaryDigest", requester: context.owner)
        let denialBehavior = try await context.porthole.get(keypath: "spatial.state.accessPolicy.denialBehavior", requester: context.owner)

        XCTAssertEqual(string(schema), "haven.spatial.feature.v2")
        XCTAssertEqual(string(anchorId), "venue-ar-sign")
        XCTAssertEqual(string(coordinateFrame), "wgs84")
        XCTAssertEqual(string(assetDigest), "abc123spatialv2")
        XCTAssertEqual(string(denialBehavior), "structured-denied")
    }

    func testConferenceIdentityLinkContract() async throws {
        let configuration = ConfigurationCatalogCell.conferenceIdentityLinkWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Clear",
                "Back to launcher"
            ],
            rootProbes: [
                .init(label: "identityLink", rootKeypath: "state")
            ]
        )

        XCTAssertEqual(
            report.validation.errorCount,
            0,
            "Validation issues: \(report.validation.issues)"
        )
        XCTAssertTrue(
            report.unresolvedReferences.isEmpty,
            "Unresolved references: \(report.unresolvedReferences)"
        )
        XCTAssertTrue(
            report.unreadableRootProbes.isEmpty,
            "Unreadable root probes: \(report.unreadableRootProbes)"
        )
        XCTAssertTrue(
            report.failedActions.isEmpty,
            "Failed actions: \(report.failedActions)"
        )
    }

    func testConferenceAIAssistantContract() async throws {
        let configuration = ConfigurationCatalogCell.conferenceAIAssistantWorkbenchConfiguration(
            conferenceEndpoint: "cell:///ConferenceParticipantPreviewShell",
            aiEndpoint: "cell:///ConferenceAIAssistantGatewayProxy"
        )

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Hosted API (API key)",
                "No-auth gateway",
                "API key on",
                "API key off",
                "Deterministic on",
                "Deterministic off",
                "Load copilot system prompt",
                "Fill request: Daily brief",
                "Fill request: Who should I meet?",
                "Fill request: Follow-up plan",
                "Fill request: Session priorities"
            ],
            rootProbes: [
                .init(label: "conferenceParticipantShell", rootKeypath: "state"),
                .init(label: "aiGateway", rootKeypath: "state")
            ]
        )

        XCTAssertEqual(
            report.validation.errorCount,
            0,
            "Validation issues: \(report.validation.issues)"
        )
        XCTAssertTrue(
            report.unresolvedReferences.isEmpty,
            "Unresolved references: \(report.unresolvedReferences)"
        )
        XCTAssertTrue(
            report.unreadableRootProbes.isEmpty,
            "Unreadable root probes: \(report.unreadableRootProbes)"
        )
        XCTAssertTrue(
            report.failedActions.isEmpty,
            "Failed actions: \(report.failedActions)"
        )
    }

    func testConferencePublicSurfaceContract() async throws {
        let configuration = ConfigurationCatalogCell.conferencePublicWorkbenchConfiguration(
            endpoint: "cell:///ConferencePublicShellFixture"
        )

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            rootProbes: [
                .init(label: "conferencePublicShell", rootKeypath: "state")
            ]
        )

        XCTAssertEqual(
            report.validation.errorCount,
            0,
            "Validation issues: \(report.validation.issues)"
        )
        XCTAssertTrue(
            report.unresolvedReferences.isEmpty,
            "Unresolved references: \(report.unresolvedReferences)"
        )
        XCTAssertTrue(
            report.unreadableRootProbes.isEmpty,
            "Unreadable root probes: \(report.unreadableRootProbes)"
        )
        XCTAssertTrue(
            report.failedActions.isEmpty,
            "Failed actions: \(report.failedActions)"
        )
    }

    func testConferenceSponsorFollowUpContract() async throws {
        let configuration = ConfigurationCatalogCell.conferenceSponsorWorkbenchConfiguration(
            endpoint: "cell:///ConferenceSponsorShellFixture"
        )

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Refresh inbox",
                "Prepare export",
                "Run retention sweep"
            ],
            rootProbes: [
                .init(label: "conferenceSponsorShell", rootKeypath: "state")
            ]
        )

        XCTAssertEqual(
            report.validation.errorCount,
            0,
            "Validation issues: \(report.validation.issues)"
        )
        XCTAssertTrue(
            report.unresolvedReferences.isEmpty,
            "Unresolved references: \(report.unresolvedReferences)"
        )
        XCTAssertTrue(
            report.unreadableRootProbes.isEmpty,
            "Unreadable root probes: \(report.unreadableRootProbes)"
        )
        XCTAssertTrue(
            report.failedActions.isEmpty,
            "Failed actions: \(report.failedActions)"
        )
    }

    func testConferenceControlTowerContract() async throws {
        let configuration = ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
            endpoint: "cell:///ConferenceAdminPreviewShell"
        )

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Publish content",
                "Discard draft"
            ]
        )

        XCTAssertEqual(
            report.validation.errorCount,
            0,
            "Validation issues: \(report.validation.issues)"
        )
        XCTAssertTrue(
            report.unresolvedReferences.isEmpty,
            "Unresolved references: \(report.unresolvedReferences)"
        )
        XCTAssertTrue(
            report.unreadableRootProbes.isEmpty,
            "Unreadable root probes: \(report.unreadableRootProbes)"
        )
        XCTAssertTrue(
            report.failedActions.isEmpty,
            "Failed actions: \(report.failedActions)"
        )
    }

    func testConferenceNearbyRadarContract() async throws {
        let configuration = ConfigurationCatalogCell.conferenceNearbyRadarWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Start scanner",
                "Stop scanner",
                "Tilbake til portalen"
            ],
            rootProbes: [
                .init(label: "nearbyRadar", rootKeypath: "state")
            ]
        )

        XCTAssertEqual(report.validation.errorCount, 0, "Validation issues: \(report.validation.issues)")
        XCTAssertTrue(report.unresolvedReferences.isEmpty, "Unresolved references: \(report.unresolvedReferences)")
        XCTAssertTrue(report.unreadableRootProbes.isEmpty, "Unreadable root probes: \(report.unreadableRootProbes)")
        XCTAssertTrue(report.failedActions.isEmpty, "Failed actions: \(report.failedActions)")
    }

    func testConferenceNearbyParticipantProfileContract() async throws {
        let configuration = ConfigurationCatalogCell.conferenceNearbyParticipantWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Åpne full radar",
                "Tilbake til portalen"
            ],
            rootProbes: [
                .init(label: "nearbyRadar", rootKeypath: "state")
            ]
        )

        XCTAssertEqual(report.validation.errorCount, 0, "Validation issues: \(report.validation.issues)")
        XCTAssertTrue(report.unresolvedReferences.isEmpty, "Unresolved references: \(report.unresolvedReferences)")
        XCTAssertTrue(report.unreadableRootProbes.isEmpty, "Unreadable root probes: \(report.unreadableRootProbes)")
        XCTAssertTrue(report.failedActions.isEmpty, "Failed actions: \(report.failedActions)")
    }

    func testConferenceParticipantChatContract() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantChatWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Tilbake til portalen"
            ],
            rootProbes: [
                .init(label: "conferenceChat", rootKeypath: "state")
            ]
        )

        XCTAssertEqual(report.validation.errorCount, 0, "Validation issues: \(report.validation.issues)")
        XCTAssertTrue(report.unresolvedReferences.isEmpty, "Unresolved references: \(report.unresolvedReferences)")
        XCTAssertTrue(report.unreadableRootProbes.isEmpty, "Unreadable root probes: \(report.unreadableRootProbes)")
        XCTAssertTrue(report.failedActions.isEmpty, "Failed actions: \(report.failedActions)")
    }

    func testConferenceParticipantNearbyFollowUpContract() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )

        let report = try await CellConfigurationVerifier.nearbyFollowUpReport(for: configuration)

        XCTAssertEqual(report.startOutcome, "ok")
        XCTAssertEqual(report.statusAfterStart, "started")
        XCTAssertEqual(report.requestContactOutcome, "ok")
        XCTAssertTrue(report.requestContactLabel.map { ["Kontakt venter", "Awaiting exchange"].contains($0) } == true)
        XCTAssertTrue(report.requestContactSummary.map { [
            "Signert kontaktforespørsel sendt. Venter på godkjenning.",
            "Signed contact request sent. Awaiting signed identity exchange."
        ].contains($0) } == true)
        XCTAssertTrue(report.requestContactActionSummary.map { [
            "Signert kontaktforespørsel sendt. Venter på godkjenning.",
            "Signed contact request sent. Awaiting signed identity exchange."
        ].contains($0) } == true)
        XCTAssertEqual(report.openChatOutcome, "ok")
        XCTAssertEqual(report.nearbyCardLabel, "Åpne chatflate")
        XCTAssertTrue(report.nearbyCardPurposeSummary?.contains("verified overlap") == true)
        XCTAssertEqual(report.nearbyActionSummary, "Startet conference-chat med Nora Berg.")
        XCTAssertEqual(report.workspaceNextStep, "Started follow-up chat with Nora Berg in local preview.")
        XCTAssertEqual(report.sharedChatSummary, "2 shared message(s) visible.")
        XCTAssertEqual(report.firstRecentMessage, "Ja, gjerne. Jobber med tillit, relasjoner og hvordan identitet og oppfølging kan flyte mellom team. Hvis du vil, kan vi ta et kort neste steg etter sesjonen.")
        XCTAssertEqual(report.stopOutcome, "ok")
        XCTAssertEqual(report.statusAfterStop, "stopped")
    }

    func testConferenceParticipantPreviewRecommendationFocusAndFollowUpActions() async throws {
        let (resolver, identity) = try await makeLocalConferenceRuntimeContext()
        guard let preview = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: identity
        ) as? Meddle else {
            XCTFail("ConferenceParticipantPreviewShell did not resolve as Meddle")
            return
        }

        _ = try await preview.set(
            keypath: "dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("agenda.setView"),
                "payload": ValueType.object([
                    "view": ValueType.string("timeline")
                ])
            ]),
            requester: identity
        )

        _ = try await preview.set(
            keypath: "dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("agenda.setTrackFocus"),
                "payload": ValueType.object([
                    "trackId": ValueType.string("track-governance")
                ])
            ]),
            requester: identity
        )

        _ = try await preview.set(
            keypath: "dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("matchmaking.focusPerson"),
                "payload": ValueType.object([
                    "displayName": ValueType.string("Ane Solberg"),
                    "subtitle": ValueType.string("Public sector interoperability")
                ])
            ]),
            requester: identity
        )

        _ = try await preview.set(
            keypath: "dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("matchmaking.toggleFollowUp"),
                "payload": ValueType.object([
                    "displayName": ValueType.string("Governance Forum"),
                    "subtitle": ValueType.string("Nearby people")
                ])
            ]),
            requester: identity
        )

        let stateValue = try await preview.get(keypath: "state", requester: identity)
        guard case let .object(stateObject) = stateValue else {
            XCTFail("Expected state object from conference participant preview fallback")
            return
        }
        guard let workspaceValue = stateObject["workspace"],
              case let .object(workspace) = workspaceValue else {
            XCTFail("Expected workspace object from conference participant preview fallback")
            return
        }
        guard let programValue = stateObject["program"],
              case let .object(program) = programValue else {
            XCTFail("Expected program object from conference participant preview fallback")
            return
        }
        guard let matchesValue = stateObject["matches"],
              case let .object(matches) = matchesValue else {
            XCTFail("Expected matches object from conference participant preview fallback")
            return
        }

        XCTAssertEqual(workspace["nextStep"], ValueType.string("Marked Governance Forum for follow-up in local preview."))
        XCTAssertEqual(program["viewSummary"], ValueType.string("Current view: Timeline."))
        XCTAssertEqual(program["trackSummary"], ValueType.string("Track focus: Governance."))
        XCTAssertEqual(program["timelineSummary"], ValueType.string("8 session(s) visible in timeline view."))
        XCTAssertEqual(matches["recommendationSummary"], ValueType.string("Focused recommendation: Ane Solberg. Open chat or mark follow-up when you are ready."))
        XCTAssertEqual(matches["status"], ValueType.string("Focused on Ane Solberg. The next natural step is to start chat or mark follow-up."))
        XCTAssertEqual(matches["searchSummary"], ValueType.string("Search broadening: people. 1 person(s) marked for follow-up."))

        guard let recommendationsValue = matches["recommendations"],
              case let .list(recommendations) = recommendationsValue,
              case let .object(firstRecommendation)? = recommendations.first else {
            XCTFail("Expected recommendations list in preview fallback state")
            return
        }
        XCTAssertEqual(firstRecommendation["label"], ValueType.string("Start chat"))

        guard let searchResultsValue = matches["searchResults"],
              case let .list(searchResults) = searchResultsValue,
              case let .object(firstSearchResult)? = searchResults.first else {
            XCTFail("Expected search results list in preview fallback state")
            return
        }
        XCTAssertEqual(firstSearchResult["label"], ValueType.string("Fjern markering"))
    }

    func testConferenceParticipantMatchmakingSnapshotSupportsInlineSelectionAndActions() async throws {
        let (resolver, identity) = try await makeLocalConferenceRuntimeContext()
        guard let snapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantMatchmakingSnapshot",
            requester: identity
        ) as? Meddle else {
            XCTFail("ConferenceParticipantMatchmakingSnapshot did not resolve as Meddle")
            return
        }

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("matchmaking.focusPerson"),
                "payload": ValueType.object([
                    "displayName": ValueType.string("Ane Solberg"),
                    "subtitle": ValueType.string("Public sector interoperability")
                ])
            ]),
            requester: identity
        )

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("matchmaking.toggleFollowUp"),
                "payload": ValueType.object([
                    "displayName": ValueType.string("Ane Solberg"),
                    "subtitle": ValueType.string("Public sector interoperability")
                ])
            ]),
            requester: identity
        )

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("discovery.startChat"),
                "payload": ValueType.object([
                    "source": ValueType.string("binding-test"),
                    "targets": ValueType.list([
                        ValueType.object([
                            "displayName": ValueType.string("Ane Solberg"),
                            "headline": ValueType.string("Public sector interoperability")
                        ])
                    ])
                ])
            ]),
            requester: identity
        )

        let stateValue = try await snapshot.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue else {
            XCTFail("Expected object from matchmaking snapshot")
            return
        }
        guard let focusedProfileValue = object["focusedProfile"],
              case let .object(focusedProfile) = focusedProfileValue,
              let focusedActionsValue = object["focusedActions"],
              case let .list(focusedActions) = focusedActionsValue,
              let recommendationsValue = object["recommendations"],
              case let .list(recommendations) = recommendationsValue,
              case let .object(firstRecommendation)? = recommendations.first else {
            XCTFail("Expected focused profile, actions, and recommendations in matchmaking snapshot")
            return
        }

        XCTAssertEqual(object["selectionSummary"], ValueType.string("Viser Ane Solberg i denne siden."))
        XCTAssertEqual(focusedProfile["title"], ValueType.string("Ane Solberg"))
        XCTAssertEqual(focusedProfile["publicProfileSummary"], ValueType.string("Offentlig profil: Public sector interoperability."))
        XCTAssertEqual(
            focusedProfile["nextStep"],
            ValueType.string("Åpne chatflaten eller be om møte med Ane Solberg.")
        )
        XCTAssertEqual(firstRecommendation["label"], ValueType.string("Valgt i siden"))

        guard case let .object(chatAction)? = focusedActions.first,
              case let .object(followUpAction)? = focusedActions.dropFirst().first,
              case let .object(meetingAction)? = focusedActions.dropFirst(2).first else {
            XCTFail("Expected three focused actions")
            return
        }

        XCTAssertEqual(chatAction["label"], ValueType.string("Åpne chatflate"))
        XCTAssertEqual(followUpAction["label"], ValueType.string("Fjern markering"))
        XCTAssertEqual(meetingAction["label"], ValueType.string("Be om møte"))

        guard let preview = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: identity
        ) as? Meddle else {
            XCTFail("ConferenceParticipantPreviewShell did not resolve as Meddle")
            return
        }

        let previewState = try await preview.get(keypath: "state", requester: identity)
        guard case let .object(previewObject) = previewState,
              case let .object(sharedConnections)? = previewObject["sharedConnections"],
              case let .list(connections)? = sharedConnections["connections"],
              case let .object(firstConnection)? = connections.first else {
            XCTFail("Expected shared connection after start chat")
            return
        }

        XCTAssertEqual(sharedConnections["connectionSummary"], ValueType.string("1 shared relation(s) visible."))
        XCTAssertEqual(sharedConnections["chatSummary"], ValueType.string("2 shared message(s) visible."))
        XCTAssertEqual(firstConnection["title"], ValueType.string("Ane Solberg"))

        guard let chatSnapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantChatSnapshot",
            requester: identity
        ) as? Meddle else {
            XCTFail("ConferenceParticipantChatSnapshot did not resolve as Meddle")
            return
        }

        let chatState = try await chatSnapshot.get(keypath: "state", requester: identity)
        guard case let .object(chatObject) = chatState,
              case let .object(focusedThread)? = chatObject["focusedThread"] else {
            XCTFail("Expected chat snapshot state after start chat")
            return
        }

        XCTAssertEqual(chatObject["selectionSummary"], ValueType.string("Viser den delte tråden med Ane Solberg."))
        XCTAssertEqual(focusedThread["title"], ValueType.string("Ane Solberg"))
    }

    func testConferenceParticipantPortalSearchGovernanceButtonUsesRendererExecutionPath() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )
        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        let response = try await context.porthole.set(
            keypath: "matchmakingSnapshot.dispatchAction",
            value: .object([
                "keypath": .string("matchmaking.searchPeople"),
                "payload": .object(["query": .string("governance")])
            ]),
            requester: context.owner
        )
        XCTAssertNotNil(response, "Renderer button path returned nil for Finn governance-matcher")
        if let response {
            XCTAssertNil(
                SkeletonBindingProbeSupport.failureDetail(from: response),
                "Renderer button path returned failure payload for Finn governance-matcher: \(response)"
            )
        }

        let actionSummary = try await context.porthole.get(
            keypath: "matchmakingSnapshot.state.actionSummary",
            requester: context.owner
        )
        XCTAssertEqual(actionSummary, .string("Viser governance-relevante personer i anbefalingene."))

        let searchSummary = try await context.porthole.get(
            keypath: "matchmakingSnapshot.state.searchSummary",
            requester: context.owner
        )
        if case let .string(searchSummaryText) = searchSummary {
            XCTAssertTrue(
                searchSummaryText.localizedCaseInsensitiveContains("governance"),
                "Expected governance-focused search summary, got: \(searchSummaryText)"
            )
        } else {
            XCTFail("Expected string searchSummary after Finn governance-matcher, got \(searchSummary)")
        }
    }

    func testConferenceParticipantDiscoverySnapshotSupportsInlineSelectionAndActions() async throws {
        let (resolver, identity) = try await makeLocalConferenceRuntimeContext()
        guard let snapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantDiscoverySnapshot",
            requester: identity
        ) as? Meddle else {
            XCTFail("ConferenceParticipantDiscoverySnapshot did not resolve as Meddle")
            return
        }

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("discovery.focusPerson"),
                "payload": ValueType.object([
                    "displayName": ValueType.string("Ane Solberg"),
                    "subtitle": ValueType.string("Public sector interoperability")
                ])
            ]),
            requester: identity
        )

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("matchmaking.toggleFollowUp"),
                "payload": ValueType.object([
                    "displayName": ValueType.string("Ane Solberg"),
                    "subtitle": ValueType.string("Public sector interoperability")
                ])
            ]),
            requester: identity
        )

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("discovery.startChat"),
                "payload": ValueType.object([
                    "source": ValueType.string("binding-test"),
                    "targets": ValueType.list([
                        ValueType.object([
                            "displayName": ValueType.string("Ane Solberg"),
                            "headline": ValueType.string("Public sector interoperability")
                        ])
                    ])
                ])
            ]),
            requester: identity
        )

        let stateValue = try await snapshot.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue else {
            XCTFail("Expected object from discovery snapshot")
            return
        }
        guard let focusedProfileValue = object["focusedProfile"],
              case let .object(focusedProfile) = focusedProfileValue,
              let focusedActionsValue = object["focusedActions"],
              case let .list(focusedActions) = focusedActionsValue,
              let candidatesValue = object["candidates"],
              case let .list(candidates) = candidatesValue,
              case let .object(firstCandidate)? = candidates.first else {
            XCTFail("Expected focused discovery state")
            return
        }

        XCTAssertEqual(object["selectionSummary"], ValueType.string("Viser Ane Solberg i discovery-delen."))
        XCTAssertEqual(focusedProfile["title"], ValueType.string("Ane Solberg"))
        XCTAssertEqual(firstCandidate["label"], ValueType.string("Åpne chatflate"))

        guard case let .object(chatAction)? = focusedActions.first,
              case let .object(followUpAction)? = focusedActions.dropFirst().first,
              case let .object(meetingAction)? = focusedActions.dropFirst(2).first else {
            XCTFail("Expected three focused discovery actions")
            return
        }

        XCTAssertEqual(chatAction["label"], ValueType.string("Åpne chatflate"))
        XCTAssertEqual(followUpAction["label"], ValueType.string("Fjern markering"))
        XCTAssertEqual(meetingAction["label"], ValueType.string("Be om møte"))
    }

    func testConferenceParticipantAgendaSnapshotSupportsInlineSelectionAndActions() async throws {
        let (resolver, identity) = try await makeLocalConferenceRuntimeContext()
        guard let snapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantAgendaSnapshot",
            requester: identity
        ) as? Meddle else {
            XCTFail("ConferenceParticipantAgendaSnapshot did not resolve as Meddle")
            return
        }

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("agenda.setView"),
                "payload": .object([
                    "view": .string("timeline")
                ])
            ]),
            requester: identity
        )

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("agenda.setTrackFocus"),
                "payload": .object([
                    "trackId": .string("track-governance")
                ])
            ]),
            requester: identity
        )

        let stateValue = try await snapshot.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue,
              case let .list(modeChoices)? = object["modeChoices"],
              case let .object(firstModeChoice)? = modeChoices.first,
              case let .object(secondModeChoice)? = modeChoices.dropFirst().first,
              case let .list(trackChoices)? = object["trackChoices"],
              case let .object(firstTrackChoice)? = trackChoices.first,
              case let .object(secondTrackChoice)? = trackChoices.dropFirst().first,
              case let .list(trackOptions)? = object["trackOptions"],
              case let .object(firstTrackOption)? = trackOptions.first,
              case let .object(thirdTrackOption)? = trackOptions.dropFirst(2).first,
              case let .list(recommendedSessions)? = object["recommendedSessions"],
              case let .object(firstRecommendedSession)? = recommendedSessions.first,
              case let .list(timelineSessions)? = object["timelineSessions"],
              case let .object(firstTimelineSession)? = timelineSessions.first else {
            XCTFail("Expected agenda snapshot state with choices and session cards")
            return
        }

        XCTAssertEqual(object["statusSummary"], ValueType.string("Viser timeline med governance i fokus."))
        XCTAssertEqual(object["selectionSummary"], ValueType.string("Viser timeline med Governance i fokus."))
        XCTAssertEqual(object["actionSummary"], ValueType.string("Governance er nå i fokus i denne siden."))
        XCTAssertEqual(firstModeChoice["label"], ValueType.string("Vis for deg"))
        XCTAssertEqual(secondModeChoice["selectionBadge"], ValueType.string("AKTIV NÅ"))
        XCTAssertEqual(secondModeChoice["label"], ValueType.string("Viser nå"))
        XCTAssertEqual(firstTrackChoice["label"], ValueType.string("Vis alle spor"))
        XCTAssertEqual(secondTrackChoice["selectionBadge"], ValueType.string("FOKUS NÅ"))
        XCTAssertEqual(secondTrackChoice["label"], ValueType.string("Viser nå"))
        XCTAssertEqual(firstTrackOption["selectionBadge"], ValueType.string("SPOR"))
        XCTAssertEqual(thirdTrackOption["selectionBadge"], ValueType.string("AKTIVT FOKUS"))
        XCTAssertEqual(firstRecommendedSession["selectionBadge"], ValueType.string("FOR DEG"))
        XCTAssertEqual(firstTimelineSession["selectionBadge"], ValueType.string("VISES NÅ"))
    }

    func testConferenceParticipantPortalProxyActionsCanOpenChatWorkbench() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )
        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        let focusResponse = try await context.porthole.set(
            keypath: "matchmakingSnapshot.dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("matchmaking.focusRecommendationAtIndex"),
                "payload": ValueType.object([
                    "index": ValueType.integer(0)
                ])
            ]),
            requester: context.owner
        )
        guard let focusResponse else {
            XCTFail("Focus action returned nil response")
            return
        }
        let focusFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: focusResponse)
        }
        XCTAssertNil(focusFailure)

        let focusedTitle = try await context.porthole.get(
            keypath: "matchmakingSnapshot.state.focusedProfile.title",
            requester: context.owner
        )
        XCTAssertEqual(focusedTitle, ValueType.string("Ane Solberg"))

        let chatStartResponse = try await context.porthole.set(
            keypath: "matchmakingSnapshot.dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("discovery.startChatWithFocusedPerson"),
                "payload": ValueType.bool(true)
            ]),
            requester: context.owner
        )
        guard let chatStartResponse else {
            XCTFail("Start chat action returned nil response")
            return
        }
        let chatStartFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: chatStartResponse)
        }
        XCTAssertNil(chatStartFailure)

        let chatActionLabel = try await context.porthole.get(
            keypath: "matchmakingSnapshot.state.focusedActions[0].label",
            requester: context.owner
        )
        XCTAssertEqual(chatActionLabel, ValueType.string("Åpne chatflate"))

        let nextStepSummary = try await context.porthole.get(
            keypath: "matchmakingSnapshot.state.nextStepSummary",
            requester: context.owner
        )
        XCTAssertEqual(
            nextStepSummary,
            ValueType.string("Chatten med Ane Solberg er klar. Neste steg er å åpne chatflaten eller be om møte.")
        )

        let expectedWorkbenchLoad = Task {
            await waitForPortholeLoadBridgeConfiguration(containingName: "Conference Participant Chat")
        }
        let openChatResponse = try await context.porthole.set(
            keypath: "chatSnapshot.dispatchAction",
            value: ValueType.object([
                "keypath": ValueType.string("openChatWorkbenchForSelectedParticipant"),
                "payload": ValueType.bool(true)
            ]),
            requester: context.owner
        )
        guard let openChatResponse else {
            XCTFail("Open chat workbench action returned nil response")
            return
        }
        let openChatFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: openChatResponse)
        }
        XCTAssertNil(openChatFailure)

        guard let configuration = await expectedWorkbenchLoad.value else {
            let actionSummaryValue = try? await context.porthole.get(
                keypath: "chatSnapshot.state.actionSummary",
                requester: context.owner
            )
            let statusSummaryValue = try? await context.porthole.get(
                keypath: "chatSnapshot.state.statusSummary",
                requester: context.owner
            )

            XCTFail(
                """
                Expected BindingPortholeLoadBridge request for Conference Participant Chat.
                actionSummary=\(String(describing: actionSummaryValue))
                statusSummary=\(String(describing: statusSummaryValue))
                """
            )
            return
        }
        XCTAssertTrue(configuration.name.contains("Conference Participant Chat"))
        XCTAssertTrue(configuration.cellReferences?.contains(where: { $0.label == "conferenceChat" }) == true)

        guard let preview = try await context.resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: context.owner
        ) as? Meddle else {
            XCTFail("ConferenceParticipantPreviewShell did not resolve after opening chat workbench")
            return
        }
        guard let conferenceChat = try await context.resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceChatLaunch",
            requester: context.owner
        ) as? Meddle else {
            XCTFail("ConferenceChatLaunch did not resolve after opening chat workbench")
            return
        }

        let previewState = try await preview.get(keypath: "state", requester: context.owner)
        guard case let .object(previewObject) = previewState,
              case let .object(sharedConnections)? = previewObject["sharedConnections"] else {
            XCTFail("Expected preview state with sharedConnections after opening chat workbench")
            return
        }

        XCTAssertEqual(sharedConnections["connectionSummary"], ValueType.string("1 shared relation(s) visible."))
        XCTAssertEqual(sharedConnections["chatSummary"], ValueType.string("2 shared message(s) visible."))

        let chatState = try await conferenceChat.get(keypath: "state", requester: context.owner)
        guard case let .object(chatObject) = chatState,
              case let .list(participants)? = chatObject["participants"],
              case let .list(conversations)? = chatObject["conversations"],
              case let .list(messages)? = chatObject["messages"],
              case let .object(firstParticipant)? = participants.first,
              case let .object(firstConversation)? = conversations.first,
              case let .object(firstMessage)? = messages.first else {
            XCTFail("Expected populated chat snapshot after opening chat workbench")
            return
        }

        XCTAssertEqual(chatObject["headline"], ValueType.string("Chat with Ane Solberg"))
        XCTAssertEqual(chatObject["conversationSummary"], ValueType.string("1 shared relation(s) visible."))
        XCTAssertEqual(chatObject["participantsSummary"], ValueType.string("Delt tråd aktiv med Ane Solberg."))
        XCTAssertEqual(chatObject["messageSummary"], ValueType.string("2 meldinger synlige i tråden med Ane Solberg, eldste først."))
        XCTAssertEqual(chatObject["bridgeSummary"], ValueType.string("HAVEN local adapter exposing ConferenceChatLaunch-style bindings over shared relation-state."))
        XCTAssertEqual(chatObject["editorDraft"], ValueType.string("Hei Ane. Jeg vil gjerne snakke mer om governance-sporet og hvordan du jobber med interoperabilitet i praksis."))
        XCTAssertEqual(firstParticipant["title"], ValueType.string("Deg"))
        XCTAssertEqual(firstConversation["title"], ValueType.string("Ane Solberg"))
        XCTAssertEqual(firstMessage["title"], ValueType.string("Deg"))

        _ = try await conferenceChat.set(
            keypath: "setDraft",
            value: .object(["text": .string("Hei Ane.  Jeg vil gjerne snakke mer om governance-sporet etter neste sesjon.  ")]),
            requester: context.owner
        )

        let draftAfterTyping = try await conferenceChat.get(keypath: "state", requester: context.owner)
        guard case let .object(draftStateObject) = draftAfterTyping else {
            XCTFail("Expected chat snapshot state after updating draft")
            return
        }
        XCTAssertEqual(
            draftStateObject["editorDraft"],
            ValueType.string("Hei Ane.  Jeg vil gjerne snakke mer om governance-sporet etter neste sesjon.  ")
        )

        let sendResponse = try await conferenceChat.set(
            keypath: "sendMessage",
            value: .bool(true),
            requester: context.owner
        )
        guard let sendResponse else {
            XCTFail("Send draft message action returned nil response")
            return
        }
        let sendFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: sendResponse)
        }
        XCTAssertNil(sendFailure)

        let updatedPreviewState = try await preview.get(keypath: "state", requester: context.owner)
        guard case let .object(updatedPreviewObject) = updatedPreviewState,
              case let .object(updatedSharedConnections)? = updatedPreviewObject["sharedConnections"],
              case let .list(updatedMessages)? = updatedSharedConnections["recentMessages"],
              case let .object(latestReply)? = updatedMessages.first,
              case let .object(latestOutgoing)? = updatedMessages.dropFirst().first else {
            XCTFail("Expected populated shared chat messages after sending custom draft")
            return
        }

        XCTAssertEqual(updatedSharedConnections["chatSummary"], ValueType.string("4 shared message(s) visible."))
        XCTAssertEqual(latestReply["title"], ValueType.string("Ane Solberg"))
        XCTAssertEqual(
            latestReply["detail"],
            ValueType.string("Ja, governance er fortsatt mest relevant for meg. Hvis du vil, kan vi gjøre det konkret og se på neste steg rett etter sesjonen.")
        )
        XCTAssertEqual(latestOutgoing["title"], ValueType.string("Deg"))
        XCTAssertEqual(
            latestOutgoing["detail"],
            ValueType.string("Hei Ane.  Jeg vil gjerne snakke mer om governance-sporet etter neste sesjon.")
        )

        let updatedChatState = try await conferenceChat.get(keypath: "state", requester: context.owner)
        guard case let .object(updatedChatObject) = updatedChatState else {
            XCTFail("Expected updated chat snapshot state after sending custom draft")
            return
        }
        XCTAssertEqual(updatedChatObject["editorDraft"], ValueType.string(""))
        XCTAssertEqual(
            updatedChatObject["messageSummary"],
            ValueType.string("4 meldinger synlige i tråden med Ane Solberg, eldste først.")
        )

        let expectedPortalPop = Task {
            await waitForConferenceNavigationPopFallbackConfiguration(containingName: "Conference Participant Portal")
        }
        let returnResponse = try await conferenceChat.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("openParticipantPortalWorkbench"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        guard let returnResponse else {
            XCTFail("Return to participant portal action returned nil response")
            return
        }
        let returnFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: returnResponse)
        }
        XCTAssertNil(returnFailure)

        guard let participantPortalConfiguration = await expectedPortalPop.value else {
            XCTFail("Expected BindingConferenceNavigationBridge pop request for Conference Participant Portal")
            return
        }
        XCTAssertTrue(participantPortalConfiguration.name.contains("Conference Participant Portal"))

        let focusedTitleAfterReturn = try await context.porthole.get(
            keypath: "matchmakingSnapshot.state.focusedProfile.title",
            requester: context.owner
        )
        XCTAssertEqual(focusedTitleAfterReturn, ValueType.string("Ane Solberg"))
    }

    func testConferenceParticipantChatWorkbenchWarmsThreadFromSelectedParticipant() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )
        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        _ = try await context.porthole.set(
            keypath: "matchmakingSnapshot.dispatchAction",
            value: .object([
                "keypath": .string("matchmaking.focusPerson"),
                "payload": .object([
                    "displayName": .string("Ane Solberg"),
                    "subtitle": .string("Public sector interoperability")
                ])
            ]),
            requester: context.owner
        )

        let expectedWorkbenchLoad = Task {
            await waitForPortholeLoadBridgeConfiguration(containingName: "Conference Participant Chat")
        }
        let openChatResponse = try await context.porthole.set(
            keypath: "chatSnapshot.dispatchAction",
            value: .object([
                "keypath": .string("openChatWorkbench"),
                "payload": .object([
                    "displayName": .string("Ane Solberg"),
                    "subtitle": .string("Public sector interoperability")
                ])
            ]),
            requester: context.owner
        )
        guard let openChatResponse else {
            XCTFail("Open chat workbench action returned nil response")
            return
        }
        let openChatFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: openChatResponse)
        }
        XCTAssertNil(openChatFailure)

        guard let workbenchConfiguration = await expectedWorkbenchLoad.value else {
            let actionSummaryValue = try? await context.porthole.get(
                keypath: "chatSnapshot.state.actionSummary",
                requester: context.owner
            )
            let statusSummaryValue = try? await context.porthole.get(
                keypath: "chatSnapshot.state.statusSummary",
                requester: context.owner
            )
            XCTFail(
                """
                Expected BindingPortholeLoadBridge request for Conference Participant Chat after warming thread.
                actionSummary=\(String(describing: actionSummaryValue))
                statusSummary=\(String(describing: statusSummaryValue))
                """
            )
            return
        }
        XCTAssertTrue(workbenchConfiguration.name.contains("Conference Participant Chat"))
        XCTAssertTrue(workbenchConfiguration.cellReferences?.contains(where: { $0.label == "conferenceChat" }) == true)

        guard let preview = try await context.resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: context.owner
        ) as? Meddle else {
            XCTFail("ConferenceParticipantPreviewShell did not resolve after warming chat workbench")
            return
        }
        let previewState = try await preview.get(keypath: "state", requester: context.owner)
        guard case let .object(previewObject) = previewState,
              case let .object(sharedConnections)? = previewObject["sharedConnections"] else {
            XCTFail("Expected preview state with sharedConnections after warming chat workbench")
            return
        }

        XCTAssertEqual(sharedConnections["connectionSummary"], ValueType.string("1 shared relation(s) visible."))
        XCTAssertEqual(sharedConnections["chatSummary"], ValueType.string("2 shared message(s) visible."))

        guard let conferenceChat = try await context.resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceChatLaunch",
            requester: context.owner
        ) as? Meddle else {
            XCTFail("ConferenceChatLaunch did not resolve after warming chat workbench")
            return
        }
        let chatState = try await conferenceChat.get(keypath: "state", requester: context.owner)
        guard case let .object(chatObject) = chatState else {
            XCTFail("Expected chat state after warming chat workbench")
            return
        }
        XCTAssertEqual(chatObject["launchSummary"], ValueType.string("Viser den delte tråden med Ane Solberg."))
    }

    func testConferenceDemoLauncherCanOpenIdentityLinkSetup() async throws {
        let configuration = ConfigurationCatalogCell.conferenceDemoLauncherWorkbenchConfiguration()
        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        let expectedIdentityLinkLoad = Task {
            await waitForPortholeLoadBridgeConfiguration(containingName: "Conference Scaffold Setup & Identity Link")
        }
        let openIdentityLinkResponse = try await context.porthole.set(
            keypath: "conferenceDemoLauncher.dispatchAction",
            value: .object([
                "keypath": .string("launcher.openIdentityLink"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        guard let openIdentityLinkResponse else {
            XCTFail("Open identity link action returned nil response")
            return
        }
        let openIdentityLinkFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: openIdentityLinkResponse)
        }
        XCTAssertNil(openIdentityLinkFailure)

        guard let identityLinkConfiguration = await expectedIdentityLinkLoad.value else {
            XCTFail("Expected BindingPortholeLoadBridge request for Conference Scaffold Setup & Identity Link")
            return
        }
        XCTAssertTrue(identityLinkConfiguration.name.contains("Conference Scaffold Setup & Identity Link"))
        XCTAssertTrue(identityLinkConfiguration.cellReferences?.contains(where: { $0.label == "identityLink" }) == true)
    }

    func testConferenceDemoLauncherCanOpenPublicSurfaceAndControlTower() async throws {
        let configuration = ConfigurationCatalogCell.conferenceDemoLauncherWorkbenchConfiguration()
        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        let expectedPublicSurfaceLoad = Task {
            await waitForPortholeLoadBridgeConfiguration(containingName: "Conference Public Surface")
        }
        let openPublicSurfaceResponse = try await context.porthole.set(
            keypath: "conferenceDemoLauncher.dispatchAction",
            value: .object([
                "keypath": .string("launcher.openPublicSurface"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        guard let openPublicSurfaceResponse else {
            XCTFail("Open public surface action returned nil response")
            return
        }
        let openPublicSurfaceFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: openPublicSurfaceResponse)
        }
        XCTAssertNil(openPublicSurfaceFailure)

        guard let publicSurfaceConfiguration = await expectedPublicSurfaceLoad.value else {
            XCTFail("Expected BindingPortholeLoadBridge request for Conference Public Surface")
            return
        }
        XCTAssertTrue(publicSurfaceConfiguration.name.contains("Conference Public Surface"))
        XCTAssertTrue(publicSurfaceConfiguration.cellReferences?.contains(where: { $0.label == "conferencePublicShell" }) == true)
        XCTAssertTrue(publicSurfaceConfiguration.cellReferences?.contains(where: {
            $0.label == "conferencePublicShell" && $0.endpoint == "cell:///ConferencePublicShellFixture"
        }) == true)

        let expectedControlTowerLoad = Task {
            await waitForPortholeLoadBridgeConfiguration(containingName: "Conference Control Tower")
        }
        let openControlTowerResponse = try await context.porthole.set(
            keypath: "conferenceDemoLauncher.dispatchAction",
            value: .object([
                "keypath": .string("launcher.openControlTower"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        guard let openControlTowerResponse else {
            XCTFail("Open control tower action returned nil response")
            return
        }
        let openControlTowerFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: openControlTowerResponse)
        }
        XCTAssertNil(openControlTowerFailure)

        guard let controlTowerConfiguration = await expectedControlTowerLoad.value else {
            XCTFail("Expected BindingPortholeLoadBridge request for Conference Control Tower")
            return
        }
        XCTAssertTrue(controlTowerConfiguration.name.contains("Conference Control Tower"))
        XCTAssertTrue(controlTowerConfiguration.cellReferences?.contains(where: { $0.label == "conferenceAdminShell" }) == true)
    }

    func testConferenceDemoLauncherCanOpenParticipantCockpitChatAndAIAssistant() async throws {
        let configuration = ConfigurationCatalogCell.conferenceDemoLauncherWorkbenchConfiguration()
        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        let expectedParticipantLoad = Task {
            await waitForPortholeLoadBridgeConfiguration(containingName: "Conference Participant Portal")
        }
        let openParticipantResponse = try await context.porthole.set(
            keypath: "conferenceDemoLauncher.dispatchAction",
            value: .object([
                "keypath": .string("launcher.openParticipantCockpit"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        guard let openParticipantResponse else {
            XCTFail("Open participant cockpit action returned nil response")
            return
        }
        let openParticipantFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: openParticipantResponse)
        }
        XCTAssertNil(openParticipantFailure)

        guard let participantConfiguration = await expectedParticipantLoad.value else {
            XCTFail("Expected BindingPortholeLoadBridge request for Conference Participant Portal")
            return
        }
        XCTAssertTrue(participantConfiguration.name.contains("Conference Participant Portal"))
        XCTAssertTrue(participantConfiguration.cellReferences?.contains(where: { $0.label == "matchmakingSnapshot" }) == true)

        let expectedChatLoad = Task {
            await waitForPortholeLoadBridgeConfiguration(containingName: "Conference Participant Chat")
        }
        let openChatResponse = try await context.porthole.set(
            keypath: "conferenceDemoLauncher.dispatchAction",
            value: .object([
                "keypath": .string("launcher.openParticipantChat"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        guard let openChatResponse else {
            XCTFail("Open participant chat action returned nil response")
            return
        }
        let openChatFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: openChatResponse)
        }
        XCTAssertNil(openChatFailure)

        guard let chatConfiguration = await expectedChatLoad.value else {
            XCTFail("Expected BindingPortholeLoadBridge request for Conference Participant Chat")
            return
        }
        XCTAssertTrue(chatConfiguration.name.contains("Conference Participant Chat"))
        XCTAssertTrue(chatConfiguration.cellReferences?.contains(where: { $0.label == "conferenceChat" }) == true)

        let expectedAIAssistantLoad = Task {
            await waitForPortholeLoadBridgeConfiguration(containingName: "Conference AI Assistant")
        }
        let openAIResponse = try await context.porthole.set(
            keypath: "conferenceDemoLauncher.dispatchAction",
            value: .object([
                "keypath": .string("launcher.openAIAssistant"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        guard let openAIResponse else {
            XCTFail("Open AI assistant action returned nil response")
            return
        }
        let openAIFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: openAIResponse)
        }
        XCTAssertNil(openAIFailure)

        guard let aiAssistantConfiguration = await expectedAIAssistantLoad.value else {
            XCTFail("Expected BindingPortholeLoadBridge request for Conference AI Assistant")
            return
        }
        XCTAssertTrue(aiAssistantConfiguration.name.contains("Conference AI Assistant"))
        XCTAssertTrue(aiAssistantConfiguration.cellReferences?.contains(where: { $0.label == "aiGateway" }) == true)
        XCTAssertTrue(aiAssistantConfiguration.cellReferences?.contains(where: {
            $0.label == "conferenceParticipantShell" && $0.endpoint == "cell:///ConferenceParticipantPreviewShell"
        }) == true)
        XCTAssertTrue(aiAssistantConfiguration.cellReferences?.contains(where: {
            $0.label == "aiGateway" && $0.endpoint == "cell:///ConferenceAIAssistantGatewayProxy"
        }) == true)
    }

    func testConferenceIdentityLinkImportAndReviewFlow() async throws {
        await ConferenceIdentityLinkInboxStore.shared.clear()

        let configuration = ConfigurationCatalogCell.conferenceIdentityLinkWorkbenchConfiguration()
        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        let initialCompletionStatus = try await context.porthole.get(
            keypath: "identityLink.state.completion.status",
            requester: context.owner
        )
        XCTAssertEqual(initialCompletionStatus, .string("Ingen completion package er importert ennå."))

        let futureExpiry = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
        let challengeNonce = "aWRlbnRpdHktbGluay1jaGFsbGVuZ2UtcmFuZG9tLTIwMjY"
        let challengeURL = "haven://identity-link?requestId=REQ-123&audience=staging.haven.digipomps.org&origin=haven://binding/add-device&entityAnchorReference=cell:///EntityAnchor&deviceLabel=Kjetil%20iPhone&identity=Kjetil%20iPhone&domains=private,scaffold&contexts=private,scaffold&scopes=entity-auth,personal-cells&challenge=\(challengeNonce)&expiresAt=\(futureExpiry)&algorithm=P256-ES256"

        let setDraftResponse = try await context.porthole.set(
            keypath: "identityLink.setDraftInput",
            value: .string(challengeURL),
            requester: context.owner
        )
        guard let setDraftResponse else {
            XCTFail("Setting identity-link draft returned nil response")
            return
        }
        let setDraftFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: setDraftResponse)
        }
        XCTAssertNil(setDraftFailure)

        let importResponse = try await context.porthole.set(
            keypath: "identityLink.dispatchAction",
            value: .object([
                "keypath": .string("identityLink.importDraft"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        guard let importResponse else {
            XCTFail("Import identity-link challenge action returned nil response")
            return
        }
        let importFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: importResponse)
        }
        XCTAssertNil(importFailure)

        let challengeSummary = try await context.porthole.get(
            keypath: "identityLink.state.incoming.challengeSummary",
            requester: context.owner
        )
        XCTAssertEqual(challengeSummary, .string("Request REQ-123"))

        let confirmationBeforeReview = try await context.porthole.get(
            keypath: "identityLink.state.review.confirmationStatus",
            requester: context.owner
        )
        XCTAssertEqual(confirmationBeforeReview, .string("Lokal brukerbekreftelse mangler."))

        let confirmResponse = try await context.porthole.set(
            keypath: "identityLink.dispatchAction",
            value: .object([
                "keypath": .string("identityLink.confirmLocalReview"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        guard let confirmResponse else {
            XCTFail("Confirm local identity-link review action returned nil response")
            return
        }
        let confirmFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: confirmResponse)
        }
        XCTAssertNil(confirmFailure)

        let confirmationAfterReview = try await context.porthole.get(
            keypath: "identityLink.state.review.confirmationStatus",
            requester: context.owner
        )
        XCTAssertEqual(
            confirmationAfterReview,
            .string("Signert enrollment request klar. Dette er lokal proof-of-possession, ikke ferdig same-entity approval.")
        )

        let localIdentitySummary = try await context.porthole.get(
            keypath: "identityLink.state.review.localIdentitySummary",
            requester: context.owner
        )
        if case let .string(localIdentitySummaryText) = localIdentitySummary {
            XCTAssertTrue(
                localIdentitySummaryText.localizedCaseInsensitiveContains("private-domenet"),
                "Expected local identity summary to mention private domain, got: \(localIdentitySummaryText)"
            )
        } else {
            XCTFail("Expected string localIdentitySummary after confirming identity-link review")
        }

        let localProofSummary = try await context.porthole.get(
            keypath: "identityLink.state.review.localProofSummary",
            requester: context.owner
        )
        if case let .string(localProofSummaryText) = localProofSummary {
            XCTAssertTrue(localProofSummaryText.contains("Request hash"))
            XCTAssertTrue(localProofSummaryText.contains("signature"))
        } else {
            XCTFail("Expected string localProofSummary after signing identity-link request")
        }

        let enrollmentRequest = try await context.porthole.get(
            keypath: "identityLink.state.review.enrollmentRequest",
            requester: context.owner
        )
        guard case let .object(enrollmentRequestObject) = enrollmentRequest,
              case let .object(proofObject)? = enrollmentRequestObject["proof"] else {
            XCTFail("Expected signed CellProtocol IdentityEnrollmentRequest after local review")
            return
        }
        XCTAssertEqual(enrollmentRequestObject["purpose"], .string("link_identity"))
        XCTAssertNotNil(proofObject["signature"])

        let expectedLauncherPop = Task {
            await waitForConferenceNavigationPopFallbackConfiguration(containingName: "Conference Demo Launcher")
        }
        let openLauncherResponse = try await context.porthole.set(
            keypath: "identityLink.dispatchAction",
            value: .object([
                "keypath": .string("identityLink.openLauncher"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        guard let openLauncherResponse else {
            XCTFail("Back to launcher action returned nil response")
            return
        }
        let openLauncherFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: openLauncherResponse)
        }
        XCTAssertNil(openLauncherFailure)

        guard let launcherConfiguration = await expectedLauncherPop.value else {
            XCTFail("Expected BindingConferenceNavigationBridge pop request for Conference Demo Launcher")
            return
        }
        XCTAssertTrue(launcherConfiguration.name.contains("Conference Demo Launcher"))
    }

    func testConferenceIdentityLinkCompletionFlowWritesEntityAnchorRecord() async throws {
        await ConferenceIdentityLinkInboxStore.shared.clear()

        let configuration = ConfigurationCatalogCell.conferenceIdentityLinkWorkbenchConfiguration()
        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration, identityMode: .startup)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        let identityVault = await BindingStartupIdentityVault.shared.initialize()
        guard let holderIdentity = await identityVault.identity(for: "private", makeNewIfNotFound: true),
              let issuerIdentity = await identityVault.identity(for: "identity-link-issuer-\(UUID().uuidString)", makeNewIfNotFound: true) else {
            XCTFail("Expected startup identities for identity-link completion fixture")
            return
        }

        let challengeExpiry = ISO8601DateFormatter().string(from: Date().addingTimeInterval(600))
        let challengeNonce = Data((0..<32).map(UInt8.init))
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        guard let challengeURL = URL(string: "haven://identity-link?requestId=binding-completion-request&audience=staging.haven.digipomps.org&origin=haven://binding/add-device&entityAnchorReference=cell:///EntityAnchor&deviceLabel=Binding%20verifier&domains=private,scaffold&contexts=private,scaffold&scopes=entity-auth,personal-cells&challenge=\(challengeNonce)&expiresAt=\(challengeExpiry)&algorithm=P256-ES256"),
              await ConferenceIdentityLinkInboxStore.shared.ingest(url: challengeURL) else {
            XCTFail("Expected trusted identity-link challenge intake")
            return
        }
        await ConferenceIdentityLinkInboxStore.shared.confirmLocalReview(with: holderIdentity)
        let signedState = await ConferenceIdentityLinkInboxStore.shared.stateObject()
        guard case let .object(review)? = signedState["review"],
              let signedRequestValue = review["enrollmentRequest"],
              let signedRequestData = try? JSONEncoder().encode(signedRequestValue),
              let signedRequest = try? JSONDecoder().decode(IdentityEnrollmentRequest.self, from: signedRequestData) else {
            XCTFail("Expected locally signed enrollment request before completion")
            return
        }

        let jti = "binding-completion-jti-\(UUID().uuidString)"
        let package = try await makeBindingIdentityLinkCompletionPackageJSON(
            holderIdentity: holderIdentity,
            issuerIdentity: issuerIdentity,
            jti: jti,
            request: signedRequest
        )

        let setCompletionInputResponse = try await context.porthole.set(
            keypath: "identityLink.setCompletionPackageInput",
            value: .string(package.json),
            requester: context.owner
        )
        guard let setCompletionInputResponse else {
            XCTFail("Setting completion package input returned nil response")
            return
        }
        let setCompletionInputFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: setCompletionInputResponse)
        }
        XCTAssertNil(setCompletionInputFailure)

        let completeResponse = try await context.porthole.set(
            keypath: "identityLink.dispatchAction",
            value: .object([
                "keypath": .string("identityLink.completeApprovedLink"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        guard let completeResponse else {
            XCTFail("Complete approved identity-link action returned nil response")
            return
        }
        let completeFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: completeResponse)
        }
        XCTAssertNil(completeFailure)

        let completionStatus = try await context.porthole.get(
            keypath: "identityLink.state.completion.status",
            requester: context.owner
        )
        XCTAssertEqual(
            completionStatus,
            .string("Identity-link completion er verifisert og lagret i EntityAnchor.")
        )

        let completionRecordPreview = try await context.porthole.get(
            keypath: "identityLink.state.completion.recordPreview",
            requester: context.owner
        )
        guard case let .string(recordPreview) = completionRecordPreview else {
            XCTFail("Expected completion record preview string")
            return
        }
        XCTAssertTrue(recordPreview.contains(package.approvalID))
        XCTAssertTrue(recordPreview.contains("active"))
        XCTAssertTrue(recordPreview.contains("proofs.identityLinks.\(package.approvalID)"))

        let storedRecord = try await holderIdentity.get(
            keypath: "identity.identityLinks.records.\(package.approvalID)",
            requester: holderIdentity
        )
        guard case let .object(storedRecordObject) = storedRecord else {
            XCTFail("Expected stored IdentityLinkRecord in EntityAnchor, got \(storedRecord)")
            return
        }
        XCTAssertEqual(storedRecordObject["status"], .string("active"))

        let replayMarker = try await holderIdentity.get(
            keypath: "identity.identityLinks.usedApprovalJTIs.\(jti)",
            requester: holderIdentity
        )
        XCTAssertNotEqual(replayMarker, .null)
    }

    func testConferenceIdentityLinkRejectsWeakNonceBeforeSigning() async throws {
        let store = ConferenceIdentityLinkInboxStore.shared
        await store.clear()

        let futureExpiry = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
        let challengeURL = try XCTUnwrap(
            URL(
                string: "haven://identity-link?requestId=REQ-WEAK-NONCE&audience=staging.haven.digipomps.org&origin=haven://binding/add-device&entityAnchorReference=cell:///EntityAnchor&deviceLabel=Kjetil%20iPhone&identity=Kjetil%20iPhone&domains=private,scaffold&contexts=private,scaffold&scopes=entity-auth,personal-cells&challenge=nonce-123&expiresAt=\(futureExpiry)&algorithm=P256-ES256"
            )
        )

        let didIngest = await store.ingest(url: challengeURL)
        XCTAssertTrue(didIngest)

        let identity = await BindingStartupIdentityVault.shared.identity(for: "private", makeNewIfNotFound: true)
        await store.confirmLocalReview(with: identity)

        let state = await store.stateObject()
        guard case let .object(review)? = state["review"] else {
            XCTFail("Expected review identity-link state object")
            await store.clear()
            return
        }

        XCTAssertEqual(
            review["confirmationStatus"],
            .string("Challenge/nonce er ikke gyldig base64url med minst 128 bit. HAVEN nekter å signere.")
        )
        XCTAssertEqual(review["enrollmentRequest"], .null)

        await store.clear()
    }

    private struct BindingIdentityLinkCompletionPackage {
        var json: String
        var approvalID: String
    }

    private func makeBindingIdentityLinkCompletionPackageJSON(
        holderIdentity: Identity,
        issuerIdentity: Identity,
        jti: String,
        request suppliedRequest: IdentityEnrollmentRequest? = nil
    ) async throws -> BindingIdentityLinkCompletionPackage {
        let now = Date()
        let request: IdentityEnrollmentRequest
        if let suppliedRequest {
            request = suppliedRequest
        } else {
            request = try await makeBindingSignedEnrollmentRequest(
                holderIdentity: holderIdentity,
                now: now,
                expiresAt: now.addingTimeInterval(600)
            )
        }
        let approval = try await IdentityLinkProtocolService.approveEnrollmentRequest(
            request,
            issuerIdentity: issuerIdentity,
            issuerType: .existingDevice,
            createdAt: now,
            expiresAt: now.addingTimeInterval(300),
            jti: jti,
            freshAuthRequired: true,
            freshAuthPerformedAt: now
        )
        let credential = try await IdentityLinkProtocolService.issueSameEntityCredential(
            request: request,
            approval: approval,
            issuerIdentity: issuerIdentity,
            validUntil: now.addingTimeInterval(600),
            revocationReference: "cell:///EntityAnchor/proofs/identityLinks/\(approval.approvalID)"
        )
        let presentationChallenge = Data("binding-completion-verifier-challenge-2026".utf8)
        let presentationDomain = "staging.haven.digipomps.org"
        let presentation = try await IdentityLinkProtocolService.makeVerifierBoundPresentation(
            credential: credential,
            holderIdentity: holderIdentity,
            challenge: presentationChallenge,
            domain: presentationDomain
        )
        let envelope = IdentityLinkCompletionEnvelope(
            request: request,
            approval: approval,
            sameEntityCredential: credential,
            presentation: presentation,
            issuerIdentity: try IdentityLinkProtocolService.descriptor(for: issuerIdentity),
            expectedAudience: request.audience,
            expectedOrigin: request.origin,
            expectedPresentationChallenge: presentationChallenge,
            expectedPresentationDomain: presentationDomain
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]
        let data = try encoder.encode(envelope)
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(
                domain: "CellConfigurationVerifierXCTest",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "Could not encode identity-link completion envelope as UTF-8"]
            )
        }
        return BindingIdentityLinkCompletionPackage(json: json, approvalID: approval.approvalID)
    }

    private func makeBindingSignedEnrollmentRequest(
        holderIdentity: Identity,
        now: Date,
        expiresAt: Date
    ) async throws -> IdentityEnrollmentRequest {
        let descriptor = try IdentityLinkProtocolService.descriptor(for: holderIdentity)
        var request = IdentityEnrollmentRequest(
            requestID: "binding-request-\(UUID().uuidString)",
            entityBinding: EntityBindingDescriptor(
                mode: .localEntityAnchor,
                entityAnchorReference: "cell:///EntityAnchor",
                audience: "staging.haven.digipomps.org"
            ),
            newIdentity: descriptor,
            requestedDomains: ["private", "scaffold"],
            requestedIdentityContexts: ["private", "scaffold"],
            requestedScopes: ["entity-auth", "personal-cells"],
            audience: "staging.haven.digipomps.org",
            origin: "haven://binding/add-device",
            createdAt: IdentityLinkProtocolService.iso8601(now),
            expiresAt: IdentityLinkProtocolService.iso8601(expiresAt),
            nonce: Data((0..<32).map(UInt8.init)),
            platform: "macOS",
            deviceLabel: "Binding verifier"
        )
        let payload = try request.canonicalPayloadData()
        guard let signature = try await holderIdentity.sign(data: payload) else {
            throw NSError(
                domain: "CellConfigurationVerifierXCTest",
                code: 11,
                userInfo: [NSLocalizedDescriptionKey: "Startup identity vault did not sign enrollment request"]
            )
        }
        request.proof = IdentityEnrollmentRequestProof(
            byIdentityUUID: holderIdentity.uuid,
            algorithm: descriptor.algorithm,
            curveType: descriptor.curveType,
            signature: signature
        )
        return request
    }

    func testConferenceAIAssistantButtonsUpdateDraftAndSessionKeyViaRendererExecutionPath() async throws {
        let configuration = ConfigurationCatalogCell.conferenceAIAssistantWorkbenchConfiguration(
            conferenceEndpoint: "cell:///ConferenceParticipantPreviewShell",
            aiEndpoint: "cell:///ConferenceAIAssistantGatewayProxy"
        )
        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        let conferenceSystemPrompt = """
        You are a conference copilot. Use only the participant context visible in this workspace. Stay concrete, concise, and action-oriented. Prioritize the next sessions, the best people to meet, and the shortest path to meaningful follow-up.
        """
        let whoShouldIMeetPrompt = "Based on the visible matchmaking, meeting, and shared-connection summaries, identify the three strongest people for me to meet next. Explain why each one matters and suggest a short opener for each conversation."

        let loadSystemPromptButton = SkeletonButton(
            keypath: "aiGateway.setDraftSystemPrompt",
            label: "Load copilot system prompt",
            payload: .string(conferenceSystemPrompt)
        )
        let loadSystemPromptResponse = await loadSystemPromptButton.execute(requester: context.owner)
        XCTAssertNotNil(loadSystemPromptResponse, "Renderer button path returned nil for Load copilot system prompt")
        if let loadSystemPromptResponse {
            XCTAssertNil(
                SkeletonBindingProbeSupport.failureDetail(from: loadSystemPromptResponse),
                "Renderer button path returned failure payload for Load copilot system prompt: \(loadSystemPromptResponse)"
            )
        }

        let fillRequestButton = SkeletonButton(
            keypath: "aiGateway.setDraftPrompt",
            label: "Fill request: Who should I meet?",
            payload: .string(whoShouldIMeetPrompt)
        )
        let fillRequestResponse = await fillRequestButton.execute(requester: context.owner)
        XCTAssertNotNil(fillRequestResponse, "Renderer button path returned nil for Fill request: Who should I meet?")
        if let fillRequestResponse {
            XCTAssertNil(
                SkeletonBindingProbeSupport.failureDetail(from: fillRequestResponse),
                "Renderer button path returned failure payload for Fill request: Who should I meet?: \(fillRequestResponse)"
            )
        }

        let bufferedKeyResponse = try await context.porthole.set(
            keypath: "aiGateway.setDraftAPIKeyEntry",
            value: .string("sk-test-buffered-session-key"),
            requester: context.owner
        )
        guard let bufferedKeyResponse else {
            XCTFail("Buffering session key returned nil response")
            return
        }
        let bufferedKeyFailure = await MainActor.run {
            SkeletonBindingProbeSupport.failureDetail(from: bufferedKeyResponse)
        }
        XCTAssertNil(bufferedKeyFailure)

        let loadSessionKeyButton = SkeletonButton(
            keypath: "aiGateway.commitDraftAPIKeyEntry",
            label: "Load session key",
            payload: .bool(true)
        )
        let loadSessionKeyResponse = await loadSessionKeyButton.execute(requester: context.owner)
        XCTAssertNotNil(loadSessionKeyResponse, "Renderer button path returned nil for Load session key")
        if let loadSessionKeyResponse {
            XCTAssertNil(
                SkeletonBindingProbeSupport.failureDetail(from: loadSessionKeyResponse),
                "Renderer button path returned failure payload for Load session key: \(loadSessionKeyResponse)"
            )
        }

        let systemPromptState = try await context.porthole.get(
            keypath: "aiGateway.state.draft.systemPrompt",
            requester: context.owner
        )
        XCTAssertEqual(systemPromptState, .string(conferenceSystemPrompt))

        let requestPromptState = try await context.porthole.get(
            keypath: "aiGateway.state.draft.prompt",
            requester: context.owner
        )
        XCTAssertEqual(requestPromptState, .string(whoShouldIMeetPrompt))

        let activeCredentialSource = try await context.porthole.get(
            keypath: "aiGateway.state.setup.activeCredentialSource",
            requester: context.owner
        )
        XCTAssertEqual(activeCredentialSource, .string("session"))
    }

    private func waitForPortholeSkeleton(
        on porthole: OrchestratorCell,
        requester: Identity,
        containing expectedFragments: [String],
        timeout: TimeInterval = 1.5,
        pollInterval: UInt64 = 100_000_000
    ) async throws -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let skeletonValue = try await porthole.get(
                keypath: "skeleton",
                requester: requester
            )
            if case let .string(skeletonString) = skeletonValue,
               expectedFragments.allSatisfy(skeletonString.contains) {
                return skeletonString
            }
            try await Task.sleep(nanoseconds: pollInterval)
        }

        let finalValue = try await porthole.get(
            keypath: "skeleton",
            requester: requester
        )
        if case let .string(skeletonString) = finalValue {
            return skeletonString
        }
        return nil
    }

    private func waitForPortholeLoadBridgeConfiguration(
        containingName expectedNameFragment: String,
        timeout: TimeInterval = 2.0
    ) async -> CellConfiguration? {
        let notificationCenter = NotificationCenter.default
        return await withCheckedContinuation { continuation in
            var token: NSObjectProtocol?
            var didResume = false

            func finish(_ configuration: CellConfiguration?) {
                guard !didResume else { return }
                didResume = true
                if let token {
                    notificationCenter.removeObserver(token)
                }
                continuation.resume(returning: configuration)
            }

            let deadline = DispatchTime.now() + timeout

            token = notificationCenter.addObserver(
                forName: BindingPortholeLoadBridge.notificationName,
                object: nil,
                queue: nil
            ) { notification in
                guard let configuration = BindingPortholeLoadBridge.configuration(from: notification) else {
                    return
                }
                guard configuration.name.contains(expectedNameFragment) else {
                    return
                }
                finish(configuration)
            }

            DispatchQueue.main.asyncAfter(deadline: deadline) {
                finish(nil)
            }
        }
    }

    private func waitForConferenceNavigationPopFallbackConfiguration(
        containingName expectedNameFragment: String,
        timeout: TimeInterval = 2.0
    ) async -> CellConfiguration? {
        let notificationCenter = NotificationCenter.default
        return await withCheckedContinuation { continuation in
            var token: NSObjectProtocol?
            var didResume = false

            func finish(_ configuration: CellConfiguration?) {
                guard !didResume else { return }
                didResume = true
                if let token {
                    notificationCenter.removeObserver(token)
                }
                continuation.resume(returning: configuration)
            }

            let deadline = DispatchTime.now() + timeout

            token = notificationCenter.addObserver(
                forName: BindingConferenceNavigationBridge.notificationName,
                object: nil,
                queue: nil
            ) { notification in
                guard BindingConferenceNavigationBridge.isPopRequest(notification),
                      let configuration = BindingConferenceNavigationBridge.fallbackConfiguration(from: notification),
                      configuration.name.contains(expectedNameFragment) else {
                    return
                }
                finish(configuration)
            }

            DispatchQueue.main.asyncAfter(deadline: deadline) {
                finish(nil)
            }
        }
    }

#if canImport(AppKit)
    @MainActor
    func testSpatialV2InspectorRenderer() async throws {
        let report = try await CellConfigurationVerifier.renderReport(
            for: Self.spatialV2InspectorConfiguration(),
            expectedVisibleStrings: [
                "Spatial v2 AR Inspector",
                "Spatial v2 AR scene fixture",
                "Anchor contract",
                "haven.spatial.feature.v2",
                "venue-ar-sign",
                "wgs84",
                "Oslo venue coarse · 120m accuracy",
                "Asset delivery",
                "vault://assets/venue-model.usdz",
                "abc123spatialv2",
                "Access policy",
                "structured-denied",
                "Binding native AR adapter candidate"
            ]
        )

        XCTAssertGreaterThan(report.snapshotByteCount, 0, "Expected rendered snapshot bytes")
        XCTAssertGreaterThan(report.subviewCount, 0, "Expected rendered subviews")
        XCTAssertGreaterThan(report.totalRenderMilliseconds, 0, "Expected positive render duration")
        XCTAssertEqual(report.unavailableNowCount, 0, "Spatial v2-inspektøren skal ikke rendre utilgjengelighets-tekster")
    }

    @MainActor
    func testConferenceDemoLauncherRenderer() async throws {
        let configuration = ConfigurationCatalogCell.conferenceDemoLauncherWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "Conference Demo Launcher",
                "Act 0 · Public Opener",
                "Open public surface",
                "Open identity link setup",
                "Open participant chat",
                "Open control tower",
                "Open AI assistant"
            ]
        )

        XCTAssertGreaterThan(report.snapshotByteCount, 0, "Expected rendered snapshot bytes")
        XCTAssertGreaterThan(report.subviewCount, 0, "Expected rendered subviews")
        XCTAssertGreaterThan(report.totalRenderMilliseconds, 0, "Expected positive render duration")
        XCTAssertEqual(report.unavailableNowCount, 0, "Demo launcheren skal ikke rendre utilgjengelighets-tekster i lokal verifier")
    }

    @MainActor
    func testConferenceIdentityLinkRenderer() async throws {
        let configuration = ConfigurationCatalogCell.conferenceIdentityLinkWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "Conference Scaffold Setup & Identity Link",
                "Incoming challenge",
                "Open or paste challenge data",
                "Import challenge",
                "Local Binding review",
                "Confirm local key & continue",
                "Back to launcher"
            ]
        )

        XCTAssertGreaterThan(report.snapshotByteCount, 0, "Expected rendered snapshot bytes")
        XCTAssertGreaterThan(report.subviewCount, 0, "Expected rendered subviews")
        XCTAssertGreaterThan(report.totalRenderMilliseconds, 0, "Expected positive render duration")
        XCTAssertEqual(report.unavailableNowCount, 0, "Identity-link-flaten skal ikke rendre utilgjengelighets-tekster i lokal verifier")
    }

    @MainActor
    func testConferenceAIAssistantRenderer() async throws {
        let configuration = ConfigurationCatalogCell.conferenceAIAssistantWorkbenchConfiguration(
            conferenceEndpoint: "cell:///ConferenceParticipantPreviewShell",
            aiEndpoint: "cell:///ConferenceAIAssistantGatewayProxy"
        )

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "Conference AI Assistant",
                "Conference Snapshot",
                "Copilot Setup",
                "Conference Prompt Presets",
                "Prompt Draft",
                "Load session key",
                "Load copilot system prompt",
                "Invoke conference copilot",
                "Latest AI Result"
            ]
        )

        XCTAssertGreaterThan(report.snapshotByteCount, 0, "Expected rendered snapshot bytes")
        XCTAssertGreaterThan(report.subviewCount, 0, "Expected rendered subviews")
        XCTAssertGreaterThan(report.totalRenderMilliseconds, 0, "Expected positive render duration")
        XCTAssertEqual(report.unavailableNowCount, 0, "Conference AI Assistant skal ikke rendre utilgjengelighets-tekster i lokal verifier")
    }

    @MainActor
    func testConferencePublicSurfaceRenderer() async throws {
        let configuration = ConfigurationCatalogCell.conferencePublicWorkbenchConfiguration(
            endpoint: "cell:///ConferencePublicShellFixture"
        )

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "AI & Digital Independence",
                "Publication & Access",
                "Tracks & Program Highlights",
                "People, Articles & Facilities",
                "Join the public program"
            ]
        )

        XCTAssertGreaterThan(report.snapshotByteCount, 0, "Expected rendered snapshot bytes")
        XCTAssertGreaterThan(report.subviewCount, 0, "Expected rendered subviews")
        XCTAssertGreaterThan(report.totalRenderMilliseconds, 0, "Expected positive render duration")
        XCTAssertEqual(report.unavailableNowCount, 0, "Conference public surface skal ikke rendre utilgjengelighets-tekster i lokal verifier")
    }

    @MainActor
    func testConferenceSponsorFollowUpRenderer() async throws {
        let configuration = ConfigurationCatalogCell.conferenceSponsorWorkbenchConfiguration(
            endpoint: "cell:///ConferenceSponsorShellFixture"
        )

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "Conference Sponsor Follow-up",
                "Lead Inbox",
                "Consent, Unlock & Retention",
                "Refresh inbox",
                "Prepare export",
                "Run retention sweep"
            ]
        )

        XCTAssertGreaterThan(report.snapshotByteCount, 0, "Expected rendered snapshot bytes")
        XCTAssertGreaterThan(report.subviewCount, 0, "Expected rendered subviews")
        XCTAssertGreaterThan(report.totalRenderMilliseconds, 0, "Expected positive render duration")
        XCTAssertEqual(report.unavailableNowCount, 0, "Conference sponsor follow-up skal ikke rendre utilgjengelighets-tekster i lokal verifier")
    }

    @MainActor
    func testConferenceParticipantPortalRenderer() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "Conference Participant Portal",
                "Entity Discovery",
                "Start scanner",
                "Match nå",
                "Radar i siden",
                "Åpne full radar",
                "Visning nå",
                "Fokus nå"
            ]
        )

        XCTAssertGreaterThan(report.snapshotByteCount, 0, "Expected rendered snapshot bytes")
        XCTAssertGreaterThan(report.subviewCount, 0, "Expected rendered subviews")
        XCTAssertGreaterThan(report.totalRenderMilliseconds, 0, "Expected positive render duration")
        XCTAssertEqual(report.unavailableNowCount, 0, "Participant-portalen skal ikke rendre utilgjengelighets-tekster i lokal verifier")
    }

    @MainActor
    func testConferenceControlTowerRenderer() async throws {
        let configuration = ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
            endpoint: "cell:///ConferenceAdminPreviewShell"
        )

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "Conference Control Tower",
                "Same Conference Reality",
                "Organizer Insight Story",
                "Simulation Studio",
                "System Load & Storage",
                "Sponsor / Exhibitor"
            ]
        )

        XCTAssertGreaterThan(report.snapshotByteCount, 0, "Expected rendered snapshot bytes")
        XCTAssertGreaterThan(report.subviewCount, 0, "Expected rendered subviews")
        XCTAssertGreaterThan(report.totalRenderMilliseconds, 0, "Expected positive render duration")
        XCTAssertEqual(report.unavailableNowCount, 0, "Control tower skal ikke rendre utilgjengelighets-tekster i lokal verifier")
    }

    @MainActor
    func testConferenceNearbyRadarRenderer() async throws {
        let configuration = ConfigurationCatalogCell.conferenceNearbyRadarWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "Conference Nearby Radar · Full oversikt",
                "Start scanner",
                "Match nå",
                "Tilbake til portalen",
                "Valgt deltager"
            ]
        )

        XCTAssertGreaterThan(report.snapshotByteCount, 0, "Expected rendered snapshot bytes")
        XCTAssertGreaterThan(report.subviewCount, 0, "Expected rendered subviews")
        XCTAssertGreaterThan(report.totalRenderMilliseconds, 0, "Expected positive render duration")
    }

    @MainActor
    func testConferenceNearbyParticipantProfileRenderer() async throws {
        let configuration = ConfigurationCatalogCell.conferenceNearbyParticipantWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "Valgt deltager · profilflate",
                "Match nå",
                "Åpne full radar",
                "Tilbake til portalen",
                "Neste steg"
            ]
        )

        XCTAssertGreaterThan(report.snapshotByteCount, 0, "Expected rendered snapshot bytes")
        XCTAssertGreaterThan(report.subviewCount, 0, "Expected rendered subviews")
        XCTAssertGreaterThan(report.totalRenderMilliseconds, 0, "Expected positive render duration")
    }

    @MainActor
    func testConferenceParticipantChatRenderer() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantChatWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "Conference Participant Chat",
                "Participants & Conversations",
                "Recent Messages",
                "Free-text Composer",
                "Send fri melding",
                "Tøm utkast",
                "Tilbake til portalen"
            ]
        )

        XCTAssertGreaterThan(report.snapshotByteCount, 0, "Expected rendered snapshot bytes")
        XCTAssertGreaterThan(report.subviewCount, 0, "Expected rendered subviews")
        XCTAssertGreaterThan(report.totalRenderMilliseconds, 0, "Expected positive render duration")
    }

    func testConferencePublicProfileEditorExportedCellConfigurationLoadsRemotely() async throws {
        try skipUnlessRemoteParityEnabled()

        let configuration = try retargetedCellScaffoldExportedConfiguration(
            at: "Documentation/ConfigurationCatalog/CellConfiguration.conference.public-profile.editor.json"
        )

        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        registerRemoteRoutes(for: context.configuration, resolver: context.resolver)

        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        let workspaceTitle = try await context.porthole.get(
            keypath: "conferencePublicProfileEditor.state.workspace.title",
            requester: context.owner
        )
        guard case let .string(title) = workspaceTitle else {
            XCTFail("Expected workspace title string from exported public-profile editor configuration, got \(workspaceTitle)")
            return
        }

        XCTAssertFalse(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertNil(SkeletonBindingProbeSupport.failureDetail(from: workspaceTitle))

        let mutationResponse = try await context.porthole.set(
            keypath: "conferencePublicProfileEditor.setHeadline",
            value: .string("Binding verifier headline"),
            requester: context.owner
        )
        XCTAssertNotNil(mutationResponse)
        if let mutationResponse {
            XCTAssertNil(SkeletonBindingProbeSupport.failureDetail(from: mutationResponse))
        }
    }

    func testConferencePublicProfileViewerExportedCellConfigurationLoadsRemotely() async throws {
        try skipUnlessRemoteParityEnabled()

        let configuration = try retargetedCellScaffoldExportedConfiguration(
            at: "Documentation/ConfigurationCatalog/CellConfiguration.conference.public-profile.json"
        )

        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        registerRemoteRoutes(for: context.configuration, resolver: context.resolver)

        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        let workspaceTitle = try await context.porthole.get(
            keypath: "conferencePublicProfileViewer.state.workspace.title",
            requester: context.owner
        )
        guard case let .string(title) = workspaceTitle else {
            XCTFail("Expected workspace title string from exported public-profile viewer configuration, got \(workspaceTitle)")
            return
        }

        XCTAssertFalse(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertNil(SkeletonBindingProbeSupport.failureDetail(from: workspaceTitle))

        let profileState = try await context.porthole.get(
            keypath: "conferencePublicProfileViewer.state.profile",
            requester: context.owner
        )
        XCTAssertNil(SkeletonBindingProbeSupport.failureDetail(from: profileState))
    }
#endif

    private func skipUnlessRemoteParityEnabled() throws {
        let enabledInEnvironment = ProcessInfo.processInfo.environment["BINDING_ENABLE_REMOTE_PARITY"] == "1"
        let sentinelExists = FileManager.default.fileExists(atPath: Self.remoteParitySentinelPath)
        if !(enabledInEnvironment || sentinelExists) {
            throw XCTSkip("Remote public-profile verifier krever BINDING_ENABLE_REMOTE_PARITY=1 eller \(Self.remoteParitySentinelPath)")
        }
    }

    private func retargetedCellScaffoldExportedConfiguration(at relativePath: String) throws -> CellConfiguration {
        let absolutePath = "\(Self.cellScaffoldRoot)/\(relativePath)"
        let data = try Data(contentsOf: URL(fileURLWithPath: absolutePath))
        let decoded = try JSONDecoder().decode(CellConfiguration.self, from: data)
        let contentView = ContentView()
        return CellConfigurationEndpointRetargeting.rewritingEndpoints(in: decoded) {
            contentView.maybeRetargetLocalEndpointToStaging($0)
        }
    }

    private func registerRemoteRoutes(for configuration: CellConfiguration, resolver: CellResolver) {
        for endpoint in remoteEndpoints(in: configuration) {
            RemoteEndpointAccessSupport.registerRemoteRouteIfNeeded(for: endpoint, resolver: resolver)
        }
    }

    private func remoteEndpoints(in configuration: CellConfiguration) -> Set<String> {
        var endpoints: Set<String> = []

        if let endpoint = configuration.discovery?.sourceCellEndpoint,
           endpoint.contains("://staging.haven.digipomps.org/") {
            endpoints.insert(endpoint)
        }

        for reference in configuration.cellReferences ?? [] {
            collectRemoteEndpoints(from: reference, into: &endpoints)
        }

        return endpoints
    }

    private func collectRemoteEndpoints(from reference: CellReference, into endpoints: inout Set<String>) {
        if reference.endpoint.contains("://staging.haven.digipomps.org/") {
            endpoints.insert(reference.endpoint)
        }

        for item in reference.setKeysAndValues {
            if let target = item.target,
               target.contains("://staging.haven.digipomps.org/") {
                endpoints.insert(target)
            }
        }

        for subscription in reference.subscriptions {
            collectRemoteEndpoints(from: subscription, into: &endpoints)
        }
    }

    private func string(_ value: ValueType?) -> String? {
        guard case let .string(string)? = value else {
            return nil
        }
        return string
    }
}
