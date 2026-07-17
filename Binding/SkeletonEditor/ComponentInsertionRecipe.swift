import Foundation
import UniformTypeIdentifiers
import SwiftUI
import CellBase

extension FullLibraryInsertionIntent: Codable {}

enum ComponentSourceKind: String, Codable {
    case palette
    case library
    case menu
}

enum ComponentRole: String, Codable {
    case rootScene
    case embeddedWidget
}

enum PreferredDropBehavior: String, Codable {
    case appendIntoContainer
    case insertBeforeTarget
    case insertAfterTarget
    case replacePlaceholder
}

struct ComponentInsertionRecipe: Codable {
    var id: String
    var displayName: String
    var subtitle: String?
    var icon: String
    var role: ComponentRole
    var supportedInsertionModes: [FullLibraryInsertionIntent]
    var supportedTargetKinds: [String]
    var referenceTemplate: [CellReference]
    var skeletonTemplate: SkeletonElement
    var preferredDropBehavior: PreferredDropBehavior
}

struct ComponentPaletteItem: Identifiable, Codable, Transferable {
    var id: String
    var title: String
    var subtitle: String?
    var icon: String
    var recipe: ComponentInsertionRecipe
    var sourceKind: ComponentSourceKind

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .componentPaletteItem)
    }
}

extension UTType {
    static let componentPaletteItem = UTType(exportedAs: "app.binding.componentpaletteitem")
}

enum ComponentPaletteCatalog {
    private static let defaultEditorTargetKinds = ["root", "vstack", "section", "scrollview", "grid"]
    private static let knownEditorTargetKinds: Set<String> = [
        "root",
        "vstack",
        "hstack",
        "scrollview",
        "section",
        "grid",
        "zstack",
        "text",
        "image",
        "button",
        "toggle",
        "reference"
    ]

    static func defaultItems() -> [ComponentPaletteItem] {
        [
            embeddedChatCard(),
            embeddedVaultSnapshotCard(),
            embeddedPurposeAssistantCard()
        ]
    }

    static func libraryEmbeddedComponent(
        configuration: CellConfiguration,
        displayName: String,
        summary: String?,
        supportedTargetKinds: [String]
    ) -> ComponentPaletteItem? {
        guard let skeleton = configuration.skeleton else { return nil }

        let normalizedTargetKinds = normalizeEditorTargetKinds(supportedTargetKinds)
        let recipe = ComponentInsertionRecipe(
            id: makeLibraryComponentID(configuration: configuration, displayName: displayName),
            displayName: displayName,
            subtitle: summary,
            icon: inferredLibraryIcon(configuration: configuration, displayName: displayName),
            role: .embeddedWidget,
            supportedInsertionModes: [.component],
            supportedTargetKinds: normalizedTargetKinds,
            referenceTemplate: configuration.cellReferences ?? [],
            skeletonTemplate: skeleton,
            preferredDropBehavior: .appendIntoContainer
        )

        return ComponentPaletteItem(
            id: recipe.id,
            title: recipe.displayName,
            subtitle: recipe.subtitle,
            icon: recipe.icon,
            recipe: recipe,
            sourceKind: .library
        )
    }

    static func embeddedChatCard(endpoint: String = "cell:///PersonalChatHub") -> ComponentPaletteItem {
        let recipe = ComponentInsertionRecipe(
            id: "chat.embedded.card",
            displayName: "Co-Pilot Prompt",
            subtitle: "Owner-scoped promptflate som foreslaar neste trygge hjelper uten aa sende.",
            icon: "arrow.up.circle.fill",
            role: .embeddedWidget,
            supportedInsertionModes: [.component],
            supportedTargetKinds: ["root", "vstack", "section", "scrollview", "grid"],
            referenceTemplate: [CellReference(endpoint: endpoint, label: "chatHub")],
            skeletonTemplate: embeddedChatCardSkeleton(referenceLabel: "chatHub"),
            preferredDropBehavior: .appendIntoContainer
        )

        return ComponentPaletteItem(
            id: recipe.id,
            title: recipe.displayName,
            subtitle: recipe.subtitle,
            icon: recipe.icon,
            recipe: recipe,
            sourceKind: .palette
        )
    }

    static func embeddedVaultSnapshotCard(endpoint: String = "cell:///Vault") -> ComponentPaletteItem {
        let recipe = ComponentInsertionRecipe(
            id: "vault.embedded.snapshot",
            displayName: "Vault Snapshot",
            subtitle: "Liten Obsidian-lignende vaultflate med tellinger og seed-handlinger.",
            icon: "books.vertical.fill",
            role: .embeddedWidget,
            supportedInsertionModes: [.component],
            supportedTargetKinds: ["root", "vstack", "section", "scrollview", "grid"],
            referenceTemplate: [CellReference(endpoint: endpoint, label: "vault")],
            skeletonTemplate: embeddedVaultSnapshotSkeleton(referenceLabel: "vault"),
            preferredDropBehavior: .appendIntoContainer
        )

        return ComponentPaletteItem(
            id: recipe.id,
            title: recipe.displayName,
            subtitle: recipe.subtitle,
            icon: recipe.icon,
            recipe: recipe,
            sourceKind: .palette
        )
    }

    static func embeddedPurposeAssistantCard(endpoint: String = "cell:///ConfigurationCatalog") -> ComponentPaletteItem {
        let recipe = ComponentInsertionRecipe(
            id: "catalog.embedded.purposeAssistant",
            displayName: "AI Purpose Assistant",
            subtitle: "Prompt, forslag og last valgt verktøy direkte fra katalogen.",
            icon: "sparkles.rectangle.stack.fill",
            role: .embeddedWidget,
            supportedInsertionModes: [.component],
            supportedTargetKinds: ["root", "vstack", "section", "scrollview", "grid"],
            referenceTemplate: [CellReference(endpoint: endpoint, label: "catalog")],
            skeletonTemplate: embeddedPurposeAssistantSkeleton(referenceLabel: "catalog"),
            preferredDropBehavior: .appendIntoContainer
        )

        return ComponentPaletteItem(
            id: recipe.id,
            title: recipe.displayName,
            subtitle: recipe.subtitle,
            icon: recipe.icon,
            recipe: recipe,
            sourceKind: .palette
        )
    }

    private static func normalizeEditorTargetKinds(_ supportedTargetKinds: [String]) -> [String] {
        let normalized = supportedTargetKinds
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { knownEditorTargetKinds.contains($0) }

        if normalized.isEmpty {
            return defaultEditorTargetKinds
        }

        var seen = Set<String>()
        return normalized.filter { seen.insert($0).inserted }
    }

    private static func makeLibraryComponentID(configuration: CellConfiguration, displayName: String) -> String {
        let seed = [
            displayName,
            configuration.name,
            configuration.cellReferences?.first?.endpoint ?? ""
        ]
            .joined(separator: "-")
            .lowercased()

        let scalars = seed.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "-"
        }
        let sanitized = String(scalars)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return "library.\(sanitized.isEmpty ? "component" : sanitized)"
    }

    private static func inferredLibraryIcon(configuration: CellConfiguration, displayName: String) -> String {
        let signal = [
            displayName,
            configuration.name,
            configuration.description ?? "",
            configuration.cellReferences?.first?.endpoint ?? ""
        ]
            .joined(separator: " ")
            .lowercased()

        if signal.contains("chat") {
            return "bubble.left.and.bubble.right.fill"
        }
        if signal.contains("vault") || signal.contains("obsidian") {
            return "books.vertical.fill"
        }
        if signal.contains("agent") || signal.contains("assistant") || signal.contains("ai") {
            return "sparkles.rectangle.stack.fill"
        }
        return "square.stack.3d.up.fill"
    }

    private static func embeddedChatCardSkeleton(referenceLabel: String) -> SkeletonElement {
        let sectionModifier = makeModifier {
            $0.padding = 10
            $0.background = "#FFFFFF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#D8DDEA"
        }

        let chipModifier = makeModifier {
            $0.padding = 6
            $0.background = "#EEF2FF"
            $0.cornerRadius = 999
            $0.fontSize = 11
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#4338CA"
        }

        let primaryButton = makeModifier {
            $0.padding = 12
            $0.background = "#4F46E5"
            $0.cornerRadius = 999
            $0.foregroundColor = "#FFFFFF"
        }

        let secondaryButton = makeModifier {
            $0.padding = 8
            $0.background = "#F8FAFC"
            $0.cornerRadius = 999
            $0.foregroundColor = "#111827"
        }

        var title = SkeletonText(text: "Co-Pilot")
        title.modifiers = makeModifier {
            $0.fontWeight = "semibold"
            $0.fontStyle = "headline"
            $0.foregroundColor = "#111827"
        }

        var liveChip = SkeletonText(text: "LOCAL")
        liveChip.modifiers = chipModifier

        var statusText = SkeletonText(keypath: "\(referenceLabel).state.ui.primaryActionHint")
        statusText.modifiers = makeModifier {
            $0.fontSize = 12
            $0.foregroundColor = "#4B5563"
            $0.lineLimit = 2
        }

        var messagesList = SkeletonList(keypath: "\(referenceLabel).state.ui.promptMessages")
        var messageAuthor = SkeletonText(keypath: "speaker")
        messageAuthor.modifiers = makeModifier {
            $0.fontWeight = "semibold"
            $0.fontSize = 12
            $0.foregroundColor = "#111827"
        }

        var messagePreview = SkeletonText(keypath: "body")
        messagePreview.modifiers = makeModifier {
            $0.fontSize = 12
            $0.foregroundColor = "#374151"
            $0.lineLimit = 3
        }

        var messageRow = SkeletonVStack(elements: [
            .Text(messageAuthor),
            .Text(messagePreview)
        ])
        messageRow.modifiers = makeModifier {
            $0.padding = 8
            $0.background = "#F8FAFC"
            $0.cornerRadius = 10
        }
        messagesList.flowElementSkeleton = messageRow
        messagesList.modifiers = makeModifier {
            $0.height = 160
        }

        let composer = SkeletonTextArea(
            text: nil,
            sourceKeypath: "\(referenceLabel).state.composer.body",
            targetKeypath: "\(referenceLabel).setComposer",
            placeholder: "Hva vil du faa gjort?",
            minLines: 2,
            maxLines: 4,
            submitOnEnter: false
        )

        var sendButton = SkeletonButton(
            keypath: "\(referenceLabel).prompt.submit",
            label: "↑",
            payload: .bool(true)
        )
        sendButton.modifiers = primaryButton

        var openSuggestionButton = SkeletonButton(
            keypath: "\(referenceLabel).ui.openSuggestedHelper",
            label: "Åpne forslag",
            payload: .bool(true)
        )
        openSuggestionButton.modifiers = secondaryButton

        var clearButton = SkeletonButton(
            keypath: "\(referenceLabel).clearComposer",
            label: "Tom",
            payload: .bool(true)
        )
        clearButton.modifiers = secondaryButton

        var headerRow = SkeletonHStack(elements: [
            .VStack(SkeletonVStack(elements: [.Text(title), .Text(statusText)])),
            .Spacer(SkeletonSpacer()),
            .Text(liveChip)
        ])
        headerRow.modifiers = makeModifier { $0.padding = 2 }

        let actionsRow = SkeletonHStack(elements: [
            .Button(sendButton),
            .Button(openSuggestionButton),
            .Button(clearButton)
        ])

        var card = SkeletonVStack(elements: [
            .HStack(headerRow),
            .List(messagesList),
            .TextArea(composer),
            .HStack(actionsRow)
        ])
        card.modifiers = sectionModifier
        return .VStack(card)
    }

    private static func embeddedVaultSnapshotSkeleton(referenceLabel: String) -> SkeletonElement {
        let cardModifier = makeModifier {
            $0.padding = 10
            $0.background = "#FCF7FF"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#D8B4FE"
        }

        let chipModifier = makeModifier {
            $0.padding = 6
            $0.background = "#F3E8FF"
            $0.cornerRadius = 999
            $0.fontSize = 11
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#7E22CE"
        }

        let statModifier = makeModifier {
            $0.padding = 8
            $0.background = "#FFFFFF"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#E9D5FF"
        }

        let primaryButton = makeModifier {
            $0.padding = 10
            $0.background = "#F3E8FF"
            $0.cornerRadius = 10
            $0.foregroundColor = "#581C87"
        }

        var title = SkeletonText(text: "Obsidian Vault")
        title.modifiers = makeModifier {
            $0.fontWeight = "semibold"
            $0.fontStyle = "headline"
            $0.foregroundColor = "#111827"
        }

        var subtitle = SkeletonText(text: "Seed notater og les lokal vault-status uten aa forlate den gjeldende flaten.")
        subtitle.modifiers = makeModifier {
            $0.fontSize = 12
            $0.foregroundColor = "#6B21A8"
            $0.lineLimit = 3
        }

        var localChip = SkeletonText(text: "LOCAL")
        localChip.modifiers = chipModifier

        var noteCountLabel = SkeletonText(text: "Notater")
        noteCountLabel.modifiers = makeModifier {
            $0.fontSize = 11
            $0.foregroundColor = "#6B7280"
        }
        var noteCount = SkeletonText(text: "Se state")
        noteCount.modifiers = makeModifier {
            $0.fontStyle = "title3"
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#7E22CE"
        }

        var linkCountLabel = SkeletonText(text: "Lenker")
        linkCountLabel.modifiers = makeModifier {
            $0.fontSize = 11
            $0.foregroundColor = "#6B7280"
        }
        var linkCount = SkeletonText(text: "Se state")
        linkCount.modifiers = makeModifier {
            $0.fontStyle = "title3"
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#9333EA"
        }

        var statusText = SkeletonText(keypath: "\(referenceLabel).vault.state")
        statusText.modifiers = makeModifier {
            $0.fontSize = 12
            $0.foregroundColor = "#4B5563"
            $0.lineLimit = 2
        }

        let seedCapturePayload: ValueType = .object([
            "id": .string("conference-capture"),
            "title": .string("Conference Capture"),
            "content": .string("Notater, navn og oppfolginger fra konferansegulvet."),
            "tags": .list([.string("conference"), .string("notes")]),
            "createdAtEpochMs": .integer(0),
            "updatedAtEpochMs": .integer(0)
        ])

        let seedFollowupPayload: ValueType = .object([
            "id": .string("follow-up-map"),
            "title": .string("Follow-up Map"),
            "content": .string("Neste steg, avtaler og koblinger mellom notater."),
            "tags": .list([.string("followup"), .string("networking")]),
            "createdAtEpochMs": .integer(0),
            "updatedAtEpochMs": .integer(0)
        ])

        var seedCapture = SkeletonButton(
            keypath: "\(referenceLabel).vault.note.create",
            label: "Seed capture",
            payload: seedCapturePayload
        )
        seedCapture.modifiers = primaryButton

        var seedFollowup = SkeletonButton(
            keypath: "\(referenceLabel).vault.note.create",
            label: "Seed follow-up",
            payload: seedFollowupPayload
        )
        seedFollowup.modifiers = primaryButton

        var noteStat = SkeletonVStack(elements: [
            .Text(noteCountLabel),
            .Text(noteCount)
        ])
        noteStat.modifiers = statModifier

        var linkStat = SkeletonVStack(elements: [
            .Text(linkCountLabel),
            .Text(linkCount)
        ])
        linkStat.modifiers = statModifier

        var headerRow = SkeletonHStack(elements: [
            .VStack(SkeletonVStack(elements: [.Text(title), .Text(subtitle)])),
            .Spacer(SkeletonSpacer()),
            .Text(localChip)
        ])
        headerRow.modifiers = makeModifier { $0.padding = 2 }

        var card = SkeletonVStack(elements: [
            .HStack(headerRow),
            .Text(statusText),
            .HStack(SkeletonHStack(elements: [.VStack(noteStat), .VStack(linkStat)])),
            .HStack(SkeletonHStack(elements: [.Button(seedCapture), .Button(seedFollowup)]))
        ])
        card.modifiers = cardModifier

        return .VStack(card)
    }

    private static func embeddedPurposeAssistantSkeleton(referenceLabel: String) -> SkeletonElement {
        let cardModifier = makeModifier {
            $0.padding = 10
            $0.background = "#F8FAFC"
            $0.cornerRadius = 12
            $0.borderWidth = 1
            $0.borderColor = "#CBD5E1"
        }

        let chipModifier = makeModifier {
            $0.padding = 6
            $0.background = "#DBEAFE"
            $0.cornerRadius = 999
            $0.fontSize = 11
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#1D4ED8"
        }

        let listModifier = makeModifier {
            $0.padding = 6
            $0.background = "#FFFFFF"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#D6E0EB"
            $0.height = 150
        }

        let inputModifier = makeModifier {
            $0.padding = 8
            $0.background = "#FFFFFF"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#D6E0EB"
        }

        let primaryButton = makeModifier {
            $0.padding = 10
            $0.background = "#DBEAFE"
            $0.cornerRadius = 10
            $0.foregroundColor = "#1E3A8A"
        }

        let neutralButton = makeModifier {
            $0.padding = 10
            $0.background = "#E2E8F0"
            $0.cornerRadius = 10
            $0.foregroundColor = "#0F172A"
        }

        var title = SkeletonText(text: "AI Purpose Assistant")
        title.modifiers = makeModifier {
            $0.fontWeight = "semibold"
            $0.fontStyle = "headline"
            $0.foregroundColor = "#0F172A"
        }

        var subtitle = SkeletonText(text: "Kjor prompt-matching mot ConfigurationCatalog og last valgt forslag direkte i Porthole.")
        subtitle.modifiers = makeModifier {
            $0.fontSize = 12
            $0.foregroundColor = "#475569"
            $0.lineLimit = 3
        }

        var aiChip = SkeletonText(text: "AI")
        aiChip.modifiers = chipModifier

        var promptCount = SkeletonText(keypath: "\(referenceLabel).matching.state.suggestionCount")
        promptCount.modifiers = makeModifier {
            $0.fontSize = 12
            $0.fontWeight = "semibold"
            $0.foregroundColor = "#1D4ED8"
        }

        let promptField = SkeletonTextField(
            text: nil,
            sourceKeypath: "\(referenceLabel).matching.promptText",
            targetKeypath: "\(referenceLabel).matching.runPromptInput",
            placeholder: "Beskriv hva du vil oppnaa",
            modifiers: inputModifier
        )

        var runPrompt = SkeletonButton(
            keypath: "\(referenceLabel).matching.runPromptInput",
            label: "Kjor prompt"
        )
        runPrompt.modifiers = primaryButton

        var syncCatalog = SkeletonButton(
            keypath: "\(referenceLabel).syncScaffoldPurposeGoals",
            label: "Sync katalog",
            payload: .bool(true)
        )
        syncCatalog.modifiers = neutralButton

        var loadSelected = SkeletonButton(
            keypath: "\(referenceLabel).matching.loadSelectedToPorthole",
            label: "Load valgt",
            payload: .bool(true)
        )
        loadSelected.modifiers = primaryButton

        var bookmarkSelected = SkeletonButton(
            keypath: "\(referenceLabel).matching.bookmarkSelected",
            label: "Bokmerk",
            payload: .bool(true)
        )
        bookmarkSelected.modifiers = neutralButton

        var suggestionName = SkeletonText(keypath: "name")
        suggestionName.modifiers = makeModifier {
            $0.fontWeight = "semibold"
            $0.fontSize = 12
            $0.foregroundColor = "#0F172A"
        }

        var suggestionMeaning = SkeletonText(keypath: "matchMeaning")
        suggestionMeaning.modifiers = makeModifier {
            $0.fontSize = 11
            $0.foregroundColor = "#475569"
            $0.lineLimit = 2
        }

        var suggestionRow = SkeletonVStack(elements: [
            .Text(suggestionName),
            .Text(suggestionMeaning)
        ])
        suggestionRow.modifiers = makeModifier {
            $0.padding = 8
            $0.background = "#FFFFFF"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#DBEAFE"
        }

        var suggestionList = SkeletonList(
            topic: "\(referenceLabel).matching.suggestions",
            keypath: nil,
            flowElementSkeleton: suggestionRow
        )
        suggestionList.filterTypes = ["event"]
        suggestionList.selectionMode = .single
        suggestionList.selectionValueKeypath = "rank"
        suggestionList.selectionStateKeypath = "\(referenceLabel).matching.selectedIndex"
        suggestionList.activationActionKeypath = "\(referenceLabel).matching.loadSelectedToPorthole"
        suggestionList.selectionPayloadMode = .itemID
        suggestionList.allowsEmptySelection = true
        suggestionList.modifiers = listModifier

        var selectedName = SkeletonText(keypath: "name")
        selectedName.modifiers = makeModifier {
            $0.fontWeight = "semibold"
            $0.fontSize = 12
            $0.foregroundColor = "#0F172A"
        }

        var selectedPurpose = SkeletonText(keypath: "purpose")
        selectedPurpose.modifiers = makeModifier {
            $0.fontSize = 11
            $0.foregroundColor = "#475569"
            $0.lineLimit = 2
        }

        var selectedRow = SkeletonVStack(elements: [
            .Text(selectedName),
            .Text(selectedPurpose)
        ])
        selectedRow.modifiers = makeModifier {
            $0.padding = 8
            $0.background = "#FFFFFF"
            $0.cornerRadius = 10
            $0.borderWidth = 1
            $0.borderColor = "#BFDBFE"
        }

        var selectedSuggestion = SkeletonList(
            topic: "\(referenceLabel).matching.selectedSuggestion",
            keypath: nil,
            flowElementSkeleton: selectedRow
        )
        selectedSuggestion.filterTypes = ["event"]
        selectedSuggestion.modifiers = listModifier

        var headerRow = SkeletonHStack(elements: [
            .VStack(SkeletonVStack(elements: [.Text(title), .Text(subtitle)])),
            .Spacer(SkeletonSpacer()),
            .VStack(SkeletonVStack(elements: [.Text(aiChip), .Text(promptCount)]))
        ])
        headerRow.modifiers = makeModifier { $0.padding = 2 }

        var card = SkeletonVStack(elements: [
            .HStack(headerRow),
            .TextField(promptField),
            .HStack(SkeletonHStack(elements: [.Button(runPrompt), .Button(syncCatalog)])),
            .List(suggestionList),
            .List(selectedSuggestion),
            .HStack(SkeletonHStack(elements: [.Button(loadSelected), .Button(bookmarkSelected)]))
        ])
        card.modifiers = cardModifier

        return .VStack(card)
    }

    private static func makeModifier(_ configure: (inout SkeletonModifiers) -> Void) -> SkeletonModifiers {
        var modifiers = SkeletonModifiers()
        configure(&modifiers)
        return modifiers
    }
}

struct ComponentDragPreviewCard: View {
    let item: ComponentPaletteItem
    let onActivate: (ComponentPaletteItem) -> Void
    let onDeactivate: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: item.icon)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: 220, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
        )
        .onAppear {
            onActivate(item)
        }
        .onDisappear {
            onDeactivate()
        }
    }
}
