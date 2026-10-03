import XCTest
import CellBase
import LocalAuthentication
@testable import CellApple
@testable import Binding

@MainActor
final class AuthenticationAttemptTests: XCTestCase {
    func testPasswordChoiceAllowsFallbackWhileCancellationAndFailureStop() {
        for code: LAError.Code in [.userFallback, .biometryLockout, .biometryNotAvailable, .biometryNotEnrolled] {
            XCTAssertTrue(IdentityVault.shouldUsePasswordFallback(after: code))
        }
        for code: LAError.Code in [.userCancel, .systemCancel, .appCancel, .authenticationFailed, .invalidContext, .notInteractive] {
            XCTAssertFalse(IdentityVault.shouldUsePasswordFallback(after: code))
        }
    }

    func testDeclinedAuthenticationStopsUntilExplicitRetryAndNeverRegisters() async {
        var authenticationCalls = 0
        var registrationCalls = 0
        var allowsAuthentication = false
        let attempt = BindingAuthenticatedRuntimeAttempt(authenticate: {
            authenticationCalls += 1
            return allowsAuthentication
        }, register: { registrationCalls += 1; return true })

        for _ in 0..<60 {
            let outcome = await attempt.run()
            XCTAssertEqual(outcome, .authenticationUnavailable)
        }
        XCTAssertEqual(authenticationCalls, 1)
        XCTAssertEqual(registrationCalls, 0)

        allowsAuthentication = true
        let outcome = await attempt.run(retryAfterFailure: true)
        XCTAssertEqual(outcome, .ready)
        XCTAssertEqual(authenticationCalls, 2)
        XCTAssertEqual(registrationCalls, 1)
    }

    func testConcurrentConsumersShareOneAuthenticationAttempt() async {
        var calls = 0
        var resumeAuthentication: CheckedContinuation<Bool, Never>?
        let started = expectation(description: "Authentication requested")
        let attempt = BindingAuthenticatedRuntimeAttempt(authenticate: {
            calls += 1
            return await withCheckedContinuation { continuation in
                resumeAuthentication = continuation
                started.fulfill()
            }
        }, register: { XCTFail("Declined authentication must not register runtime"); return true })
        let tasks = (0..<8).map { _ in Task { await attempt.run() } }
        await fulfillment(of: [started], timeout: 2)
        resumeAuthentication?.resume(returning: false)
        for task in tasks {
            let outcome = await task.value
            XCTAssertEqual(outcome, .authenticationUnavailable)
        }
        XCTAssertEqual(calls, 1)
    }

    func testRegistrationFailureIsNotTreatedAsAuthenticationSuccess() async {
        var authentications = 0
        var registrations = 0
        let attempt = BindingAuthenticatedRuntimeAttempt(authenticate: {
            authentications += 1; return true
        }, register: { registrations += 1; return false })
        for _ in 0..<10 {
            let result = await attempt.run()
            XCTAssertEqual(result, .registrationUnavailable)
        }
        XCTAssertEqual(authentications, 1)
        XCTAssertEqual(registrations, 1)
    }

    func testAlreadyCancelledLoadDoesNotStartAuthentication() async {
        var calls = 0
        var release: CheckedContinuation<Void, Never>?
        let waiting = expectation(description: "Load queued")
        let attempt = BindingAuthenticatedRuntimeAttempt(authenticate: { calls += 1; return true }, register: { true })
        let task = Task {
            await withCheckedContinuation { continuation in
                release = continuation
                waiting.fulfill()
            }
            return await attempt.run(retryAfterFailure: true)
        }
        await fulfillment(of: [waiting], timeout: 2)
        task.cancel()
        release?.resume()
        let outcome = await task.value
        XCTAssertEqual(outcome, .cancelled)
        XCTAssertEqual(calls, 0)
    }

    func testLibraryRefreshAndRepeatedAppearanceDoNotReopenDeclinedAuthentication() async {
        var calls = 0
        let attempt = BindingAuthenticatedRuntimeAttempt(authenticate: {
            calls += 1; return false
        }, register: { XCTFail("No registration after declined authentication"); return false })
        let scanner = ConfigurationCatalogCell.entityScannerWorkbenchConfiguration()
        let model = FullLibraryViewModel(catalogEndpoints: ["cell:///ConfigurationCatalog"],
            queryContext: FullLibraryQueryContext(editMode: false, selectedNodeKind: nil, insertionIntent: .unknown),
            fallbackFavorites: [scanner], fallbackTemplates: [],
            bootstrapRuntime: { await attempt.run(retryAfterFailure: $0) })
        await model.loadInitial()
        for _ in 0..<20 {
            await model.refreshNow()
            await model.loadInitial()
        }
        XCTAssertEqual(calls, 1)
        XCTAssertFalse(model.isLoading)
        XCTAssertTrue(model.statusLine.contains("Autentisering stoppet"))
        XCTAssertTrue(model.statusLine.contains("Oppdater"))
        XCTAssertEqual(model.results.first?.configuration.name, scanner.name)
        await model.refreshNow(retryAuthentication: true)
        XCTAssertEqual(calls, 2)
    }

    func testScannerRemainsOnLocalRuntimePathWhileRemoteSurfacesRequireAuthentication() {
        let view = ContentView()
        XCTAssertFalse(view.requiresAuthenticatedRuntimeBootstrap(ConfigurationCatalogCell.entityScannerWorkbenchConfiguration()))
        XCTAssertTrue(view.requiresAuthenticatedRuntimeBootstrap(ConfigurationCatalogCell.personalPublicProfileMenuConfiguration()))
    }
}
