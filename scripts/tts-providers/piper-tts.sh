#!/usr/bin/env bash
# Piper TTS provider (离线，CPU 实时)
# 优先级 4：离线兜底，无需网络和 GPU，质量中等
set -euo pipefail

tts_check() {
  piper --version 2>/dev/null
}

tts_install_help() {
  echo "pip install piper-tts"
  echo "或从 https://github.com/rhasspy/piper 下载预编译二进制"
  echo "中文模型: zh_CN-huayan-medium（自动下载）"
}

tts_synthesize() {
  local text="$1"
  local out="$2"
  local voice="${3:-zh_CN-huayan-medium}"

  if [ -z "$text" ] || [ -z "$out" ]; then
    echo "Usage: tts_synthesize <text> <output_path> [voice]" >&2
    return 1
  fi

  mkdir -p "$(dirname "$out")"
  echo "$text" | piper --model "$voice" --output_file "$out"

  if [ ! -s "$out" ]; then
    echo "Error: TTS synthesis failed, output file missing or empty: $out" >&2
    return 1
  fi
}

if [ "$(basename "$0")" = "piper-tts.sh" ] && [ -n "$1" ]; then
  "$@"
fi
