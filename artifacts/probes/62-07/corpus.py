import re, sys, os, collections
ROOT = '/home/user/beam-sharp'
def snake(n):
    # same rule as artifacts/probes/62-06/alias.patch snake/2
    out = []
    for i, c in enumerate(n):
        prev = n[i-1] if i else None
        nxt = n[i+1] if i+1 < len(n) else '_'
        up = c.isupper()
        sep = up and prev is not None and ((prev.islower() or prev.isdigit()) or (prev.isupper() and nxt.islower()))
        out.append(('_' if sep else '') + c.lower())
    return ''.join(out)
# self-check of the rule on the examples in the brief
for w, e in [('New','new'),('GetById','get_by_id'),('HTTPGet','http_get'),('GetID','get_id'),('GetId','get_id'),('ToJson','to_json'),('Sha256Hash','sha256_hash')]:
    assert snake(w) == e, (w, snake(w), e)
files = []
for d, _, fs in os.walk(ROOT):
    if '/artifacts' in d or '/_build' in d or '/.git' in d: continue
    for f in fs:
        if f.endswith('.bs'): files.append(os.path.join(d, f))
mods = collections.defaultdict(list)   # module -> [(name, file)]
nsrc = 0
for p in sorted(files):
    t = open(p, encoding='utf-8').read()
    m = re.search(r'^module\s+([\w.]+)', t, re.M)
    if not m: continue
    nsrc += 1
    for sig in re.finditer(r'^public\b(.*?)$', t, re.M):
        # signature may spill onto following lines until the first '(' ... ')' pair closes; take 3 lines
        start = sig.start()
        chunk = t[start:start+300].split('\n\n')[0]
        n = re.search(r'\b([A-Z]\w*)\(', chunk)
        if n: mods[m.group(1)].append((n.group(1), p))
total = sum(len(v) for v in mods.values())
names = {n for v in mods.values() for n, _ in v}
print(f"B# source files with a module line: {nsrc}; modules: {len(mods)}; public fn declarations (regex): {total}; distinct names: {len(names)}")
# 1. collisions within one module's export set (arity ignored => upper bound; also report with arity-blind)
coll = []
for m, v in mods.items():
    g = collections.defaultdict(set)
    for n, _ in v: g[snake(n)].add(n)
    for s, ns in g.items():
        if len(ns) > 1: coll.append((m, s, sorted(ns)))
print(f"derived-name collisions inside a module (two DIFFERENT PascalCase names -> same snake): {len(coll)}")
for c in coll: print("   ", c)
# 2. alias vs an existing lowercase-emitted name: callback-lowered names (Init -> init etc.)
cb = {'Init':'init','HandleCall':'handle_call','HandleCast':'handle_cast','HandleInfo':'handle_info','HandleContinue':'handle_continue','Terminate':'terminate','CodeChange':'code_change','Start':'start'}
clash = [(m, n) for m, v in mods.items() for n, _ in v if n in cb and any(b.strip().startswith('behaviour') for b in [''])]
print("names that equal a GenServer/Supervisor/Application callback row (alias would clash IF the module declares the behaviour):")
for m, v in sorted(mods.items()):
    hit = sorted({n for n, _ in v if n in cb})
    if hit: print("   ", m, hit)
# 3. how many names are non-trivially cased (acronym runs of 2+ caps, digits)
acr = sorted(n for n in names if re.search(r'[A-Z]{2,}', n))
dig = sorted(n for n in names if re.search(r'\d', n))
print("names with a 2+ capital run:", acr)
print("names with digits:", dig)
# 4. same snake from different module names is fine; cross-check distinct->snake mapping injective over the whole corpus
g = collections.defaultdict(set)
for n in names: g[snake(n)].add(n)
print("corpus-wide non-injective snake images:", [(s, sorted(ns)) for s, ns in g.items() if len(ns) > 1])
# 5. single-word names: alias is just lowercase
single = [n for n in names if re.fullmatch(r'[A-Z][a-z0-9]*', n)]
print(f"single-word names (alias = plain lowercase): {len(single)} of {len(names)}")
print("sample mapping:", [(n, snake(n)) for n in sorted(names)[:0]] or sorted((n, snake(n)) for n in names if not re.fullmatch(r'[A-Z][a-z0-9]*', n))[:12])
