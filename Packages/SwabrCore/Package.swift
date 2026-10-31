// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwabrCore",
    defaultLocalization: "de",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "SwabrCore", targets: ["SwabrCore"])
    ],
    targets: [
        .target(
            name: "SwabrCore",
            resources: [
                .copy("Resources/clean_rules.json"),
                .copy("Resources/protection.json"),
                .process("Resources/Localizable.xcstrings"),
            ]
        ),
        .testTarget(name: "SwabrCoreTests", dependencies: ["SwabrCore"]),
    ]
)
