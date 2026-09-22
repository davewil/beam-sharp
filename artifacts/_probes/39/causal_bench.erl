%%% Times spin_isolated:run/1 compiled two ways from the IDENTICAL source:
%%% normally (with beam_ssa_type's {tr, Reg, Type} annotations) and with
%%% `no_type_opt` (without them, and without the interprocedural constant
%%% propagation that also depends on that pass). This is ticket 39 §3 item 2:
%%% does losing the annotations, by itself, reproduce something like the
%%% ticket's originally-reported 20% gap?
-module(causal_bench).
-export([main/0]).

-define(RUNS, 25).

main() ->
    Left = 673364,
    Impls = [{"normal (tr present)",    fun spin_isolated_normal:run/1},
             {"no_type_opt (tr gone)",  fun spin_isolated_no_type_opt:run/1}],
    Results = [run(Name, F, Left) || {Name, F} <- Impls],
    report(Results),
    halt().

run(Name, F, Left) ->
    Answer = F(Left),
    Times = [begin {T, _} = timer:tc(F, [Left]), T end || _ <- lists:seq(1, ?RUNS)],
    Sorted = lists:sort(Times),
    {Name, Answer, hd(Sorted), lists:nth(?RUNS div 2 + 1, Sorted)}.

report(Results) ->
    io:format("~-22s ~-16s ~9s ~9s ~8s~n",
              ["", "answer", "min ms", "med ms", "rel"]),
    Base = lists:min([Min || {_, _, Min, _} <- Results]),
    [io:format("~-22s ~-16s ~9.3f ~9.3f ~7.2fx~n",
               [Name, io_lib:format("~p", [Answer]), Min / 1000, Med / 1000,
                Min / Base])
     || {Name, Answer, Min, Med} <- Results].
