"""Audio extractor using FFmpeg."""
import os
import subprocess
from dataclasses import dataclass
from typing import Optional


@dataclass
class ExtractResult:
    success: bool
    audio_path: Optional[str] = None
    duration_seconds: Optional[float] = None
    error: Optional[str] = None


def extract_audio(
    video_path: str,
    output_dir: Optional[str] = None,
    sample_rate: int = 16000,
    channels: int = 1,
    format: str = "wav",
) -> ExtractResult:
    """Extract audio from video using FFmpeg.

    Args:
        video_path: Path to input video file.
        output_dir: Directory for output audio (default: same as video).
        sample_rate: Audio sample rate (default 16kHz for speech recognition).
        channels: Number of audio channels (default 1 mono).
        format: Output format (default wav for Whisper).

    Returns:
        ExtractResult with audio path or error.
    """
    if not os.path.exists(video_path):
        return ExtractResult(success=False, error=f"Video not found: {video_path}")

    if output_dir is None:
        output_dir = os.path.dirname(video_path)
    os.makedirs(output_dir, exist_ok=True)

    base_name = os.path.splitext(os.path.basename(video_path))[0]
    audio_path = os.path.join(output_dir, f"{base_name}.{format}")

    cmd = [
        "ffmpeg", "-y", "-i", video_path,
        "-vn",  # No video
        "-acodec", "pcm_s16le" if format == "wav" else "libmp3lame",
        "-ar", str(sample_rate),
        "-ac", str(channels),
        audio_path,
    ]

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=300,
        )
        if result.returncode != 0:
            return ExtractResult(success=False, error=f"FFmpeg error: {result.stderr}")

        # Get duration
        duration = get_audio_duration(audio_path)

        return ExtractResult(
            success=True,
            audio_path=audio_path,
            duration_seconds=duration,
        )
    except subprocess.TimeoutExpired:
        return ExtractResult(success=False, error="FFmpeg timeout (300s)")
    except FileNotFoundError:
        return ExtractResult(success=False, error="FFmpeg not found. Please install FFmpeg.")


def get_audio_duration(audio_path: str) -> Optional[float]:
    """Get audio duration in seconds using ffprobe."""
    try:
        result = subprocess.run(
            ["ffprobe", "-v", "quiet", "-show_entries", "format=duration",
             "-of", "csv=p=0", audio_path],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode == 0:
            return float(result.stdout.strip())
    except (subprocess.TimeoutExpired, FileNotFoundError, ValueError):
        pass
    return None


def batch_extract(
    video_paths: list[str],
    output_dir: str,
    **kwargs,
) -> list[ExtractResult]:
    """Extract audio from multiple videos."""
    return [extract_audio(v, output_dir, **kwargs) for v in video_paths]
