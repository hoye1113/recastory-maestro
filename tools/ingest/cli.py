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
    parser.add_argument(
        "--cookies",
        default=None,
        help="Path to cookies.txt file (for sites requiring authentication)",
    )
    parser.add_argument(
        "--cookies-from-browser",
        default=None,
        choices=["chrome", "firefox", "edge", "opera", "vivaldi", "brave"],
        help="Extract cookies from browser (requires browser to be closed)",
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
        cookies_file=args.cookies,
        cookies_from_browser=args.cookies_from_browser,
    )

    def progress(step: str, pct: float):
        bar = "#" * int(pct * 20) + "-" * (20 - int(pct * 20))
        print(f"\r  {step}: [{bar}] {pct:.0%}", end="", flush=True)
        if pct >= 1.0:
            print()

    print(f"Processing: {args.url}")
    print(f"Output: {args.output}")
    print()

    try:
        result = run_pipeline(args.url, config, progress_callback=progress)
    except KeyboardInterrupt:
        print("\nInterrupted.", file=sys.stderr)
        sys.exit(130)
    except Exception as e:
        print(f"\nUnexpected error: {e}", file=sys.stderr)
        sys.exit(1)

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
