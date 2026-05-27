---
name: using-recastory
description: Recastory Maestro 主入口 — 意图识别、路由、plan.json 生成、子 Skill 调度、检查点管理
---

# Skill: using-recastory

## IRON LAW

**无 plan.json 不执行任何 Skill。不跳过任何检查点。**

违反任一条 = 立即停止，向用户报告违规原因。

## Purpose

接收用户输入（命令 / URL / 文件 / 自然语言），生成执行计划（plan.json），调度子 Skill 完成媒体生产流水线。

## Preconditions

- AGENT.md 已加载（Claude Code 会话开始时自动加载）
- 用户提供了有效输入（命令、文件路径、URL 或自然语言需求）

## Steps

### 1. 意图识别

检测用户输入类型，确定执行路径：

| 输入类型 | 检测方式 | 默认命令 | skip 标志 |
|---------|---------|---------|----------|
| `/recastory <cmd>` | 显式命令 | 按命令路由 | 用户指定 |
| 视频 URL | http/https 开头，指向视频平台 | `craft` | — |
| 本地视频 | 扩展名 .mp4/.mov/.avi/.mkv | `craft` | — |
| 文章/脚本 | .md/.txt，无视频特征 | `craft` | `--skip-ingest --skip-transcribe` |
| 仅音频 | .mp3/.wav/.m4a | `craft` | `--skip-ingest` |
| 自然语言 | "帮我做个视频" 等语义匹配 | `craft` | 按输入类型推断 |

如无法确定输入类型，用 `AskUserQuestion` 询问用户。

### 2. 解析参数

从用户输入中提取：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--format` | `short-video` | short-video / course / podcast / keynote |
| `--style` | `explainer` | tech / science / explainer / business / casual |
| `--register` | 从 brand/REGISTER.md 推断，否则询问 | brand（大胆/戏剧化）/ product（克制/信息密度） |
| `--perspective` | 无 | feynman / mrbeast（P0 仅支持 feynman） |
| `--parallel` | `A` | A（逐章确认）/ B（顺序）/ C（并行） |
| `--voice` | 默认 TTS 音色 | TTS 音色 ID |

未提供的必要参数用 `AskUserQuestion` 询问。

### 3. 加载参考文件

按 `references/INDEX.md` 的 Progressive Loading 规则：

1. 全局加载：`transcription/REFERENCE.md` + `content-distillation/REFERENCE.md`（如存在）
2. 命令对应领域参考（如 `storyboard/REFERENCE.md`、`voice/REFERENCE.md`）
3. 视角 Expression DNA（如指定 `--perspective`）
4. 品牌注册表 `brand/REGISTER.md`（最后加载）

### 4. 生成 design.md

按 WORKFLOW.md Phase 1 模板生成 `workspace/<id>/design.md`，必须包含：
- 输入（类型 + 来源）
- 输出（格式 + 风格 + 注册表）
- 视角（名称 + Expression DNA 摘要 + 注入点）
- 流水线（跳过列表 + 并行模式）
- 双源策略（script.md 定节拍，article.md 定画面密度）
- 检查点定义（DESIGN / STORYBOARD_PREVIEW / VOICE_PREVIEW / FINAL）
- 启用的反模式规则列表

**[Checkpoint: DESIGN]** — 用 `AskUserQuestion` 展示 design.md，等待用户确认。用户确认后才可继续。

### 5. 生成 plan.json

将 design.md 转化为 `workspace/<id>/plan.json`，格式如下：

```json
{
  "pipeline_id": "rm-<date>-<seq>",
  "command": "/recastory craft ...",
  "input_type": "<article|local-video|url|audio>",
  "target_format": "<short-video|course|podcast|keynote>",
  "register": "<brand|product>",
  "perspective": {
    "name": "<perspective-name>",
    "expression_dna": "<summary>"
  },
  "execution_mode": "<A|B|C>",
  "double_source": {
    "script": "workspace/<id>/distill/script.md",
    "article": "workspace/<id>/raw/article.md",
    "outline": "workspace/<id>/distill/outline.md"
  },
  "references_loaded": ["<list of loaded reference files>"],
  "anti_patterns_enabled": ["<list of rule IDs>"],
  "skills": [
    { "name": "distill", "depends_on": [] },
    { "name": "storyboard", "depends_on": ["distill"] },
    { "name": "voice", "depends_on": ["distill"] }
  ],
  "parallel_groups": [
    { "skills": ["storyboard", "voice"], "after": "distill" }
  ]
}
```

如用户指定了 `--skip-ingest` 或 `--skip-transcribe`，plan.json 的 skills 数组中不包含对应 Skill。

### 6. 调度子 Skill

按 plan.json 的依赖图顺序调度：

**顺序执行**：
```
distill → (storyboard + voice 并行) → 完成
```

**每个子 Skill 调用方式**：
1. 读取子 Skill 的 SKILL.md，在当前会话中按步骤执行（P0 单 Agent，不启动 subagent）
2. 执行前确保该 Skill 需要的参考文件已加载
3. 执行后检查产出文件是否存在
4. 工具返回 stdout JSON 后，Agent 读取并组装 event.json 写入 workspace

**视角注入**：
- distill 执行时，如 plan.json 指定 perspective，distill 会自行调用 `Skill("perspectives/<name>")` 提取 Expression DNA
- storyboard 执行时，同理，会自行调用 `Skill("perspectives/<name>")` 提取 Mental Models
- using-recastory 不直接调用 perspective，只把 perspective 名称写入 plan.json

**并行派发**（P1，P0 顺序执行）：
- P1 使用 `Agent` 工具并行派发两个子 Agent
- 每个 Agent 接收：plan.json 路径、对应 SKILL.md 路径、依赖产出文件路径
- Chapter 1 强制主线程（storyboard 的 Chapter 1 必须在主 Agent 完成 + 用户验收后才能继续）

### 7. 检查点管理

| 检查点 | 触发时机 | 展示内容 | 用户操作 |
|--------|---------|---------|---------|
| **DESIGN** | design.md 生成后 | design.md 全文 | 确认 / 修改 |
| **STORYBOARD_PREVIEW** | Chapter 1 完成后 | Chapter 1 渲染预览 + 口播前 30 秒 | 确认 / 修改风格 / 换视角 |
| **VOICE_PREVIEW** | voice 完成后 | TTS 音频前 15 秒 | 确认 / 修改音色 / 语速 |
| **FINAL** | 全部完成后 | 最终视频 + 中间产物清单 | 下载 / 重新渲染 |

每个检查点用 `AskUserQuestion` 实现。**必须收到用户明确确认才可继续，不可自动跳过。**

### 8. 完成报告

全部 Skill 执行完毕后，向用户报告：
- 产出文件清单（路径 + 大小）
- 质量评分（如运行了 audit/critique）
- 失败项（如有步骤失败，列出原因）
- 后续建议（如"建议运行 /recastory render 生成最终视频"）

## Output

- `workspace/<id>/design.md` — 设计文档
- `workspace/<id>/plan.json` — 执行计划
- 各子 Skill 的产出（见各 SKILL.md 定义）

## Anti-Patterns

| ID | 名称 | 检测方式 | 严重度 |
|----|------|---------|--------|
| OR-001 | 无计划执行 | 未生成 plan.json 就调用子 Skill | critical |
| OR-002 | 跳过检查点 | 未等用户确认就进入下一阶段 | critical |
| OR-003 | 并行未隔离 | storyboard + voice 并行但共享文件 | warning |
| OR-004 | 参考文件未加载 | 执行子 Skill 前未按 INDEX.md 加载参考 | warning |

## Failure Modes

| 场景 | 回退策略 |
|------|---------|
| 用户输入无法识别 | 用 AskUserQuestion 询问，提供选项 |
| 参考文件不存在 | 跳过该参考文件，在 plan.json 的 references_loaded 中标记 missing |
| 子 Skill 执行失败 | 记录错误，询问用户是否重试 / 跳过 / 修改计划 |
| 用户取消检查点 | 回退到对应阶段重新生成 |
