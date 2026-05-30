# Voice Skill Optimization Spec

## Metadata

- Iteration: 6
- Track: darwin-skill Phase 3 (batch 2)
- Baseline Score: 88
- Target Score: 92+
- Created: 2026-05-30

## Baseline Weaknesses

| 维度 | 当前分 | 问题 | 目标分 |
|------|--------|------|--------|
| Resource Integration (5) | 4/5 | Resources 已有但可补充 SRT 合并脚本引用 | 5/5 |
| Effectiveness (25) | 21/25 | test-prompts 缺 error case | 23/25 |

## Optimization Rounds

### Round 1: 补充 test error case

**改什么**: 在 test-prompts.json 追加 error case

**为什么**: 当前只有 happy path，缺 error case

**改法**: 追加 provider 全部不可用、script.md 格式错误的测试 prompt

### Round 2: 精简典型执行流程

**改什么**: 典型执行流程段落（L326-350）偏长

**为什么**: 文件较长（351 行），可精简

**改法**: 将典型执行流程折叠为简表或移至 test-prompts.json 的 expected 字段

## Acceptance Criteria

- [ ] test-prompts.json ≥ 5 条（含 error case）
- [ ] 新总分 > 88
