import SwiftUI

struct ProfilesView: View {
    @EnvironmentObject private var store: ProfileStore
    @AppStorage(RiskReductionPolicy.enabledKey) private var riskReductionMode = true
    @State private var showingNewProfile = false
    @State private var editingProfile: BrowserProfile?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: riskReductionMode ? "shield.checkered" : "exclamationmark.shield")
                            .foregroundStyle(riskReductionMode ? .green : .orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(riskReductionMode ? "安全モード ON" : "安全モード OFF")
                                .font(.subheadline.bold())
                            Text(riskReductionMode
                                 ? "各プロフィールを分離し、標準WebKitで動作"
                                 : "互換性テスト用のUA上書きが有効")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("プロファイル") {
                    if store.profiles.isEmpty {
                        ContentUnavailableView(
                            "プロファイルがありません",
                            systemImage: "person.crop.circle.badge.plus",
                            description: Text("右上の＋から最初のプロファイルを作成してください。")
                        )
                    } else {
                        ForEach(store.profiles) { profile in
                            Button {
                                store.select(profile)
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "person.crop.circle")
                                        .font(.title2)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(profile.name)
                                            .foregroundStyle(.primary)
                                        Text(riskReductionMode
                                             ? "System WebKit • 分離データ領域"
                                             : "\(profile.userAgentPreset.title) • \(profile.devicePreset.title)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if store.selectedProfileID == profile.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }

                                    Button {
                                        editingProfile = profile
                                    } label: {
                                        Image(systemName: "slider.horizontal.3")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: store.delete)
                    }
                }
            }
            .navigationTitle("プロファイル")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewProfile = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewProfile) {
            ProfileEditorView(profile: nil) { profile in
                store.save(profile)
                store.select(profile)
            }
        }
        .sheet(item: $editingProfile) { profile in
            ProfileEditorView(profile: profile) { updated in
                store.save(updated)
            }
        }
    }
}
