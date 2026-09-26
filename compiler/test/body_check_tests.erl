%%% Scenarios: compiler/features/F5-body-check-site.md
%%% Scenarios: compiler/features/F21-field-value-obligations.md
%%% Scenarios: compiler/features/F3-records.md
-module(body_check_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, check_only/1, errors/1,
                          project_root/0, escript/0, run_cli/1, with_src/3]).

-define(OUT, bs_test_support:run_root()).

%%% Body check sites

docs_src() ->
    "module Shop\n"
    "record Order   { Id: int, Total: int }\n"
    "record Invoice { Id: int, Total: int }\n"
    "public Order Update(Order o)\n"
    "Update(o) -> o with { Total = 0 }\n".

%% F5.1 — a body must produce its declared return type.
a_body_must_produce_the_declared_return_type_test() ->
    Src = "module M\npublic int Answer(int n)\nAnswer(n) -> :oops\n",
    ?assertMatch([{error, _, 'Answer', {return_not_declared, _, _}}], errors(Src)).

a_body_producing_the_declared_type_compiles_test() ->
    Src = "module M\npublic atom Answer(int n)\nAnswer(n) -> :ok\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F5.2 — a call rejects the wrong record.
a_call_rejects_the_wrong_record_test() ->
    Src = docs_src() ++
          "public Order Wrong(Invoice i)\n"
          "Wrong(i) -> Update(i)\n",
    ?assertMatch([{error, _, 'Wrong', {arg_not_accepted, 'Update', 1, _, _}}],
                 errors(Src)).

a_call_with_the_right_record_compiles_test() ->
    Src = docs_src() ++
          "public Order Right(Order o)\n"
          "Right(o) -> Update(o)\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F5.3 — the residual proposes a clause for the caller, not the callee.
the_call_site_residual_is_the_callers_clause_head_test() ->
    case bs_test_support:built() of
        false -> ok;
        true ->
            Src = docs_src() ++
                  "public Order Wrong(Invoice i)\n"
                  "Wrong(i) -> Update(i)\n",
            with_src("callsite.bs", Src, fun(Path, Out) ->
                R = run_cli("-o " ++ Out ++ " " ++ Path),
                %% The proposed head uses record pattern syntax.
                ?assert(string:find(R, "Wrong(Invoice i) -> ...") =/= nomatch),
                %% The diagnostic must not suggest widening the callee.
                ?assertEqual(nomatch, string:find(R, "Update({")),
                ?assertEqual(nomatch, string:find(R, "Update(Invoice"))
            end)
    end.

%% F5.4 — construction supplies exactly the declared fields.
construction_must_supply_every_declared_field_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "public Order Make(int n)\n"
          "Make(n) -> Order{ Id = n }\n",
    ?assertMatch([{error, _, 'Make', {field_set_mismatch, 'Order', construction, ['Total'], []}}],
                 errors(Src)).

construction_may_not_supply_an_undeclared_field_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "public Order Make(int n)\n"
          "Make(n) -> Order{ Id = n, Total = n, Extra = n }\n",
    ?assertMatch([{error, _, 'Make', {field_set_mismatch, 'Order', construction, [], ['Extra']}}],
                 errors(Src)).

construction_with_the_exact_field_set_compiles_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "public Order Make(int n)\n"
          "Make(n) -> Order{ Id = n, Total = n }\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F5.5 — the residual names the member lacking the projected field.
projecting_a_field_one_member_lacks_names_that_member_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "record Note  { Id: int }\n"
          "type Doc = Order | Note\n"
          "public int Amount(Doc d)\n"
          "Amount(d) -> d.Total\n",
    [{error, _, 'Amount', {field_absent, projection, 'Total', Residual}}] = errors(Src),
    ?assertEqual("{ Kind: :'Shop.Note' }",
                 lists:flatten(bs_types:to_pattern(Residual))).

%% F3.8 — projection is legal when every member carries the field.
projecting_a_field_every_member_carries_compiles_test() ->
    Src = "module Shop\n"
          "record Order   { Id: int, Total: int }\n"
          "record Invoice { Id: int, Total: int }\n"
          "type Doc = Order | Invoice\n"
          "public int Amount(Doc d)\n"
          "Amount(d) -> d.Total\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F5.6 — an earlier clause narrows a later body.
narrow_src(Clauses) ->
    "module Narrow\n"
    "type Flag = :on | :off\n"
    "public atom Only(:on f)\n"
    "Only(f) -> :ok\n"
    "public atom Run(Flag f)\n" ++ Clauses.

an_earlier_clause_narrows_a_later_body_test() ->
    ?assertMatch({ok, _, _},
                 check_only(narrow_src("Run(:off) -> :no\nRun(f) -> Only(f)\n"))).

%% The earlier clause, not the variable pattern, supplies the narrowing.
without_the_earlier_clause_the_same_body_is_an_error_test() ->
    ?assertMatch([{error, _, 'Run', {arg_not_accepted, 'Only', 1, _, _}} | _],
                 errors(narrow_src("Run(f) -> Only(f)\n"))).

%% F5.7 — an untranslatable guard leaves the body typed.
%% The remainder guard is legal on the BEAM but earns no coverage credit.
%% An empty body domain would make the invalid projection pass vacuously.
an_untranslatable_guard_leaves_the_body_typed_test() ->
    Src = "module Guarded\n"
          "public atom Classify(int n)\n"
          "Classify(n) when n % 2 == 0 -> n.Total\n"
          "Classify(n)                 -> :other\n",
    ?assertMatch([{error, _, 'Classify', {field_absent, projection, 'Total', _}}],
                 errors(Src)).

%% F5.8 — foreign callees receive the same argument checks.
a_foreign_callee_is_checked_like_any_other_test() ->
    Src = "module Interop\n"
          "using :lists { int sum(list<int> xs) }\n"
          "public int Bad(atom a)\n"
          "Bad(a) -> :lists.sum(a)\n",
    ?assertMatch([{error, _, 'Bad', {arg_not_accepted, _, 1, _, _}}], errors(Src)).

a_foreign_call_with_the_declared_type_compiles_test() ->
    Src = "module Interop\n"
          "using :lists { int sum(list<int> xs) }\n"
          "public int Good(list<int> xs)\n"
          "Good(xs) -> :lists.sum(xs)\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F5.9 — a binding carries its inferred type into the body.
a_binding_carries_its_type_into_the_rest_of_the_body_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "public atom Wrong(Order o)\n"
          "Wrong(o) ->\n"
          "    var t = o.Total\n"
          "    t\n",
    ?assertMatch([{error, _, 'Wrong', {return_not_declared, _, _}}], errors(Src)).

%% F5.10 — destructuring is accepted only when its residual is empty.
a_destructuring_bind_that_cannot_fail_runs_test() ->
    Src = "module Pairs\n"
          "public int Sum((int, int) pair)\n"
          "Sum(pair) ->\n"
          "    var (a, b) = pair\n"
          "    a + b\n",
    M = build_and_load(Src, 'Pairs'),
    ?assertEqual(7, M:'Sum'({3, 4})).

a_destructuring_bind_that_can_fail_is_an_error_test() ->
    Src = "module Pairs\n"
          "type Thing = (int, int) | :nothing\n"
          "public atom Sum(Thing thing)\n"
          "Sum(thing) ->\n"
          "    var (a, b) = thing\n"
          "    :done\n",
    [{error, _, 'Sum', {bind_may_fail, Residual}}] = errors(Src),
    ?assertEqual(":nothing", lists:flatten(bs_types:to_pattern(Residual))).

%%% Literal matches

a_literal_match_that_cannot_fail_is_accepted_test() ->
    Src = "module SpecOk\n"
          "public int F()\n"
          "F() ->\n"
          "    var x = 1\n"
          "    1 = x\n"
          "    x\n",
    M = build_and_load(Src, 'SpecOk'),
    ?assertEqual(1, M:'F'()).

a_literal_match_that_cannot_succeed_is_an_error_test() ->
    Src = "module SpecErr\n"
          "public int F()\n"
          "F() ->\n"
          "    var x = 1\n"
          "    2 = x\n"
          "    x\n",
    [{error, _, 'F', {bind_may_fail, Residual}}] = errors(Src),
    ?assertEqual("1", lists:flatten(bs_types:to_pattern(Residual))).

%% Get returns int, so matching 2 can fail despite its literal return value.
a_match_is_decided_by_the_type_not_the_value_test() ->
    Src = "module ViaCall\n"
          "public int Get()\n"
          "Get() -> 2\n"
          "public int F()\n"
          "F() ->\n"
          "    var y = Get()\n"
          "    2 = y\n"
          "    y\n",
    [{error, _, 'F', {bind_may_fail, Residual}}] = errors(Src),
    ?assertEqual("int <= 1 | int >= 3",
                 lists:flatten(bs_types:to_pattern(Residual))).

a_plain_binding_still_parses_as_a_name_test() ->
    %% A name binding uses the bind node, not a destructuring node.
    {ok, Toks, _} = bs_lexer:string("module M\npublic int F(int a)\nF(a) ->\n    var t = 1\n    t\n"),
    {ok, Decls} = bs_parser:parse(Toks),
    ?assertMatch([{clause, _, 'F', _, _, {e_block, _, [{bind, _, t, _}], _}}],
                 [D || D = {clause, _, _, _, _, _} <- Decls]).

%% F5.11 — a wildcard is a pattern, not a value.
a_wildcard_may_stand_on_the_left_of_a_bind_test() ->
    Src = "module Pairs\n"
          "public int First((int, int) pair)\n"
          "First(pair) ->\n"
          "    var (a, _) = pair\n"
          "    a\n",
    M = build_and_load(Src, 'Pairs'),
    ?assertEqual(3, M:'First'({3, 4})).

a_wildcard_used_as_a_value_is_an_error_test() ->
    Src = "module M\npublic int Bad(int n)\nBad(n) -> _\n",
    ?assertMatch([{error, _, 'Bad', wildcard_as_value}], errors(Src)).

a_wildcard_in_a_guard_is_an_error_not_a_crash_test() ->
    Src = "module M\npublic atom F(int n)\nF(n) when _ > 1 -> :yes\nF(n) -> :no\n",
    ?assertMatch([{error, _, 'F', wildcard_as_value}], errors(Src)).

an_unbound_name_in_a_guard_is_caught_by_bsc_test() ->
    Src = "module M\npublic atom F(int n)\nF(n) when x > 1 -> :yes\nF(n) -> :no\n",
    ?assertMatch([{error, _, 'F', {unbound_variable, x}}], errors(Src)).

%% The call is illegal, but its callee is not an unbound variable.
a_guard_calling_a_function_is_not_an_unbound_name_test() ->
    Src = "module M\n"
          "public atom Weird(int n)\n"
          "Weird(n) -> :yes\n"
          "public atom F(int n)\n"
          "F(n) when Weird(n) -> :yes\n"
          "F(n)               -> :no\n",
    ?assertMatch([{error, _, 'F', {call_in_guard, 'Weird'}}], errors(Src)).

a_non_pattern_on_the_left_of_a_bind_is_rejected_test() ->
    {ok, Toks, _} = bs_lexer:string(
                      "module M\npublic int F(int a)\nF(a) ->\n    a + 1 = 2\n    a\n"),
    ?assertMatch({error, {_, _, _}}, bs_parser:parse(Toks)).

%% F5.12 — bsc rejects undeclared callees and wrong arities.
a_call_to_an_undeclared_name_is_caught_by_bsc_test() ->
    Src = "module M\npublic int F(int n)\nF(n) -> Nope(n)\n",
    ?assertMatch([{error, _, 'F', {unknown_callee, 'Nope', 1}}], errors(Src)).

a_call_with_the_wrong_arity_is_caught_by_bsc_test() ->
    Src = "module M\npublic int F(int n)\nF(n) -> F(n, n)\n",
    ?assertMatch([{error, _, 'F', {arity_mismatch, 'F', 2, 1}}], errors(Src)).

%% F5.13 — the example corpus compiles.
%% Compile whole module directories through the CLI to check source paths.
%% One subprocess per directory needs more than eunit's default timeout.
every_example_still_compiles_test_() ->
    {timeout, 120, fun every_example_still_compiles/0}.

every_example_still_compiles() ->
    Root = project_root() ++ "/examples",
    Dirs = [D || D <- bsc:module_dirs(Root),
                 string:find(D, "/exemplars/") =:= nomatch],
    ?assert(length(Dirs) >= 6),
    [?assertEqual({D, ok}, {D, compiles(Root, D)}) || D <- Dirs].

%% Dotted module names require a source root above their nested directories.
compiles(Root, Dir) ->
    Out = bs_test_support:run_cli("--src-root " ++ Root ++ " -o " ++ ?OUT ++
                                      "/corpus " ++ Dir),
    case string:find(Out, "rc:0") of
        nomatch -> Out;
        _       -> ok
    end.

%% Single-segment module names exercise the default source root.
every_aoc_program_still_compiles_test() ->
    Aoc = filename:dirname(project_root()) ++ "/aoc",
    Dirs = bsc:module_dirs(Aoc),
    ?assert(length(Dirs) >= 3),
    [?assertEqual({D, ok}, {D, compiles_with_default_root(D)}) || D <- Dirs].

%% Separate output directories keep the Day01 modules from overwriting.
compiles_with_default_root(Dir) ->
    Out = bs_test_support:run_cli("-o " ++ ?OUT ++ "/corpus/" ++
                                      filename:basename(filename:dirname(Dir)) ++
                                      " " ++ Dir),
    case string:find(Out, "rc:0") of
        nomatch -> Out;
        _       -> ok
    end.

a_list_tail_keeps_its_element_type_in_a_body_test() ->
    Src = "module L\n"
          "public list<int> Reverse(list<int> xs, list<int> acc)\n"
          "Reverse([], acc)          -> acc\n"
          "Reverse([x, ..rest], acc) -> Reverse(rest, [x, ..acc])\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% List-element paths cannot be refined, even by complementary guards.
a_guard_over_a_list_element_still_credits_nothing_test() ->
    Src = "module L\n"
          "public atom Sign(list<int> xs)\n"
          "Sign([])             -> :empty\n"
          "Sign([x, ..r]) when x > 0  -> :positive\n"
          "Sign([x, ..r]) when x <= 0 -> :nonpositive\n",
    ?assertMatch([{error, _, 'Sign', {inexhaustive, _, _}}], errors(Src)).

%%% Field value obligations

%% F21.1 — construction checks the value assigned to a field.
construction_checks_the_value_assigned_to_a_field_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "public Order Make(int n)\n"
          "Make(n) -> Order{ Id = :oops, Total = n }\n",
    ?assertMatch([{error, _, 'Make',
                   {field_value_not_accepted, 'Order', 'Id', _}}],
                 errors(Src)).

%% F21.2 — updates check values against the same field declarations.
with_checks_the_value_assigned_to_a_field_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "public Order Bump(Order o)\n"
          "Bump(o) -> o with { Total = :oops }\n",
    ?assertMatch([{error, _, 'Bump',
                   {field_value_not_accepted, 'Order', 'Total', _}}],
                 errors(Src)).

%% Ticket 109 Q2: `with` keeps each member in itself, so it cannot move a
%% value to another member; a member with no record name is shown by its shape.
reissue(DocType, Update) ->
    "module Reissue\n"
    "type Doc = " ++ DocType ++ "\n"
    "public Doc Settle(Doc d)\n"
    "Settle(d) -> d with { " ++ Update ++ " }\n".

joined() -> "{ Kind: :invoice | :receipt, Id: int }".

split() -> "{ Kind: :invoice, Id: int } | { Kind: :receipt, Id: int }".

%% From the file name on: each fixture lives in its own directory.
reissue_output(Src) ->
    with_src("reissue.bs", Src,
             fun(Path, Out) ->
                     string:find(run_cli("-o " ++ Out ++ " " ++ Path), "reissue.bs:")
             end).

with_cannot_move_a_value_to_another_member_test() ->
    Got = reissue_output(reissue(joined(), "Kind = :receipt")),
    ?assert(string:find(Got, "Settle assigns Kind a value") =/= nomatch),
    ?assertEqual(nomatch, string:find(Got, "a value invoice does not")),
    ?assert(string:find(Got, "Kind: :invoice") =/= nomatch),
    ?assert(string:find(Got, "rc:1") =/= nomatch),
    %% Both spellings of `Doc` are one type, so they get one answer.
    ?assertEqual(Got, reissue_output(reissue(split(), "Kind = :receipt"))).

%% A hand-written `:receipt` is a tag, not a record's name.
an_undeclared_key_over_tagged_members_names_no_record_test() ->
    Got = reissue_output(reissue(joined(), "Foo = 1")),
    ?assert(string:find(Got, "rc:1") =/= nomatch),
    ?assertEqual(nomatch, string:find(Got, "an receipt")),
    ?assertEqual(nomatch, string:find(Got, "by invoice")).

%% Records already refused the cross-member `with`; the name stays the record's.
with_cannot_turn_one_record_into_another_test() ->
    Src = "module Morph\n"
          "record Invoice { Id: int }\n"
          "record Receipt { Id: int }\n"
          "type Document = Invoice | Receipt\n"
          "public Document Settle(Document d)\n"
          "Settle(d) -> d with { Kind = :'Morph.Receipt' }\n",
    ?assertMatch([{error, _, 'Settle',
                   {field_value_not_accepted, 'Invoice', 'Kind', _}}],
                 errors(Src)).

%% F21.3 — the residual is the rejected value, not the record.
the_rejected_value_is_handed_back_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "public Order Make(int n)\n"
          "Make(n) -> Order{ Id = :oops, Total = n }\n",
    [{error, _, _, {field_value_not_accepted, _, _, Residual}}] = errors(Src),
    ?assertEqual(":oops", bs_types:to_pattern(Residual)).

%% F21.4 — literals, parameters, projections, bindings and calls supply values.
a_correctly_assigned_record_compiles_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "public int Double(int n)\n"
          "Double(n) -> n * 2\n"
          "public Order New(int id)\n"
          "New(id) -> Order{ Id = id, Total = 0 }\n"
          "public Order Twice(Order o)\n"
          "Twice(o) ->\n"
          "    var t = Double(o.Total)\n"
          "    o with { Total = t }\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F21.5 — a refined field rejects a value outside its range.
a_refined_field_rejects_a_value_outside_it_test() ->
    Src = "module Shop\n"
          "type Octet = int where value >= 0 and value <= 255\n"
          "record Pixel { Level: Octet }\n"
          "public Pixel Make()\n"
          "Make() -> Pixel{ Level = 300 }\n",
    ?assertMatch([{error, _, 'Make',
                   {field_value_not_accepted, 'Pixel', 'Level', _}}],
                 errors(Src)).

%% F21.6 — a failed expression produces no cascading field-value error.
a_value_that_already_failed_is_not_reported_twice_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "public Order Make(int n)\n"
          "Make(n) -> Order{ Id = Missing(n), Total = n }\n",
    Errors = errors(Src),
    ?assertEqual([], [D || D <- Errors,
                           element(4, D) =/= undefined,
                           is_tuple(element(4, D)),
                           element(1, element(4, D)) =:= field_value_not_accepted]),
    ?assertNotEqual([], Errors).

%% F21.7 — updates reject undeclared fields.
%% Updates need only a subset of fields, so the missing-field list is empty.
with_may_not_invent_a_field_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "public Order Grow(Order o)\n"
          "Grow(o) -> o with { Nope = 1 }\n",
    ?assertMatch([{error, _, 'Grow',
                   {field_set_mismatch, 'Order', update, [], ['Nope']}}],
                 errors(Src)).

%% F21.8 — the diagnostic describes an update, not a construction.
%% CLI prose distinguishes the verbs; the diagnostic term cannot.
the_with_diagnostic_does_not_say_builds_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "public Order Grow(Order o)\n"
          "Grow(o) -> o with { Nope = 1 }\n",
    with_src("grow.bs", Src, fun(Path, Out) ->
        R = run_cli("-o " ++ Out ++ " " ++ Path),
        ?assert(string:find(R, "updates an Order with the wrong fields") =/= nomatch),
        ?assertEqual(nomatch, string:find(R, "builds an Order")),
        ?assertEqual(nomatch, string:find(R, "missing, and must be supplied"))
    end).

%% F21.9 — prose names both the assigned field and its rejecting declaration.
the_value_diagnostic_reaches_the_author_as_prose_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "public Order Make(int n)\n"
          "Make(n) -> Order{ Id = :oops, Total = n }\n",
    with_src("make.bs", Src, fun(Path, Out) ->
        R = run_cli("-o " ++ Out ++ " " ++ Path),
        ?assert(string:find(R, "Make assigns Id a value Order does not accept")
                =/= nomatch),
        ?assert(string:find(R, "not covered by the declared type of Id:") =/= nomatch),
        ?assert(string:find(R, ":oops") =/= nomatch)
    end).

%%% Update subjects

%% F21.10 — updating an int fails without a cascading return-type error.
with_on_an_int_is_refused_test() ->
    Src = "module Shop\n"
          "public int Bump(int n)\n"
          "Bump(n) -> n with { Total = 1 }\n",
    [{error, _, 'Bump', {field_absent, update, 'Total', Residual}}] = errors(Src),
    ?assertEqual("int", lists:flatten(bs_types:to_pattern(Residual))).

%% F21.11 — term does not guarantee a map carrying the updated field.
with_on_a_term_is_refused_test() ->
    Src = "module Shop\n"
          "public term Put(term m)\n"
          "Put(m) -> m with { Total = 1 }\n",
    ?assertMatch([{error, _, 'Put', {field_absent, update, 'Total', _}}],
                 errors(Src)).

%% F21.12 — a list of pairs is not a record to update.
with_on_a_list_of_pairs_is_refused_test() ->
    Src = "module Shop\n"
          "public list<(atom, term)> Put(list<(atom, term)> m)\n"
          "Put(m) -> m with { Total = 1 }\n",
    ?assertMatch([{error, _, 'Put', {field_absent, update, 'Total', _}}],
                 errors(Src)).

%% F21.13 — the residual names the union member lacking the updated field.
with_on_a_union_member_lacking_the_field_is_refused_test() ->
    Src = "module Shop\n"
          "record Order { Id: int, Total: int }\n"
          "record Note  { Id: int }\n"
          "type Doc = Order | Note\n"
          "public Doc Pay(Doc d)\n"
          "Pay(d) -> d with { Total = 500 }\n",
    [{error, _, 'Pay', {field_absent, update, 'Total', Residual}}] = errors(Src),
    ?assertEqual("{ Kind: :'Shop.Note' }",
                 lists:flatten(bs_types:to_pattern(Residual))).

%% F21.14 — updates check values against every union member's declaration.
with_on_a_union_every_member_carries_runs_the_value_half_per_member_test() ->
    Base = "module Shop\n"
           "record Order   { Id: int, Total: int }\n"
           "record Invoice { Id: int, Total: int }\n"
           "type Doc = Order | Invoice\n"
           "public Doc Pay(Doc d)\n",
    ?assertMatch({ok, _, _}, check_only(Base ++ "Pay(d) -> d with { Total = 500 }\n")),
    Errors = errors(Base ++ "Pay(d) -> d with { Total = :oops }\n"),
    ?assertEqual(['Invoice', 'Order'],
                 lists:sort([R || {error, _, 'Pay',
                                   {field_value_not_accepted, R, 'Total', _}} <- Errors])),
    ?assertEqual(2, length(Errors)).

%% F21.16 — a field absent from every member is an undeclared-field error.
%% Discriminating on the tag cannot find a member carrying that field.
with_on_a_union_undeclared_field_is_the_name_defect_test() ->
    Src = "module Shop\n"
          "record Order   { Id: int, Total: int }\n"
          "record Invoice { Id: int, Total: int }\n"
          "type Doc = Order | Invoice\n"
          "public Doc Grow(Doc d)\n"
          "Grow(d) -> d with { Nope = 1 }\n",
    Errors = errors(Src),
    ?assertEqual([{field_set_mismatch, 'Invoice', update, [], ['Nope']},
                  {field_set_mismatch, 'Order',   update, [], ['Nope']}],
                 lists:sort([D || {error, _, 'Grow', D} <- Errors])).

%% F21.15 — a recursive record remains a valid update subject.
%% Its fields are visible after unfolding the recursive type.
with_on_a_recursive_record_compiles_test() ->
    Src = "module Shop\n"
          "record Node { Kids: list<Node> }\n"
          "public Node Clear(Node n)\n"
          "Clear(n) -> n with { Kids = [] }\n",
    ?assertMatch({ok, _, _}, check_only(Src)).
