// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ExpressiveUI",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ExpressiveUI", targets: ["ExpressiveUI"])
    ],
    targets: [
        .target(name: "ExpressiveUI"),
        .testTarget(name: "ExpressiveUITests", dependencies: ["ExpressiveUI"])
    ]
)
