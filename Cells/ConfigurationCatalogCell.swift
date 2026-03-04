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

    private enum SupportedInsertionMode: String, Codable, CaseIterable {
        case root
        case component
        case both
        case unknown
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
        var displayName: String?
        var summary: String?
        var categoryPath: [String]?
        var tags: [String]?
        var purposeRefs: [String]?
        var interestRefs: [String]?
        var supportedInsertionModes: [SupportedInsertionMode]?
        var supportedTargetKinds: [String]?
        var ioGetKeys: [String]?
        var ioSetKeys: [String]?
        var ioTopics: [String]?
        var ioFilterTypes: [String]?
        var authRequired: Bool?
        var policyHints: [String]?
        var flowDriven: Bool?
        var editable: Bool?
        var recommendedContexts: [String]?
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
            if let displayName, !displayName.isEmpty {
                object["displayName"] = .string(displayName)
            }
            if let summary, !summary.isEmpty {
                object["summary"] = .string(summary)
            }
            if let categoryPath, !categoryPath.isEmpty {
                object["categoryPath"] = .list(categoryPath.map { .string($0) })
            }
            if let tags, !tags.isEmpty {
                object["tags"] = .list(tags.map { .string($0) })
            }
            if let purposeRefs, !purposeRefs.isEmpty {
                object["purposeRefs"] = .list(purposeRefs.map { .string($0) })
            }
            if let interestRefs, !interestRefs.isEmpty {
                object["interestRefs"] = .list(interestRefs.map { .string($0) })
            }
            if let supportedInsertionModes, !supportedInsertionModes.isEmpty {
                object["supportedInsertionModes"] = .list(supportedInsertionModes.map { .string($0.rawValue) })
            }
            if let supportedTargetKinds, !supportedTargetKinds.isEmpty {
                object["supportedTargetKinds"] = .list(supportedTargetKinds.map { .string($0) })
            }
            var ioSignature: Object = [:]
            if let ioGetKeys, !ioGetKeys.isEmpty {
                ioSignature["getKeys"] = .list(ioGetKeys.map { .string($0) })
            }
            if let ioSetKeys, !ioSetKeys.isEmpty {
                ioSignature["setKeys"] = .list(ioSetKeys.map { .string($0) })
            }
            if let ioTopics, !ioTopics.isEmpty {
                ioSignature["topics"] = .list(ioTopics.map { .string($0) })
            }
            if let ioFilterTypes, !ioFilterTypes.isEmpty {
                ioSignature["filterTypes"] = .list(ioFilterTypes.map { .string($0) })
            }
            if !ioSignature.isEmpty {
                object["ioSignature"] = .object(ioSignature)
            }
            if let authRequired {
                object["authRequired"] = .bool(authRequired)
            }
            if let policyHints, !policyHints.isEmpty {
                object["policyHints"] = .list(policyHints.map { .string($0) })
            }
            if let flowDriven {
                object["flowDriven"] = .bool(flowDriven)
            }
            if let editable {
                object["editable"] = .bool(editable)
            }
            if let recommendedContexts, !recommendedContexts.isEmpty {
                object["recommendedContexts"] = .list(recommendedContexts.map { .string($0) })
            }
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
        var displayName: String? = nil
        var summary: String? = nil
        var categoryPath: [String]? = nil
        var tags: [String]? = nil
        var purposeRefs: [String]? = nil
        var interestRefs: [String]? = nil
        var supportedInsertionModes: [SupportedInsertionMode]? = nil
        var supportedTargetKinds: [String]? = nil
        var ioGetKeys: [String]? = nil
        var ioSetKeys: [String]? = nil
        var ioTopics: [String]? = nil
        var ioFilterTypes: [String]? = nil
        var authRequired: Bool? = nil
        var policyHints: [String]? = nil
        var flowDriven: Bool? = nil
        var editable: Bool? = nil
        var recommendedContexts: [String]? = nil
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
        var forceRefreshExisting: Bool = false
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

    private struct MatchingSuggestion: Codable {
        var id: String
        var sourceEntryID: String
        var prompt: String
        var purpose: String
        var interests: [String]
        var overlappingInterests: [String]
        var menuSlots: [MenuSlot]
        var configuration: CellConfiguration
        var matchScore: Double
        var matchMeaning: String
        var hasSkeleton: Bool
        var matchedAt: Double

        func asObject() -> Object {
            let interestsSummary = interests.joined(separator: ", ")
            let overlapSummary = overlappingInterests.isEmpty
                ? "Ingen direkte interesseoverlapp."
                : "Interesseoverlapp: \(overlappingInterests.joined(separator: ", "))."
            let slotSummary = menuSlots.isEmpty ? "Ingen anbefalt meny-slot." : menuSlots.map(\.rawValue).joined(separator: ", ")
            let scoreLabel = String(format: "%.2f", matchScore)
            let skeletonStatus = hasSkeleton ? "Har skeleton - klar for preview/load i Porthole." : "Ingen skeleton i konfigurasjonen."
            var object: Object = [
                "id": .string(id),
                "sourceEntryId": .string(sourceEntryID),
                "prompt": .string(prompt),
                "purpose": .string(purpose),
                "interests": .list(interests.map { .string($0) }),
                "interestsSummary": .string(interestsSummary),
                "overlappingInterests": .list(overlappingInterests.map { .string($0) }),
                "overlapSummary": .string(overlapSummary),
                "menuSlots": .list(menuSlots.map { .string($0.rawValue) }),
                "menuSlotsSummary": .string(slotSummary),
                "configuration": .cellConfiguration(configuration),
                "name": .string(configuration.name),
                "matchScore": .float(matchScore),
                "matchScoreLabel": .string(scoreLabel),
                "matchMeaning": .string(matchMeaning),
                "hasSkeleton": .bool(hasSkeleton),
                "skeletonStatus": .string(skeletonStatus),
                "scoreAndSkeleton": .string("Score \(scoreLabel) | \(hasSkeleton ? "skeleton klar" : "ingen skeleton")"),
                "matchedAt": .float(matchedAt)
            ]
            if let description = configuration.description, !description.isEmpty {
                object["description"] = .string(description)
            }
            if let firstReference = configuration.cellReferences?.first {
                object["primaryEndpoint"] = .string(firstReference.endpoint)
            }
            if let skeleton = configuration.skeleton,
               let skeletonData = try? JSONEncoder().encode(skeleton),
               let skeletonString = String(data: skeletonData, encoding: .utf8) {
                let preview = String(skeletonString.prefix(240))
                object["skeletonPreview"] = .string(preview)
            }
            return object
        }
    }

    private struct PurposeUsageStat: Codable {
        var purpose: String
        var useCount: Int
        var achievedCount: Int
        var effectiveness: Double
        var currentWeight: Double
        var lastUsedAt: Double

        func asObject() -> Object {
            let effectivenessPercent = Int((effectiveness * 100.0).rounded())
            let usageSummary = "\(achievedCount) av \(useCount) oppnadd maal."
            return [
                "purpose": .string(purpose),
                "useCount": .integer(useCount),
                "achievedCount": .integer(achievedCount),
                "effectiveness": .float(effectiveness),
                "effectivenessPercent": .string("\(effectivenessPercent)%"),
                "currentWeight": .float(currentWeight),
                "weightLabel": .string(String(format: "%.2f", currentWeight)),
                "usageSummary": .string(usageSummary),
                "lastUsedAt": .float(lastUsedAt)
            ]
        }
    }

    private struct PublishedEntityPurpose: Codable {
        var id: String
        var entityName: String
        var entityType: String
        var entitySubtype: String?
        var purpose: String
        var sourceSuggestionID: String?
        var note: String?
        var publishedAt: Double

        func asObject() -> Object {
            let typeLabel: String = {
                if let entitySubtype, !entitySubtype.isEmpty {
                    return "\(entityType) (\(entitySubtype))"
                }
                return entityType
            }()
            let meaning = "\(entityName) publiserer formaal: \(purpose)."
            var object: Object = [
                "id": .string(id),
                "entityName": .string(entityName),
                "entityType": .string(entityType),
                "entityTypeLabel": .string(typeLabel),
                "purpose": .string(purpose),
                "meaning": .string(meaning),
                "publishedAt": .float(publishedAt)
            ]
            if let entitySubtype, !entitySubtype.isEmpty {
                object["entitySubtype"] = .string(entitySubtype)
            }
            if let sourceSuggestionID, !sourceSuggestionID.isEmpty {
                object["sourceSuggestionId"] = .string(sourceSuggestionID)
            }
            if let note, !note.isEmpty {
                object["note"] = .string(note)
            }
            return object
        }
    }

    private struct DetailedCatalogMatch {
        var entry: CatalogEntry
        var score: Double
        var overlapInterests: [String]
        var reasons: [String]
    }

    private enum QueryResourceBudget: String {
        case low
        case balanced
        case high
    }

    private enum QueryNetworkPolicy: String {
        case preferHealthyThenCached
        case healthyOnly
        case cacheOnly
    }

    private struct QueryConstraints {
        var maxResults: Int
        var maxSources: Int
        var latencyBudgetMs: Int
        var resourceBudget: QueryResourceBudget
        var networkPolicy: QueryNetworkPolicy
        var allowDegradedSources: Bool
    }

    private struct QueryContext {
        var editMode: Bool
        var selectedNodeKind: String?
        var insertionIntent: SupportedInsertionMode
    }

    private struct QueryFilters {
        var categoryPath: Set<String>
        var sourceRefs: Set<String>
        var authRequired: Set<Bool>
        var supportedInsertionModes: Set<SupportedInsertionMode>
        var flowDriven: Set<Bool>
        var editable: Set<Bool>
    }

    private enum SourceHealth: String {
        case online
        case degraded
        case offline
    }

    private struct SourceCandidate {
        var endpoint: String
        var health: SourceHealth
        var purposeFit: Double
        var interestFit: Double
        var sizePenalty: Double
        var score: Double
        var reason: String
        var estimatedRttMs: Int
    }

    private struct QueryScoreBreakdown {
        var text: Double
        var purpose: Double
        var interest: Double
        var compatibility: Double
        var connectivity: Double
        var resourceFit: Double
        var recency: Double

        var finalScore: Double {
            (0.32 * text) +
            (0.24 * purpose) +
            (0.16 * interest) +
            (0.10 * compatibility) +
            (0.08 * connectivity) +
            (0.06 * resourceFit) +
            (0.04 * recency)
        }
    }

    private enum AgreementRolloutMode: String, Codable {
        case newConnectionsOnly = "new_connections_only"
        case reEvaluateExisting = "re_evaluate_existing"
    }

    private enum AgreementNonCompliancePolicy: String, Codable, CaseIterable {
        case manualOnly = "manual_only"
        case autoEscalate = "auto_escalate"
        case autoRequestResign = "auto_request_resign"
        case autoRestrictUntilResolved = "auto_restrict_until_resolved"
    }

    private struct AgreementAccessDelegation: Codable {
        var identityKey: String
        var displayName: String
        var capabilities: [String]
        var grantedByIdentityKey: String
        var grantedAt: Double
        var expiresAt: Double?

        func asObject() -> Object {
            var object: Object = [
                "identityKey": .string(identityKey),
                "displayName": .string(displayName),
                "capabilities": .list(capabilities.map { .string($0) }),
                "grantedByIdentityKey": .string(grantedByIdentityKey),
                "grantedAt": .float(grantedAt)
            ]
            if let expiresAt {
                object["expiresAt"] = .float(expiresAt)
            }
            return object
        }
    }

    private struct AgreementSignature: Codable {
        var identityKey: String
        var signature: String
        var signedAt: Double
        var entityContext: String?

        func asObject() -> Object {
            var object: Object = [
                "identityKey": .string(identityKey),
                "signature": .string(signature),
                "signedAt": .float(signedAt)
            ]
            if let entityContext, !entityContext.isEmpty {
                object["entityContext"] = .string(entityContext)
            }
            return object
        }
    }

    private struct AgreementRecord: Codable {
        var agreementID: String
        var version: Int
        var templateHash: String
        var template: ValueType
        var rolloutMode: AgreementRolloutMode
        var forceSignContract: Bool
        var evictIfNonCompliant: Bool
        var requiresAllPartiesSignature: Bool
        var parties: [String]
        var signatures: [AgreementSignature]
        var createdByIdentityKey: String
        var createdAt: Double
        var status: String

        func asObject() -> Object {
            [
                "agreementId": .string(agreementID),
                "version": .integer(version),
                "templateHash": .string(templateHash),
                "template": template,
                "rolloutMode": .string(rolloutMode.rawValue),
                "forceSignContract": .bool(forceSignContract),
                "evictIfNonCompliant": .bool(evictIfNonCompliant),
                "requiresAllPartiesSignature": .bool(requiresAllPartiesSignature),
                "parties": .list(parties.map { .string($0) }),
                "signatures": .list(signatures.map { .object($0.asObject()) }),
                "createdByIdentityKey": .string(createdByIdentityKey),
                "createdAt": .float(createdAt),
                "status": .string(status)
            ]
        }
    }

    private struct AgreementPreviewSnapshot: Codable {
        var token: String
        var template: ValueType
        var rolloutMode: AgreementRolloutMode
        var forceSignContract: Bool
        var evictIfNonCompliant: Bool
        var requestedByIdentityKey: String
        var requestedAt: Double
        var affectedIdentityKeys: [String]

        func asObject() -> Object {
            [
                "previewToken": .string(token),
                "template": template,
                "rolloutMode": .string(rolloutMode.rawValue),
                "forceSignContract": .bool(forceSignContract),
                "evictIfNonCompliant": .bool(evictIfNonCompliant),
                "requestedByIdentityKey": .string(requestedByIdentityKey),
                "requestedAt": .float(requestedAt),
                "affectedExisting": .integer(affectedIdentityKeys.count),
                "affectedIdentityKeys": .list(affectedIdentityKeys.map { .string($0) })
            ]
        }
    }

    private struct AgreementNonComplianceReport: Codable {
        var id: String
        var agreementID: String?
        var reporterIdentityKey: String
        var reason: String
        var evidenceRef: String?
        var entityContext: String?
        var policy: AgreementNonCompliancePolicy
        var status: String
        var createdAt: Double

        func asObject() -> Object {
            var object: Object = [
                "id": .string(id),
                "reporterIdentityKey": .string(reporterIdentityKey),
                "reason": .string(reason),
                "policy": .string(policy.rawValue),
                "status": .string(status),
                "createdAt": .float(createdAt)
            ]
            if let agreementID, !agreementID.isEmpty {
                object["agreementId"] = .string(agreementID)
            }
            if let evidenceRef, !evidenceRef.isEmpty {
                object["evidenceRef"] = .string(evidenceRef)
            }
            if let entityContext, !entityContext.isEmpty {
                object["entityContext"] = .string(entityContext)
            }
            return object
        }
    }

    private struct AgreementAuditEntry: Codable {
        var id: String
        var action: String
        var actorIdentityKey: String
        var payload: ValueType
        var createdAt: Double

        func asObject() -> Object {
            [
                "id": .string(id),
                "action": .string(action),
                "actorIdentityKey": .string(actorIdentityKey),
                "payload": payload,
                "createdAt": .float(createdAt)
            ]
        }
    }

    enum CodingKeys: CodingKey {
        case generalCell
        case owner
        case entries
        case errors
        case agreementTemplateVersion
        case agreementTemplateDocument
        case agreementAccessDelegationsByIdentity
        case agreementCurrentRecord
        case agreementHistory
        case agreementPreviewsByToken
        case agreementNonComplianceReports
        case agreementNonCompliancePolicyByIdentity
        case agreementAuditLog
        case matchingPromptText
        case matchingSelectedIndex
        case matchingSuggestions
        case matchingBookmarks
        case matchingPurposeStatsByPurpose
        case matchingPublishedEntityPurposes
        case matchingPublishPersonName
        case matchingPublishGroupName
        case matchingPublishGroupType
        case matchingPublishNote
    }

    private let stateQueue = DispatchQueue(label: "Binding.ConfigurationCatalogCell.State")
    private var entriesByID: [String: CatalogEntry] = [:]
    private var catalogErrorsByEndpoint: [String: CatalogErrorEntry] = [:]
    private var syncInProgress: Bool = false
    private var agreementTemplateVersion: Int = 1
    private var agreementTemplateDocument: ValueType = ConfigurationCatalogCell.defaultAgreementTemplateDocument()
    private var agreementAccessDelegationsByIdentity: [String: AgreementAccessDelegation] = [:]
    private var agreementCurrentRecord: AgreementRecord?
    private var agreementHistory: [AgreementRecord] = []
    private var agreementPreviewsByToken: [String: AgreementPreviewSnapshot] = [:]
    private var agreementNonComplianceReports: [AgreementNonComplianceReport] = []
    private var agreementNonCompliancePolicyByIdentity: [String: AgreementNonCompliancePolicy] = [:]
    private var agreementAuditLog: [AgreementAuditEntry] = []
    private var matchingPromptText: String = ""
    private var matchingSelectedIndex: Int = -1
    private var matchingSuggestions: [MatchingSuggestion] = []
    private var matchingBookmarks: [MatchingSuggestion] = []
    private var matchingPurposeStatsByPurpose: [String: PurposeUsageStat] = [:]
    private var matchingPublishedEntityPurposes: [PublishedEntityPurpose] = []
    private var matchingPublishPersonName: String = ""
    private var matchingPublishGroupName: String = ""
    private var matchingPublishGroupType: String = "selskap"
    private var matchingPublishNote: String = ""
    private var lastQueryState: ValueType = .object([:])

    required init(owner: Identity) async {
        await super.init(owner: owner)
        migrateEntriesForMetadataIfNeeded()
        await setupPermissions(owner: owner)
        await setupKeys(owner: owner)
        await bootstrapDefaultsIfNeeded(requester: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try super.init(from: decoder)
        self.entriesByID = (try? container.decode([String: CatalogEntry].self, forKey: .entries)) ?? [:]
        self.catalogErrorsByEndpoint = (try? container.decode([String: CatalogErrorEntry].self, forKey: .errors)) ?? [:]
        self.agreementTemplateVersion = (try? container.decode(Int.self, forKey: .agreementTemplateVersion)) ?? 1
        self.agreementTemplateDocument = (try? container.decode(ValueType.self, forKey: .agreementTemplateDocument)) ?? ConfigurationCatalogCell.defaultAgreementTemplateDocument()
        self.agreementAccessDelegationsByIdentity = (try? container.decode([String: AgreementAccessDelegation].self, forKey: .agreementAccessDelegationsByIdentity)) ?? [:]
        self.agreementCurrentRecord = try? container.decode(AgreementRecord.self, forKey: .agreementCurrentRecord)
        self.agreementHistory = (try? container.decode([AgreementRecord].self, forKey: .agreementHistory)) ?? []
        self.agreementPreviewsByToken = (try? container.decode([String: AgreementPreviewSnapshot].self, forKey: .agreementPreviewsByToken)) ?? [:]
        self.agreementNonComplianceReports = (try? container.decode([AgreementNonComplianceReport].self, forKey: .agreementNonComplianceReports)) ?? []
        self.agreementNonCompliancePolicyByIdentity = (try? container.decode([String: AgreementNonCompliancePolicy].self, forKey: .agreementNonCompliancePolicyByIdentity)) ?? [:]
        self.agreementAuditLog = (try? container.decode([AgreementAuditEntry].self, forKey: .agreementAuditLog)) ?? []
        self.matchingPromptText = (try? container.decode(String.self, forKey: .matchingPromptText)) ?? ""
        self.matchingSelectedIndex = (try? container.decode(Int.self, forKey: .matchingSelectedIndex)) ?? -1
        self.matchingSuggestions = (try? container.decode([MatchingSuggestion].self, forKey: .matchingSuggestions)) ?? []
        self.matchingBookmarks = (try? container.decode([MatchingSuggestion].self, forKey: .matchingBookmarks)) ?? []
        self.matchingPurposeStatsByPurpose = (try? container.decode([String: PurposeUsageStat].self, forKey: .matchingPurposeStatsByPurpose)) ?? [:]
        self.matchingPublishedEntityPurposes = (try? container.decode([PublishedEntityPurpose].self, forKey: .matchingPublishedEntityPurposes)) ?? []
        self.matchingPublishPersonName = (try? container.decode(String.self, forKey: .matchingPublishPersonName)) ?? ""
        self.matchingPublishGroupName = (try? container.decode(String.self, forKey: .matchingPublishGroupName)) ?? ""
        self.matchingPublishGroupType = (try? container.decode(String.self, forKey: .matchingPublishGroupType)) ?? "selskap"
        self.matchingPublishNote = (try? container.decode(String.self, forKey: .matchingPublishNote)) ?? ""
        let decodedOwner = try container.decodeIfPresent(Identity.self, forKey: .owner)
        Task { @MainActor in
            self.migrateEntriesForMetadataIfNeeded()
            if let owner = decodedOwner {
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
        try container.encode(agreementTemplateVersion, forKey: .agreementTemplateVersion)
        try container.encode(agreementTemplateDocument, forKey: .agreementTemplateDocument)
        try container.encode(agreementAccessDelegationsByIdentity, forKey: .agreementAccessDelegationsByIdentity)
        try container.encodeIfPresent(agreementCurrentRecord, forKey: .agreementCurrentRecord)
        try container.encode(agreementHistory, forKey: .agreementHistory)
        try container.encode(agreementPreviewsByToken, forKey: .agreementPreviewsByToken)
        try container.encode(agreementNonComplianceReports, forKey: .agreementNonComplianceReports)
        try container.encode(agreementNonCompliancePolicyByIdentity, forKey: .agreementNonCompliancePolicyByIdentity)
        try container.encode(agreementAuditLog, forKey: .agreementAuditLog)
        try container.encode(matchingPromptText, forKey: .matchingPromptText)
        try container.encode(matchingSelectedIndex, forKey: .matchingSelectedIndex)
        try container.encode(matchingSuggestions, forKey: .matchingSuggestions)
        try container.encode(matchingBookmarks, forKey: .matchingBookmarks)
        try container.encode(matchingPurposeStatsByPurpose, forKey: .matchingPurposeStatsByPurpose)
        try container.encode(matchingPublishedEntityPurposes, forKey: .matchingPublishedEntityPurposes)
        try container.encode(matchingPublishPersonName, forKey: .matchingPublishPersonName)
        try container.encode(matchingPublishGroupName, forKey: .matchingPublishGroupName)
        try container.encode(matchingPublishGroupType, forKey: .matchingPublishGroupType)
        try container.encode(matchingPublishNote, forKey: .matchingPublishNote)
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
        agreementTemplate.addGrant("rw--", for: "query")
        agreementTemplate.addGrant("rw--", for: "facetCounts")
        agreementTemplate.addGrant("r---", for: "query.state")
        agreementTemplate.addGrant("r---", for: "matching.state")
        agreementTemplate.addGrant("r---", for: "matching.promptText")
        agreementTemplate.addGrant("rw--", for: "matching.promptText")
        agreementTemplate.addGrant("r---", for: "matching.suggestions")
        agreementTemplate.addGrant("r---", for: "matching.selectedSuggestion")
        agreementTemplate.addGrant("r---", for: "matching.selectedIndex")
        agreementTemplate.addGrant("rw--", for: "matching.selectedIndex")
        agreementTemplate.addGrant("r---", for: "matching.bookmarks")
        agreementTemplate.addGrant("r---", for: "matching.purposeStats")
        agreementTemplate.addGrant("r---", for: "matching.entityPurposePublications")
        agreementTemplate.addGrant("r---", for: "matching.publish.personName")
        agreementTemplate.addGrant("rw--", for: "matching.publish.personName")
        agreementTemplate.addGrant("r---", for: "matching.publish.groupName")
        agreementTemplate.addGrant("rw--", for: "matching.publish.groupName")
        agreementTemplate.addGrant("r---", for: "matching.publish.groupType")
        agreementTemplate.addGrant("rw--", for: "matching.publish.groupType")
        agreementTemplate.addGrant("r---", for: "matching.publish.note")
        agreementTemplate.addGrant("rw--", for: "matching.publish.note")
        agreementTemplate.addGrant("rw--", for: "matching.runPrompt")
        agreementTemplate.addGrant("rw--", for: "matching.select")
        agreementTemplate.addGrant("rw--", for: "matching.selectIndex")
        agreementTemplate.addGrant("rw--", for: "matching.loadSelectedToPorthole")
        agreementTemplate.addGrant("rw--", for: "matching.saveSelectedToMenu")
        agreementTemplate.addGrant("rw--", for: "matching.bookmarkSelected")
        agreementTemplate.addGrant("rw--", for: "matching.markSelectedUsed")
        agreementTemplate.addGrant("rw--", for: "matching.markSelectedGoalAchieved")
        agreementTemplate.addGrant("rw--", for: "matching.publishEntityPurpose")
        agreementTemplate.addGrant("rw--", for: "matching.clear")
        agreementTemplate.addGrant("r---", for: "syncScaffoldPurposeGoals")
        agreementTemplate.addGrant("rw--", for: "syncScaffoldPurposeGoals")
        agreementTemplate.addGrant("r---", for: "feed")
        agreementTemplate.addGrant("r---", for: "agreementTemplate.state")
        agreementTemplate.addGrant("rw--", for: "agreementTemplate.preview")
        agreementTemplate.addGrant("rw--", for: "agreementTemplate.apply")
        agreementTemplate.addGrant("rw--", for: "agreementTemplate.access.grant")
        agreementTemplate.addGrant("rw--", for: "agreementTemplate.access.revoke")
        agreementTemplate.addGrant("r---", for: "agreementTemplate.auditLog")
        agreementTemplate.addGrant("r---", for: "agreements.current")
        agreementTemplate.addGrant("r---", for: "agreements.history")
        agreementTemplate.addGrant("rw--", for: "agreements.sign")
        agreementTemplate.addGrant("rw--", for: "agreements.nonCompliant.report")
        agreementTemplate.addGrant("rw--", for: "agreements.nonCompliant.policy")
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

        await registerSet(key: "query", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "query", for: requester) else { return .string("denied") }
            return self.queryCatalog(payload: payload, requester: requester)
        }

        await registerSet(key: "facetCounts", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "facetCounts", for: requester) else { return .string("denied") }
            return self.queryFacetCounts(payload: payload, requester: requester)
        }

        await registerGet(key: "query.state", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "query.state", for: requester) else { return .string("denied") }
            return self.stateQueue.sync { self.lastQueryState }
        }

        await registerGet(key: "matching.state", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.state", for: requester) else { return .string("denied") }
            return self.matchingStateValue()
        }

        await registerGet(key: "matching.promptText", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.promptText", for: requester) else { return .string("denied") }
            return self.matchingPromptTextValue()
        }

        await registerSet(key: "matching.promptText", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.promptText", for: requester) else { return .string("denied") }
            return self.updateMatchingPromptText(payload)
        }

        await registerGet(key: "matching.publish.personName", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.publish.personName", for: requester) else { return .string("denied") }
            return self.matchingPublishPersonNameValue()
        }

        await registerSet(key: "matching.publish.personName", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.publish.personName", for: requester) else { return .string("denied") }
            return self.updateMatchingPublishField(payload, field: .personName)
        }

        await registerGet(key: "matching.publish.groupName", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.publish.groupName", for: requester) else { return .string("denied") }
            return self.matchingPublishGroupNameValue()
        }

        await registerSet(key: "matching.publish.groupName", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.publish.groupName", for: requester) else { return .string("denied") }
            return self.updateMatchingPublishField(payload, field: .groupName)
        }

        await registerGet(key: "matching.publish.groupType", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.publish.groupType", for: requester) else { return .string("denied") }
            return self.matchingPublishGroupTypeValue()
        }

        await registerSet(key: "matching.publish.groupType", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.publish.groupType", for: requester) else { return .string("denied") }
            return self.updateMatchingPublishField(payload, field: .groupType)
        }

        await registerGet(key: "matching.publish.note", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.publish.note", for: requester) else { return .string("denied") }
            return self.matchingPublishNoteValue()
        }

        await registerSet(key: "matching.publish.note", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.publish.note", for: requester) else { return .string("denied") }
            return self.updateMatchingPublishField(payload, field: .note)
        }

        await registerGet(key: "matching.suggestions", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.suggestions", for: requester) else { return .string("denied") }
            return self.matchingSuggestionsValue()
        }

        await registerGet(key: "matching.selectedSuggestion", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.selectedSuggestion", for: requester) else { return .string("denied") }
            return self.matchingSelectedSuggestionValue()
        }

        await registerGet(key: "matching.selectedIndex", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.selectedIndex", for: requester) else { return .string("denied") }
            return self.matchingSelectedIndexValue()
        }

        await registerSet(key: "matching.selectedIndex", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.selectedIndex", for: requester) else { return .string("denied") }
            return self.selectMatchingSuggestionByIndexPayload(payload)
        }

        await registerGet(key: "matching.bookmarks", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.bookmarks", for: requester) else { return .string("denied") }
            return self.matchingBookmarksValue()
        }

        await registerGet(key: "matching.purposeStats", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.purposeStats", for: requester) else { return .string("denied") }
            return self.matchingPurposeStatsValue()
        }

        await registerGet(key: "matching.entityPurposePublications", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "matching.entityPurposePublications", for: requester) else { return .string("denied") }
            return self.matchingEntityPurposePublicationsValue()
        }

        await registerSet(key: "matching.runPrompt", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.runPrompt", for: requester) else { return .string("denied") }
            return self.runMatchingPrompt(payload)
        }

        await registerSet(key: "matching.select", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.select", for: requester) else { return .string("denied") }
            return self.selectMatchingSuggestion(payload)
        }

        await registerSet(key: "matching.selectIndex", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.selectIndex", for: requester) else { return .string("denied") }
            return self.selectMatchingSuggestionByIndexPayload(payload)
        }

        await registerSet(key: "matching.loadSelectedToPorthole", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.loadSelectedToPorthole", for: requester) else { return .string("denied") }
            return await self.loadSelectedMatchingSuggestionToPorthole(requester: requester)
        }

        await registerSet(key: "matching.saveSelectedToMenu", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.saveSelectedToMenu", for: requester) else { return .string("denied") }
            return await self.saveSelectedMatchingSuggestionToMenu(payload: payload, requester: requester)
        }

        await registerSet(key: "matching.bookmarkSelected", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.bookmarkSelected", for: requester) else { return .string("denied") }
            return self.bookmarkSelectedMatchingSuggestion()
        }

        await registerSet(key: "matching.markSelectedUsed", owner: owner) { [weak self] requester, _ in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.markSelectedUsed", for: requester) else { return .string("denied") }
            return await self.markSelectedSuggestionUsage(achievedGoal: false, requester: requester)
        }

        await registerSet(key: "matching.markSelectedGoalAchieved", owner: owner) { [weak self] requester, _ in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.markSelectedGoalAchieved", for: requester) else { return .string("denied") }
            return await self.markSelectedSuggestionUsage(achievedGoal: true, requester: requester)
        }

        await registerSet(key: "matching.publishEntityPurpose", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.publishEntityPurpose", for: requester) else { return .string("denied") }
            return await self.publishEntityPurpose(payload: payload, requester: requester)
        }

        await registerSet(key: "matching.clear", owner: owner) { [weak self] requester, _ in
            guard let self = self else { return .null }
            guard await self.validateAccess("rw--", at: "matching.clear", for: requester) else { return .string("denied") }
            return self.clearMatchingSuggestions()
        }

        await registerGet(key: "syncScaffoldPurposeGoals", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.validateAccess("r---", at: "syncScaffoldPurposeGoals", for: requester) else { return .string("denied") }
            return .object([
                "status": .string("ready"),
                "state": self.stateValue()
            ])
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

        await registerGet(key: "agreementTemplate.state", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.hasAgreementCapability("agreementTemplate.read", requester: requester) else {
                return .string("denied")
            }
            return await self.agreementTemplateStateValue(requester: requester)
        }

        await registerSet(key: "agreementTemplate.preview", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            return await self.handleAgreementTemplatePreview(payload: payload, requester: requester)
        }

        await registerSet(key: "agreementTemplate.apply", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            return await self.handleAgreementTemplateApply(payload: payload, requester: requester)
        }

        await registerSet(key: "agreementTemplate.access.grant", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            return await self.handleAgreementAccessGrant(payload: payload, requester: requester)
        }

        await registerSet(key: "agreementTemplate.access.revoke", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            return await self.handleAgreementAccessRevoke(payload: payload, requester: requester)
        }

        await registerGet(key: "agreementTemplate.auditLog", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.hasAgreementCapability("agreementTemplate.read", requester: requester) else {
                return .string("denied")
            }
            let items = self.stateQueue.sync { self.agreementAuditLog.map { ValueType.object($0.asObject()) } }
            return .list(items)
        }

        await registerGet(key: "agreements.current", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.hasAgreementCapability("agreementTemplate.read", requester: requester) else {
                return .string("denied")
            }
            return self.stateQueue.sync {
                guard let current = self.agreementCurrentRecord else { return .null }
                return .object(current.asObject())
            }
        }

        await registerGet(key: "agreements.history", owner: owner) { [weak self] requester in
            guard let self = self else { return .null }
            guard await self.hasAgreementCapability("agreementTemplate.read", requester: requester) else {
                return .string("denied")
            }
            let history = self.stateQueue.sync { self.agreementHistory.map { ValueType.object($0.asObject()) } }
            return .list(history)
        }

        await registerSet(key: "agreements.sign", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            return await self.handleAgreementSign(payload: payload, requester: requester)
        }

        await registerSet(key: "agreements.nonCompliant.report", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            return await self.handleNonCompliantReport(payload: payload, requester: requester)
        }

        await registerSet(key: "agreements.nonCompliant.policy", owner: owner) { [weak self] requester, payload in
            guard let self = self else { return .null }
            return await self.handleNonCompliantPolicy(payload: payload, requester: requester)
        }
    }

    private func stateValue() -> ValueType {
        let entries = sortedEntries()
        var object: Object = [:]
        object["count"] = .integer(entries.count)
        object["purposes"] = .list(Array(Set(entries.map { $0.purpose })).sorted().map { .string($0) })
        let (errorCount, syncActive, agreementVersion, delegationCount, nonCompliantOpenCount, currentAgreementID) = stateQueue.sync {
            let openCount = agreementNonComplianceReports.filter { $0.status != "resolved" }.count
            return (
                catalogErrorsByEndpoint.count,
                syncInProgress,
                agreementTemplateVersion,
                agreementAccessDelegationsByIdentity.count,
                openCount,
                agreementCurrentRecord?.agreementID
            )
        }
        object["errorCount"] = .integer(errorCount)
        object["syncInProgress"] = .bool(syncActive)
        object["agreementTemplateVersion"] = .integer(agreementVersion)
        object["agreementDelegationCount"] = .integer(delegationCount)
        object["agreementNonCompliantOpenCount"] = .integer(nonCompliantOpenCount)
        let matchingSnapshot = stateQueue.sync { (matchingSuggestions.count, matchingBookmarks.count) }
        object["matchingSuggestionCount"] = .integer(matchingSnapshot.0)
        object["matchingBookmarkCount"] = .integer(matchingSnapshot.1)
        if let currentAgreementID {
            object["currentAgreementId"] = .string(currentAgreementID)
        }
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

    private static var supportedAgreementCapabilities: [String] {
        [
            "agreementTemplate.read",
            "agreementTemplate.write",
            "agreementTemplate.apply.newConnections",
            "agreementTemplate.apply.reEvaluateExisting",
            "agreementTemplate.contracts.enforce",
            "agreementTemplate.access.manage"
        ]
    }

    private static func defaultAgreementTemplateDocument() -> ValueType {
        .object([
            "description": .string("Capability-based agreement template."),
            "requiresAllPartiesSignature": .bool(true),
            "capabilities": .list(supportedAgreementCapabilities.map { .string($0) })
        ])
    }

    private func identityKey(for identity: Identity) -> String {
        if let data = try? JSONEncoder().encode(identity) {
            return data.base64EncodedString()
        }
        return String(describing: identity)
    }

    private func identityLabel(for identityKey: String) -> String {
        if identityKey.count <= 14 {
            return identityKey
        }
        return "\(identityKey.prefix(8))...\(identityKey.suffix(4))"
    }

    private func isOwnerIdentity(_ requester: Identity) async -> Bool {
        guard let owner = try? await getOwner(requester: requester) else { return false }
        return identityKey(for: owner) == identityKey(for: requester)
    }

    private func capabilitiesForIdentity(_ identityKey: String) -> Set<String> {
        stateQueue.sync {
            guard let delegation = agreementAccessDelegationsByIdentity[identityKey] else { return [] }
            if let expiresAt = delegation.expiresAt, expiresAt <= Date().timeIntervalSince1970 {
                agreementAccessDelegationsByIdentity.removeValue(forKey: identityKey)
                return []
            }
            return Set(delegation.capabilities)
        }
    }

    private func hasAgreementCapability(_ capability: String, requester: Identity) async -> Bool {
        if await isOwnerIdentity(requester) {
            return true
        }
        let requesterKey = identityKey(for: requester)
        let granted = capabilitiesForIdentity(requesterKey)
        if granted.contains(capability) {
            return true
        }

        if capability == "agreementTemplate.read", granted.contains("agreementTemplate.write") {
            return true
        }
        return false
    }

    private func extractString(_ value: ValueType?) -> String? {
        guard let value else { return nil }
        if case let .string(result) = value, !result.isEmpty {
            return result
        }
        return nil
    }

    private func extractBool(_ value: ValueType?, default defaultValue: Bool) -> Bool {
        guard let value else { return defaultValue }
        if case let .bool(flag) = value {
            return flag
        }
        return defaultValue
    }

    private func extractInt(_ value: ValueType?, default defaultValue: Int) -> Int {
        guard let value else { return defaultValue }
        switch value {
        case .integer(let number):
            return number
        case .number(let number):
            return number
        case .float(let number):
            return Int(number)
        default:
            return defaultValue
        }
    }

    private func extractDouble(_ value: ValueType?, default defaultValue: Double) -> Double {
        guard let value else { return defaultValue }
        switch value {
        case .float(let number):
            return number
        case .integer(let number):
            return Double(number)
        case .number(let number):
            return Double(number)
        default:
            return defaultValue
        }
    }

    private func extractCapabilityList(_ value: ValueType?) -> [String] {
        guard let value else { return [] }
        switch value {
        case .string(let capability):
            return capability.isEmpty ? [] : [capability]
        case .list(let values):
            return values.compactMap {
                if case let .string(capability) = $0, !capability.isEmpty {
                    return capability
                }
                return nil
            }
        default:
            return []
        }
    }

    private func rolloutMode(from object: Object) -> AgreementRolloutMode {
        if case let .string(mode)? = object["rolloutMode"] {
            return AgreementRolloutMode(rawValue: mode) ?? .newConnectionsOnly
        }
        return .newConnectionsOnly
    }

    private func identityKeyFromObject(_ object: Object) -> String? {
        if let direct = extractString(object["identityKey"]) {
            return direct
        }
        if let direct = extractString(object["targetIdentityKey"]) {
            return direct
        }
        if let direct = extractString(object["identity"]) {
            return direct
        }
        if case let .identity(identity)? = object["identity"] {
            return identityKey(for: identity)
        }
        return nil
    }

    private func activeAgreementIdentityKeys() -> [String] {
        stateQueue.sync {
            var keys = Set<String>()
            keys.formUnion(agreementAccessDelegationsByIdentity.keys)
            if let current = agreementCurrentRecord {
                keys.formUnion(current.parties)
                keys.formUnion(current.signatures.map(\.identityKey))
            }
            return keys.sorted()
        }
    }

    private func normalizeTemplateValue(_ payloadTemplate: ValueType?) -> ValueType {
        guard let payloadTemplate else {
            return stateQueue.sync { agreementTemplateDocument }
        }
        return payloadTemplate
    }

    private func agreementTemplateStateValue(requester: Identity) async -> ValueType {
        let requesterKey = identityKey(for: requester)
        let ownerKey: String
        if let owner = try? await getOwner(requester: requester) {
            ownerKey = identityKey(for: owner)
        } else {
            ownerKey = ""
        }

        return stateQueue.sync {
            let grants = agreementAccessDelegationsByIdentity.values
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                .map { ValueType.object($0.asObject()) }

            let reports = agreementNonComplianceReports.map { ValueType.object($0.asObject()) }
            let openReports = agreementNonComplianceReports.filter { $0.status != "resolved" }.count

            var object: Object = [
                "ownerIdentityKey": .string(ownerKey),
                "requesterIdentityKey": .string(requesterKey),
                "agreementTemplateVersion": .integer(agreementTemplateVersion),
                "template": agreementTemplateDocument,
                "capabilities": .list(Self.supportedAgreementCapabilities.map { .string($0) }),
                "accessDelegations": .list(grants),
                "activePreviewCount": .integer(agreementPreviewsByToken.count),
                "nonCompliantOpenCount": .integer(openReports),
                "nonCompliantReports": .list(reports)
            ]
            if let current = agreementCurrentRecord {
                object["currentAgreement"] = .object(current.asObject())
            }
            return .object(object)
        }
    }

    private func handleAgreementTemplatePreview(payload: ValueType, requester: Identity) async -> ValueType {
        guard await hasAgreementCapability("agreementTemplate.write", requester: requester) else {
            return .string("denied")
        }
        guard case let .object(object) = payload else {
            return .string("error: invalid payload for agreementTemplate.preview")
        }

        let mode = rolloutMode(from: object)
        let template = normalizeTemplateValue(object["template"])
        let requesterKey = identityKey(for: requester)
        let forceSignContract = extractBool(object["forceSignContract"], default: mode == .reEvaluateExisting)
        let evictIfNonCompliant = extractBool(object["evictIfNonCompliant"], default: false)
        let affected = activeAgreementIdentityKeys()
        let token = UUID().uuidString
        let now = Date().timeIntervalSince1970

        let snapshot = AgreementPreviewSnapshot(
            token: token,
            template: template,
            rolloutMode: mode,
            forceSignContract: forceSignContract,
            evictIfNonCompliant: evictIfNonCompliant,
            requestedByIdentityKey: requesterKey,
            requestedAt: now,
            affectedIdentityKeys: affected
        )

        stateQueue.sync {
            agreementPreviewsByToken[token] = snapshot
            if agreementPreviewsByToken.count > 64 {
                let keysToDrop = agreementPreviewsByToken.values
                    .sorted { $0.requestedAt < $1.requestedAt }
                    .prefix(agreementPreviewsByToken.count - 64)
                    .map(\.token)
                keysToDrop.forEach { agreementPreviewsByToken.removeValue(forKey: $0) }
            }
            agreementAuditLog.append(
                AgreementAuditEntry(
                    id: UUID().uuidString,
                    action: "agreementTemplate.preview",
                    actorIdentityKey: requesterKey,
                    payload: .object(snapshot.asObject()),
                    createdAt: now
                )
            )
        }

        var response = snapshot.asObject()
        response["requiresSignContract"] = .bool(forceSignContract && mode == .reEvaluateExisting)
        response["wouldBeRevoked"] = evictIfNonCompliant ? .list(affected.map { .string($0) }) : .list([])
        response["state"] = await agreementTemplateStateValue(requester: requester)

        await emitAgreementEvent(
            action: "agreement.preview",
            payload: [
                "previewToken": .string(token),
                "rolloutMode": .string(mode.rawValue),
                "affectedExisting": .integer(affected.count)
            ],
            requester: requester
        )
        return .object(response)
    }

    private func handleAgreementTemplateApply(payload: ValueType, requester: Identity) async -> ValueType {
        guard case let .object(object) = payload else {
            return .string("error: invalid payload for agreementTemplate.apply")
        }

        let requesterKey = identityKey(for: requester)
        let ownerKey: String
        if let owner = try? await getOwner(requester: requester) {
            ownerKey = identityKey(for: owner)
        } else {
            ownerKey = requesterKey
        }

        let requestedPreviewToken = extractString(object["previewToken"])
        let mode: AgreementRolloutMode
        let template: ValueType
        let forceSignContract: Bool
        let evictIfNonCompliant: Bool
        let affectedIdentityKeys: [String]

        if let requestedPreviewToken,
           let cachedPreview = stateQueue.sync(execute: { agreementPreviewsByToken[requestedPreviewToken] }) {
            mode = cachedPreview.rolloutMode
            template = cachedPreview.template
            forceSignContract = cachedPreview.forceSignContract
            evictIfNonCompliant = cachedPreview.evictIfNonCompliant
            affectedIdentityKeys = cachedPreview.affectedIdentityKeys
        } else {
            mode = rolloutMode(from: object)
            template = normalizeTemplateValue(object["template"])
            forceSignContract = extractBool(object["forceSignContract"], default: mode == .reEvaluateExisting)
            evictIfNonCompliant = extractBool(object["evictIfNonCompliant"], default: false)
            affectedIdentityKeys = activeAgreementIdentityKeys()
        }

        let requiredCapability: String = (mode == .reEvaluateExisting)
            ? "agreementTemplate.apply.reEvaluateExisting"
            : "agreementTemplate.apply.newConnections"
        guard await hasAgreementCapability(requiredCapability, requester: requester) else {
            return .string("denied")
        }

        let requiresAllPartiesSignature = extractBool(object["requiresAllPartiesSignature"], default: true)
        var parties = extractCapabilityList(object["parties"])
        if parties.isEmpty {
            parties = Array(Set(affectedIdentityKeys + [ownerKey, requesterKey])).sorted()
        }

        let now = Date().timeIntervalSince1970
        let templateHash = {
            if let data = try? JSONEncoder().encode(template) {
                return data.base64EncodedString()
            }
            return UUID().uuidString
        }()

        let currentVersion = stateQueue.sync { agreementTemplateVersion }
        let agreement = AgreementRecord(
            agreementID: UUID().uuidString,
            version: currentVersion + 1,
            templateHash: templateHash,
            template: template,
            rolloutMode: mode,
            forceSignContract: forceSignContract,
            evictIfNonCompliant: evictIfNonCompliant,
            requiresAllPartiesSignature: requiresAllPartiesSignature,
            parties: parties,
            signatures: [],
            createdByIdentityKey: requesterKey,
            createdAt: now,
            status: requiresAllPartiesSignature ? "pending_signatures" : "active"
        )

        var generatedReports: [AgreementNonComplianceReport] = []
        stateQueue.sync {
            agreementTemplateVersion = agreement.version
            agreementTemplateDocument = template
            agreementCurrentRecord = agreement
            agreementHistory.append(agreement)
            if let requestedPreviewToken {
                agreementPreviewsByToken.removeValue(forKey: requestedPreviewToken)
            }
            if mode == .reEvaluateExisting && forceSignContract {
                for identityKey in affectedIdentityKeys where identityKey != requesterKey {
                    let policy = agreementNonCompliancePolicyByIdentity[identityKey] ?? .manualOnly
                    let report = AgreementNonComplianceReport(
                        id: UUID().uuidString,
                        agreementID: agreement.agreementID,
                        reporterIdentityKey: identityKey,
                        reason: "Agreement template updated; renewed signContract required.",
                        evidenceRef: "agreement://\(agreement.agreementID)",
                        entityContext: nil,
                        policy: policy,
                        status: policy == .autoRestrictUntilResolved || evictIfNonCompliant ? "restricted" : "open",
                        createdAt: now
                    )
                    agreementNonComplianceReports.append(report)
                    generatedReports.append(report)
                }
            }
            agreementAuditLog.append(
                AgreementAuditEntry(
                    id: UUID().uuidString,
                    action: "agreementTemplate.apply",
                    actorIdentityKey: requesterKey,
                    payload: .object([
                        "agreementId": .string(agreement.agreementID),
                        "rolloutMode": .string(mode.rawValue),
                        "affectedExisting": .integer(affectedIdentityKeys.count),
                        "generatedNonCompliantReports": .integer(generatedReports.count)
                    ]),
                    createdAt: now
                )
            )
        }

        await emitAgreementEvent(
            action: "agreement.applied",
            payload: [
                "agreementId": .string(agreement.agreementID),
                "version": .integer(agreement.version),
                "rolloutMode": .string(mode.rawValue),
                "generatedNonCompliantReports": .integer(generatedReports.count)
            ],
            requester: requester
        )

        var response: Object = [
            "agreement": .object(agreement.asObject()),
            "generatedNonCompliantReports": .list(generatedReports.map { .object($0.asObject()) }),
            "state": await agreementTemplateStateValue(requester: requester)
        ]
        return .object(response)
    }

    private func handleAgreementAccessGrant(payload: ValueType, requester: Identity) async -> ValueType {
        guard await hasAgreementCapability("agreementTemplate.access.manage", requester: requester) else {
            return .string("denied")
        }
        guard case let .object(object) = payload else {
            return .string("error: invalid payload for agreementTemplate.access.grant")
        }
        guard let targetIdentityKey = identityKeyFromObject(object), !targetIdentityKey.isEmpty else {
            return .string("error: missing identityKey")
        }

        let capabilities = extractCapabilityList(object["capabilities"])
        guard !capabilities.isEmpty else {
            return .string("error: no capabilities provided")
        }
        let unsupported = capabilities.filter { !Self.supportedAgreementCapabilities.contains($0) }
        guard unsupported.isEmpty else {
            return .string("error: unsupported capabilities \(unsupported.joined(separator: ", "))")
        }

        let requesterKey = identityKey(for: requester)
        let isOwner = await isOwnerIdentity(requester)
        if !isOwner {
            let requesterCapabilities = capabilitiesForIdentity(requesterKey)
            let illegalDelegation = capabilities.first { !requesterCapabilities.contains($0) }
            if let illegalDelegation {
                return .string("denied: cannot delegate capability '\(illegalDelegation)'")
            }
        }

        let expiresAt: Double? = {
            if case let .float(value)? = object["expiresAt"] { return value }
            if case let .integer(value)? = object["expiresAt"] { return Double(value) }
            if case let .number(value)? = object["expiresAt"] { return Double(value) }
            return nil
        }()

        let displayName = extractString(object["displayName"]) ?? identityLabel(for: targetIdentityKey)
        let now = Date().timeIntervalSince1970
        let delegation = AgreementAccessDelegation(
            identityKey: targetIdentityKey,
            displayName: displayName,
            capabilities: Array(Set(capabilities)).sorted(),
            grantedByIdentityKey: requesterKey,
            grantedAt: now,
            expiresAt: expiresAt
        )

        stateQueue.sync {
            agreementAccessDelegationsByIdentity[targetIdentityKey] = delegation
            agreementAuditLog.append(
                AgreementAuditEntry(
                    id: UUID().uuidString,
                    action: "agreementTemplate.access.grant",
                    actorIdentityKey: requesterKey,
                    payload: .object(delegation.asObject()),
                    createdAt: now
                )
            )
        }

        await emitAgreementEvent(
            action: "agreement.access.grant",
            payload: [
                "identityKey": .string(targetIdentityKey),
                "capabilities": .list(delegation.capabilities.map { .string($0) })
            ],
            requester: requester
        )

        return .object([
            "delegation": .object(delegation.asObject()),
            "state": await agreementTemplateStateValue(requester: requester)
        ])
    }

    private func handleAgreementAccessRevoke(payload: ValueType, requester: Identity) async -> ValueType {
        guard await hasAgreementCapability("agreementTemplate.access.manage", requester: requester) else {
            return .string("denied")
        }
        guard case let .object(object) = payload else {
            return .string("error: invalid payload for agreementTemplate.access.revoke")
        }
        guard let targetIdentityKey = identityKeyFromObject(object), !targetIdentityKey.isEmpty else {
            return .string("error: missing identityKey")
        }

        let capabilitiesToRevoke = Set(extractCapabilityList(object["capabilities"]))
        let requesterKey = identityKey(for: requester)
        let now = Date().timeIntervalSince1970

        let revokedObject: Object? = stateQueue.sync {
            guard var delegation = agreementAccessDelegationsByIdentity[targetIdentityKey] else { return nil }
            if capabilitiesToRevoke.isEmpty {
                agreementAccessDelegationsByIdentity.removeValue(forKey: targetIdentityKey)
            } else {
                delegation.capabilities.removeAll { capabilitiesToRevoke.contains($0) }
                if delegation.capabilities.isEmpty {
                    agreementAccessDelegationsByIdentity.removeValue(forKey: targetIdentityKey)
                } else {
                    agreementAccessDelegationsByIdentity[targetIdentityKey] = delegation
                }
            }
            let payload: Object = [
                "identityKey": .string(targetIdentityKey),
                "revokedCapabilities": .list(Array(capabilitiesToRevoke).sorted().map { .string($0) })
            ]
            agreementAuditLog.append(
                AgreementAuditEntry(
                    id: UUID().uuidString,
                    action: "agreementTemplate.access.revoke",
                    actorIdentityKey: requesterKey,
                    payload: .object(payload),
                    createdAt: now
                )
            )
            return payload
        }

        guard let revokedObject else {
            return .string("error: delegation not found")
        }

        await emitAgreementEvent(action: "agreement.access.revoke", payload: revokedObject, requester: requester)
        return .object([
            "revoked": .object(revokedObject),
            "state": await agreementTemplateStateValue(requester: requester)
        ])
    }

    private func handleAgreementSign(payload: ValueType, requester: Identity) async -> ValueType {
        let requesterKey = identityKey(for: requester)
        let currentAgreement = stateQueue.sync { agreementCurrentRecord }
        guard let currentAgreement else {
            return .string("error: no active agreement")
        }

        let agreementID: String
        let signature: String
        let entityContext: String?
        if case let .object(object) = payload {
            agreementID = extractString(object["agreementId"]) ?? currentAgreement.agreementID
            signature = extractString(object["signature"]) ?? "signed"
            entityContext = extractString(object["entityContext"])
        } else {
            agreementID = currentAgreement.agreementID
            signature = "signed"
            entityContext = nil
        }

        guard agreementID == currentAgreement.agreementID else {
            return .string("error: only current agreement can be signed in this endpoint")
        }
        let isParty = currentAgreement.parties.contains(requesterKey)
        let hasReadCapability = await hasAgreementCapability("agreementTemplate.read", requester: requester)
        guard isParty || hasReadCapability else {
            return .string("denied")
        }

        let now = Date().timeIntervalSince1970
        var updatedAgreement: AgreementRecord?
        stateQueue.sync {
            guard var agreement = agreementCurrentRecord, agreement.agreementID == agreementID else { return }
            if let existingIndex = agreement.signatures.firstIndex(where: { $0.identityKey == requesterKey }) {
                agreement.signatures[existingIndex] = AgreementSignature(identityKey: requesterKey, signature: signature, signedAt: now, entityContext: entityContext)
            } else {
                agreement.signatures.append(AgreementSignature(identityKey: requesterKey, signature: signature, signedAt: now, entityContext: entityContext))
            }
            let signedKeys = Set(agreement.signatures.map(\.identityKey))
            if agreement.requiresAllPartiesSignature {
                let partiesSigned = Set(agreement.parties).isSubset(of: signedKeys)
                agreement.status = partiesSigned ? "active" : "pending_signatures"
            } else {
                agreement.status = "active"
            }
            agreementCurrentRecord = agreement
            if let historyIndex = agreementHistory.firstIndex(where: { $0.agreementID == agreementID }) {
                agreementHistory[historyIndex] = agreement
            }
            agreementAuditLog.append(
                AgreementAuditEntry(
                    id: UUID().uuidString,
                    action: "agreements.sign",
                    actorIdentityKey: requesterKey,
                    payload: .object([
                        "agreementId": .string(agreementID),
                        "entityContext": entityContext.map { .string($0) } ?? .null
                    ]),
                    createdAt: now
                )
            )
            updatedAgreement = agreement
        }

        guard let updatedAgreement else {
            return .string("error: failed to update agreement")
        }
        await emitAgreementEvent(
            action: "agreement.signed",
            payload: [
                "agreementId": .string(updatedAgreement.agreementID),
                "identityKey": .string(requesterKey),
                "status": .string(updatedAgreement.status)
            ],
            requester: requester
        )
        return .object(updatedAgreement.asObject())
    }

    private func handleNonCompliantReport(payload: ValueType, requester: Identity) async -> ValueType {
        let requesterKey = identityKey(for: requester)
        guard case let .object(object) = payload else {
            return .string("error: invalid payload for agreements.nonCompliant.report")
        }
        let reason = extractString(object["reason"]) ?? "Marked as non-compliant"
        let agreementID = extractString(object["agreementId"]) ?? stateQueue.sync { agreementCurrentRecord?.agreementID }
        let evidenceRef = extractString(object["evidenceRef"])
        let entityContext = extractString(object["entityContext"])

        let hasReadAccess = await hasAgreementCapability("agreementTemplate.read", requester: requester)
        let isParty = stateQueue.sync { agreementCurrentRecord?.parties.contains(requesterKey) == true }
        guard hasReadAccess || isParty else {
            return .string("denied")
        }

        let now = Date().timeIntervalSince1970
        let policy = stateQueue.sync { agreementNonCompliancePolicyByIdentity[requesterKey] ?? .manualOnly }
        let report = AgreementNonComplianceReport(
            id: UUID().uuidString,
            agreementID: agreementID,
            reporterIdentityKey: requesterKey,
            reason: reason,
            evidenceRef: evidenceRef,
            entityContext: entityContext,
            policy: policy,
            status: policy == .autoRestrictUntilResolved ? "restricted" : "open",
            createdAt: now
        )

        stateQueue.sync {
            agreementNonComplianceReports.append(report)
            agreementAuditLog.append(
                AgreementAuditEntry(
                    id: UUID().uuidString,
                    action: "agreements.nonCompliant.report",
                    actorIdentityKey: requesterKey,
                    payload: .object(report.asObject()),
                    createdAt: now
                )
            )
        }

        await emitAgreementEvent(
            action: "agreement.nonCompliant.reported",
            payload: report.asObject(),
            requester: requester
        )
        return .object(report.asObject())
    }

    private func handleNonCompliantPolicy(payload: ValueType, requester: Identity) async -> ValueType {
        guard case let .object(object) = payload else {
            return .string("error: invalid payload for agreements.nonCompliant.policy")
        }

        let requesterKey = identityKey(for: requester)
        let targetIdentityKey = identityKeyFromObject(object) ?? requesterKey
        guard let policyRaw = extractString(object["policy"]),
              let policy = AgreementNonCompliancePolicy(rawValue: policyRaw) else {
            return .string("error: invalid policy")
        }

        if targetIdentityKey != requesterKey {
            guard await hasAgreementCapability("agreementTemplate.access.manage", requester: requester) else {
                return .string("denied")
            }
        }

        let now = Date().timeIntervalSince1970
        stateQueue.sync {
            agreementNonCompliancePolicyByIdentity[targetIdentityKey] = policy
            agreementAuditLog.append(
                AgreementAuditEntry(
                    id: UUID().uuidString,
                    action: "agreements.nonCompliant.policy",
                    actorIdentityKey: requesterKey,
                    payload: .object([
                        "identityKey": .string(targetIdentityKey),
                        "policy": .string(policy.rawValue)
                    ]),
                    createdAt: now
                )
            )
        }

        await emitAgreementEvent(
            action: "agreement.nonCompliant.policy",
            payload: [
                "identityKey": .string(targetIdentityKey),
                "policy": .string(policy.rawValue)
            ],
            requester: requester
        )
        return .object([
            "identityKey": .string(targetIdentityKey),
            "policy": .string(policy.rawValue),
            "state": await agreementTemplateStateValue(requester: requester)
        ])
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
        let displayName = extractString(object["displayName"])
        let summary = extractString(object["summary"])
        let categoryPath = extractStringList(from: object["categoryPath"])
        let tags = extractStringList(from: object["tags"])
        let purposeRefs = extractStringList(from: object["purposeRefs"])
        let interestRefs = extractStringList(from: object["interestRefs"])

        let compatibilityObject: Object = {
            if case let .object(object)? = object["compatibility"] {
                return object
            }
            return [:]
        }()
        let supportedInsertionModes = extractInsertionModes(
            from: object["supportedInsertionModes"] ?? compatibilityObject["supportedInsertionModes"]
        )
        let supportedTargetKinds = extractStringList(
            from: object["supportedTargetKinds"] ?? compatibilityObject["supportedTargetKinds"]
        )

        let ioSignature: Object = {
            if case let .object(object)? = object["ioSignature"] {
                return object
            }
            return [:]
        }()
        let ioGetKeys = extractStringList(from: ioSignature["getKeys"])
        let ioSetKeys = extractStringList(from: ioSignature["setKeys"])
        let ioTopics = extractStringList(from: ioSignature["topics"])
        let ioFilterTypes = extractStringList(from: ioSignature["filterTypes"])

        let authPolicyHints: Object = {
            if case let .object(object)? = object["authPolicyHints"] {
                return object
            }
            return [:]
        }()
        let authRequired = extractOptionalBool(object["authRequired"] ?? authPolicyHints["authRequired"])
        let policyHints = extractStringList(from: object["policyHints"] ?? authPolicyHints["policyHints"])
        let flowDriven = extractOptionalBool(object["flowDriven"])
        let editable = extractOptionalBool(object["editable"])
        let recommendedContexts = extractStringList(from: object["recommendedContexts"])

        return CatalogPayload(
            id: id,
            sourceCellEndpoint: sourceCellEndpoint,
            sourceCellName: sourceCellName,
            purpose: purpose,
            purposeDescription: purposeDescription,
            interests: interests,
            menuSlots: menuSlots,
            goal: goal,
            configuration: configuration,
            displayName: displayName,
            summary: summary,
            categoryPath: categoryPath,
            tags: tags,
            purposeRefs: purposeRefs,
            interestRefs: interestRefs,
            supportedInsertionModes: supportedInsertionModes,
            supportedTargetKinds: supportedTargetKinds,
            ioGetKeys: ioGetKeys,
            ioSetKeys: ioSetKeys,
            ioTopics: ioTopics,
            ioFilterTypes: ioFilterTypes,
            authRequired: authRequired,
            policyHints: policyHints,
            flowDriven: flowDriven,
            editable: editable,
            recommendedContexts: recommendedContexts
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

    private func extractStringList(from value: ValueType?) -> [String]? {
        guard let values = extractInterestList(from: value) else { return nil }
        let normalized = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return normalized.isEmpty ? nil : Array(Set(normalized)).sorted()
    }

    private func extractOptionalBool(_ value: ValueType?) -> Bool? {
        guard let value else { return nil }
        if case let .bool(flag) = value {
            return flag
        }
        return nil
    }

    private func extractInsertionModes(from value: ValueType?) -> [SupportedInsertionMode]? {
        guard let value else { return nil }
        switch value {
        case .string(let single):
            if let mode = SupportedInsertionMode(rawValue: single.lowercased()) {
                return [mode]
            }
            return nil
        case .list(let list):
            let modes = list.compactMap { current -> SupportedInsertionMode? in
                guard case let .string(raw) = current else { return nil }
                return SupportedInsertionMode(rawValue: raw.lowercased())
            }
            return modes.isEmpty ? nil : Array(Set(modes)).sorted(by: { $0.rawValue < $1.rawValue })
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

        var updatedEntry = CatalogEntry(
            id: resolvedID,
            sourceCellEndpoint: payload.sourceCellEndpoint,
            sourceCellName: payload.sourceCellName,
            purpose: payload.purpose,
            purposeDescription: payload.purposeDescription,
            interests: payload.interests,
            menuSlots: payload.menuSlots,
            goal: payload.goal,
            configuration: payload.configuration,
            displayName: payload.displayName,
            summary: payload.summary,
            categoryPath: payload.categoryPath,
            tags: payload.tags,
            purposeRefs: payload.purposeRefs,
            interestRefs: payload.interestRefs,
            supportedInsertionModes: payload.supportedInsertionModes,
            supportedTargetKinds: payload.supportedTargetKinds,
            ioGetKeys: payload.ioGetKeys,
            ioSetKeys: payload.ioSetKeys,
            ioTopics: payload.ioTopics,
            ioFilterTypes: payload.ioFilterTypes,
            authRequired: payload.authRequired,
            policyHints: payload.policyHints,
            flowDriven: payload.flowDriven,
            editable: payload.editable,
            recommendedContexts: payload.recommendedContexts,
            updatedAt: Date().timeIntervalSince1970
        )
        updatedEntry = enrichCatalogEntryMetadata(updatedEntry)

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

    private func migrateEntriesForMetadataIfNeeded() {
        stateQueue.sync {
            entriesByID = entriesByID.mapValues { enrichCatalogEntryMetadata($0) }
        }
    }

    private func enrichCatalogEntryMetadata(_ entry: CatalogEntry) -> CatalogEntry {
        var enriched = entry

        if enriched.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            enriched.displayName = entry.configuration.name
        }

        if enriched.summary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            enriched.summary = entry.purposeDescription ?? entry.configuration.description ?? "Ingen sammendrag tilgjengelig."
        }

        if enriched.categoryPath?.isEmpty ?? true {
            enriched.categoryPath = ["purpose", slugify(entry.purpose)]
        }

        if enriched.purposeRefs?.isEmpty ?? true {
            enriched.purposeRefs = [portablePurposeRef(for: entry.purpose)]
        }

        if enriched.interestRefs?.isEmpty ?? true {
            let refs = entry.interests.map { portableInterestRef(for: $0) }
            enriched.interestRefs = refs.isEmpty ? nil : refs
        }

        if enriched.supportedInsertionModes?.isEmpty ?? true {
            enriched.supportedInsertionModes = [.unknown]
        }

        if enriched.supportedTargetKinds?.isEmpty ?? true {
            enriched.supportedTargetKinds = nil
        }

        let derivedSetKeys = Set(entry.configuration.cellReferences?.flatMap { reference in
            reference.setKeysAndValues.map(\.key)
        } ?? [])

        if enriched.ioSetKeys?.isEmpty ?? true {
            enriched.ioSetKeys = derivedSetKeys.isEmpty ? nil : Array(derivedSetKeys).sorted()
        }

        if enriched.ioGetKeys?.isEmpty ?? true {
            enriched.ioGetKeys = nil
        }

        if enriched.ioTopics?.isEmpty ?? true {
            let topicKeys = derivedSetKeys.filter { $0.lowercased().contains("topic") }
            enriched.ioTopics = topicKeys.isEmpty ? nil : Array(topicKeys).sorted()
        }

        if enriched.ioFilterTypes?.isEmpty ?? true {
            enriched.ioFilterTypes = nil
        }

        if enriched.authRequired == nil {
            let source = entry.sourceCellEndpoint.lowercased()
            let looksProtected = source.contains("auth") || source.contains("security") || source.contains("agreement")
            enriched.authRequired = looksProtected
        }

        if enriched.policyHints?.isEmpty ?? true {
            if enriched.authRequired == true {
                enriched.policyHints = ["auth-required"]
            } else {
                enriched.policyHints = nil
            }
        }

        if enriched.flowDriven == nil {
            enriched.flowDriven = !(enriched.ioTopics?.isEmpty ?? true)
        }

        if enriched.editable == nil {
            enriched.editable = entry.configuration.skeleton != nil
        }

        if enriched.recommendedContexts?.isEmpty ?? true {
            let contexts = entry.menuSlots.map { "menu.\($0.rawValue)" }
            enriched.recommendedContexts = contexts.isEmpty ? nil : contexts
        }

        if enriched.tags?.isEmpty ?? true {
            var all = Set<String>()
            all.insert(slugify(entry.purpose))
            entry.interests.forEach { all.insert(slugify($0)) }
            enriched.categoryPath?.forEach { all.insert(slugify($0)) }
            if let insertion = enriched.supportedInsertionModes {
                insertion.forEach { all.insert($0.rawValue) }
            }
            enriched.tags = all.isEmpty ? nil : Array(all).sorted()
        }

        return enriched
    }

    private func slugify(_ value: String) -> String {
        let lowered = value.lowercased()
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) { return Character(String(scalar)) }
            return "-"
        }
        let collapsed = String(scalars)
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return collapsed.isEmpty ? "unknown" : collapsed
    }

    private func portablePurposeRef(for purpose: String) -> String {
        "purpose://\(slugify(purpose))"
    }

    private func portableInterestRef(for interest: String) -> String {
        "interest://\(slugify(interest))"
    }

    private func normalizePurposeRef(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("purpose://") {
            return trimmed.lowercased()
        }
        return portablePurposeRef(for: trimmed)
    }

    private func normalizeInterestRef(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("interest://") {
            return trimmed.lowercased()
        }
        return portableInterestRef(for: trimmed)
    }

    private func parseQueryConstraints(from value: ValueType?) -> QueryConstraints {
        guard case let .object(object)? = value else {
            return QueryConstraints(
                maxResults: 50,
                maxSources: 6,
                latencyBudgetMs: 350,
                resourceBudget: .balanced,
                networkPolicy: .preferHealthyThenCached,
                allowDegradedSources: true
            )
        }

        let maxResults = min(200, max(1, extractInt(object["maxResults"], default: 50)))
        let maxSources = min(12, max(1, extractInt(object["maxSources"], default: 6)))
        let latencyBudgetMs = min(5000, max(100, extractInt(object["latencyBudgetMs"], default: 350)))
        let resourceBudget = QueryResourceBudget(rawValue: extractString(object["resourceBudget"]) ?? "") ?? .balanced
        let networkPolicy = QueryNetworkPolicy(rawValue: extractString(object["networkPolicy"]) ?? "") ?? .preferHealthyThenCached
        let allowDegradedSources = extractBool(object["allowDegradedSources"], default: true)

        return QueryConstraints(
            maxResults: maxResults,
            maxSources: maxSources,
            latencyBudgetMs: latencyBudgetMs,
            resourceBudget: resourceBudget,
            networkPolicy: networkPolicy,
            allowDegradedSources: allowDegradedSources
        )
    }

    private func parseQueryContext(from value: ValueType?) -> QueryContext {
        guard case let .object(object)? = value else {
            return QueryContext(editMode: true, selectedNodeKind: nil, insertionIntent: .unknown)
        }

        let editMode = extractBool(object["editMode"], default: true)
        let selectedNodeKind = extractString(object["selectedNodeKind"])
        let insertionIntent: SupportedInsertionMode = {
            let raw = (extractString(object["insertionIntent"]) ?? "").lowercased()
            return SupportedInsertionMode(rawValue: raw) ?? .unknown
        }()

        return QueryContext(
            editMode: editMode,
            selectedNodeKind: selectedNodeKind,
            insertionIntent: insertionIntent
        )
    }

    private func extractBoolSet(from value: ValueType?) -> Set<Bool> {
        guard let value else { return [] }
        switch value {
        case .bool(let value):
            return [value]
        case .list(let list):
            return Set(list.compactMap {
                if case let .bool(value) = $0 { return value }
                return nil
            })
        default:
            return []
        }
    }

    private func parseQueryFilters(from value: ValueType?) -> QueryFilters {
        guard case let .object(object)? = value else {
            return QueryFilters(
                categoryPath: [],
                sourceRefs: [],
                authRequired: [],
                supportedInsertionModes: [],
                flowDriven: [],
                editable: []
            )
        }

        let categoryPath = Set((extractStringList(from: object["categoryPath"]) ?? []).map { $0.lowercased() })
        let sourceRefs = Set((extractStringList(from: object["sourceRefs"]) ?? []).map { $0.lowercased() })
        let authRequired = extractBoolSet(from: object["authRequired"])
        let supportedInsertionModes = Set(extractInsertionModes(from: object["supportedInsertionModes"]) ?? [])
        let flowDriven = extractBoolSet(from: object["flowDriven"])
        let editable = extractBoolSet(from: object["editable"])

        return QueryFilters(
            categoryPath: categoryPath,
            sourceRefs: sourceRefs,
            authRequired: authRequired,
            supportedInsertionModes: supportedInsertionModes,
            flowDriven: flowDriven,
            editable: editable
        )
    }

    private func mergeFilters(_ lhs: QueryFilters, _ rhs: QueryFilters) -> QueryFilters {
        QueryFilters(
            categoryPath: lhs.categoryPath.union(rhs.categoryPath),
            sourceRefs: lhs.sourceRefs.union(rhs.sourceRefs),
            authRequired: lhs.authRequired.union(rhs.authRequired),
            supportedInsertionModes: lhs.supportedInsertionModes.union(rhs.supportedInsertionModes),
            flowDriven: lhs.flowDriven.union(rhs.flowDriven),
            editable: lhs.editable.union(rhs.editable)
        )
    }

    private func entryMatchesFilters(_ entry: CatalogEntry, filters: QueryFilters) -> Bool {
        if !filters.categoryPath.isEmpty {
            let entryPath = (entry.categoryPath ?? []).map { $0.lowercased() }
            let joined = entryPath.joined(separator: "/")
            let hasCategory = filters.categoryPath.contains(where: { filter in
                joined.contains(filter) || entryPath.contains(filter)
            })
            if !hasCategory { return false }
        }

        if !filters.sourceRefs.isEmpty, !filters.sourceRefs.contains(entry.sourceCellEndpoint.lowercased()) {
            return false
        }

        if !filters.authRequired.isEmpty {
            let authValue = entry.authRequired ?? false
            if !filters.authRequired.contains(authValue) {
                return false
            }
        }

        if !filters.supportedInsertionModes.isEmpty {
            let entryModes = Set(entry.supportedInsertionModes ?? [.unknown])
            if entryModes.intersection(filters.supportedInsertionModes).isEmpty {
                return false
            }
        }

        if !filters.flowDriven.isEmpty {
            let value = entry.flowDriven ?? false
            if !filters.flowDriven.contains(value) {
                return false
            }
        }

        if !filters.editable.isEmpty {
            let value = entry.editable ?? false
            if !filters.editable.contains(value) {
                return false
            }
        }

        return true
    }

    private func tokenize(_ text: String) -> [String] {
        text
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 1 }
    }

    private func sourceHealth(for endpoint: String, errors: [String: CatalogErrorEntry]) -> SourceHealth {
        guard let error = errors[endpoint] else { return .online }
        if error.count >= 5 { return .offline }
        return .degraded
    }

    private func sourceHealthScore(_ health: SourceHealth) -> Double {
        switch health {
        case .online: return 1.0
        case .degraded: return 0.55
        case .offline: return 0.15
        }
    }

    private func scoreSource(
        endpoint: String,
        entries: [CatalogEntry],
        purposeRefs: Set<String>,
        interestRefs: Set<String>,
        queryTokens: [String],
        errors: [String: CatalogErrorEntry]
    ) -> SourceCandidate {
        let purposeUniverse = Set(entries.flatMap { ($0.purposeRefs ?? []).map { $0.lowercased() } })
        let interestUniverse = Set(entries.flatMap { ($0.interestRefs ?? []).map { $0.lowercased() } })

        let purposeFit: Double = {
            guard !purposeRefs.isEmpty else { return 0.5 }
            return Double(purposeRefs.intersection(purposeUniverse).count) / Double(max(1, purposeRefs.count))
        }()

        let interestFit: Double = {
            guard !interestRefs.isEmpty else { return 0.5 }
            return Double(interestRefs.intersection(interestUniverse).count) / Double(max(1, interestRefs.count))
        }()

        let textFit: Double = {
            guard !queryTokens.isEmpty else { return 0.5 }
            let corpus = entries.map {
                [
                    $0.displayName ?? "",
                    $0.summary ?? "",
                    $0.purpose,
                    ($0.tags ?? []).joined(separator: " "),
                    ($0.interests).joined(separator: " ")
                ].joined(separator: " ").lowercased()
            }.joined(separator: " ")
            let matches = Set(queryTokens.filter { corpus.contains($0) })
            return Double(matches.count) / Double(max(1, Set(queryTokens).count))
        }()

        let health = sourceHealth(for: endpoint, errors: errors)
        let healthScore = sourceHealthScore(health)
        let sizePenalty = min(1.0, Double(entries.count) / 1200.0)
        let score = (0.32 * purposeFit) + (0.22 * interestFit) + (0.16 * textFit) + (0.20 * healthScore) + (0.10 * (1.0 - sizePenalty))
        let estimatedRttMs: Int = {
            switch health {
            case .online: return 20 + min(80, entries.count / 6)
            case .degraded: return 120 + min(250, entries.count / 3)
            case .offline: return 700
            }
        }()

        return SourceCandidate(
            endpoint: endpoint,
            health: health,
            purposeFit: purposeFit,
            interestFit: interestFit,
            sizePenalty: sizePenalty,
            score: score,
            reason: "source_rank",
            estimatedRttMs: estimatedRttMs
        )
    }

    private func isLocalSource(_ endpoint: String) -> Bool {
        endpoint.lowercased().hasPrefix("cell:///")
    }

    private func selectSources(
        entries: [CatalogEntry],
        purposeRefs: Set<String>,
        interestRefs: Set<String>,
        queryTokens: [String],
        constraints: QueryConstraints
    ) -> (selected: [SourceCandidate], skipped: [SourceCandidate]) {
        let grouped = Dictionary(grouping: entries, by: \.sourceCellEndpoint)
        let errors = stateQueue.sync { catalogErrorsByEndpoint }
        var selectedPool: [SourceCandidate] = []
        var skipped: [SourceCandidate] = []

        for (endpoint, sourceEntries) in grouped {
            var candidate = scoreSource(
                endpoint: endpoint,
                entries: sourceEntries,
                purposeRefs: purposeRefs,
                interestRefs: interestRefs,
                queryTokens: queryTokens,
                errors: errors
            )

            switch constraints.networkPolicy {
            case .healthyOnly where candidate.health != .online:
                candidate.reason = "healthyOnlyPolicy"
                skipped.append(candidate)
                continue
            case .cacheOnly where !isLocalSource(endpoint):
                candidate.reason = "cacheOnlyPolicy"
                skipped.append(candidate)
                continue
            default:
                break
            }

            if !constraints.allowDegradedSources, candidate.health != .online {
                candidate.reason = "degradedSourcesNotAllowed"
                skipped.append(candidate)
                continue
            }

            selectedPool.append(candidate)
        }

        selectedPool.sort { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.endpoint.localizedCaseInsensitiveCompare(rhs.endpoint) == .orderedAscending
            }
            return lhs.score > rhs.score
        }

        let selected = Array(selectedPool.prefix(constraints.maxSources))
        if selectedPool.count > constraints.maxSources {
            for candidate in selectedPool.dropFirst(constraints.maxSources) {
                var skippedCandidate = candidate
                skippedCandidate.reason = "maxSourcesLimit"
                skipped.append(skippedCandidate)
            }
        }

        return (selected, skipped)
    }

    private func queryWorkingSet(
        from object: Object,
        additionalFilters: QueryFilters? = nil
    ) -> (
        requestId: String,
        queryText: String,
        purposeRefs: Set<String>,
        interestRefs: Set<String>,
        constraints: QueryConstraints,
        context: QueryContext,
        entries: [CatalogEntry],
        selectedSources: [SourceCandidate],
        skippedSources: [SourceCandidate]
    ) {
        let requestId = extractString(object["requestId"]) ?? UUID().uuidString
        let queryText = extractString(object["q"]) ?? extractString(object["query"]) ?? ""
        var purposeRefs = Set((extractStringList(from: object["purposeRefs"]) ?? []).map { normalizePurposeRef($0) })
        var interestRefs = Set((extractStringList(from: object["interestRefs"]) ?? []).map { normalizeInterestRef($0) })

        if let fallbackPurposes = extractStringList(from: object["purposes"]) {
            fallbackPurposes.forEach { purposeRefs.insert(normalizePurposeRef($0)) }
        }
        if let fallbackInterests = extractStringList(from: object["interests"]) {
            fallbackInterests.forEach { interestRefs.insert(normalizeInterestRef($0)) }
        }

        var queryTokens = tokenize(queryText)
        if case let .list(tokenList)? = object["tokens"] {
            for token in tokenList {
                guard case let .object(tokenObject) = token else { continue }
                let kind = (extractString(tokenObject["kind"]) ?? "").lowercased()
                guard let value = extractString(tokenObject["value"]), !value.isEmpty else { continue }
                switch kind {
                case "purpose":
                    purposeRefs.insert(normalizePurposeRef(value))
                case "interest":
                    interestRefs.insert(normalizeInterestRef(value))
                default:
                    queryTokens.append(contentsOf: tokenize(value))
                }
            }
        }

        let filters = parseQueryFilters(from: object["filters"])
        let mergedFilters = mergeFilters(filters, additionalFilters ?? QueryFilters(
            categoryPath: [],
            sourceRefs: [],
            authRequired: [],
            supportedInsertionModes: [],
            flowDriven: [],
            editable: []
        ))
        let constraints = parseQueryConstraints(from: object["constraints"])
        let context = parseQueryContext(from: object["context"])

        let allEntries = sortedEntries().map { enrichCatalogEntryMetadata($0) }
        let sourceSelection = selectSources(
            entries: allEntries,
            purposeRefs: purposeRefs,
            interestRefs: interestRefs,
            queryTokens: queryTokens,
            constraints: constraints
        )
        let selectedSet = Set(sourceSelection.selected.map { $0.endpoint.lowercased() })
        let filteredEntries = allEntries.filter { entry in
            selectedSet.contains(entry.sourceCellEndpoint.lowercased()) &&
            entryMatchesFilters(entry, filters: mergedFilters)
        }

        return (
            requestId: requestId,
            queryText: queryText,
            purposeRefs: purposeRefs,
            interestRefs: interestRefs,
            constraints: constraints,
            context: context,
            entries: filteredEntries,
            selectedSources: sourceSelection.selected,
            skippedSources: sourceSelection.skipped
        )
    }

    private func textScore(for entry: CatalogEntry, queryText: String) -> Double {
        let tokens = tokenize(queryText)
        guard !tokens.isEmpty else { return 0.5 }
        let corpus = [
            entry.displayName ?? "",
            entry.summary ?? "",
            entry.purpose,
            entry.purposeDescription ?? "",
            (entry.tags ?? []).joined(separator: " "),
            entry.interests.joined(separator: " "),
            (entry.categoryPath ?? []).joined(separator: " "),
            entry.configuration.name,
            entry.configuration.description ?? ""
        ].joined(separator: " ").lowercased()
        let matches = Set(tokens.filter { corpus.contains($0) })
        return Double(matches.count) / Double(max(1, Set(tokens).count))
    }

    private func purposeScore(for entry: CatalogEntry, purposeRefs: Set<String>) -> Double {
        guard !purposeRefs.isEmpty else { return 0.5 }
        let entryRefs = Set((entry.purposeRefs ?? []).map { $0.lowercased() })
        let overlap = purposeRefs.intersection(entryRefs)
        return Double(overlap.count) / Double(max(1, purposeRefs.count))
    }

    private func interestScore(for entry: CatalogEntry, interestRefs: Set<String>) -> Double {
        guard !interestRefs.isEmpty else { return 0.5 }
        let entryRefs = Set((entry.interestRefs ?? []).map { $0.lowercased() })
        let overlap = interestRefs.intersection(entryRefs)
        return Double(overlap.count) / Double(max(1, interestRefs.count))
    }

    private func compatibilityScore(for entry: CatalogEntry, context: QueryContext) -> Double {
        var score = 0.5
        let modes = Set(entry.supportedInsertionModes ?? [.unknown])
        switch context.insertionIntent {
        case .unknown:
            score = 0.5
        case .root:
            score = modes.contains(.root) || modes.contains(.both) ? 1.0 : (modes.contains(.unknown) ? 0.35 : 0.0)
        case .component:
            score = modes.contains(.component) || modes.contains(.both) ? 1.0 : (modes.contains(.unknown) ? 0.35 : 0.0)
        case .both:
            score = modes.contains(.both) ? 1.0 : 0.7
        }

        if let selectedNodeKind = context.selectedNodeKind?.lowercased(),
           let kinds = entry.supportedTargetKinds?.map({ $0.lowercased() }),
           !kinds.isEmpty {
            if kinds.contains(selectedNodeKind) {
                score = min(1.0, score + 0.2)
            } else {
                score *= 0.5
            }
        }

        return min(1.0, max(0.0, score))
    }

    private func resourceScore(for entry: CatalogEntry, budget: QueryResourceBudget) -> Double {
        let references = entry.configuration.cellReferences?.count ?? 0
        let setOps = entry.configuration.cellReferences?.reduce(0, { $0 + $1.setKeysAndValues.count }) ?? 0
        let complexity = Double(references) + (entry.configuration.skeleton != nil ? 1.5 : 0.5) + (Double(setOps) * 0.2)

        switch budget {
        case .low:
            return max(0.0, 1.0 - min(1.0, complexity / 8.0))
        case .balanced:
            return max(0.0, 1.0 - min(1.0, abs(complexity - 3.0) / 7.0))
        case .high:
            return min(1.0, 0.35 + min(0.65, complexity / 9.0))
        }
    }

    private func recencyScore(for entry: CatalogEntry) -> Double {
        let ageSeconds = max(0.0, Date().timeIntervalSince1970 - entry.updatedAt)
        let ageDays = ageSeconds / 86400.0
        return exp(-ageDays / 30.0)
    }

    private func badges(for entry: CatalogEntry) -> [String] {
        var badges: [String] = []
        let insertion = Set(entry.supportedInsertionModes ?? [.unknown])
        if insertion.contains(.both) {
            badges.append("Both")
        } else if insertion.contains(.root) {
            badges.append("Root")
        } else if insertion.contains(.component) {
            badges.append("Component")
        } else {
            badges.append("Unknown")
        }
        if entry.authRequired == true {
            badges.append("Auth-required")
        }
        if entry.flowDriven == true {
            badges.append("Flow-driven")
        }
        if entry.editable == true {
            badges.append("Editable")
        }
        return badges
    }

    private func queryCatalog(payload: ValueType, requester: Identity) -> ValueType {
        guard case let .object(object) = payload else {
            return .object([
                "status": .string("error"),
                "message": .string("query forventer object payload")
            ])
        }

        let startedAt = Date()
        let sourceSelectionStarted = Date()
        let workingSet = queryWorkingSet(from: object)
        let sourceSelectionMs = Int(Date().timeIntervalSince(sourceSelectionStarted) * 1000.0)
        let selectedByEndpoint = Dictionary(uniqueKeysWithValues: workingSet.selectedSources.map { ($0.endpoint.lowercased(), $0) })
        let scoringStarted = Date()

        struct ScoredItem {
            var entry: CatalogEntry
            var score: QueryScoreBreakdown
            var route: String
        }

        let hasSignal = !workingSet.queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !workingSet.purposeRefs.isEmpty || !workingSet.interestRefs.isEmpty

        let scored: [ScoredItem] = workingSet.entries.compactMap { entry in
            let entryHealth = selectedByEndpoint[entry.sourceCellEndpoint.lowercased()]?.health ?? .online
            let breakdown = QueryScoreBreakdown(
                text: textScore(for: entry, queryText: workingSet.queryText),
                purpose: purposeScore(for: entry, purposeRefs: workingSet.purposeRefs),
                interest: interestScore(for: entry, interestRefs: workingSet.interestRefs),
                compatibility: compatibilityScore(for: entry, context: workingSet.context),
                connectivity: sourceHealthScore(entryHealth),
                resourceFit: resourceScore(for: entry, budget: workingSet.constraints.resourceBudget),
                recency: recencyScore(for: entry)
            )

            if hasSignal && breakdown.text <= 0.0 && breakdown.purpose <= 0.0 && breakdown.interest <= 0.0 {
                return nil
            }

            let route: String = {
                if breakdown.purpose > 0.0 && breakdown.purpose >= breakdown.interest { return "directPurpose" }
                if breakdown.interest > 0.0 { return "viaInterest" }
                return "text"
            }()

            return ScoredItem(entry: entry, score: breakdown, route: route)
        }
        .sorted { lhs, rhs in
            if lhs.score.finalScore == rhs.score.finalScore {
                if lhs.score.purpose == rhs.score.purpose {
                    let lhsName = lhs.entry.displayName ?? lhs.entry.configuration.name
                    let rhsName = rhs.entry.displayName ?? rhs.entry.configuration.name
                    if lhsName.caseInsensitiveCompare(rhsName) == .orderedSame {
                        return lhs.entry.id.localizedCaseInsensitiveCompare(rhs.entry.id) == .orderedAscending
                    }
                    return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
                }
                return lhs.score.purpose > rhs.score.purpose
            }
            return lhs.score.finalScore > rhs.score.finalScore
        }

        let limited = Array(scored.prefix(workingSet.constraints.maxResults))
        let scoringMs = Int(Date().timeIntervalSince(scoringStarted) * 1000.0)

        let resultObjects: [ValueType] = limited.map { item in
            let entry = item.entry
            let purposeRefs = entry.purposeRefs ?? [portablePurposeRef(for: entry.purpose)]
            let interestRefs = entry.interestRefs ?? entry.interests.map { portableInterestRef(for: $0) }
            let supportedModes = (entry.supportedInsertionModes ?? [.unknown]).map { ValueType.string($0.rawValue) }
            let targetKinds = (entry.supportedTargetKinds ?? []).map { ValueType.string($0) }
            let overlapPurposes = purposeRefs.filter { workingSet.purposeRefs.contains($0.lowercased()) }
            let overlapInterests = interestRefs.filter { workingSet.interestRefs.contains($0.lowercased()) }
            let purposeSupport = (overlapPurposes.isEmpty ? Array(purposeRefs.prefix(1)) : overlapPurposes)
                .map { ValueType.object(["portablePurposeRef": .string($0), "weight": .float(item.score.purpose)]) }
            let interestSupport = (overlapInterests.isEmpty ? Array(interestRefs.prefix(2)) : overlapInterests)
                .map { ValueType.object(["portableInterestRef": .string($0), "weight": .float(item.score.interest)]) }

            return .object([
                "configurationId": .string(entry.id),
                "displayName": .string(entry.displayName ?? entry.configuration.name),
                "summary": .string(entry.summary ?? ""),
                "sourceRef": .string(entry.sourceCellEndpoint),
                "score": .float(item.score.finalScore),
                "scoreBreakdown": .object([
                    "text": .float(item.score.text),
                    "purpose": .float(item.score.purpose),
                    "interest": .float(item.score.interest),
                    "compatibility": .float(item.score.compatibility),
                    "connectivity": .float(item.score.connectivity),
                    "resourceFit": .float(item.score.resourceFit),
                    "recency": .float(item.score.recency)
                ]),
                "route": .string(item.route),
                "supportingPurposes": .list(purposeSupport),
                "supportingInterests": .list(interestSupport),
                "compatibility": .object([
                    "supportedInsertionModes": .list(supportedModes),
                    "supportedTargetKinds": .list(targetKinds)
                ]),
                "badges": .list(badges(for: entry).map { .string($0) }),
                "configuration": .cellConfiguration(entry.configuration)
            ])
        }

        let selectedSourceObjects: [ValueType] = workingSet.selectedSources.map { source in
            .object([
                "sourceRef": .string(source.endpoint),
                "reason": .string(source.reason),
                "health": .string(source.health.rawValue),
                "rttMs": .integer(source.estimatedRttMs)
            ])
        }

        let skippedSourceObjects: [ValueType] = workingSet.skippedSources.map { source in
            .object([
                "sourceRef": .string(source.endpoint),
                "reason": .string(source.reason),
                "health": .string(source.health.rawValue)
            ])
        }

        let totalMs = Int(Date().timeIntervalSince(startedAt) * 1000.0)
        let responseObject: Object = [
            "requestId": .string(workingSet.requestId),
            "status": .string("ok"),
            "resultCount": .integer(resultObjects.count),
            "results": .list(resultObjects),
            "sourceSelection": .object([
                "selected": .list(selectedSourceObjects),
                "skipped": .list(skippedSourceObjects)
            ]),
            "timing": .object([
                "sourceSelectionMs": .integer(sourceSelectionMs),
                "rankMs": .integer(scoringMs),
                "totalMs": .integer(totalMs)
            ]),
            "connectivity": .object([
                "onlineSources": .integer(workingSet.selectedSources.filter { $0.health == .online }.count),
                "degradedSources": .integer(workingSet.selectedSources.filter { $0.health == .degraded }.count),
                "offlineSources": .integer(workingSet.selectedSources.filter { $0.health == .offline }.count)
            ]),
            "warnings": .list(workingSet.skippedSources.map { .string("\($0.endpoint): \($0.reason)") })
        ]

        stateQueue.sync {
            lastQueryState = .object(responseObject)
        }
        return .object(responseObject)
    }

    private func queryFacetCounts(payload: ValueType, requester: Identity) -> ValueType {
        guard case let .object(object) = payload else {
            return .object([
                "status": .string("error"),
                "message": .string("facetCounts forventer object payload")
            ])
        }

        let requestId = extractString(object["requestId"]) ?? UUID().uuidString
        let maxBuckets = min(50, max(1, extractInt(object["maxBucketsPerFacet"], default: 20)))
        let countMode = (extractString(object["countMode"]) ?? "exactOrApprox").lowercased()
        let baseQueryObject: Object = {
            if case let .object(base)? = object["baseQuery"] {
                return base
            }
            return [:]
        }()
        let activeFilters = parseQueryFilters(from: object["activeFilters"])
        var mergedBase = baseQueryObject
        mergedBase["requestId"] = .string(requestId)
        if mergedBase["constraints"] == nil, let constraints = object["constraints"] {
            mergedBase["constraints"] = constraints
        }

        let startedAt = Date()
        let workingSet = queryWorkingSet(from: mergedBase, additionalFilters: activeFilters)
        let exact = workingSet.skippedSources.isEmpty && countMode != "approxonly"
        let facetKeys = extractStringList(from: object["facetKeys"]) ?? [
            "categoryPath",
            "sourceRef",
            "supportedInsertionModes",
            "authRequired"
        ]

        var facetsObject: Object = [:]
        for facetKey in facetKeys {
            var counts: [String: Int] = [:]
            for entry in workingSet.entries {
                switch facetKey {
                case "categoryPath":
                    let value = (entry.categoryPath ?? ["unknown"]).joined(separator: "/")
                    counts[value, default: 0] += 1
                case "sourceRef":
                    counts[entry.sourceCellEndpoint, default: 0] += 1
                case "supportedInsertionModes", "compatibility":
                    for mode in (entry.supportedInsertionModes ?? [.unknown]) {
                        counts[mode.rawValue, default: 0] += 1
                    }
                case "authRequired":
                    let value = entry.authRequired == nil ? "unknown" : ((entry.authRequired ?? false) ? "true" : "false")
                    counts[value, default: 0] += 1
                case "flowDriven":
                    let value = (entry.flowDriven ?? false) ? "true" : "false"
                    counts[value, default: 0] += 1
                case "editable":
                    let value = (entry.editable ?? false) ? "true" : "false"
                    counts[value, default: 0] += 1
                case "purposeRef":
                    for purposeRef in entry.purposeRefs ?? [portablePurposeRef(for: entry.purpose)] {
                        counts[purposeRef, default: 0] += 1
                    }
                case "interestRef":
                    for interestRef in entry.interestRefs ?? entry.interests.map({ portableInterestRef(for: $0) }) {
                        counts[interestRef, default: 0] += 1
                    }
                default:
                    continue
                }
            }

            let buckets: [ValueType] = counts
                .map { ($0.key, $0.value) }
                .sorted { lhs, rhs in
                    if lhs.1 == rhs.1 {
                        return lhs.0.localizedCaseInsensitiveCompare(rhs.0) == .orderedAscending
                    }
                    return lhs.1 > rhs.1
                }
                .prefix(maxBuckets)
                .map { value, count in
                    var bucket: Object = [
                        "value": .string(value),
                        "count": .integer(count),
                        "exact": .bool(exact)
                    ]
                    if !exact {
                        bucket["note"] = .string("partial due to source limits/policy")
                    }
                    return .object(bucket)
                }

            facetsObject[facetKey] = .list(Array(buckets))
        }

        let responseObject: Object = [
            "requestId": .string(requestId),
            "status": .string("ok"),
            "facets": .object(facetsObject),
            "coverage": .object([
                "sourcesConsidered": .integer(workingSet.selectedSources.count + workingSet.skippedSources.count),
                "sourcesResponded": .integer(workingSet.selectedSources.count),
                "fromCache": .integer(workingSet.selectedSources.filter { isLocalSource($0.endpoint) }.count)
            ]),
            "timing": .object([
                "totalMs": .integer(Int(Date().timeIntervalSince(startedAt) * 1000.0))
            ]),
            "warnings": .list(workingSet.skippedSources.map { .string("\($0.endpoint): \($0.reason)") })
        ]

        return .object(responseObject)
    }

    private enum MatchingPublishField {
        case personName
        case groupName
        case groupType
        case note
    }

    private func extractTextInput(_ payload: ValueType, preferredKey: String? = nil) -> String? {
        switch payload {
        case .string(let value):
            return value
        case .object(let object):
            if let preferredKey,
               case let .string(value)? = object[preferredKey] {
                return value
            }
            if case let .string(value)? = object["value"] {
                return value
            }
            if case let .string(value)? = object["text"] {
                return value
            }
            return nil
        default:
            return nil
        }
    }

    private func matchingPublishPersonNameValue() -> ValueType {
        stateQueue.sync {
            .string(matchingPublishPersonName)
        }
    }

    private func matchingPublishGroupNameValue() -> ValueType {
        stateQueue.sync {
            .string(matchingPublishGroupName)
        }
    }

    private func matchingPublishGroupTypeValue() -> ValueType {
        stateQueue.sync {
            .string(matchingPublishGroupType)
        }
    }

    private func matchingPublishNoteValue() -> ValueType {
        stateQueue.sync {
            .string(matchingPublishNote)
        }
    }

    private func updateMatchingPublishField(_ payload: ValueType, field: MatchingPublishField) -> ValueType {
        let preferredKey: String = {
            switch field {
            case .personName: return "personName"
            case .groupName: return "groupName"
            case .groupType: return "groupType"
            case .note: return "note"
            }
        }()
        guard let rawValue = extractTextInput(payload, preferredKey: preferredKey) else {
            return .string("error: invalid publish field payload")
        }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        stateQueue.sync {
            switch field {
            case .personName:
                matchingPublishPersonName = value
            case .groupName:
                matchingPublishGroupName = value
            case .groupType:
                matchingPublishGroupType = value.isEmpty ? "selskap" : value
            case .note:
                matchingPublishNote = value
            }
        }
        switch field {
        case .personName:
            return matchingPublishPersonNameValue()
        case .groupName:
            return matchingPublishGroupNameValue()
        case .groupType:
            return matchingPublishGroupTypeValue()
        case .note:
            return matchingPublishNoteValue()
        }
    }

    private func matchingPromptTextValue() -> ValueType {
        stateQueue.sync {
            .string(matchingPromptText)
        }
    }

    private func matchingSuggestionsValue() -> ValueType {
        stateQueue.sync {
            .list(matchingSuggestions.map { .object($0.asObject()) })
        }
    }

    private func matchingBookmarksValue() -> ValueType {
        stateQueue.sync {
            .list(matchingBookmarks.map { .object($0.asObject()) })
        }
    }

    private func matchingPurposeStatsValue() -> ValueType {
        stateQueue.sync {
            let sorted = matchingPurposeStatsByPurpose.values.sorted { lhs, rhs in
                if lhs.effectiveness == rhs.effectiveness {
                    return lhs.lastUsedAt > rhs.lastUsedAt
                }
                return lhs.effectiveness > rhs.effectiveness
            }
            return .list(sorted.map { .object($0.asObject()) })
        }
    }

    private func matchingEntityPurposePublicationsValue() -> ValueType {
        stateQueue.sync {
            .list(matchingPublishedEntityPurposes.map { .object($0.asObject()) })
        }
    }

    private func matchingSelectedSuggestionValue() -> ValueType {
        stateQueue.sync {
            guard matchingSelectedIndex >= 0, matchingSelectedIndex < matchingSuggestions.count else {
                return .list([])
            }
            return .list([.object(matchingSuggestions[matchingSelectedIndex].asObject())])
        }
    }

    private func matchingSelectedIndexValue() -> ValueType {
        stateQueue.sync {
            .integer(matchingSelectedIndex)
        }
    }

    private func matchingStateValue() -> ValueType {
        stateQueue.sync {
            var object: Object = [
                "promptText": .string(matchingPromptText),
                "suggestionCount": .integer(matchingSuggestions.count),
                "bookmarkCount": .integer(matchingBookmarks.count),
                "purposeStatsCount": .integer(matchingPurposeStatsByPurpose.count),
                "entityPurposePublicationCount": .integer(matchingPublishedEntityPurposes.count),
                "selectedIndex": .integer(matchingSelectedIndex),
                "publishPersonName": .string(matchingPublishPersonName),
                "publishGroupName": .string(matchingPublishGroupName),
                "publishGroupType": .string(matchingPublishGroupType),
                "publishNote": .string(matchingPublishNote)
            ]
            if matchingSelectedIndex >= 0, matchingSelectedIndex < matchingSuggestions.count {
                object["selectedName"] = .string(matchingSuggestions[matchingSelectedIndex].configuration.name)
                object["selectedId"] = .string(matchingSuggestions[matchingSelectedIndex].id)
                object["selectedMeaning"] = .string(matchingSuggestions[matchingSelectedIndex].matchMeaning)
            }
            return .object(object)
        }
    }

    private func updateMatchingPromptText(_ payload: ValueType) -> ValueType {
        let prompt: String?
        switch payload {
        case .string(let value):
            prompt = value
        case .object(let object):
            if case let .string(value)? = object["prompt"] {
                prompt = value
            } else {
                prompt = nil
            }
        default:
            prompt = nil
        }
        guard let prompt else { return .string("error: invalid prompt payload") }
        stateQueue.sync {
            matchingPromptText = prompt
        }
        return .string(prompt)
    }

    private func runMatchingPrompt(_ payload: ValueType) -> ValueType {
        let explicitPrompt: String?
        switch payload {
        case .string(let prompt):
            explicitPrompt = prompt
        case .object(let object):
            if case let .string(prompt)? = object["prompt"] {
                explicitPrompt = prompt
            } else {
                explicitPrompt = nil
            }
        default:
            explicitPrompt = nil
        }

        let prompt = stateQueue.sync {
            let resolved = explicitPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !resolved.isEmpty {
                matchingPromptText = resolved
                return resolved
            }
            return matchingPromptText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !prompt.isEmpty else {
            return .object([
                "status": .string("empty_prompt"),
                "state": matchingStateValue()
            ])
        }

        let query = deriveMatchingQuery(from: prompt)
        let matchedEntries = matchConfigurationsDetailed(
            purpose: query.purpose,
            interests: query.interests,
            menuSlot: nil,
            limit: 10
        )

        let now = Date().timeIntervalSince1970
        let suggestions: [MatchingSuggestion] = matchedEntries.map { entry in
            MatchingSuggestion(
                id: UUID().uuidString,
                sourceEntryID: entry.entry.id,
                prompt: prompt,
                purpose: entry.entry.purpose,
                interests: entry.entry.interests,
                overlappingInterests: entry.overlapInterests,
                menuSlots: entry.entry.menuSlots,
                configuration: entry.entry.configuration,
                matchScore: entry.score,
                matchMeaning: entry.reasons.joined(separator: " | "),
                hasSkeleton: entry.entry.configuration.skeleton != nil,
                matchedAt: now
            )
        }

        stateQueue.sync {
            matchingSuggestions = suggestions
            matchingSelectedIndex = suggestions.isEmpty ? -1 : 0
        }

        return .object([
            "status": .string("ok"),
            "prompt": .string(prompt),
            "queryPurpose": query.purpose.map { .string($0) } ?? .null,
            "queryInterests": .list(query.interests.map { .string($0) }),
            "count": .integer(suggestions.count),
            "state": matchingStateValue(),
            "suggestions": matchingSuggestionsValue()
        ])
    }

    private func selectMatchingSuggestion(_ payload: ValueType) -> ValueType {
        if let index = matchingIndex(from: payload) {
            return selectMatchingSuggestion(at: index)
        }

        let selectedID: String?
        switch payload {
        case .string(let id):
            selectedID = id
        case .object(let object):
            if case let .string(id)? = object["id"] {
                selectedID = id
            } else if case let .string(id)? = object["selectedId"] {
                selectedID = id
            } else {
                selectedID = nil
            }
        default:
            selectedID = nil
        }

        guard let selectedID else { return .string("error: invalid select payload") }
        let index = stateQueue.sync {
            matchingSuggestions.firstIndex(where: { $0.id == selectedID })
        }
        guard let index else { return .string("error: suggestion not found") }
        return selectMatchingSuggestion(at: index)
    }

    private func selectMatchingSuggestionByIndexPayload(_ payload: ValueType) -> ValueType {
        guard let index = matchingIndex(from: payload) else {
            return .string("error: invalid index")
        }
        return selectMatchingSuggestion(at: index)
    }

    private func selectMatchingSuggestion(at index: Int) -> ValueType {
        let normalized = stateQueue.sync {
            guard !matchingSuggestions.isEmpty else { return -1 }
            let clamped = max(0, min(index, matchingSuggestions.count - 1))
            matchingSelectedIndex = clamped
            return clamped
        }
        guard normalized >= 0 else { return .string("error: no suggestions") }
        return .object([
            "status": .string("ok"),
            "selectedIndex": .integer(normalized),
            "selected": matchingSelectedSuggestionValue(),
            "state": matchingStateValue()
        ])
    }

    private func matchingIndex(from payload: ValueType) -> Int? {
        switch payload {
        case .integer(let index):
            return index
        case .number(let index):
            return index
        case .string(let value):
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        case .object(let object):
            if case let .integer(index)? = object["index"] {
                return index
            }
            if case let .number(index)? = object["index"] {
                return index
            }
            if case let .string(value)? = object["index"] {
                return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return nil
        default:
            return nil
        }
    }

    private func selectedMatchingSuggestion() -> MatchingSuggestion? {
        stateQueue.sync {
            guard matchingSelectedIndex >= 0, matchingSelectedIndex < matchingSuggestions.count else { return nil }
            return matchingSuggestions[matchingSelectedIndex]
        }
    }

    private func loadSelectedMatchingSuggestionToPorthole(requester: Identity) async -> ValueType {
        guard let selected = selectedMatchingSuggestion() else {
            return .string("error: no selected suggestion")
        }
        guard let resolver = CellBase.defaultCellResolver else {
            return .string("error: no resolver")
        }
        do {
            guard let porthole = try await resolver.cellAtEndpoint(endpoint: "cell:///Porthole", requester: requester) as? Meddle else {
                return .string("error: porthole unavailable")
            }
            _ = try await porthole.set(
                keypath: "setConfiguration",
                value: .cellConfiguration(selected.configuration),
                requester: requester
            )
            let usageResult = await markSelectedSuggestionUsage(achievedGoal: false, requester: requester)
            return .object([
                "status": .string("loaded"),
                "selected": .list([.object(selected.asObject())]),
                "usage": usageResult,
                "state": matchingStateValue()
            ])
        } catch {
            return .string("error: failed loading selected suggestion")
        }
    }

    private func saveSelectedMatchingSuggestionToMenu(payload: ValueType, requester: Identity) async -> ValueType {
        guard let selected = selectedMatchingSuggestion() else {
            return .string("error: no selected suggestion")
        }

        let menuSlot = extractMenuSlot(payload) ?? .upperMid
        var purpose = selected.purpose
        if case let .object(object) = payload,
           case let .string(value)? = object["purpose"],
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            purpose = value
        }

        let payloadObject = CatalogPayload(
            id: nil,
            sourceCellEndpoint: selected.configuration.cellReferences?.first?.endpoint ?? "cell:///Unknown",
            sourceCellName: selected.configuration.name,
            purpose: purpose,
            purposeDescription: selected.configuration.description,
            interests: selected.interests,
            menuSlots: [menuSlot],
            goal: selected.configuration,
            configuration: selected.configuration
        )
        let entry = upsert(from: payloadObject, keepExistingIDWhenMissing: true)
        await emitCatalogEvent(operation: "matching.saveSelectedToMenu", entry: entry, requester: requester)

        return .object([
            "status": .string("saved"),
            "menuSlot": .string(menuSlot.rawValue),
            "entry": .object(entry.asObject()),
            "state": stateValue()
        ])
    }

    private func bookmarkSelectedMatchingSuggestion() -> ValueType {
        guard let selected = selectedMatchingSuggestion() else {
            return .string("error: no selected suggestion")
        }
        stateQueue.sync {
            if matchingBookmarks.contains(where: { $0.configuration.uuid == selected.configuration.uuid }) == false {
                matchingBookmarks.insert(selected, at: 0)
                if matchingBookmarks.count > 30 {
                    matchingBookmarks = Array(matchingBookmarks.prefix(30))
                }
            }
        }
        return .object([
            "status": .string("bookmarked"),
            "bookmarks": matchingBookmarksValue(),
            "state": matchingStateValue()
        ])
    }

    private func markSelectedSuggestionUsage(achievedGoal: Bool, requester: Identity) async -> ValueType {
        guard let selected = selectedMatchingSuggestion() else {
            return .string("error: no selected suggestion")
        }

        let timestamp = Date().timeIntervalSince1970
        let updated = stateQueue.sync {
            var stat = matchingPurposeStatsByPurpose[selected.purpose] ?? PurposeUsageStat(
                purpose: selected.purpose,
                useCount: 0,
                achievedCount: 0,
                effectiveness: 0.0,
                currentWeight: 0.4,
                lastUsedAt: timestamp
            )
            stat.useCount += 1
            if achievedGoal {
                stat.achievedCount += 1
            }
            stat.effectiveness = stat.useCount > 0 ? Double(stat.achievedCount) / Double(stat.useCount) : 0.0
            let usageSignal = achievedGoal ? 0.55 : 0.04
            let effectivenessSignal = achievedGoal ? (0.2 * stat.effectiveness) : 0.0
            stat.currentWeight = min(5.0, max(0.1, stat.currentWeight + usageSignal + effectivenessSignal))
            stat.lastUsedAt = timestamp
            matchingPurposeStatsByPurpose[selected.purpose] = stat
            return stat
        }

        await nudgePerspectivePurposeWeight(
            purpose: selected.purpose,
            suggestedWeight: updated.currentWeight,
            achievedGoal: achievedGoal,
            requester: requester
        )

        var payload: Object = [
            "purpose": .string(selected.purpose),
            "suggestionId": .string(selected.id),
            "achievedGoal": .bool(achievedGoal),
            "useCount": .integer(updated.useCount),
            "achievedCount": .integer(updated.achievedCount),
            "effectiveness": .float(updated.effectiveness),
            "currentWeight": .float(updated.currentWeight)
        ]
        payload["state"] = matchingStateValue()
        var flow = FlowElement(
            title: achievedGoal ? "purpose.goalAchieved" : "purpose.activated",
            content: .object(payload),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flow.topic = "purpose.outcome"
        flow.origin = uuid
        pushFlowElement(flow, requester: requester)

        return .object([
            "status": .string(achievedGoal ? "goal_achieved" : "used"),
            "purposeStat": .object(updated.asObject()),
            "state": matchingStateValue()
        ])
    }

    private func nudgePerspectivePurposeWeight(
        purpose: String,
        suggestedWeight: Double,
        achievedGoal: Bool,
        requester: Identity
    ) async {
        guard let resolver = CellBase.defaultCellResolver else { return }
        guard let perspective = try? await resolver.cellAtEndpoint(endpoint: "cell:///Perspective", requester: requester) as? Meddle else { return }

        let purposeObject: Object = [
            "name": .string(purpose),
            "description": .string(achievedGoal ? "Goal achieved via AppleIntelligence matcher." : "Activated via AppleIntelligence matcher."),
            "types": .list([]),
            "subTypes": .list([]),
            "parts": .list([]),
            "partOf": .list([]),
            "purposes": .list([]),
            "interests": .list([]),
            "entities": .list([]),
            "states": .list([])
        ]
        let payload: Object = [
            "purpose": .object(purposeObject),
            "purposeWeight": .float(suggestedWeight)
        ]
        _ = try? await perspective.set(keypath: "addPurpose", value: .object(payload), requester: requester)
    }

    private func publishEntityPurpose(payload: ValueType, requester: Identity) async -> ValueType {
        let object: Object = {
            if case let .object(value) = payload {
                return value
            }
            return [:]
        }()
        let publishDefaults = stateQueue.sync {
            (
                personName: matchingPublishPersonName.trimmingCharacters(in: .whitespacesAndNewlines),
                groupName: matchingPublishGroupName.trimmingCharacters(in: .whitespacesAndNewlines),
                groupType: matchingPublishGroupType.trimmingCharacters(in: .whitespacesAndNewlines),
                note: matchingPublishNote.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        let entityTypeRaw: String = {
            if case let .string(value)? = object["entityType"], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            return "person"
        }()
        let entityType: String = (entityTypeRaw == "group" || entityTypeRaw == "person") ? entityTypeRaw : "person"

        let payloadEntityName: String? = {
            if case let .string(value)? = object["entityName"] {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            return nil
        }()

        let fallbackEntityName = entityType == "group"
            ? (publishDefaults.groupName.isEmpty ? "Ukjent gruppe" : publishDefaults.groupName)
            : (publishDefaults.personName.isEmpty ? "Ukjent person" : publishDefaults.personName)
        let entityName = payloadEntityName ?? fallbackEntityName

        let entitySubtype: String? = {
            if case let .string(value)? = object["entitySubtype"] {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
            if case let .string(value)? = object["groupType"] {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
            if entityType == "group" {
                return publishDefaults.groupType.isEmpty ? "selskap" : publishDefaults.groupType
            }
            return nil
        }()

        let selected = selectedMatchingSuggestion()
        let purpose: String = {
            if case let .string(value)? = object["purpose"], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return selected?.purpose ?? "Unknown Purpose"
        }()
        let note: String? = {
            if case let .string(value)? = object["note"] {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
            return publishDefaults.note.isEmpty ? nil : publishDefaults.note
        }()

        let publication = PublishedEntityPurpose(
            id: UUID().uuidString,
            entityName: entityName,
            entityType: entityType,
            entitySubtype: entitySubtype,
            purpose: purpose,
            sourceSuggestionID: selected?.id,
            note: note,
            publishedAt: Date().timeIntervalSince1970
        )

        stateQueue.sync {
            matchingPublishedEntityPurposes.insert(publication, at: 0)
            if matchingPublishedEntityPurposes.count > 100 {
                matchingPublishedEntityPurposes = Array(matchingPublishedEntityPurposes.prefix(100))
            }
        }

        var flow = FlowElement(
            title: "purpose.entity.published",
            content: .object(publication.asObject()),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flow.topic = "purpose.entity.publications"
        flow.origin = uuid
        pushFlowElement(flow, requester: requester)

        return .object([
            "status": .string("published"),
            "publication": .object(publication.asObject()),
            "publications": matchingEntityPurposePublicationsValue(),
            "state": matchingStateValue()
        ])
    }

    private func clearMatchingSuggestions() -> ValueType {
        stateQueue.sync {
            matchingSuggestions = []
            matchingSelectedIndex = -1
        }
        return .object([
            "status": .string("cleared"),
            "state": matchingStateValue()
        ])
    }

    private func deriveMatchingQuery(from prompt: String) -> (purpose: String?, interests: [String]) {
        let lower = prompt.lowercased()
        var interests = Set<String>()
        var purpose: String?

        if lower.contains("chat") || lower.contains("venn") || lower.contains("melding") || lower.contains("snakk") {
            purpose = "Kommunikasjon og samarbeid"
            interests.formUnion(["chat", "communication", "collaboration"])
        }
        if lower.contains("ai") || lower.contains("personvern") || lower.contains("privacy") || lower.contains("konfer") || lower.contains("conference") {
            if purpose == nil { purpose = "Tidslinje og planlegging" }
            interests.formUnion(["ai", "privacy", "conference", "events"])
        }
        if lower.contains("asiat") || lower.contains("spicy") || lower.contains("restaurant") || lower.contains("mat") || lower.contains("frisk") {
            if purpose == nil { purpose = "Stedsbevissthet" }
            interests.formUnion(["location", "restaurant", "maps", "presence"])
        }
        if lower.contains("lignende") || lower.contains("interesser") || lower.contains("personer") || lower.contains("nettverk") {
            if purpose == nil { purpose = "Entitetsoversikt" }
            interests.formUnion(["entities", "network", "people"])
        }

        if interests.isEmpty {
            let tokens = lower.split { !$0.isLetter && !$0.isNumber }.map(String.init)
            for token in tokens where token.count > 2 {
                interests.insert(token)
                if interests.count >= 6 { break }
            }
        }

        return (purpose, Array(interests).sorted())
    }

    private func matchConfigurationsDetailed(
        purpose: String?,
        interests: [String]?,
        menuSlot: MenuSlot?,
        limit: Int?
    ) -> [DetailedCatalogMatch] {
        let normalizedPurpose = purpose?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedInterestSet: Set<String> = Set((interests ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty })
        let purposeStats: [String: PurposeUsageStat] = stateQueue.sync {
            matchingPurposeStatsByPurpose.values.reduce(into: [:]) { partialResult, stat in
                partialResult[stat.purpose.lowercased()] = stat
            }
        }
        let isBroadQuery = (normalizedPurpose == nil || normalizedPurpose?.isEmpty == true) && normalizedInterestSet.isEmpty

        let scored: [DetailedCatalogMatch] = sortedEntries()
            .filter { entry in
                if let menuSlot {
                    return entry.menuSlots.contains(menuSlot)
                }
                return true
            }
            .compactMap { entry in
                var score = 0.0
                var reasons: [String] = []
                let entryPurposeLower = entry.purpose.lowercased()
                let entryNameLower = entry.configuration.name.lowercased()
                let entryDescriptionLower = (entry.purposeDescription ?? entry.configuration.description ?? "").lowercased()

                if let normalizedPurpose, !normalizedPurpose.isEmpty {
                    if entryPurposeLower == normalizedPurpose {
                        score += 2.8
                        reasons.append("Direkte formaal-treff.")
                    } else if entryPurposeLower.contains(normalizedPurpose) {
                        score += 2.1
                        reasons.append("Formaal matcher delvis.")
                    } else if normalizedPurpose.contains(entryPurposeLower), entryPurposeLower.count >= 4 {
                        score += 1.4
                        reasons.append("Konfigurasjonens formaal dekker forespurt tema.")
                    }

                    if entryNameLower.contains(normalizedPurpose) {
                        score += 0.8
                        reasons.append("Navn matcher formaal.")
                    }
                    if entryDescriptionLower.contains(normalizedPurpose) {
                        score += 0.6
                        reasons.append("Beskrivelse matcher formaal.")
                    }
                }

                var overlapInterests: [String] = []
                if !normalizedInterestSet.isEmpty {
                    let entryInterestsLower = Set(entry.interests.map { $0.lowercased() })
                    let overlap = normalizedInterestSet.intersection(entryInterestsLower)
                    overlapInterests = overlap.sorted()
                    if !overlapInterests.isEmpty {
                        let ratio = Double(overlapInterests.count) / Double(normalizedInterestSet.count)
                        score += 2.4 * ratio
                        reasons.append("Interessematch: \(overlapInterests.joined(separator: ", ")).")
                    } else {
                        reasons.append("Ingen direkte interesse-overlapp.")
                    }
                }

                if entry.configuration.skeleton != nil {
                    score += 0.55
                    reasons.append("Har skeleton og kan lastes direkte i Porthole.")
                } else {
                    score += 0.1
                    reasons.append("Ingen skeleton i konfigurasjonen.")
                }

                if let stat = purposeStats[entry.purpose.lowercased()] {
                    let learnedBoost = min(1.5, (stat.effectiveness * 1.0) + (stat.currentWeight * 0.2))
                    if learnedBoost > 0 {
                        score += learnedBoost
                        let effectivenessPercent = Int((stat.effectiveness * 100.0).rounded())
                        reasons.append("Historikk: \(effectivenessPercent)% maaloppnaaelse for dette formaalet.")
                    }
                }

                if isBroadQuery {
                    score += 0.2
                    reasons.append("Bredt soek - rangerer etter generell egnethet.")
                }

                if !isBroadQuery && score <= 0.0 {
                    return nil
                }

                return DetailedCatalogMatch(
                    entry: entry,
                    score: score,
                    overlapInterests: overlapInterests,
                    reasons: reasons
                )
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.entry.configuration.name.localizedCaseInsensitiveCompare(rhs.entry.configuration.name) == .orderedAscending
                }
                return lhs.score > rhs.score
            }

        if let limit {
            return Array(scored.prefix(limit))
        }
        return scored
    }

    private func matchConfigurations(
        purpose: String?,
        interests: [String]?,
        menuSlot: MenuSlot?,
        limit: Int?
    ) -> [CatalogEntry] {
        matchConfigurationsDetailed(
            purpose: purpose,
            interests: interests,
            menuSlot: menuSlot,
            limit: limit
        ).map(\.entry)
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
            let existingMatch = sortedEntries().first {
                $0.sourceCellEndpoint == template.sourceCellEndpoint && $0.purpose == template.purpose
            }

            var payload = CatalogPayload(
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

            let shouldRefreshExisting = template.forceRefreshExisting && existingMatch != nil
            if shouldRefreshExisting, let existingID = existingMatch?.id {
                payload.id = existingID
            }

            if existingMatch == nil || shouldRefreshExisting {
                _ = upsert(from: payload, keepExistingIDWhenMissing: true)
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
                if let missingHost = missingRemoteHostRoute(for: endpoint, resolver: resolver) {
                    await reportMissingEndpoint(
                        endpoint: endpoint,
                        operation: "syncScaffoldPurposeGoals",
                        message: "Missing remote host route for '\(missingHost)'. Register with resolver.registerRemoteCellHost(host:route:).",
                        requester: requester
                    )
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

    private func missingRemoteHostRoute(for endpoint: String, resolver: CellResolverProtocol) -> String? {
        guard let url = URL(string: endpoint) else { return nil }
        guard url.scheme == "cell" else { return nil }
        guard let host = url.host?.trimmingCharacters(in: .whitespacesAndNewlines), !host.isEmpty else { return nil }
        if host.lowercased() == "localhost" { return nil }

        let routes = resolver.remoteCellHostRoutesSnapshot()
        let normalizedHost = host.lowercased()
        return routes[normalizedHost] == nil ? host : nil
    }

    private func shouldSkipResolverLookup(for endpoint: String) -> Bool {
        guard let url = URL(string: endpoint) else { return false }
        let pathName = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        return pathName == "configurationcatalog" || pathName == "appleintelligence"
    }

    private func clearCatalogError(for endpoint: String) {
        _ = stateQueue.sync {
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
        let agreementWorkbench = agreementTemplateWorkbenchConfiguration()
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
                sourceCellEndpoint: "cell:///ConfigurationCatalog",
                sourceCellName: "ConfigurationCatalogCell",
                purpose: "Agreement template styring",
                purposeDescription: "Preview og apply av agreementTemplate med non-compliant policy og signering.",
                interests: ["agreement", "contract", "access", "signcontract"],
                menuSlots: [.lowerRight],
                goal: agreementWorkbench,
                configuration: agreementWorkbench
            ),
            ScaffoldPurposeTemplate(
                sourceCellEndpoint: "cell:///AppleIntelligence",
                sourceCellName: "AppleIntelligenceCell",
                purpose: "Formål landing",
                purposeDescription: "Landingsside som hjelper brukeren å finne retning og fylle appen med mening.",
                interests: ["purpose", "assistant", "onboarding", "explore"],
                menuSlots: [.upperMid, .upperRight],
                goal: purposeLanding,
                configuration: purposeLanding,
                forceRefreshExisting: true
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

        var startButton = SkeletonButton(keypath: "signals.start", label: "Start", payload: .bool(true))
        startButton.modifiers = modifier {
            $0.padding = 10
            $0.background = "#DCFCE7"
            $0.borderWidth = 1
            $0.borderColor = "#16A34A"
            $0.cornerRadius = 10
        }

        var stopButton = SkeletonButton(keypath: "signals.stop", label: "Stop", payload: .bool(true))
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

        var signalRowValue = SkeletonText(keypath: "content.key")
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
        incomingSignals.filterTypes = ["content"]
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

        var eventOperation = SkeletonText(keypath: "content.operation")
        eventOperation.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var eventCount = SkeletonText(keypath: "content.state.count")
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
        catalogEvents.filterTypes = ["event"]
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

    private static func agreementTemplateWorkbenchConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Agreement Template Workbench")
        configuration.description = "Preview/apply av agreementTemplate, signering og non-compliant policy."

        var catalogRef = CellReference(endpoint: "cell:///ConfigurationCatalog", label: "catalog")
        catalogRef.subscribeFeed = true
        configuration.addReference(catalogRef)

        var title = SkeletonText(text: "Agreement Template Workbench")
        title.modifiers = modifier {
            $0.fontStyle = "title3"
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var subtitle = SkeletonText(text: "Capability-basert tilgang, preview/apply og signContract-flyt.")
        subtitle.modifiers = modifier {
            $0.foregroundColor = "#334155"
        }

        var readState = SkeletonButton(keypath: "catalog.agreementTemplate.state", label: "Les state")
        readState.modifiers = modifier {
            $0.padding = 10
            $0.background = "#E2E8F0"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#64748B"
        }

        let defaultTemplate: Object = [
            "description": .string("Drafted in Agreement Template Workbench"),
            "requiresAllPartiesSignature": .bool(true),
            "capabilities": .list([
                .string("agreementTemplate.read"),
                .string("agreementTemplate.write"),
                .string("agreementTemplate.apply.newConnections"),
                .string("agreementTemplate.apply.reEvaluateExisting"),
                .string("agreementTemplate.contracts.enforce"),
                .string("agreementTemplate.access.manage")
            ])
        ]

        var previewNew = SkeletonButton(
            keypath: "catalog.agreementTemplate.preview",
            label: "Preview (new)",
            payload: .object([
                "rolloutMode": .string("new_connections_only"),
                "template": .object(defaultTemplate)
            ])
        )
        previewNew.modifiers = modifier {
            $0.padding = 10
            $0.background = "#DBEAFE"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#2563EB"
        }

        var applyNew = SkeletonButton(
            keypath: "catalog.agreementTemplate.apply",
            label: "Apply (new)",
            payload: .object([
                "rolloutMode": .string("new_connections_only"),
                "template": .object(defaultTemplate),
                "requiresAllPartiesSignature": .bool(true)
            ])
        )
        applyNew.modifiers = modifier {
            $0.padding = 10
            $0.background = "#DCFCE7"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#16A34A"
        }

        var applyReEvaluate = SkeletonButton(
            keypath: "catalog.agreementTemplate.apply",
            label: "Apply + re-eval",
            payload: .object([
                "rolloutMode": .string("re_evaluate_existing"),
                "forceSignContract": .bool(true),
                "evictIfNonCompliant": .bool(false),
                "template": .object(defaultTemplate)
            ])
        )
        applyReEvaluate.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FEF3C7"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#D97706"
        }

        var signCurrent = SkeletonButton(
            keypath: "catalog.agreements.sign",
            label: "Sign current",
            payload: .object(["signature": .string("accepted")])
        )
        signCurrent.modifiers = modifier {
            $0.padding = 10
            $0.background = "#ECFCCB"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#65A30D"
        }

        var reportNonCompliant = SkeletonButton(
            keypath: "catalog.agreements.nonCompliant.report",
            label: "Report non-compliant",
            payload: .object([
                "reason": .string("Possible conflict with previously signed agreement"),
                "evidenceRef": .string("agreement://previous")
            ])
        )
        reportNonCompliant.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FEE2E2"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#DC2626"
        }

        var setPolicy = SkeletonButton(
            keypath: "catalog.agreements.nonCompliant.policy",
            label: "Policy: auto request resign",
            payload: .object(["policy": .string("auto_request_resign")])
        )
        setPolicy.modifiers = modifier {
            $0.padding = 10
            $0.background = "#EDE9FE"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#7C3AED"
        }

        var historyId = SkeletonText(keypath: "agreementId")
        historyId.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var historyStatus = SkeletonText(keypath: "status")
        historyStatus.modifiers = modifier {
            $0.foregroundColor = "#334155"
        }

        var historyMode = SkeletonText(keypath: "rolloutMode")
        historyMode.modifiers = modifier {
            $0.foregroundColor = "#64748B"
            $0.fontSize = 12
        }

        var historyRow = SkeletonVStack(elements: [
            .Text(historyId),
            .Text(historyStatus),
            .Text(historyMode)
        ])
        historyRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#F8FAFC"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#E2E8F0"
        }

        var agreementHistory = SkeletonList(topic: nil, keypath: "catalog.agreements.history", flowElementSkeleton: historyRow)
        agreementHistory.modifiers = modifier {
            $0.padding = 4
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        var auditAction = SkeletonText(keypath: "action")
        auditAction.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var auditActor = SkeletonText(keypath: "actorIdentityKey")
        auditActor.modifiers = modifier {
            $0.foregroundColor = "#475569"
        }

        var auditRow = SkeletonVStack(elements: [
            .Text(auditAction),
            .Text(auditActor)
        ])
        auditRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#FFFFFF"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#E2E8F0"
        }

        var auditLog = SkeletonList(topic: nil, keypath: "catalog.agreementTemplate.auditLog", flowElementSkeleton: auditRow)
        auditLog.modifiers = modifier {
            $0.padding = 4
            $0.background = "#F8FAFC"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        var eventAction = SkeletonText(keypath: "content.action")
        eventAction.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var eventAgreement = SkeletonText(keypath: "content.agreementId")
        eventAgreement.modifiers = modifier {
            $0.foregroundColor = "#64748B"
            $0.fontSize = 12
        }

        var eventRow = SkeletonVStack(elements: [
            .Text(eventAction),
            .Text(eventAgreement)
        ])
        eventRow.modifiers = modifier {
            $0.padding = 10
            $0.background = "#F8FAFC"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#E2E8F0"
        }

        var events = SkeletonList(topic: "agreements", keypath: nil, flowElementSkeleton: eventRow)
        events.filterTypes = ["event"]
        events.modifiers = modifier {
            $0.padding = 4
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        var root = SkeletonVStack(elements: [
            .Text(title),
            .Text(subtitle),
            .HStack(SkeletonHStack(elements: [.Button(readState), .Button(previewNew), .Button(applyNew)])),
            .HStack(SkeletonHStack(elements: [.Button(applyReEvaluate), .Button(signCurrent)])),
            .HStack(SkeletonHStack(elements: [.Button(reportNonCompliant), .Button(setPolicy)])),
            .Text(SkeletonText(text: "Agreement history")),
            .List(agreementHistory),
            .Text(SkeletonText(text: "Audit log")),
            .List(auditLog),
            .Text(SkeletonText(text: "Agreement events")),
            .List(events)
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
        var configuration = CellConfiguration(name: "Apple Intelligence Purpose Matcher")
        configuration.description = "Prompt-til-match med tydelig forklaring, skeleton preview, lasting i Porthole, laering og publisering av formaal."

        var catalogReference = CellReference(endpoint: "cell:///ConfigurationCatalog", label: "catalog")
        catalogReference.subscribeFeed = false
        configuration.addReference(catalogReference)

        let sectionCard = modifier {
            $0.padding = 6
            $0.background = "#FFFFFF"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        let listLarge = modifier {
            $0.padding = 6
            $0.background = "#FFFFFF"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#BFD1E4"
            $0.height = 220
        }

        let listMedium = modifier {
            $0.padding = 6
            $0.background = "#FFFFFF"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#C8D5E6"
            $0.height = 140
        }

        let listSmall = modifier {
            $0.padding = 6
            $0.background = "#FFFFFF"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#C8D5E6"
            $0.height = 96
        }

        let neutralButton = modifier {
            $0.padding = 6
            $0.background = "#EDF2F7"
            $0.borderWidth = 1
            $0.borderColor = "#B7C5D6"
            $0.cornerRadius = 8
        }

        let primaryButton = modifier {
            $0.padding = 6
            $0.background = "#DBEAFE"
            $0.borderWidth = 1
            $0.borderColor = "#60A5FA"
            $0.cornerRadius = 8
        }

        let successButton = modifier {
            $0.padding = 6
            $0.background = "#DCFCE7"
            $0.borderWidth = 1
            $0.borderColor = "#4ADE80"
            $0.cornerRadius = 8
        }

        let warningButton = modifier {
            $0.padding = 6
            $0.background = "#FEF3C7"
            $0.borderWidth = 1
            $0.borderColor = "#F59E0B"
            $0.cornerRadius = 8
        }

        let inputModifier = modifier {
            $0.padding = 7
            $0.background = "#F8FAFC"
            $0.cornerRadius = 8
            $0.borderWidth = 1
            $0.borderColor = "#D3DEEB"
        }

        var title = SkeletonText(text: "Apple Intelligence: Purpose matcher")
        title.modifiers = modifier {
            $0.fontStyle = "headline"
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var intro = SkeletonText(text: "Tools-match pa purpose/interests. Treff viser hvorfor de passer, om skeleton finnes, og kan lastes direkte i Porthole.")
        intro.modifiers = modifier {
            $0.foregroundColor = "#334155"
            $0.fontSize = 12
            $0.lineLimit = 2
        }

        let promptField = SkeletonTextField(
            text: nil,
            sourceKeypath: "catalog.matching.promptText",
            targetKeypath: "catalog.matching.promptText",
            placeholder: "Skriv brukerprompt...",
            modifiers: inputModifier
        )

        let selectedIndexField = SkeletonTextField(
            text: nil,
            sourceKeypath: "catalog.matching.selectedIndex",
            targetKeypath: "catalog.matching.selectedIndex",
            placeholder: "Velg forslag med indeks (0..n)",
            modifiers: inputModifier
        )

        var runMatching = SkeletonButton(keypath: "catalog.matching.runPrompt", label: "Kjor matching", payload: .string(""))
        runMatching.modifiers = primaryButton

        var clearMatching = SkeletonButton(keypath: "catalog.matching.clear", label: "Nullstill", payload: .bool(true))
        clearMatching.modifiers = neutralButton

        var syncCandidates = SkeletonButton(
            keypath: "catalog.syncScaffoldPurposeGoals",
            label: "Sync kandidater",
            payload: .bool(true)
        )
        syncCandidates.modifiers = neutralButton

        var quickChat = SkeletonButton(
            keypath: "catalog.matching.runPrompt",
            label: "Chatte med venn",
            payload: .object(["prompt": .string("jeg skal chatte med en venn")])
        )
        quickChat.modifiers = neutralButton

        var quickConference = SkeletonButton(
            keypath: "catalog.matching.runPrompt",
            label: "AI + personvern konferanser",
            payload: .object(["prompt": .string("jeg vil laere om ai og personvern, hvilke konferanser boer jeg melde meg paa?")])
        )
        quickConference.modifiers = neutralButton

        var quickRestaurant = SkeletonButton(
            keypath: "catalog.matching.runPrompt",
            label: "Asiatisk, frisk, spicy",
            payload: .object(["prompt": .string("jeg kan tenke meg noe asiatisk, friskt og spicy i dag hvilke restauranter boer jeg se paa?")])
        )
        quickRestaurant.modifiers = neutralButton

        var quickPeople = SkeletonButton(
            keypath: "catalog.matching.runPrompt",
            label: "Lignende interesser",
            payload: .object(["prompt": .string("jeg har lyst til aa finne andre som har lignende interesser som meg")])
        )
        quickPeople.modifiers = neutralButton

        var suggestionName = SkeletonText(keypath: "name")
        suggestionName.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var suggestionPurpose = SkeletonText(keypath: "purpose")
        suggestionPurpose.modifiers = modifier {
            $0.foregroundColor = "#1E3A8A"
            $0.fontSize = 12
        }

        var suggestionMeaning = SkeletonText(keypath: "matchMeaning")
        suggestionMeaning.modifiers = modifier {
            $0.foregroundColor = "#334155"
            $0.fontSize = 12
            $0.lineLimit = 2
        }

        var suggestionOverlap = SkeletonText(keypath: "overlapSummary")
        suggestionOverlap.modifiers = modifier {
            $0.foregroundColor = "#475569"
            $0.fontSize = 11
            $0.lineLimit = 1
        }

        var suggestionScore = SkeletonText(keypath: "scoreAndSkeleton")
        suggestionScore.modifiers = modifier {
            $0.foregroundColor = "#0F766E"
            $0.fontSize = 11
            $0.lineLimit = 1
        }

        var suggestionEndpoint = SkeletonText(keypath: "primaryEndpoint")
        suggestionEndpoint.modifiers = modifier {
            $0.foregroundColor = "#64748B"
            $0.fontSize = 11
            $0.lineLimit = 1
        }

        var suggestionRow = SkeletonVStack(elements: [
            .Text(suggestionName),
            .Text(suggestionPurpose),
            .Text(suggestionMeaning),
            .Text(suggestionOverlap),
            .Text(suggestionScore),
            .Text(suggestionEndpoint)
        ])
        suggestionRow.modifiers = modifier {
            $0.padding = 6
            $0.background = "#FFFFFF"
            $0.cornerRadius = 8
            $0.borderWidth = 1
            $0.borderColor = "#D3DEEB"
        }

        var suggestionList = SkeletonList(topic: "catalog.matching.suggestions", keypath: "catalog.matching.suggestions", flowElementSkeleton: suggestionRow)
        suggestionList.modifiers = listLarge

        var selectedName = SkeletonText(keypath: "name")
        selectedName.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var selectedPurpose = SkeletonText(keypath: "purpose")
        selectedPurpose.modifiers = modifier {
            $0.foregroundColor = "#1E3A8A"
            $0.fontSize = 12
        }

        var selectedMeaning = SkeletonText(keypath: "matchMeaning")
        selectedMeaning.modifiers = modifier {
            $0.foregroundColor = "#334155"
            $0.fontSize = 12
            $0.lineLimit = 2
        }

        var selectedSkeletonStatus = SkeletonText(keypath: "skeletonStatus")
        selectedSkeletonStatus.modifiers = modifier {
            $0.foregroundColor = "#0F766E"
            $0.fontSize = 11
            $0.lineLimit = 1
        }

        var selectedSkeletonPreview = SkeletonText(keypath: "skeletonPreview")
        selectedSkeletonPreview.modifiers = modifier {
            $0.foregroundColor = "#64748B"
            $0.fontSize = 11
            $0.lineLimit = 2
        }

        var selectedRow = SkeletonVStack(elements: [
            .Text(selectedName),
            .Text(selectedPurpose),
            .Text(selectedMeaning),
            .Text(selectedSkeletonStatus),
            .Text(selectedSkeletonPreview)
        ])
        selectedRow.modifiers = modifier {
            $0.padding = 6
            $0.background = "#FFFFFF"
            $0.cornerRadius = 8
            $0.borderWidth = 1
            $0.borderColor = "#C9D8EC"
        }

        var selectedSuggestion = SkeletonList(topic: "catalog.matching.selectedSuggestion", keypath: "catalog.matching.selectedSuggestion", flowElementSkeleton: selectedRow)
        selectedSuggestion.modifiers = listMedium

        var purposeStatPurpose = SkeletonText(keypath: "purpose")
        purposeStatPurpose.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var purposeStatUsage = SkeletonText(keypath: "usageSummary")
        purposeStatUsage.modifiers = modifier {
            $0.foregroundColor = "#334155"
            $0.fontSize = 12
        }

        var purposeStatEffectiveness = SkeletonText(keypath: "effectivenessPercent")
        purposeStatEffectiveness.modifiers = modifier {
            $0.foregroundColor = "#15803D"
            $0.fontSize = 11
        }

        var purposeStatWeight = SkeletonText(keypath: "weightLabel")
        purposeStatWeight.modifiers = modifier {
            $0.foregroundColor = "#0F766E"
            $0.fontSize = 11
        }

        var purposeStatRow = SkeletonVStack(elements: [
            .Text(purposeStatPurpose),
            .Text(purposeStatUsage),
            .Text(purposeStatEffectiveness),
            .Text(purposeStatWeight)
        ])
        purposeStatRow.modifiers = modifier {
            $0.padding = 6
            $0.background = "#FFFFFF"
            $0.cornerRadius = 8
            $0.borderWidth = 1
            $0.borderColor = "#D9E6C7"
        }

        var purposeStatsList = SkeletonList(topic: "catalog.matching.purposeStats", keypath: "catalog.matching.purposeStats", flowElementSkeleton: purposeStatRow)
        purposeStatsList.modifiers = listMedium

        var outcomeEventTitle = SkeletonText(keypath: "title")
        outcomeEventTitle.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
            $0.fontSize = 12
        }

        var outcomeEventPurpose = SkeletonText(keypath: "content.purpose")
        outcomeEventPurpose.modifiers = modifier {
            $0.foregroundColor = "#1E3A8A"
            $0.fontSize = 12
        }

        var outcomeEventGoal = SkeletonText(keypath: "content.achievedGoal")
        outcomeEventGoal.modifiers = modifier {
            $0.foregroundColor = "#15803D"
            $0.fontSize = 11
        }

        var outcomeEventWeight = SkeletonText(keypath: "content.currentWeight")
        outcomeEventWeight.modifiers = modifier {
            $0.foregroundColor = "#0F766E"
            $0.fontSize = 11
        }

        var outcomeEventRow = SkeletonVStack(elements: [
            .Text(outcomeEventTitle),
            .Text(outcomeEventPurpose),
            .Text(outcomeEventGoal),
            .Text(outcomeEventWeight)
        ])
        outcomeEventRow.modifiers = modifier {
            $0.padding = 6
            $0.background = "#FFFFFF"
            $0.cornerRadius = 8
            $0.borderWidth = 1
            $0.borderColor = "#D9E6C7"
        }

        var purposeOutcomeEventsList = SkeletonList(topic: "purpose.outcome", keypath: nil, flowElementSkeleton: outcomeEventRow)
        purposeOutcomeEventsList.filterTypes = ["event"]
        purposeOutcomeEventsList.modifiers = listSmall

        var publicationEntity = SkeletonText(keypath: "entityName")
        publicationEntity.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
        }

        var publicationType = SkeletonText(keypath: "entityTypeLabel")
        publicationType.modifiers = modifier {
            $0.foregroundColor = "#334155"
            $0.fontSize = 12
        }

        var publicationPurpose = SkeletonText(keypath: "purpose")
        publicationPurpose.modifiers = modifier {
            $0.foregroundColor = "#1E3A8A"
            $0.fontSize = 12
        }

        var publicationMeaning = SkeletonText(keypath: "meaning")
        publicationMeaning.modifiers = modifier {
            $0.foregroundColor = "#475569"
            $0.fontSize = 11
            $0.lineLimit = 1
        }

        var publicationRow = SkeletonVStack(elements: [
            .Text(publicationEntity),
            .Text(publicationType),
            .Text(publicationPurpose),
            .Text(publicationMeaning)
        ])
        publicationRow.modifiers = modifier {
            $0.padding = 6
            $0.background = "#FFFFFF"
            $0.cornerRadius = 8
            $0.borderWidth = 1
            $0.borderColor = "#E4D8F8"
        }

        var publicationList = SkeletonList(topic: "catalog.matching.entityPurposePublications", keypath: "catalog.matching.entityPurposePublications", flowElementSkeleton: publicationRow)
        publicationList.modifiers = listMedium

        var publicationEventTitle = SkeletonText(keypath: "title")
        publicationEventTitle.modifiers = modifier {
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#0F172A"
            $0.fontSize = 12
        }

        var publicationEventEntity = SkeletonText(keypath: "content.entityName")
        publicationEventEntity.modifiers = modifier {
            $0.foregroundColor = "#334155"
            $0.fontSize = 12
        }

        var publicationEventPurpose = SkeletonText(keypath: "content.purpose")
        publicationEventPurpose.modifiers = modifier {
            $0.foregroundColor = "#1E3A8A"
            $0.fontSize = 12
        }

        var publicationEventMeaning = SkeletonText(keypath: "content.meaning")
        publicationEventMeaning.modifiers = modifier {
            $0.foregroundColor = "#475569"
            $0.fontSize = 11
            $0.lineLimit = 1
        }

        var publicationEventRow = SkeletonVStack(elements: [
            .Text(publicationEventTitle),
            .Text(publicationEventEntity),
            .Text(publicationEventPurpose),
            .Text(publicationEventMeaning)
        ])
        publicationEventRow.modifiers = modifier {
            $0.padding = 6
            $0.background = "#FFFFFF"
            $0.cornerRadius = 8
            $0.borderWidth = 1
            $0.borderColor = "#E4D8F8"
        }

        var purposePublicationEventsList = SkeletonList(topic: "purpose.entity.publications", keypath: nil, flowElementSkeleton: publicationEventRow)
        purposePublicationEventsList.filterTypes = ["event"]
        purposePublicationEventsList.modifiers = listSmall

        var bookmarkList = SkeletonList(topic: "catalog.matching.bookmarks", keypath: "catalog.matching.bookmarks", flowElementSkeleton: suggestionRow)
        bookmarkList.modifiers = listSmall

        var loadSelected = SkeletonButton(keypath: "catalog.matching.loadSelectedToPorthole", label: "Load valgt i Porthole", payload: .bool(true))
        loadSelected.modifiers = primaryButton

        var markSelectedUsed = SkeletonButton(keypath: "catalog.matching.markSelectedUsed", label: "Marker brukt", payload: .bool(true))
        markSelectedUsed.modifiers = neutralButton

        var markGoalAchieved = SkeletonButton(keypath: "catalog.matching.markSelectedGoalAchieved", label: "Maal oppnaadd", payload: .bool(true))
        markGoalAchieved.modifiers = successButton

        var bookmarkSelected = SkeletonButton(keypath: "catalog.matching.bookmarkSelected", label: "Bokmerk valgt", payload: .bool(true))
        bookmarkSelected.modifiers = neutralButton

        var saveSelectedUpperMid = SkeletonButton(
            keypath: "catalog.matching.saveSelectedToMenu",
            label: "Lagre i upperMid",
            payload: .object(["menuSlot": .string("upperMid")])
        )
        saveSelectedUpperMid.modifiers = warningButton

        var saveSelectedLowerMid = SkeletonButton(
            keypath: "catalog.matching.saveSelectedToMenu",
            label: "Lagre i lowerMid",
            payload: .object(["menuSlot": .string("lowerMid")])
        )
        saveSelectedLowerMid.modifiers = warningButton

        let publishPersonName = SkeletonTextField(
            text: nil,
            sourceKeypath: "catalog.matching.publish.personName",
            targetKeypath: "catalog.matching.publish.personName",
            placeholder: "Personnavn",
            modifiers: inputModifier
        )

        let publishGroupName = SkeletonTextField(
            text: nil,
            sourceKeypath: "catalog.matching.publish.groupName",
            targetKeypath: "catalog.matching.publish.groupName",
            placeholder: "Gruppenavn / selskap / butikk",
            modifiers: inputModifier
        )

        let publishGroupType = SkeletonTextField(
            text: nil,
            sourceKeypath: "catalog.matching.publish.groupType",
            targetKeypath: "catalog.matching.publish.groupType",
            placeholder: "Gruppetype (selskap, butikk, team...)",
            modifiers: inputModifier
        )

        let publishNote = SkeletonTextField(
            text: nil,
            sourceKeypath: "catalog.matching.publish.note",
            targetKeypath: "catalog.matching.publish.note",
            placeholder: "Notat om hvorfor formaalet passer",
            modifiers: inputModifier
        )

        var publishPersonPurpose = SkeletonButton(
            keypath: "catalog.matching.publishEntityPurpose",
            label: "Publiser formaal for person",
            payload: .object(["entityType": .string("person")])
        )
        publishPersonPurpose.modifiers = neutralButton

        var publishGroupPurpose = SkeletonButton(
            keypath: "catalog.matching.publishEntityPurpose",
            label: "Publiser formaal for gruppe",
            payload: .object(["entityType": .string("group")])
        )
        publishGroupPurpose.modifiers = neutralButton

        var sectionMatches = SkeletonText(text: "Treff fra Tools/Purpose/Interest matching")
        sectionMatches.modifiers = modifier {
            $0.foregroundColor = "#0F172A"
            $0.fontWeight = "semibold"
            $0.fontSize = 12
        }

        var sectionSelected = SkeletonText(text: "Valgt forslag (lastbar CellConfiguration med skeleton)")
        sectionSelected.modifiers = modifier {
            $0.foregroundColor = "#0F172A"
            $0.fontWeight = "semibold"
            $0.fontSize = 12
        }

        var sectionLearning = SkeletonText(text: "Formaal-laering (maaloppnaaelse teller mest)")
        sectionLearning.modifiers = modifier {
            $0.foregroundColor = "#0F172A"
            $0.fontWeight = "semibold"
            $0.fontSize = 12
        }

        var sectionOutcomeEvents = SkeletonText(text: "Flow events (topic: purpose.outcome)")
        sectionOutcomeEvents.modifiers = modifier {
            $0.foregroundColor = "#334155"
            $0.fontWeight = "semibold"
            $0.fontSize = 11
        }

        var sectionPublish = SkeletonText(text: "Publiser formaal for personer og grupper")
        sectionPublish.modifiers = modifier {
            $0.foregroundColor = "#0F172A"
            $0.fontWeight = "semibold"
            $0.fontSize = 12
        }

        var sectionPublicationEvents = SkeletonText(text: "Flow events (topic: purpose.entity.publications)")
        sectionPublicationEvents.modifiers = modifier {
            $0.foregroundColor = "#334155"
            $0.fontWeight = "semibold"
            $0.fontSize = 11
        }

        var sectionBookmarks = SkeletonText(text: "Bokmerker")
        sectionBookmarks.modifiers = modifier {
            $0.foregroundColor = "#0F172A"
            $0.fontWeight = "semibold"
            $0.fontSize = 12
        }

        var root = SkeletonVStack(elements: [
            .Text(title),
            .Text(intro),
            .TextField(promptField),
            .HStack(SkeletonHStack(elements: [.Button(runMatching), .Button(syncCandidates)])),
            .HStack(SkeletonHStack(elements: [.Button(clearMatching)])),
            .HStack(SkeletonHStack(elements: [.Button(quickChat), .Button(quickConference)])),
            .HStack(SkeletonHStack(elements: [.Button(quickRestaurant), .Button(quickPeople)])),
            .TextField(selectedIndexField),
            .Text(sectionMatches),
            .List(suggestionList),
            .Text(sectionSelected),
            .List(selectedSuggestion),
            .HStack(SkeletonHStack(elements: [.Button(loadSelected), .Button(markSelectedUsed)])),
            .HStack(SkeletonHStack(elements: [.Button(markGoalAchieved), .Button(bookmarkSelected)])),
            .HStack(SkeletonHStack(elements: [.Button(saveSelectedUpperMid), .Button(saveSelectedLowerMid)])),
            .Text(sectionLearning),
            .List(purposeStatsList),
            .Text(sectionOutcomeEvents),
            .List(purposeOutcomeEventsList),
            .Text(sectionPublish),
            .TextField(publishPersonName),
            .TextField(publishGroupName),
            .TextField(publishGroupType),
            .TextField(publishNote),
            .HStack(SkeletonHStack(elements: [.Button(publishPersonPurpose), .Button(publishGroupPurpose)])),
            .Text(sectionPublicationEvents),
            .List(purposePublicationEventsList),
            .List(publicationList),
            .Text(sectionBookmarks),
            .List(bookmarkList)
        ])
        root.modifiers = modifier {
            $0.padding = 8
            $0.background = "#EEF5FB"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#C5D5E8"
            $0.maxWidthInfinity = true
        }

        var framedRoot = SkeletonVStack(elements: [.VStack(root)])
        framedRoot.modifiers = sectionCard

        var scroll = SkeletonScrollView(axis: "vertical", elements: [.VStack(framedRoot)])
        scroll.modifiers = modifier {
            $0.maxWidthInfinity = true
            $0.maxHeightInfinity = true
            $0.background = "#E7F0F9"
        }

        configuration.skeleton = .ScrollView(scroll)
        return configuration
    }

    private static func modifier(_ configure: (inout SkeletonModifiers) -> Void) -> SkeletonModifiers {
        var modifiers = SkeletonModifiers()
        configure(&modifiers)
        return modifiers
    }

    private func emitAgreementEvent(action: String, payload: Object, requester: Identity) async {
        var flowPayload = payload
        flowPayload["action"] = .string(action)
        flowPayload["state"] = stateValue()

        var flowElement = FlowElement(
            title: "agreement.\(action)",
            content: .object(flowPayload),
            properties: FlowElement.Properties(type: .event, contentType: .object)
        )
        flowElement.topic = "agreements"
        flowElement.origin = uuid

        if let owner = try? await getOwner(requester: requester) {
            pushFlowElement(flowElement, requester: owner)
        } else {
            pushFlowElement(flowElement, requester: requester)
        }
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
