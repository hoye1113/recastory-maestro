"""Tests for audio_extractor module."""
import os
import tempfile
import pytest
import subprocess
from tools.ingest.audio_extractor import extract_audio, get_audio_duration, ExtractResult


class TestExtractAudio:
    def test_missing_video_returns_error(self):
        result = extract_audio("/nonexistent/video.mp4")
        assert result.success is False
        assert "not found" in result.error

    @pytest.mark.slow
    def test_extract_from_valid_video(self):
        """Integration test with a real video (requires FFmpeg)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            video_path = os.path.join(tmpdir, "test.mp4")
            # Generate 2-second test video with audio
            subprocess.run([
                "ffmpeg", "-y", "-f", "lavfi", "-i", "sine=frequency=440:duration=2",
                "-f", "lavfi", "-i", "color=c=black:s=320x240:d=2",
                "-shortest", video_path,
            ], capture_output=True, timeout=30)

            if os.path.exists(video_path):
                result = extract_audio(video_path, tmpdir)
                assert result.success is True
                assert result.audio_path.endswith(".wav")
                assert os.path.exists(result.audio_path)
                assert result.duration_seconds is not None
                assert result.duration_seconds > 0


class TestGetAudioDuration:
    def test_missing_file_returns_none(self):
        assert get_audio_duration("/nonexistent/audio.wav") is None
