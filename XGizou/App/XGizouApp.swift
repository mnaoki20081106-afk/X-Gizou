import SwiftUI

@main
struct XGizouApp: App {
    @StateObject private var profileStore = ProfileStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(profileStore)
                .preferredColorScheme(.dark)
        }
    }
}
