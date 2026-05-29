#!/bin/bash
# tools/lib/env-common.sh
# Shared environment detection functions for the render pipeline.
# Can be sourced (source env-common.sh) or called directly (bash env-common.sh <func> <args>).

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# --- Platform Detection ---

env_platform() {
    case "$(uname -s)" in
        MINGW*|MSYS*|CYGWIN*|Windows*) echo "windows" ;;
        Darwin*) echo "darwin" ;;
        *) echo "linux" ;;
    esac
}

# --- Resolution Detection ---

# Returns: LOGICAL_WxLOGICAL_H|PHYSICAL_WxPHYSICAL_H|DPI_SCALE
# On Windows: logical = Screen.PrimaryScreen.Bounds, physical = WMI Win32_VideoController
# On macOS/Linux: physical = logical (no DPI scaling in screen capture context)
env_detect_resolution() {
    local platform
    platform=$(env_platform)
    case "$platform" in
        windows)
            powershell -NoProfile -Command '
Add-Type -AssemblyName System.Windows.Forms
$logical = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$lw = $logical.Width; $lh = $logical.Height
$vid = Get-CimInstance Win32_VideoController | Where-Object { $_.CurrentHorizontalResolution -gt 0 } | Select-Object -First 1
if ($vid) { $pw = $vid.CurrentHorizontalResolution; $ph = $vid.CurrentVerticalResolution }
else { $pw = $lw; $ph = $lh }
$scale = [math]::Round($pw / $lw, 2)
echo "${lw}x${lh}|${pw}x${ph}|${scale}"
' 2>/dev/null || echo "1920x1080|1920x1080|1.0"
            ;;
        darwin)
            local res
            res=$(system_profiler SPDisplaysDataType 2>/dev/null | grep Resolution | head -1 | grep -o '[0-9]* x [0-9]*' | tr -d ' ' || echo "1920x1080")
            echo "${res}|${res}|1.0"
            ;;
        linux)
            local res
            res=$(xrandr 2>/dev/null | grep ' connected' | grep -o '[0-9]*x[0-9]*' | head -1 || echo "1920x1080")
            echo "${res}|${res}|1.0"
            ;;
    esac
}

# Round resolution string to even dimensions (H.264 requirement)
_round_even() {
    local input="${1:-}"
    if [[ ! "$input" =~ ^[0-9]+x[0-9]+$ ]]; then
        echo "1920x1080"
        return
    fi
    local w h
    w=$(echo "$input" | cut -d'x' -f1)
    h=$(echo "$input" | cut -d'x' -f2)
    w=$(( w - w % 2 ))
    h=$(( h - h % 2 ))
    echo "${w}x${h}"
}

# Parse pipe-delimited resolution string into global variables:
#   ENV_LOGICAL_RES, ENV_PHYSICAL_RES, ENV_DPI_SCALE
env_parse_resolution() {
    local raw="${1:-}"
    if [ -z "$raw" ]; then
        raw=$(env_detect_resolution)
    fi
    ENV_LOGICAL_RES=$(_round_even "$(echo "$raw" | cut -d'|' -f1)")
    ENV_PHYSICAL_RES=$(_round_even "$(echo "$raw" | cut -d'|' -f2)")
    ENV_DPI_SCALE=$(echo "$raw" | cut -d'|' -f3)
}

# Decide which resolution to use for screen capture or final output.
# Usage: env_pick_capture_resolution [capture|output]
#   capture = logical resolution (what the OS compositor uses)
#   output  = 1920x1080 (standard final output)
env_pick_capture_resolution() {
    local mode="${1:-capture}"
    case "$mode" in
        capture) echo "$ENV_LOGICAL_RES" ;;
        output)  echo "1920x1080" ;;
    esac
}

# --- Browser Detection ---

# Find an available Chromium-based browser.
# Search order: PUPPETEER_EXECUTABLE_PATH env var → Chrome → Edge
env_detect_browser() {
    if [ -n "${PUPPETEER_EXECUTABLE_PATH:-}" ] && [ -f "$PUPPETEER_EXECUTABLE_PATH" ]; then
        echo "$PUPPETEER_EXECUTABLE_PATH"
        return 0
    fi

    local platform
    platform=$(env_platform)
    local candidates=()

    case "$platform" in
        windows)
            candidates=(
                "C:/Program Files/Google/Chrome/Application/chrome.exe"
                "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe"
                "C:/Program Files/Microsoft/Edge/Application/msedge.exe"
                "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
            )
            ;;
        darwin)
            candidates=(
                "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
                "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"
            )
            ;;
        linux)
            candidates=(
                "/usr/bin/google-chrome"
                "/usr/bin/google-chrome-stable"
                "/usr/bin/chromium-browser"
                "/usr/bin/chromium"
                "/usr/bin/microsoft-edge"
            )
            ;;
    esac

    for p in "${candidates[@]}"; do
        if [ -f "$p" ]; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

# --- Pre-flight Dependency Check ---

# Validates all required dependencies. Returns 0 if all pass, 1 if any critical missing.
env_preflight_check() {
    local failures=0
    local warnings=0

    # Critical dependencies
    for cmd in ffmpeg ffprobe node; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log_info "$cmd: $(command -v "$cmd")"
        else
            log_error "$cmd: NOT FOUND (critical)"
            failures=$((failures + 1))
        fi
    done

    # Recommended dependencies
    for cmd in npx npm; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log_info "$cmd: $(command -v "$cmd")"
        else
            log_warn "$cmd: NOT FOUND (recommended)"
            warnings=$((warnings + 1))
        fi
    done

    # Platform-specific checks
    local platform
    platform=$(env_platform)
    case "$platform" in
        windows)
            if command -v powershell >/dev/null 2>&1; then
                log_info "powershell: $(command -v powershell)"
            else
                log_error "powershell: NOT FOUND (critical for Windows)"
                failures=$((failures + 1))
            fi
            ;;
        linux)
            if command -v xrandr >/dev/null 2>&1; then
                log_info "xrandr: $(command -v xrandr)"
            else
                log_warn "xrandr: NOT FOUND (resolution detection will use fallback)"
                warnings=$((warnings + 1))
            fi
            ;;
    esac

    # Puppeteer check (Node module)
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$script_dir/../node_modules/puppeteer/package.json" ] || \
       [ -f "$script_dir/../node_modules/puppeteer-core/package.json" ]; then
        log_info "puppeteer: installed"
    else
        log_warn "puppeteer: NOT FOUND in node_modules"
        warnings=$((warnings + 1))
    fi

    if [ "$failures" -gt 0 ]; then
        log_error "Pre-flight check FAILED: $failures critical, $warnings warnings"
        return 1
    fi
    log_info "Pre-flight check PASSED ($warnings warnings)"
    return 0
}

# --- Path Utilities ---

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

# --- Self-dispatching footer ---
# Support direct invocation: bash env-common.sh env_detect_resolution
if [ "$(basename "$0")" = "env-common.sh" ] && [ -n "${1:-}" ]; then
    "$@"
fi
