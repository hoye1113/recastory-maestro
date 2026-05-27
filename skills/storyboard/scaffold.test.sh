#!/bin/bash
# skills/storyboard/scaffold.test.sh
# Integration test for scaffold.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="/tmp/scaffold-test-$$"
PASS=0
FAIL=0

cleanup() {
  rm -rf "$WORKSPACE"
}
trap cleanup EXIT

# --- Helper ---
assert_file_exists() {
  local path="$1"
  local label="$2"
  if [ -f "$path" ]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — file not found: $path"
    FAIL=$((FAIL + 1))
  fi
}

assert_dir_exists() {
  local path="$1"
  local label="$2"
  if [ -d "$path" ]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — directory not found: $path"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if grep -q "$pattern" "$file" 2>/dev/null; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — pattern '$pattern' not found in $file"
    FAIL=$((FAIL + 1))
  fi
}

# --- Setup mock workspace ---
echo "=== Setting up mock workspace ==="
mkdir -p "$WORKSPACE/distill"

cat > "$WORKSPACE/distill/outline.md" << 'OUTLINE_EOF'
# Outline: test-pipeline

> 主题：paper-press · 总时长：~15s · 2 章 / 5 步

## 1. intro — 介绍（2 steps · ~6s）

**信息池**
- 数据：测试数据 —— 来源 article §L1

- step 1 (~3s) — 标题 "测试标题"
- step 2 (~3s) — 副标题 "测试副标题"

**口播节选**：这是测试口播。

## 2. body — 正文（3 steps · ~9s）

**信息池**
- 数据：正文数据 —— 来源 article §L2

- step 1 (~3s) — 要点一
- step 2 (~3s) — 要点二
- step 3 (~3s) — 要点三

**口播节选**：正文口播内容。
OUTLINE_EOF

echo "Mock outline created at $WORKSPACE/distill/outline.md"

# --- Run scaffold ---
echo ""
echo "=== Running scaffold.sh ==="
bash "$SCRIPT_DIR/scaffold.sh" "$WORKSPACE" "paper-press"

# --- Assertions ---
echo ""
echo "=== Running assertions ==="

SB="$WORKSPACE/storyboard"

assert_dir_exists  "$SB/src/chapters/01-intro" \
  "chapter 01-intro directory exists"

assert_dir_exists  "$SB/src/chapters/02-body" \
  "chapter 02-body directory exists"

assert_file_exists "$SB/src/chapters/01-intro/narrations.ts" \
  "01-intro/narrations.ts exists"

assert_contains    "$SB/src/chapters/01-intro/narrations.ts" \
  "这是测试口播" \
  "narrations.ts contains '这是测试口播'"

assert_contains    "$SB/src/chapters.ts" \
  "01-intro" \
  "chapters.ts references 01-intro"

assert_contains    "$SB/src/chapters.ts" \
  "stepCount: 2" \
  "chapters.ts has stepCount: 2"

assert_contains    "$SB/src/main.tsx" \
  "01-intro/Chapter.css" \
  "main.tsx imports 01-intro/Chapter.css"

assert_file_exists "$SB/package.json" \
  "package.json exists"

# --- Summary ---
echo ""
TOTAL=$((PASS + FAIL))
echo "Results: $PASS/$TOTAL passed"

if [ "$FAIL" -eq 0 ]; then
  echo "ALL TESTS PASSED"
  exit 0
else
  echo "$FAIL TEST(S) FAILED"
  exit 1
fi
