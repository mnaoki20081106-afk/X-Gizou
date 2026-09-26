import Foundation

enum BrowserNavigationErrorClassifier {
    static let webKitErrorDomain = "WebKitErrorDomain"
    static let frameLoadInterruptedByPolicyChangeCode = 102

    static func shouldIgnore(_ error: Error) -> Bool {
        let nsError = error as NSError
        return shouldIgnore(domain: nsError.domain, code: nsError.code)
    }

    static func shouldIgnore(domain: String, code: Int) -> Bool {
        if domain == NSURLErrorDomain && code == NSURLErrorCancelled {
            return true
        }

        if domain == webKitErrorDomain && code == frameLoadInterruptedByPolicyChangeCode {
            return true
        }

        return false
    }
}
