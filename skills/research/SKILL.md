---
name: research
version: 1.0.0
description: 通过 mmx search 进行主题调研，输出结构化研究笔记供 distill 使用。触发条件：/recastory research 或被 using-recastory 调度。
---

# Skill: research

## IRON LAW

**每条核心发现必须附带来源 URL，未核实信息必须列入「未核实信息」清单。研究笔记是 distill 的输入，数据质量直接决定内容质量。**

## Purpose

围绕研究主题进行系统性搜索调研，通过广度搜索、深度挖掘、交叉验证三阶段，输出结构化研究笔记供 distill 阶段使用。

## Preconditions

- `plan.json` 已存在
- `research` 参数（研究主题）已写入 plan.json
- `references/research/REFERENCE.md` 已加载（包含横纵分析法、搜索策略、信息源质量评估标准）
- mmx-cli 已安装（不可用时步骤 2 阻断）

## Agent-Tool 边界

| 步骤 | 谁做 | 产物 |
|------|------|------|
| Step 1 | Agent（读取计划） | 研究主题、关键问题 |
| Step 2 | Agent 调用 research-search.sh（工具执行） | 广度搜索结果 |
| Step 3 | Agent 调用 research-search.sh（工具执行） | 深度搜索结果 |
| Step 4 | Agent（交叉验证判断） | 验证结论 |
| Step 5 | Agent（结构化写入） | research-notes.md |
| Step 6 | Agent（记录 + 报告） | plan.json 更新 |

## Steps

### 1. 读取计划和研究主题

从 `plan.json` 获取：
- `pipeline_id` — 用于输出目录
- `research.topic` — 研究主题
- `research.questions` — 关键问题列表（如有）
- `research.perspective` — 指定视角（如有，影响搜索维度）

加载 `references/research/REFERENCE.md`，获取：
- 横纵分析法框架
- 搜索策略模板
- 信息源质量评估标准
- 视角注入的研究维度

### 2. 广度搜索

按 REFERENCE.md 的搜索策略，对主题进行多角度广度搜索：

```bash
# 主题背景
bash tools/research-search.sh "<主题> 历史 发展" --out workspace/<id>/research/search-bg.json --related

# 横向对比（如适用）
bash tools/research-search.sh "<主题> 对比 区别" --max 5 --out workspace/<id>/research/search-compare.json

# 市场/数据概况
bash tools/research-search.sh "<主题> 数据 市场规模" --max 5 --out workspace/<id>/research/search-data.json
```

搜索时读取 `skills/research/search-config.json` 的 `query_prefix` 为不同搜索类型添加前缀。

记录每个搜索结果的标题、摘要、URL、日期。

### 3. 深度挖掘

从广度搜索中识别关键发现，进行二次搜索：

```bash
# 对关键发现深入
bash tools/research-search.sh "<具体问题>" --max 5 --out workspace/<id>/research/search-deep-<n>.json

# 事实核查
bash tools/research-search.sh "核实：<待核实声明>" --max 3 --out workspace/<id>/research/search-verify-<n>.json
```

深度挖掘的触发条件：
- 广度搜索中出现反直觉或惊人的数据
- 多个来源说法不一致
- 需要原始出处或更详细的技术解释

### 4. 交叉验证

按 REFERENCE.md 的信息源质量评估标准，对重要数据进行交叉验证：

| 验证维度 | 操作 |
|---------|------|
| 多源一致性 | 同一数据点至少 2 个独立来源确认 |
| 时效性 | 标注数据年份，超过 5 年标记为过时 |
| 来源可信度 | 学术论文 > 官方统计 > 权威媒体 > 自媒体 |
| 具体性 | 优先采用有明确数字和出处的信息 |

验证结果分类：
- **已验证** — 多源一致，列入核心发现
- **部分验证** — 来源有限但可信，列入关键数据并标注
- **未验证** — 仅单一来源或可信度存疑，列入未核实信息

### 5. 输出研究笔记

生成 `workspace/<id>/research/research-notes.md`，格式严格遵循 REFERENCE.md 定义：

```markdown
# 研究笔记：<主题>

## 核心发现
- 发现 1（来源：URL）
- 发现 2（来源：URL）

## 关键数据
| 指标 | 数值 | 来源 | 年份 |
|------|------|------|------|
| 市场规模 | XX 亿元 | XX报告 | 2025 |

## 相关案例
1. 案例名称 — 简述（来源：URL）

## 未核实信息
- [ ] 待核实声明 1
- [ ] 待核实声明 2
```

写入规则：
- 核心发现不超过 8 条，按重要性排序
- 关键数据必须有来源和年份
- 相关案例不超过 5 个
- 未核实信息用 checkbox 标记，供 distill 决定是否使用

### 6. 更新 plan.json

在 plan.json 的 `research` 字段记录：

```json
{
  "research": {
    "status": "done",
    "output": "research/research-notes.md",
    "searches_count": 6,
    "findings_count": 5,
    "unverified_count": 2,
    "completed_at": "2026-05-28T12:00:00Z"
  }
}
```

报告完成：列出核心发现数量、数据条目数、未核实信息数。

### 7. 反模式检查

| 规则 | 检测 | 修复 |
|------|------|------|
| RS-001 | 核心发现缺少来源 URL | 补充来源或降级为未核实信息 |
| RS-002 | 使用超过 5 年的旧数据且未标注 | 标注年份或搜索更新数据 |
| RS-003 | 未核实信息未列入清单 | 追加到未核实信息 |
| RS-004 | 搜索结果全部来自同一来源 | 扩展搜索词获取多元来源 |
| RS-005 | 搜索词过于宽泛（结果 >50 条且相关度低） | 细化搜索词，增加限定条件 |

## Output

- `workspace/<id>/research/research-notes.md` — 结构化研究笔记
- `workspace/<id>/research/search-*.json` — 原始搜索结果（中间产物）

## Anti-Patterns

| ID | 名称 | 检测 | 严重度 |
|----|------|------|--------|
| RS-001 | 单源依赖 | 核心发现仅有 1 个来源 | critical |
| RS-002 | 数据过时 | 使用 >5 年数据未标注 | warning |
| RS-003 | 未核实遗漏 | 未验证信息未列入清单 | critical |
| RS-004 | 缺少引用 | 发现/数据缺少 URL 出处 | critical |
| RS-005 | 查询过泛 | 搜索结果相关度低 | warning |

## Failure Modes

| 场景 | 处理 |
|------|------|
| mmx-cli 未安装 | 步骤 2 阻断，报告用户 |
| mmx auth 失败 | 步骤 2 阻断，报告用户 |
| 搜索无结果 | 换搜索词重试，仍无结果则记录空状态 |
| plan.json 缺少 research 字段 | 阻断，要求补充研究主题 |
| 网络超时 | 重试 1 次，仍失败则记录并继续其他搜索 |
| REFERENCE.md 不存在 | 使用默认搜索策略，跳过视角注入 |
