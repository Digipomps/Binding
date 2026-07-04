import CryptoKit
import Foundation
import HavenRuntimeBootstrap

public enum AdvisorPanelSpawnContract {
    public static let schema = "haven.agentd.advisor-panel-spawn.v1"
    public static let directoryName = "AdvisorPanelSpawns"
    public static let source = "haven-agentd.spawn-advisors"
    public static let sideEffectBoundary = """
    Local artifact only. This command does not call AI providers, send notifications, mutate Cell state, \
    open helpers, accept suggestions, or execute scripts. Each generated advisor task must be reviewed \
    and run through an explicitly approved cell-scoped provider or agent surface.
    """
}

public enum AdvisorPanelPlanContract {
    public static let schema = "haven.agentd.advisor-panel-plan.v1"
    public static let status = "planned"
}

public struct AdvisorPanelSpec: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var displayName: String
    public var role: String
    public var preferredBackend: String
    public var focus: [String]

    public init(
        id: String,
        displayName: String,
        role: String,
        preferredBackend: String = "local_or_reviewed",
        focus: [String] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.preferredBackend = preferredBackend
        self.focus = focus
    }
}

public struct AdvisorPanelSpawnRequest: Codable, Equatable, Sendable {
    public var topic: String
    public var purposeRef: String
    public var goal: String
    public var brief: String
    public var interests: [String]
    public var constraints: [String]
    public var sourceRefs: [String]
    public var dataClassification: String
    public var outputLanguage: String
    public var advisors: [AdvisorPanelSpec]

    public init(
        topic: String,
        purposeRef: String,
        goal: String,
        brief: String,
        interests: [String] = [],
        constraints: [String] = [],
        sourceRefs: [String] = [],
        dataClassification: String = "repo_local_context",
        outputLanguage: String = "Norwegian",
        advisors: [AdvisorPanelSpec] = AdvisorPanelSpawnRequest.defaultAdvisors
    ) {
        self.topic = topic
        self.purposeRef = purposeRef
        self.goal = goal
        self.brief = brief
        self.interests = interests
        self.constraints = constraints
        self.sourceRefs = sourceRefs
        self.dataClassification = dataClassification
        self.outputLanguage = outputLanguage
        self.advisors = advisors
    }
}

extension AdvisorPanelSpawnRequest {
    public static let defaultAdvisors: [AdvisorPanelSpec] = [
        AdvisorPanelSpec(
            id: "cellprotocol-steward",
            displayName: "CellProtocol Steward",
            role: "Check ownership, grants, side-effect boundaries, purpose/interest use, and portable CellProtocol semantics.",
            focus: ["CellProtocol", "ownership", "grants", "side-effects"]
        ),
        AdvisorPanelSpec(
            id: "binding-gui-evaluator",
            displayName: "Binding GUI Evaluator",
            role: "Evaluate whether the Binding GUI is understandable, compact, accessible, and useful on iPhone, iPad, and macOS.",
            focus: ["Binding", "mobile", "accessibility", "interaction-cost"]
        ),
        AdvisorPanelSpec(
            id: "cellscaffold-parity",
            displayName: "CellScaffold Parity Reviewer",
            role: "Compare the proposed Binding behavior with CellScaffold/Porthole without requiring pixel-perfect rendering.",
            focus: ["CellScaffold", "Porthole", "skeleton", "semantic-parity"]
        ),
        AdvisorPanelSpec(
            id: "skeptic",
            displayName: "User-Value Skeptic",
            role: "Attack weak assumptions and identify places where the GUI looks plausible but fails the user's actual purpose.",
            focus: ["task-success", "evidence", "failure-modes", "user-comprehension"]
        )
    ]

    public static func bindingGUIQualityProfile(brief overrideBrief: String? = nil) -> AdvisorPanelSpawnRequest {
        AdvisorPanelSpawnRequest(
            topic: "Binding GUI quality and CellScaffold parity",
            purposeRef: "purpose://binding.gui.user-value",
            goal: "Define and review a Binding GUI that lets a real user complete the intended task with no hidden side effects, no raw protocol leaks, and semantic parity with CellScaffold.",
            brief: overrideBrief ?? """
            We need a Binding GUI that is objectively good for the user and faithful to CellProtocol. \
            It must work for chat-first Co-Pilot surfaces and portable CellConfigurations such as event atlas/program flows. \
            The GUI must keep user intent central, use Purpose/Interest context where available, keep providers and actions cell-scoped, \
            expose helper/detail surfaces without accidental side effects, and remain semantically paired with CellScaffold/Porthole. \
            Evaluate first-load comprehension, mobile/iPad/macOS layout, tabs, details/drawers/overlays, search/filter/map/list flows, \
            helper availability, action labels, error presentation, accessibility, performance, and data minimization.
            """,
            interests: [
                "binding",
                "gui-quality",
                "cellscaffold-parity",
                "cellprotocol",
                "purpose-interest",
                "mobile",
                "accessibility"
            ],
            constraints: [
                "Do not add a global AI provider or global action registry.",
                "All side effects require explicit user confirmation.",
                "Analyze, browse, open helper, preview, and advisory review are side-effect-free.",
                "Default UI must not show raw keypaths, stack traces, provider dumps, signatures, or execution scopes.",
                "Renderer parity is semantic and contractual, not pixel-perfect.",
                "Do not leak data from cells the requester lacks grants for.",
                "Use portable skeleton contracts before adding Binding-only behavior."
            ],
            sourceRefs: [
                "Binding",
                "CellScaffold/Porthole",
                "CellProtocol Skeleton and CellConfiguration contracts"
            ]
        )
    }
}

public struct AdvisorPanelSpawnTask: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var advisorID: String
    public var title: String
    public var prompt: String
    public var status: String
    public var outputContract: String
    public var sideEffectBoundary: String

    public init(
        id: String,
        advisorID: String,
        title: String,
        prompt: String,
        status: String = "queued_local_artifact",
        outputContract: String = "haven.advisor-review.v1",
        sideEffectBoundary: String = AdvisorPanelSpawnContract.sideEffectBoundary
    ) {
        self.id = id
        self.advisorID = advisorID
        self.title = title
        self.prompt = prompt
        self.status = status
        self.outputContract = outputContract
        self.sideEffectBoundary = sideEffectBoundary
    }
}

public struct AdvisorPanelSpawnArtifact: Codable, Equatable, Sendable, Identifiable {
    public var schema: String
    public var id: String
    public var createdAt: String
    public var topic: String
    public var purposeRef: String
    public var goal: String
    public var interests: [String]
    public var constraints: [String]
    public var sourceRefs: [String]
    public var dataClassification: String
    public var outputLanguage: String
    public var source: String
    public var sideEffectBoundary: String
    public var sharedBriefHash: String
    public var sharedBrief: String
    public var advisors: [AdvisorPanelSpec]
    public var tasks: [AdvisorPanelSpawnTask]
    public var synthesisPrompt: String
}

public struct AdvisorPanelSpawnRecord: Codable, Equatable, Sendable {
    public var filePath: String
    public var artifact: AdvisorPanelSpawnArtifact

    public init(filePath: String, artifact: AdvisorPanelSpawnArtifact) {
        self.filePath = filePath
        self.artifact = artifact
    }
}

public struct AdvisorPanelPlanSideEffects: Codable, Equatable, Sendable {
    public var writesFiles: Bool
    public var queuesRequests: Bool
    public var mutatesCells: Bool
    public var callsProviders: Bool
    public var executesProcesses: Bool

    public init(
        writesFiles: Bool = false,
        queuesRequests: Bool = false,
        mutatesCells: Bool = false,
        callsProviders: Bool = false,
        executesProcesses: Bool = false
    ) {
        self.writesFiles = writesFiles
        self.queuesRequests = queuesRequests
        self.mutatesCells = mutatesCells
        self.callsProviders = callsProviders
        self.executesProcesses = executesProcesses
    }
}

public struct AdvisorPanelPlanPersistence: Codable, Equatable, Sendable {
    public var written: Bool
    public var filePath: String?

    public init(written: Bool = false, filePath: String? = nil) {
        self.written = written
        self.filePath = filePath
    }
}

public struct AdvisorPanelPlanResult: Codable, Equatable, Sendable {
    public var schema: String
    public var status: String
    public var sideEffects: AdvisorPanelPlanSideEffects
    public var persistence: AdvisorPanelPlanPersistence
    public var artifact: AdvisorPanelSpawnArtifact

    public init(
        schema: String = AdvisorPanelPlanContract.schema,
        status: String = AdvisorPanelPlanContract.status,
        sideEffects: AdvisorPanelPlanSideEffects = AdvisorPanelPlanSideEffects(),
        persistence: AdvisorPanelPlanPersistence = AdvisorPanelPlanPersistence(),
        artifact: AdvisorPanelSpawnArtifact
    ) {
        self.schema = schema
        self.status = status
        self.sideEffects = sideEffects
        self.persistence = persistence
        self.artifact = artifact
    }
}

public enum AdvisorPanelSpawnError: Error, LocalizedError, Equatable, Sendable {
    case emptyTopic
    case emptyPurposeRef
    case emptyGoal
    case emptyBrief
    case noAdvisors

    public var errorDescription: String? {
        switch self {
        case .emptyTopic:
            return "Advisor panel spawn requires a non-empty topic."
        case .emptyPurposeRef:
            return "Advisor panel spawn requires a non-empty purposeRef."
        case .emptyGoal:
            return "Advisor panel spawn requires a non-empty measurable goal."
        case .emptyBrief:
            return "Advisor panel spawn requires a non-empty brief."
        case .noAdvisors:
            return "Advisor panel spawn requires at least one advisor."
        }
    }
}

public struct AdvisorPanelSpawnService {
    private let paths: RuntimePaths
    private let fileManager: FileManager
    private let now: @Sendable () -> Date

    public init(
        paths: RuntimePaths,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.paths = paths
        self.fileManager = fileManager
        self.now = now
    }

    @discardableResult
    public func plan(_ request: AdvisorPanelSpawnRequest) throws -> AdvisorPanelPlanResult {
        let request = try normalized(request)
        let artifact = makeArtifact(
            request: request,
            createdAt: iso8601String(now()),
            taskStatus: "planned_not_queued"
        )
        return AdvisorPanelPlanResult(artifact: artifact)
    }

    @discardableResult
    public func spawn(
        _ request: AdvisorPanelSpawnRequest,
        outDirectory: URL? = nil
    ) throws -> AdvisorPanelSpawnRecord {
        let request = try normalized(request)
        let artifact = makeArtifact(
            request: request,
            createdAt: iso8601String(now()),
            taskStatus: "queued_local_artifact"
        )
        let directory = outDirectory ?? paths.outputDirectory
            .appendingPathComponent(AdvisorPanelSpawnContract.directoryName, isDirectory: true)
        let fileURL = directory.appendingPathComponent("\(artifact.id).json")
        try writeJSON(artifact, to: fileURL)
        return AdvisorPanelSpawnRecord(filePath: fileURL.path, artifact: artifact)
    }

    private func makeArtifact(
        request: AdvisorPanelSpawnRequest,
        createdAt: String,
        taskStatus: String
    ) -> AdvisorPanelSpawnArtifact {
        let id = "advisor-panel-\(slug(request.topic))-\(slug(createdAt))"
        let briefHash = sha256Hex(request.brief)
        let tasks = request.advisors.map { advisor in
            AdvisorPanelSpawnTask(
                id: "\(id)-\(slug(advisor.id))",
                advisorID: advisor.id,
                title: "\(advisor.displayName): \(request.topic)",
                prompt: prompt(for: advisor, request: request, sharedBriefHash: briefHash),
                status: taskStatus
            )
        }
        return AdvisorPanelSpawnArtifact(
            schema: AdvisorPanelSpawnContract.schema,
            id: id,
            createdAt: createdAt,
            topic: request.topic,
            purposeRef: request.purposeRef,
            goal: request.goal,
            interests: request.interests,
            constraints: request.constraints,
            sourceRefs: request.sourceRefs,
            dataClassification: request.dataClassification,
            outputLanguage: request.outputLanguage,
            source: AdvisorPanelSpawnContract.source,
            sideEffectBoundary: AdvisorPanelSpawnContract.sideEffectBoundary,
            sharedBriefHash: briefHash,
            sharedBrief: request.brief,
            advisors: request.advisors,
            tasks: tasks,
            synthesisPrompt: synthesisPrompt(for: request, taskIDs: tasks.map(\.id))
        )
    }

    private func normalized(_ request: AdvisorPanelSpawnRequest) throws -> AdvisorPanelSpawnRequest {
        let topic = try required(request.topic, error: .emptyTopic)
        let purposeRef = try required(request.purposeRef, error: .emptyPurposeRef)
        let goal = try required(request.goal, error: .emptyGoal)
        let brief = try required(request.brief, error: .emptyBrief)
        let advisors = request.advisors
            .map { advisor in
                AdvisorPanelSpec(
                    id: normalizedNonEmpty(advisor.id) ?? slug(advisor.displayName),
                    displayName: normalizedNonEmpty(advisor.displayName) ?? advisor.id,
                    role: normalizedNonEmpty(advisor.role) ?? "Review the task from this advisor's perspective.",
                    preferredBackend: normalizedNonEmpty(advisor.preferredBackend) ?? "local_or_reviewed",
                    focus: advisor.focus.compactMap(normalizedNonEmpty)
                )
            }
            .filter { !$0.id.isEmpty && !$0.displayName.isEmpty }
        guard advisors.isEmpty == false else {
            throw AdvisorPanelSpawnError.noAdvisors
        }
        return AdvisorPanelSpawnRequest(
            topic: topic,
            purposeRef: purposeRef,
            goal: goal,
            brief: brief,
            interests: request.interests.compactMap(normalizedNonEmpty),
            constraints: request.constraints.compactMap(normalizedNonEmpty),
            sourceRefs: request.sourceRefs.compactMap(normalizedNonEmpty),
            dataClassification: normalizedNonEmpty(request.dataClassification) ?? "repo_local_context",
            outputLanguage: normalizedNonEmpty(request.outputLanguage) ?? "Norwegian",
            advisors: advisors
        )
    }

    private func prompt(
        for advisor: AdvisorPanelSpec,
        request: AdvisorPanelSpawnRequest,
        sharedBriefHash: String
    ) -> String {
        """
        You are \(advisor.displayName).

        Role:
        \(advisor.role)

        Topic:
        \(request.topic)

        Purpose:
        \(request.purposeRef)

        Goal:
        \(request.goal)

        Shared brief hash:
        \(sharedBriefHash)

        Shared brief:
        \(request.brief)

        Interests:
        \(joined(request.interests))

        Constraints:
        \(joined(request.constraints))

        Source references:
        \(joined(request.sourceRefs))

        Data classification:
        \(request.dataClassification)

        Required output language:
        \(request.outputLanguage)

        Output contract:
        Return haven.advisor-review.v1 with: summary, supportedClaims, counterClaims, userValueRisks, \
        CellProtocolConstraints, CellScaffoldParityChecks, measurableAcceptanceCriteria, recommendedTests, \
        and openQuestions. Be explicit about what is evidence, what is inference, and what remains unverified.

        Safety:
        This task is review-only. Do not run scripts, call providers, send notifications, mutate cells, accept suggestions, \
        or assume grants/capabilities that are not in the supplied context.
        """
    }

    private func synthesisPrompt(for request: AdvisorPanelSpawnRequest, taskIDs: [String]) -> String {
        """
        Synthesize advisor outputs for \(request.topic).

        Purpose: \(request.purposeRef)
        Goal: \(request.goal)
        Advisor task IDs: \(joined(taskIDs))

        Produce a decision note with:
        - the recommended Binding GUI contract
        - measurable quality gates
        - CellProtocol ownership/grant/side-effect constraints
        - CellScaffold parity requirements
        - implementation tasks split into skeleton/configuration, Binding renderer, and runtime/cell work
        - evidence that must be collected before claiming production readiness
        """
    }

    private func writeJSON<T: Encodable>(_ value: T, to fileURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try data.write(to: fileURL, options: [.atomic])
    }

    private func required(_ value: String, error: AdvisorPanelSpawnError) throws -> String {
        guard let normalized = normalizedNonEmpty(value) else {
            throw error
        }
        return normalized
    }

    private func normalizedNonEmpty(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func joined(_ values: [String]) -> String {
        values.isEmpty ? "- none supplied" : values.map { "- \($0)" }.joined(separator: "\n")
    }

    private func slug(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let chars = value.lowercased().unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(chars)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_."))
        return collapsed.isEmpty ? UUID().uuidString.lowercased() : collapsed
    }

    private func iso8601String(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private func sha256Hex(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
