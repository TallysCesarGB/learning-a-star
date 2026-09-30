// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CacadorEstelar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CacadorEstelar",
            path: "Sources/CacadorEstelar"
        )
    ]
)
