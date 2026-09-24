import SwiftUI

struct EnvironmentView: View {
    @EnvironmentObject private var store: ProfileStore

    @State private var snapshot: BrowserEnvironmentSnapshot?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let profile = store.selectedProfile, profile.effectiveExecutionMode == .remote {
                    List {
                        LabeledContent("実行環境", value: "リモートブラウザ")
                        LabeledContent("接続先", value: profile.remoteBrowserURL?.host ?? "未設定")
                        Text("Xを処理するブラウザとIPはサーバー側のものです。iPhone内のUA・指紋設定は適用しません。")
                        Text("この画面からリモート側の値は計測できません。接続先のブラウザ内で確認してください。")
                    }
                } else if let profile = store.selectedProfile {
                    List {
                        Section("選択中プロフィール") {
                            LabeledContent("名前", value: profile.name)
                            LabeledContent(
                                "フィンガープリント",
                                value: profile.effectiveFingerprintOptions.enabled ? "ON" : "OFF"
                            )
                            LabeledContent("端末プリセット", value: profile.devicePreset.title)
                            LabeledContent(
                                "データ領域",
                                value: String(profile.id.uuidString.prefix(8)) + "…"
                            )
                            LabeledContent("Webデータ", value: "プロフィールごとに分離")
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
                                EnvironmentRow(title: "UA-CH Platform", value: snapshot.uaDataPlatform)
                                EnvironmentRow(title: "言語", value: snapshot.language)
                                EnvironmentRow(title: "言語一覧", value: snapshot.languages)
                                EnvironmentRow(title: "CPU論理コア", value: snapshot.hardwareConcurrency)
                                EnvironmentRow(title: "Device memory", value: snapshot.deviceMemory)
                                EnvironmentRow(title: "Touch points", value: snapshot.maxTouchPoints)
                                EnvironmentRow(title: "Screen", value: snapshot.screen)
                                EnvironmentRow(title: "Pixel ratio", value: snapshot.pixelRatio)
                                EnvironmentRow(title: "Timezone", value: snapshot.timezone)
                                EnvironmentRow(title: "Timezone offset", value: snapshot.timezoneOffset)
                                EnvironmentRow(title: "WebGL vendor", value: snapshot.webGLVendor)
                                EnvironmentRow(title: "WebGL renderer", value: snapshot.webGLRenderer)
                                EnvironmentRow(title: "Canvas signature", value: snapshot.canvasSignature, monospaced: true)
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
                            Text("この画面は、選択中プロフィールの設定を同じJavaScript環境に適用したうえで、Webページから観測できる値を読み取ります。Canvas signatureはプロフィールのシードに応じて安定して変化します。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } header: {
                            Text("診断")
                        }

                        Section {
                            Text("変更対象はWKWebViewのブラウザ層です。iOSの実ハードウェアID、Secure Enclave、AppleのAttestationなどOS外部の識別子はこの画面の対象外です。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
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
            .task(id: store.selectedProfile) {
                guard let profile = store.selectedProfile else {
                    snapshot = nil
                    errorMessage = nil
                    return
                }
                guard profile.effectiveExecutionMode == .onDevice else {
                    snapshot = nil
                    errorMessage = nil
                    isLoading = false
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
        snapshot = nil

        do {
            let measured = try await BrowserEnvironmentProbe.measure(profile: profile)
            guard !Task.isCancelled, store.selectedProfile == profile else { return }
            snapshot = measured
        } catch {
            guard !Task.isCancelled, store.selectedProfile == profile else { return }
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
