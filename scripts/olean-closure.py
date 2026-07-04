#!/usr/bin/env python3
"""Compute the transitive import closure of Lean modules and stage their
olean families into a directory tree suitable for bundling into the iOS app
(lib/lean/<Module/Path>.olean...).

Core modules (Init/Lean/Std/Lake) are excluded — the app already bundles
them. Everything else (Game, GameServer shim, Mathlib slice, Batteries,
aesop, ...) is resolved from the search roots' source trees and copied from
their build dirs.

Usage:
  scripts/olean-closure.py [--nng4 DIR] [--mathlib DIR] [--out DIR]
      [--full-package NAME]... [--list-only] ROOT_MODULE...

--full-package batteries  additionally stages *every* built module of that
package (used to fully shadow the app's separately-versioned Batteries
bundle with the rev mathlib was built against).
"""

import argparse
import re
import shutil
import sys
from pathlib import Path

HOME = Path.home()
DEF_NNG4 = HOME / "gits/NNG4"
DEF_MATHLIB = HOME / "gits/mathlib4-for-paulcadman"

CORE_PREFIXES = ("Init", "Lean", "Std", "Lake")

# module-system aware: `public import`, `meta import`, `public meta import`,
# `import all Foo`, plus plain `import Foo`
IMPORT_RE = re.compile(
    r"^(?:public\s+)?(?:private\s+)?(?:meta\s+)?import\s+(?:all\s+)?([\w.«»]+)")

FAMILY_EXTS = [".olean", ".olean.private", ".olean.server", ".ir", ".ilean"]


def parse_imports(path: Path) -> list[str]:
    imports = []
    depth = 0
    for line in path.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if depth > 0:
            depth += s.count("/-") - s.count("-/")
            continue
        s = s.split("--", 1)[0].strip()  # drop line comments (incl. `module -- foo`)
        if not s or s in ("module", "prelude"):
            continue
        if s.startswith("/-"):
            depth = s.count("/-") - s.count("-/")
            continue
        m = IMPORT_RE.match(s)
        if m:
            imports.append(m.group(1))
            continue
        break
    return imports


class Pkg:
    def __init__(self, name: str, src_root: Path, build_lib: Path):
        self.name = name
        self.src_root = src_root
        self.build_lib = build_lib


def is_core(module: str) -> bool:
    top = module.split(".")[0]
    return top in CORE_PREFIXES


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--nng4", default=str(DEF_NNG4))
    ap.add_argument("--mathlib", default=str(DEF_MATHLIB))
    ap.add_argument("--out", default=None)
    ap.add_argument("--full-package", action="append", default=[])
    ap.add_argument("--list-only", action="store_true")
    ap.add_argument("roots", nargs="+")
    args = ap.parse_args()

    nng4 = Path(args.nng4).resolve()
    mathlib = Path(args.mathlib).resolve()

    pkgs: list[Pkg] = [
        Pkg("game", nng4, nng4 / ".ios-build/lib/lean"),
        Pkg("gameserver-shim", nng4 / "gameserver-shim", nng4 / ".ios-build/lib/lean"),
        Pkg("mathlib", mathlib, mathlib / ".lake/build/lib/lean"),
    ]
    pkg_dir = mathlib / ".lake/packages"
    for p in sorted(pkg_dir.iterdir()) if pkg_dir.is_dir() else []:
        src = p
        lib = p / ".lake/build/lib/lean"
        if not lib.is_dir() and (p / "server").is_dir():  # lean4game layout
            src = p / "server"
            lib = p / "server/.lake/build/lib/lean"
        if lib.is_dir():
            pkgs.append(Pkg(p.name, src, lib))

    def locate(module: str) -> tuple[Pkg, Path] | None:
        rel = Path(module.replace(".", "/") + ".lean")
        for pkg in pkgs:
            src = pkg.src_root / rel
            if src.is_file():
                return pkg, src
        return None

    closure: dict[str, Pkg] = {}

    def visit(module: str):
        if module in closure or is_core(module):
            return
        loc = locate(module)
        if loc is None:
            sys.exit(f"error: cannot find source for module {module}")
        pkg, src = loc
        closure[module] = pkg
        for imp in parse_imports(src):
            visit(imp)

    for root in args.roots:
        visit(root)

    # --full-package: add every built module of the named packages
    for name in args.full_package:
        pkg = next((p for p in pkgs if p.name == name), None)
        if pkg is None:
            sys.exit(f"error: unknown package {name}")
        for olean in pkg.build_lib.rglob("*.olean"):
            module = ".".join(olean.relative_to(pkg.build_lib).with_suffix("").parts)
            closure.setdefault(module, pkg)

    per_pkg: dict[str, int] = {}
    for m, p in closure.items():
        per_pkg[p.name] = per_pkg.get(p.name, 0) + 1
    print(f"{len(closure)} modules: " +
          ", ".join(f"{k}={v}" for k, v in sorted(per_pkg.items())), file=sys.stderr)

    if args.list_only:
        for m in sorted(closure):
            print(f"{closure[m].name:18} {m}")
        return

    out = Path(args.out or "build/nng-oleans-local/lib/lean").resolve()
    copied = missing = 0
    total_bytes = 0
    for module, pkg in sorted(closure.items()):
        rel = Path(module.replace(".", "/"))
        found_olean = False
        for ext in FAMILY_EXTS:
            src = pkg.build_lib / rel.parent / (rel.name + ext)
            if src.is_file():
                dst = out / rel.parent / (rel.name + ext)
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)
                copied += 1
                total_bytes += src.stat().st_size
                if ext == ".olean":
                    found_olean = True
        if not found_olean:
            print(f"MISSING olean: {module} (pkg {pkg.name})", file=sys.stderr)
            missing += 1
    print(f"staged {copied} files ({total_bytes / 1e6:.1f} MB) -> {out}; "
          f"{missing} modules missing oleans", file=sys.stderr)
    sys.exit(1 if missing else 0)


if __name__ == "__main__":
    main()
