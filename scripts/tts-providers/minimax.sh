#!/usr/bin/env bash
# minimax TTS provider (mmx-cli)
# 优先级 1：中文首选，质量最高，需付费额度
set -euo pipefail

tts_check() {
  mmx auth status 2>/dev/null
}

tts_install_help() {
  echo "npm install -g mmx-cli && mmx auth login --api-key <your-api-key>"
}

tts_synthesize() {
  local text="$1"
  local out="$2"
  local voice="${3:-male-qn-qingse}"

  if [ -z "$text" ] || [ -z "$out" ]; then
    echo "Usage: tts_synthesize <text> <output_path> [voice]" >&2
    return 1
  fi

  mkdir -p "$(dirname "$out")"
  mmx speech synthesize --text "$text" --voice "$voice" --out "$out" --subtitles

  if [ ! -s "$out" ]; then
    echo "Error: TTS synthesis failed, output file missing or empty: $out" >&2
    return 1
  fi
}

# 支持直接调用: bash minimax.sh tts_synthesize "文本" "输出路径" [音色]
if [ "$(basename "$0")" = "minimax.sh" ] && [ -n "$1" ]; then
  "$@"
fi
