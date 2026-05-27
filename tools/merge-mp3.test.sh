#!/bin/bash
set -euo pipefail

# Test script for merge-mp3.sh
# Creates test data with real MP3 files and validates merge logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$PROJECT_ROOT/.test-merge-mp3"
MERGE_SCRIPT="$SCRIPT_DIR/merge-mp3.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper: get MP3 duration in seconds (float)
get_duration() {
    ffprobe -v error -show_entries format=duration -of csv=p=0 "$1" 2>/dev/null
}

# Cleanup
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Generate a silent MP3 of given duration (seconds) using FFmpeg
generate_silent_mp3() {
    local output="$1"
    local duration="$2"
    ffmpeg -y -f lavfi -i "anullsrc=r=44100:cl=mono" -t "$duration" -codec:a libmp3lame -q:a 9 "$output" 2>/dev/null
}

# Setup test data: 2 chapters, each with multiple steps
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

    # Generate silent MP3 files with known durations
    generate_silent_mp3 "$TEST_DIR/voice/public/audio/01-chap/01.mp3" 2.0
    generate_silent_mp3 "$TEST_DIR/voice/public/audio/01-chap/02.mp3" 3.0
    generate_silent_mp3 "$TEST_DIR/voice/public/audio/01-chap/03.mp3" 1.5

    generate_silent_mp3 "$TEST_DIR/voice/public/audio/02-part/01.mp3" 4.0
    generate_silent_mp3 "$TEST_DIR/voice/public/audio/02-part/02.mp3" 2.5
}

# Test 1: Argument validation - no args
test_no_args() {
    echo -e "\n${YELLOW}Test 1: No arguments shows usage${NC}"

    if (set +o pipefail; bash "$MERGE_SCRIPT" 2>&1 | grep -q "Usage"); then
        echo -e "${GREEN}PASS${NC}: No arguments shows usage"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: No arguments should show usage"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 2: Argument validation - non-existent directory
test_nonexistent_dir() {
    echo -e "\n${YELLOW}Test 2: Non-existent directory errors${NC}"

    if (set +o pipefail; bash "$MERGE_SCRIPT" "/nonexistent/path" 2>&1 | grep -q "ERROR.*not found"); then
        echo -e "${GREEN}PASS${NC}: Non-existent directory error"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: Non-existent directory should error"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 3: Missing audio-segments.json
test_missing_segments() {
    echo -e "\n${YELLOW}Test 3: Missing audio-segments.json${NC}"

    local no_seg_dir="$TEST_DIR/no-segments"
    mkdir -p "$no_seg_dir/voice"

    if (set +o pipefail; bash "$MERGE_SCRIPT" "$no_seg_dir" 2>&1 | grep -q "ERROR.*not found"); then
        echo -e "${GREEN}PASS${NC}: Missing segments file error"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: Missing segments file should error"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    rm -rf "$no_seg_dir"
}

# Test 4: Basic merge - chapter 01 (3 steps)
test_basic_merge_chapter01() {
    echo -e "\n${YELLOW}Test 4: Basic merge - chapter 01 (3 steps)${NC}"
    setup_test_data

    bash "$MERGE_SCRIPT" "$TEST_DIR"

    local output="$TEST_DIR/voice/public/audio/01-chap.mp3"
    if [ ! -f "$output" ]; then
        echo -e "${RED}FAIL${NC}: Output file not created: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return
    fi

    # Expected duration: 2.0 + 3.0 + 1.5 = 6.5 seconds (allow some tolerance for MP3 frame alignment)
    local duration
    duration=$(get_duration "$output")
    local expected=6.5

    if awk "BEGIN { d = $duration - $expected; if (d < 0) d = -d; exit (d > 0.5) }"; then
        echo -e "${GREEN}PASS${NC}: Chapter 01 merged, duration=${duration}s (expected ~${expected}s)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: Chapter 01 duration mismatch, got ${duration}s expected ~${expected}s"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 5: Basic merge - chapter 02 (2 steps)
test_basic_merge_chapter02() {
    echo -e "\n${YELLOW}Test 5: Basic merge - chapter 02 (2 steps)${NC}"

    local output="$TEST_DIR/voice/public/audio/02-part.mp3"
    if [ ! -f "$output" ]; then
        echo -e "${RED}FAIL${NC}: Output file not created: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return
    fi

    # Expected duration: 4.0 + 2.5 = 6.5 seconds
    local duration
    duration=$(get_duration "$output")
    local expected=6.5

    if awk "BEGIN { d = $duration - $expected; if (d < 0) d = -d; exit (d > 0.5) }"; then
        echo -e "${GREEN}PASS${NC}: Chapter 02 merged, duration=${duration}s (expected ~${expected}s)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: Chapter 02 duration mismatch, got ${duration}s expected ~${expected}s"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test 6: Missing step MP3 files (graceful handling)
test_missing_step_files() {
    echo -e "\n${YELLOW}Test 6: Missing step MP3 files${NC}"

    # Create workspace with a step that has no MP3 file
    local missing_dir="$TEST_DIR/missing-steps"
    mkdir -p "$missing_dir/voice/public/audio/01-chap"

    cat > "$missing_dir/voice/audio-segments.json" << 'EOF'
{
  "segments": [
    { "id": "01-chap-01", "chapter": "01-chap", "chapterIndex": 1, "stepIndex": 1, "text": "Exists.", "audioPath": "voice/public/audio/01-chap/01.mp3" },
    { "id": "01-chap-02", "chapter": "01-chap", "chapterIndex": 1, "stepIndex": 2, "text": "Missing.", "audioPath": "voice/public/audio/01-chap/02.mp3" }
  ]
}
EOF

    # Only create step 01, step 02 is missing
    generate_silent_mp3 "$missing_dir/voice/public/audio/01-chap/01.mp3" 2.0

    # Should still succeed (merges available files, warns about missing)
    local output
    output=$(bash "$MERGE_SCRIPT" "$missing_dir" 2>&1)

    if echo "$output" | grep -q "WARN.*not found"; then
        echo -e "${GREEN}PASS${NC}: Warns about missing step file"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: Should warn about missing step file"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    # Output should still be created with the available file
    if [ -f "$missing_dir/voice/public/audio/01-chap.mp3" ]; then
        echo -e "${GREEN}PASS${NC}: Output created despite missing step"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAIL${NC}: Output should be created even with partial steps"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    rm -rf "$missing_dir"
}

# Test 7: Validate against real data (workspace/rm-test-002)
test_real_data() {
    echo -e "\n${YELLOW}Test 7: Validate against real data${NC}"

    local real_workspace="$PROJECT_ROOT/workspace/rm-test-002"

    if [ ! -d "$real_workspace" ]; then
        echo -e "${YELLOW}SKIP${NC}: Real workspace not found"
        return 0
    fi

    if [ ! -f "$real_workspace/voice/audio-segments.json" ]; then
        echo -e "${YELLOW}SKIP${NC}: Real audio-segments.json not found"
        return 0
    fi

    # Backup existing merged MP3 files
    local backup_dir="$PROJECT_ROOT/.backup-merge-mp3"
    mkdir -p "$backup_dir"

    for mp3 in "$real_workspace"/voice/public/audio/*.mp3; do
        if [ -f "$mp3" ]; then
            cp "$mp3" "$backup_dir/$(basename "$mp3")"
            rm "$mp3"
        fi
    done

    # Run merge on real data
    bash "$MERGE_SCRIPT" "$real_workspace"

    # Verify each expected chapter MP3 exists
    local chapters=("01-what" "02-why" "03-how")
    local all_pass=true

    for chapter in "${chapters[@]}"; do
        local output="$real_workspace/voice/public/audio/${chapter}.mp3"
        if [ -f "$output" ]; then
            local duration
            duration=$(get_duration "$output")
            echo -e "${GREEN}PASS${NC}: Real data - ${chapter}.mp3 created (duration=${duration}s)"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}FAIL${NC}: Real data - ${chapter}.mp3 not created"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            all_pass=false
        fi
    done

    # Restore backups
    for mp3 in "$backup_dir"/*.mp3; do
        if [ -f "$mp3" ]; then
            cp "$mp3" "$real_workspace/voice/public/audio/$(basename "$mp3")"
        fi
    done

    rm -rf "$backup_dir"
}

# Main test runner
main() {
    echo -e "${YELLOW}Running merge-mp3.sh tests...${NC}"

    # Check if merge script exists
    if [ ! -f "$MERGE_SCRIPT" ]; then
        echo -e "${RED}ERROR${NC}: merge-mp3.sh not found at $MERGE_SCRIPT"
        echo "Please create the script first."
        exit 1
    fi

    # Check FFmpeg is available
    if ! command -v ffmpeg >/dev/null 2>&1; then
        echo -e "${RED}ERROR${NC}: FFmpeg not installed. Tests require FFmpeg."
        exit 1
    fi

    # Run tests
    test_no_args
    test_nonexistent_dir
    test_missing_segments
    test_basic_merge_chapter01
    test_basic_merge_chapter02
    test_missing_step_files
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
