// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ContextComposerKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ContextComposerKit",
            targets: ["ContextComposerKit"]
        )
    ],
    targets: [
        .target(
            name: "ContextComposerKit",
            path: "Sources/ContextComposerKit"
        ),
        .testTarget(
            name: "ContextComposerKitTests",
            dependencies: ["ContextComposerKit"],
            path: "Tests/ContextComposerKitTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
