import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ProfileStore
    @State private var clearing = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
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
                    LabeledContent("Minimum iOS", value: "17.0")
                }

                Section {
                    Text("各プロファイルはiOS 17以降の識別付きWKWebsiteDataStoreを使い、Cookie・LocalStorage・IndexedDB・キャッシュ等を分離します。UAはWeb互換性テスト用に明示的に切替できます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Text("X-GizouはWebブラウザプロファイルを分離するアプリです。AppleやWebサービスの端末証明、App Attest、Secure Enclave、ハードウェア識別子、アカウント制限を回避する機能は実装していません。")
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
