// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Reclaude",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .executableTarget(
            name: "Reclaude",
            path: "Reclaude",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
