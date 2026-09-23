import Combine
import Foundation
import UIKit
import WebKit

@MainActor
final class BrowserSession: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let profileID: UUID
    let webView: WKWebView

    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var isLoading = false
    @Published private(set) var title: String = ""
    @Published private(set) var currentURL: URL?

    private var currentProfile: BrowserProfile
    private var policyObserver: NSObjectProtocol?

    init(profile: BrowserProfile) {
        profileID = profile.id
        currentProfile = profile

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore(forIdentifier: profile.id)
        configuration.processPool = WKProcessPool()

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        preferences.preferredContentMode = RiskReductionPolicy.preferredContentMode(for: profile)
        configuration.defaultWebpagePreferences = preferences

        webView = WKWebView(frame: .zero, configuration: configuration)

        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true

        apply(profile: profile)
        refreshState()

        policyObserver = NotificationCenter.default.addObserver(
            forName: .riskReductionPolicyChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.apply(profile: self.currentProfile)
                if self.webView.url != nil {
                    self.webView.reload()
                }
            }
        }
    }

    deinit {
        if let policyObserver {
            NotificationCenter.default.removeObserver(policyObserver)
        }
    }

    func apply(profile: BrowserProfile) {
        currentProfile = profile
        webView.customUserAgent = RiskReductionPolicy.effectiveUserAgent(for: profile)
        webView.configuration.defaultWebpagePreferences.preferredContentMode =
            RiskReductionPolicy.preferredContentMode(for: profile)
        webView.isInspectable = !RiskReductionPolicy.isEnabled
    }

    func startIfNeeded() {
        guard webView.url == nil else { return }
        loadHome()
    }

    func loadHome() {
        load(URL(string: "https://x.com/home")!)
    }

    func load(_ url: URL) {
        if RiskReductionPolicy.shouldOpenTopLevelExternally(url) {
            UIApplication.shared.open(url)
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .useProtocolCachePolicy
        webView.load(request)
    }

    func goBack() {
        if webView.canGoBack {
            webView.goBack()
            refreshState()
        }
    }

    func goForward() {
        if webView.canGoForward {
            webView.goForward()
            refreshState()
        }
    }

    func reload() {
        if webView.url == nil {
            loadHome()
        } else {
            webView.reload()
        }
        refreshState()
    }

    private func refreshState() {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
        title = webView.title ?? ""
        currentURL = webView.url
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        refreshState()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        refreshState()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refreshState()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        refreshState()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        refreshState()
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil, let requestURL = navigationAction.request.url {
            if RiskReductionPolicy.shouldOpenTopLevelExternally(requestURL) {
                UIApplication.shared.open(requestURL)
            } else {
                load(requestURL)
            }
        }
        return nil
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

        guard let scheme = url.scheme?.lowercased() else {
            decisionHandler(.cancel)
            return
        }

        if ["http", "https"].contains(scheme) {
            let isTopLevel = navigationAction.targetFrame == nil || navigationAction.targetFrame?.isMainFrame == true
            if isTopLevel && RiskReductionPolicy.shouldOpenTopLevelExternally(url) {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
            return
        }

        if scheme == "about" {
            decisionHandler(.allow)
            return
        }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        decisionHandler(.cancel)
    }
}
