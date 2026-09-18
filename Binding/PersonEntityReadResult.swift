// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import CellBase
import Foundation

/// Validated reply from one explicitly selected origin. Source provenance is
/// that HTTPS server's assertion, not an independently signed data receipt.
/// Values are transient to this call; this type installs no cache or index.
nonisolated struct PersonEntityReadResult: Sendable {
    enum Status: String, Sendable { case complete, partial, denied, unavailable }
    struct Fragment: Sendable {
        enum Status: String, Sendable { case available, denied, unavailable }
        let requestID: String
        let keypath: String
        let status: Status
        let value: ValueType?
        let sourceOrigin: String?
        let sourceReference: String?
    }
    let status: Status
    let fragments: [Fragment]

    /// v1 deliberately provides independent reads and no verified revision.
    /// Reject a contradictory reply instead of presenting a coherent snapshot.
    static func decode(_ value: ValueType, keypaths: [String], origin: String,
                       anchorUUID: String) throws -> Self {
        typealias Failure = BindingPersonEntityReadRouteContract.Failure
        guard (1...16).contains(keypaths.count), case let .object(object) = value,
              case let .string(statusText)? = object["status"], let status = Status(rawValue: statusText) else {
            throw Failure.malformed
        }
        if Set(object.keys) == ["status", "error"] {
            guard status == .denied || status == .unavailable,
                  validError(object["error"]) else { throw Failure.malformed }
            // Do not pass server error text into the UI or logs.
            return Self(status: status, fragments: [])
        }
        guard Set(object.keys) == ["schema", "status", "consistency", "revisionVerified", "retained", "fragments"],
              object["schema"] == .string("haven.entity-data-query-result.v1"),
              object["consistency"] == .string("independent-reads"),
              object["revisionVerified"] == .bool(false), object["retained"] == .bool(false),
              case let .list(rows)? = object["fragments"], rows.count == keypaths.count else { throw Failure.malformed }
        var fragments: [Fragment] = []
        var available = 0, unavailable = 0
        var remainingValueBytes = 512 * 1024
        for (index, row) in rows.enumerated() {
            guard case let .object(fragment) = row,
                  fragment["requestID"] == .string(String(index)), fragment["keypath"] == .string(keypaths[index]),
                  fragment["revision"] == .null,
                  case let .string(text)? = fragment["status"], let state = Fragment.Status(rawValue: text) else {
                throw Failure.malformed
            }
            let base: Set<String> = ["requestID", "keypath", "status", "sourceOrigin", "sourceReference", "revision"]
            if state == .available {
                guard Set(fragment.keys) == base.union(["value"]),
                      fragment["sourceOrigin"] == .string(origin),
                      fragment["sourceReference"] == .string("cell:///" + anchorUUID),
                      let data = fragment["value"],
                      let count = boundedValueBytes(data, limit: remainingValueBytes) else { throw Failure.malformed }
                remainingValueBytes -= count
                available += 1
                fragments.append(.init(requestID: String(index), keypath: keypaths[index], status: state,
                    value: data, sourceOrigin: origin, sourceReference: "cell:///" + anchorUUID))
            } else {
                guard Set(fragment.keys) == base.union(["error"]),
                      fragment["sourceOrigin"] == .null, fragment["sourceReference"] == .null,
                      validError(fragment["error"]) else { throw Failure.malformed }
                if state == .unavailable { unavailable += 1 }
                fragments.append(.init(requestID: String(index), keypath: keypaths[index], status: state,
                    value: nil, sourceOrigin: nil, sourceReference: nil))
            }
        }
        let derived: Status = available == keypaths.count ? .complete
            : (available > 0 ? .partial : (unavailable > 0 ? .unavailable : .denied))
        guard status == derived else { throw Failure.malformed }
        return Self(status: status, fragments: fragments)
    }

    private static func validError(_ value: ValueType?) -> Bool {
        guard case let .object(error)? = value, Set(error.keys) == ["code", "message"],
              case let .string(code)? = error["code"], !code.isEmpty, code.utf8.count <= 128,
              case let .string(message)? = error["message"], message.utf8.count <= 512 else { return false }
        return true
    }

    static let maximumFragmentBytes = 64 * 1024
    static let maximumQueryValueBytes = 512 * 1024
    static let maximumFragmentNodes = 4096
    static let maximumFragmentDepth = 32

    /// Conservative compact JSON budget without first allocating an encoded
    /// copy of an arbitrarily large value. Only existing plain JSON projections
    /// are eligible; opaque wrappers still require a separate public projection.
    private static func boundedValueBytes(_ value: ValueType, limit: Int) -> Int? {
        var bytes = min(limit, maximumFragmentBytes)
        let initial = bytes
        var nodes = maximumFragmentNodes
        guard bytes >= 0, consumeValue(value, bytes: &bytes, nodes: &nodes, depth: 0) else { return nil }
        return initial - bytes
    }

    private static func consumeValue(_ value: ValueType, bytes: inout Int, nodes: inout Int, depth: Int) -> Bool {
        guard depth <= maximumFragmentDepth, nodes > 0 else { return false }
        nodes -= 1
        switch value {
        case .null, .bool:
            return consume(5, bytes: &bytes)
        case .number, .integer:
            return consume(32, bytes: &bytes)
        case let .float(number):
            return number.isFinite && consume(32, bytes: &bytes)
        case let .string(text):
            return consumeString(text, bytes: &bytes)
        case let .list(values):
            guard consume(2, bytes: &bytes) else { return false }
            for value in values {
                guard consume(1, bytes: &bytes), consumeValue(value, bytes: &bytes, nodes: &nodes, depth: depth + 1) else { return false }
            }
            return true
        case let .object(object):
            guard consume(2, bytes: &bytes) else { return false }
            for (key, nested) in object {
                guard consume(2, bytes: &bytes), consumeString(key, bytes: &bytes),
                      consumeValue(nested, bytes: &bytes, nodes: &nodes, depth: depth + 1) else { return false }
            }
            return true
        default:
            return false
        }
    }

    private static func consumeString(_ text: String, bytes: inout Int) -> Bool {
        guard consume(2, bytes: &bytes) else { return false }
        for byte in text.utf8 {
            // Allow both slash escaping and conservative Unicode escaping.
            // Iteration stops at the budget, without copying the whole string.
            let cost: Int
            switch byte {
            case 0x22, 0x2f, 0x5c: cost = 2
            case 0x20...0x7e: cost = 1
            default: cost = 6
            }
            guard consume(cost, bytes: &bytes) else { return false }
        }
        return true
    }

    private static func consume(_ amount: Int, bytes: inout Int) -> Bool {
        guard bytes >= amount else { return false }
        bytes -= amount
        return true
    }

}
