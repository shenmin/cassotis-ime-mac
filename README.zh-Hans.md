# Cassotis IME - 言泉输入法

[English](README.md) | 简体中文 | [繁體中文](README.zh-Hant.md)

言泉输入法的 macOS 版，基于 Windows / Linux 版与 Cassotis Lexicon。

[官网](https://www.yanquan.org/mac) · [下载安装包](https://github.com/shenmin/cassotis-ime-mac/releases) · [Windows](https://github.com/shenmin/cassotis-ime) · [Linux](https://github.com/shenmin/cassotis-ime-linux)

原生 macOS 拼音输入法，使用 **InputMethodKit / AppKit 前端与 Free Pascal 独立引擎**。共享生产引擎对齐 Windows 1.27.0，使用 Lexicon 1.27.0 词库和相同的本地模型。后续更新以 Windows 版为基准。

版本 **0.1.0**（build **1**），面向 Apple Silicon。部署目标 macOS 14+，本轮实测为 M2 Pro / macOS 26.6.2；其他系统和架构的资格范围见 [COMPATIBILITY.md](COMPATIBILITY.md)。

## 主要特性

- 全拼、简拼、微软 / 小鹤 / 自然码 / 搜狗 / 紫光 / 拼音加加双拼。
- 简体与繁体词库，模糊音、分段选词、长句排序与本地修正。
- 固定两行候选窗：首行最多九项、始终保留 Tab 补全行，右下显示 logo 和版本；用户词可点小红 × 删除。
- 原生候选窗与设置，横排不换行、默认 14 点字号、八个配色选项和实时预览；候选窗不抢输入焦点。
- 切换中英文或从其他输入法切入言泉时，在光标旁用短暂的动画气泡显示言泉 logo 和“中”或“英”，并避让附近的系统光标标志；开始输入后自动收起。
- 左侧分类设置、字体名称补全和直接按键录制的五项快捷键；确定选项后自动保存，保留 macOS 系统组合键和安全密码框行为。
- 联合局部纠错与双向复核，Tab 补全复用已确认的拼音前缀修正；输入或退格至未完成声母时保持候选稳定。
- 修复紫光 `sh` / `zh` / `ch`（松 / 总 / 从类音节）解析；对异常拼音和重复元音作保守判断，在候选窗第二行用红色标出错误范围；共享用户词随简繁模式转换显示。
- 改进五音节解码、缓存路径的精确读音检查和重复选择后的前缀排序。
- 没有预测提示时，Tab 可精确拼接已输入拼音对应的词；预测提示使用主题强调色，精确拼接使用普通文字色。
- 所有推理在本机完成，使用 CPU ONNX Runtime；已安装的输入法无需编译器、Python 或联网服务。

## 安装与试用

普通用户下载 DMG，双击其中的“安装言泉输入法”，点击“安装”。完成后点击“打开键盘设置”，在“文字输入 → 编辑 → + → 中文（简体）”中添加言泉输入法，再从菜单栏的输入菜单选用。已添加过的输入源可直接选用；选中时显示彩色言泉 logo。输入 `nihao` 后按空格，可试打“你好”。

图形安装程序显示安装进度，升级保留设置和学习记录，失败时提供日志与重试。使用无需终端、编译器、Python 或另外下载模型。文件名带 `-local` 的包为本机临时签名，带 `-signed` 的包为 Developer ID 签名；这两种测试包均未经过 Apple 公证。卸载入口也在安装程序中；先通过系统设置移除输入源。

## 构建与安装

开发需要 **Free Pascal 3.2.2、Xcode 命令行工具、Python 3.11+**，不依赖 Lazarus/LCL。准备 [Cassotis Lexicon v1.27.0](https://github.com/shenmin/cassotis-lexicon/tree/v1.27.0) 的生成资产，将 `CASSOTIS_LEXICON_ROOT` 指向自己的词库目录（`/path/to/...` 为占位路径）：

```sh
export CASSOTIS_LEXICON_ROOT="/path/to/cassotis-lexicon"
./build_all.sh
./install.sh
```

应用输出到 `build/arm64/Cassotis.app`，安装到 `~/Library/Input Methods/Cassotis.app`。从系统设置 → 键盘 → 文本输入添加言泉输入法，再通过输入菜单启用。若系统列表未刷新，可退出登录后重新登录。

默认 Shift 切换中英文，Space 或数字选择候选，Tab 接受补全，Ctrl+Shift+F10 打开设置。完整按键和数据位置见 [CONFIGURATION.md](CONFIGURATION.md)。

`./rebuild_all.sh` 清理构建输出并完整重建；`./uninstall.sh` 卸载当前用户的输入源并保留学习记录。构建环境、模型下载和词库导入说明见 [BUILD.md](BUILD.md)。默认构建为本机临时签名，打包与签名方法也见构建文档。

## 验证与基准

发行验证覆盖核心输入行为、模型运行、词库导入、IPC、组合输入、故障恢复与设置保存，并验证原生文本控件、WebKit、Chrome、Electron 和 Terminal 中的实际输入。

本轮通过 460 项核心回归和 2,448 条简繁词库用例。完整语料基准满足 Windows v1.27.0 的冻结计数门槛：长句 Top1/Top2 为 **11,969 / 12,955**（−9 / +0），有上下文短词为 **61,860 / 63,549**，短词 Tab 命中 **9,420**（+1）。两种长句补全预算均通过；50 ms 生产轨为 **429** 预测命中、**6,765** 次预测显示、**980** 净节键。已输入拼音的精确拼接单独计数。方法、计时和验证范围见 [BENCHMARK.md](BENCHMARK.md)。测试程序、桌面自动化、基准工具、语料和逐例诊断不随公开源码分发。

## 源码与许可

`src/macos` 是原生前端，`src/service` / `src/ipc` 提供进程协议，`src/engine` / `src/dictionary` 为共享生产核心，`src/host` 是本地模型宿主。模块说明见 [架构文档](docs/ARCHITECTURE.md)。模型/schema 校验值和词库输入哈希分别在 `data/runtime-assets.sha256` 与 `data/lexicon-inputs.json`，许可证与来源见 [NOTICE.md](NOTICE.md)。应用代码使用 GPL-3.0，词库使用上游声明的 CC BY-SA 4.0。
