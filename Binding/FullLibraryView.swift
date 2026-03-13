import SwiftUI
import Combine
import CellBase
import CellApple

enum FullLibraryInsertionIntent: String {
    case root
    case component
    case both
    case unknown
}

struct FullLibraryQueryContext {
    var editMode: Bool
    var selectedNodeKind: String?
    var insertionIntent: FullLibraryInsertionIntent
}

struct FullLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bridgeStatusStore: BridgeConnectionStatusStore
    @StateObject private var model: FullLibraryViewModel
    @FocusState private var focusedField: FocusField?
    @State private var closeAfterInsert = true
    @State private var showAdvancedFilters = false

    private let onAddConfiguration: (CellConfiguration) -> Void
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
            .navigationTitle("Full Library")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Ferdig") {
                        dismissKeyboard()
                    }
                }
            }
        }
#if os(macOS)
        .frame(minWidth: 1020, minHeight: 720)
#endif
        .task {
            await model.loadInitial()
            focusedField = .query
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
        Picker("Library segment", selection: $model.selectedTab) {
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

                        Text("Score breakdown")
                            .font(.caption.weight(.semibold))

                        scoreRow("Text", selected.scoreBreakdown.text)
                        scoreRow("Purpose", selected.scoreBreakdown.purpose)
                        scoreRow("Interest", selected.scoreBreakdown.interest)
                        scoreRow("Compat", selected.scoreBreakdown.compatibility)
                        scoreRow("Conn", selected.scoreBreakdown.connectivity)
                        scoreRow("Resource", selected.scoreBreakdown.resourceFit)
                        scoreRow("Recency", selected.scoreBreakdown.recency)

                        if let skeleton = selected.configuration.skeleton {
                            Text("Skeleton")
                                .font(.caption.weight(.semibold))
                            SkeletonView(element: skeleton)
                                .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 220, alignment: .topLeading)
                                .padding(8)
                                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        } else {
                            Text("Ingen skeleton-preview tilgjengelig.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if selected.componentItem != nil {
                            if let componentItem = selected.componentItem,
                               armedComponentID == componentItem.id {
                                Text("Plassering er aktiv. Lukk biblioteket og klikk et innsettingspunkt i lerretet.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            HStack(spacing: 8) {
                                Button(componentPlacementLabel(for: selected)) {
                                    togglePlacement(for: selected)
                                }
                                .buttonStyle(.bordered)

                                Button("Sett inn i valgt layout") {
                                    applySelection(selected)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        } else {
                            Button("Legg til i Porthole") {
                                applySelection(selected)
                            }
                            .buttonStyle(.borderedProminent)
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
                Spacer()
                Text("Online \(model.connectivity.onlineSources) · Degraded \(model.connectivity.degradedSources) · Offline \(model.connectivity.offlineSources)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !model.warnings.isEmpty {
                Text(model.warnings.joined(separator: " | "))
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
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
    enum LibraryTab: String, CaseIterable, Identifiable {
        case allConfigs
        case forMyPurposes
        case sources
        case templates

        var id: String { rawValue }

        var title: String {
            switch self {
            case .allConfigs: return "All configs"
            case .forMyPurposes: return "For my purposes"
            case .sources: return "Sources"
            case .templates: return "Templates"
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
    @Published var connectivity: ConnectivitySnapshot = .empty
    @Published var availability: Availability = .unknown

    @Published var resourceBudget: ResourceBudget = .balanced
    @Published var networkPolicy: NetworkPolicy = .preferHealthyThenCached
    @Published var allowDegradedSources: Bool = true
    @Published var maxSources: Int = 24

    let fallbackFavorites: [CellConfiguration]
    let fallbackTemplates: [CellConfiguration]

    private let catalogEndpoints: [String]
    private let queryContext: FullLibraryQueryContext
    private var refreshTask: Task<Void, Never>?

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
    }

    var selectedResult: SearchResult? {
        if let selectedResultID,
           let selected = results.first(where: { $0.id == selectedResultID }) {
            return selected
        }
        return results.first
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
        refreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            await self?.refreshNow()
        }
    }

    func refreshNow() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let (catalog, identity, endpoint) = try await resolveCatalog()
            try? await catalog.set(keypath: "syncScaffoldPurposeGoals", value: .null, requester: identity)
            let fallbackCatalogResults = try? await directCatalogResults(from: catalog, requester: identity)
            let queryPayload = buildQueryPayload()
            let startedAt = Date()
            let queryResponse = try await catalog.set(keypath: "query", value: .object(queryPayload), requester: identity) ?? .null
            parseQueryResponse(queryResponse)

            let facetPayload = buildFacetPayload(baseQuery: queryPayload)
            let facetResponse = try await catalog.set(keypath: "facetCounts", value: .object(facetPayload), requester: identity) ?? .null
            parseFacetResponse(facetResponse)

            let elapsed = Int(Date().timeIntervalSince(startedAt) * 1000.0)
            if results.isEmpty, let fallbackCatalogResults, !fallbackCatalogResults.isEmpty {
                results = fallbackCatalogResults
                facetSections = []
                warnings = ["Query svarte tomt. Viser direkte katalogentries i stedet."]
                selectedResultID = results.first?.id
                connectivity = ConnectivitySnapshot(onlineSources: 1, degradedSources: 0, offlineSources: 0)
                statusLine = "Kilde: \(endpoint) · \(results.count) entries · direkte katalogvisning"
            } else {
                statusLine = "Kilde: \(endpoint) · \(results.count) treff · \(elapsed)ms"
            }
            availability = .available(endpoint: endpoint)
        } catch {
            availability = .unavailable(reason: "Kunne ikke nå ConfigurationCatalog.")
            statusLine = "Kun offline-cached favoritter/templates er tilgjengelig."
        }
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

    private func resolveCatalog() async throws -> (Meddle, Identity, String) {
        await AppInitializer.initialize()
        guard let resolver = CellBase.defaultCellResolver as? CellResolver else {
            throw LibraryError.resolverUnavailable
        }
        guard let identity = await CellBase.defaultIdentityVault?.identity(for: "private", makeNewIfNotFound: true) else {
            throw LibraryError.identityUnavailable
        }

        var seen = Set<String>()
        let candidates = (catalogEndpoints + ["cell:///ConfigurationCatalog"])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
        for endpoint in candidates {
            guard let emit = try? await resolver.cellAtEndpoint(endpoint: endpoint, requester: identity),
                  let catalog = emit as? Meddle
            else {
                continue
            }
            return (catalog, identity, endpoint)
        }
        throw LibraryError.catalogUnavailable
    }

    private func directCatalogResults(from catalog: Meddle, requester: Identity) async throws -> [SearchResult] {
        let rawEntries = try await catalog.get(keypath: "catalogEntries", requester: requester) ?? .null
        guard case let .list(items) = rawEntries else { return [] }

        let queryCorpusTokens = directMatchTokens()
        let queryText = defaultQueryTextForTab().trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSignal = !queryText.isEmpty || !queryCorpusTokens.isEmpty || !selectedFacets.isEmpty

        let results = items.compactMap { item -> SearchResult? in
            guard case let .object(object) = item,
                  let configuration = decodeCellConfiguration(from: object["configuration"]),
                  !isEmitterConfiguration(configuration)
            else {
                return nil
            }

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
            warnings = ["Ugyldig query-respons"]
            return
        }

        var parsedResults: [SearchResult] = []
        if case let .list(items)? = root["results"] {
            parsedResults = items.compactMap { item in
                guard case let .object(object) = item else { return nil }
                guard let configuration = decodeCellConfiguration(from: object["configuration"]) else { return nil }
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

        warnings = root["warnings"]?.stringListValue ?? []
        results = parsedResults
        if selectedResultID == nil || !results.contains(where: { $0.id == selectedResultID }) {
            selectedResultID = results.first?.id
        }
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
