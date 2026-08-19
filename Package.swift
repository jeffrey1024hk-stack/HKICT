// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PostureAI",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "PostureAICore", targets: ["PostureAICore"]),
        ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.26.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.4")
    ],
    targets: [
        // Core logic library - testable, no main entry point
        .target(
            name: "PostureAICore",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources",
            exclude: ["App", "Icons"],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Vision"),
                .linkedFramework("CoreImage"),
                .linkedFramework("CoreMotion"),
                .linkedFramework("IOBluetooth"),
                .linkedFramework("AppIntents"),
                .linkedFramework("CoreMediaIO"),
                .linkedFramework("Intents"),
                .linkedFramework("WidgetKit")
            ]
        ),
        // Executable target
        .executableTarget(
            name: "PostureAI",
            dependencies: ["PostureAICore"],
            path: "Sources/App"
        ),
        // Widget extension target (lives outside Sources/ so the main build
        // ignores it; assembled into Contents/PlugIns by build.sh via the
        // PostureAIWidget.xcodeproj Widget Extension target)
        // Test target
        .testTarget(
            name: "PostureAITests",
            dependencies: [
                "PostureAICore",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ],
            path: "Tests"
        )
    ]
)
