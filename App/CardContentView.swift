import CoreGraphics
import RecallCore
import SwiftUI
import UIKit

struct CardBlocksView: View {
    @EnvironmentObject var model: AppModel
    let blocks: [LessonBlock]
    var assets: [DiagramAsset]?
    var allowsTextInteraction = true
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(blocks) { block in
                switch block.kind {
                case .text: MathText(block.text ?? "").allowsHitTesting(allowsTextInteraction)
                case .equation:
                    MathText(
                        (block.display == false ? "\\(" : "\\[") + (block.text ?? "")
                            + (block.display == false ? "\\)" : "\\]"), pointSize: 20
                    )
                    .allowsHitTesting(allowsTextInteraction)
                case .diagram:
                    if let asset = (assets ?? model.library?.deck.assets ?? []).first(where: {
                        $0.id == block.assetID
                    }) {
                        CardFigure(asset: asset)
                    }
                }
                if let caption = block.caption {
                    MathText(caption, pointSize: 14).allowsHitTesting(allowsTextInteraction)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CardFigure: View {
    let asset: DiagramAsset
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingViewer = false
    private var data: Data { colorScheme == .dark ? (asset.darkData ?? asset.data) : asset.data }
    var body: some View {
        Button {
            showingViewer = true
        } label: {
            PDFDiagram(data: data)
                .allowsHitTesting(false)
                .aspectRatio(PDFDiagram.aspectRatio(for: data), contentMode: .fit)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.caption.weight(.semibold)).padding(10)
                        .background(.regularMaterial, in: Circle())
                        .padding(4).accessibilityHidden(true)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(asset.altText)
        .accessibilityHint("Open the diagram to zoom and pan")
        .fullScreenCover(isPresented: $showingViewer) { DiagramViewer(asset: asset) }
    }
}

/// Core Graphics draws only PDF contents, without a viewer's opaque page background.
struct PDFDiagram: UIViewRepresentable {
    let data: Data
    static func aspectRatio(for data: Data) -> CGFloat {
        guard let provider = CGDataProvider(data: data as CFData),
            let document = CGPDFDocument(provider), let page = document.page(at: 1)
        else { return 1 }
        let bounds = page.getBoxRect(.cropBox)
        return abs(page.rotationAngle) % 180 == 0
            ? bounds.width / max(1, bounds.height) : bounds.height / max(1, bounds.width)
    }
    func makeUIView(context: Context) -> VectorFigureView { VectorFigureView() }
    func updateUIView(_ view: VectorFigureView, context: Context) {
        if view.data != data { view.data = data }
    }
}

final class VectorFigureView: UIView {
    var data: Data? { didSet { setNeedsDisplay() } }
    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func draw(_ rect: CGRect) {
        guard let data, let provider = CGDataProvider(data: data as CFData),
            let document = CGPDFDocument(provider), let page = document.page(at: 1),
            let context = UIGraphicsGetCurrentContext()
        else { return }
        context.saveGState()
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        let box = page.getBoxRect(.cropBox)
        let rotated = abs(page.rotationAngle) % 180 != 0
        let width = rotated ? box.height : box.width
        let height = rotated ? box.width : box.height
        let scale = min(bounds.width / max(1, width), bounds.height / max(1, height))
        context.translateBy(x: bounds.midX, y: bounds.midY)
        context.scaleBy(x: scale, y: scale)
        context.rotate(by: -CGFloat(page.rotationAngle) * .pi / 180)
        context.translateBy(x: -box.midX, y: -box.midY)
        context.drawPDFPage(page)
        context.restoreGState()
    }
}
