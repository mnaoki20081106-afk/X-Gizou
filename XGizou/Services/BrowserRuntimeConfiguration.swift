import Foundation

enum BrowserRuntimeConfiguration {
    static var homeURL: URL {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["XGIZOU_TEST_HOME_URL"],
           let url = URL(string: raw) {
            return url
        }
        #endif

        return URL(string: "https://x.com/home")!
    }

    static func isUITestHomeURL(_ url: URL) -> Bool {
        #if DEBUG
        guard let raw = ProcessInfo.processInfo.environment["XGIZOU_TEST_HOME_URL"],
              let testURL = URL(string: raw) else {
            return false
        }
        return testURL == url
        #else
        return false
        #endif
    }
}
