// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AILimitTracker",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "AILimitTracker", path: "Sources/AILimitTracker")
    ]
)
