// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Testing
import CellBase
@testable import Binding

private actor RecordingRegistrationBroker: Meddle {
    private var recordedKeypath: String?
    private var recordedValue: ValueType?
    private var recordedRequesterUUID: String?

    func get(keypath: String, requester: Identity) async throws -> ValueType {
        .null
    }

    func set(keypath: String, value: ValueType, requester: Identity) async throws -> ValueType? {
        recordedKeypath = keypath
        recordedValue = value
        recordedRequesterUUID = requester.uuid
        return .object([
            "ok": .bool(true),
            "status": .string("registration_observed"),
            "grantsAuthority": .bool(false)
        ])
    }

    func snapshot() -> (String?, ValueType?, String?) {
        (recordedKeypath, recordedValue, recordedRequesterUUID)
    }
}

private actor RecordingStatusRequest {
    private var request: URLRequest?

    func record(_ request: URLRequest) {
        self.request = request
    }

    func snapshot() -> URLRequest? {
        request
    }
}

@Suite struct HavenAgentDRegistrationAdapterTests {
    @Test func reportsSanitizedStatusObservationThroughRequesterIdentity() async throws {
        let statusJSON = try makeStatusJSON(
            observation: [
                "schema": "haven.agentd-registration-observation.v1",
                "status": "registered",
                "evidenceKind": "haven-agentd.status-json",
                "availableActionIDs": [
                    "mac.finder.close-all-windows",
                    "unknown.remote.action"
                ],
                "bridgeEndpoint": "ws://127.0.0.1:43110/bridgehead",
                "observedAt": "2026-07-13T09:00:00Z",
                "evidenceAuthority": "owner-reported-runtime-observation-not-a-grant",
                "containsAccessToken": false
            ],
            topLevelExtras: [
                "localControlBridge": ["accessToken": "must-never-be-forwarded"]
            ]
        )
        let broker = RecordingRegistrationBroker()
        let requester = Identity(displayName: "Binding owner", identityVault: nil)

        let response = try await BindingHavenAgentDRegistrationAdapter.report(
            statusJSON: statusJSON,
            to: broker,
            requester: requester
        )

        let responseObject = try #require(object(response))
        #expect(bool(responseObject["grantsAuthority"]) == false)
        let recorded = await broker.snapshot()
        #expect(recorded.0 == "registration.report")
        #expect(recorded.2 == requester.uuid)
        let payload = try #require(object(recorded.1))
        #expect(string(payload["status"]) == "registered")
        #expect(string(payload["evidenceKind"]) == "haven-agentd.status-json")
        #expect(strings(payload["availableActionIDs"]) == ["mac.finder.close-all-windows"])
        #expect(string(payload["bridgeEndpoint"]) == "ws://127.0.0.1:43110/bridgehead")
        #expect(bool(payload["containsAccessToken"]) == false)
        #expect(payload["accessToken"] == nil)
        #expect(payload["token"] == nil)
        #expect(payload["identityUUID"] == nil)
    }

    @Test func rejectsSecretMaterialInsideObservation() throws {
        let statusJSON = try makeStatusJSON(observation: [
            "schema": "haven.agentd-registration-observation.v1",
            "status": "registered",
            "evidenceKind": "haven-agentd.status-json",
            "availableActionIDs": [],
            "bridgeEndpoint": "ws://127.0.0.1:43110/bridgehead",
            "observedAt": "2026-07-13T09:00:00Z",
            "accessToken": "secret"
        ])

        #expect(throws: BindingHavenAgentDRegistrationAdapterError.secretMaterialPresent) {
            _ = try BindingHavenAgentDRegistrationAdapter.observation(from: statusJSON)
        }
    }

    @Test func rejectsTokenizedOrNonLoopbackRegisteredBridge() throws {
        for endpoint in [
            "ws://127.0.0.1:43110/bridgehead?token=secret",
            "wss://example.com/bridgehead"
        ] {
            let statusJSON = try makeStatusJSON(observation: [
                "schema": "haven.agentd-registration-observation.v1",
                "status": "registered",
                "evidenceKind": "haven-agentd.status-json",
                "availableActionIDs": [],
                "bridgeEndpoint": endpoint,
                "observedAt": "2026-07-13T09:00:00Z",
                "containsAccessToken": false
            ])
            #expect(throws: BindingHavenAgentDRegistrationAdapterError.invalidBridgeEndpoint) {
                _ = try BindingHavenAgentDRegistrationAdapter.observation(from: statusJSON)
            }
        }
    }

    @Test func clientUsesAuthenticatedLoopbackStatusBoundary() async throws {
        let json = #"{"registrationObservation":{"schema":"haven.agentd-registration-observation.v1","status":"installed_not_running","evidenceKind":"haven-agentd.status-json","availableActionIDs":[],"observedAt":"2026-07-13T09:00:00Z","evidenceAuthority":"owner-reported-runtime-observation-not-a-grant","containsAccessToken":false}}"#
        let recorder = RecordingStatusRequest()
        let client = BindingHavenAgentDStatusClient(
            controlBridgeEndpoint: "ws://127.0.0.1:43110/bridgehead",
            accessToken: "local-private-token",
            dataLoader: { request in
                guard let url = request.url,
                      let response = HTTPURLResponse(
                          url: url,
                          statusCode: 200,
                          httpVersion: nil,
                          headerFields: nil
                      ) else {
                    throw URLError(.badURL)
                }
                await recorder.record(request)
                return (Data(json.utf8), response)
            }
        )
        let broker = RecordingRegistrationBroker()
        let requester = Identity(displayName: "Binding owner", identityVault: nil)

        _ = try await BindingHavenAgentDRegistrationAdapter.refreshAndReport(
            client: client,
            to: broker,
            requester: requester
        )
        let request = try #require(await recorder.snapshot())
        let requestURL = try #require(request.url)
        let components = try #require(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        let brokerSnapshot = await broker.snapshot()
        let payload = try #require(object(brokerSnapshot.1))

        #expect(request.httpMethod == "GET")
        #expect(request.url?.scheme == "http")
        #expect(request.url?.host == "127.0.0.1")
        #expect(request.url?.path == "/onboard/status.json")
        #expect(components.queryItems?.first(where: { $0.name == "token" })?.value == "local-private-token")
        #expect(brokerSnapshot.0 == "registration.report")
        #expect(brokerSnapshot.2 == requester.uuid)
        #expect(string(payload["status"]) == "installed_not_running")
        #expect(strings(payload["availableActionIDs"]).isEmpty)
        #expect(payload["bridgeEndpoint"] == .null)
        #expect(payload["token"] == nil)
    }

    @Test func clientRejectsUnauthenticatedOrNonLoopbackStatusBoundary() {
        for client in [
            BindingHavenAgentDStatusClient(
                controlBridgeEndpoint: "ws://127.0.0.1:43110/bridgehead",
                accessToken: ""
            ),
            BindingHavenAgentDStatusClient(
                controlBridgeEndpoint: "wss://example.com/bridgehead",
                accessToken: "token"
            )
        ] {
            #expect(throws: BindingHavenAgentDRegistrationAdapterError.invalidStatusEndpoint) {
                _ = try client.statusRequest()
            }
        }
    }

    @Test func acceptsObservationNestedInOnboardingStatusReport() throws {
        let observation: [String: Any] = [
            "schema": "haven.agentd-registration-observation.v1",
            "status": "installed_not_running",
            "evidenceKind": "haven-agentd.status-json",
            "availableActionIDs": [],
            "observedAt": "2026-07-13T09:00:00Z",
            "evidenceAuthority": "owner-reported-runtime-observation-not-a-grant",
            "containsAccessToken": false
        ]
        let data = try JSONSerialization.data(withJSONObject: [
            "recordedAt": "2026-07-13T09:00:00Z",
            "status": ["registrationObservation": observation]
        ])

        let decoded = try BindingHavenAgentDRegistrationAdapter.observation(from: data)

        #expect(decoded.status == "installed_not_running")
    }

    private func makeStatusJSON(
        observation: [String: Any],
        topLevelExtras: [String: Any] = [:]
    ) throws -> Data {
        var root = topLevelExtras
        root["registrationObservation"] = observation
        return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
    }

    private func object(_ value: ValueType?) -> Object? {
        guard case let .object(object)? = value else { return nil }
        return object
    }

    private func string(_ value: ValueType?) -> String? {
        guard case let .string(string)? = value else { return nil }
        return string
    }

    private func bool(_ value: ValueType?) -> Bool? {
        guard case let .bool(bool)? = value else { return nil }
        return bool
    }

    private func strings(_ value: ValueType?) -> [String] {
        guard case let .list(values)? = value else { return [] }
        return values.compactMap(string)
    }
}
