// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SecondDock",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "SecondDock",
            path: "Sources/SecondDock"
        )
    ],
    swiftLanguageModes: [.v5]
)
