import Foundation

/// One user-requested authentication attempt, shared by concurrent consumers.
/// A failed attempt stays stopped until a new explicit user action retries it.
/// This schedules bootstrap; it never grants access or substitutes an identity.
@MainActor
final class BindingAuthenticatedRuntimeAttempt {
    enum Outcome: Equatable, Sendable {
        case ready, authenticationUnavailable, registrationUnavailable, cancelled
    }

    private let authenticate: () async -> Bool
    private let register: () async -> Bool
    private var inFlight: Task<Outcome, Never>?
    private var stoppedOutcome: Outcome?

    init(authenticate: @escaping () async -> Bool, register: @escaping () async -> Bool) {
        self.authenticate = authenticate
        self.register = register
    }

    func run(retryAfterFailure: Bool = false) async -> Outcome {
        guard !Task.isCancelled else { return .cancelled }
        if let inFlight {
            let outcome = await inFlight.value
            return Task.isCancelled ? .cancelled : outcome
        }
        if let stoppedOutcome, !retryAfterFailure { return stoppedOutcome }
        stoppedOutcome = nil
        let task = Task { @MainActor [authenticate, register] in
            guard await authenticate() else { return Outcome.authenticationUnavailable }
            guard await register() else { return Outcome.registrationUnavailable }
            return Outcome.ready
        }
        inFlight = task
        let outcome = await task.value
        inFlight = nil
        if outcome != .ready { stoppedOutcome = outcome }
        return Task.isCancelled ? .cancelled : outcome
    }
}

extension BindingRuntimeBootstrap {
    @MainActor
    private static let authenticatedAttempt = BindingAuthenticatedRuntimeAttempt(
        authenticate: {
            await ensureBaseline()
            return authenticatedRuntimeIsReady
        },
        register: { await BindingLocalCellRegistration.shared.ensureRegistered() }
    )

    @MainActor
    static func requestAuthenticatedRuntime(retryAfterFailure: Bool = false) async -> BindingAuthenticatedRuntimeAttempt.Outcome {
        if authenticatedRuntimeIsReady {
            return await BindingLocalCellRegistration.shared.ensureRegistered() ? .ready : .registrationUnavailable
        }
        return await authenticatedAttempt.run(retryAfterFailure: retryAfterFailure)
    }
}
