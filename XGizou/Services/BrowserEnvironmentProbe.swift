import Foundation
import WebKit

struct BrowserEnvironmentSnapshot: Decodable, Equatable {
    let userAgent: String
    let platform: String
    let vendor: String
    let language: String
    let languages: String
    let hardwareConcurrency: String
    let maxTouchPoints: String
    let screen: String
    let pixelRatio: String
    let timezone: String
    let webdriver: String
}

enum BrowserEnvironmentProbeError: LocalizedError {
    case invalidResult

    var errorDescription: String? {
        switch self {
        case .invalidResult:
            return "ブラウザ環境の計測結果を読み取れませんでした。"
        }
    }
}

@MainActor
enum BrowserEnvironmentProbe {
    static func measure(profile: BrowserProfile) async throws -> BrowserEnvironmentSnapshot {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore(forIdentifier: profile.id)
        configuration.processPool = WKProcessPool()

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        preferences.preferredContentMode = RiskReductionPolicy.preferredContentMode(for: profile)
        configuration.defaultWebpagePreferences = preferences

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = RiskReductionPolicy.effectiveUserAgent(for: profile)

        let script = """
        JSON.stringify({
          userAgent: String(navigator.userAgent || ""),
          platform: String(navigator.platform || ""),
          vendor: String(navigator.vendor || ""),
          language: String(navigator.language || ""),
          languages: Array.isArray(navigator.languages) ? navigator.languages.join(", ") : "",
          hardwareConcurrency: String(navigator.hardwareConcurrency ?? "unknown"),
          maxTouchPoints: String(navigator.maxTouchPoints ?? "unknown"),
          screen: String(screen.width) + " × " + String(screen.height),
          pixelRatio: String(window.devicePixelRatio ?? "unknown"),
          timezone: String(Intl.DateTimeFormat().resolvedOptions().timeZone || "unknown"),
          webdriver: String(Boolean(navigator.webdriver))
        })
        """

        let result = try await webView.evaluateJavaScript(script)
        guard let json = result as? String,
              let data = json.data(using: .utf8)
        else {
            throw BrowserEnvironmentProbeError.invalidResult
        }

        do {
            return try JSONDecoder().decode(BrowserEnvironmentSnapshot.self, from: data)
        } catch {
            throw BrowserEnvironmentProbeError.invalidResult
        }
    }
}
