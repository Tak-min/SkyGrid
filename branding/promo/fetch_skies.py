#!/usr/bin/env python3
"""Collect freely-licensed real sky photographs from Wikimedia Commons.

Only Commons is used: its API needs no key and every file carries a machine-readable
licence, so provenance can be reported rather than assumed. Files whose licence is not
clearly free-for-commercial-use are skipped rather than downloaded.
"""

from __future__ import annotations

import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

API = "https://commons.wikimedia.org/w/api.php"
UA = "SkyGridPromoAssets/1.0 (https://skygrid.my; taku810616@gmail.com)"
OUT = Path(__file__).resolve().parent / "skies"
MANIFEST = Path(__file__).resolve().parent / "skies_manifest.json"

# Search terms rather than categories: a Commons category holds its files in
# subcategories, so `list=categorymembers` on a broad term like "Blue skies" returns
# almost nothing. Full-text search over the File namespace does not have that problem.
# The terms span the weather range a real morning ritual would produce: clear, overcast,
# broken cloud, and the coloured light around sunrise.
CATEGORIES = [
    "cumulus mediocris",
    "cumulus fractus",
    "stratocumulus stratiformis",
    "altocumulus stratiformis",
    "cirrus fibratus",
    "cirrus uncinus",
    "cirrostratus halo sky",
    "altocumulus lenticularis",
    "stratus nebulosus sky",
    "cumulus congestus sky",
    "cirrocumulus stratiformis",
    "altostratus undulatus",
]

# Substrings that indicate a licence usable in commercial promotional material.
FREE_MARKERS = ("cc0", "cc-by", "cc-zero", "public domain", "pd-", "attribution")
# Explicitly excluded: NonCommercial and NoDerivatives forbid this use.
BLOCKED_MARKERS = ("-nc", "noncommercial", "-nd", "noderiv", "fair use", "non-free")

TARGET_PER_CATEGORY = 40
WIDTH = 800  # thumbnail width; full resolution is unnecessary for an average colour
SEARCH_PAGES = 6  # 50 results per page, so up to 300 candidates considered per term


def api(params: dict) -> dict:
    params = {**params, "format": "json", "formatversion": "2"}
    url = f"{API}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def category_members(term: str, limit: int) -> list[str]:
    """Titles of File-namespace pages matching `term`, most relevant first.

    Paginated: one search page caps at 50 hits, and many of those are filtered out
    later for licence or MIME type, so a single page cannot fill a 365-cell grid.
    """
    titles: list[str] = []
    for page in range(SEARCH_PAGES):
        data = api({
            "action": "query",
            "list": "search",
            "srsearch": term,
            "srnamespace": "6",
            "srlimit": "50",
            "sroffset": str(page * 50),
        })
        hits = data.get("query", {}).get("search", [])
        titles.extend(hit["title"] for hit in hits)
        if len(hits) < 50 or len(titles) >= limit * 8:
            break
        time.sleep(0.3)
    return titles


def image_info(titles: list[str]) -> list[dict]:
    """Fetch licence + thumbnail URL for up to 50 titles in one request."""
    data = api({
        "action": "query",
        "titles": "|".join(titles),
        "prop": "imageinfo",
        "iiprop": "url|extmetadata|mime",
        "iiurlwidth": str(WIDTH),
    })
    return data.get("query", {}).get("pages", [])


def licence_of(page: dict) -> tuple[str, str]:
    info = (page.get("imageinfo") or [{}])[0]
    meta = info.get("extmetadata", {})
    short = (meta.get("LicenseShortName", {}) or {}).get("value", "")
    name = (meta.get("License", {}) or {}).get("value", "")
    artist = (meta.get("Artist", {}) or {}).get("value", "")
    # Artist arrives as HTML; keep it readable without pulling in a parser.
    for tag in ("<br />", "<br>", "</a>", "</span>", "</div>"):
        artist = artist.replace(tag, " ")
    while "<" in artist and ">" in artist:
        start = artist.index("<")
        end = artist.index(">", start)
        artist = artist[:start] + artist[end + 1:]
    return f"{short or name}".strip(), " ".join(artist.split())[:120]


def is_free(licence: str) -> bool:
    low = licence.lower()
    if any(bad in low for bad in BLOCKED_MARKERS):
        return False
    return any(good in low for good in FREE_MARKERS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    # Append rather than restart: roughly three quarters of Commons hits are rejected
    # later for having ground or objects in frame, so filling a grid takes several
    # passes with different search terms, and re-downloading what is already on disk
    # only invites another HTTP 429.
    manifest: list[dict] = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else []
    seen: set[str] = {e["title"] for e in manifest}

    for category in CATEGORIES:
        try:
            titles = category_members(category, TARGET_PER_CATEGORY)
        except Exception as exc:  # noqa: BLE001 - report and continue to next category
            print(f"  ! {category}: listing failed ({exc})")
            continue

        kept = 0
        for chunk_start in range(0, len(titles), 50):
            if kept >= TARGET_PER_CATEGORY:
                break
            chunk = titles[chunk_start:chunk_start + 50]
            try:
                pages = image_info(chunk)
            except Exception as exc:  # noqa: BLE001
                print(f"  ! {category}: imageinfo failed ({exc})")
                break

            for page in pages:
                if kept >= TARGET_PER_CATEGORY:
                    break
                info = (page.get("imageinfo") or [{}])[0]
                if not info.get("thumburl"):
                    continue
                if info.get("mime") not in ("image/jpeg", "image/png"):
                    continue

                licence, artist = licence_of(page)
                if not is_free(licence):
                    continue

                title = page["title"]
                if title in seen:
                    continue
                seen.add(title)

                stem = title.removeprefix("File:").rsplit(".", 1)[0]
                safe = "".join(c if c.isalnum() or c in "-_" else "_" for c in stem)[:60]
                dest = OUT / f"{len(manifest):02d}_{safe}.jpg"

                try:
                    req = urllib.request.Request(info["thumburl"], headers={"User-Agent": UA})
                    with urllib.request.urlopen(req, timeout=60) as resp:
                        dest.write_bytes(resp.read())
                except Exception as exc:  # noqa: BLE001
                    print(f"  ! download failed {title}: {exc}")
                    continue

                manifest.append({
                    "file": dest.name,
                    "title": title,
                    "category": category,
                    "licence": licence,
                    "author": artist,
                    "source": info.get("descriptionurl", ""),
                })
                kept += 1
                time.sleep(0.4)  # be polite: a tighter loop earned an HTTP 429

        print(f"  {category}: {kept} kept")

    MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False))
    print(f"\n{len(manifest)} photos -> {OUT}")
    print(f"manifest -> {MANIFEST}")


if __name__ == "__main__":
    main()
