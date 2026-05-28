#!/bin/bash
# tools/research-search.test.sh
# Tests for research-search.sh
# Validates argument parsing, input validation, and script syntax.
# Does NOT test actual mmx search (requires mmx CLI + auth).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEARCH_SCRIPT="$SCRIPT_DIR/research-search.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

pass() { echo -e "  ${GREEN}PASS${NC} $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo -e "  ${RED}FAIL${NC} $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }

# ── Test 1: Script exists ────────────────────────────────────────────────────
test_script_exists() {
    echo -e "\n${YELLOW}Test 1: Script exists${NC}"
    if [ -f "$SEARCH_SCRIPT" ]; then
        pass "research-search.sh exists"
    else
        fail "research-search.sh not found at $SEARCH_SCRIPT"
    fi
}

# ── Test 2: Syntax check (bash -n) ──────────────────────────────────────────
test_syntax_check() {
    echo -e "\n${YELLOW}Test 2: Syntax check${NC}"
    if bash -n "$SEARCH_SCRIPT" 2>&1; then
        pass "Script syntax is valid"
    else
        fail "Script has syntax errors"
    fi
}

# ── Test 3: No arguments shows usage ─────────────────────────────────────────
test_no_args() {
    echo -e "\n${YELLOW}Test 3: No arguments shows usage${NC}"
    local output
    output=$(bash "$SEARCH_SCRIPT" 2>&1) && true
    if echo "$output" | grep -qi "usage\|Usage"; then
        pass "No arguments shows usage message"
    else
        fail "Expected usage message, got: $output"
    fi
}

# ── Test 4: --help shows usage ───────────────────────────────────────────────
test_help_flag() {
    echo -e "\n${YELLOW}Test 4: --help shows usage${NC}"
    local output
    output=$(bash "$SEARCH_SCRIPT" --help 2>&1) && true
    if echo "$output" | grep -qi "usage\|help"; then
        pass "--help shows usage message"
    else
        fail "Expected help message, got: $output"
    fi
}

# ── Test 5: -h shows usage ───────────────────────────────────────────────────
test_h_flag() {
    echo -e "\n${YELLOW}Test 5: -h shows usage${NC}"
    local output
    output=$(bash "$SEARCH_SCRIPT" -h 2>&1) && true
    if echo "$output" | grep -qi "usage\|help"; then
        pass "-h shows usage message"
    else
        fail "Expected help message, got: $output"
    fi
}

# ── Test 6: --max with non-numeric shows error ───────────────────────────────
test_max_non_numeric() {
    echo -e "\n${YELLOW}Test 6: --max with non-numeric shows error${NC}"
    local output
    output=$(bash "$SEARCH_SCRIPT" "test" --max abc 2>&1) && true
    if echo "$output" | grep -qi "positive integer\|ERROR"; then
        pass "Non-numeric --max shows error"
    else
        fail "Expected error for non-numeric --max, got: $output"
    fi
}

# ── Test 7: --max with zero shows error ──────────────────────────────────────
test_max_zero() {
    echo -e "\n${YELLOW}Test 7: --max with zero shows error${NC}"
    local output
    output=$(bash "$SEARCH_SCRIPT" "test" --max 0 2>&1) && true
    if echo "$output" | grep -qi "positive integer\|ERROR"; then
        pass "Zero --max shows error"
    else
        fail "Expected error for zero --max, got: $output"
    fi
}

# ── Test 8: Unknown option shows error ───────────────────────────────────────
test_unknown_option() {
    echo -e "\n${YELLOW}Test 8: Unknown option shows error${NC}"
    local output
    output=$(bash "$SEARCH_SCRIPT" "test" --unknown 2>&1) && true
    if echo "$output" | grep -qi "unknown option\|usage\|ERROR"; then
        pass "Unknown option shows error"
    else
        fail "Expected error for unknown option, got: $output"
    fi
}

# ── Test 9: --max without value shows error ──────────────────────────────────
test_max_missing_value() {
    echo -e "\n${YELLOW}Test 9: --max without value shows error${NC}"
    local output
    output=$(bash "$SEARCH_SCRIPT" "test" --max 2>&1) && true
    if echo "$output" | grep -qi "requires\|usage\|ERROR"; then
        pass "--max without value shows error"
    else
        fail "Expected error for --max without value, got: $output"
    fi
}

# ── Test 10: --out without value shows error ─────────────────────────────────
test_out_missing_value() {
    echo -e "\n${YELLOW}Test 10: --out without value shows error${NC}"
    local output
    output=$(bash "$SEARCH_SCRIPT" "test" --out 2>&1) && true
    if echo "$output" | grep -qi "requires\|usage\|ERROR"; then
        pass "--out without value shows error"
    else
        fail "Expected error for --out without value, got: $output"
    fi
}

# ── Test 11: mmx not found shows error ───────────────────────────────────────
test_mmx_not_found() {
    echo -e "\n${YELLOW}Test 11: mmx not found shows error${NC}"
    # Create a PATH that has bash and node but no mmx.
    # On Git Bash, bash is in /usr/bin and node is alongside mmx in nodejs dir.
    # We copy/symlink only node into a stub dir, then use stub + /usr/bin.
    local stub_dir
    stub_dir=$(mktemp -d)
    local node_path
    node_path=$(command -v node)
    # Create a wrapper script for node in stub dir
    cat > "$stub_dir/node" << NODEWRAP
#!/usr/bin/bash
exec "$node_path" "\$@"
NODEWRAP
    chmod +x "$stub_dir/node"
    local output
    output=$(PATH="$stub_dir:/usr/bin:/bin" bash "$SEARCH_SCRIPT" "test" 2>&1) && true
    if echo "$output" | grep -qi "mmx.*not installed\|not in PATH\|ERROR"; then
        pass "Missing mmx shows error"
    else
        fail "Expected mmx not found error, got: $output"
    fi
    rm -rf "$stub_dir"
}

# ── Test 12: Mocked mmx search integration ───────────────────────────────────
test_mocked_search() {
    echo -e "\n${YELLOW}Test 12: Mocked mmx search integration${NC}"

    local tmpdir
    tmpdir=$(mktemp -d)

    # Create mock mmx that returns sample search results
    cat > "$tmpdir/mmx" << 'STUB'
#!/bin/bash
# Mock mmx for testing
if [ "${1:-}" = "auth" ] && [ "${2:-}" = "status" ]; then
    exit 0
fi
if [ "${1:-}" = "search" ] && [ "${2:-}" = "query" ]; then
    cat << 'JSON'
{
  "organic": [
    {
      "title": "Test Result 1",
      "link": "https://example.com/1",
      "snippet": "First test result",
      "date": "2026-05-28"
    },
    {
      "title": "Test Result 2",
      "link": "https://example.com/2",
      "snippet": "Second test result",
      "date": "2026-05-27"
    },
    {
      "title": "Test Result 3",
      "link": "https://example.com/3",
      "snippet": "Third test result",
      "date": "2026-05-26"
    }
  ],
  "related_searches": [
    {"query": "related term 1"},
    {"query": "related term 2"}
  ],
  "base_resp": {
    "status_code": 0,
    "status_msg": "success"
  }
}
JSON
    exit 0
fi
echo "stub mmx: unexpected args: $@" >&2
exit 1
STUB
    chmod +x "$tmpdir/mmx"

    local output
    output=$(PATH="$tmpdir:$PATH" bash "$SEARCH_SCRIPT" "test query" 2>/dev/null) || true

    # Validate output contains expected structure
    local check_ok=true
    if ! echo "$output" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); process.exit(d.query==='test query' && d.results && d.results.length===3 ? 0 : 1)" 2>/dev/null; then
        check_ok=false
    fi

    if [ "$check_ok" = true ]; then
        pass "Mocked search returns correct structure"
    else
        fail "Mocked search output incorrect: $output"
    fi

    rm -rf "$tmpdir"
}

# ── Test 13: --max limits results ────────────────────────────────────────────
test_max_limits_results() {
    echo -e "\n${YELLOW}Test 13: --max limits results${NC}"

    local tmpdir
    tmpdir=$(mktemp -d)

    cat > "$tmpdir/mmx" << 'STUB'
#!/bin/bash
if [ "${1:-}" = "auth" ] && [ "${2:-}" = "status" ]; then exit 0; fi
if [ "${1:-}" = "search" ] && [ "${2:-}" = "query" ]; then
    cat << 'JSON'
{
  "organic": [
    {"title": "R1", "link": "https://a.com", "snippet": "s1", "date": "2026-01-01"},
    {"title": "R2", "link": "https://b.com", "snippet": "s2", "date": "2026-01-02"},
    {"title": "R3", "link": "https://c.com", "snippet": "s3", "date": "2026-01-03"}
  ],
  "base_resp": {"status_code": 0, "status_msg": "success"}
}
JSON
    exit 0
fi
exit 1
STUB
    chmod +x "$tmpdir/mmx"

    local output
    output=$(PATH="$tmpdir:$PATH" bash "$SEARCH_SCRIPT" "test" --max 2 2>/dev/null) || true

    local count
    count=$(echo "$output" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); console.log(d.total);" 2>/dev/null) || count="error"

    if [ "$count" = "2" ]; then
        pass "--max 2 limits results to 2"
    else
        fail "Expected total=2, got: $count"
    fi

    rm -rf "$tmpdir"
}

# ── Test 14: --related includes related searches ─────────────────────────────
test_related_flag() {
    echo -e "\n${YELLOW}Test 14: --related includes related searches${NC}"

    local tmpdir
    tmpdir=$(mktemp -d)

    cat > "$tmpdir/mmx" << 'STUB'
#!/bin/bash
if [ "${1:-}" = "auth" ] && [ "${2:-}" = "status" ]; then exit 0; fi
if [ "${1:-}" = "search" ] && [ "${2:-}" = "query" ]; then
    cat << 'JSON'
{
  "organic": [
    {"title": "R1", "link": "https://a.com", "snippet": "s1", "date": "2026-01-01"}
  ],
  "related_searches": [
    {"query": "alpha"},
    {"query": "beta"}
  ],
  "base_resp": {"status_code": 0, "status_msg": "success"}
}
JSON
    exit 0
fi
exit 1
STUB
    chmod +x "$tmpdir/mmx"

    local output
    output=$(PATH="$tmpdir:$PATH" bash "$SEARCH_SCRIPT" "test" --related 2>/dev/null) || true

    local has_related
    has_related=$(echo "$output" | node -e "
        const d=JSON.parse(require('fs').readFileSync(0,'utf8'));
        console.log(d.related && d.related.length === 2 ? 'yes' : 'no');
    " 2>/dev/null) || has_related="error"

    if [ "$has_related" = "yes" ]; then
        pass "--related includes related_searches"
    else
        fail "Expected related array with 2 items, got: $output"
    fi

    rm -rf "$tmpdir"
}

# ── Test 15: --out writes to file ────────────────────────────────────────────
test_out_to_file() {
    echo -e "\n${YELLOW}Test 15: --out writes to file${NC}"

    local tmpdir
    tmpdir=$(mktemp -d)

    cat > "$tmpdir/mmx" << 'STUB'
#!/bin/bash
if [ "${1:-}" = "auth" ] && [ "${2:-}" = "status" ]; then exit 0; fi
if [ "${1:-}" = "search" ] && [ "${2:-}" = "query" ]; then
    cat << 'JSON'
{"organic":[{"title":"T","link":"https://x.com","snippet":"s","date":"2026-01-01"}],"base_resp":{"status_code":0,"status_msg":"success"}}
JSON
    exit 0
fi
exit 1
STUB
    chmod +x "$tmpdir/mmx"

    local outfile="$tmpdir/results.json"
    local output
    output=$(PATH="$tmpdir:$PATH" bash "$SEARCH_SCRIPT" "test" --out "$outfile" 2>&1) || true

    if [ -f "$outfile" ]; then
        local content
        content=$(cat "$outfile")
        if echo "$content" | node -e "const d=JSON.parse(require('fs').readFileSync(0,'utf8')); process.exit(d.query==='test' ? 0 : 1)" 2>/dev/null; then
            pass "--out writes valid JSON to file"
        else
            fail "File content is not valid JSON: $content"
        fi
    else
        fail "Output file not created: $outfile"
    fi

    rm -rf "$tmpdir"
}

# ── Test 16: Without --related, no related field ─────────────────────────────
test_no_related_by_default() {
    echo -e "\n${YELLOW}Test 16: Without --related, no related field${NC}"

    local tmpdir
    tmpdir=$(mktemp -d)

    cat > "$tmpdir/mmx" << 'STUB'
#!/bin/bash
if [ "${1:-}" = "auth" ] && [ "${2:-}" = "status" ]; then exit 0; fi
if [ "${1:-}" = "search" ] && [ "${2:-}" = "query" ]; then
    cat << 'JSON'
{
  "organic": [{"title":"T","link":"https://x.com","snippet":"s","date":"2026-01-01"}],
  "related_searches": [{"query":"alpha"}],
  "base_resp": {"status_code": 0, "status_msg": "success"}
}
JSON
    exit 0
fi
exit 1
STUB
    chmod +x "$tmpdir/mmx"

    local output
    output=$(PATH="$tmpdir:$PATH" bash "$SEARCH_SCRIPT" "test" 2>/dev/null) || true

    local has_related
    has_related=$(echo "$output" | node -e "
        const d=JSON.parse(require('fs').readFileSync(0,'utf8'));
        console.log(d.related ? 'yes' : 'no');
    " 2>/dev/null) || has_related="error"

    if [ "$has_related" = "no" ]; then
        pass "Without --related, related field is absent"
    else
        fail "Expected no related field, got: $output"
    fi

    rm -rf "$tmpdir"
}

# ── Main test runner ─────────────────────────────────────────────────────────
main() {
    echo -e "${YELLOW}=== research-search.sh tests ===${NC}"

    test_script_exists
    test_syntax_check
    test_no_args
    test_help_flag
    test_h_flag
    test_max_non_numeric
    test_max_zero
    test_unknown_option
    test_max_missing_value
    test_out_missing_value
    test_mmx_not_found
    test_mocked_search
    test_max_limits_results
    test_related_flag
    test_out_to_file
    test_no_related_by_default

    echo ""
    echo -e "${YELLOW}=== Test Summary ===${NC}"
    echo -e "  Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  Failed: ${RED}$TESTS_FAILED${NC}"

    if [ $TESTS_FAILED -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

main "$@"
