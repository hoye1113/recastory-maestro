#!/bin/bash
# tools/render-video.sh
# Main render pipeline: merge audio, record screen via FFmpeg, burn subtitles, concatenate
# Usage: bash render-video.sh <workspace-dir>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/env-common.sh"

DEV_SERVER_PID=""
FFMPEG_PID=""
cleanup() {
    [ -n "$FFMPEG_PID" ] && kill -0 "$FFMPEG_PID" 2>/dev/null && kill "$FFMPEG_PID" 2>/dev/null
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
    if [ ! -f "$SCRIPT_DIR/puppeteer-launch.js" ]; then
        log_error "puppeteer-launch.js not found in $SCRIPT_DIR"
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

    # Detect environment once (resolution, DPI, platform)
    local env_raw env_capture_res
    env_raw=$(env_detect_resolution)
    env_parse_resolution "$env_raw"
    env_capture_res=$(env_pick_capture_resolution "capture")
    local platform
    platform=$(env_platform)
    log_info "Screen capture: $env_capture_res (logical: $ENV_LOGICAL_RES, physical: $ENV_PHYSICAL_RES, DPI: ${ENV_DPI_SCALE}x)"

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
        local chapter_srt="$audio_dir/${chapter}.srt"
        local chapter_raw="$output_dir/${chapter}-raw.mp4"
        local chapter_video="$output_dir/${chapter}.mp4"

        if [ ! -f "$chapter_mp3" ]; then
            log_warn "No MP3 for $chapter, skipping"
            continue
        fi

        # Get audio duration
        local audio_dur capture_dur
        audio_dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$chapter_mp3")
        capture_dur=$(awk "BEGIN{printf \"%.0f\", $audio_dur + 3}")

        # Platform-specific screen capture (resolution detected once before the loop)
        local screen_input
        local screen_res="$env_capture_res"
        case "$platform" in
            windows) screen_input=(-f gdigrab -framerate 30 -video_size "$screen_res" -i desktop) ;;
            darwin)  screen_input=(-f avfoundation -framerate 30 -i 1:0) ;;
            linux)   screen_input=(-f x11grab -framerate 30 -video_size "$screen_res" -i :0.0) ;;
        esac

        # Puppeteer opens browser + presses SPACE (must happen BEFORE FFmpeg captures)
        log_info "Launching browser for auto-play..."
        local viewport_file="$storyboard_dir/.viewport-dimensions.txt"
        rm -f "$viewport_file"
        node "$SCRIPT_DIR/puppeteer-launch.js" "http://127.0.0.1:${vite_port}/?auto=1&chapter=${chapter}" --headed &
        local puppeteer_pid=$!
        sleep 8  # Let browser open, go fullscreen, and come to foreground

        # Read actual browser viewport dimensions (written by puppeteer-launch.js)
        if [ -f "$viewport_file" ]; then
            local viewport_res
            viewport_res=$(cat "$viewport_file" | tr -d '[:space:]')
            if [[ "$viewport_res" =~ ^[0-9]+x[0-9]+$ ]]; then
                screen_res="$viewport_res"
                log_info "Using browser viewport dimensions: $screen_res"
            fi
            rm -f "$viewport_file"
        fi

        # Start FFmpeg recording (background) — browser should be in foreground now
        log_info "Starting screen capture (${capture_dur}s, ${screen_res})..."
        ffmpeg -y "${screen_input[@]}" -t "$capture_dur" -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p "$chapter_raw" &
        FFMPEG_PID=$!

        # Wait for FFmpeg to finish (capture duration elapsed)
        wait $FFMPEG_PID 2>/dev/null || { log_error "FFmpeg capture failed for $chapter"; FFMPEG_PID=""; continue; }
        FFMPEG_PID=""

        # Wait for puppeteer to finish (auto-play complete)
        wait $puppeteer_pid 2>/dev/null || log_warn "Puppeteer exited with error for $chapter"
        [ -f "$chapter_raw" ] || { log_error "Raw capture missing: $chapter_raw"; continue; }

        # Burn subtitles
        if [ -f "$chapter_srt" ]; then
            log_info "Burning subtitles..."
            # FFmpeg subtitles filter breaks on Windows absolute paths (colon in drive letter).
            # Workaround: copy SRT to render dir, use relative path from CWD (storyboard dir).
            local srt_copy="../render/_sub.srt"
            cp "$chapter_srt" "$output_dir/_sub.srt"
            ffmpeg -y -i "$chapter_raw" \
                -filter_complex "subtitles=filename=${srt_copy}:force_style='FontSize=18,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,Outline=2,MarginV=30'" \
                -c:v libx264 -preset medium -crf 18 -c:a copy "$chapter_video" 2>/dev/null
            rm -f "$chapter_raw" "$output_dir/_sub.srt"
        else
            mv "$chapter_raw" "$chapter_video"
        fi

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
