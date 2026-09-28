# Changelog

## 0.2.0 (build 2)

- Align the shared engine, production models and dictionaries with Windows / Cassotis Lexicon v1.29.0.
- Add conservative short-word context reranking with shared encoder segments and a 30 ms result budget, preserving learned preferences and safe abstention.
- Improve literary paths, bounded classical phrase recovery, decreasing long-sentence prefixes, fuzzy character ordering and evidence-backed compound candidates.
- Add optional three-row candidate browsing, stable paging and direct mouse selection across visible rows; verified snapshots reject stale selections and removals. Inactive rows reserve the same number-label width as the active row so words stay in place when moving up or down. Keep the completion row visible.
- Add exact specialist vocabulary without polluting general predictions, deduplicate popularity evidence for additive readings, and accelerate Pinyin and dictionary prefix lookup.
- Correct ARM64 compiler differences in score-sentinel comparisons and floating-point intermediates to preserve candidate paths and Delphi scoring semantics.
- Keep automatic input-source enablement requests and per-layer notarization; upgrades preserve settings and learning. Explain the manual System Settings path when macOS does not show a consent dialog, and automatically verify enablement when returning to the installer.


## 0.1.0 (build 1)

- Use the stable lowercase release filename `cassotis-ime-macos-<version>-arm64-installer-signed.dmg` and document signing and notarization separately.
- Style the installer disk image with a website-inspired Retina background and a saved Finder layout for the installer and installation guide.
- Add an automatically saved logging switch, off by default, that starts or stops file logging immediately without restarting the input engine; rotate active logs at 2 MiB.
- Clearly label the DMG, mounted volume and bundled application as the Cassotis installer.
- Use the same white-backed logo with pronounced rounded corners in the macOS input-source switcher, menu bar and Cassotis's Chinese/English status bubble.
- Align the engine and dictionaries with Windows / Cassotis Lexicon v1.27.0; retain macOS 0.1.0 and build 1.
- Validate reused Pinyin paths against current syllable boundaries, restore five-syllable decoding, and bound cold character-LM work and exact-prefix learning bonuses.
- Offer an exact-word Tab join when no prediction is available, without learning the joined text. Show joins in the normal text color and predictive continuations in the theme accent color.
- Preserve attested compound-prefix highlighting on the five-syllable fast path and carry completion sources through the native protocol.
- Follow Windows' predictive-only completion statistics and long-sentence Top1/Top2 scoring.


- Prevent background macOS input clients from interrupting a composition. Finish launching the new frontend during installation so the first key does not wait on executable verification; restore the previous app if launch fails.

- Align the engine and lexicon with Windows / Cassotis Lexicon v1.26.1.
- Add guarded joint sentence repair with a bilateral verifier and preserve exact FP32 evidence when reusing query encodings.
- Reuse validated repaired prefixes for displayed and committed Tab completions; prefetch long completion work with request and context isolation.
- Fix Ziguang initial/final boundaries, including `sh`, `zh`, and `ch` for `song`, `zong`, and `cong`. Keep completed `ng` syllables and mixed retroflex abbreviations stable through typing, backspace and partial selection.
- Display learned words in the active simplified/traditional script while preserving learning identity and removal of both aliases.
- Show conservative invalid-Pinyin and repeated-vowel diagnostics in the candidate footer, preserving the two-row height, Tab completions and logo. Also supply marked-text colors to clients that retain them; macOS can replace inline styles.
- Reduce exact-component sorting work without changing ordering.

### Earlier changes

- Add a native macOS InputMethodKit / AppKit input method with a Free Pascal helper, local ONNX inference and simplified/traditional dictionaries.
- Align the pinyin engine with Windows 1.25.0, using Lexicon 1.25.0 and schema 24; cover prefix recall, compound ranking, ü aliases and stable candidate paging.
- Support full pinyin, abbreviated pinyin, six double-pinyin schemes, fuzzy matching, local learning and Tab completion.
- Keep the candidate panel at two rows, show up to nine candidates, highlight the selected item and allow removal of user words.
- Provide eight appearance options, font completion, live previews, native shortcut recording and automatically saved settings.
- Show an animated Chinese/English status bubble with the color logo and 13-point text at the caret on mode changes and input-source activation; avoid system cursor accessories, dismiss automatically and respect reduced motion.
- Use the color logo in the input menu and link About and Settings to the macOS website.
- Handle Chinese punctuation, cold-start keystrokes, focus changes, secure fields and recovery from helper failures.
- Provide build, rebuild and packaging scripts, plus a native graphical installer that preserves user settings and learning data.
- Keep source distributions focused on runtime and build components, validate assets with standalone checksums, and use configurable compiler and lexicon locations.
