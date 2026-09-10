// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: Copyright (c) 2026 Stiftelsen Digipomps and HAVEN contributors

import XCTest
@testable import Binding
import CellBase
import CellApple
import Foundation
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

/// Rendrer paritetskorpuset (skeleton + state fanget fra web) til PNG, i en
/// ramme som tilsvarer webens `.skeleton-host` i produktvisning: padding,
/// innholdskolonne på maks 1180 px sentrert, og samme bakgrunnsfarge som
/// web-skjermbildet. Rammen er *chrome*, ikke skjelett - den skal være lik på
/// begge sider så det som måles er rendreren, ikke omgivelsene.
///
/// Miljø: BINDING_SNAPSHOT_CORPUS_DIR (katalog med <navn>/skeleton.static.json
/// eller skeleton.json + state.json, valgfri surface.json og meta.json),
/// BINDING_SNAPSHOT_OUTPUT_DIR (standard <corpus>/../native).
@MainActor
final class SkeletonSnapshotRenderXCTest: XCTestCase {
    func testRenderCorpusToPNG() throws {
        guard let corpus = ProcessInfo.processInfo.environment["BINDING_SNAPSHOT_CORPUS_DIR"] else {
            throw XCTSkip("BINDING_SNAPSHOT_CORPUS_DIR mangler")
        }

        let fileManager = FileManager.default
        let corpusURL = URL(fileURLWithPath: corpus, isDirectory: true)
        let outputURL = ProcessInfo.processInfo.environment["BINDING_SNAPSHOT_OUTPUT_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? corpusURL.deletingLastPathComponent().appendingPathComponent("native", isDirectory: true)
        try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)

        let directories = try fileManager.contentsOfDirectory(
            at: corpusURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var rendered = 0
        var failed = 0
        var names: [String] = []
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        for directory in directories {
            let staticURL = directory.appendingPathComponent("skeleton.static.json")
            let skeletonURL = directory.appendingPathComponent("skeleton.json")
            let useStatic = fileManager.fileExists(atPath: staticURL.path)
            guard useStatic || fileManager.fileExists(atPath: skeletonURL.path) else { continue }

            let name = directory.lastPathComponent
            names.append(name)

            do {
                let skeletonData = try Data(contentsOf: useStatic ? staticURL : skeletonURL)
                let surface = try surfaceSettings(for: directory)
                let normalized = try SkeletonStyleParity.normalizedForParity(jsonData: skeletonData)
                // Capture the actual native decoder/renderer. Stripping unsupported
                // style tokens before rendering would hide genuine parity failures.
                let element = try decoder.decode(SkeletonElement.self, from: skeletonData)

                let png = try renderPNG(element: element, surface: surface)
                try png.data.write(to: outputURL.appendingPathComponent("\(name).png"), options: .atomic)

                let metadata = RenderMetadata(
                    pixelWidth: png.width,
                    pixelHeight: png.height,
                    observedStyleTokens: normalized.findings.map {
                        StyleTokenFinding(path: $0.path, token: $0.token, kind: $0.kind.rawValue)
                    },
                    materialized: useStatic,
                    surface: surface
                )
                try encoder.encode(metadata).write(to: outputURL.appendingPathComponent("\(name).json"), options: .atomic)
                rendered += 1
            } catch {
                failed += 1
                let message = String(describing: error).data(using: .utf8) ?? Data()
                try? message.write(to: outputURL.appendingPathComponent("\(name).error.txt"), options: .atomic)
            }
        }

        XCTAssertGreaterThan(rendered, 0)
        try encoder.encode(Summary(rendered: rendered, failed: failed, names: names)).write(
            to: outputURL.appendingPathComponent("summary.json"),
            options: .atomic
        )
        XCTAssertEqual(failed, 0, "Some corpus surfaces failed; inspect the per-surface error artifacts.")
    }

    // MARK: - Ramme

    struct SurfaceSettings: Codable {
        var width: CGFloat = 1280
        var height: CGFloat = 800
        var padding: CGFloat = 36
        var contentMaxWidth: CGFloat = 1180
        var backgroundHex: String = "#FFFFFF"
        var isDarkMode: Bool = false
    }

    private func surfaceSettings(for directory: URL) throws -> SurfaceSettings {
        var settings = SurfaceSettings()
        if let metadata = try jsonObject(at: directory.appendingPathComponent("meta.json")),
           let box = metadata["skeletonRootBox"] as? [String: Any],
           let width = number(box["width"]), let height = number(box["height"]) {
            settings.width = CGFloat(ceil(width)); settings.height = CGFloat(ceil(height))
        } else if let viewport = try jsonObject(at: directory.appendingPathComponent("viewport.json")),
                  let width = number(viewport["width"]), let height = number(viewport["height"]) {
            settings.width = CGFloat(ceil(width)); settings.height = CGFloat(ceil(height))
        }
        if let surface = try jsonObject(at: directory.appendingPathComponent("surface.json")) {
            if let padding = number(surface["padding"]) { settings.padding = CGFloat(padding) }
            if let maxWidth = number(surface["contentMaxWidth"]) { settings.contentMaxWidth = CGFloat(maxWidth) }
            if let hex = surface["backgroundHex"] as? String { settings.backgroundHex = hex }
        }
        if let rgb = Self.rgb(fromHex: settings.backgroundHex) {
            let luminance = 0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b
            settings.isDarkMode = luminance < 0.5
        }
        return settings
    }

    private struct RenderedPNG {
        let data: Data
        let width: Int
        let height: Int
    }

    private enum RenderFailure: Error { case rasterizationFailed, encodingFailed }

    /// Speiler `SkeletonParityRenderer.renderPNG`, men med webens
    /// vert-ramme rundt skjelettet (padding + sentrert innholdskolonne).
    private func renderPNG(element: SkeletonElement, surface: SurfaceSettings) throws -> RenderedPNG {
        let suite = "haven.skeleton.parity"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)

        let background = Self.rgb(fromHex: surface.backgroundHex).map { Color(red: $0.r, green: $0.g, blue: $0.b) } ?? .white
        let content = VStack(spacing: 0) {
            SkeletonView(element: element, showsKeyboardToolbar: false)
                .frame(maxWidth: surface.contentMaxWidth, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
            Spacer(minLength: 0)
        }
        .padding(surface.padding)
        .environmentObject(PortholeViewModel())
        .defaultAppStorage(defaults)
        .environment(\.colorScheme, surface.isDarkMode ? .dark : .light)
        .frame(width: surface.width, height: surface.height, alignment: .topLeading)
        .background(background)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        renderer.isOpaque = true
        renderer.proposedSize = ProposedViewSize(width: surface.width, height: surface.height)
        guard let cgImage = renderer.cgImage else { throw RenderFailure.rasterizationFailed }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw RenderFailure.encodingFailed
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { throw RenderFailure.encodingFailed }
        return RenderedPNG(data: data as Data, width: cgImage.width, height: cgImage.height)
    }

    private static func rgb(fromHex hex: String) -> (r: Double, g: Double, b: Double)? {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = UInt32(value, radix: 16) else { return nil }
        return (Double((number >> 16) & 0xFF) / 255, Double((number >> 8) & 0xFF) / 255, Double(number & 0xFF) / 255)
    }

    private func jsonObject(at url: URL) throws -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    }

    private func number(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }
}

private struct RenderMetadata: Encodable {
    let pixelWidth: Int
    let pixelHeight: Int
    let observedStyleTokens: [StyleTokenFinding]
    let styleNormalizationApplied = false
    let materialized: Bool
    let surface: SkeletonSnapshotRenderXCTest.SurfaceSettings
}

private struct StyleTokenFinding: Encodable {
    let path: String
    let token: String
    let kind: String
}

private struct Summary: Encodable {
    let rendered: Int
    let failed: Int
    let names: [String]
}
