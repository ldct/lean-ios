#!/usr/bin/env python3
"""Build the NNG4 `Game` package (plus the GameServer shim) with the host
stage1 Lean, without involving lake package resolution.

Mathlib and its dependency packages must already be host-built (same
USE_GMP=OFF / USE_LIBUV=OFF toolchain); their build dirs are put on
LEAN_PATH and treated as prebuilt. Only Game.* / GameServer.* / I18n
modules are compiled, in dependency order, into --out.

Usage:
  scripts/nng-build.py [--nng4 DIR] [--mathlib DIR] [--lean BIN] \
      [--out DIR] [-j N] ROOT_MODULE...

Example:
  scripts/nng-build.py Game.Levels.Tutorial
"""

import argparse
import concurrent.futures
import os
import re
import subprocess
import sys
import threading
from pathlib import Path

HOME = Path.home()
DEF_NNG4 = HOME / "gits/NNG4"
DEF_MATHLIB = HOME / "gits/mathlib4-for-paulcadman"
DEF_LEAN = HOME / "gits/lean4-host-build/stage1/bin/lean"

LEAN_OPTS = ["-Dlinter.all=false", "-Dtactic.hygienic=false", "-Dtrace.debug=false"]

IMPORT_RE = re.compile(r"^import\s+([\w.«»]+)")


def parse_imports(path: Path) -> list[str]:
    """Return the module header's imports (stops at the first real command)."""
    imports = []
    depth = 0  # block comment nesting
    for line in path.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if depth > 0:
            depth += s.count("/-") - s.count("-/")
            continue
        s = s.split("--", 1)[0].strip()  # drop line comments
        if not s or s in ("module", "prelude"):
            continue
        if s.startswith("/-"):
            depth = s.count("/-") - s.count("-/")
            continue
        m = IMPORT_RE.match(s)
        if m:
            imports.append(m.group(1))
            continue
        break  # first non-import command ends the header
    return imports


class Builder:
    def __init__(self, args):
        self.nng4 = Path(args.nng4).resolve()
        self.shim = self.nng4 / "gameserver-shim"
        self.mathlib = Path(args.mathlib).resolve()
        self.lean = Path(args.lean)
        self.out = Path(args.out or (self.nng4 / ".ios-build/lib/lean")).resolve()
        self.jobs = args.jobs
        self.deps: dict[str, list[str]] = {}  # module -> local (buildable) deps
        self.srcs: dict[str, tuple[Path, Path]] = {}  # module -> (root dir, source)
        self.lock = threading.Lock()
        self.failed = False

        libs = [str(self.out)]
        libs.append(str(self.mathlib / ".lake/build/lib/lean"))
        pkgs = self.mathlib / ".lake/packages"
        for p in sorted(pkgs.iterdir()) if pkgs.is_dir() else []:
            lib = p / ".lake/build/lib/lean"
            # proofwidgets et al. keep their libs in the same layout
            if not lib.is_dir():
                lib = p / "server/.lake/build/lib/lean"
            if lib.is_dir():
                libs.append(str(lib))
        self.lean_path = os.pathsep.join(libs)

    def locate(self, module: str) -> tuple[Path, Path] | None:
        """Map a buildable module name to (root dir, source file)."""
        rel = Path(module.replace(".", "/") + ".lean")
        if module == "Game" or module.startswith("Game."):
            src = self.nng4 / rel
            if not src.is_file():
                sys.exit(f"error: no source for module {module} (expected {src})")
            return self.nng4, src
        if module in ("GameServer", "I18n") or module.startswith("GameServer."):
            src = self.shim / rel
            if not src.is_file():
                sys.exit(f"error: no source for module {module} (expected {src})")
            return self.shim, src
        return None  # prebuilt (Init/Lean/Std/Mathlib/Batteries/...)

    def discover(self, module: str, stack=()):
        if module in self.deps:
            return
        if module in stack:
            sys.exit(f"error: import cycle: {' -> '.join(stack)} -> {module}")
        loc = self.locate(module)
        if loc is None:
            return
        root, src = loc
        self.srcs[module] = (root, src)
        local = []
        for imp in parse_imports(src):
            if self.locate(imp) is not None:
                local.append(imp)
                self.discover(imp, stack + (module,))
            # else: resolved from LEAN_PATH at compile time
        self.deps[module] = local

    def olean(self, module: str) -> Path:
        return self.out / (module.replace(".", "/") + ".olean")

    def needs_build(self, module: str) -> bool:
        out = self.olean(module)
        if not out.is_file():
            return True
        mtime = out.stat().st_mtime
        _, src = self.srcs[module]
        if src.stat().st_mtime > mtime:
            return True
        return any(self.olean(d).stat().st_mtime > mtime for d in self.deps[module])

    def compile(self, module: str) -> bool:
        root, src = self.srcs[module]
        out = self.olean(module)
        out.parent.mkdir(parents=True, exist_ok=True)
        ilean = out.with_suffix(".ilean")
        cmd = [str(self.lean), "-R", str(root), *LEAN_OPTS,
               str(src), "-o", str(out), "-i", str(ilean)]
        env = dict(os.environ, LEAN_PATH=self.lean_path)
        r = subprocess.run(cmd, env=env, capture_output=True, text=True)
        with self.lock:
            if r.returncode != 0:
                print(f"FAIL {module}\n{r.stdout}{r.stderr}", flush=True)
                if out.is_file():
                    out.unlink()  # don't leave a stale olean behind
                return False
            msg = (r.stdout + r.stderr).strip()
            print(f"OK   {module}" + (f"\n{msg}" if msg else ""), flush=True)
            return True

    def run(self, roots: list[str]) -> int:
        for m in roots:
            self.discover(m)
        order = list(self.deps)  # every discovered module
        pending = {m: set(self.deps[m]) for m in order}
        done: set[str] = set()
        running: set[str] = set()
        built = skipped = 0
        failed_any = False

        # A rebuilt dep bumps its olean mtime, so needs_build cascades to
        # dependents without explicit dirty tracking (deps are always done
        # before a module is scheduled).
        with concurrent.futures.ThreadPoolExecutor(max_workers=self.jobs) as ex:
            futures = {}
            while len(done) < len(order):
                if not failed_any:
                    for m in [m for m in order
                              if m not in done and m not in running and not pending[m]]:
                        running.add(m)
                        if self.needs_build(m):
                            futures[ex.submit(self.compile, m)] = m
                        else:
                            futures[ex.submit(lambda: None)] = m
                if not futures:
                    break
                fut = next(concurrent.futures.as_completed(futures))
                m = futures.pop(fut)
                res = fut.result()
                running.discard(m)
                done.add(m)
                if res is False:
                    failed_any = True
                elif res is True:
                    built += 1
                else:
                    skipped += 1
                for other in pending:
                    pending[other].discard(m)
        print(f"built {built}, up-to-date {skipped}, total {len(order)}")
        return 1 if failed_any else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--nng4", default=str(DEF_NNG4))
    ap.add_argument("--mathlib", default=str(DEF_MATHLIB))
    ap.add_argument("--lean", default=str(DEF_LEAN))
    ap.add_argument("--out", default=None)
    ap.add_argument("-j", "--jobs", type=int, default=os.cpu_count())
    ap.add_argument("roots", nargs="+")
    args = ap.parse_args()
    b = Builder(args)
    sys.exit(b.run(args.roots))


if __name__ == "__main__":
    main()
