# Third-party notices

Cassotis IME - 言泉输入法 for macOS is a Free Pascal and Objective-C++ port of [Cassotis IME](https://github.com/shenmin/cassotis-ime) and [Cassotis IME for Linux](https://github.com/shenmin/cassotis-ime-linux), developed by Shen Min and the Cassotis contributors. Application source is distributed under GPL-3.0; see [LICENSE](LICENSE). The engine and dictionaries follow the Windows / Cassotis Lexicon v2.4.0 releases. Model and schema hashes are recorded in `data/runtime-assets.sha256`; lexicon input hashes are in `data/lexicon-inputs.json`.

The shared [Cassotis Lexicon](https://github.com/shenmin/cassotis-lexicon) declares CC BY-SA 4.0. The bundled databases are a schema 24 SQLite conversion of the upstream generated text assets, including their derived indexes and language-model tables. The THUOCL specialist vocabulary retains its own license in `third_party/lexicon/THUOCL-LICENSE.txt`. Classical poetry texts supplied by chinese-poetry retain their MIT notice in `third_party/lexicon/CHINESE-POETRY-LICENSE.txt`. Attribution, source manifests and the full CC BY-SA 4.0 license are in `third_party/lexicon/` and in the installed app's `Contents/Resources/licenses/lexicon/`.

Traditional/simplified character mappings use pinned OpenCC 1.1.9 dictionary tables (commit `556ed22496d650bd0b13b6c163be9814637970ae`), under Apache License 2.0. The generated table records each source checksum; `tools/build_traditional_chars.py` reproduces it. See [OpenCC](https://github.com/BYVoid/OpenCC) and `third_party/opencc/LICENSE`; the application includes the license as `Contents/Resources/licenses/OpenCC.txt`.

Microsoft ONNX Runtime 1.20.1 is distributed under the MIT license. Its license and third-party notices are in `third_party/onnxruntime/`. The build fetches the official macOS arm64 release and verifies the pinned archive checksum. CPU inference uses the same deployed model files as the existing Cassotis projects.

The shared character language model was trained by the Cassotis project from separately licensed corpora; training documents are not redistributed. This single model serves sentence ranking, contextual words, phrase generation, Pinyin-constrained correction and Tab continuations. Its runtime manifest remains beside the ONNX file.

English recognition uses a filtered subset of Alan Beale's public-domain 12Dicts, packaged by Kevin Atkinson, together with project-derived spelling frequency bands and compact letter-sequence tables. The generated `src/engine/nc_english_words.inc` retains its pinned source URL and SHA-256. It contains spellings and bands only, not corpus passages. See [the upstream word-list directory](https://github.com/en-wl/wordlist/tree/b22230cc5250887737fdefe9ca4c9d9d01230eaa/alt12dicts) and `third_party/english/NOTICE`.

Free Pascal's runtime library uses its upstream license with the static-linking exception; using it does not change the application's license. Apple's system frameworks and SQLite are supplied by macOS and are not redistributed here.

The benchmark text is from the developer's own novel, *Elegance in Timelessness* / 《永恒的舞动》. Benchmark corpora and their associated source documents are not distributed with the source code or installed application.
