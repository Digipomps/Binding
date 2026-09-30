// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import XCTest
import SwiftUI
import CellBase
import CellApple
@testable import Binding
#if os(macOS)
import AppKit
#endif

@MainActor
final class BindingSkeletonMountedActionSupportTests: XCTestCase {
    private let actionKeypath = "actions.refresh"
    private let mount = BindingSkeletonMountContext(instanceID: "A", componentID: "card", revision: "r1")

    func testLocalAgreementAllowsPayloadUnchangedWithSeparateMountContexts() async throws {
        try await withFixture { fixture in
            let payload: ValueType = .object([
                "instanceID": .string("user-payload"),
                "mount": .object(["revision": .string("payload-revision")]),
                "reason": .string("manual")
            ])
            var attempts: [BindingSkeletonMountedActionAttempt] = []
            for instanceID in ["A", "B"] {
                let context = BindingSkeletonMountContext(instanceID: instanceID, componentID: "card", revision: "r1")
                let response = try await BindingSkeletonMountedActionSupport.dispatch(
                    sourceCellEndpoint: fixture.endpoint, keypath: self.actionKeypath, payload: payload,
                    mount: context, requester: fixture.member, resolver: fixture.resolver,
                    onDispatchAttempt: { attempts.append($0) })
                XCTAssertEqual(response, .string("source-write"))
            }
            let calls = await fixture.calls.snapshot()
            XCTAssertEqual(calls.count, 2)
            for call in calls {
                XCTAssertEqual(call.requesterUUID, fixture.member.uuid)
                XCTAssertEqual(call.keypath, self.actionKeypath)
                XCTAssertEqual(try self.bytes(call.payload), try self.bytes(payload))
            }
            XCTAssertEqual(attempts.map(\.mount.instanceID), ["A", "B"])
            XCTAssertEqual(attempts.map(\.mount.revision), ["r1", "r1"])
            XCTAssertTrue(attempts.allSatisfy { $0.sourceCellEndpoint == fixture.endpoint && $0.operation == .set })
        }
    }

    func testDeniedAndMissingRequesterCannotBorrowMountOrDefaultVaultAuthority() async throws {
        try await withFixture { fixture in
            let copiedOwnerMetadata = BindingSkeletonMountContext(instanceID: fixture.owner.uuid,
                componentID: "owner", revision: "authorized")
            do {
                _ = try await BindingSkeletonMountedActionSupport.dispatch(
                    sourceCellEndpoint: fixture.endpoint, keypath: self.actionKeypath, payload: .bool(true),
                    mount: copiedOwnerMetadata, requester: fixture.outsider, resolver: fixture.resolver)
                XCTFail("Mount metadata must not grant access to a requester without an Agreement")
            } catch CellAuthorizationError.denied(_) { }
            do {
                _ = try await BindingSkeletonMountedActionSupport.dispatch(
                    sourceCellEndpoint: fixture.endpoint, keypath: self.actionKeypath, payload: .bool(true),
                    mount: self.mount, requester: nil, resolver: fixture.resolver)
                XCTFail("A default private identity must not replace the missing active requester")
            } catch BindingSkeletonMountedActionError.missingRequester { }
            let calls = await fixture.calls.snapshot()
            XCTAssertTrue(calls.isEmpty)
        }
    }

    func testNilPayloadReadsButExplicitNullWrites() async throws {
        try await withFixture { fixture in
            let read = try await BindingSkeletonMountedActionSupport.dispatch(
                sourceCellEndpoint: fixture.endpoint, keypath: self.actionKeypath, payload: nil,
                mount: self.mount, requester: fixture.member, resolver: fixture.resolver)
            let write = try await BindingSkeletonMountedActionSupport.dispatch(
                sourceCellEndpoint: fixture.endpoint, keypath: self.actionKeypath, payload: .null,
                mount: self.mount, requester: fixture.member, resolver: fixture.resolver)
            XCTAssertEqual(read, .string("source-read"))
            XCTAssertEqual(write, .string("source-write"))
            let calls = await fixture.calls.snapshot()
            XCTAssertEqual(calls.map(\.operation), ["get", "set"])
            XCTAssertNil(calls[0].payload)
            XCTAssertEqual(calls[1].payload, .null)
        }
    }

    func testRemoteAndMalformedTargetsFailBeforeResolverDispatch() async throws {
        try await withFixture { fixture in
            for endpoint in ["cell://remote.example/Source", "cell://localhost/Source", "wss://remote.example/Source",
                             "cell:///Source?owner=other", "cell:///Source#action", "cell:///../Source",
                             "cell:///Source%2FChild", "cell:///%2E%2E", "cell:///Source/"] {
                do {
                    _ = try await BindingSkeletonMountedActionSupport.dispatch(
                        sourceCellEndpoint: endpoint, keypath: self.actionKeypath, payload: .bool(true),
                        mount: self.mount, requester: fixture.member, resolver: nil)
                    XCTFail("Invalid local source accepted: \(endpoint)")
                } catch BindingSkeletonMountedActionError.invalidLocalSource { }
            }
            for keypath in ["", "cell:///Other/action", "../action", "actions..refresh", "actions/refresh", "actions?owner", " actions"] {
                do {
                    _ = try await BindingSkeletonMountedActionSupport.dispatch(
                        sourceCellEndpoint: fixture.endpoint, keypath: keypath, payload: .bool(true),
                        mount: self.mount, requester: fixture.member, resolver: nil)
                    XCTFail("Invalid source-relative keypath accepted: \(keypath)")
                } catch BindingSkeletonMountedActionError.invalidKeypath { }
            }
            do {
                _ = try await BindingSkeletonMountedActionSupport.dispatch(
                    sourceCellEndpoint: fixture.endpoint, keypath: self.actionKeypath, payload: .bool(true),
                    mount: nil, requester: fixture.member, resolver: fixture.resolver)
                XCTFail("Unmounted request accepted")
            } catch BindingSkeletonMountedActionError.missingMount { }
            let calls = await fixture.calls.snapshot()
            XCTAssertTrue(calls.isEmpty)
        }
    }

    func testMissingWriteResultIsAnExplicitFailureWithoutRetry() async throws {
        try await withFixture { fixture in
            do {
                _ = try await BindingSkeletonMountedActionSupport.dispatch(
                    sourceCellEndpoint: fixture.endpoint, keypath: "actions.noReply", payload: .null,
                    mount: self.mount, requester: fixture.member, resolver: fixture.resolver)
                XCTFail("No response must not be turned into a successful null value")
            } catch BindingSkeletonMountedActionError.unresolvedWrite { }
            let calls = await fixture.calls.snapshot()
            XCTAssertEqual(calls.count, 1, "An ambiguous source response must never be retried automatically")
            XCTAssertEqual(calls.first?.keypath, "actions.noReply")
            XCTAssertEqual(calls.first?.payload, .null)
        }
    }

#if os(macOS)
    func testMountedButtonsReachSourceWhileSiblingURLNavigationStaysOutsideAdapter() async throws {
        try await withFixture { fixture in
            // Keep this rendering test's view model bootstrap out of the app's
            // Porthole registry; the actual requester is supplied explicitly.
            CellBase.defaultIdentityVault = nil
            let model = PortholeViewModel()
            try await Task.sleep(nanoseconds: 50_000_000)
            CellBase.defaultIdentityVault = fixture.vault
            model.rememberRequesterIdentity(fixture.member)
            let payload: ValueType = .object(["instanceID": .string("user-payload")])
            var attempts: [BindingSkeletonMountedActionAttempt] = []
            var openedURLs: [URL] = []
            var actionFailures: [Error] = []
            var buttonModifiers = SkeletonModifiers()
            buttonModifiers.width = 160; buttonModifiers.height = 40
            var sourceButton = SkeletonButton(keypath: self.actionKeypath, label: "Refresh source", payload: payload)
            sourceButton.modifiers = buttonModifiers
            let definition = SkeletonComponentMount(componentID: "card", revision: "r1",
                sourceCellEndpoint: fixture.endpoint, skeleton: .Button(sourceButton))
            let value = try JSONDecoder().decode(ValueType.self, from: JSONEncoder().encode(definition))
            let data: ValueType = .object(["mounts": .object(["A": value, "B": value])])
            var navigation = SkeletonButton(keypath: "", label: "Open site", url: "https://haven.example/help")
            navigation.modifiers = buttonModifiers
            let skeleton = SkeletonElement.VStack(.init(elements: [
                .ComponentSurface(.init(sourceKeypath: "mounts.A", instanceID: "A", variant: .inline)),
                .ComponentSurface(.init(sourceKeypath: "mounts.B", instanceID: "B", variant: .inline)),
                .Button(navigation)
            ], spacing: 0))
            let sourceHandler = BindingSkeletonMountedActionSupport.handler(viewModel: model,
                onDispatchAttempt: { attempts.append($0) })
            let handler = SkeletonNativeActionHandler { request in
                do { return try await sourceHandler.send(request) }
                catch { actionFailures.append(error); throw error }
            }
            let host = NSHostingView(rootView: SkeletonView(element: skeleton, renderData: .init(root: data))
                .environmentObject(model)
                .environment(\.skeletonMountedActionHandler, handler)
                .environment(\.openURL, OpenURLAction { url in openedURLs.append(url); return .handled })
                .skeletonHostTheme(.portholeLight)
                .frame(width: 240, height: 180, alignment: .topLeading))
            let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 240, height: 180),
                styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.animationBehavior = .none
            window.contentView = host; window.orderFront(nil)
            defer { window.close() }
            host.frame = NSRect(x: 0, y: 0, width: 240, height: 180)
            try await Task.sleep(nanoseconds: 200_000_000)
            host.layoutSubtreeIfNeeded()
            try self.click(host, topY: 20)
            try await self.waitUntil { attempts.count == 1 }
            try self.click(host, topY: 60)
            try await self.waitUntil { attempts.count == 2 }
            try self.click(host, topY: 100)
            try await self.waitUntil { openedURLs.count == 1 }
            XCTAssertEqual(openedURLs.map(\.absoluteString), ["https://haven.example/help"])
            XCTAssertEqual(attempts.map(\.mount.instanceID), ["A", "B"])
            try await self.waitUntil { await fixture.calls.snapshot().count == 2 }
            let calls = await fixture.calls.snapshot()
            XCTAssertTrue(calls.allSatisfy { $0.requesterUUID == fixture.member.uuid })
            for call in calls { XCTAssertEqual(try self.bytes(call.payload), try self.bytes(payload)) }
            // The factory reads the currently active requester on each action.
            model.rememberRequesterIdentity(fixture.outsider)
            try self.click(host, topY: 20)
            try await self.waitUntil { actionFailures.count == 1 }
            if case CellAuthorizationError.denied(_) = try XCTUnwrap(actionFailures.first) { }
            else { XCTFail("The active requester's authorization denial must propagate") }
            let callsAfterDenial = await fixture.calls.snapshot()
            XCTAssertEqual(callsAfterDenial.count, 2)
        }
    }

    private func click(_ host: NSView, topY: CGFloat) throws {
        let window = try XCTUnwrap(host.window)
        let point = host.convert(NSPoint(x: 80, y: host.isFlipped ? topY : host.bounds.height - topY), to: nil)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                timestamp: Date.timeIntervalSinceReferenceDate, windowNumber: window.windowNumber,
                context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0))
            window.sendEvent(event)
        }
    }

    private func waitUntil(_ predicate: () async -> Bool) async throws {
        for _ in 0..<80 {
            if await predicate() { return }
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        XCTFail("Expected mounted action/navigation did not complete")
    }
#endif

    private func bytes(_ value: ValueType?) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return try encoder.encode(value)
    }

    private struct Fixture {
        let vault: EphemeralIdentityVault
        let owner: Identity
        let member: Identity
        let outsider: Identity
        let resolver: CellResolver
        let endpoint: String
        let calls: MountedActionCalls
    }

    private func withFixture(_ run: (Fixture) async throws -> Void) async throws {
        let savedVault = CellBase.defaultIdentityVault
        let savedResolver = CellBase.defaultCellResolver
        let savedDebugAccess = CellBase.debugValidateAccessForEverything
        let vault = EphemeralIdentityVault()
        CellBase.defaultIdentityVault = vault
        CellBase.debugValidateAccessForEverything = false
        let resolver = CellResolver.sharedInstance
        CellBase.defaultCellResolver = resolver
        defer {
            CellBase.defaultIdentityVault = savedVault
            CellBase.defaultCellResolver = savedResolver
            CellBase.debugValidateAccessForEverything = savedDebugAccess
        }
        let ownerValue = await vault.identity(for: "private", makeNewIfNotFound: true)
        let memberValue = await vault.identity(for: "mounted-source-member", makeNewIfNotFound: true)
        let outsiderValue = await vault.identity(for: "mounted-source-outsider", makeNewIfNotFound: true)
        let owner = try XCTUnwrap(ownerValue), member = try XCTUnwrap(memberValue), outsider = try XCTUnwrap(outsiderValue)
        let calls = MountedActionCalls()
        let cell = await GeneralCell(owner: owner)
        let keypath = actionKeypath
        await cell.registerGet(key: keypath, owner: owner, returns: ExploreContract.schema(type: "string"), permissions: ["r---"]) { requester in
            await calls.append(operation: "get", keypath: keypath, payload: nil, requester: requester)
            return .string("source-read")
        }
        await cell.registerSet(key: keypath, owner: owner, input: .null, permissions: ["-w--"]) { requester, payload in
            await calls.append(operation: "set", keypath: keypath, payload: payload, requester: requester)
            return .string("source-write")
        }
        await cell.registerSet(key: "actions.noReply", owner: owner, input: .null, permissions: ["-w--"]) { requester, payload in
            await calls.append(operation: "set", keypath: "actions.noReply", payload: payload, requester: requester)
            return nil
        }
        cell.agreementTemplate.addGrant("rw--", for: keypath)
        cell.agreementTemplate.addGrant("-w--", for: "actions.noReply")
        let agreement = Agreement(owner: owner)
        agreement.addGrant("rw--", for: keypath)
        agreement.addGrant("-w--", for: "actions.noReply")
        let signed = await cell.addAgreement(agreement, for: member, authorizedBy: owner)
        XCTAssertEqual(signed, .signed)
        let name = "BindingMountedSource-" + UUID().uuidString
        try await resolver.registerNamedEmitCell(name: name, emitCell: cell, scope: .scaffoldUnique, identity: owner)
        do {
            try await run(Fixture(vault: vault, owner: owner, member: member, outsider: outsider,
                resolver: resolver, endpoint: "cell:///" + name, calls: calls))
            await resolver.unregisterEmitCell(uuid: cell.uuid)
        } catch {
            await resolver.unregisterEmitCell(uuid: cell.uuid)
            throw error
        }
    }
}

private actor MountedActionCalls {
    struct Call {
        let operation: String
        let keypath: String
        let payload: ValueType?
        let requesterUUID: String
    }
    private var calls: [Call] = []
    func append(operation: String, keypath: String, payload: ValueType?, requester: Identity) {
        calls.append(.init(operation: operation, keypath: keypath, payload: payload, requesterUUID: requester.uuid))
    }
    func snapshot() -> [Call] { calls }
}
