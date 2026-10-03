# 言泉输入法 macOS 基准测试

本文记录言泉输入法 macOS 版的测试方法、当前成绩与版本演进。当前发布为 **v1.0.0（build 3）**；以下以 **v0.2.0** 为前一版基准，所有主表版本号均指 macOS 产品版本。

基准工具、语料、评分校验程序和逐例诊断不随公开源码分发。本文保留评分方法、来源、环境和汇总结果；构建与运行输入法无需这些内部测试材料。

## macOS 版本对比

以下使用相同的完整语料，对比 macOS v1.0.0 与前一版 v0.2.0。表中的版本号均为 macOS 产品版本。

语料来自开发者自己的小说著作 [《永恒的舞动》](https://www.qidian.com/book/1037259117/)。下文给出完整的方法、评分与详细指标。

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

## 测试方法与固定输入

完整运行串行执行，期间暂停构建、其他推理测试和桌面自动化。每次运行冻结数据库、原始语料、程序、运行库、共享核心和验收规则，并在结束时重验指纹。关闭用户学习和外部文档上下文；短词有上下文轨只使用每例规定的左侧文本。

- 长句排名：16,300 条，确定性工作量限制测准确率，另用生产模式测完整查询延迟；仅检查候选列表前两个位置的整句精确匹配，统计 Top1/Top2。
- 短词排名：两条各 65,000 例，分别关闭和开启左侧上下文；含 11,728 例竞争子集，保留短词 Top5/Top9。
- 短词补全：12,831 次机会，核对命中、显示、净节键与稳定性；按键时间不包含后台重排，最终显示时间仅在重排改变提示时加上重排耗时。
- 长句补全：两条各 16,300 次机会，分别采用 0 ms（无补全结果时限）的准确率对照和 80 ms 生产结果预算，分别验收。
- 长句补全仅将真正预测后续文字的结果计入预测显示、命中、失误和净节键。精确拼接已输入拼音的提示单独计数，也不作为预测稳定性的前一次锚点；逐例记录当前与前一次补全来源并独立重算。
- macOS v1.0.0 的长句 Tab 采用 `predictive_continuations_v2`：命中、整句命中与已输入前缀检查允许相同位置的“他/她”等价；Oracle、逐键稳定性与短词 Tab 仍严格匹配。
- 计时遵循生产顺序：解码及预取、最终候选读取与局部纠错、可见补全处理；Oracle 诊断在计时之后执行。生产联合修正保留 30 ms 接受预算、词库路径检查和双向复核；共享字符模型使用相同节点预算、100 ms 取消时限和既有候选保护。

Darwin 使用 `mach_absolute_time`；长句和短词排名报告为整数毫秒，短词 Tab 以微秒采样再转换为毫秒，百分位采用 nearest rank。真实 socket 逐键回放使用单调时钟另行报告亚毫秒数据。环境为 Apple M2 Pro / 32 GiB、macOS 27.0.1（26A434）、FPC 3.2.2、Xcode 27.0 和原生 arm64 程序。不同主机的延迟不能直接用于归因编译器差异。

| 固定项 | SHA-256 |
| --- | --- |
| 长句 16,300 原始语料 | `3f50a9323ad798e691f86ea70c6dffa13b4a9f55b624fc3499a138258190ff0f` |
| 短词 65,000 原始语料 | `cd02fc1a24e89a106c200f4864d5ad2c11afd4c8d784059a4b6e9a10c51fbab8` |
| macOS SC 数据库 | `fe5846a187fba05c8121c95df1acc0697a59f9da29834823c26a98b1d291c7d5` |
| macOS TC 数据库 | `519bbfc015f00d191ac833224b4f89ac441da202f01bb7447037886c0bfa601b` |

SC / TC 基础词条为 **249,362 / 252,574**，由 Lexicon v1.31.0 的 24 个生成输入重建 schema 24。安装包包含十一个 ONNX 图及词表、运行索引。共享字符模型按校验分片重建；模型清单仅移除非运行元数据，运行阈值保持不变。本轮没有重新训练或修改权重。数据库逻辑一致性按 schema 和每张表双向核对，不能仅依赖 SQLite 文件布局或文件哈希。

## macOS v1.0.0 详细结果

本节提供 macOS v1.0.0 的补充测量。排名及两种补全预算的原始轨迹均绑定完整语料并独立重算，三个独立进程中的各 500 条候选、路径、分数和补全决策也完全一致。

无上下文短词为 **60,391 / 63,212**，Top5 / Top9 为 64,549 / 64,670；有上下文 Top5 / Top9 为 64,591 / 64,670。

短词 Tab 为 **10,331 / 12,831** 命中、**12,775** 显示、**27,250** 净节键、每命中平均 **2.638**，稳定 **2,117 / 2,180**；签名 `FA8B2C565BE7E8A6`。

| 长句补全结果预算 | 预测显示 | 精确拼接显示 | 预测命中 | 净节键 | 稳定 / 兼容对 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0 ms，准确率对照 | 15,812 | 44 | 3,539 | 7,539 | 179 / 3,403 |
| 80 ms，生产预算 | 15,812 | 44 | 3,539 | 7,539 | 179 / 3,403 |

签名分别为 `7E38A6AA443BA4E8` / `7E38A6AA443BA4E8`。精确拼接中与目标已输入前缀相同的提示分别为 7 / 7，这些提示不记预测命中或节键。

两轨预测未命中均为 **12,273**，等于预测显示数减去预测命中数。

生产轨神经请求 / 接受 / 应用为 15,954 / 15,722 / 15,612，完整句命中 106。解码 / 最终候选读取 / 可见补全处理平均分别为 7.988 / 36.383 / 25.479 ms，合计 69.851 ms。

| 本机延迟，ms | 平均 | P50 | P95 | 最大 |
| --- | ---: | ---: | ---: | ---: |
| 长句，生产整句查询 | 85.043 | 79 | 148 | 567 |
| 短词，无上下文 | 4.212 | 3 | 12 | 28 |
| 短词，有上下文 | 6.801 | 6 | 17 | 40 |
| 短词 Tab 最终显示 | 1.850 | 0.646 | 9.385 | 19.605 |
| 长句补全，0 ms 结果预算 | 71.015 | 71 | 134 | 715 |
| 长句补全，80 ms 结果预算 | 69.851 | 70 | 131 | 420 |

短词 Tab 按键 P95 为 **1.213 ms**，最终显示 P95 为 **9.385 ms**，分别计量按键路径与后台重排后的最终显示。

排名进程最大 RSS / HWM 为 **1,512,720 / 1,512,768 KiB**，低于冻结的 1,572,864 KiB 上限。RSS、进程 HWM 与 physical footprint 是不同指标，不能混写。完整查询计时不包含模型冷启动、InputMethodKit 事件传递、IPC、候选窗绘制或真实按键间隔。

最终安装引擎另做 200 条 / **6,658** 键的独立用户数据库回放，**0 超时**。同步 IPC 往返平均 / P50 / P95 / P99 / 最大为 **26.903 / 15.732 / 92.942 / 122.756 / 193.634 ms**；超过 100 / 250 ms 的按键分别为 250 / 0。该计时包含逐键引擎处理及进程通信，不包含 IMK 事件、绘制和后续异步结果呈现，因此不等于完整端到端输入延迟。

The methodology below describes the macOS benchmarks. Version numbers refer to macOS releases; cross-platform provenance is recorded separately at the end.

## Shared Corpus Source

All four benchmarks are derived from the developer's own novel, [**Elegance in Timelessness**](https://www.qidian.com/book/1037259117/) (Chinese title: [**永恒的舞动**](https://www.qidian.com/book/1037259117/)).

Benchmark-16300 fixes 16,300 eligible sentences, while Benchmark-65000 fixes 65,000 short-word occurrences. The short-word completion benchmark derives 12,831 incremental completion opportunities from the same short-word cases. The long-sentence completion benchmark reuses the long-sentence corpus to derive 16,300 near-tail opportunities. Benchmark cases are kept separate from the corresponding model-training data.

## Shared Accuracy Equivalence Rule

The following rule applies to visible-candidate accuracy metrics in the long-sentence and short-word context suites, including `Top1`, `Top2`, other reported `TopN` values, and the short-word `Contested` metrics. Starting with macOS `v1.0.0`, it also applies to the Long-sentence One-key Completion Benchmark-16300 hit, whole-sentence hit, and visible-prefix metrics:

- `他` and `她` are treated as equivalent only when they occur at the same character positions, because the benchmark Pinyin query cannot distinguish them.
- `它`, all other homophones, missing or additional characters, and every other textual difference remain distinct.
- The rule changes only offline pass/fail scoring. It does not rewrite candidate text or alter candidate generation, ranking, latency, or user-dictionary behavior.
- Raw-pool and Oracle recall scoring retains strict character equality so that the target label cannot influence search behavior. It is therefore not directly comparable with equivalence-aware visible `TopN` metrics.

Both macOS versions shown here already use this equivalence for long-sentence and contextual short-word candidate ranking. Long-sentence completion changes from strict equality in v0.2.0 (`predictive_continuations_v1`) to the equivalence rule in v1.0.0 (`predictive_continuations_v2`). Re-evaluating the saved v0.2.0 rows changes 25 hits: 425 → 450 correct continuations and 988 → 1,024 saved keys. It does not change a prompt, its coverage or its measured latency. The original strict scores remain in italics in the tables.

## Shared Model Configuration

macOS v1.0.0 uses the released model configuration in all four suites: the long-sentence Transformer, local-repair and continuation models, and one shared character-level language model. The character model reranks long and short candidates and contributes to both kinds of Tab completion, including completion of the current word and next-character suggestions.

macOS v0.2.0 used a separate RBT3 short-word context model, and its short-word completion had no neural rerank. The current shared model replaces RBT3. These are real product changes reflected in both quality and query latency.

## Long Sentence Benchmark-16300

### Corpus Scale and Case Construction

Benchmark-16300 contains 16,300 eligible sentences extracted from the novel in a fixed order. Its cases are constructed as follows:

- Split the novel text by punctuation and line breaks.
- Ignore sentences containing English letters.
- Ignore sentences shorter than the configured minimum CJK length.
- Convert each complete sentence to Pinyin with the benchmark reverse-Pinyin builder.
- Feed the complete Pinyin query to the engine and dictionary version under test.

### Accuracy Scoring

- A case is a `Top1` pass when the first visible candidate is complete and matches the original sentence under the shared scoring rule above.
- A case is a `Top2` pass when a candidate in visible position one or two is complete and matches the original sentence under the shared scoring rule above. Later complete candidates do not count.

### Accuracy and Latency Modes

- Accuracy runs use deterministic-work mode: normal search paths do not stop on wall-clock time and remain bounded by fixed beam, state, edge, candidate, and work limits. Changes in machine load therefore do not change normal candidate generation.
- Latency runs use production mode: fixed work limits are the primary boundary, with wider emergency wall-clock ceilings retained to prevent unacceptable stalls on malformed long Pinyin or slower machines.
- Both modes load the same deployed long-sentence Transformer reranker as the Host. A missing or incomplete runtime is an error rather than a silent fallback; disabling it is reserved for explicitly labelled diagnostic runs.
- The two measurements are run separately. macOS executes both full-corpus tracks serially.

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

The benchmark records five metrics that are straightforward to interpret across releases:

- `Completion Hit`: correct completions divided by all 12,831 opportunities; this is the primary quality metric.
- `Avg Keys Saved`: average net keystrokes saved by each correct completion, after charging one keystroke for accepting it.
- `Stability`: when the previous completion remains compatible after another syllable is typed, the proportion for which the displayed completion remains unchanged.
- `Keystroke P95`: 95% of keystrokes return their completion within this many milliseconds; this is what typing waits for.
- `Final P95`: 95% of opportunities show their final completion within this many milliseconds, including an asynchronous language-model rerank that changes the displayed completion.

Because each corpus position has only one reference target, a different but linguistically valid completion is still scored as a miss.

### Latency Protocol

Latency covers dictionary lookup, context/language-model scoring, completion selection, and hysteresis only. It excludes process and dictionary cold start, InputMethodKit/helper communication, candidate-window rendering, real inter-key timing, and learning writes after acceptance. The engine is reset before each source case; adjacent prefixes of the same target are processed consecutively, while the dictionary connection and runtime caches remain open for the complete run.

From macOS `v1.0.0`, the language-model rerank of the completion runs asynchronously in the Host, off the keystroke path: the completion chosen by dictionary ranking is shown on the keystroke, and the rerank may replace it shortly afterwards. `Keystroke P95` excludes the rerank. `Final P95` adds the rerank time to an opportunity only when the rerank changes the displayed completion. macOS v0.2.0 has no asynchronous rerank, so both values are the same.

## Long-sentence One-key Completion Benchmark-16300

### Case Construction and Scoring

This benchmark measures whether one-key completion can extend a partially decoded long sentence, instead of inferring completion quality from the unrelated long-sentence candidate-ranking score:

- Reuse all 16,300 fixed long-sentence cases and their reviewed full Pinyin queries.
- Leave the final four complete Pinyin syllables untyped while retaining at least the first four syllables as the visible composition prefix.
- Decode that prefix in deterministic-work mode with the same long-sentence Transformer reranker used by the Host.
- Run the same constrained local-completion model when the static layer requests asynchronous refinement, apply the same confidence, timeout, and exact-path validation, then read only the single settled completion that the UI would display.
- Count a local-continuation hit when the displayed result extends the intended typed prefix and the whole displayed text remains a prefix of the reference sentence, both under the shared `他`/`她` rule in macOS v1.0.0. The completion may stop after the next one to three local words; it does not have to reproduce the rest of the sentence in one step.
- Disable the user dictionary and external document context, and use a snapshot of the simplified base dictionary selected for the tested release.
- Query the immediately preceding syllable boundary before the scored query to measure whether a compatible completion remains stable as typing continues.

The public report uses four metrics suited to direct cross-version comparison under the current protocol:

- `Local Completion Hit`: correct local continuations divided by all 16,300 opportunities.
- `Predictive Prompt Coverage`: opportunities where a predictive completion was displayed, divided by all opportunities. Exact-word joins that only convert already typed Pinyin are excluded from prediction coverage and prediction misses.
- `Total Keys Saved`: net keys saved across all correct local-continuation hits after charging one key for each acceptance.
- `P95`: 95% of visible completion queries finish within this many milliseconds.

The detailed report additionally retains average keys saved per hit, incremental stability, wrong-prompt counts, whole-sentence hits, and internal-pool Oracle ranks for attribution. Oracle ranks keep strict character equality. Incremental stability is not published as a primary comparison because its eligible denominator depends on the prompts produced by each version and can be very small. Because the corpus supplies one reference, a plausible continuation with different wording still counts as a miss.

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

The four benchmark tables appear in [README.md](README.md), [简体中文](README.zh-Hans.md) and [繁體中文](README.zh-Hant.md), with macOS v1.0.0 and its preceding release. Keep each release’s measured latency, corpus identity and scoring rule. A retrospective scoring change must be labelled and retain the original values; it is not a new engine run. Historical release artifacts and reports remain unchanged.

## Notes

The benchmarks are expected to evolve with the IME. Future benchmark variants may use larger or differently distributed corpora, but their names should include the case count or another clear suffix. Every published result should record the engine and dictionary versions, runner behavior, latency mode, and scoring method so comparisons remain interpretable.

## 上游来源与对齐记录（补充）

macOS 版使用源于 [Cassotis IME Windows 版](https://github.com/shenmin/cassotis-ime) 的共享引擎和 [Cassotis Lexicon](https://github.com/shenmin/cassotis-lexicon) 的词库与模型。本次引擎和资产基线为 v1.31.0；前一版 macOS v0.2.0 的基线为 v1.29.0。上文的结果与版本历史均为 macOS 自身实测。

保留与 Windows v1.31.0 公开参考的计数核对，作为移植可追溯信息：

| 指标 | macOS v1.0.0 | Windows v1.31.0 | 计数差 |
| --- | ---: | ---: | ---: |
| 长句 Top1 / Top2 | 12,941 / 13,534 | 12,940 / 13,534 | +1 / 0 |
| 上下文短词 Top1 / Top2 | 63,036 / 64,103 | 63,036 / 64,104 | 0 / −1 |
| 竞争词 Top1 / Top2 | 10,488 / 11,196 | 10,491 / 11,196 | −3 / 0 |
| 短词 Tab 命中 | 10,331 | 10,336 | −5 |
| 长句预测显示 | 15,812 | 15,815 | −3 |
| 长句预测命中 | 3,539 | 3,513 | +26 |
| 长句净节省按键 | 7,539 | 7,478 | +61 |

长句预测未命中为 12,273，比参考的 12,302 少 29；这是预测显示 −3、命中 +26 的算术结果。长句 Tab 命中与净节键的正向差异已明确接受并保留披露，因此不声称所有计数都在个位数差内。两平台的耗时来自不同主机，不作为同机性能对比。
