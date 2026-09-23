import SwiftUI
import UniformTypeIdentifiers
import CellBase
import CellApple

/// Native owner approval, deliberately outside Skeleton, chat, Flow and generic tool execution.
struct DatabaseKeyCustodyView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var handles: [AppleDatabaseSecretHandle] = []
    @State private var selected = ""
    @State private var approval: DatabaseOwnerApprovalPackage?
    @State private var importing = false
    @State private var exporting = false
    @State private var output = CustodyDocument()
    @State private var status = "Ingen database er åpnet."
    @State private var task: Task<Void, Never>?
    private static let metadataDirectory: URL = {
        if ProcessInfo.processInfo.arguments.contains("--haven-ephemeral-identity") ||
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return FileManager.default.temporaryDirectory.appendingPathComponent("DatabaseCustodyTests-" + UUID().uuidString)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DatabaseKeyCustody", isDirectory: true)
    }()
    private static let approvals = AppleDatabaseOwnerApproval(directory: metadataDirectory.appendingPathComponent("Versions"))
    private var directory: URL { Self.metadataDirectory }
    var body: some View {
        Form {
            Section("Private celledata") {
                Text("Databasen tilhører én celle. Godkjenn bare tjenester du stoler på: prosessen som åpner databasen kan lese dataene. En lagringsadministrator får ingen automatisk nøkkeltilgang.")
                Text("Opplåsingsnøkler lagres i denne enhetens Keychain og krever lokal brukerautorisasjon. Opprett en uavhengig recovery-mottaker på en annen betrodd enhet før eldre nøkler tas ut av bruk.")
            }
            Section("Denne enhetens mottakere") {
                Picker("Nøkkelhåndtak", selection: $selected) {
                    Text("Velg mottaker").tag("")
                    ForEach(handles) { handle in Text(handle.id).tag(handle.id) }
                }
                Button("Opprett ny Keychain-mottaker") { run {
                    let handle = try await AppleDatabaseSecretHandle.create()
                    handles.append(handle); selected = handle.id
                    try saveHandles()
                    status = "Mottaker opprettet. Eksporter den offentlige referansen til eierens oppsett."
                } }
                Button("Eksporter offentlig mottaker") { run {
                    guard let handle = handles.first(where: { $0.id == selected }) else { throw SecretCredentialError.missing }
                    output = CustodyDocument(data: try JSONEncoder().encode(handle.recipient)); exporting = true
                } }.disabled(selected.isEmpty)
            }
            Section("Godkjenn databasebruk") {
                Button("Åpne signert forespørsel …") { importing = true }
                if let approval {
                    let s = approval.request.scope
                    LabeledContent("Celle", value: s.context.cellUUID)
                    LabeledContent("Database", value: s.filename)
                    LabeledContent("Tjenesteidentitet", value: s.runtimeFingerprint)
                    LabeledContent("Tjeneste", value: s.audience)
                    LabeledContent("Formål", value: s.purpose)
                    LabeledContent("Tilgang", value: "Lese og skrive")
                    LabeledContent("Nøkkel/policy", value: "\(s.context.keyVersion) / \(s.context.policyVersion)")
                    LabeledContent("Hemmelighetsvert", value: approval.secretEndpoint.host ?? "")
                    Text("Utløper \(Date(timeIntervalSince1970: TimeInterval(s.expiresAt)).formatted())")
                    Button("Godkjenn med Keychain og eksporter engangstilgang") { run {
                        guard let owner = await BindingStartupIdentityVault.shared.identity(for: s.context.domain, makeNewIfNotFound: false),
                              let handle = handles.first(where: { $0.id == selected }) else { throw SecretCredentialError.denied }
                        let grant = try await Self.approvals
                            .approve(approval, owner: owner, handle: handle)
                        try Task.checkCancellation()
                        output = CustodyDocument(data: try JSONEncoder().encode(grant)); exporting = true
                        self.approval = nil
                        status = "Tilgangen er kryptert til den godkjente tjenesten og gjelder bare denne filen."
                    } }.disabled(selected.isEmpty || task != nil)
                    Text("Utløp stopper en korrekt runtime. En tjeneste som allerede har fått nøkkelen eller klartekst kan beholde en kopi. Ved kompromittering må datanøkkelen roteres.")
                }
                Button("Lås og avbryt lokal godkjenning") { lock() }
                Text(status).accessibilityIdentifier("database-custody-status")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, idealWidth: 640, minHeight: 560)
        .task { loadHandles() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { lock() } }
        .onDisappear { lock() }
#if os(macOS)
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.sessionDidResignActiveNotification)) { _ in lock() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)) { _ in lock() }
#endif
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in run {
            let url = try result.get(); let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
            guard size <= 65_536 else { throw SecretCredentialError.invalidContract }
            let candidate = try JSONDecoder().decode(DatabaseOwnerApprovalPackage.self, from: Data(contentsOf: url))
            guard let owner = await BindingStartupIdentityVault.shared.identity(for: candidate.record.context.domain, makeNewIfNotFound: false) else {
                throw SecretCredentialError.denied
            }
            try candidate.validate(owner: owner)
            approval = candidate; status = "Kontroller identitet, database og formål før du godkjenner."
        } }
        .fileExporter(isPresented: $exporting, document: output, contentType: .json, defaultFilename: "database-custody") { result in
            output = CustodyDocument()
            if case .failure = result { status = "Eksporten ble ikke fullført." }
        }
    }
    private func run(_ operation: @escaping @MainActor () async throws -> Void) {
        guard task == nil else { return }
        task = Task { @MainActor in
            defer { task = nil }
            do { try await operation() }
            catch { status = "Operasjonen ble avvist eller kunne ikke fullføres. Ingen ny tilgang er gitt." }
        }
    }
    private func lock() {
        task?.cancel(); approval = nil; output = CustodyDocument(); exporting = false
        status = "Låst. Eventuell allerede eksportert tjenestetilgang må låses i tjenesten."
    }
    private func saveHandles() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let url = directory.appendingPathComponent("handles.json")
        try JSONEncoder().encode(handles).write(to: url, options: [.atomic, .completeFileProtection])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    private func loadHandles() {
        let file = directory.appendingPathComponent("handles.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        do { handles = try JSONDecoder().decode([AppleDatabaseSecretHandle].self, from: Data(contentsOf: file)) }
        catch { status = "Lagrede mottakerreferanser kan ikke leses. De eksisterende nøklene blir ikke erstattet." }
    }
}

private struct CustodyDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data = Data()
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
