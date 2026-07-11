// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import XCTest
import SwiftUI
import CellBase
import CellApple
@testable import Binding
#if canImport(AppKit)
import AppKit
#endif

@MainActor
final class SkeletonRendererParityTests: XCTestCase {
    func testButterpopNavigationButtonResolvesAgainstConfiguredHTTPSBase() {
        let button = SkeletonButton(
            keypath: "",
            label: "Open The Butterpop Collective",
            url: "/butterpop"
        )
        let baseURL = SkeletonButtonNavigation.configuredBaseURL(environment: [
            "CELL_SCAFFOLD_PUBLIC_BASE_URL": "https://haven.example/porthole"
        ])

        XCTAssertTrue(SkeletonButtonNavigation.isNavigationButton(button))
        XCTAssertEqual(
            SkeletonButtonNavigation.resolveURL(for: button, relativeTo: baseURL)?.absoluteString,
            "https://haven.example/butterpop"
        )
    }

#if canImport(AppKit)
    func testHAVENHostsButterpopButtonAndNavigationOpensExactlyOnce() async throws {
        let environmentKey = "CELL_SCAFFOLD_PUBLIC_BASE_URL"
        let previousValue = ProcessInfo.processInfo.environment[environmentKey]
        setenv(environmentKey, "https://haven.example", 1)
        defer {
            if let previousValue {
                setenv(environmentKey, previousValue, 1)
            } else {
                unsetenv(environmentKey)
            }
        }

        let navigationButton = SkeletonButton(
            keypath: "",
            label: "Open The Butterpop Collective",
            url: "/butterpop"
        )
        let viewModel = PortholeViewModel()
        let initialMutationVersion = viewModel.localMutationVersion
        var openedURLs: [URL] = []
        let hostingView = NSHostingView(
            rootView: BindingSkeletonView(element: .Button(navigationButton))
                .environmentObject(viewModel)
                .environment(\.openURL, OpenURLAction { url in
                    openedURLs.append(url)
                    return .handled
                })
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 480, height: 180)
        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }

        for _ in 0..<4 {
            hostingView.layoutSubtreeIfNeeded()
            hostingView.displayIfNeeded()
            try? await Task.sleep(nanoseconds: 25_000_000)
        }

        let imageRep = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: imageRep)
        XCTAssertGreaterThan(
            imageRep.representation(using: .png, properties: [:])?.count ?? 0,
            1_000,
            "Expected the HAVEN-hosted Butterpop button to render nonblank"
        )
        XCTAssertEqual(navigationButton.label, "Open The Butterpop Collective")

        let didOpen = await SkeletonButtonNavigationExecution.open(navigationButton) { url, completion in
            openedURLs.append(url)
            completion(true)
        }
        XCTAssertTrue(didOpen)
        XCTAssertEqual(openedURLs.map(\.absoluteString), ["https://haven.example/butterpop"])
        XCTAssertEqual(viewModel.localMutationVersion, initialMutationVersion)
    }
#endif

    func testVisibilityRuleUsesRootScopeInsideListRow() {
        var modifiers = SkeletonModifiers()
        modifiers.visibility = SkeletonVisibilityRule(
            when: SkeletonCondition(
                scope: .root,
                keypath: "state.showLaneChip",
                equals: .bool(true)
            )
        )

        var text = SkeletonText(text: "Root gated")
        text.modifiers = modifiers
        let element = SkeletonElement.VStack(SkeletonVStack(elements: [.Text(text)]))

        let rootAllows = ValueType.object([
            "state": .object(["showLaneChip": .bool(true)])
        ])
        let rootHides = ValueType.object([
            "state": .object(["showLaneChip": .bool(false)])
        ])
        let rowItemWouldHideIfUsedAsRoot = ValueType.object([
            "state": .object(["showLaneChip": .bool(false)])
        ])

        let visible = BindingSkeletonPresentationSupport.prepareRowElement(
            element,
            root: rootAllows,
            item: rowItemWouldHideIfUsedAsRoot
        )
        XCTAssertEqual(textValues(in: visible), ["Root gated"])

        let hidden = BindingSkeletonPresentationSupport.prepareRowElement(
            element,
            root: rootHides,
            item: .object(["state": .object(["showLaneChip": .bool(true)])])
        )
        XCTAssertEqual(textValues(in: hidden), [])
    }

    func testVisibilityRuleUsesItemScopeInsideListRow() {
        var modifiers = SkeletonModifiers()
        modifiers.visibility = SkeletonVisibilityRule(
            when: SkeletonCondition(
                scope: .item,
                keypath: "isVisible",
                equals: .bool(true)
            )
        )

        var text = SkeletonText(text: "Item gated")
        text.modifiers = modifiers
        let element = SkeletonElement.VStack(SkeletonVStack(elements: [.Text(text)]))
        let rootWouldShowIfUsedAsItem = ValueType.object(["isVisible": .bool(true)])

        let visible = BindingSkeletonPresentationSupport.prepareRowElement(
            element,
            root: rootWouldShowIfUsedAsItem,
            item: .object(["isVisible": .bool(true)])
        )
        XCTAssertEqual(textValues(in: visible), ["Item gated"])

        let hidden = BindingSkeletonPresentationSupport.prepareRowElement(
            element,
            root: rootWouldShowIfUsedAsItem,
            item: .object(["isVisible": .bool(false)])
        )
        XCTAssertEqual(textValues(in: hidden), [])
    }

    func testVisibilityRuleUsesContextScopeWithRootFallbackInsideListRow() {
        var modifiers = SkeletonModifiers()
        modifiers.visibility = SkeletonVisibilityRule(
            when: SkeletonCondition(
                scope: .context,
                keypath: "state.showLaneChip",
                equals: .bool(true)
            )
        )

        var text = SkeletonText(text: "Context gated")
        text.modifiers = modifiers
        let element = SkeletonElement.VStack(SkeletonVStack(elements: [.Text(text)]))

        let visible = BindingSkeletonPresentationSupport.prepareRowElement(
            element,
            root: .object(["state": .object(["showLaneChip": .bool(true)])]),
            item: .object(["label": .string("Co-Pilot")])
        )
        XCTAssertEqual(textValues(in: visible), ["Context gated"])

        let hidden = BindingSkeletonPresentationSupport.prepareRowElement(
            element,
            root: .object(["state": .object(["showLaneChip": .bool(false)])]),
            item: .object(["label": .string("Co-Pilot")])
        )
        XCTAssertEqual(textValues(in: hidden), [])
    }

    func testButtonLabelKeypathResolvesFromRowItemWithStaticFallback() {
        let button = SkeletonButton(
            keypath: "chat.selectLane",
            label: "Fallback lane",
            labelKeypath: "label"
        )

        let resolved = BindingSkeletonPresentationSupport.resolveButtonForRow(
            button,
            item: .object(["label": .string("Co-Pilot")])
        )
        XCTAssertEqual(resolved.label, "Co-Pilot")

        let missing = BindingSkeletonPresentationSupport.resolveButtonForRow(
            button,
            item: .object(["title": .string("Ignored")])
        )
        XCTAssertEqual(missing.label, "Fallback lane")

        let empty = BindingSkeletonPresentationSupport.resolveButtonForRow(
            button,
            item: .object(["label": .string("   ")])
        )
        XCTAssertEqual(empty.label, "Fallback lane")
    }

    func testButtonPayloadKeypathReplacesStaticPayloadFromRowItem() {
        let staticPayload = ValueType.object(["static": .bool(true)])
        let rowPayload = ValueType.object(["laneID": .string("lane-assistant")])
        let button = SkeletonButton(
            keypath: "chat.selectLane",
            label: "Select",
            payload: staticPayload,
            payloadKeypath: "payload"
        )

        let resolved = BindingSkeletonPresentationSupport.resolveButtonForRow(
            button,
            item: .object(["payload": rowPayload])
        )
        XCTAssertEqual(resolved.payload?["laneID"], .string("lane-assistant"))
        XCTAssertNil(resolved.payload?["static"])

        let fallback = BindingSkeletonPresentationSupport.resolveButtonForRow(
            button,
            item: .object(["label": .string("No payload field")])
        )
        XCTAssertEqual(fallback.payload?["static"], .bool(true))
        XCTAssertNil(fallback.payload?["laneID"])
    }

    func testLaneChipListFixtureMaterializesVisibleDynamicButtonRows() {
        var chipVisibility = SkeletonModifiers()
        chipVisibility.visibility = SkeletonVisibilityRule(
            when: SkeletonCondition(
                scope: .item,
                keypath: "isVisible",
                equals: .bool(true)
            )
        )

        var laneButton = SkeletonButton(
            keypath: "chat.selectLane",
            label: "Fallback lane",
            payload: .object(["static": .bool(true)]),
            labelKeypath: "label",
            payloadKeypath: "payload"
        )
        laneButton.modifiers = chipVisibility

        var laneList = SkeletonList(topic: nil, keypath: "lanes", flowElementSkeleton: nil)
        laneList.flowElementSkeleton = SkeletonVStack(elements: [.Button(laneButton)])

        let root = ValueType.object([
            "lanes": .list([
                .object([
                    "label": .string("Co-Pilot"),
                    "payload": .object(["laneID": .string("copilot")]),
                    "isVisible": .bool(true)
                ]),
                .object([
                    "label": .string("Hidden debug lane"),
                    "payload": .object(["laneID": .string("debug")]),
                    "isVisible": .bool(false)
                ])
            ])
        ])

        let extraction = BindingSkeletonPresentationSupport.extract(
            from: .List(laneList),
            context: .root(root)
        )
        let buttons = buttons(in: extraction.baseElement)

        XCTAssertEqual(buttons.map(\.label), ["Co-Pilot"])
        XCTAssertEqual(buttons.first?.payload?["laneID"], .string("copilot"))
        XCTAssertNil(buttons.first?.payload?["static"])
    }

    private func textValues(in element: SkeletonElement?) -> [String] {
        guard let element else {
            return []
        }

        switch element {
        case .Text(let value):
            return value.text.map { [$0] } ?? []
        case .HStack(let value):
            return value.elements.flatMap { textValues(in: $0) }
        case .VStack(let value):
            return value.elements.flatMap { textValues(in: $0) }
        case .ScrollView(let value):
            return value.elements.flatMap { textValues(in: $0) }
        case .Section(let value):
            return textValues(in: value.header)
                + value.content.flatMap { textValues(in: $0) }
                + textValues(in: value.footer)
        case .ZStack(let value):
            return value.elements.flatMap { textValues(in: $0) }
        case .Grid(let value):
            return value.elements.flatMap { textValues(in: $0) }
                + textValues(in: value.itemSkeleton)
        case .Object(let value):
            return value.elements.keys.sorted().flatMap { textValues(in: value.elements[$0]) }
        case .Tabs(let value):
            return value.panels.flatMap { $0.content.flatMap { textValues(in: $0) } }
        case .List(let value):
            return value.flowElementSkeleton.map { textValues(in: .VStack($0)) } ?? []
        case .Reference(let value):
            return value.flowElementSkeleton.map { textValues(in: .VStack($0)) } ?? []
        default:
            return []
        }
    }

    private func buttons(in element: SkeletonElement?) -> [SkeletonButton] {
        guard let element else {
            return []
        }

        switch element {
        case .Button(let button):
            return [button]
        case .HStack(let value):
            return value.elements.flatMap { buttons(in: $0) }
        case .VStack(let value):
            return value.elements.flatMap { buttons(in: $0) }
        case .ScrollView(let value):
            return value.elements.flatMap { buttons(in: $0) }
        case .Section(let value):
            return buttons(in: value.header)
                + value.content.flatMap { buttons(in: $0) }
                + buttons(in: value.footer)
        case .ZStack(let value):
            return value.elements.flatMap { buttons(in: $0) }
        case .Grid(let value):
            return value.elements.flatMap { buttons(in: $0) }
                + buttons(in: value.itemSkeleton)
        case .Object(let value):
            return value.elements.keys.sorted().flatMap { buttons(in: value.elements[$0]) }
        case .Tabs(let value):
            return value.panels.flatMap { $0.content.flatMap { buttons(in: $0) } }
        case .List(let value):
            return value.flowElementSkeleton.map { buttons(in: .VStack($0)) } ?? []
        case .Reference(let value):
            return value.flowElementSkeleton.map { buttons(in: .VStack($0)) } ?? []
        default:
            return []
        }
    }

}
