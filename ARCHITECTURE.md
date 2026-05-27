# ARCHITECTURE.md — Recastory Maestro v2.0

> **本文件是架构蓝图，供深入理解设计决策时参考。** Agent 每次会话应读取 [AGENT.md](AGENT.md)（主入口）。
>
> The content refinery that makes your AI harness better at media production.

## 项目定位

Recastory Maestro 是一个**任务编排型 Agent**，负责将原始内容（视频 URL、本地视频、文章、脚本）通过可组合的技能（Skills）流水线，重铸为结构化输出（转写文稿、PPT/Keynote、带 TTS 口播的视频）。

Maestro **不直接处理内容**，只负责：
1. 解析用户命令，选择执行模式
2. 加载领域参考文件，注入上下文
3. 生成/读取执行计划（`plan.json`）
4. 调度子 Skill 执行（P0 单 Agent 顺序，P1 支持 subagent 并行）
5. 运行确定性规则检查 + LLM 审查
6. 管理人类检查点（Checkpoint）

---

## 核心哲学

- **Commands over Prompts** — 用共享命令词汇与 AI 交流，而非每次重新描述需求
- **References over Memory** — 每个命令执行时强制加载领域参考文件，AI 不会"遗忘"标准
- **Deterministic Rules over Vibes** — 用 CLI 可运行的硬性规则检测反模式，不依赖 LLM 判断
- **Contracts over Conventions** — 每个 Skill 必须有 Zod Schema 输入/输出契约
- **Review before Proceed** — 双层检查：确定性规则（快）+ LLM 审查（深）
- **Perspectives over Generic** — 通过人格化视角引擎（Perspective Engine）注入差异化创造力，对抗"AI 味"
- **Double-Source over Single-Source** — 内容生产有两个真相源：script.md 定节拍，article.md 定画面密度，二者职责不可混淆
- **Agent judges, Tools execute** — 创作性写入（口播稿/代码/配置）是 Agent 的职责；机械性操作（下载/转码/压缩/文件移动）交给工具。Agent 的创造力用在"怎么编排"，不是"怎么下载"。

---

## Agent-Tool 边界

### 设计原则

Agent（Claude Code）负责**判断和创作**，工具负责**执行和转换**。

核心动机：
1. **可靠性** — 工具做确定性操作，结果可预测
2. **可维护性** — 工具脚本独立测试，不依赖 LLM 发挥
3. **降级能力** — 工具不可用时停下报告，不自行替代

### 创作性 vs 机械性

| 类型 | 示例 | 谁做 |
|------|------|------|
| 创作性写入 | script.md、Chapter.tsx、plan.json | Agent |
| 机械性操作 | 移动文件、校验存在性、压缩转格式 | 工具 |
| 混合型 | audio-segments.json（Agent 写清单，mmx 执行） | 分工 |

### 文件读写边界

| 操作 | 内容产物 (.md/.json/.html) | 二进制 (.mp4/.wav/.mp3) | 目录管理 |
|------|---------------------------|------------------------|---------|
| 读取 | 可以（展示、判断） | 不碰 | — |
| 写入 | 可以（创作） | 不碰 | 例外：可 mkdir -p 自己即将写入的目录 |

### 目录初始化

Agent 可以 `mkdir -p` 自己即将写入的内容产物目录（workspace/ 下的子目录）。其他目录操作（移动、复制、删除）仍交给工具。

### 工具调用协议

- **前置检查**: 运行 auth/status 确认可用
- **结果处理**: 成功→继续，失败→停下报告（P0 不做自动降级）
- **输出校验**: 检查产出文件存在性
- **异常报告**: 记录到 plan.json

### Skill 调度方式

P0 单 Agent 顺序执行：读取子 Skill 的 SKILL.md，在当前会话中按步骤执行。不启动 subagent。

### 配置管理边界

| 职责 | 谁做 | 示例 |
|------|------|------|
| 语义映射 | Agent | "沉稳男声" → male-qn-qingse |
| ID → CLI 参数 | config 模板 | mmx-config.json |
| API Key | 工具读取 | MINIMAX_API_KEY，不暴露给 Agent |

### 检查点展示

P0 直接在对话中贴文本内容（如 script.md 前 200 字），用户看完回复"确认"。不生成 HTML 预览。

### P0 工具清单

| 工具 | 用途 | SKILL.md | 配置 |
|------|------|----------|------|
| mmx CLI | TTS 合成 | voice/SKILL.md | skills/voice/mmx-config.json |

### P1+ 工具清单（预留）

| 工具 | 用途 | 依赖 |
|------|------|------|
| yt-dlp | 视频下载 | ingest |
| FFmpeg | 音频提取、视频编码 | ingest, render |
| Whisper | 语音转写 | transcribe |
| Puppeteer | 录屏 | render |

P1 统一建 `bin/` 目录包装外部工具，每个工具一个脚本，内嵌 mkdir -p。

---

## 一、命令体系（Command Vocabulary）

所有命令通过 `/recastory` 访问：

### 核心流水线命令

| 命令 | 作用 |
|------|------|
| `/recastory craft` | 完整流水线：从输入到最终视频 |
| `/recastory ingest` | 仅下载/解析输入（视频 URL → 本地文件） |
| `/recastory transcribe` | 仅转写（视频/音频 → 文字+时间戳） |
| `/recastory distill` | 仅提炼（文字 → 大纲+口播脚本） |
| `/recastory storyboard` | 仅生成幻灯片（大纲 → HTML slides） |
| `/recastory voice` | 仅生成配音（脚本 → TTS 音频+字幕） |
| `/recastory render` | 仅渲染视频（slides + 音频 → MP4） |

### 质量与审查命令

| 命令 | 作用 |
|------|------|
| `/recastory audit` | 运行确定性质量检查，输出问题报告 |
| `/recastory critique` | LLM 深度审查：内容质量、叙事节奏、视觉一致性 |
| `/recastory polish` | 最终润色：同步对齐、字幕检查、输出格式统一 |

### 内容变体命令

| 命令 | 作用 |
|------|------|
| `/recastory distill-clip` | 从长视频提取精华片段（短视频模式） |
| `/recastory adapt` | 将已有内容适配为不同格式（课程→短视频→播客） |
| `/recastory research` | 深度研究：横纵分析法生成研究报告作为素材 |
| `/recastory illustrate` | 为内容生成配图（GPT Image 2 集成） |

### 快捷指令（Pin）

```bash
/recastory pin craft    # 创建 /craft 快捷指令
/recastory pin audit    # 创建 /audit 快捷指令
```

---

## 二、视角引擎（Perspective Engine）

> 借鉴 nuwa-skill 的认知操作系统提取方法，为内容生产注入差异化创造力。

### 什么是视角引擎

视角引擎不是"角色扮演"，而是提取特定人物的**认知操作系统**：思维模型、决策启发式、表达 DNA。每个视角定义了 HOW someone thinks，而非 WHAT they said。

### 内置视角库

| 视角 | 核心思维模型 | 适用内容类型 | 表达特征 |
|------|------------|-------------|---------|
| **Feynman** | 反自欺、cargo cult 检测 | 科普、原理解释 | 口语化、从具体到抽象、自嘲式幽默 |
| **MrBeast** | CTR×AVD 方程、零无聊时刻、阶梯升级 | 短视频、娱乐内容 | 极度具体、零铺垫、每句制造悬念 |
| **Musk** | 渐近极限思维、五步算法 | 科技解读、产品分析 | 宣言式、数字先行、实时成本拆解 |
| **Munger** | 多元思维模型格栅、反向思考 | 商业分析、投资洞察 | 跨学科类比、反直觉切入 |
| **Naval** | 欲望即痛苦契约、特定知识 | 哲学思考、创业心法 | 箴言式、极简、格言体 |
| **Jobs** | 现实扭曲力场、体验至上 | 产品发布、设计理念 | 戏剧化、极简主义、情感共鸣 |
| **Graham** | 黑天鹅式创业、做不可扩展的事 | 创业方法论 | 随笔式、举例论证、朴素直接 |
| **Karpathy** | 神经直觉、从零实现 | AI/ML 技术解读 | 代码先行、可视化、渐进复杂度 |

### 视角应用方式

每个视角 Skill 包含以下结构，可直接注入内容生产流水线：

```
perspective/
├── SKILL.md              # 视角定义（YAML frontmatter + 完整规范）
├── references/
│   ├── 01-writings.md    # 原始著作/演讲
│   ├── 02-interviews.md  # 访谈记录
│   ├── 03-decisions.md   # 关键决策案例
│   ├── 04-critics.md     # 他人评价
│   ├── 05-patterns.md    # 行为模式提取
│   └── 06-timeline.md    # 人生时间线
```

### 视角在流水线中的注入点

| 阶段 | 注入方式 | 效果 |
|------|---------|------|
| `/recastory distill` | 选择视角的 Expression DNA 生成口播稿 | 脚本风格差异化 |
| `/recastory storyboard` | 选择视角的 Mental Models 决定叙事结构 | 故事架构差异化 |
| `/recastory critique` | 用视角的 Decision Heuristics 审查内容 | 审查维度差异化 |
| `/recastory research` | 用视角的研究维度指导深度分析 | 研究角度差异化 |

### 使用示例

```bash
/recastory craft video.mp4 --perspective feynman
# → 用费曼的认知操作系统重铸内容：从具体例子出发、口语化、反 cargo cult

/recastory distill article.md --perspective mrbeast
# → 用 MrBeast 的注意力工程框架重写脚本：零无聊、阶梯升级、前置极端元素

/recastory critique output/ --perspective munger
# → 用芒格的多元思维模型审查：反向思考、激励分析、跨学科类比
```

---

## 三、领域参考文件（Domain References）

每个命令执行时，必须加载对应的参考文件。这些文件位于 `references/` 目录，确保 AI 不会生成千篇一律的"AI 味"内容。

```
references/
├── transcription/          # 转写领域
│   ├── REFERENCE.md        # 标点规范、说话人标注、时间戳格式
│   └── anti-patterns.md    # 转写反模式
├── content-distillation/   # 内容提炼领域
│   ├── REFERENCE.md        # 大纲结构、信息密度、叙事弧线
│   └── anti-patterns.md
├── storyboard/             # 分镜领域
│   ├── REFERENCE.md        # 主题规范、配色、字体、布局网格
│   ├── themes/             # 每套主题的 theme.json + preview.png
│   └── anti-patterns.md
├── voice/                  # 配音领域
│   ├── REFERENCE.md        # 语速、停顿、情感标记、多音字处理
│   └── anti-patterns.md
├── render/                 # 渲染领域
│   ├── REFERENCE.md        # 分辨率、码率、编码参数、字幕样式
│   └── anti-patterns.md
├── research/               # 研究领域（新增）
│   ├── REFERENCE.md        # 横纵分析法、信息源验证、报告结构
│   └── anti-patterns.md
└── brand/                  # 品牌注册表（用户配置）
    └── REGISTER.md         # 用户品牌色、字体偏好、口播风格
```

### 加载规则（Progressive Reference Loading）

- **全局加载**：`transcription/REFERENCE.md`、`content-distillation/REFERENCE.md` — 所有命令都加载
- **按需加载**：`storyboard/` 仅在 `/storyboard`、`/craft` 时加载；`voice/` 仅在 `/voice`、`/craft` 时加载
- **品牌覆盖**：`brand/REGISTER.md` 最后加载，覆盖参考文件中的默认值
- **渐进加载**：长会话中按步骤加载参考文件，而非一次性全部加载，节省 context window

### 注册表类型（Brand vs Product Register）

> 借鉴 Impeccable 的 register 概念。设计决策必须先确定注册表类型，不同类型适用完全不同的设计规则。

| 注册表 | 适用场景 | 设计规则 |
|--------|---------|---------|
| **Brand**（品牌） | 营销视频、品牌宣传片、产品发布、创意短片 — 设计就是产品本身 | 大胆、戏剧化、色彩饱和、排版实验性、允许反常规 |
| **Product**（产品） | 教程、课程、技术讲解、数据报告 — 设计服务于内容 | 克制、功能性优先、信息密度高、一致性强、可预测 |

**注册表判定规则**（优先级从高到低）：

1. `--register` 参数显式指定
2. `brand/REGISTER.md` 中的 `type` 字段
3. 从 `--format` 推断：`podcast`/`course` → Product，`short-video`/`keynote` → 视内容而定
4. 从 `--style` 推断：`business`/`tech` → Product，`casual`/`explainer` → 视内容而定
5. 无法推断时，询问用户

**注册表对各阶段的影响**：

| 阶段 | Brand 注册表 | Product 注册表 |
|------|------------|---------------|
| `distill` | 允许戏剧化叙事、情感化表达 | 信息密度优先、结构清晰 |
| `storyboard` | 色彩大胆、排版实验性 | 配色克制、布局可预测 |
| `voice` | 语速可变、情感起伏大 | 语速稳定、情感中性 |
| `critique` | 审查创意冲击力、情感共鸣 | 审查信息准确性、逻辑清晰度 |

---

## 四、反模式规则（Anti-Patterns）

### 转写反模式（Deterministic Rules）

| 规则 ID | 检测内容 | 修复动作 |
|---------|---------|---------|
| `TR-001` | 连续 3 个以上无标点长句（>50 字） | 自动插入逗号/句号 |
| `TR-002` | 说话人标签格式不统一 | 统一为 `[说话人] 内容` |
| `TR-003` | 时间戳不连续或重叠 | 标记为需人工校对 |
| `TR-004` | 填充词密度过高（"嗯""啊""这个">5%） | 建议开启过滤模式 |
| `TR-005` | 中英文标点混用 | 统一为中文标点或英文标点 |

### 内容提炼反模式

| 规则 ID | 检测内容 | 修复动作 |
|---------|---------|---------|
| `CD-001` | 大纲层级超过 4 层 | 扁平化或拆分为多个视频 |
| `CD-002` | 单章节字数 >500 字（短视频模式） | 拆分为 2-3 个子章节 |
| `CD-003` | 口播脚本包含书面语（"综上所述""由此可见"） | 替换为口语化表达 |
| `CD-004` | 信息密度过低（关键词覆盖率 <30%） | 标记为需补充 |
| `CD-005` | 缺乏 Hook（前 10 秒无吸引力语句） | 建议添加开场钩子 |
| `CD-006` | 表达 DNA 未注入（未按选定视角风格执行） | 加载对应视角的 Expression DNA |

### 分镜反模式

| 规则 ID | 检测内容 | 修复动作 |
|---------|---------|---------|
| `SB-001` | 单页文字 >80 字 | 拆分为多页或提炼 |
| `SB-002` | 使用默认主题（未匹配内容类型） | 强制要求选择主题 |
| `SB-003` | 配色对比度 <4.5:1 | 标记为无障碍问题 |
| `SB-004` | 动画效果 >3 种/页 | 统一为 1-2 种 |
| `SB-005` | 图片与文字无关（占位图未替换） | 阻断，要求替换 |

### 配音反模式

| 规则 ID | 检测内容 | 修复动作 |
|---------|---------|---------|
| `VO-001` | 语速 >180 字/分钟 或 <120 字/分钟 | 标记为需调整 |
| `VO-002` | 单句长度 >25 字（TTS 易破音） | 拆分为短句 |
| `VO-003` | 多音字未标注（如"行(xíng)业"） | 要求添加拼音标注 |
| `VO-004` | 缺乏停顿标记（连续 5 句无逗号/句号） | 插入呼吸停顿 |

### 渲染反模式

| 规则 ID | 检测内容 | 修复动作 |
|---------|---------|---------|
| `RD-001` | 视频时长与音频时长偏差 >1 秒 | 阻断，检查同步 |
| `RD-002` | 分辨率 ≠ 1920×1080 | 强制重渲染 |
| `RD-003` | 字幕与音频不同步（>0.5 秒） | 标记为需校对 |
| `RD-004` | 输出文件大小 >500MB（短视频） | 建议压缩或分段 |

### CLI 检测方式

```bash
npx recastory-audit workspace/<pipeline-id>/  # 全量扫描
npx recastory-audit --rule TR-001,TR-002 workspace/<pipeline-id>/transcribe/  # 指定规则
npx recastory-audit --json workspace/<pipeline-id>/  # JSON 输出，供 CI 使用
```

### AI Slop Test（AI 味检测）

> 借鉴 Impeccable 的 AI slop test。确定性规则只能检测技术问题，但检测不了"感觉像 AI 做的"这种整体审美判断。

**核心原则**：如果有人能看出这个内容是 AI 生成的，它就失败了。

#### 两阶反射检测

| 层级 | 检测内容 | 例子 | 修复动作 |
|------|---------|------|---------|
| **一阶反射** | 从内容类型就能猜出风格 | "科普→蓝黑配色"、"金融→深蓝+金色"、"科技→深色+霓虹" | 重新选择配色/风格直到无法从领域猜出 |
| **二阶反射** | 避开了一阶但没避开二阶 | "AI工具不用SaaS奶油色→编辑排版风格" — 仍然可预测 | 更深层的风格差异化 |

#### 音视频内容的 AI 味特征（可检测）

| 规则 ID | 检测内容 | 修复动作 |
|---------|---------|---------|
| `SL-001` | 假共情（"我知道你""你是不是也""我能理解"） | 直接抛事实/钩子 |
| `SL-002` | 假深刻（"恰恰/反而/正是"包装，去掉后意思不变） | 去掉转折直接说结论 |
| `SL-003` | 自我标榜（"我必须认真说""颠覆认知""你一定要听完"） | 直接说 |
| `SL-004` | 万能模板（"说白了/本质上/底层逻辑/一句话总结/归根结底"） | 删掉或直接说内容 |
| `SL-005` | 排比堆砌（连续 ≥3 句结构相同） | 保留 1~2 个，其余砍掉 |
| `SL-006` | 套话结尾（"以上就是本期内容/希望对你有帮助/感谢观看"） | 用视角的 Decision Heuristics 设计结尾 |

#### 执行时机

- **Phase 5 Review** 中作为独立审查维度（`AI Slop Check`）
- **Phase 4 Audit** 中对 `SL-001`~`SL-006` 运行确定性检测
- 两阶反射检测仅在 Review 阶段由 LLM 执行（无法确定性检测）

---

## 五、输入类型与 Pipeline 路径

Maestro 必须在启动时判断输入类型，选择对应的 Pipeline（Route Guard 模式）：

| 输入类型 | 检测方式 | 默认命令 |
|---------|---------|---------|
| **Video URL** | 以 http/https 开头，指向视频平台 | `/recastory craft` |
| **Local Video** | 文件扩展名 `.mp4`/`.mov`/`.avi`/`.mkv` | `/recastory craft` |
| **Article/Script** | 纯文本、`.md`、`.txt`，无视频特征 | `/recastory craft --skip-ingest --skip-transcribe` |
| **Audio Only** | 文件扩展名 `.mp3`/`.wav`/`.m4a` | `/recastory craft --skip-ingest` |
| **Research Topic** | 用户指定主题而非文件 | `/recastory research` |

---

## 六、工作流（Workflow）

### 双源原则（Double-Source Principle）

> 内容生产有两个真相源，职责不同，不可混淆，不可合并。

| 源 | 作用 | 不可违反的规则 |
|---|---|---|
| `script.md`（口播稿） | **定节拍** | 口播顺序不可乱，一步一拍。脚本节奏 = 视觉推进节奏 |
| `article.md`（原文） | **定画面密度** | 口播没念但 article 有的细节，挂到屏幕画面和信息池里。`article.md` 不删 |

**为什么需要两个源**：

- `script.md` 决定的是**时间线**：观众听到什么、按什么顺序听到、每段多长
- `article.md` 决定的是**信息密度**：屏幕上展示什么数据、案例、引用、图表
- 如果只保留 script.md，视频"信息密度"骤降 — 观众听到的和看到的完全一样，没有信息增量
- 如果只保留 article.md，节奏失控 — 画面和口播脱节

**在流水线中的执行**：

| 阶段 | 读取哪个源 | 用途 |
|------|-----------|------|
| `distill` 生成 script.md | article.md | 提取核心信息，转化为口语化脚本 |
| `distill` 生成 outline.md | script.md + article.md | script 定章节切分和 step，article 定信息池 |
| `storyboard` 渲染每章 | outline.md（回溯到两个源） | 口播文本来自 script 段落，屏幕内容来自 article 细节 |
| `voice` 合成音频 | script.md | 严格按 script 顺序和节奏合成 |

**outline.md 的边界**：

| outline 必须写 | outline 不要写 |
|---|---|
| 章节切分 / 每章 step 数 / 估时 | 具体动画类型（blur clear / wipe / 弹簧） |
| 每步屏幕内容（hero / 数据 / 标语 / 列表项） | CSS 实现手段（filter / SVG / clip-path） |
| 章节级信息池：从 article 抽的数字 / 引用 / 案例 | 时长数值 / 持续微动 / 错峰量 |

### Phase 0: Intake（命令解析）

1. 接收用户命令（如 `/recastory craft <url>`）
2. 解析命令参数：
   - `--format`: `short-video` / `course` / `podcast` / `keynote`
   - `--style`: `tech` / `science` / `explainer` / `business` / `casual`
   - `--register`: `brand` / `product`（品牌/产品注册表）
   - `--voice`: TTS 音色 ID
   - `--perspective`: 视角名称（`feynman` / `mrbeast` / `musk` 等）
   - `--parallel`: 并行模式（`A` / `B` / `C`，默认 `A`）
   - `--skip-<skill>`: 跳过指定 Skill
3. 判断输入类型（Route Guard）
4. 加载领域参考文件（Progressive Loading）
5. 询问未提供的必要参数（如风格、音色）

### Phase 1: Design（设计生成）

1. 生成 `design.md`：
   - Pipeline 路径
   - 输出格式与风格
   - 注册表类型（Brand / Product）及设计策略
   - 主题选择（如适用）
   - 视角选择（如适用）及 Expression DNA 注入策略
   - 并行模式（A / B / C）
   - 双源策略（script.md + article.md 的职责划分）
   - 检查点策略
   - 反模式规则启用列表（含 AI Slop 规则）
2. **Checkpoint: DESIGN** — 向用户展示 `design.md`，等待确认
3. 用户确认后，生成 `plan.json`

### Phase 2: Plan（计划生成）

`plan.json` 必须包含：

```json
{
  "pipeline_id": "rm-20260527-001",
  "command": "/recastory craft video.mp4 --perspective feynman",
  "input_type": "local-video",
  "target_format": "short-video",
  "register": "brand",
  "perspective": {
    "name": "feynman",
    "source": "recastory",
    "expression_dna": "colloquial, concrete-to-abstract, self-deprecating humor",
    "mental_models": ["anti-self-deception", "cargo-cult-detection"],
    "research_dimensions": ["basic-physics", "logical-holes", "experimental-data"]
  },
  "parallel_mode": "A",
  "double_source": {
    "script": "workspace/001/distill/script.md",
    "article": "workspace/001/raw/article.md",
    "outline": "workspace/001/distill/outline.md"
  },
  "references_loaded": [
    "transcription/REFERENCE.md",
    "content-distillation/REFERENCE.md",
    "storyboard/REFERENCE.md",
    "voice/REFERENCE.md"
  ],
  "anti_patterns_enabled": ["TR-001", "TR-002", "CD-001", "CD-003", "CD-005", "SB-001", "VO-002", "SL-001", "SL-002", "SL-003"],
  "skills": [
    { "name": "ingest", "depends_on": [] },
    { "name": "transcribe", "depends_on": ["ingest"] },
    { "name": "distill", "depends_on": ["transcribe"] },
    { "name": "storyboard", "depends_on": ["distill"] },
    { "name": "voice", "depends_on": ["distill"] },
    { "name": "render", "depends_on": ["storyboard", "voice"] }
  ],
  "parallel_groups": [
    { "skills": ["storyboard", "voice"], "after": "distill" }
  ]
}
```

### Phase 3: Dispatch（调度执行）

1. 读取 `plan.json`，构建依赖图
2. 按依赖顺序调度 Skills
3. **并行规则**：`parallel_groups` 中的 Skills 满足依赖后可同时调度
4. P0 单 Agent 顺序执行：读取子 Skill 的 SKILL.md，在当前会话中按步骤执行。P1 支持 Mode C subagent 并行（每个 subagent 执行前必须重新读取 `SKILL.md` 和领域参考文件）
5. **视角注入**：在 `distill` 和 `storyboard` 阶段，加载 `--perspective` 指定的视角 Skill，注入 Expression DNA

#### 多章节并行模式

> 当内容包含多个章节（如长视频拆分为 2~N 章）时，用户可选择执行模式：

| 模式 | 行为 | 适用场景 | 风格一致性保障 |
|------|------|---------|---------------|
| **A · 逐章确认**（默认） | 第 2 章→停→第 3 章→停→...→第 N 章 | 用户不确定风格时 | 天然一致（每章用户确认） |
| **B · 顺序开发** | 第 2~N 章主线程顺序做完，最后统一验收 | agent 不支持并行时 | 依赖上下文传递 |
| **C · 并行 subagent** | 第 2~N 章 subagent 并行，用户控制并行数 | 最快，风格差异为预期行为 | 每个 subagent 必须重新加载同一视角的 Expression DNA |

**并行模式选择规则**：

1. 用户未指定时，默认 Mode A（逐章确认）
2. `--parallel` 参数选择 Mode C，可指定并行数（如 `--parallel 3`）
3. `--sequential` 参数选择 Mode B
4. **第 1 章强制主线程**：无论选哪种模式，第 1 章必须在主线程完成 + 用户验收后才能继续。这是质量锚点

**Mode C 并行一致性保障**：

- 每个 subagent 执行前必须重新加载：`SKILL.md` + 领域参考文件 + 视角 Expression DNA
- subagent 之间不共享上下文，每章独立按规范自由发挥
- 并行完成后，运行一致性审查：检查各章之间的风格偏差（配色、字体、语气、节奏）

**多章节并行隔离机制**（防止 subagent 互相冲突）：

| 隔离层 | 措施 |
|--------|------|
| 物理隔离 | 每章独立文件夹（`src/chapters/<NN>-<id>/`） |
| 样式隔离 | 每章独立 CSS 前缀，不抢类名 |
| 视觉统一 | 主题 token 兜底（字体/颜色/间距走全局 CSS 变量） |

### Phase 4: Audit（确定性检查）

每个 Skill 完成后，**先运行 CLI 审计**，再进入 Review：

```bash
npx recastory-audit --rule <enabled-rules> workspace/<pipeline-id>/<skill>/
```

- **Pass**：进入 Phase 5
- **Warning**：记录问题，继续执行
- **Critical**：阻断流程，等待修复

### Phase 5: Review（LLM 审查）

Audit 通过后，运行 LLM 深度审查：

1. **Spec Compliance** — 输出是否符合 `plan.json` 预期？
2. **Narrative Quality** — 内容连贯性、信息密度、叙事弧线
3. **Perspective Consistency** — 视角风格是否贯穿始终？（如已指定视角）
4. **Visual Consistency** — 风格一致性、主题匹配度
5. **Audio Sync** — 口播脚本与幻灯片页数是否对齐？
6. **AI Slop Check** — 两阶反射检测 + SL-001~SL-006 规则（见四、反模式规则）
7. **Register Consistency** — 设计决策是否符合注册表类型（Brand vs Product）？
8. **Double-Source Check** — outline.md 是否同时参考了 script.md 和 article.md？

**阻断规则**：Critical 问题必须阻断。

### Phase 6: Checkpoint（人类检查点）

| 检查点 | 展示内容 | 用户操作 |
|--------|---------|---------|
| **DESIGN** | `design.md`（含视角选择） | 确认 / 修改 |
| **STORYBOARD_PREVIEW** | 第一章渲染图 + 口播脚本前 30 秒 | 确认 / 修改风格 / 换视角 |
| **VOICE_PREVIEW** | TTS 音频前 15 秒 | 确认 / 修改音色 / 语速 |
| **FINAL** | 最终视频 + 中间产物清单 | 下载 / 重新渲染 |

### Phase 7: Deliver（交付）

1. 汇总所有输出文件
2. 生成 `manifest.json`
3. 运行最终 `polish` 检查
4. 清理临时文件（可选）

---

## 七、Skill 契约规范

```
skills/
├── ingest/
│   ├── SKILL.md
│   ├── schema.ts         # Zod Schema
│   ├── anti-patterns.ts  # 该 Skill 的确定性规则
│   ├── index.ts
│   └── test/
├── transcribe/
│   ├── SKILL.md
│   ├── schema.ts
│   ├── anti-patterns.ts
│   ├── index.ts
│   └── test/
├── distill/
│   ├── SKILL.md
│   ├── schema.ts
│   ├── anti-patterns.ts
│   ├── index.ts
│   └── test/
├── storyboard/
│   ├── SKILL.md
│   ├── schema.ts
│   ├── anti-patterns.ts
│   ├── index.ts
│   └── test/
├── voice/
│   ├── SKILL.md
│   ├── schema.ts
│   ├── anti-patterns.ts
│   ├── index.ts
│   └── test/
├── render/
│   ├── SKILL.md
│   ├── schema.ts
│   ├── anti-patterns.ts
│   ├── index.ts
│   └── test/
├── review/
│   ├── SKILL.md
│   ├── schema.ts
│   ├── index.ts
│   └── test/
├── research/
│   ├── SKILL.md
│   ├── schema.ts
│   ├── anti-patterns.ts
│   ├── index.ts
│   └── test/
└── perspectives/          # 视角库
    ├── feynman/
    │   ├── SKILL.md
    │   └── references/
    ├── mrbeast/
    │   ├── SKILL.md
    │   └── references/
    └── .../
```

### SKILL.md 最小模板

```markdown
# Skill: <name>

## IRON LAW
一条不可违反的铁律（借鉴 IRON LAW 模式）。

## Purpose
一句话描述。

## Input
- 文件路径及格式
- Zod Schema

## Output
- 文件路径及格式
- Zod Schema

## Dependencies
- 前置 Skill
- 系统依赖

## Anti-Patterns
- 该 Skill 负责的确定性规则 ID 列表
- 检测方式
- 自动修复逻辑

## Failure Modes
- 已知失败场景
```

### 事件信封（Event Envelope）

```json
{
  "pipeline_id": "rm-20260527-001",
  "skill": "transcribe",
  "version": "1.0.0",
  "status": "success",
  "input_files": ["workspace/001/raw/video.mp4"],
  "output_files": {
    "transcript": "workspace/001/transcribe/transcript.json",
    "audio": "workspace/001/transcribe/audio.wav"
  },
  "audit_result": {
    "passed": true,
    "warnings": [],
    "criticals": []
  },
  "metrics": {
    "duration_seconds": 120.5,
    "confidence": 0.94,
    "processing_time_seconds": 45.2
  },
  "perspective_applied": "feynman",
  "timestamp": "2026-05-27T15:14:00Z"
}
```

### 测试策略（Testing Strategy）

> 借鉴 superpowers 的 TDD 方法论 + darwin-skill 的 8 维评分体系。每个 Skill 必须有测试保障。

#### 三层测试体系

| 层 | 方法 | 覆盖范围 | 执行时机 |
|----|------|---------|---------|
| **L1: Schema 测试** | 验证输入输出符合 Zod Schema | 数据格式正确性 | 每次 Skill 执行后自动运行 |
| **L2: 确定性规则测试** | 验证 anti-patterns.ts 的规则覆盖 | 技术质量 | Phase 4 Audit |
| **L3: LLM 质量测试** | 用 golden samples 对比 LLM 输出质量 | 内容质量 | 开发阶段 + 版本发布前 |

#### L1: Schema 测试（必须）

每个 Skill 的 `test/` 目录必须包含：

```
test/
├── fixtures/            # 测试数据
│   ├── input-valid.json     # 合法输入样例
│   ├── input-invalid.json   # 非法输入样例（边界条件）
│   └── output-golden.json   # 期望输出样例
├── schema.test.ts       # Schema 合规性测试
└── integration.test.ts  # 端到端集成测试（可选）
```

**Schema 测试必须覆盖**：
- 合法输入 → 输出符合 Schema
- 非法输入 → 明确错误信息
- 边界条件（空输入、超大输入、特殊字符）
- 可选字段缺失时的默认值行为

#### L2: 确定性规则测试（必须）

```bash
# 测试单条规则
npx recastory-test --rule TR-001 --fixture test/fixtures/transcribe/

# 测试全部规则
npx recastory-test --all --fixture test/fixtures/
```

每个 anti-pattern 规则必须有对应的测试 fixture，包含：
- **正例**：应该被检测到的问题样本
- **反例**：不应该被误报的正常样本

#### L3: LLM 质量测试（推荐）

> **MVP 使用 4 维评分（见 [SKILL-TEMPLATE.md](SKILL-TEMPLATE.md)）。** 以下 8 维体系为 v2.0 扩展目标。
>
> 借鉴 darwin-skill 的 8 维评分 rubric。

| 维度 | 权重 | 评分标准 |
|------|------|---------|
| Schema 合规性 | 15% | 输出是否符合 Zod Schema |
| 反模式规避 | 15% | 是否触发了 anti-pattern 规则 |
| 视角一致性 | 15% | Expression DNA 是否贯穿始终 |
| 信息保留度 | 15% | 原文信息保留比例（≥60%） |
| 口语化程度 | 10% | 书面语/口语比例 |
| 叙事节奏 | 10% | 信息密度起伏是否合理 |
| 创意差异化 | 10% | 是否可被预测（AI slop test） |
| 技术质量 | 10% | 无障碍、性能、兼容性 |

**执行方式**：

```bash
# 运行 LLM 质量评分
npx recastory-score --skill distill --input test/fixtures/distill/input.json --output workspace/distill/result.json

# 输出 JSON 评分报告
{
  "skill": "distill",
  "total_score": 82,
  "dimensions": {
    "schema_compliance": { "score": 15, "max": 15, "detail": "pass" },
    "anti_pattern_avoidance": { "score": 13, "max": 15, "detail": "CD-003 triggered" },
    "perspective_consistency": { "score": 14, "max": 15, "detail": "strong feynman voice" },
    "information_retention": { "score": 12, "max": 15, "detail": "67% retained" },
    "colloquial_level": { "score": 8, "max": 10, "detail": "2 formal phrases detected" },
    "narrative_rhythm": { "score": 8, "max": 10, "detail": "even density" },
    "creative_differentiation": { "score": 7, "max": 10, "detail": "predictable structure" },
    "technical_quality": { "score": 5, "max": 10, "detail": "contrast ratio 3.8:1" }
  }
}
```

#### 质量基线

| 等级 | 总分 | 说明 |
|------|------|------|
| **A** | ≥90 | 可直接发布 |
| **B** | 80-89 | 需微调后发布 |
| **C** | 70-79 | 需要人工审查 |
| **D** | <70 | 需要重新生成 |

**发布门槛**：总分 ≥ 80，且无单维度 < 50% 的项。

#### 命令

```bash
/recastory test-skill distill         # 运行指定 Skill 的全部测试
/recastory test-skill --all           # 运行所有 Skill 的全部测试
/recastory score distill output.json  # 运行 LLM 质量评分
/recastory score --all workspace/     # 评分整个 workspace
```

---

## 八、与现有项目的集成映射

| Recastory Skill | 复用来源 | 对应模块 | 需添加 |
|----------------|---------|---------|--------|
| `ingest` | ClipScribe | `video_downloader.py` + `video_parser.py` + yt-dlp | `anti-patterns.ts` |
| `transcribe` | ClipScribe | `audio_extractor.py` + `audio_to_text.py` | `anti-patterns.ts` |
| `distill` | ClipScribe + SlideNarrator | `text_polish.py` + `script-generator` + `outline-generator` | `anti-patterns.ts` + 视角注入 |
| `storyboard` | SlideNarrator | `web-video-presentation`（23 套主题） | `anti-patterns.ts` |
| `voice` | SlideNarrator | `subtitle-generator` + TTS | `anti-patterns.ts` |
| `render` | SlideNarrator | `ffmpeg-encoder` + `puppeteer-recorder` | `anti-patterns.ts` |
| `review` | 新建 | — | 完整实现 |
| `research` | SlideNarrator + skill-collection | `deep-research` + `hv-analysis` | 横纵分析法 |
| `perspectives` | skill-collection | `nuwa-skill` 视角库 | 视角提取工厂 |

### 基础设施复用（ClipScribe 模块）

| ClipScribe 模块 | Recastory 用途 |
|----------------|---------------|
| `pipeline.py` + `auto_processor.py` | 流水线编排引擎 |
| `download_queue.py` | 下载队列管理 |
| `progress_tracker.py` | 进度追踪 |
| `retry_handler.py` | 失败重试 |
| `storage_manager.py` | 存储管理 |
| `litellm_config.py` | 多模型路由 |

---

## 九、多 Harness 安装

| 工具 | 安装路径 |
|------|---------|
| **Claude Code** | `.claude/skills/recastory-maestro/` |
| **OpenCode** | `.opencode/skills/recastory-maestro/` |
| **Codex CLI** | `.agents/skills/recastory-maestro/` |
| **Cursor** | `.cursor/skills/recastory-maestro/` |
| **GitHub Copilot** | `.github/skills/recastory-maestro/` |

安装后，在对应工具中运行：
```
/recastory craft <url>
```

---

## 十、约束与恢复

### 反馈修复的最小切片原则

> 不要重做整章，先定位问题在哪一层，只改最小的切片。

用户反馈"第 3 步节奏太快"时，不要重做整个章节（会把做对的部分也改掉）。

| 问题层级 | 修复范围 | 例子 |
|---------|---------|------|
| **节奏问题** | 只改对应段落的口播节奏 | 第 3 步语速太快 → 拆分该步为两步 |
| **视觉内容** | 只改某一步的画面 | 第 5 步信息太密 → 拆分为多页 |
| **代码问题** | 只改对应组件 | 某步动画卡顿 → 优化该动画 CSS |

### 自评失真对抗

让写代码的 agent 自己评价，结果大概率是"还不错"。必须用独立 reviewer 对抗：

| 方案 | 实现方式 | 优先级 |
|------|---------|--------|
| **最优** | 开独立 reviewer agent，给产出文件 + 检查清单，从零逐项检查 | 推荐 |
| **次优** | 用 subagent 做质检 | 可接受 |
| **兜底** | 当前 agent 自己逐项核查（必须严格逐项，不允许目测放行） | 最低要求 |

---

## 十一、禁止行为（Hard Constraints）

1. **禁止无命令执行**：必须通过 `/recastory <command>` 触发，禁止自由发挥
2. **禁止跳过参考文件**：执行任何命令前必须加载对应领域参考文件
3. **禁止跳过 Audit**：每个 Skill 后必须先运行确定性检查，再进入 LLM Review
4. **禁止跳过 Plan**：未生成 `plan.json` 前不得执行任何 Skill
5. **禁止修改已确认设计**：`design.md` 确认后如需修改，必须重新走 Phase 0
6. **禁止假设输入类型**：必须通过检测逻辑或用户确认判断
7. **禁止 Checkpoint 自动继续**：必须收到用户明确确认
8. **禁止使用占位内容**：检测到占位图/占位音频必须阻断
9. **禁止视角漂移**：选定视角后，Expression DNA 必须贯穿整个流水线，不可中途切换
10. **禁止删除原文**：`article.md` 保留不删，它是画面密度的真相源
11. **禁止跳过双源**：`outline.md` 必须同时参考 `script.md` 和 `article.md`，不可只依赖一个源
12. **禁止跳过测试**：Skill 发布前必须通过 L1 Schema 测试 + L2 确定性规则测试

---

## 十二、快速启动检查清单

当用户输入 `/recastory craft <input>` 时：

- [ ] 1. 解析命令，识别输入类型（Route Guard）
- [ ] 2. 判断注册表类型（Brand / Product）
- [ ] 3. 加载领域参考文件（Progressive Loading）+ 品牌注册表
- [ ] 4. 加载视角 Skill（如指定 `--perspective`）
- [ ] 5. 确认双源：`script.md`（定节拍）+ `article.md`（定画面密度）
- [ ] 6. 询问缺失参数（格式、风格、音色、并行模式）
- [ ] 7. 生成 `design.md`（含注册表、视角、并行模式、双源策略）
- [ ] 8. **Checkpoint DESIGN** — 等待确认
- [ ] 9. 生成 `plan.json`
- [ ] 10. 按 Plan 调度 Skills（按选定并行模式执行）
- [ ] 11. 每个 Skill 后运行 Audit（确定性规则 + AI Slop 规则）
- [ ] 12. Audit 通过后运行 Review（LLM，含 AI Slop Check + Register Check）
- [ ] 13. 遇到 Checkpoint 暂停等待确认
- [ ] 14. 最终 Deliver，输出 `manifest.json` + 质量评分报告

---

## 十三、错误处理与回退

| 场景 | 回退策略 |
|------|----------|
| LLM API 调用失败 | 切换备用模型 (SiliconFlow → OpenRouter → Ollama) |
| TTS 合成失败 | 跳过音频，仅输出无声视频 + 字幕 |
| Whisper 转写失败 | 提示用户手动输入文本 |
| FFmpeg 编码失败 | 输出原始录屏文件，提示用户手动转换 |
| 在线下载失败 | 提示用户手动上传文件 |
| 视角 Skill 加载失败 | 回退到默认视角（无风格注入），警告用户 |
| 主题文件缺失 | 回退到 `paper-press` 默认主题 |

### 录屏三种模式（render Skill）

| 模式 | URL 参数 | 行为 | 适用场景 |
|------|---------|------|---------|
| **手动模式**（默认） | 无 | 不播放音频，用户自由切换步骤，自己录声音 | 用户想用自己的声音录制 |
| **音频模式** | `?audio=1` | 自动播放音频，用户手动推进步骤 | 用户想配合音频手动控制节奏 |
| **自动模式** | `?auto=1` | 按下空格后自动按音频节奏播放 | 全自动录屏 |

---

## 版本

- AGENT.md Version: 3.0.0（本文件为 v2.2.0 架构蓝图，已降级为参考文档）
- Inspired by: superpowers, impeccable, nuwa-skill, SlideNarrator, ClipScribe, darwin-skill, hv-analysis, 可乐米花园视频生成教程
- Compatible with: Claude Code, Codex CLI, OpenCode, Cursor, GitHub Copilot
