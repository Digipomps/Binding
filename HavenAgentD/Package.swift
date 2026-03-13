// swift-tools-version: 6.0
import PackageDescription

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
        .executable(name: "haven-agentd", targets: ["HavenAgentD"])
    ],
    dependencies: [
        .package(path: "../../CellProtocol"),
        .package(path: "../../sprout")
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
                .product(name: "SproutCrypto", package: "sprout")
            ]
        ),
        .target(
            name: "HavenAgentCells",
            dependencies: [
                "HavenAgentRuntime",
                "HavenMacAutomation",
                .product(name: "CellBase", package: "CellProtocol")
            ]
        ),
        .target(
            name: "HavenAgentCellRuntime",
            dependencies: [
                "HavenAgentCells",
                "HavenRuntimeBootstrap",
                .product(name: "CellBase", package: "CellProtocol")
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
