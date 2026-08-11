#!/usr/bin/env python3
"""Render Sky Grid promo mosaics from real, freely-licensed sky photographs.

Each cell is the PHOTOGRAPH itself, aspect-filled into its square slot — matching
`ArchivePhotoTile` (Grid/SkyGridView.swift), which draws `Image(uiImage: thumbnail)`.
The flat average colour is only the app's fallback for a cell whose thumbnail has not
loaded, so building a promo mosaic out of average colours shows the fallback rather
than the product.

Geometry and palette are copied from the app rather than invented:
  * year grid  — 31 columns x 12 rows, cell 30px, spacing 2px (SkyGridExportView)
  * ground     — #0B0E14, empty cell white@9%             (SGExport)
  * archive    — 7 columns, zero spacing, square corners  (GridLayoutMath.sequentialDates)
  * cell crop  — aspect-fill, centred                     (GridLayoutMath.aspectFillRect)

Deliberately NOT rendered: a handle, a testimonial, or a total that would read as one
real person's completed record.
"""

from __future__ import annotations

import calendar
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

from sky_color import sky_hex  # noqa: F401 - kept for the colour cross-check tooling

HERE = Path(__file__).resolve().parent
SKIES = HERE / "skies"
MANIFEST = HERE / "skies_manifest.json"
OUT = HERE / "out"

YEAR = 2026
COLUMNS, ROWS = 31, 12
CELL, SPACING = 30, 2

GROUND = "#0B0E14"
INK = (255, 255, 255)
INK2 = (255, 255, 255, 158)   # white @ 0.62
INK3 = (255, 255, 255, 87)    # white @ 0.34
CELL_EMPTY = (255, 255, 255, 23)  # white @ 0.09
WARM_WHITE = "#FAF7F2"

FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Futura.ttc",
    "/System/Library/Fonts/HelveticaNeue.ttc",
    "/System/Library/Fonts/Helvetica.ttc",
    "/Library/Fonts/Arial.ttf",
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    for path in FONT_CANDIDATES:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size, index=1 if bold else 0)
            except OSError:
                try:
                    return ImageFont.truetype(path, size)
                except OSError:
                    continue
    return ImageFont.load_default(size)


SKY_PIXEL_RATIO = 0.93      # a capture aimed at the sky is almost entirely sky
MONOCHROME_CHANNEL_SPREAD = 6.0


def tile_is_clean_sky(tile: Image.Image) -> bool:
    """Judge the square crop that will actually be shown, not the whole source file.

    Commons search returns towers, parachutes, cornfields, black-and-white studies and
    wide landscapes alongside sky photographs. Averaging hides all of that; once the
    photograph itself is the tile, anything with ground, foliage or an object in frame
    reads instantly as "not a phone pointed at the sky", so it has to be excluded.
    """
    import numpy as np

    arr = np.asarray(tile.resize((64, 64), Image.BILINEAR), dtype=np.float32)
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]

    # Black-and-white source: every channel agrees everywhere.
    if float(np.mean(np.abs(r - g)) + np.mean(np.abs(g - b))) < MONOCHROME_CHANNEL_SPREAD:
        return False

    brightness = 0.2126 * r + 0.7152 * g + 0.0722 * b
    spread = arr.max(axis=-1) - arr.min(axis=-1)

    blue_sky = (b >= r) & (brightness > 70)
    bright_cloud = (spread < 34) & (brightness > 120)
    dawn_warm = (r > b) & (brightness > 95) & ~((g > r) & (g > b))
    sky = blue_sky | bright_cloud | dawn_warm

    # Ground and foliage veto whatever else matched.
    sky &= ~((g > r + 6) & (g > b + 6))
    sky &= brightness > 45

    if float(sky.mean()) < SKY_PIXEL_RATIO:
        return False

    # Sky is cool or neutral almost everywhere: even a flat overcast grey keeps blue at
    # or above red. Paper, plaster, pencil drawings and scanned manuscripts are warm —
    # and they are pale and soft, so brightness and edge tests alone wave them through.
    # A genuinely warm frame is only accepted when it is *saturated*, which separates a
    # sunrise from a sheet of aged paper.
    cool = float((b >= r - 8).mean())
    warm_saturated = float(((r > b + 25) & (spread > 50)).mean())
    if cool < 0.60 and warm_saturated < 0.25:
        return False

    # A horizon is a band of darker ground across the bottom. Clouds do not produce a
    # step change between the top and bottom edges of a frame aimed upwards.
    if float(brightness[:10].mean() - brightness[-10:].mean()) > 45:
        return False

    # Cloud edges are soft; parachutes, branches, masts, rooftops and handwriting are
    # not. Measured at 160px, because downsampling to 64px blurs script and fine line
    # work into something indistinguishable from haze.
    fine = np.asarray(tile.resize((160, 160), Image.BILINEAR), dtype=np.float32)
    fine_lum = 0.2126 * fine[..., 0] + 0.7152 * fine[..., 1] + 0.0722 * fine[..., 2]
    gx = np.abs(np.diff(fine_lum, axis=1))
    gy = np.abs(np.diff(fine_lum, axis=0))
    hard = (float((gx > 38).mean()) + float((gy > 38).mean())) / 2
    return hard <= 0.02


# Commons holds a great deal of scanned artwork whose subject is the sky. A painted
# sky passes every colour and edge test but is unmistakably not a phone photograph, and
# the giveaway is in the file title rather than the pixels.
NON_PHOTO_TITLE_MARKERS = (
    "painting", "paint", "oil on", "canvas", "watercolour", "watercolor", "aquarell",
    "drawing", "sketch", "etching", "lithograph", "engraving", "illustration",
    "museum", "gallery", "collection", "kunst", "peinture", "gemälde", "gemalde",
    "study for", "landscape with", "-fig-", "plate ", "map", "diagram", "chart",
    "letter", "manuscript", "_ms_", "album", "blueprint", "plan_", "poster", "print",
    "aircraft", "airplane", "aeroplane", "airliner", "flight", "logo", "seal",
    "postcard", "stamp", "cover", "page", "book", "document", "archive",
)


# Search terms whose results are dominated by things that survive every pixel test but
# are obviously not a phone pointed at the sky. Measured, not guessed: grouping the
# surviving tiles by source term showed the meteorological cloud-type queries returning
# clean photographs, while these three supplied the aircraft renders, paper textures and
# building gables that kept reappearing in the mosaic.
NOISY_SOURCE_TERMS = {
    "contrails blue sky",       # 3D aircraft models on plain backgrounds
    "sky texture background",   # paper, plaster and fabric swatches
    "clouds from below",        # roof lines and interiors shot upwards
}


# Culled by eye from `out/contact-sheet.png`. Colour statistics cannot separate a grey
# building from a grey cloud, or beach sand from haze, so the last pass is manual and
# recorded here rather than repeated. Regenerate the sheet after any re-fetch and revise
# this list; nothing else in the pipeline depends on it.
EXCLUDED_FILES = {
    "02_NASA_s_Orion_Spacecraft_Parachutes_Tested_at_U_S__Army_Yuma_.jpg",   # parachute
    "25_Cirrus_cloud_over_Federal_Way__WA.jpg",                              # foliage
    "33_Lone_Pine_Road_Clouds__Jefferson_County__Oregon_scenic_image.jpg",   # treeline
    "86_Morning_Sky_view_of_Religious_ground.jpg",                           # canopy
    "129_Stratocumulus_castellanus_break_2.jpg",                             # branch
    "150_Clouds_06.jpg",                                                     # rooftops
    "182_Hodler_-_Genfersee_mit_Mont-Blanc_im_Morgenrot_-_1918.jpg",         # painting
    "216_Dawn-_Sending_away_Coastal_Motor_Boats__11th_August_1918_Art.jpg",  # painting
    "253_Cloudscape_over_the_Asiago_Plateau__Italy__1918_Art_IWMART45.jpg",  # painting
    "256_Rock_Formation_and_Cloudscape_over_the_Alps__Italy__1918_Art.jpg",  # painting
    "276_Altostratus_translucidus_1.jpg",                                    # house
    "382_Cumulus_castellanus_1.jpg",                                         # moon, night
    "388_Cirrus-cumulus.jpg",                                                # shoreline
    "390_The_Lost_Cloud__243288481_.jpg",                                    # building gable
    "392_2456Clouds_and_blue_sky_in_Hagonoy_and_Paombong_river_19.jpg",      # riverside block
    "393_2456Clouds_and_blue_sky_in_Hagonoy_and_Paombong_river_21.jpg",
    "394_2456Clouds_and_blue_sky_in_Hagonoy_and_Paombong_river_20.jpg",
    "395_2456Clouds_and_blue_sky_in_Hagonoy_and_Paombong_river_22.jpg",
}


def load_photos() -> list[Path]:
    if MANIFEST.exists():
        entries = json.loads(MANIFEST.read_text())
        paths = [
            SKIES / e["file"] for e in entries
            if not any(m in e["title"].lower() for m in NON_PHOTO_TITLE_MARKERS)
            and e.get("category") not in NOISY_SOURCE_TERMS
            and e["file"] not in EXCLUDED_FILES
        ]
        dropped = len(entries) - len(paths)
        if dropped:
            print(f"  {dropped} file(s) dropped: title indicates artwork, not a photograph")
    else:
        paths = [
            p for p in sorted(SKIES.glob("*.jpg"))
            if not any(m in p.stem.lower().replace("_", " ") for m in NON_PHOTO_TITLE_MARKERS)
        ]

    kept, rejected = [], 0
    for path in paths:
        if not path.exists():
            continue
        try:
            if tile_is_clean_sky(sky_tile(path, 256)):
                kept.append(path)
            else:
                rejected += 1
        except Exception as exc:  # noqa: BLE001 - a corrupt download must not stop the render
            print(f"  ! skipped {path.name}: {exc}")
    print(f"  {rejected} photo(s) rejected: frame was not clean sky")
    return kept


def sky_tile(path: Path, size: int) -> Image.Image:
    """A square, aspect-filled crop biased to the upper part of the frame.

    `centering=(0.5, 0.25)` keeps the crop where the sky is. A centre crop on a
    landscape-orientation photo pulls in the horizon and ground, which is not what a
    capture aimed at the sky looks like.
    """
    with Image.open(path) as img:
        img = ImageOps.exif_transpose(img).convert("RGB")
        return ImageOps.fit(img, (size, size), Image.LANCZOS, centering=(0.5, 0.25))


def render_vertical(photos: list[Path]) -> Path:
    """1080x1920 for TikTok: 7 columns of real photographs, zero gaps.

    The year grid is 990x382, so dropping it into a 9:16 frame strands a thin band in
    dark space; seven columns grow downwards and fill the format.
    """
    width, height = 1080, 1920
    cols = 7
    # Full bleed: a mosaic floated in the middle of a 9:16 frame leaves most of the
    # screen empty, and on TikTok the empty part is what the viewer sees first. Size
    # the cell from the frame width and fill top to bottom instead.
    cell = -(-width // cols)                       # ceil, so 7 columns cover the width
    # Only complete rows: a trailing part-row leaves dark notches along the edge of the
    # block, which reads as a rendering defect rather than as an unfinished month. When
    # there are not enough photographs to reach the bottom of the frame the mosaic sits
    # centred, and the bands above and below are where the headline and CTA go — copy is
    # set in the editor, so that space is wanted rather than wasted.
    rows = min(-(-height // cell), len(photos) // cols)
    if rows == 0:
        raise SystemExit(f"need at least {cols} photos for the vertical mosaic")
    capacity = rows * cols

    canvas = Image.new("RGB", (width, height), GROUND)
    ox, oy = (width - cell * cols) // 2, (height - cell * rows) // 2
    for i, path in enumerate(photos[:capacity]):
        canvas.paste(sky_tile(path, cell), (ox + (i % cols) * cell, oy + (i // cols) * cell))
    print(f"  vertical: {capacity} tiles ({cols}x{rows}), {len(photos) - capacity} spare")

    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / "mosaic-9x16.png"
    canvas.save(out)
    return out


def render_hook_background(photos: list[Path]) -> Path:
    """A full-bleed 1080x1920 mosaic for the promo video's opening frame.

    Distinct from `mosaic-9x16.png`, which centres a whole number of 7-wide rows and
    keeps margins for copy. Here the frame is a *background*: it is shaded and typed over
    in `video-v1/make_assets.py`, so any dark margin would read as a letterbox. The
    column count is chosen so the available photographs tile the frame edge to edge, and
    no photograph is repeated — a visible repeat in a mosaic reads as a rendering bug.
    """
    width, height = 1080, 1920
    best: tuple[int, int, int] | None = None  # (waste, cols, rows)
    for cols in range(4, 13):
        cell = -(-width // cols)
        rows = -(-height // cell)
        if cols * rows > len(photos):
            continue
        waste = abs(cell * rows - height)
        if best is None or waste < best[0]:
            best = (waste, cols, rows)

    if best is None:
        # Too few photographs to cover the frame at any sensible cell size; fall back to
        # the widest grid that fits and let the caller see it is short.
        cols = 7
        cell = -(-width // cols)
        rows = max(1, len(photos) // cols)
        print(f"  ! hook background short: {cols}x{rows} does not reach the frame bottom")
    else:
        _, cols, rows = best
        cell = -(-width // cols)

    canvas = Image.new("RGB", (width, height), GROUND)
    ox, oy = (width - cell * cols) // 2, (height - cell * rows) // 2
    for i, path in enumerate(photos[:cols * rows]):
        canvas.paste(sky_tile(path, cell), (ox + (i % cols) * cell, oy + (i // cols) * cell))
    print(f"  hook background: {cols}x{rows} at {cell}px")

    out = OUT / "hook-background-9x16.png"
    canvas.save(out)
    return out


def render_month_archive(photos: list[Path]) -> Path:
    """The in-app PHOTO ARCHIVE look: 7 columns, zero gaps, square corners, warm ground."""
    cols, cell, pad = 7, 150, 72
    count = min(len(photos), 31)
    rows = (count + cols - 1) // cols

    canvas = Image.new("RGB", (cols * cell + pad * 2, rows * cell + pad * 2), WARM_WHITE)
    for i in range(count):
        canvas.paste(sky_tile(photos[i], cell), (pad + (i % cols) * cell, pad + (i // cols) * cell))

    out = OUT / "month-archive.png"
    canvas.save(out)
    return out


# Sky Grid reached the App Store on 2026-08-06, so no 2026 grid can hold a morning
# earlier than that. Filling from January would depict a year nobody could have had.
FIRST_POSSIBLE = (8, 6)

# The app draws this card at 30px cells on a phone screen. Rendered at that size as a
# flat file the photographs turn to noise, so everything is scaled up — geometry stays
# proportionally identical to SkyGridExportView, it is just resolved for a poster.
CARD_SCALE = 3


def render_share_card(photos: list[Path]) -> Path:
    """Replica of SkyGridExportView: wordmark, count, year, then the year mosaic.

    Text blocks are stacked from measured boxes rather than guessed offsets — a large
    face carries internal leading that makes hand-picked y values collide.
    """
    s = CARD_SCALE
    cell, spacing = CELL * s, SPACING * s
    grid_w = COLUMNS * cell + (COLUMNS - 1) * spacing
    grid_h = ROWS * cell + (ROWS - 1) * spacing
    margin = 88 * s

    wordmark_f = font(26 * s)
    count_f = font(132 * s, bold=True)
    unit_f, year_f = font(34 * s), font(26 * s)
    count_text = str(len(photos))
    probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    count_box = probe.textbbox((0, 0), count_text, font=count_f)
    count_h = count_box[3] - count_box[1]

    y = margin
    wordmark_y = y
    y += (26 + 44) * s
    count_y = y
    y += count_h + 22 * s
    year_y = y
    y += (26 + 46) * s
    grid_y = y

    card = Image.new("RGB", (grid_w + margin * 2, grid_y + grid_h + margin), GROUND)
    draw = ImageDraw.Draw(card)
    draw.text((margin, wordmark_y), "S K Y   G R I D", font=wordmark_f, fill=(158, 160, 166))
    draw.text((margin - count_box[0], count_y - count_box[1]), count_text, font=count_f, fill=INK)
    draw.text((margin + (count_box[2] - count_box[0]) + 20 * s, count_y + count_h - 34 * s),
              "mornings", font=unit_f, fill=(158, 160, 166))
    draw.text((margin, year_y), f"in {YEAR}", font=year_f, fill=(96, 99, 106))

    def slot_xy(month: int, day: int) -> tuple[int, int]:
        return margin + (day - 1) * (cell + spacing), grid_y + (month - 1) * (cell + spacing)

    # Empty cells first, then photographs over the days that have one.
    empty = Image.new("RGBA", card.size, (0, 0, 0, 0))
    edraw = ImageDraw.Draw(empty)
    for month in range(1, 13):
        for day in range(1, calendar.monthrange(YEAR, month)[1] + 1):
            x, yy = slot_xy(month, day)
            edraw.rectangle([x, yy, x + cell - 1, yy + cell - 1], fill=CELL_EMPTY)
    card = Image.alpha_composite(card.convert("RGBA"), empty).convert("RGB")

    slots = [
        (m, d)
        for m in range(1, 13)
        for d in range(1, calendar.monthrange(YEAR, m)[1] + 1)
        if (m, d) >= FIRST_POSSIBLE
    ]
    for path, (month, day) in zip(photos, slots):
        card.paste(sky_tile(path, cell), slot_xy(month, day))

    out = OUT / "year-share-card.png"
    card.save(out)
    return out


def main() -> None:
    photos = load_photos()
    if not photos:
        raise SystemExit("no sky photos found — run fetch_skies.py first")

    print(f"{len(photos)} real sky photographs tiled")
    renders = (
        render_vertical(photos),
        render_hook_background(photos),
        render_month_archive(photos),
        render_share_card(photos),
    )
    for path in renders:
        print(f"  wrote {path}")


if __name__ == "__main__":
    main()
