"""Workspace scanner for anti-pattern rules.

Scans workspace directories, maps file patterns to rule categories,
runs applicable rules, and produces an AuditReport.
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path

from .rules import Rule, RuleResult, ALL_RULES, get_rules_by_ids


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

    # Map file patterns to applicable rule categories
    file_rule_map = {
        '*.md': [r for r in rules if r.id.startswith(('TR-', 'CD-', 'SL-'))],
        '*.srt': [r for r in rules if r.id.startswith('TR-')],
        '*.json': [r for r in rules if r.id.startswith('VO-')],
    }

    for pattern, applicable_rules in file_rule_map.items():
        if not applicable_rules:
            continue
        for file_path in workspace.rglob(pattern):
            # Skip node_modules and .git
            parts = file_path.parts
            if 'node_modules' in parts or '.git' in parts:
                continue
            report.total_files_scanned += 1
            content = file_path.read_text(encoding='utf-8', errors='replace')
            for rule in applicable_rules:
                violations = rule.detect(content, str(file_path))
                report.results.extend(violations)
                for v in violations:
                    if v.severity == 'critical':
                        report.critical_count += 1
                    else:
                        report.warning_count += 1

    return report


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
