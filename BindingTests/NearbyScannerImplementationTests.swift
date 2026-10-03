import XCTest
import SwiftUI
import ImageIO
import MultipeerConnectivity
@testable import CellApple
@testable import CellBase
@testable import Binding

final class NearbyScannerImplementationTests: XCTestCase {
    private func advertisement(now: TimeInterval = Date().timeIntervalSince1970) -> NearbyAdvertisement {
        NearbyAdvertisement(displayName: "Testdeltaker", purposes: ["purpose://samarbeid": "Finne samarbeidspartnere"],
                            interests: ["interest://design": "Design"], expiresAt: now + 600)
    }

    func testPublicationIsBoundedAndExpires() throws {
        let now = 1_000.0
        var ad = advertisement(now: now)
        XCTAssertNoThrow(try ad.validate(now: now))
        XCTAssertThrowsError(try ad.validate(now: now + 601))
        ad.purposes = Dictionary(uniqueKeysWithValues: (0..<7).map { ("purpose://\($0)", "Formål \($0)") })
        XCTAssertThrowsError(try ad.validate(now: now))
        ad = advertisement(now: now); ad.interests = ["private://notes": "Privat"]
        XCTAssertThrowsError(try ad.validate(now: now))
        ad = advertisement(now: now); ad.thumbnail = Data(repeating: 1, count: 32_769)
        XCTAssertThrowsError(try ad.validate(now: now))
        ad = advertisement(now: now); ad.expiresAt = .infinity
        XCTAssertThrowsError(try ad.validate(now: now))
    }

    func testReadModelRoundTripDoesNotCopyUnknownPrivateFields() throws {
        let ad = advertisement()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(ad)) as? [String: Any])
        object["privateProfile"] = ["notes": "must not propagate"]
        let decoded = try JSONDecoder().decode(NearbyAdvertisement.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded, ad)
        let encoded = String(decoding: try JSONEncoder().encode(decoded), as: UTF8.self)
        XCTAssertFalse(encoded.contains("privateProfile"))
        XCTAssertFalse(encoded.contains("must not propagate"))
    }

    @MainActor func testPublicationIsOffByDefaultAndConferenceDoesNotTrustAScopeString() throws {
        let exchange = NearbyAdvertisementExchange()
        XCTAssertNil(exchange.currentPublication)
        try exchange.publish(advertisement())
        XCTAssertNotNil(exchange.currentPublication)
        var conference = advertisement(); conference.scope = .conference; conference.scopeID = "conference://example"
        XCTAssertThrowsError(try exchange.publish(conference))
        try exchange.publish(nil)
        XCTAssertNil(exchange.currentPublication)
    }

    func testUnknownPositionHasNoFabricatedCoordinates() {
        var ledger = RadarEntityLedger()
        ledger.consume(.found(RadarEntityUpdate(remoteUUID: "unknown", displayName: "Ukjent")))
        let spec = RadarVisualizationSpec.decode(from: .object(ledger.radarSpec()))!
        XCTAssertEqual(spec.blips.count, 1)
        XCTAssertFalse(spec.blips[0].hasDirection)
        XCTAssertTrue(RadarClustering.groups(spec.blips, radius: 200).isEmpty)
        guard case let .list(values)? = ledger.radarSpec()["blips"], case let .object(blip)? = values.first else { return XCTFail() }
        XCTAssertEqual(blip["x"], .null)
        XCTAssertEqual(blip["y"], .null)
        XCTAssertEqual(blip["bearingDegrees"], .null)
    }

    func testThousandsOfOverlappingEntitiesRemainReachableWithoutThousandsOfMarkers() {
        for count in [0, 1, 10, 100, 1_000, 5_000] {
            let nodes = (0..<count).map { i in
                RadarBlip(id: "\(i)", label: "Person \(i)", status: "found", connected: false,
                          x: 0.4, y: 0.2, strength: 1, distanceText: "4 m", hasDirection: true, matchScore: 0)
            }
            let groups = RadarClustering.groups(nodes, radius: 200)
            XCTAssertEqual(groups.count, count == 0 ? 0 : 1)
            XCTAssertEqual(Set(groups.flatMap(\.members).map(\.id)), Set(nodes.map(\.id)))
        }
    }

    func testNonFinitePositionCannotEnterACluster() {
        let node = RadarBlip(id: "bad", label: "Bad", status: "found", connected: false,
                            x: .infinity, y: 0, strength: 1, distanceText: "?", hasDirection: true, matchScore: 0)
        XCTAssertTrue(RadarClustering.groups([node], radius: 200).isEmpty)
    }

    func testDenseGroupsHaveSeparateHitTargetsAndRetainEveryPeer() {
        let nodes = (0..<5_000).map { i in
            let angle = Double(i % 97) * 2 * .pi / 97
            let distance = Double(i % 19 + 1) / 20
            return RadarBlip(id: "\(i)", label: "Deltaker \(i)", status: "found", connected: false,
                x: sin(angle) * distance, y: cos(angle) * distance, strength: 1, distanceText: "", hasDirection: true, matchScore: 0)
        }
        for radius in [132.0, 200.0] {
            let clusters = RadarClustering.groups(nodes, radius: radius)
            XCTAssertEqual(Set(clusters.flatMap(\.members).map(\.id)), Set(nodes.map(\.id)))
            for a in clusters.indices {
                for b in clusters.indices where b > a {
                    XCTAssertGreaterThanOrEqual(hypot(clusters[a].x - clusters[b].x, clusters[a].y - clusters[b].y) * radius, 47.99)
                }
            }
        }
    }

    func testDiscoveredPeerSurvivesWithoutAConnectionButOldMeasurementIsNotPlotted() {
        let now = Date(timeIntervalSince1970: 1_000)
        var ledger = RadarEntityLedger()
        ledger.consume(.found(RadarEntityUpdate(remoteUUID: "visible", displayName: "Visible", distanceMeters: 4,
            direction: RadarDirection3D(x: 1, y: 0, z: 1), timestamp: now)))
        XCTAssertTrue(ledger.prune(now: now.addingTimeInterval(60), visibleRemoteUUIDs: ["visible"]).isEmpty)
        let spec = RadarVisualizationSpec.decode(from: .object(ledger.radarSpec(now: now.addingTimeInterval(60))))!
        XCTAssertFalse(spec.blips[0].hasDirection)
        XCTAssertEqual(ledger.prune(now: now.addingTimeInterval(60)), ["visible"])
    }

    @MainActor func testAdvertisementInvitationsRequirePublicationAndDoNotAcceptUnknownProtocols() throws {
        let exchange = NearbyAdvertisementExchange()
        let remote = MCPeerID(displayName: "Synthetic remote")
        let local = MCPeerID(displayName: "Synthetic local")
        let request = try JSONEncoder().encode(NearbyAdvertisementEnvelope(requestID: UUID()))
        var accepted: Bool?
        XCTAssertTrue(exchange.accept(context: request, peer: remote, localPeer: local) { allowed, _ in accepted = allowed })
        XCTAssertEqual(accepted, false)
        accepted = nil
        XCTAssertFalse(exchange.accept(context: Data("{\"otherProtocol\":true}".utf8), peer: remote, localPeer: local) { allowed, _ in accepted = allowed })
        XCTAssertNil(accepted)
        try exchange.publish(advertisement())
        XCTAssertTrue(exchange.accept(context: request, peer: remote, localPeer: local) { allowed, _ in accepted = allowed })
        XCTAssertEqual(accepted, true)
        XCTAssertTrue(exchange.accept(context: request, peer: remote, localPeer: local) { allowed, _ in accepted = allowed })
        XCTAssertEqual(accepted, false, "Repeated request should be rate limited")
        exchange.stop()
        XCTAssertNil(exchange.currentPublication)
    }

    @MainActor func testResponseRequiresExpectedPeerNonceAndScopeAndCompletesOnce() async throws {
        let remote = MCPeerID(displayName: "Synthetic remote")
        let local = MCPeerID(displayName: "Synthetic local")
        let other = MCPeerID(displayName: "Other peer")
        let nonce = UUID()
        var completions = [NearbyAdvertisement?]()
        let receiver = AdvertisementSession(localPeer: local, remotePeer: remote, requestID: nonce, response: nil) { completions.append($0) }
        func deliver(_ envelope: NearbyAdvertisementEnvelope, from peer: MCPeerID) async throws {
            receiver.session(receiver.session, didReceive: try JSONEncoder().encode(envelope), fromPeer: peer)
            // Delegate delivery hops to MainActor, just as it does with the real MCSession.
            for _ in 0..<10 { await Task.yield() }
        }
        try await deliver(NearbyAdvertisementEnvelope(requestID: UUID(), advertisement: advertisement()), from: remote)
        XCTAssertTrue(completions.isEmpty)
        try await deliver(NearbyAdvertisementEnvelope(requestID: nonce, advertisement: advertisement()), from: other)
        XCTAssertTrue(completions.isEmpty)
        var conference = advertisement(); conference.scope = .conference; conference.scopeID = "conference://example"
        try await deliver(NearbyAdvertisementEnvelope(requestID: nonce, advertisement: conference), from: remote)
        XCTAssertTrue(completions.isEmpty)
        let allowed = advertisement()
        try await deliver(NearbyAdvertisementEnvelope(requestID: nonce, advertisement: allowed), from: remote)
        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(completions.first!, allowed)
        receiver.finish(nil)
        XCTAssertEqual(completions.count, 1)
    }

    @MainActor func testPublicationActionsRejectAnotherIdentityAndDoNotEnterAgreementTemplate() async throws {
        let previousVault = CellBase.defaultIdentityVault
        let previousDebugAccess = CellBase.debugValidateAccessForEverything
        defer {
            CellBase.defaultIdentityVault = previousVault
            CellBase.debugValidateAccessForEverything = previousDebugAccess
        }
        let vault = EphemeralIdentityVault()
        CellBase.debugValidateAccessForEverything = false
        CellBase.defaultIdentityVault = vault
        let owner = await vault.identity(for: "nearby-test-owner-\(UUID().uuidString)", makeNewIfNotFound: true)!
        let outsider = await vault.identity(for: "nearby-test-outsider-\(UUID().uuidString)", makeNewIfNotFound: true)!
        let cell = await EntityScannerCell(owner: owner)
        let keys = Set(cell.agreementTemplate.grants.map(\.keypath))
        for key in ["advertisement", "publishAdvertisement", "withdrawAdvertisement"] { XCTAssertFalse(keys.contains(key)) }
        let value = try JSONDecoder().decode(ValueType.self, from: JSONEncoder().encode(advertisement()))
        do {
            _ = try await cell.set(keypath: "publishAdvertisement", value: value, requester: outsider)
            XCTFail("A foreign requester must be denied by the Cell authorization boundary")
        } catch CellAuthorizationError.denied(let decision) {
            XCTAssertFalse(decision.allowed)
            XCTAssertEqual(decision.request.keypath, "publishAdvertisement")
        }
        let current = try await cell.get(keypath: "advertisement", requester: owner)
        XCTAssertEqual(current, .null)
        // No radio startup: an unstarted service is sufficient to isolate Cell publication policy.
        let service = ScannerService(owner: owner)
        cell.connectService = service
        let allowed = try await cell.set(keypath: "publishAdvertisement", value: value, requester: owner)
        let published = try JSONDecoder().decode(NearbyAdvertisement.self, from: JSONEncoder().encode(XCTUnwrap(allowed)))
        let expected = try JSONDecoder().decode(NearbyAdvertisement.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(published, expected)
        // Exercise the action contract through the same discovery event and GET used by the UI.
        cell.foundDevicesChanged(manager: service, foundDevice: MCPeerID(displayName: "Synthetic peer"), remoteUUID: "peer-fixture", discoveryInfo: nil)
        for selection: ValueType in [.string("peer-fixture"), .object(["remoteUUID": .string("peer-fixture")]),
            .object(["selected": .object(["payload": .string("peer-fixture")])])] {
            _ = try await cell.set(keypath: "select", value: selection, requester: owner)
            let radar = try await cell.get(keypath: "radar", requester: owner)
            guard case let .object(spec) = radar else { return XCTFail("Expected radar snapshot") }
            XCTAssertEqual(spec["selectedID"], .string("peer-fixture"))
            XCTAssertNil(spec["selectedAdvertisement"], "Unavailable peers must not inherit another person's excerpt")
        }
        let withdrawn = try await cell.set(keypath: "withdrawAdvertisement", value: .bool(true), requester: owner)
        XCTAssertEqual(withdrawn, .bool(true))
        let after = try await cell.get(keypath: "advertisement", requester: owner)
        XCTAssertEqual(after, .null)
    }

    func testMainConfigurationHasOneRadarWithoutLegacySectorCards() throws {
        let config = ConfigurationCatalogCell.entityScannerWorkbenchConfiguration()
        let json = String(decoding: try JSONEncoder().encode(config.skeleton), as: UTF8.self)
        XCTAssertTrue(json.contains("scanner.radar"))
        XCTAssertFalse(json.contains("nearbyRadar.state.radarLayout"))
        XCTAssertFalse(json.contains("Troubleshooting"))
    }

#if os(macOS)
    @MainActor func testRenderDenseRadarAndAdvertisedDetailsAtPhoneAndDesktopWidths() async throws {
        var ledger = RadarEntityLedger()
        for index in 0..<1_000 {
            ledger.consume(.found(RadarEntityUpdate(remoteUUID: "test-\(index)", displayName: "Deltaker \(index)",
                distanceMeters: Double(index % 19 + 1),
                direction: index % 3 == 0 ? nil : RadarDirection3D(x: sin(Double(index % 18)), y: 0, z: cos(Double(index % 18))))))
        }
        var value = ledger.radarSpec()
        value["status"] = .string("started")
        value["selectedID"] = .string("test-1")
        var excerpt = advertisement()
        let pixels = try XCTUnwrap(CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 128,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        pixels.setFillColor(CGColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1))
        pixels.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        let pictureData = NSMutableData()
        let pictureDestination = try XCTUnwrap(CGImageDestinationCreateWithData(pictureData, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(pictureDestination, try XCTUnwrap(pixels.makeImage()), nil)
        XCTAssertTrue(CGImageDestinationFinalize(pictureDestination))
        excerpt.thumbnail = pictureData as Data
        XCTAssertNoThrow(try excerpt.validate())
        value["selectedAdvertisement"] = try JSONDecoder().decode(ValueType.self, from: JSONEncoder().encode(excerpt))
        let directory = URL(fileURLWithPath: "/tmp/haven-nearby-20260910/render", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for width in [360.0, 736.0] {
            let view = NearbyRadarSurface(value: .object(value), onSelect: { _ in })
                .padding(20).frame(width: width).background(Color(nsColor: .windowBackgroundColor))
            let hosting = NSHostingView(rootView: view)
            hosting.frame = CGRect(origin: .zero, size: hosting.fittingSize)
            let window = NSWindow(contentRect: hosting.frame, styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = hosting
            defer { window.close() }
            for _ in 0..<4 {
                hosting.layoutSubtreeIfNeeded()
                hosting.displayIfNeeded()
                try await Task.sleep(nanoseconds: 25_000_000)
            }
            let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            let image = try XCTUnwrap(bitmap.cgImage)
            let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(directory.appendingPathComponent("radar-\(Int(width)).png") as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(destination))
        }
    }
#endif
}
