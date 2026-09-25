import SwiftUI

private enum RootTab: Hashable {
    case home
    case profiles
    case shadowban
    case environment
    case settings
}

struct RootView: View {
    @State private var selection: RootTab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeView(
                openProfiles: { selection = .profiles },
                openShadowban: { selection = .shadowban },
                openEnvironment: { selection = .environment },
                openSettings: { selection = .settings }
            )
            .tabItem {
                Label("ホーム", systemImage: "house.fill")
            }
            .tag(RootTab.home)

            ProfilesView()
                .tabItem {
                    Label("プロファイル", systemImage: "person.2.fill")
                }
                .tag(RootTab.profiles)

            ShadowbanCheckView()
                .tabItem {
                    Label("BANチェック", systemImage: "magnifyingglass.circle.fill")
                }
                .tag(RootTab.shadowban)

            EnvironmentView()
                .tabItem {
                    Label("環境", systemImage: "viewfinder.circle.fill")
                }
                .tag(RootTab.environment)

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
                .tag(RootTab.settings)
        }
        .tint(.blue)
    }
}
