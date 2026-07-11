// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import XCTest
import CellBase
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

    func testChatPromptLogMaterializesDistinctUserAndAssistantRows() throws {
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
        guard case let .VStack(container)? = extraction.baseElement else {
            return XCTFail("Expected the prompt list to materialize as a VStack")
        }
        let rows = container.elements.compactMap { element -> SkeletonVStack? in
            guard case let .VStack(row) = element else { return nil }
            return row
        }

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].modifiers?.styleRole, "chat-prompt-row-user")
        XCTAssertEqual(rows[0].modifiers?.hAlignment, "trailing")
        XCTAssertEqual(rows[0].modifiers?.background, "#E8F1FF")
        XCTAssertEqual(rows[1].modifiers?.styleRole, "chat-prompt-row-assistant")
        XCTAssertEqual(rows[1].modifiers?.hAlignment, "leading")
        XCTAssertEqual(rows[1].modifiers?.background, "#F4F5F7")
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
