#!/usr/bin/env bash
# Qwen3-TTS provider (本地 GPU)
# 优先级 2：配额耗尽时降级，需 GPU 4-8GB

tts_check() {
  python -c "from qwen_tts import QwenTTS" 2>/dev/null
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
    echo "Usage: tts_synthesize <text> <output_path> [voice_style]" >&2
    return 1
  fi

  python -c "
from qwen_tts import QwenTTS
m = QwenTTS.from_pretrained('Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice')
a = m.generate_custom_voice(text='''$text''', voice='$voice')
a.save('$out')
"
}

if [ "$(basename "$0")" = "qwen3-tts.sh" ] && [ -n "$1" ]; then
  "$@"
fi
