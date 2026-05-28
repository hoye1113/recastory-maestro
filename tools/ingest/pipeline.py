"""Ingest pipeline orchestrator: URL -> download -> extract -> transcribe -> article.md."""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import Optional, Callable

from .video_downloader import download_video, validate_url
from .audio_extractor import extract_audio
from .transcriber import transcribe_audio, segments_to_article


@dataclass
class PipelineConfig:
    workspace_dir: str
    max_height: int = 720
    whisper_model: str = "base"
    language: Optional[str] = None
    device: str = "auto"
    cookies_file: Optional[str] = None
    cookies_from_browser: Optional[str] = None


@dataclass
class PipelineResult:
    success: bool
    article_path: Optional[str] = None
    video_path: Optional[str] = None
    audio_path: Optional[str] = None
    title: Optional[str] = None
    duration_seconds: Optional[float] = None
    error: Optional[str] = None
    steps_completed: list[str] = field(default_factory=list)


def run_pipeline(
    url: str,
    config: PipelineConfig,
    progress_callback: Optional[Callable[[str, float], None]] = None,
) -> PipelineResult:
    """Run the full ingest pipeline.

    Args:
        url: Video URL to process.
        config: Pipeline configuration.
        progress_callback: Optional callback(step_name, progress).

    Returns:
        PipelineResult with paths to generated files.
    """
    def notify(step: str, progress: float):
        if progress_callback:
            progress_callback(step, progress)

    if not validate_url(url):
        return PipelineResult(success=False, error=f"Unsupported URL: {url}")

    if not config.workspace_dir or not config.workspace_dir.strip():
        return PipelineResult(success=False, error="workspace_dir is required")

    workspace = config.workspace_dir
    os.makedirs(workspace, exist_ok=True)

    # Step 1: Download
    notify("download", 0.0)
    video_dir = os.path.join(workspace, "video")
    dl_result = download_video(
        url, video_dir,
        max_height=config.max_height,
        cookies_file=config.cookies_file,
        cookies_from_browser=config.cookies_from_browser,
    )
    if not dl_result.success:
        return PipelineResult(success=False, error=f"Download failed: {dl_result.error}")
    notify("download", 1.0)

    # Step 2: Extract audio
    notify("extract", 0.0)
    audio_dir = os.path.join(workspace, "audio")
    ext_result = extract_audio(dl_result.file_path, audio_dir)
    if not ext_result.success:
        return PipelineResult(
            success=False,
            video_path=dl_result.file_path,
            error=f"Audio extraction failed: {ext_result.error}",
            steps_completed=["download"],
        )
    notify("extract", 1.0)

    # Step 3: Transcribe
    notify("transcribe", 0.0)
    trans_result = transcribe_audio(
        ext_result.audio_path,
        model_size=config.whisper_model,
        language=config.language,
        device=config.device,
    )
    if not trans_result.success:
        return PipelineResult(
            success=False,
            video_path=dl_result.file_path,
            audio_path=ext_result.audio_path,
            error=f"Transcription failed: {trans_result.error}",
            steps_completed=["download", "extract"],
        )
    notify("transcribe", 1.0)

    # Step 4: Generate article.md
    notify("article", 0.0)
    title = dl_result.title or "Untitled"
    article_content = segments_to_article(trans_result.segments, title)
    article_path = os.path.join(workspace, "article.md")
    try:
        with open(article_path, "w", encoding="utf-8") as f:
            f.write(article_content)
    except OSError as e:
        return PipelineResult(
            success=False,
            video_path=dl_result.file_path,
            audio_path=ext_result.audio_path,
            error=f"Failed to write article.md: {e}",
            steps_completed=["download", "extract", "transcribe"],
        )
    notify("article", 1.0)

    return PipelineResult(
        success=True,
        article_path=article_path,
        video_path=dl_result.file_path,
        audio_path=ext_result.audio_path,
        title=title,
        duration_seconds=dl_result.duration_seconds,
        steps_completed=["download", "extract", "transcribe", "article"],
    )
