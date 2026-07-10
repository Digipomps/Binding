import Foundation
import Testing
@testable import HavenAgentRuntime
@testable import HavenMacAutomation

private final class ScheduledTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(_ value: Date) { self.value = value }

    func now() -> Date {
        lock.withLock { value }
    }

    func advance(seconds: TimeInterval) {
        lock.withLock { value = value.addingTimeInterval(seconds) }
    }
}

private actor ScheduledRecordingProcessRunner: ProcessRunning {
    private(set) var commands: [[String]] = []

    func run(executableURL: URL, arguments: [String]) async throws -> SubprocessResult {
        let command = [executableURL.path] + arguments
        commands.append(command)
        return SubprocessResult(command: command, terminationStatus: 0, standardOutput: "ok", standardError: "")
    }
}

struct ScheduledEventServiceTests {
    @Test
    func countedEventRunsExactNumberOfTimesAndPersistsCompletion() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let clock = ScheduledTestClock(try #require(ISO8601DateFormatter().date(from: "2026-07-10T23:00:00Z")))
        let runner = ScheduledRecordingProcessRunner()
        let service = ScheduledEventService(
            fileURL: directory.appendingPathComponent("scheduled-events.json"),
            processRunner: runner,
            now: { clock.now() },
            sleep: { _ in try await Task.sleep(nanoseconds: 60_000_000_000) }
        )
        let definition = ScheduledEventDefinition(
            id: "counted",
            firstFireAt: "2026-07-10T23:00:00Z",
            repeatMode: .count,
            repeatCount: 2,
            intervalSeconds: 60,
            action: AutomationActionRequest(kind: .localTask, id: "test-task")
        )
        let policy = AutomationPolicy(localTasks: [
            LocalTaskDefinition(id: "test-task", description: "test", executablePath: "/usr/bin/true", arguments: [])
        ])

        try await service.start(definitions: [definition], policy: policy)
        await service.runDueEvents()
        clock.advance(seconds: 60)
        await service.runDueEvents()
        await service.stop()

        let record = try #require(await service.snapshot().first)
        #expect(record.status == .completed)
        #expect(record.runCount == 2)
        #expect(await runner.commands.count == 2)

        let persisted = try await ScheduledEventStore(fileURL: directory.appendingPathComponent("scheduled-events.json")).load()
        #expect(persisted.first?.status == .completed)
        #expect(persisted.first?.runCount == 2)
    }

    @Test
    func stoppedUntilStoppedEventDoesNotRunAgain() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = ScheduledEventService(
            fileURL: directory.appendingPathComponent("scheduled-events.json"),
            sleep: { _ in try await Task.sleep(nanoseconds: 60_000_000_000) }
        )
        let definition = ScheduledEventDefinition(
            id: "continuous",
            firstFireAt: "2099-01-01T00:00:00Z",
            repeatMode: .untilStopped,
            intervalSeconds: 60,
            action: AutomationActionRequest(kind: .localTask, id: "test-task")
        )

        try await service.start(definitions: [definition], policy: .init())
        let stopped = try await service.stopEvent(id: "continuous")
        await service.stop()

        #expect(stopped.status == .stopped)
        #expect(stopped.nextFireAt == nil)
    }

    @Test
    func workerObservesStopWrittenByAnotherProcess() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("scheduled-events.json")
        let definition = ScheduledEventDefinition(
            id: "shared-stop",
            firstFireAt: "2099-01-01T00:00:00Z",
            repeatMode: .untilStopped,
            intervalSeconds: 60,
            action: AutomationActionRequest(kind: .localTask, id: "test-task")
        )
        let worker = ScheduledEventService(
            fileURL: fileURL,
            sleep: { _ in try await Task.sleep(nanoseconds: 60_000_000_000) }
        )
        let controller = ScheduledEventService(fileURL: fileURL)

        try await worker.start(definitions: [definition], policy: .init())
        try await controller.start(
            definitions: [definition],
            policy: .init(),
            runWorker: false
        )
        _ = try await controller.stopEvent(id: "shared-stop")
        await worker.runDueEvents()
        await worker.stop()

        #expect(await worker.snapshot().first?.status == .stopped)
        #expect(await worker.snapshot().first?.nextFireAt == nil)
    }
}
