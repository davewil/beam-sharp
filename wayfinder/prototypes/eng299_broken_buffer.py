#!/usr/bin/env python3
"""ENG-299 prototype: a broken buffer, tree-sitter against bsc.

PROTOTYPE -- a measurement, not a gate. Nothing runs it; its numbers are in
eng299-broken-buffer.md beside it.

The question: for an LSP's structural needs (the declarations in a file, the
function enclosing the cursor), is the tree-sitter grammar's parse of a buffer
the author is still typing good enough, with bsc run on save for diagnostics?

For every compiler/examples/**/*.bs outside exemplars/ it picks one clause
(the middle clause that is not the file's last declaration), breaks the file
five ways at that clause, and asks both parsers about the result.

  mid_identifier   delete from halfway through the body's first name to the end
                   of the body -- typing the body left to right
  unclosed_brace   delete the last `}` of the first clause, from the target on,
                   that has one
  half_head        keep `Name(` and the first pattern, delete the rest of the
                   clause
  dangling_arrow   delete the body, keep `->`
  no_signature     delete the target function's signature

Each tree-sitter result is classified against the unbroken file's tree:

  recovered   every declaration the edit did not touch is a top-level node of
              the same kind with the same source text, and the node at the
              cursor names the target function (no_signature: not asked)
  flagged     not recovered, and the tree carries an ERROR or MISSING node --
              the server can see it has a damaged parse
  silent      not recovered, and no ERROR or MISSING node -- a wrong tree that
              looks like a right one

Usage (from anywhere; bsc must be built with `rebar3 escriptize`):
    python3 wayfinder/prototypes/eng299_broken_buffer.py
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
EXAMPLES = REPO / "compiler" / "examples"
# ENG299_GRAMMAR points the measurement at a variant grammar directory, e.g. a
# copy with reserved words, without editing the shipped one.
GRAMMAR = Path(os.environ.get("ENG299_GRAMMAR",
                              REPO / "editor" / "tree-sitter-beam-sharp"))
BSC = REPO / "compiler" / "_build" / "default" / "bin" / "bsc"

DECLS = {"module_declaration", "type_alias", "record_declaration",
         "behaviour_declaration", "foreign_declaration", "import_declaration",
         "signature", "clause"}
BREAKS = ["mid_identifier", "unclosed_brace", "half_head", "dangling_arrow",
          "no_signature"]


# --- tree-sitter -------------------------------------------------------------

def ts_parse(path):
    r = subprocess.run(["tree-sitter", "parse", "-x", str(path)], cwd=GRAMMAR,
                       capture_output=True, text=True)
    out = r.stdout
    end = out.rfind("</source_file>")
    if end < 0:
        sys.exit(f"tree-sitter produced no tree for {path}:\n{r.stderr}")
    root = ET.fromstring(out[:end + len("</source_file>")])
    return r.returncode != 0, root


def line_starts(src):
    starts = [0]
    for i, b in enumerate(src):
        if b == 0x0A:
            starts.append(i + 1)
    return starts


def span(el, starts):
    s = starts[int(el.get("srow"))] + int(el.get("scol"))
    e = starts[int(el.get("erow"))] + int(el.get("ecol"))
    return s, e


def name_of(el):
    """The function a node names: a signature's or clause's name field, or an
    ERROR node's first function_name."""
    if el.tag in ("signature", "clause"):
        for c in el:
            if c.get("field") == "name":
                return "".join(c.itertext()).strip()
    if el.tag == "ERROR":
        fn = el.find(".//function_name")
        if fn is not None:
            return "".join(fn.itertext()).strip()
    return None


def top_level(root, src):
    starts = line_starts(src)
    nodes = []
    for el in root:
        if el.tag in DECLS or el.tag == "ERROR":
            s, e = span(el, starts)
            nodes.append({"kind": el.tag, "start": s, "end": e,
                          "text": src[s:e], "name": name_of(el), "el": el})
    return nodes, starts


# --- breaks ------------------------------------------------------------------

def first_name_leaf(el):
    for d in el.iter():
        if d.tag in ("lident", "uident") and len(d) == 0:
            if len("".join(d.itertext()).strip()) >= 2:
                return d
    return None


def make_breaks(src, nodes, starts):
    """-> {break: (broken_bytes, cursor, touched_starts, target_name)} or None."""
    decls = [n for n in nodes if n["kind"] in DECLS]
    cands = [i for i, n in enumerate(decls)
             if n["kind"] == "clause" and i < len(decls) - 1]
    if not cands:
        return None
    ti = cands[len(cands) // 2]
    t = decls[ti]
    name = t["name"]
    body = next((c for c in t["el"] if c.get("field") == "body"), None)
    out = {}

    def cut(s, e, touched, n=name):
        return (src[:s] + src[e:], s, touched, n)

    if body is not None:
        bs, be = span(body, starts)
        leaf = first_name_leaf(body)
        if leaf is not None:
            ls, le = span(leaf, starts)
            out["mid_identifier"] = cut(ls + (le - ls) // 2, be, {t["start"]})
        out["dangling_arrow"] = cut(bs, be, {t["start"]})

    pats = [c for c in t["el"] if c.tag == "pattern"]
    if pats:
        keep = span(pats[0], starts)[1]
    else:
        keep = t["start"] + t["text"].index(b"(") + 1
    out["half_head"] = cut(keep, t["end"], {t["start"]})

    order = list(range(ti, len(decls) - 1)) + list(range(0, ti))
    for i in order:
        d = decls[i]
        if d["kind"] == "clause" and b"}" in d["text"]:
            p = d["start"] + d["text"].rindex(b"}")
            out["unclosed_brace"] = cut(p, p + 1, {d["start"]}, d["name"])
            break

    sig = next((d for d in decls
                if d["kind"] == "signature" and d["name"] == name), None)
    if sig is not None:
        e = sig["end"] + 1 if src[sig["end"]:sig["end"] + 1] == b"\n" else sig["end"]
        out["no_signature"] = (src[:sig["start"]] + src[e:], sig["start"],
                               {sig["start"]}, None)
    return out


# --- classification ----------------------------------------------------------

def missing(want, have_keys, key):
    have = {}
    for k in have_keys:
        have[k] = have.get(k, 0) + 1
    lost = []
    for n in want:
        k = key(n)
        if have.get(k, 0) > 0:
            have[k] -= 1
        else:
            lost.append(n)
    return lost


def classify(clean_nodes, broken_nodes, has_error, cursor, removed, touched,
             name, broken_src):
    """Two levels. EXACT: each untouched declaration is a node of the same kind
    with the same source text. SYMBOLS: each is a node of the same kind naming
    the same function on the same line -- what an outline, go-to-definition and
    "which function am I in" read."""
    want = [n for n in clean_nodes
            if n["kind"] in DECLS and n["start"] not in touched]
    lost = missing(want, [(n["kind"], n["text"]) for n in broken_nodes],
                   lambda n: (n["kind"], n["text"]))

    def line_in_broken(n):
        s = n["start"] if n["start"] < cursor else n["start"] - removed
        return broken_src[:s].count(b"\n")

    sym_lost = missing(
        want,
        [(n["kind"], n["name"], broken_src[:n["start"]].count(b"\n"))
         for n in broken_nodes],
        lambda n: (n["kind"], n["name"], line_in_broken(n)))
    if name is None:
        enclosing = None
    else:
        before = [n for n in broken_nodes if n["start"] <= cursor]
        at = before[-1] if before else None
        enclosing = (at is not None and at["kind"] in ("clause", "ERROR")
                     and at["name"] == name)
    def verdict(l):
        if not l and enclosing is not False:
            return "recovered"
        return "flagged" if has_error else "silent"
    return verdict(lost), lost, verdict(sym_lost), sym_lost, len(want), enclosing


# --- bsc ---------------------------------------------------------------------

TERM = re.compile(rb"#\{([^\n]*)\}")


def first_diag(stdout):
    m = TERM.search(stdout)
    if not m:
        return None
    body = m.group(1).decode()
    tag = re.search(r"tag => (\w+)", body)
    line = re.search(r"line => (\d+)", body)
    return (tag.group(1) if tag else "?", int(line.group(1)) if line else None,
            len(TERM.findall(stdout)))


def run_bsc(cases, work):
    manifest = work / "manifest"
    results = work / "results"
    results.mkdir()
    with manifest.open("w") as m:
        for cid, c in cases.items():
            m.write(f"entry {cid}\n")
            for a in ["-o", str(work / "beams" / cid), "--diagnostics", "term",
                      "--src-root", str(c["root"]), str(c["moddir"])]:
                m.write(f"arg {a}\n")
            m.write("end\n")
            (work / "beams" / cid).mkdir(parents=True)
    subprocess.run([str(BSC), "--batch", str(manifest), str(results)],
                   capture_output=True)
    out = {}
    for cid in cases:
        status = (results / f"{cid}.status").read_text().strip()
        merged = (results / f"{cid}.stdout").read_bytes() + \
                 (results / f"{cid}.stderr").read_bytes()
        out[cid] = (status, first_diag(merged))
    return out


# --- main --------------------------------------------------------------------

def main():
    if not BSC.exists():
        sys.exit(f"no bsc at {BSC}: run `rebar3 escriptize` in compiler/")
    files = sorted(p for p in EXAMPLES.rglob("*.bs")
                   if "exemplars" not in p.relative_to(EXAMPLES).parts)
    work = Path(tempfile.mkdtemp(prefix="eng299-"))
    ignore = shutil.ignore_patterns("exemplars")
    cases, rows = {}, []
    clean_root = work / "clean"
    shutil.copytree(EXAMPLES, clean_root, ignore=ignore)
    for f in files:
        rel = f.relative_to(EXAMPLES)
        src = f.read_bytes()
        err, root = ts_parse(f)
        if err:
            sys.exit(f"the clean corpus file {rel} does not parse")
        nodes, starts = top_level(root, src)
        cid = f"clean-{len(cases)}"
        cases[cid] = {"root": clean_root, "moddir": clean_root / rel.parent}
        rows.append({"file": str(rel), "break": "clean", "cid": cid})
        breaks = make_breaks(src, nodes, starts) or {}
        for b in BREAKS:
            if b not in breaks:
                rows.append({"file": str(rel), "break": b, "na": True})
                continue
            broken, cursor, touched, name = breaks[b]
            cid = f"c{len(cases)}"
            root_dir = work / cid
            shutil.copytree(EXAMPLES, root_dir, ignore=ignore)
            (root_dir / rel).write_bytes(broken)
            b_err, b_root = ts_parse(root_dir / rel)
            b_nodes, _ = top_level(b_root, broken)
            verdict, lost, sym_verdict, sym_lost, kept, enclosing = classify(
                nodes, b_nodes, b_err, cursor, len(src) - len(broken),
                touched, name, broken)
            cases[cid] = {"root": root_dir, "moddir": root_dir / rel.parent}
            rows.append({"file": str(rel), "break": b, "cid": cid,
                         "verdict": verdict, "lost": lost,
                         "sym_verdict": sym_verdict, "sym_lost": sym_lost,
                         "kept": kept, "enclosing": enclosing,
                         "ts_error": b_err,
                         "cursor_line": broken[:cursor].count(b"\n") + 1})
    bsc = run_bsc(cases, work)

    NA_WHY = {"mid_identifier": "no name of two or more characters in the body",
              "unclosed_brace": "no clause holding `}` before the last declaration",
              "half_head": "no clause", "dangling_arrow": "no body",
              "no_signature": "the target function has no signature"}
    print("| file | break | exact tree | symbols | lost (exact) | enclosing fn | bsc first diagnostic | bsc diagnostics |")
    print("|---|---|---|---|---|---|---|---|")
    tally = {b: {"recovered": 0, "flagged": 0, "silent": 0, "na": 0} for b in BREAKS}
    sym_tally = {b: {"recovered": 0, "flagged": 0, "silent": 0, "na": 0} for b in BREAKS}
    bsc_tally = {}
    clean_bad = []
    for r in rows:
        if r["break"] == "clean":
            status, d = bsc[r["cid"]]
            if status != "0":
                clean_bad.append((r["file"], d))
            continue
        if r.get("na"):
            tally[r["break"]]["na"] += 1
            sym_tally[r["break"]]["na"] += 1
            print(f"| {r['file']} | {r['break']} | n/a: {NA_WHY[r['break']]} | | | | | |")
            continue
        tally[r["break"]][r["verdict"]] += 1
        sym_tally[r["break"]][r["sym_verdict"]] += 1
        status, d = bsc[r["cid"]]
        if d is None:
            diag, count = ("compiles" if status == "0" else f"exit {status}, no term"), 0
            bsc_tally[diag] = bsc_tally.get(diag, 0) + 1
        else:
            tag, line, count = d
            rel_line = "" if line is None else (
                " at the edit" if line == r["cursor_line"] else
                f" {line - r['cursor_line']:+d} lines from the edit")
            diag = f"`{tag}`{rel_line}"
            bsc_tally[tag] = bsc_tally.get(tag, 0) + 1
        enc = {None: "n/a", True: "yes", False: "no"}[r["enclosing"]]
        lost = ", ".join(f"{n['kind']} {n['name'] or ''}".strip() for n in r["lost"])
        mark = " (ERROR node)" if r["ts_error"] else ""
        verdict = r["verdict"] + (mark if r["verdict"] == "recovered" else "")
        sym = r["sym_verdict"] + (mark if r["sym_verdict"] == "recovered" else "")
        print(f"| {r['file']} | {r['break']} | {verdict} | {sym} | "
              f"{len(r['lost'])} of {r['kept']}: {lost} | {enc} | {diag} | {count} |")

    print()
    print(f"corpus: {len(files)} files; bsc on the clean corpus: "
          f"{len(files) - len(clean_bad)} compile")
    for f, d in clean_bad:
        print(f"  clean file did not compile: {f} {d}")
    print()
    for label, tab in (("exact tree", tally), ("symbols", sym_tally)):
        print(f"**{label}**\n")
        print("| break | recovered | flagged | silent | not applicable |")
        print("|---|---|---|---|---|")
        tot = {"recovered": 0, "flagged": 0, "silent": 0, "na": 0}
        for b in BREAKS:
            t = tab[b]
            for k in tot:
                tot[k] += t[k]
            print(f"| {b} | {t['recovered']} | {t['flagged']} | {t['silent']} | {t['na']} |")
        print(f"| **all** | {tot['recovered']} | {tot['flagged']} | {tot['silent']} | {tot['na']} |\n")
    print()
    print("bsc first diagnostic, by tag: " +
          ", ".join(f"{k} {v}" for k, v in sorted(bsc_tally.items())))
    print(f"\nscratch: {work}")


if __name__ == "__main__":
    main()
