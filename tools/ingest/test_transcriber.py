"""Tests for transcriber module."""
import pytest
from tools.ingest.transcriber import (
    clean_text,
    segments_to_article,
    TranscriptionSegment,
    TranscribeResult,
    transcribe_audio,
)


class TestCleanText:
    def test_remove_repeated_words(self):
        assert clean_text("hello hello hello world") == "hello world"

    def test_normalize_whitespace(self):
        assert clean_text("  hello   world  ") == "hello world"

    def test_normal_text_unchanged(self):
        assert clean_text("normal sentence") == "normal sentence"


class TestSegmentsToArticle:
    def test_empty_segments(self):
        result = segments_to_article([], "Test")
        assert "# Test" in result
        assert "No content" in result

    def test_single_segment(self):
        segs = [TranscriptionSegment(start=0, end=1, text="Hello world.")]
        result = segments_to_article(segs, "Title")
        assert "# Title" in result
        assert "Hello world." in result

    def test_paragraph_break_on_pause(self):
        segs = [
            TranscriptionSegment(start=0, end=1, text="First sentence."),
            TranscriptionSegment(start=3, end=4, text="Second sentence."),  # 2s gap
        ]
        result = segments_to_article(segs)
        # Should be two paragraphs
        assert result.count("\n\n") >= 2  # Title + paragraph break

    def test_no_break_on_short_gap(self):
        segs = [
            TranscriptionSegment(start=0, end=1, text="First."),
            TranscriptionSegment(start=1.2, end=2, text="Second."),  # 0.2s gap
        ]
        result = segments_to_article(segs)
        assert "First. Second." in result


class TestTranscribeAudio:
    def test_missing_file_returns_error(self):
        result = transcribe_audio("/nonexistent/audio.wav")
        assert result.success is False
        assert "not found" in result.error

    def test_transcribe_result_dataclass(self):
        result = TranscribeResult(
            success=True,
            segments=[TranscriptionSegment(0, 1, "test")],
            full_text="test",
            language="en",
        )
        assert result.success is True
        assert len(result.segments) == 1
