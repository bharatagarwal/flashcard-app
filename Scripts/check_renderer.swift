// Run from the repo root: swift Scripts/check_renderer.swift
// Uses macOS WebKit to check the same bundled page used by the iPhone app.
import AppKit
import WebKit

final class RendererCheck: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    var window: NSWindow!
    var web: WKWebView!
    var texts: [String] = []
    var index = 0
    var cases = 0
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let data = try Data(contentsOf: root.appendingPathComponent("App/Resources/starter.json"))
            let deck = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            func collect(_ value: Any) {
                if let array = value as? [Any] {
                    array.forEach(collect)
                } else if let object = value as? [String: Any] {
                    if object["kind"] as? String == "equation", let text = object["text"] as? String {
                        texts.append("\\[" + text + "\\]")
                    } else if object["kind"] as? String == "text", let text = object["text"] as? String {
                        texts.append(text)
                    }
                    for key in ["prompt", "answer", "hint", "explanation", "pitfall"] {
                        if let text = object[key] as? String { texts.append(text) }
                    }
                    for (key, child) in object
                    where !["text", "data", "darkData", "latexSource"].contains(key) {
                        if child is [Any] || child is [String: Any] { collect(child) }
                    }
                }
            }
            collect(deck)
            texts.append(
                "<img src=x onerror='window.injected=true'><script>window.injected=true</script>\\[3\\mid18\\]"
            )
        } catch { fail(error.localizedDescription) }
        window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 291, height: 650), styleMask: [.titled],
            backing: .buffered, defer: false)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        web = WKWebView(frame: window.contentView!.bounds, configuration: configuration)
        web.navigationDelegate = self
        window.contentView = web
        let page = root.appendingPathComponent("App/Resources/Math/index.html")
        web.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        DispatchQueue.main.asyncAfter(deadline: .now() + 120) { self.fail("Renderer check timed out") }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { renderNext() }
    func renderNext() {
        if index == texts.count {
            print(
                "Passed \(cases) native WebKit cases at 291 pt width. No maths errors, page overflow, or HTML execution."
            )
            NSApp.terminate(nil)
            return
        }
        let large = cases % 2 == 1
        window.appearance = NSAppearance(named: large ? .darkAqua : .aqua)
        let payload: [String: Any] = ["text": texts[index], "size": large ? 28 : 18]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        let script = "window.showMath(\(String(data: data, encoding: .utf8)!))"
        web.evaluateJavaScript(script) { _, error in
            if let error { self.fail(error.localizedDescription) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.inspect() }
        }
    }
    func inspect() {
        web.evaluateJavaScript(
            "({errors:document.querySelectorAll('.katex-error').length,overflow:document.documentElement.scrollWidth>innerWidth+1,injected:!!window.injected,height:document.getElementById('content').getBoundingClientRect().height})"
        ) { result, error in
            guard error == nil, let result = result as? [String: Any] else {
                self.fail("Could not read renderer result: \(String(describing: error))")
                return
            }
            if result["errors"] as? Int != 0 || result["overflow"] as? Bool != false
                || result["injected"] as? Bool != false
            {
                self.fail("Case \(self.index), large=\(self.cases % 2 == 1): \(result)")
            }
            self.cases += 1
            if self.cases % 2 == 0 { self.index += 1 }
            self.renderNext()
        }
    }
    func fail(_ message: String) -> Never {
        fputs(message + "\n", stderr)
        exit(1)
    }
}
let application = NSApplication.shared
let checker = RendererCheck()
application.delegate = checker
application.run()
