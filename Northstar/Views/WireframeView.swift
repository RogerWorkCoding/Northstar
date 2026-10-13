import SwiftUI
import WebKit

// "Show, don't tell": a simple wireframe Northstar draws for visual requests
// (a web page, an app screen, a flyer). It is drawing only. It is shown in a
// locked viewer with JavaScript off and no internet access.

/// Card in the chat: the wireframe with its title. Tap to see it large.
struct WireframeCard: View {
    let visual: NorthstarInsight.Visual
    @State private var isEnlarged = false

    var body: some View {
        Button {
            isEnlarged = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.3.group")
                        .font(.system(size: 12, weight: .semibold))
                    Text("WIREFRAME · \(visual.title.uppercased())")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.5)
                        .lineLimit(1)
                }
                .foregroundStyle(NorthstarChatStyle.label)

                SVGView(svg: visual.svg)
                    .aspectRatio(360.0 / 640.0, contentMode: .fit)
                    .frame(maxWidth: 240)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .allowsHitTesting(false)

                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                    Text("Tap to see it large")
                }
                .font(.system(size: 14))
                .foregroundStyle(NorthstarChatStyle.soft)
                .frame(maxWidth: .infinity)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Wireframe: \(visual.title). Tap to see it large.")
        .fullScreenCover(isPresented: $isEnlarged) {
            WireframeFullScreen(visual: visual)
        }
    }
}

/// Full-screen view of a wireframe.
struct WireframeFullScreen: View {
    let visual: NorthstarInsight.Visual
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color(red: 0.04, green: 0.07, blue: 0.16).ignoresSafeArea()

            VStack(spacing: 16) {
                Text(visual.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 8)

                SVGView(svg: visual.svg)
                    .aspectRatio(360.0 / 640.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 20)

                Spacer(minLength: 0)
            }
            .padding(.top, 48)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.16)))
            }
            .accessibilityLabel("Close")
            .padding(.trailing, 16)
            .padding(.top, 8)
        }
    }
}

/// Shows an SVG drawing in a locked web view: JavaScript off, no links,
/// no network, no scrolling.
struct SVGView: UIViewRepresentable {
    let svg: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        config.websiteDataStore = .nonPersistent()

        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.scrollView.bounces = false
        view.navigationDelegate = context.coordinator
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        guard context.coordinator.loadedSVG != svg else { return }
        context.coordinator.loadedSVG = svg
        let html = """
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'">
        <style>html,body{margin:0;height:100%;background:transparent}svg{display:block;width:100%;height:100%}</style>
        </head><body>\(svg)</body></html>
        """
        view.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedSVG: String?

        // Only the drawing itself may load; every other navigation is blocked.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            let scheme = navigationAction.request.url?.scheme ?? "about"
            return scheme == "about" ? .allow : .cancel
        }
    }
}
