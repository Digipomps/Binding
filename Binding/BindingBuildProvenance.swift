import Foundation
import CryptoKit
#if os(macOS)
import Security
#endif

nonisolated enum BindingBuildProvenanceError: LocalizedError, Equatable {
    case missingBuildResource
    case missingCompilerInputManifest
    case invalidBuildResource
    case compilerInputManifestMismatch
    case dirtySourceTree
    case unsignedBuild
    case codeSigningAuthorityUnavailable
    case codeSigningAuthorityMismatch

    var errorDescription: String? {
        switch self {
        case .missingBuildResource:
            return "The build-generated Binding provenance resource is missing."
        case .missingCompilerInputManifest:
            return "The build-generated compiler-input manifest is missing."
        case .invalidBuildResource:
            return "The build-generated Binding provenance resource is invalid."
        case .compilerInputManifestMismatch:
            return "The compiler-input manifest does not match its signed provenance digest."
        case .dirtySourceTree:
            return "The Binding candidate was built from a dirty Binding or CellProtocol source tree."
        case .unsignedBuild:
            return "This Binding build has no attested certificate signing authority."
        case .codeSigningAuthorityUnavailable:
            return "The running Binding code-signing authority is unavailable."
        case .codeSigningAuthorityMismatch:
            return "The running Binding code-signing authority does not match the build attestation."
        }
    }
}

/// Build attestation generated after compilation from Xcode's actual Swift
/// file list, generated Swift inputs, synchronized-root inventory, selected
/// build settings, toolchain/SDK fingerprints and linked CellProtocol objects.
///
/// This is intentionally not described as a complete-source claim. The exact
/// coverage declaration is part of the signed resource and registration body.
nonisolated struct BindingBuildProvenance: Codable, Equatable, Sendable {
    static let currentSchema = "binding.build-provenance.v4"
    static let resourceName = "BindingBuildProvenance"
    static let compilerInputManifestResourceName = "BindingCompilerInputManifest"
    static let canonicalIOSBundleIdentifier = "org.digipomps.haven"
    static let canonicalIOSTeamIdentifier = "5UT5HQTCV9"
    static let coverage =
        "exact-head+dirty-state+xcode-swift-file-list+fs-synchronized-root-inventory+generated-swift+linked-cellprotocol-artifacts+declared-build-settings"

    enum CodeSigningMode: String, Codable, Sendable {
        case certificate
        case unsigned
    }

    let schema: String
    let coverageDeclaration: String
    let bindingGitRevision: String
    let cellProtocolGitRevision: String
    let bindingSourceTreeDirty: Bool
    let cellProtocolSourceTreeDirty: Bool
    let compilerInputManifestSHA256: String
    let compilerInputCount: Int
    let generatedCompilerInputCount: Int
    let filesystemSynchronizedSourceCount: Int
    let ignoredSourceLikeInputCount: Int
    let bindingCompilerArtifactSHA256: String
    let cellProtocolArtifactSHA256: String
    let linkInputManifestSHA256: String
    let compilerFlagsSHA256: String
    let toolchainSHA256: String
    let codeSigningMode: CodeSigningMode
    let codeSigningIdentityFingerprint: String
    let codeSigningTeamIdentifier: String
    let codeSigningEntitlementsSHA256: String
    let buildConfiguration: String
    let sdkName: String
    let generatedAtUTC: String

    init(
        schema: String = Self.currentSchema,
        coverageDeclaration: String = Self.coverage,
        bindingGitRevision: String,
        cellProtocolGitRevision: String,
        bindingSourceTreeDirty: Bool,
        cellProtocolSourceTreeDirty: Bool,
        compilerInputManifestSHA256: String,
        compilerInputCount: Int,
        generatedCompilerInputCount: Int,
        filesystemSynchronizedSourceCount: Int,
        ignoredSourceLikeInputCount: Int,
        bindingCompilerArtifactSHA256: String,
        cellProtocolArtifactSHA256: String,
        linkInputManifestSHA256: String,
        compilerFlagsSHA256: String,
        toolchainSHA256: String,
        codeSigningMode: CodeSigningMode,
        codeSigningIdentityFingerprint: String,
        codeSigningTeamIdentifier: String,
        codeSigningEntitlementsSHA256: String,
        buildConfiguration: String,
        sdkName: String,
        generatedAtUTC: String
    ) throws {
        guard schema == Self.currentSchema,
              coverageDeclaration == Self.coverage,
              Self.isGitRevision(bindingGitRevision),
              Self.isGitRevision(cellProtocolGitRevision),
              Self.isSHA256(compilerInputManifestSHA256),
              compilerInputCount > 0,
              generatedCompilerInputCount >= 0,
              generatedCompilerInputCount <= compilerInputCount,
              filesystemSynchronizedSourceCount > 0,
              ignoredSourceLikeInputCount >= 0,
              ignoredSourceLikeInputCount <= filesystemSynchronizedSourceCount,
              Self.isSHA256(bindingCompilerArtifactSHA256),
              Self.isSHA256(cellProtocolArtifactSHA256),
              Self.isSHA256(linkInputManifestSHA256),
              Self.isSHA256(compilerFlagsSHA256),
              Self.isSHA256(toolchainSHA256),
              Self.isSHA256(codeSigningEntitlementsSHA256),
              Self.isNonempty(buildConfiguration),
              Self.isNonempty(sdkName),
              Self.isNonempty(generatedAtUTC) else {
            throw BindingBuildProvenanceError.invalidBuildResource
        }
        switch codeSigningMode {
        case .certificate:
            guard codeSigningIdentityFingerprint.count == 40,
                  Self.isLowercaseHex(codeSigningIdentityFingerprint),
                  Self.isNonempty(codeSigningTeamIdentifier),
                  codeSigningTeamIdentifier != "unsigned" else {
                throw BindingBuildProvenanceError.invalidBuildResource
            }
        case .unsigned:
            guard codeSigningIdentityFingerprint == "unsigned",
                  codeSigningTeamIdentifier == "unsigned" else {
                throw BindingBuildProvenanceError.invalidBuildResource
            }
        }

        self.schema = schema
        self.coverageDeclaration = coverageDeclaration
        self.bindingGitRevision = bindingGitRevision
        self.cellProtocolGitRevision = cellProtocolGitRevision
        self.bindingSourceTreeDirty = bindingSourceTreeDirty
        self.cellProtocolSourceTreeDirty = cellProtocolSourceTreeDirty
        self.compilerInputManifestSHA256 = compilerInputManifestSHA256
        self.compilerInputCount = compilerInputCount
        self.generatedCompilerInputCount = generatedCompilerInputCount
        self.filesystemSynchronizedSourceCount = filesystemSynchronizedSourceCount
        self.ignoredSourceLikeInputCount = ignoredSourceLikeInputCount
        self.bindingCompilerArtifactSHA256 = bindingCompilerArtifactSHA256
        self.cellProtocolArtifactSHA256 = cellProtocolArtifactSHA256
        self.linkInputManifestSHA256 = linkInputManifestSHA256
        self.compilerFlagsSHA256 = compilerFlagsSHA256
        self.toolchainSHA256 = toolchainSHA256
        self.codeSigningMode = codeSigningMode
        self.codeSigningIdentityFingerprint = codeSigningIdentityFingerprint
        self.codeSigningTeamIdentifier = codeSigningTeamIdentifier
        self.codeSigningEntitlementsSHA256 = codeSigningEntitlementsSHA256
        self.buildConfiguration = buildConfiguration
        self.sdkName = sdkName
        self.generatedAtUTC = generatedAtUTC
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            schema: values.decode(String.self, forKey: .schema),
            coverageDeclaration: values.decode(String.self, forKey: .coverageDeclaration),
            bindingGitRevision: values.decode(String.self, forKey: .bindingGitRevision),
            cellProtocolGitRevision: values.decode(String.self, forKey: .cellProtocolGitRevision),
            bindingSourceTreeDirty: values.decode(
                Bool.self,
                forKey: .bindingSourceTreeDirty
            ),
            cellProtocolSourceTreeDirty: values.decode(
                Bool.self,
                forKey: .cellProtocolSourceTreeDirty
            ),
            compilerInputManifestSHA256: values.decode(
                String.self,
                forKey: .compilerInputManifestSHA256
            ),
            compilerInputCount: values.decode(Int.self, forKey: .compilerInputCount),
            generatedCompilerInputCount: values.decode(
                Int.self,
                forKey: .generatedCompilerInputCount
            ),
            filesystemSynchronizedSourceCount: values.decode(
                Int.self,
                forKey: .filesystemSynchronizedSourceCount
            ),
            ignoredSourceLikeInputCount: values.decode(
                Int.self,
                forKey: .ignoredSourceLikeInputCount
            ),
            bindingCompilerArtifactSHA256: values.decode(
                String.self,
                forKey: .bindingCompilerArtifactSHA256
            ),
            cellProtocolArtifactSHA256: values.decode(
                String.self,
                forKey: .cellProtocolArtifactSHA256
            ),
            linkInputManifestSHA256: values.decode(
                String.self,
                forKey: .linkInputManifestSHA256
            ),
            compilerFlagsSHA256: values.decode(String.self, forKey: .compilerFlagsSHA256),
            toolchainSHA256: values.decode(String.self, forKey: .toolchainSHA256),
            codeSigningMode: values.decode(CodeSigningMode.self, forKey: .codeSigningMode),
            codeSigningIdentityFingerprint: values.decode(
                String.self,
                forKey: .codeSigningIdentityFingerprint
            ),
            codeSigningTeamIdentifier: values.decode(
                String.self,
                forKey: .codeSigningTeamIdentifier
            ),
            codeSigningEntitlementsSHA256: values.decode(
                String.self,
                forKey: .codeSigningEntitlementsSHA256
            ),
            buildConfiguration: values.decode(String.self, forKey: .buildConfiguration),
            sdkName: values.decode(String.self, forKey: .sdkName),
            generatedAtUTC: values.decode(String.self, forKey: .generatedAtUTC)
        )
    }

    static func current(
        bundle: Bundle = .main,
        requireCertificateSignature: Bool = true
    ) throws -> Self {
        guard let provenanceURL = bundle.url(
            forResource: resourceName,
            withExtension: "plist"
        ) else {
            throw BindingBuildProvenanceError.missingBuildResource
        }
        guard let manifestURL = bundle.url(
            forResource: compilerInputManifestResourceName,
            withExtension: "txt"
        ) else {
            throw BindingBuildProvenanceError.missingCompilerInputManifest
        }
        let provenance: Self
        do {
            provenance = try PropertyListDecoder().decode(
                Self.self,
                from: Data(contentsOf: provenanceURL)
            )
        } catch let error as BindingBuildProvenanceError {
            throw error
        } catch {
            throw BindingBuildProvenanceError.invalidBuildResource
        }
        let manifestData = try Data(contentsOf: manifestURL)
        guard sha256Hex(manifestData) == provenance.compilerInputManifestSHA256 else {
            throw BindingBuildProvenanceError.compilerInputManifestMismatch
        }
        if requireCertificateSignature {
            guard provenance.bindingSourceTreeDirty == false,
                  provenance.cellProtocolSourceTreeDirty == false else {
                throw BindingBuildProvenanceError.dirtySourceTree
            }
            guard provenance.codeSigningMode == .certificate else {
                throw BindingBuildProvenanceError.unsignedBuild
            }
            #if os(macOS)
            let runningFingerprint = try currentSigningCertificateSHA1()
            guard runningFingerprint == provenance.codeSigningIdentityFingerprint else {
                throw BindingBuildProvenanceError.codeSigningAuthorityMismatch
            }
            #elseif os(iOS)
            #if targetEnvironment(simulator)
            // APNS DeviceIngress is a physical-device contract. A simulator
            // build cannot provide that platform execution prerequisite.
            throw BindingBuildProvenanceError.codeSigningAuthorityUnavailable
            #else
            // iOS verifies the application code signature before launch, but
            // does not expose the running leaf signing certificate through a
            // public API. Validate the signed, build-generated provenance
            // against the canonical App ID and team instead. This is a local
            // platform execution prerequisite; it is not remote app-integrity
            // attestation and must not be represented as App Attest.
            try validateIOSPlatformSigning(
                provenance,
                bundleIdentifier: bundle.bundleIdentifier
            )
            #endif
            #else
            throw BindingBuildProvenanceError.codeSigningAuthorityUnavailable
            #endif
        }
        return provenance
    }

    static func validateIOSPlatformSigning(
        _ provenance: Self,
        bundleIdentifier: String?,
        expectedBundleIdentifier: String = canonicalIOSBundleIdentifier,
        expectedTeamIdentifier: String = canonicalIOSTeamIdentifier
    ) throws {
        guard let bundleIdentifier,
              isNonempty(bundleIdentifier),
              isNonempty(expectedBundleIdentifier),
              isNonempty(expectedTeamIdentifier) else {
            throw BindingBuildProvenanceError.codeSigningAuthorityUnavailable
        }
        guard provenance.codeSigningMode == .certificate,
              provenance.sdkName.lowercased().hasPrefix("iphoneos"),
              bundleIdentifier == expectedBundleIdentifier,
              provenance.codeSigningTeamIdentifier == expectedTeamIdentifier else {
            throw BindingBuildProvenanceError.codeSigningAuthorityMismatch
        }
    }

    var registrationObject: [String: JSONValue] {
        [
            "schema": .string(schema),
            "coverageDeclaration": .string(coverageDeclaration),
            "bindingGitRevision": .string(bindingGitRevision),
            "cellProtocolGitRevision": .string(cellProtocolGitRevision),
            "bindingSourceTreeDirty": .bool(bindingSourceTreeDirty),
            "cellProtocolSourceTreeDirty": .bool(cellProtocolSourceTreeDirty),
            "compilerInputManifestSHA256": .string(compilerInputManifestSHA256),
            "compilerInputCount": .number(Double(compilerInputCount)),
            "generatedCompilerInputCount": .number(Double(generatedCompilerInputCount)),
            "filesystemSynchronizedSourceCount": .number(
                Double(filesystemSynchronizedSourceCount)
            ),
            "ignoredSourceLikeInputCount": .number(Double(ignoredSourceLikeInputCount)),
            "bindingCompilerArtifactSHA256": .string(bindingCompilerArtifactSHA256),
            "cellProtocolArtifactSHA256": .string(cellProtocolArtifactSHA256),
            "linkInputManifestSHA256": .string(linkInputManifestSHA256),
            "compilerFlagsSHA256": .string(compilerFlagsSHA256),
            "toolchainSHA256": .string(toolchainSHA256),
            "codeSigningMode": .string(codeSigningMode.rawValue),
            "codeSigningIdentityFingerprint": .string(codeSigningIdentityFingerprint),
            "codeSigningTeamIdentifier": .string(codeSigningTeamIdentifier),
            "codeSigningEntitlementsSHA256": .string(codeSigningEntitlementsSHA256),
            "buildConfiguration": .string(buildConfiguration),
            "sdkName": .string(sdkName),
            "generatedAtUTC": .string(generatedAtUTC)
        ]
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    #if os(macOS)
    private static func currentSigningCertificateSHA1() throws -> String {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else {
            throw BindingBuildProvenanceError.codeSigningAuthorityUnavailable
        }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
              let staticCode else {
            throw BindingBuildProvenanceError.codeSigningAuthorityUnavailable
        }
        guard SecStaticCodeCheckValidity(staticCode, [], nil) == errSecSuccess else {
            throw BindingBuildProvenanceError.codeSigningAuthorityUnavailable
        }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &information
        ) == errSecSuccess,
        let dictionary = information as? [CFString: Any],
        let certificates = dictionary[kSecCodeInfoCertificates] as? [SecCertificate],
        let leaf = certificates.first else {
            throw BindingBuildProvenanceError.codeSigningAuthorityUnavailable
        }
        let certificateData = SecCertificateCopyData(leaf) as Data
        return Insecure.SHA1.hash(data: certificateData)
            .map { String(format: "%02x", $0) }.joined()
    }
    #endif

    private static func isGitRevision(_ value: String) -> Bool {
        (value.count == 40 || value.count == 64) && isLowercaseHex(value)
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && isLowercaseHex(value)
    }

    private static func isLowercaseHex(_ value: String) -> Bool {
        value.allSatisfy { ("0"..."9").contains($0) || ("a"..."f").contains($0) }
    }

    private static func isNonempty(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}
