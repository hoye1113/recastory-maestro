# Storyboard Skill Optimization Spec

## Metadata

- Iteration: 6
- Track: darwin-skill Phase 3 (batch 2)
- Baseline Score: 90
- Target Score: 92+
- Created: 2026-05-30

## Baseline Weaknesses

| 维度 | 当前分 | 问题 | 目标分 |
|------|--------|------|--------|
| Resource Integration (5) | 4/5 | References 章节已有但命名不统一（应为 Resources） | 5/5 |
| Effectiveness (25) | 22/25 | test-prompts 缺 error case | 24/25 |

## Optimization Rounds

### Round 1: 统一 Resources 章节命名

**改什么**: 将 `## References` 改为 `## Resources`

**为什么**: 与其他 skill 保持一致（ingest/transcribe/render/voice 都用 Resources）

**改法**: 重命名章节标题

### Round 2: 补充 test error case

**改什么**: 在 test-prompts.json 追加 error case

**为什么**: 当前 test-prompts 缺少 scaffold 失败、node_modules 损坏等场景

**改法**: 追加 error case

## Acceptance Criteria

- [ ] 章节命名为 Resources
- [ ] test-prompts.json ≥ 5 条（含 error case）
- [ ] 新总分 > 90
