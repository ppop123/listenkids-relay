#!/usr/bin/env python3
"""Mirror selected LibriVox books into ~/listenkids/series/librivox/<slug>/.
Each book has its own manifest.json (title, author, level, chapters), which
organize.py picks up generically."""
import os, sys, re, urllib.request, urllib.parse, json, time
import xml.etree.ElementTree as ET

ROOT = os.path.expanduser("~/listenkids")
SERIES_DIR = os.path.join(ROOT, "series", "librivox")
PUBLIC_BASE = os.environ.get("LK_PUBLIC", "http://192.168.50.9:18000")
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

# (title query, level). Picks first matching book via API search.
BOOK_LIST = [
    ("Wind in the Willows", "B2"),
    ("Anne of Green Gables", "B2"),
    ("The Secret Garden", "B2"),
    ("Alice's Adventures in Wonderland", "B2"),
    ("The Wonderful Wizard of Oz", "B1"),
    ("Black Beauty", "B1"),
    ("A Little Princess", "B2"),
    ("Five Children and It", "B1"),
    ("Heidi", "B1"),
    ("Peter Pan", "B2"),
]

os.makedirs(SERIES_DIR, exist_ok=True)


def slugify(s):
    s = s.lower()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-")[:80]


def http_get(url, timeout=120):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
    return urllib.request.urlopen(req, timeout=timeout)


def find_book(title):
    queries = [title]
    no_article = re.sub(r"^(The|A|An)\s+", "", title, flags=re.IGNORECASE)
    if no_article != title:
        queries.append(no_article)
    for q in queries:
        url = f"https://librivox.org/api/feed/audiobooks/?title={urllib.parse.quote(q)}&format=json&limit=10"
        try:
            data = json.loads(http_get(url, 30).read().decode("utf-8"))
        except Exception as e:
            print(f"  api fail ({q!r}): {e}", file=sys.stderr)
            continue
        books = data.get("books", [])
        if not books:
            continue
        for b in books:
            if "collab" not in (b.get("url_zip_file") or ""):
                return b
        return books[0]
    return None


def fetch_chapters(rss_url):
    data = http_get(rss_url, 30).read()
    channel = ET.fromstring(data).find("channel")
    chapters = []
    for item in channel.findall("item"):
        title_el = item.find("title")
        title = title_el.text.strip() if title_el is not None and title_el.text else "Chapter"
        enc = item.find("enclosure")
        url = enc.attrib.get("url") if enc is not None else None
        if not url: continue
        chapters.append({"title": title, "url": url})
    return chapters


def download(url, dest):
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        return False
    print(f"    download {url[:80]}...", file=sys.stderr, flush=True)
    tmp = dest + ".tmp"
    try:
        with http_get(url, 600) as r, open(tmp, "wb") as f:
            while True:
                buf = r.read(65536)
                if not buf: break
                f.write(buf)
        os.rename(tmp, dest)
        return True
    except Exception as e:
        print(f"    fail: {e}", file=sys.stderr)
        if os.path.exists(tmp): os.remove(tmp)
        return False


for query, level in BOOK_LIST:
    print(f"\n== {query} ==", file=sys.stderr)
    book = find_book(query)
    if not book:
        print(f"  not found", file=sys.stderr)
        continue
    book_id = book["id"]
    title = book["title"]
    book_slug = slugify(title)
    book_dir = os.path.join(SERIES_DIR, book_slug)
    os.makedirs(book_dir, exist_ok=True)
    print(f"  id={book_id} slug={book_slug}", file=sys.stderr)

    rss_url = book.get("url_rss")
    if not rss_url:
        print(f"  no rss, skip", file=sys.stderr)
        continue

    chapters = fetch_chapters(rss_url)
    parts = []
    for i, ch in enumerate(chapters, 1):
        url = ch["url"]
        ext = os.path.splitext(urllib.parse.urlparse(url).path)[1] or ".mp3"
        # Prefix with book slug so transcript filenames don't collide across books
        # (transcribe.py uses the mp3 basename to derive the transcript path).
        fname = f"{book_slug}-{i:02d}{ext}"
        dest = os.path.join(book_dir, fname)
        download(url, dest)
        parts.append({
            "partNumber": i,
            "title": ch["title"],
            "filename": fname,
        })

    authors = book.get("authors") or []
    author_name = ", ".join(
        f"{(a.get('first_name') or '').strip()} {(a.get('last_name') or '').strip()}".strip()
        for a in authors
    ).strip(", ")

    manifest = {
        "id": f"librivox/{book_slug}",
        "sourceID": "librivox",
        "title": title,
        "author": author_name or "Unknown",
        "level": level,
        "librivoxID": book_id,
        "chapters": parts,
    }
    with open(os.path.join(book_dir, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    print(f"  wrote {len(parts)} chapters + manifest.json", file=sys.stderr)

print("\nall done", file=sys.stderr)
