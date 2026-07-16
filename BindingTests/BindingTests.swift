//
//  BindingTests.swift
//  BindingTests
//
//  Created by Kjetil Hustveit on 16/12/2025.
//

import Foundation
import XCTest
import Testing
import SwiftUI
import CryptoKit
#if canImport(AppKit)
import AppKit
#endif
@_spi(Testing) import CellBase
@_spi(Testing) @testable import CellApple
@testable import Binding

private enum AgreementOrderingBridgeTransportError: Error {
    case missingDelegate
}

private final class RuntimeSurfaceLaunchEventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedEvent: BindingRuntimeSurfaceLaunchBridgeEvent?

    func record(_ event: BindingRuntimeSurfaceLaunchBridgeEvent?) {
        lock.lock()
        storedEvent = event
        lock.unlock()
    }

    func event() -> BindingRuntimeSurfaceLaunchBridgeEvent? {
        lock.lock()
        defer { lock.unlock() }
        return storedEvent
    }
}

private actor AgreementOrderingBridgeTransportScript {
    static let shared = AgreementOrderingBridgeTransportScript()

    private var descriptionAttempts = 0
    private var commands: [String] = []
    private var signedAgreementGrantKeypaths: [String] = []
    private var responseErrors: [String] = []

    func reset() {
        descriptionAttempts = 0
        commands = []
        signedAgreementGrantKeypaths = []
        responseErrors = []
    }

    func record(command: String) {
        commands.append(command)
    }

    func nextDescriptionAttempt() -> Int {
        descriptionAttempts += 1
        return descriptionAttempts
    }

    func recordSignedAgreement(_ agreement: Agreement) {
        signedAgreementGrantKeypaths = agreement.grants.map(\.keypath)
    }

    func recordResponseError(_ error: Error) {
        responseErrors.append(String(describing: error))
    }

    func snapshot() -> (commands: [String], signedAgreementGrantKeypaths: [String], responseErrors: [String]) {
        (commands, signedAgreementGrantKeypaths, responseErrors)
    }
}

private final class AgreementOrderingBridgeResponseDelivery: @unchecked Sendable {
    private let delegate: BridgeDelegateProtocol
    private let response: BridgeCommand

    init(delegate: BridgeDelegateProtocol, response: BridgeCommand) {
        self.delegate = delegate
        self.response = response
    }

    func deliver() async {
        do {
            try await Task.sleep(nanoseconds: 250_000_000)
            try await delegate.consumeResponse(command: response)
        } catch {
            await AgreementOrderingBridgeTransportScript.shared.recordResponseError(error)
        }
    }
}

private final class AgreementOrderingBridgeTransport: BridgeTransportProtocol {
    private var delegate: BridgeDelegateProtocol?

    static func new() -> BridgeTransportProtocol {
        AgreementOrderingBridgeTransport()
    }

    func setDelegate(_ delegate: BridgeDelegateProtocol) {
        self.delegate = delegate
    }

    func setup(_ endpointURL: URL, identity: Identity) async throws {
        try await delegate?.consumeCommand(
            command: BridgeCommand(
                cmd: Command.ready.rawValue,
                identity: identity,
                payload: nil,
                cid: 0
            )
        )
    }

    func sendData(_ data: Data) async throws {
        let command = try JSONDecoder().decode(BridgeCommand.self, from: data)
        await AgreementOrderingBridgeTransportScript.shared.record(command: command.cmd)

        switch command.command {
        case .description:
            let attempt = await AgreementOrderingBridgeTransportScript.shared.nextDescriptionAttempt()
            let description = attempt == 1 ? initialDescription() : remoteDescription()
            try await respond(to: command, payload: .description(description))
        case .admit:
            try await respond(to: command, payload: .connectState(.signContract))
        case .agreement:
            if case let .agreementPayload(agreement)? = command.payload {
                await AgreementOrderingBridgeTransportScript.shared.recordSignedAgreement(agreement)
            }
            try await respond(to: command, payload: .contractState(.signed))
        default:
            try await respond(to: command, payload: .string("ok"))
        }
    }

    func identityVault(for: Identity?) async -> IdentityVaultProtocol {
        CellBase.defaultIdentityVault!
    }

    private func respond(to command: BridgeCommand, payload: ValueType) async throws {
        guard let delegate else {
            throw AgreementOrderingBridgeTransportError.missingDelegate
        }
        let response = BridgeCommand(
            cmd: Command.response.rawValue,
            identity: command.identity,
            payload: payload,
            cid: command.cid
        )
        let delivery = AgreementOrderingBridgeResponseDelivery(delegate: delegate, response: response)
        Task.detached {
            await delivery.deliver()
        }
    }

    private func initialDescription() -> AnyCell {
        let remoteOwner = Identity(
            "remote-agreement-owner",
            displayName: "Remote Agreement Owner",
            identityVault: nil
        )
        let agreement = Agreement(owner: remoteOwner)
        agreement.name = "Incomplete Initial Agreement"
        agreement.conditions = []
        agreement.addGrant("r---", for: "initialOnly")
        return AnyCell(
            uuid: "remote-agreement-cell",
            name: "RemoteAgreementCell",
            contractTemplate: agreement,
            owner: remoteOwner,
            identityDomain: "remote-agreement-test"
        )
    }

    private func remoteDescription() -> AnyCell {
        let remoteOwner = Identity(
            "remote-agreement-owner",
            displayName: "Remote Agreement Owner",
            identityVault: nil
        )
        let agreement = Agreement(owner: remoteOwner)
        agreement.name = "Remote Agreement For Binding Test"
        agreement.conditions = []
        agreement.addGrant("r---", for: "state")
        agreement.addGrant("r---", for: "skeletonConfiguration")
        agreement.addGrant("rw--", for: "approveRequest")
        return AnyCell(
            uuid: "remote-agreement-cell",
            name: "RemoteAgreementCell",
            contractTemplate: agreement,
            owner: remoteOwner,
            identityDomain: "remote-agreement-test"
        )
    }
}

private func remoteEndpointAccessAgreementOrderingSnapshot() async throws -> (commands: [String], signedAgreementGrantKeypaths: [String], responseErrors: [String]) {
    let vault = BindingStartupIdentityVault.shared
    _ = await vault.initialize()
    CellBase.defaultIdentityVault = vault
    await BindingRuntimeBootstrap.ensureInfrastructureBaseline()

    let resolver = CellResolver.sharedInstance
    try await resolver.registerTransport(
        AgreementOrderingBridgeTransport.self,
        for: "ws"
    )

    let endpoint = "ws://agreement-order-\(UUID().uuidString).test/RemoteAgreementCell"
    let requester = await vault.identity(
        for: "binding-test-remote-agreement-order",
        makeNewIfNotFound: true
    ) ?? Identity(UUID().uuidString, displayName: "Binding Test", identityVault: vault)
    await AgreementOrderingBridgeTransportScript.shared.reset()

    do {
        _ = try await RemoteEndpointAccessSupport.resolveEmit(
            endpoint: endpoint,
            resolver: resolver,
            requester: requester,
            accessLabel: "agreement-order"
        )
    } catch {
        try? await resolver.registerTransport(LightweightBridgeTransport.self, for: "ws")
        throw error
    }

    try await resolver.registerTransport(LightweightBridgeTransport.self, for: "ws")
    return await AgreementOrderingBridgeTransportScript.shared.snapshot()
}

final class RemoteEndpointAccessAgreementXCTest: XCTestCase {
    func testUsesBridgeAgreementBeforeAdmission() async throws {
        let snapshot = try await remoteEndpointAccessAgreementOrderingSnapshot()
        let firstAdmit = snapshot.commands.firstIndex(of: Command.admit.rawValue)
        let firstAgreement = snapshot.commands.firstIndex(of: Command.agreement.rawValue)
        let secondDescription = snapshot.commands.dropFirst().firstIndex(of: Command.description.rawValue)

        XCTAssertNotNil(secondDescription)
        XCTAssertNotNil(firstAdmit)
        XCTAssertNotNil(firstAgreement)
        if let secondDescription, let firstAdmit {
            XCTAssertLessThan(secondDescription, firstAdmit)
        }
        XCTAssertTrue(snapshot.signedAgreementGrantKeypaths.contains("state"))
        XCTAssertTrue(snapshot.signedAgreementGrantKeypaths.contains("skeletonConfiguration"))
        XCTAssertTrue(snapshot.responseErrors.isEmpty, "Bridge response delivery errors: \(snapshot.responseErrors)")
    }
}

final class PersonalUsageQuotaCellXCTest: XCTestCase {
    func testKeepsTopUpInsideEntitlementBoundary() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
        let resolver = CellResolver.sharedInstance
        CellBase.defaultCellResolver = resolver

        let vault = BindingStartupIdentityVault.shared
        _ = await vault.initialize()
        CellBase.defaultIdentityVault = vault
        let owner = await vault.identity(
            for: "personal-usage-quota-test-\(UUID().uuidString)",
            makeNewIfNotFound: true
        )!

        guard let quota = try await resolver.cellAtEndpoint(
            endpoint: "cell:///PersonalUsageQuota",
            requester: owner
        ) as? Meddle else {
            return XCTFail("Could not resolve PersonalUsageQuota as Meddle")
        }

        guard case let .object(initialState) = try await quota.get(keypath: "state", requester: owner) else {
            return XCTFail("PersonalUsageQuota state was not an object")
        }

        XCTAssertEqual(bindingTestValueString(initialState["productVariant"]), "usage_quota")
        XCTAssertEqual(bindingTestValueString(initialState["transferability"]), "none")
        XCTAssertEqual(bindingTestValueBool(initialState["cashOut"]), false)
        XCTAssertEqual(bindingTestValueBool(initialState["externalAcceptance"]), false)

        guard case let .object(topUp)? = initialState["topUp"] else {
            return XCTFail("PersonalUsageQuota topUp state was not an object")
        }
        XCTAssertEqual(bindingTestValueString(topUp["providerRole"]), "external_top_up_only")
        XCTAssertEqual(bindingTestValueString(topUp["nativePurchaseCTA"]), "disabled")

        let blockedSnapshotResponse = try await quota.set(
            keypath: "recordRemoteSnapshot",
            value: .object([
                "productVariant": .string("wallet_value"),
                "transferability": .string("p2p"),
                "cashOut": .bool(true),
                "externalAcceptance": .bool(true)
            ]),
            requester: owner
        )
        guard case let .object(blockedSnapshot) = blockedSnapshotResponse else {
            return XCTFail("Blocked snapshot response was not an object")
        }
        XCTAssertEqual(bindingTestValueString(blockedSnapshot["status"]), "blocked")

        let acceptedSnapshotResponse = try await quota.set(
            keypath: "recordRemoteSnapshot",
            value: .object([
                "productVariant": .string("usage_quota"),
                "transferability": .string("p2p"),
                "cashOut": .bool(true),
                "externalAcceptance": .bool(true),
                "balance": .object([
                    "quotaUnits": .integer(50_000),
                    "settlementMinorUnits": .integer(50),
                    "currency": .string("NOK")
                ])
            ]),
            requester: owner
        )
        guard case let .object(acceptedSnapshot) = acceptedSnapshotResponse,
              case let .object(updatedState)? = acceptedSnapshot["state"],
              case let .object(remoteSnapshot)? = updatedState["remoteSnapshot"],
              case let .object(balance)? = updatedState["balance"] else {
            return XCTFail("Accepted snapshot response did not contain normalized state")
        }

        XCTAssertEqual(bindingTestValueString(acceptedSnapshot["status"]), "ok")
        XCTAssertEqual(bindingTestValueString(remoteSnapshot["transferability"]), "none")
        XCTAssertEqual(bindingTestValueBool(remoteSnapshot["cashOut"]), false)
        XCTAssertEqual(bindingTestValueBool(remoteSnapshot["externalAcceptance"]), false)
        XCTAssertEqual(bindingTestValueDouble(balance["quotaUnits"]), 50_000)
        XCTAssertEqual(bindingTestValueString(balance["currency"]), "NOK")

        let topUpResponse = try await quota.set(
            keypath: "requestTopUp",
            value: .object([
                "amountMinorUnits": .integer(5_000),
                "rail": .string("stripe_apple_pay")
            ]),
            requester: owner
        )
        guard case let .object(topUpRequest) = topUpResponse else {
            return XCTFail("Top-up request response was not an object")
        }
        XCTAssertTrue(["blocked", "delegated"].contains(bindingTestValueString(topUpRequest["status"]) ?? ""))
    }

    func testAppStoreTopUpResponseKeepsVisibleCopyInsideUsageQuotaFrame() async throws {
        guard BindingPersonalCopilotV1Policy.appStoreCatalogGateEnabled else {
            throw XCTSkip("App Store catalog gate is disabled for this process.")
        }

        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
        let resolver = CellResolver.sharedInstance
        CellBase.defaultCellResolver = resolver

        let vault = BindingStartupIdentityVault.shared
        _ = await vault.initialize()
        CellBase.defaultIdentityVault = vault
        let owner = await vault.identity(
            for: "personal-usage-quota-copy-test-\(UUID().uuidString)",
            makeNewIfNotFound: true
        )!

        guard let quota = try await resolver.cellAtEndpoint(
            endpoint: "cell:///PersonalUsageQuota",
            requester: owner
        ) as? Meddle else {
            return XCTFail("Could not resolve PersonalUsageQuota as Meddle")
        }

        let topUpResponse = try await quota.set(
            keypath: "requestTopUp",
            value: .object([
                "amountMinorUnits": .integer(5_000),
                "rail": .string("stripe_apple_pay")
            ]),
            requester: owner
        )
        guard case let .object(response) = topUpResponse,
              case let .object(state)? = response["state"],
              case let .object(topUp)? = state["topUp"] else {
            return XCTFail("Top-up response did not contain normalized state")
        }

        XCTAssertEqual(bindingTestValueString(response["status"]), "blocked")
        XCTAssertEqual(bindingTestValueString(topUp["nativePurchaseCTA"]), "disabled")

        let visibleCopy = Self.userFacingStrings(in: response)
        XCTAssertTrue(
            visibleCopy.contains { $0.localizedCaseInsensitiveContains("brukskvote") },
            "Visible usage-quota copy should keep the user inside brukskvote language."
        )

        let combinedCopy = visibleCopy.joined(separator: "\n").lowercased()
        for forbiddenTerm in [
            "prepaid",
            "wallet",
            "saldo",
            "balance",
            "token",
            "micropayment",
            "issueprepaid",
            "external purchase",
            "purchase cta",
            "native external",
            "checkout"
        ] {
            XCTAssertFalse(
                combinedCopy.contains(forbiddenTerm),
                "Visible usage-quota copy leaked '\(forbiddenTerm)':\n\(visibleCopy.joined(separator: "\n"))"
            )
        }
    }

    private static let userFacingTextKeys: Set<String> = [
        "title",
        "subtitle",
        "headline",
        "summary",
        "status",
        "message",
        "nextStep",
        "label",
        "description",
        "helperText"
    ]

    private static func userFacingStrings(in object: Object) -> [String] {
        object.flatMap { key, value -> [String] in
            var strings: [String] = []
            if userFacingTextKeys.contains(key),
               let string = bindingTestValueString(value),
               !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                strings.append(string)
            }

            switch value {
            case let .object(child):
                strings.append(contentsOf: userFacingStrings(in: child))
            case let .list(values):
                for entry in values {
                    if case let .object(child) = entry {
                        strings.append(contentsOf: userFacingStrings(in: child))
                    } else if userFacingTextKeys.contains(key),
                              case let .string(string) = entry,
                              !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        strings.append(string)
                    }
                }
            default:
                break
            }

            return strings
        }
    }
}

final class SkeletonOwnerEntityAccessValidationXCTest: XCTestCase {
    func testValidationServiceWarnsWhenSkeletonLacksOwnerEntityAccess() {
        var configuration = CellConfiguration(name: "No Owner Access")
        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(text: "Prosjektstatus")),
            .Text(SkeletonText(text: "Utestående arbeid"))
        ]))

        let report = CellConfigurationValidationService.validate(configuration)

        XCTAssertGreaterThan(report.warningCount, 0)
        XCTAssertTrue(report.issues.contains(where: { $0.title == "Mangler eier-entitet tilgang" }))
    }

    func testValidationServiceAcceptsVisibleCopilotOwnerEntityAccess() {
        var configuration = CellConfiguration(name: "With Owner Access")
        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(text: "Prosjektstatus")),
            .Button(SkeletonButton(
                keypath: "cell:///PersonalChatHub/chatHub.ui.openOwnEntity",
                label: "Co-Pilot"
            ))
        ]))

        let report = CellConfigurationValidationService.validate(configuration)

        XCTAssertFalse(report.issues.contains(where: { $0.title == "Mangler eier-entitet tilgang" }))
    }
}

final class BindingRuntimeBootstrapXCTest: XCTestCase {
    func testDocumentRootDoesNotUseUserDocuments() {
        let defaultPath = BindingRuntimeBootstrap.documentRootPath(
            environment: [:],
            launchArguments: ["Binding"]
        )
        let verifierPath = BindingRuntimeBootstrap.documentRootPath(
            environment: ["BINDING_VERIFIER_IDENTITY_MODE": "startup"],
            launchArguments: ["Binding"]
        )

        XCTAssertFalse(defaultPath.contains("/Documents"))
        XCTAssertFalse(verifierPath.contains("/Documents"))
        XCTAssertTrue(verifierPath.hasPrefix(NSTemporaryDirectory()))
        XCTAssertTrue(verifierPath.hasSuffix("Binding/CellDocumentRoot"))

        let xctestPath = BindingRuntimeBootstrap.documentRootPath(
            environment: ["XCTestConfigurationFilePath": "/tmp/BindingTests.xctestconfiguration"],
            launchArguments: ["Binding"]
        )
        XCTAssertTrue(xctestPath.hasPrefix(NSTemporaryDirectory()))
        XCTAssertTrue(xctestPath.contains("/Binding/TestRuns/"))
        XCTAssertTrue(xctestPath.hasSuffix("/CellDocumentRoot"))
    }

    @MainActor
    func testCleanLocalRegistrationIncludesEntityScanner() async throws {
        let previousVault = CellBase.defaultIdentityVault
        let previousResolver = CellBase.defaultCellResolver
        let previousTypedUtility = CellBase.typedCellUtility
        let resolver = CellResolver.sharedInstance

        await resolver.resetRuntimeStateForTesting()
        do {
            let vault = BindingStartupIdentityVault()
            CellBase.defaultIdentityVault = vault
            CellBase.defaultCellResolver = resolver
            await BindingLocalCellRegistration.shared.ensureLocallyRegistered()

            let resolvedRequester = await vault.identity(
                for: "private",
                makeNewIfNotFound: true
            )
            let requester = try XCTUnwrap(resolvedRequester)
            let scanner = try await resolver.cellAtEndpoint(
                endpoint: "cell:///EntityScanner",
                requester: requester
            )
            let owner = try await scanner.getOwner(requester: requester)
            XCTAssertTrue(owner.referencesSameSigningIdentity(as: requester))
        } catch {
            CellBase.defaultIdentityVault = previousVault
            CellBase.defaultCellResolver = previousResolver
            CellBase.typedCellUtility = previousTypedUtility
            await resolver.resetRuntimeStateForTesting()
            await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
            throw error
        }

        CellBase.defaultIdentityVault = previousVault
        CellBase.defaultCellResolver = previousResolver
        CellBase.typedCellUtility = previousTypedUtility
        await resolver.resetRuntimeStateForTesting()
        await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
    }

    @MainActor
    func testLocalRegistrationRebindsWhenActiveIdentityVaultChanges() async throws {
        let previousVault = CellBase.defaultIdentityVault
        let previousResolver = CellBase.defaultCellResolver
        let previousTypedUtility = CellBase.typedCellUtility
        let resolver = CellResolver.sharedInstance

        await resolver.resetRuntimeStateForTesting()

        do {
            let firstVault = BindingStartupIdentityVault()
            CellBase.defaultIdentityVault = firstVault
            CellBase.defaultCellResolver = resolver
            await BindingLocalCellRegistration.shared.ensureLocallyRegistered()

            let resolvedFirstOwner = await firstVault.identity(
                for: "private",
                makeNewIfNotFound: true
            )
            let firstOwner = try XCTUnwrap(resolvedFirstOwner)
            let firstPorthole = try await resolver.cellAtEndpoint(
                endpoint: "cell:///Porthole",
                requester: firstOwner
            )

            let secondVault = BindingStartupIdentityVault()
            CellBase.defaultIdentityVault = secondVault
            await resolver.refreshNamedResolveOwnersFromCurrentVault()
            await BindingLocalCellRegistration.shared.ensureLocallyRegistered()

            let resolvedSecondOwner = await secondVault.identity(
                for: "private",
                makeNewIfNotFound: true
            )
            let secondOwner = try XCTUnwrap(resolvedSecondOwner)
            let secondPorthole = try await resolver.cellAtEndpoint(
                endpoint: "cell:///Porthole",
                requester: secondOwner
            )

            XCTAssertNotEqual(firstOwner.uuid, secondOwner.uuid)
            XCTAssertNotEqual(firstPorthole.uuid, secondPorthole.uuid)

            let orchestrator = try XCTUnwrap(secondPorthole as? OrchestratorCell)
            let configuration = ConfigurationCatalogCell.conferenceDemoLauncherWorkbenchConfiguration()
            try await orchestrator.loadCellConfiguration(configuration, requester: secondOwner)
            let state = try await orchestrator.get(
                keypath: "conferenceDemoLauncher.state.statusSummary",
                requester: secondOwner
            )
            guard case let .string(text) = state else {
                throw NSError(
                    domain: "BindingRuntimeBootstrapXCTest",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Expected readable launcher state after vault transition, got \(state)"]
                )
            }
            XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } catch {
            CellBase.defaultIdentityVault = previousVault
            CellBase.defaultCellResolver = previousResolver
            CellBase.typedCellUtility = previousTypedUtility
            await resolver.resetRuntimeStateForTesting()
            await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
            throw error
        }

        CellBase.defaultIdentityVault = previousVault
        CellBase.defaultCellResolver = previousResolver
        CellBase.typedCellUtility = previousTypedUtility
        await resolver.resetRuntimeStateForTesting()
        await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
    }

    @MainActor
    func testPersistentLocalRegistrationValidationFailureStopsAfterBoundedRetry() async {
        await BindingLocalCellRegistration.shared
            .setForcedLocalRegistrationValidationFailureForTesting(true)

        let registrationResults = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
                }
            }
            var results = [Bool]()
            for await result in group {
                results.append(result)
            }
            return results
        }

        let validationCount = await BindingLocalCellRegistration.shared
            .localRegistrationValidationCountForTestingSnapshot()
        XCTAssertEqual(validationCount, 2)
        XCTAssertEqual(registrationResults.count, 8)
        XCTAssertTrue(registrationResults.allSatisfy { !$0 })

        await BindingLocalCellRegistration.shared
            .setForcedLocalRegistrationValidationFailureForTesting(false)
        let recovered = await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
        XCTAssertTrue(recovered)
    }

    func testCriticalLocalRegistrationManifestRejectsWrongTypeDuplicate() async throws {
        let vault = EphemeralIdentityVault()
        let candidateOwner = await vault.identity(
            for: "critical-registration-manifest-\(UUID().uuidString)",
            makeNewIfNotFound: true
        )
        let owner = try XCTUnwrap(candidateOwner)
        let wrongType = await EventEmitterCell(owner: owner)
        let correctCatalog = await ConfigurationCatalogCell(owner: owner)

        XCTAssertFalse(BindingLocalCellRegistration.criticalCellTypeMatches(
            endpoint: "cell:///ConfigurationCatalog",
            cell: wrongType
        ))
        XCTAssertTrue(BindingLocalCellRegistration.criticalCellTypeMatches(
            endpoint: "cell:///ConfigurationCatalog",
            cell: correctCatalog
        ))
    }
}

@Suite(.serialized)
struct BindingTests {

    @Test @MainActor func bindingRuntimeBootstrapEnsuresDefaultsWhenMissing() async {
        let resolver = (CellBase.defaultCellResolver as? CellResolver) ?? CellResolver.sharedInstance
        await AppInitializer.resetRuntimeStateForTesting()
        await resolver.resetRuntimeStateForTesting()
        CellBase.defaultIdentityVault = nil
        CellBase.defaultCellResolver = nil
        CellBase.typedCellUtility = nil
        CellBase.documentRootPath = ""

        await BindingRuntimeBootstrap.ensureBaseline()

        #expect(CellBase.defaultIdentityVault != nil)
        #expect(CellBase.defaultCellResolver is CellResolver)
        #expect(CellBase.typedCellUtility != nil)
        #expect(CellBase.documentRootPath != nil)
        #expect(!(CellBase.documentRootPath ?? "").isEmpty)

        // Leave the serialized suite on a non-interactive test identity. The
        // production bootstrap vault may legitimately invoke LocalAuthentication,
        // which must never become an implicit dependency of following tests.
        CellBase.defaultIdentityVault = EphemeralIdentityVault()
        CellBase.defaultCellResolver = resolver
    }

    @Test func personalPrivacyAuditConcurrentRecordsAreAtomicAndEncodable() async throws {
        #expect(await BindingLocalCellRegistration.shared.ensureLocallyRegistered())
        let resolver = try #require(CellBase.defaultCellResolver as? CellResolver)
        let vault = try #require(CellBase.defaultIdentityVault)
        let requester = try #require(await vault.identity(
            for: "private",
            makeNewIfNotFound: true
        ))
        let cell = try await resolver.cellAtEndpoint(
            endpoint: "cell:///PersonalPrivacyAudit",
            requester: requester
        )
        let generalCell = try #require(cell as? GeneralCell)
        let recordCount = 24
        let prefix = "concurrent-audit-\(UUID().uuidString)-"

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<recordCount {
                group.addTask {
                    _ = try await generalCell.set(
                        keypath: "audit.record",
                        value: ValueType.string("\(prefix)\(index)"),
                        requester: requester
                    )
                }
            }
            try await group.waitForAll()
        }

        let state = try await generalCell.get(keypath: "state", requester: requester)
        guard case let .object(root) = state,
              case let .object(audit)? = root["audit"],
              case let .list(entries)? = audit["entries"] else {
            Issue.record("Expected PersonalPrivacyAudit entries after concurrent actions")
            return
        }
        let summaries = Set(entries.compactMap { entry -> String? in
            guard case let .object(object) = entry,
                  case let .string(summary)? = object["summary"],
                  summary.hasPrefix(prefix) else {
                return nil
            }
            return summary
        })
        #expect(summaries.count == recordCount)

        let personalCell = try #require(cell as? PersonalCopilotLocalCell)
        let persistedState = personalCell.stateObject()
        let encoded = try JSONEncoder().encode(personalCell)
        #expect(encoded.isEmpty == false)
        let decoded = try JSONDecoder().decode(PersonalCopilotLocalCell.self, from: encoded)
        let stateEncoder = JSONEncoder()
        stateEncoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        #expect(
            try stateEncoder.encode(persistedState)
                == stateEncoder.encode(decoded.stateObject())
        )
    }

    @Test func personalCopilotV1MenuConfigurationsAreScopedAndConferenceFree() {
        let configurations = ConfigurationCatalogCell.personalCopilotV1MenuConfigurations()
        let names = Set(configurations.map(\.name))

        for requiredName in [
            "Personal Home",
            "My Profile",
            "Publish Public Profile",
            "Public Profile Directory",
            "Matches",
            "Co-Pilot",
            "Agenda Context",
            "Butterpop Studio",
            "Calendar",
            "Vault / Ideas",
            "Meeting Intent",
            "Privacy Audit",
            "Personal Co-Pilot Catalog",
            "Apple Intelligence Purpose Matcher",
            "Entity Scanner",
            "Workflow Studio"
        ] {
            #expect(names.contains(requiredName))
        }

        #expect(configurations.count == 16)
        #expect(configurations.allSatisfy(BindingPersonalCopilotV1Policy.isAllowedInPersonalCopilotV1))

        let visibleText = configurations.flatMap { configuration in
            [
                configuration.name,
                configuration.description ?? "",
                configuration.discovery?.purpose ?? "",
                configuration.discovery?.purposeDescription ?? ""
            ] + (configuration.discovery?.interests ?? [])
        }
        let normalized = visibleText.joined(separator: " ").lowercased()
        #expect(!normalized.contains("conference"))
        #expect(!normalized.contains("konferanse"))
        #expect(!normalized.contains("demo launcher"))
        #expect(!normalized.contains("control tower"))
    }

    @Test func stagingSurfaceTestingModeIsDebugOnlyAndCanBeDisabled() {
        #if DEBUG
        #expect(BindingPersonalCopilotV1Policy.stagingSurfaceTestingEnabled(environment: [:], launchArguments: []))
        #else
        #expect(!BindingPersonalCopilotV1Policy.stagingSurfaceTestingEnabled(environment: [:], launchArguments: []))
        #endif

        #expect(!BindingPersonalCopilotV1Policy.stagingSurfaceTestingEnabled(
            environment: ["BINDING_ENABLE_STAGING_SURFACE_TESTING": "false"],
            launchArguments: []
        ))
        #expect(!BindingPersonalCopilotV1Policy.stagingSurfaceTestingEnabled(
            environment: [:],
            launchArguments: ["Binding", "--disable-staging-surface-testing"]
        ))
        #if DEBUG
        #expect(BindingPersonalCopilotV1Policy.stagingSurfaceTestingEnabled(
            environment: ["BINDING_ENABLE_STAGING_SURFACE_TESTING": "true"],
            launchArguments: []
        ))
        #else
        #expect(!BindingPersonalCopilotV1Policy.stagingSurfaceTestingEnabled(
            environment: ["BINDING_ENABLE_STAGING_SURFACE_TESTING": "true"],
            launchArguments: []
        ))
        #endif
    }

    @Test func stagingSurfaceTestingMenuConfigurationsExposeRequestedRemoteSurfaces() throws {
        let configurations = ConfigurationCatalogCell.stagingSurfaceTestingMenuConfigurations(
            includeAgentOperatorSurfaces: false
        )
        let names = Set(configurations.map(\.name))

        for requiredName in [
            "Arendalsuka Participant Program",
            "Arendalsuka Event Atlas",
            "HAVEN Workbench",
            "Mermaid Renderer",
            "Admin Entry",
            "Admin Overview"
        ] {
            #expect(names.contains(requiredName))
        }

        let endpointsByName = try Dictionary(
            uniqueKeysWithValues: configurations.map { configuration in
                (configuration.name, try Self.cellEndpointStrings(in: configuration))
            }
        )
        #expect(endpointsByName["Arendalsuka Participant Program"]?.contains("cell://staging.haven.digipomps.org/ArendalsukaParticipantProgram") == true)
        #expect(endpointsByName["Arendalsuka Event Atlas"]?.contains("cell://staging.haven.digipomps.org/ArendalsukaEventAtlas") == true)
        #expect(endpointsByName["HAVEN Workbench"]?.contains("cell://staging.haven.digipomps.org/WorkItem") == true)
        #expect(endpointsByName["Mermaid Renderer"]?.contains("cell://staging.haven.digipomps.org/MermaidRenderer") == true)
        #expect(endpointsByName["Admin Entry"]?.contains("cell://staging.haven.digipomps.org/AdminEntry") == true)
        #expect(endpointsByName["Admin Overview"]?.contains("cell://staging.haven.digipomps.org/AdminOverview") == true)

        #expect(configurations.allSatisfy { $0.skeleton != nil })
    }

    @Test func stagingSurfaceTestingMenuConfigurationsIncludeAgentSurfacesWhenOptedIn() {
        UserDefaults.standard.set(true, forKey: BindingPersonalCopilotV1Policy.agentSetupWorkbenchDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: BindingPersonalCopilotV1Policy.agentSetupWorkbenchDefaultsKey) }

        let configurations = ConfigurationCatalogCell.stagingSurfaceTestingMenuConfigurations(
            includeAgentOperatorSurfaces: true
        )
        let names = Set(configurations.map(\.name))

        #expect(names.contains("Agent Setup Workbench"))
        #expect(names.contains("Network Sentinel"))
    }

    @Test func conferenceLauncherAndClaudeReferenceAreLoadableAndExplicitAboutScope() throws {
        let codex = ConfigurationCatalogCell.conferenceCodexLiveConfigurationsMenuConfiguration()
        let claude = ConfigurationCatalogCell.conferenceClaudeDesignReferenceMenuConfiguration()

        for configuration in [codex, claude] {
            #expect(
                CellConfigurationValidationService.validate(configuration).errorCount == 0,
                "\(configuration.name) should validate as a normal CellConfiguration."
            )
            #expect(
                configuration.cellReferences?.contains(where: {
                    $0.label == "conferenceNavigator" && $0.endpoint == "cell:///ConferenceConfigurationNavigator"
                }) == true,
                "\(configuration.name) should carry an explicit conference navigator reference."
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]

        let codexJSON = try String(
            decoding: encoder.encode(codex),
            as: UTF8.self
        )
        let claudeJSON = try String(
            decoding: encoder.encode(claude),
            as: UTF8.self
        )

        for expected in [
            "\"name\":\"Conference Codex Live Configurations\"",
            "\"keypath\":\"conferenceNavigator.dispatchAction\"",
            "\"keypath\":\"navigator.openConferenceParticipantPortal\"",
            "\"keypath\":\"navigator.openConferenceAIAssistant\"",
            "\"label\":\"Participant portal\"",
            "\"label\":\"AI assistant\"",
            "\"label\":\"Control tower\"",
            "\"label\":\"Public surface\""
        ] {
            #expect(codexJSON.contains(expected), "Conference Codex launcher JSON missing \(expected)")
        }

        for expected in [
            "\"name\":\"Conference Claude Design Reference\"",
            "\"keypath\":\"conferenceNavigator.dispatchAction\"",
            "\"keypath\":\"navigator.openConferencePublicSurface\"",
            "\"keypath\":\"navigator.openConferenceSponsorFollowUp\"",
            "\"label\":\"Open public surface\"",
            "\"label\":\"Open sponsor follow-up\"",
            "\"label\":\"Open nearby radar\"",
            "\"label\":\"Open participant chat\""
        ] {
            #expect(claudeJSON.contains(expected), "Conference Claude reference JSON missing \(expected)")
        }

        #expect(!codexJSON.contains("conferenceNavigator.status"))
        #expect(!claudeJSON.contains("conferenceNavigator.status"))
        #expect(claudeJSON.lowercased().contains("designreferanse") || claudeJSON.lowercased().contains("design reference"))
    }

    @Test func conferenceShowcaseDefaultsStayOnLocalDemoRuntime() {
        let ai = ConfigurationCatalogCell.conferenceAIAssistantWorkbenchConfiguration()
        let publicSurface = ConfigurationCatalogCell.conferencePublicWorkbenchConfiguration()
        let sponsor = ConfigurationCatalogCell.conferenceSponsorWorkbenchConfiguration()

        #expect(ai.discovery?.sourceCellEndpoint == "cell:///ConferenceParticipantPreviewShell")
        #expect(ai.discovery?.sourceCellName == "ConferenceParticipantPreviewShellLocalFallbackCell")
        #expect(ai.cellReferences?.first?.endpoint == "cell:///ConferenceParticipantPreviewShell")
        #expect(ai.cellReferences?.last?.endpoint == "cell:///ConferenceAIAssistantGatewayProxy")

        #expect(publicSurface.discovery?.sourceCellEndpoint == "cell:///ConferencePublicShellFixture")
        #expect(publicSurface.discovery?.sourceCellName == "ConferencePublicShellFixtureCell")
        #expect(publicSurface.cellReferences?.first?.endpoint == "cell:///ConferencePublicShellFixture")

        #expect(sponsor.discovery?.sourceCellEndpoint == "cell:///ConferenceSponsorShellFixture")
        #expect(sponsor.discovery?.sourceCellName == "ConferenceSponsorShellFixtureCell")
        #expect(sponsor.cellReferences?.first?.endpoint == "cell:///ConferenceSponsorShellFixture")
    }

    @Test func runtimeBootstrapClassificationUsesEndpointsForLocalPersonalSurfaces() {
        let contentView = ContentView()

        for configuration in [
            ConfigurationCatalogCell.personalHomeMenuConfiguration(),
            ConfigurationCatalogCell.personalProfileMenuConfiguration(),
            ConfigurationCatalogCell.personalInviteChatMenuConfiguration(),
            ConfigurationCatalogCell.personalVaultIdeasMenuConfiguration(),
            ConfigurationCatalogCell.personalPrivacyAuditMenuConfiguration()
        ] {
            #expect(
                contentView.requiresAuthenticatedRuntimeBootstrap(configuration) == false,
                "\(configuration.name) should load through the local runtime path."
            )
        }

        for configuration in [
            ConfigurationCatalogCell.personalPublicProfileMenuConfiguration(),
            ConfigurationCatalogCell.personalPublicProfileDirectoryMenuConfiguration(),
            ConfigurationCatalogCell.personalMatchesMenuConfiguration(),
            ConfigurationCatalogCell.personalMeetingIntentMenuConfiguration(),
            ConfigurationCatalogCell.personalCopilotCatalogMenuConfiguration()
        ] {
            #expect(
                contentView.requiresAuthenticatedRuntimeBootstrap(configuration),
                "\(configuration.name) should still require authenticated remote runtime bootstrap."
            )
        }
    }

    @Test func personalCopilotViewerModeSkipsSourceBackedResolutionForCuratedSurfaces() {
        let contentView = ContentView()

        #expect(
            contentView.shouldResolveSourceBackedConfiguration(
                ConfigurationCatalogCell.personalInviteChatMenuConfiguration(),
                editorMode: .view
            ) == false
        )
        #expect(
            contentView.shouldResolveSourceBackedConfiguration(
                ConfigurationCatalogCell.personalHomeMenuConfiguration(),
                editorMode: .view
            ) == false
        )
        #expect(
            contentView.shouldResolveSourceBackedConfiguration(
                ConfigurationCatalogCell.workflowStudioWorkbenchConfiguration(),
                editorMode: .view
            )
        )
        #expect(
            contentView.shouldResolveSourceBackedConfiguration(
                ConfigurationCatalogCell.personalInviteChatMenuConfiguration(),
                editorMode: .edit
            )
        )
    }

    @Test func personalCopilotInviteChatStaysChatFirstAndDropsTechnicalInviteFields() throws {
        let configuration = ConfigurationCatalogCell.personalInviteChatMenuConfiguration()

        #expect(BindingPersonalCopilotV1Policy.isAllowedInPersonalCopilotV1(configuration))
        #expect(BindingPersonalCopilotV1Policy.referencedEndpoints(in: configuration).contains("cell:///PersonalChatHub"))

        guard let skeleton = configuration.skeleton else {
            Issue.record("Co-Pilot Chat should have a skeleton")
            return
        }

        let styleRoles = skeletonStyleRoles(in: skeleton)
        #expect(styleRoles.contains("personal-chat-page"))
        #expect(styleRoles.contains("personal-chat-hero"))

        let helpIntro = "Skriv hva du vil oppnaa i klartekst. Flaten er laget for chat-first, ikke for tekniske felt."
        let helpFollowup = "Bruk navn, kallenavn eller relasjoner som \"naermeste kollega\". Assistenten kan foreslaa neste steg, men sender aldri noe alene."
        if let conversationPanel = skeletonTabPanel(id: "samtale", in: skeleton) {
            let conversationElement = SkeletonElement.VStack(SkeletonVStack(elements: conversationPanel))
            let composerTextArea = try #require(skeletonTextArea(targetKeypath: "chatHub.setComposer", in: conversationElement))
            #expect(composerTextArea.placeholder == nil)
            #expect(composerTextArea.maxLines == 3)
            #expect(composerTextArea.submitOnEnter == true)
            #expect(composerTextArea.submitActionKeypath == "chatHub.prompt.submit")
            #expect(composerTextArea.modifiers?.styleRole == "personal-chat-composer-field")
            #expect(skeletonStyleRoles(in: conversationElement).contains("personal-chat-section"))
            #expect(topLevelSectionHasHeader("Samtale", in: conversationPanel))
            if let sectionContent = topLevelSectionContent(header: "Samtale", in: conversationPanel),
               let promptLogIndex = firstTopLevelElementIndex(in: sectionContent, matching: { elementContainsList(keypath: "chatHub.state.ui.promptMessages", in: $0) }),
               let composerIndex = firstTopLevelElementIndex(in: sectionContent, matching: { skeletonTextArea(targetKeypath: "chatHub.setComposer", in: $0) != nil }) {
                #expect(promptLogIndex == 0)
                #expect(promptLogIndex < composerIndex)
            } else {
                Issue.record("Co-Pilot Chat should place the prompt log above the composer")
            }
            #expect(!topLevelSectionHasHeader("Start her", in: conversationPanel))
            #expect(!topLevelSectionHasHeader("Co-Pilot Chat", in: conversationPanel))
            #expect(!skeletonContainsLiteralText("Hva vil du få gjort?", in: conversationPanel))
            #expect(!skeletonContainsLiteralText(helpIntro, in: conversationPanel))
            #expect(!skeletonContainsLiteralText(helpFollowup, in: conversationPanel))
            if let promptLogRow = skeletonListFlowElement(
                keypath: "chatHub.state.ui.promptMessages",
                in: conversationPanel
            ) {
                #expect(!skeletonContainsButton(keypath: "chatHub.ui.openSuggestedHelper", in: promptLogRow))
                #expect(!skeletonContainsButton(keypath: "chatHub.ui.openMatchedResourceLibrary", in: promptLogRow))
                #expect(!skeletonContainsButton(keypath: "chatHub.assistant.dismissSuggestion", in: promptLogRow))
            } else {
                Issue.record("Co-Pilot Chat Samtale tab should render the prompt log")
            }
            #expect(!skeletonContainsButton(keypath: "chatHub.assistant.analyzeDraft", in: conversationPanel))
            #expect(skeletonContainsButton(keypath: "chatHub.ui.openSuggestedHelper", label: "↑", in: conversationPanel))
            func primaryActionButton(in element: SkeletonElement) -> SkeletonButton? {
                switch element {
                case .Button(let button):
                    return button.keypath == "chatHub.ui.openSuggestedHelper" && button.label == "↑" ? button : nil
                case .VStack(let stack):
                    return stack.elements.lazy.compactMap(primaryActionButton).first
                case .HStack(let stack):
                    return stack.elements.lazy.compactMap(primaryActionButton).first
                case .ScrollView(let scroll):
                    return scroll.elements.lazy.compactMap(primaryActionButton).first
                case .Section(let section):
                    return (section.header.flatMap(primaryActionButton))
                        ?? section.content.lazy.compactMap(primaryActionButton).first
                        ?? section.footer.flatMap(primaryActionButton)
                case .Tabs(let tabs):
                    return tabs.panels.lazy.compactMap { panel in
                        panel.content.lazy.compactMap(primaryActionButton).first
                    }.first
                default:
                    return nil
                }
            }
            let primaryAction = try #require(primaryActionButton(in: conversationElement))
            #expect(primaryAction.payload != nil)
            #expect(skeletonContainsTextKeypath("chatHub.state.ui.primaryActionHint", in: conversationPanel))
            #expect(skeletonContainsTabs(tabsKeypath: "chatHub.state.ui.activeHelpers", in: conversationElement))
            #expect(!skeletonContainsLiteralText("Trykk pilen", in: conversationPanel))
            #expect(!skeletonContainsButton(keypath: "chatHub.prompt.submit", in: conversationPanel))
            #expect(!skeletonContainsButton(keypath: "chatHub.clearComposer", in: conversationPanel))
            #expect(!skeletonContainsButton(keypath: "chatHub.assistant.dismissSuggestion", in: conversationPanel))
            #expect(!skeletonContainsButton(keypath: "chatHub.voice.requestPermission", in: conversationPanel))
            #expect(!skeletonContainsButton(keypath: "chatHub.voice.startListening", in: conversationPanel))
            #expect(!skeletonContainsButton(keypath: "chatHub.voice.stopListening", in: conversationPanel))
        } else {
            Issue.record("Co-Pilot Chat should expose a Samtale tab panel")
        }
        if let activePanel = skeletonTabPanel(id: "aktivt", in: skeleton) {
            let activeElement = SkeletonElement.VStack(SkeletonVStack(elements: activePanel))
            #expect(skeletonContainsList(keypath: "chatHub.state.threads", topic: nil, in: activeElement))
            #expect(skeletonContainsList(keypath: "chatHub.state.messages", topic: nil, in: activeElement))
        } else {
            Issue.record("Co-Pilot Chat should expose an Aktivt tab panel")
        }
        if let helpPanel = skeletonTabPanel(id: "hjelp", in: skeleton) {
            let helpElement = SkeletonElement.VStack(SkeletonVStack(elements: helpPanel))
            #expect(skeletonContainsLiteralText("Hjelp", in: helpPanel))
            #expect(skeletonContainsLiteralText("Kontekst", in: helpPanel))
            #expect(skeletonContainsLiteralText(helpIntro, in: helpPanel))
            #expect(skeletonContainsLiteralText(helpFollowup, in: helpPanel))
            #expect(skeletonContainsTextKeypath("perspective.perspective.state.activePurposeCount", in: helpPanel))
            #expect(skeletonContainsTextKeypath("perspective.perspective.state.activeInterestCount", in: helpPanel))
            #expect(skeletonContainsList(keypath: "perspective.activePurpose.purposes", topic: nil, in: helpElement))
        } else {
            Issue.record("Co-Pilot Chat should expose a Mer > Hjelp tab panel")
        }

        for keypath in [
            "chatHub.invite",
            "chatHub.acceptInvite",
            "chatHub.declineInvite",
            "chatHub.clearComposer",
            "chatHub.reportMessage",
            "chatHub.blockUser",
            "chatHub.unblockUser",
            "chatHub.assistant.dismissSuggestion",
            "chatHub.ui.openSuggestedHelper",
            "chatHub.ui.setCapabilityDiscoveryEnabled",
            "chatHub.voice.requestPermission",
            "chatHub.voice.startListening",
            "chatHub.voice.stopListening",
            "chatHub.voice.acceptTranscript",
            "chatHub.voice.acceptTranscriptAndAnalyze",
            "chatHub.voice.clearTranscript",
            "chatHub.meeting.schedule",
            "chatHub.idea.capture",
            "chatHub.todo.create",
            "chatHub.project.create",
            "chatHub.reminder.create",
            "chatHub.agent.review.create",
            "chatHub.capabilityRequest.submit",
            "chatHub.poll.create",
            "chatHub.poll.vote",
            "chatHub.poll.close"
        ] {
            #expect(skeletonContainsButton(keypath: keypath, in: skeleton))
        }
        #expect(skeletonContainsTabsSelectionAction(keypath: "chatHub.ui.setActiveHelper", in: skeleton))

        #expect(skeletonContainsTextField(targetKeypath: "chatHub.assistant.setCandidateQuery", in: skeleton))
        #expect(skeletonContainsTextArea(targetKeypath: "chatHub.assistant.setCandidateQuery", in: skeleton))
        #expect(skeletonContainsTextField(targetKeypath: "chatHub.inviteDraft.title", in: skeleton))
        #expect(skeletonContainsTextArea(targetKeypath: "chatHub.setComposer", in: skeleton))
        #expect(skeletonContainsTextArea(targetKeypath: "chatHub.poll.setOptions", in: skeleton))
        #expect(skeletonContainsTextField(targetKeypath: "chatHub.todo.title", in: skeleton))
        #expect(skeletonContainsTextArea(targetKeypath: "chatHub.project.description", in: skeleton))
        #expect(skeletonContainsTextArea(targetKeypath: "chatHub.capabilityRequest.summary", in: skeleton))
        #expect(skeletonContainsTextKeypath("chatHub.state.assistant.latestSuggestion.explanation", in: skeleton))
        #expect(skeletonContainsTextKeypath("chatHub.state.assistant.whySummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("chatHub.state.assistant.providerRecommendation.title", in: skeleton))
        #expect(skeletonContainsTextKeypath("chatHub.state.voice.message", in: skeleton))
        #expect(skeletonContainsTextKeypath("chatHub.state.voice.finalTranscript", in: skeleton))
        #expect(skeletonContainsList(keypath: "chatHub.state.ui.componentSurfaces", topic: nil, in: skeleton))
        #expect(skeletonContainsList(keypath: "chatHub.state.ui.activeToolChips", topic: nil, in: skeleton))
        #expect(skeletonContainsList(keypath: "chatHub.state.workbench.modules", topic: nil, in: skeleton))
        #expect(skeletonContainsList(keypath: "chatHub.state.capabilityRequests", topic: nil, in: skeleton))
        #expect(skeletonContainsList(keypath: "chatHub.state.assistant.assistantProviders", topic: nil, in: skeleton))
        #expect(skeletonContainsList(keypath: "chatHub.state.assistant.latestSuggestion.candidates", topic: nil, in: skeleton))
        #expect(skeletonContainsList(keypath: "perspective.activePurpose.purposes", topic: nil, in: skeleton))
        #expect(!skeletonContainsTextField(targetKeypath: "chatHub.inviteDraft.userUUID", in: skeleton))
        #expect(!skeletonContainsTextField(targetKeypath: "chatHub.inviteDraft.profileID", in: skeleton))
        #expect(!skeletonContainsTextKeypath("chatHub.state.blockedUsers", in: skeleton))
        #expect(!skeletonContainsTextKeypath("chatHub.state.purposeWeights", in: skeleton))
        let validationReport = CellConfigurationValidationService.validate(configuration)
        #expect(!validationReport.unusedLabels.contains("perspective"))
        if let mermaidPanel = skeletonTabPanel(id: "mermaid-diagram", in: skeleton) {
            let mermaidElement = SkeletonElement.VStack(SkeletonVStack(elements: mermaidPanel))
            #expect(skeletonContainsTextArea(targetKeypath: "chatHub.assistant.setCandidateQuery", in: mermaidElement))
            #expect(skeletonContainsButton(keypath: "chatHub.ui.openMatchedResourceLibrary", label: "Åpne diagramflate", in: mermaidPanel))
        } else {
            Issue.record("Co-Pilot Chat should expose the Mermaid helper panel")
        }
        _ = try JSONEncoder().encode(skeleton)
    }

    @Test func skeletonTextDoesNotExposeTechnicalAuthorizationFailures() async {
        let text = SkeletonText(keypath: "state.draft.title")
        let rendered = await text.asyncContent(
            userInfoValue: .object([
                "state": .object([
                    "draft": .object([
                        "title": .string("failure: Consume command get failed for get(state.draft.title): denied(CellBase.CellAuthorizationDecision(allowed: false, reason: \"No verified owner proof\"))")
                    ])
                ])
            ])
        )

        #expect(rendered == "Innholdet er ikke tilgjengelig akkurat nå.")
        #expect(!rendered.contains("CellAuthorizationDecision"))
        #expect(!rendered.contains("Consume command"))
    }

    @Test func personalCopilotV1PolicyRejectsConferenceAndUnapprovedHosts() {
        var scopedConference = ConfigurationCatalogCell.conferenceDemoLauncherWorkbenchConfiguration()
        scopedConference.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: "cell:///ConferenceDemoLauncher",
            sourceCellName: "ConferenceDemoLauncherLocalCell",
            purpose: "Conference demo launcher",
            purposeDescription: "Should remain hidden in Personal Co-Pilot V1.",
            interests: BindingPersonalCopilotV1Policy.discoveryInterests(["conference"], policyCategory: "demo"),
            menuSlots: ["upperLeft"]
        )
        #expect(!BindingPersonalCopilotV1Policy.isAllowedInPersonalCopilotV1(scopedConference))

        var offHost = ConfigurationCatalogCell.personalHomeMenuConfiguration()
        offHost.cellReferences = [CellReference(endpoint: "cell://unapproved.example.org/PersonalIdentity", label: "identity")]
        #expect(!BindingPersonalCopilotV1Policy.isAllowedInPersonalCopilotV1(offHost))
        #expect(BindingPersonalCopilotV1Policy.unavailableMessage(for: offHost.name).contains("Personal Co-Pilot V1"))
    }

    @Test func conferenceDemoMenusCanBePersistentlyEnabledInDebugBuilds() {
        #if DEBUG
        #expect(BindingPersonalCopilotV1Policy.conferenceDemoMenusEnabled(
            environment: [:],
            launchArguments: [],
            persistedOptIn: false
        ) == false)
        #expect(BindingPersonalCopilotV1Policy.conferenceDemoMenusEnabled(
            environment: [:],
            launchArguments: [],
            persistedOptIn: true
        ))
        #expect(BindingPersonalCopilotV1Policy.conferenceDemoMenusEnabled(
            environment: ["BINDING_ENABLE_CONFERENCE_DEMO_MENUS": "yes"],
            launchArguments: [],
            persistedOptIn: false
        ))
        #expect(BindingPersonalCopilotV1Policy.conferenceDemoMenusEnabled(
            environment: [:],
            launchArguments: ["--conference-demo-menus"],
            persistedOptIn: false
        ))
        #else
        #expect(BindingPersonalCopilotV1Policy.conferenceDemoMenusEnabled(
            environment: ["BINDING_ENABLE_CONFERENCE_DEMO_MENUS": "1"],
            launchArguments: ["--conference-demo-menus"],
            persistedOptIn: true
        ) == false)
        #endif
    }

    @Test func personalCopilotProfilePublishingCarriesAppStoreReviewMetadata() {
        let configuration = ConfigurationCatalogCell.personalPublicProfileMenuConfiguration()
        let interests = configuration.discovery?.interests ?? []

        #expect(interests.contains("appStoreScope=\(BindingPersonalCopilotV1Policy.appStoreScope)"))
        #expect(interests.contains("policyCategory=profile-publish"))
        #expect(interests.contains("requiresLogin=true"))
        #expect(interests.contains("requiresUserGeneratedContentModeration=true"))
        #expect(interests.contains { $0.hasPrefix("universalLink=https://staging.haven.digipomps.org/app/personal/profile/publish") })
        #expect(interests.contains { $0.hasPrefix("reviewSummary=Curated Personal Co-Pilot surface") })
    }

    @Test func personalCopilotRemotePurposeSurfacesExposeContractActions() {
        let publishConfiguration = ConfigurationCatalogCell.personalPublicProfileMenuConfiguration()
        let publishEndpoints = BindingPersonalCopilotV1Policy.referencedEndpoints(in: publishConfiguration)
        #expect(publishEndpoints.contains("cell://staging.haven.digipomps.org/PersonalProfilePublisher"))
        #expect(publishEndpoints.contains("cell:///PersonalProfileDraft"))
        #expect(publishEndpoints.contains("cell:///PersonalPrivacyAudit"))

        if let skeleton = publishConfiguration.skeleton {
            for keypath in [
                "profileDraft.preparePublishPreview",
                "profileDraft.recordPublishConsent",
                "privacyAudit.audit.record",
                "profilePublisher.publishProfile",
                "profilePublisher.unpublishProfile",
                "profilePublisher.deleteProfile"
            ] {
                #expect(skeletonContainsButton(keypath: keypath, in: skeleton))
            }
            #expect(skeletonContainsTextKeypath("profileDraft.state.publishPreview.summary", in: skeleton))
            #expect(skeletonContainsTextField(targetKeypath: "profilePublisher.publishDraft.displayName", in: skeleton))
            #expect(skeletonContainsTextArea(targetKeypath: "profilePublisher.publishDraft.summary", in: skeleton))
            #expect(skeletonContainsTextKeypath("profilePublisher.state.publishStatus", in: skeleton))
        } else {
            Issue.record("Publish Public Profile should expose a consent-gated skeleton")
        }

        let matchesConfiguration = ConfigurationCatalogCell.personalMatchesMenuConfiguration()
        let matchesEndpoints = BindingPersonalCopilotV1Policy.referencedEndpoints(in: matchesConfiguration)
        #expect(matchesEndpoints.contains("cell://staging.haven.digipomps.org/PersonalMatchmaking"))
        #expect(matchesEndpoints.contains("cell:///PersonalProfileDraft"))
        #expect(matchesEndpoints.contains("cell:///PersonalChatClient"))
        #expect(matchesEndpoints.contains("cell:///PersonalPrivacyAudit"))

        if let skeleton = matchesConfiguration.skeleton {
            for keypath in [
                "matchmaking.refreshSuggestions",
                "matchmaking.requestMatchConsent",
                "matchmaking.acceptMatchConsent",
                "matchmaking.declineMatchConsent",
                "matchmaking.clearMatchSuggestion",
                "privacyAudit.audit.record"
            ] {
                #expect(skeletonContainsButton(keypath: keypath, in: skeleton))
            }
            #expect(skeletonContainsTextField(targetKeypath: "matchmaking.preferencesText", in: skeleton))
            #expect(skeletonContainsList(keypath: "matchmaking.state.matchSuggestions", topic: nil, in: skeleton))
            #expect(skeletonContainsTextKeypath("matchmaking.state.requiresMutualApprovalForChat", in: skeleton))
            #expect(skeletonContainsTextKeypath("chatClient.state.inviteStatus", in: skeleton))
        } else {
            Issue.record("Matches should expose consent and matchmaking contract actions")
        }
    }

    @Test func personalCopilotDirectoryMeetingAndCatalogMatchCellScaffoldContracts() {
        let directory = ConfigurationCatalogCell.personalPublicProfileDirectoryMenuConfiguration()
        #expect(BindingPersonalCopilotV1Policy.referencedEndpoints(in: directory).contains("cell://staging.haven.digipomps.org/PublicProfileDirectory"))
        if let skeleton = directory.skeleton {
            for keypath in ["directory.searchProfiles", "directory.profileDetail", "directory.reportProfile", "directory.hideProfile", "directory.blockProfile"] {
                #expect(skeletonContainsButton(keypath: keypath, in: skeleton))
            }
            #expect(skeletonContainsTextField(targetKeypath: "directory.query", in: skeleton))
            #expect(skeletonContainsList(keypath: "directory.state.lastSearch.results", topic: nil, in: skeleton))
        } else {
            Issue.record("Public Profile Directory should expose the staging directory contract")
        }

        let meeting = ConfigurationCatalogCell.personalMeetingIntentMenuConfiguration()
        #expect(BindingPersonalCopilotV1Policy.referencedEndpoints(in: meeting).contains("cell://staging.haven.digipomps.org/PersonalMeetingCoordinator"))
        if let skeleton = meeting.skeleton {
            for keypath in ["meetingCoordinator.proposeTimes", "meetingCoordinator.acceptTime", "meetingCoordinator.declineTime", "meetingCoordinator.clearMeetingIntent"] {
                #expect(skeletonContainsButton(keypath: keypath, in: skeleton))
            }
            #expect(skeletonContainsTextField(targetKeypath: "meetingCoordinator.draft.title", in: skeleton))
            #expect(skeletonContainsTextKeypath("meetingCoordinator.state.meetingBridge.requiresCameraMicrophoneConsent", in: skeleton))
        } else {
            Issue.record("Meeting Intent should expose the staging coordinator contract")
        }

        let agenda = ConfigurationCatalogCell.personalAgendaContextMenuConfiguration()
        #expect(BindingPersonalCopilotV1Policy.isAllowedInPersonalCopilotV1(agenda))
        #expect(BindingPersonalCopilotV1Policy.referencedEndpoints(in: agenda).contains("cell:///PersonalAgendaContext"))
        #expect((agenda.discovery?.interests ?? []).contains("policyCategory=agenda-context"))
        #expect((agenda.discovery?.interests ?? []).contains("nativePermissionRequests=calendar,reminders"))
        if let skeleton = agenda.skeleton {
            for keypath in [
                "agendaContext.agenda.refresh",
                "agendaContext.agenda.answerQuery",
                "agendaContext.agenda.publishPerspectiveSignals"
            ] {
                #expect(skeletonContainsButton(keypath: keypath, in: skeleton))
            }
            #expect(skeletonContainsTextKeypath("agendaContext.state.permissionStatus.calendar", in: skeleton))
            #expect(skeletonContainsTextKeypath("agendaContext.state.permissionStatus.reminders", in: skeleton))
            #expect(skeletonContainsList(keypath: "agendaContext.state.items", topic: nil, in: skeleton))
        } else {
            Issue.record("Agenda Context should expose the local agenda contract")
        }

        let catalog = ConfigurationCatalogCell.personalCopilotCatalogMenuConfiguration()
        #expect(BindingPersonalCopilotV1Policy.referencedEndpoints(in: catalog).contains("cell://staging.haven.digipomps.org/PersonalCopilotConfigurationCatalog"))
        if let skeleton = catalog.skeleton {
            #expect(skeletonContainsList(keypath: "personalCatalog.catalogEntries", topic: nil, in: skeleton))
            #expect(skeletonContainsTextKeypath("personalCatalog.state.appStoreScope", in: skeleton))
            #expect(skeletonContainsTextKeypath("personalCatalog.state.configurationCount", in: skeleton))
        } else {
            Issue.record("Personal Co-Pilot Catalog should expose the staging catalog contract")
        }
    }

    @Test func personalCopilotMetadataAddsSurfaceFamilyAndPresentationClass() {
        let configurations = [
            ConfigurationCatalogCell.personalHomeMenuConfiguration(),
            ConfigurationCatalogCell.personalMatchesMenuConfiguration(),
            ConfigurationCatalogCell.personalVaultIdeasMenuConfiguration(),
            ConfigurationCatalogCell.personalInviteChatMenuConfiguration()
        ]

        for configuration in configurations {
            let metadata = BindingPersonalCopilotSurfaceMetadata(configuration: configuration)
            #expect(metadata.appStoreScope == BindingPersonalCopilotV1Policy.appStoreScope)
            #expect(metadata.policyCategory != nil)
            #expect(metadata.surfaceFamily != nil)
            #expect(metadata.presentationClass != nil)
            #expect(metadata.reviewSummary?.contains("Curated Personal Co-Pilot surface") == true)
        }
    }

    @Test func personalCopilotNavigationModelStaysStable() {
        #expect(BindingPersonalCopilotDestination.phonePrimaryTabs == [.home, .matches, .chat, .vault, .profile])
        #expect(BindingPersonalCopilotDestination.sidebarSections.map(\.title) == ["Personal", "Network", "Workspace"])
        #expect(BindingPersonalCopilotDestination.defaultDestination(for: .home) == .personalHome)
        #expect(BindingPersonalCopilotDestination.defaultDestination(for: .profile) == .myProfile)
        #expect(BindingPersonalCopilotDestination.defaultDestination(for: .matches) == .matches)
        #expect(BindingPersonalCopilotDestination.defaultDestination(for: .vault) == .vaultIdeas)
        #expect(BindingPersonalCopilotDestination.matching(configurationName: "Co-Pilot") == .inviteChat)
        #expect(BindingPersonalCopilotDestination.matching(configurationName: "Co-Pilot Chat") == .inviteChat)
        #expect(BindingPersonalCopilotDestination.matching(configurationName: "Invite Chat") == .inviteChat)
        #expect(BindingPersonalCopilotDestination.matching(configurationName: "Butterpop Studio") == .butterpopStudio)
    }

    @Test func personalCopilotStyleRolesStayWithinAllowlist() {
        let configurations = [
            ConfigurationCatalogCell.personalHomeMenuConfiguration(),
            ConfigurationCatalogCell.personalProfileMenuConfiguration(),
            ConfigurationCatalogCell.personalPublicProfileMenuConfiguration(),
            ConfigurationCatalogCell.personalPublicProfileDirectoryMenuConfiguration(),
            ConfigurationCatalogCell.butterpopStudioMenuConfiguration(),
            ConfigurationCatalogCell.personalMatchesMenuConfiguration(),
            ConfigurationCatalogCell.personalVaultIdeasMenuConfiguration(),
            ConfigurationCatalogCell.personalMeetingIntentMenuConfiguration(),
            ConfigurationCatalogCell.personalPrivacyAuditMenuConfiguration(),
            ConfigurationCatalogCell.personalCopilotCatalogMenuConfiguration(),
            ConfigurationCatalogCell.personalInviteChatMenuConfiguration()
        ]

        let usedStyleRoles = Set(
            configurations
                .compactMap(\.skeleton)
                .flatMap { skeletonStyleRoles(in: $0) }
        )

        #expect(!usedStyleRoles.isEmpty)
        #expect(usedStyleRoles.allSatisfy(BindingPersonalCopilotV1Policy.allowedStyleRoles.contains))
    }

    @Test func componentMergeReusesExistingReferenceLabelAndRewritesFragmentKeypaths() {
        let recipe = ComponentPaletteCatalog.embeddedChatCard(endpoint: "cell:///Chat").recipe
        let existingReferences = [CellReference(endpoint: "cell:///Chat", label: "teamChat")]

        let mergeResult = ReferenceMergeService.merge(
            recipeReferences: recipe.referenceTemplate,
            into: existingReferences,
            fragment: recipe.skeletonTemplate
        )

        #expect(mergeResult.mergedReferences.count == 1)
        #expect(mergeResult.mergedReferences.first?.label == "teamChat")
        #expect(skeletonContainsTextArea(targetKeypath: "teamChat.setComposer", in: mergeResult.rewrittenFragment))
        #expect(!skeletonContainsTextArea(targetKeypath: "chatHub.setComposer", in: mergeResult.rewrittenFragment))
        #expect(skeletonContainsList(keypath: "teamChat.state.ui.promptMessages", topic: nil, in: mergeResult.rewrittenFragment))
        #expect(skeletonContainsButton(keypath: "teamChat.ui.openSuggestedHelper", label: "↑", in: mergeResult.rewrittenFragment))
        #expect(!skeletonContainsButton(keypath: "teamChat.sendComposedMessage", in: mergeResult.rewrittenFragment))
    }

    @Test func componentMergeRewritesListSelectionKeypathsForAssistantComponent() {
        var suggestionList = SkeletonList(topic: "catalog.matching.suggestions", keypath: nil, flowElementSkeleton: nil)
        suggestionList.selectionMode = .single
        suggestionList.selectionPayloadMode = .itemID
        suggestionList.selectionValueKeypath = "rank"
        suggestionList.selectionStateKeypath = "catalog.matching.selectedIndex"
        suggestionList.selectionActionKeypath = "catalog.matching.selectedIndex"
        suggestionList.activationActionKeypath = "catalog.matching.loadSelectedToPorthole"

        let mergeResult = ReferenceMergeService.merge(
            recipeReferences: [CellReference(endpoint: "cell:///ConfigurationCatalog", label: "catalog")],
            into: [CellReference(endpoint: "cell:///ConfigurationCatalog", label: "assistantCatalog")],
            fragment: .List(suggestionList)
        )

        guard case let .List(rewrittenList) = mergeResult.rewrittenFragment else {
            Issue.record("Forventet list-fragment etter merge")
            return
        }

        #expect(rewrittenList.topic == "assistantCatalog.matching.suggestions")
        #expect(rewrittenList.selectionStateKeypath == "assistantCatalog.matching.selectedIndex")
        #expect(rewrittenList.selectionActionKeypath == "assistantCatalog.matching.selectedIndex")
        #expect(rewrittenList.activationActionKeypath == "assistantCatalog.matching.loadSelectedToPorthole")
    }

    @Test func referenceUsageAnalyzerCountsListSelectionKeypathsAsReferenceUsage() {
        var suggestionList = SkeletonList(topic: nil, keypath: nil, flowElementSkeleton: nil)
        suggestionList.selectionMode = .single
        suggestionList.selectionPayloadMode = .itemID
        suggestionList.selectionValueKeypath = "rank"
        suggestionList.selectionStateKeypath = "catalog.matching.selectedIndex"
        suggestionList.selectionActionKeypath = "catalog.matching.selectedIndex"
        suggestionList.activationActionKeypath = "catalog.matching.loadSelectedToPorthole"

        let report = ReferenceUsageAnalyzer.analyze(
            skeleton: .List(suggestionList),
            references: [CellReference(endpoint: "cell:///ConfigurationCatalog", label: "catalog")]
        )

        #expect(report.referencedLabels == ["catalog"])
        #expect(report.unusedTopLevelLabels.isEmpty)
    }

    @Test func tabStripLauncherContractCarriesSelectedCellConfigurationInActivationPayload() throws {
        let agendaConfiguration = CellConfiguration(name: "Agenda Surface")
        let chatConfiguration = CellConfiguration(name: "Chat Surface")

        var tabStrip = SkeletonList(elements: [
            .object([
                "id": .string("agenda"),
                "title": .string("Agenda"),
                "badge": .string("3"),
                "icon": .string("calendar"),
                "configuration": .cellConfiguration(agendaConfiguration)
            ]),
            .object([
                "id": .string("chat"),
                "title": .string("Chat"),
                "icon": .string("bubble.left.and.bubble.right"),
                "configuration": .cellConfiguration(chatConfiguration)
            ])
        ])
        tabStrip.selectionMode = .single
        tabStrip.selectionStateKeypath = "tabs.selected"
        tabStrip.activationActionKeypath = "tabs.loadSelectedConfiguration"
        tabStrip.selectionPayloadMode = .item

        var modifiers = SkeletonModifiers()
        modifiers.styleRole = "tabstrip"
        modifiers.styleClasses = ["top-pinned", "compact"]
        tabStrip.modifiers = modifiers

        let payload = try tabStrip.selectionPayload(
            trigger: .activate,
            rows: tabStrip.elements,
            selectedIndices: [1]
        )

        guard case let .object(object) = payload,
              case let .object(selected)? = object["selected"],
              case let .cellConfiguration(configuration)? = selected["configuration"] else {
            Issue.record("Forventet activation-payload med valgt CellConfiguration i selected.configuration")
            return
        }

        #expect(object["trigger"] == .string("activate"))
        #expect(object["selectionMode"] == .string("single"))
        #expect(object["selectedIndex"] == .integer(1))
        #expect(selected["title"] == .string("Chat"))
        #expect(selected["icon"] == .string("bubble.left.and.bubble.right"))
        #expect(configuration.name == "Chat Surface")
    }

    @Test func tabStripLauncherContractRoundTripsStyleMetadataInSkeletonJSON() throws {
        let agendaConfiguration = CellConfiguration(name: "Agenda Surface")

        var tabStrip = SkeletonList(elements: [
            .object([
                "id": .string("agenda"),
                "title": .string("Agenda"),
                "configuration": .cellConfiguration(agendaConfiguration)
            ])
        ])
        tabStrip.selectionMode = .single
        tabStrip.selectionStateKeypath = "tabs.selected"
        tabStrip.activationActionKeypath = "tabs.loadSelectedConfiguration"
        tabStrip.selectionPayloadMode = .item

        var modifiers = SkeletonModifiers()
        modifiers.styleRole = "tabstrip"
        modifiers.styleClasses = ["bottom-pinned", "prominent"]
        tabStrip.modifiers = modifiers

        let data = try JSONEncoder().encode(SkeletonElement.List(tabStrip))
        let decoded = try JSONDecoder().decode(SkeletonElement.self, from: data)

        guard case let .List(decodedList) = decoded else {
            Issue.record("Forventet List etter roundtrip av tabstrip-kontrakt")
            return
        }

        #expect(decodedList.selectionMode == .single)
        #expect(decodedList.selectionPayloadMode == .item)
        #expect(decodedList.selectionStateKeypath == "tabs.selected")
        #expect(decodedList.activationActionKeypath == "tabs.loadSelectedConfiguration")
        #expect(decodedList.modifiers?.styleRole == "tabstrip")
        #expect(decodedList.modifiers?.styleClasses == ["bottom-pinned", "prominent"])
    }

    @Test func tabStripV1UsesSkeletonCompositionForBottomPinning() {
        let homeConfiguration = CellConfiguration(name: "Home Surface")
        let settingsConfiguration = CellConfiguration(name: "Settings Surface")

        var tabStrip = SkeletonList(elements: [
            .object([
                "id": .string("home"),
                "title": .string("Home"),
                "configuration": .cellConfiguration(homeConfiguration)
            ]),
            .object([
                "id": .string("settings"),
                "title": .string("Settings"),
                "configuration": .cellConfiguration(settingsConfiguration)
            ])
        ])
        tabStrip.selectionMode = .single
        tabStrip.selectionStateKeypath = "tabs.selected"
        tabStrip.activationActionKeypath = "tabs.loadSelectedConfiguration"
        tabStrip.selectionPayloadMode = .item

        var modifiers = SkeletonModifiers()
        modifiers.styleRole = "tabstrip"
        modifiers.styleClasses = ["bottom-pinned"]
        tabStrip.modifiers = modifiers

        let root = SkeletonElement.VStack(
            SkeletonVStack(elements: [
                .ScrollView(
                    SkeletonScrollView(axis: "vertical", elements: [
                        .Text(SkeletonText(text: "Panel content"))
                    ])
                ),
                .List(tabStrip)
            ])
        )

        guard case let .VStack(stack) = root,
              case .ScrollView = stack.elements.first,
              case let .List(bottomStrip)? = stack.elements.last else {
            Issue.record("Forventet bottom-pinned komposisjon med ScrollView først og List sist")
            return
        }

        #expect(bottomStrip.modifiers?.styleRole == "tabstrip")
        #expect(bottomStrip.modifiers?.styleClasses == ["bottom-pinned"])
    }

    @Test func componentPaletteOffersChatVaultAndAssistantWidgets() {
        let ids = Set(ComponentPaletteCatalog.defaultItems().map(\.id))
        #expect(ids.contains("chat.embedded.card"))
        #expect(ids.contains("vault.embedded.snapshot"))
        #expect(ids.contains("catalog.embedded.purposeAssistant"))
    }

    @Test func libraryEmbeddedComponentFallsBackToEditorContainersWhenCatalogKindsAreExternal() {
        var configuration = CellConfiguration(name: "Vault Compact")
        configuration.description = "Embedded vault snapshot"
        configuration.addReference(CellReference(endpoint: "cell:///Vault", label: "vault"))
        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "vault.summary.title"))
        ]))

        let component = ComponentPaletteCatalog.libraryEmbeddedComponent(
            configuration: configuration,
            displayName: "Vault Compact",
            summary: "Embedded vault snapshot",
            supportedTargetKinds: ["menu", "porthole", "library"]
        )

        #expect(component?.sourceKind == .library)
        #expect(component?.recipe.supportedTargetKinds == ["root", "vstack", "section", "scrollview", "grid"])
        #expect(component?.recipe.referenceTemplate.first?.endpoint == "cell:///Vault")
    }

    @Test func libraryEmbeddedComponentReturnsNilWithoutSkeleton() {
        var configuration = CellConfiguration(name: "Agent Shell")
        configuration.description = "No skeleton yet"
        configuration.skeleton = nil
        configuration.addReference(CellReference(endpoint: "cell:///ConfigurationCatalog", label: "catalog"))

        let component = ComponentPaletteCatalog.libraryEmbeddedComponent(
            configuration: configuration,
            displayName: "Agent Shell",
            summary: "No skeleton yet",
            supportedTargetKinds: ["root"]
        )

        #expect(component == nil)
    }

    @MainActor
    @Test func editorAppliesPreferredChatComponentIntoSelectedContainer() {
        let recipe = ComponentPaletteCatalog.defaultItems()[0].recipe
        var configuration = CellConfiguration(name: "Host")
        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(text: "Host"))
        ]))

        let editorState = EditorState()
        editorState.beginEditing(configuration: configuration)

        #expect(editorState.applyPreferredComponent(recipe))
        #expect(editorState.selectedNodePath == .root.appending(1))

        guard let workingSkeleton = editorState.workingCopy else {
            Issue.record("Forventet working skeleton etter component insert")
            return
        }

        let references = editorState.workingConfiguration?.cellReferences ?? []
        #expect(references.contains(where: { $0.endpoint == "cell:///PersonalChatHub" && $0.label == "chatHub" }))
        #expect(skeletonContainsTextArea(targetKeypath: "chatHub.setComposer", in: workingSkeleton))
        #expect(skeletonContainsList(keypath: "chatHub.state.ui.promptMessages", topic: nil, in: workingSkeleton))
        #expect(skeletonContainsButton(keypath: "chatHub.ui.openSuggestedHelper", label: "↑", in: workingSkeleton))
        #expect(!skeletonContainsButton(keypath: "chatHub.sendComposedMessage", in: workingSkeleton))
    }

    @Test func localOnlyCellsAreNotRetargetedToStaging() {
        let contentView = ContentView()

        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///EntityScanner") == "cell:///EntityScanner")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///ConferenceParticipantDiscoverySnapshot") == "cell:///ConferenceParticipantDiscoverySnapshot")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///ConferenceParticipantPreviewShell") == "cell:///ConferenceParticipantPreviewShell")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///ConferenceAdminPreviewShell") == "cell:///ConferenceAdminPreviewShell")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///ConferenceAIAssistantGatewayProxy") == "cell:///ConferenceAIAssistantGatewayProxy")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///ConferenceIdentityLinkIntake") == "cell:///ConferenceIdentityLinkIntake")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///AppleIntelligence") == "cell:///AppleIntelligence")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///agent/network/sentinel") == "cell:///agent/network/sentinel")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///Chat") == "cell://staging.haven.digipomps.org/Chat")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///AIGateway") == "cell://staging.haven.digipomps.org/AIGateway")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///ConferencePublicProfileEditorPreview") == "cell://staging.haven.digipomps.org/ConferencePublicProfileEditorPreview")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///ConferencePublicProfilePreview") == "cell://staging.haven.digipomps.org/ConferencePublicProfilePreview")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///ArendalsukaParticipantProgram") == "cell://staging.haven.digipomps.org/ArendalsukaParticipantProgram")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///ArendalsukaEventAtlas") == "cell://staging.haven.digipomps.org/ArendalsukaEventAtlas")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///WorkItem") == "cell://staging.haven.digipomps.org/WorkItem")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///AgreementWorkbench") == "cell://staging.haven.digipomps.org/AgreementWorkbench")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///EntityStudio") == "cell://staging.haven.digipomps.org/EntityStudio")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///TrustedIssuers") == "cell://staging.haven.digipomps.org/TrustedIssuers")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///EntityAnchor") == "cell://staging.haven.digipomps.org/EntityAnchor")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///ProjectPortfolio") == "cell://staging.haven.digipomps.org/ProjectPortfolio")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///GitHubWorkSync") == "cell://staging.haven.digipomps.org/GitHubWorkSync")
        #expect(contentView.maybeRetargetLocalEndpointToStaging("cell:///IdeaTaskWorkspace") == "cell://staging.haven.digipomps.org/IdeaTaskWorkspace")
    }

    @Test func configurationEndpointRetargetingRewritesNestedConfigurationLookupEndpoints() throws {
        let contentView = ContentView()
        var configuration = CellConfiguration(name: "Conference Public Profile Editor")
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: "cell:///ConferencePublicProfileEditorPreview",
            sourceCellName: "ConferencePublicProfileEditorPreviewCell",
            purpose: "Conference public profile editor",
            purposeDescription: "Preview wrapper",
            interests: ["conference", "profile"],
            menuSlots: ["upperMid"]
        )

        var reference = CellReference(
            endpoint: "cell:///ConferencePublicProfileEditorPreview",
            label: "conferencePublicProfileEditor"
        )
        reference.setKeysAndValues = [
            KeyValue(
                key: "state",
                value: nil,
                target: "cell:///ConferencePublicProfilePreview"
            )
        ]
        configuration.addReference(reference)
        configuration.skeleton = .VStack(
            SkeletonVStack(elements: [
                .Button(
                    SkeletonButton(
                        keypath: "addConfiguration",
                        label: "Open public profile",
                        payload: .object([
                            "configurationLookup": .object([
                                "name": .string("Conference Public Profile"),
                                "sourceCellEndpoint": .string("cell:///ConferencePublicProfilePreview")
                            ])
                        ])
                    )
                )
            ])
        )

        let retargeted = CellConfigurationEndpointRetargeting.rewritingEndpoints(in: configuration) {
            contentView.maybeRetargetLocalEndpointToStaging($0)
        }

        #expect(retargeted.discovery?.sourceCellEndpoint == "cell://staging.haven.digipomps.org/ConferencePublicProfileEditorPreview")
        #expect(retargeted.cellReferences?.first?.endpoint == "cell://staging.haven.digipomps.org/ConferencePublicProfileEditorPreview")
        #expect(retargeted.cellReferences?.first?.setKeysAndValues.first?.target == "cell://staging.haven.digipomps.org/ConferencePublicProfilePreview")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let data = try? encoder.encode(retargeted),
              let json = String(data: data, encoding: .utf8) else {
            Issue.record("Expected JSON-serializable retargeted configuration")
            return
        }

        #expect(json.contains("\"sourceCellEndpoint\":\"cell://staging.haven.digipomps.org/ConferencePublicProfilePreview\""))
    }

    @Test func configurationEndpointRetargetingCanPointLocalReferencesAtFetchedScaffold() throws {
        var configuration = CellConfiguration(name: "Remote Imported Workspace")
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: "cell:///RemoteWorkspace",
            sourceCellName: "RemoteWorkspaceCell",
            purpose: "Remote workspace",
            purposeDescription: "Imported over a bridge",
            interests: ["remote"],
            menuSlots: ["upperLeft"]
        )

        var reference = CellReference(endpoint: "cell:///RemoteWorkspace", label: "workspace")
        reference.setKeysAndValues = [
            KeyValue(
                key: "state",
                value: nil,
                target: "cell:///RemotePeer"
            )
        ]
        configuration.addReference(reference)
        configuration.skeleton = .VStack(
            SkeletonVStack(elements: [
                .Button(
                    SkeletonButton(
                        keypath: "addConfiguration",
                        label: "Open remote peer",
                        payload: .object([
                            "configurationLookup": .object([
                                "name": .string("Remote Peer"),
                                "sourceCellEndpoint": .string("cell:///RemotePeer")
                            ])
                        ])
                    )
                )
            ])
        )

        let retargeted = CellConfigurationEndpointRetargeting.rewritingLocalCellEndpoints(
            in: configuration,
            toScaffoldEndpoint: "cell://preview.example.org/ConfigurationCatalog"
        )

        #expect(retargeted.discovery?.sourceCellEndpoint == "cell://preview.example.org/RemoteWorkspace")
        #expect(retargeted.cellReferences?.first?.endpoint == "cell://preview.example.org/RemoteWorkspace")
        #expect(retargeted.cellReferences?.first?.setKeysAndValues.first?.target == "cell://preview.example.org/RemotePeer")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let data = try encoder.encode(retargeted)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("\"sourceCellEndpoint\":\"cell://preview.example.org/RemotePeer\""))
    }

    @Test func remoteHavenWorkbenchConfigurationRetargetsToFetchedScaffoldOrigin() throws {
        let remoteHost = "agent.binding.test"
        let remoteCatalogEndpoint = "cell://\(remoteHost)/ConfigurationCatalog"
        let configuration = Self.remoteHavenWorkbenchFixtureConfiguration()

        let retargeted = CellConfigurationEndpointRetargeting.rewritingLocalCellEndpoints(
            in: configuration,
            toScaffoldEndpoint: remoteCatalogEndpoint
        )
        let endpoints = try Self.cellEndpointStrings(in: retargeted)

        #expect(retargeted.name == "HAVEN Workbench")
        #expect(retargeted.discovery?.sourceCellEndpoint == "cell://\(remoteHost)/WorkItem")
        #expect(endpoints.contains("cell://\(remoteHost)/WorkItem"))
        #expect(endpoints.contains("cell://\(remoteHost)/ProjectPortfolio"))
        #expect(endpoints.contains("cell://\(remoteHost)/GitHubWorkSync"))
        #expect(endpoints.contains("cell://\(remoteHost)/IdeaTaskWorkspace"))
        #expect(!endpoints.contains(where: Self.isLocalCellEndpoint))

        let resolver = CellResolver.sharedInstance
        let previousRoute = resolver.remoteCellHostRoutesSnapshot()[remoteHost]
        defer {
            if let previousRoute {
                resolver.registerRemoteCellHost(remoteHost, route: previousRoute)
            } else {
                resolver.unregisterRemoteCellHost(remoteHost)
            }
        }
        resolver.unregisterRemoteCellHost(remoteHost)

        ContentView().registerRemoteRoutesIfNeeded(for: retargeted, resolver: resolver)

        let route = resolver.remoteCellHostRoutesSnapshot()[remoteHost]
        #expect(route?.websocketEndpoint == "bridgehead")
    }

    @Test func remoteArendalsukaConfigurationsRespectCatalogPublicationAndRetargetWhenPresent() throws {
        let remoteCatalogWithoutEventAccess = [
            Self.remoteHavenWorkbenchFixtureConfiguration()
        ]
        #expect(!remoteCatalogWithoutEventAccess.contains { $0.name == "Arendalsuka Participant Program" })
        #expect(!remoteCatalogWithoutEventAccess.contains { $0.name == "Arendalsuka Event Atlas" })

        let remoteCatalogEndpoint = "cell://staging.haven.digipomps.org/ConfigurationCatalog"
        let publishedArendalsuka = [
            Self.remoteArendalsukaParticipantProgramFixtureConfiguration(),
            Self.remoteArendalsukaEventAtlasFixtureConfiguration()
        ].map {
            CellConfigurationEndpointRetargeting.rewritingLocalCellEndpoints(
                in: $0,
                toScaffoldEndpoint: remoteCatalogEndpoint
            )
        }

        let publishedNames = Set(publishedArendalsuka.map(\.name))
        #expect(publishedNames.contains("Arendalsuka Participant Program"))
        #expect(publishedNames.contains("Arendalsuka Event Atlas"))

        let participantEndpoints = try Self.cellEndpointStrings(in: publishedArendalsuka[0])
        #expect(publishedArendalsuka[0].discovery?.sourceCellEndpoint == "cell://staging.haven.digipomps.org/ArendalsukaParticipantProgram")
        #expect(participantEndpoints.contains("cell://staging.haven.digipomps.org/ArendalsukaParticipantProgram"))
        #expect(participantEndpoints.contains("cell://staging.haven.digipomps.org/ArendalsukaEventAtlas"))
        #expect(!participantEndpoints.contains(where: Self.isLocalCellEndpoint))
        #expect(participantEndpoints.allSatisfy {
            RemoteEndpointAccessSupport.authorizationKind(for: $0) == .scaffoldAdmission
        })

        let resolver = CellResolver.sharedInstance
        let stagingHost = "staging.haven.digipomps.org"
        let previousRoute = resolver.remoteCellHostRoutesSnapshot()[stagingHost]
        defer {
            if let previousRoute {
                resolver.registerRemoteCellHost(stagingHost, route: previousRoute)
            } else {
                resolver.unregisterRemoteCellHost(stagingHost)
            }
        }
        resolver.unregisterRemoteCellHost(stagingHost)

        ContentView().registerRemoteRoutesIfNeeded(for: publishedArendalsuka[0], resolver: resolver)

        let route = resolver.remoteCellHostRoutesSnapshot()[stagingHost]
        #expect(route?.websocketEndpoint == "bridgehead")
        #expect(route?.schemePreference == .wss)
        let usesEndpointFirstPath: Bool
        if case .some(.endpointThenPublisherUUID) = route?.pathLayout {
            usesEndpointFirstPath = true
        } else {
            usesEndpointFirstPath = false
        }
        #expect(usesEndpointFirstPath)
    }

    @Test func localVerifierCanRetargetKnownStagingPersonalCopilotFallbacks() throws {
        let cases: [(CellConfiguration, String, String)] = [
            (
                ConfigurationCatalogCell.personalPublicProfileMenuConfiguration(),
                "cell://staging.haven.digipomps.org/PersonalProfilePublisher",
                "cell:///PersonalProfilePublisher"
            ),
            (
                ConfigurationCatalogCell.personalPublicProfileDirectoryMenuConfiguration(),
                "cell://staging.haven.digipomps.org/PublicProfileDirectory",
                "cell:///PublicProfileDirectory"
            ),
            (
                ConfigurationCatalogCell.personalMatchesMenuConfiguration(),
                "cell://staging.haven.digipomps.org/PersonalMatchmaking",
                "cell:///PersonalMatchmaking"
            ),
            (
                ConfigurationCatalogCell.personalMeetingIntentMenuConfiguration(),
                "cell://staging.haven.digipomps.org/PersonalMeetingCoordinator",
                "cell:///PersonalMeetingCoordinator"
            ),
            (
                ConfigurationCatalogCell.personalCopilotCatalogMenuConfiguration(),
                "cell://staging.haven.digipomps.org/PersonalCopilotConfigurationCatalog",
                "cell:///PersonalCopilotConfigurationCatalog"
            )
        ]

        for (configuration, stagingEndpoint, localEndpoint) in cases {
            let retargeted = CellConfigurationEndpointRetargeting
                .rewritingStagingPersonalCopilotEndpointsToLocalFallbacks(in: configuration)

            #expect(retargeted.discovery?.sourceCellEndpoint == localEndpoint)
            #expect(BindingPersonalCopilotV1Policy.referencedEndpoints(in: configuration).contains(stagingEndpoint))
            #expect(BindingPersonalCopilotV1Policy.referencedEndpoints(in: retargeted).contains(localEndpoint))
            #expect(!BindingPersonalCopilotV1Policy.referencedEndpoints(in: retargeted).contains(stagingEndpoint))
        }
    }

    @Test func fullLibraryCanPreferRemoteCatalogEndpointsBeforeLocalFallback() {
        let ordered = RemoteCatalogSupport.orderedCatalogCandidateEndpoints(from: [
            "cell:///ConfigurationCatalog",
            "cell://staging.haven.digipomps.org/ConfigurationCatalog"
        ], preference: .preferRemote)

        #expect(ordered == [
            "cell://staging.haven.digipomps.org/ConfigurationCatalog",
            "cell:///ConfigurationCatalog"
        ])
    }

    @Test func fullLibraryPrefersLocalCatalogWhenPolicyAllowsCache() {
        let ordered = RemoteCatalogSupport.orderedCatalogCandidateEndpoints(from: [
            "cell:///ConfigurationCatalog",
            "cell://staging.haven.digipomps.org/ConfigurationCatalog"
        ], preference: .preferLocal)

        #expect(ordered == [
            "cell:///ConfigurationCatalog",
            "cell://staging.haven.digipomps.org/ConfigurationCatalog"
        ])
    }

    @Test func fullLibraryAppendsLocalCatalogFallbackWhenOnlyRemoteEndpointsAreProvided() {
        let ordered = RemoteCatalogSupport.orderedCatalogCandidateEndpoints(from: [
            "cell://staging.haven.digipomps.org/ConfigurationCatalog"
        ], preference: .preferRemote)

        #expect(ordered == [
            "cell://staging.haven.digipomps.org/ConfigurationCatalog",
            "cell:///ConfigurationCatalog"
        ])
    }

    @MainActor
    @Test func fullLibrarySummarizesSourceLimitWarningsForHumans() {
        let presentation = FullLibraryViewModel.presentWarnings([
            "cell://staging.haven.digipomps.org/AdminFunding:maxSourcesLimit",
            "cell://staging.haven.digipomps.org/AdminOverview:maxSourcesLimit"
        ])

        #expect(presentation.messages == [
            "2 eksterne kilder ble hoppet over for å holde biblioteket raskt."
        ])
        #expect(presentation.details.count == 2)
    }

    @MainActor
    @Test func fullLibrarySummarizesRemoteFallbackWarningsForHumans() {
        let presentation = FullLibraryViewModel.presentWarnings([
            "Remote tilgang til cell://staging.haven.digipomps.org/ConfigurationCatalog feilet. Fortsetter til neste kilde.",
            "Kilden støtter ikke facetCounts. Viser lokale fasetter for treffene."
        ])

        #expect(presentation.messages == [
            "En ekstern katalogkilde var treg eller utilgjengelig. Biblioteket fortsatte med lokale data.",
            "Filtertellinger er beregnet lokalt for denne visningen."
        ])
    }

    @MainActor
    @Test func fullLibraryPrefersQueryBestMatchForPreviewSelection() {
        let model = FullLibraryViewModel(
            catalogEndpoints: ["cell:///ConfigurationCatalog"],
            queryContext: FullLibraryQueryContext(editMode: false, selectedNodeKind: nil, insertionIntent: .unknown),
            fallbackFavorites: [],
            fallbackTemplates: []
        )
        model.queryText = "control tower"

        let results = [
            FullLibraryViewModel.SearchResult(
                id: "participant",
                configurationId: "participant",
                displayName: "Conference Participant Portal Dashboard",
                summary: "Participant-shell over preview-wrapper.",
                sourceRef: "cell://staging.haven.digipomps.org/ConferenceParticipantPreviewShell",
                origin: .catalog(endpoint: "cell://staging.haven.digipomps.org/ConfigurationCatalog"),
                route: "directPurpose",
                score: 0.64,
                scoreBreakdown: .init(text: 0.5, purpose: 0.5, interest: 0.5, compatibility: 1.0, connectivity: 1.0, resourceFit: 1.0, recency: 1.0),
                badges: ["conference", "participant"],
                configuration: CellConfiguration(name: "Conference Participant Portal Dashboard"),
                componentItem: nil
            ),
            FullLibraryViewModel.SearchResult(
                id: "control-tower",
                configurationId: "control-tower",
                displayName: "Conference Control Tower",
                summary: "Organizer/admin-shell med drift, innhold og innsikt over staging.",
                sourceRef: "cell://staging.haven.digipomps.org/ConferenceAdminShell",
                origin: .catalog(endpoint: "cell://staging.haven.digipomps.org/ConfigurationCatalog"),
                route: "directPurpose",
                score: 0.64,
                scoreBreakdown: .init(text: 0.5, purpose: 0.5, interest: 0.5, compatibility: 1.0, connectivity: 1.0, resourceFit: 1.0, recency: 1.0),
                badges: ["conference", "admin"],
                configuration: CellConfiguration(name: "Conference Control Tower"),
                componentItem: nil
            )
        ]

        let preferred = model.preferredSelectionID(in: results, currentSelectionID: "participant")
        #expect(preferred == "control-tower")
    }

    @Test func remoteCatalogSyncRunsOnlyForLocalCatalogEndpoint() {
        #expect(RemoteCatalogSupport.shouldSyncCatalogBeforeQuery(for: "cell:///ConfigurationCatalog"))
        #expect(!RemoteCatalogSupport.shouldSyncCatalogBeforeQuery(for: "cell://staging.haven.digipomps.org/ConfigurationCatalog"))
        #expect(!RemoteCatalogSupport.shouldSyncCatalogBeforeQuery(for: "wss://staging.haven.digipomps.org/bridgehead/ConfigurationCatalog"))
    }

    @Test func remoteCatalogAdmissionRunsOnlyForRemoteCatalogEndpoints() {
        #expect(!RemoteCatalogSupport.shouldAttemptAdmission(for: "cell:///ConfigurationCatalog"))
        #expect(RemoteCatalogSupport.shouldAttemptAdmission(for: "cell://staging.haven.digipomps.org/ConfigurationCatalog"))
        #expect(RemoteCatalogSupport.shouldAttemptAdmission(for: "wss://staging.haven.digipomps.org/bridgehead/ConfigurationCatalog"))
    }

    @Test func remoteMenuRecoverySkipsStagingEndpointsDuringMenuBuild() {
        #expect(RemoteCatalogSupport.shouldEagerlyRecoverMenuEndpoint("cell:///Vault"))
        #expect(!RemoteCatalogSupport.shouldEagerlyRecoverMenuEndpoint("cell://staging.haven.digipomps.org/Vault"))
        #expect(!RemoteCatalogSupport.shouldEagerlyRecoverMenuEndpoint("wss://staging.haven.digipomps.org/bridgehead/Vault"))
    }

    @Test func thinRemoteConfigurationsRecoverOnlyWhenUserActuallyOpensThem() {
        var thinRemoteConfiguration = CellConfiguration(name: "Thin Remote Vault")
        thinRemoteConfiguration.addReference(CellReference(
            endpoint: "cell://staging.haven.digipomps.org/Vault",
            label: "vault"
        ))
        thinRemoteConfiguration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(text: "Vault"))
        ]))

        #expect(RemoteCatalogSupport.shouldRecoverConfigurationOnDemand(thinRemoteConfiguration))

        var dynamicRemoteConfiguration = thinRemoteConfiguration
        dynamicRemoteConfiguration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "vault.summary.title"))
        ]))

        #expect(!RemoteCatalogSupport.shouldRecoverConfigurationOnDemand(dynamicRemoteConfiguration))
    }

    @Test func conferenceShortcutUsesDesignedScrollSurface() {
        let configuration = ConfigurationCatalogCell.conferenceMVPWorkbenchMenuConfiguration(
            endpoint: "cell://staging.haven.digipomps.org/ConferenceUIRouter"
        )

        #expect(configuration.cellReferences?.first?.label == "conferenceUIRouter")
        #expect(configuration.cellReferences?.first?.endpoint == "cell://staging.haven.digipomps.org/ConferenceUIRouter")

        guard case .ScrollView? = configuration.skeleton else {
            Issue.record("Conference MVP should use a designed scroll surface")
            return
        }
    }

    @Test func conferenceAIAssistantWorkbenchSeedsConferenceAndAIGatewayState() {
        let configuration = ConfigurationCatalogCell.conferenceAIAssistantWorkbenchConfiguration(
            conferenceEndpoint: "cell://staging.haven.digipomps.org/ConferenceParticipantPreviewShell",
            aiEndpoint: "cell://staging.haven.digipomps.org/ConferenceAIGatewayPreview"
        )

        #expect(configuration.name == "Conference AI Assistant")
        #expect(configuration.cellReferences?.count == 2)
        #expect(configuration.cellReferences?.first?.label == "conferenceParticipantShell")
        #expect(configuration.cellReferences?.first?.setKeysAndValues.contains(where: { $0.key == "state" }) == true)
        #expect(configuration.cellReferences?.last?.label == "aiGateway")
        #expect(configuration.cellReferences?.last?.endpoint == "cell://staging.haven.digipomps.org/ConferenceAIGatewayPreview")

        guard case .ScrollView? = configuration.skeleton else {
            Issue.record("Conference AI Assistant should use a designed scroll surface")
            return
        }
    }

    @Test func conferenceAutomationAIAssistantUsesScaffoldHostedPreview() {
        let configuration = ContentView.conferenceAIAssistantAutomationConfiguration()

        #expect(configuration.name == "Conference AI Assistant")
        #expect(configuration.cellReferences?.first?.endpoint == "cell:///ConferenceParticipantPreviewShell")
        #expect(configuration.cellReferences?.last?.endpoint == "cell:///ConferenceAIAssistantGatewayProxy")
    }

    @Test func conferenceIdentityLinkWorkbenchSeedsLocalIntakeState() {
        let configuration = ConfigurationCatalogCell.conferenceIdentityLinkWorkbenchConfiguration()

        #expect(configuration.name == "Conference Scaffold Setup & Identity Link")
        #expect(configuration.cellReferences?.count == 1)
        #expect(configuration.cellReferences?.first?.label == "identityLink")
        #expect(configuration.cellReferences?.first?.endpoint == "cell:///ConferenceIdentityLinkIntake")
        #expect(configuration.cellReferences?.first?.setKeysAndValues.contains(where: { $0.key == "state" }) == true)

        guard case .ScrollView? = configuration.skeleton else {
            Issue.record("Conference identity-link workbench should use a designed scroll surface")
            return
        }
    }

    @Test func conferenceIdentityLinkInboxParsesDeepLinkChallenge() async throws {
        let store = ConferenceIdentityLinkInboxStore.shared
        await store.clear()
        let futureExpiry = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
        let challengeNonce = "aWRlbnRpdHktbGluay1jaGFsbGVuZ2UtcmFuZG9tLTIwMjY"

        let url = try #require(
            URL(string: "haven://identity-link?requestId=REQ-123&audience=staging.haven.digipomps.org&origin=haven://binding/add-device&entityAnchorReference=cell:///EntityAnchor&deviceLabel=Kjetil%20iPhone&identity=Kjetil%20iPhone&domains=private,scaffold&contexts=private,scaffold&scopes=entity-auth,personal-cells&challenge=\(challengeNonce)&expiresAt=\(futureExpiry)&algorithm=P256-ES256")
        )

        #expect(await store.ingest(url: url))

        let state = await store.stateObject()
        guard case let .object(incoming)? = state["incoming"],
              case let .object(review)? = state["review"] else {
            Issue.record("Expected incoming/review identity-link state objects")
            await store.clear()
            return
        }

        #expect(incoming["challengeSummary"] == .string("Request REQ-123"))
        #expect(incoming["audienceSummary"] == .string("Audience: staging.haven.digipomps.org"))
        #expect(incoming["domainSummary"] == .string("Requested domains: private, scaffold"))
        #expect(incoming["scopeSummary"] == .string("Requested scopes: entity-auth, personal-cells"))
        #expect(review["confirmationStatus"] == .string("Lokal brukerbekreftelse mangler."))

        await store.clear()
    }

    @Test func conferenceIdentityLinkParserRejectsDuplicateParametersAndUntrustedWebOrigins() throws {
        let duplicate = try #require(URL(string: "haven://identity-link?requestId=one&requestId=two"))
        let hostileHTTPS = try #require(URL(string: "https://evil.example/identity-link?requestId=one"))
        let hostileHTTP = try #require(URL(string: "http://staging.haven.digipomps.org/identity-link?requestId=one"))
        let substringRoute = try #require(URL(string: "haven://identity-link/anything?requestId=one"))

        #expect(ConferenceIdentityLinkSupport.parse(url: duplicate) == nil)
        #expect(ConferenceIdentityLinkSupport.parse(url: hostileHTTPS) == nil)
        #expect(ConferenceIdentityLinkSupport.parse(url: hostileHTTP) == nil)
        #expect(ConferenceIdentityLinkSupport.parse(url: substringRoute) == nil)
    }

    @Test func conferenceIdentityLinkNewChallengeClearsPreviouslySignedDerivedState() async throws {
        let store = ConferenceIdentityLinkInboxStore.shared
        await store.clear()
        let identity = try #require(
            await BindingStartupIdentityVault.shared.identity(for: "private", makeNewIfNotFound: true)
        )
        let firstExpiry = ISO8601DateFormatter().string(from: Date().addingTimeInterval(900))
        let first = try #require(URL(string: "haven://identity-link?requestId=REQ-FIRST&audience=staging.haven.digipomps.org&origin=haven://binding/add-device&entityAnchorReference=cell:///EntityAnchor&domains=private,scaffold&contexts=private,scaffold&scopes=entity-auth,personal-cells&challenge=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA&expiresAt=\(firstExpiry)&algorithm=P256-ES256"))
        #expect(await store.ingest(url: first))
        await store.confirmLocalReview(with: identity)
        let signedState = await store.stateObject()
        guard case let .object(signedReview)? = signedState["review"] else {
            Issue.record("Expected signed review state")
            return
        }
        #expect(signedReview["enrollmentRequest"] != .null)

        let second = try #require(URL(string: "haven://identity-link?requestId=REQ-SECOND&audience=staging.haven.digipomps.org&origin=haven://binding/add-device&entityAnchorReference=cell:///EntityAnchor&domains=private,scaffold&contexts=private,scaffold&scopes=entity-auth,personal-cells&challenge=BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB&expiresAt=\(firstExpiry)&algorithm=P256-ES256"))
        #expect(await store.ingest(url: second))
        let resetState = await store.stateObject()
        guard case let .object(resetReview)? = resetState["review"] else {
            Issue.record("Expected reset review state")
            return
        }
        #expect(resetReview["enrollmentRequest"] == .null)
        #expect(resetReview["confirmationStatus"] == .string("Lokal brukerbekreftelse mangler."))
        await store.clear()
    }

    @Test func conferenceIdentityLinkInboxRefusesExpiredChallengeSigning() async throws {
        let store = ConferenceIdentityLinkInboxStore.shared
        await store.clear()

        let url = try #require(
            URL(string: "haven://identity-link?requestId=REQ-EXPIRED&audience=staging.haven.digipomps.org&origin=haven://binding/add-device&entityAnchorReference=cell:///EntityAnchor&deviceLabel=Kjetil%20iPhone&identity=Kjetil%20iPhone&domains=private,scaffold&contexts=private,scaffold&scopes=entity-auth,personal-cells&challenge=AAAAAAAAAAAAAAAAAAAAAA&expiresAt=2026-04-02T12:00:00Z&algorithm=P256-ES256")
        )

        #expect(await store.ingest(url: url))

        let identity = await BindingStartupIdentityVault.shared.identity(for: "private", makeNewIfNotFound: true)
        await store.confirmLocalReview(with: identity)

        let state = await store.stateObject()
        guard case let .object(review)? = state["review"] else {
            Issue.record("Expected review identity-link state object")
            await store.clear()
            return
        }

        #expect(review["confirmationStatus"] == .string("Challenge er utløpt. HAVEN nekter å signere enrollment request."))
        #expect(review["enrollmentRequest"] == .null)

        await store.clear()
    }

    @Test func bindingAdmissionChallengeSupportDecodesSharedPayload() throws {
        let owner = Identity()
        let agreement = Agreement(owner: owner)
        agreement.name = "Binding Admission"

        let helperConfiguration = CellConfiguration(name: "Helper Surface")
        let issue = AdmissionChallengeIssueRecord(
            conditionName: "sameEntityLink",
            conditionType: "binding.same-entity",
            state: .unmet,
            reasonCode: "same_entity_link_review_required",
            userMessage: "Review same-entity link request before continuing.",
            requiredAction: "open_helper_configuration",
            canAutoResolve: false,
            helperCellConfiguration: helperConfiguration,
            developerHint: "Helper should stay optional but portable."
        )
        let session = AdmissionSession(
            label: "Same entity link",
            requesterUUID: "requester-123",
            targetCellUUID: "target-456",
            agreementUUID: agreement.uuid,
            agreementName: agreement.name,
            connectState: .signContract,
            primaryReasonCode: issue.reasonCode,
            requiredAction: issue.requiredAction,
            issueCount: 1
        )
        let payload = AdmissionChallengePayload(
            state: .unmet,
            connectState: .signContract,
            agreement: agreement,
            context: ConnectContext(source: nil, target: nil, identity: owner),
            issues: [issue],
            issueCount: 1,
            sessionId: session.id,
            session: session,
            reasonCode: issue.reasonCode,
            userMessage: issue.userMessage,
            requiredAction: issue.requiredAction,
            canAutoResolve: issue.canAutoResolve,
            helperCellConfiguration: helperConfiguration,
            developerHint: issue.developerHint
        )

        let encodedObject = try #require(BindingAdmissionChallengeSupport.encodeObject(payload))
        let decoded = try #require(BindingAdmissionChallengeSupport.decodePayload(from: encodedObject))

        #expect(decoded.state == .unmet)
        #expect(decoded.connectState == .signContract)
        #expect(decoded.sessionId == session.id)
        #expect(decoded.primaryIssue?.reasonCode == issue.reasonCode)
        #expect(decoded.helperCellConfiguration?.name == "Helper Surface")
    }

    @Test func conferenceIdentityLinkInboxExposesTypedAdmissionSessionAndRetryRequest() async throws {
        let owner = Identity()
        let agreement = Agreement(owner: owner)
        agreement.name = "Binding Identity Link"

        let helperConfiguration = CellConfiguration(name: "Identity Link Helper")
        let issue = AdmissionChallengeIssueRecord(
            conditionName: "sameEntityLink",
            conditionType: "binding.same-entity",
            state: .unmet,
            reasonCode: "same_entity_link_review_required",
            userMessage: "Review same-entity link request before continuing.",
            requiredAction: "open_helper_configuration",
            canAutoResolve: true,
            helperCellConfiguration: helperConfiguration,
            developerHint: "Prompt should surface session retry data."
        )
        let session = AdmissionSession(
            label: "Identity link admission",
            requesterUUID: "requester-abc",
            targetCellUUID: "target-def",
            agreementUUID: agreement.uuid,
            agreementName: agreement.name,
            connectState: .signContract,
            primaryReasonCode: issue.reasonCode,
            requiredAction: issue.requiredAction,
            issueCount: 1
        )
        let payload = AdmissionChallengePayload(
            state: .unmet,
            connectState: .signContract,
            agreement: agreement,
            context: ConnectContext(source: nil, target: nil, identity: owner),
            issues: [issue],
            issueCount: 1,
            sessionId: session.id,
            session: session,
            reasonCode: issue.reasonCode,
            userMessage: issue.userMessage,
            requiredAction: issue.requiredAction,
            canAutoResolve: issue.canAutoResolve,
            helperCellConfiguration: helperConfiguration,
            developerHint: issue.developerHint
        )
        var payloadObject = try #require(BindingAdmissionChallengeSupport.encodeObject(payload))
        payloadObject["requestId"] = .string("REQ-ADMISSION-1")
        payloadObject["requestedDomains"] = .list([.string("private"), .string("scaffold")])
        payloadObject["requestedIdentityContexts"] = .list([.string("private"), .string("scaffold")])
        payloadObject["requestedScopes"] = .list([.string("entity-auth"), .string("personal-cells")])

        let rawPayloadData = try #require(try? JSONEncoder().encode(payloadObject))
        let rawPayload = try #require(String(data: rawPayloadData, encoding: .utf8))

        let store = ConferenceIdentityLinkInboxStore.shared
        await store.clear()
        await store.setDraftInput(rawPayload)

        #expect(await store.importDraft())

        let state = await store.stateObject()
        guard case let .object(admission)? = state["admission"] else {
            Issue.record("Expected typed admission state object in identity-link inbox")
            await store.clear()
            return
        }

        #expect(admission["sessionSummary"] == .string("Session: \(session.id)"))
        #expect(admission["requiredAction"] == .string("open_helper_configuration"))
        #expect(admission["retrySummary"] == .string("Admission retry-request er klar fra delt session-id."))
        #expect(await store.helperConfiguration()?.name == "Identity Link Helper")

        guard case let .object(retryRequest)? = admission["retryRequest"] else {
            Issue.record("Expected retryRequest object in typed admission state")
            await store.clear()
            return
        }
        #expect(retryRequest["sessionId"] == .string(session.id))
        #expect(retryRequest["requesterUUID"] == .string("requester-abc"))

        await store.clear()
    }

    @Test func portableSurfaceCacheStoreReloadsFromDiskAndScopesDataToSigningIdentity() async {
        let endpoint = "cell://staging.haven.digipomps.org/ConferencePublicShell"
        let configuration = CellConfiguration(name: "Conference Public Surface")
        let snapshot: ValueType = .object([
            "setup": .object([
                "statusLabel": .string("Ready")
            ]),
            "draft": .object([
                "cachePolicy": .string("useCache")
            ])
        ])
        let owner = await makeOwnerIdentity()
        let otherIdentity = await Self.testIdentityVault.identity(
            for: "portable-cache-other-\(UUID().uuidString)",
            makeNewIfNotFound: true
        )!
        let cacheFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("binding-portable-cache-\(UUID().uuidString).json")
        let writingStore = PortableSurfaceCacheStore(fileURL: cacheFileURL)

        await writingStore.clearAll()
        await writingStore.storeConfiguration(configuration, endpoint: endpoint, requester: owner)
        await writingStore.storeSnapshot(snapshot, endpoint: endpoint, keypath: "state", requester: owner)

        let reloadedStore = PortableSurfaceCacheStore(fileURL: cacheFileURL)
        let restoredConfiguration = await reloadedStore.configuration(for: endpoint, requester: owner)
        let restoredSnapshot = await reloadedStore.snapshot(for: endpoint, keypath: "state", requester: owner)
        let metadata = await reloadedStore.metadata(for: endpoint, requester: owner)

        #expect(restoredConfiguration?.name == "Conference Public Surface")
        #expect(metadata?.hasConfiguration == true)
        #expect(metadata?.cachedKeypaths == ["state"])
        #expect(await reloadedStore.configuration(for: endpoint, requester: otherIdentity) == nil)
        #expect(await reloadedStore.snapshot(for: endpoint, keypath: "state", requester: otherIdentity) == nil)
        guard case let .object(restoredObject)? = restoredSnapshot else {
            Issue.record("Expected cached snapshot object to roundtrip through the portable surface cache")
            await reloadedStore.clearAll()
            return
        }
        guard case let .object(restoredSetup)? = restoredObject["setup"] else {
            Issue.record("Expected cached snapshot setup object to survive persistence")
            await reloadedStore.clearAll()
            return
        }
        guard case let .object(restoredDraft)? = restoredObject["draft"] else {
            Issue.record("Expected cached snapshot draft object to survive persistence")
            await reloadedStore.clearAll()
            return
        }
        #expect(restoredSetup["statusLabel"] == .string("Ready"))
        #expect(restoredDraft["cachePolicy"] == .string("useCache"))

        await reloadedStore.clearAll()
        try? FileManager.default.removeItem(at: cacheFileURL)
    }

    @Test func productionPortableSurfaceCacheIsMemoryOnlyAndPurgesLegacyDiskState() async throws {
        let owner = await makeOwnerIdentity()
        let endpoint = "cell://staging.haven.digipomps.org/private-surface"
        let legacyFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("binding-portable-legacy-\(UUID().uuidString).json")
        try Data("{\"legacy\":true}".utf8).write(to: legacyFileURL)

        let memoryStore = PortableSurfaceCacheStore(legacyFileURL: legacyFileURL)
        #expect(await memoryStore.configuration(for: endpoint, requester: owner) == nil)
        #expect(!FileManager.default.fileExists(atPath: legacyFileURL.path))

        await memoryStore.storeConfiguration(
            CellConfiguration(name: "Session-only surface"),
            endpoint: endpoint,
            requester: owner
        )
        #expect(await memoryStore.configuration(for: endpoint, requester: owner)?.name == "Session-only surface")

        let restartedStore = PortableSurfaceCacheStore(legacyFileURL: legacyFileURL)
        #expect(await restartedStore.configuration(for: endpoint, requester: owner) == nil)
        #expect(!FileManager.default.fileExists(atPath: legacyFileURL.path))
    }

    @Test func unreceiptedCacheIsRejectedForAdmissionProtectedRemoteEndpoints() {
        #expect(RemoteEndpointAccessSupport.mayUseUnreceiptedCache(for: "cell:///LocalSurface"))
        #expect(RemoteEndpointAccessSupport.mayUseUnreceiptedCache(
            for: "cell://staging.haven.digipomps.org/SkeletonParityPublicFixture"
        ))
        #expect(!RemoteEndpointAccessSupport.mayUseUnreceiptedCache(
            for: "cell://staging.haven.digipomps.org/PrivateSurface"
        ))
        #expect(!RemoteEndpointAccessSupport.mayUseUnreceiptedCache(
            for: "cell://runtime.example/PrivateSurface"
        ))
    }

    @Test func getOnlyReadRenegotiatesExactlyOnceAfterTypedAuthorizationDenial() async throws {
        let owner = await makeOwnerIdentity()
        let probe = await RemoteReadRetryProbeCell(owner: owner)
        probe.doneInitializing()

        await RemoteReadRetryProbeScript.shared.configure(.succeedsOnSecondAttempt)
        var resolveAttempts = 0
        let value = try await RemoteEndpointAccessSupport.readValue(
            endpoint: "cell:///RemoteReadRetryProbe",
            keypath: "state",
            requester: owner,
            authorizationKind: .none
        ) {
            resolveAttempts += 1
            return probe
        }
        #expect(value == .string("authorized-after-retry"))
        #expect(resolveAttempts == 2)
        #expect(await RemoteReadRetryProbeScript.shared.attemptCount() == 2)

        await RemoteReadRetryProbeScript.shared.configure(.alwaysDenied)
        resolveAttempts = 0
        do {
            _ = try await RemoteEndpointAccessSupport.readValue(
                endpoint: "cell:///RemoteReadRetryProbe",
                keypath: "state",
                requester: owner,
                authorizationKind: .none
            ) {
                resolveAttempts += 1
                return probe
            }
            Issue.record("Expected the second typed denial to be returned to the caller")
        } catch {
            #expect(RemoteEndpointAccessSupport.isAuthorizationDenied(error))
        }
        #expect(resolveAttempts == 2)
        #expect(await RemoteReadRetryProbeScript.shared.attemptCount() == 2)
    }

    @Test func authorizationCacheKeyBindsEndpointEmitterAndSigningIdentity() async {
        let owner = await makeOwnerIdentity()
        let firstEmitter = await GeneralCell(owner: owner)
        let secondEmitter = await GeneralCell(owner: owner)
        firstEmitter.doneInitializing()
        secondEmitter.doneInitializing()

        let first = RemoteEndpointAccessAuthorizer.authorizationCacheKey(
            endpoint: "cell://runtime.example/Surface",
            emit: firstEmitter,
            requester: owner
        )
        let same = RemoteEndpointAccessAuthorizer.authorizationCacheKey(
            endpoint: "CELL://RUNTIME.EXAMPLE/SURFACE",
            emit: firstEmitter,
            requester: owner
        )
        let replacementEmitter = RemoteEndpointAccessAuthorizer.authorizationCacheKey(
            endpoint: "cell://runtime.example/Surface",
            emit: secondEmitter,
            requester: owner
        )
        let unsignedRequester = Identity(
            "unsigned-requester",
            displayName: "Unsigned requester",
            identityVault: nil
        )

        #expect(first != nil)
        #expect(first == same)
        #expect(first != replacementEmitter)
        #expect(RemoteEndpointAccessAuthorizer.authorizationCacheKey(
            endpoint: "cell://runtime.example/Surface",
            emit: firstEmitter,
            requester: unsignedRequester
        ) == nil)
    }

    @Test func portableSurfaceCacheStorePrunesOldEntriesAndSnapshots() async {
        let owner = await makeOwnerIdentity()
        let cacheFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("binding-portable-prune-\(UUID().uuidString).json")
        let store = PortableSurfaceCacheStore(fileURL: cacheFileURL)
        await store.clearAll()

        let oldestEndpoint = "cell://staging.haven.digipomps.org/cache-entry-oldest"
        await store.storeConfiguration(
            CellConfiguration(name: "Oldest cached surface"),
            endpoint: oldestEndpoint,
            requester: owner
        )
        try? await Task.sleep(nanoseconds: 2_000_000)

        for index in 0..<PortableSurfaceCacheStore.maximumRetainedEntries {
            await store.storeConfiguration(
                CellConfiguration(name: "Cached surface \(index)"),
                endpoint: "cell://staging.haven.digipomps.org/cache-entry-\(index)",
                requester: owner
            )
        }

        #expect(await store.configuration(for: oldestEndpoint, requester: owner) == nil)
        #expect(
            await store.configuration(
                for: "cell://staging.haven.digipomps.org/cache-entry-\(PortableSurfaceCacheStore.maximumRetainedEntries - 1)",
                requester: owner
            )?.name == "Cached surface \(PortableSurfaceCacheStore.maximumRetainedEntries - 1)"
        )

        let snapshotEndpoint = "cell://staging.haven.digipomps.org/cache-snapshots"
        await store.storeSnapshot(
            .string("oldest"),
            endpoint: snapshotEndpoint,
            keypath: "state.0",
            requester: owner
        )
        try? await Task.sleep(nanoseconds: 2_000_000)
        for index in 1...PortableSurfaceCacheStore.maximumSnapshotsPerEntry {
            await store.storeSnapshot(
                .string("snapshot-\(index)"),
                endpoint: snapshotEndpoint,
                keypath: "state.\(index)",
                requester: owner
            )
        }

        let metadata = await store.metadata(for: snapshotEndpoint, requester: owner)
        #expect(metadata?.cachedKeypaths.count == PortableSurfaceCacheStore.maximumSnapshotsPerEntry)
        #expect(
            await store.snapshot(
                for: snapshotEndpoint,
                keypath: "state.0",
                requester: owner
            ) == nil
        )
        #expect(
            await store.snapshot(
                for: snapshotEndpoint,
                keypath: "state.\(PortableSurfaceCacheStore.maximumSnapshotsPerEntry)",
                requester: owner
            ) == .string("snapshot-\(PortableSurfaceCacheStore.maximumSnapshotsPerEntry)")
        )

        await store.clearAll()
        try? FileManager.default.removeItem(at: cacheFileURL)
    }

    @Test func conferenceAutomationHookParsesSupportedURLs() throws {
        let identityLinkURL = try #require(URL(string: "haven://identity-link?requestId=REQ-123"))
        var externallyAllowed: Set<ContentView.ConferenceAutomationHook> = [
            .openLauncher, .openParticipantPortal, .openConferenceMVP,
            .openPublicSurface, .openControlTower, .openSponsorFollowUp,
            .openAIAssistant, .openIdentityLink, .openAgentSetupWorkbench
        ]
#if canImport(AppKit)
        externallyAllowed.formUnion([.windowCompact, .windowTall, .windowWide, .centerWindow])
#endif
        for hook in ContentView.ConferenceAutomationHook.allCases {
            let url = try #require(URL(string: "haven://conference-automation?action=\(hook.rawValue)"))
            if externallyAllowed.contains(hook) {
                #expect(ContentView.conferenceAutomationHook(from: url) == hook)
            } else {
                #expect(ContentView.conferenceAutomationHook(from: url) == nil)
            }
        }
        #expect(ContentView.conferenceAutomationHook(from: identityLinkURL) == nil)
        #expect(ContentView.conferenceAutomationHook(
            from: URL(string: "haven://conference-automation?action=open-launcher&action=open-control-tower")!
        ) == nil)
        #expect(ContentView.conferenceAutomationHook(
            from: URL(string: "haven://conference-automation?action=open-launcher&token=unexpected")!
        ) == nil)
    }

    @Test func runtimeSurfaceLaunchParsesOpaqueViewOnlyRoute() throws {
        let url = try #require(URL(string: "haven://open?schema=haven.surface-launch.v1&surfaceID=Runtime-Only-Surface&intent=view"))
        guard case let .accepted(request) = BindingRuntimeSurfaceLaunchSupport.parse(url) else {
            Issue.record("Expected accepted runtime surface launch")
            return
        }
        #expect(request.surfaceID == "runtime-only-surface")
    }

    @Test func runtimeSurfaceLaunchRejectsDuplicateOrAuthorityBearingParameters() throws {
        let duplicate = try #require(URL(string: "haven://open?schema=haven.surface-launch.v1&surfaceID=one&surfaceID=two&intent=view"))
        let action = try #require(URL(string: "haven://open?schema=haven.surface-launch.v1&surfaceID=one&intent=view&action=delete"))
        let requester = try #require(URL(string: "haven://open?schema=haven.surface-launch.v1&surfaceID=one&intent=view&requester=admin"))
        let token = try #require(URL(string: "haven://open?schema=haven.surface-launch.v1&surfaceID=one&intent=view&token=secret"))
        let pathVariant = try #require(URL(string: "haven://open/delete?schema=haven.surface-launch.v1&surfaceID=one&intent=view"))
        let oversized = try #require(URL(string: "haven://open?schema=haven.surface-launch.v1&surfaceID=one&intent=view&padding=\(String(repeating: "x", count: 2_048))"))
        let identityLink = try #require(URL(string: "haven://identity-link?requestId=REQ-123"))

        guard case .rejected = BindingRuntimeSurfaceLaunchSupport.parse(duplicate) else {
            Issue.record("Expected duplicate parameter rejection")
            return
        }
        guard case .rejected = BindingRuntimeSurfaceLaunchSupport.parse(action) else {
            Issue.record("Expected action parameter rejection")
            return
        }
        guard case .rejected = BindingRuntimeSurfaceLaunchSupport.parse(requester) else {
            Issue.record("Expected requester parameter rejection")
            return
        }
        guard case .rejected = BindingRuntimeSurfaceLaunchSupport.parse(token) else {
            Issue.record("Expected token parameter rejection")
            return
        }
        #expect(BindingRuntimeSurfaceLaunchSupport.parse(pathVariant) == .notLaunchRoute)
        guard case .rejected("url_too_large") = BindingRuntimeSurfaceLaunchSupport.parse(oversized) else {
            Issue.record("Expected oversized runtime launch rejection")
            return
        }
        #expect(BindingRuntimeSurfaceLaunchSupport.parse(identityLink) == .notLaunchRoute)
    }

    @Test func runtimeSurfaceLaunchResolvesOwnerPublishedLookupAndRetargetsRemoteSource() throws {
        let routes: ValueType = .list([
            .object([
                "schema": .string(BindingRuntimeSurfaceLaunchSupport.registrySchema),
                "surfaceID": .string("runtime-only-surface"),
                "configurationLookup": .object([
                    "name": .string("Runtime Only Surface"),
                    "sourceCellEndpoint": .string("cell:///RuntimeOnlySurface")
                ]),
                "revision": .integer(7),
                "enabled": .bool(true),
                "published": .bool(true),
                "updatedAtEpochMs": .float(1)
            ])
        ])
        let registryEndpoint = "cell://staging.haven.digipomps.org/ScaffoldLaunchRegistry"
        let payload = BindingRuntimeSurfaceLaunchSupport.resolveLaunchPayload(
            surfaceID: "runtime-only-surface",
            routesValue: routes,
            registryEndpoint: registryEndpoint
        )
        let lookup = CellConfigurationPayloadSupport.decodeLookup(from: payload)

        #expect(lookup?.name == "Runtime Only Surface")
        #expect(lookup?.sourceCellEndpoint == "cell://staging.haven.digipomps.org/RuntimeOnlySurface")
        #expect(
            BindingRuntimeSurfaceLaunchSupport.registryEndpoint(
                forCatalogEndpoint: "cell://staging.haven.digipomps.org/ConfigurationCatalog"
            ) == registryEndpoint
        )
    }

    @Test func runtimeSurfaceLaunchRejectsEndpointOnlyOrDisabledRegistryEntry() {
        let endpointOnly: ValueType = .list([
            .object([
                "schema": .string(BindingRuntimeSurfaceLaunchSupport.registrySchema),
                "surfaceID": .string("endpoint-only"),
                "configurationLookup": .object([
                    "sourceCellEndpoint": .string("cell:///Unpublished")
                ]),
                "enabled": .bool(true),
                "published": .bool(true)
            ])
        ])
        let disabled: ValueType = .list([
            .object([
                "schema": .string(BindingRuntimeSurfaceLaunchSupport.registrySchema),
                "surfaceID": .string("disabled"),
                "configurationLookup": .object([
                    "name": .string("Disabled")
                ]),
                "enabled": .bool(false),
                "published": .bool(true)
            ])
        ])
        let unpublished: ValueType = .list([
            .object([
                "schema": .string(BindingRuntimeSurfaceLaunchSupport.registrySchema),
                "surfaceID": .string("unpublished"),
                "configurationLookup": .object([
                    "name": .string("Private surface")
                ]),
                "enabled": .bool(true),
                "published": .bool(false)
            ])
        ])

        #expect(BindingRuntimeSurfaceLaunchSupport.resolveLaunchPayload(
            surfaceID: "endpoint-only",
            routesValue: endpointOnly,
            registryEndpoint: "cell:///ScaffoldLaunchRegistry"
        ) == nil)
        #expect(BindingRuntimeSurfaceLaunchSupport.resolveLaunchPayload(
            surfaceID: "disabled",
            routesValue: disabled,
            registryEndpoint: "cell:///ScaffoldLaunchRegistry"
        ) == nil)
        #expect(BindingRuntimeSurfaceLaunchSupport.resolveLaunchPayload(
            surfaceID: "unpublished",
            routesValue: unpublished,
            registryEndpoint: "cell:///ScaffoldLaunchRegistry"
        ) == nil)
    }

    @Test func runtimeSurfaceSkeletonUsesLocalAdapterAndPreservesPayload() throws {
        let payload: ValueType = .object([
            "surfaceLaunch": .object([
                "schema": .string(BindingRuntimeSurfaceLaunchRequest.schema),
                "surfaceID": .string("conference.public.registration"),
                "intent": .string("view")
            ])
        ])
        let skeleton = SkeletonElement.Button(
            SkeletonButton(keypath: "addConfiguration", label: "Registrer deg", payload: payload)
        )
        let extraction = BindingSkeletonPresentationSupport.extract(from: skeleton, userInfoValue: nil)
        guard case let .Button(adapted)? = extraction.baseElement else {
            Issue.record("Expected adapted runtime surface button")
            return
        }
        #expect(adapted.keypath == BindingRuntimeSurfaceLaunchSupport.adapterKeypath)
        #expect(adapted.url == BindingRuntimeSurfaceLaunchSupport.adapterEndpoint)
        #expect(try adapted.payload?.jsonString() == payload.jsonString())

        let targetSceneID = UUID()
        let targetedExtraction = BindingSkeletonPresentationSupport.extract(
            from: skeleton,
            userInfoValue: nil,
            targetSceneID: targetSceneID
        )
        guard case let .Button(targeted)? = targetedExtraction.baseElement else {
            Issue.record("Expected scene-targeted runtime surface button")
            return
        }
        #expect(BindingRuntimeSurfaceLaunchSupport.targetSceneID(from: targeted.payload) == targetSceneID)
        #expect(
            BindingRuntimeSurfaceLaunchSupport.classifyPayload(targeted.payload)
                == .accepted(BindingRuntimeSurfaceLaunchRequest(surfaceID: "conference.public.registration"))
        )

        let directPayload: ValueType = .object([
            "configurationLookup": .object(["name": .string("Compiled fallback")])
        ])
        let directSkeleton = SkeletonElement.Button(
            SkeletonButton(keypath: "addConfiguration", label: "Direkte", payload: directPayload)
        )
        let directExtraction = BindingSkeletonPresentationSupport.extract(
            from: directSkeleton,
            userInfoValue: nil
        )
        guard case let .Button(direct)? = directExtraction.baseElement else {
            Issue.record("Expected direct configuration button")
            return
        }
        #expect(direct.keypath == "addConfiguration")
        #expect(direct.url == nil)

        let malformedPayload: ValueType = .object([
            "surfaceLaunch": .object([
                "schema": .string(BindingRuntimeSurfaceLaunchRequest.schema),
                "surfaceID": .string("conference.public.registration"),
                "intent": .string("view"),
                "token": .string("must-not-be-authority")
            ])
        ])
        let malformed = BindingRuntimeSurfaceLaunchSupport.adaptSkeletonButton(
            SkeletonButton(keypath: "addConfiguration", label: "Ugyldig", payload: malformedPayload)
        )
        #expect(malformed.keypath == BindingRuntimeSurfaceLaunchSupport.adapterKeypath)
        #expect(
            BindingRuntimeSurfaceLaunchSupport.classifyPayload(malformed.payload)
                == .rejected("invalid_surface_launch_payload")
        )
    }

    @Test func runtimeSurfaceAdaptedButtonExecutesThroughResolverWithExactRequester() async throws {
        let requester = await makeIsolatedRuntimeIdentity("runtime-surface-adapter")
        let resolver = CellResolver.sharedInstance
        CellBase.defaultCellResolver = resolver
        await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
        let payload: ValueType = .object([
            "surfaceLaunch": .object([
                "schema": .string(BindingRuntimeSurfaceLaunchRequest.schema),
                "surfaceID": .string("conference.public.registration"),
                "intent": .string("view")
            ])
        ])
        let recorder = RuntimeSurfaceLaunchEventRecorder()
        let token = NotificationCenter.default.addObserver(
            forName: BindingRuntimeSurfaceLaunchBridge.notificationName,
            object: nil,
            queue: nil
        ) { notification in
            recorder.record(BindingRuntimeSurfaceLaunchBridge.event(from: notification))
        }
        defer { NotificationCenter.default.removeObserver(token) }

        let skeleton = SkeletonElement.Button(
            SkeletonButton(keypath: "addConfiguration", label: "Registrer deg", payload: payload)
        )
        let targetSceneID = UUID()
        let adapted = await MainActor.run { () -> SkeletonButton? in
            let extraction = BindingSkeletonPresentationSupport.extract(
                from: skeleton,
                userInfoValue: nil,
                targetSceneID: targetSceneID
            )
            guard case let .Button(adapted)? = extraction.baseElement else {
                return nil
            }
            return adapted
        }
        let executableButton = try #require(adapted)

        let response = await executableButton.execute(requester: requester)

        #expect(response != nil)
        #expect(response?["status"] == .string("submitted"))
        let event = try #require(recorder.event())
        #expect(event.request?.surfaceID == "conference.public.registration")
        #expect(event.requester.uuid == requester.uuid)
        #expect(event.requester.publicSecureKey?.compressedKey == requester.publicSecureKey?.compressedKey)
        #expect(event.targetSceneID == targetSceneID)
    }

    @Test func presentedRuntimeSurfaceButtonUsesLocalAdapterAndPreservesTargetScene() {
        let targetSceneID = UUID()
        let payload: ValueType = .object([
            "surfaceLaunch": .object([
                "schema": .string(BindingRuntimeSurfaceLaunchRequest.schema),
                "surfaceID": .string("conference.public.registration"),
                "intent": .string("view")
            ])
        ])
        var modifiers = SkeletonModifiers()
        modifiers.presentation = SkeletonPresentation(kind: .modal, placement: .center)
        var button = SkeletonButton(keypath: "addConfiguration", label: "Registrer deg", payload: payload)
        button.modifiers = modifiers

        let extraction = BindingSkeletonPresentationSupport.extract(
            from: .Button(button),
            userInfoValue: nil,
            targetSceneID: targetSceneID
        )

        #expect(extraction.baseElement == nil)
        #expect(extraction.nodes.count == 1)
        guard case let .Button(adapted)? = extraction.nodes.first?.element else {
            Issue.record("Expected adapted runtime surface button in presentation node")
            return
        }
        #expect(adapted.keypath == BindingRuntimeSurfaceLaunchSupport.adapterKeypath)
        #expect(adapted.url == BindingRuntimeSurfaceLaunchSupport.adapterEndpoint)
        #expect(BindingRuntimeSurfaceLaunchSupport.targetSceneID(from: adapted.payload) == targetSceneID)

        let hostileRow: ValueType = .object([
            "keypath": .string("row.override"),
            "label": .string("Radetikett"),
            "url": .string("cell:///RowOverride"),
            "payload": .object([
                "surfaceLaunch": .object([
                    "schema": .string("attacker.schema"),
                    "surfaceID": .string("private.surface"),
                    "intent": .string("mutate")
                ])
            ])
        ])
        let resolved = SkeletonButtonResolutionSupport.resolve(
            template: adapted,
            userInfoValue: hostileRow,
            transform: BindingRuntimeSurfaceLaunchSupport.buttonResolutionTransform(
                targetSceneID: targetSceneID
            )
        )
        #expect(resolved.keypath == BindingRuntimeSurfaceLaunchSupport.adapterKeypath)
        #expect(resolved.url == BindingRuntimeSurfaceLaunchSupport.adapterEndpoint)
        // Presentation extraction deliberately suppresses deferred row-field
        // resolution after its own pass, so a later hostile row cannot rewrite
        // the already prepared button, including its visible label.
        #expect(resolved.label == "Registrer deg")
        #expect(BindingRuntimeSurfaceLaunchSupport.targetSceneID(from: resolved.payload) == targetSceneID)
        #expect(
            BindingRuntimeSurfaceLaunchSupport.classifyPayload(resolved.payload)
                == .accepted(BindingRuntimeSurfaceLaunchRequest(surfaceID: "conference.public.registration"))
        )
    }

    @Test func presentedContainerAdaptsNestedRuntimeSurfaceButtonForTargetScene() {
        let targetSceneID = UUID()
        let payload: ValueType = .object([
            "surfaceLaunch": .object([
                "schema": .string(BindingRuntimeSurfaceLaunchRequest.schema),
                "surfaceID": .string("conference.public.registration"),
                "intent": .string("view")
            ])
        ])
        let button = SkeletonElement.Button(
            SkeletonButton(keypath: "addConfiguration", label: "Registrer deg", payload: payload)
        )
        var modifiers = SkeletonModifiers()
        modifiers.presentation = SkeletonPresentation(kind: .sheet, placement: .bottom)
        var container = SkeletonVStack(elements: [button])
        container.modifiers = modifiers

        let extraction = BindingSkeletonPresentationSupport.extract(
            from: .VStack(container),
            userInfoValue: nil,
            targetSceneID: targetSceneID
        )

        #expect(extraction.baseElement == nil)
        #expect(extraction.nodes.count == 1)
        guard case let .VStack(preparedContainer)? = extraction.nodes.first?.element,
              case let .Button(adapted)? = preparedContainer.elements.first else {
            Issue.record("Expected adapted runtime surface button inside presentation container")
            return
        }
        #expect(adapted.keypath == BindingRuntimeSurfaceLaunchSupport.adapterKeypath)
        #expect(adapted.url == BindingRuntimeSurfaceLaunchSupport.adapterEndpoint)
        #expect(BindingRuntimeSurfaceLaunchSupport.targetSceneID(from: adapted.payload) == targetSceneID)
    }

    @Test func delegatedTopicListAdaptsRuntimeSurfaceButtonTemplateForTargetScene() {
        let targetSceneID = UUID()
        let payload: ValueType = .object([
            "surfaceLaunch": .object([
                "schema": .string(BindingRuntimeSurfaceLaunchRequest.schema),
                "surfaceID": .string("conference.public.registration"),
                "intent": .string("view")
            ])
        ])
        let row = SkeletonVStack(elements: [
            .Button(
                SkeletonButton(keypath: "addConfiguration", label: "Registrer deg", payload: payload)
            )
        ])
        let list = SkeletonList(
            topic: "conference.public.registrations",
            keypath: nil,
            flowElementSkeleton: row
        )

        let extraction = BindingSkeletonPresentationSupport.extract(
            from: .List(list),
            userInfoValue: nil,
            targetSceneID: targetSceneID
        )

        guard case let .List(preparedList)? = extraction.baseElement,
              let preparedRow = preparedList.flowElementSkeleton,
              case let .Button(adapted)? = preparedRow.elements.first else {
            Issue.record("Expected adapted runtime surface button in delegated list template")
            return
        }
        #expect(preparedList.topic == list.topic)
        #expect(adapted.keypath == BindingRuntimeSurfaceLaunchSupport.adapterKeypath)
        #expect(adapted.url == BindingRuntimeSurfaceLaunchSupport.adapterEndpoint)
        #expect(BindingRuntimeSurfaceLaunchSupport.targetSceneID(from: adapted.payload) == targetSceneID)
    }

    @Test func delegatedReferenceAdaptsRuntimeSurfaceButtonAndRejectsHostileRowOverrides() {
        let targetSceneID = UUID()
        let payload: ValueType = .object([
            "surfaceLaunch": .object([
                "schema": .string(BindingRuntimeSurfaceLaunchRequest.schema),
                "surfaceID": .string("conference.public.registration"),
                "intent": .string("view")
            ])
        ])
        let row = SkeletonVStack(elements: [
            .Button(
                SkeletonButton(keypath: "addConfiguration", label: "Registrer deg", payload: payload)
            )
        ])
        var reference = SkeletonCellReference(
            keypath: "cell:///Conference/PublicRegistrations",
            topic: "conference.public.registrations"
        )
        reference.flowElementSkeleton = row

        let extraction = BindingSkeletonPresentationSupport.extract(
            from: .Reference(reference),
            userInfoValue: nil,
            targetSceneID: targetSceneID
        )

        guard case let .Reference(preparedReference)? = extraction.baseElement,
              let preparedRow = preparedReference.flowElementSkeleton,
              case let .Button(adapted)? = preparedRow.elements.first else {
            Issue.record("Expected adapted runtime surface button in delegated reference template")
            return
        }
        let hostileRow: ValueType = .object([
            "keypath": .string("row.override"),
            "url": .string("cell:///RowOverride"),
            "payload": .string("row override")
        ])
        let resolved = SkeletonButtonResolutionSupport.resolve(
            template: adapted,
            userInfoValue: hostileRow,
            transform: BindingRuntimeSurfaceLaunchSupport.buttonResolutionTransform(
                targetSceneID: targetSceneID
            )
        )

        #expect(preparedReference.keypath == reference.keypath)
        #expect(resolved.keypath == BindingRuntimeSurfaceLaunchSupport.adapterKeypath)
        #expect(resolved.url == BindingRuntimeSurfaceLaunchSupport.adapterEndpoint)
        #expect(BindingRuntimeSurfaceLaunchSupport.targetSceneID(from: resolved.payload) == targetSceneID)
        #expect(
            BindingRuntimeSurfaceLaunchSupport.classifyPayload(resolved.payload)
                == .accepted(BindingRuntimeSurfaceLaunchRequest(surfaceID: "conference.public.registration"))
        )
    }

    @Test func delegatedTopicListAdaptsRuntimeSurfacePayloadResolvedFromRow() {
        let targetSceneID = UUID()
        let template = SkeletonButton(
            keypath: "addConfiguration",
            label: "Fallback",
            payloadKeypath: "payload"
        )
        let list = SkeletonList(
            topic: "runtime.dynamic.routes",
            keypath: nil,
            flowElementSkeleton: SkeletonVStack(elements: [.Button(template)])
        )
        let extraction = BindingSkeletonPresentationSupport.extract(
            from: .List(list),
            userInfoValue: nil,
            targetSceneID: targetSceneID
        )
        guard case let .List(preparedList)? = extraction.baseElement,
              let preparedRow = preparedList.flowElementSkeleton,
              case let .Button(preparedTemplate)? = preparedRow.elements.first else {
            Issue.record("Expected delegated runtime button template")
            return
        }

        let dynamicPayload: ValueType = .object([
            "surfaceLaunch": .object([
                "schema": .string(BindingRuntimeSurfaceLaunchRequest.schema),
                "surfaceID": .string("runtime.dynamic"),
                "intent": .string("view")
            ])
        ])
        let resolved = SkeletonButtonResolutionSupport.resolve(
            template: preparedTemplate,
            userInfoValue: .object(["payload": dynamicPayload]),
            transform: BindingRuntimeSurfaceLaunchSupport.buttonResolutionTransform(
                targetSceneID: targetSceneID
            )
        )

        #expect(resolved.keypath == BindingRuntimeSurfaceLaunchSupport.adapterKeypath)
        #expect(resolved.url == BindingRuntimeSurfaceLaunchSupport.adapterEndpoint)
        #expect(BindingRuntimeSurfaceLaunchSupport.targetSceneID(from: resolved.payload) == targetSceneID)
        #expect(
            BindingRuntimeSurfaceLaunchSupport.classifyPayload(resolved.payload)
                == .accepted(BindingRuntimeSurfaceLaunchRequest(surfaceID: "runtime.dynamic"))
        )
    }

    @Test func dynamicRuntimeRowCannotReplaceHostRouteOrSceneTarget() {
        let hostSceneID = UUID()
        let attackerSceneID = UUID()
        let dynamicPayload: ValueType = .object([
            "surfaceLaunch": .object([
                "schema": .string(BindingRuntimeSurfaceLaunchRequest.schema),
                "surfaceID": .string("runtime.dynamic"),
                "intent": .string("view")
            ])
        ])
        let dynamicTemplate = SkeletonButton(
            keypath: "addConfiguration",
            label: "Fallback",
            payloadKeypath: "payload"
        )
        let resolved = SkeletonButtonResolutionSupport.resolve(
            template: dynamicTemplate,
            userInfoValue: .object([
                "keypath": .string("attacker.write"),
                "url": .string("cell:///AttackerCell"),
                "payload": dynamicPayload
            ]),
            transform: BindingRuntimeSurfaceLaunchSupport.buttonResolutionTransform(
                targetSceneID: hostSceneID
            )
        )
        #expect(resolved.keypath == BindingRuntimeSurfaceLaunchSupport.adapterKeypath)
        #expect(resolved.url == BindingRuntimeSurfaceLaunchSupport.adapterEndpoint)
        #expect(BindingRuntimeSurfaceLaunchSupport.targetSceneID(from: resolved.payload) == hostSceneID)

        var attackerPayloadRoot: Object = [
            "surfaceLaunch": .object([
                "schema": .string(BindingRuntimeSurfaceLaunchRequest.schema),
                "surfaceID": .string("runtime.dynamic"),
                "intent": .string("view")
            ])
        ]
        attackerPayloadRoot["bindingTargetSceneID"] = .string(attackerSceneID.uuidString)
        let preAdaptedTemplate = SkeletonButton(
            keypath: BindingRuntimeSurfaceLaunchSupport.adapterKeypath,
            label: "Open",
            url: BindingRuntimeSurfaceLaunchSupport.adapterEndpoint,
            payload: .object(attackerPayloadRoot)
        )
        let rebound = SkeletonButtonResolutionSupport.resolve(
            template: preAdaptedTemplate,
            userInfoValue: .object([
                "keypath": .string("attacker.write"),
                "url": .string("cell:///AttackerCell"),
                "payload": .object([
                    "surfaceLaunch": .object([
                        "schema": .string(BindingRuntimeSurfaceLaunchRequest.schema),
                        "surfaceID": .string("attacker.other-surface"),
                        "intent": .string("view")
                    ])
                ])
            ]),
            transform: BindingRuntimeSurfaceLaunchSupport.buttonResolutionTransform(
                targetSceneID: hostSceneID
            )
        )
        #expect(rebound.keypath == BindingRuntimeSurfaceLaunchSupport.adapterKeypath)
        #expect(rebound.url == BindingRuntimeSurfaceLaunchSupport.adapterEndpoint)
        #expect(BindingRuntimeSurfaceLaunchSupport.targetSceneID(from: rebound.payload) == hostSceneID)
        #expect(
            BindingRuntimeSurfaceLaunchSupport.classifyPayload(rebound.payload)
                == .accepted(BindingRuntimeSurfaceLaunchRequest(surfaceID: "runtime.dynamic"))
        )
    }

    @Test func delegatedReferenceRoutesMalformedDynamicSurfacePayloadToFailClosedAdapter() {
        let targetSceneID = UUID()
        let template = SkeletonButton(
            keypath: "addConfiguration",
            label: "Fallback",
            payloadKeypath: "payload"
        )
        var reference = SkeletonCellReference(
            keypath: "cell:///DynamicRoutes",
            topic: "runtime.dynamic.routes"
        )
        reference.flowElementSkeleton = SkeletonVStack(elements: [.Button(template)])
        let extraction = BindingSkeletonPresentationSupport.extract(
            from: .Reference(reference),
            userInfoValue: nil,
            targetSceneID: targetSceneID
        )
        guard case let .Reference(preparedReference)? = extraction.baseElement,
              let preparedRow = preparedReference.flowElementSkeleton,
              case let .Button(preparedTemplate)? = preparedRow.elements.first else {
            Issue.record("Expected delegated reference button template")
            return
        }

        let malformedPayload: ValueType = .object([
            "surfaceLaunch": .object([
                "schema": .string(BindingRuntimeSurfaceLaunchRequest.schema),
                "surfaceID": .string("runtime.dynamic"),
                "intent": .string("mutate")
            ])
        ])
        let resolved = SkeletonButtonResolutionSupport.resolve(
            template: preparedTemplate,
            userInfoValue: .object(["payload": malformedPayload]),
            transform: BindingRuntimeSurfaceLaunchSupport.buttonResolutionTransform(
                targetSceneID: targetSceneID
            )
        )

        #expect(resolved.keypath == BindingRuntimeSurfaceLaunchSupport.adapterKeypath)
        #expect(resolved.url == BindingRuntimeSurfaceLaunchSupport.adapterEndpoint)
        #expect(
            BindingRuntimeSurfaceLaunchSupport.classifyPayload(resolved.payload)
                == .rejected("invalid_surface_launch_payload")
        )
    }

    @Test func runtimeSurfaceLaunchTargetsOnlyOriginatingSceneOrWindow() {
        let originatingSceneID = UUID()
        let otherSceneID = UUID()
        let matchingScenes = [originatingSceneID, otherSceneID].filter { hostingSceneID in
            ContentView.matchesRuntimeSurfaceLaunchTarget(
                targetWindowNumber: nil,
                targetSceneID: originatingSceneID,
                hostingWindowNumber: nil,
                hostingSceneID: hostingSceneID
            )
        }
        #expect(matchingScenes == [originatingSceneID])
        #expect(!ContentView.matchesRuntimeSurfaceLaunchTarget(
            targetWindowNumber: nil,
            targetSceneID: originatingSceneID,
            hostingWindowNumber: nil,
            hostingSceneID: nil
        ))
#if canImport(AppKit)
        #expect(ContentView.matchesRuntimeSurfaceLaunchTarget(
            targetWindowNumber: 314,
            targetSceneID: nil,
            hostingWindowNumber: 314,
            hostingSceneID: originatingSceneID
        ))
        #expect(!ContentView.matchesRuntimeSurfaceLaunchTarget(
            targetWindowNumber: 314,
            targetSceneID: nil,
            hostingWindowNumber: 271,
            hostingSceneID: originatingSceneID
        ))
        #expect(!ContentView.matchesRuntimeSurfaceLaunchTarget(
            targetWindowNumber: nil,
            targetSceneID: nil,
            hostingWindowNumber: 314,
            hostingSceneID: originatingSceneID
        ))
#endif
    }

    @Test func runtimeSurfaceCatalogOrderingPreventsLocalRegistryShadowing() {
        #expect(
            BindingRuntimeSurfaceLaunchSupport.orderedCatalogEndpoints([
                "cell:///ConfigurationCatalog",
                "cell://staging.haven.digipomps.org/ConfigurationCatalog"
            ]) == [
                "cell://staging.haven.digipomps.org/ConfigurationCatalog",
                "cell:///ConfigurationCatalog"
            ]
        )
        #expect(
            BindingRuntimeSurfaceLaunchSupport.orderedCatalogEndpoints([
                "cell://owner.example/ConfigurationCatalog"
            ]) == ["cell://owner.example/ConfigurationCatalog"]
        )
        #expect(BindingRuntimeSurfaceLaunchSupport.orderedCatalogEndpoints([]).isEmpty)
    }

    @Test func conferenceAutomationRequiresExplicitOptIn() {
        #expect(
            ContentView.conferenceAutomationEnabled(
                debugPanelVisible: false,
                environment: [:],
                launchArguments: [],
                persistedOptIn: false
            ) == false
        )

        #expect(
            ContentView.conferenceAutomationEnabled(
                debugPanelVisible: true,
                environment: [:],
                launchArguments: [],
                persistedOptIn: false
            ) == true
        )

        #expect(
            ContentView.conferenceAutomationEnabled(
                debugPanelVisible: false,
                environment: ["BINDING_ENABLE_CONFERENCE_AUTOMATION": "1"],
                launchArguments: [],
                persistedOptIn: false
            ) == true
        )

        #expect(
            ContentView.conferenceAutomationEnabled(
                debugPanelVisible: false,
                environment: [:],
                launchArguments: [],
                persistedOptIn: true
            ) == true
        )

        #expect(
            ContentView.conferenceAutomationEnabled(
                debugPanelVisible: false,
                environment: [:],
                launchArguments: ["Binding", "--enable-conference-automation"],
                persistedOptIn: false
            ) == true
        )
    }

    @Test func conferenceAutomationUsesStartupRuntimeBootstrap() {
        #expect(
            BindingRuntimeBootstrap.shouldUseLocalRuntimeOnlyForVerifier(
                environment: [:],
                launchArguments: ["Binding", "--enable-conference-automation"]
            )
        )

        #expect(
            BindingRuntimeBootstrap.shouldUseLocalRuntimeOnlyForVerifier(
                environment: ["BINDING_ENABLE_CONFERENCE_AUTOMATION": "true"],
                launchArguments: ["Binding"]
            )
        )

        #expect(
            !BindingRuntimeBootstrap.shouldUseLocalRuntimeOnlyForVerifier(
                environment: [:],
                launchArguments: ["Binding"]
            )
        )
    }

    @Test func conferenceAutomationMatchesOnlyItsTargetWindow() {
        #expect(ContentView.matchesConferenceAutomationWindow(targetWindowNumber: 42, hostingWindowNumber: 42))
        #expect(!ContentView.matchesConferenceAutomationWindow(targetWindowNumber: 42, hostingWindowNumber: 7))
        #expect(!ContentView.matchesConferenceAutomationWindow(targetWindowNumber: 42, hostingWindowNumber: nil))
    }

    @Test func conferenceAutomationGlobalOptInUsesOnlyExplicitGlobalInputs() {
        #expect(
            ContentView.conferenceAutomationGlobalOptInEnabled(
                environment: [:],
                launchArguments: [],
                persistedOptIn: false
            ) == false
        )

        #expect(
            ContentView.conferenceAutomationGlobalOptInEnabled(
                environment: ["BINDING_ENABLE_CONFERENCE_AUTOMATION": "1"],
                launchArguments: [],
                persistedOptIn: false
            ) == true
        )

        #expect(
            ContentView.conferenceAutomationGlobalOptInEnabled(
                environment: [:],
                launchArguments: ["Binding", "--enable-conference-automation"],
                persistedOptIn: false
            ) == true
        )

        #expect(
            ContentView.conferenceAutomationGlobalOptInEnabled(
                environment: [:],
                launchArguments: [],
                persistedOptIn: true
            ) == true
        )
    }

    @Test @MainActor func incomingURLBridgeCarriesTargetWindowNumber() throws {
        BindingIncomingURLBridge.resetForTesting()
        defer { BindingIncomingURLBridge.resetForTesting() }
        let center = NotificationCenter()
        let url = try #require(URL(string: "haven://conference-automation?action=open-launcher"))
        var receivedURL: URL?
        var receivedTargetWindowNumber: Int?

        let observer = center.addObserver(
            forName: BindingIncomingURLBridge.notificationName,
            object: nil,
            queue: nil
        ) { notification in
            receivedURL = BindingIncomingURLBridge.url(from: notification)
            receivedTargetWindowNumber = BindingIncomingURLBridge.targetWindowNumber(from: notification)
        }

        #expect(BindingIncomingURLBridge.post(url: url, targetWindowNumber: 314, notificationCenter: center))
        center.removeObserver(observer)

        #expect(receivedURL == url)
        #expect(receivedTargetWindowNumber == 314)
    }

    @Test func conferenceAutomationBridgeCarriesHookAndTargetWindow() {
        let center = NotificationCenter()
        var receivedHook: ContentView.ConferenceAutomationHook?
        var receivedTargetWindowNumber: Int?

        let observer = center.addObserver(
            forName: BindingConferenceAutomationBridge.notificationName,
            object: nil,
            queue: nil
        ) { notification in
            receivedHook = BindingConferenceAutomationBridge.hook(from: notification)
            receivedTargetWindowNumber = BindingConferenceAutomationBridge.targetWindowNumber(from: notification)
        }

        BindingConferenceAutomationBridge.post(
            hook: .openParticipantPortal,
            targetWindowNumber: 271,
            notificationCenter: center
        )
        center.removeObserver(observer)

        #expect(receivedHook == .openParticipantPortal)
        #expect(receivedTargetWindowNumber == 271)
    }

    @Test func conferenceAdminPublicAndSponsorWorkbenchesSeedStateAndUseScrollSurfaces() {
        let configurations = [
            ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
                endpoint: "cell://staging.haven.digipomps.org/ConferenceAdminShell"
            ),
            ConfigurationCatalogCell.conferencePublicWorkbenchConfiguration(
                endpoint: "cell://staging.haven.digipomps.org/ConferencePublicShell"
            ),
            ConfigurationCatalogCell.conferenceSponsorWorkbenchConfiguration(
                endpoint: "cell://staging.haven.digipomps.org/ConferenceSponsorShell"
            )
        ]

        for configuration in configurations {
            #expect(configuration.cellReferences?.count == 1)
            #expect(configuration.cellReferences?.first?.setKeysAndValues.contains(where: { $0.key == "state" }) == true)

            guard case .ScrollView? = configuration.skeleton else {
                Issue.record("\(configuration.name) should use a designed scroll surface")
                continue
            }
        }
    }

    @Test func conferenceWorkbenchConfigurationsValidateWithoutBrokenBindings() {
        let configurations = [
            ConfigurationCatalogCell.conferenceDemoLauncherWorkbenchConfiguration(),
            ConfigurationCatalogCell.conferenceIdentityLinkWorkbenchConfiguration(),
            ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
                endpoint: "cell:///ConferenceParticipantPreviewShell"
            ),
            ConfigurationCatalogCell.conferenceParticipantChatWorkbenchConfiguration(
                participantEndpoint: "cell:///ConferenceParticipantPreviewShell"
            ),
            ConfigurationCatalogCell.conferenceNearbyRadarWorkbenchConfiguration(
                participantEndpoint: "cell:///ConferenceParticipantPreviewShell"
            ),
            ConfigurationCatalogCell.conferenceNearbyParticipantWorkbenchConfiguration(
                participantEndpoint: "cell:///ConferenceParticipantPreviewShell"
            ),
            ConfigurationCatalogCell.conferenceAIAssistantWorkbenchConfiguration(
                conferenceEndpoint: "cell:///ConferenceParticipantPreviewShell",
                aiEndpoint: "cell:///ConferenceAIGatewayPreview"
            ),
            ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
                endpoint: "cell:///ConferenceAdminPreviewShell"
            ),
            ConfigurationCatalogCell.conferencePublicWorkbenchConfiguration(
                endpoint: "cell:///ConferencePublicShellFixture"
            ),
            ConfigurationCatalogCell.conferenceSponsorWorkbenchConfiguration(
                endpoint: "cell:///ConferenceSponsorShellFixture"
            )
        ]

        for configuration in configurations {
            let repaired = BindingConferenceConfigurationRepair.updatedConfigurationIfNeeded(configuration) ?? configuration
            let report = CellConfigurationValidationService.validate(repaired)
            #expect(report.errorCount == 0, "\(repaired.name): \(report.issues)")
        }
    }

    @Test func conferenceRequesterDescriptorsMatchConferenceShellOwnershipModel() {
        let contentView = ContentView()

        #expect(
            contentView.preferredRequesterDescriptor(
                for: "cell://staging.haven.digipomps.org/ConferenceParticipantPreviewShell"
            ) == .init(
                identityContext: "conference-participant-preview:preview-demo@staging.haven.digipomps.org",
                displayName: "Conference Participant Preview"
            )
        )
        #expect(
            contentView.preferredRequesterDescriptor(
                for: "cell://staging.haven.digipomps.org/ConferenceAIGatewayPreview"
            ) == .init(
                identityContext: "conference-participant-preview:preview-demo@staging.haven.digipomps.org",
                displayName: "Conference Participant Preview"
            )
        )
        #expect(
            contentView.preferredRequesterDescriptor(
                for: "cell://staging.haven.digipomps.org/ConferencePublicProfilePreview"
            ) == .init(
                identityContext: "conference-participant-preview:preview-demo@staging.haven.digipomps.org",
                displayName: "Conference Participant Preview"
            )
        )
        #expect(
            contentView.preferredRequesterDescriptor(
                for: "cell://staging.haven.digipomps.org/ConferencePublicProfileEditorPreview"
            ) == .init(
                identityContext: "conference-participant-preview:preview-demo@staging.haven.digipomps.org",
                displayName: "Conference Participant Preview"
            )
        )
        #expect(
            contentView.preferredRequesterDescriptor(
                for: "cell://staging.haven.digipomps.org/ConferenceAdminPreviewShell"
            ) == .init(
                identityContext: "conference-admin-preview:preview-control-tower-v2@staging.haven.digipomps.org",
                displayName: "Conference Admin Preview"
            )
        )
        #expect(
            contentView.preferredRequesterDescriptor(
                for: "cell://staging.haven.digipomps.org/ConferenceAdminShell"
            ) == .init(
                identityContext: "conference-organizer@staging.haven.digipomps.org",
                displayName: "Conference Organizer"
            )
        )
        #expect(
            contentView.preferredRequesterDescriptor(
                for: "cell://staging.haven.digipomps.org/ConferenceUIRouter"
            ) == .init(
                identityContext: "conference-organizer@staging.haven.digipomps.org",
                displayName: "Conference Organizer"
            )
        )
        #expect(
            contentView.preferredRequesterDescriptor(
                for: "cell://staging.haven.digipomps.org/ConferencePublicShell"
            ) == .init(
                identityContext: "conference-public-publisher@staging.haven.digipomps.org",
                displayName: "Conference Public Publisher"
            )
        )
        #expect(
            contentView.preferredRequesterDescriptor(
                for: "cell://staging.haven.digipomps.org/ConferenceSponsorShell"
            ) == .init(
                identityContext: "conference-sponsor:sponsor-ai-digital-independence@staging.haven.digipomps.org",
                displayName: "sponsor-ai-digital-independence"
            )
        )
    }

    @Test func conferenceRequesterDescriptorsAreScopedPerRemoteHost() {
        let contentView = ContentView()

        let stagingDescriptor = contentView.preferredRequesterDescriptor(
            for: "cell://staging.haven.digipomps.org/ConferenceParticipantPreviewShell"
        )
        let demoDescriptor = contentView.preferredRequesterDescriptor(
            for: "cell://demo.haven.digipomps.org/ConferenceParticipantPreviewShell"
        )

        #expect(stagingDescriptor?.displayName == "Conference Participant Preview")
        #expect(demoDescriptor?.displayName == "Conference Participant Preview")
        #expect(stagingDescriptor?.identityContext == "conference-participant-preview:preview-demo@staging.haven.digipomps.org")
        #expect(demoDescriptor?.identityContext == "conference-participant-preview:preview-demo@demo.haven.digipomps.org")
        #expect(stagingDescriptor != demoDescriptor)
    }

    @Test func bindingLocalCellRegistrationMakesConferencePreviewFallbacksReadable() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        // This test exercises Binding-owned local fallbacks. The authenticated
        // AppInitializer path also schedules a deferred Porthole view model and
        // is both unnecessary and order-sensitive in the test host.
        await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
        let resolver = CellResolver.sharedInstance
        CellBase.defaultCellResolver = resolver

        let owner = await makeOwnerIdentity()

        guard let participant = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: owner
        ) as? Meddle else {
            Issue.record("Could not resolve local conference participant preview fallback")
            return
        }

        let participantTitle = try await participant.get(
            keypath: "state.workspace.title",
            requester: owner
        )
        #expect(participantTitle == .string("Conference Participant Portal"))

        guard let admin = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceAdminPreviewShell",
            requester: owner
        ) as? Meddle else {
            Issue.record("Could not resolve local conference admin preview fallback")
            return
        }

        let adminTitle = try await admin.get(
            keypath: "state.workspace.title",
            requester: owner
        )
        #expect(adminTitle == .string("Conference Control Tower"))

        guard let entityScanner = try await resolver.cellAtEndpoint(
            endpoint: "cell:///EntityScanner",
            requester: owner
        ) as? Meddle else {
            Issue.record("Could not resolve local EntityScanner")
            return
        }

        _ = entityScanner
    }

    @Test func conferenceAIAssistantGatewayProxyReturnsStateForPresetWrites() async throws {
        await BindingLocalCellRegistration.shared.ensureRegistered()
        let resolver = CellResolver.sharedInstance
        CellBase.defaultCellResolver = resolver

        let owner = await makeOwnerIdentity()

        guard let proxy = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceAIAssistantGatewayProxy",
            requester: owner
        ) as? Meddle else {
            Issue.record("Could not resolve ConferenceAIAssistantGatewayProxy as Meddle")
            return
        }

        let systemPromptResponse = try await proxy.set(
            keypath: "setDraftSystemPrompt",
            value: .string("Conference copilot system prompt"),
            requester: owner
        )
        #expect(systemPromptResponse != nil)

        let promptResponse = try await proxy.set(
            keypath: "setDraftPrompt",
            value: .string("Give me a concise conference brief."),
            requester: owner
        )
        #expect(promptResponse != nil)

        let stateValue = try await proxy.get(
            keypath: "state",
            requester: owner
        )
        guard case let .object(stateObject) = stateValue,
              case let .object(draftObject)? = stateObject["draft"] else {
            Issue.record("Expected draft object from conference AI gateway proxy state")
            return
        }

        #expect(draftObject["systemPrompt"] == .string("Conference copilot system prompt"))
        #expect(draftObject["prompt"] == .string("Give me a concise conference brief."))
    }

    @Test func conferenceAIAssistantGatewayProxyCanCommitBufferedSessionAPIKey() async throws {
        await BindingLocalCellRegistration.shared.ensureRegistered()
        let resolver = CellResolver.sharedInstance
        CellBase.defaultCellResolver = resolver

        let owner = await makeOwnerIdentity()

        guard let proxy = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceAIAssistantGatewayProxy",
            requester: owner
        ) as? Meddle else {
            Issue.record("Could not resolve ConferenceAIAssistantGatewayProxy as Meddle")
            return
        }

        let bufferResponse = try await proxy.set(
            keypath: "setDraftAPIKeyEntry",
            value: .string("sk-test-buffered-session-key"),
            requester: owner
        )
        #expect(bufferResponse != nil)

        let commitResponse = try await proxy.set(
            keypath: "commitDraftAPIKeyEntry",
            value: .null,
            requester: owner
        )
        #expect(commitResponse != nil)

        let stateValue = try await proxy.get(
            keypath: "state",
            requester: owner
        )
        guard case let .object(stateObject) = stateValue,
              case let .object(setupObject)? = stateObject["setup"] else {
            Issue.record("Expected setup object from conference AI gateway proxy state")
            return
        }

        #expect(setupObject["sessionCredentialAvailable"] == .bool(true))
        #expect(setupObject["activeCredentialSource"] == .string("session"))
    }

    @Test func conferenceWorkbenchFallsBackToLocalPreviewWhenStagingPreviewIsDenied() {
        let contentView = ContentView()

        let participantConfiguration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell://staging.haven.digipomps.org/ConferenceParticipantPreviewShell"
        )
        let participantFallback = contentView.localConferencePreviewFallbackConfiguration(
            for: participantConfiguration,
            failureDetails: ["denied: preview owner required"]
        )

        #expect(participantFallback?.cellReferences?.first?.endpoint == "cell:///ConferenceParticipantPreviewShell")
        #expect(participantFallback?.discovery?.sourceCellEndpoint == "cell:///ConferenceParticipantPreviewShell")

        let adminConfiguration = ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
            endpoint: "cell://staging.haven.digipomps.org/ConferenceAdminPreviewShell"
        )
        let adminFallback = contentView.localConferencePreviewFallbackConfiguration(
            for: adminConfiguration,
            failureDetails: ["denied: organizer VC required"]
        )

        #expect(adminFallback?.cellReferences?.first?.endpoint == "cell:///ConferenceAdminPreviewShell")
        #expect(adminFallback?.discovery?.sourceCellEndpoint == "cell:///ConferenceAdminPreviewShell")

        let aiAssistantConfiguration = ConfigurationCatalogCell.conferenceAIAssistantWorkbenchConfiguration(
            conferenceEndpoint: "cell://staging.haven.digipomps.org/ConferenceParticipantPreviewShell",
            aiEndpoint: "cell://staging.haven.digipomps.org/ConferenceAIGatewayPreview"
        )
        let aiAssistantFallback = contentView.localConferencePreviewFallbackConfiguration(
            for: aiAssistantConfiguration,
            failureDetails: ["finishedWithoutValue"]
        )
        #expect(aiAssistantFallback?.cellReferences?.first?.endpoint == "cell:///ConferenceParticipantPreviewShell")
        #expect(aiAssistantFallback?.cellReferences?.last?.endpoint == "cell:///ConferenceAIAssistantGatewayProxy")
        #expect(aiAssistantFallback?.discovery?.sourceCellEndpoint == "cell:///ConferenceParticipantPreviewShell")

        #expect(
            contentView.localConferencePreviewFallbackConfiguration(
                for: participantConfiguration,
                failureDetails: ["Timeout ved lasting av conference preview"]
            )?.cellReferences?.first?.endpoint == "cell:///ConferenceParticipantPreviewShell"
        )

        #expect(
            contentView.localConferencePreviewFallbackConfiguration(
                for: adminConfiguration,
                failureDetails: ["Innholdet er ikke tilgjengelig akkurat nå."]
            )?.cellReferences?.first?.endpoint == "cell:///ConferenceAdminPreviewShell"
        )
    }

    @Test func conferencePreviewFixtureFallbackRequiresExplicitDebugOptIn() {
        #expect(
            ContentView.conferencePreviewFixtureFallbackEnabled(
                environment: [:],
                launchArguments: []
            ) == false
        )
#if DEBUG
        #expect(
            ContentView.conferencePreviewFixtureFallbackEnabled(
                environment: ["BINDING_ENABLE_CONFERENCE_FIXTURE_FALLBACK": "true"],
                launchArguments: []
            )
        )
        #expect(
            ContentView.conferencePreviewFixtureFallbackEnabled(
                environment: [:],
                launchArguments: ["--enable-conference-fixture-fallback"]
            )
        )
#endif
    }

    @Test func conferenceAdminWorkbenchPrefersOrganizerRequesterDescriptor() {
        let contentView = ContentView()
        let configuration = ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
            endpoint: "cell://staging.haven.digipomps.org/ConferenceAdminShell"
        )

        #expect(
            contentView.preferredRequesterDescriptor(for: configuration)
            == .init(
                identityContext: "conference-organizer@staging.haven.digipomps.org",
                displayName: "Conference Organizer"
            )
        )
    }

    @Test func conferencePublicSurfaceDoesNotRequireAuthenticatedRuntimeBootstrap() {
        let contentView = ContentView()
        let publicConfiguration = ConfigurationCatalogCell.conferencePublicWorkbenchConfiguration(
            endpoint: "cell://staging.haven.digipomps.org/ConferencePublicShell"
        )
        let aiAssistantConfiguration = ContentView.conferenceAIAssistantAutomationConfiguration()
        let launcherConfiguration = ConfigurationCatalogCell.conferenceDemoLauncherWorkbenchConfiguration()
        let identityLinkConfiguration = ConfigurationCatalogCell.conferenceIdentityLinkWorkbenchConfiguration()
        let agentSetupConfiguration = ConfigurationCatalogCell.agentSetupWorkbenchConfiguration()
        let participantPortalConfiguration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )
        let participantChatConfiguration = ConfigurationCatalogCell.conferenceParticipantChatWorkbenchConfiguration(
            participantEndpoint: "cell:///ConferenceParticipantPreviewShell"
        )
        let namedParticipantChatConfiguration = ConfigurationCatalogCell.conferenceParticipantChatWorkbenchConfiguration(
            participantEndpoint: "cell:///ConferenceParticipantPreviewShell",
            displayName: "Conference Participant Chat · Ane Solberg",
            summary: "Conference participant chat with Ane Solberg."
        )
        let controlTowerConfiguration = ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
            endpoint: "cell:///ConferenceAdminPreviewShell"
        )

        #expect(contentView.requiresAuthenticatedRuntimeBootstrap(publicConfiguration) == false)
        #expect(contentView.requiresAuthenticatedRuntimeBootstrap(aiAssistantConfiguration) == false)
        #expect(contentView.requiresAuthenticatedRuntimeBootstrap(launcherConfiguration) == false)
        #expect(contentView.requiresAuthenticatedRuntimeBootstrap(identityLinkConfiguration) == false)
        #expect(contentView.requiresAuthenticatedRuntimeBootstrap(agentSetupConfiguration) == false)
        #expect(contentView.requiresAuthenticatedRuntimeBootstrap(participantPortalConfiguration) == false)
        #expect(contentView.requiresAuthenticatedRuntimeBootstrap(participantChatConfiguration) == false)
        #expect(contentView.requiresAuthenticatedRuntimeBootstrap(namedParticipantChatConfiguration) == false)
        #expect(contentView.requiresAuthenticatedRuntimeBootstrap(controlTowerConfiguration) == false)
    }

    @Test func agentSetupWorkbenchUsesProvisioningStateBindings() throws {
        let configuration = ConfigurationCatalogCell.agentSetupWorkbenchConfiguration()
        let data = try JSONEncoder().encode(configuration)
        let json = String(decoding: data, as: UTF8.self)

        #expect(json.contains("agentSetup.state.agent.setup.status.installStage"))
        #expect(json.contains("agentSetup.state.agent.setup.review.queueState"))
        #expect(json.contains("agentSetup.state.agent.setup.activity"))
        #expect(json.contains("agentSetup.state.status.installStage") == false)
        #expect(json.contains("agentSetup.state.review.queueState") == false)
    }

    @Test func conferenceBridgeHeavySurfacesUseExtendedLoadTimeouts() {
        let contentView = ContentView()
        let aiAssistantConfiguration = ContentView.conferenceAIAssistantAutomationConfiguration()
        let publicConfiguration = ContentView.conferencePublicAutomationConfiguration()
        let participantConfiguration = ContentView.conferenceParticipantPortalMenuSeedConfiguration()

        #expect(contentView.configurationLoadTimeoutNanoseconds(for: aiAssistantConfiguration) == 30_000_000_000)
        #expect(contentView.configurationLoadTimeoutNanoseconds(for: publicConfiguration) == 20_000_000_000)
        #expect(contentView.configurationLoadTimeoutNanoseconds(for: participantConfiguration) == 10_000_000_000)
    }

    @Test func mixedConferenceAndAIWorkbenchDoesNotForceSingleSpecialRequester() {
        let contentView = ContentView()
        let configuration = ConfigurationCatalogCell.conferenceAIAssistantWorkbenchConfiguration(
            conferenceEndpoint: "cell://staging.haven.digipomps.org/ConferenceParticipantPreviewShell",
            aiEndpoint: "cell://staging.haven.digipomps.org/ConferenceAIGatewayPreview"
        )

        #expect(
            contentView.preferredRequesterDescriptor(for: configuration) == .init(
                identityContext: "conference-participant-preview:preview-demo@staging.haven.digipomps.org",
                displayName: "Conference Participant Preview"
            )
        )
    }

    @Test func validationServiceFlagsUnresolvedSkeletonBindings() {
        var configuration = CellConfiguration(name: "Broken")
        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "ghost.value")),
            .Text(SkeletonText(keypath: "ghost.status"))
        ]))

        let report = CellConfigurationValidationService.validate(configuration)

        #expect(report.errorCount > 0)
        #expect(report.issues.contains(where: { $0.title == "Mangler CellReferences" }))
        #expect(report.issues.contains(where: { $0.title == "Bindings uten matchende reference" }))
    }

    @Test func validationServiceWarnsWhenSkeletonLacksOwnerEntityAccess() {
        var configuration = CellConfiguration(name: "No Owner Access")
        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(text: "Prosjektstatus")),
            .Text(SkeletonText(text: "Utestående arbeid"))
        ]))

        let report = CellConfigurationValidationService.validate(configuration)

        #expect(report.warningCount > 0)
        #expect(report.issues.contains(where: { $0.title == "Mangler eier-entitet tilgang" }))
    }

    @Test func validationServiceAcceptsVisibleCopilotOwnerEntityAccess() {
        var configuration = CellConfiguration(name: "With Owner Access")
        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(text: "Prosjektstatus")),
            .Button(SkeletonButton(
                keypath: "cell:///PersonalChatHub/chatHub.ui.openOwnEntity",
                label: "Co-Pilot"
            ))
        ]))

        let report = CellConfigurationValidationService.validate(configuration)

        #expect(!report.issues.contains(where: { $0.title == "Mangler eier-entitet tilgang" }))
    }

    @Test func validationServiceIgnoresDispatchActionPayloadKeypaths() {
        var configuration = CellConfiguration(name: "Dispatch Action")
        configuration.addReference(
            CellReference(
                endpoint: "cell://staging.haven.digipomps.org/ConferenceParticipantPreviewShell",
                label: "conferenceParticipantShell"
            )
        )

        let actionButton = SkeletonButton(
            keypath: "conferenceParticipantShell.dispatchAction",
            label: "Vis for deg",
            payload: .object([
                "keypath": .string("agenda.setView"),
                "payload": .object(["view": .string("forYou")])
            ])
        )

        configuration.skeleton = .VStack(
            SkeletonVStack(elements: [
                .Text(SkeletonText(keypath: "conferenceParticipantShell.state.workspace.title")),
                .Button(actionButton)
            ])
        )

        let report = CellConfigurationValidationService.validate(configuration)

        #expect(!report.issues.contains(where: {
            $0.title == "Bindings uten matchende reference"
        }))
    }

    @Test func validationServiceIgnoresDirectDispatchActionPayloadKeypaths() {
        var configuration = CellConfiguration(name: "Direct Dispatch Action")
        configuration.addReference(
            CellReference(
                endpoint: "cell:///ConferenceNearbyRadar",
                label: "nearbyRadar"
            )
        )

        let actionButton = SkeletonButton(
            keypath: "dispatchAction",
            label: "Start scanner",
            url: "cell:///ConferenceNearbyRadar",
            payload: .object([
                "keypath": .string("start"),
                "payload": .bool(true)
            ])
        )

        configuration.skeleton = .VStack(
            SkeletonVStack(elements: [
                .Text(SkeletonText(keypath: "nearbyRadar.state.summary")),
                .Button(actionButton)
            ])
        )

        let report = CellConfigurationValidationService.validate(configuration)

        #expect(!report.issues.contains(where: {
            $0.title == "Bindings uten matchende reference"
        }))
    }

    @Test func validationServiceIgnoresRelativeBindingsInsideFlowElementSkeleton() {
        var configuration = CellConfiguration(name: "Flow Element Snapshot")
        configuration.addReference(
            CellReference(
                endpoint: "cell:///ConferenceNearbyRadar",
                label: "nearbyRadar"
            )
        )

        var snapshotReference = SkeletonCellReference(
            keypath: "nearbyRadar",
            topic: "nearbyRadar.snapshot"
        )
        snapshotReference.flowElementSkeleton = SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "radarLayout.ahead.title")),
            .Text(SkeletonText(keypath: "radarLayout.center.subtitle")),
            .Text(SkeletonText(keypath: "selectedEntity.title"))
        ])

        configuration.skeleton = .VStack(
            SkeletonVStack(elements: [
                .Reference(snapshotReference)
            ])
        )

        let report = CellConfigurationValidationService.validate(configuration)

        #expect(!report.issues.contains(where: {
            $0.title == "Bindings uten matchende reference"
        }))
    }

    @Test func skeletonBindingProbeSupportExtractsConferenceParticipantStateRoot() {
        let configuration = makeConferenceParticipantPortalConfiguration()
        let probes = SkeletonBindingProbeSupport.rootProbes(for: configuration)

        #expect(probes.contains(where: {
            $0.label == "conferenceParticipantShell" && $0.rootKeypath == "state"
        }))
    }

    @Test func skeletonBindingProbeSupportSkipsButtonActionKeypaths() {
        var configuration = CellConfiguration(name: "Action Probe")
        configuration.addReference(CellReference(endpoint: "cell:///Chat", label: "chat"))
        configuration.skeleton = .VStack(
            SkeletonVStack(elements: [
                .Text(SkeletonText(keypath: "chat.status")),
                .Button(SkeletonButton(keypath: "chat.dispatchAction", label: "Open"))
            ])
        )

        let probes = SkeletonBindingProbeSupport.rootProbes(for: configuration)

        #expect(probes.contains(where: {
            $0.label == "chat" && $0.rootKeypath == "status"
        }))
        #expect(!probes.contains(where: {
            $0.label == "chat" && $0.rootKeypath == "dispatchAction"
        }))
    }

    @Test func remoteEndpointAccessTreatsStagingCellsAsScaffoldAdmissions() {
        #expect(RemoteEndpointAccessSupport.authorizationKind(for: "cell://staging.haven.digipomps.org/Chat") == .scaffoldAdmission)
        #expect(RemoteEndpointAccessSupport.authorizationKind(for: "wss://staging.haven.digipomps.org/bridgehead/ConfigurationCatalog") == .scaffoldAdmission)
    }

    @Test func remoteEndpointAccessTreatsPublicSkeletonParityFixturesAsOpenContracts() {
        #expect(RemoteEndpointAccessSupport.authorizationKind(for: "cell://staging.haven.digipomps.org/SkeletonParityTextFixture") == .none)
        #expect(RemoteEndpointAccessSupport.authorizationKind(for: "cell://staging.haven.digipomps.org/SkeletonParityRemoteBridgeFixture") == .none)
        #expect(RemoteEndpointAccessSupport.authorizationKind(for: "cell://staging.haven.digipomps.org/SkeletonParityInvalidFixture") == .none)
        #expect(RemoteEndpointAccessSupport.authorizationKind(for: "cell://staging.haven.digipomps.org/ConfigurationCatalog") == .scaffoldAdmission)
    }

    @Test func stagingWebSocketEndpointsCanonicalizeToBridgeheadRoute() {
        let bridgeheadRoute = RemoteEndpointAccessSupport.canonicalRoute(
            for: "wss://staging.haven.digipomps.org/bridgehead/ConferenceUIRouter"
        )

        #expect(bridgeheadRoute?.websocketEndpoint == "bridgehead")
        let usesEndpointFirstPath: Bool
        if case .some(.endpointThenPublisherUUID) = bridgeheadRoute?.pathLayout {
            usesEndpointFirstPath = true
        } else {
            usesEndpointFirstPath = false
        }
        #expect(usesEndpointFirstPath)
    }

    @Test func stagingAIGatewayRouteRegistrationRepairsStaleRemoteRoute() {
        let resolver = CellResolver.sharedInstance
        let stagingHost = "staging.haven.digipomps.org"
        let previousRoute = resolver.remoteCellHostRoutesSnapshot()[stagingHost]
        defer {
            if let previousRoute {
                resolver.registerRemoteCellHost(stagingHost, route: previousRoute)
            } else {
                resolver.unregisterRemoteCellHost(stagingHost)
            }
        }

        resolver.registerRemoteCellHost(
            stagingHost,
            route: RemoteCellHostRoute(websocketEndpoint: "browserhead/wsce", schemePreference: .wss)
        )

        RemoteEndpointAccessSupport.registerRemoteRouteIfNeeded(
            for: "cell://staging.haven.digipomps.org/ConferenceAIGatewayPreview",
            resolver: resolver
        )

        let repairedRoute = resolver.remoteCellHostRoutesSnapshot()[stagingHost]
        #expect(repairedRoute?.websocketEndpoint == "bridgehead")
        #expect(repairedRoute?.schemePreference == .wss)
        let usesEndpointFirstPath: Bool
        if case .some(.endpointThenPublisherUUID) = repairedRoute?.pathLayout {
            usesEndpointFirstPath = true
        } else {
            usesEndpointFirstPath = false
        }
        #expect(usesEndpointFirstPath)
    }

    @Test func remoteEndpointAccessUsesBridgeAgreementBeforeAdmission() async throws {
        let snapshot = try await remoteEndpointAccessAgreementOrderingSnapshot()
        let firstAdmit = snapshot.commands.firstIndex(of: Command.admit.rawValue)
        let firstAgreement = snapshot.commands.firstIndex(of: Command.agreement.rawValue)
        let secondDescription = snapshot.commands.dropFirst().firstIndex(of: Command.description.rawValue)

        #expect(secondDescription != nil)
        #expect(firstAdmit != nil)
        #expect(firstAgreement != nil)
        if let secondDescription, let firstAdmit {
            #expect(secondDescription < firstAdmit)
        }
        #expect(snapshot.signedAgreementGrantKeypaths.contains("state"))
        #expect(snapshot.signedAgreementGrantKeypaths.contains("skeletonConfiguration"))
        #expect(snapshot.responseErrors.isEmpty)
    }

    @Test func conferencePublicConfigurationRegistersRouteFromDiscoveryEndpoint() {
        let contentView = ContentView()
        let resolver = CellResolver.sharedInstance
        let stagingHost = "staging.haven.digipomps.org"
        let previousRoute = resolver.remoteCellHostRoutesSnapshot()[stagingHost]
        defer {
            if let previousRoute {
                resolver.registerRemoteCellHost(stagingHost, route: previousRoute)
            } else {
                resolver.unregisterRemoteCellHost(stagingHost)
            }
        }

        resolver.unregisterRemoteCellHost(stagingHost)

        var configuration = ConfigurationCatalogCell.conferencePublicWorkbenchConfiguration(
            endpoint: "cell://staging.haven.digipomps.org/ConferencePublicShell"
        )
        configuration.cellReferences = []

        contentView.registerRemoteRoutesIfNeeded(for: configuration, resolver: resolver)

        let repairedRoute = resolver.remoteCellHostRoutesSnapshot()[stagingHost]
        #expect(repairedRoute?.websocketEndpoint == "bridgehead")
        #expect(repairedRoute?.schemePreference == .wss)
    }

    @Test func conferencePublicSurfaceUsesCurrentSectionShape() {
        let configuration = ConfigurationCatalogCell.conferencePublicWorkbenchConfiguration(
            endpoint: "cell:///ConferencePublicShellFixture"
        )

        let references = configuration.cellReferences ?? []
        #expect(references.contains(where: {
            $0.label == "conferencePublicShell" && $0.endpoint == "cell:///ConferencePublicShellFixture" && $0.subscribeFeed
        }))

        guard let skeleton = configuration.skeleton else {
            Issue.record("Conference public surface mangler skeleton")
            return
        }

        #expect(skeletonContainsTextKeypath("conferencePublicShell.state.workspace.title", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferencePublicShell.state.workspace.ctaTitle", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferencePublicShell.state.access.headline", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferencePublicShell.state.tracksIntro", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferencePublicShell.state.sessionsIntro", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferencePublicShell.state.peopleIntro", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferencePublicShell.state.articlesIntro", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferencePublicShell.state.facilitiesIntro", in: skeleton))
    }

    @Test func conferenceControlTowerUsesCurrentSectionShape() {
        let configuration = ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
            endpoint: "cell:///ConferenceAdminPreviewShell"
        )

        guard let skeleton = configuration.skeleton else {
            Issue.record("Conference control tower mangler skeleton")
            return
        }

        #expect(skeletonContainsTextKeypath("conferenceAdminShell.state.followUpStory.headline", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceAdminShell.state.insightStory.headline", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceAdminShell.state.access.headline", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceAdminShell.state.audienceDiscovery.headline", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceAdminShell.state.accessRequests.headline", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceAdminShell.state.sessionThread.headline", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceAdminShell.state.sessionPolling.headline", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceAdminShell.state.simulation.headline", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceAdminShell.state.system.headline", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceAdminShell.state.sponsor.dashboardSummary", in: skeleton))
        #expect(skeletonContainsButton(keypath: "conferenceAdminShell.dispatchAction", in: skeleton))
    }

    @Test func remoteEndpointAccessTreatsLoopbackBridgeheadAsLiveControlAgreement() {
        #expect(RemoteEndpointAccessSupport.authorizationKind(for: "ws://127.0.0.1:43110/bridgehead/agent/identity") == .liveControlAgreement)
        #expect(RemoteEndpointAccessSupport.authorizationKind(for: "ws://localhost:43110/bridgehead") == .liveControlAgreement)
    }

    @Test func liveControlAgreementNeverSelfApprovesAForeignRequester() async throws {
        let owner = await makeOwnerIdentity()
        let requester = try #require(await Self.testIdentityVault.identity(
            for: "live-control-foreign-requester-\(UUID().uuidString)",
            makeNewIfNotFound: true
        ))
        let cell = await AgentEnrollmentCell(owner: owner)

        do {
            try await LiveControlBridgeAuthorization.authorizeIfNeeded(cell, requester: requester)
            Issue.record("A foreign live-control requester must not be able to approve its own Agreement.")
        } catch let error as LiveControlBridgeAuthorization.AuthorizationError {
            #expect(error.localizedDescription.contains("not accepted"))
        }
    }

    @Test func remoteEndpointAccessLeavesLocalCellsUnmanaged() {
        #expect(RemoteEndpointAccessSupport.authorizationKind(for: "cell:///ConfigurationCatalog") == .none)
        #expect(RemoteEndpointAccessSupport.authorizationKind(for: "cell:///Perspective") == .none)
    }

    @Test func entityScannerWorkbenchConfigurationsStayLocalToBinding() throws {
        let configurations = [
            ConfigurationCatalogCell.entityScannerWorkbenchConfiguration(),
            ConfigurationCatalogCell.entityScannerTestHelperConfiguration(),
            ConfigurationCatalogCell.entityScannerPairingChecklistConfiguration()
        ]

        for configuration in configurations {
            let encoded = try JSONEncoder().encode(configuration)
            let decoded = try JSONDecoder().decode(CellConfiguration.self, from: encoded)
            let references = decoded.cellReferences ?? []
            #expect(references.contains(where: { $0.endpoint == "cell:///EntityScanner" }))
            #expect(references.contains(where: { $0.endpoint == "cell:///ConferenceNearbyRadar" }))
            #expect(!references.contains(where: { $0.endpoint.contains("staging.haven.digipomps.org/EntityScanner") }))
            guard let scannerReference = references.first(where: {
                $0.endpoint == "cell:///EntityScanner" && $0.label == "scanner"
            }) else {
                Issue.record("\(decoded.name) mangler lokal EntityScanner-referanse")
                continue
            }
            #expect(scannerReference.setKeysAndValues.first(where: { $0.key == "start" })?.value == .bool(true))

            guard let skeleton = decoded.skeleton else {
                Issue.record("\(decoded.name) mangler skeleton")
                continue
            }

            #expect(skeletonContainsTextKeypath("nearbyRadar.state.statusSummary", in: skeleton))
            #expect(skeletonContainsTextKeypath("nearbyRadar.state.spatialTruthSummary", in: skeleton))
            #expect(skeletonContainsTextKeypath("nearbyRadar.state.radarLayout.center.title", in: skeleton))
            #expect(skeletonContainsGrid(keypath: "nearbyRadar.state.nearby", in: skeleton))
            #expect(skeletonContainsTextKeypath("nearbyRadar.state.selectedEntity.relevanceBadge", in: skeleton))
            #expect(skeletonContainsTextKeypath("nearbyRadar.state.selectedEntity.detail", in: skeleton))
            #expect(skeletonContainsGrid(keypath: "nearbyRadar.state.selectedEntityActions", in: skeleton))
        }
    }

    @Test func conferenceParticipantPortalWorkbenchIncludesDiscoveryAndLocalScannerEnrichment() {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration()
        let references = configuration.cellReferences ?? []

        #expect(references.contains(where: { $0.label == "conferenceParticipantShell" }))
        #expect(references.contains(where: {
            $0.label == "conferenceParticipantShell" && $0.endpoint == "cell:///ConferenceParticipantPreviewShell"
        }))
        #expect(references.contains(where: {
            $0.label == "agendaSnapshot" && $0.endpoint == "cell:///ConferenceParticipantAgendaSnapshot"
        }))
        #expect(references.contains(where: {
            $0.label == "matchmakingSnapshot" && $0.endpoint == "cell:///ConferenceParticipantMatchmakingSnapshot"
        }))
        #expect(references.contains(where: {
            $0.label == "discoverySnapshot" && $0.endpoint == "cell:///ConferenceParticipantDiscoverySnapshot"
        }))
        #expect(references.contains(where: { $0.label == "nearbyRadar" && $0.endpoint == "cell:///ConferenceNearbyRadar" }))
        #expect(references.contains(where: { $0.label == "chatSnapshot" && $0.endpoint == "cell:///ConferenceParticipantChatSnapshot" }))

        guard let skeleton = configuration.skeleton else {
            Issue.record("Conference participant portal mangler skeleton")
            return
        }

        #expect(skeletonContainsTextKeypath("agendaSnapshot.state.status", in: skeleton))
        #expect(skeletonContainsTextKeypath("agendaSnapshot.state.selectionSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("agendaSnapshot.state.viewSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("agendaSnapshot.state.navigationSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("agendaSnapshot.state.trackSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("agendaSnapshot.state.recommendedSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("agendaSnapshot.state.savedSummary", in: skeleton))
        #expect(skeletonContainsGrid(keypath: "agendaSnapshot.state.modeChoices", in: skeleton))
        #expect(skeletonContainsGrid(keypath: "agendaSnapshot.state.trackChoices", in: skeleton))
        #expect(skeletonContainsGrid(keypath: "agendaSnapshot.state.trackOptions", in: skeleton))
        #expect(skeletonContainsGrid(keypath: "agendaSnapshot.state.recommendedSessions", in: skeleton))
        #expect(skeletonContainsGrid(keypath: "agendaSnapshot.state.timelineSessions", in: skeleton))
        #expect(skeletonContainsTextKeypath("agendaSnapshot.state.nextStepSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("matchmakingSnapshot.state.statusSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("matchmakingSnapshot.state.selectionSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("matchmakingSnapshot.state.focusedProfile.title", in: skeleton))
        #expect(skeletonContainsTextKeypath("matchmakingSnapshot.state.actionSummary", in: skeleton))
        #expect(skeletonContainsButton(keypath: "matchmakingSnapshot.dispatchAction", in: skeleton))
        #expect(skeletonContainsReference(keypath: "discoverySnapshot", topic: "discoverySnapshot.snapshot", in: skeleton))
        #expect(skeletonContainsTextKeypath("status", in: skeleton))
        #expect(skeletonContainsTextKeypath("nextAction", in: skeleton))
        #expect(skeletonContainsTextKeypath("statusSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("selectionSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("focusedProfile.title", in: skeleton))
        #expect(skeletonContainsTextKeypath("alignmentSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("proofSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("nearbyRadar.state.summary", in: skeleton))
        #expect(skeletonContainsTextKeypath("nearbyRadar.state.selectionSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("nearbyRadar.state.actionSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("nearbyRadar.state.selectedEntity.relevanceBadge", in: skeleton))
        #expect(skeletonContainsTextKeypath("nearbyRadar.state.selectedEntity.purposeSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("nearbyRadar.state.selectedEntity.followUpSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("nearbyRadar.state.selectedEntity.title", in: skeleton))
        #expect(skeletonContainsTextKeypath("nearbyRadar.state.selectedEntity.note", in: skeleton))
        #expect(skeletonContainsTextKeypath("chatSnapshot.state.statusSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("chatSnapshot.state.selectionSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("chatSnapshot.state.nextStepSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("chatSnapshot.state.focusedThread.title", in: skeleton))
        #expect(skeletonContainsGrid(keypath: "chatSnapshot.state.focusedActions", in: skeleton))
        #expect(skeletonContainsButton(keypath: "chatSnapshot.dispatchAction", in: skeleton))
        #expect(skeletonContainsButton(keypath: "nearbyRadar.dispatchAction", in: skeleton))
        #expect(skeletonContainsButton(keypath: "discoverySnapshot.dispatchAction", in: skeleton))
        #expect(!skeletonContainsReference(keypath: "nearbyRadar", topic: "nearbyRadar.snapshot", in: skeleton))
        #expect(configuration.discovery?.sourceCellEndpoint == "cell:///ConferenceParticipantPreviewShell")
        #expect(configuration.discovery?.sourceCellName == "ConferenceParticipantPreviewShellLocalFallbackCell")
        #expect(configuration.description?.contains("lokal preview-wrapper") == true)
    }

    @Test func personalCopilotLocalSurfacesExposeRuntimePurposeBindings() {
        let cases: [(configuration: CellConfiguration, keypaths: [String], buttons: [(keypath: String, url: String?)], textAreaTargets: [String])] = [
            (
                ConfigurationCatalogCell.personalHomeMenuConfiguration(),
                [
                    "identity.state.identityMode",
                    "identity.state.publicIdentityStatus",
                    "identity.state.exportStatus",
                    "identity.state.deleteStatus",
                    "identity.state.status"
                ],
                [
                    ("requestExport", "cell:///PersonalIdentity"),
                    ("requestAccountDelete", "cell:///PersonalIdentity"),
                    ("cancelAccountDelete", "cell:///PersonalIdentity"),
                    ("dispatchAction", "cell:///PersonalCopilotNavigator")
                ],
                []
            ),
            (
                ConfigurationCatalogCell.personalProfileMenuConfiguration(),
                [
                    "profileDraft.state.publishedStatus",
                    "profileDraft.state.publishPreview.summary",
                    "profileDraft.state.requiresExplicitConsent",
                    "profileDraft.state.status"
                ],
                [
                    ("profileDraft.preparePublishPreview", nil),
                    ("profileDraft.recordPublishConsent", nil),
                    ("profileDraft.resetDraft", nil)
                ],
                [
                    "profileDraft.profile.summary"
                ]
            ),
            (
                ConfigurationCatalogCell.personalVaultIdeasMenuConfiguration(),
                [
                    "vault.vault.state"
                ],
                [
                    ("vault.note.create", "cell:///Vault"),
                    ("graph.reindex", "cell:///GraphIndex"),
                    ("graph.neighbors", "cell:///GraphIndex")
                ],
                []
            ),
            (
                ConfigurationCatalogCell.personalMeetingIntentMenuConfiguration(),
                [
                    "meetingCoordinator.state.coordinationStatus",
                    "meetingCoordinator.state.meetingBridge.provider",
                    "meetingCoordinator.state.meetingBridge.requiresCameraMicrophoneConsent",
                    "meetingCoordinator.state.nativePermissionRequests"
                ],
                [
                    ("meetingCoordinator.proposeTimes", nil),
                    ("meetingCoordinator.acceptTime", nil),
                    ("meetingCoordinator.declineTime", nil),
                    ("meetingCoordinator.clearMeetingIntent", nil)
                ],
                []
            ),
            (
                ConfigurationCatalogCell.personalPrivacyAuditMenuConfiguration(),
                [
                    "privacyAudit.state.status",
                    "privacyAudit.state.updatedAt"
                ],
                [
                    ("privacyAudit.audit.record", nil)
                ],
                []
            )
        ]

        for item in cases {
            guard let skeleton = item.configuration.skeleton else {
                Issue.record("\(item.configuration.name) should have a skeleton")
                continue
            }

            for keypath in item.keypaths {
                #expect(skeletonContainsTextKeypath(keypath, in: skeleton), "\(item.configuration.name) missing \(keypath)")
            }
            for button in item.buttons {
                #expect(
                    skeletonContainsButton(keypath: button.keypath, url: button.url, in: skeleton),
                    "\(item.configuration.name) missing \(button.keypath) at \(button.url ?? "porthole")"
                )
            }
            for target in item.textAreaTargets {
                #expect(skeletonContainsTextArea(targetKeypath: target, in: skeleton), "\(item.configuration.name) missing TextArea \(target)")
            }
        }
    }

    @Test func personalHomeUsesDirectCopilotNavigatorDispatchActions() {
        let configuration = ConfigurationCatalogCell.personalHomeMenuConfiguration()

        #expect(configuration.cellReferences?.contains(where: {
            $0.label == "personalNavigator" || $0.endpoint == "cell:///PersonalCopilotNavigator"
        }) != true)

        guard let skeleton = configuration.skeleton else {
            Issue.record("Personal Home should have a skeleton")
            return
        }

        #expect(skeletonContainsButton(keypath: "dispatchAction", url: "cell:///PersonalCopilotNavigator", in: skeleton))
    }

    @Test func storedCopilotDemoStartRefreshesToCurrentFactorySkeleton() {
        guard BindingPersonalCopilotV1Policy.appStoreCatalogGateEnabled else { return }

        var stale = ConfigurationCatalogCell.personalInviteChatMenuConfiguration()
        stale.skeleton = .Text(SkeletonText(text: "Start her"))

        let effective = ContentView.effectiveDemoStartConfiguration(storedConfiguration: stale)

        #expect(ContentView.shouldRefreshStoredDemoStartConfiguration(stale))
        #expect(effective.name == "Co-Pilot")
        if let skeleton = effective.skeleton {
            #expect(!skeletonContainsLiteralText("Start her", in: skeleton))
            #expect(skeletonTabPanel(id: "hjelp", in: skeleton) != nil)
        } else {
            Issue.record("Co-Pilot Chat default should keep its factory skeleton")
        }
    }

    @Test func conferenceParticipantPortalMenuSeedUsesLocalPreviewInBinding() {
        let configuration = ContentView.conferenceParticipantPortalMenuSeedConfiguration()

        #expect(configuration.cellReferences?.contains(where: {
            $0.label == "conferenceParticipantShell" && $0.endpoint == "cell:///ConferenceParticipantPreviewShell"
        }) == true)
        #expect(configuration.discovery?.sourceCellEndpoint == "cell:///ConferenceParticipantPreviewShell")
        #expect(configuration.discovery?.sourceCellName == "ConferenceParticipantPreviewShellLocalFallbackCell")
    }

    @Test func defaultDemoStartConfigurationFollowsProductMode() {
        let configuration = ContentView.defaultDemoStartConfiguration()

        if BindingPersonalCopilotV1Policy.appStoreCatalogGateEnabled {
            #expect(configuration.name == "Co-Pilot")
            #expect(configuration.cellReferences?.contains(where: {
                $0.label == "chatHub" && $0.endpoint == "cell:///PersonalChatHub"
            }) == true)
        } else {
            #expect(configuration.name == "Conference Demo Launcher")
            #expect(configuration.cellReferences?.contains(where: {
                $0.label == "conferenceDemoLauncher" && $0.endpoint == "cell:///ConferenceDemoLauncher"
            }) == true)
        }
    }

    @Test func localConferenceDemoLauncherLoadsThroughStartupPorthole() async throws {
        CellBase.defaultIdentityVault = nil
        CellBase.defaultCellResolver = nil
        CellBase.typedCellUtility = nil

        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        await BindingLocalCellRegistration.shared.ensureLocallyRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected CellResolver after local startup bootstrap")
            return
        }
        guard let owner = await CellBase.defaultIdentityVault?.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Expected startup vault identity for local conference launcher bootstrap")
            return
        }
        guard let porthole = try await resolver.cellAtEndpoint(
            endpoint: "cell:///Porthole",
            requester: owner
        ) as? OrchestratorCell else {
            Issue.record("Expected locally registered Porthole during startup bootstrap")
            return
        }

        let configuration = ConfigurationCatalogCell.conferenceDemoLauncherWorkbenchConfiguration()
        try await porthole.loadCellConfiguration(configuration, requester: owner)

        let stateValue = try await porthole.get(
            keypath: "conferenceDemoLauncher.state.statusSummary",
            requester: owner
        )

        guard case let .string(text) = stateValue else {
            Issue.record("Expected string statusSummary from conference demo launcher, got \(stateValue)")
            return
        }

        #expect(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(SkeletonBindingProbeSupport.failureDetail(from: stateValue) == nil)
    }

    @Test func localStartupPortholeDoesNotExposeAgentSetupWorkbench() async throws {
        CellBase.defaultIdentityVault = nil
        CellBase.defaultCellResolver = nil
        CellBase.typedCellUtility = nil

        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        await BindingLocalCellRegistration.shared.ensureLocallyRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected CellResolver after local startup bootstrap")
            return
        }
        guard let owner = await CellBase.defaultIdentityVault?.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Expected startup vault identity for local startup bootstrap")
            return
        }

        let provisioningResolved: Bool
        do {
            _ = try await resolver.cellAtEndpoint(endpoint: "cell:///AgentProvisioning", requester: owner)
            provisioningResolved = true
        } catch {
            provisioningResolved = false
        }

        #expect(provisioningResolved == false)
    }

    @Test func localStartupPortholeExposesAgentSetupWorkbenchWhenOptedIn() async throws {
        UserDefaults.standard.set(true, forKey: BindingPersonalCopilotV1Policy.agentSetupWorkbenchDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: BindingPersonalCopilotV1Policy.agentSetupWorkbenchDefaultsKey) }

        CellBase.defaultIdentityVault = nil
        CellBase.defaultCellResolver = nil
        CellBase.typedCellUtility = nil

        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        await BindingLocalCellRegistration.shared.ensureLocallyRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected CellResolver after local startup bootstrap")
            return
        }
        guard let owner = await CellBase.defaultIdentityVault?.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Expected startup vault identity for local startup bootstrap")
            return
        }

        let provisioning = try? await resolver.cellAtEndpoint(endpoint: "cell:///AgentProvisioning", requester: owner)
        #expect(provisioning != nil)
    }

    @Test func localBootstrapRegistersPerspectiveCell() async throws {
        CellBase.defaultIdentityVault = nil
        CellBase.defaultCellResolver = nil
        CellBase.typedCellUtility = nil

        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        await BindingLocalCellRegistration.shared.ensureLocallyRegistered()

        let resolver = CellResolver.sharedInstance
        guard let owner = await BindingStartupIdentityVault.shared.identity(
            for: "private",
            makeNewIfNotFound: true
        ) else {
            Issue.record("Expected startup vault identity for local Perspective bootstrap")
            return
        }
        guard let perspective = try await resolver.cellAtEndpoint(
            endpoint: "cell:///Perspective",
            requester: owner
        ) as? Meddle else {
            Issue.record("Expected locally registered Perspective during startup bootstrap")
            return
        }

        let stateValue = try await bindingTestEventuallyGet(
            from: perspective,
            keypath: "perspective.state",
            requester: owner
        )

        guard case .object = stateValue else {
            Issue.record("Expected object perspective.state from local Perspective bootstrap, got \(stateValue)")
            return
        }
    }

    @Test func localBootstrapRegistersEntityScannerCell() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        CellBase.defaultIdentityVault = nil
        CellBase.defaultCellResolver = nil
        CellBase.typedCellUtility = nil

        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected CellResolver after local startup bootstrap")
            return
        }
        guard let owner = await CellBase.defaultIdentityVault?.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Expected startup vault identity for local EntityScanner bootstrap")
            return
        }
        guard let scanner = try await resolver.cellAtEndpoint(
            endpoint: "cell:///EntityScanner",
            requester: owner
        ) as? Meddle else {
            Issue.record("Expected locally registered EntityScanner during startup bootstrap")
            return
        }

        _ = scanner
    }

    @Test func localBootstrapPathDoesNotBlockLaterEntityScannerRegistration() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        CellBase.defaultIdentityVault = nil
        CellBase.defaultCellResolver = nil
        CellBase.typedCellUtility = nil

        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
        await BindingLocalCellRegistration.shared.ensureConferenceDemoRuntimeReady()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected CellResolver after local conference bootstrap path")
            return
        }
        guard let owner = await CellBase.defaultIdentityVault?.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Expected startup vault identity after local conference bootstrap path")
            return
        }
        guard let scanner = try await resolver.cellAtEndpoint(
            endpoint: "cell:///EntityScanner",
            requester: owner
        ) as? Meddle else {
            Issue.record("Expected EntityScanner after local-first bootstrap path")
            return
        }

        _ = scanner
    }

    @Test func conferenceDemoRuntimeReadyKeepsStartupVaultAsDefault() async {
        CellBase.defaultIdentityVault = nil
        CellBase.defaultCellResolver = nil
        CellBase.typedCellUtility = nil

        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
        await BindingLocalCellRegistration.shared.ensureConferenceDemoRuntimeReady()

        #expect(CellBase.defaultIdentityVault is BindingStartupIdentityVault)
        #expect(!(CellBase.defaultIdentityVault is IdentityVault))
    }

    @Test func localBootstrapPathRegistersUtilityCellsWithoutAuthenticatedVault() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        CellBase.defaultIdentityVault = nil
        CellBase.defaultCellResolver = nil
        CellBase.typedCellUtility = nil

        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        await BindingLocalCellRegistration.shared.ensureLocallyRegistered()

        #expect(CellBase.defaultIdentityVault is BindingStartupIdentityVault)
        #expect(!(CellBase.defaultIdentityVault is IdentityVault))

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected CellResolver after local bootstrap path")
            return
        }
        guard let owner = await CellBase.defaultIdentityVault?.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Expected startup identity after local bootstrap path")
            return
        }

        for endpoint in [
            "cell:///GeneralCell",
            "cell:///EntityAnchor",
            "cell:///Identities"
        ] {
            let cell = try await resolver.cellAtEndpoint(endpoint: endpoint, requester: owner)
            #expect(cell.uuid.isEmpty == false)
        }
    }

    @Test func bindingStartupVaultRetainsPreviewIdentityAcrossAuthenticatedBootstrap() async {
        CellBase.defaultIdentityVault = nil
        CellBase.defaultCellResolver = nil
        CellBase.typedCellUtility = nil

        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        let startupIdentityBefore = await BindingStartupIdentityVault.shared.identity(for: "private", makeNewIfNotFound: true)

        await BindingRuntimeBootstrap.ensureBaseline()
        let startupIdentityAfter = await BindingStartupIdentityVault.shared.identity(for: "private", makeNewIfNotFound: true)

        #expect(startupIdentityBefore?.uuid == startupIdentityAfter?.uuid)
        #expect(CellBase.defaultIdentityVault != nil)
    }

    @Test func cellConfigurationVerifierDefaultsToStartupIdentityMode() {
        #expect(CellConfigurationVerifier.verifierIdentityMode(environment: [:]) == .startup)
    }

    @Test func cellConfigurationVerifierReadsStartupIdentityModeFromEnvironment() {
        #expect(
            CellConfigurationVerifier.verifierIdentityMode(
                environment: ["BINDING_VERIFIER_IDENTITY_MODE": "startup"]
            ) == .startup
        )
    }

    @Test func cellConfigurationVerifierReadsAppleIdentityModeFromEnvironment() {
        #expect(
            CellConfigurationVerifier.verifierIdentityMode(
                environment: ["BINDING_VERIFIER_IDENTITY_MODE": "apple"]
            ) == .apple
        )
    }

    @Test func localConferenceAdminPreviewProvidesExtendedStateContract() async throws {
        CellBase.defaultIdentityVault = nil
        CellBase.defaultCellResolver = nil
        CellBase.typedCellUtility = nil

        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        await BindingLocalCellRegistration.shared.ensureConferenceDemoRuntimeReady()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected CellResolver for local conference admin preview")
            return
        }
        guard let owner = await BindingStartupIdentityVault.shared.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Expected startup identity for local conference admin preview")
            return
        }
        guard let adminShell = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceAdminPreviewShell",
            requester: owner
        ) as? Meddle else {
            Issue.record("Expected ConferenceAdminPreviewShell to resolve locally")
            return
        }

        let followUpHeadline = try await adminShell.get(
            keypath: "state.followUpStory.headline",
            requester: owner
        )
        let insightHeadline = try await adminShell.get(
            keypath: "state.insightStory.headline",
            requester: owner
        )
        let accessRequestsHeadline = try await adminShell.get(
            keypath: "state.accessRequests.headline",
            requester: owner
        )
        let simulationHeadline = try await adminShell.get(
            keypath: "state.simulation.headline",
            requester: owner
        )
        let systemHeadline = try await adminShell.get(
            keypath: "state.system.headline",
            requester: owner
        )

        #expect(followUpHeadline != .string("Innholdet er ikke tilgjengelig akkurat nå."))
        #expect(insightHeadline != .string("Innholdet er ikke tilgjengelig akkurat nå."))
        #expect(accessRequestsHeadline != .string("Innholdet er ikke tilgjengelig akkurat nå."))
        #expect(simulationHeadline != .string("Innholdet er ikke tilgjengelig akkurat nå."))
        #expect(systemHeadline != .string("Innholdet er ikke tilgjengelig akkurat nå."))
    }

    @Test func localConferenceAdminPreviewSupportsDraftFieldWrites() async throws {
        CellBase.defaultIdentityVault = nil
        CellBase.defaultCellResolver = nil
        CellBase.typedCellUtility = nil

        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        await BindingLocalCellRegistration.shared.ensureConferenceDemoRuntimeReady()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected CellResolver for admin draft write test")
            return
        }
        guard let owner = await BindingStartupIdentityVault.shared.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Expected startup identity for admin draft write test")
            return
        }
        guard let adminShell = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceAdminPreviewShell",
            requester: owner
        ) as? Meddle else {
            Issue.record("Expected ConferenceAdminPreviewShell to resolve locally")
            return
        }

        _ = try await adminShell.set(
            keypath: "contentPublishing.setDraftTitle",
            value: .string("Updated from test"),
            requester: owner
        )

        let updatedTitle = try await adminShell.get(
            keypath: "state.content.draft.title",
            requester: owner
        )

        #expect(updatedTitle == .string("Updated from test"))
    }

    @Test func localConferenceParticipantPreviewFallbackRestoresAfterCodableRoundTrip() async throws {
        let previousVault = CellBase.defaultIdentityVault
        let identityVault = Self.testIdentityVault
        CellBase.defaultIdentityVault = identityVault
        defer { CellBase.defaultIdentityVault = previousVault }

        let owner = try #require(
            await identityVault.identity(
                for: "conference-participant-roundtrip-\(UUID().uuidString)",
                makeNewIfNotFound: true
            )
        )
        let original = await ConferenceParticipantPreviewShellLocalFallbackCell(owner: owner)

        _ = try await original.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("matchmaking.searchPeople"),
                "payload": .object([
                    "query": .string("governance")
                ])
            ]),
            requester: owner
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ConferenceParticipantPreviewShellLocalFallbackCell.self, from: data)
        let grantContractsBefore = Set(decoded.agreementTemplate.grants.map {
            "\($0.keypath)\u{0}\($0.permission.permissionString)"
        })

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<24 {
                group.addTask {
                    let searchSummary = try await decoded.get(
                        keypath: "state.matches.searchSummary",
                        requester: owner
                    )
                    #expect(searchSummary == .string("Search broadening: governance. No people marked for follow-up yet."))
                }
            }
            try await group.waitForAll()
        }

        let grantContractsAfter = Set(decoded.agreementTemplate.grants.map {
            "\($0.keypath)\u{0}\($0.permission.permissionString)"
        })
        #expect(grantContractsAfter == grantContractsBefore)
        #expect(decoded.agreementTemplate.grants.count == grantContractsBefore.count)

        let action = try await decoded.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("matchmaking.searchPeople"),
                "payload": .object(["query": .string("identity")])
            ]),
            requester: owner
        )
        #expect(action != nil)
        #expect(try await decoded.get(
            keypath: "state.matches.searchSummary",
            requester: owner
        ) == .string("Search broadening: identity. No people marked for follow-up yet."))
    }

    @Test func localConferenceAdminPreviewFallbackRestoresAfterCodableRoundTrip() async throws {
        let previousVault = CellBase.defaultIdentityVault
        let identityVault = Self.testIdentityVault
        CellBase.defaultIdentityVault = identityVault
        defer { CellBase.defaultIdentityVault = previousVault }

        let owner = try #require(
            await identityVault.identity(
                for: "conference-admin-roundtrip-\(UUID().uuidString)",
                makeNewIfNotFound: true
            )
        )
        let original = await ConferenceAdminPreviewShellLocalFallbackCell(owner: owner)

        _ = try await original.set(
            keypath: "contentPublishing.setDraftTitle",
            value: .string("Roundtrip title"),
            requester: owner
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ConferenceAdminPreviewShellLocalFallbackCell.self, from: data)
        let grantContractsBefore = Set(decoded.agreementTemplate.grants.map {
            "\($0.keypath)\u{0}\($0.permission.permissionString)"
        })

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<24 {
                group.addTask {
                    let title = try await decoded.get(
                        keypath: "state.content.draft.title",
                        requester: owner
                    )
                    #expect(title == .string("Roundtrip title"))
                }
            }
            try await group.waitForAll()
        }

        let grantContractsAfter = Set(decoded.agreementTemplate.grants.map {
            "\($0.keypath)\u{0}\($0.permission.permissionString)"
        })
        #expect(grantContractsAfter == grantContractsBefore)
        #expect(decoded.agreementTemplate.grants.count == grantContractsBefore.count)

        let action = try await decoded.set(
            keypath: "contentPublishing.setDraftTitle",
            value: .string("Immediate decoded title"),
            requester: owner
        )
        #expect(action != nil)
        #expect(try await decoded.get(
            keypath: "state.content.draft.title",
            requester: owner
        ) == .string("Immediate decoded title"))
    }

    @Test func effectiveDemoStartConfigurationPreservesRuntimeSelectedConfiguration() {
        let effectiveWhenMissing = ContentView.effectiveDemoStartConfiguration(
            storedConfiguration: nil
        )
        #expect(effectiveWhenMissing.name == ContentView.defaultDemoStartConfiguration().name)

        let effectiveWhenLauncherStored = ContentView.effectiveDemoStartConfiguration(
            storedConfiguration: ContentView.defaultDemoStartConfiguration()
        )
        #expect(effectiveWhenLauncherStored.name == ContentView.defaultDemoStartConfiguration().name)

        let effectiveWhenDifferentStored = ContentView.effectiveDemoStartConfiguration(
            storedConfiguration: ContentView.conferenceParticipantPortalMenuSeedConfiguration()
        )
        #expect(effectiveWhenDifferentStored.name == "Conference Participant Portal Dashboard")
    }

    @Test func conferenceParticipantPortalRepairRestoresDiscoveryAndNearbyWiring() {
        var staleConfiguration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )
        staleConfiguration.cellReferences?.removeAll { $0.label == "matchmakingSnapshot" }
        staleConfiguration.cellReferences?.removeAll { $0.label == "discoverySnapshot" }
        staleConfiguration.cellReferences?.removeAll { $0.label == "nearbyRadar" }
        staleConfiguration.cellReferences?.removeAll { $0.label == "agendaSnapshot" }

        let repaired = BindingConferenceConfigurationRepair.updatedConfigurationIfNeeded(staleConfiguration)

        #expect(repaired != nil)
        #expect(repaired?.cellReferences?.contains(where: {
            $0.label == "conferenceParticipantShell" && $0.endpoint == "cell:///ConferenceParticipantPreviewShell"
        }) == true)
        #expect(repaired?.cellReferences?.contains(where: {
            $0.label == "agendaSnapshot" && $0.endpoint == "cell:///ConferenceParticipantAgendaSnapshot"
        }) == true)
        #expect(repaired?.cellReferences?.contains(where: {
            $0.label == "matchmakingSnapshot" && $0.endpoint == "cell:///ConferenceParticipantMatchmakingSnapshot"
        }) == true)
        #expect(repaired?.cellReferences?.contains(where: {
            $0.label == "discoverySnapshot" && $0.endpoint == "cell:///ConferenceParticipantDiscoverySnapshot"
        }) == true)
        #expect(repaired?.cellReferences?.contains(where: {
            $0.label == "nearbyRadar" && $0.endpoint == "cell:///ConferenceNearbyRadar"
        }) == true)

        guard let skeleton = repaired?.skeleton else {
            Issue.record("Expected repaired conference participant portal skeleton")
            return
        }

        #expect(skeletonContainsTextKeypath("agendaSnapshot.state.viewSummary", in: skeleton))
        #expect(skeletonContainsGrid(keypath: "agendaSnapshot.state.modeChoices", in: skeleton))
        #expect(skeletonContainsGrid(keypath: "agendaSnapshot.state.trackChoices", in: skeleton))
        #expect(skeletonContainsReference(keypath: "discoverySnapshot", topic: "discoverySnapshot.snapshot", in: skeleton))
        #expect(skeletonContainsButton(keypath: "matchmakingSnapshot.dispatchAction", in: skeleton))
        #expect(skeletonContainsButton(keypath: "discoverySnapshot.dispatchAction", in: skeleton))
        #expect(skeletonContainsButton(keypath: "nearbyRadar.dispatchAction", in: skeleton))
        #expect(!skeletonContainsReference(keypath: "nearbyRadar", topic: "nearbyRadar.snapshot", in: skeleton))
    }

    @Test func conferenceParticipantPortalUsesReferenceLabelsForLocalConferenceActions() {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )

        guard let skeleton = configuration.skeleton else {
            Issue.record("Conference participant portal mangler skeleton")
            return
        }

        #expect(skeletonContainsTextKeypath("agendaSnapshot.state.viewSummary", in: skeleton))
        #expect(skeletonContainsButton(keypath: "matchmakingSnapshot.dispatchAction", in: skeleton))
        #expect(skeletonContainsButton(keypath: "discoverySnapshot.dispatchAction", in: skeleton))
        #expect(skeletonContainsButton(keypath: "nearbyRadar.dispatchAction", in: skeleton))
        #expect(!skeletonContainsButton(keypath: "dispatchAction", url: "cell:///ConferenceParticipantAgendaSnapshot", in: skeleton))
        #expect(!skeletonContainsButton(keypath: "dispatchAction", url: "cell:///ConferenceParticipantMatchmakingSnapshot", in: skeleton))
        #expect(!skeletonContainsButton(keypath: "dispatchAction", url: "cell:///ConferenceParticipantDiscoverySnapshot", in: skeleton))
        #expect(!skeletonContainsButton(keypath: "dispatchAction", url: "cell:///ConferenceNearbyRadar", in: skeleton))
    }

    @Test func conferenceControlTowerRepairRestoresAdminPreviewWiring() {
        var staleConfiguration = ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
            endpoint: "cell://staging.haven.digipomps.org/ConferenceAdminPreviewShell"
        )
        staleConfiguration.cellReferences = []
        staleConfiguration.skeleton = .VStack(
            SkeletonVStack(elements: [
                .Text(SkeletonText(keypath: "conferenceAdminShell.state.workspace.title"))
            ])
        )

        let repaired = BindingConferenceConfigurationRepair.updatedConfigurationIfNeeded(staleConfiguration)

        #expect(repaired != nil)
        #expect(repaired?.cellReferences?.contains(where: {
            $0.label == "conferenceAdminShell" && $0.endpoint == "cell:///ConferenceAdminPreviewShell"
        }) == true)

        guard let skeleton = repaired?.skeleton else {
            Issue.record("Expected repaired conference control tower skeleton")
            return
        }

        #expect(skeletonContainsTextKeypath("conferenceAdminShell.state.workspace.title", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceAdminShell.state.followUpStory.headline", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceAdminShell.state.insightStory.headline", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceAdminShell.state.audienceDiscovery.headline", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceAdminShell.state.system.headline", in: skeleton))
        #expect(skeletonContainsButton(keypath: "conferenceAdminShell.dispatchAction", in: skeleton))
    }

    @Test func conferenceControlTowerDefaultsToLocalPreviewInBinding() {
        let configuration = ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration()
        let references = configuration.cellReferences ?? []

        #expect(references.contains(where: {
            $0.label == "conferenceAdminShell" && $0.endpoint == "cell:///ConferenceAdminPreviewShell"
        }))
        #expect(!references.contains(where: {
            $0.label == "conferenceAdminShell" && $0.endpoint.contains("staging.haven.digipomps.org")
        }))
        #expect(configuration.description?.contains("lokal preview-wrapper") == true)
        #expect(configuration.discovery?.sourceCellName == "ConferenceAdminPreviewShellLocalFallbackCell")
    }

    @Test func conferenceAdminMenuSeedUsesLocalPreviewInBinding() {
        let configuration = ContentView.conferenceAdminMenuSeedConfiguration()
        let references = configuration.cellReferences ?? []

        #expect(references.contains(where: {
            $0.label == "conferenceAdminShell" && $0.endpoint == "cell:///ConferenceAdminPreviewShell"
        }))
        #expect(configuration.discovery?.sourceCellEndpoint == "cell:///ConferenceAdminPreviewShell")
        #expect(configuration.discovery?.sourceCellName == "ConferenceAdminPreviewShellLocalFallbackCell")
    }

    @Test func conferenceControlTowerUsesReferenceLabelForOrganizerActions() {
        let configuration = ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
            endpoint: "cell:///ConferenceAdminPreviewShell"
        )

        guard let skeleton = configuration.skeleton else {
            Issue.record("Conference control tower mangler skeleton")
            return
        }

        #expect(skeletonContainsButton(keypath: "conferenceAdminShell.dispatchAction", in: skeleton))
        #expect(!skeletonContainsButton(keypath: "dispatchAction", url: "cell:///ConferenceAdminPreviewShell", in: skeleton))
    }

    @Test func conferenceControlTowerOrganizerActionsAckThroughProxyAndPreviewShell() async throws {
        let configuration = ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(
            endpoint: "cell:///ConferenceAdminPreviewShell"
        )
        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        let actionPayload: ValueType = .object([
            "keypath": .string("contentPublishing.publishDraft"),
            "payload": .bool(true),
            "responseMode": .string("ack")
        ])

        let portholeResponse = try await context.porthole.set(
            keypath: "conferenceAdminShell.dispatchAction",
            value: actionPayload,
            requester: context.owner
        )
        #expect(portholeResponse != nil)
        if let portholeResponse {
            #expect(SkeletonBindingProbeSupport.failureDetail(from: portholeResponse) == nil)
        }

        guard let previewShell = try await context.resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceAdminPreviewShell",
            requester: context.owner
        ) as? Meddle else {
            Issue.record("ConferenceAdminPreviewShell did not resolve as Meddle")
            return
        }

        let previewResponse = try await previewShell.set(
            keypath: "dispatchAction",
            value: actionPayload,
            requester: context.owner
        )
        #expect(previewResponse != nil)
        if let previewResponse {
            #expect(SkeletonBindingProbeSupport.failureDetail(from: previewResponse) == nil)
        }
    }

    @Test func conferenceParticipantPortalProxyActionsFocusParticipantAndOpenChatWorkbench() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )
        let context = try await CellConfigurationVerifier.makeRuntimeContext(for: configuration)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        let focusResponse = try await context.porthole.set(
            keypath: "matchmakingSnapshot.dispatchAction",
            value: .object([
                "keypath": .string("matchmaking.focusRecommendationAtIndex"),
                "payload": .object([
                    "index": .integer(0)
                ])
            ]),
            requester: context.owner
        )
        #expect(focusResponse != nil)
        if let focusResponse {
            let focusFailure = await MainActor.run {
                SkeletonBindingProbeSupport.failureDetail(from: focusResponse)
            }
            #expect(focusFailure == nil)
        }

        let focusedTitle = try await context.porthole.get(
            keypath: "matchmakingSnapshot.state.focusedProfile.title",
            requester: context.owner
        )
        #expect(focusedTitle == .string("Ane Solberg"))

        let chatStartResponse = try await context.porthole.set(
            keypath: "matchmakingSnapshot.dispatchAction",
            value: .object([
                "keypath": .string("discovery.startChatWithFocusedPerson"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        #expect(chatStartResponse != nil)
        if let chatStartResponse {
            let chatStartFailure = await MainActor.run {
                SkeletonBindingProbeSupport.failureDetail(from: chatStartResponse)
            }
            #expect(chatStartFailure == nil)
        }

        let chatActionLabel = try await context.porthole.get(
            keypath: "matchmakingSnapshot.state.focusedActions[0].label",
            requester: context.owner
        )
        #expect(chatActionLabel == .string("Åpne chatflate"))

        let nextStepSummary = try await context.porthole.get(
            keypath: "matchmakingSnapshot.state.nextStepSummary",
            requester: context.owner
        )
        #expect(nextStepSummary == .string("Chatten med Ane Solberg er klar. Neste steg er å åpne chatflaten eller be om møte."))

        let expectedWorkbenchLoad = Task {
            await CellConfigurationVerifier.waitForPortholeLoadBridgeConfiguration(
                containingName: "Conference Participant Chat"
            )
        }
        let openChatResponse = try await context.porthole.set(
            keypath: "chatSnapshot.dispatchAction",
            value: .object([
                "keypath": .string("openChatWorkbenchForSelectedParticipant"),
                "payload": .bool(true)
            ]),
            requester: context.owner
        )
        #expect(openChatResponse != nil)
        if let openChatResponse {
            let openChatFailure = await MainActor.run {
                SkeletonBindingProbeSupport.failureDetail(from: openChatResponse)
            }
            #expect(openChatFailure == nil)
        }

        guard let configuration = await expectedWorkbenchLoad.value else {
            let actionSummary = try? await context.porthole.get(
                keypath: "chatSnapshot.state.actionSummary",
                requester: context.owner
            )
            let statusSummary = try? await context.porthole.get(
                keypath: "chatSnapshot.state.statusSummary",
                requester: context.owner
            )
            Issue.record(
                "Expected BindingPortholeLoadBridge request for Conference Participant Chat. actionSummary=\(String(describing: actionSummary)) statusSummary=\(String(describing: statusSummary))"
            )
            return
        }

        #expect(configuration.name.contains("Conference Participant Chat"))
        #expect(configuration.cellReferences?.contains(where: { $0.label == "conferenceChat" }) == true)
    }

    @Test func bindingLocalCellRegistrationMakesConferenceParticipantAgendaSnapshotReadable() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after app initialization")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Missing private identity")
            return
        }
        guard let snapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantAgendaSnapshot",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantAgendaSnapshot did not resolve as Meddle")
            return
        }

        let stateValue = try await snapshot.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue else {
            Issue.record("Expected object from ConferenceParticipantAgendaSnapshot.state, got \(stateValue)")
            return
        }

        #expect(object["statusSummary"] != nil)
        #expect(object["selectionSummary"] != nil)
        #expect(object["nextStepSummary"] != nil)
        #expect(object["actionSummary"] != nil)
        #expect(object["modeChoices"] != nil)
        #expect(object["trackChoices"] != nil)
        #expect(object["focusedActions"] != nil)
        #expect(object["trackOptions"] != nil)
    }

    @Test func conferenceParticipantAgendaSnapshotSupportsInlineSelectionAndActions() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after app initialization")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Missing private identity")
            return
        }
        guard let snapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantAgendaSnapshot",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantAgendaSnapshot did not resolve as Meddle")
            return
        }

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("agenda.setView"),
                "payload": .object([
                    "view": .string("timeline")
                ])
            ]),
            requester: identity
        )

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("agenda.setTrackFocus"),
                "payload": .object([
                    "trackId": .string("track-governance")
                ])
            ]),
            requester: identity
        )

        let stateValue = try await snapshot.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue,
              case let .list(modeChoices)? = object["modeChoices"],
              case let .object(firstModeChoice)? = modeChoices.first,
              case let .object(secondModeChoice)? = modeChoices.dropFirst().first,
              case let .list(trackChoices)? = object["trackChoices"],
              case let .object(firstTrackChoice)? = trackChoices.first,
              case let .object(secondTrackChoice)? = trackChoices.dropFirst().first,
              case let .list(trackOptions)? = object["trackOptions"],
              case let .object(firstTrackOption)? = trackOptions.first,
              case let .object(thirdTrackOption)? = trackOptions.dropFirst(2).first,
              case let .list(recommendedSessions)? = object["recommendedSessions"],
              case let .object(firstRecommendedSession)? = recommendedSessions.first,
              case let .list(timelineSessions)? = object["timelineSessions"],
              case let .object(firstTimelineSession)? = timelineSessions.first else {
            Issue.record("Expected agenda snapshot state with choices and session cards")
            return
        }

        #expect(object["statusSummary"] == .string("Viser timeline med governance i fokus."))
        #expect(object["selectionSummary"] == .string("Viser timeline med Governance i fokus."))
        #expect(object["actionSummary"] == .string("Governance er nå i fokus i denne siden."))
        #expect(firstModeChoice["label"] == .string("Vis for deg"))
        #expect(secondModeChoice["selectionBadge"] == .string("AKTIV NÅ"))
        #expect(secondModeChoice["label"] == .string("Viser nå"))
        #expect(firstTrackChoice["label"] == .string("Vis alle spor"))
        #expect(secondTrackChoice["selectionBadge"] == .string("FOKUS NÅ"))
        #expect(secondTrackChoice["label"] == .string("Viser nå"))
        #expect(firstTrackOption["selectionBadge"] == .string("SPOR"))
        #expect(thirdTrackOption["selectionBadge"] == .string("AKTIVT FOKUS"))
        #expect(firstRecommendedSession["selectionBadge"] == .string("FOR DEG"))
        #expect(firstTimelineSession["selectionBadge"] == .string("VISES NÅ"))
    }

    @Test func bindingLocalCellRegistrationMakesConferenceDiscoverySnapshotReadable() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after app initialization")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Missing private identity")
            return
        }
        guard let discoverySnapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantDiscoverySnapshot",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantDiscoverySnapshot did not resolve as Meddle")
            return
        }

        let stateValue = try await discoverySnapshot.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue else {
            Issue.record("Expected object from ConferenceParticipantDiscoverySnapshot.state, got \(stateValue)")
            return
        }

        #expect(object["status"] != nil)
        #expect(object["nextAction"] != nil)
        #expect(object["statusSummary"] != nil)
        #expect(object["selectionSummary"] != nil)
        #expect(object["focusedProfile"] != nil)
        #expect(object["focusedActions"] != nil)
        #expect(object["candidates"] != nil)
        #expect(object["proofCandidates"] != nil)
        #expect(object["groupSuggestions"] != nil)
    }

    @Test func conferenceParticipantDiscoverySnapshotSupportsInlineSelectionAndActions() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after app initialization")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Missing private identity")
            return
        }
        guard let snapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantDiscoverySnapshot",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantDiscoverySnapshot did not resolve as Meddle")
            return
        }

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("discovery.focusPerson"),
                "payload": .object([
                    "displayName": .string("Ane Solberg"),
                    "subtitle": .string("Public sector interoperability")
                ])
            ]),
            requester: identity
        )

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("matchmaking.toggleFollowUp"),
                "payload": .object([
                    "displayName": .string("Ane Solberg"),
                    "subtitle": .string("Public sector interoperability")
                ])
            ]),
            requester: identity
        )

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("discovery.startChat"),
                "payload": .object([
                    "source": .string("binding-test"),
                    "targets": .list([
                        .object([
                            "displayName": .string("Ane Solberg"),
                            "headline": .string("Public sector interoperability")
                        ])
                    ])
                ])
            ]),
            requester: identity
        )

        let stateValue = try await snapshot.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue,
              case let .object(focusedProfile)? = object["focusedProfile"],
              case let .list(focusedActions)? = object["focusedActions"],
              case let .list(candidates)? = object["candidates"],
              case let .object(firstCandidate)? = candidates.first else {
            Issue.record("Expected discovery snapshot state with focused profile and actions")
            return
        }

        #expect(object["selectionSummary"] == .string("Viser Ane Solberg i discovery-delen."))
        #expect(focusedProfile["title"] == .string("Ane Solberg"))
        #expect(firstCandidate["label"] == .string("Åpne chatflate"))

        guard case let .object(chatAction)? = focusedActions.first,
              case let .object(followUpAction)? = focusedActions.dropFirst().first,
              case let .object(meetingAction)? = focusedActions.dropFirst(2).first else {
            Issue.record("Expected three focused actions in discovery snapshot")
            return
        }

        #expect(chatAction["label"] == .string("Åpne chatflate"))
        #expect(followUpAction["label"] == .string("Fjern markering"))
        #expect(meetingAction["label"] == .string("Be om møte"))

        guard let preview = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantPreviewShell did not resolve as Meddle")
            return
        }

        let previewState = try await preview.get(keypath: "state", requester: identity)
        guard case let .object(previewObject) = previewState,
              case let .object(sharedConnections)? = previewObject["sharedConnections"],
              case let .list(connections)? = sharedConnections["connections"],
              case let .object(firstConnection)? = connections.first else {
            Issue.record("Expected shared connection after start chat")
            return
        }

        #expect(sharedConnections["connectionSummary"] == .string("1 shared relation(s) visible."))
        #expect(sharedConnections["chatSummary"] == .string("2 shared message(s) visible."))
        #expect(firstConnection["title"] == .string("Ane Solberg"))

        guard let chatSnapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantChatSnapshot",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantChatSnapshot did not resolve as Meddle")
            return
        }

        let chatState = try await chatSnapshot.get(keypath: "state", requester: identity)
        guard case let .object(chatObject) = chatState,
              case let .object(focusedThread)? = chatObject["focusedThread"] else {
            Issue.record("Expected chat snapshot state after start chat")
            return
        }

        #expect(chatObject["selectionSummary"] == .string("Viser den delte tråden med Ane Solberg."))
        #expect(focusedThread["title"] == .string("Ane Solberg"))
    }

    @Test func bindingLocalCellRegistrationMakesConferenceMatchmakingSnapshotReadable() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after app initialization")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Missing private identity")
            return
        }
        guard let snapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantMatchmakingSnapshot",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantMatchmakingSnapshot did not resolve as Meddle")
            return
        }

        let stateValue = try await snapshot.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue else {
            Issue.record("Expected object from ConferenceParticipantMatchmakingSnapshot.state, got \(stateValue)")
            return
        }

        #expect(object["statusSummary"] != nil)
        #expect(object["selectionSummary"] != nil)
        #expect(object["nextStepSummary"] != nil)
        #expect(object["focusedProfile"] != nil)
        #expect(object["focusedActions"] != nil)
        #expect(object["recommendations"] != nil)
    }

    @Test func bindingLocalCellRegistrationMakesConferenceChatSnapshotReadable() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after app initialization")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Missing private identity")
            return
        }
        guard let preview = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantPreviewShell did not resolve as Meddle")
            return
        }
        guard let snapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantChatSnapshot",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantChatSnapshot did not resolve as Meddle")
            return
        }

        _ = try await preview.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("discovery.startChat"),
                "payload": .object([
                    "source": .string("binding-test"),
                    "targets": .list([
                        .object([
                            "displayName": .string("Ane Solberg"),
                            "headline": .string("Public sector interoperability")
                        ])
                    ])
                ])
            ]),
            requester: identity
        )

        let stateValue = try await snapshot.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue,
              case let .object(focusedThread)? = object["focusedThread"],
              case let .list(focusedActions)? = object["focusedActions"] else {
            Issue.record("Expected chat snapshot state with focused thread and actions")
            return
        }

        #expect(object["statusSummary"] != nil)
        #expect(object["selectionSummary"] == .string("Viser den delte tråden med Ane Solberg."))
        #expect(object["draftSummary"] == .string("Skriv en kort oppfølging til Ane Solberg og send den direkte fra denne flaten."))
        #expect(object["personaSummary"] == .string("Ane Solberg · Public sector interoperability"))
        #expect(object["simulationSummary"] == .string("Demo-svarene holder seg til en bounded persona som representerer offentlig samhandling og governance."))
        #expect(focusedThread["title"] == .string("Ane Solberg"))
        #expect(focusedThread["nextMessage"] == .string("Hei Ane. Jeg vil gjerne snakke mer om governance-sporet og hvordan du jobber med interoperabilitet i praksis."))
        #expect(object["connections"] != nil)
        #expect(object["recentMessages"] != nil)

        guard case let .object(firstAction)? = focusedActions.first else {
            Issue.record("Expected at least one focused chat action")
            return
        }
        #expect(firstAction["label"] == .string("Send forslag"))
    }

    @Test func bindingLocalCellRegistrationMakesConferenceNearbyRadarReadable() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after app initialization")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Missing private identity")
            return
        }
        guard let radar = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceNearbyRadar",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceNearbyRadar did not resolve as Meddle")
            return
        }

        let stateValue = try await radar.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue else {
            Issue.record("Expected object from ConferenceNearbyRadar.state, got \(stateValue)")
            return
        }

        #expect(object["summary"] != nil)
        #expect(object["precisionSummary"] != nil)
        #expect(object["actionSummary"] != nil)
        #expect(object["selectionSummary"] != nil)
        #expect(object["spatialTruthSummary"] != nil)
        #expect(object["radarLayout"] != nil)
        #expect(object["selectedEntity"] != nil)
        #expect(object["selectedEntityActions"] != nil)
        #expect(object["sectors"] != nil)
        #expect(object["nearby"] != nil)
    }

    @Test func bindingLaunchWarmupMakesConferenceNearbyRadarReadable() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault

        await BindingLaunchWarmup.preloadLocalRuntime()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after launch warmup")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Missing private identity")
            return
        }
        guard let radar = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceNearbyRadar",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceNearbyRadar did not resolve as Meddle after launch warmup")
            return
        }

        let stateValue = try await radar.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue else {
            Issue.record("Expected object from ConferenceNearbyRadar.state after launch warmup, got \(stateValue)")
            return
        }

        #expect(object["summary"] != nil)
        #expect(object["precisionSummary"] != nil)
        #expect(object["actionSummary"] != nil)
        #expect(object["selectionSummary"] != nil)
        #expect(object["radarLayout"] != nil)
    }

    @Test func bindingLaunchWarmupMakesConferenceParticipantPreviewAndChatReadable() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault

        await BindingLaunchWarmup.preloadLocalRuntime()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after launch warmup")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Missing private identity")
            return
        }
        guard let preview = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantPreviewShell did not resolve as Meddle after launch warmup")
            return
        }
        guard let chat = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantChatSnapshot",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantChatSnapshot did not resolve as Meddle after launch warmup")
            return
        }

        let previewState = try await preview.get(keypath: "state", requester: identity)
        guard case let .object(previewObject) = previewState else {
            Issue.record("Expected object from ConferenceParticipantPreviewShell.state after launch warmup, got \(previewState)")
            return
        }
        #expect(previewObject["workspace"] != nil)
        #expect(previewObject["sharedConnections"] != nil)

        let chatState = try await chat.get(keypath: "state", requester: identity)
        guard case let .object(chatObject) = chatState else {
            Issue.record("Expected object from ConferenceParticipantChatSnapshot.state after launch warmup, got \(chatState)")
            return
        }
        #expect(chatObject["statusSummary"] != nil)
        #expect(chatObject["selectionSummary"] != nil)
        #expect(chatObject["nextStepSummary"] != nil)
    }

    @Test func bindingLaunchWarmupMakesConferenceParticipantSurfacesReadable() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault

        await BindingLaunchWarmup.preloadLocalRuntime()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after launch warmup")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Missing private identity")
            return
        }

        let expectedRootKeys: [(String, [String])] = [
            ("cell:///ConferenceParticipantAgendaSnapshot", ["viewSummary", "trackSummary", "actionSummary"]),
            ("cell:///ConferenceParticipantDiscoverySnapshot", ["status", "sourceSummary", "actionSummary"]),
            ("cell:///ConferenceParticipantMatchmakingSnapshot", ["status", "searchSummary", "actionSummary"]),
            ("cell:///ConferenceNearbyRadar", ["statusSummary", "selectionSummary", "actionSummary"])
        ]

        for (endpoint, keys) in expectedRootKeys {
            guard let cell = try await resolver.cellAtEndpoint(
                endpoint: endpoint,
                requester: identity
            ) as? Meddle else {
                Issue.record("\(endpoint) did not resolve as Meddle after launch warmup")
                continue
            }

            let state = try await cell.get(keypath: "state", requester: identity)
            guard case let .object(object) = state else {
                Issue.record("Expected object from \(endpoint).state after launch warmup, got \(state)")
                continue
            }

            for key in keys {
                #expect(object[key] != nil, "\(endpoint) missing \(key) after launch warmup")
            }
        }
    }

    @Test func conferenceNearbyRadarDispatchActionReturnsSnapshotObject() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await BindingLaunchWarmup.preloadLocalRuntime()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after launch warmup")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Missing private identity")
            return
        }
        guard let radar = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceNearbyRadar",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceNearbyRadar did not resolve as Meddle")
            return
        }

        let response = try await radar.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("start"),
                "payload": .bool(true)
            ]),
            requester: identity
        )

        guard case let .object(object) = response else {
            Issue.record("Expected snapshot object from ConferenceNearbyRadar.dispatchAction, got \(response)")
            return
        }

        #expect(object["summary"] != nil)
        #expect(object["actionSummary"] != nil)
    }

    @Test func conferenceNearbyRadarSeparatesApproximateSignalsFromFocusedParticipantActions() async throws {
        let identity = await makeIsolatedRuntimeIdentity("conference-nearby-radar-separates")
        await BindingLaunchWarmup.preloadLocalRuntime()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after launch warmup")
            return
        }
        guard let radar = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceNearbyRadar",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceNearbyRadar did not resolve as Meddle")
            return
        }

        _ = try await radar.set(
            keypath: "testInjectNearbyCandidate",
            value: .object([
                "remoteUUID": .string("nearby-approx-001"),
                "displayName": .string("Approx Nearby"),
                "matchScore": .float(0.34),
                "distanceMeters": .float(2.4),
                "hasDirection": .bool(false)
            ]),
            requester: identity
        )

        _ = try await radar.set(
            keypath: "testInjectVerifiedContact",
            value: .object([
                "remoteUUID": .string("nearby-verified-001"),
                "displayName": .string("Nora Berg"),
                "participantId": .string("participant-102"),
                "identityUUID": .string("identity-remote-123"),
                "company": .string("Polar Systems"),
                "role": .string("speaker"),
                "matchCount": .integer(2),
                "matchScore": .float(0.92),
                "distanceMeters": .float(1.6),
                "directionX": .float(0.0),
                "directionY": .float(0.0),
                "directionZ": .float(1.0)
            ]),
            requester: identity
        )

        let stateValue = try await radar.get(keypath: "state", requester: identity)
        guard case let .object(stateObject) = stateValue else {
            Issue.record("Expected object from ConferenceNearbyRadar.state after injecting nearby candidates, got \(stateValue)")
            return
        }

        guard case let .string(selectionSummary)? = stateObject["selectionSummary"] else {
            Issue.record("Expected selectionSummary in nearby radar state")
            return
        }
        #expect(selectionSummary.contains("Nora Berg"))

        guard case let .string(spatialTruthSummary)? = stateObject["spatialTruthSummary"] else {
            Issue.record("Expected spatialTruthSummary in nearby radar state")
            return
        }
        #expect(spatialTruthSummary.contains("faktisk retningsmåling"))
        #expect(stateObject["hiddenEntityCount"] == .integer(1))

        guard case let .object(selectedEntity)? = stateObject["selectedEntity"] else {
            Issue.record("Expected selectedEntity in nearby radar state")
            return
        }
        #expect(selectedEntity["title"] == .string("Nora Berg"))
        #expect(selectedEntity["relevanceBadge"] == .string("GRØNN MATCH"))
        #expect(selectedEntity["followUpSummary"] == .string("Identity saved. Nå kan du starte chat eller markere for oppfølging."))
        #expect(selectedEntity["chatSummary"] == .string("Chat er ikke startet ennå. Identity saved gjør at du kan trykke Start chat."))
        #expect(selectedEntity["relationBadge"] == .string("Identity saved"))
        #expect(selectedEntity["identityPersistenceSummary"] == .string("Signed identity exchange complete · relation persisted · proof saved"))

        guard case let .string(matchSummary)? = stateObject["matchSummary"] else {
            Issue.record("Expected matchSummary in nearby radar state")
            return
        }
        #expect(matchSummary.contains("Sterk verifisert match"))

        guard case let .object(radarLayout)? = stateObject["radarLayout"],
              case let .object(surface)? = radarLayout["surface"],
              case let .object(centerNode)? = radarLayout["center"] else {
            Issue.record("Expected radarLayout.center in nearby radar state")
            return
        }
        #expect(surface["renderingOwner"] == .string("binding-native-swiftui"))
        #expect(centerNode["title"] == .string("Nora Berg"))
        #expect(centerNode["relevanceBadge"] == .string("GRØNN MATCH"))

        let preciseSurfaceNodes = bindingTestValueObjects(surface["preciseNodes"])
        let noraSurfaceNode = preciseSurfaceNodes.first { bindingTestValueString($0["remoteUUID"]) == "nearby-verified-001" }
        #expect(noraSurfaceNode?["positionPrecision"] == .string("precise"))
        #expect(noraSurfaceNode?["isSelected"] == .bool(true))
        #expect(abs((bindingTestValueDouble(noraSurfaceNode?["xNormalized"]) ?? 1.0)) < 0.001)
        #expect((bindingTestValueDouble(noraSurfaceNode?["yNormalized"]) ?? 0.0) > 0.1)

        guard case let .list(selectedEntityActions)? = stateObject["selectedEntityActions"],
              case let .object(primaryAction)? = selectedEntityActions.first else {
            Issue.record("Expected selectedEntityActions in nearby radar state")
            return
        }
        #expect(primaryAction["label"] == .string("Åpne profilflate"))
        #expect(selectedEntityActions.contains { value in
            guard case let .object(action) = value else { return false }
            return action["label"] == .string("Start chat")
        })

        guard case let .list(hiddenNearby)? = stateObject["hiddenNearby"],
              case let .object(hiddenApprox)? = hiddenNearby.first else {
            Issue.record("Expected hidden lower nearby row in nearby radar state")
            return
        }
        #expect(hiddenApprox["title"] == .string("Approx Nearby"))
        #expect(hiddenApprox["relevanceBadge"] == .string("RØD MATCH"))
    }

    @Test func conferenceNearbyRadarSupportsVariableEntityCountsWithDistanceDirectionAndRelevance() async throws {
        let identity = await makeIsolatedRuntimeIdentity("conference-nearby-radar-variable-entities")
        await BindingLaunchWarmup.preloadLocalRuntime()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after launch warmup")
            return
        }
        guard let radar = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceNearbyRadar",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceNearbyRadar did not resolve as Meddle")
            return
        }

        let injectedEntities: [Object] = [
            [
                "remoteUUID": .string("nearby-variable-001"),
                "displayName": .string("Low Signal"),
                "matchScore": .float(0.18),
                "distanceMeters": .float(4.2),
                "hasDirection": .bool(false)
            ],
            [
                "remoteUUID": .string("nearby-variable-002"),
                "displayName": .string("Right Match"),
                "matchScore": .float(0.72),
                "distanceMeters": .float(1.2),
                "directionX": .float(1.0),
                "directionY": .float(0.0),
                "directionZ": .float(0.0)
            ],
            [
                "remoteUUID": .string("nearby-variable-003"),
                "displayName": .string("Close Strong Match"),
                "matchScore": .float(0.91),
                "distanceMeters": .float(0.8),
                "directionX": .float(0.0),
                "directionY": .float(0.0),
                "directionZ": .float(1.0)
            ]
        ]

        for entity in injectedEntities {
            _ = try await radar.set(
                keypath: "testInjectNearbyCandidate",
                value: .object(entity),
                requester: identity
            )
        }

        let stateValue = try await radar.get(keypath: "state", requester: identity)
        guard case let .object(stateObject) = stateValue,
              case let .list(nearbyCards)? = stateObject["nearby"] else {
            Issue.record("Expected nearby list in ConferenceNearbyRadar.state, got \(stateValue)")
            return
        }

        #expect(nearbyCards.count == 2)
        #expect(stateObject["hiddenEntityCount"] == .integer(1))

        let cards = nearbyCards.compactMap { value -> Object? in
            guard case let .object(object) = value else { return nil }
            return object
        }
        let byTitle = Dictionary(uniqueKeysWithValues: cards.compactMap { card -> (String, Object)? in
            guard let title = bindingTestValueString(card["title"]) else { return nil }
            return (title, card)
        })

        #expect(byTitle["Low Signal"] == nil)

        #expect(bindingTestValueString(byTitle["Right Match"]?["detail"])?.contains("1.2 m") == true)
        #expect(bindingTestValueString(byTitle["Right Match"]?["detail"])?.contains("Høyre") == true)
        #expect(bindingTestValueString(byTitle["Right Match"]?["relevanceBadge"]) == "LOVENDE MATCH")

        #expect(bindingTestValueString(byTitle["Close Strong Match"]?["detail"])?.contains("0.8 m") == true)
        #expect(bindingTestValueString(byTitle["Close Strong Match"]?["detail"])?.contains("Foran") == true)
        #expect(bindingTestValueString(byTitle["Close Strong Match"]?["relevanceBadge"]) == "LOVENDE MATCH")

        guard case let .object(radarLayout)? = stateObject["radarLayout"],
              case let .object(surface)? = radarLayout["surface"],
              case let .object(ahead)? = radarLayout["ahead"],
              case let .object(right)? = radarLayout["right"],
              case let .object(uncertain)? = radarLayout["uncertain"] else {
            Issue.record("Expected directional radar layout nodes")
            return
        }
        #expect(surface["kind"] == .string("conference-nearby-radar-surface"))
        #expect(surface["coordinateSpace"] == .string("device-relative"))
        #expect(surface["preciseCount"] == .integer(2))
        #expect(surface["approximateCount"] == .integer(0))
        #expect(bindingTestValueString(ahead["subtitle"]) == "1 peer(s)")
        #expect(bindingTestValueString(right["subtitle"]) == "1 peer(s)")
        #expect(bindingTestValueString(uncertain["subtitle"]) == "0 peer(s)")

        let preciseSurfaceNodes = bindingTestValueObjects(surface["preciseNodes"])
        let rightSurfaceNode = preciseSurfaceNodes.first { bindingTestValueString($0["remoteUUID"]) == "nearby-variable-002" }
        let aheadSurfaceNode = preciseSurfaceNodes.first { bindingTestValueString($0["remoteUUID"]) == "nearby-variable-003" }
        #expect((bindingTestValueDouble(rightSurfaceNode?["xNormalized"]) ?? 0.0) > 0.1)
        #expect(abs(bindingTestValueDouble(rightSurfaceNode?["yNormalized"]) ?? 1.0) < 0.001)
        #expect(abs(bindingTestValueDouble(aheadSurfaceNode?["xNormalized"]) ?? 1.0) < 0.001)
        #expect((bindingTestValueDouble(aheadSurfaceNode?["yNormalized"]) ?? 0.0) > 0.1)

        _ = try await radar.set(
            keypath: "toggleLowerMatches",
            value: .bool(true),
            requester: identity
        )

        let expandedStateValue = try await radar.get(keypath: "state", requester: identity)
        guard case let .object(expandedStateObject) = expandedStateValue,
              case let .list(expandedNearbyCards)? = expandedStateObject["nearby"],
              case let .object(expandedRadarLayout)? = expandedStateObject["radarLayout"],
              case let .object(expandedSurface)? = expandedRadarLayout["surface"] else {
            Issue.record("Expected expanded nearby list after showing lower matches")
            return
        }

        #expect(expandedStateObject["showingLowerMatches"] == .bool(true))
        #expect(expandedNearbyCards.count == 3)
        #expect(expandedSurface["preciseCount"] == .integer(2))
        #expect(expandedSurface["approximateCount"] == .integer(1))

        let approximateSurfaceNodes = bindingTestValueObjects(expandedSurface["approximateNodes"])
        let lowSignalSurfaceNode = approximateSurfaceNodes.first { bindingTestValueString($0["remoteUUID"]) == "nearby-variable-001" }
        #expect(lowSignalSurfaceNode?["positionPrecision"] == .string("approximate"))
        #expect(lowSignalSurfaceNode?["xNormalized"] == .null)
        #expect(lowSignalSurfaceNode?["yNormalized"] == .null)
        #expect(bindingTestValueString(lowSignalSurfaceNode?["uncertaintySummary"])?.contains("Ingen live retning") == true)

        let decodedSurfaceSnapshot = ConferenceNearbyRadarSurfaceSnapshot(value: expandedStateValue)
        #expect(decodedSurfaceSnapshot.preciseNodes.count == 2)
        #expect(decodedSurfaceSnapshot.approximateNodes.count == 1)
        #expect(decodedSurfaceSnapshot.approximateNodes.first?.hasPrecisePosition == false)
    }

    @Test func portholeRoutesNearbyRadarDispatchActionForConferenceParticipantPortal() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await makeIsolatedRuntimeIdentity("porthole-nearby-radar-dispatch")
        await BindingLaunchWarmup.preloadLocalRuntime()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after launch warmup")
            return
        }
        guard let porthole = try await resolver.cellAtEndpoint(
            endpoint: "cell:///Porthole",
            requester: owner
        ) as? OrchestratorCell else {
            Issue.record("Could not resolve Porthole")
            return
        }

        porthole.detachAll(requester: owner)

        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )
        try await porthole.loadCellConfiguration(configuration, requester: owner)

        let beforeSummary = try await porthole.get(
            keypath: "nearbyRadar.state.actionSummary",
            requester: owner
        )
        guard case let .string(beforeSummaryText) = beforeSummary else {
            Issue.record("Expected string action summary before dispatch through Porthole")
            return
        }
        #expect(
            beforeSummaryText.contains("Nearby-radaren") ||
                beforeSummaryText.contains("Scanner")
        )

        let response = try await porthole.set(
            keypath: "nearbyRadar.dispatchAction",
            value: .object([
                "keypath": .string("start"),
                "payload": .bool(true)
            ]),
            requester: owner
        )

        guard case let .object(snapshot) = response else {
            Issue.record("Expected snapshot object from Porthole nearbyRadar.dispatchAction, got \(response)")
            return
        }

        #expect(snapshot["summary"] != nil)
        guard case let .string(snapshotActionSummary)? = snapshot["actionSummary"] else {
            Issue.record("Expected string actionSummary in nearby radar snapshot")
            return
        }
        let normalizedActionSummary = snapshotActionSummary.lowercased()
        #expect(
            normalizedActionSummary.contains("scanner") &&
                (
                    normalizedActionSummary.contains("starter") ||
                    normalizedActionSummary.contains("start") ||
                    normalizedActionSummary.contains("kjører")
                )
        )

        let afterSummary = try await porthole.get(
            keypath: "nearbyRadar.state.actionSummary",
            requester: owner
        )
        guard case let .string(afterSummaryText) = afterSummary else {
            Issue.record("Expected string action summary after dispatch through Porthole")
            return
        }
        #expect(afterSummaryText.isEmpty == false)
    }

    @Test func conferenceNearbyFollowUpSupportBuildsDiscoveryPayloadFromVerifiedEncounter() {
        let encounter: Object = [
            "remoteIdentityUUID": .string("identity-remote-123"),
            "remoteDisplayName": .string("Nora Berg"),
            "remotePerspective": .object([
                "identityProfile": .object([
                    "state": .object([
                        "participantId": .string("participant-102"),
                        "name": .string("Nora Berg"),
                        "company": .string("Polar Systems"),
                        "role": .string("speaker")
                    ])
                ])
            ])
        ]

        let target = ConferenceNearbyFollowUpSupport.target(
            from: encounter,
            fallbackRemoteUUID: "remote-session-abc",
            fallbackDisplayName: "Fallback Name"
        )

        #expect(target.remoteUUID == "remote-session-abc")
        #expect(target.participantId == "participant-102")
        #expect(target.identityUUID == "identity-remote-123")
        #expect(target.displayName == "Nora Berg")
        #expect(target.company == "Polar Systems")
        #expect(target.role == "speaker")

        let payload = ConferenceNearbyFollowUpSupport.discoveryPayload(for: target, source: "nearby-verified-contact")

        #expect(payload["source"] == .string("nearby-verified-contact"))
        #expect(payload["displayName"] == .string("Nora Berg"))
        #expect(payload["company"] == .string("Polar Systems"))
        #expect(payload["role"] == .string("speaker"))

        guard case let .list(participantIds)? = payload["participantIds"] else {
            Issue.record("Expected participantIds in discovery payload")
            return
        }
        #expect(participantIds == [.string("participant-102")])

        guard case let .list(identityUUIDs)? = payload["identityUUIDs"] else {
            Issue.record("Expected identityUUIDs in discovery payload")
            return
        }
        #expect(identityUUIDs == [.string("identity-remote-123")])

        guard case let .list(targets)? = payload["targets"],
              case let .object(firstTarget)? = targets.first else {
            Issue.record("Expected targets in discovery payload")
            return
        }
        #expect(firstTarget["participantId"] == .string("participant-102"))
        #expect(firstTarget["displayName"] == .string("Nora Berg"))
        #expect(firstTarget["company"] == .string("Polar Systems"))
        #expect(firstTarget["role"] == .string("speaker"))
        #expect(firstTarget["identityUUID"] == .string("identity-remote-123"))
    }

    @Test func conferenceParticipantPreviewFallbackSupportsNearbyDiscoveryChat() async throws {
        let identity = await makeIsolatedRuntimeIdentity("conference-preview-nearby-chat")
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after app initialization")
            return
        }
        guard let preview = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantPreviewShell did not resolve as Meddle")
            return
        }

        let dispatchPayload: Object = [
            "keypath": .string("discovery.startChat"),
            "payload": .object([
                "source": .string("nearby-verified-contact"),
                "participantIds": .list([.string("participant-102")]),
                "targets": .list([
                    .object([
                        "participantId": .string("participant-102"),
                        "displayName": .string("Nora Berg"),
                        "company": .string("Polar Systems"),
                        "role": .string("speaker")
                    ])
                ])
            ])
        ]

        _ = try await preview.set(keypath: "dispatchAction", value: .object(dispatchPayload), requester: identity)
        let stateValue = try await preview.get(keypath: "state", requester: identity)
        guard case let .object(stateObject) = stateValue,
              case let .object(workspace)? = stateObject["workspace"],
              case let .object(sharedConnections)? = stateObject["sharedConnections"] else {
            Issue.record("Expected state object from conference participant preview fallback")
            return
        }

        #expect(workspace["nextStep"] == .string("Started follow-up chat with Nora Berg in local preview."))
        #expect(sharedConnections["chatSummary"] == .string("2 shared message(s) visible."))

        guard case let .list(connections)? = sharedConnections["connections"] else {
            Issue.record("Expected shared connections list")
            return
        }
        #expect(connections.count == 1)

        guard case let .list(recentMessages)? = sharedConnections["recentMessages"],
              case let .object(firstMessage)? = recentMessages.first else {
            Issue.record("Expected recent messages list")
            return
        }
        #expect(firstMessage["detail"] == .string("Ja, gjerne. Jobber med tillit, relasjoner og hvordan identitet og oppfølging kan flyte mellom team. Hvis du vil, kan vi ta et kort neste steg etter sesjonen."))
    }

    @Test func conferenceParticipantPreviewFallbackSupportsRecommendationFocusAndFollowUpActions() async throws {
        let identity = await makeIsolatedRuntimeIdentity("conference-preview-recommendation-actions")
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after app initialization")
            return
        }
        guard let preview = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantPreviewShell did not resolve as Meddle")
            return
        }

        _ = try await preview.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("agenda.setView"),
                "payload": .object([
                    "view": .string("timeline")
                ])
            ]),
            requester: identity
        )

        _ = try await preview.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("agenda.setTrackFocus"),
                "payload": .object([
                    "trackId": .string("track-governance")
                ])
            ]),
            requester: identity
        )

        _ = try await preview.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("matchmaking.focusPerson"),
                "payload": .object([
                    "displayName": .string("Ane Solberg"),
                    "subtitle": .string("Public sector interoperability")
                ])
            ]),
            requester: identity
        )

        _ = try await preview.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("matchmaking.toggleFollowUp"),
                "payload": .object([
                    "displayName": .string("Governance Forum"),
                    "subtitle": .string("Nearby people")
                ])
            ]),
            requester: identity
        )

        let stateValue = try await preview.get(keypath: "state", requester: identity)
        guard case let .object(stateObject) = stateValue,
              case let .object(workspace)? = stateObject["workspace"],
              case let .object(program)? = stateObject["program"],
              case let .object(matches)? = stateObject["matches"] else {
            Issue.record("Expected state object from conference participant preview fallback")
            return
        }

        #expect(workspace["nextStep"] == .string("Marked Governance Forum for follow-up in local preview."))
        #expect(program["viewSummary"] == .string("Current view: Timeline."))
        #expect(program["trackSummary"] == .string("Track focus: Governance."))
        #expect(program["timelineSummary"] == .string("8 session(s) visible in timeline view."))
        #expect(matches["recommendationSummary"] == .string("Focused recommendation: Ane Solberg. Open chat or mark follow-up when you are ready."))
        #expect(matches["status"] == .string("Focused on Ane Solberg. The next natural step is to start chat or mark follow-up."))
        #expect(matches["searchSummary"] == .string("Search broadening: people. 1 person(s) marked for follow-up."))

        guard case let .list(recommendations)? = matches["recommendations"],
              case let .object(firstRecommendation)? = recommendations.first else {
            Issue.record("Expected recommendations list in preview fallback state")
            return
        }
        #expect(firstRecommendation["label"] == .string("Start chat"))

        guard case let .list(searchResults)? = matches["searchResults"],
              case let .object(firstSearchResult)? = searchResults.first else {
            Issue.record("Expected search results list in preview fallback state")
            return
        }
        #expect(firstSearchResult["label"] == .string("Fjern markering"))
    }

    @Test func conferenceParticipantMatchmakingSnapshotSupportsInlineSelectionAndActions() async throws {
        let identity = await makeIsolatedRuntimeIdentity("conference-matchmaking-inline-actions")
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after app initialization")
            return
        }
        guard let snapshot = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantMatchmakingSnapshot",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConferenceParticipantMatchmakingSnapshot did not resolve as Meddle")
            return
        }

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("matchmaking.focusPerson"),
                "payload": .object([
                    "displayName": .string("Ane Solberg"),
                    "subtitle": .string("Public sector interoperability")
                ])
            ]),
            requester: identity
        )

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("matchmaking.toggleFollowUp"),
                "payload": .object([
                    "displayName": .string("Ane Solberg"),
                    "subtitle": .string("Public sector interoperability")
                ])
            ]),
            requester: identity
        )

        _ = try await snapshot.set(
            keypath: "dispatchAction",
            value: .object([
                "keypath": .string("discovery.startChat"),
                "payload": .object([
                    "source": .string("binding-test"),
                    "targets": .list([
                        .object([
                            "displayName": .string("Ane Solberg"),
                            "headline": .string("Public sector interoperability")
                        ])
                    ])
                ])
            ]),
            requester: identity
        )

        let stateValue = try await snapshot.get(keypath: "state", requester: identity)
        guard case let .object(object) = stateValue,
              case let .object(focusedProfile)? = object["focusedProfile"],
              case let .list(focusedActions)? = object["focusedActions"],
              case let .list(recommendations)? = object["recommendations"],
              case let .object(firstRecommendation)? = recommendations.first else {
            Issue.record("Expected matchmaking snapshot state with focused profile and actions")
            return
        }

        #expect(object["selectionSummary"] == .string("Viser Ane Solberg i denne siden."))
        #expect(focusedProfile["title"] == .string("Ane Solberg"))
        #expect(focusedProfile["publicProfileSummary"] == .string("Offentlig profil: Public sector interoperability."))
        #expect(focusedProfile["nextStep"] == .string("Åpne chatflaten eller be om møte med Ane Solberg."))
        #expect(firstRecommendation["label"] == .string("Valgt i siden"))

        guard case let .object(chatAction)? = focusedActions.first,
              case let .object(followUpAction)? = focusedActions.dropFirst().first,
              case let .object(meetingAction)? = focusedActions.dropFirst(2).first else {
            Issue.record("Expected three focused actions in matchmaking snapshot")
            return
        }

        #expect(chatAction["label"] == .string("Åpne chatflate"))
        #expect(followUpAction["label"] == .string("Fjern markering"))
        #expect(meetingAction["label"] == .string("Be om møte"))
    }

    @Test func conferenceParticipantPortalDashboardIsWrappedInScrollView() {
        var configuration = CellConfiguration(name: "Conference Participant Portal Dashboard")
        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(text: "Hero"))
        ]))

        let adjusted = ConfigurationPresentationSupport.viewportSafeConfiguration(configuration)

        guard case let .ScrollView(scroll)? = adjusted.skeleton else {
            Issue.record("Forventet ScrollView-wrapper for conference dashboard")
            return
        }

        #expect(scroll.axis == "vertical")
        #expect(scroll.elements.count == 1)
    }

    @Test func unrelatedConfigurationsKeepOriginalSkeletonShape() {
        var configuration = CellConfiguration(name: "Standalone Surface")
        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(text: "Standalone"))
        ]))

        let adjusted = ConfigurationPresentationSupport.viewportSafeConfiguration(configuration)

        guard case .VStack? = adjusted.skeleton else {
            Issue.record("Urelatert konfigurasjon skulle ikke blitt scroll-wrappet")
            return
        }
    }

    @Test func appleIntelligencePurposeMatcherUsesRichSelectableListForSuggestionSelection() {
        let configuration = ConfigurationCatalogCell.appleIntelligenceLandingConfiguration()

        guard let skeleton = configuration.skeleton else {
            Issue.record("Forventet skeleton for Apple Intelligence Purpose Matcher")
            return
        }

        #expect(skeletonContainsSelectableList(
            keypath: "catalog.matching.suggestions",
            topic: nil,
            selectionStateKeypath: "catalog.matching.selectedIndex",
            selectionActionKeypath: "catalog.matching.selectIndex",
            selectionValueKeypath: "rank",
            activationActionKeypath: "catalog.matching.loadSelectedToPorthole",
            in: skeleton
        ))
        #expect(!skeletonContainsTextField(targetKeypath: "catalog.matching.selectedIndex", in: skeleton))
        #expect(skeletonContainsTextField(targetKeypath: "catalog.matching.runPromptInput", in: skeleton))
        #expect(skeletonContainsButtonWithNilPayload(keypath: "catalog.matching.runPromptInput", in: skeleton))
    }

    @Test func personalCopilotAppleIntelligenceMatcherRunsLocallyFromTypedIntent() async throws {
        let configuration = ConfigurationCatalogCell.appleIntelligenceLandingForPersonalCopilotConfiguration()
        #expect(configuration.discovery?.sourceCellEndpoint == "cell:///ConfigurationCatalog")
        #expect(configuration.discovery?.sourceCellName == "ConfigurationCatalogCell")
        #expect(configuration.cellReferences?.contains(where: {
            $0.endpoint == "cell:///ConfigurationCatalog" && $0.label == "catalog"
        }) == true)

        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)
        let response = try await cell.set(
            keypath: "matching.runPromptInput",
            value: .string("Finn CellConfiguration som kan hjelpe brukeren aa oppfylle en moteintensjon"),
            requester: owner
        )

        guard case let .integer(count)? = response else {
            Issue.record("Expected integer suggestion count from matching.runPromptInput")
            return
        }
        #expect(count > 0)

        let suggestions = try await cell.get(keypath: "matching.suggestions", requester: owner)
        guard case let .list(items) = suggestions else {
            Issue.record("Expected matching.suggestions list")
            return
        }
        #expect(!items.isEmpty)
        #expect(items.contains { item in
            guard case let .object(object) = item,
                  case let .string(name)? = object["name"] else {
                return false
            }
            return name == "Meeting Intent" || name == "Apple Intelligence Purpose Matcher"
        })
    }

    @MainActor
    @Test func deletingComponentPrunesNewlyUnusedReferences() {
        var configuration = CellConfiguration(name: "Delete Chat Component")
        configuration.addReference(CellReference(endpoint: "cell:///Chat", label: "chat"))
        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(text: "Header")),
            .VStack(SkeletonVStack(elements: [
                .Text(SkeletonText(keypath: "chat.status"))
            ]))
        ]))

        let editorState = EditorState()
        editorState.beginEditing(configuration: configuration)
        editorState.deleteNode(at: .root.appending(1))

        let references = editorState.workingConfiguration?.cellReferences ?? []
        #expect(references.isEmpty)

        guard let workingSkeleton = editorState.workingCopy else {
            Issue.record("Forventet skeleton etter delete")
            return
        }

        #expect(!skeletonContainsTextKeypath("chat.status", in: workingSkeleton))
    }

    @MainActor
    @Test func editorStateRetainsSourceBackedRevisionMetadataAcrossApply() {
        var configuration = CellConfiguration(name: "Source-backed Editor")
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: "cell:///ConferenceAdminShell",
            sourceCellName: "ConferenceAdminShellCell",
            purpose: "Conference admin editing",
            purposeDescription: "Editable shell",
            interests: ["conference", "admin"],
            menuSlots: ["upperMid"]
        )
        configuration.skeleton = .Text(SkeletonText(text: "Original"))

        let sourceContext = EditorSourceBackedContext(
            committedSourceRevision: 7,
            canEdit: true,
            sourceCellEndpoint: "cell:///ConferenceAdminShell",
            sourceCellName: "ConferenceAdminShellCell",
            accessSummary: "Organizer requester can edit."
        )

        let editorState = EditorState()
        editorState.beginEditing(configuration: configuration, sourceBackedContext: sourceContext)

        #expect(editorState.currentSourceBackedContext?.committedSourceRevision == 7)
        #expect(editorState.currentSourceBackedContext?.canEdit == true)

        editorState.replaceWorkingCopy(with: .Text(SkeletonText(text: "Updated")), recordUndo: false)

        #expect(editorState.isDirty)

        _ = editorState.commitDocumentChanges()

        #expect(editorState.isDirty == false)
        #expect(editorState.viewerConfiguration?.name == "Source-backed Editor")
        #expect(editorState.currentSourceBackedContext?.sourceCellEndpoint == "cell:///ConferenceAdminShell")
        #expect(editorState.currentSourceBackedContext?.committedSourceRevision == 7)
    }

    @MainActor
    @Test func editorStateKeepsDirtyDraftWhenSourceBackedRevisionChanges() {
        var configuration = CellConfiguration(name: "Source-backed Editor")
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: "cell:///ConferenceAdminShell",
            sourceCellName: "ConferenceAdminShellCell",
            purpose: "Conference admin editing",
            purposeDescription: "Editable shell",
            interests: ["conference", "admin"],
            menuSlots: ["upperMid"]
        )
        configuration.skeleton = .Text(SkeletonText(text: "Original"))

        let sourceContext = EditorSourceBackedContext(
            committedSourceRevision: 7,
            canEdit: true,
            sourceCellEndpoint: "cell:///ConferenceAdminShell",
            sourceCellName: "ConferenceAdminShellCell",
            accessSummary: "Organizer requester can edit."
        )

        let editorState = EditorState()
        editorState.beginEditing(configuration: configuration, sourceBackedContext: sourceContext)
        editorState.replaceWorkingCopy(with: .Text(SkeletonText(text: "Local draft")), recordUndo: false)

        var refreshedConfiguration = configuration
        refreshedConfiguration.skeleton = .Text(SkeletonText(text: "Source revision 8"))
        let refreshedContext = EditorSourceBackedContext(
            committedSourceRevision: 8,
            canEdit: true,
            sourceCellEndpoint: "cell:///ConferenceAdminShell",
            sourceCellName: "ConferenceAdminShellCell",
            accessSummary: "Organizer requester can edit."
        )

        editorState.beginEditing(configuration: refreshedConfiguration, sourceBackedContext: refreshedContext)

        guard case let .Text(workingText)? = editorState.workingCopy,
              case let .Text(viewerText)? = editorState.viewerSnapshot else {
            Issue.record("Expected text skeletons after source-backed refresh.")
            return
        }

        #expect(workingText.text == "Local draft")
        #expect(viewerText.text == "Source revision 8")
        #expect(editorState.isDirty)
        #expect(editorState.sourceBackedChangeNotice?.contains("Original CellConfiguration er endret") == true)

        editorState.discardChanges()

        guard case let .Text(discardedText)? = editorState.workingCopy else {
            Issue.record("Expected source snapshot after discarding local draft.")
            return
        }

        #expect(discardedText.text == "Source revision 8")
        #expect(editorState.sourceBackedChangeNotice == nil)
    }

    @Test func configurationCatalogSeedsRichLibrary() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        _ = try await cell.set(keypath: "syncScaffoldPurposeGoals", value: .null, requester: owner)
        let configurations = try await cell.get(keypath: "configurations", requester: owner)
        guard case let .list(items) = configurations else {
            Issue.record("Forventet liste fra configurations")
            return
        }

        #expect(items.count >= 12)
    }

    @Test func configurationCatalogExposesSafeButterpopStudioLauncher() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        let configurations = try await cell.get(keypath: "configurations", requester: owner)
        guard case let .list(items) = configurations,
              let butterpop = items.compactMap({ value -> CellConfiguration? in
                  guard case let .cellConfiguration(configuration) = value,
                        configuration.name == "Butterpop Studio" else { return nil }
                  return configuration
              }).first,
              let skeleton = butterpop.skeleton
        else {
            Issue.record("Forventet Butterpop Studio i HAVEN-katalogen")
            return
        }

        func collectButtons(_ element: SkeletonElement) -> [SkeletonButton] {
            switch element {
            case .Button(let button): return [button]
            case .VStack(let stack): return stack.elements.flatMap(collectButtons)
            case .HStack(let stack): return stack.elements.flatMap(collectButtons)
            case .ScrollView(let scroll): return scroll.elements.flatMap(collectButtons)
            case .Section(let section):
                return (section.header.map(collectButtons) ?? [])
                    + section.content.flatMap(collectButtons)
                    + (section.footer.map(collectButtons) ?? [])
            case .Grid(let grid): return grid.elements.flatMap(collectButtons)
            case .ZStack(let stack): return stack.elements.flatMap(collectButtons)
            case .Object(let object): return object.elements.values.flatMap(collectButtons)
            case .Tabs(let tabs): return tabs.panels.flatMap { $0.content.flatMap(collectButtons) }
            case .Reference(let reference):
                return reference.flowElementSkeleton?.elements.flatMap(collectButtons) ?? []
            default: return []
            }
        }

        let buttons = collectButtons(skeleton)
        let launcher = try #require(buttons.first { $0.label == "Åpne Butterpop Studio" })
        let validation = await CellConfigurationValidationService.validate(butterpop)
        let validationErrorCount = await MainActor.run { validation.errorCount }
        #expect(butterpop.cellReferences?.isEmpty != false)
        #expect(validationErrorCount == 0)
        #expect(SkeletonButtonNavigation.isNavigationButton(launcher))
        #expect(
            SkeletonButtonNavigation.resolveURL(
                for: launcher,
                relativeTo: URL(string: "http://127.0.0.1:9097")
            )?.absoluteString == "http://127.0.0.1:9097/butterpop"
        )
    }

    @Test func configurationCatalogExposesAgentSetupWorkbench() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        let configurations = try await cell.get(keypath: "configurations", requester: owner)
        guard case let .list(items) = configurations else {
            Issue.record("Forventet liste fra configurations")
            return
        }

        let configurationNames = items.compactMap { value -> String? in
            guard case let .cellConfiguration(configuration) = value else { return nil }
            return configuration.name
        }

        #expect(configurationNames.contains("Agent Setup Workbench") == false)
        #expect(configurationNames.contains("Network Sentinel") == false)
    }

    @Test func configurationCatalogExposesAgentSetupWorkbenchWhenOptedIn() async throws {
        UserDefaults.standard.set(true, forKey: BindingPersonalCopilotV1Policy.agentSetupWorkbenchDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: BindingPersonalCopilotV1Policy.agentSetupWorkbenchDefaultsKey) }

        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        let configurations = try await cell.get(keypath: "configurations", requester: owner)
        guard case let .list(items) = configurations else {
            Issue.record("Forventet liste fra configurations")
            return
        }

        let configurationNames = items.compactMap { value -> String? in
            guard case let .cellConfiguration(configuration) = value else { return nil }
            return configuration.name
        }

        #expect(configurationNames.contains("Agent Setup Workbench"))
        #expect(configurationNames.contains("Network Sentinel"))
    }

    @Test func networkSentinelConfigurationRetargetsToLocalControlBridge() throws {
        func expectLocalNetworkSentinelBridgeEndpoint(_ endpoint: String) {
            guard let components = URLComponents(string: endpoint) else {
                Issue.record("Expected valid endpoint URL, got \(endpoint)")
                return
            }

            #expect(components.scheme == "ws")
            #expect(components.host == "127.0.0.1")
            #expect(components.port == 43110)
            #expect(components.path == "/bridgehead/network-sentinel")
            #expect(components.queryItems?.contains { $0.name == "token" && $0.value == "test token" } == true)
        }

        func collectButtons(in element: SkeletonElement) -> [SkeletonButton] {
            switch element {
            case .Button(let button):
                return [button]
            case .VStack(let stack):
                return stack.elements.flatMap(collectButtons)
            case .HStack(let stack):
                return stack.elements.flatMap(collectButtons)
            case .ScrollView(let scroll):
                return scroll.elements.flatMap(collectButtons)
            case .Section(let section):
                return (section.header.map(collectButtons) ?? []) +
                    section.content.flatMap(collectButtons) +
                    (section.footer.map(collectButtons) ?? [])
            case .Reference(let reference):
                return reference.flowElementSkeleton?.elements.flatMap(collectButtons) ?? []
            case .Grid(let grid):
                return grid.elements.flatMap(collectButtons)
            case .ZStack(let stack):
                return stack.elements.flatMap(collectButtons)
            case .Object(let object):
                return object.elements.values.flatMap(collectButtons)
            case .Tabs(let tabs):
                return tabs.panels.flatMap { $0.content.flatMap(collectButtons) }
            default:
                return []
            }
        }

        let configuration = ConfigurationCatalogCell.networkSentinelWorkbenchConfiguration()
        let configJSON: [String: Any] = [
            "localControlBridge": [
                "enabled": true,
                "host": "127.0.0.1",
                "port": 43110,
                "accessToken": "test token",
                "routes": [
                    [
                        "name": "network-sentinel",
                        "targetCellReference": "agent/network/sentinel"
                    ]
                ]
            ]
        ]

        let rewritten = CellConfigurationEndpointRetargeting.rewritingLocalAgentBridgeEndpoints(
            in: configuration,
            configJSON: configJSON
        )

        let directLoopbackEndpoint = try #require(AgentLocalControlBridgeEndpointSupport.rewriteEndpoint(
            "cell://127.0.0.1/agent/network/sentinel",
            configJSON: configJSON
        ))
        expectLocalNetworkSentinelBridgeEndpoint(directLoopbackEndpoint)

        let referenceEndpoint = try #require(rewritten.cellReferences?.first?.endpoint)
        expectLocalNetworkSentinelBridgeEndpoint(referenceEndpoint)

        let skeleton = try #require(rewritten.skeleton)
        let buttons = collectButtons(in: skeleton)
        let actionKeypaths = Set(buttons.map(\.keypath))
        #expect(actionKeypaths.isSuperset(of: ["acknowledge", "probe", "captureNow", "runListen"]))

        let actionButtons = buttons.filter { ["acknowledge", "probe", "captureNow", "runListen"].contains($0.keypath) }
        #expect(actionButtons.isEmpty == false)
        for button in actionButtons {
            expectLocalNetworkSentinelBridgeEndpoint(try #require(button.url))
            #expect(button.payload != nil)
        }
    }

    @Test func remoteOwnerPublishedConfigurationCannotSelectLocalControlPlane() {
        let forbiddenEndpoints = [
            "cell:///agent/network/sentinel",
            "cell://localhost/ConfigurationCatalog",
            "cell://localhost./agent/network/sentinel",
            "cell://127.0.0.1/agent/network/sentinel",
            "ws://127.0.0.2:43110/bridgehead/network-sentinel",
            "ws://127.1:43110/bridgehead/network-sentinel",
            "ws://2130706433:43110/bridgehead/network-sentinel",
            "ws://0x7f000001:43110/bridgehead/network-sentinel",
            "ws://017700000001:43110/bridgehead/network-sentinel",
            "ws://0x7f.0.0.1:43110/bridgehead/network-sentinel",
            "ws://0x7f.1:43110/bridgehead/network-sentinel",
            "ws://127.0x0.0x0.0x1:43110/bridgehead/network-sentinel",
            "ws://127.0.0.0x1:43110/bridgehead/network-sentinel",
            "ws://127.0x1:43110/bridgehead/network-sentinel",
            "ws://127.0x000001:43110/bridgehead/network-sentinel",
            "ws://0.0.0.0:43110/bridgehead/network-sentinel",
            "ws://0.0.0.1:43110/bridgehead/network-sentinel",
            "ws://127.0.0.1:43110/bridgehead/network-sentinel?token=secret",
            "wss://[::1]/bridgehead/network-sentinel",
            "wss://[0::1]/bridgehead/network-sentinel",
            "wss://[0000::0001]/bridgehead/network-sentinel",
            "wss://[0:0:0:0:0:0:0:01]/bridgehead/network-sentinel",
            "wss://[0:0:0:0:0:0:0:0001]/bridgehead/network-sentinel",
            "wss://[::1%25lo0]/bridgehead/network-sentinel",
            "wss://[0::1%25lo0]/bridgehead/network-sentinel",
            "wss://[::ffff:127.0.0.1%25lo0]/bridgehead/network-sentinel",
            "wss://[::ffff:127.0.0.1]/bridgehead/network-sentinel",
            "wss://[::ffff:7f00:1]/bridgehead/network-sentinel"
        ]

        for endpoint in forbiddenEndpoints {
            var configuration = CellConfiguration(name: "Untrusted remote")
            configuration.addReference(CellReference(endpoint: endpoint, label: "remote"))
            #expect(
                !CellConfigurationEndpointRetargeting.isSafeForRemoteOwnerPublication(configuration),
                "Expected remote publication to reject \(endpoint)"
            )
            #expect(!CellConfigurationEndpointRetargeting.isAllowedByHostTrustBoundary(
                configuration,
                mayUseLocalControlPlane: false
            ))
            #expect(CellConfigurationEndpointRetargeting.isAllowedByHostTrustBoundary(
                configuration,
                mayUseLocalControlPlane: true
            ))
        }

        var skeletonConfiguration = CellConfiguration(name: "Untrusted remote skeleton")
        skeletonConfiguration.skeleton = .Button(
            SkeletonButton(
                keypath: "probe",
                label: "Probe",
                url: "ws://localhost:43110/bridgehead/network-sentinel?token=secret"
            )
        )
        #expect(
            !CellConfigurationEndpointRetargeting.isSafeForRemoteOwnerPublication(
                skeletonConfiguration
            )
        )

        var safeRemote = CellConfiguration(name: "Safe owner publication")
        safeRemote.addReference(
            CellReference(endpoint: "cell:///ConferencePublicShell", label: "public")
        )
        #expect(CellConfigurationEndpointRetargeting.isSafeForRemoteOwnerPublication(safeRemote))

        var hostileImport = CellConfiguration(name: "Ambient local deputy")
        var provisioningReference = CellReference(
            endpoint: "cell:///AgentProvisioning",
            label: "local provisioning"
        )
        provisioningReference.setKeysAndValues = [
            KeyValue(key: "provision", value: .object(["enabled": .bool(true)]))
        ]
        hostileImport.addReference(provisioningReference)
        #expect(CellConfigurationEndpointRetargeting.isSafeForRemoteOwnerPublication(hostileImport))
        #expect(!CellConfigurationEndpointRetargeting.isSafeForUntrustedImport(hostileImport))

        var explicitRemoteImport = hostileImport
        explicitRemoteImport.cellReferences?[0].endpoint = "cell://publisher.example/AgentProvisioning"
        #expect(CellConfigurationEndpointRetargeting.isSafeForUntrustedImport(explicitRemoteImport))
    }

    @Test func externalViewConfigurationRejectsInitializerWritesAndTargets() {
        var readOnly = CellConfiguration(name: "Read only")
        var readReference = CellReference(endpoint: "cell://publisher.example/Public", label: "public")
        readReference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        readOnly.addReference(readReference)
        #expect(CellConfigurationEndpointRetargeting.isSideEffectFreeForExternalView(readOnly))

        var initializerWrite = readOnly
        initializerWrite.cellReferences?[0].setKeysAndValues = [
            KeyValue(key: "refresh", value: .object([:]))
        ]
        #expect(!CellConfigurationEndpointRetargeting.isSideEffectFreeForExternalView(initializerWrite))

        var crossTarget = readOnly
        crossTarget.cellReferences?[0].setKeysAndValues = [
            KeyValue(key: "state", value: nil, target: "cell://publisher.example/Other")
        ]
        #expect(!CellConfigurationEndpointRetargeting.isSideEffectFreeForExternalView(crossTarget))
    }

    @Test func runtimeCredentialsAreRedactedOrConvertedBeforeExternalization() throws {
        let credentialed = "ws://user:password@127.0.0.1:43110/bridgehead/network-sentinel?token=secret&mode=read"
        let httpsCredentialed = "https://web-user:web-password@publisher.example/open?token=https-secret&mode=read"
        let redacted = CellConfigurationEndpointRetargeting.redactedEndpointForDisplay(credentialed)
        #expect(!redacted.contains("user"))
        #expect(!redacted.contains("password"))
        #expect(!redacted.contains("secret"))
        #expect(redacted.contains("mode=read"))
        let redactedHTTPS = CellConfigurationEndpointRetargeting.redactedEndpointForDisplay(
            httpsCredentialed
        )
        #expect(!redactedHTTPS.contains("web-user"))
        #expect(!redactedHTTPS.contains("web-password"))
        #expect(!redactedHTTPS.contains("https-secret"))
        #expect(redactedHTTPS.contains("mode=read"))
        let errorText = CellConfigurationEndpointRetargeting.redactedTextForDisplay(
            "connect failed at \(credentialed) token=second-secret "
                + "Authorization: Bearer bearer-secret {\"token\":\"json-secret\"}"
        )
        #expect(!errorText.contains("password"))
        #expect(!errorText.contains("secret"))

        let configJSON: [String: Any] = [
            "localControlBridge": [
                "enabled": true,
                "host": "127.0.0.1",
                "port": 43110,
                "accessToken": "secret",
                "routes": [[
                    "name": "network-sentinel",
                    "targetCellReference": "agent/network/sentinel"
                ]]
            ]
        ]
        #expect(
            AgentLocalControlBridgeEndpointSupport.portableEndpoint(
                "ws://127.0.0.1:43110/bridgehead/network-sentinel?token=secret",
                configJSON: configJSON
            ) == "cell:///agent/network/sentinel"
        )

        var exportedConfiguration = CellConfiguration(name: "Export")
        exportedConfiguration.addReference(
            CellReference(endpoint: credentialed, label: "agent")
        )
        exportedConfiguration.skeleton = .Button(
            SkeletonButton(
                keypath: "open",
                label: "Open",
                url: httpsCredentialed
            )
        )
        exportedConfiguration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: httpsCredentialed,
            sourceCellName: "CredentialedHTTPS",
            purpose: "externalization",
            purposeDescription: "externalization",
            interests: [],
            menuSlots: []
        )
        let exported = FullLibraryView.exportConfiguration(exportedConfiguration)
        let exportedJSON = String(decoding: try JSONEncoder().encode(exported), as: UTF8.self)
        #expect(!exportedJSON.contains("password"))
        #expect(!exportedJSON.contains("secret"))
        #expect(exportedJSON.contains("mode=read"))
    }

    @Test @MainActor func diagnosticsAndValidationRedactCredentialBearingEndpointsAtTheSink() {
        let endpoint = "wss://user:password@publisher.example/catalog?token=secret&mode=read"
        let diagnostics = BindingRuntimeDiagnostics.shared
        diagnostics.clearLogs()
        diagnostics.record(
            severity: .warning,
            domain: "binding.probe",
            message: "Probe failed for \(endpoint)"
        )
        let recorded = diagnostics.entries.first?.message ?? ""
        #expect(!recorded.contains("user"))
        #expect(!recorded.contains("password"))
        #expect(!recorded.contains("secret"))
        #expect(recorded.contains("mode=read"))

        var configuration = CellConfiguration(name: "Credential-safe validation")
        configuration.skeleton = .Text(SkeletonText(text: "Preview"))
        configuration.addReference(
            CellReference(endpoint: "cell://publisher.example/Public", label: "public")
        )
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: endpoint,
            sourceCellName: "RemoteCatalog",
            purpose: "credential redaction",
            purposeDescription: "credential redaction",
            interests: [],
            menuSlots: []
        )
        let report = CellConfigurationValidationService.validate(configuration)
        let renderedDetails = report.issues.map(\.detail).joined(separator: " | ")
        #expect(!renderedDetails.contains("user"))
        #expect(!renderedDetails.contains("password"))
        #expect(!renderedDetails.contains("secret"))
        #expect(renderedDetails.contains("mode=read"))
    }

    @Test @MainActor func fullLibraryDistinguishesHostOwnedLocalResultsFromRemotePublisherResults() {
        let localOrigin = FullLibraryViewModel.resultOrigin(
            forCatalogEndpoint: "cell:///ConfigurationCatalog"
        )
        #expect(localOrigin == .hostTrusted)
        let localConfiguration = ConfigurationCatalogCell.conferenceCodexLiveConfigurationsMenuConfiguration()
        #expect(!CellConfigurationEndpointRetargeting.isSafeForUntrustedImport(localConfiguration))
        #expect(
            CellConfigurationEndpointRetargeting.isAllowedByHostTrustBoundary(
                localConfiguration,
                mayUseLocalControlPlane: localOrigin == .hostTrusted
            )
        )
        #expect(
            FullLibraryViewModel.resultOrigin(
                forCatalogEndpoint: "cell://publisher.example/ConfigurationCatalog?token=secret"
            ) == .catalog(endpoint: "cell://publisher.example/ConfigurationCatalog?token=secret")
        )
        let model = FullLibraryViewModel(
            catalogEndpoints: [],
            queryContext: FullLibraryQueryContext(
                editMode: false,
                selectedNodeKind: nil,
                insertionIntent: .unknown
            ),
            fallbackFavorites: [],
            fallbackTemplates: []
        )
        let presentedSource = model.displayFacetValue(
            key: "sourceRef",
            value: "https://user:password@publisher.example/Public?token=secret&mode=read"
        )
        #expect(!presentedSource.contains("password"))
        #expect(!presentedSource.contains("secret"))
        #expect(presentedSource.contains("mode=read"))
    }

    @Test func runtimeSelectedDemoStartRoundTripsConfigurationAndPublisherOriginWithoutCredentials() throws {
        var configuration = CellConfiguration(name: "Runtime-selected demo")
        configuration.addReference(
            CellReference(
                endpoint: "wss://user:password@publisher.example/Public?token=secret&mode=read",
                label: "public"
            )
        )
        let envelope = ContentView.storedDemoStartEnvelope(
            configuration: configuration,
            origin: .catalog(
                endpoint: "cell://publisher.example/ConfigurationCatalog?token=secret&mode=read"
            )
        )
        let data = try JSONEncoder().encode(envelope)
        let persistedText = String(decoding: data, as: UTF8.self)
        #expect(!persistedText.contains("password"))
        #expect(!persistedText.contains("secret"))

        let decoded = try JSONDecoder().decode(BindingStoredDemoStartEnvelope.self, from: data)
        #expect(decoded.version == BindingStoredDemoStartEnvelope.currentVersion)
        #expect(decoded.configuration.name == configuration.name)
        #expect(
            decoded.origin == .catalog(
                endpoint: "cell://publisher.example/ConfigurationCatalog?mode=read"
            )
        )
        #expect(decoded.configuration.cellReferences?.first?.endpoint == "wss://publisher.example/Public?mode=read")
    }

    @Test @MainActor func persistedDemoStartCannotForgeHostTrustedAuthority() {
        let compiledDefault = ContentView.defaultDemoStartConfiguration()
        let persisted = ContentView.storedDemoStartEnvelope(
            configuration: compiledDefault,
            origin: .hostTrusted
        )
        let roundTrip = try? JSONDecoder().decode(
            BindingStoredDemoStartEnvelope.self,
            from: JSONEncoder().encode(persisted)
        )
        let roundTrippedConfiguration = roundTrip?.configuration
        #expect(roundTrippedConfiguration != nil)
        let reconstructed = ContentView.reconstructedHostOwnedDemoStartConfiguration(
            matching: roundTrippedConfiguration ?? CellConfiguration(name: "invalid")
        )
        #expect(reconstructed != nil)
        if let reconstructed, let roundTrippedConfiguration {
            #expect(reconstructed.uuid != roundTrippedConfiguration.uuid)
        }

        var forgedDefault = compiledDefault
        var hostileReference = CellReference(
            endpoint: "cell:///AgentProvisioning",
            label: "provisioning"
        )
        hostileReference.setKeysAndValues = [
            KeyValue(key: "provision", value: .object(["enabled": .bool(true)]))
        ]
        forgedDefault.cellReferences = [hostileReference]
        #expect(
            ContentView.reconstructedHostOwnedDemoStartConfiguration(
                matching: forgedDefault
            ) == nil
        )
        #expect(!CellConfigurationEndpointRetargeting.isSafeForUntrustedImport(forgedDefault))
    }

    @Test func hostTrustFingerprintNormalizesOnlyGeneratedTabsIdentifier() {
        func tabsConfiguration(
            id: UUID = UUID(),
            tabsKeypath: String? = "state.tabs",
            activeTabStateKeypath: String = "state.activeTab",
            selectionActionKeypath: String? = "actions.selectTab",
            panelID: String = "overview",
            panelContent: SkeletonElementList = []
        ) -> CellConfiguration {
            var configuration = CellConfiguration(name: "tabs-fingerprint")
            configuration.skeleton = .Tabs(
                SkeletonTabs(
                    id: id,
                    tabsKeypath: tabsKeypath,
                    activeTabStateKeypath: activeTabStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    panels: [
                        SkeletonTabPanel(id: panelID, content: panelContent)
                    ]
                )
            )
            return configuration
        }

        let baseline = tabsConfiguration(id: UUID())
        let sameCompiledIntent = tabsConfiguration(id: UUID())
        #expect(ContentView.configurationsHaveEqualWireForm(baseline, sameCompiledIntent))
        #expect(
            !ContentView.configurationsHaveEqualWireForm(
                baseline,
                tabsConfiguration(tabsKeypath: "state.otherTabs")
            )
        )
        #expect(
            !ContentView.configurationsHaveEqualWireForm(
                baseline,
                tabsConfiguration(activeTabStateKeypath: "state.otherActiveTab")
            )
        )
        #expect(
            !ContentView.configurationsHaveEqualWireForm(
                baseline,
                tabsConfiguration(selectionActionKeypath: "actions.otherSelection")
            )
        )
        #expect(
            !ContentView.configurationsHaveEqualWireForm(
                baseline,
                tabsConfiguration(panelID: "administration")
            )
        )
        #expect(
            !ContentView.configurationsHaveEqualWireForm(
                baseline,
                tabsConfiguration(panelContent: [.Divider(SkeletonDivider())])
            )
        )
        #expect(
            !ContentView.configurationsHaveEqualWireForm(
                tabsConfiguration(panelContent: [
                    .Button(SkeletonButton(keypath: "actions.open", label: "Open"))
                ]),
                tabsConfiguration(panelContent: [
                    .Button(SkeletonButton(keypath: "actions.delete", label: "Open"))
                ])
            )
        )

        func actionPayloadConfiguration(tabID: String) -> CellConfiguration {
            var configuration = CellConfiguration(name: "action-payload-fingerprint")
            configuration.skeleton = .Button(
                SkeletonButton(
                    keypath: "actions.submit",
                    label: "Submit",
                    payload: .object([
                        "Tabs": .object(["id": .string(tabID)])
                    ])
                )
            )
            return configuration
        }

        #expect(
            !ContentView.configurationsHaveEqualWireForm(
                actionPayloadConfiguration(tabID: "one"),
                actionPayloadConfiguration(tabID: "two")
            )
        )
    }

    @Test func bindingLocalRegistrationKeepsAgentAdminSurfacesBehindCatalogGate() async throws {
        UserDefaults.standard.removeObject(forKey: BindingPersonalCopilotV1Policy.agentSetupWorkbenchDefaultsKey)

        CellBase.defaultIdentityVault = nil
        CellBase.defaultCellResolver = nil
        CellBase.typedCellUtility = nil

        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        await BindingLocalCellRegistration.shared.ensureLocallyRegistered()

        guard CellBase.defaultCellResolver is CellResolver else {
            Issue.record("Expected shared resolver after local registration.")
            return
        }
        guard let owner = await BindingStartupIdentityVault.shared.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Expected startup identity for local registration.")
            return
        }

        let catalog = await ConfigurationCatalogCell(owner: owner)
        let configurations = try await catalog.get(keypath: "configurations", requester: owner)
        guard case let .list(items) = configurations else {
            Issue.record("Forventet liste fra configurations")
            return
        }

        let configurationNames = items.compactMap { value -> String? in
            guard case let .cellConfiguration(configuration) = value else { return nil }
            return configuration.name
        }

        #expect(!BindingPersonalCopilotV1Policy.agentSetupWorkbenchEnabled)
        #expect(configurationNames.contains("Agent Setup Workbench") == false)
        #expect(configurationNames.contains("Network Sentinel") == false)
    }

    @Test func bindingLocalRegistrationRegistersAgentAdminCellsWhenOptedIn() async throws {
        UserDefaults.standard.set(true, forKey: BindingPersonalCopilotV1Policy.agentSetupWorkbenchDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: BindingPersonalCopilotV1Policy.agentSetupWorkbenchDefaultsKey) }

        CellBase.defaultIdentityVault = nil
        CellBase.defaultCellResolver = nil
        CellBase.typedCellUtility = nil

        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        await BindingLocalCellRegistration.shared.ensureLocallyRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared resolver after local registration.")
            return
        }
        guard let owner = await BindingStartupIdentityVault.shared.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Expected startup identity for local registration.")
            return
        }

        let provisioning = try? await resolver.cellAtEndpoint(endpoint: "cell:///AgentProvisioning", requester: owner)
        let enrollment = try? await resolver.cellAtEndpoint(endpoint: "cell:///AgentEnrollment", requester: owner)

        #expect(provisioning != nil)
        #expect(enrollment != nil)
    }

    @Test func configurationCatalogQueryReturnsRankedResults() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        let payload = makeCatalogPayload(
            name: "Prosessmonitor",
            endpoint: "cell:///AdminProcesses",
            insertionMode: "component"
        )
        _ = try await cell.set(keypath: "addConfiguration", value: .object(payload), requester: owner)

        let queryPayload: Object = [
            "requestId": .string("query-test-1"),
            "q": .string("monitor prosesser"),
            "filters": .object([
                "sourceRefs": .list([.string("cell:///AdminProcesses")])
            ]),
            "context": .object([
                "editMode": .bool(true),
                "insertionIntent": .string("component")
            ]),
            "constraints": .object([
                "maxResults": .integer(5),
                "maxSources": .integer(3),
                "latencyBudgetMs": .integer(300)
            ])
        ]
        let response = try await cell.set(keypath: "query", value: .object(queryPayload), requester: owner)
        guard case let .object(result)? = response else {
            Issue.record("Forventet object-respons fra query")
            return
        }

        #expect(result["status"] == .string("ok"))
        if case let .list(results)? = result["results"] {
            #expect(!results.isEmpty)
        } else {
            Issue.record("Mangler results-list i query-respons")
        }
    }

    @Test func configurationCatalogBrowseQueryIncludesConferenceParticipantPortalEvenWithLowSourceLimit() async throws {
        UserDefaults.standard.set(true, forKey: BindingPersonalCopilotV1Policy.conferenceDemoMenusDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: BindingPersonalCopilotV1Policy.conferenceDemoMenusDefaultsKey) }

        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        let queryPayload: Object = [
            "requestId": .string("query-browse-participant-portal"),
            "q": .string(""),
            "constraints": .object([
                "maxResults": .integer(80),
                "maxSources": .integer(1),
                "latencyBudgetMs": .integer(300)
            ]),
            "filters": .object([
                "sourceRefs": .list([.string("cell:///ConferenceParticipantPreviewShell")])
            ])
        ]

        let response = try await cell.set(keypath: "query", value: .object(queryPayload), requester: owner)
        guard case let .object(result)? = response else {
            Issue.record("Forventet object-respons fra browse query")
            return
        }

        guard case let .list(results)? = result["results"] else {
            Issue.record("Mangler results-list i browse query")
            return
        }

        let names = results.compactMap { value -> String? in
            guard case let .object(object) = value else { return nil }
            guard case let .string(name)? = object["displayName"] else { return nil }
            return name
        }

        #expect(names.contains("Conference Participant Portal Dashboard"))

        if case let .list(warnings)? = result["warnings"] {
            let warningStrings = warnings.compactMap { value -> String? in
                guard case let .string(message) = value else { return nil }
                return message
            }
            #expect(!warningStrings.contains(where: { $0.contains("ConferenceParticipantPreviewShell:maxSourcesLimit") }))
        }
    }

    @Test func configurationCatalogConferenceControlTowerUsesWorkbenchSkeletonForPreviewShell() async throws {
        UserDefaults.standard.set(true, forKey: BindingPersonalCopilotV1Policy.conferenceDemoMenusDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: BindingPersonalCopilotV1Policy.conferenceDemoMenusDefaultsKey) }

        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        let queryPayload: Object = [
            "requestId": .string("query-control-tower"),
            "q": .string("control tower"),
            "constraints": .object([
                "maxResults": .integer(12),
                "maxSources": .integer(4),
                "latencyBudgetMs": .integer(300)
            ])
        ]

        let response = try await cell.set(keypath: "query", value: .object(queryPayload), requester: owner)
        guard case let .object(result)? = response else {
            Issue.record("Forventet object-respons fra control tower query")
            return
        }

        guard case let .list(results)? = result["results"] else {
            Issue.record("Mangler results-list i control tower query")
            return
        }

        let matchedConfiguration = results.compactMap { value -> CellConfiguration? in
            guard case let .object(object) = value else { return nil }
            guard case let .string(displayName)? = object["displayName"], displayName == "Conference Control Tower" else {
                return nil
            }
            switch object["configuration"] {
            case .cellConfiguration(let configuration):
                return configuration
            case .object(let configurationObject):
                guard let data = try? JSONEncoder().encode(configurationObject) else { return nil }
                return try? JSONDecoder().decode(CellConfiguration.self, from: data)
            default:
                return nil
            }
        }.first

        guard let configuration = matchedConfiguration else {
            Issue.record("Fant ikke Conference Control Tower i query-resultatene")
            return
        }

        let configurationData = try JSONEncoder().encode(configuration)
        let configurationString = String(decoding: configurationData, as: UTF8.self)
        #expect(configuration.discovery?.sourceCellEndpoint == "cell:///ConferenceAdminPreviewShell")
        #expect(configuration.discovery?.sourceCellName == "ConferenceAdminPreviewShellLocalFallbackCell")
        #expect(configurationString.contains("conferenceAdminShell.state.workspace.title"))
        #expect(configurationString.contains("conferenceAdminShell.state.content.intro"))
    }

    @MainActor
    @Test func conferenceAdminPreviewShellUsesAdminPreviewRequesterDescriptor() async throws {
        let subject = ContentView()
        let descriptor = subject.preferredRequesterDescriptor(
            for: "cell://staging.haven.digipomps.org/ConferenceAdminPreviewShell"
        )

        #expect(descriptor?.identityContext == "conference-admin-preview:preview-control-tower-v2@staging.haven.digipomps.org")
        #expect(descriptor?.displayName == "Conference Admin Preview")
    }

    @Test func configurationCatalogFacetCountsIncludesInsertionModes() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        let payload = makeCatalogPayload(
            name: "Prosesskort",
            endpoint: "cell:///AdminProcesses",
            insertionMode: "component"
        )
        _ = try await cell.set(keypath: "addConfiguration", value: .object(payload), requester: owner)

        let facetPayload: Object = [
            "requestId": .string("facet-test-1"),
            "baseQuery": .object([
                "q": .string("prosess"),
                "constraints": .object([
                    "maxSources": .integer(3)
                ])
            ]),
            "facetKeys": .list([.string("supportedInsertionModes")]),
            "maxBucketsPerFacet": .integer(10)
        ]

        let response = try await cell.set(keypath: "facetCounts", value: .object(facetPayload), requester: owner)
        guard case let .object(result)? = response else {
            Issue.record("Forventet object-respons fra facetCounts")
            return
        }
        #expect(result["status"] == .string("ok"))

        guard case let .object(facets)? = result["facets"],
              case let .list(modeBuckets)? = facets["supportedInsertionModes"] else {
            Issue.record("Mangler supportedInsertionModes-facet")
            return
        }

        let hasComponent = modeBuckets.contains { value in
            guard case let .object(bucket) = value else { return false }
            return bucket["value"] == .string("component")
        }
        #expect(hasComponent)
    }

    @Test func portholeAbsorbsCatalogReference() async throws {
        let (resolver, identity) = await makeIsolatedPortholeRuntime()
        await BindingLocalCellRegistration.shared.ensureLocallyRegistered()

        guard let porthole = try await resolver.cellAtEndpoint(endpoint: "cell:///Porthole", requester: identity) as? OrchestratorCell else {
            Issue.record("Could not resolve Porthole")
            return
        }

        porthole.detachAll(requester: identity)

        var config = CellConfiguration(name: "Catalog Absorb Test")
        config.addReference(CellReference(endpoint: "cell:///ConfigurationCatalog", label: "catalog"))

        _ = try await resolver.loadCell(from: config, into: porthole, requester: identity)

        let status = try await porthole.attachedStatus(for: "catalog", requester: identity)
        #expect(status.name == "catalog")
        #expect(status.active)

        let stateValue = try await porthole.get(keypath: "catalog.state", requester: identity)
        guard case .object = stateValue else {
            Issue.record("Expected object from catalog.state, got \(stateValue)")
            return
        }
    }

    @Test func bindingLocalCellRegistrationMakesConfigurationCatalogResolvable() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after app initialization")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Missing private identity")
            return
        }

        let emit = try await resolver.cellAtEndpoint(endpoint: "cell:///ConfigurationCatalog", requester: identity)
        #expect(emit is ConfigurationCatalogCell)
    }

    @Test func bindingLocalConfigurationCatalogServesEntriesAndQueryResults() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            Issue.record("Expected shared CellResolver after app initialization")
            return
        }
        guard let identity = await identityVault.identity(for: "private", makeNewIfNotFound: true) else {
            Issue.record("Missing private identity")
            return
        }
        guard let catalog = try await resolver.cellAtEndpoint(
            endpoint: "cell:///ConfigurationCatalog",
            requester: identity
        ) as? Meddle else {
            Issue.record("ConfigurationCatalog did not resolve as Meddle")
            return
        }

        let entries = try await catalog.get(keypath: "catalogEntries", requester: identity)
        guard case let .list(entryList) = entries else {
            Issue.record("Expected catalogEntries list, got \(String(describing: entries))")
            return
        }
        #expect(!entryList.isEmpty)

        let queryResponse = try await catalog.set(
            keypath: "query",
            value: .object([
                "q": .string("conference"),
                "constraints": .object([
                    "maxResults": .integer(12)
                ])
            ]),
            requester: identity
        )
        guard case let .object(queryObject) = queryResponse else {
            Issue.record("Expected object query response, got \(String(describing: queryResponse))")
            return
        }
        guard case let .list(resultList)? = queryObject["results"] else {
            Issue.record("Expected query response with results list")
            return
        }
        #expect(!resultList.isEmpty)
    }

    @Test func fullLibraryRefreshCompletesAndYieldsResults() async throws {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        await AppInitializer.initialize()
        await BindingLocalCellRegistration.shared.ensureRegistered()

        let model = await MainActor.run {
            FullLibraryViewModel(
                catalogEndpoints: ["cell:///ConfigurationCatalog"],
                queryContext: FullLibraryQueryContext(
                    editMode: false,
                    selectedNodeKind: nil,
                    insertionIntent: .unknown
                ),
                fallbackFavorites: [],
                fallbackTemplates: []
            )
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                await model.refreshNow()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 4_000_000_000)
                throw CancellationError()
            }

            _ = try await group.next()
            group.cancelAll()
        }

        await MainActor.run {
            #expect(!model.isLoading)
            #expect(model.statusLine != "Laster ConfigurationCatalog...")
            #expect(!model.results.isEmpty)
        }
    }

    @Test func applePortholeLoadCellConfigurationReplacesPreviousReferences() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let (resolver, owner) = await makeIsolatedPortholeRuntime()

        try? await resolver.addCellResolve(
            name: "Porthole",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: OrchestratorCell.self
        )
        try? await resolver.addCellResolve(
            name: "ConfigurationCatalog",
            cellScope: .scaffoldUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: ConfigurationCatalogCell.self
        )
        try? await resolver.addCellResolve(
            name: "RootOnlyState",
            cellScope: .scaffoldUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: RootOnlyStateCell.self
        )

        guard let porthole = try await resolver.cellAtEndpoint(endpoint: "cell:///Porthole", requester: owner) as? OrchestratorCell else {
            Issue.record("Could not resolve Porthole")
            return
        }

        try await porthole.loadCellConfiguration(CellConfiguration(name: "Empty Porthole"), requester: owner)

        var catalogConfiguration = CellConfiguration(name: "Catalog Workspace")
        catalogConfiguration.addReference(CellReference(endpoint: "cell:///ConfigurationCatalog", label: "catalog"))
        try await porthole.loadCellConfiguration(catalogConfiguration, requester: owner)

        var rootStateConfiguration = CellConfiguration(name: "Root State Workspace")
        rootStateConfiguration.addReference(CellReference(endpoint: "cell:///RootOnlyState", label: "rootState"))
        try await porthole.loadCellConfiguration(rootStateConfiguration, requester: owner)

        #expect(porthole.getCellConfiguration()?.name == "Root State Workspace")
        #expect(porthole.getCellConfiguration()?.cellReferences?.map(\.label) == ["rootState"])

        let catalogEmitter = await porthole.getEmitterWithLabel("catalog", requester: owner)
        let rootStateEmitter = await porthole.getEmitterWithLabel("rootState", requester: owner)
        #expect(catalogEmitter == nil)
        #expect(rootStateEmitter != nil)
    }

    @Test func applePortholeLoadCellConfigurationRollsBackOnFailure() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let (resolver, owner) = await makeIsolatedPortholeRuntime()

        try? await resolver.addCellResolve(
            name: "Porthole",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: OrchestratorCell.self
        )
        try? await resolver.addCellResolve(
            name: "ConfigurationCatalog",
            cellScope: .scaffoldUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: ConfigurationCatalogCell.self
        )

        guard let porthole = try await resolver.cellAtEndpoint(endpoint: "cell:///Porthole", requester: owner) as? OrchestratorCell else {
            Issue.record("Could not resolve Porthole")
            return
        }

        try await porthole.loadCellConfiguration(CellConfiguration(name: "Empty Porthole"), requester: owner)

        var validConfiguration = CellConfiguration(name: "Catalog Workspace")
        validConfiguration.addReference(CellReference(endpoint: "cell:///ConfigurationCatalog", label: "catalog"))
        try await porthole.loadCellConfiguration(validConfiguration, requester: owner)

        var invalidConfiguration = CellConfiguration(name: "Broken Workspace")
        invalidConfiguration.addReference(CellReference(endpoint: "cell:///MissingCell", label: "missing"))

        do {
            try await porthole.loadCellConfiguration(invalidConfiguration, requester: owner)
            Issue.record("Expected loadCellConfiguration to fail for missing endpoint")
        } catch {
            // Expected: rollback should restore the previous working configuration.
        }

        #expect(porthole.getCellConfiguration()?.name == "Catalog Workspace")
        #expect(porthole.getCellConfiguration()?.cellReferences?.map(\.label) == ["catalog"])

        let missingEmitter = await porthole.getEmitterWithLabel("missing", requester: owner)
        #expect(missingEmitter == nil)
    }

    @Test func cellConfigurationLookupPrefersEditableOverrideFromSourceCell() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        await AppInitializer.initialize()
        let resolver: CellResolver
        if let existing = CellBase.defaultCellResolver as? CellResolver {
            resolver = existing
        } else {
            resolver = CellResolver.sharedInstance
            CellBase.defaultCellResolver = resolver
        }

        let owner = await makeOwnerIdentity()
        let sourceCell = await EditableConfigurationSourceFixtureCell(owner: owner)
        try await resolver.registerNamedEmitCell(
            name: "EditableConfigurationSourceFixture",
            emitCell: sourceCell,
            identity: owner
        )

        let payload: ValueType = .object([
            "configurationLookup": .object([
                "name": .string("Editable Override Workspace"),
                "sourceCellEndpoint": .string("cell:///EditableConfigurationSourceFixture")
            ])
        ])

        let resolved = await CellConfigurationPayloadSupport.resolveCellConfiguration(
            from: payload,
            requester: owner
        )

        #expect(resolved?.name == "Editable Override Workspace")
        #expect(resolved?.cellReferences?.first?.endpoint == "cell:///RootOnlyState")
    }

    @Test func applePortholeAddConfigurationLookupLoadsResolvedConfiguration() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        await AppInitializer.initialize()
        let resolver: CellResolver
        if let existing = CellBase.defaultCellResolver as? CellResolver {
            resolver = existing
        } else {
            resolver = CellResolver.sharedInstance
            CellBase.defaultCellResolver = resolver
        }

        let owner = await makeOwnerIdentity()
        let rootStateCell = await RootOnlyStateCell(owner: owner)
        try await resolver.registerNamedEmitCell(
            name: "RootOnlyState",
            emitCell: rootStateCell,
            identity: owner
        )
        let sourceCell = await EditableConfigurationSourceFixtureCell(owner: owner)
        try await resolver.registerNamedEmitCell(
            name: "EditableConfigurationSourceFixture",
            emitCell: sourceCell,
            identity: owner
        )

        let porthole = await OrchestratorCell(owner: owner)
        try await porthole.loadCellConfiguration(CellConfiguration(name: "Empty Porthole"), requester: owner)

        let response = try await porthole.set(
            keypath: "addConfiguration",
            value: .object([
                "configurationLookup": .object([
                    "name": .string("Editable Override Workspace"),
                    "sourceCellEndpoint": .string("cell:///EditableConfigurationSourceFixture")
                ])
            ]),
            requester: owner
        )

        #expect(response == .string("ok"))
        #expect(porthole.getCellConfiguration()?.name == "Editable Override Workspace")
        #expect(porthole.getCellConfiguration()?.cellReferences?.map(\.label) == ["rootState"])
    }

    @Test func nestedStateLookupFallsBackToRootStateIntercept() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await makeOwnerIdentity()
        let cell = await RootOnlyStateCell(owner: owner)

        let titleValue = try await cell.get(keypath: "state.workspace.title", requester: owner)
        #expect(titleValue == .string("Conference Participant Portal"))

        let sessionValue = try await cell.get(keypath: "state.program.savedSessions[1].title", requester: owner)
        #expect(sessionValue == .string("Shared Relations Roundtable"))
    }

    @Test func portholeResolvesNestedStateKeypathsForAttachedRootOnlyStateCells() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let resolver = CellResolver.sharedInstance
        CellBase.defaultCellResolver = resolver
        let owner = await makeOwnerIdentity()
        let fixtureName = "RootOnlyState-\(UUID().uuidString)"
        let fixture = await RootOnlyStateCell(owner: owner)
        try await resolver.registerNamedEmitCell(
            name: fixtureName,
            emitCell: fixture,
            identity: owner
        )
        let porthole = await OrchestratorCell(owner: owner)

        var configuration = CellConfiguration(name: "Root State Portal")
        configuration.addReference(CellReference(endpoint: "cell:///\(fixtureName)", label: "rootState"))

        try await porthole.loadCellConfiguration(configuration, requester: owner)

        let titleValue = try await porthole.get(keypath: "rootState.state.workspace.title", requester: owner)
        #expect(titleValue == .string("Conference Participant Portal"))

        let sessionValue = try await porthole.get(
            keypath: "rootState.state.program.savedSessions[0].title",
            requester: owner
        )
        #expect(sessionValue == .string("Opening Keynote"))
    }

    @Test func conferenceParticipantPortalResolvesPreviewWrapperStateKeypathsThroughPorthole() async throws {
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let (resolver, owner) = await makeIsolatedPortholeRuntime()

        try? await resolver.addCellResolve(
            name: "Porthole",
            cellScope: .identityUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: OrchestratorCell.self
        )
        let fixtureName = "ConferenceParticipantPreviewShellFixture-\(UUID().uuidString)"
        let fixtureEndpoint = "cell:///\(fixtureName)"

        try? await resolver.addCellResolve(
            name: fixtureName,
            cellScope: .scaffoldUnique,
            persistency: .persistant,
            identityDomain: "private",
            type: ConferenceParticipantPreviewShellFixtureCell.self
        )

        guard let porthole = try await resolver.cellAtEndpoint(endpoint: "cell:///Porthole", requester: owner) as? OrchestratorCell else {
            Issue.record("Could not resolve Porthole")
            return
        }

        porthole.detachAll(requester: owner)

        let configuration = makeConferenceParticipantPortalConfiguration(endpoint: fixtureEndpoint)
        guard let skeleton = configuration.skeleton else {
            Issue.record("Conference participant portal mangler skeleton")
            return
        }

        #expect(skeletonContainsTextKeypath("conferenceParticipantShell.state.workspace.title", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceParticipantShell.state.program.agendaSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceParticipantShell.state.matches.recommendationSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceParticipantShell.state.meetings.meetingSummary", in: skeleton))
        #expect(skeletonContainsTextKeypath("conferenceParticipantShell.state.sharedConnections.chatSummary", in: skeleton))
        #expect(skeletonContainsList(keypath: "conferenceParticipantShell.state.program.savedSessions", topic: "conference.agenda.saved", in: skeleton))
        #expect(skeletonContainsList(keypath: "conferenceParticipantShell.state.matches.recommendations", topic: "conference.match.recommendation", in: skeleton))
        #expect(skeletonContainsList(keypath: "conferenceParticipantShell.state.meetings.confirmedMeetings", topic: "conference.meeting.confirmed", in: skeleton))
        #expect(skeletonContainsList(keypath: "conferenceParticipantShell.state.sharedConnections.connections", topic: "conference.shared.connection", in: skeleton))

        let fixture = try #require(try await resolver.cellAtEndpoint(
            endpoint: fixtureEndpoint,
            requester: owner
        ) as? Meddle)
        #expect(try await fixture.get(
            keypath: "state.workspace.title",
            requester: owner
        ) == .string("Conference Participant Portal"))

        do {
            try await porthole.loadCellConfiguration(configuration, requester: owner)
        } catch {
            Issue.record("Could not attach the persisted participant fixture to Porthole: \(error)")
            return
        }

        let titleValue = try await porthole.get(keypath: "conferenceParticipantShell.state.workspace.title", requester: owner)
        #expect(titleValue == .string("Conference Participant Portal"))

        let agendaSummaryValue = try await porthole.get(
            keypath: "conferenceParticipantShell.state.program.agendaSummary",
            requester: owner
        )
        #expect(agendaSummaryValue == .string("2 saved session(s) · 6 recommended session(s)."))

        let recommendationSummaryValue = try await porthole.get(
            keypath: "conferenceParticipantShell.state.matches.recommendationSummary",
            requester: owner
        )
        #expect(recommendationSummaryValue == .string("3 recommended people with explainability."))

        let meetingSummaryValue = try await porthole.get(
            keypath: "conferenceParticipantShell.state.meetings.meetingSummary",
            requester: owner
        )
        #expect(meetingSummaryValue == .string("0 shared meeting(s) visible."))

        let chatSummaryValue = try await porthole.get(
            keypath: "conferenceParticipantShell.state.sharedConnections.chatSummary",
            requester: owner
        )
        #expect(chatSummaryValue == .string("0 shared message(s) visible."))

        let savedSessionsValue = try await porthole.get(
            keypath: "conferenceParticipantShell.state.program.savedSessions",
            requester: owner
        )
        guard case let .list(savedSessions) = savedSessionsValue else {
            Issue.record("Expected saved sessions list, got \(savedSessionsValue)")
            return
        }
        #expect(savedSessions.count == 2)

        let recommendationsValue = try await porthole.get(
            keypath: "conferenceParticipantShell.state.matches.recommendations",
            requester: owner
        )
        guard case let .list(recommendations) = recommendationsValue else {
            Issue.record("Expected recommendations list, got \(recommendationsValue)")
            return
        }
        #expect(recommendations.count == 3)

        let confirmedMeetingsValue = try await porthole.get(
            keypath: "conferenceParticipantShell.state.meetings.confirmedMeetings",
            requester: owner
        )
        guard case let .list(confirmedMeetings) = confirmedMeetingsValue else {
            Issue.record("Expected confirmed meetings list, got \(confirmedMeetingsValue)")
            return
        }
        #expect(confirmedMeetings.count == 0)

        let connectionsValue = try await porthole.get(
            keypath: "conferenceParticipantShell.state.sharedConnections.connections",
            requester: owner
        )
        guard case let .list(connections) = connectionsValue else {
            Issue.record("Expected shared connections list, got \(connectionsValue)")
            return
        }
        #expect(connections.count == 0)
    }

    @Test func configurationCatalogRemovesBlockedReferencesWhenOtherReferencesExist() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        var configuration = CellConfiguration(name: "Mixed References")
        configuration.addReference(CellReference(endpoint: "cell:///EventEmitter", label: "signals"))
        configuration.addReference(CellReference(endpoint: "cell:///Chat", label: "chat"))

        let payload: Object = [
            "sourceCellEndpoint": .string("cell:///EventEmitter"),
            "sourceCellName": .string("MixedCell"),
            "purpose": .string("Test blocked filtering"),
            "interests": .list([.string("chat")]),
            "menuSlots": .list([.string("upperLeft")]),
            "configuration": .cellConfiguration(configuration),
            "goal": .cellConfiguration(configuration)
        ]

        _ = try await cell.set(keypath: "addConfiguration", value: .object(payload), requester: owner)

        let entriesValue = try await cell.get(keypath: "catalogEntries", requester: owner)
        guard case let .list(entries) = entriesValue,
              let match = entries.first(where: { value in
                  guard case let .object(object) = value,
                        case let .cellConfiguration(configuration)? = object["configuration"] else {
                      return false
                  }
                  return configuration.name == "Mixed References"
              }),
              case let .object(object) = match,
              case let .cellConfiguration(storedConfiguration)? = object["configuration"],
              let references = storedConfiguration.cellReferences
        else {
            Issue.record("Expected stored catalog entry with configuration references")
            return
        }

        #expect(references.contains(where: { $0.endpoint == "cell:///Chat" }))
        #expect(!references.contains(where: { $0.endpoint.lowercased().contains("eventemitter") }))
    }

    @Test func configurationCatalogRejectsConfigurationsWithOnlyBlockedReferences() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        var configuration = CellConfiguration(name: "Only Blocked")
        configuration.addReference(CellReference(endpoint: "cell:///TimesWrapper", label: "times"))

        let payload: Object = [
            "sourceCellEndpoint": .string("cell:///TimesWrapper"),
            "sourceCellName": .string("TimesOnlyCell"),
            "purpose": .string("Should be rejected"),
            "interests": .list([.string("time")]),
            "menuSlots": .list([.string("upperLeft")]),
            "configuration": .cellConfiguration(configuration),
            "goal": .cellConfiguration(configuration)
        ]

        let response = try await cell.set(keypath: "addConfiguration", value: .object(payload), requester: owner)
        #expect(response == .string("error: invalid payload for addConfiguration"))
    }

    @Test func copilotChatConfigurationUsesPersonalChatHubWorkbench() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        _ = try await cell.set(keypath: "syncScaffoldPurposeGoals", value: .null, requester: owner)
        let configurations = try await cell.get(keypath: "configurations", requester: owner)
        guard case let .list(items) = configurations else {
            Issue.record("Forventet liste fra configurations")
            return
        }

        let chatConfiguration = items.compactMap { value -> CellConfiguration? in
            guard case let .cellConfiguration(configuration) = value else { return nil }
            return configuration.name == "Co-Pilot" ? configuration : nil
        }.first

        guard let chatConfiguration else {
            Issue.record("Fant ikke Co-Pilot i configurations")
            return
        }

        let endpoints = chatConfiguration.cellReferences?.map(\.endpoint) ?? []
        #expect(endpoints.contains("cell:///PersonalChatHub"))

        guard let skeleton = chatConfiguration.skeleton else {
            Issue.record("Co-Pilot mangler skeleton")
            return
        }

        #expect(skeletonContainsTextArea(targetKeypath: "chatHub.setComposer", in: skeleton))
        #expect(skeletonContainsButton(keypath: "chatHub.ui.openSuggestedHelper", in: skeleton))
        #expect(skeletonContainsButton(keypath: "chatHub.assistant.dismissSuggestion", in: skeleton))
        #expect(!skeletonContainsLiteralText("Trykk pilen", in: skeleton))
        #expect(skeletonContainsList(keypath: "chatHub.state.ui.promptMessages", topic: nil, in: skeleton))
        #expect(skeletonContainsList(keypath: "chatHub.state.workbench.modules", topic: nil, in: skeleton))
        #expect(skeletonContainsList(keypath: "chatHub.state.ui.componentSurfaces", topic: nil, in: skeleton))
        #expect(skeletonContainsList(keypath: "chatHub.state.ui.activeToolChips", topic: nil, in: skeleton))
        #expect(skeletonContainsTextKeypath("chatHub.state.assistant.whySummary", in: skeleton))
    }

    @Test func catalogSyncRefreshesPersistedCopilotChatWorkbench() async throws {
        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        var stale = ConfigurationCatalogCell.personalInviteChatMenuConfiguration()
        stale.skeleton = .Text(SkeletonText(text: "Start her"))

        _ = try await cell.set(
            keypath: "addConfiguration",
            value: .object([
                "sourceCellEndpoint": .string("cell:///PersonalChatHub"),
                "sourceCellName": .string("PersonalChatHubCell"),
                "purpose": .string("Central purpose-driven co-pilot chat"),
                "purposeDescription": .string("stale"),
                "interests": .list([.string("personal-copilot-v1")]),
                "menuSlots": .list([.string("upperLeft")]),
                "configuration": .cellConfiguration(stale),
                "goal": .cellConfiguration(stale)
            ]),
            requester: owner
        )

        _ = try await cell.set(keypath: "syncScaffoldPurposeGoals", value: .null, requester: owner)
        let configurations = try await cell.get(keypath: "configurations", requester: owner)
        guard case let .list(items) = configurations else {
            Issue.record("Forventet liste fra configurations")
            return
        }

        let chatConfiguration = items.compactMap { value -> CellConfiguration? in
            guard case let .cellConfiguration(configuration) = value else { return nil }
            return configuration.name == "Co-Pilot" ? configuration : nil
        }.first

        guard let skeleton = chatConfiguration?.skeleton else {
            Issue.record("Co-Pilot mangler skeleton etter sync")
            return
        }

        #expect(!skeletonContainsLiteralText("Start her", in: skeleton))
        #expect(skeletonTabPanel(id: "hjelp", in: skeleton) != nil)
        #expect(chatConfiguration?.cellReferences?.contains(where: {
            $0.label == "chatHub" && $0.endpoint == "cell:///PersonalChatHub"
        }) == true)
    }

    @Test func configurationCatalogPublishesCatalogContractsForScaffoldParityFixtures() async throws {
        UserDefaults.standard.set(true, forKey: BindingPersonalCopilotV1Policy.conferenceDemoMenusDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: BindingPersonalCopilotV1Policy.conferenceDemoMenusDefaultsKey) }
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        CellBase.debugValidateAccessForEverything = true
        defer { CellBase.debugValidateAccessForEverything = previousDebugAccess }

        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        _ = try await cell.set(keypath: "syncScaffoldPurposeGoals", value: .null, requester: owner)
        let contractsValue = try await cell.get(keypath: "catalogContracts", requester: owner)
        guard case let .list(items) = contractsValue else {
            Issue.record("Forventet liste fra catalogContracts")
            return
        }

        let parityObject = items.compactMap { value -> Object? in
            guard case let .object(object) = value else { return nil }
            return bindingTestValueString(object["displayName"]) == "Skeleton Parity Text Fixture" ? object : nil
        }.first

        guard let parityObject else {
            Issue.record("Fant ikke scaffold parity-kontrakt i catalogContracts")
            return
        }

        #expect(bindingTestValueString(parityObject["sourceCellEndpoint"]) == "cell:///SkeletonParityTextFixture")
        #expect(bindingTestValueStrings(parityObject["recommendedContexts"]).contains("binding"))
        #expect(bindingTestValueStrings(parityObject["policyHints"]).contains("deterministic_fixture"))
        #expect(bindingTestValueStrings(parityObject["categoryPath"]).contains("skeleton-parity"))

        guard case let .object(ioSignature)? = parityObject["ioSignature"] else {
            Issue.record("Forventet ioSignature i scaffold parity-kontrakten")
            return
        }
        #expect(bindingTestValueStrings(ioSignature["getKeys"]).contains("purposeGoal"))
    }

    @Test func configurationCatalogPublishesCatalogWorkbenchContractIOKeys() async throws {
        UserDefaults.standard.set(true, forKey: BindingPersonalCopilotV1Policy.conferenceDemoMenusDefaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: BindingPersonalCopilotV1Policy.conferenceDemoMenusDefaultsKey) }

        let owner = await makeOwnerIdentity()
        let cell = await ConfigurationCatalogCell(owner: owner)

        let contractsValue = try await cell.get(keypath: "catalogContracts", requester: owner)
        guard case let .list(items) = contractsValue else {
            Issue.record("Forventet liste fra catalogContracts")
            return
        }

        let workbenchObject = items.compactMap { value -> Object? in
            guard case let .object(object) = value else { return nil }
            return bindingTestValueString(object["displayName"]) == "Catalog Workbench" ? object : nil
        }.first

        guard let workbenchObject else {
            Issue.record("Fant ikke Catalog Workbench i catalogContracts")
            return
        }

        #expect(bindingTestValueStrings(workbenchObject["recommendedContexts"]).contains("catalog-curation"))
        #expect(bindingTestValueStrings(workbenchObject["supportedTargetKinds"]).contains("tool"))

        guard case let .object(ioSignature)? = workbenchObject["ioSignature"] else {
            Issue.record("Forventet ioSignature i Catalog Workbench-kontrakten")
            return
        }

        let getKeys = bindingTestValueStrings(ioSignature["getKeys"])
        #expect(getKeys.contains("catalogContracts"))
        #expect(getKeys.contains("catalogEntries"))
        #expect(getKeys.contains("configurations"))
    }

    private func makeOwnerIdentity() async -> Identity {
        CellBase.defaultIdentityVault = Self.testIdentityVault
        await CellResolver.sharedInstance.refreshNamedResolveOwnersFromCurrentVault()
        return await Self.testIdentityVault.identity(for: "private", makeNewIfNotFound: true)!
    }

    @MainActor
    private func makeIsolatedPortholeRuntime() async -> (CellResolver, Identity) {
        let resolver = CellResolver.sharedInstance
        await AppInitializer.resetRuntimeStateForTesting()
        await resolver.resetRuntimeStateForTesting()
        CellBase.defaultCellResolver = resolver
        CellBase.defaultIdentityVault = Self.testIdentityVault
        await BindingRuntimeBootstrap.ensureInfrastructureBaseline()
        let owner = await Self.testIdentityVault.identity(
            for: "private",
            makeNewIfNotFound: true
        )!
        return (resolver, owner)
    }

    private func makeIsolatedRuntimeIdentity(_ contextPrefix: String) async -> Identity {
        let identityVault = IdentityVault.shared
        _ = await identityVault.initialize()
        CellBase.defaultIdentityVault = identityVault
        return await identityVault.identity(
            for: "\(contextPrefix)-\(UUID().uuidString)",
            makeNewIfNotFound: true
        )!
    }

    private func makeCatalogPayload(name: String, endpoint: String, insertionMode: String) -> Object {
        var configuration = CellConfiguration(name: name)
        configuration.description = "Testkonfig for query/facet"
        var reference = CellReference(endpoint: endpoint, label: "source")
        reference.setKeysAndValues = [KeyValue(key: "adminProcesses.query", value: .string("top"))]
        configuration.addReference(reference)

        return [
            "sourceCellEndpoint": .string(endpoint),
            "sourceCellName": .string("AdminProcessesCell"),
            "purpose": .string("System monitorering"),
            "purposeDescription": .string("Overvåkning av systemprosesser"),
            "interests": .list([.string("process"), .string("alerts")]),
            "menuSlots": .list([.string("lowerMid")]),
            "categoryPath": .list([.string("ops"), .string("monitoring")]),
            "tags": .list([.string("ops"), .string("monitoring")]),
            "supportedInsertionModes": .list([.string(insertionMode)]),
            "flowDriven": .bool(true),
            "editable": .bool(true),
            "configuration": .cellConfiguration(configuration),
            "goal": .cellConfiguration(configuration)
        ]
    }

    private func makeConferenceParticipantPortalConfiguration(
        endpoint: String = "cell:///ConferenceParticipantPreviewShell"
    ) -> CellConfiguration {
        var configuration = CellConfiguration(name: "Conference Participant Portal Dashboard")
        configuration.description = "Representative portal config using the preview-wrapper state contract."

        var reference = CellReference(
            endpoint: endpoint,
            subscribeFeed: false,
            label: "conferenceParticipantShell"
        )
        reference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(reference)

        var savedSessions = SkeletonList(
            topic: "conference.agenda.saved",
            keypath: "conferenceParticipantShell.state.program.savedSessions",
            flowElementSkeleton: nil
        )
        savedSessions.flowElementSkeleton = SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "title")),
            .Text(SkeletonText(keypath: "subtitle"))
        ])

        var recommendations = SkeletonList(
            topic: "conference.match.recommendation",
            keypath: "conferenceParticipantShell.state.matches.recommendations",
            flowElementSkeleton: nil
        )
        recommendations.flowElementSkeleton = SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "displayName")),
            .Text(SkeletonText(keypath: "headline"))
        ])

        var confirmedMeetings = SkeletonList(
            topic: "conference.meeting.confirmed",
            keypath: "conferenceParticipantShell.state.meetings.confirmedMeetings",
            flowElementSkeleton: nil
        )
        confirmedMeetings.flowElementSkeleton = SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "title")),
            .Text(SkeletonText(keypath: "time"))
        ])

        var sharedConnections = SkeletonList(
            topic: "conference.shared.connection",
            keypath: "conferenceParticipantShell.state.sharedConnections.connections",
            flowElementSkeleton: nil
        )
        sharedConnections.flowElementSkeleton = SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "displayName")),
            .Text(SkeletonText(keypath: "relation"))
        ])

        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "conferenceParticipantShell.state.workspace.title")),
            .Text(SkeletonText(keypath: "conferenceParticipantShell.state.program.agendaSummary")),
            .Text(SkeletonText(keypath: "conferenceParticipantShell.state.matches.recommendationSummary")),
            .Text(SkeletonText(keypath: "conferenceParticipantShell.state.meetings.meetingSummary")),
            .Text(SkeletonText(keypath: "conferenceParticipantShell.state.sharedConnections.chatSummary")),
            .List(savedSessions),
            .List(recommendations),
            .List(confirmedMeetings),
            .List(sharedConnections)
        ]))
        return configuration
    }

    private func skeletonContainsButton(keypath: String, url: String? = nil, in elements: [SkeletonElement]) -> Bool {
        elements.contains { skeletonContainsButton(keypath: keypath, url: url, in: $0) }
    }

    private func skeletonContainsButton(keypath: String, label: String, in elements: [SkeletonElement]) -> Bool {
        elements.contains { skeletonContainsButton(keypath: keypath, label: label, in: $0) }
    }

    private func skeletonContainsButton(keypath: String, label: String, in element: SkeletonElement) -> Bool {
        switch element {
        case .Button(let button):
            return button.keypath == keypath && button.label == label
        case .VStack(let stack):
            return stack.elements.contains { skeletonContainsButton(keypath: keypath, label: label, in: $0) }
        case .HStack(let stack):
            return stack.elements.contains { skeletonContainsButton(keypath: keypath, label: label, in: $0) }
        case .ScrollView(let scroll):
            return scroll.elements.contains { skeletonContainsButton(keypath: keypath, label: label, in: $0) }
        case .Section(let section):
            return (section.header.map { skeletonContainsButton(keypath: keypath, label: label, in: $0) } ?? false) ||
                section.content.contains { skeletonContainsButton(keypath: keypath, label: label, in: $0) } ||
                (section.footer.map { skeletonContainsButton(keypath: keypath, label: label, in: $0) } ?? false)
        case .Reference(let reference):
            return reference.flowElementSkeleton.map { skeletonContainsButton(keypath: keypath, label: label, in: .VStack($0)) } ?? false
        case .List(let list):
            return list.flowElementSkeleton.map { skeletonContainsButton(keypath: keypath, label: label, in: .VStack($0)) } ?? false
        case .Grid(let grid):
            return grid.elements.contains { skeletonContainsButton(keypath: keypath, label: label, in: $0) }
        case .ZStack(let stack):
            return stack.elements.contains { skeletonContainsButton(keypath: keypath, label: label, in: $0) }
        case .Object(let object):
            return object.elements.values.contains { skeletonContainsButton(keypath: keypath, label: label, in: $0) }
        case .Tabs(let tabs):
            return tabs.panels.contains { panel in
                panel.content.contains { skeletonContainsButton(keypath: keypath, label: label, in: $0) }
            }
        default:
            return false
        }
    }

    private func skeletonContainsButton(keypath: String, url: String? = nil, in element: SkeletonElement) -> Bool {
        switch element {
        case .Button(let button):
            return button.keypath == keypath && button.url == url
        case .VStack(let stack):
            return stack.elements.contains { skeletonContainsButton(keypath: keypath, url: url, in: $0) }
        case .HStack(let stack):
            return stack.elements.contains { skeletonContainsButton(keypath: keypath, url: url, in: $0) }
        case .ScrollView(let scroll):
            return scroll.elements.contains { skeletonContainsButton(keypath: keypath, url: url, in: $0) }
        case .Section(let section):
            return (section.header.map { skeletonContainsButton(keypath: keypath, url: url, in: $0) } ?? false) ||
                section.content.contains { skeletonContainsButton(keypath: keypath, url: url, in: $0) } ||
                (section.footer.map { skeletonContainsButton(keypath: keypath, url: url, in: $0) } ?? false)
        case .Reference(let reference):
            return reference.flowElementSkeleton.map { skeletonContainsButton(keypath: keypath, url: url, in: .VStack($0)) } ?? false
        case .List(let list):
            return list.flowElementSkeleton.map { skeletonContainsButton(keypath: keypath, url: url, in: .VStack($0)) } ?? false
        case .Grid(let grid):
            return grid.elements.contains { skeletonContainsButton(keypath: keypath, url: url, in: $0) }
        case .ZStack(let stack):
            return stack.elements.contains { skeletonContainsButton(keypath: keypath, url: url, in: $0) }
        case .Object(let object):
            return object.elements.values.contains { skeletonContainsButton(keypath: keypath, url: url, in: $0) }
        case .Tabs(let tabs):
            return tabs.panels.contains { panel in
                panel.content.contains { skeletonContainsButton(keypath: keypath, url: url, in: $0) }
            }
        default:
            return false
        }
    }

    private func topLevelSectionHasHeader(_ text: String, in elements: [SkeletonElement]) -> Bool {
        elements.contains { element in
            guard case .Section(let section) = element,
                  let header = section.header else {
                return false
            }
            return skeletonContainsLiteralText(text, in: header)
        }
    }

    private func topLevelSectionContent(header text: String, in elements: [SkeletonElement]) -> [SkeletonElement]? {
        for element in elements {
            guard case .Section(let section) = element,
                  let header = section.header,
                  skeletonContainsLiteralText(text, in: header) else {
                continue
            }
            return section.content
        }
        return nil
    }

    private func firstTopLevelElementIndex(
        in elements: [SkeletonElement],
        matching predicate: (SkeletonElement) -> Bool
    ) -> Int? {
        elements.firstIndex(where: predicate)
    }

    private func elementContainsList(keypath: String, in element: SkeletonElement) -> Bool {
        skeletonListFlowElement(keypath: keypath, in: element) != nil
    }

    private func skeletonListFlowElement(keypath: String, in elements: [SkeletonElement]) -> SkeletonElement? {
        for element in elements {
            if let match = skeletonListFlowElement(keypath: keypath, in: element) {
                return match
            }
        }
        return nil
    }

    private func skeletonListFlowElement(keypath: String, in element: SkeletonElement) -> SkeletonElement? {
        switch element {
        case .List(let list):
            guard list.keypath == keypath,
                  let flowElementSkeleton = list.flowElementSkeleton else {
                return nil
            }
            return .VStack(flowElementSkeleton)
        case .VStack(let stack):
            return skeletonListFlowElement(keypath: keypath, in: stack.elements)
        case .HStack(let stack):
            return skeletonListFlowElement(keypath: keypath, in: stack.elements)
        case .ScrollView(let scroll):
            return skeletonListFlowElement(keypath: keypath, in: scroll.elements)
        case .Section(let section):
            if let header = section.header,
               let match = skeletonListFlowElement(keypath: keypath, in: header) {
                return match
            }
            if let match = skeletonListFlowElement(keypath: keypath, in: section.content) {
                return match
            }
            if let footer = section.footer {
                return skeletonListFlowElement(keypath: keypath, in: footer)
            }
            return nil
        case .Reference(let reference):
            return reference.flowElementSkeleton.flatMap {
                skeletonListFlowElement(keypath: keypath, in: .VStack($0))
            }
        case .Grid(let grid):
            return skeletonListFlowElement(keypath: keypath, in: grid.elements)
        case .ZStack(let stack):
            return skeletonListFlowElement(keypath: keypath, in: stack.elements)
        case .Object(let object):
            return skeletonListFlowElement(keypath: keypath, in: Array(object.elements.values))
        case .Tabs(let tabs):
            for panel in tabs.panels {
                if let match = skeletonListFlowElement(keypath: keypath, in: panel.content) {
                    return match
                }
            }
            return nil
        default:
            return nil
        }
    }

    private func skeletonContainsButtonWithNilPayload(keypath: String, in element: SkeletonElement) -> Bool {
        switch element {
        case .Button(let button):
            return button.keypath == keypath && button.payload == nil
        case .VStack(let stack):
            return stack.elements.contains { skeletonContainsButtonWithNilPayload(keypath: keypath, in: $0) }
        case .HStack(let stack):
            return stack.elements.contains { skeletonContainsButtonWithNilPayload(keypath: keypath, in: $0) }
        case .ScrollView(let scroll):
            return scroll.elements.contains { skeletonContainsButtonWithNilPayload(keypath: keypath, in: $0) }
        case .Section(let section):
            return (section.header.map { skeletonContainsButtonWithNilPayload(keypath: keypath, in: $0) } ?? false) ||
                section.content.contains { skeletonContainsButtonWithNilPayload(keypath: keypath, in: $0) } ||
                (section.footer.map { skeletonContainsButtonWithNilPayload(keypath: keypath, in: $0) } ?? false)
        case .Reference(let reference):
            return reference.flowElementSkeleton.map { skeletonContainsButtonWithNilPayload(keypath: keypath, in: .VStack($0)) } ?? false
        case .List(let list):
            return list.flowElementSkeleton.map { skeletonContainsButtonWithNilPayload(keypath: keypath, in: .VStack($0)) } ?? false
        case .Grid(let grid):
            return grid.elements.contains { skeletonContainsButtonWithNilPayload(keypath: keypath, in: $0) }
        case .ZStack(let stack):
            return stack.elements.contains { skeletonContainsButtonWithNilPayload(keypath: keypath, in: $0) }
        case .Object(let object):
            return object.elements.values.contains { skeletonContainsButtonWithNilPayload(keypath: keypath, in: $0) }
        case .Tabs(let tabs):
            return tabs.panels.contains { panel in
                panel.content.contains { skeletonContainsButtonWithNilPayload(keypath: keypath, in: $0) }
            }
        default:
            return false
        }
    }

    private func skeletonContainsTextArea(targetKeypath: String, in element: SkeletonElement) -> Bool {
        switch element {
        case .TextArea(let textArea):
            return textArea.targetKeypath == targetKeypath
        case .VStack(let stack):
            return stack.elements.contains { skeletonContainsTextArea(targetKeypath: targetKeypath, in: $0) }
        case .HStack(let stack):
            return stack.elements.contains { skeletonContainsTextArea(targetKeypath: targetKeypath, in: $0) }
        case .ScrollView(let scroll):
            return scroll.elements.contains { skeletonContainsTextArea(targetKeypath: targetKeypath, in: $0) }
        case .Section(let section):
            return (section.header.map { skeletonContainsTextArea(targetKeypath: targetKeypath, in: $0) } ?? false) ||
                section.content.contains { skeletonContainsTextArea(targetKeypath: targetKeypath, in: $0) } ||
                (section.footer.map { skeletonContainsTextArea(targetKeypath: targetKeypath, in: $0) } ?? false)
        case .Reference(let reference):
            return reference.flowElementSkeleton.map { skeletonContainsTextArea(targetKeypath: targetKeypath, in: .VStack($0)) } ?? false
        case .List(let list):
            return list.flowElementSkeleton.map { skeletonContainsTextArea(targetKeypath: targetKeypath, in: .VStack($0)) } ?? false
        case .Grid(let grid):
            return grid.elements.contains { skeletonContainsTextArea(targetKeypath: targetKeypath, in: $0) }
        case .ZStack(let stack):
            return stack.elements.contains { skeletonContainsTextArea(targetKeypath: targetKeypath, in: $0) }
        case .Object(let object):
            return object.elements.values.contains { skeletonContainsTextArea(targetKeypath: targetKeypath, in: $0) }
        case .Tabs(let tabs):
            return tabs.panels.contains { panel in
                panel.content.contains { skeletonContainsTextArea(targetKeypath: targetKeypath, in: $0) }
            }
        default:
            return false
        }
    }

    private func skeletonTextArea(targetKeypath: String, in element: SkeletonElement) -> SkeletonTextArea? {
        switch element {
        case .TextArea(let textArea):
            return textArea.targetKeypath == targetKeypath ? textArea : nil
        case .VStack(let stack):
            return stack.elements.lazy.compactMap { skeletonTextArea(targetKeypath: targetKeypath, in: $0) }.first
        case .HStack(let stack):
            return stack.elements.lazy.compactMap { skeletonTextArea(targetKeypath: targetKeypath, in: $0) }.first
        case .ScrollView(let scroll):
            return scroll.elements.lazy.compactMap { skeletonTextArea(targetKeypath: targetKeypath, in: $0) }.first
        case .Section(let section):
            if let header = section.header,
               let match = skeletonTextArea(targetKeypath: targetKeypath, in: header) {
                return match
            }
            if let match = section.content.lazy.compactMap({ skeletonTextArea(targetKeypath: targetKeypath, in: $0) }).first {
                return match
            }
            if let footer = section.footer {
                return skeletonTextArea(targetKeypath: targetKeypath, in: footer)
            }
            return nil
        case .Reference(let reference):
            return reference.flowElementSkeleton.flatMap { skeletonTextArea(targetKeypath: targetKeypath, in: .VStack($0)) }
        case .List(let list):
            return list.flowElementSkeleton.flatMap { skeletonTextArea(targetKeypath: targetKeypath, in: .VStack($0)) }
        case .Grid(let grid):
            if let itemSkeleton = grid.itemSkeleton,
               let match = skeletonTextArea(targetKeypath: targetKeypath, in: itemSkeleton) {
                return match
            }
            return grid.elements.lazy.compactMap { skeletonTextArea(targetKeypath: targetKeypath, in: $0) }.first
        case .ZStack(let stack):
            return stack.elements.lazy.compactMap { skeletonTextArea(targetKeypath: targetKeypath, in: $0) }.first
        case .Object(let object):
            return object.elements.values.lazy.compactMap { skeletonTextArea(targetKeypath: targetKeypath, in: $0) }.first
        case .Tabs(let tabs):
            for panel in tabs.panels {
                if let match = panel.content.lazy.compactMap({ skeletonTextArea(targetKeypath: targetKeypath, in: $0) }).first {
                    return match
                }
            }
            return nil
        default:
            return nil
        }
    }

    private func skeletonContainsTextField(targetKeypath: String, in element: SkeletonElement) -> Bool {
        switch element {
        case .TextField(let textField):
            return textField.targetKeypath == targetKeypath
        case .VStack(let stack):
            return stack.elements.contains { skeletonContainsTextField(targetKeypath: targetKeypath, in: $0) }
        case .HStack(let stack):
            return stack.elements.contains { skeletonContainsTextField(targetKeypath: targetKeypath, in: $0) }
        case .ScrollView(let scroll):
            return scroll.elements.contains { skeletonContainsTextField(targetKeypath: targetKeypath, in: $0) }
        case .Section(let section):
            return (section.header.map { skeletonContainsTextField(targetKeypath: targetKeypath, in: $0) } ?? false) ||
                section.content.contains { skeletonContainsTextField(targetKeypath: targetKeypath, in: $0) } ||
                (section.footer.map { skeletonContainsTextField(targetKeypath: targetKeypath, in: $0) } ?? false)
        case .Reference(let reference):
            return reference.flowElementSkeleton.map { skeletonContainsTextField(targetKeypath: targetKeypath, in: .VStack($0)) } ?? false
        case .List(let list):
            return list.flowElementSkeleton.map { skeletonContainsTextField(targetKeypath: targetKeypath, in: .VStack($0)) } ?? false
        case .Grid(let grid):
            return grid.elements.contains { skeletonContainsTextField(targetKeypath: targetKeypath, in: $0) }
        case .ZStack(let stack):
            return stack.elements.contains { skeletonContainsTextField(targetKeypath: targetKeypath, in: $0) }
        case .Object(let object):
            return object.elements.values.contains { skeletonContainsTextField(targetKeypath: targetKeypath, in: $0) }
        case .Tabs(let tabs):
            return tabs.panels.contains { panel in
                panel.content.contains { skeletonContainsTextField(targetKeypath: targetKeypath, in: $0) }
            }
        default:
            return false
        }
    }

    private func skeletonContainsPicker(
        keypath: String,
        selectionStateKeypath: String,
        selectionActionKeypath: String,
        in element: SkeletonElement
    ) -> Bool {
        switch element {
        case .Picker(let picker):
            return picker.keypath == keypath &&
                picker.selectionStateKeypath == selectionStateKeypath &&
                picker.selectionActionKeypath == selectionActionKeypath
        case .VStack(let stack):
            return stack.elements.contains {
                skeletonContainsPicker(
                    keypath: keypath,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    in: $0
                )
            }
        case .HStack(let stack):
            return stack.elements.contains {
                skeletonContainsPicker(
                    keypath: keypath,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    in: $0
                )
            }
        case .ScrollView(let scroll):
            return scroll.elements.contains {
                skeletonContainsPicker(
                    keypath: keypath,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    in: $0
                )
            }
        case .Section(let section):
            return (section.header.map {
                skeletonContainsPicker(
                    keypath: keypath,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    in: $0
                )
            } ?? false) ||
                section.content.contains {
                    skeletonContainsPicker(
                        keypath: keypath,
                        selectionStateKeypath: selectionStateKeypath,
                        selectionActionKeypath: selectionActionKeypath,
                        in: $0
                    )
                } ||
                (section.footer.map {
                    skeletonContainsPicker(
                        keypath: keypath,
                        selectionStateKeypath: selectionStateKeypath,
                        selectionActionKeypath: selectionActionKeypath,
                        in: $0
                    )
                } ?? false)
        case .Reference(let reference):
            return reference.flowElementSkeleton.map {
                skeletonContainsPicker(
                    keypath: keypath,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    in: .VStack($0)
                )
            } ?? false
        case .List(let list):
            return list.flowElementSkeleton.map {
                skeletonContainsPicker(
                    keypath: keypath,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    in: .VStack($0)
                )
            } ?? false
        case .Grid(let grid):
            return grid.elements.contains {
                skeletonContainsPicker(
                    keypath: keypath,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    in: $0
                )
            }
        case .ZStack(let stack):
            return stack.elements.contains {
                skeletonContainsPicker(
                    keypath: keypath,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    in: $0
                )
            }
        case .Object(let object):
            return object.elements.values.contains {
                skeletonContainsPicker(
                    keypath: keypath,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    in: $0
                )
            }
        case .Tabs(let tabs):
            return tabs.panels.contains { panel in
                panel.content.contains {
                    skeletonContainsPicker(
                        keypath: keypath,
                        selectionStateKeypath: selectionStateKeypath,
                        selectionActionKeypath: selectionActionKeypath,
                        in: $0
                    )
                }
            }
        default:
            return false
        }
    }

    private func skeletonContainsList(keypath: String, topic: String?, in element: SkeletonElement) -> Bool {
        switch element {
        case .List(let list):
            if list.keypath == keypath && list.topic == topic {
                return true
            }
            return list.flowElementSkeleton.map { skeletonContainsList(keypath: keypath, topic: topic, in: .VStack($0)) } ?? false
        case .VStack(let stack):
            return stack.elements.contains { skeletonContainsList(keypath: keypath, topic: topic, in: $0) }
        case .HStack(let stack):
            return stack.elements.contains { skeletonContainsList(keypath: keypath, topic: topic, in: $0) }
        case .ScrollView(let scroll):
            return scroll.elements.contains { skeletonContainsList(keypath: keypath, topic: topic, in: $0) }
        case .Section(let section):
            return (section.header.map { skeletonContainsList(keypath: keypath, topic: topic, in: $0) } ?? false) ||
                section.content.contains { skeletonContainsList(keypath: keypath, topic: topic, in: $0) } ||
                (section.footer.map { skeletonContainsList(keypath: keypath, topic: topic, in: $0) } ?? false)
        case .Reference(let reference):
            return reference.flowElementSkeleton.map { skeletonContainsList(keypath: keypath, topic: topic, in: .VStack($0)) } ?? false
        case .Grid(let grid):
            return grid.elements.contains { skeletonContainsList(keypath: keypath, topic: topic, in: $0) }
        case .ZStack(let stack):
            return stack.elements.contains { skeletonContainsList(keypath: keypath, topic: topic, in: $0) }
        case .Object(let object):
            return object.elements.values.contains { skeletonContainsList(keypath: keypath, topic: topic, in: $0) }
        case .Tabs(let tabs):
            return tabs.panels.contains { panel in
                panel.content.contains { skeletonContainsList(keypath: keypath, topic: topic, in: $0) }
            }
        default:
            return false
        }
    }

    private func skeletonContainsTabs(tabsKeypath: String, in element: SkeletonElement) -> Bool {
        switch element {
        case .Tabs(let tabs):
            if tabs.tabsKeypath == tabsKeypath {
                return true
            }
            return tabs.panels.contains { panel in
                panel.content.contains { skeletonContainsTabs(tabsKeypath: tabsKeypath, in: $0) }
            }
        case .VStack(let stack):
            return stack.elements.contains { skeletonContainsTabs(tabsKeypath: tabsKeypath, in: $0) }
        case .HStack(let stack):
            return stack.elements.contains { skeletonContainsTabs(tabsKeypath: tabsKeypath, in: $0) }
        case .ScrollView(let scroll):
            return scroll.elements.contains { skeletonContainsTabs(tabsKeypath: tabsKeypath, in: $0) }
        case .Section(let section):
            return (section.header.map { skeletonContainsTabs(tabsKeypath: tabsKeypath, in: $0) } ?? false) ||
                section.content.contains { skeletonContainsTabs(tabsKeypath: tabsKeypath, in: $0) } ||
                (section.footer.map { skeletonContainsTabs(tabsKeypath: tabsKeypath, in: $0) } ?? false)
        case .Reference(let reference):
            return reference.flowElementSkeleton.map {
                skeletonContainsTabs(tabsKeypath: tabsKeypath, in: .VStack($0))
            } ?? false
        case .List(let list):
            return list.flowElementSkeleton.map {
                skeletonContainsTabs(tabsKeypath: tabsKeypath, in: .VStack($0))
            } ?? false
        case .Grid(let grid):
            return grid.elements.contains { skeletonContainsTabs(tabsKeypath: tabsKeypath, in: $0) }
        case .ZStack(let stack):
            return stack.elements.contains { skeletonContainsTabs(tabsKeypath: tabsKeypath, in: $0) }
        case .Object(let object):
            return object.elements.values.contains { skeletonContainsTabs(tabsKeypath: tabsKeypath, in: $0) }
        default:
            return false
        }
    }

    private func skeletonContainsTabsSelectionAction(keypath: String, in element: SkeletonElement) -> Bool {
        switch element {
        case .Tabs(let tabs):
            if tabs.selectionActionKeypath == keypath {
                return true
            }
            return tabs.panels.contains { panel in
                panel.content.contains { skeletonContainsTabsSelectionAction(keypath: keypath, in: $0) }
            }
        case .VStack(let stack):
            return stack.elements.contains { skeletonContainsTabsSelectionAction(keypath: keypath, in: $0) }
        case .HStack(let stack):
            return stack.elements.contains { skeletonContainsTabsSelectionAction(keypath: keypath, in: $0) }
        case .ScrollView(let scroll):
            return scroll.elements.contains { skeletonContainsTabsSelectionAction(keypath: keypath, in: $0) }
        case .Section(let section):
            return (section.header.map { skeletonContainsTabsSelectionAction(keypath: keypath, in: $0) } ?? false) ||
                section.content.contains { skeletonContainsTabsSelectionAction(keypath: keypath, in: $0) } ||
                (section.footer.map { skeletonContainsTabsSelectionAction(keypath: keypath, in: $0) } ?? false)
        case .Reference(let reference):
            return reference.flowElementSkeleton.map {
                skeletonContainsTabsSelectionAction(keypath: keypath, in: .VStack($0))
            } ?? false
        case .List(let list):
            return list.flowElementSkeleton.map {
                skeletonContainsTabsSelectionAction(keypath: keypath, in: .VStack($0))
            } ?? false
        case .Grid(let grid):
            return grid.elements.contains { skeletonContainsTabsSelectionAction(keypath: keypath, in: $0) }
        case .ZStack(let stack):
            return stack.elements.contains { skeletonContainsTabsSelectionAction(keypath: keypath, in: $0) }
        case .Object(let object):
            return object.elements.values.contains { skeletonContainsTabsSelectionAction(keypath: keypath, in: $0) }
        default:
            return false
        }
    }

    private func skeletonContainsSelectableList(
        keypath: String,
        topic: String?,
        selectionStateKeypath: String,
        selectionActionKeypath: String,
        selectionValueKeypath: String,
        activationActionKeypath: String,
        in element: SkeletonElement
    ) -> Bool {
        switch element {
        case .List(let list):
            if list.keypath == keypath &&
                list.topic == topic &&
                list.selectionMode == .single &&
                list.selectionStateKeypath == selectionStateKeypath &&
                list.selectionActionKeypath == selectionActionKeypath &&
                list.selectionValueKeypath == selectionValueKeypath &&
                list.activationActionKeypath == activationActionKeypath &&
                list.selectionPayloadMode == .itemID &&
                list.allowsEmptySelection == false {
                return true
            }
            return list.flowElementSkeleton.map {
                skeletonContainsSelectableList(
                    keypath: keypath,
                    topic: topic,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    selectionValueKeypath: selectionValueKeypath,
                    activationActionKeypath: activationActionKeypath,
                    in: .VStack($0)
                )
            } ?? false
        case .VStack(let stack):
            return stack.elements.contains {
                skeletonContainsSelectableList(
                    keypath: keypath,
                    topic: topic,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    selectionValueKeypath: selectionValueKeypath,
                    activationActionKeypath: activationActionKeypath,
                    in: $0
                )
            }
        case .HStack(let stack):
            return stack.elements.contains {
                skeletonContainsSelectableList(
                    keypath: keypath,
                    topic: topic,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    selectionValueKeypath: selectionValueKeypath,
                    activationActionKeypath: activationActionKeypath,
                    in: $0
                )
            }
        case .ScrollView(let scroll):
            return scroll.elements.contains {
                skeletonContainsSelectableList(
                    keypath: keypath,
                    topic: topic,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    selectionValueKeypath: selectionValueKeypath,
                    activationActionKeypath: activationActionKeypath,
                    in: $0
                )
            }
        case .Section(let section):
            return (section.header.map {
                skeletonContainsSelectableList(
                    keypath: keypath,
                    topic: topic,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    selectionValueKeypath: selectionValueKeypath,
                    activationActionKeypath: activationActionKeypath,
                    in: $0
                )
            } ?? false) ||
                section.content.contains {
                    skeletonContainsSelectableList(
                        keypath: keypath,
                        topic: topic,
                        selectionStateKeypath: selectionStateKeypath,
                        selectionActionKeypath: selectionActionKeypath,
                        selectionValueKeypath: selectionValueKeypath,
                        activationActionKeypath: activationActionKeypath,
                        in: $0
                    )
                } ||
                (section.footer.map {
                    skeletonContainsSelectableList(
                        keypath: keypath,
                        topic: topic,
                        selectionStateKeypath: selectionStateKeypath,
                        selectionActionKeypath: selectionActionKeypath,
                        selectionValueKeypath: selectionValueKeypath,
                        activationActionKeypath: activationActionKeypath,
                        in: $0
                    )
                } ?? false)
        case .Reference(let reference):
            return reference.flowElementSkeleton.map {
                skeletonContainsSelectableList(
                    keypath: keypath,
                    topic: topic,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    selectionValueKeypath: selectionValueKeypath,
                    activationActionKeypath: activationActionKeypath,
                    in: .VStack($0)
                )
            } ?? false
        case .Grid(let grid):
            return grid.elements.contains {
                skeletonContainsSelectableList(
                    keypath: keypath,
                    topic: topic,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    selectionValueKeypath: selectionValueKeypath,
                    activationActionKeypath: activationActionKeypath,
                    in: $0
                )
            }
        case .ZStack(let stack):
            return stack.elements.contains {
                skeletonContainsSelectableList(
                    keypath: keypath,
                    topic: topic,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    selectionValueKeypath: selectionValueKeypath,
                    activationActionKeypath: activationActionKeypath,
                    in: $0
                )
            }
        case .Object(let object):
            return object.elements.values.contains {
                skeletonContainsSelectableList(
                    keypath: keypath,
                    topic: topic,
                    selectionStateKeypath: selectionStateKeypath,
                    selectionActionKeypath: selectionActionKeypath,
                    selectionValueKeypath: selectionValueKeypath,
                    activationActionKeypath: activationActionKeypath,
                    in: $0
                )
            }
        case .Tabs(let tabs):
            return tabs.panels.contains { panel in
                panel.content.contains {
                    skeletonContainsSelectableList(
                        keypath: keypath,
                        topic: topic,
                        selectionStateKeypath: selectionStateKeypath,
                        selectionActionKeypath: selectionActionKeypath,
                        selectionValueKeypath: selectionValueKeypath,
                        activationActionKeypath: activationActionKeypath,
                        in: $0
                    )
                }
            }
        default:
            return false
        }
    }

    private func skeletonContainsTextKeypath(_ keypath: String, in elements: [SkeletonElement]) -> Bool {
        elements.contains { skeletonContainsTextKeypath(keypath, in: $0) }
    }

    private func skeletonContainsTextKeypath(_ keypath: String, in element: SkeletonElement) -> Bool {
        switch element {
        case .Text(let text):
            return text.keypath == keypath
        case .VStack(let stack):
            return stack.elements.contains { skeletonContainsTextKeypath(keypath, in: $0) }
        case .HStack(let stack):
            return stack.elements.contains { skeletonContainsTextKeypath(keypath, in: $0) }
        case .ScrollView(let scroll):
            return scroll.elements.contains { skeletonContainsTextKeypath(keypath, in: $0) }
        case .Section(let section):
            return (section.header.map { skeletonContainsTextKeypath(keypath, in: $0) } ?? false) ||
                section.content.contains { skeletonContainsTextKeypath(keypath, in: $0) } ||
                (section.footer.map { skeletonContainsTextKeypath(keypath, in: $0) } ?? false)
        case .Reference(let reference):
            return reference.flowElementSkeleton.map { skeletonContainsTextKeypath(keypath, in: .VStack($0)) } ?? false
        case .List(let list):
            return list.flowElementSkeleton.map { skeletonContainsTextKeypath(keypath, in: .VStack($0)) } ?? false
        case .Grid(let grid):
            return grid.elements.contains { skeletonContainsTextKeypath(keypath, in: $0) }
        case .ZStack(let stack):
            return stack.elements.contains { skeletonContainsTextKeypath(keypath, in: $0) }
        case .Object(let object):
            return object.elements.values.contains { skeletonContainsTextKeypath(keypath, in: $0) }
        case .Tabs(let tabs):
            return tabs.panels.contains { panel in
                panel.content.contains { skeletonContainsTextKeypath(keypath, in: $0) }
            }
        default:
            return false
        }
    }

    private func skeletonContainsLiteralText(_ text: String, in elements: [SkeletonElement]) -> Bool {
        elements.contains { skeletonContainsLiteralText(text, in: $0) }
    }

    private func skeletonContainsLiteralText(_ text: String, in element: SkeletonElement) -> Bool {
        switch element {
        case .Text(let skeletonText):
            return skeletonText.text == text
        case .VStack(let stack):
            return stack.elements.contains { skeletonContainsLiteralText(text, in: $0) }
        case .HStack(let stack):
            return stack.elements.contains { skeletonContainsLiteralText(text, in: $0) }
        case .ScrollView(let scroll):
            return scroll.elements.contains { skeletonContainsLiteralText(text, in: $0) }
        case .Section(let section):
            return (section.header.map { skeletonContainsLiteralText(text, in: $0) } ?? false) ||
                section.content.contains { skeletonContainsLiteralText(text, in: $0) } ||
                (section.footer.map { skeletonContainsLiteralText(text, in: $0) } ?? false)
        case .Reference(let reference):
            return reference.flowElementSkeleton.map { skeletonContainsLiteralText(text, in: .VStack($0)) } ?? false
        case .List(let list):
            return list.flowElementSkeleton.map { skeletonContainsLiteralText(text, in: .VStack($0)) } ?? false
        case .Grid(let grid):
            return grid.elements.contains { skeletonContainsLiteralText(text, in: $0) }
        case .ZStack(let stack):
            return stack.elements.contains { skeletonContainsLiteralText(text, in: $0) }
        case .Object(let object):
            return object.elements.values.contains { skeletonContainsLiteralText(text, in: $0) }
        case .Tabs(let tabs):
            return tabs.panels.contains { panel in
                panel.content.contains { skeletonContainsLiteralText(text, in: $0) }
            }
        default:
            return false
        }
    }

    private func skeletonTabPanel(id: String, in element: SkeletonElement) -> [SkeletonElement]? {
        switch element {
        case .Tabs(let tabs):
            if let panel = tabs.panels.first(where: { $0.id == id }) {
                return panel.content
            }
            for panel in tabs.panels {
                for child in panel.content {
                    if let match = skeletonTabPanel(id: id, in: child) {
                        return match
                    }
                }
            }
            return nil
        case .VStack(let stack):
            return skeletonTabPanel(id: id, in: stack.elements)
        case .HStack(let stack):
            return skeletonTabPanel(id: id, in: stack.elements)
        case .ScrollView(let scroll):
            return skeletonTabPanel(id: id, in: scroll.elements)
        case .Section(let section):
            if let header = section.header,
               let match = skeletonTabPanel(id: id, in: header) {
                return match
            }
            if let match = skeletonTabPanel(id: id, in: section.content) {
                return match
            }
            if let footer = section.footer {
                return skeletonTabPanel(id: id, in: footer)
            }
            return nil
        case .Reference(let reference):
            return reference.flowElementSkeleton.flatMap { skeletonTabPanel(id: id, in: .VStack($0)) }
        case .List(let list):
            return list.flowElementSkeleton.flatMap { skeletonTabPanel(id: id, in: .VStack($0)) }
        case .Grid(let grid):
            return skeletonTabPanel(id: id, in: grid.elements)
        case .ZStack(let stack):
            return skeletonTabPanel(id: id, in: stack.elements)
        case .Object(let object):
            return skeletonTabPanel(id: id, in: Array(object.elements.values))
        default:
            return nil
        }
    }

    private func skeletonTabPanel(id: String, in elements: [SkeletonElement]) -> [SkeletonElement]? {
        for element in elements {
            if let panel = skeletonTabPanel(id: id, in: element) {
                return panel
            }
        }
        return nil
    }

    private func skeletonStyleRoles(in element: SkeletonElement, depth: Int = 0) -> [String] {
        guard depth < 64 else {
            return []
        }

        var roles: [String] = []

        func append(_ modifiers: SkeletonModifiers?) {
            guard let role = modifiers?.styleRole?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !role.isEmpty else {
                return
            }
            roles.append(role)
        }

        func child(_ element: SkeletonElement) -> [String] {
            skeletonStyleRoles(in: element, depth: depth + 1)
        }

        switch element {
        case .Text(let text):
            append(text.modifiers)
        case .AttachmentField(let attachmentField):
            append(attachmentField.modifiers)
        case .FileUpload(let fileUpload):
            append(fileUpload.modifiers)
        case .TextField(let textField):
            append(textField.modifiers)
        case .TextArea(let textArea):
            append(textArea.modifiers)
        case .Image(let image):
            append(image.modifiers)
        case .Spacer(let spacer):
            append(spacer.modifiers)
        case .VStack(let stack):
            append(stack.modifiers)
            stack.elements.forEach { roles.append(contentsOf: child($0)) }
        case .HStack(let stack):
            append(stack.modifiers)
            stack.elements.forEach { roles.append(contentsOf: child($0)) }
        case .ZStack(let stack):
            append(stack.modifiers)
            stack.elements.forEach { roles.append(contentsOf: child($0)) }
        case .ScrollView(let scroll):
            append(scroll.modifiers)
            scroll.elements.forEach { roles.append(contentsOf: child($0)) }
        case .Section(let section):
            append(section.modifiers)
            if let header = section.header {
                roles.append(contentsOf: child(header))
            }
            section.content.forEach { roles.append(contentsOf: child($0)) }
            if let footer = section.footer {
                roles.append(contentsOf: child(footer))
            }
        case .List(let list):
            append(list.modifiers)
        case .Reference(let reference):
            append(reference.modifiers)
        case .Grid(let grid):
            append(grid.modifiers)
            if let itemSkeleton = grid.itemSkeleton {
                roles.append(contentsOf: child(itemSkeleton))
            }
            grid.elements.forEach { roles.append(contentsOf: child($0)) }
        case .Button(let button):
            append(button.modifiers)
        case .Divider(let divider):
            append(divider.modifiers)
        case .Toggle(let toggle):
            append(toggle.modifiers)
        case .Picker(let picker):
            append(picker.modifiers)
        case .Visualization(let visualization):
            append(visualization.modifiers)
        case .Unsupported(let unsupported):
            append(unsupported.modifiers)
        case .Object(let object):
            append(object.modifiers)
            object.elements.values.forEach { roles.append(contentsOf: child($0)) }
        case .Tabs(let tabs):
            append(tabs.modifiers)
            tabs.panels.forEach { panel in
                append(panel.modifiers)
                panel.content.forEach { roles.append(contentsOf: child($0)) }
            }
        }

        return roles
    }

    private func skeletonContainsGrid(keypath: String, in element: SkeletonElement) -> Bool {
        switch element {
        case .Grid(let grid):
            if grid.keypath == keypath {
                return true
            }
            if let itemSkeleton = grid.itemSkeleton, skeletonContainsGrid(keypath: keypath, in: itemSkeleton) {
                return true
            }
            return grid.elements.contains { skeletonContainsGrid(keypath: keypath, in: $0) }
        case .VStack(let stack):
            return stack.elements.contains { skeletonContainsGrid(keypath: keypath, in: $0) }
        case .HStack(let stack):
            return stack.elements.contains { skeletonContainsGrid(keypath: keypath, in: $0) }
        case .ScrollView(let scroll):
            return scroll.elements.contains { skeletonContainsGrid(keypath: keypath, in: $0) }
        case .Section(let section):
            return (section.header.map { skeletonContainsGrid(keypath: keypath, in: $0) } ?? false) ||
                section.content.contains { skeletonContainsGrid(keypath: keypath, in: $0) } ||
                (section.footer.map { skeletonContainsGrid(keypath: keypath, in: $0) } ?? false)
        case .Reference(let reference):
            return reference.flowElementSkeleton.map { skeletonContainsGrid(keypath: keypath, in: .VStack($0)) } ?? false
        case .List(let list):
            return list.flowElementSkeleton.map { skeletonContainsGrid(keypath: keypath, in: .VStack($0)) } ?? false
        case .ZStack(let stack):
            return stack.elements.contains { skeletonContainsGrid(keypath: keypath, in: $0) }
        case .Object(let object):
            return object.elements.values.contains { skeletonContainsGrid(keypath: keypath, in: $0) }
        case .Tabs(let tabs):
            return tabs.panels.contains { panel in
                panel.content.contains { skeletonContainsGrid(keypath: keypath, in: $0) }
            }
        default:
            return false
        }
    }

    private func skeletonContainsReference(keypath: String, topic: String, in element: SkeletonElement) -> Bool {
        switch element {
        case .Reference(let reference):
            return reference.keypath == keypath && reference.topic == topic
        case .VStack(let stack):
            return stack.elements.contains { skeletonContainsReference(keypath: keypath, topic: topic, in: $0) }
        case .HStack(let stack):
            return stack.elements.contains { skeletonContainsReference(keypath: keypath, topic: topic, in: $0) }
        case .ScrollView(let scroll):
            return scroll.elements.contains { skeletonContainsReference(keypath: keypath, topic: topic, in: $0) }
        case .Section(let section):
            if let header = section.header, skeletonContainsReference(keypath: keypath, topic: topic, in: header) {
                return true
            }
            if let footer = section.footer, skeletonContainsReference(keypath: keypath, topic: topic, in: footer) {
                return true
            }
            return section.content.contains { skeletonContainsReference(keypath: keypath, topic: topic, in: $0) }
        case .Grid(let grid):
            if let itemSkeleton = grid.itemSkeleton,
               skeletonContainsReference(keypath: keypath, topic: topic, in: itemSkeleton) {
                return true
            }
            return grid.elements.contains { skeletonContainsReference(keypath: keypath, topic: topic, in: $0) }
        case .ZStack(let stack):
            return stack.elements.contains { skeletonContainsReference(keypath: keypath, topic: topic, in: $0) }
        case .Object(let object):
            return object.elements.values.contains { skeletonContainsReference(keypath: keypath, topic: topic, in: $0) }
        case .Tabs(let tabs):
            return tabs.panels.contains { panel in
                panel.content.contains { skeletonContainsReference(keypath: keypath, topic: topic, in: $0) }
            }
        default:
            return false
        }
    }

}

private actor BindingTestIdentityVault: IdentityVaultProtocol {
    private struct StoredIdentity {
        var identity: Identity
        let signingPrivateKey: P256.Signing.PrivateKey
    }

    private var identitiesByContext: [String: String] = [:]
    private var identitiesByUUID: [String: StoredIdentity] = [:]
    private var idCounter = 1
    private let vaultReference = "binding.test.identityvault:\(UUID().uuidString)"

    func identityVaultReference() async -> String? {
        vaultReference
    }

    func initialize() async -> IdentityVaultProtocol {
        self
    }

    func addIdentity(identity: inout Identity, for identityContext: String) async {
        let signingPrivateKey = P256.Signing.PrivateKey()
        identity.identityVault = self
        identity.homeVaultReference = vaultReference
        identity.publicSecureKey = SecureKey(
            date: Date(),
            privateKey: false,
            use: .signature,
            algorithm: .ECDSA,
            size: 256,
            curveType: .P256,
            x: nil,
            y: nil,
            compressedKey: signingPrivateKey.publicKey.x963Representation
        )

        identitiesByContext[identityContext] = identity.uuid
        identitiesByUUID[identity.uuid] = StoredIdentity(
            identity: identity,
            signingPrivateKey: signingPrivateKey
        )
    }

    func identity(for identityContext: String, makeNewIfNotFound: Bool) async -> Identity? {
        if let uuid = identitiesByContext[identityContext],
           let stored = identitiesByUUID[uuid] {
            let identity = stored.identity
            identity.identityVault = self
            identity.homeVaultReference = vaultReference
            return identity
        }
        guard makeNewIfNotFound else { return nil }

        let suffix = String(format: "%012d", idCounter)
        idCounter += 1
        let uuidString = "00000000-0000-0000-0000-\(suffix)"
        var identity = Identity(uuidString, displayName: identityContext, identityVault: self)
        await addIdentity(identity: &identity, for: identityContext)
        return await self.identity(for: identityContext, makeNewIfNotFound: false)
    }

    func identity(forUUID uuid: String) async -> Identity? {
        guard let stored = identitiesByUUID[uuid] else {
            return nil
        }
        let identity = stored.identity
        identity.identityVault = self
        identity.homeVaultReference = vaultReference
        return identity
    }

    func identityExistInVault(_ identity: Identity) async -> Bool {
        guard let stored = identitiesByUUID[identity.uuid],
              let requestedFingerprint = identity.signingPublicKeyFingerprint,
              let storedFingerprint = stored.identity.signingPublicKeyFingerprint else {
            return false
        }
        return requestedFingerprint == storedFingerprint
    }

    func saveIdentity(_ identity: Identity) async {
        guard let stored = identitiesByUUID[identity.uuid] else {
            return
        }
        let updatedIdentity = identity
        updatedIdentity.identityVault = self
        updatedIdentity.homeVaultReference = vaultReference
        identitiesByContext[updatedIdentity.displayName] = updatedIdentity.uuid
        identitiesByUUID[updatedIdentity.uuid] = StoredIdentity(
            identity: updatedIdentity,
            signingPrivateKey: stored.signingPrivateKey
        )
    }

    func signMessageForIdentity(messageData: Data, identity: Identity) async throws -> Data {
        guard let stored = identitiesByUUID[identity.uuid] else {
            throw ScopedSecretProviderError.unavailable
        }
        let signature = try stored.signingPrivateKey.signature(for: messageData)
        return signature.derRepresentation
    }

    func verifySignature(signature: Data, messageData: Data, for identity: Identity) async throws -> Bool {
        guard let compressedKey = identity.publicSecureKey?.compressedKey else {
            return false
        }
        let publicKey = try P256.Signing.PublicKey(x963Representation: compressedKey)
        let ecdsaSignature = try P256.Signing.ECDSASignature(derRepresentation: signature)
        return publicKey.isValidSignature(ecdsaSignature, for: messageData)
    }

    func randomBytes64() async -> Data? {
        Data(repeating: 0xAB, count: 64)
    }

    func aquireKeyForTag(tag: String) async throws -> (key: String, iv: String) {
        ("binding-test-key-\(tag)", "binding-test-iv-\(tag)")
    }
}

private extension BindingTests {
    static let testIdentityVault = BindingTestIdentityVault()

    static func remoteHavenWorkbenchFixtureConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "HAVEN Workbench")
        configuration.description = "Remote CellScaffold workbench fixture for Binding catalog import regression coverage."
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: "cell:///WorkItem",
            sourceCellName: "WorkItemCell",
            purpose: "HAVEN project workbench",
            purposeDescription: "Project workbench with WorkItem, portfolio, GitHub sync, vault and AI references.",
            interests: [
                "haven",
                "projects",
                "work-items",
                "portfolio",
                "github",
                "docs",
                "purposeRef=haven.work.board.view"
            ],
            menuSlots: ["upperMid", "lowerMid"]
        )

        var workItemsReference = CellReference(endpoint: "cell:///WorkItem", label: "workItems")
        workItemsReference.setKeysAndValues = [
            KeyValue(key: "state", value: nil),
            KeyValue(key: "syncStatus", value: nil)
        ]
        configuration.addReference(workItemsReference)

        var projectPortfolioReference = CellReference(endpoint: "cell://127.0.0.1/ProjectPortfolio", label: "projectPortfolio")
        projectPortfolioReference.setKeysAndValues = [
            KeyValue(key: "state", value: nil),
            KeyValue(key: "feed", value: nil)
        ]
        configuration.addReference(projectPortfolioReference)

        var githubSyncReference = CellReference(endpoint: "cell://localhost/GitHubWorkSync", label: "githubSync")
        githubSyncReference.setKeysAndValues = [
            KeyValue(key: "state", value: nil),
            KeyValue(key: "syncStatus", value: nil)
        ]
        configuration.addReference(githubSyncReference)

        var ideaWorkspaceReference = CellReference(endpoint: "cell:///IdeaTaskWorkspace", label: "ideaWorkspace")
        ideaWorkspaceReference.setKeysAndValues = [
            KeyValue(key: "refresh", value: .object([:])),
            KeyValue(key: "state", value: nil)
        ]
        configuration.addReference(ideaWorkspaceReference)

        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "workItems.state.summaryText")),
            .Text(SkeletonText(keypath: "projectPortfolio.state.summaryText")),
            .Text(SkeletonText(keypath: "githubSync.state.importedItemCount")),
            .Button(
                SkeletonButton(
                    keypath: "addConfiguration",
                    label: "Open portfolio",
                    payload: .object([
                        "configurationLookup": .object([
                            "name": .string("Project Portfolio"),
                            "sourceCellEndpoint": .string("cell://127.0.0.1/ProjectPortfolio")
                        ])
                    ])
                )
            )
        ]))
        return configuration
    }

    static func remoteArendalsukaParticipantProgramFixtureConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Arendalsuka Participant Program")
        configuration.description = "Remote CellScaffold Arendalsuka participant fixture for Binding catalog import regression coverage."
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: "cell:///ArendalsukaParticipantProgram",
            sourceCellName: "ArendalsukaParticipantProgramCell",
            purpose: "Arendalsuka participant program",
            purposeDescription: "Participant-facing Arendalsuka program and navigation surface.",
            interests: [
                "arendalsuka",
                "participant",
                "program",
                "agenda",
                "navigation",
                "purposeRef=arendalsuka.program.navigate"
            ],
            menuSlots: ["upperMid", "lowerMid"]
        )

        var atlasReference = CellReference(endpoint: "cell:///ArendalsukaEventAtlas", label: "arendalsukaAtlas")
        atlasReference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(atlasReference)

        var participantReference = CellReference(endpoint: "cell:///ArendalsukaParticipantProgram", label: "arendalsukaParticipant")
        participantReference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(participantReference)

        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "arendalsukaParticipant.state.workspace.title")),
            .Text(SkeletonText(keypath: "arendalsukaAtlas.state.workspace.status")),
            .Button(
                SkeletonButton(
                    keypath: "addConfiguration",
                    label: "Open atlas",
                    payload: .object([
                        "configurationLookup": .object([
                            "name": .string("Arendalsuka Event Atlas"),
                            "sourceCellEndpoint": .string("cell:///ArendalsukaEventAtlas")
                        ])
                    ])
                )
            )
        ]))
        return configuration
    }

    static func remoteArendalsukaEventAtlasFixtureConfiguration() -> CellConfiguration {
        var configuration = CellConfiguration(name: "Arendalsuka Event Atlas")
        configuration.description = "Remote CellScaffold Arendalsuka event atlas fixture for Binding catalog import regression coverage."
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: "cell:///ArendalsukaEventAtlas",
            sourceCellName: "ArendalsukaEventAtlasCell",
            purpose: "Arendalsuka event atlas",
            purposeDescription: "Source-backed Arendalsuka program import and inspection surface.",
            interests: [
                "arendalsuka",
                "program",
                "agenda",
                "matching",
                "purposeRef=arendalsuka.event-atlas.inspect"
            ],
            menuSlots: ["upperMid", "lowerMid", "lowerRight"]
        )

        var atlasReference = CellReference(endpoint: "cell:///ArendalsukaEventAtlas", label: "arendalsukaAtlas")
        atlasReference.setKeysAndValues = [KeyValue(key: "state", value: nil)]
        configuration.addReference(atlasReference)
        configuration.skeleton = .VStack(SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "arendalsukaAtlas.state.workspace.title")),
            .Text(SkeletonText(keypath: "arendalsukaAtlas.state.workspace.status"))
        ]))
        return configuration
    }

    static func cellEndpointStrings(in configuration: CellConfiguration) throws -> [String] {
        let data = try JSONEncoder().encode(configuration)
        let object = try JSONSerialization.jsonObject(with: data)
        var endpoints: [String] = []

        func collect(_ value: Any) {
            switch value {
            case let string as String:
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("cell://") {
                    endpoints.append(trimmed)
                }
            case let dictionary as [String: Any]:
                dictionary.values.forEach(collect)
            case let array as [Any]:
                array.forEach(collect)
            default:
                break
            }
        }

        collect(object)
        return endpoints
    }

    static func isLocalCellEndpoint(_ endpoint: String) -> Bool {
        guard let components = URLComponents(string: endpoint),
              components.scheme?.lowercased() == "cell"
        else {
            return false
        }

        let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return host.isEmpty
            || host == "localhost"
            || host == "127.0.0.1"
            || host == "::1"
            || host == "[::1]"
    }
}

private final class RootOnlyStateCell: GeneralCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
        agreementTemplate.addGrant("r---", for: "state")
        await addInterceptForGet(requester: owner, key: "state") { _, _ in
            .object(Self.stateObject)
        }
    }

    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private static let stateObject: Object = [
        "workspace": .object([
            "title": .string("Conference Participant Portal"),
            "subtitle": .string("Profile, recommended people, and meetings in one low-friction flow.")
        ]),
        "program": .object([
            "savedSessions": .list([
                .object(["title": .string("Opening Keynote")]),
                .object(["title": .string("Shared Relations Roundtable")])
            ])
        ])
    ]
}

private final class EditableConfigurationSourceFixtureCell: GeneralCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
        agreementTemplate.addGrant("r---", for: "editableCellConfigurationState")
        agreementTemplate.addGrant("r---", for: "skeletonConfiguration")
        await addInterceptForGet(requester: owner, key: "editableCellConfigurationState") { _, _ in
            .object(Self.editableState)
        }
        await addInterceptForGet(requester: owner, key: "skeletonConfiguration") { _, _ in
            .cellConfiguration(Self.originalConfiguration)
        }
    }

    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private static var editableState: Object {
        [
            "configuration": .cellConfiguration(overrideConfiguration),
            "fallbackConfiguration": .cellConfiguration(originalConfiguration),
            "revision": .integer(3),
            "hasStoredOverride": .bool(true),
            "canEdit": .bool(true),
            "sourceCellEndpoint": .string("cell:///EditableConfigurationSourceFixture"),
            "sourceCellName": .string("EditableConfigurationSourceFixtureCell"),
            "accessSummary": .string("Fixture editable state")
        ]
    }

    private static var overrideConfiguration: CellConfiguration {
        var configuration = CellConfiguration(name: "Editable Override Workspace")
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: "cell:///EditableConfigurationSourceFixture",
            sourceCellName: "EditableConfigurationSourceFixtureCell",
            purpose: "Editable override",
            purposeDescription: "Local override for lookup testing",
            interests: ["test"],
            menuSlots: ["upperLeft"]
        )
        configuration.addReference(CellReference(endpoint: "cell:///RootOnlyState", label: "rootState"))
        configuration.skeleton = .Text(SkeletonText(text: "Override"))
        return configuration
    }

    private static var originalConfiguration: CellConfiguration {
        var configuration = CellConfiguration(name: "Original Published Workspace")
        configuration.discovery = CellConfigurationDiscovery(
            sourceCellEndpoint: "cell:///EditableConfigurationSourceFixture",
            sourceCellName: "EditableConfigurationSourceFixtureCell",
            purpose: "Original",
            purposeDescription: "Published fallback",
            interests: ["test"],
            menuSlots: ["upperLeft"]
        )
        configuration.addReference(CellReference(endpoint: "cell:///RootOnlyState", label: "rootState"))
        configuration.skeleton = .Text(SkeletonText(text: "Original"))
        return configuration
    }
}

private final class BindingSpatialV2FixtureCell: GeneralCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")
        await addInterceptForGet(requester: owner, key: "state") { _, _ in
            .object(Self.stateObject)
        }
        await addInterceptForSet(requester: owner, key: "dispatchAction") { _, value, _ in
            .object([
                "ok": .bool(true),
                "status": .string("preview-ready"),
                "action": value,
                "state": .object(Self.stateObject)
            ])
        }
    }

    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private static let stateObject: Object = [
        "schema": .string("haven.spatial.feature.v2"),
        "summary": .string("Spatial v2 AR scene fixture"),
        "nativeAdapter": .string("Binding native AR adapter candidate"),
        "anchor": .object([
            "schema": .string("haven.spatial.anchor.v1"),
            "anchorId": .string("venue-ar-sign"),
            "coordinateFrame": .string("wgs84"),
            "locationSummary": .string("Oslo venue coarse · 120m accuracy"),
            "poseSummary": .string("Position 0, 1.4, -2 · confidence 0.82"),
            "location": .object([
                "geoRef": .string("wgs84"),
                "lng": .float(10.7522),
                "lat": .float(59.9139),
                "altitudeMeters": .float(12.5),
                "accuracyMeters": .float(120),
                "disclosure": .string("coarse")
            ]),
            "pose": .object([
                "positionMeters": .object([
                    "x": .float(0),
                    "y": .float(1.4),
                    "z": .float(-2.0)
                ]),
                "orientationQuaternion": .object([
                    "x": .float(0),
                    "y": .float(0),
                    "z": .float(0),
                    "w": .float(1)
                ]),
                "scale": .object([
                    "x": .float(1),
                    "y": .float(1),
                    "z": .float(1)
                ]),
                "confidence": .float(0.82)
            ])
        ]),
        "assetManifest": .object([
            "primaryAssetId": .string("venue-model"),
            "primaryAssetRef": .string("vault://assets/venue-model.usdz"),
            "primaryDigest": .string("abc123spatialv2"),
            "primaryMimeType": .string("model/vnd.usdz+zip"),
            "cachePolicy": .string("sha256-revision-ttl")
        ]),
        "accessPolicy": .object([
            "viewerRoles": .string("guest, member"),
            "policyRefs": .string("agreement://venue-ar-public"),
            "denialBehavior": .string("structured-denied"),
            "assetDeliverySummary": .string("Asset blobs stay in vault-backed refs")
        ])
    ]
}

enum ConferenceVerifierFixtureSupport {
    static func ensureRegistered(on resolver: CellResolver) async {
        await register(
            name: "BindingSpatialV2Fixture",
            type: BindingSpatialV2FixtureCell.self,
            scope: .identityUnique,
            on: resolver
        )
        await register(
            name: "ConferenceParticipantPreviewShellFixture",
            type: ConferenceParticipantPreviewShellFixtureCell.self,
            on: resolver
        )
        await register(
            name: "ConferencePublicShellFixture",
            type: ConferencePublicShellFixtureCell.self,
            scope: .identityUnique,
            on: resolver
        )
        await register(
            name: "ConferenceSponsorShellFixture",
            type: ConferenceSponsorShellFixtureCell.self,
            on: resolver
        )
    }

    private static func register<CellType: Emit & OwnerInstantiable>(
        name: String,
        type: CellType.Type,
        scope: CellUsageScope = .scaffoldUnique,
        on resolver: CellResolver
    ) async {
        do {
            try await resolver.addCellResolve(
                name: name,
                cellScope: scope,
                persistency: .persistant,
                identityDomain: "private",
                type: type
            )
        } catch {
            let description = String(describing: error).lowercased()
            guard !description.contains("duplicatedendpointname"),
                  !description.contains("duplicatedcodingname"),
                  !description.contains("registeratalreadytakenendpoint") else {
                return
            }
            Issue.record("Could not register \(name) fixture: \(error)")
        }
    }
}

private func timelineCard(
    title: String,
    subtitle: String,
    detail: String,
    note: String
) -> ValueType {
    .object([
        "title": .string(title),
        "subtitle": .string(subtitle),
        "detail": .string(detail),
        "note": .string(note)
    ])
}

private func titleDetailRow(
    title: String,
    detail: String
) -> ValueType {
    .object([
        "title": .string(title),
        "detail": .string(detail)
    ])
}

private func titleSubtitleDetailRow(
    title: String,
    subtitle: String,
    detail: String
) -> ValueType {
    .object([
        "title": .string(title),
        "subtitle": .string(subtitle),
        "detail": .string(detail)
    ])
}

private final class ConferenceParticipantPreviewShellFixtureCell: GeneralCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
        try? await ensureRuntimeReady()
    }

    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override func installCellRuntimeBindingsForAccess() async throws {
        let owner = storedOwnerIdentity
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("r---", for: "skeletonConfiguration")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")

        await addInterceptForGet(requester: owner, key: "state") { _, _ in
            .object(Self.stateObject)
        }
        await addInterceptForGet(requester: owner, key: "skeletonConfiguration") { _, _ in
            .null
        }
        await addInterceptForSet(requester: owner, key: "dispatchAction") { _, _, _ in
            .object([
                "status": .string("ok"),
                "state": .object(Self.stateObject)
            ])
        }
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private static let stateObject: Object = [
        "workspace": .object([
            "title": .string("Conference Participant Portal"),
            "subtitle": .string("Agenda, meetings, and shared relations in one workspace."),
            "participantBadge": .string("Participant"),
            "programBadge": .string("Program: ready"),
            "matchBadge": .string("Matches: active"),
            "meetingBadge": .string("Meetings: 3 confirmed"),
            "nextStep": .string("Review your recommended sessions and confirm the next meeting request."),
            "previewNotice": .string("Preview wrapper is exposing the same state contract as the real participant shell.")
        ]),
        "access": .object([
            "headline": .string("Conference access overview")
        ]),
        "program": .object([
            "intro": .string("Your agenda is tuned for policy, coordination, and follow-up."),
            "agendaSummary": .string("2 saved session(s) · 6 recommended session(s)."),
            "viewSummary": .string("Currently showing your saved agenda."),
            "trackSummary": .string("Governance and implementation are both in focus."),
            "status": .string("Agenda sync is healthy."),
            "storageSummary": .string("All agenda selections are stored."),
            "savedSessions": .list([
                .object([
                    "title": .string("Opening Keynote"),
                    "subtitle": .string("Shared language for trusted infrastructure")
                ]),
                .object([
                    "title": .string("Shared Relations Roundtable"),
                    "subtitle": .string("Operational follow-up between ecosystem teams")
                ])
            ])
        ]),
        "matches": .object([
            "intro": .string("These people are aligned with your current goals."),
            "filterSummary": .string("Filter is set to governance and interoperability."),
            "status": .string("Recommendations are derived from onboarding interests, purpose signals, and optional track focus."),
            "recommendationSummary": .string("3 recommended people with explainability."),
            "recommendations": .list([
                .object([
                    "displayName": .string("Ane Solberg"),
                    "headline": .string("Public sector interoperability lead")
                ]),
                .object([
                    "displayName": .string("Mads Hovden"),
                    "headline": .string("Policy and compliance facilitator")
                ]),
                .object([
                    "displayName": .string("Lea Heger"),
                    "headline": .string("Digital service design")
                ])
            ])
        ]),
        "meetings": .object([
            "intro": .string("Meeting planning stays inside the participant shell."),
            "requestSummary": .string("0 shared request(s) visible."),
            "slotSummary": .string("5 viable slots overlap with your saved sessions."),
            "meetingSummary": .string("0 shared meeting(s) visible."),
            "exportStatus": .string("No iCal export prepared yet."),
            "confirmedMeetings": .list([])
        ]),
        "sharedConnections": .object([
            "intro": .string("Shared relations help you continue the right conversations."),
            "accessSummary": .string("Shared threads are visible to participating parties."),
            "connectionSummary": .string("0 shared relation(s) visible."),
            "chatSummary": .string("0 shared message(s) visible."),
            "connections": .list([]),
            "recentMessages": .list([])
        ])
    ]
}

private final class ConferencePublicShellFixtureCell: GeneralCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("r---", for: "feed")
        agreementTemplate.addGrant("r---", for: "skeletonConfiguration")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")

        await addInterceptForGet(requester: owner, key: "state") { _, _ in
            .object(Self.stateObject)
        }
        await addInterceptForGet(requester: owner, key: "skeletonConfiguration") { _, _ in
            .null
        }
        await addInterceptForSet(requester: owner, key: "dispatchAction") { _, _, _ in
            .object([
                "status": .string("ok"),
                "state": .object(Self.stateObject)
            ])
        }
    }

    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private static let stateObject: Object = [
        "workspace": .object([
            "title": .string("AI & Digital Independence"),
            "subtitle": .string("Conference public surface for the live program, people, articles and facilities."),
            "dateBadge": .string("30. mars"),
            "venueBadge": .string("Oslo"),
            "ctaTitle": .string("Join the public program"),
            "ctaDetail": .string("Tracks, sessions and facilities are now published for everyone.")
        ]),
        "access": .object([
            "headline": .string("Public conference publication scope"),
            "ownerScope": .string("Owner: conference public publisher"),
            "readScope": .string("Read: public audience"),
            "writeScope": .string("Write: public publishing pipeline"),
            "deliveryScope": .string("Delivery: published surfaces only"),
            "storageScope": .string("Storage: scaffold publication state"),
            "notes": .string("This fixture mirrors the public-shell contract without pretending to be staging."),
            "keypathMatrix": .list([
                timelineCard(title: "workspace.*", subtitle: "Public landing", detail: "Title, badges and CTA", note: "Readable"),
                timelineCard(title: "tracks/sessions", subtitle: "Published program", detail: "Tracks and sessions visible to attendees", note: "Readable")
            ])
        ]),
        "tracksIntro": .string("Tracks currently highlighted for the public audience."),
        "tracks": .list([
            titleDetailRow(title: "Trusted AI", detail: "Governance, controls and public interest deployment."),
            titleDetailRow(title: "Digital Independence", detail: "Infrastructure, procurement and resilient service design.")
        ]),
        "sessionsIntro": .string("Featured sessions from the published conference program."),
        "sessions": .list([
            titleSubtitleDetailRow(title: "Opening keynote", subtitle: "Main stage", detail: "Why trustworthy AI needs better institutional memory."),
            titleSubtitleDetailRow(title: "Implementation roundtable", subtitle: "Room B", detail: "How public-sector teams move from pilots to dependable delivery.")
        ]),
        "peopleIntro": .string("People currently highlighted on the public surface."),
        "people": .list([
            titleSubtitleDetailRow(title: "Ane Solberg", subtitle: "Public sector interoperability", detail: "Speaking on procurement, coordination and follow-up."),
            titleSubtitleDetailRow(title: "Mads Hovden", subtitle: "Policy and compliance", detail: "Moderating the governance track discussion.")
        ]),
        "articlesIntro": .string("Editorial highlights and conference explainers."),
        "articles": .list([
            titleSubtitleDetailRow(title: "Why this conference now", subtitle: "Editorial", detail: "Explains the public framing for AI and digital independence."),
            titleSubtitleDetailRow(title: "How to navigate the day", subtitle: "Guide", detail: "Program guide for attendees and visitors.")
        ]),
        "facilitiesIntro": .string("Facilities and practical venue information."),
        "facilities": .list([
            titleSubtitleDetailRow(title: "Main stage", subtitle: "Ground floor", detail: "Keynotes and plenary sessions."),
            titleSubtitleDetailRow(title: "Quiet work area", subtitle: "Second floor", detail: "Space for follow-up and focused conversation.")
        ])
    ]
}

private final class ConferenceSponsorShellFixtureCell: GeneralCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
        agreementTemplate.addGrant("r---", for: "state")
        agreementTemplate.addGrant("r---", for: "skeletonConfiguration")
        agreementTemplate.addGrant("rw--", for: "dispatchAction")

        await addInterceptForGet(requester: owner, key: "state") { _, _ in
            .object(Self.stateObject)
        }
        await addInterceptForGet(requester: owner, key: "skeletonConfiguration") { _, _ in
            .null
        }
        await addInterceptForSet(requester: owner, key: "dispatchAction") { _, _, _ in
            .object([
                "status": .string("ok"),
                "state": .object(Self.stateObject)
            ])
        }
    }

    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }

    private static let stateObject: Object = [
        "workspace": .object([
            "title": .string("Conference Sponsor Follow-up"),
            "subtitle": .string("Sponsor-owned inbox, compliance and retention overview."),
            "conferenceBadge": .string("Conference"),
            "sponsorBadge": .string("Sponsor"),
            "pipelineBadge": .string("Pipeline active"),
            "retentionBadge": .string("Retention ready"),
            "creditBadge": .string("Credits healthy"),
            "nextStep": .string("Refresh the inbox, prepare export, and clear the retention review queue."),
            "previewNotice": .string("Fixture mirrors the sponsor-shell contract for deterministic verification.")
        ]),
        "access": .object([
            "headline": .string("Sponsor follow-up access scope"),
            "ownerScope": .string("Owner: sponsor workspace"),
            "readScope": .string("Read: sponsor lead inbox"),
            "writeScope": .string("Write: sponsor follow-up operations"),
            "deliveryScope": .string("Delivery: sponsor exports and unlock handoff"),
            "storageScope": .string("Storage: consented sponsor data only"),
            "notes": .string("Retention and export steps stay inside sponsor-owned state."),
            "keypathMatrix": .list([
                timelineCard(title: "followUp.*", subtitle: "Lead inbox", detail: "Pickup and qualified leads", note: "Readable"),
                timelineCard(title: "retention.*", subtitle: "Retention controls", detail: "Unlocks, reclaim and review queue", note: "Readable")
            ])
        ]),
        "followUp": .object([
            "intro": .string("Lead inbox for sponsor-owned pickup and qualification."),
            "pickupSummary": .string("2 pickup leads waiting."),
            "qualificationSummary": .string("1 qualified lead ready for export."),
            "status": .string("Inbox is synchronized."),
            "pickupLeads": .list([
                timelineCard(title: "Ingrid Nilsen", subtitle: "Municipal AI lead", detail: "Asked for a short follow-up after the keynote.", note: "Pickup"),
                timelineCard(title: "Jon Hauge", subtitle: "Digital procurement", detail: "Interested in sponsor roundtable materials.", note: "Pickup")
            ]),
            "qualifiedLeads": .list([
                timelineCard(title: "Lea Heger", subtitle: "Service design", detail: "Qualified after consent review and sponsor handoff.", note: "Qualified")
            ])
        ]),
        "compliance": .object([
            "intro": .string("Consent, agreement and chronicle review for sponsor follow-up."),
            "consentSummary": .string("All exported leads have explicit consent receipts."),
            "agreementSummary": .string("Agreement template is current."),
            "chronicleSummary": .string("Chronicle entries ready for sponsor audit."),
            "status": .string("Compliance checks are green."),
            "consentReceipts": .list([
                timelineCard(title: "Receipt #104", subtitle: "Lea Heger", detail: "Consent captured for sponsor follow-up export.", note: "Valid")
            ])
        ]),
        "retention": .object([
            "creditSummary": .string("Credits remain within sponsor allocation."),
            "unlockSummary": .string("1 unlock action is pending approval."),
            "reclaimSummary": .string("No reclaims needed right now."),
            "reviewSummary": .string("2 review items in the retention queue."),
            "policySummary": .string("Retention policy is aligned with sponsor agreement."),
            "slaSummary": .string("Next retention review due tomorrow."),
            "exportStatus": .string("Last export pack prepared 10 minutes ago."),
            "reviewQueue": .list([
                timelineCard(title: "Review Lea Heger", subtitle: "Retention queue", detail: "Check unlock scope before export.", note: "Pending"),
                timelineCard(title: "Review Ingrid Nilsen", subtitle: "Retention queue", detail: "Confirm follow-up objective and SLA.", note: "Pending")
            ]),
            "unlockedLeads": .list([
                timelineCard(title: "Mads Hovden", subtitle: "Unlocked lead", detail: "Ready for sponsor-owned next step.", note: "Unlocked")
            ])
        ])
    ]
}

@Suite(.serialized)
struct CellConfigurationVerifierTests {
    @Test func verifierRejectsDeniedStateRootsInsteadOfSuppressingThem() {
        let probe = SkeletonBindingProbeSupport.RootProbe(
            label: "protectedSurface",
            rootKeypath: "state"
        )
        let failures = CellConfigurationVerifier.unreadableRootProbeFailures(
            in: [
                .init(
                    probe: probe,
                    durationMilliseconds: 1,
                    outcome: "denied"
                )
            ]
        )

        #expect(failures[probe] == "denied")
    }

    @Test func verifierCollectsActionsFromListRowTemplates() {
        let expected = SkeletonButton(
            keypath: "dispatchAction",
            label: "Open row",
            payloadKeypath: "row.id"
        )
        let row = SkeletonVStack(elements: [.Button(expected)])
        let list = SkeletonList(
            topic: nil,
            keypath: "rows",
            flowElementSkeleton: row
        )

        let collected = CellConfigurationVerifier.collectStaticButtons(in: .List(list))

        #expect(collected.map(\.label) == ["Open row"])
        #expect(collected.map(\.keypath) == ["dispatchAction"])
    }

    @Test func conferenceParticipantPortalContractVerifierKeepsBindingsAndActionsReachable() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Vis for deg",
                "Vis timeline",
                "Vis lagret",
                "Fokuser governance"
            ],
            rootProbes: [
                .init(label: "agendaSnapshot", rootKeypath: "state"),
                .init(label: "matchmakingSnapshot", rootKeypath: "state"),
                .init(label: "discoverySnapshot", rootKeypath: "state"),
                .init(label: "nearbyRadar", rootKeypath: "state")
            ]
        )

        let validationErrorCount = await report.validation.errorCount
        #expect(validationErrorCount == 0)
        #expect(report.unresolvedReferences.isEmpty)
        #expect(report.unreadableRootProbes.isEmpty)
        #expect(report.failedActions.isEmpty)
    }

    @Test func conferenceParticipantPortalNearbyVerifierCanOpenFollowUpChat() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )

        let report = try await CellConfigurationVerifier.nearbyFollowUpReport(for: configuration)

        #expect(report.startSucceeded)
        #expect(report.statusAfterStart == "started")
        #expect(report.requestContactSucceeded)
        #expect(report.requestContactLabel.map { ["Kontakt venter", "Awaiting exchange"].contains($0) } == true)
        #expect(report.requestContactSummary.map { [
            "Signert kontaktforespørsel sendt. Venter på godkjenning.",
            "Signed contact request sent. Awaiting signed identity exchange."
        ].contains($0) } == true)
        #expect(report.requestContactActionSummary.map { [
            "Signert kontaktforespørsel sendt. Venter på godkjenning.",
            "Signed contact request sent. Awaiting signed identity exchange."
        ].contains($0) } == true)
        #expect(report.chatOpened)
        #expect(report.nearbyCardLabel == "Åpne chatflate")
        #expect(report.nearbyCardPurposeSummary?.contains("verified overlap") == true)
        #expect(report.nearbyActionSummary == "Startet conference-chat med Nora Berg.")
        #expect(report.workspaceNextStep == "Started follow-up chat with Nora Berg in local preview.")
        #expect(report.sharedChatSummary == "2 shared message(s) visible.")
        #expect(report.firstRecentMessage == "Ja, gjerne. Jobber med tillit, relasjoner og hvordan identitet og oppfølging kan flyte mellom team. Hvis du vil, kan vi ta et kort neste steg etter sesjonen.")
        #expect(report.stopSucceeded)
        #expect(report.statusAfterStop == "stopped")
    }

    @Test func conferenceNearbyRadarContractVerifierKeepsBindingsAndActionsReachable() async throws {
        let configuration = ConfigurationCatalogCell.conferenceNearbyRadarWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Start scanner",
                "Stop scanner",
                "Tilbake til portalen"
            ]
        )

        let validationErrorCount = await report.validation.errorCount
        #expect(validationErrorCount == 0)
        #expect(report.unresolvedReferences.isEmpty)
        #expect(report.unreadableRootProbes.isEmpty)
        #expect(report.failedActions.isEmpty)
    }

    @Test func conferenceNearbyParticipantProfileContractVerifierKeepsBindingsAndActionsReachable() async throws {
        let configuration = ConfigurationCatalogCell.conferenceNearbyParticipantWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Åpne full radar",
                "Tilbake til portalen"
            ]
        )

        let validationErrorCount = await report.validation.errorCount
        #expect(validationErrorCount == 0)
        #expect(report.unresolvedReferences.isEmpty)
        #expect(report.unreadableRootProbes.isEmpty)
        #expect(report.failedActions.isEmpty)
    }

    @Test func conferenceParticipantChatContractVerifierKeepsBindingsAndActionsReachable() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantChatWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.contractReport(
            for: configuration,
            buttonsToExecute: [
                "Tilbake til portalen"
            ],
            rootProbes: [
                .init(label: "conferenceChat", rootKeypath: "state")
            ]
        )

        let validationErrorCount = await report.validation.errorCount
        #expect(validationErrorCount == 0)
        #expect(report.unresolvedReferences.isEmpty)
        #expect(report.unreadableRootProbes.isEmpty)
        #expect(report.failedActions.isEmpty)
    }

#if canImport(AppKit)
    @MainActor
    @Test func conferenceParticipantPortalRendererVerifierBuildsVisibleMacOSSurface() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(
            endpoint: "cell:///ConferenceParticipantPreviewShell"
        )

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "Conference Participant Portal",
                "Entity Discovery",
                "Start scanner",
                "Match nå",
                "Radar i siden",
                "Åpne full radar"
            ]
        )

        #expect(report.snapshotByteCount > 0, "Expected a non-empty rendered snapshot")
        #expect(report.subviewCount > 0)
        #expect(report.totalRenderMilliseconds > 0)
        #expect(report.unavailableNowCount == 0)
    }

    @MainActor
    @Test func conferenceNearbyRadarRendererVerifierBuildsVisibleMacOSSurface() async throws {
        let configuration = ConfigurationCatalogCell.conferenceNearbyRadarWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "Conference Nearby Radar · Full oversikt",
                "Start scanner",
                "Match nå",
                "Tilbake til portalen",
                "Valgt deltager"
            ]
        )

        #expect(report.snapshotByteCount > 0, "Expected a non-empty rendered snapshot")
        #expect(report.subviewCount > 0)
        #expect(report.totalRenderMilliseconds > 0)
    }

    @MainActor
    @Test func conferenceNearbyParticipantProfileRendererVerifierBuildsVisibleMacOSSurface() async throws {
        let configuration = ConfigurationCatalogCell.conferenceNearbyParticipantWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "Valgt deltager · profilflate",
                "Match nå",
                "Åpne full radar",
                "Tilbake til portalen",
                "Neste steg"
            ]
        )

        #expect(report.snapshotByteCount > 0, "Expected a non-empty rendered snapshot")
        #expect(report.subviewCount > 0)
        #expect(report.totalRenderMilliseconds > 0)
    }

    @MainActor
    @Test func conferenceParticipantChatRendererVerifierBuildsVisibleMacOSSurface() async throws {
        let configuration = ConfigurationCatalogCell.conferenceParticipantChatWorkbenchConfiguration()

        let report = try await CellConfigurationVerifier.renderReport(
            for: configuration,
            expectedVisibleStrings: [
                "Conference Participant Chat",
                "Participants & Conversations",
                "Recent Messages",
                "Free-text Composer",
                "Send fri melding",
                "Tøm utkast",
                "Tilbake til portalen"
            ]
        )

        #expect(report.snapshotByteCount > 0, "Expected a non-empty rendered snapshot")
        #expect(report.subviewCount > 0)
        #expect(report.totalRenderMilliseconds > 0)
    }
#endif
}

enum CellConfigurationVerifier {
    enum VerifierIdentityMode: String {
        case test
        case startup
        case apple
    }

    nonisolated struct ReferenceResolution: Hashable {
        let label: String
        let endpoint: String
        let durationMilliseconds: Double
        let outcome: String

        var resolved: Bool { outcome == "ok" }
    }

    nonisolated struct RootProbeResolution: Hashable {
        let probe: SkeletonBindingProbeSupport.RootProbe
        let durationMilliseconds: Double
        let outcome: String

        var readable: Bool { outcome == "ok" }
    }

    nonisolated struct ActionExecution: Hashable {
        let label: String
        let keypath: String
        let url: String?
        let durationMilliseconds: Double
        let outcome: String

        var succeeded: Bool { outcome == "ok" }
    }

    nonisolated struct ContractReport {
        let configuration: CellConfiguration
        let validation: CellConfigurationValidationReport
        let referenceResolutions: [ReferenceResolution]
        let rootProbeResolutions: [RootProbeResolution]
        let actionExecutions: [ActionExecution]
        let loadMilliseconds: Double
        let totalMilliseconds: Double

        var unresolvedReferences: [ReferenceResolution] {
            referenceResolutions.filter { !$0.resolved }
        }

        var unreadableRootProbes: [SkeletonBindingProbeSupport.RootProbe: String] {
            CellConfigurationVerifier.unreadableRootProbeFailures(in: rootProbeResolutions)
        }

        var failedActions: [ActionExecution] {
            actionExecutions.filter { !$0.succeeded }
        }
    }

    struct NearbyFollowUpReport {
        let configuration: CellConfiguration
        let injectedRemoteUUID: String
        let startDurationMilliseconds: Double
        let requestContactDurationMilliseconds: Double
        let injectDurationMilliseconds: Double
        let openChatDurationMilliseconds: Double
        let stopDurationMilliseconds: Double
        let startOutcome: String
        let requestContactOutcome: String
        let nearbyCardLabel: String?
        let nearbyCardPurposeSummary: String?
        let nearbyActionSummary: String?
        let requestContactLabel: String?
        let requestContactSummary: String?
        let requestContactActionSummary: String?
        let workspaceNextStep: String?
        let sharedChatSummary: String?
        let firstRecentMessage: String?
        let openChatOutcome: String
        let stopOutcome: String
        let statusAfterStart: String?
        let statusAfterStop: String?

        var startSucceeded: Bool { startOutcome == "ok" }
        var requestContactSucceeded: Bool { requestContactOutcome == "ok" }
        var chatOpened: Bool { openChatOutcome == "ok" }
        var stopSucceeded: Bool { stopOutcome == "ok" }
    }

#if canImport(AppKit)
    @MainActor
    struct RenderReport {
        let visibleStrings: Set<String>
        let buttonTitles: Set<String>
        let snapshotByteCount: Int
        let subviewCount: Int
        let firstMeaningfulContentMilliseconds: Double
        let totalRenderMilliseconds: Double

        var unavailableNowCount: Int {
            visibleStrings.filter { $0.contains("Innholdet er ikke tilgjengelig akkurat nå.") }.count
        }
    }
#endif

    static func contractReport(
        for configuration: CellConfiguration,
        buttonsToExecute: Set<String> = [],
        rootProbes: [SkeletonBindingProbeSupport.RootProbe]? = nil,
        identityMode: VerifierIdentityMode? = nil
    ) async throws -> ContractReport {
        let clock = ContinuousClock()
        let overallStart = clock.now
        let context = try await makeRuntimeContext(for: configuration, identityMode: identityMode)
        let directBindingCandidates = directReadableBindings(for: context.configuration)
        let probes = rootProbes ?? SkeletonBindingProbeSupport.rootProbes(for: context.configuration)

        let referenceResolutions = try await resolveReferences(
            flattenReferences(from: context.configuration.cellReferences ?? []),
            resolver: context.resolver,
            requester: context.owner
        )

        let loadStart = clock.now
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)
        try await waitForAttachedReferenceLabels(
            in: context.configuration.cellReferences ?? [],
            porthole: context.porthole,
            requester: context.owner
        )
        let loadMilliseconds = milliseconds(since: loadStart, clock: clock)

        let probeResolutions = try await readRootProbes(
            probes,
            bindingCandidates: directBindingCandidates,
            from: context.porthole,
            requester: context.owner
        )

        let actionExecutions = try await executeStaticButtons(
            in: context.configuration.skeleton,
            allowedLabels: buttonsToExecute,
            porthole: context.porthole,
            resolver: context.resolver,
            requester: context.owner
        )

        return ContractReport(
            configuration: context.configuration,
            validation: context.validation,
            referenceResolutions: referenceResolutions,
            rootProbeResolutions: probeResolutions,
            actionExecutions: actionExecutions,
            loadMilliseconds: loadMilliseconds,
            totalMilliseconds: milliseconds(since: overallStart, clock: clock)
        )
    }

    static func unreadableRootProbeFailures(
        in resolutions: [RootProbeResolution]
    ) -> [SkeletonBindingProbeSupport.RootProbe: String] {
        Dictionary(
            uniqueKeysWithValues: resolutions
                .filter { !$0.readable }
                .map { ($0.probe, $0.outcome) }
        )
    }

    private static func waitForAttachedReferenceLabels(
        in references: [CellReference],
        porthole: OrchestratorCell,
        requester: Identity
    ) async throws {
        let labels = references
            .map { $0.label.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !labels.isEmpty else { return }

        let maxAttempts = 12
        let retryDelayNanoseconds: UInt64 = 120_000_000

        for attempt in 1...maxAttempts {
            var pendingLabels: [String] = []
            for label in labels {
                do {
                    let status = try await withTimeout(
                        seconds: 0.5,
                        operation: "attachedStatus:\(label)"
                    ) {
                        try await porthole.attachedStatus(for: label, requester: requester)
                    }
                    if !status.active {
                        pendingLabels.append(label)
                    }
                } catch {
                    pendingLabels.append(label)
                }
            }

            if pendingLabels.isEmpty || attempt == maxAttempts {
                return
            }

            try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
        }
    }

    static func nearbyFollowUpReport(
        for configuration: CellConfiguration,
        remoteUUID: String = "nearby-verified-001",
        displayName: String = "Nora Berg",
        identityMode: VerifierIdentityMode? = nil
    ) async throws -> NearbyFollowUpReport {
        typealias NearbySnapshot = (
            status: String?,
            actionSummary: String?,
            cardLabel: String?,
            purposeSummary: String?,
            note: String?
        )

        let clock = ContinuousClock()
        let context = try await makeRuntimeContext(for: configuration, identityMode: identityMode)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)
        guard let nearbyRadar = try await context.resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceNearbyRadar",
            requester: context.owner
        ) as? Meddle else {
            throw NSError(
                domain: "CellConfigurationVerifier",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "Could not resolve ConferenceNearbyRadar for nearby follow-up verifier"]
            )
        }

        @Sendable
        func nearbyStateSnapshot(
            from value: ValueType
        ) -> NearbySnapshot {
            guard case let .object(rawObject) = value else {
                return (nil, nil, nil, nil, nil)
            }

            let object: Object
            if rawObject["statusBadge"] != nil || rawObject["nearby"] != nil || rawObject["actionSummary"] != nil {
                object = rawObject
            } else if case let .object(stateObject)? = rawObject["state"] {
                object = stateObject
            } else {
                object = rawObject
            }

            let status = bindingTestValueString(object["statusBadge"]) ?? bindingTestValueString(object["status"])
            let actionSummary = bindingTestValueString(object["actionSummary"])
            let selectedEntity: Object?
            if case let .object(value)? = object["selectedEntity"] {
                selectedEntity = value
            } else {
                selectedEntity = nil
            }
            let selectedActions: [ValueType]
            if case let .list(value)? = object["selectedEntityActions"] {
                selectedActions = value
            } else {
                selectedActions = []
            }
            let selectedPrimaryAction: Object?
            selectedPrimaryAction = selectedActions.compactMap { action -> Object? in
                guard case let .object(value) = action else {
                    return nil
                }
                let title = bindingTestValueString(value["title"])?.lowercased()
                let label = bindingTestValueString(value["label"])?.lowercased()
                if title == "kontakt" || title == "chat" {
                    return value
                }
                if label == "be om kontakt" ||
                    label == "kobler til..." ||
                    label == "kontakt venter" ||
                    label == "start chat" ||
                    label == "åpne chat" {
                    return value
                }
                return nil
            }.first ?? selectedActions.first.flatMap { action in
                guard case let .object(value) = action else {
                    return nil
                }
                return value
            }

            return (
                status,
                actionSummary,
                bindingTestValueString(selectedPrimaryAction?["label"]),
                bindingTestValueString(selectedEntity?["purposeSummary"]),
                bindingTestValueString(selectedEntity?["note"])
            )
        }

        func readNearbyState(operation: String) async throws -> ValueType {
            try await withTimeout(
                seconds: 5,
                operation: operation
            ) {
                try await nearbyRadar.get(
                    keypath: "state",
                    requester: context.owner
                )
            }
        }

        func readNearbyStatus(
            expectedStatus: String,
            from response: ValueType?,
            readOperation: String
        ) async throws -> String? {
            @Sendable
            func actionSummaryImpliesExpectedStatus(_ snapshot: NearbySnapshot?) -> Bool {
                guard let actionSummary = snapshot?.actionSummary?.lowercased() else {
                    return false
                }
                switch expectedStatus {
                case "started":
                    return actionSummary.contains("scanner started") || actionSummary.contains("starting scanner")
                case "stopped":
                    return actionSummary.contains("scanner stopped") || actionSummary.contains("stopping scanner")
                default:
                    return false
                }
            }

            let responseSnapshot = response.map(nearbyStateSnapshot(from:))
            if responseSnapshot?.status == expectedStatus {
                return responseSnapshot?.status
            }
            if actionSummaryImpliesExpectedStatus(responseSnapshot) {
                return expectedStatus
            }

            do {
                let awaitedSnapshot = try await waitForNearbySnapshot(
                    operation: readOperation,
                    timeoutSeconds: 3,
                    pollIntervalNanoseconds: 120_000_000
                ) { snapshot in
                    snapshot.status == expectedStatus || actionSummaryImpliesExpectedStatus(snapshot)
                }

                if awaitedSnapshot.status == expectedStatus {
                    return awaitedSnapshot.status
                }
                if actionSummaryImpliesExpectedStatus(awaitedSnapshot) {
                    return expectedStatus
                }
                return awaitedSnapshot.status ?? responseSnapshot?.status
            } catch {
                let stateSnapshot = nearbyStateSnapshot(
                    from: try await readNearbyState(operation: readOperation)
                )
                if stateSnapshot.status == expectedStatus {
                    return stateSnapshot.status
                }
                if actionSummaryImpliesExpectedStatus(stateSnapshot) {
                    return expectedStatus
                }
                return stateSnapshot.status ?? responseSnapshot?.status
            }
        }

        func waitForNearbySnapshot(
            operation: String,
            timeoutSeconds: Double = 5,
            pollIntervalNanoseconds: UInt64 = 50_000_000,
            until predicate: @escaping @Sendable (NearbySnapshot) -> Bool
        ) async throws -> NearbySnapshot {
            try await withTimeout(
                seconds: timeoutSeconds,
                operation: operation
            ) {
                while true {
                    let snapshot = nearbyStateSnapshot(
                        from: try await nearbyRadar.get(
                            keypath: "state",
                            requester: context.owner
                        )
                    )
                    if predicate(snapshot) {
                        return snapshot
                    }
                    try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
                }
            }
        }

        let startStart = clock.now
        let startResponse = try await withTimeout(
            seconds: 5,
            operation: "startNearbyScanner"
        ) {
            try await nearbyRadar.set(
                keypath: "dispatchAction",
                value: .object([
                    "keypath": .string("start"),
                    "payload": .bool(true)
                ]),
                requester: context.owner
            )
        }
        let startDuration = milliseconds(since: startStart, clock: clock)
        let startOutcome = startResponse.flatMap(SkeletonBindingProbeSupport.failureDetail(from:)) ?? "ok"
        let statusAfterStart = try await readNearbyStatus(
            expectedStatus: "started",
            from: startResponse,
            readOperation: "readNearbyStateAfterStart"
        )

        let candidateInjectPayload: Object = [
            "remoteUUID": .string(remoteUUID),
            "displayName": .string(displayName),
            "participantId": .string("participant-102"),
            "identityUUID": .string("identity-remote-123"),
            "company": .string("Polar Systems"),
            "role": .string("speaker"),
            "matchCount": .integer(0),
            "matchScore": .float(0.41),
            "distanceMeters": .float(1.6),
            "directionX": .float(0.0),
            "directionY": .float(0.0),
            "directionZ": .float(1.0)
        ]

        _ = try await withTimeout(
            seconds: 5,
            operation: "injectNearbyCandidate"
        ) {
            try await nearbyRadar.set(
                keypath: "testInjectNearbyCandidate",
                value: .object(candidateInjectPayload),
                requester: context.owner
            )
        }

        let requestContactStart = clock.now
        let requestContactResponse = try await withTimeout(
            seconds: 5,
            operation: "requestNearbyContact"
        ) {
            try await nearbyRadar.set(
                keypath: "dispatchAction",
                value: .object([
                    "keypath": .string("requestContact"),
                    "payload": .string(remoteUUID)
                ]),
                requester: context.owner
            )
        }
        let requestContactDuration = milliseconds(since: requestContactStart, clock: clock)
        let requestContactOutcome = requestContactResponse.flatMap(SkeletonBindingProbeSupport.failureDetail(from:)) ?? "ok"
        let immediateRequestContactSnapshot = requestContactResponse.map(nearbyStateSnapshot(from:))
        let requestContactSnapshot: NearbySnapshot
        @Sendable func requestContactIsWaiting(_ snapshot: NearbySnapshot?) -> Bool {
            snapshot?.cardLabel == "Kontakt venter" ||
                snapshot?.cardLabel == "Awaiting exchange" ||
                snapshot?.actionSummary == "Signert kontaktforespørsel sendt. Venter på godkjenning." ||
                snapshot?.actionSummary == "Signed contact request sent. Awaiting signed identity exchange."
        }

        if let immediateRequestContactSnapshot,
           requestContactIsWaiting(immediateRequestContactSnapshot) {
            requestContactSnapshot = immediateRequestContactSnapshot
        } else {
            requestContactSnapshot = try await waitForNearbySnapshot(
                operation: "waitForNearbyStateAfterRequestContact"
            ) { snapshot in
                requestContactIsWaiting(snapshot)
            }
        }
        let requestContactLabel = requestContactSnapshot.cardLabel
        let requestContactSummary = requestContactSnapshot.note
        let requestContactActionSummary = requestContactSnapshot.actionSummary

        let injectPayload: Object = [
            "remoteUUID": .string(remoteUUID),
            "displayName": .string(displayName),
            "participantId": .string("participant-102"),
            "identityUUID": .string("identity-remote-123"),
            "company": .string("Polar Systems"),
            "role": .string("speaker"),
            "matchCount": .integer(2),
            "matchScore": .float(0.92),
            "distanceMeters": .float(1.6),
            "directionX": .float(0.0),
            "directionY": .float(0.0),
            "directionZ": .float(1.0)
        ]

        let injectStart = clock.now
        _ = try await withTimeout(
            seconds: 5,
            operation: "injectVerifiedNearbyContact"
        ) {
            try await nearbyRadar.set(
                keypath: "testInjectVerifiedContact",
                value: .object(injectPayload),
                requester: context.owner
            )
        }
        let injectDuration = milliseconds(since: injectStart, clock: clock)

        var nearbySnapshot = nearbyStateSnapshot(
            from: try await readNearbyState(operation: "readNearbyStateAfterVerifiedInjection")
        )
        var nearbyCardLabel = nearbySnapshot.cardLabel
        var nearbyCardPurposeSummary = nearbySnapshot.purposeSummary
        var nearbyActionSummary = nearbySnapshot.actionSummary

        let openChatStart = clock.now
        let openChatResponse: ValueType?
        do {
            openChatResponse = try await withTimeout(
                seconds: 5,
                operation: "openNearbyFollowUpChat"
            ) {
                try await nearbyRadar.set(
                    keypath: "dispatchAction",
                    value: .object([
                        "keypath": .string("openFollowUpChat"),
                        "payload": .object(["remoteUUID": .string(remoteUUID)])
                    ]),
                    requester: context.owner
                )
            }
        } catch {
            return NearbyFollowUpReport(
                configuration: context.configuration,
                injectedRemoteUUID: remoteUUID,
                startDurationMilliseconds: startDuration,
                requestContactDurationMilliseconds: requestContactDuration,
                injectDurationMilliseconds: injectDuration,
                openChatDurationMilliseconds: milliseconds(since: openChatStart, clock: clock),
                stopDurationMilliseconds: 0,
                startOutcome: startOutcome,
                requestContactOutcome: requestContactOutcome,
                nearbyCardLabel: nearbyCardLabel,
                nearbyCardPurposeSummary: nearbyCardPurposeSummary,
                nearbyActionSummary: nearbyActionSummary,
                requestContactLabel: requestContactLabel,
                requestContactSummary: requestContactSummary,
                requestContactActionSummary: requestContactActionSummary,
                workspaceNextStep: nil,
                sharedChatSummary: nil,
                firstRecentMessage: nil,
                openChatOutcome: String(describing: error),
                stopOutcome: "not-run",
                statusAfterStart: statusAfterStart,
                statusAfterStop: nil
            )
        }
        let openChatDuration = milliseconds(since: openChatStart, clock: clock)
        let openChatOutcome: String
        if let openChatResponse {
            openChatOutcome = SkeletonBindingProbeSupport.failureDetail(from: openChatResponse) ?? "ok"
        } else {
            openChatOutcome = "nil"
        }

        nearbySnapshot = nearbyStateSnapshot(
            from: try await readNearbyState(operation: "readNearbyStateAfterOpenChat")
        )
        nearbyActionSummary = nearbySnapshot.actionSummary
        nearbyCardLabel = nearbySnapshot.cardLabel
        nearbyCardPurposeSummary = nearbySnapshot.purposeSummary

        guard let participantPreview = try await context.resolver.cellAtEndpoint(
            endpoint: "cell:///ConferenceParticipantPreviewShell",
            requester: context.owner
        ) as? Meddle else {
            throw NSError(
                domain: "CellConfigurationVerifier",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: "Could not resolve ConferenceParticipantPreviewShell for nearby follow-up verifier"]
            )
        }

        let participantStateValue = try await withTimeout(
            seconds: 5,
            operation: "readParticipantPreviewStateAfterNearbyChat"
        ) {
            try await participantPreview.get(
                keypath: "state",
                requester: context.owner
            )
        }

        let firstRecentMessage: String?
        let workspaceNextStep: String?
        let sharedChatSummary: String?
        if case let .object(stateObject) = participantStateValue {
            let workspace: Object?
            if case let .object(workspaceObject)? = stateObject["workspace"] {
                workspace = workspaceObject
            } else {
                workspace = nil
            }
            let sharedConnections: Object?
            if case let .object(sharedConnectionsObject)? = stateObject["sharedConnections"] {
                sharedConnections = sharedConnectionsObject
            } else {
                sharedConnections = nil
            }

            workspaceNextStep = bindingTestValueString(workspace?["nextStep"])
            sharedChatSummary = bindingTestValueString(sharedConnections?["chatSummary"])
            if case let .list(messages)? = sharedConnections?["recentMessages"],
               case let .object(firstMessage)? = messages.first {
                firstRecentMessage = bindingTestValueString(firstMessage["detail"])
            } else {
                firstRecentMessage = nil
            }
        } else {
            workspaceNextStep = nil
            sharedChatSummary = nil
            firstRecentMessage = nil
        }

        let stopStart = clock.now
        let stopResponse = try await withTimeout(
            seconds: 5,
            operation: "stopNearbyScanner"
        ) {
            try await nearbyRadar.set(
                keypath: "dispatchAction",
                value: .object([
                    "keypath": .string("stop"),
                    "payload": .bool(true)
                ]),
                requester: context.owner
            )
        }
        let stopDuration = milliseconds(since: stopStart, clock: clock)
        let stopOutcome = stopResponse.flatMap(SkeletonBindingProbeSupport.failureDetail(from:)) ?? "ok"
        let statusAfterStop = try await readNearbyStatus(
            expectedStatus: "stopped",
            from: stopResponse,
            readOperation: "readNearbyStateAfterStop"
        )

        return NearbyFollowUpReport(
            configuration: context.configuration,
            injectedRemoteUUID: remoteUUID,
            startDurationMilliseconds: startDuration,
            requestContactDurationMilliseconds: requestContactDuration,
            injectDurationMilliseconds: injectDuration,
            openChatDurationMilliseconds: openChatDuration,
            stopDurationMilliseconds: stopDuration,
            startOutcome: startOutcome,
            requestContactOutcome: requestContactOutcome,
            nearbyCardLabel: nearbyCardLabel,
            nearbyCardPurposeSummary: nearbyCardPurposeSummary,
            nearbyActionSummary: nearbyActionSummary,
            requestContactLabel: requestContactLabel,
            requestContactSummary: requestContactSummary,
            requestContactActionSummary: requestContactActionSummary,
            workspaceNextStep: workspaceNextStep,
            sharedChatSummary: sharedChatSummary,
            firstRecentMessage: firstRecentMessage,
            openChatOutcome: openChatOutcome,
            stopOutcome: stopOutcome,
            statusAfterStart: statusAfterStart,
            statusAfterStop: statusAfterStop
        )
    }

#if canImport(AppKit)
    @MainActor
    static func renderReport(
        for configuration: CellConfiguration,
        expectedVisibleStrings: Set<String>,
        identityMode: VerifierIdentityMode? = nil
    ) async throws -> RenderReport {
        let context = try await makeRuntimeContext(for: configuration, identityMode: identityMode)
        context.porthole.detachAll(requester: context.owner)
        try await context.porthole.loadCellConfiguration(context.configuration, requester: context.owner)

        guard let skeleton = context.configuration.skeleton else {
            throw NSError(domain: "CellConfigurationVerifier", code: 1, userInfo: [NSLocalizedDescriptionKey: "Configuration mangler skeleton"])
        }

        let viewModel = PortholeViewModel()
        viewModel.cellReferences = context.configuration.cellReferences ?? []
        viewModel.applyCellConfiguration(cellConfiguration: context.configuration)
        viewModel.markLocalMutation()

        let hostingView = NSHostingView(
            rootView: BindingSkeletonView(element: skeleton)
                .environmentObject(viewModel)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 1280, height: 2600)
        let containerView = NSView(frame: hostingView.frame)
        containerView.addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        containerView.layoutSubtreeIfNeeded()

        let clock = ContinuousClock()
        let renderStart = clock.now
        var firstMeaningfulContentMilliseconds = 0.0
        var visibleStrings = Set<String>()
        var buttonTitles = Set<String>()
        var snapshotByteCount = 0

        for iteration in 0..<16 {
            containerView.layoutSubtreeIfNeeded()
            hostingView.layoutSubtreeIfNeeded()
            hostingView.displayIfNeeded()
            visibleStrings = collectVisibleStrings(from: containerView)
            buttonTitles = collectButtonTitles(from: containerView)
            snapshotByteCount = max(snapshotByteCount, snapshotPNGByteCount(for: containerView))

            let combinedStrings = visibleStrings.union(buttonTitles)
            if firstMeaningfulContentMilliseconds == 0,
               expectedVisibleStrings.isSubset(of: combinedStrings) {
                firstMeaningfulContentMilliseconds = milliseconds(since: renderStart, clock: clock)
                break
            }

            if iteration < 15 {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }

        containerView.layoutSubtreeIfNeeded()
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()
        visibleStrings = collectVisibleStrings(from: containerView)
        buttonTitles = collectButtonTitles(from: containerView)
        snapshotByteCount = max(snapshotByteCount, snapshotPNGByteCount(for: containerView))

        if firstMeaningfulContentMilliseconds == 0 {
            firstMeaningfulContentMilliseconds = milliseconds(since: renderStart, clock: clock)
        }

        return RenderReport(
            visibleStrings: visibleStrings,
            buttonTitles: buttonTitles,
            snapshotByteCount: snapshotByteCount,
            subviewCount: countSubviews(in: containerView),
            firstMeaningfulContentMilliseconds: firstMeaningfulContentMilliseconds,
            totalRenderMilliseconds: milliseconds(since: renderStart, clock: clock)
        )
    }
#endif

    struct RuntimeContext {
        let configuration: CellConfiguration
        let validation: CellConfigurationValidationReport
        let resolver: CellResolver
        let owner: Identity
        let porthole: OrchestratorCell
    }

    private struct VerifierTimeoutError: Error, CustomStringConvertible {
        let operation: String
        let seconds: Double

        var description: String {
            "timeout(\(operation), \(seconds)s)"
        }
    }

    static func verifierIdentityMode(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> VerifierIdentityMode {
        guard let rawValue = environment["BINDING_VERIFIER_IDENTITY_MODE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !rawValue.isEmpty else {
            return .startup
        }

        switch rawValue {
        case "startup", "local":
            return .startup
        case "apple", "signed-apple", "keychain":
            return .apple
        case "test", "deterministic":
            return .test
        default:
            return .startup
        }
    }

    static func makeRuntimeContext(
        for configuration: CellConfiguration,
        identityMode explicitIdentityMode: VerifierIdentityMode? = nil
    ) async throws -> RuntimeContext {
        let identityMode = explicitIdentityMode ?? verifierIdentityMode()
        let identityVault: any IdentityVaultProtocol

        switch identityMode {
        case .test:
            let vault = BindingTests.testIdentityVault
            _ = await vault.initialize()
            identityVault = vault
        case .startup:
            identityVault = await BindingStartupIdentityVault.shared.initialize()
        case .apple:
            identityVault = await IdentityVault.shared.initialize()
        }

        CellBase.defaultIdentityVault = identityVault
        await BindingLaunchWarmup.preloadLocalRuntime()
        switch identityMode {
        case .apple:
            await BindingLocalCellRegistration.shared.ensureRegistered()
        case .startup, .test:
            await BindingLocalCellRegistration.shared.ensureLocallyRegistered()
        }

        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            throw NSError(domain: "CellConfigurationVerifier", code: 2, userInfo: [NSLocalizedDescriptionKey: "Expected CellResolver after local runtime warmup"])
        }

        await ConferenceVerifierFixtureSupport.ensureRegistered(on: resolver)

        let identityContext = "verifier-\(UUID().uuidString)"
        guard let owner = await identityVault.identity(for: identityContext, makeNewIfNotFound: true) else {
            throw NSError(domain: "CellConfigurationVerifier", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not create verifier identity"])
        }

        await ConferenceParticipantPreviewFallbackStateStore.shared.reset(for: owner.uuid)

        guard let porthole = try await resolver.cellAtEndpoint(
            endpoint: "cell:///Porthole",
            requester: owner
        ) as? OrchestratorCell else {
            throw NSError(domain: "CellConfigurationVerifier", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not resolve Porthole for verifier"])
        }

        let repaired = BindingConferenceConfigurationRepair.updatedConfigurationIfNeeded(configuration) ?? configuration
        registerRemoteRoutes(for: repaired, resolver: resolver)
        try await prepareRemoteReferenceAdmissionIfNeeded(for: repaired, resolver: resolver, requester: owner)
        let validation = await CellConfigurationValidationService.validate(repaired)
        return RuntimeContext(
            configuration: repaired,
            validation: validation,
            resolver: resolver,
            owner: owner,
            porthole: porthole
        )
    }

    private static func prepareRemoteReferenceAdmissionIfNeeded(
        for configuration: CellConfiguration,
        resolver: CellResolver,
        requester: Identity
    ) async throws {
        for endpoint in remoteRegistrationEndpoints(in: configuration) {
            guard await RemoteEndpointAccessSupport.authorizationKind(for: endpoint) != .none else {
                continue
            }
            _ = try await RemoteEndpointAccessSupport.resolveEmit(
                endpoint: endpoint,
                resolver: resolver,
                requester: requester,
                accessLabel: "CellConfigurationVerifier: \(configuration.name)"
            )
        }
    }

    private static func registerRemoteRoutes(for configuration: CellConfiguration, resolver: CellResolver) {
        for endpoint in remoteRegistrationEndpoints(in: configuration) {
            RemoteEndpointAccessSupport.registerRemoteRouteIfNeeded(for: endpoint, resolver: resolver)
        }
    }

    private static func remoteRegistrationEndpoints(in configuration: CellConfiguration) -> Set<String> {
        var endpoints: Set<String> = []

        if let sourceEndpoint = configuration.discovery?.sourceCellEndpoint {
            endpoints.insert(sourceEndpoint)
        }

        for reference in configuration.cellReferences ?? [] {
            collectRemoteRegistrationEndpoints(from: reference, into: &endpoints)
        }

        return endpoints
    }

    private static func collectRemoteRegistrationEndpoints(from reference: CellReference, into endpoints: inout Set<String>) {
        endpoints.insert(reference.endpoint)

        for item in reference.setKeysAndValues {
            if let target = item.target {
                endpoints.insert(target)
            }
        }

        for subscription in reference.subscriptions {
            collectRemoteRegistrationEndpoints(from: subscription, into: &endpoints)
        }
    }

    fileprivate static func waitForPortholeLoadBridgeConfiguration(
        containingName expectedNameFragment: String,
        timeout: TimeInterval = 2.0
    ) async -> CellConfiguration? {
        let notificationCenter = NotificationCenter.default
        return await withCheckedContinuation { continuation in
            var token: NSObjectProtocol?
            var didResume = false

            func finish(_ configuration: CellConfiguration?) {
                guard !didResume else { return }
                didResume = true
                if let token {
                    notificationCenter.removeObserver(token)
                }
                continuation.resume(returning: configuration)
            }

            let deadline = DispatchTime.now() + timeout
            token = notificationCenter.addObserver(
                forName: BindingPortholeLoadBridge.notificationName,
                object: nil,
                queue: nil
            ) { notification in
                guard let configuration = BindingPortholeLoadBridge.configuration(from: notification) else {
                    return
                }
                guard configuration.name.contains(expectedNameFragment) else {
                    return
                }
                finish(configuration)
            }

            DispatchQueue.main.asyncAfter(deadline: deadline) {
                finish(nil)
            }
        }
    }

    private static func withTimeout<T: Sendable>(
        seconds: Double,
        operation: String,
        _ work: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var didResolve = false

            func resolve(_ result: Result<T, Error>) {
                lock.lock()
                guard !didResolve else {
                    lock.unlock()
                    return
                }
                didResolve = true
                lock.unlock()

                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let workTask = Task.detached {
                do {
                    resolve(.success(try await work()))
                } catch {
                    resolve(.failure(error))
                }
            }

            Task.detached {
                let duration = max(seconds, 0)
                do {
                    try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                } catch {
                    return
                }
                workTask.cancel()
                resolve(.failure(VerifierTimeoutError(operation: operation, seconds: seconds)))
            }
        }
    }

    private static func resolveReferences(
        _ references: [CellReference],
        resolver: CellResolver,
        requester: Identity
    ) async throws -> [ReferenceResolution] {
        let clock = ContinuousClock()
        var results: [ReferenceResolution] = []

        for reference in references {
            let start = clock.now
            do {
                _ = try await withTimeout(
                    seconds: 5,
                    operation: "resolveReference:\(reference.endpoint)"
                ) {
                    try await resolver.cellAtEndpoint(endpoint: reference.endpoint, requester: requester)
                }
                results.append(
                    ReferenceResolution(
                        label: reference.label,
                        endpoint: reference.endpoint,
                        durationMilliseconds: milliseconds(since: start, clock: clock),
                        outcome: "ok"
                    )
                )
            } catch {
                results.append(
                    ReferenceResolution(
                        label: reference.label,
                        endpoint: reference.endpoint,
                        durationMilliseconds: milliseconds(since: start, clock: clock),
                        outcome: String(describing: error)
                    )
                )
            }
        }

        return results
    }

    private static func readRootProbes(
        _ probes: [SkeletonBindingProbeSupport.RootProbe],
        bindingCandidates: [SkeletonBindingProbeSupport.RootProbe: [String]],
        from porthole: OrchestratorCell,
        requester: Identity
    ) async throws -> [RootProbeResolution] {
        let clock = ContinuousClock()
        let maxAttempts = 3
        let retryDelayNanoseconds: UInt64 = 120_000_000
        let perProbeTimeoutSeconds = 0.6
        var latestOutcomes: [SkeletonBindingProbeSupport.RootProbe: String] = [:]
        var latestDurations: [SkeletonBindingProbeSupport.RootProbe: Double] = [:]

        for attempt in 1...maxAttempts {
            latestOutcomes.removeAll(keepingCapacity: true)

            for probe in probes {
                let start = clock.now
                let candidates = bindingCandidates[probe] ?? []
                if !candidates.isEmpty {
                    let candidateOutcome = try await firstReadableBindingOutcome(
                        for: probe,
                        initialFailure: "candidate-unreadable",
                        candidates: candidates,
                        on: porthole,
                        requester: requester,
                        timeoutSeconds: perProbeTimeoutSeconds
                    )
                    latestDurations[probe] = milliseconds(since: start, clock: clock)
                    if candidateOutcome == "ok" {
                        continue
                    }
                }
                do {
                    let value = try await withTimeout(
                        seconds: perProbeTimeoutSeconds,
                        operation: "readRootProbe:\(probe.qualifiedKeypath)"
                    ) {
                        try await porthole.get(keypath: probe.qualifiedKeypath, requester: requester)
                    }
                    latestDurations[probe] = milliseconds(since: start, clock: clock)
                    if let detail = SkeletonBindingProbeSupport.failureDetail(from: value) {
                        latestOutcomes[probe] = try await firstReadableBindingOutcome(
                            for: probe,
                            initialFailure: detail,
                            candidates: candidates,
                            on: porthole,
                            requester: requester,
                            timeoutSeconds: perProbeTimeoutSeconds
                        )
                    }
                } catch {
                    latestDurations[probe] = milliseconds(since: start, clock: clock)
                    latestOutcomes[probe] = try await firstReadableBindingOutcome(
                        for: probe,
                        initialFailure: String(describing: error),
                        candidates: candidates,
                        on: porthole,
                        requester: requester,
                        timeoutSeconds: perProbeTimeoutSeconds
                    )
                }
            }

            if latestOutcomes.isEmpty || attempt == maxAttempts {
                break
            }

            try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
        }

        return probes.map { probe in
            RootProbeResolution(
                probe: probe,
                durationMilliseconds: latestDurations[probe] ?? 0,
                outcome: latestOutcomes[probe] ?? "ok"
            )
        }
    }

    private static func firstReadableBindingOutcome(
        for probe: SkeletonBindingProbeSupport.RootProbe,
        initialFailure: String,
        candidates: [String],
        on porthole: OrchestratorCell,
        requester: Identity,
        timeoutSeconds: Double
    ) async throws -> String {
        let fallbackCandidates = candidates
            .filter { $0 != probe.qualifiedKeypath }
            .prefix(6)

        guard !fallbackCandidates.isEmpty else {
            return initialFailure
        }

        for candidate in fallbackCandidates {
            do {
                let value = try await withTimeout(
                    seconds: timeoutSeconds,
                    operation: "readBindingCandidate:\(candidate)"
                ) {
                    try await porthole.get(keypath: candidate, requester: requester)
                }
                if SkeletonBindingProbeSupport.failureDetail(from: value) == nil {
                    return "ok"
                }
            } catch {
                continue
            }
        }

        return initialFailure
    }

    private static func executeStaticButtons(
        in skeleton: SkeletonElement?,
        allowedLabels: Set<String>,
        porthole: OrchestratorCell,
        resolver: CellResolver,
        requester: Identity
    ) async throws -> [ActionExecution] {
        guard let skeleton, !allowedLabels.isEmpty else {
            return []
        }

        let buttons = collectStaticButtons(in: skeleton)
            .filter { allowedLabels.contains($0.label) }
        let clock = ContinuousClock()
        var results: [ActionExecution] = []

        for button in buttons {
            let start = clock.now
            let response: ValueType?
            do {
                response = try await withTimeout(
                    seconds: 5,
                    operation: "executeButton:\(button.label)"
                ) {
                    try await executeButtonDeterministically(
                        button,
                        porthole: porthole,
                        resolver: resolver,
                        requester: requester
                    )
                }
            } catch {
                results.append(
                    ActionExecution(
                        label: button.label,
                        keypath: button.keypath,
                        url: button.url,
                        durationMilliseconds: milliseconds(since: start, clock: clock),
                        outcome: String(describing: error)
                    )
                )
                continue
            }
            let outcome: String
            if let response {
                outcome = SkeletonBindingProbeSupport.failureDetail(from: response) ?? "ok"
            } else {
                outcome = "nil"
            }
            results.append(
                ActionExecution(
                    label: button.label,
                    keypath: button.keypath,
                    url: button.url,
                    durationMilliseconds: milliseconds(since: start, clock: clock),
                    outcome: outcome
                )
            )
        }

        return results
    }

    private static func executeButtonDeterministically(
        _ button: SkeletonButton,
        porthole: OrchestratorCell,
        resolver: CellResolver,
        requester: Identity
    ) async throws -> ValueType? {
        let target: Meddle
        if let url = button.url {
            guard let resolved = try await resolver.cellAtEndpoint(
                endpoint: url,
                requester: requester
            ) as? Meddle else {
                throw NSError(
                    domain: "CellConfigurationVerifier",
                    code: 7,
                    userInfo: [NSLocalizedDescriptionKey: "Button target was not Meddle for \(button.label)"]
                )
            }
            target = resolved
        } else {
            target = porthole
        }

        if let payload = button.payload {
            return try await target.set(
                keypath: button.keypath,
                value: payload,
                requester: requester
            )
        }

        return try await target.get(
            keypath: button.keypath,
            requester: requester
        )
    }

    private static func directReadableBindings(
        for configuration: CellConfiguration
    ) -> [SkeletonBindingProbeSupport.RootProbe: [String]] {
        guard let skeleton = configuration.skeleton,
              let rawObject = rawObject(from: skeleton)
        else {
            return [:]
        }

        let labels = Set(
            (configuration.cellReferences ?? [])
                .map { $0.label.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        guard !labels.isEmpty else {
            return [:]
        }

        var collected: [SkeletonBindingProbeSupport.RootProbe: [String]] = [:]
        collectReadableBindings(
            from: rawObject,
            currentElementKind: nil,
            labels: labels,
            into: &collected
        )
        return collected
    }

    private static func rawObject<T: Encodable>(from value: T) -> Any? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private static func collectReadableBindings(
        from value: Any,
        currentElementKind: String?,
        labels: Set<String>,
        into collected: inout [SkeletonBindingProbeSupport.RootProbe: [String]]
    ) {
        let skeletonElementKinds: Set<String> = [
            "Text", "AttachmentField", "FileUpload", "TextField", "TextArea", "List", "Object", "Reference",
            "Toggle", "Picker", "Image", "Button", "Spacer", "HStack", "VStack",
            "ScrollView", "Section", "Tabs", "ZStack", "Grid", "Visualization", "Divider", "Unsupported"
        ]
        let readableBindingKeys: Set<String> = ["keypath", "sourceKeypath"]

        switch value {
        case let dictionary as [String: Any]:
            if dictionary.count == 1,
               let onlyKey = dictionary.keys.first,
               skeletonElementKinds.contains(onlyKey),
               let child = dictionary[onlyKey] {
                collectReadableBindings(
                    from: child,
                    currentElementKind: onlyKey,
                    labels: labels,
                    into: &collected
                )
                return
            }

            for (key, child) in dictionary {
                if readableBindingKeys.contains(key),
                   currentElementKind != "Button",
                   let bindingValue = child as? String,
                   let normalizedBinding = normalizedReadableBinding(bindingValue, labels: labels),
                   let probe = rootProbe(for: normalizedBinding) {
                    var current = collected[probe] ?? []
                    if !current.contains(normalizedBinding) {
                        current.append(normalizedBinding)
                        collected[probe] = current
                    }
                }

                collectReadableBindings(
                    from: child,
                    currentElementKind: currentElementKind,
                    labels: labels,
                    into: &collected
                )
            }
        case let array as [Any]:
            for child in array {
                collectReadableBindings(
                    from: child,
                    currentElementKind: currentElementKind,
                    labels: labels,
                    into: &collected
                )
            }
        default:
            break
        }
    }

    private static func normalizedReadableBinding(_ bindingValue: String, labels: Set<String>) -> String? {
        let trimmed = bindingValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalizedBinding: String
        if trimmed.hasPrefix("cell:///Porthole/") {
            normalizedBinding = String(trimmed.dropFirst("cell:///Porthole/".count))
        } else if trimmed.hasPrefix("cell://") || trimmed.hasPrefix("ws://") || trimmed.hasPrefix("wss://") {
            return nil
        } else {
            normalizedBinding = trimmed
        }

        guard let separatorIndex = normalizedBinding.firstIndex(of: ".") else {
            return nil
        }

        let label = String(normalizedBinding[..<separatorIndex])
        guard labels.contains(label) else { return nil }
        return normalizedBinding
    }

    private static func rootProbe(for normalizedBinding: String) -> SkeletonBindingProbeSupport.RootProbe? {
        guard let separatorIndex = normalizedBinding.firstIndex(of: ".") else {
            return nil
        }

        let label = String(normalizedBinding[..<separatorIndex])
        let remainder = String(normalizedBinding[normalizedBinding.index(after: separatorIndex)...])
        guard let rootSeparator = remainder.firstIndex(where: { $0 == "." || $0 == "[" }) else {
            guard !remainder.isEmpty else { return nil }
            return SkeletonBindingProbeSupport.RootProbe(label: label, rootKeypath: remainder)
        }

        let rootKeypath = String(remainder[..<rootSeparator])
        guard !rootKeypath.isEmpty else { return nil }
        return SkeletonBindingProbeSupport.RootProbe(label: label, rootKeypath: rootKeypath)
    }

    static func collectStaticButtons(in element: SkeletonElement) -> [SkeletonButton] {
        switch element {
        case .Button(let button):
            return [button]
        case .VStack(let stack):
            return stack.elements.flatMap(collectStaticButtons)
        case .HStack(let stack):
            return stack.elements.flatMap(collectStaticButtons)
        case .ScrollView(let scroll):
            return scroll.elements.flatMap(collectStaticButtons)
        case .Section(let section):
            return (section.header.map(collectStaticButtons) ?? []) +
                section.content.flatMap(collectStaticButtons) +
                (section.footer.map(collectStaticButtons) ?? [])
        case .Reference(let reference):
            return reference.flowElementSkeleton?.elements.flatMap(collectStaticButtons) ?? []
        case .List(let list):
            return list.flowElementSkeleton?.elements.flatMap(collectStaticButtons) ?? []
        case .Grid(let grid):
            return grid.elements.flatMap(collectStaticButtons)
        case .ZStack(let stack):
            return stack.elements.flatMap(collectStaticButtons)
        case .Object(let object):
            return object.elements.values.flatMap(collectStaticButtons)
        case .Tabs(let tabs):
            return tabs.panels.flatMap { $0.content.flatMap(collectStaticButtons) }
        default:
            return []
        }
    }

    private static func flattenReferences(from references: [CellReference]) -> [CellReference] {
        var flattened: [CellReference] = []

        func visit(_ reference: CellReference) {
            if flattened.contains(where: { $0.id == reference.id }) {
                return
            }
            flattened.append(reference)
            reference.subscriptions.forEach(visit)
        }

        references.forEach(visit)
        return flattened
    }

    private static func milliseconds(
        since start: ContinuousClock.Instant,
        clock: ContinuousClock
    ) -> Double {
        let duration = clock.now - start
        let components = duration.components
        return (Double(components.seconds) * 1_000.0) + (Double(components.attoseconds) / 1_000_000_000_000_000.0)
    }

#if canImport(AppKit)
    @MainActor
    private static func snapshotPNGByteCount(for view: NSView) -> Int {
        guard view.bounds.isEmpty == false,
              let imageRep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
        else {
            return 0
        }
        view.cacheDisplay(in: view.bounds, to: imageRep)
        return imageRep.representation(using: .png, properties: [:])?.count ?? 0
    }

    @MainActor
    private static func collectVisibleStrings(from view: NSView) -> Set<String> {
        var strings = Set<String>()
        if let textField = view as? NSTextField {
            let text = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty == false {
                strings.insert(text)
            }
        }
        for child in view.subviews {
            strings.formUnion(collectVisibleStrings(from: child))
        }
        return strings
    }

    @MainActor
    private static func collectButtonTitles(from view: NSView) -> Set<String> {
        var titles = Set<String>()
        if let button = view as? NSButton {
            let title = button.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if title.isEmpty == false {
                titles.insert(title)
            }
        }
        for child in view.subviews {
            titles.formUnion(collectButtonTitles(from: child))
        }
        return titles
    }

    @MainActor
    private static func countSubviews(in view: NSView) -> Int {
        1 + view.subviews.reduce(0) { partialResult, child in
            partialResult + countSubviews(in: child)
        }
    }
#endif
}

private func bindingTestValueString(_ value: ValueType?) -> String? {
    guard case let .string(string)? = value else {
        return nil
    }
    return string
}

private actor RemoteReadRetryProbeScript {
    enum Mode {
        case succeedsOnSecondAttempt
        case alwaysDenied
    }

    static let shared = RemoteReadRetryProbeScript()

    private var mode: Mode = .alwaysDenied
    private var attempts = 0

    func configure(_ mode: Mode) {
        self.mode = mode
        attempts = 0
    }

    func attemptCount() -> Int {
        attempts
    }

    func read(cellUUID: String, requester: Identity) throws -> ValueType {
        attempts += 1
        if mode == .succeedsOnSecondAttempt, attempts == 2 {
            return .string("authorized-after-retry")
        }
        let request = CellAuthorizationRequest(
            cellUUID: cellUUID,
            identityDomain: "binding.remote-read-retry-test",
            keypath: "state",
            requestedAccess: "r---",
            requester: requester
        )
        throw CellAuthorizationError.denied(
            CellAuthorizationDecision(
                allowed: false,
                path: .deniedNoGrant,
                reason: "Injected typed denial for GET reauthorization coverage.",
                request: request
            )
        )
    }
}

private final class RemoteReadRetryProbeCell: GeneralCell {
    required init(owner: Identity) async {
        await super.init(owner: owner)
        agreementTemplate.addGrant("r---", for: "state")
        await addInterceptForGet(requester: owner, key: "state") { [weak self] _, requester in
            guard let self else { throw CancellationError() }
            return try await RemoteReadRetryProbeScript.shared.read(
                cellUUID: self.uuid,
                requester: requester
            )
        }
    }

    nonisolated required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    nonisolated override func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
    }
}

private func bindingTestEventuallyGet(
    from cell: Meddle,
    keypath: String,
    requester: Identity,
    attempts: Int = 40,
    retryDelayNanoseconds: UInt64 = 50_000_000
) async throws -> ValueType {
    var lastError: Error?
    for attempt in 0..<attempts {
        do {
            return try await cell.get(keypath: keypath, requester: requester)
        } catch {
            lastError = error
            if attempt == attempts - 1 {
                throw error
            }
            try await Task.sleep(nanoseconds: retryDelayNanoseconds)
        }
    }
    throw lastError ?? CancellationError()
}

private func bindingTestEventuallySet(
    on cell: Meddle,
    keypath: String,
    value: ValueType,
    requester: Identity,
    attempts: Int = 40,
    retryDelayNanoseconds: UInt64 = 50_000_000
) async throws -> ValueType? {
    var lastError: Error?
    for attempt in 0..<attempts {
        do {
            return try await cell.set(keypath: keypath, value: value, requester: requester)
        } catch {
            lastError = error
            if attempt == attempts - 1 {
                throw error
            }
            try await Task.sleep(nanoseconds: retryDelayNanoseconds)
        }
    }
    throw lastError ?? CancellationError()
}

private func bindingTestValueStrings(_ value: ValueType?) -> [String] {
    guard case let .list(values)? = value else {
        return []
    }
    return values.compactMap { entry in
        guard case let .string(string) = entry else {
            return nil
        }
        return string
    }
}

private func bindingTestValueDouble(_ value: ValueType?) -> Double? {
    guard let value else { return nil }
    switch value {
    case let .float(float):
        return float
    case let .integer(integer):
        return Double(integer)
    case let .number(number):
        return Double(number)
    case let .string(string):
        return Double(string)
    default:
        return nil
    }
}

private func bindingTestValueBool(_ value: ValueType?) -> Bool? {
    guard let value else { return nil }
    switch value {
    case let .bool(flag):
        return flag
    case let .string(string):
        let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ["1", "true", "yes", "on"].contains(normalized) {
            return true
        }
        if ["0", "false", "no", "off"].contains(normalized) {
            return false
        }
        return nil
    default:
        return nil
    }
}

private func bindingTestValueObjects(_ value: ValueType?) -> [Object] {
    guard case let .list(values)? = value else {
        return []
    }
    return values.compactMap { entry in
        guard case let .object(object) = entry else {
            return nil
        }
        return object
    }
}
