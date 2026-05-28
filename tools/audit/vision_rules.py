"""VV-series rules: Visual Verification via mmx vision.

These rules analyze storyboard screenshots using mmx vision describe
to detect visual quality issues (AI fingerprints, contrast, placeholders,
information density, etc.).

Graceful degradation:
- mmx CLI not installed -> skip all VV rules
- mmx auth fails -> skip all VV rules
- Single vision call fails -> skip that rule, continue others
- Screenshot dir missing -> skip all VV rules
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from dataclasses import dataclass
from typing import Optional, Union


@dataclass
class VisionResult:
    """Result from a VV vision rule check."""
    rule_id: str
    status: str  # "pass", "warn", "fail", "skip"
    message: str
    file: Optional[str] = None


def _call_vision(image_path: str, prompt: str) -> Union[str, dict, None]:
    """Call mmx vision describe and return the description text.

    Returns:
        str: the description text on success
        dict: error info dict with 'error' and 'message' keys for known failures
        None: if mmx is unavailable or the call fails generically
    """
    try:
        result = subprocess.run(
            ["mmx", "vision", "describe", "--image", image_path, "--prompt", prompt, "--output", "json", "--quiet"],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode != 0:
            if result.returncode == 4:
                return {"error": "quota_exhausted", "message": "mmx vision quota exhausted. Retry later."}
            elif result.returncode == 3:
                return {"error": "auth_failed", "message": "mmx authentication failed. Run 'mmx auth login'."}
            else:
                return None  # generic failure, treat as unavailable
        data = json.loads(result.stdout)
        return data.get("description") or data.get("content") or ""
    except (subprocess.TimeoutExpired, json.JSONDecodeError, FileNotFoundError):
        return None


def _mmx_available() -> bool:
    """Check if mmx CLI is installed and authenticated."""
    try:
        result = subprocess.run(["mmx", "auth", "status"], capture_output=True, timeout=10)
        return result.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def detect_vv001_ai_fingerprint(image_path: str) -> VisionResult:
    """VV-001: Detect AI visual fingerprints.

    Checks for purple-pink gradients, rounded cards with colored left borders,
    emoji used as icons, gradient buttons with pill shapes, generic stock aesthetics.
    Maps to CH-001, CH-003.
    """
    prompt = (
        "Analyze this slide for AI-generated visual clichés. "
        "Check for: (1) purple-pink gradients, (2) rounded cards with colored left borders, "
        "(3) emoji used as icons, (4) gradient buttons with pill shapes, "
        "(5) generic stock photo aesthetics. "
        "Reply with PASS if none found, or FAIL with specific issues."
    )
    desc = _call_vision(image_path, prompt)
    if desc is None:
        return VisionResult("VV-001", "skip", "mmx vision unavailable", image_path)
    if isinstance(desc, dict) and "error" in desc:
        if desc["error"] == "quota_exhausted":
            return VisionResult("VV-001", "skip", "mmx vision quota exhausted. Retry later.", image_path)
        return VisionResult("VV-001", "skip", desc["message"], image_path)
    status = "fail" if "FAIL" in desc.upper() else "pass"
    return VisionResult("VV-001", status, desc[:200], image_path)


def detect_vv002_info_density(image_path: str) -> VisionResult:
    """VV-002: Detect uniform information density across steps.

    Counts visual elements per step. Maps to CH-003.
    """
    prompt = (
        "Count the number of distinct visual elements on this slide (text blocks, "
        "images, charts, cards, icons). Reply with just a number."
    )
    desc = _call_vision(image_path, prompt)
    if desc is None:
        return VisionResult("VV-002", "skip", "mmx vision unavailable", image_path)
    if isinstance(desc, dict) and "error" in desc:
        if desc["error"] == "quota_exhausted":
            return VisionResult("VV-002", "skip", "mmx vision quota exhausted. Retry later.", image_path)
        return VisionResult("VV-002", "skip", desc["message"], image_path)
    try:
        count = int(''.join(c for c in desc if c.isdigit()))
        if count > 10:
            return VisionResult("VV-002", "warn", f"High element count: {count}", image_path)
        return VisionResult("VV-002", "pass", f"Element count: {count}", image_path)
    except ValueError:
        return VisionResult("VV-002", "skip", f"Could not parse count: {desc[:100]}", image_path)


def detect_vv003_placeholder(image_path: str) -> VisionResult:
    """VV-003: Detect placeholder cards not replaced with real images.

    Checks for text like 'image . 16:9 description' or 'placeholder'.
    Maps to SB-005.
    """
    prompt = (
        "Does this slide contain a placeholder card (a card showing text like "
        "'image . 16:9 description' or 'placeholder')? "
        "Reply PASS if no placeholder found, FAIL if placeholder detected."
    )
    desc = _call_vision(image_path, prompt)
    if desc is None:
        return VisionResult("VV-003", "skip", "mmx vision unavailable", image_path)
    if isinstance(desc, dict) and "error" in desc:
        if desc["error"] == "quota_exhausted":
            return VisionResult("VV-003", "skip", "mmx vision quota exhausted. Retry later.", image_path)
        return VisionResult("VV-003", "skip", desc["message"], image_path)
    status = "fail" if "FAIL" in desc.upper() else "pass"
    return VisionResult("VV-003", status, desc[:200], image_path)


def detect_vv004_ending_screen(image_path: str) -> VisionResult:
    """VV-004: Detect template ending screens.

    Checks for generic 'Thank you', progress bar at 100%, 'The End', 'Q&A'.
    Maps to CH-004.
    """
    prompt = (
        "Is this slide a generic ending screen (e.g., 'Thank you', 'Thanks', "
        "progress bar at 100%, 'The End', 'Q&A')? "
        "Reply PASS if it has real content, FAIL if it's a generic ending."
    )
    desc = _call_vision(image_path, prompt)
    if desc is None:
        return VisionResult("VV-004", "skip", "mmx vision unavailable", image_path)
    if isinstance(desc, dict) and "error" in desc:
        if desc["error"] == "quota_exhausted":
            return VisionResult("VV-004", "skip", "mmx vision quota exhausted. Retry later.", image_path)
        return VisionResult("VV-004", "skip", desc["message"], image_path)
    status = "fail" if "FAIL" in desc.upper() else "pass"
    return VisionResult("VV-004", status, desc[:200], image_path)


def detect_vv005_text_density(image_path: str) -> VisionResult:
    """VV-005: Detect excessive text on a single slide.

    Flags slides with >80 Chinese characters (or equivalent English words).
    Maps to SB-001.
    """
    prompt = (
        "Estimate the total Chinese character count (or English word count) "
        "visible on this slide. Reply with just a number."
    )
    desc = _call_vision(image_path, prompt)
    if desc is None:
        return VisionResult("VV-005", "skip", "mmx vision unavailable", image_path)
    if isinstance(desc, dict) and "error" in desc:
        if desc["error"] == "quota_exhausted":
            return VisionResult("VV-005", "skip", "mmx vision quota exhausted. Retry later.", image_path)
        return VisionResult("VV-005", "skip", desc["message"], image_path)
    try:
        count = int(''.join(c for c in desc if c.isdigit()))
        if count > 80:
            return VisionResult("VV-005", "fail", f"Text too dense: ~{count} chars", image_path)
        elif count > 50:
            return VisionResult("VV-005", "warn", f"Text moderately dense: ~{count} chars", image_path)
        return VisionResult("VV-005", "pass", f"Text count: ~{count} chars", image_path)
    except ValueError:
        return VisionResult("VV-005", "skip", f"Could not parse count: {desc[:100]}", image_path)


# Registry of all VV rule functions
VV_RULES = [
    detect_vv001_ai_fingerprint,
    detect_vv002_info_density,
    detect_vv003_placeholder,
    detect_vv004_ending_screen,
    detect_vv005_text_density,
]


def run_vv_rules(screenshot_dir: str) -> list[VisionResult]:
    """Run all VV rules on screenshots in the given directory.

    Graceful degradation:
    - mmx not available -> single skip result
    - dir not found -> single skip result
    - no screenshots -> single skip result
    - individual call failure -> that rule skips, others continue
    """
    results: list[VisionResult] = []
    if not _mmx_available():
        results.append(VisionResult("VV", "skip", "mmx CLI not available"))
        return results
    if not os.path.isdir(screenshot_dir):
        results.append(VisionResult("VV", "skip", f"Screenshot dir not found: {screenshot_dir}"))
        return results

    screenshots = sorted(f for f in os.listdir(screenshot_dir) if f.endswith('.png'))
    if not screenshots:
        results.append(VisionResult("VV", "skip", "No screenshots found"))
        return results

    any_quota = False
    for filename in screenshots:
        filepath = os.path.join(screenshot_dir, filename)
        for rule_fn in VV_RULES:
            result = rule_fn(filepath)
            if result.status == "skip" and "quota" in result.message.lower():
                any_quota = True
            results.append(result)

    all_skipped = all(r.status == "skip" for r in results)
    if all_skipped and any_quota:
        print("WARNING: mmx vision quota exhausted. VV rules skipped. Retry tomorrow.", file=sys.stderr)

    return results
