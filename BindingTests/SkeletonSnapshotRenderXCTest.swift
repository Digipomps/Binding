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
#if os(macOS)
import AppKit
#endif
#if canImport(Vision)
import Vision
#endif

/// Rendrer paritetskorpuset (skeleton + state fanget fra web) til PNG, i en
/// ramme som tilsvarer webens `.skeleton-host` i produktvisning: padding,
/// innholdskolonne på maks 1180 px sentrert, og samme bakgrunnsfarge som
/// web-skjermbildet. Rammen er *chrome*, ikke skjelett - den skal være lik på
/// begge sider så det som måles er rendreren, ikke omgivelsene.
///
/// Miljø: BINDING_SNAPSHOT_CORPUS_DIR (katalog med <navn>/skeleton.json og
/// root.json med nøyaktig renderdata fra web, valgfri expected-text.json,
/// surface.json og meta.json). Eldre materialiserte fixtures er merket separat.
/// BINDING_SNAPSHOT_OUTPUT_DIR (standard <corpus>/../native).
@MainActor
final class SkeletonSnapshotRenderXCTest: XCTestCase {
    func testRenderCorpusToPNG() async throws {
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
        var rasterOnlyNames: [String] = []
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        for directory in directories {
            let staticURL = directory.appendingPathComponent("skeleton.static.json")
            let skeletonURL = directory.appendingPathComponent("skeleton.json")
            // Original payload always wins. A stale materialized file must not
            // silently turn a binding regression into a static screenshot pass.
            let useStatic = !fileManager.fileExists(atPath: skeletonURL.path)
            guard !useStatic || fileManager.fileExists(atPath: staticURL.path) else { continue }

            let name = directory.lastPathComponent
            names.append(name)

            do {
                let skeletonData = try Data(contentsOf: useStatic ? staticURL : skeletonURL)
                let surface = try surfaceSettings(for: directory)
                let normalized = try SkeletonStyleParity.normalizedForParity(jsonData: skeletonData)
                // Capture the actual native decoder/renderer. Stripping unsupported
                // style tokens before rendering would hide genuine parity failures.
                let element = try decoder.decode(SkeletonElement.self, from: skeletonData)
                let rootURL = directory.appendingPathComponent("root.json")
                let root = fileManager.fileExists(atPath: rootURL.path)
                    ? try decoder.decode(ValueType.self, from: Data(contentsOf: rootURL))
                    : nil

                let png = try await renderPNG(element: element, root: root, surface: surface)
                try png.data.write(to: outputURL.appendingPathComponent("\(name).png"), options: .atomic)

                let expectedURL = directory.appendingPathComponent("expected-text.json")
                let expected = fileManager.fileExists(atPath: expectedURL.path)
                    ? try decoder.decode([String].self, from: Data(contentsOf: expectedURL))
                    : []
                if expected.isEmpty { rasterOnlyNames.append(name) }
                let recognized = try recognizedText(in: png.data, expected: expected)
                let missing = expected.filter { !recognized.contains($0) }
                let rasterURL = directory.appendingPathComponent("expected-raster.json")
                let rasterExpectations = fileManager.fileExists(atPath: rasterURL.path)
                    ? try decoder.decode([RasterExpectation].self, from: Data(contentsOf: rasterURL))
                    : []
                let rasterResults = try rasterEvidence(in: png.data, expectations: rasterExpectations)

                let metadata = RenderMetadata(
                    pixelWidth: png.width,
                    pixelHeight: png.height,
                    observedStyleTokens: normalized.findings.map {
                        StyleTokenFinding(path: $0.path, token: $0.token, kind: $0.kind.rawValue)
                    },
                    materialized: useStatic,
                    rootDataSupplied: root != nil,
                    recognizedText: recognized,
                    expectedTextCount: expected.count,
                    missingExpectedText: missing,
                    rasterResults: rasterResults,
                    surface: surface
                )
                try encoder.encode(metadata).write(to: outputURL.appendingPathComponent("\(name).json"), options: .atomic)
                guard missing.isEmpty else { throw RenderFailure.missingExpectedText(missing) }
                guard rasterResults.allSatisfy({ $0.matchingPixels >= $0.expected.minimumPixels }) else {
                    throw RenderFailure.missingExpectedRaster
                }
                let previousError = outputURL.appendingPathComponent("\(name).error.txt")
                if fileManager.fileExists(atPath: previousError.path) { try fileManager.removeItem(at: previousError) }
                rendered += 1
            } catch {
                failed += 1
                let message = String(describing: error).data(using: .utf8) ?? Data()
                try? message.write(to: outputURL.appendingPathComponent("\(name).error.txt"), options: .atomic)
            }
        }

        XCTAssertGreaterThan(rendered, 0)
        try encoder.encode(Summary(rendered: rendered, failed: failed, names: names, rasterOnlyNames: rasterOnlyNames)).write(
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

    private enum RenderFailure: Error {
        case rasterizationFailed, encodingFailed
        case missingExpectedText([String])
        case missingExpectedRaster
    }

    /// Speiler `SkeletonParityRenderer.renderPNG`, men med webens
    /// vert-ramme rundt skjelettet (padding + sentrert innholdskolonne).
    private func renderPNG(element: SkeletonElement, root: ValueType?, surface: SurfaceSettings) async throws -> RenderedPNG {
        let suite = "haven.skeleton.parity.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let background = Self.rgb(fromHex: surface.backgroundHex).map { Color(red: $0.r, green: $0.g, blue: $0.b) } ?? .white
        let content = VStack(spacing: 0) {
            BindingSkeletonView(element: element, userInfoValue: root)
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

        #if os(macOS)
        // ImageRenderer cannot render every NSView-backed control. Capture the
        // real app host after SwiftUI binding tasks have had time to settle.
        let host = NSHostingView(rootView: content)
        host.frame = NSRect(x: 0, y: 0, width: surface.width, height: surface.height)
        let window = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: surface.width, height: surface.height),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.contentView = host
        defer { window.orderOut(nil); window.close() }
        for _ in 0..<12 {
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw RenderFailure.rasterizationFailed
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw RenderFailure.encodingFailed
        }
        return RenderedPNG(data: data, width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
        #else
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
        #endif
    }

    private func rasterEvidence(in png: Data, expectations: [RasterExpectation]) throws -> [RasterResult] {
        guard !expectations.isEmpty else { return [] }
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw RenderFailure.rasterizationFailed
        }
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { throw RenderFailure.rasterizationFailed }
        return expectations.map { expected in
            let matches = stride(from: 0, to: bytes.count, by: 4).reduce(0) { count, offset in
                count + ((0..<3).allSatisfy {
                    abs(Int(bytes[offset + $0]) - expected.rgb[$0]) <= expected.tolerance
                } && bytes[offset + 3] > 240 ? 1 : 0)
            }
            return RasterResult(expected: expected, matchingPixels: matches)
        }
    }

    private func recognizedText(in png: Data, expected: [String]) throws -> String {
        #if canImport(Vision)
        func recognize(_ handler: VNImageRequestHandler) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0
        try handler.perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        }
        var text = try recognize(VNImageRequestHandler(data: png))
        if expected.contains(where: { !text.contains($0) }),
           let source = CGImageSourceCreateWithData(png as CFData, nil),
           let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            // Vision can omit a short final control label on a large canvas.
            // Retry overlapping pixel crops, never infer text from the JSON.
            let width = CGFloat(image.width), height = CGFloat(image.height)
            for y in [CGFloat(0), height * 0.4] {
                for x in [CGFloat(0), width * 0.4] {
                    if let crop = image.cropping(to: CGRect(x: x, y: y, width: width * 0.6, height: height * 0.6)) {
                        text += "\n" + (try recognize(VNImageRequestHandler(cgImage: crop)))
                    }
                }
            }
        }
        return text
        #else
        return ""
        #endif
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
    let rootDataSupplied: Bool
    let recognizedText: String
    let expectedTextCount: Int
    let missingExpectedText: [String]
    let rasterResults: [RasterResult]
    let surface: SkeletonSnapshotRenderXCTest.SurfaceSettings
}

private struct RasterExpectation: Codable {
    let rgb: [Int]
    let tolerance: Int
    let minimumPixels: Int
}

private struct RasterResult: Encodable {
    let expected: RasterExpectation
    let matchingPixels: Int
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
    let rasterOnlyNames: [String]
}
