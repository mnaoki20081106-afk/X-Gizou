import Foundation

@main
struct ProfileConsistencyTests {
    static func configuration(_ profile: BrowserProfile) throws -> [String: Any] {
        let script = FingerprintSpoofer.javascript(for: profile)
        let json = script.components(separatedBy: "const cfg = ")[1].components(separatedBy: ";\n")[0]
        return try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
    }

    static func main() throws {
        var profile = BrowserProfile(devicePreset: .iPhone16Pro)
        precondition(!profile.effectiveFingerprintOptions.enabled)
        precondition(!profile.effectiveFingerprintOptions.spoofCanvas)
        precondition(!profile.effectiveFingerprintOptions.spoofWebGL)
        precondition(!profile.effectiveFingerprintOptions.spoofAudio)
        precondition(!profile.effectiveFingerprintOptions.spoofTimezone)
        precondition(profile.effectiveUserAgent.isEmpty)
        precondition(FingerprintSpoofer.userScript(for: profile) == nil)
        let originalSeed = profile.effectiveFingerprintOptions.seed
        var enabled = profile.effectiveFingerprintOptions
        enabled.enabled = true
        profile.fingerprintOptions = enabled
        precondition(FingerprintSpoofer.userScript(for: profile) != nil)
        profile.selectUserAgent(.chromeIOS)
        precondition(profile.devicePreset == .iPhone16Pro)
        profile.selectUserAgent(.chromeMac)
        precondition(profile.devicePreset == .macBookPro)
        precondition(profile.effectiveDevice.vendor == "Google Inc.")
        let mac = try configuration(profile)
        precondition(mac["uaDataPlatform"] as? String == "macOS")
        precondition(mac["deviceMemory"] as? Int == 8)
        profile.selectDevice(.pixel8)
        precondition(profile.userAgentPreset == .chromeAndroid)
        profile.selectDevice(.windowsPC)
        precondition(profile.userAgentPreset == .chromeWindows)
        profile.selectUserAgent(.edgeWindows)
        precondition(profile.devicePreset == .windowsPC)
        profile.selectDevice(.iPadPro13)
        precondition(profile.userAgentPreset == .safariIPad)
        let safari = try configuration(profile)
        precondition(safari["uaDataPlatform"] == nil)
        precondition(safari["deviceMemory"] == nil)
        precondition(profile.effectiveFingerprintOptions.seed == originalSeed)

        profile.customUserAgent = "Custom test UA"
        profile.selectUserAgent(.custom)
        profile.selectDevice(.windowsPC)
        precondition(profile.userAgentPreset == .custom)
        precondition(profile.effectiveUserAgent == "Custom test UA")
        profile.selectDevice(.custom)
        profile.customDevice.vendor = "My vendor"
        profile.selectUserAgent(.chromeMac)
        precondition(profile.devicePreset == .custom)
        precondition(profile.effectiveDevice.vendor == "My vendor")
        let encoded = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(BrowserProfile.self, from: encoded)
        precondition(decoded == profile)
        profile.executionMode = .remote
        profile.remoteBrowserAddress = "https://browser.example.ts.net/"
        precondition(profile.remoteBrowserURL != nil)
        precondition(profile.remoteBrowserService == "browser.example.ts.net:443")
        var conflicting = profile
        conflicting.id = UUID()
        conflicting.remoteBrowserAddress = "https://BROWSER.example.ts.net/another-path/"
        precondition(conflicting.remoteBrowserService == profile.remoteBrowserService)
        conflicting.remoteBrowserAddress = "https://browser.example.ts.net:8444/"
        precondition(conflicting.remoteBrowserService != profile.remoteBrowserService)
        precondition(FingerprintSpoofer.userScript(for: profile) == nil)
        for invalid in ["http://server/", "https://user:pass@server/", "https://server/?token=secret", "https://server/#token", "https://"] {
            profile.remoteBrowserAddress = invalid
            precondition(profile.remoteBrowserURL == nil)
        }
        var oldJSON = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        oldJSON.removeValue(forKey: "executionMode")
        oldJSON.removeValue(forKey: "remoteBrowserAddress")
        let legacy = try JSONDecoder().decode(BrowserProfile.self, from: JSONSerialization.data(withJSONObject: oldJSON))
        precondition(legacy.effectiveExecutionMode == .onDevice)
        print("Profile selection, runtime configuration, custom values and persistence passed")
    }
}
