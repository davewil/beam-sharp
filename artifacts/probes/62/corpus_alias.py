#!/usr/bin/env python3
# ticket 62: derive snake_case aliases for every public B# function in the repo's .bs corpus;
# report names whose alias is NOT the obvious one, or collides inside one file.
import re,sys,pathlib,collections
root=pathlib.Path(sys.argv[1])
sig=re.compile(r'^\s*public\s+[\w<>,\s\(\)\?\.]*?\b([A-Z]\w*)\s*\(')
def snake(n): # the Gleam-like rule: split before an uppercase that follows a lowercase/digit
    s=re.sub(r'(?<=[a-z0-9])(?=[A-Z])','_',n); return s.lower()
def snake2(n): # acronym-aware: HTTPServer -> http_server
    s=re.sub(r'([A-Z]+)([A-Z][a-z])',r'\1_\2',n); s=re.sub(r'(?<=[a-z0-9])(?=[A-Z])','_',s); return s.lower()
tot=0; files=0; diff=[]; coll=[]
for p in sorted(root.rglob('*.bs')):
    if 'artifacts' in p.parts: continue
    names=set()
    for l in p.read_text(errors='ignore').splitlines():
        m=sig.match(l)
        if m: names.add(m.group(1))
    if not names: continue
    files+=1; tot+=len(names)
    by=collections.defaultdict(list)
    for n in names: by[snake(n)].append(n)
    for a,ns in by.items():
        if len(ns)>1: coll.append((str(p),a,ns))
    for n in names:
        if snake(n)!=snake2(n): diff.append((n,snake(n),snake2(n)))
print(f"files with public functions: {files}; distinct (file,name) pairs: {tot}")
print(f"alias collisions within one module: {len(coll)}"); [print("  ",c) for c in coll]
print(f"names where the two reasonable derivations disagree: {len(diff)}"); [print("  ",d) for d in sorted(set(diff))[:15]]
