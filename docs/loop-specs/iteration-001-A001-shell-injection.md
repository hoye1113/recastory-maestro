# A-001: qwen3-tts.sh Shell Injection Vulnerability

## Metadata
- Iteration: 1
- Track: A
- Severity: critical
- Created: 2026-05-29

## Problem

`scripts/tts-providers/qwen3-tts.sh` lines 24-29: `$text` 和 `$voice` 变量直接用 `'''$text'''` 插值到 Python 代码字符串中。如果 text 包含三引号、反斜杠或 Python 特殊字符，会导致：
1. Python 语法错误（脚本失败）
2. 任意 Python 代码注入（安全风险）

## Root Cause

使用 shell 变量内联到 Python heredoc 时未做转义。

## Affected Files

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| scripts/tts-providers/qwen3-tts.sh | modify | 重写 tts_synthesize 函数 |

## Fix Strategy

改用 `python -c` 配合 `sys.argv` 传参，避免字符串插值：

```bash
tts_synthesize() {
  local text="$1"
  local out="$2"
  local voice="${3:-female-calm}"

  if [ -z "$text" ] || [ -z "$out" ]; then
    echo "Usage: tts_synthesize <text> <output_path> [voice_style]" >&2
    return 1
  fi

  python -c "
import sys
from qwen_tts import QwenTTS
m = QwenTTS.from_pretrained('Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice')
a = m.generate_custom_voice(text=sys.argv[1], voice=sys.argv[2])
a.save(sys.argv[3])
" "$text" "$voice" "$out"
}
```

## Acceptance Criteria

- [ ] `$text` 不再直接插值到 Python 代码字符串中
- [ ] 使用 sys.argv 传参
- [ ] bash -n 语法检查通过
- [ ] 包含三引号的 text 不会导致 Python 语法错误

## Review Checklist

- [ ] Spec Compliance: 改动匹配 spec
- [ ] Code Quality: bash -n 通过
- [ ] Runtime Neutrality: 无平台锁定

## Regression Risk

低。仅修改内部实现，函数签名和调用方式不变。
