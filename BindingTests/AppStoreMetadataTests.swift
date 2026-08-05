// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Testing

@Suite("App Store metadata")
struct AppStoreMetadataTests {
    @Test func infoPlistDoesNotDeclareAnUnhandledDocumentApp() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let infoPlistURL = repositoryRoot
            .appendingPathComponent("Binding", isDirectory: true)
            .appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: infoPlistURL)
        let propertyList = try PropertyListSerialization.propertyList(from: data, format: nil)
        let info = try #require(propertyList as? [String: Any])

        // CFBundleDocumentTypes tells App Store Connect that HAVEN is a
        // document-based app. HAVEN imports CellConfigurations through its
        // explicit Transferable/drop path and does not host a document browser
        // or document lifecycle, so declaring document ownership here is false
        // and triggers ITMS-90737.
        #expect(info["CFBundleDocumentTypes"] == nil)

        let exportedTypes = try #require(info["UTExportedTypeDeclarations"] as? [[String: Any]])
        #expect(exportedTypes.contains { declaration in
            declaration["UTTypeIdentifier"] as? String == "app.binding.cellconfiguration"
        })
    }
}
