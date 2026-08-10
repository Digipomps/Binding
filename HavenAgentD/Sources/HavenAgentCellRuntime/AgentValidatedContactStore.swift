// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
@preconcurrency import CellBase

public struct AgentValidatedContactStoreInput: Codable, Equatable, Sendable {
    public var relationID: String
    public var displayName: String
    public var email: String?
    public var phoneE164: String?
    public var sourceKind: String
    public var sourceLabel: String
    public var observedAt: String
    public var purposeRefs: [String]

    public init(
        relationID: String,
        displayName: String,
        email: String? = nil,
        phoneE164: String? = nil,
        sourceKind: String,
        sourceLabel: String,
        observedAt: String,
        purposeRefs: [String]
    ) {
        self.relationID = relationID
        self.displayName = displayName
        self.email = email
        self.phoneE164 = phoneE164
        self.sourceKind = sourceKind
        self.sourceLabel = sourceLabel
        self.observedAt = observedAt
        self.purposeRefs = purposeRefs
    }

    func recordValue() -> ValueType {
        var channels: Object = [:]
        if let email { channels["email"] = .string(email) }
        if let phoneE164 { channels["phoneE164"] = .string(phoneE164) }
        return .object([
            "schema": .string(EntityValidatedContactRecordV1.recordSchema),
            "relationID": .string(relationID),
            "displayName": .string(displayName),
            "channels": .object(channels),
            "provenance": .object([
                "sourceKind": .string(sourceKind),
                "sourceLabel": .string(sourceLabel),
                "observedAt": .string(observedAt)
            ]),
            "purposeRefs": .list(purposeRefs.map(ValueType.string)),
            "retention": .object([
                "storageAuthorized": .bool(true),
                "disclosureAuthorized": .bool(false)
            ]),
            "status": .string("owner-accepted")
        ])
    }
}

public struct AgentValidatedContactStoreReceipt: Codable, Equatable, Sendable {
    public var relationID: String
    public var keypath: String
    public var partitionID: String
    public var epoch: Int
    public var revision: Int
    public var entryHash: String
    public var payloadHash: String
    public var authorityCellUUID: String
    public var authorityIdentityUUID: String
    public var committedAtEpochMilliseconds: Int
    public var durabilityLevel: String
    public var replicationState: String
    public var quorumSatisfied: Bool
    public var distributedCommit: Bool
    public var storageAuthorized: Bool
    public var disclosureAuthorized: Bool
    public var readAfterReloadVerified: Bool
}

public struct AgentValidatedContactVerification: Codable, Equatable, Sendable {
    public var relationID: String
    public var keypath: String
    public var matchesAuthorizedRecord: Bool
    public var storageAuthorized: Bool
    public var disclosureAuthorized: Bool
}

public enum AgentValidatedContactStoreError: Error, LocalizedError {
    case runtimeUnavailable
    case emptyStandardInput
    case verificationMismatch

    public var errorDescription: String? {
        switch self {
        case .runtimeUnavailable:
            return "The local agent EntityAnchor runtime is unavailable."
        case .emptyStandardInput:
            return "Expected one validated-contact JSON object on standard input."
        case .verificationMismatch:
            return "The persisted validated-contact record does not match the authorized input."
        }
    }
}
