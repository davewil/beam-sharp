%%% F45 — calls instantiate polymorphic function signatures.
%%% Scenarios: compiler/features/F45-polymorphic-signatures.md

-module(poly_signature_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, check_only/1, run_cli/1]).

%%% ---------------------------------------------------------------------------
%%% Helpers
%%% ---------------------------------------------------------------------------

has(Out, S)   -> ?assert(string:find(Out, S) =/= nomatch).
ok_rc(Out)    -> has(Out, "rc:0").
bad_rc(Out)   -> has(Out, "rc:1").

tags(Diags) -> [element(1, D) || {error, _, _, D} <- Diags, is_tuple(D)]
               ++ [D || {error, _, _, D} <- Diags, is_atom(D)].

errors(Src) ->
    Diags = case check_only(Src) of
                {ok, _, Ds}  -> Ds;
                {error, Ds}  -> Ds
            end,
    [D || D <- Diags, element(1, D) =:= error].

in_dir(Files) ->
    Root = bs_test_support:fixture_root(),
    Paths = [bs_test_support:place(Root, N, S) || {N, S} <- Files],
    {Root, hd(Paths)}.

pick_src(Ret) ->
    "module Pick\n"
    "public T Pick<T>(T a, T b)\n"
    "Pick(a, _) -> a\n"
    "public " ++ Ret ++ " Both(int n)\n"
    "Both(n) -> Pick(n, :a)\n".

rows_src() ->
    "module Rows\n"
    "type FetchError = (:unknown_status, atom)\n"
    "public result<list<atom>, FetchError> Names(list<(int, atom)> rows)\n"
    "Names([])                -> []\n"
    "Names([(_, s), ..rest])  -> Prepend(s, Names(rest))\n"
    "public result<list<int>, FetchError> Ids(list<(int, atom)> rows)\n"
    "Ids([])                -> []\n"
    "Ids([(id, _), ..rest]) -> Prepend(id, Ids(rest))\n"
    "private result<list<T>, E> Prepend<T, E>(T row, result<list<T>, E> rest)\n"
    "Prepend(row, (:error, e)) -> (:error, e)\n"
    "Prepend(row, rows)        -> [row, ..rows]\n".

%%% ---------------------------------------------------------------------------
%%% F45.1 — one `Prepend` serves two element types.
%%% ---------------------------------------------------------------------------

%% A return widened to `list<term>` cannot satisfy these callers.
one_prepend_serves_two_element_types_test() ->
    M = build_and_load(rows_src(), 'Rows'),
    ?assertEqual([1, 2], M:'Ids'([{1, placed}, {2, lost}])),
    ?assertEqual([placed, lost], M:'Names'([{1, placed}, {2, lost}])).

the_corpus_program_runs_at_both_types_test() ->
    Root = bs_test_support:project_root() ++ "/examples",
    File = Root ++ "/Shop/Rows/Rows.bs",
    Rowed = run_cli("--src-root " ++ Root ++ " " ++ File
                    ++ " Rowed \"[(1, :placed), (2, :shipped)]\""),
    ok_rc(Rowed),
    has(Rowed, "Status = :placed"),
    Ids = run_cli("--src-root " ++ Root ++ " " ++ File
                  ++ " Ids \"[(1, :placed), (2, :lost)]\""),
    ok_rc(Ids),
    has(Ids, "[1, 2]").

%%% ---------------------------------------------------------------------------
%%% F45.2 — repeated variables join the argument types.
%%% ---------------------------------------------------------------------------

a_variable_twice_joins_test() ->
    M = build_and_load(pick_src("int | :a"), 'Pick'),
    ?assertEqual(3, M:'Both'(3)).

%% A narrower caller rules out accepting every return declaration.
the_join_is_the_return_and_narrower_is_refused_test() ->
    Diags = errors(pick_src("int")),
    ?assert(lists:member(return_not_declared, tags(Diags))),
    Out = run_cli_src(pick_src("int")),
    bad_rc(Out),
    has(Out, "int | :a Both(int n)").

the_join_collapses_when_the_arguments_agree_test() ->
    Src = "module Pick\n"
          "public T Pick<T>(T a, T b)\n"
          "Pick(a, _) -> a\n"
          "public int Same(int n)\n"
          "Same(n) -> Pick(n, n + 1)\n",
    ?assertEqual([], errors(Src)).

%%% ---------------------------------------------------------------------------
%%% F45.3 — `First(:nothing)` returns exactly `:nothing`.
%%% ---------------------------------------------------------------------------

least_keeps_the_return_informative_test() ->
    Src = "module First\n"
          "public option<T> First<T>(option<T> o)\n"
          "First(o) -> o\n"
          "public :nothing Empty()\n"
          "Empty() -> First(:nothing)\n",
    ?assertEqual([], errors(Src)).

%% Refusing `int` rules out accepting every declaration for the same call.
least_control_a_wrong_declaration_is_still_refused_test() ->
    Src = "module First\n"
          "public option<T> First<T>(option<T> o)\n"
          "First(o) -> o\n"
          "public int Empty()\n"
          "Empty() -> First(:nothing)\n",
    ?assert(lists:member(return_not_declared, tags(errors(Src)))).

%%% ---------------------------------------------------------------------------
%%% F45.4 — arguments outside the parameter extent are refused.
%%% ---------------------------------------------------------------------------

an_argument_outside_the_extent_is_refused_test() ->
    Src = "module Rows\n"
          "private result<list<T>, E> Prepend<T, E>(T row, result<list<T>, E> rest)\n"
          "Prepend(row, (:error, e)) -> (:error, e)\n"
          "Prepend(row, rows)        -> [row, ..rows]\n"
          "public term Bad(int n)\n"
          "Bad(n) -> Prepend(n, n)\n",
    Diags = errors(Src),
    ?assertMatch([{error, _, 'Bad', {arg_not_accepted, 'Prepend', 2, _, _}}], Diags).

a_bare_variable_rejects_nothing_test() ->
    Src = "module Pick\n"
          "public T Pick<T>(T a, T b)\n"
          "Pick(a, _) -> a\n"
          "public term Any(list<int> xs, (int, atom) t)\n"
          "Any(xs, t) -> Pick(xs, t)\n",
    ?assertEqual([], errors(Src)).

%%% ---------------------------------------------------------------------------
%%% F45.5 — declarations are checked for every instantiation.
%%% ---------------------------------------------------------------------------

the_declaration_is_checked_for_every_instantiation_test() ->
    %% Both list shapes are covered; the error tuple remains uncovered for
    %% every instantiation.
    Src = "module Rows\n"
          "private result<list<T>, E> Prepend<T, E>(T row, result<list<T>, E> rest)\n"
          "Prepend(row, [])          -> [row]\n"
          "Prepend(row, [x, ..xs])   -> [row, x, ..xs]\n",
    ?assert(lists:member(inexhaustive, tags(errors(Src)))).

a_body_outside_the_declared_shape_is_refused_at_the_declaration_test() ->
    Src = "module Rows\n"
          "private list<T> Only<T>(T row, list<T> rest)\n"
          "Only(row, rest) -> (:error, row)\n",
    ?assert(lists:member(return_not_declared, tags(errors(Src)))).

%%% ---------------------------------------------------------------------------
%%% F45.6 — a bare type variable admits only a binding pattern.
%%% ---------------------------------------------------------------------------

a_pattern_on_a_bare_variable_is_refused_test() ->
    Src = "module Pick\n"
          "public T Pick<T>(T a, T b)\n"
          "Pick(1, _) -> 1\n"
          "Pick(_, b) -> b\n",
    Diags = errors(Src),
    ?assertMatch([{error, _, 'Pick', {pattern_on_type_variable, 'T', 1}}], Diags).

%% List structure remains matchable even when the element type is unknown.
structure_around_a_variable_matches_freely_test() ->
    Src = "module Heads\n"
          "public option<T> First<T>(list<T> xs)\n"
          "First([])       -> :nothing\n"
          "First([h, ..]) -> h\n",
    ?assertEqual([], errors(Src)).

%%% ---------------------------------------------------------------------------
%%% F45.10 — every variable must appear in a parameter.
%%% ---------------------------------------------------------------------------

a_variable_only_in_the_return_is_refused_test() ->
    Src = "module Empty\n"
          "public list<T> Empty<T>()\n"
          "Empty() -> []\n",
    ?assertMatch([{error, _, 'Empty', {unrecoverable_type_variable, 'T'}}],
                 errors(Src)).

%% A variable inside a parameter constructor is still recoverable.
a_variable_under_a_constructor_is_recoverable_test() ->
    Src = "module Heads\n"
          "public list<T> Rest<T>(list<T> xs)\n"
          "Rest([])        -> []\n"
          "Rest([_, ..t]) -> t\n",
    ?assertEqual([], errors(Src)).

%%% ---------------------------------------------------------------------------
%%% F45.11 — codegen obligations over type variables are refused.
%%% ---------------------------------------------------------------------------

validate_as_over_a_variable_is_refused_test() ->
    Src = "module Obl\n"
          "public result<T, ValidationError> Check<T>(T x)\n"
          "Check(x) -> ValidateAs<T>(x)\n",
    ?assertMatch([{error, _, 'Check', {obligation_over_type_variable, 'ValidateAs', 'T'}}],
                 errors(Src)).

parse_atom_over_a_variable_is_refused_test() ->
    Src = "module Obl\n"
          "public option<T> Read<T>(T x, string s)\n"
          "Read(_, s) -> ParseAtom<T>(s)\n",
    ?assertMatch([{error, _, 'Read', {obligation_over_type_variable, 'ParseAtom', 'T'}}],
                 errors(Src)).

%% A ground argument remains legal inside a polymorphic function.
a_ground_obligation_inside_a_polymorphic_function_stands_test() ->
    Src = "module Obl\n"
          "public (T, result<int, ValidationError>) Both<T>(T x, term raw)\n"
          "Both(x, raw) -> (x, ValidateAs<int>(raw))\n",
    ?assertEqual([], errors(Src)).

%%% ---------------------------------------------------------------------------
%%% F45.7 — the API prints the written polymorphic signature.
%%% ---------------------------------------------------------------------------

api_prints_the_written_signature_test() ->
    {Root, Main} = in_dir([{"Pick.bs", pick_src("int | :a")}]),
    Out = run_cli("--src-root " ++ Root ++ " --api " ++ Main),
    ok_rc(Out),
    has(Out, "T Pick<T>(T, T)\n"),
    has(Out, ":a | int Both(int)\n").

%%% ---------------------------------------------------------------------------
%%% F45.8 — dependents instantiate imported signatures.
%%% ---------------------------------------------------------------------------

a_dependent_instantiates_an_imported_signature_test() ->
    Lib = "module Lib\n"
          "public option<T> First<T>(list<T> xs)\n"
          "First([])       -> :nothing\n"
          "First([h, ..]) -> h\n",
    App = "module App\n"
          "using Lib\n"
          "public int | :nothing Head(list<int> xs)\n"
          "Head(xs) -> First(xs)\n",
    {Root, _} = in_dir([{"Lib.bs", Lib}, {"App.bs", App}]),
    Out = run_cli("--src-root " ++ Root ++ " " ++ Root ++ "/App/App.bs Head \"[4, 5]\""),
    ok_rc(Out),
    has(Out, "4\n").

%% A narrower dependent checks that the import preserves the template.
a_dependent_declared_narrower_is_refused_test() ->
    Lib = "module Lib\n"
          "public option<T> First<T>(list<T> xs)\n"
          "First([])       -> :nothing\n"
          "First([h, ..]) -> h\n",
    App = "module App\n"
          "using Lib\n"
          "public int Head(list<int> xs)\n"
          "Head(xs) -> First(xs)\n",
    {Root, _} = in_dir([{"Lib.bs", Lib}, {"App.bs", App}]),
    Out = run_cli("--src-root " ++ Root ++ " " ++ Root ++ "/App/App.bs Head \"[4]\""),
    bad_rc(Out),
    has(Out, "int | :nothing Head(list<int> xs)").

%%% ---------------------------------------------------------------------------
%%% F45.9 — emitted specs erase variables and the module loads.
%%% ---------------------------------------------------------------------------

the_emitted_spec_erases_the_variables_test() ->
    M = build_and_load(pick_src("int | :a"), 'Pick'),
    ?assertEqual(placed, M:'Pick'(placed, 7)).

%%% ---------------------------------------------------------------------------
%%% What a single-file source compiles to through the CLI
%%% ---------------------------------------------------------------------------

run_cli_src(Src) ->
    {Root, Main} = in_dir([{"in.bs", Src}]),
    run_cli("--src-root " ++ Root ++ " -o " ++ Root ++ "/out " ++ Main).
