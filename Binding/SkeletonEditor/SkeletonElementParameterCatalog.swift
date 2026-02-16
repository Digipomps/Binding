import Foundation
import CellBase

enum SkeletonElementParameterValueKind {
    case bool
    case double
    case string
}

enum SkeletonElementParameterKey: String, CaseIterable, Identifiable {
    case text
    case endpoint
    case keypath
    case name
    case type
    case resizable
    case scaledToFit
    case width
    case sourceKeypath
    case targetKeypath
    case placeholder
    case topic
    case filterTypes
    case label
    case axis
    case spacing
    case padding
    case isOn

    var id: String { rawValue }
    var title: String { rawValue }

    var valueKind: SkeletonElementParameterValueKind {
        switch self {
        case .resizable, .scaledToFit, .isOn:
            return .bool
        case .width, .spacing, .padding:
            return .double
        default:
            return .string
        }
    }

    func isSet(on element: SkeletonElement) -> Bool {
        switch self {
        case .text:
            switch element {
            case .Text(let text): return text.text != nil
            case .TextField(let textField): return textField.text != nil
            default: return false
            }
        case .endpoint:
            switch element {
            case .Text(let text): return text.url != nil
            case .Image(let image): return image.url != nil
            case .Button(let button): return button.url != nil
            default: return false
            }
        case .keypath:
            switch element {
            case .Text(let text): return text.keypath != nil
            case .List(let list): return list.keypath != nil
            case .Reference, .Button, .Toggle:
                return true
            default:
                return false
            }
        case .name:
            if case .Image(let image) = element { return image.name != nil }
            return false
        case .type:
            if case .Image(let image) = element { return image.type != nil }
            return false
        case .resizable:
            if case .Image(let image) = element { return image.resizable }
            return false
        case .scaledToFit:
            switch element {
            case .Image(let image): return image.scaledToFit
            case .Reference(let reference): return reference.scaledToFit
            default: return false
            }
        case .width:
            if case .Spacer(let spacer) = element { return spacer.width != nil }
            return false
        case .sourceKeypath:
            if case .TextField(let textField) = element { return textField.sourceKeypath != nil }
            return false
        case .targetKeypath:
            if case .TextField(let textField) = element { return textField.targetKeypath != nil }
            return false
        case .placeholder:
            if case .TextField(let textField) = element { return textField.placeholder != nil }
            return false
        case .topic:
            switch element {
            case .List(let list): return list.topic != nil
            case .Reference: return true
            default: return false
            }
        case .filterTypes:
            switch element {
            case .List(let list): return !(list.filterTypes ?? []).isEmpty
            case .Reference(let reference): return !(reference.filterTypes ?? []).isEmpty
            default: return false
            }
        case .label:
            switch element {
            case .Button, .Toggle:
                return true
            default:
                return false
            }
        case .axis:
            if case .ScrollView(let scrollView) = element { return scrollView.axis != nil }
            return false
        case .spacing:
            if case .Grid(let grid) = element { return grid.spacing != nil }
            return false
        case .padding:
            switch element {
            case .Image(let image): return image.padding != nil
            case .Reference(let reference): return reference.padding != nil
            default: return false
            }
        case .isOn:
            if case .Toggle(let toggle) = element { return toggle.isOn }
            return false
        }
    }

    func canRemove(on element: SkeletonElement) -> Bool {
        switch self {
        case .keypath:
            switch element {
            case .Reference, .Button, .Toggle:
                return false
            default:
                return true
            }
        case .topic:
            switch element {
            case .Reference:
                return false
            default:
                return true
            }
        case .label:
            switch element {
            case .Button, .Toggle:
                return false
            default:
                return true
            }
        default:
            return true
        }
    }

    func boolValue(on element: SkeletonElement) -> Bool? {
        switch self {
        case .resizable:
            if case .Image(let image) = element { return image.resizable }
            return nil
        case .scaledToFit:
            switch element {
            case .Image(let image): return image.scaledToFit
            case .Reference(let reference): return reference.scaledToFit
            default: return nil
            }
        case .isOn:
            if case .Toggle(let toggle) = element { return toggle.isOn }
            return nil
        default:
            return nil
        }
    }

    func textValue(on element: SkeletonElement) -> String? {
        switch self {
        case .text:
            switch element {
            case .Text(let text): return text.text
            case .TextField(let textField): return textField.text
            default: return nil
            }
        case .endpoint:
            switch element {
            case .Text(let text): return text.url?.absoluteString
            case .Image(let image): return image.url?.absoluteString
            case .Button(let button): return button.url
            default: return nil
            }
        case .keypath:
            switch element {
            case .Text(let text): return text.keypath
            case .List(let list): return list.keypath
            case .Reference(let reference): return reference.keypath
            case .Button(let button): return button.keypath
            case .Toggle(let toggle): return toggle.keypath
            default: return nil
            }
        case .name:
            if case .Image(let image) = element { return image.name }
            return nil
        case .type:
            if case .Image(let image) = element { return image.type }
            return nil
        case .width:
            if case .Spacer(let spacer) = element { return spacer.width.map { "\($0)" } }
            return nil
        case .sourceKeypath:
            if case .TextField(let textField) = element { return textField.sourceKeypath }
            return nil
        case .targetKeypath:
            if case .TextField(let textField) = element { return textField.targetKeypath }
            return nil
        case .placeholder:
            if case .TextField(let textField) = element { return textField.placeholder }
            return nil
        case .topic:
            switch element {
            case .List(let list): return list.topic
            case .Reference(let reference): return reference.topic
            default: return nil
            }
        case .filterTypes:
            switch element {
            case .List(let list): return list.filterTypes?.joined(separator: ", ")
            case .Reference(let reference): return reference.filterTypes?.joined(separator: ", ")
            default: return nil
            }
        case .label:
            switch element {
            case .Button(let button): return button.label
            case .Toggle(let toggle): return toggle.label
            default: return nil
            }
        case .axis:
            if case .ScrollView(let scrollView) = element { return scrollView.axis }
            return nil
        case .spacing:
            if case .Grid(let grid) = element { return grid.spacing.map { "\($0)" } }
            return nil
        case .padding:
            switch element {
            case .Image(let image): return image.padding.map { "\($0)" }
            case .Reference(let reference): return reference.padding.map { "\($0)" }
            default: return nil
            }
        case .resizable, .scaledToFit, .isOn:
            return nil
        }
    }

    func setDefault(on element: inout SkeletonElement) {
        switch self {
        case .text:
            _ = set(string: "New text", on: &element)
        case .endpoint:
            _ = set(string: "cell:///Porthole", on: &element)
        case .keypath:
            _ = set(string: "value", on: &element)
        case .name:
            _ = set(string: "image", on: &element)
        case .type:
            _ = set(string: "png", on: &element)
        case .sourceKeypath:
            _ = set(string: "input.value", on: &element)
        case .targetKeypath:
            _ = set(string: "input.value", on: &element)
        case .placeholder:
            _ = set(string: "Input", on: &element)
        case .topic:
            _ = set(string: "default", on: &element)
        case .filterTypes:
            _ = set(string: "content", on: &element)
        case .label:
            _ = set(string: "Label", on: &element)
        case .axis:
            _ = set(string: "vertical", on: &element)
        case .width:
            set(double: 16, on: &element)
        case .spacing:
            set(double: 8, on: &element)
        case .padding:
            set(double: 0, on: &element)
        case .resizable, .scaledToFit, .isOn:
            set(bool: true, on: &element)
        }
    }

    func clear(on element: inout SkeletonElement) {
        switch self {
        case .text:
            switch element {
            case .Text(var text):
                text.text = nil
                element = .Text(text)
            case .TextField(var textField):
                textField.text = nil
                element = .TextField(textField)
            default:
                break
            }
        case .endpoint:
            switch element {
            case .Text(var text):
                text.url = nil
                element = .Text(text)
            case .Image(var image):
                image.url = nil
                element = .Image(image)
            case .Button(var button):
                button.url = nil
                element = .Button(button)
            default:
                break
            }
        case .keypath:
            switch element {
            case .Text(var text):
                text.keypath = nil
                element = .Text(text)
            case .List(var list):
                list.keypath = nil
                element = .List(list)
            default:
                break
            }
        case .name:
            if case .Image(var image) = element {
                image.name = nil
                element = .Image(image)
            }
        case .type:
            if case .Image(var image) = element {
                image.type = nil
                element = .Image(image)
            }
        case .resizable:
            set(bool: false, on: &element)
        case .scaledToFit:
            set(bool: false, on: &element)
        case .width:
            if case .Spacer(var spacer) = element {
                spacer.width = nil
                element = .Spacer(spacer)
            }
        case .sourceKeypath:
            if case .TextField(var textField) = element {
                textField.sourceKeypath = nil
                element = .TextField(textField)
            }
        case .targetKeypath:
            if case .TextField(var textField) = element {
                textField.targetKeypath = nil
                element = .TextField(textField)
            }
        case .placeholder:
            if case .TextField(var textField) = element {
                textField.placeholder = nil
                element = .TextField(textField)
            }
        case .topic:
            if case .List(var list) = element {
                list.topic = nil
                element = .List(list)
            }
        case .filterTypes:
            switch element {
            case .List(var list):
                list.filterTypes = nil
                element = .List(list)
            case .Reference(var reference):
                reference.filterTypes = nil
                element = .Reference(reference)
            default:
                break
            }
        case .label:
            break
        case .axis:
            if case .ScrollView(var scrollView) = element {
                scrollView.axis = nil
                element = .ScrollView(scrollView)
            }
        case .spacing:
            if case .Grid(var grid) = element {
                grid.spacing = nil
                element = .Grid(grid)
            }
        case .padding:
            switch element {
            case .Image(var image):
                image.padding = nil
                element = .Image(image)
            case .Reference(var reference):
                reference.padding = nil
                element = .Reference(reference)
            default:
                break
            }
        case .isOn:
            set(bool: false, on: &element)
        }
    }

    func set(bool value: Bool, on element: inout SkeletonElement) {
        switch self {
        case .resizable:
            if case .Image(var image) = element {
                image.resizable = value
                element = .Image(image)
            }
        case .scaledToFit:
            switch element {
            case .Image(var image):
                image.scaledToFit = value
                element = .Image(image)
            case .Reference(var reference):
                reference.scaledToFit = value
                element = .Reference(reference)
            default:
                break
            }
        case .isOn:
            if case .Toggle(var toggle) = element {
                toggle.isOn = value
                element = .Toggle(toggle)
            }
        default:
            break
        }
    }

    func set(double value: Double, on element: inout SkeletonElement) {
        switch self {
        case .width:
            if case .Spacer(var spacer) = element {
                spacer.width = value
                element = .Spacer(spacer)
            }
        case .spacing:
            if case .Grid(var grid) = element {
                grid.spacing = value
                element = .Grid(grid)
            }
        case .padding:
            switch element {
            case .Image(var image):
                image.padding = value
                element = .Image(image)
            case .Reference(var reference):
                reference.padding = value
                element = .Reference(reference)
            default:
                break
            }
        default:
            break
        }
    }

    @discardableResult
    func set(string value: String, on element: inout SkeletonElement) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        switch self {
        case .text:
            switch element {
            case .Text(var text):
                text.text = trimmed.isEmpty ? nil : trimmed
                element = .Text(text)
                return true
            case .TextField(var textField):
                textField.text = trimmed.isEmpty ? nil : trimmed
                element = .TextField(textField)
                return true
            default:
                return false
            }
        case .endpoint:
            switch element {
            case .Text(var text):
                if trimmed.isEmpty {
                    text.url = nil
                } else if let url = URL(string: trimmed) {
                    text.url = url
                } else {
                    return false
                }
                element = .Text(text)
                return true
            case .Image(var image):
                if trimmed.isEmpty {
                    image.url = nil
                } else if let url = URL(string: trimmed) {
                    image.url = url
                } else {
                    return false
                }
                element = .Image(image)
                return true
            case .Button(var button):
                button.url = trimmed.isEmpty ? nil : trimmed
                element = .Button(button)
                return true
            default:
                return false
            }
        case .keypath:
            switch element {
            case .Text(var text):
                text.keypath = trimmed.isEmpty ? nil : trimmed
                element = .Text(text)
                return true
            case .List(var list):
                list.keypath = trimmed.isEmpty ? nil : trimmed
                element = .List(list)
                return true
            case .Reference(var reference):
                reference.keypath = trimmed
                element = .Reference(reference)
                return true
            case .Button(var button):
                button.keypath = trimmed
                element = .Button(button)
                return true
            case .Toggle(var toggle):
                toggle.keypath = trimmed
                element = .Toggle(toggle)
                return true
            default:
                return false
            }
        case .name:
            if case .Image(var image) = element {
                image.name = trimmed.isEmpty ? nil : trimmed
                element = .Image(image)
                return true
            }
            return false
        case .type:
            if case .Image(var image) = element {
                image.type = trimmed.isEmpty ? nil : trimmed
                element = .Image(image)
                return true
            }
            return false
        case .sourceKeypath:
            if case .TextField(var textField) = element {
                textField.sourceKeypath = trimmed.isEmpty ? nil : trimmed
                element = .TextField(textField)
                return true
            }
            return false
        case .targetKeypath:
            if case .TextField(var textField) = element {
                textField.targetKeypath = trimmed.isEmpty ? nil : trimmed
                element = .TextField(textField)
                return true
            }
            return false
        case .placeholder:
            if case .TextField(var textField) = element {
                textField.placeholder = trimmed.isEmpty ? nil : trimmed
                element = .TextField(textField)
                return true
            }
            return false
        case .topic:
            switch element {
            case .List(var list):
                list.topic = trimmed.isEmpty ? nil : trimmed
                element = .List(list)
                return true
            case .Reference(var reference):
                reference.topic = trimmed
                element = .Reference(reference)
                return true
            default:
                return false
            }
        case .filterTypes:
            let types = Self.parseList(trimmed)
            switch element {
            case .List(var list):
                list.filterTypes = types.isEmpty ? nil : types
                element = .List(list)
                return true
            case .Reference(var reference):
                reference.filterTypes = types.isEmpty ? nil : types
                element = .Reference(reference)
                return true
            default:
                return false
            }
        case .label:
            switch element {
            case .Button(var button):
                button.label = trimmed
                element = .Button(button)
                return true
            case .Toggle(var toggle):
                toggle.label = trimmed
                element = .Toggle(toggle)
                return true
            default:
                return false
            }
        case .axis:
            if case .ScrollView(var scrollView) = element {
                scrollView.axis = trimmed.isEmpty ? nil : trimmed
                element = .ScrollView(scrollView)
                return true
            }
            return false
        case .width, .spacing, .padding, .resizable, .scaledToFit, .isOn:
            return false
        }
    }

    private static func parseList(_ text: String) -> [String] {
        text
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

enum SkeletonElementParameterCatalog {
    static func supportedKeys(for element: SkeletonElement?) -> [SkeletonElementParameterKey] {
        guard let element else { return [] }

        switch element {
        case .Text:
            return [.text, .endpoint, .keypath]
        case .TextField:
            return [.text, .sourceKeypath, .targetKeypath, .placeholder]
        case .Image:
            return [.name, .endpoint, .type, .resizable, .scaledToFit, .padding]
        case .Spacer:
            return [.width]
        case .List:
            return [.topic, .keypath, .filterTypes]
        case .Reference:
            return [.keypath, .topic, .filterTypes, .scaledToFit, .padding]
        case .Button:
            return [.label, .keypath, .endpoint]
        case .ScrollView:
            return [.axis]
        case .Grid:
            return [.spacing]
        case .Toggle:
            return [.label, .keypath, .isOn]
        case .Object, .HStack, .VStack, .Divider, .Section, .ZStack:
            return []
        }
    }

    static func activeKeys(for element: SkeletonElement?) -> [SkeletonElementParameterKey] {
        guard let element else { return [] }
        return supportedKeys(for: element).filter { $0.isSet(on: element) }
    }

    static func addableKeys(for element: SkeletonElement?) -> [SkeletonElementParameterKey] {
        guard let element else { return [] }
        return supportedKeys(for: element).filter { !$0.isSet(on: element) }
    }
}
