#!/usr/bin/env python3
"""Build a unified ~/listenkids/manifest.json describing all collections + standalone episodes."""

import os, sys, json, re, glob, subprocess, urllib.parse
import xml.etree.ElementTree as ET

FFPROBE = "/opt/homebrew/bin/ffprobe"
DURATION_CACHE_FILE = os.path.expanduser("~/listenkids/.duration_cache.json")
_duration_cache = {}


def _load_duration_cache():
    global _duration_cache
    try:
        with open(DURATION_CACHE_FILE, "r") as f:
            _duration_cache = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        _duration_cache = {}


def _save_duration_cache():
    try:
        with open(DURATION_CACHE_FILE, "w") as f:
            json.dump(_duration_cache, f)
    except OSError:
        pass


def probe_duration(path):
    """Return audio duration in seconds, cached by (path, mtime, size)."""
    try:
        st = os.stat(path)
        key = f"{path}|{int(st.st_mtime)}|{st.st_size}"
    except OSError:
        return None
    if key in _duration_cache:
        return _duration_cache[key]
    try:
        result = subprocess.run(
            [
                FFPROBE, "-v", "error",
                "-show_entries", "format=duration",
                "-of", "default=noprint_wrappers=1:nokey=1",
                path,
            ],
            capture_output=True, text=True, timeout=15,
        )
        secs = int(float(result.stdout.strip()))
        _duration_cache[key] = secs
        return secs
    except (subprocess.SubprocessError, ValueError):
        return None


def url_path(*parts):
    return "/".join(urllib.parse.quote(p, safe="") for p in parts)

ROOT = os.path.expanduser("~/listenkids")
PUBLIC_BASE = os.environ.get("LK_PUBLIC", "http://192.168.50.8:18000")
FEED = os.path.join(ROOT, "feed.xml")
SERIES_DIR = os.path.join(ROOT, "series")
MANIFEST = os.path.join(ROOT, "manifest.json")

ITUNES_NS = {"itunes": "http://www.itunes.com/dtds/podcast-1.0.dtd"}


def slugify(s):
    s = s.lower().strip()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-")


# --- Practising English title parsing ---

def parse_pe_title(title):
    """Returns (clean_title, episode_num, series_title, part_number, level)."""
    raw = title
    ep_num = None
    m = re.match(r"^(\d+)\.\s*", title)
    if m:
        ep_num = int(m.group(1))
        title = title[m.end():]

    level = None
    for pat in [
        r"\s*\(?\s*([ABC]\d)\s+(?:and\s+[ABC]\d\s+)?[Ss]tor[yies]+\s*\)?\s*$",
        r"\s*\(?\s*([ABC]\d)\s+[Ss]tory\s*\)?\s*$",
        r"\s+\b([ABC]\d)\s+story\s*$",
    ]:
        m = re.search(pat, title)
        if m:
            level = m.group(1)
            title = title[:m.start()].strip()
            break

    title = re.sub(r"\s*\([^)]*\)\s*$", "", title).strip()

    series, part = None, None
    for pat in [
        r"^(.+?)\s*[-—]\s*chapter\s+(\d+)",
        r"^(.+?)\s+chapter\s+(\d+)",
        r"^(.+?)\s*[-—]\s*part\s+(\d+)",
        r"^(.+?)\s+[Pp]art\s+(\d+)",
    ]:
        m = re.match(pat, title, re.IGNORECASE)
        if m:
            series = m.group(1).strip()
            part = int(m.group(2))
            break

    return title, ep_num, series, part, level


def collect_pe():
    if not os.path.exists(FEED):
        return []
    tree = ET.parse(FEED)
    channel = tree.getroot().find("channel")
    out = []
    for item in channel.findall("item"):
        t_el = item.find("itunes:title", ITUNES_NS) or item.find("title")
        title = (t_el.text or "").strip() if t_el is not None else ""
        enc = item.find("enclosure")
        audio_url = enc.attrib.get("url") if enc is not None else None
        if not audio_url:
            continue
        link = item.find("link")
        page_url = (link.text or None) if link is not None else None
        pub = item.find("pubDate")
        pub_date = (pub.text or None) if pub is not None else None
        guid_el = item.find("guid")
        guid = (guid_el.text or audio_url) if guid_el is not None else audio_url
        dur_el = item.find("itunes:duration", ITUNES_NS)
        duration = None
        if dur_el is not None:
            try:
                duration = int(dur_el.text)
            except (ValueError, TypeError):
                pass

        clean_title, ep_num, series, part, level = parse_pe_title(title)
        audio_basename = os.path.splitext(os.path.basename(audio_url.split("?")[0]))[0]
        transcript_url = f"{PUBLIC_BASE}/transcripts/{audio_basename}.json"

        out.append({
            "id": guid,
            "sourceID": "practising-english",
            "rawTitle": title,
            "title": clean_title or title,
            "episodeNumber": ep_num,
            "audioURL": audio_url,
            "pageURL": page_url,
            "transcriptURL": transcript_url,
            "publishedAt": pub_date,
            "durationSeconds": duration,
            "level": level,
            "seriesTitle": series,
            "partNumber": part,
        })
    return out


# --- Roald Dahl ---

def classify_episode(title):
    """Classify a PE standalone episode for home-screen relevance.
    Story signal wins outright (even if a grammar word also appears).
    Default-to-story: anything not explicitly tutorial counts as story."""
    t = title.lower()
    # Strong story signal — narrative content always wins
    if any(s in t for s in ("story", "stories", " tale", "tales of", " chapter ")):
        return "story"
    lesson_keywords = (
        "linking words", "phrasal verb", "infinitive", "preposition",
        "modal verb", "tenses", "grammar", "vocabulary", "passive",
        "conditional", "reported speech", "subjunctive",
        "pronunciation", "intonation", "stress in",
        "used to", "would rather", "going to'",
        "comparative", "superlative", "relative clause", "gerund",
        "essential b2", "b1 linking", "b2 linking",
        "essential vocabulary",
    )
    if any(k in t for k in lesson_keywords):
        return "lesson"
    exam_keywords = (
        "exam", "ielts", "fce", "cambridge", "preliminary",
        "speaking part", "writing part", "use of english", "test ",
        "writing the article", "writing the essay", "writing exam",
    )
    if any(k in t for k in exam_keywords):
        return "exam"
    return "story"


DAHL_LEVELS = {
    "billy and the minpins": "B1",
    "charlie and the chocolate factory": "B1",
    "fantastic mr fox": "B1",
    "george": "B1",
    "james and the giant peach": "B1",
    "matilda": "B1",
    "esio trot": "B1",
    "the bfg": "B1",
    "the enormous crocodile": "B1",
    "the giraffe and the pelly": "B1",
    "the magic finger": "B1",
    "the twits": "B1",
    "the witches": "B1",
    "boy": "B2",
    "going solo": "B2",
    "tales of the unexpected": "B2",
    "switch bitch": "B2",
    "over to you": "B2",
    "someone like you": "B2",
    "revolting rhymes": "B2",
    "charlie and the great glass": "B2",
    "danny the champion": "B2",
    "collins theatre": "B2",
}


def dahl_level(title_lower):
    for key, lvl in DAHL_LEVELS.items():
        if key in title_lower:
            return lvl
    return "B1"


def collect_bilibili():
    base = os.path.join(SERIES_DIR, "bilibili")
    if not os.path.isdir(base):
        return []
    out = []
    for slug in sorted(os.listdir(base)):
        book_dir = os.path.join(base, slug)
        manifest_path = os.path.join(book_dir, "manifest.json")
        if not os.path.isfile(manifest_path):
            continue
        try:
            mf = json.load(open(manifest_path, "r", encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            continue
        parts = []
        for ch in mf.get("chapters", []):
            fname = ch.get("filename")
            if not fname:
                continue
            local = os.path.join(book_dir, fname)
            if not os.path.exists(local):
                continue
            parts.append({
                "id": f"bilibili/{slug}/{ch['partNumber']:03d}",
                "partNumber": ch["partNumber"],
                "title": ch.get("title") or f"Episode {ch['partNumber']}",
                "audioURL": f"{PUBLIC_BASE}/{url_path('series', 'bilibili', slug, fname)}",
                "durationSeconds": probe_duration(local),
            })
        if not parts:
            continue
        out.append({
            "id": f"bilibili/{slug}",
            "sourceID": "bilibili",
            "title": mf.get("title", slug),
            "author": mf.get("author"),
            "level": mf.get("level"),
            "cover": None,
            "parts": parts,
        })
    return out


def collect_librivox():
    base = os.path.join(SERIES_DIR, "librivox")
    if not os.path.isdir(base):
        return []
    out = []
    for slug in sorted(os.listdir(base)):
        book_dir = os.path.join(base, slug)
        manifest_path = os.path.join(book_dir, "manifest.json")
        if not os.path.isfile(manifest_path):
            continue
        try:
            mf = json.load(open(manifest_path, "r", encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            continue
        parts = []
        for ch in mf.get("chapters", []):
            fname = ch.get("filename")
            if not fname: continue
            local = os.path.join(book_dir, fname)
            if not os.path.exists(local): continue
            parts.append({
                "id": f"librivox/{slug}/{ch['partNumber']:02d}",
                "partNumber": ch["partNumber"],
                "title": ch.get("title") or f"Chapter {ch['partNumber']}",
                "audioURL": f"{PUBLIC_BASE}/{url_path('series', 'librivox', slug, fname)}",
                "durationSeconds": probe_duration(local),
            })
        if not parts:
            continue
        out.append({
            "id": f"librivox/{slug}",
            "sourceID": "librivox",
            "title": mf.get("title", slug),
            "author": mf.get("author"),
            "level": mf.get("level"),
            "cover": None,
            "parts": parts,
        })
    return out


def collect_storynory_episodes():
    meta_path = os.path.join(ROOT, "storynory.json")
    if not os.path.isfile(meta_path):
        return []
    try:
        m = json.load(open(meta_path, "r", encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return []
    out = []
    for ep in m.get("episodes", []):
        out.append({
            "id": ep["id"],
            "sourceID": "storynory",
            "title": ep["title"],
            "rawTitle": ep.get("rawTitle", ep["title"]),
            "episodeNumber": None,
            "audioURL": ep["audioURL"],
            "pageURL": None,
            "transcriptURL": None,
            "publishedAt": ep.get("publishedAt"),
            "durationSeconds": ep.get("durationSeconds"),
            "level": "B1",  # Storynory is generally B1-B2
            "kind": "story",
        })
    return out


def collect_dahl():
    base = os.path.join(SERIES_DIR, "roald-dahl")
    if not os.path.isdir(base):
        return []
    series = []
    for folder in sorted(os.listdir(base)):
        folder_path = os.path.join(base, folder)
        if not os.path.isdir(folder_path):
            continue
        clean_name = re.sub(r"^Roald Dahl\s*-\s*", "", folder)
        mp3s = sorted(
            os.path.join(folder_path, f)
            for f in os.listdir(folder_path)
            if f.lower().endswith(".mp3")
        )
        if not mp3s:
            continue
        slug = slugify(clean_name)
        cover_url = None
        files = os.listdir(folder_path)
        for ext in (".jpg", ".jpeg", ".png"):
            covers = sorted(f for f in files if f.lower().endswith(ext))
            if covers:
                cover_url = f"{PUBLIC_BASE}/{url_path('series', 'roald-dahl', folder, covers[0])}"
                break
        # Fallback to generated cover stored under series/roald-dahl/<slug>/
        if not cover_url:
            gen_dir = os.path.join(base, slug)
            if os.path.isdir(gen_dir):
                for f in sorted(os.listdir(gen_dir)):
                    if f.lower().endswith((".jpg", ".jpeg", ".png")):
                        cover_url = f"{PUBLIC_BASE}/{url_path('series', 'roald-dahl', slug, f)}"
                        break

        parts = []
        for i, mp3 in enumerate(mp3s, 1):
            mp3_name = os.path.basename(mp3)
            chapter_title = re.sub(r"^\d+\s*[-.]?\s*", "", mp3_name)
            chapter_title = os.path.splitext(chapter_title)[0]
            parts.append({
                "id": f"roald-dahl/{slug}/{i:02d}",
                "partNumber": i,
                "title": chapter_title,
                "audioURL": f"{PUBLIC_BASE}/{url_path('series', 'roald-dahl', folder, mp3_name)}",
                "durationSeconds": probe_duration(mp3),
            })

        series.append({
            "id": f"roald-dahl/{slug}",
            "sourceID": "roald-dahl",
            "title": clean_name,
            "author": "Roald Dahl",
            "level": dahl_level(clean_name.lower()),
            "cover": cover_url,
            "parts": parts,
        })
    return series


def main():
    _load_duration_cache()
    pe_eps = collect_pe()
    pe_series_map = {}
    pe_standalone = []
    for ep in pe_eps:
        if ep["seriesTitle"]:
            slug = slugify(ep["seriesTitle"])
            sid = f"practising-english/{slug}"
            if sid not in pe_series_map:
                pe_series_map[sid] = {
                    "id": sid,
                    "sourceID": "practising-english",
                    "title": ep["seriesTitle"],
                    "level": ep["level"],
                    "cover": None,
                    "parts": [],
                }
            pe_series_map[sid]["parts"].append({
                "id": ep["id"],
                "partNumber": ep["partNumber"],
                "title": f"Part {ep['partNumber']}" if ep["partNumber"] else ep["title"],
                "rawTitle": ep["rawTitle"],
                "audioURL": ep["audioURL"],
                "pageURL": ep["pageURL"],
                "transcriptURL": ep["transcriptURL"],
                "publishedAt": ep["publishedAt"],
                "durationSeconds": ep["durationSeconds"],
                "level": ep["level"],
            })
        else:
            pe_standalone.append({
                "id": ep["id"],
                "sourceID": "practising-english",
                "title": ep["title"],
                "rawTitle": ep["rawTitle"],
                "episodeNumber": ep["episodeNumber"],
                "audioURL": ep["audioURL"],
                "pageURL": ep["pageURL"],
                "transcriptURL": ep["transcriptURL"],
                "publishedAt": ep["publishedAt"],
                "durationSeconds": ep["durationSeconds"],
                "level": ep["level"],
                "kind": classify_episode(ep["rawTitle"]),
            })
    for s in pe_series_map.values():
        s["parts"].sort(key=lambda p: (p["partNumber"] or 0))
    # Attach generated cover for PE series (stored under series/practising-english/<slug>/)
    for sid, s in pe_series_map.items():
        slug = sid.split("/", 1)[1]
        gen_dir = os.path.join(SERIES_DIR, "practising-english", slug)
        if os.path.isdir(gen_dir):
            for f in sorted(os.listdir(gen_dir)):
                if f.lower().endswith((".jpg", ".jpeg", ".png")):
                    s["cover"] = f"{PUBLIC_BASE}/{url_path('series', 'practising-english', slug, f)}"
                    break

    dahl_series = collect_dahl()
    librivox_series = collect_librivox()
    bilibili_series = collect_bilibili()
    storynory_eps = collect_storynory_episodes()

    manifest = {
        "version": 1,
        "publicBase": PUBLIC_BASE,
        "series": dahl_series + bilibili_series + librivox_series + list(pe_series_map.values()),
        "episodes": pe_standalone + storynory_eps,
    }

    tmp = MANIFEST + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    os.rename(tmp, MANIFEST)

    _save_duration_cache()
    print(
        f"wrote {MANIFEST}: "
        f"{len(manifest['series'])} series ({len(dahl_series)} dahl + {len(bilibili_series)} bilibili + {len(librivox_series)} librivox + {len(pe_series_map)} pe), "
        f"{len(manifest['episodes'])} standalone ({len(pe_standalone)} pe + {len(storynory_eps)} storynory)",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
