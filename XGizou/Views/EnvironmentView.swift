import SwiftUI

struct EnvironmentView: View {
    @EnvironmentObject private var store: ProfileStore

    @State private var snapshot: BrowserEnvironmentSnapshot?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let profile = store.selectedProfile {
                    List {
                        Section("選択中プロフィール") {
                            LabeledContent("名前", value: profile.name)
                            LabeledContent(
                                "データ領域",
                                value: String(profile.id.uuidString.prefix(8)) + "…"
                            )
                            LabeledContent(
                                "Webデータ",
                                value: "プロフィールごとに分離"
                            )
                        }

                        Section("Webページから見える環境") {
                            if isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView("計測中…")
                                    Spacer()
                                }
                            } else if let snapshot {
                                EnvironmentRow(title: "User-Agent", value: snapshot.userAgent, monospaced: true)
                                EnvironmentRow(title: "Platform", value: snapshot.platform)
                                EnvironmentRow(title: "Vendor", value: snapshot.vendor)
                                EnvironmentRow(title: "言語", value: snapshot.language)
                                EnvironmentRow(title: "言語一覧", value: snapshot.languages)
                                EnvironmentRow(title: "CPU論理コア", value: snapshot.hardwareConcurrency)
                                EnvironmentRow(title: "Touch points", value: snapshot.maxTouchPoints)
                                EnvironmentRow(title: "Screen", value: snapshot.screen)
                                EnvironmentRow(title: "Pixel ratio", value: snapshot.pixelRatio)
                                EnvironmentRow(title: "Timezone", value: snapshot.timezone)
                                EnvironmentRow(title: "WebDriver", value: snapshot.webdriver)
                            } else if let errorMessage {
                                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            } else {
                                Text("未計測")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Section {
                            Button {
                                Task { await refresh(profile: profile) }
                            } label: {
                                Label("再計測", systemImage: "arrow.clockwise")
                            }
                            .disabled(isLoading)
                        }

                        Section {
                            Text("ここで表示するのは、現在のWKWebViewからWebページに実際に見える値です。X-GizouはCookie・LocalStorage・IndexedDBなどのWebデータをプロフィールごとに分離しますが、端末のハードウェアID、Secure Enclave、Apple/XのAttestationを別端末として偽装するものではありません。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } header: {
                            Text("この画面について")
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "プロファイル未選択",
                        systemImage: "person.crop.circle.badge.questionmark",
                        description: Text("プロファイルタブからX用のブラウザプロファイルを作成・選択してください。")
                    )
                }
            }
            .navigationTitle("環境")
            .task(id: store.selectedProfileID) {
                guard let profile = store.selectedProfile else {
                    snapshot = nil
                    errorMessage = nil
                    return
                }
                await refresh(profile: profile)
            }
        }
    }

    @MainActor
    private func refresh(profile: BrowserProfile) async {
        isLoading = true
        errorMessage = nil

        do {
            snapshot = try await BrowserEnvironmentProbe.measure(profile: profile)
        } catch {
            snapshot = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

private struct EnvironmentRow: View {
    let title: String
    let value: String
    var monospaced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value.isEmpty ? "—" : value)
                .font(monospaced ? .caption.monospaced() : .body)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }
}
