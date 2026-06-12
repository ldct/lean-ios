#!/usr/bin/env python3
"""Drive the elaborator app in the iOS simulator.

Subcommands (run from anywhere):
  launch                  build + install + launch via `make run-sim-app`
  relaunch                terminate + launch (no rebuild)
  ui [filter]             print accessibility tree as `label @ (x, y, w, h)` lines,
                          optionally filtered by case-insensitive substring
  tap <x> <y>             tap at point coordinates
  tap-label <substring>   find element whose label/value contains substring, tap its center
  type <text>             type into the focused field (tap-label it first)
  ss <out.png>            screenshot the booted simulator
  flow <lesson-substring> <out.png>
                          from the home list: open a lesson row, tap through the
                          intro's "Start the proof", screenshot the exercise view

Requires: a booted simulator, `axe` (brew install cameroncooke/axe/axe).
"""
import json
import subprocess
import sys
import time
from pathlib import Path

ELAB_DIR = Path(__file__).resolve().parents[3]
BUNDLE_ID = "xuanji.lean-games"


def sh(*args, **kw):
    return subprocess.run(args, check=True, capture_output=True, text=True, **kw).stdout


def booted_udid():
    devices = json.loads(sh("xcrun", "simctl", "list", "devices", "booted", "-j"))["devices"]
    for runtime in devices.values():
        for d in runtime:
            if d["state"] == "Booted":
                return d["udid"]
    sys.exit("error: no booted simulator (run `launch` first, or `xcrun simctl boot <device>`)")


def axe(*args):
    return sh("axe", *args, "--udid", booted_udid())


def walk(node, out):
    # SwiftUI TextFields expose their placeholder as AXValue with no AXLabel
    label = node.get("AXLabel") or node.get("AXValue") or ""
    frame = node.get("frame")
    if label and frame:
        out.append((label, frame))
    for child in node.get("children") or []:
        walk(child, out)


def elements():
    tree = json.loads(axe("describe-ui"))
    out = []
    walk(tree[0] if isinstance(tree, list) else tree, out)
    return out


def find(substring):
    needle = substring.lower()
    matches = [(l, f) for l, f in elements() if needle in l.lower()]
    if not matches:
        sys.exit(f"error: no element labeled like {substring!r}")
    exact = [m for m in matches if m[0].lower() == needle]
    if exact:
        return exact[0]
    # substring can hit huge container nodes (e.g. "Run" ⊂ "LeanIOSRunner",
    # the full-screen app node) — the smallest match is the real control
    return min(matches, key=lambda m: m[1]["width"] * m[1]["height"])


def tap(x, y):
    axe("tap", "-x", str(x), "-y", str(y))
    time.sleep(1.5)


def tap_label(substring):
    label, f = find(substring)
    x, y = f["x"] + f["width"] / 2, f["y"] + f["height"] / 2
    print(f"tapping {label[:60]!r} at ({x:.0f}, {y:.0f})")
    tap(x, y)


def screenshot(path):
    sh("xcrun", "simctl", "io", "booted", "screenshot", path)
    print(f"wrote {path}")


def launch():
    subprocess.run(["make", "run-sim-app"], cwd=ELAB_DIR, check=True)
    time.sleep(2)


def relaunch():
    subprocess.run(["xcrun", "simctl", "terminate", "booted", BUNDLE_ID], capture_output=True)
    sh("xcrun", "simctl", "launch", "booted", BUNDLE_ID)
    time.sleep(2)


def main():
    cmd, *args = sys.argv[1:] or ["help"]
    if cmd == "launch":
        launch()
    elif cmd == "relaunch":
        relaunch()
    elif cmd == "ui":
        needle = args[0].lower() if args else ""
        for label, f in elements():
            if needle in label.lower():
                print(f"{label[:70]} @ ({f['x']:.0f}, {f['y']:.0f}, {f['width']:.0f}, {f['height']:.0f})")
    elif cmd == "tap":
        tap(float(args[0]), float(args[1]))
    elif cmd == "tap-label":
        tap_label(args[0])
    elif cmd == "type":
        axe("type", args[0])
        time.sleep(0.5)
    elif cmd == "ss":
        screenshot(args[0])
    elif cmd == "flow":
        lesson, out = args
        tap_label(lesson)
        tap_label("Start the proof")
        time.sleep(1.5)  # first runCheck() of a fresh exercise can take a moment
        screenshot(out)
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
