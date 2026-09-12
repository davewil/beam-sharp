%%% F45 — polymorphic function signatures (ticket 27 §(c), the instantiation
%%% algorithm of ticket 37, ENG-295).
%%%
%%% A variable declared after the function name — `T Pick<T>(T a, T b)` — is
%%% solved at every call from the arguments: least per occurrence, joined
%%% across occurrences, then the argument is contained as any argument is. The
%%% return type is the declared one with the solution substituted, and that is
%%% what every test here reads through the boundary: a caller declared to
%%% return the instantiated type compiles, and a caller declared narrower is
%%% refused with the corrected signature F25 already prints.
%%%
%%% Nothing inspects the checker's tables. The solve is observable only in what
%%% the call returns, so the tests are callers.

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

%% The errors a source provokes, empty when it checks clean: both outcomes
%% of `check_only/1` are read, so a clean source is an assertion and not a
%% badmatch.
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

%% `T Pick<T>(T, T)` beside a caller declared to return `Ret`.
pick_src(Ret) ->
    "module Pick\n"
    "public T Pick<T>(T a, T b)\n"
    "Pick(a, _) -> a\n"
    "public " ++ Ret ++ " Both(int n)\n"
    "Both(n) -> Pick(n, :a)\n".

%% 25d's `Prepend`, at two element types in one module.
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
%%% F45.1 — the ticket's program: one `Prepend`, two element types, and the
%%% instantiated return is what makes each caller's body check
%%% ---------------------------------------------------------------------------

%% Both callers compile against `Prepend`'s declared return with `T` and `E`
%% substituted — `list<int> | (:error, FetchError)` for `Ids`. Under the
%% maximal extent alone the return would be `list<term> | (:error, term)`,
%% which `Ids` may not return, so a green here is the solve and not the
%% containment.
one_prepend_serves_two_element_types_test() ->
    M = build_and_load(rows_src(), 'Rows'),
    ?assertEqual([1, 2], M:'Ids'([{1, placed}, {2, lost}])),
    ?assertEqual([placed, lost], M:'Names'([{1, placed}, {2, lost}])).

%% The corpus carries the same shape as `examples/Shop/Rows/Rows.bs`, where the
%% first element type is a record; `check-examples.sh` compiles it and this
%% runs it, so a corpus edit cannot silently drop the polymorphic call.
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
%%% F45.2 — a variable twice joins: `Pick<T>(T, T)` with an int and an atom
%%% returns `int | :a` (ticket 37 M5)
%%% ---------------------------------------------------------------------------

a_variable_twice_joins_test() ->
    M = build_and_load(pick_src("int | :a"), 'Pick'),
    ?assertEqual(3, M:'Both'(3)).

%% The control: declare the caller narrower than the join and the checker
%% refuses it, with the join in the corrected signature. So the previous test
%% is green because the return was instantiated, not because a bare `T`
%% resolved to something everything is contained in.
the_join_is_the_return_and_narrower_is_refused_test() ->
    Diags = errors(pick_src("int")),
    ?assert(lists:member(return_not_declared, tags(Diags))),
    Out = run_cli_src(pick_src("int")),
    bad_rc(Out),
    has(Out, "int | :a Both(int n)").

%% Two arguments of one type collapse rather than widen (M5's control).
the_join_collapses_when_the_arguments_agree_test() ->
    Src = "module Pick\n"
          "public T Pick<T>(T a, T b)\n"
          "Pick(a, _) -> a\n"
          "public int Same(int n)\n"
          "Same(n) -> Pick(n, n + 1)\n",
    ?assertEqual([], errors(Src)).

%%% ---------------------------------------------------------------------------
%%% F45.3 — least, per occurrence: `option<T> First<T>(option<T>)` handed
%%% exactly `:nothing` returns exactly `:nothing` (ticket 37 M2)
%%% ---------------------------------------------------------------------------

least_keeps_the_return_informative_test() ->
    Src = "module First\n"
          "public option<T> First<T>(option<T> o)\n"
          "First(o) -> o\n"
          "public :nothing Empty()\n"
          "Empty() -> First(:nothing)\n",
    ?assertEqual([], errors(Src)).

%% Under the greatest solution the return would be `term`, and `Empty` would
%% be refused. The control is the same call declared over `int`, which is
%% refused under either solution: it shows the previous test discriminates on
%% the return and not on the checker accepting every declaration.
least_control_a_wrong_declaration_is_still_refused_test() ->
    Src = "module First\n"
          "public option<T> First<T>(option<T> o)\n"
          "First(o) -> o\n"
          "public int Empty()\n"
          "Empty() -> First(:nothing)\n",
    ?assert(lists:member(return_not_declared, tags(errors(Src)))).

%%% ---------------------------------------------------------------------------
%%% F45.4 — containment fails exactly where an argument escapes the
%%% parameter's maximal extent (ticket 37 M4, H2)
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

%% A bare `T` has extent `term` and rejects nothing (ticket 37 M6) — recorded
%% by ENG-295 as a property of the shape, not a defect of the algorithm.
a_bare_variable_rejects_nothing_test() ->
    Src = "module Pick\n"
          "public T Pick<T>(T a, T b)\n"
          "Pick(a, _) -> a\n"
          "public term Any(list<int> xs, (int, atom) t)\n"
          "Any(xs, t) -> Pick(xs, t)\n",
    ?assertEqual([], errors(Src)).

%%% ---------------------------------------------------------------------------
%%% F45.5 — the signature is checked at its extent: exhaustiveness holds for
%%% every instantiation, and a body returning outside the declared shape is
%%% refused there, not at a caller
%%% ---------------------------------------------------------------------------

the_declaration_is_checked_for_every_instantiation_test() ->
    %% Cover the list half with the ordinary pair and leave the error tuple
    %% out: `result<list<T>, E>` is `list<T> | (:error, E)` whatever `T` is,
    %% so the residual is `(:error, E)` for every instantiation.
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
%%% F45.6 — a bare variable admits one clause: bind it (ticket 27 §2)
%%% ---------------------------------------------------------------------------

%% `Pick(1, _)` inspects a value whose type is `T`. Ticket 27 §2 refuses this
%% at the declaration: the signature `T Pick<T>(T, T)` promises a reviewer that
%% which argument comes back cannot depend on the type.
a_pattern_on_a_bare_variable_is_refused_test() ->
    Src = "module Pick\n"
          "public T Pick<T>(T a, T b)\n"
          "Pick(1, _) -> 1\n"
          "Pick(_, b) -> b\n",
    Diags = errors(Src),
    ?assertMatch([{error, _, 'Pick', {pattern_on_type_variable, 'T', 1}}], Diags).

%% Structure AROUND a variable matches freely: `[]` / `[h, ..t]` over
%% `list<T>` is the ordinary pair, exhaustive for every instantiation.
structure_around_a_variable_matches_freely_test() ->
    Src = "module Heads\n"
          "public option<T> First<T>(list<T> xs)\n"
          "First([])       -> :nothing\n"
          "First([h, ..]) -> h\n",
    ?assertEqual([], errors(Src)).

%%% ---------------------------------------------------------------------------
%%% F45.10 — every variable appears in a parameter, or the call could not
%%% recover it (ticket 28 §6)
%%% ---------------------------------------------------------------------------

a_variable_only_in_the_return_is_refused_test() ->
    Src = "module Empty\n"
          "public list<T> Empty<T>()\n"
          "Empty() -> []\n",
    ?assertMatch([{error, _, 'Empty', {unrecoverable_type_variable, 'T'}}],
                 errors(Src)).

%% The control is the same variable reached through a parameter's structure:
%% `list<T>` mentions `T`, so it is recoverable and the signature stands.
a_variable_under_a_constructor_is_recoverable_test() ->
    Src = "module Heads\n"
          "public list<T> Rest<T>(list<T> xs)\n"
          "Rest([])        -> []\n"
          "Rest([_, ..t]) -> t\n",
    ?assertEqual([], errors(Src)).

%%% ---------------------------------------------------------------------------
%%% F45.11 — a codegen obligation is not generated over a variable (ticket 27)
%%% ---------------------------------------------------------------------------

%% Before this refusal the checker accepted the call under the opaque binding
%% and the EMITTER crashed building the validator table — a compiler crash,
%% not a diagnostic. Now it is refused where the obligation is written.
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

%% The control: a GROUND obligation inside a polymorphic function is the
%% ordinary one, so the refusal is about the argument and not the function.
a_ground_obligation_inside_a_polymorphic_function_stands_test() ->
    Src = "module Obl\n"
          "public (T, result<int, ValidationError>) Both<T>(T x, term raw)\n"
          "Both(x, raw) -> (x, ValidateAs<int>(raw))\n",
    ?assertEqual([], errors(Src)).

%%% ---------------------------------------------------------------------------
%%% F45.7 — the API prints the signature as written, variables and all
%%% ---------------------------------------------------------------------------

%% `--api` prints resolved types (F17). A polymorphic signature has no ground
%% resolution to print — `term Pick(term, term)` would be a lie about what the
%% function promises — so it prints the declaration the caller instantiates.
api_prints_the_written_signature_test() ->
    {Root, Main} = in_dir([{"Pick.bs", pick_src("int | :a")}]),
    Out = run_cli("--src-root " ++ Root ++ " --api " ++ Main),
    ok_rc(Out),
    has(Out, "T Pick<T>(T, T)\n"),
    has(Out, ":a | int Both(int)\n").

%%% ---------------------------------------------------------------------------
%%% F45.8 — the solve crosses `using`: a dependent instantiates a producer's
%%% polymorphic export at its own type
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

%% Declared narrower than the instantiation, the dependent is refused where
%% a local caller would be — so the import table carried the template and
%% not a ground extent.
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
%%% F45.9 — the emitted spec is inert: variables erase to `any()` and the
%%% module loads (ticket 27 §6)
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
