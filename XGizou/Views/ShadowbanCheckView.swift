import SwiftUI

struct ShadowbanCheckView: View {
    @State private var username = ""
    @State private var result: ShadowbanResult?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var usernameFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    checkerCard

                    if let result {
                        resultContent(result)
                    } else {
                        explanationCard
                    }

                    sourceCard
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("シャドウバンチェック")
            .navigationBarTitleDisplayMode(.inline)
            .alert("チェックできませんでした", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var checkerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Xユーザー名")
                .font(.headline)

            HStack(spacing: 10) {
                Text("@")
                    .font(.title3.bold())
                    .foregroundStyle(.secondary)

                TextField("username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .focused($usernameFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        runCheck()
                    }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

            Button {
                runCheck()
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }

                    Text(isLoading ? "チェック中…" : "チェックする")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private func resultContent(_ result: ShadowbanResult) -> some View {
        VStack(spacing: 18) {
            accountCard(result)
            checksCard(result)
            accuracyNote(result)
        }
    }

    private func accountCard(_ result: ShadowbanResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let legacy = result.user?.legacy {
                HStack(spacing: 12) {
                    AsyncImage(url: legacy.profileImageURL) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 54, height: 54)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(legacy.name ?? "X User")
                            .font(.headline)
                        Text("@\(legacy.screenName ?? username)")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                if let description = legacy.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()
            }

            HStack(spacing: 10) {
                Image(systemName: accountStatusIcon(result))
                    .foregroundStyle(accountStatusColor(result))
                Text(accountStatusText(result))
                    .fontWeight(.semibold)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func checksCard(_ result: ShadowbanResult) -> some View {
        VStack(spacing: 0) {
            ShadowbanStatusRow(
                title: "Search Suggestion Ban",
                subtitle: "検索候補からの除外",
                state: definitiveState(isDetected: result.searchSuggestionBan, result: result)
            )

            Divider().padding(.leading, 46)

            ShadowbanStatusRow(
                title: "Search Ban",
                subtitle: "検索結果からの除外",
                state: definitiveState(isDetected: result.searchBan, result: result)
            )

            Divider().padding(.leading, 46)

            ShadowbanStatusRow(
                title: "Ghost Ban",
                subtitle: "返信一覧からの除外",
                state: upstreamPlaceholderState(reported: result.ghostBan, result: result)
            )

            Divider().padding(.leading, 46)

            ShadowbanStatusRow(
                title: "Reply Deboosting",
                subtitle: "返信の表示順位低下",
                state: upstreamPlaceholderState(reported: result.replyDeboosting, result: result)
            )
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func accuracyNote(_ result: ShadowbanResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("判定について", systemImage: "info.circle")
                .font(.headline)

            Text("これはX公式の判定ではなく、検索結果と検索候補への露出を外部から確認する参考チェックです。検索仕様の変更や地域・ログイン状態によって結果が変わる可能性があります。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !result.notFound && !result.suspended && !result.protected && !result.noTweet {
                Text("現在参照している公開実装では、Ghost Ban と Reply Deboosting のバックエンド判定ロジックは実装されていないため、falseを「問題なし」とは表示せず未判定として扱います。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("何を確認する？", systemImage: "eye")
                .font(.headline)

            Text("公開されている Shadowban-Test/X の判定サービスを利用し、ユーザー名から Search Suggestion Ban と Search Ban を確認します。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("ログインCookieやXの認証トークンをこの画面から外部へ送信する実装にはしていません。送信するのは入力したユーザー名だけです。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("判定エンジン", systemImage: "chevron.left.forwardslash.chevron.right")
                .font(.headline)

            Link(destination: ShadowbanChecker.serviceURL) {
                HStack {
                    Text("shadowban.lami.zip")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                }
            }

            Link(destination: ShadowbanChecker.sourceURL) {
                HStack {
                    Text("Shadowban-Test/X（GPL-3.0）")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func runCheck() {
        guard !isLoading else { return }

        usernameFocused = false
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let normalized = try ShadowbanChecker.normalizeUsername(username)
                let checked = try await ShadowbanChecker.check(username: normalized)

                await MainActor.run {
                    username = normalized
                    result = checked
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    result = nil
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private func definitiveState(isDetected: Bool, result: ShadowbanResult) -> ShadowbanStatusRow.State {
        if result.notFound || result.suspended || result.protected || result.noTweet {
            return .unknown
        }
        return isDetected ? .detected : .notDetected
    }

    private func upstreamPlaceholderState(reported: Bool, result: ShadowbanResult) -> ShadowbanStatusRow.State {
        if result.notFound || result.suspended || result.protected || result.noTweet {
            return .unknown
        }
        return reported ? .detected : .unknown
    }

    private func accountStatusText(_ result: ShadowbanResult) -> String {
        if result.notFound {
            return "ユーザーが見つかりません"
        }
        if result.suspended {
            return "アカウントが凍結されています"
        }
        if result.protected {
            return "非公開アカウントのため十分に判定できません"
        }
        if result.noTweet {
            return "判定に使える投稿がありません"
        }
        if result.searchBan || result.searchSuggestionBan {
            return "検索系の露出制限を検出しました"
        }
        return "検索系の露出制限は検出されませんでした"
    }

    private func accountStatusIcon(_ result: ShadowbanResult) -> String {
        if result.notFound || result.suspended {
            return "exclamationmark.triangle.fill"
        }
        if result.protected || result.noTweet {
            return "questionmark.circle.fill"
        }
        if result.searchBan || result.searchSuggestionBan {
            return "exclamationmark.shield.fill"
        }
        return "checkmark.circle.fill"
    }

    private func accountStatusColor(_ result: ShadowbanResult) -> Color {
        if result.notFound || result.suspended || result.searchBan || result.searchSuggestionBan {
            return .red
        }
        if result.protected || result.noTweet {
            return .orange
        }
        return .green
    }
}

private struct ShadowbanStatusRow: View {
    enum State {
        case detected
        case notDetected
        case unknown

        var icon: String {
            switch self {
            case .detected:
                return "exclamationmark.triangle.fill"
            case .notDetected:
                return "checkmark.circle.fill"
            case .unknown:
                return "questionmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .detected:
                return .red
            case .notDetected:
                return .green
            case .unknown:
                return .blue
            }
        }

        var label: String {
            switch self {
            case .detected:
                return "検出"
            case .notDetected:
                return "未検出"
            case .unknown:
                return "未判定"
            }
        }
    }

    let title: String
    let subtitle: String
    let state: State

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: state.icon)
                .font(.title3)
                .foregroundStyle(state.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(state.label)
                .font(.caption.bold())
                .foregroundStyle(state.color)
        }
        .padding(16)
    }
}
