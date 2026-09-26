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
                .padding(.top, 28)

            Spacer()

            VStack(spacing: 14) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)

                Text("プロファイル未選択")
                    .font(.title2.bold())

                Text("プロファイルタブからアカウントを追加・選択してください")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 42)
            }
            .frame(maxWidth: .infinity)

            Spacer()
        }
        .background(Color(uiColor: .systemBackground))
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
            XBrowserHeader(
                title: profile.name,
                canGoBack: session.canGoBack,
                canGoForward: session.canGoForward,
                isLoading: session.isLoading,
                goBack: session.goBack,
                goForward: session.goForward,
                reload: session.reload
            )

            ZStack {
                BrowserWebView(webView: session.webView)

                if let errorMessage = session.errorMessage {
                    VStack(spacing: 14) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 38))
                            .foregroundStyle(.orange)

                        Text("Xを開けません")
                            .font(.headline)

                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button("再試行") {
                            session.reload()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(20)
                    .frame(maxWidth: 360)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding()
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
        .onAppear {
            session.apply(profile: profile)
            session.startIfNeeded()
        }
        .onChange(of: profile) { _, newValue in
            session.apply(profile: newValue)
        }
    }
}

struct XBrowserHeader: View {
    let title: String
    let canGoBack: Bool
    let canGoForward: Bool
    let isLoading: Bool
    let goBack: () -> Void
    let goForward: () -> Void
    let reload: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: goBack) {
                Image(systemName: "chevron.left")
                    .frame(width: 42, height: 42)
            }
            .disabled(!canGoBack)

            Button(action: goForward) {
                Image(systemName: "chevron.right")
                    .frame(width: 42, height: 42)
            }
            .disabled(!canGoForward)

            Spacer(minLength: 4)

            Text(title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 4)

            Button(action: reload) {
                Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                    .frame(width: 42, height: 42)
            }

            Color.clear
                .frame(width: 42, height: 42)
        }
        .font(.title3)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
