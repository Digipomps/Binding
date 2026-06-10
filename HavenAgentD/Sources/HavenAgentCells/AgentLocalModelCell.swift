import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import CellBase

public struct AgentLocalModelProfile: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var summary: String
    public var providerID: String
    public var model: String
    public var repoID: String
    public var quantization: String
    public var parameterCount: String
    public var role: String
    public var defaultPort: Int
    public var purposeRefs: [String]
    public var interests: [String]
    public var privacyLevel: String
    public var executionScope: String
    public var gdprProcessingNote: String
    public var isExperimental: Bool
    public var sourceURL: String

    public func asObject() -> Object {
        [
            "id": .string(id),
            "title": .string(title),
            "summary": .string(summary),
            "providerID": .string(providerID),
            "model": .string(model),
            "repoID": .string(repoID),
            "quantization": .string(quantization),
            "parameterCount": .string(parameterCount),
            "role": .string(role),
            "defaultPort": .integer(defaultPort),
            "purposeRefs": .list(purposeRefs.map(ValueType.string)),
            "interests": .list(interests.map(ValueType.string)),
            "privacyLevel": .string(privacyLevel),
            "executionScope": .string(executionScope),
            "gdprProcessingNote": .string(gdprProcessingNote),
            "isExperimental": .bool(isExperimental),
            "sourceURL": .string(sourceURL)
        ]
    }

    public static let qwen25SmallTest = AgentLocalModelProfile(
        id: "qwen2.5-0.5b-instruct-q4_k_m",
        title: "Qwen 2.5 0.5B Instruct (test)",
        summary: "Tiny local playground model for fast AgentD and Co-Pilot integration tests.",
        providerID: "agent-qwen-test",
        model: "Qwen/Qwen2.5-0.5B-Instruct-GGUF:Q4_K_M",
        repoID: "Qwen/Qwen2.5-0.5B-Instruct-GGUF",
        quantization: "Q4_K_M",
        parameterCount: "0.5B",
        role: "test-playground",
        defaultPort: 8080,
        purposeRefs: [
            "personal.ai.provider.local-llm.test",
            "personal.chat.assist.local-model-playground",
            "agent.local-model.test"
        ],
        interests: [
            "qwen",
            "test",
            "playground",
            "local",
            "offline",
            "no-network",
            "agentd",
            "llama-server"
        ],
        privacyLevel: "local_test_runtime",
        executionScope: "local_agent_loopback",
        gdprProcessingNote: "Suitable for local integration tests only; not a production quality or policy claim.",
        isExperimental: true,
        sourceURL: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF"
    )

    public static let borealis4BInstructQ4KM = AgentLocalModelProfile(
        id: "borealis-4b-instruct-q4_k_m",
        title: "Borealis 4B Instruct Q4_K_M",
        summary: "Norwegian/EU local instruction model profile for private Co-Pilot tasks that need more than Apple Intelligence can offer.",
        providerID: "agent-borealis",
        model: "NbAiLab/borealis-4b-instruct-preview-gguf:Q4_K_M",
        repoID: "NbAiLab/borealis-4b-instruct-preview-gguf",
        quantization: "Q4_K_M",
        parameterCount: "4B",
        role: "gdpr-local-norwegian-assistant",
        defaultPort: 8082,
        purposeRefs: [
            "personal.ai.provider.agent-local-model",
            "personal.ai.provider.gdpr-local-processing",
            "personal.chat.assist.private-local-model",
            "personal.chat.assist.norwegian-language",
            "agent.local-model.gdpr-safe-assistant"
        ],
        interests: [
            "agentd",
            "borealis",
            "nbailab",
            "norwegian",
            "norsk",
            "bokmal",
            "nynorsk",
            "eu-region",
            "gdpr",
            "personvern",
            "local",
            "offline",
            "private",
            "no-network",
            "llama-server"
        ],
        privacyLevel: "local_agent_loopback_no_external_provider",
        executionScope: "local_agent",
        gdprProcessingNote: "Prompt and response stay on the operator-controlled local AgentD backend when the model is served on loopback; this does not by itself replace DPIA, retention policy or agreement grants.",
        isExperimental: true,
        sourceURL: "https://huggingface.co/NbAiLab/borealis-4b-instruct-preview-gguf"
    )

    public static let knownProfiles: [AgentLocalModelProfile] = [
        .qwen25SmallTest,
        .borealis4BInstructQ4KM
    ]

    public static func resolve(_ value: String?) -> AgentLocalModelProfile? {
        guard let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !normalized.isEmpty else {
            return nil
        }
        return knownProfiles.first { profile in
            let aliases = [
                profile.id,
                profile.model,
                profile.repoID,
                profile.providerID,
                profile.title
            ].map { $0.lowercased() }
            return aliases.contains(normalized)
                || normalized == "\(profile.repoID.lowercased()):\(profile.quantization.lowercased())"
        }
    }
}

public struct AgentLocalModelBackendConfig: Codable, Equatable, Sendable {
    public var profileID: String
    public var providerID: String
    public var baseURL: String
    public var apiPath: String
    public var model: String
    public var timeoutMs: Int
    public var allowNonLoopback: Bool

    public init(
        profileID: String = "custom",
        providerID: String,
        baseURL: String,
        apiPath: String,
        model: String,
        timeoutMs: Int,
        allowNonLoopback: Bool = false
    ) {
        self.profileID = profileID
        self.providerID = providerID
        self.baseURL = baseURL
        self.apiPath = apiPath
        self.model = model
        self.timeoutMs = timeoutMs
        self.allowNonLoopback = allowNonLoopback
    }

    public static func load(environment: [String: String] = ProcessInfo.processInfo.environment) -> AgentLocalModelBackendConfig {
        let requestedProfile = normalized(environment["HAVEN_AGENTD_LOCAL_LLM_PROFILE"])
            ?? normalized(environment["LOCAL_LLM_PROFILE"])
        let explicitModel = normalized(environment["HAVEN_AGENTD_LOCAL_LLM_MODEL"])
            ?? normalized(environment["LOCAL_LLM_DEFAULT_MODEL"])
        let profile = AgentLocalModelProfile.resolve(requestedProfile)
            ?? AgentLocalModelProfile.resolve(explicitModel)
            ?? .qwen25SmallTest
        return AgentLocalModelBackendConfig(
            profileID: profile.id,
            providerID: normalized(environment["HAVEN_AGENTD_LOCAL_LLM_PROVIDER_ID"])
                ?? normalized(environment["LOCAL_LLM_PROVIDER_ID"])
                ?? profile.providerID,
            baseURL: normalized(environment["HAVEN_AGENTD_LOCAL_LLM_BASE_URL"])
                ?? normalized(environment["LOCAL_LLM_BASE_URL"])
                ?? "http://127.0.0.1:\(profile.defaultPort)",
            apiPath: normalized(environment["HAVEN_AGENTD_LOCAL_LLM_API_PATH"])
                ?? normalized(environment["LOCAL_LLM_API_PATH"])
                ?? "/v1/chat/completions",
            model: explicitModel ?? profile.model,
            timeoutMs: positiveInt(environment["HAVEN_AGENTD_LOCAL_LLM_TIMEOUT_MS"])
                ?? positiveInt(environment["LOCAL_LLM_TIMEOUT_MS"])
                ?? 8_000,
            allowNonLoopback: bool(environment["HAVEN_AGENTD_LOCAL_LLM_ALLOW_NON_LOOPBACK"]) ?? false
        )
    }

    public func endpointURL() throws -> URL {
        guard var components = URLComponents(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw AgentLocalModelError.invalidBackendURL(baseURL)
        }
        let normalizedPath = apiPath.hasPrefix("/") ? apiPath : "/\(apiPath)"
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let suffixPath = normalizedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = ([basePath, suffixPath].filter { !$0.isEmpty }).joined(separator: "/")
        if components.path.hasPrefix("/") == false {
            components.path = "/" + components.path
        }
        guard let url = components.url else {
            throw AgentLocalModelError.invalidBackendURL(baseURL)
        }
        guard allowNonLoopback || Self.isLoopback(url) else {
            throw AgentLocalModelError.nonLoopbackBackend(url.host ?? baseURL)
        }
        return url
    }

    public func asObject() -> Object {
        [
            "profileID": .string(profileID),
            "providerID": .string(providerID),
            "baseURL": .string(baseURL),
            "apiPath": .string(apiPath),
            "model": .string(model),
            "timeoutMs": .integer(timeoutMs),
            "allowNonLoopback": .bool(allowNonLoopback)
        ]
    }

    private static func isLoopback(_ url: URL) -> Bool {
        guard let host = url.host?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }
        return ["127.0.0.1", "localhost", "::1", "0:0:0:0:0:0:0:1"].contains(host)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func positiveInt(_ value: String?) -> Int? {
        guard let value = normalized(value), let intValue = Int(value), intValue > 0 else {
            return nil
        }
        return intValue
    }

    private static func bool(_ value: String?) -> Bool? {
        guard let value = normalized(value)?.lowercased() else {
            return nil
        }
        switch value {
        case "1", "true", "yes", "y":
            return true
        case "0", "false", "no", "n":
            return false
        default:
            return nil
        }
    }
}

public struct AgentLocalModelInvokeRequest: Equatable, Sendable {
    public var prompt: String
    public var systemPrompt: String
    public var temperature: Double?
    public var maxTokens: Int?
    public var deterministicMode: Bool
    public var correlationID: String?
    public var requestedProfileID: String?

    public init(
        prompt: String,
        systemPrompt: String,
        temperature: Double?,
        maxTokens: Int?,
        deterministicMode: Bool,
        correlationID: String?,
        requestedProfileID: String? = nil
    ) {
        self.prompt = prompt
        self.systemPrompt = systemPrompt
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.deterministicMode = deterministicMode
        self.correlationID = correlationID
        self.requestedProfileID = requestedProfileID
    }
}

public struct AgentLocalModelInvokeResponse: Equatable, Sendable {
    public var providerID: String
    public var model: String
    public var outputText: String
    public var finishReason: String?
    public var inputTokens: Int?
    public var outputTokens: Int?

    public init(
        providerID: String,
        model: String,
        outputText: String,
        finishReason: String? = nil,
        inputTokens: Int? = nil,
        outputTokens: Int? = nil
    ) {
        self.providerID = providerID
        self.model = model
        self.outputText = outputText
        self.finishReason = finishReason
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

public protocol AgentLocalModelInvoking: Sendable {
    func invoke(
        config: AgentLocalModelBackendConfig,
        request: AgentLocalModelInvokeRequest
    ) async throws -> AgentLocalModelInvokeResponse
}

public struct AgentLocalModelHTTPClient: AgentLocalModelInvoking {
    public init() {}

    public func invoke(
        config: AgentLocalModelBackendConfig,
        request: AgentLocalModelInvokeRequest
    ) async throws -> AgentLocalModelInvokeResponse {
        let url = try config.endpointURL()
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = TimeInterval(config.timeoutMs) / 1_000.0
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: Self.body(config: config, request: request))

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.timeoutIntervalForRequest = urlRequest.timeoutInterval
        sessionConfig.timeoutIntervalForResource = urlRequest.timeoutInterval
        let session = URLSession(configuration: sessionConfig)
        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AgentLocalModelError.invalidBackendResponse("non-HTTP response")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let preview = String(data: data, encoding: .utf8).map { Self.preview($0, limit: 600) } ?? ""
            throw AgentLocalModelError.backendFailure("HTTP \(httpResponse.statusCode): \(preview)")
        }
        return try Self.decodeResponse(data, fallbackProviderID: config.providerID, fallbackModel: config.model)
    }

    private static func body(config: AgentLocalModelBackendConfig, request: AgentLocalModelInvokeRequest) -> [String: Any] {
        var body: [String: Any] = [
            "model": config.model,
            "stream": false,
            "messages": [
                ["role": "system", "content": request.systemPrompt],
                ["role": "user", "content": request.prompt]
            ]
        ]
        body["temperature"] = request.deterministicMode ? 0 : request.temperature
        if let maxTokens = request.maxTokens {
            body["max_tokens"] = maxTokens
        }
        return body
    }

    private static func decodeResponse(
        _ data: Data,
        fallbackProviderID: String,
        fallbackModel: String
    ) throws -> AgentLocalModelInvokeResponse {
        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AgentLocalModelError.invalidBackendResponse("response was not a JSON object")
        }
        let model = payload["model"] as? String ?? fallbackModel
        let outputText = chatCompletionText(payload)
            ?? responsesOutputText(payload)
            ?? payload["response"] as? String
            ?? payload["text"] as? String
        guard let outputText, !outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentLocalModelError.invalidBackendResponse("missing output text")
        }
        let usage = payload["usage"] as? [String: Any]
        return AgentLocalModelInvokeResponse(
            providerID: fallbackProviderID,
            model: model,
            outputText: outputText,
            finishReason: firstChoice(payload)?["finish_reason"] as? String,
            inputTokens: usage?["prompt_tokens"] as? Int ?? usage?["input_tokens"] as? Int,
            outputTokens: usage?["completion_tokens"] as? Int ?? usage?["output_tokens"] as? Int
        )
    }

    private static func chatCompletionText(_ payload: [String: Any]) -> String? {
        guard let choice = firstChoice(payload) else {
            return nil
        }
        if let message = choice["message"] as? [String: Any] {
            if let content = message["content"] as? String {
                return content
            }
            if let parts = message["content"] as? [[String: Any]] {
                return parts.compactMap { $0["text"] as? String }.joined()
            }
        }
        return choice["text"] as? String
    }

    private static func responsesOutputText(_ payload: [String: Any]) -> String? {
        if let outputText = payload["output_text"] as? String {
            return outputText
        }
        guard let output = payload["output"] as? [[String: Any]] else {
            return nil
        }
        return output.compactMap { item -> String? in
            guard let content = item["content"] as? [[String: Any]] else {
                return nil
            }
            return content.compactMap { $0["text"] as? String }.joined()
        }.joined()
    }

    private static func firstChoice(_ payload: [String: Any]) -> [String: Any]? {
        guard let choices = payload["choices"] as? [[String: Any]] else {
            return nil
        }
        return choices.first
    }

    private static func preview(_ text: String, limit: Int) -> String {
        guard text.count > limit else {
            return text
        }
        return String(text.prefix(limit)) + "..."
    }
}

public final class AgentLocalModelCell: GeneralCell {
    private enum CodingKeys: String, CodingKey {
        case version
        case totalInvocations
        case lastInvocation
        case lastBackendStatus
        case lastError
    }

    private struct LastInvocationSnapshot: Codable, Equatable, Sendable {
        var status: String
        var providerID: String
        var model: String
        var invokeTimeMs: Int
        var outputPreview: String
        var inputTokens: Int?
        var outputTokens: Int?
        var correlationID: String?

        static let empty = LastInvocationSnapshot(
            status: "idle",
            providerID: "",
            model: "",
            invokeTimeMs: 0,
            outputPreview: "",
            inputTokens: nil,
            outputTokens: nil,
            correlationID: nil
        )

        func asObject() -> Object {
            [
                "status": .string(status),
                "providerID": .string(providerID),
                "model": .string(model),
                "invokeTimeMs": .integer(invokeTimeMs),
                "outputPreview": .string(outputPreview),
                "inputTokens": inputTokens.map(ValueType.integer) ?? .null,
                "outputTokens": outputTokens.map(ValueType.integer) ?? .null,
                "correlationID": correlationID.map(ValueType.string) ?? .null
            ]
        }
    }

    nonisolated(unsafe) public static var clientFactory: @Sendable () -> any AgentLocalModelInvoking = {
        AgentLocalModelHTTPClient()
    }
    nonisolated(unsafe) public static var backendConfigFactory: @Sendable () -> AgentLocalModelBackendConfig = {
        AgentLocalModelBackendConfig.load()
    }

    private let client: any AgentLocalModelInvoking
    private let stateQueue = DispatchQueue(label: "AgentLocalModelCell.State")
    private var totalInvocations: Int
    private var lastInvocation: LastInvocationSnapshot
    private var lastBackendStatus: String
    private var lastError: String?

    public required init(owner: Identity) async {
        self.client = Self.clientFactory()
        self.totalInvocations = 0
        self.lastInvocation = .empty
        self.lastBackendStatus = "unknown"
        self.lastError = nil
        await super.init(owner: owner)
        await setupPermissions(owner: owner)
        await setupKeys(owner: owner)
    }

    public required init(from decoder: Decoder) throws {
        self.client = Self.clientFactory()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.totalInvocations = (try? container.decode(Int.self, forKey: .totalInvocations)) ?? 0
        self.lastInvocation = (try? container.decode(LastInvocationSnapshot.self, forKey: .lastInvocation)) ?? .empty
        self.lastBackendStatus = (try? container.decode(String.self, forKey: .lastBackendStatus)) ?? "unknown"
        self.lastError = try? container.decodeIfPresent(String.self, forKey: .lastError)
        try super.init(from: decoder)
        let cell = UncheckedSendableReference(value: self)
        Task {
            let requester = Identity()
            let decodedOwner = (try? await cell.value.getOwner(requester: requester)) ?? requester
            await cell.value.setupPermissions(owner: decodedOwner)
            await cell.value.setupKeys(owner: decodedOwner)
        }
    }

    public override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("1", forKey: .version)
        try container.encode(totalInvocations, forKey: .totalInvocations)
        try container.encode(lastInvocation, forKey: .lastInvocation)
        try container.encode(lastBackendStatus, forKey: .lastBackendStatus)
        try container.encodeIfPresent(lastError, forKey: .lastError)
    }

    private func setupPermissions(owner: Identity) async {
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("r---", for: "contracts")
        agreementTemplate.addGrant("rw--", for: "llm.health")
        agreementTemplate.addGrant("rw--", for: "llm.generate")
        agreementTemplate.addGrant("r---", for: "flow")
    }

    private func setupKeys(owner: Identity) async {
        await addInterceptForGet(requester: owner, key: "state", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.hasAccess("r---", at: "state", requester: requester) else { return .string("denied") }
            return self.stateValue()
        })

        await addInterceptForGet(requester: owner, key: "contracts", getValueIntercept: { [weak self] _, requester in
            guard let self else { return .string("failure") }
            guard await self.hasAccess("r---", at: "contracts", requester: requester) else { return .string("denied") }
            return self.contractsValue()
        })

        await addInterceptForSet(requester: owner, key: "llm.health", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.hasAccess("rw--", at: "llm.health", requester: requester) else { return .string("denied") }
            return await self.healthValue(from: value, requester: requester)
        })

        await addInterceptForSet(requester: owner, key: "llm.generate", setValueIntercept: { [weak self] _, value, requester in
            guard let self else { return .string("failure") }
            guard await self.hasAccess("rw--", at: "llm.generate", requester: requester) else { return .string("denied") }
            return await self.generateValue(from: value, requester: requester)
        })
    }

    private func hasAccess(_ grant: String, at keypath: String, requester: Identity) async -> Bool {
        if await validateAccess(grant, at: keypath, for: requester) {
            return true
        }
        return await LocalControlCellAccess.isPairedOperator(requester)
    }

    private func stateValue() -> ValueType {
        let snapshot = stateQueue.sync {
            (
                totalInvocations: totalInvocations,
                lastInvocation: lastInvocation,
                lastBackendStatus: lastBackendStatus,
                lastError: lastError
            )
        }
        let backend = Self.backendConfigFactory()
        return .object([
            "status": .string("ready"),
            "endpoint": .string("cell:///agent/local-model"),
            "capabilities": .list([.string("llm.health"), .string("llm.generate")]),
            "runtimeTarget": .string("macos-agentd"),
            "backendStatus": .string(snapshot.lastBackendStatus),
            "backend": .object(backend.asObject()),
            "selectedProfile": AgentLocalModelProfile.resolve(backend.profileID).map { .object($0.asObject()) } ?? .null,
            "modelProfiles": .list(AgentLocalModelProfile.knownProfiles.map { .object($0.asObject()) }),
            "activationPurposes": .list(Self.activationPurposes().map { .object($0) }),
            "selectedModel": .string(backend.model),
            "totalInvocations": .integer(snapshot.totalInvocations),
            "lastInvocation": .object(snapshot.lastInvocation.asObject()),
            "lastError": snapshot.lastError.map(ValueType.string) ?? .null,
            "mobileAccess": .object([
                "strategy": .string("Use HAVENAgentD through CellProtocol/Porthole. Direct iPhone/iPad execution requires a native on-device model host that is not implemented in this package yet."),
                "controlBridgeRoute": .string("local-model")
            ])
        ])
    }

    private func contractsValue() -> ValueType {
        .object([
            "state": .object([
                "returns": .string("Local model backend config, model selection, health and invocation audit without prompt/output secrets.")
            ]),
            "llm.health": .object([
                "expects": .object([
                    "prompt": .string("optional String, defaults to a short health prompt")
                ]),
                "returns": .string("healthy/unhealthy status for the configured local model backend")
            ]),
            "llm.generate": .object([
                "expects": .object([
                    "prompt": .string("required String, or String payload"),
                    "systemPrompt": .string("optional String"),
                    "temperature": .string("optional Double"),
                    "maxTokens": .string("optional Int"),
                    "deterministicMode": .string("optional Bool, defaults true"),
                    "modelProfile": .string("optional profile id; must match the running local backend profile"),
                    "correlationID": .string("optional String")
                ]),
                "flowTopic": .string("agent.localModel")
            ])
        ])
    }

    private func healthValue(from value: ValueType, requester: Identity) async -> ValueType {
        let prompt = stringValue(valueAt("prompt", in: value)) ?? "Reply exactly: ok"
        return await invokeValue(
            request: AgentLocalModelInvokeRequest(
                prompt: prompt,
                systemPrompt: "You are a local model health check. Reply with a short status only.",
                temperature: 0,
                maxTokens: 8,
                deterministicMode: true,
                correlationID: stringValue(valueAt("correlationID", in: value)) ?? stringValue(valueAt("correlationId", in: value)),
                requestedProfileID: requestedProfileID(from: value)
            ),
            surface: "llm.health",
            requester: requester,
            includeOutput: true
        )
    }

    private func generateValue(from value: ValueType, requester: Identity) async -> ValueType {
        guard let prompt = normalizedString(stringValue(value) ?? stringValue(valueAt("prompt", in: value)) ?? stringValue(valueAt("message", in: value))) else {
            return errorValue(status: "invalidRequest", message: "llm.generate requires a non-empty prompt.")
        }
        let request = AgentLocalModelInvokeRequest(
            prompt: prompt,
            systemPrompt: normalizedString(stringValue(valueAt("systemPrompt", in: value)) ?? stringValue(valueAt("system_prompt", in: value)))
                ?? defaultSystemPrompt(),
            temperature: doubleValue(valueAt("temperature", in: value)),
            maxTokens: intValue(valueAt("maxTokens", in: value)) ?? intValue(valueAt("max_tokens", in: value)),
            deterministicMode: boolValue(valueAt("deterministicMode", in: value)) ?? boolValue(valueAt("deterministic_mode", in: value)) ?? true,
            correlationID: stringValue(valueAt("correlationID", in: value)) ?? stringValue(valueAt("correlationId", in: value)) ?? stringValue(valueAt("correlation_id", in: value)),
            requestedProfileID: requestedProfileID(from: value)
        )
        return await invokeValue(
            request: request,
            surface: "llm.generate",
            requester: requester,
            includeOutput: true
        )
    }

    private func invokeValue(
        request: AgentLocalModelInvokeRequest,
        surface: String,
        requester: Identity,
        includeOutput: Bool
    ) async -> ValueType {
        let started = Date()
        let backend = Self.backendConfigFactory()
        if let requestedProfileID = request.requestedProfileID,
           requestedProfileID != backend.profileID {
            return .object([
                "status": .string("modelProfileUnavailable"),
                "requestedProfileID": .string(requestedProfileID),
                "selectedProfileID": .string(backend.profileID),
                "availableProfiles": .list(AgentLocalModelProfile.knownProfiles.map { .object($0.asObject()) }),
                "error": .string("The requested model profile is not the model currently served by this AgentD local model backend.")
            ])
        }
        do {
            let response = try await client.invoke(config: backend, request: request)
            let durationMs = Int(Date().timeIntervalSince(started) * 1_000)
            let snapshot = LastInvocationSnapshot(
                status: "completed",
                providerID: response.providerID,
                model: response.model,
                invokeTimeMs: durationMs,
                outputPreview: Self.preview(response.outputText, limit: 1_000),
                inputTokens: response.inputTokens,
                outputTokens: response.outputTokens,
                correlationID: request.correlationID
            )
            stateQueue.sync {
                self.totalInvocations += 1
                self.lastInvocation = snapshot
                self.lastBackendStatus = "healthy"
                self.lastError = nil
            }
            await emitInvocationEvent(surface: surface, status: "completed", snapshot: snapshot, error: nil, requester: requester)
            var object: Object = [
                "status": .string(surface == "llm.health" ? "healthy" : "completed"),
                "providerID": .string(response.providerID),
                "model": .string(response.model),
                "finishReason": response.finishReason.map(ValueType.string) ?? .null,
                "durationMs": .integer(durationMs),
                "usage": .object([
                    "inputTokens": response.inputTokens.map(ValueType.integer) ?? .null,
                    "outputTokens": response.outputTokens.map(ValueType.integer) ?? .null
                ]),
                "correlationID": request.correlationID.map(ValueType.string) ?? .null
            ]
            if includeOutput {
                object["outputText"] = .string(response.outputText)
            }
            return .object(object)
        } catch {
            let durationMs = Int(Date().timeIntervalSince(started) * 1_000)
            let message = error.localizedDescription
            let snapshot = LastInvocationSnapshot(
                status: "failed",
                providerID: backend.providerID,
                model: backend.model,
                invokeTimeMs: durationMs,
                outputPreview: "",
                inputTokens: nil,
                outputTokens: nil,
                correlationID: request.correlationID
            )
            stateQueue.sync {
                self.totalInvocations += 1
                self.lastInvocation = snapshot
                self.lastBackendStatus = "failed"
                self.lastError = message
            }
            await emitInvocationEvent(surface: surface, status: "failed", snapshot: snapshot, error: message, requester: requester)
            return errorValue(status: surface == "llm.health" ? "unhealthy" : "failed", message: message)
        }
    }

    private func requestedProfileID(from value: ValueType) -> String? {
        let requested = stringValue(valueAt("modelProfile", in: value))
            ?? stringValue(valueAt("model_profile", in: value))
            ?? stringValue(valueAt("profileID", in: value))
            ?? stringValue(valueAt("profileId", in: value))
        return AgentLocalModelProfile.resolve(requested)?.id ?? normalizedString(requested)
    }

    private static func activationPurposes() -> [Object] {
        AgentLocalModelProfile.knownProfiles.map { profile in
            [
                "profileID": .string(profile.id),
                "title": .string(profile.title),
                "purposeRefs": .list(profile.purposeRefs.map(ValueType.string)),
                "interests": .list(profile.interests.map(ValueType.string)),
                "privacyLevel": .string(profile.privacyLevel),
                "executionScope": .string(profile.executionScope),
                "gdprProcessingNote": .string(profile.gdprProcessingNote),
                "isExperimental": .bool(profile.isExperimental)
            ]
        }
    }

    private func emitInvocationEvent(
        surface: String,
        status: String,
        snapshot: LastInvocationSnapshot,
        error: String?,
        requester: Identity
    ) async {
        var payload: Object = [
            "surface": .string(surface),
            "status": .string(status),
            "providerID": .string(snapshot.providerID),
            "model": .string(snapshot.model),
            "durationMs": .integer(snapshot.invokeTimeMs),
            "correlationID": snapshot.correlationID.map(ValueType.string) ?? .null
        ]
        payload["error"] = error.map(ValueType.string) ?? .null
        var flowElement = FlowElement(
            title: status == "completed" ? "agent.localModel.completed" : "agent.localModel.failed",
            content: .object(payload),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flowElement.topic = "agent.localModel"
        flowElement.origin = uuid
        pushFlowElement(flowElement, requester: requester)
    }

    private func defaultSystemPrompt() -> String {
        """
        You are a local language model hosted by HAVENAgentD.
        Treat model output as advisory and keep the response grounded in the supplied prompt.
        Do not claim access to hidden files, vaults, tools, phone sensors or private state.
        """
    }

    private func errorValue(status: String, message: String) -> ValueType {
        .object([
            "status": .string(status),
            "error": .string(message)
        ])
    }

    private static func preview(_ text: String, limit: Int) -> String {
        guard text.count > limit else {
            return text
        }
        return String(text.prefix(limit)) + "..."
    }

    private func valueAt(_ key: String, in value: ValueType) -> ValueType? {
        guard case let .object(object) = value else {
            return nil
        }
        return object[key]
    }

    private func normalizedString(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func stringValue(_ value: ValueType?) -> String? {
        guard case let .string(string)? = value else {
            return nil
        }
        return string
    }

    private func boolValue(_ value: ValueType?) -> Bool? {
        guard case let .bool(bool)? = value else {
            return nil
        }
        return bool
    }

    private func intValue(_ value: ValueType?) -> Int? {
        switch value {
        case .integer(let int)?:
            return int
        case .float(let double)?:
            return Int(double)
        case .number(let number)?:
            return Int(number)
        default:
            return nil
        }
    }

    private func doubleValue(_ value: ValueType?) -> Double? {
        switch value {
        case .float(let double)?:
            return double
        case .number(let number)?:
            return Double(number)
        case .integer(let int)?:
            return Double(int)
        default:
            return nil
        }
    }
}

public enum AgentLocalModelError: Error, LocalizedError, Equatable, Sendable {
    case invalidBackendURL(String)
    case nonLoopbackBackend(String)
    case backendFailure(String)
    case invalidBackendResponse(String)

    public var errorDescription: String? {
        switch self {
        case .invalidBackendURL(let value):
            return "Invalid local model backend URL: \(value)"
        case .nonLoopbackBackend(let host):
            return "Local model backend must be loopback-only unless HAVEN_AGENTD_LOCAL_LLM_ALLOW_NON_LOOPBACK=1 is set. Host: \(host)"
        case .backendFailure(let message):
            return "Local model backend failed: \(message)"
        case .invalidBackendResponse(let message):
            return "Invalid local model backend response: \(message)"
        }
    }
}
