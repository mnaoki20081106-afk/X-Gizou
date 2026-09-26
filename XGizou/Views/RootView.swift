import SwiftUI

private enum RootTab: Hashable {
    case home
    case profiles
    case settings
}

struct RootView: View {
    @State private var selection: RootTab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }
                .tag(RootTab.home)

            ProfilesView {
                selection = .home
            }
            .tabItem {
                Label("プロファイル", systemImage: "person.2.fill")
            }
            .tag(RootTab.profiles)

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
                .tag(RootTab.settings)
        }
        .tint(.blue)
    }
}
