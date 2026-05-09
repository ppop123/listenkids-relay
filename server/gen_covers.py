#!/usr/bin/env python3
"""Generate cover art for series missing one.

Reads the live manifest from the relay, picks every series whose `cover` is null,
calls doubao-seedream-5 to render a unified hand-drawn cover for it, and saves the
result to `lk_covers/<sourceID>/<slug>/cover.png`. After running, rsync the output
into the relay's `~/listenkids/series/` and re-run `organize.py` to pick up.

Usage:
    VOLCANO_API_KEY=... python3 gen_covers.py
"""
import httpx
import json
import os
import re
import sys
import time

API_URL = "https://ark.cn-beijing.volces.com/api/v3/images/generations"
MODEL = "doubao-seedream-5-0-260128"
SIZE = "2048x2048"  # API requires >= 1920x1920 for square
MANIFEST_URL = os.environ.get(
    "LK_MANIFEST_URL",
    "http://192.168.50.9:18000/manifest.json",
)
OUT_DIR = os.environ.get("LK_COVER_OUT", "/tmp/lk_covers")

API_KEY = os.environ.get("VOLCANO_API_KEY")
if not API_KEY:
    sys.exit("set VOLCANO_API_KEY env var (Volcano Engine doubao-seedream key)")

os.makedirs(OUT_DIR, exist_ok=True)


def clean_title(t):
    t = re.sub(r"\s*\(.*?\)\s*", " ", t)
    t = re.sub(r"\s+(read by|BBC|abridged|Unabridged|Tape|VBR.*|dramatisation).*$", " ", t, flags=re.IGNORECASE)
    t = re.sub(r"\s+&\s+Dirty Beasts.*$", "", t)
    return re.sub(r"\s+", " ", t).strip()


def make_prompt(series):
    title = clean_title(series["title"])
    author = series.get("author")
    by = f' by {author}' if author else ''
    return (
        f'Square cover illustration for the audiobook "{title}"{by}. '
        'Hand-drawn storybook style, gentle watercolor wash with confident pen lines, '
        'soft warm palette of cream, coral, sky blue, and muted greens. '
        'Centered evocative scene capturing the heart of the story (an iconic object, '
        'character, or landscape). '
        'CRITICAL: the artwork FILLS the entire square edge-to-edge — no padding, '
        'no white border, no rounded inner card; the background extends to all edges. '
        'No text, no logo, no watermarks, no Chinese characters anywhere.'
    )


def main():
    manifest = httpx.get(MANIFEST_URL, timeout=30).json()
    todo = [s for s in manifest["series"] if not s.get("cover")]
    print(f"to generate: {len(todo)}", flush=True)

    for i, series in enumerate(todo, 1):
        slug = series["id"].split("/", 1)[1]
        out_dir = os.path.join(OUT_DIR, series["sourceID"], slug)
        os.makedirs(out_dir, exist_ok=True)
        out_path = os.path.join(out_dir, "cover.png")
        if os.path.exists(out_path) and os.path.getsize(out_path) > 5_000:
            print(f"[{i}/{len(todo)}] skip (have): {series['title'][:55]}", flush=True)
            continue

        print(f"[{i}/{len(todo)}] generating: {series['title'][:55]}", flush=True)
        t0 = time.time()
        try:
            resp = httpx.post(
                API_URL,
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {API_KEY}",
                },
                json={
                    "model": MODEL,
                    "prompt": make_prompt(series),
                    "size": SIZE,
                    "watermark": False,
                    "response_format": "url",
                },
                timeout=180,
            ).json()
        except Exception as exc:
            print(f"  request failed: {exc}", flush=True)
            continue

        items = resp.get("data") or []
        if not items:
            print(f"  no image returned: {resp.get('error')}", flush=True)
            continue
        try:
            img = httpx.get(items[0]["url"], timeout=60).content
        except Exception as exc:
            print(f"  download failed: {exc}", flush=True)
            continue
        with open(out_path, "wb") as f:
            f.write(img)
        print(f"  ok in {time.time() - t0:.1f}s ({len(img)} bytes)", flush=True)


if __name__ == "__main__":
    main()
