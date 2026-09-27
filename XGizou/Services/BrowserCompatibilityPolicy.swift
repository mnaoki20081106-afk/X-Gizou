import Foundation

enum BrowserCompatibilityPolicy {
    /// Returning nil preserves WKWebView's native User-Agent. This is the
    /// safest default because WebKit and its UA stay version-aligned.
    static func effectiveUserAgent(configuredUserAgent: String) -> String? {
        let configured = configuredUserAgent.trimmingCharacters(in: .whitespacesAndNewlines)
        return configured.isEmpty ? nil : configured
    }
}
