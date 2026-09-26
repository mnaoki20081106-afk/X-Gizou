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
}
