import Combine
import Foundation
import WebKit

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [BrowserProfile] = []
    @Published var selectedProfileID: UUID? {
        didSet { saveSelectedProfileID() }
    }

    private let profilesKey = "xgizou.profiles.v1"
    private let selectedProfileKey = "xgizou.selectedProfile.v1"

    init() {
        RiskReductionPolicy.bootstrap()
        load()
    }

    var selectedProfile: BrowserProfile? {
        guard let selectedProfileID else { return nil }
        return profiles.first(where: { $0.id == selectedProfileID })
    }

    func save(_ profile: BrowserProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }

        if selectedProfileID == nil {
            selectedProfileID = profile.id
        }
        persist()
    }

    func select(_ profile: BrowserProfile) {
        selectedProfileID = profile.id
    }

    func delete(at offsets: IndexSet) {
        let ids = offsets.compactMap { index in
            profiles.indices.contains(index) ? profiles[index].id : nil
        }

        for id in ids {
            Task { await clearWebsiteData(for: id) }
        }

        for index in offsets.sorted(by: >) where profiles.indices.contains(index) {
            profiles.remove(at: index)
        }

        if let selectedProfileID, !profiles.contains(where: { $0.id == selectedProfileID }) {
            self.selectedProfileID = profiles.first?.id
        }
        persist()
    }

    func delete(_ profile: BrowserProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        delete(at: IndexSet(integer: index))
    }

    func clearWebsiteData(for profileID: UUID) async {
        let store = WKWebsiteDataStore(forIdentifier: profileID)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                modifiedSince: .distantPast
            ) {
                continuation.resume()
            }
        }
    }

    func clearAllWebsiteData() async {
        for profile in profiles {
            await clearWebsiteData(for: profile.id)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([BrowserProfile].self, from: data) {
            profiles = repairedProfiles(decoded)
        }

        if let raw = UserDefaults.standard.string(forKey: selectedProfileKey),
           let id = UUID(uuidString: raw),
           profiles.contains(where: { $0.id == id }) {
            selectedProfileID = id
        } else {
            selectedProfileID = profiles.first?.id
        }

        persist()
    }

    private func repairedProfiles(_ input: [BrowserProfile]) -> [BrowserProfile] {
        var seen = Set<UUID>()
        var output: [BrowserProfile] = []
        output.reserveCapacity(input.count)

        for var profile in input {
            if seen.contains(profile.id) {
                profile.id = UUID()
            }
            seen.insert(profile.id)
            output.append(profile)
        }

        return output
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: profilesKey)
        }
    }

    private func saveSelectedProfileID() {
        if let selectedProfileID {
            UserDefaults.standard.set(selectedProfileID.uuidString, forKey: selectedProfileKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedProfileKey)
        }
    }
}
