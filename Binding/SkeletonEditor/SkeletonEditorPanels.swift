import SwiftUI
import CellBase

struct SkeletonTreePanel: View {
    @ObservedObject var editorState: EditorState
    private let preferredWidth: CGFloat?
    private let maximumHeight: CGFloat?
    private let showsBackground: Bool
    @State private var addElementKind: SkeletonInsertElementKind = .text

    init(
        editorState: EditorState,
        preferredWidth: CGFloat? = 300,
        maximumHeight: CGFloat? = 420,
        showsBackground: Bool = true
    ) {
        self.editorState = editorState
        self.preferredWidth = preferredWidth
        self.maximumHeight = maximumHeight
        self.showsBackground = showsBackground
    }

    private var nodes: [SkeletonTreeNodeDescriptor] {
        guard let workingCopy = editorState.workingCopy else { return [] }
        return SkeletonTreeQueries.linearizedNodes(in: workingCopy)
    }

    private var references: [CellReference] {
        editorState.workingConfiguration?.cellReferences ?? []
    }

    private var referenceUsageReport: ReferenceUsageReport {
        ReferenceUsageAnalyzer.analyze(
            skeleton: editorState.workingCopy,
            references: references
        )
    }

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 8) {
            Text("Elements")
                .font(.headline)

            if !nodes.isEmpty || !references.isEmpty {
                Text("\(nodes.count) noder • \(references.count) refs")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if nodes.isEmpty {
                Text("No elements")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(nodes) { node in
                            let isSelected = node.path == editorState.selectedNodePath
                            Button {
                                editorState.selectNode(node.path)
                            } label: {
                                HStack(spacing: 8) {
                                    Text(node.title)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                    Text(node.path.description)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .padding(.leading, CGFloat(node.depth) * 14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(isSelected ? Color.accentColor.opacity(0.20) : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !references.isEmpty {
                Divider()

                Text("References")
                    .font(.subheadline.weight(.semibold))

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(references.enumerated()), id: \.offset) { _, reference in
                            ReferenceSummaryCard(
                                reference: reference,
                                statusBadge: referenceUsageReport.unusedTopLevelLabels.contains(reference.editorTrimmedLabel) ? "Unused" : nil,
                                statusTint: .orange
                            )
                        }
                    }
                }
                .frame(maxHeight: 120)
            }

            Divider()

            HStack(spacing: 8) {
                Button("Delete Selected", role: .destructive) {
                    guard let path = editorState.selectedNodePath else { return }
                    editorState.deleteNode(at: path)
                }
                .disabled(editorState.selectedNodePath == nil || editorState.selectedNodePath == .root)
                .font(.caption)
            }

            HStack(spacing: 8) {
                Picker("Element", selection: $addElementKind) {
                    ForEach(SkeletonInsertElementKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)

                Button("Add") {
                    insertSelectedKind()
                }
                .disabled(insertionPlan() == nil)
                .font(.caption)
            }
        }
        .padding(10)

        Group {
            if let preferredWidth {
                content
                    .frame(width: preferredWidth)
            } else {
                content
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .modifier(PanelHeightModifier(maximumHeight: maximumHeight))
        .modifier(PanelBackgroundModifier(showsBackground: showsBackground))
    }

    private func insertionPlan() -> (parentPath: SkeletonNodePath, index: Int?)? {
        guard let root = editorState.workingCopy else { return nil }
        guard let selectedPath = editorState.selectedNodePath else {
            if SkeletonTreeQueries.canContainChildren(root) {
                return (.root, nil)
            }
            return nil
        }

        guard let selectedElement = SkeletonTreeQueries.element(in: root, at: selectedPath) else {
            return nil
        }

        if SkeletonTreeQueries.canContainChildren(selectedElement) {
            return (selectedPath, nil)
        }

        guard let parentPath = selectedPath.parent,
              let selectedIndex = selectedPath.indices.last else {
            return nil
        }
        return (parentPath, selectedIndex + 1)
    }

    private func insertSelectedKind() {
        guard let plan = insertionPlan() else { return }
        let newElement = addElementKind.makeElement()
        let insertIndex = plan.index
        let selectedInsertIndex: Int = {
            if let insertIndex {
                return insertIndex
            }
            guard let root = editorState.workingCopy,
                  let parent = SkeletonTreeQueries.element(in: root, at: plan.parentPath) else {
                return 0
            }
            return SkeletonTreeQueries.childCount(in: parent)
        }()

        editorState.insertNode(newElement, into: plan.parentPath, at: insertIndex)
        editorState.selectNode(plan.parentPath.appending(selectedInsertIndex))
    }
}

struct SkeletonModifierInspectorPanel: View {
    @ObservedObject var editorState: EditorState
    private let preferredWidth: CGFloat?
    private let maximumHeight: CGFloat?
    private let modifierListMaximumHeight: CGFloat?
    private let showsBackground: Bool
    @State private var rawNodeExpanded = false
    @State private var addParameterSelection: SkeletonElementParameterKey?
    @State private var parameterValueDrafts: [SkeletonElementParameterKey: String] = [:]
    @State private var invalidParameterDrafts: Set<SkeletonElementParameterKey> = []

    @State private var addSelection: SkeletonModifierKey?
    @State private var valueDrafts: [SkeletonModifierKey: String] = [:]
    @State private var invalidDrafts: Set<SkeletonModifierKey> = []

    private var selectedPath: SkeletonNodePath? {
        editorState.selectedNodePath
    }

    private var selectedElement: SkeletonElement? {
        editorState.selectedElement
    }

    private var selectedModifiers: SkeletonModifiers? {
        editorState.selectedModifiers
    }

    private var references: [CellReference] {
        editorState.workingConfiguration?.cellReferences ?? []
    }

    private var selectedChildCount: Int {
        guard let selectedElement else { return 0 }
        return SkeletonTreeQueries.childCount(in: selectedElement)
    }

    private var rawSelectedElementJSON: String? {
        guard let selectedElement,
              let data = try? prettyPrint(selectedElement),
              let json = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return json
    }

    private var activeParameterKeys: [SkeletonElementParameterKey] {
        SkeletonElementParameterCatalog.activeKeys(for: selectedElement)
    }

    private var addableParameterKeys: [SkeletonElementParameterKey] {
        SkeletonElementParameterCatalog.addableKeys(for: selectedElement)
    }

    private var activeKeys: [SkeletonModifierKey] {
        SkeletonModifierCatalog.activeKeys(modifiers: selectedModifiers)
    }

    private var addableKeys: [SkeletonModifierKey] {
        SkeletonModifierCatalog.addableKeys(for: selectedElement, modifiers: selectedModifiers)
    }

    private var matchingReferences: [CellReference] {
        guard let selectedElement else { return [] }
        let labels = ReferenceUsageAnalyzer.matchingTopLevelLabels(
            for: selectedElement,
            references: references
        )
        guard !labels.isEmpty else { return [] }
        return references.filter { labels.contains($0.editorTrimmedLabel) }
    }

    init(
        editorState: EditorState,
        preferredWidth: CGFloat? = 360,
        maximumHeight: CGFloat? = 520,
        modifierListMaximumHeight: CGFloat? = 150,
        showsBackground: Bool = true
    ) {
        self.editorState = editorState
        self.preferredWidth = preferredWidth
        self.maximumHeight = maximumHeight
        self.modifierListMaximumHeight = modifierListMaximumHeight
        self.showsBackground = showsBackground
    }

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 10) {
            Text("Inspector")
                .font(.headline)

            if let selectedElement, let selectedPath {
                Text("\(SkeletonTreeQueries.displayName(for: selectedElement)) @ \(selectedPath.description)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Children: \(selectedChildCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Select an element")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if selectedPath != nil {
                bindingContextSection
                parameterSection

                HStack(spacing: 8) {
                    Picker("Add Modifier", selection: $addSelection) {
                        Text("Select").tag(Optional<SkeletonModifierKey>.none)
                        ForEach(addableKeys) { key in
                            Text(key.title).tag(Optional(key))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)

                    Button("Add") {
                        guard let key = addSelection else { return }
                        addModifier(key)
                    }
                    .disabled(addSelection == nil)
                }

                Divider()

                Text("Modifiers")
                    .font(.subheadline.weight(.semibold))

                if activeKeys.isEmpty {
                    Text("No modifiers on selected element")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(activeKeys) { key in
                                modifierRow(for: key)
                            }
                        }
                    }
                    .modifier(PanelHeightModifier(maximumHeight: modifierListMaximumHeight))
                }

                if let rawSelectedElementJSON {
                    Divider()

                    DisclosureGroup(isExpanded: $rawNodeExpanded) {
                        ScrollView {
                            Text(rawSelectedElementJSON)
                                .font(.caption2.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 180)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.black.opacity(0.04))
                        )
                        .padding(.top, 6)
                    } label: {
                        HStack(spacing: 8) {
                            Text("Raw Node")
                                .font(.subheadline.weight(.semibold))
                            Spacer(minLength: 0)
                            PanelBadge(text: rawNodeExpanded ? "Vises" : "Skjult")
                        }
                    }
                }
            }
        }
        .padding(10)
        .onAppear {
            refreshFromState()
        }
        .onChange(of: editorState.selectedNodePath) { _, _ in
            refreshFromState()
        }
        .onChange(of: editorState.revision) { _, _ in
            refreshFromState()
        }

        Group {
            if let preferredWidth {
                content
                    .frame(width: preferredWidth)
            } else {
                content
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .modifier(PanelHeightModifier(maximumHeight: maximumHeight))
        .modifier(PanelBackgroundModifier(showsBackground: showsBackground))
    }

    @ViewBuilder
    private var bindingContextSection: some View {
        if !references.isEmpty {
            Text("Bindings")
                .font(.subheadline.weight(.semibold))

            if matchingReferences.isEmpty {
                Text("Valgt node bruker ingen top-level references.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(matchingReferences.enumerated()), id: \.offset) { _, reference in
                            ReferenceSummaryCard(reference: reference)
                        }
                    }
                }
                .frame(maxHeight: 150)
            }

            Divider()
        }
    }

    @ViewBuilder
    private var parameterSection: some View {
        Text("Parameters")
            .font(.subheadline.weight(.semibold))

        HStack(spacing: 8) {
            Picker("Add Parameter", selection: $addParameterSelection) {
                Text("Select").tag(Optional<SkeletonElementParameterKey>.none)
                ForEach(addableParameterKeys) { key in
                    Text(key.title).tag(Optional(key))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            Button("Add") {
                guard let key = addParameterSelection else { return }
                addParameter(key)
            }
            .disabled(addParameterSelection == nil)
        }

        if activeParameterKeys.isEmpty {
            Text("No parameters on selected element")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(activeParameterKeys) { key in
                        parameterRow(for: key)
                    }
                }
            }
            .frame(maxHeight: 170)
        }

        Divider()
    }

    @ViewBuilder
    private func parameterRow(for key: SkeletonElementParameterKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(key.title)
                    .font(.caption)
                Spacer()

                let removable = selectedElement.map { key.canRemove(on: $0) } ?? false
                Button(role: .destructive) {
                    removeParameter(key)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .font(.caption)
                .disabled(!removable)
            }

            switch key.valueKind {
            case .bool:
                Toggle(
                    "Enabled",
                    isOn: Binding(
                        get: {
                            selectedElement.flatMap { key.boolValue(on: $0) } ?? false
                        },
                        set: { newValue in
                            updateSelectedElement { element in
                                key.set(bool: newValue, on: &element)
                            }
                        }
                    )
                )
                .font(.caption)
            case .double, .string:
                HStack(spacing: 8) {
                    TextField(
                        "Value",
                        text: Binding(
                            get: {
                                if let draft = parameterValueDrafts[key] {
                                    return draft
                                }
                                guard let selectedElement else { return "" }
                                return key.textValue(on: selectedElement) ?? ""
                            },
                            set: { newValue in
                                parameterValueDrafts[key] = newValue
                                invalidParameterDrafts.remove(key)
                            }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onSubmit {
                        applyParameterValueDraft(for: key)
                    }

                    Button("Set") {
                        applyParameterValueDraft(for: key)
                    }
                    .font(.caption)
                }
            }

            if invalidParameterDrafts.contains(key) {
                Text("Invalid value for \(key.title)")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.04))
        )
    }

    @ViewBuilder
    private func modifierRow(for key: SkeletonModifierKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(key.title)
                    .font(.caption)
                Spacer()
                Button(role: .destructive) {
                    removeModifier(key)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .font(.caption)
            }

            switch key.valueKind {
            case .bool:
                Toggle(
                    "Enabled",
                    isOn: Binding(
                        get: {
                            key.boolValue(in: selectedModifiers) ?? false
                        },
                        set: { newValue in
                            updateSelectedModifiers { modifiers in
                                key.set(bool: newValue, in: &modifiers)
                            }
                        }
                    )
                )
                .font(.caption)

            case .double, .int, .string:
                HStack(spacing: 8) {
                    TextField(
                        "Value",
                        text: Binding(
                            get: {
                                valueDrafts[key] ?? key.textValue(in: selectedModifiers) ?? ""
                            },
                            set: { newValue in
                                valueDrafts[key] = newValue
                                invalidDrafts.remove(key)
                            }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onSubmit {
                        applyValueDraft(for: key)
                    }

                    Button("Set") {
                        applyValueDraft(for: key)
                    }
                    .font(.caption)
                }
            }

            if invalidDrafts.contains(key) {
                Text("Invalid value for \(key.title)")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.04))
        )
    }

    private func addParameter(_ key: SkeletonElementParameterKey) {
        updateSelectedElement { element in
            key.setDefault(on: &element)
        }
        addParameterSelection = addableParameterKeys.first
    }

    private func removeParameter(_ key: SkeletonElementParameterKey) {
        guard let selectedElement, key.canRemove(on: selectedElement) else { return }
        updateSelectedElement { element in
            key.clear(on: &element)
        }
        parameterValueDrafts.removeValue(forKey: key)
        invalidParameterDrafts.remove(key)
        if addParameterSelection == nil {
            addParameterSelection = addableParameterKeys.first
        }
    }

    private func applyParameterValueDraft(for key: SkeletonElementParameterKey) {
        let draft = (parameterValueDrafts[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        switch key.valueKind {
        case .bool:
            return
        case .double:
            guard let value = parseDouble(draft) else {
                invalidParameterDrafts.insert(key)
                return
            }
            updateSelectedElement { element in
                key.set(double: value, on: &element)
            }
            invalidParameterDrafts.remove(key)
        case .string:
            var isValid = false
            updateSelectedElement { element in
                isValid = key.set(string: draft, on: &element)
            }
            if isValid {
                invalidParameterDrafts.remove(key)
            } else {
                invalidParameterDrafts.insert(key)
            }
        }
    }

    private func addModifier(_ key: SkeletonModifierKey) {
        updateSelectedModifiers { modifiers in
            key.setDefault(in: &modifiers)
        }
        addSelection = addableKeys.first
    }

    private func removeModifier(_ key: SkeletonModifierKey) {
        updateSelectedModifiers { modifiers in
            key.clear(in: &modifiers)
        }
        valueDrafts.removeValue(forKey: key)
        invalidDrafts.remove(key)
        if addSelection == nil {
            addSelection = addableKeys.first
        }
    }

    private func applyValueDraft(for key: SkeletonModifierKey) {
        let draft = (valueDrafts[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        switch key.valueKind {
        case .string:
            updateSelectedModifiers { modifiers in
                key.set(string: draft, in: &modifiers)
            }
            invalidDrafts.remove(key)
        case .double:
            guard let value = parseDouble(draft) else {
                invalidDrafts.insert(key)
                return
            }
            updateSelectedModifiers { modifiers in
                key.set(double: value, in: &modifiers)
            }
            invalidDrafts.remove(key)
        case .int:
            guard let value = Int(draft) else {
                invalidDrafts.insert(key)
                return
            }
            updateSelectedModifiers { modifiers in
                key.set(int: value, in: &modifiers)
            }
            invalidDrafts.remove(key)
        case .bool:
            break
        }
    }

    private func updateSelectedModifiers(_ mutate: (inout SkeletonModifiers) -> Void) {
        guard let path = selectedPath else { return }
        editorState.updateModifier(at: path, mutate: mutate)
    }

    private func updateSelectedElement(_ mutate: (inout SkeletonElement) -> Void) {
        guard let path = selectedPath else { return }
        editorState.updateElement(at: path, mutate: mutate)
    }

    private func refreshFromState() {
        addParameterSelection = addableParameterKeys.first
        var updatedParameterDrafts: [SkeletonElementParameterKey: String] = [:]
        if let selectedElement {
            for key in activeParameterKeys where key.valueKind == .string || key.valueKind == .double {
                updatedParameterDrafts[key] = key.textValue(on: selectedElement) ?? ""
            }
        }
        parameterValueDrafts = updatedParameterDrafts
        invalidParameterDrafts.removeAll()

        let active = activeKeys
        addSelection = addableKeys.first

        var updatedDrafts: [SkeletonModifierKey: String] = [:]
        for key in active {
            if key.valueKind == .string || key.valueKind == .double || key.valueKind == .int {
                updatedDrafts[key] = key.textValue(in: selectedModifiers) ?? ""
            }
        }
        valueDrafts = updatedDrafts
        invalidDrafts.removeAll()
    }

    private func parseDouble(_ text: String) -> Double? {
        if let value = Double(text) {
            return value
        }
        return Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private func prettyPrint<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(value)
    }
}

private struct PanelHeightModifier: ViewModifier {
    let maximumHeight: CGFloat?

    func body(content: Content) -> some View {
        if let maximumHeight {
            content.frame(maxHeight: maximumHeight, alignment: .topLeading)
        } else {
            content
        }
    }
}

private struct PanelBackgroundModifier: ViewModifier {
    let showsBackground: Bool

    func body(content: Content) -> some View {
        if showsBackground {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            content
        }
    }
}

private struct ReferenceSummaryCard: View {
    let reference: CellReference
    var statusBadge: String? = nil
    var statusTint: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(reference.editorDisplayLabel)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let statusBadge {
                    PanelBadge(text: statusBadge, tint: statusTint)
                }
            }

            Text(reference.endpoint)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(2)

            HStack(spacing: 6) {
                PanelBadge(
                    text: reference.subscribeFeed ? "Feed" : "Snapshot",
                    tint: reference.subscribeFeed ? .accentColor : .secondary
                )

                if !reference.subscriptions.isEmpty {
                    PanelBadge(text: "\(reference.subscriptions.count) subs")
                }

                if !reference.setKeysAndValues.isEmpty {
                    PanelBadge(text: "\(reference.setKeysAndValues.count) set")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.04))
        )
        .opacity(statusBadge == nil ? 1 : 0.82)
    }
}

struct PanelBadge: View {
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption2.monospacedDigit())
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }
}

private extension CellReference {
    var editorTrimmedLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var editorDisplayLabel: String {
        let trimmed = editorTrimmedLabel
        return trimmed.isEmpty ? "(unlabeled)" : trimmed
    }
}

enum SkeletonInsertElementKind: String, CaseIterable, Identifiable {
    case text
    case textField
    case textArea
    case image
    case spacer
    case button
    case divider
    case toggle
    case hStack
    case vStack
    case zStack
    case scrollView
    case section
    case grid
    case list
    case picker
    case object
    case reference

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: return "Text"
        case .textField: return "TextField"
        case .textArea: return "TextArea"
        case .image: return "Image"
        case .spacer: return "Spacer"
        case .button: return "Button"
        case .divider: return "Divider"
        case .toggle: return "Toggle"
        case .hStack: return "HStack"
        case .vStack: return "VStack"
        case .zStack: return "ZStack"
        case .scrollView: return "ScrollView"
        case .section: return "Section"
        case .grid: return "Grid"
        case .list: return "List"
        case .picker: return "Picker"
        case .object: return "Object"
        case .reference: return "Reference"
        }
    }

    func makeElement() -> SkeletonElement {
        switch self {
        case .text:
            return .Text(SkeletonText(text: "New text"))
        case .textField:
            return .TextField(
                SkeletonTextField(
                    text: "",
                    sourceKeypath: "input.value",
                    targetKeypath: "input.value",
                    placeholder: "Input"
                )
            )
        case .textArea:
            return .TextArea(
                SkeletonTextArea(
                    text: nil,
                    sourceKeypath: "input.body",
                    targetKeypath: "input.body",
                    placeholder: "Write here"
                )
            )
        case .image:
            return .Image(SkeletonImage(name: "photo"))
        case .spacer:
            return .Spacer(SkeletonSpacer())
        case .button:
            return .Button(SkeletonButton(keypath: "action", label: "Button"))
        case .divider:
            return .Divider(SkeletonDivider())
        case .toggle:
            return .Toggle(SkeletonToggle(label: "Toggle", keypath: "toggle.value"))
        case .hStack:
            return .HStack(SkeletonHStack(elements: []))
        case .vStack:
            return .VStack(SkeletonVStack(elements: []))
        case .zStack:
            return .ZStack(SkeletonZStack(elements: []))
        case .scrollView:
            return .ScrollView(SkeletonScrollView(axis: nil, elements: []))
        case .section:
            return .Section(SkeletonSection(content: []))
        case .grid:
            return .Grid(
                SkeletonGrid(
                    columns: [.flexible(min: 80)],
                    spacing: 8,
                    elements: []
                )
            )
        case .list:
            return .List(SkeletonList(topic: nil, keypath: nil, flowElementSkeleton: nil))
        case .picker:
            return .Picker(SkeletonPicker(label: "Select", placeholder: "Choose", elements: []))
        case .object:
            return .Object(.empty())
        case .reference:
            return .Reference(SkeletonCellReference(keypath: "cell:///Porthole", topic: "default"))
        }
    }
}
