# Building against a local `lean4/` tree

The default `make` flow downloads the host `.olean` archive from paulcadman's
GitHub release, addressed by the first 12 chars of `lean4/HEAD`. If your
`lean4` submodule points at a hash that has no published release — local
patches, a custom branch, an older tag — the download 404s and the build
fails. This guide builds the host Lean toolchain locally and stages it where
`Makefile.common` looks.

## 1. Prerequisites

In addition to the [root README](../README.md):

```
brew install cmake zstd ccache    # ccache optional, speeds up rebuilds
```

## 2. Build the host Lean toolchain

```
cd lean4
cmake -S . -B $HOME/gits/lean4-host-build -DUSE_GMP=OFF -DUSE_LIBUV=OFF
J=$(sysctl -n hw.logicalcpu)
cmake --build $HOME/gits/lean4-host-build         --target stage0           -j$J
cmake --build $HOME/gits/lean4-host-build         --target stage1-configure -j$J
cmake --build $HOME/gits/lean4-host-build/stage1                            -j$J
```

About 25–40 minutes on an M-series Mac. Verify:

```
$HOME/gits/lean4-host-build/stage1/bin/lean --version
```

`USE_GMP=OFF` and `USE_LIBUV=OFF` match the iOS runtime so the resulting
oleans share the `flags` byte the on-device kernel expects.

## 3. Stage the host oleans where the Makefile looks

```
cd ..   # back to repo root
HASH=$(git -C lean4 rev-parse --short=12 HEAD)
CACHE=build/host-oleans/ios-artifacts-v4.29.0-${HASH}
mkdir -p ${CACHE}/lean4-host-oleans-macos/lib
ln -sfn $HOME/gits/lean4-host-build/stage1/lib/lean ${CACHE}/lean4-host-oleans-macos/lib/lean

# Dummy archive older than the extract stamp so make doesn't redownload
mkdir -p build/downloads
touch -t 197001010000 build/downloads/lean4-host-oleans-macos-${HASH}.tar.zst
touch ${CACHE}/.extract-stamp
```

## 4. Build and run

The build invokes `lake`, which uses whichever `lean` is on `PATH`. Point at
the freshly built one (your elan-managed system Lean won't match):

```
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export PATH=$HOME/gits/lean4-host-build/stage1/bin:/opt/homebrew/bin:$PATH

cd projects/elaborator
make
```

Install and launch as usual:

```
APP=$(pwd)/../../build/ios-elab-app-arm64_apple_ios16_0_simulator/LeanIOSRunner.app
xcrun simctl install booted "$APP"
xcrun simctl launch  booted dev.paulcadman.LeanIOSRunner
```

## Lean ≥ 4.30 source-level patches

Two changes are committed locally to make the elaborator project build against
4.30+:

- `projects/elaborator/lean/Runner.lean` — `set_option
  compiler.ignoreBorrowAnnotation true in` before `@[export checkLeanSource]`.
  4.30 made this opt-in for `@&` parameters on `@[export]` declarations.
- `scripts/ios-ar.sh` — expands `@response-file` arguments inline before
  invoking `xcrun ar`. Lake 4.30 emits rsp files; Apple's `ar` doesn't grok
  them.

If you bump `lean4` further you may hit additional drift; same recipe — fix
the file, rerun `make`.

## Olean version-string compatibility

The on-device olean loader compares the 1-byte `version` field (currently `2`)
and the 1-byte `flags` field (bit 0 = GMP); the human-readable version string
(`"4.30.0"` vs `"4.30.0-pre"`) is not enforced unless the kernel was built
with `LEAN_CHECK_OLEAN_VERSION` defined (it isn't, by default). It is fine to
mix oleans produced by stage0 (`4.30.0-pre`) and stage1 (`4.30.0`) inside the
same bundle.

## Bundling third-party oleans (mathlib, NNG, …)

The default elaborator ships only Init/Std/Lean/Lake. To run code that
imports mathlib, NNG, etc. on-device:

1. Build the package against the same host Lean (e.g. clone mathlib4, delete
   its `lean-toolchain`, run `lake build` with the host bin on `PATH`).
2. Compute the transitive olean closure of the source you want to elaborate.
   `lean --deps file.lean` lists direct imports; recurse to get the full
   closure.
3. Copy each module's olean family — `.olean`, `.olean.private`,
   `.olean.server`, `.ir`, `.ilean` — into
   `LeanIOSRunner.app/lib/lean/<Module/Path>/`.
4. `touch LeanIOSRunner.app/.lean-lib-stamp` so the next `make` doesn't
   `rsync --delete` your additions away.

Bundle size grows quickly: ~2 GiB for the core; +35 mathlib oleans for a
single tactic-heavy import.
