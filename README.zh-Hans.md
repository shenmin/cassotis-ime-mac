# Cassotis IME - 言泉输入法

<p align="center">
  <img src="docs/images/cassotis-logo.png" alt="Cassotis IME - 言泉输入法 logo" width="280">
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue" alt="License: GPL-3.0"></a>
  <a href="COMPATIBILITY.md"><img src="https://img.shields.io/badge/platform-macOS-000000?logo=apple&amp;logoColor=white" alt="Platform: macOS"></a>
  <a href="BUILD.md"><img src="https://img.shields.io/badge/arch-Apple%20Silicon-5a67d8" alt="Architecture: Apple Silicon"></a>
</p>

<p align="center">
  <img src="docs/images/macos-preview.png" alt="言泉输入法 macOS 版晴白、青瓷与靛夜主题的候选窗和 Tab 补全展示" width="600">
</p>

<p align="center"><sub>macOS 原生候选窗 · Tab 补全 · 晴白、青瓷与靛夜主题</sub></p>

[English](README.md) | 简体中文 | [繁體中文](README.zh-Hant.md)

Cassotis IME - 言泉输入法是一款面向 macOS 的开源中文拼音输入法，提供原生候选窗、本地语言模型和保存在本机的用户词学习。

[官网](https://www.yanquan.org/mac) · [下载安装包](https://github.com/shenmin/cassotis-ime-mac/releases) · [Windows](https://github.com/shenmin/cassotis-ime) · [Linux](https://github.com/shenmin/cassotis-ime-linux)

使用 **InputMethodKit / AppKit 前端与 Free Pascal 独立引擎**，融入 macOS 原生文字输入。词库和模型随包提供，候选排序、句子修正与 Tab 补全均在本机完成。

版本 **1.0.0**（build **3**），支持 Apple Silicon 和 macOS 14 及以上。已验证范围和已知限制见 [COMPATIBILITY.md](COMPATIBILITY.md)。

## 主要特性

- 全拼、简拼、微软 / 小鹤 / 自然码 / 搜狗 / 紫光 / 拼音加加双拼。
- 简体与繁体词库，模糊音、分段选词、长句排序与本地修正。
- 默认两行候选窗，可在翻页时展开为三行候选：每行最多九项、始终保留 Tab 补全行，右下显示 logo 和版本；用户词可点小红 × 删除。
- 原生候选窗与设置，横排不换行、默认 14 点字号、八个配色选项和实时预览；候选窗不抢输入焦点。
- 切换中英文或从其他输入法切入言泉时，在光标旁用短暂的动画气泡显示言泉 logo 和“中”或“英”，并避让附近的系统光标标志；开始输入后自动收起。
- 左侧分类设置、字体名称补全和直接按键录制的五项快捷键；确定选项后自动保存，保留 macOS 系统组合键和安全密码框行为。
- 联合局部纠错与双向复核，Tab 补全复用已确认的拼音前缀修正；输入或退格至未完成声母时保持候选稳定。
- 修复紫光 `sh` / `zh` / `ch`（松 / 总 / 从类音节）解析；对异常拼音和重复元音作保守判断，在候选窗底部用红色标出错误范围；共享用户词随简繁模式转换显示。
- 改进五音节解码、缓存路径的精确读音检查和重复选择后的前缀排序。
- 没有预测提示时，Tab 可精确拼接已输入拼音对应的词；预测提示使用主题强调色，精确拼接使用普通文字色。
- 共享字符级语言模型统一改善长句、上下文短词、混合简拼和 Tab 续写，保留用户学习和精确整词保护。
- Tab 同时比较当前词补全、后续短语与下一个字建议；短词先显示词库结果，再在后台重排，保护显式拼音音节边界。
- 新增专业词精确输入，多音字补充读音不重复累计文字热度；共享模型编码和拼音缓存降低计算开销。
- 所有推理在本机完成，使用 CPU ONNX Runtime；已安装的输入法无需编译器、Python 或联网服务。

## 安装与试用

普通用户下载 DMG，双击其中的“言泉输入法安装器”，点击“安装”。安装器会自动请求启用；若 macOS 弹出确认，点击“允许”。显示“安装完成”后，直接从菜单栏的输入菜单选择言泉输入法，选中时显示彩色言泉 logo。输入 `nihao` 后按空格，可试打“你好”。若尚未启用，可点击“重试启用”，或通过“打开键盘设置”手动添加。

macOS 27 上可能只打开键盘设置而不弹出确认。请在“文字输入 → 编辑 → + → 中文（简体）”中添加“言泉输入法”，再返回安装器；安装器会自动核实启用状态。

图形安装程序显示安装进度，升级保留设置和学习记录，失败时提供日志与重试。使用无需终端、编译器、Python 或另外下载模型。v1.0.0 下载文件为 `cassotis-ime-macos-1.0.0-arm64-installer-signed.dmg`，已使用 Sunisoft Limited 的 Developer ID 签名并完成 Apple 公证。文件名带 `-local` 的本机开发包使用临时签名。卸载入口也在安装程序中；先通过系统设置移除输入源。

## 基准测试

以下使用相同的完整语料，对比 macOS v1.0.0 与前一版 v0.2.0。表中的版本号均为 macOS 产品版本。

测试方法、评分规则和详细结果见 [BENCHMARK.md](BENCHMARK.md)。语料来自开发者自己的小说著作 [《永恒的舞动》](https://www.qidian.com/book/1037259117/)。

两版均在 Apple M2 Pro、32 GiB 内存上以原生 arm64 程序测量：v1.0.0 使用 macOS 27.0.1，v0.2.0 使用 macOS 27.0。以下保留各版发布时的实测耗时，并非将两版在当前系统重新运行。

### Cassotis 长句语料基准测试-16300

| macOS 版本 | Top1 | Top2 | 平均 (ms) | P50 (ms) | P95 (ms) | 最大 (ms) |
| --- | --- | --- | --- | --- | --- | --- |
| `v1.0.0` | **12,941/16,300 (79.39%)** | **13,534/16,300 (83.03%)** | 85.043 | 79 | 148 | 567 |
| `v0.2.0` | 11,989/16,300 (73.55%) | 12,968/16,300 (79.56%) | 59.615 | 54 | 115 | 452 |

### 短词上下文基准测试-65000

| macOS 版本 | Top1 | Top2 | 竞争词 Top1 | 竞争词 Top2 | 平均 (ms) | P50 (ms) | P95 (ms) | 最大 (ms) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `v1.0.0` | **63,036/65,000 (96.98%)** | **64,103/65,000 (98.62%)** | **10,488/11,728 (89.43%)** | **11,196/11,728 (95.46%)** | 6.801 | 6 | 17 | 40 |
| `v0.2.0` | 61,974/65,000 (95.34%) | 63,568/65,000 (97.80%) | 9,677/11,728 (82.51%) | 10,776/11,728 (91.88%) | 5.971 | 4 | 16 | 63 |

“竞争词”是同一拼音对应至少两个目标词的 11,728 例子集，用于衡量结合前文进行同音选词的效果。

### 一键补全上下文基准测试-12831

| macOS 版本 | 补全命中率 | 平均节省按键 | 逐键稳定率 | 按键 P95 (ms) | 最终显示 P95 (ms) |
| --- | --- | --- | --- | --- | --- |
| `v1.0.0` | **10,331/12,831 (80.52%)** | 2.638 | **2,117/2,180 (97.11%)** | 1.213 | 9.385 |
| `v0.2.0` | 9,420/12,831 (73.42%) | 2.548 | 1,691/1,749 (96.68%) | 1 | 1 |

平均节省按键按每次正确补全计算，已扣除接受补全的一次按键；逐键稳定率只统计继续输入后原补全仍兼容的机会。v1.0.0 合计净节省 27,250 键，v0.2.0 为 24,006 键。

v1.0.0 新增后台语言模型重排：按键 P95 不包含重排，最终显示 P95 在提示改变时计入重排耗时。v0.2.0 没有后台重排，两项数值相同；旧版补全计时精度为整数毫秒，新版以微秒采样后换算为毫秒。

### Cassotis 长句一键补全基准测试-16300

每条长句保留末尾四个拼音音节不输入，评估界面显示的唯一续写。正确结果须扩展已输入的目标前缀，并仍是参考句的前缀。覆盖率仅统计预测提示，不含已输入拼音的精确拼接，也不代表提示准确率。

| macOS 版本 | 局部续写命中率 | 预测提示覆盖率 | 总节省按键 | P95 (ms) |
| --- | --- | --- | --- | --- |
| `v1.0.0` | **3,539/16,300 (21.71%)** | 15,812/16,300 (97.01%) | **7,539** | 131 |
| `v0.2.0` | 450/16,300 (2.76%)<br>*425/16,300 (2.61%)* | 6,778/16,300 (41.58%) | 1,024<br>*988* | 86 |

macOS v1.0.0 起，长句补全评分将相同位置的“他/她”视为等价。v0.2.0 的常规数字由保存的 16,300 条结果按新口径重评，斜体保留原始严格口径；没有重跑旧版引擎，覆盖率与耗时保持原实测值。短词补全和逐键稳定性仍采用严格匹配。

长句补全生产结果预算分别为 v1.0.0 的 80 ms、v0.2.0 的 50 ms，不等于完整查询耗时上限。表中延迟为引擎查询或补全过程耗时，不含模型冷启动、InputMethodKit/IPC、候选窗绘制及实际按键间隔，不能视为端到端输入延迟。

测试程序、基准工具、语料和逐例报告不随公开源码分发。

发行验证覆盖 600 项核心回归、2,840 条简繁词库用例、模型运行、IPC、组合输入恢复与设置保存，以及原生文本控件、WebKit、Chrome、Electron 和 Terminal 中的实际输入。

## 构建与安装

开发需要 **Free Pascal 3.2.2、Xcode 命令行工具、Python 3.11+**，不依赖 Lazarus/LCL。准备 [Cassotis Lexicon v1.31.0](https://github.com/shenmin/cassotis-lexicon/tree/v1.31.0) 的生成资产，将 `CASSOTIS_LEXICON_ROOT` 指向自己的词库目录（`/path/to/...` 为占位路径）：

```sh
export CASSOTIS_LEXICON_ROOT="/path/to/cassotis-lexicon"
./build_all.sh
./install.sh
```

应用输出到 `build/arm64/Cassotis.app`，安装到 `~/Library/Input Methods/Cassotis.app`。从系统设置 → 键盘 → 文本输入添加言泉输入法，再通过输入菜单启用。若系统列表未刷新，可退出登录后重新登录。

默认 Shift 切换中英文，Space 或数字选择候选，Tab 接受补全，Ctrl+Shift+F10 打开设置。完整按键和数据位置见 [CONFIGURATION.md](CONFIGURATION.md)。

`./rebuild_all.sh` 清理构建输出并完整重建；`./uninstall.sh` 卸载当前用户的输入源并保留学习记录。构建环境、模型下载和词库导入说明见 [BUILD.md](BUILD.md)。默认构建为本机临时签名，打包与签名方法也见构建文档。

## 源码与许可

引擎衍生自 [Cassotis IME Windows 版](https://github.com/shenmin/cassotis-ime)，Free Pascal 移植基础与 [Linux 版](https://github.com/shenmin/cassotis-ime-linux) 共用。macOS 1.0.0 合入 Windows 1.31.0 的引擎改进，使用 [Cassotis Lexicon 1.31.0](https://github.com/shenmin/cassotis-lexicon) 词库与模型；共享引擎的后续更新继续跟进 Windows。macOS 版独立维护原生界面、产品发行和基准历史。

`src/macos` 是原生前端，`src/service` / `src/ipc` 提供进程协议，`src/engine` / `src/dictionary` 为共享生产核心，`src/host` 是本地模型宿主。模块说明见 [架构文档](docs/ARCHITECTURE.md)。模型/schema 校验值和词库输入哈希分别在 `data/runtime-assets.sha256` 与 `data/lexicon-inputs.json`，许可证与来源见 [NOTICE.md](NOTICE.md)。应用代码使用 GPL-3.0，词库使用上游声明的 CC BY-SA 4.0。
