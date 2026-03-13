import Foundation
@preconcurrency import CellBase

public enum SignedRemoteIntentEnvelopeCodecError: Error, LocalizedError, Equatable, Sendable {
    case invalidEnvelope

    public var errorDescription: String? {
        switch self {
        case .invalidEnvelope:
            return "Signed remote intent envelope is invalid."
        }
    }
}

public enum SignedRemoteIntentEnvelopeValueCodec {
    public static func decode(from value: ValueType) throws -> SignedRemoteIntentEnvelope {
        guard case let .object(object) = value else {
            throw SignedRemoteIntentEnvelopeCodecError.invalidEnvelope
        }
        guard case let .object(payloadObject)? = object["payload"],
              case let .string(signatureBase64)? = object["signatureBase64"],
              case let .string(issuerID)? = payloadObject["issuerID"],
              case let .string(nonce)? = payloadObject["nonce"],
              case let .string(topic)? = payloadObject["topic"],
              case let .string(origin)? = payloadObject["origin"],
              case let .string(actionID)? = payloadObject["actionID"],
              case let .string(issuedAt)? = payloadObject["issuedAt"] else {
            throw SignedRemoteIntentEnvelopeCodecError.invalidEnvelope
        }

        let expiresAt: String?
        if case let .string(value)? = payloadObject["expiresAt"] {
            expiresAt = value
        } else {
            expiresAt = nil
        }

        let arguments: [String: String] = try {
            guard case let .object(argumentObject)? = payloadObject["arguments"] else {
                return [:]
            }
            return try argumentObject.reduce(into: [String: String]()) { partialResult, entry in
                guard case let .string(stringValue) = entry.value else {
                    throw SignedRemoteIntentEnvelopeCodecError.invalidEnvelope
                }
                partialResult[entry.key] = stringValue
            }
        }()

        return SignedRemoteIntentEnvelope(
            payload: SignedRemoteIntentPayload(
                issuerID: issuerID,
                nonce: nonce,
                topic: topic,
                origin: origin,
                actionID: actionID,
                arguments: arguments,
                issuedAt: issuedAt,
                expiresAt: expiresAt
            ),
            signatureBase64: signatureBase64
        )
    }

    public static func encode(_ envelope: SignedRemoteIntentEnvelope) -> ValueType {
        .object([
            "payload": .object([
                "issuerID": .string(envelope.payload.issuerID),
                "nonce": .string(envelope.payload.nonce),
                "topic": .string(envelope.payload.topic),
                "origin": .string(envelope.payload.origin),
                "actionID": .string(envelope.payload.actionID),
                "arguments": .object(envelope.payload.arguments.mapValues(ValueType.string)),
                "issuedAt": .string(envelope.payload.issuedAt),
                "expiresAt": envelope.payload.expiresAt.map(ValueType.string) ?? .null
            ]),
            "signatureBase64": .string(envelope.signatureBase64)
        ])
    }
}
