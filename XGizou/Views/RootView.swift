import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }

            ProfilesView()
                .tabItem {
                    Label("プロファイル", systemImage: "person.2.fill")
                }

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
        }
        .tint(.blue)
    }
}
