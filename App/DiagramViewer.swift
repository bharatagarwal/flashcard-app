import RecallCore
import SwiftUI
import UIKit

private struct DiagramZoomRequest {
    enum Action { case fit, increase, decrease }
    let id = UUID()
    let action: Action
}

struct DiagramViewer: View {
    let asset: DiagramAsset
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var request = DiagramZoomRequest(action: .fit)
    private var data: Data { colorScheme == .dark ? (asset.darkData ?? asset.data) : asset.data }

    var body: some View {
        NavigationStack {
            ZoomableDiagram(data: data, description: asset.altText, request: request)
                .background(Palette.paper)
                .safeAreaInset(edge: .bottom) {
                    Text("Pinch to zoom · drag to move · double-tap to zoom")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(12)
                        .frame(maxWidth: .infinity).background(Palette.paper)
                }
                .navigationTitle("Diagram")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button {
                            request = .init(action: .decrease)
                        } label: {
                            Label("Zoom out", systemImage: "minus.magnifyingglass")
                        }
                        Spacer()
                        Button("Fit") { request = .init(action: .fit) }
                        Spacer()
                        Button {
                            request = .init(action: .increase)
                        } label: {
                            Label("Zoom in", systemImage: "plus.magnifyingglass")
                        }
                    }
                }
        }
        .tint(Palette.accent)
    }
}

private struct ZoomableDiagram: UIViewRepresentable {
    let data: Data
    let description: String
    let request: DiagramZoomRequest
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeUIView(context: Context) -> DiagramScrollView { DiagramScrollView() }
    func updateUIView(_ view: DiagramScrollView, context: Context) {
        view.configure(data: data, description: description)
        if view.lastRequest != request.id {
            view.lastRequest = request.id
            view.perform(request.action, animated: !reduceMotion)
        }
    }
    static func dismantleUIView(_ view: DiagramScrollView, coordinator: ()) { view.delegate = nil }
}

private final class DiagramScrollView: UIScrollView, UIScrollViewDelegate {
    let figure = VectorFigureView(frame: .zero)
    var lastRequest: UUID?
    private var viewport: CGSize = .zero
    private var aspect: CGFloat = 1

    init() {
        super.init(frame: .zero)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 4
        backgroundColor = .clear
        isOpaque = false
        contentInsetAdjustmentBehavior = .never
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        scrollsToTop = false
        addSubview(figure)
        figure.isAccessibilityElement = true
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(data: Data, description: String) {
        figure.accessibilityLabel = description
        guard figure.data != data else { return }
        let newAspect = PDFDiagram.aspectRatio(for: data)
        figure.data = data
        if abs(newAspect - aspect) > 0.001 { viewport = .zero }
        aspect = newAspect
        setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }
        if viewport != bounds.size {
            viewport = bounds.size
            setZoomScale(minimumZoomScale, animated: false)
            let width = min(bounds.width, bounds.height * aspect)
            let size = CGSize(width: width, height: width / max(0.001, aspect))
            figure.frame = CGRect(origin: .zero, size: size)
            contentSize = size
            renderAtCurrentScale()
        }
        centerFigure()
    }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { figure }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerFigure() }
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        renderAtCurrentScale()
    }
    private func centerFigure() {
        let horizontal = max(0, (bounds.width - figure.frame.width) / 2)
        let vertical = max(0, (bounds.height - figure.frame.height) / 2)
        let inset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
        if contentInset != inset { contentInset = inset }
        if zoomScale <= minimumZoomScale * 1.001 {
            let offset = CGPoint(x: -inset.left, y: -inset.top)
            if contentOffset != offset { contentOffset = offset }
        }
    }
    private func renderAtCurrentScale() {
        // Re-render the PDF at the finished zoom level instead of stretching a cached bitmap.
        figure.contentScaleFactor = max(1, traitCollection.displayScale) * zoomScale
        figure.setNeedsDisplay()
    }
    func perform(_ action: DiagramZoomRequest.Action, animated: Bool) {
        let target: CGFloat
        switch action {
        case .fit: target = minimumZoomScale
        case .increase: target = min(maximumZoomScale, zoomScale * 2)
        case .decrease: target = max(minimumZoomScale, zoomScale / 2)
        }
        setZoomScale(target, animated: animated)
        if !animated { renderAtCurrentScale() }
    }
    @objc private func doubleTapped(_ gesture: UITapGestureRecognizer) {
        guard zoomScale <= minimumZoomScale * 1.01 else {
            perform(.fit, animated: !UIAccessibility.isReduceMotionEnabled)
            return
        }
        let scale = min(maximumZoomScale, minimumZoomScale * 2)
        let size = CGSize(width: bounds.width / scale, height: bounds.height / scale)
        var point = gesture.location(in: figure)
        if !figure.bounds.contains(point) { point = CGPoint(x: figure.bounds.midX, y: figure.bounds.midY) }
        zoom(
            to: CGRect(
                x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width,
                height: size.height),
            animated: !UIAccessibility.isReduceMotionEnabled)
        if UIAccessibility.isReduceMotionEnabled { renderAtCurrentScale() }
    }
}
