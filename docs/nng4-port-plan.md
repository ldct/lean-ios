# Porting the Natural Number Game (NNG4) to iOS

> **Status (2026-07-03):** Phases 0 and 1 are done; measurements below.
>
> - GameServer shim + `I18n` stub live in the NNG4 fork (`~/gits/NNG4`,
>   branch `ios`) under `gameserver-shim/`. All 9 worlds (114 modules) build
>   against Lean 4.30 host stage1 with **zero level-file changes** (one dead
>   `import ImportGraph` dropped in Algorithm L04).
> - `scripts/nng-build.py` compiles Game+shim with plain `lean` against the
>   prebuilt host Mathlib (`~/gits/mathlib4-for-paulcadman`), no lake
>   resolution. `scripts/olean-closure.py` stages the transitive closure:
>   366 modules / 185 MB (Game 111, Mathlib 53, Qq 14, importGraph 10,
>   full Batteries 175 to shadow the app's older Batteries rev).
> - Archive `nng-oleans-bfdeb998c96a-lean7ed217daee2b.tar.zst` (36 MB) is on
>   the `nng-oleans` release; `NNG_*` rules in `Makefile.common` mirror the
>   batteries flow. `make test-nng` runs the host sweep;
>   `native/App/NNGTestHarness.swift` runs the same sweep in the simulator
>   (launch with `SIMCTL_CHILD_NNG_TEST_DIR`/`_OUT`).
> - **Phase 0 exit:** all 8 Tutorial samples complete on host and simulator
>   (`nth_rewrite` + cross-level imports proven). **Phase 1 exit:** deepest
>   Algorithm header + `decide` completes in the sim (2.7 s cold, 251 MB).
> - **Simulator baselines:** per-level cold header import 0.7–4.3 s, warm
>   re-check ~0–7 ms; **each header *switch* leaks ~1 GB** (163 MB → 6.2 GB
>   over 5 distinct headers; flat when the header repeats) — fact 5
>   confirmed. Maximal shared header `import Game`: 2.8 s cold once,
>   252 MB flat, ~3 ms per level after. **D2 is decided: ship one shared
>   maximal header** (with the UI refusing the current level's own theorem);
>   per-level headers are not viable on device.

Plan for bringing [leanprover-community/NNG4](https://github.com/leanprover-community/NNG4)
into the `projects/elaborator` app, the same way
[Reintroduction to Proofs](https://adam.math.hhu.de/#/g/emilyriehl/reintroductiontoproofs)
was ported. The hard new requirement: NNG4 depends on Mathlib and on the
lean4game `GameServer` framework, so we must bundle third-party oleans and
elaborate against them on-device.

## Where we are today

- The elaborator app already elaborates arbitrary Lean source on-device
  against bundled oleans (`Init`/`Std`/`Lean`/`Lake` + Batteries, ~2.0 GiB in
  `lib/lean/`). The bridge, JSON goal protocol, and `done`-based completeness
  check are import-agnostic — nothing in `Runner.lean` or
  `LeanIOSBridge.cpp` needs to change for Mathlib-backed content.
- The Reintroduction port hard-codes ~60 levels as Swift `Exercise` structs in
  `native/App/App.swift`, each an import-free `example … := by done`. Prose
  and the tactic reference are also hard-coded Swift.
- A feasibility spike for NNG4 is already on disk (untracked):
  - `projects/elaborator/lean-samples/Tutorial/` — 8 Tutorial-world levels
    translated to plain `example`s with real `import Game.MyNat.…` headers.
  - `build/extra-oleans/` (51 MB) — hand-staged `Game/` modules plus a
    35-module `Mathlib/` slice, `Batteries/`, `ImportGraph/`. Staged into a
    built bundle manually per the recipe in
    [building-against-local-lean4.md](building-against-local-lean4.md)
    ("Bundling third-party oleans").
  - Gaps: `Game/Levels/Tutorial/*.olean` and `Mathlib/Tactic/NthRewrite.olean`
    are not in the staged set, so samples L03–L08 can't elaborate yet; nothing
    is wired into the Makefiles or the Swift UI.

## Key facts that shape the plan

1. **NNG4's Mathlib footprint is tiny.** NNG4 defines its own `MyNat` (with
   `ℕ` notation) and proves everything from scratch. Its only *active*
   Mathlib imports are `Mathlib.Tactic.NthRewrite` and `Mathlib.Tactic.Tauto`
   (`Game/Tactic/FromMathlib.lean`; ~200 more are deliberately commented out,
   and `Mathlib.Tactic.Ring` is explicitly excluded to protect the `MyNat`
   namespace). We bundle the transitive closure of the `Game` package, not
   Mathlib — expect tens of MB, not gigabytes. The spike's 35-olean / 34 MB
   slice confirms the order of magnitude.
2. **Oleans are host-portable, but the `flags` byte must match.** The
   on-device loader checks only the 1-byte olean `version` and the `flags`
   byte (bit 0 = GMP). The iOS runtime is built `USE_GMP=OFF USE_LIBUV=OFF`,
   so **Mathlib/NNG4 must be built from source with our host stage1 Lean**
   (same flags), *not* fetched from the community `lake exe cache get` cache
   (official toolchains have GMP on → flags mismatch). Building only the
   NNG4 closure keeps this cheap — we never build all of Mathlib.
3. **Only elaboration is needed, never native codegen.** Custom tactics
   (`Game.Tactic.*`, `nth_rewrite`, `tauto`) execute via the Lean IR
   interpreter from bundled `.ir` files; the bridge already enables
   initializer execution and `loadExts`. This is proven by the spike
   (`Game/Tactic/LabelAttr` attribute works from an olean).
4. **Version skew:** NNG4 pins `v4.23.0`; this repo pins `v4.29.0`
   (with local lean4 patches). Mathlib publishes a tag per Lean release, so
   the NNG4 fork bumps to `v4.29.0` + `mathlib @ v4.29.0`. Expect minor
   deprecation fixes in NNG4 sources.
5. **Memory constraint:** `Runner.lean` reuses the previous run's imported
   environment only when the *header* (import list) is unchanged
   (`lastSnapRef`). Re-importing while old compacted regions are still mapped
   degrades to heap copies that accumulate until reads fail on device. NNG4
   levels have *varying* headers, so level switches trigger re-imports —
   this is the main runtime risk to measure (see Phase 2).
6. **NNG4 content is machine-readable.** Levels are `Statement … := by …`
   blocks with `Hint`s, `Introduction`/`Conclusion` prose, and
   `NewTactic`/`NewTheorem` unlock declarations — everything the UI needs
   (including canonical solutions for testing) can be extracted from the
   sources instead of hand-translating ~150 levels across 9 worlds
   (Tutorial, Addition, Multiplication, Power, Implication, AdvAddition,
   LessOrEqual, AdvMultiplication, Algorithm).

## Decisions

### D1 — How to build the `Game` package: GameServer shim (recommended)

NNG4's level files `import GameServer` (for `Statement`, `Hint`, `World`,
`NewTactic`, …). Options:

- **(a) Shim GameServer (recommended).** Fork NNG4 and swap the `GameServer`
  dependency for a small local package that defines the same surface
  syntax with trivial semantics: `Statement` elaborates to a plain `theorem`,
  `Hint`/`Branch` become `skip`-like tactics, the metadata commands
  (`World`, `Level`, `Title`, `Introduction`, `Conclusion`, `NewTactic`,
  `NewTheorem`, `TacticDoc`, `TheoremDoc`, `DefinitionDoc`, `MakeGame`, …)
  become no-ops. Roughly 200–300 lines of macros. Level files stay
  byte-identical to upstream, so `import Game.Levels.Tutorial.L07add_succ`
  keeps working and rebasing on upstream NNG4 stays cheap.
- **(b) Real lean4game GameServer oleans.** Zero shim authoring, but pulls
  the whole server framework (plus its `i18n` dependency) into the on-device
  import closure, and its initializers may touch externs we compiled out
  (`USE_LIBUV=OFF`). More moving parts for no runtime benefit — the app
  never runs the game server.

Even with (a), we can still use the *real* lean4game on the **host** for
content extraction (D3) if convenient.

### D2 — Per-level import headers, measured before optimizing

Keep upstream per-level headers in v1 (each level imports exactly its
prerequisites, so a level can't `exact` its own theorem or use future
lemmas). Cost: a re-import on every level switch. Phase 2 measures whether
that is acceptable (time + the compacted-region accumulation from fact 5).
Fallback if it isn't: one shared maximal header per world (or per game) so
`lastSnapRef` reuse kicks in across levels, with the UI refusing `exact
<current level's theorem name>` to close the cheat hole. A `Restart proof`
action that doesn't change the header stays cheap either way.

### D3 — Content becomes data, not Swift code

Write an extractor (script over the NNG4 sources, or lean4game's build-time
JSON output) that emits a bundled `nng-levels.json`: per level — world, id,
title, statement-as-`example`, import header, namespace preamble,
introduction/conclusion prose, hints (static text in v1), unlocked tactics,
unlocked theorems, and the canonical solution (for the test harness only).
The Swift side grows a decoder and renders from data. The existing
Reintroduction levels can stay hard-coded or migrate later — out of scope.

### D4 — Distribution of the olean payload

Mirror the existing `batteries-oleans` pattern: build the closure locally,
publish it as a `nng-oleans-<rev>` archive on the `ldct/lean-ios` GitHub
release, and add download/extract/stage rules to
`projects/elaborator/Makefile.common` so `make sim-app` is reproducible on a
clean checkout (no more hand-staging + `touch .lean-lib-stamp`).

## Phases

### Phase 0 — Finish the feasibility spike (small)

1. Build the missing modules (`Mathlib.Tactic.NthRewrite` closure,
   `Game.Levels.Tutorial.*`) with the host stage1 Lean and stage them into
   the bundle by hand.
2. Get all 8 existing `lean-samples/Tutorial/*.lean` green through
   `tests/TestRunner.lean` in the simulator (this exercises `nth_rewrite`
   from Mathlib and cross-level theorem imports — the two novel mechanisms).
3. Record baseline numbers: import time for a Tutorial-level header (cold and
   warm), peak memory, bundle-size delta.

**Exit criterion:** an NNG4 Tutorial level using a Mathlib tactic elaborates
and completes on the simulator. This de-risks the whole project before any
infrastructure work.

### Phase 1 — Reproducible content build

1. Fork NNG4 (e.g. `ldct/NNG4-ios`): bump `lean-toolchain` to `v4.29.0`,
   pin `mathlib @ v4.29.0`, replace the GameServer require with the shim
   package (D1); fix whatever deprecations surface.
2. `lake build Game` with the host stage1 bin on `PATH` (per
   [building-against-local-lean4.md](building-against-local-lean4.md) §4).
3. `scripts/olean-closure.sh <root modules…>`: compute the transitive import
   closure (recurse `lean --deps`), copy each module's olean family into a
   staging tree, produce the `.tar.zst` archive. Investigate here which
   family members are truly needed at runtime (`.olean`, `.olean.private`,
   `.ir` certainly; `.ilean` is an editor index and likely droppable;
   `.olean.server` to be tested) — free size wins.
4. Publish the archive; add `NNG_OLEAN_*` download/extract/rsync-stamp rules
   to `Makefile.common` mirroring the `BATTERIES_*` rules.

**Exit criterion:** `make run-sim-app` on a clean checkout produces an app
where `import Game.Levels.Algorithm.L08` (the deepest header) elaborates.

### Phase 2 — Validation harness and performance gate

1. Extend the test runner with every NNG4 level's canonical solution
   (extracted from the `Statement` proof bodies) and run the full sweep in
   the simulator; triage failures (missing closure entries, interpreter
   externs, deprecated tactic behavior).
2. Measure per-level: header import time (cold/warm), per-tactic check
   latency, resident memory across a simulated "play through a world then
   switch worlds" session. This decides D2's fallback.
3. Same sweep on a physical iPhone: install size (~2.1 GiB app), memory
   headroom, thermal behavior on tactic-heavy levels (`decide` in Algorithm
   world, `tauto`).

**Exit criterion:** all ~150 canonical solutions pass on-device with
acceptable latency (target: < 2 s per tactic check warm, < 10 s cold header
import), no memory growth across a 30-level session.

### Phase 3 — Content pipeline

1. Build the extractor (D3) producing `nng-levels.json` + a theorem/tactic
   doc bundle from `TacticDoc`/`TheoremDoc` entries. NNG4's `.i18n/en`
   strings and level markdown give the prose.
2. Handle NNG-specific rendering details: `ℕ` = `MyNat`, the hidden preamble
   (`import …` + `namespace MyNat`) that the SOURCE pane must not show
   (the existing `displaySource` trailing-`done` trick generalizes to a
   hidden prefix), and statement pretty-printing for the level header.

### Phase 4 — UI

1. Load worlds/levels from `nng-levels.json` alongside the hard-coded
   Reintroduction game (two games on the root screen).
2. Per-level tactic chips driven by the accumulated `NewTactic` set; a
   theorem inventory tab driven by `NewTheorem` (this is a core NNG UI
   element — players apply named lemmas like `add_succ` constantly, so
   theorem chips that insert `rw [<name>]` matter as much as tactic chips).
3. Hints: v1 shows the level's static hints behind a "Hint" button.
   (Goal-matched progressive hints need GameServer's matching logic
   on-device — defer.)
4. Progress persistence per level (the existing app pattern), world map
   ordering per `Game.lean`'s dependency graph.

### Phase 5 — Ship & polish

1. Trim the bundle: drop `.ilean` (and `.olean.server` if Phase 1 shows
   they're unneeded), audit whether `Lake/` oleans (part of the 2 GiB core)
   are ever imported by app content.
2. Roll out worlds incrementally — Tutorial + Addition + Multiplication
   first, the rest once validated.
3. On-device QA pass with the `run-elaborator` skill / simulator driver.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Mathlib slice must be flags-compatible (GMP off) | High, but understood | Always build from source with host stage1; never `lake exe cache get`. Phase 0 proves it. |
| Compacted-region memory accumulation on level switches | High | Phase 2 measures; D2 fallback (shared world header) + possible `Runner.lean` work (explicitly release old snapshot before re-import). |
| Interpreter hits an `@[extern]` symbol compiled out of the iOS runtime (GMP/libuv paths in the Mathlib slice) | Medium | Full-closure import test in Phase 1; shim (D1a) keeps the closure minimal; worst case: patch the offending Mathlib module in the fork. |
| NNG4 doesn't build on v4.29 without changes | Medium | It's elementary Lean; budget for small fixes in the fork. Alternative: hold the whole repo at a version both support. |
| `tauto`/`decide` latency on device | Low–Medium | They operate on tiny `MyNat` goals; Phase 2 measures. |
| App size (~2.1 GiB) for distribution | Low (personal project) | Phase 5 trimming; App Store would need On-Demand Resources or core-olean pruning — out of scope for now. |
| Upstream NNG4 drift vs fork | Low | Shim keeps level files unmodified → rebases are mechanical. |

## Open questions

- Which olean family members does on-device elaboration actually read in
  v4.29's module system (`.olean.private` vs `.olean.server`)? Decides real
  payload size. (Phase 1.3)
- Is per-level header re-import fast enough on an iPhone, and does region
  reuse hold across header *changes*? (Phase 2.2 — decides D2)
- Do we want the three in-development worlds (EvenOdd, Prime,
  StrongInduction) — they're commented out upstream?
