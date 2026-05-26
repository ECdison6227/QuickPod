// swift-tools-version: 5.9
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