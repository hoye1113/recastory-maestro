# recastory-audit CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## 质量门禁（每 Task 强制执行）

参考 ElectronHound development-process.md，每个 Task 完成后执行 **3 轮 Code Review**，无需人工介入：

```text
Task 执行 → Code Review #1 → 修复全部问题 → Code Review #2 → 修复回归问题 → Code Review #3 → 最终验证 → Commit
```

### Review 流程

1. **Code Review #1（Spec Compliance）** — 检查代码是否完整实现计划规格
2. **修复** — 修复 #1 发现的所有 `[Required]` 问题
3. **Code Review #2（Regression Check）** — 检查修复过程中是否引入回归
4. **修复** — 修复 #2 发现的回归问题
5. **Code Review #3（Final Quality）** — 最终质量验证
6. **Commit** — 三次 Review 全部通过后提交

**Goal:** 实现 `recastory-audit` CLI 工具，对 workspace 运行确定性反模式规则检查（TR/CD/SB/VO/RD/SL 系列规则）。

**Architecture:** Python CLI 工具，扫描 workspace 目录下的产出文件（script.md、outline.md、audio-segments.json、SRT 等），运行文本匹配规则检测反模式。支持 `--rule` 指定规则、`--json` 输出 JSON。

**Tech Stack:** Python 3.10+, argparse, re, json, pathlib

**参考：** ARCHITECTURE.md 中的反模式规则定义（TR-001~TR-005, CD-001~CD-006, SB-001~SB-005, VO-001~VO-004, RD-001~RD-004, SL-001~SL-006）

---

## 文件清单

| 操作 | 文件 | 职责 |
|------|------|------|
| Create | `tools/audit/__init__.py` | 包初始化 |
| Create | `tools/audit/rules.py` | 所有反模式规则定义（detect 函数） |
| Create | `tools/audit/scanner.py` | 扫描 workspace，调用规则，汇总结果 |
| Create | `tools/audit/cli.py` | CLI 入口 |
| Create | `tools/audit/__main__.py` | `python -m tools.audit` 入口 |
| Create | `tools/audit/test_rules.py` | 规则单元测试 |
| Create | `tools/audit/test_scanner.py` | 扫描器测试 |

---

### Task 1: 规则引擎（rules.py）

**Files:**
- Create: `tools/audit/__init__.py`
- Create: `tools/audit/rules.py`
- Create: `tools/audit/test_rules.py`

- [ ] **Step 1: 创建包结构**

`tools/audit/__init__.py`:
```python
"""Recastory Audit — deterministic anti-pattern rule checker."""
```

- [ ] **Step 2: 编写 rules.py**

定义规则数据结构和所有规则的 detect 函数。

```python
"""Anti-pattern rules for Recastory audit."""
import re
from dataclasses import dataclass
from typing import Callable


@dataclass
class RuleResult:
    rule_id: str
    name: str
    severity: str  # "critical" or "warning"
    file_path: str
    message: str
    line_number: int | None = None


@dataclass
class Rule:
    id: str
    name: str
    severity: str
    detect: Callable[[str, str], list[RuleResult]]
    description: str
```

规则 detect 函数签名：`def detect(content: str, file_path: str) -> list[RuleResult]`

实现以下规则组：

**TR 系列（转写规则）—— 检测 .md 文件：**
- `TR-001`: 连续 3 个以上无标点长句（>50 字） — 用正则匹配连续长句
- `TR-002`: 说话人标签格式不统一 — 检查 `[说话人]` 格式
- `TR-003`: 时间戳不连续或重叠 — 检查 SRT 时间戳
- `TR-004`: 填充词密度过高（"嗯""啊""这个">5%） — 统计填充词占比
- `TR-005`: 中英文标点混用 — 检测中英文标点共存

**CD 系列（内容提炼规则）—— 检测 script.md / outline.md：**
- `CD-001`: 大纲层级超过 4 层 — 检测 `####` 及更深的标题
- `CD-002`: 单章节字数 >500 字 — 按 `##` 分割，统计每章字数
- `CD-003`: 口播脚本包含书面语 — 匹配"综上所述""由此可见"等
- `CD-005`: 缺乏 Hook — 检查前 10 秒（前 50 字）是否有吸引力语句
- `CD-006`: 表达 DNA 未注入 — 检查是否有视角标记

**VO 系列（配音规则）—— 检测 audio-segments.json / 文本：**
- `VO-001`: 语速异常 — 基于字数和预估时长计算语速
- `VO-002`: 单句长度 >50 字 — 检测长句
- `VO-003`: 多音字未标注 — 检测常见多音字缺少拼音标注
- `VO-004`: 缺乏停顿标记 — 连续 5 句无逗号/句号

**SL 系列（AI Slop 规则）—— 检测 script.md：**
- `SL-001`: 假共情 — 匹配"我知道你""你是不是也""我能理解"
- `SL-002`: 假深刻 — 匹配"恰恰/反而/正是"包装
- `SL-003`: 自我标榜 — 匹配"我必须认真说""颠覆认知""你一定要听完"
- `SL-004`: 万能模板 — 匹配"说白了/本质上/底层逻辑/一句话总结/归根结底"
- `SL-005`: 排比堆砌 — 检测连续 ≥3 句结构相同
- `SL-006`: 套话结尾 — 匹配"以上就是本期内容/希望对你有帮助/感谢观看"

每条规则都是一个函数，返回 `list[RuleResult]`。

- [ ] **Step 3: 编写 test_rules.py**

为每条规则编写测试：
- 正例：应该被检测到的问题样本
- 反例：不应该被误报的正常样本

```python
"""Tests for audit rules."""
import pytest
from tools.audit.rules import (
    detect_tr001, detect_tr002, detect_tr003, detect_tr004, detect_tr005,
    detect_cd001, detect_cd002, detect_cd003, detect_cd005,
    detect_vo002, detect_vo004,
    detect_sl001, detect_sl002, detect_sl003, detect_sl004, detect_sl005, detect_sl006,
)


class TestTR001:
    def test_detects_long_sentences(self):
        content = "这是一段超过五十个字的长句子" * 6  # >50 chars each
        results = detect_tr001(content, "test.md")
        assert len(results) > 0

    def test_no_false_positive_short_sentences(self):
        content = "短句。另一个短句。第三句。"
        results = detect_tr001(content, "test.md")
        assert len(results) == 0


class TestCD003:
    def test_detects_formal_language(self):
        content = "综上所述，我们可以得出结论。"
        results = detect_cd003(content, "script.md")
        assert len(results) > 0
        assert any("综上所述" in r.message for r in results)

    def test_no_false_positive_colloquial(self):
        content = "说白了就是这么回事。你看，其实很简单。"
        results = detect_cd003(content, "script.md")
        assert len(results) == 0


class TestSL001:
    def test_detects_fake_empathy(self):
        content = "我知道你可能觉得这很难。"
        results = detect_sl001(content, "script.md")
        assert len(results) > 0

    def test_no_false_positive_genuine(self):
        content = "今天我们来聊聊冷萃咖啡。"
        results = detect_sl001(content, "script.md")
        assert len(results) == 0


# ... 类似地为每条规则编写 2-4 个测试
```

- [ ] **Step 4: 运行测试**

```bash
pytest tools/audit/test_rules.py -v
```

- [ ] **Step 5: Commit**

```bash
git add tools/audit/__init__.py tools/audit/rules.py tools/audit/test_rules.py
git commit -m "feat(audit): add anti-pattern rule engine with TR/CD/VO/SL rules"
```

---

### Task 2: 扫描器 + CLI

**Files:**
- Create: `tools/audit/scanner.py`
- Create: `tools/audit/cli.py`
- Create: `tools/audit/__main__.py`
- Create: `tools/audit/test_scanner.py`

- [ ] **Step 1: 编写 scanner.py**

扫描 workspace 目录，找到可检测文件，调用规则，汇总结果。

```python
"""Workspace scanner for anti-pattern rules."""
import os
import json
from pathlib import Path
from dataclasses import dataclass, field
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
    """
    workspace = Path(workspace_dir)
    if not workspace.is_dir():
        raise FileNotFoundError(f"Workspace not found: {workspace_dir}")

    rules = get_rules_by_ids(rule_ids) if rule_ids else ALL_RULES
    report = AuditReport(workspace_dir=str(workspace), total_files_scanned=0)

    # Map file patterns to applicable rule categories
    file_rule_map = {
        "*.md": [r for r in rules if r.id.startswith(("TR-", "CD-", "SL-"))],
        "*.srt": [r for r in rules if r.id.startswith("TR-")],
        "*.json": [r for r in rules if r.id.startswith("VO-")],
    }

    for pattern, applicable_rules in file_rule_map.items():
        if not applicable_rules:
            continue
        for file_path in workspace.rglob(pattern):
            if "node_modules" in str(file_path) or ".git" in str(file_path):
                continue
            report.total_files_scanned += 1
            content = file_path.read_text(encoding="utf-8", errors="replace")
            for rule in applicable_rules:
                violations = rule.detect(content, str(file_path))
                report.results.extend(violations)
                for v in violations:
                    if v.severity == "critical":
                        report.critical_count += 1
                    else:
                        report.warning_count += 1

    return report


def format_report(report: AuditReport, output_json: bool = False) -> str:
    """Format audit report as text or JSON."""
    if output_json:
        return json.dumps({
            "workspace": report.workspace_dir,
            "files_scanned": report.total_files_scanned,
            "passed": report.passed,
            "critical": report.critical_count,
            "warning": report.warning_count,
            "issues": [
                {
                    "rule": r.rule_id,
                    "severity": r.severity,
                    "file": r.file_path,
                    "message": r.message,
                    "line": r.line_number,
                }
                for r in report.results
            ],
        }, ensure_ascii=False, indent=2)

    lines = []
    lines.append(f"Audit Report: {report.workspace_dir}")
    lines.append(f"Files scanned: {report.total_files_scanned}")
    lines.append(f"Status: {'PASS' if report.passed else 'FAIL'}")
    lines.append(f"Critical: {report.critical_count}, Warning: {report.warning_count}")
    lines.append("")

    for r in report.results:
        prefix = "❌" if r.severity == "critical" else "⚠️"
        loc = f"{r.file_path}:{r.line_number}" if r.line_number else r.file_path
        lines.append(f"{prefix} [{r.rule_id}] {r.name} — {loc}")
        lines.append(f"   {r.message}")
        lines.append("")

    return "\n".join(lines)
```

- [ ] **Step 2: 编写 cli.py**

```python
"""CLI entry point for recastory-audit.

Usage: python -m tools.audit <workspace-dir> [options]
"""
import argparse
import sys
from .scanner import scan_workspace, format_report


def main():
    parser = argparse.ArgumentParser(
        description="Recastory Audit — deterministic anti-pattern rule checker",
        prog="python -m tools.audit",
    )
    parser.add_argument("workspace", help="Workspace directory to scan")
    parser.add_argument(
        "--rule",
        default=None,
        help="Comma-separated rule IDs to run (e.g., TR-001,CD-003). Default: all",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output JSON format (for CI)",
    )

    args = parser.parse_args()
    rule_ids = args.rule.split(",") if args.rule else None

    try:
        report = scan_workspace(args.workspace, rule_ids=rule_ids)
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    output = format_report(report, output_json=args.json)
    print(output)

    sys.exit(0 if report.passed else 1)


if __name__ == "__main__":
    main()
```

- [ ] **Step 3: 编写 __main__.py**

```python
"""Entry point for python -m tools.audit."""
from .cli import main

if __name__ == "__main__":
    main()
```

- [ ] **Step 4: 编写 test_scanner.py**

```python
"""Tests for audit scanner."""
import tempfile
import os
import pytest
from tools.audit.scanner import scan_workspace, format_report


class TestScanWorkspace:
    def test_nonexistent_dir_raises(self):
        with pytest.raises(FileNotFoundError):
            scan_workspace("/nonexistent/path")

    def test_empty_workspace(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            report = scan_workspace(tmpdir)
            assert report.passed is True
            assert report.total_files_scanned == 0

    def test_detects_issues_in_md(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            script = os.path.join(tmpdir, "script.md")
            with open(script, "w") as f:
                f.write("综上所述，我们可以得出这个结论。\n" * 3)
            report = scan_workspace(tmpdir)
            assert len(report.results) > 0

    def test_rule_filter(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            script = os.path.join(tmpdir, "script.md")
            with open(script, "w") as f:
                f.write("综上所述，我们可以得出结论。\n")
                f.write("我知道你可能觉得这很难。\n")
            # Only run CD-003
            report = scan_workspace(tmpdir, rule_ids=["CD-003"])
            rule_ids_found = {r.rule_id for r in report.results}
            assert "CD-003" in rule_ids_found
            assert "SL-001" not in rule_ids_found


class TestFormatReport:
    def test_text_format(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            report = scan_workspace(tmpdir)
            output = format_report(report)
            assert "PASS" in output

    def test_json_format(self):
        import json
        with tempfile.TemporaryDirectory() as tmpdir:
            report = scan_workspace(tmpdir)
            output = format_report(report, output_json=True)
            data = json.loads(output)
            assert "passed" in data
```

- [ ] **Step 5: 运行测试**

```bash
pytest tools/audit/test_rules.py tools/audit/test_scanner.py -v
```

- [ ] **Step 6: Commit**

```bash
git add tools/audit/scanner.py tools/audit/cli.py tools/audit/__main__.py tools/audit/test_scanner.py
git commit -m "feat(audit): add workspace scanner and CLI entry point"
```

---

### Task 3: 真实数据验证

**Files:**
- Modify: `tools/audit/rules.py`（如需要修复）

- [ ] **Step 1: 对 rm-test-002 运行全量扫描**

```bash
python -m tools.audit workspace/rm-test-002
```

检查输出是否合理：
- 应该检测到 script.md 中的反模式（如有）
- 不应该有误报

- [ ] **Step 2: 对 rm-test-002 运行 JSON 输出**

```bash
python -m tools.audit workspace/rm-test-002 --json
```

验证 JSON 格式正确。

- [ ] **Step 3: 对 rm-test-002 运行单规则过滤**

```bash
python -m tools.audit workspace/rm-test-002 --rule SL-001,SL-002
```

验证只运行指定规则。

- [ ] **Step 4: 修复发现的问题（如有）**

- [ ] **Step 5: Commit（如有修复）**

```bash
git add tools/audit/
git commit -m "fix(audit): fix issues found during real data validation"
```

---

### Task 4: 更新文档

**Files:**
- Modify: `WORKFLOW.md`

- [ ] **Step 1: 更新 WORKFLOW.md Phase 4**

确认 Phase 4 引用了正确的命令：

```bash
python -m tools.audit workspace/<pipeline-id>/
python -m tools.audit --rule TR-001,TR-002 workspace/<pipeline-id>/transcribe/
python -m tools.audit --json workspace/<pipeline-id>/
```

- [ ] **Step 2: Commit**

```bash
git add WORKFLOW.md
git commit -m "docs: update Phase 4 audit commands"
```

---

## 验证清单

| 验证项 | 方法 |
|--------|------|
| 规则覆盖 | TR-001~005, CD-001~003/005, VO-001~004, SL-001~006 |
| 测试通过 | `pytest tools/audit/ -v` → ALL PASSED |
| CLI 工作 | `python -m tools.audit --help` → 显示帮助 |
| 真实数据 | `python -m tools.audit workspace/rm-test-002` → 合理输出 |
| JSON 输出 | `python -m tools.audit --json workspace/rm-test-002` → 有效 JSON |
| 规则过滤 | `python -m tools.audit --rule SL-001 workspace/rm-test-002` → 仅 SL-001 |
| 退出码 | 有 critical → exit 1，无 critical → exit 0 |
