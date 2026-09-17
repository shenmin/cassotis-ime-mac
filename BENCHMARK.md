# 言泉输入法 macOS 基准测试

macOS **0.1.0（build 1）** 的生产引擎、模型与词库对齐 **Windows / Cassotis Lexicon v1.27.0**。本页为此次引擎更新后的重新测量，macOS 版本号与 build number 保持不变。

基准工具、语料、评分校验程序和逐例诊断不随公开源码分发。本文保留评分方法、来源、环境和汇总结果；构建与运行输入法无需这些内部测试材料。

## 测试方法与固定输入

完整运行串行执行，期间暂停构建、其他推理测试和桌面自动化。每次运行冻结数据库、原始语料、程序、运行库、共享核心和验收规则，并在结束时重验指纹。关闭用户学习和外部文档上下文；短词有上下文轨只使用每例规定的左侧文本。

- 长句排名：16,300 条，确定性工作量限制测准确率，另用生产模式测完整查询延迟；跟随 Windows v1.27.0，仅检查候选列表前两个位置的整句精确匹配，统计 Top1/Top2，不再列长句 Top5/Top9。
- 短词排名：两条各 65,000 例，分别关闭和开启左侧上下文；含 11,728 例竞争子集，保留短词 Top5/Top9。
- 短词补全：12,831 次机会，核对命中、显示、净节键与稳定性。
- 长句补全：两条各 16,300 次机会，分别采用 0 ms（无补全结果时限）的准确率对照和 50 ms 生产结果预算，分别验收。
- 长句补全仅将真正预测后续文字的结果计入预测显示、命中、失误和净节键。精确拼接已输入拼音的提示单独计数，也不作为预测稳定性的前一次锚点；逐例记录当前与前一次补全来源并独立重算。
- 计时遵循生产顺序：解码及预取、最终候选读取与局部纠错、可见补全处理；Oracle 诊断在计时之后执行。生产联合修正保留 30 ms 接受预算、词库路径检查和双向复核。

Darwin 使用 `mach_absolute_time`；Pascal 报告为整数毫秒，百分位采用 nearest rank。真实 socket 逐键回放使用单调时钟另行报告亚毫秒数据。环境为 Apple M2 Pro / 32 GiB、macOS 26.6.2（25G83）、FPC 3.2.2 和原生 arm64 程序。不同主机的延迟不能直接用于归因编译器差异。

| 固定项 | SHA-256 |
| --- | --- |
| 长句 16,300 原始语料 | `3f50a9323ad798e691f86ea70c6dffa13b4a9f55b624fc3499a138258190ff0f` |
| 短词 65,000 原始语料 | `cd02fc1a24e89a106c200f4864d5ad2c11afd4c8d784059a4b6e9a10c51fbab8` |
| macOS SC 数据库 | `23b535c64dcfee447ea7b5e30945f54efa6d01cf38213c3b1f1a129bb24c42dd` |
| macOS TC 数据库 | `4e24781f6b9e4d30fd05c421082bc2bb5f502db1dba8bb41c667caecf9c87ddd` |

SC / TC 基础词条为 **213,493 / 216,708**，由 Lexicon v1.27.0 的 24 个生成输入重建 schema 24。17 个模型/schema 原始输入与 Windows 目标标签逐字节相同。九个 ONNX 图原样部署；模型清单仅移除非运行元数据，运行阈值保持不变。本轮没有重新训练或修改权重。数据库逻辑一致性按 schema 和每张表双向核对，不能仅依赖 SQLite 文件布局或文件哈希。

## Windows 参考与验收规则

参考为 [Windows v1.27.0 标签 README](https://github.com/shenmin/cassotis-ime/blob/v1.27.0/README.md) 的正式表：

| 排名轨 | Windows Top1 | Windows Top2 |
| --- | ---: | ---: |
| 长句 16,300 | 11,978 | 12,955 |
| 有上下文短词 65,000 | 61,860 | 63,549 |
| 有上下文竞争子集 11,728 | 9,596 | 10,775 |

短词 Tab 参考为 **9,419 / 12,831** 命中、每命中平均 **2.549** 净节键、稳定 **1,691 / 1,749**。长句预测补全参考为 **425** 命中、**6,769** 预测显示、**987** 净节键。Windows 长句查询平均 / P95 为 63.08 / 109 ms，有上下文短词为 4.474 / 9.310 ms，短词补全 P95 为 2.026 ms，长句补全 P95 为 80.099 ms。

参考和门槛在新版首次本机测量前冻结。公开可对照的计数最多允许 **9** 的绝对差；长句补全净节键范围为 **978–996**。既有性能预算继续适用：长句平均 / P95 不超过 110 / 200 ms，短词不超过 12 / 30 ms，排名进程 RSS / HWM 不超过 1.5 GiB。长句稳定性依据逐例记录重算；Windows 新表没有发布该项的固定计数，不把旧口径数值作为新版参考。

## macOS 结果

完整基准通过全部四个固定校验器。排名及两种补全预算的原始轨迹均绑定完整语料并独立重算，三个独立进程中的各 500 条候选、路径、分数和补全决策也完全一致。

| 排名轨 | macOS Top1 / Top2 | 相对 Windows 公开参考的计数差 |
| --- | ---: | ---: |
| 长句 16,300 | 11,969 / 12,955 | −9 / +0 |
| 有上下文短词 65,000 | 61,860 / 63,549 | +0 / +0 |
| 有上下文竞争子集 11,728 | 9,596 / 10,775 | +0 / +0 |

无上下文短词为 **60,378 / 63,194**，Top5 / Top9 为 64,531 / 64,652；有上下文 Top5 / Top9 为 64,573 / 64,652。未在当前 Windows 公开表单列的短词指标沿用既有冻结参考。

短词 Tab 为 **9,420 / 12,831** 命中、**12,775** 显示、**24,006** 净节键、每命中平均 **2.548**，稳定 **1,691 / 1,749**；命中相对 Windows 为 **+1**，签名 `0F85F09476081967`。

| 长句补全结果预算 | 预测显示 | 精确拼接显示 | 预测命中 | 净节键 | 稳定 / 兼容对 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 ms，准确率对照 | 6,765 | 3,038 | 429 | 980 | 25 / 766 |
| 50 ms，生产预算 | 6,765 | 3,038 | 429 | 980 | 25 / 766 |

两条长句补全轨的可见结果逐例一致。准确率轨相对 Windows 的预测显示 / 命中 / 净节键差为 **−4 / +4 / −7**；生产轨为 **−4 / +4 / −7**。签名分别为 `D127E38EAE8A4F6B` / `D127E38EAE8A4F6B`。精确拼接中与目标已输入前缀相同的提示分别为 1,516 / 1,516，这些提示不记预测命中或节键。

生产轨神经请求 / 接受 / 应用为 11,780 / 5,537 / 3,911，完整句命中 20。解码 / 最终候选读取 / 可见补全处理平均分别为 18.733 / 31.102 / 1.746 ms，合计 51.580 ms。

| 本机延迟，ms | 平均 | P50 | P95 | 最大 |
| --- | ---: | ---: | ---: | ---: |
| 长句，生产整句查询 | 84.815 | 76 | 162 | 644 |
| 短词，无上下文 | 7.185 | 6 | 18 | 56 |
| 短词，有上下文 | 7.849 | 6 | 19 | 51 |
| 短词 Tab 补全 | 0.768 | 1 | 2 | 14 |
| 长句补全，0 ms 结果预算 | 51.206 | 47 | 117 | 622 |
| 长句补全，50 ms 结果预算 | 51.580 | 47 | 118 | 620 |

排名进程最大 RSS / HWM 为 **1,287,536 / 1,287,568 KiB**，低于冻结的 1,572,864 KiB 上限。RSS、进程 HWM 与 physical footprint 是不同指标，不能混写。完整查询计时不包含模型冷启动、InputMethodKit 事件传递、IPC、候选窗绘制或真实按键间隔。

最终安装引擎另做 200 条 / **6,658** 键的独立用户数据库回放，**0 超时**。同步 IPC 往返平均 / P50 / P95 / P99 / 最大为 **38.289 / 27.876 / 101.938 / 145.106 / 255.982 ms**；超过 100 / 250 ms 的按键分别为 356 / 2。该计时包含逐键引擎处理及进程通信，不包含 IMK 事件、绘制和后续异步结果呈现，因此不等于完整端到端输入延迟。

The English methodology below follows the [Windows v1.27.0 benchmark definitions](https://github.com/shenmin/cassotis-ime/blob/v1.27.0/BENCHMARK.md). Historical v1.x version numbers in this section refer to Windows releases; macOS remains 0.1.0 (build 1).

## Shared Corpus Source

All four benchmarks are derived from the developer's own novel, [**Elegance in Timelessness**](https://www.qidian.com/book/1037259117/) (Chinese title: [**永恒的舞动**](https://www.qidian.com/book/1037259117/)).

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

- A case is a `Top1` pass when the first candidate is complete and matches the original sentence under the shared scoring rule above.
- A case is a `Top2` pass when either of the first two candidate entries is complete and matches the original sentence under the shared scoring rule above.

### Accuracy and Latency Modes

- Accuracy runs use deterministic-work mode: normal search paths do not stop on wall-clock time and remain bounded by fixed beam, state, edge, candidate, and work limits. Changes in machine load therefore do not change normal candidate generation.
- Latency runs use production mode: fixed work limits are the primary boundary, with wider emergency wall-clock ceilings retained to prevent unacceptable stalls on malformed long Pinyin or slower machines.
- Both modes load the same deployed long-sentence Transformer reranker as the Host. A missing or incomplete runtime is an error rather than a silent fallback; disabling it is reserved for explicitly labelled diagnostic runs.
- The two measurements are run separately. Both macOS tracks execute serially in corpus order.

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

- A case is a `Top1` pass when the first candidate is exact and matches the target unit under the shared scoring rule above.
- A case is a `Top2` pass when either of the first two candidate entries is exact and matches the target unit under the shared scoring rule above.
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

Latency covers dictionary lookup, context/language-model scoring, completion selection, and hysteresis only. It excludes process and dictionary cold start, InputMethodKit/helper communication, candidate-window rendering, real inter-key timing, and learning writes after acceptance. The engine is reset before each source case; adjacent prefixes of the same target are processed consecutively, while the dictionary connection and runtime caches remain open for the complete run.

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
- `Predictive Prompt Coverage`: opportunities where a predictive completion was displayed, divided by all opportunities. Exact-word joins that only convert already typed Pinyin are excluded from prediction coverage and prediction misses.
- `Total Keys Saved`: net keys saved across all correct local-continuation hits after charging one key for each acceptance.
- `P95`: 95% of visible completion queries finish within this many milliseconds.

The detailed report additionally retains average keys saved per hit, incremental stability, wrong-prompt counts, strict whole-sentence hits, and internal-pool Oracle ranks for attribution. Incremental stability is not published as a primary comparison because its eligible denominator depends on the prompts produced by each version and can be very small. Because the corpus supplies one reference, a plausible continuation with different wording still counts as a miss.

### Latency Protocol

The dictionary and runtime models are loaded and warmed before scored cases begin. Latency starts immediately before assigning the scored Pinyin prefix and includes long-sentence decoding, exact/transition lookup, language-model scoring, hysteresis, local correction during final candidate readback, and accepted continuation-model refinement. Continuation-model work that abstains or times out is asynchronous and does not delay the visible static result, so it is not added to visible latency. The measurement excludes process and model cold start, the preceding stability probe, report output, InputMethodKit-to-helper IPC, rendering, real inter-key timing, and learning writes. The engine is reset before every source sentence while dictionary connections, model sessions, and runtime caches remain open for the complete run.

## Latency Statistics

Latency columns are reported in milliseconds:

- `Mean`: arithmetic mean of all per-query decode times.
- `P50`: nearest-rank median; 50% of measured queries complete at or below this value.
- `P95`: nearest-rank 95th percentile; 95% of measured queries complete at or below this value.
- `Max`: largest per-query decode time in the run.

These values quantify complete-query engine performance and long-tail cost. They are not incremental keystroke-to-display latency and must not be presented as end-to-end typing latency. Comparisons are meaningful only when the machine, operating system, power profile, release build settings, corpus order, and dictionary snapshot are controlled.

## Result Publication

Version-specific results for the four benchmarks appear in [README.md](README.md). The short-word completion benchmark begins with `v1.15.0`. Long-sentence completion results through `v1.17.0` used the legacy whole-sentence exact criterion; the local-continuation criterion starts with the next formally evaluated release and is not backfilled. This document defines their shared source, case construction, accuracy scoring, and latency protocols.

## Notes

The benchmarks are expected to evolve with the IME. Future benchmark variants may use larger or differently distributed corpora, but their names should include the case count or another clear suffix. Every published result should record the engine and dictionary versions, runner behavior, latency mode, and scoring method so comparisons remain interpretable.
