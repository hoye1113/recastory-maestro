# SKILL.md Darwin-Skill Score Annotation Spec

## Metadata

- Iteration: 8
- Track: v3.1.0 Phase 4 completion
- Created: 2026-05-30

## Context

Phase 2-3 已完成 9 个 skills 的 darwin-skill 基线评估和定向优化（平均 85.9→90.8）。Phase 4 遗留：在每个 SKILL.md 头部标注评分。

## Changes

在 9 个确定性 skills 的 SKILL.md frontmatter 后、正文前，添加评分摘要行：

```markdown
> Darwin Skill: {score}/100 (baseline {baseline} → optimized {date})
```

### Skills

| Skill | Baseline | Optimized | Δ |
|-------|----------|-----------|---|
| ingest | 82 | 91.3 | +9.3 |
| transcribe | 82 | 91.3 | +9.3 |
| render | 85 | 88.8 | +3.8 |
| audit | 84 | 90.3 | +6.3 |
| research | 84 | 90.3 | +6.3 |
| distill | 86 | 91.3 | +5.3 |
| using-recastory | 87 | 91.3 | +4.3 |
| voice | 88 | 90.3 | +2.3 |
| storyboard | 90 | 92.3 | +2.3 |

## File Changes

- `skills/ingest/SKILL.md`
- `skills/transcribe/SKILL.md`
- `skills/render/SKILL.md`
- `skills/audit/SKILL.md`
- `skills/research/SKILL.md`
- `skills/distill/SKILL.md`
- `skills/using-recastory/SKILL.md`
- `skills/voice/SKILL.md`
- `skills/storyboard/SKILL.md`

## Acceptance Criteria

- [ ] 9 个 SKILL.md 都有 Darwin Skill 评分行
- [ ] 评分与 results.tsv 一致
