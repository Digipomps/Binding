// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import Foundation
import Testing
@testable import Binding

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

    @Test func deviceIngressRolloutIsExplicitAndIndependentOfDemoCatalog() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let infoPlistURL = repositoryRoot
            .appendingPathComponent("Binding", isDirectory: true)
            .appendingPathComponent("Info.plist")
        let infoData = try Data(contentsOf: infoPlistURL)
        let propertyList = try PropertyListSerialization.propertyList(
            from: infoData,
            format: nil
        )
        let info = try #require(propertyList as? [String: Any])
        #expect(
            info[BindingDeviceIngressRolloutPolicy.environmentKey] as? String
                == "$(HAVEN_DEVICE_INGRESS_ROLLOUT_ENVIRONMENT)"
        )

        let project = try String(
            contentsOf: repositoryRoot
                .appendingPathComponent("Binding.xcodeproj", isDirectory: true)
                .appendingPathComponent("project.pbxproj"),
            encoding: .utf8
        )
        #expect(project.components(
            separatedBy: "HAVEN_DEVICE_INGRESS_ROLLOUT_ENVIRONMENT = staging;"
        ).count - 1 == 1)
        #expect(project.components(
            separatedBy: "HAVEN_DEVICE_INGRESS_ROLLOUT_ENVIRONMENT = disabled;"
        ).count - 1 == 1)
        #expect(project.contains(
            "HAVEN_DEVICE_INGRESS_AUDIENCE = staging.haven.digipomps.org;"
        ))
        #expect(project.contains(
            "HAVEN_DEVICE_INGRESS_PUBLIC_ORIGIN = \"https://staging.haven.digipomps.org\";"
        ))
        #expect(!project.contains(
            "HAVEN_DEVICE_INGRESS_CHALLENGE_ISSUER_BASE64 = \"\";\n"
                + "\t\t\t\tHAVEN_DEVICE_INGRESS_PUBLIC_ORIGIN = \"https://staging.haven.digipomps.org\";"
        ))

        for relativePath in [
            "Binding/BindingAppNotifications.swift",
            "Binding/NotificationEnrollmentManager.swift",
            "Binding/RootView.swift"
        ] {
            let source = try String(
                contentsOf: repositoryRoot.appendingPathComponent(relativePath),
                encoding: .utf8
            )
            #expect(!source.contains(
                "BindingPersonalCopilotV1Policy.appStoreCatalogGateEnabled"
            ))
            #expect(source.contains("BindingDeviceIngressRolloutPolicy"))
        }
    }

    @Test func stagingBuildIsVisiblyDistinctWhileReleaseKeepsTheProductName() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let infoPlistURL = repositoryRoot
            .appendingPathComponent("Binding", isDirectory: true)
            .appendingPathComponent("Info.plist")
        let infoData = try Data(contentsOf: infoPlistURL)
        let propertyList = try PropertyListSerialization.propertyList(
            from: infoData,
            format: nil
        )
        let info = try #require(propertyList as? [String: Any])
        #expect(info["CFBundleDisplayName"] as? String == "$(HAVEN_DISPLAY_NAME)")

        let project = try String(
            contentsOf: repositoryRoot
                .appendingPathComponent("Binding.xcodeproj", isDirectory: true)
                .appendingPathComponent("project.pbxproj"),
            encoding: .utf8
        )
        #expect(project.components(
            separatedBy: "HAVEN_DISPLAY_NAME = \"HAVEN Staging\";"
        ).count - 1 == 1)
        #expect(project.components(
            separatedBy: "HAVEN_DISPLAY_NAME = HAVEN;"
        ).count - 1 == 1)
    }
}
