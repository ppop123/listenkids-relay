#!/usr/bin/env python3
"""Backfill transcripts for all mp3s under audio/ using mlx_whisper. Skip existing."""
import os, sys, subprocess, time, re

def buzzsprout_id(path):
    m = re.match(r'(\d+)-', os.path.basename(path))
    return int(m.group(1)) if m else 0

ROOT = os.path.expanduser("~/listenkids")
AUDIO_DIR = os.path.join(ROOT, "audio")
SERIES_DIR = os.path.join(ROOT, "series")
TRANSCRIPT_DIR = os.path.join(ROOT, "transcripts")


def all_audio():
    """Walk ~/listenkids and return every .mp3 under audio/, audio_storynory/, series/."""
    out = []
    for d in (AUDIO_DIR, os.path.join(ROOT, "audio_storynory")):
        if os.path.isdir(d):
            for f in os.listdir(d):
                if f.lower().endswith(".mp3"):
                    out.append(os.path.join(d, f))
    if os.path.isdir(SERIES_DIR):
        for root_dir, _dirs, files in os.walk(SERIES_DIR):
            for f in files:
                if f.lower().endswith(".mp3"):
                    out.append(os.path.join(root_dir, f))
    return out
WHISPER = "/Users/wangyan/fanyi-asr/.venv/bin/mlx_whisper"
MODEL = os.environ.get("LK_MODEL", "mlx-community/whisper-small.en-mlx")

os.makedirs(TRANSCRIPT_DIR, exist_ok=True)

mp3s = sorted(all_audio(), key=buzzsprout_id, reverse=True)
print(f"found {len(mp3s)} mp3s", flush=True)

todo = []
for mp3 in mp3s:
    base = os.path.splitext(os.path.basename(mp3))[0]
    j = os.path.join(TRANSCRIPT_DIR, base + ".json")
    if os.path.exists(j) and os.path.getsize(j) > 1000:
        continue
    todo.append(mp3)
print(f"to transcribe: {len(todo)} (using {MODEL})", flush=True)

env = os.environ.copy()
env["PATH"] = "/opt/homebrew/bin:" + env.get("PATH", "")

start_all = time.time()
for i, mp3 in enumerate(todo, 1):
    base = os.path.splitext(os.path.basename(mp3))[0]
    print(f"[{i}/{len(todo)}] {base}", flush=True)
    t0 = time.time()
    try:
        subprocess.run(
            [
                WHISPER,
                "--model", MODEL,
                "--output-dir", TRANSCRIPT_DIR,
                "--output-format", "json",
                "--temperature", "0",
                mp3,
            ],
            env=env, check=True, capture_output=True,
        )
        dt = time.time() - t0
        print(f"  done in {dt:.1f}s", flush=True)
    except subprocess.CalledProcessError as e:
        err = (e.stderr or b"").decode()[:300]
        print(f"  FAIL: {err}", flush=True)

print(f"backfill complete in {time.time() - start_all:.0f}s", flush=True)
