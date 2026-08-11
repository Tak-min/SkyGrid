#!/usr/bin/env python3
"""Replicate SkyColorExtractor (ios/SkyGrid/Sources/SkyColor/SkyColorExtractor.swift).

The app takes the top 55% of the frame and area-averages it with CIAreaAverage in an
explicitly sRGB working space — i.e. an arithmetic mean of the sRGB-encoded channel
values, not a linear-light average. That is reproduced here as a plain mean over the
band, so promo assets carry the same colours the app itself would produce.

`verify` checks this against the Pillow cross-check values already recorded in
SkyColorExtractorTests.swift. If those do not match, the replication is wrong and the
generated grid must not be described as the app's output.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

SKY_BAND_FRACTION = 0.55

# Oracles copied from ios/SkyGrid/Tests/SkyColorExtractorTests.swift.
ORACLES = {
    "real_clear_sky": "#326FB5",
    "real_overcast_sky": "#81888C",
    "real_sunset_sky": "#4F69A6",
    "real_dramatic_sky": "#694054",
}
FIXTURES = Path.home() / "Desktop/SkyGrid/ios/SkyGrid/Tests/Fixtures"


def sky_hex(path: Path) -> str:
    with Image.open(path) as img:
        # EXIF orientation matters: the app decodes via UIImage, which honours it.
        img = ImageOps.exif_transpose(img).convert("RGB")
        arr = np.asarray(img, dtype=np.float64)

    band_height = int(round(arr.shape[0] * SKY_BAND_FRACTION))
    band = arr[:band_height]
    r, g, b = band.reshape(-1, 3).mean(axis=0)
    # Truncate, do not round: CIAreaAverage's render into a UInt8 bitmap truncates, and
    # the recorded oracle values match truncation. Rounding drifts one level on three of
    # the four fixtures.
    return "#{:02X}{:02X}{:02X}".format(int(r), int(g), int(b))


def verify() -> bool:
    ok = True
    for stem, expected in ORACLES.items():
        got = sky_hex(FIXTURES / f"{stem}.jpg")
        match = got == expected
        ok &= match
        print(f"  {'OK ' if match else 'FAIL'} {stem}: expected {expected}, got {got}")
    return ok


if __name__ == "__main__":
    print("Verifying against SkyColorExtractorTests.swift cross-check values:")
    sys.exit(0 if verify() else 1)
