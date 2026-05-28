#!/bin/bash
# tools/capture-screenshots.test.sh
# Tests for capture-screenshots.sh
# Validates argument parsing, input validation, and script syntax.
# Does NOT test actual Vite/Puppeteer (requires browser).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAPTURE_SCRIPT="$SCRIPT_DIR/capture-screenshots.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

pass() { echo -e "  ${GREEN}PASS${NC} $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo -e "  ${RED}FAIL${NC} $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }

# ── Test 1: Script exists ────────────────────────────────────────────────────
test_script_exists() {
    echo -e "\n${YELLOW}Test 1: Script exists${NC}"
    if [ -f "$CAPTURE_SCRIPT" ]; then
        pass "capture-screenshots.sh exists"
    else
        fail "capture-screenshots.sh not found at $CAPTURE_SCRIPT"
    fi
}

# ── Test 2: Syntax check (bash -n) ──────────────────────────────────────────
test_syntax_check() {
    echo -e "\n${YELLOW}Test 2: Syntax check${NC}"
    if bash -n "$CAPTURE_SCRIPT" 2>&1; then
        pass "Script syntax is valid"
    else
        fail "Script has syntax errors"
    fi
}

# ── Test 3: No arguments shows usage ─────────────────────────────────────────
test_no_args() {
    echo -e "\n${YELLOW}Test 3: No arguments shows usage${NC}"
    local output
    output=$(bash "$CAPTURE_SCRIPT" 2>&1) && true
    if echo "$output" | grep -qi "usage"; then
        pass "No arguments shows usage message"
    else
        fail "Expected usage message, got: $output"
    fi
}

# ── Test 4: --help shows usage ───────────────────────────────────────────────
test_help_flag() {
    echo -e "\n${YELLOW}Test 4: --help shows usage${NC}"
    local output
    output=$(bash "$CAPTURE_SCRIPT" --help 2>&1) && true
    if echo "$output" | grep -qi "usage\|help"; then
        pass "--help shows usage message"
    else
        fail "Expected help message, got: $output"
    fi
}

# ── Test 5: Missing storyboard dir shows error ───────────────────────────────
test_missing_storyboard() {
    echo -e "\n${YELLOW}Test 5: Missing storyboard dir shows error${NC}"
    local tmpdir
    tmpdir=$(mktemp -d)
    # tmpdir exists but has no storyboard/ subdirectory
    local output
    output=$(bash "$CAPTURE_SCRIPT" "$tmpdir" 2>&1) && true
    if echo "$output" | grep -qi "storyboard dir not found\|ERROR"; then
        pass "Missing storyboard dir shows error"
    else
        fail "Expected storyboard dir error, got: $output"
    fi
    rm -rf "$tmpdir"
}

# ── Main test runner ─────────────────────────────────────────────────────────
main() {
    echo -e "${YELLOW}=== capture-screenshots.sh tests ===${NC}"

    test_script_exists
    test_syntax_check
    test_no_args
    test_help_flag
    test_missing_storyboard

    echo ""
    echo -e "${YELLOW}=== Test Summary ===${NC}"
    echo -e "  Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  Failed: ${RED}$TESTS_FAILED${NC}"

    if [ $TESTS_FAILED -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

main "$@"
