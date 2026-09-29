// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ConfettiKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "ConfettiKit", targets: ["ConfettiKit"]),
    ],
    targets: [
        .target(name: "ConfettiKit"),
        .testTarget(name: "ConfettiKitTests", dependencies: ["ConfettiKit"]),
    ]
)
