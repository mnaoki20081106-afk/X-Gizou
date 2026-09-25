import SwiftUI
import WebKit

struct RemoteBrowserScreen: View {
    @EnvironmentObject private var store: ProfileStore
    let profile: BrowserProfile
    @State private var reloadID = UUID()
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text(profile.name).font(.headline)
                    Text(profile.remoteBrowserURL?.host ?? "接続先未設定")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    errorMessage = nil
                    reloadID = UUID()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("リモートブラウザへ再接続")
            }
            .padding()
            if let errorMessage {
                Text(errorMessage)
                    .font(.callout).foregroundStyle(.orange).padding()
            }
            if let host = profile.remoteEnvironmentHost,
               store.profiles.contains(where: { $0.id != profile.id && $0.remoteEnvironmentHost == host }) {
                ContentUnavailableView("独立環境になっていません", systemImage: "person.2.slash",
                    description: Text("同じホストを複数プロフィールで使っています。別プロフィールには別VM・別ホストの専用ブラウザを設定してください。"))
            } else if let url = profile.remoteBrowserURL {
                RemoteBrowserCanvas(profileID: profile.id, endpoint: url, errorMessage: $errorMessage)
                    .id(reloadID.uuidString + url.absoluteString)
            } else {
                ContentUnavailableView("接続先が必要です", systemImage: "network",
                    description: Text("プロフィール編集で別VM・別ホストの専用ブラウザHTTPS URLを設定してください。"))
            }
        }
    }
}

// This WebView displays only the remote-control client. X itself is rendered by
// the server browser; no local UA or fingerprint script is injected into it.
private struct RemoteBrowserCanvas: UIViewRepresentable {
    let profileID: UUID
    let endpoint: URL
    @Binding var errorMessage: String?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore(forIdentifier: profileID)
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.load(URLRequest(url: endpoint))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading()
        view.navigationDelegate = nil
        view.uiDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: RemoteBrowserCanvas
        init(parent: RemoteBrowserCanvas) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.errorMessage = nil
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            show(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            show(error)
        }

        private func show(_ error: Error) {
            guard (error as NSError).code != NSURLErrorCancelled else { return }
            parent.errorMessage = "接続できませんでした。サーバーの起動とTailscale接続を確認してください。\n" + error.localizedDescription
        }

        private func sameOrigin(_ url: URL) -> Bool {
            url.scheme?.lowercased() == "https" &&
            url.host?.lowercased() == parent.endpoint.host?.lowercased() &&
            (url.port ?? 443) == (parent.endpoint.port ?? 443)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            if navigationAction.targetFrame?.isMainFrame == false {
                decisionHandler(url.scheme == "https" || url.scheme == "about" || url.scheme == "blob" ? .allow : .cancel)
                return
            }
            guard sameOrigin(url) else {
                parent.errorMessage = "接続先以外への画面遷移を止めました。Xの操作はリモート画面内で行ってください。"
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url, sameOrigin(url) {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
