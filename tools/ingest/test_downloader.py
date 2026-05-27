"""Tests for video_downloader module."""
import os
import tempfile
import pytest
from unittest.mock import patch, MagicMock
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

    def test_dailymotion_short_valid(self):
        assert validate_url("https://dai.ly/x2k8pqz") is True

    def test_bilibili_short_valid(self):
        assert validate_url("https://b23.tv/BV1xx411c7mu") is True

    def test_youtube_no_path_valid(self):
        assert validate_url("https://www.youtube.com") is True

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

    @pytest.mark.slow
    def test_download_short_video(self):
        """Happy-path test: exercises prepare_filename extension normalization."""
        with tempfile.TemporaryDirectory() as tmpdir:
            fake_info = {
                "title": "test_video",
                "duration": 10.0,
            }
            mock_ydl = MagicMock()
            mock_ydl.extract_info.return_value = fake_info
            mock_ydl.prepare_filename.return_value = os.path.join(tmpdir, "test_video.webm")
            mock_ydl.__enter__ = MagicMock(return_value=mock_ydl)
            mock_ydl.__exit__ = MagicMock(return_value=False)

            # Create the expected .mp4 file so the existence check passes
            expected_mp4 = os.path.join(tmpdir, "test_video.mp4")
            with open(expected_mp4, "w") as f:
                f.write("fake")

            with patch("tools.ingest.video_downloader.yt_dlp.YoutubeDL", return_value=mock_ydl):
                result = download_video("https://www.youtube.com/watch?v=dQw4w9WgXcQ", tmpdir)

            assert result.success is True
            assert result.file_path == expected_mp4
            assert result.title == "test_video"
            assert result.duration_seconds == 10.0

    @pytest.mark.slow
    def test_download_file_not_found_returns_error(self):
        """Verify file existence check returns error when file is missing."""
        with tempfile.TemporaryDirectory() as tmpdir:
            fake_info = {
                "title": "test_video",
                "duration": 10.0,
            }
            mock_ydl = MagicMock()
            mock_ydl.extract_info.return_value = fake_info
            mock_ydl.prepare_filename.return_value = os.path.join(tmpdir, "test_video.webm")
            mock_ydl.__enter__ = MagicMock(return_value=mock_ydl)
            mock_ydl.__exit__ = MagicMock(return_value=False)

            with patch("tools.ingest.video_downloader.yt_dlp.YoutubeDL", return_value=mock_ydl):
                result = download_video("https://www.youtube.com/watch?v=dQw4w9WgXcQ", tmpdir)

            assert result.success is False
            assert "file not found" in result.error
