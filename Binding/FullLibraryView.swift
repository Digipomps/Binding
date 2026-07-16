import SwiftUI
import Combine
import CellBase
import CellApple

nonisolated enum FullLibraryInsertionIntent: String {
    case root
    case component
    case both
    case unknown
}

nonisolated struct FullLibraryQueryContext {
    var editMode: Bool
    var selectedNodeKind: String?
    var insertionIntent: FullLibraryInsertionIntent
}

nonisolated enum LibraryPreviewSkeletonSupport {
    struct PreparedPreview {
        var element: SkeletonElement
        var usesPlaceholders: Bool
    }

    static func preparePreview(for configuration: CellConfiguration) -> PreparedPreview? {
        guard let skeleton = configuration.skeleton else { return nil }
        return sanitize(skeleton)
    }

    private static func sanitize(_ element: SkeletonElement) -> PreparedPreview {
        switch element {
        case .Text(var text):
            var usedPlaceholder = false
            if text.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                text.text = previewLabel(from: text.keypath)
                    ?? previewLabel(from: text.url?.absoluteString)
                    ?? "Preview data"
                usedPlaceholder = true
            }
            if text.keypath != nil || text.url != nil {
                usedPlaceholder = true
            }
            text.keypath = nil
            text.url = nil
            return PreparedPreview(element: .Text(text), usesPlaceholders: usedPlaceholder)

        case .AttachmentField(let attachment):
            return placeholderCollection(
                title: attachment.title ?? attachment.emptyTitle ?? "Attachment field",
                detail: attachment.emptyMessage ?? attachment.helperText ?? "Native attach/drop surface preview.",
                modifiers: attachment.modifiers
            )

        case .FileUpload(let fileUpload):
            return placeholderCollection(
                title: fileUpload.title ?? fileUpload.emptyTitle ?? "File upload",
                detail: fileUpload.emptyMessage ?? fileUpload.helperText ?? "Native file picker/drop surface preview.",
                modifiers: fileUpload.modifiers
            )

        case .TextField(let field):
            let previewText = previewFieldText(
                text: field.text,
                placeholder: field.placeholder,
                preferredBinding: field.sourceKeypath ?? field.targetKeypath
            )
            let preview = SkeletonTextField(
                text: previewText,
                sourceKeypath: nil,
                targetKeypath: nil,
                placeholder: field.placeholder,
                modifiers: field.modifiers
            )
            return PreparedPreview(
                element: .TextField(preview),
                usesPlaceholders: field.sourceKeypath != nil || field.targetKeypath != nil
            )

        case .TextArea(let area):
            let previewText = previewFieldText(
                text: area.text,
                placeholder: area.placeholder,
                preferredBinding: area.sourceKeypath ?? area.targetKeypath
            )
            let preview = SkeletonTextArea(
                text: previewText,
                sourceKeypath: nil,
                targetKeypath: nil,
                placeholder: area.placeholder,
                minLines: area.minLines,
                maxLines: area.maxLines,
                submitOnEnter: area.submitOnEnter,
                modifiers: area.modifiers
            )
            return PreparedPreview(
                element: .TextArea(preview),
                usesPlaceholders: area.sourceKeypath != nil || area.targetKeypath != nil
            )

        case .HStack(let stack):
            let sanitizedChildren = sanitize(stack.elements)
            return PreparedPreview(
                element: .HStack(
                    SkeletonHStack(
                        elements: sanitizedChildren.map(\.element),
                        spacing: stack.spacing,
                        modifiers: stack.modifiers
                    )
                ),
                usesPlaceholders: sanitizedChildren.contains(where: \.usesPlaceholders)
            )

        case .VStack(let stack):
            let sanitizedChildren = sanitize(stack.elements)
            return PreparedPreview(
                element: .VStack(
                    SkeletonVStack(
                        elements: sanitizedChildren.map(\.element),
                        spacing: stack.spacing,
                        modifiers: stack.modifiers
                    )
                ),
                usesPlaceholders: sanitizedChildren.contains(where: \.usesPlaceholders)
            )

        case .ScrollView(let scroll):
            let sanitizedChildren = sanitize(scroll.elements)
            return PreparedPreview(
                element: .ScrollView(
                    SkeletonScrollView(
                        axis: scroll.axis,
                        elements: sanitizedChildren.map(\.element)
                    )
                ),
                usesPlaceholders: sanitizedChildren.contains(where: \.usesPlaceholders)
            )

        case .Section(let section):
            let header = section.header.map(sanitize)
            let footer = section.footer.map(sanitize)
            let content = sanitize(section.content)
            return PreparedPreview(
                element: .Section(
                    SkeletonSection(
                        header: header?.element,
                        footer: footer?.element,
                        content: content.map(\.element)
                    )
                ),
                usesPlaceholders:
                    (header?.usesPlaceholders ?? false) ||
                    (footer?.usesPlaceholders ?? false) ||
                    content.contains(where: \.usesPlaceholders)
            )

        case .ZStack(let stack):
            let sanitizedChildren = sanitize(stack.elements)
            return PreparedPreview(
                element: .ZStack(
                    SkeletonZStack(
                        elements: sanitizedChildren.map(\.element),
                        modifiers: stack.modifiers
                    )
                ),
                usesPlaceholders: sanitizedChildren.contains(where: \.usesPlaceholders)
            )

        case .Object(let object):
            var sanitizedChildren: SkeletonElementObject = [:]
            var usesPlaceholders = false
            for (key, child) in object.elements {
                let sanitizedChild = sanitize(child)
                sanitizedChildren[key] = sanitizedChild.element
                usesPlaceholders = usesPlaceholders || sanitizedChild.usesPlaceholders
            }
            return PreparedPreview(
                element: .Object(SkeletonObject(elements: sanitizedChildren, modifiers: object.modifiers)),
                usesPlaceholders: usesPlaceholders
            )

        case .List(let list):
            return placeholderCollection(
                title: previewLabel(from: list.keypath) ?? "Preview list",
                detail: "Viser statiske eksempelrader i biblioteket.",
                modifiers: list.modifiers
            )

        case .Grid(let grid):
            if !grid.elements.isEmpty {
                let sanitizedChildren = sanitize(grid.elements)
                let previewGrid = SkeletonGrid(
                    columns: grid.columns,
                    spacing: grid.spacing,
                    keypath: nil,
                    itemSkeleton: nil,
                    elements: sanitizedChildren.map(\.element),
                    modifiers: grid.modifiers
                )
                return PreparedPreview(
                    element: .Grid(previewGrid),
                    usesPlaceholders: sanitizedChildren.contains(where: \.usesPlaceholders)
                )
            }
            return placeholderCollection(
                title: previewLabel(from: grid.keypath) ?? "Preview grid",
                detail: "Viser statiske eksempelkort i biblioteket.",
                modifiers: grid.modifiers
            )

        case .Reference(let reference):
            return PreparedPreview(
                element: .Text(
                    previewText(
                        "Preview reference",
                        subtitle: previewLabel(from: reference.keypath) ?? reference.topic,
                        modifiers: reference.modifiers
                    )
                ),
                usesPlaceholders: true
            )

        case .Toggle(let toggle):
            return PreparedPreview(
                element: .Text(
                    previewText(
                        toggle.label,
                        subtitle: "Statisk toggle-preview",
                        modifiers: toggle.modifiers
                    )
                ),
                usesPlaceholders: true
            )

        case .Picker(let picker):
            return placeholderCollection(
                title: picker.label ?? picker.placeholder ?? "Preview picker",
                detail: previewLabel(from: picker.keypath) ?? "Statisk valgpreview i biblioteket.",
                modifiers: picker.modifiers
            )

        case .Tabs(let tabs):
            var usesPlaceholders = false
            let sanitizedPanels = tabs.panels.map { panel in
                let sanitizedContent = sanitize(panel.content)
                usesPlaceholders = usesPlaceholders || sanitizedContent.contains(where: \.usesPlaceholders)
                return SkeletonTabPanel(
                    id: panel.id,
                    content: sanitizedContent.map(\.element),
                    modifiers: panel.modifiers
                )
            }
            return PreparedPreview(
                element: .Tabs(
                    SkeletonTabs(
                        id: tabs.id,
                        tabsKeypath: nil,
                        activeTabStateKeypath: tabs.activeTabStateKeypath,
                        selectionActionKeypath: nil,
                        idKeypath: tabs.idKeypath,
                        labelKeypath: tabs.labelKeypath,
                        panels: sanitizedPanels,
                        modifiers: tabs.modifiers
                    )
                ),
                usesPlaceholders:
                    usesPlaceholders ||
                    tabs.tabsKeypath != nil ||
                    tabs.selectionActionKeypath != nil
            )

        case .Visualization(let visualization):
            return placeholderCollection(
                title: "Preview \(visualization.kind)",
                detail: previewLabel(from: visualization.keypath) ?? "Statisk visualiseringspreview i biblioteket.",
                modifiers: visualization.modifiers
            )

        case .Unsupported(let unsupported):
            return placeholderCollection(
                title: "Unsupported \(unsupported.elementType)",
                detail: unsupported.reason ?? "Skeleton-elementet kan ikke rendres av denne HAVEN-versjonen.",
                modifiers: unsupported.modifiers
            )

        case .Image(var image):
            let hadRemoteImage = image.url != nil
            if image.url != nil && image.name == nil {
                image.url = nil
                image.type = "system"
                image.name = "photo"
            } else {
                image.url = nil
            }
            return PreparedPreview(
                element: .Image(image),
                usesPlaceholders: hadRemoteImage
            )

        case .Button(let button):
            return PreparedPreview(element: .Button(button), usesPlaceholders: false)

        case .Divider(let divider):
            return PreparedPreview(element: .Divider(divider), usesPlaceholders: false)

        case .Spacer(let spacer):
            return PreparedPreview(element: .Spacer(spacer), usesPlaceholders: false)
        }
    }

    private static func sanitize(_ elements: SkeletonElementList) -> [PreparedPreview] {
        elements.map(sanitize)
    }

    private static func placeholderCollection(
        title: String,
        detail: String,
        modifiers: SkeletonModifiers?
    ) -> PreparedPreview {
        var containerModifiers = modifiers ?? SkeletonModifiers()
        if containerModifiers.padding == nil {
            containerModifiers.padding = 8
        }
        if containerModifiers.cornerRadius == nil {
            containerModifiers.cornerRadius = 12
        }
        if containerModifiers.background == nil {
            containerModifiers.background = "#F8FAFC"
        }
        if containerModifiers.borderWidth == nil {
            containerModifiers.borderWidth = 1
        }
        if containerModifiers.borderColor == nil {
            containerModifiers.borderColor = "#D7E2EE"
        }

        return PreparedPreview(
            element: .VStack(
                SkeletonVStack(
                    elements: [
                        .Text(previewText(title, modifiers: previewTitleModifiers())),
                        .Text(previewText(detail, modifiers: previewDetailModifiers())),
                        .Text(previewText("Eksempelrad 1", modifiers: previewRowModifiers())),
                        .Text(previewText("Eksempelrad 2", modifiers: previewRowModifiers())),
                        .Text(previewText("Eksempelrad 3", modifiers: previewRowModifiers()))
                    ],
                    spacing: 6,
                    modifiers: containerModifiers
                )
            ),
            usesPlaceholders: true
        )
    }

    private static func previewFieldText(text: String?, placeholder: String?, preferredBinding: String?) -> String {
        if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }
        if let placeholder, !placeholder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return placeholder
        }
        return previewLabel(from: preferredBinding) ?? "Preview input"
    }

    private static func previewLabel(from binding: String?) -> String? {
        guard let binding else { return nil }
        let trimmed = binding.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let source: String
        if let url = URL(string: trimmed), !url.path.isEmpty {
            source = url.lastPathComponent
        } else {
            source = trimmed
                .split(whereSeparator: { $0 == "." || $0 == "/" || $0 == "[" || $0 == "]" })
                .last
                .map(String.init) ?? trimmed
        }

        let spaced = source.unicodeScalars.reduce(into: "") { partial, scalar in
            if CharacterSet.uppercaseLetters.contains(scalar), !partial.isEmpty {
                partial.append(" ")
            }
            partial.append(Character(scalar))
        }

        let cleaned = spaced
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }

    private static func previewText(_ text: String, subtitle: String? = nil, modifiers: SkeletonModifiers? = nil) -> SkeletonText {
        var preview = SkeletonText(text: subtitle.map { "\(text): \($0)" } ?? text)
        preview.modifiers = modifiers
        return preview
    }

    private static func previewTitleModifiers() -> SkeletonModifiers {
        var modifiers = SkeletonModifiers()
        modifiers.fontWeight = "semibold"
        modifiers.foregroundColor = "#0F172A"
        return modifiers
    }

    private static func previewDetailModifiers() -> SkeletonModifiers {
        var modifiers = SkeletonModifiers()
        modifiers.fontSize = 12
        modifiers.foregroundColor = "#64748B"
        return modifiers
    }

    private static func previewRowModifiers() -> SkeletonModifiers {
        var modifiers = SkeletonModifiers()
        modifiers.padding = 6
        modifiers.background = "#FFFFFF"
        modifiers.cornerRadius = 8
        modifiers.borderWidth = 1
        modifiers.borderColor = "#E2E8F0"
        modifiers.foregroundColor = "#334155"
        return modifiers
    }
}

struct FullLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bridgeStatusStore: BridgeConnectionStatusStore
    @StateObject private var model: FullLibraryViewModel
    @FocusState private var focusedField: FocusField?
    @State private var closeAfterInsert = true
    @State private var showAdvancedFilters = false

    private let onAddConfiguration: (CellConfiguration) -> Void
    private let onSetDemoStartConfiguration: ((CellConfiguration) -> Void)?
    private let onAddComponent: ((ComponentPaletteItem) -> Bool)?
    private let armedComponentID: String?
    private let onArmComponent: ((ComponentPaletteItem?) -> Void)?
    private let onComponentDragStateChange: ((ComponentPaletteItem?) -> Void)?

    private enum FocusField: Hashable {
        case query
        case token
    }

    init(
        catalogEndpoints: [String],
        queryContext: FullLibraryQueryContext,
        favorites: [CellConfiguration],
        templates: [CellConfiguration],
        onAddConfiguration: @escaping (CellConfiguration) -> Void,
        onSetDemoStartConfiguration: ((CellConfiguration) -> Void)? = nil,
        onAddComponent: ((ComponentPaletteItem) -> Bool)? = nil,
        armedComponentID: String? = nil,
        onArmComponent: ((ComponentPaletteItem?) -> Void)? = nil,
        onComponentDragStateChange: ((ComponentPaletteItem?) -> Void)? = nil
    ) {
        _model = StateObject(
            wrappedValue: FullLibraryViewModel(
                catalogEndpoints: catalogEndpoints,
                queryContext: queryContext,
                fallbackFavorites: favorites,
                fallbackTemplates: templates
            )
        )
        self.onAddConfiguration = onAddConfiguration
        self.onSetDemoStartConfiguration = onSetDemoStartConfiguration
        self.onAddComponent = onAddComponent
        self.armedComponentID = armedComponentID
        self.onArmComponent = onArmComponent
        self.onComponentDragStateChange = onComponentDragStateChange
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let compact = proxy.size.width < 980
                Group {
                    if compact {
                        ScrollView {
                            libraryBody(compact: true, includeFooter: false)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .padding(12)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .safeAreaInset(edge: .bottom) {
                            connectivityFooter
                                .padding(.horizontal, 12)
                                .padding(.bottom, 8)
                                .background(.ultraThinMaterial)
                        }
                    } else {
                        libraryBody(compact: false, includeFooter: true)
                            .padding(12)
                    }
                }
                .contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture().onEnded {
                        dismissKeyboard()
                    }
                )
            }
            .navigationTitle("Bibliotek")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        dismissKeyboard()
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .accessibilityLabel("Skjul tastatur")
                    }
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 1020, minHeight: 720)
#endif
        .onAppear {
            focusedField = .query
            Task {
                await model.refreshNow()
            }
        }
        .onChange(of: model.queryText) { _, _ in
            model.scheduleRefresh()
        }
        .onChange(of: model.selectedTab) { _, _ in
            model.scheduleRefresh()
        }
        .onChange(of: model.resourceBudget) { _, _ in
            model.scheduleRefresh()
        }
        .onChange(of: model.networkPolicy) { _, _ in
            model.scheduleRefresh()
        }
        .onChange(of: model.allowDegradedSources) { _, _ in
            model.scheduleRefresh()
        }
        .onChange(of: model.maxSources) { _, _ in
            model.scheduleRefresh()
        }
        .onDisappear {
            onComponentDragStateChange?(nil)
        }
    }

    @ViewBuilder
    private func libraryBody(compact: Bool, includeFooter: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            headerCard
            if let bridgeStatus = bridgeStatusStore.primaryStatus {
                BridgeStatusBanner(
                    status: bridgeStatus,
                    additionalCount: max(0, bridgeStatusStore.visibleStatuses.count - 1)
                )
            }
            actionBar(compact: compact)
            tabPicker
            searchBar(compact: compact)
            if !model.searchSuggestions.isEmpty {
                suggestionsRow
            }
            tokenBar
            if showAdvancedFilters {
                advancedControls(compact: compact)
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAdvancedFilters = true
                    }
                } label: {
                    Label("Vis avanserte filtre", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if case .unavailable(let reason) = model.availability, model.results.isEmpty {
                unavailableView(reason: reason)
            } else if compact {
                compactLayout
            } else {
                regularLayout
            }

            if includeFooter {
                connectivityFooter
            }
        }
    }

    private var tabPicker: some View {
        Picker("Biblioteksegment", selection: $model.selectedTab) {
            ForEach(FullLibraryViewModel.LibraryTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    private var headerCard: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "books.vertical")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Søk, filtrer, forhåndsvis og legg til.")
                    .font(.subheadline.weight(.semibold))
                Text("Start med søkefeltet. Bruk avanserte filtre ved behov.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func actionBar(compact: Bool) -> some View {
        Group {
            if compact {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Lukk etter legg til", isOn: $closeAfterInsert)
                        .toggleStyle(.switch)
                        .font(.caption)

                    HStack(spacing: 8) {
                        Button {
                            dismissKeyboard()
                            Task { await model.refreshNow() }
                        } label: {
                            Label("Oppdater", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isLoading)

                        Button("Lukk") {
                            dismissKeyboard()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Toggle("Lukk etter legg til", isOn: $closeAfterInsert)
                        .toggleStyle(.switch)
                        .font(.caption)

                    Spacer()

                    Button {
                        dismissKeyboard()
                        Task { await model.refreshNow() }
                    } label: {
                        Label("Oppdater", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.isLoading)

                    Button("Lukk") {
                        dismissKeyboard()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func searchBar(compact: Bool) -> some View {
        Group {
            if compact {
                VStack(alignment: .leading, spacing: 8) {
                    primarySearchField
                    HStack(spacing: 8) {
                        Button("Søk") {
                            dismissKeyboard()
                            Task { await model.refreshNow() }
                        }
                        .buttonStyle(.borderedProminent)

                        demoStartButton

                        Button {
                            showAdvancedFilters.toggle()
                        } label: {
                            Label(showAdvancedFilters ? "Skjul filtre" : "Avansert", systemImage: "slider.horizontal.3")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    primarySearchField
                    Button("Søk") {
                        dismissKeyboard()
                        Task { await model.refreshNow() }
                    }
                    .buttonStyle(.borderedProminent)

                    demoStartButton

                    Button {
                        showAdvancedFilters.toggle()
                    } label: {
                        Label(showAdvancedFilters ? "Skjul filtre" : "Avansert", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    @ViewBuilder
    private var demoStartButton: some View {
        Button("Start demo her") {
            guard let selected = model.selectedResult,
                  selected.componentItem == nil else { return }
            dismissKeyboard()
            onSetDemoStartConfiguration?(selected.configuration)
        }
        .buttonStyle(.bordered)
        .disabled(model.selectedResult == nil || model.selectedResult?.componentItem != nil || onSetDemoStartConfiguration == nil)
    }

    private var primarySearchField: some View {
        TextField("Søk i konfigurasjoner, tags eller beskrivelser", text: $model.queryText)
            .textFieldStyle(.roundedBorder)
            .focused($focusedField, equals: .query)
            .submitLabel(.search)
            .onSubmit {
                dismissKeyboard()
                Task { await model.refreshNow() }
            }
    }

    private var suggestionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.searchSuggestions) { suggestion in
                    Button(suggestion.label) {
                        model.applySuggestion(suggestion)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private var tokenBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if model.tokens.isEmpty {
                    Text("Ingen tokens valgt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.tokens) { token in
                        LibraryTokenChip(token: token) {
                            model.removeToken(token)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func advancedControls(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            tokenInputControls(compact: compact)
            sourcePolicyControls(compact: compact)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showAdvancedFilters = false
                }
            } label: {
                Label("Skjul avanserte filtre", systemImage: "chevron.up")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func tokenInputControls(compact: Bool) -> some View {
        Group {
            if compact {
                VStack(alignment: .leading, spacing: 8) {
                    tokenDraftField
                    addTokenButton
                }
            } else {
                HStack(spacing: 10) {
                    tokenDraftField
                    addTokenButton
                }
            }
        }
    }

    private var tokenDraftField: some View {
        TextField("Token: purpose:... / interest:...", text: $model.tokenDraft)
            .textFieldStyle(.roundedBorder)
            .focused($focusedField, equals: .token)
            .submitLabel(.done)
            .onSubmit {
                model.consumeTokenDraft()
                dismissKeyboard()
            }
    }

    private var addTokenButton: some View {
        Button {
            model.consumeTokenDraft()
            dismissKeyboard()
        } label: {
            Label("Legg til token", systemImage: "plus.circle")
        }
        .buttonStyle(.bordered)
    }

    private func sourcePolicyControls(compact: Bool) -> some View {
        DisclosureGroup("Kilde- og ressurspolicy") {
            VStack(alignment: .leading, spacing: 10) {
                if compact {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Network", selection: $model.networkPolicy) {
                            ForEach(FullLibraryViewModel.NetworkPolicy.allCases) { policy in
                                Text(policy.title).tag(policy)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Ressurs", selection: $model.resourceBudget) {
                            ForEach(FullLibraryViewModel.ResourceBudget.allCases) { budget in
                                Text(budget.title).tag(budget)
                            }
                        }
                        .pickerStyle(.menu)

                        Stepper(value: $model.maxSources, in: 1 ... 12) {
                            Text("Maks kilder: \(model.maxSources)")
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        Picker("Network", selection: $model.networkPolicy) {
                            ForEach(FullLibraryViewModel.NetworkPolicy.allCases) { policy in
                                Text(policy.title).tag(policy)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Ressurs", selection: $model.resourceBudget) {
                            ForEach(FullLibraryViewModel.ResourceBudget.allCases) { budget in
                                Text(budget.title).tag(budget)
                            }
                        }
                        .pickerStyle(.menu)

                        Stepper(value: $model.maxSources, in: 1 ... 12) {
                            Text("Maks kilder: \(model.maxSources)")
                        }
                    }
                }
                Toggle("Tillat degraderte kilder", isOn: $model.allowDegradedSources)
            }
            .font(.caption)
        }
        .font(.caption)
    }

    private var regularLayout: some View {
        HStack(alignment: .top, spacing: 12) {
            facetPanel
                .frame(minWidth: 230, maxWidth: 300, maxHeight: .infinity, alignment: .topLeading)
            resultsPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            previewPanel
                .frame(minWidth: 280, maxWidth: 360, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var compactLayout: some View {
        VStack(spacing: 12) {
            facetPanel
                .frame(minHeight: 160, maxHeight: 240)
            compactResultsPanel
            previewPanel
                .frame(minHeight: 180, maxHeight: 280)
        }
    }

    private var facetPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Fasetter")
                    .font(.headline)

                ForEach(model.facetSections) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.title)
                            .font(.subheadline.weight(.semibold))
                        ForEach(section.buckets.prefix(12)) { bucket in
                            let selected = model.isFacetSelected(key: section.key, value: bucket.value)
                            Button {
                                model.toggleFacet(key: section.key, value: bucket.value)
                            } label: {
                                HStack {
                                    Text(model.displayFacetValue(key: section.key, value: bucket.value))
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(bucket.count)")
                                        .font(.caption.monospacedDigit())
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(selected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.10))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var resultsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Resultater (\(model.results.count))")
                    .font(.headline)
                Spacer()
                if model.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            List(selection: $model.selectedResultID) {
                ForEach(model.results) { item in
                    draggableResultCard(for: item) {
                        resultRowContent(item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                model.selectedResultID = item.id
                            }
                            .contextMenu {
                                if item.componentItem != nil {
                                    Button(componentPlacementLabel(for: item)) {
                                        togglePlacement(for: item)
                                    }
                                }
                                Button(item.componentItem == nil ? "Legg til i Porthole" : "Sett inn i valgt layout") {
                                    applySelection(item)
                                }
                            }
                    }
                }
            }
            .listStyle(.plain)
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var compactResultsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Resultater (\(model.results.count))")
                    .font(.headline)
                Spacer()
                if model.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if model.results.isEmpty {
                Text("Ingen resultater ennå. Juster søk eller filtre.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(model.results) { item in
                        draggableResultCard(for: item) {
                            resultRowContent(item)
                                .padding(10)
                                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    model.selectedResultID = item.id
                                }
                                .onTapGesture(count: 2) {
                                    applySelection(item)
                                }
                                .contextMenu {
                                    if item.componentItem != nil {
                                        Button(componentPlacementLabel(for: item)) {
                                            togglePlacement(for: item)
                                        }
                                    }
                                    Button(item.componentItem == nil ? "Legg til i Porthole" : "Sett inn i valgt layout") {
                                        applySelection(item)
                                    }
                                }
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func resultRowContent(_ item: FullLibraryViewModel.SearchResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(item.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text(item.scoreLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if !item.summary.isEmpty {
                Text(item.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                ForEach(item.badges.prefix(4), id: \.self) { badge in
                    Text(badge)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.13), in: Capsule())
                }
                Spacer()
                if item.componentItem != nil {
                    Button(componentPlacementLabel(for: item)) {
                        togglePlacement(for: item)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Button(item.componentItem == nil ? "Legg til" : "Sett inn") {
                    applySelection(item)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Text("Route: \(item.route) · Source: \(item.sourceRef)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.headline)

            if let selected = model.selectedResult {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selected.displayName)
                            .font(.subheadline.weight(.semibold))
                        if !selected.summary.isEmpty {
                            Text(selected.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if selected.componentItem != nil {
                            HStack(spacing: 8) {
                                Button(componentPlacementLabel(for: selected)) {
                                    togglePlacement(for: selected)
                                }
                                .buttonStyle(.bordered)

                                Button("Sett inn i valgt layout") {
                                    applySelection(selected)
                                }
                                .buttonStyle(.borderedProminent)
                                .keyboardShortcut(.return, modifiers: [.command])
                            }
                            if let componentItem = selected.componentItem,
                               armedComponentID == componentItem.id {
                                Text("Plassering er aktiv. Lukk biblioteket og klikk et innsettingspunkt i lerretet.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Button("Legg til i Porthole") {
                                applySelection(selected)
                            }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.defaultAction)
                            .keyboardShortcut(.return, modifiers: [.command])
                        }

                        DisclosureGroup("Match diagnostics") {
                            VStack(alignment: .leading, spacing: 4) {
                                scoreRow("Text", selected.scoreBreakdown.text)
                                scoreRow("Purpose", selected.scoreBreakdown.purpose)
                                scoreRow("Interest", selected.scoreBreakdown.interest)
                                scoreRow("Compat", selected.scoreBreakdown.compatibility)
                                scoreRow("Conn", selected.scoreBreakdown.connectivity)
                                scoreRow("Resource", selected.scoreBreakdown.resourceFit)
                                scoreRow("Recency", selected.scoreBreakdown.recency)
                            }
                            .padding(.top, 4)
                        }
                        .font(.caption)

                        if let preparedPreview = LibraryPreviewSkeletonSupport.preparePreview(for: selected.configuration) {
                            HStack(spacing: 8) {
                                Text("Static skeleton preview")
                                    .font(.caption.weight(.semibold))
                                if preparedPreview.usesPlaceholders {
                                    Text("bindings/actions disabled")
                                        .font(.caption2.weight(.medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.secondary.opacity(0.12), in: Capsule())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            BindingSkeletonView(element: preparedPreview.element)
                                .allowsHitTesting(false)
                                .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 420, alignment: .topLeading)
                                .padding(8)
                                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            if preparedPreview.usesPlaceholders {
                                Text("Previewen viser statiske plassholdere for live data og actions.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Ingen skeleton-preview tilgjengelig.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            } else {
                Text("Velg en konfigurasjon for detaljer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var connectivityFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(model.statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if model.catalogMode != .unknown {
                    Text(model.catalogMode.label)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(model.catalogMode.tint.opacity(0.14), in: Capsule())
                        .foregroundStyle(model.catalogMode.tint)
                }
                Spacer()
                Text("Online \(model.connectivity.onlineSources) · Degraded \(model.connectivity.degradedSources) · Offline \(model.connectivity.offlineSources)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let warningSummaryText = model.warningSummaryText {
                Label {
                    Text(warningSummaryText)
                        .lineLimit(2)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.caption2)
                .foregroundStyle(.orange)
                .help(model.warningDetails.joined(separator: "\n"))
            }
        }
    }

    private func unavailableView(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Full Library er utilgjengelig akkurat nå.")
                .font(.headline)
            Text(reason)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !model.fallbackFavorites.isEmpty {
                fallbackSection("Favorites (cached/offline)", items: model.fallbackFavorites)
            }
            if !model.fallbackTemplates.isEmpty {
                fallbackSection("Templates/Bootstraps (cached/offline)", items: model.fallbackTemplates)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func fallbackSection(_ title: String, items: [CellConfiguration]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            ForEach(Array(items.prefix(8).enumerated()), id: \.offset) { _, configuration in
                HStack {
                    Text(configuration.name)
                        .font(.caption)
                    Spacer()
                    Button("Legg til") {
                        applySelection(configuration)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private func scoreRow(_ label: String, _ value: Double) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
            Spacer()
            Text(String(format: "%.2f", value))
                .font(.caption2.monospacedDigit())
        }
        .foregroundStyle(.secondary)
    }

    private func applySelection(_ configuration: CellConfiguration) {
        dismissKeyboard()
        onAddConfiguration(configuration)
        if closeAfterInsert {
            dismiss()
        }
    }

    private func applySelection(_ item: FullLibraryViewModel.SearchResult) {
        dismissKeyboard()

        if let componentItem = item.componentItem,
           let onAddComponent {
            let inserted = onAddComponent(componentItem)
            if inserted && closeAfterInsert {
                dismiss()
            }
            return
        }

        applySelection(item.configuration)
    }

    private func togglePlacement(for item: FullLibraryViewModel.SearchResult) {
        guard let componentItem = item.componentItem else { return }
        dismissKeyboard()
        onComponentDragStateChange?(nil)

        let shouldArm = armedComponentID != componentItem.id
        onArmComponent?(shouldArm ? componentItem : nil)

        if shouldArm {
            dismiss()
        }
    }

    private func componentPlacementLabel(for item: FullLibraryViewModel.SearchResult) -> String {
        guard let componentItem = item.componentItem else { return "Plasser" }
        return armedComponentID == componentItem.id ? "Avbryt plassering" : "Plasser"
    }

    @ViewBuilder
    private func draggableResultCard<Content: View>(
        for item: FullLibraryViewModel.SearchResult,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if let componentItem = item.componentItem {
            content()
                .draggable(componentItem) {
                    ComponentDragPreviewCard(
                        item: componentItem,
                        onActivate: { active in onComponentDragStateChange?(active) },
                        onDeactivate: { onComponentDragStateChange?(nil) }
                    )
                }
        } else {
            content()
                .draggable(item.configuration)
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
    }
}

@MainActor
final class FullLibraryViewModel: ObservableObject {
    struct WarningPresentation {
        var messages: [String]
        var details: [String]
    }

    enum LibraryTab: String, CaseIterable, Identifiable {
        case allConfigs
        case forMyPurposes
        case sources
        case templates

        var id: String { rawValue }

        var title: String {
            switch self {
            case .allConfigs: return "Alle konfigurasjoner"
            case .forMyPurposes: return "For mine formål"
            case .sources: return "Kilder"
            case .templates: return "Maler"
            }
        }
    }

    enum TokenKind: String, CaseIterable, Identifiable {
        case purpose
        case interest
        case category
        case source
        case compatibility
        case authRequired

        var id: String { rawValue }
    }

    struct Token: Identifiable, Hashable {
        var kind: TokenKind
        var value: String

        var id: String { "\(kind.rawValue)|\(value.lowercased())" }
        var label: String { "\(kind.rawValue):\(value)" }
    }

    struct FacetBucket: Identifiable {
        var facetKey: String
        var value: String
        var count: Int
        var exact: Bool

        var id: String { "\(facetKey)|\(value.lowercased())" }
    }

    struct FacetSection: Identifiable {
        var key: String
        var title: String
        var buckets: [FacetBucket]

        var id: String { key }
    }

    enum SuggestionAction {
        case addToken(Token)
        case setQuery(String)
        case toggleFacet(key: String, value: String)
    }

    struct SearchSuggestion: Identifiable {
        var id: String
        var label: String
        var action: SuggestionAction
    }

    struct ScoreBreakdown {
        var text: Double
        var purpose: Double
        var interest: Double
        var compatibility: Double
        var connectivity: Double
        var resourceFit: Double
        var recency: Double
    }

    struct SearchResult: Identifiable {
        var id: String
        var configurationId: String
        var displayName: String
        var summary: String
        var sourceRef: String
        var route: String
        var score: Double
        var scoreBreakdown: ScoreBreakdown
        var badges: [String]
        var configuration: CellConfiguration
        var componentItem: ComponentPaletteItem?

        var scoreLabel: String {
            String(format: "%.2f", score)
        }
    }

    struct ConnectivitySnapshot {
        var onlineSources: Int
        var degradedSources: Int
        var offlineSources: Int

        static let empty = ConnectivitySnapshot(onlineSources: 0, degradedSources: 0, offlineSources: 0)
    }

    enum Availability: Equatable {
        case unknown
        case available(endpoint: String)
        case unavailable(reason: String)
    }

    enum CatalogMode: Equatable {
        case unknown
        case fullQuery
        case directEntriesFallback

        var label: String {
            switch self {
            case .unknown: return "Ukjent"
            case .fullQuery: return "Full query"
            case .directEntriesFallback: return "Direct catalog fallback"
            }
        }

        var tint: Color {
            switch self {
            case .unknown: return .secondary
            case .fullQuery: return .green
            case .directEntriesFallback: return .orange
            }
        }
    }

    enum ResourceBudget: String, CaseIterable, Identifiable {
        case low
        case balanced
        case high

        var id: String { rawValue }
        var title: String {
            switch self {
            case .low: return "Lav"
            case .balanced: return "Balansert"
            case .high: return "Høy"
            }
        }
    }

    enum NetworkPolicy: String, CaseIterable, Identifiable {
        case preferHealthyThenCached
        case healthyOnly
        case cacheOnly

        var id: String { rawValue }
        var title: String {
            switch self {
            case .preferHealthyThenCached: return "Healthy + Cache"
            case .healthyOnly: return "Healthy only"
            case .cacheOnly: return "Cache only"
            }
        }
    }

    enum LibraryError: Error {
        case resolverUnavailable
        case identityUnavailable
        case catalogUnavailable
        case catalogCandidateTimedOut(String)
        case catalogOperationTimedOut(String, String)
    }

    private struct ResolvedCatalog {
        let catalog: Meddle
        let identity: Identity
        let endpoint: String
        let resolutionWarnings: [String]
    }

    private struct CachedQuerySnapshot {
        var endpoint: String
        var results: [SearchResult]
        var facetSections: [FacetSection]
        var connectivity: ConnectivitySnapshot
        var catalogMode: CatalogMode
        var storedAt: Date
    }

    @Published var selectedTab: LibraryTab = .allConfigs
    @Published var queryText: String = ""
    @Published var tokenDraft: String = ""
    @Published var tokens: [Token] = []
    @Published var facetSections: [FacetSection] = []
    @Published var selectedFacets: [String: Set<String>] = [:]
    @Published var results: [SearchResult] = []
    @Published var selectedResultID: String?
    @Published var isLoading: Bool = false
    @Published var statusLine: String = "Klar"
    @Published var warnings: [String] = []
    @Published var warningDetails: [String] = []
    @Published var connectivity: ConnectivitySnapshot = .empty
    @Published var availability: Availability = .unknown
    @Published var catalogMode: CatalogMode = .unknown

    @Published var resourceBudget: ResourceBudget = .balanced
    @Published var networkPolicy: NetworkPolicy = .preferHealthyThenCached
    @Published var allowDegradedSources: Bool = true
    @Published var maxSources: Int = 24

    let fallbackFavorites: [CellConfiguration]
    let fallbackTemplates: [CellConfiguration]

    private let catalogEndpoints: [String]
    private let queryContext: FullLibraryQueryContext
    private var refreshTask: Task<Void, Never>?
    private var bootstrapWatchTask: Task<Void, Never>?
    private var facetRefreshTask: Task<Void, Never>?
    private var catalogSyncTask: Task<Void, Never>?
    private var refreshGeneration = 0
    private var lastGoodCatalogEndpoint: String?
    private var queryCapableCatalogEndpoints: Set<String> = []
    private var queryResultCache: [String: CachedQuerySnapshot] = [:]
    private var rawWarnings: [String] = []

    init(
        catalogEndpoints: [String],
        queryContext: FullLibraryQueryContext,
        fallbackFavorites: [CellConfiguration],
        fallbackTemplates: [CellConfiguration]
    ) {
        self.catalogEndpoints = catalogEndpoints
        self.queryContext = queryContext
        self.fallbackFavorites = fallbackFavorites
        self.fallbackTemplates = fallbackTemplates
    }

    deinit {
        refreshTask?.cancel()
        bootstrapWatchTask?.cancel()
        facetRefreshTask?.cancel()
        catalogSyncTask?.cancel()
    }

    var selectedResult: SearchResult? {
        if let selectedResultID,
           let selected = results.first(where: { $0.id == selectedResultID }) {
            return selected
        }
        return results.first
    }

    func preferredSelectionID(
        in results: [SearchResult],
        currentSelectionID: String?
    ) -> String? {
        guard !results.isEmpty else { return nil }

        let trimmedQuery = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty,
           let bestQueryMatch = bestSelectionMatch(in: results, query: trimmedQuery) {
            return bestQueryMatch.id
        }

        if let currentSelectionID,
           results.contains(where: { $0.id == currentSelectionID }) {
            return currentSelectionID
        }

        return results.first?.id
    }

    var searchSuggestions: [SearchSuggestion] {
        var output: [SearchSuggestion] = []
        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            output.append(SearchSuggestion(
                id: "token-purpose-\(trimmed.lowercased())",
                label: "purpose:\(trimmed)",
                action: .addToken(Token(kind: .purpose, value: trimmed))
            ))
            output.append(SearchSuggestion(
                id: "token-interest-\(trimmed.lowercased())",
                label: "interest:\(trimmed)",
                action: .addToken(Token(kind: .interest, value: trimmed))
            ))
            output.append(SearchSuggestion(
                id: "query-\(trimmed.lowercased())",
                label: "Søk etter \"\(trimmed)\"",
                action: .setQuery(trimmed)
            ))
        }

        for section in facetSections.prefix(2) {
            for bucket in section.buckets.prefix(3) {
                output.append(SearchSuggestion(
                    id: "facet-\(section.key)-\(bucket.value.lowercased())",
                    label: "\(section.title): \(displayFacetValue(key: section.key, value: bucket.value))",
                    action: .toggleFacet(key: section.key, value: bucket.value)
                ))
            }
        }
        return output
    }

    func loadInitial() async {
        await refreshNow()
    }

    func scheduleRefresh() {
        refreshTask?.cancel()
        facetRefreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            await self?.refreshNow()
        }
    }

    func refreshNow() async {
        guard await ensureRuntimeBootstrapForLibrary() else {
            presentAuthPendingState()
            return
        }

        statusLine = "Laster ConfigurationCatalog..."
        isLoading = true
        facetRefreshTask?.cancel()
        refreshGeneration += 1
        let generation = refreshGeneration
        let querySignature = currentQuerySignature()
        if let cachedSnapshot = queryResultCache[querySignature],
           !cachedSnapshot.results.isEmpty {
            applyCachedQuerySnapshot(cachedSnapshot)
            let age = max(0, Int(Date().timeIntervalSince(cachedSnapshot.storedAt)))
            statusLine = "Viser siste treff fra cache (\(age)s) · oppdaterer..."
        }
        defer { isLoading = false }

        do {
            let resolved = try await runRefreshPhase(
                name: "resolveCatalog",
                timeoutNanoseconds: 2_500_000_000
            ) {
                try await self.resolveCatalog()
            }
            let catalog = resolved.catalog
            let identity = resolved.identity
            let endpoint = resolved.endpoint
            replaceWarnings(with: resolved.resolutionWarnings)
            catalogMode = .unknown
            let queryPayload = buildQueryPayload()
            let startedAt = Date()

            statusLine = "Henter katalogtreff..."
            let queryFastPath = shouldUseQueryFastPath(for: endpoint)
            let fallbackCatalogResultsTask: Task<[SearchResult]?, Never>? = queryFastPath
                ? nil
                : Task<[SearchResult]?, Never> {
                    await self.optionalCatalogOperation(
                        name: "catalogContracts",
                        endpoint: endpoint
                    ) {
                        try await self.directCatalogResults(from: catalog, requester: identity)
                    }
                }

            var usedQueryResponse = false
            let queryResponse: ValueType? = await optionalCatalogOperation(
                name: "query",
                endpoint: endpoint
            ) {
                guard let response = try await catalog.set(
                    keypath: "query",
                    value: .object(queryPayload),
                    requester: identity
                ) else {
                    throw LibraryError.catalogUnavailable
                }
                return response
            }
            if let queryResponse {
                usedQueryResponse = true
                parseQueryResponse(queryResponse)
                markQueryCapable(endpoint)
                catalogMode = .fullQuery
                availability = .available(endpoint: endpoint)
                lastGoodCatalogEndpoint = endpoint
                if !results.isEmpty {
                    storeQuerySnapshot(signature: querySignature, endpoint: endpoint)
                    fallbackCatalogResultsTask?.cancel()
                }
                let elapsed = Int(Date().timeIntervalSince(startedAt) * 1000.0)
                statusLine = "Kilde: \(endpoint) · \(results.count) treff · query \(elapsed)ms"
                scheduleFacetRefreshIfNeeded(
                    catalog: catalog,
                    identity: identity,
                    endpoint: endpoint,
                    queryPayload: queryPayload,
                    querySignature: querySignature,
                    generation: generation
                )
                scheduleCatalogSyncIfNeeded(catalog: catalog, identity: identity, endpoint: endpoint, generation: generation)
            } else if let fallbackCatalogResults = await directCatalogFallbackResults(
                from: fallbackCatalogResultsTask,
                catalog: catalog,
                requester: identity,
                endpoint: endpoint
            ), !fallbackCatalogResults.isEmpty {
                results = fallbackCatalogResults
                facetSections = deriveFacetSections(from: fallbackCatalogResults)
                appendWarning("Kilden støtter ikke katalog-query. Viser direkte katalogentries i stedet.")
                selectedResultID = preferredSelectionID(in: results, currentSelectionID: selectedResultID)
                catalogMode = .directEntriesFallback
                availability = .available(endpoint: endpoint)
                lastGoodCatalogEndpoint = endpoint
            } else {
                throw LibraryError.catalogUnavailable
            }

            let elapsed = Int(Date().timeIntervalSince(startedAt) * 1000.0)
            let fallbackCatalogResults: [SearchResult]?
            if !queryFastPath, results.isEmpty {
                fallbackCatalogResults = await fallbackCatalogResultsTask?.value
            } else {
                fallbackCatalogResultsTask?.cancel()
                fallbackCatalogResults = nil
            }
            if results.isEmpty, let fallbackCatalogResults, !fallbackCatalogResults.isEmpty {
                results = fallbackCatalogResults
                facetSections = deriveFacetSections(from: fallbackCatalogResults)
                if warnings.isEmpty {
                    replaceWarnings(with: ["Query svarte tomt. Viser direkte katalogentries i stedet."])
                }
                selectedResultID = preferredSelectionID(in: results, currentSelectionID: selectedResultID)
                connectivity = ConnectivitySnapshot(onlineSources: 1, degradedSources: 0, offlineSources: 0)
                statusLine = "Kilde: \(endpoint) · \(results.count) entries · direkte katalogvisning"
                catalogMode = .directEntriesFallback
            } else if !usedQueryResponse && results.isEmpty {
                let offlineResults = offlineFallbackResults()
                if !offlineResults.isEmpty {
                    results = offlineResults
                    facetSections = deriveFacetSections(from: offlineResults)
                    selectedResultID = preferredSelectionID(in: results, currentSelectionID: selectedResultID)
                    let fallbackWarning = "Katalogen svarte uten visbare treff. Viser lokal fallback i stedet."
                    if !rawWarnings.contains(fallbackWarning) {
                        appendWarning(fallbackWarning)
                    }
                    connectivity = ConnectivitySnapshot(onlineSources: 0, degradedSources: 1, offlineSources: 1)
                    statusLine = "Kilde: \(endpoint) · lokal fallback · \(offlineResults.count) entries"
                    catalogMode = .directEntriesFallback
                } else {
                    statusLine = "Kilde: \(endpoint) · 0 treff · \(elapsed)ms"
                }
            } else {
                statusLine = "Kilde: \(endpoint) · \(results.count) treff · \(elapsed)ms"
            }
            availability = .available(endpoint: endpoint)
        } catch {
            if let cachedSnapshot = queryResultCache[querySignature],
               !cachedSnapshot.results.isEmpty {
                applyCachedQuerySnapshot(cachedSnapshot)
                availability = .unavailable(reason: "Kunne ikke nå ConfigurationCatalog. Viser siste query-cache.")
                statusLine = "Staging er utilgjengelig. Viser siste query-cache fra \(cachedSnapshot.endpoint)."
                appendWarning("Staging-katalogen svarte ikke. Viser siste query-cache i stedet.")
                return
            }
            let offlineResults = offlineFallbackResults()
            results = offlineResults
            facetSections = deriveFacetSections(from: offlineResults)
            selectedResultID = preferredSelectionID(in: results, currentSelectionID: selectedResultID)
            availability = .unavailable(reason: "Kunne ikke nå ConfigurationCatalog.")
            statusLine = offlineResults.isEmpty
                ? "Kun offline-cached favoritter/templates er tilgjengelig."
                : "Staging er utilgjengelig. Viser lokal cache med preview og filtre."
            if !offlineResults.isEmpty {
                replaceWarnings(with: ["Staging-katalogen svarte ikke. Viser lokal cache i stedet."])
            }
            catalogMode = offlineResults.isEmpty ? .unknown : .directEntriesFallback
            connectivity = ConnectivitySnapshot(onlineSources: 0, degradedSources: 0, offlineSources: 1)
        }
    }

    private var runtimeBootstrapIsReady: Bool {
        BindingRuntimeBootstrap.authenticatedRuntimeIsReady
    }

    private func ensureRuntimeBootstrapForLibrary() async -> Bool {
        if runtimeBootstrapIsReady {
            bootstrapWatchTask?.cancel()
            bootstrapWatchTask = nil
            await BindingLocalCellRegistration.shared.ensureRegistered()
            return true
        }

        if bootstrapWatchTask == nil {
            bootstrapWatchTask = Task { [weak self] in
                if !BindingRuntimeBootstrap.shouldUseLocalRuntimeOnlyForVerifier() {
                    await AppInitializer.initialize()
                }
                await BindingLocalCellRegistration.shared.ensureRegistered()
                await MainActor.run {
                    guard let self else { return }
                    self.bootstrapWatchTask = nil
                    guard self.runtimeBootstrapIsReady else { return }
                    Task { @MainActor [weak self] in
                        await self?.refreshNow()
                    }
                }
            }
        }

        return false
    }

    private func presentAuthPendingState() {
        let offlineResults = offlineFallbackResults()
        results = offlineResults
        facetSections = deriveFacetSections(from: offlineResults)
        selectedResultID = preferredSelectionID(in: offlineResults, currentSelectionID: selectedResultID)
        availability = .unavailable(
            reason: "Bekreft Touch ID, Face ID eller passkode for å laste Full Library. Lokale favoritter og konferanseoppsett vises mens vi venter."
        )
        statusLine = "Venter paa autentisering for ConfigurationCatalog…"
        replaceWarnings(with: [])
        connectivity = ConnectivitySnapshot(
            onlineSources: 0,
            degradedSources: 0,
            offlineSources: offlineResults.isEmpty ? 0 : 1
        )
        catalogMode = offlineResults.isEmpty ? .unknown : .directEntriesFallback
        isLoading = false
    }

    private func runCatalogOperation<T: Sendable>(
        name: String,
        endpoint: String,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let timeoutNanoseconds: UInt64 = RemoteCatalogSupport.isLocalCatalogEndpoint(endpoint)
            ? 1_200_000_000
            : 2_500_000_000

        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw LibraryError.catalogOperationTimedOut(endpoint, name)
            }

            guard let value = try await group.next() else {
                throw LibraryError.catalogOperationTimedOut(endpoint, name)
            }
            group.cancelAll()
            return value
        }
    }

    private func optionalCatalogOperation<T: Sendable>(
        name: String,
        endpoint: String,
        operation: @escaping @Sendable () async throws -> T
    ) async -> T? {
        do {
            return try await runCatalogOperation(
                name: name,
                endpoint: endpoint,
                operation: operation
            )
        } catch {
            return nil
        }
    }

    private func directCatalogFallbackResults(
        from existingTask: Task<[SearchResult]?, Never>?,
        catalog: Meddle,
        requester: Identity,
        endpoint: String
    ) async -> [SearchResult]? {
        if let existingTask {
            return await existingTask.value
        }

        return await optionalCatalogOperation(
            name: "catalogContracts",
            endpoint: endpoint
        ) {
            try await self.directCatalogResults(from: catalog, requester: requester)
        }
    }

    private func scheduleFacetRefreshIfNeeded(
        catalog: Meddle,
        identity: Identity,
        endpoint: String,
        queryPayload: Object,
        querySignature: String,
        generation: Int
    ) {
        guard !results.isEmpty else {
            facetSections = []
            return
        }

        if facetSections.isEmpty {
            facetSections = deriveFacetSections(from: results)
        }

        facetRefreshTask?.cancel()
        facetRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let facetPayload = self.buildFacetPayload(baseQuery: queryPayload)
            let facetResponse = await self.optionalCatalogOperation(
                name: "facetCounts",
                endpoint: endpoint
            ) {
                guard let response = try await catalog.set(
                    keypath: "facetCounts",
                    value: .object(facetPayload),
                    requester: identity
                ) else {
                    throw LibraryError.catalogUnavailable
                }
                return response
            }
            guard !Task.isCancelled, self.refreshGeneration == generation else { return }
            if let facetResponse {
                self.parseFacetResponse(facetResponse)
            } else {
                self.facetSections = self.deriveFacetSections(from: self.results)
                self.appendWarning("Kilden støtter ikke facetCounts. Viser lokale fasetter for treffene.")
            }
            self.storeQuerySnapshot(signature: querySignature, endpoint: endpoint)
        }
    }

    private func scheduleCatalogSyncIfNeeded(
        catalog: Meddle,
        identity: Identity,
        endpoint: String,
        generation: Int
    ) {
        guard RemoteCatalogSupport.shouldSyncCatalogBeforeQuery(for: endpoint) else { return }

        catalogSyncTask?.cancel()
        catalogSyncTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let syncResult: ValueType? = await self.optionalCatalogOperation(
                name: "sync",
                endpoint: endpoint
            ) {
                guard let response = try await catalog.set(
                    keypath: "syncScaffoldPurposeGoals",
                    value: .object([:]),
                    requester: identity
                ) else {
                    throw LibraryError.catalogUnavailable
                }
                return response
            }
            guard !Task.isCancelled, self.refreshGeneration == generation else { return }
            if syncResult == nil {
                self.appendWarning(self.syncWarning(for: endpoint, error: LibraryError.catalogOperationTimedOut(endpoint, "sync")))
            }
        }
    }

    private func storeQuerySnapshot(signature: String, endpoint: String) {
        guard !results.isEmpty else { return }
        queryResultCache[signature] = CachedQuerySnapshot(
            endpoint: endpoint,
            results: results,
            facetSections: facetSections,
            connectivity: connectivity,
            catalogMode: catalogMode,
            storedAt: Date()
        )
    }

    private func applyCachedQuerySnapshot(_ snapshot: CachedQuerySnapshot) {
        results = snapshot.results
        facetSections = snapshot.facetSections
        connectivity = snapshot.connectivity
        catalogMode = snapshot.catalogMode
        selectedResultID = preferredSelectionID(in: snapshot.results, currentSelectionID: selectedResultID)
    }

    private func shouldUseQueryFastPath(for endpoint: String) -> Bool {
        let key = normalizedEndpointKey(endpoint)
        return queryCapableCatalogEndpoints.contains(key)
            || normalizedEndpointKey(lastGoodCatalogEndpoint) == key
            || endpointLooksQueryCapable(endpoint)
    }

    private func markQueryCapable(_ endpoint: String) {
        queryCapableCatalogEndpoints.insert(normalizedEndpointKey(endpoint))
    }

    private func endpointLooksQueryCapable(_ endpoint: String) -> Bool {
        if RemoteCatalogSupport.isLocalCatalogEndpoint(endpoint) {
            return true
        }
        guard let components = URLComponents(string: endpoint) else {
            return false
        }
        let path = components.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
        return path.split(separator: "/").last.map(String.init) == "configurationcatalog"
    }

    private func normalizedEndpointKey(_ endpoint: String?) -> String {
        endpoint?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private func currentQuerySignature() -> String {
        let tokenSignature = tokensForRequest()
            .map { "\($0.kind.rawValue)=\($0.value.lowercased())" }
            .sorted()
            .joined(separator: ",")
        let facetSignature = selectedFacets
            .map { key, values in
                "\(key)=\(values.map { $0.lowercased() }.sorted().joined(separator: ","))"
            }
            .sorted()
            .joined(separator: "|")
        return [
            "tab=\(selectedTab.rawValue)",
            "q=\(defaultQueryTextForTab().lowercased())",
            "tokens=\(tokenSignature)",
            "facets=\(facetSignature)",
            "edit=\(queryContext.editMode)",
            "node=\(queryContext.selectedNodeKind ?? "")",
            "intent=\(queryContext.insertionIntent.rawValue)",
            "budget=\(resourceBudget.rawValue)",
            "policy=\(networkPolicy.rawValue)",
            "degraded=\(allowDegradedSources)",
            "max=\(maxSources)"
        ].joined(separator: ";;")
    }

    private func runRefreshPhase<T: Sendable>(
        name: String,
        timeoutNanoseconds: UInt64,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw LibraryError.catalogOperationTimedOut("refresh", name)
            }

            guard let value = try await group.next() else {
                throw LibraryError.catalogOperationTimedOut("refresh", name)
            }
            group.cancelAll()
            return value
        }
    }

    private func syncWarning(for endpoint: String, error: Error) -> String {
        if case let LibraryError.catalogOperationTimedOut(_, operation) = error,
           operation == "sync" {
            if RemoteCatalogSupport.isLocalCatalogEndpoint(endpoint) {
                return "Lokal katalogoppdatering tok for lang tid. Viser lagrede katalogdata i stedet."
            }
            return "Katalogoppdatering mot \(endpoint) tok for lang tid. Viser eksisterende data."
        }
        if RemoteCatalogSupport.isLocalCatalogEndpoint(endpoint) {
            return "Lokal katalogoppdatering feilet. Viser lagrede katalogdata i stedet."
        }
        return "Katalogoppdatering mot \(endpoint) feilet. Viser eksisterende data."
    }

    func consumeTokenDraft() {
        let raw = tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        tokenDraft = ""

        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        if parts.count == 2 {
            let kindValue = parts[0].lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return }
            if let token = makeToken(kindValue: kindValue, value: value) {
                addToken(token)
                return
            }
        }

        queryText = raw
        scheduleRefresh()
    }

    func applySuggestion(_ suggestion: SearchSuggestion) {
        switch suggestion.action {
        case .addToken(let token):
            addToken(token)
        case .setQuery(let query):
            queryText = query
            scheduleRefresh()
        case .toggleFacet(let key, let value):
            toggleFacet(key: key, value: value)
        }
    }

    func removeToken(_ token: Token) {
        tokens.removeAll { $0.id == token.id }
        scheduleRefresh()
    }

    func toggleFacet(key: String, value: String) {
        var set = selectedFacets[key] ?? []
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
        selectedFacets[key] = set
        scheduleRefresh()
    }

    func isFacetSelected(key: String, value: String) -> Bool {
        selectedFacets[key]?.contains(value) ?? false
    }

    func displayFacetValue(key: String, value: String) -> String {
        switch key {
        case "authRequired":
            if value.lowercased() == "true" { return "Auth required" }
            if value.lowercased() == "false" { return "Auth not required" }
            return "Auth unknown"
        case "flowDriven":
            return value.lowercased() == "true" ? "Flow-driven" : "Not flow-driven"
        case "editable":
            return value.lowercased() == "true" ? "Editable" : "Read-only"
        case "supportedInsertionModes":
            return value.capitalized
        case "categoryPath":
            return value.replacingOccurrences(of: "/", with: " / ")
        default:
            return value
        }
    }

    private func addToken(_ token: Token) {
        guard !tokens.contains(where: { $0.id == token.id }) else { return }
        tokens.append(token)
        scheduleRefresh()
    }

    private func makeToken(kindValue: String, value: String) -> Token? {
        switch kindValue {
        case "purpose":
            return Token(kind: .purpose, value: value)
        case "interest":
            return Token(kind: .interest, value: value)
        case "category":
            return Token(kind: .category, value: value)
        case "source":
            return Token(kind: .source, value: value)
        case "compatibility":
            return Token(kind: .compatibility, value: value)
        case "auth", "authrequired":
            return Token(kind: .authRequired, value: value)
        default:
            return nil
        }
    }

    private func makeComponentItem(
        configuration: CellConfiguration,
        displayName: String,
        summary: String,
        insertionModes: [String],
        supportedTargetKinds: [String]
    ) -> ComponentPaletteItem? {
        guard queryContext.editMode else { return nil }
        guard queryContext.insertionIntent == .component || queryContext.insertionIntent == .both else { return nil }

        let normalizedModes = Set(insertionModes.map { $0.lowercased() })
        guard normalizedModes.contains("component") || normalizedModes.contains("both") else { return nil }

        return ComponentPaletteCatalog.libraryEmbeddedComponent(
            configuration: configuration,
            displayName: displayName,
            summary: summary.isEmpty ? configuration.description : summary,
            supportedTargetKinds: supportedTargetKinds
        )
    }

    private func stickyCatalogCandidates(_ candidates: [String]) -> [String] {
        guard networkPolicy != .cacheOnly,
              let lastGoodCatalogEndpoint,
              !lastGoodCatalogEndpoint.isEmpty else {
            return candidates
        }

        let lastGoodKey = normalizedEndpointKey(lastGoodCatalogEndpoint)
        guard candidates.contains(where: { normalizedEndpointKey($0) == lastGoodKey }) else {
            return candidates
        }

        return [lastGoodCatalogEndpoint] + candidates.filter { normalizedEndpointKey($0) != lastGoodKey }
    }

    private func resolveCatalog() async throws -> ResolvedCatalog {
        if !BindingRuntimeBootstrap.shouldUseLocalRuntimeOnlyForVerifier() {
            await AppInitializer.initialize()
        }
        await BindingLocalCellRegistration.shared.ensureRegistered()
        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            throw LibraryError.resolverUnavailable
        }
        guard let identity = await CellBase.defaultIdentityVault?.identity(for: "private", makeNewIfNotFound: true) else {
            throw LibraryError.identityUnavailable
        }

        let preference: RemoteCatalogSupport.CandidatePreference = switch networkPolicy {
        case .healthyOnly:
            .preferRemote
        case .preferHealthyThenCached, .cacheOnly:
            .preferLocal
        }

        let candidates = stickyCatalogCandidates(
            RemoteCatalogSupport.orderedCatalogCandidateEndpoints(
                from: catalogEndpoints,
                preference: preference
            )
        )
        var resolutionWarnings: [String] = []
        for endpoint in candidates {
            do {
                let emit = try await resolveCatalogCandidate(
                    endpoint: endpoint,
                    resolver: resolver,
                    requester: identity
                )
                guard let catalog = emit as? Meddle else {
                    resolutionWarnings.append("Kilden \(endpoint) eksponerer ikke Meddle-kontrakt.")
                    continue
                }
                return ResolvedCatalog(
                    catalog: catalog,
                    identity: identity,
                    endpoint: endpoint,
                    resolutionWarnings: resolutionWarnings
                )
            } catch {
                resolutionWarnings.append(resolutionWarning(for: endpoint, error: error))
                continue
            }
        }
        throw LibraryError.catalogUnavailable
    }

    private func resolveCatalogCandidate(
        endpoint: String,
        resolver: CellResolver,
        requester: Identity
    ) async throws -> Emit {
        let timeoutNanoseconds: UInt64 = RemoteCatalogSupport.isLocalCatalogEndpoint(endpoint)
            ? 800_000_000
            : 2_000_000_000

        return try await withThrowingTaskGroup(of: Emit.self) { group in
            group.addTask {
                try await RemoteEndpointAccessSupport.resolveEmit(
                    endpoint: endpoint,
                    resolver: resolver,
                    requester: requester,
                    accessLabel: "fullLibrary.catalog"
                )
            }
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw LibraryError.catalogCandidateTimedOut(endpoint)
            }

            guard let emit = try await group.next() else {
                throw LibraryError.catalogUnavailable
            }
            group.cancelAll()
            return emit
        }
    }

    private func resolutionWarning(for endpoint: String, error: Error) -> String {
        if case LibraryError.catalogCandidateTimedOut = error {
            return "Kilden \(endpoint) svarte ikke raskt nok. Fortsetter til neste kilde."
        }
        if RemoteCatalogSupport.isLocalCatalogEndpoint(endpoint) {
            return "Lokal ConfigurationCatalog kunne ikke lastes. Prøver neste kilde."
        }
        return "Remote tilgang til \(endpoint) feilet. Fortsetter til neste kilde."
    }

    var warningSummaryText: String? {
        guard let first = warnings.first else { return nil }
        guard warnings.count > 1 else { return first }
        return "\(first) (+\(warnings.count - 1) til)"
    }

    private func replaceWarnings(with rawMessages: [String]) {
        rawWarnings = rawMessages
        let presentation = Self.presentWarnings(rawMessages)
        warnings = presentation.messages
        warningDetails = presentation.details
    }

    private func appendWarning(_ rawMessage: String) {
        replaceWarnings(with: rawWarnings + [rawMessage])
    }

    static func presentWarnings(_ rawMessages: [String]) -> WarningPresentation {
        let trimmed = rawMessages
            .flatMap(splitWarningComponents)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !trimmed.isEmpty else {
            return WarningPresentation(messages: [], details: [])
        }

        var messages: [String] = []
        var details: [String] = []

        let sourceLimitWarnings = trimmed.filter { normalizedWarningText($0).contains("maxsourceslimit") }
        if !sourceLimitWarnings.isEmpty {
            let count = sourceLimitWarnings.count
            messages.append(
                count == 1
                    ? "Én ekstern kilde ble hoppet over for å holde biblioteket raskt."
                    : "\(count) eksterne kilder ble hoppet over for å holde biblioteket raskt."
            )
            details.append(contentsOf: sourceLimitWarnings)
        }

        let remoteFallbackWarnings = trimmed.filter {
            let normalized = normalizedWarningText($0)
            return normalized.contains("svarte ikke raskt nok") ||
                normalized.contains("remote tilgang til") ||
                normalized.contains("staging-katalogen svarte ikke")
        }
        if !remoteFallbackWarnings.isEmpty {
            messages.append("En ekstern katalogkilde var treg eller utilgjengelig. Biblioteket fortsatte med lokale data.")
            details.append(contentsOf: remoteFallbackWarnings)
        }

        let incompatibleWarnings = trimmed.filter { normalizedWarningText($0).contains("eksponerer ikke meddle") }
        if !incompatibleWarnings.isEmpty {
            messages.append("En katalogkilde svarte i feil format og ble hoppet over.")
            details.append(contentsOf: incompatibleWarnings)
        }

        let directFallbackWarnings = trimmed.filter {
            let normalized = normalizedWarningText($0)
            return normalized.contains("støtter ikke katalog-query") ||
                normalized.contains("query svarte tomt")
        }
        if !directFallbackWarnings.isEmpty {
            messages.append("Biblioteket viser en enklere katalogvisning fordi avansert søk ikke var tilgjengelig.")
            details.append(contentsOf: directFallbackWarnings)
        }

        let localFacetWarnings = trimmed.filter { normalizedWarningText($0).contains("støtter ikke facetcounts") }
        if !localFacetWarnings.isEmpty {
            messages.append("Filtertellinger er beregnet lokalt for denne visningen.")
            details.append(contentsOf: localFacetWarnings)
        }

        let localFallbackWarnings = trimmed.filter {
            let normalized = normalizedWarningText($0)
            return normalized.contains("uten visbare treff") ||
                normalized.contains("viser lokal fallback")
        }
        if !localFallbackWarnings.isEmpty {
            messages.append("Den valgte katalogkilden ga ikke visbare treff, så biblioteket viste lokal fallback.")
            details.append(contentsOf: localFallbackWarnings)
        }

        let invalidQueryWarnings = trimmed.filter { normalizedWarningText($0).contains("ugyldig query-respons") }
        if !invalidQueryWarnings.isEmpty {
            messages.append("Katalogen svarte med et uventet format.")
            details.append(contentsOf: invalidQueryWarnings)
        }

        let coveredWarnings = Set(details)
        let uncategorizedWarnings = trimmed.filter { !coveredWarnings.contains($0) }
        for warning in uncategorizedWarnings {
            messages.append(simplifyWarningText(warning))
            details.append(warning)
        }

        var seenMessages = Set<String>()
        let deduplicatedMessages = messages.filter { seenMessages.insert($0).inserted }
        return WarningPresentation(messages: deduplicatedMessages.prefix(3).map { $0 }, details: details)
    }

    private static func simplifyWarningText(_ warning: String) -> String {
        let normalized = normalizedWarningText(warning)
        if normalized.contains("maxsourceslimit") {
            return "Eksterne kilder ble hoppet over for å holde biblioteket raskt."
        }
        if warning.contains("cell://") || warning.contains("wss://") {
            return "En katalogkilde rapporterte et teknisk avvik og ble håndtert automatisk."
        }
        return warning
    }

    private static func splitWarningComponents(_ warning: String) -> [String] {
        warning
            .split(whereSeparator: { $0 == "|" || $0 == "\n" })
            .map(String.init)
    }

    private static func normalizedWarningText(_ warning: String) -> String {
        warning
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func directCatalogResults(from catalog: Meddle, requester: Identity) async throws -> [SearchResult] {
        let items = try await directCatalogItems(from: catalog, requester: requester)

        let queryCorpusTokens = directMatchTokens()
        let queryText = defaultQueryTextForTab().trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSignal = !queryText.isEmpty || !queryCorpusTokens.isEmpty || !selectedFacets.isEmpty

        let results = items.compactMap { item -> SearchResult? in
            guard case let .object(object) = item,
                  let decodedConfiguration = decodeCellConfiguration(from: object["configuration"])
            else {
                return nil
            }
            let configuration = ConfigurationPresentationSupport.viewportSafeConfiguration(decodedConfiguration)
            guard !isEmitterConfiguration(configuration) else { return nil }

            let displayName = object["displayName"]?.stringValueOrNil ?? configuration.name
            let summary = object["summary"]?.stringValueOrNil ?? (configuration.description ?? "")
            let sourceRef = object["sourceCellEndpoint"]?.stringValueOrNil ?? ""
            let categoryPath = object["categoryPath"]?.stringListValue ?? []
            let interests = object["interests"]?.stringListValue ?? []
            let tags = object["tags"]?.stringListValue ?? []
            let purpose = object["purpose"]?.stringValueOrNil ?? ""
            let authRequired = object["authRequired"]?.boolValue
            let flowDriven = object["flowDriven"]?.boolValue
            let editable = object["editable"]?.boolValue
            let insertionModes = object["supportedInsertionModes"]?.stringListValue ?? []
            let supportedTargetKinds = object["supportedTargetKinds"]?.stringListValue ?? []

            let corpus = [
                displayName,
                summary,
                sourceRef,
                purpose,
                interests.joined(separator: " "),
                tags.joined(separator: " "),
                categoryPath.joined(separator: " ")
            ]
            .joined(separator: " ")
            .lowercased()

            let matchedTokens = queryCorpusTokens.filter { corpus.contains($0) }
            let score = hasSignal
                ? Double(matchedTokens.count) / Double(max(1, queryCorpusTokens.count))
                : 0.5

            if hasSignal && score <= 0 {
                return nil
            }

            var badges: [String] = []
            if insertionModes.contains("both") {
                badges.append("Both")
            } else if insertionModes.contains("root") {
                badges.append("Root")
            } else if insertionModes.contains("component") {
                badges.append("Component")
            }
            if authRequired == true {
                badges.append("Auth-required")
            }
            if flowDriven == true {
                badges.append("Flow-driven")
            }
            if editable == true {
                badges.append("Editable")
            }

            let id = object["id"]?.stringValueOrNil ?? UUID().uuidString
            return SearchResult(
                id: id,
                configurationId: id,
                displayName: displayName,
                summary: summary,
                sourceRef: sourceRef,
                route: "catalogEntry",
                score: score,
                scoreBreakdown: ScoreBreakdown(
                    text: score,
                    purpose: 0,
                    interest: 0,
                    compatibility: 0,
                    connectivity: 1,
                    resourceFit: 0,
                    recency: 0
                ),
                badges: badges,
                configuration: configuration,
                componentItem: makeComponentItem(
                    configuration: configuration,
                    displayName: displayName,
                    summary: summary,
                    insertionModes: insertionModes,
                    supportedTargetKinds: supportedTargetKinds
                )
            )
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            return lhs.score > rhs.score
        }

        return Array(results.prefix(selectedTab == .sources ? 100 : 60))
    }

    private func directCatalogItems(from catalog: Meddle, requester: Identity) async throws -> [ValueType] {
        if let contracts = try? await catalog.get(keypath: "catalogContracts", requester: requester),
           case let .list(items) = contracts,
           items.isEmpty == false {
            return items
        }

        let rawEntries = try await catalog.get(keypath: "catalogEntries", requester: requester)
        guard case let .list(items) = rawEntries else { return [] }
        return items
    }

    private func offlineFallbackResults() -> [SearchResult] {
        let queryTokens = directMatchTokens()
        let hasSignal = !defaultQueryTextForTab().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !queryTokens.isEmpty

        var seenOfflineConfigurationIDs = Set<String>()
        func appendUnique(
            _ configurations: [CellConfiguration],
            sourceRef: String,
            badges: [String],
            into output: inout [(CellConfiguration, String, [String])]
        ) {
            for configuration in configurations {
                guard seenOfflineConfigurationIDs.insert(configuration.uuid).inserted else { continue }
                output.append((configuration, sourceRef, badges))
            }
        }

        var candidates: [(CellConfiguration, String, [String])] = []
        appendUnique(fallbackFavorites, sourceRef: "offline.favorite", badges: ["Offline", "Favorite"], into: &candidates)
        appendUnique(fallbackTemplates, sourceRef: "offline.template", badges: ["Offline", "Template"], into: &candidates)
        if BindingPersonalCopilotV1Policy.conferenceShowcaseEnabled {
            appendUnique(
                [
                    ConfigurationCatalogCell.conferenceCodexLiveConfigurationsMenuConfiguration(),
                    ConfigurationCatalogCell.conferenceClaudeDesignReferenceMenuConfiguration(),
                    ConfigurationCatalogCell.conferenceParticipantPortalWorkbenchConfiguration(),
                    ConfigurationCatalogCell.conferenceAIAssistantWorkbenchConfiguration(),
                    ConfigurationCatalogCell.conferenceMVPWorkbenchMenuConfiguration(),
                    ConfigurationCatalogCell.conferenceAdminWorkbenchConfiguration(),
                    ConfigurationCatalogCell.conferencePublicWorkbenchConfiguration(),
                    ConfigurationCatalogCell.conferenceSponsorWorkbenchConfiguration()
                ],
                sourceRef: "offline.local",
                badges: ["Offline", "Local"],
                into: &candidates
            )
        }

        let results = candidates.compactMap { configuration, sourceRef, seedBadges -> SearchResult? in
            let configuration = ConfigurationPresentationSupport.viewportSafeConfiguration(configuration)
            let discovery = configuration.discovery
            let displayName = configuration.name
            let summary = configuration.description ?? discovery?.purposeDescription ?? ""
            let corpus = [
                displayName,
                summary,
                discovery?.purpose ?? "",
                discovery?.interests.joined(separator: " ") ?? "",
                discovery?.sourceCellEndpoint ?? ""
            ]
            .joined(separator: " ")
            .lowercased()

            let matchedTokens = queryTokens.filter { corpus.contains($0) }
            let score = hasSignal
                ? Double(matchedTokens.count) / Double(max(1, queryTokens.count))
                : 0.42

            if hasSignal && score <= 0 {
                return nil
            }

            let sourceEndpoint = discovery?.sourceCellEndpoint ?? sourceRef
            return SearchResult(
                id: "offline|\(configuration.uuid)",
                configurationId: configuration.uuid,
                displayName: displayName,
                summary: summary,
                sourceRef: sourceEndpoint,
                route: "offlineCache",
                score: score,
                scoreBreakdown: ScoreBreakdown(
                    text: score,
                    purpose: hasSignal ? min(1, score * 0.8) : 0.2,
                    interest: hasSignal ? min(1, score * 0.7) : 0.2,
                    compatibility: 0,
                    connectivity: 0,
                    resourceFit: 0,
                    recency: 0
                ),
                badges: seedBadges,
                configuration: configuration,
                componentItem: makeComponentItem(
                    configuration: configuration,
                    displayName: displayName,
                    summary: summary,
                    insertionModes: configuration.skeleton == nil ? [] : ["both"],
                    supportedTargetKinds: ["root", "vstack", "section", "scrollview", "grid"]
                )
            )
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            return lhs.score > rhs.score
        }

        return Array(results.prefix(selectedTab == .sources ? 100 : 60))
    }

    private func directMatchTokens() -> [String] {
        let freeTextTokens = tokenize(defaultQueryTextForTab())
        let tokenValues = tokensForRequest().flatMap { tokenize($0.value) }
        let facetTokens = selectedFacets.values
            .flatMap { $0 }
            .flatMap { tokenize($0) }
        return Array(Set(freeTextTokens + tokenValues + facetTokens))
    }

    private func tokenize(_ value: String) -> [String] {
        value
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 1 }
    }

    private func buildQueryPayload() -> Object {
        var payload: Object = [
            "requestId": .string(UUID().uuidString),
            "q": .string(defaultQueryTextForTab()),
            "tokens": .list(tokensForRequest().map { token in
                .object([
                    "kind": .string(token.kind.rawValue),
                    "value": .string(token.value)
                ])
            }),
            "filters": .object(filtersObject()),
            "context": .object([
                "editMode": .bool(queryContext.editMode),
                "selectedNodeKind": queryContext.selectedNodeKind.map(ValueType.string) ?? .null,
                "insertionIntent": .string(queryContext.insertionIntent.rawValue)
            ]),
            "constraints": .object([
                "maxResults": .integer(selectedTab == .sources ? 100 : 60),
                "maxSources": .integer(maxSources),
                "latencyBudgetMs": .integer(350),
                "resourceBudget": .string(resourceBudget.rawValue),
                "networkPolicy": .string(networkPolicy.rawValue),
                "allowDegradedSources": .bool(allowDegradedSources)
            ])
        ]

        if selectedTab == .forMyPurposes {
            let hasPurposeSignal = tokens.contains { $0.kind == .purpose || $0.kind == .interest }
            if !hasPurposeSignal {
                payload["q"] = .string(defaultQueryTextForTab() + " purpose")
            }
        }
        return payload
    }

    private func buildFacetPayload(baseQuery: Object) -> Object {
        [
            "requestId": .string(UUID().uuidString),
            "baseQuery": .object(baseQuery),
            "facetKeys": .list([
                .string("categoryPath"),
                .string("sourceRef"),
                .string("supportedInsertionModes"),
                .string("authRequired"),
                .string("flowDriven"),
                .string("editable")
            ]),
            "activeFilters": .object(filtersObject()),
            "maxBucketsPerFacet": .integer(16)
        ]
    }

    private func tokensForRequest() -> [Token] {
        var output = tokens

        if selectedTab == .templates {
            let hasTemplateSignal = output.contains { $0.kind == .category }
            if !hasTemplateSignal {
                output.append(Token(kind: .category, value: "template"))
                output.append(Token(kind: .category, value: "bootstrap"))
            }
        }
        return output
    }

    private func filtersObject() -> Object {
        var object: Object = [:]

        for token in tokens {
            switch token.kind {
            case .category:
                appendFilterValue(key: "categoryPath", value: token.value.lowercased(), into: &object)
            case .source:
                appendFilterValue(key: "sourceRefs", value: token.value, into: &object)
            case .compatibility:
                appendFilterValue(key: "supportedInsertionModes", value: token.value.lowercased(), into: &object)
            case .authRequired:
                let normalized = token.value.lowercased()
                if normalized == "true" || normalized == "required" {
                    appendFilterBool(key: "authRequired", value: true, into: &object)
                } else if normalized == "false" || normalized == "none" {
                    appendFilterBool(key: "authRequired", value: false, into: &object)
                }
            default:
                break
            }
        }

        for (key, values) in selectedFacets where !values.isEmpty {
            for value in values {
                switch key {
                case "categoryPath":
                    appendFilterValue(key: "categoryPath", value: value, into: &object)
                case "sourceRef":
                    appendFilterValue(key: "sourceRefs", value: value, into: &object)
                case "supportedInsertionModes":
                    appendFilterValue(key: "supportedInsertionModes", value: value, into: &object)
                case "authRequired", "flowDriven", "editable":
                    guard let boolValue = boolFromFacetValue(value) else { continue }
                    appendFilterBool(key: key, value: boolValue, into: &object)
                default:
                    continue
                }
            }
        }

        return object
    }

    private func appendFilterValue(key: String, value: String, into object: inout Object) {
        var current: [ValueType] = []
        if case let .list(existing)? = object[key] {
            current = existing
        }
        if !current.contains(.string(value)) {
            current.append(.string(value))
        }
        object[key] = .list(current)
    }

    private func appendFilterBool(key: String, value: Bool, into object: inout Object) {
        var current: [ValueType] = []
        if case let .list(existing)? = object[key] {
            current = existing
        }
        let boolValue: ValueType = .bool(value)
        if !current.contains(boolValue) {
            current.append(boolValue)
        }
        object[key] = .list(current)
    }

    private func boolFromFacetValue(_ value: String) -> Bool? {
        switch value.lowercased() {
        case "true":
            return true
        case "false":
            return false
        default:
            return nil
        }
    }

    private func defaultQueryTextForTab() -> String {
        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        switch selectedTab {
        case .templates:
            return "template bootstrap"
        default:
            return ""
        }
    }

    private func parseQueryResponse(_ response: ValueType) {
        guard case let .object(root) = response else {
            results = []
            replaceWarnings(with: ["Ugyldig query-respons"])
            return
        }

        var parsedResults: [SearchResult] = []
        if case let .list(items)? = root["results"] {
            parsedResults = items.compactMap { item in
                guard case let .object(object) = item else { return nil }
                guard let decodedConfiguration = decodeCellConfiguration(from: object["configuration"]) else { return nil }
                let configuration = ConfigurationPresentationSupport.viewportSafeConfiguration(decodedConfiguration)
                guard !isEmitterConfiguration(configuration) else { return nil }

                let scoreBreakdownObject = object["scoreBreakdown"]?.objectValue ?? [:]
                let breakdown = ScoreBreakdown(
                    text: scoreBreakdownObject["text"]?.doubleValue ?? 0,
                    purpose: scoreBreakdownObject["purpose"]?.doubleValue ?? 0,
                    interest: scoreBreakdownObject["interest"]?.doubleValue ?? 0,
                    compatibility: scoreBreakdownObject["compatibility"]?.doubleValue ?? 0,
                    connectivity: scoreBreakdownObject["connectivity"]?.doubleValue ?? 0,
                    resourceFit: scoreBreakdownObject["resourceFit"]?.doubleValue ?? 0,
                    recency: scoreBreakdownObject["recency"]?.doubleValue ?? 0
                )

                let id = object["configurationId"]?.stringValueOrNil ?? UUID().uuidString
                let displayName = object["displayName"]?.stringValueOrNil ?? configuration.name
                let summary = object["summary"]?.stringValueOrNil ?? ""
                let insertionModes = object["supportedInsertionModes"]?.stringListValue ?? []
                let supportedTargetKinds = object["supportedTargetKinds"]?.stringListValue ?? []
                return SearchResult(
                    id: id,
                    configurationId: id,
                    displayName: displayName,
                    summary: summary,
                    sourceRef: object["sourceRef"]?.stringValueOrNil ?? "",
                    route: object["route"]?.stringValueOrNil ?? "text",
                    score: object["score"]?.doubleValue ?? 0,
                    scoreBreakdown: breakdown,
                    badges: object["badges"]?.stringListValue ?? [],
                    configuration: configuration,
                    componentItem: makeComponentItem(
                        configuration: configuration,
                        displayName: displayName,
                        summary: summary,
                        insertionModes: insertionModes,
                        supportedTargetKinds: supportedTargetKinds
                    )
                )
            }
        }

        if case let .object(connectivityObject)? = root["connectivity"] {
            connectivity = ConnectivitySnapshot(
                onlineSources: connectivityObject["onlineSources"]?.intValue ?? 0,
                degradedSources: connectivityObject["degradedSources"]?.intValue ?? 0,
                offlineSources: connectivityObject["offlineSources"]?.intValue ?? 0
            )
        } else {
            connectivity = .empty
        }

        replaceWarnings(with: root["warnings"]?.stringListValue ?? [])
        results = parsedResults
        selectedResultID = preferredSelectionID(in: results, currentSelectionID: selectedResultID)
    }

    private func bestSelectionMatch(in results: [SearchResult], query: String) -> SearchResult? {
        let normalizedQuery = normalizedSearchText(query)
        guard !normalizedQuery.isEmpty else { return nil }
        let queryTokens = normalizedQuery.split(separator: " ").map(String.init)

        return results.max { lhs, rhs in
            selectionAffinity(for: lhs, normalizedQuery: normalizedQuery, queryTokens: queryTokens) <
                selectionAffinity(for: rhs, normalizedQuery: normalizedQuery, queryTokens: queryTokens)
        }
    }

    private func selectionAffinity(
        for result: SearchResult,
        normalizedQuery: String,
        queryTokens: [String]
    ) -> Int {
        let displayName = normalizedSearchText(result.displayName)
        let summary = normalizedSearchText(result.summary)
        let sourceRef = normalizedSearchText(result.sourceRef)
        let badges = normalizedSearchText(result.badges.joined(separator: " "))

        var score = 0
        if displayName == normalizedQuery { score += 800 }
        if displayName.contains(normalizedQuery) { score += 400 }
        if summary.contains(normalizedQuery) { score += 180 }
        if sourceRef.contains(normalizedQuery) { score += 120 }
        if badges.contains(normalizedQuery) { score += 80 }

        for token in queryTokens where !token.isEmpty {
            if displayName.contains(token) { score += 90 }
            if summary.contains(token) { score += 30 }
            if sourceRef.contains(token) { score += 20 }
            if badges.contains(token) { score += 12 }
        }

        score += Int(result.score * 100.0)
        return score
    }

    private func normalizedSearchText(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseFacetResponse(_ response: ValueType) {
        guard case let .object(root) = response,
              case let .object(facetsObject)? = root["facets"] else {
            facetSections = []
            return
        }

        let order = [
            "categoryPath",
            "sourceRef",
            "supportedInsertionModes",
            "authRequired",
            "flowDriven",
            "editable"
        ]

        var sections: [FacetSection] = []
        for key in order {
            guard case let .list(values)? = facetsObject[key] else { continue }
            let buckets = values.compactMap { value -> FacetBucket? in
                guard case let .object(object) = value,
                      let facetValue = object["value"]?.stringValueOrNil
                else {
                    return nil
                }
                return FacetBucket(
                    facetKey: key,
                    value: facetValue,
                    count: object["count"]?.intValue ?? 0,
                    exact: object["exact"]?.boolValue ?? false
                )
            }

            sections.append(
                FacetSection(
                    key: key,
                    title: facetTitle(for: key),
                    buckets: buckets
                )
            )
        }

        facetSections = sections
    }

    private func deriveFacetSections(from results: [SearchResult]) -> [FacetSection] {
        guard !results.isEmpty else { return [] }

        func sortedBuckets(from counts: [String: Int], key: String) -> [FacetBucket] {
            counts
                .map { FacetBucket(facetKey: key, value: $0.key, count: $0.value, exact: true) }
                .sorted { lhs, rhs in
                    if lhs.count == rhs.count {
                        return lhs.value.localizedCaseInsensitiveCompare(rhs.value) == .orderedAscending
                    }
                    return lhs.count > rhs.count
                }
        }

        var sourceCounts: [String: Int] = [:]
        var insertionModeCounts: [String: Int] = [:]
        var authCounts: [String: Int] = [:]
        var flowCounts: [String: Int] = [:]
        var editableCounts: [String: Int] = [:]

        for result in results {
            if !result.sourceRef.isEmpty {
                sourceCounts[result.sourceRef, default: 0] += 1
            }

            let loweredBadges = Set(result.badges.map { $0.lowercased() })
            if loweredBadges.contains("both") {
                insertionModeCounts["both", default: 0] += 1
            } else if loweredBadges.contains("root") {
                insertionModeCounts["root", default: 0] += 1
            } else if loweredBadges.contains("component") {
                insertionModeCounts["component", default: 0] += 1
            }

            if loweredBadges.contains("auth-required") {
                authCounts["true", default: 0] += 1
            }
            if loweredBadges.contains("flow-driven") {
                flowCounts["true", default: 0] += 1
            }
            if loweredBadges.contains("editable") {
                editableCounts["true", default: 0] += 1
            }
        }

        var sections: [FacetSection] = []
        if !sourceCounts.isEmpty {
            sections.append(FacetSection(key: "sourceRef", title: "Source", buckets: sortedBuckets(from: sourceCounts, key: "sourceRef")))
        }
        if !insertionModeCounts.isEmpty {
            sections.append(FacetSection(key: "supportedInsertionModes", title: "Insertion", buckets: sortedBuckets(from: insertionModeCounts, key: "supportedInsertionModes")))
        }
        if !authCounts.isEmpty {
            sections.append(FacetSection(key: "authRequired", title: "Auth", buckets: sortedBuckets(from: authCounts, key: "authRequired")))
        }
        if !flowCounts.isEmpty {
            sections.append(FacetSection(key: "flowDriven", title: "Flow", buckets: sortedBuckets(from: flowCounts, key: "flowDriven")))
        }
        if !editableCounts.isEmpty {
            sections.append(FacetSection(key: "editable", title: "Editable", buckets: sortedBuckets(from: editableCounts, key: "editable")))
        }
        return sections
    }

    private func facetTitle(for key: String) -> String {
        switch key {
        case "categoryPath": return "Category"
        case "sourceRef": return "Source"
        case "supportedInsertionModes": return "Compatibility"
        case "authRequired": return "Auth"
        case "flowDriven": return "Flow-driven"
        case "editable": return "Editable"
        default: return key
        }
    }

    private func decodeCellConfiguration(from value: ValueType?) -> CellConfiguration? {
        guard let value else { return nil }
        switch value {
        case .cellConfiguration(let configuration):
            return configuration
        case .object(let object):
            guard let data = try? JSONEncoder().encode(object) else { return nil }
            return try? JSONDecoder().decode(CellConfiguration.self, from: data)
        default:
            return nil
        }
    }

    private func isEmitterConfiguration(_ configuration: CellConfiguration) -> Bool {
        let loweredName = configuration.name.lowercased()
        if loweredName.contains("emitter") || loweredName.contains("signal workbench") {
            return true
        }
        if let description = configuration.description?.lowercased(),
           description.contains("event emitter") {
            return true
        }
        guard let references = configuration.cellReferences else { return false }
        return references.contains { reference in
            reference.endpoint.lowercased().contains("eventemitter")
        }
    }
}

private struct LibraryTokenChip: View {
    let token: FullLibraryViewModel.Token
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(token.label)
                .font(.caption)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.accentColor.opacity(0.15), in: Capsule())
    }
}

private extension ValueType {
    var objectValue: Object? {
        if case let .object(object) = self {
            return object
        }
        return nil
    }

    var stringValueOrNil: String? {
        switch self {
        case .string(let value):
            return value
        default:
            return nil
        }
    }

    var intValue: Int? {
        switch self {
        case .integer(let value):
            return value
        case .number(let value):
            return value
        case .float(let value):
            return Int(value)
        default:
            return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .float(let value):
            return value
        case .integer(let value):
            return Double(value)
        case .number(let value):
            return Double(value)
        default:
            return nil
        }
    }

    var boolValue: Bool? {
        if case let .bool(value) = self {
            return value
        }
        return nil
    }

    var stringListValue: [String] {
        guard case let .list(values) = self else { return [] }
        return values.compactMap { value in
            if case let .string(string) = value {
                return string
            }
            return nil
        }
    }
}
