import SwiftUI

struct SafetyCenterView: View {
    @EnvironmentObject private var store: ProfileStore
    @AppStorage(RiskReductionPolicy.enabledKey) private var storedSafetyMode = true

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: effectiveSafetyEnabled ? "shield.checkered" : "exclamationmark.shield")
                        .font(.title2)
                        .foregroundStyle(effectiveSafetyEnabled ? .green : .orange)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(effectiveSafetyEnabled ? "安全モード ON" : "安全モード OFF")
                            .font(.headline)
                        Text(RiskReductionPolicy.isReleaseLocked
                             ? "通常版では常時有効"
                             : (effectiveSafetyEnabled ? "通常のiOS WebKitとして動作" : "DEBUG互換性テスト中"))
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
                    title: "プロセス分離",
                    detail: "各アクティブプロフィールに独立WKProcessPoolを使用",
                    ok: true
                )
                SafetyRow(
                    title: "UA整合性",
                    detail: effectiveSafetyEnabled ? "システムWebKitのUAを使用" : "DEBUG上書き可能",
                    ok: effectiveSafetyEnabled
                )
                SafetyRow(
                    title: "表示モード",
                    detail: effectiveSafetyEnabled ? "iOSのモバイル表示に固定" : "DEBUG変更可能",
                    ok: effectiveSafetyEnabled
                )
                SafetyRow(
                    title: "外部リンク分離",
                    detail: effectiveSafetyEnabled ? "X以外のトップレベル遷移は外部ブラウザへ" : "DEBUGではWebView内遷移可能",
                    ok: effectiveSafetyEnabled
                )
                SafetyRow(
                    title: "Xアプリへの脱出防止",
                    detail: effectiveSafetyEnabled ? "x:// / twitter:// をブロック" : "DEBUGでは外部起動可能",
                    ok: effectiveSafetyEnabled
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
                }
            }

            Section {
                Text("安全モードは、プロフィール間のデータ混在や不自然なブラウザ偽装を避けるためのものです。アカウント停止を回避する保証や、停止済み端末・アカウントを別物として偽装する機能ではありません。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("安全センター")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var effectiveSafetyEnabled: Bool {
        #if DEBUG
        return storedSafetyMode
        #else
        return true
        #endif
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
