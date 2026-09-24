import Foundation
import WebKit

enum RiskReductionPolicy {
    static let enabledKey = "xgizou.riskReductionMode.enabled"

    static var isEnabled: Bool {
        #if DEBUG
        let defaults = UserDefaults.standard
        if defaults.object(forKey: enabledKey) == nil {
            return true
        }
        return defaults.bool(forKey: enabledKey)
        #else
        return true
        #endif
    }

    static var isReleaseLocked: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }

    static func setEnabled(_ enabled: Bool) {
        #if DEBUG
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        #else
        UserDefaults.standard.set(true, forKey: enabledKey)
        #endif
        NotificationCenter.default.post(name: .riskReductionPolicyChanged, object: nil)
    }

    static func bootstrap() {
        if isReleaseLocked {
            UserDefaults.standard.set(true, forKey: enabledKey)
        } else if UserDefaults.standard.object(forKey: enabledKey) == nil {
            UserDefaults.standard.set(true, forKey: enabledKey)
        }
    }

    static func effectiveUserAgent(for profile: BrowserProfile) -> String? {
        let ua = profile.effectiveUserAgent.trimmingCharacters(in: .whitespacesAndNewlines)
        return ua.isEmpty ? nil : ua
    }

    static func preferredContentMode(for profile: BrowserProfile) -> WKWebpagePreferences.ContentMode {
        profile.devicePreset.prefersDesktopContent ? .desktop : .mobile
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

    static func shouldBlockExternalScheme(_ scheme: String) -> Bool {
        guard isEnabled else { return false }
        let normalized = scheme.lowercased()
        return normalized == "x" || normalized == "twitter"
    }

    static func isAllowedExternalScheme(_ scheme: String) -> Bool {
        ["mailto", "tel", "sms", "itms-apps"].contains(scheme.lowercased())
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
