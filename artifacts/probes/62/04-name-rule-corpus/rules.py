import re, sys, collections
# Rule S1: "naive": '_' before every uppercase letter (except at start), lowercase everything.
def s1(n): return re.sub(r'(?<!^)([A-Z])', r'_\1', n).lower()
# Rule S2: acronym-aware, the shape Gleam 1.5.0 was measured to use for constructors (probe 03 section C):
#   boundary before an upper that follows a lower/digit, and before the last upper of an upper-run that precedes a lower.
def s2(n):
    out=[]
    for i,c in enumerate(n):
        if i>0 and c.isupper():
            p=n[i-1]; nx=n[i+1] if i+1<len(n) else ''
            if p.islower() or p.isdigit() or (p.isupper() and nx.islower()): out.append('_')
        out.append(c.lower())
    return ''.join(out)
names = collections.defaultdict(list)   # module -> [(name, arity)]
for line in sys.stdin:
    m, f, a = line.rstrip('\n').split('\t'); names[m].append((f, int(a)))
total = sum(len(v) for v in names.values())
print(f"modules={len(names)} exported author functions={total}")
diff=0
for m, fs in sorted(names.items()):
    for rule, fn in (('S1', s1), ('S2', s2)):
        by = collections.defaultdict(set)
        for f, a in fs: by[(fn(f), a)].add(f)
        for k, v in by.items():
            if len(v) > 1: print(f"COLLISION {rule} {m}: {sorted(v)} -> {k[0]}/{k[1]}")
for m, fs in sorted(names.items()):
    for f, a in fs:
        if s1(f) != s2(f): diff += 1; print(f"S1/S2 DIFFER in corpus: {m}:{f} S1={s1(f)} S2={s2(f)}")
print(f"names where S1 and S2 differ: {diff}")
# Names that would have to be derived and are not valid Erlang-snake: contain '_' already, or digits
us=[(m,f) for m,fs in names.items() for f,a in fs if '_' in f]
print("corpus names already containing '_':", us)
# synthetic probes of the rule's edge cases (B# ALNUM = [a-zA-Z0-9_], lexer line 16)
for f in ['GetHTTPServer','ParseURL','ParseUrl','ABC','Abc','Get2D','Get_Value','GetValue','Get_value','F1','F_1','Init','HandleCall','HTTP','Http']:
    print(f"  {f:14} S1={s1(f):20} S2={s2(f)}")
syn = ['ABC','Abc','Get_Value','GetValue','ParseURL','ParseUrl']
for rule, fn in (('S1',s1),('S2',s2)):
    by = collections.defaultdict(list)
    for f in syn: by[fn(f)].append(f)
    print(rule, "synthetic collisions:", {k:v for k,v in by.items() if len(v)>1})
