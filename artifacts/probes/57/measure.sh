#!/usr/bin/env bash
# Measurements for ticket 57. Prints numbers; asserts nothing except the stated EXPECTATIONS at the end.
# EXPECTED before run:
#  M1 yecc conflicts: base 6 s/r 0 r/r; A 6/0 (an action change); Aprod 6/0 as reported, but verbose lists
#     more precedence-resolved conflicts than base (a new reduce/reduce between `integer` and `'-' integer`).
#  M2 lines changed (diff -ruN of src): A and Aprod ~1-2 lines; B0 about 10; Bn about 25; Ba about 35.
#  M3 compile time of a 200-refinement module (7 runs each, min/median ms): no variant differs from base by
#     more than run-to-run noise (i.e. the fold is not measurable next to the rest of the compile).
here=$(cd "$(dirname "$0")" && pwd)
W=${W:-/tmp/claude-0/-home-user-beam-sharp/40070274-2489-5304-8393-d8d915b713dc/scratchpad/work/57}
SP=$(dirname "$W"|xargs dirname)
echo "== M1 yecc conflicts (yecc:file, as reported / count of precedence-resolved parse-action conflicts in verbose mode)"
for v in base A Aprod B0 Bn Ba; do
  verb=$(erl -noshell -pa $SP/newleex -eval 'yecc:file("'$W/$v-copy/src/bs_parser.yrl'",[{parserfile,"'$W'/verbose_'$v'.erl"},{verbose,true}]),halt().' 2>&1 | grep -c '^Parse action conflict')
  printf '%-6s %s ; verbose parse-action conflict reports: %s\n' $v "$(cat $W/$v.yecc)" "$verb"
done
echo; echo "== M2 lines changed vs unpatched copy (git diff --no-index --shortstat)"
for v in A Aprod B0 Bn Ba; do
  printf '%-6s %s\n' $v "$(git diff --no-index --shortstat $W/base-copy/src $W/$v-copy/src | sed 's/^ *//')"
done
echo; echo "== M3 compile time, 200-refinement module, timer:tc, 7 runs interleaved across compilers (ms)"
gen () { # $1 = nonneg|neg
  d=$W/gen_$1/Big; mkdir -p $d
  { echo "module Big"
    for i in $(seq 1 200); do
      if [ $1 = neg ]; then lo="-$i"; else lo="$i"; fi
      echo "type T$i = int where value >= $lo and value <= $((i+10))"
      echo "public int Id$i(T$i b)"
      echo "Id$i(b) -> b"
    done; } > $d/a.bs
}
gen nonneg; gen neg
cat > $W/time.erl <<'EOF'
-module(time).
-export([main/1]).
main([Ebin, Src, Out]) ->
    true = code:add_patha(Ebin),
    Runs = [begin {T, R} = timer:tc(fun() -> bsc:file_to_dir(Src, Out) end), {T div 1000, R} end || _ <- lists:seq(1, 1)],
    io:format("~p~n", [Runs]).
EOF
erlc -o $W $W/time.erl
declare -A T
for kind in nonneg neg; do
  for v in base A Aprod B0 Bn Ba; do T[$kind,$v]=""; done
  for run in 1 2 3 4 5 6 7; do
    for v in base A Aprod B0 Bn Ba; do
      r=$(erl -noshell -pa $W -eval 'true=code:add_patha("'$W/$v/ebin'"), {Us,R}=timer:tc(fun()->bsc:file_to_dir("'$W'/gen_'$kind'/Big/a.bs","'$W'/gen_'$kind'/out_'$v'") end), io:format("~p ~p~n",[Us div 1000, element(1,R)]), halt().' 2>&1 | tail -1)
      T[$kind,$v]="${T[$kind,$v]} ${r%% *}:${r##* }"
    done
  done
  echo "-- $kind refinements"
  for v in base A Aprod B0 Bn Ba; do
    python3 - "$v" "${T[$kind,$v]}" <<'PY'
import sys,statistics
v=sys.argv[1]; items=sys.argv[2].split()
ms=[int(i.split(':')[0]) for i in items]; res=set(i.split(':')[1] for i in items)
print(f"{v:6s} min {min(ms)} ms  median {statistics.median(ms)} ms  runs {ms}  compile result term(s): {sorted(res)}")
PY
  done
done
