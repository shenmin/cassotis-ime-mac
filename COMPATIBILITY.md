# Compatibility

Version 0.1.0 targets Apple Silicon and macOS 14 or later. Build and desktop validation used macOS 26.6.2, an Apple M2 Pro, Xcode 26.6 and Free Pascal 3.2.2.

| Environment | Validation status |
| --- | --- |
| arm64 / macOS 26.6.2 | Native build, model execution, installation and desktop input tested |
| macOS 14 / 15 | Deployment target and API compatibility; execution on these systems has not been verified |
| Intel / Universal 2 | Not a release target |
| NSTextView and NSTextField | IMK composition and Chinese commit tested |
| WKWebView input | Composition events and Chinese commit tested |
| NSSecureTextField | ASCII input without IMK composition tested |
| Chrome, Electron and Terminal | Actual input, cold starts and switching between applications tested |

The frontend uses public InputMethodKit and AppKit APIs. Normal operation does not require Accessibility, Input Monitoring or event-posting permission.

The candidate panel follows the composition start, stays within its display's visible area and opens above the input line when there is insufficient space below. It does not take input focus and supports full-screen auxiliary windows. Placement has been checked at screen edges and across displays with negative coordinates. The mode bubble defaults above the caret and avoids nearby system cursor indicators when their window bounds are available.

When a client cannot provide surrounding text, composition continues with an empty external context. Failed or timed-out engine requests preserve the last visible composition and close the connection so a later request cannot consume a stale reply. If model loading fails, base-dictionary input remains available; logs identify model failures.

Sleep/wake behavior and other third-party application combinations require further runtime validation. Published measurements and their scope are described in [BENCHMARK.md](BENCHMARK.md).
