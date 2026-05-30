# Transcribe Skill Optimization Spec

## Metadata

- Iteration: 5
- Track: darwin-skill Phase 3
- Baseline Score: 82
- Target Score: 87+
- Created: 2026-05-30

## Baseline Weaknesses

| 维度 | 当前分 | 问题 | 目标分 |
|------|--------|------|--------|
| Frontmatter (8) | 7/10 | description 可补充更多触发词 | 8/10 |
| Instruction Specificity (15) | 12/15 | 缺 dry_run 模式 | 14/15 |
| Resource Integration (5) | 3/5 | 缺少 references 引用 | 4/5 |

## Optimization Rounds

### Round 1: 补 dry_run 模式

**改什么**: 在 Step 3 之后添加 dry_run 模式说明

**为什么**: 与 voice/ingest 保持一致，允许用户验证流程而不消耗资源

**改法**:

```markdown
> **dry_run 模式**：如 plan.json 中 `dry_run: true`，跳过实际转写，
> 仅输出将要执行的命令和预期产物路径。用于验证输入文件和参数。
>
> dry_run 输出示例：
> ```
> [dry_run] 将执行转写：
>   输入: workspace/rm-test-001/raw/video.mp4
>   模型: base, 设备: auto, 语言: 自动检测
>   输出: workspace/rm-test-001/article.md
> [dry_run] 预估耗时: ~30 秒（base 模型，CPU）
> [dry_run] 完成。实际转写请移除 dry_run 标志。
> ```

**预期提升**: Instruction Specificity +2 (12→14)

### Round 2: 补充 Resource 引用

**改什么**: 添加 Resources 章节

**为什么**: 当前缺少对 references 和工具的显式引用

**改法**: 在 Output 之后添加：

```markdown
## Resources

| 资源 | 路径 | 用途 |
|------|------|------|
| 转写参考 | `references/transcription/REFERENCE.md` | Whisper 参数调优、停顿分段策略 |
| 转写工具 | `tools/ingest/transcriber.py` | Faster-Whisper 封装 |
| 测试用例 | `skills/transcribe/test-prompts.json` | 典型 prompt 和期望输出 |
```

**预期提升**: Resource Integration +1 (3→4)

### Round 3: 补充 test edge case

**改什么**: 补充 error case 测试 prompt

**为什么**: 当前 test-prompts.json 只有 happy path，缺 error case

**改法**: 在 test-prompts.json 追加：

```json
{
  "id": 4,
  "prompt": "转写一个损坏的音频文件",
  "expected": "阻断，提示音频文件损坏"
},
{
  "id": 5,
  "prompt": "转写一个 0.5 秒的极短音频",
  "expected": "阻断，提示音频时长过短"
}
```

**预期提升**: Effectiveness +1

## Acceptance Criteria

- [ ] dry_run 模式文档完整，含输出示例
- [ ] Resources 章节存在且引用路径正确
- [ ] test-prompts.json ≥ 5 条（含 error case）
- [ ] bash -n / JSON.parse 通过
- [ ] 新总分 > 82

## Regression Risk

Low. 纯文档补充，不改变任何执行逻辑。
