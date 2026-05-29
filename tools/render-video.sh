#!/bin/bash
# tools/render-video.sh
# Main render pipeline: merge audio, record via CDP screencast, concatenate
# Usage: bash render-video.sh <workspace-dir>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/env-common.sh"

DEV_SERVER_PID=""
cleanup() {
    [ -n "$DEV_SERVER_PID" ] && kill -0 "$DEV_SERVER_PID" 2>/dev/null && kill "$DEV_SERVER_PID" 2>/dev/null
}
trap cleanup EXIT

main() {
    local workspace="${1:?Usage: render-video.sh <workspace-dir>}"

    local storyboard_dir="$workspace/storyboard"
    local voice_dir="$workspace/voice"
    local segments_file="$voice_dir/audio-segments.json"
    local audio_dir="$voice_dir/public/audio"
    local output_dir="$workspace/render"
    local final_output="$output_dir/final.mp4"

    # Validate inputs
    if [ ! -d "$workspace" ]; then
        log_error "Workspace directory not found: $workspace"
        exit 1
    fi

    [ -d "$storyboard_dir" ] || { log_error "Storyboard directory not found: $storyboard_dir"; exit 1; }
    [ -f "$segments_file" ] || { log_error "audio-segments.json not found: $segments_file"; exit 1; }
    command -v ffmpeg >/dev/null 2>&1 || { log_error "FFmpeg not installed"; exit 1; }
    command -v ffprobe >/dev/null 2>&1 || { log_error "FFprobe not installed"; exit 1; }
    if [ ! -f "$SCRIPT_DIR/capture-chrome.js" ]; then
        log_error "capture-chrome.js not found in $SCRIPT_DIR"
        exit 1
    fi

    # Resolve to absolute paths (needed because we cd into storyboard_dir later)
    workspace="$(cd "$workspace" && pwd)"
    storyboard_dir="$workspace/storyboard"
    voice_dir="$workspace/voice"
    segments_file="$voice_dir/audio-segments.json"
    audio_dir="$voice_dir/public/audio"
    output_dir="$workspace/render"
    final_output="$output_dir/final.mp4"

    # Optional pre-flight check (can be skipped with SKIP_PREFLIGHT=true)
    if [ "${SKIP_PREFLIGHT:-false}" != "true" ]; then
        env_preflight_check || { log_error "Pre-flight check failed"; exit 1; }
    fi

    log_info "Starting render pipeline"
    mkdir -p "$output_dir"

    # Step 1: Merge MP3s
    log_info "Merging step MP3s..."
    bash "$SCRIPT_DIR/merge-mp3.sh" "$workspace"

    # Step 2: Start dev server
    log_info "Cleaning up old Vite servers..."
    pkill -f "vite" 2>/dev/null || true
    sleep 2

    log_info "Starting Vite dev server..."
    cd "$storyboard_dir"
    local vite_port=5173
    local vite_log
    vite_log=$(mktemp /tmp/vite-XXXXXX.log)
    npx vite --port "$vite_port" --host 127.0.0.1 > "$vite_log" 2>&1 &
    DEV_SERVER_PID=$!
    # Detect actual port from Vite output (it may pick another if 5173 is busy)
    for i in $(seq 1 30); do
        if grep -q "ready in" "$vite_log" 2>/dev/null; then
            local detected
            detected=$(grep -o 'http://127.0.0.1:[0-9]*' "$vite_log" | tail -1 | sed 's/.*://')
            if [ -n "$detected" ]; then
                vite_port="$detected"
                log_info "Detected Vite port: $vite_port"
            fi
            break
        fi
        sleep 1
    done
    rm -f "$vite_log"
    if ! curl -s "http://127.0.0.1:$vite_port" >/dev/null 2>&1; then
        log_error "Dev server failed to start within 30s"
        exit 1
    fi
    log_info "Dev server at http://127.0.0.1:$vite_port"

    # Step 3: Extract chapters (same approach as merge-mp3.sh)
    local chapters
    chapters=$(grep -o '"chapter"[[:space:]]*:[[:space:]]*"[^"]*"\|"chapterIndex"[[:space:]]*:[[:space:]]*[0-9]*' "$segments_file" | \
               paste - - | \
               sed 's/[^"]*"chapter"[[:space:]]*:[[:space:]]*"\([^"]*\)"[^"]*"chapterIndex"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\2 \1/' | \
               sort -n | awk '{print $2}' | uniq)

    if [ -z "$chapters" ]; then
        log_warn "No chapters found in audio-segments.json"
        exit 0
    fi

    # Limit chapters for test runs (MAX_CHAPTERS env var)
    local max_chapters="${MAX_CHAPTERS:-0}"
    if [ "$max_chapters" -gt 0 ] 2>/dev/null; then
        chapters=$(echo "$chapters" | head -n "$max_chapters")
        log_info "Test mode: limiting to $max_chapters chapters"
    fi

    local chapter_videos=()

    for chapter in $chapters; do
        log_info "Rendering chapter: $chapter"

        local chapter_mp3="$audio_dir/${chapter}.mp3"
        local chapter_video="$output_dir/${chapter}.mp4"

        if [ ! -f "$chapter_mp3" ]; then
            log_warn "No MP3 for $chapter, skipping"
            continue
        fi

        # CDP screencast recording via capture-chrome.js
        # Handles: browser launch, CDP screencast, ffprobe timing, frame encoding, audio muxing
        log_info "Recording chapter via CDP screencast..."
        if ! node "$SCRIPT_DIR/capture-chrome.js" "$workspace" \
            --chapter "$chapter" \
            --port "$vite_port" \
            --output "$chapter_video"; then
            log_error "capture-chrome.js failed for $chapter, skipping"
            continue
        fi

        [ -f "$chapter_video" ] || { log_error "Chapter video missing: $chapter_video"; continue; }

        log_info "Chapter video: $chapter_video"
        chapter_videos+=("$chapter_video")
    done

    # Concatenate chapter videos
    if [ ${#chapter_videos[@]} -gt 0 ]; then
        local concat_file="$output_dir/final-concat.txt"
        > "$concat_file"
        for vid in "${chapter_videos[@]}"; do
            local abs_vid
            abs_vid=$(ffmpeg_path "$vid")
            echo "file '$abs_vid'" >> "$concat_file"
        done
        ffmpeg -y -f concat -safe 0 -i "$concat_file" -c copy "$final_output" 2>/dev/null

        # Scale to 1920x1080 if captured resolution differs
        local final_res
        final_res=$(ffprobe -v quiet -show_entries stream=width,height -of csv=p=0:s=x "$final_output" 2>/dev/null | head -1)
        if [ "$final_res" != "1920x1080" ]; then
            log_info "Scaling from $final_res to 1920x1080..."
            local scaled_output="$output_dir/final-scaled.mp4"
            ffmpeg -y -i "$final_output" \
                -vf "scale=1920:1080:flags=lanczos" \
                -c:v libx264 -preset medium -crf 18 -c:a copy "$scaled_output" 2>/dev/null
            mv "$scaled_output" "$final_output"
            log_info "Scaled to 1920x1080"
        fi
        log_info "Final video: $final_output"
    fi

    # Generate manifest
    local actual_resolution
    actual_resolution=$(ffprobe -v quiet -show_entries stream=width,height -of csv=p=0:s=x "$final_output" 2>/dev/null | head -1 || echo "unknown")
    cat > "$workspace/manifest.json" <<MANIFEST_EOF
{
  "pipeline_id": "$(basename "$workspace")",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "output": { "video": "$final_output" },
  "duration_seconds": $(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$final_output" 2>/dev/null || echo "0"),
  "resolution": "$actual_resolution"
}
MANIFEST_EOF

    # Optional BGM mixing (controlled by ENABLE_BGM env var)
    if [ "${ENABLE_BGM:-false}" = "true" ]; then
        local bgm_prompt="${BGM_PROMPT:-}"
        local bgm_volume="${BGM_VOLUME:-0.2}"
        if [ -n "$bgm_prompt" ]; then
            bash "$SCRIPT_DIR/mix-bgm.sh" "$workspace" --prompt "$bgm_prompt" --volume "$bgm_volume" || log_warn "BGM mixing failed, continuing without BGM"
        else
            bash "$SCRIPT_DIR/mix-bgm.sh" "$workspace" --volume "$bgm_volume" || log_warn "BGM mixing failed, continuing without BGM"
        fi
    fi

    log_info "Render complete!"
}

main "$@"
