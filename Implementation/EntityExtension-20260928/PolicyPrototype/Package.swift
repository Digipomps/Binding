// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "EntityExperiencePolicy", products: [
    .library(name: "EntityExperiencePolicy", targets: ["EntityExperiencePolicy"])
], targets: [.target(name: "EntityExperiencePolicy"),
             .testTarget(name: "EntityExperiencePolicyTests", dependencies: ["EntityExperiencePolicy"])])
