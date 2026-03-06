// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MarkdownCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "MarkdownCore",
            targets: ["MarkdownCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.4.0")
    ],
    targets: [
        .target(
            name: "MarkdownCore",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            resources: [
                .copy("Resources/mermaid.min.js"),
                .copy("Resources/highlight.min.js"),
                .copy("Resources/katex.min.js"),
                .copy("Resources/auto-render.min.js"),
                .copy("Resources/pako.min.js"),
                .copy("Resources/katex.min.css"),
                .copy("Resources/atom-one-dark.min.css"),
                .copy("Resources/atom-one-light.min.css"),
            ]
        )
    ]
)
