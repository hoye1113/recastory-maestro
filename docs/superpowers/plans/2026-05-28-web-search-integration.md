# mmx-cli Web Search Integration Plan

> **OBSOLETE**: 本计划中的 `mmx-config.json` 引用已失效。保留作为历史参考。
>
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## 质量门禁（每 Task 强制执行）

每个 Task 完成后执行 **3 轮 Code Review**：

```text
Task 执行 → Code Review #1 → 修复全部问题 → Code Review #2 → 修复回归问题 → Code Review #3 → 最终验证 → Commit
```

**Goal:** 集成 mmx-cli web search 能力到 Recastory research 流水线，为内容生产提供在线信息检索和事实核查能力。

**Architecture:** 新增 `tools/research-search.sh` 脚本，接受查询关键词，调用 `mmx search query` 获取搜索结果，输出结构化 JSON。搜索结果可用于：research 阶段的信息收集、distill 阶段的事实核查、storyboard 阶段的数据补充。

**Tech Stack:** Bash, mmx-cli (search query), jq (JSON 处理)

**参考：**
- `tools/generate-images.sh` — mmx CLI 调用模式参考
- `skills/voice/mmx-config.json` — 配置文件模板
- mmx-cli `search query --help` — API 参数
- `references/research/REFERENCE.md` — 研究领域参考（当前为占位）

---

## 设计决策

### 1. 定位：信息检索工具，非内容生成

mmx web search 用于：
- 收集主题相关背景信息
- 查找数据、统计、引用
- 核实事实（交叉验证）
- 发现相关案例和故事

**不用于：** 直接生成脚本/文章内容（那是 Agent 的职责）。

### 2. 输出格式

搜索结果输出为 JSON，便于下游脚本和 Agent 消费：

```json
{
  "query": "冷萃咖啡 历史",
  "results": [
    {
      "title": "...",
      "link": "...",
      "snippet": "...",
      "date": "2026-05-14"
    }
  ],
  "total": 5
}
```

### 3. 集成点

| 阶段 | 用途 | 调用方式 |
|------|------|---------|
| research | 主题调研、背景收集 | `bash tools/research-search.sh "query"` |
| distill | 事实核查、数据补充 | Agent 调用 |
| storyboard | 查找真实数据替换假数据 | Agent 调用 |

### 4. 幂等性

- 搜索是只读操作，天然幂等
- 结果不缓存（每次重新搜索）
- 输出到 stdout，不写文件（除非 `--out` 指定）

---

## 文件清单

| 操作 | 文件 | 职责 |
|------|------|------|
| Create | `skills/research/search-config.json` | mmx search 配置 |
| Create | `tools/research-search.sh` | 主脚本：查询 → 结构化结果 |
| Create | `tools/research-search.test.sh` | 测试 |
| Modify | `references/research/REFERENCE.md` | 填充研究领域参考内容 |
| Modify | `ARCHITECTURE.md` | 注册 mmx search 工具 |

---

## mmx search query 参数参考

```bash
mmx search query --q <query> [--output json] [--quiet]

# 关键参数
--q <query>          # 搜索查询（必需）
--output json        # JSON 格式输出
--quiet              # 静默模式

# 输出结构
{
  "organic": [
    {
      "title": "标题",
      "link": "URL",
      "snippet": "摘要",
      "date": "2026-05-14"
    }
  ],
  "related_searches": [
    { "query": "相关搜索词" }
  ]
}
```

---

### Task 1: 创建 search-config.json

**Files:**
- Create: `skills/research/search-config.json`

- [ ] **Step 1: 编写配置文件**

```json
{
  "provider": "minimax",
  "cli": "mmx",
  "auth_check": "mmx auth status",
  "search_template": {
    "command": "mmx search query",
    "params": {
      "q": "{{query}}",
      "output": "json",
      "quiet": true
    }
  },
  "defaults": {
    "max_results": 10,
    "language": "zh"
  },
  "query_prefix": {
    "fact_check": "核实：",
    "data_search": "数据统计：",
    "case_study": "案例：",
    "background": ""
  }
}
```

- [ ] **Step 2: 验证 JSON**

```bash
node -e "JSON.parse(require('fs').readFileSync('skills/research/search-config.json','utf8')); console.log('Valid JSON')"
```

- [ ] **Step 3: Commit**

```bash
git add skills/research/search-config.json
git commit -m "feat(research): add mmx search config"
```

---

### Task 2: 编写 research-search.sh

**Files:**
- Create: `tools/research-search.sh`
- Create: `tools/research-search.test.sh`

- [ ] **Step 1: 编写 research-search.sh**

脚本职责：接受查询关键词，调用 mmx search query，输出结构化结果。

**命令行接口：**

```bash
bash tools/research-search.sh <query> [--max <n>] [--out <path>] [--related]
```

- `<query>`：必需，搜索查询
- `--max <n>`：最大结果数（默认 10）
- `--out <path>`：输出到文件（默认 stdout）
- `--related`：同时输出相关搜索词

**核心逻辑：**

1. 验证 mmx 已安装且 auth 通过
2. 调用 `mmx search query --q "<query>" --output json --quiet`
3. 解析 JSON 结果
4. 按 `--max` 限制结果数
5. 输出格式化 JSON 到 stdout 或文件

- [ ] **Step 2: 编写测试**

测试用例：
1. 脚本存在
2. 语法检查
3. 无参数显示 usage
4. `--help` 显示帮助
5. mmx 不可用时优雅报错

- [ ] **Step 3: 运行测试**

```bash
chmod +x tools/research-search.sh tools/research-search.test.sh
bash tools/research-search.test.sh
```

- [ ] **Step 4: Commit**

```bash
git add tools/research-search.sh tools/research-search.test.sh
git commit -m "feat(tools): add research-search.sh for mmx web search"
```

---

### Task 3: 更新研究领域参考文件

**Files:**
- Modify: `references/research/REFERENCE.md`

- [ ] **Step 1: 填充 REFERENCE.md**

替换占位内容为完整的研究领域规范：

```markdown
# 研究领域参考文件

> 本文件定义研究（research）阶段的规范。执行 `/recastory research` 时加载。

---

## 研究方法论

### 横纵分析法

| 维度 | 方法 | 示例 |
|------|------|------|
| **横向对比** | 同类事物并列比较 | 冷萃 vs 冰滴 vs 冰咖啡：工艺/口感/成本 |
| **纵向深挖** | 单一事物层层深入 | 冷萃：起源 → 工艺演变 → 化学原理 → 商业化 |

### 研究流程

1. **定义问题** — 明确研究主题和关键问题
2. **广度搜索** — 用 mmx search 收集背景信息
3. **深度挖掘** — 对关键发现进行二次搜索
4. **交叉验证** — 多源核实重要数据和事实
5. **结构化输出** — 整理为研究笔记供 distill 使用

---

## 搜索工具使用

### mmx search query

```bash
# 基本搜索
bash tools/research-search.sh "冷萃咖啡 历史起源"

# 限定结果数
bash tools/research-search.sh "冷萃咖啡 工艺" --max 5

# 输出到文件
bash tools/research-search.sh "咖啡市场数据" --out workspace/<id>/research/search-results.json

# 带相关搜索词
bash tools/research-search.sh "冷萃咖啡" --related
```

### 搜索策略

| 阶段 | 查询模式 | 示例 |
|------|---------|------|
| 广度搜索 | 主题 + 背景 | "冷萃咖啡 历史 发展" |
| 深度挖掘 | 具体问题 | "冷萃咖啡 冷水萃取 化学原理" |
| 数据查找 | 主题 + 数据 | "冷萃咖啡 市场规模 2025" |
| 事实核查 | 声称 + 核实 | "冷萃咖啡 起源于荷兰 是否属实" |

---

## 信息源质量评估

| 维度 | 高可信度 | 低可信度 |
|------|---------|---------|
| 来源类型 | 学术论文、官方统计、权威媒体 | 自媒体、论坛帖子、广告 |
| 时效性 | 近 2 年内的数据 | 超过 5 年的旧数据 |
| 一致性 | 多源交叉验证通过 | 单一来源无法验证 |
| 具体性 | 有明确数字和出处 | 模糊描述无出处 |

---

## 研究输出格式

研究结果以 `research-notes.md` 形式保存到 workspace：

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

---

## 视角注入的研究维度

不同视角在研究阶段有不同的关注点：

| 视角 | 研究维度 | 搜索偏好 |
|------|---------|---------|
| Feynman | 基本原理、逻辑漏洞、实验数据 | 原始论文、实验报告 |
| MrBeast | 反直觉事实、极端数据、情感钩子 | 热门话题、惊人数据 |
| Musk | 技术极限、成本结构、可行性 | 技术文档、成本分析 |
| Munger | 跨学科类比、反向案例、激励分析 | 历史案例、心理学研究 |
```

- [ ] **Step 2: Commit**

```bash
git add references/research/REFERENCE.md
git commit -m "docs(research): fill in research methodology and search guide"
```

---

### Task 4: 注册到 ARCHITECTURE.md

**Files:**
- Modify: `ARCHITECTURE.md`

- [ ] **Step 1: 在 P0 工具清单添加 mmx search**

```markdown
| mmx CLI (search) | 网络搜索 | references/research/REFERENCE.md | skills/research/search-config.json |
| research-search.sh | 搜索查询 → 结构化结果 | references/research/REFERENCE.md | tools/research-search.sh |
```

- [ ] **Step 2: Commit**

```bash
git add ARCHITECTURE.md
git commit -m "docs: register mmx search and research-search.sh in tool table"
```

---

### Task 5: 真实数据验证

**Files:**
- None (validation only)

- [ ] **Step 1: 验证 mmx search**

```bash
mmx search query --q "冷萃咖啡 历史" --output json --quiet
```

Expected: JSON with organic results

- [ ] **Step 2: 测试脚本**

```bash
bash tools/research-search.sh "MiniMax AI" --max 3
```

Expected: JSON output with 3 results

- [ ] **Step 3: 测试输出到文件**

```bash
bash tools/research-search.sh "咖啡市场数据" --out /tmp/search-test.json
cat /tmp/search-test.json
```

Expected: Valid JSON file

- [ ] **Step 4: Commit（如有修复）**

---

## 验证清单

| 验证项 | 方法 |
|--------|------|
| 配置文件 | `node -e "JSON.parse(...)"` → OK |
| 脚本语法 | `bash -n tools/research-search.sh` → OK |
| 测试通过 | `bash tools/research-search.test.sh` → ALL PASSED |
| mmx search | `mmx search query --q "test"` → JSON results |
| 端到端 | `bash tools/research-search.sh "test" --max 3` → 3 results |
| REFERENCE.md | 包含完整研究方法论 |
| ARCHITECTURE.md | 工具表包含 mmx search |
