#!/usr/bin/env bash
# Probe 62-06: prototype of DERIVED snake_case alias exports; measures cost for 1/10/50 functions.
# Builds a patched copy of the compiler in a temp dir (repo compiler is NOT touched).
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO=/home/user/beam-sharp
W=$(mktemp -d); mkdir -p $W/c $W/src
(cd $REPO/compiler && tar --exclude=_build --exclude=examples --exclude=test --exclude=bench -cf - .) | tar -xf - -C $W/c
patch -s $W/c/src/bs_emit.erl < $HERE/alias.patch || { echo PATCH FAILED; exit 1; }
(cd $W/c && rebar3 escriptize >/dev/null 2>&1) || { echo BUILD FAILED; exit 1; }
B=$W/c/_build/default/bin/bsc
gen() { # N -> module GN with N public functions of mixed shape
  n=$1; d=$W/src/G$n; mkdir -p $d
  { echo "module G$n"; echo; echo "record Item { Id: int, Qty: int }"; echo
    for i in $(seq 1 $n); do
      s=$(printf '%s%s' "$(echo $i | awk '{printf "%c", 65+int($1/26)%26}')" "$(echo $i | awk '{printf "%c", 97+$1%26}')")
      echo "public int GetItem${s}ById(int id)"; echo; echo "GetItem${s}ById(id) -> id + $i"; echo
    done; } > $d/g$n.bs
}
for n in 1 10 50; do gen $n; done
echo "sample (G10, first 6 lines):"; head -8 $W/src/G10/g10.bs
for n in 1 10 50; do for m in none nospec spec; do
  mkdir -p $W/o/$m/$n; BS_ALIAS=$m $B --src-root $W/src -o $W/o/$m/$n $W/src/G$n >/dev/null 2>$W/err.txt
  [ -s $W/err.txt ] && { echo "stderr for $m/$n:"; cat $W/err.txt; }
  printf "N=%-3s mode=%-7s " $n $m; escript $HERE/measure.escript $W/o/$m/$n/G$n.beam
done; done
echo; echo "--- compile time (wall ms, 9 runs, bsc escript incl. VM start): min / median"
for n in 10 50; do for m in none nospec spec; do
  ts=(); for r in $(seq 1 9); do s=$(date +%s%N); BS_ALIAS=$m $B --src-root $W/src -o $W/o/$m/$n $W/src/G$n >/dev/null 2>&1; e=$(date +%s%N); ts+=($(( (e-s)/1000000 ))); done
  sorted=($(printf '%s\n' "${ts[@]}" | sort -n)); printf "N=%-3s mode=%-7s min=%s median=%s  (%s)\n" $n $m ${sorted[0]} ${sorted[4]} "${ts[*]}"
done; done
echo; echo "--- emitted export list (G10, spec mode), first 14"
cd $W; erl -noshell -eval '{ok,{_,[{exports,E}]}}=beam_lib:chunks("'$W'/o/spec/10/G10.beam",[exports]), io:format("~p~n",[lists:sublist(E,3)++lists:sublist(lists:reverse(E),5)]), halt().' 2>&1 | head -20
echo; echo "--- call overhead: direct vs alias (G10, 2M calls each, median of 5)"
cat > $W/call.escript <<'EOS'
#!/usr/bin/env escript
main([Dir]) ->
    true = code:add_patha(Dir),
    Names = [N || {N, 1} <- 'G10':module_info(exports), N =/= module_info],
    io:format("exports(G10)=~p~n", [lists:sort(Names)]),
    Run = fun(F) -> {T, _} = timer:tc(fun() -> lists:foreach(fun(I) -> F(I) end, lists:seq(1, 2000000)) end), T end,
    Med = fun(F) -> L = lists:sort([Run(F) || _ <- lists:seq(1, 5)]), lists:nth(3, L) end,
    Direct = hd([N || N <- Names, atom_to_list(N) =/= string:lowercase(atom_to_list(N))]),
    Alias = hd([N || N <- Names, atom_to_list(N) =:= string:lowercase(atom_to_list(N)), N =/= module_info]),
    io:format("direct ~p ~p us; alias ~p ~p us (2M calls, remote apply by variable atom)~n",
      [Direct, Med(fun(I) -> 'G10':Direct(I) end), Alias, Med(fun(I) -> 'G10':Alias(I) end)]).
EOS
escript $W/call.escript $W/o/spec/10
echo; echo "--- dialyzer (erts-only PLT) on G50: none vs spec vs nospec"
PLT=$W/plt; (cd $W; dialyzer --build_plt --output_plt $PLT --apps erts >/dev/null 2>&1)
for m in none nospec spec; do s=$(date +%s%N); dialyzer --plt $PLT $W/o/$m/50/G50.beam 2>&1 | tail -2 | tr '\n' ' '; e=$(date +%s%N); echo " <- $m: $(( (e-s)/1000000 )) ms"; done
rm -rf $W
