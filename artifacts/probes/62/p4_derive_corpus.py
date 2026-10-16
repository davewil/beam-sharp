# 62 / P4 — how well does a mechanical PascalCase->snake_case derivation do on the repo's own corpus?
# Reads every `public ... Name(` signature in all .bs files; applies the two common deriver rules and
# reports names the rules disagree on, digits, and collisions within a module.
import re, sys, glob, collections
def rule_a(n):   # insert _ before each capital (naive)
    return re.sub(r'(?<!^)([A-Z])', r'_\1', n).lower()
def rule_b(n):   # keep acronym runs together (Gleam/serde style)
    s = re.sub(r'([A-Z]+)([A-Z][a-z])', r'\1_\2', n)
    s = re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', s)
    return s.lower()
sig = re.compile(r'^public\s+[^\n(]*?\b([A-Z][A-Za-z0-9]*)\s*\(', re.M)
names = collections.defaultdict(set); total = 0
for f in glob.glob('compiler/examples/**/*.bs', recursive=True) + glob.glob('aoc/**/*.bs', recursive=True) + glob.glob('handoff/**/*.bs', recursive=True):
    src = open(f, encoding='utf-8', errors='replace').read()
    mod = re.search(r'^module\s+([\w.]+)', src, re.M)
    for m in sig.finditer(src):
        names[mod.group(1) if mod else f].add(m.group(1))
allnames = sorted({n for s in names.values() for n in s})
print(f"files scanned: modules={len(names)} distinct public function names={len(allnames)}")
dis = [(n, rule_a(n), rule_b(n)) for n in allnames if rule_a(n) != rule_b(n)]
print(f"names where the two common rules DISAGREE: {len(dis)}")
for n, a, b in dis[:12]: print(f"   {n:24} naive={a:26} acronym-aware={b}")
dig = [n for n in allnames if re.search(r'\d', n)]
print(f"names containing a digit (Base64, Utf8 ...): {len(dig)}  e.g. {dig[:6]}")
for rule in (rule_a, rule_b):
    col = [(m, d) for m, ns in names.items() for d in [collections.Counter(rule(n) for n in ns)] if any(c > 1 for c in d.values())]
    print(f"{rule.__name__}: modules with an intra-module collision after derivation: {len(col)}")
# collision with an author-written reserved/OTP callback name: handle_call etc.
cb = {'init','handle_call','handle_cast','handle_info','terminate','code_change','start_link','child_spec'}
clash = sorted({n for n in allnames if rule_b(n) in cb})
print("derived names that equal an OTP callback / well-known export:", clash)
