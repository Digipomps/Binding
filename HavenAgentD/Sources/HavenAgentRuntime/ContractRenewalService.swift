import Foundation
import HavenRuntimeBootstrap

public struct ContractRenewalStatus: Codable, Equatable, Sendable {
    public var scaffoldDomain: String
    public var requestedPortholeKind: String
    public var renewalLeadTimeSeconds: Int
    public var status: String
    public var contractID: String?
    public var artifactExpiresAt: String?
    public var lastRenewedAt: String?
    public var nextRetryAt: String?
    public var retryCount: Int?
    public var lastError: String?

    public init(
        scaffoldDomain: String,
        requestedPortholeKind: String,
        renewalLeadTimeSeconds: Int,
        status: String,
        contractID: String? = nil,
        artifactExpiresAt: String? = nil,
        lastRenewedAt: String? = nil,
        nextRetryAt: String? = nil,
        retryCount: Int? = nil,
        lastError: String? = nil
    ) {
        self.scaffoldDomain = scaffoldDomain
        self.requestedPortholeKind = requestedPortholeKind
        self.renewalLeadTimeSeconds = renewalLeadTimeSeconds
        self.status = status
        self.contractID = contractID
        self.artifactExpiresAt = artifactExpiresAt
        self.lastRenewedAt = lastRenewedAt
        self.nextRetryAt = nextRetryAt
        self.retryCount = retryCount
        self.lastError = lastError
    }
}

public actor ContractRenewalService {
    private var currentPlan: SproutBootstrapPlan?
    private var currentStatus: ContractRenewalStatus?

    public init() {}

    public func update(plan: SproutBootstrapPlan) {
        currentPlan = plan
        currentStatus = ContractRenewalStatus(
            scaffoldDomain: plan.scaffoldDomain,
            requestedPortholeKind: plan.requestedPortholeKind,
            renewalLeadTimeSeconds: plan.renewalLeadTimeSeconds,
            status: "planned"
        )
    }

    public func markRenewed(
        contractID: String,
        artifactExpiresAt: String,
        renewedAt: String
    ) {
        guard let currentPlan else {
            return
        }
        currentStatus = ContractRenewalStatus(
            scaffoldDomain: currentPlan.scaffoldDomain,
            requestedPortholeKind: currentPlan.requestedPortholeKind,
            renewalLeadTimeSeconds: currentPlan.renewalLeadTimeSeconds,
            status: "renewed",
            contractID: contractID,
            artifactExpiresAt: artifactExpiresAt,
            lastRenewedAt: renewedAt,
            nextRetryAt: nil,
            retryCount: nil,
            lastError: nil
        )
    }

    public func markConnected(
        contractID: String,
        artifactExpiresAt: String
    ) {
        guard let currentPlan else {
            return
        }
        currentStatus = ContractRenewalStatus(
            scaffoldDomain: currentPlan.scaffoldDomain,
            requestedPortholeKind: currentPlan.requestedPortholeKind,
            renewalLeadTimeSeconds: currentPlan.renewalLeadTimeSeconds,
            status: "connected",
            contractID: contractID,
            artifactExpiresAt: artifactExpiresAt,
            lastRenewedAt: currentStatus?.lastRenewedAt,
            nextRetryAt: nil,
            retryCount: nil,
            lastError: nil
        )
    }

    public func markRenewalDue(
        contractID: String,
        artifactExpiresAt: String
    ) {
        guard let currentPlan else {
            return
        }
        currentStatus = ContractRenewalStatus(
            scaffoldDomain: currentPlan.scaffoldDomain,
            requestedPortholeKind: currentPlan.requestedPortholeKind,
            renewalLeadTimeSeconds: currentPlan.renewalLeadTimeSeconds,
            status: "renewal_due",
            contractID: contractID,
            artifactExpiresAt: artifactExpiresAt,
            lastRenewedAt: currentStatus?.lastRenewedAt,
            nextRetryAt: nil,
            retryCount: nil,
            lastError: nil
        )
    }

    public func markRetryScheduled(
        contractID: String?,
        artifactExpiresAt: String?,
        nextRetryAt: String?,
        retryCount: Int,
        lastError: String
    ) {
        guard let currentPlan else {
            return
        }
        currentStatus = ContractRenewalStatus(
            scaffoldDomain: currentPlan.scaffoldDomain,
            requestedPortholeKind: currentPlan.requestedPortholeKind,
            renewalLeadTimeSeconds: currentPlan.renewalLeadTimeSeconds,
            status: "retry_scheduled",
            contractID: contractID,
            artifactExpiresAt: artifactExpiresAt,
            lastRenewedAt: currentStatus?.lastRenewedAt,
            nextRetryAt: nextRetryAt,
            retryCount: retryCount,
            lastError: lastError
        )
    }

    public func markFailed(
        contractID: String?,
        artifactExpiresAt: String?,
        lastError: String
    ) {
        guard let currentPlan else {
            return
        }
        currentStatus = ContractRenewalStatus(
            scaffoldDomain: currentPlan.scaffoldDomain,
            requestedPortholeKind: currentPlan.requestedPortholeKind,
            renewalLeadTimeSeconds: currentPlan.renewalLeadTimeSeconds,
            status: "failed",
            contractID: contractID,
            artifactExpiresAt: artifactExpiresAt,
            lastRenewedAt: currentStatus?.lastRenewedAt,
            nextRetryAt: nil,
            retryCount: currentStatus?.retryCount,
            lastError: lastError
        )
    }

    public func markStopped() {
        guard let currentPlan else {
            return
        }
        currentStatus = ContractRenewalStatus(
            scaffoldDomain: currentPlan.scaffoldDomain,
            requestedPortholeKind: currentPlan.requestedPortholeKind,
            renewalLeadTimeSeconds: currentPlan.renewalLeadTimeSeconds,
            status: "stopped",
            contractID: currentStatus?.contractID,
            artifactExpiresAt: currentStatus?.artifactExpiresAt,
            lastRenewedAt: currentStatus?.lastRenewedAt,
            nextRetryAt: nil,
            retryCount: nil,
            lastError: currentStatus?.lastError
        )
    }

    public func status() -> ContractRenewalStatus? {
        currentStatus
    }
}
