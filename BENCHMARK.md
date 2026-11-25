# 言泉输入法 macOS 基准测试

本文记录 macOS **v2.10.0（build 11）** 的完整实测数据，并与前一正式版 **v2.9.0** 对比。基准工具、语料与逐例诊断不随源码分发；构建和使用输入法不依赖这些文件。

## macOS 版本对比

本轮沿用 v2.9.0 相同语料，没有再次修改案例或读音。v2.10.0 使用本轮完整测量，v2.9.0 及更早版本保留历史成绩。v2.0.0 行的普通字体保留 10 月 23 日原程序搭配原 Lexicon v2.2.0 在相同语料上的重测结果，斜体是原发布值；只有一个数值表示两次相同。版本号均为 macOS 产品版本，旧发布产物和原始报告不改写。

语料来自开发者自己的小说著作 [《永恒的舞动》](https://www.qidian.com/book/1037259117/)。测试在 Apple M2 Pro、32 GiB 内存、macOS 27.2.1 上以原生 arm64 串行运行，使用简体词库及 6 个模型线程，与 v2.9.0 相同。耗时受系统负载影响，不将跨轮波动视作代码优化的证明。

本轮测量日期：**2026-11-26（UTC+8）**。

### Cassotis 长句语料基准测试-16300

| macOS 版本 | Top1 | Top2 | 平均 (ms) | P50 (ms) | P95 (ms) | 最大 (ms) |
| --- | --- | --- | --- | --- | --- | --- |
| `v2.10.0` | 13,871/16,300 (85.10%) | 14,790/16,300 (90.74%) | 96.601 | 90 | 172 | 586 |
| `v2.9.0` | 13,869/16,300 (85.09%) | 14,789/16,300 (90.73%) | 99.312 | 92 | 177 | 723 |
| `v2.8.0` | 13,747/16,300 (84.34%) | 14,690/16,300 (90.12%) | 88.809 | 82 | 159 | 533 |
| `v2.7.0` | 13,738/16,300 (84.28%) | 14,681/16,300 (90.07%) | 85.862 | 79 | 155 | 508 |
| `v2.6.0` | 13,743/16,300 (84.31%) | 14,689/16,300 (90.12%) | 82.148 | 77 | 143 | 499 |
| `v2.5.0` | 13,441/16,300 (82.46%) | 14,358/16,300 (88.09%) | 86.055 | 81 | 146 | 512 |
| `v2.1.0` | 13,435/16,300 (82.42%) | 14,314/16,300 (87.82%) | 87.889 | 84 | 147 | 519 |
| `v2.0.0` | 13,390/16,300 (82.15%)<br>*13,397/16,300 (82.19%)* | 14,273/16,300 (87.56%)<br>*14,281/16,300 (87.61%)* | 90.024<br>*94.084* | 86<br>*90* | 149<br>*154* | 517<br>*523* |
| `v1.0.0` | 12,941/16,300 (79.39%) | 13,534/16,300 (83.03%) | 85.043 | 79 | 148 | 567 |

### 短词上下文基准测试-65000

| macOS 版本 | Top1 | Top2 | 竞争词 Top1 | 竞争词 Top2 | 平均 (ms) | P50 (ms) | P95 (ms) | 最大 (ms) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `v2.10.0` | 63,499/65,000 (97.69%) | 64,562/65,000 (99.33%) | 10,533/11,685 (90.14%) | 11,312/11,685 (96.81%) | 7.489 | 5 | 20 | 145 |
| `v2.9.0` | 63,500/65,000 (97.69%) | 64,562/65,000 (99.33%) | 10,534/11,685 (90.15%) | 11,312/11,685 (96.81%) | 7.633 | 6 | 20 | 221 |
| `v2.8.0` | 63,502/65,000 (97.70%) | 64,565/65,000 (99.33%) | 10,546/11,685 (90.25%) | 11,315/11,685 (96.83%) | 7.459 | 5 | 20 | 69 |
| `v2.7.0` | 63,502/65,000 (97.70%) | 64,564/65,000 (99.33%) | 10,545/11,685 (90.24%) | 11,315/11,685 (96.83%) | 7.404 | 5 | 20 | 53 |
| `v2.6.0` | 63,455/65,000 (97.62%) | 64,521/65,000 (99.26%) | 10,516/11,685 (90.00%) | 11,283/11,685 (96.56%) | 6.744 | 5 | 18 | 99 |
| `v2.5.0` | 63,463/65,000 (97.64%) | 64,436/65,000 (99.13%) | 10,512/11,685 (89.96%) | 11,223/11,685 (96.05%) | 7.202 | 5 | 20 | 66 |
| `v2.1.0` | 63,455/65,000 (97.62%) | 64,423/65,000 (99.11%) | 10,539/11,685 (90.19%) | 11,225/11,685 (96.06%) | 7.652 | 5 | 21 | 70 |
| `v2.0.0` | 63,348/65,000 (97.46%)<br>*63,362/65,000 (97.48%)* | 64,346/65,000 (98.99%)<br>*64,291/65,000 (98.91%)* | 10,504/11,685 (89.89%)<br>*10,533/11,728 (89.81%)* | 11,228/11,685 (96.09%)<br>*11,244/11,728 (95.87%)* | 7.281<br>*7.232* | 5 | 20 | 79<br>*62* |
| `v1.0.0` | 63,036/65,000 (96.98%) | 64,103/65,000 (98.62%) | 10,488/11,728 (89.43%) | 11,196/11,728 (95.46%) | 6.801 | 6 | 17 | 40 |

“竞争词”是同一拼音对应至少两个目标词的子集。现用语料的分母为 11,685；历史原发布语料的分母为 11,728。

### 一键补全上下文基准测试-12831

| macOS 版本 | 补全命中率 | 平均节省按键 | 逐键稳定率 | 按键 P95 (ms) | 最终显示 P95 (ms) |
| --- | --- | --- | --- | --- | --- |
| `v2.10.0` | 10,561/12,831 (82.31%) | 2.642 | 2,178/2,234 (97.49%) | 2.103 | 19.068 |
| `v2.9.0` | 10,561/12,831 (82.31%) | 2.642 | 2,178/2,234 (97.49%) | 2.108 | 19.133 |
| `v2.8.0` | 10,506/12,831 (81.88%) | 2.634 | 2,139/2,200 (97.23%) | 2.107 | 17.968 |
| `v2.7.0` | 10,506/12,831 (81.88%) | 2.634 | 2,139/2,200 (97.23%) | 2.054 | 17.527 |
| `v2.6.0` | 10,513/12,831 (81.93%) | 2.635 | 2,153/2,216 (97.16%) | 2.000 | 16.493 |
| `v2.5.0` | 10,513/12,831 (81.93%) | 2.635 | 2,153/2,216 (97.16%) | 2.137 | 19.915 |
| `v2.1.0` | 10,513/12,831 (81.93%) | 2.636 | 2,154/2,217 (97.16%) | 2.035 | 18.451 |
| `v2.0.0` | 10,466/12,831 (81.57%)<br>*10,457/12,831 (81.50%)* | 2.633<br>*2.632* | 2,134/2,198 (97.09%)<br>*2,133/2,195 (97.18%)* | 1.982<br>*2.035* | 19.357<br>*21.352* |
| `v1.0.0` | 10,331/12,831 (80.52%) | 2.638 | 2,117/2,180 (97.11%) | 1.213 | 9.385 |

平均节省按键按每次正确补全计算，已扣除接受补全的一次按键；逐键稳定率只统计继续输入后原补全仍兼容的机会。 v2.9.0 短词补全累计净节省 27,903 键；v2.8.0 为 27,676 键；v2.7.0 为 27,677 键；v2.6.0 为 27,706 键；v2.5.0 为 27,706 键；v2.1.0 为 27,712 键；v2.0.0 同语料重测为 27,553 键，原发布值为 27,525 键。

### Cassotis 长句一键补全基准测试-16300

每条长句保留末尾四个拼音音节不输入，评估界面显示的唯一续写。覆盖率仅统计预测提示，不含已输入拼音的精确拼接，也不代表提示准确率。

| macOS 版本 | 局部续写命中率 | 预测提示覆盖率 | 总节省按键 | P95 (ms) |
| --- | --- | --- | --- | --- |
| `v2.10.0` | 4,011/16,300 (24.61%) | 16,215/16,300 (99.48%) | 9,835 | 154 |
| `v2.9.0` | 4,012/16,300 (24.61%) | 16,212/16,300 (99.46%) | 9,836 | 175 |
| `v2.8.0` | 3,976/16,300 (24.39%) | 16,230/16,300 (99.57%) | 9,816 | 150 |
| `v2.7.0` | 3,982/16,300 (24.43%) | 16,234/16,300 (99.60%) | 9,827 | 143 |
| `v2.6.0` | 3,955/16,300 (24.26%) | 16,152/16,300 (99.09%) | 9,724 | 137 |
| `v2.5.0` | 3,903/16,300 (23.94%) | 16,144/16,300 (99.04%) | 9,627 | 146 |
| `v2.1.0` | 3,877/16,300 (23.79%) | 16,139/16,300 (99.01%) | 9,597 | 148 |
| `v2.0.0` | 3,771/16,300 (23.13%)<br>*3,768/16,300 (23.12%)* | 16,111/16,300 (98.84%)<br>*16,113/16,300 (98.85%)* | 9,303<br>*9,293* | 143<br>*149* |
| `v1.0.0` | 3,539/16,300 (21.71%) | 15,812/16,300 (97.01%) | 7,539 | 131 |

自 v2.9.0 起，长句补全的结果时限为 120 ms。v1.0.0 至 v2.8.0 使用 80 ms，v0.2.0 使用 50 ms。本轮另以无结果时限复核，命中 4,012 次、净省 9,836 键。

测试程序、基准工具、语料和逐例报告不随公开源码分发。

## 测试方法与固定输入

四项完整语料串行运行。数据库、五笔码表、语料、程序、运行库、共享核心和验收规则在开始前冻结，结束后复验 SHA-256。测试关闭用户学习，上下文短词只使用每例指定的前文。

长句排名分别执行确定性工作量准确率轨和生产计时轨；短词执行无上下文与有上下文两条完整轨；长句 Tab 分别执行无结果时限的 0 ms 对照和 120 ms 生产预算。所有模型均启用，排名失败不回退为无模型成绩。计时顺序为解码、最终候选读取与修正、可见补全；Oracle 诊断在计时后执行。生产轨保留共享模型的 100 ms 取消时限；准确率对照关闭时间截止。节点预算和词库／读音保护在两条轨中都保留。

环境为 Apple M2 Pro、32 GiB、macOS 27.2.1（26B131）、FPC 3.2.2、Xcode 27.2、ORT 1.20.1，原生 arm64，模型使用 6 个推理线程，与 v2.9.0 相同；v2.5.0 之前的测量使用 8 个。Darwin 使用 `mach_absolute_time`；短词 Tab 以微秒采样后换算毫秒，百分位使用 nearest rank。

| 固定项 | SHA-256 |
| --- | --- |
| 长句 16,300 原始语料 | `504d9fdbdad5dd22c41f1611a63d1ce8ccd6df7307ee2e28f904f48bdd23eb20` |
| 短词 65,000 原始语料 | `f8c9e3cf44009dfd92ca244e5eda695e1e47117ec3de97e284dcafd201be2130` |
| macOS SC 数据库 | `50763f0e4777f017644a34c75c6e0fcce06833861145bf76b70ce285f478ace3` |
| macOS TC 数据库 | `6d3f7ab10e31a683502659d1d4eedb506b6892f0d72303bf6880d6c12bbf4022` |
| 五笔 86 码表 | `71232d0e77edf7a5765866110cefb42322885e213d2c38aac810013d53c05ae4` |

Lexicon v2.10.0 提供 30 个简繁 SQLite 构建输入和一份独立五笔 86 码表。简繁基础读音分别为 **270,463／273,220**。应用携带的字符模型、词表和读音资源与 v2.9.0 相同。五笔只在启用混输时加载。

自 v2.5.0 起按最快核心层级确定模型线程数量，查询不可用时回退到物理／系统 CPU 计数，保留 4–8 个线程的边界。实际调度仍由 macOS 管理。v2.5.0 准备期间的 8／6／4 线程隔离对照显示 6 线程更合适；v2.5.0、v2.6.0、v2.7.0、v2.8.0 与 v2.9.0 均采用正式线程策略，重新冻结程序并完整运行全部语料，不使用这些小样本对照代替完整成绩。本轮采用蒸馏后的模型权重，长句 Tab 结果时限为 120 ms，节点预算沿用 v2.8.0。

## macOS v2.10.0 详细结果

五笔四码重码另做了一组 macOS 逐键测试。从长句语料抽取 300 份前文，每份前文分别输入两次相同的四码。按固定码表顺序时，目标字词排在首位 281 次，开启上文排序后为 293 次。

短词在无上文时，Top1／Top2 为 61,280／63,836，Top5／Top9 为 64,873／64,967。有上文时，Top5／Top9 为 64,927／64,967。短词 Tab 显示 12,796 次，净省 27,903 键，稳定 2,178/2,234 (97.49%)。

| 长句续写 | 预测显示 | 精确拼接显示 | 预测命中 | 净节键 | 稳定／兼容对 |
| --- | --- | --- | --- | --- | --- |
| 无结果时限 | 16,217 | 0 | 4,012 | 9,836 | 362 / 3,684 |
| 120 ms 生产预算 | 16,215 | 0 | 4,011 | 9,835 | 362 / 3,682 |

生产轨共有 16,228 个神经续写请求，接受 16,142 次，应用 15,950 次，完整句命中 206 次。解码、最终候选读取和可见补全处理的平均耗时分别为 7.515、47.938、30.610 ms。

| 本机耗时，ms | 平均 | P50 | P95 | 最大 |
| --- | --- | --- | --- | --- |
| 长句，生产整句查询 | 96.601 | 90 | 172 | 586 |
| 短词，无上文 | 5.104 | 4 | 14 | 206 |
| 短词，有上文 | 7.489 | 5 | 20 | 145 |
| 短词 Tab 最终显示 | 3.979 | 0.767 | 19.068 | 72.944 |
| 长句 Tab，无结果时限 | 88.061 | 82 | 155 | 820 |
| 长句 Tab，120 ms | 86.064 | 80 | 154 | 870 |

本轮排名测试进程的峰值 RSS／HWM 为 1,428,704／1,428,736 KiB。

## Shared Corpus Source

All four benchmarks are derived from the developer's own novel, [**Elegance in Timelessness**](https://www.qidian.com/book/1037259117/) (Chinese title: [**永恒的舞动**](https://www.qidian.com/book/1037259117/)).

Benchmark-16300 fixes 16,300 eligible sentences, while Benchmark-65000 fixes 65,000 short-word occurrences. The short-word completion benchmark derives 12,831 incremental completion opportunities from the same short-word cases. The long-sentence completion benchmark reuses the long-sentence corpus to derive 16,300 near-tail opportunities. Benchmark cases are kept separate from the corresponding model-training data.

## Shared Accuracy Equivalence Rule

The following rule applies to visible-candidate accuracy metrics in the long-sentence and short-word context suites, including `Top1`, `Top2`, other reported `TopN` values, and the short-word `Contested` metrics. Starting with macOS `v1.0.0`, it also applies to the Long-sentence One-key Completion Benchmark-16300 hit, whole-sentence hit, and visible-prefix metrics:

- `他` and `她` are treated as equivalent only when they occur at the same character positions, because the benchmark Pinyin query cannot distinguish them.
- `它`, all other homophones, missing or additional characters, and every other textual difference remain distinct.
- The rule changes only offline pass/fail scoring. It does not rewrite candidate text or alter candidate generation, ranking, latency, or user-dictionary behavior.

All macOS versions in these tables use the same equivalence rule for visible ranking and long completion (`predictive_continuations_v2`). Short completion and incremental stability use strict equality.

## Shared Model Configuration

Since macOS v2.0.0, the engine uses one shared character-level language model of about 150 million parameters for long and short ranking, word completion, continuation and Pinyin-constrained correction. The deployed graph uses static int8 quantization, float16 input embeddings and a custom attention operator; v2.9.0 uses ten compact parameter sets (seven decision models and three structural rankers). All suites load these deployed assets. No benchmark-specific model is substituted.

The historical macOS v1.0.0 release used eleven neural graphs, including separate correction and continuation models. macOS v2.0.0 consolidated them into the shared model. The v2.0.0, v2.1.0, v2.5.0 and v2.6.0 runs use the same neural weights and background short Tab reranking; v2.7.0 adopts the conversationally continued model; v2.8.0 keeps those weights and updates the engine, runtime cache and dictionaries. Version 2.9.0 deploys the distilled character model and retrains seven decision models, including the gate for accepting a long-sentence rewrite.

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
- Both modes load the same deployed shared language model and Pinyin-constrained correction as the input method. A missing or incomplete runtime is an error rather than a silent fallback; disabling it is reserved for explicitly labelled diagnostic runs.
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
- `Contested` is the 11,685-case subset in which the same Pinyin query maps to at least two target words in the current corpus (11,728 cases in the original historical corpus). `Contested Top1` and `Contested Top2` isolate the cases where left context is most useful for disambiguation.
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
- Decode that prefix in deterministic-work mode with the same shared language model and correction used by the input method.
- Run the same shared-LM continuation policy when the static layer requests asynchronous refinement, apply the same confidence, timeout, and exact-path validation, then read only the single settled completion that the UI would display.
- Count a local-continuation hit when the displayed result extends the intended typed prefix and the whole displayed text remains a prefix of the reference sentence, both under the shared `他`/`她` rule used since macOS v1.0.0. The completion need not reproduce the rest of the sentence. In v2.0.0, the shared LM can extend the chosen continuation by up to three further characters while confidence permits.
- Disable the user dictionary and external document context, and use a snapshot of the simplified base dictionary selected for the tested release.
- Query the immediately preceding syllable boundary before the scored query to measure whether a compatible completion remains stable as typing continues.

The public report uses four metrics suited to direct cross-version comparison under the current protocol:

- `Local Completion Hit`: correct local continuations divided by all 16,300 opportunities.
- `Predictive Prompt Coverage`: opportunities where a predictive completion was displayed, divided by all opportunities. Exact-word joins that only convert already typed Pinyin are excluded from prediction coverage and prediction misses.
- `Total Keys Saved`: net keys saved across all correct local-continuation hits after charging one key for each acceptance.
- `P95`: 95% of visible completion queries finish within this many milliseconds.

The detailed report additionally retains average keys saved per hit, incremental stability, wrong-prompt counts, whole-sentence hits, and the pre-refinement completion for attribution. Diagnostic pool queries run after the timed sample; their contents are not scored as visible predictions. Incremental stability is not published as a primary comparison because its eligible denominator depends on the prompts produced by each version and can be very small. Because the corpus supplies one reference, a plausible continuation with different wording still counts as a miss.

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

The four benchmark tables appear in [README.md](README.md), [简体中文](README.zh-Hans.md) and [繁體中文](README.zh-Hant.md), with macOS v2.10.0 and its preceding release, v2.9.0. The historical v2.0.0 runtime was re-measured on the corrected cases on October 23; italic values preserve its original release measurements. Keep each release’s measured latency, corpus identity and scoring rule. A retrospective scoring change must be labelled and retain the original values; it is not a new engine run. Historical release artifacts and reports remain unchanged.

## Notes

The benchmarks are expected to evolve with the IME. Future benchmark variants may use larger or differently distributed corpora, but their names should include the case count or another clear suffix. Every published result should record the engine and dictionary versions, runner behavior, latency mode, and scoring method so comparisons remain interpretable.

## 上游来源与对齐记录（补充）

本次参考 [Windows v2.10.0](https://github.com/shenmin/cassotis-ime/releases/tag/v2.10.0) 与 [Cassotis Lexicon v2.10.0](https://github.com/shenmin/cassotis-lexicon/releases/tag/v2.10.0)。Windows 与 macOS 使用相同的长句与短词语料。Windows README 将短词、短词补全和长句续写的 v2.10.0 与 v2.9.0 合并列出。

| 指标 | macOS v2.10.0 | Windows v2.10.0 | 计数差 |
| --- | --- | --- | --- |
| 长句 Top1 | 13,871 | 13,871 | 0 |
| 长句 Top2 | 14,790 | 14,790 | 0 |
| 上下文短词 Top1 | 63,499 | 63,500 | -1 |
| 上下文短词 Top2 | 64,562 | 64,563 | -1 |
| 竞争词 Top1 | 10,533 | 10,534 | -1 |
| 竞争词 Top2 | 11,312 | 11,313 | -1 |
| 短词 Tab 命中 | 10,561 | 10,561 | 0 |
| 长句预测命中 | 4,011 | 4,012 | -1 |
| 长句净节省按键 | 9,835 | 9,836 | -1 |
| 长句预测显示 | 16,215 | 16,217 | -2 |
