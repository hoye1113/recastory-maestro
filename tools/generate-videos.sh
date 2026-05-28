#!/bin/bash
# tools/generate-videos.sh
# Scans outline.md for <!-- video: description --> markers and generates videos via mmx (async).
# Usage: bash generate-videos.sh <workspace-dir> [--force] [--dry-run]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_skip()  { echo -e "${YELLOW}[SKIP]${NC} $1"; }

# ── Defaults from video-config.json ─────────────────────────────────────────
POLL_INTERVAL=10
MAX_WAIT_SECONDS=300
VIDEO_PROMPT_PREFIX=""

usage() {
    echo "Usage: bash generate-videos.sh <workspace-dir> [--force] [--dry-run]"
    echo ""
    echo "  <workspace-dir>  Path to the pipeline workspace"
    echo "  --force          Regenerate videos even if they already exist"
    echo "  --dry-run        Only print the video list, do not generate"
    exit 1
}

# ── Parse config from video-config.json ─────────────────────────────────────
load_config() {
    local config="$PROJECT_ROOT/skills/storyboard/video-config.json"
    if [ -f "$config" ]; then
        # Convert to Windows path for Node.js compatibility (MSYS2/Git Bash)
        local config_win
        config_win=$(cygpath -w "$config" 2>/dev/null || echo "$config")
        local interval
        interval=$(node -e "const c=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); process.stdout.write(String(c.defaults?.poll_interval||10))" "$config_win" 2>/dev/null || echo "10")
        local max_wait
        max_wait=$(node -e "const c=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); process.stdout.write(String(c.defaults?.max_wait_seconds||300))" "$config_win" 2>/dev/null || echo "300")
        local prefix
        prefix=$(node -e "const c=JSON.parse(require('fs').readFileSync(process.argv[1],'utf8')); const p=c.prompt_prefix||{}; process.stdout.write(p.scene||p.transition||p.motion||'')" "$config_win" 2>/dev/null || echo "")
        POLL_INTERVAL="$interval"
        MAX_WAIT_SECONDS="$max_wait"
        VIDEO_PROMPT_PREFIX="$prefix"
    fi
}

# ── Poll for video task completion ──────────────────────────────────────────
poll_video_task() {
    local task_id="$1"
    local out_path="$2"
    local desc="$3"
    local elapsed=0

    while [ "$elapsed" -lt "$MAX_WAIT_SECONDS" ]; do
        local status_json
        status_json=$(mmx video task get --task-id "$task_id" --output json --quiet 2>/dev/null) || {
            log_warn "Poll request failed, retrying..."
            sleep "$POLL_INTERVAL"
            elapsed=$((elapsed + POLL_INTERVAL))
            continue
        }

        local status
        status=$(echo "$status_json" | node -e "process.stdout.write(JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')).status||'')" 2>/dev/null || echo "")

        if [ "$status" = "completed" ] || [ "$status" = "success" ]; then
            local file_id
            file_id=$(echo "$status_json" | node -e "process.stdout.write(JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')).fileId||'')" 2>/dev/null || echo "")
            if [ -z "$file_id" ]; then
                log_error "No fileId in completed response for: $desc"
                return 1
            fi
            mkdir -p "$(dirname "$out_path")"
            mmx video download --file-id "$file_id" --out "$out_path" --quiet 2>/dev/null
            if [ -f "$out_path" ] && [ -s "$out_path" ]; then
                log_info "OK: $out_path"
                return 0
            else
                log_error "Downloaded file missing or empty: $out_path"
                return 1
            fi
        elif [ "$status" = "failed" ] || [ "$status" = "error" ]; then
            log_error "Video generation failed: $desc"
            return 1
        fi

        # Still processing — wait
        sleep "$POLL_INTERVAL"
        elapsed=$((elapsed + POLL_INTERVAL))
    done

    log_error "Timeout waiting for video: $desc (${MAX_WAIT_SECONDS}s)"
    return 1
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    local workspace=""
    local force=false
    local dry_run=false

    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --force)   force=true ;;
            --dry-run) dry_run=true ;;
            -h|--help) usage ;;
            *)
                if [ -z "$workspace" ]; then
                    workspace="$arg"
                else
                    log_error "Unexpected argument: $arg"
                    usage
                fi
                ;;
        esac
    done

    if [ -z "$workspace" ]; then
        log_error "Missing required argument: <workspace-dir>"
        usage
    fi

    # Validate workspace
    if [ ! -d "$workspace" ]; then
        log_error "Workspace directory not found: $workspace"
        exit 1
    fi

    local outline="$workspace/distill/outline.md"
    if [ ! -f "$outline" ]; then
        log_error "outline.md not found: $outline"
        exit 1
    fi

    # Load config (poll intervals, etc.)
    load_config

    # Validate mmx (skip auth check in dry-run mode)
    if ! command -v mmx >/dev/null 2>&1; then
        log_error "mmx CLI not installed or not in PATH"
        exit 1
    fi

    if [ "$dry_run" = false ]; then
        if ! mmx auth status >/dev/null 2>&1; then
            log_error "mmx authentication failed. Run 'mmx auth login' first."
            exit 1
        fi
    fi

    local video_dir="$workspace/storyboard/public/video"
    local generated=0
    local skipped=0
    local failed=0
    local total=0

    # Parse outline.md
    local current_chapter="misc"
    local current_step=0

    log_info "Scanning $outline for video markers..."

    while IFS= read -r line; do
        # Detect chapter header: ## 第N章：<id> — <标题> or ## Chapter N: <id> — <标题>
        if echo "$line" | grep -qE '^## +第[0-9]+章[：:]'; then
            local chapter_id
            chapter_id=$(echo "$line" | sed -E 's/^## +第[0-9]+章[：:] *([^ ——]+).*/\1/' | tr -d ' ' | tr '/' '_' | tr '\\' '_')
            if [ -n "$chapter_id" ]; then
                current_chapter="$chapter_id"
            else
                current_chapter="misc"
            fi
            current_step=0
            continue
        fi

        if echo "$line" | grep -qE '^## +Chapter [0-9]+[：:]'; then
            local chapter_id
            chapter_id=$(echo "$line" | sed -E 's/^## +Chapter [0-9]+[：:] *([^ ——]+).*/\1/' | tr -d ' ' | tr '/' '_' | tr '\\' '_')
            if [ -n "$chapter_id" ]; then
                current_chapter="$chapter_id"
            else
                current_chapter="misc"
            fi
            current_step=0
            continue
        fi

        # Detect step header: ### 步骤 N or ### Step N
        if echo "$line" | grep -qE '^### +(步骤|Step) [0-9]+'; then
            local detected_step
            detected_step=$(echo "$line" | grep -oE '[0-9]+' | head -1)
            if [ -n "$detected_step" ]; then
                current_step=$detected_step
            else
                current_step=$((current_step + 1))
            fi
            continue
        fi

        # Detect video marker: <!-- video: description -->
        if echo "$line" | grep -qE '^<!-- *video:.*-->'; then
            local desc
            desc=$(echo "$line" | sed -E 's/^<!-- *video: *(.*) *-->/\1/' | sed 's/^ *//;s/ *$//')
            if [ -z "$desc" ]; then
                continue
            fi

            # Increment step if not yet set by a header
            if [ "$current_step" -eq 0 ]; then
                current_step=$((current_step + 1))
            fi

            local out_path="$video_dir/$current_chapter/$current_step.mp4"
            total=$((total + 1))

            if [ "$dry_run" = true ]; then
                local dry_prompt="${VIDEO_PROMPT_PREFIX}${desc}"
                echo -e "  ${YELLOW}[DRY-RUN]${NC} Would generate: $out_path"
                echo -e "           Prompt: $dry_prompt"
                continue
            fi

            # Skip existing unless --force
            if [ -f "$out_path" ] && [ "$force" = false ]; then
                log_skip "Already exists: $out_path"
                skipped=$((skipped + 1))
                continue
            fi

            # Ensure output directory
            mkdir -p "$(dirname "$out_path")"

            # Generate video (async)
            local full_prompt="${VIDEO_PROMPT_PREFIX}${desc}"
            log_info "Submitting video generation: $out_path"
            local gen_json
            gen_json=$(mmx video generate \
                --prompt "$full_prompt" \
                --async \
                --output json \
                --quiet 2>/dev/null) || {
                log_error "mmx video generate failed for: $desc"
                failed=$((failed + 1))
                continue
            }

            # Parse taskId
            local task_id
            task_id=$(echo "$gen_json" | node -e "process.stdout.write(JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')).taskId||'')" 2>/dev/null || echo "")

            if [ -z "$task_id" ]; then
                log_error "No taskId returned for: $desc"
                failed=$((failed + 1))
                continue
            fi

            log_info "Task submitted: $task_id (polling every ${POLL_INTERVAL}s, timeout ${MAX_WAIT_SECONDS}s)"

            # Poll for completion and download
            if poll_video_task "$task_id" "$out_path" "$desc"; then
                generated=$((generated + 1))
            else
                failed=$((failed + 1))
            fi
        fi
    done < "$outline"

    # Summary
    if [ "$dry_run" = true ]; then
        echo ""
        echo -e "${YELLOW}[DRY-RUN]${NC} Found $total video marker(s). No videos were generated."
        exit 0
    fi

    echo ""
    echo -e "${YELLOW}=== Video Generation Summary ===${NC}"
    echo -e "  Total markers: ${YELLOW}$total${NC}"
    echo -e "  Generated:     ${GREEN}$generated${NC}"
    echo -e "  Skipped:       ${YELLOW}$skipped${NC}"
    echo -e "  Failed:        ${RED}$failed${NC}"

    if [ $failed -gt 0 ]; then
        exit 1
    fi
}

main "$@"
