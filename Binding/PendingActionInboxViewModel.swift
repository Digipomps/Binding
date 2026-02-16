import Foundation
import Combine

struct PendingDeviceAction: Identifiable, Codable, Equatable {
    var id: String
    var participantId: String
    var deviceId: String
    var ticketId: String
    var requiredActionKey: String
    var payload: [String: JSONValue]
    var receivedAt: Date
}

/// Small JSON bridge type for storing callback payloads in app state.
enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else {
            throw DecodingError.typeMismatch(JSONValue.self, .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

@MainActor
final class PendingActionInboxViewModel: ObservableObject {
    static let shared = PendingActionInboxViewModel()

    @Published private(set) var actions: [PendingDeviceAction] = []

    private init() {}

    func upsert(_ action: PendingDeviceAction) {
        if let index = actions.firstIndex(where: { $0.id == action.id }) {
            actions[index] = action
        } else {
            actions.insert(action, at: 0)
        }
    }

    func remove(ticketId: String) {
        actions.removeAll { $0.ticketId == ticketId }
    }
}
