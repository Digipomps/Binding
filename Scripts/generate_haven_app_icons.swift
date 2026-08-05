#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

private enum Appearance {
    case standard
    case dark
    case tinted

    var background: CGColor {
        switch self {
        case .standard:
            return color(0x43, 0x3C, 0x98)
        case .dark:
            return color(0x18, 0x13, 0x23)
        case .tinted:
            return color(0x24, 0x24, 0x24)
        }
    }

    var mark: CGColor {
        switch self {
        case .standard, .dark:
            return color(0xFF, 0xF8, 0xEE)
        case .tinted:
            return color(0xF2, 0xF2, 0xF2)
        }
    }
}

private struct Rendition {
    let filename: String
    let size: Int
    let appearance: Appearance
}

private let renditions: [Rendition] = [
    Rendition(filename: "HavenAppIcon-1024.png", size: 1024, appearance: .standard),
    Rendition(filename: "HavenAppIcon-Dark-1024.png", size: 1024, appearance: .dark),
    Rendition(filename: "HavenAppIcon-Tinted-1024.png", size: 1024, appearance: .tinted),
    Rendition(filename: "HavenAppIcon-mac-16.png", size: 16, appearance: .standard),
    Rendition(filename: "HavenAppIcon-mac-16@2x.png", size: 32, appearance: .standard),
    Rendition(filename: "HavenAppIcon-mac-32.png", size: 32, appearance: .standard),
    Rendition(filename: "HavenAppIcon-mac-32@2x.png", size: 64, appearance: .standard),
    Rendition(filename: "HavenAppIcon-mac-128.png", size: 128, appearance: .standard),
    Rendition(filename: "HavenAppIcon-mac-128@2x.png", size: 256, appearance: .standard),
    Rendition(filename: "HavenAppIcon-mac-256.png", size: 256, appearance: .standard),
    Rendition(filename: "HavenAppIcon-mac-256@2x.png", size: 512, appearance: .standard),
    Rendition(filename: "HavenAppIcon-mac-512.png", size: 512, appearance: .standard),
    Rendition(filename: "HavenAppIcon-mac-512@2x.png", size: 1024, appearance: .standard),
]

private func color(_ red: UInt8, _ green: UInt8, _ blue: UInt8) -> CGColor {
    CGColor(
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        components: [
            CGFloat(red) / 255,
            CGFloat(green) / 255,
            CGFloat(blue) / 255,
            1,
        ]
    )!
}

private func render(_ rendition: Rendition, into directory: URL) throws {
    let pixelSize = rendition.size
    let bytesPerRow = pixelSize * 4
    var pixels = Data(count: bytesPerRow * pixelSize)

    let image: CGImage = try pixels.withUnsafeMutableBytes { bytes in
        guard let context = CGContext(
            data: bytes.baseAddress,
            width: pixelSize,
            height: pixelSize,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let size = CGFloat(pixelSize)
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        context.interpolationQuality = .high
        context.setFillColor(rendition.appearance.background)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))

        context.setStrokeColor(rendition.appearance.mark)
        context.setLineCap(.butt)
        context.setLineJoin(.round)
        context.setLineWidth(opticalStrokeWidth(for: pixelSize))

        context.move(to: point(0.179_687_5, 0.628_906_25, size: size))
        context.addCurve(
            to: point(0.820_312_5, 0.628_906_25, size: size),
            control1: point(0.309_570_312_5, 0.853_515_625, size: size),
            control2: point(0.690_429_687_5, 0.853_515_625, size: size)
        )

        context.move(to: point(0.179_687_5, 0.371_093_75, size: size))
        context.addCurve(
            to: point(0.820_312_5, 0.371_093_75, size: size),
            control1: point(0.309_570_312_5, 0.146_484_375, size: size),
            control2: point(0.690_429_687_5, 0.146_484_375, size: size)
        )
        context.strokePath()

        guard let image = context.makeImage() else {
            throw CocoaError(.fileWriteUnknown)
        }
        return image
    }

    let representation = NSBitmapImageRep(cgImage: image)
    guard let data = representation.representation(
        using: .png,
        properties: [.compressionFactor: 1]
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }

    try data.write(to: directory.appendingPathComponent(rendition.filename), options: .atomic)
}

private func point(_ x: CGFloat, _ y: CGFloat, size: CGFloat) -> CGPoint {
    CGPoint(x: x * size, y: y * size)
}

private func opticalStrokeWidth(for pixelSize: Int) -> CGFloat {
    let proportional = CGFloat(pixelSize) * 0.066_406_25
    switch pixelSize {
    case ...16:
        return 2
    case ...32:
        return max(2.5, proportional)
    default:
        return proportional
    }
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(
        Data("Usage: swift Scripts/generate_haven_app_icons.swift <appiconset-directory>\n".utf8)
    )
    exit(2)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(
    at: outputDirectory,
    withIntermediateDirectories: true
)

for rendition in renditions {
    try render(rendition, into: outputDirectory)
    print("Generated \(rendition.filename) (\(rendition.size)×\(rendition.size))")
}
