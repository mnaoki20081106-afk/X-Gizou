# X-Gizou

X-Gizou is a SwiftUI + WebKit iOS app that provides persistent, isolated browser profiles for web services such as X.

## Implemented

- Native SwiftUI UI with Home / Profiles / BAN Check / Settings tabs
- Persistent multi-profile browsing on iOS 17+
- A separate `WKWebsiteDataStore(forIdentifier:)` for every profile
- Cookie, LocalStorage, IndexedDB and cache isolation between profiles
- User-Agent presets for Safari/Chrome on iOS, iPadOS, macOS, Windows and Android
- Custom User-Agent input
- Device-profile presets and preview values
- Mobile/desktop content-mode selection based on the chosen profile
- Per-profile and global web-data reset
- In-app X web browsing with back / forward / reload controls
- Native shadowban checker UI backed by the public Shadowban-Test/X service
- Search Suggestion Ban and Search Ban results
- Honest "unknown / not tested" rendering for checks the current upstream backend does not actually perform
- GitHub Actions unsigned IPA build
- Xcode project generation with XcodeGen

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

The selected User-Agent is assigned through `WKWebView.customUserAgent`. Device-profile presets also select WebKit's mobile/desktop content mode.

## Important scope

The device-profile screen is a browser compatibility profile, not an OS-level identity replacement. X-Gizou does **not** bypass or forge Apple/Web-service attestation, Secure Enclave state, hardware identifiers, device-bound credentials, or account enforcement.

This distinction is intentional: the project implements the parts that WebKit officially exposes and that can be built reliably as a normal sideloaded iOS app.

## Public-project / upstream references

The implementation uses native WebKit directly and keeps runtime dependencies minimal. The design was informed by current public projects and upstream sources, especially:

- WebKit's `WKWebsiteDataStore` named-profile implementation
- Shadowban-Test/X public shadowban checking service
- Cybozu WebUI (SwiftUI / WKWebView patterns)
- Kyle Hickinson's SwiftUI-WebView (observable WKWebView patterns)
- XcodeGen for reproducible project generation
- GitHub Actions for repeatable unsigned IPA packaging

See `THIRD_PARTY.md` for the shadowban-service attribution and current limitations.
