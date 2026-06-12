import Foundation
import CellBase

enum SkeletonModifierValueKind {
    case bool
    case double
    case int
    case string
}

enum SkeletonModifierKey: String, CaseIterable, Identifiable {
    case padding
    case maxWidthInfinity
    case maxHeightInfinity
    case width
    case height
    case hAlignment
    case vAlignment
    case background
    case cornerRadius
    case shadowRadius
    case shadowX
    case shadowY
    case shadowColor
    case borderWidth
    case borderColor
    case opacity
    case hidden
    case foregroundColor
    case fontStyle
    case fontSize
    case fontWeight
    case lineLimit
    case multilineTextAlignment
    case minimumScaleFactor
    case motionHint
    case motionSourceRole

    var id: String { rawValue }
    var title: String { rawValue }

    var valueKind: SkeletonModifierValueKind {
        switch self {
        case .maxWidthInfinity, .maxHeightInfinity, .hidden:
            return .bool
        case .lineLimit:
            return .int
        case .hAlignment, .vAlignment, .background, .shadowColor, .borderColor, .foregroundColor, .fontStyle, .fontWeight, .multilineTextAlignment, .motionHint, .motionSourceRole:
            return .string
        default:
            return .double
        }
    }

    func isSet(in modifiers: SkeletonModifiers?) -> Bool {
        switch self {
        case .padding: return modifiers?.padding != nil
        case .maxWidthInfinity: return modifiers?.maxWidthInfinity != nil
        case .maxHeightInfinity: return modifiers?.maxHeightInfinity != nil
        case .width: return modifiers?.width != nil
        case .height: return modifiers?.height != nil
        case .hAlignment: return modifiers?.hAlignment != nil
        case .vAlignment: return modifiers?.vAlignment != nil
        case .background: return modifiers?.background != nil
        case .cornerRadius: return modifiers?.cornerRadius != nil
        case .shadowRadius: return modifiers?.shadowRadius != nil
        case .shadowX: return modifiers?.shadowX != nil
        case .shadowY: return modifiers?.shadowY != nil
        case .shadowColor: return modifiers?.shadowColor != nil
        case .borderWidth: return modifiers?.borderWidth != nil
        case .borderColor: return modifiers?.borderColor != nil
        case .opacity: return modifiers?.opacity != nil
        case .hidden: return modifiers?.hidden != nil
        case .foregroundColor: return modifiers?.foregroundColor != nil
        case .fontStyle: return modifiers?.fontStyle != nil
        case .fontSize: return modifiers?.fontSize != nil
        case .fontWeight: return modifiers?.fontWeight != nil
        case .lineLimit: return modifiers?.lineLimit != nil
        case .multilineTextAlignment: return modifiers?.multilineTextAlignment != nil
        case .minimumScaleFactor: return modifiers?.minimumScaleFactor != nil
        case .motionHint: return modifiers?.motionHint != nil
        case .motionSourceRole: return modifiers?.motionSourceRole != nil
        }
    }

    func boolValue(in modifiers: SkeletonModifiers?) -> Bool? {
        switch self {
        case .maxWidthInfinity: return modifiers?.maxWidthInfinity
        case .maxHeightInfinity: return modifiers?.maxHeightInfinity
        case .hidden: return modifiers?.hidden
        default: return nil
        }
    }

    func textValue(in modifiers: SkeletonModifiers?) -> String? {
        switch self {
        case .padding: return modifiers?.padding.map { "\($0)" }
        case .width: return modifiers?.width.map { "\($0)" }
        case .height: return modifiers?.height.map { "\($0)" }
        case .hAlignment: return modifiers?.hAlignment
        case .vAlignment: return modifiers?.vAlignment
        case .background: return modifiers?.background
        case .cornerRadius: return modifiers?.cornerRadius.map { "\($0)" }
        case .shadowRadius: return modifiers?.shadowRadius.map { "\($0)" }
        case .shadowX: return modifiers?.shadowX.map { "\($0)" }
        case .shadowY: return modifiers?.shadowY.map { "\($0)" }
        case .shadowColor: return modifiers?.shadowColor
        case .borderWidth: return modifiers?.borderWidth.map { "\($0)" }
        case .borderColor: return modifiers?.borderColor
        case .opacity: return modifiers?.opacity.map { "\($0)" }
        case .foregroundColor: return modifiers?.foregroundColor
        case .fontStyle: return modifiers?.fontStyle
        case .fontSize: return modifiers?.fontSize.map { "\($0)" }
        case .fontWeight: return modifiers?.fontWeight
        case .lineLimit: return modifiers?.lineLimit.map { "\($0)" }
        case .multilineTextAlignment: return modifiers?.multilineTextAlignment
        case .minimumScaleFactor: return modifiers?.minimumScaleFactor.map { "\($0)" }
        case .motionHint: return modifiers?.motionHint?.rawValue
        case .motionSourceRole: return modifiers?.motionSourceRole
        case .maxWidthInfinity, .maxHeightInfinity, .hidden:
            return nil
        }
    }

    func setDefault(in modifiers: inout SkeletonModifiers) {
        switch valueKind {
        case .bool:
            set(bool: false, in: &modifiers)
        case .double:
            set(double: self == .opacity ? 1 : 0, in: &modifiers)
        case .int:
            set(int: 1, in: &modifiers)
        case .string:
            set(string: defaultStringValue, in: &modifiers)
        }
    }

    func clear(in modifiers: inout SkeletonModifiers) {
        switch self {
        case .padding: modifiers.padding = nil
        case .maxWidthInfinity: modifiers.maxWidthInfinity = nil
        case .maxHeightInfinity: modifiers.maxHeightInfinity = nil
        case .width: modifiers.width = nil
        case .height: modifiers.height = nil
        case .hAlignment: modifiers.hAlignment = nil
        case .vAlignment: modifiers.vAlignment = nil
        case .background: modifiers.background = nil
        case .cornerRadius: modifiers.cornerRadius = nil
        case .shadowRadius: modifiers.shadowRadius = nil
        case .shadowX: modifiers.shadowX = nil
        case .shadowY: modifiers.shadowY = nil
        case .shadowColor: modifiers.shadowColor = nil
        case .borderWidth: modifiers.borderWidth = nil
        case .borderColor: modifiers.borderColor = nil
        case .opacity: modifiers.opacity = nil
        case .hidden: modifiers.hidden = nil
        case .foregroundColor: modifiers.foregroundColor = nil
        case .fontStyle: modifiers.fontStyle = nil
        case .fontSize: modifiers.fontSize = nil
        case .fontWeight: modifiers.fontWeight = nil
        case .lineLimit: modifiers.lineLimit = nil
        case .multilineTextAlignment: modifiers.multilineTextAlignment = nil
        case .minimumScaleFactor: modifiers.minimumScaleFactor = nil
        case .motionHint: modifiers.motionHint = nil
        case .motionSourceRole: modifiers.motionSourceRole = nil
        }
    }

    func set(bool value: Bool, in modifiers: inout SkeletonModifiers) {
        switch self {
        case .maxWidthInfinity: modifiers.maxWidthInfinity = value
        case .maxHeightInfinity: modifiers.maxHeightInfinity = value
        case .hidden: modifiers.hidden = value
        default: break
        }
    }

    func set(double value: Double, in modifiers: inout SkeletonModifiers) {
        switch self {
        case .padding: modifiers.padding = value
        case .width: modifiers.width = value
        case .height: modifiers.height = value
        case .cornerRadius: modifiers.cornerRadius = value
        case .shadowRadius: modifiers.shadowRadius = value
        case .shadowX: modifiers.shadowX = value
        case .shadowY: modifiers.shadowY = value
        case .borderWidth: modifiers.borderWidth = value
        case .opacity: modifiers.opacity = value
        case .fontSize: modifiers.fontSize = value
        case .minimumScaleFactor: modifiers.minimumScaleFactor = value
        default: break
        }
    }

    func set(int value: Int, in modifiers: inout SkeletonModifiers) {
        if self == .lineLimit {
            modifiers.lineLimit = value
        }
    }

    func set(string value: String, in modifiers: inout SkeletonModifiers) {
        switch self {
        case .hAlignment: modifiers.hAlignment = value
        case .vAlignment: modifiers.vAlignment = value
        case .background: modifiers.background = value
        case .shadowColor: modifiers.shadowColor = value
        case .borderColor: modifiers.borderColor = value
        case .foregroundColor: modifiers.foregroundColor = value
        case .fontStyle: modifiers.fontStyle = value
        case .fontWeight: modifiers.fontWeight = value
        case .multilineTextAlignment: modifiers.multilineTextAlignment = value
        case .motionHint: modifiers.motionHint = SkeletonMotionHint(rawValue: value.trimmingCharacters(in: .whitespacesAndNewlines))
        case .motionSourceRole: modifiers.motionSourceRole = value
        default: break
        }
    }

    private var defaultStringValue: String {
        switch self {
        case .hAlignment, .multilineTextAlignment:
            return "leading"
        case .vAlignment:
            return "center"
        case .background, .shadowColor, .borderColor, .foregroundColor:
            return "#FFFFFF"
        case .fontStyle:
            return "body"
        case .fontWeight:
            return "regular"
        case .motionHint:
            return SkeletonMotionHint.appear.rawValue
        case .motionSourceRole:
            return "suggestion-card"
        default:
            return ""
        }
    }
}

enum SkeletonModifierCatalog {
    private static let textOnlyKeys: Set<SkeletonModifierKey> = [
        .foregroundColor,
        .fontStyle,
        .fontSize,
        .fontWeight,
        .lineLimit,
        .multilineTextAlignment,
        .minimumScaleFactor
    ]

    static func addableKeys(for element: SkeletonElement?, modifiers: SkeletonModifiers?) -> [SkeletonModifierKey] {
        let supported = supportedKeys(for: element)
        return supported.filter { !$0.isSet(in: modifiers) }
    }

    static func activeKeys(modifiers: SkeletonModifiers?) -> [SkeletonModifierKey] {
        SkeletonModifierKey.allCases.filter { $0.isSet(in: modifiers) }
    }

    static func supportedKeys(for element: SkeletonElement?) -> [SkeletonModifierKey] {
        guard let element else { return SkeletonModifierKey.allCases }

        switch element {
        case .Text, .TextField:
            return SkeletonModifierKey.allCases
        default:
            return SkeletonModifierKey.allCases.filter { !textOnlyKeys.contains($0) }
        }
    }
}
