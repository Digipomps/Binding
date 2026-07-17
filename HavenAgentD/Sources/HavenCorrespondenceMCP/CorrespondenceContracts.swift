import Foundation
import HavenAgentRuntime

enum CorrespondenceContract {
  static let schemaVersion = 1
  static let maximumRequestLifetime: TimeInterval = 5 * 60
  static let defaultPurposeRef = "purpose://contact.communication"
  static let endpoint = "cell:///AssistantCorrespondence"
  static let accessCredentialType = "HAVENAssistantCorrespondenceAccessCredential"
  static let operations = ["inbox.list", "message.read", "message.send", "message.ack"]
}

struct CorrespondenceProof: Codable, Equatable, Sendable {
  var algorithm: String
  var signatureBase64URL: String
}

struct CorrespondenceArguments: Codable, Equatable, Sendable {
  var recipientID: String? = nil
  var subject: String? = nil
  var content: String? = nil
  var purposeRef: String? = nil
  var clientMessageID: String? = nil
  var messageID: String? = nil
  var afterSequence: Int? = nil
  var limit: Int? = nil
  var retentionSeconds: Int? = nil
}

struct CorrespondenceRequestPayload: Codable, Equatable, Sendable {
  var version: Int
  var requestID: String
  var operation: String
  var principalID: String
  var deviceID: String
  var identityUUID: String
  var issuedAt: String
  var expiresAt: String
  var nonce: String
  var arguments: CorrespondenceArguments
}

struct CorrespondenceSignedRequest: Codable, Equatable, Sendable {
  var payload: CorrespondenceRequestPayload
  var accessCredential: CorrespondenceAccessCredential
  var proof: CorrespondenceProof
}

struct CorrespondenceEnrollmentPayload: Codable, Equatable, Sendable {
  var version: Int
  var requestID: String
  var inviteID: String
  var inviteSecret: String
  var principalID: String
  var deviceID: String
  var identityUUID: String
  var entityRef: String
  var displayName: String
  var publicKeyBase64URL: String
  var issuedAt: String
  var expiresAt: String
  var nonce: String
}

struct CorrespondenceAccessStatusPayload: Codable, Equatable, Sendable {
  var version: Int
  var requestID: String
  var accessRequestID: String
  var principalID: String
  var deviceID: String
  var identityUUID: String
  var issuedAt: String
  var expiresAt: String
  var nonce: String
}

struct CorrespondenceAccessStatusRequest: Codable, Equatable, Sendable {
  var payload: CorrespondenceAccessStatusPayload
  var proof: CorrespondenceProof
}

struct CorrespondenceAccessCredentialPayload: Codable, Equatable, Sendable {
  var version: Int
  var credentialID: String
  var credentialType: String
  var issuerIdentityUUID: String
  var subjectEntityRef: String
  var principalID: String
  var deviceID: String
  var identityUUID: String
  var publicKeyBase64URL: String
  var resourceRefs: [String]
  var allowedPeerIDs: [String]
  var allowedOperations: [String]
  var allowedPurposeRefs: [String]
  var issuedAt: String
  var expiresAt: String
  var approvalRequestID: String
  var approvalReceiptID: String
  var revocationRef: String
}

struct CorrespondenceAccessCredentialProof: Codable, Equatable, Sendable {
  var algorithm: String
  var issuerPublicKeyBase64URL: String
  var signatureBase64URL: String
}

struct CorrespondenceAccessCredential: Codable, Equatable, Sendable {
  var payload: CorrespondenceAccessCredentialPayload
  var proof: CorrespondenceAccessCredentialProof
}

struct CorrespondenceEnrollmentRequest: Codable, Equatable, Sendable {
  var payload: CorrespondenceEnrollmentPayload
  var proof: CorrespondenceProof
}

struct CorrespondenceEnrollmentInviteFile: Codable, Equatable, Sendable {
  var version: Int
  var baseURL: String
  var profile: String
  var principalID: String
  var entityRef: String
  var deviceID: String?
  var displayName: String
  var inviteID: String
  var inviteSecret: String
}

struct CorrespondenceProfile: Codable, Equatable, Sendable {
  var version: Int
  var profile: String
  var baseURL: String
  var principalID: String
  var entityRef: String?
  var deviceID: String
  var displayName: String
  var identityUUID: String
  var publicKeyBase64URL: String
  var enrolledAt: String
  var accessRequestID: String?
  var accessCredential: CorrespondenceAccessCredential?
}

enum CorrespondenceCanonicalCoding {
  static func data<T: Encodable>(for value: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(value)
  }

  static func dateString(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }

  static func date(_ raw: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: raw) { return date }
    return ISO8601DateFormatter().date(from: raw)
  }

  static func signed<T: Encodable>(_ payload: T, with material: AgentIdentityMaterial) throws
    -> CorrespondenceProof
  {
    let signature = try material.privateKey().signature(for: data(for: payload))
    return CorrespondenceProof(algorithm: "Ed25519", signatureBase64URL: base64URL(signature))
  }

  static func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  static func data(base64URL: String) -> Data? {
    var value =
      base64URL
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    let remainder = value.count % 4
    if remainder != 0 { value += String(repeating: "=", count: 4 - remainder) }
    return Data(base64Encoded: value)
  }
}

struct CorrespondencePaths: Sendable {
  var root: URL
  var profileFile: URL { root.appendingPathComponent("profile.json") }
  var identityFile: URL { root.appendingPathComponent("identity.json") }

  static func resolve(profile: String, rootOverride: String?) throws -> CorrespondencePaths {
    if let rootOverride,
      rootOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    {
      return CorrespondencePaths(
        root: URL(
          fileURLWithPath: NSString(string: rootOverride).expandingTildeInPath, isDirectory: true))
    }
    let home = FileManager.default.homeDirectoryForCurrentUser
    return CorrespondencePaths(
      root:
        home
        .appendingPathComponent(
          "Library/Application Support/HAVEN/AssistantCorrespondence", isDirectory: true
        )
        .appendingPathComponent(profile, isDirectory: true))
  }
}
