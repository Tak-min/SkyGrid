#!/usr/bin/env python3
"""Write a numbered contact sheet of the tiles that survive automatic filtering.

The last selection pass is manual and cannot be automated: a grey building and a grey
cloud, or beach sand and haze, are not separable by colour statistics. Run this after
any re-fetch, read off the indices of the bad tiles, and pass them to
`python3 contact_sheet.py <index> <index> ...` to print filenames ready to paste into
`EXCLUDED_FILES` in render_grid.py.
"""

from __future__ import annotations

import sys

from PIL import Image, ImageDraw

import render_grid as R

COLS, CELL = 8, 150


def main() -> None:
    photos = R.load_photos()
    if not photos:
        raise SystemExit("no photos survived filtering — run fetch_skies.py first")

    if len(sys.argv) > 1:
        try:
            indices = [int(a) for a in sys.argv[1:]]
        except ValueError:
            raise SystemExit("usage: contact_sheet.py [index ...]") from None
        bad = [i for i in indices if 0 <= i < len(photos)]
        if len(bad) != len(indices):
            print(f"  ! ignored out-of-range indices (have 0..{len(photos) - 1})")
        for i in bad:
            print(f'    "{photos[i].name}",')
        print(f"\n{len(photos) - len(bad)} tiles would remain")
        return

    rows = (len(photos) + COLS - 1) // COLS
    sheet = Image.new("RGB", (COLS * CELL, rows * CELL), "#111111")
    draw = ImageDraw.Draw(sheet)
    for i, path in enumerate(photos):
        x, y = (i % COLS) * CELL, (i // COLS) * CELL
        sheet.paste(R.sky_tile(path, CELL), (x, y))
        draw.rectangle([x, y, x + 34, y + 20], fill="#000000")
        draw.text((x + 5, y + 4), str(i), fill="#FFFFFF", font=R.font(15))

    R.OUT.mkdir(parents=True, exist_ok=True)
    out = R.OUT / "contact-sheet.png"
    sheet.save(out)
    print(f"{len(photos)} tiles -> {out}")
    print("Review it, then: python3 contact_sheet.py <bad index> <bad index> ...")


if __name__ == "__main__":
    main()
