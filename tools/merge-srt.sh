#!/bin/bash
set -euo pipefail

# merge-srt.sh - Merge step-level SRT files into chapter-level SRT files
# Usage: ./merge-srt.sh <workspace-directory>
#
# This script reads voice/audio-segments.json to get chapter structure,
# then merges step-level SRT files from voice/public/audio/<chapter>/<step>.srt
# into chapter-level SRT files at voice/public/audio/<chapter>.srt
#
# Cumulative offset logic: each step's timestamps get shifted by the
# accumulated duration of all previous steps.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Convert HH:MM:SS,mmm to milliseconds
SRT_TO_MS() {
    local timestamp="$1"
    local hours minutes seconds millis

    # Parse HH:MM:SS,mmm
    IFS=':,' read -r hours minutes seconds millis <<< "$timestamp"

    # Remove leading zeros to avoid octal interpretation
    hours=$((10#$hours))
    minutes=$((10#$minutes))
    seconds=$((10#$seconds))
    millis=$((10#$millis))

    # Calculate total milliseconds
    echo $(( hours * 3600000 + minutes * 60000 + seconds * 1000 + millis ))
}

# Convert milliseconds to HH:MM:SS,mmm format
MS_TO_SRT() {
    local ms="$1"

    # Ensure non-negative
    if [ "$ms" -lt 0 ]; then
        ms=0
    fi

    local hours=$(( ms / 3600000 ))
    local remainder=$(( ms % 3600000 ))
    local minutes=$(( remainder / 60000 ))
    remainder=$(( remainder % 60000 ))
    local seconds=$(( remainder / 1000 ))
    local millis=$(( remainder % 1000 ))

    # Format with leading zeros
    printf "%02d:%02d:%02d,%03d" "$hours" "$minutes" "$seconds" "$millis"
}

# Shift a timestamp by given offset in milliseconds
SHIFT_TIMESTAMP() {
    local timestamp="$1"
    local offset_ms="$2"

    local ms
    ms=$(SRT_TO_MS "$timestamp")
    ms=$(( ms + offset_ms ))

    MS_TO_SRT "$ms"
}

# Process SRT file and write entries to output file
process_srt_file() {
    local srt_file="$1"
    local output_file="$2"
    local cumulative_offset="$3"
    local seq_num="$4"

    local in_block=0
    local current_timestamp=""
    local current_text=""

    while IFS= read -r line || [ -n "$line" ]; do
        # Empty lines mark end of block
        if [ -z "$line" ]; then
            if [ $in_block -eq 1 ] && [ -n "$current_timestamp" ]; then
                if [[ "$current_timestamp" =~ ^([0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3})\ --\>\ ([0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3})$ ]]; then
                    local start_ts="${BASH_REMATCH[1]}"
                    local end_ts="${BASH_REMATCH[2]}"

                    local new_start
                    local new_end
                    new_start=$(SHIFT_TIMESTAMP "$start_ts" "$cumulative_offset")
                    new_end=$(SHIFT_TIMESTAMP "$end_ts" "$cumulative_offset")

                    printf "%d\n%s --> %s\n%s\n\n" "$seq_num" "$new_start" "$new_end" "$current_text" >> "$output_file"
                    seq_num=$((seq_num + 1))
                fi

                in_block=0
                current_timestamp=""
                current_text=""
            fi
            continue
        fi

        # Check if this is a sequence number (only digits)
        if [[ "$line" =~ ^[0-9]+$ ]]; then
            # Flush any pending block first
            if [ $in_block -eq 1 ] && [ -n "$current_timestamp" ]; then
                if [[ "$current_timestamp" =~ ^([0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3})\ --\>\ ([0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3})$ ]]; then
                    local start_ts="${BASH_REMATCH[1]}"
                    local end_ts="${BASH_REMATCH[2]}"

                    local new_start
                    local new_end
                    new_start=$(SHIFT_TIMESTAMP "$start_ts" "$cumulative_offset")
                    new_end=$(SHIFT_TIMESTAMP "$end_ts" "$cumulative_offset")

                    printf "%d\n%s --> %s\n%s\n\n" "$seq_num" "$new_start" "$new_end" "$current_text" >> "$output_file"
                    seq_num=$((seq_num + 1))
                fi

                in_block=0
                current_timestamp=""
                current_text=""
            fi
            in_block=1
            continue
        fi

        # Check if this is a timestamp line
        if [[ "$line" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3}\ --\>\ [0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3}$ ]]; then
            current_timestamp="$line"
            continue
        fi

        # Otherwise, it's a text line
        if [ -n "$current_text" ]; then
            current_text="${current_text}
${line}"
        else
            current_text="$line"
        fi
    done < "$srt_file"

    # Handle last block if file doesn't end with empty line
    if [ $in_block -eq 1 ] && [ -n "$current_timestamp" ]; then
        if [[ "$current_timestamp" =~ ^([0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3})\ --\>\ ([0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3})$ ]]; then
            local start_ts="${BASH_REMATCH[1]}"
            local end_ts="${BASH_REMATCH[2]}"

            local new_start
            local new_end
            new_start=$(SHIFT_TIMESTAMP "$start_ts" "$cumulative_offset")
            new_end=$(SHIFT_TIMESTAMP "$end_ts" "$cumulative_offset")

            printf "%d\n%s --> %s\n%s\n\n" "$seq_num" "$new_start" "$new_end" "$current_text" >> "$output_file"
            seq_num=$((seq_num + 1))
        fi
    fi

    # Return the new sequence number
    echo "$seq_num"
}

# Get the end timestamp (in ms) from the last entry of an SRT file
get_last_end_timestamp_ms() {
    local srt_file="$1"
    local last_timestamp=""
    local in_timestamp=0

    while IFS= read -r line || [ -n "$line" ]; do
        # Check if this is a timestamp line
        if [[ "$line" =~ ^([0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3})\ --\>\ ([0-9]{2}:[0-9]{2}:[0-9]{2},[0-9]{3})$ ]]; then
            last_timestamp="${BASH_REMATCH[2]}"
        fi
    done < "$srt_file"

    if [ -z "$last_timestamp" ]; then
        echo "0"
    else
        SRT_TO_MS "$last_timestamp"
    fi
}

# Merge SRT files for a chapter
merge_chapter_srt() {
    local chapter_dir="$1"
    local output_file="$2"
    local step_files=("$@")
    step_files=("${step_files[@]:2}") # Remove first two args

    local cumulative_offset=0
    local seq_num=1

    # Create/clear the output file
    > "$output_file"

    for srt_file in "${step_files[@]}"; do
        if [ ! -f "$srt_file" ]; then
            log_warn "SRT file not found: $srt_file, skipping"
            continue
        fi

        # Process the SRT file and write to output
        local result
        result=$(process_srt_file "$srt_file" "$output_file" "$cumulative_offset" "$seq_num")

        # Update sequence number
        seq_num=$result

        # Update cumulative offset for next step
        local last_end_ms
        last_end_ms=$(get_last_end_timestamp_ms "$srt_file")
        cumulative_offset=$((cumulative_offset + last_end_ms))
    done
}

# Main function
main() {
    # Check arguments
    if [ $# -lt 1 ]; then
        echo "Usage: $0 <workspace-directory>"
        echo ""
        echo "Merges step-level SRT files into chapter-level SRT files."
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

    log_info "Processing workspace: $workspace_dir"

    # Extract unique chapters sorted by chapterIndex
    local chapters
    chapters=$(grep -o '"chapter"[[:space:]]*:[[:space:]]*"[^"]*"\|"chapterIndex"[[:space:]]*:[[:space:]]*[0-9]*' "$segments_file" | \
               paste - - | \
               sed 's/.*"chapter"[[:space:]]*:[[:space:]]*"\([^"]*\)".*"chapterIndex"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\2 \1/' | \
               sort -n | awk '{print $2}' | uniq)

    if [ -z "$chapters" ]; then
        log_warn "No chapters found in audio-segments.json"
        exit 0
    fi

    # Process each chapter
    while IFS= read -r chapter; do
        log_info "Processing chapter: $chapter"

        local chapter_dir="$workspace_dir/voice/public/audio/$chapter"
        local output_file="$workspace_dir/voice/public/audio/${chapter}.srt"

        # Find step-level SRT files for this chapter
        local step_files=()
        local steps
        # Extract stepIndex values for this chapter from JSON
        # Each segment is on one line, so we can grep for lines containing both chapter and stepIndex
        steps=$(grep "\"chapter\"[[:space:]]*:[[:space:]]*\"$chapter\"" "$segments_file" | \
                grep -o '"stepIndex"[[:space:]]*:[[:space:]]*[0-9]*' | \
                sed 's/.*"stepIndex"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/' | \
                sort -n)

        while IFS= read -r step; do
            if [ -n "$step" ]; then
                local step_file="$chapter_dir/$(printf "%02d" "$step").srt"
                step_files+=("$step_file")
            fi
        done <<< "$steps"

        if [ ${#step_files[@]} -eq 0 ]; then
            log_warn "No step files found for chapter: $chapter"
            continue
        fi

        # Merge SRT files
        merge_chapter_srt "$chapter_dir" "$output_file" "${step_files[@]}"

        log_info "Created: $output_file"

    done <<< "$chapters"

    log_info "SRT merge completed successfully"
}

main "$@"
