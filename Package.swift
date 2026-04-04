// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MarkdownPad",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "MarkdownPad",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            path: "Sources/MarkdownPad"
        ),
        .testTarget(
            name: "MarkdownPadTests",
            dependencies: ["MarkdownPad"],
            path: "Tests/MarkdownPadTests"
        ),
    ]
)
