#!/usr/bin/env bash
# Ticket 39 §3: what decides the 20%, and what is the ceiling? RUN ON AN IDLE MACHINE (check `uptime`):
# every number below is a min over 25 runs of a 673,364-click fold, so a background build will move it.
#   E1  the ticket's own table, five times over (is the gap there at all, and how much does it wander?)
#   E3  the SAME code loaded under N different module names (does placement alone move the number?)
#   E4  what is type information worth: Spin private (types inferred) vs exported (not) vs exported+guards
. "$(cd "$(dirname "$0")" && pwd)/env.sh"
B=$PROBE_HOME/b39; E=$B/ebin
case "${1:-all}" in all|E1)
  echo "== E1 four-language table x5 (min ms; rel to fastest of the run)"
  for i in 1 2 3 4 5; do erl -noshell -pa $E -eval 'bench:main(["'$root'/aoc/2025/Day01/input.txt"])' | grep -E "^(Erlang|Elixir|Gleam|beam-sharp)" | awk '{printf "%s %s | ", $1, $3}'; echo; done;; esac
case "${1:-all}" in all|E3)
  echo "== E3 identical code, different module names/load order (min ms over 25 runs each)"
  rm -rf $B/e3; mkdir -p $B/e3
  for i in 1 2 3 4 5 6 7 8; do
    sed "s/bench_erl/bench_erl$i/g" $root/aoc/bench/bench_erl.erl > $B/e3/bench_erl$i.erl
    erlc -o $B/e3 $B/e3/bench_erl$i.erl
    mkdir -p $B/e3/D$i; sed "s/Day01/Day0$i/g" $B/Day01/bench_bs.bs > $B/e3/D$i/bench_bs.bs
  done
  cat > $B/e3/c.escript <<'X'
#!/usr/bin/env escript
main([Ebin, E3, Input, Bsc]) ->
    true = code:add_patha(Ebin), true = code:add_patha(E3), true = code:add_patha(Bsc),
    [begin {ok,_} = bsc:file_to_dir(E3 ++ "/D" ++ integer_to_list(I), E3) end || I <- lists:seq(1,8)],
    {ok, Bin} = file:read_file(Input),
    P = fun([$L|N]) -> -list_to_integer(N); ([$R|N]) -> list_to_integer(N) end,
    Ds = [P(L) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""],
    Time = fun(F) -> _ = F(Ds), lists:min([element(1, timer:tc(F, [Ds])) || _ <- lists:seq(1, 25)]) end,
    Er = [{I, Time(fun(X) -> (list_to_atom("bench_erl" ++ integer_to_list(I))):part_two(X) end)} || I <- lists:seq(1,8)],
    Bs = [{I, Time(fun(X) -> (list_to_atom("Day0" ++ integer_to_list(I))):'PartTwo'(X) end)} || I <- lists:seq(1,8)],
    Show = fun(Name, L) -> Ms = [T/1000 || {_, T} <- L],
                io:format("~-11s ~s   spread max/min = ~.3f~n", [Name, [io_lib:format("~6.2f", [M]) || M <- Ms], lists:max(Ms)/lists:min(Ms)]) end,
    Show("erlang x8", Er), Show("beam-sharp x8", Bs),
    io:format("beam-sharp best / erlang best = ~.3f~n", [lists:min([T || {_,T} <- Bs]) / lists:min([T || {_,T} <- Er])]).
X
  escript $B/e3/c.escript $E $B/e3 $root/aoc/2025/Day01/input.txt ${BSC_EBIN:-$PROBE_HOME/variants/base/ebin};; esac
case "${1:-all}" in all|E4)
  echo "== E4 what type information is worth in this loop (Erlang, same body)"
  mkdir -p $B/e4; rm -f $B/e4/*
  base=$root/aoc/bench/bench_erl.erl
  # (a) private spin: inferred ranges   (b) spin exported: callers unknown, ranges lost
  # (c) spin exported + range guards at the boundary (what B#'s boundary_guards emits for a refined parameter)
  sed 's/bench_erl/e4a/g' $base > $B/e4/e4a.erl
  sed 's/bench_erl/e4b/g; s/-export(\[part_two\/1\])/-export([part_two\/1, spin\/4, wrap\/1])/' $base > $B/e4/e4b.erl
  sed 's/bench_erl/e4c/g; s/-export(\[part_two\/1\])/-export([part_two\/1, spin\/4, wrap\/1])/;
       s/^spin(Pos, Step, Left, Zeros) ->/spin(Pos, Step, Left, Zeros) when is_integer(Pos), Pos >= 0, Pos =< 99, is_integer(Step), Step >= -1, Step =< 1, is_integer(Left), Left >= 0 ->/' $base > $B/e4/e4c.erl
  for m in e4a e4b e4c; do erlc -S -o $B/e4 $B/e4/$m.erl; erlc -o $B/e4 $B/e4/$m.erl; printf "%s: {tr,..integer ranges} annotations in .S: %s\n" $m "$(grep -c 't_integer' $B/e4/$m.S)"; done
  cat > $B/e4/c.escript <<'X'
#!/usr/bin/env escript
main([E4, Input]) ->
    true = code:add_patha(E4),
    {ok, Bin} = file:read_file(Input),
    P = fun([$L|N]) -> -list_to_integer(N); ([$R|N]) -> list_to_integer(N) end,
    Ds = [P(L) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""],
    Time = fun(M) -> F = fun(X) -> M:part_two(X) end, _ = F(Ds), lists:min([element(1, timer:tc(F, [Ds])) || _ <- lists:seq(1, 25)]) end,
    [io:format("~s ~6.2f ms~n", [M, Time(M)/1000]) || M <- [e4a, e4b, e4c, e4a, e4b, e4c]].
X
  escript $B/e4/c.escript $B/e4 $root/aoc/2025/Day01/input.txt;; esac
case "${1:-all}" in all|E5)
  echo "== E5 the ceiling: Gleam's output carries -compile([inline,...]). Same bodies, inlining on."
  mkdir -p $B/e5; rm -rf $B/e5/*
  sed 's/bench_erl/e5erl/g' $root/aoc/bench/bench_erl.erl > $B/e5/e5erl.erl
  erlc -o $B/e5 $B/e5/e5erl.erl                              # default options
  sed 's/bench_erl/e5erli/g' $root/aoc/bench/bench_erl.erl > $B/e5/e5erli.erl
  erlc +inline -o $B/e5 $B/e5/e5erli.erl                     # Erlang with +inline
  # beam-sharp: the same .abstr bsc wrote, recompiled with the compiler option; and with the attribute in the forms
  cat > $B/e5/c.escript <<'X'
#!/usr/bin/env escript
main([E5, Ebin, Input]) ->
    true = code:add_patha(E5), true = code:add_patha(Ebin),
    Abstr = Ebin ++ "/Day01.abstr",
    {ok, 'Day01'} = compile:file(Abstr, [from_abstr, debug_info, {outdir, E5}]),
    code:purge('Day01'), {module,'Day01'} = code:load_abs(E5 ++ "/Day01"),
    Plain = fun(X) -> 'Day01':'PartTwo'(X) end,
    {ok, Forms} = file:consult(Abstr),
    Forms1 = [hd(Forms) | [{attribute, 1, compile, [inline]} | tl(Forms)]],
    {ok, Forms2} = {ok, [case F of {attribute,L,module,'Day01'} -> {attribute,L,module,'Day01i'}; _ -> F end || F <- Forms1]},
    ok = file:write_file(E5 ++ "/Day01i.abstr", [io_lib:format("~p.~n", [F]) || F <- Forms2]),
    {ok, 'Day01i'} = compile:file(E5 ++ "/Day01i.abstr", [from_abstr, debug_info, {outdir, E5}]),
    {module,'Day01i'} = code:load_abs(E5 ++ "/Day01i"),
    {ok, Bin} = file:read_file(Input),
    P = fun([$L|N]) -> -list_to_integer(N); ([$R|N]) -> list_to_integer(N) end,
    Ds = [P(L) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""],
    Time = fun(F) -> _ = F(Ds), lists:min([element(1, timer:tc(F, [Ds])) || _ <- lists:seq(1, 25)]) / 1000 end,
    Run = [{"erlang default",        fun e5erl:part_two/1},
           {"erlang +inline",        fun e5erli:part_two/1},
           {"beam-sharp (as bsc builds it)", Plain},
           {"beam-sharp + inline attribute", fun 'Day01i':'PartTwo'/1},
           {"gleam",                 fun bench_gleam:part_two/1}],
    [io:format("~-32s ~6.2f ms~n", [N, Time(F)]) || {N, F} <- Run],
    [io:format("~-32s ~6.2f ms~n", [N, Time(F)]) || {N, F} <- Run].
X
  escript $B/e5/c.escript $B/e5 $E $root/aoc/2025/Day01/input.txt;; esac
case "${1:-all}" in all|E6)
  echo "== E6 which function's inlining carries the gain (Erlang source, -compile({inline,[...]}) on one function at a time)"
  mkdir -p $B/e6; rm -rf $B/e6/*
  for pair in "none:" "hit:hit/1" "wrap:wrap/1" "both:wrap/1,hit/1"; do
    n=${pair%%:*}; fs=${pair#*:}
    { [ -n "$fs" ] && printf -- '-compile({inline,[%s]}).\n' "$fs"; sed "s/bench_erl/e6$n/g" $root/aoc/bench/bench_erl.erl; } > $B/e6/e6$n.erl
    # the -compile line must follow -module: put module first
    { head -1 $B/e6/e6$n.erl | grep -q compile && { sed -n 2p $B/e6/e6$n.erl; sed -n 1p $B/e6/e6$n.erl; sed -n '3,$p' $B/e6/e6$n.erl; } || cat $B/e6/e6$n.erl; } > $B/e6/t && mv $B/e6/t $B/e6/e6$n.erl
    erlc -o $B/e6 $B/e6/e6$n.erl
  done
  cat > $B/e6/c.escript <<'X'
#!/usr/bin/env escript
main([E6, Input]) ->
    true = code:add_patha(E6),
    {ok, Bin} = file:read_file(Input),
    P = fun([$L|N]) -> -list_to_integer(N); ([$R|N]) -> list_to_integer(N) end,
    Ds = [P(L) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""],
    Time = fun(M) -> F = fun(X) -> M:part_two(X) end, _ = F(Ds), lists:min([element(1, timer:tc(F, [Ds])) || _ <- lists:seq(1, 25)]) / 1000 end,
    [io:format("~-10s ~6.2f ms~n", [M, Time(M)]) || M <- [e6none, e6hit, e6wrap, e6both, e6none, e6hit, e6wrap, e6both]].
X
  escript $B/e6/c.escript $B/e6 $root/aoc/2025/Day01/input.txt;; esac
