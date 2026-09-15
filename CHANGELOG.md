# Changelog

## 0.1.0 (build 1)

- Add a native macOS InputMethodKit / AppKit input method with a Free Pascal helper, local ONNX inference and simplified/traditional dictionaries.
- Align the pinyin engine with Windows 1.25.0 and Linux 0.7.0, using Lexicon 1.25.0 and schema 24; cover prefix recall, compound ranking, ü aliases and stable candidate paging.
- Support full pinyin, abbreviated pinyin, six double-pinyin schemes, fuzzy matching, local learning and Tab completion.
- Keep the candidate panel at two rows, show up to nine candidates, highlight the selected item and allow removal of user words.
- Provide eight appearance options, font completion, live previews, native shortcut recording and automatically saved settings.
- Show an animated Chinese/English status bubble with 13-point text at the caret on mode changes and input-source activation, with automatic dismissal and support for reduced motion.
- Use the color logo in the input menu and link About and Settings to the macOS website.
- Handle Chinese punctuation, cold-start keystrokes, focus changes, secure fields and recovery from helper failures.
- Provide build, rebuild and packaging scripts, plus a native graphical installer that preserves user settings and learning data.
