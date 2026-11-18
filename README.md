# Cassotis IME for macOS

<p align="center">
  <img src="docs/images/cassotis-logo.png" alt="Cassotis IME logo" width="280">
</p>

<p align="center">
  <a href="https://www.yanquan.org">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="docs/images/readme_slogan_dark.svg">
      <img src="docs/images/readme_slogan.svg" alt="翩若惊鸿，言如泉涌。" width="640">
    </picture>
  </a>
</p>

<p align="center">
  <a href="https://www.yanquan.org"><img src="https://img.shields.io/badge/website-yanquan.org-2a4374" alt="Website: yanquan.org"></a>
  <a href="https://github.com/shenmin/cassotis-ime-mac/releases/latest"><img src="https://img.shields.io/github/v/release/shenmin/cassotis-ime-mac?color=b0432f" alt="Latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue" alt="License: GPL-3.0"></a>
  <a href="COMPATIBILITY.md"><img src="https://img.shields.io/badge/platform-macOS%2014%2B-000000?logo=apple&amp;logoColor=white" alt="Platform: macOS 14 or later"></a>
  <a href="BUILD.md"><img src="https://img.shields.io/badge/arch-Apple%20Silicon-5a67d8" alt="Architecture: Apple Silicon"></a>
</p>

<p align="center">
  <img src="docs/images/macos-preview.png" alt="Native macOS candidate windows and Tab completions in the light, jade and dark themes" width="600">
</p>

**[Website: www.yanquan.org](https://www.yanquan.org)** | English | [简体中文](README.zh-Hans.md) | [繁體中文](README.zh-Hant.md) | [Windows version](https://github.com/shenmin/cassotis-ime) | [Linux version](https://github.com/shenmin/cassotis-ime-linux)

Cassotis IME for macOS (言泉输入法 macOS 版) is an experimental Chinese Pinyin input method for Apple silicon Macs. A native InputMethodKit / AppKit frontend communicates over IPC with a standalone Free Pascal engine process ported from [Cassotis IME for Windows](https://github.com/shenmin/cassotis-ime), using dictionaries built from [Cassotis Lexicon](https://github.com/shenmin/cassotis-lexicon). Candidate ranking runs entirely on the local CPU, powered by an in-house character-level language model. There are no ads, bundled programs, or cloud uploads—dictionaries, settings, and learned words remain strictly on your Mac.

The source for the upcoming 2.8.0 (build 9) aligns with Cassotis IME and Cassotis Lexicon v2.8.0 and requires Apple silicon running macOS 14 or later. The current published download is the [v2.7.0 installer](https://github.com/shenmin/cassotis-ime-mac/releases/download/v2.7.0/cassotis-ime-macos-2.7.0-arm64-installer-signed.dmg); read its [release notes](https://github.com/shenmin/cassotis-ime-mac/releases/tag/v2.7.0). See the [website](https://www.yanquan.org/mac) for a product overview, [COMPATIBILITY.md](COMPATIBILITY.md) for tested environments and known limitations, and the [version history](#version-history) below for release milestones.

Project goals:
- keep the macOS engine synchronized with each Windows release and verify parity on shared benchmark suites,
- integrate natively with macOS text input through public InputMethodKit and AppKit APIs, without requiring Accessibility or Input Monitoring permissions,
- ship an Apple-signed and notarized offline installer that requires neither network access nor a GPU.

## Name Origin
The English name **Cassotis** comes from the sacred spring inside the Temple of Delphi. In Greek tradition, the priestess Pythia drank from this spring before delivering oracles; as a symbol of inspiration and spoken prophecy, the name also nods to the core engine's origins in the Delphi programming language.

The Chinese name **言泉** (Yanquan, "Spring of Words") echoes both the prophetic spring of Cassotis and the idiom **言如泉涌** ("words flowing like a spring").

## Features
- **Native input method.** Built as an InputMethodKit input source with a non-activating AppKit candidate window that never steals focus from the active application. Composition, partial selection, and text commitment work across native Cocoa fields, WebKit, Chrome, Electron, and Terminal; secure password fields retain standard macOS behavior.
- **Candidate window.** Two rows by default: a single unwrapped row of up to nine numbered candidates, paired with a persistent Tab completion bar showing the logo and version. Paging can expand the view to three candidate rows; number keys and Space select from the active row while mouse clicks select from any visible row. All characters for a single syllable remain reachable by paging, including readings with more than 256 characters. Clicking the small red `×` next to a learned word deletes it. Includes eight color themes, font sizes from 12 to 32 pt (14 pt default), and live preview. The window anchors to the start of the composition by default and can be set to follow the caret in Appearance. Optional `;` and `'` shortcuts select the second and third candidates (off by default; Double Pinyin finals take priority). Right-clicking the window opens a context menu for mode switching, Settings, and About without interrupting active input.
- **Chinese/English mode.** Pressing Shift alone toggles between Chinese and English modes and briefly shows a 中/英 indicator near the caret (configurable in Appearance). Mode indicators also appear when switching to Cassotis or focusing a text field in English mode. Caps Lock can optionally replace Shift (currently without distinguishing short taps from long holds; see [configuration](CONFIGURATION.md)). Mode state is remembered per application by default. Pressing another key or clicking the mouse while holding the modifier cancels the toggle; the frontend detects this via system-wide event counts without inspecting key contents.
- **English recognition.** In Chinese full-Pinyin, half-width mode, recognized English words and names (`pro`, `markdown`, `Effie`), capitalized inputs, and previously committed letter strings appear ahead of numbered candidates with their casing preserved. If the input has no full-word Chinese reading, the English candidate is selected by default so Space commits it directly; if it also matches a Chinese reading (`bug`, `mac`), the language model ranks the English token against Chinese candidates using preceding context. Arrow keys and the mouse move between English and Chinese candidates while Chinese selection numbers stay unchanged. Committing an English token records the preference without adding a user dictionary entry. Enabled by default and configurable in Settings; Double Pinyin retains standard Chinese parsing.
- **One-key completion.** Displays at most one high-confidence continuation in the Tab bar, accepted with the configured completion key. Exact matches from the user and base dictionaries plus offline-vetted strong-transition completions appear immediately, followed by background language-model reranking using preceding context when available. During long-sentence input, it completes the current word or proposes the next phrase, hiding the prompt when confidence is low. Model predictions appear in the theme's accent color, whereas plain concatenations of already-typed words use the standard text color. Classical Chinese verses can be completed from their opening syllables, and entering a full line can prompt the following line (for example, 春眠不觉晓，处处闻啼鸟).
- **Long sentences.** Lexicon-constrained path search constructs full-sentence candidates (for example `womenjintian` → `我们今天`) while retaining prefix candidates for step-by-step selection. The language model selects the top full-sentence candidates and—across simplified and traditional Chinese in both full and Double Pinyin—applies Pinyin-conditioned homophone correction using preceding context.
- **Short words.** Competing exact candidates are ranked using language-model context scores and general-corpus word frequencies. Without preceding context, frequency priors and conversational-word protection prevent rare or overly formal words from displacing common everyday defaults. With preceding context, single-syllable homophone characters are also ranked by the language model.
- **Short phrases.** In simplified and traditional modes, three- to five-syllable inputs absent from the dictionary (for example `jiuguize` → `旧规则`) are assembled into full-phrase drafts from dictionary words, scored in context by the language model, and checked for homophone errors against the typed Pinyin. Up to two close alternatives follow the top choice.
- **Pinyin schemes.** Full Pinyin and seven Double Pinyin layouts (Microsoft, Xiaohe, Ziranma, Sogou, Ziguang, Pinyin Jiajia, and Zhineng ABC) share the same ranking pipeline and learned data. Supports per-rule fuzzy Pinyin, initial-letter abbreviations (for example `jt` → `今天`), and `v` for `ü` (`lv`, `nv`, plus `lue`/`nue` and `jv`/`qv`/`xv`).
- **Dictionaries and learning.** Maintains separate simplified and traditional base dictionaries alongside an independent user dictionary; learned words automatically render in the active script without re-learning. Specialist terms appear only on exact Pinyin matches. Unrecognized letter sequences are highlighted in red without altering the input. Word-frequency exports from other input methods can be imported under Advanced; see the [frequency import guide (Chinese)](CONFIGURATION.md#输入频次导入).
- **Quick input.** `ufh` for symbols, `uxh` for numbered markers, `usx` for math symbols, `urq` / `usj` for current date and time, and more; `i123.45` or `v123.45` formats Chinese numerals and uppercase currency amounts, selected via `a/b/c/d` while digit keys continue appending numbers. In Double Pinyin, enter these modes via Shift+U/I/V. See the [quick-input guide (Chinese)](QUICK_INPUT.md).
- **Chinese punctuation.** In Chinese punctuation with half-width input, a period typed immediately after digits outputs a decimal point. Symbols kept half-width can be customized in Settings or switched between the Markdown preset and standard Chinese punctuation. The default Markdown preset preserves ``-#*+_=`~[]<>|@`` as ASCII while keeping Chinese commas, periods, parentheses, and quotation marks; backslash outputs `、`.
- **Custom phrases.** Bind letter abbreviations to literal single- or multi-line text committed via Tab without affecting numbered candidates or Space. Supports custom ordering, duplicate-shortcut priority, and Windows-compatible JSON import/export. Enter a shortcut and text, then click **添加短语** (Add Phrase); use **保存修改** (Save Changes) or **取消编辑** (Cancel Edit) when editing existing entries.
- **Settings.** Sidebar-organized preferences window where confirmed changes save and apply immediately, with direct key-press shortcut recording and font-name autocomplete. Logging is disabled by default. Keys groups paging, candidate keys and completion; `[` / `]` can optionally select the first / last character of the highlighted word.
- **Offline by design.** Runs locally without network access or GPU usage. Keystrokes entered while the engine starts are buffered and processed once ready; if the language model is still loading or unavailable, dictionary-based input continues normally without neural reranking.

<p align="center">
  <img src="docs/images/macos-three-row-candidates.png" alt="Three-row candidate window with the second row active" width="560">
  <br>
  <em>Three-row candidate view, with selection numbers on the active row.</em>
</p>

## What's new in 2.8.0

- **Pick a character from a word.** Enable `[` / `]` in Keys to commit the highlighted candidate's first or last character. Bracket paging takes priority; this action does not train character preferences.
- **Recent choices matter, without lasting surprises.** Choose a word twice within two hours to put it first temporarily. Single-character preferences expire after the same window.
- **More natural short phrases.** Preserve corpus-supported phrases, distinguish the readings of 没, and keep `oo` as a Chinese acknowledgement unless English was deliberately chosen.
- **Better traditional-character choices.** Common related forms beyond the first sixteen characters can participate in context ranking.
- **Updated vocabulary and less repeated inference.** Adopt Lexicon v2.8.0 and reuse recent model output distributions. The application still carries one neural model, with the same weights as 2.7.0.
- **Keep syllable boundaries intact.** Fix long-sentence candidates when Double Pinyin or an apostrophe fixes an otherwise ambiguous boundary.

## Download and Install
- **Download.** Download `cassotis-ime-macos-<version>-arm64-installer-signed.dmg` (~340 MB, including simplified/traditional base dictionaries and the language model) from [Releases](https://github.com/shenmin/cassotis-ime-mac/releases). Official disk images are signed with the Sunisoft Limited Developer ID and notarized by Apple.
- **Requirements.** Apple silicon Mac running macOS 14 or later. No Terminal commands, compiler, Python environment, network connection, or GPU required.
- **Install.** Open the disk image, double-click **言泉输入法安装器** (Cassotis IME Installer), and click **安装** (Install). Click **Allow** if macOS prompts to enable the input source. Once **安装完成** (Installation Complete) appears, choose **言泉输入法** from the menu bar input menu and type `nihao` followed by Space to enter “你好”. If the input source is not yet active, click **重试启用** (Retry Enablement) or **打开键盘设置** (Open Keyboard Settings) to add it manually.
- **macOS 27.** macOS may open Keyboard Settings directly without showing a confirmation dialog. Add **言泉输入法** under **Text Input → Edit → + → Chinese, Simplified**, then return to the installer so it can verify enablement.
- **Upgrade.** Run the new installer directly over an existing installation. User settings and learned words are preserved; the installer displays progress and provides log access and retry options on failure.
- **Uninstall.** Remove the input source in System Settings first, then run the uninstaller built into the installer app. User settings and learned words are retained.

## Architecture
- `src/macos`: InputMethodKit input controller and AppKit candidate window, mode indicator bubble, and settings UI (Objective-C++).
- `src/service`, `src/ipc`: standalone engine service and Unix domain socket IPC protocol.
- `src/engine`, `src/dictionary`: Pinyin parsing, candidate generation, ranking, and user learning ported from Windows.
- `src/host`: language-model runtime host; `src/host/native` implements the C++ ONNX Runtime bridge and custom attention operator.
- `src/common`: configuration handling, shared types, and platform abstraction.
- `src/installer`: graphical macOS installer.
- `tools/dictionary`, `tools/control`: SQLite dictionary builder/importer and input-source registration helper.
- `data`: split language-model archives (`data/models/char_lm`), asset checksums, and lexicon input hashes.
- `scripts`, `resources`: build, install, and packaging scripts; icons and bundle metadata.
- `third_party`: ONNX Runtime headers/version pins and third-party license notices.

See the [architecture document (Chinese)](docs/ARCHITECTURE.md) for process boundaries, IPC protocol details, and crash recovery.

## Runtime Files
- `Cassotis.app/Contents/MacOS/Cassotis`: input-method frontend process launched by macOS for the input source.
- `Cassotis.app/Contents/MacOS/cassotis-engine`: backend engine process that loads dictionaries and the language model; spawned by the frontend with `--serve` over a private Unix socket.
- `Cassotis.app/Contents/Frameworks/libcassotis_ort.dylib` and `libonnxruntime.1.20.1.dylib`: C++ inference bridge and ONNX Runtime library, loaded exclusively by the engine process.
- `Cassotis.app/Contents/Resources/models/char_lm`: language model, character vocabulary, Pinyin reading table, and runtime manifest.
- `Cassotis.app/Contents/Resources/dictionaries`: simplified and traditional base dictionaries (`dict_sc.db`, `dict_tc.db`).

Pinyin conversion requires `cassotis-engine`. If an IPC request fails or times out, the frontend commits the last visible composition, passes the current key event through to the client app, and restarts the engine automatically. If model files are missing, dictionary lookup and candidate input continue without language-model reranking.

## Build and Install (Quick Start)
Prerequisites: Apple silicon Mac, Free Pascal 3.2.2, Xcode Command Line Tools, and Python 3.11+ (Lazarus/LCL is not needed). Obtain the generated lexicon files from [Cassotis Lexicon v2.8.0](https://github.com/shenmin/cassotis-lexicon) and point `CASSOTIS_LEXICON_ROOT` to that directory (`/path/to/...` below is a placeholder):

```sh
./scripts/check_environment.sh
export CASSOTIS_LEXICON_ROOT="/path/to/cassotis-lexicon"
./build_all.sh
./install.sh
```

The bundle is built at `build/arm64/Cassotis.app` and installed into `~/Library/Input Methods/Cassotis.app` for the current user (do not run with `sudo`). Add 言泉输入法 under System Settings → Keyboard → Text Input, then select it from the menu bar. Log out and back in if the input-source list does not update immediately.

`build_all.sh` compiles the ONNX bridge, engine, simplified and traditional dictionaries, frontend, and installer, and reassembles `char_lm.onnx` from the numbered parts in `data/models/char_lm` after verifying SHA-256 checksums. On first build, it downloads the official ONNX Runtime 1.20.1 arm64 archive and verifies its pinned hash. Use `./rebuild_all.sh` for a clean rebuild, `./uninstall.sh` to remove the app while keeping user data, and `./scripts/package.sh` to create the installer DMG. See [BUILD.md (Chinese)](BUILD.md) for build flags, packaging, and signing.

## Dictionary Workflow
Base dictionaries use schema-24 SQLite databases defined by [Cassotis Lexicon](https://github.com/shenmin/cassotis-lexicon), built from 30 generated files under its `data/generated/` directory:
- core and character word lists: `dict_unihan_sc.txt`, `dict_unihan_tc.txt`, `dict_clean_sc.txt`, and `dict_clean_tc.txt` (`pinyin<TAB>text<TAB>weight`),
- corpus-derived statistical tables: word-transition priors, completion priors, general-text and conversational word frequencies, and precomputed short-word promotion tables.

During the build, each input file is verified against [data/lexicon-inputs.json](data/lexicon-inputs.json) before being imported into `dict_sc.db` and `dict_tc.db` inside the app bundle. The v2.8.0 dictionaries contain 266,839 simplified and 269,930 traditional reading entries (including single characters). User dictionaries, engine preferences, and learned data live under `~/Library/Application Support/CassotisIME/` and are never overwritten on app updates.

## Models and Ranking
The macOS build uses the exact same language model and compact ranking components as Cassotis IME for Windows v2.8.0, with byte-identical model weights and identical compiled decision parameters.

### Character-level language model
- **Unified local language model.** A custom-trained ~150M-parameter character-level autoregressive model (11 layers, 1,024 hidden size, 12,017-character vocabulary, int8 static quantization) serves every neural task: full-sentence scoring and Pinyin-conditioned homophone repair, contextual short-word and single-character ranking, out-of-vocabulary phrase composition, English-vs-Chinese candidate weighting, one-key completion reranking, and long-sentence Tab continuation. Earlier task-specific neural graphs have been retired.
- **Training corpora and conversational adaptation.** Trained on independent general Chinese text and fiction corpora for both standard autoregressive scoring and Pinyin-conditioned repair. Starting in v2.7.0, training continued on the 10% subset of the public LCCC dialogue corpus closest to everyday chat, then averaged 1:1 with the base checkpoint to improve conversational phrasing while preserving accuracy on fiction and general text. All benchmark evaluation sets are strictly excluded from training data.
- **Deterministic inference.** Fixed static quantization ranges are paired with a custom trie-attention operator whose Apple silicon ARM NEON kernel preserves the exact accumulation order of the Windows AVX2 kernel. Any text produces bit-identical scores regardless of batching or prior cache state, guaranteeing that typing a sentence key by key yields the same candidates as decoding the full Pinyin string at once.

### Decision models and lexical priors
- **Lightweight GBDT decision models.** Six compact gradient-boosted decision tree (GBDT) models combine language-model scores with lexical features for long-sentence selection, context-free short-word ranking, contextual short-word ranking (plus a secondary contextual tie-breaker), one-key completion, and Tab continuation. Trained on engine traces over held-out corpora and refit whenever the base LM changes, they are compiled directly into the engine with identical parameters across platforms.
- **Compact structural rankers.** Three lightweight structural rankers guide lattice pruning during long-sentence search and order the initial pool of full-sentence candidates.
- **Lexicon statistical priors.** Precomputed SQLite tables supply signals orthogonal to neural scores: word-transition priors, completion priors, an offline short-word promotion table, and corpus word frequencies across general text and everyday conversation.

### Ranking pipeline by scenario
In Traditional Chinese mode, candidates and context are mapped to simplified characters for neural scoring while generated completions are converted to standard Taiwan traditional forms. Foreground candidate ranking and background completion share the same model instance.

- **Long sentences.** Lexicon-constrained search builds full-sentence candidates; two structural rankers prune search paths and a third orders the complete candidate pool. The language model scores leading candidates and the long-sentence GBDT selects the top two choices. Across simplified and traditional Chinese in full or Double Pinyin, the model then runs up to two Pinyin-conditioned homophone repair passes with joint scoring using up to 48 preceding characters; user dictionary words and exact full-query dictionary matches remain untouched.
- **Short words and single characters.** Competing exact candidates keep their dictionary order unless language-model scores (incorporating preceding context when present) give the short-word GBDTs a clear margin to reorder them. Without context, the GBDT also weighs general-corpus word frequencies while protecting top choices that are substantially more common in everyday conversation (`zhezhou` → 这周); purely dictionary-driven ties are calibrated by the precomputed short-word promotion table. Single-syllable characters are ranked by the language model when context is present and by modern character frequency otherwise.
- **Out-of-vocabulary phrases.** Three- to five-syllable inputs matching neither base nor user dictionaries are segmented into candidate full-phrase drafts from dictionary words, scored by the language model as standalone or contextual clauses, and refined via Pinyin-conditioned homophone repair. Active for full and Double Pinyin in both scripts; bypassed when fuzzy Pinyin is enabled or when explicit syllable separators (`'`) are present. Selecting a non-top phrase records it in the user dictionary.
- **English tokens.** When typed letters also form valid Chinese Pinyin, a single batched model call compares the literal English token against the top Chinese readings in context, promoting the English candidate only when it holds a clear margin.
- **One-key completion.** Exact dictionary matches and strong-transition completions appear immediately; the language model reranks a broader candidate set in the background and updates the prompt only when the score gain is decisive.
- **Long-sentence Tab continuation.** The language model proposes trailing characters and jointly scores completions of the current word against next-phrase continuations; the Tab GBDT either selects the best continuation or suppresses the prompt.

### Local runtime behavior
- Inference runs exclusively on the local CPU via bundled ONNX Runtime, with zero network or GPU usage.
- The model loads asynchronously in the background inside `cassotis-engine`; standard dictionary lookup, selection, commitment, and lexical completion never block on model initialization.
- Neural calls enforce a 100 ms deadline (80 ms for long-sentence Tab continuation); timed-out calls are discarded without disturbing existing candidates.
- Inference worker count scales with the fastest CPU core tier (clamped between 4 and 8 threads), falling back to physical or logical CPU counts if core-tier metadata is unavailable.
- Context reads at most 1,024 UTF-16 code units preceding the caret and never inspects secure text fields.

## Benchmarks
Methodology, corpus details, and scoring rules are documented in [BENCHMARK.md](BENCHMARK.md). The evaluation suites match Cassotis IME for Windows and are drawn from the author's novel [**Elegance in Timelessness** (永恒的舞动)](https://www.qidian.com/book/1037259117/), strictly disjoint from all training corpora. Version labels in the tables denote macOS releases.

Current measurements were collected serially in native arm64 mode on an Apple M2 Pro (32 GiB RAM, macOS 27.2.1) using the simplified dictionary and six model threads (releases prior to v2.5.0 used eight). Latencies are reported in milliseconds for the engine alone, excluding InputMethodKit, IPC, and UI rendering. Cross-run latency varies slightly with background system load; full results and methodology are in [BENCHMARK.md](BENCHMARK.md).

The tables compare macOS v2.8.0 against the preceding release, v2.7.0, while retaining published figures for earlier versions. Test cases include the 51 long-sentence and 217 short-word polyphonic Pinyin reading fixes adopted during v2.1.0 preparation. In the `v2.0.0` row, regular text shows the October 23 remeasurement of the original binary and Lexicon v2.2.0 on the corrected cases, italic text preserves the original release numbers, and a single value indicates no change. `v1.0.0` retains its historical figures. Full details and upstream reference counts appear in [BENCHMARK.md](BENCHMARK.md).

### Long Sentence Benchmark-16300

| Version | Top1 | Top2 | Mean (ms) | P50 (ms) | P95 (ms) | Max (ms) |
|---|---:|---:|---:|---:|---:|---:|
| `v2.8.0` | 13747/16300 (84.34%) | 14690/16300 (90.12%) | 88.809 | 82 | 159 | 533 |
| `v2.7.0` | 13738/16300 (84.28%) | 14681/16300 (90.07%) | 85.862 | 79 | 155 | 508 |
| `v2.6.0` | 13743/16300 (84.31%) | 14689/16300 (90.12%) | 82.148 | 77 | 143 | 499 |
| `v2.5.0` | 13441/16300 (82.46%) | 14358/16300 (88.09%) | 86.055 | 81 | 146 | 512 |
| `v2.1.0` | 13435/16300 (82.42%) | 14314/16300 (87.82%) | 87.889 | 84 | 147 | 519 |
| `v2.0.0` | 13390/16300 (82.15%)<br>*13397/16300 (82.19%)* | 14273/16300 (87.56%)<br>*14281/16300 (87.61%)* | 90.024<br>*94.084* | 86<br>*90* | 149<br>*154* | 517<br>*523* |
| `v1.0.0` | 12941/16300 (79.39%) | 13534/16300 (83.03%) | 85.043 | 79 | 148 | 567 |

Accuracy is measured in deterministic mode without inference timeouts; latency is measured in a separate production-configured run and reflects full-sentence batch decoding rather than per-keystroke display latency.

### Short-word Context Benchmark-65000

| Version | Top1 | Top2 | Contested Top1 | Contested Top2 | Mean (ms) | P50 (ms) | P95 (ms) | Max (ms) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `v2.8.0` | 63502/65000 (97.70%) | 64565/65000 (99.33%) | 10546/11685 (90.25%) | 11315/11685 (96.83%) | 7.459 | 5 | 20 | 69 |
| `v2.7.0` | 63502/65000 (97.70%) | 64564/65000 (99.33%) | 10545/11685 (90.24%) | 11315/11685 (96.83%) | 7.404 | 5 | 20 | 53 |
| `v2.6.0` | 63455/65000 (97.62%) | 64521/65000 (99.26%) | 10516/11685 (90.00%) | 11283/11685 (96.56%) | 6.744 | 5 | 18 | 99 |
| `v2.5.0` | 63463/65000 (97.64%) | 64436/65000 (99.13%) | 10512/11685 (89.96%) | 11223/11685 (96.05%) | 7.202 | 5 | 20 | 66 |
| `v2.1.0` | 63455/65000 (97.62%) | 64423/65000 (99.11%) | 10539/11685 (90.19%) | 11225/11685 (96.06%) | 7.652 | 5 | 21 | 70 |
| `v2.0.0` | 63348/65000 (97.46%)<br>*63362/65000 (97.48%)* | 64346/65000 (98.99%)<br>*64291/65000 (98.91%)* | 10504/11685 (89.89%)<br>*10533/11728 (89.81%)* | 11228/11685 (96.09%)<br>*11244/11728 (95.87%)* | 7.281<br>*7.232* | 5 | 20 | 79<br>*62* |
| `v1.0.0` | 63036/65000 (96.98%) | 64103/65000 (98.62%) | 10488/11728 (89.43%) | 11196/11728 (95.46%) | 6.801 | 6 | 17 | 40 |

Results above include preceding context. `Contested` denotes queries that map to at least two distinct target words in the corpus. Without preceding context, v2.8.0 achieves 61316/63822 (Top1/Top2). Full subset breakdowns are in [BENCHMARK.md](BENCHMARK.md).

### One-key Completion Context Benchmark-12831

| Version | Completion Hit | Avg Keys Saved | Stability | Keystroke P95 (ms) | Final P95 (ms) |
| --- | --- | --- | --- | --- | --- |
| `v2.8.0` | 10506/12831 (81.88%) | 2.634 | 2139/2200 (97.23%) | 2.107 | 17.968 |
| `v2.7.0` | 10506/12831 (81.88%) | 2.634 | 2139/2200 (97.23%) | 2.054 | 17.527 |
| `v2.6.0` | 10513/12831 (81.93%) | 2.635 | 2153/2216 (97.16%) | 2.000 | 16.493 |
| `v2.5.0` | 10513/12831 (81.93%) | 2.635 | 2153/2216 (97.16%) | 2.137 | 19.915 |
| `v2.1.0` | 10513/12831 (81.93%) | 2.636 | 2154/2217 (97.16%) | 2.035 | 18.451 |
| `v2.0.0` | 10466/12831 (81.57%)<br>*10457/12831 (81.50%)* | 2.633<br>*2.632* | 2134/2198 (97.09%)<br>*2133/2195 (97.18%)* | 1.982<br>*2.035* | 19.357<br>*21.352* |
| `v1.0.0` | 10331/12831 (80.52%) | 2.638 | 2117/2180 (97.11%) | 1.213 | 9.385 |

The 65,000 short-word cases yield 12,831 completion opportunities. Average keys saved are computed per hit after deducting one keystroke to accept the prompt; `Final P95` includes background rerank latency whenever reranking updates the displayed completion.

### Long-sentence One-key Completion Benchmark-16300

| Version | Local Completion Hit | Predictive Prompt Coverage | Total Keys Saved | P95 (ms) |
| --- | --- | --- | --- | --- |
| `v2.8.0` | 3976/16300 (24.39%) | 16230/16300 (99.57%) | 9816 | 150 |
| `v2.7.0` | 3982/16300 (24.43%) | 16234/16300 (99.60%) | 9827 | 143 |
| `v2.6.0` | 3955/16300 (24.26%) | 16152/16300 (99.09%) | 9724 | 137 |
| `v2.5.0` | 3903/16300 (23.94%) | 16144/16300 (99.04%) | 9627 | 146 |
| `v2.1.0` | 3877/16300 (23.79%) | 16139/16300 (99.01%) | 9597 | 148 |
| `v2.0.0` | 3771/16300 (23.13%)<br>*3768/16300 (23.12%)* | 16111/16300 (98.84%)<br>*16113/16300 (98.85%)* | 9303<br>*9293* | 143<br>*149* |
| `v1.0.0` | 3539/16300 (21.71%) | 15812/16300 (97.01%) | 7539 | 131 |

Each case omits the final four complete syllables of a sentence and evaluates the single continuation shown; any continuation that accurately extends the typed prefix counts as a hit without requiring full-sentence completion. All releases enforce an 80 ms deadline. For v2.8.0, the deadline-free control run records 3,976 hits and 9,816 net saved keys; the production run records 3,976 hits and 9,816 net saved keys. 他 and 她 are treated as equivalent at the same position. `Predictive Prompt Coverage` measures how often a predictive continuation is offered (excluding plain joins of already-typed Pinyin) rather than hit precision.

## Configuration
Open **Settings…** from the menu bar input menu, or press Ctrl+Shift+F10. Confirmed changes are saved and applied immediately.

Key options include:
- simplified or traditional dictionary and Pinyin scheme (Full Pinyin or one of seven Double Pinyin layouts)
- per-rule fuzzy Pinyin toggles
- candidates per page (3 to 9), paging and completion keys, and five individually toggleable action shortcuts
- Chinese/English toggle key: Shift or Caps Lock (Shift by default)
- per-application Chinese/English mode memory (enabled by default)
- English recognition in Chinese mode (enabled by default)
- automatic decimal point when typing a period after digits (enabled by default)
- ASCII symbols preserved in Chinese punctuation mode (Markdown preset by default)
- candidate font, size, color theme, and optional three-row expansion
- candidate window anchored at composition start or following the caret (anchored by default)
- `;` and `'` shortcuts for the second and third candidates (disabled by default)
- `[` / `]` to select a candidate's first or last character (disabled by default; incompatible with bracket paging)
- Chinese/English mode bubble near the caret (enabled by default)
- custom phrases with Add / Save Changes controls, ordering, duplicate priority, and JSON import/export
- importing external word frequencies under Advanced
- diagnostic logging under Advanced (disabled by default; written to `~/Library/Logs/CassotisIME/`)
- ranking-context debug display under Advanced (disabled by default, independent of logging)

UI display preferences are stored in `UserDefaults` under `org.cassotis.inputmethod.Cassotis`; engine settings and learned user data reside in `~/Library/Application Support/CassotisIME/`. See the [configuration guide (Chinese)](CONFIGURATION.md) for full details.

## Documentation
- Website: [www.yanquan.org](https://www.yanquan.org), macOS page: [www.yanquan.org/mac](https://www.yanquan.org/mac)
- Simplified Chinese documentation: [README.zh-Hans.md](README.zh-Hans.md)
- Traditional Chinese documentation: [README.zh-Hant.md](README.zh-Hant.md)
- Benchmark methodology and results: [BENCHMARK.md](BENCHMARK.md)
- Configuration and shortcuts (Chinese): [CONFIGURATION.md](CONFIGURATION.md)
- Quick input reference (Chinese): [QUICK_INPUT.md](QUICK_INPUT.md)
- Build, packaging, and signing (Chinese): [BUILD.md](BUILD.md)
- Tested environments and limitations: [COMPATIBILITY.md](COMPATIBILITY.md)
- Release changelog: [CHANGELOG.md](CHANGELOG.md)
- Processes, IPC protocol, and recovery (Chinese): [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Licenses and provenance: [NOTICE.md](NOTICE.md)

## Roadmap
- track upstream Windows engine, language-model, and lexicon releases, verify parity on shared benchmarks, and publish native macOS results
- expand hardware validation across macOS 14 and 15, clean installs, multi-display setups, and sleep/wake cycles
- broaden compatibility testing across third-party macOS apps
- reduce end-to-end keystroke-to-candidate latency, especially on long sentences

## Version History
Major milestones of the macOS port and its ranking architecture. The corresponding Cassotis IME for Windows baseline is shown in parentheses; see the [changelog](CHANGELOG.md) and [GitHub Releases](https://github.com/shenmin/cassotis-ime-mac/releases) for complete release notes.

**v0.1.0 (build 1, Windows v1.27.0): initial public release.** Native InputMethodKit / AppKit frontend paired with a Free Pascal engine process, local ONNX inference, and simplified/traditional dictionaries; full Pinyin, abbreviations, six Double Pinyin schemes, fuzzy Pinyin, local user learning, and Tab completion; two-row candidate window with eight themes, caret mode bubble, instant-apply settings, and a signed installer that preserves user data.

**v0.2.0 (build 2, Windows v1.29.0): cross-platform numerical parity.** Added contextual short-word reranking, literary phrase recovery for long sentences, optional three-row candidate expansion with cross-row mouse selection, and exact-match gating for specialist terms. Aligned minimum-integer boundary checks and floating-point intermediate precision so Free Pascal on Apple silicon matches Delphi candidate paths and scores on Windows.

**v1.0.0 (build 3, Windows v1.31.0): shared character language model.** Replaced the RBT3 short-context model with a unified character-level language model across long sentences, contextual short words, mixed abbreviations, and Tab continuation, adding background short-completion reranking and unified scoring of word completions, trailing phrases, and predicted characters.

**v2.0.0 (build 4, Windows v2.2.0): single-model consolidation.** Consolidated the eleven stage-specific neural graphs from v1.0.0 into one character language model and seven compact ranking units, removing legacy graphs, auxiliary indexes, and host code. Added neural composition and homophone repair for three- to five-syllable out-of-vocabulary phrases, alongside English recognition, U/I/V quick input, automatic decimal periods, the Markdown punctuation preset, per-app mode memory, and ordered custom phrases.

**v2.1.0 (build 5, Windows v2.4.0): language-model ranking for Traditional Chinese.** Mapped traditional candidates and context to simplified equivalents for neural scoring while preserving Taiwan traditional character forms across candidates, paging, committed text, and Tab completions. Added external word-frequency import and ranking-context debug inspection.

**v2.5.0 (build 6, Windows v2.5.0): general-corpus word frequencies and unified versioning.** Integrated general-corpus word frequencies into short-word ranking to keep common words ahead without context, switched word transitions to on-demand queries, made all single-syllable characters reachable by paging, added Caps Lock mode switching, and sized model worker threads from performance cores. Unified macOS and Windows version numbers starting with 2.5.0.

**v2.6.0 (build 7, Windows v2.6.0): joint homophone repair and contextual short-word GBDT.** Combined Pinyin-conditioned repair with language-model joint scoring for long-sentence rewrites (including whole-word homophone swaps), introduced a dedicated contextual short-word GBDT, switched context-free single characters to modern frequency order, and appended two-syllable split prefix characters after full-syllable characters (such as `shu` under `shua`).

**v2.7.0 (build 8, Windows v2.7.0): conversational adaptation and full scheme coverage.** Continued language-model training on everyday dialogue data and refit all six GBDT decision models, protecting high-frequency conversational defaults when no context is present. Extended phrase generation and sentence repair to Traditional Chinese and Double Pinyin, added contextual neural ranking for single characters, enabled second-pass sentence repair, and added Zhineng ABC Double Pinyin.

## License
Application source code is licensed under GPL-3.0; see [LICENSE](LICENSE). Bundled dictionaries are licensed under CC BY-SA 4.0 as declared by Cassotis Lexicon. Licenses and provenance for the language model, ONNX Runtime, and other bundled components are documented in [NOTICE.md](NOTICE.md); model and schema checksums are listed in `data/runtime-assets.sha256`.
