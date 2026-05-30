# Audit Skill Optimization Spec

## Metadata

- Iteration: 6
- Track: darwin-skill Phase 3 (batch 2)
- Baseline Score: 84
- Target Score: 89+
- Created: 2026-05-30

## Baseline Weaknesses

| 维度 | 当前分 | 问题 | 目标分 |
|------|--------|------|--------|
| Instruction Specificity (15) | 12/15 | 缺 dry_run 模式 | 14/15 |
| Resource Integration (5) | 3/5 | 缺 Resources 章节 | 5/5 |
| Effectiveness (25) | 20/25 | test-prompts 缺 error case | 22/25 |

## Optimization Rounds

### Round 1: 添加 dry_run 模式

**改什么**: 在 Step 1 之后添加 dry_run 模式说明

**为什么**: 与其他 skill 保持一致，允许用户验证流程

**改法**: 添加 dry_run 输出示例

### Round 2: 添加 Resources 章节

**改什么**: 在 Output 之后添加 Resources 章节

**为什么**: 缺少对 tools/audit 模块和 REFERENCE.md 的显式引用

**改法**: 添加 Resources 表格

### Round 3: 补充 test error case

**改什么**: 在 test-prompts.json 追加 error case

**为什么**: 当前缺 error case（workspace 不存在、rules.py 导入错误等）

**改法**: 追加 error case

## Acceptance Criteria

- [ ] dry_run 模式文档完整
- [ ] Resources 章节存在
- [ ] test-prompts.json ≥ 5 条（含 error case）
- [ ] 新总分 > 84
