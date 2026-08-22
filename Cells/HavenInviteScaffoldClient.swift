// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

//
//  HavenInviteScaffoldClient.swift
//  Binding
//
//  The one place Binding talks to a scaffold about invitations.
//
//  Four calls, all of them the issuer's own device acting on the issuer's own
//  tickets: register a ticket, withdraw it, read its status, collect replies.
//  Nothing here reads anybody else's data, and nothing sends a message to a
//  person — the scaffold is a relay and a counter, not a mailer.
//
//  Reads are authorised with the `statusKey` minted at publication time.
//  Signing every read would be neater, but it would also mean the scaffold
//  learning which device is asking, and how often. A bearer token the issuer
//  generated and never shared says exactly as much as it has to.
//

import Foundation
import CellBase

enum HavenInviteTransportFailure: Error, Sendable {
    case notConfigured
    case transport(String)
    case rejected(String)

    var code: String {
        switch self {
        case .notConfigured: return "not_configured"
        case .transport: return "transport"
        case .rejected: return "rejected"
        }
    }

    var userMessage: String {
        switch self {
        case .notConfigured:
            return "Ingen landingsside er satt opp, så billetten ble ikke registrert."
        case .transport(let detail):
            return "Fikk ikke kontakt med scaffoldet: \(detail)"
        case .rejected(let detail):
            return "Scaffoldet avviste forespørselen: \(detail)"
        }
    }
}

enum BindingInviteScaffoldClient {

    /// Short on purpose. A prepare that hangs is worse than a prepare that
    /// falls back to a self-contained link and says so.
    static let timeout: TimeInterval = 8

    private static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout * 2
        configuration.httpAdditionalHeaders = ["Accept": "application/json"]
        return URLSession(configuration: configuration)
    }

    private static func url(landingBase: String, path: String) -> URL? {
        let base = landingBase.trimmingCharacters(in: CharacterSet(charactersIn: " /"))
        guard !base.isEmpty else { return nil }
        return URL(string: base + path)
    }

    @discardableResult
    static func post<Body: Encodable>(
        path: String,
        landingBase: String,
        body: Body
    ) async -> Result<Data, HavenInviteTransportFailure> {
        guard let url = url(landingBase: landingBase, path: path) else {
            return .failure(.notConfigured)
        }
        guard let payload = try? JSONEncoder().encode(body) else {
            return .failure(.rejected("kunne ikke kode forespørselen"))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload

        do {
            let (data, response) = try await session().data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.transport("uventet svar"))
            }
            guard (200...299).contains(http.statusCode) else {
                return .failure(.rejected(Self.describe(status: http.statusCode, data: data)))
            }
            return .success(data)
        } catch {
            return .failure(.transport(error.localizedDescription))
        }
    }

    static func status(
        landingBase: String,
        ticketID: String,
        statusKey: String
    ) async -> Result<HavenInviteStatusReport, HavenInviteTransportFailure> {
        let query = StatusQuery(ticketID: ticketID, statusKey: statusKey)
        switch await post(path: "/i/api/status", landingBase: landingBase, body: query) {
        case .failure(let failure):
            return .failure(failure)
        case .success(let data):
            guard let report = try? JSONDecoder().decode(HavenInviteStatusReport.self, from: data) else {
                return .failure(.rejected("kunne ikke lese statussvaret"))
            }
            return .success(report)
        }
    }

    static func contactRequests(
        landingBase: String,
        ticketID: String,
        statusKey: String
    ) async -> Result<[HavenInviteContactRequest], HavenInviteTransportFailure> {
        let query = StatusQuery(ticketID: ticketID, statusKey: statusKey)
        switch await post(path: "/i/api/requests", landingBase: landingBase, body: query) {
        case .failure(let failure):
            return .failure(failure)
        case .success(let data):
            guard let envelope = try? JSONDecoder().decode(ContactRequestEnvelope.self, from: data) else {
                return .failure(.rejected("kunne ikke lese svarene"))
            }
            return .success(envelope.requests)
        }
    }

    /// Server error bodies are for us, not for the person. Pull out the one
    /// field worth showing and leave the rest in the log.
    private static func describe(status: Int, data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = object["message"] as? String ?? object["reason"] as? String {
            return message
        }
        switch status {
        case 401, 403: return "ikke autorisert"
        case 404: return "billetten finnes ikke der"
        case 409: return "billetten er allerede registrert"
        case 429: return "for mange forsøk, vent litt"
        case 500...599: return "serverfeil (\(status))"
        default: return "HTTP \(status)"
        }
    }

    struct StatusQuery: Codable, Sendable {
        var ticketID: String
        var statusKey: String
    }

    struct ContactRequestEnvelope: Codable, Sendable {
        var requests: [HavenInviteContactRequest]
    }
}
