# A-002: TTS Provider Scripts Missing Error Handling

## Metadata
- Iteration: 1
- Track: A
- Severity: critical
- Created: 2026-05-29

## Problem

4 个 TTS provider scripts 缺少基本的错误处理：
- 无 `set -e`：命令失败不会终止脚本
- 无 output validation：合成后不检查输出文件是否存在
- tts_synthesize 失败时调用方无法感知

## Root Cause

脚本作为最小实现创建，未加错误处理层。

## Affected Files

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| scripts/tts-providers/minimax.sh | modify | 添加 error handling |
| scripts/tts-providers/qwen3-tts.sh | modify | 添加 error handling（与 A-001 合并） |
| scripts/tts-providers/edge-tts.sh | modify | 添加 error handling |
| scripts/tts-providers/piper-tts.sh | modify | 添加 error handling |

## Fix Strategy

每个脚本添加：
1. 不加 `set -e`（因为 tts_check 设计为可失败，return 非零）
2. tts_synthesize 内部检查命令退出码
3. 合成后检查输出文件是否存在且大小 >0
4. 失败时 return 1

统一模式：

```bash
tts_synthesize() {
  local text="$1"
  local out="$2"
  local voice="${3:-<default>}"

  if [ -z "$text" ] || [ -z "$out" ]; then
    echo "Usage: tts_synthesize <text> <output_path> [voice]" >&2
    return 1
  fi

  # 确保输出目录存在
  mkdir -p "$(dirname "$out")"

  <synthesize command>

  # 验证输出
  if [ ! -s "$out" ]; then
    echo "Error: TTS synthesis failed, output file missing or empty: $out" >&2
    return 1
  fi
}
```

## Acceptance Criteria

- [ ] 每个 tts_synthesize 函数检查输出文件存在且非空
- [ ] mkdir -p 确保输出目录存在
- [ ] 失败时 return 1 并输出 stderr
- [ ] bash -n 语法检查通过（全部 4 个脚本）

## Review Checklist

- [ ] Spec Compliance: 4 个文件全部修改
- [ ] Code Quality: bash -n 通过
- [ ] Runtime Neutrality: 无平台锁定

## Regression Risk

低。仅在函数末尾添加验证逻辑，不改变已有的合成流程。
