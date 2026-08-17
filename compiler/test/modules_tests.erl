%%% F11 — the module system.
%%%
%%% Driven through the CLI rather than through `bs_check` directly, and that is
%%% not ceremony: this feature's whole subject is what happens ACROSS files, and
%%% a checker called with one parsed file cannot express the question. The unit
%%% under test is `bsc DIR/A.bs`, which is also what a person types.
%%%
%%% Every test gets its OWN directory. `bsc` now builds a module index by walking
%%% the source tree from the roots of the files it was given, so two tests
%%% sharing a directory would see each other's modules — and the failure would be
%%% order-dependent, which is the worst kind to debug.

-module(modules_tests).

-include_lib("eunit/include/eunit.hrl").

%%% ---------------------------------------------------------------------------
%%% Helpers
%%% ---------------------------------------------------------------------------

%% F15 — EACH MODULE NOW GETS ITS OWN DIRECTORY, under one shared root.
%%
%% This file's own header already had half the rule: every test gets its own
%% directory, because two tests sharing one would see each other's modules. F15
%% supplies the other half — within a test, every MODULE needs its own directory
%% too, since a directory is now a module and two `module` lines in one of them is
%% the thing `{module_disagreement, …}` refuses.
%%
%% `place/3` puts each source in the directory its own `module` line implies, so
%% `module Shop.List` lands at `<root>/Shop/List/List.bs`. That is what makes
%% `--src-root <root>` the right thing to pass: 41 §5's check then compares
%% `Shop.List` against `Shop/List` and they match.
%%
%% Files is [{"Name.bs", Source}]; the first is the one compiled.
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

list_mod() ->
    {"List.bs",
     "module Shop.List\n"
     "public int Sum(list<int> xs, int acc)\n"
     "Sum([], acc) -> acc\n"
     "Sum([x, ..rest], acc) -> Sum(rest, acc + x)\n"}.

%%% ---------------------------------------------------------------------------
%%% F11.1 / F11.2 — the dotted atom, and the tag it mints
%%% ---------------------------------------------------------------------------

%% Ticket 40 §1: the atom is the FULL dotted path, and this is forced rather than
%% chosen. If a nested module lowered to its leaf, `Shop.Orders.Order` and
%% `Billing.Invoices.Order` would both mint `'Orders.Order'` and two bounded
%% contexts would silently unify — the exact failure 26 §1's mint exists to
%% prevent, one level up and invisible.
%% Ticket 13's measured `erlc` module-atom/filename enforcement means the emitted
%% file is named by the atom, so `ls` showing `Shop.Orders.beam` IS the assertion
%% that the atom is `'Shop.Orders'` — and it is also 23 §10's requirement that the
%% listing be legible to a reader with nothing but `ls`.
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

%%% ---------------------------------------------------------------------------
%%% F11.4 / F11.6 / F11.7 — the three ways to reach another module
%%% ---------------------------------------------------------------------------

an_unqualified_call_reaches_an_imported_function_test() ->
    Out = run([{"R.bs",
                "module Shop.Reports\n"
                "using Shop.List\n"
                "public int Go(int n)\n"
                "Go(n) -> Sum([n, n], 0)\n"},
               list_mod()],
              "Go 4"),
    has(Out, "8").

a_fully_qualified_call_needs_no_unqualified_scope_test() ->
    Out = run([{"R.bs",
                "module Shop.Reports\n"
                "using Shop.List\n"
                "public int Go(int n)\n"
                "Go(n) -> Shop.List.Sum([n], 0)\n"},
               list_mod()],
              "Go 5"),
    has(Out, "5").

%% 41 §5: a path that is not itself a module but is a prefix of ones that are is
%% a NAMESPACE — erased entirely, no atom, nothing emitted.
a_namespace_import_short_qualifies_its_modules_test() ->
    Out = run([{"R.bs",
                "module Shop.Reports\n"
                "using Shop\n"
                "public int Go(int n)\n"
                "Go(n) -> List.Sum([n, n, n], 0)\n"},
               list_mod()],
              "Go 2"),
    has(Out, "6").

%%% ---------------------------------------------------------------------------
%%% F11.5 — a qualified call to something the module does not declare
%%% ---------------------------------------------------------------------------

a_qualified_call_to_an_undeclared_function_is_an_error_test() ->
    Out = compile_set([{"R.bs",
                        "module Shop.Reports\n"
                        "using Shop.List\n"
                        "public int Go(int n)\n"
                        "Go(n) -> Shop.List.Product([n], 0)\n"},
                       list_mod()]),
    bad_rc(Out),
    has(Out, "which nothing declares").

%% 41 §1 reason 3 met rather than decided: a file's `using` lines ARE its
%% dependency list, so a qualified call that skipped the list would make the
%% list wrong.
a_qualified_call_to_an_unimported_module_is_an_error_test() ->
    Out = compile_set([{"R.bs",
                        "module Shop.Reports\n"
                        "public int Go(int n)\n"
                        "Go(n) -> Shop.List.Sum([n], 0)\n"},
                       list_mod()]),
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

%%% ---------------------------------------------------------------------------
%%% F11.8 / F11.9 / F11.10 — the collision rules
%%% ---------------------------------------------------------------------------

%% 41 §2 requirement 1. NOT a silent winner: a quiet resolution is the failure
%% shape this project has been bitten by three times, and the candidates print
%% QUALIFIED so the message hands over the fix.
an_ambiguous_unqualified_call_is_an_error_naming_both_test() ->
    Out = compile_set([{"R.bs",
                        "module Shop.Reports\n"
                        "using Shop.List\n"
                        "using Shop.Other\n"
                        "public int Go(int n)\n"
                        "Go(n) -> Sum([n], 0)\n"},
                       list_mod(),
                       {"Other.bs",
                        "module Shop.Other\n"
                        "public int Sum(list<int> xs, int acc)\n"
                        "Sum(xs, acc) -> acc\n"}]),
    bad_rc(Out),
    has(Out, "is ambiguous"),
    has(Out, "Shop.List.Sum"),
    has(Out, "Shop.Other.Sum").

%% 41 §2 requirement 2, and the ticket is careful this is NOT the analogy 40 §2
%% refused: there each overload has a defined meaning, here the unqualified name
%% has none at all.
an_import_shadowing_a_local_is_an_error_test() ->
    Out = compile_set([{"R.bs",
                        "module Shop.Reports\n"
                        "using Shop.List\n"
                        "public int Sum(list<int> xs, int acc)\n"
                        "Sum(xs, acc) -> acc\n"
                        "public int Go(int n)\n"
                        "Go(n) -> Sum([n], 0)\n"},
                       list_mod()]),
    bad_rc(Out),
    has(Out, "which this module also declares").

%% 41 §2 requirement 3: resolution is by name AND arity, since 40 §2 permits
%% overloading. `Sum/2` imported beside a local `Sum/1` is not a conflict.
an_import_differing_only_in_arity_is_not_a_conflict_test() ->
    Out = run([{"R.bs",
                "module Shop.Reports\n"
                "using Shop.List\n"
                "public int Sum(list<int> xs)\n"
                "Sum(xs) -> Sum(xs, 0)\n"
                "public int Go(int n)\n"
                "Go(n) -> Sum([n, n])\n"},
               list_mod()],
              "Go 6"),
    has(Out, "12").

%%% ---------------------------------------------------------------------------
%%% F11.11 / F11.12 — one name, one arity
%%% ---------------------------------------------------------------------------

%% Ticket 40 §2's owed check. Before it, the checker MERGED the two into one
%% four-clause function and reported the later clauses as unreachable — a remark
%% about the code where the truth was a duplicate declaration — and the program
%% was then stopped by `erlc` against `Silent.abstr:0`: no line, no `.bs`
%% filename, a message about a file the author never wrote.
two_signatures_of_the_same_arity_are_an_error_test() ->
    Out = compile_set([{"A.bs",
                        "module Dup\n"
                        "public int Combine(int n, int m)\n"
                        "Combine(n, m) -> n + m\n"
                        "public int Combine(int n, int m)\n"
                        "Combine(n, m) -> n * m\n"}]),
    bad_rc(Out),
    has(Out, "declared more than once"),
    %% The point of the check is the DIAGNOSIS, not the outcome: the old
    %% behaviour also stopped the program.
    ?assertEqual(nomatch, string:find(Out, "unreachable")).

%% The other half of 40 §2, and the half that is a permission rather than a
%% refusal: nothing on the BEAM breaks under overloading, and `examples/fib.bs`
%% writing `Fib`/`Series`/`Reverse` was idiom rather than constraint.
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

%% Keying callees by name and arity made this a real fork. Reporting `F/2` as
%% simply unknown when `F/1` exists throws away the fact that the author plainly
%% meant the `F` sitting right there.
%% One other arity keeps the old, friendlier sentence. Losing this to a bare
%% `unknown_callee` would have been a real regression: the author plainly meant
%% the `F` sitting right there.
calling_the_wrong_arity_still_says_so_test() ->
    Out = compile_set([{"A.bs",
                        "module Ar\n"
                        "public int F(int a)\n"
                        "F(a) -> a\n"
                        "public int G(int a)\n"
                        "G(a) -> F(a, a)\n"}]),
    bad_rc(Out),
    has(Out, "with 2 arguments, and it takes 1").

%% Several, and the sentence has to change: under overloading there is no single
%% "it takes N", so the message names every arity that IS declared and says why
%% the missing one would be a new function.
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

%% The name really is unknown — no arity of it exists — so neither of the two
%% above applies and the original message is the right one.
calling_a_name_that_does_not_exist_is_still_unknown_test() ->
    Out = compile_set([{"A.bs",
                        "module Ar\n"
                        "public int G(int a)\n"
                        "G(a) -> Nope(a)\n"}]),
    bad_rc(Out),
    has(Out, "which nothing declares").

%%% ---------------------------------------------------------------------------
%%% F11.14 — the cycle rule
%%% ---------------------------------------------------------------------------

%% 41 leaves the cycle rule to "the implementing feature" and names F6's
%% cyclic-ALIAS guard as the precedent: refuse by name rather than expand. That
%% guard shipped after a HANG, which no green suite could see.
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

%%% ---------------------------------------------------------------------------
%%% The dependency graph is the compiler's
%%% ---------------------------------------------------------------------------

%% 41 §3: a build tool names the source root and the file set, never the order.
%% Only the DEPENDENT is passed here; the dependency is found and compiled first.
a_dependency_not_named_on_the_command_line_is_found_and_built_test() ->
    {Root, Main} = in_dir([{"R.bs",
                            "module Shop.Reports\n"
                            "using Shop.List\n"
                            "public int Go(int n)\n"
                            "Go(n) -> Sum([n], 0)\n"},
                           list_mod()]),
    Out = bs_test_support:run_cli("--src-root " ++ Root ++ " -o " ++ Root ++
                                      "/out " ++ Main),
    ok_rc(Out),
    ?assert(filelib:is_regular(Root ++ "/out/Shop.List.beam")),
    ?assert(filelib:is_regular(Root ++ "/out/Shop.Reports.beam")).
