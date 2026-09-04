%%% Ordering-confound control for ticket 39: identical to bench_spin.erl
%%% except beam-sharp is timed FIRST and Erlang LAST. If the previous
%%% (Erlang,Elixir,Gleam,beam-sharp)-ordered runs' occasional elevated
%%% beam-sharp "min" were a real per-language effect, reversing the order
%%% should leave beam-sharp fast and now make Erlang show the occasional
%%% elevated min instead -- if instead whichever language goes LAST is what
%%% occasionally gets the elevated min, that is an ordering artifact (drift
%%% in shared-VM background load across one erl invocation), not a
%%% beam-sharp effect.
-module(bench_spin_reordered).
-export([main/0]).

-define(RUNS, 300).
-define(LEFT, 2000000).

main() ->
    io:format("Spin-only microbenchmark (REORDERED, bs first): ~p iterations x ~p runs~n~n",
              [?LEFT, ?RUNS]),
    Impls = [{"beam-sharp", fun() -> 'ProbeBsSpin':'SpinOnly'(1, ?LEFT) end},
             {"Gleam",      fun() -> probe_gleam_spin:spin_only(1, ?LEFT) end},
             {"Elixir",     fun() -> 'Elixir.ProbeExSpin':spin_only(1, ?LEFT) end},
             {"Erlang",     fun() -> probe_erl_spin:spin_only(1, ?LEFT) end}],
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
