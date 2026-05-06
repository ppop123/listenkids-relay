#!/usr/bin/env python3
"""Mirror selected Bilibili series into ~/listenkids/series/bilibili/<slug>/.
Each BV is treated as one series; per-P pages become chapters. Audio-only
extraction (mp3) via yt-dlp + ffmpeg. Per-series manifest.json written for
organize.py to pick up generically."""
import json, os, re, subprocess, sys

ROOT = os.path.expanduser("~/listenkids")
SERIES_DIR = os.path.join(ROOT, "series", "bilibili")
PUBLIC_BASE = os.environ.get("LK_PUBLIC", "http://192.168.50.8:18000")

# (bvid, slug, title, level, author)
BILIBILI_LIST = [
    ("BV1sV4y1L7m9", "charlottes-web", "Charlotte's Web", "B1", "E. B. White"),
    ("BV1Ju4y1o7Jq", "harry-potter-stephen-fry", "Harry Potter (Stephen Fry / Jim Dale)", "B2", "J. K. Rowling"),
    ("BV1gx411B7kJ", "magic-school-bus", "The Magic School Bus", "B1", "Joanna Cole"),
    ("BV1L2uKzUEHR", "horrid-henry", "Horrid Henry", "B1", "Francesca Simon"),
    ("BV1rZBsBPEN5", "worst-witch", "The Worst Witch", "B1", "Jill Murphy"),
]

os.makedirs(SERIES_DIR, exist_ok=True)


def slugify(s):
    s = s.lower()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-")[:80]


def download_bv(bvid, slug, title, level, author):
    book_dir = os.path.join(SERIES_DIR, slug)
    os.makedirs(book_dir, exist_ok=True)
    url = f"https://www.bilibili.com/video/{bvid}"
    print(f"\n=== [{slug}] downloading {bvid} ===", flush=True)

    # Output template: <slug>-<padded index>-<sanitized title>.<ext>
    output_tmpl = f"{slug}-%(playlist_index)03d-%(title).80B.%(ext)s"
    cmd = [
        "yt-dlp",
        "-x",                          # extract audio only
        "--audio-format", "mp3",
        "--audio-quality", "5",
        "--paths", book_dir,
        "--output", output_tmpl,
        "--restrict-filenames",        # ascii-only filenames
        "--ignore-errors",
        "--no-warnings",
        "--continue",                  # resume partially-downloaded files
        "--yes-playlist",
        url,
    ]
    subprocess.run(cmd, check=False)

    # Build chapter list from final mp3 files in dir
    files = sorted(f for f in os.listdir(book_dir) if f.lower().endswith(".mp3"))
    chapters = []
    for i, fname in enumerate(files, 1):
        m = re.match(rf"{re.escape(slug)}-(\d+)-(.+)\.mp3$", fname)
        if m:
            part_num = int(m.group(1))
            chap_title = m.group(2).replace("_", " ")[:80]
        else:
            part_num = i
            chap_title = os.path.splitext(fname)[0]
        chapters.append({
            "partNumber": part_num,
            "title": chap_title,
            "filename": fname,
        })
    chapters.sort(key=lambda c: c["partNumber"])

    manifest = {
        "id": f"bilibili/{slug}",
        "sourceID": "bilibili",
        "title": title,
        "author": author,
        "level": level,
        "bvid": bvid,
        "chapters": chapters,
    }
    with open(os.path.join(book_dir, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    print(f"=== [{slug}] {len(chapters)} chapters ===", flush=True)


for bv, slug, title, level, author in BILIBILI_LIST:
    try:
        download_bv(bv, slug, title, level, author)
    except Exception as exc:
        print(f"!! {slug}: {exc}", file=sys.stderr, flush=True)

print("\nall done", flush=True)
