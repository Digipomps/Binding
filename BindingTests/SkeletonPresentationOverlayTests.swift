// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import XCTest
import CellBase
import CellApple
@testable import Binding

@MainActor
final class SkeletonPresentationOverlayTests: XCTestCase {
    func testPresentationNodeIsRemovedFromInlineSkeletonAndCollectedForOverlay() {
        let root = makeRootSkeleton(
            panelTitle: "Overlay Panel",
            presentation: SkeletonPresentation(
                kind: .drawer,
                placement: .trailing,
                closeActionKeypath: "overlay.close",
                dismissOnBackdrop: true,
                backdropStyle: .dim,
                accessibilityLabel: "Inspector"
            )
        )

        let extraction = BindingSkeletonPresentationSupport.extract(from: root, userInfoValue: nil)

        XCTAssertEqual(extraction.nodes.count, 1)
        XCTAssertEqual(extraction.nodes.first?.presentation.kind, .drawer)
        XCTAssertEqual(extraction.nodes.first?.presentation.placement, .trailing)
        XCTAssertNil(extraction.nodes.first.map(\.element).flatMap(BindingSkeletonPresentationSupport.presentation(for:)))
        XCTAssertEqual(textValues(in: extraction.baseElement), ["Base Content"])
        XCTAssertEqual(textValues(in: extraction.nodes.first?.element), ["Overlay Panel"])
    }

    func testHiddenPresentationNodeDoesNotRenderInlineOrAsOverlay() {
        var modifiers = SkeletonModifiers()
        modifiers.hidden = true
        modifiers.presentation = SkeletonPresentation(kind: .modal, placement: .center)

        var hiddenPanel = SkeletonText(text: "Hidden Panel")
        hiddenPanel.modifiers = modifiers

        let root = SkeletonElement.VStack(
            SkeletonVStack(elements: [
                .Text(SkeletonText(text: "Base Content")),
                .Text(hiddenPanel)
            ])
        )

        let extraction = BindingSkeletonPresentationSupport.extract(from: root, userInfoValue: nil)

        XCTAssertTrue(extraction.nodes.isEmpty)
        XCTAssertEqual(textValues(in: extraction.baseElement), ["Base Content"])
    }

    func testPresentationNodesAreSortedByZIndexThenSourceOrder() {
        let lower = makePanelText(title: "Lower", presentation: SkeletonPresentation(kind: .popover, zIndex: 1))
        let higher = makePanelText(title: "Higher", presentation: SkeletonPresentation(kind: .modal, zIndex: 20))
        let sameLayer = makePanelText(title: "Same Layer", presentation: SkeletonPresentation(kind: .sheet, zIndex: 20))

        let root = SkeletonElement.VStack(
            SkeletonVStack(elements: [
                .Text(SkeletonText(text: "Base Content")),
                lower,
                higher,
                sameLayer
            ])
        )

        let extraction = BindingSkeletonPresentationSupport.extract(from: root, userInfoValue: nil)

        XCTAssertEqual(extraction.nodes.map { $0.presentation.zIndex ?? 0 }, [1, 20, 20])
        XCTAssertEqual(extraction.nodes.flatMap { textValues(in: $0.element) }, ["Lower", "Higher", "Same Layer"])
    }

    func testChatPromptLogRetainsNativeListAndRelativeBindings() throws {
        var row = SkeletonVStack(elements: [
            .Text(SkeletonText(keypath: "speaker")),
            .Text(SkeletonText(keypath: "body"))
        ])
        row.modifiers = SkeletonModifiers()

        var list = SkeletonList(topic: nil, keypath: "messages", flowElementSkeleton: row)
        var listModifiers = SkeletonModifiers()
        listModifiers.styleRole = "chat-prompt-log"
        list.modifiers = listModifiers

        let root = ValueType.object([
            "messages": .list([
                .object([
                    "role": .string("user"),
                    "speaker": .string("Du"),
                    "body": .string("Hva skjer på arendalsuka?")
                ]),
                .object([
                    "role": .string("assistant"),
                    "speaker": .string("HAVEN Co-Pilot"),
                    "body": .string("Jeg åpner Arendalsuka Participant Program.")
                ])
            ])
        ])

        let extraction = BindingSkeletonPresentationSupport.extract(
            from: .List(list),
            context: .root(root)
        )
        guard case let .List(preserved)? = extraction.baseElement else {
            return XCTFail("Expected the prompt log to retain native List row context")
        }
        XCTAssertEqual(preserved.keypath, "messages")
        XCTAssertEqual(preserved.modifiers?.styleRole, "chat-prompt-log")
        XCTAssertEqual(preserved.flowElementSkeleton?.elements.count, 2)
        guard case let .Text(speaker)? = preserved.flowElementSkeleton?.elements.first else {
            return XCTFail("Expected the original speaker binding")
        }
        XCTAssertEqual(speaker.keypath, "speaker")
        XCTAssertNil(speaker.text)
        XCTAssertTrue(extraction.nodes.isEmpty)
    }

    func testRowOverlayRetainsItemAndRootWithoutFlatteningList() throws {
        var overlay = SkeletonText(keypath: "detail")
        var modifiers = SkeletonModifiers()
        modifiers.presentation = SkeletonPresentation(kind: .modal)
        modifiers.visibility = SkeletonVisibilityRule(when: SkeletonCondition(scope: .item, keypath: "open", equals: .bool(true)))
        overlay.modifiers = modifiers
        let row = SkeletonVStack(elements: [.Text(SkeletonText(keypath: "title")), .Text(overlay)])
        let list = SkeletonList(topic: nil, keypath: "rows", flowElementSkeleton: row)
        let root = ValueType.object([
            "headline": .string("Root preserved"),
            "rows": .list([
                .object(["title": .string("First"), "detail": .string("First detail"), "open": .bool(true)]),
                .object(["title": .string("Second"), "detail": .string("Second detail"), "open": .bool(false)])
            ])
        ])
        let extraction = BindingSkeletonPresentationSupport.extract(from: .List(list), userInfoValue: root)
        guard case let .List(preserved)? = extraction.baseElement else { return XCTFail("List must retain its row scope") }
        XCTAssertEqual(preserved.flowElementSkeleton?.elements.count, 1)
        XCTAssertEqual(extraction.nodes.count, 1)
        let data = try XCTUnwrap(extraction.nodes.first?.renderData)
        XCTAssertEqual(data.resolve("detail"), .string("First detail"))
        XCTAssertEqual(data.resolve("headline"), .string("Root preserved"))
    }

    func testGridItemVisibilityIsNotEvaluatedAgainstRoot() throws {
        var text = SkeletonText(keypath: "title")
        var modifiers = SkeletonModifiers()
        modifiers.visibility = SkeletonVisibilityRule(when: SkeletonCondition(scope: .item, keypath: "visible", equals: .bool(true)))
        text.modifiers = modifiers
        let grid = SkeletonGrid(columns: [], keypath: "cards", itemSkeleton: .Text(text))
        let root = ValueType.object(["visible": .bool(false), "cards": .list([
            .object(["title": .string("Visible card"), "visible": .bool(true)])
        ])])
        let extraction = BindingSkeletonPresentationSupport.extract(from: .Grid(grid), userInfoValue: root)
        guard case let .Grid(preserved)? = extraction.baseElement,
              case let .Text(item)? = preserved.itemSkeleton else { return XCTFail("The item template must survive until its row scope exists") }
        XCTAssertEqual(item.keypath, "title")
        XCTAssertNotNil(item.modifiers?.visibility)
    }

    func testFullyPresentedGridUsesEmptyInlineTemplateInsteadOfRawItemFallback() {
        var text = SkeletonText(keypath: "detail")
        var modifiers = SkeletonModifiers()
        modifiers.presentation = SkeletonPresentation(kind: .modal)
        text.modifiers = modifiers
        let grid = SkeletonGrid(columns: [], keypath: "cards", itemSkeleton: .Text(text))
        let root = ValueType.object(["cards": .list([.object(["detail": .string("Panel detail")])])])
        let extraction = BindingSkeletonPresentationSupport.extract(from: .Grid(grid), userInfoValue: root)
        guard case let .Grid(preserved)? = extraction.baseElement,
              case let .VStack(inline)? = preserved.itemSkeleton else { return XCTFail("Explicit empty template prevents raw object fallback") }
        XCTAssertTrue(inline.elements.isEmpty)
        XCTAssertEqual(extraction.nodes.count, 1)
    }

    func testRemoteRowTemplateIsNotStrippedBeforeItsDataArrives() {
        var text = SkeletonText(keypath: "detail")
        var modifiers = SkeletonModifiers()
        modifiers.presentation = SkeletonPresentation(kind: .modal)
        text.modifiers = modifiers
        let list = SkeletonList(topic: nil, keypath: "cell://example.test/Rows/state", flowElementSkeleton: SkeletonVStack(elements: [.Text(text)]))
        let extraction = BindingSkeletonPresentationSupport.extract(from: .List(list), userInfoValue: nil)
        guard case let .List(preserved)? = extraction.baseElement,
              let row = preserved.flowElementSkeleton?.elements.first else { return XCTFail("Remote template must remain intact") }
        XCTAssertNotNil(BindingSkeletonPresentationSupport.presentation(for: row))
        XCTAssertTrue(extraction.nodes.isEmpty)
    }

    func testOpenRowPanelKeepsIdentityWhenAnotherPanelCloses() throws {
        var text = SkeletonText(keypath: "detail")
        var modifiers = SkeletonModifiers()
        modifiers.presentation = SkeletonPresentation(kind: .modal)
        modifiers.visibility = SkeletonVisibilityRule(when: SkeletonCondition(scope: .item, keypath: "open", equals: .bool(true)))
        text.modifiers = modifiers
        let list = SkeletonList(topic: nil, keypath: "rows", flowElementSkeleton: SkeletonVStack(elements: [.Text(text)]))
        func root(firstOpen: Bool) -> ValueType { .object(["rows": .list([
            .object(["id": .string("first"), "open": .bool(firstOpen), "detail": .string("First")]),
            .object(["id": .string("second"), "open": .bool(true), "detail": .string("Second")])
        ])]) }
        let both = BindingSkeletonPresentationSupport.extract(from: .List(list), userInfoValue: root(firstOpen: true))
        let second = BindingSkeletonPresentationSupport.extract(from: .List(list), userInfoValue: root(firstOpen: false))
        XCTAssertEqual(both.nodes.count, 2)
        XCTAssertEqual(second.nodes.count, 1)
        XCTAssertEqual(try XCTUnwrap(both.nodes.last?.id), try XCTUnwrap(second.nodes.first?.id))
    }

    func testRepeatedPanelsFollowNativeBoundThenStaticOrderAndKeepListScopesDistinct() {
        var panel = SkeletonText(keypath: "detail")
        var modifiers = SkeletonModifiers()
        modifiers.presentation = SkeletonPresentation(kind: .modal)
        panel.modifiers = modifiers
        let template = SkeletonVStack(elements: [.Text(panel)])
        var first = SkeletonList(topic: nil, keypath: "rows", flowElementSkeleton: template)
        first.elements = [.object(["id": .string("static"), "detail": .string("Static")])]
        let second = SkeletonList(topic: nil, keypath: "rows", flowElementSkeleton: template)
        let root = ValueType.object(["rows": .list([
            .object(["id": .string("same"), "detail": .string("Bound")])
        ])])
        let result = BindingSkeletonPresentationSupport.extract(
            from: .VStack(SkeletonVStack(elements: [.List(first), .List(second)])), userInfoValue: root)
        XCTAssertEqual(result.nodes.map { $0.renderData.resolve("detail") },
                       [.string("Bound"), .string("Static"), .string("Bound")])
        XCTAssertEqual(Set(result.nodes.map(\.id)).count, 3, "The same row ID in distinct lists must not collide")
    }

    func testNestedItemNullDoesNotResurrectRootRowsInPanels() {
        var panel = SkeletonText(keypath: "detail")
        var modifiers = SkeletonModifiers()
        modifiers.presentation = SkeletonPresentation(kind: .modal)
        panel.modifiers = modifiers
        let list = SkeletonList(topic: nil, keypath: "rows", flowElementSkeleton: SkeletonVStack(elements: [.Text(panel)]))
        let context = BindingSkeletonRenderContext.root(.object([
            "rows": .list([.object(["detail": .string("Stale root row")])])
        ])).row(.object(["rows": .null]))
        let result = BindingSkeletonPresentationSupport.extract(from: .List(list), context: context)
        XCTAssertTrue(result.nodes.isEmpty)
    }

    func testTreeAndComponentSurfacePresentationsHonorVisibilityAndKeepTheirContracts() throws {
        func surfaces(_ modifiers: SkeletonModifiers) -> [SkeletonElement] {
            [
                .Tree(SkeletonTree(keypath: "nodes", idKeypath: "id", parentIDKeypath: "parentID",
                    levelKeypath: "level", leadingInsetKeypath: "inset", hasChildrenKeypath: "hasChildren",
                    expandedKeypath: "expanded", selectedIDStateKeypath: "selected",
                    selectionActionKeypath: "select", expansionActionKeypath: "expand",
                    rowSkeleton: SkeletonVStack(elements: [.Text(SkeletonText(keypath: "label"))]), modifiers: modifiers)),
                .ComponentSurface(SkeletonComponentSurface(sourceKeypath: "mounts.A", instanceID: "A",
                    variant: .pinned, modifiers: modifiers))
            ]
        }
        var modifiers = SkeletonModifiers()
        modifiers.presentation = SkeletonPresentation(kind: .modal)
        modifiers.visibility = SkeletonVisibilityRule(when: SkeletonCondition(scope: .root, keypath: "open", equals: .bool(true)))
        for original in surfaces(modifiers) {
            let closed = BindingSkeletonPresentationSupport.extract(from: original, userInfoValue: .object(["open": .bool(false)]))
            XCTAssertNil(closed.baseElement)
            XCTAssertTrue(closed.nodes.isEmpty)
            let open = BindingSkeletonPresentationSupport.extract(from: original, userInfoValue: .object(["open": .bool(true)]))
            XCTAssertNil(open.baseElement, "A modal must not also appear inline")
            let node = try XCTUnwrap(open.nodes.first)
            XCTAssertEqual(open.nodes.count, 1)
            XCTAssertNil(BindingSkeletonPresentationSupport.presentation(for: node.element), "Extraction must remove presentation to avoid recursion")
            switch node.element {
            case .Tree(let tree):
                XCTAssertEqual(tree.keypath, "nodes")
                XCTAssertEqual(tree.selectionActionKeypath, "select")
            case .ComponentSurface(let component):
                XCTAssertEqual(component.sourceKeypath, "mounts.A")
                XCTAssertEqual(component.instanceID, "A")
            default: XCTFail("The original element type must survive")
            }
        }
    }

    private func makeRootSkeleton(
        panelTitle: String,
        presentation: SkeletonPresentation
    ) -> SkeletonElement {
        SkeletonElement.VStack(
            SkeletonVStack(elements: [
                .Text(SkeletonText(text: "Base Content")),
                makePanelText(title: panelTitle, presentation: presentation)
            ])
        )
    }

    private func makePanelText(title: String, presentation: SkeletonPresentation) -> SkeletonElement {
        var modifiers = SkeletonModifiers()
        modifiers.presentation = presentation

        var text = SkeletonText(text: title)
        text.modifiers = modifiers
        return .Text(text)
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
        case .Tabs(let value):
            return value.panels.flatMap { panel in
                panel.content.flatMap { textValues(in: $0) }
            }
        case .Object(let value):
            return value.elements.keys.sorted().flatMap { key in
                textValues(in: value.elements[key])
            }
        default:
            return []
        }
    }
}
