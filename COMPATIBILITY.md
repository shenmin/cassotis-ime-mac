# Compatibility

Version 1.0.0 (build 3) targets Apple Silicon and macOS 14 or later. Build and desktop validation used macOS 27.0.1, an Apple M2 Pro, Xcode 27.0 and Free Pascal 3.2.2.

| Environment | Validation status |
| --- | --- |
| arm64 / macOS 27.0.1 | Native build, model execution, installation and desktop input tested |
| macOS 14 / 15 | Deployment target and API compatibility; execution on these systems has not been verified |
| Intel / Universal 2 | Not a release target |
| NSTextView and NSTextField | IMK composition and Chinese commit tested |
| WKWebView input | Composition events and Chinese commit tested |
| NSSecureTextField | ASCII input without IMK composition tested |
| Chrome 154, Electron 44 and Terminal | Actual input and switching between applications tested |

The frontend uses public InputMethodKit and AppKit APIs. Normal operation does not require Accessibility, Input Monitoring or event-posting permission.

Qualification includes normal and immediate-input cold launches through AppKit, WebKit and secure text fields, plus twelve browser/Terminal handoffs. Installed UI checks cover three-row paging, active-row digits, cross-row clicks, Tab completion, punctuation, mode feedback and settings autosave. Installation checks cover upgrade and download quarantine on the existing test host; this is not a clean-machine qualification.

On the macOS 27.0.1 test host, the automatic enablement request opens Keyboard Settings without showing a consent dialog. For first installation, use System Settings → Keyboard → Text Input → Edit → + → Chinese, Simplified → 言泉输入法 → Add, then return to the installer. The installer verifies the actual enabled state before reporting completion. Upgrades retain an already enabled input source. Automatic consent worked in the v0.1.0 macOS 26 qualification; it has not been qualified on macOS 27.

The candidate panel follows the composition start, stays within its display's visible area and opens above the input line when there is insufficient space below. It does not take input focus and supports full-screen auxiliary windows. Placement has been checked at screen edges and across displays with negative coordinates. The mode bubble defaults above the caret and avoids nearby system cursor indicators when their window bounds are available.

When a client cannot provide surrounding text, composition continues with an empty external context. Failed or timed-out engine requests preserve the last visible composition and close the connection so a later request cannot consume a stale reply. If model loading fails, base-dictionary input remains available; logs identify model failures.

Sleep/wake behavior and other third-party application combinations require further runtime validation. Published measurements and their scope are described in [BENCHMARK.md](BENCHMARK.md).

Pinyin diagnostics highlight invalid ranges in the footer beneath the candidate rows, alongside any Tab completion and the logo. The input method also supplies marked-text color attributes, but InputMethodKit or the receiving application may replace inline colors with system styling. The candidate diagnostic remains visible, including when invalid input has no candidates, and clears when the Pinyin is corrected.
