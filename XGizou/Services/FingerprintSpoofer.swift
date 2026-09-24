import Foundation
import WebKit

private struct FingerprintRuntimeConfiguration: Encodable {
    let userAgent: String
    let appVersion: String
    let platform: String
    let vendor: String
    let language: String
    let languages: [String]
    let hardwareConcurrency: Int
    let maxTouchPoints: Int
    let deviceMemory: Int?
    let screenWidth: Int
    let screenHeight: Int
    let availWidth: Int
    let availHeight: Int
    let colorDepth: Int
    let pixelDepth: Int
    let pixelRatio: Double
    let timezoneIdentifier: String
    let dateTimezoneOffsetMinutes: Int
    let spoofTimezone: Bool
    let spoofCanvas: Bool
    let spoofWebGL: Bool
    let spoofAudio: Bool
    let webGLVendor: String
    let webGLRenderer: String
    let uaDataPlatform: String?
    let uaDataMobile: Bool?
    let uaDataArchitecture: String?
    let uaDataModel: String?
    let seed: UInt32
}

enum FingerprintSpoofer {
    static func userScript(for profile: BrowserProfile) -> WKUserScript? {
        guard profile.effectiveExecutionMode == .onDevice,
              profile.effectiveFingerprintOptions.enabled else { return nil }

        return WKUserScript(
            source: javascript(for: profile),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }

    static func javascript(for profile: BrowserProfile) -> String {
        let config = runtimeConfiguration(for: profile)
        guard let data = try? JSONEncoder().encode(config),
              let json = String(data: data, encoding: .utf8)
        else {
            return ""
        }

        return """
        (() => {
          'use strict';
          const cfg = \(json);

          const defineValue = (target, property, value) => {
            if (!target) return;
            try {
              Object.defineProperty(target, property, {
                get: () => value,
                configurable: true
              });
              return;
            } catch (_) {}

            try {
              const proto = Object.getPrototypeOf(target);
              if (proto) {
                Object.defineProperty(proto, property, {
                  get: () => value,
                  configurable: true
                });
              }
            } catch (_) {}
          };

          const clampByte = value => Math.max(0, Math.min(255, value));
          const mix32 = input => {
            let x = (input ^ cfg.seed) >>> 0;
            x ^= x >>> 16;
            x = Math.imul(x, 0x7feb352d);
            x ^= x >>> 15;
            x = Math.imul(x, 0x846ca68b);
            x ^= x >>> 16;
            return x >>> 0;
          };

          // Navigator surface
          if (cfg.userAgent) {
            defineValue(navigator, 'userAgent', cfg.userAgent);
            defineValue(navigator, 'appVersion', cfg.appVersion);
          }
          defineValue(navigator, 'platform', cfg.platform);
          defineValue(navigator, 'vendor', cfg.vendor);
          defineValue(navigator, 'language', cfg.language);
          defineValue(navigator, 'languages', Object.freeze(cfg.languages.slice()));
          defineValue(navigator, 'hardwareConcurrency', cfg.hardwareConcurrency);
          defineValue(navigator, 'maxTouchPoints', cfg.maxTouchPoints);
          defineValue(navigator, 'webdriver', false);
          if (cfg.deviceMemory != null) {
            defineValue(navigator, 'deviceMemory', cfg.deviceMemory);
          }

          if (cfg.uaDataPlatform != null) {
            const chromiumVersion = (() => {
              const match = cfg.userAgent.match(/(?:Chrome|Edg)\\/(\\d+)/);
              return match ? match[1] : '146';
            })();
            const browserBrand = cfg.userAgent.includes('Edg/') ? 'Microsoft Edge' : 'Google Chrome';
            const brands = Object.freeze([
              Object.freeze({ brand: 'Chromium', version: chromiumVersion }),
              Object.freeze({ brand: browserBrand, version: chromiumVersion }),
              Object.freeze({ brand: 'Not_A Brand', version: '99' })
            ]);
            const uaData = {
              brands,
              mobile: Boolean(cfg.uaDataMobile),
              platform: cfg.uaDataPlatform,
              getHighEntropyValues: async hints => {
                const values = {
                  brands,
                  mobile: Boolean(cfg.uaDataMobile),
                  platform: cfg.uaDataPlatform,
                  architecture: cfg.uaDataArchitecture || '',
                  bitness: cfg.uaDataArchitecture ? '64' : '',
                  model: cfg.uaDataModel || '',
                  platformVersion: '',
                  uaFullVersion: chromiumVersion + '.0.0.0',
                  fullVersionList: brands.map(item => ({
                    brand: item.brand,
                    version: item.version + '.0.0.0'
                  })),
                  wow64: false
                };
                const output = {};
                for (const key of (hints || [])) {
                  if (Object.prototype.hasOwnProperty.call(values, key)) output[key] = values[key];
                }
                output.brands = brands;
                output.mobile = Boolean(cfg.uaDataMobile);
                output.platform = cfg.uaDataPlatform;
                return output;
              },
              toJSON: () => ({
                brands,
                mobile: Boolean(cfg.uaDataMobile),
                platform: cfg.uaDataPlatform
              })
            };
            defineValue(navigator, 'userAgentData', uaData);
          }

          // Screen/device surface
          defineValue(screen, 'width', cfg.screenWidth);
          defineValue(screen, 'height', cfg.screenHeight);
          defineValue(screen, 'availWidth', cfg.availWidth);
          defineValue(screen, 'availHeight', cfg.availHeight);
          defineValue(screen, 'colorDepth', cfg.colorDepth);
          defineValue(screen, 'pixelDepth', cfg.pixelDepth);
          defineValue(window, 'devicePixelRatio', cfg.pixelRatio);

          // Timezone surface
          if (cfg.spoofTimezone) {
            try {
              const OriginalDateTimeFormat = Intl.DateTimeFormat;
              // Validate the identifier before replacing any APIs.
              const offsetFormatter = new OriginalDateTimeFormat('en-US', {
                timeZone: cfg.timezoneIdentifier, year: 'numeric', month: '2-digit',
                day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit',
                hourCycle: 'h23'
              });
              Object.defineProperty(Date.prototype, 'getTimezoneOffset', {
                value: function() {
                  const timestamp = Date.prototype.getTime.call(this);
                  if (!Number.isFinite(timestamp)) return NaN;
                  const parts = {};
                  for (const part of offsetFormatter.formatToParts(this)) parts[part.type] = part.value;
                  const local = new Date(0);
                  local.setUTCFullYear(Number(parts.year), Number(parts.month) - 1, Number(parts.day));
                  local.setUTCHours(Number(parts.hour), Number(parts.minute), Number(parts.second), 0);
                  return (Math.floor(timestamp / 1000) * 1000 - local.getTime()) / 60000;
                },
                writable: true,
                configurable: true
              });
              const withTimezone = args => {
                const options = args[1] === undefined ? {} : args[1];
                if (options === null) return args; // Preserve the native TypeError.
                if (options.timeZone !== undefined) return args;
                return [args[0], { ...options, timeZone: cfg.timezoneIdentifier }];
              };
              Intl.DateTimeFormat = new Proxy(OriginalDateTimeFormat, {
                apply(target, receiver, args) {
                  return Reflect.apply(target, receiver, withTimezone(args));
                },
                construct(target, args, newTarget) {
                  return Reflect.construct(target, withTimezone(args), newTarget);
                }
              });
            } catch (_) {}
          }

          // WebGL surface
          if (cfg.spoofWebGL) {
            const patchWebGL = proto => {
              if (!proto || typeof proto.getParameter !== 'function') return;
              const original = proto.getParameter;
              try {
                Object.defineProperty(proto, 'getParameter', {
                  value: function(parameter) {
                    if (parameter === 37445) return cfg.webGLVendor;
                    if (parameter === 37446) return cfg.webGLRenderer;
                    return Reflect.apply(original, this, [parameter]);
                  },
                  writable: true,
                  configurable: true
                });
              } catch (_) {}
            };
            patchWebGL(globalThis.WebGLRenderingContext && WebGLRenderingContext.prototype);
            patchWebGL(globalThis.WebGL2RenderingContext && WebGL2RenderingContext.prototype);
          }

          // Audio surface: stable, tiny per-profile perturbation applied once
          // to each AudioBuffer channel.
          if (cfg.spoofAudio && globalThis.AudioBuffer && AudioBuffer.prototype.getChannelData) {
            const originalGetChannelData = AudioBuffer.prototype.getChannelData;
            const touchedChannels = new WeakMap();
            try {
              Object.defineProperty(AudioBuffer.prototype, 'getChannelData', {
                value: function(channel) {
                  const data = originalGetChannelData.call(this, channel);
                  let touched = touchedChannels.get(this);
                  if (!touched) {
                    touched = new Set();
                    touchedChannels.set(this, touched);
                  }
                  if (!touched.has(channel) && data && data.length) {
                    const edits = Math.min(4, data.length);
                    for (let i = 0; i < edits; i++) {
                      const mixed = mix32((Number(channel) * 131 + i * 977 + data.length) >>> 0);
                      const index = mixed % data.length;
                      const delta = (mixed & 1) === 0 ? 0.0000001 : -0.0000001;
                      data[index] = data[index] + delta;
                    }
                    touched.add(channel);
                  }
                  return data;
                },
                writable: true,
                configurable: true
              });
            } catch (_) {}
          }

          // Canvas surface: stable per-profile perturbation. It does not mutate
          // the original canvas; only data returned to callers is changed.
          if (cfg.spoofCanvas && globalThis.HTMLCanvasElement && globalThis.CanvasRenderingContext2D) {
            const originalToDataURL = HTMLCanvasElement.prototype.toDataURL;
            const originalToBlob = HTMLCanvasElement.prototype.toBlob;
            const originalGetImageData = CanvasRenderingContext2D.prototype.getImageData;
            const originalPutImageData = CanvasRenderingContext2D.prototype.putImageData;

            const perturbImageData = (imageData, salt) => {
              const data = imageData && imageData.data;
              if (!data || data.length < 4) return imageData;
              const pixelCount = Math.floor(data.length / 4);
              const edits = Math.min(4, pixelCount);
              for (let i = 0; i < edits; i++) {
                const mixed = mix32((salt + i * 0x9e3779b9) >>> 0);
                const pixel = mixed % pixelCount;
                const channel = mixed % 3;
                const index = pixel * 4 + channel;
                const delta = (mixed & 1) === 0 ? 1 : -1;
                data[index] = clampByte(data[index] + delta);
              }
              return imageData;
            };

            try {
              Object.defineProperty(CanvasRenderingContext2D.prototype, 'getImageData', {
                value: function(sx, sy, sw, sh, settings) {
                  const imageData = originalGetImageData.call(this, sx, sy, sw, sh, settings);
                  const salt = (
                    (Number(sx) | 0) ^
                    ((Number(sy) | 0) << 7) ^
                    ((Number(sw) | 0) << 13) ^
                    ((Number(sh) | 0) << 19)
                  ) >>> 0;
                  return perturbImageData(imageData, salt);
                },
                writable: true,
                configurable: true
              });
            } catch (_) {}

            const noisyClone = canvas => {
              if (!canvas || canvas.width <= 0 || canvas.height <= 0) return null;
              const clone = document.createElement('canvas');
              clone.width = canvas.width;
              clone.height = canvas.height;
              const context = clone.getContext('2d');
              if (!context) return null;

              try {
                context.drawImage(canvas, 0, 0);
                const edits = 4;
                for (let i = 0; i < edits; i++) {
                  const mixedX = mix32((canvas.width + i * 17) >>> 0);
                  const mixedY = mix32((canvas.height + i * 31 + 0x85ebca6b) >>> 0);
                  const x = mixedX % canvas.width;
                  const y = mixedY % canvas.height;
                  const pixel = originalGetImageData.call(context, x, y, 1, 1);
                  const channel = mix32((i + 101) >>> 0) % 3;
                  const delta = (mix32((i + 203) >>> 0) & 1) === 0 ? 1 : -1;
                  pixel.data[channel] = clampByte(pixel.data[channel] + delta);
                  originalPutImageData.call(context, pixel, x, y);
                }
                return clone;
              } catch (_) {
                return null;
              }
            };

            try {
              Object.defineProperty(HTMLCanvasElement.prototype, 'toDataURL', {
                value: function(type, quality) {
                  const clone = noisyClone(this);
                  return clone
                    ? originalToDataURL.call(clone, type, quality)
                    : originalToDataURL.call(this, type, quality);
                },
                writable: true,
                configurable: true
              });
            } catch (_) {}

            if (typeof originalToBlob === 'function') {
              try {
                Object.defineProperty(HTMLCanvasElement.prototype, 'toBlob', {
                  value: function(callback, type, quality) {
                    const clone = noisyClone(this);
                    return clone
                      ? originalToBlob.call(clone, callback, type, quality)
                      : originalToBlob.call(this, callback, type, quality);
                  },
                  writable: true,
                  configurable: true
                });
              } catch (_) {}
            }
          }
        })();
        """
    }

    private static func runtimeConfiguration(for profile: BrowserProfile) -> FingerprintRuntimeConfiguration {
        let device = profile.effectiveDevice
        let options = profile.effectiveFingerprintOptions
        let (width, height) = parseScreen(device.screen)
        let traits = traits(for: profile.devicePreset)
        let clientHints = profile.userAgentPreset.usesChromiumClientHints
        let isMac = profile.devicePreset == .macBookPro

        let ua = profile.effectiveUserAgent
        let appVersion: String
        if ua.hasPrefix("Mozilla/") {
            appVersion = String(ua.dropFirst("Mozilla/".count))
        } else {
            appVersion = ua
        }

        let seed = UInt32(truncatingIfNeeded: options.seed ^ (options.seed >> 32))

        return FingerprintRuntimeConfiguration(
            userAgent: ua,
            appVersion: appVersion,
            platform: device.platform,
            vendor: device.vendor,
            language: options.language,
            languages: options.languages,
            hardwareConcurrency: max(1, device.cpuCores),
            maxTouchPoints: max(0, device.touchPoints),
            deviceMemory: clientHints ? (traits.deviceMemory ?? 8) : nil,
            screenWidth: width,
            screenHeight: height,
            availWidth: width,
            availHeight: height,
            colorDepth: traits.colorDepth,
            pixelDepth: traits.colorDepth,
            pixelRatio: traits.pixelRatio,
            timezoneIdentifier: options.timezoneIdentifier,
            dateTimezoneOffsetMinutes: options.dateTimezoneOffsetMinutes,
            spoofTimezone: options.spoofTimezone,
            spoofCanvas: options.spoofCanvas,
            spoofWebGL: options.spoofWebGL,
            spoofAudio: options.spoofAudio,
            webGLVendor: traits.webGLVendor,
            webGLRenderer: traits.webGLRenderer,
            uaDataPlatform: clientHints ? (isMac ? "macOS" : traits.uaDataPlatform) : nil,
            uaDataMobile: clientHints ? (traits.uaDataMobile ?? false) : nil,
            uaDataArchitecture: clientHints ? (isMac ? "arm" : traits.uaDataArchitecture) : nil,
            uaDataModel: clientHints ? (traits.uaDataModel ?? "") : nil,
            seed: seed
        )
    }

    private static func parseScreen(_ raw: String) -> (Int, Int) {
        let normalized = raw
            .replacingOccurrences(of: "×", with: "x")
            .replacingOccurrences(of: " ", with: "")
        let parts = normalized.split(separator: "x", maxSplits: 1)
        guard parts.count == 2,
              let width = Int(parts[0]),
              let height = Int(parts[1]),
              width > 0,
              height > 0
        else {
            return (393, 852)
        }
        return (width, height)
    }

    private static func traits(for preset: DevicePreset) -> (
        pixelRatio: Double,
        colorDepth: Int,
        deviceMemory: Int?,
        webGLVendor: String,
        webGLRenderer: String,
        uaDataPlatform: String?,
        uaDataMobile: Bool?,
        uaDataArchitecture: String?,
        uaDataModel: String?
    ) {
        switch preset {
        case .iPhone16Pro:
            return (3.0, 32, nil, "Apple Inc.", "Apple GPU", nil, nil, nil, nil)
        case .iPhone15:
            return (3.0, 32, nil, "Apple Inc.", "Apple GPU", nil, nil, nil, nil)
        case .iPadPro13:
            return (2.0, 32, nil, "Apple Inc.", "Apple GPU", nil, nil, nil, nil)
        case .macBookPro:
            return (2.0, 30, nil, "Apple Inc.", "Apple M3", nil, nil, nil, nil)
        case .windowsPC:
            return (1.0, 24, 8, "Google Inc. (NVIDIA)", "ANGLE (NVIDIA, NVIDIA GeForce RTX 3060 Direct3D11)", "Windows", false, "x86", "")
        case .pixel8:
            return (2.625, 24, 8, "Google Inc. (ARM)", "ANGLE (ARM, Mali-G715, OpenGL ES 3.2)", "Android", true, "arm", "Pixel 8")
        case .custom:
            return (3.0, 32, nil, "Apple Inc.", "Apple GPU", nil, nil, nil, nil)
        }
    }
}
