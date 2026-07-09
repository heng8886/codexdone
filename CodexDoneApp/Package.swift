// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexDone",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "CodexDoneCore", targets: ["CodexDoneCore"]),
        .executable(name: "CodexDoneApp", targets: ["CodexDoneApp"])
    ],
    targets: [
        .target(name: "CodexDoneCore"),
        .executableTarget(
            name: "CodexDoneApp",
            dependencies: ["CodexDoneCore"]
        ),
        .testTarget(
            name: "CodexDoneCoreTests",
            dependencies: ["CodexDoneCore"]
        )
    ]
)
