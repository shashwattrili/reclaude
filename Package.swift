// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Reclaude",
    platforms: [
        .macOS(.v26)
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.0.2")
    ],
    targets: [
        .executableTarget(
            name: "Reclaude",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ],
            path: "Reclaude",
            exclude: ["Resources"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
