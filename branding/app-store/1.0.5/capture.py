#!/usr/bin/env python3
"""Capture actual DEBUG UI on a dedicated simulator; no backend or real user data."""
import pathlib, subprocess, sys, time
udid = sys.argv[1]
root = pathlib.Path(__file__).resolve().parent
fixtures = root.parents[2] / "ios/SkyGrid/Tests/Fixtures"
shots = [("today", "light"), ("camera-review", "light"), ("grid", "light"), ("buddies", "dark"), ("reward-peak", "light"), ("share-morning", "dark"), ("today", "dark")]
def run(*args):
    return subprocess.run(["xcrun", "simctl", *args], check=True, capture_output=True, text=True, timeout=90)
for scenario, appearance in shots:
    subprocess.run(["xcrun", "simctl", "terminate", udid, "com.takmin.skygrid"], capture_output=True)
    run("ui", udid, "appearance", appearance)
    run("launch", udid, "com.takmin.skygrid", "-SkyGridUIAudit", "-SkyGridUIAuditScenario", scenario, "-SkyGridStorePhotoDirectory", str(fixtures))
    time.sleep(3)
    run("io", udid, "screenshot", str(root / "raw" / f"{scenario}-{appearance}.png"))
    print(f"Captured {scenario}-{appearance}", flush=True)
