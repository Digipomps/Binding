// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import CellBase

nonisolated enum BindingHavenAgentDRegistrationAdapterError: Error, Equatable {
    case invalidStatusEndpoint
    case statusRequestFailed(Int)
    case emptyStatusOutput
    case invalidStatusJSON
    case missingRegistrationObservation
    case secretMaterialPresent
    case invalidSchema
    case invalidStatus
    case invalidEvidenceKind
    case invalidObservedAt
    case invalidBridgeEndpoint
    case registeredStatusRequiresBridge
    case missingBrokerResponse
}

nonisolated struct BindingHavenAgentDStatusClient: Sendable {
    typealias DataLoader = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    var controlBridgeEndpoint: String
    var accessToken: String
    var dataLoader: DataLoader

    init(
        controlBridgeEndpoint: String,
        accessToken: String,
        dataLoader: @escaping DataLoader = { request in
            try await URLSession.shared.data(for: request)
        }
    ) {
        self.controlBridgeEndpoint = controlBridgeEndpoint
        self.accessToken = accessToken
        self.dataLoader = dataLoader
    }

    func loadStatusJSON() async throws -> Data {
        let request = try statusRequest()
        let (data, response) = try await dataLoader(request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw BindingHavenAgentDRegistrationAdapterError.statusRequestFailed(statusCode)
        }
        guard data.isEmpty == false else {
            throw BindingHavenAgentDRegistrationAdapterError.emptyStatusOutput
        }
        return data
    }

    func statusRequest() throws -> URLRequest {
        guard accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              var components = URLComponents(string: controlBridgeEndpoint),
              components.user == nil,
              components.password == nil,
              components.query == nil,
              Self.isLoopbackHost(components.host) else {
            throw BindingHavenAgentDRegistrationAdapterError.invalidStatusEndpoint
        }
        switch components.scheme?.lowercased() {
        case "ws":
            components.scheme = "http"
        case "wss":
            components.scheme = "https"
        case "http", "https":
            break
        default:
            throw BindingHavenAgentDRegistrationAdapterError.invalidStatusEndpoint
        }
        components.path = "/onboard/status.json"
        components.fragment = nil
        components.queryItems = [URLQueryItem(name: "token", value: accessToken)]
        guard let url = components.url else {
            throw BindingHavenAgentDRegistrationAdapterError.invalidStatusEndpoint
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 5
        return request
    }

    private static func isLoopbackHost(_ host: String?) -> Bool {
        switch host?.lowercased() {
        case "127.0.0.1", "localhost", "::1", "0:0:0:0:0:0:0:1":
            return true
        default:
            return false
        }
    }
}

nonisolated struct BindingHavenAgentDRegistrationObservation: Equatable, Sendable {
    static let schema = "haven.agentd-registration-observation.v1"
    static let evidenceKind = "haven-agentd.status-json"
    static let evidenceAuthority = "owner-reported-runtime-observation-not-a-grant"

    var status: String
    var availableActionIDs: [String]
    var bridgeEndpoint: String?
    var observedAt: String

    var objectValue: Object {
        [
            "schema": .string(Self.schema),
            "status": .string(status),
            "evidenceKind": .string(Self.evidenceKind),
            "availableActionIDs": .list(availableActionIDs.map(ValueType.string)),
            "bridgeEndpoint": bridgeEndpoint.map(ValueType.string) ?? .null,
            "observedAt": .string(observedAt),
            "evidenceAuthority": .string(Self.evidenceAuthority),
            "containsAccessToken": .bool(false)
        ]
    }
}

nonisolated enum BindingHavenAgentDRegistrationAdapter {
    static let reportKeypath = "registration.report"
    static let brokerActionIDs = [
        "mac.finder.close-all-windows",
        "shortcut.binding.wake",
        "binding.absorb.cell-input",
        "folder-watch.changed-input",
        "sprout.sync.local-agent"
    ]

    static func refreshAndReport(
        client: BindingHavenAgentDStatusClient,
        to broker: any Meddle,
        requester: Identity
    ) async throws -> ValueType {
        let statusJSON = try await client.loadStatusJSON()
        return try await report(statusJSON: statusJSON, to: broker, requester: requester)
    }

    static func report(
        statusJSON: Data,
        to broker: any Meddle,
        requester: Identity
    ) async throws -> ValueType {
        let observation = try observation(from: statusJSON)
        guard let response = try await broker.set(
            keypath: reportKeypath,
            value: .object(observation.objectValue),
            requester: requester
        ) else {
            throw BindingHavenAgentDRegistrationAdapterError.missingBrokerResponse
        }
        return response
    }

    static func observation(from statusJSON: Data) throws -> BindingHavenAgentDRegistrationObservation {
        guard let root = try? JSONSerialization.jsonObject(with: statusJSON) as? [String: Any] else {
            throw BindingHavenAgentDRegistrationAdapterError.invalidStatusJSON
        }
        let raw = root["registrationObservation"] as? [String: Any]
            ?? (root["status"] as? [String: Any])?["registrationObservation"] as? [String: Any]
        guard let raw else {
            throw BindingHavenAgentDRegistrationAdapterError.missingRegistrationObservation
        }
        guard containsForbiddenKey(raw) == false else {
            throw BindingHavenAgentDRegistrationAdapterError.secretMaterialPresent
        }
        guard string(raw["schema"]) == BindingHavenAgentDRegistrationObservation.schema else {
            throw BindingHavenAgentDRegistrationAdapterError.invalidSchema
        }
        guard let status = string(raw["status"]),
              ["unknown", "not_installed", "installed_not_running", "registered"].contains(status) else {
            throw BindingHavenAgentDRegistrationAdapterError.invalidStatus
        }
        guard string(raw["evidenceKind"]) == BindingHavenAgentDRegistrationObservation.evidenceKind else {
            throw BindingHavenAgentDRegistrationAdapterError.invalidEvidenceKind
        }
        guard let observedAt = string(raw["observedAt"]),
              ISO8601DateFormatter().date(from: observedAt) != nil else {
            throw BindingHavenAgentDRegistrationAdapterError.invalidObservedAt
        }
        if let containsAccessToken = raw["containsAccessToken"] as? Bool, containsAccessToken {
            throw BindingHavenAgentDRegistrationAdapterError.secretMaterialPresent
        }

        let rawEndpoint = string(raw["bridgeEndpoint"])
        let bridgeEndpoint = try rawEndpoint.map(sanitizedLoopbackEndpoint)
        if status == "registered", bridgeEndpoint == nil {
            throw BindingHavenAgentDRegistrationAdapterError.registeredStatusRequiresBridge
        }

        let reportedActionIDs = (raw["availableActionIDs"] as? [Any] ?? []).compactMap(string)
        let reported = Set(reportedActionIDs)
        return BindingHavenAgentDRegistrationObservation(
            status: status,
            availableActionIDs: brokerActionIDs.filter(reported.contains),
            bridgeEndpoint: status == "registered" ? bridgeEndpoint : nil,
            observedAt: observedAt
        )
    }

    private static func sanitizedLoopbackEndpoint(_ raw: String) throws -> String {
        guard var components = URLComponents(string: raw),
              components.scheme == "ws" || components.scheme == "wss",
              isLoopbackHost(components.host),
              components.user == nil,
              components.password == nil,
              components.query == nil else {
            throw BindingHavenAgentDRegistrationAdapterError.invalidBridgeEndpoint
        }
        components.fragment = nil
        guard let result = components.string else {
            throw BindingHavenAgentDRegistrationAdapterError.invalidBridgeEndpoint
        }
        return result
    }

    private static func isLoopbackHost(_ host: String?) -> Bool {
        switch host?.lowercased() {
        case "127.0.0.1", "localhost", "::1", "0:0:0:0:0:0:0:1":
            return true
        default:
            return false
        }
    }

    private static func containsForbiddenKey(_ value: Any) -> Bool {
        if let object = value as? [String: Any] {
            for (key, child) in object {
                let normalized = key.lowercased().replacingOccurrences(of: "_", with: "")
                if ["accesstoken", "token", "secret", "credential"].contains(normalized) {
                    return true
                }
                if containsForbiddenKey(child) {
                    return true
                }
            }
        } else if let list = value as? [Any] {
            return list.contains(where: containsForbiddenKey)
        }
        return false
    }

    private static func string(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
