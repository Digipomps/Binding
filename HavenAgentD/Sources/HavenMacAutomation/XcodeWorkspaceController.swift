import Foundation

public struct XcodeWorkspaceRequest: Equatable, Sendable {
    public var workspacePath: String
    public var exclusiveLocalPackagePath: String?
    public var scheme: String?
    public var destinationName: String?
    public var destinationPlatform: String?
    public var destinationArchitecture: String?
    public var closeOtherWorkspaces: Bool
    public var build: Bool
    public var timeoutSeconds: Int

    public init(
        workspacePath: String,
        exclusiveLocalPackagePath: String? = nil,
        scheme: String? = nil,
        destinationName: String? = nil,
        destinationPlatform: String? = nil,
        destinationArchitecture: String? = nil,
        closeOtherWorkspaces: Bool = true,
        build: Bool = true,
        timeoutSeconds: Int = 300
    ) {
        self.workspacePath = workspacePath
        self.exclusiveLocalPackagePath = exclusiveLocalPackagePath
        self.scheme = scheme
        self.destinationName = destinationName
        self.destinationPlatform = destinationPlatform
        self.destinationArchitecture = destinationArchitecture
        self.closeOtherWorkspaces = closeOtherWorkspaces
        self.build = build
        self.timeoutSeconds = max(10, min(timeoutSeconds, 900))
    }
}

public struct XcodeWorkspaceResult: Codable, Equatable, Sendable {
    public var ok: Bool
    public var workspacePath: String
    public var exclusiveLocalPackagePath: String?
    public var closedWorkspaceNames: [String]
    public var openedWorkspaceName: String
    public var scheme: String?
    public var destination: String?
    public var closeOtherWorkspaces: Bool
    public var buildRequested: Bool
    public var completed: Bool
    public var status: String
    public var errorCount: Int
    public var warningCount: Int
    public var errors: [String]

    public init(
        ok: Bool,
        workspacePath: String,
        exclusiveLocalPackagePath: String? = nil,
        closedWorkspaceNames: [String] = [],
        openedWorkspaceName: String,
        scheme: String? = nil,
        destination: String? = nil,
        closeOtherWorkspaces: Bool,
        buildRequested: Bool,
        completed: Bool,
        status: String,
        errorCount: Int,
        warningCount: Int,
        errors: [String] = []
    ) {
        self.ok = ok
        self.workspacePath = workspacePath
        self.exclusiveLocalPackagePath = exclusiveLocalPackagePath
        self.closedWorkspaceNames = closedWorkspaceNames
        self.openedWorkspaceName = openedWorkspaceName
        self.scheme = scheme
        self.destination = destination
        self.closeOtherWorkspaces = closeOtherWorkspaces
        self.buildRequested = buildRequested
        self.completed = completed
        self.status = status
        self.errorCount = errorCount
        self.warningCount = warningCount
        self.errors = errors
    }
}

public protocol XcodeWorkspaceControlling: Sendable {
    func ensureWorkspace(_ request: XcodeWorkspaceRequest) async throws -> XcodeWorkspaceResult
}

public final class XcodeWorkspaceController: XcodeWorkspaceControlling, @unchecked Sendable {
    private let runner: AppleScriptRunner
    private let policy: AutomationPolicy

    public init(
        runner: AppleScriptRunner = AppleScriptRunner(),
        policy: AutomationPolicy = .xcodeWorkspacePolicy
    ) {
        self.runner = runner
        self.policy = policy
    }

    public func ensureWorkspace(_ request: XcodeWorkspaceRequest) async throws -> XcodeWorkspaceResult {
        let invocation = AppleScriptInvocation(
            id: "xcode.ensure-workspace",
            origin: .local,
            arguments: [
                "workspacePath": NSString(string: request.workspacePath).expandingTildeInPath,
                "exclusiveLocalPackagePath": request.exclusiveLocalPackagePath.map {
                    NSString(string: $0).expandingTildeInPath
                } ?? "",
                "scheme": request.scheme ?? "",
                "destinationName": request.destinationName ?? "",
                "destinationPlatform": request.destinationPlatform ?? "",
                "destinationArchitecture": request.destinationArchitecture ?? "",
                "build": request.build ? "true" : "false",
                "closeOtherWorkspaces": request.closeOtherWorkspaces ? "true" : "false",
                "timeoutSeconds": String(request.timeoutSeconds)
            ]
        )
        let result = try await runner.run(invocation, policy: policy)
        return try Self.parseOutput(result.standardOutput, fallback: request)
    }

    static func parseOutput(_ output: String, fallback request: XcodeWorkspaceRequest) throws -> XcodeWorkspaceResult {
        var values: [String: String] = [:]
        for line in output.split(whereSeparator: \.isNewline) {
            guard let separator = line.firstIndex(of: "=") else {
                continue
            }
            let key = String(line[..<separator])
            let value = String(line[line.index(after: separator)...])
            values[key] = value
        }

        guard values["ok"] == "true" else {
            throw XcodeWorkspaceControllerError.invalidOutput(output)
        }

        return XcodeWorkspaceResult(
            ok: true,
            workspacePath: values["workspacePath"] ?? request.workspacePath,
            exclusiveLocalPackagePath: nonEmpty(values["exclusiveLocalPackagePath"]) ?? request.exclusiveLocalPackagePath,
            closedWorkspaceNames: listValue(values["closedWorkspaceNames"]),
            openedWorkspaceName: values["openedWorkspaceName"] ?? "",
            scheme: nonEmpty(values["scheme"]) ?? request.scheme,
            destination: nonEmpty(values["destination"]),
            closeOtherWorkspaces: boolValue(values["closeOtherWorkspaces"]) ?? request.closeOtherWorkspaces,
            buildRequested: boolValue(values["buildRequested"]) ?? request.build,
            completed: boolValue(values["completed"]) ?? false,
            status: values["status"] ?? "unknown",
            errorCount: intValue(values["errorCount"]) ?? 0,
            warningCount: intValue(values["warningCount"]) ?? 0,
            errors: listValue(values["errors"])
        )
    }

    private static func listValue(_ value: String?) -> [String] {
        guard let value, !value.isEmpty else {
            return []
        }
        return value
            .split(separator: "|", omittingEmptySubsequences: true)
            .map(String.init)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func boolValue(_ value: String?) -> Bool? {
        switch value {
        case "true":
            return true
        case "false":
            return false
        default:
            return nil
        }
    }

    private static func intValue(_ value: String?) -> Int? {
        guard let value else {
            return nil
        }
        return Int(value)
    }
}

public enum XcodeWorkspaceControllerError: Error, Equatable, Sendable, LocalizedError {
    case invalidOutput(String)

    public var errorDescription: String? {
        switch self {
        case .invalidOutput(let output):
            return "Xcode automation returned unexpected output: \(output)"
        }
    }
}

public extension AutomationPolicy {
    static var xcodeWorkspacePolicy: AutomationPolicy {
        AutomationPolicy(
            appleScripts: [
                AppleScriptDefinition(
                    id: "xcode.ensure-workspace",
                    description: "Close competing Xcode workspaces, open the requested workspace, select scheme/destination, and optionally build.",
                    source: xcodeEnsureWorkspaceScript,
                    argumentOrder: [
                        "workspacePath",
                        "exclusiveLocalPackagePath",
                        "scheme",
                        "destinationName",
                        "destinationPlatform",
                        "destinationArchitecture",
                        "build",
                        "closeOtherWorkspaces",
                        "timeoutSeconds"
                    ],
                    argumentConstraints: [
                        "workspacePath": StringConstraint(
                            maxLength: 4096,
                            pattern: #"^/.+\.(xcworkspace|xcodeproj)$"#
                        ),
                        "exclusiveLocalPackagePath": StringConstraint(required: false, maxLength: 4096),
                        "scheme": StringConstraint(required: false, maxLength: 128),
                        "destinationName": StringConstraint(required: false, maxLength: 128),
                        "destinationPlatform": StringConstraint(required: false, maxLength: 64),
                        "destinationArchitecture": StringConstraint(required: false, maxLength: 64),
                        "build": StringConstraint(allowedValues: ["true", "false"]),
                        "closeOtherWorkspaces": StringConstraint(allowedValues: ["true", "false"]),
                        "timeoutSeconds": StringConstraint(pattern: #"^[0-9]{1,3}$"#)
                    ],
                    allowedForRemoteExecution: false,
                    requiresUserSession: true
                )
            ]
        )
    }

    private static var xcodeEnsureWorkspaceScript: String {
        #"""
        on run argv
            set workspacePath to item 1 of argv
            set exclusiveLocalPackagePath to item 2 of argv
            set schemeName to item 3 of argv
            set destinationName to item 4 of argv
            set destinationPlatform to item 5 of argv
            set destinationArchitecture to item 6 of argv
            set shouldBuild to item 7 of argv
            set closeOtherWorkspaces to item 8 of argv
            set timeoutSeconds to (item 9 of argv) as integer
            set targetWorkspaceName to my basename(workspacePath)

            set closedNames to {}
            set openedName to ""
            set selectedDestination to ""
            set completedText to "false"
            set statusText to "notRequested"
            set errorCountText to "0"
            set warningCountText to "0"
            set errorLines to {}

            tell application "Xcode"
                activate

                set closedDocumentCount to 0
                repeat with documentIndex from (count of workspace documents) to 1 by -1
                    set wd to workspace document documentIndex
                    set docName to name of wd as text
                    if closeOtherWorkspaces is "true" or docName is targetWorkspaceName then
                        set end of closedNames to docName
                        set closedDocumentCount to closedDocumentCount + 1
                        close wd saving yes
                    end if
                end repeat

                if closedDocumentCount > 0 then delay 1

                open POSIX file workspacePath

                repeat (timeoutSeconds * 2) times
                    if exists workspace document targetWorkspaceName then
                        set targetDocument to workspace document targetWorkspaceName
                        if loaded of targetDocument is true then exit repeat
                    end if
                    delay 0.5
                end repeat

                if not (exists workspace document targetWorkspaceName) then
                    error "Xcode did not open " & targetWorkspaceName
                end if

                set targetDocument to workspace document targetWorkspaceName
                if loaded of targetDocument is not true then
                    error "Xcode did not finish loading " & targetWorkspaceName
                end if
                set openedName to name of targetDocument as text

                if schemeName is not "" then
                    set matchedScheme to missing value
                    repeat (timeoutSeconds * 2) times
                        repeat with s in schemes of targetDocument
                            if (name of s as text) is schemeName then
                                set matchedScheme to s
                                exit repeat
                            end if
                        end repeat
                        if matchedScheme is not missing value then exit repeat
                        delay 0.5
                    end repeat
                    if matchedScheme is missing value then
                        error "No Xcode scheme matched " & schemeName
                    end if

                    set activeSchemeName to ""
                    try
                        set activeSchemeName to name of active scheme of targetDocument as text
                    end try
                    if activeSchemeName is not schemeName then
                        try
                            set active scheme of targetDocument to matchedScheme
                        on error schemeError
                            delay 1
                            set activeSchemeName to ""
                            try
                                set activeSchemeName to name of active scheme of targetDocument as text
                            end try
                            if activeSchemeName is not schemeName then
                                error schemeError
                            end if
                        end try
                    end if
                end if

                if destinationName is not "" then
                    set matchedDestination to missing value
                    repeat with d in run destinations of targetDocument
                        set didMatch to true
                        if destinationName is not "" and (name of d as text) is not destinationName then set didMatch to false
                        if destinationPlatform is not "" and (platform of d as text) is not destinationPlatform then set didMatch to false
                        if destinationArchitecture is not "" and (architecture of d as text) is not destinationArchitecture then set didMatch to false
                        if didMatch then
                            set matchedDestination to d
                            set selectedDestination to (name of d as text) & " [" & (platform of d as text) & "/" & (architecture of d as text) & "]"
                            exit repeat
                        end if
                    end repeat
                    if matchedDestination is missing value then
                        error "No Xcode run destination matched " & destinationName
                    end if
                    set active run destination of targetDocument to matchedDestination
                end if

                if shouldBuild is "true" then
                    set actionResult to build targetDocument
                    repeat (timeoutSeconds * 2) times
                        if completed of actionResult is true then exit repeat
                        delay 0.5
                    end repeat

                    set completedText to completed of actionResult as text
                    set statusText to status of actionResult as text
                    set errorCountText to (count of build errors of actionResult) as text
                    set warningCountText to (count of build warnings of actionResult) as text

                    repeat with e in build errors of actionResult
                        set fileText to ""
                        set lineText to ""
                        try
                            set fileText to file path of e as text
                        end try
                        try
                            set lineText to starting line number of e as text
                        end try
                        set end of errorLines to my sanitize((message of e as text) & " @ " & fileText & ":" & lineText)
                    end repeat
                end if
            end tell

            set outputLines to {¬
                "ok=true", ¬
                "workspacePath=" & workspacePath, ¬
                "exclusiveLocalPackagePath=" & exclusiveLocalPackagePath, ¬
                "closedWorkspaceNames=" & my joinList(closedNames, "|"), ¬
                "openedWorkspaceName=" & openedName, ¬
                "scheme=" & schemeName, ¬
                "destination=" & selectedDestination, ¬
                "closeOtherWorkspaces=" & closeOtherWorkspaces, ¬
                "buildRequested=" & shouldBuild, ¬
                "completed=" & completedText, ¬
                "status=" & statusText, ¬
                "errorCount=" & errorCountText, ¬
                "warningCount=" & warningCountText, ¬
                "errors=" & my joinList(errorLines, "|") ¬
            }
            return my joinList(outputLines, linefeed)
        end run

        on basename(posixPath)
            set oldDelimiters to AppleScript's text item delimiters
            set AppleScript's text item delimiters to "/"
            set pathItems to text items of posixPath
            set baseName to item -1 of pathItems
            set AppleScript's text item delimiters to oldDelimiters
            return baseName
        end basename

        on joinList(itemsToJoin, delimiterText)
            set oldDelimiters to AppleScript's text item delimiters
            set AppleScript's text item delimiters to delimiterText
            set joinedText to itemsToJoin as text
            set AppleScript's text item delimiters to oldDelimiters
            return joinedText
        end joinList

        on sanitize(rawText)
            set sanitizedText to my replaceText(linefeed, " ", rawText)
            set sanitizedText to my replaceText(return, " ", sanitizedText)
            set sanitizedText to my replaceText("|", "/", sanitizedText)
            return sanitizedText
        end sanitize

        on replaceText(searchText, replacementText, sourceText)
            set oldDelimiters to AppleScript's text item delimiters
            set AppleScript's text item delimiters to searchText
            set textItems to text items of sourceText
            set AppleScript's text item delimiters to replacementText
            set replacedText to textItems as text
            set AppleScript's text item delimiters to oldDelimiters
            return replacedText
        end replaceText
        """#
    }
}
