import SwiftUI
import Combine
import CellBase
import CellApple
import UniformTypeIdentifiers
import ImageIO

@MainActor
final class NearbyScannerSurfaceModel: ObservableObject {
    @Published var radar: ValueType = .object([:])
    @Published var publication: NearbyAdvertisement?
    @Published var error: String?
    private var scanner: Meddle?
    private var identity: Identity?

    var accessChallenge: NearbyAccessChallenge? {
        guard case let .object(snapshot) = radar, let value = snapshot["accessChallenge"] else { return nil }
        return (try? JSONEncoder().encode(value)).flatMap { try? JSONDecoder().decode(NearbyAccessChallenge.self, from: $0) }
    }

    func submitEvidence(_ evidence: NearbyAccessEvidence, challenge: NearbyAccessChallenge) async -> Bool {
        guard let value = try? JSONDecoder().decode(ValueType.self, from: JSONEncoder().encode(evidence)) else { return false }
        return await action("submitAdvertisementProof", .object([
            "remoteUUID": .string(challenge.publisherSessionID),
            "policyDigest": .string(challenge.policy.digest), "evidence": value
        ]))
    }

    func run() async {
        guard await BindingLocalCellRegistration.shared.ensureConferenceDemoRuntimeReady(),
              let resolver = CellBase.defaultCellResolver,
              let vault = CellBase.defaultIdentityVault,
              let identity = await vault.identity(for: "private", makeNewIfNotFound: true) else {
            error = "Scanneren er ikke tilgjengelig ennå."; return
        }
        do {
            self.identity = identity
            scanner = try await resolver.cellAtEndpoint(endpoint: "cell:///EntityScanner", requester: identity) as? Meddle
            while !Task.isCancelled {
                await refresh()
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
        } catch is CancellationError { } catch { self.error = "Kunne ikke hente scanneren: \(error.localizedDescription)" }
    }

    func refresh() async {
        guard let scanner, let identity else { return }
        do {
            radar = try await scanner.get(keypath: "radar", requester: identity)
            let value = try await scanner.get(keypath: "advertisement", requester: identity)
            publication = (try? JSONEncoder().encode(value)).flatMap { try? JSONDecoder().decode(NearbyAdvertisement.self, from: $0) }
        } catch { self.error = "Kunne ikke oppdatere radaren." }
    }

    @discardableResult
    func action(_ key: String, _ value: ValueType) async -> Bool {
        guard let scanner, let identity else { error = "Scanneren er ikke klar."; return false }
        do {
            let result = try await scanner.set(keypath: key, value: value, requester: identity)
            if case let .string(status)? = result, ["denied", "failure", "notFound", "conferenceAuthorityUnavailable"].contains(status) {
                error = status == "conferenceAuthorityUnavailable" ? "Konferansedeling krever en verifisert deltakerkilde." : "Handlingen kunne ikke utføres."
                return false
            }
            error = nil; await refresh(); return true
        } catch { self.error = "Handlingen feilet: \(error.localizedDescription)"; return false }
    }

    func publish(_ advertisement: NearbyAdvertisement) async -> Bool {
        do {
            try advertisement.validate()
            let value = try JSONDecoder().decode(ValueType.self, from: JSONEncoder().encode(advertisement))
            return await action("publishAdvertisement", value)
        } catch { self.error = "Kontroller feltene. Maks seks formål og seks interesser, med korte navn."; return false }
    }
}

struct NearbyScannerSurfaceView: View {
    @StateObject private var model = NearbyScannerSurfaceModel()
    @State private var showingPublication = false
    @State private var showingProof = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ViewThatFits(in: .horizontal) {
                    HStack { title; Spacer(); controls }
                    VStack(alignment: .leading, spacing: 12) { title; controls }
                }
                NearbyRadarSurface(value: model.radar) { id in
                    Task { await model.action("select", .string(id)) }
                }
                if let challenge = model.accessChallenge {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(challenge.policy.title).font(.headline)
                        ForEach(Array(challenge.policy.conditionNames.enumerated()), id: \.offset) { _, name in
                            Label(name, systemImage: "checkmark.shield")
                        }
                        Button("Legg til bevis …") { showingProof = true }
                            .accessibilityIdentifier("nearby.proof")
                    }
                }
                if let error = model.error { Text(error).font(.caption).foregroundStyle(.red) }
            }
            .padding(20)
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
        }
        .task { await model.run() }
        .sheet(isPresented: $showingPublication) {
            NearbyAdvertisementEditor(model: model)
        }
        .sheet(isPresented: $showingProof) {
            if let challenge = model.accessChallenge { NearbyProofEditor(model: model, challenge: challenge) }
        }
    }
    private var title: some View { Text("I nærheten").font(.title2.weight(.semibold)) }
    private var controls: some View {
        HStack(spacing: 10) {
            Button("Start") { Task { await model.action("start", .bool(true)) } }
                .accessibilityIdentifier("nearby.start")
            Button("Stopp") { Task { await model.action("stop", .bool(true)) } }
                .accessibilityIdentifier("nearby.stop")
            Button(model.publication == nil ? "Del detaljer" : "Min deling") { showingPublication = true }
                .accessibilityIdentifier("nearby.sharing")
        }.buttonStyle(.bordered)
    }
}

private struct NearbyAdvertisementEditor: View {
    @ObservedObject var model: NearbyScannerSurfaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var purposes = ""
    @State private var interests = ""
    @State private var thumbnail: Data?
    @State private var importingImage = false
    @State private var error: String?
    @State private var saving = false
    @State private var useConditions = false
    @State private var accessAgreement: NearbyAccessAgreement?
    @State private var importingAgreement = false
    @State private var agreementDomain = ""
    @State private var verifierDID = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Det du annonserer").font(.title2)
                Spacer()
                Button("Lukk") { dismiss() }.disabled(saving)
            }
            Text("Velg et kort utdrag. Resten av profilen og dine private formål deles ikke.")
                .font(.subheadline).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Navn som skal vises", text: $name).textFieldStyle(.roundedBorder)
                    field("Formål", text: $purposes, hint: "Ett per linje, opptil seks")
                    field("Interesser", text: $interests, hint: "Ett per linje, opptil seks")
                    HStack {
                        Button(thumbnail == nil ? "Legg til bilde …" : "Bytt bilde …") { importingImage = true }
                        if thumbnail != nil { Button("Fjern bilde") { thumbnail = nil } }
                    }
                    if let data = thumbnail, let source = CGImageSourceCreateWithData(data as CFData, nil),
                       let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                        Image(decorative: cgImage, scale: 1).resizable().scaledToFit().frame(height: 80)
                    }
                    Picker("Synlig for", selection: $useConditions) {
                        Text("Alle i nærheten").tag(false)
                        Text("De som oppfyller vilkårene").tag(true)
                    }
                    if useConditions {
                        TextField("Agreement-domene", text: $agreementDomain).textFieldStyle(.roundedBorder)
                        TextField("DID til bevismyndigheten du stoler på", text: $verifierDID).textFieldStyle(.roundedBorder)
                        Button("Importer Agreement …") { importingAgreement = true }
                        if let accessAgreement {
                            Text(accessAgreement.title).font(.headline)
                            ForEach(Array(accessAgreement.conditionNames.enumerated()), id: \.offset) { _, name in Text(name).font(.subheadline) }
                        }
                        Text("Gruppemedlemskap, relasjoner og andre krav uttrykkes som Conditions. Alle vilkårene må dekkes av gyldig, signert tilgang fra den valgte myndigheten. Vilkårene vises til den som ber om innsyn.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text(useConditions
                        ? "Utdraget utleveres først etter godkjent bevis. Delingen varer i opptil åtte timer og trekkes tilbake når scanneren stoppes."
                        : "Utdraget kan leses av HAVEN-enheter som oppdager deg på lokalnettet. Delingen varer i opptil åtte timer og trekkes tilbake når scanneren stoppes.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Kopier som allerede er mottatt kan ikke hentes tilbake.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let error = error ?? model.error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                if model.publication != nil {
                    Button("Trekk tilbake") {
                        Task { if await model.action("withdrawAdvertisement", .bool(true)) { dismiss() } }
                    }.disabled(saving)
                }
                Spacer()
                Button(saving ? "Deler …" : "Del dette utdraget") { save() }
                    .buttonStyle(.borderedProminent).disabled(saving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(minWidth: 300, idealWidth: 470, maxWidth: 580, minHeight: 420, idealHeight: 650)
        .onAppear {
            if let ad = model.publication {
                name = ad.displayName; purposes = ad.purposes.values.sorted().joined(separator: "\n")
                interests = ad.interests.values.sorted().joined(separator: "\n"); thumbnail = ad.thumbnail
                accessAgreement = ad.accessAgreement; useConditions = ad.accessAgreement != nil
                agreementDomain = ad.accessAgreement?.domain ?? ""; verifierDID = ad.accessAgreement?.verifierDID ?? ""
            }
        }
        .fileImporter(isPresented: $importingImage, allowedContentTypes: [.image]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                thumbnail = try Self.makeThumbnail(url)
                error = nil
            } catch { self.error = "Bildet kunne ikke brukes. Velg et vanlig bilde under 10 MB." }
        }
        .fileImporter(isPresented: $importingAgreement, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 65_536 else { throw NearbyAccessAgreement.AccessError.invalidPolicy }
                let policy = try NearbyAccessAgreement.importing(Data(contentsOf: url), domain: agreementDomain, verifierDID: verifierDID)
                accessAgreement = policy; agreementDomain = policy.domain; verifierDID = policy.verifierDID; error = nil
            } catch { self.error = "Avtalen kunne ikke brukes. Oppgi domene og bevismyndighet, og velg en Agreement med støttede Conditions." }
        }
    }

    private func field(_ title: String, text: Binding<String>, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.medium))
            TextEditor(text: text).frame(height: 70).border(.secondary.opacity(0.2))
                .accessibilityLabel(title)
            Text(hint).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func save() {
        do {
            var policy: NearbyAccessAgreement?
            if useConditions {
                guard var selected = accessAgreement else { throw NearbyAccessAgreement.AccessError.invalidPolicy }
                selected.domain = agreementDomain; selected.verifierDID = verifierDID
                try selected.validate(); policy = selected
            }
            let ad = NearbyAdvertisement(displayName: name.trimmingCharacters(in: .whitespacesAndNewlines),
                purposes: try Self.entries(purposes, kind: "purpose"), interests: try Self.entries(interests, kind: "interest"),
                scope: useConditions ? .agreement : .nearby, scopeID: policy?.domain,
                thumbnail: thumbnail, expiresAt: Date().timeIntervalSince1970 + NearbyAdvertisement.maximumLifetime, accessAgreement: policy)
            try ad.validate(); saving = true; error = nil
            Task { if await model.publish(ad) { dismiss() }; saving = false }
        } catch { self.error = useConditions ? "Kontroller vilkår, domene og bevismyndighet. Bruk opptil seks formål og seks interesser." : "Bruk opptil seks ulike, korte formål og seks interesser." }
    }

    private static func entries(_ text: String, kind: String) throws -> [String: String] {
        let labels = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard labels.count <= NearbyAdvertisement.maximumEntries else { throw NearbyAdvertisement.ValidationError.invalidEntries }
        var result = [String: String]()
        for label in labels {
            guard let key = PortableReference.make(kind: kind, localReference: nil, name: label), result[key] == nil else {
                throw NearbyAdvertisement.ValidationError.invalidEntries
            }
            result[key] = label
        }
        return result
    }

    private static func makeThumbnail(_ url: URL) throws -> Data {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
        guard size <= 10_000_000, let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 192
              ] as CFDictionary) else { throw NearbyAdvertisement.ValidationError.invalidImage }
        // Encode fresh pixels, deliberately omitting original EXIF/GPS metadata.
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw NearbyAdvertisement.ValidationError.invalidImage
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.65] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw NearbyAdvertisement.ValidationError.invalidImage }
        let result = data as Data
        try NearbyAdvertisement.validateThumbnail(result)
        return result
    }
}

private struct NearbyProofEditor: View {
    @ObservedObject var model: NearbyScannerSurfaceModel
    let challenge: NearbyAccessChallenge
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false
    @State private var evidence: NearbyAccessEvidence?
    @State private var error: String?
    @State private var sending = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Bevis for tilgang").font(.title2); Spacer(); Button("Lukk") { dismiss() } }
            Text(challenge.policy.title).font(.headline)
            ForEach(Array(challenge.policy.conditionNames.enumerated()), id: \.offset) { _, name in Text(name) }
            Text("Velg en signert tilgangsavtale (Contract) fra Agreement. Bare bevisene du velger sendes, sammen med en signatur som viser at de tilhører din identitet.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button("Velg bevisfil …") { importing = true }
            if let evidence { Text("\(evidence.contracts.count) signerte tilgangsavtaler valgt").font(.caption) }
            if let error = error ?? model.error { Text(error).foregroundStyle(.red).font(.caption) }
            Button(sending ? "Sender …" : "Bruk dette beviset") {
                guard let evidence else { return }; sending = true
                Task { if await model.submitEvidence(evidence, challenge: challenge) { dismiss() }; sending = false }
            }.buttonStyle(.borderedProminent).disabled(evidence == nil || sending)
        }.padding(22).frame(minWidth: 300, idealWidth: 470, maxWidth: 580)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get(); let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 196_608 else { throw NearbyAccessAgreement.AccessError.invalidProof }
                evidence = try NearbyAccessEvidence.importing(Data(contentsOf: url)); error = nil
            } catch { self.error = "Filen inneholder ikke et lesbart bevis."; evidence = nil }
        }
    }
}
