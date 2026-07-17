import Foundation
import HavenAgentRuntime

#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif

typealias CorrespondenceJSONObject = [String: Any]

struct CorrespondenceHTTPResponse: @unchecked Sendable {
  var statusCode: Int
  var object: CorrespondenceJSONObject
}

protocol CorrespondenceHTTPTransporting: Sendable {
  func post(url: URL, body: Data) async throws -> CorrespondenceHTTPResponse
}

struct URLSessionCorrespondenceTransport: CorrespondenceHTTPTransporting {
  func post(url: URL, body: Data) async throws -> CorrespondenceHTTPResponse {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = body
    request.timeoutInterval = 30
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw CorrespondenceClientError.invalidResponse
    }
    guard let object = try JSONSerialization.jsonObject(with: data) as? CorrespondenceJSONObject
    else {
      throw CorrespondenceClientError.invalidResponse
    }
    return CorrespondenceHTTPResponse(statusCode: http.statusCode, object: object)
  }
}

enum CorrespondenceClientError: Error, LocalizedError {
  case invalidBaseURL
  case invalidResponse
  case serverRejected(String)
  case profileMissing(String)
  case profileIdentityMismatch
  case unsupportedVersion(Int)
  case accessPending(String)
  case invalidAccessCredential(String)

  var errorDescription: String? {
    switch self {
    case .invalidBaseURL: return "The correspondence base URL is invalid or is not HTTPS."
    case .invalidResponse: return "The correspondence service returned an invalid response."
    case .serverRejected(let message):
      return "The correspondence service rejected the request: \(message)"
    case .profileMissing(let path): return "No enrolled correspondence profile exists at \(path)."
    case .profileIdentityMismatch:
      return "The enrolled profile does not match its Keychain-backed device identity."
    case .unsupportedVersion(let version):
      return "Correspondence contract version \(version) is not supported."
    case .accessPending(let requestID):
      return "Correspondence access is awaiting Kjetil's decision (request \(requestID))."
    case .invalidAccessCredential(let message):
      return "The Entity-bound correspondence access proof is invalid: \(message)"
    }
  }
}

actor CorrespondenceClient {
  let profile: CorrespondenceProfile
  private let material: AgentIdentityMaterial
  private let transport: any CorrespondenceHTTPTransporting
  private let now: @Sendable () -> Date

  init(
    profile: CorrespondenceProfile,
    material: AgentIdentityMaterial,
    transport: any CorrespondenceHTTPTransporting = URLSessionCorrespondenceTransport(),
    now: @escaping @Sendable () -> Date = Date.init
  ) throws {
    guard profile.identityUUID == material.descriptor.identityUUID,
      profile.publicKeyBase64URL == material.descriptor.publicKeyBase64URL
    else {
      throw CorrespondenceClientError.profileIdentityMismatch
    }
    self.profile = profile
    self.material = material
    self.transport = transport
    self.now = now
  }

  static func load(
    paths: CorrespondencePaths,
    transport: any CorrespondenceHTTPTransporting = URLSessionCorrespondenceTransport(),
    now: @escaping @Sendable () -> Date = Date.init
  ) async throws -> CorrespondenceClient {
    guard FileManager.default.fileExists(atPath: paths.profileFile.path) else {
      throw CorrespondenceClientError.profileMissing(paths.profileFile.path)
    }
    let profile = try JSONDecoder().decode(
      CorrespondenceProfile.self, from: Data(contentsOf: paths.profileFile))
    guard profile.version == CorrespondenceContract.schemaVersion else {
      throw CorrespondenceClientError.unsupportedVersion(profile.version)
    }
    try validateBaseURL(profile.baseURL)
    let material = try await AgentIdentityStore(fileURL: paths.identityFile).loadOrCreate(
      instanceName: "correspondence-\(profile.profile)")
    return try CorrespondenceClient(
      profile: profile, material: material, transport: transport, now: now)
  }

  static func enroll(
    invite: CorrespondenceEnrollmentInviteFile,
    paths: CorrespondencePaths,
    transport: any CorrespondenceHTTPTransporting = URLSessionCorrespondenceTransport(),
    now: @escaping @Sendable () -> Date = Date.init
  ) async throws -> (CorrespondenceProfile, CorrespondenceJSONObject) {
    guard invite.version == CorrespondenceContract.schemaVersion else {
      throw CorrespondenceClientError.unsupportedVersion(invite.version)
    }
    try validateBaseURL(invite.baseURL)
    let material = try await AgentIdentityStore(fileURL: paths.identityFile).loadOrCreate(
      instanceName: "correspondence-\(invite.profile)")
    let issued = now()
    let payload = CorrespondenceEnrollmentPayload(
      version: CorrespondenceContract.schemaVersion,
      requestID: "enroll-\(UUID().uuidString.lowercased())",
      inviteID: invite.inviteID,
      inviteSecret: invite.inviteSecret,
      principalID: invite.principalID,
      deviceID: invite.deviceID ?? "device-\(UUID().uuidString.lowercased())",
      identityUUID: material.descriptor.identityUUID,
      entityRef: invite.entityRef,
      displayName: invite.displayName,
      publicKeyBase64URL: material.descriptor.publicKeyBase64URL,
      issuedAt: CorrespondenceCanonicalCoding.dateString(issued),
      expiresAt: CorrespondenceCanonicalCoding.dateString(issued.addingTimeInterval(120)),
      nonce: UUID().uuidString.lowercased()
    )
    let request = CorrespondenceEnrollmentRequest(
      payload: payload,
      proof: try CorrespondenceCanonicalCoding.signed(payload, with: material)
    )
    let response = try await transport.post(
      url: try endpoint(baseURL: invite.baseURL, path: "enroll"),
      body: try CorrespondenceCanonicalCoding.data(for: request)
    )
    let status = response.object["status"] as? String
    let acceptedStatuses = ["pending_approval", "enrolled", "already_enrolled", "approved"]
    guard response.statusCode == 200, let status, acceptedStatuses.contains(status) else {
      throw CorrespondenceClientError.serverRejected(
        response.object["message"] as? String ?? status ?? "unknown response")
    }
    let accessCredential = try decodeCredential(response.object["accessCredential"])
    var profile = CorrespondenceProfile(
      version: 1,
      profile: invite.profile,
      baseURL: invite.baseURL,
      principalID: invite.principalID,
      entityRef: invite.entityRef,
      deviceID: payload.deviceID,
      displayName: invite.displayName,
      identityUUID: material.descriptor.identityUUID,
      publicKeyBase64URL: material.descriptor.publicKeyBase64URL,
      enrolledAt: CorrespondenceCanonicalCoding.dateString(issued),
      accessRequestID: response.object["accessRequestID"] as? String,
      accessCredential: accessCredential
    )
    if let accessCredential {
      try validate(accessCredential: accessCredential, profile: profile, now: issued)
      profile.accessRequestID = accessCredential.payload.approvalRequestID
    }
    try persist(profile: profile, at: paths.profileFile)
    return (profile, response.object)
  }

  static func refreshAccess(
    paths: CorrespondencePaths,
    transport: any CorrespondenceHTTPTransporting = URLSessionCorrespondenceTransport(),
    now: @escaping @Sendable () -> Date = Date.init
  ) async throws -> (CorrespondenceProfile, CorrespondenceJSONObject) {
    guard FileManager.default.fileExists(atPath: paths.profileFile.path) else {
      throw CorrespondenceClientError.profileMissing(paths.profileFile.path)
    }
    var profile = try JSONDecoder().decode(
      CorrespondenceProfile.self, from: Data(contentsOf: paths.profileFile))
    guard let accessRequestID = profile.accessRequestID else {
      throw CorrespondenceClientError.invalidAccessCredential(
        "the local profile has no approval request identifier")
    }
    let material = try await AgentIdentityStore(fileURL: paths.identityFile).loadOrCreate(
      instanceName: "correspondence-\(profile.profile)")
    guard profile.identityUUID == material.descriptor.identityUUID,
      profile.publicKeyBase64URL == material.descriptor.publicKeyBase64URL
    else {
      throw CorrespondenceClientError.profileIdentityMismatch
    }
    let issued = now()
    let payload = CorrespondenceAccessStatusPayload(
      version: CorrespondenceContract.schemaVersion,
      requestID: "access-status-\(UUID().uuidString.lowercased())",
      accessRequestID: accessRequestID,
      principalID: profile.principalID,
      deviceID: profile.deviceID,
      identityUUID: profile.identityUUID,
      issuedAt: CorrespondenceCanonicalCoding.dateString(issued),
      expiresAt: CorrespondenceCanonicalCoding.dateString(issued.addingTimeInterval(120)),
      nonce: UUID().uuidString.lowercased()
    )
    let request = CorrespondenceAccessStatusRequest(
      payload: payload,
      proof: try CorrespondenceCanonicalCoding.signed(payload, with: material)
    )
    let response = try await transport.post(
      url: try endpoint(baseURL: profile.baseURL, path: "access/status"),
      body: try CorrespondenceCanonicalCoding.data(for: request)
    )
    guard response.statusCode == 200,
      let status = response.object["status"] as? String,
      ["pending_approval", "approved", "rejected", "expired"].contains(status)
    else {
      throw CorrespondenceClientError.serverRejected(
        response.object["message"] as? String
          ?? response.object["status"] as? String ?? "unknown response")
    }
    if status == "approved" {
      guard let credential = try decodeCredential(response.object["accessCredential"]) else {
        throw CorrespondenceClientError.invalidAccessCredential(
          "an approved response did not contain the signed proof")
      }
      try validate(accessCredential: credential, profile: profile, now: issued)
      profile.accessCredential = credential
    } else {
      profile.accessCredential = nil
    }
    try persist(profile: profile, at: paths.profileFile)
    return (profile, response.object)
  }

  func perform(operation: String, arguments: CorrespondenceArguments) async throws
    -> CorrespondenceHTTPResponse
  {
    guard let accessCredential = profile.accessCredential else {
      throw CorrespondenceClientError.accessPending(profile.accessRequestID ?? "unknown")
    }
    let issued = now()
    try Self.validate(accessCredential: accessCredential, profile: profile, now: issued)
    let payload = CorrespondenceRequestPayload(
      version: CorrespondenceContract.schemaVersion,
      requestID: "request-\(UUID().uuidString.lowercased())",
      operation: operation,
      principalID: profile.principalID,
      deviceID: profile.deviceID,
      identityUUID: profile.identityUUID,
      issuedAt: CorrespondenceCanonicalCoding.dateString(issued),
      expiresAt: CorrespondenceCanonicalCoding.dateString(issued.addingTimeInterval(120)),
      nonce: UUID().uuidString.lowercased(),
      arguments: arguments
    )
    let signed = CorrespondenceSignedRequest(
      payload: payload,
      accessCredential: accessCredential,
      proof: try CorrespondenceCanonicalCoding.signed(payload, with: material)
    )
    return try await transport.post(
      url: try Self.endpoint(baseURL: profile.baseURL, path: "messages"),
      body: try CorrespondenceCanonicalCoding.data(for: signed)
    )
  }

  private static func validateBaseURL(_ raw: String) throws {
    guard let url = URL(string: raw), url.scheme?.lowercased() == "https", url.host != nil else {
      throw CorrespondenceClientError.invalidBaseURL
    }
  }

  private static func endpoint(baseURL: String, path: String) throws -> URL {
    try validateBaseURL(baseURL)
    guard let base = URL(string: baseURL),
      let url = URL(
        string: "haven/api/assistant-correspondence/v1/\(path)",
        relativeTo: base.appendingPathComponent("/"))?.absoluteURL
    else {
      throw CorrespondenceClientError.invalidBaseURL
    }
    return url
  }

  private static func decodeCredential(_ value: Any?) throws -> CorrespondenceAccessCredential? {
    guard let value, !(value is NSNull) else { return nil }
    guard JSONSerialization.isValidJSONObject(value) else {
      throw CorrespondenceClientError.invalidAccessCredential("the proof is not valid JSON")
    }
    do {
      let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
      return try JSONDecoder().decode(CorrespondenceAccessCredential.self, from: data)
    } catch {
      throw CorrespondenceClientError.invalidAccessCredential("the proof contract did not decode")
    }
  }

  private static func validate(
    accessCredential: CorrespondenceAccessCredential,
    profile: CorrespondenceProfile,
    now: Date
  ) throws {
    let payload = accessCredential.payload
    guard payload.version == CorrespondenceContract.schemaVersion,
      payload.credentialType == CorrespondenceContract.accessCredentialType,
      payload.subjectEntityRef == profile.entityRef,
      payload.principalID == profile.principalID,
      payload.deviceID == profile.deviceID,
      payload.identityUUID == profile.identityUUID,
      payload.publicKeyBase64URL == profile.publicKeyBase64URL,
      Set(payload.resourceRefs) == Set([CorrespondenceContract.endpoint]),
      Set(payload.allowedOperations) == Set(CorrespondenceContract.operations),
      payload.approvalRequestID == profile.accessRequestID,
      payload.approvalReceiptID.isEmpty == false,
      let expiresAt = CorrespondenceCanonicalCoding.date(payload.expiresAt),
      expiresAt > now,
      accessCredential.proof.algorithm.lowercased() == "ed25519",
      let issuerKeyData = CorrespondenceCanonicalCoding.data(
        base64URL: accessCredential.proof.issuerPublicKeyBase64URL),
      let signature = CorrespondenceCanonicalCoding.data(
        base64URL: accessCredential.proof.signatureBase64URL),
      let issuerKey = try? Curve25519.Signing.PublicKey(rawRepresentation: issuerKeyData),
      let signingData = try? CorrespondenceCanonicalCoding.data(for: payload),
      issuerKey.isValidSignature(signature, for: signingData)
    else {
      throw CorrespondenceClientError.invalidAccessCredential(
        "signature, expiry, Entity, device, principal, resource, operation, or approval binding failed")
    }
  }

  static func persist(profile: CorrespondenceProfile, at url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700])
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(profile).write(to: url, options: [.atomic])
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
  }
}
