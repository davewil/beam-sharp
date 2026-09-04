%%% Probe for ticket 39 sub-decision 2: causation test. Compares the SAME
%%% wrap/hit/spin logic, timed identically, in two Erlang builds that differ
%%% ONLY in whether wrap/1 and hit/1 are in the same module as spin/4
%%% (probe_erl_spin, full same-module SSA type narrowing, confirmed by
%%% dump_s / beam_disasm to carry {tr,{x,0},{t_integer,{-99,99}}}-style
%%% annotations) or in a separate module reached by call_ext (xmod_b/xmod_a,
%%% confirmed by beam_disasm to carry BARE {x,0} operands with no {tr,...}
%%% at the call boundary, matching the ticket's description of beam-sharp's
%%% emitted code). If the missing annotation is causal, xmod_b should be
%%% measurably slower than probe_erl_spin despite being the same algorithm
%%% on the same VM in the same run.
-module(bench_causation).
-export([main/0]).

-define(RUNS, 300).
-define(LEFT, 2000000).

main() ->
    io:format("Causation probe: ~p iterations x ~p runs~n~n", [?LEFT, ?RUNS]),
    Impls = [{"same-module (annotated)",  fun() -> probe_erl_spin:spin_only(1, ?LEFT) end},
             {"cross-module (bare)",      fun() -> xmod_b:spin_only(1, ?LEFT) end}],
    [F() || {_, F} <- Impls],
    Results = [run(Name, F) || {Name, F} <- Impls],
    report(Results),
    halt().

run(Name, F) ->
    Answer = F(),
    Times = [begin {T, _} = timer:tc(F), T end || _ <- lists:seq(1, ?RUNS)],
    Sorted = lists:sort(Times),
    {Name, Answer, hd(Sorted), lists:nth(?RUNS div 4, Sorted),
     lists:nth(?RUNS div 2, Sorted)}.

report(Results) ->
    io:format("~-26s ~-12s ~9s ~9s ~9s ~8s~n",
              ["", "answer", "min ms", "p25 ms", "med ms", "rel"]),
    Base = lists:min([Min || {_, _, Min, _, _} <- Results]),
    [io:format("~-26s ~-12s ~9.3f ~9.3f ~9.3f ~7.2fx~n",
               [Name, lists:flatten(io_lib:format("~p", [Answer])), Min / 1000,
                P25 / 1000, Med / 1000, Min / Base])
     || {Name, Answer, Min, P25, Med} <- Results].
