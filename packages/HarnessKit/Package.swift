// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Tessera",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
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
            path: "Sources/HarnessKit",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-weak_framework", "-Xlinker", "FoundationModels"])
            ]
        ),
        .testTarget(
            name: "HarnessKitTests",
            dependencies: ["Tessera"],
            path: "Tests/HarnessKitTests",
        ),
    ]
)
