---
name: audit
version: 1.0.0
description: 运行确定性反模式规则检查（37 条规则），解读结果并指导修复。用于产出文件的质量门控，在 critique（LLM 深度审查）之前运行。触发词：/recastory audit、"检查质量"、"跑审计"。
---

# Skill: audit

## IRON LAW

**Critical 违规必须阻断流水线，无例外。Warning 记录后可继续。修复后必须重跑审计验证，不可凭感觉确认。**

## Purpose

对 workspace 中的产出文件运行确定性规则检查，快速发现转写、内容提炼、配音、AI Slop、视觉方面的问题。工具做检测，Agent 做解读和修复指导。

## Preconditions

- `plan.json` 已存在
- workspace 目录中有待检查的产出文件（.md、.srt、audio-segments.json、screenshots）
- Python 环境可用
- `tools/audit/` 模块可导入

## Agent-Tool 边界

| 步骤 | 谁做 | 产物 |
| ---- | ---- | ---- |
| Step 1 | Agent 调用 CLI（工具执行） | 审计报告 |
| Step 2 | Agent（解读） | 问题分类 |
| Step 3 | Agent（创作性修复） | 修复后的文件 |
| Step 4 | Agent 调用 CLI（工具执行） | 验证报告 |
| Step 5 | Agent（报告） | 汇总结果 |

## Steps

### 1. 运行审计工具

```bash
# 全量扫描
python -m tools.audit workspace/<pipeline_id>/

# 指定规则
python -m tools.audit workspace/<pipeline_id>/ --rule TR-001,SL-001

# JSON 输出（CI 用）
python -m tools.audit workspace/<pipeline_id>/ --json
```

**退出码语义**：

- `0` = Pass（无 Critical）
- `1` = 至少一个 Critical

> **dry_run 模式**：如 plan.json 中 `dry_run: true`，跳过实际审计执行，仅输出将要检查的文件列表和规则集。用于验证 workspace 结构和规则覆盖。
>
> dry_run 输出示例：
>
> ```text
> [dry_run] 将执行审计：
>   目录: workspace/rm-test-001/
>   规则集: TR-001~005, CD-001/002/003/005/006, VO-001~004, SL-001~006, VV-001~005, DS-001~006, CH-001~006, SB-001~005
>   扫描文件: article.md, script.md, outline.md, audio-segments.json
> [dry_run] 预估耗时: ~5 秒
> [dry_run] 完成。实际审计请移除 dry_run 标志。
> ```

### 2. 解读审计结果

按严重度分类：

| 严重度 | 处理方式 |
| ------ | ------- |
| **critical** | 阻断流水线，必须修复后重跑 |
| **warning** | 记录到报告，可继续执行 |

**检查点 [CHECKPOINT: AUDIT_REVIEW]**：向用户展示审计摘要，**必须暂停等待用户确认修复方案后再执行修复。不可自动跳过。**

```text
审计摘要：
- 扫描文件数：<N>
- Critical：<N> 条（必须修复）
- Warning：<N> 条（可记录后继续）
- 涉及规则：<rule_ids>
```

**等待用户决策**：

| 用户输入 | 处理 |
| -------- | ---- |
| 确认修复 / 继续 | 对 Critical 项执行步骤 3 修复 |
| 0 Critical + 确认 | 直接进入报告步骤（步骤 6） |
| 要求跳过 Critical | 阻断，Critical 不可跳过（IRON LAW） |
| 终止 / 取消 | 保留审计报告，更新 plan.json 状态为 audit_failed |

**规则覆盖表**（37 条）：

| 规则组 | 规则 ID | 检测文件 | 说明 | 典型检测示例 |
| ------ | ------- | ------- | ---- | ----------- |
| 转写 | TR-001~005 | *.md, *.srt | 标点、标签、时间戳、填充词 | TR-003: SRT 时间戳重叠 >0.5s |
| 内容提炼 | CD-001/002/003/005/006 | *.md | 层级、字数、书面语、Hook、视角 | CD-003: 口播稿中出现书面语词汇 |
| 配音 | VO-001~004 | audio-segments.json | 语速、句长、多音字、停顿 | VO-001: 语速 <120 或 >180 字/分 |
| AI Slop | SL-001~006 | *.md | 假共情、假深刻、自我标榜等 | SL-001: "我知道你..." 假共情模式 |
| 视觉 | VV-001~005 | screenshots/*.png | 视觉一致性（需 mmx vision） | VV-001: 章节间主题不一致 |
| 口语化 | DS-001~006 | script.md, article.md | 信息保留、单句长度、人称、钩子、结构词、数字 | DS-002: 单句 >20 字 |
| 章节视觉 | CH-001~006 | *.tsx, *.jsx, *.css | 纯文字、列表揭示、AI 指纹、假数据、动画 | CH-003: 紫粉渐变 AI 指纹 |
| 分镜设计 | SB-001~005 | narrations.ts, theme.css | 字数、主题、对比度、动画数、占位图 | SB-005: placeholder 占位图 |

### 3. 指导修复

**前置**：步骤 2 确认有 Critical 违规 + 用户确认修复方案。

对每个 Critical 违规，按以下顺序处理：

1. 定位具体文件和行号
2. 解释违规原因
3. 提出具体修复方案
4. Agent 执行修复（编辑文件）

**修复原则**：

- 定位违规句子，修复具体句子（不重写整章）
- SL-001~006 修复参考 humanizer-zh 规则
- CD-003 书面语替换为口语化表达
- TR-003 时间戳问题需检查 SRT 源文件

### 4. 重跑审计验证

**前置**：步骤 3 完成所有 Critical 修复。

修复后必须重跑：

```bash
python -m tools.audit workspace/<pipeline_id>/
```

确认 Critical 数量归零。如仍有 Critical，回到步骤 3 继续修复（最多 3 轮）。

### 5. 反模式检查

| 规则 | 检测 | 修复 |
| ---- | ---- | ---- |
| AU-001 | 跳过审计直接进入 critique | 阻断，必须先跑 audit |
| AU-002 | 忽略 Critical 继续执行 | 阻断，必须修复 |
| AU-003 | 修复后不重跑审计 | 强制重跑验证 |

### 6. 报告结果

向用户报告：

- 扫描文件数
- Critical 数量（修复前 → 修复后）
- Warning 数量
- 修复的具体内容
- 最终状态（Pass / 仍有问题）

## Output

- 审计报告（终端输出或 JSON）
- 修复后的产出文件
- 汇总报告（Pass/Warning/Critical 数量）

## Resources

| 资源 | 路径 | 用途 |
| ---- | ---- | ---- |
| 审计工具 | `tools/audit/` | 确定性规则引擎（37 条规则） |
| 测试用例 | `skills/audit/test-prompts.json` | 典型 prompt 和期望输出 |

## Anti-Patterns

步骤 5 中检测的流程规则（详见 Failure Modes 获取恢复策略）：

| ID | 名称 | 检测方式 | 严重度 |
| -- | ---- | -------- | ------ |
| AU-001 | 跳过审计 | 未运行 audit 就进入 critique | critical |
| AU-002 | 忽略 Critical | audit 报告 critical 但继续执行 | critical |
| AU-003 | 修复后不重跑 | 编辑文件后未重新运行审计 | warning |

## Failure Modes

前置依赖和运行时错误的恢复策略：

| 场景 | 检测方式 | 恢复策略 |
| ---- | -------- | -------- |
| workspace 不存在 | 目录不存在 | 阻断，提示路径错误，检查 pipeline_id |
| rules.py 导入错误 | `import` 报错 ModuleNotFoundError | 阻断，提示 `pip install -e .` 或检查 Python 环境 |
| mmx vision 不可用 | VV-001~005 规则导入失败 | 跳过视觉规则，记录 warning，继续其余规则 |
| 无产出文件可检查 | workspace 目录为空 | 报告 "无文件可审计"，不阻断 |
| 修复后仍有 Critical（第 1-2 轮） | 重跑审计仍有 Critical | 回到步骤 3 继续修复 |
| 修复后仍有 Critical（第 3 轮） | 3 轮修复后仍有 Critical | 阻断，报告用户具体残留问题，等待人工介入 |
| 审计工具输出格式异常 | JSON 解析失败或字段缺失 | 记录原始输出，提示用户检查 tools/audit/ 版本 |
