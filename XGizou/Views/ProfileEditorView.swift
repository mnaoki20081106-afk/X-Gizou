import SwiftUI

struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: ProfileStore

    private let isNew: Bool
    private let onSave: (BrowserProfile) -> Void
    @State private var draft: BrowserProfile
    @State private var showsAdvanced = false
    @State private var showsIndividualSettings = false

    init(profile: BrowserProfile?, onSave: @escaping (BrowserProfile) -> Void) {
        isNew = profile == nil
        self.onSave = onSave
        _draft = State(initialValue: profile ?? BrowserProfile(name: "新しいプロフィール"))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("プロフィール") {
                    TextField("名前", text: $draft.name)
                    Picker("ブラウザ", selection: executionModeSelection) {
                        Text("iPhone内").tag(BrowserExecutionMode.onDevice)
                        Text("独立環境").tag(BrowserExecutionMode.remote)
                    }
                }

                if draft.effectiveExecutionMode == .remote {
                    Section {
                        TextField("https://サーバー名.ts.net", text: remoteAddress)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if remoteServiceIsShared {
                            Text("このホストは別のプロフィールが使用中です。別プロフィールには別VM・別ホストの専用ブラウザを指定してください。")
                                .foregroundStyle(.red)
                        }
                    } header: {
                        Text("接続先")
                    } footer: {
                        Text("プロフィールごとに別VM・別ホストの専用ブラウザを用意してください。Xはそのリモート環境の実際のOS・ブラウザ・保存領域・ネットワーク出口を利用します。同じiPhone内の値は注入しません。")
                    }
                } else {
                    Section {
                        LabeledContent("ブラウザ設定", value: draft.effectiveFingerprintOptions.enabled ? "手動" : "自動")
                        DisclosureGroup("詳細設定", isExpanded: $showsAdvanced) {
                            Toggle("ブラウザ値を手動で変更", isOn: fingerprintEnabled)

                            if draft.effectiveFingerprintOptions.enabled {
                                Picker("ブラウザ", selection: userAgentSelection) {
                                    ForEach(UserAgentPreset.allCases) { preset in
                                        Text(preset.title).tag(preset)
                                    }
                                }
                                if draft.userAgentPreset == .custom {
                                    TextField("カスタムUA", text: $draft.customUserAgent, axis: .vertical)
                                        .lineLimit(2...4)
                                }
                                Picker("端末", selection: deviceSelection) {
                                    ForEach(DevicePreset.allCases) { preset in
                                        Text(preset.title).tag(preset)
                                    }
                                }
                                if draft.devicePreset == .custom {
                                    TextField("Platform", text: $draft.customDevice.platform)
                                    TextField("画面サイズ", text: $draft.customDevice.screen)
                                    TextField("CPUコア数", value: $draft.customDevice.cpuCores, format: .number)
                                        .keyboardType(.numberPad)
                                    TextField("タッチポイント", value: $draft.customDevice.touchPoints, format: .number)
                                        .keyboardType(.numberPad)
                                    TextField("Vendor", text: $draft.customDevice.vendor)
                                }

                                DisclosureGroup("個別調整", isExpanded: $showsIndividualSettings) {
                                    Toggle("Canvas", isOn: spoofCanvas)
                                    Toggle("WebGL", isOn: spoofWebGL)
                                    Toggle("Audio", isOn: spoofAudio)
                                    Toggle("タイムゾーン", isOn: spoofTimezone)
                                    if draft.effectiveFingerprintOptions.spoofTimezone {
                                        TextField("Timezone", text: fingerprintTimezone)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled()
                                        if !hasValidTimezone {
                                            Text("有効なタイムゾーンを入力してください（例: Asia/Tokyo）。")
                                                .foregroundStyle(.red)
                                        }
                                    }
                                    TextField("Language", text: fingerprintLanguage)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                    Button("言語・時刻をiPhoneの設定に合わせる") {
                                        var options = draft.effectiveFingerprintOptions
                                        let preferred = Locale.preferredLanguages
                                        options.language = preferred.first ?? "ja-JP"
                                        options.languages = Array(preferred.prefix(3))
                                        if options.languages.isEmpty { options.languages = [options.language] }
                                        options.timezoneIdentifier = TimeZone.current.identifier
                                        options.dateTimezoneOffsetMinutes = -(TimeZone.current.secondsFromGMT() / 60)
                                        draft.fingerprintOptions = options
                                    }
                                    Button("描画シードを再生成") {
                                        var options = draft.effectiveFingerprintOptions
                                        options.seed = UInt64.random(in: UInt64.min...UInt64.max)
                                        draft.fingerprintOptions = options
                                    }
                                }
                            }
                        }
                    } footer: {
                        Text("自動ではiPhoneのWebKitが公開する値を使います。手動変更はWebページから見える一部の値だけに適用されます。")
                    }
                }
            }
            .navigationTitle(isNew ? "新規プロフィール" : "プロフィール編集")
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
        guard let host = draft.remoteEnvironmentHost else { return false }
        return store.profiles.contains { $0.id != draft.id && $0.remoteEnvironmentHost == host }
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
                if newValue && draft.userAgentPreset == .custom && draft.customUserAgent.isEmpty {
                    draft.selectUserAgent(.safariIOS)
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
