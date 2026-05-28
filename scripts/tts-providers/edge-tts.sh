#!/usr/bin/env bash
# edge-tts provider (免费，微软云)
# 优先级 3：无 GPU 时降级，走微软 Edge 云端，免费无额度限制
set -euo pipefail

tts_check() {
  uvx edge-tts --version 2>/dev/null || pip show edge-tts >/dev/null 2>&1
}

tts_install_help() {
  echo "pip install edge-tts"
  echo "或直接使用 uvx edge-tts（无需安装）"
  echo "中文音色: zh-CN-XiaoxiaoNeural(女) zh-CN-YunjianNeural(男)"
}

tts_synthesize() {
  local text="$1"
  local out="$2"
  local voice="${3:-zh-CN-XiaoxiaoNeural}"

  if [ -z "$text" ] || [ -z "$out" ]; then
    echo "Usage: tts_synthesize <text> <output_path> [voice]" >&2
    return 1
  fi

  local srt="${out%.mp3}.srt"
  mkdir -p "$(dirname "$out")"
  uvx edge-tts --text "$text" --voice "$voice" --write-media "$out" --write-subtitles "$srt"

  if [ ! -s "$out" ]; then
    echo "Error: TTS synthesis failed, output file missing or empty: $out" >&2
    return 1
  fi
}

if [ "$(basename "$0")" = "edge-tts.sh" ] && [ -n "$1" ]; then
  "$@"
fi
