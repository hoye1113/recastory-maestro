"""Tests for audit scanner and CLI."""
import json
import os
import tempfile
from unittest.mock import patch, MagicMock

import pytest

from tools.audit.scanner import scan_workspace, scan_screenshots, format_report, AuditReport


# ============================================================================
# scan_workspace tests
# ============================================================================

class TestScanWorkspace:
    def test_nonexistent_dir_raises(self):
        with pytest.raises(FileNotFoundError):
            scan_workspace('/nonexistent/path')

    def test_empty_workspace(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            report = scan_workspace(tmpdir)
            assert report.passed is True
            assert report.total_files_scanned == 0
            assert report.critical_count == 0
            assert report.warning_count == 0

    def test_detects_issues_in_md(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            script = os.path.join(tmpdir, 'script.md')
            with open(script, 'w', encoding='utf-8') as f:
                f.write('综上所述，我们可以得出这个结论。\n' * 3)
            report = scan_workspace(tmpdir)
            assert len(report.results) > 0
            assert any(r.rule_id == 'CD-003' for r in report.results)

    def test_rule_filter(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            script = os.path.join(tmpdir, 'script.md')
            with open(script, 'w', encoding='utf-8') as f:
                f.write('综上所述，我们可以得出结论。\n')
                f.write('我知道你可能觉得这很难。\n')
            # Only run CD-003
            report = scan_workspace(tmpdir, rule_ids=['CD-003'])
            rule_ids_found = {r.rule_id for r in report.results}
            assert 'CD-003' in rule_ids_found
            assert 'SL-001' not in rule_ids_found

    def test_skip_node_modules(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create a file in node_modules that would trigger a rule
            nm_dir = os.path.join(tmpdir, 'node_modules', 'pkg')
            os.makedirs(nm_dir)
            script = os.path.join(nm_dir, 'script.md')
            with open(script, 'w', encoding='utf-8') as f:
                f.write('综上所述，我们可以得出结论。\n' * 3)
            report = scan_workspace(tmpdir)
            assert report.total_files_scanned == 0

    def test_skip_git_dir(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            git_dir = os.path.join(tmpdir, '.git')
            os.makedirs(git_dir)
            script = os.path.join(git_dir, 'script.md')
            with open(script, 'w', encoding='utf-8') as f:
                f.write('综上所述，我们可以得出结论。\n' * 3)
            report = scan_workspace(tmpdir)
            assert report.total_files_scanned == 0

    def test_scans_md_files(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            script = os.path.join(tmpdir, 'script.md')
            with open(script, 'w', encoding='utf-8') as f:
                f.write('# Title\nHello world.\n')
            report = scan_workspace(tmpdir)
            assert report.total_files_scanned >= 1

    def test_scans_audio_segments_json(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            audio = os.path.join(tmpdir, 'audio-segments.json')
            data = {'segments': [{'text': 'test', 'start': 0, 'end': 3}]}
            with open(audio, 'w', encoding='utf-8') as f:
                json.dump(data, f)
            report = scan_workspace(tmpdir)
            assert report.total_files_scanned >= 1

    def test_ignores_non_audio_json(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            # package-lock.json should not be scanned by VO rules
            pkg = os.path.join(tmpdir, 'package-lock.json')
            with open(pkg, 'w', encoding='utf-8') as f:
                json.dump({'name': 'test', 'dependencies': {}}, f)
            report = scan_workspace(tmpdir)
            assert report.total_files_scanned == 0

    def test_critical_exit_logic(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            script = os.path.join(tmpdir, 'script.md')
            with open(script, 'w', encoding='utf-8') as f:
                f.write('我知道你可能觉得这很难。\n')
            report = scan_workspace(tmpdir)
            assert report.critical_count > 0
            assert report.passed is False


# ============================================================================
# format_report tests
# ============================================================================

class TestFormatReport:
    def test_text_format_pass(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            report = scan_workspace(tmpdir)
            output = format_report(report)
            assert 'PASS' in output
            assert 'Audit Report' in output

    def test_text_format_fail(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            script = os.path.join(tmpdir, 'script.md')
            with open(script, 'w', encoding='utf-8') as f:
                f.write('我知道你可能觉得这很难。\n')
            report = scan_workspace(tmpdir)
            output = format_report(report)
            assert 'FAIL' in output

    def test_json_format(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            report = scan_workspace(tmpdir)
            output = format_report(report, output_json=True)
            data = json.loads(output)
            assert 'passed' in data
            assert 'workspace' in data
            assert 'files_scanned' in data
            assert 'critical' in data
            assert 'warning' in data
            assert 'issues' in data

    def test_json_format_with_issues(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            script = os.path.join(tmpdir, 'script.md')
            with open(script, 'w', encoding='utf-8') as f:
                f.write('我知道你可能觉得这很难。\n')
            report = scan_workspace(tmpdir)
            output = format_report(report, output_json=True)
            data = json.loads(output)
            assert len(data['issues']) > 0
            rule_ids = {issue['rule'] for issue in data['issues']}
            assert 'SL-001' in rule_ids

    def test_text_format_includes_rule_info(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            script = os.path.join(tmpdir, 'script.md')
            with open(script, 'w', encoding='utf-8') as f:
                f.write('综上所述，我们可以得出结论。\n')
            report = scan_workspace(tmpdir)
            output = format_report(report)
            assert 'CD-003' in output


# ============================================================================
# AuditReport dataclass tests
# ============================================================================

class TestAuditReport:
    def test_passed_when_no_critical(self):
        report = AuditReport(workspace_dir='.', total_files_scanned=0)
        assert report.passed is True

    def test_failed_when_critical(self):
        report = AuditReport(workspace_dir='.', total_files_scanned=0, critical_count=1)
        assert report.passed is False


# ============================================================================
# CLI tests
# ============================================================================

class TestCLI:
    def test_help(self):
        from tools.audit.cli import main
        with pytest.raises(SystemExit) as exc_info:
            main(['--help'])
        assert exc_info.value.code == 0

    def test_nonexistent_workspace_exits_1(self):
        from tools.audit.cli import main
        with pytest.raises(SystemExit) as exc_info:
            main(['/nonexistent/path'])
        assert exc_info.value.code == 1

    def test_workspace_with_no_issues_exits_0(self):
        from tools.audit.cli import main
        with tempfile.TemporaryDirectory() as tmpdir:
            with pytest.raises(SystemExit) as exc_info:
                main([tmpdir])
            assert exc_info.value.code == 0

    def test_workspace_with_critical_exits_1(self):
        from tools.audit.cli import main
        with tempfile.TemporaryDirectory() as tmpdir:
            script = os.path.join(tmpdir, 'script.md')
            with open(script, 'w', encoding='utf-8') as f:
                f.write('我知道你可能觉得这很难。\n')
            with pytest.raises(SystemExit) as exc_info:
                main([tmpdir])
            assert exc_info.value.code == 1

    def test_json_flag(self, capsys):
        from tools.audit.cli import main
        with tempfile.TemporaryDirectory() as tmpdir:
            with pytest.raises(SystemExit):
                main([tmpdir, '--json'])
            captured = capsys.readouterr()
            data = json.loads(captured.out)
            assert 'passed' in data

    def test_rule_flag(self):
        from tools.audit.cli import main
        with tempfile.TemporaryDirectory() as tmpdir:
            script = os.path.join(tmpdir, 'script.md')
            with open(script, 'w', encoding='utf-8') as f:
                f.write('综上所述，我们可以得出结论。\n')
                f.write('我知道你可能觉得这很难。\n')
            # Only run CD-003 — SL-001 should not be triggered
            with pytest.raises(SystemExit) as exc_info:
                main([tmpdir, '--rule', 'CD-003'])
            # CD-003 is warning, not critical, so exit 0
            assert exc_info.value.code == 0


# ============================================================================
# scan_screenshots tests
# ============================================================================

class TestScanScreenshots:
    def test_empty_dir(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            result = scan_screenshots(tmpdir)
            assert result == []

    def test_finds_png_files(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            ss_dir = os.path.join(tmpdir, 'storyboard', 'screenshots')
            os.makedirs(ss_dir)
            for name in ['step-01.png', 'step-00.png', 'step-02.png']:
                with open(os.path.join(ss_dir, name), 'wb') as f:
                    f.write(b'\x89PNG')
            result = scan_screenshots(tmpdir)
            assert len(result) == 3
            # Should be sorted
            assert 'step-00' in result[0]
            assert 'step-01' in result[1]
            assert 'step-02' in result[2]

    def test_ignores_non_png(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            ss_dir = os.path.join(tmpdir, 'storyboard', 'screenshots')
            os.makedirs(ss_dir)
            with open(os.path.join(ss_dir, 'step-00.png'), 'wb') as f:
                f.write(b'\x89PNG')
            with open(os.path.join(ss_dir, 'readme.txt'), 'w') as f:
                f.write('not a screenshot')
            result = scan_screenshots(tmpdir)
            assert len(result) == 1

    def test_no_screenshots_dir(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            # workspace exists but no storyboard/screenshots/
            result = scan_screenshots(tmpdir)
            assert result == []


# ============================================================================
# VV rule integration in scan_workspace
# ============================================================================

class TestVVIntegration:
    @patch('tools.audit.scanner._run_vv_rules')
    def test_vv_rules_called_when_screenshots_exist(self, mock_vv):
        with tempfile.TemporaryDirectory() as tmpdir:
            report = scan_workspace(tmpdir)
            # _run_vv_rules should be called (no rule_ids filter)
            mock_vv.assert_called_once()

    @patch('tools.audit.scanner._run_vv_rules')
    def test_vv_rules_called_with_vv_filter(self, mock_vv):
        with tempfile.TemporaryDirectory() as tmpdir:
            report = scan_workspace(tmpdir, rule_ids=['VV-001'])
            mock_vv.assert_called_once()

    @patch('tools.audit.scanner._run_vv_rules')
    def test_vv_rules_skipped_with_non_vv_filter(self, mock_vv):
        with tempfile.TemporaryDirectory() as tmpdir:
            report = scan_workspace(tmpdir, rule_ids=['TR-001'])
            mock_vv.assert_not_called()

    @patch('tools.audit.vision_rules._mmx_available', return_value=False)
    def test_vv_skip_when_mmx_unavailable(self, mock_a):
        with tempfile.TemporaryDirectory() as tmpdir:
            report = scan_workspace(tmpdir)
            vv_results = [r for r in report.results if r.rule_id.startswith('VV')]
            assert len(vv_results) == 1
            assert 'mmx CLI not available' in vv_results[0].message

    @patch('tools.audit.vision_rules._mmx_available', return_value=True)
    @patch('tools.audit.vision_rules._call_vision')
    def test_vv_results_in_report(self, mock_v, mock_a):
        # VV-001/003/004 expect PASS/FAIL; VV-002/005 expect numbers
        mock_v.side_effect = lambda img, prompt: (
            '5' if 'Count the number' in prompt or 'Estimate the total' in prompt
            else 'PASS. All clear.'
        )
        with tempfile.TemporaryDirectory() as tmpdir:
            ss_dir = os.path.join(tmpdir, 'storyboard', 'screenshots')
            os.makedirs(ss_dir)
            with open(os.path.join(ss_dir, 'step-00.png'), 'wb') as f:
                f.write(b'\x89PNG')
            report = scan_workspace(tmpdir)
            vv_results = [r for r in report.results if r.rule_id.startswith('VV')]
            assert len(vv_results) == 5
            assert all(r.severity == 'warning' for r in vv_results)

    @patch('tools.audit.vision_rules._mmx_available', return_value=True)
    @patch('tools.audit.vision_rules._call_vision', return_value='FAIL. Purple gradient.')
    def test_vv_fail_counts_as_critical(self, mock_v, mock_a):
        with tempfile.TemporaryDirectory() as tmpdir:
            ss_dir = os.path.join(tmpdir, 'storyboard', 'screenshots')
            os.makedirs(ss_dir)
            with open(os.path.join(ss_dir, 'step-00.png'), 'wb') as f:
                f.write(b'\x89PNG')
            report = scan_workspace(tmpdir)
            # VV-001 fail = critical, VV-002/005 skip (can't parse number from FAIL text)
            assert report.critical_count > 0
            assert report.passed is False
