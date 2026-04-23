// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "chrome-cli",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "chrome-cli",
            targets: ["chrome_cli"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.4.0")
    ],
    targets: [
        .executableTarget(
            name: "chrome_cli",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            linkerSettings: [
                .linkedFramework("ScriptingBridge"),
                .linkedFramework("ApplicationServices")
            ]
        ),
        .testTarget(
            name: "chrome_cliTests",
            dependencies: ["chrome_cli"]
        )
    ]
)
