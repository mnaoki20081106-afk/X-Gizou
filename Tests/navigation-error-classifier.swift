import Foundation

@main
struct NavigationErrorClassifierTest {
    static func main() {
        precondition(
            BrowserNavigationErrorClassifier.shouldIgnore(
                domain: "WebKitErrorDomain",
                code: 102
            ),
            "WebKit policy-change interruption must not be shown as an X load failure"
        )

        precondition(
            BrowserNavigationErrorClassifier.shouldIgnore(
                domain: NSURLErrorDomain,
                code: NSURLErrorCancelled
            ),
            "Cancelled navigation must not be shown as an X load failure"
        )

        precondition(
            !BrowserNavigationErrorClassifier.shouldIgnore(
                domain: NSURLErrorDomain,
                code: NSURLErrorNotConnectedToInternet
            ),
            "Offline errors must remain visible"
        )

        precondition(
            !BrowserNavigationErrorClassifier.shouldIgnore(
                domain: NSURLErrorDomain,
                code: NSURLErrorCannotFindHost
            ),
            "DNS errors must remain visible"
        )

        precondition(
            !BrowserNavigationErrorClassifier.shouldIgnore(
                domain: "WebKitErrorDomain",
                code: 1
            ),
            "Unknown WebKit failures must remain visible"
        )

        print("navigation-error-classifier: ok")
    }
}
