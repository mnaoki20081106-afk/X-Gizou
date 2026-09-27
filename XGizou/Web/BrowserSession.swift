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
    @Published private(set) var estimatedProgress = 0.0
    @Published private(set) var title: String = ""
    @Published private(set) var currentURL: URL?
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasRenderedContent = false

    private var currentProfile: BrowserProfile
    private var policyObserver: NSObjectProtocol?
    private var observations: [NSKeyValueObservation] = []

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
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        // Keep the profile-specific browser presentation layer intact, but install
        // it before the first navigation so WebKit does not need a mid-load reset.
        if let script = FingerprintSpoofer.userScript(for: profile) {
            configuration.userContentController.addUserScript(script)
        }

        webView = WKWebView(frame: .zero, configuration: configuration)

        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.accessibilityIdentifier = "x-browser-webview"
        webView.isOpaque = true
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        webView.underPageBackgroundColor = .systemBackground

        applyRuntimeProfile(profile)
        observeWebView()

        policyObserver = NotificationCenter.default.addObserver(
            forName: .riskReductionPolicyChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.applyRuntimeProfile(self.currentProfile)
                if self.webView.url != nil {
                    self.webView.reload()
                }
            }
        }
    }

    deinit {
        observations.forEach { $0.invalidate() }
        if let policyObserver {
            NotificationCenter.default.removeObserver(policyObserver)
        }
    }

    func apply(profile: BrowserProfile) {
        let changed = currentProfile != profile
        currentProfile = profile
        applyRuntimeProfile(profile)

        let controller = webView.configuration.userContentController
        controller.removeAllUserScripts()
        if let script = FingerprintSpoofer.userScript(for: profile) {
            controller.addUserScript(script)
        }

        // User scripts are captured when a document starts. Reload only when the
        // active profile settings actually changed, never as blank-page recovery.
        if changed && webView.url != nil {
            hasRenderedContent = false
            errorMessage = nil
            webView.reload()
        }
    }

    func startIfNeeded() {
        guard webView.url == nil else { return }
        loadHome()
    }

    func loadHome() {
        load(BrowserRuntimeConfiguration.homeURL)
    }

    func load(_ url: URL) {
        errorMessage = nil
        hasRenderedContent = false

        if RiskReductionPolicy.shouldOpenTopLevelExternally(url) {
            UIApplication.shared.open(url)
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .useProtocolCachePolicy
        request.timeoutInterval = 30
        webView.load(request)
    }

    func goBack() {
        guard webView.canGoBack else { return }
        errorMessage = nil
        hasRenderedContent = false
        webView.goBack()
    }

    func goForward() {
        guard webView.canGoForward else { return }
        errorMessage = nil
        hasRenderedContent = false
        webView.goForward()
    }

    func reload() {
        errorMessage = nil

        if webView.isLoading {
            webView.stopLoading()
            return
        }

        hasRenderedContent = false
        if webView.url == nil {
            loadHome()
        } else {
            webView.reload()
        }
    }

    private func applyRuntimeProfile(_ profile: BrowserProfile) {
        webView.customUserAgent = RiskReductionPolicy.effectiveUserAgent(for: profile)
        webView.configuration.defaultWebpagePreferences.preferredContentMode =
            RiskReductionPolicy.preferredContentMode(for: profile)
        webView.isInspectable = !RiskReductionPolicy.isEnabled
    }

    private func observeWebView() {
        observations = [
            webView.observe(\.title, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.title = webView.title ?? ""
                }
            },
            webView.observe(\.url, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.currentURL = webView.url
                }
            },
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.canGoBack = webView.canGoBack
                }
            },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.canGoForward = webView.canGoForward
                }
            },
            webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.estimatedProgress = webView.estimatedProgress
                }
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.isLoading = webView.isLoading
                }
            }
        ]
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        errorMessage = nil
        hasRenderedContent = false
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        // Once WebKit commits bytes to the main frame, remove our loading cover.
        // X can continue hydrating normally without DOM polling or forced reloads.
        hasRenderedContent = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        errorMessage = nil
        hasRenderedContent = true

        #if DEBUG
        if ProcessInfo.processInfo.environment["XGIZOU_REAL_X_SMOKE"] == "1" {
            webView.accessibilityIdentifier = "x-browser-real-x-loaded"
        } else if ProcessInfo.processInfo.environment["XGIZOU_TEST_HOME_URL"] != nil {
            webView.accessibilityIdentifier = "x-browser-webview-loaded"
        }
        #endif
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleNavigationError(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleNavigationError(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        errorMessage = nil
        hasRenderedContent = false

        if webView.url == nil {
            loadHome()
        } else {
            webView.reload()
        }
    }

    private func handleNavigationError(_ error: Error) {
        if BrowserNavigationErrorClassifier.shouldIgnore(error) {
            errorMessage = nil
            return
        }

        hasRenderedContent = false
        errorMessage = "Xを読み込めませんでした。通信状態を確認して再試行してください。\n" + error.localizedDescription
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
        guard let url = navigationAction.request.url,
              let scheme = url.scheme?.lowercased() else {
            decisionHandler(.cancel)
            return
        }

        #if DEBUG
        if BrowserRuntimeConfiguration.isUITestHomeURL(url) {
            decisionHandler(.allow)
            return
        }
        #endif

        if ["http", "https", "about", "data", "blob"].contains(scheme) {
            let isTopLevel = navigationAction.targetFrame == nil || navigationAction.targetFrame?.isMainFrame == true
            if ["http", "https"].contains(scheme),
               isTopLevel,
               RiskReductionPolicy.shouldOpenTopLevelExternally(url) {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
            return
        }

        if RiskReductionPolicy.shouldBlockExternalScheme(scheme) {
            decisionHandler(.cancel)
            return
        }

        if RiskReductionPolicy.isEnabled {
            if RiskReductionPolicy.isAllowedExternalScheme(scheme),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
            decisionHandler(.cancel)
            return
        }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        decisionHandler(.cancel)
    }
}
