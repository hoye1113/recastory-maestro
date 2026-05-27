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
    segments: Optional[list[TranscriptionSegment]] = None
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

    segments = sorted(segments, key=lambda s: s.start)

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
