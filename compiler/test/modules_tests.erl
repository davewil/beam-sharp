%%% Scenarios: compiler/features/F11-module-system.md
%%% Scenarios: compiler/features/F15-module-is-a-directory.md
%%% F11 — the module system resolves calls across files.
%%% The CLI exercises discovery across files, beyond a single-file checker.
%%% Each test needs its own root: discovery scans neighbouring modules.

-module(modules_tests).

-include_lib("eunit/include/eunit.hrl").

%%% Helpers

%% F15 — each module occupies its own directory beneath the source root.
%% `place/3` matches directories to module names; the first file is compiled.
in_dir(Files) ->
    Root = bs_test_support:fixture_root(),
    Paths = [bs_test_support:place(Root, N, S) || {N, S} <- Files],
    {Root, hd(Paths)}.

compile_set(Files) ->
    {Root, Main} = in_dir(Files),
    bs_test_support:run_cli("--src-root " ++ Root ++ " -o " ++ Root ++ "/out " ++ Main).

run(Files, Call) ->
    {Root, Main} = in_dir(Files),
    bs_test_support:run_cli("--src-root " ++ Root ++ " " ++ Main ++ " " ++ Call).

ok_rc(Out)  -> ?assert(string:find(Out, "rc:0") =/= nomatch).
bad_rc(Out) -> ?assert(string:find(Out, "rc:1") =/= nomatch).
has(Out, S) -> ?assert(string:find(Out, S) =/= nomatch).

%% Strip the CLI status line: searching for "0" also matches `rc:0`.
value(Out) -> string:trim(hd(string:split(Out, "\n"))).

ints_mod() ->
    {"Ints.bs",
     "module Shop.Ints\n"
     "public int Sum(list<int> xs, int acc)\n"
     "Sum([], acc) -> acc\n"
     "Sum([x, ..rest], acc) -> Sum(rest, acc + x)\n"}.

%% `Solo` has no parent namespace to import instead of its bare names.
solo_mod() ->
    {"Solo.bs",
     "module Solo\n"
     "public int Sum(list<int> xs, int acc)\n"
     "Sum([], acc) -> acc\n"
     "Sum([x, ..rest], acc) -> Sum(rest, acc + x)\n"}.

%%% F11.1–F11.2 — dotted names qualify module atoms and record tags.

%% erlc requires the beam filename to match the module atom.
a_dotted_module_emits_a_dotted_atom_test() ->
    {Root, Main} = in_dir([{"A.bs", "module Shop.Orders\npublic int One()\nOne() -> 1\n"}]),
    Out = bs_test_support:run_cli("--src-root " ++ Root ++ " -o " ++ Root ++
                                      "/out " ++ Main),
    ok_rc(Out),
    ?assert(filelib:is_regular(Root ++ "/out/Shop.Orders.beam")).

a_record_in_a_dotted_module_mints_the_qualified_tag_test() ->
    Src = "module Shop.Orders\n"
          "record Order { Id: int }\n"
          "public Order Make()\n"
          "Make() -> Order { Id = 7 }\n",
    Mod = bs_test_support:build_and_load(Src, 'Shop.Orders'),
    ?assertMatch(#{'Kind' := 'Shop.Orders.Order', 'Id' := 7}, Mod:'Make'()).

%%% F11.4, F11.6, F11.7 — imports resolve bare and qualified calls.

an_unqualified_call_reaches_an_imported_function_test() ->
    Out = run([{"R.bs",
                "module Shop.Reports\n"
                "using Shop.Ints\n"
                "public int Go(int n)\n"
                "Go(n) -> Sum([n, n], 0)\n"},
               ints_mod()],
              "Go 4"),
    has(Out, "8").

a_fully_qualified_call_needs_no_unqualified_scope_test() ->
    Out = run([{"R.bs",
                "module Shop.Reports\n"
                "using Shop.Ints\n"
                "public int Go(int n)\n"
                "Go(n) -> Shop.Ints.Sum([n], 0)\n"},
               ints_mod()],
              "Go 5"),
    has(Out, "5").

a_namespace_import_short_qualifies_its_modules_test() ->
    Out = run([{"R.bs",
                "module Shop.Reports\n"
                "using Shop\n"
                "public int Go(int n)\n"
                "Go(n) -> Ints.Sum([n, n, n], 0)\n"},
               ints_mod()],
              "Go 2"),
    has(Out, "6").

%%% F11.5 — qualified calls reject undeclared functions.

a_qualified_call_to_an_undeclared_function_is_an_error_test() ->
    Out = compile_set([{"R.bs",
                        "module Shop.Reports\n"
                        "using Shop.Ints\n"
                        "public int Go(int n)\n"
                        "Go(n) -> Shop.Ints.Product([n], 0)\n"},
                       ints_mod()]),
    bad_rc(Out),
    has(Out, "which nothing declares").

a_qualified_call_to_an_unimported_module_is_an_error_test() ->
    Out = compile_set([{"R.bs",
                        "module Shop.Reports\n"
                        "public int Go(int n)\n"
                        "Go(n) -> Shop.Ints.Sum([n], 0)\n"},
                       ints_mod()]),
    bad_rc(Out),
    has(Out, "never imported").

using_something_that_is_neither_module_nor_namespace_is_an_error_test() ->
    Out = compile_set([{"R.bs",
                        "module Shop.Reports\n"
                        "using Nowhere.At.All\n"
                        "public int Go(int n)\n"
                        "Go(n) -> n\n"}]),
    bad_rc(Out),
    has(Out, "names no module and no namespace").

%%% F11.8–F11.10 — calls resolve by scope, name and arity.

an_ambiguous_unqualified_call_is_an_error_naming_both_test() ->
    Out = compile_set([{"R.bs",
                        "module Shop.Reports\n"
                        "using Shop.Ints\n"
                        "using Shop.Other\n"
                        "public int Go(int n)\n"
                        "Go(n) -> Sum([n], 0)\n"},
                       ints_mod(),
                       {"Other.bs",
                        "module Shop.Other\n"
                        "public int Sum(list<int> xs, int acc)\n"
                        "Sum(xs, acc) -> acc\n"}]),
    bad_rc(Out),
    has(Out, "is ambiguous"),
    has(Out, "Shop.Ints.Sum"),
    has(Out, "Shop.Other.Sum").

%% Exact output distinguishes the local result from the import and `rc:0`.
an_import_may_shadow_a_local_and_the_local_wins_test() ->
    Out = run([{"R.bs",
                "module Shop.Reports\n"
                "using Shop.Ints\n"
                "public int Sum(list<int> xs, int acc)\n"
                "Sum(xs, acc) -> acc\n"
                "public int Go(int n)\n"
                "Go(n) -> Sum([n], 0)\n"},
               ints_mod()],
              "Go 3"),
    ok_rc(Out),
    ?assertEqual("0", value(Out)).

%% The qualified call returns 3 and the local call 0; two imported calls give 6.
a_top_level_module_shadowing_a_local_is_still_reachable_test() ->
    Out = run([{"R.bs",
                "module Shop.Reports\n"
                "using Solo\n"
                "public int Sum(list<int> xs, int acc)\n"
                "Sum(xs, acc) -> acc\n"
                "public int Go(int n)\n"
                "Go(n) -> Solo.Sum([n], 0) + Sum([n], 0)\n"},
               solo_mod()],
              "Go 3"),
    ok_rc(Out),
    ?assertEqual("3", value(Out)).

an_import_differing_only_in_arity_is_not_a_conflict_test() ->
    Out = run([{"R.bs",
                "module Shop.Reports\n"
                "using Shop.Ints\n"
                "public int Sum(list<int> xs)\n"
                "Sum(xs) -> Sum(xs, 0)\n"
                "public int Go(int n)\n"
                "Go(n) -> Sum([n, n])\n"},
               ints_mod()],
              "Go 6"),
    has(Out, "12").

%%% F11.11–F11.12 — each name and arity pair has one signature.

two_signatures_of_the_same_arity_are_an_error_test() ->
    Out = compile_set([{"A.bs",
                        "module Dup\n"
                        "public int Combine(int n, int m)\n"
                        "Combine(n, m) -> n + m\n"
                        "public int Combine(int n, int m)\n"
                        "Combine(n, m) -> n * m\n"}]),
    bad_rc(Out),
    has(Out, "declared more than once"),
    %% Duplicate signatures must not be diagnosed as unreachable clauses.
    ?assertEqual(nomatch, string:find(Out, "unreachable")).

two_arities_of_one_name_are_accepted_test() ->
    Out = run([{"A.bs",
                "module Over\n"
                "public int Fib(int n, int a, int b)\n"
                "Fib(n, a, b) when n <= 0 -> a\n"
                "Fib(n, a, b) when n > 0  -> Fib(n - 1, b, a + b)\n"
                "public int Fib(int n)\n"
                "Fib(n) -> Fib(n, 0, 1)\n"}],
              "Fib 10"),
    has(Out, "55").

calling_the_wrong_arity_still_says_so_test() ->
    Out = compile_set([{"A.bs",
                        "module Ar\n"
                        "public int F(int a)\n"
                        "F(a) -> a\n"
                        "public int G(int a)\n"
                        "G(a) -> F(a, a)\n"}]),
    bad_rc(Out),
    has(Out, "with 2 arguments, and it takes 1").

calling_an_arity_that_is_not_declared_names_the_ones_that_are_test() ->
    Out = compile_set([{"A.bs",
                        "module Ar\n"
                        "public int F(int a)\n"
                        "F(a) -> a\n"
                        "public int F(int a, int b)\n"
                        "F(a, b) -> a + b\n"
                        "public int G(int a)\n"
                        "G(a) -> F(a, a, a)\n"}]),
    bad_rc(Out),
    has(Out, "F/3"),
    has(Out, "/1, /2"),
    has(Out, "Arity overloading is permitted").

calling_a_name_that_does_not_exist_is_still_unknown_test() ->
    Out = compile_set([{"A.bs",
                        "module Ar\n"
                        "public int G(int a)\n"
                        "G(a) -> Nope(a)\n"}]),
    bad_rc(Out),
    has(Out, "which nothing declares").

%%% F11.14 — cyclic imports are refused.

two_modules_importing_each_other_are_refused_test() ->
    Out = compile_set([{"A.bs",
                        "module Cyc.A\n"
                        "using Cyc.B\n"
                        "public int Ping(int n)\n"
                        "Ping(n) -> n\n"},
                       {"B.bs",
                        "module Cyc.B\n"
                        "using Cyc.A\n"
                        "public int Pong(int n)\n"
                        "Pong(n) -> n\n"}]),
    bad_rc(Out),
    has(Out, "cycle").

%%% The dependency graph is the compiler's

%% Only the dependent file is passed; discovery must find its dependency.
a_dependency_not_named_on_the_command_line_is_found_and_built_test() ->
    {Root, Main} = in_dir([{"R.bs",
                            "module Shop.Reports\n"
                            "using Shop.Ints\n"
                            "public int Go(int n)\n"
                            "Go(n) -> Sum([n], 0)\n"},
                           ints_mod()]),
    Out = bs_test_support:run_cli("--src-root " ++ Root ++ " -o " ++ Root ++
                                      "/out " ++ Main),
    ok_rc(Out),
    ?assert(filelib:is_regular(Root ++ "/out/Shop.Ints.beam")),
    ?assert(filelib:is_regular(Root ++ "/out/Shop.Reports.beam")).
