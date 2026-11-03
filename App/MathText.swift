import SwiftUI
import WebKit

/// Text is passed as JSON and assigned with textContent, never interpreted as HTML.
struct MathText: UIViewRepresentable {
    let text: String
    let pointSize: CGFloat
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1
    @State private var measuredHeight: CGFloat = 60
    init(_ text: String, pointSize: CGFloat = 18) {
        self.text = text
        self.pointSize = pointSize
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(context.coordinator, name: "height")
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.navigationDelegate = context.coordinator
        context.coordinator.height = { value in
            guard value.isFinite, value > 0 else { return }
            let next = min(100000, max(30, value))
            if abs(measuredHeight - next) > 1 { measuredHeight = next }
        }
        context.coordinator.update(text: text, size: min(pointSize * scale, 50))
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Math") {
            view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.update(text: text, size: min(pointSize * scale, 50))
        context.coordinator.render(in: view)
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: WKWebView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 300, height: measuredHeight)
    }
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.configuration.userContentController.removeScriptMessageHandler(forName: "height")
        view.navigationDelegate = nil
    }
    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var height: ((CGFloat) -> Void)?
        var text = ""
        var size: CGFloat = 18
        var ready = false
        var lastPayload = ""
        func update(text: String, size: CGFloat) {
            self.text = text
            self.size = size
        }
        func render(in view: WKWebView) {
            guard ready,
                let data = try? JSONEncoder().encode(MathPayload(text: text, size: size)),
                let payload = String(data: data, encoding: .utf8), payload != lastPayload
            else { return }
            lastPayload = payload
            view.evaluateJavaScript("window.showMath(\(payload))", completionHandler: nil)
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
            ready = true
            lastPayload = ""
            render(in: webView)
        }
        func userContentController(
            _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
        ) {
            if let number = message.body as? NSNumber { height?(CGFloat(number.doubleValue)) }
        }
        func webView(
            _ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            navigationAction.request.url?.isFileURL == true ? .allow : .cancel
        }
    }
}

private struct MathPayload: Encodable {
    let text: String
    let size: CGFloat
}
