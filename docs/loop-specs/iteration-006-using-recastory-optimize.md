# Using-Recastory Skill Optimization Spec

## Metadata

- Iteration: 6
- Track: darwin-skill Phase 3 (batch 2)
- Baseline Score: 87
- Target Score: 91+
- Created: 2026-05-30

## Baseline Weaknesses

| 维度 | 当前分 | 问题 | 目标分 |
|------|--------|------|--------|
| Resource Integration (5) | 3/5 | 缺 Resources 章节 | 5/5 |
| Effectiveness (25) | 22/25 | test-prompts 缺 error case | 24/25 |

## Optimization Rounds

### Round 1: 添加 Resources 章节

**改什么**: 在 Output 之后添加 Resources 章节

**为什么**: 缺少对 AGENT.md、WORKFLOW.md、references/INDEX.md 的显式引用

**改法**: 添加 Resources 表格

### Round 2: 补充 test error case

**改什么**: 在 test-prompts.json 追加 error case

**为什么**: 当前缺 error case（参数冲突、视角不存在等）

**改法**: 追加 error case

## Acceptance Criteria

- [ ] Resources 章节存在
- [ ] test-prompts.json ≥ 5 条（含 error case）
- [ ] 新总分 > 87
