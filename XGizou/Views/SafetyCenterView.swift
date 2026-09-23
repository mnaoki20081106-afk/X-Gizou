import SwiftUI

struct SafetyCenterView: View {
    @EnvironmentObject private var store: ProfileStore
    @AppStorage(RiskReductionPolicy.enabledKey) private var riskReductionMode = true

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: riskReductionMode ? "shield.checkered" : "exclamationmark.shield")
                        .font(.title2)
                        .foregroundStyle(riskReductionMode ? .green : .orange)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(riskReductionMode ? "安全モード ON" : "安全モード OFF")
                            .font(.headline)
                        Text(riskReductionMode ? "通常のiOS WebKitとして動作" : "互換性テスト用のUA上書きを許可")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("現在の保護") {
                SafetyRow(
                    title: "プロファイル分離",
                    detail: "各プロフィールに固有のWKWebsiteDataStoreを使用",
                    ok: uniqueProfileIDs
                )
                SafetyRow(
                    title: "UA整合性",
                    detail: riskReductionMode ? "システムWebKitのUAを使用" : "カスタムUAが有効になる可能性あり",
                    ok: riskReductionMode
                )
                SafetyRow(
                    title: "表示モード",
                    detail: riskReductionMode ? "iOSのモバイル表示に固定" : "デスクトップ表示へ変更可能",
                    ok: riskReductionMode
                )
                SafetyRow(
                    title: "外部リンク分離",
                    detail: riskReductionMode ? "X以外のトップレベル遷移は外部ブラウザで開く" : "WebView内で開く場合あり",
                    ok: riskReductionMode
                )
                SafetyRow(
                    title: "自動操作",
                    detail: "自動投稿・自動フォロー・自動いいね機能なし",
                    ok: true
                )
                SafetyRow(
                    title: "認証情報",
                    detail: "BANチェックへログインCookieやauth_tokenを送信しない",
                    ok: true
                )
            }

            if let profile = store.selectedProfile {
                Section("選択中プロフィール") {
                    LabeledContent("名前", value: profile.name)
                    LabeledContent("データ領域", value: String(profile.id.uuidString.prefix(8)) + "…")

                    if riskReductionMode {
                        Text("このモードでは、保存済みのUA/デバイス互換性プリセットはX閲覧時には使わず、端末上の標準WebKit情報を優先します。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("UAや表示モードの上書きはサイトから見える情報と実際のWebKit挙動が食い違うことがあります。")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section {
                Text("この機能はアカウント停止を回避したり、停止済み端末・アカウントを別物として偽装するものではありません。BANをゼロに保証する方法はなく、ここでは誤検知につながり得る不自然なブラウザ偽装やプロフィール間のデータ混在を減らします。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("安全センター")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var uniqueProfileIDs: Bool {
        Set(store.profiles.map(\.id)).count == store.profiles.count
    }
}

private struct SafetyRow: View {
    let title: String
    let detail: String
    let ok: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ok ? .green : .orange)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
