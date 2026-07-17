import Foundation
import HavenAgentRuntime

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
    guard response.statusCode == 200, status == "enrolled" || status == "already_enrolled" else {
      throw CorrespondenceClientError.serverRejected(
        response.object["message"] as? String ?? status ?? "unknown response")
    }
    let profile = CorrespondenceProfile(
      version: 1,
      profile: invite.profile,
      baseURL: invite.baseURL,
      principalID: invite.principalID,
      deviceID: payload.deviceID,
      displayName: invite.displayName,
      identityUUID: material.descriptor.identityUUID,
      publicKeyBase64URL: material.descriptor.publicKeyBase64URL,
      enrolledAt: CorrespondenceCanonicalCoding.dateString(issued)
    )
    try persist(profile: profile, at: paths.profileFile)
    return (profile, response.object)
  }

  func perform(operation: String, arguments: CorrespondenceArguments) async throws
    -> CorrespondenceHTTPResponse
  {
    let issued = now()
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

  private static func persist(profile: CorrespondenceProfile, at url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700])
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(profile).write(to: url, options: [.atomic])
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
  }
}
