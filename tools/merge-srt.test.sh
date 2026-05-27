#!/bin/bash
set -euo pipefail

# Test script for merge-srt.sh
# Creates test data and validates merge logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$PROJECT_ROOT/.test-merge-srt"
MERGE_SCRIPT="$SCRIPT_DIR/merge-srt.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function
assert_file_content() {
    local test_name="$1"
    local expected="$2"
    local actual_file="$3"

    if [ ! -f "$actual_file" ]; then
        echo -e "${RED}FAIL${NC}: $test_name - File not found: $actual_file"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi

    local actual
    actual=$(cat "$actual_file")

    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}: $test_name"
        echo "  Expected:"
        echo "$expected" | sed 's/^/    /'
        echo "  Actual:"
        echo "$actual" | sed 's/^/    /'
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Cleanup
cleanup() {
    rm -rf "$TEST_DIR"
}

# Setup test data
setup_test_data() {
    cleanup
    mkdir -p "$TEST_DIR/voice/public/audio/01-chap"
    mkdir -p "$TEST_DIR/voice/public/audio/02-part"

    # Create audio-segments.json
    cat > "$TEST_DIR/voice/audio-segments.json" << 'EOF'
{
  "segments": [
    { "id": "01-chap-01", "chapter": "01-chap", "chapterIndex": 1, "stepIndex": 1, "text": "First step.", "audioPath": "voice/public/audio/01-chap/01.mp3" },
    { "id": "01-chap-02", "chapter": "01-chap", "chapterIndex": 1, "stepIndex": 2, "text": "Second step.", "audioPath": "voice/public/audio/01-chap/02.mp3" },
    { "id": "01-chap-03", "chapter": "01-chap", "chapterIndex": 1, "stepIndex": 3, "text": "Third step.", "audioPath": "voice/public/audio/01-chap/03.mp3" },
    { "id": "02-part-01", "chapter": "02-part", "chapterIndex": 2, "stepIndex": 1, "text": "Chapter 2 first.", "audioPath": "voice/public/audio/02-part/01.mp3" },
    { "id": "02-part-02", "chapter": "02-part", "chapterIndex": 2, "stepIndex": 2, "text": "Chapter 2 second.", "audioPath": "voice/public/audio/02-part/02.mp3" }
  ]
}
EOF

    # Create step-level SRT files for chapter 01
    mkdir -p "$TEST_DIR/voice/public/audio/01-chap"

    cat > "$TEST_DIR/voice/public/audio/01-chap/01.srt" << 'EOF'
1
00:00:00,000 --> 00:00:04,463
First step.
EOF

    cat > "$TEST_DIR/voice/public/audio/01-chap/02.srt" << 'EOF'
1
00:00:00,000 --> 00:00:04,370
Second step.
EOF

    cat > "$TEST_DIR/voice/public/audio/01-chap/03.srt" << 'EOF'
1
00:00:00,000 --> 00:00:05,868
Third step.
EOF

    # Create step-level SRT files for chapter 02
    mkdir -p "$TEST_DIR/voice/public/audio/02-part"

    cat > "$TEST_DIR/voice/public/audio/02-part/01.srt" << 'EOF'
1
00:00:00,000 --> 00:00:05,148
Chapter 2 first.
EOF

    cat > "$TEST_DIR/voice/public/audio/02-part/02.srt" << 'EOF'
1
00:00:00,000 --> 00:00:03,200
Chapter 2 second.
EOF
}

# Test 1: Basic merge with 3 steps
test_basic_merge() {
    echo -e "\n${YELLOW}Test 1: Basic merge with 3 steps${NC}"
    setup_test_data

    # Run merge script
    bash "$MERGE_SCRIPT" "$TEST_DIR"

    # Expected output for chapter 01
    read -r -d '' expected << 'EOF' || true
1
00:00:00,000 --> 00:00:04,463
First step.

2
00:00:04,463 --> 00:00:08,833
Second step.

3
00:00:08,833 --> 00:00:14,701
Third step.

EOF

    assert_file_content "Chapter 01 merge" "$expected" "$TEST_DIR/voice/public/audio/01-chap.srt"
}

# Test 2: Second chapter merge
test_second_chapter() {
    echo -e "\n${YELLOW}Test 2: Second chapter merge${NC}"

    # Expected output for chapter 02
    read -r -d '' expected << 'EOF' || true
1
00:00:00,000 --> 00:00:05,148
Chapter 2 first.

2
00:00:05,148 --> 00:00:08,348
Chapter 2 second.

EOF

    assert_file_content "Chapter 02 merge" "$expected" "$TEST_DIR/voice/public/audio/02-part.srt"
}

# Test 3: Handles missing SRT files gracefully
test_missing_srt_files() {
    echo -e "\n${YELLOW}Test 3: Missing SRT files${NC}"

    # Create a chapter with missing SRT
    cat > "$TEST_DIR/voice/audio-segments.json" << 'EOF'
{
  "segments": [
    { "id": "01-chap-01", "chapter": "01-chap", "chapterIndex": 1, "stepIndex": 1, "text": "Only step.", "audioPath": "voice/public/audio/01-chap/01.mp3" }
  ]
}
EOF

    # Remove the SRT file
    rm -f "$TEST_DIR/voice/public/audio/01-chap/01.srt"

    # Run merge script - should fail with error
    if bash "$MERGE_SCRIPT" "$TEST_DIR" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -q "WARN.*SRT file not found"; then
        echo -e "${GREEN}PASS${NC}: Missing SRT file warning"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: Missing SRT file warning - expected warn message"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 4: Handles multi-line SRT entries
test_multiline_srt() {
    echo -e "\n${YELLOW}Test 4: Multi-line SRT entries${NC}"

    # Create SRT with multiple text lines
    cat > "$TEST_DIR/voice/public/audio/01-chap/01.srt" << 'EOF'
1
00:00:00,000 --> 00:00:04,463
First line of text.
Second line of text.

2
00:00:04,463 --> 00:00:08,000
Another entry.

EOF

    # Update audio-segments.json to have just one step
    cat > "$TEST_DIR/voice/audio-segments.json" << 'EOF'
{
  "segments": [
    { "id": "01-chap-01", "chapter": "01-chap", "chapterIndex": 1, "stepIndex": 1, "text": "Test.", "audioPath": "voice/public/audio/01-chap/01.mp3" }
  ]
}
EOF

    # Run merge script
    bash "$MERGE_SCRIPT" "$TEST_DIR"

    # Verify the output preserves multiple entries
    if grep -q "First line of text." "$TEST_DIR/voice/public/audio/01-chap.srt" && \
       grep -q "Second line of text." "$TEST_DIR/voice/public/audio/01-chap.srt" && \
       grep -q "Another entry." "$TEST_DIR/voice/public/audio/01-chap.srt"; then
        echo -e "${GREEN}PASS${NC}: Multi-line SRT preserved"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: Multi-line SRT not preserved"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 5: Validates against real data
test_real_data() {
    echo -e "\n${YELLOW}Test 5: Validate against real data${NC}"

    local real_workspace="$PROJECT_ROOT/workspace/rm-test-002"

    if [ ! -d "$real_workspace" ]; then
        echo -e "${YELLOW}SKIP${NC}: Real workspace not found"
        return 0
    fi

    # Backup existing merged files
    local backup_dir="$PROJECT_ROOT/.backup-merge-srt"
    mkdir -p "$backup_dir"

    # Add trap for cleanup on failure
    trap 'for f in "'"$backup_dir"'"/*.srt; do [ -f "$f" ] && cp "$f" "'"$real_workspace"'/voice/public/audio/$(basename "$f")"; done; rm -rf "'"$backup_dir"'"' EXIT

    for srt in "$real_workspace"/voice/public/audio/*.srt; do
        if [ -f "$srt" ]; then
            cp "$srt" "$backup_dir/$(basename "$srt")"
            rm "$srt"
        fi
    done

    # Run merge on real data
    bash "$MERGE_SCRIPT" "$real_workspace"

    # Compare with backup
    for srt in "$backup_dir"/*.srt; do
        local name=$(basename "$srt")
        local expected=$(cat "$srt")
        local actual=$(cat "$real_workspace/voice/public/audio/$name")

        if [ "$expected" = "$actual" ]; then
            echo -e "${GREEN}PASS${NC}: Real data - $name"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}FAIL${NC}: Real data - $name"
            echo "  Expected:"
            echo "$expected" | sed 's/^/    /'
            echo "  Actual:"
            echo "$actual" | sed 's/^/    /'
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    done

    # Restore backups
    for srt in "$backup_dir"/*.srt; do
        local name=$(basename "$srt")
        cp "$srt" "$real_workspace/voice/public/audio/$name"
    done

    # Remove the trap and clean up
    trap - EXIT
    rm -rf "$backup_dir"
}

# Test 6: Argument validation
test_argument_validation() {
    echo -e "\n${YELLOW}Test 6: Argument validation${NC}"

    # Test with no arguments
    if (set +o pipefail; bash "$MERGE_SCRIPT" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -q "Usage"); then
        echo -e "${GREEN}PASS${NC}: No arguments shows usage"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: No arguments should show usage"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    # Test with non-existent directory
    if (set +o pipefail; bash "$MERGE_SCRIPT" "/nonexistent/path" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -q "ERROR.*not found"); then
        echo -e "${GREEN}PASS${NC}: Non-existent directory error"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: Non-existent directory should error"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Main test runner
main() {
    echo -e "${YELLOW}Running merge-srt.sh tests...${NC}"

    # Check if merge script exists
    if [ ! -f "$MERGE_SCRIPT" ]; then
        echo -e "${RED}ERROR${NC}: merge-srt.sh not found at $MERGE_SCRIPT"
        echo "Please create the script first."
        exit 1
    fi

    # Run tests
    test_argument_validation
    test_basic_merge
    test_second_chapter
    test_missing_srt_files
    test_multiline_srt
    test_real_data

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
