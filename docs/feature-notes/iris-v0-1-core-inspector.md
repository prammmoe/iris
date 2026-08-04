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

## 2026-08-04 - Global Console Gesture API

### Changed
- Added public `IrisGesture` cases for `.shake`, `.hold(minimumDuration:)`, and `.custom`.
- Added `Iris.setGesture(_:)` so apps can configure the console gesture after `Iris.start()`.
- Updated the SwiftUI `.irisConsoleTrigger()` modifier to use the globally selected Iris gesture by default, while still allowing a per-view override.
- Added test coverage for global gesture configuration and reset behavior.

### Stayed The Same
- Shake remains the default gesture.
- `.custom` leaves presentation to explicit calls such as `Iris.present()` or `Iris.present(from:)`.

### Verification
- `swift test` passed with 14 tests.

## 2026-08-04 - Request Body Stream Capture And Visible Headers

### Changed
- Changed default `redactedHeaders` to empty so Iris shows header values by default instead of `<redacted>`.
- Added `httpBodyStream` capture for POST requests that do not expose `httpBody`, including stream-backed bodies commonly produced by networking libraries.
- Replaces the consumed request body stream with a new `InputStream(data:)` before forwarding so inspected requests still reach the server with their body.
- Added tests for visible default headers, optional configured redaction, and stream-backed request body capture/forwarding.

### Stayed The Same
- Apps can still opt into redaction by passing `IrisConfiguration(redactedHeaders:)`.
- Body capture remains bounded by `maxBodyBytes`.

### Verification
- `swift test` passed with 16 tests.

## 2026-08-04 - Console Category And Full-Width Layout

### Changed
- Removed the visible Iris navigation title from the console and replaced the default searchable navigation UI with a custom always-visible search field.
- Reworked the console list into full-width summary and request rows instead of inset grouped list containers.
- Added `IrisTrafficCategory` with Main and Other segmented filtering.
- Added `mainHosts` and `mainBaseURLs` to `IrisConfiguration`; Main contains requests whose host matches the configured base URL host, while Other contains third-party hosts.
- Defaulted the selected category to Other when no main hosts are configured, preventing an empty first console view for apps that have not set a base URL.
- Added test coverage for Main/Other host classification.

### Verification
- `swift test` passed with 17 tests.

## 2026-08-04 - Compact Netfox-Style Rows And Segmented Details

### Changed
- Restyled request rows to a denser Netfox-like layout with a colored left status/time column and compact URL/method/content-type metadata.
- Kept existing row information such as status, duration, content type, URL, method, and response size while reducing vertical space.
- Updated the console header to use a Requests title with compact close and clear icon actions.
- Reworked transaction detail into segmented Info, Request, and Response views.
- Info shows URL, method, status, request/response dates, duration, response size, content type, and error when present.
- Request and Response sections split headers and body under explicit headings.

### Verification
- `swift test` passed with 17 tests.

## 2026-08-04 - Console Presentation Guard And Detail Layout

### Changed
- Added a presentation guard so repeated shake/hold/manual calls cannot present duplicate Iris console controllers.
- Changed console presentation from page sheet to full screen to avoid stacked sheet clipping.
- Added a Close toolbar action for the full-screen console.
- Replaced the transaction detail `List` with a custom `ScrollView` layout with explicit top padding, preventing the first rows from being hidden under the navigation bar.

### Verification
- `swift test` passed with 17 tests.

## 2026-08-04 - UIKit Global Gesture Presentation

### Changed
- Added a UIKit gesture installer so `Iris.setGesture(.shake)` and `Iris.setGesture(.hold)` can open the console without requiring SwiftUI `.irisConsoleTrigger()`.
- Added a `UIWindow.motionEnded` hook for shake presentation, matching Netfox's global UIKit behavior.
- Added automatic long-press recognizer installation on visible and future key windows for `.hold(minimumDuration:)`.
- `Iris.start()` reapplies the selected gesture and `Iris.stop()` removes hold recognizers; gestures only present while Iris runtime is enabled.

### Stayed The Same
- `Iris.present()` and SwiftUI `.irisConsoleTrigger()` remain available for manual or per-view presentation.

### Verification
- `swift test` passed with 17 tests.

## 2026-08-05 - Status-Only List Badge And Visible Detail Sections

### Changed
- Changed the compact request row's colored status box to show only the transaction status code, `ERR`, or running placeholder.
- Moved timestamp and duration into the row metadata area so request context remains visible outside the status box.
- Moved the detail Info/Request/Response segmented control into a top safe-area inset and forced inline detail navigation title behavior on UIKit.
- Applied stack navigation style to the console NavigationView on UIKit to avoid clipped/split navigation presentation.

### Bugs And Fixes
- Bug: Detail content could appear clipped and the Info/Request/Response segmented control could be hidden by the navigation area.
  Fix: Reworked the detail root into a ScrollView with a safe-area top inset for the segmented control.

### Verification
- `swift test` passed with 17 tests.

## 2026-08-05 - Detail Section Cards And Export Actions

### Changed
- Kept the Info, Request, and Response segmented detail control while changing each tab's content into section title plus rounded card containers.
- Added divider-separated field rows inside Info and header sections while preserving the existing field font size and blue label styling.
- Added a top-right share menu with Copy cURL and Export as `.txt` actions.
- Added text export formatting that includes Info, Request headers/body, and Response headers/body.

### Verification
- `swift test` passed with 17 tests.

## 2026-08-05 - SSE Metadata And Console Usability Polish

### Changed
- Reduced detail field and body text size inside Info, Request, and Response section cards.
- Removed the console statistics row from the request list.
- Added long-press copy cURL support on request rows.
- Changed URLProtocol forwarding to a URLSession delegate flow so response status and headers are recorded as soon as they arrive, including long-lived `text/event-stream` SSE requests.
- Running requests now show the received HTTP status code when one is available instead of always showing the running placeholder.
- Reset search text when clearing the console and added coverage that observers continue receiving inserts after clear.
- Added a console navigation bar configurator so top title text remains visible against the app's navigation appearance.

### Verification
- `swift test` passed with 19 tests.
