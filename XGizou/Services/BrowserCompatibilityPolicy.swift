import Foundation

enum BrowserCompatibilityPolicy {
    static func effectiveUserAgent(
        manualEnabled: Bool,
        configuredUserAgent: String,
        safariFallbackUserAgent: String
    ) -> String {
        let configured = configuredUserAgent.trimmingCharacters(in: .whitespacesAndNewlines)
        if manualEnabled && !configured.isEmpty {
            return configured
        }
        return safariFallbackUserAgent
    }
}
