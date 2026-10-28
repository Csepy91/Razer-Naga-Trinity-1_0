// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NagaTrinityControl",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "NagaTrinityControl", targets: ["NagaTrinityControl"]),
        .executable(name: "naga-cli", targets: ["NagaCLI"]),
        .executable(name: "naga-core-smoke", targets: ["NagaCoreSmoke"]),
        .library(name: "NagaCore", targets: ["NagaCore"]),
    ],
    targets: [
        .target(
            name: "NagaUSB",
            path: "Sources/NagaUSB",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
            ]
        ),
        .target(
            name: "NagaCore",
            dependencies: ["NagaUSB"],
            path: "Sources/NagaCore"
        ),
        .executableTarget(
            name: "NagaCoreSmoke",
            dependencies: ["NagaCore"],
            path: "Sources/NagaCoreSmoke"
        ),
        .executableTarget(
            name: "NagaCLI",
            dependencies: ["NagaCore"],
            path: "Sources/NagaCLI"
        ),
        .executableTarget(
            name: "NagaTrinityControl",
            dependencies: ["NagaCore"],
            path: "Sources/NagaTrinityControl",
            resources: [
                .copy("Resources/i18n"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("IOKit"),
            ]
        ),
    ]
)
