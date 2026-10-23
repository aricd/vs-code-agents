#!/usr/bin/env python3
"""Fetch a YouTube transcript and emit it as clean Markdown.

This is the deterministic, side-effecting shell for the ``extract-transcript``
skill. It knows how to turn a YouTube URL (or bare video id) into a Markdown
document containing a metadata header and the transcript body. All of the
"decide what to do with the transcript" work (summarizing, rewriting, etc.) is
left to the calling agent -- this script's only job is to reliably get the raw
material and format it predictably.

Design notes for whoever extends this later
--------------------------------------------
* The YouTube-specific pieces are intentionally isolated in ``extract_video_id``
  and ``fetch_transcript``. To add another platform, add a sibling
  ``extract_<platform>_id`` / ``fetch_<platform>`` pair and dispatch on the URL
  host in ``main``. The Markdown formatting functions below are
  platform-agnostic and should be reused as-is.
* Formatting functions are pure (input -> string). Keep them that way so they
  stay trivially testable.

Usage
-----
    python fetch_transcript.py <url_or_id> [options]

Common options:
    -o, --output FILE        Write Markdown to FILE instead of stdout.
    --languages en de ...    Preferred language codes, highest priority first.
    --group-seconds N        Merge snippets into ~N-second paragraphs (default 30).
    --no-timestamps          Emit clean prose paragraphs with no timestamps.
    --raw                    One line per caption snippet (no grouping).
    --list-languages         Only list the transcripts available for the video.

Requires: pip install youtube-transcript-api
"""

from __future__ import annotations

import argparse
import datetime as _dt
import json
import re
import sys
import urllib.request
from typing import List, Optional, Sequence

try:
    from youtube_transcript_api import YouTubeTranscriptApi
    from youtube_transcript_api._errors import (
        CouldNotRetrieveTranscript,
        NoTranscriptFound,
        TranscriptsDisabled,
    )
except ImportError:  # pragma: no cover - dependency guard
    sys.stderr.write(
        "Missing dependency. Install it with:\n"
        "    pip install youtube-transcript-api\n"
    )
    raise


# --------------------------------------------------------------------------- #
# YouTube-specific input handling (the part to generalize for new platforms).
# --------------------------------------------------------------------------- #

_YOUTUBE_ID_RE = re.compile(r"^[0-9A-Za-z_-]{11}$")
_URL_PATTERNS = [
    re.compile(r"(?:v=|/v/)([0-9A-Za-z_-]{11})"),
    re.compile(r"youtu\.be/([0-9A-Za-z_-]{11})"),
    re.compile(r"/shorts/([0-9A-Za-z_-]{11})"),
    re.compile(r"/live/([0-9A-Za-z_-]{11})"),
    re.compile(r"/embed/([0-9A-Za-z_-]{11})"),
]


def extract_video_id(url_or_id: str) -> str:
    """Return the 11-character YouTube id from a URL or a bare id.

    Accepts the common forms: watch?v=, youtu.be/, /shorts/, /live/, /embed/,
    with or without extra query parameters, and a bare id passed directly.
    """
    candidate = url_or_id.strip()
    if _YOUTUBE_ID_RE.match(candidate):
        return candidate
    for pattern in _URL_PATTERNS:
        match = pattern.search(candidate)
        if match:
            return match.group(1)
    raise ValueError(
        f"Could not extract a YouTube video id from: {url_or_id!r}. "
        "Pass a watch/shorts/youtu.be URL or an 11-character video id."
    )


def fetch_video_title(video_id: str) -> Optional[str]:
    """Best-effort video title via YouTube's public oEmbed endpoint.

    The transcript API does not return the title, so we fetch it separately.
    This is purely cosmetic -- any failure (offline, blocked, private video)
    falls back to ``None`` and the caller uses the id instead.
    """
    url = (
        "https://www.youtube.com/oembed?url="
        f"https://www.youtube.com/watch?v={video_id}&format=json"
    )
    try:
        with urllib.request.urlopen(url, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        return data.get("title")
    except Exception:
        return None


def fetch_transcript(
    video_id: str, languages: Optional[Sequence[str]]
):
    """Fetch the best transcript for ``video_id``.

    Returns a tuple of ``(fetched_transcript, transcript_meta)`` where
    ``transcript_meta`` is the ``Transcript`` object carrying language metadata.

    Selection strategy:
      * If ``languages`` is given, honor that priority list.
      * Otherwise prefer English, then fall back to the first available
        transcript in any language so a non-English video still works.
    ``find_transcript`` already prefers manually-created captions over
    auto-generated ones when both exist.
    """
    api = YouTubeTranscriptApi()
    transcript_list = api.list(video_id)

    if languages:
        meta = transcript_list.find_transcript(list(languages))
    else:
        try:
            meta = transcript_list.find_transcript(["en"])
        except NoTranscriptFound:
            meta = next(iter(transcript_list))

    return meta.fetch(), meta


def list_available_languages(video_id: str) -> List[str]:
    """Return human-readable descriptions of every transcript on the video."""
    api = YouTubeTranscriptApi()
    lines = []
    for t in api.list(video_id):
        kind = "auto-generated" if t.is_generated else "manual"
        translatable = ", translatable" if t.is_translatable else ""
        lines.append(f"{t.language} ({t.language_code}) - {kind}{translatable}")
    return lines


# --------------------------------------------------------------------------- #
# Pure formatting helpers (platform-agnostic; keep these free of side effects).
# --------------------------------------------------------------------------- #

def format_timestamp(seconds: float) -> str:
    """Seconds -> ``H:MM:SS`` (hours dropped when zero, e.g. ``4:05``)."""
    total = int(seconds)
    hours, remainder = divmod(total, 3600)
    minutes, secs = divmod(remainder, 60)
    if hours:
        return f"{hours}:{minutes:02d}:{secs:02d}"
    return f"{minutes}:{secs:02d}"


def _clean(text: str) -> str:
    """Collapse whitespace/newlines inside a snippet to a single space."""
    return " ".join(text.split())


def group_snippets(snippets, group_seconds: float):
    """Merge caption snippets into ~``group_seconds`` paragraph blocks.

    Yields ``(start_seconds, text)`` tuples. Grouping makes the transcript far
    more readable and much easier to summarize than the raw ~2-second captions.
    """
    block_start = None
    parts: List[str] = []
    for snip in snippets:
        # Close the current block *before* adding a snippet that crosses the
        # threshold, so that snippet opens the next paragraph.
        if block_start is not None and snip.start - block_start >= group_seconds:
            yield block_start, " ".join(parts)
            block_start = None
            parts = []
        if block_start is None:
            block_start = snip.start
        text = _clean(snip.text)
        if text:
            parts.append(text)
    if parts:
        yield block_start or 0.0, " ".join(parts)


def build_markdown(
    *,
    video_id: str,
    title: Optional[str],
    fetched,
    meta,
    group_seconds: float,
    timestamps: bool,
    raw: bool,
) -> str:
    """Assemble the full Markdown document (header + body)."""
    heading = title or f"YouTube transcript {video_id}"
    source = f"https://www.youtube.com/watch?v={video_id}"
    kind = "auto-generated" if meta.is_generated else "manual"
    duration = fetched[-1].start + fetched[-1].duration if len(fetched) else 0
    retrieved = _dt.date.today().isoformat()

    header = [
        f"# {heading}",
        "",
        f"- **Source:** {source}",
        f"- **Video ID:** `{video_id}`",
        f"- **Language:** {meta.language} (`{meta.language_code}`) - {kind}",
        f"- **Approx. length:** {format_timestamp(duration)}",
        f"- **Caption snippets:** {len(fetched)}",
        f"- **Retrieved:** {retrieved}",
        "",
        "---",
        "",
        "## Transcript",
        "",
        "",
    ]

    body: List[str] = []
    if raw:
        for snip in fetched:
            text = _clean(snip.text)
            if not text:
                continue
            if timestamps:
                body.append(f"`[{format_timestamp(snip.start)}]` {text}")
            else:
                body.append(text)
        body_text = "\n".join(body)
    else:
        for start, text in group_snippets(fetched, group_seconds):
            if not text:
                continue
            if timestamps:
                body.append(f"**[{format_timestamp(start)}]** {text}")
            else:
                body.append(text)
        body_text = "\n\n".join(body)

    return "\n".join(header) + body_text + "\n"


# --------------------------------------------------------------------------- #
# CLI shell.
# --------------------------------------------------------------------------- #

def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Fetch a YouTube transcript and emit it as Markdown."
    )
    parser.add_argument("url_or_id", help="YouTube URL or 11-character video id")
    parser.add_argument("-o", "--output", help="Write Markdown to this file")
    parser.add_argument(
        "--languages",
        nargs="+",
        metavar="LANG",
        help="Preferred language codes, highest priority first (e.g. en de)",
    )
    parser.add_argument(
        "--group-seconds",
        type=float,
        default=30.0,
        help="Merge snippets into ~N-second paragraphs (default: 30)",
    )
    parser.add_argument(
        "--no-timestamps",
        action="store_true",
        help="Emit clean prose with no timestamps (best for summarizing)",
    )
    parser.add_argument(
        "--raw",
        action="store_true",
        help="One line per caption snippet instead of grouped paragraphs",
    )
    parser.add_argument(
        "--list-languages",
        action="store_true",
        help="List available transcripts for the video and exit",
    )
    args = parser.parse_args(argv)

    try:
        video_id = extract_video_id(args.url_or_id)
    except ValueError as exc:
        sys.stderr.write(f"Error: {exc}\n")
        return 2

    if args.list_languages:
        try:
            for line in list_available_languages(video_id):
                print(line)
            return 0
        except TranscriptsDisabled:
            sys.stderr.write("This video has transcripts/subtitles disabled.\n")
            return 1
        except CouldNotRetrieveTranscript as exc:
            sys.stderr.write(f"Could not retrieve transcript list: {exc}\n")
            return 1

    try:
        fetched, meta = fetch_transcript(video_id, args.languages)
    except TranscriptsDisabled:
        sys.stderr.write(
            "This video has transcripts/subtitles disabled, so none can be "
            "fetched.\n"
        )
        return 1
    except NoTranscriptFound:
        sys.stderr.write(
            "No transcript found for the requested language(s). Run with "
            "--list-languages to see what is available.\n"
        )
        return 1
    except CouldNotRetrieveTranscript as exc:
        # Covers RequestBlocked / IpBlocked / VideoUnavailable / AgeRestricted.
        sys.stderr.write(
            f"Could not retrieve transcript: {exc}\n"
            "If you are on a cloud/VPN IP, YouTube may be blocking the request; "
            "try from a residential connection or configure a proxy.\n"
        )
        return 1
    except Exception as exc:  # noqa: BLE001 - surface network errors cleanly
        # e.g. proxy/DNS/connection failures from the underlying HTTP client,
        # which are common on cloud hosts and are not subclasses of the
        # library's own exceptions.
        sys.stderr.write(
            f"Network error while contacting YouTube: {exc}\n"
            "Check connectivity; on a cloud/VPN IP YouTube may block requests. "
            "Run from a residential connection or configure a proxy.\n"
        )
        return 1

    title = fetch_video_title(video_id)
    markdown = build_markdown(
        video_id=video_id,
        title=title,
        fetched=fetched,
        meta=meta,
        group_seconds=args.group_seconds,
        timestamps=not args.no_timestamps,
        raw=args.raw,
    )

    if args.output:
        with open(args.output, "w", encoding="utf-8") as handle:
            handle.write(markdown)
        sys.stderr.write(f"Wrote transcript to {args.output}\n")
    else:
        sys.stdout.write(markdown)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
