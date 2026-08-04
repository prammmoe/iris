# Iris v0.1 Core Inspector Implementation Notes

Branch: `main`

## 2026-08-04 - Core URLSession Inspector Slice

### Changed
- Added the Iris v0.1 vertical slice: public start/stop/instrument APIs, URLProtocol interception, in-memory transaction store, body formatting, and SwiftUI console/detail views.
- Added default header redaction for authorization, cookies, API keys, and signatures, plus case-normalized ignored hosts.
- Added macOS 14 as a package platform so SwiftPM tests can compile the SwiftUI/concurrency code locally while preserving iOS 15 support.
- Replaced the placeholder test with 10 Swift Testing cases for URLProtocol filtering, handled request rejection, ignored hosts, redaction, body truncation, store bounds, clear, successful capture, failed capture, and concurrent inserts.

### Stayed The Same
- Iris still requires explicit `Iris.instrument(configuration)` before creating the `URLSession`.
- The forwarding session still uses no custom protocol classes by default to avoid recursive interception in production.

### Bugs And Fixes
- Bug: `swift test` first failed because SwiftPM compiled for an old default macOS deployment target while the package uses Swift concurrency and SwiftUI.
  Fix: Added `.macOS(.v14)` to `Package.swift`.
- Bug: macOS test builds rejected iOS-only SwiftUI navigation toolbar modifiers.
  Fix: Used platform-neutral toolbar/navigation modifiers in the console UI.

### Verification
- `swift test` passed with 10 tests.

## 2026-08-04 - In-App Console Trigger And Status Rows

### Changed
- Added a SwiftUI `.irisConsoleTrigger(...)` modifier with shake and long-press trigger options for opening the in-app console.
- Added top-most UIKit presenter lookup so Iris can present the console without requiring a caller-owned view controller.
- Updated the console list rows with a left status badge, timestamp, method, host/path, duration, and response byte count.
- Added status presentation logic for success, running, and error transactions; 2xx/3xx responses map to success, while 4xx/5xx and failed requests map to error.
- Added test coverage for status text and status kind mapping.

### Stayed The Same
- Manual presentation through `Iris.present(from:)` remains available.
- The console still reads from the same in-memory transaction stream.

### Verification
- `swift test` passed with 11 tests.

## 2026-08-04 - Netfox-Style URLSession Auto-Injection

### Changed
- Added Netfox-style `URLSessionConfiguration` swizzling for `.default`, `.ephemeral`, and the `protocolClasses` setter so `Iris.start()` injects `IrisURLProtocol` into new configurations automatically.
- Kept `URLProtocol.registerClass` alongside configuration injection to match Netfox's broader registration strategy.
- Added URLSessionTask-based `canInit(with:)` handling and WebSocket exclusion.
- Preserved `Iris.instrument(_:)` as an explicit fallback, but normal URLSession usage no longer needs it after `Iris.start()`.
- Added tests proving a session created from `.ephemeral` is captured without calling `Iris.instrument`, and proving `.default`/`.ephemeral` receive only one Iris protocol entry.

### Stayed The Same
- `IrisURLProtocol` still uses its internal handled marker to prevent recursive interception.
- `Iris.stop()` still disables capture through runtime state and unregisters the protocol class.

### Verification
- `swift test` passed with 13 tests.
