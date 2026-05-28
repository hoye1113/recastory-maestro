"""Tests for VV vision rules."""
from __future__ import annotations

import os
import tempfile
from unittest.mock import patch, MagicMock

import pytest

from tools.audit.vision_rules import (
    VisionResult,
    _mmx_available,
    _call_vision,
    detect_vv001_ai_fingerprint,
    detect_vv002_info_density,
    detect_vv003_placeholder,
    detect_vv004_ending_screen,
    detect_vv005_text_density,
    run_vv_rules,
    VV_RULES,
)


# ============================================================================
# _mmx_available tests
# ============================================================================

class TestMmxAvailable:
    @patch('subprocess.run')
    def test_available(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0)
        assert _mmx_available() is True

    @patch('subprocess.run')
    def test_not_installed(self, mock_run):
        mock_run.side_effect = FileNotFoundError
        assert _mmx_available() is False

    @patch('subprocess.run')
    def test_auth_failed(self, mock_run):
        mock_run.return_value = MagicMock(returncode=1)
        assert _mmx_available() is False

    @patch('subprocess.run')
    def test_timeout(self, mock_run):
        import subprocess
        mock_run.side_effect = subprocess.TimeoutExpired(cmd='mmx', timeout=10)
        assert _mmx_available() is False


# ============================================================================
# _call_vision tests
# ============================================================================

class TestCallVision:
    @patch('subprocess.run')
    def test_success_json(self, mock_run):
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout='{"description": "A blue slide with text"}'
        )
        result = _call_vision('/fake/img.png', 'Describe.')
        assert result == "A blue slide with text"

    @patch('subprocess.run')
    def test_success_content_field(self, mock_run):
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout='{"content": "Slide content here"}'
        )
        result = _call_vision('/fake/img.png', 'Describe.')
        assert result == "Slide content here"

    @patch('subprocess.run')
    def test_returncode_nonzero(self, mock_run):
        mock_run.return_value = MagicMock(returncode=1, stdout='')
        result = _call_vision('/fake/img.png', 'Describe.')
        assert result is None

    @patch('subprocess.run')
    def test_file_not_found(self, mock_run):
        mock_run.side_effect = FileNotFoundError
        result = _call_vision('/fake/img.png', 'Describe.')
        assert result is None

    @patch('subprocess.run')
    def test_invalid_json(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout='not json')
        result = _call_vision('/fake/img.png', 'Describe.')
        assert result is None


# ============================================================================
# VV-001: AI fingerprint
# ============================================================================

class TestVV001:
    @patch('tools.audit.vision_rules._call_vision', return_value=None)
    def test_skip_when_vision_unavailable(self, mock_v):
        result = detect_vv001_ai_fingerprint('/fake/img.png')
        assert result.status == 'skip'
        assert result.rule_id == 'VV-001'

    @patch('tools.audit.vision_rules._call_vision', return_value='PASS. No AI clichés found.')
    def test_pass_clean_slide(self, mock_v):
        result = detect_vv001_ai_fingerprint('/fake/img.png')
        assert result.status == 'pass'

    @patch('tools.audit.vision_rules._call_vision', return_value='FAIL. Purple gradient detected.')
    def test_fail_ai_fingerprint(self, mock_v):
        result = detect_vv001_ai_fingerprint('/fake/img.png')
        assert result.status == 'fail'

    @patch('tools.audit.vision_rules._call_vision', return_value='fail: rounded cards with colored borders')
    def test_fail_lowercase(self, mock_v):
        result = detect_vv001_ai_fingerprint('/fake/img.png')
        assert result.status == 'fail'


# ============================================================================
# VV-002: Info density
# ============================================================================

class TestVV002:
    @patch('tools.audit.vision_rules._call_vision', return_value=None)
    def test_skip_when_unavailable(self, mock_v):
        result = detect_vv002_info_density('/fake/img.png')
        assert result.status == 'skip'

    @patch('tools.audit.vision_rules._call_vision', return_value='5')
    def test_pass_normal_density(self, mock_v):
        result = detect_vv002_info_density('/fake/img.png')
        assert result.status == 'pass'

    @patch('tools.audit.vision_rules._call_vision', return_value='15')
    def test_warn_high_density(self, mock_v):
        result = detect_vv002_info_density('/fake/img.png')
        assert result.status == 'warn'

    @patch('tools.audit.vision_rules._call_vision', return_value='no number here')
    def test_skip_unparseable(self, mock_v):
        result = detect_vv002_info_density('/fake/img.png')
        assert result.status == 'skip'


# ============================================================================
# VV-003: Placeholder
# ============================================================================

class TestVV003:
    @patch('tools.audit.vision_rules._call_vision', return_value=None)
    def test_skip_when_unavailable(self, mock_v):
        result = detect_vv003_placeholder('/fake/img.png')
        assert result.status == 'skip'

    @patch('tools.audit.vision_rules._call_vision', return_value='PASS. No placeholders.')
    def test_pass_no_placeholder(self, mock_v):
        result = detect_vv003_placeholder('/fake/img.png')
        assert result.status == 'pass'

    @patch('tools.audit.vision_rules._call_vision', return_value='FAIL. Found placeholder card.')
    def test_fail_placeholder(self, mock_v):
        result = detect_vv003_placeholder('/fake/img.png')
        assert result.status == 'fail'


# ============================================================================
# VV-004: Ending screen
# ============================================================================

class TestVV004:
    @patch('tools.audit.vision_rules._call_vision', return_value=None)
    def test_skip_when_unavailable(self, mock_v):
        result = detect_vv004_ending_screen('/fake/img.png')
        assert result.status == 'skip'

    @patch('tools.audit.vision_rules._call_vision', return_value='PASS. Real content shown.')
    def test_pass_real_content(self, mock_v):
        result = detect_vv004_ending_screen('/fake/img.png')
        assert result.status == 'pass'

    @patch('tools.audit.vision_rules._call_vision', return_value='FAIL. Shows "Thank you" text.')
    def test_fail_ending_screen(self, mock_v):
        result = detect_vv004_ending_screen('/fake/img.png')
        assert result.status == 'fail'


# ============================================================================
# VV-005: Text density
# ============================================================================

class TestVV005:
    @patch('tools.audit.vision_rules._call_vision', return_value=None)
    def test_skip_when_unavailable(self, mock_v):
        result = detect_vv005_text_density('/fake/img.png')
        assert result.status == 'skip'

    @patch('tools.audit.vision_rules._call_vision', return_value='30')
    def test_pass_low_density(self, mock_v):
        result = detect_vv005_text_density('/fake/img.png')
        assert result.status == 'pass'

    @patch('tools.audit.vision_rules._call_vision', return_value='65')
    def test_warn_moderate_density(self, mock_v):
        result = detect_vv005_text_density('/fake/img.png')
        assert result.status == 'warn'

    @patch('tools.audit.vision_rules._call_vision', return_value='150')
    def test_fail_high_density(self, mock_v):
        result = detect_vv005_text_density('/fake/img.png')
        assert result.status == 'fail'

    @patch('tools.audit.vision_rules._call_vision', return_value='about fifty characters')
    def test_skip_unparseable(self, mock_v):
        result = detect_vv005_text_density('/fake/img.png')
        assert result.status == 'skip'


# ============================================================================
# VV_RULES registry
# ============================================================================

class TestVVRegistry:
    def test_five_rules_registered(self):
        assert len(VV_RULES) == 5

    def test_all_rules_callable(self):
        for rule_fn in VV_RULES:
            assert callable(rule_fn)


# ============================================================================
# VisionResult dataclass
# ============================================================================

class TestVisionResult:
    def test_fields(self):
        r = VisionResult(rule_id='VV-001', status='pass', message='ok', file='/test.png')
        assert r.rule_id == 'VV-001'
        assert r.status == 'pass'
        assert r.message == 'ok'
        assert r.file == '/test.png'

    def test_optional_file(self):
        r = VisionResult(rule_id='VV', status='skip', message='no mmx')
        assert r.file is None


# ============================================================================
# run_vv_rules integration
# ============================================================================

class TestRunVvRules:
    @patch('tools.audit.vision_rules._mmx_available', return_value=False)
    def test_skip_when_no_mmx(self, mock_a):
        results = run_vv_rules('/fake/dir')
        assert len(results) == 1
        assert results[0].status == 'skip'
        assert 'mmx CLI not available' in results[0].message

    @patch('tools.audit.vision_rules._mmx_available', return_value=True)
    def test_skip_when_dir_missing(self, mock_a):
        results = run_vv_rules('/nonexistent/dir')
        assert len(results) == 1
        assert results[0].status == 'skip'
        assert 'not found' in results[0].message

    @patch('tools.audit.vision_rules._mmx_available', return_value=True)
    def test_skip_when_no_screenshots(self, mock_a):
        with tempfile.TemporaryDirectory() as tmpdir:
            results = run_vv_rules(tmpdir)
            assert len(results) == 1
            assert results[0].status == 'skip'
            assert 'No screenshots' in results[0].message

    @patch('tools.audit.vision_rules._mmx_available', return_value=True)
    @patch('tools.audit.vision_rules._call_vision')
    def test_runs_all_rules_per_screenshot(self, mock_v, mock_a):
        # VV-001/003/004 expect PASS/FAIL text; VV-002/005 expect numeric text
        mock_v.side_effect = lambda img, prompt: (
            '5' if 'Count the number' in prompt or 'Estimate the total' in prompt
            else 'PASS. All clear.'
        )
        with tempfile.TemporaryDirectory() as tmpdir:
            # Create 2 fake screenshots
            for name in ['step-00.png', 'step-01.png']:
                with open(os.path.join(tmpdir, name), 'wb') as f:
                    f.write(b'\x89PNG')  # minimal PNG header
            results = run_vv_rules(tmpdir)
            # 2 screenshots * 5 rules = 10 results
            assert len(results) == 10
            assert all(r.status == 'pass' for r in results)

    @patch('tools.audit.vision_rules._mmx_available', return_value=True)
    @patch('tools.audit.vision_rules._call_vision', return_value=None)
    def test_graceful_skip_on_call_failure(self, mock_v, mock_a):
        with tempfile.TemporaryDirectory() as tmpdir:
            with open(os.path.join(tmpdir, 'step-00.png'), 'wb') as f:
                f.write(b'\x89PNG')
            results = run_vv_rules(tmpdir)
            assert len(results) == 5
            assert all(r.status == 'skip' for r in results)
