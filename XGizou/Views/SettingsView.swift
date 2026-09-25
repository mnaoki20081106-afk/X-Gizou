import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ProfileStore

    var openShadowban: () -> Void = {}
    var openEnvironment: () -> Void = {}
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
                    Text("セッション保護")
                } footer: {
                    #if DEBUG
                    Text(RiskReductionPolicy.isEnabled
                         ? "プロフィール分離・外部リンク分離を使用します。UAとフィンガープリントは各プロフィール設定を使用します。"
                         : "DEBUG互換性テスト用に安全モードが無効です。")
                    #else
                    Text("通常版ではプロフィール分離と外部リンク分離を常時適用します。UAとフィンガープリントは各プロフィール設定を使用します。")
                    #endif
                }

                Section("ツール") {
                    Button(action: openShadowban) {
                        HStack {
                            Label("BANチェック", systemImage: "magnifyingglass.circle.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)

                    Button(action: openEnvironment) {
                        HStack {
                            Label("環境", systemImage: "viewfinder.circle.fill")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                Section("ブラウザデータ") {
                    if let profile = store.selectedProfile {
                        Button(role: .destructive) {
                            clear(profile)
                        } label: {
                            Label("「\(profile.name)」のiPhone側データを削除", systemImage: "trash")
                        }
                    }

                    Button(role: .destructive) {
                        clearAll()
                    } label: {
                        Label("全プロファイルのiPhone側データを削除", systemImage: "trash.slash")
                    }
                    .disabled(store.profiles.isEmpty)
                }

                Section {
                    Text("リモートブラウザのCookie・履歴はサーバー側に保存されます。ここでの削除やプロフィール削除では消えません。リモートブラウザ内で削除してください。")
                        .font(.footnote)
                }

                Section("実装") {
                    LabeledContent("Web engine", value: "iOS WebKit / Remote")
                    LabeledContent("Profile isolation", value: "WKWebsiteDataStore")
                    LabeledContent("Fingerprint layer", value: "WKUserScript")
                    LabeledContent("Safety mode", value: RiskReductionPolicy.isEnabled ? "ON" : "OFF")
                    LabeledContent("Minimum iOS", value: "17.0")
                }

                Section {
                    Text("各プロフィールは固有のWKWebsiteDataStoreと独立したWebKitプロセスプールを使います。UA、navigator、screen、WebGL、Canvas、timezoneなどのブラウザ公開値はプロフィール設定に応じて適用されます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Text("ブラウザ層の値を変更する機能です。iOSの実ハードウェアID、Secure Enclave、AppleのAttestationなどを変更するものではありません。")
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
            message = "選択したプロファイルのiPhone側Webデータを削除しました。"
        }
    }

    private func clearAll() {
        clearing = true
        Task {
            await store.clearAllWebsiteData()
            clearing = false
            message = "全プロファイルのiPhone側Webデータを削除しました。"
        }
    }
}

