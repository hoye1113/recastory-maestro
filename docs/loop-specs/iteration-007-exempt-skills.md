# Exempt Skills Test Assets Spec

## Metadata

- Iteration: 7
- Track: darwin-skill Phase 1 completion
- Created: 2026-05-30

## Context

5 个 LLM 创意型 skills 豁免于 darwin-skill 自动优化，但仍需 test-prompts.json 或 darwin-exempt 标记。

## Skills

| Skill | 类型 | 策略 |
|-------|------|------|
| critique | LLM 深度审查 | test-prompts.json（2 条 happy path + 1 条 error） |
| humanizer-zh | 文本改写 | test-prompts.json（2 条 happy path + 1 条 error） |
| nuwa-skill | 视角工厂 | darwin-exempt: true（组合爆炸，无法硬编码预期） |
| perspectives/feynman | 视角注入 | darwin-exempt: true（被 distill/storyboard 调用） |
| perspectives/mrbeast | 视角注入 | darwin-exempt: true（被 distill/storyboard 调用） |
| web-video-presentation | 方法论参考 | darwin-exempt: true（纯文档型） |

## Execution

1. 为 critique 和 humanizer-zh 创建 test-prompts.json
2. 为 nuwa-skill/perspectives/web-video-presentation 在 SKILL.md frontmatter 添加 `darwin-exempt: true`

## Acceptance Criteria

- [ ] critique/test-prompts.json 存在（≥3 条）
- [ ] humanizer-zh/test-prompts.json 存在（≥3 条）
- [ ] nuwa-skill SKILL.md 含 darwin-exempt: true
- [ ] perspectives/feynman SKILL.md 含 darwin-exempt: true
- [ ] perspectives/mrbeast SKILL.md 含 darwin-exempt: true
- [ ] web-video-presentation SKILL.md 含 darwin-exempt: true
