-module(lists_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2]).

-define(OUT, bs_test_support:run_root()).

%%% ---------------------------------------------------------------------------
%%% Lists
%%%
%%% `[]` and `[h, ..t]` partition list<T>, which is what lets a list function be
%%% exhaustive with no catch-all.
%%%
%%% F20 replaced the representation underneath all of this. A list pattern's
%%% prefix is now a product the checker subtracts position by position, so
%%% `[a, b]` is exactly two and `[a, b, ..]` is two or more — and the rest is a
%%% MARKER rather than an ordinary pattern, which is ticket 08 amended. The
%%% tests below the fold measure both directions of the defect that forced it.
%%% ---------------------------------------------------------------------------

series_src() ->
    %% Not `Fib`: the reload test defines its own scalar `Fib` module and the two
    %% would clobber one another's .beam and loaded code.
    "module FibL\n"
    "public list<int> Fib(int n)\n"
    "Fib(n) when n <= 0 -> []\n"
    "Fib(n) when n > 0  -> Series(n, 0, 1, [])\n"
    "public list<int> Series(int n, int a, int b, list<int> acc)\n"
    "Series(n, a, b, acc) when n <= 0 -> Reverse(acc, [])\n"
    "Series(n, a, b, acc) when n > 0  -> Series(n - 1, b, a + b, [a, ..acc])\n"
    "public list<int> Reverse(list<int> xs, list<int> acc)\n"
    "Reverse([], acc)          -> acc\n"
    "Reverse([x, ..rest], acc) -> Reverse(rest, [x, ..acc])\n".

a_list_function_computes_test() ->
    M = build_and_load(series_src(), 'FibL'),
    ?assertEqual([], M:'Fib'(0)),
    ?assertEqual([0], M:'Fib'(1)),
    ?assertEqual([0, 1, 1, 2, 3], M:'Fib'(5)),
    ?assertEqual([0, 1, 1, 2, 3, 5, 8, 13, 21, 34], M:'Fib'(10)).

%% The pair is exhaustive: no catch-all clause, and no diagnostic.
nil_and_cons_partition_a_list_test() ->
    {ok, _} = compile(series_src()),
    {ok, Toks, _} = bs_lexer:string(series_src()),
    {ok, Decls} = bs_parser:parse(Toks),
    {ok, _, Diags} = bs_check:check(Decls),
    ?assertEqual([], [D || D <- Diags, element(1, D) =:= error]).

%% Drop `Reverse([], acc)` and the residual must name the empty list.
missing_nil_clause_is_caught_test() ->
    Src = "module L\npublic list<int> Rev(list<int> xs, list<int> acc)\n"
          "Rev([x, ..rest], acc) -> Rev(rest, [x, ..acc])\n",
    {ok, Toks, _} = bs_lexer:string(Src),
    {ok, Decls} = bs_parser:parse(Toks),
    {error, Diags} = bs_check:check(Decls),
    [{error, _, 'Rev', {inexhaustive, Residual, _}}] =
        [D || D <- Diags, element(1, D) =:= error],
    ?assert(string:find(bs_types:to_string(Residual), "[]") =/= nomatch).

%% Every self-call is a BEAM tail call — `call_only`, not `call` plus a frame.
%% Asserted on the emitted bytecode rather than on the source's shape.
recursion_is_a_tail_call_test() ->
    {ok, _} = compile(series_src()),
    {beam_file, _, _, _, _, Fns} = beam_disasm:file(?OUT ++ "/FibL.beam"),
    Bad = [{Name, Op}
           || {function, Name, _A, _E, Is} <- Fns,
              Name =/= module_info,
              {Op} <- [{element(1, I)} || I <- Is, is_tuple(I)],
              Op =:= call orelse Op =:= call_ext],
    ?assertEqual([], Bad).

%% Flat stack at a depth that would blow a body-recursive version.
tail_calls_do_not_grow_the_stack_test() ->
    M = build_and_load(series_src(), 'FibL'),
    Self = self(),
    Pid = spawn(fun() ->
                    _ = M:'Fib'(50000),
                    {stack_size, S} = erlang:process_info(self(), stack_size),
                    Self ! {stack, S}
                end),
    receive {stack, S} -> ?assert(S < 100)
    after 60000 -> exit({timeout, Pid}) end.


%%% ---------------------------------------------------------------------------
%%% F20 / ticket 54 — the checker sees a list's length, in both directions.
%%%
%%% Measured at the boundary: a source string in, a diagnostic or a running
%%% function out. Nothing here reaches into `bs_types`, so the spine
%%% representation can be replaced again without rewriting these.
%%% ---------------------------------------------------------------------------

diags(Src) ->
    {ok, Toks, _} = bs_lexer:string(Src),
    {ok, Decls} = bs_parser:parse(Toks),
    case bs_check:check(Decls) of
        {ok, _, Ds} -> Ds;
        {error, Ds} -> Ds
    end.

errors(Src) -> [D || D <- diags(Src), element(1, D) =:= error].

shape_src(Clauses) ->
    "module Sh\npublic atom Shape(list<int> xs)\n" ++ Clauses.

%% THE REPRO. `[]` beside a two-element prefix was proved exhaustive and crashed
%% on `[7]`; now it is an error, and the residual NAMES the missing case rather
%% than only refusing. Asserting the text is the point — a residual that merely
%% says "not exhaustive" is a cheaper decision than the one ticket 54 took.
a_two_element_prefix_does_not_cover_a_one_element_list_test() ->
    Src = shape_src("Shape([]) -> :empty\nShape([a, b, ..]) -> :many\n"),
    [{error, _, 'Shape', {inexhaustive, Residual, _}}] = errors(Src),
    %% The parentheses are the ARGUMENT LIST, not the list type: a residual is a
    %% product over the parameters, and this function has one. `check-list-length.sh`
    %% asserts the user-visible form, `Shape([int]) -> ...`; this asserts the
    %% type, and the distinction that matters is `[int]` against `[int, ..]` —
    %% exactly-one against one-or-more, which is the whole defect.
    ?assertEqual("([int])", bs_types:to_string(Residual)).

%% THE OTHER DIRECTION. A closed prefix used to subtract nothing at all, so this
%% set left the same residual as `[]` alone. Exactly-nothing plus exactly-one
%% plus two-or-more is every list. If this fails while the one above passes, the
%% fix went in one direction only — which is ticket 54's standing warning.
closed_and_open_prefixes_compose_to_every_list_test() ->
    Src = shape_src("Shape([]) -> :empty\n"
                    "Shape([a]) -> :one\n"
                    "Shape([a, b, ..]) -> :many\n"),
    ?assertEqual([], errors(Src)).

%% SYMPTOM FIVE, and the worst of them: a correct clause reported dead. `erlc`
%% stays silent here and the program returns `:one`, so the compiler was telling
%% a right program it was wrong.
a_clause_that_matches_is_not_called_unreachable_test() ->
    Src = shape_src("Shape([]) -> :empty\n"
                    "Shape([a, b, ..]) -> :many\n"
                    "Shape([a, ..]) -> :one\n"),
    ?assertEqual([], [D || D <- diags(Src), element(1, D) =:= warning]).

%% `[a, b]` is exactly two — the spelling Erlang, Elixir, C# and Gleam all agree
%% on, and the one B# alone refused. Measured by running it.
a_closed_list_pattern_means_exactly_that_length_test() ->
    Src = "module Cl\n"
          "public atom Shape(list<int> xs)\n"
          "Shape([]) -> :empty\n"
          "Shape([a]) -> :one\n"
          "Shape([a, b]) -> :two\n"
          "Shape([a, b, c, ..]) -> :many\n",
    M = build_and_load(Src, 'Cl'),
    ?assertEqual(empty, M:'Shape'([])),
    ?assertEqual(one,   M:'Shape'([7])),
    ?assertEqual(two,   M:'Shape'([7, 8])),
    ?assertEqual(many,  M:'Shape'([7, 8, 9])),
    ?assertEqual(many,  M:'Shape'([7, 8, 9, 10])).

%% Ticket 53's route table, in the spelling C# and TypeScript programmers
%% expect. The property that ticket cared about is the third assertion:
%% `/orders/42/lines` must fall through rather than be swallowed by `:show`.
a_route_table_dispatches_on_path_length_test() ->
    Src = "module Rt\n"
          "public atom Route(list<string> path)\n"
          "Route([\"orders\"]) -> :index\n"
          "Route([\"orders\", id]) -> :show\n"
          "Route(_) -> :not_found\n",
    M = build_and_load(Src, 'Rt'),
    ?assertEqual(index,     M:'Route'([<<"orders">>])),
    ?assertEqual(show,      M:'Route'([<<"orders">>, <<"42">>])),
    ?assertEqual(not_found, M:'Route'([<<"orders">>, <<"42">>, <<"lines">>])),
    ?assertEqual(not_found, M:'Route'([])).

%% The retired forms name their replacement. `..[]` was ticket 53's answer and
%% sat in four clauses of exemplar 25a, so it will be typed again from memory.
a_closed_rest_is_retired_and_names_the_fix_test() ->
    Src = shape_src("Shape([a, ..[]]) -> :one\nShape(_) -> :o\n"),
    {ok, Toks, _} = bs_lexer:string(Src),
    {error, {_, _, Msg}} = bs_parser:parse(Toks),
    ?assert(string:find(lists:flatten(Msg), "`..[]` is retired") =/= nomatch).

a_nested_rest_pattern_is_retired_and_names_the_fix_test() ->
    Src = shape_src("Shape([a, ..[b, ..t]]) -> :two\nShape(_) -> :o\n"),
    {ok, Toks, _} = bs_lexer:string(Src),
    {error, {_, _, Msg}} = bs_parser:parse(Toks),
    ?assert(string:find(lists:flatten(Msg), "a rest is `..` or `..name`")
            =/= nomatch).

%% DECISION 5 — the closed-residual catch-all rule reaches lists. Over a closed
%% element type the residual is a finite set of lists, so `_` hides cases the
%% compiler can name. The second test is the control: over `list<int>` the
%% element is unbounded, the residual stays open, and `_` is still legal. A rule
%% that fired on every list would pass the first test and fail the second.
a_catch_all_over_a_closed_list_residual_is_refused_test() ->
    Src = "module Cb\npublic atom F(list<bool> xs)\n"
          "F([]) -> :e\nF([a, b, ..]) -> :m\nF(_) -> :o\n",
    ?assertMatch([{error, _, 'F', {catch_all_over_closed, _, _}}], errors(Src)).

a_catch_all_over_an_open_list_residual_is_still_legal_test() ->
    Src = shape_src("Shape([]) -> :empty\nShape([a, b, ..]) -> :many\n"
                    "Shape(_) -> :o\n"),
    ?assertEqual([], errors(Src)).

%%% --- F20, the half that is not a function head ------------------------------
%%%
%%% Switch arms are a SEPARATE residual loop (`arms/8`, not `walk/5`), and every
%%% test above goes through a head. TOUR chapter 8 states the premise this
%%% feature leans on — "a switch arm is the clause head's own pattern grammar,
%%% one level down" — so it is asserted here rather than inferred. A compiler
%%% that proved length in heads and not in arms would be worse than one that
%%% proved it nowhere, because nobody would expect the asymmetry.

switch_src(Arms) ->
    "module Sw\npublic atom Shape(list<int> xs)\nShape(xs) -> xs switch {\n"
        ++ Arms ++ "\n}\n".

a_switch_arm_sees_list_length_too_test() ->
    Src = switch_src("    [] => :empty,\n"
                     "    [a, b, ..] => :many"),
    [{error, _, 'Shape', {switch_inexhaustive, Residual}}] = errors(Src),
    ?assertEqual("[int]", bs_types:to_string(Residual)).

a_switch_over_every_length_needs_no_catch_all_test() ->
    Src = switch_src("    [] => :empty,\n"
                     "    [a] => :one,\n"
                     "    [a, b, ..] => :many"),
    ?assertEqual([], errors(Src)).

%% TICKET 54 PREDICTED SIXTEEN HEADS HERE AND THERE ARE TWO.
%%
%% Decision 5 warned the closed-residual rule would multiply against ticket 43's
%% cap — "a four-atom union at length two is sixteen heads". It is not: a spine
%% holds a union AT EACH POSITION rather than enumerating the cross-product, so
%% the residual grows with the number of missing LENGTHS, not with the number of
%% missing value combinations. This test exists to keep that true, because the
%% obvious "simplification" of expanding spines into products would pass every
%% other test in this file and quietly restore the blow-up.
a_residual_over_a_union_element_does_not_enumerate_products_test() ->
    Src = "module Cap\ntype Q = :a | :b | :c | :d\n"
          "public atom F(list<Q> xs)\n"
          "F([]) -> :e\nF([x, y, z, ..]) -> :m\n",
    [{error, _, 'F', {inexhaustive, Residual, _}}] = errors(Src),
    %% Two spines — lengths 1 and 2 — each carrying the whole union inline at
    %% every position. Sixteen products would be sixteen bracketed groups.
    ?assertEqual("([:a | :b | :c | :d] | [:a | :b | :c | :d, :a | :b | :c | :d])",
                 bs_types:to_string(Residual)).

%% `[a, b]` used to be a grammar error, so this path went from refused outright
%% to type-checked with no test on the way through. The complement of
%% exactly-two is shorter, shorter, longer — and it has to read as one thing.
a_refutable_closed_bind_names_the_complement_test() ->
    Src = "module Bd\npublic int F(list<int> xs)\n"
          "F(xs) ->\n    var [a, b] = xs\n    a + b\n",
    [{error, _, 'F', {bind_may_fail, Residual}}] = errors(Src),
    ?assertEqual("[] | [int] | [int, int, int, ..]",
                 bs_types:to_string(Residual)).
