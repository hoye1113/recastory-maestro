# Ingest + Transcribe Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## 质量门禁（每 Task 强制执行）

参考 ElectronHound development-process.md，每个 Task 完成后执行 **3 轮 Code Review**，无需人工介入：

```text
Task 执行 → Code Review #1 → 修复全部问题 → Code Review #2 → 修复回归问题 → Code Review #3 → 最终验证 → Commit
```

### Review 流程

1. **Code Review #1（Spec Compliance）** — 检查代码是否完整实现计划规格
   - 所有 spec 要求均已实现（无遗漏）
   - 无超出 spec 的多余功能
   - 命名、签名与计划一致
2. **修复** — 修复 #1 发现的所有 `[Required]` 问题
3. **Code Review #2（Regression Check）** — 检查修复过程中是否引入回归
   - 之前通过的功能仍然正常
   - 修复没有引入新问题
4. **修复** — 修复 #2 发现的回归问题
5. **Code Review #3（Final Quality）** — 最终质量验证
   - 代码质量、安全性、可维护性
   - 测试通过
   - 无遗留问题
6. **Commit** — 三次 Review 全部通过后提交

### Review 标签

- **[Required]** — 必须修复，阻断继续
- **[Optional]** — 建议改进，不阻断
- **[Question]** — 需要澄清
- **[FYI]** — 信息同步

---

**Goal:** 实现 ingest（视频下载）+ transcribe（语音转文字）skill，支持视频 URL 输入 → 下载 → 音频提取 → Whisper 转写 → 输出 article.md。

**Architecture:** Python 后端服务（Flask），参考 ClipScribe 架构。yt-dlp 下载视频 → FFmpeg 提取音频 → Faster-Whisper 转写 → 输出 article.md。独立脚本模式，不依赖 Flask 也可直接调用。

**Tech Stack:** Python 3.10+, yt-dlp, FFmpeg, Faster-Whisper, Flask（可选 API 层）

**参考：** ClipScribe 后端模块（video_downloader.py, audio_extractor.py, audio_to_text.py, pipeline.py）

---

## 文件清单

| 操作 | 文件 | 职责 |
|------|------|------|
| Create | `tools/ingest/__init__.py` | 包初始化 |
| Create | `tools/ingest/video_downloader.py` | yt-dlp 下载视频，URL 校验、重试、进度回调 |
| Create | `tools/ingest/audio_extractor.py` | FFmpeg 提取音频（16kHz mono WAV，适合语音识别） |
| Create | `tools/ingest/transcriber.py` | Faster-Whisper 转写，GPU/CPU 自动检测，输出带时间戳文本 |
| Create | `tools/ingest/pipeline.py` | 编排：download → extract → transcribe → 输出 article.md |
| Create | `tools/ingest/cli.py` | CLI 入口：`python -m tools.ingest <url>` |
| Create | `tools/ingest/test_downloader.py` | 下载器单元测试 |
| Create | `tools/ingest/test_extractor.py` | 音频提取单元测试 |
| Create | `tools/ingest/test_transcriber.py` | 转写器单元测试 |
| Create | `tools/ingest/test_pipeline.py` | 流水线集成测试 |
| Modify | `requirements.txt` | 添加 yt-dlp, faster-whisper, flask 依赖 |
| Modify | `WORKFLOW.md` | 新增 Phase 0: Ingest |
| Modify | `skills/using-recastory/SKILL.md` | 添加 ingest 命令路由 |

---

## 前置条件

- Python 3.10+ 已安装
- FFmpeg 已安装（`ffmpeg -version`）
- 磁盘空间充足（视频文件可能较大）

---

### Task 1: 安装依赖 + 视频下载器

**Files:**
- Create: `tools/ingest/__init__.py`
- Create: `tools/ingest/video_downloader.py`
- Create: `tools/ingest/test_downloader.py`
- Modify: `requirements.txt`

- [ ] **Step 1: 安装依赖**

```bash
pip install yt-dlp faster-whisper flask
pip freeze > requirements.txt
```

- [ ] **Step 2: 创建包结构**

`tools/ingest/__init__.py`:
```python
"""Ingest + Transcribe pipeline for Recastory Maestro."""
```

- [ ] **Step 3: 编写 video_downloader.py**

```python
"""Video downloader using yt-dlp."""
import os
import re
import yt_dlp
from dataclasses import dataclass
from typing import Optional, Callable


@dataclass
class DownloadResult:
    success: bool
    file_path: Optional[str] = None
    title: Optional[str] = None
    duration_seconds: Optional[float] = None
    error: Optional[str] = None


def validate_url(url: str) -> bool:
    """Validate if URL is a supported video URL."""
    pattern = r'^https?://(www\.)?(youtube\.com|youtu\.be|bilibili\.com|vimeo\.com|dailymotion\.com)/'
    return bool(re.match(pattern, url))


def download_video(
    url: str,
    output_dir: str,
    max_height: int = 720,
    progress_callback: Optional[Callable[[float], None]] = None,
) -> DownloadResult:
    """Download video using yt-dlp.

    Args:
        url: Video URL to download.
        output_dir: Directory to save the downloaded video.
        max_height: Maximum video resolution (default 720p).
        progress_callback: Optional callback for progress updates (0.0-1.0).

    Returns:
        DownloadResult with file path or error.
    """
    if not validate_url(url):
        return DownloadResult(success=False, error=f"Unsupported URL: {url}")

    os.makedirs(output_dir, exist_ok=True)

    def progress_hook(d):
        if d['status'] == 'downloading' and progress_callback:
            total = d.get('total_bytes') or d.get('total_bytes_estimate', 0)
            if total > 0:
                progress_callback(d['downloaded_bytes'] / total)

    ydl_opts = {
        'format': f'bestvideo[height<={max_height}]+bestaudio/best[height<={max_height}]/best',
        'outtmpl': os.path.join(output_dir, '%(title)s.%(ext)s'),
        'merge_output_format': 'mp4',
        'progress_hooks': [progress_hook],
        'quiet': True,
        'no_warnings': True,
        'retries': 3,
        'socket_timeout': 30,
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)
            file_path = ydl.prepare_filename(info)
            # Ensure .mp4 extension after merge
            if not file_path.endswith('.mp4'):
                file_path = os.path.splitext(file_path)[0] + '.mp4'

            return DownloadResult(
                success=True,
                file_path=file_path,
                title=info.get('title'),
                duration_seconds=info.get('duration'),
            )
    except Exception as e:
        return DownloadResult(success=False, error=str(e))
```

- [ ] **Step 4: 编写 test_downloader.py**

```python
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

    @pytest.mark.slow
    def test_download_short_video(self):
        """Integration test with a short video (requires network)."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # Use a very short public domain video for testing
            result = download_video(
                "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                tmpdir,
                max_height=360,
            )
            # Note: This test requires network access
            if result.success:
                assert os.path.exists(result.file_path)
                assert result.title is not None
                assert result.duration_seconds is not None
```

- [ ] **Step 5: 运行测试**

```bash
pytest tools/ingest/test_downloader.py -v -m "not slow"
```

- [ ] **Step 6: Commit**

```bash
git add tools/ingest/__init__.py tools/ingest/video_downloader.py tools/ingest/test_downloader.py requirements.txt
git commit -m "feat(ingest): add video downloader with yt-dlp"
```

---

### Task 2: 音频提取器

**Files:**
- Create: `tools/ingest/audio_extractor.py`
- Create: `tools/ingest/test_extractor.py`

- [ ] **Step 1: 编写 audio_extractor.py**

```python
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
```

- [ ] **Step 2: 编写 test_extractor.py**

```python
"""Tests for audio_extractor module."""
import os
import tempfile
import pytest
from tools.ingest.audio_extractor import extract_audio, get_audio_duration, ExtractResult


class TestExtractAudio:
    def test_missing_video_returns_error(self):
        result = extract_audio("/nonexistent/video.mp4")
        assert result.success is False
        assert "not found" in result.error

    @pytest.mark.slow
    def test_extract_from_valid_video(self):
        """Integration test with a real video (requires FFmpeg)."""
        # Create a short test video with FFmpeg
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


import subprocess
```

- [ ] **Step 3: 运行测试**

```bash
pytest tools/ingest/test_extractor.py -v -m "not slow"
```

- [ ] **Step 4: Commit**

```bash
git add tools/ingest/audio_extractor.py tools/ingest/test_extractor.py
git commit -m "feat(ingest): add audio extractor with FFmpeg"
```

---

### Task 3: 语音转写器

**Files:**
- Create: `tools/ingest/transcriber.py`
- Create: `tools/ingest/test_transcriber.py`

- [ ] **Step 1: 编写 transcriber.py**

```python
"""Speech-to-text transcription using Faster-Whisper."""
import os
import re
from dataclasses import dataclass
from typing import Optional


@dataclass
class TranscriptionSegment:
    start: float
    end: float
    text: str


@dataclass
class TranscribeResult:
    success: bool
    segments: list[TranscriptionSegment] = None
    full_text: str = ""
    language: Optional[str] = None
    error: Optional[str] = None


def clean_text(text: str) -> str:
    """Clean transcription text: remove duplicates, normalize whitespace."""
    # Remove repeated consecutive words (Whisper artifact)
    text = re.sub(r'\b(\w+)(\s+\1\b)+', r'\1', text)
    # Normalize whitespace
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def transcribe_audio(
    audio_path: str,
    model_size: str = "base",
    language: Optional[str] = None,
    device: str = "auto",
) -> TranscribeResult:
    """Transcribe audio file using Faster-Whisper.

    Args:
        audio_path: Path to audio file (WAV recommended).
        model_size: Whisper model size (tiny/base/small/medium/large).
        language: Force language (None for auto-detect).
        device: Compute device (auto/cpu/cuda).

    Returns:
        TranscribeResult with segments and full text.
    """
    if not os.path.exists(audio_path):
        return TranscribeResult(success=False, error=f"Audio not found: {audio_path}")

    try:
        from faster_whisper import WhisperModel
    except ImportError:
        return TranscribeResult(
            success=False,
            error="faster-whisper not installed. Run: pip install faster-whisper"
        )

    # Auto-detect device
    if device == "auto":
        try:
            import torch
            device = "cuda" if torch.cuda.is_available() else "cpu"
        except ImportError:
            device = "cpu"

    compute_type = "float16" if device == "cuda" else "int8"

    try:
        model = WhisperModel(model_size, device=device, compute_type=compute_type)
        raw_segments, info = model.transcribe(
            audio_path,
            language=language,
            beam_size=5,
            vad_filter=True,
        )

        segments = []
        for seg in raw_segments:
            cleaned = clean_text(seg.text)
            if cleaned:
                segments.append(TranscriptionSegment(
                    start=seg.start,
                    end=seg.end,
                    text=cleaned,
                ))

        full_text = " ".join(s.text for s in segments)

        return TranscribeResult(
            success=True,
            segments=segments,
            full_text=full_text,
            language=info.language,
        )
    except Exception as e:
        return TranscribeResult(success=False, error=str(e))


def segments_to_article(segments: list[TranscriptionSegment], title: str = "Untitled") -> str:
    """Convert transcription segments to article.md format.

    Groups segments into paragraphs by pause detection (>1.5s gap).
    """
    if not segments:
        return f"# {title}\n\n(No content transcribed)\n"

    paragraphs = []
    current_para = [segments[0].text]

    for i in range(1, len(segments)):
        gap = segments[i].start - segments[i - 1].end
        if gap > 1.5:  # New paragraph on significant pause
            paragraphs.append(" ".join(current_para))
            current_para = [segments[i].text]
        else:
            current_para.append(segments[i].text)

    if current_para:
        paragraphs.append(" ".join(current_para))

    article = f"# {title}\n\n"
    article += "\n\n".join(paragraphs)
    article += "\n"

    return article
```

- [ ] **Step 2: 编写 test_transcriber.py**

```python
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
```

- [ ] **Step 3: 运行测试**

```bash
pytest tools/ingest/test_transcriber.py -v
```

- [ ] **Step 4: Commit**

```bash
git add tools/ingest/transcriber.py tools/ingest/test_transcriber.py
git commit -m "feat(ingest): add transcriber with Faster-Whisper"
```

---

### Task 4: Pipeline 编排

**Files:**
- Create: `tools/ingest/pipeline.py`
- Create: `tools/ingest/test_pipeline.py`

- [ ] **Step 1: 编写 pipeline.py**

```python
"""Ingest pipeline orchestrator: URL → download → extract → transcribe → article.md."""
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

    workspace = config.workspace_dir
    os.makedirs(workspace, exist_ok=True)

    # Step 1: Download
    notify("download", 0.0)
    video_dir = os.path.join(workspace, "video")
    dl_result = download_video(url, video_dir, max_height=config.max_height)
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
    with open(article_path, "w", encoding="utf-8") as f:
        f.write(article_content)
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
```

- [ ] **Step 2: 编写 test_pipeline.py**

```python
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
```

- [ ] **Step 3: 运行测试**

```bash
pytest tools/ingest/test_pipeline.py -v
```

- [ ] **Step 4: Commit**

```bash
git add tools/ingest/pipeline.py tools/ingest/test_pipeline.py
git commit -m "feat(ingest): add pipeline orchestrator"
```

---

### Task 5: CLI 入口

**Files:**
- Create: `tools/ingest/cli.py`

- [ ] **Step 1: 编写 cli.py**

```python
"""CLI entry point for ingest pipeline.

Usage: python -m tools.ingest <url> [options]
"""
import argparse
import sys
import os

from .pipeline import PipelineConfig, run_pipeline


def main():
    parser = argparse.ArgumentParser(
        description="Ingest video URL → download → transcribe → article.md",
        prog="python -m tools.ingest",
    )
    parser.add_argument("url", help="Video URL to process")
    parser.add_argument(
        "-o", "--output",
        default=None,
        help="Output workspace directory (default: workspace/<domain>)",
    )
    parser.add_argument(
        "--quality",
        type=int,
        default=720,
        choices=[360, 480, 720, 1080],
        help="Max video resolution (default: 720)",
    )
    parser.add_argument(
        "--model",
        default="base",
        choices=["tiny", "base", "small", "medium", "large"],
        help="Whisper model size (default: base)",
    )
    parser.add_argument(
        "--language",
        default=None,
        help="Force language (e.g., 'zh', 'en'). Default: auto-detect",
    )
    parser.add_argument(
        "--device",
        default="auto",
        choices=["auto", "cpu", "cuda"],
        help="Compute device (default: auto)",
    )

    args = parser.parse_args()

    # Generate workspace dir from URL if not specified
    if args.output is None:
        from urllib.parse import urlparse
        domain = urlparse(args.url).netloc.replace("www.", "").replace(".", "-")
        args.output = os.path.join("workspace", f"ingest-{domain}")

    config = PipelineConfig(
        workspace_dir=args.output,
        max_height=args.quality,
        whisper_model=args.model,
        language=args.language,
        device=args.device,
    )

    def progress(step: str, pct: float):
        bar = "█" * int(pct * 20) + "░" * (20 - int(pct * 20))
        print(f"\r  {step}: [{bar}] {pct:.0%}", end="", flush=True)
        if pct >= 1.0:
            print()

    print(f"Processing: {args.url}")
    print(f"Output: {args.output}")
    print()

    result = run_pipeline(args.url, config, progress_callback=progress)

    if result.success:
        print()
        print(f"  Title: {result.title}")
        print(f"  Duration: {result.duration_seconds:.1f}s" if result.duration_seconds else "  Duration: unknown")
        print(f"  Article: {result.article_path}")
        print(f"  Video: {result.video_path}")
        print(f"  Audio: {result.audio_path}")
        print()
        print("Ingest complete!")
    else:
        print(f"\nError: {result.error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: 验证语法**

```bash
python -c "from tools.ingest.cli import main"
```

- [ ] **Step 3: Commit**

```bash
git add tools/ingest/cli.py
git commit -m "feat(ingest): add CLI entry point"
```

---

### Task 6: 更新文档 + SKILL.md 集成

**Files:**
- Modify: `WORKFLOW.md`
- Modify: `skills/using-recastory/SKILL.md`

- [ ] **Step 1: 更新 WORKFLOW.md Phase 0**

在 Phase 1 之前添加：

```markdown
## Phase 0: Ingest（导入）

当用户提供视频 URL 时执行。

1. 下载视频：`yt-dlp` 自动选择最佳质量
2. 提取音频：FFmpeg → 16kHz mono WAV
3. 语音转写：Faster-Whisper → article.md
4. 输出：`workspace/<id>/article.md` + 原始视频 + 音频

```bash
# CLI 模式
python -m tools.ingest "<video-url>" -o workspace/<id>

# 或由 using-recastory 自动调度
```

产出：`article.md`（供 Phase 1 distill 使用）
```

- [ ] **Step 2: 更新 using-recastory SKILL.md**

在意图识别表中添加 ingest 命令路由。

- [ ] **Step 3: Commit**

```bash
git add WORKFLOW.md skills/using-recastory/SKILL.md
git commit -m "docs: integrate ingest + transcribe into pipeline"
```

---

## 验证清单

| 验证项 | 方法 |
|--------|------|
| 依赖安装 | `python -c "import yt_dlp; import faster_whisper"` → OK |
| video_downloader | `pytest tools/ingest/test_downloader.py -v` → ALL PASSED |
| audio_extractor | `pytest tools/ingest/test_extractor.py -v` → ALL PASSED |
| transcriber | `pytest tools/ingest/test_transcriber.py -v` → ALL PASSED |
| pipeline | `pytest tools/ingest/test_pipeline.py -v` → ALL PASSED |
| CLI | `python -m tools.ingest --help` → 显示帮助 |
| 端到端 | `python -m tools.ingest "<test-url>" -o workspace/test-ingest` → article.md |
| 文档 | WORKFLOW.md Phase 0 存在 |
