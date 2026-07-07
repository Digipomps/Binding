import Foundation
import AppKit
import ApplicationServices

struct CLI {
    enum Command: String {
        case dump
        case click
        case windows
        case setText
    }

    let command: Command
    let appName: String
    let query: String?
    let maxDepth: Int

    init() throws {
        var args = CommandLine.arguments.dropFirst()
        guard let raw = args.first, let command = Command(rawValue: raw) else {
            throw NSError(domain: "ax_binding", code: 1, userInfo: [NSLocalizedDescriptionKey: "usage: ax_binding.swift <dump|click|windows> [--app HAVEN] [--query text] [--depth N]"])
        }
        args = args.dropFirst()

        var appName = "HAVEN"
        var query: String?
        var maxDepth = 6

        while let flag = args.first {
            args = args.dropFirst()
            switch flag {
            case "--app":
                guard let value = args.first else { throw cliUsageError("--app requires a value") }
                appName = value
                args = args.dropFirst()
            case "--query":
                guard let value = args.first else { throw cliUsageError("--query requires a value") }
                query = value
                args = args.dropFirst()
            case "--depth":
                guard let value = args.first, let parsed = Int(value) else { throw cliUsageError("--depth requires an integer") }
                maxDepth = parsed
                args = args.dropFirst()
            default:
                throw cliUsageError("unknown flag \(flag)")
            }
        }

        self.command = command
        self.appName = appName
        self.query = query
        self.maxDepth = maxDepth
    }
}

private func cliUsageError(_ message: String) -> NSError {
    NSError(domain: "ax_binding", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
}

struct AXNode {
    let element: AXUIElement
    let role: String
    let subrole: String?
    let title: String?
    let value: String?
    let identifier: String?
    let description: String?
    let frame: CGRect?

    var searchableText: String {
        [role, subrole, title, value, identifier, description]
            .compactMap { $0?.lowercased() }
            .joined(separator: " | ")
    }
}

func copyAttribute<T>(_ element: AXUIElement, _ attribute: String) -> T? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else { return nil }
    return value as? T
}

func boolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else { return nil }
    guard let number = value as? NSNumber else { return nil }
    return number.boolValue
}

func pointAttribute(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success, let axValue = value, CFGetTypeID(axValue) == AXValueGetTypeID() else { return nil }
    let typed = axValue as! AXValue
    var point = CGPoint.zero
    return AXValueGetValue(typed, .cgPoint, &point) ? point : nil
}

func sizeAttribute(_ element: AXUIElement, _ attribute: String) -> CGSize? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success, let axValue = value, CFGetTypeID(axValue) == AXValueGetTypeID() else { return nil }
    let typed = axValue as! AXValue
    var size = CGSize.zero
    return AXValueGetValue(typed, .cgSize, &size) ? size : nil
}

func frame(for element: AXUIElement) -> CGRect? {
    guard let origin = pointAttribute(element, kAXPositionAttribute as String),
          let size = sizeAttribute(element, kAXSizeAttribute as String) else {
        return nil
    }
    return CGRect(origin: origin, size: size)
}

func runningApplication(named appName: String) -> NSRunningApplication? {
    let candidates = NSWorkspace.shared.runningApplications.filter { app in
        app.localizedName == appName
    }
    return candidates.sorted { $0.processIdentifier > $1.processIdentifier }.first
}

func applicationElement(named appName: String) throws -> AXUIElement {
    guard let app = runningApplication(named: appName) else {
        throw NSError(domain: "ax_binding", code: 10, userInfo: [NSLocalizedDescriptionKey: "app \(appName) is not running"])
    }
    return AXUIElementCreateApplication(app.processIdentifier)
}

func relatedElements(for element: AXUIElement) -> [AXUIElement] {
    let scalarAttributes = [
        "AXToolbar",
        kAXTitleUIElementAttribute as String,
        kAXCloseButtonAttribute as String,
        kAXMinimizeButtonAttribute as String,
        kAXZoomButtonAttribute as String,
        kAXFullScreenButtonAttribute as String
    ]
    let arrayAttributes = [
        kAXChildrenAttribute as String,
        kAXVisibleChildrenAttribute as String,
        "AXSheets"
    ]

    var ordered: [AXUIElement] = []
    var seen = Set<CFHashCode>()

    func append(_ candidate: AXUIElement) {
        let key = CFHash(candidate)
        guard seen.insert(key).inserted else { return }
        ordered.append(candidate)
    }

    for attribute in scalarAttributes {
        if let child: AXUIElement = copyAttribute(element, attribute) {
            append(child)
        }
    }

    for attribute in arrayAttributes {
        let children: [AXUIElement] = copyAttribute(element, attribute) ?? []
        for child in children {
            append(child)
        }
    }

    return ordered
}

func node(for element: AXUIElement) -> AXNode {
    let role: String = copyAttribute(element, kAXRoleAttribute as String) ?? "unknown"
    let subrole: String? = copyAttribute(element, kAXSubroleAttribute as String)
    let title: String? = copyAttribute(element, kAXTitleAttribute as String)
    let valueObject: Any? = copyAttribute(element, kAXValueAttribute as String) as CFTypeRef?
    let value: String?
    if let stringValue = valueObject as? String {
        value = stringValue
    } else if let number = valueObject as? NSNumber {
        value = number.stringValue
    } else {
        value = nil
    }
    let identifier: String? = copyAttribute(element, kAXIdentifierAttribute as String)
    let description: String? = copyAttribute(element, kAXDescriptionAttribute as String)
    return AXNode(
        element: element,
        role: role,
        subrole: subrole,
        title: title,
        value: value,
        identifier: identifier,
        description: description,
        frame: frame(for: element)
    )
}

func dumpTree(from element: AXUIElement, depth: Int, maxDepth: Int, lines: inout [String]) {
    let current = node(for: element)
    let indent = String(repeating: "  ", count: depth)
    let frameSummary: String
    if let frame = current.frame {
        frameSummary = String(format: " frame=(%.0f,%.0f %.0fx%.0f)", frame.origin.x, frame.origin.y, frame.size.width, frame.size.height)
    } else {
        frameSummary = ""
    }
    let summary = [
        current.role,
        current.subrole,
        current.title.map { "title=\"\($0)\"" },
        current.value.map { "value=\"\($0)\"" },
        current.identifier.map { "id=\"\($0)\"" },
        current.description.map { "desc=\"\($0)\"" }
    ]
    .compactMap { $0 }
    .joined(separator: " ")
    lines.append("\(indent)\(summary)\(frameSummary)")

    guard depth < maxDepth else { return }
    for child in relatedElements(for: element) {
        dumpTree(from: child, depth: depth + 1, maxDepth: maxDepth, lines: &lines)
    }
}

func allNodes(from element: AXUIElement, maxDepth: Int, depth: Int = 0) -> [AXNode] {
    let current = node(for: element)
    guard depth < maxDepth else { return [current] }
    return [current] + relatedElements(for: element).flatMap { allNodes(from: $0, maxDepth: maxDepth, depth: depth + 1) }
}

func performPress(on element: AXUIElement) -> AXError {
    AXUIElementPerformAction(element, kAXPressAction as CFString)
}

do {
    let cli = try CLI()
    let appElement = try applicationElement(named: cli.appName)

    switch cli.command {
    case .windows:
        let windows: [AXUIElement] = copyAttribute(appElement, kAXWindowsAttribute as String) ?? []
        for (index, window) in windows.enumerated() {
            let current = node(for: window)
            print("[\(index)] \(current.role) \(current.title ?? "<no title>")")
        }
    case .dump:
        let windows: [AXUIElement] = copyAttribute(appElement, kAXWindowsAttribute as String) ?? []
        var lines: [String] = []
        for (index, window) in windows.enumerated() {
            lines.append("WINDOW[\(index)]")
            dumpTree(from: window, depth: 0, maxDepth: cli.maxDepth, lines: &lines)
        }
        print(lines.joined(separator: "\n"))
    case .click:
        guard let query = cli.query?.lowercased(), query.isEmpty == false else {
            throw NSError(domain: "ax_binding", code: 20, userInfo: [NSLocalizedDescriptionKey: "--query is required for click"])
        }
        let windows: [AXUIElement] = copyAttribute(appElement, kAXWindowsAttribute as String) ?? []
        let nodes = windows.flatMap { allNodes(from: $0, maxDepth: cli.maxDepth) }
        let interactiveRoles = Set([
            kAXButtonRole as String,
            kAXMenuButtonRole as String,
            kAXRadioButtonRole as String,
            kAXCheckBoxRole as String
        ])
        let preferredMatches = nodes.filter { node in
            interactiveRoles.contains(node.role) &&
            node.searchableText.contains(query) &&
            boolAttribute(node.element, kAXEnabledAttribute as String) != false
        }
        let fallbackMatches = nodes.filter { node in
            node.searchableText.contains(query) &&
            boolAttribute(node.element, kAXEnabledAttribute as String) != false
        }
        guard let match = preferredMatches.first ?? fallbackMatches.first else {
            throw NSError(domain: "ax_binding", code: 21, userInfo: [NSLocalizedDescriptionKey: "no matching node for query \(query)"])
        }
        let result = performPress(on: match.element)
        if result != .success {
            throw NSError(domain: "ax_binding", code: Int(result.rawValue), userInfo: [NSLocalizedDescriptionKey: "AXPress failed with \(result.rawValue)"])
        }
        print("clicked \(match.role) \(match.title ?? match.identifier ?? match.description ?? "<unnamed>")")
    case .setText:
        guard let query = cli.query, query.isEmpty == false else {
            throw NSError(domain: "ax_binding", code: 22, userInfo: [NSLocalizedDescriptionKey: "--query is required for setText"])
        }
        let windows: [AXUIElement] = copyAttribute(appElement, kAXWindowsAttribute as String) ?? []
        let nodes = windows.flatMap { allNodes(from: $0, maxDepth: cli.maxDepth) }
        guard let field = nodes.first(where: { node in
            node.role == kAXTextFieldRole as String && boolAttribute(node.element, kAXEnabledAttribute as String) != false
        }) else {
            throw NSError(domain: "ax_binding", code: 23, userInfo: [NSLocalizedDescriptionKey: "no enabled text field found"])
        }
        let result = AXUIElementSetAttributeValue(field.element, kAXValueAttribute as CFString, query as CFTypeRef)
        if result != .success {
            throw NSError(domain: "ax_binding", code: Int(result.rawValue), userInfo: [NSLocalizedDescriptionKey: "setting text failed with \(result.rawValue)"])
        }
        print("set text field to \(query)")
    }
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
