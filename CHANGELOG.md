# Changelog

## 0.1.0 (build 1)

- Use a transparent logo in the macOS input-source switcher and menu bar; preserve the white-backed logo in Cassotis's Chinese/English status bubble.
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
