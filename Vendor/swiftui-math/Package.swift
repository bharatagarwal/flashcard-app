// swift-tools-version: 6.0
import PackageDescription

// Runtime-only snapshot: omit upstream's snapshot-test dependency.
let package = Package(
    name: "swiftui-math",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "SwiftUIMath", targets: ["SwiftUIMath"])],
    targets: [
        .target(name: "SwiftUIMath", resources: [.copy("mathFonts.bundle")])
    ]
)
