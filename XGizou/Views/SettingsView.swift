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
                    #if DEBUG
                    Toggle(isOn: $riskReductionMode) {
                        Label("安全モード", systemImage: "shield.checkered")
                    }
                    .onChange(of: riskReductionMode) { _, newValue in
                        RiskReductionPolicy.setEnabled(newValue)
                    }
                    #else
                    HStack {
                        Label("安全モード", systemImage: "shield.checkered")
                        Spacer()
                        Text("ON")
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    }
                    #endif

                    NavigationLink {
                        SafetyCenterView()
                    } label: {
                        Label("安全センター", systemImage: "checkmark.shield")
                    }
                } header: {
                    Text("アカウント安全運用")
                } footer: {
                    #if DEBUG
                    Text(RiskReductionPolicy.isEnabled
                         ? "標準WebKit・分離セッション・外部リンク分離を使用します。"
                         : "DEBUG互換性テスト用に安全モードが無効です。")
                    #else
                    Text("通常版では安全モードを常時ONにしています。設定操作を増やさず、標準WebKit・分離セッション・外部リンク分離を自動適用します。")
                    #endif
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
                    LabeledContent("Safety mode", value: RiskReductionPolicy.isEnabled ? "ON" : "OFF")
                    LabeledContent("Minimum iOS", value: "17.0")
                }

                Section {
                    Text("各プロファイルは固有のWKWebsiteDataStoreと独立したWebKitプロセスプールを使います。通常版ではUA上書きやデスクトップ偽装をX閲覧に適用せず、端末上の標準WebKit情報を優先します。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Text("BANをゼロに保証する機能ではありません。また、停止済み端末・アカウントを別物として偽装したり、Apple/XのAttestationやアカウント制限を回避する機能は実装していません。")
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
