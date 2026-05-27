---
name: distill
description: 从文章或转写文本生成口播稿（script.md）和大纲（outline.md），注入视角风格
---

# Skill: distill

## IRON LAW

**script.md 定节拍（口播顺序 = 视觉推进顺序），article.md 定画面密度（口播跳过的细节上屏幕）。永不混淆两个源的职责。**

outline.md 是跨步骤记忆载体，必须同时参考 script.md 和 article.md。

## Purpose

将原始内容（文章 / 转写文本）提炼为两个产出：口播稿（定节奏）和开发大纲（定画面）。这是整个流水线的核心转换步骤。

## Preconditions

- `plan.json` 已存在（由 using-recastory 生成）
- 输入文件存在：`raw/article.md`（或 `transcribe/transcript.json`）
- 如指定 `--perspective`，对应视角 SKILL.md 可用

## Steps

### 1. 读取计划

从 `plan.json` 获取：
- `double_source.article` — 原文路径
- `double_source.script` — 口播稿输出路径
- `double_source.outline` — 大纲输出路径
- `perspective.name` — 视角名称（如有）
- `perspective.expression_dna` — Expression DNA 摘要（如有）
- `target_format` — 目标格式（决定时长/字数）
- `register` — 注册表类型（brand/product）

### 2. 读取原文

读取 `raw/article.md`（P0 场景无 transcript，直接从文章出发）。

提取：
- 核心论点（1-3 个）
- 关键数据 / 引用 / 案例
- 可视觉化的元素（图表、对比、流程）

### 3. 视角注入（如 plan.json 指定 perspective）

根据 plan.json 的 `perspective.source` 字段选择加载方式：

- **`source: "recastory"`** 或无 source 字段 → 调用 `Skill` 工具加载 `skills/perspectives/<name>/SKILL.md`（如 `perspectives/feynman`）
- **`source: "nuwa-skill"`** → 跳过 Skill 调用，直接使用已加载的上下文内容（nuwa-skill 视角为问答式格式，需从中提取表达风格特征用于内容生产）

从 SKILL.md 提取：
- **Expression DNA**：句式规则、词汇偏好、节奏模式、幽默策略
- 将 Expression DNA 作为 script.md 生成的**约束条件**（不是装饰，是硬性规则）

如未指定 perspective，跳过此步，使用中性口语风格。

### 4. 生成 script.md

从原文提取核心内容，转化为口语化口播稿。

**格式要求**：
- 按章节组织：`## 第N章：<标题>`
- 每章含 2-3 个步骤，用 `### 步骤 <N>` 标记
- 30 秒视频 → 约 150-200 字（中文）
- 60 秒视频 → 约 300-400 字
- 每增加 30 秒 → 增加约 150-200 字

**口语化规则**（硬性）：
- 每句 ≤20 字（B 站基准，超过 = 违规 CD-003；抖音 ≤12、YouTube ≤30、知乎 ≤25，按 --platform 调整）
- 第二人称为主（"你看"、"你想想"）
- 去填充词（"那么"、"其实"、"所以说"、"接下来"）
- 去书面语（"综上所述"→"说白了"、"由此可见"→"你看"、"值得注意的是"→直接说）
- 短句优先，允许不完整句（"真的。""你猜怎么着？"）
- 变化句式：长-短-长交替，避免连续 5 句相同结构

**anti-AI 规则**（SL-001~SL-006，与 content-distillation/REFERENCE.md 一致）：
- 禁止假共情（"我知道你""你是不是也""我能理解"）— SL-001
- 禁止假深刻（"恰恰/反而/正是"包装，去掉后意思不变）— SL-002
- 禁止自我标榜（"我必须认真说""颠覆认知""你一定要听完"）— SL-003
- 禁止万能模板（"说白了/本质上/底层逻辑/一句话总结/归根结底"）— SL-004
- 禁止排比堆砌（连续 ≥3 句结构相同）— SL-005
- 禁止套话结尾（"以上就是本期内容/希望对你有帮助/感谢观看"）— SL-006
- 禁止 AI 高频词（"此外"、"至关重要"、"深入探讨"、"充满活力"）

自检发现 SL-001~SL-006 违规 ≥1 条时，加载 `skills/humanizer-zh/SKILL.md` 的 24 类检测规则做二次审查（≥1 而非 ≥2，理由：宁严勿松，P0 hello-world 测试后如误触发过多可回调）。默认使用 SL-001~SL-006 做快速检查。

**视角 Expression DNA 注入**（如有）：
- 按视角 SKILL.md 的句式、词汇、节奏、幽默规则改写
- 全文风格必须一致，不可中途切换

### 5. 生成 outline.md

从 script.md 和 article.md **双源参考**，生成开发大纲。

**结构**：
```markdown
# Outline: <pipeline_id>

## 章节 1: <标题>（<N> 步骤，约 <M> 秒）
### 步骤 1
- **屏幕内容**：<hero 图 / 数据卡片 / 标语 / 列表项>
- **口播要点**：<script.md 中对应步骤的核心信息>
- **信息池**：<从 article.md 提取的补充细节，可挂到屏幕上>

### 步骤 2
...

## 章节 2: <标题>（<N> 步骤，约 <M> 秒）
...
```

**双源执行规则**：
- **从 script.md 取**：章节切分、每章步骤数、口播要点（定节奏）
- **从 article.md 取**：屏幕内容细节、信息池（数据/引用/案例）、视觉化元素（定密度）

**outline.md 边界**（必须写 vs 不可写）：

| 必须写 | 不可写 |
|--------|--------|
| 章节切分 + 每章步骤数 + 估时 | 具体动画类型 |
| 每步屏幕内容描述（hero/数据/标语/列表） | CSS 实现手段 |
| 章节级信息池（数字/引用/案例） | 时长数值（秒） |
| 口播要点摘要 | 微动细节 |

### 6. 保留原文

`raw/article.md` 保留不删。不修改、不重命名。

### 7. 反模式检查

对照以下规则逐项检查产出：

**内容提炼反模式**：

| 规则 | 检测 | 修复 |
|------|------|------|
| CD-001 | 大纲层级 >4 层 | 扁平化或拆分视频 |
| CD-002 | 单章节 >500 字（短视频） | 拆分子章节 |
| CD-003 | 口播稿含书面语 | 替换为口语化表达 |
| CD-004 | 关键词覆盖率 <30% | 补充核心术语 |
| CD-005 | 前 10 秒无 Hook | 添加开场钩子 |
| CD-006 | 指定了视角但未注入 Expression DNA | 重新注入 |

**AI Slop 反模式**：

| 规则 | 检测 | 修复 |
|------|------|------|
| SL-001 | 假共情 | 直接抛事实/钩子 |
| SL-002 | 假深刻 | 去掉转折直接说结论 |
| SL-003 | 自我标榜 | 直接说 |
| SL-004 | 万能模板 | 删掉或直接说内容 |
| SL-005 | 排比堆砌 | 保留 1~2 个，其余砍掉 |
| SL-006 | 套话结尾 | 用视角启发式设计结尾 |

**自检流程**：先检查 → 发现问题 → 修复 → 再检查 → 通过后才向用户报告。**不可跳过修复直接报告。**

## Output

- `workspace/<id>/distill/script.md` — 口播稿
- `workspace/<id>/distill/outline.md` — 开发大纲
- `raw/article.md` — 原文（保留不删）

## Anti-Patterns

| ID | 名称 | 检测 | 严重度 |
|----|------|------|--------|
| CD-001 | 层级过深 | outline 层级 >4 | warning |
| CD-002 | 章节过长 | 单章 >500 字 | warning |
| CD-003 | 书面语残留 | script.md 含 "综上所述/由此可见" 等 | critical |
| CD-004 | 信息密度低 | 关键词覆盖率 <30% | warning |
| CD-005 | 缺乏 Hook | 前 10 秒无吸引力 | warning |
| CD-006 | 视角未注入 | 指定了 perspective 但 script 风格中性 | critical |

## Failure Modes

| 场景 | 回退 |
|------|------|
| article.md 为空或不存在 | 阻断，要求用户提供输入 |
| 视角 SKILL.md 不存在 | 跳过视角注入，在 plan.json 标记，继续执行 |
| script.md 字数超出目标 ±30% | 警告用户，建议调整 |
| 反模式 CD-003/CD-006 触发 | 阻断，必须修复后才可继续 |
