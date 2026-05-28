#!/bin/bash
# tools/mix-bgm.sh
# Generate BGM via mmx-cli and mix into final video using FFmpeg.
# Usage: bash mix-bgm.sh <workspace-dir> [--prompt <text>] [--volume <0-1>] [--force] [--dry-run]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BGM_CONFIG="$PROJECT_ROOT/skills/storyboard/bgm-config.json"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }

usage() {
    echo "Usage: bash mix-bgm.sh <workspace-dir> [--prompt <text>] [--volume <0-1>] [--force] [--dry-run]"
    echo ""
    echo "  <workspace-dir>  Path to the pipeline workspace"
    echo "  --prompt <text>  BGM style description (optional, defaults from config presets)"
    echo "  --volume <0-1>   BGM volume, default 0.2 (20%)"
    echo "  --force          Regenerate even if BGM already exists"
    echo "  --dry-run        Only print the mix plan, do not execute"
    exit 1
}

# ── Read style preset from bgm-config.json ──────────────────────────────────
get_style_preset() {
    local category="$1"
    if [ -f "$BGM_CONFIG" ]; then
        local preset=""
        if command -v python3 >/dev/null 2>&1; then
            preset=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    cfg = json.load(f)
presets = cfg.get('style_presets', {})
cat = sys.argv[2]
if cat in presets:
    print(presets[cat], end='')
elif '默认' in presets:
    print(presets['默认'], end='')
" "$BGM_CONFIG" "$category" 2>/dev/null || true)
        elif command -v python >/dev/null 2>&1; then
            preset=$(python -c "
import json, sys
with open(sys.argv[1]) as f:
    cfg = json.load(f)
presets = cfg.get('style_presets', {})
cat = sys.argv[2]
if cat in presets:
    print(presets[cat], end='')
elif '默认' in presets:
    print(presets['默认'], end='')
" "$BGM_CONFIG" "$category" 2>/dev/null || true)
        elif command -v jq >/dev/null 2>&1; then
            preset=$(jq -r ".style_presets[\"$category\"] // .style_presets[\"默认\"] // \"\"" "$BGM_CONFIG" 2>/dev/null || true)
        fi
        echo "$preset"
    fi
}

# ── Derive BGM prompt from plan.json register ───────────────────────────────
derive_prompt_from_plan() {
    local workspace="$1"
    local plan_file="$workspace/plan.json"
    local category="默认"

    if [ -f "$plan_file" ]; then
        if command -v python3 >/dev/null 2>&1; then
            category=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    plan = json.load(f)
reg = plan.get('register', '')
style = plan.get('target_format', '')
cmd = plan.get('command', '')
# Map content types to BGM style presets
mapping = {
    'science': '知识科普', '科普': '知识科普',
    'product': '产品介绍', '产品': '产品介绍',
    'tech': '科技评测', '评测': '科技评测', '科技': '科技评测',
    'humanities': '人文故事', '故事': '人文故事', '人文': '人文故事',
    'business': '商业分析', '商业': '商业分析', '金融': '商业分析',
}
text = (reg + ' ' + style + ' ' + cmd).lower()
for key, val in mapping.items():
    if key in text:
        print(val, end='')
        break
else:
    print('默认', end='')
" "$plan_file" 2>/dev/null || echo "默认")
        elif command -v jq >/dev/null 2>&1; then
            category=$(jq -r '
                (.register // "") as $reg |
                (.target_format // "") as $fmt |
                (.command // "") as $cmd |
                if ($reg + $fmt + $cmd | test("science|科普"; "i")) then "知识科普"
                elif ($reg + $fmt + $cmd | test("product|产品"; "i")) then "产品介绍"
                elif ($reg + $fmt + $cmd | test("tech|评测|科技"; "i")) then "科技评测"
                elif ($reg + $fmt + $cmd | test("humanities|故事|人文"; "i")) then "人文故事"
                elif ($reg + $fmt + $cmd | test("business|商业|金融"; "i")) then "商业分析"
                else "默认" end
            ' "$plan_file" 2>/dev/null || echo "默认")
        fi
    fi

    get_style_preset "$category"
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    local workspace=""
    local bgm_prompt=""
    local volume="0.2"
    local force=false
    local dry_run=false

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --prompt)
                bgm_prompt="$2"; shift 2 ;;
            --volume)
                volume="$2"; shift 2 ;;
            --force)
                force=true; shift ;;
            --dry-run)
                dry_run=true; shift ;;
            -h|--help)
                usage ;;
            -*)
                log_error "Unknown option: $1"
                usage ;;
            *)
                if [ -z "$workspace" ]; then
                    workspace="$1"; shift
                else
                    log_error "Unexpected argument: $1"
                    usage
                fi
                ;;
        esac
    done

    if [ -z "$workspace" ]; then
        log_error "Missing required argument: <workspace-dir>"
        usage
    fi

    # ── Validate workspace ───────────────────────────────────────────────────
    if [ ! -d "$workspace" ]; then
        log_error "Workspace directory not found: $workspace"
        exit 1
    fi

    local final_mp4="$workspace/render/final.mp4"
    if [ ! -f "$final_mp4" ]; then
        log_error "final.mp4 not found: $final_mp4"
        log_error "Run render-video.sh first."
        exit 1
    fi

    # ── Validate mmx CLI ─────────────────────────────────────────────────────
    if ! command -v mmx >/dev/null 2>&1; then
        log_warn "mmx CLI not installed or not in PATH. Skipping BGM generation."
        exit 0
    fi

    if ! mmx auth status >/dev/null 2>&1; then
        log_warn "mmx authentication failed. Run 'mmx auth login'. Skipping BGM."
        exit 0
    fi

    # ── Validate FFmpeg ──────────────────────────────────────────────────────
    if ! command -v ffmpeg >/dev/null 2>&1; then
        log_error "FFmpeg not installed. Cannot mix BGM."
        exit 1
    fi

    if ! command -v ffprobe >/dev/null 2>&1; then
        log_error "FFprobe not installed. Cannot read video duration."
        exit 1
    fi

    # ── Determine BGM prompt ─────────────────────────────────────────────────
    if [ -z "$bgm_prompt" ]; then
        bgm_prompt=$(derive_prompt_from_plan "$workspace")
    fi
    if [ -z "$bgm_prompt" ]; then
        bgm_prompt="Cinematic ambient, moderate tempo, subtle tension, orchestral"
    fi
    log_info "BGM prompt: $bgm_prompt"

    # ── Generate BGM ─────────────────────────────────────────────────────────
    local bgm_mp3="$workspace/render/bgm.mp3"
    mkdir -p "$workspace/render"

    if [ "$dry_run" = true ]; then
        local video_dur
        video_dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$final_mp4" 2>/dev/null || echo "unknown")
        local fade_out_start
        fade_out_start=$(awk "BEGIN{d=$video_dur-3; if(d<0)d=0; printf \"%.1f\", d}")
        echo ""
        echo -e "${YELLOW}[DRY-RUN]${NC} BGM Mix Plan:"
        echo "  Workspace:  $workspace"
        echo "  Input:      render/final.mp4 (${video_dur}s)"
        echo "  BGM:        render/bgm.mp3 (to be generated)"
        echo "  BGM Prompt: $bgm_prompt"
        echo "  Volume:     $volume"
        echo "  Fade in:    3s"
        echo "  Fade out:   3s (start at ${fade_out_start}s)"
        echo "  Output:     render/final-with-bgm.mp4"
        echo ""
        echo -e "${YELLOW}[DRY-RUN]${NC} Commands that would run:"
        echo "  1. mmx music generate --prompt \"$bgm_prompt\" --instrumental --out $bgm_mp3 --quiet"
        echo "  2. ffmpeg -y -i $final_mp4 -i $bgm_mp3 \\"
        echo "       -filter_complex \"[1:a]volume=$volume,afade=t=in:d=3,afade=t=out:st=${fade_out_start}:d=3[aout]\" \\"
        echo "       -map 0:v -map \"[aout]\" -c:v copy -c:a aac -b:a 192k \\"
        echo "       $workspace/render/final-with-bgm.mp4"
        exit 0
    fi

    if [ -f "$bgm_mp3" ] && [ "$force" = false ]; then
        log_info "BGM already exists: $bgm_mp3 (use --force to regenerate)"
    else
        log_info "Generating BGM: $bgm_mp3"
        mmx music generate \
            --prompt "$bgm_prompt" \
            --instrumental \
            --use-case "background music for video" \
            --out "$bgm_mp3" \
            --quiet 2>/dev/null
        MMX_EXIT=$?
        if [ "$MMX_EXIT" -ne 0 ]; then
            if [ "$MMX_EXIT" -eq 4 ]; then
                log_warn "BGM generation quota exhausted. Proceeding without background music."
                log_info "Tip: Retry tomorrow or use --dry-run to preview without generating."
            elif [ "$MMX_EXIT" -eq 3 ]; then
                log_warn "mmx authentication failed. Run 'mmx auth login'. Proceeding without BGM."
            else
                log_warn "BGM generation failed (exit code: $MMX_EXIT). Skipping BGM mixing."
            fi
            exit 0
        fi

        if [ ! -f "$bgm_mp3" ] || [ ! -s "$bgm_mp3" ]; then
            log_warn "BGM file missing or empty after generation. Skipping."
            exit 0
        fi
    fi

    # ── Get durations ────────────────────────────────────────────────────────
    local video_dur bgm_dur
    video_dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$final_mp4")
    bgm_dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$bgm_mp3")

    log_info "Input: render/final.mp4 (${video_dur}s)"
    log_info "BGM:   render/bgm.mp3 (${bgm_dur}s, volume: ${volume})"

    # Calculate fade-out start (3 seconds before video end, minimum 0)
    local fade_out_start
    fade_out_start=$(awk "BEGIN{d=$video_dur-3; if(d<0)d=0; printf \"%.1f\", d}")

    # ── Check if final.mp4 has audio ─────────────────────────────────────────
    local has_audio
    has_audio=$(ffprobe -v quiet -select_streams a -show_entries stream=codec_type -of csv=p=0 "$final_mp4" 2>/dev/null || echo "")

    local output_mp4="$workspace/render/final-with-bgm.mp4"

    if [ -n "$has_audio" ]; then
        # Video has audio → mix with amix
        log_info "Mixing BGM into final video (amix mode)..."
        ffmpeg -y -i "$final_mp4" -i "$bgm_mp3" \
            -filter_complex "[1:a]volume=$volume,afade=t=in:d=3,afade=t=out:st=${fade_out_start}:d=3[bgm];[0:a][bgm]amix=inputs=2:duration=first[aout]" \
            -map 0:v -map "[aout]" -c:v copy -c:a aac -b:a 192k \
            "$output_mp4" 2>/dev/null
    else
        # No audio track → BGM becomes the only audio
        log_info "Mixing BGM into final video (no existing audio, BGM as sole track)..."
        ffmpeg -y -i "$final_mp4" -i "$bgm_mp3" \
            -filter_complex "[1:a]volume=$volume,afade=t=in:d=3,afade=t=out:st=${fade_out_start}:d=3[aout]" \
            -map 0:v -map "[aout]" -c:v copy -c:a aac -b:a 192k \
            "$output_mp4" 2>/dev/null
    fi

    if [ ! -f "$output_mp4" ] || [ ! -s "$output_mp4" ]; then
        log_error "Mix failed: output file missing or empty."
        exit 1
    fi

    log_info "Output: render/final-with-bgm.mp4"

    # ── Update manifest.json (if jq available) ──────────────────────────────
    local manifest="$workspace/manifest.json"
    if [ -f "$manifest" ] && command -v jq >/dev/null 2>&1; then
        local out_dur
        out_dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$output_mp4" 2>/dev/null || echo "0")
        jq --arg bgm "$bgm_mp3" --arg out "$output_mp4" --arg dur "$out_dur" \
            '.output.bgm = $bgm | .output.video_with_bgm = $out | .duration_seconds = ($dur | tonumber)' \
            "$manifest" > "$manifest.tmp" && mv "$manifest.tmp" "$manifest"
        log_info "Updated manifest.json"
    fi

    log_info "BGM pipeline complete"
}

main "$@"
