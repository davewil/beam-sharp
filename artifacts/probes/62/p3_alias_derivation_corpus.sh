#!/bin/sh
# 62 / probe 3 — if B# emitted a snake_case alias beside every exported PascalCase function,
# does a derivation rule collide on the REAL corpus (every `public` signature under compiler/examples + aoc)?
# Two rules: Gleam's own to_snake_case (strings.rs:70, ported line for line) and Elixir's Macro.underscore.
set -u
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
python3 -I - "$ROOT" <<'P'
import re,sys,os,subprocess,collections,json
root=sys.argv[1]
def gleam_snake(s):
    out=[];wb=True
    for ch in s:
        if ch in '_ ': wb=True; continue
        if ch.isupper(): wb=True
        if wb:
            if out: out.append('_')
            wb=False
        out.append(ch.lower() if ch.isascii() else ch)
    return ''.join(out)
sig=re.compile(r'^\s*public\s+[^()=\n]*?\b([A-Z][A-Za-z0-9_]*)\s*\(',re.M)
mod=re.compile(r'^\s*module\s+([A-Za-z0-9_.]+)',re.M)
mods=collections.defaultdict(set)
for d in ('compiler/examples','aoc'):
    for dp,_,fs in os.walk(os.path.join(root,d)):
        for f in fs:
            if f.endswith('.bs'):
                t=open(os.path.join(dp,f)).read()
                m=mod.search(t)
                if not m: continue
                for n in sig.findall(t): mods[m.group(1)].add(n)
names=sorted({n for v in mods.values() for n in v})
ex=subprocess.run(['elixir','-e','IO.read(:stdio,:eof) |> String.split("\\n",trim: true) |> Enum.each(&IO.puts(Macro.underscore(&1)))'],input='\n'.join(names),capture_output=True,text=True).stdout.split('\n')
exmap=dict(zip(names,ex))
print(f"modules={len(mods)} exported-PascalCase-names={sum(len(v) for v in mods.values())} distinct={len(names)}")
for label,fn in (('gleam to_snake_case',gleam_snake),('elixir Macro.underscore',lambda n:exmap[n])):
    coll=[]
    for m,v in mods.items():
        seen=collections.defaultdict(list)
        for n in v: seen[fn(n)].append(n)
        coll+= [(m,k,x) for k,x in seen.items() if len(x)>1]
    print(f"{label}: within-module collisions on the corpus = {len(coll)}", coll[:5])
print('rules disagree on:',[(n,gleam_snake(n),exmap[n]) for n in names if gleam_snake(n)!=exmap[n]][:12])
print('names with a digit or acronym run (where rules diverge in principle):',[n for n in names if re.search(r'[A-Z]{2}|\d',n)][:15])
# adversarial: names an author could legally write
adv=['GetID','GetId','HTTPGet','HttpGet','Part1','Part_1','ParseJSON','ParseJson']
print('adversarial gleam :',{n:gleam_snake(n) for n in adv})
out=subprocess.run(['elixir','-e','Enum.each(~w(%s), &IO.puts(&1 <> " -> " <> Macro.underscore(&1)))'%' '.join(adv)],capture_output=True,text=True).stdout
print('adversarial elixir:',out.replace('\n','; '))
P
