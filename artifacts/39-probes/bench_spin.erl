%%% Probe for ticket 39 sub-decision 1: "is the gap in Spin/the loop itself,
%%% isolated, rather than the whole fold?"
%%%
%%% Times ONLY the hot loop (Spin/wrap, no list traversal, no Clicks fold) by
%%% calling each language's Spin-equivalent directly with a large iteration
%%% count, bypassing the day-1 input entirely. This isolates exactly the
%%% "673k tight integer iterations" the ticket says is where the loop lives.
-module(bench_spin).
-export([main/0]).

-define(RUNS, 300).
-define(LEFT, 2000000). %% one call does 2M iterations of the wrap/spin loop

main() ->
    io:format("Spin-only microbenchmark: ~p iterations x ~p runs~n~n",
              [?LEFT, ?RUNS]),
    Impls = [{"Erlang",     fun() -> probe_erl_spin:spin_only(1, ?LEFT) end},
             {"Elixir",     fun() -> 'Elixir.ProbeExSpin':spin_only(1, ?LEFT) end},
             {"Gleam",      fun() -> probe_gleam_spin:spin_only(1, ?LEFT) end},
             {"beam-sharp", fun() -> 'ProbeBsSpin':'SpinOnly'(1, ?LEFT) end}],
    [F() || {_, F} <- Impls], %% warm up
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
    io:format("~-12s ~-8s ~9s ~9s ~9s ~8s~n",
              ["", "answer", "min ms", "p25 ms", "med ms", "rel"]),
    Base = lists:min([Min || {_, _, Min, _, _} <- Results]),
    [io:format("~-12s ~-8s ~9.3f ~9.3f ~9.3f ~7.2fx~n",
               [Name, lists:flatten(io_lib:format("~p", [Answer])), Min / 1000,
                P25 / 1000, Med / 1000, Min / Base])
     || {Name, Answer, Min, P25, Med} <- Results].
