# Cassotis IME - 言泉输入法

<p align="center">
  <img src="docs/images/cassotis-logo.png" alt="Cassotis IME logo" width="280">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue" alt="License: GPL-3.0"></a>
  <a href="COMPATIBILITY.md"><img src="https://img.shields.io/badge/platform-macOS-000000?logo=apple&amp;logoColor=white" alt="Platform: macOS"></a>
  <a href="BUILD.md"><img src="https://img.shields.io/badge/arch-Apple%20Silicon-5a67d8" alt="Architecture: Apple Silicon"></a>
</p>

<p align="center">
  <img src="docs/images/macos-preview.png" alt="Native macOS candidate windows and Tab completions in the light, jade and dark themes" width="600">
</p>

<p align="center"><sub>Native macOS candidate windows · Tab completion · Light, jade and dark themes</sub></p>

English | [简体中文](README.zh-Hans.md) | [繁體中文](README.zh-Hant.md)

Cassotis IME - 言泉输入法 is an open-source Chinese Pinyin input method for macOS, with native candidate windows, local language models and private, offline word learning.

[Website](https://www.yanquan.org/mac) · [Downloads](https://github.com/shenmin/cassotis-ime-mac/releases) · [Windows](https://github.com/shenmin/cassotis-ime) · [Linux](https://github.com/shenmin/cassotis-ime-linux)

An **InputMethodKit / AppKit frontend and a separate Free Pascal engine process** integrate with macOS text input. Dictionaries and models are included; candidate ranking, sentence repair and Tab completion run locally.

Version **1.0.0** (build **3**) supports Apple Silicon and macOS 14 or later. See [COMPATIBILITY.md](COMPATIBILITY.md) for the tested environments and known limitations.

## Features

- Full Pinyin, initial-letter abbreviations, and six Double Pinyin schemes: Microsoft, Xiaohe, Ziranma, Sogou, Ziguang, and Pinyin Jiajia.
- Simplified and traditional Chinese dictionaries, fuzzy Pinyin, partial candidate selection, long-sentence ranking, and local sentence repair.
- A two-row candidate window by default, with optional expansion to three candidate rows while paging: up to nine candidates per row, an always-present Tab completion row, and the logo and version at the bottom right. Learned words can be deleted using the small red × beside them.
- A native candidate window and settings interface, horizontal candidate rows without wrapping, a default font size of 14 points, eight color options, and a live preview. The candidate window keeps focus in the application receiving input.
- A brief animated bubble beside the caret shows the Cassotis logo beside “中” (Chinese) or “英” (English), avoids nearby system cursor indicators, and appears when changing modes or switching from another input method to Cassotis. It dismisses when typing starts.
- Settings categories in a sidebar, font-name completion, and direct key recording for five configurable shortcuts. Confirmed choices save automatically; macOS system shortcuts and secure password fields retain their normal behavior.
- Joint local sentence repair with bilateral verification, repaired-prefix reuse for Tab completions, and stable candidates while typing or deleting incomplete initials.
- Correct Ziguang `sh` / `zh` / `ch` decoding (`song` / `zong` / `cong`), conservative diagnostics for invalid Pinyin and repeated vowels, with red error ranges in the candidate footer, and simplified/traditional display of shared learned words.
- Five-syllable decoding, stricter pronunciation checks for cached paths, and prefix ranking that respects repeated choices.
- When no predictive hint is available, Tab can join exact words for the already typed Pinyin. Predictive hints use the theme accent color; exact joins use ordinary text color.
- One shared character language model improves long sentences, contextual words, mixed Pinyin abbreviations and Tab continuations while preserving learned preferences and exact-word protections.
- Tab compares completion of the current word with following phrases and next-character suggestions. Short-word suggestions are shown immediately from the dictionary, then reranked in the background. Explicit Pinyin syllable boundaries are preserved.
- Specialist vocabulary is available for exact input without crowding predictions. Additive readings no longer duplicate text-popularity evidence; shared encoders and Pinyin caches reduce repeated work.
- All inference runs locally on the CPU through ONNX Runtime. The installed input method needs no compiler, Python installation, or online service.

## Install and Try

Download the DMG, open it, double-click **言泉输入法安装器** (Cassotis IME Installer), and click **安装** (Install). The installer requests input-source enablement automatically; click **Allow** if macOS asks for confirmation. Once **安装完成** (Installation Complete) appears, select **言泉输入法** directly from the input menu in the menu bar. The color Cassotis logo indicates that it is selected. Type `nihao` and press Space to enter “你好”. If enablement is still pending, click **重试启用** (Retry Enablement), or use **打开键盘设置** (Open Keyboard Settings) to add it manually.

On macOS 27, the system may open Keyboard Settings without showing a confirmation. Add **言泉输入法** under **Text Input → Edit → + → Chinese, Simplified**, then return to the installer; it verifies enablement automatically.

The graphical installer shows progress, preserves settings and learned words during upgrades, and provides logs and a retry option if installation fails. Using the installed input method requires no Terminal commands, compiler, Python installation, or separate model downloads. The v1.0.0 download is `cassotis-ime-macos-1.0.0-arm64-installer-signed.dmg`, signed with the Sunisoft Limited Developer ID and notarized by Apple. Local development packages ending in `-local` use an ad hoc signature. The installer also provides an uninstall option; remove the input source in System Settings first.

## Benchmarks

Results below compare macOS v1.0.0 with the previous release, v0.2.0, using the same complete corpora. All version numbers in these tables are macOS product versions.

See [BENCHMARK.md](BENCHMARK.md) for case construction, scoring and detailed results. The corpus comes from the developer’s novel [Elegance in Timelessness (永恒的舞动)](https://www.qidian.com/book/1037259117/).

Both releases were measured on an Apple M2 Pro with 32 GiB of memory, using native arm64 programs: v1.0.0 on macOS 27.0.1, v0.2.0 on macOS 27.0. These are the recorded measurements for each release, not a rerun of both versions on the current system.

### Long Sentence Benchmark-16300

| macOS version | Top1 | Top2 | Mean (ms) | P50 (ms) | P95 (ms) | Max (ms) |
| --- | --- | --- | --- | --- | --- | --- |
| `v1.0.0` | **12,941/16,300 (79.39%)** | **13,534/16,300 (83.03%)** | 85.043 | 79 | 148 | 567 |
| `v0.2.0` | 11,989/16,300 (73.55%) | 12,968/16,300 (79.56%) | 59.615 | 54 | 115 | 452 |

### Short-word Context Benchmark-65000

| macOS version | Top1 | Top2 | Contested Top1 | Contested Top2 | Mean (ms) | P50 (ms) | P95 (ms) | Max (ms) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `v1.0.0` | **63,036/65,000 (96.98%)** | **64,103/65,000 (98.62%)** | **10,488/11,728 (89.43%)** | **11,196/11,728 (95.46%)** | 6.801 | 6 | 17 | 40 |
| `v0.2.0` | 61,974/65,000 (95.34%) | 63,568/65,000 (97.80%) | 9,677/11,728 (82.51%) | 10,776/11,728 (91.88%) | 5.971 | 4 | 16 | 63 |

`Contested` is the 11,728-case subset where one Pinyin query maps to at least two target words; it measures how preceding text helps select the intended homophone.

### One-key Completion Context Benchmark-12831

| macOS version | Completion Hit | Avg Keys Saved | Stability | Keystroke P95 (ms) | Final P95 (ms) |
| --- | --- | --- | --- | --- | --- |
| `v1.0.0` | **10,331/12,831 (80.52%)** | 2.638 | **2,117/2,180 (97.11%)** | 1.213 | 9.385 |
| `v0.2.0` | 9,420/12,831 (73.42%) | 2.548 | 1,691/1,749 (96.68%) | 1 | 1 |

Average savings are per correct completion, after charging one key to accept it. Stability counts only adjacent prefixes for which the previous completion remains compatible. v1.0.0 saved 27,250 keys in total; v0.2.0 saved 24,006.

v1.0.0 adds background language-model reranking. Keystroke P95 excludes it; Final P95 includes it when the displayed completion changes. v0.2.0 had no background rerank, so its two values are the same. Its completion timing was recorded in whole milliseconds; v1.0.0 records microseconds and reports milliseconds.

### Long-sentence One-key Completion Benchmark-16300

Leave the final four Pinyin syllables untyped and score the single visible continuation. A hit must extend the intended typed prefix and remain a prefix of the reference sentence. Coverage counts predictive prompts, excluding exact joins of already typed Pinyin; it is not prompt accuracy.

| macOS version | Local Completion Hit | Predictive Prompt Coverage | Total Keys Saved | P95 (ms) |
| --- | --- | --- | --- | --- |
| `v1.0.0` | **3,539/16,300 (21.71%)** | 15,812/16,300 (97.01%) | **7,539** | 131 |
| `v0.2.0` | 450/16,300 (2.76%)<br>*425/16,300 (2.61%)* | 6,778/16,300 (41.58%) | 1,024<br>*988* | 86 |

From macOS v1.0.0, long-completion scoring treats 他 and 她 as equivalent at the same positions. The regular v0.2.0 values were rescored from its saved 16,300 results using this rule; italic values retain its original strict scores. The engine was not rerun, and the old coverage and latency are unchanged. Short-word completion and incremental stability still use strict text equality.

Long-completion production result budgets were 80 ms in v1.0.0 and 50 ms in v0.2.0; these are not full-query latency limits. Tables measure engine query/completion time, excluding model cold start, InputMethodKit/IPC, window rendering and real inter-key delays. They are not end-to-end typing latency.

Test programs, benchmark tools, corpora and per-case reports are not included in the public source distribution.

Release validation covers 600 core regressions, 2,840 simplified/traditional dictionary cases, model execution, IPC, composition recovery and settings persistence, plus real input in native controls, WebKit, Chrome, Electron and Terminal.

## Build and Install

Development requires **Free Pascal 3.2.2, Xcode command-line tools, and Python 3.11+**. Lazarus/LCL is not required. Obtain the generated assets from [Cassotis Lexicon v1.31.0](https://github.com/shenmin/cassotis-lexicon/tree/v1.31.0) and point `CASSOTIS_LEXICON_ROOT` to your checkout (`/path/to/...` is a placeholder):

```sh
export CASSOTIS_LEXICON_ROOT="/path/to/cassotis-lexicon"
./build_all.sh
./install.sh
```

The application is built at `build/arm64/Cassotis.app` and installed to `~/Library/Input Methods/Cassotis.app`. Add 言泉输入法 under System Settings → Keyboard → Text Input, then select it from the input menu. If the input-source list does not refresh, log out and log back in.

By default, Shift switches between Chinese and English input, Space or a number selects a candidate, Tab accepts a completion, and Ctrl+Shift+F10 opens settings. See [CONFIGURATION.md](CONFIGURATION.md) for the full key bindings and data locations.

`./rebuild_all.sh` cleans the build output and performs a complete rebuild. `./uninstall.sh` removes the current user's input method while preserving learned words. See [BUILD.md](BUILD.md) for build prerequisites, model downloads, dictionary imports, packaging, and signing. Builds use a local ad hoc signature by default.

## Source and License

The engine is derived from [Cassotis IME for Windows](https://github.com/shenmin/cassotis-ime), with Free Pascal porting foundations shared with the [Linux version](https://github.com/shenmin/cassotis-ime-linux). macOS 1.0.0 incorporates the Windows 1.31.0 engine changes and [Cassotis Lexicon 1.31.0](https://github.com/shenmin/cassotis-lexicon) dictionaries and models; shared engine updates continue to follow Windows. macOS has its own frontend, releases and benchmark history.

`src/macos` contains the native frontend, `src/service` / `src/ipc` implement the process protocol, `src/engine` / `src/dictionary` contain the shared production core, and `src/host` hosts the local models. See the [architecture document](docs/ARCHITECTURE.md) for module details. Model/schema checksums and lexicon input hashes are in `data/runtime-assets.sha256` and `data/lexicon-inputs.json`; licenses and provenance are described in [NOTICE.md](NOTICE.md). Application code is licensed under GPL-3.0, and the dictionaries use the upstream CC BY-SA 4.0 license.
