import Foundation

enum UserAgentPreset: String, CaseIterable, Codable, Identifiable {
    case safariIOS
    case chromeIOS
    case safariIPad
    case safariMac
    case chromeMac
    case chromeWindows
    case edgeWindows
    case chromeAndroid
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .safariIOS: "Safari (iOS)"
        case .chromeIOS: "Chrome (iOS)"
        case .safariIPad: "Safari (iPad)"
        case .safariMac: "Safari (macOS)"
        case .chromeMac: "Chrome (macOS)"
        case .chromeWindows: "Chrome (Windows)"
        case .edgeWindows: "Edge (Windows)"
        case .chromeAndroid: "Chrome (Android)"
        case .custom: "カスタム"
        }
    }

    var userAgent: String {
        switch self {
        case .safariIOS:
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1"
        case .chromeIOS:
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/146.0.7680.40 Mobile/15E148 Safari/604.1"
        case .safariIPad:
            "Mozilla/5.0 (iPad; CPU OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1"
        case .safariMac:
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"
        case .chromeMac:
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"
        case .chromeWindows:
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"
        case .edgeWindows:
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36 Edg/146.0.0.0"
        case .chromeAndroid:
            "Mozilla/5.0 (Linux; Android 15; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Mobile Safari/537.36"
        case .custom:
            ""
        }
    }
}

struct DeviceDescriptor: Codable, Hashable {
    var platform: String
    var screen: String
    var cpuCores: Int
    var touchPoints: Int
    var vendor: String

    static let customDefault = DeviceDescriptor(
        platform: "iPhone",
        screen: "393 x 852",
        cpuCores: 6,
        touchPoints: 5,
        vendor: "Apple Computer, Inc."
    )
}

enum DevicePreset: String, CaseIterable, Codable, Identifiable {
    case iPhone16Pro
    case iPhone15
    case iPadPro13
    case macBookPro
    case windowsPC
    case pixel8
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iPhone16Pro: "iPhone 16 Pro"
        case .iPhone15: "iPhone 15"
        case .iPadPro13: "iPad Pro 13\""
        case .macBookPro: "MacBook Pro"
        case .windowsPC: "Windows PC"
        case .pixel8: "Android (Pixel 8)"
        case .custom: "カスタム"
        }
    }

    var descriptor: DeviceDescriptor {
        switch self {
        case .iPhone16Pro:
            DeviceDescriptor(platform: "iPhone", screen: "402 x 874", cpuCores: 6, touchPoints: 5, vendor: "Apple Computer, Inc.")
        case .iPhone15:
            DeviceDescriptor(platform: "iPhone", screen: "393 x 852", cpuCores: 6, touchPoints: 5, vendor: "Apple Computer, Inc.")
        case .iPadPro13:
            DeviceDescriptor(platform: "iPad", screen: "1032 x 1376", cpuCores: 9, touchPoints: 5, vendor: "Apple Computer, Inc.")
        case .macBookPro:
            DeviceDescriptor(platform: "MacIntel", screen: "1512 x 982", cpuCores: 10, touchPoints: 0, vendor: "Apple Computer, Inc.")
        case .windowsPC:
            DeviceDescriptor(platform: "Win32", screen: "1920 x 1080", cpuCores: 8, touchPoints: 0, vendor: "Google Inc.")
        case .pixel8:
            DeviceDescriptor(platform: "Linux armv8l", screen: "412 x 915", cpuCores: 9, touchPoints: 5, vendor: "Google Inc.")
        case .custom:
            .customDefault
        }
    }

    var prefersDesktopContent: Bool {
        switch self {
        case .macBookPro, .windowsPC:
            true
        default:
            false
        }
    }
}

struct BrowserProfile: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var userAgentPreset: UserAgentPreset
    var customUserAgent: String
    var devicePreset: DevicePreset
    var customDevice: DeviceDescriptor
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String = "新しいプロフィール",
        userAgentPreset: UserAgentPreset = .safariIOS,
        customUserAgent: String = "",
        devicePreset: DevicePreset = .iPhone15,
        customDevice: DeviceDescriptor = .customDefault,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.userAgentPreset = userAgentPreset
        self.customUserAgent = customUserAgent
        self.devicePreset = devicePreset
        self.customDevice = customDevice
        self.createdAt = createdAt
    }

    var effectiveUserAgent: String {
        if userAgentPreset == .custom {
            customUserAgent.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            userAgentPreset.userAgent
        }
    }

    var effectiveDevice: DeviceDescriptor {
        devicePreset == .custom ? customDevice : devicePreset.descriptor
    }
}
