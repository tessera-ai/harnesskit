// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tessera",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0")
    ],
    products: [
        .library(
            name: "Tessera",
            targets: ["Tessera"]
        )
    ],
    targets: [
        .target(
            name: "Tessera",
            path: "Sources/HarnessKit"
        ),
        .testTarget(
            name: "HarnessKitTests",
            dependencies: ["Tessera"],
            path: "Tests/HarnessKitTests"
        )
    ]
)
