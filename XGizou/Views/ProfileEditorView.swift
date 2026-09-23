import SwiftUI

struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(RiskReductionPolicy.enabledKey) private var riskReductionMode = true

    private let isNew: Bool
    private let onSave: (BrowserProfile) -> Void
    @State private var draft: BrowserProfile

    init(profile: BrowserProfile?, onSave: @escaping (BrowserProfile) -> Void) {
        isNew = profile == nil
        self.onSave = onSave
        _draft = State(initialValue: profile ?? BrowserProfile(name: "お試し1"))
    }

    var body: some View {
        NavigationStack {
            Form {
                if riskReductionMode {
                    Section {
                        Label("安全モードではUA・デバイス表示の上書きを使いません", systemImage: "shield.checkered")
                            .foregroundStyle(.green)
                        Text("下のプリセットは互換性テスト用として保存できますが、X閲覧時はシステム標準のWebKit情報が優先されます。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("プロフィール名") {
                    TextField("例: お試し1", text: $draft.name)
                }

                Section("ユーザーエージェント") {
                    Picker("プリセット", selection: $draft.userAgentPreset) {
                        ForEach(UserAgentPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .disabled(riskReductionMode)

                    if draft.userAgentPreset == .custom {
                        TextEditor(text: $draft.customUserAgent)
                            .frame(minHeight: 90)
                            .disabled(riskReductionMode)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ユーザーエージェント プレビュー")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(riskReductionMode
                             ? "安全モード: システム標準UAを使用"
                             : (draft.effectiveUserAgent.isEmpty ? "未設定" : draft.effectiveUserAgent))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                Section {
                    Picker("プリセット", selection: $draft.devicePreset) {
                        ForEach(DevicePreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .disabled(riskReductionMode)

                    if draft.devicePreset == .custom {
                        TextField("Platform", text: $draft.customDevice.platform)
                            .disabled(riskReductionMode)
                        TextField("画面サイズ", text: $draft.customDevice.screen)
                            .disabled(riskReductionMode)
                        TextField("CPU コア数", value: $draft.customDevice.cpuCores, format: .number)
                            .keyboardType(.numberPad)
                            .disabled(riskReductionMode)
                        TextField("タッチポイント", value: $draft.customDevice.touchPoints, format: .number)
                            .keyboardType(.numberPad)
                            .disabled(riskReductionMode)
                        TextField("Vendor", text: $draft.customDevice.vendor)
                            .disabled(riskReductionMode)
                    }
                } header: {
                    Text("デバイスプロファイル")
                } footer: {
                    Text(riskReductionMode
                         ? "安全モードでは実端末のWebKit表示を優先し、この互換性プリセットは適用しません。"
                         : "この項目は表示互換性のためのプリセットです。OSのハードウェア識別子、App Attest、Secure Enclaveなどの端末証明は変更しません。")
                }

                Section("デバイスプロファイル プレビュー") {
                    if riskReductionMode {
                        PreviewRow(label: "Runtime", value: "System WebKit")
                        PreviewRow(label: "Content mode", value: "Mobile")
                        PreviewRow(label: "UA override", value: "Off")
                    } else {
                        PreviewRow(label: "Platform", value: draft.effectiveDevice.platform)
                        PreviewRow(label: "画面サイズ", value: draft.effectiveDevice.screen)
                        PreviewRow(label: "CPU コア数", value: String(draft.effectiveDevice.cpuCores))
                        PreviewRow(label: "タッチポイント", value: String(draft.effectiveDevice.touchPoints))
                        PreviewRow(label: "Vendor", value: draft.effectiveDevice.vendor)
                    }
                }
            }
            .navigationTitle(isNew ? "新規プロファイル" : "プロファイル編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        draft.name = trimmed.isEmpty ? "名称未設定" : trimmed
                        onSave(draft)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct PreviewRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
