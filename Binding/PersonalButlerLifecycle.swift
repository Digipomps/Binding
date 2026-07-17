// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import SwiftUI
import Combine
import CellBase

/// Explicit integration seam for Cells that know a user-owned task became complete.
///
/// Posting this notification only asks the private butler policy to evaluate an
/// allowlisted signal. It does not send, share, or invoke a provider.
enum BindingPersonalButlerTriggerBridge {
    nonisolated static let taskCompletedNotification = Notification.Name(
        "BindingPersonalButlerTriggerBridge.taskCompleted"
    )
    nonisolated static let preferencesChangedNotification = Notification.Name(
        "BindingPersonalButlerTriggerBridge.preferencesChanged"
    )

    nonisolated private static let taskIDKey = "taskID"
    nonisolated private static let sourceEndpointKey = "sourceEndpoint"

    nonisolated static func postTaskCompleted(
        taskID: String? = nil,
        sourceEndpoint: String? = nil,
        notificationCenter: NotificationCenter = .default
    ) {
        var userInfo: [String: String] = [:]
        if let taskID, taskID.isEmpty == false {
            userInfo[taskIDKey] = taskID
        }
        if let sourceEndpoint, sourceEndpoint.isEmpty == false {
            userInfo[sourceEndpointKey] = sourceEndpoint
        }
        notificationCenter.post(
            name: taskCompletedNotification,
            object: nil,
            userInfo: userInfo
        )
    }
}

nonisolated enum BindingPersonalButlerDaemonWakeRequest {
    static func triggerKind(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "haven",
              components.host?.lowercased() == "butler",
              components.path == "/check-in" else {
            return nil
        }
        var query: [String: String] = [:]
        for item in components.queryItems ?? [] {
            guard let value = item.value, query[item.name] == nil else {
                return nil
            }
            query[item.name] = value
        }
        guard query["source"] == "havenagentd",
              let trigger = query["trigger"],
              ["app_launch", "user_schedule"].contains(trigger) else {
            return nil
        }
        return trigger
    }
}

@MainActor
struct BindingPersonalButlerLifecycleModifier: ViewModifier {
    @State private var didRunLaunchTrigger = false

    func body(content: Content) -> some View {
        content
            .task {
                guard didRunLaunchTrigger == false else { return }
                didRunLaunchTrigger = true
                await dispatch(triggerKind: "app_launch")
            }
            .onReceive(NotificationCenter.default.publisher(
                for: BindingPersonalButlerTriggerBridge.taskCompletedNotification
            )) { _ in
                Task { @MainActor in
                    await dispatch(triggerKind: "task_completed")
                }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: BindingPersonalButlerTriggerBridge.preferencesChangedNotification
            )) { _ in
                Task { @MainActor in
                    await syncDaemonPreferences()
                }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: BindingIncomingURLBridge.notificationName
            )) { notification in
                guard let url = BindingIncomingURLBridge.url(from: notification),
                      let triggerKind = BindingPersonalButlerDaemonWakeRequest.triggerKind(from: url) else {
                    return
                }
                Task { @MainActor in
                    await dispatch(triggerKind: triggerKind)
                }
            }
    }

    private func dispatch(triggerKind: String) async {
        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        await BindingLocalCellRegistration.shared.ensureLaunchCriticalCellsRegistered()

        guard let requester = await BindingStartupIdentityVault.shared.identity(
            for: "private",
            makeNewIfNotFound: true
        ), let resolver = CellBase.defaultCellResolver as? CellResolver else {
            return
        }
        guard let chat = try? await resolver.cellAtEndpoint(
            endpoint: "cell:///PersonalChatHub",
            requester: requester
        ) as? Meddle else {
            return
        }
        _ = try? await chat.set(
            keypath: "chatHub.butler.trigger.run",
            value: .object([
                "triggerKind": .string(triggerKind),
                "source": .string("binding.lifecycle")
            ]),
            requester: requester
        )
        await syncDaemonPreferences(chat: chat, requester: requester, resolver: resolver)
    }

    private func syncDaemonPreferences() async {
        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        await BindingLocalCellRegistration.shared.ensureLaunchCriticalCellsRegistered()
        guard let requester = await BindingStartupIdentityVault.shared.identity(
            for: "private",
            makeNewIfNotFound: true
        ), let resolver = CellBase.defaultCellResolver as? CellResolver,
              let chat = try? await resolver.cellAtEndpoint(
                endpoint: "cell:///PersonalChatHub",
                requester: requester
              ) as? Meddle else {
            return
        }
        await syncDaemonPreferences(chat: chat, requester: requester, resolver: resolver)
    }

    private func syncDaemonPreferences(
        chat: Meddle,
        requester: Identity,
        resolver: CellResolver
    ) async {
        guard let butlerValue = try? await chat.get(
            keypath: "chatHub.butler",
            requester: requester
        ), let butler = BindingChatValue.object(butlerValue),
              let proactivity = BindingChatValue.object(butler["proactivity"]) else {
            return
        }
        let sync = BindingChatValue.object(butler["sync"]) ?? [:]
        let endpoint = AgentLocalControlBridgeEndpointSupport.rewriteEndpoint(
            "cell:///agent/butler/scheduler"
        ) ?? "cell:///agent/butler/scheduler"
        guard let scheduler = try? await resolver.cellAtEndpoint(
            endpoint: endpoint,
            requester: requester
        ) as? Meddle else {
            return
        }

        let payload: Object = [
            "ownerApproved": .bool(true),
            "enabled": proactivity["enabled"] ?? .bool(false),
            "minimumIntervalHours": proactivity["minimumIntervalHours"] ?? .integer(72),
            "quietHoursEnabled": proactivity["quietHoursEnabled"] ?? .bool(true),
            "quietHoursStart": proactivity["quietHoursStart"] ?? .integer(22),
            "quietHoursEnd": proactivity["quietHoursEnd"] ?? .integer(8),
            "appLaunchEnabled": proactivity["appLaunchEnabled"] ?? .bool(true),
            "taskCompletionEnabled": proactivity["taskCompletionEnabled"] ?? .bool(true),
            "userScheduleEnabled": proactivity["userScheduleEnabled"] ?? .bool(false),
            "userScheduleKind": proactivity["userScheduleKind"] ?? .string("weekdays"),
            "userScheduleLocalTime": proactivity["userScheduleLocalTime"] ?? .string("09:00"),
            "userScheduleWeekday": proactivity["userScheduleWeekday"] ?? .integer(2),
            "stagingWakeEnabled": proactivity["stagingWakeEnabled"] ?? .bool(false),
            "lastOfferedAt": proactivity["lastOfferedAt"] ?? .null,
            "snoozedUntil": proactivity["snoozedUntil"] ?? .null,
            "sourceDeviceID": sync["deviceID"] ?? .null
        ]
        _ = try? await scheduler.set(
            keypath: "preferences.configure",
            value: .object(payload),
            requester: requester
        )
    }
}
