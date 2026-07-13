// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import CellBase

/// Private, deterministic policy for the user-shaped Co-Pilot butler surface.
///
/// This type deliberately does not inspect raw chat history or invoke a model.
/// It consumes owner-selected preferences and small, allowlisted support signals.
nonisolated enum BindingPersonalButlerPolicy {
    static let schema = "binding.personal-butler.v0"
    static let supportDecisionSchema = "binding.personal-butler-support-decision.v0"

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
                "minimumIntervalHours": .integer(72),
                "quietHoursEnabled": .bool(true),
                "quietHoursStart": .integer(22),
                "quietHoursEnd": .integer(8),
                "lastOfferedAt": .null,
                "snoozedUntil": .null,
                "summary": .string("Proaktive innsjekker er av. Direkte spørsmål om hjelp virker fortsatt."),
                "contextPolicy": .string("owner-approved local signals only; no raw behavior log")
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

    static func updatingProfile(
        in current: Object,
        field: String,
        value: ValueType,
        now: Date = Date()
    ) -> Object {
        var butler = current
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
        var butler = current
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
        return butler
    }

    static func configuringProactivity(
        in current: Object,
        value: ValueType
    ) -> Object {
        let input = BindingChatValue.object(value) ?? [:]
        var butler = current
        var policy = BindingChatValue.object(butler["proactivity"])
            ?? BindingChatValue.object(initialState()["proactivity"])
            ?? [:]

        for key in [
            "enabled",
            "checkInsEnabled",
            "helpWhenBlockedEnabled",
            "adviceOffersEnabled",
            "quietHoursEnabled"
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
        policy["summary"] = .string(proactivitySummary(policy))
        butler["proactivity"] = .object(policy)
        return butler
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
        localHour: Int? = nil
    ) -> Object {
        let input = BindingChatValue.object(value) ?? [:]
        let signalKind = BindingChatValue.string(input["signalKind"])
            ?? BindingChatValue.string(input["signal"])
            ?? "unknown"
        let signalCount = Int(BindingChatValue.double(input["signalCount"]) ?? 1)
        let profile = BindingChatValue.object(butler["profile"]) ?? [:]
        let proactivity = BindingChatValue.object(butler["proactivity"]) ?? [:]
        let displayName = BindingChatValue.string(profile["displayName"]) ?? "HAVEN Co-Pilot"

        guard [
            "explicit_help",
            "periodic_check_in",
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
        if let snoozedUntilText = BindingChatValue.string(proactivity["snoozedUntil"]),
           let snoozedUntil = ISO8601DateFormatter().date(from: snoozedUntilText),
           snoozedUntil > now {
            return suppressedDecision(signalKind: signalKind, reason: "snoozed", now: now)
        }
        if BindingChatValue.bool(proactivity["quietHoursEnabled"]) == true {
            let hour = localHour ?? Calendar.current.component(.hour, from: now)
            let start = Int(BindingChatValue.double(proactivity["quietHoursStart"]) ?? 22)
            let end = Int(BindingChatValue.double(proactivity["quietHoursEnd"]) ?? 8)
            let isQuiet = start == end ? true : (start < end ? (hour >= start && hour < end) : (hour >= start || hour < end))
            if isQuiet {
                return suppressedDecision(signalKind: signalKind, reason: "quiet_hours", now: now)
            }
        }
        if let lastText = BindingChatValue.string(proactivity["lastOfferedAt"]),
           let last = ISO8601DateFormatter().date(from: lastText) {
            let minimumHours = BindingChatValue.double(proactivity["minimumIntervalHours"]) ?? 72
            if now.timeIntervalSince(last) < minimumHours * 3_600 {
                return suppressedDecision(signalKind: signalKind, reason: "minimum_interval", now: now)
            }
        }

        switch signalKind {
        case "periodic_check_in":
            guard BindingChatValue.bool(proactivity["checkInsEnabled"]) == true else {
                return suppressedDecision(signalKind: signalKind, reason: "check_ins_disabled", now: now)
            }
            return offeredDecision(
                signalKind: signalKind,
                displayName: displayName,
                message: "Hvordan går det? Vil du ha noen tips, eller skal jeg bare være stille litt til?",
                now: now
            )
        case "repeated_low_confidence", "repeated_failure":
            guard BindingChatValue.bool(proactivity["helpWhenBlockedEnabled"]) == true else {
                return suppressedDecision(signalKind: signalKind, reason: "blocked_help_disabled", now: now)
            }
            guard signalCount >= 2 else {
                return suppressedDecision(signalKind: signalKind, reason: "insufficient_signal", now: now)
            }
            return offeredDecision(
                signalKind: signalKind,
                displayName: displayName,
                message: "Det ser ut som vi ikke finner et trygt neste steg. Vil du at jeg hjelper deg å beskrive målet eller finne en annen hjelper?",
                now: now
            )
        case "advice_opportunity":
            guard BindingChatValue.bool(proactivity["adviceOffersEnabled"]) == true else {
                return suppressedDecision(signalKind: signalKind, reason: "advice_offers_disabled", now: now)
            }
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
        support["summary"] = .string("Butleren er satt på pause til (timestamp(until)).")
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
        now: Date
    ) -> Object {
        [
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
        let checkIns = BindingChatValue.bool(policy["checkInsEnabled"]) == true ? "innsjekker på" : "innsjekker av"
        let advice = BindingChatValue.bool(policy["adviceOffersEnabled"]) == true ? "råd på" : "råd av"
        return "Forsiktig proaktivitet er på: \(checkIns), \(advice), minst \(interval) timer mellom tilbud."
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
