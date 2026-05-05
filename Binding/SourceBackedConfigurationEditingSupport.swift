import Foundation
import CellBase

enum BindingEditableCellConfigurationError: Error {
    case missingSourceEndpoint
    case sourceCellNotMeddle(String)
    case invalidStatePayload
}

enum BindingEditableCellConfigurationContract {
    static let stateKeypath = "editableCellConfigurationState"
    static let applyKeypath = "applyEditableCellConfiguration"

    struct State {
        var configuration: CellConfiguration
        var fallbackConfiguration: CellConfiguration
        var revision: Int
        var hasStoredOverride: Bool
        var canEdit: Bool
        var sourceCellEndpoint: String
        var sourceCellName: String
        var accessSummary: String
    }

    nonisolated static func decodeConfiguration(from value: ValueType) -> CellConfiguration? {
        switch value {
        case .cellConfiguration(let configuration):
            return configuration
        case .object(let object):
            if let nested = object["configuration"],
               let configuration = decodeConfiguration(from: nested) {
                return configuration
            }
            guard let data = try? JSONEncoder().encode(object) else { return nil }
            return try? JSONDecoder().decode(CellConfiguration.self, from: data)
        default:
            return nil
        }
    }

    nonisolated static func decodeState(from value: ValueType) -> State? {
        guard case let .object(object) = value,
              let configuration = object["configuration"].flatMap(decodeConfiguration(from:)),
              let fallbackConfiguration = object["fallbackConfiguration"].flatMap(decodeConfiguration(from:)),
              let revision = integerValue(object["revision"]),
              let hasStoredOverride = boolValue(object["hasStoredOverride"]),
              let canEdit = boolValue(object["canEdit"]),
              let sourceCellEndpoint = stringValue(object["sourceCellEndpoint"]),
              let sourceCellName = stringValue(object["sourceCellName"])
        else {
            return nil
        }

        return State(
            configuration: configuration,
            fallbackConfiguration: fallbackConfiguration,
            revision: revision,
            hasStoredOverride: hasStoredOverride,
            canEdit: canEdit,
            sourceCellEndpoint: sourceCellEndpoint,
            sourceCellName: sourceCellName,
            accessSummary: stringValue(object["accessSummary"]) ?? ""
        )
    }

    nonisolated static func applyPayloadValue(configuration: CellConfiguration, expectedRevision: Int?) -> ValueType {
        var object: Object = ["configuration": .cellConfiguration(configuration)]
        if let expectedRevision {
            object["expectedRevision"] = .integer(expectedRevision)
        }
        return .object(object)
    }

    nonisolated private static func stringValue(_ value: ValueType?) -> String? {
        if case let .string(string)? = value {
            return string
        }
        return nil
    }

    nonisolated private static func integerValue(_ value: ValueType?) -> Int? {
        switch value {
        case .integer(let integer):
            return integer
        case .number(let integer):
            return integer
        default:
            return nil
        }
    }

    nonisolated private static func boolValue(_ value: ValueType?) -> Bool? {
        if case let .bool(bool)? = value {
            return bool
        }
        return nil
    }
}

enum BindingSourceBackedConfigurationEditingSupport {
    static func editableState(
        for configuration: CellConfiguration,
        requester: Identity
    ) async -> BindingEditableCellConfigurationContract.State? {
        guard let sourceCell = try? await resolveSourceCell(for: configuration, requester: requester),
              let value = try? await sourceCell.get(
                keypath: BindingEditableCellConfigurationContract.stateKeypath,
                requester: requester
              )
        else {
            return nil
        }
        return BindingEditableCellConfigurationContract.decodeState(from: value)
    }

    static func apply(
        _ configuration: CellConfiguration,
        expectedRevision: Int?,
        toSourceEndpoint sourceCellEndpoint: String,
        requester: Identity
    ) async throws -> BindingEditableCellConfigurationContract.State {
        let sourceCell = try await resolveSourceCell(
            sourceCellEndpoint: sourceCellEndpoint,
            requester: requester
        )
        let result = try await sourceCell.set(
            keypath: BindingEditableCellConfigurationContract.applyKeypath,
            value: BindingEditableCellConfigurationContract.applyPayloadValue(
                configuration: configuration,
                expectedRevision: expectedRevision
            ),
            requester: requester
        ) ?? .null

        guard let state = BindingEditableCellConfigurationContract.decodeState(from: result) else {
            throw BindingEditableCellConfigurationError.invalidStatePayload
        }
        return state
    }

    static func apply(
        _ configuration: CellConfiguration,
        expectedRevision: Int?,
        to sourceBackedConfiguration: CellConfiguration,
        requester: Identity
    ) async throws -> BindingEditableCellConfigurationContract.State {
        try await apply(
            configuration,
            expectedRevision: expectedRevision,
            toSourceEndpoint: sourceBackedConfiguration.discovery?.sourceCellEndpoint ?? "",
            requester: requester
        )
    }

    private static func resolveSourceCell(
        for configuration: CellConfiguration,
        requester: Identity
    ) async throws -> Meddle {
        try await resolveSourceCell(
            sourceCellEndpoint: configuration.discovery?.sourceCellEndpoint,
            requester: requester
        )
    }

    private static func resolveSourceCell(
        sourceCellEndpoint: String?,
        requester: Identity
    ) async throws -> Meddle {
        guard let sourceCellEndpoint,
              !sourceCellEndpoint.isEmpty else {
            throw BindingEditableCellConfigurationError.missingSourceEndpoint
        }
        guard let resolver = CellBase.defaultCellResolver else {
            throw CellBaseError.noResolver
        }
        guard let sourceCell = try await resolver.cellAtEndpoint(
            endpoint: sourceCellEndpoint,
            requester: requester
        ) as? Meddle else {
            throw BindingEditableCellConfigurationError.sourceCellNotMeddle(sourceCellEndpoint)
        }
        return sourceCell
    }
}
