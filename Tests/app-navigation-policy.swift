import Foundation

@main
struct AppNavigationPolicyTest {
    static func main() {
        precondition(
            AppNavigationPolicy.destinationAfterProfileSelection() == .home,
            "Selecting a profile must immediately return to the X home screen"
        )
        print("app-navigation-policy: ok")
    }
}
