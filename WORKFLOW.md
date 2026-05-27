# WORKFLOW.md — Recastory Maestro 详细工作流

> 本文件定义 Phase 0-7 的完整执行流程。Agent 在执行 `/recastory craft` 时必须读取本文件。主入口见 [AGENT.md](AGENT.md)。

---

## Phase 0: Intake（命令解析）

### 步骤

1. 接收用户命令（如 `/recastory craft <url>`）
2. 解析命令参数：
   - `--format`: `short-video` / `course` / `podcast` / `keynote`
   - `--style`: `tech` / `science` / `explainer` / `business` / `casual`
   - `--register`: `brand` / `product`（品牌/产品注册表）
   - `--voice`: TTS 音色 ID
   - `--perspective`: 视角名称（`feynman` / `mrbeast`）
   - `--parallel`: `A`（逐章确认）/ `B`（顺序）/ `C`（并行），默认 `A`
   - `--skip-<skill>`: 跳过指定 Skill
3. 判断输入类型（Route Guard）：

| 输入类型 | 检测方式 | 默认命令 |
|---------|---------|---------|
| Video URL | 以 http/https 开头，指向视频平台 | `/recastory craft` |
| Local Video | 扩展名 `.mp4`/`.mov`/`.avi`/`.mkv` | `/recastory craft` |
| Article/Script | `.md`/`.txt`，无视频特征 | `/recastory craft --skip-ingest --skip-transcribe` |
| Audio Only | 扩展名 `.mp3`/`.wav`/`.m4a` | `/recastory craft --skip-ingest` |
| Research Topic | 用户指定主题而非文件 | `/recastory research` |

4. 按 [references/INDEX.md](references/INDEX.md) 加载领域参考文件（Progressive Loading）
5. 判断注册表类型：
   - `--register` 显式指定 > `brand/REGISTER.md` 中的 `type` 字段 > 从 `--format`/`--style` 推断 > 询问用户
6. 询问未提供的必要参数

---

## Phase 0.5: Ingest（导入）

当用户提供视频 URL 时执行。

1. 下载视频：`yt-dlp` 自动选择最佳质量
2. 提取音频：FFmpeg → 16kHz mono WAV
3. 语音转写：Faster-Whisper → article.md
4. 输出：`workspace/<id>/article.md` + 原始视频 + 音频

```bash
# CLI 模式
python -m tools.ingest "<video-url>" -o workspace/<id>

# 或由 using-recastory 自动调度
```

产出：`workspace/<id>/article.md`（供 Phase 1 distill 使用）
子目录：`workspace/<id>/video/`（原始视频）、`workspace/<id>/audio/`（提取的音频）

> **Note:** ingest 当前作为直接工具调用执行（`python -m tools.ingest`），不通过 plan.json 调度子 Skill。

---

## Phase 1: Design（设计生成）

### 步骤

1. 生成 `design.md`，必须包含：

```markdown
# Design: <pipeline_id>

## 输入
- 类型：<input_type>
- 来源：<file_path or url>

## 输出
- 格式：<target_format>
- 风格：<style>
- 注册表：<brand|product>

## 视角
- 名称：<perspective_name>
- Expression DNA：<expression_dna_summary>
- 注入点：distill, storyboard, critique

## 流水线
- 跳过：<list of skipped skills>
- 并行模式：<A|B|C>

## 双源策略
- script.md：<定节拍>
- article.md：<定画面密度>

## 检查点
- DESIGN: 确认 design.md
- STORYBOARD_PREVIEW: 第一章渲染图 + 口播前 30 秒
- VOICE_PREVIEW: TTS 前 15 秒
- FINAL: 最终视频

## 反模式规则
- 启用：<list of rule IDs>
```

2. **Checkpoint: DESIGN** — 向用户展示 `design.md`，**必须停等用户确认**
3. 用户确认后，进入 Phase 2

---

## Phase 2: Plan（计划生成）

### 步骤

1. 基于 `design.md` 生成 `plan.json`
2. 双源产出（如输入为视频）：
   - `script.md`：从转写文本生成口播稿（口语化、短句、第二人称）
   - `outline.md`：同时参考 script.md + article.md，切章节/步骤/信息池

### plan.json 结构

```json
{
  "pipeline_id": "rm-20260527-001",
  "command": "/recastory craft video.mp4 --perspective feynman",
  "input_type": "local-video",
  "target_format": "short-video",
  "register": "product",
  "perspective": {
    "name": "feynman",
    "source": "recastory",
    "expression_dna": "colloquial, concrete-to-abstract, self-deprecating humor"
  },
  "execution_mode": "A",
  "double_source": {
    "script": "workspace/001/distill/script.md",
    "article": "workspace/001/raw/article.md",
    "outline": "workspace/001/distill/outline.md"
  },
  "references_loaded": ["transcription/REFERENCE.md", "content-distillation/REFERENCE.md"],
  "anti_patterns_enabled": ["TR-001", "CD-001", "CD-003", "SL-001"],
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

### outline.md 边界

| 必须写 | 不要写 |
|--------|--------|
| 章节切分 / 每章 step 数 / 估时 | 具体动画类型 |
| 每步屏幕内容（hero / 数据 / 标语 / 列表项） | CSS 实现手段 |
| 章节级信息池（数字 / 引用 / 案例） | 时长数值 / 微动细节 |

---

## Phase 3: Dispatch（调度执行）

### 执行规则

1. 读取 `plan.json`，构建依赖图
2. 按依赖顺序调度 Skills
3. P0 单 Agent 顺序执行：读取子 Skill 的 SKILL.md + 领域参考文件，在当前会话中按步骤执行（不启动 subagent）。P1 支持 Mode C subagent 并行
4. 视角注入：`distill` 和 `storyboard` 阶段加载视角 Expression DNA

### 多章节并行

**第 1 章强制主线程**：无论选哪种模式，第 1 章必须在主线程完成 + 用户验收后才能继续。

| 模式 | 行为 | "停"的方式 |
|------|------|-----------|
| **A（默认）** | 每章完成后暂停 | 生成渲染预览图 + 展示给用户，等待用户输入"继续" |
| **B** | 第 1 章验收后顺序做完 | 最后统一展示所有章节预览，等待用户验收 |
| **C** | 第 1 章验收后并行 | 多 subagent 同时开发，完成后统一展示预览 |

**并行隔离机制**：

| 隔离层 | 措施 |
|--------|------|
| 物理隔离 | 每章独立文件夹 `src/chapters/<NN>-<id>/` |
| 样式隔离 | 每章独立 CSS 前缀 |
| 视觉统一 | 主题 token 兜底（全局 CSS 变量） |

---

## Phase 4: Audit（确定性检查）

每个 Skill 完成后，**先运行 CLI 审计**，再进入 Review：

```bash
npx recastory-audit --rule <enabled-rules> workspace/<pipeline-id>/<skill>/
```

- **Pass** → 进入 Phase 5
- **Warning** → 记录问题，继续执行
- **Critical** → 阻断流程，等待修复

---

## Phase 5: Review（LLM 审查）

Audit 通过后，运行 LLM 深度审查（6 个维度）：

1. **Spec Compliance** — 输出是否符合 plan.json 预期？
2. **Narrative Quality** — 内容连贯性、信息密度、叙事弧线
3. **Perspective Consistency** — 视角风格是否贯穿始终？
4. **Visual Consistency** — 风格一致性、主题匹配度
5. **Audio Sync** — 口播脚本与幻灯片页数是否对齐？
6. **AI Slop Check** — SL-001~SL-006 规则 + 两阶反射检测

**阻断规则**：Critical 问题必须阻断。

### 自评失真对抗

| 方案 | 实现方式 | 优先级 |
|------|---------|--------|
| 最优 | 开独立 reviewer agent，给产出文件 + 检查清单，从零逐项检查 | 推荐 |
| 次优 | 用 subagent 做质检 | 可接受 |
| 兜底 | 当前 agent 自己逐项核查（必须严格逐项） | 最低要求 |

---

## Phase 6: Checkpoint（人类检查点）

| 检查点 | 展示内容 | 用户操作 |
|--------|---------|---------|
| **DESIGN** | `design.md` | 确认 / 修改 |
| **STORYBOARD_PREVIEW** | 第一章渲染图 + 口播脚本前 30 秒 | 确认 / 修改风格 / 换视角 |
| **VOICE_PREVIEW** | TTS 音频前 15 秒 | 确认 / 修改音色 / 语速 |
| **FINAL** | 最终视频 + 中间产物清单 | 下载 / 重新渲染 |

---

## Phase 7: Deliver（交付）

1. 合并章节级音频：`bash tools/merge-mp3.sh <workspace-dir>`
2. 渲染视频：`bash tools/render-video.sh <workspace-dir>`

脚本自动完成：

- 启动 Vite dev server
- 合并步骤级 MP3 → 章节级 MP3
- Puppeteer 打开浏览器 + 按 SPACE 启动自动播放
- FFmpeg 录屏
- 烧入章节级 SRT 字幕
- 合并为最终 MP4 + 生成 manifest.json

---

## Concrete Example：从视频到成品

### 场景

用户输入一个 10 分钟的技术讲解视频，希望生成一个带 Feynman 风格口播的知识视频。

### 完整流程

```
用户：/recastory craft lecture.mp4 --perspective feynman --register product

Phase 0: Intake
├─ 检测输入类型 → local-video
├─ 加载参考文件 → transcription/ + content-distillation/
├─ 未指定 format → 询问用户 → short-video
├─ 未指定 style → 询问用户 → tech
└─ 未指定 parallel → 默认 A

Phase 1: Design
├─ 生成 design.md（含视角、注册表、流水线路径）
└─ [Checkpoint DESIGN] → 用户确认

Phase 2: Plan
├─ ingest → transcribe → distill → storyboard + voice → render
├─ 产出 script.md（Feynman 风格口播稿）
├─ 产出 outline.md（参考 script + article 双源）
└─ 产出 plan.json

Phase 3: Dispatch
├─ ingest: 本地文件，跳过下载
├─ transcribe: FFmpeg 提取音频 + Whisper 转写
├─ distill: 注入 Feynman Expression DNA，生成口播稿 + 大纲
├─ 第 1 章 storyboard + voice（主线程）
│   └─ [Checkpoint STORYBOARD_PREVIEW] → 用户验收
├─ 第 2~N 章（按 Mode A 逐章确认）
└─ render: Puppeteer 录屏 + FFmpeg 编码

Phase 4: Audit → 每个 Skill 后运行确定性规则
Phase 5: Review → LLM 审查 6 维度

Phase 6: Checkpoints
├─ [Checkpoint VOICE_PREVIEW] → 用户确认音频
└─ [Checkpoint FINAL] → 用户验收最终视频

Phase 7: Deliver
├─ 输出：final.mp4 + subtitles.srt + manifest.json
└─ 清理临时文件
```

### 产出文件结构

```
workspace/rm-20260527-001/
├── raw/
│   ├── lecture.mp4           # 原始视频
│   └── article.md            # 转写文本（article.md 不删）
├── ingest/
│   └── metadata.json
├── transcribe/
│   ├── audio.wav
│   └── transcript.json
├── distill/
│   ├── script.md             # 口播稿（定节拍）
│   └── outline.md            # 大纲（跨步骤记忆）
├── storyboard/
│   └── src/chapters/
│       ├── 01-intro/
│       │   ├── Chapter.tsx
│       │   ├── Chapter.css
│       │   └── narrations.ts
│       └── 02-.../
├── voice/
│   └── public/audio/
│       ├── 01-intro/01.mp3
│       └── ...
├── render/
│   └── final.mp4
├── design.md
├── plan.json
└── manifest.json
```
