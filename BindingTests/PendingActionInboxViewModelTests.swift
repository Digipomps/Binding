import Foundation
import Testing
@testable import Binding

@MainActor
struct PendingActionInboxViewModelTests {
    @Test
    func correspondenceInspectionRequiresCompleteMessagesOnlyIdentityBinding() throws {
        let inspection = try #require(CorrespondenceApprovalInspection(
            action: correspondenceAction(),
            now: Date(timeIntervalSince1970: 1_780_000_000)
        ))

        #expect(inspection.isComplete)
        #expect(inspection.validationIssues.isEmpty)
        #expect(inspection.accessRequestID == "access-request-vegar-1")
        #expect(inspection.entityRef == "entity:vegar")
        #expect(inspection.requesterDeviceID == "vegar-device-1")
        #expect(inspection.requesterIdentityUUID == "identity-vegar-1")
        #expect(inspection.publicKeyFingerprint == "sha256:\(String(repeating: "A", count: 43))")
        #expect(Set(inspection.allowedOperations) == CorrespondenceApprovalInspection.operations)
        #expect(inspection.executionAuthority == false)
    }

    @Test
    func correspondenceInspectionFailsClosedForMissingOrBroadenedAuthority() throws {
        var missingFingerprint = correspondenceAction()
        guard case var .object(inspection)? = missingFingerprint.payload["approvalInspection"] else {
            Issue.record("Expected approval inspection fixture")
            return
        }
        inspection["publicKeyFingerprint"] = nil
        missingFingerprint.payload["approvalInspection"] = .object(inspection)
        let missing = try #require(CorrespondenceApprovalInspection(
            action: missingFingerprint,
            now: Date(timeIntervalSince1970: 1_780_000_000)
        ))
        #expect(missing.isComplete == false)
        #expect(missing.validationIssues.contains("Nøkkelfingerprint mangler."))

        var broadened = correspondenceAction()
        guard case var .object(broadenedInspection)? = broadened.payload["approvalInspection"] else {
            Issue.record("Expected approval inspection fixture")
            return
        }
        broadenedInspection["allowedOperations"] = .array([
            .string("inbox.list"),
            .string("message.read"),
            .string("message.send"),
            .string("message.ack"),
            .string("execute")
        ])
        broadened.payload["approvalInspection"] = .object(broadenedInspection)
        let expanded = try #require(CorrespondenceApprovalInspection(
            action: broadened,
            now: Date(timeIntervalSince1970: 1_780_000_000)
        ))
        #expect(expanded.isComplete == false)
        #expect(expanded.validationIssues.contains(
            "Operasjonene er ikke nøyaktig de fire meldingsoperasjonene."
        ))
    }

    @Test
    func upsertPersistsPendingActionForRelaunch() throws {
        let suiteName = "PendingActionInboxViewModelTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let storageKey = "pending-actions"
        let action = PendingDeviceAction(
            id: "ticket-1",
            participantId: "binding-participant",
            deviceId: "iphone-1",
            ticketId: "ticket-1",
            requiredActionKey: "haven.agent.followup.approval",
            payload: [
                "title": .string("Agent venter"),
                "message": .string("Godkjenn neste steg.")
            ],
            receivedAt: Date(timeIntervalSince1970: 1_780_000_000)
        )

        let model = PendingActionInboxViewModel(defaults: defaults, storageKey: storageKey)
        model.upsert(action)

        let restored = PendingActionInboxViewModel(defaults: defaults, storageKey: storageKey)

        #expect(restored.actions.count == 1)
        #expect(restored.actions.first?.ticketId == "ticket-1")
        #expect(restored.actions.first?.requiredActionKey == "haven.agent.followup.approval")
        #expect(restored.actions.first?.payload["title"] == .string("Agent venter"))
    }

    @Test
    func removeClearsPersistedActionAfterSuccessfulSubmit() throws {
        let suiteName = "PendingActionInboxViewModelTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let storageKey = "pending-actions"
        let model = PendingActionInboxViewModel(defaults: defaults, storageKey: storageKey)
        model.upsert(
            PendingDeviceAction(
                id: "ticket-2",
                participantId: "binding-participant",
                deviceId: "iphone-1",
                ticketId: "ticket-2",
                requiredActionKey: "haven.agent.followup.prompt",
                payload: ["message": .string("Skriv svar.")],
                receivedAt: Date(timeIntervalSince1970: 1_780_000_001)
            )
        )

        model.remove(ticketId: "ticket-2")
        let restored = PendingActionInboxViewModel(defaults: defaults, storageKey: storageKey)

        #expect(restored.actions.isEmpty)
    }

    @Test
    func approvalUITestFixtureSurvivesRuntimeReload() throws {
        let suiteName = "PendingActionInboxViewModelTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let model = PendingActionInboxViewModel(
            defaults: defaults,
            storageKey: "pending-actions",
            launchArguments: [
                PendingActionInboxViewModel.correspondenceApprovalUITestLaunchArgument
            ]
        )

        model.reloadPersistedActions()

        #expect(model.actions.count == 1)
        #expect(model.actions.first?.ticketId == "notification-ticket-vegar-ui")
        #expect(defaults.data(forKey: "pending-actions") == nil)
    }

    private func correspondenceAction() -> PendingDeviceAction {
        PendingDeviceAction(
            id: "notification-ticket-vegar-1",
            participantId: "entity-pairwise:kjetil",
            deviceId: "kjetil-iphone-1",
            ticketId: "notification-ticket-vegar-1",
            requiredActionKey: CorrespondenceApprovalInspection.actionKey,
            payload: [
                "schema": .string(
                    "cellscaffold.device-ingress.callback-payload.correspondence-approval.v1"),
                "title": .string("Utsted adgangsbevis til HAVEN-agent hos Vegar"),
                "message": .string("entity:vegar ber om avgrenset meldingsadgang."),
                "approvalInspection": .object([
                    "schema": .string(CorrespondenceApprovalInspection.schema),
                    "accessRequestID": .string("access-request-vegar-1"),
                    "displayName": .string("HAVEN-agent hos Vegar"),
                    "entityRef": .string("entity:vegar"),
                    "principalID": .string("vegar-local-agent"),
                    "requesterDeviceID": .string("vegar-device-1"),
                    "requesterIdentityUUID": .string("identity-vegar-1"),
                    "publicKeyFingerprint": .string(
                        "sha256:\(String(repeating: "A", count: 43))"),
                    "resourceRefs": .array([
                        .string(CorrespondenceApprovalInspection.endpoint)
                    ]),
                    "allowedPeerIDs": .array([.string("kjetil-vegar-codex")]),
                    "allowedOperations": .array(
                        CorrespondenceApprovalInspection.operations.sorted().map(JSONValue.string)
                    ),
                    "allowedPurposeRefs": .array(
                        CorrespondenceApprovalInspection.purposeRefs.sorted().map(JSONValue.string)
                    ),
                    "requestExpiresAt": .string("2026-08-22T23:42:22.563Z"),
                    "grantExpiresAt": .string("2026-09-14T23:42:22.564Z"),
                    "executionAuthority": .bool(false)
                ])
            ],
            receivedAt: Date(timeIntervalSince1970: 1_780_000_000)
        )
    }
}
