import Foundation
import SwiftUI
import CellBase

/// Debug-only presentation fixture: no user vault, local runtime or network
/// mutation. The same production view renders a synthetic unsigned invitation.
nonisolated enum IdentityLinkUIFixture {
    static var enabled: Bool {
        #if DEBUG && os(macOS)
        ProcessInfo.processInfo.arguments.contains("--binding-person-link-ui-test")
            || Bundle.main.bundleIdentifier == "org.digipomps.haven.person-link-ui-test"
        #else
        false
        #endif
    }
}

#if DEBUG && os(macOS)
actor IdentityLinkUIFixtureOutbox: IdentityLinkOutbox {
    func load() -> IdentityLinkPendingCompletion? { nil }
    func save(_ entry: IdentityLinkPendingCompletion) throws { throw IdentityLinkOutboxError.invalidFile }
    func remove(requestID: String) {}
}

struct IdentityLinkUIFixtureView: View {
    @ObservedObject private var presenter = IdentityLinkFlowPresenter.shared
    var body: some View {
        Text("Isolert personkoblingstest")
            .frame(width: 560, height: 780)
            .sheet(isPresented: Binding(get: { presenter.isPresented }, set: { if !$0 { presenter.dismiss() } })) {
                IdentityLinkFlowView()
            }
            .task {
                let origin = "https://staging.haven.digipomps.org"
                let ticket = IdentityLinkTicket(schema: IdentityLinkTicket.currentSchema, ticketID: "synthetic-ui-only",
                    audience: "staging.haven.digipomps.org", origin: origin,
                    entityBinding: .init(mode: .localEntityAnchor, entityAnchorReference: "cell:///EntityAnchor", audience: "staging.haven.digipomps.org"),
                    rendezvousURL: origin + "/link/api", nonce: Data(repeating: 1, count: 32),
                    expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(300)),
                    presentationChallenge: Data(repeating: 2, count: 32), presentationDomain: origin,
                    ownerDisplayName: "Syntetisk person", approverLabel: "Syntetisk nettleser")
                if let data = try? IdentityLinkWire.encoder.encode(ticket),
                   let url = URL(string: "haven://identity-link?t=" + IdentityLinkWire.base64URL(data)) {
                    presenter.handle(url: url)
                }
            }
    }
}
#endif
