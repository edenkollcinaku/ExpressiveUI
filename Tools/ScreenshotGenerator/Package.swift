// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScreenshotGenerator",
    platforms: [.macOS(.v13)],
    dependencies: [.package(path: "../..")],
    targets: [
        .executableTarget(
            name: "ScreenshotGenerator",
            dependencies: [.product(name: "ExpressiveUI", package: "ExpressiveUI")]
        )
    ]
)
