---
name: critique
version: 1.0.0
description: 在 audit 确定性检查通过后，运行 LLM 深度审查（8 维度：规格合规、叙事质量、视角一致性、视觉一致性、音画同步、AI Slop、注册表一致性、双源原则），含自评失真对抗机制。触发条件：/recastory critique 或被 using-recastory 调度。
---

# Skill: critique

## IRON LAW

**审查必须用检查清单逐项核查，禁止"看一眼就过"。自审必须用独立 reviewer agent 或至少 subagent，禁止同一上下文自我评判。**

## Purpose

在 audit（确定性规则）通过后，运行 LLM 深度审查。8 个维度覆盖：规格合规、叙事质量、视角一致性、视觉一致性、音画同步、AI Slop、注册表一致性、双源原则。这是质量保障的最后一道防线。

## Preconditions

- `plan.json` 已存在
- audit 已通过（无 Critical）
- 产出文件已就绪（script.md、outline.md、storyboard/、voice/、render/）
- 如指定 `--perspective`，对应视角 SKILL.md 可用（路径：`skills/perspectives/<name>/SKILL.md`）
- `raw/article.md` 存在（双源原则检查需要）

## Agent-Tool 边界

| 步骤 | 谁做 | 产物 |
|------|------|------|
| Step 1 | Agent（读取） | 上下文加载 |
| Step 2 | Agent / 独立 reviewer（审查） | 8 维度评分 |
| Step 3 | Agent（判定） | 门控决策 |
| Step 4 | Agent（报告） | 审查报告 |

## Steps

### 1. 加载审查上下文

读取 `plan.json` 获取：
- 所有产出文件路径
- perspective（如有）
- register（brand/product）
- target_format、style

读取所有产出文件（相对于 `workspace/<pipeline_id>/`）：

- `distill/script.md` — 口播稿
- `distill/outline.md` — 大纲
- `storyboard/` — 幻灯片项目（Chapter.tsx、narrations.ts）
- `voice/audio-segments.json` — 音频段落映射
- `render/manifest.json` — 渲染元数据
- `raw/article.md` — 原文（用于双源检查）
- 如指定 perspective：`skills/perspectives/<name>/SKILL.md` — 视角定义

### 2. 逐维度审查

**前置**：步骤 1 完成上下文加载，所有产出文件已读取。

对以下 8 个维度，逐项检查并给出 Pass / Warning / Critical：

#### 维度 1: Spec Compliance（规格合规）

| 检查项 | 方法 |
|--------|------|
| plan.json 中的 skills 是否全部完成 | 检查每个 skill 的产出文件是否存在 |
| target_format 是否匹配 | script.md 字数与目标时长对应 |
| register 是否一致 | script.md 风格与 brand/product 匹配 |
| --skip 标志是否正确遵守 | 跳过的 skill 无产出文件 |

#### 维度 2: Narrative Quality（叙事质量）

| 检查项 | 方法 |
|--------|------|
| 内容连贯性 | 章节之间有无逻辑断裂 |
| 信息密度 | 有无冗余段落或信息不足 |
| 叙事弧线 | 开头有 Hook、中间有证据、结尾有收束 |
| Hook 策略 | 前 10 秒是否抓人 |

#### 维度 3: Perspective Consistency（视角一致性）

| 检查项 | 方法 |
|--------|------|
| Expression DNA 注入 | script.md 是否体现视角的句式、词汇、节奏 |
| Narrative Heuristics | 章节排序、重点分配是否符合视角策略 |
| 风格贯穿 | 全文风格是否一致，有无中途变调 |

如未指定 perspective，标记为 N/A。

#### 维度 4: Visual Consistency（视觉一致性）

| 检查项 | 方法 |
|--------|------|
| 主题一致 | 所有 Chapter 是否使用同一主题 |
| 样式统一 | CSS 变量、颜色方案是否一致 |
| 截图质量 | screenshots/ 下的 PNG 是否正常渲染 |

#### 维度 5: Audio Sync（音画同步）

| 检查项 | 方法 |
|--------|------|
| 步骤数对齐 | script.md 步骤数 = outline.md 步骤数 = audio-segments.json 段数 |
| 章节数对齐 | script.md 章节数 = storyboard 章节数 |
| 时长合理性 | 每步音频时长在 5-30 秒范围 |

#### 维度 6: AI Slop Check（AI 痕迹检查）

在 audit 的 SL-001~006 确定性检查基础上，做二阶反射检测：

- **一阶**：从内容类型推断可能的 AI 风格倾向
- **二阶**：检查是否故意规避了常见模式但仍使用了不自然的变体

重点关注：
- 假共情的变体（不是"我知道你"但用了类似的情感操纵）
- 假深刻的变体（不是"本质上"但用了同义的空洞转折）
- 结尾的自然度（是否真的像真人说话的结尾）

#### 维度 7: Register Consistency（注册表一致性）

| 检查项 | 方法 |
|--------|------|
| Brand 模式 | 大胆、戏剧化、情感驱动 |
| Product 模式 | 克制、信息密度、专业感 |
| 贯穿性 | 全文 register 是否一致 |

#### 维度 8: Double-Source Check（双源原则检查）

| 检查项 | 方法 |
|--------|------|
| script.md 定节拍 | 口播顺序 = 视觉推进顺序 |
| article.md 定密度 | 口播跳过的细节是否上屏幕 |
| 职责不混淆 | script.md 中是否有不应出现的细节密度、article.md 中是否有口播节奏 |

### 3. 自评失真对抗

**前置**：步骤 2 完成所有 8 维度审查。

**必须使用以下方式之一，禁止同一上下文自我评判**：

| 方式 | 实现 | 优先级 |
| ---- | ---- | ------ |
| 独立 reviewer agent | 用 Agent 工具派发，给产出文件 + 8 维度检查清单 | 最优 |
| Subagent 质检 | 用 Agent 工具派发简化版审查（仅 Critical 检查项） | 次优 |
| 逐项检查清单 | 当前 agent 严格按清单逐项核查 | 兜底 |

**兜底模式要求**：每项检查必须写出具体的检查依据（引用文件内容），不可只写 "Pass"。格式：

```text
维度 N: <名称>
- 检查项: <具体检查内容>
- 依据: <引用文件:行号 或 文件内容片段>
- 结果: Pass / Warning / Critical
- 说明: <如非 Pass，说明原因>
```

### 4. 门控决策

**前置**：步骤 2 审查完成 + 步骤 3 自评失真对抗完成。

| 结果 | 处理 |
| ---- | ---- |
| 0 Critical + Warning ≤ 3 | 通过，进入 deliver |
| 0 Critical + Warning > 3 | 通过，但列出 warning 建议优化 |
| 有 Critical | 阻断，列出 Critical 项 + 修复建议 |

### 5. 反模式检查

| 规则 | 检测 | 修复 |
|------|------|------|
| CR-001 | 跳过 critique 直接 deliver | 阻断，必须先审查 |
| CR-002 | 无检查清单通过 | 要求逐项列出检查依据 |
| CR-003 | 自审无独立检查 | 至少用 subagent 做质检 |

### 6. 生成审查报告

输出格式：

```markdown
# Critique Report: <pipeline_id>

## 总评
- 状态：Pass / Warning / Critical
- Critical 数：N
- Warning 数：N

## 维度评分
| 维度 | 结果 | 说明 |
|------|------|------|
| Spec Compliance | Pass | ... |
| Narrative Quality | Warning | ... |
| ... | ... | ... |

## Critical 问题
1. [文件:行号] 问题描述 + 修复建议

## Warning 问题
1. [文件:行号] 问题描述 + 优化建议

## 审查方式
- [x] 独立 reviewer agent / subagent / 逐项清单
```

## Output

- 审查报告（markdown 格式）
- 门控决策（Pass/Warning/Critical）

## Anti-Patterns

步骤 5 中检测的流程规则（详见 Failure Modes 获取恢复策略）：

| ID | 名称 | 检测方式 | 严重度 |
| -- | ---- | -------- | ------ |
| CR-001 | 跳过审查 | 未运行 critique 就进入 deliver | critical |
| CR-002 | 无清单通过 | 未逐项检查就给出 Pass | critical |
| CR-003 | 自审无独立检查 | 同一 agent 自己审自己 | warning |

## Failure Modes

前置依赖和运行时错误的恢复策略：

| 场景 | 检测方式 | 恢复策略 |
| ---- | -------- | -------- |
| 产出文件缺失 | 文件不存在或为空 | 对应维度标记 N/A，继续审查其他维度 |
| 视角 SKILL.md 未找到 | `skills/perspectives/<name>/SKILL.md` 不存在 | 跳过维度 3（Perspective Consistency），标记 N/A，记录 warning |
| reviewer agent 超时 | Agent 工具返回超时错误 | 降级到逐项检查清单模式（兜底） |
| 所有维度 N/A | 8 个维度全部标记 N/A | 阻断，无产出可审查，提示用户检查流水线状态 |
| article.md 缺失 | 文件不存在 | 维度 8（双源检查）标记 N/A，其余维度继续 |
| 审查报告格式不符合模板 | 输出缺少必要章节 | 按模板重新格式化后输出 |
| plan.json 缺失 | 文件不存在 | 阻断，提示先运行 using-recastory 生成计划 |
