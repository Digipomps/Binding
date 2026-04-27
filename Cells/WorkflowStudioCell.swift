import Foundation
import CellBase

final class WorkflowStudioCell: GeneralCell {
    static let endpoint = "cell:///WorkflowStudio"
    private static let sourceLabel = "workflowStudio"

    private enum CodingKeys: String, CodingKey {
        case workflowDefinition
        case workflowRevision
        case selectedNodeID
        case runInputText
        case storedConfiguration
        case configurationRevision
        case lastRunState
        case owner
    }

    private let stateQueue = DispatchQueue(label: "Binding.WorkflowStudioCell.State")

    private nonisolated(unsafe) var workflowDefinition: WorkflowDefinition = WorkflowCatalog.documentPipeline()
    private nonisolated(unsafe) var workflowRevision: Int = 1
    private nonisolated(unsafe) var selectedNodeID: String?
    private nonisolated(unsafe) var runInputText: String = "Analyze NVDA and return a compact company summary."
    private nonisolated(unsafe) var storedConfiguration: CellConfiguration = WorkflowStudioCell.workbenchConfiguration()
    private nonisolated(unsafe) var configurationRevision: Int = 1
    private nonisolated(unsafe) var lastRunState: WorkflowRunState?
    private nonisolated(unsafe) var ownerUUID: String = ""

    required init(owner: Identity) async {
        await super.init(owner: owner)
        ownerUUID = owner.uuid
        stateQueue.sync {
            workflowDefinition = WorkflowStudioCell.normalizedDefinition(workflowDefinition)
            storedConfiguration = WorkflowStudioCell.normalizedConfiguration(storedConfiguration)
            if selectedNodeID == nil {
                selectedNodeID = workflowDefinition.nodes.first?.id
            }
        }
        await setupPermissions()
        await setupKeys(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workflowDefinition = try container.decodeIfPresent(WorkflowDefinition.self, forKey: .workflowDefinition) ?? WorkflowCatalog.documentPipeline()
        workflowRevision = try container.decodeIfPresent(Int.self, forKey: .workflowRevision) ?? 1
        selectedNodeID = try container.decodeIfPresent(String.self, forKey: .selectedNodeID)
        runInputText = try container.decodeIfPresent(String.self, forKey: .runInputText) ?? "Analyze NVDA and return a compact company summary."
        storedConfiguration = try container.decodeIfPresent(CellConfiguration.self, forKey: .storedConfiguration) ?? WorkflowStudioCell.workbenchConfiguration()
        configurationRevision = try container.decodeIfPresent(Int.self, forKey: .configurationRevision) ?? 1
        lastRunState = try container.decodeIfPresent(WorkflowRunState.self, forKey: .lastRunState)
        ownerUUID = try container.decodeIfPresent(Identity.self, forKey: .owner)?.uuid ?? ""

        try super.init(from: decoder)
        Task {
            if let vault = CellBase.defaultIdentityVault,
               let requester = await vault.identity(for: "private", makeNewIfNotFound: true) {
                self.stateQueue.sync {
                    self.workflowDefinition = WorkflowStudioCell.normalizedDefinition(self.workflowDefinition)
                    self.storedConfiguration = WorkflowStudioCell.normalizedConfiguration(self.storedConfiguration)
                    if self.selectedNodeID == nil {
                        self.selectedNodeID = self.workflowDefinition.nodes.first?.id
                    }
                }
                await self.setupPermissions()
                await self.setupKeys(owner: requester)
            }
        }
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        let snapshot = stateQueue.sync {
            (
                definition: workflowDefinition,
                revision: workflowRevision,
                selectedNodeID: selectedNodeID,
                runInputText: runInputText,
                configuration: storedConfiguration,
                configurationRevision: configurationRevision,
                lastRunState: lastRunState
            )
        }
        try container.encode(snapshot.definition, forKey: .workflowDefinition)
        try container.encode(snapshot.revision, forKey: .workflowRevision)
        try container.encodeIfPresent(snapshot.selectedNodeID, forKey: .selectedNodeID)
        try container.encode(snapshot.runInputText, forKey: .runInputText)
        try container.encode(snapshot.configuration, forKey: .storedConfiguration)
        try container.encode(snapshot.configurationRevision, forKey: .configurationRevision)
        try container.encodeIfPresent(snapshot.lastRunState, forKey: .lastRunState)
    }

    private func setupPermissions() async {
        let readable = [
            "state",
            "definition",
            "workflowDefinitionState",
            "configuration",
            "skeletonConfiguration",
            "purposeGoal",
            BindingEditableCellConfigurationContract.stateKeypath
        ]
        let writable = [
            "workflow.selectNode",
            "workflow.insertNodeAfterSelected",
            "workflow.removeSelectedNode",
            "workflow.resetDemoDocument",
            "workflow.resetDemoResearch",
            "workflow.resetDemoApproval",
            "workflow.run",
            "workflow.setRunInputText",
            "workflow.setSelectedNodeTitle",
            "workflow.setSelectedNodeInstructions",
            "workflow.setSelectedNodeProvider",
            "workflow.setSelectedNodeModel",
            "workflow.setSelectedNodeConditionKeypath",
            "workflow.setSelectedNodeTransformStrategy",
            "workflow.setSelectedNodePromptTemplate",
            "applyWorkflowDefinition",
            "workflow.applyDefinition",
            BindingEditableCellConfigurationContract.applyKeypath
        ]
        readable.forEach { agreementTemplate.addGrant("r---", for: $0) }
        writable.forEach {
            agreementTemplate.addGrant("r---", for: $0)
            agreementTemplate.addGrant("rw--", for: $0)
        }
    }

    private func setupKeys(owner: Identity) async {
        let readableKeys = [
            "state",
            "definition",
            "workflowDefinitionState",
            "configuration",
            "skeletonConfiguration",
            "purposeGoal",
            BindingEditableCellConfigurationContract.stateKeypath
        ]
        let writableKeys = [
            "workflow.selectNode",
            "workflow.insertNodeAfterSelected",
            "workflow.removeSelectedNode",
            "workflow.resetDemoDocument",
            "workflow.resetDemoResearch",
            "workflow.resetDemoApproval",
            "workflow.run",
            "workflow.setRunInputText",
            "workflow.setSelectedNodeTitle",
            "workflow.setSelectedNodeInstructions",
            "workflow.setSelectedNodeProvider",
            "workflow.setSelectedNodeModel",
            "workflow.setSelectedNodeConditionKeypath",
            "workflow.setSelectedNodeTransformStrategy",
            "workflow.setSelectedNodePromptTemplate",
            "applyWorkflowDefinition",
            "workflow.applyDefinition",
            BindingEditableCellConfigurationContract.applyKeypath
        ]

        for key in readableKeys {
            await addInterceptForGet(requester: owner, key: key) { [weak self] _, requester in
                guard let self else { return .string("failure") }
                guard await self.validateAccess("r---", at: key, for: requester) else { return .string("denied") }
                return self.readValue(for: key, requester: requester)
            }
        }

        for key in writableKeys {
            await addInterceptForSet(requester: owner, key: key) { [weak self] _, value, requester in
                guard let self else { return .string("failure") }
                guard await self.validateAccess("rw--", at: key, for: requester) else { return .string("denied") }
                return await self.writeValue(for: key, payload: value, requester: requester)
            }
        }
    }

    private func readValue(for key: String, requester: Identity) -> ValueType {
        switch key {
        case "state":
            return stateValue(requester: requester)
        case "definition":
            return WorkflowValueCodec.encode(currentDefinition()) ?? .null
        case "workflowDefinitionState":
            return workflowDefinitionStateValue(requester: requester)
        case "configuration", "skeletonConfiguration":
            return .cellConfiguration(currentConfiguration())
        case "purposeGoal":
            return .object([
                "title": .string("Workflow Studio"),
                "summary": .string("Cell-native workflow authoring for agents, transforms, parsers, approvals, and deterministic state updates."),
                "interests": .list([
                    .string("workflow"),
                    .string("agents"),
                    .string("transforms"),
                    .string("parsers"),
                    .string("approval")
                ])
            ])
        case BindingEditableCellConfigurationContract.stateKeypath:
            return editableConfigurationStateValue(requester: requester)
        default:
            return .null
        }
    }

    private func writeValue(for key: String, payload: ValueType, requester: Identity) async -> ValueType {
        switch key {
        case "workflow.selectNode":
            selectNode(with: payload)
            return stateValue(requester: requester)

        case "workflow.insertNodeAfterSelected":
            guard let kind = parseNodeKind(from: payload) else {
                return .string("error: invalid node kind payload")
            }
            insertNodeAfterSelection(kind: kind)
            return stateValue(requester: requester)

        case "workflow.removeSelectedNode":
            removeSelectedNode()
            return stateValue(requester: requester)

        case "workflow.resetDemoDocument":
            replaceDefinition(WorkflowCatalog.documentPipeline())
            updateRunInputText("Meeting Notes\nSpeaker: HAVEN Team\n- Add parser cell\n- Normalize output\n- Summarize with local AI")
            return stateValue(requester: requester)

        case "workflow.resetDemoResearch":
            replaceDefinition(WorkflowCatalog.researchPipeline())
            updateRunInputText("Analyze NVDA and return a structured company brief.")
            return stateValue(requester: requester)

        case "workflow.resetDemoApproval":
            replaceDefinition(WorkflowCatalog.approvalPipeline())
            updateRunInputText("osascript request: Open Safari and load the HAVEN admin preview.")
            return stateValue(requester: requester)

        case "workflow.run":
            let input = parseRunInput(from: payload) ?? .string(currentRunInputText())
            let result = await WorkflowRunner.run(
                definition: currentDefinition(),
                input: input,
                requester: requester
            )
            stateQueue.sync {
                lastRunState = result
            }
            return stateValue(requester: requester)

        case "workflow.setRunInputText":
            guard let text = extractTextInput(payload) else {
                return .string("error: invalid run input payload")
            }
            updateRunInputText(text)
            return stateValue(requester: requester)

        case "workflow.setSelectedNodeTitle":
            guard let text = extractTextInput(payload) else {
                return .string("error: invalid node title payload")
            }
            updateSelectedNode { node in
                node.title = text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return stateValue(requester: requester)

        case "workflow.setSelectedNodeInstructions":
            guard let text = extractTextInput(payload) else {
                return .string("error: invalid instructions payload")
            }
            updateSelectedNode { node in
                node.note = text
                switch node.kind {
                case .agentCall:
                    node.configuration["systemPrompt"] = .string(text)
                case .note:
                    node.configuration["text"] = .string(text)
                case .approval:
                    node.configuration["message"] = .string(text)
                default:
                    break
                }
            }
            return stateValue(requester: requester)

        case "workflow.setSelectedNodeProvider":
            guard let text = extractTextInput(payload) else {
                return .string("error: invalid provider payload")
            }
            updateSelectedNode { node in
                if node.modelRoute == nil {
                    node.modelRoute = .bindingGatewayPreview
                }
                node.modelRoute?.provider = text
            }
            return stateValue(requester: requester)

        case "workflow.setSelectedNodeModel":
            guard let text = extractTextInput(payload) else {
                return .string("error: invalid model payload")
            }
            updateSelectedNode { node in
                if node.modelRoute == nil {
                    node.modelRoute = .bindingGatewayPreview
                }
                node.modelRoute?.model = text
            }
            return stateValue(requester: requester)

        case "workflow.setSelectedNodeConditionKeypath":
            guard let text = extractTextInput(payload) else {
                return .string("error: invalid condition payload")
            }
            updateSelectedNode { node in
                switch node.kind {
                case .condition:
                    node.configuration["keypath"] = .string(text)
                case .parser:
                    node.configuration["textKey"] = .string(text)
                default:
                    node.configuration["keypath"] = .string(text)
                }
            }
            return stateValue(requester: requester)

        case "workflow.setSelectedNodeTransformStrategy":
            guard let text = extractTextInput(payload) else {
                return .string("error: invalid transform payload")
            }
            updateSelectedNode { node in
                switch node.kind {
                case .transform:
                    node.configuration["strategy"] = .string(text)
                case .parser:
                    node.configuration["mode"] = .string(text)
                default:
                    node.configuration["strategy"] = .string(text)
                }
            }
            return stateValue(requester: requester)

        case "workflow.setSelectedNodePromptTemplate":
            guard let text = extractTextInput(payload) else {
                return .string("error: invalid prompt payload")
            }
            updateSelectedNode { node in
                if node.kind == .agentCall {
                    node.configuration["promptTemplate"] = .string(text)
                } else {
                    node.note = text
                }
            }
            return stateValue(requester: requester)

        case "applyWorkflowDefinition", "workflow.applyDefinition":
            return applyWorkflowDefinition(payload: payload, requester: requester)

        case BindingEditableCellConfigurationContract.applyKeypath:
            return applyEditableConfiguration(payload: payload, requester: requester)

        default:
            return .string("error: unsupported workflow mutation \(key)")
        }
    }

    private func stateValue(requester: Identity) -> ValueType {
        let definition = currentDefinition()
        let validationIssues = WorkflowDefinitionValidation.validate(definition)
        let canEdit = canEdit(for: requester)
        let selectedNode = selectedNodeSnapshot(from: definition)
        let selectedNodeIndex = definition.nodes.firstIndex { $0.id == selectedNode?.id } ?? 0
        let lastRun = currentLastRunState()
        let sourceStatus = canEdit
            ? "Source-backed workflow surface. Porthole edits stay local until Apply writes them back here."
            : "Read-only workflow surface for this requester. You can inspect the workflow and last run, but not mutate it."
        let selectedRouteSummary = selectedNode?.modelRoute.map { "\($0.provider) · \($0.model)" } ?? "Deterministic"

        let stateObject: Object = [
            "definitionName": .string(definition.name),
            "definitionSummary": .string(definition.summary),
            "workflowRevision": .integer(currentWorkflowRevision()),
            "nodeCount": .integer(definition.nodes.count),
            "edgeCount": .integer(definition.edges.count),
            "topologySummary": .string("\(definition.nodes.count) nodes · \(definition.edges.count) edges"),
            "validationSummary": .string(workflowValidationSummary(validationIssues)),
            "validationIssues": .list(validationIssues.map(validationIssueValue)),
            "canEdit": .bool(canEdit),
            "sourceBackedNotice": .string(sourceStatus),
            "runInputText": .string(currentRunInputText()),
            "selectedNodeIndex": .integer(selectedNodeIndex),
            "selectedNodeRouteSummary": .string(selectedRouteSummary),
            "selectedNode": selectedNode.map(selectedNodeValue) ?? .object([:]),
            "nodes": .list(definition.nodes.enumerated().map { index, node in
                .object(nodeRowValue(node, selectedIndex: selectedNodeIndex, currentIndex: index))
            }),
            "edges": .list(definition.edges.map { .object(edgeRowValue($0, definition: definition)) }),
            "palette": .list(WorkflowCatalog.palette().map { .object(paletteRowValue($0)) }),
            "availableRoutes": .list(WorkflowCatalog.availableRoutes().map { route in
                .object([
                    "provider": .string(route.provider),
                    "model": .string(route.model),
                    "endpoint": .string(route.endpoint ?? "")
                ])
            }),
            "lastRun": lastRun.map(lastRunValue) ?? .object([
                "status": .string(WorkflowRunStatus.idle.rawValue),
                "summary": .string("No workflow run has been executed yet."),
                "trace": .list([]),
                "nodeSnapshots": .list([])
            ])
        ]
        return .object(stateObject)
    }

    private func workflowDefinitionStateValue(requester: Identity) -> ValueType {
        .object([
            "definition": WorkflowValueCodec.encode(currentDefinition()) ?? .null,
            "revision": .integer(currentWorkflowRevision()),
            "canEdit": .bool(canEdit(for: requester)),
            "accessSummary": .string(canEdit(for: requester) ? "Writable workflow definition." : "Read-only workflow definition for this requester.")
        ])
    }

    private func editableConfigurationStateValue(requester: Identity) -> ValueType {
        let canEdit = canEdit(for: requester)
        let current = currentConfiguration()
        let fallback = WorkflowStudioCell.workbenchConfiguration()
        let summary = canEdit
            ? "Workflow Studio layout can be edited directly in Porthole and applied back to the source cell."
            : "Workflow Studio layout is read-only for this requester."

        return .object([
            "configuration": .cellConfiguration(current),
            "fallbackConfiguration": .cellConfiguration(fallback),
            "revision": .integer(currentConfigurationRevision()),
            "hasStoredOverride": .bool(true),
            "canEdit": .bool(canEdit),
            "sourceCellEndpoint": .string(Self.endpoint),
            "sourceCellName": .string("WorkflowStudioCell"),
            "accessSummary": .string(summary)
        ])
    }

    private func applyWorkflowDefinition(payload: ValueType, requester: Identity) -> ValueType {
        let currentRevision = currentWorkflowRevision()
        let canEdit = canEdit(for: requester)
        guard canEdit else {
            return workflowDefinitionStateValue(requester: requester)
        }

        guard case let .object(object) = payload,
              let definitionValue = object["definition"] ?? object["workflow"],
              let definition = WorkflowValueCodec.decode(WorkflowDefinition.self, from: definitionValue)
        else {
            return .string("error: invalid workflow definition payload")
        }

        let expectedRevision = WorkflowValueExtraction.integer(object["expectedRevision"])
        if let expectedRevision, expectedRevision != currentRevision {
            return .object([
                "definition": WorkflowValueCodec.encode(currentDefinition()) ?? .null,
                "revision": .integer(currentRevision),
                "canEdit": .bool(true),
                "accessSummary": .string("Workflow definition changed before apply. Reload and try again.")
            ])
        }

        replaceDefinition(definition)
        return workflowDefinitionStateValue(requester: requester)
    }

    private func applyEditableConfiguration(payload: ValueType, requester: Identity) -> ValueType {
        let currentRevision = currentConfigurationRevision()
        guard canEdit(for: requester) else {
            return editableConfigurationStateValue(requester: requester)
        }

        guard case let .object(object) = payload,
              let configurationValue = object["configuration"],
              let configuration = BindingEditableCellConfigurationContract.decodeConfiguration(from: configurationValue)
        else {
            return .string("error: invalid editable configuration payload")
        }

        let expectedRevision = WorkflowValueExtraction.integer(object["expectedRevision"])
        if let expectedRevision, expectedRevision != currentRevision {
            return .object([
                "configuration": .cellConfiguration(currentConfiguration()),
                "fallbackConfiguration": .cellConfiguration(WorkflowStudioCell.workbenchConfiguration()),
                "revision": .integer(currentRevision),
                "hasStoredOverride": .bool(true),
                "canEdit": .bool(true),
                "sourceCellEndpoint": .string(Self.endpoint),
                "sourceCellName": .string("WorkflowStudioCell"),
                "accessSummary": .string("Workflow Studio layout changed before apply. Reload and try again.")
            ])
        }

        stateQueue.sync {
            storedConfiguration = WorkflowStudioCell.normalizedConfiguration(configuration)
            configurationRevision += 1
        }
        return editableConfigurationStateValue(requester: requester)
    }

    private func currentDefinition() -> WorkflowDefinition {
        stateQueue.sync { workflowDefinition }
    }

    private func currentConfiguration() -> CellConfiguration {
        stateQueue.sync { storedConfiguration }
    }

    private func currentWorkflowRevision() -> Int {
        stateQueue.sync { workflowRevision }
    }

    private func currentConfigurationRevision() -> Int {
        stateQueue.sync { configurationRevision }
    }

    private func currentRunInputText() -> String {
        stateQueue.sync { runInputText }
    }

    private func currentLastRunState() -> WorkflowRunState? {
        stateQueue.sync { lastRunState }
    }

    private func canEdit(for requester: Identity) -> Bool {
        requester.uuid == ownerUUID
    }

    private func updateRunInputText(_ text: String) {
        stateQueue.sync {
            runInputText = text
        }
    }

    private func replaceDefinition(_ definition: WorkflowDefinition) {
        stateQueue.sync {
            workflowDefinition = WorkflowStudioCell.normalizedDefinition(definition)
            workflowRevision += 1
            if workflowDefinition.nodes.contains(where: { $0.id == selectedNodeID }) == false {
                selectedNodeID = workflowDefinition.nodes.first?.id
            }
        }
    }

    private func updateSelectedNode(_ mutate: (inout WorkflowNode) -> Void) {
        stateQueue.sync {
            guard let selectedNodeID,
                  let index = workflowDefinition.nodes.firstIndex(where: { $0.id == selectedNodeID }) else {
                return
            }
            mutate(&workflowDefinition.nodes[index])
            workflowDefinition = WorkflowStudioCell.normalizedDefinition(workflowDefinition)
            workflowRevision += 1
        }
    }

    private func selectNode(with payload: ValueType) {
        stateQueue.sync {
            let definition = workflowDefinition
            if let index = Self.selectedIndex(from: payload),
               definition.nodes.indices.contains(index) {
                selectedNodeID = definition.nodes[index].id
                return
            }
            if let identifier = Self.selectedIdentifier(from: payload),
               definition.nodes.contains(where: { $0.id == identifier }) {
                selectedNodeID = identifier
            }
        }
    }

    private func insertNodeAfterSelection(kind: WorkflowNodeKind) {
        stateQueue.sync {
            var definition = workflowDefinition
            let orderedIDs = WorkflowStudioCell.linearNodeIDs(in: definition)
            let selectedID = selectedNodeID ?? orderedIDs.first
            let selectedIndex = orderedIDs.firstIndex(where: { $0 == selectedID }) ?? max(orderedIDs.count - 2, 0)
            let newNode = WorkflowNodeFactory.makeNode(kind: kind)
            definition.nodes.append(newNode)

            let predecessorID = orderedIDs[safe: selectedIndex]
            let successorID = orderedIDs[safe: selectedIndex + 1]
            if let predecessorID,
               let successorID,
               let predecessor = definition.nodes.first(where: { $0.id == predecessorID }),
               let successor = definition.nodes.first(where: { $0.id == successorID }),
               let predecessorPort = WorkflowNodeFactory.primaryOutputPortID(for: predecessor),
               let successorPort = WorkflowNodeFactory.primaryInputPortID(for: successor) {
                definition.edges.removeAll {
                    $0.fromNodeID == predecessorID && $0.toNodeID == successorID
                }
                if let newInputPort = WorkflowNodeFactory.primaryInputPortID(for: newNode),
                   let newOutputPort = WorkflowNodeFactory.primaryOutputPortID(for: newNode) {
                    definition.edges.append(
                        WorkflowEdge(
                            id: UUID().uuidString,
                            fromNodeID: predecessorID,
                            fromPortID: predecessorPort,
                            toNodeID: newNode.id,
                            toPortID: newInputPort,
                            label: nil
                        )
                    )
                    definition.edges.append(
                        WorkflowEdge(
                            id: UUID().uuidString,
                            fromNodeID: newNode.id,
                            fromPortID: newOutputPort,
                            toNodeID: successorID,
                            toPortID: successorPort,
                            label: nil
                        )
                    )
                }
            }
            workflowDefinition = WorkflowStudioCell.normalizedDefinition(definition)
            selectedNodeID = newNode.id
            workflowRevision += 1
        }
    }

    private func removeSelectedNode() {
        stateQueue.sync {
            guard let selectedNodeID,
                  let selectedNode = workflowDefinition.nodes.first(where: { $0.id == selectedNodeID }),
                  selectedNode.kind != .start,
                  selectedNode.kind != .end else {
                return
            }

            let incoming = workflowDefinition.edges.filter { $0.toNodeID == selectedNodeID }
            let outgoing = workflowDefinition.edges.filter { $0.fromNodeID == selectedNodeID }
            workflowDefinition.nodes.removeAll { $0.id == selectedNodeID }
            workflowDefinition.edges.removeAll { $0.toNodeID == selectedNodeID || $0.fromNodeID == selectedNodeID }

            if let predecessorEdge = incoming.first,
               let successorEdge = outgoing.first,
               let predecessor = workflowDefinition.nodes.first(where: { $0.id == predecessorEdge.fromNodeID }),
               let successor = workflowDefinition.nodes.first(where: { $0.id == successorEdge.toNodeID }),
               let predecessorPort = WorkflowNodeFactory.primaryOutputPortID(for: predecessor),
               let successorPort = WorkflowNodeFactory.primaryInputPortID(for: successor) {
                workflowDefinition.edges.append(
                    WorkflowEdge(
                        id: UUID().uuidString,
                        fromNodeID: predecessor.id,
                        fromPortID: predecessorPort,
                        toNodeID: successor.id,
                        toPortID: successorPort,
                        label: nil
                    )
                )
            }

            workflowDefinition = WorkflowStudioCell.normalizedDefinition(workflowDefinition)
            self.selectedNodeID = workflowDefinition.nodes.first?.id
            workflowRevision += 1
        }
    }

    private func selectedNodeSnapshot(from definition: WorkflowDefinition) -> WorkflowNode? {
        let selectedID = stateQueue.sync { selectedNodeID }
        return definition.nodes.first(where: { $0.id == selectedID }) ?? definition.nodes.first
    }

    private static func selectedIndex(from payload: ValueType) -> Int? {
        switch payload {
        case .integer(let index):
            return index
        case .number(let index):
            return index
        case .object(let object):
            if let direct = WorkflowValueExtraction.integer(object["selectedIndex"]) {
                return direct
            }
            if let direct = WorkflowValueExtraction.integer(object["index"]) {
                return direct
            }
            if case let .object(selected)? = object["selected"] {
                return WorkflowValueExtraction.integer(selected["index"])
            }
            return nil
        default:
            return nil
        }
    }

    private static func selectedIdentifier(from payload: ValueType) -> String? {
        switch payload {
        case .string(let string):
            return string
        case .object(let object):
            if let direct = WorkflowValueExtraction.nonEmptyString(object["id"]) {
                return direct
            }
            if case let .object(selected)? = object["selected"] {
                return WorkflowValueExtraction.nonEmptyString(selected["id"])
            }
            return nil
        default:
            return nil
        }
    }

    private func parseNodeKind(from payload: ValueType) -> WorkflowNodeKind? {
        let raw = WorkflowValueExtraction.nonEmptyString(payload)
            ?? {
                if case let .object(object) = payload {
                    return WorkflowValueExtraction.nonEmptyString(object["kind"])
                }
                return nil
            }()
        return raw.flatMap { WorkflowNodeKind(rawValue: $0) }
    }

    private func parseRunInput(from payload: ValueType) -> ValueType? {
        switch payload {
        case .string:
            return payload
        case .object(let object):
            if let text = WorkflowValueExtraction.nonEmptyString(object["value"]) ?? WorkflowValueExtraction.nonEmptyString(object["text"]) {
                return .string(text)
            }
            return .object(object)
        case .null:
            return nil
        default:
            return payload
        }
    }

    private func extractTextInput(_ payload: ValueType) -> String? {
        switch payload {
        case .string(let value):
            return value
        case .object(let object):
            return WorkflowValueExtraction.nonEmptyString(object["value"])
                ?? WorkflowValueExtraction.nonEmptyString(object["text"])
        default:
            return nil
        }
    }

    private func workflowValidationSummary(_ issues: [WorkflowValidationIssue]) -> String {
        let errors = issues.filter { $0.severity == .error }.count
        let warnings = issues.filter { $0.severity == .warning }.count
        if errors == 0 && warnings == 0 {
            return "Definition is valid and ready for a first run."
        }
        return "\(errors) errors, \(warnings) warnings"
    }

    private func validationIssueValue(_ issue: WorkflowValidationIssue) -> ValueType {
        .object([
            "severity": .string(issue.severity.rawValue),
            "message": .string(issue.message),
            "nodeID": .string(issue.nodeID ?? ""),
            "edgeID": .string(issue.edgeID ?? "")
        ])
    }

    private func nodeRowValue(_ node: WorkflowNode, selectedIndex: Int, currentIndex: Int) -> Object {
        [
            "id": .string(node.id),
            "index": .integer(currentIndex),
            "title": .string(node.title),
            "kind": .string(node.kind.displayName),
            "selectionBadge": .string(currentIndex == selectedIndex ? "Selected" : ""),
            "portSummary": .string("\(node.inputPorts.count) in · \(node.outputPorts.count) out"),
            "routeSummary": .string(node.modelRoute.map { "\($0.provider) · \($0.model)" } ?? "Deterministic"),
            "positionSummary": .string("x=\(Int(node.position.x)) y=\(Int(node.position.y))"),
            "note": .string(node.note ?? "")
        ]
    }

    private func edgeRowValue(_ edge: WorkflowEdge, definition: WorkflowDefinition) -> Object {
        let from = definition.nodes.first(where: { $0.id == edge.fromNodeID })?.title ?? edge.fromNodeID
        let to = definition.nodes.first(where: { $0.id == edge.toNodeID })?.title ?? edge.toNodeID
        return [
            "id": .string(edge.id),
            "from": .string(from),
            "to": .string(to),
            "portSummary": .string("\(edge.fromPortID) -> \(edge.toPortID)")
        ]
    }

    private func paletteRowValue(_ item: WorkflowPaletteItem) -> Object {
        [
            "id": .string(item.kind.rawValue),
            "title": .string(item.title),
            "summary": .string(item.summary),
            "providerHint": .string(item.providerHint ?? "")
        ]
    }

    private func selectedNodeValue(_ node: WorkflowNode) -> ValueType {
        .object([
            "id": .string(node.id),
            "title": .string(node.title),
            "kind": .string(node.kind.displayName),
            "instructions": .string(
                WorkflowValueExtraction.nonEmptyString(node.configuration["systemPrompt"])
                    ?? WorkflowValueExtraction.nonEmptyString(node.configuration["text"])
                    ?? WorkflowValueExtraction.nonEmptyString(node.configuration["message"])
                    ?? node.note
                    ?? ""
            ),
            "provider": .string(node.modelRoute?.provider ?? ""),
            "model": .string(node.modelRoute?.model ?? ""),
            "routeSummary": .string(node.modelRoute.map { "\($0.provider) · \($0.model)" } ?? "Deterministic"),
            "conditionKeypath": .string(
                WorkflowValueExtraction.nonEmptyString(node.configuration["keypath"])
                    ?? WorkflowValueExtraction.nonEmptyString(node.configuration["textKey"])
                    ?? ""
            ),
            "transformStrategy": .string(
                WorkflowValueExtraction.nonEmptyString(node.configuration["strategy"])
                    ?? WorkflowValueExtraction.nonEmptyString(node.configuration["mode"])
                    ?? ""
            ),
            "promptTemplate": .string(
                WorkflowValueExtraction.nonEmptyString(node.configuration["promptTemplate"])
                    ?? node.note
                    ?? ""
            ),
            "note": .string(node.note ?? ""),
            "portSummary": .string("\(node.inputPorts.count) in · \(node.outputPorts.count) out")
        ])
    }

    private func lastRunValue(_ run: WorkflowRunState) -> ValueType {
        .object([
            "status": .string(run.status.rawValue),
            "summary": .string(run.resultSummary),
            "inputPreview": .string(run.inputPreview),
            "errorMessage": .string(run.errorMessage ?? ""),
            "finalOutput": .string(run.finalOutput.map(renderPreview) ?? ""),
            "trace": .list(run.trace.map { .object(["title": .string($0), "detail": .string("")]) }),
            "nodeSnapshots": .list(run.nodeSnapshots.map { snapshot in
                .object([
                    "title": .string(snapshot.nodeTitle),
                    "detail": .string(snapshot.status.rawValue),
                    "route": .string(snapshot.routeSummary),
                    "inputPreview": .string(snapshot.inputPreview),
                    "outputPreview": .string(snapshot.outputPreview)
                ])
            })
        ])
    }

    private static func normalizedDefinition(_ definition: WorkflowDefinition) -> WorkflowDefinition {
        var normalized = definition
        normalized.nodes = linearNodeIDs(in: normalized).compactMap { id in
            normalized.nodes.first(where: { $0.id == id })
        }.enumerated().map { index, node in
            var updated = node
            updated.position = WorkflowNodePosition(x: Double(index * 220), y: 0)
            return updated
        }
        if normalized.nodes.isEmpty {
            normalized = WorkflowCatalog.documentPipeline()
        }
        return normalized
    }

    private static func normalizedConfiguration(_ configuration: CellConfiguration) -> CellConfiguration {
        var normalized = configuration
        normalized.name = normalized.name.isEmpty ? "Workflow Studio" : normalized.name
        normalized.description = normalized.description ?? "Cell-native workflow studio for agents, parsers, transforms, approvals, and deterministic state updates."
        normalized.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: endpoint,
            sourceCellName: "WorkflowStudioCell",
            purpose: "Workflow authoring",
            purposeDescription: "Build typed pipelines with agents, parsers, transforms, approvals, and source-backed publishing.",
            interests: ["workflow", "agents", "parsers", "transforms", "approval", "automation"],
            menuSlots: ["upperMid", "lowerMid"]
        )

        var references = normalized.cellReferences ?? []
        if references.contains(where: { $0.label == sourceLabel }) == false {
            references.append(CellReference(endpoint: endpoint, label: sourceLabel))
        } else {
            references = references.map { reference in
                var updated = reference
                if updated.label == sourceLabel {
                    updated.endpoint = endpoint
                    updated.subscribeFeed = true
                }
                return updated
            }
        }
        normalized.cellReferences = references
        if normalized.skeleton == nil {
            normalized.skeleton = workbenchConfiguration().skeleton
        }
        return normalized
    }

    private static func linearNodeIDs(in definition: WorkflowDefinition) -> [String] {
        guard let start = definition.nodes.first(where: { $0.kind == .start }) else {
            return definition.nodes.map(\.id)
        }
        var ordered: [String] = [start.id]
        var visited: Set<String> = [start.id]
        var cursor = start.id

        while let nextEdge = definition.edges.first(where: { $0.fromNodeID == cursor }),
              visited.contains(nextEdge.toNodeID) == false {
            ordered.append(nextEdge.toNodeID)
            visited.insert(nextEdge.toNodeID)
            cursor = nextEdge.toNodeID
        }

        definition.nodes.map(\.id).forEach {
            if visited.contains($0) == false {
                ordered.append($0)
            }
        }
        return ordered
    }

    static func workbenchConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Workflow Studio")
        configuration.description = "Cell-native workflow authoring for typed agent pipelines, deterministic parser cells, transform cells, and approvals."
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: endpoint,
            sourceCellName: "WorkflowStudioCell",
            purpose: "Workflow authoring",
            purposeDescription: "Build source-backed workflows with typed nodes, port validation, model routing, and deterministic parser/transform steps.",
            interests: ["workflow", "agents", "transforms", "parsers", "approval", "automation"],
            menuSlots: ["upperMid", "lowerMid"]
        )

        var studioReference = CellReference(endpoint: endpoint, label: sourceLabel)
        studioReference.subscribeFeed = true
        configuration.addReference(studioReference)
        configuration.skeleton = workflowSkeleton()
        return configuration
    }

    static func menuConfiguration() -> CellConfiguration {
        var configuration = workbenchConfiguration()
        configuration.name = "Workflow Studio"
        configuration.description = "Typed graph authoring for agent pipelines, parsers, transforms, approvals, and source-backed runtime state."
        return configuration
    }

    static func portableConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Workflow Remote")
        configuration.description = "Phone-friendly workflow control surface for reviewing, tweaking, and running typed pipelines from Porthole."
        configuration.discovery = CellConfigurationDiscovery(
            purpose: "Portable workflow control",
            purposeDescription: "Operate and lightly edit workflows from a compact remote surface when you are away from the laptop.",
            interests: ["workflow", "remote", "mobile", "agents", "automation"],
            menuSlots: ["upperMid", "lowerMid", "lowerRight"]
        )

        var studioReference = CellReference(endpoint: endpoint, label: sourceLabel)
        studioReference.subscribeFeed = true
        configuration.addReference(studioReference)
        configuration.skeleton = portableSkeleton()
        return configuration
    }

    static func portableMenuConfiguration() -> CellConfiguration {
        var configuration = portableConfiguration()
        configuration.name = "Workflow Remote"
        configuration.description = "Compact remote workflow surface for phone-sized Porthole sessions."
        return configuration
    }

    private static func workflowSkeleton() -> SkeletonElement {
        let title = styledText(text: "Workflow Studio", fontStyle: "title2", weight: "semibold", color: "#0F172A")
        let subtitle = styledText(
            keypath: "\(sourceLabel).state.definitionSummary",
            color: "#334155",
            size: 13
        )
        let validation = styledText(
            keypath: "\(sourceLabel).state.validationSummary",
            weight: "semibold",
            color: "#1D4ED8",
            size: 12
        )
        let sourceNotice = styledText(
            keypath: "\(sourceLabel).state.sourceBackedNotice",
            color: "#475569",
            size: 12
        )

        var hero = SkeletonVStack(elements: [
            .Text(title),
            .Text(subtitle),
            .Text(validation),
            .Text(sourceNotice)
        ])
        hero.modifiers = modifier {
            $0.padding = 14
            $0.background = "#F8FAFC"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        let documentButton = studioButton(
            keypath: "\(sourceLabel).workflow.resetDemoDocument",
            label: "Doc demo",
            payload: .null,
            background: "#DBEAFE",
            border: "#2563EB"
        )
        let researchButton = studioButton(
            keypath: "\(sourceLabel).workflow.resetDemoResearch",
            label: "Research demo",
            payload: .null,
            background: "#E0F2FE",
            border: "#0891B2"
        )
        let approvalButton = studioButton(
            keypath: "\(sourceLabel).workflow.resetDemoApproval",
            label: "Approval demo",
            payload: .null,
            background: "#FEF3C7",
            border: "#D97706"
        )
        let runButton = studioButton(
            keypath: "\(sourceLabel).workflow.run",
            label: "Run workflow",
            payload: .null,
            background: "#DCFCE7",
            border: "#16A34A"
        )

        let addParser = studioButton(
            keypath: "\(sourceLabel).workflow.insertNodeAfterSelected",
            label: "Add parser",
            payload: .object(["kind": .string(WorkflowNodeKind.parser.rawValue)]),
            background: "#EDE9FE",
            border: "#7C3AED"
        )
        let addTransform = studioButton(
            keypath: "\(sourceLabel).workflow.insertNodeAfterSelected",
            label: "Add transform",
            payload: .object(["kind": .string(WorkflowNodeKind.transform.rawValue)]),
            background: "#FCE7F3",
            border: "#DB2777"
        )
        let addAgent = studioButton(
            keypath: "\(sourceLabel).workflow.insertNodeAfterSelected",
            label: "Add agent",
            payload: .object(["kind": .string(WorkflowNodeKind.agentCall.rawValue)]),
            background: "#E0F2FE",
            border: "#0284C7"
        )
        let removeSelected = studioButton(
            keypath: "\(sourceLabel).workflow.removeSelectedNode",
            label: "Remove selected",
            payload: .null,
            background: "#FEE2E2",
            border: "#DC2626"
        )

        let runInput = SkeletonTextArea(
            text: nil,
            sourceKeypath: "\(sourceLabel).state.runInputText",
            targetKeypath: "\(sourceLabel).workflow.setRunInputText",
            placeholder: "Describe the document, company, or side effect the workflow should process.",
            minLines: 4,
            maxLines: 8,
            submitOnEnter: false,
            modifiers: modifier {
                $0.padding = 10
                $0.background = "#FFFFFF"
                $0.cornerRadius = 12
                $0.borderWidth = 1
                $0.borderColor = "#CBD5E1"
                $0.foregroundColor = "#0F172A"
            }
        )

        var nodeTitle = inspectorField(
            sourceKeypath: "\(sourceLabel).state.selectedNode.title",
            targetKeypath: "\(sourceLabel).workflow.setSelectedNodeTitle",
            placeholder: "Selected node title"
        )
        var nodeInstructions = inspectorArea(
            sourceKeypath: "\(sourceLabel).state.selectedNode.instructions",
            targetKeypath: "\(sourceLabel).workflow.setSelectedNodeInstructions",
            placeholder: "Instructions, system prompt, note, or approval message",
            minLines: 3,
            maxLines: 6
        )
        var nodeProvider = inspectorField(
            sourceKeypath: "\(sourceLabel).state.selectedNode.provider",
            targetKeypath: "\(sourceLabel).workflow.setSelectedNodeProvider",
            placeholder: "Provider"
        )
        var nodeModel = inspectorField(
            sourceKeypath: "\(sourceLabel).state.selectedNode.model",
            targetKeypath: "\(sourceLabel).workflow.setSelectedNodeModel",
            placeholder: "Model"
        )
        let nodeCondition = inspectorField(
            sourceKeypath: "\(sourceLabel).state.selectedNode.conditionKeypath",
            targetKeypath: "\(sourceLabel).workflow.setSelectedNodeConditionKeypath",
            placeholder: "Condition keypath / parser text key"
        )
        let nodeStrategy = inspectorField(
            sourceKeypath: "\(sourceLabel).state.selectedNode.transformStrategy",
            targetKeypath: "\(sourceLabel).workflow.setSelectedNodeTransformStrategy",
            placeholder: "Transform strategy / parser mode"
        )
        let nodePrompt = inspectorArea(
            sourceKeypath: "\(sourceLabel).state.selectedNode.promptTemplate",
            targetKeypath: "\(sourceLabel).workflow.setSelectedNodePromptTemplate",
            placeholder: "Prompt template or note",
            minLines: 3,
            maxLines: 6
        )

        var nodeRow = SkeletonVStack(elements: [
            .Text(styledText(keypath: "selectionBadge", weight: "semibold", color: "#2563EB", size: 11)),
            .Text(styledText(keypath: "title", weight: "semibold", color: "#0F172A", size: 15)),
            .Text(styledText(keypath: "kind", color: "#334155", size: 12)),
            .Text(styledText(keypath: "portSummary", color: "#475569", size: 12)),
            .Text(styledText(keypath: "routeSummary", color: "#1D4ED8", size: 11)),
            .Text(styledText(keypath: "positionSummary", color: "#64748B", size: 11))
        ])
        nodeRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        var nodesList = SkeletonList(
            topic: nil,
            keypath: "\(sourceLabel).state.nodes",
            flowElementSkeleton: nodeRow
        )
        nodesList.selectionMode = SkeletonListSelectionMode.single
        nodesList.selectionPayloadMode = SkeletonListSelectionPayloadMode.item
        nodesList.selectionStateKeypath = "\(sourceLabel).state.selectedNodeIndex"
        nodesList.selectionActionKeypath = "\(sourceLabel).workflow.selectNode"
        nodesList.activationActionKeypath = "\(sourceLabel).workflow.selectNode"
        nodesList.modifiers = modifier {
            $0.padding = 6
            $0.background = "#F8FAFC"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        var edgeRow = SkeletonVStack(elements: [
            .Text(styledText(keypath: "from", weight: "semibold", color: "#0F172A", size: 14)),
            .Text(styledText(keypath: "to", color: "#334155", size: 12)),
            .Text(styledText(keypath: "portSummary", color: "#64748B", size: 11))
        ])
        edgeRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#E2E8F0"
        }

        var edgesList = SkeletonList(
            topic: nil,
            keypath: "\(sourceLabel).state.edges",
            flowElementSkeleton: edgeRow
        )
        edgesList.modifiers = modifier {
            $0.padding = 6
            $0.background = "#F8FAFC"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        var validationRow = SkeletonVStack(elements: [
            .Text(styledText(keypath: "severity", weight: "semibold", color: "#991B1B", size: 11)),
            .Text(styledText(keypath: "message", color: "#334155", size: 12))
        ])
        validationRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FFF7ED"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#FDBA74"
        }

        var validationList = SkeletonList(
            topic: nil,
            keypath: "\(sourceLabel).state.validationIssues",
            flowElementSkeleton: validationRow
        )
        validationList.modifiers = modifier {
            $0.padding = 6
            $0.background = "#FFF7ED"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = "#FDBA74"
        }

        var traceRow = SkeletonVStack(elements: [
            .Text(styledText(keypath: "title", weight: "semibold", color: "#0F172A", size: 13)),
            .Text(styledText(keypath: "detail", color: "#64748B", size: 11))
        ])
        traceRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#E2E8F0"
        }

        var traceList = SkeletonList(
            topic: nil,
            keypath: "\(sourceLabel).state.lastRun.trace",
            flowElementSkeleton: traceRow
        )
        traceList.modifiers = modifier {
            $0.padding = 6
            $0.background = "#F8FAFC"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        var snapshotRow = SkeletonVStack(elements: [
            .Text(styledText(keypath: "title", weight: "semibold", color: "#0F172A", size: 13)),
            .Text(styledText(keypath: "detail", color: "#334155", size: 11)),
            .Text(styledText(keypath: "route", color: "#1D4ED8", size: 11)),
            .Text(styledText(keypath: "outputPreview", color: "#64748B", size: 11))
        ])
        snapshotRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#E2E8F0"
        }

        var snapshotsList = SkeletonList(
            topic: nil,
            keypath: "\(sourceLabel).state.lastRun.nodeSnapshots",
            flowElementSkeleton: snapshotRow
        )
        snapshotsList.modifiers = modifier {
            $0.padding = 6
            $0.background = "#F8FAFC"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        let runStatus = styledText(keypath: "\(sourceLabel).state.lastRun.status", weight: "semibold", color: "#047857", size: 12)
        let runSummary = styledText(keypath: "\(sourceLabel).state.lastRun.summary", color: "#334155", size: 12)
        let finalOutput = styledText(keypath: "\(sourceLabel).state.lastRun.finalOutput", color: "#0F172A", size: 12)

        var root = SkeletonVStack(elements: [
            .VStack(hero),
            .Section(
                SkeletonSection(
                    header: .Text(styledText(text: "Workflow setup", fontStyle: "headline", weight: "semibold", color: "#0F172A")),
                    footer: .Text(styledText(text: "The workflow definition is cell-native. The layout is source-backed and can be edited directly in Porthole.", color: "#64748B", size: 11)),
                    content: [
                        .HStack(SkeletonHStack(elements: [documentButton, researchButton, approvalButton, runButton])),
                        .TextArea(runInput),
                        .HStack(SkeletonHStack(elements: [addParser, addTransform, addAgent, removeSelected]))
                    ]
                )
            ),
            .Section(
                SkeletonSection(
                    header: .Text(styledText(text: "Node map", fontStyle: "headline", weight: "semibold", color: "#0F172A")),
                    footer: .Text(styledText(text: "Select a node to inspect and update its title, route, prompt, parser mode, or condition keypath.", color: "#64748B", size: 11)),
                    content: [.List(nodesList)]
                )
            ),
            .Section(
                SkeletonSection(
                    header: .Text(styledText(text: "Inspector", fontStyle: "headline", weight: "semibold", color: "#0F172A")),
                    footer: .Text(styledText(keypath: "\(sourceLabel).state.selectedNode.portSummary", color: "#64748B", size: 11)),
                    content: [
                        nodeTitle,
                        nodeInstructions,
                        .HStack(SkeletonHStack(elements: [nodeProvider, nodeModel])),
                        .HStack(SkeletonHStack(elements: [nodeCondition, nodeStrategy])),
                        nodePrompt
                    ]
                )
            ),
            .Section(
                SkeletonSection(
                    header: .Text(styledText(text: "Edges and validation", fontStyle: "headline", weight: "semibold", color: "#0F172A")),
                    footer: .Text(styledText(text: "Port compatibility is validated from the typed node definitions. Parser and transform nodes stay deterministic.", color: "#64748B", size: 11)),
                    content: [
                        .List(edgesList),
                        .List(validationList)
                    ]
                )
            ),
            .Section(
                SkeletonSection(
                    header: .Text(styledText(text: "Run and debug", fontStyle: "headline", weight: "semibold", color: "#0F172A")),
                    footer: .Text(styledText(text: "V1 stores a resumable run snapshot with node-level status, output preview, and trace messages.", color: "#64748B", size: 11)),
                    content: [
                        .Text(runStatus),
                        .Text(runSummary),
                        .Text(finalOutput),
                        .List(traceList),
                        .List(snapshotsList)
                    ]
                )
            )
        ])
        root.modifiers = modifier {
            $0.padding = 16
            $0.background = "#FFFFFF"
        }
        return .ScrollView(
            SkeletonScrollView(axis: "vertical", elements: [.VStack(root)])
        )
    }

    private static func portableSkeleton() -> SkeletonElement {
        let title = styledText(text: "Workflow Remote", fontStyle: "title3", weight: "semibold", color: "#0F172A")
        let summary = styledText(keypath: "\(sourceLabel).state.definitionSummary", color: "#334155", size: 12)
        let counts = styledText(
            keypath: "\(sourceLabel).state.topologySummary",
            color: "#1D4ED8",
            size: 11
        )
        let sourceNotice = styledText(keypath: "\(sourceLabel).state.sourceBackedNotice", color: "#64748B", size: 11)

        var hero = SkeletonVStack(elements: [
            .Text(title),
            .Text(summary),
            .Text(counts),
            .Text(sourceNotice)
        ])
        hero.modifiers = modifier {
            $0.padding = 12
            $0.background = "#F8FAFC"
            $0.cornerRadius = 16
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        let documentButton = studioButton(
            keypath: "\(sourceLabel).workflow.resetDemoDocument",
            label: "Doc demo",
            payload: .null,
            background: "#DBEAFE",
            border: "#2563EB"
        )
        let researchButton = studioButton(
            keypath: "\(sourceLabel).workflow.resetDemoResearch",
            label: "Research demo",
            payload: .null,
            background: "#E0F2FE",
            border: "#0891B2"
        )
        let approvalButton = studioButton(
            keypath: "\(sourceLabel).workflow.resetDemoApproval",
            label: "Approval demo",
            payload: .null,
            background: "#FEF3C7",
            border: "#D97706"
        )
        let runButton = studioButton(
            keypath: "\(sourceLabel).workflow.run",
            label: "Run now",
            payload: .null,
            background: "#DCFCE7",
            border: "#16A34A"
        )

        let runInput = SkeletonTextArea(
            text: nil,
            sourceKeypath: "\(sourceLabel).state.runInputText",
            targetKeypath: "\(sourceLabel).workflow.setRunInputText",
            placeholder: "What should the workflow process or do?",
            minLines: 3,
            maxLines: 6,
            submitOnEnter: false,
            modifiers: modifier {
                $0.padding = 10
                $0.background = "#FFFFFF"
                $0.cornerRadius = 12
                $0.borderWidth = 1
                $0.borderColor = "#CBD5E1"
                $0.foregroundColor = "#0F172A"
            }
        )

        var nodeRow = SkeletonVStack(elements: [
            .Text(styledText(keypath: "selectionBadge", weight: "semibold", color: "#2563EB", size: 10)),
            .Text(styledText(keypath: "title", weight: "semibold", color: "#0F172A", size: 14)),
            .Text(styledText(keypath: "kind", color: "#334155", size: 11)),
            .Text(styledText(keypath: "routeSummary", color: "#1D4ED8", size: 10))
        ])
        nodeRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        var nodesList = SkeletonList(
            topic: nil,
            keypath: "\(sourceLabel).state.nodes",
            flowElementSkeleton: nodeRow
        )
        nodesList.selectionMode = SkeletonListSelectionMode.single
        nodesList.selectionPayloadMode = SkeletonListSelectionPayloadMode.item
        nodesList.selectionStateKeypath = "\(sourceLabel).state.selectedNodeIndex"
        nodesList.selectionActionKeypath = "\(sourceLabel).workflow.selectNode"
        nodesList.activationActionKeypath = "\(sourceLabel).workflow.selectNode"
        nodesList.modifiers = modifier {
            $0.padding = 6
            $0.background = "#F8FAFC"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
            $0.height = 220
        }

        let nodeTitle = inspectorField(
            sourceKeypath: "\(sourceLabel).state.selectedNode.title",
            targetKeypath: "\(sourceLabel).workflow.setSelectedNodeTitle",
            placeholder: "Node title"
        )
        let nodeInstructions = inspectorArea(
            sourceKeypath: "\(sourceLabel).state.selectedNode.instructions",
            targetKeypath: "\(sourceLabel).workflow.setSelectedNodeInstructions",
            placeholder: "Instructions or note",
            minLines: 3,
            maxLines: 5
        )
        let nodeProvider = inspectorField(
            sourceKeypath: "\(sourceLabel).state.selectedNode.provider",
            targetKeypath: "\(sourceLabel).workflow.setSelectedNodeProvider",
            placeholder: "Provider"
        )
        let nodeModel = inspectorField(
            sourceKeypath: "\(sourceLabel).state.selectedNode.model",
            targetKeypath: "\(sourceLabel).workflow.setSelectedNodeModel",
            placeholder: "Model"
        )

        var snapshotRow = SkeletonVStack(elements: [
            .Text(styledText(keypath: "title", weight: "semibold", color: "#0F172A", size: 12)),
            .Text(styledText(keypath: "detail", color: "#334155", size: 10)),
            .Text(styledText(keypath: "outputPreview", color: "#64748B", size: 10))
        ])
        snapshotRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#E2E8F0"
        }

        var snapshotsList = SkeletonList(
            topic: nil,
            keypath: "\(sourceLabel).state.lastRun.nodeSnapshots",
            flowElementSkeleton: snapshotRow
        )
        snapshotsList.modifiers = modifier {
            $0.padding = 6
            $0.background = "#F8FAFC"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
            $0.height = 220
        }

        let runStatus = styledText(keypath: "\(sourceLabel).state.lastRun.status", weight: "semibold", color: "#047857", size: 12)
        let runSummary = styledText(keypath: "\(sourceLabel).state.lastRun.summary", color: "#334155", size: 11)
        let finalOutput = styledText(keypath: "\(sourceLabel).state.lastRun.finalOutput", color: "#0F172A", size: 11)

        var root = SkeletonVStack(elements: [
            .VStack(hero),
            .Section(
                SkeletonSection(
                    header: .Text(styledText(text: "Quick actions", fontStyle: "headline", weight: "semibold", color: "#0F172A")),
                    footer: .Text(styledText(text: "Choose a seeded flow, tweak the input, and run it directly from Porthole on the phone.", color: "#64748B", size: 11)),
                    content: [
                        .HStack(SkeletonHStack(elements: [documentButton, researchButton])),
                        .HStack(SkeletonHStack(elements: [approvalButton, runButton])),
                        .TextArea(runInput)
                    ]
                )
            ),
            .Section(
                SkeletonSection(
                    header: .Text(styledText(text: "Selected node", fontStyle: "headline", weight: "semibold", color: "#0F172A")),
                    footer: .Text(styledText(keypath: "\(sourceLabel).state.selectedNodeRouteSummary", color: "#64748B", size: 11)),
                    content: [
                        .List(nodesList),
                        nodeTitle,
                        nodeInstructions,
                        .HStack(SkeletonHStack(elements: [nodeProvider, nodeModel]))
                    ]
                )
            ),
            .Section(
                SkeletonSection(
                    header: .Text(styledText(text: "Last run", fontStyle: "headline", weight: "semibold", color: "#0F172A")),
                    footer: .Text(styledText(text: "This compact remote surface keeps the node trace readable on smaller screens.", color: "#64748B", size: 11)),
                    content: [
                        .Text(runStatus),
                        .Text(runSummary),
                        .Text(finalOutput),
                        .List(snapshotsList)
                    ]
                )
            )
        ])
        root.modifiers = modifier {
            $0.padding = 14
            $0.background = "#FFFFFF"
        }
        return .ScrollView(SkeletonScrollView(axis: "vertical", elements: [.VStack(root)]))
    }

    private static func styledText(
        text: String? = nil,
        keypath: String? = nil,
        fontStyle: String? = nil,
        weight: String? = nil,
        color: String,
        size: Double? = nil
    ) -> SkeletonText {
        var value: SkeletonText
        if let text {
            value = SkeletonText(text: text)
        } else if let keypath {
            value = SkeletonText(keypath: keypath)
        } else {
            value = SkeletonText(text: "")
        }
        value.modifiers = modifier {
            $0.foregroundColor = color
            if let fontStyle {
                $0.fontStyle = fontStyle
            }
            if let weight {
                $0.fontWeight = weight
            }
            if let size {
                $0.fontSize = size
            }
        }
        return value
    }

    nonisolated private static func modifier(_ configure: (inout SkeletonModifiers) -> Void) -> SkeletonModifiers {
        var modifiers = SkeletonModifiers()
        configure(&modifiers)
        return modifiers
    }

    private static func studioButton(
        keypath: String,
        label: String,
        payload: ValueType,
        background: String,
        border: String
    ) -> SkeletonElement {
        var button = SkeletonButton(keypath: keypath, label: label, payload: payload)
        button.modifiers = modifier {
            $0.padding = 10
            $0.background = background
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = border
        }
        return .Button(button)
    }

    private static func inspectorField(
        sourceKeypath: String,
        targetKeypath: String,
        placeholder: String
    ) -> SkeletonElement {
        .TextField(
            SkeletonTextField(
                text: nil,
                sourceKeypath: sourceKeypath,
                targetKeypath: targetKeypath,
                placeholder: placeholder,
                modifiers: modifier {
                    $0.padding = 8
                    $0.background = "#FFFFFF"
                    $0.cornerRadius = 10
                    $0.borderWidth = 1
                    $0.borderColor = "#CBD5E1"
                    $0.foregroundColor = "#0F172A"
                }
            )
        )
    }

    private static func inspectorArea(
        sourceKeypath: String,
        targetKeypath: String,
        placeholder: String,
        minLines: Int,
        maxLines: Int
    ) -> SkeletonElement {
        .TextArea(
            SkeletonTextArea(
                text: nil,
                sourceKeypath: sourceKeypath,
                targetKeypath: targetKeypath,
                placeholder: placeholder,
                minLines: minLines,
                maxLines: maxLines,
                submitOnEnter: false,
                modifiers: modifier {
                    $0.padding = 8
                    $0.background = "#FFFFFF"
                    $0.cornerRadius = 10
                    $0.borderWidth = 1
                    $0.borderColor = "#CBD5E1"
                    $0.foregroundColor = "#0F172A"
                }
            )
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
