import Foundation

/// Decides one next channel; it does not send, acknowledge or create authority.
/// Endpoint admission and the per-event delivery ledger must be loaded under the
/// entity's authorized context. The caller must atomically claim an attempt before
/// sending; two scaffolds running this pure function do not provide deduplication.
public enum NotificationRouter {
    public enum Channel: String, Codable, Sendable { case inApp, apns, webPush }
    public struct Endpoint: Codable, Sendable {
        public var id: String
        public var entityContext: String
        public var channel: Channel
        public var admittedUntil: Date?
        public var permissionGranted: Bool
        public var providerReady: Bool
        public var revoked: Bool
        public var foregroundObservedAt: Date?
        public var preference: Int // Smaller is preferred by the user.
    }
    public enum Delivery: Sendable {
        case notAttempted
        case awaitingReceipt(until: Date)
        case acknowledged
        case failed
    }
    public enum Decision: Equatable, Sendable {
        case send(endpointID: String, channel: Channel)
        case wait
        case suppressed(String)
        case unavailable
    }
    public static func choose(endpoints: [Endpoint], entityContext: String,
                              now: Date, expiresAt: Date, quietHours: Bool,
                              urgent: Bool, userAllowsUrgentInterruption: Bool,
                              delivery: Delivery, attempted: Set<String> = []) -> Decision {
        guard !entityContext.isEmpty, now.timeIntervalSince1970.isFinite,
              expiresAt.timeIntervalSince1970.isFinite, expiresAt > now else { return .suppressed("expired_or_invalid") }
        switch delivery {
        case .acknowledged: return .suppressed("acknowledged")
        case let .awaitingReceipt(until):
            // Invalid ledger evidence must not fan out another notification.
            guard until.timeIntervalSince1970.isFinite else { return .suppressed("invalid_receipt_deadline") }
            if until > now { return .wait }
        case .notAttempted, .failed: break
        }
        if quietHours && !(urgent && userAllowsUrgentInterruption) { return .suppressed("quiet_hours") }
        guard Set(endpoints.map(\.id)).count == endpoints.count else { return .suppressed("duplicate_endpoint") }
        func foreground(_ endpoint: Endpoint) -> Bool {
            endpoint.foregroundObservedAt.map { date in
                date.timeIntervalSince1970.isFinite && date <= now && now.timeIntervalSince(date) <= 30
            } ?? false
        }
        let eligible = endpoints.filter {
            !$0.id.isEmpty && $0.entityContext == entityContext && !$0.revoked
                && $0.admittedUntil.map { $0.timeIntervalSince1970.isFinite && $0 > now } == true
                && $0.permissionGranted && $0.providerReady && !attempted.contains($0.id)
                && ($0.channel != .inApp || foreground($0))
        }.sorted {
            let leftActive = $0.channel == .inApp && foreground($0)
            let rightActive = $1.channel == .inApp && foreground($1)
            if leftActive != rightActive { return leftActive }
            if $0.preference != $1.preference { return $0.preference < $1.preference }
            return $0.id < $1.id
        }
        guard let selected = eligible.first else { return .unavailable }
        return .send(endpointID: selected.id, channel: selected.channel)
    }
}
