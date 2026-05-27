"""Tests for video_downloader module."""
import os
import tempfile
import pytest
from tools.ingest.video_downloader import validate_url, download_video, DownloadResult


class TestValidateUrl:
    def test_youtube_valid(self):
        assert validate_url("https://www.youtube.com/watch?v=dQw4w9WgXcQ") is True

    def test_youtu_be_valid(self):
        assert validate_url("https://youtu.be/dQw4w9WgXcQ") is True

    def test_bilibili_valid(self):
        assert validate_url("https://www.bilibili.com/video/BV1xx411c7mu") is True

    def test_vimeo_valid(self):
        assert validate_url("https://vimeo.com/123456789") is True

    def test_invalid_url(self):
        assert validate_url("https://example.com/video") is False

    def test_not_url(self):
        assert validate_url("not a url") is False


class TestDownloadResult:
    def test_success_result(self):
        result = DownloadResult(success=True, file_path="/tmp/test.mp4", title="Test", duration_seconds=60.0)
        assert result.success is True
        assert result.file_path == "/tmp/test.mp4"

    def test_error_result(self):
        result = DownloadResult(success=False, error="Download failed")
        assert result.success is False
        assert result.error == "Download failed"


class TestDownloadVideo:
    def test_invalid_url_returns_error(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            result = download_video("not-a-url", tmpdir)
            assert result.success is False
            assert "Unsupported URL" in result.error
