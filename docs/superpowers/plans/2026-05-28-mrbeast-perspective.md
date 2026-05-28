# MrBeast Perspective Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## 质量门禁（每 Task 强制执行）

参考 ElectronHound development-process.md，每个 Task 完成后执行 **3 轮 Code Review**，无需人工介入：

```text
Task 执行 → Code Review #1 → 修复全部问题 → Code Review #2 → 修复回归问题 → Code Review #3 → 最终验证 → Commit
```

### Review 流程

1. **Code Review #1（Spec Compliance）** — 检查代码是否完整实现计划规格
2. **修复** — 修复 #1 发现的所有 `[Required]` 问题
3. **Code Review #2（Regression Check）** — 检查修复过程中是否引入回归
4. **修复** — 修复 #2 发现的回归问题
5. **Code Review #3（Final Quality）** — 最终质量验证
6. **Commit** — 三次 Review 全部通过后提交

**Goal:** 将 nuwa-skill 的 MrBeast 视角改编为 Recastory 的内容生产式视角，与 Feynman 视角结构对齐。

**Architecture:** 参考 `skills/perspectives/feynman/SKILL.md` 的三段式结构（Expression DNA + Mental Models + Decision Heuristics），从 nuwa-skill 的 MrBeast 视角提取核心内容，重新组织为内容生产注入格式。

**Tech Stack:** Markdown (SKILL.md)

**参考：**
- `skills/perspectives/feynman/SKILL.md` — 结构模板
- `skills/nuwa-skill/examples/mrbeast-perspective/SKILL.md` — 源内容

---

## 文件清单

| 操作 | 文件 | 职责 |
|------|------|------|
| Create | `skills/perspectives/mrbeast/SKILL.md` | MrBeast 视角定义（Expression DNA + Mental Models + Decision Heuristics） |

---

### Task 1: 创建 MrBeast 视角 SKILL.md

**Files:**
- Create: `skills/perspectives/mrbeast/SKILL.md`

- [ ] **Step 1: 创建目录**

```bash
mkdir -p skills/perspectives/mrbeast
```

- [ ] **Step 2: 编写 SKILL.md**

参照 Feynman SKILL.md 的结构，从 nuwa-skill 的 MrBeast 视角提取核心内容，创建 `skills/perspectives/mrbeast/SKILL.md`。

文件必须包含以下结构：

```markdown
---
name: perspectives/mrbeast
description: MrBeast 视角注入 — Expression DNA（口播风格）+ Mental Models（视觉设计）+ Decision Heuristics（审查）
---

# Skill: perspectives/mrbeast

## 适配说明

本 Skill 从 nuwa-skill 的问答式视角改编为 Recastory 的内容生产式视角。

| 维度 | nuwa-skill 原版（问答式） | Recastory 版（内容生产式） |
|------|---|---|
| 输入 | 用户问题 | transcript / article.md |
| 输出 | MrBeast 视角分析 | MrBeast 风格 script.md + 视觉建议 |
| 触发方式 | 用户问"MrBeast会怎么做" | `--perspective mrbeast` 参数 |
| 注入时机 | 随时 | distill（Expression DNA）+ storyboard（Mental Models）|

## Purpose

被 distill 和 storyboard 按需调用，注入 MrBeast 的内容创造操作系统：
- **distill 阶段** → 提取 Expression DNA，改写口播稿风格
- **storyboard 阶段** → 提取 Mental Models，指导视觉设计

## 调用方式

本 Skill 是**子 Skill**，不被 using-recastory 独立调度。

## Expression DNA（注入 distill 阶段）
```

Expression DNA 部分必须包含：

**句式规则：**
- 极度具体：不说"标题要吸引人"，说"把数字放前面，去掉多余的字"
- 零铺垫：直接给结论，不解释为什么（观众不关心为什么）
- 制造悬念：每句结尾暗示"后面有更大的"

**词汇偏好：**
- 禁用模糊词："可能""也许""一些""很多"
- 替换为具体数字和极端词："100%""绝对""致命""灾难级"

**节奏模式：**
- 前 3 秒必须是一个画面或一句话让人产生疑问
- 每 3-5 分钟一个 re-engagement moment
- 结尾用 CTA 或悬念（"下一个视频更疯狂"）

**幽默策略：**
- 不用幽默，用极端和悬念
- 用数字制造冲击

Mental Models 部分必须包含 5 个模型（从 nuwa-skill 的 6 个中选取最适用于内容生产的）：

1. CTR × AVD 方程式 — 视觉含义：缩略图+标题决定点击，内容决定留存
2. 零无聊时刻 — 视觉含义：每帧必须有信息增量
3. 阶梯递进 — 视觉含义：刺激强度曲线必须持续上升
4. 简单概念×极端执行 — 视觉含义：一句话说清概念，画面展示极端执行
5. 前 30 秒法则 — 视觉含义：Hook 结构（0-3秒概念即画面，3-8秒赌注声明，8-15秒视觉预告，15-30秒立即行动）

Decision Heuristics 部分包含 8 条决策启发式（从 nuwa-skill 提取）。

最后添加注入点表和诚实边界。

- [ ] **Step 3: 验证文件**

确认文件存在且结构完整：
- YAML frontmatter 有 name, description
- 包含适配说明、Purpose、调用方式
- 包含 Expression DNA（句式、词汇、节奏、幽默）
- 包含 Mental Models（5 个，每个有视觉含义和 storyboard 应用）
- 包含 Decision Heuristics（8 条）
- 包含注入点表
- 包含诚实边界

- [ ] **Step 4: Commit**

```bash
git add skills/perspectives/mrbeast/SKILL.md
git commit -m "feat(perspectives): add MrBeast perspective skill"
```

---

## 验证清单

| 验证项 | 方法 |
|--------|------|
| 文件存在 | `ls skills/perspectives/mrbeast/SKILL.md` |
| 结构完整 | 包含 Expression DNA + Mental Models + Decision Heuristics |
| 与 Feynman 对齐 | 三段式结构一致 |
| 注入点表 | distill + storyboard 两个注入点 |
| 诚实边界 | 包含局限性说明 |
