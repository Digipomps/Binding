import Foundation
import CellBase
import CellApple
import Darwin

nonisolated enum DeviceIngressRegistrationClientError: LocalizedError, Equatable {
    case operationalCompositionUnavailable
    case authenticatedIdentityVaultUnavailable
    case notificationIdentityUnavailable
    case notificationDomainBindingUnavailable
    case notificationIdentityDescriptorUnavailable
    case invalidProtectedBody
    case pendingRegistrationExists
    case verifiedRegistrationExists
    case preRegistrationDeclined
    case registrationEvidencePreventsPreRegistrationDecline
    case pendingExpectationMissing
    case pendingExpectationMismatch
    case evidenceTooLarge
    case evidenceDirectoryUnavailable
    case verifiedEvidenceDeviceIdentityMismatch
    case buildProvenanceMismatch
    case responseWasNotRegistration
    case registrationWasNotActiveAndConsented

    var errorDescription: String? {
        switch self {
        case .operationalCompositionUnavailable:
            return "DeviceIngress v3 registration is fail-closed until the reviewed server composition and pinned trust configuration are operational."
        case .authenticatedIdentityVaultUnavailable:
            return "The authenticated persistent CellApple identity vault is unavailable."
        case .notificationIdentityUnavailable:
            return "The persistent notification-callback identity has not been provisioned."
        case .notificationDomainBindingUnavailable:
            return "The notification-callback identity is not uniquely bound to its required domain."
        case .notificationIdentityDescriptorUnavailable:
            return "The notification-callback identity has no usable public signing descriptor."
        case .invalidProtectedBody:
            return "The protected registration body is empty or exceeds the DeviceIngress limit."
        case .pendingRegistrationExists:
            return "An unresolved DeviceIngress registration request already exists; automatic replay is disabled."
        case .verifiedRegistrationExists:
            return "Historical verified registration evidence already exists; a fresh signed status/read-back is required before another register attempt."
        case .preRegistrationDeclined:
            return "Notification registration is locally closed by a durable pre-registration decline."
        case .registrationEvidencePreventsPreRegistrationDecline:
            return "Pending or verified registration evidence exists; pre-registration decline cannot represent server revocation, so a signed revoke/deregister flow is required."
        case .pendingExpectationMissing:
            return "The persisted response expectation is missing."
        case .pendingExpectationMismatch:
            return "The persisted response expectation does not match this registration response."
        case .evidenceTooLarge:
            return "The persisted DeviceIngress evidence exceeds its local size limit."
        case .evidenceDirectoryUnavailable:
            return "The persistent DeviceIngress evidence directory is unavailable."
        case .verifiedEvidenceDeviceIdentityMismatch:
            return "The verified registration evidence belongs to a different device identity."
        case .buildProvenanceMismatch:
            return "The verified registration evidence belongs to a different Binding build."
        case .responseWasNotRegistration:
            return "The signed DeviceIngress response was not a registration receipt."
        case .registrationWasNotActiveAndConsented:
            return "The signed registration receipt did not confirm active consent."
        }
    }
}

nonisolated struct DeviceIngressRegistrationTrustConfiguration: Sendable {
    let expectedAudience: String
    let expectedChallengeIssuer: IdentityPublicKeyDescriptor
}

nonisolated protocol DeviceIngressRegistrationTransport: Sendable {
    /// Retrieves exact canonical challenge bytes. Transport framing is outside
    /// this protocol and must come from a separately reviewed composition.
    func fetchRegisterChallenge(
        subject: IdentityPublicKeyDescriptor
    ) async throws -> Data

    /// Carries the three byte strings without decoding, re-encoding or making
    /// an authority decision.
    func submitRegister(
        canonicalChallengeData: Data,
        canonicalRequestData: Data,
        protectedBody: Data
    ) async throws -> Data
}

nonisolated struct InertDeviceIngressRegistrationTransport: DeviceIngressRegistrationTransport {
    func fetchRegisterChallenge(
        subject: IdentityPublicKeyDescriptor
    ) async throws -> Data {
        throw DeviceIngressRegistrationClientError.operationalCompositionUnavailable
    }

    func submitRegister(
        canonicalChallengeData: Data,
        canonicalRequestData: Data,
        protectedBody: Data
    ) async throws -> Data {
        throw DeviceIngressRegistrationClientError.operationalCompositionUnavailable
    }
}

nonisolated struct DeviceIngressVerifiedRegistrationEvidence: Codable, Equatable, Sendable {
    static let currentSchema = "binding.device-ingress.registration-evidence.v2"

    let schema: String
    let expectation: DeviceIngressResponseExpectation
    let canonicalResponseData: Data
    let buildProvenance: BindingBuildProvenance

    init(
        expectation: DeviceIngressResponseExpectation,
        canonicalResponseData: Data,
        buildProvenance: BindingBuildProvenance
    ) {
        schema = Self.currentSchema
        self.expectation = expectation
        self.canonicalResponseData = canonicalResponseData
        self.buildProvenance = buildProvenance
    }
}

/// Cryptographically verified history from an earlier register mutation.
/// This type intentionally cannot represent current registration state. A
/// current-state claim requires a new signed server status/read-back bound to
/// current admission and revocation generations, which the register-only
/// Binding composition does not implement.
nonisolated struct DeviceIngressHistoricalRegistrationEvidence: Equatable, Sendable {
    let receiptAtMutation: DeviceIngressRegistrationReceipt
    let admissionID: String
    let authorityGeneration: UInt64
    let revocationLedgerID: String
    let revocationGeneration: UInt64
    let signedResponseIssuedAtMilliseconds: Int64
    let buildProvenance: BindingBuildProvenance
}

nonisolated struct DeviceIngressPreRegistrationDeclineTombstone:
    Codable,
    Equatable,
    Sendable
{
    static let currentSchema = "binding.device-ingress.pre-registration-decline.v1"

    let schema: String

    init() {
        schema = Self.currentSchema
    }
}

nonisolated protocol DeviceIngressRegistrationEvidenceStoring: Sendable {
    func persistPending(
        _ expectation: DeviceIngressResponseExpectation
    ) throws
    func pendingExpectation() throws -> DeviceIngressResponseExpectation?
    func commitVerified(
        expectation: DeviceIngressResponseExpectation,
        canonicalResponseData: Data,
        buildProvenance: BindingBuildProvenance
    ) throws
    func verifiedEvidence() throws -> DeviceIngressVerifiedRegistrationEvidence?
    func containsRegistrationEvidence() throws -> Bool
    func performPreRegistrationDecline(_ localStateClear: () -> Void) throws
    func clearPreRegistrationDecline() throws
}

nonisolated enum DeviceIngressEvidenceFileError: LocalizedError, Equatable {
    case posix(operation: String, code: Int32)
    case invalidPathComponent
    case metadataRejected(reason: String)
    case pathIdentityChanged
    case contentChangedDuringAccess

    var errorDescription: String? {
        switch self {
        case let .posix(operation, code):
            return "DeviceIngress evidence \(operation) failed with errno \(code)."
        case .invalidPathComponent:
            return "DeviceIngress evidence contains an invalid path component."
        case let .metadataRejected(reason):
            return "DeviceIngress evidence metadata was rejected: \(reason)."
        case .pathIdentityChanged:
            return "DeviceIngress evidence path identity changed during access."
        case .contentChangedDuringAccess:
            return "DeviceIngress evidence content changed during access."
        }
    }
}

nonisolated struct DeviceIngressEvidenceMetadataSnapshot: Equatable, Sendable {
    let device: UInt64
    let inode: UInt64
    let mode: UInt32
    let owner: UInt32
    let linkCount: UInt64
    let size: Int64
    let modificationSeconds: Int64
    let modificationNanoseconds: Int64
    let changeSeconds: Int64
    let changeNanoseconds: Int64

    init(
        device: UInt64,
        inode: UInt64,
        mode: UInt32,
        owner: UInt32,
        linkCount: UInt64,
        size: Int64,
        modificationSeconds: Int64,
        modificationNanoseconds: Int64,
        changeSeconds: Int64,
        changeNanoseconds: Int64
    ) {
        self.device = device
        self.inode = inode
        self.mode = mode
        self.owner = owner
        self.linkCount = linkCount
        self.size = size
        self.modificationSeconds = modificationSeconds
        self.modificationNanoseconds = modificationNanoseconds
        self.changeSeconds = changeSeconds
        self.changeNanoseconds = changeNanoseconds
    }

    init(_ value: stat) {
        device = UInt64(bitPattern: Int64(value.st_dev))
        inode = UInt64(value.st_ino)
        mode = UInt32(value.st_mode)
        owner = UInt32(value.st_uid)
        linkCount = UInt64(value.st_nlink)
        size = Int64(value.st_size)
        modificationSeconds = Int64(value.st_mtimespec.tv_sec)
        modificationNanoseconds = Int64(value.st_mtimespec.tv_nsec)
        changeSeconds = Int64(value.st_ctimespec.tv_sec)
        changeNanoseconds = Int64(value.st_ctimespec.tv_nsec)
    }

    func hasSameIdentity(as other: Self) -> Bool {
        device == other.device && inode == other.inode
    }
}

nonisolated enum DeviceIngressEvidenceMetadataPolicy {
    static func validateDirectory(
        _ metadata: DeviceIngressEvidenceMetadataSnapshot,
        expectedOwner: UInt32
    ) throws {
        guard metadata.mode & UInt32(S_IFMT) == UInt32(S_IFDIR) else {
            throw DeviceIngressEvidenceFileError.metadataRejected(reason: "not-directory")
        }
        guard metadata.mode & 0o7777 == 0o700 else {
            throw DeviceIngressEvidenceFileError.metadataRejected(reason: "directory-mode")
        }
        guard metadata.owner == expectedOwner else {
            throw DeviceIngressEvidenceFileError.metadataRejected(reason: "directory-owner")
        }
    }

    static func validateRegularFile(
        _ metadata: DeviceIngressEvidenceMetadataSnapshot,
        expectedOwner: UInt32,
        maximumSize: Int
    ) throws {
        guard metadata.mode & UInt32(S_IFMT) == UInt32(S_IFREG) else {
            throw DeviceIngressEvidenceFileError.metadataRejected(reason: "not-regular")
        }
        guard metadata.mode & 0o7777 == 0o600 else {
            throw DeviceIngressEvidenceFileError.metadataRejected(reason: "file-mode")
        }
        guard metadata.owner == expectedOwner else {
            throw DeviceIngressEvidenceFileError.metadataRejected(reason: "file-owner")
        }
        guard metadata.linkCount == 1 else {
            throw DeviceIngressEvidenceFileError.metadataRejected(reason: "file-link-count")
        }
        guard metadata.size >= 0, metadata.size <= Int64(maximumSize) else {
            throw DeviceIngressRegistrationClientError.evidenceTooLarge
        }
    }
}

nonisolated protocol DeviceIngressEvidenceReadObserving: Sendable {
    func didOpenForRead(fileName: String) throws
    func didAcquireCanonicalLock(fileName: String) throws
}

nonisolated extension DeviceIngressEvidenceReadObserving {
    func didAcquireCanonicalLock(fileName: String) throws {}
}

nonisolated struct NoopDeviceIngressEvidenceReadObserver:
    DeviceIngressEvidenceReadObserving
{
    func didOpenForRead(fileName: String) throws {}
}

nonisolated protocol DeviceIngressDurabilitySynchronizing: Sendable {
    func synchronizeFile(_ descriptor: Int32) throws
    func synchronizeDirectory(_ descriptor: Int32) throws
}

nonisolated struct DarwinDeviceIngressDurabilitySynchronizer:
    DeviceIngressDurabilitySynchronizing
{
    func synchronizeFile(_ descriptor: Int32) throws {
        guard Darwin.fsync(descriptor) == 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: "file fsync",
                code: errno
            )
        }
        guard Darwin.fcntl(descriptor, F_FULLFSYNC) == 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: "file fullfsync",
                code: errno
            )
        }
    }

    func synchronizeDirectory(_ descriptor: Int32) throws {
        guard Darwin.fsync(descriptor) == 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: "directory fsync",
                code: errno
            )
        }
    }
}

nonisolated final class FileDeviceIngressRegistrationEvidenceStore:
    DeviceIngressRegistrationEvidenceStoring,
    @unchecked Sendable
{
    private static let maximumEvidenceBytes = 256 * 1_024
    private static let processLock = NSLock()
    private let anchorPath: String
    private let relativeDirectoryComponents: [String]
    private let synchronizer: any DeviceIngressDurabilitySynchronizing
    private let readObserver: any DeviceIngressEvidenceReadObserving
    private var pinnedDirectories: [PinnedDirectory] = []
    private var activeTransactionValidator: (() throws -> Void)?

    private struct PinnedDirectory: Sendable {
        let descriptor: Int32
        let parentIndex: Int?
        let nameInParent: String?
        let requiresPrivateMetadata: Bool
    }

    init(
        directoryURL: URL,
        synchronizer: any DeviceIngressDurabilitySynchronizing =
            DarwinDeviceIngressDurabilitySynchronizer(),
        readObserver: any DeviceIngressEvidenceReadObserving =
            NoopDeviceIngressEvidenceReadObserver()
    ) {
        anchorPath = directoryURL.deletingLastPathComponent()
            .resolvingSymlinksInPath().path
        relativeDirectoryComponents = [directoryURL.lastPathComponent]
        self.synchronizer = synchronizer
        self.readObserver = readObserver
    }

    init(
        anchorDirectoryURL: URL,
        relativeDirectoryComponents: [String],
        synchronizer: any DeviceIngressDurabilitySynchronizing =
            DarwinDeviceIngressDurabilitySynchronizer(),
        readObserver: any DeviceIngressEvidenceReadObserving =
            NoopDeviceIngressEvidenceReadObserver()
    ) {
        anchorPath = anchorDirectoryURL.resolvingSymlinksInPath().path
        self.relativeDirectoryComponents = relativeDirectoryComponents
        self.synchronizer = synchronizer
        self.readObserver = readObserver
    }

    deinit {
        for directory in pinnedDirectories.reversed() {
            _ = Darwin.close(directory.descriptor)
        }
    }

    static func applicationSupport(fileManager: FileManager = .default) throws -> Self {
        guard let base = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw DeviceIngressRegistrationClientError.evidenceDirectoryUnavailable
        }
        return Self(
            anchorDirectoryURL: base,
            relativeDirectoryComponents: ["Binding", "DeviceIngressRegistration"]
        )
    }

    func persistPending(
        _ expectation: DeviceIngressResponseExpectation
    ) throws {
        try withExclusiveAccess {
            guard try readUnlocked(
                DeviceIngressPreRegistrationDeclineTombstone.self,
                from: preRegistrationDeclineFileName,
                directoryDescriptor: $0
            ) == nil else {
                throw DeviceIngressRegistrationClientError.preRegistrationDeclined
            }
            guard try readUnlocked(
                DeviceIngressResponseExpectation.self,
                from: pendingFileName,
                directoryDescriptor: $0
            ) == nil else {
                throw DeviceIngressRegistrationClientError.pendingRegistrationExists
            }
            guard try readUnlocked(
                DeviceIngressVerifiedRegistrationEvidence.self,
                from: verifiedFileName,
                directoryDescriptor: $0
            ) == nil else {
                throw DeviceIngressRegistrationClientError.verifiedRegistrationExists
            }
            try writeUnlocked(
                expectation,
                to: pendingFileName,
                directoryDescriptor: $0,
                replaceExisting: false
            )
        }
    }

    func pendingExpectation() throws -> DeviceIngressResponseExpectation? {
        try withExclusiveAccess {
            try readUnlocked(
                DeviceIngressResponseExpectation.self,
                from: pendingFileName,
                directoryDescriptor: $0
            )
        }
    }

    func commitVerified(
        expectation: DeviceIngressResponseExpectation,
        canonicalResponseData: Data,
        buildProvenance: BindingBuildProvenance
    ) throws {
        try withExclusiveAccess {
            guard let pending = try readUnlocked(
                DeviceIngressResponseExpectation.self,
                from: pendingFileName,
                directoryDescriptor: $0
            ) else {
                throw DeviceIngressRegistrationClientError.pendingExpectationMissing
            }
            guard pending == expectation else {
                throw DeviceIngressRegistrationClientError.pendingExpectationMismatch
            }

            let evidence = DeviceIngressVerifiedRegistrationEvidence(
                expectation: expectation,
                canonicalResponseData: canonicalResponseData,
                buildProvenance: buildProvenance
            )
            try writeUnlocked(
                evidence,
                to: verifiedFileName,
                directoryDescriptor: $0,
                replaceExisting: true
            )
            try removeUnlocked(pendingFileName, directoryDescriptor: $0)
        }
    }

    func verifiedEvidence() throws -> DeviceIngressVerifiedRegistrationEvidence? {
        try withExclusiveAccess {
            try readUnlocked(
                DeviceIngressVerifiedRegistrationEvidence.self,
                from: verifiedFileName,
                directoryDescriptor: $0
            )
        }
    }

    func containsRegistrationEvidence() throws -> Bool {
        try withExclusiveAccess {
            let pending = try readUnlocked(
                DeviceIngressResponseExpectation.self,
                from: pendingFileName,
                directoryDescriptor: $0
            )
            let verified = try readUnlocked(
                DeviceIngressVerifiedRegistrationEvidence.self,
                from: verifiedFileName,
                directoryDescriptor: $0
            )
            return pending != nil || verified != nil
        }
    }

    /// Atomically establishes a durable local pre-registration gate only if
    /// there is no pending or verified register evidence. Once this method
    /// returns, a register attempt prepared from stale in-memory consent still
    /// cannot persist its expectation.
    func performPreRegistrationDecline(_ localStateClear: () -> Void) throws {
        try withExclusiveAccess {
            let pending = try readUnlocked(
                DeviceIngressResponseExpectation.self,
                from: pendingFileName,
                directoryDescriptor: $0
            )
            let verified = try readUnlocked(
                DeviceIngressVerifiedRegistrationEvidence.self,
                from: verifiedFileName,
                directoryDescriptor: $0
            )
            guard pending == nil, verified == nil else {
                throw DeviceIngressRegistrationClientError
                    .registrationEvidencePreventsPreRegistrationDecline
            }
            try writeUnlocked(
                DeviceIngressPreRegistrationDeclineTombstone(),
                to: preRegistrationDeclineFileName,
                directoryDescriptor: $0,
                replaceExisting: true
            )
            localStateClear()
            try validateActiveTransaction()
        }
    }

    func clearPreRegistrationDecline() throws {
        try withExclusiveAccess {
            try removeUnlocked(
                preRegistrationDeclineFileName,
                directoryDescriptor: $0
            )
        }
    }

    private let pendingFileName = "pending-register-expectation.json"
    private let verifiedFileName = "verified-register-evidence.json"
    private let preRegistrationDeclineFileName = "pre-registration-decline.json"
    private let lockFileName = "registration.lock"

    /// NSLock closes the same-process gap in POSIX record-lock semantics;
    /// lockf then serializes cooperating app/extension processes using the
    /// same store.
    private func withExclusiveAccess<T>(_ body: (Int32) throws -> T) throws -> T {
        Self.processLock.lock()
        defer { Self.processLock.unlock() }

        let directoryDescriptor = try pinnedDirectoryDescriptor()
        try validatePinnedDirectoryChain()
        let descriptor = try openFileAt(
            directoryDescriptor,
            name: lockFileName,
            flags: O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW,
            mode: 0o600,
            operation: "lock open"
        )
        defer { _ = Darwin.close(descriptor) }
        let lockMetadata = try metadataForDescriptor(descriptor, operation: "lock stat")
        try validateRegularFile(lockMetadata)
        let lockPathMetadata = try requiredMetadataAt(
            directoryDescriptor,
            name: lockFileName
        )
        guard lockMetadata.hasSameIdentity(as: lockPathMetadata) else {
            throw DeviceIngressEvidenceFileError.pathIdentityChanged
        }

        while Darwin.lockf(descriptor, F_LOCK, 0) != 0 {
            guard errno == EINTR else {
                throw DeviceIngressEvidenceFileError.posix(
                    operation: "lock acquire",
                    code: errno
                )
            }
        }
        defer { _ = Darwin.lockf(descriptor, F_ULOCK, 0) }
        try readObserver.didAcquireCanonicalLock(fileName: lockFileName)
        let validateCanonicalLock = { [unowned self] in
            try self.validateCanonicalLockBinding(
                descriptor: descriptor,
                expectedMetadata: lockMetadata,
                directoryDescriptor: directoryDescriptor
            )
        }
        try validateCanonicalLock()
        activeTransactionValidator = validateCanonicalLock
        defer { activeTransactionValidator = nil }
        do {
            let result = try body(directoryDescriptor)
            try validateCanonicalLock()
            return result
        } catch let bodyError {
            // If the canonical name was replaced while the body failed for a
            // different reason, the split-lock condition takes precedence.
            try validateCanonicalLock()
            throw bodyError
        }
    }

    private func validateCanonicalLockBinding(
        descriptor: Int32,
        expectedMetadata: DeviceIngressEvidenceMetadataSnapshot,
        directoryDescriptor: Int32
    ) throws {
        try validatePinnedDirectoryChain()
        let descriptorMetadata = try metadataForDescriptor(
            descriptor,
            operation: "locked descriptor stat"
        )
        try validateRegularFile(descriptorMetadata)
        guard descriptorMetadata.size == 0 else {
            throw DeviceIngressEvidenceFileError.metadataRejected(reason: "lock-size")
        }
        let canonicalMetadata = try requiredMetadataAt(
            directoryDescriptor,
            name: lockFileName
        )
        try validateRegularFile(canonicalMetadata)
        guard canonicalMetadata.size == 0 else {
            throw DeviceIngressEvidenceFileError.metadataRejected(reason: "lock-size")
        }
        guard descriptorMetadata == expectedMetadata,
              canonicalMetadata == expectedMetadata else {
            throw DeviceIngressEvidenceFileError.pathIdentityChanged
        }
    }

    private func validateActiveTransaction() throws {
        guard let activeTransactionValidator else {
            throw DeviceIngressEvidenceFileError.pathIdentityChanged
        }
        try activeTransactionValidator()
    }

    private func pinnedDirectoryDescriptor() throws -> Int32 {
        if let descriptor = pinnedDirectories.last?.descriptor {
            try validatePinnedDirectoryChain()
            return descriptor
        }

        var opened: [PinnedDirectory] = []
        do {
            let rootDescriptor = Darwin.open(
                "/",
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
            )
            guard rootDescriptor >= 0 else {
                throw DeviceIngressEvidenceFileError.posix(
                    operation: "root directory open",
                    code: errno
                )
            }
            opened.append(PinnedDirectory(
                descriptor: rootDescriptor,
                parentIndex: nil,
                nameInParent: nil,
                requiresPrivateMetadata: false
            ))

            let anchorComponents = URL(fileURLWithPath: anchorPath)
                .standardizedFileURL.pathComponents.filter { $0 != "/" }
            for component in anchorComponents {
                try appendPinnedDirectory(
                    component,
                    createIfMissing: false,
                    requiresPrivateMetadata: false,
                    to: &opened
                )
            }
            guard opened.count > 1 else {
                throw DeviceIngressRegistrationClientError.evidenceDirectoryUnavailable
            }
            let anchorIndex = opened.index(before: opened.endIndex)
            opened[anchorIndex] = PinnedDirectory(
                descriptor: opened[anchorIndex].descriptor,
                parentIndex: opened[anchorIndex].parentIndex,
                nameInParent: opened[anchorIndex].nameInParent,
                requiresPrivateMetadata: true
            )
            try DeviceIngressEvidenceMetadataPolicy.validateDirectory(
                try metadataForDescriptor(
                    opened[anchorIndex].descriptor,
                    operation: "anchor directory stat"
                ),
                expectedOwner: UInt32(geteuid())
            )

            for component in relativeDirectoryComponents {
                try appendPinnedDirectory(
                    component,
                    createIfMissing: true,
                    requiresPrivateMetadata: true,
                    to: &opened
                )
            }
            pinnedDirectories = opened
            try validatePinnedDirectoryChain()
            return try requirePinnedDirectoryDescriptor()
        } catch {
            pinnedDirectories = []
            for directory in opened.reversed() {
                _ = Darwin.close(directory.descriptor)
            }
            throw error
        }
    }

    private func appendPinnedDirectory(
        _ component: String,
        createIfMissing: Bool,
        requiresPrivateMetadata: Bool,
        to opened: inout [PinnedDirectory]
    ) throws {
        try validatePathComponent(component)
        guard let parent = opened.last else {
            throw DeviceIngressRegistrationClientError.evidenceDirectoryUnavailable
        }
        if try metadataAt(parent.descriptor, name: component) == nil {
            guard createIfMissing else {
                throw DeviceIngressRegistrationClientError.evidenceDirectoryUnavailable
            }
            let result = component.withCString {
                Darwin.mkdirat(parent.descriptor, $0, 0o700)
            }
            guard result == 0 || errno == EEXIST else {
                throw DeviceIngressEvidenceFileError.posix(
                    operation: "directory create",
                    code: errno
                )
            }
            try synchronizer.synchronizeDirectory(parent.descriptor)
        }
        let before = try requiredMetadataAt(parent.descriptor, name: component)
        if requiresPrivateMetadata {
            try DeviceIngressEvidenceMetadataPolicy.validateDirectory(
                before,
                expectedOwner: UInt32(geteuid())
            )
        } else {
            guard before.mode & UInt32(S_IFMT) == UInt32(S_IFDIR) else {
                throw DeviceIngressEvidenceFileError.metadataRejected(reason: "path-not-directory")
            }
        }
        let descriptor = try openFileAt(
            parent.descriptor,
            name: component,
            flags: O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW,
            mode: 0,
            operation: "directory open"
        )
        let after = try metadataForDescriptor(descriptor, operation: "directory stat")
        guard before.hasSameIdentity(as: after) else {
            _ = Darwin.close(descriptor)
            throw DeviceIngressEvidenceFileError.pathIdentityChanged
        }
        opened.append(PinnedDirectory(
            descriptor: descriptor,
            parentIndex: opened.index(before: opened.endIndex),
            nameInParent: component,
            requiresPrivateMetadata: requiresPrivateMetadata
        ))
    }

    private func validatePinnedDirectoryChain() throws {
        guard pinnedDirectories.isEmpty == false else { return }
        for (index, directory) in pinnedDirectories.enumerated() {
            let descriptorMetadata = try metadataForDescriptor(
                directory.descriptor,
                operation: "pinned directory stat"
            )
            if directory.requiresPrivateMetadata {
                try DeviceIngressEvidenceMetadataPolicy.validateDirectory(
                    descriptorMetadata,
                    expectedOwner: UInt32(geteuid())
                )
            } else {
                guard descriptorMetadata.mode & UInt32(S_IFMT) == UInt32(S_IFDIR) else {
                    throw DeviceIngressEvidenceFileError.metadataRejected(
                        reason: "pinned-path-not-directory"
                    )
                }
            }
            if let parentIndex = directory.parentIndex,
               let name = directory.nameInParent {
                guard parentIndex < index else {
                    throw DeviceIngressEvidenceFileError.pathIdentityChanged
                }
                let pathMetadata = try requiredMetadataAt(
                    pinnedDirectories[parentIndex].descriptor,
                    name: name
                )
                guard descriptorMetadata.hasSameIdentity(as: pathMetadata) else {
                    throw DeviceIngressEvidenceFileError.pathIdentityChanged
                }
            }
        }
    }

    private func requirePinnedDirectoryDescriptor() throws -> Int32 {
        guard let descriptor = pinnedDirectories.last?.descriptor else {
            throw DeviceIngressRegistrationClientError.evidenceDirectoryUnavailable
        }
        return descriptor
    }

    private func writeUnlocked<T: Encodable>(
        _ value: T,
        to fileName: String,
        directoryDescriptor: Int32,
        replaceExisting: Bool
    ) throws {
        try validateActiveTransaction()
        try validatePathComponent(fileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        guard data.count <= Self.maximumEvidenceBytes else {
            throw DeviceIngressRegistrationClientError.evidenceTooLarge
        }

        let temporaryName = ".\(fileName).\(UUID().uuidString).tmp"
        var descriptor = try openFileAt(
            directoryDescriptor,
            name: temporaryName,
            flags: O_RDWR | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            mode: 0o600,
            operation: "temporary file open"
        )
        var renamed = false
        defer {
            if descriptor >= 0 {
                _ = Darwin.close(descriptor)
            }
            if renamed == false {
                _ = temporaryName.withCString {
                    Darwin.unlinkat(directoryDescriptor, $0, 0)
                }
            }
        }

        try validateActiveTransaction()
        let createdMetadata = try metadataForDescriptor(
            descriptor,
            operation: "temporary file stat"
        )
        try validateRegularFile(createdMetadata)
        try writeAll(data, to: descriptor)
        try synchronizer.synchronizeFile(descriptor)
        let persistedData = try readAll(
            descriptor: descriptor,
            expectedSize: data.count,
            operation: "temporary file read-back"
        )
        guard persistedData == data else {
            throw DeviceIngressEvidenceFileError.contentChangedDuringAccess
        }
        let persistedMetadata = try metadataForDescriptor(
            descriptor,
            operation: "persisted temporary file stat"
        )
        try validateRegularFile(persistedMetadata)
        guard persistedMetadata.size == Int64(data.count) else {
            throw DeviceIngressEvidenceFileError.contentChangedDuringAccess
        }
        let temporaryPathMetadata = try requiredMetadataAt(
            directoryDescriptor,
            name: temporaryName
        )
        guard persistedMetadata == temporaryPathMetadata else {
            throw DeviceIngressEvidenceFileError.pathIdentityChanged
        }
        try validateActiveTransaction()

        if let existing = try metadataAt(directoryDescriptor, name: fileName) {
            guard replaceExisting else {
                throw DeviceIngressRegistrationClientError.pendingRegistrationExists
            }
            try validateRegularFile(existing)
        }
        let renameResult = temporaryName.withCString { source in
            fileName.withCString { destination in
                if replaceExisting {
                    Darwin.renameat(
                        directoryDescriptor,
                        source,
                        directoryDescriptor,
                        destination
                    )
                } else {
                    Darwin.renameatx_np(
                        directoryDescriptor,
                        source,
                        directoryDescriptor,
                        destination,
                        UInt32(RENAME_EXCL)
                    )
                }
            }
        }
        guard renameResult == 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: "atomic rename",
                code: errno
            )
        }
        renamed = true
        try validateActiveTransaction()
        let installedMetadata = try requiredMetadataAt(
            directoryDescriptor,
            name: fileName
        )
        guard installedMetadata == persistedMetadata else {
            throw DeviceIngressEvidenceFileError.pathIdentityChanged
        }
        try synchronizer.synchronizeDirectory(directoryDescriptor)
        let postSyncMetadata = try requiredMetadataAt(
            directoryDescriptor,
            name: fileName
        )
        guard postSyncMetadata == persistedMetadata else {
            throw DeviceIngressEvidenceFileError.contentChangedDuringAccess
        }
        try validateActiveTransaction()
        guard Darwin.close(descriptor) == 0 else {
            descriptor = -1
            throw DeviceIngressEvidenceFileError.posix(
                operation: "installed file close",
                code: errno
            )
        }
        descriptor = -1
    }

    private func readUnlocked<T: Decodable>(
        _ type: T.Type,
        from fileName: String,
        directoryDescriptor: Int32
    ) throws -> T? {
        try validateActiveTransaction()
        try validatePathComponent(fileName)
        guard let before = try metadataAt(directoryDescriptor, name: fileName) else {
            return nil
        }
        try validateRegularFile(before)
        let descriptor = try openFileAt(
            directoryDescriptor,
            name: fileName,
            flags: O_RDONLY | O_CLOEXEC | O_NOFOLLOW,
            mode: 0,
            operation: "evidence open"
        )
        defer { _ = Darwin.close(descriptor) }
        let opened = try metadataForDescriptor(descriptor, operation: "evidence stat")
        try validateRegularFile(opened)
        guard opened == before else {
            throw DeviceIngressEvidenceFileError.pathIdentityChanged
        }
        try validateActiveTransaction()
        try readObserver.didOpenForRead(fileName: fileName)
        let data = try readAll(
            descriptor: descriptor,
            expectedSize: Int(opened.size),
            operation: "evidence read"
        )
        let after = try metadataForDescriptor(descriptor, operation: "post-read stat")
        let pathAfter = try requiredMetadataAt(directoryDescriptor, name: fileName)
        try validateRegularFile(after)
        guard after == opened, pathAfter == opened else {
            throw DeviceIngressEvidenceFileError.contentChangedDuringAccess
        }
        try validateActiveTransaction()
        return try JSONDecoder().decode(type, from: data)
    }

    private func removeUnlocked(
        _ fileName: String,
        directoryDescriptor: Int32
    ) throws {
        try validateActiveTransaction()
        try validatePathComponent(fileName)
        guard let before = try metadataAt(directoryDescriptor, name: fileName) else {
            return
        }
        try validateRegularFile(before)
        let result = fileName.withCString {
            Darwin.unlinkat(directoryDescriptor, $0, 0)
        }
        guard result == 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: "evidence unlink",
                code: errno
            )
        }
        try validateActiveTransaction()
        guard try metadataAt(directoryDescriptor, name: fileName) == nil else {
            throw DeviceIngressEvidenceFileError.pathIdentityChanged
        }
        try synchronizer.synchronizeDirectory(directoryDescriptor)
        try validateActiveTransaction()
    }

    private func writeAll(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let count = Darwin.write(
                    descriptor,
                    buffer.baseAddress!.advanced(by: offset),
                    buffer.count - offset
                )
                if count < 0 {
                    if errno == EINTR { continue }
                    throw DeviceIngressEvidenceFileError.posix(
                        operation: "evidence write",
                        code: errno
                    )
                }
                guard count > 0 else {
                    throw DeviceIngressEvidenceFileError.posix(
                        operation: "evidence short write",
                        code: EIO
                    )
                }
                offset += count
            }
        }
    }

    private func readAll(
        descriptor: Int32,
        expectedSize: Int,
        operation: String
    ) throws -> Data {
        var data = Data(count: expectedSize)
        try data.withUnsafeMutableBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let count = Darwin.pread(
                    descriptor,
                    buffer.baseAddress!.advanced(by: offset),
                    buffer.count - offset,
                    off_t(offset)
                )
                if count < 0 {
                    if errno == EINTR { continue }
                    throw DeviceIngressEvidenceFileError.posix(
                        operation: operation,
                        code: errno
                    )
                }
                guard count > 0 else {
                    throw DeviceIngressEvidenceFileError.posix(
                        operation: "\(operation) short read",
                        code: EIO
                    )
                }
                offset += count
            }
        }
        return data
    }

    private func metadataAt(_ directoryDescriptor: Int32, name: String) throws
        -> DeviceIngressEvidenceMetadataSnapshot?
    {
        var value = stat()
        let result = name.withCString {
            Darwin.fstatat(directoryDescriptor, $0, &value, AT_SYMLINK_NOFOLLOW)
        }
        if result != 0 {
            if errno == ENOENT { return nil }
            throw DeviceIngressEvidenceFileError.posix(
                operation: "path stat",
                code: errno
            )
        }
        return DeviceIngressEvidenceMetadataSnapshot(value)
    }

    private func requiredMetadataAt(_ directoryDescriptor: Int32, name: String) throws
        -> DeviceIngressEvidenceMetadataSnapshot
    {
        guard let metadata = try metadataAt(directoryDescriptor, name: name) else {
            throw DeviceIngressEvidenceFileError.pathIdentityChanged
        }
        return metadata
    }

    private func metadataForDescriptor(_ descriptor: Int32, operation: String) throws
        -> DeviceIngressEvidenceMetadataSnapshot
    {
        var value = stat()
        guard Darwin.fstat(descriptor, &value) == 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: operation,
                code: errno
            )
        }
        return DeviceIngressEvidenceMetadataSnapshot(value)
    }

    private func validateRegularFile(
        _ metadata: DeviceIngressEvidenceMetadataSnapshot
    ) throws {
        try DeviceIngressEvidenceMetadataPolicy.validateRegularFile(
            metadata,
            expectedOwner: UInt32(geteuid()),
            maximumSize: Self.maximumEvidenceBytes
        )
    }

    private func validatePathComponent(_ value: String) throws {
        guard value.isEmpty == false,
              value != ".",
              value != "..",
              value.contains("/") == false,
              value.contains("\0") == false else {
            throw DeviceIngressEvidenceFileError.invalidPathComponent
        }
    }

    private func openFileAt(
        _ directoryDescriptor: Int32,
        name: String,
        flags: Int32,
        mode: mode_t,
        operation: String
    ) throws -> Int32 {
        try validatePathComponent(name)
        let descriptor = name.withCString {
            Darwin.openat(directoryDescriptor, $0, flags, mode)
        }
        guard descriptor >= 0 else {
            throw DeviceIngressEvidenceFileError.posix(
                operation: operation,
                code: errno
            )
        }
        return descriptor
    }
}

nonisolated struct DeviceIngressAuthenticatedVaultHandle: Sendable {
    fileprivate let identityVault: any IdentityVaultProtocol

    @MainActor
    static func current() throws -> Self {
        guard BindingRuntimeBootstrap.authenticatedRuntimeIsReady,
              let identityVault = CellBase.defaultIdentityVault,
              identityVault is IdentityVault else {
            throw DeviceIngressRegistrationClientError.authenticatedIdentityVaultUnavailable
        }
        return Self(identityVault: identityVault)
    }

    #if DEBUG
    static func testing(_ identityVault: any IdentityVaultProtocol) -> Self {
        Self(identityVault: identityVault)
    }
    #endif
}

nonisolated actor DeviceIngressRegistrationClient {
    private let identityVault: any IdentityVaultProtocol
    private let transport: any DeviceIngressRegistrationTransport
    private let evidenceStore: any DeviceIngressRegistrationEvidenceStoring
    private let trust: DeviceIngressRegistrationTrustConfiguration
    private let buildProvenance: BindingBuildProvenance

    init(
        authenticatedVault: DeviceIngressAuthenticatedVaultHandle,
        transport: any DeviceIngressRegistrationTransport,
        evidenceStore: any DeviceIngressRegistrationEvidenceStoring,
        trust: DeviceIngressRegistrationTrustConfiguration,
        buildProvenance: BindingBuildProvenance
    ) {
        identityVault = authenticatedVault.identityVault
        self.transport = transport
        self.evidenceStore = evidenceStore
        self.trust = trust
        self.buildProvenance = buildProvenance
    }

    func register(
        protectedBody: Data,
        now: Date = Date()
    ) async throws -> DeviceIngressRegistrationReceipt {
        guard protectedBody.isEmpty == false,
              protectedBody.count <= DeviceIngressEnvelope.maximumBodyBytes else {
            throw DeviceIngressRegistrationClientError.invalidProtectedBody
        }
        let requesterContext = try await currentRequesterContext()
        let requester = requesterContext.identity
        let binding = requesterContext.binding
        let subject = requesterContext.descriptor

        let challengeData = try await transport.fetchRegisterChallenge(subject: subject)
        let prepared = try await DeviceIngressRequestFactory.prepare(
            canonicalChallengeData: challengeData,
            protectedBody: protectedBody,
            requester: requester,
            domainBinding: binding,
            expectedAudience: trust.expectedAudience,
            expectedChallengeIssuer: trust.expectedChallengeIssuer,
            now: now
        )
        guard prepared.expectation.operation == .register else {
            throw DeviceIngressRegistrationClientError.responseWasNotRegistration
        }

        // This durable write intentionally precedes the first mutation-capable
        // transport call. An ambiguous send leaves evidence pending and blocks
        // silent retry.
        try await evidenceStore.persistPending(prepared.expectation)
        let responseData = try await transport.submitRegister(
            canonicalChallengeData: challengeData,
            canonicalRequestData: prepared.canonicalRequestData,
            protectedBody: protectedBody
        )
        let response = try DeviceIngressOperationResponseVerifier.verify(
            canonicalData: responseData,
            expectation: prepared.expectation
        )
        guard response.operation == .register,
              response.result.kind == .registrationReceipt,
              let receipt = response.result.registrationReceipt else {
            throw DeviceIngressRegistrationClientError.responseWasNotRegistration
        }
        guard receipt.state == .activeConsented else {
            throw DeviceIngressRegistrationClientError.registrationWasNotActiveAndConsented
        }

        // Marking succeeds only after cryptographic verification and durable
        // local evidence replacement. No HTTP status can reach this branch.
        try await evidenceStore.commitVerified(
            expectation: prepared.expectation,
            canonicalResponseData: responseData,
            buildProvenance: buildProvenance
        )
        return receipt
    }

    func restoreHistoricalRegistrationEvidence() async throws
        -> DeviceIngressHistoricalRegistrationEvidence?
    {
        guard let evidence = try await evidenceStore.verifiedEvidence() else {
            return nil
        }
        guard evidence.schema == DeviceIngressVerifiedRegistrationEvidence.currentSchema else {
            throw DeviceIngressRegistrationClientError.pendingExpectationMismatch
        }
        guard evidence.buildProvenance == buildProvenance else {
            throw DeviceIngressRegistrationClientError.buildProvenanceMismatch
        }

        // A valid owner signature is portable evidence, not proof that this
        // installation controls the registered device identity. Rebind it to
        // the currently authenticated persistent vault before accepting it.
        let requesterContext = try await currentRequesterContext()
        guard evidence.expectation.subjectIdentityUUID
                == requesterContext.descriptor.uuid,
              evidence.expectation.subjectSigningKeyFingerprint
                == requesterContext.binding.signingKeyFingerprint else {
            throw DeviceIngressRegistrationClientError
                .verifiedEvidenceDeviceIdentityMismatch
        }
        let response = try DeviceIngressOperationResponseVerifier.verify(
            canonicalData: evidence.canonicalResponseData,
            expectation: evidence.expectation
        )
        guard response.operation == .register,
              response.result.kind == .registrationReceipt,
              let receipt = response.result.registrationReceipt else {
            throw DeviceIngressRegistrationClientError.responseWasNotRegistration
        }
        guard receipt.state == .activeConsented,
              receipt.deviceIdentityUUID == requesterContext.descriptor.uuid else {
            throw DeviceIngressRegistrationClientError.registrationWasNotActiveAndConsented
        }
        return DeviceIngressHistoricalRegistrationEvidence(
            receiptAtMutation: receipt,
            admissionID: response.admissionID,
            authorityGeneration: response.authorityGeneration,
            revocationLedgerID: response.revocationLedgerID,
            revocationGeneration: response.revocationGeneration,
            signedResponseIssuedAtMilliseconds: response.issuedAtMilliseconds,
            buildProvenance: evidence.buildProvenance
        )
    }

    private func currentRequesterContext() async throws -> (
        identity: Identity,
        binding: IdentityDomainBinding,
        descriptor: IdentityPublicKeyDescriptor
    ) {
        guard let requester = await identityVault.identity(
            for: DeviceIngressEnvelope.identityDomain,
            makeNewIfNotFound: false
        ) else {
            throw DeviceIngressRegistrationClientError.notificationIdentityUnavailable
        }
        guard let binding = await identityVault.identityDomainBinding(for: requester),
              binding.domain == DeviceIngressEnvelope.identityDomain,
              binding.matches(identity: requester),
              binding.grantsAuthority == false else {
            throw DeviceIngressRegistrationClientError.notificationDomainBindingUnavailable
        }
        guard let descriptor = DeviceIngressIdentityDescriptor.publicDescriptor(
            for: requester
        ) else {
            throw DeviceIngressRegistrationClientError.notificationIdentityDescriptorUnavailable
        }
        return (requester, binding, descriptor)
    }
}

/// Runtime integration is deliberately inert. PR #33 does not provide an
/// operational challenge issuer, durable authority composition or a shared
/// client transport package, so Binding must not infer those details.
@MainActor
enum BindingDeviceIngressRegistrationComposition {
    static func register(
        protectedBody: Data,
        buildProvenance: BindingBuildProvenance
    ) async throws -> DeviceIngressRegistrationReceipt {
        _ = (protectedBody, buildProvenance)
        throw DeviceIngressRegistrationClientError.operationalCompositionUnavailable
    }
}
