#!/bin/bash
# tools/capture-screenshots.sh
# Capture per-step screenshots from storyboard and optionally run VV audit.
# Usage: bash capture-screenshots.sh <workspace-dir> [--audit]
set -euo pipefail

WORKSPACE="${1:?Usage: capture-screenshots.sh <workspace-dir> [--audit]}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AUDIT=false

for arg in "$@"; do
    [ "$arg" = "--audit" ] && AUDIT=true
done

STORYBOARD_DIR="$WORKSPACE/storyboard"
SCREENSHOT_DIR="$STORYBOARD_DIR/screenshots"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Validation
if [ ! -d "$STORYBOARD_DIR" ]; then
    log_error "Storyboard dir not found: $STORYBOARD_DIR"
    exit 1
fi

# Start Vite dev server
log_info "Starting Vite dev server..."
cd "$STORYBOARD_DIR"
npx vite --port 5174 --host 127.0.0.1 &
VITE_PID=$!
trap 'kill $VITE_PID 2>/dev/null || true' EXIT
sleep 3

# Capture screenshots
log_info "Capturing screenshots..."
node "$SCRIPT_DIR/puppeteer-launch.js" \
    "http://127.0.0.1:5174/?auto=1" \
    --screenshot-steps \
    --screenshot-dir "$SCREENSHOT_DIR" \
    || log_error "Screenshot capture failed"

# Vite process is cleaned up by EXIT trap

log_info "Screenshots saved to: $SCREENSHOT_DIR"
ls -la "$SCREENSHOT_DIR"/*.png 2>/dev/null | wc -l | xargs -I{} echo "  {} screenshots captured"

# Optional: run VV audit
if [ "$AUDIT" = true ]; then
    log_info "Running visual audit..."
    PYTHON_CMD="python3"
    command -v python3 >/dev/null 2>&1 || PYTHON_CMD="python"
    $PYTHON_CMD -m tools.audit "$WORKSPACE" --rule VV || log_error "VV audit found issues"
fi
