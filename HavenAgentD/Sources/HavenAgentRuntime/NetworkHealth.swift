// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation

/// Coarse classification of an observed flood. Detail is refined post-hoc from
/// the triggered packet capture; this is the at-a-glance kind used by the
/// purpose/notification layer to decide whether to bother the user.
public enum NetworkFloodClass: String, Codable, Sendable, Equatable {
    /// High inbound throughput, errors low — usually a benign download saturating the link.
    case bulkDownload
    /// High outbound throughput, errors low — a large upload/backup.
    case bulkUpload
    /// Very high packet rate with low byte volume — many small frames (storm-like).
    case highPacketRate
    /// Rising interface input/output errors or drops — the link is in distress.
    case interfaceDistress
    case unknown
}

/// Lifecycle phase of a flood event. A sustained condition is ONE event that
/// moves started -> ongoing -> resolved, rather than re-firing on every sample.
public enum NetworkFloodPhase: String, Codable, Sendable, Equatable {
    case started
    case ongoing
    case resolved
}

/// One measurement window derived from interface counter deltas.
public struct NetworkHealthSample: Codable, Sendable, Equatable {
    public var interface: String
    public var packetsPerSecond: Int
    public var bytesPerSecondIn: Int
    public var bytesPerSecondOut: Int
    public var inputErrorsPerSecond: Int
    public var outputErrorsPerSecond: Int
    public var sampledAt: String

    public init(
        interface: String,
        packetsPerSecond: Int,
        bytesPerSecondIn: Int,
        bytesPerSecondOut: Int,
        inputErrorsPerSecond: Int,
        outputErrorsPerSecond: Int,
        sampledAt: String
    ) {
        self.interface = interface
        self.packetsPerSecond = packetsPerSecond
        self.bytesPerSecondIn = bytesPerSecondIn
        self.bytesPerSecondOut = bytesPerSecondOut
        self.inputErrorsPerSecond = inputErrorsPerSecond
        self.outputErrorsPerSecond = outputErrorsPerSecond
        self.sampledAt = sampledAt
    }

    public var megabitsPerSecond: Double {
        Double(bytesPerSecondIn + bytesPerSecondOut) * 8.0 / 1_000_000.0
    }

    public var errorsPerSecond: Int { inputErrorsPerSecond + outputErrorsPerSecond }
}

/// Tunable detection thresholds. Defaults treat benign high-throughput as NOT a
/// flood (a saturated link with no errors is normal); a flood is sustained very
/// high packet rate or rising interface errors.
public struct NetworkSentinelThresholds: Codable, Sendable, Equatable {
    public var packetsPerSecond: Int
    public var megabitsPerSecond: Double
    public var errorsPerSecond: Int
    public var sustainedSamples: Int
    public var resolveSamples: Int

    public init(
        packetsPerSecond: Int = 12_000,
        megabitsPerSecond: Double = 500.0,
        errorsPerSecond: Int = 50,
        sustainedSamples: Int = 2,
        resolveSamples: Int = 3
    ) {
        self.packetsPerSecond = packetsPerSecond
        self.megabitsPerSecond = megabitsPerSecond
        self.errorsPerSecond = errorsPerSecond
        self.sustainedSamples = max(1, sustainedSamples)
        self.resolveSamples = max(1, resolveSamples)
    }
}

/// A single flood event with lifecycle. Re-published as it transitions; the
/// notification/purpose layer alerts on `.started`, may update on `.ongoing`,
/// and clears on `.resolved`.
public struct NetworkFloodEvent: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var phase: NetworkFloodPhase
    public var classification: NetworkFloodClass
    public var startedAt: String
    public var updatedAt: String
    public var resolvedAt: String?
    public var peakPacketsPerSecond: Int
    public var peakMegabitsPerSecond: Double
    public var capturePath: String?
    public var summary: String
    public var acknowledged: Bool

    public init(
        id: String = UUID().uuidString,
        phase: NetworkFloodPhase,
        classification: NetworkFloodClass,
        startedAt: String,
        updatedAt: String,
        resolvedAt: String? = nil,
        peakPacketsPerSecond: Int,
        peakMegabitsPerSecond: Double,
        capturePath: String? = nil,
        summary: String,
        acknowledged: Bool = false
    ) {
        self.id = id
        self.phase = phase
        self.classification = classification
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.resolvedAt = resolvedAt
        self.peakPacketsPerSecond = peakPacketsPerSecond
        self.peakMegabitsPerSecond = peakMegabitsPerSecond
        self.capturePath = capturePath
        self.summary = summary
        self.acknowledged = acknowledged
    }
}

/// The full read-only projection the cell exposes and the bridge stores.
public struct NetworkHealthSnapshot: Codable, Sendable, Equatable {
    public var interface: String
    public var status: String
    public var latest: NetworkHealthSample?
    public var activeEvent: NetworkFloodEvent?
    public var recentEvents: [NetworkFloodEvent]
    public var notificationsEnabled: Bool
    public var thresholds: NetworkSentinelThresholds
    public var updatedAt: String

    public init(
        interface: String,
        status: String,
        latest: NetworkHealthSample?,
        activeEvent: NetworkFloodEvent?,
        recentEvents: [NetworkFloodEvent],
        notificationsEnabled: Bool,
        thresholds: NetworkSentinelThresholds,
        updatedAt: String
    ) {
        self.interface = interface
        self.status = status
        self.latest = latest
        self.activeEvent = activeEvent
        self.recentEvents = recentEvents
        self.notificationsEnabled = notificationsEnabled
        self.thresholds = thresholds
        self.updatedAt = updatedAt
    }
}

/// Control surface the cell uses to push operator changes down to the running
/// measurement service. The service registers itself on the bridge at startup,
/// keeping automation/measurement out of the cell while the cell stays the
/// authoritative protocol surface for `notificationsEnabled` and thresholds.
public protocol NetworkSentinelControlling: Sendable {
    func setNotificationsEnabled(_ enabled: Bool) async
    func setThresholds(_ thresholds: NetworkSentinelThresholds) async
    func acknowledgeActiveEvent() async -> Bool
}
