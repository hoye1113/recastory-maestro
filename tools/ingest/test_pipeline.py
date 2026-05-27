"""Tests for pipeline module."""
import tempfile
import pytest
from tools.ingest.pipeline import PipelineConfig, PipelineResult, run_pipeline


class TestPipelineConfig:
    def test_default_values(self):
        config = PipelineConfig(workspace_dir="/tmp/test")
        assert config.max_height == 720
        assert config.whisper_model == "base"
        assert config.language is None
        assert config.device == "auto"


class TestPipelineResult:
    def test_success_result(self):
        result = PipelineResult(
            success=True,
            article_path="/tmp/article.md",
            steps_completed=["download", "extract", "transcribe", "article"],
        )
        assert result.success is True
        assert len(result.steps_completed) == 4

    def test_error_result(self):
        result = PipelineResult(success=False, error="Failed")
        assert result.success is False
        assert result.error == "Failed"


class TestRunPipeline:
    def test_invalid_url_returns_error(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            config = PipelineConfig(workspace_dir=tmpdir)
            result = run_pipeline("not-a-url", config)
            assert result.success is False
            assert "Unsupported URL" in result.error
