#!/bin/bash
# tools/mix-bgm.test.sh
# Tests for mix-bgm.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/mix-bgm.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0

pass() { echo -e "  ${GREEN}PASS${NC} $1"; PASS=$((PASS+1)); }
fail() { echo -e "  ${RED}FAIL${NC} $1"; FAIL=$((FAIL+1)); }

# ── Test 1: Script exists ───────────────────────────────────────────────────
echo -e "${YELLOW}[Test 1]${NC} Script file exists"
if [ -f "$SCRIPT" ]; then
    pass "mix-bgm.sh exists"
else
    fail "mix-bgm.sh not found at $SCRIPT"
fi

# ── Test 2: Syntax check ────────────────────────────────────────────────────
echo -e "${YELLOW}[Test 2]${NC} Syntax check (bash -n)"
if bash -n "$SCRIPT" 2>/dev/null; then
    pass "Syntax OK"
else
    fail "Syntax error detected"
fi

# ── Test 3: No arguments shows usage ────────────────────────────────────────
echo -e "${YELLOW}[Test 3]${NC} No arguments shows usage"
output=$(bash "$SCRIPT" 2>&1 || true)
if echo "$output" | grep -qi "usage"; then
    pass "Shows usage on no args"
else
    fail "Did not show usage: $output"
fi

# ── Test 4: Non-existent directory ──────────────────────────────────────────
echo -e "${YELLOW}[Test 4]${NC} Non-existent directory reports error"
output=$(bash "$SCRIPT" "/tmp/nonexistent-workspace-$$" 2>&1 || true)
if echo "$output" | grep -qi "not found\|error"; then
    pass "Reports error for missing directory"
else
    fail "Did not report error: $output"
fi

# ── Test 5: Missing final.mp4 ──────────────────────────────────────────────
echo -e "${YELLOW}[Test 5]${NC} Missing final.mp4 reports error"
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/render"
output=$(bash "$SCRIPT" "$tmpdir" 2>&1 || true)
if echo "$output" | grep -qi "final.mp4 not found\|render-video"; then
    pass "Reports error for missing final.mp4"
else
    fail "Did not report error for missing final.mp4: $output"
fi
rm -rf "$tmpdir"

# ── Test 6: --dry-run outputs plan ──────────────────────────────────────────
echo -e "${YELLOW}[Test 6]${NC} --dry-run outputs mix plan"
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/render"
# Create a stub final.mp4 (minimal valid mp4)
ffmpeg -y -f lavfi -i "color=c=black:s=64x64:d=1" -c:v libx264 "$tmpdir/render/final.mp4" 2>/dev/null || true

if [ -f "$tmpdir/render/final.mp4" ]; then
    output=$(bash "$SCRIPT" "$tmpdir" --prompt "Test ambient" --volume 0.3 --dry-run 2>&1 || true)
    if echo "$output" | grep -qi "DRY-RUN\|BGM Mix Plan\|mmx music generate"; then
        pass "Dry-run outputs mix plan"
    else
        fail "Dry-run did not output expected plan: $output"
    fi
else
    echo -e "  ${YELLOW}SKIP${NC} ffmpeg not available for stub creation"
fi
rm -rf "$tmpdir"

# ── Test 7: mmx music generate returns exit code 4 (quota exhaustion) ─────
echo -e "${YELLOW}[Test 7]${NC} mmx music generate exit code 4 (quota exhaustion)"
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/render"
touch "$tmpdir/render/final.mp4"

mock_bin=$(mktemp -d)
cat > "$mock_bin/mmx" << 'MOCK_EOF'
#!/bin/bash
if [ "$1" = "auth" ] && [ "$2" = "status" ]; then exit 0; fi
if [ "$1" = "music" ] && [ "$2" = "generate" ]; then exit 4; fi
exit 0
MOCK_EOF
chmod +x "$mock_bin/mmx"
printf '#!/bin/bash\nexit 0\n' > "$mock_bin/ffmpeg" && chmod +x "$mock_bin/ffmpeg"
printf '#!/bin/bash\nexit 0\n' > "$mock_bin/ffprobe" && chmod +x "$mock_bin/ffprobe"

exit_code=0
output=$(PATH="$mock_bin:$PATH" bash "$SCRIPT" "$tmpdir" --prompt "Test ambient" 2>&1) || exit_code=$?

if [ "$exit_code" -eq 0 ]; then
    pass "Script exits 0 on quota exhaustion"
else
    fail "Script exited $exit_code, expected 0"
fi

if echo "$output" | grep -qi "quota"; then
    pass "Output contains 'quota' warning"
else
    fail "Output missing 'quota' keyword: $output"
fi

rm -rf "$tmpdir" "$mock_bin"

# ── Test 8: mmx music generate returns exit code 3 (auth failure) ────────
echo -e "${YELLOW}[Test 8]${NC} mmx music generate exit code 3 (auth failure)"
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/render"
touch "$tmpdir/render/final.mp4"

mock_bin=$(mktemp -d)
cat > "$mock_bin/mmx" << 'MOCK_EOF'
#!/bin/bash
if [ "$1" = "auth" ] && [ "$2" = "status" ]; then exit 0; fi
if [ "$1" = "music" ] && [ "$2" = "generate" ]; then exit 3; fi
exit 0
MOCK_EOF
chmod +x "$mock_bin/mmx"
printf '#!/bin/bash\nexit 0\n' > "$mock_bin/ffmpeg" && chmod +x "$mock_bin/ffmpeg"
printf '#!/bin/bash\nexit 0\n' > "$mock_bin/ffprobe" && chmod +x "$mock_bin/ffprobe"

exit_code=0
output=$(PATH="$mock_bin:$PATH" bash "$SCRIPT" "$tmpdir" --prompt "Test ambient" 2>&1) || exit_code=$?

if [ "$exit_code" -eq 0 ]; then
    pass "Script exits 0 on auth failure"
else
    fail "Script exited $exit_code, expected 0"
fi

if echo "$output" | grep -qi "auth"; then
    pass "Output contains 'auth' warning"
else
    fail "Output missing 'auth' keyword: $output"
fi

rm -rf "$tmpdir" "$mock_bin"

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}=== mix-bgm.test.sh Results ===${NC}"
echo -e "  Passed: ${GREEN}$PASS${NC}"
echo -e "  Failed: ${RED}$FAIL${NC}"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
echo -e "${GREEN}ALL PASSED${NC}"
