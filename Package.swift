// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RecallCore", platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "RecallCore", targets: ["RecallCore"])],
    dependencies: [.package(path: "Vendor/swift-fsrs")],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(
            name: "RecallCore", dependencies: ["CSQLite", .product(name: "FSRS", package: "swift-fsrs")],
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]),
        .testTarget(
            name: "RecallCoreTests", dependencies: ["RecallCore", "CSQLite"],
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]),
    ],
    swiftLanguageModes: [.v6]
)
