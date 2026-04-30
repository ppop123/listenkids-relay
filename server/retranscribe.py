#!/usr/bin/env python3
"""Daemon: watch ~/listenkids/bad_transcripts.log, re-transcribe reported episodes with medium.en."""
import os, sys, json, time, subprocess, urllib.parse

ROOT = os.path.expanduser("~/listenkids")
REPORTS = os.path.join(ROOT, "bad_transcripts.log")
PROCESSED = os.path.join(ROOT, "bad_transcripts_done.log")
TRANSCRIPT_DIR = os.path.join(ROOT, "transcripts")
WHISPER = "/Users/wangyan/fanyi-asr/.venv/bin/mlx_whisper"
MODEL = os.environ.get("LK_REPAIR_MODEL", "mlx-community/whisper-medium.en-mlx")
POLL_SECONDS = 30


def url_to_local_path(url):
    p = urllib.parse.urlparse(url)
    decoded = urllib.parse.unquote(p.path).lstrip("/")
    return os.path.join(ROOT, decoded)


def basename_from_audio_url(url):
    p = urllib.parse.urlparse(url)
    name = urllib.parse.unquote(os.path.basename(p.path))
    return os.path.splitext(name)[0]


def retranscribe(audio_url):
    local_mp3 = url_to_local_path(audio_url)
    if not os.path.exists(local_mp3):
        return f"NOT FOUND: {local_mp3}"
    base = basename_from_audio_url(audio_url)
    json_out = os.path.join(TRANSCRIPT_DIR, base + ".json")
    if os.path.exists(json_out):
        try:
            os.remove(json_out)
        except OSError as e:
            return f"could not remove old transcript: {e}"
    env = os.environ.copy()
    env["PATH"] = "/opt/homebrew/bin:" + env.get("PATH", "")
    t0 = time.time()
    try:
        subprocess.run(
            [
                WHISPER,
                "--model", MODEL,
                "--output-dir", TRANSCRIPT_DIR,
                "--output-format", "json",
                "--temperature", "0",
                local_mp3,
            ],
            env=env, check=True, capture_output=True,
        )
        return f"OK in {time.time() - t0:.1f}s"
    except subprocess.CalledProcessError as e:
        return f"FAIL: {(e.stderr or b'').decode()[:200]}"


def already_processed():
    seen = set()
    if os.path.exists(PROCESSED):
        with open(PROCESSED, "r", encoding="utf-8") as f:
            for line in f:
                try:
                    rec = json.loads(line)
                    url = rec.get("audioURL")
                    if url:
                        seen.add(url)
                except json.JSONDecodeError:
                    pass
    return seen


def main():
    print(f"retranscribe daemon: model={MODEL}", flush=True)
    seen = already_processed()
    print(f"already processed: {len(seen)}", flush=True)

    while True:
        if os.path.exists(REPORTS):
            with open(REPORTS, "r", encoding="utf-8") as f:
                lines = f.readlines()
            for line in lines:
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                url = (rec.get("audioURL") or "").strip()
                if not url or url in seen:
                    continue
                print(f"[repair] {url}", flush=True)
                result = retranscribe(url)
                print(f"  -> {result}", flush=True)
                rec["result"] = result
                rec["processedAt"] = time.strftime("%Y-%m-%dT%H:%M:%S")
                rec["model"] = MODEL
                with open(PROCESSED, "a", encoding="utf-8") as g:
                    g.write(json.dumps(rec, ensure_ascii=False) + "\n")
                seen.add(url)
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
