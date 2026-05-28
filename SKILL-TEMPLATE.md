# SKILL-TEMPLATE.md — Skill 契约与测试规范

> 本文件定义 Skill 的标准结构、契约规范和测试要求。创建新 Skill 时必须读取本文件。

---

## 一、Skill 目录结构

```
skills/<skill-name>/
├── SKILL.md              # 技能定义（YAML frontmatter + 指令 + Anti-Patterns 段落）
└── references/           # 可选：参考文件（按需加载）
```

---

## 二、SKILL.md 模板

```markdown
---
name: <skill-name>
description: <one-line description>
version: 1.0.0
input_schema: ./schema.ts#InputSchema
output_schema: ./schema.ts#OutputSchema
---

# Skill: <name>

## IRON LAW
一条不可违反的铁律。

## Purpose
一句话描述。

## Preconditions
- 前置 Skill 必须已完成
- 必须加载的参考文件

## Steps
1. 步骤一
2. 步骤二
3. ...

## Output
- 产出文件路径及格式
- Schema 定义

## Anti-Patterns
- 负责的规则 ID 列表

## Failure Modes
- 已知失败场景及回退策略
```

---

## 三、Agent-Tool 边界

创建新 Skill 时必须遵守 [AGENT.md](AGENT.md) 中定义的 Agent-Tool 边界原则。

### 写入边界

| 内容产物 (.md/.json/.html) | 二进制 (.mp4/.wav/.mp3) | 目录管理 |
|---------------------------|------------------------|---------|
| Agent 可以读写 | Agent 不碰 | 例外：Agent 可 mkdir -p 自己即将写入的目录（workspace/ 下） |

### 创作性 vs 机械性

| 类型 | 示例 | 谁做 |
|------|------|------|
| 创作性写入 | script.md、Chapter.tsx、plan.json | Agent |
| 机械性操作 | 移动文件、校验存在性、压缩转格式 | 工具 |
| 混合型 | audio-segments.json（Agent 写清单，mmx 执行） | 分工 |

### 工具调用协议

- **前置检查**: 运行 auth/status 确认可用
- **结果处理**: 成功→继续，失败→停下报告（不做自动降级）
- **输出校验**: 检查产出文件存在性
- **异常报告**: 记录到 plan.json

---

## 四、Schema 契约（L1 测试）

### 每个 Skill 必须定义 InputSchema 和 OutputSchema

```typescript
// schema.ts
import { z } from 'zod';

export const InputSchema = z.object({
  input_file: z.string().describe('输入文件路径'),
  language: z.enum(['zh', 'en']).default('zh'),
  // ...
});

export const OutputSchema = z.object({
  output_file: z.string().describe('输出文件路径'),
  confidence: z.number().min(0).max(1),
  // ...
});
```

### L1 测试要求（MVP 必须通过）

```typescript
// test/schema.test.ts
import { InputSchema, OutputSchema } from '../schema';

describe('<skill-name> schema', () => {
  it('accepts valid input', () => {
    const input = require('./fixtures/input-valid.json');
    expect(() => InputSchema.parse(input)).not.toThrow();
  });

  it('rejects invalid input', () => {
    const input = require('./fixtures/input-invalid.json');
    expect(() => InputSchema.parse(input)).toThrow();
  });

  it('output matches schema', () => {
    const output = require('./fixtures/output-golden.json');
    expect(() => OutputSchema.parse(output)).not.toThrow();
  });
});
```

---

## 五、反模式规则模板

反模式规则定义在 SKILL.md 的 `## Anti-Patterns` 段落中：

```markdown
## Anti-Patterns

| ID | 规则 | 级别 | 检测方式 | 修复建议 |
|----|------|------|---------|---------|
| XX-001 | <规则名称> | critical | <如何检测> | <修复建议> |
| XX-002 | <规则名称> | warning | <如何检测> | <修复建议> |
```

**ID 命名规范**：2 位大写字母前缀（Skill 缩写）+ 3 位数字。例如：`TR-001`、`CD-003`、`RR-002`。

---

## 六、评分体系（MVP 简化版）

MVP 阶段使用 4 维评分（满分 100），替代完整的 8 维体系：

| 维度 | 权重 | 评分标准 |
|------|------|---------|
| Schema 合规 | 30% | 输出是否通过 L1 Schema 测试 |
| 反模式规避 | 30% | 是否触发 anti-pattern 规则 |
| 视角一致性 | 20% | Expression DNA 是否贯穿（如指定视角）|
| AI Slop 检测 | 20% | SL-001~SL-006 规则 |

### 质量等级

| 等级 | 总分 | 说明 |
|------|------|------|
| A | ≥90 | 可直接发布 |
| B | 80-89 | 需微调 |
| C | 70-79 | 需人工审查 |
| D | <70 | 需重新生成 |

**发布门槛**：总分 ≥ 80，且无单维度 < 50% 的项。

### 命令

```bash
/recastory test-skill distill         # 运行 L1 Schema 测试
/recastory test-skill --all           # 运行所有 Skill 的 L1 测试
/recastory score distill output.json  # 运行 4 维评分
```

---

## 七、Roadmap（v2.0 扩展）

MVP 之后根据实际需求扩展：

| 版本 | 扩展内容 |
|------|---------|
| v1.1 | 增加 L2 确定性规则 CLI（`npx recastory-audit`）|
| v1.2 | 增加 L3 LLM 质量测试（golden samples 对比）|
| v2.0 | 扩展为完整 8 维评分（+信息保留度、口语化、叙事节奏、技术质量）|

---

## 八、事件信封（Event Envelope）

每个 Skill 执行完成后，输出标准化事件：

```json
{
  "pipeline_id": "rm-20260527-001",
  "skill": "transcribe",
  "version": "1.0.0",
  "status": "success",
  "input_files": ["workspace/001/raw/video.mp4"],
  "output_files": {
    "transcript": "workspace/001/transcribe/transcript.json"
  },
  "audit_result": {
    "passed": true,
    "warnings": [],
    "criticals": []
  },
  "score": {
    "total": 85,
    "schema_compliance": 30,
    "anti_pattern_avoidance": 25,
    "perspective_consistency": 15,
    "ai_slop_check": 15
  },
  "timestamp": "2026-05-27T15:14:00Z"
}
```
