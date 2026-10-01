import sys
n=int(sys.argv[1]); mode=sys.argv[2]
out=[f"-module(g_{mode}_{n})."]
ex=[]
for i in range(1,n+1):
    ex.append(f"'Fun{i}'/1")
    if mode!='base': ex.append(f"fun_{i}/1")
out.append("-export(["+", ".join(ex)+"]).")
for i in range(1,n+1):
    body=lambda f: f"{f}(#{{'Kind' := 'M.R', 'Id' := I}}) when is_integer(I), I > 0 -> {{ok, I + {i}}};\n{f}(_) -> error."
    out.append(body(f"'Fun{i}'"))
    if mode=='alias': out.append(f"fun_{i}(X) -> 'Fun{i}'(X).")
    if mode=='dup': out.append(body(f"fun_{i}"))
print("\n".join(out))
