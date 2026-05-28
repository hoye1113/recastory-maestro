#!/bin/bash
set -euo pipefail

# Test script for generate-videos.sh
# Validates argument parsing, input validation, and script syntax.
# Does NOT test actual mmx video generation (requires mmx CLI + auth).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$PROJECT_ROOT/.test-generate-videos"
GEN_SCRIPT="$SCRIPT_DIR/generate-videos.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Cleanup
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# ── Test 1: Script exists ────────────────────────────────────────────────────
test_script_exists() {
    echo -e "\n${YELLOW}Test 1: Script exists${NC}"

    if [ -f "$GEN_SCRIPT" ]; then
        echo -e "${GREEN}PASS${NC}: generate-videos.sh exists"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: generate-videos.sh not found at $GEN_SCRIPT"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# ── Test 2: Syntax check (bash -n) ──────────────────────────────────────────
test_syntax_check() {
    echo -e "\n${YELLOW}Test 2: Script syntax check${NC}"

    if bash -n "$GEN_SCRIPT" 2>&1; then
        echo -e "${GREEN}PASS${NC}: Script syntax is valid"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: Script has syntax errors"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# ── Test 3: No arguments shows usage ─────────────────────────────────────────
test_no_args() {
    echo -e "\n${YELLOW}Test 3: No arguments shows usage${NC}"

    local output
    output=$(bash "$GEN_SCRIPT" 2>&1) && true

    if echo "$output" | grep -qi "usage\|Usage"; then
        echo -e "${GREEN}PASS${NC}: No arguments shows usage message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: Expected usage message, got: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# ── Test 4: Non-existent directory errors ────────────────────────────────────
test_nonexistent_dir() {
    echo -e "\n${YELLOW}Test 4: Non-existent directory errors${NC}"

    local output
    output=$(bash "$GEN_SCRIPT" "/nonexistent/path" 2>&1) && true

    if echo "$output" | grep -qi "not found\|ERROR"; then
        echo -e "${GREEN}PASS${NC}: Non-existent directory produces error"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: Expected error for non-existent dir, got: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# ── Test 5: Missing outline.md errors ───────────────────────────────────────
test_missing_outline() {
    echo -e "\n${YELLOW}Test 5: Missing outline.md errors${NC}"

    cleanup
    mkdir -p "$TEST_DIR"

    local output
    output=$(bash "$GEN_SCRIPT" "$TEST_DIR" 2>&1) && true

    if echo "$output" | grep -qi "outline.md.*not found\|ERROR"; then
        echo -e "${GREEN}PASS${NC}: Missing outline.md produces error"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: Expected outline.md error, got: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# ── Test 6: --dry-run with temp outline ─────────────────────────────────────
test_dry_run() {
    echo -e "\n${YELLOW}Test 6: --dry-run with video marker${NC}"

    cleanup
    mkdir -p "$TEST_DIR/distill"

    # Create a minimal outline with 1 video marker and 1 plain step
    cat > "$TEST_DIR/distill/outline.md" << 'OUTLINE'
## 第1章：intro — 引言

### 步骤 1

这是一个介绍段落，没有视频标记。

### 步骤 2

<!-- video: A coffee bean being ground in slow motion, cinematic close-up -->

这里是第二步的内容。
OUTLINE

    # --dry-run should skip mmx auth check per spec
    local output
    output=$(bash "$GEN_SCRIPT" "$TEST_DIR" --dry-run 2>&1) || true

    if echo "$output" | grep -qi "DRY-RUN\|dry-run\|Would generate"; then
        echo -e "${GREEN}PASS${NC}: --dry-run shows video list without generating"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: Expected dry-run output, got: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# ── Main test runner ─────────────────────────────────────────────────────────
main() {
    echo -e "${YELLOW}Running generate-videos.sh tests...${NC}"

    test_script_exists
    test_syntax_check
    test_no_args
    test_nonexistent_dir
    test_missing_outline
    test_dry_run

    # Summary
    echo -e "\n${YELLOW}Test Summary:${NC}"
    echo -e "  Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  Failed: ${RED}$TESTS_FAILED${NC}"

    # Cleanup
    cleanup

    if [ $TESTS_FAILED -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

main "$@"
