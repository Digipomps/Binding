//
//  ConfigurationCatalogCell.swift
//  Binding
//
//  Created by Codex on 11/02/2026.
//

import Foundation
import CellBase

final class ConfigurationCatalogCell: GeneralCell {
    private enum MenuSlot: String, Codable, CaseIterable {
        case upperLeft
        case upperMid
        case upperRight
        case lowerLeft
        case lowerMid
        case lowerRight

        var keypath: String { "\(rawValue)Menu" }
    }

    private struct CatalogEntry: Codable {
        var id: String
        var sourceCellEndpoint: String
        var sourceCellName: String
        var purpose: String
        var purposeDescription: String?
        var interests: [String]
        var menuSlots: [MenuSlot]
        var goal: CellConfiguration
        var configuration: CellConfiguration
        var updatedAt: Double

        func asObject() -> Object {
            var object: Object = [
                "id": .string(id),
                "sourceCellEndpoint": .string(sourceCellEndpoint),
                "sourceCellName": .string(sourceCellName),
                "purpose": .string(purpose),
                "interests": .list(interests.map { .string($0) }),
                "menuSlots": .list(menuSlots.map { .string($0.rawValue) }),
                "goal": .cellConfiguration(goal),
                "configuration": .cellConfiguration(configuration),
                "updatedAt": .float(updatedAt)
            ]
            if let purposeDescription {
                object["purposeDescription"] = .string(purposeDescription)
            }
            return object
        }
    }

    private struct CatalogPayload {
        var id: String?
        var sourceCellEndpoint: String
        var sourceCellName: String
        var purpose: String
        var purposeDescription: String?
        var interests: [String]
        var menuSlots: [MenuSlot]
        var goal: CellConfiguration
        var configuration: CellConfiguration
    }

    private struct ScaffoldPurposeTemplate {
        var sourceCellEndpoint: String
        var sourceCellName: String
        var purpose: String
        var purposeDescription: String
        var interests: [String]
        var menuSlots: [MenuSlot]
        var goal: CellConfiguration
        var configuration: CellConfiguration
    }

    private struct CatalogErrorEntry: Codable {
        var id: String
        var endpoint: String
        var operation: String
        var message: String
        var firstSeenAt: Double
        var lastSeenAt: Double
        var count: Int

        func asObject() -> Object {
            [
                "id": .string(id),
                "endpoint": .string(endpoint),
                "operation": .string(operation),
                "message": .string(message),
                "firstSeenAt": .float(firstSeenAt),
                "lastSeenAt": .float(lastSeenAt),
                "count": .integer(count)
            ]
        }
    }

    enum CodingKeys: CodingKey {
        case generalCell
        case owner
        case entries
        case errors
    }

    private let stateQueue = DispatchQueue(label: "Binding.ConfigurationCatalogCell.State")
    private var entriesByID: [String: CatalogEntry] = [:]
    private var catalogErrorsByEndpoint: [String: CatalogErrorEntry] = [:]
    private var syncInProgress: Bool = false

    required init(owner: Identity) async {
        await super.init(owner: owner)
        await setupPermissions(owner: owner)
        await setupKeys(owner: owner)
        await bootstrapDefaultsIfNeeded(requester: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try super.init(from: decoder)
        self.entriesByID = (try? container.decode([String: CatalogEntry].self, forKey: .entries)) ?? [:]
        self.catalogErrorsByEndpoint = (try? container.decode([String: CatalogErrorEntry].self, forKey: .errors)) ?? [:]
        if let owner = try container.decodeIfPresent(Identity.self, forKey: .owner) {
            Task {
                await self.setupPermissions(owner: owner)
                await self.setupKeys(owner: owner)
                await self.bootstrapDefaultsIfNeeded(requester: owner)
            }
        }
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(entriesByID, forKey: .entries)
        try container.encode(catalogErrorsByEndpoint, forKey: .errors)
    }

    private func setupPermissions(owner: Identity) async {
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("r---", for: "configurations")
        agreementTemplate.addGrant("r---", for: "catalogEntries")
        agreementTemplate.addGrant("r---", for: "errorLog")
        MenuSlot.allCases.forEach { agreementTemplate.addGrant("r---", for: $0.keypath) }
        agreementTemplate.addGrant("rw--", for: "addConfiguration")
        agreementTemplate.addGrant("rw--", for: "editConfiguration")
        agreementTemplate.addGrant("rw--", for: "updateConfiguration")
        agreementTemplate.addGrant("rw--", for: "removeConfiguration")
        agreementTemplate.addGrant("rw--", for: "match")
        agreementTemplate.addGrant("rw--", for: "matchPurpose")
        agreementTemplate.addGrant("rw--", for: "matchInterests")
        agreementTemplate.addGrant("rw--", for: "syncScaffoldPurposeGoals")
        agreementTemplate.addGrant("r---", for: "feed")
    }

    private func setupKeys(owner: Identity) async {
        await registerGet(key: "state", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "state", for: requester) else { return .string("denied") }
            return self.stateValue()
        }

        await registerGet(key: "configurations", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "configurations", for: requester) else { return .string("denied") }
            return .list(self.sortedEntries().map { .cellConfiguration($0.configuration) })
        }

        await registerGet(key: "catalogEntries", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "catalogEntries", for: requester) else { return .string("denied") }
            return .list(self.sortedEntries().map { .object($0.asObject()) })
        }

        await registerGet(key: "errorLog", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "errorLog", for: requester) else { return .string("denied") }
            return .list(self.sortedCatalogErrors().map { .object($0.asObject()) })
        }

        for slot in MenuSlot.allCases {
            await registerGet(key: slot.keypath, owner: owner) { [weak self] requester in
                guard let self = self else { return .null }
                guard await self.validateAccess("r---", at: slot.keypath, for: requester) else { return .string("denied") }
                return .list(self.menuConfigurations(for: slot).map { .cellConfiguration($0) })
            }
        }

        await registerSet(key: "addConfiguration", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "addConfiguration", for: requester) else { return .string("denied") }
            guard let catalogPayload = self.decodeCatalogPayload(payload, requireID: false) else {
                return .string("error: invalid payload for addConfiguration")
            }
            let entry = self.upsert(from: catalogPayload, keepExistingIDWhenMissing: false)
            await self.emitCatalogEvent(operation: "addConfiguration", entry: entry, requester: requester)
            return self.stateValue()
        }

        await registerSet(key: "editConfiguration", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "editConfiguration", for: requester) else { return .string("denied") }
            guard let catalogPayload = self.decodeCatalogPayload(payload, requireID: true) else {
                return .string("error: invalid payload for editConfiguration")
            }
            let entry = self.upsert(from: catalogPayload, keepExistingIDWhenMissing: true)
            await self.emitCatalogEvent(operation: "editConfiguration", entry: entry, requester: requester)
            return self.stateValue()
        }

        await registerSet(key: "updateConfiguration", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "updateConfiguration", for: requester) else { return .string("denied") }
            guard let catalogPayload = self.decodeCatalogPayload(payload, requireID: true) else {
                return .string("error: invalid payload for updateConfiguration")
            }
            let entry = self.upsert(from: catalogPayload, keepExistingIDWhenMissing: true)
            await self.emitCatalogEvent(operation: "updateConfiguration", entry: entry, requester: requester)
            return self.stateValue()
        }

        await registerSet(key: "removeConfiguration", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "removeConfiguration", for: requester) else { return .string("denied") }
            guard let id = self.extractID(payload), !id.isEmpty else {
                return .string("error: missing id")
            }
            let removed = self.remove(id: id)
            if removed {
                await self.emitCatalogEvent(operation: "removeConfiguration", entry: nil, requester: requester)
            }
            return self.stateValue()
        }

        await registerSet(key: "matchPurpose", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matchPurpose", for: requester) else { return .string("denied") }
            guard let purposeTerm = self.extractPurposeTerm(payload), !purposeTerm.isEmpty else {
                return .list([])
            }
            let result = self.matchConfigurations(purpose: purposeTerm, interests: nil, menuSlot: nil, limit: nil)
            return .list(result.map { .cellConfiguration($0.configuration) })
        }

        await registerSet(key: "matchInterests", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matchInterests", for: requester) else { return .string("denied") }
            guard let interests = self.extractInterests(payload), !interests.isEmpty else {
                return .list([])
            }
            let result = self.matchConfigurations(purpose: nil, interests: interests, menuSlot: nil, limit: nil)
            return .list(result.map { .cellConfiguration($0.configuration) })
        }

        await registerSet(key: "match", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "match", for: requester) else { return .string("denied") }
            let purpose = self.extractPurposeTerm(payload)
            let interests = self.extractInterests(payload)
            let menuSlot = self.extractMenuSlot(payload)
            let limit = self.extractLimit(payload)
            let result = self.matchConfigurations(purpose: purpose, interests: interests, menuSlot: menuSlot, limit: limit)
            return .list(result.map { .cellConfiguration($0.configuration) })
        }

        await registerSet(key: "syncScaffoldPurposeGoals", owner: owner) { [weak self] requester, _ in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "syncScaffoldPurposeGoals", for: requester) else { return .string("denied") }
            let importedCount = await self.syncScaffoldPurposeGoals(requester: requester)
            await self.emitCatalogEvent(operation: "syncScaffoldPurposeGoals", entry: nil, requester: requester)
            var result: Object = [:]
            result["importedCount"] = .integer(importedCount)
            result["state"] = self.stateValue()
            return .object(result)
        }
    }

    private func stateValue() -> ValueType {
        let entries = sortedEntries()
        var object: Object = [:]
        object["count"] = .integer(entries.count)
        object["purposes"] = .list(Array(Set(entries.map { $0.purpose })).sorted().map { .string($0) })
        let errorCount = stateQueue.sync { catalogErrorsByEndpoint.count }
        let syncActive = stateQueue.sync { syncInProgress }
        object["errorCount"] = .integer(errorCount)
        object["syncInProgress"] = .bool(syncActive)
        for slot in MenuSlot.allCases {
            let count = entries.filter { $0.menuSlots.contains(slot) }.count
            object["\(slot.rawValue)Count"] = .integer(count)
        }
        return .object(object)
    }

    private func sortedEntries() -> [CatalogEntry] {
        stateQueue.sync {
            entriesByID.values.sorted {
                if $0.purpose == $1.purpose {
                    return $0.configuration.name.localizedCaseInsensitiveCompare($1.configuration.name) == .orderedAscending
                }
                return $0.purpose.localizedCaseInsensitiveCompare($1.purpose) == .orderedAscending
            }
        }
    }

    private func menuConfigurations(for slot: MenuSlot) -> [CellConfiguration] {
        sortedEntries()
            .filter { $0.menuSlots.contains(slot) }
            .map(\.configuration)
    }

    private func sortedCatalogErrors() -> [CatalogErrorEntry] {
        stateQueue.sync {
            catalogErrorsByEndpoint.values.sorted { lhs, rhs in
                if lhs.lastSeenAt == rhs.lastSeenAt {
                    return lhs.endpoint.localizedCaseInsensitiveCompare(rhs.endpoint) == .orderedAscending
                }
                return lhs.lastSeenAt > rhs.lastSeenAt
            }
        }
    }

    private func extractID(_ payload: ValueType) -> String? {
        switch payload {
        case .string(let id):
            return id
        case .object(let object):
            if case let .string(id)? = object["id"] {
                return id
            }
            if case let .string(id)? = object["uuid"] {
                return id
            }
            return nil
        default:
            return nil
        }
    }

    private func decodeCatalogPayload(_ payload: ValueType, requireID: Bool) -> CatalogPayload? {
        guard case let .object(object) = payload else { return nil }
        let id = extractID(payload)
        if requireID && (id == nil || id?.isEmpty == true) {
            return nil
        }

        guard let configuration = decodeConfiguration(from: object["configuration"]) else { return nil }

        let goal = decodeConfiguration(from: object["goal"]) ?? configuration

        let sourceCellEndpoint: String
        if case let .string(endpoint)? = object["sourceCellEndpoint"], !endpoint.isEmpty {
            sourceCellEndpoint = endpoint
        } else if let firstEndpoint = configuration.cellReferences?.first?.endpoint {
            sourceCellEndpoint = firstEndpoint
        } else {
            sourceCellEndpoint = "cell:///Unknown"
        }

        let sourceCellName: String
        if case let .string(name)? = object["sourceCellName"], !name.isEmpty {
            sourceCellName = name
        } else {
            sourceCellName = configuration.name
        }

        let purpose: String
        if case let .string(purposeName)? = object["purpose"], !purposeName.isEmpty {
            purpose = purposeName
        } else {
            purpose = configuration.name
        }

        let purposeDescription: String?
        if case let .string(description)? = object["purposeDescription"], !description.isEmpty {
            purposeDescription = description
        } else {
            purposeDescription = nil
        }

        let interests = extractInterestList(from: object["interests"]) ?? []
        let menuSlots = extractMenuSlots(from: object["menuSlots"]) ?? [.upperLeft]

        return CatalogPayload(
            id: id,
            sourceCellEndpoint: sourceCellEndpoint,
            sourceCellName: sourceCellName,
            purpose: purpose,
            purposeDescription: purposeDescription,
            interests: interests,
            menuSlots: menuSlots,
            goal: goal,
            configuration: configuration
        )
    }

    private func decodeConfiguration(from value: ValueType?) -> CellConfiguration? {
        guard let value else { return nil }
        switch value {
        case .cellConfiguration(let configuration):
            return configuration
        case .object(let object):
            guard let data = try? JSONEncoder().encode(object) else { return nil }
            return try? JSONDecoder().decode(CellConfiguration.self, from: data)
        default:
            return nil
        }
    }

    private func extractInterestList(from value: ValueType?) -> [String]? {
        guard let value else { return nil }
        switch value {
        case .string(let single):
            return [single]
        case .list(let list):
            return list.compactMap {
                if case let .string(s) = $0, !s.isEmpty {
                    return s
                }
                return nil
            }
        default:
            return nil
        }
    }

    private func extractMenuSlots(from value: ValueType?) -> [MenuSlot]? {
        guard let value else { return nil }
        switch value {
        case .string(let slot):
            if let parsed = parseMenuSlot(slot) {
                return [parsed]
            }
            return nil
        case .list(let list):
            let parsed = list.compactMap { current -> MenuSlot? in
                if case let .string(slot) = current {
                    return parseMenuSlot(slot)
                }
                return nil
            }
            return parsed.isEmpty ? nil : parsed
        default:
            return nil
        }
    }

    private func parseMenuSlot(_ slot: String) -> MenuSlot? {
        let cleaned = slot.replacingOccurrences(of: "Menu", with: "")
        return MenuSlot(rawValue: cleaned)
    }

    private func upsert(from payload: CatalogPayload, keepExistingIDWhenMissing: Bool) -> CatalogEntry {
        let resolvedID: String = {
            if let id = payload.id, !id.isEmpty {
                return id
            }
            if keepExistingIDWhenMissing {
                if let existing = sortedEntries().first(where: { $0.configuration.uuid == payload.configuration.uuid }) {
                    return existing.id
                }
            }
            return UUID().uuidString
        }()

        let updatedEntry = CatalogEntry(
            id: resolvedID,
            sourceCellEndpoint: payload.sourceCellEndpoint,
            sourceCellName: payload.sourceCellName,
            purpose: payload.purpose,
            purposeDescription: payload.purposeDescription,
            interests: payload.interests,
            menuSlots: payload.menuSlots,
            goal: payload.goal,
            configuration: payload.configuration,
            updatedAt: Date().timeIntervalSince1970
        )

        stateQueue.sync {
            entriesByID[resolvedID] = updatedEntry
        }
        return updatedEntry
    }

    private func remove(id: String) -> Bool {
        stateQueue.sync {
            entriesByID.removeValue(forKey: id) != nil
        }
    }

    private func extractPurposeTerm(_ payload: ValueType) -> String? {
        switch payload {
        case .string(let term):
            return term
        case .object(let object):
            if case let .string(term)? = object["purpose"] {
                return term
            }
            if case let .string(term)? = object["term"] {
                return term
            }
            return nil
        default:
            return nil
        }
    }

    private func extractInterests(_ payload: ValueType) -> [String]? {
        switch payload {
        case .list:
            return extractInterestList(from: payload)
        case .string(let value):
            return [value]
        case .object(let object):
            return extractInterestList(from: object["interests"])
        default:
            return nil
        }
    }

    private func extractMenuSlot(_ payload: ValueType) -> MenuSlot? {
        guard case let .object(object) = payload else { return nil }
        if case let .string(slotName)? = object["menuSlot"] {
            return parseMenuSlot(slotName)
        }
        return nil
    }

    private func extractLimit(_ payload: ValueType) -> Int? {
        guard case let .object(object) = payload else { return nil }
        if case let .integer(limit)? = object["limit"] {
            return max(1, limit)
        }
        if case let .number(limit)? = object["limit"] {
            return max(1, limit)
        }
        return nil
    }

    private func matchConfigurations(
        purpose: String?,
        interests: [String]?,
        menuSlot: MenuSlot?,
        limit: Int?
    ) -> [CatalogEntry] {
        let normalizedPurpose = purpose?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedInterestSet: Set<String> = Set((interests ?? []).map { $0.lowercased() })

        let scored: [(CatalogEntry, Double)] = sortedEntries()
            .filter { entry in
                if let menuSlot {
                    return entry.menuSlots.contains(menuSlot)
                }
                return true
            }
            .map { entry in
                var score = 0.0

                if let normalizedPurpose, !normalizedPurpose.isEmpty {
                    if entry.purpose.lowercased().contains(normalizedPurpose) {
                        score += 2.0
                    }
                    if entry.configuration.name.lowercased().contains(normalizedPurpose) {
                        score += 1.0
                    }
                    if entry.purposeDescription?.lowercased().contains(normalizedPurpose) == true {
                        score += 0.8
                    }
                }

                if !normalizedInterestSet.isEmpty {
                    let entryInterests = Set(entry.interests.map { $0.lowercased() })
                    let overlap = normalizedInterestSet.intersection(entryInterests)
                    if !overlap.isEmpty {
                        score += Double(overlap.count) / Double(normalizedInterestSet.count)
                    }
                }

                if normalizedPurpose == nil && normalizedInterestSet.isEmpty {
                    score += 0.1
                }

                return (entry, score)
            }
            .filter { pair in
                if normalizedPurpose != nil || !normalizedInterestSet.isEmpty {
                    return pair.1 > 0.0
                }
                return true
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.configuration.name.localizedCaseInsensitiveCompare(rhs.0.configuration.name) == .orderedAscending
                }
                return lhs.1 > rhs.1
            }

        if let limit {
            return Array(scored.prefix(limit).map(\.0))
        }
        return scored.map(\.0)
    }

    private func bootstrapDefaultsIfNeeded(requester: Identity) async {
        let hasEntries = stateQueue.sync { !entriesByID.isEmpty }
        if hasEntries { return }
        _ = await syncScaffoldPurposeGoals(requester: requester, includeResolverLookups: false)
    }

    private func syncScaffoldPurposeGoals(requester: Identity, includeResolverLookups: Bool = true) async -> Int {
        guard beginSyncIfPossible() else { return 0 }
        defer { endSync() }

        var importedCount = 0
        let templates = Self.scaffoldPurposeTemplates()

        for template in templates {
            let payload = CatalogPayload(
                id: nil,
                sourceCellEndpoint: template.sourceCellEndpoint,
                sourceCellName: template.sourceCellName,
                purpose: template.purpose,
                purposeDescription: template.purposeDescription,
                interests: template.interests,
                menuSlots: template.menuSlots,
                goal: template.goal,
                configuration: template.configuration
            )

            let existingMatch = sortedEntries().first {
                $0.sourceCellEndpoint == template.sourceCellEndpoint && $0.purpose == template.purpose
            }

            if existingMatch == nil {
                _ = upsert(from: payload, keepExistingIDWhenMissing: false)
                importedCount += 1
            }
        }

        guard includeResolverLookups else { return importedCount }

        if let resolver = CellBase.defaultCellResolver {
            let uniqueEndpoints = Array(Set(templates.map(\.sourceCellEndpoint))).sorted()
            for endpoint in uniqueEndpoints {
                if shouldSkipResolverLookup(for: endpoint) {
                    continue
                }
                guard let emit = try? await resolver.cellAtEndpoint(endpoint: endpoint, requester: requester),
                      let meddle = emit as? Meddle,
                      let purposeGoalPayload = try? await meddle.get(keypath: "purposeGoal", requester: requester),
                      let parsedPayload = decodeCatalogPayload(purposeGoalPayload, requireID: false)
                else {
                    await reportMissingEndpoint(endpoint: endpoint, operation: "syncScaffoldPurposeGoals", message: "Cell unavailable or missing purposeGoal.", requester: requester)
                    continue
                }

                _ = upsert(from: parsedPayload, keepExistingIDWhenMissing: true)
                importedCount += 1
                clearCatalogError(for: endpoint)
            }
        }

        return importedCount
    }

    private func beginSyncIfPossible() -> Bool {
        stateQueue.sync {
            if syncInProgress { return false }
            syncInProgress = true
            return true
        }
    }

    private func endSync() {
        stateQueue.sync {
            syncInProgress = false
        }
    }

    private func shouldSkipResolverLookup(for endpoint: String) -> Bool {
        guard let url = URL(string: endpoint) else { return false }
        let pathName = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        return pathName == "configurationcatalog"
    }

    private func clearCatalogError(for endpoint: String) {
        stateQueue.sync {
            catalogErrorsByEndpoint.removeValue(forKey: endpoint)
        }
    }

    private func upsertCatalogError(endpoint: String, operation: String, message: String) -> (CatalogErrorEntry, Bool) {
        stateQueue.sync {
            let now = Date().timeIntervalSince1970
            if var existing = catalogErrorsByEndpoint[endpoint] {
                existing.count += 1
                existing.lastSeenAt = now
                existing.message = message
                existing.operation = operation
                catalogErrorsByEndpoint[endpoint] = existing
                return (existing, false)
            }

            let created = CatalogErrorEntry(
                id: UUID().uuidString,
                endpoint: endpoint,
                operation: operation,
                message: message,
                firstSeenAt: now,
                lastSeenAt: now,
                count: 1
            )
            catalogErrorsByEndpoint[endpoint] = created
            return (created, true)
        }
    }

    private func reportMissingEndpoint(endpoint: String, operation: String, message: String, requester: Identity) async {
        let (entry, isNew) = upsertCatalogError(endpoint: endpoint, operation: operation, message: message)
        guard isNew else { return }

        CellBase.defaultCellResolver?.logAction(
            context: ConnectContext(source: nil, target: self, identity: requester),
            action: "missing_cell_endpoint",
            param: endpoint
        )

        var payload: Object = [
            "endpoint": .string(entry.endpoint),
            "operation": .string(entry.operation),
            "message": .string(entry.message),
            "count": .integer(entry.count),
            "lastSeenAt": .float(entry.lastSeenAt)
        ]
        payload["state"] = stateValue()

        var flowElement = FlowElement(
            title: "configuration.catalog.error",
            content: .object(payload),
            properties: FlowElement.Properties(type: .alert, contentType: .object)
        )
        flowElement.topic = "configurationCatalog.error"
        flowElement.origin = uuid
        pushFlowElement(flowElement, requester: requester)
    }

    private static func scaffoldPurposeTemplates() -> [ScaffoldPurposeTemplate] {
        let chatConfig = referenceCardConfiguration(
            name: "Scaffold Chat",
            endpoint: "cell:///Chat",
            label: "chat",
            title: "Kommunikasjon",
            subtitle: "Direkte meldinger, status og samarbeid i teamet.",
            chip: "LIVE",
            borderColor: "#7C3AED"
        )
        let timesConfig = referenceCardConfiguration(
            name: "Scaffold Timeline",
            endpoint: "cell:///TimesWrapper",
            label: "times",
            title: "Tidslinje",
            subtitle: "Strukturert flyt av hendelser og planlagte aktiviteter.",
            chip: "PLAN",
            borderColor: "#0EA5E9"
        )
        let entitiesConfig = referenceCardConfiguration(
            name: "Scaffold Entities",
            endpoint: "cell:///EntitiesWrapper",
            label: "entities",
            title: "Entitetsnettverk",
            subtitle: "Se relasjoner, roller og avhengigheter mellom aktører.",
            chip: "MAP",
            borderColor: "#16A34A"
        )
        let locationsConfig = referenceCardConfiguration(
            name: "Scaffold Locations",
            endpoint: "cell:///LocationsWrapper",
            label: "locations",
            title: "Stedsbevissthet",
            subtitle: "Live oversikt over steder, nærvær og bevegelser.",
            chip: "GEO",
            borderColor: "#EA580C"
        )
        let signalConfig = referenceCardConfiguration(
            name: "Binding Signals",
            endpoint: "cell:///EventEmitter",
            label: "signals",
            title: "Signal Feed",
            subtitle: "Lokale events for rask verifisering av flyt i Binding.",
            chip: "TEST",
            borderColor: "#334155",
            startKey: "start"
        )
        let signalWorkbench = signalWorkbenchConfiguration()
        let catalogWorkbench = catalogWorkbenchConfiguration()
        let purposeLanding = appleIntelligenceLandingConfiguration()

        return [
            ScaffoldPurposeTemplate(
                sourceCellEndpoint: "cell:///Chat",
                sourceCellName: "ChatCell",
                purpose: "Kommunikasjon og samarbeid",
                purposeDescription: "Få delt meldinger i sanntid mellom deltakere.",
                interests: ["chat", "communication", "collaboration"],
                menuSlots: [.upperLeft, .upperMid],
                goal: chatConfig,
                configuration: chatConfig
            ),
            ScaffoldPurposeTemplate(
                sourceCellEndpoint: "cell:///TimesWrapper",
                sourceCellName: "TimesWrapperCell",
                purpose: "Tidslinje og planlegging",
                purposeDescription: "Følg tidsbaserte hendelser i en feed.",
                interests: ["time", "events", "planning"],
                menuSlots: [.upperRight],
                goal: timesConfig,
                configuration: timesConfig
            ),
            ScaffoldPurposeTemplate(
                sourceCellEndpoint: "cell:///EntitiesWrapper",
                sourceCellName: "EntitiesWrapperCell",
                purpose: "Entitetsoversikt",
                purposeDescription: "Vis relaterte entiteter og hendelser.",
                interests: ["entities", "network", "people"],
                menuSlots: [.lowerLeft],
                goal: entitiesConfig,
                configuration: entitiesConfig
            ),
            ScaffoldPurposeTemplate(
                sourceCellEndpoint: "cell:///LocationsWrapper",
                sourceCellName: "LocationsWrapperCell",
                purpose: "Stedsbevissthet",
                purposeDescription: "Følg stedshendelser i sanntid.",
                interests: ["location", "maps", "presence"],
                menuSlots: [.lowerMid],
                goal: locationsConfig,
                configuration: locationsConfig
            ),
            ScaffoldPurposeTemplate(
                sourceCellEndpoint: "cell:///EventEmitter",
                sourceCellName: "EventEmitterCell",
                purpose: "Signaler og diagnostikk",
                purposeDescription: "Bruk lokale signaler for å verifisere menyer og flyt.",
                interests: ["signals", "testing", "diagnostics"],
                menuSlots: [.lowerRight],
                goal: signalConfig,
                configuration: signalConfig
            ),
            ScaffoldPurposeTemplate(
                sourceCellEndpoint: "cell:///EventEmitter",
                sourceCellName: "EventEmitterCell",
                purpose: "Signalmonitor og knapper",
                purposeDescription: "Start/stopp signalstrøm og se innkommende FlowElements live.",
                interests: ["signals", "events", "debug"],
                menuSlots: [.upperLeft],
                goal: signalWorkbench,
                configuration: signalWorkbench
            ),
            ScaffoldPurposeTemplate(
                sourceCellEndpoint: "cell:///ConfigurationCatalog",
                sourceCellName: "ConfigurationCatalogCell",
                purpose: "Katalogoperasjoner",
                purposeDescription: "Synk katalogen, inspiser entries og observer katalog-events.",
                interests: ["catalog", "configurations", "operations"],
                menuSlots: [.upperMid],
                goal: catalogWorkbench,
                configuration: catalogWorkbench
            ),
            ScaffoldPurposeTemplate(
                sourceCellEndpoint: "cell:///AppleIntelligence",
                sourceCellName: "AppleIntelligenceCell",
                purpose: "Formål landing",
                purposeDescription: "Landingsside som hjelper brukeren å finne retning og fylle appen med mening.",
                interests: ["purpose", "assistant", "onboarding", "explore"],
                menuSlots: [.upperMid, .upperRight],
                goal: purposeLanding,
                configuration: purposeLanding
            )
        ]
    }

    private static func referenceCardConfiguration(
        name: String,
        endpoint: String,
        label: String,
        title: String,
        subtitle: String,
        chip: String,
        borderColor: String,
        startKey: String? = nil
    ) -> CellConfiguration {
        var configuration = CellConfiguration(name: name)
        configuration.description = subtitle

        var reference = CellReference(endpoint: endpoint, label: label)
        if let startKey {
            reference.addKeyAndValue(KeyValue(key: startKey))
        }
        configuration.addReference(reference)

        var titleText = SkeletonText(text: title)
        titleText.modifiers = modifier {
            $0.fontStyle = "title3"
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var subtitleText = SkeletonText(text: subtitle)
        subtitleText.modifiers = modifier {
            $0.foregroundColor = "#334155"
            $0.padding = 2
        }

        var chipText = SkeletonText(text: chip)
        chipText.modifiers = modifier {
            $0.foregroundColor = "#0F172A"
            $0.fontWeight = "semibold"
            $0.background = "#E2E8F0"
            $0.cornerRadius = 8
            $0.padding = 6
        }

        var hintText = SkeletonText(text: endpoint)
        hintText.modifiers = modifier {
            $0.foregroundColor = "#64748B"
            $0.fontSize = 12
        }

        var header = SkeletonHStack(elements: [.Text(titleText), .Spacer(SkeletonSpacer()), .Text(chipText)])
        header.modifiers = modifier { $0.padding = 2 }

        var card = SkeletonVStack(elements: [.HStack(header), .Text(subtitleText), .Text(hintText)])
        card.modifiers = modifier {
            $0.padding = 14
            $0.background = "#FFFFFF"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = borderColor
            $0.shadowRadius = 6
            $0.shadowY = 2
            $0.shadowColor = "#0F172A22"
        }

        configuration.skeleton = .VStack(card)
        return configuration
    }

    private static func signalWorkbenchConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Signal Workbench")
        configuration.description = "Kontroller lokale signaler og se innkommende flow i samme visning."

        var signalRef = CellReference(endpoint: "cell:///EventEmitter", label: "signals")
        signalRef.subscribeFeed = true
        configuration.addReference(signalRef)

        var title = SkeletonText(text: "Signal Workbench")
        title.modifiers = modifier {
            $0.fontStyle = "title3"
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var subtitle = SkeletonText(text: "Kjør start/stop og følg innkommende test-events i listen under.")
        subtitle.modifiers = modifier {
            $0.foregroundColor = "#334155"
        }

        var startButton = SkeletonButton(keypath: "signals.start", label: "Start")
        startButton.modifiers = modifier {
            $0.padding = 10
            $0.background = "#DCFCE7"
            $0.borderWidth = 1
            $0.borderColor = "#16A34A"
            $0.cornerRadius = 10
        }

        var stopButton = SkeletonButton(keypath: "signals.stop", label: "Stop")
        stopButton.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FEE2E2"
            $0.borderWidth = 1
            $0.borderColor = "#DC2626"
            $0.cornerRadius = 10
        }

        var signalRowTitle = SkeletonText(text: "Signal")
        signalRowTitle.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var signalRowValue = SkeletonText(keypath: "key")
        signalRowValue.modifiers = modifier {
            $0.foregroundColor = "#475569"
        }

        var signalRow = SkeletonVStack(elements: [
            .Text(signalRowTitle),
            .Text(signalRowValue)
        ])
        signalRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#F8FAFC"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#E2E8F0"
        }

        var incomingSignals = SkeletonList(topic: "test", keypath: nil, flowElementSkeleton: signalRow)
        incomingSignals.modifiers = modifier {
            $0.padding = 4
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        var root = SkeletonVStack(elements: [
            .Text(title),
            .Text(subtitle),
            .HStack(SkeletonHStack(elements: [.Button(startButton), .Button(stopButton)])),
            .List(incomingSignals)
        ])
        root.modifiers = modifier {
            $0.padding = 14
            $0.background = "#FFFFFF"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = "#94A3B8"
        }

        configuration.skeleton = .VStack(root)
        return configuration
    }

    private static func catalogWorkbenchConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Catalog Workbench")
        configuration.description = "Driftspanel for ConfigurationCatalog med synk, entries og events."

        var catalogRef = CellReference(endpoint: "cell:///ConfigurationCatalog", label: "catalog")
        catalogRef.subscribeFeed = true
        configuration.addReference(catalogRef)

        var title = SkeletonText(text: "Catalog Workbench")
        title.modifiers = modifier {
            $0.fontStyle = "title3"
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var subtitle = SkeletonText(text: "Synk fra scaffold og følg katalogens tilstand/endringer.")
        subtitle.modifiers = modifier {
            $0.foregroundColor = "#334155"
        }

        var syncButton = SkeletonButton(keypath: "catalog.syncScaffoldPurposeGoals", label: "Sync fra Scaffold", payload: .null)
        syncButton.modifiers = modifier {
            $0.padding = 10
            $0.background = "#DBEAFE"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#2563EB"
        }

        var matchButton = SkeletonButton(
            keypath: "catalog.matchPurpose",
            label: "Match: plan",
            payload: .object(["purpose": .string("plan")])
        )
        matchButton.modifiers = modifier {
            $0.padding = 10
            $0.background = "#E2E8F0"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#64748B"
        }

        var stateButton = SkeletonButton(keypath: "catalog.state", label: "Les State")
        stateButton.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FEF3C7"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#D97706"
        }

        var entryPurpose = SkeletonText(keypath: "purpose")
        entryPurpose.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var entryDescription = SkeletonText(keypath: "purposeDescription")
        entryDescription.modifiers = modifier {
            $0.foregroundColor = "#475569"
        }

        var entryEndpoint = SkeletonText(keypath: "sourceCellEndpoint")
        entryEndpoint.modifiers = modifier {
            $0.foregroundColor = "#64748B"
            $0.fontSize = 12
        }

        var entryRow = SkeletonVStack(elements: [
            .Text(entryPurpose),
            .Text(entryDescription),
            .Text(entryEndpoint)
        ])
        entryRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#F8FAFC"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#E2E8F0"
        }

        var entriesList = SkeletonList(topic: nil, keypath: "catalog.catalogEntries", flowElementSkeleton: entryRow)
        entriesList.modifiers = modifier {
            $0.padding = 4
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        var eventOperation = SkeletonText(keypath: "operation")
        eventOperation.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var eventCount = SkeletonText(keypath: "state.count")
        eventCount.modifiers = modifier {
            $0.foregroundColor = "#334155"
        }

        var eventRow = SkeletonVStack(elements: [
            .Text(eventOperation),
            .Text(eventCount)
        ])
        eventRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FFFFFF"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#E2E8F0"
        }

        var catalogEvents = SkeletonList(topic: "configurationCatalog", keypath: nil, flowElementSkeleton: eventRow)
        catalogEvents.modifiers = modifier {
            $0.padding = 4
            $0.background = "#F8FAFC"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        var errorEndpoint = SkeletonText(keypath: "endpoint")
        errorEndpoint.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#7F1D1D"
        }

        var errorMessage = SkeletonText(keypath: "message")
        errorMessage.modifiers = modifier {
            $0.foregroundColor = "#B91C1C"
        }

        var errorCount = SkeletonText(keypath: "count")
        errorCount.modifiers = modifier {
            $0.foregroundColor = "#991B1B"
            $0.fontSize = 12
        }

        var errorRow = SkeletonVStack(elements: [
            .Text(errorEndpoint),
            .Text(errorMessage),
            .Text(errorCount)
        ])
        errorRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FEF2F2"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#FCA5A5"
        }

        var errorLogList = SkeletonList(topic: nil, keypath: "catalog.errorLog", flowElementSkeleton: errorRow)
        errorLogList.modifiers = modifier {
            $0.padding = 4
            $0.background = "#FFF1F2"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#FECACA"
        }

        var root = SkeletonVStack(elements: [
            .Text(title),
            .Text(subtitle),
            .HStack(SkeletonHStack(elements: [.Button(syncButton), .Button(matchButton), .Button(stateButton)])),
            .Text(SkeletonText(text: "Entries")),
            .List(entriesList),
            .Text(SkeletonText(text: "Catalog events")),
            .List(catalogEvents),
            .Text(SkeletonText(text: "Error log")),
            .List(errorLogList)
        ])
        root.modifiers = modifier {
            $0.padding = 14
            $0.background = "#FFFFFF"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = "#94A3B8"
        }

        configuration.skeleton = .VStack(root)
        return configuration
    }

    private static func appleIntelligenceLandingConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Purpose Landing (AI)")
        configuration.description = "Landingsside for å finne formål og fylle appen med relevante forslag."

        var aiReference = CellReference(endpoint: "cell:///AppleIntelligence", label: "intelligence")
        aiReference.subscribeFeed = true
        configuration.addReference(aiReference)

        var title = SkeletonText(text: "Trenger du hjelp til å finne formål?")
        title.modifiers = modifier {
            $0.fontStyle = "title3"
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var intro = SkeletonText(text: "Denne landingssiden bruker AppleIntelligenceCell for å foreslå retning, formål og neste steg.")
        intro.modifiers = modifier {
            $0.foregroundColor = "#334155"
        }

        var sendPrompt = SkeletonButton(
            keypath: "intelligence.ai.sendPrompt",
            label: "Finn formål for meg",
            payload: .object([
                "prompt": .string("Hjelp meg finne 3 konkrete formål jeg kan fylle appen med i dag."),
                "topic": .string("explore.request")
            ])
        )
        sendPrompt.modifiers = modifier {
            $0.padding = 10
            $0.background = "#D1FAE5"
            $0.borderWidth = 1
            $0.borderColor = "#059669"
            $0.cornerRadius = 10
        }

        var discover = SkeletonButton(keypath: "intelligence.ai.discover", label: "Discover", payload: .null)
        discover.modifiers = modifier {
            $0.padding = 10
            $0.background = "#DBEAFE"
            $0.borderWidth = 1
            $0.borderColor = "#2563EB"
            $0.cornerRadius = 10
        }

        var ensurePurpose = SkeletonButton(keypath: "intelligence.ai.ensurePurpose", label: "Ensure Purpose", payload: .null)
        ensurePurpose.modifiers = modifier {
            $0.padding = 10
            $0.background = "#EDE9FE"
            $0.borderWidth = 1
            $0.borderColor = "#7C3AED"
            $0.cornerRadius = 10
        }

        var buildCluster = SkeletonButton(keypath: "intelligence.ai.buildCluster", label: "Build Cluster", payload: .null)
        buildCluster.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FFEDD5"
            $0.borderWidth = 1
            $0.borderColor = "#EA580C"
            $0.cornerRadius = 10
        }

        var rank = SkeletonButton(keypath: "intelligence.ai.rank", label: "Rank", payload: .null)
        rank.modifiers = modifier {
            $0.padding = 10
            $0.background = "#F1F5F9"
            $0.borderWidth = 1
            $0.borderColor = "#475569"
            $0.cornerRadius = 10
        }

        var aiStateStatus = SkeletonText(keypath: "status")
        aiStateStatus.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var aiStatePurpose = SkeletonText(keypath: "currentPurposeRef")
        aiStatePurpose.modifiers = modifier {
            $0.foregroundColor = "#334155"
        }

        var aiStateCluster = SkeletonText(keypath: "purposeClusterRefs")
        aiStateCluster.modifiers = modifier {
            $0.foregroundColor = "#64748B"
            $0.fontSize = 12
        }

        var aiStateRow = SkeletonVStack(elements: [
            .Text(aiStateStatus),
            .Text(aiStatePurpose),
            .Text(aiStateCluster)
        ])
        aiStateRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#F8FAFC"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#E2E8F0"
        }

        var recommendationsFlow = SkeletonList(topic: "ai.assistant.recommendations", keypath: nil, flowElementSkeleton: aiStateRow)
        recommendationsFlow.modifiers = modifier {
            $0.padding = 4
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        var requestPrompt = SkeletonText(keypath: "prompt")
        requestPrompt.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var requestInstructions = SkeletonText(keypath: "instructions")
        requestInstructions.modifiers = modifier {
            $0.foregroundColor = "#475569"
        }

        var requestRow = SkeletonVStack(elements: [
            .Text(requestPrompt),
            .Text(requestInstructions)
        ])
        requestRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FFFFFF"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#E2E8F0"
        }

        var exploreRequests = SkeletonList(topic: "explore.request", keypath: nil, flowElementSkeleton: requestRow)
        exploreRequests.modifiers = modifier {
            $0.padding = 4
            $0.background = "#F8FAFC"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        var root = SkeletonVStack(elements: [
            .Text(title),
            .Text(intro),
            .HStack(SkeletonHStack(elements: [.Button(sendPrompt)])),
            .HStack(SkeletonHStack(elements: [.Button(discover), .Button(ensurePurpose), .Button(buildCluster), .Button(rank)])),
            .Text(SkeletonText(text: "Anbefalinger")),
            .List(recommendationsFlow),
            .Text(SkeletonText(text: "Incoming explore-requests")),
            .List(exploreRequests)
        ])
        root.modifiers = modifier {
            $0.padding = 14
            $0.background = "#FFFFFF"
            $0.cornerRadius = 14
            $0.borderWidth = 1
            $0.borderColor = "#94A3B8"
        }

        configuration.skeleton = .VStack(root)
        return configuration
    }

    private static func modifier(_ configure: (inout SkeletonModifiers) -> Void) -> SkeletonModifiers {
        var modifiers = SkeletonModifiers()
        configure(&modifiers)
        return modifiers
    }

    private func emitCatalogEvent(operation: String, entry: CatalogEntry?, requester: Identity) async {
        var payload: Object = ["operation": .string(operation), "state": stateValue()]
        if let entry {
            payload["entry"] = .object(entry.asObject())
        }

        var flowElement = FlowElement(
            title: "configuration.catalog.\(operation)",
            content: .object(payload),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flowElement.topic = "configurationCatalog"
        flowElement.origin = uuid

        if let owner = try? await getOwner(requester: requester) {
            pushFlowElement(flowElement, requester: owner)
        } else {
            pushFlowElement(flowElement, requester: requester)
        }
    }
}
