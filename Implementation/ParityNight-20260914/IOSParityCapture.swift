// Isolated iOS renderer harness. Never ship this app entry point.
#if os(iOS)
import SwiftUI
import UIKit
import CellBase
import CellApple

@MainActor
enum IOSParityCapture {
    static var started = false

    static func run() async {
        guard !started, ProcessInfo.processInfo.arguments.contains("--parity-capture") else { return }
        started = true
        guard Bundle.main.bundleIdentifier == "org.digipomps.haven.parity-night-test",
              CellBase.defaultIdentityVault == nil,
              CellBase.defaultCellResolver == nil else {
            fatalError("Isolated renderer must not acquire a real identity or resolver")
        }
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else { return }
        let output = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("parity", isDirectory: true)
        try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let model = PortholeViewModel()
        var reports: [[String: Any]] = []
        for slug in ["text", "list", "grid", "form", "chat"] {
            do {
                guard let configURL = Bundle.main.url(forResource: slug + "-configuration", withExtension: "json"),
                      let stateURL = Bundle.main.url(forResource: slug + "-state", withExtension: "json") else {
                    throw NSError(domain: "Missing bundled fixture", code: 1)
                }
                let configuration = try JSONDecoder().decode(CellConfiguration.self, from: Data(contentsOf: configURL))
                let state = try JSONDecoder().decode(ValueType.self, from: Data(contentsOf: stateURL))
                guard let skeleton = configuration.skeleton else { throw NSError(domain: "Missing skeleton", code: 2) }
                var root: [String: ValueType] = [:]
                for reference in configuration.cellReferences ?? [] where slug != "chat" || reference.label == "chatHub" { root[reference.label] = .object(["state": state]) }
                let host = UIHostingController(rootView:
                    BindingSkeletonView(element: skeleton, userInfoValue: .object(root))
                        .environmentObject(model)
                        .padding(16)
                        .background(Color.white)
                        .environment(\.colorScheme, .light)
                )
                window.rootViewController = host
                window.makeKeyAndVisible()
                for _ in 0..<12 {
                    host.view.setNeedsLayout()
                    host.view.layoutIfNeeded()
                    try await Task.sleep(nanoseconds: 50_000_000)
                }
                let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                guard let png = image.pngData() else { throw NSError(domain: "Missing bitmap", code: 3) }
                try png.write(to: output.appendingPathComponent("ios-" + slug + ".png"))
                reports.append(["slug": slug, "outcome": "captured", "bytes": png.count,
                                "width": window.bounds.width, "height": window.bounds.height,
                                "systemVersion": UIDevice.current.systemVersion])
            } catch {
                reports.append(["slug": slug, "outcome": "failed", "error": String(describing: error)])
            }
        }
        try? JSONSerialization.data(withJSONObject: reports, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("ios-capture-report.json"))
        // Leave the final fixture visible for a genuine Simulator screenshot.
        print("PARITY_CAPTURE_FINISHED")
    }
}
#endif
