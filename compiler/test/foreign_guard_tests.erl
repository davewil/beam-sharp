%%% Scenarios: compiler/features/F42-foreign-return-guard.md
%%% Scenarios: compiler/features/F52-channelled-foreign-return-guard.md
%%% F42 — foreign returns enforce their declared types.

-module(foreign_guard_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, run_cli/1, with_src/3]).

%%% Fixture
%%% erlang:hd/1 lets each test choose the return value independently of the
%%% declared return type.

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

%%% F42.1 — a float returned as int crashes.

a_float_from_a_function_declared_int_crashes_test() ->
    First = first("int"),
    ?assertEqual(3, First(3)),
    ?assertError({case_clause, 3.0}, First(3.0)).

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

%%% F42.2–F42.4 — scalar kinds and refinements guard returns.

%% F42.2 — a binary declaration rejects an atom.
a_binary_declaration_refuses_an_atom_test() ->
    First = first("binary"),
    ?assertEqual(<<"x">>, First(<<"x">>)),
    ?assertError({case_clause, nope}, First(nope)).

%% F42.3 — a finite atom union admits only its members.
a_finite_atom_union_admits_only_its_members_test() ->
    First = first("Status"),
    ?assertEqual(up, First(up)),
    ?assertEqual(down, First(down)),
    ?assertError({case_clause, sideways}, First(sideways)),
    ?assertError({case_clause, 1}, First(1)).

%% F42.4 — a refined int enforces its bounds and kind.
a_refined_int_carries_its_bounds_test() ->
    First = first("Octet"),
    ?assertEqual(0, First(0)),
    ?assertEqual(255, First(255)),
    ?assertError({case_clause, 256}, First(256)),
    ?assertError({case_clause, -1}, First(-1)),
    ?assertError({case_clause, 7.0}, First(7.0)).

%%% F42.5–F42.6 — unions guard each alternative.

%% F42.5 — a union across kinds accepts either kind.
a_union_across_kinds_is_a_disjunction_test() ->
    First = first("Maybe"),
    ?assertEqual(4, First(4)),
    ?assertEqual(undefined, First(undefined)),
    ?assertError({case_clause, 1.5}, First(1.5)),
    ?assertError({case_clause, other}, First(other)).

%% F42.6 — tuple unions check arity and every component.
a_tuple_union_tests_arity_and_every_component_test() ->
    First = first("Reply"),
    ?assertEqual({ok, 1}, First({ok, 1})),
    ?assertEqual({error, nope}, First({error, nope})),
    ?assertError({case_clause, {ok, 1.5}}, First({ok, 1.5})),
    ?assertError({case_clause, {ok, 1, 2}}, First({ok, 1, 2})),
    ?assertError({case_clause, {error, <<"nope">>}}, First({error, <<"nope">>})),
    ?assertError({case_clause, ok}, First(ok)).

%%% F42.7 — a fixed field set admits extra keys and checks declared fields.

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

%%% F42.8–F42.9 — containers of term require only a container test.

%% F42.8 — a list of term requires only a list test.
a_list_of_term_is_one_list_test_test() ->
    First = first("list<term>"),
    ?assertEqual([], First([])),
    ?assertEqual([1, two, <<"3">>], First([1, two, <<"3">>])),
    ?assertError({case_clause, nope}, First(nope)),
    ?assertError({case_clause, {}}, First({})).

%% F42.9 — a map of term requires only a map test.
a_map_of_term_is_one_map_test_test() ->
    First = first("map<term, term>"),
    ?assertEqual(#{}, First(#{})),
    ?assertEqual(#{a => 1}, First(#{a => 1})),
    ?assertError({case_clause, []}, First([])).

%%% F42.10 — term emits no guard.

%% Runtime values cannot distinguish no guard from a guard that always passes.
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

%%% F42.11 — sequential and nested guarded calls run independently.

%% A single-clause case exports its variable binding. Reusing that name in
%% another case would match the first value instead of binding a fresh one.
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

%%% F42.12 — exceptions inside the callee propagate unchanged.

%% The return guard runs after the call, so it cannot intercept callee errors.
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

%%% F52.1–F52.3 — return guards sit outside the exception channel.

%% F52.1 — a channelled declaration rejects values outside its type.
a_channelled_declaration_refuses_a_value_outside_its_type_test() ->
    First = first("result<int, foreign_error>"),
    ?assertEqual(3, First(3)),
    ?assertError({case_clause, 3.0}, First(3.0)).

%% F52.2 — callee exceptions pass through the declared channel.
%% This checks channel preservation; it does not distinguish wrapper order.
a_real_exception_still_arrives_through_the_channel_test() ->
    M = build_and_load(src("result<int, foreign_error>"), 'Fg'),
    ?assertEqual({error, {error, badarg}}, M:'First'([])).

%% F52.3 — the CLI reports an invalid channelled return as a crash.
%% read_file returns an ok tuple, outside the declared type. Reader.bs is
%% the input file too, so the call always has a real file to open.
the_cli_reports_the_crash_on_a_channelled_return_test() ->
    Src = "module Reader\n"
          "using :file {\n"
          "    result<binary, foreign_error> read_file(binary path)\n"
          "}\n"
          "public result<binary, foreign_error> Slurp(binary path)\n"
          "Slurp(path) -> :file.read_file(path)\n",
    R = with_src("Reader.bs", Src,
                 fun(Path, Out) ->
                     run_cli("-o " ++ Out ++ " " ++ Path ++
                             " Slurp '<<\"" ++ Path ++ "\">>'")
                 end),
    ?assertNotEqual(nomatch, string:find(R, "crashed: case_clause (:ok,")),
    ?assertNotEqual(nomatch, string:find(R, "rc:1")).
