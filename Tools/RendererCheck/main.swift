import AppKit
import Foundation
import RecallCore
import RecallMath
import SwiftUI
@_spi(Textual) import SwiftUIMath

@MainActor
func run() throws {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let deck = try Codec.decode(
        Deck.self, from: Data(contentsOf: root.appendingPathComponent("App/Resources/starter.json")))
    var texts = deck.cards.flatMap { [$0.prompt, $0.answer] }
    texts += [#"<img src=x onerror='alert(1)'>\[3\mid18\]"#, String(repeating: "Long answer. ", count: 100)]
    let font = Math.Font(name: .latinModern, size: 24)
    var formulaCount = 0
    let start = ContinuousClock.now
    for text in texts {
        for case .formula(let latex, let display) in MathDocument(text).parts where !latex.isEmpty {
            let bounds = Math.typographicBounds(
                for: latex, fitting: .unspecified, font: font, style: display ? .display : .text)
            guard bounds.width.isFinite, bounds.width > 0, bounds.size.height > 0 else {
                throw CheckError.invalidFormula(latex)
            }
            guard
                let artwork = Math.rasterizedFormula(
                    for: latex, font: font, style: display ? .display : .text, scale: 2)
            else { throw CheckError.renderFailed(latex) }
            let image = artwork.image
            let bitmap = NSBitmapImageRep(cgImage: image)
            let hasInk = stride(from: 0, to: image.height, by: 2).contains { y in
                stride(from: 0, to: image.width, by: 2).contains { x in
                    (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0
                }
            }
            guard hasInk else { throw CheckError.renderFailed(latex) }
            formulaCount += 1
        }
    }
    let cold = start.duration(to: .now)
    var count = 0
    let warmStart = ContinuousClock.now
    for text in texts {
        for dark in [false, true] {
            for size in [18.0, 28.0] {
                let view = MathText(text, pointSize: size)
                    .frame(width: 291).padding(12)
                    .background(dark ? Color.black : Color.white)
                    .environment(\.colorScheme, dark ? .dark : .light)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 1
                guard let image = renderer.cgImage, image.width == 315, image.height > 0 else {
                    throw CheckError.renderFailed(text)
                }
                count += 1
            }
        }
    }
    let warm = warmStart.duration(to: .now)
    print(
        "Passed \(formulaCount) native formulas and \(count) native rendered cases at 291 pt, both themes and sizes."
    )
    print("Formula parse/layout and glyph drawing (cold): \(cold). Complete native snapshots: \(warm).")
    // A compact visual sheet checks baselines, fractions, wrapping, and theme changes with the actual renderer.
    let samples = [
        #"What does \(X\setminus Y\) mean?"#,
        #"\(Y\) \(f\) \(f^{\prime}(x)\)"#,
        #"Differentiate \(e^{g(x)}\), where \(g\) is differentiable."#,
        #"\[\frac{1-x\ln2}{2^x}\]"#,
        #"If \(y=f(u)\) and \(u=g(x)\), give \(\displaystyle\frac{dy}{dx}\)."#,
        #"\[\frac{dy}{dx}=\frac{dy}{du}\frac{du}{dx}=f^{\prime}(g(x))g^{\prime}(x)\]"#,
    ]
    let sheet = HStack(alignment: .top, spacing: 0) {
        ForEach([false, true], id: \.self) { dark in
            VStack(alignment: .leading, spacing: 24) {
                ForEach(samples, id: \.self) { MathText($0, pointSize: 24) }
            }
            .padding(24).frame(width: 343)
            .background(dark ? Color.black : Color.white)
            .foregroundStyle(dark ? Color.white : Color.black)
            .environment(\.colorScheme, dark ? .dark : .light)
        }
    }
    let renderer = ImageRenderer(content: sheet)
    renderer.scale = 2
    if let image = renderer.cgImage {
        let bitmap = NSBitmapImageRep(cgImage: image)
        try bitmap.representation(using: .png, properties: [:])?.write(
            to: URL(fileURLWithPath: "/tmp/recur-native-math.png"))
    }
}

enum CheckError: Error {
    case invalidFormula(String)
    case renderFailed(String)
}

do { try run() } catch {
    print("Native renderer check failed: \(error)")
    exit(1)
}
