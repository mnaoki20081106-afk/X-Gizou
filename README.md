# X-Gizou

X-Gizou is a SwiftUI + WebKit iOS app that provides persistent, isolated browser profiles for web services such as X.

## Implemented

- Native SwiftUI UI with Home / Profiles / Settings tabs
- Persistent multi-profile browsing on iOS 17+
- A separate `WKWebsiteDataStore(forIdentifier:)` for every profile
- Cookie, LocalStorage, IndexedDB and cache isolation between profiles
- User-Agent presets for Safari/Chrome on iOS, iPadOS, macOS, Windows and Android
- Custom User-Agent input
- Device-profile presets and preview values
- Mobile/desktop content-mode selection based on the chosen profile
- Per-profile and global web-data reset
- In-app X web browsing with back / forward / reload controls
- GitHub Actions unsigned IPA build
- Xcode project generation with XcodeGen

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
- Cybozu WebUI (SwiftUI / WKWebView patterns)
- Kyle Hickinson's SwiftUI-WebView (observable WKWebView patterns)
- XcodeGen for reproducible project generation
- GitHub Actions for repeatable unsigned IPA packaging

No source from those projects is vendored into this repository.
