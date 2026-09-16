# 言泉输入法 macOS 基准测试

macOS **0.1.0（build 1）** 的生产引擎和模型对齐 **Windows v1.26.1**，词库使用 **Lexicon v1.26.1**。Windows v1.26.1 标签的 README 中最新测量表标为 v1.26.0；本轮将该表作为公开准确率对照，另用针对性回归验证 v1.26.1 的双拼与输入诊断修复，不将表中数据重新标成一次不存在的 v1.26.1 实测。

基准测试工具、语料、评分校验程序和逐例诊断不随公开源码分发。本文保留方法、来源与汇总结果；构建和运行输入法无需这些内部测试材料。

以下全量结果在版本元数据调整前测得；调整后的交付经核对，共享核心仅版本字面量改变，推理逻辑、模型和词库保持一致，原始测量记录保留当时编号。

## 测试方法与固定输入

完整运行串行执行，期间暂停构建、其他推理测试和桌面自动化。每次运行冻结 SC 数据库、语料、程序、运行库、共享核心和校验规则，并在结束时重验指纹。使用基础词库，关闭用户学习和外部文档上下文；短词有上下文轨只使用每例规定的左侧文本。

- 长句排名：16,300 条，确定性工作量限制测准确率，再用独立生产引擎测完整查询延迟。
- 短词排名：两条各 65,000 例，分别关闭和开启左侧上下文；含 11,728 例竞争子集。
- 短词补全：从同一短词集产生 12,831 次机会，核对显示、命中、净节键和稳定性。
- 长句补全：两条各 16,300 次机会，分别使用 0 ms（无补全结果时限）的准确率对照和 50 ms 的生产结果预算。两条轨都须通过相对 Windows 的个位数计数差要求。
- 长句补全遵循生产调用顺序：解码后可预取，最终候选读取执行局部修正，再处理实际显示的 Tab 结果。计时包含解码、最终候选修正和可见补全处理；Oracle 诊断在计时之后执行。
- 生产模式的联合修正沿用 30 ms 接受预算、词库路径检查与双向复核；主排序器已同步完成的结果不因其 30 ms 审计阈值而丢弃。

Darwin 计时使用 `mach_absolute_time`。Pascal 报告为整数毫秒，P50/P95 为 nearest rank；真实 socket 逐键回放使用单调时钟另行报告亚毫秒数据。不同主机的延迟不可直接用于归因编译器差异。

| 固定项 | SHA-256 |
| --- | --- |
| 长句 16,300 原始语料 | `3f50a9323ad798e691f86ea70c6dffa13b4a9f55b624fc3499a138258190ff0f` |
| 短词 65,000 原始语料 | `cd02fc1a24e89a106c200f4864d5ad2c11afd4c8d784059a4b6e9a10c51fbab8` |
| macOS SC 数据库 | `8d114618300c951da67e30ca2dc0828d6567746c24eaa801f529febbc11d8c99` |
| macOS TC 数据库 | `32519373675b00f1820c9afc8fc74006ad3ce87b7da0b81cd56a27f8dbb8ffb1` |

SC / TC 基础词条为 **213,359 / 216,574**，从 Lexicon v1.26.1 的 24 个生成输入重建 schema 24。所有部署模型权重与 Windows v1.26.1 标签文件逐字节一致；新增联合 query、chooser 和 bilateral 三个图，共九个图，旧 query 保留为兼容回退。SQLite 文件布局可能随平台不同，因此跨平台数据库一致性需按表内容和 schema 核对，不能只比较文件哈希。

## Windows 参考与验收规则

参考为 [Windows v1.26.1 标签 README](https://github.com/shenmin/cassotis-ime/blob/v1.26.1/README.md) 中的 v1.26.0 表：

| 排名轨 | Windows Top1 | Windows Top2 |
| --- | ---: | ---: |
| 长句 16,300 | 11,974 | 12,947 |
| 有上下文短词 65,000 | 61,860 | 63,549 |
| 有上下文竞争子集 11,728 | 9,596 | 10,775 |

短词补全参考为 **9,419 / 12,831** 命中、每命中平均净节键 **2.549**、稳定 **1,691 / 1,749**。长句补全参考为 **410** 命中、**6,488** 显示、**967** 净节键。Windows 表中长句查询平均 / P95 为 62.83 / 109 ms，有上下文短词为 4.474 / 9.310 ms；短词补全 P95 为 2.026 ms，长句补全 P95 为 80.437 ms。

验收参考在第一次 macOS 测量前冻结。公开可对照的排名、命中、显示和净节键计数最多允许 **9** 的绝对差，长句补全净节键范围为 **958–976**。输入规模、模型配置和评分规则保持固定。既有 macOS 延迟和内存门槛继续适用：长句平均 / P95 不超过 110 / 200 ms，短词不超过 12 / 30 ms，排名进程 RSS / HWM 不超过 1.5 GiB。

词库已经改变，旧 v1.25.0 逐例输出签名不再适合作为新版本的预期输出。本轮仍记录新签名，逐例绑定原始输入并从轨迹重算 TopN；另在三个独立进程布局中要求候选与补全轨迹完全一致。重复一致性不替代完整语料上的 Windows 计数门槛。

## macOS 结果

完整基准通过全部四个固定校验器，排名轨迹已逐例绑定输入并独立重算。环境为 Apple M2 Pro / 32 GiB、macOS 26.6.2（25G83）、FPC 3.2.2、Xcode 26.6 和原生 arm64 程序。安装与实际桌面的验证另外记录。

| 排名轨 | macOS Top1 / Top2 | 相对 Windows 公开参考的计数差 |
| --- | ---: | ---: |
| 长句 16,300 | 11,968 / 12,954 | -6 / +7 |
| 有上下文短词 65,000 | 61,860 / 63,549 | +0 / +0 |
| 有上下文竞争子集 11,728 | 9,596 / 10,775 | +0 / +0 |

无上下文短词为 **60,378 / 63,194**，Top5 / Top9 为 64,531 / 64,652；有上下文 Top5 / Top9 为 64,573 / 64,652。无上下文及其他未在最新 Windows 公开表列出的 TopN 沿用既有冻结参考，未把它们冒充新一次 Windows 实测。

短词 Tab 补全为 **9,420 / 12,831** 命中、**12,775** 显示、**24,006** 净节键，平均每命中 **2.548** 净节键，稳定性 **1,691 / 1,749**。命中比 Windows 公开参考多 1；本机结果签名为 `0F85F09476081967`。

| 长句补全结果预算 | 显示 | 命中 | 净节键 | 稳定 / 兼容对 |
| --- | ---: | ---: | ---: | ---: |
| 0 ms，准确率对照 | 6,493 | 414 | 960 | 25 / 738 |
| 50 ms，生产预算 | 6,493 | 414 | 960 | 25 / 738 |

两条长句补全轨的可见结果逐例一致，相对 Windows 均为：显示 +5、命中 +4、净节键 −7，满足个位数偏差要求；16,300 条记录的签名均为 `689E40CBBC67A0EC`。神经请求 / 接受 / 应用均为 11,459 / 5,309 / 3,758，完整句命中均为 21。生产轨的解码 / 最终候选读取 / 可见补全处理平均分别为 18.428 / 29.952 / 1.662 ms，合计 50.042 ms；没有漏计最终纠错阶段。

| 本机延迟，ms | 平均 | P50 | P95 | 最大 |
| --- | ---: | ---: | ---: | ---: |
| 长句，生产整句查询 | 88.244 | 79 | 168 | 668 |
| 短词，无上下文 | 6.934 | 5 | 17 | 44 |
| 短词，有上下文 | 7.553 | 6 | 18 | 61 |
| 短词 Tab 补全 | 0.741 | 1 | 2 | 12 |
| 长句补全，0 ms 结果预算 | 51.395 | 47 | 117 | 869 |
| 长句补全，50 ms 结果预算 | 50.042 | 46 | 113 | 604 |

排名进程的最大 RSS / HWM 为 **1,277,312 / 1,277,344 KiB**，低于 1,572,864 KiB 的冻结上限。RSS、进程峰值 HWM 与 physical footprint 含义不同，多引擎基准峰值也不等于日常单个输入会话的物理占用。

另以同一模型和词库在三个独立进程中各重放 500 条长句，改变参数路径长度和环境大小；候选文字、词典路径、分数、补全及其拼音逐字段完全一致。每轮均完成 500 次机会、374 次请求、165 次接受、118 次可见应用。此项检查确定性，完整准确率仍以上述全量语料结果为准。

安装后的最终引擎另做真实 socket 逐键回放：从固定长句集中均匀选取 200 条，共 **6,658** 个按键，使用独立用户数据库并在每句前清空组合和外部上下文，**0 超时**。同步请求往返平均 / P50 / P95 / P99 / 最大为 **35.725 / 25.124 / 98.942 / 141.339 / 257.499 ms**；320 键超过 100 ms，1 键超过 250 ms。此项包含逐键引擎处理及进程通信，不包含 IMK 事件传递、候选窗绘制或后续异步结果呈现，不能当作完整端到端输入延迟。回放结束时 helper RSS 为 1,121,376 KiB，physical footprint 为 409,649 KiB，峰值 physical footprint 为 410,177 KiB。

最终签名包还通过原生多行/单行/WebKit/密码框、零等待冷启动、设置自动保存、真实系统菜单、紫光双拼、错误拼音显示及连续简繁切换；Chrome、Electron、Terminal 共完成三轮 12 次真实输入交接，复用的单个 Terminal 测试窗口在结束后关闭。

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
