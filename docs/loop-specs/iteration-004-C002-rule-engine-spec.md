# C-002: DS/CH/SB Rule Engine Implementation Spec

## Metadata

- Iteration: 4 (spec only, deferred to v3.1.0)
- Track: C (Anti-Pattern ID Resolution)
- Severity: warning
- Created: 2026-05-30

## Problem

ARCHITECTURE.md defines 17 anti-pattern rules across 3 rule sets that are not implemented in `tools/audit/rules.py`:

| Rule Set | Rules | Current Status |
|----------|-------|---------------|
| DS (distill-style) | DS-001~006 | ❌ Not implemented |
| CH (chapter visual) | CH-001~006 | ❌ Not implemented |
| SB (storyboard design) | SB-001~005 | ❌ Not implemented |

Currently, `audit` skill only validates render/ingest/voice rules (RV-001~004). Design/storyboard violations are caught only by LLM critique, which is non-deterministic.

## Root Cause

Rule definitions exist in ARCHITECTURE.md but were deferred during v3.0.0 to focus on render pipeline. The rules.py file only implements RV (render validation) rules.

## Rule Definitions (from ARCHITECTURE.md)

### DS-001~006 (Distill-Style Rules)

| ID | Rule | Detection Method |
|----|------|-----------------|
| DS-001 | No fake empathy ("我理解你的感受") | Regex pattern match |
| DS-002 | No fake depth ("让我们深入思考") | Regex pattern match |
| DS-003 | No self-promotion ("作为AI") | Regex pattern match |
| DS-004 | No universal template ("无论你是谁") | Regex pattern match |
| DS-005 | No parallelism abuse (3+ parallel clauses) | Sentence structure analysis |
| DS-006 | No cliché endings ("让我们一起") | Regex pattern match |

### CH-001~006 (Chapter Visual Rules)

| ID | Rule | Detection Method |
|----|------|-----------------|
| CH-001 | No purple-pink gradient | CSS property scan |
| CH-002 | No rounded colorful borders | CSS property scan |
| CH-003 | No emoji in hero text | Text content scan |
| CH-004 | No full-stage fade (every step) | Animation pattern scan |
| CH-005 | No cliché transition phrases | Text content scan |
| CH-006 | Max 3 visual elements per step | DOM structure analysis |

### SB-001~005 (Storyboard Design Rules)

| ID | Rule | Detection Method |
|----|------|-----------------|
| SB-001 | Each chapter has distinct visual identity | Color/layout comparison |
| SB-002 | No two consecutive identical layouts | Step structure comparison |
| SB-003 | Hero text ≤ 15 chars per line | Text length check |
| SB-004 | Max 6 steps per chapter | Step count check |
| SB-005 | Progressive disclosure (info density increases) | Content density analysis |

## Implementation Strategy

### Phase 1: DS Rules (Regex-based, lowest complexity)

```python
# In tools/audit/rules.py

DS_PATTERNS = {
    "DS-001": r"我理解你的?感受|我能体会到",
    "DS-002": r"让我们深入思考|深入探讨一下",
    "DS-003": r"作为AI|作为一个AI|作为语言模型",
    "DS-004": r"无论你是谁|不管你是谁|每个人都知道",
    "DS-006": r"让我们一起|让我们携手|共同(?:前进|努力)",
}

def check_ds_rules(text: str) -> list[RuleViolation]:
    violations = []
    for rule_id, pattern in DS_PATTERNS.items():
        matches = re.findall(pattern, text)
        if matches:
            violations.append(RuleViolation(
                rule_id=rule_id,
                severity="warning",
                message=f"Pattern matched: {matches[0]}",
                file="script.md",
            ))
    return violations
```

### Phase 2: CH Rules (CSS/Text scan, medium complexity)

```python
CH_CSS_PATTERNS = {
    "CH-001": r"linear-gradient.*(?:purple|pink|#(?:a|b|c)[0-9a-f]{3})",
    "CH-002": r"border(?:-radius)?:\s*(?:\d+px\s+)?(?:#[0-9a-f]{3,6}|rgb)",
}

def check_ch_rules(chapter_dir: str) -> list[RuleViolation]:
    violations = []
    css_file = os.path.join(chapter_dir, "Chapter.css")
    tsx_file = os.path.join(chapter_dir, "Chapter.tsx")

    if os.path.exists(css_file):
        css_content = read_file(css_file)
        for rule_id, pattern in CH_CSS_PATTERNS.items():
            if re.search(pattern, css_content, re.IGNORECASE):
                violations.append(RuleViolation(...))

    if os.path.exists(tsx_file):
        tsx_content = read_file(tsx_file)
        # CH-003: emoji in hero text
        emoji_pattern = r"[\U0001F600-\U0001F64F\U0001F300-\U0001F5FF]"
        hero_match = re.search(r'className="[^"]*hero[^"]*"[^>]*>([^<]+)', tsx_content)
        if hero_match and re.search(emoji_pattern, hero_match.group(1)):
            violations.append(RuleViolation(rule_id="CH-003", ...))

    return violations
```

### Phase 3: SB Rules (Structure analysis, highest complexity)

SB rules require cross-chapter comparison and content analysis. These are best implemented as Python functions that parse the storyboard structure:

```python
def check_sb_rules(storyboard_dir: str) -> list[RuleViolation]:
    violations = []
    chapters = get_chapters(storyboard_dir)

    # SB-004: Max 6 steps per chapter
    for ch in chapters:
        step_count = count_steps(ch)
        if step_count > 6:
            violations.append(RuleViolation(
                rule_id="SB-004",
                severity="warning",
                message=f"Chapter {ch.id} has {step_count} steps (max 6)",
            ))

    # SB-002: No consecutive identical layouts
    for i in range(len(chapters) - 1):
        if layout_similarity(chapters[i], chapters[i+1]) > 0.8:
            violations.append(RuleViolation(
                rule_id="SB-002",
                severity="warning",
                message=f"Chapters {chapters[i].id} and {chapters[i+1].id} have similar layouts",
            ))

    return violations
```

## Integration with Existing rules.py

```python
# Add to VV_RULE_IDS
VV_RULE_IDS = [
    # Existing RV rules
    "RV-001", "RV-002", "RV-003", "RV-004",
    # New DS rules
    "DS-001", "DS-002", "DS-003", "DS-004", "DS-005", "DS-006",
    # New CH rules
    "CH-001", "CH-002", "CH-003", "CH-004", "CH-005", "CH-006",
    # New SB rules
    "SB-001", "SB-002", "SB-003", "SB-004", "SB-005",
]

# Add to run_all_checks()
def run_all_checks(workspace: str) -> list[RuleViolation]:
    violations = []
    violations.extend(check_render_rules(workspace))
    violations.extend(check_distill_rules(workspace))  # NEW
    violations.extend(check_chapter_rules(workspace))   # NEW
    violations.extend(check_storyboard_rules(workspace)) # NEW
    return violations
```

## Affected Files

| File | Change |
|------|--------|
| `tools/audit/rules.py` | Add DS/CH/SB rule functions + VV_RULE_IDS update |
| `ARCHITECTURE.md` | Update rule status table (all ✅) |

## Acceptance Criteria

- [ ] All 17 new rules implemented in rules.py
- [ ] `python tools/audit/rules.py --list` shows all 21 rules (4 RV + 6 DS + 6 CH + 5 SB)
- [ ] DS rules detect test patterns (IIFE test cases)
- [ ] CH rules detect CSS violations in test fixtures
- [ ] SB rules detect structural violations in test fixtures
- [ ] Existing RV rules still pass (no regression)

## Review Checklist

- [ ] Spec Compliance: all 17 rules implemented
- [ ] Code Quality: Python syntax valid, no dead code
- [ ] Runtime Neutrality: no hardcoded paths beyond project conventions

## Regression Risk

Medium. Adding rules increases audit strictness — existing workspaces that previously passed may now fail. This is expected behavior (audit is a quality gate, not a pass-through).

## Deferred To

v3.1.0 Iteration 1 (ROADMAP.md Phase 3). Requires:
- Test fixtures for each rule set
- Integration with `recastory audit` command
- darwin-skill evaluation of rule coverage
