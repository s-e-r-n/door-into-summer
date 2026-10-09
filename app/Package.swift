// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DoorIntoSummer",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "DoorIntoSummer", targets: ["DoorIntoSummer"]),
    ],
    targets: [
        .target(name: "NativeWindow"),
        .executableTarget(name: "DoorIntoSummer", dependencies: ["NativeWindow"], resources: [.copy("Fonts")]),
        .testTarget(name: "DoorIntoSummerTests", dependencies: ["DoorIntoSummer"]),
    ]
)
