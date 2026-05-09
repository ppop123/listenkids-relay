#!/usr/bin/env python3
"""Mirror Storynory RSS to ~/listenkids/audio_storynory/ + emit storynory.json."""
import os, sys, re, urllib.request, urllib.parse, json, time
import xml.etree.ElementTree as ET

ROOT = os.path.expanduser("~/listenkids")
SOURCE = "https://www.storynory.com/feeds/stories/"
PUBLIC_BASE = os.environ.get("LK_PUBLIC", "http://192.168.50.9:18000")
AUDIO_DIR = os.path.join(ROOT, "audio_storynory")
META_FILE = os.path.join(ROOT, "storynory.json")
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
ITUNES = {"itunes": "http://www.itunes.com/dtds/podcast-1.0.dtd"}

os.makedirs(AUDIO_DIR, exist_ok=True)


def safe_name(url, title):
    p = urllib.parse.urlparse(url)
    base = urllib.parse.unquote(os.path.basename(p.path))
    base = os.path.splitext(base)[0]
    if not base or len(base) < 3:
        base = re.sub(r"[^A-Za-z0-9]+", "-", title)[:50].strip("-").lower()
    base = re.sub(r"[^A-Za-z0-9_.-]", "_", base)
    return f"{base}.mp3"


def http_get(url, timeout=120):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
    return urllib.request.urlopen(req, timeout=timeout)


def download(url, dest):
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        return False
    print(f"  download {url}", file=sys.stderr, flush=True)
    tmp = dest + ".tmp"
    try:
        with http_get(url, 180) as r, open(tmp, "wb") as f:
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


def parse_duration(text):
    if not text: return None
    text = text.strip()
    try:
        if ":" in text:
            parts = [int(x) for x in text.split(":")]
            return sum(p * 60**i for i, p in enumerate(reversed(parts)))
        return int(text)
    except (ValueError, AttributeError):
        return None


print(f"fetch {SOURCE}", file=sys.stderr)
data = http_get(SOURCE, timeout=30).read()
channel = ET.fromstring(data).find("channel")

episodes = []
new = 0
for item in channel.findall("item"):
    enc = item.find("enclosure")
    if enc is None: continue
    url = enc.attrib.get("url", "")
    if not url: continue
    title = (item.find("title").text or "Untitled").strip()
    fname = safe_name(url, title)
    dest = os.path.join(AUDIO_DIR, fname)
    if download(url, dest):
        new += 1
    pub = item.find("pubDate")
    pub_text = pub.text if pub is not None else None
    guid_el = item.find("guid")
    guid = guid_el.text if guid_el is not None else url
    desc_el = item.find("description")
    if desc_el is None:
        desc_el = item.find("itunes:summary", ITUNES)
    desc = desc_el.text if desc_el is not None else None
    dur_el = item.find("itunes:duration", ITUNES)
    dur = parse_duration(dur_el.text) if dur_el is not None else None
    episodes.append({
        "id": f"storynory-{guid}",
        "sourceID": "storynory",
        "title": title,
        "rawTitle": title,
        "summary": (desc[:500] if desc else None),
        "audioURL": f"{PUBLIC_BASE}/audio_storynory/{urllib.parse.quote(fname)}",
        "publishedAt": pub_text,
        "durationSeconds": dur,
    })

print(f"processed {len(episodes)} episodes, downloaded {new} new", file=sys.stderr)

tmp_out = META_FILE + ".tmp"
with open(tmp_out, "w", encoding="utf-8") as f:
    json.dump({"sourceID": "storynory", "title": "Storynory", "episodes": episodes}, f, ensure_ascii=False, indent=2)
os.rename(tmp_out, META_FILE)
print(f"wrote {META_FILE}", file=sys.stderr)
