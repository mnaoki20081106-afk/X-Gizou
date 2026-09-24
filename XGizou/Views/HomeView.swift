import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: ProfileStore

    var body: some View {
        Group {
            if let profile = store.selectedProfile {
                if profile.effectiveExecutionMode == .remote {
                    RemoteBrowserScreen(profile: profile)
                        .id(profile.id)
                } else {
                    BrowserScreen(profile: profile)
                        .id(profile.id)
                }
            } else {
                EmptyProfileView()
            }
        }
    }
}

private struct EmptyProfileView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ホーム")
                .font(.largeTitle.bold())
                .padding(.horizontal, 24)
                .padding(.top, 24)

            Spacer()

            VStack(spacing: 14) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 68))
                    .foregroundStyle(.secondary)
                Text("プロファイル未選択")
                    .font(.title2.bold())
                Text("プロファイルタブからアカウント用のブラウザプロファイルを追加・選択してください")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 36)
            }
            .frame(maxWidth: .infinity)

            Spacer()
        }
    }
}

private struct BrowserScreen: View {
    let profile: BrowserProfile
    @StateObject private var session: BrowserSession

    init(profile: BrowserProfile) {
        self.profile = profile
        _session = StateObject(wrappedValue: BrowserSession(profile: profile))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                Button {
                    session.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!session.canGoBack)

                Button {
                    session.goForward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!session.canGoForward)

                Spacer()

                VStack(spacing: 2) {
                    Text(profile.name)
                        .font(.headline)
                        .lineLimit(1)
                    if let host = session.currentURL?.host {
                        Text(host)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    session.reload()
                } label: {
                    Image(systemName: session.isLoading ? "xmark" : "arrow.clockwise")
                }
            }
            .font(.title3)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)

            Divider()

            BrowserWebView(webView: session.webView)
        }
        .onAppear {
            session.apply(profile: profile)
            session.startIfNeeded()
        }
        .onChange(of: profile) { _, newValue in
            session.apply(profile: newValue)
        }
    }
}
