import Foundation
import CellBase

nonisolated protocol BindingChatTransport: Sendable {
    func canRefreshSharedChat() async -> Bool
    func request(_ path: String, payload: Object?) async throws -> Object
}

extension BindingChatTransport {
    // In-memory transports have no persisted person-link prerequisite.
    nonisolated func canRefreshSharedChat() async -> Bool { true }
}

/// One authenticated person-link context per call. No cookies, bearer storage,
/// redirects, retries of uncertain sends, or anonymous persona fallback.
actor BindingNativeChatTransport: BindingChatTransport {
    private typealias C = BindingPersonEntityReadRouteContract
    private let requesterUUID: String
    init(requesterUUID: String) { self.requesterUUID = requesterUUID }

    // Runs on the transport actor, never on the state reader's executor. This
    // is only a readiness hint; request still performs every authorization check.
    func canRefreshSharedChat() async -> Bool {
        IdentityLinkCompletionStore.entries().contains {
            $0.record.status == .active && $0.record.linkedIdentity.uuid == requesterUUID
                && $0.personEvidenceReference != nil && IdentityLinkTrust.isTrustedOrigin($0.origin)
        }
    }

    func request(_ path: String, payload: Object?) async throws -> Object {
        let entries = IdentityLinkCompletionStore.entries().filter {
            $0.record.status == .active && $0.record.linkedIdentity.uuid == requesterUUID
                && $0.personEvidenceReference != nil && IdentityLinkTrust.isTrustedOrigin($0.origin)
        }
        // Ambiguous accounts/origins require an explicit person selection; never
        // silently choose the last receipt belonging to a different person.
        // A renewed receipt for the same person/origin supersedes its predecessor.
        let contexts = Set(entries.map { $0.origin + "|" + $0.record.issuerIdentityUUID })
        guard contexts.count == 1, let entry = entries.last,
              entry.record.approvedDomains.contains(C.domain), IdentityLinkScope.grantsSameEntity(entry.record.approvedScopes),
              let reference = entry.personEvidenceReference,
              let identity = await BindingStartupIdentityVault.shared.identity(forUUID: requesterUUID),
              identity.publicSecureKey?.compressedKey == entry.record.linkedIdentity.publicKey,
              let vault = identity.identityVault, await vault.identityExistInVault(identity),
              identity.homeVaultReference == (await vault.identityVaultReference()) else { throw C.Failure.denied }
        let prefix = "/personal-copilot-v1/chat/api/"
        let allowed = ["state", "identity", "invite", "accept", "decline", "send", "block", "unblock",
                       "collaboration/prepare-external", "collaboration/identity-binding/approve",
                       "collaboration/identity-binding/reject", "collaboration/grant/revoke"]
        guard allowed.contains(path), let origin = URL(string: entry.origin), origin.scheme == "https",
              origin.path.isEmpty, origin.query == nil, origin.fragment == nil, origin.user == nil else { throw C.Failure.denied }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false; configuration.httpCookieStorage = nil; configuration.urlCache = nil
        let session = URLSession(configuration: configuration, delegate: NativeChatNoRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        guard let challengeURL = URL(string: prefix + "native/challenge", relativeTo: origin)?.absoluteURL,
              let actionURL = URL(string: prefix + path, relativeTo: origin)?.absoluteURL else { throw C.Failure.malformed }
        let challenge = try await Self.perform(URLRequest(url: challengeURL, timeoutInterval: 20), session: session)
        guard let nonce = BindingChatValue.string(challenge["nonce"]), nonce.utf8.count <= 128 else { throw C.Failure.malformed }
        let bytes = try payload.map { try C.encode($0) } ?? Data()
        let method = payload == nil ? "GET" : "POST"
        let resource = BindingNativeChatWire.resource(method: method, path: prefix + path, body: bytes, nonce: nonce, evidenceReference: reference, linkID: entry.record.linkID)
        guard let random = await vault.randomBytes64() else { throw C.Failure.unavailable }
        let signing = try IdentitySigningChallenge.signingData(for: identity, trustedIdentity: identity,
            domain: C.domain, resource: resource, action: "personal-chat.request.v1", audience: entry.origin, nonce: random)
        guard let signature = try await identity.sign(data: signing) else { throw C.Failure.denied }
        let proof = C.Proof(evidenceReference: reference, linkID: entry.record.linkID, challenge: signing, signature: signature)
        var request = URLRequest(url: actionURL, timeoutInterval: 20)
        request.httpMethod = method; request.httpBody = payload == nil ? nil : bytes
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(try C.encode(BindingNativeChatEnvelope(nonce: nonce, proof: proof)).base64EncodedString(), forHTTPHeaderField: "X-Haven-Chat-Proof")
        return try await Self.perform(request, session: session)
    }

    private static func perform(_ request: URLRequest, session: URLSession) async throws -> Object {
        let (stream, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.url == request.url,
              http.statusCode == 200, http.mimeType == "application/json" else { throw C.Failure.unavailable }
        var bytes = Data()
        for try await byte in stream {
            guard bytes.count < 2 * 1024 * 1024 else { throw C.Failure.capacity }
            bytes.append(byte)
        }
        return try JSONDecoder().decode(Object.self, from: bytes)
    }
}

private nonisolated struct BindingNativeChatEnvelope: Encodable, Sendable {
    let nonce: String
    let proof: BindingPersonEntityReadRouteContract.Proof
}

private nonisolated final class NativeChatNoRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                               newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

/// The registered app runtime always uses shared transport, including decoded
/// cells. The base cell remains available for isolated local helper contracts.
final class BindingConnectedPersonalChatHubCell: BindingPersonalChatHubCell {
    private(set) var readRefreshTask: Task<Void, Never>?
    private var historyReadTask: Task<Void, Never>?

    override func prepareForRead(key: String, requester: Identity) async {
        // No await of history persistence, receipt discovery or transport here.
        // Coalesce the many skeleton keypath reads into one in-flight refresh.
        if Self.shouldHydrateHistoryPolicy(for: key), historyReadTask == nil {
            historyReadTask = Task { [weak self] in
                guard let self else { return }
                defer { self.historyReadTask = nil }
                await self.hydrateHistoryPolicyIfNeeded(requester: requester)
            }
        }
        guard Self.shouldRefreshSharedChat(for: key), readRefreshTask == nil,
              let transport = chatTransport else { return }
        let refreshID = sharedRefreshID
        readRefreshTask = Task { [weak self] in
            let ready = await transport.canRefreshSharedChat()
            guard let self else { return }
            defer { self.readRefreshTask = nil }
            // An explicit refresh/push while discovery was pending takes priority.
            guard self.sharedRefreshID == refreshID else { return }
            guard ready else {
                self.discardLocalChatProjection()
                return
            }
            _ = await self.refreshSharedChat()
        }
    }

    required init(owner: Identity) async {
        await super.init(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override func installRuntimeBindings(owner: Identity) async {
        if chatTransport == nil {
            chatTransport = BindingNativeChatTransport(requesterUUID: owner.uuid)
            discardLocalChatProjection()
        }
        await super.installRuntimeBindings(owner: owner)
    }
}

nonisolated enum BindingNativeChatWire {
    static func resource(method: String, path: String, body: Data, nonce: String, evidenceReference: String, linkID: String) -> String {
        "personal-chat:" + method + ":" + path + ":" + BindingPersonEntityReadRouteContract.digest(body) + ":" + nonce + ":" + evidenceReference + ":" + linkID
    }
}

/// The same explicit external identity decision controls appear in both hosts.
nonisolated enum BindingSharedChatControls {
    static func messages(reference: String) -> SkeletonElement {
        var messages = SkeletonList(keypath: "\(reference).state.messages")
        messages.flowElementSkeleton = SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "authorDisplayName")), .Text(SkeletonText(keypath: "body"))
        ])
        return .List(messages)
    }
    static func threads(reference: String) -> SkeletonElement {
        var threads = SkeletonList(keypath: "\(reference).state.threads")
        threads.flowElementSkeleton = SkeletonVStack(elements: [.Text(SkeletonText(keypath: "title"))])
        threads.selectionMode = .single
        threads.selectionStateKeypath = "\(reference).state.currentThread.id"
        threads.selectionValueKeypath = "id"
        threads.selectionActionKeypath = "\(reference).ui.setCurrentThread"
        threads.selectionPayloadMode = .itemID
        return .List(threads)
    }
    static func external(reference: String) -> SkeletonElement {
        var invites = SkeletonList(keypath: "\(reference).state.collaborationInvites")
        invites.flowElementSkeleton = SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "title")), .Text(SkeletonText(keypath: "status"))
        ])
        invites.selectionMode = .single
        invites.selectionStateKeypath = "\(reference).state.collaboration.selectedID"
        invites.selectionValueKeypath = "id"
        invites.selectionActionKeypath = "\(reference).collaboration.select"
        invites.selectionPayloadMode = .itemID
        return .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(text: "Eksterne invitasjoner")), .List(invites),
            .Button(SkeletonButton(keypath: "\(reference).collaboration.approve", label: "Godkjenn identitet")),
            .Button(SkeletonButton(keypath: "\(reference).collaboration.reject", label: "Avslå identitet")),
            .Button(SkeletonButton(keypath: "\(reference).collaboration.revokeGrant", label: "Trekk tilbake tilgang"))
        ]))
    }
}
