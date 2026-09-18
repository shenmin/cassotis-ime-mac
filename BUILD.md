# 构建 Cassotis IME - 言泉输入法

本版本面向 Apple Silicon 和 macOS 14+，使用 Free Pascal 3.2.2、Xcode 命令行工具和 Python 3.11+，不依赖 Lazarus/LCL。其他系统和架构的验证范围见 [COMPATIBILITY.md](COMPATIBILITY.md)。以下命令均在本仓库根目录执行。

## 准备依赖

安装 Xcode 命令行工具（`xcode-select --install`）、Free Pascal 3.2.2 和 Python 3.11+。将 `fpc` 和 `python3` 加入 `PATH`；编译器也可通过 `CASSOTIS_FPC_BIN=/path/to/fpc` 指定。`/path/to/...` 是示例占位路径，请替换为自己的实际位置。

```sh
./scripts/check_environment.sh
```

词库是独立的 [Cassotis Lexicon](https://github.com/shenmin/cassotis-lexicon) 项目。下载或检出其 v1.27.0 版本后，用环境变量指定位置，无需放在固定目录或本仓库旁边：

```sh
export CASSOTIS_LEXICON_ROOT="/path/to/cassotis-lexicon"
```

该目录必须包含 `data/generated/` 下简繁两套共 24 个生成文本。构建时按 `data/lexicon-inputs.json` 验证输入 SHA-256，再导入 schema 24 数据库；基础词条分别为 213,493 / 216,708。词库生成过程和许可见词库项目自身的文档。

九个 ONNX 模型、词表和索引已随源码提供，`data/runtime-assets.sha256` 记录模型和数据库 schema 的校验值。首次构建会下载官方 ONNX Runtime 1.20.1 arm64 发行包，核对固定 SHA-256 后解压。已安装的输入法无需编译器、Python、联网推理或另外下载模型。

## 构建

```sh
./rebuild_all.sh        # 清理 build/ 并完整重建
./build_all.sh          # 增量构建
./build_all.sh --force  # 重新编译 Pascal 单元
./clean_all.sh          # 清理构建产物
```

构建依次生成原生推理桥接库、FPC 引擎、简繁数据库、AppKit 前端和图形安装器，不依赖测试工具或语料。

| 输出 | 用途 |
| --- | --- |
| `build/arm64/Cassotis.app` | 输入法应用，包含引擎、运行库、模型与词库 |
| `build/arm64/言泉输入法安装器.app` | 图形安装器；打包时加入安装负载 |
| `build/arm64/bin/` | 引擎、词库导入器、输入源管理工具及推理运行库 |
| `build/dictionaries/` | 简繁 SQLite 数据库及导入记录 |
| `build/arm64/units/`、`logs/`、`symbols/` | 编译中间文件、日志与调试符号 |

`VERSION` 控制显示版本，`BUILD_NUMBER` 控制应用和安装器的 `CFBundleVersion`。修改后需重新构建；打包器会拒绝版本或构建号不匹配的旧应用。

## 从源码安装

```sh
./install.sh
./uninstall.sh
```

以当前桌面用户运行，不要使用 `sudo`。安装后在“系统设置 → 键盘 → 文字输入 → 编辑 → + → 中文（简体）”中添加言泉输入法，再从菜单栏选用。应用安装到 macOS 的当前用户输入法目录 `~/Library/Input Methods/`；升级和卸载保留用户数据。数据与日志位置见 [CONFIGURATION.md](CONFIGURATION.md)。

## 打包与签名

```sh
./scripts/package.sh
```

输出位于 `dist/`，包括带图形安装器的 DMG、命令行安装 ZIP 和各自的 SHA-256。默认 `-local` 包使用临时签名。拥有 Developer ID 证书时，可以使用自己的身份和钥匙串公证配置：

```sh
./scripts/package.sh --identity 'Developer ID Application: YOUR NAME (TEAMID)' --notary-profile YOUR_PROFILE
```

省略 `--notary-profile` 时生成 `-signed` 包，表示 Developer ID 已签名但未公证。证书、私钥和钥匙串配置由构建者自行管理。打包器使用暂存副本，不修改已安装应用。

评分方法、测试环境和汇总结果见 [BENCHMARK.md](BENCHMARK.md)。测试程序、桌面自动化、基准工具、语料和逐例诊断不随源码分发。

Application assembly projects model manifests onto the same runtime-field allowlist as source export. Runtime thresholds, model hashes and licensing remain intact; training paths and evaluation records are excluded from the installed bundle.
