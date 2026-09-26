import SwiftUI

struct ProfilesView: View {
    @EnvironmentObject private var store: ProfileStore

    var onOpenSelectedProfile: () -> Void = {}

    @State private var showingNewProfile = false
    @State private var editingProfile: BrowserProfile?

    var body: some View {
        NavigationStack {
            List {
                #if DEBUG
                if !RiskReductionPolicy.isEnabled {
                    Section {
                        Label("DEBUG: 安全モードが無効です", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
                #endif

                Section("iPhone内の分離") {
                    isolationStatusRow

                    Text("オンデバイスの各プロフィールは、Cookie・LocalStorage・IndexedDB・キャッシュを別々の永続WebKitデータストアに保存します。これはブラウザデータの分離であり、同じiPhoneを物理的な別端末として扱わせることを保証するものではありません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                                onOpenSelectedProfile()
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "person.crop.circle")
                                        .font(.title2)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(profile.name)
                                            .foregroundStyle(.primary)
                                        Text(profile.effectiveExecutionMode == .remote
                                             ? (profile.normalizedRemoteEnvironmentID == nil
                                                ? "独立ブラウザ • 環境ID未確認"
                                                : "独立ブラウザ • 環境ID確認済み")
                                             : "ブラウザデータ分離 • iOS WebKit")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if store.selectedProfileID == profile.id {
                                        Text("使用中")
                                            .font(.caption.bold())
                                            .foregroundStyle(.blue)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundStyle(.tertiary)
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
            .refreshable {
                await store.refreshIsolationState()
            }
        }
        .sheet(isPresented: $showingNewProfile) {
            ProfileEditorView(profile: nil) { profile in
                store.save(profile)
                store.select(profile)
                onOpenSelectedProfile()
            }
        }
        .sheet(item: $editingProfile) { profile in
            ProfileEditorView(profile: profile) { updated in
                store.save(updated)
            }
        }
    }

    @ViewBuilder
    private var isolationStatusRow: some View {
        switch store.isolationState {
        case .checking:
            HStack {
                Label("分離状態を確認中", systemImage: "hourglass")
                Spacer()
                ProgressView()
            }

        case .ready(let profileCount):
            Label(
                profileCount == 0
                    ? "オンデバイスプロフィール未作成"
                    : "\(profileCount)件のプロフィールを独立保存",
                systemImage: profileCount == 0 ? "circle.dashed" : "checkmark.shield.fill"
            )
            .foregroundStyle(profileCount == 0 ? Color.secondary : Color.green)

        case .issue(let missingStoreCount):
            VStack(alignment: .leading, spacing: 6) {
                Label(
                    "\(missingStoreCount)件の保存領域を確認できません",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)

                Button("再確認") {
                    Task { await store.refreshIsolationState() }
                }
            }
        }
    }
}
