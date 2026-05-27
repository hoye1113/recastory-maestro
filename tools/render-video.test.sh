#!/bin/bash
set -euo pipefail

# Test script for render-video.sh
# Validates argument parsing, input validation, and script syntax.
# Does NOT test actual rendering (requires FFmpeg, Puppeteer, display).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$PROJECT_ROOT/.test-render-video"
RENDER_SCRIPT="$SCRIPT_DIR/render-video.sh"

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

# Test 1: Script exists and is readable
test_script_exists() {
    echo -e "\n${YELLOW}Test 1: Script exists${NC}"

    if [ -f "$RENDER_SCRIPT" ]; then
        echo -e "${GREEN}PASS${NC}: render-video.sh exists"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: render-video.sh not found at $RENDER_SCRIPT"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 2: Script syntax is valid (bash -n)
test_syntax_check() {
    echo -e "\n${YELLOW}Test 2: Script syntax check${NC}"

    if bash -n "$RENDER_SCRIPT" 2>&1; then
        echo -e "${GREEN}PASS${NC}: Script syntax is valid"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: Script has syntax errors"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 3: No arguments shows usage error
test_no_args() {
    echo -e "\n${YELLOW}Test 3: No arguments shows usage${NC}"

    local output
    output=$(bash "$RENDER_SCRIPT" 2>&1) && true

    if echo "$output" | grep -qi "usage\|Usage"; then
        echo -e "${GREEN}PASS${NC}: No arguments shows usage message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: Expected usage message, got: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 4: Non-existent directory errors
test_nonexistent_dir() {
    echo -e "\n${YELLOW}Test 4: Non-existent directory errors${NC}"

    local output
    output=$(bash "$RENDER_SCRIPT" "/nonexistent/path" 2>&1) && true

    if echo "$output" | grep -qi "not found\|ERROR"; then
        echo -e "${GREEN}PASS${NC}: Non-existent directory produces error"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: Expected error for non-existent dir, got: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 5: Missing storyboard directory errors
test_missing_storyboard() {
    echo -e "\n${YELLOW}Test 5: Missing storyboard directory${NC}"

    cleanup
    mkdir -p "$TEST_DIR/voice"
    echo '{"segments":[]}' > "$TEST_DIR/voice/audio-segments.json"

    local output
    output=$(bash "$RENDER_SCRIPT" "$TEST_DIR" 2>&1) && true

    if echo "$output" | grep -qi "storyboard.*not found\|ERROR"; then
        echo -e "${GREEN}PASS${NC}: Missing storyboard directory produces error"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: Expected storyboard error, got: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 6: Missing audio-segments.json errors
test_missing_segments() {
    echo -e "\n${YELLOW}Test 6: Missing audio-segments.json${NC}"

    cleanup
    mkdir -p "$TEST_DIR/storyboard"

    local output
    output=$(bash "$RENDER_SCRIPT" "$TEST_DIR" 2>&1) && true

    if echo "$output" | grep -qi "audio-segments.*not found\|ERROR"; then
        echo -e "${GREEN}PASS${NC}: Missing audio-segments.json produces error"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: Expected segments error, got: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Main test runner
main() {
    echo -e "${YELLOW}Running render-video.sh tests...${NC}"

    # Run tests
    test_script_exists
    test_syntax_check
    test_no_args
    test_nonexistent_dir
    test_missing_storyboard
    test_missing_segments

    # Summary
    echo -e "\n${YELLOW}Test Summary:${NC}"
    echo -e "  Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  Failed: ${RED}$TESTS_FAILED${NC}"

    # Cleanup
    cleanup

    # Exit with appropriate code
    if [ $TESTS_FAILED -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

main "$@"
