import Foundation
import WebKit

enum RiskReductionPolicy {
    static let enabledKey = "xgizou.riskReductionMode.enabled"

    static var isEnabled: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: enabledKey) == nil {
            return true
        }
        return defaults.bool(forKey: enabledKey)
    }

    static func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        NotificationCenter.default.post(name: .riskReductionPolicyChanged, object: nil)
    }

    static func effectiveUserAgent(for profile: BrowserProfile) -> String? {
        if isEnabled {
            return nil
        }

        let ua = profile.effectiveUserAgent.trimmingCharacters(in: .whitespacesAndNewlines)
        return ua.isEmpty ? nil : ua
    }

    static func preferredContentMode(for profile: BrowserProfile) -> WKContentMode {
        if isEnabled {
            return .mobile
        }
        return profile.devicePreset.prefersDesktopContent ? .desktop : .mobile
    }

    static func shouldOpenTopLevelExternally(_ url: URL) -> Bool {
        guard isEnabled else { return false }
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return false
        }
        guard let host = url.host?.lowercased() else {
            return false
        }

        return !isXHost(host)
    }

    static func isXHost(_ host: String) -> Bool {
        host == "x.com" ||
        host.hasSuffix(".x.com") ||
        host == "twitter.com" ||
        host.hasSuffix(".twitter.com")
    }
}

extension Notification.Name {
    static let riskReductionPolicyChanged = Notification.Name("xgizou.riskReductionPolicyChanged")
}
