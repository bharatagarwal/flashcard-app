import AppKit
import CoreGraphics

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let themes: [(String, [CGFloat])] = [
    ("light", [245 / 255, 243 / 255, 237 / 255]), ("dark", [20 / 255, 27 / 255, 23 / 255]),
]
for (name, background) in themes {
    let filename = name == "dark" ? "unit-circle-dark.pdf" : "unit-circle.pdf"
    guard let document = CGPDFDocument(root.appendingPathComponent("output/pdf/" + filename) as CFURL),
        let page = document.page(at: 1)
    else { fatalError("Missing compiled PDF") }
    let box = page.getBoxRect(.cropBox)
    let width = 900
    let height = Int(900 * box.height / box.width)
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let bounds = CGRect(x: 0, y: 0, width: width, height: height)
    let scale = min(bounds.width / box.width, bounds.height / box.height)
    context.translateBy(x: bounds.midX, y: bounds.midY)
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: -box.midX, y: -box.midY)
    context.drawPDFPage(page)
    // The page itself must leave its corners transparent; no viewer/page fill is drawn.
    let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
    for (x, y) in [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)] {
        precondition(bytes[(y * width + x) * 4 + 3] == 0, "Diagram contains an opaque corner")
    }
    let figure = context.makeImage()!
    let preview = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    preview.setFillColor(CGColor(red: background[0], green: background[1], blue: background[2], alpha: 1))
    preview.fill(bounds)
    preview.draw(figure, in: bounds)
    let png = NSBitmapImageRep(cgImage: preview.makeImage()!).representation(using: .png, properties: [:])!
    try png.write(to: root.appendingPathComponent("output/pdf/unit-circle-\(name)-preview.png"))
    print("\(name): transparent PDF checked and preview saved")
}
