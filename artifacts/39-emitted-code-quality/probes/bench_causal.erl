%%% Causal test for ticket 39 sub-investigation #2: "do the annotations
%%% cause it, or merely accompany it?"
%%%
%%% Three implementations of the SAME source (bench_erl.erl), differing only
%%% in the presence of {tr, Reg, Type} JIT operand annotations:
%%%   - Erlang            : erlc's normal output (annotations present)
%%%   - Erlang (stripped) : the SAME module, reassembled from `+to_asm`
%%%                         output with every {tr,...} wrapper stripped to
%%%                         a bare register (compile:file([from_asm]), so
%%%                         beam_ssa_opt never runs a second time -- the
%%%                         ONLY change from the original is annotation
%%%                         presence/absence)
%%%   - beam-sharp        : Day01's real, unmodified emitted code
%%% If annotation-loss alone is causally responsible for a slowdown, the
%%% stripped Erlang variant should slow down toward beam-sharp's time even
%%% though its instruction sequence is otherwise identical to the original.
-module(bench_causal).
-export([main/1]).

-define(RUNS, 25).

main([InputPath]) ->
    Deltas = read(InputPath),
    io:format("~p rotations, ~p clicks simulated per run~n~n",
              [length(Deltas), lists:sum([abs(D) || D <- Deltas])]),
    Impls = [{"Erlang (annotated, original)", fun bench_erl:part_two/1},
             {"Erlang (tr-stripped)",         fun bench_erl_stripped:part_two/1},
             {"beam-sharp",                   fun 'Day01':'PartTwo'/1}],
    Results = [run(Name, F, Deltas) || {Name, F} <- Impls],
    report(Results),
    halt().

run(Name, F, Deltas) ->
    Answer = F(Deltas),
    Times = [begin {T, _} = timer:tc(F, [Deltas]), T end
             || _ <- lists:seq(1, ?RUNS)],
    Sorted = lists:sort(Times),
    {Name, Answer, hd(Sorted), lists:nth(?RUNS div 2 + 1, Sorted)}.

report(Results) ->
    io:format("~-32s ~-8s ~9s ~9s ~8s~n",
              ["", "answer", "min ms", "med ms", "rel"]),
    Base = lists:min([Min || {_, _, Min, _} <- Results]),
    [io:format("~-32s ~-8s ~9.2f ~9.2f ~7.2fx~n",
               [Name, integer_to_list(Answer), Min / 1000, Med / 1000,
                Min / Base])
     || {Name, Answer, Min, Med} <- Results],
    Wrong = [N || {N, A, _, _} <- Results, A =/= 6770],
    case Wrong of
        [] -> io:format("~nall three agree on 6770~n");
        _  -> io:format("~nWRONG ANSWER from: ~p~n", [Wrong])
    end.

read(Path) ->
    {ok, Bin} = file:read_file(Path),
    [parse(L) || L <- string:split(binary_to_list(Bin), "\n", all), L =/= ""].

parse([$L | N]) -> -list_to_integer(N);
parse([$R | N]) -> list_to_integer(N).
