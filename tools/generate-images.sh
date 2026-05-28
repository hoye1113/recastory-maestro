#!/bin/bash
# tools/generate-images.sh
# Scans outline.md for <!-- img: description --> markers and generates images via mmx.
# Usage: bash generate-images.sh <workspace-dir> [--force] [--dry-run]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_skip()  { echo -e "${YELLOW}[SKIP]${NC} $1"; }

usage() {
    echo "Usage: bash generate-images.sh <workspace-dir> [--force] [--dry-run]"
    echo ""
    echo "  <workspace-dir>  Path to the pipeline workspace"
    echo "  --force          Regenerate images even if they already exist"
    echo "  --dry-run        Only print the image list, do not generate"
    exit 1
}

# ── Parse prompt prefix from image-config.json ──────────────────────────────
get_prompt_prefix() {
    local config="$PROJECT_ROOT/skills/storyboard/image-config.json"
    if [ -f "$config" ]; then
        # Try python first, fall back to jq
        if command -v python3 >/dev/null 2>&1; then
            python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    cfg = json.load(f)
pp = cfg.get('promptPrefix') or cfg.get('prompt_prefix') or ''
if isinstance(pp, dict):
    pp = pp.get('default') or pp.get('hero') or ''
print(pp, end='')
" "$config" 2>/dev/null || true
        elif command -v python >/dev/null 2>&1; then
            python -c "
import json, sys
with open(sys.argv[1]) as f:
    cfg = json.load(f)
pp = cfg.get('promptPrefix') or cfg.get('prompt_prefix') or ''
if isinstance(pp, dict):
    pp = pp.get('default') or pp.get('hero') or ''
print(pp, end='')
" "$config" 2>/dev/null || true
        elif command -v jq >/dev/null 2>&1; then
            jq -r '(.promptPrefix // .prompt_prefix // "") | if type == "object" then (.default // .hero // "") else . end' "$config" 2>/dev/null || true
        fi
    fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    local workspace=""
    local force=false
    local dry_run=false

    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --force)  force=true ;;
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

    # Validate mmx
    if ! command -v mmx >/dev/null 2>&1; then
        log_error "mmx CLI not installed or not in PATH"
        exit 1
    fi

    if ! mmx auth status >/dev/null 2>&1; then
        log_error "mmx authentication failed. Run 'mmx auth login' first."
        exit 1
    fi

    # Read optional prompt prefix
    local prompt_prefix
    prompt_prefix=$(get_prompt_prefix)
    if [ -n "$prompt_prefix" ]; then
        log_info "Using prompt prefix from image-config.json"
    fi

    local img_dir="$workspace/storyboard/public/img"
    local generated=0
    local skipped=0
    local failed=0
    local total=0
    local QUOTA_EXHAUSTED=false

    # Parse outline.md
    local current_chapter="misc"
    local current_step=0

    log_info "Scanning $outline for image markers..."

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

        # Detect image marker: <!-- img: description --> or <!-- img: 描述 -->
        if echo "$line" | grep -qE '^<!-- *img:.*-->'; then
            local desc
            desc=$(echo "$line" | sed -E 's/^<!-- *img: *(.*) *-->/\1/' | sed 's/^ *//;s/ *$//')
            if [ -z "$desc" ]; then
                continue
            fi

            # Increment step if not yet set by a header
            if [ "$current_step" -eq 0 ]; then
                current_step=$((current_step + 1))
            fi

            local out_path="$img_dir/$current_chapter/$current_step.jpg"
            total=$((total + 1))

            if [ "$dry_run" = true ]; then
                echo -e "  ${YELLOW}[DRY-RUN]${NC} Would generate: $out_path"
                echo -e "           Prompt: $prompt_prefix$desc"
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

            # Build full prompt
            local full_prompt="$desc"
            if [ -n "$prompt_prefix" ]; then
                full_prompt="$prompt_prefix$desc"
            fi

            # Generate image
            log_info "Generating: $out_path"
            MMX_EXIT=0
            mmx image generate \
                --prompt "$full_prompt" \
                --aspect-ratio 16:9 \
                --prompt-optimizer \
                --out "$out_path" \
                --quiet 2>/dev/null || MMX_EXIT=$?
            if [ "$MMX_EXIT" -eq 0 ]; then
                # Validate output
                if [ -f "$out_path" ] && [ -s "$out_path" ]; then
                    log_info "OK: $out_path"
                    generated=$((generated + 1))
                else
                    log_error "File missing or empty after generation: $out_path"
                    failed=$((failed + 1))
                fi
            elif [ "$MMX_EXIT" -eq 4 ]; then
                QUOTA_EXHAUSTED=true
                log_error "Image generation quota exhausted. Stopping further attempts."
                log_info "Generated $generated of $total images. Remaining will use placeholder cards."
                break
            else
                log_error "mmx generation failed for: $out_path"
                failed=$((failed + 1))
            fi
        fi
    done < "$outline"

    # Summary
    if [ "$dry_run" = true ]; then
        echo ""
        echo -e "${YELLOW}[DRY-RUN]${NC} Found $total image marker(s). No images were generated."
        exit 0
    fi

    echo ""
    echo -e "${YELLOW}=== Image Generation Summary ===${NC}"
    echo -e "  Total markers: ${YELLOW}$total${NC}"
    echo -e "  Generated:     ${GREEN}$generated${NC}"
    echo -e "  Skipped:       ${YELLOW}$skipped${NC}"
    echo -e "  Failed:        ${RED}$failed${NC}"

    if [ "$QUOTA_EXHAUSTED" = true ]; then
        log_warn "Image generation quota exhausted. $generated images generated, $((total - generated - skipped)) skipped."
        log_warn "   Remaining images will use placeholder cards. Retry tomorrow for remaining images."
        log_warn "   Tip: Use --dry-run first to plan image allocation within quota."
    fi

    if [ $failed -gt 0 ]; then
        exit 1
    fi
}

main "$@"
