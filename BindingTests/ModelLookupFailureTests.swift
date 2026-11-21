import XCTest
import CellBase
@testable import Binding

private struct ModelLookupFailureTransport: BindingChatTransport {
    let throwsError: Bool
    var gatewayEnvelope = false
    var serverStatus: Int? = nil
    func request(_ path: String, payload: Object?) async throws -> Object {
        if let serverStatus { throw BindingNativeChatConnectionError.serverResponse(serverStatus) }
        if throwsError { throw BindingNativeChatConnectionError.personLinkRequired }
        if gatewayEnvelope {
            if path == "assistant/provider/recommend" { return ["ok": .bool(true)] }
            return ["ok": .bool(true), "success": .bool(false), "answer": .string("Synthetic gateway unavailable"),
                    "assistantState": .object(["providerUsageStatus": .object(["status": .string("provider_state_unavailable")])])]
        }
        return ["ok": .bool(false), "message": .string("Synthetic model access denied")]
    }
}

@MainActor
final class ModelLookupFailureTests: XCTestCase {
    func testPersonSearchFailureKeepsHTTPReasonAndEmptyExplanation() async throws {
        let vault = EphemeralIdentityVault()
        var owner = Identity(UUID().uuidString, displayName: "Synthetic person search", identityVault: vault)
        await vault.addIdentity(identity: &owner, for: "private")
        let cell = await BindingPersonalChatHubCell(owner: owner)
        cell.chatTransport = ModelLookupFailureTransport(throwsError: false, serverStatus: 401)
        _ = try await cell.set(keypath: "assistant.setCandidateQuery", value: .string("Synthetic recipient"), requester: owner)
        let status = try await cell.get(keypath: "state.status", requester: owner)
        XCTAssertEqual(status, .string(BindingNativeChatConnectionError.serverResponse(401).message))
        let explanation = try await cell.get(keypath: "state.assistant.latestSuggestion.explanation", requester: owner)
        XCTAssertEqual(explanation, .string(""))
    }
    func testDiscoveryPreservesGatewayFailureAnswerAndUsageState() async throws {
        let vault = EphemeralIdentityVault()
        var owner = Identity(UUID().uuidString, displayName: "Synthetic gateway test", identityVault: vault)
        await vault.addIdentity(identity: &owner, for: "private")
        let cell = await BindingPersonalChatHubCell(owner: owner)
        cell.chatTransport = ModelLookupFailureTransport(throwsError: false, gatewayEnvelope: true)
        _ = try await cell.set(keypath: "assistant.provider.recommend", value: .object([:]), requester: owner)
        let status = try await cell.get(keypath: "state.status", requester: owner)
        XCTAssertEqual(status, .string("Synthetic gateway unavailable"))
        let usage = try await cell.get(keypath: "state.assistant.providerUsageStatus.status", requester: owner)
        XCTAssertEqual(usage, .string("provider_state_unavailable"))
    }
    func testTransportFailureIsVisibleInModelPanelState() async throws {
        try await verify(throwsError: true, expected: BindingNativeChatConnectionError.personLinkRequired.message)
    }
    func testProviderRejectionIsVisibleInModelPanelState() async throws {
        try await verify(throwsError: false, expected: "Synthetic model access denied")
    }
    private func verify(throwsError: Bool, expected: String) async throws {
        let vault = EphemeralIdentityVault()
        var owner = Identity(UUID().uuidString, displayName: "Synthetic model test", identityVault: vault)
        await vault.addIdentity(identity: &owner, for: "private")
        let cell = await BindingPersonalChatHubCell(owner: owner)
        cell.chatTransport = ModelLookupFailureTransport(throwsError: throwsError)
        let response = try await cell.set(keypath: "assistant.provider.status", value: .object([:]), requester: owner)
        guard case let .object(result)? = response else { return XCTFail("Missing failure response") }
        XCTAssertEqual(result["ok"], .bool(false))
        let status = try await cell.get(keypath: "state.status", requester: owner)
        XCTAssertEqual(status, .string(expected))
    }
}
