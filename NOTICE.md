# Third-party notices

Cassotis IME - 言泉输入法 for macOS is a Free Pascal and Objective-C++ port of [Cassotis IME](https://github.com/shenmin/cassotis-ime) and [Cassotis IME for Linux](https://github.com/shenmin/cassotis-ime-linux), developed by Shen Min and the Cassotis contributors. Application source is distributed under GPL-3.0; see [LICENSE](LICENSE). The engine follows Windows 1.26.1 and uses Lexicon 1.26.1. Model and schema hashes are recorded in `data/runtime-assets.sha256`; lexicon input hashes are in `data/lexicon-inputs.json`.

The shared [Cassotis Lexicon](https://github.com/shenmin/cassotis-lexicon) declares CC BY-SA 4.0. The bundled databases are a schema 24 SQLite conversion of the upstream generated text assets, including their derived indexes and language-model tables. Attribution, source manifests and the full CC BY-SA 4.0 license are in `third_party/lexicon/` and in the installed app's `Contents/Resources/licenses/lexicon/`.

Microsoft ONNX Runtime 1.20.1 is distributed under the MIT license. Its license and third-party notices are in `third_party/onnxruntime/`. The build fetches the official macOS arm64 release and verifies the pinned archive checksum. CPU inference uses the same deployed model files as the existing Cassotis projects.

The local repair model derives from the upstream MacBERT model family. Its Apache-2.0 license and attribution are retained in `third_party/macbert/`. Model runtime manifests remain beside their ONNX files.

Free Pascal's runtime library uses its upstream license with the static-linking exception; using it does not change the application's license. Apple's system frameworks and SQLite are supplied by macOS and are not redistributed here.

The benchmark text is from the developer's own novel, *Elegance in Timelessness* / 《永恒的舞动》. Benchmark corpora and their associated source documents are not distributed with the source code or installed application.
