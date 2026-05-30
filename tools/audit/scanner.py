"""Workspace scanner for anti-pattern rules.

Scans workspace directories, maps file patterns to rule categories,
runs applicable rules, and produces an AuditReport.
"""
from __future__ import annotations

import glob
import json
import os
from dataclasses import dataclass, field
from pathlib import Path

from .rules import Rule, RuleResult, ALL_RULES, VV_RULE_IDS, get_rules_by_ids, get_rules_by_prefix


@dataclass
class AuditReport:
    workspace_dir: str
    total_files_scanned: int
    results: list[RuleResult] = field(default_factory=list)
    critical_count: int = 0
    warning_count: int = 0

    @property
    def passed(self) -> bool:
        return self.critical_count == 0


def scan_screenshots(workspace_dir: str) -> list[str]:
    """Scan for screenshot files in storyboard/screenshots/.

    Args:
        workspace_dir: Path to workspace directory.

    Returns:
        Sorted list of screenshot file paths.
    """
    pattern = os.path.join(workspace_dir, 'storyboard', 'screenshots', '*.png')
    return sorted(glob.glob(pattern))


def scan_workspace(
    workspace_dir: str,
    rule_ids: list[str] | None = None,
) -> AuditReport:
    """Scan workspace directory for anti-pattern violations.

    Args:
        workspace_dir: Path to workspace directory.
        rule_ids: Optional list of rule IDs to run. None = run all.

    Returns:
        AuditReport with all violations found.

    Raises:
        FileNotFoundError: If workspace_dir does not exist.
    """
    workspace = Path(workspace_dir)
    if not workspace.is_dir():
        raise FileNotFoundError(f'Workspace not found: {workspace_dir}')

    rules = get_rules_by_ids(rule_ids) if rule_ids else ALL_RULES
    report = AuditReport(workspace_dir=str(workspace), total_files_scanned=0)
    scanned_files: set[str] = set()  # deduplicate file counting

    # Map file patterns to applicable rule categories
    # VO rules only apply to audio-segments.json, not all JSON files
    md_rules = [r for r in rules if r.id.startswith(('TR-', 'CD-', 'SL-'))]
    srt_rules = [r for r in rules if r.id.startswith('TR-')]
    vo_rules = [r for r in rules if r.id.startswith('VO-')]

    def _apply_rules(file_path: Path, content: str, applicable_rules: list[Rule]) -> None:
        fkey = str(file_path)
        if fkey not in scanned_files:
            scanned_files.add(fkey)
            report.total_files_scanned += 1
        for rule in applicable_rules:
            violations = rule.detect(content, str(file_path))
            report.results.extend(violations)
            for v in violations:
                if v.severity == 'critical':
                    report.critical_count += 1
                else:
                    report.warning_count += 1

    # Scan .md files with TR/CD/SL rules
    if md_rules:
        for file_path in workspace.rglob('*.md'):
            if 'node_modules' in file_path.parts or '.git' in file_path.parts:
                continue
            content = file_path.read_text(encoding='utf-8', errors='replace')
            _apply_rules(file_path, content, md_rules)

    # Scan .srt files with TR rules
    if srt_rules:
        for file_path in workspace.rglob('*.srt'):
            if 'node_modules' in file_path.parts or '.git' in file_path.parts:
                continue
            content = file_path.read_text(encoding='utf-8', errors='replace')
            _apply_rules(file_path, content, srt_rules)

    # Scan audio-segments.json files with VO rules (not all .json files)
    if vo_rules:
        for file_path in workspace.rglob('audio-segments.json'):
            if 'node_modules' in file_path.parts or '.git' in file_path.parts:
                continue
            content = file_path.read_text(encoding='utf-8', errors='replace')
            _apply_rules(file_path, content, vo_rules)

    # Run class-based rules (DS, CH, SB) that use check(workspace_dir)
    _run_class_rules(workspace, report, rule_ids)

    # Run VV vision rules on screenshots (if any VV rule IDs requested)
    requested_vv = rule_ids is None or any(rid.startswith('VV-') for rid in rule_ids)
    if requested_vv:
        _run_vv_rules(workspace, report)

    return report


def _run_class_rules(workspace: Path, report: AuditReport, rule_ids: list[str] | None) -> None:
    """Run class-based rules (DS, CH, SB) that have a check(workspace_dir) method."""
    requested_set = set(rule_ids) if rule_ids else None
    for prefix in ('DS-', 'CH-', 'SB-'):
        prefix_rules = get_rules_by_prefix(prefix)
        for rid, info in prefix_rules.items():
            if requested_set is not None and rid not in requested_set:
                continue
            rule_cls = info["class"]
            if rule_cls is None:
                continue
            instance = rule_cls()
            if not hasattr(instance, 'check'):
                continue
            violations = instance.check(str(workspace))
            report.results.extend(violations)
            for v in violations:
                if v.severity == 'critical':
                    report.critical_count += 1
                else:
                    report.warning_count += 1


def _run_vv_rules(workspace: Path, report: AuditReport) -> None:
    """Run VV vision rules on screenshots and append results to report."""
    try:
        from .vision_rules import run_vv_rules, VisionResult
    except ImportError:
        return  # vision_rules module not available

    screenshot_dir = str(workspace / 'storyboard' / 'screenshots')
    vv_results = run_vv_rules(screenshot_dir)

    for vr in vv_results:
        if vr.status == 'skip':
            # Report skip for transparency (mmx unavailable) but don't count
            report.results.append(RuleResult(
                rule_id=vr.rule_id,
                name='VV visual check',
                severity='warning',
                file_path=vr.file or screenshot_dir,
                message=vr.message,
            ))
            continue
        severity = 'critical' if vr.status == 'fail' else 'warning'
        report.results.append(RuleResult(
            rule_id=vr.rule_id,
            name='VV visual check',
            severity=severity,
            file_path=vr.file or screenshot_dir,
            message=vr.message,
        ))
        if vr.status == 'fail':
            report.critical_count += 1
        elif vr.status == 'warn':
            report.warning_count += 1
        # 'pass' and 'skip' don't increment counters


def format_report(report: AuditReport, output_json: bool = False) -> str:
    """Format audit report as text or JSON.

    Args:
        report: The AuditReport to format.
        output_json: If True, output JSON format. Otherwise, human-readable text.

    Returns:
        Formatted report string.
    """
    if output_json:
        return json.dumps({
            'workspace': report.workspace_dir,
            'files_scanned': report.total_files_scanned,
            'passed': report.passed,
            'critical': report.critical_count,
            'warning': report.warning_count,
            'issues': [
                {
                    'rule': r.rule_id,
                    'severity': r.severity,
                    'file': r.file_path,
                    'message': r.message,
                    'line': r.line_number,
                }
                for r in report.results
            ],
        }, ensure_ascii=False, indent=2)

    lines = []
    lines.append(f'Audit Report: {report.workspace_dir}')
    lines.append(f'Files scanned: {report.total_files_scanned}')
    lines.append(f'Status: {"PASS" if report.passed else "FAIL"}')
    lines.append(f'Critical: {report.critical_count}, Warning: {report.warning_count}')
    lines.append('')

    for r in report.results:
        prefix = 'CRITICAL' if r.severity == 'critical' else 'WARNING'
        loc = f'{r.file_path}:{r.line_number}' if r.line_number else r.file_path
        lines.append(f'[{prefix}] [{r.rule_id}] {r.name} -- {loc}')
        lines.append(f'   {r.message}')
        lines.append('')

    return '\n'.join(lines)
