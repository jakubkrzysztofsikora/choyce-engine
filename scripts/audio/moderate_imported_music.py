#!/usr/bin/env python3
"""Lyric/STT moderation pass for imported CC0 music tracks.

Pipeline per file in data/audio/music/voxel/*.mp3:
  1. Run ElevenLabs Speech-to-Text (PL + EN auto-detect) on the mp3.
  2. Apply the same word-list moderation rules used by
     LocalModerationAdapter (data/moderation/rules_pl.json).
  3. REJECT if any term in categories: violence, weapons, drugs,
     gambling, profanity, adult_content, horror.
  4. Update data/audio/music/voxel/MODERATION_LOG.md.

This script is offline-safe in --dry-run mode: it lists what *would*
be rejected (re-using cached transcripts when present) without calling
the ElevenLabs API.

Key picked up from ELEVENLABS_API_KEY env var.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import unicodedata
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

ROOT = Path(__file__).resolve().parents[2]
MUSIC_DIR = ROOT / "data" / "audio" / "music" / "voxel"
RULES_FILE = ROOT / "data" / "moderation" / "rules_pl.json"
CACHE_DIR = MUSIC_DIR / ".transcripts"
LOG_FILE = MUSIC_DIR / "MODERATION_LOG.md"

API_KEY = os.environ.get("ELEVENLABS_API_KEY") or os.environ.get("ELEVEN_LABS_API_KEY")
STT_URL = "https://api.elevenlabs.io/v1/speech-to-text"
STT_MODEL = "scribe_v1"  # ElevenLabs multilingual STT (PL + EN supported)

# Categories that REJECT the track outright.  horror + adult_content kept
# even though the source is CC0 instrumental — defence in depth.
HARD_REJECT_CATEGORIES = {
    "violence",
    "weapons",
    "drugs",
    "gambling",
    "profanity",
    "adult_content",
    "horror",
}

POLISH_DIACRITICS = {
    "ą": "a", "ć": "c", "ę": "e", "ł": "l", "ń": "n",
    "ó": "o", "ś": "s", "ź": "z", "ż": "z",
}


def _normalize(text: str) -> str:
    out = []
    for ch in text.lower():
        if ch in POLISH_DIACRITICS:
            out.append(POLISH_DIACRITICS[ch])
        else:
            # Strip combining marks (NFD), keep ASCII letters/digits/space.
            decomposed = unicodedata.normalize("NFD", ch)
            for c in decomposed:
                if unicodedata.category(c) == "Mn":
                    continue
                if c.isalnum() or c == " ":
                    out.append(c)
                else:
                    out.append(" ")
    return " ".join("".join(out).split())


def _load_rules() -> dict:
    with RULES_FILE.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def _scan_for_blocked(transcript: str, rules: dict) -> list[tuple[str, str]]:
    """Return list of (category, term) hits across HARD_REJECT_CATEGORIES."""
    norm = _normalize(transcript)
    tokens = set(norm.split())
    hits: list[tuple[str, str]] = []
    for cat, cat_rules in rules.get("categories", {}).items():
        if cat not in HARD_REJECT_CATEGORIES:
            continue
        for term in cat_rules.get("terms", []):
            n_term = _normalize(term)
            if " " in n_term:
                if n_term in norm:
                    hits.append((cat, term))
            else:
                if n_term in tokens:
                    hits.append((cat, term))
    return hits


def _stt(mp3: Path) -> str:
    """Call ElevenLabs STT. Returns transcript text (may be empty)."""
    if not API_KEY:
        raise RuntimeError("ELEVENLABS_API_KEY not set")
    boundary = f"----MOD{int(time.time()*1000)}"
    body_parts: list[bytes] = []

    def add_field(name: str, value: str) -> None:
        body_parts.append(f"--{boundary}\r\n".encode())
        body_parts.append(
            f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode()
        )
        body_parts.append(value.encode())
        body_parts.append(b"\r\n")

    def add_file(name: str, filename: str, content: bytes) -> None:
        body_parts.append(f"--{boundary}\r\n".encode())
        body_parts.append(
            f'Content-Disposition: form-data; name="{name}"; '
            f'filename="{filename}"\r\n'.encode()
        )
        body_parts.append(b"Content-Type: audio/mpeg\r\n\r\n")
        body_parts.append(content)
        body_parts.append(b"\r\n")

    add_field("model_id", STT_MODEL)
    add_field("tag_audio_events", "false")
    add_field("diarize", "false")
    add_file("file", mp3.name, mp3.read_bytes())
    body_parts.append(f"--{boundary}--\r\n".encode())

    req = Request(
        STT_URL,
        data=b"".join(body_parts),
        headers={
            "xi-api-key": API_KEY,
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "Accept": "application/json",
        },
        method="POST",
    )
    with urlopen(req, timeout=300) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return data.get("text", "") or ""


def _cached_transcript(mp3: Path) -> str | None:
    cache = CACHE_DIR / f"{mp3.stem}.txt"
    if cache.exists():
        return cache.read_text(encoding="utf-8")
    return None


def _store_transcript(mp3: Path, transcript: str) -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    (CACHE_DIR / f"{mp3.stem}.txt").write_text(transcript, encoding="utf-8")


def _process_track(mp3: Path, rules: dict, dry_run: bool) -> dict:
    cached = _cached_transcript(mp3)
    if cached is not None:
        transcript = cached
        source = "cache"
    elif dry_run:
        # Treat missing transcript in dry-run as empty (no rejection decision).
        transcript = ""
        source = "skip(dry-run)"
    else:
        try:
            transcript = _stt(mp3)
            _store_transcript(mp3, transcript)
            source = "stt"
        except (HTTPError, URLError, RuntimeError) as exc:
            # Fail-closed: STT failure means we cannot certify the track.
            return {
                "file": mp3.name,
                "verdict": "REJECT",
                "reason": f"STT failed: {exc}",
                "transcript_excerpt": "",
                "hits": [],
                "source": "error",
            }

    hits = _scan_for_blocked(transcript, rules)
    if hits:
        return {
            "file": mp3.name,
            "verdict": "REJECT",
            "reason": "Lyric moderation hit",
            "transcript_excerpt": transcript[:160],
            "hits": hits,
            "source": source,
        }
    return {
        "file": mp3.name,
        "verdict": "PASS",
        "reason": (
            "Instrumental — no lyrics detected"
            if not transcript.strip()
            else "Lyrics clean"
        ),
        "transcript_excerpt": transcript[:160],
        "hits": [],
        "source": source,
    }


def _write_log(results: list[dict], dry_run: bool) -> None:
    lines = [
        "# Music Moderation Log",
        "",
        f"_Generated by `scripts/audio/moderate_imported_music.py`"
        f"{' (dry-run)' if dry_run else ''}_",
        "",
        "Pipeline: ElevenLabs STT (scribe_v1, PL+EN) → "
        "rules_pl.json word-list scan. Categories that reject: "
        + ", ".join(sorted(HARD_REJECT_CATEGORIES))
        + ".",
        "",
        "| File | Verdict | Source | Hits | Reason |",
        "|------|---------|--------|------|--------|",
    ]
    pass_count = 0
    reject_count = 0
    for r in results:
        if r["verdict"] == "PASS":
            pass_count += 1
        else:
            reject_count += 1
        hit_str = (
            ", ".join(f"{cat}:{term}" for cat, term in r["hits"])
            if r["hits"]
            else "—"
        )
        lines.append(
            "| `{file}` | **{verdict}** | {source} | {hits} | {reason} |".format(
                file=r["file"],
                verdict=r["verdict"],
                source=r["source"],
                hits=hit_str,
                reason=r["reason"].replace("|", "/"),
            )
        )
    lines.extend(
        [
            "",
            f"**Pass: {pass_count}  Reject: {reject_count}  Total: {len(results)}**",
            "",
        ]
    )
    LOG_FILE.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help=(
            "Skip ElevenLabs calls. Use cached transcripts only; missing "
            "transcripts are treated as 'no decision yet'."
        ),
    )
    parser.add_argument(
        "--delete-rejected",
        action="store_true",
        help="If set, REJECTED mp3 files are deleted from voxel/.",
    )
    args = parser.parse_args()

    if not MUSIC_DIR.exists():
        print(f"No music dir at {MUSIC_DIR}", file=sys.stderr)
        return 2

    tracks = sorted(p for p in MUSIC_DIR.glob("*.mp3"))
    if not tracks:
        print("No tracks to moderate.")
        return 0

    rules = _load_rules()
    results: list[dict] = []
    for mp3 in tracks:
        res = _process_track(mp3, rules, dry_run=args.dry_run)
        results.append(res)
        verdict_marker = "[OK]" if res["verdict"] == "PASS" else "[BLOCK]"
        print(
            f"{verdict_marker} {res['file']} "
            f"(source={res['source']}) — {res['reason']}"
        )
        if res["verdict"] == "REJECT" and args.delete_rejected and not args.dry_run:
            mp3.unlink()
            print(f"  deleted {mp3.name}")

    _write_log(results, dry_run=args.dry_run)
    print(f"\nLog: {LOG_FILE}")
    pass_n = sum(1 for r in results if r["verdict"] == "PASS")
    rej_n = sum(1 for r in results if r["verdict"] == "REJECT")
    print(f"Pass: {pass_n}  Reject: {rej_n}  Total: {len(results)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
