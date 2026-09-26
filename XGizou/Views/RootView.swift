import SwiftUI

struct RootView: View {
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }
                .tag(AppTab.home)

            ProfilesView {
                selection = AppNavigationPolicy.destinationAfterProfileSelection()
            }
            .tabItem {
                Label("プロファイル", systemImage: "person.2.fill")
            }
            .tag(AppTab.profiles)

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
                .tag(AppTab.settings)
        }
        .tint(.blue)
    }
}
