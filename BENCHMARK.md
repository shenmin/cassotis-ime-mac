# 言泉输入法 macOS 基准测试

macOS 0.1.0 对齐 Windows 1.25.0、Linux 0.7.0 和 Lexicon 1.25.0。四套基准使用相同原始语料、评分和计时范围；长句补全分别验证生产预算与 Windows 准确率对照。完整小说语料不随源码分发；无需这些语料即可构建输入法。

以下为本版引擎与模型配置的验证结果；候选与设置界面另外经过原生及真实桌面验证。公开模型清单仅保留运行配置与来源信息，权重文件不变。

## 测试范围与固定输入

基准测试工具、评分校验程序、固定语料和逐例诊断均不随公开源码分发。本文公开评分方法、环境和汇总结果，供跨版本比较。公开构建入口只构建运行组件，测试与开发诊断工具不随源码分发。

运行器冻结 SC 数据库、原始语料、程序、运行库和源文件快照，记录模型哈希、编译参数与硬件环境，并在结束时重新验证。全量运行串行执行，期间不进行构建、其他推理测试或桌面自动化。用户词库和外部文档上下文关闭；短词有上下文轨仅使用每例规定的左侧文本。

- 长句排名准确率使用确定性工作量限制和固定神经配置，随后单独以生产模式测量完整查询延迟。
- 两套 65,000 条短词轨分别关闭和开启左侧上下文，要求逐例失败签名与 Windows 相同。
- 短词补全从 65,000 个源词产生 12,831 次机会，严格核对显示结果、命中、净节键、稳定性与签名。
- 长句补全均为 16,300 次机会。准确率对照的补全结果预算为 0（无此项时限），生产轨使用 **50 ms**。主排序器的 30 ms 阈值仅记录超时审计，保留已经同步计算完成的结果；局部修正仍以 **30 ms** 拒绝超时结果，与当前 Linux 宿主一致。两条补全轨不能互换。
- 每次长句补全都保留逐例 TSV，计入 decode、最终 `get_candidates` 修正和实际应用的补全结果耗时。Oracle 诊断在取样之后进行，不进入可见延迟。

Darwin 时间使用 `mach_absolute_time`。Pascal 基准按整数毫秒记录，P50/P95 使用 nearest rank，不能把整数采样解释为 Windows 的微秒精度。真实 socket 逐键测试使用 C++ 单调时钟，单独记录亚毫秒数据。

| 固定项 | SHA-256 |
| --- | --- |
| 长句 16,300 原始语料 | `3f50a9323ad798e691f86ea70c6dffa13b4a9f55b624fc3499a138258190ff0f` |
| 短词 65,000 原始语料 | `cd02fc1a24e89a106c200f4864d5ad2c11afd4c8d784059a4b6e9a10c51fbab8` |
| macOS SC 数据库 | `bd409ac7b3d8d090d0442f6f0b922d20fc445584a3da704dae09e2b13fef3ae6` |
| macOS TC 数据库 | `8c24c21a9daea3e5e996065798bce8a30a41954456b8183b1dbb6c1dfe98a4e2` |

SC / TC 基础词条为 213,290 / 216,505，使用v1.25.0 的 24 个生成输入从空目录导入 schema 24。输入校验值与基础词条数见 `data/lexicon-inputs.json`。从 Linux 0.7.0 正式发行包提取的 Windows 预建库，已经与本机重建库逐表双向比较：SC/TC 所有表的内容、行数及全部 schema 定义一致。预建 SC 文件哈希为 `ddec15f2015c3182d971e90656a568d9ec434794dadcf822f3abd77ff0d91acd`，与 macOS 文件不同，因此不宣称 SQLite 文件二进制相同。模型与 Windows 1.25.0 的部署文件逐字节相同。

## Windows / Linux 参考结果

以下准确率来自 Windows 1.25.0 文档与 Linux 0.7.0 的同版本重放记录。Windows 公开表和同输入重放都得到长句 11,698 / 12,830。

| 排名轨 | Windows 1.25.0 Top1 / Top2 | Linux 0.7.0 ARM Top1 / Top2 |
| --- | --- | --- |
| 长句 16,300 | 11,698 / 12,830 | 11,696 / 12,833 |
| 短词 65,000，无上下文 | 60,378 / 63,194 | 60,378 / 63,194 |
| 短词 65,000，有上下文 | 61,859 / 63,549 | 61,859 / 63,549 |
| 有上下文竞争子集 11,728 | 9,596 / 10,775 | 9,596 / 10,775 |

两套短词轨的 7,763 行失败签名固定为 `86a271df3a5b6b97bb510ad39d3c9f3f81eeda412181183dd02f6e211519573a`。短词补全同输入重放为 9,420 命中、12,775 显示、24,006 净节键和 1,691/1,749 稳定性，签名 `0F85F09476081967`；Windows 公开表仍为 9,419 命中，本报告区分两者。

| 长句补全参考 | 显示 | 命中 | 净节键 | 稳定 / 兼容对 |
| --- | --- | --- | --- | --- |
| Windows 1.25.0，无补全时限 | 6,489 | 409 | 959 | 28 / 740 |
| Linux x86_64，无补全时限 | 6,488 | 408 | 956 | 28 / 740 |
| Linux ARM，无补全时限 | 6,491 | 412 | 946 | 26 / 738 |
| Linux ARM，生产 50 ms | 6,492 | 412 | 945 | 26 / 738 |

macOS 在运行前固定门槛：长句 Top1/Top2 及无补全时限的显示、命中、净节键等计数相对 Windows 最多允许 9 的绝对差；净节键下限为 **950**。Linux 单独接受的 ARM 13 键缺口不适用于该门槛。生产 50 ms 另与 Linux 同预算比较；短词的逐例签名和计数要求一致。

参考延迟分别记录平台：Windows 1.25.0 长句平均/P95 57.49/94 ms，有上下文短词 4.705/9.817 ms，长句补全 P95 74.936 ms；Linux ARM 生产长句 84.179/156 ms，生产 50 ms 长句补全 52.031/117 ms。这些来自不同主机，不能据此单独推断编译器快慢；macOS 使用单独固定的延迟和 RSS/HWM 上限。

## macOS 结果

完整运行通过全部四个校验器；所有输入、签名、准确率、延迟和 RSS/HWM 门槛保持运行前的固定值。环境为 Apple M2 Pro / 32 GiB、macOS 26.6.2（25G83）、FPC 3.2.2、Xcode 26.6，使用原生 arm64 程序。

| 排名轨 | macOS Top1 / Top2 | 相对 Windows 1.25.0 的计数差 |
| --- | --- | --- |
| 长句 16,300 | 11,695 / 12,835 | −3 / +5 |
| 短词 65,000，无上下文 | 60,378 / 63,194 | 0 / 0 |
| 短词 65,000，有上下文 | 61,859 / 63,549 | 0 / 0 |
| 有上下文竞争子集 11,728 | 9,596 / 10,775 | 0 / 0 |

两套短词的逐例失败签名与上述 Windows 固定签名完全相同。短词补全为 12,775 次显示、9,420 次命中、24,006 个净节键、1,691/1,749 稳定性，签名 `0F85F09476081967`，与同输入参考回放完全一致。

| 长句补全预算 | 显示 | 命中 | 净节键 | 稳定 / 兼容对 | 对照 |
| --- | --- | --- | --- | --- | --- |
| 0 ms，准确率对照 | 6,494 | 413 | 952 | 26 / 737 | 相对 Windows：命中 +4，净节键 −7 |
| 50 ms，生产预算 | 6,494 | 413 | 952 | 26 / 737 | 相对 Linux ARM 同预算：命中 +1，净节键 +7 |

两条长句补全轨各有 16,300 次机会，签名均为 `D3599591870310AE`，完整句命中均为 21；模型请求 / 接受 / 应用均为 11,458 / 5,310 / 3,759。生产与准确率对照的可见结果一致，两条独立门槛均通过。

| 本机延迟，ms | 平均 | P50 | P95 | 最大 |
| --- | --- | --- | --- | --- |
| 长句，生产整句查询 | 78.984 | 70 | 151 | 639 |
| 短词，无上下文 | 6.981 | 5 | 17 | 49 |
| 短词，有上下文 | 7.606 | 6 | 18 | 49 |
| 短词补全 | 0.765 | 1 | 2 | 12 |
| 长句补全，0 ms 结果预算 | 47.655 | 43 | 107 | 597 |
| 长句补全，50 ms 结果预算 | 47.793 | 44 | 107 | 598 |

生产长句补全的 decode / 最终候选读取 / 可见补全平均分别为 18.451 / 27.639 / 1.702 ms；总延迟包含全部三个阶段。排名基准进程的最大 RSS 为 1,348,752 KiB，最大 HWM 为 1,348,784 KiB，均低于 1,572,864 KiB 的固定上限。


## macOS 专项

模型资格采用三个全新进程、不同参数/环境布局的 500 条回放，要求每个候选路径和补全决定完全一致。当前无补全时限签名为 `CC52A67DE3040900`，请求 374、接受 165、应用 118、命中 10、净节键 16；它不替代完整长句补全。

冷启动验证使用测试专用 native bridge 暂停模型初始化，并验证候选、Space 提交、静态 Tab、长句回退和轮询；恢复真实模型加载后再次验证。另起新进程记录正常启动与逐键延迟，未清空操作系统缓存。测试库不会进入应用或安装包。

IPC 逐键测试 从 16,300 条原始语料中按固定间隔抽样，逐字发送实际 socket 请求，核对每个拼音键被处理，报告均值、P50/P95/P99、最大耗时、超过 100/250 ms 的数量和超时。它包括 IPC、服务和解码，不包含 AppKit 渲染或真实用户停顿。桌面输入由已安装应用的 IMK、浏览器和 Terminal 测试独立验证。

最终已安装 helper 的 200 条 / 6,658 键重放通过，超时为 0。平均 / P50 / P95 / P99 / 最大延迟为 **35.364 / 25.019 / 97.655 / 141.180 / 256.724 ms**，超过 100 ms 的按键为 304 个，超过 250 ms 的为 1 个。结束时 helper RSS 为 1,076,032 KiB，physical footprint 为 432,769 KiB、峰值为 433,681 KiB。

模型初始化被测试屏障暂停时，47 键序列首键 / 最大耗时为 20.241 / 44.468 ms；恢复模型后为 10.494 / 45.836 ms。另一正常新进程的两轮 47 键序列均通过，首键分别为 10.022 / 10.648 ms。前端的九组受控连接启动场景、三轮零等待和三轮常规等待的系统冷启动矩阵，以及十二次原生 Chrome / Electron / Terminal 交接也已通过。

内存分别报告 Darwin resident size（RSS）、进程峰值 HWM 与 helper physical footprint，不能互相替代；多引擎基准的峰值也不等于日常单个输入会话的物理占用。

## Shared Corpus Source

The published benchmarks are all derived from the developer's own novel, [**Elegance in Timelessness**](https://www.qidian.com/book/1037259117/) (Chinese title: [**永恒的舞动**](https://www.qidian.com/book/1037259117/)).

Benchmark-16300 fixes 16,300 eligible sentences, while Benchmark-65000 fixes 65,000 short-word occurrences. The short-word completion benchmark derives 12,831 incremental completion opportunities from the same short-word cases. The long-sentence completion benchmark reuses the long-sentence corpus to derive 16,300 near-tail opportunities. Benchmark cases are kept separate from the corresponding model-training data.

## Shared Accuracy Equivalence Rule

The following rule applies to visible-candidate accuracy metrics in the long-sentence and short-word context suites, including `Top1`, `Top2`, other reported `TopN` values, and the short-word `Contested` metrics:

- `他` and `她` are treated as equivalent only when they occur at the same character positions, because the benchmark Pinyin query cannot distinguish them.
- `它`, all other homophones, missing or additional characters, and every other textual difference remain distinct.
- The rule changes only offline pass/fail scoring. It does not rewrite candidate text or alter candidate generation, ranking, latency, or user-dictionary behavior.
- Raw-pool and Oracle recall scoring retains strict character equality so that the target label cannot influence search behavior. It is therefore not directly comparable with equivalence-aware visible `TopN` metrics.

This equivalence rule applies to benchmark results starting with `v1.11.0`. Results for `v1.10.0` and earlier releases used strict character equality and should be rescored before direct comparison with `v1.11.0` or later results.

## Long Sentence Benchmark-16300

### Corpus Scale and Case Construction

Benchmark-16300 contains 16,300 eligible sentences extracted from the novel in a fixed order. Its cases are constructed as follows:

- Split the novel text by punctuation and line breaks.
- Ignore sentences containing English letters.
- Ignore sentences shorter than the configured minimum CJK length.
- Convert each complete sentence to Pinyin with the benchmark reverse-Pinyin builder.
- Feed the complete Pinyin query to the engine and dictionary version under test.

### Accuracy Scoring

- A case is a `Top1` pass when the first complete candidate matches the original sentence under the shared scoring rule above.
- A case is a `Top2` pass when either of the first two complete candidates matches the original sentence under the shared scoring rule above.

### Accuracy and Latency Modes

- Accuracy runs use deterministic-work mode: normal search paths do not stop on wall-clock time and remain bounded by fixed beam, state, edge, candidate, and work limits. Changes in machine load therefore do not change normal candidate generation.
- Latency runs use production mode: fixed work limits are the primary boundary, with wider emergency wall-clock ceilings retained to prevent unacceptable stalls on malformed long Pinyin or slower machines.
- Both modes load the same deployed long-sentence Transformer reranker as the Host. A missing or incomplete runtime is an error rather than a silent fallback; disabling it is reserved for explicitly labelled diagnostic runs.
- The two measurements are run separately. The macOS runner evaluates cases serially.

### Latency Protocol

Long-sentence latency values measure engine-only full-query decoding:

- Process the fixed 16,300 cases serially in one runner process and in corpus order.
- Use a snapshot of the simplified base dictionary selected for the tested release and disable the user dictionary by default.
- Reset the engine composition state before each case while retaining the same dictionary connection and runtime caches for the complete run.
- Assign the complete Pinyin query in one operation, then generate and read the candidate list.
- Measure from immediately before query assignment until candidate retrieval finishes.
- Exclude process startup, dictionary opening, reverse-Pinyin conversion, report writing, InputMethodKit integration, candidate-window rendering, real keystrokes, and inter-key timing.

## Short-word Context Benchmark-65000

### Corpus Scale and Case Construction

Benchmark-65000 measures word-by-word input with preceding text and uses the same novel text as the long-sentence benchmark as its source:

- Deterministically segment each sentence and normalize the result into two- to four-character units that represent ordinary short-word input habits.
- Admit only manually reviewed lexical units and exclude novel-specific proper nouns, so the benchmark measures general input behavior rather than memorization of story-specific names.
- Treat each eligible occurrence as one case and preserve the sentence prefix that a user would already have committed before typing that unit.
- Convert the target unit to Pinyin independently, with reviewed overrides for ambiguous readings.
- Keep cases in source-text order and freeze the first 65,000 eligible occurrences as Benchmark-65000.
- Evaluate with a snapshot of the selected simplified dictionary; user-dictionary ranking is disabled by default.

The frozen set contains 55,712 cases with usable left context and 9,288 sentence-initial cases without left context.

### Accuracy and Contested Scoring

- A case is a `Top1` pass when the first exact candidate matches the target unit under the shared scoring rule above.
- A case is a `Top2` pass when either of the first two exact candidates matches the target unit under the shared scoring rule above.
- `Contested` is the 11,728-case subset in which the same Pinyin query maps to at least two target words in the corpus. `Contested Top1` and `Contested Top2` isolate the cases where left context is most useful for disambiguation.
- Short-word results use the context-enabled benchmark.

### Latency Protocol

Short-word latency values measure engine-only candidate retrieval for the context-enabled track:

- Process all 65,000 cases serially in one runner process and in fixed corpus order.
- Reset the engine before each query while retaining the same dictionary connection and runtime caches.
- Install the already committed sentence prefix before timing, assign the complete target Pinyin query, and stop timing after candidate retrieval.
- Exclude corpus segmentation, Pinyin generation, process startup, dictionary opening, report writing, InputMethodKit integration, candidate-window rendering, real keystrokes, and inter-key timing.

## One-key Completion Context Benchmark-12831

### Case Construction and Scoring

The completion benchmark reuses the frozen Benchmark-65000 cases and their left context to measure one-key continuation before the target word has been fully typed:

- Evaluate only targets containing at least three complete Pinyin syllables.
- Starting after two syllables, advance one syllable at a time and stop before the complete Pinyin. Each intermediate state is one completion opportunity.
- For example, the target `往常一样` is queried at both `wangchang` and `wangchangyi`.
- The complete 65,000-source corpus deterministically produces 12,831 opportunities, hence the name One-key Completion Context Benchmark-12831.
- Use the simplified base-dictionary snapshot for the tested release, disable the user dictionary, and enable left context.
- Read only the single completion that the UI would display. It is a hit only when it strictly equals the corpus target; the `他`/`她` equivalence rule is not applied.

The benchmark records four metrics that are straightforward to interpret across releases:

- `Completion Hit`: correct completions divided by all 12,831 opportunities; this is the primary quality metric.
- `Avg Keys Saved`: average net keystrokes saved by each correct completion, after charging one keystroke for accepting it.
- `Stability`: when the previous completion remains compatible after another syllable is typed, the proportion for which the displayed completion remains unchanged.
- `P95`: 95% of completion queries finish within this many milliseconds.

Because each corpus position has only one reference target, a different but linguistically valid completion is still scored as a miss.

### Latency Protocol

Latency covers dictionary lookup, context/language-model scoring, completion selection, and hysteresis only. It excludes process and dictionary cold start, helper IPC, candidate-window rendering, real inter-key timing, and learning writes after acceptance. The engine is reset before each source case; adjacent prefixes of the same target are processed consecutively, while the dictionary connection and runtime caches remain open for the complete run.

## Long-sentence One-key Completion Benchmark-16300

### Case Construction and Scoring

This benchmark measures whether one-key completion can extend a partially decoded long sentence, instead of inferring completion quality from the unrelated long-sentence candidate-ranking score:

- Reuse all 16,300 fixed long-sentence cases and their reviewed full Pinyin queries.
- Leave the final four complete Pinyin syllables untyped while retaining at least the first four syllables as the visible composition prefix.
- Decode that prefix in deterministic-work mode with the same long-sentence Transformer reranker used by the Host.
- Run the same constrained local-completion model when the static layer requests asynchronous refinement, apply the same confidence, timeout, and exact-path validation, then read only the single settled completion that the UI would display.
- Count a local-continuation hit when the displayed result strictly extends the intended typed prefix and the whole displayed text remains a prefix of the reference sentence. The completion may stop after the next one to three local words; it does not have to reproduce the rest of the sentence in one step.
- Disable the user dictionary and external document context, and use a snapshot of the simplified base dictionary selected for the tested release.
- Query the immediately preceding syllable boundary before the scored query to measure whether a compatible completion remains stable as typing continues.

The public report uses four metrics suited to direct cross-version comparison under the current protocol:

- `Local Completion Hit`: correct local continuations divided by all 16,300 opportunities.
- `Prompt Coverage`: opportunities where any completion was displayed, divided by all opportunities.
- `Total Keys Saved`: net keys saved across all correct local-continuation hits after charging one key for each acceptance.
- `P95`: 95% of visible completion queries finish within this many milliseconds.

The detailed report additionally retains average keys saved per hit, incremental stability, wrong-prompt counts, strict whole-sentence hits, and internal-pool Oracle ranks for attribution. Incremental stability is not published as a primary comparison because its eligible denominator depends on the prompts produced by each version and can be very small. Because the corpus supplies one reference, a plausible continuation with different wording still counts as a miss.

### Latency Protocol

The dictionary and runtime models are loaded and warmed before scored cases begin. Latency starts immediately before assigning the scored Pinyin prefix and includes long-sentence decoding, exact/transition lookup, language-model scoring, hysteresis, local correction during final candidate readback, and accepted continuation-model refinement. Continuation-model work that abstains or times out is asynchronous and does not delay the visible static result, so it is not added to visible latency. The measurement excludes process and model cold start, the preceding stability probe, report output, InputMethodKit-to-helper IPC, rendering, real inter-key timing, and learning writes. The engine is reset before every source sentence while dictionary connections, model sessions, and runtime caches remain open for the complete run.
