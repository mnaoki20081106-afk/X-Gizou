import SwiftUI

struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss

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

                Section("ユーザーエージェント") {
                    Picker("プリセット", selection: $draft.userAgentPreset) {
                        ForEach(UserAgentPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }

                    if draft.userAgentPreset == .custom {
                        TextEditor(text: $draft.customUserAgent)
                            .frame(minHeight: 90)
                    }

                    Text(draft.effectiveUserAgent.isEmpty ? "システムUA" : draft.effectiveUserAgent)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Section("フィンガープリント") {
                    Toggle("フィンガープリント変更", isOn: fingerprintEnabled)

                    Picker("端末プリセット", selection: $draft.devicePreset) {
                        ForEach(DevicePreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    .disabled(!fingerprintEnabled.wrappedValue)

                    if draft.devicePreset != .custom {
                        Button("UAも「\(draft.devicePreset.title)」に合わせる") {
                            draft.userAgentPreset = draft.devicePreset.recommendedUserAgent
                            draft.customUserAgent = ""
                        }
                        .disabled(!fingerprintEnabled.wrappedValue)
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

                    Toggle("Canvas", isOn: spoofCanvas)
                        .disabled(!fingerprintEnabled.wrappedValue)
                    Toggle("WebGL", isOn: spoofWebGL)
                        .disabled(!fingerprintEnabled.wrappedValue)
                    Toggle("Timezone", isOn: spoofTimezone)
                        .disabled(!fingerprintEnabled.wrappedValue)
                } footer: {
                    Text("端末プリセットは navigator / screen / hardwareConcurrency / maxTouchPoints / devicePixelRatio / WebGL など、Webページから見えるブラウザ値に適用されます。")
                }

                Section("地域・言語") {
                    TextField("Language", text: fingerprintLanguage)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Timezone", text: fingerprintTimezone)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField(
                        "Timezone offset (min)",
                        value: fingerprintTimezoneOffset,
                        format: .number
                    )
                    .keyboardType(.numbersAndPunctuation)

                    Button("現在のiPhone設定に戻す") {
                        var options = draft.effectiveFingerprintOptions
                        let preferred = Locale.preferredLanguages
                        options.language = preferred.first ?? "ja-JP"
                        options.languages = Array(preferred.prefix(3))
                        if options.languages.isEmpty {
                            options.languages = [options.language]
                        }
                        options.timezoneIdentifier = TimeZone.current.identifier
                        options.dateTimezoneOffsetMinutes = -(TimeZone.current.secondsFromGMT() / 60)
                        draft.fingerprintOptions = options
                    }
                }
                .disabled(!fingerprintEnabled.wrappedValue)

                Section("フィンガープリントシード") {
                    LabeledContent(
                        "Seed",
                        value: String(draft.effectiveFingerprintOptions.seed, radix: 16).uppercased()
                    )
                    .font(.caption.monospaced())

                    Button("Canvasシードを再生成") {
                        var options = draft.effectiveFingerprintOptions
                        options.seed = UInt64.random(in: UInt64.min...UInt64.max)
                        draft.fingerprintOptions = options
                    }
                    .disabled(!fingerprintEnabled.wrappedValue)
                }

                Section("ブラウザ環境") {
                    LabeledContent("Runtime", value: "iOS WebKit")
                    LabeledContent("Session", value: "分離")
                    LabeledContent(
                        "Content",
                        value: draft.devicePreset.prefersDesktopContent ? "Desktop" : "Mobile"
                    )
                    LabeledContent(
                        "Fingerprint",
                        value: fingerprintEnabled.wrappedValue ? "ON" : "OFF"
                    )
                }

                Section {
                    Text("変更対象はWKWebViewからWebページに公開されるブラウザ値です。iOSの実ハードウェアID、Secure Enclave、AppleのAttestationそのものを書き換える機能ではありません。")
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

    private var fingerprintEnabled: Binding<Bool> {
        Binding(
            get: { draft.effectiveFingerprintOptions.enabled },
            set: { newValue in
                var options = draft.effectiveFingerprintOptions
                options.enabled = newValue
                draft.fingerprintOptions = options
            }
        )
    }

    private var spoofCanvas: Binding<Bool> {
        Binding(
            get: { draft.effectiveFingerprintOptions.spoofCanvas },
            set: { newValue in
                var options = draft.effectiveFingerprintOptions
                options.spoofCanvas = newValue
                draft.fingerprintOptions = options
            }
        )
    }

    private var spoofWebGL: Binding<Bool> {
        Binding(
            get: { draft.effectiveFingerprintOptions.spoofWebGL },
            set: { newValue in
                var options = draft.effectiveFingerprintOptions
                options.spoofWebGL = newValue
                draft.fingerprintOptions = options
            }
        )
    }

    private var spoofTimezone: Binding<Bool> {
        Binding(
            get: { draft.effectiveFingerprintOptions.spoofTimezone },
            set: { newValue in
                var options = draft.effectiveFingerprintOptions
                options.spoofTimezone = newValue
                draft.fingerprintOptions = options
            }
        )
    }

    private var fingerprintLanguage: Binding<String> {
        Binding(
            get: { draft.effectiveFingerprintOptions.language },
            set: { newValue in
                var options = draft.effectiveFingerprintOptions
                options.language = newValue
                options.languages = [newValue]
                draft.fingerprintOptions = options
            }
        )
    }

    private var fingerprintTimezone: Binding<String> {
        Binding(
            get: { draft.effectiveFingerprintOptions.timezoneIdentifier },
            set: { newValue in
                var options = draft.effectiveFingerprintOptions
                options.timezoneIdentifier = newValue
                draft.fingerprintOptions = options
            }
        )
    }

    private var fingerprintTimezoneOffset: Binding<Int> {
        Binding(
            get: { draft.effectiveFingerprintOptions.dateTimezoneOffsetMinutes },
            set: { newValue in
                var options = draft.effectiveFingerprintOptions
                options.dateTimezoneOffsetMinutes = newValue
                draft.fingerprintOptions = options
            }
        )
    }
}
