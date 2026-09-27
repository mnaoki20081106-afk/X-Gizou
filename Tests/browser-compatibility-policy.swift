import Foundation

@main
struct BrowserCompatibilityPolicyTest {
    static func main() {
        precondition(
            BrowserCompatibilityPolicy.effectiveUserAgent(
                configuredUserAgent: ""
            ) == nil
        )

        precondition(
            BrowserCompatibilityPolicy.effectiveUserAgent(
                configuredUserAgent: "   "
            ) == nil
        )

        precondition(
            BrowserCompatibilityPolicy.effectiveUserAgent(
                configuredUserAgent: "Custom/1.0"
            ) == "Custom/1.0"
        )

        precondition(
            BrowserCompatibilityPolicy.effectiveUserAgent(
                configuredUserAgent: "  Custom/2.0  "
            ) == "Custom/2.0"
        )

        print("browser-compatibility-policy: ok")
    }
}
