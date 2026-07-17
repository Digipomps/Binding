import Darwin
import Foundation
import HavenAgentRuntime

@main
struct HavenCorrespondenceMCPMain {
  static func main() async {
    do {
      let arguments = Array(CommandLine.arguments.dropFirst())
      if arguments.contains("--help") || arguments.contains("-h") {
        printUsage()
        return
      }
      let command = arguments.first.map { $0.hasPrefix("-") ? "serve" : $0 } ?? "serve"
      let profile = value("--profile", in: arguments) ?? "default"
      let paths = try CorrespondencePaths.resolve(
        profile: profile, rootOverride: value("--root", in: arguments))

      switch command {
      case "setup":
        guard let invitePath = value("--invite", in: arguments) else {
          throw CorrespondenceMCPServiceError.invalidArguments(
            "setup requires --invite /path/to/invite.json")
        }
        let inviteURL = URL(fileURLWithPath: NSString(string: invitePath).expandingTildeInPath)
        let invite = try JSONDecoder().decode(
          CorrespondenceEnrollmentInviteFile.self, from: Data(contentsOf: inviteURL))
        let invitePaths = try CorrespondencePaths.resolve(
          profile: invite.profile, rootOverride: value("--root", in: arguments))
        let (enrolled, _) = try await CorrespondenceClient.enroll(
          invite: invite, paths: invitePaths)
        print(try publicProfileJSON(enrolled))
      case "doctor":
        let client = try await CorrespondenceClient.load(paths: paths)
        let response = try await client.perform(
          operation: "inbox.list", arguments: CorrespondenceArguments(limit: 1))
        var result = response.object
        result["httpStatus"] = response.statusCode
        result["profile"] = profile
        print(try json(result))
        if !(200...299).contains(response.statusCode) { Darwin.exit(2) }
      case "identity":
        let client = try await CorrespondenceClient.load(paths: paths)
        print(try publicProfileJSON(client.profile))
      case "serve":
        let client = try await CorrespondenceClient.load(paths: paths)
        try await CorrespondenceMCPServer(service: CorrespondenceMCPService(client: client)).run()
      default:
        throw CorrespondenceMCPServiceError.invalidArguments("Unknown command: \(command)")
      }
    } catch {
      FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
      Darwin.exit(1)
    }
  }

  private static func value(_ flag: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
      return nil
    }
    return arguments[index + 1]
  }

  private static func publicProfileJSON(_ profile: CorrespondenceProfile) throws -> String {
    try json([
      "status": "enrolled",
      "profile": profile.profile,
      "principalID": profile.principalID,
      "deviceID": profile.deviceID,
      "displayName": profile.displayName,
      "identityUUID": profile.identityUUID,
      "publicKeyBase64URL": profile.publicKeyBase64URL,
      "baseURL": profile.baseURL,
      "executionAuthority": false,
    ])
  }

  private static func json(_ object: MCPJSONObject) throws -> String {
    String(
      decoding: try JSONSerialization.data(
        withJSONObject: object, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self)
  }

  private static func printUsage() {
    print(
      """
      HAVEN Assistant Correspondence

      Usage:
        haven-correspondence-mcp setup --invite /path/to/invite.json [--root /path]
        haven-correspondence-mcp doctor --profile NAME [--root /path]
        haven-correspondence-mcp identity --profile NAME [--root /path]
        haven-correspondence-mcp serve --profile NAME [--root /path]

      The MCP surface is messages-only: list, read, send and acknowledge.
      Message text never grants code execution or machine authority.
      """)
  }
}
