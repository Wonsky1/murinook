// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MurinookKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MurinookKit", targets: [
            "MurinookDomain", "MurinookUseCases", "MurinookStorage", "MurinookMacIntegration",
            "MurinookDesignSystem", "ClipboardFeature", "ShelfFeature", "PasteQueueFeature",
            "SettingsFeature", "OnboardingFeature", "MurinookPresentation"
        ])
    ],
    targets: [
        .target(name: "MurinookDomain"),
        .target(name: "MurinookPresentation"),
        .target(name: "MurinookUseCases", dependencies: ["MurinookDomain"]),
        .target(name: "MurinookStorage", dependencies: ["MurinookDomain", "MurinookUseCases"]),
        .target(name: "MurinookMacIntegration", dependencies: ["MurinookDomain", "MurinookUseCases"]),
        .target(name: "MurinookDesignSystem", resources: [.process("Resources")]),
        .target(name: "ClipboardFeature", dependencies: ["MurinookDomain", "MurinookUseCases", "MurinookDesignSystem"], resources: [.process("Resources")]),
        .target(name: "ShelfFeature", dependencies: ["MurinookDomain", "MurinookUseCases", "MurinookDesignSystem", "MurinookPresentation"], resources: [.process("Resources")]),
        .target(name: "PasteQueueFeature", dependencies: ["MurinookDomain", "MurinookUseCases", "MurinookDesignSystem"], resources: [.process("Resources")]),
        .target(name: "SettingsFeature", dependencies: ["MurinookDomain", "MurinookUseCases", "MurinookDesignSystem"], resources: [.process("Resources")]),
        .target(name: "OnboardingFeature", dependencies: ["MurinookDomain", "MurinookUseCases", "MurinookDesignSystem"], resources: [.process("Resources")]),
        .testTarget(name: "MurinookPresentationTests", dependencies: ["MurinookPresentation"]),
        .testTarget(name: "MurinookCoreTests", dependencies: ["MurinookDomain", "MurinookUseCases", "MurinookStorage"]),
        .testTarget(name: "MurinookMacTests", dependencies: ["MurinookMacIntegration", "MurinookDomain", "SettingsFeature"])
    ]
)
