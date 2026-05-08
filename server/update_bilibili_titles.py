#!/usr/bin/env python3
"""Refresh chapter titles in ~/listenkids/series/bilibili/<slug>/manifest.json
from Bilibili web-view API per-page metadata. Files on disk keep their original
names — only the manifest 'title' field changes."""
import json, os, sys, urllib.request

ROOT = os.path.expanduser("~/listenkids")
SERIES_DIR = os.path.join(ROOT, "series", "bilibili")
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15"

for slug in sorted(os.listdir(SERIES_DIR)):
    book_dir = os.path.join(SERIES_DIR, slug)
    manifest_path = os.path.join(book_dir, "manifest.json")
    if not os.path.isfile(manifest_path):
        continue
    mf = json.load(open(manifest_path))
    bvid = mf.get("bvid")
    if not bvid:
        print(f"[{slug}] no bvid, skip")
        continue

    api_url = f"https://api.bilibili.com/x/web-interface/view?bvid={bvid}"
    req = urllib.request.Request(api_url, headers={"User-Agent": UA})
    try:
        data = json.loads(urllib.request.urlopen(req, timeout=30).read())
    except Exception as e:
        print(f"[{slug}] api fail: {e}")
        continue

    pages = data.get("data", {}).get("pages", [])
    page_titles = {p["page"]: p["part"] for p in pages}

    updated = 0
    for ch in mf.get("chapters", []):
        pn = ch["partNumber"]
        if pn in page_titles:
            new_title = page_titles[pn].strip()
            if new_title and ch.get("title") != new_title:
                ch["title"] = new_title[:120]
                updated += 1

    if updated:
        json.dump(mf, open(manifest_path, "w"), ensure_ascii=False, indent=2)
    print(f"[{slug}] updated {updated}/{len(mf.get('chapters', []))} chapter titles")
