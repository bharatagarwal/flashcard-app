// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RecallCore", platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RecallCore", targets: ["RecallCore"]),
        .library(name: "RecallMath", targets: ["RecallMath"]),
    ],
    dependencies: [.package(path: "Vendor/swift-fsrs"), .package(path: "Vendor/swiftui-math")],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(
            name: "RecallCore", dependencies: ["CSQLite", .product(name: "FSRS", package: "swift-fsrs")],
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]),
        .target(
            name: "RecallMath", dependencies: [.product(name: "SwiftUIMath", package: "swiftui-math")],
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]),
        .testTarget(
            name: "RecallMathTests",
            dependencies: ["RecallMath", .product(name: "SwiftUIMath", package: "swiftui-math")],
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]),
        .executableTarget(
            name: "RendererCheck",
            dependencies: [
                "RecallMath", "RecallCore", .product(name: "SwiftUIMath", package: "swiftui-math"),
            ],
            path: "Tools/RendererCheck"),
        .testTarget(
            name: "RecallCoreTests", dependencies: ["RecallCore", "CSQLite"],
            swiftSettings: [.enableUpcomingFeature("ExistentialAny")]),
    ],
    swiftLanguageModes: [.v6]
)
