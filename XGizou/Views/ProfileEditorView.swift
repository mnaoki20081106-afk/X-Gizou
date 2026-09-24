import SwiftUI

struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ProfileStore

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

                Section("実行環境") {
                    Picker("ブラウザを動かす場所", selection: executionModeSelection) {
                        ForEach(BrowserExecutionMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }

                if draft.effectiveExecutionMode == .remote {
                    Section {
                        TextField("https://サーバー名.ts.net", text: remoteAddress)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if draft.remoteBrowserURL == nil {
                            Text("HTTPSの接続先を入力してください。パスワードやトークンはURLに含めないでください。")
                                .font(.caption)
                        }
                        if remoteServiceIsShared {
                            Text("別のプロフィールが同じリモートブラウザを使用しています。別コンテナの専用接続先を設定してください。")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    } header: {
                        Text("専用ブラウザの接続先")
                    } footer: {
                        Text("サーバーで動くブラウザを遠隔操作します。UA・フォント・IPはサーバー側の環境を使用します。接続先の用意が必要です。")
                    }
                    Section {
                        Text("プロフィールを分離するには、サーバー側でも別のブラウザと保存領域を用意してください。同じ接続先は同じセッションです。")
                        Text("このアプリのCookie削除はiPhone側のみです。Xのログイン情報はリモートブラウザ側で管理・削除します。")
                    }
                } else {
                Section("ユーザーエージェント") {
                    Picker("プリセット", selection: userAgentSelection) {
                        ForEach(UserAgentPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }

                    if draft.userAgentPreset == .custom {
                        TextEditor(text: $draft.customUserAgent)
                            .frame(minHeight: 90)
                    }

                    Text("プリセット選択時は、UAと端末の組み合わせを自動で合わせます。カスタム入力は維持されます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(draft.effectiveUserAgent.isEmpty ? "システムUA" : draft.effectiveUserAgent)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Section {
                    Toggle("フィンガープリント変更", isOn: fingerprintEnabled)

                    Picker("端末プリセット", selection: deviceSelection) {
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
                    Toggle("Audio", isOn: spoofAudio)
                        .disabled(!fingerprintEnabled.wrappedValue)
                    Toggle("Timezone", isOn: spoofTimezone)
                        .disabled(!fingerprintEnabled.wrappedValue)
                } header: {
                    Text("フィンガープリント")
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
                    if !hasValidTimezone {
                        Text("有効なタイムゾーンを入力してください（例: Asia/Tokyo）。")
                            .foregroundStyle(.red)
                    }
                    Text("時差はタイムゾーンと対象日時から自動計算します（夏時間対応）。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

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

                    Button("Canvas・Audioシードを再生成") {
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
                    .disabled(!canSave)
                }
            }
        }
    }

    private var executionModeSelection: Binding<BrowserExecutionMode> {
        Binding(get: { draft.effectiveExecutionMode }, set: { draft.executionMode = $0 })
    }

    private var remoteAddress: Binding<String> {
        Binding(get: { draft.remoteBrowserAddress ?? "" }, set: { draft.remoteBrowserAddress = $0 })
    }

    private var canSave: Bool {
        draft.effectiveExecutionMode == .remote
            ? draft.remoteBrowserService != nil && !remoteServiceIsShared
            : hasValidTimezone
    }

    private var remoteServiceIsShared: Bool {
        guard let service = draft.remoteBrowserService else { return false }
        return store.profiles.contains { $0.id != draft.id && $0.remoteBrowserService == service }
    }

    private var userAgentSelection: Binding<UserAgentPreset> {
        Binding(get: { draft.userAgentPreset }, set: { draft.selectUserAgent($0) })
    }

    private var deviceSelection: Binding<DevicePreset> {
        Binding(get: { draft.devicePreset }, set: { draft.selectDevice($0) })
    }

    private var fingerprintEnabled: Binding<Bool> {
        Binding(
            get: { draft.effectiveFingerprintOptions.enabled },
            set: { newValue in
                var options = draft.effectiveFingerprintOptions
                options.enabled = newValue
                draft.fingerprintOptions = options
                if newValue {
                    draft.selectUserAgent(draft.userAgentPreset)
                }
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

    private var spoofAudio: Binding<Bool> {
        Binding(
            get: { draft.effectiveFingerprintOptions.spoofAudio },
            set: { newValue in
                var options = draft.effectiveFingerprintOptions
                options.spoofAudio = newValue
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

    private var hasValidTimezone: Bool {
        let options = draft.effectiveFingerprintOptions
        return !options.enabled || !options.spoofTimezone || TimeZone(identifier: options.timezoneIdentifier) != nil
    }
}
