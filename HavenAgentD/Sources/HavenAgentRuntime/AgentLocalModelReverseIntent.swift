import Foundation
@preconcurrency import CellBase

public enum AgentLocalModelReverseIntentContract {
    public static let capability = "cap.local_model.generate"
    public static let topic = "haven.agent.local-model.generate.v1"
    public static let actionID = "agent.local-model.generate"
    public static let responseKeypath = "native.localModel.response"
    public static let registrationKeypath = "native.localModel.register"
    public static let maximumPayloadChunks = 12

    public struct Request: Codable, Equatable, Sendable {
        public var requestID: String
        public var providerID: String
        public var prompt: String
        public var systemPrompt: String?
        public var temperature: Double?
        public var maxTokens: Int?

        public init(
            requestID: String,
            providerID: String,
            prompt: String,
            systemPrompt: String? = nil,
            temperature: Double? = nil,
            maxTokens: Int? = nil
        ) {
            self.requestID = requestID
            self.providerID = providerID
            self.prompt = prompt
            self.systemPrompt = systemPrompt
            self.temperature = temperature
            self.maxTokens = maxTokens
        }

        public var cellValue: ValueType {
            .object([
                "prompt": .string(prompt),
                "systemPrompt": systemPrompt.map(ValueType.string) ?? .null,
                "temperature": temperature.map(ValueType.float) ?? .null,
                "maxTokens": maxTokens.map(ValueType.integer) ?? .null,
                "correlationID": .string(requestID)
            ])
        }
    }

    public enum DecodeError: Error, Equatable, Sendable {
        case invalidRequestID
        case invalidProviderID
        case invalidChunkCount
        case missingChunk(Int)
        case invalidBase64
        case invalidPayload
        case mismatchedRequestID
        case mismatchedProviderID
        case emptyPrompt
    }

    public static func decode(arguments: [String: String]) throws -> Request {
        guard let requestID = normalized(arguments["requestID"]) else {
            throw DecodeError.invalidRequestID
        }
        guard let providerID = normalized(arguments["providerID"]) else {
            throw DecodeError.invalidProviderID
        }
        guard let rawCount = arguments["payloadChunkCount"],
              let count = Int(rawCount),
              (1...maximumPayloadChunks).contains(count) else {
            throw DecodeError.invalidChunkCount
        }
        var encoded = ""
        for index in 0..<count {
            guard let chunk = arguments["payload.\(index)"] else {
                throw DecodeError.missingChunk(index)
            }
            encoded.append(chunk)
        }
        guard let data = Data(base64Encoded: encoded) else {
            throw DecodeError.invalidBase64
        }
        guard let request = try? JSONDecoder().decode(Request.self, from: data) else {
            throw DecodeError.invalidPayload
        }
        guard request.requestID == requestID else {
            throw DecodeError.mismatchedRequestID
        }
        guard request.providerID == providerID else {
            throw DecodeError.mismatchedProviderID
        }
        guard normalized(request.prompt) != nil else {
            throw DecodeError.emptyPrompt
        }
        return request
    }

    public static func responseValue(
        requestID: String,
        providerID: String,
        result: ValueType
    ) -> ValueType {
        .object([
            "requestID": .string(requestID),
            "providerID": .string(providerID),
            "result": result
        ])
    }

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

public typealias AgentLocalModelReverseIntentHandler = @Sendable (
    AgentLocalModelReverseIntentContract.Request
) async -> ValueType
