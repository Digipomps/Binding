import Foundation
import Testing
import CellBase
@testable import Binding

@MainActor
@Suite(.serialized)
struct WorkflowStudioTests {

    @Test func workflowDefinitionValidationFlagsPortMismatch() {
        var definition = WorkflowCatalog.documentPipeline()
        guard definition.nodes.count >= 3 else {
            Issue.record("Expected seeded document pipeline nodes")
            return
        }

        let start = definition.nodes[0]
        let transform = definition.nodes[2]
        definition.edges = [
            WorkflowEdge(
                id: UUID().uuidString,
                fromNodeID: start.id,
                fromPortID: "next",
                toNodeID: transform.id,
                toPortID: "transformed",
                label: nil
            )
        ]

        let issues = WorkflowDefinitionValidation.validate(definition)
        #expect(issues.contains(where: { $0.severity == .error }))
    }

    @Test func workflowRunnerExecutesDeterministicDocumentPipeline() async {
        let definition = WorkflowCatalog.documentPipeline()
        let run = await WorkflowRunner.run(
            definition: definition,
            input: .string("HAVEN Notes\n- parser\n- transform\nhttps://haven.example"),
            requester: nil
        )

        #expect(run.status == .completed)
        #expect(run.nodeSnapshots.isEmpty == false)
        #expect(run.resultSummary.isEmpty == false)
    }

    @Test func workflowStudioWorkbenchConfigurationIsSourceBacked() {
        let configuration = WorkflowStudioCell.workbenchConfiguration()

        #expect(configuration.discovery?.sourceCellEndpoint == "cell:///WorkflowStudio")
        #expect(configuration.cellReferences?.contains(where: {
            $0.label == "workflowStudio" && $0.endpoint == "cell:///WorkflowStudio"
        }) == true)
        #expect(configuration.skeleton != nil)
    }

    @Test func workflowStudioPortableConfigurationTargetsRemoteUse() {
        let configuration = WorkflowStudioCell.portableConfiguration()

        #expect(configuration.name == "Workflow Remote")
        #expect(configuration.discovery?.sourceCellEndpoint == nil)
        #expect(configuration.discovery?.menuSlots.contains("lowerMid") == true)
        #expect(configuration.cellReferences?.contains(where: {
            $0.label == "workflowStudio" && $0.endpoint == "cell:///WorkflowStudio"
        }) == true)
        #expect(configuration.skeleton != nil)
    }

    @Test func workflowStudioCellExposesEditableStateAndRunsDemo() async throws {
        CellBase.defaultIdentityVault = nil
        CellBase.defaultCellResolver = nil
        CellBase.typedCellUtility = nil

        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected CellResolver after Binding bootstrap")
            return
        }
        guard let requester = await CellBase.defaultIdentityVault?.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Expected requester identity after Binding bootstrap")
            return
        }
        guard let workflowStudio = try await resolver.cellAtEndpoint(
            endpoint: "cell:///WorkflowStudio",
            requester: requester
        ) as? Meddle else {
            Issue.record("Expected WorkflowStudio cell to be locally registered")
            return
        }

        let editableState = try await workflowStudio.get(
            keypath: BindingEditableCellConfigurationContract.stateKeypath,
            requester: requester
        )
        let stateValue = try await workflowStudio.set(
            keypath: "workflow.run",
            value: .null,
            requester: requester
        )

        guard let decodedEditable = BindingEditableCellConfigurationContract.decodeState(from: editableState) else {
            Issue.record("Expected editable configuration state for Workflow Studio")
            return
        }

        #expect(decodedEditable.canEdit)

        guard case let .object(object)? = stateValue,
              let lastRun = object["lastRun"] ?? object["state"] else {
            Issue.record("Expected workflow state after running demo")
            return
        }

        #expect(renderPreview(lastRun).isEmpty == false)
    }
}
