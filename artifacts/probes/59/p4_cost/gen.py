import sys,os
k=int(sys.argv[1]); fields=int(sys.argv[2]); d=sys.argv[3]
os.makedirs(d+"/Many",exist_ok=True)
fs=", ".join(f"F{i}: int" for i in range(fields))
out=["module Many","",f"record Rec {{ {fs} }}",""]
for i in range(k):
    out+= [f"int P{i}(Rec r)", f"P{i}(r) -> r.F0 + {i}", ""]
    out+= [f"int Q{i}(int n)", f"Q{i}(n) -> n + {i}", ""]
out+=["public int Entry(Rec r)","Entry(r) -> "+" + ".join(f"P{i}(r)" for i in range(k)) if k else "Entry(r) -> 0",""]
out+=["public int EntryI(int n)","EntryI(n) -> "+" + ".join(f"Q{i}(n)" for i in range(k))]
open(d+"/Many/many.bs","w").write("\n".join(out)+"\n")
