%%% F42 — the boundary guard on a foreign return (ticket 18 §2, ENG-357).
%%%
%%% Ticket 18 §2 lets a foreign declaration promise only what one BEAM guard
%%% decides in O(1) "so the compiler checks it". F40 built the refusal that
%%% narrows the promise; this is the check that makes the promise true. A
%%% foreign call whose declaration names no failure channel is wrapped in a
%%% `case` whose single clause carries the guard the declared type spells, so
%%% a value that does not inhabit the type raises `{case_clause, Value}` at
%%% the call — ticket 18 §1 rule C: "a wrong term from outside will crash,
%%% not always at the call site, but never silently".
%%%
%%% ASSERTED AT THE BOUNDARY: source text in, a loaded `.beam` called, and
%%% what it returns or raises compared; or the CLI run and its printed output
%%% read. Nothing here pins a function in `bs_emit`. One test reads the emitted
%%% abstract code, for the same reason F19.9 does: "no guard" has no observable
%%% value beyond every value passing, and the sibling assertion that a `term`
%%% declaration emits no `case` at all is what makes that visible.
%%%
%%% What is NOT asserted, deliberately: a foreign return declared
%%% `result<T, foreign_error>` is not guarded by this feature. What a failed
%%% guard becomes under a declared channel is ticket 74's question, and a test
%%% pinning the unguarded arm would certify the missing check as intended.

-module(foreign_guard_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, run_cli/1, with_src/3]).

%%% ---------------------------------------------------------------------------
%%% Fixture
%%%
%%% One foreign function, `erlang:hd/1`, declared with a different return type
%%% per test. The caller hands it a one-element list, so the value that comes
%%% back is the test's choice and the declaration is the only thing that
%%% varies. The type declarations are the ones LANGUAGE.md §11 and the ENG-357
%%% grill name as admissible: every one is decided by a fixed guard sequence.
%%% ---------------------------------------------------------------------------

src(Ret) ->
    "module Fg\n"
    "type Octet = int where value >= 0 and value <= 255\n"
    "type Status = :up | :down\n"
    "type Maybe = int | :undefined\n"
    "type Reply = (:ok, int) | (:error, atom)\n"
    "type Request = { Method: binary, Path: binary }\n"
    "using :erlang {\n"
    "    " ++ Ret ++ " hd(list<term> xs)\n"
    "}\n"
    "public " ++ Ret ++ " First(list<term> xs)\n"
    "First(xs) -> :erlang.hd(xs)\n".

first(Ret) ->
    M = build_and_load(src(Ret), 'Fg'),
    fun(V) -> M:'First'([V]) end.

%%% ---------------------------------------------------------------------------
%%% F42.1 — the program ENG-357 measured: `int float(int x)` printed `3.0`
%%% ---------------------------------------------------------------------------

%% THE WHOLE FEATURE, IN ONE ASSERTION. On `f68d0cb` this printed `3.0` from a
%% function declared `int`. The crash is the BEAM's own `case_clause`, which is
%% what an arm-less `case` raises — the same reason a switch emits no failure
%% arm and a clause head's guard raises `function_clause`.
a_float_from_a_function_declared_int_crashes_test() ->
    First = first("int"),
    ?assertEqual(3, First(3)),
    ?assertError({case_clause, 3.0}, First(3.0)).

%% The same program through the CLI, so what the author sees is what is
%% asserted: the crash line and the exit status, not a value.
the_cli_reports_the_crash_and_exits_one_test() ->
    Src = "module Guard\n"
          "using :erlang {\n"
          "    int float(int x)\n"
          "}\n"
          "public int Widen(int x)\n"
          "Widen(x) -> :erlang.float(x)\n",
    R = with_src("Guard.bs", Src,
                 fun(Path, Out) ->
                     run_cli("-o " ++ Out ++ " " ++ Path ++ " Widen 3")
                 end),
    ?assertNotEqual(nomatch, string:find(R, "crashed: case_clause 3.0")),
    ?assertNotEqual(nomatch, string:find(R, "rc:1")).

%%% ---------------------------------------------------------------------------
%%% F42.2 – F42.4 — the scalar kinds, and a refinement
%%% ---------------------------------------------------------------------------

%% F42.2. `binary` is `is_binary/1`; an atom is not one.
a_binary_declaration_refuses_an_atom_test() ->
    First = first("binary"),
    ?assertEqual(<<"x">>, First(<<"x">>)),
    ?assertError({case_clause, nope}, First(nope)).

%% F42.3. A finite atom union is an equality per member: `:up | :down` admits
%% neither a third atom nor an integer.
a_finite_atom_union_admits_only_its_members_test() ->
    First = first("Status"),
    ?assertEqual(up, First(up)),
    ?assertEqual(down, First(down)),
    ?assertError({case_clause, sideways}, First(sideways)),
    ?assertError({case_clause, 1}, First(1)).

%% F42.4. A refined int carries its bounds into the guard (F37 emits the same
%% comparisons at an exported parameter): 256 is an integer and still refused.
a_refined_int_carries_its_bounds_test() ->
    First = first("Octet"),
    ?assertEqual(0, First(0)),
    ?assertEqual(255, First(255)),
    ?assertError({case_clause, 256}, First(256)),
    ?assertError({case_clause, -1}, First(-1)),
    ?assertError({case_clause, 7.0}, First(7.0)).

%%% ---------------------------------------------------------------------------
%%% F42.5 – F42.6 — a union across kinds, and a tuple union
%%% ---------------------------------------------------------------------------

%% F42.5. `int | :undefined` is a disjunction of two kind tests, the shape
%% ticket 18 §2 names for `erlang:whereis/1`.
a_union_across_kinds_is_a_disjunction_test() ->
    First = first("Maybe"),
    ?assertEqual(4, First(4)),
    ?assertEqual(undefined, First(undefined)),
    ?assertError({case_clause, 1.5}, First(1.5)),
    ?assertError({case_clause, other}, First(other)).

%% F42.6. A tuple member is arity plus one test per component; a union of
%% tuples is a disjunction over the products. `(:ok, 1.5)` has the right tag
%% and the wrong payload and is refused for it.
a_tuple_union_tests_arity_and_every_component_test() ->
    First = first("Reply"),
    ?assertEqual({ok, 1}, First({ok, 1})),
    ?assertEqual({error, nope}, First({error, nope})),
    ?assertError({case_clause, {ok, 1.5}}, First({ok, 1.5})),
    ?assertError({case_clause, {ok, 1, 2}}, First({ok, 1, 2})),
    ?assertError({case_clause, {error, <<"nope">>}}, First({error, <<"nope">>})),
    ?assertError({case_clause, ok}, First(ok)).

%%% ---------------------------------------------------------------------------
%%% F42.7 — a fixed field set emits ticket 26's boundary guard, never the
%%% pattern guard
%%% ---------------------------------------------------------------------------

%% `is_map` plus one value test per declared field, and NO `map_size` (26 §1:
%% the exact-set test is emitted only where a codegen obligation consumes the
%% record, and a foreign wrapper returns the value). So a cowboy request with a
%% dozen keys beyond `Method` and `Path` passes, which is what ticket 72's
%% withdrawal records; a missing field or a wrongly typed one is refused.
a_fixed_field_set_admits_extra_keys_and_refuses_a_wrong_field_test() ->
    First = first("Request"),
    Req   = #{'Method' => <<"GET">>, 'Path' => <<"/">>},
    Wide  = Req#{host => <<"example">>, port => 80, peer => {127, 0, 0, 1}},
    ?assertEqual(Req, First(Req)),
    ?assertEqual(Wide, First(Wide)),
    ?assertError({case_clause, #{'Method' := <<"GET">>}},
                 First(#{'Method' => <<"GET">>})),
    ?assertError({case_clause, #{'Method' := get, 'Path' := <<"/">>}},
                 First(#{'Method' => get, 'Path' => <<"/">>})),
    ?assertError({case_clause, []}, First([])).

%%% ---------------------------------------------------------------------------
%%% F42.8 – F42.9 — the two containers one guard decides
%%% ---------------------------------------------------------------------------

%% F42.8. `list<term>` is `is_list/1` and nothing per element — the element is
%% `term`, so there is nothing to inspect, which is why F40 admits it.
a_list_of_term_is_one_list_test_test() ->
    First = first("list<term>"),
    ?assertEqual([], First([])),
    ?assertEqual([1, two, <<"3">>], First([1, two, <<"3">>])),
    ?assertError({case_clause, nope}, First(nope)),
    ?assertError({case_clause, {}}, First({})).

%% F42.9. `map<term, term>` is `is_map/1` and nothing per key, for the same
%% reason.
a_map_of_term_is_one_map_test_test() ->
    First = first("map<term, term>"),
    ?assertEqual(#{}, First(#{})),
    ?assertEqual(#{a => 1}, First(#{a => 1})),
    ?assertError({case_clause, []}, First([])).

%%% ---------------------------------------------------------------------------
%%% F42.10 — `term` promises nothing and is not guarded
%%% ---------------------------------------------------------------------------

%% Every value passes, and the emitted code carries no `case` around the call:
%% a guard that cannot fail would be a `case` for nothing.
a_term_declaration_emits_no_guard_test() ->
    First = first("term"),
    ?assertEqual(3.0, First(3.0)),
    ?assertEqual(nope, First(nope)),
    {ok, {'Fg', [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(bs_test_support:run_root() ++ "/Fg.beam", [abstract_code]),
    ?assertEqual(0, count_cases(Forms)).

count_cases({'case', _, _, _}) -> 1;
count_cases(T) when is_tuple(T) -> count_cases(tuple_to_list(T));
count_cases(L) when is_list(L)  -> lists:sum([count_cases(E) || E <- L]);
count_cases(_)                  -> 0.

%%% ---------------------------------------------------------------------------
%%% F42.11 — two guarded calls in one clause, and one nested in another
%%% ---------------------------------------------------------------------------

%% The `case` binds a synthesised variable, and a variable bound in a `case`
%% with one clause is exported from it. A second `case` binding the same name
%% would MATCH against the first's value rather than bind a fresh one, so the
%% names are numbered per module, the way F19's wrapper variables are. Two
%% guards in one body and one nested inside another's argument all run.
two_guarded_calls_in_one_clause_and_a_nested_one_run_test() ->
    Src = "module Twice\n"
          "using :erlang {\n"
          "    int hd(list<term> xs)\n"
          "}\n"
          "using :lists {\n"
          "    int last(list<term> xs)\n"
          "    list<term> reverse(list<term> xs)\n"
          "}\n"
          "public int Ends(list<term> xs)\n"
          "Ends(xs) -> :erlang.hd(xs) + :lists.last(xs)\n"
          "public int LastOf(list<term> xs)\n"
          "LastOf(xs) -> :erlang.hd(:lists.reverse(xs))\n",
    M = build_and_load(Src, 'Twice'),
    ?assertEqual(5, M:'Ends'([2, 9, 3])),
    ?assertEqual(3, M:'LastOf'([2, 9, 3])),
    ?assertError({case_clause, 3.0}, M:'Ends'([2, 9, 3.0])),
    ?assertError({case_clause, 2.0}, M:'LastOf'([3, 9, 2.0])).

%%% ---------------------------------------------------------------------------
%%% F42.12 — the corpus is unchanged by the guard
%%% ---------------------------------------------------------------------------

%% `examples/Foreign`'s `Size` declares no channel and still dies with
%% `badarg` on an atom: the guard sits AFTER the call, so a throw inside the
%% call is the same throw it always was.
a_throw_inside_the_call_is_still_that_throw_test() ->
    Src = "module Sz\n"
          "using :erlang {\n"
          "    int byte_size(binary b)\n"
          "}\n"
          "public int Size(binary b)\n"
          "Size(b) -> :erlang.byte_size(b)\n",
    M = build_and_load(Src, 'Sz'),
    ?assertEqual(3, M:'Size'(<<"abc">>)),
    ?assertError(badarg, M:'Size'(not_a_binary)).
