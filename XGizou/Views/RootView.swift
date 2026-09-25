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
        ZStack {
            switch selection {
            case .home:
                HomeView()
            case .profiles:
                ProfilesView()
            case .shadowban:
                ShadowbanCheckView()
            case .environment:
                EnvironmentView()
            case .settings:
                SettingsView(
                    openShadowban: { selection = .shadowban },
                    openEnvironment: { selection = .environment }
                )
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            XGizouTabBar(selection: $selection)
        }
        .tint(.blue)
    }
}

private struct XGizouTabBar: View {
    @Binding var selection: RootTab

    var body: some View {
        HStack {
            tabButton(.home, title: "ホーム", systemImage: "house.fill")
            Spacer()
            tabButton(.profiles, title: "プロファイル", systemImage: "person.2.fill")
            Spacer()
            tabButton(.settings, title: "設定", systemImage: "gearshape.fill")
        }
        .padding(.horizontal, 42)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func tabButton(_ tab: RootTab, title: String, systemImage: String) -> some View {
        Button {
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 23, weight: .semibold))
                Text(title)
                    .font(.caption2)
            }
            .frame(minWidth: 74)
            .foregroundStyle(isSelected(tab) ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func isSelected(_ tab: RootTab) -> Bool {
        switch tab {
        case .settings:
            return selection == .settings || selection == .shadowban || selection == .environment
        default:
            return selection == tab
        }
    }
}
