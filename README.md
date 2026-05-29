# Recastory Maestro

> 内容重铸引擎：将原始内容通过可组合的 Skill 流水线，重铸为结构化视频输出。

## 这是什么

Recastory Maestro 是一个**任务编排型 AI Agent**，负责将视频、文章、脚本等原始内容，通过标准化的 Skill 流水线，生产出带 TTS 口播的结构化视频。

它**不直接处理内容**，只负责：解析命令 → 加载参考文件 → 生成计划 → 调度 Skills → 审查质量 → 管理检查点。

## 核心特性

- **双源原则** — `script.md` 定节拍，`article.md` 定画面密度，信息密度翻倍
- **视角引擎** — 提取 Feynman / MrBeast 等人的认知操作系统注入内容，对抗"AI 味"
- **注册表系统** — Brand（品牌宣传）和 Product（教程课程）两套设计规则，自动适配
- **确定性审查** — CLI 可运行的硬性规则检测反模式，不依赖 LLM 判断
- **人类检查点** — 关键节点强制暂停等待确认，不自动放行

## 快速开始

```bash
# 从本地视频生成 Feynman 风格的知识视频
/recastory craft video.mp4 --perspective feynman --register product

# 从文章生成 MrBeast 风格的短视频
/recastory distill article.md --perspective mrbeast --register brand

# 仅运行质量审查
/recastory audit workspace/<pipeline-id>/
```

## 命令体系

| 命令 | 作用 |
|------|------|
| `craft` | 完整流水线：从输入到最终视频 |
| `ingest` / `transcribe` / `distill` / `storyboard` / `voice` / `render` | 单步执行 |
| `audit` | 确定性质量检查 |
| `critique` | LLM 深度审查 |
| `research` | 深度研究，生成报告作为素材 |

参数：`--perspective` `--register` `--parallel` `--format` `--style` `--voice`

## 工作流

```
输入 → Phase 0 Intake → Phase 1 Design → [Checkpoint]
     → Phase 2 Plan → Phase 3 Dispatch → Phase 4 Audit → Phase 5 Review
     → [Checkpoint] → Phase 6 Deliver
```

每个阶段的详细规范见 [WORKFLOW.md](WORKFLOW.md)。

## 文档结构

| 文档 | 内容 | 何时读取 |
|------|------|---------|
| [AGENT.md](AGENT.md) | 主入口：核心哲学、命令、禁止行为 | 每次会话开始 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 完整架构蓝图、设计决策 | 深入理解时 |
| [WORKFLOW.md](WORKFLOW.md) | Phase 0-7 详细流程 | 执行 `craft` 时 |
| [SKILL-TEMPLATE.md](SKILL-TEMPLATE.md) | Skill 契约、测试规范、评分体系 | 创建新 Skill 时 |
| [PERSPECTIVES.md](PERSPECTIVES.md) | 视角引擎：8 个视角定义 | 使用 `--perspective` 时 |
| [references/INDEX.md](references/INDEX.md) | 参考文件加载规则 | 按需查阅 |
| [examples/hello-world/](examples/hello-world/) | 30 秒视频的完整示例 | 首次使用时 |

## 视角引擎

通过提取特定人物的**认知操作系统**注入创造力，非角色扮演。

| 视角 | 适用场景 | 状态 |
|------|---------|------|
| **Feynman** | 科普、原理解释 — 口语化、从具体到抽象 | MVP |
| **MrBeast** | 短视频、娱乐 — 零无聊、阶梯升级 | MVP |
| Musk / Munger / Naval / Jobs / Graham / Karpathy | 各类内容 | contributions welcome |

## 技术栈

- **AI Agent**: Any compatible agent harness (SKILL.md protocol)
- **转写**: Whisper
- **TTS**: MMX CLI / MiniMax Token Plan
- **渲染**: CDP Screencast 录屏 + FFmpeg 编码
- **Skill 框架**: Zod Schema 契约 + TypeScript

## 项目状态

v3.0.0。文档体系、架构设计、TTS 多 Provider 降级链、render 平台编码优化已完成。`craft` 流水线可用。

## License

MIT
