%%% Paying down two of the walking skeleton's eleven debts.
%%%
%%% 1. TICKET 04 — checker cost at showcase clause counts.
%%%    Ticket 04 concluded the exhaustiveness mechanism "is not a research risk;
%%%    it has been solved and shipped since 2003", while also recording that
%%%    Etylizer's pathological inputs are `case` expressions with 40+ branches —
%%%    precisely the large multi-clause `handle_info` this language advertises.
%%%    Nobody had run one. This does.
%%%
%%% 2. TICKET 12 — the retained failure arm at showcase clause counts.
%%%    Measured at 40 bytes (4.8%) on a TWO-clause function, and kept everywhere
%%%    on that evidence. The map records the cost on a forty-clause function as
%%%    unknown.
%%%
%%% Run: rebar3 as bench compile && erl -noshell -pa _build/bench/lib/bsc/ebin \
%%%        -pa bench -eval 'bs_bench:main(),halt().'

-module(bs_bench).
-export([main/0, checker_cost/0, failure_arm_cost/0]).

main() ->
    checker_cost(),
    failure_arm_cost(),
    ok.

%%% ---------------------------------------------------------------------------
%%% 1. Checker cost against clause count
%%% ---------------------------------------------------------------------------

checker_cost() ->
    io:format("~n=== ticket 04: exhaustiveness check cost vs clause count ===~n"),
    %% Warm the JIT first: an unwarmed first measurement read 3734 us at five
    %% clauses and 23 us at ten, which is the runtime compiling, not the checker
    %% working.
    _ = [check(atom_ladder(20)) || _ <- lists:seq(1, 50)],
    io:format("~-8s ~-12s ~-12s ~s~n", ["clauses", "check (us)", "us/clause", "verdict"]),
    [begin
         Src = atom_ladder(N),
         Reps = 20,
         {Total, Result} = timer:tc(fun() -> last([check(Src) || _ <- lists:seq(1, Reps)]) end),
         Us = Total / Reps,
         io:format("~-8w ~-12.1f ~-12.2f ~s~n",
                   [N, Us, Us / N, verdict(Result)])
     end || N <- [5, 10, 20, 40, 80, 160]],
    ok.

last(L) -> lists:last(L).

%% The shape the language advertises: a wide dispatch over a closed atom union,
%% which is what a large `handle_info` is.
atom_ladder(N) ->
    Members = [io_lib:format(":m~p", [I]) || I <- lists:seq(1, N)],
    Clauses = [io_lib:format("Handle(:m~p) -> :ok;\n", [I]) || I <- lists:seq(1, N)],
    lists:flatten(
      ["module Bench;\n",
       "type Msg = ", string:join(Members, " | "), ";\n",
       "atom Handle(Msg m);\n",
       Clauses]).

check(Src) ->
    {ok, Toks, _} = bs_lexer:string(Src),
    {ok, Decls} = bs_parser:parse(Toks),
    bs_check:check(Decls).

verdict({ok, _, []})   -> "exhaustive";
verdict({ok, _, D})    -> io_lib:format("exhaustive, ~p warnings", [length(D)]);
verdict({error, _})    -> "INEXHAUSTIVE".

%%% ---------------------------------------------------------------------------
%%% 2. What the retained failure arm costs at scale
%%%
%%% Ticket 13 found the arm cannot be suppressed on this target — `erlc` inserts
%%% it. So the cost is measured by comparison: a function whose clauses are all
%%% specific (the arm is reachable and must be emitted) against the same function
%%% with a final catch-all (the arm is unreachable and folds away).
%%% ---------------------------------------------------------------------------

failure_arm_cost() ->
    io:format("~n=== ticket 12: the retained failure arm vs clause count ===~n"),
    io:format("~-8s ~-12s ~-12s ~-10s ~s~n",
              ["clauses", "specific", "catch-all", "delta", "% of Code"]),
    [begin
         Specific = code_size(erl_ladder(N, specific)),
         CatchAll = code_size(erl_ladder(N, catch_all)),
         Delta = Specific - CatchAll,
         io:format("~-8w ~-12w ~-12w ~-10w ~.2f%~n",
                   [N, Specific, CatchAll, Delta, 100 * Delta / Specific])
     end || N <- [2, 5, 10, 20, 40]],
    ok.

%% Built directly as abstract-format forms — the same contract bsc emits, so the
%% number measures the target rather than a hand-written Erlang approximation.
%% Each clause returns a DISTINCT value. With identical `-> ok` bodies the
%% optimiser folded every clause into the catch-all, so the catch-all baseline sat
%% at 70 bytes for 2 clauses and for 40 alike, and the "delta" was measuring the
%% clauses themselves rather than the failure arm. That artefact read as 66% of
%% the Code chunk at forty clauses, which is why it is called out here rather than
%% quietly fixed.
erl_ladder(N, Kind) ->
    Clauses =
        [{clause, 0, [{atom, 0, list_to_atom("m" ++ integer_to_list(I))}], [],
          [{atom, 0, list_to_atom("r" ++ integer_to_list(I))}]} || I <- lists:seq(1, N)]
        ++ case Kind of
               specific  -> [];
               catch_all -> [{clause, 0, [{var, 0, '_'}], [], [{atom, 0, fallback}]}]
           end,
    Mod = list_to_atom("bench_" ++ atom_to_list(Kind) ++ "_" ++ integer_to_list(N)),
    [{attribute, 0, module, Mod},
     {attribute, 0, export, [{handle, 1}]},
     {function, 0, handle, 1, Clauses}].

code_size(Forms) ->
    {ok, _Mod, Bin} = compile:forms(Forms, [binary, return_errors]),
    {ok, {_, [{"Code", Code}]}} = beam_lib:chunks(Bin, ["Code"]),
    byte_size(Code).
