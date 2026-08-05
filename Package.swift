// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VoidBar",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "VoidBar", targets: ["VoidBar"])
    ],
    targets: [
        .executableTarget(
            name: "VoidBar",
            path: "Sources/VoidBar",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "VoidBarTests",
            dependencies: ["VoidBar"],
            path: "Tests/VoidBarTests"
        )
    ]
)
