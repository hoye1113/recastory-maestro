"""CLI entry point for recastory-audit.

Usage: python -m tools.audit <workspace-dir> [options]
"""
from __future__ import annotations

import argparse
import sys

from .scanner import scan_workspace, format_report


def main(argv: list[str] | None = None) -> None:
    """Main entry point for the recastory-audit CLI.

    Args:
        argv: Command-line arguments. Defaults to sys.argv[1:].
    """
    parser = argparse.ArgumentParser(
        description='Recastory Audit -- deterministic anti-pattern rule checker',
        prog='python -m tools.audit',
    )
    parser.add_argument('workspace', help='Workspace directory to scan')
    parser.add_argument(
        '--rule',
        default=None,
        help='Comma-separated rule IDs to run (e.g., TR-001,CD-003). Default: all',
    )
    parser.add_argument(
        '--json',
        action='store_true',
        help='Output JSON format (for CI)',
    )

    args = parser.parse_args(argv)
    rule_ids = args.rule.split(',') if args.rule else None

    try:
        report = scan_workspace(args.workspace, rule_ids=rule_ids)
    except FileNotFoundError as e:
        print(f'Error: {e}', file=sys.stderr)
        sys.exit(1)

    output = format_report(report, output_json=args.json)
    print(output)

    sys.exit(0 if report.passed else 1)


if __name__ == '__main__':
    main()
