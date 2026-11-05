import CoreGraphics
import Foundation

extension Math {
  @_spi(Textual)
  public struct RasterizedFormula {
    public let image: CGImage
    public let padding: CGFloat
  }

  /// Keep glyph ink beyond the advance width, such as an italic Y's right arm.
  /// The caller retains the logical typographic size and places this padded artwork around it.
  @_spi(Textual)
  public static nonisolated func rasterizedFormula(
    for latex: String,
    font: Font,
    style: TypesettingStyle,
    scale: CGFloat
  ) -> RasterizedFormula? {
    guard scale.isFinite, scale > 0,
      let display = DisplayProvider.shared.display(for: latex, font: font, style: style, proposedWidth: 0)
    else { return nil }
    let padding = max(2 / scale, font.size * 0.4)
    let width = ceil((display.width + 2 * padding) * scale)
    let height = ceil((display.ascent + display.descent + 2 * padding) * scale)
    guard width.isFinite, height.isFinite, width > 0, height > 0,
      width <= 16384, height <= 16384, width * height <= 16_000_000,
      let context = CGContext(
        data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: padding, y: padding + display.descent)
    context.draw(display, foregroundColor: CGColor(gray: 0, alpha: 1))
    guard let image = context.makeImage() else { return nil }
    return RasterizedFormula(image: image, padding: padding)
  }
}
