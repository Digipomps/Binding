// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

//
//  HavenRelationCellSupport.swift
//  Binding
//
//  Shared ValueType plumbing for the relations, import, invitation and
//  residency cells, so each of them stays about its own subject.
//

import Foundation
import CellBase

nonisolated enum HavenValue {

    nonisolated static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    nonisolated static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    nonisolated static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Bridges any Codable into the cell value world. Dates become ISO strings
    /// so a skeleton can bind them directly instead of showing a timestamp.
    nonisolated static func value<T: Encodable>(_ value: T) -> ValueType {
        guard let data = try? encoder().encode(value),
              let bridged = try? decoder().decode(ValueType.self, from: data) else {
            return .null
        }
        return bridged
    }

    nonisolated static func decode<T: Decodable>(_ type: T.Type, from value: ValueType?) -> T? {
        guard let value,
              let data = try? encoder().encode(value) else { return nil }
        return try? decoder().decode(type, from: data)
    }

    /// Bridges a plain `[String: Any]` (the shape system frameworks hand us)
    /// into a `ValueType`, via JSON so the conversion stays honest about what
    /// actually survives the trip.
    nonisolated static func value(fromJSONObject object: [String: Any]) -> ValueType? {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object),
              let bridged = try? decoder().decode(ValueType.self, from: data) else {
            return nil
        }
        return bridged
    }

    nonisolated static func object(_ value: ValueType?) -> Object? {
        guard case let .object(object)? = value else { return nil }
        return object
    }

    nonisolated static func list(_ value: ValueType?) -> [ValueType]? {
        guard case let .list(list)? = value else { return nil }
        return list
    }

    nonisolated static func string(_ value: ValueType?) -> String? {
        guard case let .string(text)? = value else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated static func stringList(_ value: ValueType?) -> [String] {
        guard case let .list(list)? = value else { return [] }
        return list.compactMap(string)
    }

    nonisolated static func bool(_ value: ValueType?) -> Bool? {
        switch value {
        case let .bool(flag)?: return flag
        case let .string(text)?:
            switch text.lowercased() {
            case "true", "yes", "1", "ja": return true
            case "false", "no", "0", "nei": return false
            default: return nil
            }
        default: return nil
        }
    }

    nonisolated static func int(_ value: ValueType?) -> Int? {
        switch value {
        case let .integer(number)?: return number
        case let .number(number)?: return number
        case let .float(number)?: return Int(number)
        case let .string(text)?: return Int(text)
        default: return nil
        }
    }

    nonisolated static func double(_ value: ValueType?) -> Double? {
        switch value {
        case let .float(number)?: return number
        case let .integer(number)?: return Double(number)
        case let .number(number)?: return Double(number)
        case let .string(text)?: return Double(text.replacingOccurrences(of: ",", with: "."))
        default: return nil
        }
    }

    nonisolated static func data(_ value: ValueType?) -> Data? {
        switch value {
        case let .data(data)?: return data
        case let .string(text)?: return Data(base64Encoded: text, options: [.ignoreUnknownCharacters])
        default: return nil
        }
    }

    nonisolated static func date(_ value: ValueType?) -> Date? {
        switch value {
        case let .string(text)?: return isoFormatter.date(from: text)
        case let .float(seconds)?: return Date(timeIntervalSince1970: seconds)
        case let .integer(seconds)?: return Date(timeIntervalSince1970: TimeInterval(seconds))
        default: return nil
        }
    }

    nonisolated static func iso(_ date: Date) -> String { isoFormatter.string(from: date) }

    nonisolated static func error(code: String, message: String, extra: Object = [:]) -> Object {
        var object: Object = [
            "status": .string("error"),
            "code": .string(code),
            "message": .string(message),
            "sideEffect": .bool(false)
        ]
        for (key, value) in extra { object[key] = value }
        return object
    }

    nonisolated static func ok(_ message: String, sideEffect: Bool, extra: Object = [:]) -> Object {
        var object: Object = [
            "status": .string("ok"),
            "message": .string(message),
            "sideEffect": .bool(sideEffect)
        ]
        for (key, value) in extra { object[key] = value }
        return object
    }

    /// Human-readable Norwegian date, for surfaces rather than protocols.
    nonisolated static func readable(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Presentation

nonisolated enum HavenRelationPresenter {

    /// The shape a skeleton list row binds to. Kept flat and pre-formatted,
    /// because a skeleton can read a keypath but cannot format a sentence.
    nonisolated static func row(for record: HavenRelationRecord) -> Object {
        let readiness = record.inviteReadiness
        let primary = record.reachableEndpoints.first
        return [
            "id": .string(record.id),
            "displayName": .string(record.displayName),
            "subtitle": .string(subtitle(for: record)),
            "organization": .string(record.organization ?? ""),
            "jobTitle": .string(record.jobTitle ?? ""),
            "primaryEndpoint": .string(primary?.raw ?? ""),
            "primaryEndpointKind": .string(primary?.kind.rawValue ?? ""),
            "endpointSummary": .string(endpointSummary(for: record)),
            "endpoints": .list(record.endpoints.map { endpoint in
                .object([
                    "kind": .string(endpoint.kind.rawValue),
                    "raw": .string(endpoint.raw),
                    "normalized": .string(endpoint.normalized),
                    "label": .string(endpoint.label ?? ""),
                    "confirmed": .bool(endpoint.confirmed),
                    "reachable": .bool(endpoint.isReachable),
                    "disclosureToken": .string(endpoint.disclosureToken)
                ])
            }),
            "contextTags": .list(record.contextTags.map(ValueType.string)),
            "tagSummary": .string(record.contextTags.prefix(4).joined(separator: " · ")),
            "roles": .list(record.roles.map { role in
                .object([
                    "context": .string(role.context),
                    "role": .string(role.role ?? ""),
                    "group": .string(role.group ?? "")
                ])
            }),
            "roleSummary": .string(record.roles.compactMap { role -> String? in
                let parts = [role.role, role.group].compactMap { $0 }
                return parts.isEmpty ? nil : parts.joined(separator: ", ")
            }.joined(separator: " · ")),
            "notes": .string(record.notes ?? ""),
            "sourceSummary": .string(sourceSummary(for: record)),
            "inviteState": .string(record.inviteState.rawValue),
            "inviteStateText": .string(stateText(record.inviteState)),
            "canInvite": .bool(readiness.canInvite),
            "inviteBlockReason": .string(readiness.canInvite ? "" : readiness.reason),
            "isInHaven": .bool(record.isInHaven),
            "entityRef": .string(record.entityRef ?? ""),
            "confidence": .float(record.confidence),
            "possibleDuplicateCount": .integer(record.possibleDuplicateIDs.count),
            "updatedAt": .string(HavenValue.iso(record.updatedAt)),
            "updatedAtText": .string(HavenValue.readable(record.updatedAt))
        ]
    }

    nonisolated static func subtitle(for record: HavenRelationRecord) -> String {
        let parts = [record.jobTitle, record.organization]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: ", ") }
        if let primary = record.reachableEndpoints.first { return primary.raw }
        return record.contextTags.prefix(3).joined(separator: " · ")
    }

    nonisolated static func endpointSummary(for record: HavenRelationRecord) -> String {
        let emails = record.endpoints.filter { $0.kind == .email }.count
        let phones = record.endpoints.filter { $0.kind == .phone }.count
        var parts: [String] = []
        if emails > 0 { parts.append(emails == 1 ? "1 e-post" : "\(emails) e-poster") }
        if phones > 0 { parts.append(phones == 1 ? "1 telefon" : "\(phones) telefoner") }
        if parts.isEmpty { return "Ingen kanal å nå denne på" }
        return parts.joined(separator: ", ")
    }

    nonisolated static func sourceSummary(for record: HavenRelationRecord) -> String {
        guard let latest = record.sources.max(by: { $0.importedAt < $1.importedAt }) else { return "" }
        let origin: String
        switch latest.kind {
        case .addressBookPicker: origin = "valgt fra kontakter"
        case .addressBookScan: origin = "kontaktliste"
        case .fileImport: origin = latest.label
        case .manual: origin = "lagt inn for hånd"
        case .nearby: origin = "møtt i nærheten"
        case .inboundInvite: origin = "kom inn via invitasjon"
        }
        return "\(origin) · \(HavenValue.readable(latest.importedAt))"
    }

    nonisolated static func stateText(_ state: HavenInviteState) -> String {
        switch state {
        case .none: return "Ikke invitert"
        case .prepared: return "Invitasjon klargjort"
        case .sent: return "Invitasjon sendt"
        case .opened: return "Har åpnet invitasjonen"
        case .joined: return "Er i HAVEN"
        case .declined: return "Takket nei"
        case .blocked: return "Blokkert"
        }
    }
}
