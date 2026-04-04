import SwiftUI
import WebKit

struct PreviewView: NSViewRepresentable {
    var html: String
    var scrollToLine: Int?
    var onFirstVisibleLine: ((Int) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "scrollSync")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        // Load the HTML template
        webView.loadHTMLString(PreviewCSS.html, baseURL: nil)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.pendingHTML = html
        context.coordinator.pendingScrollLine = scrollToLine
        context.coordinator.onFirstVisibleLine = onFirstVisibleLine

        // If page is loaded, update immediately
        if context.coordinator.isPageLoaded {
            context.coordinator.updateContent()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var webView: WKWebView?
        var isPageLoaded = false
        var pendingHTML: String = ""
        var pendingScrollLine: Int?
        var onFirstVisibleLine: ((Int) -> Void)?
        private var isScrollingFromEditor = false

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isPageLoaded = true
            updateContent()
        }

        func updateContent() {
            guard let webView = webView, isPageLoaded else { return }

            let escaped = pendingHTML
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "")

            webView.evaluateJavaScript("updateContent(`\(escaped)`)")

            if let line = pendingScrollLine {
                isScrollingFromEditor = true
                webView.evaluateJavaScript("scrollToLine(\(line))") { [weak self] _, _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        self?.isScrollingFromEditor = false
                    }
                }
            }
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard !isScrollingFromEditor,
                  let body = message.body as? [String: Any],
                  let line = body["line"] as? Int else { return }
            onFirstVisibleLine?(line)
        }
    }
}
