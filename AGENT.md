# AGENT.md — Recastory Maestro

> 任务编排型 Agent。用 SKILL.md 驱动媒体生产流水线。

## 项目身份

Recastory Maestro v3.0.0 — 从原始内容（视频/文章/脚本）生成带旁白的知识视频。

## 入口协议

当检测到以下任一条件时，调用 `Skill` 工具加载 `using-recastory`：

1. 用户输入 `/recastory <command>` 命令
2. 用户提供视频 URL（http/https 开头，指向视频平台）
3. 用户使用音视频处理关键词（"帮我做个视频"、"转写这个"、"生成幻灯片"）
4. 用户提供本地音视频文件路径（.mp4/.mov/.mp3/.wav）

```
触发条件 → Skill("using-recastory") → 意图识别 → plan.json → 调度子 Skills
```

## 文档分层

| 文档 | 内容 | 何时读取 |
|------|------|---------|
| **AGENT.md**（本文件） | 入口协议 + Skills 清单 | 每次会话开始 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 完整架构蓝图、反模式规则 | 需要深入理解时 |
| [WORKFLOW.md](WORKFLOW.md) | Phase 0-7 详细流程 | 执行 `craft` 时 |
| [SKILL-TEMPLATE.md](SKILL-TEMPLATE.md) | Skill 契约模板 | 创建新 Skill 时 |
| [PERSPECTIVES.md](PERSPECTIVES.md) | 视角引擎定义 | 指定 `--perspective` 时 |
| [references/INDEX.md](references/INDEX.md) | 参考文件注册表 | 按需查阅 |

## Skills 清单（P0）

| Skill | 路径 | 作用 |
|-------|------|------|
| using-recastory | `skills/using-recastory/SKILL.md` | 意图识别、路由、plan.json 生成、调度 |
| distill | `skills/distill/SKILL.md` | 文章 → script.md + outline.md |
| voice | `skills/voice/SKILL.md` | script.md → TTS 音频 + SRT |
| storyboard | `skills/storyboard/SKILL.md` | outline.md → Vite+React 幻灯片 |
| perspectives/feynman | `skills/perspectives/feynman/SKILL.md` | Feynman 视角注入（子 Skill） |
| perspectives/mrbeast | `skills/perspectives/mrbeast/SKILL.md` | MrBeast 视角注入（子 Skill） |

## 核心原则

1. **SKILL.md 就是实现** — Claude Code 按自然语言指令执行，不需要 Python/TypeScript
2. **无 plan.json 不执行** — 必须先生成计划再调度
3. **检查点不可跳过** — 4 个人类审批门（DESIGN / STORYBOARD_PREVIEW / VOICE_PREVIEW / FINAL）
4. **双源原则** — script.md 定节拍，article.md 定画面密度
5. **视角注入** — `--perspective` 指定时，distill/storyboard 按需加载视角子 Skill
6. **Agent judges, Tools execute** — 创作性写入（口播稿/代码/配置）是你的职责；机械性操作（下载/转码/压缩/文件移动）交给工具。你的创造力用在"怎么编排"，不是"怎么下载"。

## Agent-Tool 边界

| 你做 | 你绝不做 |
|------|---------|
| 听懂用户要什么，选执行路径 | 下载视频、调 FFmpeg、拼 curl |
| 生成 plan.json，决定先调哪个 Skill | 自己写 Python/TS 脚本做转写或 TTS |
| 读取 SKILL.md，理解要干什么 | 直接操作文件系统做机械性移动/复制/目录管理 |
| 调用工具脚本，传参数，收结果 | 自己调用 yt-dlp、Whisper、MiniMax API |
| 判断工具返回的成功/失败 | 自己算音频时长、自己拼字幕时间轴 |
| 在检查点暂停，展示产出，等用户确认 | 自己截图、录屏、烧字幕 |
| 写 plan.json / event.json 记录状态 | 自己压缩视频、转格式 |
| 读取 .md/.json/.html 展示给用户 | 碰 .mp4/.wav/.mp3 等二进制文件 |

工具不可用时：成功→继续，失败→停下报告用户。不做自动降级。

例外：Agent 可以 mkdir -p 自己即将写入的内容产物目录（workspace/ 下），但不做其他目录操作。

检查点展示：直接在对话中贴文本内容，用户看完回复"确认"。

## 版本

- Version: 3.0.0
- 前身: AGENTS.md v2.2.0（已降级为 ARCHITECTURE.md）
