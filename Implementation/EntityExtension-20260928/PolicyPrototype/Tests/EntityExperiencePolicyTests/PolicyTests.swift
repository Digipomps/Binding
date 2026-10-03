import Foundation
import Testing
@testable import EntityExperiencePolicy

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private func policy() -> PlacementPlanner.Policy {
    .init(entityContext: "owner-domain", requiredCapabilities: ["read", "write", "index", "store"],
          allowedJurisdictions: ["NO"], replicas: 2, minimumAvailability: 0.9,
          maximumObservationAge: 60, costBudget: 100, latencyScaleMS: 1_000,
          availabilityWeight: 4, latencyWeight: 1, costWeight: 1, energyWeight: 1,
          switchImprovement: 0.1, switchCooldown: 600)
}
private func candidate(_ id: String, cost: Double = 10) -> PlacementPlanner.Candidate {
    .init(id: id, failureDomain: id, jurisdiction: "NO", entityContext: "owner-domain",
          admittedUntil: now.addingTimeInterval(600), capabilities: ["read", "write", "index", "store"],
          reachable: true, observedAt: now, availability: 0.99, latencyMS: 20,
          monthlyCost: cost, energy: 0.1)
}
@Test func cheapScaffoldWithoutAuthorityNeverWins() {
    var cheap = candidate("cheap", cost: 0); cheap.admittedUntil = nil
    let result = PlacementPlanner.plan([cheap, candidate("phone"), candidate("server")], policy: policy(), now: now)
    #expect(result.selected == ["phone", "server"])
    #expect(result.rejected["cheap"] == "no_current_admission")
}
@Test func readDoesNotImplyWriteIndexOrStorage() {
    for absent in ["write", "index", "store"] {
        var c = candidate("partial"); c.capabilities.remove(absent)
        let result = PlacementPlanner.plan([c, candidate("server")], policy: policy(), now: now)
        #expect(result.reason == "no_feasible_plan")
        #expect(result.rejected["partial"] == "missing_capability")
    }
}
@Test func differentEntityOrJurisdictionAndStaleMetricsAreRejected() {
    var wrong = candidate("wrong"); wrong.entityContext = "someone-else"
    var abroad = candidate("abroad"); abroad.jurisdiction = "other"
    var stale = candidate("stale"); stale.observedAt = now.addingTimeInterval(-61)
    var future = candidate("future"); future.observedAt = now.addingTimeInterval(1)
    let result = PlacementPlanner.plan([wrong, abroad, stale, future], policy: policy(), now: now)
    #expect(result.selected.isEmpty)
    #expect(result.rejected.count == 4)
}
@Test func sameFailureDomainCannotMasqueradeAsTwoReplicas() {
    var staging = candidate("staging"); staging.failureDomain = "one-server"
    var prod = candidate("prod"); prod.failureDomain = "one-server"
    #expect(PlacementPlanner.plan([staging, prod], policy: policy(), now: now).selected.isEmpty)
}
@Test func selectionIsOptimalWithinBoundAndIndependentOfDiscoveryOrder() {
    let list = [candidate("c", cost: 30), candidate("b", cost: 10), candidate("a", cost: 10)]
    let forward = PlacementPlanner.plan(list, policy: policy(), now: now)
    let backward = PlacementPlanner.plan(list.reversed(), policy: policy(), now: now)
    #expect(forward == backward)
    #expect(forward.selected == ["a", "b"])
    var budget = policy(); budget.costBudget = 19
    #expect(PlacementPlanner.plan(list, policy: budget, now: now).reason == "no_feasible_plan")
}
@Test func cooldownNeverKeepsAnExpiredGrant() {
    let current: Set<String> = ["phone", "old"]
    var old = candidate("old"); old.admittedUntil = now
    let result = PlacementPlanner.plan([candidate("phone"), old, candidate("new")], policy: policy(), now: now,
                                       current: current, lastChange: now)
    #expect(result.selected == ["new", "phone"])
}
@Test func validCurrentPlanDoesNotThrashForSmallGain() {
    let list = [candidate("phone"), candidate("old", cost: 11), candidate("new", cost: 10)]
    let result = PlacementPlanner.plan(list, policy: policy(), now: now, current: ["phone", "old"])
    #expect(result.selected == ["old", "phone"])
    #expect(result.reason == "retain_valid_current_plan")
}
@Test func invalidAndUnboundedInputsFailClosed() {
    #expect(PlacementPlanner.plan([candidate("same"), candidate("same")], policy: policy(), now: now).reason == "duplicate_candidate")
    #expect(PlacementPlanner.plan((0..<17).map { candidate("\($0)") }, policy: policy(), now: now).reason == "candidate_limit_exceeded")
    var p = policy(); p.costWeight = .nan
    #expect(PlacementPlanner.plan([], policy: p, now: now).reason == "invalid_policy")
    var bad = candidate("bad"); bad.latencyMS = .infinity
    #expect(PlacementPlanner.plan([bad], policy: policy(), now: now).rejected["bad"] == "invalid_metrics")
}
private func endpoint(_ id: String, _ channel: NotificationRouter.Channel, preference: Int = 1) -> NotificationRouter.Endpoint {
    .init(id: id, entityContext: "owner-domain", channel: channel,
          admittedUntil: now.addingTimeInterval(600), permissionGranted: true,
          providerReady: true, revoked: false, foregroundObservedAt: nil, preference: preference)
}
private func route(_ endpoints: [NotificationRouter.Endpoint], delivery: NotificationRouter.Delivery = .notAttempted,
                   attempted: Set<String> = [], quiet: Bool = false, urgent: Bool = false, allowUrgent: Bool = false) -> NotificationRouter.Decision {
    NotificationRouter.choose(endpoints: endpoints, entityContext: "owner-domain", now: now,
                              expiresAt: now.addingTimeInterval(300), quietHours: quiet,
                              urgent: urgent, userAllowsUrgentInterruption: allowUrgent,
                              delivery: delivery, attempted: attempted)
}
@Test func activeSurfaceWinsThenUserPreferredBrowserThenPhone() {
    var active = endpoint("active", .inApp, preference: 9); active.foregroundObservedAt = now
    let web = endpoint("web", .webPush, preference: 0)
    let phone = endpoint("phone", .apns)
    #expect(route([phone, web, active]) == .send(endpointID: "active", channel: .inApp))
    active.foregroundObservedAt = now.addingTimeInterval(-31)
    #expect(route([phone, web, active]) == .send(endpointID: "web", channel: .webPush))
    #expect(route([phone, web], delivery: .failed, attempted: ["web"]) == .send(endpointID: "phone", channel: .apns))
}
@Test func missingBrowserPermissionRevocationAndOtherEntityNeverReceive() {
    var web = endpoint("web", .webPush); web.permissionGranted = false
    var phone = endpoint("phone", .apns); phone.revoked = true
    var other = endpoint("other", .apns); other.entityContext = "someone-else"
    #expect(route([web, phone, other]) == .unavailable)
}
@Test func receiptWaitAndAcknowledgementPreventImmediateFanout() {
    let endpoints = [endpoint("web", .webPush), endpoint("phone", .apns)]
    #expect(route(endpoints, delivery: .awaitingReceipt(until: now.addingTimeInterval(30))) == .wait)
    #expect(route(endpoints, delivery: .acknowledged) == .suppressed("acknowledged"))
}
@Test func urgencyDoesNotInventPermissionToInterrupt() {
    let endpoints = [endpoint("phone", .apns)]
    #expect(route(endpoints, quiet: true, urgent: true) == .suppressed("quiet_hours"))
    #expect(route(endpoints, quiet: true, urgent: true, allowUrgent: true) == .send(endpointID: "phone", channel: .apns))
}

@Test func invalidAdmissionExpiryCannotGrantPlacementOrDelivery() {
    var c = candidate("invalid"); c.admittedUntil = Date(timeIntervalSince1970: .infinity)
    #expect(PlacementPlanner.plan([c], policy: policy(), now: now).rejected["invalid"] == "no_current_admission")
    var e = endpoint("invalid", .apns); e.admittedUntil = Date(timeIntervalSince1970: .infinity)
    #expect(route([e]) == .unavailable)
}
