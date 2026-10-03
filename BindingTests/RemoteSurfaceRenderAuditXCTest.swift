import XCTest
import Foundation
import CellBase
import CellApple
@testable import Binding

/// Skeleton-render audit against live scaffold hosts, measured through the
/// same code paths HAVEN uses when a person opens a surface.
///
/// Three phases per host:
///
/// - `bridge`: every `cell://<host>/<Cell>` endpoint the app's catalog can point
///   at, resolved through `RemoteEndpointAccessSupport.resolveEmit` (route
///   registration → websocket bridge → scaffold admission). Answers "does the
///   cell answer, and how long does the app wait before it knows".
/// - `http`: every CellConfiguration the host publishes over plain HTTP
///   (`/personal-copilot-v1/*/api/configuration`, `/skeleton-parity/*`),
///   decoded with the app's decoder, validated, and rendered with the app's
///   SwiftUI renderer. Answers "does the renderer handle what the server
///   actually publishes, and how fast".
/// - `load`: the full Porthole load path (`CellConfigurationVerifier.contractReport`)
///   for every configuration that references the host, with the host under
///   test substituted. Answers "what does a person actually wait for".
///
/// Opt-in. Settings come from `BINDING_SURFACE_AUDIT_*` environment variables or,
/// when those are absent, from `_audit-skeleton-render-20260828/audit-settings.json`
/// next to the repository root. Nothing here asserts on findings: the report is
/// the deliverable, and a red row must stay visible rather than abort the run.
final class RemoteSurfaceRenderAuditXCTest: XCTestCase {

    // MARK: - Settings

    private struct AuditSettings: Decodable {
        var hosts: [String] = []
        var outputDirectory: String? = nil
        var phases: [String] = ["bridge", "http", "load"]
        var resolveDeadlineSeconds: Double = 10
        var loadDeadlineSeconds: Double = 20
        var renderDeadlineSeconds: Double = 20
        var coldThresholdMilliseconds: Double = 3000
        var warmThresholdMilliseconds: Double = 1500
        var maxLoadPathSurfacesPerHost: Int = 80
        var extraCellNames: [String] = []

        init() {}

        private enum CodingKeys: String, CodingKey {
            case hosts, outputDirectory, phases, resolveDeadlineSeconds, loadDeadlineSeconds,
                 renderDeadlineSeconds, coldThresholdMilliseconds, warmThresholdMilliseconds,
                 maxLoadPathSurfacesPerHost, extraCellNames
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            hosts = try container.decodeIfPresent([String].self, forKey: .hosts) ?? []
            outputDirectory = try container.decodeIfPresent(String.self, forKey: .outputDirectory)
            phases = try container.decodeIfPresent([String].self, forKey: .phases) ?? ["bridge", "http", "load"]
            resolveDeadlineSeconds = try container.decodeIfPresent(Double.self, forKey: .resolveDeadlineSeconds) ?? 10
            loadDeadlineSeconds = try container.decodeIfPresent(Double.self, forKey: .loadDeadlineSeconds) ?? 20
            renderDeadlineSeconds = try container.decodeIfPresent(Double.self, forKey: .renderDeadlineSeconds) ?? 20
            coldThresholdMilliseconds = try container.decodeIfPresent(Double.self, forKey: .coldThresholdMilliseconds) ?? 3000
            warmThresholdMilliseconds = try container.decodeIfPresent(Double.self, forKey: .warmThresholdMilliseconds) ?? 1500
            maxLoadPathSurfacesPerHost = try container.decodeIfPresent(Int.self, forKey: .maxLoadPathSurfacesPerHost) ?? 80
            extraCellNames = try container.decodeIfPresent([String].self, forKey: .extraCellNames) ?? []
        }
    }

    /// Repository root derived from this file's compile-time path, so the
    /// settings file and the report land next to the checkout that was built.
    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // BindingTests
            .deletingLastPathComponent()   // repo root
    }

    private static var auditDirectory: URL {
        repositoryRoot.appendingPathComponent("_audit-skeleton-render-20260828", isDirectory: true)
    }

    private static func loadSettings() -> AuditSettings {
        var settings = AuditSettings()
        let settingsURL = auditDirectory.appendingPathComponent("audit-settings.json")
        if let data = try? Data(contentsOf: settingsURL),
           let decoded = try? JSONDecoder().decode(AuditSettings.self, from: data) {
            settings = decoded
        }

        let environment = ProcessInfo.processInfo.environment
        if let raw = environment["BINDING_SURFACE_AUDIT_HOSTS"] {
            let hosts = raw
                .components(separatedBy: CharacterSet(charactersIn: ",; \n"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !hosts.isEmpty { settings.hosts = hosts }
        }
        if let raw = environment["BINDING_SURFACE_AUDIT_OUTPUT_DIR"], !raw.isEmpty {
            settings.outputDirectory = raw
        }
        if let raw = environment["BINDING_SURFACE_AUDIT_PHASES"] {
            let phases = raw
                .components(separatedBy: CharacterSet(charactersIn: ",; \n"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
            if !phases.isEmpty { settings.phases = phases }
        }
        if let raw = environment["BINDING_SURFACE_AUDIT_RESOLVE_DEADLINE_SECONDS"], let value = Double(raw) {
            settings.resolveDeadlineSeconds = value
        }
        if let raw = environment["BINDING_SURFACE_AUDIT_LOAD_DEADLINE_SECONDS"], let value = Double(raw) {
            settings.loadDeadlineSeconds = value
        }
        return settings
    }

    // MARK: - Records

    private struct AuditRecord: Codable {
        var phase: String
        var host: String
        var surface: String
        var endpoint: String
        var outcome: String        // ok | error | timeout
        var verdict: String        // green | yellow | red
        var cold: Bool
        var totalMs: Double
        var resolveMs: Double? = nil
        var fetchMs: Double? = nil
        var decodeMs: Double? = nil
        var loadMs: Double? = nil
        var renderMs: Double? = nil
        var firstContentMs: Double? = nil
        var httpStatus: Int? = nil
        var bytes: Int? = nil
        var unsupportedElements: Int? = nil
        var validationErrors: Int? = nil
        var validationWarnings: Int? = nil
        var subviews: Int? = nil
        var snapshotBytes: Int? = nil
        var unavailableNow: Int? = nil
        var referenceCount: Int? = nil
        var unresolvedReferences: [String]? = nil
        var unreadableRoots: [String]? = nil
        var rootProbeCount: Int? = nil
        var detail: String? = nil
    }

    private struct AuditReport: Codable {
        var startedAt: String
        var finishedAt: String
        var hosts: [String]
        var phases: [String]
        var appStoreCatalogGateEnabled: Bool
        var identityMode: String
        var thresholds: [String: Double]
        var records: [AuditRecord]
    }

    private struct AuditTimeout: Error, CustomStringConvertible {
        let operation: String
        let seconds: Double
        var description: String { "timeout(\(operation), \(seconds)s)" }
    }

    private struct AuditFailure: Error, CustomStringConvertible {
        let message: String
        var description: String { message }
    }

    // MARK: - Bridge status capture

    private final class BridgeStatusCapture {
        private let notificationCenter: NotificationCenter
        private let lock = NSLock()
        private var token: NSObjectProtocol?
        private var statuses: [LightweightBridgeConnectionStatus] = []

        init(notificationCenter: NotificationCenter = .default) {
            self.notificationCenter = notificationCenter
            token = notificationCenter.addObserver(
                forName: .lightweightBridgeConnectionStatusDidChange,
                object: nil,
                queue: nil
            ) { [weak self] notification in
                guard let status = LightweightBridgeConnectionStatus(notification: notification) else { return }
                self?.append(status)
            }
        }

        deinit {
            if let token { notificationCenter.removeObserver(token) }
        }

        private func append(_ status: LightweightBridgeConnectionStatus) {
            lock.lock()
            statuses.append(status)
            lock.unlock()
        }

        func drain() -> String {
            lock.lock()
            let snapshot = statuses
            statuses.removeAll()
            lock.unlock()
            guard !snapshot.isEmpty else { return "" }
            return snapshot.map { status in
                let detail = status.detail.map { " (\($0))" } ?? ""
                return "\(status.phase.rawValue)\(detail)"
            }.joined(separator: " → ")
        }
    }

    // MARK: - Entry point

    @MainActor
    func testAuditEveryReachableRemoteSurfaceOnConfiguredHosts() async throws {
        let settings = Self.loadSettings()
        try XCTSkipIf(
            settings.hosts.isEmpty,
            "Set BINDING_SURFACE_AUDIT_HOSTS or write hosts into \(Self.auditDirectory.path)/audit-settings.json to run the surface audit."
        )

        let startedAt = Self.iso8601(Date())
        let clock = ContinuousClock()
        var records: [AuditRecord] = []
        let identityMode = CellConfigurationVerifier.VerifierIdentityMode.startup
        let catalog = await Self.appCatalogSnapshot(extraCellNames: settings.extraCellNames)

        print("SURFACE_AUDIT start hosts=\(settings.hosts) phases=\(settings.phases) catalogEntries=\(catalog.offered.count) cellNames=\(catalog.remoteCellNames.count) appStoreGate=\(BindingPersonalCopilotV1Policy.appStoreCatalogGateEnabled)")

        // The local phase is host-independent: it is what a person sees in the
        // app today, with every remote Personal Co-Pilot endpoint rewritten to
        // its local fallback the way the app does when staging is unreachable.
        if settings.phases.contains("local") {
            let localRecords = await auditLocalSurfaces(
                offered: catalog.offered,
                settings: settings,
                identityMode: identityMode
            )
            records.append(contentsOf: localRecords)
            Self.emitProgress(phase: "local", host: "(lokal)", records: localRecords)
        }

        for host in settings.hosts {
            let hostStart = clock.now
            var httpConfigurations: [(surface: String, configuration: CellConfiguration)] = []

            if settings.phases.contains("bridge") {
                let bridgeRecords = await auditBridgeEndpoints(
                    host: host,
                    cellNames: catalog.remoteCellNames,
                    settings: settings,
                    identityMode: identityMode
                )
                records.append(contentsOf: bridgeRecords)
                Self.emitProgress(phase: "bridge", host: host, records: bridgeRecords)
            }

            if settings.phases.contains("http") {
                let (httpRecords, fetched) = await auditHTTPPublishedConfigurations(
                    host: host,
                    settings: settings,
                    identityMode: identityMode
                )
                records.append(contentsOf: httpRecords)
                httpConfigurations = fetched
                Self.emitProgress(phase: "http", host: host, records: httpRecords)
            }

            if settings.phases.contains("load") {
                let loadRecords = await auditLoadPath(
                    host: host,
                    offered: catalog.offered,
                    httpConfigurations: httpConfigurations,
                    settings: settings,
                    identityMode: identityMode
                )
                records.append(contentsOf: loadRecords)
                Self.emitProgress(phase: "load", host: host, records: loadRecords)
            }

            print("SURFACE_AUDIT host=\(host) done in \(Int(Self.milliseconds(since: hostStart, clock: clock))) ms")
        }

        let report = AuditReport(
            startedAt: startedAt,
            finishedAt: Self.iso8601(Date()),
            hosts: settings.hosts,
            phases: settings.phases,
            appStoreCatalogGateEnabled: BindingPersonalCopilotV1Policy.appStoreCatalogGateEnabled,
            identityMode: identityMode.rawValue,
            thresholds: [
                "coldMs": settings.coldThresholdMilliseconds,
                "warmMs": settings.warmThresholdMilliseconds,
                "resolveDeadlineS": settings.resolveDeadlineSeconds,
                "loadDeadlineS": settings.loadDeadlineSeconds,
                "renderDeadlineS": settings.renderDeadlineSeconds
            ],
            records: records
        )
        let written = Self.writeReport(report, settings: settings)
        print("SURFACE_AUDIT report=\(written.map(\.path).joined(separator: " "))")
        XCTAssertFalse(written.isEmpty, "Surface audit produced no report file.")
    }

    // MARK: - Catalog snapshot

    private struct AppCatalogSnapshot {
        let offered: [(name: String, endpoint: String, configuration: CellConfiguration)]
        /// Cell names (path component of `cell://staging.haven.digipomps.org/<Cell>`)
        /// with the first surface that referenced each.
        let remoteCellNames: [(cell: String, surface: String)]
    }

    private static func appCatalogSnapshot(extraCellNames: [String]) async -> AppCatalogSnapshot {
        let offered = await ConfigurationCatalogCell.offeredCatalogConfigurationsForVerification()
        var ordered: [(cell: String, surface: String)] = []
        var seen: Set<String> = []

        func note(_ endpoint: String, surface: String) {
            guard let cell = remoteCellName(in: endpoint) else { return }
            let key = cell.lowercased()
            guard seen.insert(key).inserted else { return }
            ordered.append((cell: cell, surface: surface))
        }

        for name in ["ConfigurationCatalog", "PersonalCopilotConfigurationCatalog"] + extraCellNames {
            note("cell://\(RemoteEndpointAccessSupport.stagingHost)/\(name)", surface: "(katalog)")
        }
        for entry in offered {
            note(entry.endpoint, surface: entry.name)
            for endpoint in remoteEndpoints(in: entry.configuration) {
                note(endpoint, surface: entry.name)
            }
        }
        for configuration in ConfigurationCatalogCell.personalCopilotV1MenuConfigurations() {
            for endpoint in remoteEndpoints(in: configuration) {
                note(endpoint, surface: configuration.name)
            }
        }
        return AppCatalogSnapshot(offered: offered, remoteCellNames: ordered)
    }

    /// Path component of a `cell://<remote host>/<Cell>` endpoint; nil for local
    /// or non-cell endpoints.
    private static func remoteCellName(in endpoint: String) -> String? {
        guard let components = URLComponents(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.scheme?.lowercased() == "cell",
              let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              !host.isEmpty,
              !RemoteEndpointAccessSupport.isLoopbackHost(host)
        else {
            return nil
        }
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return path.isEmpty ? nil : path
    }

    private static func remoteEndpoints(in configuration: CellConfiguration) -> [String] {
        var endpoints: [String] = []
        if let source = configuration.discovery?.sourceCellEndpoint {
            endpoints.append(source)
        }
        for reference in configuration.cellReferences ?? [] {
            collectEndpoints(from: reference, into: &endpoints)
        }
        return endpoints.filter { remoteCellName(in: $0) != nil }
    }

    private static func collectEndpoints(from reference: CellReference, into endpoints: inout [String]) {
        endpoints.append(reference.endpoint)
        for item in reference.setKeysAndValues {
            if let target = item.target { endpoints.append(target) }
        }
        for subscription in reference.subscriptions {
            collectEndpoints(from: subscription, into: &endpoints)
        }
    }

    private static func referencesHost(_ configuration: CellConfiguration, host: String) -> Bool {
        let needle = host.lowercased()
        return remoteEndpoints(in: configuration).contains { endpoint in
            URLComponents(string: endpoint)?.host?.lowercased() == needle
        }
    }

    /// Rewrites every `cell://<any remote host>/X` endpoint to `cell://<host>/X`
    /// and every host-relative `cell:///X` to `cell://<host>/X` (which is what the
    /// app does when a configuration arrives from a remote catalog).
    private static func retargeting(_ configuration: CellConfiguration, toHost host: String, includeLocal: Bool) -> CellConfiguration {
        CellConfigurationEndpointRetargeting.rewritingEndpoints(in: configuration) { endpoint in
            guard var components = URLComponents(string: endpoint),
                  components.scheme?.lowercased() == "cell"
            else {
                return endpoint
            }
            let currentHost = components.host?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if currentHost.isEmpty || RemoteEndpointAccessSupport.isLoopbackHost(currentHost) {
                guard includeLocal else { return endpoint }
                let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                guard !path.isEmpty else { return endpoint }
                // Keep the catalog binding local; the app does the same
                // (ensureCatalogReferenceBindingIfNeeded) to avoid a bridge round trip.
                if path.lowercased() == "configurationcatalog" { return endpoint }
                components.host = host
                components.path = "/" + path
                return components.string ?? endpoint
            }
            components.host = host
            return components.string ?? endpoint
        }
    }

    // MARK: - Phase: bridge

    private func auditBridgeEndpoints(
        host: String,
        cellNames: [(cell: String, surface: String)],
        settings: AuditSettings,
        identityMode: CellConfigurationVerifier.VerifierIdentityMode
    ) async -> [AuditRecord] {
        var records: [AuditRecord] = []
        let clock = ContinuousClock()
        let context: CellConfigurationVerifier.RuntimeContext
        do {
            context = try await CellConfigurationVerifier.makeRuntimeContext(
                for: CellConfiguration(name: "Surface Audit Bridge Probe \(host)"),
                identityMode: identityMode
            )
        } catch {
            records.append(AuditRecord(
                phase: "bridge", host: host, surface: "(runtime)", endpoint: "cell:///Porthole",
                outcome: "error", verdict: "red", cold: true, totalMs: 0,
                detail: "Could not create verifier runtime: \(Self.compact(error))"
            ))
            return records
        }

        let capture = BridgeStatusCapture()
        var cold = true
        for entry in cellNames {
            let endpoint = "cell://\(host)/\(entry.cell)"
            let start = clock.now
            var record = AuditRecord(
                phase: "bridge", host: host, surface: entry.surface, endpoint: endpoint,
                outcome: "ok", verdict: "green", cold: cold, totalMs: 0
            )
            _ = capture.drain()
            do {
                let resolver = context.resolver
                let owner = context.owner
                let emit = try await Self.withDeadline(seconds: settings.resolveDeadlineSeconds, operation: "resolveEmit \(endpoint)") {
                    try await RemoteEndpointAccessSupport.resolveEmit(
                        endpoint: endpoint,
                        resolver: resolver,
                        requester: owner,
                        accessLabel: "surface audit \(entry.cell)"
                    )
                }
                record.resolveMs = Self.milliseconds(since: start, clock: clock)
                var detail = "resolved uuid=\(emit.uuid.prefix(8))"
                if entry.cell.lowercased().hasSuffix("configurationcatalog"), let meddle = emit as? Meddle {
                    let readStart = clock.now
                    do {
                        let value = try await Self.withDeadline(seconds: settings.resolveDeadlineSeconds, operation: "get configurations") {
                            try await meddle.get(keypath: "configurations", requester: owner)
                        }
                        let count: Int
                        if case let .list(items) = value {
                            count = items.compactMap { PortableSurfaceContractSupport.extractConfiguration(from: $0) }.count
                        } else {
                            count = 0
                        }
                        detail += "; configurations=\(count) (\(Int(Self.milliseconds(since: readStart, clock: clock))) ms)"
                        if count == 0 {
                            detail += " value=\(Self.compact(String(describing: value), limit: 240))"
                        }
                    } catch {
                        detail += "; get(configurations) failed: \(Self.compact(error))"
                        record.outcome = "error"
                    }
                }
                record.detail = detail
            } catch let timeout as AuditTimeout {
                record.outcome = "timeout"
                record.detail = timeout.description
            } catch {
                record.outcome = "error"
                record.detail = Self.compact(error)
            }
            record.totalMs = Self.milliseconds(since: start, clock: clock)
            let statuses = capture.drain()
            if !statuses.isEmpty {
                record.detail = (record.detail ?? "") + " | bridge: " + Self.compact(statuses, limit: 300)
            }
            record.verdict = Self.verdict(for: record, settings: settings)
            records.append(record)
            cold = false
        }
        return records
    }

    // MARK: - Phase: http

    private struct PublishedRoute {
        let surface: String
        let route: String
    }

    @MainActor
    private func auditHTTPPublishedConfigurations(
        host: String,
        settings: AuditSettings,
        identityMode: CellConfigurationVerifier.VerifierIdentityMode
    ) async -> (records: [AuditRecord], configurations: [(surface: String, configuration: CellConfiguration)]) {
        var records: [AuditRecord] = []
        var fetched: [(surface: String, configuration: CellConfiguration)] = []
        let clock = ContinuousClock()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        let session = URLSession(configuration: configuration)

        var routes: [PublishedRoute] = [
            PublishedRoute(surface: "Personal Co-Pilot · profile", route: "/personal-copilot-v1/profile/api/configuration"),
            PublishedRoute(surface: "Personal Co-Pilot · directory", route: "/personal-copilot-v1/directory/api/configuration"),
            PublishedRoute(surface: "Personal Co-Pilot · matchmaking", route: "/personal-copilot-v1/matchmaking/api/configuration"),
            PublishedRoute(surface: "Personal Co-Pilot · chat", route: "/personal-copilot-v1/chat/api/configuration"),
            PublishedRoute(surface: "Personal Co-Pilot · meeting", route: "/personal-copilot-v1/meeting/api/configuration"),
            PublishedRoute(surface: "Personal Co-Pilot · catalog", route: "/personal-copilot-v1/catalog/api/configuration")
        ]

        // Skeleton-parity fixtures advertise their own configuration routes.
        do {
            let (data, status, ms) = try await Self.fetch(session: session, host: host, route: "/skeleton-parity/api/catalog")
            guard status == 200,
                  let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let fixtures = object["fixtures"] as? [[String: Any]]
            else {
                throw AuditFailure(message: "skeleton-parity catalog HTTP \(status) after \(Int(ms)) ms")
            }
            for fixture in fixtures {
                guard let route = fixture["configurationRoute"] as? String else { continue }
                let title = (fixture["title"] as? String) ?? (fixture["slug"] as? String) ?? route
                routes.append(PublishedRoute(surface: title, route: route))
            }
        } catch {
            records.append(AuditRecord(
                phase: "http", host: host, surface: "Skeleton Parity · catalog", endpoint: "https://\(host)/skeleton-parity/api/catalog",
                outcome: "error", verdict: "red", cold: true, totalMs: 0, detail: Self.compact(error)
            ))
        }

        var cold = true
        for published in routes {
            let endpoint = "https://\(host)\(published.route)"
            let start = clock.now
            var record = AuditRecord(
                phase: "http", host: host, surface: published.surface, endpoint: endpoint,
                outcome: "ok", verdict: "green", cold: cold, totalMs: 0
            )
            cold = false
            do {
                let (data, status, fetchMs) = try await Self.fetch(session: session, host: host, route: published.route)
                record.fetchMs = fetchMs
                record.httpStatus = status
                record.bytes = data.count
                guard status == 200 else {
                    throw AuditFailure(message: "HTTP \(status): \(Self.compact(String(data: data, encoding: .utf8) ?? "", limit: 160))")
                }

                let decodeStart = clock.now
                let decoded: CellConfiguration
                if let direct = try? JSONDecoder().decode(CellConfiguration.self, from: data) {
                    decoded = direct
                } else {
                    let value = try JSONDecoder().decode(ValueType.self, from: data)
                    guard let extracted = PortableSurfaceContractSupport.extractConfiguration(from: value) else {
                        throw AuditFailure(message: "Body is not a CellConfiguration: \(Self.compact(String(describing: value), limit: 200))")
                    }
                    decoded = extracted
                }
                record.decodeMs = Self.milliseconds(since: decodeStart, clock: clock)
                record.referenceCount = decoded.cellReferences?.count ?? 0

                let unsupported = Self.unsupportedElements(in: decoded)
                record.unsupportedElements = unsupported.count
                let validation = CellConfigurationValidationService.validate(decoded)
                record.validationErrors = validation.errorCount
                record.validationWarnings = validation.warningCount
                var detail = "name=\(decoded.name)"
                if !unsupported.isEmpty {
                    detail += "; unsupported=\(unsupported.prefix(6).joined(separator: ", "))"
                }
                if validation.errorCount > 0 {
                    detail += "; validation=\(Self.compact(String(describing: validation.issues), limit: 240))"
                }
                fetched.append((surface: published.surface, configuration: decoded))

                let renderStart = clock.now
                do {
                    let render = try await Self.withDeadline(seconds: settings.renderDeadlineSeconds, operation: "render \(decoded.name)") {
                        try await CellConfigurationVerifier.renderReport(
                            for: decoded,
                            expectedVisibleStrings: [],
                            identityMode: identityMode
                        )
                    }
                    record.renderMs = Self.milliseconds(since: renderStart, clock: clock)
                    record.firstContentMs = render.firstMeaningfulContentMilliseconds
                    record.subviews = render.subviewCount
                    record.snapshotBytes = render.snapshotByteCount
                    record.unavailableNow = render.unavailableNowCount
                    if render.subviewCount == 0 { detail += "; rendered without subviews" }
                    if render.snapshotByteCount == 0 { detail += "; blank snapshot" }
                    if render.unavailableNowCount > 0 { detail += "; unavailableNow=\(render.unavailableNowCount)" }
                } catch let timeout as AuditTimeout {
                    record.renderMs = Self.milliseconds(since: renderStart, clock: clock)
                    record.outcome = "timeout"
                    detail += "; render \(timeout.description)"
                } catch {
                    record.renderMs = Self.milliseconds(since: renderStart, clock: clock)
                    record.outcome = "error"
                    detail += "; render failed: \(Self.compact(error))"
                }
                record.detail = detail
            } catch let timeout as AuditTimeout {
                record.outcome = "timeout"
                record.detail = timeout.description
            } catch {
                record.outcome = "error"
                record.detail = Self.compact(error)
            }
            record.totalMs = Self.milliseconds(since: start, clock: clock)
            record.verdict = Self.verdict(for: record, settings: settings)
            records.append(record)
        }
        return (records, fetched)
    }

    private static func fetch(session: URLSession, host: String, route: String) async throws -> (Data, Int, Double) {
        guard let url = URL(string: "https://\(host)\(route)") else {
            throw AuditFailure(message: "invalid URL for \(route)")
        }
        let clock = ContinuousClock()
        let start = clock.now
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        return (data, status, milliseconds(since: start, clock: clock))
    }

    /// Element types the app decoder could not map, as `elementType (reason)`.
    private static func unsupportedElements(in configuration: CellConfiguration) -> [String] {
        guard let skeleton = configuration.skeleton,
              let data = try? JSONEncoder().encode(skeleton),
              let value = try? JSONDecoder().decode(ValueType.self, from: data)
        else {
            return []
        }
        var found: [String] = []
        collectUnsupported(in: value, into: &found)
        return found
    }

    private static func collectUnsupported(in value: ValueType, into found: inout [String]) {
        switch value {
        case .object(let object):
            if case let .object(payload)? = object["Unsupported"] {
                var label = "?"
                if case let .string(type)? = payload["elementType"] { label = type }
                if case let .string(reason)? = payload["reason"] {
                    label += " (\(compact(reason, limit: 80)))"
                }
                found.append(label)
            }
            for nested in object.values {
                collectUnsupported(in: nested, into: &found)
            }
        case .list(let list):
            for nested in list {
                collectUnsupported(in: nested, into: &found)
            }
        default:
            break
        }
    }

    // MARK: - Phase: load

    private func auditLoadPath(
        host: String,
        offered: [(name: String, endpoint: String, configuration: CellConfiguration)],
        httpConfigurations: [(surface: String, configuration: CellConfiguration)],
        settings: AuditSettings,
        identityMode: CellConfigurationVerifier.VerifierIdentityMode
    ) async -> [AuditRecord] {
        var records: [AuditRecord] = []
        let clock = ContinuousClock()
        let stagingHost = RemoteEndpointAccessSupport.stagingHost

        var candidates: [(surface: String, configuration: CellConfiguration)] = []
        for entry in offered where Self.referencesHost(entry.configuration, host: stagingHost) || Self.remoteCellName(in: entry.endpoint) != nil {
            candidates.append((surface: entry.name, configuration: Self.retargeting(entry.configuration, toHost: host, includeLocal: false)))
        }
        for entry in httpConfigurations {
            candidates.append((surface: "(publisert) \(entry.surface)", configuration: Self.retargeting(entry.configuration, toHost: host, includeLocal: true)))
        }
        if candidates.count > settings.maxLoadPathSurfacesPerHost {
            candidates = Array(candidates.prefix(settings.maxLoadPathSurfacesPerHost))
        }

        let capture = BridgeStatusCapture()
        var cold = true
        for candidate in candidates {
            let configuration = candidate.configuration
            let endpoints = Self.remoteEndpoints(in: configuration)
            let start = clock.now
            var record = AuditRecord(
                phase: "load", host: host, surface: candidate.surface,
                endpoint: endpoints.first ?? "(ingen fjernreferanse)",
                outcome: "ok", verdict: "green", cold: cold, totalMs: 0
            )
            record.referenceCount = configuration.cellReferences?.count ?? 0
            cold = false
            _ = capture.drain()
            do {
                let report = try await Self.withDeadline(seconds: settings.loadDeadlineSeconds, operation: "contractReport \(configuration.name)") {
                    try await CellConfigurationVerifier.contractReport(
                        for: configuration,
                        buttonsToExecute: [],
                        identityMode: identityMode
                    )
                }
                record.loadMs = report.loadMilliseconds
                record.validationErrors = report.validation.errorCount
                record.validationWarnings = report.validation.warningCount
                record.rootProbeCount = report.rootProbeResolutions.count
                let unresolved = report.unresolvedReferences.map {
                    "\($0.label)=\($0.endpoint) [\(Int($0.durationMilliseconds)) ms] \(Self.compact($0.outcome, limit: 140))"
                }
                let unreadable = report.rootProbeResolutions.filter { !$0.readable }.map {
                    "\($0.probe.qualifiedKeypath) [\(Int($0.durationMilliseconds)) ms] \(Self.compact($0.outcome, limit: 120))"
                }
                record.unresolvedReferences = unresolved.isEmpty ? nil : unresolved
                record.unreadableRoots = unreadable.isEmpty ? nil : unreadable
                let resolveTotal = report.referenceResolutions.reduce(0.0) { $0 + $1.durationMilliseconds }
                record.resolveMs = resolveTotal
                var detail = "references=\(report.referenceResolutions.count) probes=\(report.rootProbeResolutions.count) verifierTotal=\(Int(report.totalMilliseconds)) ms"
                if !unresolved.isEmpty {
                    record.outcome = "error"
                    detail += "; unresolved=\(unresolved.count)"
                }
                if !unreadable.isEmpty {
                    record.outcome = "error"
                    detail += "; unreadableRoots=\(unreadable.count)/\(report.rootProbeResolutions.count)"
                }
                if report.validation.errorCount > 0 {
                    detail += "; validationErrors=\(report.validation.errorCount)"
                }
                record.detail = detail
            } catch let timeout as AuditTimeout {
                record.outcome = "timeout"
                record.detail = timeout.description
            } catch {
                record.outcome = "error"
                record.detail = Self.compact(error)
            }
            record.totalMs = Self.milliseconds(since: start, clock: clock)
            let statuses = capture.drain()
            if !statuses.isEmpty {
                record.detail = (record.detail ?? "") + " | bridge: " + Self.compact(statuses, limit: 300)
            }
            record.verdict = Self.verdict(for: record, settings: settings)
            records.append(record)
        }
        return records
    }

    // MARK: - Phase: local

    /// Every configuration the catalog offers, retargeted to its local fallback
    /// and taken through the app's own load and render path. This is the
    /// measurement that still means something while the remote bridge is down.
    @MainActor
    private func auditLocalSurfaces(
        offered: [(name: String, endpoint: String, configuration: CellConfiguration)],
        settings: AuditSettings,
        identityMode: CellConfigurationVerifier.VerifierIdentityMode
    ) async -> [AuditRecord] {
        var records: [AuditRecord] = []
        let clock = ContinuousClock()
        var cold = true

        for entry in offered {
            let configuration = CellConfigurationEndpointRetargeting
                .rewritingStagingPersonalCopilotEndpointsToLocalFallbacks(in: entry.configuration)
            let start = clock.now
            var record = AuditRecord(
                phase: "local", host: "(lokal)", surface: entry.name, endpoint: entry.endpoint,
                outcome: "ok", verdict: "green", cold: cold, totalMs: 0
            )
            record.referenceCount = configuration.cellReferences?.count ?? 0
            let unsupported = Self.unsupportedElements(in: configuration)
            record.unsupportedElements = unsupported.count
            cold = false
            var detail = ""
            if !unsupported.isEmpty {
                detail += "unsupported=\(unsupported.prefix(6).joined(separator: ", ")); "
            }

            do {
                let report = try await Self.withDeadline(seconds: settings.loadDeadlineSeconds, operation: "contractReport \(configuration.name)") {
                    try await CellConfigurationVerifier.contractReport(
                        for: configuration,
                        buttonsToExecute: [],
                        identityMode: identityMode
                    )
                }
                record.loadMs = report.loadMilliseconds
                record.validationErrors = report.validation.errorCount
                record.validationWarnings = report.validation.warningCount
                record.rootProbeCount = report.rootProbeResolutions.count
                record.resolveMs = report.referenceResolutions.reduce(0.0) { $0 + $1.durationMilliseconds }
                let unresolved = report.unresolvedReferences.map {
                    "\($0.label)=\($0.endpoint) [\(Int($0.durationMilliseconds)) ms] \(Self.compact($0.outcome, limit: 140))"
                }
                let unreadable = report.rootProbeResolutions.filter { !$0.readable }.map {
                    "\($0.probe.qualifiedKeypath) [\(Int($0.durationMilliseconds)) ms] \(Self.compact($0.outcome, limit: 120))"
                }
                record.unresolvedReferences = unresolved.isEmpty ? nil : unresolved
                record.unreadableRoots = unreadable.isEmpty ? nil : unreadable
                if !unresolved.isEmpty || !unreadable.isEmpty {
                    record.outcome = "error"
                }
                detail += "references=\(report.referenceResolutions.count) probes=\(report.rootProbeResolutions.count) verifierTotal=\(Int(report.totalMilliseconds)) ms"
                if !unresolved.isEmpty { detail += "; unresolved=\(unresolved.count)" }
                if !unreadable.isEmpty { detail += "; unreadableRoots=\(unreadable.count)/\(report.rootProbeResolutions.count)" }
                if report.validation.errorCount > 0 { detail += "; validationErrors=\(report.validation.errorCount)" }
            } catch let timeout as AuditTimeout {
                record.outcome = "timeout"
                detail += timeout.description
            } catch {
                record.outcome = "error"
                detail += Self.compact(error)
            }

            let renderStart = clock.now
            do {
                let render = try await Self.withDeadline(seconds: settings.renderDeadlineSeconds, operation: "render \(configuration.name)") {
                    try await CellConfigurationVerifier.renderReport(
                        for: configuration,
                        expectedVisibleStrings: [],
                        identityMode: identityMode
                    )
                }
                record.renderMs = Self.milliseconds(since: renderStart, clock: clock)
                record.firstContentMs = render.firstMeaningfulContentMilliseconds
                record.subviews = render.subviewCount
                record.snapshotBytes = render.snapshotByteCount
                record.unavailableNow = render.unavailableNowCount
                if render.subviewCount == 0 {
                    detail += "; rendered without subviews"
                    record.outcome = "error"
                }
                if render.snapshotByteCount == 0 {
                    detail += "; blank snapshot"
                    record.outcome = "error"
                }
                if render.unavailableNowCount > 0 { detail += "; unavailableNow=\(render.unavailableNowCount)" }
            } catch let timeout as AuditTimeout {
                record.renderMs = Self.milliseconds(since: renderStart, clock: clock)
                record.outcome = "timeout"
                detail += "; render \(timeout.description)"
            } catch {
                record.renderMs = Self.milliseconds(since: renderStart, clock: clock)
                record.outcome = "error"
                detail += "; render failed: \(Self.compact(error))"
            }

            record.detail = detail
            record.totalMs = Self.milliseconds(since: start, clock: clock)
            record.verdict = Self.verdict(for: record, settings: settings)
            records.append(record)
        }
        return records
    }

    // MARK: - Verdicts, timing, output

    private static func verdict(for record: AuditRecord, settings: AuditSettings) -> String {
        if record.outcome != "ok" { return "red" }
        let threshold = record.cold ? settings.coldThresholdMilliseconds : settings.warmThresholdMilliseconds
        if record.totalMs > threshold { return "yellow" }
        if let unavailable = record.unavailableNow, unavailable > 0 { return "yellow" }
        if let unsupported = record.unsupportedElements, unsupported > 0 { return "yellow" }
        if let errors = record.validationErrors, errors > 0 { return "yellow" }
        return "green"
    }

    private static func milliseconds(since start: ContinuousClock.Instant, clock: ContinuousClock) -> Double {
        let duration = clock.now - start
        let components = duration.components
        return Double(components.seconds) * 1000 + Double(components.attoseconds) / 1_000_000_000_000_000
    }

    private static func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func compact(_ error: Error, limit: Int = 320) -> String {
        compact(String(describing: error), limit: limit)
    }

    private static func compact(_ text: String, limit: Int = 320) -> String {
        let single = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "|", with: "/")
        guard single.count > limit else { return single }
        return String(single.prefix(limit)) + "…"
    }

    /// Bounded wait that never blocks on a child that ignores cancellation: the
    /// continuation resumes on whichever finishes first, and the loser is
    /// cancelled and abandoned.
    private static func withDeadline<T>(
        seconds: Double,
        operation: String,
        _ work: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var didResolve = false

            func resolve(_ result: Result<T, Error>) {
                lock.lock()
                guard !didResolve else {
                    lock.unlock()
                    return
                }
                didResolve = true
                lock.unlock()
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let workTask = Task.detached {
                do {
                    resolve(.success(try await work()))
                } catch {
                    resolve(.failure(error))
                }
            }

            Task.detached {
                do {
                    try await Task.sleep(nanoseconds: UInt64(max(seconds, 0) * 1_000_000_000))
                } catch {
                    return
                }
                workTask.cancel()
                resolve(.failure(AuditTimeout(operation: operation, seconds: seconds)))
            }
        }
    }

    private static func emitProgress(phase: String, host: String, records: [AuditRecord]) {
        let red = records.filter { $0.verdict == "red" }.count
        let yellow = records.filter { $0.verdict == "yellow" }.count
        let green = records.filter { $0.verdict == "green" }.count
        print("SURFACE_AUDIT phase=\(phase) host=\(host) green=\(green) yellow=\(yellow) red=\(red)")
        for record in records {
            print("SURFACE_AUDIT_ROW phase=\(phase) host=\(host) verdict=\(record.verdict) outcome=\(record.outcome) ms=\(Int(record.totalMs)) surface=\(record.surface) endpoint=\(record.endpoint) detail=\(record.detail ?? "")")
        }
    }

    private static func writeReport(_ report: AuditReport, settings: AuditSettings) -> [URL] {
        let stamp = iso8601(Date())
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
        var directories: [URL] = []
        if let configured = settings.outputDirectory, !configured.isEmpty {
            directories.append(URL(fileURLWithPath: configured, isDirectory: true))
        }
        directories.append(auditDirectory.appendingPathComponent("reports", isDirectory: true))
        directories.append(URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("binding-surface-audit", isDirectory: true))

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let json = try? encoder.encode(report) else { return [] }
        let markdown = Data(renderMarkdown(report).utf8)

        var written: [URL] = []
        for directory in directories {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let jsonURL = directory.appendingPathComponent("surface-audit-\(stamp).json")
                let markdownURL = directory.appendingPathComponent("surface-audit-\(stamp).md")
                try json.write(to: jsonURL, options: .atomic)
                try markdown.write(to: markdownURL, options: .atomic)
                written.append(jsonURL)
                written.append(markdownURL)
                break
            } catch {
                print("SURFACE_AUDIT could not write to \(directory.path): \(error)")
                continue
            }
        }
        return written
    }

    private static func renderMarkdown(_ report: AuditReport) -> String {
        var lines: [String] = []
        lines.append("# HAVEN surface audit — \(report.startedAt)")
        lines.append("")
        lines.append("Hosts: \(report.hosts.joined(separator: ", ")) · phases: \(report.phases.joined(separator: ", ")) · identity: \(report.identityMode) · App Store-gate: \(report.appStoreCatalogGateEnabled)")
        lines.append("Thresholds: cold \(Int(report.thresholds["coldMs"] ?? 0)) ms, warm \(Int(report.thresholds["warmMs"] ?? 0)) ms, resolve deadline \(Int(report.thresholds["resolveDeadlineS"] ?? 0)) s, load deadline \(Int(report.thresholds["loadDeadlineS"] ?? 0)) s")
        lines.append("")

        var hostSections = report.hosts
        if report.records.contains(where: { $0.host == "(lokal)" }) {
            hostSections.insert("(lokal)", at: 0)
        }
        for host in hostSections {
            lines.append("## \(host)")
            var phaseOrder: [String] = ["local"]
            for phase in report.phases where !phaseOrder.contains(phase) {
                phaseOrder.append(phase)
            }
            for phase in phaseOrder {
                let rows = report.records.filter { $0.host == host && $0.phase == phase }
                guard !rows.isEmpty else { continue }
                let green = rows.filter { $0.verdict == "green" }.count
                let yellow = rows.filter { $0.verdict == "yellow" }.count
                let red = rows.filter { $0.verdict == "red" }.count
                let slowest = rows.map(\.totalMs).max() ?? 0
                let total = rows.reduce(0.0) { $0 + $1.totalMs }
                lines.append("")
                lines.append("### \(phase) — \(rows.count) rader · 🟢 \(green) · 🟡 \(yellow) · 🔴 \(red) · tregeste \(Int(slowest)) ms · sum \(Int(total)) ms")
                lines.append("")
                lines.append("| Verdict | Flate | Endepunkt | Utfall | Total ms | Faser | Detalj |")
                lines.append("|---|---|---|---|---:|---|---|")
                for row in rows.sorted(by: { $0.totalMs > $1.totalMs }) {
                    let symbol = row.verdict == "green" ? "🟢" : (row.verdict == "yellow" ? "🟡" : "🔴")
                    var phases: [String] = []
                    if let value = row.resolveMs { phases.append("resolve \(Int(value))") }
                    if let value = row.fetchMs { phases.append("fetch \(Int(value))") }
                    if let value = row.decodeMs { phases.append("decode \(Int(value))") }
                    if let value = row.loadMs { phases.append("load \(Int(value))") }
                    if let value = row.renderMs { phases.append("render \(Int(value))") }
                    if let value = row.bytes { phases.append("\(value) B") }
                    if let value = row.subviews { phases.append("subviews \(value)") }
                    if let value = row.unsupportedElements, value > 0 { phases.append("unsupported \(value)") }
                    var detail = row.detail ?? ""
                    if let unresolved = row.unresolvedReferences, !unresolved.isEmpty {
                        detail += " · unresolved: " + unresolved.joined(separator: "; ")
                    }
                    if let unreadable = row.unreadableRoots, !unreadable.isEmpty {
                        detail += " · unreadable: " + unreadable.prefix(6).joined(separator: "; ")
                    }
                    lines.append("| \(symbol) | \(row.surface) | `\(row.endpoint)` | \(row.outcome)\(row.cold ? " (kald)" : "") | \(Int(row.totalMs)) | \(phases.joined(separator: ", ")) | \(compact(detail, limit: 600)) |")
                }
            }
            lines.append("")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
