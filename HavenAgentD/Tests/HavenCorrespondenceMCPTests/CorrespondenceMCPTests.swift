import Foundation
import Testing

@testable import HavenCorrespondenceMCP

#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif

@Suite("HAVEN Assistant Correspondence MCP")
struct CorrespondenceMCPTests {
  @Test
  func enrollmentPersistsPublicProfileAndKeepsInviteSecretOut() async throws {
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let paths = CorrespondencePaths(root: root)
    let transport = RecordingTransport(
      response: CorrespondenceHTTPResponse(
        statusCode: 200,
        object: ["status": "pending_approval", "accessRequestID": "access-request-victoria"]))
    let invite = CorrespondenceEnrollmentInviteFile(
      version: 1,
      baseURL: "https://staging.haven.digipomps.org/",
      profile: "victoria",
      principalID: "victoria-lille-robot",
      entityRef: "entity:victoria",
      deviceID: "victoria-mac-1",
      displayName: "Lille Robot",
      inviteID: "invite-victoria",
      inviteSecret: "one-time-secret-that-is-not-persisted"
    )

    let (profile, _) = try await CorrespondenceClient.enroll(
      invite: invite, paths: paths, transport: transport)
    #expect(profile.principalID == "victoria-lille-robot")
    #expect(profile.accessCredential == nil)
    #expect(profile.accessRequestID == "access-request-victoria")
    #expect(FileManager.default.fileExists(atPath: paths.profileFile.path))
    let persisted = try String(contentsOf: paths.profileFile, encoding: .utf8)
    #expect(persisted.contains(invite.inviteSecret) == false)
    #expect(
      await transport.lastURL()?.absoluteString
        == "https://staging.haven.digipomps.org/haven/api/assistant-correspondence/v1/enroll")

    let requestData = try #require(await transport.lastBody())
    let request = try JSONDecoder().decode(CorrespondenceEnrollmentRequest.self, from: requestData)
    #expect(request.payload.inviteSecret == invite.inviteSecret)
    #expect(
      verify(
        request.proof, payload: request.payload,
        publicKeyBase64URL: request.payload.publicKeyBase64URL))
  }

  @Test
  func mcpSurfaceContainsOnlyFourCorrespondenceToolsAndSignsSends() async throws {
    let root = temporaryRoot()
    defer { try? FileManager.default.removeItem(at: root) }
    let paths = CorrespondencePaths(root: root)
    let transport = RecordingTransport(
      response: CorrespondenceHTTPResponse(
        statusCode: 200, object: ["fixture": "approved-enrollment"]))
    let invite = CorrespondenceEnrollmentInviteFile(
      version: 1,
      baseURL: "https://staging.haven.digipomps.org/",
      profile: "kjetil",
      principalID: "kjetil-codex",
      entityRef: "entity:kjetil",
      deviceID: "kjetil-mac-1",
      displayName: "Codex",
      inviteID: "invite-kjetil",
      inviteSecret: "one-time-kjetil-secret"
    )
    _ = try await CorrespondenceClient.enroll(invite: invite, paths: paths, transport: transport)
    await transport.setResponse(
      CorrespondenceHTTPResponse(statusCode: 200, object: ["status": "sent", "created": true]))
    let client = try await CorrespondenceClient.load(paths: paths, transport: transport)
    let service = CorrespondenceMCPService(client: client)

    let names = service.listTools().compactMap { $0["name"] as? String }
    #expect(
      names == [
        "correspondence.list_inbox",
        "correspondence.read_message",
        "correspondence.send_message",
        "correspondence.ack_message",
      ])
    #expect(
      names.contains(where: {
        $0.contains("execute") || $0.contains("xcode") || $0.contains("mail")
      }) == false)

    let output = await service.callTool(
      name: "correspondence.send_message",
      arguments: [
        "recipientID": "victoria-lille-robot",
        "subject": "HAVEN",
        "content": "Dette er en signert melding.",
        "clientMessageID": "test-message-1",
      ])
    #expect(output.isError == false)
    let data = try #require(await transport.lastBody())
    #expect(
      await transport.lastURL()?.absoluteString
        == "https://staging.haven.digipomps.org/haven/api/assistant-correspondence/v1/messages")
    let request = try JSONDecoder().decode(CorrespondenceSignedRequest.self, from: data)
    #expect(request.payload.operation == "message.send")
    #expect(request.payload.arguments.recipientID == "victoria-lille-robot")
    #expect(request.accessCredential.payload.subjectEntityRef == "entity:kjetil")
    #expect(request.accessCredential.payload.approvalReceiptID.isEmpty == false)
    let clientProfile = await client.profile
    #expect(
      verify(
        request.proof, payload: request.payload,
        publicKeyBase64URL: clientProfile.publicKeyBase64URL))
  }

  private func temporaryRoot() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(
      "HavenCorrespondenceMCPTests-\(UUID().uuidString)", isDirectory: true)
  }

  private func verify<T: Encodable>(
    _ proof: CorrespondenceProof, payload: T, publicKeyBase64URL: String
  ) -> Bool {
    guard let publicKeyData = CorrespondenceCanonicalCoding.data(base64URL: publicKeyBase64URL),
      let signature = CorrespondenceCanonicalCoding.data(base64URL: proof.signatureBase64URL),
      let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData),
      let data = try? CorrespondenceCanonicalCoding.data(for: payload)
    else {
      return false
    }
    return publicKey.isValidSignature(signature, for: data)
  }
}

private actor RecordingTransport: CorrespondenceHTTPTransporting {
  private var response: CorrespondenceHTTPResponse
  private var bodies: [Data] = []
  private var urls: [URL] = []

  init(response: CorrespondenceHTTPResponse) {
    self.response = response
  }

  func post(url: URL, body: Data) async throws -> CorrespondenceHTTPResponse {
    urls.append(url)
    bodies.append(body)
    if response.object["fixture"] as? String == "approved-enrollment",
      url.path.hasSuffix("/enroll")
    {
      let request = try JSONDecoder().decode(CorrespondenceEnrollmentRequest.self, from: body)
      let approvalRequestID = "access-request-\(request.payload.principalID)"
      let issuer = Curve25519.Signing.PrivateKey()
      let credentialPayload = CorrespondenceAccessCredentialPayload(
        version: 1,
        credentialID: "credential-\(request.payload.principalID)",
        credentialType: CorrespondenceContract.accessCredentialType,
        issuerIdentityUUID: "staging-scaffold-identity",
        subjectEntityRef: request.payload.entityRef,
        principalID: request.payload.principalID,
        deviceID: request.payload.deviceID,
        identityUUID: request.payload.identityUUID,
        publicKeyBase64URL: request.payload.publicKeyBase64URL,
        resourceRefs: [CorrespondenceContract.endpoint],
        allowedPeerIDs: ["victoria-lille-robot"],
        allowedOperations: CorrespondenceContract.operations,
        allowedPurposeRefs: ["purpose://contact.communication"],
        issuedAt: CorrespondenceCanonicalCoding.dateString(Date()),
        expiresAt: CorrespondenceCanonicalCoding.dateString(Date().addingTimeInterval(3600)),
        approvalRequestID: approvalRequestID,
        approvalReceiptID: "approval-receipt-test",
        revocationRef: "cell:///AssistantCorrespondence/grants/test"
      )
      let signature = try issuer.signature(
        for: CorrespondenceCanonicalCoding.data(for: credentialPayload))
      let credential = CorrespondenceAccessCredential(
        payload: credentialPayload,
        proof: CorrespondenceAccessCredentialProof(
          algorithm: "Ed25519",
          issuerPublicKeyBase64URL: CorrespondenceCanonicalCoding.base64URL(
            issuer.publicKey.rawRepresentation),
          signatureBase64URL: CorrespondenceCanonicalCoding.base64URL(signature)))
      let credentialData = try CorrespondenceCanonicalCoding.data(for: credential)
      let credentialObject = try JSONSerialization.jsonObject(with: credentialData)
      return CorrespondenceHTTPResponse(
        statusCode: 200,
        object: [
          "status": "already_enrolled",
          "accessRequestID": approvalRequestID,
          "accessCredential": credentialObject,
        ])
    }
    return response
  }

  func setResponse(_ response: CorrespondenceHTTPResponse) {
    self.response = response
  }

  func lastBody() -> Data? {
    bodies.last
  }

  func lastURL() -> URL? {
    urls.last
  }
}
