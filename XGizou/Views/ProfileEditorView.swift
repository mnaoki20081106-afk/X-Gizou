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
                Section("プロフィール名") {
                    TextField("例: お試し1", text: $draft.name)
                }

                Section("ブラウザ環境") {
                    LabeledContent("Runtime", value: "iOS WebKit")
                    LabeledContent("Session", value: "分離")
                    LabeledContent("Content", value: "Mobile")
                }

                #if DEBUG
                if !RiskReductionPolicy.isEnabled {
                    Section("ユーザーエージェント（DEBUG）") {
                        Picker("プリセット", selection: $draft.userAgentPreset) {
                            ForEach(UserAgentPreset.allCases) { preset in
                                Text(preset.title).tag(preset)
                            }
                        }

                        if draft.userAgentPreset == .custom {
                            TextEditor(text: $draft.customUserAgent)
                                .frame(minHeight: 90)
                        }

                        Text(draft.effectiveUserAgent.isEmpty ? "未設定" : draft.effectiveUserAgent)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    Section("デバイス互換性（DEBUG）") {
                        Picker("プリセット", selection: $draft.devicePreset) {
                            ForEach(DevicePreset.allCases) { preset in
                                Text(preset.title).tag(preset)
                            }
                        }

                        if draft.devicePreset == .custom {
                            TextField("Platform", text: $draft.customDevice.platform)
                            TextField("画面サイズ", text: $draft.customDevice.screen)
                            TextField("CPU コア数", value: $draft.customDevice.cpuCores, format: .number)
                                .keyboardType(.numberPad)
                            TextField("タッチポイント", value: $draft.customDevice.touchPoints, format: .number)
                                .keyboardType(.numberPad)
                            TextField("Vendor", text: $draft.customDevice.vendor)
                        }
                    }
                }
                #endif

                Section {
                    Label("安全設定は自動適用されます", systemImage: "shield.checkered")
                        .foregroundStyle(.green)
                    Text("通常版ではUAや端末表示の手動調整を出さず、プロフィール作成を名前だけで完了できるようにしています。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
