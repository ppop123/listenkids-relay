#!/usr/bin/env python3
"""Slowly upgrade every transcript to a heavier Whisper model
(default large-v3) without breaking the live ones.

Each file is transcribed into a side directory and only `os.replace`d
into the canonical location once mlx-whisper has produced a complete
JSON, so the iOS app never sees a half-written file. A progress log
makes the run resumable across reboots."""
import os, subprocess, sys, time

ROOT = os.path.expanduser("~/listenkids")
AUDIO_DIR = os.path.join(ROOT, "audio")
STORYNORY_DIR = os.path.join(ROOT, "audio_storynory")
SERIES_DIR = os.path.join(ROOT, "series")
TRANSCRIPT_DIR = os.path.join(ROOT, "transcripts")
TMP_DIR = os.path.join(TRANSCRIPT_DIR, ".tmp_upgrade")
PROGRESS_FILE = os.path.join(ROOT, "transcripts_upgraded.log")
WHISPER = "/Users/wangyan/fanyi-asr/.venv/bin/mlx_whisper"
MODEL = os.environ.get("LK_UPGRADE_MODEL", "mlx-community/whisper-large-v3-mlx")

os.makedirs(TMP_DIR, exist_ok=True)


def all_audio():
    out = []
    for d in (AUDIO_DIR, STORYNORY_DIR):
        if os.path.isdir(d):
            for f in os.listdir(d):
                if f.lower().endswith(".mp3"):
                    out.append(os.path.join(d, f))
    if os.path.isdir(SERIES_DIR):
        for root_dir, _, files in os.walk(SERIES_DIR):
            for f in files:
                if f.lower().endswith(".mp3"):
                    out.append(os.path.join(root_dir, f))
    return out


def already_upgraded():
    if not os.path.exists(PROGRESS_FILE):
        return set()
    with open(PROGRESS_FILE, "r") as f:
        return set(line.strip() for line in f if line.strip())


def mark_upgraded(basename):
    with open(PROGRESS_FILE, "a") as f:
        f.write(basename + "\n")


def upgrade_one(mp3_path):
    base = os.path.splitext(os.path.basename(mp3_path))[0]
    final_json = os.path.join(TRANSCRIPT_DIR, base + ".json")
    tmp_json = os.path.join(TMP_DIR, base + ".json")
    if os.path.exists(tmp_json):
        os.remove(tmp_json)

    env = os.environ.copy()
    env["PATH"] = "/opt/homebrew/bin:" + env.get("PATH", "")
    t0 = time.time()
    try:
        subprocess.run(
            [
                WHISPER,
                "--model", MODEL,
                "--output-dir", TMP_DIR,
                "--output-format", "json",
                "--temperature", "0",
                mp3_path,
            ],
            env=env, check=True, capture_output=True,
        )
    except subprocess.CalledProcessError as e:
        return f"FAIL: {(e.stderr or b'')[-200:].decode(errors='replace')}"

    if not os.path.exists(tmp_json):
        return "FAIL: no json output"
    if os.path.getsize(tmp_json) < 100:
        os.remove(tmp_json)
        return "FAIL: empty output"
    os.replace(tmp_json, final_json)
    return f"OK in {time.time() - t0:.1f}s"


def main():
    mp3s = sorted(all_audio())
    done = already_upgraded()
    todo = [m for m in mp3s if os.path.splitext(os.path.basename(m))[0] not in done]
    print(f"upgrade model: {MODEL}", flush=True)
    print(
        f"total mp3s: {len(mp3s)}, already upgraded: {len(done)}, todo: {len(todo)}",
        flush=True,
    )

    for i, mp3 in enumerate(todo, 1):
        base = os.path.splitext(os.path.basename(mp3))[0]
        print(f"[{i}/{len(todo)}] {base[:80]}", flush=True)
        result = upgrade_one(mp3)
        print(f"  -> {result}", flush=True)
        if result.startswith("OK"):
            mark_upgraded(base)

    print("upgrade run complete", flush=True)


if __name__ == "__main__":
    main()
