"""Recastory Audit — deterministic anti-pattern rule checker."""

from .rules import (
    ALL_RULES,
    VV_RULE_IDS,
    Rule,
    RuleResult,
    get_all_rules,
    get_rules_by_ids,
    get_rules_by_prefix,
)
from .scanner import (
    AuditReport,
    scan_workspace,
    format_report,
)

__all__ = [
    "ALL_RULES",
    "VV_RULE_IDS",
    "Rule",
    "RuleResult",
    "get_all_rules",
    "get_rules_by_ids",
    "get_rules_by_prefix",
    "AuditReport",
    "scan_workspace",
    "format_report",
]
