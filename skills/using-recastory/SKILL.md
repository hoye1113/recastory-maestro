---
name: using-recastory
version: 1.1.0
description: >
  Recastory Maestro 主入口 — 接收用户输入（命令 / URL / 文件 / 自然语言），识别意图，
  生成执行计划（plan.json），调度子 Skill 完成媒体生产流水线，管理 4 个检查点。
  触发条件：/recastory 命令、视频 URL、音视频文件路径、"帮我做个视频"等自然语言。
user-invocable: true
argument-hint: "[craft|distill|voice|storyboard|research] <input> [--perspective <name>] [--register <brand|product>] [--dry-run]"
---

# Skill: using-recastory

## IRON LAW

**无 plan.json 不执行任何 Skill。不跳过任何检查点。**

违反任一条 = 立即停止，向用户报告违规原因。

## Purpose

接收用户输入（命令 / URL / 文件 / 自然语言），生成执行计划（plan.json），调度子 Skill 完成媒体生产流水线。

## Preconditions

- AGENT.md 已加载（会话开始时自动加载）
- 用户提供了有效输入（命令、文件路径、URL 或自然语言需求）
- 工作目录可写（workspace/ 下可创建子目录）

## Steps

### 1. 意图识别

检测用户输入类型，确定执行路径：

| 输入类型 | 检测方式 | 默认命令 | skip 标志 |
|---------|---------|---------|----------|
| `/recastory <cmd>` | 显式命令 | 按命令路由 | 用户指定 |
| `/recastory research` | 显式命令 | `research`（主题调研） | — |
| 视频 URL | http/https 开头，指向视频平台 | `craft`（自动走 ingest→transcribe 流水线） | — |
| 本地视频 | 扩展名 .mp4/.mov/.avi/.mkv | `craft`（跳过下载，从 extract+transcribe 开始） | — |
| 文章/脚本 | .md/.txt，无视频特征 | `craft` | `--skip-ingest --skip-transcribe` |
| 仅音频 | .mp3/.wav/.m4a | `craft` | `--skip-ingest` |
| 自然语言 | "帮我做个视频" 等语义匹配 | `craft` | 按输入类型推断 |

**具体检测示例**：

| 用户输入 | 检测结果 | 路由 |
|---------|---------|------|
| `/recastory craft lecture.mp4 --perspective feynman` | 显式命令 + 本地视频 | craft，跳过 ingest |
| `https://www.youtube.com/watch?v=abc123` | 视频 URL | craft，含 ingest+transcribe |
| `这是我的文章.md` | 本地文章 | craft，skip-ingest + skip-transcribe |
| `帮我把这段录音做成视频` + `recording.wav` | 自然语言 + 音频 | craft，skip-ingest |
| `/recastory distill article.md --perspective mrbeast` | 显式命令 | distill |

**视频 URL ingest 流水线**：当输入为视频 URL 时，plan.json 中自动包含 `ingest` 和 `transcribe` 两个 Skill，按顺序执行：

```text
ingest（yt-dlp 下载 + FFmpeg 提取音频） → transcribe（Faster-Whisper 转写 → article.md） → distill → ...
```

CLI 独立运行：`python -m tools.ingest "<video-url>" -o workspace/<id>`

**无法确定输入类型时**：向用户展示检测结果和候选选项，请用户选择正确的输入类型和执行命令。

### 2. 解析参数

从用户输入中提取：

| 参数 | 默认值 | 说明 | 可选值 |
|------|--------|------|--------|
| `--format` | `short-video` | 输出格式 | short-video / course / podcast / keynote |
| `--style` | `explainer` | 内容风格 | tech / science / explainer / business / casual |
| `--register` | 从 brand/REGISTER.md 推断，否则询问 | 注册表类型 | brand（大胆/戏剧化）/ product（克制/信息密度） |
| `--perspective` | 无 | 视角名称 | feynman / mrbeast / 任意 nuwa-skill 视角名 |
| `--parallel` | `A` | 并行模式 | A（逐章确认）/ B（顺序）/ C（并行） |
| `--voice` | 默认 TTS 音色 | TTS 音色 ID | 见 tts-config.json voice_map |
| `--dry-run` | false | 试运行模式 | true / false |

**参数解析优先级**（从高到低）：
1. 命令行显式指定（`--register brand`）
2. brand/REGISTER.md 中的 `type` 字段
3. 从 `--format`/`--style` 推断（podcast/course → product；short-video/keynote → 视内容而定）
4. 无法推断时，向用户展示推断依据和候选值，请用户确认

**冲突参数处理**：当参数之间存在冲突时（如 `--format keynote` + `--style casual`），向用户展示冲突说明，请用户选择。

### 3. 加载参考文件

按 `references/INDEX.md` 的 Progressive Loading 规则：

1. **全局加载**：`references/transcription/REFERENCE.md` + `references/content-distillation/REFERENCE.md`（如存在）
2. **命令对应领域参考**（如 `references/storyboard/REFERENCE.md`、`references/voice/REFERENCE.md`）；`/recastory research` 加载 `references/research/REFERENCE.md`
   - `/recastory distill` 时，`skills/humanizer-zh/SKILL.md` 的 10 条生成约束规则作为**必须加载项**（非可选），因为它们是 Phase B 的前置条件
3. **视角 Expression DNA**（如指定 `--perspective`）：
   - 检查 `skills/perspectives/<name>/SKILL.md` 是否存在
   - 如存在 → 直接使用
   - 如不存在 → 检查 `skills/nuwa-skill/examples/<name>-perspective/SKILL.md`
   - 如存在 → 读取文件内容到上下文，在 plan.json 中标记 `perspective.source: "nuwa-skill"`
   - 如都不存在 → 报错："视角 <name> 未找到"
   - **格式适配**: nuwa-skill 视角为问答式格式，需从中提取表达风格特征（句式、词汇、节奏、幽默方式）用于内容生产，而非直接使用其角色扮演逻辑。参考 `skills/perspectives/feynman/SKILL.md` 的 Expression DNA 结构做适配。
   - **前提**: P0 单 Agent 会话共享上下文（已读入的 nuwa-skill 视角内容在 distill 执行时可用）。P1 subagent 模式时需在 dispatch 前将 `skills/nuwa-skill/examples/<name>-perspective/SKILL.md` 复制到 `skills/perspectives/<name>/SKILL.md`，因为 subagent 不继承主 Agent 的上下文。
4. **品牌注册表** `brand/REGISTER.md`（最后加载）

**参考文件过大处理**：如单个 REFERENCE.md 超过 3000 tokens，优先加载 `REFERENCE-SUMMARY.md`（如存在），完整版按需在子 Skill 执行时加载。

### 4. 生成 design.md

按 WORKFLOW.md Phase 1 模板生成 `workspace/<id>/design.md`，必须包含：

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

## 检查点定义
- DESIGN: 确认 design.md
- STORYBOARD_PREVIEW: 第一章渲染图 + 口播前 30 秒
- VOICE_PREVIEW: TTS 前 15 秒
- FINAL: 最终视频

## 反模式规则
- 启用：<list of rule IDs>
```

**workspace 目录初始化**：在生成 design.md 前，创建 `workspace/<id>/` 目录及子目录（raw/, distill/, storyboard/, voice/, render/）。

**Pipeline ID 格式**：`rm-YYYYMMDD-NNN`（如 `rm-20260528-001`），NNN 为当日序号，自动递增避免冲突。

**[Checkpoint: DESIGN]** — 向用户展示 design.md 全文，等待用户确认。提供选项："确认"/"修改"/"重新生成"。用户确认后才可继续。

### 5. 生成 plan.json

将 design.md 转化为 `workspace/<id>/plan.json`，格式如下：

```json
{
  "pipeline_id": "rm-20260528-001",
  "command": "/recastory craft article.md --perspective feynman",
  "input_type": "article",
  "target_format": "short-video",
  "register": "product",
  "perspective": {
    "name": "feynman",
    "source": "recastory",
    "expression_dna": "colloquial, concrete-to-abstract, self-deprecating humor"
  },
  "execution_mode": "A",
  "dry_run": false,
  "double_source": {
    "script": "workspace/rm-20260528-001/distill/script.md",
    "article": "workspace/rm-20260528-001/raw/article.md",
    "outline": "workspace/rm-20260528-001/distill/outline.md"
  },
  "references_loaded": ["transcription/REFERENCE.md", "content-distillation/REFERENCE.md"],
  "anti_patterns_enabled": ["CD-001", "CD-003", "SL-001", "SL-002", "SL-003", "SL-004", "SL-005", "SL-006"],
  "skills": [
    { "name": "ingest", "depends_on": [] },
    { "name": "transcribe", "depends_on": ["ingest"] },
    { "name": "distill", "depends_on": ["transcribe"] },
    { "name": "storyboard", "depends_on": ["distill"] },
    { "name": "voice", "depends_on": ["distill"] },
    { "name": "render", "depends_on": ["storyboard", "voice"] },
    { "name": "audit", "depends_on": ["render"] },
    { "name": "critique", "depends_on": ["audit"] }
  ],
  "parallel_groups": [
    { "skills": ["ingest"], "after": null },
    { "skills": ["transcribe"], "after": "ingest" },
    { "skills": ["storyboard", "voice"], "after": "distill" },
    { "skills": ["render"], "after": ["storyboard", "voice"] },
    { "skills": ["audit"], "after": "render" },
    { "skills": ["critique"], "after": "audit" }
  ]
}
```

**dry_run 模式**：当 `--dry-run` 指定时，plan.json 中 `dry_run: true`。子 Skill 读取此字段后：
- 跳过实际工具调用（TTS 合成、视频下载、FFmpeg 编码等）
- 仅输出将要执行的命令列表和结构化产物（如 audio-segments.json）
- 用于验证流程正确性、参数合理性，不产生实际媒体文件

**plan.json 验证**：生成后检查以下必填字段是否完整：
- `pipeline_id`、`command`、`input_type`、`target_format`、`skills`（非空数组）
- `skills` 中每个条目有 `name` 和 `depends_on`
- 依赖图无环（不存在 A→B→A 的循环依赖）

验证失败时，向用户展示具体错误项，请用户确认是否修复后重新生成。

如用户指定了 `--skip-ingest` 或 `--skip-transcribe`，plan.json 的 skills 数组中不包含对应 Skill，且 parallel_groups 中对应条目也需移除。

### 6. 调度子 Skill

按 plan.json 的依赖图顺序调度：

**顺序执行**：
```
ingest → transcribe → distill → (storyboard + voice 并行) → render → audit → critique → 完成
```

**每个子 Skill 调用方式**：
1. 读取子 Skill 的 SKILL.md，在当前会话中按步骤执行（P0 单 Agent，不启动 subagent）
2. 执行前确保该 Skill 需要的参考文件已加载
3. 执行后检查产出文件是否存在
4. 工具返回 stdout JSON 后，读取并组装 event.json 写入 workspace

**视角注入**：
- distill 执行时，如 plan.json 指定 perspective，distill 会自行调用视角子 Skill 提取 Expression DNA
- storyboard 执行时，同理，会自行调用视角子 Skill 提取 Mental Models
- using-recastory 不直接调用 perspective，只把 perspective 名称写入 plan.json

**并行派发**（P1，P0 顺序执行）：
- P1 使用并行调度器派发两个子任务
- 每个子任务接收：plan.json 路径、对应 SKILL.md 路径、依赖产出文件路径
- Chapter 1 强制主线程（storyboard 的 Chapter 1 必须在主 Agent 完成 + 用户验收后才能继续）

**子 Skill 执行失败处理**：
- 记录失败原因到 plan.json
- 向用户展示失败详情，提供选项："重试"/"跳过"/"修改计划"
- 用户选择"跳过"时，下游依赖该 Skill 的步骤也自动跳过，在完成报告中标记

### 7. 检查点管理

| 检查点 | 触发时机 | 展示内容 | 用户操作选项 |
|--------|---------|---------|-------------|
| **DESIGN** | design.md 生成后 | design.md 全文 | 确认 / 修改 / 重新生成 |
| **STORYBOARD_PREVIEW** | Chapter 1 完成后 | Chapter 1 渲染预览 + 口播前 30 秒 | 确认 / 修改风格 / 换视角 |
| **VOICE_PREVIEW** | voice 完成后 | TTS 音频前 15 秒 + 音色/语速参数 | 确认 / 修改音色 / 调整语速 / 重新合成 |
| **FINAL** | 全部完成后 | 最终视频 + 中间产物清单 + 质量评分 | 下载 / 重新渲染 / 微调 |

**检查点执行规则**：
- 向用户展示检查点内容，等待用户明确回复
- 必须收到用户确认才可继续，不可自动跳过
- 用户选择"修改"时，回退到对应阶段重新生成
- 用户选择"换视角"（STORYBOARD_PREVIEW）时，更新 plan.json 中的 perspective，重新执行 distill + storyboard

### 8. 完成报告

全部 Skill 执行完毕后，向用户报告：

| 报告项 | 内容 |
|--------|------|
| 产出文件清单 | 每个文件的路径 + 大小 |
| 质量评分 | audit/critique 结果（如已运行） |
| 失败项 | 失败步骤 + 原因 + 影响范围 |
| 后续建议 | 如"建议运行 /recastory render 生成最终视频"或"建议调整音色后重新合成" |

**产出文件结构**：

```
workspace/<pipeline_id>/
├── design.md              # 设计文档
├── plan.json              # 执行计划
├── manifest.json          # 最终清单
├── raw/
│   ├── <input>.mp4        # 原始视频（如有）
│   └── article.md         # 转写文本（保留不删）
├── distill/
│   ├── script.md          # 口播稿
│   └── outline.md         # 开发大纲
├── storyboard/
│   └── src/chapters/      # 各章 React 组件
├── voice/
│   └── public/audio/      # TTS 音频 + SRT 字幕
└── render/
    └── final.mp4          # 最终视频
```

## Output

- `workspace/<id>/design.md` — 设计文档
- `workspace/<id>/plan.json` — 执行计划
- 各子 Skill 的产出（见各 SKILL.md 定义）

## Resources

| 资源 | 路径 | 用途 |
| ---- | ---- | ---- |
| 入口协议 | `AGENT.md` | 完整入口协议 + Agent-Tool 边界 |
| 工作流 | `WORKFLOW.md` | Phase 0-7 详细流程 |
| 参考文件索引 | `references/INDEX.md` | Progressive Loading 规则 |
| 品牌注册表 | `brand/REGISTER.md` | register 类型推断 |
| 测试用例 | `skills/using-recastory/test-prompts.json` | 典型 prompt 和期望输出 |

## Anti-Patterns

| ID | 名称 | 检测方式 | 严重度 |
|----|------|---------|--------|
| OR-001 | 无计划执行 | 未生成 plan.json 就调用子 Skill | critical |
| OR-002 | 跳过检查点 | 未等用户确认就进入下一阶段 | critical |
| OR-003 | 并行未隔离 | storyboard + voice 并行但共享文件 | warning |
| OR-004 | 参考文件未加载 | 执行子 Skill 前未按 INDEX.md 加载参考 | warning |
| OR-005 | 依赖图有环 | plan.json 中 skills 存在循环依赖 | critical |
| OR-006 | 缺失必填字段 | plan.json 缺少 pipeline_id/command/skills 等 | critical |

## Failure Modes

| 场景 | 回退策略 | 恢复动作 |
|------|---------|---------|
| 用户输入无法识别 | 展示检测结果和候选选项 | 请用户选择正确的输入类型 |
| 参数冲突（如 format+style 不兼容） | 展示冲突说明 | 请用户选择优先参数 |
| 参考文件不存在 | 跳过该参考文件 | 在 plan.json 的 references_loaded 中标记 missing，继续执行 |
| 参考文件过大（>3000 tokens） | 加载摘要版本 | 使用 REFERENCE-SUMMARY.md（如存在），完整版按需加载 |
| 视角 SKILL.md 不存在 | 跳过视角注入 | 在 plan.json 标记 perspective.missing，继续执行，警告用户 |
| design.md 生成失败 | 重试一次 | 仍失败则向用户报告错误，请用户手动提供设计要点 |
| plan.json 验证失败 | 展示具体错误项 | 请用户确认是否修复后重新生成 |
| workspace 目录不可写 | 检查权限 | 向用户报告权限问题，请用户检查目录权限 |
| 子 Skill 执行失败 | 记录错误到 plan.json | 向用户展示失败详情，提供"重试"/"跳过"/"修改计划"选项 |
| 用户取消检查点 | 回退到对应阶段 | 重新生成被取消阶段的产物 |
| pipeline_id 冲突 | 自动递增序号 | rm-20260528-001 → rm-20260528-002 |
| 所有子 Skill 完成但有部分失败 | 汇总成功/失败项 | 生成部分完成报告，建议用户处理失败项后重新运行 |
