#!/bin/bash
set -euo pipefail

# merge-mp3.sh - Merge step-level MP3 files into chapter-level MP3 files
# Usage: ./merge-mp3.sh <workspace-directory>
#
# This script reads voice/audio-segments.json to get chapter structure,
# then merges step-level MP3 files from voice/public/audio/<chapter>/<step>.mp3
# into chapter-level MP3 files at voice/public/audio/<chapter>.mp3
#
# Uses FFmpeg concat demuxer for lossless merging (no re-encoding).

# Cleanup trap for temp files
TEMP_FILES=()
cleanup() { for f in "${TEMP_FILES[@]}"; do rm -f "$f"; done; }
trap cleanup EXIT

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Convert path to absolute format FFmpeg can use (Windows-native on MSYS2/Git Bash)
ffmpeg_path() {
    local abs_path
    abs_path=$(realpath "$1")
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -w "$abs_path"
    else
        echo "$abs_path"
    fi
}

# Main function
main() {
    # Check arguments
    if [ $# -lt 1 ]; then
        echo "Usage: $0 <workspace-directory>"
        echo ""
        echo "Merges step-level MP3 files into chapter-level MP3 files."
        echo ""
        echo "Example:"
        echo "  $0 workspace/rm-test-002"
        exit 1
    fi

    local workspace_dir="$1"

    # Validate workspace directory
    if [ ! -d "$workspace_dir" ]; then
        log_error "Workspace directory not found: $workspace_dir"
        exit 1
    fi

    # Validate audio-segments.json exists
    local segments_file="$workspace_dir/voice/audio-segments.json"
    if [ ! -f "$segments_file" ]; then
        log_error "audio-segments.json not found: $segments_file"
        exit 1
    fi

    # Check FFmpeg is installed
    if ! command -v ffmpeg >/dev/null 2>&1; then
        log_error "FFmpeg not installed. Please install FFmpeg first."
        exit 1
    fi

    log_info "Processing workspace: $workspace_dir"

    # Extract unique chapters sorted by chapterIndex
    local chapters
    chapters=$(grep -o '"chapter"[[:space:]]*:[[:space:]]*"[^"]*"\|"chapterIndex"[[:space:]]*:[[:space:]]*[0-9]*' "$segments_file" | \
               paste - - | \
               sed 's/[^"]*"chapter"[[:space:]]*:[[:space:]]*"\([^"]*\)"[^"]*"chapterIndex"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\2 \1/' | \
               sort -n | awk '{print $2}' | uniq)

    if [ -z "$chapters" ]; then
        log_warn "No chapters found in audio-segments.json"
        exit 0
    fi

    local merge_count=0

    # Process each chapter
    while IFS= read -r chapter; do
        log_info "Processing chapter: $chapter"

        local chapter_dir="$workspace_dir/voice/public/audio/$chapter"
        local output_file="$workspace_dir/voice/public/audio/${chapter}.mp3"

        if [ ! -d "$chapter_dir" ]; then
            log_warn "Chapter directory not found: $chapter_dir, skipping"
            continue
        fi

        # Find step-level MP3 files for this chapter
        local steps
        steps=$(grep -A3 "\"chapter\"[[:space:]]*:[[:space:]]*\"$chapter\"" "$segments_file" | \
                grep -o '"stepIndex"[[:space:]]*:[[:space:]]*[0-9]*' | \
                sed 's/.*"stepIndex"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/' | \
                sort -n)

        if [ -z "$steps" ]; then
            log_warn "No steps found for chapter: $chapter"
            continue
        fi

        # Build concat list file
        local concat_file
        concat_file=$(mktemp /tmp/merge-mp3-XXXXXX.txt)
        TEMP_FILES+=("$concat_file")
        local file_count=0

        while IFS= read -r step; do
            if [ -n "$step" ]; then
                local step_file="$chapter_dir/$(printf "%02d" $((step + 1))).mp3"
                if [ -f "$step_file" ]; then
                    local abs_path
                    abs_path=$(ffmpeg_path "$step_file")
                    # Single quotes required: FFmpeg concat demuxer treats backslashes
                    # as escape characters in double-quoted paths (breaks Windows paths)
                    echo "file '$abs_path'" >> "$concat_file"
                    file_count=$((file_count + 1))
                else
                    log_warn "Step file not found: $step_file, skipping"
                fi
            fi
        done <<< "$steps"

        if [ "$file_count" -eq 0 ]; then
            log_warn "No MP3 files found for chapter: $chapter"
            rm -f "$concat_file"
            continue
        fi

        # Merge using FFmpeg concat demuxer (lossless, no re-encoding)
        local output_path
        output_path=$(ffmpeg_path "$output_file")
        local ffmpeg_output
        if ffmpeg_output=$(ffmpeg -y -f concat -safe 0 -i "$concat_file" -c copy "$output_path" 2>&1); then
            log_info "Created: $output_file ($file_count steps)"
            merge_count=$((merge_count + 1))
        else
            log_error "FFmpeg failed to merge chapter $chapter: $ffmpeg_output"
        fi

        rm -f "$concat_file"

    done <<< "$chapters"

    log_info "MP3 merge completed: $merge_count chapters merged"
}

main "$@"
