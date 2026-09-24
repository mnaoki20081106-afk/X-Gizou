# Third-party services and references

## Shadowban-Test/X

X-Gizou's native shadowban-check screen interoperates with the public API hosted at `https://shadowban.lami.zip/`.

The service's source code is published at `https://github.com/Shadowban-Test/X` under GNU GPL-3.0.

X-Gizou does **not** vendor or copy the GPL-3.0 TypeScript implementation into the iOS binary. The app implements its own Swift client for the public HTTP API and attributes the upstream project in the UI and documentation.

The upstream API currently implements checks for:

- Search Suggestion Ban
- Search Ban

The upstream route currently returns placeholder false values for Ghost Ban and Reply Deboosting without performing those checks. X-Gizou intentionally renders those false values as **unknown / not tested** rather than incorrectly reporting them as clean.

Because this service depends on X's non-public web behavior, upstream API changes or X changes can affect the result or availability.


## dvm-sh/browser-fingerprint-spoofer

X-Gizou's browser-fingerprint layer was informed by the public project at `https://github.com/dvm-sh/browser-fingerprint-spoofer`, which is published under the MIT License.

The reference project demonstrates common browser fingerprint surfaces such as navigator properties, screen metrics, Canvas, WebGL and timezone values. X-Gizou does not vendor its extension code; the iOS implementation is an independent Swift + WKUserScript implementation adapted to WebKit.

Copyright (c) 2025 Devansh Mishra. See the upstream MIT license for its terms.
