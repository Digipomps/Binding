// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import CellBase

/// A chat provider that actually generates an answer by calling an external
/// language model over the network.
///
/// This cell is deliberately explicit about what it is: `privacyLevel` is
/// `external_provider` and `requiresNetwork` is `true`. The butler surface is
/// expected to name the provider and model in its receipt line whenever an
/// answer came from here, so the user is never left guessing whether text left
/// the device.
///
/// Configuration is read from the process environment so a demo build can be
/// pointed at a key from the Xcode scheme without the key entering the repo:
///
/// - `BINDING_REMOTE_LLM_API_KEY`   (required; empty key means "unavailable")
/// - `BINDING_REMOTE_LLM_PROVIDER`  ("anthropic" | "openai", default "anthropic")
/// - `BINDING_REMOTE_LLM_MODEL`     (default depends on provider)
/// - `BINDING_REMOTE_LLM_BASE_URL`  (optional override)
final class BindingRemoteLLMCell: BindingRuntimeBindingCell {
    private enum CodingKeys: String, CodingKey {
        case lastAnswer
        case backendStatus
    }

    nonisolated(unsafe) private var lastAnswer: Object = [:]
    nonisolated(unsafe) private var backendStatus = "not_checked"

    required init(owner: Identity) async {
        await super.init(owner: owner)
        await installRuntimeBindings(owner: owner)
        await markRuntimeBindingsInstalled()
    }

    nonisolated required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lastAnswer = (try? container.decode(Object.self, forKey: .lastAnswer)) ?? [:]
        backendStatus = (try? container.decode(String.self, forKey: .backendStatus)) ?? "not_checked"
        try super.init(from: decoder)
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lastAnswer, forKey: .lastAnswer)
        try container.encode(backendStatus, forKey: .backendStatus)
    }

    override func installRuntimeBindings(owner: Identity) async {
        for key in ["state", "llm.lastAnswer"] {
            ensureAgreementGrant("r---", for: key)
        }
        for key in ["llm.generate", "llm.health"] {
            ensureAgreementGrant("rw--", for: key)
        }

        await registerGet(key: "state", owner: owner, returns: .object([:])) { [weak self] requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("r---", at: "state", for: requester) else { return .string("denied") }
            return self.stateValue()
        }
        await registerGet(key: "llm.lastAnswer", owner: owner, returns: .object([:])) { [weak self] requester in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("r---", at: "llm.lastAnswer", for: requester) else { return .string("denied") }
            return .object(self.lastAnswer)
        }
        await registerSet(key: "llm.generate", owner: owner, input: .object([:]), returns: .object([:])) { [weak self] requester, value in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "llm.generate", for: requester) else { return .string("denied") }
            return await self.generate(value)
        }
        await registerSet(key: "llm.health", owner: owner, input: .object([:]), returns: .object([:])) { [weak self] requester, _ in
            guard let self else { return .string("failure") }
            guard await self.validateAccess("rw--", at: "llm.health", for: requester) else { return .string("denied") }
            self.backendStatus = Self.configuredAPIKey().isEmpty ? "not_configured" : "configured"
            return self.stateValue()
        }
    }

    // MARK: - State

    private func stateValue() -> ValueType {
        let configured = Self.configuredAPIKey().isEmpty == false
        let provider = Self.configuredProvider()
        let model = Self.configuredModel()
        return .object([
            "status": .string(configured ? "ready" : "unavailable"),
            "providerID": .string("binding.remote-llm"),
            "kind": .string("remote_llm"),
            "title": .string("Ekstern språkmodell"),
            "summary": .string("Formulerer svar i butler-chatten ved å sende teksten til \(Self.providerDisplayName(provider)). Teksten forlater enheten."),
            "backendStatus": .string(configured ? backendStatus : "not_configured"),
            "model": .string(model),
            "selectedModel": .string(model),
            "endpoint": .string("cell:///RemoteLLM"),
            "sourceCellName": .string("BindingRemoteLLMCell"),
            "capability": .string("llm.generate"),
            "privacyLevel": .string("external_provider"),
            "executionScope": .string("network"),
            "requiresNetwork": .bool(true),
            "requiresUserApproval": .bool(true),
            "canInvokeFromChat": .bool(true),
            "backend": .object([
                "provider": .string(provider),
                "providerDisplayName": .string(Self.providerDisplayName(provider)),
                "baseURL": .string(Self.configuredBaseURL()),
                "model": .string(model)
            ]),
            "purposeRefs": .list([
                .string("personal.ai.provider.remote-llm"),
                .string("personal.chat.assist.compose-answer")
            ]),
            "interests": .list([
                .string("assistant"),
                .string("chat"),
                .string("remote"),
                .string("language-model")
            ]),
            "lastAnswer": .object(lastAnswer)
        ])
    }

    // MARK: - Generation

    private func generate(_ value: ValueType) async -> ValueType {
        let payload = BindingChatValue.object(value) ?? [:]
        let prompt: String = BindingChatValue.string(payload["draft"])
            ?? BindingChatValue.string(payload["prompt"])
            ?? BindingChatValue.string(payload["text"])
            ?? BindingChatValue.string(value)
            ?? ""
        let trimmedPrompt = prompt.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard trimmedPrompt.isEmpty == false else {
            return failure(reason: "empty_prompt", message: "Ingen tekst å svare på.")
        }

        let apiKey = Self.configuredAPIKey()
        guard apiKey.isEmpty == false else {
            return failure(reason: "not_configured", message: "Ingen API-nøkkel er satt for den eksterne modellen.")
        }

        let systemPrompt = BindingChatValue.string(payload["system"]) ?? Self.defaultSystemPrompt
        let grounding = BindingChatValue.string(payload["grounding"])
        let provider = Self.configuredProvider()
        let model = Self.configuredModel()

        let started = Date()
        do {
            let answer: String
            switch provider {
            case "openai":
                answer = try await Self.callOpenAI(
                    apiKey: apiKey,
                    model: model,
                    systemPrompt: systemPrompt,
                    grounding: grounding,
                    prompt: trimmedPrompt
                )
            default:
                answer = try await Self.callAnthropic(
                    apiKey: apiKey,
                    model: model,
                    systemPrompt: systemPrompt,
                    grounding: grounding,
                    prompt: trimmedPrompt
                )
            }
            let elapsed = Date().timeIntervalSince(started)
            let trimmedAnswer = answer.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            guard trimmedAnswer.isEmpty == false else {
                return failure(reason: "empty_answer", message: "Modellen svarte tomt.")
            }
            backendStatus = "ok"
            let result: Object = [
                "ok": .bool(true),
                "status": .string("generated"),
                "answer": .string(trimmedAnswer),
                "providerID": .string("binding.remote-llm"),
                "providerKind": .string("remote_llm"),
                "provider": .string(provider),
                "providerDisplayName": .string(Self.providerDisplayName(provider)),
                "model": .string(model),
                "elapsedSeconds": .float(elapsed),
                "leftDevice": .bool(true),
                "receipt": .string("Svaret ble formulert av \(model) hos \(Self.providerDisplayName(provider)). Spørsmålet ditt forlot enheten.")
            ]
            lastAnswer = result
            return .object(result)
        } catch {
            backendStatus = "error"
            return failure(
                reason: "request_failed",
                message: Self.readableError(error)
            )
        }
    }

    private func failure(reason: String, message: String) -> ValueType {
        let result: Object = [
            "ok": .bool(false),
            "status": .string("unavailable"),
            "reason": .string(reason),
            "message": .string(message),
            "providerID": .string("binding.remote-llm"),
            "providerKind": .string("remote_llm"),
            "leftDevice": .bool(false)
        ]
        lastAnswer = result
        return .object(result)
    }

    // MARK: - Transport

    private static func callAnthropic(
        apiKey: String,
        model: String,
        systemPrompt: String,
        grounding: String?,
        prompt: String
    ) async throws -> String {
        let base = configuredBaseURL()
        guard let url = URL(string: base + "/v1/messages") else {
            throw BindingRemoteLLMError.badURL(base)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        var system = systemPrompt
        if let grounding, grounding.isEmpty == false {
            system += "\n\nKontekst du kan bruke:\n" + grounding
        }
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 700,
            "system": system,
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = root["content"] as? [[String: Any]]
        else {
            throw BindingRemoteLLMError.unexpectedResponse
        }
        let text = content
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
        guard text.isEmpty == false else { throw BindingRemoteLLMError.unexpectedResponse }
        return text
    }

    private static func callOpenAI(
        apiKey: String,
        model: String,
        systemPrompt: String,
        grounding: String?,
        prompt: String
    ) async throws -> String {
        let base = configuredBaseURL()
        guard let url = URL(string: base + "/v1/chat/completions") else {
            throw BindingRemoteLLMError.badURL(base)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + apiKey, forHTTPHeaderField: "Authorization")

        var messages: [[String: String]] = [["role": "system", "content": systemPrompt]]
        if let grounding, grounding.isEmpty == false {
            messages.append(["role": "system", "content": "Kontekst du kan bruke:\n" + grounding])
        }
        messages.append(["role": "user", "content": prompt])
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 700,
            "messages": messages
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)

        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = root["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let text = message["content"] as? String
        else {
            throw BindingRemoteLLMError.unexpectedResponse
        }
        return text
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw BindingRemoteLLMError.unexpectedResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data.prefix(400), encoding: .utf8) ?? ""
            throw BindingRemoteLLMError.httpStatus(http.statusCode, detail)
        }
    }

    private static func readableError(_ error: Error) -> String {
        switch error {
        case BindingRemoteLLMError.httpStatus(let code, _):
            switch code {
            case 401, 403:
                return "Modelltjenesten avviste nøkkelen (\(code))."
            case 429:
                return "Modelltjenesten er opptatt akkurat nå (429)."
            default:
                return "Modelltjenesten svarte \(code)."
            }
        case BindingRemoteLLMError.badURL(let base):
            return "Ugyldig adresse for modelltjenesten: \(base)"
        case BindingRemoteLLMError.unexpectedResponse:
            return "Uventet svarformat fra modelltjenesten."
        default:
            return "Fikk ikke kontakt med modelltjenesten."
        }
    }

    // MARK: - Configuration

    static let defaultSystemPrompt = """
    Du er butleren i HAVEN. Du svarer kort, konkret og på norsk, i en rolig og \
    vennlig tone. Du finner deg ikke på fakta: hvis du ikke vet noe, sier du det. \
    Du lover aldri å ha gjort noe du ikke har gjort, og du later ikke som om du \
    har lest data du ikke har fått. Hold svaret under 120 ord med mindre brukeren \
    ber om mer.
    """

    private static func env(_ key: String) -> String? {
        guard let raw = ProcessInfo.processInfo.environment[key] else { return nil }
        let trimmed = raw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func configuredAPIKey() -> String {
        env("BINDING_REMOTE_LLM_API_KEY")
            ?? env("ANTHROPIC_API_KEY")
            ?? env("OPENAI_API_KEY")
            ?? ""
    }

    static func configuredProvider() -> String {
        if let explicit = env("BINDING_REMOTE_LLM_PROVIDER")?.lowercased() {
            return explicit
        }
        if env("BINDING_REMOTE_LLM_API_KEY") == nil, env("ANTHROPIC_API_KEY") == nil, env("OPENAI_API_KEY") != nil {
            return "openai"
        }
        return "anthropic"
    }

    static func configuredModel() -> String {
        if let explicit = env("BINDING_REMOTE_LLM_MODEL") {
            return explicit
        }
        return configuredProvider() == "openai" ? "gpt-4.1-mini" : "claude-sonnet-5"
    }

    static func configuredBaseURL() -> String {
        if let explicit = env("BINDING_REMOTE_LLM_BASE_URL") {
            return explicit.hasSuffix("/") ? String(explicit.dropLast()) : explicit
        }
        return configuredProvider() == "openai" ? "https://api.openai.com" : "https://api.anthropic.com"
    }

    static func providerDisplayName(_ provider: String) -> String {
        switch provider {
        case "openai": return "OpenAI"
        case "anthropic": return "Anthropic"
        default: return provider
        }
    }
}

enum BindingRemoteLLMError: Error {
    case badURL(String)
    case httpStatus(Int, String)
    case unexpectedResponse
}


// The equivalents in ChatWorkbenchParityCells.swift are `private`, so they do
// not reach this file. Duplicated here rather than widening their visibility:
// two three-line helpers cost less than making file-local details part of the
// module's surface.
private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension ValueType {
    var stringValueIfPossible: String? {
        guard case let .string(text) = self else { return nil }
        return text
    }
}
