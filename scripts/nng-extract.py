#!/usr/bin/env python3
"""Extract NNG4 level content into data for the iOS app.

Walks the active game graph (Game.lean -> world files -> level modules),
parses each level file textually (string/comment aware, no Lean needed) and
emits:

  --emit-json FILE   nng-levels.json: worlds -> ordered levels with title,
                     statement signature, prose, hints, inventory unlocks,
                     canonical solution, plus a global inventory-docs table.
  --emit-tests DIR   one .lean file per level: the canonical solution as an
                     `example` under the shared maximal header `import Game`
                     (D2), for the host/simulator sweep harnesses.

Usage: scripts/nng-extract.py [--nng4 DIR] [--emit-json F] [--emit-tests D]
"""

import argparse
import json
import re
import sys
from pathlib import Path

HOME = Path.home()
DEF_NNG4 = HOME / "gits/NNG4"

IMPORT_RE = re.compile(r"^import\s+([\w.«»]+)")
IDENT_RE = re.compile(r"[A-Za-z_«][A-Za-z0-9_'.«»]*")

STR_CMDS = ("World", "Level", "Title", "TheoremTab", "Introduction", "Conclusion")
IDENTS_CMDS = ("NewTactic", "NewHiddenTactic", "NewTheorem", "NewDefinition",
               "DisabledTactic", "DisabledTheorem")


def scan_string(text: str, i: int) -> tuple[str, int]:
    """text[i] == '"'; return (contents, index after closing quote)."""
    assert text[i] == '"'
    i += 1
    out = []
    while i < len(text):
        c = text[i]
        if c == "\\":
            nxt = text[i + 1]
            out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(nxt, "\\" + nxt))
            i += 2
        elif c == '"':
            return "".join(out), i + 1
        else:
            out.append(c)
            i += 1
    raise ValueError("unterminated string")


def skip_ws_comments(text: str, i: int) -> int:
    while i < len(text):
        if text[i].isspace():
            i += 1
        elif text.startswith("--", i):
            j = text.find("\n", i)
            i = len(text) if j < 0 else j
        elif text.startswith("/--", i):
            return i  # doc comment: significant, not skippable whitespace
        elif text.startswith("/-", i):
            depth = 1
            i += 2
            while i < len(text) and depth:
                if text.startswith("/-", i):
                    depth += 1
                    i += 2
                elif text.startswith("-/", i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
        else:
            return i
    return i


def read_doc_comment(text: str, i: int) -> tuple[str, int]:
    """text[i:] starts with '/--'; return (contents, index after '-/')."""
    j = text.find("-/", i)
    return text[i + 3:j].strip(), j + 2


class LevelParser:
    """One pass over a level (or world) file, collecting game commands."""

    def __init__(self, path: Path):
        self.path = path
        self.text = path.read_text(encoding="utf-8")
        self.data = {
            "imports": [], "preamble": [], "hints": [],
            "newTactics": [], "newTheorems": [], "newDefinitions": [],
            "disabledTactics": [], "disabledTheorems": [],
            "docs": [],  # (kind, name, displayName, category, content)
        }
        self.parse()

    def next_string(self, i: int) -> tuple[str, int]:
        i = skip_ws_comments(self.text, i)
        if i >= len(self.text) or self.text[i] != '"':
            raise ValueError(f"{self.path}: expected string at {i}")
        return scan_string(self.text, i)

    def parse(self):
        text, d = self.text, self.data
        i = 0
        pending_doc = None
        while i < len(text):
            j = skip_ws_comments(text, i)
            if j >= len(text):
                break
            # remember a doc comment that directly precedes the next command
            if text.startswith("/--", j):
                pending_doc, i = read_doc_comment(text, j)
                continue
            i = j
            m = IDENT_RE.match(text, i)
            if not m:
                i += 1
                continue
            word = m.group(0)
            i = m.end()
            if word == "import":
                m2 = IMPORT_RE.match(text[j:text.find("\n", j) if text.find("\n", j) > 0 else len(text)])
                if m2:
                    d["imports"].append(m2.group(1))
                i = text.find("\n", i)
                i = len(text) if i < 0 else i
            elif word in ("namespace", "open"):
                eol = text.find("\n", i)
                eol = len(text) if eol < 0 else eol
                d["preamble"].append((word + text[i:eol]).rstrip())
                i = eol
            elif word == "Level":
                m2 = re.match(r"\s*(\d+)", text[i:])
                d["level"] = int(m2.group(1))
                i += m2.end()
            elif word in STR_CMDS and word != "Level":
                s, i = self.next_string(i)
                key = {"World": "world", "Title": "title", "TheoremTab": "theoremTab",
                       "Introduction": "introduction", "Conclusion": "conclusion"}[word]
                d[key] = s
            elif word in IDENTS_CMDS:
                eol = text.find("\n", i)
                eol = len(text) if eol < 0 else eol
                names = [n.strip("«»") for n in IDENT_RE.findall(text[i:eol])]
                key = {"NewTactic": "newTactics", "NewHiddenTactic": "newTactics",
                       "NewTheorem": "newTheorems", "NewDefinition": "newDefinitions",
                       "DisabledTactic": "disabledTactics",
                       "DisabledTheorem": "disabledTheorems"}[word]
                d[key].extend(names)
                i = eol
            elif word in ("TacticDoc", "TheoremDoc", "DefinitionDoc", "LemmaDoc"):
                m2 = IDENT_RE.search(text, i)
                name = m2.group(0)
                i = m2.end()
                display = category = None
                eol = text.find("\n", i)
                head = text[i:eol if eol > 0 else len(text)]
                if word in ("TheoremDoc", "DefinitionDoc", "LemmaDoc"):
                    dm = re.match(r'\s*as\s*"', head)
                    if dm:
                        display, i = scan_string(text, i + dm.end() - 1)
                        cm = re.match(r'\s*in\s*"', text[i:])
                        if cm:
                            category, i = scan_string(text, i + cm.end() - 1)
                d["docs"].append({
                    "kind": word, "name": name, "displayName": display,
                    "category": category, "content": pending_doc or ""})
                pending_doc = None
            elif word == "Statement":
                self.parse_statement(i, pending_doc)
                pending_doc = None
                return  # statement is last thing we need; prose after is Conclusion
                # (handled below by re-scan)
            else:
                # skip to end of line for anything else (macro defs, set_option, …)
                eol = text.find("\n", i)
                i = len(text) if eol < 0 else eol
            if word != "Statement":
                pending_doc = None

    def parse_statement(self, i: int, doc: str | None):
        text, d = self.text, self.data
        d["statementDoc"] = doc or ""
        # optional name
        j = skip_ws_comments(text, i)
        m = IDENT_RE.match(text, j)
        name = None
        if m and not text.startswith("(", j) and not text.startswith(":", j) and \
           not text.startswith("{", j) and not text.startswith("[", j) and \
           not text.startswith("⦃", j):
            # an ident directly followed by more sig is a binder only if the
            # statement is named; upstream treats first ident as the name
            name = m.group(0)
            j = m.end()
        d["statementName"] = name
        # signature: up to top-level `:= by`, string-aware
        sig_start = j
        while j < len(text):
            if text[j] == '"':
                _, j = scan_string(text, j)
            elif text.startswith("--", j):
                nl = text.find("\n", j)
                j = len(text) if nl < 0 else nl
            elif text.startswith("/--", j):
                _, j = read_doc_comment(text, j)
            elif text.startswith("/-", j):
                j = skip_ws_comments(text, j)
            elif text.startswith(":=", j):
                break
            else:
                j += 1
        d["statementSig"] = re.sub(r"\s+\n", "\n", text[sig_start:j].strip())
        m2 = re.match(r":=\s*by[ \t]*\n?", text[j:])
        if not m2:
            raise ValueError(f"{self.path}: Statement without ':= by'")
        j += m2.end()
        # proof body: lines until a column-0 command while not inside a string
        proof_lines = []
        while j < len(text):
            eol = text.find("\n", j)
            eol = len(text) if eol < 0 else eol
            line = text[j:eol]
            if line and not line[0].isspace():
                # column-0 token outside any string: end of proof — but only
                # if we're at a genuine line start (scan_string consumed
                # multi-line strings wholesale, so we are)
                break
            # consume any strings on this line so multi-line Hint text with
            # column-0 content doesn't fake a proof end
            k = j
            while k < eol:
                if text[k] == '"':
                    _, k = scan_string(text, k)
                    eol = text.find("\n", k)
                    eol = len(text) if eol < 0 else eol
                elif text.startswith("--", k):
                    k = eol
                else:
                    k += 1
            line = text[j:eol]
            proof_lines.append(line)
            j = eol + 1
        # trim trailing blank lines
        while proof_lines and not proof_lines[-1].strip():
            proof_lines.pop()
        d["proof"] = "\n".join(proof_lines)
        # collect hints from the proof body
        for hm in re.finditer(r"^(\s*)Hint(\s*\((?:strict|hidden)\s*:=\s*\w+\))?\s*\"",
                              d["proof"], re.M):
            s, _ = scan_string(d["proof"], hm.end() - 1)
            d["hints"].append({"text": s, "hidden": "hidden" in (hm.group(2) or "")})
        # conclusion appears after the proof; scan the remainder
        rest = text[j:]
        cm = re.search(r"^Conclusion\s*", rest, re.M)
        if cm:
            k = skip_ws_comments(rest, cm.end())
            if k < len(rest) and rest[k] == '"':
                d["conclusion"], _ = scan_string(rest, k)


def module_path(nng4: Path, module: str) -> Path:
    return nng4 / (module.replace(".", "/") + ".lean")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--nng4", default=str(DEF_NNG4))
    ap.add_argument("--emit-json", default=None)
    ap.add_argument("--emit-tests", default=None)
    ap.add_argument("--worlds", default=None,
                    help="comma-separated world module suffixes to include "
                         "(e.g. 'Tutorial,Addition'); default: all")
    args = ap.parse_args()
    nng4 = Path(args.nng4).resolve()

    game = LevelParser(nng4 / "Game.lean")
    world_modules = [m for m in game.data["imports"] if m.startswith("Game.Levels.")]
    if args.worlds:
        wanted = {w.strip() for w in args.worlds.split(",")}
        world_modules = [m for m in world_modules if m.split(".")[-1] in wanted]

    worlds = []
    all_docs = []
    for wm in world_modules:
        wp = LevelParser(module_path(nng4, wm))
        all_docs.extend(wp.data["docs"])
        levels = []
        for lm in wp.data["imports"]:
            if not lm.startswith("Game.Levels."):
                continue
            lp = LevelParser(module_path(nng4, lm))
            ld = lp.data
            all_docs.extend(ld["docs"])
            if "level" not in ld:
                print(f"warning: {lm} has no Level command, skipped", file=sys.stderr)
                continue
            levels.append({
                "module": lm,
                "level": ld["level"],
                "title": ld.get("title", ""),
                "world": ld.get("world", wp.data.get("world", "")),
                "statementName": ld["statementName"],
                "statementSig": ld["statementSig"],
                "statementDoc": ld["statementDoc"],
                "introduction": ld.get("introduction", ""),
                "conclusion": ld.get("conclusion", ""),
                "preamble": ld["preamble"],
                "proof": ld["proof"],
                "hints": ld["hints"],
                "newTactics": ld["newTactics"],
                "newTheorems": ld["newTheorems"],
                "newDefinitions": ld["newDefinitions"],
                "disabledTactics": ld["disabledTactics"],
                "theoremTab": ld.get("theoremTab"),
            })
        levels.sort(key=lambda l: l["level"])
        worlds.append({
            "id": wp.data.get("world", wm.split(".")[-1]),
            "title": wp.data.get("title", ""),
            "introduction": wp.data.get("introduction", ""),
            "levels": levels,
        })

    n_levels = sum(len(w["levels"]) for w in worlds)
    print(f"{len(worlds)} worlds, {n_levels} levels, {len(all_docs)} doc entries",
          file=sys.stderr)

    if args.emit_json:
        docs_table = {}
        for doc in all_docs:
            docs_table.setdefault(doc["kind"], {})[doc["name"]] = {
                "displayName": doc["displayName"],
                "category": doc["category"],
                "content": doc["content"],
            }
        out = {"worlds": worlds, "docs": docs_table}
        Path(args.emit_json).write_text(
            json.dumps(out, indent=1, ensure_ascii=False, sort_keys=True))
        print(f"wrote {args.emit_json}", file=sys.stderr)

    if args.emit_tests:
        tdir = Path(args.emit_tests)
        tdir.mkdir(parents=True, exist_ok=True)
        for w_idx, w in enumerate(worlds):
            for l in w["levels"]:
                fname = f"W{w_idx+1:02d}L{l['level']:02d}_{l['module'].split('.')[-1]}.lean"
                preamble = "\n".join(l["preamble"]) or "namespace MyNat"
                src = (f"import Game\n\n{preamble}\n\n"
                       f"example {l['statementSig']} := by\n{l['proof']}\n")
                (tdir / fname).write_text(src)
        print(f"wrote {n_levels} test files to {tdir}", file=sys.stderr)


if __name__ == "__main__":
    main()
