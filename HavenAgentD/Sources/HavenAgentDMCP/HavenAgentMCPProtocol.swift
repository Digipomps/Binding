import Foundation

typealias JSONObject = [String: Any]
typealias JSONArray = [Any]

enum JSONRPCErrorCode {
    static let parseError = -32700
    static let invalidRequest = -32600
    static let methodNotFound = -32601
    static let invalidParams = -32602
    static let internalError = -32603
}

enum HavenAgentMCPProtocolError: Error, LocalizedError {
    case invalidJSONRPCVersion
    case invalidRequestShape
    case invalidMethod
    case invalidParams(String)
    case unsupportedMessageType

    var errorDescription: String? {
        switch self {
        case .invalidJSONRPCVersion:
            return "JSON-RPC version must be 2.0."
        case .invalidRequestShape:
            return "Request must be a JSON object."
        case .invalidMethod:
            return "Request method is missing or invalid."
        case .invalidParams(let message):
            return message
        case .unsupportedMessageType:
            return "Unsupported message type."
        }
    }
}

struct MCPRequest {
    let id: Any?
    let method: String
    let params: JSONObject

    var isNotification: Bool {
        id == nil
    }

    init(jsonObject: Any) throws {
        guard let object = jsonObject as? JSONObject else {
            throw HavenAgentMCPProtocolError.invalidRequestShape
        }
        guard (object["jsonrpc"] as? String) == "2.0" else {
            throw HavenAgentMCPProtocolError.invalidJSONRPCVersion
        }
        guard let method = object["method"] as? String,
              !method.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HavenAgentMCPProtocolError.invalidMethod
        }
        if let params = object["params"] {
            guard let paramsObject = params as? JSONObject else {
                throw HavenAgentMCPProtocolError.invalidParams("Request params must be an object.")
            }
            self.params = paramsObject
        } else {
            self.params = [:]
        }
        self.id = object["id"]
        self.method = method
    }
}

struct MCPToolCallOutput {
    let structuredContent: JSONObject?
    let text: String
    let isError: Bool
}

func decodeJSONLine(_ line: String) throws -> Any {
    try JSONSerialization.jsonObject(with: Data(line.utf8), options: [])
}

func encodeJSONLine(_ object: JSONObject) throws -> String {
    let data = try JSONSerialization.data(withJSONObject: object, options: [])
    guard let string = String(data: data, encoding: .utf8) else {
        throw HavenAgentMCPProtocolError.invalidRequestShape
    }
    return string
}

func makeJSONRPCResult(id: Any, result: JSONObject) -> JSONObject {
    [
        "jsonrpc": "2.0",
        "id": id,
        "result": result
    ]
}

func makeJSONRPCError(id: Any?, code: Int, message: String, data: Any? = nil) -> JSONObject {
    var errorObject: JSONObject = [
        "code": code,
        "message": message
    ]
    if let data {
        errorObject["data"] = data
    }

    var response: JSONObject = [
        "jsonrpc": "2.0",
        "error": errorObject
    ]
    if let id {
        response["id"] = id
    }
    return response
}

func textContent(_ text: String) -> JSONObject {
    [
        "type": "text",
        "text": text
    ]
}

func jsonValue<T: Encodable>(from encodable: T) throws -> Any {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(encodable)
    return try JSONSerialization.jsonObject(with: data, options: [])
}

func jsonObject<T: Encodable>(from encodable: T) throws -> JSONObject {
    guard let object = try jsonValue(from: encodable) as? JSONObject else {
        throw HavenAgentMCPProtocolError.invalidRequestShape
    }
    return object
}

func jsonArray<T: Encodable>(from encodable: T) throws -> JSONArray {
    guard let array = try jsonValue(from: encodable) as? JSONArray else {
        throw HavenAgentMCPProtocolError.invalidRequestShape
    }
    return array
}

func prettyJSONString(from object: JSONObject) throws -> String {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    guard let string = String(data: data, encoding: .utf8) else {
        throw HavenAgentMCPProtocolError.invalidRequestShape
    }
    return string
}

func stringValue(_ value: Any?) -> String? {
    switch value {
    case let string as String:
        return string
    case let number as NSNumber:
        return number.stringValue
    default:
        return nil
    }
}

func boolValue(_ value: Any?) -> Bool? {
    switch value {
    case let bool as Bool:
        return bool
    case let number as NSNumber:
        return number.boolValue
    default:
        return nil
    }
}

func doubleValue(_ value: Any?) -> Double? {
    switch value {
    case let double as Double:
        return double
    case let float as Float:
        return Double(float)
    case let int as Int:
        return Double(int)
    case let number as NSNumber:
        return number.doubleValue
    default:
        return nil
    }
}

func objectValue(_ value: Any?) -> JSONObject? {
    value as? JSONObject
}

func stringArrayValue(_ value: Any?) -> [String]? {
    guard let array = value as? [Any] else {
        return nil
    }
    return array.compactMap { element in
        guard let string = stringValue(element) else {
            return nil
        }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
