// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import SwiftUI
import CellBase
import CellApple

private struct BindingRuntimeSurfaceTargetSceneIDKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

extension EnvironmentValues {
    var bindingRuntimeSurfaceTargetSceneID: UUID? {
        get { self[BindingRuntimeSurfaceTargetSceneIDKey.self] }
        set { self[BindingRuntimeSurfaceTargetSceneIDKey.self] = newValue }
    }
}

struct BindingSkeletonView: View {
    let element: SkeletonElement
    let userInfoValue: ValueType?

    @EnvironmentObject private var viewModel: PortholeViewModel
    @Environment(\.bindingRuntimeSurfaceTargetSceneID) private var runtimeSurfaceTargetSceneID

    init(element: SkeletonElement, userInfoValue: ValueType? = nil) {
        self.element = element
        self.userInfoValue = userInfoValue
    }

    var body: some View {
        let extraction = BindingSkeletonPresentationSupport.extract(
            from: element,
            userInfoValue: userInfoValue,
            targetSceneID: runtimeSurfaceTargetSceneID
        )

        ZStack {
            if let baseElement = extraction.baseElement {
                SkeletonView(element: baseElement, userInfoValue: userInfoValue)
                    .environmentObject(viewModel)
            }

            BindingSkeletonPresentationOverlay(
                nodes: extraction.nodes,
                userInfoValue: userInfoValue
            )
            .environmentObject(viewModel)
        }
        .environment(
            \.skeletonButtonResolutionTransform,
            BindingRuntimeSurfaceLaunchSupport.buttonResolutionTransform(
                targetSceneID: runtimeSurfaceTargetSceneID
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct BindingSkeletonPresentationExtraction {
    var baseElement: SkeletonElement?
    var nodes: [BindingSkeletonPresentationNode]
}

struct BindingSkeletonRenderContext {
    var root: ValueType?
    var item: ValueType?
    var context: ValueType?
    var buttonContext: ValueType?
    var runtimeSurfaceTargetSceneID: UUID?

    static func root(
        _ value: ValueType?,
        runtimeSurfaceTargetSceneID: UUID? = nil
    ) -> BindingSkeletonRenderContext {
        BindingSkeletonRenderContext(
            root: value,
            item: nil,
            context: nil,
            buttonContext: nil,
            runtimeSurfaceTargetSceneID: runtimeSurfaceTargetSceneID
        )
    }

    func row(_ value: ValueType) -> BindingSkeletonRenderContext {
        BindingSkeletonRenderContext(
            root: root,
            item: value,
            context: Self.mergedContext(root: root, item: value),
            buttonContext: value,
            runtimeSurfaceTargetSceneID: runtimeSurfaceTargetSceneID
        )
    }

    private static func mergedContext(root: ValueType?, item: ValueType) -> ValueType {
        guard case let .object(itemObject) = item else {
            return item
        }
        guard case let .object(rootObject)? = root else {
            return item
        }

        var merged = rootObject
        for (key, value) in itemObject {
            merged[key] = value
        }
        return .object(merged)
    }
}

struct BindingSkeletonPresentationNode: Identifiable {
    var id: UUID { element.id }
    var element: SkeletonElement
    var presentation: SkeletonPresentation
    var sourceIndex: Int
}

enum BindingSkeletonPresentationSupport {
    static func extract(
        from element: SkeletonElement,
        userInfoValue: ValueType?,
        targetSceneID: UUID? = nil
    ) -> BindingSkeletonPresentationExtraction {
        extract(
            from: element,
            context: .root(
                userInfoValue,
                runtimeSurfaceTargetSceneID: targetSceneID
            )
        )
    }

    static func extract(
        from element: SkeletonElement,
        context: BindingSkeletonRenderContext
    ) -> BindingSkeletonPresentationExtraction {
        var nodes: [BindingSkeletonPresentationNode] = []
        let baseElement = extractBaseElement(
            from: element,
            context: context,
            nodes: &nodes
        )
        nodes.sort { lhs, rhs in
            let lhsZ = lhs.presentation.zIndex ?? 0
            let rhsZ = rhs.presentation.zIndex ?? 0
            if lhsZ == rhsZ {
                return lhs.sourceIndex < rhs.sourceIndex
            }
            return lhsZ < rhsZ
        }
        return BindingSkeletonPresentationExtraction(baseElement: baseElement, nodes: nodes)
    }

    static func presentation(for element: SkeletonElement) -> SkeletonPresentation? {
        modifiers(for: element)?.presentation
    }

    static func modifiers(for element: SkeletonElement) -> SkeletonModifiers? {
        switch element {
        case .Text(let value):
            return value.modifiers
        case .AttachmentField(let value):
            return value.modifiers
        case .FileUpload(let value):
            return value.modifiers
        case .TextField(let value):
            return value.modifiers
        case .TextArea(let value):
            return value.modifiers
        case .HStack(let value):
            return value.modifiers
        case .VStack(let value):
            return value.modifiers
        case .Image(let value):
            return value.modifiers
        case .List(let value):
            return value.modifiers
        case .Object(let value):
            return value.modifiers
        case .Spacer(let value):
            return value.modifiers
        case .Reference(let value):
            return value.modifiers
        case .Button(let value):
            return value.modifiers
        case .Divider(let value):
            return value.modifiers
        case .ScrollView(let value):
            return value.modifiers
        case .Section(let value):
            return value.modifiers
        case .Tabs(let value):
            return value.modifiers
        case .ZStack(let value):
            return value.modifiers
        case .Grid(let value):
            return value.modifiers
        case .Toggle(let value):
            return value.modifiers
        case .Picker(let value):
            return value.modifiers
        case .Visualization(let value):
            return value.modifiers
        case .Unsupported(let value):
            return value.modifiers
        @unknown default:
            return nil
        }
    }

    private static func extractBaseElement(
        from element: SkeletonElement,
        context: BindingSkeletonRenderContext,
        nodes: inout [BindingSkeletonPresentationNode]
    ) -> SkeletonElement? {
        guard isVisible(element, context: context) else {
            return nil
        }

        if let presentation = presentation(for: element) {
            guard let preparedElement = extractBaseElement(
                from: removingPresentation(from: element),
                context: context,
                nodes: &nodes
            ) else {
                return nil
            }
            nodes.append(
                BindingSkeletonPresentationNode(
                    element: preparedElement,
                    presentation: presentation,
                    sourceIndex: nodes.count
                )
            )
            return nil
        }

        switch element {
        case .HStack(var value):
            value.elements = extractBaseElements(from: value.elements, context: context, nodes: &nodes)
            return .HStack(value)
        case .VStack(var value):
            value.elements = extractBaseElements(from: value.elements, context: context, nodes: &nodes)
            return .VStack(value)
        case .ScrollView(var value):
            value.elements = extractBaseElements(from: value.elements, context: context, nodes: &nodes)
            return .ScrollView(value)
        case .Section(var value):
            value.header = value.header.flatMap {
                extractBaseElement(from: $0, context: context, nodes: &nodes)
            }
            value.content = extractBaseElements(from: value.content, context: context, nodes: &nodes)
            value.footer = value.footer.flatMap {
                extractBaseElement(from: $0, context: context, nodes: &nodes)
            }
            return .Section(value)
        case .ZStack(var value):
            value.elements = extractBaseElements(from: value.elements, context: context, nodes: &nodes)
            return .ZStack(value)
        case .Grid(var value):
            value.elements = extractBaseElements(from: value.elements, context: context, nodes: &nodes)
            value.itemSkeleton = value.itemSkeleton.flatMap {
                extractBaseElement(from: $0, context: context, nodes: &nodes)
            }
            return .Grid(value)
        case .List(var value):
            if let materialized = materializedList(value, context: context, nodes: &nodes) {
                return materialized
            }
            if let rowSkeleton = value.flowElementSkeleton,
               case let .VStack(preparedRow) = adaptRuntimeSurfaceButtons(
                   in: .VStack(rowSkeleton),
                   targetSceneID: context.runtimeSurfaceTargetSceneID
               ) {
                value.flowElementSkeleton = preparedRow
            }
            return .List(value)
        case .Reference(let value):
            return adaptRuntimeSurfaceButtons(
                in: .Reference(value),
                targetSceneID: context.runtimeSurfaceTargetSceneID
            )
        case .Tabs(var value):
            value.panels = value.panels.map { panel in
                var updated = panel
                updated.content = extractBaseElements(from: panel.content, context: context, nodes: &nodes)
                return updated
            }
            return .Tabs(value)
        case .Object(var value):
            var updatedElements: SkeletonElementObject = [:]
            for (key, child) in value.elements {
                if let updated = extractBaseElement(from: child, context: context, nodes: &nodes) {
                    updatedElements[key] = updated
                }
            }
            value.elements = updatedElements
            return .Object(value)
        case .Button(let value):
            return .Button(resolveButton(value, context: context))
        default:
            return element
        }
    }

    private static func extractBaseElements(
        from elements: SkeletonElementList,
        context: BindingSkeletonRenderContext,
        nodes: inout [BindingSkeletonPresentationNode]
    ) -> SkeletonElementList {
        elements.compactMap {
            extractBaseElement(from: $0, context: context, nodes: &nodes)
        }
    }

    private static func adaptRuntimeSurfaceButtons(
        in element: SkeletonElement,
        targetSceneID: UUID?
    ) -> SkeletonElement {
        switch element {
        case .HStack(var value):
            value.elements = value.elements.map {
                adaptRuntimeSurfaceButtons(in: $0, targetSceneID: targetSceneID)
            }
            return .HStack(value)
        case .VStack(var value):
            value.elements = value.elements.map {
                adaptRuntimeSurfaceButtons(in: $0, targetSceneID: targetSceneID)
            }
            return .VStack(value)
        case .ScrollView(var value):
            value.elements = value.elements.map {
                adaptRuntimeSurfaceButtons(in: $0, targetSceneID: targetSceneID)
            }
            return .ScrollView(value)
        case .Section(var value):
            value.header = value.header.map {
                adaptRuntimeSurfaceButtons(in: $0, targetSceneID: targetSceneID)
            }
            value.content = value.content.map {
                adaptRuntimeSurfaceButtons(in: $0, targetSceneID: targetSceneID)
            }
            value.footer = value.footer.map {
                adaptRuntimeSurfaceButtons(in: $0, targetSceneID: targetSceneID)
            }
            return .Section(value)
        case .ZStack(var value):
            value.elements = value.elements.map {
                adaptRuntimeSurfaceButtons(in: $0, targetSceneID: targetSceneID)
            }
            return .ZStack(value)
        case .Grid(var value):
            value.elements = value.elements.map {
                adaptRuntimeSurfaceButtons(in: $0, targetSceneID: targetSceneID)
            }
            value.itemSkeleton = value.itemSkeleton.map {
                adaptRuntimeSurfaceButtons(in: $0, targetSceneID: targetSceneID)
            }
            return .Grid(value)
        case .List(var value):
            if let rowSkeleton = value.flowElementSkeleton,
               case let .VStack(preparedRow) = adaptRuntimeSurfaceButtons(
                   in: .VStack(rowSkeleton),
                   targetSceneID: targetSceneID
               ) {
                value.flowElementSkeleton = preparedRow
            }
            return .List(value)
        case .Reference(var value):
            if let rowSkeleton = value.flowElementSkeleton,
               case let .VStack(preparedRow) = adaptRuntimeSurfaceButtons(
                   in: .VStack(rowSkeleton),
                   targetSceneID: targetSceneID
               ) {
                value.flowElementSkeleton = preparedRow
            }
            return .Reference(value)
        case .Tabs(var value):
            value.panels = value.panels.map { panel in
                var preparedPanel = panel
                preparedPanel.content = panel.content.map {
                    adaptRuntimeSurfaceButtons(in: $0, targetSceneID: targetSceneID)
                }
                return preparedPanel
            }
            return .Tabs(value)
        case .Object(var value):
            value.elements = value.elements.mapValues {
                adaptRuntimeSurfaceButtons(in: $0, targetSceneID: targetSceneID)
            }
            return .Object(value)
        case .Button(let value):
            return .Button(
                BindingRuntimeSurfaceLaunchSupport.adaptSkeletonButton(
                    value,
                    targetSceneID: targetSceneID
                )
            )
        default:
            return element
        }
    }

    private static func isVisible(_ element: SkeletonElement, context: BindingSkeletonRenderContext) -> Bool {
        guard let modifiers = modifiers(for: element) else {
            return true
        }
        if modifiers.hidden == true {
            return false
        }
        guard let visibility = modifiers.visibility else {
            return true
        }
        return visibility.isVisible(root: context.root, item: context.item, context: context.context)
    }

    static func prepareRowElement(
        _ element: SkeletonElement,
        root: ValueType?,
        item: ValueType
    ) -> SkeletonElement? {
        var nodes: [BindingSkeletonPresentationNode] = []
        return extractBaseElement(from: element, context: .root(root).row(item), nodes: &nodes)
    }

    static func resolveButtonForRow(
        _ button: SkeletonButton,
        item: ValueType
    ) -> SkeletonButton {
        resolveButton(button, context: .root(nil).row(item))
    }

    private static func materializedList(
        _ list: SkeletonList,
        context: BindingSkeletonRenderContext,
        nodes: inout [BindingSkeletonPresentationNode]
    ) -> SkeletonElement? {
        guard let rowSkeleton = list.flowElementSkeleton,
              canMaterializeList(list) else {
            return nil
        }

        let rows = resolvedRows(
            keypath: list.keypath,
            staticElements: list.elements,
            root: context.root
        )
        guard let rowElements = materializedRows(
            from: rows,
            rowSkeleton: rowSkeleton,
            listStyleRole: list.modifiers?.styleRole,
            context: context,
            nodes: &nodes
        ) else {
            return nil
        }

        return .VStack(SkeletonVStack(elements: rowElements, spacing: 8, modifiers: list.modifiers))
    }

    private static func canMaterializeList(_ list: SkeletonList) -> Bool {
        if list.topic?.isEmpty == false {
            return false
        }
        if list.filterTypes?.isEmpty == false {
            return false
        }
        if let selectionMode = list.selectionMode, selectionMode != .none {
            return false
        }
        return list.selectionValueKeypath == nil
            && list.selectionStateKeypath == nil
            && list.selectionActionKeypath == nil
            && list.activationActionKeypath == nil
            && list.selectionPayloadMode == nil
    }

    private static func materializedRows(
        from rows: ValueTypeList,
        rowSkeleton: SkeletonVStack,
        listStyleRole: String?,
        context: BindingSkeletonRenderContext,
        nodes: inout [BindingSkeletonPresentationNode]
    ) -> SkeletonElementList? {
        guard rows.isEmpty == false else {
            return nil
        }

        return rows.compactMap { row in
            var preparedRow = rowSkeleton
            if listStyleRole == "chat-prompt-log" {
                preparedRow.modifiers = chatPromptRowModifiers(
                    role: stringValue(at: "role", in: row)
                )
            }
            let rowElement = SkeletonElement.VStack(preparedRow)
            return extractBaseElement(from: rowElement, context: context.row(row), nodes: &nodes)
        }
    }

    private static func chatPromptRowModifiers(role: String?) -> SkeletonModifiers {
        let isUser = role == "user"
        var modifiers = SkeletonModifiers()
        modifiers.padding = 12
        modifiers.maxWidthInfinity = true
        modifiers.hAlignment = isUser ? "trailing" : "leading"
        modifiers.background = isUser ? "#E8F1FF" : "#F4F5F7"
        modifiers.cornerRadius = 14
        modifiers.borderWidth = 1
        modifiers.borderColor = isUser ? "#9FC1F8" : "#D7DCE2"
        modifiers.styleRole = isUser ? "chat-prompt-row-user" : "chat-prompt-row-assistant"
        modifiers.styleClasses = ["chat-prompt-row", modifiers.styleRole ?? ""]
        return modifiers
    }

    private static func stringValue(at keypath: String, in source: ValueType) -> String? {
        guard case let .string(string)? = value(at: keypath, in: source) else {
            return nil
        }
        return string
    }

    private static func resolvedRows(
        keypath: String?,
        staticElements: ValueTypeList,
        root: ValueType?
    ) -> ValueTypeList {
        var rows = staticElements
        if let keypath,
           keypath.hasPrefix("cell://") == false,
           case let .list(resolvedRows)? = value(at: keypath, in: root) {
            rows.append(contentsOf: resolvedRows)
        }
        return rows
    }

    private static func value(at keypath: String, in value: ValueType?) -> ValueType? {
        guard keypath.isEmpty == false else {
            return nil
        }
        if keypath == "." || keypath == "$" {
            return value
        }
        return value?[keypath]
    }

    private static func resolveButton(
        _ skeletonButton: SkeletonButton,
        context: BindingSkeletonRenderContext
    ) -> SkeletonButton {
        var button = skeletonButton

        guard case let .object(object)? = context.buttonContext else {
            suppressDeferredButtonResolution(&button)
            return BindingRuntimeSurfaceLaunchSupport.adaptSkeletonButton(
                button,
                targetSceneID: context.runtimeSurfaceTargetSceneID
            )
        }

        if let urlValue = object["url"], case let .string(urlString) = urlValue {
            button.url = urlString
        }

        let keypathField = trimmedNonEmpty(skeletonButton.keypathKeypath) ?? "keypath"
        let labelField = trimmedNonEmpty(skeletonButton.labelKeypath) ?? "label"
        let payloadField = trimmedNonEmpty(skeletonButton.payloadKeypath) ?? "payload"

        if let keypathValue = object[keypathField],
           case let .string(keypathString) = keypathValue,
           let resolvedKeypath = trimmedNonEmpty(keypathString) {
            button.keypath = resolvedKeypath
        }
        if let labelValue = object[labelField],
           case let .string(labelString) = labelValue,
           trimmedNonEmpty(labelString) != nil {
            button.label = labelString
        }
        if let payloadValue = object[payloadField] {
            button.payload = payloadValue
        }

        let hasDetailTarget = (trimmedNonEmpty(stringValue(object["detailKeypath"])) != nil)
            || object["detailPayload"] != nil
        if button.keypath == "addConfiguration", hasDetailTarget {
            if let detailKeypath = trimmedNonEmpty(stringValue(object["detailKeypath"])) {
                button.keypath = detailKeypath
            }
            if let detailLabel = stringValue(object["detailLabel"]),
               trimmedNonEmpty(detailLabel) != nil {
                button.label = detailLabel
            }
            if let detailPayload = object["detailPayload"] {
                button.payload = detailPayload
            }
        }

        suppressDeferredButtonResolution(&button)
        return BindingRuntimeSurfaceLaunchSupport.adaptSkeletonButton(
            button,
            targetSceneID: context.runtimeSurfaceTargetSceneID
        )
    }

    private static func suppressDeferredButtonResolution(_ button: inout SkeletonButton) {
        let sentinel = "__binding_skeleton_no_dynamic_button_keypath__"
        button.keypathKeypath = sentinel
        button.labelKeypath = sentinel
        button.payloadKeypath = sentinel
    }

    private static func trimmedNonEmpty(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func stringValue(_ value: ValueType?) -> String? {
        guard case let .string(string)? = value else {
            return nil
        }
        return string
    }

    private static func removingPresentation(from element: SkeletonElement) -> SkeletonElement {
        var modifiers = modifiers(for: element)
        modifiers?.presentation = nil
        return setting(modifiers: modifiers, on: element)
    }

    private static func setting(modifiers: SkeletonModifiers?, on element: SkeletonElement) -> SkeletonElement {
        switch element {
        case .Text(var value):
            value.modifiers = modifiers
            return .Text(value)
        case .AttachmentField(var value):
            value.modifiers = modifiers
            return .AttachmentField(value)
        case .FileUpload(var value):
            value.modifiers = modifiers
            return .FileUpload(value)
        case .TextField(var value):
            value.modifiers = modifiers
            return .TextField(value)
        case .TextArea(var value):
            value.modifiers = modifiers
            return .TextArea(value)
        case .HStack(var value):
            value.modifiers = modifiers
            return .HStack(value)
        case .VStack(var value):
            value.modifiers = modifiers
            return .VStack(value)
        case .Image(var value):
            value.modifiers = modifiers
            return .Image(value)
        case .List(var value):
            value.modifiers = modifiers
            return .List(value)
        case .Object(var value):
            value.modifiers = modifiers
            return .Object(value)
        case .Spacer(var value):
            value.modifiers = modifiers
            return .Spacer(value)
        case .Reference(var value):
            value.modifiers = modifiers
            return .Reference(value)
        case .Button(var value):
            value.modifiers = modifiers
            return .Button(value)
        case .Divider(var value):
            value.modifiers = modifiers
            return .Divider(value)
        case .ScrollView(var value):
            value.modifiers = modifiers
            return .ScrollView(value)
        case .Section(var value):
            value.modifiers = modifiers
            return .Section(value)
        case .Tabs(var value):
            value.modifiers = modifiers
            return .Tabs(value)
        case .ZStack(var value):
            value.modifiers = modifiers
            return .ZStack(value)
        case .Grid(var value):
            value.modifiers = modifiers
            return .Grid(value)
        case .Toggle(var value):
            value.modifiers = modifiers
            return .Toggle(value)
        case .Picker(var value):
            value.modifiers = modifiers
            return .Picker(value)
        case .Visualization(var value):
            value.modifiers = modifiers
            return .Visualization(value)
        case .Unsupported(var value):
            value.modifiers = modifiers
            return .Unsupported(value)
        @unknown default:
            return element
        }
    }
}

private struct BindingSkeletonPresentationOverlay: View {
    let nodes: [BindingSkeletonPresentationNode]
    let userInfoValue: ValueType?

    @EnvironmentObject private var viewModel: PortholeViewModel

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    BindingSkeletonPresentationLayer(
                        node: node,
                        isTopmost: index == nodes.count - 1,
                        viewportSize: proxy.size,
                        userInfoValue: userInfoValue
                    )
                    .environmentObject(viewModel)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(nodes.isEmpty == false)
    }
}

private struct BindingSkeletonPresentationLayer: View {
    let node: BindingSkeletonPresentationNode
    let isTopmost: Bool
    let viewportSize: CGSize
    let userInfoValue: ValueType?

    @EnvironmentObject private var viewModel: PortholeViewModel

    var body: some View {
        let effectivePresentation = effectivePresentation(for: node.presentation)
        let alignment = Self.alignment(for: effectivePresentation)

        ZStack(alignment: alignment) {
            if isTopmost {
                backdrop(for: effectivePresentation)
            }

            SkeletonView(element: node.element, userInfoValue: userInfoValue)
                .environmentObject(viewModel)
                .frame(
                    maxWidth: maxPanelWidth(for: effectivePresentation),
                    maxHeight: maxPanelHeight(for: effectivePresentation),
                    alignment: .topLeading
                )
                .padding(edgePadding(for: effectivePresentation))
                .accessibilityLabel(Text(effectivePresentation.accessibilityLabel ?? "Presentation"))
                .bindingSkeletonExitCommand(
                    enabled: isTopmost && effectivePresentation.escapeKeyBehavior == .closeAction
                ) {
                    dismiss(effectivePresentation, reason: "escape")
                }
        }
        .zIndex(Double(effectivePresentation.zIndex ?? node.sourceIndex))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func backdrop(for presentation: SkeletonPresentation) -> some View {
        let style = presentation.backdropStyle ?? .none
        switch style {
        case .none:
            if presentation.dismissOnBackdrop == true {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismiss(presentation, reason: "backdrop")
                    }
            }
        case .dim:
            Color.black.opacity(0.28)
                .contentShape(Rectangle())
                .onTapGesture {
                    if presentation.dismissOnBackdrop == true {
                        dismiss(presentation, reason: "backdrop")
                    }
                }
        case .blur:
            Rectangle()
                .fill(.ultraThinMaterial)
                .contentShape(Rectangle())
                .onTapGesture {
                    if presentation.dismissOnBackdrop == true {
                        dismiss(presentation, reason: "backdrop")
                    }
                }
        }
    }

    private func dismiss(_ presentation: SkeletonPresentation, reason: String) {
        guard let closeActionKeypath = presentation.closeActionKeypath,
              closeActionKeypath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return
        }
        Task {
            await BindingSkeletonPresentationActionDispatcher.dispatchClose(
                keypath: closeActionKeypath,
                presentation: presentation,
                reason: reason,
                viewModel: viewModel
            )
        }
    }

    private func effectivePresentation(for presentation: SkeletonPresentation) -> SkeletonPresentation {
        guard viewportSize.width < 600, let fallback = presentation.mobileFallback else {
            return presentation
        }
        var updated = presentation
        if let kind = fallback.kind {
            updated.kind = kind
        }
        if let placement = fallback.placement {
            updated.placement = placement
        }
        return updated
    }

    private static func alignment(for presentation: SkeletonPresentation) -> Alignment {
        switch presentation.placement ?? defaultPlacement(for: presentation.kind) {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        case .top:
            return .top
        case .bottom:
            return .bottom
        case .center, .anchor:
            return .center
        }
    }

    private static func defaultPlacement(for kind: SkeletonPresentationKind) -> SkeletonPresentationPlacement {
        switch kind {
        case .drawer:
            return .trailing
        case .sheet:
            return .bottom
        case .overlay, .popover, .modal:
            return .center
        }
    }

    private func maxPanelWidth(for presentation: SkeletonPresentation) -> CGFloat? {
        let width = viewportSize.width
        switch presentation.kind {
        case .drawer:
            return min(max(width * 0.86, 320), 440)
        case .sheet:
            return min(width - 24, 720)
        case .modal:
            return min(width - 24, 620)
        case .popover:
            return min(width - 24, 420)
        case .overlay:
            return min(width - 24, 760)
        }
    }

    private func maxPanelHeight(for presentation: SkeletonPresentation) -> CGFloat? {
        let height = viewportSize.height
        switch presentation.kind {
        case .drawer:
            return max(height - 24, 0)
        case .sheet:
            return max(min(height * 0.72, 640), 0)
        case .modal, .popover, .overlay:
            return max(height * 0.88, 0)
        }
    }

    private func edgePadding(for presentation: SkeletonPresentation) -> EdgeInsets {
        switch presentation.placement ?? Self.defaultPlacement(for: presentation.kind) {
        case .leading:
            return EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 0)
        case .trailing:
            return EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 12)
        case .top:
            return EdgeInsets(top: 12, leading: 12, bottom: 0, trailing: 12)
        case .bottom:
            return EdgeInsets(top: 0, leading: 12, bottom: 12, trailing: 12)
        case .center, .anchor:
            return EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        }
    }
}

private enum BindingSkeletonPresentationActionDispatcher {
    static func dispatchClose(
        keypath: String,
        presentation: SkeletonPresentation,
        reason: String,
        viewModel: PortholeViewModel
    ) async {
        let currentRequester = await viewModel.executionRequesterIdentity()
        let fallbackRequester = await CellBase.defaultIdentityVault?.identity(for: "private", makeNewIfNotFound: true)
        guard let requester = currentRequester ?? fallbackRequester,
              let target = resolveTarget(for: keypath) else {
            return
        }

        do {
            guard let cell = try await CellResolver.sharedInstance.emitCellAtEndpoint(
                endpointUrl: target.url,
                endpoint: target.url.absoluteString,
                requester: requester
            ) as? Meddle else {
                return
            }
            let value = ValueType.object(closePayload(for: presentation, reason: reason))
            _ = try await cell.set(keypath: target.keypath, value: value, requester: requester)
            await MainActor.run {
                viewModel.markLocalMutation()
            }
        } catch {
            CellBase.diagnosticLog("Skeleton presentation close failed for \(keypath): \(error)", domain: .skeleton)
        }
    }

    private static func closePayload(for presentation: SkeletonPresentation, reason: String) -> Object {
        var payload: Object = [
            "source": .string("skeleton.presentation"),
            "reason": .string(reason),
            "kind": .string(presentation.kind.rawValue)
        ]
        if let placement = presentation.placement {
            payload["placement"] = .string(placement.rawValue)
        }
        if let openStateKeypath = presentation.openStateKeypath {
            payload["openStateKeypath"] = .string(openStateKeypath)
        }
        if let anchorRole = presentation.anchorRole {
            payload["anchorRole"] = .string(anchorRole)
        }
        if let anchorKeypath = presentation.anchorKeypath {
            payload["anchorKeypath"] = .string(anchorKeypath)
        }
        if let zIndex = presentation.zIndex {
            payload["zIndex"] = .integer(zIndex)
        }
        return payload
    }

    private static func resolveTarget(for keypath: String) -> (url: URL, keypath: String)? {
        let trimmed = keypath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return nil
        }

        if trimmed.hasPrefix("cell://"), let url = URL(string: trimmed) {
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            guard let child = pathComponents.last else {
                return nil
            }
            return (url.deletingLastPathComponent(), child)
        }

        guard let portholeURL = URL(string: "cell:///Porthole") else {
            return nil
        }
        return (portholeURL, trimmed)
    }
}

private extension View {
    @ViewBuilder
    func bindingSkeletonExitCommand(enabled: Bool, perform: @escaping () -> Void) -> some View {
#if os(macOS)
        if enabled {
            self.onExitCommand(perform: perform)
        } else {
            self
        }
#else
        self
#endif
    }
}
