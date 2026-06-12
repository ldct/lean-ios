---
name: run-elaborator
description: Build, run, and drive the elaborator iOS app in the simulator. Use when asked to run or launch the app, take screenshots of its UI, tap through lessons, run tactics, or verify a UI change in the simulator.
---

iOS app (SwiftUI + embedded Lean elaborator) that runs in the iOS simulator.
Drive it via `.claude/skills/run-elaborator/driver.py` — it wraps `make
run-sim-app`, `xcrun simctl`, and `axe` (simulator touch/keyboard injection)
into launch / tap-by-label / type / screenshot subcommands.

All paths below are relative to `projects/elaborator/`.

## Prerequisites

macOS with Xcode and an iOS simulator runtime (verified with Xcode 26.3,
iPhone 17 Pro / iOS 26.3). For UI driving:

```bash
brew install cameroncooke/axe/axe   # tap/type/describe-ui for simulators; no macOS accessibility permission needed
```

The Lean static libraries must already exist in `../../build/` (built once via
the repo-root `make`; slow). If `build/ios-lean-*/lib/libLean.a` exists, skip.

## Build + Run (agent path)

```bash
python3 .claude/skills/run-elaborator/driver.py launch
```

This runs `make run-sim-app`: recompiles the Lean runner + Swift app
(~seconds when only Swift changed), boots a simulator if none is booted,
installs, and launches bundle `xuanji.lean-games`. Then drive it:

| command | what it does |
|---|---|
| `launch` | build + install + launch via `make run-sim-app` |
| `relaunch` | terminate + relaunch installed app (no rebuild) |
| `ui [filter]` | print accessibility tree as `label @ (x, y, w, h)`, optionally filtered |
| `tap <x> <y>` | tap at point coordinates (not pixels) |
| `tap-label <substring>` | tap center of element whose label/value matches |
| `type <text>` | type into the focused field (`tap-label` it first) |
| `ss <out.png>` | screenshot the booted simulator |
| `flow <lesson> <out.png>` | from home list: open lesson → "Start the proof" → screenshot |

Verified end-to-end flow (home list → exercise → solve a proof):

```bash
D=.claude/skills/run-elaborator/driver.py
python3 $D flow "L02: Proofs" /tmp/l02.png   # opens lesson, taps "Start the proof", screenshots
python3 $D tap-label "next tactic"           # focus the tactic input field
python3 $D type "exact p"
python3 $D tap-label "Run"                   # STATE card flips to green "Proof complete"
python3 $D ss /tmp/l02-solved.png
python3 $D tap-label "Back"                  # returns to the home list
```

**Look at every screenshot you take** (Read the png). Screenshots land
wherever you point them; `/tmp/` is fine.

## Run (human path)

```bash
make run-sim-app   # builds, boots a simulator, opens Simulator.app, launches
```

## Test

```bash
ls tests/   # Lean-side tests exist; the UI has no test suite — verify via the driver
```

## Gotchas

- **Coordinates are points, not pixels.** `describe-ui` frames and `tap` use
  points (402×874 on iPhone 17 Pro); `simctl` screenshots are 3× (1206×2622).
  Don't derive tap targets from screenshot pixel positions — use `ui`.
- **`osascript`/System Events clicking fails** with "not allowed assistive
  access" — that's why `axe` is the driver, it injects HID events directly.
- **SwiftUI TextField placeholders are `AXValue`, not `AXLabel`** — the
  driver matches both, so `tap-label "next tactic"` works.
- **Substring label matches hit container nodes** (e.g. "Run" ⊂ the
  full-screen "LeanIOSRunner" app node). The driver prefers exact matches,
  then the smallest-area match.
- **The top bar back button sits at points (35, 81)** — `tap-label "Back"`
  finds it; don't guess coordinates under the status bar.
- **First `runCheck()` after opening an exercise takes a beat** (Lean
  elaborates the source) — the driver's `flow` sleeps 1.5 s before the
  screenshot; if STATE shows "Loading…", screenshot again.
- **`make run-sim-app` boots "iPhone 16" only if nothing is booted** — any
  already-booted simulator is reused (`simctl install/launch booted`).

## Troubleshooting

- **`error: no booted simulator`**: run the `launch` subcommand (its make
  target boots one), or `xcrun simctl boot "<device>" && open -a Simulator`.
- **`no element labeled like '…'`**: the view scrolled it off-screen or
  navigation didn't happen — run `ui` with no filter to see what's actually
  on screen, then re-navigate.
- **Tap lands but nothing happens**: you used pixel coordinates from a
  screenshot. Re-read the frame from `ui` (points) and tap that.
