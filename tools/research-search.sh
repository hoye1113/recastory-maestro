#!/bin/bash
# tools/research-search.sh
# Wraps `mmx search query` for structured web search with JSON output.
# Usage: bash research-search.sh <query> [--max <n>] [--out <path>] [--related]
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }

usage() {
    echo "Usage: bash research-search.sh <query> [--max <n>] [--out <path>] [--related]"
    echo ""
    echo "  <query>        Required: search query string"
    echo "  --max <n>      Maximum results (default: 10)"
    echo "  --out <path>   Output to file (default: stdout)"
    echo "  --related      Include related search terms"
    echo ""
    echo "Examples:"
    echo "  bash research-search.sh \"AI news\""
    echo "  bash research-search.sh \"气候数据\" --max 5 --related"
    echo "  bash research-search.sh \"案例分析\" --out results.json"
    exit 1
}

# ── Parse arguments ───────────────────────────────────────────────────────────
parse_args() {
    local query=""
    local max_results=10
    local out_path=""
    local include_related=false

    while [ $# -gt 0 ]; do
        case "$1" in
            --max)
                [ $# -ge 2 ] || { log_error "--max requires a number"; usage; }
                max_results="$2"
                # Validate numeric
                if ! [[ "$max_results" =~ ^[0-9]+$ ]] || [ "$max_results" -lt 1 ]; then
                    log_error "--max must be a positive integer, got: $max_results"
                    exit 1
                fi
                shift 2
                ;;
            --out)
                [ $# -ge 2 ] || { log_error "--out requires a path"; usage; }
                out_path="$2"
                shift 2
                ;;
            --related)
                include_related=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                ;;
            *)
                if [ -z "$query" ]; then
                    query="$1"
                else
                    log_error "Unexpected argument: $1"
                    usage
                fi
                shift
                ;;
        esac
    done

    if [ -z "$query" ]; then
        log_error "Missing required argument: <query>"
        usage
    fi

    # Export parsed values
    PARSED_QUERY="$query"
    PARSED_MAX="$max_results"
    PARSED_OUT="$out_path"
    PARSED_RELATED="$include_related"
}

# ── Validate dependencies ────────────────────────────────────────────────────
validate_deps() {
    if ! command -v mmx >/dev/null 2>&1; then
        log_error "mmx CLI not installed or not in PATH"
        exit 1
    fi

    if ! command -v node >/dev/null 2>&1; then
        log_error "Node.js not installed or not in PATH"
        exit 1
    fi

    if ! mmx auth status >/dev/null 2>&1; then
        log_error "mmx authentication failed. Run 'mmx auth login' first."
        exit 1
    fi
}

# ── Execute search ───────────────────────────────────────────────────────────
do_search() {
    local query="$1"
    local max_results="$2"
    local include_related="$3"

    # Call mmx search
    log_info "Searching: $query"
    local raw_json
    raw_json=$(mmx search query --q "$query" --output json --quiet 2>/dev/null) || {
        log_error "mmx search query failed"
        exit 1
    }

    # Validate JSON response
    if [ -z "$raw_json" ]; then
        log_error "Empty response from mmx search"
        exit 1
    fi

    # Check for error in response
    local status_code
    status_code=$(echo "$raw_json" | node -e "
        const d = JSON.parse(require('fs').readFileSync(0,'utf8'));
        console.log((d.base_resp || {}).status_code || 0);
    " 2>/dev/null) || {
        log_error "Failed to parse mmx response"
        exit 1
    }

    if [ "$status_code" != "0" ]; then
        local status_msg
        status_msg=$(echo "$raw_json" | node -e "
            const d = JSON.parse(require('fs').readFileSync(0,'utf8'));
            console.log((d.base_resp || {}).status_msg || 'unknown error');
        " 2>/dev/null)
        log_error "mmx search returned error: $status_msg"
        exit 1
    fi

    # Transform to our output format using node
    local result
    result=$(echo "$raw_json" | node -e "
        const d = JSON.parse(require('fs').readFileSync(0,'utf8'));
        const max = parseInt(process.argv[1], 10);
        const includeRelated = process.argv[2] === 'true';
        const query = process.argv[3];

        const organic = (d.organic || []).slice(0, max);
        const results = organic.map(r => ({
            title: r.title || '',
            link: r.link || '',
            snippet: r.snippet || '',
            date: r.date || ''
        }));

        const out = {
            query: query,
            results: results,
            total: results.length
        };

        if (includeRelated) {
            out.related = (d.related_searches || []).map(r => typeof r === 'string' ? r : r.query || '');
        }

        console.log(JSON.stringify(out, null, 2));
    " "$max_results" "$include_related" "$query" 2>/dev/null) || {
        log_error "Failed to transform search results"
        exit 1
    }

    echo "$result"
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    parse_args "$@"
    validate_deps

    local result
    result=$(do_search "$PARSED_QUERY" "$PARSED_MAX" "$PARSED_RELATED")

    if [ -n "$PARSED_OUT" ]; then
        # Output to file
        local out_dir
        out_dir=$(dirname "$PARSED_OUT")
        if [ "$out_dir" != "." ] && [ ! -d "$out_dir" ]; then
            mkdir -p "$out_dir"
        fi
        echo "$result" > "$PARSED_OUT"
        log_info "Results written to: $PARSED_OUT"
    else
        # Output to stdout
        echo "$result"
    fi
}

main "$@"
