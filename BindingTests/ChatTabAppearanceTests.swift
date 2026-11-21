import XCTest
import SwiftUI
import AppKit
import CellBase
import CellApple
@testable import Binding

@MainActor
final class ChatTabAppearanceTests: XCTestCase {
    func testProductionTabLabelsRemainVisibleInBothAppearances() async throws {
        let config = ConfigurationCatalogCell.personalInviteChatMenuConfiguration()
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(XCTUnwrap(config.skeleton)))
        var tabs: [SkeletonTabs] = []
        func visit(_ value: Any) throws {
            if let object = value as? [String: Any] {
                if let raw = object["Tabs"] as? [String: Any] {
                    tabs.append(try JSONDecoder().decode(SkeletonTabs.self, from: JSONSerialization.data(withJSONObject: ["Tabs": raw])))
                }
                for child in object.values { try visit(child) }
            } else if let list = value as? [Any] {
                for child in list { try visit(child) }
            }
        }
        try visit(json)
        XCTAssertGreaterThanOrEqual(tabs.count, 3)
        let output = ProcessInfo.processInfo.environment["HAVEN_CHAT_APPEARANCE_OUTPUT"].map { URL(fileURLWithPath: $0) }
        if let output { try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true) }
        for (index, var tab) in tabs.enumerated() {
            // Render the production tab labels and style; omit panel contents
            // and live bindings so this visual probe performs no service calls.
            tab.tabsKeypath = nil; tab.activeTabStateKeypath = ""; tab.selectionActionKeypath = nil
            tab.panels = tab.panels.map { SkeletonTabPanel(id: $0.id, content: []) }
            for (name, scheme) in [("light", ColorScheme.light), ("dark", .dark)] {
                let view = SkeletonView(element: .Tabs(tab), showsKeyboardToolbar: false)
                    .environmentObject(PortholeViewModel())
                    .environment(\.colorScheme, scheme)
                    .frame(width: 1000, height: 80, alignment: .topLeading)
                    .background(Color.white)
                let hosting = NSHostingView(rootView: view)
                hosting.frame = NSRect(x: 0, y: 0, width: 1000, height: 80)
                let window = NSWindow(contentRect: hosting.frame, styleMask: [.titled], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false; window.animationBehavior = .none
                window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                window.contentView = hosting
                defer { window.close() }
                for _ in 0..<4 {
                    hosting.layoutSubtreeIfNeeded(); hosting.displayIfNeeded()
                    try await Task.sleep(for: .milliseconds(25))
                }
                let bitmap = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
                hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
                var darkPixels = 0
                for y in 0..<min(50, bitmap.pixelsHigh) {
                    for x in 0..<bitmap.pixelsWide {
                        if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                           max(color.redComponent, color.greenComponent, color.blueComponent) < 0.45 {
                            darkPixels += 1
                        }
                    }
                }
                XCTAssertGreaterThan(darkPixels, 100, "Unreadable production tab labels: \(index), \(name)")
                if let output {
                    try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                        .write(to: output.appendingPathComponent("tabs-\(index)-\(name).png"))
                }
            }
        }
    }
}
