// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import CellBase

/// Private, deterministic policy for the user-shaped Co-Pilot butler surface.
///
/// This type deliberately does not inspect raw chat history or invoke a model.
/// It consumes owner-selected preferences and small, allowlisted support signals.
nonisolated enum BindingPersonalButlerPolicy {
    static let schema = "binding.personal-butler.v1"
    static let supportDecisionSchema = "binding.personal-butler-support-decision.v1"
    static let syncPacketSchema = "binding.personal-butler-preference-sync.v1"
    static let defaultMinimumIntervalHours = 72
    static let syncPacketTTLSeconds: TimeInterval = 15 * 60

    static func initialState() -> Object {
        [
            "schema": .string(schema),
            "profile": .object([
                "displayName": .string("HAVEN Co-Pilot"),
                "styleGuidance": .string("Varm, tydelig og tilbakeholden. Spør før du gir råd."),
                "initiative": .string("reserved"),
                "source": .string("system_default"),
                "adaptationMode": .string("explicit_preferences_and_feedback_only"),
                "preferenceSignalsApplied": .integer(0),
                "retainsRawFeedback": .bool(false),
                "summary": .string("Standardprofil. Du kan gi butleren navn og justere stilen selv."),
                "updatedAt": .null
            ]),
            "capabilities": .object([
                "status": .string("not_refreshed"),
                "functionalLevel": .string("guided_local"),
                "helperCount": .integer(0),
                "providerDescriptorCount": .integer(0),
                "modelProviderDescriptorCount": .integer(0),
                "externalProviderDescriptorCount": .integer(0),
                "contextStatus": .string("idle"),
                "agentStatus": .string("unknown"),
                "summary": .string("Kapasiteten er ikke oppdatert ennå."),
                "transparencySummary": .string("Oppdatering leser bare lokale descriptors og starter ingen språkmodell."),
                "providers": .list([]),
                "providerInvoked": .bool(false),
                "derivedFromDescriptorsOnly": .bool(true),
                "requiresExplicitProviderAction": .bool(true)
            ]),
            "proactivity": .object([
                "enabled": .bool(false),
                "checkInsEnabled": .bool(false),
                "helpWhenBlockedEnabled": .bool(true),
                "adviceOffersEnabled": .bool(false),
                "minimumIntervalHours": .integer(defaultMinimumIntervalHours),
                "quietHoursEnabled": .bool(true),
                "quietHoursStart": .integer(22),
                "quietHoursEnd": .integer(8),
                "appLaunchEnabled": .bool(true),
                "taskCompletionEnabled": .bool(true),
                "userScheduleEnabled": .bool(false),
                "stagingWakeEnabled": .bool(false),
                "userScheduleKind": .string("weekdays"),
                "userScheduleLocalTime": .string("09:00"),
                "userScheduleWeekday": .integer(2),
                "lastScheduleSlot": .null,
                "lastOfferedAt": .null,
                "snoozedUntil": .null,
                "summary": .string("Proaktive innsjekker er av. Direkte spørsmål om hjelp virker fortsatt."),
                "contextPolicy": .string("owner-approved local signals only; no raw behavior log")
            ]),
            "sync": .object([
                "approved": .bool(false),
                "deviceID": .string(UUID().uuidString.lowercased()),
                "targetEndpoint": .string(""),
                "localRevision": .integer(0),
                "incomingRevisions": .object([:]),
                "lastExportedAt": .null,
                "lastImportedAt": .null,
                "lastStatus": .string("not_approved"),
                "allowedFields": .list([
                    "profile.displayName",
                    "profile.styleGuidance",
                    "proactivity.enabled",
                    "proactivity.checkInsEnabled",
                    "proactivity.helpWhenBlockedEnabled",
                    "proactivity.adviceOffersEnabled",
                    "proactivity.minimumIntervalHours",
                    "proactivity.quietHoursEnabled",
                    "proactivity.quietHoursStart",
                    "proactivity.quietHoursEnd",
                    "proactivity.appLaunchEnabled",
                    "proactivity.taskCompletionEnabled",
                    "proactivity.userScheduleEnabled",
                    "proactivity.stagingWakeEnabled",
                    "proactivity.userScheduleKind",
                    "proactivity.userScheduleLocalTime",
                    "proactivity.userScheduleWeekday"
                ].map(ValueType.string)),
                "summary": .string("Synk mellom enheter er av. Begge enheter må godkjennes av eieren."),
                "privacySummary": .string("Bare personlighet og kadansepreferanser kan synkes; chatthistorikk og atferdsdata er utelatt.")
            ]),
            "support": .object([
                "status": .string("idle"),
                "reason": .string("waiting_for_owner_or_allowed_signal"),
                "signalKind": .string("none"),
                "consecutiveLowConfidence": .integer(0),
                "message": .string(""),
                "summary": .string("Butleren venter til du spør eller har slått på forsiktige innsjekker."),
                "providerInvoked": .bool(false),
                "usesRawBehaviorLog": .bool(false),
                "lastDecisionAt": .null
            ]),
            "privacy": .object([
                "scope": .string("owner_private_chat_cell"),
                "rawBehaviorLogStored": .bool(false),
                "emotionInferenceAllowed": .bool(false),
                "healthInferenceAllowed": .bool(false),
                "relationshipInferenceAllowed": .bool(false),
                "externalModelDefault": .string("denied_until_explicit_user_approval"),
                "summary": .string("Personlighet bygges fra eksplisitte valg og enkel feedback, ikke skjult profilering.")
            ])
        ]
    }

    static func migratingState(_ current: Object?) -> Object {
        let defaults = initialState()
        guard let current else { return defaults }
        var migrated = defaults
        for key in ["profile", "capabilities", "proactivity", "support", "privacy", "sync"] {
            var section = BindingChatValue.object(defaults[key]) ?? [:]
            if let existing = BindingChatValue.object(current[key]) {
                for (field, value) in existing {
                    section[field] = value
                }
            }
            migrated[key] = .object(section)
        }
        migrated["schema"] = .string(schema)
        return migrated
    }

    static func updatingProfile(
        in current: Object,
        field: String,
        value: ValueType,
        now: Date = Date()
    ) -> Object {
        var butler = migratingState(current)
        var profile = BindingChatValue.object(butler["profile"])
            ?? BindingChatValue.object(initialState()["profile"])
            ?? [:]
        let raw = BindingChatValue.string(value)
            ?? BindingChatValue.string(BindingChatValue.object(value)?["value"])
            ?? ""

        switch field {
        case "displayName":
            let displayName = sanitizedText(raw, maximumLength: 40)
            profile["displayName"] = .string(displayName.isEmpty ? "HAVEN Co-Pilot" : displayName)
        case "styleGuidance":
            let style = sanitizedText(raw, maximumLength: 180)
            if style.isEmpty == false {
                profile["styleGuidance"] = .string(style)
            }
        default:
            return current
        }

        profile["source"] = .string("owner_selected")
        profile["updatedAt"] = .string(timestamp(now))
        profile["summary"] = .string(profileSummary(profile))
        butler["profile"] = .object(profile)
        markLocalPreferenceChange(in: &butler, now: now)
        return butler
    }

    static func applyingFeedback(
        to current: Object,
        value: ValueType,
        now: Date = Date()
    ) -> Object {
        let object = BindingChatValue.object(value) ?? [:]
        let signal = BindingChatValue.string(object["signal"])
            ?? BindingChatValue.string(value)
            ?? ""
        var butler = migratingState(current)
        var profile = BindingChatValue.object(butler["profile"])
            ?? BindingChatValue.object(initialState()["profile"])
            ?? [:]
        var proactivity = BindingChatValue.object(butler["proactivity"])
            ?? BindingChatValue.object(initialState()["proactivity"])
            ?? [:]

        switch signal {
        case "more_concise":
            profile["styleGuidance"] = .string("Kort og konkret, med ett tydelig neste steg om gangen.")
        case "more_warm":
            profile["styleGuidance"] = .string("Varm og støttende, men fortsatt tydelig og uten å overdrive.")
        case "more_direct":
            profile["styleGuidance"] = .string("Direkte og løsningsorientert. Si tydelig hva som mangler.")
        case "less_proactive":
            profile["initiative"] = .string("very_reserved")
            let currentInterval = Int(BindingChatValue.double(proactivity["minimumIntervalHours"]) ?? 72)
            proactivity["minimumIntervalHours"] = .integer(min(720, max(168, currentInterval * 2)))
        case "good_fit":
            break
        default:
            return current
        }

        let count = Int(BindingChatValue.double(profile["preferenceSignalsApplied"]) ?? 0) + 1
        profile["preferenceSignalsApplied"] = .integer(count)
        profile["retainsRawFeedback"] = .bool(false)
        profile["source"] = .string("owner_feedback")
        profile["updatedAt"] = .string(timestamp(now))
        profile["summary"] = .string(profileSummary(profile))
        proactivity["summary"] = .string(proactivitySummary(proactivity))
        butler["profile"] = .object(profile)
        butler["proactivity"] = .object(proactivity)
        markLocalPreferenceChange(in: &butler, now: now)
        return butler
    }

    static func configuringProactivity(
        in current: Object,
        value: ValueType,
        now: Date = Date()
    ) -> Object {
        let input = BindingChatValue.object(value) ?? [:]
        var butler = migratingState(current)
        var policy = BindingChatValue.object(butler["proactivity"])
            ?? BindingChatValue.object(initialState()["proactivity"])
            ?? [:]

        for key in [
            "enabled",
            "checkInsEnabled",
            "helpWhenBlockedEnabled",
            "adviceOffersEnabled",
            "quietHoursEnabled",
            "appLaunchEnabled",
            "taskCompletionEnabled",
            "userScheduleEnabled",
            "stagingWakeEnabled"
        ] {
            if let flag = BindingChatValue.bool(input[key]) {
                policy[key] = .bool(flag)
            }
        }
        if let hours = BindingChatValue.double(input["minimumIntervalHours"]) {
            policy["minimumIntervalHours"] = .integer(min(720, max(24, Int(hours))))
        }
        if let start = BindingChatValue.double(input["quietHoursStart"]) {
            policy["quietHoursStart"] = .integer(min(23, max(0, Int(start))))
        }
        if let end = BindingChatValue.double(input["quietHoursEnd"]) {
            policy["quietHoursEnd"] = .integer(min(23, max(0, Int(end))))
        }
        if let kind = BindingChatValue.string(input["userScheduleKind"]),
           ["daily", "weekdays", "weekly"].contains(kind) {
            policy["userScheduleKind"] = .string(kind)
        }
        if let localTime = BindingChatValue.string(input["userScheduleLocalTime"]),
           normalizedScheduleTime(localTime) != nil {
            policy["userScheduleLocalTime"] = .string(normalizedScheduleTime(localTime) ?? "09:00")
        }
        if let weekday = BindingChatValue.double(input["userScheduleWeekday"]) {
            policy["userScheduleWeekday"] = .integer(min(7, max(1, Int(weekday))))
        }
        policy["summary"] = .string(proactivitySummary(policy))
        butler["proactivity"] = .object(policy)
        markLocalPreferenceChange(in: &butler, now: now)
        return butler
    }

    static func updatingScheduleTime(
        in current: Object,
        value: ValueType,
        now: Date = Date()
    ) -> Object {
        let raw = BindingChatValue.string(value)
            ?? BindingChatValue.string(BindingChatValue.object(value)?["value"])
            ?? ""
        guard let localTime = normalizedScheduleTime(raw) else { return migratingState(current) }
        return configuringProactivity(
            in: current,
            value: .object(["userScheduleLocalTime": .string(localTime)]),
            now: now
        )
    }

    static func configuringSync(
        in current: Object,
        value: ValueType,
        now: Date = Date()
    ) -> Object {
        let input = BindingChatValue.object(value) ?? [:]
        var butler = migratingState(current)
        var sync = BindingChatValue.object(butler["sync"]) ?? [:]
        let requestedApproval = BindingChatValue.bool(input["approved"])
            ?? BindingChatValue.bool(input["enabled"])

        if requestedApproval == true {
            guard BindingChatValue.bool(input["confirm"]) == true else {
                sync["lastStatus"] = .string("approval_confirmation_required")
                sync["summary"] = .string("Synk er fortsatt av. Eieren må bekrefte godkjenningen eksplisitt.")
                butler["sync"] = .object(sync)
                return butler
            }
            sync["approved"] = .bool(true)
            sync["approvedAt"] = .string(timestamp(now))
            sync["lastStatus"] = .string("approved")
        } else if requestedApproval == false {
            sync["approved"] = .bool(false)
            sync["approvedAt"] = .null
            sync["targetEndpoint"] = .string("")
            sync["incomingRevisions"] = .object([:])
            sync["lastStatus"] = .string("revoked")
        }

        if let endpoint = BindingChatValue.string(input["targetEndpoint"]),
           let normalized = normalizedSyncEndpoint(endpoint) {
            sync["targetEndpoint"] = .string(normalized)
        }
        sync["summary"] = .string(syncSummary(sync))
        butler["sync"] = .object(sync)
        return butler
    }

    static func updatingSyncTarget(
        in current: Object,
        value: ValueType
    ) -> Object {
        let raw = BindingChatValue.string(value)
            ?? BindingChatValue.string(BindingChatValue.object(value)?["value"])
            ?? ""
        var butler = migratingState(current)
        var sync = BindingChatValue.object(butler["sync"]) ?? [:]
        if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sync["targetEndpoint"] = .string("")
            sync["lastStatus"] = .string("target_not_configured")
        } else if let endpoint = normalizedSyncEndpoint(raw) {
            sync["targetEndpoint"] = .string(endpoint)
            sync["lastStatus"] = .string("target_configured")
        } else {
            sync["lastStatus"] = .string("invalid_target_endpoint")
        }
        sync["summary"] = .string(syncSummary(sync))
        butler["sync"] = .object(sync)
        return butler
    }

    static func preferenceSyncPayload(from current: Object) -> Object {
        let butler = migratingState(current)
        let profile = BindingChatValue.object(butler["profile"]) ?? [:]
        let proactivity = BindingChatValue.object(butler["proactivity"]) ?? [:]
        return [
            "profile": .object([
                "displayName": profile["displayName"] ?? .string("HAVEN Co-Pilot"),
                "styleGuidance": profile["styleGuidance"] ?? .string("Varm, tydelig og tilbakeholden. Spør før du gir råd.")
            ]),
            "proactivity": .object([
                "enabled": proactivity["enabled"] ?? .bool(false),
                "checkInsEnabled": proactivity["checkInsEnabled"] ?? .bool(false),
                "helpWhenBlockedEnabled": proactivity["helpWhenBlockedEnabled"] ?? .bool(true),
                "adviceOffersEnabled": proactivity["adviceOffersEnabled"] ?? .bool(false),
                "minimumIntervalHours": proactivity["minimumIntervalHours"] ?? .integer(defaultMinimumIntervalHours),
                "quietHoursEnabled": proactivity["quietHoursEnabled"] ?? .bool(true),
                "quietHoursStart": proactivity["quietHoursStart"] ?? .integer(22),
                "quietHoursEnd": proactivity["quietHoursEnd"] ?? .integer(8),
                "appLaunchEnabled": proactivity["appLaunchEnabled"] ?? .bool(true),
                "taskCompletionEnabled": proactivity["taskCompletionEnabled"] ?? .bool(true),
                "userScheduleEnabled": proactivity["userScheduleEnabled"] ?? .bool(false),
                "stagingWakeEnabled": proactivity["stagingWakeEnabled"] ?? .bool(false),
                "userScheduleKind": proactivity["userScheduleKind"] ?? .string("weekdays"),
                "userScheduleLocalTime": proactivity["userScheduleLocalTime"] ?? .string("09:00"),
                "userScheduleWeekday": proactivity["userScheduleWeekday"] ?? .integer(2)
            ])
        ]
    }

    static func applyingSyncedPreferences(
        to current: Object,
        payload: Object,
        sourceDeviceID: String,
        revision: Int,
        now: Date = Date()
    ) -> Object {
        var butler = migratingState(current)
        if let incomingProfile = BindingChatValue.object(payload["profile"]) {
            if let displayName = BindingChatValue.string(incomingProfile["displayName"]) {
                butler = updatingProfileWithoutRevision(in: butler, field: "displayName", raw: displayName, now: now)
            }
            if let style = BindingChatValue.string(incomingProfile["styleGuidance"]) {
                butler = updatingProfileWithoutRevision(in: butler, field: "styleGuidance", raw: style, now: now)
            }
        }
        if let incomingCadence = BindingChatValue.object(payload["proactivity"]) {
            butler = configuringProactivityWithoutRevision(in: butler, input: incomingCadence)
        }

        var sync = BindingChatValue.object(butler["sync"]) ?? [:]
        var incomingRevisions = BindingChatValue.object(sync["incomingRevisions"]) ?? [:]
        incomingRevisions[sourceDeviceID] = .integer(revision)
        sync["incomingRevisions"] = .object(incomingRevisions)
        sync["lastImportedAt"] = .string(timestamp(now))
        sync["lastStatus"] = .string("imported")
        sync["summary"] = .string(syncSummary(sync))
        butler["sync"] = .object(sync)
        return butler
    }

    static func recordingSyncExport(in current: Object, now: Date = Date()) -> Object {
        var butler = migratingState(current)
        var sync = BindingChatValue.object(butler["sync"]) ?? [:]
        sync["lastExportedAt"] = .string(timestamp(now))
        sync["lastStatus"] = .string("exported")
        sync["summary"] = .string(syncSummary(sync))
        butler["sync"] = .object(sync)
        return butler
    }

    static func incomingRevision(for sourceDeviceID: String, in current: Object) -> Int? {
        let butler = migratingState(current)
        let revisions = BindingChatValue.object(BindingChatValue.nested("sync.incomingRevisions", in: butler)) ?? [:]
        return BindingChatValue.double(revisions[sourceDeviceID]).map(Int.init)
    }

    static func capabilitySnapshot(
        providers: [BindingChatProviderDescriptor],
        helperCount: Int,
        contextStatus: String,
        agentStatus: BindingHavenAgentDStatusSnapshot
    ) -> Object {
        let modelProviders = providers.filter { $0.kind != "local_rules" }
        let externalProviders = modelProviders.filter(\.requiresNetwork)
        let functionalLevel: String
        if modelProviders.isEmpty == false && contextStatus == "queried" {
            functionalLevel = "contextual_model_assisted"
        } else if modelProviders.isEmpty == false {
            functionalLevel = "model_assisted"
        } else if helperCount > 0 {
            functionalLevel = "guided_local"
        } else {
            functionalLevel = "basic_chat"
        }
        let providerRows: [ValueType] = providers.map { provider in
            .object([
                "id": .string(provider.id),
                "title": .string(provider.title),
                "kind": .string(provider.kind),
                "availability": .string(provider.availability),
                "privacyLevel": .string(provider.privacyLevel),
                "requiresNetwork": .bool(provider.requiresNetwork),
                "requiresUserApproval": .bool(true)
            ])
        }
        let summary = "\(helperCount) hjelpere, \(modelProviders.count) språkmodell-descriptor(er), kontekststatus \(contextStatus), HAVENAgentD \(agentStatus.status)."
        return [
            "status": .string("refreshed"),
            "functionalLevel": .string(functionalLevel),
            "helperCount": .integer(helperCount),
            "providerDescriptorCount": .integer(providers.count),
            "modelProviderDescriptorCount": .integer(modelProviders.count),
            "externalProviderDescriptorCount": .integer(externalProviders.count),
            "contextStatus": .string(contextStatus),
            "agentStatus": .string(agentStatus.status),
            "agentReadyForMCP": .bool(agentStatus.isReadyForPhoneCodexQueue),
            "summary": .string(summary),
            "transparencySummary": .string("Kapasitet er et descriptor-øyeblikksbilde. Ingen modell eller agenthandling ble startet."),
            "providers": .list(providerRows),
            "providerInvoked": .bool(false),
            "derivedFromDescriptorsOnly": .bool(true),
            "requiresExplicitProviderAction": .bool(true),
            "refreshedAt": .string(timestamp(Date()))
        ]
    }

    static func evaluateSupport(
        butler: Object,
        value: ValueType,
        now: Date = Date(),
        localHour: Int? = nil,
        calendar: Calendar = .current
    ) -> Object {
        let input = BindingChatValue.object(value) ?? [:]
        let signalKind = BindingChatValue.string(input["signalKind"])
            ?? BindingChatValue.string(input["triggerKind"])
            ?? BindingChatValue.string(input["signal"])
            ?? "unknown"
        let signalCount = Int(BindingChatValue.double(input["signalCount"]) ?? 1)
        let migrated = migratingState(butler)
        let profile = BindingChatValue.object(migrated["profile"]) ?? [:]
        let proactivity = BindingChatValue.object(migrated["proactivity"]) ?? [:]
        let displayName = BindingChatValue.string(profile["displayName"]) ?? "HAVEN Co-Pilot"

        guard [
            "explicit_help",
            "periodic_check_in",
            "app_launch",
            "task_completed",
            "user_schedule",
            "repeated_low_confidence",
            "repeated_failure",
            "advice_opportunity"
        ].contains(signalKind) else {
            return suppressedDecision(signalKind: signalKind, reason: "unsupported_signal", now: now)
        }

        // A direct request is not a proactive interruption and must remain available.
        if signalKind == "explicit_help" {
            return offeredDecision(
                signalKind: signalKind,
                displayName: displayName,
                message: "Klart. Vil du beskrive hva du prøver å få til, eller skal jeg hjelpe deg å finne ordene?",
                now: now
            )
        }

        guard BindingChatValue.bool(proactivity["enabled"]) == true else {
            return suppressedDecision(signalKind: signalKind, reason: "proactivity_disabled", now: now)
        }

        var scheduleSlot: String?
        switch signalKind {
        case "periodic_check_in":
            guard BindingChatValue.bool(proactivity["checkInsEnabled"]) == true else {
                return suppressedDecision(signalKind: signalKind, reason: "check_ins_disabled", now: now)
            }
        case "app_launch":
            guard BindingChatValue.bool(proactivity["appLaunchEnabled"]) == true else {
                return suppressedDecision(signalKind: signalKind, reason: "app_launch_disabled", now: now)
            }
        case "task_completed":
            guard BindingChatValue.bool(proactivity["taskCompletionEnabled"]) == true else {
                return suppressedDecision(signalKind: signalKind, reason: "task_completion_disabled", now: now)
            }
        case "user_schedule":
            guard BindingChatValue.bool(proactivity["userScheduleEnabled"]) == true else {
                return suppressedDecision(signalKind: signalKind, reason: "user_schedule_disabled", now: now)
            }
            guard let dueSlot = dueScheduleSlot(proactivity: proactivity, now: now, calendar: calendar) else {
                return suppressedDecision(signalKind: signalKind, reason: "schedule_not_due", now: now)
            }
            scheduleSlot = dueSlot
        case "repeated_low_confidence", "repeated_failure":
            guard BindingChatValue.bool(proactivity["helpWhenBlockedEnabled"]) == true else {
                return suppressedDecision(signalKind: signalKind, reason: "blocked_help_disabled", now: now)
            }
            guard signalCount >= 2 else {
                return suppressedDecision(signalKind: signalKind, reason: "insufficient_signal", now: now)
            }
        case "advice_opportunity":
            guard BindingChatValue.bool(proactivity["adviceOffersEnabled"]) == true else {
                return suppressedDecision(signalKind: signalKind, reason: "advice_offers_disabled", now: now)
            }
        default:
            break
        }

        if let snoozedUntilText = BindingChatValue.string(proactivity["snoozedUntil"]),
           let snoozedUntil = ISO8601DateFormatter().date(from: snoozedUntilText),
           snoozedUntil > now {
            return suppressedDecision(signalKind: signalKind, reason: "snoozed", now: now, scheduleSlot: scheduleSlot)
        }
        if BindingChatValue.bool(proactivity["quietHoursEnabled"]) == true {
            let hour = localHour ?? Calendar.current.component(.hour, from: now)
            let start = Int(BindingChatValue.double(proactivity["quietHoursStart"]) ?? 22)
            let end = Int(BindingChatValue.double(proactivity["quietHoursEnd"]) ?? 8)
            let isQuiet = start == end ? true : (start < end ? (hour >= start && hour < end) : (hour >= start || hour < end))
            if isQuiet {
                return suppressedDecision(signalKind: signalKind, reason: "quiet_hours", now: now, scheduleSlot: scheduleSlot)
            }
        }
        if let lastText = BindingChatValue.string(proactivity["lastOfferedAt"]),
           let last = ISO8601DateFormatter().date(from: lastText) {
            let minimumHours = BindingChatValue.double(proactivity["minimumIntervalHours"]) ?? 72
            if now.timeIntervalSince(last) < minimumHours * 3_600 {
                return suppressedDecision(signalKind: signalKind, reason: "minimum_interval", now: now, scheduleSlot: scheduleSlot)
            }
        }

        switch signalKind {
        case "periodic_check_in":
            return offeredDecision(
                signalKind: signalKind,
                displayName: displayName,
                message: "Hvordan går det? Vil du ha noen tips, eller skal jeg bare være stille litt til?",
                now: now
            )
        case "app_launch":
            return offeredDecision(
                signalKind: signalKind,
                displayName: displayName,
                message: "Hei igjen. Vil du ha en kort oversikt eller noen tips, eller vil du fortsette i fred?",
                now: now
            )
        case "task_completed":
            return offeredDecision(
                signalKind: signalKind,
                displayName: displayName,
                message: "Oppgaven er ferdig. Vil du ha hjelp til å velge neste steg, eller skal jeg la deg fortsette selv?",
                now: now
            )
        case "user_schedule":
            var decision = offeredDecision(
                signalKind: signalKind,
                displayName: displayName,
                message: "Dette er innsjekken du satte opp. Vil du ha en kort status eller noen tips?",
                now: now
            )
            if let scheduleSlot {
                decision["scheduleSlot"] = .string(scheduleSlot)
            }
            return decision
        case "repeated_low_confidence", "repeated_failure":
            return offeredDecision(
                signalKind: signalKind,
                displayName: displayName,
                message: "Det ser ut som vi ikke finner et trygt neste steg. Vil du at jeg hjelper deg å beskrive målet eller finne en annen hjelper?",
                now: now
            )
        case "advice_opportunity":
            return offeredDecision(
                signalKind: signalKind,
                displayName: displayName,
                message: "Jeg har et mulig tips. Vil du høre det?",
                now: now
            )
        default:
            return suppressedDecision(signalKind: signalKind, reason: "unsupported_signal", now: now)
        }
    }

    static func dismissingSupport(
        in current: Object,
        value: ValueType,
        now: Date = Date()
    ) -> Object {
        let input = BindingChatValue.object(value) ?? [:]
        let requestedHours = BindingChatValue.double(input["snoozeHours"]) ?? 168
        let hours = min(720, max(1, requestedHours))
        var butler = current
        var proactivity = BindingChatValue.object(butler["proactivity"]) ?? [:]
        var support = BindingChatValue.object(butler["support"]) ?? [:]
        let until = now.addingTimeInterval(hours * 3_600)
        proactivity["snoozedUntil"] = .string(timestamp(until))
        proactivity["summary"] = .string(proactivitySummary(proactivity))
        support["status"] = .string("dismissed")
        support["reason"] = .string("owner_snoozed")
        support["message"] = .string("")
        support["summary"] = .string("Butleren er satt på pause til \(timestamp(until)).")
        support["lastDecisionAt"] = .string(timestamp(now))
        butler["proactivity"] = .object(proactivity)
        butler["support"] = .object(support)
        return butler
    }

    static func timestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func offeredDecision(
        signalKind: String,
        displayName: String,
        message: String,
        now: Date
    ) -> Object {
        [
            "schema": .string(supportDecisionSchema),
            "status": .string("offer"),
            "reason": .string("allowed_by_owner_policy"),
            "signalKind": .string(signalKind),
            "speaker": .string(displayName),
            "message": .string(message),
            "providerInvoked": .bool(false),
            "usesRawBehaviorLog": .bool(false),
            "requiresUserActionForAnyEffect": .bool(true),
            "sideEffect": .bool(false),
            "evaluatedAt": .string(timestamp(now))
        ]
    }

    private static func suppressedDecision(
        signalKind: String,
        reason: String,
        now: Date,
        scheduleSlot: String? = nil
    ) -> Object {
        var decision: Object = [
            "schema": .string(supportDecisionSchema),
            "status": .string("suppressed"),
            "reason": .string(reason),
            "signalKind": .string(signalKind),
            "message": .string(""),
            "providerInvoked": .bool(false),
            "usesRawBehaviorLog": .bool(false),
            "requiresUserActionForAnyEffect": .bool(true),
            "sideEffect": .bool(false),
            "evaluatedAt": .string(timestamp(now))
        ]
        if let scheduleSlot {
            decision["scheduleSlot"] = .string(scheduleSlot)
        }
        return decision
    }

    private static func profileSummary(_ profile: Object) -> String {
        let name = BindingChatValue.string(profile["displayName"]) ?? "HAVEN Co-Pilot"
        let style = BindingChatValue.string(profile["styleGuidance"]) ?? ""
        return "\(name): \(style) Tilpasning skjer bare fra dine valg og enkel feedback."
    }

    private static func proactivitySummary(_ policy: Object) -> String {
        guard BindingChatValue.bool(policy["enabled"]) == true else {
            return "Proaktive innsjekker er av. Direkte spørsmål om hjelp virker fortsatt."
        }
        let interval = Int(BindingChatValue.double(policy["minimumIntervalHours"]) ?? 72)
        var triggers: [String] = []
        if BindingChatValue.bool(policy["appLaunchEnabled"]) == true {
            triggers.append("ved appstart")
        }
        if BindingChatValue.bool(policy["taskCompletionEnabled"]) == true {
            triggers.append("etter fullført oppgave")
        }
        if BindingChatValue.bool(policy["userScheduleEnabled"]) == true {
            let kind = BindingChatValue.string(policy["userScheduleKind"]) ?? "weekdays"
            let time = BindingChatValue.string(policy["userScheduleLocalTime"]) ?? "09:00"
            let kindLabel: String
            switch kind {
            case "daily": kindLabel = "daglig"
            case "weekly": kindLabel = "ukentlig"
            default: kindLabel = "på hverdager"
            }
            triggers.append("\(kindLabel) kl. \(time)")
        }
        if BindingChatValue.bool(policy["stagingWakeEnabled"]) == true {
            triggers.append("signert staging-signal")
        }
        let triggerSummary = triggers.isEmpty ? "ingen automatiske utløsere" : triggers.joined(separator: ", ")
        return "Forsiktig proaktivitet er på: \(triggerSummary), minst \(interval) timer mellom tilbud."
    }

    private static func markLocalPreferenceChange(in butler: inout Object, now: Date) {
        var sync = BindingChatValue.object(butler["sync"])
            ?? BindingChatValue.object(initialState()["sync"])
            ?? [:]
        let revision = Int(BindingChatValue.double(sync["localRevision"]) ?? 0) + 1
        sync["localRevision"] = .integer(revision)
        sync["lastStatus"] = .string("local_changes")
        sync["localChangedAt"] = .string(timestamp(now))
        sync["summary"] = .string(syncSummary(sync))
        butler["sync"] = .object(sync)
    }

    private static func updatingProfileWithoutRevision(
        in current: Object,
        field: String,
        raw: String,
        now: Date
    ) -> Object {
        var butler = migratingState(current)
        var profile = BindingChatValue.object(butler["profile"]) ?? [:]
        switch field {
        case "displayName":
            let name = sanitizedText(raw, maximumLength: 40)
            profile["displayName"] = .string(name.isEmpty ? "HAVEN Co-Pilot" : name)
        case "styleGuidance":
            let style = sanitizedText(raw, maximumLength: 180)
            if style.isEmpty == false {
                profile["styleGuidance"] = .string(style)
            }
        default:
            return butler
        }
        profile["source"] = .string("owner_approved_device_sync")
        profile["updatedAt"] = .string(timestamp(now))
        profile["summary"] = .string(profileSummary(profile))
        butler["profile"] = .object(profile)
        return butler
    }

    private static func configuringProactivityWithoutRevision(in current: Object, input: Object) -> Object {
        var butler = migratingState(current)
        var policy = BindingChatValue.object(butler["proactivity"]) ?? [:]
        for key in [
            "enabled", "checkInsEnabled", "helpWhenBlockedEnabled", "adviceOffersEnabled",
            "quietHoursEnabled", "appLaunchEnabled", "taskCompletionEnabled", "userScheduleEnabled",
            "stagingWakeEnabled"
        ] {
            if let value = BindingChatValue.bool(input[key]) {
                policy[key] = .bool(value)
            }
        }
        if let hours = BindingChatValue.double(input["minimumIntervalHours"]) {
            policy["minimumIntervalHours"] = .integer(min(720, max(24, Int(hours))))
        }
        if let start = BindingChatValue.double(input["quietHoursStart"]) {
            policy["quietHoursStart"] = .integer(min(23, max(0, Int(start))))
        }
        if let end = BindingChatValue.double(input["quietHoursEnd"]) {
            policy["quietHoursEnd"] = .integer(min(23, max(0, Int(end))))
        }
        if let kind = BindingChatValue.string(input["userScheduleKind"]),
           ["daily", "weekdays", "weekly"].contains(kind) {
            policy["userScheduleKind"] = .string(kind)
        }
        if let rawTime = BindingChatValue.string(input["userScheduleLocalTime"]),
           let localTime = normalizedScheduleTime(rawTime) {
            policy["userScheduleLocalTime"] = .string(localTime)
        }
        if let weekday = BindingChatValue.double(input["userScheduleWeekday"]) {
            policy["userScheduleWeekday"] = .integer(min(7, max(1, Int(weekday))))
        }
        policy["summary"] = .string(proactivitySummary(policy))
        butler["proactivity"] = .object(policy)
        return butler
    }

    private static func normalizedScheduleTime(_ raw: String) -> String? {
        let parts = raw.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]), (0...23).contains(hour),
              let minute = Int(parts[1]), (0...59).contains(minute) else {
            return nil
        }
        return String(format: "%02d:%02d", hour, minute)
    }

    private static func normalizedSyncEndpoint(_ raw: String) -> String? {
        let candidate = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard candidate.count <= 512,
              candidate.hasPrefix("cell://"),
              URL(string: candidate) != nil else {
            return nil
        }
        return candidate
    }

    private static func dueScheduleSlot(proactivity: Object, now: Date, calendar: Calendar) -> String? {
        guard let rawTime = BindingChatValue.string(proactivity["userScheduleLocalTime"]),
              let normalized = normalizedScheduleTime(rawTime) else {
            return nil
        }
        let parts = normalized.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        let components = calendar.dateComponents([.year, .month, .day, .weekday, .hour, .minute], from: now)
        guard let year = components.year,
              let month = components.month,
              let day = components.day,
              let weekday = components.weekday,
              let hour = components.hour,
              let minute = components.minute,
              (hour, minute) >= (parts[0], parts[1]) else {
            return nil
        }
        let kind = BindingChatValue.string(proactivity["userScheduleKind"]) ?? "weekdays"
        switch kind {
        case "weekdays" where weekday == 1 || weekday == 7:
            return nil
        case "weekly":
            let configuredWeekday = Int(BindingChatValue.double(proactivity["userScheduleWeekday"]) ?? 2)
            guard weekday == configuredWeekday else { return nil }
        case "daily", "weekdays":
            break
        default:
            return nil
        }
        let slot = String(format: "%@:%04d-%02d-%02d", kind, year, month, day)
        guard BindingChatValue.string(proactivity["lastScheduleSlot"]) != slot else { return nil }
        return slot
    }

    private static func syncSummary(_ sync: Object) -> String {
        guard BindingChatValue.bool(sync["approved"]) == true else {
            return "Synk mellom enheter er av. Begge enheter må godkjennes av eieren."
        }
        let endpoint = BindingChatValue.string(sync["targetEndpoint"]) ?? ""
        let status = BindingChatValue.string(sync["lastStatus"]) ?? "approved"
        if endpoint.isEmpty {
            return "Preferansesynk er godkjent på denne enheten, men ingen målenhet er valgt. Status: \(status)."
        }
        return "Preferansesynk er godkjent mot \(endpoint). Status: \(status)."
    }

    private static func sanitizedText(_ raw: String, maximumLength: Int) -> String {
        let singleLine = raw
            .split(whereSeparator: { $0.isNewline || $0 == "\t" })
            .map(String.init)
            .joined(separator: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return String(singleLine.prefix(maximumLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
