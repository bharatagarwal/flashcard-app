import SwiftUI
@_spi(Textual) import SwiftUIMath

/// Synchronous native text and cached native math: no document loads or asynchronous height messages.
public struct MathText: View {
    private let document: MathDocument
    private let pointSize: CGFloat
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    public init(_ text: String, pointSize: CGFloat = 18) {
        document = MathDocument(text)
        self.pointSize = pointSize
    }

    public var body: some View {
        let size = min(pointSize * scale, 50)
        Group {
            if document.parts.allSatisfy({ if case .text = $0 { true } else { false } }) {
                Text(document.parts.map { if case .text(let text) = $0 { text } else { "" } }.joined())
                    .font(.system(size: size)).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                MathFlow(lineSpacing: size * 0.35) {
                    ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                        switch token {
                        case .word(let word):
                            Text(word).font(.system(size: size)).fixedSize(horizontal: false, vertical: true)
                        case .formula(let latex, let display):
                            if display {
                                MathFlow(lineSpacing: size * 0.45) {
                                    ForEach(
                                        Array(MathDocument.equationFragments(latex).enumerated()),
                                        id: \.offset
                                    ) { _, fragment in
                                        NativeFormula(
                                            fragment.hasPrefix("=") ? #"\;"# + fragment : fragment,
                                            pointSize: size * 1.1, display: true)
                                    }
                                }
                                .layoutValue(key: MathBreak.self, value: .display)
                            } else {
                                NativeFormula(latex, pointSize: size * 1.1, display: false)
                            }
                        case .newline:
                            Color.clear.frame(width: 0, height: size)
                                .layoutValue(key: MathBreak.self, value: .newline)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            document.parts.map { part in
                switch part {
                case .text(let text): return text
                case .formula(let latex, _): return " " + MathSpeech.read(latex) + " "
                }
            }.joined())
    }

    private enum Token {
        case word(String)
        case formula(String, Bool)
        case newline
    }
    private var tokens: [Token] {
        document.parts.flatMap { part -> [Token] in
            switch part {
            case .formula(let latex, let display): return [.formula(latex, display)]
            case .text(let text):
                var tokens: [Token] = []
                var word = ""
                for character in text {
                    if character == "\n" {
                        if !word.isEmpty {
                            tokens.append(.word(word))
                            word = ""
                        }
                        tokens.append(.newline)
                    } else if character.isWhitespace {
                        word.append(character)
                        tokens.append(.word(word))
                        word = ""
                    } else {
                        word.append(character)
                    }
                }
                if !word.isEmpty { tokens.append(.word(word)) }
                return tokens
            }
        }
    }
}

private struct NativeFormula: View {
    let latex: String
    let pointSize: CGFloat
    let display: Bool
    @Environment(\.displayScale) private var displayScale

    init(_ latex: String, pointSize: CGFloat, display: Bool) {
        self.latex = latex
        self.pointSize = pointSize
        self.display = display
    }
    var body: some View {
        let font = Math.Font(name: .latinModern, size: pointSize)
        let style: Math.TypesettingStyle = display ? .display : .text
        let metrics = Math.typographicBounds(for: latex, fitting: .unspecified, font: font, style: style)
        if metrics.size.height > 0 {
            if let artwork = FormulaArtworkCache.shared.image(
                latex: latex, font: font, style: style, scale: displayScale)
            {
                FormulaImageLayout(size: metrics.size) {
                    Image(decorative: artwork, scale: displayScale)
                        .renderingMode(.template).resizable()
                }
                .alignmentGuide(.firstTextBaseline) { dimensions in
                    metrics.ascent * dimensions.width / max(1, metrics.width)
                }
            } else {
                Text("Unable to render: \(latex)").font(.system(size: pointSize * 0.8))
            }
        } else {
            Text(latex.isEmpty ? " " : "Unable to render: \(latex)")
                .font(.system(size: pointSize * 0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Rasterize once at the screen's scale, then reuse a transparent native image through scrolling and 3D turns.
/// This also isolates Core Text drawing from the card's animated transform.
@MainActor
private final class FormulaArtworkCache {
    static let shared = FormulaArtworkCache()
    private final class Artwork: NSObject {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }
    private let cache = NSCache<NSString, Artwork>()
    private init() {
        cache.countLimit = 512
        cache.totalCostLimit = 16 * 1024 * 1024
    }
    func image(latex: String, font: Math.Font, style: Math.TypesettingStyle, scale: CGFloat) -> CGImage? {
        let key = "\(font.name.rawValue)|\(font.size)|\(style)|\(scale)|\(latex)" as NSString
        if let hit = cache.object(forKey: key) { return hit.image }
        let renderer = ImageRenderer(
            content: Math(latex).mathFont(font).mathTypesettingStyle(style)
                .foregroundStyle(.black).fixedSize())
        renderer.scale = scale
        guard let image = renderer.cgImage else { return nil }
        cache.setObject(Artwork(image), forKey: key, cost: image.bytesPerRow * image.height)
        return image
    }
}

/// Scale an indivisible formula only when it cannot fit; display equations first break at safe boundaries.
private struct FormulaImageLayout: Layout {
    let size: CGSize
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = min(size.width, max(1, proposal.width ?? size.width))
        return CGSize(width: width, height: size.height * width / max(1, size.width))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}

private enum MathBreak: LayoutValueKey {
    enum Kind { case none, display, newline }
    static let defaultValue: Kind = .none
}

/// Wrap words and inline equations together, aligning their baselines. Display math owns a line.
private struct MathFlow: Layout {
    let lineSpacing: CGFloat
    struct Placement {
        let point: CGPoint
        let size: CGSize
    }
    struct Result {
        let size: CGSize
        let placements: [Placement]
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? 300, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (view, placement) in zip(subviews, result.placements) {
            view.place(
                at: CGPoint(x: bounds.minX + placement.point.x, y: bounds.minY + placement.point.y),
                proposal: ProposedViewSize(placement.size))
        }
    }
    private func arrange(width: CGFloat, subviews: Subviews) -> Result {
        let width = max(1, width)
        var placements: [Placement] = []
        var line: [(index: Int, x: CGFloat, size: CGSize, baseline: CGFloat)] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        func finishLine() {
            guard !line.isEmpty else { return }
            let ascent = line.map(\.baseline).max() ?? 0
            let descent = line.map { $0.size.height - $0.baseline }.max() ?? 0
            for item in line {
                placements[item.index] = Placement(
                    point: CGPoint(x: item.x, y: y + ascent - item.baseline), size: item.size)
            }
            y += ascent + descent + lineSpacing
            line = []
            x = 0
        }
        for (index, view) in subviews.enumerated() {
            let dimensions = view.dimensions(in: ProposedViewSize(width: width, height: nil))
            let size = CGSize(width: dimensions.width, height: dimensions.height)
            let kind = view[MathBreak.self]
            if kind != .none || (x > 0 && x + size.width > width) { finishLine() }
            placements.append(Placement(point: .zero, size: size))
            line.append((index, x, size, dimensions[.firstTextBaseline]))
            x += size.width
            if kind != .none { finishLine() }
        }
        finishLine()
        return Result(size: CGSize(width: width, height: max(0, y - lineSpacing)), placements: placements)
    }
}
