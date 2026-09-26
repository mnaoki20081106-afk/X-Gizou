# X-Gizou

X-Gizou is a SwiftUI + WebKit iOS app that provides persistent, isolated browser profiles for X.

## Implemented

- Native SwiftUI UI with Home / Profiles / Settings as the primary bottom tabs; BAN Check and Environment remain available from Settings
- Persistent multi-profile browsing on iOS 17+
- A separate `WKWebsiteDataStore(forIdentifier:)` for every profile
- A separate `WKProcessPool` per active profile browser
- Cookie, LocalStorage, IndexedDB and cache isolation between profiles
- User-Agent presets for Safari/Chrome on iOS, iPadOS, macOS, Windows and Android
- Custom User-Agent input per profile
- Browser-visible device fingerprint profiles for iPhone, iPad, macOS, Windows and Android
- Navigator spoofing: platform, vendor, language, languages, hardwareConcurrency, maxTouchPoints, webdriver and deviceMemory where appropriate
- Screen spoofing: width, height, available size, color depth and devicePixelRatio
- WebGL vendor/renderer spoofing
- Stable per-profile Canvas and Audio fingerprint perturbation
- Timezone and timezone-offset spoofing
- Chromium-style userAgentData surface for Windows/Android Chromium presets
- Browser-environment diagnostics showing the values the configured WKWebView exposes to a web page
- Safety Mode enabled by default
- Safety Center showing active risk-reduction controls
- Per-profile UA and content mode in Release builds
- External top-level links opened outside the X WebView while Safety Mode is enabled
- Per-profile and global web-data reset
- In-app X web browsing with back / forward / reload controls
- Native shadowban checker UI backed by the public Shadowban-Test/X service
- Search Suggestion Ban and Search Ban results
- Honest "unknown / not tested" rendering for checks the current upstream backend does not actually perform
- GitHub Actions unsigned IPA build
- Xcode project generation with XcodeGen

## Browser profiles

Each X profile has its own persistent WebKit website-data partition. That isolates login cookies, LocalStorage, IndexedDB and cache from the other profiles, so multiple X sessions can coexist without sharing the same browser-data container.

New on-device profiles use WebKit's actual browser values by default: no custom User-Agent, no fingerprint script and no Canvas/Audio noise. Advanced manual controls are collapsed in the profile editor. Enabling manual changes injects a `WKUserScript` at document start in the main frame and subframes. Existing saved profiles retain their settings unless the user turns manual changes off.

Optional Canvas and Audio overrides are off for new profiles. When explicitly enabled, they use a stable profile-specific seed rather than new random noise on every API call.

The Environment tab measures the configured browser-visible values, including User-Agent, platform, vendor, language, CPU count, touch points, device memory, screen size, pixel ratio, timezone, WebGL vendor/renderer and a Canvas signature.

## Safety Mode

Safety Mode is enabled by default and locked ON in Release builds. Its purpose is to reduce accidental account-risk signals caused by inconsistent browser configuration or profile-data mixing without adding day-to-day UI friction.

When enabled:

- each X profile keeps its own persistent WebKit data store
- each active profile browser uses a separate WebKit process pool
- top-level navigation away from X/Twitter opens in the system browser instead of reusing the X profile WebView
- x:// and twitter:// cross-app escapes are blocked inside the protected X session
- duplicate profile identifiers are repaired on load so two profiles cannot accidentally reuse the same WebKit data-store identity
- no automatic posting, following, liking, reposting, or bulk action features are included

UA and browser-fingerprint profiles are available in normal Release builds. Safety Mode continues to handle profile-data separation and external navigation; it does not disable per-profile fingerprint settings.

Safety Mode does **not** guarantee that an account will never be suspended. It does not disguise a suspended device/account as a new one, bypass X enforcement, forge Apple/X attestation, or replace hardware identifiers. Those are different mechanisms from normal WebKit profile isolation.

## Shadowban check

The BAN Check tab sends only the entered X username to the public checker endpoint hosted at:

`https://shadowban.lami.zip/api/test`

Upstream source:

`https://github.com/Shadowban-Test/X`

The upstream project is GPL-3.0. X-Gizou does not vendor its TypeScript source; it contains an independently implemented Swift HTTP client for the public API. See `THIRD_PARTY.md` for details.

The current upstream backend actively checks Search Suggestion Ban and Search Ban. Its current route does not implement Ghost Ban or Reply Deboosting checks and returns placeholder false values for those fields. X-Gizou therefore shows those false values as **未判定** instead of incorrectly calling the account clean.

These results are indicators based on externally observable X behavior, not official X account-status information.

## Build

The repository intentionally keeps the generated `.xcodeproj` out of source control.

Local build:

```bash
brew install xcodegen
xcodegen generate
open XGizou.xcodeproj
```

GitHub Actions:

1. Open **Actions**
2. Select **Build IPA**
3. Run the workflow, or push to `main` / a `build/**` branch
4. Download the **XGizou-unsigned-ipa** artifact

The workflow builds without signing and packages `XGizou.app` as `XGizou-unsigned.ipa`. A sideloading/signing tool still has to sign it for the target device.

## Architecture

Each `BrowserProfile` owns a stable UUID. That UUID is passed to WebKit's named persistent data-store API:

```swift
configuration.websiteDataStore = WKWebsiteDataStore(forIdentifier: profile.id)
```

This gives each profile an independent persistent website-data partition while letting the same profile reopen its session after app relaunch.

A fresh `WKProcessPool` is also assigned to each active profile browser instance.

In DEBUG builds, Safety Mode can be disabled for compatibility testing. Release IPA builds lock Safety Mode ON for session and navigation protections, while UA and fingerprint values continue to come from the selected profile.

## Important scope

X-Gizou implements browser-layer session isolation and diagnostics that a normal sideloaded iOS app can reliably provide. It does **not** bypass or forge Apple/Web-service attestation, Secure Enclave state, hardware identifiers, device-bound credentials, or account enforcement.

## Public-project / upstream references

The implementation uses native WebKit directly and keeps runtime dependencies minimal. The design was informed by current public projects and upstream sources, especially:

- WebKit's `WKWebsiteDataStore` named-profile implementation
- dvm-sh/browser-fingerprint-spoofer (MIT) as a design reference for common browser fingerprint surfaces; X-Gizou implements its own Swift/WKUserScript layer
- Shadowban-Test/X public shadowban checking service
- Cybozu WebUI (SwiftUI / WKWebView patterns)
- Kyle Hickinson's SwiftUI-WebView (observable WKWebView patterns)
- XcodeGen for reproducible project generation
- GitHub Actions for repeatable unsigned IPA packaging

See `THIRD_PARTY.md` for the shadowban-service attribution and current limitations.


## Runtime verification and limits

Run `node --test Tests/fingerprint-runtime.test.cjs` to check the injected JavaScript's navigator fields, omitted optional values, timezone/DST handling, WebGL forwarding, stable Canvas/Audio output, and optional feature toggles. The same checks run before the Release IPA build. These isolated JavaScript tests do not replace an iOS device test.

Timezone overrides apply to `Date.getTimezoneOffset` and default `Intl.DateTimeFormat` formatting. Explicit formatter timezones are preserved; legacy Date local getters/string methods are not changed. Browser workers, CSS media queries, viewport dimensions, fonts, network client-hint headers, and the underlying WebKit engine are not emulated. This is a browser-value override, not complete emulation of another operating system or browser.

## Execution modes

Profiles can choose on-device WebKit or an independent remote browser environment. Existing saved profiles default to on-device mode. Remote mode displays a private HTTPS remote-control client, without local UA/fingerprint injection. X runs in the server browser. The included `remote/compose.yaml` uses an actual Linux Chromium session, persistent storage, and a loopback-only listener intended for Tailscale Serve. Chromium always launches X in application mode from `https://x.com/` with browser chrome removed and a portrait 393×852 remote display so X uses its responsive mobile layout. The iOS shell keeps a compact native header with the selected profile name and reload control, plus a persistent three-item bottom bar for Home / Profiles / Settings. BAN Check and Environment are reachable from Settings. See [remote setup](remote/README.md).

For independent remote profiles, X-Gizou now requires a different hostname per profile and rejects reuse of the same host even when the port or path differs. The intended layout is one dedicated VM/host per profile, so browser process, persistent browser storage, OS environment and network egress are not shared by the app profiles. Remote mode still requires provisioned servers; adding a URL does not create one, and local data deletion does not delete server-side cookies. Remote diagnostics are explicitly unavailable in the local Environment tab.

On-device UA/device preset selection synchronizes compatible preset families while preserving custom input. Browser vendor and Chromium client hints are derived from the selected browser only in manual mode. Canvas/Audio seeds remain stable across edits. Remote profiles use the server browser's actual environment.
