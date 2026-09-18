import Foundation
import SwiftUI
import Combine
import CellNearby

/// Never follow redirects while resolving an untrusted discovery reference.
nonisolated final class IdentityLinkNoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@MainActor
final class IdentityLinkNearbyModel: ObservableObject {
    static let shared = IdentityLinkNearbyModel()
    @Published var offers: [NearbyLinkOffer] = []
    @Published var state: NetworkLinkDiscovery.State = .stopped
    @Published var publication: NearbyLinkOffer?
    @Published var error: String?
    @Published var fetching = false
    private var attempt = UUID()
    private var task: Task<Void, Never>?
    private let discovery = NetworkLinkDiscovery(trustedOrigins: IdentityLinkTrust.trustedOrigins)

    private init() {
        discovery.onChange = { [weak self] offers, state in
            self?.offers = offers
            self?.state = state
        }
    }

    func browse() {
        stop()
        discovery.browse()
    }

    func reviewPublication(_ url: URL) {
        stop()
        do { publication = try NearbyLinkOffer.decodePublicationLink(url, trustedOrigins: IdentityLinkTrust.trustedOrigins) }
        catch { self.error = "Invitasjonen er ugyldig eller utløpt. Lag en ny der den andre entiteten er." }
    }

    func advertise() {
        guard let publication else { return }
        do { try discovery.advertise(publication); self.publication = nil }
        catch { self.error = "Kunne ikke gjøre invitasjonen synlig. Bruk QR-koden." }
    }

    func choose(_ offer: NearbyLinkOffer) {
        do { _ = try discovery.select(offer) }
        catch { self.error = "Invitasjonen er ikke lenger tilgjengelig."; return }
        let token = UUID()
        attempt = token
        fetching = true
        task = Task {
            do {
                try offer.validate(trustedOrigins: IdentityLinkTrust.trustedOrigins)
                guard let url = offer.fetchURL else { throw NearbyLinkOffer.ValidationError.invalidOrigin }
                let config = URLSessionConfiguration.ephemeral
                config.timeoutIntervalForRequest = 15
                config.httpShouldSetCookies = false
                let session = URLSession(configuration: config, delegate: IdentityLinkNoRedirectDelegate(), delegateQueue: nil)
                defer { session.invalidateAndCancel() }
                var request = URLRequest(url: url)
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                let (data, response) = try await session.data(for: request)
                guard !Task.isCancelled, attempt == token else { return }
                guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                      response.url == url, data.count <= 32 * 1024 else { throw NearbyLinkOffer.ValidationError.invalidEncoding }
                struct TicketResponse: Decodable { let deepLink: String }
                let payload = try JSONDecoder().decode(TicketResponse.self, from: data)
                let ticket = try IdentityLinkTicket.decode(deepLink: payload.deepLink)
                guard ticket.origin == offer.origin else { throw NearbyLinkOffer.ValidationError.untrustedOrigin }
                fetching = false
                // Existing signature/request/control-word/passkey flow is the only authority path.
                await IdentityLinkFlowCoordinator.shared.review(deepLink: payload.deepLink)
            } catch {
                guard attempt == token, !Task.isCancelled else { return }
                fetching = false
                self.error = "Invitasjonen kunne ikke hentes sikkert. Prøv QR eller lag en ny invitasjon."
            }
        }
    }

    func stop() {
        attempt = UUID()
        task?.cancel(); task = nil
        discovery.stop()
        publication = nil
        fetching = false
        error = nil
    }
}

struct IdentityLinkNearbyPanel: View {
    @ObservedObject var model: IdentityLinkNearbyModel
    @Environment(\.openURL) private var openURL
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let offer = model.publication {
                Text("Gjør invitasjonen til entiteten din på \(offer.origin) synlig i nærheten?")
                Text("Andre i nærheten kan hente invitasjonen og se entitetens visningsnavn. Du godkjenner fortsatt koblingen fra den andre entiteten. Synligheten stopper senest etter fem minutter.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Gjør synlig") { model.advertise() }
                    Button("Avbryt") { model.stop() }
                }
            } else {
                HStack {
                    Button("Finn i nærheten") { model.browse() }.disabled(model.fetching)
                    if model.state != .stopped { Button("Stopp") { model.stop() } }
                    Menu("Mine entiteter") {
                        Button("Produksjon") { openURL(URL(string: "https://haven.digipomps.org/link")!) }
                        Button("Staging") { openURL(URL(string: "https://staging.haven.digipomps.org/link")!) }
                    }
                }
                if model.fetching { ProgressView("Henter invitasjonen …") }
                if model.state == .browsing { Text("Leter etter invitasjoner. Åpne «Finn på telefonen» der den andre entiteten din er.").font(.caption) }
                if model.state == .advertising { Text("Invitasjonen er synlig i nærheten.").font(.caption) }
                if case let .unavailable(message) = model.state { Text(message).font(.caption) }
                ForEach(model.offers) { offer in
                    Button("Se invitasjon fra \(offer.origin) · \(offer.offerID.prefix(6))") { model.choose(offer) }
                }
            }
            if let error = model.error { Text(error).foregroundStyle(.red).font(.caption) }
        }
        .padding()
    }
}
