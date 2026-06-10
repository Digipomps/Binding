// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import CellBase
#if canImport(EventKit)
import EventKit
#endif

final class PersonalAgendaContextCell: GeneralCell {
    static let endpoint = "cell:///PersonalAgendaContext"
    static let sourceCellName = "PersonalAgendaContextCell"

    private enum CodingKeys: String, CodingKey {
        case cachedItems
        case lastRefreshAt
        case lastQueryText
        case lastAnswer
        case lastPermissionSnapshot
        case lastError
    }

    private struct AgendaItem: Codable, Equatable {
        var id: String
        var kind: String
        var source: String
        var title: String
        var startAt: Date?
        var endAt: Date?
        var dueAt: Date?
        var isAllDay: Bool
        var calendarTitle: String
        var notes: String
        var url: String
        var status: String
        var roleHints: [String]
        var priority: Double
        var completed: Bool

        var primaryDate: Date? {
            startAt ?? dueAt ?? endAt
        }
    }

    private let stateQueue = DispatchQueue(label: "Binding.PersonalAgendaContextCell.State")

    private nonisolated(unsafe) var cachedItems: [AgendaItem] = []
    private nonisolated(unsafe) var lastRefreshAt: Date?
    private nonisolated(unsafe) var lastQueryText: String = ""
    private nonisolated(unsafe) var lastAnswer: Object = [:]
    private nonisolated(unsafe) var lastPermissionSnapshot: Object = [:]
    private nonisolated(unsafe) var lastError: String = ""

#if canImport(EventKit)
    private let eventStore = EKEventStore()
#endif

    required init(owner: Identity) async {
        await super.init(owner: owner)
        stateQueue.sync {
            lastPermissionSnapshot = Self.permissionSnapshot()
            lastAnswer = Self.emptyAnswer(now: Date(), reason: "Agenda context is ready.")
        }
        await setup(owner: owner)
    }

    nonisolated required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cachedItems = try container.decodeIfPresent([AgendaItem].self, forKey: .cachedItems) ?? []
        lastRefreshAt = try container.decodeIfPresent(Date.self, forKey: .lastRefreshAt)
        lastQueryText = try container.decodeIfPresent(String.self, forKey: .lastQueryText) ?? ""
        lastAnswer = try container.decodeIfPresent(Object.self, forKey: .lastAnswer) ?? [:]
        lastPermissionSnapshot = try container.decodeIfPresent(Object.self, forKey: .lastPermissionSnapshot) ?? Self.permissionSnapshot()
        lastError = try container.decodeIfPresent(String.self, forKey: .lastError) ?? ""

        try super.init(from: decoder)
        Task { [weak self] in
            guard let self else { return }
            await self.setup(owner: self.storedOwnerIdentity)
        }
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        let snapshot = stateQueue.sync {
            (
                cachedItems: cachedItems,
                lastRefreshAt: lastRefreshAt,
                lastQueryText: lastQueryText,
                lastAnswer: lastAnswer,
                lastPermissionSnapshot: lastPermissionSnapshot,
                lastError: lastError
            )
        }
        try container.encode(snapshot.cachedItems, forKey: .cachedItems)
        try container.encodeIfPresent(snapshot.lastRefreshAt, forKey: .lastRefreshAt)
        try container.encode(snapshot.lastQueryText, forKey: .lastQueryText)
        try container.encode(snapshot.lastAnswer, forKey: .lastAnswer)
        try container.encode(snapshot.lastPermissionSnapshot, forKey: .lastPermissionSnapshot)
        try container.encode(snapshot.lastError, forKey: .lastError)
    }

    private func setup(owner: Identity) async {
        for key in readableKeys {
            agreementTemplate.addGrant("r---", for: key)
            await addInterceptForGet(requester: owner, key: key) { [weak self] _, requester in
                guard let self else { return .string("failure") }
                guard await self.validateAccess("r---", at: key, for: requester) else { return .string("denied") }
                return self.readValue(for: key)
            }
        }

        for key in writableKeys {
            agreementTemplate.addGrant("rw--", for: key)
            await addInterceptForSet(requester: owner, key: key) { [weak self] _, value, requester in
                guard let self else { return .string("failure") }
                guard await self.validateAccess("rw--", at: key, for: requester) else { return .string("denied") }
                return await self.writeValue(for: key, value: value, requester: requester)
            }
        }
    }

    private var readableKeys: [String] {
        [
            "state",
            "agenda.state",
            "agenda.today",
            "agenda.next",
            "agenda.items",
            "agenda.summary",
            "agenda.lastAnswer",
            "agenda.permissionStatus",
            "agenda.purposeSignals",
            "providerDescriptor",
            "purposeGoal",
            "skeletonConfiguration"
        ]
    }

    private var writableKeys: [String] {
        [
            "agenda.refresh",
            "agenda.answerQuery",
            "agenda.requestAccess",
            "agenda.requestCalendarAccess",
            "agenda.requestReminderAccess",
            "agenda.publishPerspectiveSignals",
            "agenda.clearCache"
        ]
    }

    private func readValue(for key: String) -> ValueType {
        switch key {
        case "state", "agenda.state":
            return .object(stateValue())
        case "agenda.today":
            let now = Date()
            let window = Self.window(for: "today", payload: [:], now: now)
            let items = filteredItems(start: window.start, end: window.end, includeUndated: false)
            let snapshot = answerSnapshot()
            return .object(answer(
                for: "Hva er på agendaen i dag?",
                payload: [:],
                now: now,
                items: items,
                cacheHasData: snapshot.cacheHasData,
                lastRefreshAt: snapshot.lastRefreshAt
            ))
        case "agenda.next":
            let now = Date()
            let window = Self.window(for: "next", payload: [:], now: now)
            let items = filteredItems(start: window.start, end: window.end, includeUndated: false)
            let snapshot = answerSnapshot()
            return .object(answer(
                for: "Hva er neste?",
                payload: ["mode": .string("next")],
                now: now,
                items: items,
                cacheHasData: snapshot.cacheHasData,
                lastRefreshAt: snapshot.lastRefreshAt
            ))
        case "agenda.items":
            return .list(stateQueue.sync { cachedItems }.map { .object(Self.objectValue(for: $0)) })
        case "agenda.summary":
            return stateQueue.sync { lastAnswer["summaryText"] ?? .string("Ingen agenda-spørring er kjørt ennå.") }
        case "agenda.lastAnswer":
            return .object(stateQueue.sync { lastAnswer })
        case "agenda.permissionStatus":
            return .object(Self.permissionSnapshot())
        case "agenda.purposeSignals":
            return .list(purposeSignals().map(ValueType.object))
        case "providerDescriptor":
            return .object(providerDescriptor())
        case "purposeGoal":
            return .object(purposeGoal())
        case "skeletonConfiguration":
            return .cellConfiguration(Self.menuConfiguration())
        default:
            return .null
        }
    }

    private func writeValue(for key: String, value: ValueType, requester: Identity) async -> ValueType {
        switch key {
        case "agenda.refresh":
            return await refresh(value)
        case "agenda.answerQuery":
            return answerQuery(value)
        case "agenda.requestAccess":
            return await requestAccess(calendar: true, reminders: true)
        case "agenda.requestCalendarAccess":
            return await requestAccess(calendar: true, reminders: false)
        case "agenda.requestReminderAccess":
            return await requestAccess(calendar: false, reminders: true)
        case "agenda.publishPerspectiveSignals":
            return await publishPerspectiveSignals(requester: requester)
        case "agenda.clearCache":
            stateQueue.sync {
                cachedItems = []
                lastRefreshAt = nil
                lastAnswer = Self.emptyAnswer(now: Date(), reason: "Agenda cache cleared.")
            }
            return .object(stateValue())
        default:
            return .object(Self.errorObject(code: "unsupported_keypath", message: "Unsupported agenda action."))
        }
    }

    private func refresh(_ value: ValueType) async -> ValueType {
        let payload = Self.object(from: value) ?? [:]
        if let injected = Self.list(payload["items"]) {
            let parsed = Self.sorted(injected.compactMap(Self.agendaItem(from:)))
            let now = Self.date(payload["now"]) ?? Date()
            let computedAnswer = answer(
                for: "Hva er på agendaen i dag?",
                payload: payload,
                now: now,
                items: parsed,
                cacheHasData: !parsed.isEmpty,
                lastRefreshAt: now
            )
            stateQueue.sync {
                cachedItems = parsed
                lastRefreshAt = now
                lastPermissionSnapshot = Self.permissionSnapshot()
                lastError = ""
                lastAnswer = computedAnswer
            }
            return .object(stateValue())
        }

        let includeCalendar = Self.bool(payload["includeCalendar"]) ?? true
        let includeReminders = Self.bool(payload["includeReminders"]) ?? true
        let now = Self.date(payload["now"]) ?? Date()
        let window = Self.window(for: Self.string(payload["mode"]) ?? "today", payload: payload, now: now)

        let result = await fetchEventKitItems(
            start: window.start,
            end: window.end,
            includeCalendar: includeCalendar,
            includeReminders: includeReminders
        )
        let sorted = Self.sorted(result.items)
        let computedAnswer = answer(
            for: "Hva er på agendaen i dag?",
            payload: payload,
            now: now,
            items: sorted,
            cacheHasData: !sorted.isEmpty,
            lastRefreshAt: now
        )
        stateQueue.sync {
            cachedItems = sorted
            lastRefreshAt = now
            lastPermissionSnapshot = Self.permissionSnapshot()
            lastError = result.errors.joined(separator: "; ")
            lastAnswer = computedAnswer
        }
        return .object(stateValue())
    }

    private func answerQuery(_ value: ValueType) -> ValueType {
        let payload = Self.object(from: value) ?? [:]
        let query = Self.string(payload["query"]) ?? Self.string(payload["text"]) ?? Self.string(payload["prompt"]) ?? "Hva er på agendaen i dag?"
        let now = Self.date(payload["now"]) ?? Date()
        let window = Self.window(for: query, payload: payload, now: now)
        let items = filteredItems(
            start: window.start,
            end: window.end,
            includeUndated: Self.bool(payload["includeUndated"]) ?? false
        )
        let snapshot = answerSnapshot()
        let answer = answer(
            for: query,
            payload: payload,
            now: now,
            items: items,
            cacheHasData: snapshot.cacheHasData,
            lastRefreshAt: snapshot.lastRefreshAt
        )
        stateQueue.sync {
            lastQueryText = query
            lastAnswer = answer
        }
        return .object(answer)
    }

    private func filteredItems(start: Date, end: Date, includeUndated: Bool) -> [AgendaItem] {
        Self.sorted(stateQueue.sync { cachedItems }.filter { item in
            guard let date = item.primaryDate else { return includeUndated }
            return date >= start && date < end
        })
    }

    private func answerSnapshot() -> (cacheHasData: Bool, lastRefreshAt: Date?) {
        stateQueue.sync {
            (!cachedItems.isEmpty, lastRefreshAt)
        }
    }

    private func answer(
        for query: String,
        payload: Object,
        now: Date,
        items: [AgendaItem],
        cacheHasData: Bool,
        lastRefreshAt: Date?
    ) -> Object {
        let sortedItems = Self.sorted(items)
        let roleScores = Self.roleScores(for: sortedItems, query: query)
        let roleScoreValues = roleScores.reduce(into: Object()) { result, item in
            result[item.key] = .float(item.value)
        }
        let nextItem = sortedItems.first { ($0.primaryDate ?? Date.distantPast) >= now } ?? sortedItems.first
        let mentionedRole = Self.mentionedRole(in: query) ?? Self.string(payload["role"])
        let topRoles = roleScores
            .filter { $0.value >= 0.34 }
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
        let needsClarification = mentionedRole == nil && topRoles.count > 1
        let permission = Self.permissionSnapshot()
        let calendarReadable = Self.string(permission["calendar"]) == "fullAccess"
        let remindersReadable = Self.string(permission["reminders"]) == "fullAccess"
        let requiresConsent = !cacheHasData && (!calendarReadable || !remindersReadable)

        let summary = Self.summaryText(items: sortedItems, nextItem: nextItem, needsClarification: needsClarification, requiresConsent: requiresConsent)
        let clarification = needsClarification
            ? "Jeg ser flere mulige konferanseroller. Vil du at jeg skal prioritere deltaker-, arrangør-, sponsor- eller utstilleragendaen?"
            : ""

        var answer: Object = [
            "schema": .string("haven.personal.agenda.answer.v1"),
            "status": .string(requiresConsent ? "requiresConsent" : "answered"),
            "query": .string(query),
            "summaryText": .string(summary),
            "itemCount": .integer(sortedItems.count),
            "items": .list(sortedItems.map { .object(Self.objectValue(for: $0)) }),
            "nextItem": nextItem.map { .object(Self.objectValue(for: $0)) } ?? .null,
            "roleScores": .object(roleScoreValues),
            "topRoles": .list(topRoles.map { .string($0.key) }),
            "mentionedRole": mentionedRole.map(ValueType.string) ?? .null,
            "needsClarification": .bool(needsClarification),
            "clarifyingQuestion": .string(clarification),
            "askUserWhenUnclear": .bool(true),
            "permissionStatus": .object(permission),
            "requiresConsent": .bool(requiresConsent),
            "sideEffect": .bool(false),
            "purposeSignals": .list(purposeSignals(from: sortedItems, roleScores: roleScores).map(ValueType.object)),
            "privacyBoundary": .string("owner_local_eventkit_cache_no_remote_native_permission"),
            "updatedAt": .string(Self.isoString(now))
        ]
        if let refreshed = lastRefreshAt {
            answer["lastRefreshAt"] = .string(Self.isoString(refreshed))
        }
        return answer
    }

    private func purposeSignals() -> [Object] {
        let items = stateQueue.sync { cachedItems }
        return purposeSignals(from: items, roleScores: Self.roleScores(for: items, query: ""))
    }

    private func purposeSignals(from items: [AgendaItem], roleScores: [String: Double]) -> [Object] {
        var signals: [Object] = [
            [
                "purposeName": .string("Review today's agenda"),
                "portablePurposeRef": .string("purpose://review-todays-agenda"),
                "purposeWeight": .float(items.isEmpty ? 0.42 : 0.78),
                "interests": .list([
                    .string("agenda"),
                    .string("calendar"),
                    .string("reminders"),
                    .string("daily-planning")
                ]),
                "reason": .string(items.isEmpty ? "Agenda context is available but currently empty." : "Agenda context has dated items.")
            ]
        ]

        for (role, score) in roleScores where score >= 0.25 {
            signals.append([
                "purposeName": .string(Self.rolePurposeName(role)),
                "portablePurposeRef": .string("purpose://\(role)-agenda-focus"),
                "purposeWeight": .float(min(0.95, max(0.35, score))),
                "interests": .list(Self.roleInterests(role).map(ValueType.string)),
                "reason": .string("Agenda items indicate \(role) context.")
            ])
        }
        return signals
    }

    private func publishPerspectiveSignals(requester: Identity) async -> ValueType {
        guard let resolver = CellBase.defaultCellResolver as? CellResolver,
              let perspective = try? await resolver.cellAtEndpoint(endpoint: "cell:///Perspective", requester: requester) as? Meddle
        else {
            return .object(Self.errorObject(code: "perspective_unavailable", message: "Perspective is not available in the current runtime."))
        }

        var published = 0
        var failures: [String] = []
        for signal in purposeSignals() {
            let purposeName = Self.string(signal["purposeName"]) ?? "Review today's agenda"
            let purposeObject: Object = [
                "name": .string(purposeName),
                "description": .string(Self.string(signal["reason"]) ?? "Published from PersonalAgendaContext."),
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
                "purposeWeight": signal["purposeWeight"] ?? .float(0.5)
            ]
            if (try? await perspective.set(keypath: "addPurpose", value: .object(payload), requester: requester)) != nil {
                published += 1
            } else {
                failures.append(purposeName)
            }
        }

        return .object([
            "status": .string(failures.isEmpty ? "published" : "partial"),
            "publishedCount": .integer(published),
            "failedPurposes": .list(failures.map(ValueType.string)),
            "sideEffect": .bool(true),
            "message": .string("Agenda purpose signals published to Perspective.")
        ])
    }

    private func stateValue() -> Object {
        let snapshot = stateQueue.sync {
            (
                items: cachedItems,
                lastRefreshAt: lastRefreshAt,
                lastAnswer: lastAnswer,
                lastPermissionSnapshot: lastPermissionSnapshot,
                lastError: lastError
            )
        }
        let permission = Self.permissionSnapshot()
        return [
            "schema": .string("haven.personal.agenda.context.v1"),
            "cell": .string(Self.endpoint),
            "status": .string(snapshot.lastError.isEmpty ? "ready" : "degraded"),
            "itemCount": .integer(snapshot.items.count),
            "todayCount": .integer(filteredItems(start: Calendar.current.startOfDay(for: Date()), end: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date(), includeUndated: false).count),
            "items": .list(snapshot.items.map { .object(Self.objectValue(for: $0)) }),
            "lastRefreshAt": snapshot.lastRefreshAt.map { .string(Self.isoString($0)) } ?? .null,
            "lastAnswer": .object(snapshot.lastAnswer),
            "summary": snapshot.lastAnswer["summaryText"] ?? .string("Agenda context is ready."),
            "permissionStatus": .object(permission),
            "nativePermissionRequests": .list([
                .string("calendar"),
                .string("reminders")
            ]),
            "requiresExplicitUserAction": .bool(true),
            "remoteConfigurationsReceiveNativePermission": .bool(false),
            "purposeSignals": .list(purposeSignals().map(ValueType.object)),
            "lastError": snapshot.lastError.isEmpty ? .null : .string(snapshot.lastError)
        ]
    }

    private func providerDescriptor() -> Object {
        [
            "id": .string("binding.personal-agenda-context"),
            "providerID": .string("binding.personal-agenda-context"),
            "kind": .string("agenda_context"),
            "title": .string("Agenda Context"),
            "summary": .string("Owner-local Calendar and Reminders context for today/next agenda queries."),
            "endpoint": .string(Self.endpoint),
            "sourceCellName": .string(Self.sourceCellName),
            "actionKeypath": .string("agenda.answerQuery"),
            "purposeRefs": .list([
                .string("personal.agenda.context.today"),
                .string("personal.chat.assist.agenda-query"),
                .string("purpose://review-todays-agenda")
            ]),
            "interests": .list([
                .string("agenda"),
                .string("calendar"),
                .string("reminders"),
                .string("daily-planning"),
                .string("agenda-aspects")
            ]),
            "availability": .string("available_in_cell_scope"),
            "privacyLevel": .string("owner_local_eventkit_cache"),
            "executionScope": .string("binding_local_cell"),
            "requiresUserApproval": .bool(true),
            "requiresNetwork": .bool(false),
            "canInvokeFromChat": .bool(true),
            "score": .float(0.92),
            "reason": .string("Agenda questions should use the local agenda context before generic chat helpers.")
        ]
    }

    private func purposeGoal() -> Object {
        [
            "title": .string("Agenda Context"),
            "summary": .string("Answer today's/next agenda questions from owner-local Calendar and Reminders data, then ask when role intent is ambiguous."),
            "purposeRefs": .list([
                .string("personal.agenda.context.today"),
                .string("personal.chat.assist.agenda-query")
            ]),
            "interests": .list([
                .string("agenda"),
                .string("calendar"),
                .string("reminders"),
                .string("conference-participant"),
                .string("conference-organizer"),
                .string("conference-sponsor"),
                .string("conference-exhibitor")
            ])
        ]
    }

    private func requestAccess(calendar: Bool, reminders: Bool) async -> ValueType {
        var results: Object = [:]
#if canImport(EventKit)
        if calendar {
            let result = await requestCalendarAccess()
            results["calendarGranted"] = .bool(result.granted)
            results["calendarError"] = result.error.map(ValueType.string) ?? .null
        }
        if reminders {
            let result = await requestReminderAccess()
            results["remindersGranted"] = .bool(result.granted)
            results["remindersError"] = result.error.map(ValueType.string) ?? .null
        }
#else
        results["calendarGranted"] = .bool(false)
        results["remindersGranted"] = .bool(false)
        results["calendarError"] = .string("EventKit is not available in this build.")
        results["remindersError"] = .string("EventKit is not available in this build.")
#endif
        let permission = Self.permissionSnapshot()
        stateQueue.sync {
            lastPermissionSnapshot = permission
        }
        results["permissionStatus"] = .object(permission)
        results["sideEffect"] = .bool(true)
        return .object(results)
    }

#if canImport(EventKit)
    private func requestCalendarAccess() async -> (granted: Bool, error: String?) {
        await withCheckedContinuation { continuation in
            eventStore.requestFullAccessToEvents { granted, error in
                continuation.resume(returning: (granted, error.map { String(describing: $0) }))
            }
        }
    }

    private func requestReminderAccess() async -> (granted: Bool, error: String?) {
        await withCheckedContinuation { continuation in
            eventStore.requestFullAccessToReminders { granted, error in
                continuation.resume(returning: (granted, error.map { String(describing: $0) }))
            }
        }
    }
#endif

    private func fetchEventKitItems(
        start: Date,
        end: Date,
        includeCalendar: Bool,
        includeReminders: Bool
    ) async -> (items: [AgendaItem], errors: [String]) {
#if canImport(EventKit)
        var items: [AgendaItem] = []
        var errors: [String] = []

        if includeCalendar {
            if Self.hasFullAccess(to: .event) {
                let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
                let events = eventStore.events(matching: predicate)
                items.append(contentsOf: events.map(Self.agendaItem(from:)))
            } else {
                errors.append("Calendar full access is not granted.")
            }
        }

        if includeReminders {
            if Self.hasFullAccess(to: .reminder) {
                let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: end, calendars: nil)
                let reminders = await fetchReminders(predicate: predicate)
                items.append(contentsOf: reminders.compactMap { reminder in
                    let item = Self.agendaItem(from: reminder)
                    if let due = item.dueAt {
                        return due >= start && due < end ? item : nil
                    }
                    return nil
                })
            } else {
                errors.append("Reminders full access is not granted.")
            }
        }

        return (items, errors)
#else
        return ([], ["EventKit is not available in this build."])
#endif
    }

#if canImport(EventKit)
    private func fetchReminders(predicate: NSPredicate) async -> [EKReminder] {
        await withCheckedContinuation { continuation in
            _ = eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    private static func agendaItem(from event: EKEvent) -> AgendaItem {
        AgendaItem(
            id: event.eventIdentifier ?? "event-\(UUID().uuidString)",
            kind: "event",
            source: "calendar",
            title: event.title.nilIfBlank ?? "Untitled event",
            startAt: event.startDate,
            endAt: event.endDate,
            dueAt: nil,
            isAllDay: event.isAllDay,
            calendarTitle: event.calendar?.title ?? "",
            notes: event.notes ?? "",
            url: event.url?.absoluteString ?? "",
            status: "scheduled",
            roleHints: roleHints(from: [event.title, event.notes ?? "", event.calendar?.title ?? ""]),
            priority: 0.5,
            completed: false
        )
    }

    private static func agendaItem(from reminder: EKReminder) -> AgendaItem {
        let dueAt = date(from: reminder.dueDateComponents)
        return AgendaItem(
            id: reminder.calendarItemIdentifier,
            kind: "reminder",
            source: "reminders",
            title: reminder.title.nilIfBlank ?? "Untitled reminder",
            startAt: nil,
            endAt: nil,
            dueAt: dueAt,
            isAllDay: reminder.dueDateComponents?.hour == nil,
            calendarTitle: reminder.calendar?.title ?? "",
            notes: reminder.notes ?? "",
            url: reminder.url?.absoluteString ?? "",
            status: reminder.isCompleted ? "completed" : "open",
            roleHints: roleHints(from: [reminder.title, reminder.notes ?? "", reminder.calendar?.title ?? ""]),
            priority: Double(reminder.priority) / 9.0,
            completed: reminder.isCompleted
        )
    }

    private static func date(from components: DateComponents?) -> Date? {
        guard var components else { return nil }
        components.calendar = components.calendar ?? Calendar.current
        return components.date
    }

    private static func hasFullAccess(to entityType: EKEntityType) -> Bool {
        switch EKEventStore.authorizationStatus(for: entityType) {
        case .fullAccess:
            return true
        default:
            return false
        }
    }
#endif

    private static func permissionSnapshot() -> Object {
#if canImport(EventKit)
        return [
            "eventKitAvailable": .bool(true),
            "calendar": .string(permissionString(EKEventStore.authorizationStatus(for: .event))),
            "reminders": .string(permissionString(EKEventStore.authorizationStatus(for: .reminder))),
            "calendarFullAccessRequiredForRead": .bool(true),
            "remindersFullAccessRequiredForRead": .bool(true)
        ]
#else
        return [
            "eventKitAvailable": .bool(false),
            "calendar": .string("unavailable"),
            "reminders": .string("unavailable"),
            "calendarFullAccessRequiredForRead": .bool(true),
            "remindersFullAccessRequiredForRead": .bool(true)
        ]
#endif
    }

#if canImport(EventKit)
    private static func permissionString(_ status: EKAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .fullAccess:
            return "fullAccess"
        case .writeOnly:
            return "writeOnly"
        @unknown default:
            return "unknown"
        }
    }
#endif

    static func menuConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Agenda Context")
        configuration.description = "Owner-local agenda context over Calendar and Reminders. Native access is requested only after explicit user action."
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: endpoint,
            sourceCellName: sourceCellName,
            purpose: "Hold dagens agenda og neste gjøremål tilgjengelig for Co-Pilot",
            purposeDescription: "Leser Calendar/Reminders lokalt etter samtykke, svarer på agenda-spørringer, og kan publisere eksplisitte purpose-signaler til Perspective.",
            interests: BindingPersonalCopilotV1Policy.discoveryInterests([
                "agenda",
                "calendar",
                "reminders",
                "daily-planning",
                "agenda-aspects",
                "purposeRef=personal.chat.assist.agenda-query"
            ], policyCategory: "agenda-context"),
            menuSlots: ["upperRight", "lowerRight"]
        )
        configuration.addReference(CellReference(endpoint: endpoint, subscribeFeed: false, label: "agendaContext"))

        let refresh = SkeletonButton(
            keypath: "agendaContext.agenda.refresh",
            label: "Oppdater agenda",
            payload: .object(["mode": .string("today")])
        )
        let answer = SkeletonButton(
            keypath: "agendaContext.agenda.answerQuery",
            label: "Svar på agenda",
            payload: .object(["query": .string("Hva er på agendaen i dag?")])
        )
        let publish = SkeletonButton(
            keypath: "agendaContext.agenda.publishPerspectiveSignals",
            label: "Del fokus med Perspective",
            payload: .object([:])
        )

        var row = SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "title")),
            .Text(SkeletonText(keypath: "timeSummary")),
            .Text(SkeletonText(keypath: "roleSummary"))
        ], spacing: 4)
        row.modifiers = SkeletonModifiers()
        row.modifiers?.padding = 10
        row.modifiers?.cornerRadius = 8
        row.modifiers?.borderWidth = 1
        row.modifiers?.borderColor = "#CBD5E1"
        row.modifiers?.styleRole = "personal-list-row"

        var list = SkeletonList(topic: nil, keypath: "agendaContext.state.items", flowElementSkeleton: row)
        list.modifiers = SkeletonModifiers()
        list.modifiers?.height = 280
        list.modifiers?.styleRole = "personal-list-row"

        configuration.skeleton = .ScrollView(SkeletonScrollView(elements: [
            .VStack(SkeletonVStack(elements: [
                .Text(SkeletonText(text: "Agenda Context")),
                .Text(SkeletonText(keypath: "agendaContext.state.summary")),
                .Text(SkeletonText(keypath: "agendaContext.state.permissionStatus.calendar")),
                .Text(SkeletonText(keypath: "agendaContext.state.permissionStatus.reminders")),
                .HStack(SkeletonHStack(elements: [
                    .Button(refresh),
                    .Button(answer),
                    .Button(publish)
                ], spacing: 8)),
                .List(list),
                .Text(SkeletonText(keypath: "agendaContext.state.lastAnswer.clarifyingQuestion"))
            ], spacing: 12))
        ]))
        return configuration
    }

    private static func objectValue(for item: AgendaItem) -> Object {
        let date = item.primaryDate
        let timeSummary: String
        if item.isAllDay {
            timeSummary = date.map { "Hele dagen \(shortDate($0))" } ?? "Ingen dato"
        } else if let startAt = item.startAt {
            timeSummary = "\(shortTime(startAt))\(item.endAt.map { "-\(shortTime($0))" } ?? "")"
        } else if let dueAt = item.dueAt {
            timeSummary = "Frist \(shortTime(dueAt))"
        } else {
            timeSummary = "Ingen dato"
        }
        return [
            "id": .string(item.id),
            "kind": .string(item.kind),
            "source": .string(item.source),
            "title": .string(item.title),
            "startAt": item.startAt.map { .string(isoString($0)) } ?? .null,
            "endAt": item.endAt.map { .string(isoString($0)) } ?? .null,
            "dueAt": item.dueAt.map { .string(isoString($0)) } ?? .null,
            "isAllDay": .bool(item.isAllDay),
            "calendarTitle": .string(item.calendarTitle),
            "notes": .string(item.notes),
            "url": item.url.isEmpty ? .null : .string(item.url),
            "status": .string(item.status),
            "roleHints": .list(item.roleHints.map(ValueType.string)),
            "roleSummary": .string(item.roleHints.isEmpty ? "agenda" : item.roleHints.joined(separator: ", ")),
            "priority": .float(item.priority),
            "completed": .bool(item.completed),
            "timeSummary": .string(timeSummary)
        ]
    }

    private static func agendaItem(from value: ValueType) -> AgendaItem? {
        guard let object = object(from: value) else { return nil }
        let title = string(object["title"]) ?? string(object["summary"]) ?? ""
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let kind = string(object["kind"]) ?? string(object["type"]) ?? "event"
        let startAt = date(object["startAt"]) ?? date(object["startsAt"])
        let dueAt = date(object["dueAt"]) ?? date(object["dueDate"])
        let roleHints = stringList(object["roleHints"]).nilIfEmpty
            ?? stringList(object["roles"]).nilIfEmpty
            ?? roleHints(from: [
                title,
                string(object["notes"]) ?? "",
                string(object["calendarTitle"]) ?? ""
            ])
        return AgendaItem(
            id: string(object["id"]) ?? "\(kind)-\(UUID().uuidString)",
            kind: kind,
            source: string(object["source"]) ?? (kind == "reminder" ? "reminders" : "calendar"),
            title: title,
            startAt: startAt,
            endAt: date(object["endAt"]) ?? date(object["endsAt"]),
            dueAt: dueAt,
            isAllDay: bool(object["isAllDay"]) ?? false,
            calendarTitle: string(object["calendarTitle"]) ?? string(object["calendar"]) ?? "",
            notes: string(object["notes"]) ?? string(object["detail"]) ?? "",
            url: string(object["url"]) ?? "",
            status: string(object["status"]) ?? (kind == "reminder" ? "open" : "scheduled"),
            roleHints: roleHints,
            priority: double(object["priority"]) ?? 0.5,
            completed: bool(object["completed"]) ?? false
        )
    }

    private static func sorted(_ items: [AgendaItem]) -> [AgendaItem] {
        items.sorted { lhs, rhs in
            switch (lhs.primaryDate, rhs.primaryDate) {
            case let (left?, right?):
                if left == right {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return left < right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }

    private static func summaryText(
        items: [AgendaItem],
        nextItem: AgendaItem?,
        needsClarification: Bool,
        requiresConsent: Bool
    ) -> String {
        if requiresConsent {
            return "Jeg trenger kalender- og påminnelsestilgang før jeg kan lese dagens agenda. Du kan fortsatt bruke lokale agenda-utkast."
        }
        guard !items.isEmpty else {
            return "Jeg fant ingen kalenderhendelser eller påminnelser i den valgte agendaen."
        }
        let firstItems = items.prefix(4).map { item in
            let prefix = item.primaryDate.map { item.isAllDay ? "hele dagen" : shortTime($0) } ?? "udatert"
            return "\(prefix) \(item.title)"
        }.joined(separator: "; ")
        let nextText = nextItem.map { " Neste er \($0.title)." } ?? ""
        let roleText = needsClarification ? " Jeg bør spørre hvilken rolle som skal prioriteres." : ""
        return "Agendaen har \(items.count) punkt: \(firstItems).\(nextText)\(roleText)"
    }

    private static func roleScores(for items: [AgendaItem], query: String) -> [String: Double] {
        var scores: [String: Double] = [:]
        for item in items {
            for role in item.roleHints {
                scores[normalizedRole(role), default: 0.0] += 1.0
            }
            let text = normalized([item.title, item.notes, item.calendarTitle].joined(separator: " "))
            for (role, keywords) in roleKeywords {
                if keywords.contains(where: { text.contains($0) }) {
                    scores[role, default: 0.0] += 0.7
                }
            }
        }
        if let mentioned = mentionedRole(in: query) {
            scores[mentioned, default: 0.0] += 0.5
        }
        let maxScore = scores.values.max() ?? 1.0
        guard maxScore > 0 else { return [:] }
        return scores.mapValues { min(1.0, $0 / maxScore) }
    }

    private static func roleHints(from texts: [String]) -> [String] {
        let haystack = normalized(texts.joined(separator: " "))
        return roleKeywords.compactMap { role, keywords in
            keywords.contains { haystack.contains($0) } ? role : nil
        }.sorted()
    }

    private static func mentionedRole(in query: String) -> String? {
        let normalized = normalized(query)
        if normalized.contains("deltaker") || normalized.contains("participant") { return "participant" }
        if normalized.contains("arrangor") || normalized.contains("organizer") || normalized.contains("arranger") { return "organizer" }
        if normalized.contains("sponsor") { return "sponsor" }
        if normalized.contains("utstiller") || normalized.contains("exhibitor") || normalized.contains("stand") { return "exhibitor" }
        return nil
    }

    private static func normalizedRole(_ role: String) -> String {
        let value = normalized(role)
        if value.contains("arrang") || value.contains("organizer") { return "organizer" }
        if value.contains("sponsor") { return "sponsor" }
        if value.contains("utstill") || value.contains("exhibitor") { return "exhibitor" }
        if value.contains("deltak") || value.contains("participant") { return "participant" }
        return value
    }

    private static let roleKeywords: [String: [String]] = [
        "participant": ["participant", "deltaker", "session", "keynote", "talk", "workshop", "program", "agenda"],
        "organizer": ["organizer", "arrangor", "arranger", "staff", "control tower", "speaker brief", "publisering", "programansvar"],
        "sponsor": ["sponsor", "lead", "handoff", "qualified", "retention", "crm", "sponsoroppfolging"],
        "exhibitor": ["exhibitor", "utstiller", "booth", "stand", "expo", "messe"]
    ]

    private static func rolePurposeName(_ role: String) -> String {
        switch role {
        case "participant": return "Conference participant agenda"
        case "organizer": return "Conference organizer agenda"
        case "sponsor": return "Conference sponsor follow-up"
        case "exhibitor": return "Conference exhibitor agenda"
        default: return "\(role.capitalized) agenda"
        }
    }

    private static func roleInterests(_ role: String) -> [String] {
        switch role {
        case "participant": return ["conference", "participant", "agenda", "sessions"]
        case "organizer": return ["conference", "organizer", "operations", "agenda"]
        case "sponsor": return ["conference", "sponsor", "leads", "follow-up"]
        case "exhibitor": return ["conference", "exhibitor", "booth", "expo"]
        default: return ["agenda", role]
        }
    }

    private static func emptyAnswer(now: Date, reason: String) -> Object {
        [
            "schema": .string("haven.personal.agenda.answer.v1"),
            "status": .string("idle"),
            "summaryText": .string(reason),
            "itemCount": .integer(0),
            "items": .list([]),
            "needsClarification": .bool(false),
            "clarifyingQuestion": .string(""),
            "sideEffect": .bool(false),
            "updatedAt": .string(isoString(now))
        ]
    }

    private static func errorObject(code: String, message: String) -> Object {
        [
            "status": .string("error"),
            "code": .string(code),
            "message": .string(message),
            "sideEffect": .bool(false)
        ]
    }

    private static func window(for query: String, payload: Object, now: Date) -> (start: Date, end: Date) {
        if let start = date(payload["startAt"]) ?? date(payload["from"]),
           let end = date(payload["endAt"]) ?? date(payload["to"]) {
            return (start, end)
        }
        let calendar = Calendar.current
        let normalizedQuery = normalized(query)
        if normalizedQuery.contains("neste") || normalizedQuery.contains("next") || string(payload["mode"]) == "next" {
            return (now, calendar.date(byAdding: .day, value: int(payload["daysAhead"]) ?? 7, to: now) ?? now.addingTimeInterval(7 * 24 * 60 * 60))
        }
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: int(payload["daysAhead"]) ?? 1, to: start) ?? start.addingTimeInterval(24 * 60 * 60)
        return (start, end)
    }

    private static func object(from value: ValueType?) -> Object? {
        guard case let .object(object)? = value else { return nil }
        return object
    }

    private static func list(_ value: ValueType?) -> [ValueType]? {
        guard case let .list(list)? = value else { return nil }
        return list
    }

    private static func string(_ value: ValueType?) -> String? {
        guard case let .string(text)? = value else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func stringList(_ value: ValueType?) -> [String] {
        guard case let .list(list)? = value else { return [] }
        return list.compactMap(string)
    }

    private static func bool(_ value: ValueType?) -> Bool? {
        guard case let .bool(flag)? = value else { return nil }
        return flag
    }

    private static func int(_ value: ValueType?) -> Int? {
        switch value {
        case let .integer(number)?: return number
        case let .number(number)?: return number
        case let .float(number)?: return Int(number)
        default: return nil
        }
    }

    private static func double(_ value: ValueType?) -> Double? {
        switch value {
        case let .float(number)?: return number
        case let .integer(number)?: return Double(number)
        case let .number(number)?: return Double(number)
        default: return nil
        }
    }

    private static func date(_ value: ValueType?) -> Date? {
        switch value {
        case let .float(timestamp)?: return Date(timeIntervalSince1970: timestamp)
        case let .integer(timestamp)?: return Date(timeIntervalSince1970: TimeInterval(timestamp))
        case let .number(timestamp)?: return Date(timeIntervalSince1970: TimeInterval(timestamp))
        case let .string(text)?:
            return ISO8601DateFormatter().date(from: text)
        default:
            return nil
        }
    }

    private static func normalized(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private static func isoString(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.timeStyle = .none
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Array where Element == String {
    var nilIfEmpty: [String]? {
        isEmpty ? nil : self
    }
}
