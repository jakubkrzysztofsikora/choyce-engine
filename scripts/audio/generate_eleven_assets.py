#!/usr/bin/env python3
"""Generate ElevenLabs audio assets for choyce-engine.

Outputs:
  data/audio/voice/  - Polish kid-friendly mascot voice lines (.mp3)
  data/audio/sfx/    - Sound effects via ElevenLabs sound generation (.mp3)
  data/audio/music/  - Looping ambient tracks (.mp3) via music endpoint (if available)

Key picked up from ELEVENLABS_API_KEY env var.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

ROOT = Path(__file__).resolve().parents[2]
VOICE_DIR = ROOT / "data" / "audio" / "voice"
SFX_DIR = ROOT / "data" / "audio" / "sfx" / "eleven"
MUSIC_DIR = ROOT / "data" / "audio" / "music"

API_KEY = os.environ.get("ELEVENLABS_API_KEY")
if not API_KEY:
    print("ELEVENLABS_API_KEY not set", file=sys.stderr)
    sys.exit(1)

# Multilingual v2 supports Polish. Female warm voice ids (premade):
# Charlotte: XB0fDUnXU5powFXDhCwa, Lily: pFZP5JQG7iQjIQuC4Bku, Aria: 9BWtsMINqrJLrRacOk9x
MASCOT_VOICE_ID = "XB0fDUnXU5powFXDhCwa"
TTS_MODEL = "eleven_multilingual_v2"

VOICE_LINES = {
    "greet_landing":     "Cześć! Jestem twoim królikiem. Naciśnij Zagraj!",
    "world_picker":      "Wybierz świat do gry!",
    "celebrate_win":     "Hura! Świetna robota!",
    "celebrate_collect": "Brawo! Złapałeś!",
    "block_oops":        "Spróbuj inaczej, kolego.",
    "tools_unavailable": "Narzędzia śpią. Zaraz wracają!",
    "no_world":          "Najpierw stwórz świat!",
    "encourage_create":  "Naciśnij Zrób, żeby coś zbudować.",
    "parent_zone":       "Tu rządzą rodzice.",
    "session_end":       "Koniec gry. Zagrasz jeszcze?",
}

SFX_PROMPTS = {
    "ui_click":         "soft warm UI click pop, kid-friendly, 100ms",
    "ui_hover":         "tiny ascending bell tone, very short, gentle",
    "ui_confirm":       "happy cheerful confirm chime, 3 ascending notes, 400ms",
    "ui_back":          "soft descending two-tone, short, friendly",
    "collect_coin":     "bright cartoon coin pickup, sparkle ding, 300ms",
    "collect_star":     "magical sparkle pickup, warm twinkle, 500ms",
    "victory_fanfare":  "joyful cartoon fanfare, 4 ascending notes, celebratory, 1.2s",
    "block_buzz":       "clear gentle rejection chime for child app, descending two-tone, friendly but unmistakable, target peak -3 dBFS, 250ms",
    "spawn_pop":        "magical poof appearing, soft whoosh and twinkle, 400ms",
    "footstep_grass":   "soft footstep on grass, single tap, kid character, 80ms",
    "footstep_sand":    "soft footstep on sand, soft scrape, 100ms",
    "jump_up":          "cute little jump squeak, ascending, 200ms",
    "land_soft":        "soft kid landing, small thump, 100ms",
}

MUSIC_PROMPTS = {
    "landing_ambient":   "gentle warm playful kid game lobby music loop, ukulele and soft xylophone, 120 bpm, looping, 30 seconds, cheerful but calm",
    "adventure_island":  "cheerful pirate adventure island music, ukulele steel drum, tropical, kid friendly, looping, 30 seconds",
    "little_farm":       "cozy farm music, banjo and harmonica, warm sunny morning, kid friendly, looping, 30 seconds",
    "mushroom_forest":   "magical mushroom forest music, soft pizzicato strings, glockenspiel, ambient mystery, kid friendly, looping, 30 seconds",
    "celebration":       "victory celebration fanfare, brass and timpani, 8 seconds, triumphant",
}


def http_post(url: str, body: dict, accept: str = "audio/mpeg") -> bytes:
    req = Request(
        url,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "xi-api-key": API_KEY,
            "Content-Type": "application/json",
            "Accept": accept,
        },
        method="POST",
    )
    with urlopen(req, timeout=120) as resp:
        return resp.read()


def gen_voice(name: str, text: str) -> bool:
    out = VOICE_DIR / f"{name}.mp3"
    if out.exists() and out.stat().st_size > 1024:
        print(f"[skip] voice/{name}.mp3 already present ({out.stat().st_size} bytes)")
        return True
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{MASCOT_VOICE_ID}"
    body = {
        "text": text,
        "model_id": TTS_MODEL,
        "voice_settings": {
            "stability": 0.55,
            "similarity_boost": 0.8,
            "style": 0.35,
            "use_speaker_boost": True,
        },
    }
    try:
        data = http_post(url, body)
        out.write_bytes(data)
        print(f"[ok] voice/{name}.mp3 ({len(data)} bytes)")
        return True
    except HTTPError as e:
        print(f"[fail] voice/{name}.mp3 — HTTP {e.code}: {e.read().decode('utf-8', errors='replace')[:200]}", file=sys.stderr)
    except URLError as e:
        print(f"[fail] voice/{name}.mp3 — {e}", file=sys.stderr)
    return False


def gen_sfx(name: str, prompt: str) -> bool:
    out = SFX_DIR / f"{name}.mp3"
    if out.exists() and out.stat().st_size > 1024:
        print(f"[skip] sfx/{name}.mp3 already present ({out.stat().st_size} bytes)")
        return True
    url = "https://api.elevenlabs.io/v1/sound-generation"
    body = {
        "text": prompt,
        "duration_seconds": None,  # auto
        "prompt_influence": 0.5,
    }
    try:
        data = http_post(url, body)
        out.write_bytes(data)
        print(f"[ok] sfx/{name}.mp3 ({len(data)} bytes)")
        return True
    except HTTPError as e:
        print(f"[fail] sfx/{name}.mp3 — HTTP {e.code}: {e.read().decode('utf-8', errors='replace')[:200]}", file=sys.stderr)
    except URLError as e:
        print(f"[fail] sfx/{name}.mp3 — {e}", file=sys.stderr)
    return False


def gen_music(name: str, prompt: str) -> bool:
    out = MUSIC_DIR / f"{name}.mp3"
    if out.exists() and out.stat().st_size > 1024:
        print(f"[skip] music/{name}.mp3 already present ({out.stat().st_size} bytes)")
        return True
    # Try newer "/v1/music" endpoint
    url = "https://api.elevenlabs.io/v1/music"
    body = {
        "prompt": prompt,
        "music_length_ms": 30000,
        "model_id": "music_v1",
    }
    try:
        data = http_post(url, body)
        out.write_bytes(data)
        print(f"[ok] music/{name}.mp3 ({len(data)} bytes)")
        return True
    except HTTPError as e:
        msg = e.read().decode('utf-8', errors='replace')[:200]
        print(f"[fail] music/{name}.mp3 — HTTP {e.code}: {msg}", file=sys.stderr)
    except URLError as e:
        print(f"[fail] music/{name}.mp3 — {e}", file=sys.stderr)
    return False


def main() -> int:
    VOICE_DIR.mkdir(parents=True, exist_ok=True)
    SFX_DIR.mkdir(parents=True, exist_ok=True)
    MUSIC_DIR.mkdir(parents=True, exist_ok=True)

    tally = {"voice_ok": 0, "voice_fail": 0, "sfx_ok": 0, "sfx_fail": 0, "music_ok": 0, "music_fail": 0}

    print("=== Voice lines (Polish) ===")
    for name, text in VOICE_LINES.items():
        if gen_voice(name, text):
            tally["voice_ok"] += 1
        else:
            tally["voice_fail"] += 1

    print("\n=== Sound effects ===")
    for name, prompt in SFX_PROMPTS.items():
        if gen_sfx(name, prompt):
            tally["sfx_ok"] += 1
        else:
            tally["sfx_fail"] += 1

    print("\n=== Music loops ===")
    for name, prompt in MUSIC_PROMPTS.items():
        if gen_music(name, prompt):
            tally["music_ok"] += 1
        else:
            tally["music_fail"] += 1

    print("\n=== Summary ===")
    print(json.dumps(tally, indent=2))
    return 0 if tally["voice_fail"] + tally["sfx_fail"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
