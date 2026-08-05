import Foundation
import Testing
@testable import HavenAgentRuntime
@testable import HavenMacAutomation

private actor ButlerWakeRecordingProcessRunner: ProcessRunning {
    struct Call: Equatable, Sendable {
        var executableURL: URL
        var arguments: [String]
    }

    private var recordedCalls: [Call] = []
    var result = SubprocessResult(
        command: ["/usr/bin/open"],
        terminationStatus: 0,
        standardOutput: "",
        standardError: ""
    )

    func run(executableURL: URL, arguments: [String]) async throws -> SubprocessResult {
        recordedCalls.append(Call(executableURL: executableURL, arguments: arguments))
        return result
    }

    func calls() -> [Call] {
        recordedCalls
    }
}

@Suite(.serialized)
struct PersonalButlerScheduleServiceTests {
    @Test
    func defaultsArePrivateDisabledAndUse72HourCadence() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let service = PersonalButlerScheduleService(fileURL: fixture.stateURL)

        try await service.start(runWorker: false)
        let snapshot = await service.snapshot()

        #expect(snapshot.preferences.ownerApproved == false)
        #expect(snapshot.preferences.enabled == false)
        #expect(snapshot.preferences.userScheduleEnabled == false)
        #expect(snapshot.preferences.stagingWakeEnabled == false)
        #expect(snapshot.preferences.minimumIntervalHours == 72)
    }

    @Test
    func dueScheduleLaunchesFixedHAVENURLOnlyOncePerSlotAndPersistsIt() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let runner = ButlerWakeRecordingProcessRunner()
        let fixedNow = try #require(ISO8601DateFormatter().date(from: "2026-07-13T10:00:00Z"))
        let service = PersonalButlerScheduleService(
            fileURL: fixture.stateURL,
            processRunner: runner,
            calendar: Self.gmtCalendar,
            now: { fixedNow }
        )
        try await service.start(runWorker: false)
        try await service.configure(PersonalButlerDaemonPreferences(
            ownerApproved: true,
            enabled: true,
            minimumIntervalHours: 72,
            quietHoursEnabled: false,
            userScheduleEnabled: true,
            userScheduleKind: "daily",
            userScheduleLocalTime: "09:00"
        ))

        await service.evaluateSchedule()
        await service.evaluateSchedule()

        let calls = await runner.calls()
        #expect(calls.count == 1)
        #expect(calls[0].executableURL.path == "/usr/bin/open")
        #expect(calls[0].arguments.first == "-b")
        #expect(calls[0].arguments.contains(PersonalButlerScheduleService.havenBundleIdentifier))
        let url = try #require(calls[0].arguments.last)
        #expect(url.contains("haven://butler/check-in"))
        #expect(url.contains("source=havenagentd"))
        #expect(url.contains("trigger=user_schedule"))
        #expect(url.contains("slot=daily:2026-07-13"))

        let persisted = try JSONDecoder().decode(
            PersonalButlerDaemonState.self,
            from: Data(contentsOf: fixture.stateURL)
        )
        #expect(persisted.lastScheduleSlot == "daily:2026-07-13")
        #expect(persisted.lastScheduleOutcome == "launched")
    }

    @Test
    func cadenceAndQuietHoursSuppressAndConsumeDueScheduleSlots() async throws {
        let fixedNow = try #require(ISO8601DateFormatter().date(from: "2026-07-13T10:00:00Z"))

        let cadenceFixture = try Fixture()
        defer { cadenceFixture.cleanup() }
        let cadenceRunner = ButlerWakeRecordingProcessRunner()
        let cadenceService = PersonalButlerScheduleService(
            fileURL: cadenceFixture.stateURL,
            processRunner: cadenceRunner,
            calendar: Self.gmtCalendar,
            now: { fixedNow }
        )
        try await cadenceService.start(runWorker: false)
        try await cadenceService.configure(PersonalButlerDaemonPreferences(
            ownerApproved: true,
            enabled: true,
            minimumIntervalHours: 72,
            quietHoursEnabled: false,
            userScheduleEnabled: true,
            userScheduleKind: "daily",
            userScheduleLocalTime: "09:00",
            lastOfferedAt: "2026-07-13T09:00:00Z"
        ))
        await cadenceService.evaluateSchedule()
        #expect(await cadenceRunner.calls().isEmpty)
        #expect(await cadenceService.snapshot().lastScheduleOutcome == "suppressed:minimum_interval")

        let quietFixture = try Fixture()
        defer { quietFixture.cleanup() }
        let quietRunner = ButlerWakeRecordingProcessRunner()
        let quietService = PersonalButlerScheduleService(
            fileURL: quietFixture.stateURL,
            processRunner: quietRunner,
            calendar: Self.gmtCalendar,
            now: { fixedNow }
        )
        try await quietService.start(runWorker: false)
        try await quietService.configure(PersonalButlerDaemonPreferences(
            ownerApproved: true,
            enabled: true,
            quietHoursEnabled: true,
            quietHoursStart: 9,
            quietHoursEnd: 11,
            userScheduleEnabled: true,
            userScheduleKind: "daily",
            userScheduleLocalTime: "09:00"
        ))
        await quietService.evaluateSchedule()
        #expect(await quietRunner.calls().isEmpty)
        #expect(await quietService.snapshot().lastScheduleOutcome == "suppressed:quiet_hours")
    }

    @Test
    func signedRemoteWakeStillRequiresLocalOwnerConsentAndIgnoresArguments() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let runner = ButlerWakeRecordingProcessRunner()
        let fixedNow = try #require(ISO8601DateFormatter().date(from: "2026-07-13T12:00:00Z"))
        let service = PersonalButlerScheduleService(
            fileURL: fixture.stateURL,
            processRunner: runner,
            calendar: Self.gmtCalendar,
            now: { fixedNow }
        )
        try await service.start(runWorker: false)
        let intent = QueuedRemoteIntent(
            id: "signed-staging-wake-1",
            topic: PersonalButlerScheduleService.remoteWakeTopic,
            origin: "staging",
            actionID: PersonalButlerScheduleService.remoteWakeActionID,
            arguments: ["url": "file:///tmp/never-open-this", "command": "never-run-this"],
            receivedAt: "2026-07-13T12:00:00Z",
            issuerID: "staging.example",
            verificationStatus: "verified"
        )

        #expect(await service.handleRemoteWake(intent: intent) == .suppressed("owner_approval_missing"))
        try await service.configure(PersonalButlerDaemonPreferences(
            ownerApproved: true,
            enabled: true,
            quietHoursEnabled: false,
            appLaunchEnabled: true,
            stagingWakeEnabled: false
        ))
        #expect(await service.handleRemoteWake(intent: intent) == .suppressed("staging_wake_disabled"))

        try await service.configure(PersonalButlerDaemonPreferences(
            ownerApproved: true,
            enabled: true,
            quietHoursEnabled: false,
            appLaunchEnabled: true,
            stagingWakeEnabled: true
        ))
        #expect(await service.handleRemoteWake(intent: intent) == .launched)

        let calls = await runner.calls()
        #expect(calls.count == 1)
        let arguments = calls[0].arguments.joined(separator: " ")
        #expect(arguments.contains("trigger=app_launch"))
        #expect(arguments.contains("file:///tmp/never-open-this") == false)
        #expect(arguments.contains("never-run-this") == false)
    }

    private static var gmtCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }
}

private struct Fixture {
    let directoryURL: URL
    let stateURL: URL

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("haven-butler-schedule-tests-\(UUID().uuidString)", isDirectory: true)
        stateURL = directoryURL.appendingPathComponent("personal-butler-schedule.json")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}
