import Combine
import Foundation
import WebKit

enum ProfileIsolationState: Equatable {
    case checking
    case ready(profileCount: Int)
    case issue(missingStoreCount: Int)
}

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [BrowserProfile] = []
    @Published private(set) var isolationState: ProfileIsolationState = .checking
    @Published var selectedProfileID: UUID? {
        didSet { saveSelectedProfileID() }
    }

    private let profilesKey = "xgizou.profiles.v1"
    private let selectedProfileKey = "xgizou.selectedProfile.v1"

    init() {
        #if DEBUG
        let isUITest = ProcessInfo.processInfo.arguments.contains("--ui-test-seed-profiles")
        if isUITest {
            UserDefaults.standard.removeObject(forKey: profilesKey)
            UserDefaults.standard.removeObject(forKey: selectedProfileKey)
            RiskReductionPolicy.setEnabled(false)
        } else {
            RiskReductionPolicy.bootstrap()
        }
        #else
        RiskReductionPolicy.bootstrap()
        #endif

        load()

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-seed-profiles") {
            seedUITestProfiles()
        }
        #endif

        Task { await refreshIsolationState() }
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

        // Pre-provision the persistent WebKit container for on-device profiles.
        // This keeps every profile tied to one stable, unique data-store identifier
        // before its first navigation.
        if profile.effectiveExecutionMode == .onDevice {
            _ = WKWebsiteDataStore(forIdentifier: profile.id)
        }

        persist()
        Task { await refreshIsolationState() }
    }

    func select(_ profile: BrowserProfile) {
        selectedProfileID = profile.id
    }

    func delete(at offsets: IndexSet) {
        let ids = offsets.compactMap { index in
            profiles.indices.contains(index) ? profiles[index].id : nil
        }

        for index in offsets.sorted(by: >) where profiles.indices.contains(index) {
            profiles.remove(at: index)
        }

        if let selectedProfileID, !profiles.contains(where: { $0.id == selectedProfileID }) {
            self.selectedProfileID = profiles.first?.id
        }
        persist()

        // Remove the underlying named WebKit data stores after the model update so
        // SwiftUI can tear down any WKWebView still using the deleted profile first.
        for id in ids {
            Task { [weak self] in
                await Task.yield()
                guard let self else { return }
                await self.removeWebsiteDataStore(for: id)
                await self.refreshIsolationState()
            }
        }
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
        for profile in profiles where profile.effectiveExecutionMode == .onDevice {
            await clearWebsiteData(for: profile.id)
        }
        await refreshIsolationState()
    }

    func refreshIsolationState() async {
        isolationState = .checking

        let expected = Set(
            profiles
                .filter { $0.effectiveExecutionMode == .onDevice }
                .map(\.id)
        )

        // Ensure every on-device profile owns a persistent named data store.
        for id in expected {
            _ = WKWebsiteDataStore(forIdentifier: id)
        }

        // Creating the named store is the supported way to obtain (or create)
        // the persistent profile container. Avoid enumerating all identifiers:
        // current WebKit releases have had stability issues around that API.
        isolationState = .ready(profileCount: expected.count)
    }

    private func removeWebsiteDataStore(for profileID: UUID) async {
        do {
            try await WKWebsiteDataStore.remove(forIdentifier: profileID)
        } catch {
            // A store can still be in use for a short time while its WKWebView is
            // being released. Clearing all website data is the safe fallback.
            await clearWebsiteData(for: profileID)
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
                var options = profile.effectiveFingerprintOptions
                options.seed = FingerprintOptions.defaults(for: profile.id).seed
                profile.fingerprintOptions = options
            }
            if profile.fingerprintOptions == nil {
                profile.fingerprintOptions = FingerprintOptions.defaults(for: profile.id)
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

    #if DEBUG
    private func seedUITestProfiles() {
        let first = BrowserProfile(name: "UI Profile A")
        let second = BrowserProfile(name: "UI Profile B")
        profiles = [first, second]
        selectedProfileID = first.id
        persist()
    }
    #endif

    private func saveSelectedProfileID() {
        if let selectedProfileID {
            UserDefaults.standard.set(selectedProfileID.uuidString, forKey: selectedProfileKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedProfileKey)
        }
    }
}
