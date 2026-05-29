#!/bin/bash
# tools/verify-render.sh
# Extract screenshots from rendered video for content verification
# Usage: bash verify-render.sh <workspace-dir> [num-screenshots]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

main() {
    local workspace="${1:?Usage: verify-render.sh <workspace-dir> [num-screenshots]}"
    local num_screenshots="${2:-5}"
    local final_video="$workspace/render/final.mp4"
    local verify_dir="$workspace/render/verify"

    if [ ! -f "$final_video" ]; then
        log_error "Final video not found: $final_video"
        exit 1
    fi

    command -v ffmpeg >/dev/null 2>&1 || { log_error "FFmpeg not installed"; exit 1; }
    command -v ffprobe >/dev/null 2>&1 || { log_error "FFprobe not installed"; exit 1; }

    mkdir -p "$verify_dir"

    # Get video duration
    local duration
    duration=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$final_video")
    local duration_int=${duration%.*}

    log_info "Video duration: ${duration_int}s, extracting $num_screenshots screenshots"

    # Extract screenshots at evenly spaced intervals
    # Skip first 5s (intro) and last 5s (outro)
    local start_time=5
    local end_time=$((duration_int - 5))
    local interval=$(( (end_time - start_time) / (num_screenshots - 1) ))

    for i in $(seq 0 $((num_screenshots - 1))); do
        local timestamp=$((start_time + i * interval))
        local output_file="$verify_dir/screenshot-$(printf '%02d' $i)-${timestamp}s.jpg"

        ffmpeg -y -ss "$timestamp" -i "$final_video" -frames:v 1 -q:v 2 "$output_file" 2>/dev/null

        if [ -f "$output_file" ]; then
            log_info "Screenshot $i: ${timestamp}s -> $output_file"
        else
            log_warn "Failed to extract screenshot at ${timestamp}s"
        fi
    done

    log_info "Screenshots saved to: $verify_dir"
    log_info "Use mmx MCP to read and verify each screenshot"

    # List the screenshots
    ls -la "$verify_dir"/*.jpg 2>/dev/null || log_warn "No screenshots found"
}

main "$@"
