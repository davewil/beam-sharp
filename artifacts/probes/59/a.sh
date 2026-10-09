#!/usr/bin/env bash
# Probe 59a: read the emitted abstract code (beam_lib debug_info/abstract_code) of PRIVATE and PUBLIC
# functions. Expected on the pinned emitter: record tag test on private AND public; int kind/range test on public ONLY.
cd "$(dirname "$0")"
for spec in "Ledger Handle public-record" "Ledger Inner private-record" "Kinds DoubleP public-int" "Kinds Double private-int" "Kinds Band private-refined-int"; do
  set -- $spec
  b=out/$1; [ -d $b ] || b=out/$1/base
  f=out/base/$1.beam; [ $1 = Kinds ] && f=out/Kinds/base/Kinds.beam
  echo "--- $1:$2 ($3), emitter base"
  ./show.escript $f | awk -v fn="'$2'" 'index($0,fn"(")==1{p=1} p{print} p&&/\.$/{exit}' | head -12
done
echo "--- tag/kind test counts per function (base emitter), is_public = in export list"
for m in "Ledger out/base/Ledger.beam" "Kinds out/Kinds/base/Kinds.beam"; do
  set -- $m
  erl -noshell -eval '
    {ok,{_,[{abstract_code,{_,AC}}]}} = beam_lib:chunks("'$2'",[abstract_code]),
    Ex = lists:append([E || {attribute,_,export,E} <- AC]),
    [begin
       S = lists:flatten(erl_pp:form(F)),
       Tag = string:str(S, "map_get(\x27Kind\x27") > 0 andalso string:str(S, "=:= \x27") > 0,
       Int = string:str(S, "is_integer(") > 0,
       io:format("~-22s ~-7s tag_test=~-5w kind_test=~w~n",["'$1':"++atom_to_list(N), case lists:member({N,A},Ex) of true->"public";false->"private" end, Tag, Int])
     end || F={function,_,N,A,_} <- AC, not lists:prefix("bs@",atom_to_list(N))],
    halt().' 
done
