#!/usr/bin/env bash
# Ticket 62, candidate 2: "emit snake_case aliases alongside - costs two exports per function".
# Measures the .beam byte cost of N PascalCase functions vs the same N plus a snake_case forwarding alias,
# vs a snake_case duplicate of the whole body. Same body for every function (a 2-clause record-ish match).
set -u
W=$(mktemp -d); cd "$W"
gen() { # n mode
  n=$1; mode=$2
  echo "-module(m_${mode}_$n)."
  ex=""; for i in $(seq 1 $n); do ex+="'Fun$i'/1,"; [ $mode != base ] && ex+="fun_$i/1,"; done
  echo "-export([${ex%,}])."
  for i in $(seq 1 $n); do
    echo "'Fun$i'(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + $i}; 'Fun$i'(_) -> error."
    case $mode in
      alias) echo "fun_$i(X) -> 'Fun$i'(X)." ;;
      dup)   echo "fun_$i(#{'Kind' := 'M.R', 'Id' := I}) when is_integer(I), I > 0 -> {ok, I + $i}; fun_$i(_) -> error." ;;
    esac
  done
}
printf '%-6s %-8s %10s %10s\n' N mode bytes stripped
for n in 1 10 50 200; do
  for mode in base alias dup; do
    gen $n $mode > m_${mode}_$n.erl
    erlc +debug_info m_${mode}_$n.erl; s1=$(stat -c%s m_${mode}_$n.beam)
    erlc +strip m_${mode}_$n.erl;      s2=$(stat -c%s m_${mode}_$n.beam)
    printf '%-6s %-8s %10s %10s\n' $n $mode $s1 $s2
  done
done
# call cost: PascalCase direct vs alias forward, 20M calls, 5 repetitions each, median
cat > bench.erl <<'EOF'
-module(bench).
-export([run/0]).
run() ->
  M = #{'Kind' => 'M.R', 'Id' => 5},
  [begin
     T = [begin {U,_} = timer:tc(fun() -> loop(Mod, F, M, 20000000) end), U*1000/20000000 end || _ <- lists:seq(1,5)],
     io:format("~-10s ~-8s ns/call samples ~p~n", [Mod, F, [round(X*100)/100 || X <- lists:sort(T)]])
   end || {Mod, F} <- [{m_base_10,'Fun1'}, {m_alias_10,'Fun1'}, {m_alias_10,fun_1}, {m_dup_10,fun_1}]],
  ok.
loop(_,_,_,0) -> ok;
loop(Mod,F,M,N) -> Mod:F(M), loop(Mod,F,M,N-1).
EOF
erlc bench.erl && erl -noshell -pa . -eval 'bench:run(), halt().'
