import Foundation
import Testing
import Darwin
@_spi(HAVENRuntime) import CellBase
@testable import Binding

@Suite(.serialized)
struct DeviceIngressRegistrationClientTests {
    private let now = Date(timeIntervalSince1970: 1_784_454_400)
    private let audience = "staging.haven.digipomps.org"
    private let body = Data(#"{"participantId":"binding-participant","pushToken":"test-apns-token"}"#.utf8)

    @Test
    func registerPersistsExpectationBeforeSendAndRestoresVerifiedReceipt() async throws {
        let fixture = try await makeFixture()
        let buildProvenance = try makeBuildProvenance()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let transport = FixtureTransport(
            challengeData: fixture.challengeData,
            evidenceStore: store,
            targetOwner: fixture.targetOwner,
            responseMode: .valid
        )
        let client = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(fixture.subjectVault),
            transport: transport,
            evidenceStore: store,
            trust: fixture.trust,
            buildProvenance: buildProvenance
        )

        let receipt = try await client.register(protectedBody: body, now: now)

        #expect(receipt.state == .activeConsented)
        #expect(receipt.deviceIdentityUUID == fixture.subject.uuid)
        #expect(await transport.sawPersistedExpectationBeforeSubmit())
        #expect(try await store.pendingExpectation() == nil)
        #expect(try await store.verifiedEvidence() != nil)

        let restartedStore = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let restartedClient = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(fixture.subjectVault),
            transport: InertDeviceIngressRegistrationTransport(),
            evidenceStore: restartedStore,
            trust: fixture.trust,
            buildProvenance: buildProvenance
        )
        let restored = try await restartedClient.restoreHistoricalRegistrationEvidence()
        #expect(restored?.receiptAtMutation == receipt)
        #expect(restored?.admissionID.isEmpty == false)
        #expect(restored?.authorityGeneration == 1)
        #expect(restored?.revocationGeneration == 1)

        let persistedText = try persistedEvidenceText(in: fixture.evidenceDirectory)
        #expect(!persistedText.contains("test-apns-token"))
        #expect(!persistedText.contains("pushToken"))
    }

    @Test
    func tamperedResponseNeverBecomesVerifiedAndLeavesPendingEvidence() async throws {
        let fixture = try await makeFixture()
        let buildProvenance = try makeBuildProvenance()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let transport = FixtureTransport(
            challengeData: fixture.challengeData,
            evidenceStore: store,
            targetOwner: fixture.targetOwner,
            responseMode: .nonCanonical
        )
        let client = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(fixture.subjectVault),
            transport: transport,
            evidenceStore: store,
            trust: fixture.trust,
            buildProvenance: buildProvenance
        )

        await #expect(throws: DeviceIngressResponseValidationError.nonCanonicalResponse) {
            try await client.register(protectedBody: body, now: now)
        }
        #expect(try await store.pendingExpectation() != nil)
        #expect(try await store.verifiedEvidence() == nil)
        #expect(await transport.submitCount() == 1)

        await #expect(throws: DeviceIngressRegistrationClientError.pendingRegistrationExists) {
            try await client.register(protectedBody: body, now: now)
        }
        #expect(await transport.submitCount() == 1)
    }

    @Test
    func missingPersistentDomainIdentityFailsBeforeTransport() async throws {
        let fixture = try await makeFixture()
        let emptyVault = EphemeralIdentityVault()
        let transport = CountingInertTransport()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let client = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(emptyVault),
            transport: transport,
            evidenceStore: store,
            trust: fixture.trust,
            buildProvenance: try makeBuildProvenance()
        )

        await #expect(throws: DeviceIngressRegistrationClientError.notificationIdentityUnavailable) {
            try await client.register(protectedBody: body, now: now)
        }
        #expect(await transport.fetchCount() == 0)
        #expect(await emptyVault.identity(
            for: DeviceIngressEnvelope.identityDomain,
            makeNewIfNotFound: false
        ) == nil)
    }

    @Test
    func fileSynchronizationFailurePreventsSubmitAndLeavesNoPendingClaim() async throws {
        let fixture = try await makeFixture()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory,
            synchronizer: FailingDurabilitySynchronizer(failure: .file)
        )
        let transport = FixtureTransport(
            challengeData: fixture.challengeData,
            evidenceStore: store,
            targetOwner: fixture.targetOwner,
            responseMode: .valid
        )
        let client = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(fixture.subjectVault),
            transport: transport,
            evidenceStore: store,
            trust: fixture.trust,
            buildProvenance: try makeBuildProvenance()
        )

        await #expect(throws: TestDurabilityError.file) {
            try await client.register(protectedBody: body, now: now)
        }
        #expect(await transport.submitCount() == 0)
        #expect(try await store.pendingExpectation() == nil)
    }

    @Test
    func directorySynchronizationFailurePreventsSubmitAndBlocksRetry() async throws {
        let fixture = try await makeFixture()
        try createPrivateDirectory(fixture.evidenceDirectory)
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory,
            synchronizer: FailingDurabilitySynchronizer(failure: .directory)
        )
        let transport = FixtureTransport(
            challengeData: fixture.challengeData,
            evidenceStore: store,
            targetOwner: fixture.targetOwner,
            responseMode: .valid
        )
        let client = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(fixture.subjectVault),
            transport: transport,
            evidenceStore: store,
            trust: fixture.trust,
            buildProvenance: try makeBuildProvenance()
        )

        await #expect(throws: TestDurabilityError.directory) {
            try await client.register(protectedBody: body, now: now)
        }
        #expect(await transport.submitCount() == 0)
        #expect(try await store.pendingExpectation() != nil)

        await #expect(throws: DeviceIngressRegistrationClientError.pendingRegistrationExists) {
            try await client.register(protectedBody: body, now: now)
        }
        #expect(await transport.submitCount() == 0)
    }

    @Test
    func separateStoreInstancesPermitOnlyOneInFlightSubmit() async throws {
        let fixture = try await makeFixture()
        let firstStore = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let secondStore = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let underlyingTransport = FixtureTransport(
            challengeData: fixture.challengeData,
            evidenceStore: firstStore,
            targetOwner: fixture.targetOwner,
            responseMode: .valid
        )
        let transport = GatedRegistrationTransport(underlying: underlyingTransport)
        let buildProvenance = try makeBuildProvenance()
        let firstClient = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(fixture.subjectVault),
            transport: transport,
            evidenceStore: firstStore,
            trust: fixture.trust,
            buildProvenance: buildProvenance
        )
        let secondClient = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(fixture.subjectVault),
            transport: transport,
            evidenceStore: secondStore,
            trust: fixture.trust,
            buildProvenance: buildProvenance
        )

        let firstRegistration = Task {
            try await firstClient.register(protectedBody: body, now: now)
        }
        await transport.waitUntilSubmitStarted()

        await #expect(throws: DeviceIngressRegistrationClientError.pendingRegistrationExists) {
            try await secondClient.register(protectedBody: body, now: now)
        }
        await transport.releaseSubmit()
        let receipt = try await firstRegistration.value

        #expect(receipt.state == .activeConsented)
        #expect(await underlyingTransport.submitCount() == 1)
    }

    @Test
    func copiedVerifiedEvidenceIsRejectedByCurrentVaultIdentity() async throws {
        let fixture = try await makeFixture()
        let buildProvenance = try makeBuildProvenance()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let transport = FixtureTransport(
            challengeData: fixture.challengeData,
            evidenceStore: store,
            targetOwner: fixture.targetOwner,
            responseMode: .valid
        )
        let registeringClient = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(fixture.subjectVault),
            transport: transport,
            evidenceStore: store,
            trust: fixture.trust,
            buildProvenance: buildProvenance
        )
        _ = try await registeringClient.register(protectedBody: body, now: now)

        let otherVault = EphemeralIdentityVault()
        var otherDeviceIdentity = Identity(
            fixture.subject.uuid,
            displayName: DeviceIngressEnvelope.identityDomain,
            identityVault: otherVault
        )
        await otherVault.addIdentity(
            identity: &otherDeviceIdentity,
            for: DeviceIngressEnvelope.identityDomain
        )
        #expect(otherDeviceIdentity.signingPublicKeyFingerprint
            != fixture.subject.signingPublicKeyFingerprint)

        let restoringClient = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(otherVault),
            transport: InertDeviceIngressRegistrationTransport(),
            evidenceStore: store,
            trust: fixture.trust,
            buildProvenance: buildProvenance
        )
        await #expect(
            throws: DeviceIngressRegistrationClientError
                .verifiedEvidenceDeviceIdentityMismatch
        ) {
            try await restoringClient.restoreHistoricalRegistrationEvidence()
        }
    }

    @Test
    func verifiedEvidenceFromDifferentBuildProvenanceIsRejected() async throws {
        let fixture = try await makeFixture()
        let registrationProvenance = try makeBuildProvenance()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let transport = FixtureTransport(
            challengeData: fixture.challengeData,
            evidenceStore: store,
            targetOwner: fixture.targetOwner,
            responseMode: .valid
        )
        let registeringClient = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(fixture.subjectVault),
            transport: transport,
            evidenceStore: store,
            trust: fixture.trust,
            buildProvenance: registrationProvenance
        )
        _ = try await registeringClient.register(protectedBody: body, now: now)

        let restoringClient = DeviceIngressRegistrationClient(
            authenticatedVault: .testing(fixture.subjectVault),
            transport: InertDeviceIngressRegistrationTransport(),
            evidenceStore: store,
            trust: fixture.trust,
            buildProvenance: try makeBuildProvenance(bindingRevisionHex: "e")
        )
        await #expect(throws: DeviceIngressRegistrationClientError.buildProvenanceMismatch) {
            try await restoringClient.restoreHistoricalRegistrationEvidence()
        }
    }

    @Test
    func symlinkEvidenceIsRejectedWithoutFollowingIt() async throws {
        let fixture = try await makeFixture()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        #expect(try await store.containsRegistrationEvidence() == false)
        let pendingURL = fixture.evidenceDirectory
            .appendingPathComponent("pending-register-expectation.json")
        try FileManager.default.createSymbolicLink(
            at: pendingURL,
            withDestinationURL: fixture.evidenceDirectory
                .appendingPathComponent("nonexistent-target")
        )

        await #expect(
            throws: DeviceIngressEvidenceFileError.metadataRejected(reason: "not-regular")
        ) {
            try await store.pendingExpectation()
        }
    }

    @Test
    func hardLinkedEvidenceIsRejected() async throws {
        let fixture = try await makeFixture()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        try await store.persistPending(try await makeExpectation(fixture))
        let pendingURL = fixture.evidenceDirectory
            .appendingPathComponent("pending-register-expectation.json")
        try FileManager.default.linkItem(
            at: pendingURL,
            to: fixture.evidenceDirectory.appendingPathComponent("attacker-hardlink")
        )

        await #expect(
            throws: DeviceIngressEvidenceFileError.metadataRejected(reason: "file-link-count")
        ) {
            try await store.pendingExpectation()
        }
    }

    @Test
    func wrongModeEvidenceIsRejected() async throws {
        let fixture = try await makeFixture()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        try await store.persistPending(try await makeExpectation(fixture))
        let path = fixture.evidenceDirectory
            .appendingPathComponent("pending-register-expectation.json").path
        #expect(Darwin.chmod(path, 0o640) == 0)

        await #expect(
            throws: DeviceIngressEvidenceFileError.metadataRejected(reason: "file-mode")
        ) {
            try await store.pendingExpectation()
        }
    }

    @Test
    func wrongOwnerMetadataIsRejectedByPolicy() {
        let metadata = DeviceIngressEvidenceMetadataSnapshot(
            device: 1,
            inode: 2,
            mode: UInt32(S_IFREG) | 0o600,
            owner: UInt32(geteuid()) &+ 1,
            linkCount: 1,
            size: 1,
            modificationSeconds: 1,
            modificationNanoseconds: 0,
            changeSeconds: 1,
            changeNanoseconds: 0
        )

        #expect(
            throws: DeviceIngressEvidenceFileError.metadataRejected(reason: "file-owner")
        ) {
            try DeviceIngressEvidenceMetadataPolicy.validateRegularFile(
                metadata,
                expectedOwner: UInt32(geteuid()),
                maximumSize: 10
            )
        }
    }

    @Test
    func fifoEvidenceIsRejected() async throws {
        let fixture = try await makeFixture()
        try createPrivateDirectory(fixture.evidenceDirectory)
        let pendingPath = fixture.evidenceDirectory
            .appendingPathComponent("pending-register-expectation.json").path
        #expect(Darwin.mkfifo(pendingPath, 0o600) == 0)
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )

        await #expect(
            throws: DeviceIngressEvidenceFileError.metadataRejected(reason: "not-regular")
        ) {
            try await store.pendingExpectation()
        }
    }

    @Test
    func pinnedDirectoryRejectsPathSwap() async throws {
        let fixture = try await makeFixture()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        #expect(try await store.containsRegistrationEvidence() == false)
        let displaced = fixture.evidenceDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("displaced-evidence")
        try FileManager.default.moveItem(at: fixture.evidenceDirectory, to: displaced)
        try createPrivateDirectory(fixture.evidenceDirectory)

        await #expect(throws: DeviceIngressEvidenceFileError.pathIdentityChanged) {
            try await store.pendingExpectation()
        }
    }

    @Test
    func concurrentWriterIsDetectedByBeforeAfterMetadata() async throws {
        let fixture = try await makeFixture()
        let pendingURL = fixture.evidenceDirectory
            .appendingPathComponent("pending-register-expectation.json")
        let observer = ConcurrentEvidenceWriter(fileURL: pendingURL)
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory,
            readObserver: observer
        )
        try await store.persistPending(try await makeExpectation(fixture))

        await #expect(
            throws: DeviceIngressEvidenceFileError.contentChangedDuringAccess
        ) {
            try await store.pendingExpectation()
        }
        #expect(observer.didMutate)
    }

    @Test
    func canonicalLockReplacementAfterAcquisitionFailsClosed() async throws {
        let fixture = try await makeFixture()
        let observer = CanonicalLockReplacer(
            directoryURL: fixture.evidenceDirectory
        )
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory,
            readObserver: observer
        )

        await #expect(throws: DeviceIngressEvidenceFileError.pathIdentityChanged) {
            try await store.containsRegistrationEvidence()
        }
        #expect(observer.didReplace)
    }

    @Test
    func durablePreRegistrationDeclineBlocksPreparedRegisterUntilExplicitAccept() async throws {
        let fixture = try await makeFixture()
        let store = FileDeviceIngressRegistrationEvidenceStore(
            directoryURL: fixture.evidenceDirectory
        )
        let expectation = try await makeExpectation(fixture)
        var clearedLocalState = false

        try store.performPreRegistrationDecline {
            clearedLocalState = true
        }

        #expect(clearedLocalState)
        await #expect(throws: DeviceIngressRegistrationClientError.preRegistrationDeclined) {
            try await store.persistPending(expectation)
        }

        try store.clearPreRegistrationDecline()
        try await store.persistPending(expectation)
        #expect(try await store.pendingExpectation() == expectation)
    }

    @Test
    func declineAndPendingPersistenceRaceNeverBothCrossTheGate() async throws {
        let fixture = try await makeFixture()
        try createPrivateDirectory(fixture.evidenceDirectory)
        let expectation = try await makeExpectation(fixture)

        for iteration in 0..<16 {
            let directory = fixture.evidenceDirectory
                .appendingPathComponent("race-\(iteration)", isDirectory: true)
            let declineStore = FileDeviceIngressRegistrationEvidenceStore(
                directoryURL: directory
            )
            let registrationStore = FileDeviceIngressRegistrationEvidenceStore(
                directoryURL: directory
            )

            let outcomes = await withTaskGroup(
                of: DeclineRegistrationRaceOutcome.self,
                returning: [DeclineRegistrationRaceOutcome].self
            ) { group in
                group.addTask {
                    do {
                        try declineStore.performPreRegistrationDecline {}
                        return .declineSucceeded
                    } catch {
                        return .declineRejected
                    }
                }
                group.addTask {
                    do {
                        try registrationStore.persistPending(expectation)
                        return .registrationSucceeded
                    } catch {
                        return .registrationRejected
                    }
                }
                var values: [DeclineRegistrationRaceOutcome] = []
                for await value in group { values.append(value) }
                return values
            }

            let declineWon = outcomes.contains(.declineSucceeded)
                && outcomes.contains(.registrationRejected)
            let registrationWon = outcomes.contains(.registrationSucceeded)
                && outcomes.contains(.declineRejected)
            #expect(declineWon != registrationWon)
        }
    }

    @Test @MainActor
    func promptFreeStartupVaultCannotBeUsedAsAuthenticatedDeviceVault() {
        let previousVault = CellBase.defaultIdentityVault
        defer { CellBase.defaultIdentityVault = previousVault }
        CellBase.defaultIdentityVault = BindingStartupIdentityVault.shared

        #expect(throws: DeviceIngressRegistrationClientError.authenticatedIdentityVaultUnavailable) {
            try DeviceIngressAuthenticatedVaultHandle.current()
        }
    }

    @Test @MainActor
    func runtimeCompositionRemainsInert() async {
        await #expect(throws: DeviceIngressRegistrationClientError.operationalCompositionUnavailable) {
            try await BindingDeviceIngressRegistrationComposition.register(
                protectedBody: Data("test".utf8),
                buildProvenance: try makeBuildProvenance()
            )
        }
    }

    @Test
    func ignoredSourceLikeFileOutsideSwiftFileListIsRejectedByProvenanceGenerator() throws {
        let fileManager = FileManager.default
        let workspace = fileManager.temporaryDirectory
            .appendingPathComponent("BindingProvenanceGeneratorTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: workspace) }

        let syntheticRoot = workspace.appendingPathComponent("Binding", isDirectory: true)
        let bindingRoot = syntheticRoot.appendingPathComponent("Binding", isDirectory: true)
        let ignoredRoot = bindingRoot.appendingPathComponent(".sprout", isDirectory: true)
        let cellsRoot = syntheticRoot.appendingPathComponent("Cells", isDirectory: true)
        let objectRoot = workspace.appendingPathComponent("Objects/arm64", isDirectory: true)
        let productsRoot = workspace.appendingPathComponent("Products", isDirectory: true)
        let sdkRoot = workspace.appendingPathComponent("SDK", isDirectory: true)
        let projectRoot = syntheticRoot.appendingPathComponent(
            "Binding.xcodeproj",
            isDirectory: true
        )
        let packageRoot = projectRoot.appendingPathComponent(
            "project.xcworkspace/xcshareddata/swiftpm",
            isDirectory: true
        )
        for directory in [
            ignoredRoot,
            cellsRoot,
            objectRoot,
            productsRoot,
            sdkRoot,
            packageRoot,
            workspace.appendingPathComponent("CellProtocol", isDirectory: true),
            workspace.appendingPathComponent("TargetTemp/DerivedSources", isDirectory: true),
            workspace.appendingPathComponent("Output", isDirectory: true)
        ] {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }

        let includedBinding = bindingRoot.appendingPathComponent("Included.swift")
        let ignoredBinding = ignoredRoot.appendingPathComponent("Unattested.swift")
        let includedCell = cellsRoot.appendingPathComponent("IncludedCell.swift")
        try writeTestFile("struct Included {}\n", to: includedBinding)
        try writeTestFile("struct Unattested {}\n", to: ignoredBinding)
        try writeTestFile("struct IncludedCell {}\n", to: includedCell)
        try writeTestFile("Binding/.sprout/\n", to: syntheticRoot.appendingPathComponent(".gitignore"))
        try writeTestFile(
            "\(includedBinding.path)\n\(includedCell.path)\n",
            to: objectRoot.appendingPathComponent("HAVEN.SwiftFileList")
        )
        for file in [
            objectRoot.appendingPathComponent("HAVEN.LinkFileList"),
            objectRoot.appendingPathComponent("Binding.swiftmodule"),
            productsRoot.appendingPathComponent("CellBase.o"),
            productsRoot.appendingPathComponent("CellApple.o"),
            sdkRoot.appendingPathComponent("SDKSettings.plist"),
            projectRoot.appendingPathComponent("project.pbxproj"),
            packageRoot.appendingPathComponent("Package.resolved")
        ] {
            try writeTestFile("fixture\n", to: file)
        }

        let gitInit = Process()
        gitInit.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        gitInit.arguments = ["-C", syntheticRoot.path, "init", "-q"]
        try gitInit.run()
        gitInit.waitUntilExit()
        #expect(gitInit.terminationStatus == 0)

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let generator = repositoryRoot
            .appendingPathComponent("Scripts/generate_binding_build_provenance.sh")
        let standardError = Pipe()
        let process = Process()
        process.executableURL = generator
        process.arguments = [
            workspace.appendingPathComponent("Output/provenance.plist").path,
            workspace.appendingPathComponent("Output/manifest.txt").path
        ]
        process.standardError = standardError
        process.environment = ProcessInfo.processInfo.environment.merging([
            "SRCROOT": syntheticRoot.path,
            "DEVELOPER_DIR": "/Applications/Xcode.app/Contents/Developer",
            "TOOLCHAIN_DIR": "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain",
            "OBJECT_FILE_DIR_normal": workspace.appendingPathComponent("Objects").path,
            "ARCHS": "arm64",
            "CURRENT_ARCH": "undefined_arch",
            "PRODUCT_NAME": "HAVEN",
            "PRODUCT_MODULE_NAME": "Binding",
            "BUILT_PRODUCTS_DIR": productsRoot.path,
            "SDKROOT": sdkRoot.path,
            "PROJECT_FILE_PATH": projectRoot.path,
            "TARGET_TEMP_DIR": workspace.appendingPathComponent("TargetTemp").path,
            "CODE_SIGNING_ALLOWED": "NO"
        ]) { _, fixture in fixture }

        try process.run()
        process.waitUntilExit()
        let errorText = String(
            data: standardError.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""

        #expect(process.terminationStatus == 65)
        #expect(errorText.contains("ignored source-like file is not attested"))
    }

    private struct Fixture {
        let subjectVault: EphemeralIdentityVault
        let subject: Identity
        let targetOwner: Identity
        let challengeData: Data
        let trust: DeviceIngressRegistrationTrustConfiguration
        let evidenceDirectory: URL
    }

    private func makeFixture() async throws -> Fixture {
        let issuerVault = EphemeralIdentityVault()
        var issuer = Identity(
            "11111111-1111-4111-8111-111111111111",
            displayName: "fixture-issuer",
            identityVault: issuerVault
        )
        await issuerVault.addIdentity(
            identity: &issuer,
            for: "domain:test:device-ingress-issuer"
        )
        let issuerDescriptor = try #require(
            DeviceIngressIdentityDescriptor.publicDescriptor(for: issuer)
        )

        let subjectVault = EphemeralIdentityVault()
        var subject = Identity(
            "22222222-2222-4222-8222-222222222222",
            displayName: DeviceIngressEnvelope.identityDomain,
            identityVault: subjectVault
        )
        await subjectVault.addIdentity(
            identity: &subject,
            for: DeviceIngressEnvelope.identityDomain
        )
        let subjectDescriptor = try #require(
            DeviceIngressIdentityDescriptor.publicDescriptor(for: subject)
        )

        let ownerVault = EphemeralIdentityVault()
        var targetOwner = Identity(
            "33333333-3333-4333-8333-333333333333",
            displayName: "fixture-owner",
            identityVault: ownerVault
        )
        await ownerVault.addIdentity(
            identity: &targetOwner,
            for: "domain:test:device-registration-owner"
        )

        let contentPolicy = DeviceIngressContentPolicy(
            requestBodyContentContractSHA256: Data(repeating: 0xA1, count: 32),
            responseContentContractSHA256: Data(repeating: 0xB2, count: 32)
        )
        let authority = DeviceIngressAuthorityReference(
            authorityID: "fixture-authority-1",
            agreementID: "fixture-agreement-1",
            targetCellUUID: "66666666-6666-4666-8666-666666666666",
            targetOwnerIdentityUUID: targetOwner.uuid,
            targetOwnerSigningKeyFingerprint: try #require(targetOwner.signingPublicKeyFingerprint),
            signedAgreementSHA256: Data(repeating: 0xC3, count: 32),
            subjectIdentityUUID: subject.uuid,
            subjectSigningKeyFingerprint: try #require(subject.signingPublicKeyFingerprint),
            authorityGeneration: 1,
            revocationLedgerID: "fixture-revocations-1",
            revocationGeneration: 1,
            contentPolicy: contentPolicy,
            issuedAtMilliseconds: milliseconds(now.addingTimeInterval(-60)),
            validUntilMilliseconds: milliseconds(now.addingTimeInterval(3_600))
        )
        let challengeData = try await DeviceIngressChallengeFactory.issue(
            operation: .register,
            audience: audience,
            subject: subjectDescriptor,
            authority: authority,
            issuer: issuer,
            now: now,
            lifetimeMilliseconds: 120_000
        )

        let evidenceAnchor = FileManager.default.temporaryDirectory
            .appendingPathComponent("BindingDeviceIngressTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try createPrivateDirectory(evidenceAnchor)

        return Fixture(
            subjectVault: subjectVault,
            subject: subject,
            targetOwner: targetOwner,
            challengeData: challengeData,
            trust: DeviceIngressRegistrationTrustConfiguration(
                expectedAudience: audience,
                expectedChallengeIssuer: issuerDescriptor
            ),
            evidenceDirectory: evidenceAnchor
                .appendingPathComponent("evidence", isDirectory: true)
        )
    }

    private func makeExpectation(
        _ fixture: Fixture
    ) async throws -> DeviceIngressResponseExpectation {
        let binding = try #require(
            await fixture.subjectVault.identityDomainBinding(for: fixture.subject)
        )
        return try await DeviceIngressRequestFactory.prepare(
            canonicalChallengeData: fixture.challengeData,
            protectedBody: body,
            requester: fixture.subject,
            domainBinding: binding,
            expectedAudience: fixture.trust.expectedAudience,
            expectedChallengeIssuer: fixture.trust.expectedChallengeIssuer,
            now: now
        ).expectation
    }

    private func createPrivateDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        guard Darwin.chmod(url.path, 0o700) == 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: "test directory chmod",
                code: errno
            )
        }
    }

    private func writeTestFile(_ value: String, to url: URL) throws {
        try Data(value.utf8).write(to: url)
    }

    private func persistedEvidenceText(in directory: URL) throws -> String {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        return try urls.map { try String(contentsOf: $0, encoding: .utf8) }.joined()
    }

    private func milliseconds(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1_000).rounded(.towardZero))
    }

    private func makeBuildProvenance(
        bindingRevisionHex: Character = "a"
    ) throws -> BindingBuildProvenance {
        try BindingBuildProvenance(
            bindingGitRevision: String(repeating: bindingRevisionHex, count: 40),
            cellProtocolGitRevision: String(repeating: "c", count: 40),
            compilerInputManifestSHA256: String(repeating: "b", count: 64),
            compilerInputCount: 2,
            generatedCompilerInputCount: 1,
            filesystemSynchronizedSourceCount: 1,
            ignoredSourceLikeInputCount: 0,
            bindingCompilerArtifactSHA256: String(repeating: "d", count: 64),
            cellProtocolArtifactSHA256: String(repeating: "e", count: 64),
            linkInputManifestSHA256: String(repeating: "f", count: 64),
            compilerFlagsSHA256: String(repeating: "1", count: 64),
            toolchainSHA256: String(repeating: "2", count: 64),
            codeSigningMode: .certificate,
            codeSigningIdentityFingerprint: String(repeating: "3", count: 40),
            codeSigningTeamIdentifier: "TESTTEAM01",
            codeSigningEntitlementsSHA256: String(repeating: "4", count: 64),
            buildConfiguration: "Test",
            sdkName: "test-sdk",
            generatedAtUTC: "2026-07-21T00:00:00Z"
        )
    }
}

private enum TestDurabilityError: Error, Equatable {
    case file
    case directory
}

private enum DeclineRegistrationRaceOutcome: Sendable {
    case declineSucceeded
    case declineRejected
    case registrationSucceeded
    case registrationRejected
}

private final class CanonicalLockReplacer:
    DeviceIngressEvidenceReadObserving,
    @unchecked Sendable
{
    private let directoryURL: URL
    private let lock = NSLock()
    private var hasReplaced = false

    init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    var didReplace: Bool {
        lock.withLock { hasReplaced }
    }

    func didOpenForRead(fileName: String) throws {}

    func didAcquireCanonicalLock(fileName: String) throws {
        let shouldReplace = lock.withLock { () -> Bool in
            guard hasReplaced == false else { return false }
            hasReplaced = true
            return true
        }
        guard shouldReplace else { return }

        let canonicalURL = directoryURL.appendingPathComponent(fileName)
        let displacedURL = directoryURL.appendingPathComponent("displaced-lock")
        try FileManager.default.moveItem(at: canonicalURL, to: displacedURL)
        let descriptor = Darwin.open(
            canonicalURL.path,
            O_RDWR | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            0o600
        )
        guard descriptor >= 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: "test replacement lock open",
                code: errno
            )
        }
        _ = Darwin.close(descriptor)
    }
}

private final class ConcurrentEvidenceWriter:
    DeviceIngressEvidenceReadObserving,
    @unchecked Sendable
{
    private let fileURL: URL
    private let lock = NSLock()
    private var hasMutated = false

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    var didMutate: Bool {
        lock.withLock { hasMutated }
    }

    func didOpenForRead(fileName: String) throws {
        guard fileName == "pending-register-expectation.json" else { return }
        let shouldMutate = lock.withLock { () -> Bool in
            guard hasMutated == false else { return false }
            hasMutated = true
            return true
        }
        guard shouldMutate else { return }

        let descriptor = Darwin.open(fileURL.path, O_WRONLY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: "test concurrent writer open",
                code: errno
            )
        }
        defer { _ = Darwin.close(descriptor) }
        var replacement = UInt8(ascii: " ")
        guard Darwin.pwrite(descriptor, &replacement, 1, 0) == 1 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: "test concurrent writer pwrite",
                code: errno
            )
        }
    }
}

nonisolated private struct FailingDurabilitySynchronizer:
    DeviceIngressDurabilitySynchronizing
{
    let failure: TestDurabilityError
    private let system = DarwinDeviceIngressDurabilitySynchronizer()

    func synchronizeFile(_ descriptor: Int32) throws {
        if failure == .file { throw TestDurabilityError.file }
        try system.synchronizeFile(descriptor)
    }

    func synchronizeDirectory(_ descriptor: Int32) throws {
        if failure == .directory { throw TestDurabilityError.directory }
        try system.synchronizeDirectory(descriptor)
    }
}

private actor GatedRegistrationTransport: DeviceIngressRegistrationTransport {
    private let underlying: FixtureTransport
    private var submitStarted = false
    private var submitReleased = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    init(underlying: FixtureTransport) {
        self.underlying = underlying
    }

    func fetchRegisterChallenge(subject: IdentityPublicKeyDescriptor) async throws -> Data {
        try await underlying.fetchRegisterChallenge(subject: subject)
    }

    func submitRegister(
        canonicalChallengeData: Data,
        canonicalRequestData: Data,
        protectedBody: Data
    ) async throws -> Data {
        submitStarted = true
        startWaiters.forEach { $0.resume() }
        startWaiters.removeAll()
        if submitReleased == false {
            await withCheckedContinuation { continuation in
                releaseWaiters.append(continuation)
            }
        }
        return try await underlying.submitRegister(
            canonicalChallengeData: canonicalChallengeData,
            canonicalRequestData: canonicalRequestData,
            protectedBody: protectedBody
        )
    }

    func waitUntilSubmitStarted() async {
        if submitStarted { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func releaseSubmit() {
        submitReleased = true
        releaseWaiters.forEach { $0.resume() }
        releaseWaiters.removeAll()
    }
}

private actor CountingInertTransport: DeviceIngressRegistrationTransport {
    private var fetches = 0

    func fetchRegisterChallenge(subject: IdentityPublicKeyDescriptor) throws -> Data {
        fetches += 1
        throw DeviceIngressRegistrationClientError.operationalCompositionUnavailable
    }

    func submitRegister(
        canonicalChallengeData: Data,
        canonicalRequestData: Data,
        protectedBody: Data
    ) throws -> Data {
        throw DeviceIngressRegistrationClientError.operationalCompositionUnavailable
    }

    func fetchCount() -> Int { fetches }
}

private actor FixtureTransport: DeviceIngressRegistrationTransport {
    enum ResponseMode {
        case valid
        case nonCanonical
    }

    private let challengeData: Data
    private let evidenceStore: any DeviceIngressRegistrationEvidenceStoring
    private let targetOwner: Identity
    private let responseMode: ResponseMode
    private var expectationWasPresent = false
    private var submits = 0

    init(
        challengeData: Data,
        evidenceStore: any DeviceIngressRegistrationEvidenceStoring,
        targetOwner: Identity,
        responseMode: ResponseMode
    ) {
        self.challengeData = challengeData
        self.evidenceStore = evidenceStore
        self.targetOwner = targetOwner
        self.responseMode = responseMode
    }

    func fetchRegisterChallenge(subject: IdentityPublicKeyDescriptor) -> Data {
        challengeData
    }

    func submitRegister(
        canonicalChallengeData: Data,
        canonicalRequestData: Data,
        protectedBody: Data
    ) async throws -> Data {
        submits += 1
        let expectation = try #require(await evidenceStore.pendingExpectation())
        expectationWasPresent = true
        var response = try await Self.signedRegistrationResponse(
            expectation: expectation,
            targetOwner: targetOwner
        )
        if responseMode == .nonCanonical {
            response.append(0x20)
        }
        return response
    }

    func sawPersistedExpectationBeforeSubmit() -> Bool {
        expectationWasPresent
    }

    func submitCount() -> Int { submits }

    private static func signedRegistrationResponse(
        expectation: DeviceIngressResponseExpectation,
        targetOwner: Identity
    ) async throws -> Data {
        let committedAt = expectation.requestIssuedAtMilliseconds + 1
        let registrationReceipt = DeviceIngressRegistrationReceipt(
            registrationID: "fixture-registration-1",
            deviceIdentityUUID: expectation.subjectIdentityUUID,
            registrationGeneration: 1,
            durableSequence: 1,
            state: .activeConsented,
            registrationRecordSHA256: Data(repeating: 0xD4, count: 32),
            committedAtMilliseconds: committedAt
        )
        let result = DeviceIngressOperationResult.registration(registrationReceipt)
        let resultSHA256 = DeviceIngressCanonicalWire.sha256(try result.canonicalData())
        let mutationRecordSHA256 = Data(repeating: 0xE5, count: 32)
        let responseID = try DeviceIngressMutationReceipt.responseID(
            admissionID: expectation.admissionID,
            requestSHA256: expectation.requestSHA256,
            mutationRecordSHA256: mutationRecordSHA256,
            operationResultSHA256: resultSHA256
        )
        let mutationReceipt = DeviceIngressMutationReceipt(
            responseID: responseID,
            operation: .register,
            admissionID: expectation.admissionID,
            requestSHA256: expectation.requestSHA256,
            challengeSHA256: expectation.challengeSHA256,
            bodySHA256: expectation.bodySHA256,
            targetCellUUID: expectation.targetCellUUID,
            targetOwnerIdentityUUID: expectation.targetOwnerIdentityUUID,
            targetOwnerSigningKeyFingerprint: expectation.targetOwnerSigningKeyFingerprint,
            subjectIdentityUUID: expectation.subjectIdentityUUID,
            subjectSigningKeyFingerprint: expectation.subjectSigningKeyFingerprint,
            signedAgreementSHA256: expectation.signedAgreementSHA256,
            authorityGeneration: expectation.authorityGeneration,
            revocationLedgerID: expectation.revocationLedgerID,
            revocationGeneration: expectation.revocationGeneration,
            contentPolicySHA256: try expectation.contentPolicy.canonicalSHA256(),
            mutationRecordSHA256: mutationRecordSHA256,
            operationResultSHA256: resultSHA256,
            durableSequence: 1,
            committedAtMilliseconds: committedAt
        )
        let signer = try #require(
            DeviceIngressIdentityDescriptor.publicDescriptor(for: targetOwner)
        )
        let unsignedFixture = OperationResponseFixture(
            responseID: responseID,
            operation: .register,
            admissionID: expectation.admissionID,
            requestSHA256: expectation.requestSHA256,
            challengeSHA256: expectation.challengeSHA256,
            bodySHA256: expectation.bodySHA256,
            mutationReceiptSHA256: DeviceIngressCanonicalWire.sha256(
                try mutationReceipt.canonicalData()
            ),
            operationResultSHA256: resultSHA256,
            targetCellUUID: expectation.targetCellUUID,
            targetOwnerIdentityUUID: expectation.targetOwnerIdentityUUID,
            targetOwnerSigningKeyFingerprint: expectation.targetOwnerSigningKeyFingerprint,
            subjectIdentityUUID: expectation.subjectIdentityUUID,
            subjectSigningKeyFingerprint: expectation.subjectSigningKeyFingerprint,
            signedAgreementSHA256: expectation.signedAgreementSHA256,
            authorityGeneration: expectation.authorityGeneration,
            revocationLedgerID: expectation.revocationLedgerID,
            revocationGeneration: expectation.revocationGeneration,
            contentPolicySHA256: try expectation.contentPolicy.canonicalSHA256(),
            mutationReceipt: mutationReceipt,
            result: result,
            issuedAtMilliseconds: committedAt,
            expiresAtMilliseconds: expectation.requestExpiresAtMilliseconds,
            signer: signer,
            proof: nil
        )
        var response = try JSONDecoder().decode(
            DeviceIngressOperationResponse.self,
            from: JSONEncoder().encode(unsignedFixture)
        )
        let signature = try #require(
            try await targetOwner.sign(data: response.canonicalPayloadData())
        )
        response.proof = DeviceIngressIdentityProof(
            signerIdentityUUID: targetOwner.uuid,
            signature: signature
        )
        return try response.canonicalWireData()
    }
}

private struct OperationResponseFixture: Codable {
    var schema = DeviceIngressOperationResponse.currentSchema
    let responseID: String
    let operation: DeviceIngressOperation
    let admissionID: String
    let requestSHA256: Data
    let challengeSHA256: Data
    let bodySHA256: Data
    let mutationReceiptSHA256: Data
    let operationResultSHA256: Data
    let targetCellUUID: String
    let targetOwnerIdentityUUID: String
    let targetOwnerSigningKeyFingerprint: String
    let subjectIdentityUUID: String
    let subjectSigningKeyFingerprint: String
    let signedAgreementSHA256: Data
    let authorityGeneration: UInt64
    let revocationLedgerID: String
    let revocationGeneration: UInt64
    let contentPolicySHA256: Data
    let mutationReceipt: DeviceIngressMutationReceipt
    let result: DeviceIngressOperationResult
    let issuedAtMilliseconds: Int64
    let expiresAtMilliseconds: Int64
    let signer: IdentityPublicKeyDescriptor
    var proof: DeviceIngressIdentityProof?
}
