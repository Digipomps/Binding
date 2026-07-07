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
    static let defaultStorageKey = "binding.pendingDeviceActions.v1"

    @Published private(set) var actions: [PendingDeviceAction]

    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = PendingActionInboxViewModel.defaultStorageKey
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.actions = Self.loadActions(defaults: defaults, storageKey: storageKey)
    }

    func reloadPersistedActions() {
        actions = Self.normalized(Self.loadActions(defaults: defaults, storageKey: storageKey))
    }

    func upsert(_ action: PendingDeviceAction) {
        if let index = actions.firstIndex(where: { $0.id == action.id }) {
            actions[index] = action
        } else {
            actions.insert(action, at: 0)
        }
        actions = Self.normalized(actions)
        persist()
    }

    func remove(ticketId: String) {
        actions.removeAll { $0.ticketId == ticketId }
        persist()
    }

    func removeAll() {
        actions.removeAll()
        persist()
    }

    private func persist() {
        if actions.isEmpty {
            defaults.removeObject(forKey: storageKey)
            return
        }

        do {
            let data = try JSONEncoder().encode(actions)
            defaults.set(data, forKey: storageKey)
        } catch {
            print("HAVEN pending action persistence failed: \(error)")
        }
    }

    private static func loadActions(
        defaults: UserDefaults,
        storageKey: String
    ) -> [PendingDeviceAction] {
        guard let data = defaults.data(forKey: storageKey) else {
            return []
        }
        do {
            return normalized(try JSONDecoder().decode([PendingDeviceAction].self, from: data))
        } catch {
            defaults.removeObject(forKey: storageKey)
            print("HAVEN pending action restore failed: \(error)")
            return []
        }
    }

    private static func normalized(_ actions: [PendingDeviceAction]) -> [PendingDeviceAction] {
        var actionsByTicketID: [String: PendingDeviceAction] = [:]
        for action in actions {
            if let existing = actionsByTicketID[action.ticketId],
               existing.receivedAt >= action.receivedAt {
                continue
            }
            actionsByTicketID[action.ticketId] = action
        }
        return actionsByTicketID.values.sorted { $0.receivedAt > $1.receivedAt }
    }
}
