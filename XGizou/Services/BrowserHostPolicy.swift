import Foundation

enum BrowserHostPolicy {
    static func isXHost(_ host: String) -> Bool {
        let normalized = host.lowercased()
        return normalized == "x.com" ||
            normalized.hasSuffix(".x.com") ||
            normalized == "twitter.com" ||
            normalized.hasSuffix(".twitter.com")
    }

    static func shouldOpenTopLevelExternally(_ url: URL, protectionEnabled: Bool) -> Bool {
        guard protectionEnabled else { return false }
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host?.lowercased() else {
            return false
        }
        return !isXHost(host)
    }
}
