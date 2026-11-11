import XCTest
import SwiftUI
import AppKit
import CellBase
@testable import Binding

/// Opt-in screenshots of the actual production view. Assigning presentation
/// state never submits a ticket, performs passkey approval or changes a link.
@MainActor
final class IdentityLinkAppearanceTests: XCTestCase {
    func testRenderLinkStatesInLightAndDarkAppearance() async throws {
        guard let directory = ProcessInfo.processInfo.environment["HAVEN_LINK_APPEARANCE_OUTPUT"] else {
            throw XCTSkip("Opt-in visual review: set HAVEN_LINK_APPEARANCE_OUTPUT")
        }
        let output = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let presenter = IdentityLinkFlowPresenter.shared
        try await Task.sleep(for: .milliseconds(100))
        let previous = presenter.state
        defer { presenter.state = previous }
        let origin = "https://staging.haven.digipomps.org"
        let ticket = IdentityLinkTicket(schema: IdentityLinkTicket.currentSchema, ticketID: "appearance-only",
            audience: "staging.haven.digipomps.org", origin: origin,
            entityBinding: .init(mode: .localEntityAnchor, entityAnchorReference: "cell:///EntityAnchor", audience: "staging.haven.digipomps.org"),
            rendezvousURL: origin + "/link/api", nonce: Data(repeating: 1, count: 32),
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(300)),
            presentationChallenge: Data(repeating: 2, count: 32), presentationDomain: origin,
            ownerDisplayName: "Syntetisk testperson", approverLabel: "Testnettleseren")
        let states: [(String, IdentityLinkFlowState)] = [
            ("review", .reviewing(ticket: ticket)),
            ("words", .awaitingApproval(ticket: ticket, sas: ["rogn", "flue", "salt", "blomst"], requestHash: "synthetic")),
            ("recovery", .recovery(ticket: ticket, message: "Godkjenningen er mottatt, men lokal aktivering må prøves igjen.", canRetry: true)),
            ("failure", .failed(message: "Koden er utløpt. Lag en ny invitasjon og prøv igjen."))
        ]
        for (mode, scheme, appearance) in [("light", ColorScheme.light, NSAppearance.Name.aqua), ("dark", .dark, .darkAqua)] {
            for (sizeName, width, height) in [("regular", 520.0, 720.0), ("compact", 440.0, 620.0)] {
                for (name, state) in states {
                    presenter.state = state
                    let view = IdentityLinkFlowView().environment(\.colorScheme, scheme).frame(width: width, height: height)
                    let hosting = NSHostingView(rootView: view)
                    hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
                    let window = NSWindow(contentRect: hosting.frame, styleMask: [.titled], backing: .buffered, defer: false)
                    window.isReleasedWhenClosed = false; window.animationBehavior = .none
                    window.appearance = NSAppearance(named: appearance)
                    window.contentView = hosting
                    defer { window.close() }
                    for _ in 0..<4 {
                        hosting.layoutSubtreeIfNeeded(); hosting.displayIfNeeded()
                        try await Task.sleep(for: .milliseconds(25))
                    }
                    let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
                    hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
                    let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    XCTAssertGreaterThan(data.count, 1000)
                    try data.write(to: output.appendingPathComponent("\(mode)-\(sizeName)-\(name).png"))
                    window.close()
                }
            }
        }
    }
}
