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
    """Validate if URL is a supported video URL (first-pass check before yt-dlp)."""
    pattern = r'^https?://(www\.)?(youtube\.com|youtu\.be|bilibili\.com|b23\.tv|vimeo\.com|dailymotion\.com|dai\.ly)(/|$)'
    return bool(re.match(pattern, url))


def download_video(
    url: str,
    output_dir: str,
    max_height: int = 720,
    progress_callback: Optional[Callable[[float], None]] = None,
) -> DownloadResult:
    """Download video using yt-dlp."""
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
            if not file_path.endswith('.mp4'):
                file_path = os.path.splitext(file_path)[0] + '.mp4'

            if not os.path.exists(file_path):
                return DownloadResult(
                    success=False,
                    error=f"Download completed but file not found at {file_path}",
                )

            return DownloadResult(
                success=True,
                file_path=file_path,
                title=info.get('title'),
                duration_seconds=info.get('duration'),
            )
    except Exception as e:
        return DownloadResult(success=False, error=str(e))
