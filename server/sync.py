#!/usr/bin/env python3
"""Sync Practising English podcast to local storage; rewrite RSS for app consumption."""
import os, sys, re, urllib.request, urllib.parse
import xml.etree.ElementTree as ET

SOURCE = os.environ.get("LK_SOURCE", "https://feeds.buzzsprout.com/1783332.rss")
ROOT = os.environ.get("LK_ROOT", os.path.expanduser("~/listenkids"))
PUBLIC_BASE = os.environ.get("LK_PUBLIC", "http://192.168.50.9:18000")

AUDIO_DIR = os.path.join(ROOT, "audio")
FEED_OUT = os.path.join(ROOT, "feed.xml")
os.makedirs(AUDIO_DIR, exist_ok=True)

UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

def safe_name(url):
    n = urllib.parse.unquote(os.path.basename(urllib.parse.urlparse(url).path))
    return re.sub(r'[^A-Za-z0-9_.-]', '_', n) or 'episode.mp3'

def http_get(url, timeout=120):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
    return urllib.request.urlopen(req, timeout=timeout)

def download(url, dest):
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        return False
    print(f"  download {url}", file=sys.stderr, flush=True)
    tmp = dest + ".tmp"
    try:
        with http_get(url) as r, open(tmp, "wb") as f:
            while True:
                buf = r.read(65536)
                if not buf: break
                f.write(buf)
        os.rename(tmp, dest)
        return True
    except Exception as e:
        print(f"  fail: {e}", file=sys.stderr)
        if os.path.exists(tmp): os.remove(tmp)
        return False

print(f"fetch {SOURCE}", file=sys.stderr)
xml_bytes = http_get(SOURCE, timeout=30).read()

for prefix, uri in [
    ("itunes", "http://www.itunes.com/dtds/podcast-1.0.dtd"),
    ("content", "http://purl.org/rss/1.0/modules/content/"),
    ("atom", "http://www.w3.org/2005/Atom"),
    ("podcast", "https://podcastindex.org/namespace/1.0"),
    ("psc", "http://podlove.org/simple-chapters"),
]:
    ET.register_namespace(prefix, uri)

root = ET.fromstring(xml_bytes)
channel = root.find("channel")

download_tasks = []
for item in channel.findall("item"):
    enc = item.find("enclosure")
    if enc is None or "url" not in enc.attrib:
        continue
    src_url = enc.attrib["url"]
    fname = safe_name(src_url)
    download_tasks.append((src_url, os.path.join(AUDIO_DIR, fname)))
    enc.attrib["url"] = f"{PUBLIC_BASE}/audio/{fname}"

tmp_out = FEED_OUT + ".tmp"
with open(tmp_out, "wb") as f:
    f.write(b'<?xml version="1.0" encoding="UTF-8"?>\n')
    f.write(ET.tostring(root, encoding="utf-8"))
os.rename(tmp_out, FEED_OUT)
print(f"wrote {FEED_OUT} ({len(download_tasks)} entries)", file=sys.stderr)

new = 0
for src_url, dest in download_tasks:
    if download(src_url, dest):
        new += 1
print(f"downloaded {new} new files (total {len(download_tasks)} entries)", file=sys.stderr)
