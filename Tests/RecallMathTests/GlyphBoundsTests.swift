import CoreGraphics
import Foundation
import SwiftUI
@_spi(Textual) import SwiftUIMath
import Testing

@Test func italicGlyphInkHasTransparentSpaceBeyondAllImageEdges() throws {
    for latex in ["Y", #"X\setminus Y"#, "f", #"f^{\prime}(x)"#] {
        for size in [18.0, 26.4, 44.0] {
            for scale in [2.0, 3.0] {
                let artwork = try #require(
                    Math.rasterizedFormula(
                        for: latex, font: .init(name: .latinModern, size: size), style: .text, scale: scale))
                let image = artwork.image
                let data = try #require(image.dataProvider?.data)
                let bytes = try #require(CFDataGetBytePtr(data))
                var xs: [Int] = []
                var ys: [Int] = []
                for y in 0..<image.height {
                    for x in 0..<image.width where bytes[y * image.bytesPerRow + x * 4 + 3] > 0 {
                        xs.append(x)
                        ys.append(y)
                    }
                }
                if latex == "Y", size == 26.4, scale == 3 {
                    let metrics = Math.typographicBounds(
                        for: latex, fitting: .unspecified, font: .init(name: .latinModern, size: size),
                        style: .text)
                    // This Y's ink extends beyond its advance width: cropping there loses its right arm.
                    let inkRight = CGFloat(xs.max() ?? 0) / scale - artwork.padding
                    #expect(inkRight > metrics.width)
                }
                #expect(!xs.isEmpty)
                #expect((xs.min() ?? 0) > 0)
                #expect((xs.max() ?? image.width) < image.width - 1)
                #expect((ys.min() ?? 0) > 0)
                #expect((ys.max() ?? image.height) < image.height - 1)
            }
        }
    }
    #expect(
        Math.rasterizedFormula(for: "Y", font: .init(name: .latinModern, size: 24), style: .text, scale: 0)
            == nil)
}
