%%% F12 — `public` / `private` at the signature (ticket 40 §3).
%%%
%%% WHY THESE ARE TESTS RATHER THAN EXAMPLES
%%% The features README draws the boundary: every file in `examples/` must
%%% compile, so a capability whose whole behaviour is a REJECTION cannot be
%%% demonstrated there. Four of this feature's five behaviours are refusals, and
%%% the fifth — that a private function leaves the export list — is invisible in
%%% a program's output and has to be read off the emitted beam.
%%%
%%% The corpus carries the positive half: `examples/Fib` has a private `Series/4`
%%% and `Reverse/2`, and `Shop.Collections.List` has a private `Length/2` beside
%%% a public `Length/1`.
-module(visibility_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, check_only/1, escript/0, run_cli/1,
                          fixture_root/0, place/3]).

-define(OUT, "/tmp/bsc_eunit").

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

%%% ---------------------------------------------------------------------------
%%% F12.3 — AN UNMARKED SIGNATURE IS PRIVATE (ticket 40 §3, amended 2026-08-17)
%%%
%%% §3 first took Elixir's `def`/`defp` — no unmarked case, absence an error —
%%% and reversed on the evidence its own original framing had gathered: C#, the
%%% BEAM and TypeScript all default CLOSED. There was a `missing_visibility`
%%% check and two tests here asserting it; both are gone, replaced by the
%%% positive claim, because a test for an error the language no longer raises is
%%% worse than no test at all.
%%% ---------------------------------------------------------------------------

unmarked_src() ->
    "module Unmarked\n"
    "public int Twice(int n)\n"
    "Twice(n) -> Helper(n) + Helper(n)\n"
    "int Helper(int n)\n"
    "Helper(n) -> n\n".

%% The default itself: no marker, no export.
an_unmarked_signature_is_not_exported_test() ->
    M = build_and_load(unmarked_src(), 'Unmarked'),
    Exports = [{F, A} || {F, A} <- M:module_info(exports), F =/= module_info],
    ?assertEqual([{'Twice', 1}], Exports).

%% ...and it compiles and runs, which is the half that would break if `none`
%% were sorted as public somewhere: the module would still work and would simply
%% export too much, which no test of a working program can see.
an_unmarked_signature_is_still_callable_in_its_module_test() ->
    ?assertMatch({ok, _, []}, check_only(unmarked_src())),
    M = build_and_load(unmarked_src(), 'Unmarked'),
    ?assertEqual(8, M:'Twice'(4)).

%% Writing `private` is legal and says what the absence already says. Kept so
%% the two spellings cannot drift apart unnoticed — the corpus uses the explicit
%% form throughout, and the language's default is the implicit one.
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

%% THE MOMENT THE DEFAULT BITES, and the reason the message is part of the
%% amendment rather than a follow-up. A module nobody has marked exports
%% nothing, and the old sentence was "which function? the module exports " with
%% an empty list after it.
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

%%% ---------------------------------------------------------------------------
%%% F12.1 / F12.2 / F12.8 — what `private` actually does
%%% ---------------------------------------------------------------------------

%% The whole mechanism, and it is the export list and nothing else.
a_private_function_is_not_exported_test() ->
    M = build_and_load(fib_src(), 'Vis'),
    Exports = [{F, A} || {F, A} <- M:module_info(exports), F =/= module_info],
    ?assertEqual([{'Fib', 1}], Exports).

%% ...and it is still THERE. A private function is compiled, specced, and named
%% by a crash; it is simply not offered to anyone. Asserting this separately is
%% the difference between "not exported" and "not emitted", and only one of them
%% is what ticket 40 §3 decided.
a_private_function_is_still_defined_test() ->
    M = build_and_load(fib_src(), 'Vis'),
    Defined = [{F, A} || {F, A} <- M:module_info(functions), F =/= module_info],
    ?assert(lists:member({'Series', 4}, Defined)),
    ?assert(lists:member({'Reverse', 2}, Defined)).

%% F12.8 — and the module still works, which is the point of having helpers.
a_private_function_is_callable_within_its_module_test() ->
    M = build_and_load(fib_src(), 'Vis'),
    ?assertEqual([0, 1, 1, 2, 3, 5, 8, 13, 21, 34], M:'Fib'(10)).

%% Ticket 40 §2 permits arity overloading and §3 marks each signature, so the
%% two meet here: visibility is per NAME AND ARITY. This is the shape
%% `Shop.Collections.List` carries in the corpus.
two_arities_of_one_name_may_differ_in_visibility_test() ->
    Src = "module Pair\n"
          "public int Length(list<int> xs)\n"
          "Length(xs) -> Length(xs, 0)\n"
          "private int Length(list<int> xs, int acc)\n"
          "Length([], acc)          -> acc\n"
          "Length([x, ..rest], acc) -> Length(rest, acc + 1)\n",
    M = build_and_load(Src, 'Pair'),
    Exports = [{F, A} || {F, A} <- M:module_info(exports), F =/= module_info],
    ?assertEqual([{'Length', 1}], Exports),
    ?assertEqual(3, M:'Length'([7, 8, 9])).

%%% ---------------------------------------------------------------------------
%%% F12.4 — a private callee is `private`, NEVER `unknown`
%%%
%%% This is the reason `exports_of/1` does not simply filter. Reported as
%%% `unknown_callee` the message would tell the author the function does not
%%% exist, when it plainly does and is one word away from being callable —
%%% sending them to fix the wrong thing. Ticket 40 §2 wrote a whole section
%%% about that shape; this is its third appearance.
%%%
%%% Both spellings, because they take different paths: a qualified call arrives
%%% already keyed `{q, M, N, A}`, and an unqualified one never resolves at all,
%%% since a private name cannot populate the import table.
%%% ---------------------------------------------------------------------------

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

%% The other half of the same table: a name that is genuinely absent must still
%% report as absent. Without this, the private path could swallow everything and
%% the suite would not notice.
a_call_to_a_name_that_does_not_exist_still_says_so_test() ->
    Out = two_modules("module B\n"
                      "using A\n"
                      "public int Go(int n)\n"
                      "Go(n) -> Missing(n, 3)\n"),
    said(Out, "which nothing declares"),
    silent(Out, "declares `private`").

%% And the public one is reachable, so the refusals above are about visibility
%% rather than about imports being broken.
a_public_function_is_reachable_across_modules_test() ->
    Out = two_modules("module B\n"
                      "using A\n"
                      "public int Go(int n)\n"
                      "Go(n) -> Twice(n)\n"),
    said(Out, "rc:0").

%%% ---------------------------------------------------------------------------
%%% F12.5 — a private callback, refused at the declaration
%%%
%%% Ticket 06 measured that `-behaviour` has NO runtime effect and only exports
%%% matter: `gen_server` builds `fun Mod:handle_call/3` off the module atom. So a
%%% private callback breaks the contract when the process STARTS, silently. That
%%% is why 40 §3 says the check ships with the keyword rather than after it.
%%% ---------------------------------------------------------------------------

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

%% The same module with the marker the other way round is fine — so the refusal
%% is about the marker and not about the module.
a_public_callback_is_accepted_test() ->
    ?assertMatch({ok, _, []}, check_only(callback_src("public"))).

%% CONTRACT-SCOPED, exactly as F10's table is. The same name and arity in a
%% module that declares NO behaviour is an ordinary private function, and stays
%% one. Without this the check would be a naming rule by another route, which is
%% the worry ticket 35 raised about the lowering table.
a_private_function_named_like_a_callback_is_fine_without_the_behaviour_test() ->
    Src = "module NoBeh\n"
          "public (:reply, int, int) Ask(int n)\n"
          "Ask(n) -> HandleCall(:get, :nobody, n)\n"
          "private (:reply, int, int) HandleCall(atom request, term from, int state)\n"
          "HandleCall(r, from, state) -> (:reply, state, state)\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

%%% ---------------------------------------------------------------------------
%%% F12.6 — naming a private function at the CLI
%%%
%%% Measured before it shipped: a private name is simply absent from
%%% `module_info(exports)`, so this used to fall through the file-name rule, take
%%% the module's public function, and try to read the FUNCTION NAME as an
%%% ARGUMENT — reporting an unreadable argument for something that was never an
%%% argument. Fifth instance of the shape that fails by going quiet.
%%% ---------------------------------------------------------------------------

naming_a_private_function_at_the_cli_says_it_is_private_test() ->
    case built() of
        false -> ok;
        true ->
            Root = fixture_root() ++ "/viscli",
            Main = place(Root, "Vis.bs", fib_src()),
            Out = run_cli("--src-root " ++ Root ++ " -o " ++ ?OUT ++ " " ++
                          filename:dirname(Main) ++ " Series 3"),
            said(Out, "Series is private in Vis"),
            %% Exit 2, not 1: the compiler succeeded and the INVOCATION is
            %% wrong, which is the class `ambiguous` and `bad_arity` are in.
            said(Out, "rc:2"),
            %% The sentence it used to print instead.
            silent(Out, "unreadable")
    end.

%%% ---------------------------------------------------------------------------

said(Out, What)   -> ?assertNotEqual(nomatch, string:find(Out, What)).
silent(Out, What) -> ?assertEqual(nomatch, string:find(Out, What)).

built() -> bs_test_support:built().
