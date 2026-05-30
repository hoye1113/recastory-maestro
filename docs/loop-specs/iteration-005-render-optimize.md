# Render Skill Optimization Spec

## Metadata

- Iteration: 5
- Track: darwin-skill Phase 3
- Baseline Score: 85
- Target Score: 88+
- Created: 2026-05-30

## Baseline Weaknesses

| 维度 | 当前分 | 问题 | 目标分 |
|------|--------|------|--------|
| Boundary Conditions (10) | 8/10 | L257 悬挂行（格式问题） | 9/10 |
| Overall Architecture (15) | 13/15 | 文件偏长（258 行），可精简 | 14/15 |

## Optimization Rounds

### Round 1: 修复 L257 悬挂行

**改什么**: render/SKILL.md 最后一行（L257）有一行悬挂内容：

```
| 音画同步偏差 > 0.5s | manifest.json 中 duration 偏差 | 阻断（IRON LAW），检查录屏和音频对齐 |
```

这行应该在 Failure Modes 表中，但被放在了文件末尾（踩坑参考之后）。

**为什么**: 格式问题影响文档结构清晰度

**改法**: 将此行移回 Failure Modes 表中（约 L247），或删除（因为 Failure Modes 表已有类似条目）。

检查 Failure Modes 表是否已有此场景：如果已有，删除 L257；如果没有，插入到 Failure Modes 表末尾。

**预期提升**: Boundary Conditions +1 (8→9)

### Round 2: 精简冗余描述

**改什么**: 检查是否有重复或可精简的段落

**为什么**: 文件偏长（258 行），影响可读性

**改法**:
- 检查 CDP Screencast 章节是否与 Step 2 重复
- 检查平台输出优化表是否可以折叠或移至 references
- 检查硬件加速表是否必要

**预期提升**: Overall Architecture +1 (13→14)

### Round 3: 补充 test edge case

**改什么**: 补充 error case 测试 prompt

**为什么**: 当前 test-prompts.json 已有 error case（缺文件、Vite 失败），但可以补充更多

**改法**: 检查现有 test-prompts.json，如果已有 ≥5 条则跳过；否则追加：

```json
{
  "id": 7,
  "prompt": "渲染时 FFmpeg 未安装",
  "expected": "阻断，提示安装 FFmpeg"
}
```

**预期提升**: Effectiveness +1（如需要）

## Acceptance Criteria

- [ ] L257 悬挂行已修复（移回 Failure Modes 或删除）
- [ ] 无悬挂/孤立内容
- [ ] 文件行数 ≤ 250（精简后）
- [ ] 新总分 > 85

## Regression Risk

Low. 格式修复和精简，不改变执行逻辑。
