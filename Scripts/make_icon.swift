import AppKit

// Export the generated source at the opaque App Store size and at home-screen size.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("Design/RecurIcon-source.png")
guard let source = NSImage(contentsOf: sourceURL) else {
    fatalError("Missing icon source at \(sourceURL.path)")
}
for (size, path) in [
    (1024, "App/Resources/Assets.xcassets/AppIcon.appiconset/Icon.png"),
    (120, "Design/RecurIcon-preview.png"),
] {
    guard
        let context = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )
    else { fatalError("Could not create the icon export context") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.current?.imageInterpolation = .high
    source.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    guard let image = context.makeImage(),
        let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    else { fatalError("Could not encode icon PNG") }
    try png.write(to: root.appendingPathComponent(path))
}
