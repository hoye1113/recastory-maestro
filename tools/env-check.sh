#!/bin/bash
# tools/env-check.sh
# Standalone environment pre-flight checker.
# Outputs env-report.json with platform, resolution, browser, dependencies.
# Usage: bash env-check.sh [--output <path>] [--quiet]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/env-common.sh"

usage() {
    echo "Usage: bash env-check.sh [--output <path>] [--quiet]"
    echo ""
    echo "Options:"
    echo "  --output <path>  Write env-report.json to file (default: stdout)"
    echo "  --quiet          Suppress log output, only output JSON"
    echo "  --help           Show this help"
}

main() {
    local output_file=""
    local quiet=false

    while [ $# -gt 0 ]; do
        case "$1" in
            --output)
                [ -z "${2:-}" ] && { log_error "--output requires a path argument"; usage; exit 1; }
                output_file="$2"; shift 2
                ;;
            --quiet)  quiet=true; shift ;;
            --help)   usage; exit 0 ;;
            *)        log_error "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    # Suppress logs if quiet
    if [ "$quiet" = true ]; then
        log_info() { :; }
        log_warn() { :; }
        log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
    fi

    log_info "Detecting environment..."

    # Platform
    local platform
    platform=$(env_platform)
    log_info "Platform: $platform"

    # Resolution
    local env_raw
    env_raw=$(env_detect_resolution)
    env_parse_resolution "$env_raw"
    local capture_res
    capture_res=$(env_pick_capture_resolution "capture")
    log_info "Resolution: logical=$ENV_LOGICAL_RES physical=$ENV_PHYSICAL_RES dpi=$ENV_DPI_SCALE capture=$capture_res"

    # Browser
    local browser_path browser_detected
    browser_path=$(env_detect_browser 2>/dev/null) && browser_detected=true || browser_detected=false
    if [ "$browser_detected" = true ]; then
        log_info "Browser: $browser_path"
    else
        log_warn "Browser: NOT FOUND"
        browser_path=""
    fi

    # Dependencies
    local ffmpeg_found ffprobe_found node_found npx_found powershell_found xrandr_found puppeteer_found
    local ffmpeg_path_val ffprobe_path_val node_path_val npx_path_val powershell_path_val node_version_val

    ffmpeg_found=false; ffprobe_found=false; node_found=false; npx_found=false
    powershell_found=false; xrandr_found=false; puppeteer_found=false
    ffmpeg_path_val=""; ffprobe_path_val=""; node_path_val=""; npx_path_val=""
    powershell_path_val=""; node_version_val=""

    if command -v ffmpeg >/dev/null 2>&1; then ffmpeg_found=true; ffmpeg_path_val="$(command -v ffmpeg)"; fi
    if command -v ffprobe >/dev/null 2>&1; then ffprobe_found=true; ffprobe_path_val="$(command -v ffprobe)"; fi
    if command -v node >/dev/null 2>&1; then node_found=true; node_path_val="$(command -v node)"; node_version_val="$(node --version 2>/dev/null || echo 'unknown')"; fi
    if command -v npx >/dev/null 2>&1; then npx_found=true; npx_path_val="$(command -v npx)"; fi
    if command -v powershell >/dev/null 2>&1; then powershell_found=true; powershell_path_val="$(command -v powershell)"; fi
    if command -v xrandr >/dev/null 2>&1; then xrandr_found=true; fi
    if [ -f "$SCRIPT_DIR/node_modules/puppeteer/package.json" ] || \
       [ -f "$SCRIPT_DIR/node_modules/puppeteer-core/package.json" ]; then
        puppeteer_found=true
    fi

    # Preflight status
    local critical_failures=0 warnings=0 preflight_passed=true
    [ "$ffmpeg_found" = false ] && critical_failures=$((critical_failures + 1))
    [ "$ffprobe_found" = false ] && critical_failures=$((critical_failures + 1))
    [ "$node_found" = false ] && critical_failures=$((critical_failures + 1))
    if [ "$platform" = "windows" ] && [ "$powershell_found" = false ]; then
        critical_failures=$((critical_failures + 1))
    fi
    [ "$npx_found" = false ] && warnings=$((warnings + 1))
    [ "$puppeteer_found" = false ] && warnings=$((warnings + 1))
    [ "$platform" = "linux" ] && [ "$xrandr_found" = false ] && warnings=$((warnings + 1))
    [ "$critical_failures" -gt 0 ] && preflight_passed=false

    # Build JSON
    # Escape backslashes and double quotes in path values for safe JSON interpolation
    _json_escape() { echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
    browser_path=$(_json_escape "$browser_path")
    ffmpeg_path_val=$(_json_escape "$ffmpeg_path_val")
    ffprobe_path_val=$(_json_escape "$ffprobe_path_val")
    node_path_val=$(_json_escape "$node_path_val")
    npx_path_val=$(_json_escape "$npx_path_val")
    powershell_path_val=$(_json_escape "$powershell_path_val")

    local json
    json=$(cat <<JSON_EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "platform": "$platform",
  "resolution": {
    "logical": "$ENV_LOGICAL_RES",
    "physical": "$ENV_PHYSICAL_RES",
    "dpi_scale": $ENV_DPI_SCALE,
    "capture_recommended": "$capture_res",
    "output_target": "1920x1080"
  },
  "browser": {
    "path": "$browser_path",
    "detected": $browser_detected
  },
  "dependencies": {
    "ffmpeg": { "found": $ffmpeg_found, "path": "$ffmpeg_path_val" },
    "ffprobe": { "found": $ffprobe_found, "path": "$ffprobe_path_val" },
    "node": { "found": $node_found, "path": "$node_path_val", "version": "$node_version_val" },
    "npx": { "found": $npx_found, "path": "$npx_path_val" },
    "powershell": { "found": $powershell_found, "path": "$powershell_path_val" },
    "puppeteer": { "found": $puppeteer_found }
  },
  "preflight": {
    "passed": $preflight_passed,
    "critical_failures": $critical_failures,
    "warnings": $warnings
  }
}
JSON_EOF
    )

    if [ -n "$output_file" ]; then
        echo "$json" > "$output_file"
        log_info "Report written to: $output_file"
    else
        echo "$json"
    fi

    if [ "$preflight_passed" = false ]; then
        log_error "Pre-flight FAILED: $critical_failures critical dependency missing"
        exit 1
    fi

    log_info "Pre-flight PASSED ($warnings warnings)"
    exit 0
}

main "$@"
