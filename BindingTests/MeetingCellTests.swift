import XCTest
@testable import CellBase

final class MeetingCellTests: XCTestCase {
    func testOwnerPlanReadbackAndOutsiderDenied() async throws {
        let vault = MeetingTestIdentityVault()
        let previous = CellBase.defaultIdentityVault
        CellBase.defaultIdentityVault = vault
        defer { CellBase.defaultIdentityVault = previous }
        let owner = await vault.identity(for:"meeting-owner",makeNewIfNotFound:true)!
        let guest = await vault.identity(for:"meeting-guest",makeNewIfNotFound:true)!
        let outsider = await vault.identity(for:"meeting-outsider",makeNewIfNotFound:true)!
        let cell = await MeetingSessionCell(owner:owner)
        func principal(_ identity: Identity) -> MeetingPrincipal { MeetingPrincipal(id:identity.uuid,signingKeyFingerprint:identity.signingPublicKeyFingerprint!) }
        let plan = MeetingPlan(purpose:"Test meeting",participants:[principal(owner),principal(guest)],recorder:principal(owner))
        let value = MeetingSurfaceConfiguration.encode(plan)
        let response = try await cell.set(keypath:"plan.propose",value:.object(["operationID": .string(UUID().uuidString), "plan":value]),requester:owner)
        let result = ExploreContract.object(from:response)
        XCTAssertEqual(ExploreContract.string(from:result?["status"]),"ok")
        let state = try await cell.get(keypath:"state",requester:owner)
        XCTAssertNotNil(ExploreContract.object(from:state)?["participants"])
        do {
            let denied = try await cell.get(keypath:"state",requester:outsider)
            XCTAssertNil(ExploreContract.object(from:denied)?["participants"])
        } catch { /* Resolver denial is also acceptable. */ }
        let bytes = try JSONEncoder().encode(cell)
        let restored = try JSONDecoder().decode(MeetingSessionCell.self,from:bytes)
        try await restored.ensureRuntimeReady()
        let recovered = try await restored.get(keypath:"state",requester:owner)
        XCTAssertTrue(ExploreContract.string(from:ExploreContract.object(from:recovered)?["notice"])?.contains("0 av 2") == true)
    }
    func testEachAuthorizedParticipantActsAsSelfAndNewcomerRequiresAllAgain() async throws {
        let vault = MeetingTestIdentityVault(); let previous = CellBase.defaultIdentityVault
        CellBase.defaultIdentityVault = vault
        defer { CellBase.defaultIdentityVault = previous }
        let owner = await vault.identity(for: "host", makeNewIfNotFound: true)!
        let guest = await vault.identity(for: "guest", makeNewIfNotFound: true)!
        let newcomer = await vault.identity(for: "newcomer", makeNewIfNotFound: true)!
        let cell = await MeetingSessionCell(owner: owner)
        func principal(_ identity: Identity) -> MeetingPrincipal {
            MeetingPrincipal(id: identity.uuid, signingKeyFingerprint: identity.signingPublicKeyFingerprint!)
        }
        let plan = MeetingPlan(purpose: "Meeting", participants: [principal(owner), principal(guest)], recorder: principal(owner))
        let initialID = UUID().uuidString
        let initial: ValueType = .object(["operationID": .string(initialID), "plan": MeetingSurfaceConfiguration.encode(plan)])
        func ok(_ response: ValueType?) { XCTAssertEqual(ExploreContract.string(from: ExploreContract.object(from: response)?["status"]), "ok") }
        ok(try await cell.set(keypath: "plan.propose", value: initial, requester: owner))
        let admission = await cell.addAgreement(cell.agreementTemplate, for: guest, authorizedBy: owner)
        XCTAssertEqual(admission, .signed)
        func state(_ identity: Identity) async throws -> Object {
            let value = try await cell.get(keypath: "state", requester: identity)
            return try XCTUnwrap(ExploreContract.object(from: value))
        }
        func approvePayload(_ state: Object) throws -> ValueType {
            guard case .list(let actions)? = state["actions"],
                  let action = actions.compactMap({ ExploreContract.object(from: $0) }).first(where: { $0["keypath"] == .string("meeting.consent.approve") }),
                  let payload = action["payload"] else { throw MeetingSessionError.unavailable }
            return payload
        }
        let firstState = try await state(owner)
        let hostApproval = try approvePayload(firstState)
        ok(try await cell.set(keypath: "consent.approve", value: hostApproval, requester: owner))
        // The same host command cannot count for the guest or replace their click.
        ok(try await cell.set(keypath: "consent.approve", value: hostApproval, requester: owner))
        let guestState = try await state(guest)
        XCTAssertTrue(ExploreContract.string(from: guestState["notice"])?.contains("1 av 2") == true)
        let guestApproval = try approvePayload(guestState)
        ok(try await cell.set(keypath: "consent.approve", value: guestApproval, requester: guest))
        let approved = try await state(owner)
        XCTAssertTrue(ExploreContract.string(from: approved["notice"])?.contains("2 av 2") == true)
        // Lost initial-create response: a retry leaves all approvals intact.
        ok(try await cell.set(keypath: "plan.propose", value: initial, requester: owner))
        let afterRetry = try await state(owner)
        XCTAssertTrue(ExploreContract.string(from: afterRetry["notice"])?.contains("2 av 2") == true)
        let newPlan = MeetingPlan(purpose: "Meeting", participants: [principal(owner), principal(guest), principal(newcomer)], recorder: principal(owner))
        let oldExpected = try XCTUnwrap(ExploreContract.object(from: hostApproval)?["expected"])
        let update: ValueType = .object(["operationID": .string(UUID().uuidString), "plan": MeetingSurfaceConfiguration.encode(newPlan), "expected": oldExpected])
        // A participant's consent grant never delegates roster authority.
        do {
            let denied = try await cell.set(keypath: "plan.propose", value: update, requester: guest)
            XCTAssertNotEqual(ExploreContract.object(from: denied)?["status"], .string("ok"))
        } catch { }
        ok(try await cell.set(keypath: "plan.propose", value: update, requester: owner))
        let changed = try await state(guest)
        XCTAssertTrue(ExploreContract.string(from: changed["notice"])?.contains("0 av 3") == true)
        // A replay acknowledges the old command but restores no authority.
        ok(try await cell.set(keypath: "consent.approve", value: guestApproval, requester: guest))
        let afterOldApproval = try await state(guest)
        XCTAssertTrue(ExploreContract.string(from: afterOldApproval["notice"])?.contains("0 av 3") == true)
        let newcomerAdmission = await cell.addAgreement(cell.agreementTemplate, for: newcomer, authorizedBy: owner)
        XCTAssertEqual(newcomerAdmission, .signed)
        for identity in [owner, guest, newcomer] {
            let view = try await state(identity)
            ok(try await cell.set(keypath: "consent.approve", value: approvePayload(view), requester: identity))
        }
        let final = try await state(owner)
        XCTAssertTrue(ExploreContract.string(from: final["notice"])?.contains("3 av 3") == true)
        // Media is intentionally unavailable until durable distributed admission.
        XCTAssertFalse(String(describing: final["actions"]).contains("recording.start"))
    }

    func testInitialProposalRejectsExpectedReferenceAndReservesFailedID() async throws {
        let vault = MeetingTestIdentityVault(); let previous = CellBase.defaultIdentityVault
        CellBase.defaultIdentityVault = vault
        defer { CellBase.defaultIdentityVault = previous }
        let owner = await vault.identity(for: "initial-host", makeNewIfNotFound: true)!
        let guest = await vault.identity(for: "initial-guest", makeNewIfNotFound: true)!
        let a = MeetingPrincipal(id: owner.uuid, signingKeyFingerprint: owner.signingPublicKeyFingerprint!)
        let b = MeetingPrincipal(id: guest.uuid, signingKeyFingerprint: guest.signingPublicKeyFingerprint!)
        let plan = MeetingPlan(purpose: "Initial", participants: [a,b], recorder: a)
        let other = try MeetingConsentSession(owner: a, plan: plan)
        let ref = try other.snapshot(now: Date()).reference
        let cell = await MeetingSessionCell(owner: owner)
        let oldExpected: ValueType = .object(["operationID": .string(UUID().uuidString), "plan": MeetingSurfaceConfiguration.encode(plan), "expected": MeetingSurfaceConfiguration.encode(ref)])
        let rejected = try await cell.set(keypath: "plan.propose", value: oldExpected, requester: owner)
        XCTAssertEqual(ExploreContract.object(from: rejected)?["code"], .string("stalePlan"))
        let uncreated = try await cell.get(keypath: "state", requester: owner)
        XCTAssertEqual(ExploreContract.object(from: uncreated)?["title"], .string("Opprett et privat møte"))
        let invalid = MeetingPlan(purpose: "", participants: [a,b], recorder: a); let id = UUID().uuidString
        let invalidCommand: ValueType = .object(["operationID": .string(id), "plan": MeetingSurfaceConfiguration.encode(invalid)])
        let invalidResult = try await cell.set(keypath: "plan.propose", value: invalidCommand, requester: owner)
        XCTAssertEqual(ExploreContract.object(from: invalidResult)?["code"], .string("invalidPlan"))
        let bytes = try JSONEncoder().encode(cell)
        let restored = try JSONDecoder().decode(MeetingSessionCell.self, from: bytes)
        try await restored.ensureRuntimeReady()
        let validWithReusedID: ValueType = .object(["operationID": .string(id), "plan": MeetingSurfaceConfiguration.encode(plan)])
        let conflict = try await restored.set(keypath: "plan.propose", value: validWithReusedID, requester: owner)
        XCTAssertEqual(ExploreContract.object(from: conflict)?["code"], .string("operationConflict"))
        let repeated = try await restored.set(keypath: "plan.propose", value: invalidCommand, requester: owner)
        XCTAssertEqual(ExploreContract.object(from: repeated)?["code"], .string("invalidPlan"))
        let fresh: ValueType = .object(["operationID": .string(UUID().uuidString), "plan": MeetingSurfaceConfiguration.encode(plan)])
        let success = try await restored.set(keypath: "plan.propose", value: fresh, requester: owner)
        XCTAssertEqual(ExploreContract.object(from: success)?["status"], .string("ok"))
    }

    func testRemovedMemberCanRevokeOriginalSegmentThroughAuthorizedCell() async throws {
        let vault = MeetingTestIdentityVault(); let previous = CellBase.defaultIdentityVault
        CellBase.defaultIdentityVault = vault
        defer { CellBase.defaultIdentityVault = previous }
        let owner = await vault.identity(for: "segment-owner", makeNewIfNotFound: true)!
        let former = await vault.identity(for: "segment-former", makeNewIfNotFound: true)!
        let newcomer = await vault.identity(for: "segment-newcomer", makeNewIfNotFound: true)!
        func principal(_ identity: Identity) -> MeetingPrincipal {
            MeetingPrincipal(id: identity.uuid, signingKeyFingerprint: identity.signingPublicKeyFingerprint!)
        }
        let now = Date()
        let policy = try MeetingConsentSession(owner: principal(owner), plan: MeetingPlan(purpose: "Original",
            participants: [principal(owner), principal(former)], recorder: principal(owner)), now: now)
        let ref = try policy.snapshot(now: now).reference
        for identity in [owner, former] { try policy.approve(by: principal(identity), expected: ref, now: now) }
        let permit = try policy.start(by: principal(owner), expected: ref, now: now)
        try policy.replacePlan(MeetingPlan(purpose: "Later", participants: [principal(owner), principal(newcomer)],
            recorder: principal(owner)), by: principal(owner), expected: ref, now: now)
        let cell = await MeetingSessionCell(owner: owner)
        let admission = await cell.addAgreement(cell.agreementTemplate, for: former, authorizedBy: owner)
        XCTAssertEqual(admission, .signed)
        let newerAdmission = await cell.addAgreement(cell.agreementTemplate, for: newcomer, authorizedBy: owner)
        XCTAssertEqual(newerAdmission, .signed)
        // Restore a legitimate historical segment with the cell's actual
        // participant agreements. No recording endpoint is enabled by this fixture.
        var document = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(cell)) as? [String: Any])
        document["meetingSnapshot"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(policy.snapshot(now: now)))
        let restored = try JSONDecoder().decode(MeetingSessionCell.self, from: JSONSerialization.data(withJSONObject: document))
        try await restored.ensureRuntimeReady()
        let payload: ValueType = .object(["operationID": .string(UUID().uuidString),
            "segmentID": .string(permit.segmentID.uuidString), "expected": MeetingSurfaceConfiguration.encode(ref)])
        let denied = try await restored.set(keypath: "segment.revoke", value: payload, requester: newcomer)
        XCTAssertEqual(ExploreContract.object(from: denied)?["code"], .string("forbidden"))
        let revoked = try await restored.set(keypath: "segment.revoke", value: payload, requester: former)
        XCTAssertEqual(ExploreContract.object(from: revoked)?["status"], .string("ok"))
        let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(restored)) as? [String: Any])
        let snapshot = try XCTUnwrap(encoded["meetingSnapshot"] as? [String: Any])
        XCTAssertEqual(snapshot["processingRevokedSegments"] as? [String], [permit.segmentID.uuidString])
    }
}
