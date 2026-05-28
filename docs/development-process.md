# Recastory 开发流程规范

## 概述

Recastory Maestro 是任务编排型 Agent，用 SKILL.md 驱动媒体生产流水线。本文档定义项目自身的开发流程——如何修改 Skill、架构文档、工具链，以及如何保证变更质量。

## 项目结构速查

```
Recastory/
├── AGENT.md              # 入口协议 + Skills 清单
├── ARCHITECTURE.md       # 架构蓝图 + 反模式规则
├── WORKFLOW.md           # Phase 0-7 详细流程
├── CLAUDE.md             # 触发条件 + 核心原则
├── skills/               # Skill 定义（SKILL.md = 实现）
│   ├── using-recastory/  # Maestro 主入口
│   ├── distill/          # 文章 → script.md + outline.md
│   ├── voice/            # script.md → TTS 音频 + SRT
│   ├── storyboard/       # outline.md → 幻灯片
│   ├── perspectives/     # 视角引擎（feynman, mrbeast, ...）
│   └── humanizer-zh/     # 去 AI 味
├── tools/                # 确定性工具（Python/Shell/JS）
│   ├── audit/            # 反模式检测 CLI
│   ├── ingest/           # 视频下载 + 音频提取
│   ├── merge-srt.sh      # SRT 合并
│   └── render-video.sh   # 视频渲染
├── references/           # 领域参考文件（Progressive Loading）
├── workspace/            # 运行产物（plan.json + 输出）
└── examples/             # 测试素材
```

## 开发产物约定

| 产物 | 格式 | 说明 |
|------|------|------|
| SKILL.md | Markdown + frontmatter | Skill 定义，包含 Steps / Output / Anti-Patterns / Failure Modes |
| test-prompts.json | JSON 数组 | 每个 Skill 的验收测试用例（id / prompt / expected） |
| plan.json | JSON | 运行时执行计划，由 using-recastory 生成 |
| REFERENCE.md | Markdown | 领域参考文件，≤3000 tokens，按 INDEX.md 注册 |
| mmx-config.json | JSON | 工具配置模板（voice Skill 专用） |

---

## 并行执行模型

Recastory 的修改可按**文件隔离性**分组并行执行。

### 分组原则

1. **同文件修改必须串行** — 同一文件的多次修改按顺序执行，避免冲突
2. **不同文件可并行** — 无文件交集的修改组可派发给独立 sub agent
3. **依赖关系决定先后** — 有依赖的修改等前置完成

### 分组模板

```markdown
## 执行组：<描述>

| 任务 | 文件 | 修改内容 |
|------|------|---------|
| X1   | `path/to/file` | 具体修改 |
| X2   | `path/to/other` | 具体修改 |

**并行可行性**: X1/X2 改不同文件，可并行 / 串行约束：同文件
```

### 冲突检测

派发 sub agent 前：
1. 列出每个组涉及的文件路径
2. 检查是否有文件交集
3. 有交集的组自动降级为串行

---

## 自主执行模型

计划启动后，Agent **独立完成全部流程**，无需人工中途确认：

```
派发 sub agents → 收集结果 → CR1 → 修复 → CR2 → 修复回归 → CR3 → 最终验证 → Commit → 完成
```

### 详细步骤

1. **任务执行**
   - 按并行组派发 sub agent（或单 Agent 顺序执行）
   - 监控进度和质量
   - 收集执行结果

2. **第一次 Code Review（发现问题）**
   - 执行 `/code-review` 技能
   - 检查变更的正确性、一致性、回归风险
   - 输出所有 [Required] / [Optional] / [Question] / [FYI] 问题

3. **问题修复**
   - 修复所有 [Required] 问题
   - 验证修复效果（确认文件内容正确）

4. **第二次 Code Review（确认修复 + 检测回归）**
   - 再次执行 `/code-review`
   - 确认第一次的问题已修复
   - 检查修复过程中是否引入新问题（回归）
   - 验证无回归

5. **回归问题修复**
   - 修复第二次 CR 发现的回归问题
   - 验证修复效果

6. **第三次 Code Review（最终验证）**
   - 最终执行 `/code-review`
   - 确认所有问题已解决
   - 验证无回归问题
   - 最终质量验证

7. **最终验证**
   - 文档交叉引用一致（Skills 表 ↔ 文件路径 ↔ INDEX.md）
   - 反模式规则 ID 跨文件对齐
   - test-prompts.json 与 SKILL.md Steps 匹配

8. **提交 Commit**
   - 语义化提交信息（见下方规范）
   - 自动提交，无需用户确认
   - 完成后向用户报告执行摘要

## 质量门禁

全部自动验证，无需人工审批：

- [ ] 所有并行组执行完成
- [ ] 第一次 Code Review 通过
- [ ] 所有问题修复完成
- [ ] 第二次 Code Review 通过（无回归问题）
- [ ] 所有回归问题修复完成
- [ ] 第三次 Code Review 通过（最终验证）
- [ ] 文档交叉引用一致

## Code Review

使用项目内置的 `/code-review` 技能。默认 `--depth standard --focus general`。

| 条件 | 升级到 deep |
|------|------------|
| 变更 >500 行 | 是 |
| 涉及 SKILL.md Steps 区域修改 | 是 |
| 仅改文档注册 / 示例 | 否 |

问题标签：`[Required]` 阻断合并 / `[Optional]` 建议改进 / `[Question]` 需澄清 / `[FYI]` 信息同步。

详见 [code-review skill](../.claude/skills/code-review/SKILL.md) 完整规范。

---

## Sub Agent 派发协议

### 派发方式

```python
Agent({
  subagent_type: "general-purpose",
  description: "Group X: 简短描述",
  prompt: "完整任务上下文 + 目标文件 + 修改内容 + 验证条件",
  run_in_background: true
})
```

### 派发约束

- 每个 sub agent 接收**完整任务上下文**（目标文件路径、修改内容、预期产出）
- sub agent **不修改**其他组的文件
- sub agent 完成后返回**修改摘要**
- 主 agent 收集所有结果后统一做 Code Review

---

## 提交规范

### 格式

```
<type>(<scope>): <subject>
```

### type

| 类型 | 用途 |
|------|------|
| feat | 新功能 / 新 Skill |
| fix | 修复 bug |
| docs | 文档更新 |
| refactor | 重构 |
| test | 测试相关 |
| chore | 构建 / 工具链更新 |

### scope（Recastory 专用）

| 范围 | 覆盖 |
|------|------|
| skills | skills/ 下的 SKILL.md 文件 |
| docs | AGENT.md / ARCHITECTURE.md / WORKFLOW.md / CLAUDE.md |
| tools | tools/ 下的工具脚本 |
| references | references/ 下的 REFERENCE.md |
| config | mmx-config.json 等配置 |
| perspectives | skills/perspectives/ 下的视角 Skill |
| audit | tools/audit/ 下的反模式检测 |

### 示例

```
docs(skills): 注册 MrBeast 视角，修正架构文档 CLI 示例

- CLAUDE.md/AGENT.md Skills 表新增 perspectives/mrbeast
- references/INDEX.md 补充原生视角路径
- ARCHITECTURE.md CLI 示例从 npx 改为 python -m tools.audit
```

---

## 最佳实践

1. **文件隔离优先** — 并行组之间零文件交集
2. **小步提交** — 每个逻辑变更独立提交
3. **SKILL.md 即实现** — 修改 Skill 逻辑只改 SKILL.md，不写代码
4. **反模式规则对齐** — 规则 ID（CD-001, SL-001 等）必须在 SKILL.md / ARCHITECTURE.md / rules.py 三处一致
5. **文档同步** — Skills 表（CLAUDE.md / AGENT.md）与文件路径必须一致
6. **自主完成** — 计划启动后独立执行到结束，完成后报告摘要

---

## 常见问题

### Q: 为什么用并行执行？

A: 无文件交集的修改并行执行可显著提速。3 个 sub agent 并行处理 3 个组，比串行快约 3 倍。

### Q: sub agent 冲突怎么办？

A: 派发前做文件交集检测。有交集的组自动降级为串行。

### Q: Code Review 失败怎么办？

A: 修复所有 [Required] 问题，再次 Code Review。如果第二次 CR 发现回归问题，继续修复。三次 CR 全部通过才能提交。

### Q: 如何确定审查深度？

A: 默认 standard。改 SKILL.md Steps 区域或变更 >500 行时用 deep。

### Q: commit 需要用户确认吗？

A: 不需要。计划启动后 Agent 自主完成全部流程（CR1→修复→CR2→修复回归→CR3→Commit），完成后向用户报告执行摘要。

### Q: SKILL.md 改了但没改 test-prompts.json？

A: 这是常见遗漏。SKILL.md Steps 变更时，同步检查 test-prompts.json 的 expected 字段是否仍然匹配。
