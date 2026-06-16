// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Testing
@preconcurrency import CellBase

/// Proves the proposed Network Sentinel GUI is a *working* skeleton: it decodes
/// against the real CellConfiguration / SkeletonElement Codable models and
/// survives a full encode/decode round-trip. (Visual rendering is verified
/// separately via the Porthole skeleton-iteration workflow.)
struct NetworkSentinelConfigurationTests {
    private func loadConfigurationData() throws -> Data {
        let testFile = URL(fileURLWithPath: #filePath)
        let packageRoot = testFile
            .deletingLastPathComponent() // HavenAgentRuntimeTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // HavenAgentD
        let configURL = packageRoot
            .appendingPathComponent("Docs")
            .appendingPathComponent("CellConfiguration.network-sentinel.json")
        return try Data(contentsOf: configURL)
    }

    @Test
    func decodesAgainstTheRealSchema() throws {
        let configuration = try JSONDecoder().decode(CellConfiguration.self, from: loadConfigurationData())

        #expect(configuration.name == "Network Sentinel")
        #expect(configuration.discovery?.sourceCellEndpoint == "cell:///agent/network/sentinel")
        #expect(configuration.cellReferences?.first?.label == "networkSentinel")
        #expect(configuration.cellReferences?.first?.setKeysAndValues.first?.key == "state")

        let skeleton = try #require(configuration.skeleton)
        guard case let .VStack(root) = skeleton else {
            Issue.record("Expected a VStack root, got \(skeleton)")
            return
        }
        let hasTabs = root.elements.contains { if case .Tabs = $0 { return true } else { return false } }
        #expect(hasTabs)
    }

    @Test
    func tabsAndPanelsRoundTrip() throws {
        let configuration = try JSONDecoder().decode(CellConfiguration.self, from: loadConfigurationData())
        let reEncoded = try JSONEncoder().encode(configuration)
        let reDecoded = try JSONDecoder().decode(CellConfiguration.self, from: reEncoded)

        guard case let .VStack(root)? = reDecoded.skeleton else {
            Issue.record("Expected VStack after round-trip")
            return
        }
        let tabs = try #require(root.elements.compactMap { element -> SkeletonTabs? in
            if case let .Tabs(value) = element { return value } else { return nil }
        }.first)

        #expect(tabs.activeTabStateKeypath == "networkSentinel.state.navigation.activeTab")
        #expect(tabs.tabsKeypath == "networkSentinel.state.navigation.tabs")
        #expect(tabs.selectionActionKeypath == "selectTab")
        #expect(tabs.panels.map(\.id) == ["dashboard", "devices", "events", "tools", "settings"])
    }

    @Test
    func actionButtonsTargetTheSentinelCell() throws {
        let configuration = try JSONDecoder().decode(CellConfiguration.self, from: loadConfigurationData())
        var buttons: [SkeletonButton] = []
        collectButtons(in: configuration.skeleton, into: &buttons)

        // Every action button explicitly targets the sentinel endpoint with a real action keypath.
        let actionKeypaths = Set(buttons.map(\.keypath))
        #expect(actionKeypaths.isSuperset(of: ["acknowledge", "probe", "captureNow"]))
        for button in buttons {
            #expect(button.url == "cell:///agent/network/sentinel")
        }
    }

    private func collectButtons(in element: SkeletonElement?, into buttons: inout [SkeletonButton]) {
        guard let element else { return }
        switch element {
        case let .Button(button):
            buttons.append(button)
        case let .VStack(value):
            value.elements.forEach { collectButtons(in: $0, into: &buttons) }
        case let .HStack(value):
            value.elements.forEach { collectButtons(in: $0, into: &buttons) }
        case let .ZStack(value):
            value.elements.forEach { collectButtons(in: $0, into: &buttons) }
        case let .ScrollView(value):
            value.elements.forEach { collectButtons(in: $0, into: &buttons) }
        case let .Section(value):
            collectButtons(in: value.header, into: &buttons)
            value.content.forEach { collectButtons(in: $0, into: &buttons) }
            collectButtons(in: value.footer, into: &buttons)
        case let .Tabs(value):
            value.panels.forEach { panel in panel.content.forEach { collectButtons(in: $0, into: &buttons) } }
        default:
            break
        }
    }
}
