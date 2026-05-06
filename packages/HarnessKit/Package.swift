// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tessera",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
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
            path: "Tests/HarnessKitTests",
        ),
    ]
)
