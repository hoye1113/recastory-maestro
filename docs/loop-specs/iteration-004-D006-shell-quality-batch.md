# D-006: Shell Script Quality Batch Fix

## Metadata

- Iteration: 4
- Track: D (Shell Script Quality)
- Severity: warning
- Created: 2026-05-30

## Problem

Structural scan revealed 8 shell script quality issues across 7 files:

1. **Template TTS providers** (web-video-presentation): 2 files missing shebang + `set -euo pipefail`
2. **Unquoted variables**: 4 files have unquoted variable expansions that break on spaces/globs
3. **nuwa-skill download_subtitles.sh**: Missing `-uo pipefail`, brittle `/tmp/.ytdlp_marker` logic

## Root Cause

- Template scripts were written as function libraries (sourced, not executed), so shebangs were omitted
- Unquoted variables are legacy patterns from early prototyping
- download_subtitles.sh uses a marker file approach that predates the project's pipefail convention

## Affected Files

| File | Issue | Fix |
|------|-------|-----|
| `skills/web-video-presentation/templates/scripts/tts-providers/minimax.sh` | No shebang, no pipefail | Add `#!/usr/bin/env bash` + `set -euo pipefail` |
| `skills/web-video-presentation/templates/scripts/tts-providers/openai.sh` | No shebang, no pipefail | Add `#!/usr/bin/env bash` + `set -euo pipefail` |
| `tools/capture-screenshots.sh:34,38` | `kill $VITE_PID` unquoted | `kill "$VITE_PID"` |
| `skills/storyboard/scaffold.sh:44-47` | `$line`, `$ch_id`, `$ch_title`, `$ch_steps` unquoted | Quote all variables in while loop |
| `scripts/tts-providers/piper-tts.sh:35` | `$1` unquoted in test | `[ -n "$1" ]` |
| `scripts/tts-providers/minimax.sh:34` | `$1` unquoted in test | `[ -n "$1" ]` |
| `skills/nuwa-skill/scripts/download_subtitles.sh:7` | `set -e` only | `set -euo pipefail` |
| `skills/nuwa-skill/scripts/download_subtitles.sh:27` | `/tmp/.ytdlp_marker` may not exist | Use `touch` to create marker before download, or switch to timestamp-based approach |

## Fix Strategy

### Template TTS providers (minimax.sh, openai.sh)

These are function libraries sourced by a runner script. Adding shebang + pipefail is defensive:

```bash
#!/usr/bin/env bash
set -euo pipefail
# ... existing content ...
```

### Unquoted variables

Standard quoting fixes:

```bash
# capture-screenshots.sh
trap 'kill "$VITE_PID" 2>/dev/null || true' EXIT
# ...
kill "$VITE_PID" 2>/dev/null || true

# scaffold.sh while loop
while IFS= read -r line; do
  if echo "$line" | grep -qE '^## [0-9]+\. '; then
    ch_id=$(echo "$line" | sed -E 's/^## [0-9]+\. ([a-z-]+) —.*/\1/')
    # ... all variables already quoted in command substitutions
```

### download_subtitles.sh marker fix

Replace brittle marker file with timestamp-based approach:

```bash
# Before download: record timestamp
MARKER=$(mktemp)
trap 'rm -f "$MARKER"' EXIT

# After download: find files newer than marker
FOUND=$(find "$OUTPUT_DIR" -name "*.srt" -newer "$MARKER" 2>/dev/null | head -1)
```

## Acceptance Criteria

- [ ] All 7 files pass `bash -n` syntax check
- [ ] `grep -n 'set -euo pipefail'` matches all 7 files
- [ ] `grep -rn 'kill \$VITE_PID' tools/` returns no unquoted matches
- [ ] `grep -rn '/tmp/.ytdlp_marker' skills/nuwa-skill/` returns no matches (replaced)
- [ ] No functional behavior change (same inputs → same outputs)

## Review Checklist

- [ ] Spec Compliance: all 8 issues addressed
- [ ] Code Quality: bash -n passes on all files
- [ ] Runtime Neutrality: no platform-specific assumptions added

## Regression Risk

Low. All changes are defensive quoting/pipefail additions. Template scripts are function libraries — adding shebang doesn't affect sourcing behavior. The marker file fix changes only the detection logic, not the download logic.
