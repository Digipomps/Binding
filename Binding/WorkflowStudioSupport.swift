import Foundation
import CellBase

enum WorkflowPortDirection: String, Codable, CaseIterable, Sendable {
    case input
    case output
}

enum WorkflowPortValueKind: String, Codable, CaseIterable, Sendable {
    case any
    case trigger
    case text
    case number
    case boolean
    case object
    case list
    case document
    case approval
    case statePatch

    func isCompatible(with other: WorkflowPortValueKind) -> Bool {
        if self == .any || other == .any {
            return true
        }
        if self == other {
            return true
        }
        let compatiblePairs: Set<[WorkflowPortValueKind]> = [
            [.text, .document],
            [.document, .text],
            [.object, .statePatch],
            [.statePatch, .object]
        ]
        return compatiblePairs.contains([self, other])
    }
}

enum WorkflowNodeKind: String, Codable, CaseIterable, Sendable {
    case start = "Start"
    case agentCall = "AgentCall"
    case parser = "Parser"
    case transform = "Transform"
    case condition = "Condition"
    case loop = "Loop"
    case approval = "Approval"
    case setState = "SetState"
    case end = "End"
    case note = "Note"

    var displayName: String { rawValue }
}

struct WorkflowPortSpec: Codable, Sendable {
    var id: String
    var label: String
    var direction: WorkflowPortDirection
    var valueKind: WorkflowPortValueKind
    var isRequired: Bool
    var summary: String?
}

struct WorkflowSchemaField: Codable, Sendable {
    var key: String
    var label: String
    var valueKind: WorkflowPortValueKind
    var isRequired: Bool
    var helpText: String?
}

struct WorkflowNodePosition: Codable, Sendable {
    var x: Double
    var y: Double
}

struct WorkflowModelRoute: Codable, Sendable {
    var provider: String
    var endpoint: String?
    var model: String
    var reasoningEffort: String?

    static let localAppleIntelligence = WorkflowModelRoute(
        provider: "apple-intelligence",
        endpoint: "cell:///AppleIntelligence",
        model: "on-device",
        reasoningEffort: "balanced"
    )

    static let bindingGatewayPreview = WorkflowModelRoute(
        provider: "binding-local-preview",
        endpoint: "cell:///ConferenceAIAssistantGatewayProxy",
        model: "gpt-4.1-mini",
        reasoningEffort: "low"
    )

    static let remoteScaffold = WorkflowModelRoute(
        provider: "remote-scaffold",
        endpoint: "cell://staging.haven.digipomps.org/AIGateway",
        model: "gpt-4.1-mini",
        reasoningEffort: "medium"
    )
}

struct WorkflowNode: Codable, Sendable {
    var id: String
    var title: String
    var kind: WorkflowNodeKind
    var position: WorkflowNodePosition
    var inputPorts: [WorkflowPortSpec]
    var outputPorts: [WorkflowPortSpec]
    var stateSchema: [WorkflowSchemaField]
    var configSchema: [WorkflowSchemaField]
    var configuration: Object
    var modelRoute: WorkflowModelRoute?
    var note: String?

    func inputPort(id: String) -> WorkflowPortSpec? {
        inputPorts.first(where: { $0.id == id })
    }

    func outputPort(id: String) -> WorkflowPortSpec? {
        outputPorts.first(where: { $0.id == id })
    }

    var primaryInputPortID: String? {
        inputPorts.first?.id
    }

    var primaryOutputPortID: String? {
        outputPorts.first?.id
    }
}

struct WorkflowEdge: Codable, Sendable {
    var id: String
    var fromNodeID: String
    var fromPortID: String
    var toNodeID: String
    var toPortID: String
    var label: String?
}

struct WorkflowDefinition: Codable, Sendable {
    var id: String
    var name: String
    var summary: String
    var revision: Int
    var nodes: [WorkflowNode]
    var edges: [WorkflowEdge]
}

enum WorkflowValidationSeverity: String, Codable, CaseIterable, Sendable {
    case info
    case warning
    case error
}

struct WorkflowValidationIssue: Codable, Sendable {
    var severity: WorkflowValidationSeverity
    var message: String
    var nodeID: String?
    var edgeID: String?
}

enum WorkflowRunStatus: String, Codable, CaseIterable, Sendable {
    case idle
    case running
    case completed
    case failed
    case waitingForApproval
}

enum WorkflowNodeRunStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case running
    case completed
    case failed
    case waitingForApproval
    case skipped
}

struct WorkflowNodeRunSnapshot: Codable, Sendable {
    var nodeID: String
    var nodeTitle: String
    var nodeKind: WorkflowNodeKind
    var status: WorkflowNodeRunStatus
    var inputPreview: String
    var outputPreview: String
    var routeSummary: String
    var errorMessage: String?
    var startedAt: String?
    var finishedAt: String?
}

struct WorkflowRunState: Codable, Sendable {
    var id: String
    var status: WorkflowRunStatus
    var startedAt: String
    var finishedAt: String?
    var trace: [String]
    var finalOutput: ValueType?
    var sharedState: Object
    var waitingNodeID: String?
    var errorMessage: String?
    var inputPreview: String
    var resultSummary: String
    var nodeSnapshots: [WorkflowNodeRunSnapshot]
}

struct WorkflowPaletteItem: Codable, Sendable {
    var kind: WorkflowNodeKind
    var title: String
    var summary: String
    var providerHint: String?
}

enum WorkflowValueCodec {
    static func encode<T: Encodable>(_ value: T) -> ValueType? {
        guard let data = try? JSONEncoder().encode(value) else {
            return nil
        }
        return try? JSONDecoder().decode(ValueType.self, from: data)
    }

    static func decode<T: Decodable>(_ type: T.Type, from value: ValueType) -> T? {
        guard let data = try? JSONEncoder().encode(value) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

enum WorkflowNodeFactory {
    static func makeNode(kind: WorkflowNodeKind, title: String? = nil) -> WorkflowNode {
        let nodeID = UUID().uuidString
        switch kind {
        case .start:
            return WorkflowNode(
                id: nodeID,
                title: title ?? "Start",
                kind: .start,
                position: .init(x: 0, y: 0),
                inputPorts: [],
                outputPorts: [
                    .init(id: "next", label: "Next", direction: .output, valueKind: .any, isRequired: false, summary: "Send initial input forward")
                ],
                stateSchema: [],
                configSchema: [
                    .init(key: "seedText", label: "Seed text", valueKind: .text, isRequired: false, helpText: "Used when the workflow is started without explicit input.")
                ],
                configuration: [:],
                modelRoute: nil,
                note: "Deterministic start of the workflow graph."
            )

        case .agentCall:
            return WorkflowNode(
                id: nodeID,
                title: title ?? "Agent Call",
                kind: .agentCall,
                position: .init(x: 240, y: 0),
                inputPorts: [
                    .init(id: "input", label: "Input", direction: .input, valueKind: .any, isRequired: false, summary: "Data routed into the model node")
                ],
                outputPorts: [
                    .init(id: "result", label: "Result", direction: .output, valueKind: .object, isRequired: false, summary: "Structured model output"),
                    .init(id: "error", label: "Error", direction: .output, valueKind: .text, isRequired: false, summary: "Routing for invocation failures")
                ],
                stateSchema: [
                    .init(key: "lastResult", label: "Last result", valueKind: .object, isRequired: false, helpText: "Last captured output from the model node.")
                ],
                configSchema: [
                    .init(key: "promptTemplate", label: "Prompt template", valueKind: .text, isRequired: false, helpText: "Use {{input}} to interpolate the upstream payload."),
                    .init(key: "systemPrompt", label: "System prompt", valueKind: .text, isRequired: false, helpText: "Optional model instructions."),
                    .init(key: "fallbackSummary", label: "Fallback summary", valueKind: .text, isRequired: false, helpText: "Used when no live provider is reachable.")
                ],
                configuration: [
                    "promptTemplate": .string("Analyze the workflow payload and return a concise structured summary for {{input}}."),
                    "systemPrompt": .string("You are a workflow node inside HAVEN Workflow Studio. Keep the output structured and short.")
                ],
                modelRoute: .bindingGatewayPreview,
                note: "Route one step of the workflow to Apple Intelligence, AIGateway, or a remote scaffold provider."
            )

        case .parser:
            return WorkflowNode(
                id: nodeID,
                title: title ?? "Parser",
                kind: .parser,
                position: .init(x: 480, y: 0),
                inputPorts: [
                    .init(id: "document", label: "Document", direction: .input, valueKind: .document, isRequired: false, summary: "String or document envelope to parse")
                ],
                outputPorts: [
                    .init(id: "parsed", label: "Parsed", direction: .output, valueKind: .object, isRequired: false, summary: "Deterministic parse result"),
                    .init(id: "error", label: "Error", direction: .output, valueKind: .text, isRequired: false, summary: "Parse failure")
                ],
                stateSchema: [
                    .init(key: "lastParse", label: "Last parse", valueKind: .object, isRequired: false, helpText: "Last deterministic parse snapshot.")
                ],
                configSchema: [
                    .init(key: "mode", label: "Mode", valueKind: .text, isRequired: false, helpText: "documentEnvelope or csvish"),
                    .init(key: "textKey", label: "Text key", valueKind: .text, isRequired: false, helpText: "Which object field to parse when the input is an object.")
                ],
                configuration: [
                    "mode": .string("documentEnvelope"),
                    "textKey": .string("text")
                ],
                modelRoute: nil,
                note: "Deterministic parser node. Prefer this to AI extraction when the document format is stable."
            )

        case .transform:
            return WorkflowNode(
                id: nodeID,
                title: title ?? "Transform",
                kind: .transform,
                position: .init(x: 720, y: 0),
                inputPorts: [
                    .init(id: "input", label: "Input", direction: .input, valueKind: .any, isRequired: false, summary: "Upstream payload to transform")
                ],
                outputPorts: [
                    .init(id: "transformed", label: "Transformed", direction: .output, valueKind: .object, isRequired: false, summary: "Normalized payload")
                ],
                stateSchema: [
                    .init(key: "lastTransform", label: "Last transform", valueKind: .object, isRequired: false, helpText: "Latest deterministic transform output.")
                ],
                configSchema: [
                    .init(key: "strategy", label: "Strategy", valueKind: .text, isRequired: false, helpText: "fieldProjection, normalizeResearch, or marketingBatch"),
                    .init(key: "includeKeys", label: "Include keys", valueKind: .list, isRequired: false, helpText: "Optional keys to keep from an object payload.")
                ],
                configuration: [
                    "strategy": .string("fieldProjection")
                ],
                modelRoute: nil,
                note: "Deterministic transformer for shaping parser or agent output before the next step."
            )

        case .condition:
            return WorkflowNode(
                id: nodeID,
                title: title ?? "Condition",
                kind: .condition,
                position: .init(x: 960, y: 0),
                inputPorts: [
                    .init(id: "input", label: "Input", direction: .input, valueKind: .any, isRequired: false, summary: "Payload to evaluate")
                ],
                outputPorts: [
                    .init(id: "true", label: "True", direction: .output, valueKind: .any, isRequired: false, summary: "Branch when the predicate succeeds"),
                    .init(id: "false", label: "False", direction: .output, valueKind: .any, isRequired: false, summary: "Branch when the predicate fails")
                ],
                stateSchema: [
                    .init(key: "lastDecision", label: "Last decision", valueKind: .boolean, isRequired: false, helpText: "Latest boolean outcome.")
                ],
                configSchema: [
                    .init(key: "keypath", label: "Keypath", valueKind: .text, isRequired: false, helpText: "Dot-separated keypath to inspect in the payload."),
                    .init(key: "equalsText", label: "Equals text", valueKind: .text, isRequired: false, helpText: "Optional expected value."),
                    .init(key: "exists", label: "Exists", valueKind: .boolean, isRequired: false, helpText: "Require the value to exist.")
                ],
                configuration: [
                    "keypath": .string("summary"),
                    "exists": .bool(true)
                ],
                modelRoute: nil,
                note: "Deterministic branch node. Use it for routing instead of prompt tricks."
            )

        case .loop:
            return WorkflowNode(
                id: nodeID,
                title: title ?? "Loop",
                kind: .loop,
                position: .init(x: 1200, y: 0),
                inputPorts: [
                    .init(id: "items", label: "Items", direction: .input, valueKind: .list, isRequired: false, summary: "List to iterate or flatten")
                ],
                outputPorts: [
                    .init(id: "items", label: "Items", direction: .output, valueKind: .list, isRequired: false, summary: "Forwarded loop payload"),
                    .init(id: "done", label: "Done", direction: .output, valueKind: .object, isRequired: false, summary: "Loop summary")
                ],
                stateSchema: [
                    .init(key: "lastIterationCount", label: "Last iteration count", valueKind: .number, isRequired: false, helpText: "How many items were observed.")
                ],
                configSchema: [
                    .init(key: "joinWith", label: "Join with", valueKind: .text, isRequired: false, helpText: "Optional delimiter used for text flattening.")
                ],
                configuration: [
                    "joinWith": .string("\n")
                ],
                modelRoute: nil,
                note: "Simple deterministic loop helper. V1 forwards list payloads and emits iteration summary."
            )

        case .approval:
            return WorkflowNode(
                id: nodeID,
                title: title ?? "Approval",
                kind: .approval,
                position: .init(x: 1440, y: 0),
                inputPorts: [
                    .init(id: "proposal", label: "Proposal", direction: .input, valueKind: .any, isRequired: false, summary: "Payload requiring approval")
                ],
                outputPorts: [
                    .init(id: "approved", label: "Approved", direction: .output, valueKind: .any, isRequired: false, summary: "Continue when approved"),
                    .init(id: "rejected", label: "Rejected", direction: .output, valueKind: .any, isRequired: false, summary: "Route when rejected")
                ],
                stateSchema: [
                    .init(key: "approvalState", label: "Approval state", valueKind: .approval, isRequired: false, helpText: "Latest approval state.")
                ],
                configSchema: [
                    .init(key: "autoApprove", label: "Auto approve", valueKind: .boolean, isRequired: false, helpText: "If false, the run pauses in waitingForApproval."),
                    .init(key: "message", label: "Message", valueKind: .text, isRequired: false, helpText: "Human-facing note for the approval step.")
                ],
                configuration: [
                    "autoApprove": .bool(false),
                    "message": .string("Review this side effect before the workflow continues.")
                ],
                modelRoute: nil,
                note: "Approval gate that reuses HAVEN's access and human-in-the-loop semantics."
            )

        case .setState:
            return WorkflowNode(
                id: nodeID,
                title: title ?? "Set State",
                kind: .setState,
                position: .init(x: 1680, y: 0),
                inputPorts: [
                    .init(id: "patch", label: "Patch", direction: .input, valueKind: .object, isRequired: false, summary: "Payload to merge into shared workflow state")
                ],
                outputPorts: [
                    .init(id: "state", label: "State", direction: .output, valueKind: .object, isRequired: false, summary: "Merged shared state")
                ],
                stateSchema: [
                    .init(key: "lastPatch", label: "Last patch", valueKind: .object, isRequired: false, helpText: "Latest merged object.")
                ],
                configSchema: [
                    .init(key: "statePatch", label: "State patch", valueKind: .statePatch, isRequired: false, helpText: "Additional deterministic state patch merged on every run.")
                ],
                configuration: [:],
                modelRoute: nil,
                note: "Writes structured state without involving a model."
            )

        case .end:
            return WorkflowNode(
                id: nodeID,
                title: title ?? "End",
                kind: .end,
                position: .init(x: 1920, y: 0),
                inputPorts: [
                    .init(id: "result", label: "Result", direction: .input, valueKind: .any, isRequired: false, summary: "Final workflow output")
                ],
                outputPorts: [],
                stateSchema: [],
                configSchema: [],
                configuration: [:],
                modelRoute: nil,
                note: "Final sink for the workflow result."
            )

        case .note:
            return WorkflowNode(
                id: nodeID,
                title: title ?? "Note",
                kind: .note,
                position: .init(x: 2160, y: 0),
                inputPorts: [
                    .init(id: "input", label: "Input", direction: .input, valueKind: .any, isRequired: false, summary: "Payload passed through the note")
                ],
                outputPorts: [
                    .init(id: "next", label: "Next", direction: .output, valueKind: .any, isRequired: false, summary: "Pass-through output")
                ],
                stateSchema: [],
                configSchema: [
                    .init(key: "text", label: "Text", valueKind: .text, isRequired: false, helpText: "Design-time note for the workflow author.")
                ],
                configuration: [
                    "text": .string("Use notes to capture intent or TODO items next to the runtime graph.")
                ],
                modelRoute: nil,
                note: "Authoring-only note that still behaves like a pass-through runtime node."
            )
        }
    }

    static func primaryOutputPortID(for node: WorkflowNode) -> String? {
        switch node.kind {
        case .condition:
            return "true"
        case .approval:
            return "approved"
        case .parser:
            return "parsed"
        case .transform:
            return "transformed"
        case .setState:
            return "state"
        case .agentCall:
            return "result"
        case .loop:
            return "items"
        case .note:
            return "next"
        case .start:
            return "next"
        case .end:
            return nil
        }
    }

    static func primaryInputPortID(for node: WorkflowNode) -> String? {
        switch node.kind {
        case .parser:
            return "document"
        case .approval:
            return "proposal"
        case .setState:
            return "patch"
        case .loop:
            return "items"
        case .end:
            return "result"
        default:
            return node.inputPorts.first?.id
        }
    }
}

enum WorkflowCatalog {
    static func palette() -> [WorkflowPaletteItem] {
        WorkflowNodeKind.allCases.map { kind in
            let node = WorkflowNodeFactory.makeNode(kind: kind)
            return WorkflowPaletteItem(
                kind: kind,
                title: node.title,
                summary: node.note ?? "",
                providerHint: node.modelRoute?.provider
            )
        }
    }

    static func documentPipeline() -> WorkflowDefinition {
        var start = WorkflowNodeFactory.makeNode(kind: .start, title: "Document Input")
        start.configuration["seedText"] = .string("Meeting Notes\nSpeaker: HAVEN Team\n- Add parser cell\n- Normalize output\n- Summarize with local AI\nLink: https://haven.example/demo")

        let parser = WorkflowNodeFactory.makeNode(kind: .parser, title: "Parse Notes")
        var transform = WorkflowNodeFactory.makeNode(kind: .transform, title: "Project Fields")
        transform.configuration["strategy"] = .string("fieldProjection")
        transform.configuration["includeKeys"] = .list([
            .string("title"),
            .string("bulletCount"),
            .string("urlCount"),
            .string("lineCount"),
            .string("summary")
        ])

        var agent = WorkflowNodeFactory.makeNode(kind: .agentCall, title: "Summarize Findings")
        agent.modelRoute = .localAppleIntelligence
        agent.configuration["promptTemplate"] = .string("Summarize this parsed document for the workflow user: {{input}}")

        var condition = WorkflowNodeFactory.makeNode(kind: .condition, title: "Has Summary")
        condition.configuration["keypath"] = .string("summary")
        condition.configuration["exists"] = .bool(true)

        let end = WorkflowNodeFactory.makeNode(kind: .end, title: "Publish Result")

        let nodes = [start, parser, transform, agent, condition, end]
        let edges = makeLinearEdges(nodes: nodes)

        return WorkflowDefinition(
            id: UUID().uuidString,
            name: "Document -> Parser -> Transform -> Agent -> Condition",
            summary: "Deterministic document intake with parser and transform before a local AI summary.",
            revision: 1,
            nodes: layout(nodes),
            edges: edges
        )
    }

    static func researchPipeline() -> WorkflowDefinition {
        let start = WorkflowNodeFactory.makeNode(kind: .start, title: "Research Brief")
        var agent1 = WorkflowNodeFactory.makeNode(kind: .agentCall, title: "Web Research Agent")
        agent1.modelRoute = .bindingGatewayPreview
        agent1.configuration["promptTemplate"] = .string("Research the company described by {{input}} and return a concise structured brief.")

        var transform = WorkflowNodeFactory.makeNode(kind: .transform, title: "Normalize Research Batch")
        transform.configuration["strategy"] = .string("normalizeResearch")

        var agent2 = WorkflowNodeFactory.makeNode(kind: .agentCall, title: "Summarize for User")
        agent2.modelRoute = .remoteScaffold
        agent2.configuration["promptTemplate"] = .string("Turn this research batch into a user-facing summary: {{input}}")

        let end = WorkflowNodeFactory.makeNode(kind: .end, title: "Structured Result")
        let nodes = [start, agent1, transform, agent2, end]

        return WorkflowDefinition(
            id: UUID().uuidString,
            name: "Research Workflow",
            summary: "Two agent nodes with a deterministic normalizer in the middle.",
            revision: 1,
            nodes: layout(nodes),
            edges: makeLinearEdges(nodes: nodes)
        )
    }

    static func approvalPipeline() -> WorkflowDefinition {
        let start = WorkflowNodeFactory.makeNode(kind: .start, title: "Side Effect Request")

        var parser = WorkflowNodeFactory.makeNode(kind: .parser, title: "Parse Request")
        parser.configuration["mode"] = .string("documentEnvelope")

        var setState = WorkflowNodeFactory.makeNode(kind: .setState, title: "Prepare State")
        setState.configuration["statePatch"] = .object([
            "sideEffectCategory": .string("osascript"),
            "executionMode": .string("guarded")
        ])

        var approval = WorkflowNodeFactory.makeNode(kind: .approval, title: "Human Approval")
        approval.configuration["autoApprove"] = .bool(false)
        approval.configuration["message"] = .string("Review before this workflow is allowed to reach an external side effect.")

        let end = WorkflowNodeFactory.makeNode(kind: .end, title: "Ready To Dispatch")
        let nodes = [start, parser, setState, approval, end]

        return WorkflowDefinition(
            id: UUID().uuidString,
            name: "Approval + Guardrail Workflow",
            summary: "Source-backed approval gate before a side effect or remote tool call.",
            revision: 1,
            nodes: layout(nodes),
            edges: makeLinearEdges(nodes: nodes)
        )
    }

    static func availableRoutes() -> [WorkflowModelRoute] {
        [.localAppleIntelligence, .bindingGatewayPreview, .remoteScaffold]
    }

    private static func layout(_ nodes: [WorkflowNode]) -> [WorkflowNode] {
        nodes.enumerated().map { index, node in
            var updated = node
            updated.position = WorkflowNodePosition(x: Double(index * 220), y: 0)
            return updated
        }
    }

    private static func makeLinearEdges(nodes: [WorkflowNode]) -> [WorkflowEdge] {
        guard nodes.count > 1 else { return [] }
        var edges: [WorkflowEdge] = []
        for index in 0..<(nodes.count - 1) {
            let from = nodes[index]
            let to = nodes[index + 1]
            guard let fromPortID = WorkflowNodeFactory.primaryOutputPortID(for: from),
                  let toPortID = WorkflowNodeFactory.primaryInputPortID(for: to) else {
                continue
            }
            edges.append(
                WorkflowEdge(
                    id: UUID().uuidString,
                    fromNodeID: from.id,
                    fromPortID: fromPortID,
                    toNodeID: to.id,
                    toPortID: toPortID,
                    label: nil
                )
            )
        }
        return edges
    }
}

enum WorkflowDefinitionValidation {
    static func validate(_ definition: WorkflowDefinition) -> [WorkflowValidationIssue] {
        var issues: [WorkflowValidationIssue] = []
        let nodeIDs = definition.nodes.map(\.id)
        let uniqueNodeIDs = Set(nodeIDs)
        if nodeIDs.count != uniqueNodeIDs.count {
            issues.append(.init(severity: .error, message: "Workflow contains duplicate node IDs.", nodeID: nil, edgeID: nil))
        }

        let startNodes = definition.nodes.filter { $0.kind == .start }
        if startNodes.isEmpty {
            issues.append(.init(severity: .error, message: "Workflow needs at least one Start node.", nodeID: nil, edgeID: nil))
        } else if startNodes.count > 1 {
            issues.append(.init(severity: .warning, message: "Workflow has multiple Start nodes. V1 runner starts with the first one.", nodeID: startNodes.first?.id, edgeID: nil))
        }

        let endNodes = definition.nodes.filter { $0.kind == .end }
        if endNodes.isEmpty {
            issues.append(.init(severity: .warning, message: "Workflow has no End node. Final output will be taken from the last executed node.", nodeID: nil, edgeID: nil))
        }

        if definition.edges.isEmpty {
            issues.append(.init(severity: .warning, message: "Workflow has no edges yet.", nodeID: nil, edgeID: nil))
        }

        let nodeMap = Dictionary(uniqueKeysWithValues: definition.nodes.map { ($0.id, $0) })
        for edge in definition.edges {
            guard let from = nodeMap[edge.fromNodeID] else {
                issues.append(.init(severity: .error, message: "Edge references missing source node.", nodeID: nil, edgeID: edge.id))
                continue
            }
            guard let to = nodeMap[edge.toNodeID] else {
                issues.append(.init(severity: .error, message: "Edge references missing target node.", nodeID: nil, edgeID: edge.id))
                continue
            }
            guard let outputPort = from.outputPort(id: edge.fromPortID) else {
                issues.append(.init(severity: .error, message: "Edge references unknown output port \(edge.fromPortID).", nodeID: from.id, edgeID: edge.id))
                continue
            }
            guard let inputPort = to.inputPort(id: edge.toPortID) else {
                issues.append(.init(severity: .error, message: "Edge references unknown input port \(edge.toPortID).", nodeID: to.id, edgeID: edge.id))
                continue
            }
            if !outputPort.valueKind.isCompatible(with: inputPort.valueKind) {
                issues.append(.init(
                    severity: .error,
                    message: "Port mismatch from \(from.title).\(outputPort.label) to \(to.title).\(inputPort.label).",
                    nodeID: to.id,
                    edgeID: edge.id
                ))
            }
        }
        return issues
    }
}

private struct WorkflowExecutionResult {
    var status: WorkflowNodeRunStatus
    var outputs: [String: ValueType]
    var sharedStatePatch: Object
    var errorMessage: String?
    var note: String
}

enum WorkflowRunner {
    private static let maxExecutionSteps = 64

    static func run(
        definition: WorkflowDefinition,
        input: ValueType,
        requester: Identity?
    ) async -> WorkflowRunState {
        let startedAt = Date()
        let nodeMap = Dictionary(uniqueKeysWithValues: definition.nodes.map { ($0.id, $0) })
        var snapshots: [String: WorkflowNodeRunSnapshot] = [:]
        var trace: [String] = []
        var sharedState: Object = [:]
        var finalOutput: ValueType?
        var waitingNodeID: String?
        var runStatus: WorkflowRunStatus = .running
        var runError: String?

        let initialInput = input
        guard let startNode = definition.nodes.first(where: { $0.kind == .start }) else {
            return WorkflowRunState(
                id: UUID().uuidString,
                status: .failed,
                startedAt: iso8601(startedAt),
                finishedAt: iso8601(Date()),
                trace: ["No Start node found."],
                finalOutput: nil,
                sharedState: [:],
                waitingNodeID: nil,
                errorMessage: "Workflow is missing a Start node.",
                inputPreview: renderPreview(initialInput),
                resultSummary: "Missing Start node",
                nodeSnapshots: []
            )
        }

        var pending: [(nodeID: String, payload: ValueType)] = [(startNode.id, initialInput)]
        var executionSteps = 0

        while pending.isEmpty == false, executionSteps < maxExecutionSteps {
            executionSteps += 1
            let next = pending.removeFirst()
            guard let node = nodeMap[next.nodeID] else {
                trace.append("Skipped missing node \(next.nodeID).")
                continue
            }

            let startTime = Date()
            let result = await executeNode(node, input: next.payload, sharedState: sharedState, requester: requester)

            sharedState.merge(result.sharedStatePatch) { _, new in new }
            let outputPreview = result.outputs.isEmpty
                ? ""
                : renderPreview(.object(result.outputs))

            let routeSummary: String = {
                if let route = node.modelRoute {
                    return "\(route.provider) · \(route.model)"
                }
                return ""
            }()

            snapshots[node.id] = WorkflowNodeRunSnapshot(
                nodeID: node.id,
                nodeTitle: node.title,
                nodeKind: node.kind,
                status: result.status,
                inputPreview: renderPreview(next.payload),
                outputPreview: outputPreview,
                routeSummary: routeSummary,
                errorMessage: result.errorMessage,
                startedAt: iso8601(startTime),
                finishedAt: iso8601(Date())
            )

            trace.append("\(node.title): \(result.note)")

            if node.kind == .end, let value = result.outputs["result"] ?? result.outputs.values.first {
                finalOutput = value
                runStatus = .completed
                break
            }

            if result.status == .waitingForApproval {
                waitingNodeID = node.id
                runStatus = .waitingForApproval
                finalOutput = .object(result.outputs)
                break
            }

            if result.status == .failed {
                if let errorOutput = result.outputs["error"] {
                    let routed = edges(from: node.id, portID: "error", definition: definition)
                    if routed.isEmpty {
                        runStatus = .failed
                        runError = result.errorMessage ?? renderPreview(errorOutput)
                        finalOutput = errorOutput
                        break
                    }
                    for edge in routed {
                        pending.append((edge.toNodeID, errorOutput))
                    }
                    continue
                }
                runStatus = .failed
                runError = result.errorMessage ?? "Node \(node.title) failed."
                break
            }

            if result.outputs.isEmpty {
                continue
            }

            for (portID, payload) in result.outputs {
                let routedEdges = edges(from: node.id, portID: portID, definition: definition)
                if routedEdges.isEmpty {
                    finalOutput = payload
                }
                for edge in routedEdges {
                    pending.append((edge.toNodeID, payload))
                }
            }
        }

        if executionSteps >= maxExecutionSteps, runStatus == .running {
            runStatus = .failed
            runError = "Workflow exceeded the V1 execution step limit."
        }

        if runStatus == .running {
            runStatus = .completed
        }

        let orderedSnapshots = definition.nodes.compactMap { snapshots[$0.id] }
        let summary: String = {
            switch runStatus {
            case .completed:
                return finalOutput.map(renderPreview) ?? "Completed without explicit output."
            case .waitingForApproval:
                return "Waiting for approval at \(waitingNodeID ?? "unknown node")."
            case .failed:
                return runError ?? "Run failed."
            case .idle, .running:
                return "Run status \(runStatus.rawValue)"
            }
        }()

        return WorkflowRunState(
            id: UUID().uuidString,
            status: runStatus,
            startedAt: iso8601(startedAt),
            finishedAt: iso8601(Date()),
            trace: trace,
            finalOutput: finalOutput,
            sharedState: sharedState,
            waitingNodeID: waitingNodeID,
            errorMessage: runError,
            inputPreview: renderPreview(initialInput),
            resultSummary: summary,
            nodeSnapshots: orderedSnapshots
        )
    }

    private static func edges(
        from nodeID: String,
        portID: String,
        definition: WorkflowDefinition
    ) -> [WorkflowEdge] {
        definition.edges.filter { $0.fromNodeID == nodeID && $0.fromPortID == portID }
    }

    private static func executeNode(
        _ node: WorkflowNode,
        input: ValueType,
        sharedState: Object,
        requester: Identity?
    ) async -> WorkflowExecutionResult {
        switch node.kind {
        case .start:
            let seeded = WorkflowValueExtraction.nonEmptyString(node.configuration["seedText"])
            let output: ValueType
            if case .null = input, let seeded {
                output = .string(seeded)
            } else {
                output = input
            }
            return WorkflowExecutionResult(
                status: .completed,
                outputs: ["next": output],
                sharedStatePatch: [:],
                errorMessage: nil,
                note: "Seeded initial workflow payload."
            )

        case .parser:
            guard let parsed = WorkflowDeterministicParser.parse(input: input, configuration: node.configuration) else {
                return WorkflowExecutionResult(
                    status: .failed,
                    outputs: ["error": .string("Parser could not find document text in the payload.")],
                    sharedStatePatch: [:],
                    errorMessage: "Parser could not extract text.",
                    note: "Parser failed to extract text."
                )
            }
            return WorkflowExecutionResult(
                status: .completed,
                outputs: ["parsed": .object(parsed)],
                sharedStatePatch: [:],
                errorMessage: nil,
                note: "Parsed document deterministically."
            )

        case .transform:
            let transformed = WorkflowDeterministicTransform.transform(input: input, configuration: node.configuration)
            return WorkflowExecutionResult(
                status: .completed,
                outputs: ["transformed": transformed],
                sharedStatePatch: [:],
                errorMessage: nil,
                note: "Applied deterministic transform strategy."
            )

        case .condition:
            let passed = WorkflowConditionEvaluator.evaluate(input: input, configuration: node.configuration)
            let port = passed ? "true" : "false"
            return WorkflowExecutionResult(
                status: .completed,
                outputs: [port: input],
                sharedStatePatch: [:],
                errorMessage: nil,
                note: "Condition evaluated to \(passed)."
            )

        case .loop:
            let list = WorkflowValueExtraction.list(input)
            let count = list?.count ?? 0
            let joinedText = list.map { values in
                values.map(renderPreview).joined(separator: WorkflowValueExtraction.nonEmptyString(node.configuration["joinWith"]) ?? "\n")
            } ?? renderPreview(input)
            return WorkflowExecutionResult(
                status: .completed,
                outputs: [
                    "items": list.map(ValueType.list) ?? .list([input]),
                    "done": .object([
                        "iterationCount": .integer(count),
                        "joinedText": .string(joinedText)
                    ])
                ],
                sharedStatePatch: [:],
                errorMessage: nil,
                note: "Loop observed \(count) items."
            )

        case .approval:
            let autoApprove = WorkflowValueExtraction.bool(node.configuration["autoApprove"]) ?? false
            let message = WorkflowValueExtraction.nonEmptyString(node.configuration["message"]) ?? "Approval required."
            if autoApprove {
                return WorkflowExecutionResult(
                    status: .completed,
                    outputs: ["approved": input],
                    sharedStatePatch: [:],
                    errorMessage: nil,
                    note: "Approval auto-approved."
                )
            }
            return WorkflowExecutionResult(
                status: .waitingForApproval,
                outputs: [
                    "rejected": .object([
                        "message": .string(message),
                        "pendingPayload": input
                    ])
                ],
                sharedStatePatch: [:],
                errorMessage: nil,
                note: "Run paused for approval."
            )

        case .setState:
            var patch: Object = sharedState
            if case let .object(object) = input {
                patch.merge(object) { _, new in new }
            }
            if case let .object(additionalPatch)? = node.configuration["statePatch"] {
                patch.merge(additionalPatch) { _, new in new }
            }
            return WorkflowExecutionResult(
                status: .completed,
                outputs: ["state": .object(patch)],
                sharedStatePatch: patch,
                errorMessage: nil,
                note: "Merged patch into shared workflow state."
            )

        case .note:
            return WorkflowExecutionResult(
                status: .completed,
                outputs: ["next": input],
                sharedStatePatch: [:],
                errorMessage: nil,
                note: "Passed payload through note node."
            )

        case .end:
            return WorkflowExecutionResult(
                status: .completed,
                outputs: ["result": input],
                sharedStatePatch: [:],
                errorMessage: nil,
                note: "Completed workflow at End node."
            )

        case .agentCall:
            let invoked = await WorkflowAgentInvoker.invoke(node: node, input: input, requester: requester)
            switch invoked {
            case .success(let result):
                return WorkflowExecutionResult(
                    status: .completed,
                    outputs: ["result": result],
                    sharedStatePatch: [:],
                    errorMessage: nil,
                    note: "Invoked model route \(node.modelRoute?.provider ?? "fallback")."
                )
            case .failure(let error):
                return WorkflowExecutionResult(
                    status: .failed,
                    outputs: ["error": .string(error.message)],
                    sharedStatePatch: [:],
                    errorMessage: error.message,
                    note: "Model route failed."
                )
            }
        }
    }
}

private enum WorkflowDeterministicParser {
    static func parse(input: ValueType, configuration: Object) -> Object? {
        let textKey = WorkflowValueExtraction.nonEmptyString(configuration["textKey"]) ?? "text"
        let mode = WorkflowValueExtraction.nonEmptyString(configuration["mode"]) ?? "documentEnvelope"
        let rawText: String?
        switch input {
        case .string(let string):
            rawText = string
        case .object(let object):
            rawText = WorkflowValueExtraction.nonEmptyString(object[textKey])
                ?? WorkflowValueExtraction.nonEmptyString(object["documentText"])
                ?? WorkflowValueExtraction.nonEmptyString(object["text"])
        default:
            rawText = nil
        }

        guard let rawText else { return nil }
        let lines = rawText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let title = lines.first ?? "Untitled Document"
        let bulletCount = lines.filter { line in
            line.hasPrefix("- ") || line.hasPrefix("* ") || line.range(of: #"^\d+\."#, options: .regularExpression) != nil
        }.count
        let urlCount = rawText.matches(of: #"https?://\S+"#).count
        let emailCount = rawText.matches(of: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, caseInsensitive: true).count
        let commaLineCount = lines.filter { $0.contains(",") }.count
        let csvColumns = commaLineCount > 1 ? (lines.first?.split(separator: ",").count ?? 0) : 0

        var result: Object = [
            "mode": .string(mode),
            "title": .string(title),
            "lineCount": .integer(lines.count),
            "wordCount": .integer(rawText.split(whereSeparator: \.isWhitespace).count),
            "bulletCount": .integer(bulletCount),
            "urlCount": .integer(urlCount),
            "emailCount": .integer(emailCount),
            "summary": .string(lines.prefix(3).joined(separator: " | ")),
            "text": .string(rawText)
        ]

        if csvColumns > 0 {
            result["csvColumnCount"] = .integer(csvColumns)
            result["hasTabularShape"] = .bool(true)
        }
        return result
    }
}

private enum WorkflowDeterministicTransform {
    static func transform(input: ValueType, configuration: Object) -> ValueType {
        let strategy = WorkflowValueExtraction.nonEmptyString(configuration["strategy"]) ?? "fieldProjection"
        let includeKeys = WorkflowValueExtraction.list(configuration["includeKeys"])?.compactMap(WorkflowValueExtraction.nonEmptyString) ?? []

        switch strategy {
        case "normalizeResearch":
            if case let .object(object) = input {
                return .object([
                    "company": object["company"] ?? object["title"] ?? .string("unknown"),
                    "signals": .list(extractSignalList(from: object)),
                    "summary": .string(WorkflowValueExtraction.nonEmptyString(object["summary"]) ?? renderPreview(input)),
                    "normalizedAt": .string(iso8601(Date()))
                ])
            }

        case "marketingBatch":
            if case let .object(object) = input {
                return .object([
                    "batchTitle": object["title"] ?? .string("Marketing batch"),
                    "metrics": .object([
                        "links": object["urlCount"] ?? .integer(0),
                        "bullets": object["bulletCount"] ?? .integer(0),
                        "emails": object["emailCount"] ?? .integer(0)
                    ]),
                    "summary": .string(WorkflowValueExtraction.nonEmptyString(object["summary"]) ?? renderPreview(input))
                ])
            }

        default:
            break
        }

        if case let .object(object) = input {
            if includeKeys.isEmpty == false {
                var projected: Object = [:]
                includeKeys.forEach { key in
                    if let value = object[key] {
                        projected[key] = value
                    }
                }
                projected["strategy"] = .string(strategy)
                return .object(projected)
            }

            var normalized = object
            normalized["strategy"] = .string(strategy)
            if normalized["summary"] == nil {
                normalized["summary"] = .string(renderPreview(input))
            }
            return .object(normalized)
        }

        return .object([
            "strategy": .string(strategy),
            "summary": .string(renderPreview(input))
        ])
    }

    private static func extractSignalList(from object: Object) -> [ValueType] {
        let interestingKeys = ["summary", "title", "urlCount", "bulletCount", "emailCount"]
        return interestingKeys.compactMap { key in
            guard let value = object[key] else { return nil }
            return .object([
                "key": .string(key),
                "value": value
            ])
        }
    }
}

private enum WorkflowConditionEvaluator {
    static func evaluate(input: ValueType, configuration: Object) -> Bool {
        let keypath = WorkflowValueExtraction.nonEmptyString(configuration["keypath"]) ?? ""
        let equalsText = WorkflowValueExtraction.nonEmptyString(configuration["equalsText"])
        let exists = WorkflowValueExtraction.bool(configuration["exists"])

        let inspectedValue: ValueType?
        if keypath.isEmpty {
            inspectedValue = input
        } else {
            inspectedValue = WorkflowValueExtraction.value(at: keypath, in: input)
        }

        if let exists {
            let isPresent = inspectedValue != nil && inspectedValue != .null
            if exists == false {
                return !isPresent
            }
            if !isPresent {
                return false
            }
        }

        if let equalsText {
            return WorkflowValueExtraction.nonEmptyString(inspectedValue) == equalsText
        }

        guard let inspectedValue else { return false }
        switch inspectedValue {
        case .bool(let value):
            return value
        case .string(let value):
            return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .list(let list):
            return list.isEmpty == false
        case .object(let object):
            return object.isEmpty == false
        case .null:
            return false
        default:
            return true
        }
    }
}

private enum WorkflowAgentInvoker {
    struct InvocationError: Error {
        var message: String
    }

    static func invoke(
        node: WorkflowNode,
        input: ValueType,
        requester: Identity?
    ) async -> Result<ValueType, InvocationError> {
        let route = node.modelRoute ?? .bindingGatewayPreview
        let promptTemplate = WorkflowValueExtraction.nonEmptyString(node.configuration["promptTemplate"])
            ?? "Summarize the following workflow payload: {{input}}"
        let prompt = promptTemplate.replacingOccurrences(of: "{{input}}", with: renderPreview(input))

        if let endpoint = route.endpoint,
           let requester,
           let resolver = CellBase.defaultCellResolver as? CellResolver,
           let meddle = try? await resolver.cellAtEndpoint(endpoint: endpoint, requester: requester) as? Meddle {
            if endpoint.contains("ConferenceAIAssistantGatewayProxy") {
                _ = try? await meddle.set(
                    keypath: "applyDraftProfile",
                    value: .object([
                        "providerID": .string(route.provider),
                        "model": .string(route.model),
                        "requiresAPIKey": .bool(route.provider != "apple-intelligence")
                    ]),
                    requester: requester
                )
                _ = try? await meddle.set(
                    keypath: "setDraftPrompt",
                    value: .string(prompt),
                    requester: requester
                )
                let response = try? await meddle.set(
                    keypath: "invokeDraft",
                    value: .object([
                        "prompt": .string(prompt)
                    ]),
                    requester: requester
                )
                if let preview = extractInvocationPreview(from: response) {
                    return .success(.object([
                        "summary": .string(preview),
                        "provider": .string(route.provider),
                        "model": .string(route.model),
                        "prompt": .string(prompt)
                    ]))
                }
            }
        }

        let fallback = WorkflowValueExtraction.nonEmptyString(node.configuration["fallbackSummary"])
            ?? "Workflow Studio used a deterministic local fallback because no live provider was reachable."
        return .success(.object([
            "summary": .string(fallback),
            "provider": .string(route.provider),
            "model": .string(route.model),
            "prompt": .string(prompt),
            "inputPreview": .string(renderPreview(input))
        ]))
    }

    private static func extractInvocationPreview(from response: ValueType?) -> String? {
        guard let response else { return nil }
        if case let .object(object) = response {
            if let preview = WorkflowValueExtraction.nonEmptyString(WorkflowValueExtraction.value(at: "state.lastInvocation.outputPreview", in: .object(object))) {
                return preview
            }
            if let preview = WorkflowValueExtraction.nonEmptyString(WorkflowValueExtraction.value(at: "lastInvocation.outputPreview", in: .object(object))) {
                return preview
            }
            if let preview = WorkflowValueExtraction.nonEmptyString(object["outputPreview"]) {
                return preview
            }
        }
        return nil
    }
}

enum WorkflowValueExtraction {
    static func nonEmptyString(_ value: ValueType?) -> String? {
        guard case let .string(string)? = value else {
            return nil
        }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func bool(_ value: ValueType?) -> Bool? {
        guard case let .bool(bool)? = value else {
            return nil
        }
        return bool
    }

    static func integer(_ value: ValueType?) -> Int? {
        switch value {
        case .integer(let integer):
            return integer
        case .number(let number):
            return number
        default:
            return nil
        }
    }

    static func list(_ value: ValueType?) -> [ValueType]? {
        guard case let .list(list)? = value else {
            return nil
        }
        return list
    }

    static func object(_ value: ValueType?) -> Object? {
        guard case let .object(object)? = value else {
            return nil
        }
        return object
    }

    static func value(at keypath: String, in root: ValueType) -> ValueType? {
        guard keypath.isEmpty == false else {
            return root
        }
        let parts = keypath.split(separator: ".").map(String.init)
        var current: ValueType? = root
        for part in parts {
            guard case let .object(object)? = current else {
                return nil
            }
            current = object[part]
        }
        return current
    }
}

func renderPreview(_ value: ValueType) -> String {
    switch value {
    case .string(let string):
        return string
    case .bool(let bool):
        return bool ? "true" : "false"
    case .integer(let integer), .number(let integer):
        return "\(integer)"
    case .float(let double):
        return "\(double)"
    case .list(let list):
        return "[\(list.map(renderPreview).joined(separator: ", "))]"
    case .object(let object):
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(object),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "{object}"
    case .null:
        return "null"
    default:
        return String(describing: value)
    }
}

func iso8601(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
}

private extension String {
    func matches(
        of pattern: String,
        options: NSRegularExpression.Options = [],
        caseInsensitive: Bool = false
    ) -> [String] {
        var regexOptions = options
        if caseInsensitive {
            regexOptions.insert(.caseInsensitive)
        }
        guard let regex = try? NSRegularExpression(pattern: pattern, options: regexOptions) else {
            return []
        }
        let range = NSRange(startIndex..<endIndex, in: self)
        return regex.matches(in: self, options: [], range: range).compactMap { result in
            guard let range = Range(result.range, in: self) else { return nil }
            return String(self[range])
        }
    }
}
