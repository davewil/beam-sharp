%%% F12 — signatures control function visibility.
%%% Scenarios: compiler/features/F12-public-and-private.md
-module(visibility_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, check_only/1, escript/0, run_cli/1,
                          fixture_root/0, place/3]).

-define(OUT, bs_test_support:run_root()).

fib_src() ->
    "module Vis\n"
    "public list<int> Fib(int n)\n"
    "Fib(n) when n <= 0 -> []\n"
    "Fib(n) when n > 0  -> Series(n, 0, 1, [])\n"
    "private list<int> Series(int n, int a, int b, list<int> acc)\n"
    "Series(n, a, b, acc) when n <= 0 -> Reverse(acc, [])\n"
    "Series(n, a, b, acc) when n > 0  -> Series(n - 1, b, a + b, [a, ..acc])\n"
    "private list<int> Reverse(list<int> xs, list<int> acc)\n"
    "Reverse([], acc)          -> acc\n"
    "Reverse([x, ..rest], acc) -> Reverse(rest, [x, ..acc])\n".

%%% F12.3 — an unmarked signature is private.

unmarked_src() ->
    "module Unmarked\n"
    "public int Twice(int n)\n"
    "Twice(n) -> Helper(n) + Helper(n)\n"
    "int Helper(int n)\n"
    "Helper(n) -> n\n".

an_unmarked_signature_is_not_exported_test() ->
    M = build_and_load(unmarked_src(), 'Unmarked'),
    Exports = authors_exports(M),
    ?assertEqual([{'Twice', 1}], Exports).

an_unmarked_signature_is_still_callable_in_its_module_test() ->
    ?assertMatch({ok, _, []}, check_only(unmarked_src())),
    M = build_and_load(unmarked_src(), 'Unmarked'),
    ?assertEqual(8, M:'Twice'(4)).

an_explicit_private_and_an_unmarked_signature_agree_test() ->
    Explicit = "module Same\n"
               "public int Twice(int n)\n"
               "Twice(n) -> Helper(n) + Helper(n)\n"
               "private int Helper(int n)\n"
               "Helper(n) -> n\n",
    M1 = build_and_load(unmarked_src(), 'Unmarked'),
    M2 = build_and_load(Explicit, 'Same'),
    Ex = fun(M) -> [F || {F, _} <- M:module_info(exports), F =/= module_info] end,
    ?assertEqual(Ex(M1), Ex(M2)).

a_module_that_exports_nothing_says_so_test() ->
    case built() of
        false -> ok;
        true ->
            Root = fixture_root() ++ "/visnone",
            Main = place(Root, "Silent.bs",
                         "module Silent\n"
                         "int Go(int n)\n"
                         "Go(n) -> n + 1\n"),
            Out = run_cli("--src-root " ++ Root ++ " -o " ++ ?OUT ++ " " ++
                          filename:dirname(Main) ++ " 5"),
            said(Out, "this module exports nothing"),
            said(Out, "Mark the one you want to run"),
            silent(Out, "the module exports \n"),
            said(Out, "rc:2")
    end.

%%% F12.1 / F12.2 / F12.8 — private helpers run without being exported.

a_private_function_is_not_exported_test() ->
    M = build_and_load(fib_src(), 'Vis'),
    Exports = authors_exports(M),
    ?assertEqual([{'Fib', 1}], Exports).

%% Absence from exports must not mean absence from the emitted module.
a_private_function_is_still_defined_test() ->
    M = build_and_load(fib_src(), 'Vis'),
    Defined = [{F, A} || {F, A} <- M:module_info(functions), F =/= module_info],
    ?assert(lists:member({'Series', 4}, Defined)),
    ?assert(lists:member({'Reverse', 2}, Defined)).

%% F12.8 — private functions remain callable within their module.
a_private_function_is_callable_within_its_module_test() ->
    M = build_and_load(fib_src(), 'Vis'),
    ?assertEqual([0, 1, 1, 2, 3, 5, 8, 13, 21, 34], M:'Fib'(10)).

two_arities_of_one_name_may_differ_in_visibility_test() ->
    Src = "module Pair\n"
          "public int Length(list<int> xs)\n"
          "Length(xs) -> Length(xs, 0)\n"
          "private int Length(list<int> xs, int acc)\n"
          "Length([], acc)          -> acc\n"
          "Length([x, ..rest], acc) -> Length(rest, acc + 1)\n",
    M = build_and_load(Src, 'Pair'),
    Exports = authors_exports(M),
    ?assertEqual([{'Length', 1}], Exports),
    ?assertEqual(3, M:'Length'([7, 8, 9])).

%%% F12.4 — calls distinguish private functions from unknown names.
%%% Qualified calls resolve directly; imports exclude private names.

provider() ->
    {"A.bs",
     "module A\n"
     "public int Twice(int n)\n"
     "Twice(n) -> Helper(n, 2)\n"
     "private int Helper(int n, int k)\n"
     "Helper(n, k) -> n * k\n"}.

two_modules(Consumer) ->
    Root = fixture_root() ++ "/vis" ++ integer_to_list(erlang:unique_integer([positive])),
    {"A.bs", ASrc} = provider(),
    _ = place(Root, "A.bs", ASrc),
    Main = place(Root, "B.bs", Consumer),
    run_cli("--src-root " ++ Root ++ " -o " ++ ?OUT ++ " " ++ filename:dirname(Main)).

an_unqualified_call_to_a_private_function_says_private_test() ->
    Out = two_modules("module B\n"
                      "using A\n"
                      "public int Go(int n)\n"
                      "Go(n) -> Helper(n, 3)\n"),
    said(Out, "which A declares `private`"),
    silent(Out, "which nothing declares"),
    said(Out, "rc:1").

a_qualified_call_to_a_private_function_says_private_test() ->
    Out = two_modules("module B\n"
                      "using A\n"
                      "public int Go(int n)\n"
                      "Go(n) -> A.Helper(n, 3)\n"),
    said(Out, "which A declares `private`"),
    silent(Out, "which nothing declares"),
    said(Out, "rc:1").

%% Missing names must not be classified as private.
a_call_to_a_name_that_does_not_exist_still_says_so_test() ->
    Out = two_modules("module B\n"
                      "using A\n"
                      "public int Go(int n)\n"
                      "Go(n) -> Missing(n, 3)\n"),
    said(Out, "which nothing declares"),
    silent(Out, "declares `private`").

%% This control distinguishes visibility refusal from a broken import.
a_public_function_is_reachable_across_modules_test() ->
    Out = two_modules("module B\n"
                      "using A\n"
                      "public int Go(int n)\n"
                      "Go(n) -> Twice(n)\n"),
    said(Out, "rc:0").

%%% F12.5 — a private callback is refused at its declaration.
%%% gen_server calls exports, regardless of behaviour attributes.

callback_src(Vis) ->
    "module Cb\n"
    "behaviour GenServer\n"
    "public (:ok, int) Init(int seed)\n"
    "Init(seed) -> (:ok, seed)\n"
    ++ Vis ++ " (:reply, int, int) HandleCall(atom request, term from, int state)\n"
    "HandleCall(r, from, state) -> (:reply, state, state)\n"
    "public (:noreply, int) HandleCast(atom msg, int state)\n"
    "HandleCast(m, state) -> (:noreply, state)\n".

a_private_callback_is_an_error_test() ->
    ?assertError({private_callback, 'HandleCall', 3, handle_call, _},
                 check_only(callback_src("private"))).

%% Changing only visibility isolates the callback refusal.
a_public_callback_is_accepted_test() ->
    ?assertMatch({ok, _, []}, check_only(callback_src("public"))).

%% Callback restrictions require a declared behaviour, not just a matching name.
a_private_function_named_like_a_callback_is_fine_without_the_behaviour_test() ->
    Src = "module NoBeh\n"
          "public (:reply, int, int) Ask(int n)\n"
          "Ask(n) -> HandleCall(:get, :nobody, n)\n"
          "private (:reply, int, int) HandleCall(atom request, term from, int state)\n"
          "HandleCall(r, from, state) -> (:reply, state, state)\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

%%% F12.6 — the CLI identifies a named private function.

naming_a_private_function_at_the_cli_says_it_is_private_test() ->
    case built() of
        false -> ok;
        true ->
            Root = fixture_root() ++ "/viscli",
            Main = place(Root, "Vis.bs", fib_src()),
            Out = run_cli("--src-root " ++ Root ++ " -o " ++ ?OUT ++ " " ++
                          filename:dirname(Main) ++ " Series 3"),
            said(Out, "Series is private in Vis"),
            %% Compilation succeeds; exit 2 identifies an invocation error.
            said(Out, "rc:2"),
            %% The function name must not be interpreted as an argument.
            silent(Out, "unreadable")
    end.

said(Out, What)   -> ?assertNotEqual(nomatch, string:find(Out, What)).
silent(Out, What) -> ?assertEqual(nomatch, string:find(Out, What)).

built() -> bs_test_support:built().

%% Use the runner's export filter to exclude VM and compiler helper functions.
authors_exports(M) -> bs_run:authors_exports(M).
