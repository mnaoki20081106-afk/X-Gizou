import SwiftUI
import WebKit

struct RemoteBrowserScreen: View {
    @EnvironmentObject private var store: ProfileStore

    let profile: BrowserProfile

    @State private var reloadID = UUID()
    @State private var errorMessage: String?
    @State private var environmentVerified = false
    @State private var isVerifyingEnvironment = false
    @State private var verificationMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            XBrowserHeader(
                title: profile.name,
                canGoBack: false,
                canGoForward: false,
                isLoading: isVerifyingEnvironment,
                goBack: {},
                goForward: {},
                reload: reconnect
            )

            ZStack {
                Color(uiColor: .systemBackground)

                remoteContent

                if let errorMessage, environmentVerified {
                    connectionErrorCard(errorMessage)
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
        .task(id: reloadID) {
            await verifyEnvironment()
        }
    }

    @ViewBuilder
    private var remoteContent: some View {
        if let host = profile.remoteEnvironmentHost,
           store.profiles.contains(where: { $0.id != profile.id && $0.remoteEnvironmentHost == host }) {
            unavailableView(
                title: "独立環境になっていません",
                symbol: "person.2.slash",
                message: "同じホストを複数プロフィールで使っています。別プロフィールには別VM・別ホストの専用ブラウザを設定してください。"
            )
        } else if let url = profile.remoteBrowserURL {
            if environmentVerified {
                RemoteBrowserCanvas(
                    profileID: profile.id,
                    endpoint: url,
                    errorMessage: $errorMessage
                )
                .id(reloadID.uuidString + url.absoluteString)
            } else if isVerifyingEnvironment {
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Xを起動しています")
                        .font(.headline)
                    Text("独立ブラウザ環境を確認中")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let verificationMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.orange)
                    Text("独立環境を確認できません")
                        .font(.title3.bold())
                    Text(verificationMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                    Button("再接続") {
                        reconnect()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            unavailableView(
                title: "接続先が必要です",
                symbol: "network",
                message: "プロフィール編集で別VM・別ホストの専用ブラウザHTTPS URLを設定してください。"
            )
        }
    }

    private func connectionErrorCard(_ message: String) -> some View {
        VStack(spacing: 10) {
            Text("接続が途切れました")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
            Button("再接続") {
                reconnect()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .frame(maxWidth: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(radius: 12)
    }

    private func unavailableView(title: String, symbol: String, message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.bold())
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func reconnect() {
        errorMessage = nil
        verificationMessage = nil
        environmentVerified = false
        reloadID = UUID()
    }

    @MainActor
    private func verifyEnvironment() async {
        guard let endpoint = profile.remoteBrowserURL else { return }

        if let host = profile.remoteEnvironmentHost,
           store.profiles.contains(where: { $0.id != profile.id && $0.remoteEnvironmentHost == host }) {
            return
        }

        isVerifyingEnvironment = true
        environmentVerified = false
        verificationMessage = nil
        defer { isVerifyingEnvironment = false }

        do {
            let actualIdentity = try await RemoteEnvironmentVerifier.fetchIdentity(from: endpoint)

            if let expectedIdentity = profile.normalizedRemoteEnvironmentID,
               expectedIdentity != actualIdentity {
                verificationMessage = "保存時と異なる環境IDが返されました。接続先またはブラウザ保存領域が入れ替わっています。プロフィール編集で確認してください。"
                return
            }

            if store.profiles.contains(where: {
                $0.id != profile.id && $0.normalizedRemoteEnvironmentID == actualIdentity
            }) {
                verificationMessage = "別プロフィールと同じブラウザ実体が返されました。独立環境として起動を停止しました。"
                return
            }

            if profile.normalizedRemoteEnvironmentID == nil {
                var repaired = profile
                repaired.remoteEnvironmentID = actualIdentity
                store.save(repaired)
            }

            environmentVerified = true
        } catch {
            verificationMessage = "環境IDを取得できませんでした。サーバー側のX-GizouゲートウェイとTailscale接続を確認してください。\n\(error.localizedDescription)"
        }
    }
}

// The local WKWebView renders only the remote-control client. X itself runs in
// the dedicated Chromium application window on the remote environment.
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
        view.isOpaque = false
        view.backgroundColor = .systemBackground
        view.scrollView.backgroundColor = .systemBackground
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.scrollView.bounces = false
        view.scrollView.showsHorizontalScrollIndicator = false
        view.scrollView.showsVerticalScrollIndicator = false
        view.scrollView.keyboardDismissMode = .interactive
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

        init(parent: RemoteBrowserCanvas) {
            self.parent = parent
        }

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
            parent.errorMessage = "サーバーの起動とTailscale接続を確認してください。\n" + error.localizedDescription
        }

        private func sameOrigin(_ url: URL) -> Bool {
            url.scheme?.lowercased() == "https" &&
            url.host?.lowercased() == parent.endpoint.host?.lowercased() &&
            (url.port ?? 443) == (parent.endpoint.port ?? 443)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
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

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url, sameOrigin(url) {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
