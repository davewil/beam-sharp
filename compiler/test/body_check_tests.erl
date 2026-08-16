-module(body_check_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, check_only/1, errors/1,
                          project_root/0, escript/0, run_cli/1, with_src/3]).

-define(OUT, "/tmp/bsc_eunit").

%%% ---------------------------------------------------------------------------
%%% F5 — the body check site. Ticket 33.
%%%
%%% Five obligation sites, every one of them a place a type was already
%%% declared. Three of the tests below assert scenarios F3 wrote down with their
%%% ids RESERVED and could not run, because F3 had no body check to raise them
%%% from: F3.3's call-site enforcement, F3.8's projection error, and F3.10.
%%% ---------------------------------------------------------------------------


docs_src() ->
    "module Shop\n"
    "record Order   { Id: int, Total: int }\n"
    "record Invoice { Id: int, Total: int }\n"
    "Order Update(Order o)\n"
    "Update(o) -> o with { Total = 0 }\n".

%% F5.1 — site 4. Without it beam-sharp emits a `-spec` claiming what its own
%% body does not deliver, which is the defect ticket 18 measured in Gleam.
a_body_must_produce_the_declared_return_type_test() ->
    Src = "module M\nint Answer(int n)\nAnswer(n) -> :oops\n",
    ?assertMatch([{error, _, 'Answer', {return_not_declared, _}}], errors(Src)).

a_body_producing_the_declared_type_compiles_test() ->
    Src = "module M\natom Answer(int n)\nAnswer(n) -> :ok\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F5.2 — site 1, and F3.3's deferred half: ticket 26 §1's requirement as David
%% phrased it. F3 established aggregate identity in the algebra and had nowhere
%% to enforce it.
a_call_rejects_the_wrong_record_test() ->
    Src = docs_src() ++
          "Order Wrong(Invoice i)\n"
          "Wrong(i) -> Update(i)\n",
    ?assertMatch([{error, _, 'Wrong', {arg_not_accepted, 'Update', 1, _, _}}],
                 errors(Src)).

a_call_with_the_right_record_compiles_test() ->
    Src = docs_src() ++
          "Order Right(Order o)\n"
          "Right(o) -> Update(o)\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F5.3 — the residual IS the clause the caller must write, and it proposes an
%% edit to the function being checked rather than to the callee: ticket 18 §4's
%% function-local rule showing up in a diagnostic.
the_call_site_residual_is_the_callers_clause_head_test() ->
    case filelib:is_regular(escript()) of
        false -> ok;
        true ->
            Src = docs_src() ++
                  "Order Wrong(Invoice i)\n"
                  "Wrong(i) -> Update(i)\n",
            with_src("callsite.bs", Src, fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path),
                ?assert(string:find(R, "Wrong({ Kind: :'Shop.Invoice' }) -> ...")
                        =/= nomatch),
                %% Never a suggestion to widen the callee.
                ?assertEqual(nomatch, string:find(R, "Update({"))
            end)
    end.

%% F5.4 — site 2, and F3.10: the single largest hole F3 shipped with. A body
%% could build a map wearing an `Order` tag without `Order`'s fields.
construction_must_supply_every_declared_field_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "Order Make(int n)\n"
          "Make(n) -> Order{ Id = n }\n",
    ?assertMatch([{error, _, 'Make', {field_set_mismatch, 'Order', ['Total'], []}}],
                 errors(Src)).

construction_may_not_supply_an_undeclared_field_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "Order Make(int n)\n"
          "Make(n) -> Order{ Id = n, Total = n, Extra = n }\n",
    ?assertMatch([{error, _, 'Make', {field_set_mismatch, 'Order', [], ['Extra']}}],
                 errors(Src)).

construction_with_the_exact_field_set_compiles_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "Order Make(int n)\n"
          "Make(n) -> Order{ Id = n, Total = n }\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F5.5 — site 3, and F3.8's deferred sentence. The residual IS the member that
%% lacks the field, so the fix — discriminate on the tag first — is handed back
%% rather than described.
projecting_a_field_one_member_lacks_names_that_member_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "record Note  { Id: int }\n"
          "type Doc = Order | Note\n"
          "int Amount(Doc d)\n"
          "Amount(d) -> d.Total\n",
    [{error, _, 'Amount', {field_absent, 'Total', Residual}}] = errors(Src),
    ?assertEqual("{ Kind: :'Shop.Note' }",
                 lists:flatten(bs_types:to_pattern(Residual))).

%% F3.8's live half, unchanged: legal where every member carries the field.
projecting_a_field_every_member_carries_compiles_test() ->
    Src = "module Shop\n"
          "record Order   { Id: int, Total: int }\n"
          "record Invoice { Id: int, Total: int }\n"
          "type Doc = Order | Invoice\n"
          "int Amount(Doc d)\n"
          "Amount(d) -> d.Total\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F5.6 — a body variable's type comes from the clause's REFINED DOMAIN, so an
%% earlier clause narrows a later body with nothing written. Ticket 08's
%% "narrowing is always written" falling out: the earlier clause head IS the
%% narrowing.
narrow_src(Clauses) ->
    "module Narrow\n"
    "type Flag = :on | :off\n"
    "atom Only(:on f)\n"
    "Only(f) -> :ok\n"
    "atom Run(Flag f)\n" ++ Clauses.

an_earlier_clause_narrows_a_later_body_test() ->
    ?assertMatch({ok, _, _},
                 check_only(narrow_src("Run(:off) -> :no\nRun(f) -> Only(f)\n"))).

%% The control, and it is the load-bearing half: without the earlier clause the
%% same body is an error, so the narrowing is the residual's contribution and
%% not the pattern's.
without_the_earlier_clause_the_same_body_is_an_error_test() ->
    ?assertMatch([{error, _, 'Run', {arg_not_accepted, 'Only', 1, _, _}} | _],
                 errors(narrow_src("Run(f) -> Only(f)\n"))).

%% F5.7 — the domain is `Possible`, never `Certain`. An untranslatable guard
%% makes `Certain` none, and a body typed against none does not fail loudly: it
%% silently stops checking, because every containment over none passes. So this
%% asserts an error that the WRONG build omits.
an_untranslatable_guard_leaves_the_body_typed_test() ->
    Src = "module Guarded\n"
          "atom Weird(int n)\n"
          "Weird(n) -> :yes\n"
          "atom Classify(int n)\n"
          "Classify(n) when Weird(n) -> n.Total\n"
          "Classify(n)               -> :other\n",
    ?assertMatch([{error, _, 'Classify', {field_absent, 'Total', _}}], errors(Src)).

%% F5.8 — ticket 32 dissolved the foreign case. `collect/1` excludes foreign
%% declarations by design, which is right for clause checking and wrong for a
%% callee environment, so this fails if the env is built from signatures alone.
a_foreign_callee_is_checked_like_any_other_test() ->
    Src = "module Interop\n"
          "using :lists { int sum(list<int> xs) }\n"
          "int Bad(atom a)\n"
          "Bad(a) -> :lists.sum(a)\n",
    ?assertMatch([{error, _, 'Bad', {arg_not_accepted, _, 1, _, _}}], errors(Src)).

a_foreign_call_with_the_declared_type_compiles_test() ->
    Src = "module Interop\n"
          "using :lists { int sum(list<int> xs) }\n"
          "int Good(list<int> xs)\n"
          "Good(xs) -> :lists.sum(xs)\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F5.9 — a binding declares no type, so it is synthesis only. `t : int` has to
%% come from somewhere it did not before.
a_binding_carries_its_type_into_the_rest_of_the_body_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "atom Wrong(Order o)\n"
          "Wrong(o) ->\n"
          "    var t = o.Total\n"
          "    t\n",
    ?assertMatch([{error, _, 'Wrong', {return_not_declared, _}}], errors(Src)).

%% F5.10 — site 5, the destructuring bind ticket 34 deferred here rather than
%% refusing. Provably irrefutable IFF the residual is empty.
a_destructuring_bind_that_cannot_fail_runs_test() ->
    Src = "module Pairs\n"
          "int Sum((int, int) pair)\n"
          "Sum(pair) ->\n"
          "    var (a, b) = pair\n"
          "    a + b\n",
    M = build_and_load(Src, 'Pairs'),
    ?assertEqual(7, M:'Sum'({3, 4})).

a_destructuring_bind_that_can_fail_is_an_error_test() ->
    Src = "module Pairs\n"
          "type Thing = (int, int) | :nothing\n"
          "atom Sum(Thing thing)\n"
          "Sum(thing) ->\n"
          "    var (a, b) = thing\n"
          "    :done\n",
    [{error, _, 'Sum', {bind_may_fail, Residual}}] = errors(Src),
    ?assertEqual(":nothing", lists:flatten(bs_types:to_pattern(Residual))).

%%% `=` IS A MATCH, and this is the spec as David wrote it on 2026-08-15:
%%%
%%%     x = 1
%%%     1 = x     // no error
%%%     2 = x     // error
%%%
%%% It already behaved this way — the pair below is here because it is now a
%%% STATED REQUIREMENT rather than a property that happened to fall out of F5,
%%% and an unpinned requirement is one refactor away from being a coincidence.
%%%
%%% It works because a literal's inferred type is a SINGLETON: `x = 1` binds
%%% `1..1`, so `1 = x` leaves an empty residual and `2 = x` leaves `1`. Widen
%%% that type and both change — see the `Get()` case below, which is the same
%%% program through a declared return.

a_literal_match_that_cannot_fail_is_accepted_test() ->
    Src = "module SpecOk\n"
          "int F()\n"
          "F() ->\n"
          "    var x = 1\n"
          "    1 = x\n"
          "    x\n",
    M = build_and_load(Src, 'SpecOk'),
    ?assertEqual(1, M:'F'()).

a_literal_match_that_cannot_succeed_is_an_error_test() ->
    Src = "module SpecErr\n"
          "int F()\n"
          "F() ->\n"
          "    var x = 1\n"
          "    2 = x\n"
          "    x\n",
    [{error, _, 'F', {bind_may_fail, Residual}}] = errors(Src),
    ?assertEqual("1", lists:flatten(bs_types:to_pattern(Residual))).

%% ...and the same match against a name whose type came from a DECLARED RETURN
%% rather than a literal. `Get()` is declared `int`, so `y` is `int` and even the
%% "correct" value is refused — the check is against the type, never against what
%% the program would do at run time. This is the case that shows the singleton
%% above is doing the work.
a_match_is_decided_by_the_type_not_the_value_test() ->
    Src = "module ViaCall\n"
          "int Get()\n"
          "Get() -> 2\n"
          "int F()\n"
          "F() ->\n"
          "    var y = Get()\n"
          "    2 = y\n"
          "    y\n",
    [{error, _, 'F', {bind_may_fail, Residual}}] = errors(Src),
    ?assertEqual("int <= 1 | int >= 3",
                 lists:flatten(bs_types:to_pattern(Residual))).

%% A plain `x = e` still produces ticket 34's node, so nothing downstream of the
%% parser learns a new shape for the case that already worked.
a_plain_binding_still_parses_as_a_name_test() ->
    %% F8 — `var` changed how the LEFT of a binding is READ, not what a binding
    %% IS. This still asserts the `{bind, …}` node ticket 34 shipped, which is the
    %% claim that nothing downstream of the parser learned a new shape.
    {ok, Toks, _} = bs_lexer:string("module M\nint F(int a)\nF(a) ->\n    var t = 1\n    t\n"),
    {ok, Decls} = bs_parser:parse(Toks),
    ?assertMatch([{clause, _, 'F', _, _, {e_block, _, [{bind, _, t, _}], _}}],
                 [D || D = {clause, _, _, _, _, _} <- Decls]).

%% F5.11 — `_` is an expression only so that `(a, _) = pair` parses. As a value
%% it is rejected here, not by erlc against a file the author did not write.
a_wildcard_may_stand_on_the_left_of_a_bind_test() ->
    Src = "module Pairs\n"
          "int First((int, int) pair)\n"
          "First(pair) ->\n"
          "    var (a, _) = pair\n"
          "    a\n",
    M = build_and_load(Src, 'Pairs'),
    ?assertEqual(3, M:'First'({3, 4})).

a_wildcard_used_as_a_value_is_an_error_test() ->
    Src = "module M\nint Bad(int n)\nBad(n) -> _\n",
    ?assertMatch([{error, _, 'Bad', wildcard_as_value}], errors(Src)).

%% A guard is not typed — no site is a guard — but `_` in one is the same
%% authoring mistake, and it is a hole F5's own grammar opened: before `_` was an
%% expression this did not parse. Left alone it reached `bs_emit:expr/2` as a
%% function-clause CRASH, which is worse than the erlc error F4.7 prevents.
a_wildcard_in_a_guard_is_an_error_not_a_crash_test() ->
    Src = "module M\natom F(int n)\nF(n) when _ > 1 -> :yes\nF(n) -> :no\n",
    ?assertMatch([{error, _, 'F', wildcard_as_value}], errors(Src)).

%% The same gap for names, which predates F5 and was the one place F4's rule was
%% false: `variable 'X' is unbound` from erlc, against a file nobody wrote.
an_unbound_name_in_a_guard_is_caught_by_bsc_test() ->
    Src = "module M\natom F(int n)\nF(n) when x > 1 -> :yes\nF(n) -> :no\n",
    ?assertMatch([{error, _, 'F', {unbound_variable, x}}], errors(Src)).

%% ...and a guard calling a user function still names only its ARGUMENTS, so the
%% callee is not mistaken for an unbound variable.
a_guard_calling_a_function_is_not_an_unbound_name_test() ->
    Src = "module M\n"
          "atom Weird(int n)\n"
          "Weird(n) -> :yes\n"
          "atom F(int n)\n"
          "F(n) when Weird(n) -> :yes\n"
          "F(n)               -> :no\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% Everything else on the left of `=` is a parse error naming what belongs
%% there, rather than an obscure failure further down.
a_non_pattern_on_the_left_of_a_bind_is_rejected_test() ->
    {ok, Toks, _} = bs_lexer:string(
                      "module M\nint F(int a)\nF(a) ->\n    a + 1 = 2\n    a\n"),
    ?assertMatch({error, {_, _, _}}, bs_parser:parse(Toks)).

%% F5.12 — same lookup as site 1. Without it the author meets
%% `function 'Nope'/1 undefined` against an emitted file they never wrote.
a_call_to_an_undeclared_name_is_caught_by_bsc_test() ->
    Src = "module M\nint F(int n)\nF(n) -> Nope(n)\n",
    ?assertMatch([{error, _, 'F', {unknown_callee, 'Nope', 1}}], errors(Src)).

a_call_with_the_wrong_arity_is_caught_by_bsc_test() ->
    Src = "module M\nint F(int n)\nF(n) -> F(n, n)\n",
    ?assertMatch([{error, _, 'F', {arity_mismatch, 'F', 2, 1}}], errors(Src)).

%% F5.13 — the corpus. F5 adds four new ways to be rejected, and the README's
%% own rule is that a capability which closes a residual must not make
%% previously-valid programs invalid. This is the gate that was run before any
%% rejection test above was written.
every_example_still_compiles_test() ->
    Dir = project_root() ++ "/examples",
    {ok, Names} = file:list_dir(Dir),
    Sources = [filename:join(Dir, N) || N <- lists:sort(Names),
                                        filename:extension(N) =:= ".bs"],
    ?assert(length(Sources) >= 6),
    [?assertMatch({N, {ok, _}}, {N, bsc:file_to_dir(N, ?OUT)}) || N <- Sources].

%% A list element is bound at a REAL path now, because the body check has to
%% read `rest` back out and answer `list<int>`. Answering `term` rejects this —
%% a shipped example, with a checker working correctly on wrong information.
a_list_tail_keeps_its_element_type_in_a_body_test() ->
    Src = "module L\n"
          "list<int> Reverse(list<int> xs, list<int> acc)\n"
          "Reverse([], acc)          -> acc\n"
          "Reverse([x, ..rest], acc) -> Reverse(rest, [x, ..acc])\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% ...and the guard side is exactly as conservative as it was: a path through a
%% list step is unrefinable, so this stays inexhaustive rather than silently
%% becoming exhaustive on an address the algebra cannot narrow.
a_guard_over_a_list_element_still_credits_nothing_test() ->
    Src = "module L\n"
          "atom Sign(list<int> xs)\n"
          "Sign([])             -> :empty\n"
          "Sign([x, ..r]) when x > 0  -> :positive\n"
          "Sign([x, ..r]) when x <= 0 -> :nonpositive\n",
    ?assertMatch([{error, _, 'Sign', {inexhaustive, _}}], errors(Src)).

