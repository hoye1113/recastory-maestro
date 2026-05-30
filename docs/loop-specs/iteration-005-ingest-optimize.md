# Ingest Skill Optimization Spec

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

**改什么**: 在 Steps 的 Step 2 之后添加 dry_run 模式说明

**为什么**: voice/storyboard/distill 都有 dry_run 支持，ingest 缺失会导致用户无法验证流程

**改法**:

```markdown
> **dry_run 模式**：如 plan.json 中 `dry_run: true`，跳过实际下载和转写，
> 仅输出将要执行的命令列表和预期产物路径。用于验证 URL 有效性和参数合理性。
>
> dry_run 输出示例：
> ```
> [dry_run] 将执行以下步骤：
>   1. yt-dlp download "<url>" → video/<title>.mp4
>   2. ffmpeg extract audio → audio/<title>.wav
>   3. faster-whisper transcribe → article.md
> [dry_run] 预估耗时: ~60 秒（取决于视频时长和网络速度）
> [dry_run] 完成。实际导入请移除 dry_run 标志。
> ```
```

**预期提升**: Instruction Specificity +2 (12→14)

### Round 2: 补充 Resource 引用

**改什么**: 添加 Resources 章节

**为什么**: 当前缺少对 references 文件的显式引用

**改法**: 在 Output 之后添加：

```markdown
## Resources

| 资源 | 路径 | 用途 |
|------|------|------|
| 转写参考 | `references/transcription/REFERENCE.md` | Whisper 参数调优 |
| 测试用例 | `skills/ingest/test-prompts.json` | 典型 prompt 和期望输出 |
| 摄取工具 | `tools/ingest/` | Python 模块（yt-dlp + FFmpeg + Whisper） |
```

**预期提升**: Resource Integration +1 (3→4)

### Round 3: 补充 test edge case

**改什么**: 补充 error case 测试 prompt

**为什么**: 当前 test-prompts.json 只有 happy path，缺 error case

**改法**: 在 test-prompts.json 追加：

```json
{
  "id": 4,
  "prompt": "用一个无效的 URL 进行 ingest",
  "expected": "阻断，报告 URL 不匹配支持平台"
},
{
  "id": 5,
  "prompt": "网络断开时 ingest 一个视频",
  "expected": "yt-dlp 失败，保留中间文件，报告错误"
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
