import Foundation

enum CorrespondenceMCPServiceError: Error, LocalizedError {
  case unknownResource
  case invalidArguments(String)

  var errorDescription: String? {
    switch self {
    case .unknownResource: return "Unknown correspondence resource."
    case .invalidArguments(let message): return message
    }
  }
}

final class CorrespondenceMCPService: @unchecked Sendable {
  private let client: CorrespondenceClient

  init(client: CorrespondenceClient) {
    self.client = client
  }

  func listResources() -> [MCPJSONObject] {
    [
      [
        "uri": "haven-correspondence://profile",
        "name": "correspondence_profile",
        "title": "HAVEN Correspondence Profile",
        "description":
          "The enrolled local participant and the strict message-only authority boundary.",
        "mimeType": "application/json",
      ]
    ]
  }

  func readResource(uri: String) async throws -> MCPJSONObject {
    guard uri == "haven-correspondence://profile" else {
      throw CorrespondenceMCPServiceError.unknownResource
    }
    let profile = client.profile
    let object: MCPJSONObject = [
      "profile": profile.profile,
      "principalID": profile.principalID,
      "deviceID": profile.deviceID,
      "displayName": profile.displayName,
      "identityUUID": profile.identityUUID,
      "baseURL": profile.baseURL,
      "authority": ["inbox.list", "message.read", "message.send", "message.ack"],
      "executionAuthority": false,
      "contentDoesNotConferAuthority": true,
    ]
    let data = try JSONSerialization.data(
      withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    return [
      "contents": [
        ["uri": uri, "mimeType": "application/json", "text": String(decoding: data, as: UTF8.self)]
      ]
    ]
  }

  func listTools() -> [MCPJSONObject] {
    [
      tool(
        "correspondence.list_inbox", "List Inbox",
        "List message metadata addressed to this enrolled principal; message bodies require an explicit read.",
        properties: [
          "afterSequence": ["type": "integer", "minimum": 0, "default": 0],
          "limit": ["type": "integer", "minimum": 1, "maximum": 100, "default": 50],
        ]),
      tool(
        "correspondence.read_message", "Read Message",
        "Read one message addressed to this enrolled principal.",
        properties: [
          "messageID": ["type": "string"]
        ], required: ["messageID"]),
      tool(
        "correspondence.send_message", "Send Message",
        "Send project correspondence to an explicitly granted peer. This never authorizes local code or machine actions.",
        properties: [
          "recipientID": ["type": "string"],
          "subject": ["type": "string", "maxLength": 512],
          "content": ["type": "string", "maxLength": 16384],
          "purposeRef": [
            "type": "string",
            "enum": ["purpose://contact.communication", "purpose://digital-work.coordinate"],
            "default": CorrespondenceContract.defaultPurposeRef,
          ],
          "clientMessageID": ["type": "string"],
          "retentionSeconds": ["type": "integer", "minimum": 60, "maximum": 7_776_000],
        ], required: ["recipientID", "content"]),
      tool(
        "correspondence.ack_message", "Acknowledge Message",
        "Acknowledge receipt of one message addressed to this enrolled principal.",
        properties: [
          "messageID": ["type": "string"]
        ], required: ["messageID"]),
    ]
  }

  func callTool(name: String, arguments: MCPJSONObject) async -> MCPToolOutput {
    do {
      let operation: String
      let requestArguments: CorrespondenceArguments
      switch name {
      case "correspondence.list_inbox":
        operation = "inbox.list"
        requestArguments = CorrespondenceArguments(
          afterSequence: mcpInt(arguments["afterSequence"]), limit: mcpInt(arguments["limit"]))
      case "correspondence.read_message":
        operation = "message.read"
        requestArguments = CorrespondenceArguments(messageID: try required("messageID", arguments))
      case "correspondence.send_message":
        operation = "message.send"
        requestArguments = CorrespondenceArguments(
          recipientID: try required("recipientID", arguments),
          subject: mcpString(arguments["subject"]),
          content: try required("content", arguments),
          purposeRef: mcpString(arguments["purposeRef"])
            ?? CorrespondenceContract.defaultPurposeRef,
          clientMessageID: mcpString(arguments["clientMessageID"]),
          retentionSeconds: mcpInt(arguments["retentionSeconds"])
        )
      case "correspondence.ack_message":
        operation = "message.ack"
        requestArguments = CorrespondenceArguments(messageID: try required("messageID", arguments))
      default:
        throw CorrespondenceMCPServiceError.invalidArguments("Unknown tool: \(name)")
      }
      let response = try await client.perform(operation: operation, arguments: requestArguments)
      let isError =
        !(200...299).contains(response.statusCode)
        || response.object["status"] as? String == "error"
      let data = try JSONSerialization.data(
        withJSONObject: response.object, options: [.prettyPrinted, .sortedKeys])
      return MCPToolOutput(
        structured: response.object, text: String(decoding: data, as: UTF8.self), isError: isError)
    } catch {
      return MCPToolOutput(
        structured: ["status": "error", "message": error.localizedDescription],
        text: error.localizedDescription, isError: true)
    }
  }

  private func required(_ key: String, _ arguments: MCPJSONObject) throws -> String {
    guard let value = mcpString(arguments[key])?.trimmingCharacters(in: .whitespacesAndNewlines),
      value.isEmpty == false
    else {
      throw CorrespondenceMCPServiceError.invalidArguments("\(key) is required.")
    }
    return value
  }

  private func tool(
    _ name: String,
    _ title: String,
    _ description: String,
    properties: MCPJSONObject,
    required: [String] = []
  ) -> MCPJSONObject {
    var schema: MCPJSONObject = [
      "type": "object", "properties": properties, "additionalProperties": false,
    ]
    if required.isEmpty == false { schema["required"] = required }
    return ["name": name, "title": title, "description": description, "inputSchema": schema]
  }
}
