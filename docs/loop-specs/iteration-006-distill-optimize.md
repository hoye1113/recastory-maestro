# Distill Skill Optimization Spec

## Metadata

- Iteration: 6
- Track: darwin-skill Phase 3 (batch 2)
- Baseline Score: 86
- Target Score: 90+
- Created: 2026-05-30

## Baseline Weaknesses

| 维度 | 当前分 | 问题 | 目标分 |
|------|--------|------|--------|
| Resource Integration (5) | 3/5 | 缺 Resources 章节 | 5/5 |
| Effectiveness (25) | 21/25 | test-prompts 缺 error case | 23/25 |

## Optimization Rounds

### Round 1: 添加 Resources 章节

**改什么**: 在 Output 之后添加 Resources 章节

**为什么**: 缺少对 references 文件和工具的显式引用

**改法**: 添加 Resources 表格，引用 content-distillation/REFERENCE.md、humanizer-zh SKILL.md、test-prompts.json

### Round 2: 补充 test error case

**改什么**: 在 test-prompts.json 追加 error case

**为什么**: 当前缺 error case（article.md 为空、视角不存在等）

**改法**: 追加 error case

## Acceptance Criteria

- [ ] Resources 章节存在且引用路径正确
- [ ] test-prompts.json ≥ 5 条（含 error case）
- [ ] 新总分 > 86
