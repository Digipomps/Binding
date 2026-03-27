import SwiftUI
import Combine
import CellBase

enum BindingDiagnosticSeverity: String, Hashable {
    case info
    case warning
    case error

    var tint: Color {
        switch self {
        case .info:
            return .accentColor
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    var symbolName: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }
}

struct BindingDiagnosticEntry: Identifiable, Hashable {
    let id = UUID()
    var timestamp: Date
    let severity: BindingDiagnosticSeverity
    let domain: String
    let message: String
    var occurrenceCount: Int = 1
}

struct CellConfigurationValidationIssue: Identifiable, Hashable {
    let id = UUID()
    let severity: BindingDiagnosticSeverity
    let title: String
    let detail: String
}

struct CellConfigurationValidationReport: Hashable {
    let configurationName: String
    let referenceCount: Int
    let bindingValueCount: Int
    let referencedLabels: [String]
    let unusedLabels: [String]
    let issues: [CellConfigurationValidationIssue]

    var errorCount: Int {
        issues.filter { $0.severity == .error }.count
    }

    var warningCount: Int {
        issues.filter { $0.severity == .warning }.count
    }
}

enum CellConfigurationValidationService {
    private static let referenceSensitiveKeys: Set<String> = [
        "keypath",
        "sourceKeypath",
        "targetKeypath",
        "topic",
        "url",
        "selectionValueKeypath",
        "selectionStateKeypath",
        "selectionActionKeypath",
        "activationActionKeypath"
    ]

    static func validate(_ configuration: CellConfiguration) -> CellConfigurationValidationReport {
        let references = configuration.cellReferences ?? []
        let trimmedLabels = references
            .map { $0.label.trimmingCharacters(in: .whitespacesAndNewlines) }
        let topLevelLabels = trimmedLabels.filter { !$0.isEmpty }
        let duplicateLabels = Dictionary(grouping: topLevelLabels, by: { $0 })
            .filter { $1.count > 1 }
            .keys
            .sorted()
        let blankLabelCount = trimmedLabels.count - topLevelLabels.count
        let bindingValues = referencedValues(in: configuration.skeleton)
        let usageReport = ReferenceUsageAnalyzer.analyze(
            skeleton: configuration.skeleton,
            references: references
        )

        var issues: [CellConfigurationValidationIssue] = []

        if configuration.skeleton == nil {
            issues.append(
                CellConfigurationValidationIssue(
                    severity: .error,
                    title: "Mangler skeleton",
                    detail: "Konfigurasjonen kan ikke rendres uten et skeleton-tre."
                )
            )
        }

        if references.isEmpty && !bindingValues.isEmpty {
            issues.append(
                CellConfigurationValidationIssue(
                    severity: .error,
                    title: "Mangler CellReferences",
                    detail: "Skeletonet peker på \(bindingValues.count) keypaths eller topics, men konfigurasjonen har ingen top-level references."
                )
            )
        }

        if blankLabelCount > 0 {
            issues.append(
                CellConfigurationValidationIssue(
                    severity: .error,
                    title: "Tom reference-label",
                    detail: "\(blankLabelCount) reference(r) mangler label. Skeleton-keypaths kan da ikke matches stabilt."
                )
            )
        }

        if !duplicateLabels.isEmpty {
            issues.append(
                CellConfigurationValidationIssue(
                    severity: .error,
                    title: "Dupliserte labels",
                    detail: duplicateLabels.joined(separator: ", ")
                )
            )
        }

        let invalidEndpoints = references
            .map(\.endpoint)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { endpoint in
                guard !endpoint.isEmpty else { return true }
                guard let scheme = URLComponents(string: endpoint)?.scheme?.lowercased() else { return true }
                return !["cell", "ws", "wss"].contains(scheme)
            }

        if !invalidEndpoints.isEmpty {
            issues.append(
                CellConfigurationValidationIssue(
                    severity: .warning,
                    title: "Uvanlige endpoints",
                    detail: invalidEndpoints.prefix(3).joined(separator: ", ")
                )
            )
        }

        let unresolvedBindings = unresolvedBindingValues(bindingValues, labels: Set(topLevelLabels))
        if !unresolvedBindings.isEmpty {
            issues.append(
                CellConfigurationValidationIssue(
                    severity: .error,
                    title: "Bindings uten matchende reference",
                    detail: unresolvedBindings.prefix(4).joined(separator: ", ")
                )
            )
        }

        if !usageReport.unusedTopLevelLabels.isEmpty {
            issues.append(
                CellConfigurationValidationIssue(
                    severity: .warning,
                    title: "Ubrukte references",
                    detail: usageReport.unusedTopLevelLabels.sorted().joined(separator: ", ")
                )
            )
        }

        if let sourceEndpoint = configuration.discovery?.sourceCellEndpoint?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !sourceEndpoint.isEmpty,
           !references.contains(where: { endpointIdentity($0.endpoint) == endpointIdentity(sourceEndpoint) })
        {
            issues.append(
                CellConfigurationValidationIssue(
                    severity: .info,
                    title: "Discovery skiller seg fra references",
                    detail: "Discovery peker på \(sourceEndpoint), men ingen top-level reference bruker samme endpoint."
                )
            )
        }

        if issues.isEmpty {
            issues.append(
                CellConfigurationValidationIssue(
                    severity: .info,
                    title: "Ingen åpenbare strukturelle feil",
                    detail: "Skeleton, references og labels ser konsistente ut i denne lokale valideringen."
                )
            )
        }

        return CellConfigurationValidationReport(
            configurationName: configuration.name,
            referenceCount: references.count,
            bindingValueCount: bindingValues.count,
            referencedLabels: usageReport.referencedLabels.sorted(),
            unusedLabels: usageReport.unusedTopLevelLabels.sorted(),
            issues: issues
        )
    }

    private static func unresolvedBindingValues(_ values: [String], labels: Set<String>) -> [String] {
        var result: [String] = []
        for value in values {
            guard let label = inferredLabel(from: value) else { continue }
            guard !labels.contains(label) else { continue }
            if !result.contains(value) {
                result.append(value)
            }
        }
        return result
    }

    private static func inferredLabel(from bindingValue: String) -> String? {
        let trimmed = bindingValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("cell:///Porthole/") {
            let remainder = String(trimmed.dropFirst("cell:///Porthole/".count))
            return remainder.split(separator: ".").first.map(String.init)
        }

        if trimmed.hasPrefix("cell://") || trimmed.hasPrefix("ws://") || trimmed.hasPrefix("wss://") || trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return nil
        }

        guard trimmed.contains(".") else { return nil }
        return trimmed.split(separator: ".").first.map(String.init)
    }

    private static func endpointIdentity(_ endpoint: String) -> String {
        endpoint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func referencedValues(in skeleton: SkeletonElement?) -> [String] {
        guard let skeleton,
              let rawObject = rawObject(from: skeleton)
        else {
            return []
        }

        var collected: [String] = []
        collectValues(from: rawObject, into: &collected)
        return collected
    }

    private static func rawObject<T: Encodable>(from value: T) -> Any? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private static func collectValues(
        from value: Any,
        into collected: inout [String],
        insideDispatchActionPayload: Bool = false
    ) {
        switch value {
        case let dictionary as [String: Any]:
            let keypathValue = (dictionary["keypath"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let isDispatchActionContainer = keypathValue == "dispatchAction" ||
                keypathValue?.hasSuffix(".dispatchAction") == true
            for (key, child) in dictionary {
                let childInsideDispatchActionPayload = insideDispatchActionPayload || (isDispatchActionContainer && key == "payload")
                if let stringValue = child as? String,
                   referenceSensitiveKeys.contains(key) {
                    if insideDispatchActionPayload && key == "keypath" {
                        continue
                    }
                    collected.append(stringValue)
                } else {
                    collectValues(
                        from: child,
                        into: &collected,
                        insideDispatchActionPayload: childInsideDispatchActionPayload
                    )
                }
            }
        case let array as [Any]:
            for child in array {
                collectValues(
                    from: child,
                    into: &collected,
                    insideDispatchActionPayload: insideDispatchActionPayload
                )
            }
        default:
            break
        }
    }
}

@MainActor
final class BindingRuntimeDiagnostics: ObservableObject {
    static let shared = BindingRuntimeDiagnostics()
    private static let maximumEntries = 140

    @Published var panelVisible = false
    @Published private(set) var entries: [BindingDiagnosticEntry] = []
    @Published private(set) var validationReport: CellConfigurationValidationReport?

    private var configured = false
    private var previousHandler: ((CellBase.DiagnosticLogDomain, String) -> Void)?

    private init() {}

    func configureIfNeeded() {
        guard !configured else { return }
        configured = true
        previousHandler = CellBase.diagnosticLogHandler
        CellBase.enabledDiagnosticLogDomains.formUnion([.resolver, .skeleton, .flow, .identity, .agreement])

        CellBase.diagnosticLogHandler = { [weak self] domain, message in
            self?.previousHandler?(domain, message)
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                guard self.panelVisible else {
                    return
                }
                guard !Self.shouldSuppress(domain: domain, message: message) else {
                    return
                }
                self.append(
                    severity: Self.severity(for: domain, message: message),
                    domain: domain.rawValue,
                    message: message
                )
            }
        }
    }

    func record(
        severity: BindingDiagnosticSeverity = .info,
        domain: String = "binding",
        message: String
    ) {
        append(severity: severity, domain: domain, message: message)
    }

    func refreshValidation(for configuration: CellConfiguration?) {
        validationReport = configuration.map(CellConfigurationValidationService.validate)
    }

    func clearLogs() {
        entries.removeAll()
    }

    private func append(
        severity: BindingDiagnosticSeverity,
        domain: String,
        message: String
    ) {
        let now = Date()
        if let existingIndex = entries.firstIndex(where: {
            $0.severity == severity &&
                $0.domain == domain &&
                $0.message == message
        }) {
            var existing = entries.remove(at: existingIndex)
            existing.timestamp = now
            existing.occurrenceCount += 1
            entries.insert(existing, at: 0)
            return
        }

        let entry = BindingDiagnosticEntry(
            timestamp: now,
            severity: severity,
            domain: domain,
            message: message
        )
        entries.insert(entry, at: 0)
        if entries.count > Self.maximumEntries {
            entries.removeLast(entries.count - Self.maximumEntries)
        }
    }

    private static func severity(
        for domain: CellBase.DiagnosticLogDomain,
        message: String
    ) -> BindingDiagnosticSeverity {
        let normalized = message.lowercased()
        if normalized.contains("failed") ||
            normalized.contains("timeout") ||
            normalized.contains("notfound") ||
            normalized.contains("denied") ||
            normalized.contains("bad response from the server") ||
            normalized.contains("notconnected") ||
            normalized.contains("502") {
            return .error
        }
        if normalized.contains("skip") || normalized.contains("missing") || normalized.contains("reconnect") || normalized.contains("fallback") {
            return .warning
        }
        switch domain {
        case .resolver, .skeleton:
            return .warning
        default:
            return .info
        }
    }

    private static func shouldSuppress(
        domain: CellBase.DiagnosticLogDomain,
        message: String
    ) -> Bool {
        guard domain == .skeleton else {
            return false
        }

        return message.hasPrefix("SkeletonText loading cellName=") ||
            message.hasPrefix("SkeletonText loading keypath=") ||
            message.hasPrefix("SkeletonText fetched content for keypath=")
    }
}

struct BindingDiagnosticsPanel: View {
    @ObservedObject var diagnostics: BindingRuntimeDiagnostics
    let bridgeStatus: LightweightBridgeConnectionStatus?
    let onRefreshValidation: () -> Void

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label("Debug", systemImage: "ladybug.fill")
                    .font(.headline)
                Spacer(minLength: 0)
                Button("Refresh") {
                    onRefreshValidation()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button {
                    diagnostics.panelVisible = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if let bridgeStatus {
                diagnosticChip(
                    title: bridgeStatus.titleText,
                    subtitle: bridgeStatus.subtitleText,
                    tint: bridgeStatus.tintColor
                )
            }

            if let report = diagnostics.validationReport {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(report.configurationName)
                            .font(.subheadline.weight(.semibold))
                        Spacer(minLength: 0)
                        if report.errorCount > 0 {
                            countBadge("\(report.errorCount) feil", tint: .red)
                        }
                        if report.warningCount > 0 {
                            countBadge("\(report.warningCount) advarsler", tint: .orange)
                        }
                    }

                    Text("\(report.referenceCount) references, \(report.bindingValueCount) bindings")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(report.issues.prefix(5)) { issue in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: issue.severity.symbolName)
                                .foregroundStyle(issue.severity.tint)
                                .font(.caption)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(issue.title)
                                    .font(.caption.weight(.semibold))
                                Text(issue.detail)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Runtime logg")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                    Button("Clear") {
                        diagnostics.clearLogs()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }

                if diagnostics.entries.isEmpty {
                    Text("Ingen diagnoselinjer ennå.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(diagnostics.entries.prefix(24)) { entry in
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 8) {
                                        Text(Self.timestampFormatter.string(from: entry.timestamp))
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                        Text(entry.domain.uppercased())
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(entry.severity.tint)
                                        if entry.occurrenceCount > 1 {
                                            countBadge("x\(entry.occurrenceCount)", tint: entry.severity.tint)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    Text(entry.message)
                                        .font(.caption2)
                                        .foregroundStyle(.primary)
                                        .textSelection(.enabled)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(entry.severity.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                    .frame(maxHeight: 280)
                }
            }
        }
        .padding(14)
#if os(macOS)
        .frame(width: 360, alignment: .leading)
#else
        .frame(maxWidth: .infinity, alignment: .leading)
#endif
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
    }

    private func diagnosticChip(title: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func countBadge(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption2.monospacedDigit())
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
    }
}
