import Foundation

public enum AutomationOrigin: String, Codable, CaseIterable, Sendable {
    case local
    case trustedRemote
    case untrustedRemote

    public var isRemote: Bool {
        self != .local
    }
}

public struct ShortcutDefinition: Codable, Equatable, Sendable {
    public var id: String
    public var shortcutName: String
    public var acceptsInputPath: Bool
    public var allowedForRemoteExecution: Bool
    public var outputPath: String?
    public var outputType: String?

    public init(
        id: String,
        shortcutName: String,
        acceptsInputPath: Bool = false,
        allowedForRemoteExecution: Bool = false,
        outputPath: String? = nil,
        outputType: String? = nil
    ) {
        self.id = id
        self.shortcutName = shortcutName
        self.acceptsInputPath = acceptsInputPath
        self.allowedForRemoteExecution = allowedForRemoteExecution
        self.outputPath = outputPath
        self.outputType = outputType
    }
}

public struct ShortcutInvocation: Equatable, Sendable {
    public var id: String
    public var origin: AutomationOrigin
    public var inputPath: String?

    public init(id: String, origin: AutomationOrigin, inputPath: String? = nil) {
        self.id = id
        self.origin = origin
        self.inputPath = inputPath
    }
}

public struct StringConstraint: Codable, Equatable, Sendable {
    public var required: Bool
    public var maxLength: Int
    public var allowedValues: [String]
    public var pattern: String?
    public var allowsNewlines: Bool?

    public init(
        required: Bool = true,
        maxLength: Int = 512,
        allowedValues: [String] = [],
        pattern: String? = nil,
        allowsNewlines: Bool? = nil
    ) {
        self.required = required
        self.maxLength = maxLength
        self.allowedValues = allowedValues
        self.pattern = pattern
        self.allowsNewlines = allowsNewlines
    }
}

public struct AppleScriptDefinition: Codable, Equatable, Sendable {
    public var id: String
    public var description: String
    public var source: String
    public var argumentOrder: [String]
    public var argumentConstraints: [String: StringConstraint]
    public var allowedForRemoteExecution: Bool
    public var requiresUserSession: Bool

    public init(
        id: String,
        description: String,
        source: String,
        argumentOrder: [String] = [],
        argumentConstraints: [String: StringConstraint] = [:],
        allowedForRemoteExecution: Bool = false,
        requiresUserSession: Bool = true
    ) {
        self.id = id
        self.description = description
        self.source = source
        self.argumentOrder = argumentOrder
        self.argumentConstraints = argumentConstraints
        self.allowedForRemoteExecution = allowedForRemoteExecution
        self.requiresUserSession = requiresUserSession
    }
}

public struct AppleScriptInvocation: Equatable, Sendable {
    public var id: String
    public var origin: AutomationOrigin
    public var arguments: [String: String]

    public init(id: String, origin: AutomationOrigin, arguments: [String: String] = [:]) {
        self.id = id
        self.origin = origin
        self.arguments = arguments
    }
}

public struct LocalTaskDefinition: Codable, Equatable, Sendable {
    public var id: String
    public var description: String
    public var executablePath: String
    public var arguments: [String]
    public var requiresUserSession: Bool

    public init(
        id: String,
        description: String,
        executablePath: String,
        arguments: [String],
        requiresUserSession: Bool = false
    ) {
        self.id = id
        self.description = description
        self.executablePath = executablePath
        self.arguments = arguments
        self.requiresUserSession = requiresUserSession
    }
}

public struct LocalTaskInvocation: Equatable, Sendable {
    public var id: String

    public init(id: String) {
        self.id = id
    }
}

public struct AutomationPolicy: Codable, Equatable, Sendable {
    public var shortcuts: [ShortcutDefinition]
    public var appleScripts: [AppleScriptDefinition]
    public var localTasks: [LocalTaskDefinition]?

    public init(
        shortcuts: [ShortcutDefinition] = [],
        appleScripts: [AppleScriptDefinition] = [],
        localTasks: [LocalTaskDefinition]? = nil
    ) {
        self.shortcuts = shortcuts
        self.appleScripts = appleScripts
        self.localTasks = localTasks
    }

    public func authorize(_ invocation: ShortcutInvocation) throws -> AuthorizedShortcutInvocation {
        guard let definition = shortcuts.first(where: { $0.id == invocation.id }) else {
            throw AutomationPolicyError.unknownShortcut(invocation.id)
        }
        if invocation.origin.isRemote && !definition.allowedForRemoteExecution {
            throw AutomationPolicyError.remoteExecutionDenied(invocation.id)
        }
        if invocation.inputPath != nil && !definition.acceptsInputPath {
            throw AutomationPolicyError.inputPathNotAllowed(invocation.id)
        }
        if let inputPath = invocation.inputPath {
            try validatePathLikeValue(inputPath, field: "inputPath")
        }
        if let outputPath = definition.outputPath {
            try validatePathLikeValue(outputPath, field: "outputPath")
        }
        return AuthorizedShortcutInvocation(definition: definition, invocation: invocation)
    }

    public func authorize(_ invocation: AppleScriptInvocation) throws -> AuthorizedAppleScriptInvocation {
        guard let definition = appleScripts.first(where: { $0.id == invocation.id }) else {
            throw AutomationPolicyError.unknownAppleScript(invocation.id)
        }
        if invocation.origin.isRemote && !definition.allowedForRemoteExecution {
            throw AutomationPolicyError.remoteExecutionDenied(invocation.id)
        }

        let extraKeys = Set(invocation.arguments.keys).subtracting(definition.argumentConstraints.keys)
        if let firstExtraKey = extraKeys.sorted().first {
            throw AutomationPolicyError.unexpectedArgument(firstExtraKey)
        }

        var orderedValues: [String] = []
        for key in definition.argumentOrder {
            let constraint = definition.argumentConstraints[key] ?? StringConstraint()
            guard let value = invocation.arguments[key] else {
                if constraint.required {
                    throw AutomationPolicyError.missingRequiredArgument(key)
                }
                continue
            }
            try validate(value: value, field: key, constraint: constraint)
            orderedValues.append(value)
        }

        for (key, constraint) in definition.argumentConstraints where !definition.argumentOrder.contains(key) {
            guard let value = invocation.arguments[key] else {
                if constraint.required {
                    throw AutomationPolicyError.missingRequiredArgument(key)
                }
                continue
            }
            try validate(value: value, field: key, constraint: constraint)
        }

        return AuthorizedAppleScriptInvocation(
            definition: definition,
            invocation: invocation,
            orderedArgumentValues: orderedValues
        )
    }

    public func authorize(_ invocation: LocalTaskInvocation) throws -> LocalTaskDefinition {
        guard let definition = localTasks?.first(where: { $0.id == invocation.id }) else {
            throw AutomationPolicyError.unknownLocalTask(invocation.id)
        }
        guard definition.executablePath.hasPrefix("/"), !definition.executablePath.contains(where: \.isNewline) else {
            throw AutomationPolicyError.invalidLocalTask(invocation.id, "executablePath must be an absolute single-line path")
        }
        guard definition.arguments.allSatisfy({ !$0.contains(where: \.isNewline) }) else {
            throw AutomationPolicyError.invalidLocalTask(invocation.id, "arguments must be single-line values")
        }
        return definition
    }

    private func validate(value: String, field: String, constraint: StringConstraint) throws {
        if value.count > constraint.maxLength {
            throw AutomationPolicyError.invalidArgument(field, "Value exceeds maxLength \(constraint.maxLength)")
        }
        if constraint.allowsNewlines != true && value.contains(where: \.isNewline) {
            throw AutomationPolicyError.invalidArgument(field, "Value contains a newline")
        }
        if !constraint.allowedValues.isEmpty && !constraint.allowedValues.contains(value) {
            throw AutomationPolicyError.invalidArgument(field, "Value is not in the allowedValues set")
        }
        if let pattern = constraint.pattern {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(location: 0, length: value.utf16.count)
            let match = regex.firstMatch(in: value, options: [], range: range)
            if match?.range != range {
                throw AutomationPolicyError.invalidArgument(field, "Value does not match expected pattern")
            }
        }
    }

    private func validatePathLikeValue(_ value: String, field: String) throws {
        if value.isEmpty {
            throw AutomationPolicyError.invalidArgument(field, "Path-like value is empty")
        }
        if value.contains(where: \.isNewline) {
            throw AutomationPolicyError.invalidArgument(field, "Path-like value contains a newline")
        }
        if value.count > 4096 {
            throw AutomationPolicyError.invalidArgument(field, "Path-like value exceeds max length")
        }
    }
}

public struct AuthorizedShortcutInvocation: Sendable {
    public var definition: ShortcutDefinition
    public var invocation: ShortcutInvocation

    public init(definition: ShortcutDefinition, invocation: ShortcutInvocation) {
        self.definition = definition
        self.invocation = invocation
    }
}

public struct AuthorizedAppleScriptInvocation: Sendable {
    public var definition: AppleScriptDefinition
    public var invocation: AppleScriptInvocation
    public var orderedArgumentValues: [String]

    public init(
        definition: AppleScriptDefinition,
        invocation: AppleScriptInvocation,
        orderedArgumentValues: [String]
    ) {
        self.definition = definition
        self.invocation = invocation
        self.orderedArgumentValues = orderedArgumentValues
    }
}

public enum AutomationPolicyError: Error, Equatable, Sendable, LocalizedError {
    case unknownShortcut(String)
    case unknownAppleScript(String)
    case unknownLocalTask(String)
    case invalidLocalTask(String, String)
    case remoteExecutionDenied(String)
    case inputPathNotAllowed(String)
    case unexpectedArgument(String)
    case missingRequiredArgument(String)
    case invalidArgument(String, String)

    public var errorDescription: String? {
        switch self {
        case .unknownShortcut(let id):
            return "Unknown shortcut definition: \(id)"
        case .unknownAppleScript(let id):
            return "Unknown AppleScript definition: \(id)"
        case .unknownLocalTask(let id):
            return "Unknown local task definition: \(id)"
        case .invalidLocalTask(let id, let reason):
            return "Invalid local task '\(id)': \(reason)"
        case .remoteExecutionDenied(let id):
            return "Remote execution denied for action: \(id)"
        case .inputPathNotAllowed(let id):
            return "Shortcut does not accept an input path: \(id)"
        case .unexpectedArgument(let key):
            return "Unexpected AppleScript argument: \(key)"
        case .missingRequiredArgument(let key):
            return "Missing required AppleScript argument: \(key)"
        case .invalidArgument(let key, let reason):
            return "Invalid argument '\(key)': \(reason)"
        }
    }
}
