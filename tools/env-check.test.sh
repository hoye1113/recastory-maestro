#!/bin/bash
set -euo pipefail

# Test script for env-check.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_CHECK="$SCRIPT_DIR/env-check.sh"
ENV_COMMON="$SCRIPT_DIR/lib/env-common.sh"
TEST_DIR="$PROJECT_ROOT/.test-env-check"

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
TESTS_PASSED=0
TESTS_FAILED=0

cleanup() { rm -rf "$TEST_DIR"; }
trap cleanup EXIT

pass() { TESTS_PASSED=$((TESTS_PASSED + 1)); echo -e "${GREEN}PASS${NC}: $1"; }
fail() { TESTS_FAILED=$((TESTS_FAILED + 1)); echo -e "${RED}FAIL${NC}: $1"; }

assert_exit_zero() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc (expected exit 0)"; fi
}

assert_contains() {
    local desc="$1" haystack="$2" needle="$3"
    if echo "$haystack" | grep -q "$needle"; then pass "$desc"; else fail "$desc (missing: $needle)"; fi
}

assert_file_exists() {
    local desc="$1" file="$2"
    if [ -f "$file" ]; then pass "$desc"; else fail "$desc (file not found: $file)"; fi
}

assert_json_field() {
    local desc="$1" json="$2" field="$3"
    if echo "$json" | grep -q "\"$field\""; then pass "$desc"; else fail "$desc (missing JSON field: $field)"; fi
}

assert_regex() {
    local desc="$1" text="$2" pattern="$3"
    if echo "$text" | grep -qP "$pattern" 2>/dev/null || echo "$text" | grep -qE "$pattern"; then
        pass "$desc"
    else
        fail "$desc (pattern not matched: $pattern)"
    fi
}

# --- Tests ---

test_script_exists() {
    assert_file_exists "env-check.sh exists" "$ENV_CHECK"
}

test_lib_exists() {
    assert_file_exists "env-common.sh exists" "$ENV_COMMON"
}

test_syntax_check() {
    assert_exit_zero "env-check.sh syntax" bash -n "$ENV_CHECK"
}

test_lib_syntax_check() {
    assert_exit_zero "env-common.sh syntax" bash -n "$ENV_COMMON"
}

test_no_args_produces_json() {
    local output
    output=$(bash "$ENV_CHECK" --quiet 2>/dev/null) || true
    assert_json_field "JSON has platform field" "$output" "platform"
    assert_json_field "JSON has resolution field" "$output" "resolution"
    assert_json_field "JSON has browser field" "$output" "browser"
    assert_json_field "JSON has dependencies field" "$output" "dependencies"
    assert_json_field "JSON has preflight field" "$output" "preflight"
}

test_output_flag() {
    mkdir -p "$TEST_DIR"
    local outfile="$TEST_DIR/test-report.json"
    bash "$ENV_CHECK" --output "$outfile" --quiet 2>/dev/null || true
    assert_file_exists "--output writes file" "$outfile"
    if [ -f "$outfile" ]; then
        local content
        content=$(cat "$outfile")
        assert_json_field "output file has platform" "$content" "platform"
    fi
}

test_resolution_format() {
    local output
    output=$(bash "$ENV_CHECK" --quiet 2>/dev/null) || true
    # Extract logical resolution value
    local logical
    logical=$(echo "$output" | grep '"logical"' | grep -oE '[0-9]+x[0-9]+')
    assert_regex "resolution matches NNNNxNNNN" "$logical" '^[0-9]+x[0-9]+$'
}

test_exit_code_success() {
    assert_exit_zero "exits 0 when deps present" bash "$ENV_CHECK" --quiet
}

test_lib_sourcing() {
    assert_exit_zero "env-common.sh can be sourced" bash -c "source '$ENV_COMMON' && env_platform"
}

test_env_platform() {
    local result
    result=$(bash -c "source '$ENV_COMMON' && env_platform")
    assert_regex "env_platform returns valid value" "$result" '^(windows|linux|darwin)$'
}

test_env_detect_resolution() {
    local result
    result=$(bash -c "source '$ENV_COMMON' && env_detect_resolution" 2>/dev/null) || true
    assert_regex "env_detect_resolution returns pipe-delimited" "$result" '^[0-9]+x[0-9]+\|[0-9]+x[0-9]+\|[0-9.]+$'
}

test_env_detect_browser() {
    local result
    result=$(bash -c "source '$ENV_COMMON' && env_detect_browser" 2>/dev/null) && \
        assert_regex "env_detect_browser returns a path" "$result" '.' || \
        pass "env_detect_browser returns path or fails gracefully"
}

test_env_preflight_check() {
    assert_exit_zero "env_preflight_check passes" bash -c "source '$ENV_COMMON' && env_preflight_check"
}

# --- Main ---

main() {
    echo "=== env-check.sh Tests ==="

    test_script_exists
    test_lib_exists
    test_syntax_check
    test_lib_syntax_check
    test_no_args_produces_json
    test_output_flag
    test_resolution_format
    test_exit_code_success
    test_lib_sourcing
    test_env_platform
    test_env_detect_resolution
    test_env_detect_browser
    test_env_preflight_check

    echo ""
    echo "=== Results: $TESTS_PASSED passed, $TESTS_FAILED failed ==="
    [ "$TESTS_FAILED" -eq 0 ] && exit 0 || exit 1
}

main "$@"
