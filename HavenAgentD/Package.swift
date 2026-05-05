// swift-tools-version: 6.0
import Foundation
import PackageDescription

let packageDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let localCellProtocolPath = packageDirectory
    .appendingPathComponent("../../CellProtocol")
    .standardizedFileURL.path
let cellProtocolDependency: Package.Dependency = FileManager.default.fileExists(
    atPath: "\(localCellProtocolPath)/Package.swift"
) ? .package(path: localCellProtocolPath)
  : .package(
      url: "https://github.com/Digipomps/CellProtocol.git",
      revision: "0e0c5337eec6ba7b18ea2bfa63f863e5c9c4ee77"
  )

let package = Package(
    name: "HavenAgentD",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "HavenMacAutomation", targets: ["HavenMacAutomation"]),
        .library(name: "HavenRuntimeBootstrap", targets: ["HavenRuntimeBootstrap"]),
        .library(name: "HavenAgentRuntime", targets: ["HavenAgentRuntime"]),
        .library(name: "HavenAgentCells", targets: ["HavenAgentCells"]),
        .library(name: "HavenAgentCellRuntime", targets: ["HavenAgentCellRuntime"]),
        .executable(name: "haven-agentd", targets: ["HavenAgentD"]),
        .executable(name: "haven-agentd-mcp", targets: ["HavenAgentDMCP"])
    ],
    dependencies: [
        cellProtocolDependency,
        .package(url: "https://github.com/Digipomps/Sprout.git", revision: "d53d2d18f5cadd4bd0e73e449101a3b766f65af7"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.1")
    ],
    targets: [
        .target(
            name: "HavenMacAutomation"
        ),
        .target(
            name: "HavenRuntimeBootstrap"
        ),
        .target(
            name: "HavenAgentRuntime",
            dependencies: [
                "HavenMacAutomation",
                "HavenRuntimeBootstrap",
                .product(name: "CellBase", package: "CellProtocol"),
                .product(name: "SproutAppSupport", package: "sprout"),
                .product(name: "SproutCore", package: "sprout"),
                .product(name: "SproutCrypto", package: "sprout"),
                .product(name: "SproutResolverAdapter", package: "sprout")
            ]
        ),
        .target(
            name: "HavenAgentCells",
            dependencies: [
                "HavenAgentRuntime",
                "HavenMacAutomation",
                .product(name: "CellBase", package: "CellProtocol"),
                .product(name: "SproutCrypto", package: "sprout")
            ]
        ),
        .target(
            name: "HavenAgentCellRuntime",
            dependencies: [
                "HavenAgentRuntime",
                "HavenAgentCells",
                "HavenRuntimeBootstrap",
                .product(name: "CellBase", package: "CellProtocol"),
                .product(name: "CellVapor", package: "CellProtocol"),
                .product(name: "Vapor", package: "vapor")
            ]
        ),
        .executableTarget(
            name: "HavenAgentD",
            dependencies: [
                "HavenAgentRuntime",
                "HavenRuntimeBootstrap",
                "HavenMacAutomation",
                "HavenAgentCells",
                "HavenAgentCellRuntime",
                .product(name: "SproutCore", package: "sprout"),
                .product(name: "SproutCrypto", package: "sprout"),
                .product(name: "SproutResolverAdapter", package: "sprout")
            ]
        ),
        .executableTarget(
            name: "HavenAgentDMCP",
            dependencies: [
                "HavenAgentRuntime",
                "HavenRuntimeBootstrap",
                "HavenAgentCells",
                "HavenAgentCellRuntime"
            ]
        ),
        .testTarget(
            name: "HavenMacAutomationTests",
            dependencies: [
                "HavenMacAutomation"
            ]
        ),
        .testTarget(
            name: "HavenAgentRuntimeTests",
            dependencies: [
                "HavenAgentRuntime",
                "HavenRuntimeBootstrap",
                "HavenMacAutomation",
                .product(name: "SproutResolverAdapter", package: "sprout"),
                .product(name: "SproutCrypto", package: "sprout")
            ]
        ),
        .testTarget(
            name: "HavenAgentCellsTests",
            dependencies: [
                "HavenAgentCellRuntime",
                "HavenAgentCells",
                .product(name: "CellBase", package: "CellProtocol")
            ]
        ),
        .testTarget(
            name: "HavenAgentCellRuntimeTests",
            dependencies: [
                "HavenAgentCellRuntime",
                "HavenAgentCells",
                "HavenRuntimeBootstrap",
                .product(name: "CellBase", package: "CellProtocol")
            ]
        )
    ]
)
