import Foundation
@preconcurrency import CellBase
import Testing
@testable import HavenAgentCells
@testable import HavenAgentRuntime

@Suite(.serialized)
struct PersonalButlerScheduleCellTests {
    @Test
    func ownerCanConfigurePrivacySafeDaemonScheduleThroughCell() async throws {
        await PersonalButlerBridgeTestLock.shared.acquire()
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("haven-butler-cell-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let service = PersonalButlerScheduleService(
            fileURL: directoryURL.appendingPathComponent("personal-butler-schedule.json")
        )
        try await service.start(runWorker: false)
        await AgentRuntimeBridge.shared.update(personalButlerScheduleService: service)

        let vault = EphemeralIdentityVault()
        let owner = try #require(await vault.identity(
            for: "personal-butler-schedule-cell-owner-\(UUID().uuidString)",
            makeNewIfNotFound: true
        ))
        let previousVault = CellBase.defaultIdentityVault
        CellBase.defaultIdentityVault = vault
        defer {
            CellBase.defaultIdentityVault = previousVault
            Task {
                await AgentRuntimeBridge.shared.update(personalButlerScheduleService: nil)
                await PersonalButlerBridgeTestLock.shared.release()
            }
        }

        let cell = await PersonalButlerScheduleCell(owner: owner)
        let initial = try #require(object(try await cell.get(keypath: "state", requester: owner)))
        #expect(bool(initial["storesChatContent"]) == false)
        #expect(bool(initial["storesPersonalityContent"]) == false)

        let unapprovedValue = try await cell.set(
            keypath: "preferences.configure",
            value: .object(["enabled": .bool(true)]),
            requester: owner
        )
        let unapproved = try #require(object(unapprovedValue))
        let unapprovedPreferences = try #require(object(unapproved["preferences"]))
        #expect(bool(unapprovedPreferences["ownerApproved"]) == false)

        let configuredValue = try await cell.set(
            keypath: "preferences.configure",
            value: .object([
                "ownerApproved": .bool(true),
                "enabled": .bool(true),
                "minimumIntervalHours": .integer(72),
                "quietHoursEnabled": .bool(true),
                "quietHoursStart": .integer(22),
                "quietHoursEnd": .integer(8),
                "userScheduleEnabled": .bool(true),
                "userScheduleKind": .string("weekdays"),
                "userScheduleLocalTime": .string("09:00"),
                "stagingWakeEnabled": .bool(false),
                "sourceDeviceID": .string("owner-device")
            ]),
            requester: owner
        )
        let configured = try #require(object(configuredValue))
        let preferences = try #require(object(configured["preferences"]))
        #expect(bool(preferences["ownerApproved"]) == true)
        #expect(bool(preferences["userScheduleEnabled"]) == true)
        #expect(bool(preferences["stagingWakeEnabled"]) == false)
        #expect(string(preferences["approvedByIdentityUUID"]) == owner.uuid)

        let snapshot = await service.snapshot()
        #expect(snapshot.preferences.ownerApproved == true)
        #expect(snapshot.preferences.sourceDeviceID == "owner-device")
        #expect(snapshot.preferences.approvedByIdentityUUID == owner.uuid)
    }

    private func object(_ value: ValueType?) -> Object? {
        guard case let .object(result)? = value else { return nil }
        return result
    }

    private func bool(_ value: ValueType?) -> Bool? {
        guard case let .bool(result)? = value else { return nil }
        return result
    }

    private func string(_ value: ValueType?) -> String? {
        guard case let .string(result)? = value else { return nil }
        return result
    }
}
