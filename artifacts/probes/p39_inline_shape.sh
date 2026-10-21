#!/usr/bin/env bash
# Ticket 39: the ticket's §1 says all four emit the same hot-loop instructions. Gleam does not: it compiles with
# -compile([inline,...]) and its Spin has no calls left. Run p39_experiments.sh E5 first (it builds Day01i).
. "$(cd "$(dirname "$0")" && pwd)/env.sh"
cat > $PROBE_HOME/gs.escript <<'X'
#!/usr/bin/env escript
main([F, Fn]) ->
    {beam_file,_,_,_,_,D} = beam_disasm:file(F), Name = list_to_atom(Fn),
    [io:format("~-34s ~2w instrs, calls left: ~w~n", [filename:basename(F) ++ ":" ++ Fn, length(Is),
       [element(3, C) || C <- Is, element(1, C) =:= call] ++ [element(3, C) || C <- Is, element(1, C) =:= call_last]]) || {function,N,_,_,Is} <- D, N =:= Name].
X
B=$PROBE_HOME/b39
escript $PROBE_HOME/gs.escript $B/ebin/bench_erl.beam spin
escript $PROBE_HOME/gs.escript $B/ebin/Day01.beam Spin
escript $PROBE_HOME/gs.escript $B/ebin/bench_gleam.beam spin
escript $PROBE_HOME/gs.escript $B/e5/Day01i.beam Spin
