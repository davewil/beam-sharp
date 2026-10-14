#!/bin/bash
for v in "$@"; do
  echo "######## $v"; rm -rf out_${v}_G; mkdir -p out_${v}_G
  ./$v/bsc.sh --src-root pG -o out_${v}_G pG/G </dev/null 2>&1 | grep -v Warning | head -3
  escript dump.escript $(find out_${v}_G -name '*.abstr') > dump_${v}_G.txt 2>&1
  echo "guarded fns (tag/kind guard present in emitted head):"
  python3 - dump_${v}_G.txt <<'PY'
import re,sys
t=open(sys.argv[1]).read()
forms=re.split(r'\n(?=\'[A-Za-z0-9_]+\'\()',t)
for f in forms:
    m=re.match(r"'(\w+)'\(",f)
    if m and m.group(1).startswith(('Show','NoEsc','Cls')):
        print("  %-9s %s"%(m.group(1),"GUARDED" if ("map_get('Kind'" in f or "is_integer" in f) else "unguarded"))
PY
  erl -noshell -pa out_${v}_G -eval '
    Ord = #{'"'"'Kind'"'"'=>'"'"'G.Order'"'"','"'"'Id'"'"'=>1,'"'"'Total'"'"'=>7},
    Inv = #{'"'"'Kind'"'"'=>'"'"'G.Invoice'"'"','"'"'Id'"'"'=>1,'"'"'Total'"'"'=>7},
    T = fun(L, F) -> R = try F() catch Cl:Rs -> {Cl,Rs} end, io:format("  ~-34s ~p~n",[L, R]) end,
    {F1,_} = '"'"'G'"'"':'"'"'InTuple'"'"'(),
    T("tuple Show1(Invoice)", fun() -> F1(Inv) end),
    #{'"'"'Run'"'"' := F2} = '"'"'G'"'"':'"'"'MkBox'"'"'(),
    T("record-field Show2(Invoice)", fun() -> F2(Inv) end),
    T("record-field Show2(Order)", fun() -> F2(Ord) end),
    [F5] = '"'"'G'"'"':'"'"'InList'"'"'(),
    T("list Show5/1 (Invoice)", fun() -> F5(Inv) end),
    F6 = '"'"'G'"'"':'"'"'Two'"'"'(),
    T("Show6/2 (Invoice,1)", fun() -> F6(Inv,1) end),
    F8 = ('"'"'G'"'"':'"'"'Thunk'"'"'())(0),
    T("lambda-returned Show8(Invoice)", fun() -> F8(Inv) end),
    {FC,_} = '"'"'G'"'"':'"'"'KindInTuple'"'"'(),
    T("Cls(8.5) via tuple", fun() -> FC(8.5) end),
    T("Mapped([Invoice]) via lists:map", fun() -> '"'"'G'"'"':'"'"'Mapped'"'"'([Inv]) end),
    T("Piped(Invoice) exported entry", fun() -> '"'"'G'"'"':'"'"'Piped'"'"'(Inv) end),
    T("Plain(Invoice) exported entry", fun() -> '"'"'G'"'"':'"'"'Plain'"'"'(Inv) end),
    halt().'
  echo "  BEAM_BYTES $(stat -c %s out_${v}_G/G.beam)"
done
