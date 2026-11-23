// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import XCTest
@testable import CellBase
@testable import Binding

/// The entity-extension flow in Binding must agree with CellBase, PyCellProtocol
/// and GoCellProtocol: the approval binds to SHA-256 of the canonical request,
/// the human code is derived from that hash, and an approval is only accepted
/// when the approver's signature verifies.
final class EntityScaffoldExtensionCellTests: XCTestCase {
    /// CellProtocol fixtures/interop/v1/extend.request.valid.json, `encodedBase64`.
    private static let fixtureRequestBase64 = "eyJhdWRpZW5jZSI6InN0YWdpbmcuaGF2ZW4uZGlnaXBvbXBzLm9yZyIsImNyZWF0ZWRBdCI6IjIwMjYtMTAtMjdUMTE6NTk6MDBaIiwiZGV2aWNlTGFiZWwiOiJTdHVkZW50ZW5zIGLDpnJiYXJlIiwiZW50aXR5QmluZGluZyI6eyJhdWRpZW5jZSI6InN0YWdpbmcuaGF2ZW4uZGlnaXBvbXBzLm9yZyIsImJpbmRpbmdJRCI6ImJpbmQtMDAwMSIsImVudGl0eUFuY2hvclJlZmVyZW5jZSI6ImNlbGw6XC9cL1wvRW50aXR5QW5jaG9yIiwibW9kZSI6ImxvY2FsRW50aXR5QW5jaG9yIn0sImV4cGlyZXNBdCI6IjIwMjYtMTAtMjdUMTI6MDk6MDBaIiwibmV3SWRlbnRpdHkiOnsiYWxnb3JpdGhtIjoiRWREU0EiLCJjdXJ2ZVR5cGUiOiJDdXJ2ZTI1NTE5IiwiZGlzcGxheU5hbWUiOiJib2IiLCJwdWJsaWNLZXkiOiJQU2huNUpiYWFLVDBscHpISEZnYzRmcThJQkRHNFd5T2tkWkwwVWVmdXpFPSIsInV1aWQiOiI2RjFDMkIwQS0wMDAwLTQwMDAtODAwMC0wMDAwMDAwMDBCMEIifSwibm9uY2UiOiJpWjNNUlJPZmFSeHdIR2ZZZWtHQWpoSU1zU25Jd09VQjhpdFc4WGxyRk5BPSIsIm9yaWdpbiI6Imh0dHBzOlwvXC9zdGFnaW5nLmhhdmVuLmRpZ2lwb21wcy5vcmdcL2xpbmsiLCJwbGF0Zm9ybSI6InB5dGhvbiIsInByb29mIjp7ImFsZ29yaXRobSI6IkVkRFNBIiwiYnlJZGVudGl0eVVVSUQiOiI2RjFDMkIwQS0wMDAwLTQwMDAtODAwMC0wMDAwMDAwMDBCMEIiLCJjdXJ2ZVR5cGUiOiJDdXJ2ZTI1NTE5Iiwic2lnbmF0dXJlIjoiUXh5dTVyMFVFMjNPUFVhV0dpdzNjdDFqQnVJeUk1b21qSEJGYlEwbmk1VEd2TWYxZTFsUDFRXC95T0o4dXNuZGpaUTcwQUphOVZENSt5eDFDOERaWUJBPT0iLCJ0eXBlIjoic2lnbmF0dXJlIn0sInB1cnBvc2UiOiJsaW5rX2lkZW50aXR5IiwicmVxdWVzdElEIjoicmVxLWludGVyb3AtMDAwMSIsInJlcXVlc3RlZERvbWFpbnMiOlsicHJpdmF0ZSIsInNjYWZmb2xkIl0sInJlcXVlc3RlZElkZW50aXR5Q29udGV4dHMiOlsiZGVmYXVsdCJdLCJyZXF1ZXN0ZWRTY29wZXMiOlsiY2hhdC5yZWFkIiwiY2hhdC53cml0ZSJdLCJ2ZXJzaW9uIjoxfQ=="

    private func withVault(_ body: (MeetingTestIdentityVault) async throws -> Void) async throws {
        let vault = MeetingTestIdentityVault()
        let previous = CellBase.defaultIdentityVault
        CellBase.defaultIdentityVault = vault
        defer { CellBase.defaultIdentityVault = previous }
        try await body(vault)
    }

    private func call(_ cell: BindingEntityScaffoldExtensionCell, _ key: String, _ value: ValueType, as requester: Identity) async throws -> Object {
        let response = try await cell.set(keypath: key, value: value, requester: requester)
        return try XCTUnwrap(ExploreContract.object(from: response), "\(key) returned no object")
    }

    func testHashAndHumanCodeMatchTheInteropFixture() throws {
        let data = try XCTUnwrap(Data(base64Encoded: Self.fixtureRequestBase64))
        let request = try JSONDecoder().decode(IdentityEnrollmentRequest.self, from: data)
        let hash = try IdentityLinkProtocolService.requestHash(for: request)
        XCTAssertEqual(hash.base64EncodedString(), "em6sWAmJwoROjVsO1ODz94rajg0oDW/bevdw2dNDe5E=")
        XCTAssertEqual(BindingEntityScaffoldExtensionCell.humanCode(for: request), "P6EACF")
    }

    func testHumanCodeChangesWhenTheRequestChanges() throws {
        let data = try XCTUnwrap(Data(base64Encoded: Self.fixtureRequestBase64))
        let request = try JSONDecoder().decode(IdentityEnrollmentRequest.self, from: data)
        var swapped = request
        swapped.requestedScopes.append("admin")
        XCTAssertEqual(swapped.requestID, request.requestID)
        XCTAssertEqual(swapped.audience, request.audience)
        XCTAssertNotEqual(BindingEntityScaffoldExtensionCell.humanCode(for: swapped), BindingEntityScaffoldExtensionCell.humanCode(for: request),
                          "Same requestID and audience must not give the same code when the content differs")
    }

    func testAskApproveAcceptNeedsTheApproversSignature() async throws {
        try await withVault { vault in
            let newPlace = await vault.identity(for: "extend-new-place", makeNewIfNotFound: true)!
            let existing = await vault.identity(for: "extend-existing", makeNewIfNotFound: true)!
            let stranger = await vault.identity(for: "extend-stranger", makeNewIfNotFound: true)!
            let asking = await BindingEntityScaffoldExtensionCell(owner: newPlace)
            let approving = await BindingEntityScaffoldExtensionCell(owner: existing)
            let forging = await BindingEntityScaffoldExtensionCell(owner: stranger)

            let asked = try await call(asking, "extension.beginRequest", .object(["audience": .string("staging.haven.digipomps.org")]), as: newPlace)
            XCTAssertEqual(HavenValue.string(asked["status"]), "ok")
            let requestPayload = try XCTUnwrap(HavenValue.string(asked["payload"]))
            let code = try XCTUnwrap(HavenValue.string(asked["humanCode"]))

            let review = try await call(approving, "extension.reviewRequest", .object(["payload": .string(requestPayload)]), as: existing)
            XCTAssertEqual(HavenValue.string(review["humanCode"]), code, "Both screens show the same code")

            let approved = try await call(approving, "extension.approveRequest", .object(["payload": .string(requestPayload)]), as: existing)
            XCTAssertEqual(HavenValue.string(approved["status"]), "ok")
            let package = try XCTUnwrap(HavenValue.string(approved["package"]))
            let bareApproval = try XCTUnwrap(HavenValue.string(approved["payload"]))

            // A bare approval without the approver's key is refused.
            let bare = try await call(asking, "extension.acceptApproval", .object(["payload": .string(bareApproval)]), as: newPlace)
            XCTAssertEqual(HavenValue.string(HavenValue.object(bare["error"])?["code"]) ?? HavenValue.string(bare["code"]), "missing_issuer_key", "\(bare)")

            // The approval with someone else's key next to it is refused.
            let strangerKey = try XCTUnwrap(IdentityPublicKeySignatureVerifier.descriptor(for: stranger))
            let wrongKey = try await call(asking, "extension.acceptApproval", .object([
                "payload": .string(bareApproval),
                "issuerIdentity": try XCTUnwrap(try? JSONDecoder().decode(ValueType.self, from: JSONEncoder().encode(strangerKey)))
            ]), as: newPlace)
            XCTAssertEqual(HavenValue.string(HavenValue.object(wrongKey["error"])?["code"]) ?? HavenValue.string(wrongKey["code"]), "bad_signature", "\(wrongKey)")

            // An approval signed by another identity for the same request is refused too.
            let forged = try await call(forging, "extension.approveRequest", .object(["payload": .string(requestPayload)]), as: stranger)
            let forgedApproval = try XCTUnwrap(HavenValue.string(forged["payload"]))
            let existingKey = try XCTUnwrap(IdentityPublicKeySignatureVerifier.descriptor(for: existing))
            let swappedKey = try await call(asking, "extension.acceptApproval", .object([
                "payload": .string(forgedApproval),
                "issuerIdentity": try XCTUnwrap(try? JSONDecoder().decode(ValueType.self, from: JSONEncoder().encode(existingKey)))
            ]), as: newPlace)
            XCTAssertNotEqual(HavenValue.string(swappedKey["status"]), "ok", "\(swappedKey)")

            // The full package links.
            let accepted = try await call(asking, "extension.acceptApproval", .object(["package": .string(package)]), as: newPlace)
            XCTAssertEqual(HavenValue.string(accepted["status"]), "ok", "\(accepted)")
            XCTAssertEqual(accepted["signatureVerified"], .bool(true))
        }
    }
}
