import SwiftUI
import Combine
import CellBase
#if os(macOS)
import AppKit
#endif

/// A fresh client for one explicitly selected receipt. Selection never signs
/// proofs or starts a read; closing the view discards its transient result.
@MainActor
final class PersonEntityReadViewModel: ObservableObject {
    struct Connection {
        var connect: () async throws -> Void
        var read: ([String]) async throws -> PersonEntityReadResult
        var close: () async -> Void
    }
    enum Phase { case idle, connecting, ready, reading, failed }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var result: PersonEntityReadResult?
    @Published private(set) var message = "Velg en lagret kobling."
    private var connection: Connection?
    private var operation: Task<Void, Never>?
    private var generation = UUID()
    var hasSelection: Bool { connection != nil }
    var isBusy: Bool { phase == .connecting || phase == .reading }

    func select(entry: IdentityLinkCompletionStore.Entry?) {
        guard let entry else { select(connection: nil); return }
        let client = PersonEntityReadClient()
        select(connection: Connection(connect: { try await client.connect(entry: entry) },
            read: { try await client.read(keypaths: $0) }, close: { await client.close() }))
    }

    func select(connection newConnection: Connection?) {
        generation = UUID()
        operation?.cancel(); operation = nil
        if let previous = connection { Task { await previous.close() } }
        connection = newConnection
        phase = .idle; result = nil
        message = newConnection == nil ? "Velg en lagret kobling." : "Kobling valgt. Kontroller tilgangen før du leser."
    }

    func connect() {
        guard let connection, phase == .idle else { return }
        let attempt = generation
        phase = .connecting; message = "Kontrollerer kobling og tilgang …"
        operation = Task {
            do {
                try await connection.connect()
                try Task.checkCancellation()
                guard generation == attempt else { return }
                phase = .ready; message = "Koblingen er kontrollert. Velg hvilke opplysninger du vil lese."
                operation = nil
            } catch {
                await connection.close()
                guard generation == attempt else { return }
                phase = .failed; result = nil; operation = nil
                message = "Tilgangen ble avvist eller forbindelsen kunne ikke opprettes. Kontroller koblingen og prøv igjen."
            }
        }
    }

    static func keypaths(from text: String) -> [String]? {
        let paths = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard (1...16).contains(paths.count), paths.allSatisfy({ $0.utf8.count <= 1024 }) else { return nil }
        return paths
    }

    func read(_ text: String) {
        guard let connection, phase == .ready, let paths = Self.keypaths(from: text) else { return }
        let attempt = generation
        result = nil; phase = .reading; message = "Leser valgte opplysninger …"
        operation = Task {
            do {
                let reply = try await connection.read(paths)
                try Task.checkCancellation()
                guard generation == attempt else { return }
                result = reply; phase = .ready; operation = nil
                switch reply.status {
                case .complete: message = "Alle valgte opplysninger ble lest."
                case .partial: message = "Bare noen av de valgte opplysningene kunne leses."
                case .denied: message = "Tilgang til de valgte opplysningene ble avvist."
                case .unavailable: message = "De valgte opplysningene er ikke tilgjengelige."
                }
            } catch {
                await connection.close()
                guard generation == attempt else { return }
                result = nil; phase = .failed; operation = nil
                message = "Lesingen kunne ikke fullføres. Kontroller koblingen på nytt."
            }
        }
    }

    func disconnect() { select(connection: nil) }
}

struct PersonEntityReadView: View {
    @StateObject private var model = PersonEntityReadViewModel()
    @State private var entries: [IdentityLinkCompletionStore.Entry] = []
    @State private var selected = ""
    @State private var paths = ""
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Opplysninger fra min entitet") {
                Text("Velg en tidligere godkjent kobling til et scaffold. Tilgangen kontrolleres med appens eksisterende identitet.")
                Picker("Lagret kobling", selection: $selected) {
                    Text("Velg kobling").tag("")
                    ForEach(entries, id: \.record.linkID) { entry in
                        Text("\(entry.origin) · \(entry.record.linkedAt)").tag(entry.record.linkID)
                    }
                }
                if entries.isEmpty {
                    Text("Ingen personkobling er lagret på denne enheten.")
                }
                HStack {
                    Button("Utvid min entitet …") {
                        clear(); dismiss()
                        IdentityLinkFlowPresenter.shared.presentScanner()
                    }
                    Button("Oppdater koblinger") { reload() }
                }
                if let entry = entries.first(where: { $0.record.linkID == selected }) {
                    Text("Tilgangskontrollen sendes til \(entry.origin).")
                    Button(model.phase == .failed ? "Kontroller på nytt" : "Kontroller tilgang") {
                        if model.phase == .failed { model.select(entry: entry) }
                        model.connect()
                    }.disabled(model.isBusy || model.phase == .ready)
                }
            }
            Section("Les valgte opplysninger") {
                Text("Skriv ett feltnavn (keypath) per linje, opptil 16. Scaffoldet avgjør hvilke felt du har tilgang til.")
                TextEditor(text: $paths).frame(minHeight: 70, maxHeight: 130)
                    .accessibilityLabel("Felter som skal leses")
                HStack {
                    Button("Les opplysninger") { model.read(paths) }
                        .disabled(model.phase != .ready || PersonEntityReadViewModel.keypaths(from: paths) == nil)
                    Button("Koble fra og tøm") { clear() }.disabled(!model.hasSelection)
                }
                Text(model.message).accessibilityIdentifier("person-entity-read-status")
                if let result = model.result {
                    Text("Svarene er enkeltavlesninger, ikke et samlet øyeblikksbilde. De beholdes bare i dette vinduet.")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(result.fragments, id: \.requestID) { fragment in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(fragment.keypath).font(.headline)
                            if fragment.status == .available, let value = fragment.value {
                                Text(Self.display(value)).font(.system(.body, design: .monospaced))
                                if let origin = fragment.sourceOrigin { Text("Kilde: \(origin)").font(.caption) }
                            } else {
                                Text(fragment.status == .denied ? "Tilgang avvist" : "Ikke tilgjengelig")
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, idealWidth: 640, minHeight: 520)
        .onAppear { reload() }
        .onChange(of: selected) { _, value in
            model.select(entry: entries.first { $0.record.linkID == value })
        }
        .onDisappear { clear() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { clear() } }
        #if os(macOS)
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.sessionDidResignActiveNotification)) { _ in clear() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)) { _ in clear() }
        #endif
    }
    private func clear() { model.disconnect(); selected = ""; paths = "" }
    private func reload() {
        clear()
        entries = IdentityLinkCompletionStore.entries().filter { $0.record.status == .active }
    }
    private static func display(_ value: ValueType) -> String {
        if case let .string(text) = value { return text }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value), let text = String(data: data, encoding: .utf8) else { return "Verdien kunne ikke vises." }
        return text
    }
}

#if os(macOS)
struct PersonEntityReadCommand: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Opplysninger fra min entitet …") { openWindow(id: "person-entity-read") }
    }
}
#endif
