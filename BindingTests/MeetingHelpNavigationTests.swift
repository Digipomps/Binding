import XCTest
import CellBase
@testable import CellApple
@testable import Binding

@MainActor
final class MeetingHelpNavigationTests: XCTestCase {
    func testMeetingHelpPayloadLoadsThroughActualPorthole() async throws {
        let previousAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = false
        defer { CellBase.debugValidateAccessForEverything = previousAccess }
        let meeting = try MeetingSurfaceConfiguration.make(endpoint: "cell:///MeetingSession")
        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: meeting, identityMode: .test)
        let payload: ValueType = .object(["configurationLookup": .object([
            "name": .string("Co-Pilot Chat"), "sourceCellEndpoint": .string("cell:///PersonalChatHub")
        ])])
        let resolved = await CellConfigurationPayloadSupport.resolveCellConfiguration(from: payload, requester: context.owner)
        XCTAssertNotNil(resolved?.skeleton)
        let response = try await context.porthole.set(keypath: "addConfiguration", value: payload, requester: context.owner)
        XCTAssertEqual(response, .string("ok"))
        // Native Porthole UI consumes this configuration snapshot. The older
        // `skeleton` get is a rendered string, not this portable Skeleton.
        let loaded = try XCTUnwrap(context.porthole.getCellConfiguration())
        XCTAssertNotNil(loaded.skeleton)
        let encoded = String(decoding: try JSONEncoder().encode(loaded), as: UTF8.self)
        XCTAssertTrue(encoded.contains("prompt.submit"))
        XCTAssertTrue(encoded.contains("setComposer"))
        let outsiderVault = EphemeralIdentityVault()
        let outsiderIdentity = await outsiderVault.identity(for: "outside-help-scope", makeNewIfNotFound: true)
        let outsider = try XCTUnwrap(outsiderIdentity)
        do {
            let denied = try await context.porthole.set(keypath: "addConfiguration", value: payload, requester: outsider)
            XCTAssertNotEqual(denied, .string("ok"))
        } catch { /* Real authorization failure is expected. */ }
    }

    func testSourceBackedChatExportHasComposerAndSurvivesReload() async throws {
        let vault = MeetingTestIdentityVault()
        let previous = CellBase.defaultIdentityVault
        CellBase.defaultIdentityVault = vault
        defer { CellBase.defaultIdentityVault = previous }
        let owner = await vault.identity(for: "meeting-help-test", makeNewIfNotFound: true)!
        let fresh = await BindingPersonalChatHubCell(owner: owner)
        for cell in [fresh, try JSONDecoder().decode(BindingPersonalChatHubCell.self, from: JSONEncoder().encode(fresh))] {
            try await cell.ensureRuntimeReady()
            let exported = try await cell.get(keypath: "skeletonConfiguration", requester: owner)
            let configuration = try XCTUnwrap(CellConfigurationPayloadSupport.decodeCellConfiguration(from: exported))
            XCTAssertNotNil(configuration.skeleton, "A name-only summary silently opens an empty chat")
            let encoded = String(decoding: try JSONEncoder().encode(configuration), as: UTF8.self)
            XCTAssertTrue(encoded.contains("chatHub"))
            XCTAssertTrue(encoded.contains("prompt.submit"))
            XCTAssertTrue(encoded.contains("setComposer"))
            let response = try await cell.set(keypath: "chatHub.help.openContextual", value: .object([
                "surfaceName": .string("Møteopptak"),
                "surfaceDescription": .string("Ny deltaker stopper opptaket. Alle må godkjenne på nytt, også fra Nearby."),
                "editorMode": .string("view")
            ]), requester: owner)
            XCTAssertEqual(ExploreContract.object(from: response)?["status"], .string("context_staged"))
            let state = try await cell.get(keypath: "state", requester: owner)
            let stateJSON = String(decoding: try JSONEncoder().encode(state), as: UTF8.self)
            XCTAssertTrue(stateJSON.contains("Nearby"))
            XCTAssertTrue(stateJSON.contains("Møteopptak"))
        }
    }
}
