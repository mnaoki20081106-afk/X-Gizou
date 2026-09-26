import Foundation

enum AppTab: String, Equatable {
    case home
    case profiles
    case settings
}

enum AppNavigationPolicy {
    static func destinationAfterProfileSelection() -> AppTab {
        .home
    }
}
