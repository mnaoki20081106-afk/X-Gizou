import Foundation

@main
struct BrowserHostPolicyTest {
    static func main() {
        let internalHosts = [
            "x.com",
            "www.x.com",
            "mobile.x.com",
            "twitter.com",
            "mobile.twitter.com"
        ]

        for host in internalHosts {
            precondition(BrowserHostPolicy.isXHost(host), "\(host) must stay inside the X browser")
        }

        precondition(!BrowserHostPolicy.isXHost("example.com"))
        precondition(!BrowserHostPolicy.isXHost("x.com.example.com"))
        precondition(!BrowserHostPolicy.isXHost("twitter.com.evil.example"))

        precondition(
            BrowserHostPolicy.shouldOpenTopLevelExternally(
                URL(string: "https://example.com/")!,
                protectionEnabled: true
            )
        )

        precondition(
            !BrowserHostPolicy.shouldOpenTopLevelExternally(
                URL(string: "https://x.com/home")!,
                protectionEnabled: true
            )
        )

        precondition(
            !BrowserHostPolicy.shouldOpenTopLevelExternally(
                URL(string: "https://mobile.twitter.com/login")!,
                protectionEnabled: true
            )
        )

        precondition(
            !BrowserHostPolicy.shouldOpenTopLevelExternally(
                URL(string: "https://example.com/")!,
                protectionEnabled: false
            )
        )

        print("browser-host-policy: ok")
    }
}
