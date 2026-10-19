#!/usr/bin/env python3
# ticket 60: how would a directory-subtree "who may name me" rule classify the repo's existing B# imports?
# An edge A -> B (A `using`s B, both B# modules) is: child (B inside A's subtree), parent (B an ancestor of A),
# sibling (share a parent, neither contains the other), or unrelated (no common dotted prefix).
import re,sys,pathlib,collections
root=pathlib.Path(sys.argv[1]); mods={}
for p in root.rglob('*.bs'):
    if 'artifacts' in p.parts: continue
    t=p.read_text(errors='ignore'); m=re.search(r'^\s*module\s+([\w.]+)',t,re.M)
    if m: mods.setdefault(m.group(1),[]).append((p,t))
known=set(mods); kinds=collections.Counter(); ex=collections.defaultdict(list)
for a,fs in mods.items():
  for p,t in fs:
    for b in re.findall(r'^\s*using\s+([A-Z][\w.]*)',t,re.M):
        if b==a: continue
        if b.startswith(a+'.'): k='callee inside caller subtree'
        elif a.startswith(b+'.'): k='callee is an ancestor'
        elif a.split('.')[0]==b.split('.')[0]: k='same root, sibling/cousin'
        else: k='unrelated root'
        kinds[k]+=1; ex[k].append(f"{a} -> {b}")
print(f"B# modules found: {len(mods)}")
for k,n in kinds.most_common(): print(f"{n:3d}  {k}   e.g. {ex[k][:2]}")
print("total B#->B# using edges:",sum(kinds.values()))
