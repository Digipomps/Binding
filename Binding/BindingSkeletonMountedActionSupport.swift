// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import CellBase
import CellApple

enum BindingSkeletonMountedActionError: LocalizedError, Equatable {
    case missingMount
    case invalidLocalSource
    case invalidKeypath
    case missingRequester
    case missingResolver
    case sourceNotMeddle
    case unresolvedRead
    case unresolvedWrite

    var errorDescription: String? {
        switch self {
        case .missingMount: return "ComponentSurface action requires mount metadata."
        case .invalidLocalSource: return "ComponentSurface actions currently support local cell:/// sources only."
        case .invalidKeypath: return "ComponentSurface action has an invalid source-relative keypath."
        case .missingRequester: return "ComponentSurface action requires the active requester."
        case .missingResolver: return "ComponentSurface action requires the CellResolver."
        case .sourceNotMeddle: return "ComponentSurface source does not support this operation."
        case .unresolvedRead: return "ComponentSurface source read could not be resolved."
        case .unresolvedWrite: return "ComponentSurface source did not confirm the write; its outcome is unknown."
        }
    }
}

/// Host context, kept beside the payload. It is neither a grant nor a new
/// Meddle parameter, and is never inserted into the source Cell's value.
struct BindingSkeletonMountContext: Equatable {
    let instanceID: String
    let componentID: String
    let revision: String
}

struct BindingSkeletonMountedActionAttempt: Equatable {
    enum Operation: Equatable { case get, set }
    let sourceCellEndpoint: String
    let keypath: String
    let mount: BindingSkeletonMountContext
    let operation: Operation
}

@MainActor
enum BindingSkeletonMountedActionSupport {
    static func handler(
        viewModel: PortholeViewModel,
        onDispatchAttempt: ((BindingSkeletonMountedActionAttempt) -> Void)? = nil
    ) -> SkeletonNativeActionHandler {
        SkeletonNativeActionHandler { request in
            let mount = request.mount.map {
                BindingSkeletonMountContext(instanceID: $0.instanceID, componentID: $0.componentID, revision: $0.revision)
            }
            return try await dispatch(
                sourceCellEndpoint: request.sourceCellEndpoint,
                keypath: request.keypath,
                payload: request.payload,
                mount: mount,
                requester: await viewModel.executionRequesterIdentity(),
                resolver: CellBase.defaultCellResolver,
                onDispatchAttempt: onDispatchAttempt
            )
        }
    }

    static func dispatch(
        sourceCellEndpoint: String?, keypath: String, payload: ValueType?,
        mount: BindingSkeletonMountContext?, requester: Identity?, resolver: CellResolverProtocol?,
        onDispatchAttempt: ((BindingSkeletonMountedActionAttempt) -> Void)? = nil
    ) async throws -> ValueType {
        guard let mount, [mount.instanceID, mount.componentID, mount.revision].allSatisfy({ !$0.isEmpty }) else {
            throw BindingSkeletonMountedActionError.missingMount
        }
        let target = try localActionURL(sourceCellEndpoint: sourceCellEndpoint, keypath: keypath)
        guard let requester else { throw BindingSkeletonMountedActionError.missingRequester }
        guard let resolver else { throw BindingSkeletonMountedActionError.missingResolver }
        // Both resolution and the operation use the active requester. Metadata
        // does not select an owner, obtain a grant, or create a vault identity.
        guard let sourceCellEndpoint,
              try await resolver.cellAtEndpoint(endpoint: sourceCellEndpoint, requester: requester) is Meddle else {
            throw BindingSkeletonMountedActionError.sourceNotMeddle
        }
        onDispatchAttempt?(.init(sourceCellEndpoint: sourceCellEndpoint, keypath: keypath,
            mount: mount, operation: payload == nil ? .get : .set))
        if let payload {
            guard let value = try await resolver.set(value: payload, into: target, requester: requester) else {
                // A missing reply is not a successful null result. Do not retry:
                // the source may already have applied its operation.
                throw BindingSkeletonMountedActionError.unresolvedWrite
            }
            return value
        }
        // A nil button payload means GET. An explicit ValueType.null is SET.
        guard let value = try await resolver.get(from: target, requester: requester) else {
            throw BindingSkeletonMountedActionError.unresolvedRead
        }
        return value
    }

    private static func localActionURL(sourceCellEndpoint: String?, keypath: String) throws -> URL {
        guard let sourceCellEndpoint, sourceCellEndpoint.hasPrefix("cell:///"),
              var components = URLComponents(string: sourceCellEndpoint),
              components.scheme == "cell", (components.host ?? "").isEmpty,
              components.user == nil, components.password == nil, components.port == nil,
              components.query == nil, components.fragment == nil else {
            throw BindingSkeletonMountedActionError.invalidLocalSource
        }
        let name = String(components.path.dropFirst())
        guard components.path.hasPrefix("/"), !name.isEmpty, name != ".", name != "..",
              !name.contains("/"), !name.contains("\\"),
              name.rangeOfCharacter(from: .controlCharacters) == nil else {
            throw BindingSkeletonMountedActionError.invalidLocalSource
        }
        guard !keypath.isEmpty,
              keypath.rangeOfCharacter(from: .whitespacesAndNewlines.union(.controlCharacters)) == nil,
              !keypath.contains(where: { "/\\?#:%".contains($0) }),
              keypath.split(separator: ".", omittingEmptySubsequences: false).allSatisfy({ !$0.isEmpty }) else {
            throw BindingSkeletonMountedActionError.invalidKeypath
        }
        components.path += "/" + keypath
        guard let target = components.url else { throw BindingSkeletonMountedActionError.invalidLocalSource }
        return target
    }
}
