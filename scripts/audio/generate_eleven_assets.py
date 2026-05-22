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

# Multilingual v2 supports Polish. Ninja mascot uses Adam — deep,
# calm, narrative male voice that reads as "wise sensei" rather than
# "edgelord". Still kid-safe per CLAUDE.md (age 5-8 target).
# Older voice ids kept for reference:
#   Charlotte (warm female): XB0fDUnXU5powFXDhCwa
#   Lily:                    pFZP5JQG7iQjIQuC4Bku
#   Aria:                    9BWtsMINqrJLrRacOk9x
#   Daniel (deep brit):      onwK4e9ZLuTAKqWW03F9
#   Adam (deep narrator):    pNInz6obpgDQGcFmaJgB  <- ACTIVE
MASCOT_VOICE_ID = "pNInz6obpgDQGcFmaJgB"
TTS_MODEL = "eleven_multilingual_v2"

# Sigma-coded short declarative lines — calm authority, dry humor,
# slight mystery. No yelling, no rage, no scary content. Reads like
# a chill ninja sensei talking to a kid apprentice. PL only.
VOICE_LINES = {
    "greet_landing":     "Cześć. Jestem twoim ninja. Wciśnij Zagraj.",
    "world_picker":      "Wybierz świat. Czas iść.",
    "celebrate_win":     "Tak. Dobra robota.",
    "celebrate_collect": "Nieźle.",
    "block_oops":        "Spróbuj jeszcze raz. Spokojnie.",
    "tools_unavailable": "Sprzęt śpi. Chwila.",
    "no_world":          "Najpierw stwórz świat. Działaj.",
    "encourage_create":  "Naciśnij Zrób. Buduj swój świat.",
    "parent_zone":       "Strefa dla dorosłych. Stop.",
    "session_end":       "Koniec. Wracaj jutro.",
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
    # Combat feel SFX (Adv Y C2). Kid-safe punch/kick percussion —
    # cartoony "whump" not violent meat-impact. No screams, no grunts,
    # no gore textures. Short and tight so they layer cleanly with the
    # hit-stop time-scale dip.
    "punch_thud":       "cartoon punch impact, soft padded thud, low-mid frequency whump, no metallic shimmer, no scream, kid-friendly cartoon style, 150ms",
    "kick_impact":      "cartoon kick impact, padded boot whump, slightly deeper than punch, soft low thud, no scream no gore, kid-friendly, 180ms",
    "swing_whoosh":     "fast cartoon arm swing whoosh through air, soft airy sweep, descending pitch, no metallic blade, kid-friendly, 120ms",
}

MUSIC_PROMPTS = {
    "landing_ambient":   "gentle warm playful kid game lobby music loop, ukulele and soft xylophone, 120 bpm, looping, 30 seconds, cheerful but calm",
    "adventure_island":  "cheerful pirate adventure island music, ukulele steel drum, tropical, kid friendly, looping, 30 seconds",
    "little_farm":       "cozy farm music, banjo and harmonica, warm sunny morning, kid friendly, looping, 30 seconds",
    "mushroom_forest":   "magical mushroom forest music, soft pizzicato strings, glockenspiel, ambient mystery, kid friendly, looping, 30 seconds",
    "celebration":       "victory celebration fanfare, brass and timpani, 8 seconds, triumphant",
    # Kid-safe drift phonk vibe — slow, hazy, no aggressive 808 distortion,
    # no vocals/shouting/horror. Acts as the new default lobby + create
    # mode loop (replaces landing_ambient when present).
    "drift_phonk":       "drift phonk Memphis trap instrumental, prominent rhythmic cowbell loop pattern (the signature phonk cowbell), deep slow 808 sub bass with subtle slide, lo-fi cassette tape saturation and vinyl crackle, slowed-and-reverb chopped-and-screwed pitched-down mood, slow tempo 75 bpm, hypnotic moody atmosphere, instrumental only NO vocals NO shouting NO screams NO sirens NO horror elements, kid-safe (age 7), looping seamlessly, 30 seconds",
    # Faster phonk for combat — still kid-safe, more energetic but
    # never harsh. Used by PlayShell when COMBAT mode active.
    "combat_phonk":      "drift phonk Memphis trap instrumental for action gameplay, signature phonk cowbell rhythm front-and-center, crisp 808 bass with sliding bends, lo-fi cassette texture, chopped-and-screwed vibe, mid tempo 105 bpm, confident focused energetic mood, instrumental only NO vocals NO shouting NO screams NO sirens NO horror elements, kid-safe (age 7), looping seamlessly, 30 seconds",
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
