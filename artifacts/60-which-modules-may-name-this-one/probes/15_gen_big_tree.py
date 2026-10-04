#!/usr/bin/env python3
# Generates Big/: G groups x M modules + one Rules helper per group, and Big/Main using every module.
# usage: 15_gen_big_tree.py OUTDIR G M WITHIN(0|1)
import os, sys
out, G, M, W = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4] == "1"
def w(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write(text)
for g in range(G):
    gm = f"Big.G{g}"
    w(f"{out}/Big/G{g}/Rules/Rules.bs",
      f"module {gm}.Rules\n" + (f"within {gm}\n" if W else "") +
      "\npublic int Helper(int x)\nHelper(x) -> x + 1\n")
    for m in range(M):
        uses = [f"using {gm}.Rules"] + [f"using {gm}.M{k}" for k in range(max(0, m - 6), m)]
        calls = " + ".join(["Helper(x)"] + [f"F{k}(x)" for k in range(max(0, m - 6), m)])
        w(f"{out}/Big/G{g}/M{m}/M{m}.bs",
          f"module {gm}.M{m}\n\n" + "\n".join(uses) + f"\n\npublic int F{m}(int x)\nF{m}(x) -> {calls}\n")
mods = [f"Big.G{g}.M{m}" for g in range(G) for m in range(M)]
# F{m} is declared by many modules, so Main must qualify -- but qualified calls need the module path; call one per group.
w(f"{out}/Big/Main/Main.bs",
  "module Big.Main\n\n" + "\n".join(f"using {x}" for x in mods) +
  "\n\npublic int Go(int x)\nGo(x) -> " + " + ".join(f"Big.G{g}.M{M-1}.F{M-1}(x)" for g in range(G)) + "\n")
print(f"{G*M + G + 1} modules, {len(mods) + G*(M*1) + sum(min(6,m) for m in range(M))*G} using lines")
