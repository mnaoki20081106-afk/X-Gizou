import Foundation
import WebKit

struct BrowserEnvironmentSnapshot: Decodable, Equatable {
    let userAgent: String
    let platform: String
    let vendor: String
    let language: String
    let languages: String
    let hardwareConcurrency: String
    let maxTouchPoints: String
    let deviceMemory: String
    let screen: String
    let pixelRatio: String
    let timezone: String
    let timezoneOffset: String
    let webdriver: String
    let webGLVendor: String
    let webGLRenderer: String
    let canvasSignature: String
    let uaDataPlatform: String
}

enum BrowserEnvironmentProbeError: LocalizedError {
    case invalidResult

    var errorDescription: String? {
        switch self {
        case .invalidResult:
            return "ブラウザ環境の計測結果を読み取れませんでした。"
        }
    }
}

@MainActor
enum BrowserEnvironmentProbe {
    static func measure(profile: BrowserProfile) async throws -> BrowserEnvironmentSnapshot {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore(forIdentifier: profile.id)
        configuration.processPool = WKProcessPool()

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        preferences.preferredContentMode = RiskReductionPolicy.preferredContentMode(for: profile)
        configuration.defaultWebpagePreferences = preferences

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = RiskReductionPolicy.effectiveUserAgent(for: profile)

        let probe = """
        (() => {
          const readWebGL = () => {
            try {
              const canvas = document.createElement('canvas');
              const gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');
              if (!gl) return { vendor: 'unavailable', renderer: 'unavailable' };
              const ext = gl.getExtension('WEBGL_debug_renderer_info');
              if (!ext) return { vendor: 'masked', renderer: 'masked' };
              return {
                vendor: String(gl.getParameter(ext.UNMASKED_VENDOR_WEBGL) || ''),
                renderer: String(gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) || '')
              };
            } catch (_) {
              return { vendor: 'error', renderer: 'error' };
            }
          };

          const canvasSignature = () => {
            try {
              const canvas = document.createElement('canvas');
              canvas.width = 240;
              canvas.height = 60;
              const ctx = canvas.getContext('2d');
              if (!ctx) return 'unavailable';
              ctx.textBaseline = 'top';
              ctx.font = '17px Arial';
              ctx.fillStyle = '#f60';
              ctx.fillRect(8, 8, 122, 34);
              ctx.fillStyle = '#069';
              ctx.fillText('X-Gizou fingerprint', 12, 15);
              const value = canvas.toDataURL();
              let hash = 2166136261 >>> 0;
              for (let i = 0; i < value.length; i++) {
                hash ^= value.charCodeAt(i);
                hash = Math.imul(hash, 16777619);
              }
              return (hash >>> 0).toString(16).padStart(8, '0');
            } catch (_) {
              return 'error';
            }
          };

          const webgl = readWebGL();
          return JSON.stringify({
            userAgent: String(navigator.userAgent || ''),
            platform: String(navigator.platform || ''),
            vendor: String(navigator.vendor || ''),
            language: String(navigator.language || ''),
            languages: Array.isArray(navigator.languages) ? navigator.languages.join(', ') : '',
            hardwareConcurrency: String(navigator.hardwareConcurrency ?? 'unknown'),
            maxTouchPoints: String(navigator.maxTouchPoints ?? 'unknown'),
            deviceMemory: String(navigator.deviceMemory ?? 'unsupported'),
            screen: String(screen.width) + ' × ' + String(screen.height),
            pixelRatio: String(window.devicePixelRatio ?? 'unknown'),
            timezone: String(Intl.DateTimeFormat().resolvedOptions().timeZone || 'unknown'),
            timezoneOffset: String(new Date().getTimezoneOffset()),
            webdriver: String(Boolean(navigator.webdriver)),
            webGLVendor: webgl.vendor,
            webGLRenderer: webgl.renderer,
            canvasSignature: canvasSignature(),
            uaDataPlatform: String(navigator.userAgentData?.platform || 'unsupported')
          });
        })()
        """

        let script = profile.effectiveFingerprintOptions.enabled
            ? FingerprintSpoofer.javascript(for: profile) + "\n" + probe
            : probe

        let result = try await webView.evaluateJavaScript(script)
        guard let json = result as? String,
              let data = json.data(using: .utf8)
        else {
            throw BrowserEnvironmentProbeError.invalidResult
        }

        do {
            return try JSONDecoder().decode(BrowserEnvironmentSnapshot.self, from: data)
        } catch {
            throw BrowserEnvironmentProbeError.invalidResult
        }
    }
}
