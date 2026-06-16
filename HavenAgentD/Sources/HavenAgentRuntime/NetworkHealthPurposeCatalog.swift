// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
@preconcurrency import CellBase

/// Couples the network sentinel to the CellProtocol Purpose/Goal machinery.
///
/// Instead of a hardcoded popup, a detected flood is turned into a
/// `GoalObservation` and evaluated against a `GoalDefinition` by the shared
/// `GoalEvaluationEngine`. The goal "keep the local link healthy" becomes
/// `at-risk` only when a *harmful* flood is observed (interface distress or an
/// unexplained high packet rate). Benign throughput saturation — a large
/// download that fully uses the link with no errors — evaluates as `satisfied`,
/// so it is recorded but never interrupts the operator.
///
/// This is what makes the alert a *purpose match* (`formål`): notification is
/// gated on the goal evaluation, not on raw thresholds.
public enum NetworkHealthPurposeCatalog {
    public static let purposeRef = "purpose://haven.network.health"
    public static let goalID = "goal.haven.network.health.no-harmful-flood"
    public static let evidenceSourceID = "network-sentinel"
    public static let sentinelEndpoint = "cell:///agent/network/sentinel"

    public static let defaultInterests = ["haven.local.network", "haven.local.health", "haven.local.security"]
    public static let purposeTitle = "Keep the local link healthy"
    public static let purposeDescription = """
    The home link stays healthy. A harmful flood — rising interface errors, or an \
    unexplained high packet rate — puts this goal at risk and is surfaced to the \
    operator. Benign throughput saturation (for example a large download) does not.
    """

    /// Classifications that represent a *harmful* flood worth the operator's attention.
    public static func isHarmful(_ classification: NetworkFloodClass) -> Bool {
        switch classification {
        case .interfaceDistress, .highPacketRate, .bulkUpload:
            return true
        case .bulkDownload, .unknown:
            return false
        }
    }

    /// The canonical goal definition evaluated by the engine. Evidence is the local
    /// sentinel cell's flood topic; the `.networkPing` evaluator maps a harmful-flood
    /// "failure" count onto at-risk / missed via the status policy.
    public static func goalDefinition(
        purpose: String = purposeRef,
        atRiskAfterFailures: Int = 1,
        missedAfterFailures: Int = 3
    ) -> GoalDefinition {
        GoalDefinition(
            goalID: goalID,
            purposeRef: purpose,
            title: purposeTitle,
            description: purposeDescription,
            lifecycle: .continuous,
            evaluatorKind: .networkPing,
            evidenceSources: [
                GoalEvidenceSource(
                    sourceID: evidenceSourceID,
                    endpoint: sentinelEndpoint,
                    topic: NetworkSentinelFlowTopics.flood,
                    eventType: NetworkSentinelFlowTopics.detected,
                    freshnessSeconds: 30,
                    visibility: .ownerOnly,
                    summary: "Local network sentinel link-health observations."
                )
            ],
            statusPolicy: GoalStatusPolicy(
                atRiskAfterFailures: max(1, atRiskAfterFailures),
                missedAfterFailures: max(atRiskAfterFailures + 1, missedAfterFailures)
            ),
            tags: ["network", "health", "local"]
        )
    }

    /// Builds the goal observation from the current sentinel snapshot. A harmful,
    /// non-resolved active event counts as a "failure" against the health goal.
    public static func observation(
        snapshot: NetworkHealthSnapshot,
        transition: NetworkFloodEvent?
    ) -> GoalObservation {
        let active = snapshot.activeEvent
        let harmfulActive = active.map { $0.phase != .resolved && isHarmful($0.classification) } ?? false
        let failures = harmfulActive ? (active?.phase == .ongoing ? 2 : 1) : 0
        let classification = active?.classification ?? transition?.classification ?? .unknown

        return GoalObservation(
            sourceID: evidenceSourceID,
            // An unreadable interface is "stale evidence" — the engine maps that to
            // .unknown (not a flood, but not a clean bill of health either).
            status: snapshot.status == "unavailable" ? .stale : .fresh,
            observedAt: snapshot.updatedAt,
            value: snapshot.status,
            labels: [classification.rawValue],
            eventTypes: transition.map { _ in [NetworkSentinelFlowTopics.detected] } ?? [],
            consecutiveFailures: failures,
            confidence: 0.9,
            summary: active?.summary ?? "Link healthy."
        )
    }

    /// Evaluates the network-health goal against the current snapshot.
    public static func evaluate(
        snapshot: NetworkHealthSnapshot,
        transition: NetworkFloodEvent?,
        evaluatedAt: String? = nil
    ) -> GoalEvaluation {
        let when = evaluatedAt ?? ISO8601DateFormatter().string(from: Date())
        return GoalEvaluationEngine.evaluate(
            definition: goalDefinition(),
            observations: [observation(snapshot: snapshot, transition: transition)],
            evaluatedAt: when
        )
    }

    /// Whether the evaluation warrants actively interrupting the operator.
    public static func warrantsNotification(_ evaluation: GoalEvaluation) -> Bool {
        evaluation.status == .atRisk || evaluation.status == .missed
    }
}
