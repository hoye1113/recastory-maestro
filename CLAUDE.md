# Recastory Maestro

> 任务编排型 Agent。用 SKILL.md 驱动媒体生产流水线。

## 触发条件

当用户输入以下任一条件时，调用 `Skill` 工具加载 `using-recastory`：

1. `/recastory <command>` — 显式命令
2. 视频 URL（http/https，指向视频平台）
3. 音视频处理关键词（"帮我做个视频"、"转写这个"、"生成幻灯片"）
4. 本地音视频文件路径（.mp4/.mov/.mp3/.wav）

**入口流程**：
```
触发条件 → Skill("using-recastory") → 意图识别 → plan.json → 调度子 Skills
```

## Skills 目录

| Skill | 路径 | 触发方式 |
|-------|------|---------|
| using-recastory | `skills/using-recastory/SKILL.md` | `/recastory` 命令 |
| distill | `skills/distill/SKILL.md` | 被 using-recastory 调度 |
| voice | `skills/voice/SKILL.md` | 被 using-recastory 调度 |
| storyboard | `skills/storyboard/SKILL.md` | 被 using-recastory 调度 |
| perspectives/feynman | `skills/perspectives/feynman/SKILL.md` | 被 distill/storyboard 按需调用 |
| perspectives/mrbeast | `skills/perspectives/mrbeast/SKILL.md` | 被 distill/storyboard 按需调用 |
| humanizer-zh | `skills/humanizer-zh/SKILL.md` | SL-001~006 违规时被 distill 按需加载 |
| nuwa-skill | `skills/nuwa-skill/SKILL.md` | 视角工厂，15 个 nuwa-skill 视角按需加载 |
| web-video-presentation | `skills/web-video-presentation/SKILL.md` | 分镜方法论参考，被 storyboard 按需加载 |

## 核心原则

1. **SKILL.md 就是实现** — AI Agent 按自然语言指令执行
2. **无 plan.json 不执行** — 必须先生成计划再调度
3. **检查点不可跳过** — 4 个人类审批门（DESIGN / STORYBOARD_PREVIEW / VOICE_PREVIEW / FINAL）
4. **双源原则** — script.md 定节拍，article.md 定画面密度
5. **Agent judges, Tools execute** — 创作性写入是 Agent 职责，机械性操作交给工具

## 参考文档

- [AGENT.md](AGENT.md) — 完整入口协议 + Agent-Tool 边界
- [ARCHITECTURE.md](ARCHITECTURE.md) — 架构蓝图、反模式规则
- [WORKFLOW.md](WORKFLOW.md) — Phase 0-7 详细流程
- [references/INDEX.md](references/INDEX.md) — 参考文件注册表
