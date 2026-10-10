// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DoorIntoSummer",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "DoorIntoSummer", targets: ["DoorIntoSummer"]),
    ],
    targets: [
        .executableTarget(name: "DoorIntoSummer", resources: [.copy("Fonts")]),
        .testTarget(name: "DoorIntoSummerTests", dependencies: ["DoorIntoSummer"]),
    ]
)
