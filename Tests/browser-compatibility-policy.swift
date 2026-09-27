import Foundation

@main
struct BrowserCompatibilityPolicyTest {
    static func main() {
        let safari = "Mozilla/5.0 Safari/604.1"

        precondition(
            BrowserCompatibilityPolicy.effectiveUserAgent(
                manualEnabled: false,
                configuredUserAgent: "",
                safariFallbackUserAgent: safari
            ) == safari
        )

        precondition(
            BrowserCompatibilityPolicy.effectiveUserAgent(
                manualEnabled: false,
                configuredUserAgent: "Custom/1.0",
                safariFallbackUserAgent: safari
            ) == safari
        )

        precondition(
            BrowserCompatibilityPolicy.effectiveUserAgent(
                manualEnabled: true,
                configuredUserAgent: "Custom/1.0",
                safariFallbackUserAgent: safari
            ) == "Custom/1.0"
        )

        precondition(
            BrowserCompatibilityPolicy.effectiveUserAgent(
                manualEnabled: true,
                configuredUserAgent: "   ",
                safariFallbackUserAgent: safari
            ) == safari
        )

        print("browser-compatibility-policy: ok")
    }
}
