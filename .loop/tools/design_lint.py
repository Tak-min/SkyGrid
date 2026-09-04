#!/usr/bin/env python3
"""Deterministic design-conformance lint for ios/SkyGrid/Sources.

Tier A only (per the 2026-09-04 Opus architecture consult, see
.loop/codex-handoff-log.md "Item 3"): counts, not opinions. No screenshots,
no LLM judgment. Reports counts of likely violations per category per file,
plus a delta against the previous run's .loop/design-lint.json.

Deliberately biased toward under-reporting (false negatives) over
over-reporting (false positives) per the Opus consult's own guidance -- a
noisy linter burns batches on nothing. Category 1 (emoji) is reported as
"needs_review" rather than "violation" because static analysis can't
reliably tell structural iconography from an inline text flourish.

Usage: python3 .loop/tools/design_lint.py [--write]
  --write   persist this run as the new .loop/design-lint.json baseline
            (default: dry run, prints the report and the delta vs the
            existing baseline without overwriting it)
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SOURCES = REPO_ROOT / "ios" / "SkyGrid" / "Sources"
BASELINE_PATH = REPO_ROOT / ".loop" / "design-lint.json"

DESIGN_SYSTEM_DIR_NAMES = {"DesignSystem"}

EMOJI_RE = re.compile(
    "[\U0001F300-\U0001FAFF\U00002600-\U000027BF\U0001F1E6-\U0001F1FF]"
)

RAW_COLOR_RE = re.compile(
    r"\bColor\s*\(\s*(?:\.sRGB|\.displayP3|red:|\"#|#)"
    r"|\bColor\.(red|blue|green|yellow|orange|purple|pink|gray|black|white|brown|mint|teal|indigo|cyan)\b"
    r"|\bUIColor\s*\("
)

SPACING_LITERAL_RE = re.compile(
    r"\.padding\(\s*[\d.]+\s*\)"
    r"|\.padding\(\.\w+,\s*[\d.]+\s*\)"
    r"|spacing:\s*[\d.]+\b"
    r"|\.frame\([^)]*(?:width|height|minWidth|minHeight):\s*[\d.]+"
)

FONT_LITERAL_RE = re.compile(
    r"\.font\(\s*\.system\(\s*size:\s*[\d.]+"
    r"|\.font\(\s*\.system\(size:\s*[\d.]+"
)

GLASS_PANEL_RE = re.compile(r"\.ultraThinMaterial")
STROKE_BORDER_RE = re.compile(r"strokeBorder")

BUTTON_BLOCK_RE = re.compile(r"Button\s*(?:\([^)]*\))?\s*\{", re.MULTILINE)


def iter_swift_files():
    for path in SOURCES.rglob("*.swift"):
        if "Tests" in path.parts:
            continue
        yield path


def is_design_system_file(path: Path) -> bool:
    return any(part in DESIGN_SYSTEM_DIR_NAMES for part in path.parts)


def count_matches(pattern: re.Pattern, text: str) -> int:
    return len(pattern.findall(text))


def find_icon_only_buttons_without_label(text: str) -> int:
    violations = 0
    for match in BUTTON_BLOCK_RE.finditer(text):
        start = match.end() - 1
        depth = 0
        end = None
        for i in range(start, min(len(text), start + 4000)):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
                if depth == 0:
                    end = i
                    break
        if end is None:
            continue
        block = text[start:end]
        tail = text[end : end + 200]
        if "Image(systemName:" not in block:
            continue
        if "Text(" in block:
            continue
        if ".accessibilityLabel" in block or ".accessibilityLabel" in tail:
            continue
        violations += 1
    return violations


def main():
    write = "--write" in sys.argv

    per_file: dict[str, dict[str, int]] = {}
    totals = {
        "emoji_needs_review": 0,
        "raw_color": 0,
        "spacing_literal": 0,
        "font_literal": 0,
        "glass_panel_files": 0,
        "icon_only_button_missing_label": 0,
    }
    glass_panel_files: list[str] = []

    for path in sorted(iter_swift_files()):
        text = path.read_text(encoding="utf-8", errors="replace")
        rel = str(path.relative_to(REPO_ROOT))
        design_system = is_design_system_file(path)

        emoji = count_matches(EMOJI_RE, text)
        raw_color = 0 if design_system else count_matches(RAW_COLOR_RE, text)
        spacing = 0 if design_system else count_matches(SPACING_LITERAL_RE, text)
        font = 0 if design_system else count_matches(FONT_LITERAL_RE, text)
        icon_btn = find_icon_only_buttons_without_label(text)

        has_glass = bool(GLASS_PANEL_RE.search(text)) and bool(
            STROKE_BORDER_RE.search(text)
        )
        if has_glass:
            glass_panel_files.append(rel)

        file_counts = {
            "emoji_needs_review": emoji,
            "raw_color": raw_color,
            "spacing_literal": spacing,
            "font_literal": font,
            "icon_only_button_missing_label": icon_btn,
        }
        if any(file_counts.values()):
            per_file[rel] = file_counts
            for k, v in file_counts.items():
                totals[k] += v

    totals["glass_panel_files"] = len(glass_panel_files)

    report = {
        "totals": totals,
        "glass_panel_duplicate_files": sorted(glass_panel_files),
        "per_file": per_file,
        "files_scanned": len(list(iter_swift_files())),
        "note": (
            "Tier A deterministic lint. emoji_needs_review is flagged, not "
            "asserted as a violation, per the 2026-09-04 Opus consult "
            "(static analysis can't reliably tell structural iconography "
            "from inline text flourish)."
        ),
    }

    print(json.dumps({"totals": totals, "files_scanned": report["files_scanned"]}, indent=2))
    if glass_panel_files:
        print(f"\nFiles with duplicated .ultraThinMaterial + strokeBorder ({len(glass_panel_files)}):")
        for f in glass_panel_files:
            print(f"  - {f}")

    if BASELINE_PATH.exists():
        previous = json.loads(BASELINE_PATH.read_text())
        prev_totals = previous.get("totals", {})
        print("\nDelta vs previous run:")
        for k in totals:
            prev = prev_totals.get(k, 0)
            cur = totals[k]
            delta = cur - prev
            sign = "+" if delta > 0 else ""
            print(f"  {k}: {prev} -> {cur} ({sign}{delta})")
    else:
        print("\nNo previous baseline found -- this run establishes the first one.")

    if write:
        BASELINE_PATH.write_text(json.dumps(report, indent=2) + "\n")
        print(f"\nWrote baseline to {BASELINE_PATH}")
    else:
        print("\n(dry run -- pass --write to persist this as the new baseline)")


if __name__ == "__main__":
    main()
