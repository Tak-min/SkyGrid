#!/usr/bin/env python3
"""Build deterministic 9:16 scene cards for the first Sky Grid social video.

The video deliberately opens on the desired outcome, then proves the product with
real app screenshots. A single AI-generated lifestyle image is used for the social
beat and is labelled inside the frame.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BUILD = HERE / "build"

SIZE = (1080, 1920)
INK = (24, 24, 22)
CREAM = (249, 246, 240)
WHITE = (255, 255, 255)

FONT_REGULAR = "/System/Library/Fonts/SFNS.ttf"
FONT_ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"


def font(size: int, rounded: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_ROUNDED if rounded else FONT_REGULAR, size)


def cover(source: Image.Image, size: tuple[int, int], focus_y: float = 0.5) -> Image.Image:
    source = source.convert("RGB")
    scale = max(size[0] / source.width, size[1] / source.height)
    resized = source.resize(
        (round(source.width * scale), round(source.height * scale)),
        Image.Resampling.LANCZOS,
    )
    left = max(0, (resized.width - size[0]) // 2)
    available_y = max(0, resized.height - size[1])
    top = round(available_y * focus_y)
    return resized.crop((left, top, left + size[0], top + size[1]))


def add_paper(canvas: Image.Image, opacity: int = 10) -> None:
    noise = Image.effect_noise(canvas.size, 8).convert("L")
    texture = Image.new("RGBA", canvas.size, (100, 88, 72, 0))
    texture.putalpha(noise.point(lambda value: value * opacity // 255))
    canvas.alpha_composite(texture)


def centered_text(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    text: str,
    face: ImageFont.FreeTypeFont,
    fill: tuple[int, ...],
    spacing: int = 10,
) -> None:
    draw.multiline_text(xy, text, font=face, fill=fill, anchor="ma", align="center", spacing=spacing)


# The hook asks "what if every morning became this?", so the answer behind the words has
# to be skies, not an illustration of skies. `branding/promo/out/hook-background-9x16.png`
# is a full-bleed grid of real, freely-licensed sky photographs laid out with the app's
# own geometry (see branding/promo/render_grid.py); the illustrated concept mockup is the
# fallback for when that file has not been rendered yet.
HOOK_BACKGROUNDS = (
    ROOT / "branding/promo/out/hook-background-9x16.png",
    ROOT / "branding/mockups/backgrounds/overview-year-v1.png",
)


def hook_background() -> tuple[Path, bool]:
    for candidate in HOOK_BACKGROUNDS:
        if candidate.exists():
            return candidate, candidate == HOOK_BACKGROUNDS[0]
    raise SystemExit("no hook background available")


def scene_hook() -> Image.Image:
    background, is_photographic = hook_background()
    canvas = cover(Image.open(background), SIZE).convert("RGBA")
    # Real photographs carry their own contrast, so they need less shading than a flat
    # illustration before white type stays readable over them.
    shade = Image.new("RGBA", SIZE, (11, 14, 20, 140 if is_photographic else 165))
    canvas.alpha_composite(shade)

    # Keep copy away from TikTok's right-side controls and lower caption tray.
    top = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    top_draw = ImageDraw.Draw(top)
    for y in range(0, 610):
        alpha = round(205 * (1 - y / 610))
        top_draw.line((0, y, 1080, y), fill=(6, 8, 12, alpha))
    canvas.alpha_composite(top)

    bottom = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    bottom_draw = ImageDraw.Draw(bottom)
    for y in range(1400, 1920):
        alpha = round(180 * ((y - 1400) / 520))
        bottom_draw.line((0, y, 1080, y), fill=(6, 8, 12, alpha))
    canvas.alpha_composite(bottom)

    draw = ImageDraw.Draw(canvas)
    centered_text(draw, (540, 106), "S K Y   G R I D", font(28), (255, 255, 255, 180))
    centered_text(
        draw,
        (540, 228),
        "WHAT IF EVERY\nMORNING\nBECAME THIS?",
        font(92, rounded=True),
        WHITE,
        spacing=2,
    )
    centered_text(draw, (540, 1700), "ONE SKY PHOTO  •  EVERY DAY", font(33), (255, 255, 255, 210))
    # The photographs are genuine, but the grid is not any one person's record, so the
    # frame still needs a disclaimer — a more precise one than "concept visual", which
    # would undersell real skies while leaving the arrangement unexplained.
    disclaimer = "REAL SKY PHOTOS  •  SAMPLE GRID" if is_photographic else "CONCEPT VISUAL"
    centered_text(draw, (540, 1760), disclaimer, font(22), (255, 255, 255, 135))
    return canvas


def scene_app(source: Path) -> Image.Image:
    screenshot = Image.open(source).convert("RGB")
    background = cover(screenshot, SIZE).filter(ImageFilter.GaussianBlur(34))
    background = ImageEnhance.Brightness(background).enhance(1.08).convert("RGBA")
    background.alpha_composite(Image.new("RGBA", SIZE, (*CREAM, 158)))

    height = 1920
    width = round(screenshot.width * height / screenshot.height)
    sharp = screenshot.resize((width, height), Image.Resampling.LANCZOS).convert("RGBA")
    background.alpha_composite(sharp, ((1080 - width) // 2, 0))
    return background


def scene_friends() -> Image.Image:
    source = HERE / "assets" / "two-friends-dawn-ai.png"
    canvas = cover(Image.open(source), SIZE, focus_y=0.43).convert("RGBA")
    overlay = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    odraw = ImageDraw.Draw(overlay)
    for y in range(0, 690):
        alpha = round(195 * (1 - y / 690))
        odraw.line((0, y, 1080, y), fill=(4, 5, 8, alpha))
    for y in range(1480, 1920):
        alpha = round(145 * ((y - 1480) / 440))
        odraw.line((0, y, 1080, y), fill=(4, 5, 8, alpha))
    canvas.alpha_composite(overlay)

    draw = ImageDraw.Draw(canvas)
    centered_text(draw, (540, 125), "DO IT WITH\nONE FRIEND.", font(98, rounded=True), WHITE, spacing=0)

    label = (54, 1784, 420, 1850)
    draw.rounded_rectangle(label, radius=33, fill=(0, 0, 0, 145))
    draw.text((78, 1817), "AI-GENERATED IMAGERY", font=font(22), fill=(255, 255, 255, 215), anchor="lm")
    return canvas


def rounded_icon(source: Path, size: int) -> Image.Image:
    icon = Image.open(source).convert("RGB").resize((size, size), Image.Resampling.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=round(size * 0.22), fill=255)
    icon.putalpha(mask)
    return icon


def scene_cta() -> Image.Image:
    background_path = ROOT / "branding/mockups/backgrounds/buddies-connection-v1.png"
    canvas = cover(Image.open(background_path), SIZE).convert("RGBA")
    canvas.alpha_composite(Image.new("RGBA", SIZE, (255, 252, 246, 56)))
    add_paper(canvas, opacity=8)

    icon = rounded_icon(ROOT / "branding/app-icon/skygrid-app-icon-v1-1024.png", 264)
    shadow = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((420, 330, 684, 594), radius=58, fill=(39, 33, 24, 95))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(icon, (408, 310))

    draw = ImageDraw.Draw(canvas)
    centered_text(draw, (540, 690), "SEND THIS TO YOUR\nMORNING PERSON.", font(82, rounded=True), INK, spacing=4)
    centered_text(draw, (540, 930), "Start tomorrow.", font(42), (83, 78, 70))

    button = (128, 1200, 952, 1366)
    draw.rounded_rectangle(button, radius=83, fill=(24, 24, 22))
    draw.text((540, 1283), "DOWNLOAD SKY GRID", font=font(38, rounded=True), fill=WHITE, anchor="mm")
    centered_text(draw, (540, 1432), "AVAILABLE ON THE APP STORE", font(27), (87, 82, 74))
    centered_text(draw, (540, 1790), "S K Y   G R I D", font(27), (87, 82, 74, 170))
    return canvas


def main() -> None:
    BUILD.mkdir(parents=True, exist_ok=True)
    scenes = {
        "scene-01-hook.png": scene_hook(),
        "scene-02-today.png": scene_app(ROOT / "branding/mockups/app-store-resized/01-today-one-sky-v1.png"),
        "scene-03-friends.png": scene_friends(),
        "scene-04-grid.png": scene_app(ROOT / "branding/mockups/app-store-resized/02-grid-year-in-view-v1.png"),
        "scene-05-cta.png": scene_cta(),
    }
    for name, image in scenes.items():
        path = BUILD / name
        image.convert("RGB").save(path, quality=95)
        print(path)


if __name__ == "__main__":
    main()
