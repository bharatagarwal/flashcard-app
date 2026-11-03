import AppKit
import CoreGraphics
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("Diagrams/card-lessons/manifest.json"))) as! [[String: String]]
for theme in ["light", "dark"] {
    let atlasName = theme == "light" ? "main" : "dark"
    guard let document = CGPDFDocument(root.appendingPathComponent("tmp/pdfs/card-lessons/\(atlasName).pdf") as CFURL) else { fatalError("Missing atlas") }
    precondition(document.numberOfPages == manifest.count, "Expected one page per card, got \(document.numberOfPages)")
    for (index, entry) in manifest.enumerated() {
        let page = document.page(at: index + 1)!
        let box = page.getBoxRect(.cropBox)
        var bounds = CGRect(origin: .zero, size: box.size)
        let suffix = theme == "dark" ? "-dark" : ""
        let url = root.appendingPathComponent("output/pdf/cards/\(entry["id"]!)\(suffix).pdf")
        let consumer = CGDataConsumer(url: url as CFURL)!
        let context = CGContext(consumer: consumer, mediaBox: &bounds, nil)!
        context.beginPDFPage(nil)
        context.translateBy(x: -box.minX, y: -box.minY)
        context.drawPDFPage(page)
        context.endPDFPage(); context.closePDF()
    }
    // Contact sheets at slightly above phone width, with page bounds and themes checked.
    for batch in stride(from: 0, to: manifest.count, by: 12) {
        let width = 1440, height = 1080, tileW = 360, tileH = 360
        let bitmap = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width*4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let dark = theme == "dark"
        bitmap.setFillColor(CGColor(red: dark ? 20/255 : 245/255, green: dark ? 27/255 : 243/255, blue: dark ? 23/255 : 237/255, alpha: 1))
        bitmap.fill(CGRect(x: 0,y: 0,width: width,height: height))
        for index in batch..<min(batch+12, manifest.count) {
            let page = document.page(at: index+1)!
            let box = page.getBoxRect(.cropBox)
            let local = index-batch, col = local%4, row = local/4
            let rect = CGRect(x: col*tileW+10,y: height-(row+1)*tileH+20,width: tileW-20,height: tileH-55)
            let scale = min(rect.width/box.width, rect.height/box.height)
            bitmap.saveGState()
            bitmap.translateBy(x: rect.midX,y: rect.midY)
            bitmap.scaleBy(x: scale,y: scale)
            bitmap.translateBy(x: -box.midX,y: -box.midY)
            bitmap.drawPDFPage(page); bitmap.restoreGState()
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: bitmap, flipped: false)
            let text = manifest[index]["id"]! as NSString
            text.draw(at: CGPoint(x: col*tileW+10,y: height-row*tileH-25),withAttributes: [.font:NSFont.systemFont(ofSize:14),.foregroundColor:dark ? NSColor.white : NSColor.black])
            NSGraphicsContext.restoreGraphicsState()
            let check = CGContext(data: nil,width: 320,height: 320,bitsPerComponent:8,bytesPerRow:1280,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            check.scaleBy(x: 320/box.width,y: 320/box.height); check.translateBy(x: -box.minX,y: -box.minY); check.drawPDFPage(page)
            let bytes = check.data!.assumingMemoryBound(to: UInt8.self)
            for pixel in [0,319,319*320,320*320-1] { precondition(bytes[pixel*4+3] == 0, "Opaque page background") }
        }
        let png = NSBitmapImageRep(cgImage:bitmap.makeImage()!).representation(using:.png,properties:[:])!
        try png.write(to:root.appendingPathComponent("output/pdf/cards-\(theme)-\(batch/12+1).png"))
    }
    print("\(theme): split \(manifest.count) vector figures, checked transparent corners, saved 4 contact sheets")
}
