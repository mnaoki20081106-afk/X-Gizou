import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ProfileStore
    @AppStorage(RiskReductionPolicy.enabledKey) private var riskReductionMode = true
    @State private var clearing = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $riskReductionMode) {
                        Label("安全モード", systemImage: "shield.checkered")
                    }
                    .onChange(of: riskReductionMode) { _, newValue in
                        RiskReductionPolicy.setEnabled(newValue)
                    }

                    NavigationLink {
                        SafetyCenterView()
                    } label: {
                        Label("安全センター", systemImage: "checkmark.shield")
                    }
                } header: {
                    Text("アカウント安全運用")
                } footer: {
                    Text(riskReductionMode
                         ? "ONではシステム標準のWebKit UAとモバイル表示を使い、X以外のトップレベルリンクを外部ブラウザへ分離します。プロフィールごとのWebデータ分離は常に有効です。"
                         : "OFFは互換性テスト向けです。保存したUAやデバイス表示プリセットが使われ、実際のWebKit挙動と食い違う可能性があります。")
                }

                Section("ブラウザデータ") {
                    if let profile = store.selectedProfile {
                        Button(role: .destructive) {
                            clear(profile)
                        } label: {
                            Label("「\(profile.name)」のCookie・キャッシュを削除", systemImage: "trash")
                        }
                    }

                    Button(role: .destructive) {
                        clearAll()
                    } label: {
                        Label("全プロファイルのWebデータを削除", systemImage: "trash.slash")
                    }
                    .disabled(store.profiles.isEmpty)
                }

                Section("実装") {
                    LabeledContent("Web engine", value: "WKWebView")
                    LabeledContent("Profile isolation", value: "WKWebsiteDataStore")
                    LabeledContent("Safety mode", value: riskReductionMode ? "ON" : "OFF")
                    LabeledContent("Minimum iOS", value: "17.0")
                }

                Section {
                    Text("各プロファイルはiOS 17以降の識別付きWKWebsiteDataStoreを使い、Cookie・LocalStorage・IndexedDB・キャッシュ等を分離します。安全モードでは不自然なUA上書きやデスクトップ偽装を使わず、端末上の標準WebKit情報を優先します。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Text("安全モードはBANを保証して防ぐものではありません。停止済み端末・アカウントを別物として偽装したり、Apple/XのAttestationやアカウント制限を回避する機能は実装していません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定")
            .overlay {
                if clearing {
                    ProgressView("削除中…")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .alert("完了", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
        }
    }

    private func clear(_ profile: BrowserProfile) {
        clearing = true
        Task {
            await store.clearWebsiteData(for: profile.id)
            clearing = false
            message = "選択したプロファイルのWebデータを削除しました。"
        }
    }

    private func clearAll() {
        clearing = true
        Task {
            await store.clearAllWebsiteData()
            clearing = false
            message = "全プロファイルのWebデータを削除しました。"
        }
    }
}
