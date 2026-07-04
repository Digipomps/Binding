import Foundation
import HavenAgentRuntime
import HavenRuntimeBootstrap
import Testing

@Suite
struct AdvisorPanelSpawnServiceTests {
    @Test
    func planReturnsAdvisorTasksWithoutWritingArtifacts() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AdvisorPanelSpawnTests-\(UUID().uuidString)", isDirectory: true)
        let paths = RuntimePaths.rooted(at: root)
        let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)
        let service = AdvisorPanelSpawnService(paths: paths, now: { fixedDate })

        let result = try service.plan(.bindingGUIQualityProfile(brief: "Plan Binding GUI review."))

        #expect(result.schema == AdvisorPanelPlanContract.schema)
        #expect(result.status == "planned")
        #expect(result.sideEffects.writesFiles == false)
        #expect(result.sideEffects.queuesRequests == false)
        #expect(result.sideEffects.mutatesCells == false)
        #expect(result.sideEffects.callsProviders == false)
        #expect(result.sideEffects.executesProcesses == false)
        #expect(result.persistence.written == false)
        #expect(result.persistence.filePath == nil)
        #expect(result.artifact.tasks.allSatisfy { $0.status == "planned_not_queued" })

        let advisorDirectory = paths.outputDirectory
            .appendingPathComponent(AdvisorPanelSpawnContract.directoryName, isDirectory: true)
        #expect(FileManager.default.fileExists(atPath: advisorDirectory.path) == false)
    }

    @Test
    func spawnWritesSideEffectFreeAdvisorPanelArtifact() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AdvisorPanelSpawnTests-\(UUID().uuidString)", isDirectory: true)
        let paths = RuntimePaths.rooted(at: root)
        let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)
        let service = AdvisorPanelSpawnService(paths: paths, now: { fixedDate })
        let request = AdvisorPanelSpawnRequest.bindingGUIQualityProfile(brief: "Review Binding GUI parity.")

        let record = try service.spawn(request)

        #expect(record.artifact.schema == AdvisorPanelSpawnContract.schema)
        #expect(record.artifact.source == AdvisorPanelSpawnContract.source)
        #expect(record.artifact.purposeRef == "purpose://binding.gui.user-value")
        #expect(record.artifact.sideEffectBoundary.contains("does not call AI providers"))
        #expect(record.artifact.sideEffectBoundary.contains("mutate Cell state"))
        #expect(record.artifact.tasks.count == record.artifact.advisors.count)
        #expect(record.filePath.contains(AdvisorPanelSpawnContract.directoryName))
        #expect(record.filePath.contains("/Out/"))
        #expect(!record.filePath.contains("/Inbox/"))

        let data = try Data(contentsOf: URL(fileURLWithPath: record.filePath))
        let decoded = try JSONDecoder().decode(AdvisorPanelSpawnArtifact.self, from: data)
        #expect(decoded == record.artifact)

        let firstPrompt = try #require(record.artifact.tasks.first?.prompt)
        #expect(firstPrompt.contains("CellProtocol"))
        #expect(firstPrompt.contains("CellScaffold"))
        #expect(firstPrompt.contains("side effects"))
        #expect(firstPrompt.contains("Review Binding GUI parity."))
    }

    @Test
    func spawnRejectsEmptyCustomBrief() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AdvisorPanelSpawnTests-\(UUID().uuidString)", isDirectory: true)
        let service = AdvisorPanelSpawnService(paths: RuntimePaths.rooted(at: root))
        let request = AdvisorPanelSpawnRequest(
            topic: "Binding GUI",
            purposeRef: "purpose://binding.gui.user-value",
            goal: "Define measurable GUI quality.",
            brief: "   "
        )

        do {
            _ = try service.spawn(request)
            Issue.record("Expected empty brief rejection.")
        } catch let error as AdvisorPanelSpawnError {
            #expect(error == .emptyBrief)
        }
    }
}
