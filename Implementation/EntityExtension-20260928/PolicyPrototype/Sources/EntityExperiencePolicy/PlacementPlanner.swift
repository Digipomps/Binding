import Foundation

/// Advisory only. No identity, grants, transport or persistent mutations are created.
/// The host must populate admission from the resolver's current verified evidence,
/// never from an untrusted discovery advertisement, and revalidate before execution.
public enum PlacementPlanner {
    public struct Candidate: Codable, Sendable {
        public var id: String
        public var failureDomain: String
        public var jurisdiction: String
        public var entityContext: String
        public var admittedUntil: Date?
        public var capabilities: Set<String>
        public var reachable: Bool
        public var observedAt: Date
        public var availability: Double // Measured [0, 1], not a guarantee.
        public var latencyMS: Double
        public var monthlyCost: Double
        public var energy: Double // Host-normalized [0, 1].
    }
    public struct Policy: Codable, Sendable {
        public var entityContext: String
        public var requiredCapabilities: Set<String>
        public var allowedJurisdictions: Set<String>
        public var replicas: Int
        public var minimumAvailability: Double
        public var maximumObservationAge: TimeInterval
        public var costBudget: Double
        public var latencyScaleMS: Double
        public var availabilityWeight: Double
        public var latencyWeight: Double
        public var costWeight: Double
        public var energyWeight: Double
        public var switchImprovement: Double
        public var switchCooldown: TimeInterval
    }
    public struct Plan: Equatable, Sendable {
        public var selected: [String]
        public var rejected: [String: String]
        public var reason: String
        public var score: Double?
    }

    /// Exhaustive minimum-score choice for at most 16 candidates. Bound is explicit
    /// to avoid exponential work in a UI. Replica independence is a hard constraint;
    /// this does not multiply availability probabilities or promise combined uptime.
    public static func plan(_ candidates: [Candidate], policy p: Policy, now: Date,
                            current: Set<String> = [], lastChange: Date? = nil) -> Plan {
        func invalid(_ reason: String) -> Plan { Plan(selected: [], rejected: [:], reason: reason, score: nil) }
        let numbers = [p.minimumAvailability, p.maximumObservationAge, p.costBudget,
                       p.latencyScaleMS, p.availabilityWeight, p.latencyWeight, p.costWeight,
                       p.energyWeight, p.switchImprovement, p.switchCooldown]
        guard numbers.allSatisfy({ $0.isFinite && $0 >= 0 }),
              (0...1).contains(p.minimumAvailability), p.latencyScaleMS > 0,
              p.replicas > 0, p.replicas <= 16, !p.entityContext.isEmpty,
              !p.requiredCapabilities.isEmpty, !p.allowedJurisdictions.isEmpty,
              p.availabilityWeight + p.latencyWeight + p.costWeight + p.energyWeight > 0,
              now.timeIntervalSince1970.isFinite else { return invalid("invalid_policy") }
        guard candidates.count <= 16 else { return invalid("candidate_limit_exceeded") }
        guard Set(candidates.map(\.id)).count == candidates.count else { return invalid("duplicate_candidate") }
        var rejected: [String: String] = [:]
        let eligible = candidates.sorted { $0.id < $1.id }.filter { c in
            let reason: String?
            if c.id.isEmpty || c.failureDomain.isEmpty { reason = "missing_identity_or_failure_domain" }
            else if c.entityContext != p.entityContext { reason = "wrong_entity_context" }
            else if c.admittedUntil.map({ $0.timeIntervalSince1970.isFinite && $0 > now }) != true { reason = "no_current_admission" }
            else if !p.requiredCapabilities.isSubset(of: c.capabilities) { reason = "missing_capability" }
            else if !p.allowedJurisdictions.contains(c.jurisdiction) { reason = "jurisdiction" }
            else if !c.reachable { reason = "unreachable" }
            else if !c.observedAt.timeIntervalSince1970.isFinite || c.observedAt > now || now.timeIntervalSince(c.observedAt) > p.maximumObservationAge { reason = "stale_observation" }
            else if ![c.availability, c.latencyMS, c.monthlyCost, c.energy].allSatisfy({ $0.isFinite && $0 >= 0 }) || c.availability > 1 || c.energy > 1 { reason = "invalid_metrics" }
            else if c.availability < p.minimumAvailability { reason = "availability" }
            else { reason = nil }
            if let reason { rejected[c.id] = reason; return false }
            return true
        }
        func score(_ set: [Candidate]) -> Double? {
            guard set.count == p.replicas, Set(set.map(\.failureDomain)).count == set.count else { return nil }
            let cost = set.reduce(0) { $0 + $1.monthlyCost }
            guard cost.isFinite, cost <= p.costBudget else { return nil }
            // Worst selected latency and availability, plus total cost and energy.
            let total = p.availabilityWeight * (1 - (set.map(\.availability).min() ?? 0))
                + p.latencyWeight * min(1, (set.map(\.latencyMS).max() ?? 0) / p.latencyScaleMS)
                + p.costWeight * (p.costBudget == 0 ? 0 : cost / p.costBudget)
                + p.energyWeight * set.reduce(0) { $0 + $1.energy } / Double(set.count)
            return total.isFinite ? total : nil
        }
        var best: [Candidate] = []
        var bestScore = Double.infinity
        for mask in 0..<(1 << eligible.count) where mask.nonzeroBitCount == p.replicas {
            let set = eligible.enumerated().compactMap { (mask & (1 << $0.offset)) != 0 ? $0.element : nil }
            if let value = score(set), value < bestScore || (value == bestScore && set.map(\.id).lexicographicallyPrecedes(best.map(\.id))) {
                best = set; bestScore = value
            }
        }
        guard bestScore.isFinite else { return Plan(selected: [], rejected: rejected, reason: "no_feasible_plan", score: nil) }
        let existing = eligible.filter { current.contains($0.id) }
        if Set(existing.map(\.id)) == current, let previousScore = score(existing) {
            let coolingDown = lastChange.map { $0 <= now && now.timeIntervalSince($0) < p.switchCooldown } ?? false
            if coolingDown || previousScore - bestScore <= p.switchImprovement {
                return Plan(selected: existing.map(\.id), rejected: rejected, reason: "retain_valid_current_plan", score: previousScore)
            }
        }
        return Plan(selected: best.map(\.id), rejected: rejected, reason: "proposed_requires_revalidation", score: bestScore)
    }
}
