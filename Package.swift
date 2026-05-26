// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuickPod",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "QuickPod",
            path: "Sources/QuickPod"
        )
    ]
)
