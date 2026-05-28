#!/bin/bash
# tools/render-video.sh
# Main render pipeline: merge audio, record screen via FFmpeg, burn subtitles, concatenate
# Usage: bash render-video.sh <workspace-dir>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

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

    log_info "Starting render pipeline"
    mkdir -p "$output_dir"

    # Step 1: Merge MP3s
    log_info "Merging step MP3s..."
    bash "$SCRIPT_DIR/merge-mp3.sh" "$workspace"

    # Step 2: Start dev server
    log_info "Starting Vite dev server..."
    cd "$storyboard_dir"
    npx vite --port 5173 --host 127.0.0.1 &
    DEV_SERVER_PID=$!
    for i in $(seq 1 30); do curl -s "http://127.0.0.1:5173" >/dev/null 2>&1 && break; sleep 1; done
    if ! curl -s "http://127.0.0.1:5173" >/dev/null 2>&1; then
        log_error "Dev server failed to start within 30s"
        exit 1
    fi
    log_info "Dev server at http://127.0.0.1:5173"

    # Step 3: Extract chapters (same approach as merge-mp3.sh)
    local chapters
    chapters=$(grep -o '"chapter"[[:space:]]*:[[:space:]]*"[^"]*"\|"chapterIndex"[[:space:]]*:[[:space:]]*[0-9]*' "$segments_file" | \
               paste - - | \
               sed 's/.*"chapter"[[:space:]]*:[[:space:]]*"\([^"]*\)".*"chapterIndex"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\2 \1/' | \
               sort -n | awk '{print $2}' | uniq)

    if [ -z "$chapters" ]; then
        log_warn "No chapters found in audio-segments.json"
        exit 0
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

        # Platform-specific screen capture
        local screen_input
        case "$(uname -s)" in
            MINGW*|MSYS*|CYGWIN*|Windows*) screen_input=(-f gdigrab -framerate 30 -video_size 1920x1080 -i desktop) ;;
            Darwin*) screen_input=(-f avfoundation -framerate 30 -i 1:0) ;;
            *) screen_input=(-f x11grab -framerate 30 -video_size 1920x1080 -i :0.0) ;;
        esac

        # Start FFmpeg recording (background)
        log_info "Starting screen capture (${capture_dur}s)..."
        ffmpeg -y "${screen_input[@]}" -t "$capture_dur" -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p "$chapter_raw" &
        FFMPEG_PID=$!
        sleep 1  # Let FFmpeg initialize

        # Puppeteer opens browser + presses SPACE
        log_info "Launching browser for auto-play..."
        node "$SCRIPT_DIR/puppeteer-launch.js" "http://127.0.0.1:5173/?auto=1" --headed

        # Wait for FFmpeg to finish
        wait $FFMPEG_PID 2>/dev/null || { log_error "FFmpeg capture failed for $chapter"; FFMPEG_PID=""; continue; }
        FFMPEG_PID=""
        [ -f "$chapter_raw" ] || { log_error "Raw capture missing: $chapter_raw"; continue; }

        # Burn subtitles
        if [ -f "$chapter_srt" ]; then
            log_info "Burning subtitles..."
            local srt_path
            srt_path=$(ffmpeg_path "$chapter_srt")
            ffmpeg -y -i "$chapter_raw" \
                -vf "subtitles=${srt_path}:force_style='FontSize=24,PrimaryColour=&H00FFFFFF,OutlineColour=&H00000000,Outline=2'" \
                -c:v libx264 -preset medium -crf 18 -c:a copy "$chapter_video" 2>/dev/null
            rm -f "$chapter_raw"
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
        log_info "Final video: $final_output"
    fi

    # Generate manifest
    cat > "$workspace/manifest.json" << EOF
{
  "pipeline_id": "$(basename "$workspace")",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "output": { "video": "$final_output" },
  "duration_seconds": $(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$final_output" 2>/dev/null || echo "0"),
  "resolution": "1920x1080"
}
EOF

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
