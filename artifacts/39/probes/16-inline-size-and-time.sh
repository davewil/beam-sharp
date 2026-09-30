#!/usr/bin/env bash
# Cost of turning `inline` on for real B# modules: .beam size and erlc-from-abstr time, default vs inline. 10 repeats each.
R=/home/user/beam-sharp/artifacts/39; C=/home/user/beam-sharp/compiler/examples; O=$R/build/ex; rm -rf $O; mkdir -p $O
for m in Shop Signalbox Intake Ledger Queue Frame; do $R/probes/bsc.sh --src-root $C -o $O $C/$m 2>&1 | head -3 | sed "s/^/bsc $m: /" ; done
cat > $O/m.erl <<'XEOF'
-module(m).
-export([main/0]).
main() ->
    Files = [F || F <- filelib:wildcard("/home/user/beam-sharp/artifacts/39/build/ex/*.abstr"), filename:basename(F) =/= "Signalbox.abstr"],
    [begin
        Sz = fun(Opts) -> {ok,_,B} = compile:file(F, [from_abstr, binary, debug_info | Opts]), byte_size(B) end,
        Tm = fun(Opts) -> lists:sort([begin {T,_} = timer:tc(fun() -> compile:file(F, [from_abstr, binary, debug_info | Opts]) end), T end || _ <- lists:seq(1,10)]) end,
        T0 = lists:nth(5, Tm([])), T1 = lists:nth(5, Tm([inline])),
        io:format("~-28s bytes ~6w -> ~6w (~.1f%)   median compile us ~6w -> ~6w (~.1f%)~n",
                  [filename:basename(F), Sz([]), Sz([inline]), (Sz([inline])/Sz([])-1)*100, T0, T1, (T1/T0-1)*100])
     end || F <- Files],
    halt().
XEOF
erlc -o $O $O/m.erl && erl -noshell -pa $O -eval 'm:main()'
