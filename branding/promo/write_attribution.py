#!/usr/bin/env python3
"""Emit ATTRIBUTION.md for the downloaded sky photographs.

CC BY / CC BY-SA require credit wherever the work is used. The mosaics only ever show
an averaged colour rather than any recognisable part of a photograph, but the source
files themselves are stored in this repo, so the credit list has to exist and stay in
sync with `skies_manifest.json`.
"""

from __future__ import annotations

import json
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
MANIFEST = HERE / "skies_manifest.json"
OUT = HERE / "ATTRIBUTION.md"


def main() -> None:
    entries = json.loads(MANIFEST.read_text())
    licences = Counter(e["licence"] for e in entries)

    lines = [
        "# Sky photograph credits",
        "",
        f"{len(entries)} photographs, all from Wikimedia Commons under licences that permit",
        "commercial use. Collected by `fetch_skies.py`; regenerate this file with",
        "`python3 write_attribution.py` after any re-fetch.",
        "",
        "## Licence breakdown",
        "",
        "| Licence | Files |",
        "|---|---:|",
    ]
    lines += [f"| {lic or '(unstated)'} | {n} |" for lic, n in licences.most_common()]
    lines += [
        "",
        "## Files",
        "",
        "| Local file | Author | Licence | Source |",
        "|---|---|---|---|",
    ]
    for e in entries:
        title = e["title"].removeprefix("File:")
        author = (e["author"] or "—").replace("|", "/")
        lines.append(
            f"| `{e['file']}` | {author} | {e['licence']} | [{title[:48]}]({e['source']}) |"
        )

    OUT.write_text("\n".join(lines) + "\n")
    print(f"wrote {OUT} ({len(entries)} entries)")


if __name__ == "__main__":
    main()
