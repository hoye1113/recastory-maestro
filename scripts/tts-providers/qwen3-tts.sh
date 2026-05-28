#!/usr/bin/env bash
# Qwen3-TTS provider (本地 GPU)
# 优先级 2：配额耗尽时降级，需 GPU 4-8GB
set -euo pipefail

find_python() {
  # Find a working Python executable (bypass Windows Store stub)
  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import sys" 2>/dev/null && { echo "python3"; return 0; }
  fi
  if command -v python >/dev/null 2>&1; then
    python -c "import sys" 2>/dev/null && { echo "python"; return 0; }
  fi
  # Windows: try common install paths
  for p in /c/Users/*/AppData/Local/Programs/Python/*/python.exe; do
    if [ -x "$p" ]; then
      "$p" -c "import sys" 2>/dev/null && { echo "$p"; return 0; }
    fi
  done
  return 1
}

tts_check() {
  local py
  py=$(find_python) || return 1
  "$py" -c "from qwen_tts import Qwen3TTSModel" 2>/dev/null
}

tts_install_help() {
  echo "pip install -U qwen-tts  # 需要 GPU 4-8GB (0.6B模型) 或 6-8GB (1.7B模型)"
  echo "模型会自动从 HuggingFace 下载，首次加载较慢"
}

tts_synthesize() {
  local text="$1"
  local out="$2"
  local voice="${3:-female-calm}"

  if [ -z "$text" ] || [ -z "$out" ]; then
    echo "Usage: tts_synthesize <text> <output_path> [voice]" >&2
    return 1
  fi

  mkdir -p "$(dirname "$out")"
  local py
  py=$(find_python) || { echo "Error: No working Python found" >&2; return 1; }
  "$py" -c "
import sys
from qwen_tts import Qwen3TTSModel
m = Qwen3TTSModel.from_pretrained('Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice')
a = m.generate_custom_voice(text=sys.argv[1], voice=sys.argv[2])
a.save(sys.argv[3])
" "$text" "$voice" "$out"

  if [ ! -s "$out" ]; then
    echo "Error: TTS synthesis failed, output file missing or empty: $out" >&2
    return 1
  fi
}

if [ "$(basename "$0")" = "qwen3-tts.sh" ] && [ -n "$1" ]; then
  "$@"
fi
