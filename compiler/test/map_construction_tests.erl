%%% Scenarios: compiler/features/F57-brace-expression.md
%%% F57 — the brace expression `{ Key = value }` builds a field set.
%%%
%%% The value has no `Kind`, so it is never a record; its type is the exact
%%% field set its values give, and the ordinary check sites compare that
%%% against what the site expects.

-module(map_construction_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, errors/1]).

tags(Src) -> [element(1, element(4, E)) || E <- errors(Src)].

%% F57.1 — it builds, runs, and is a plain map with no `Kind`.
a_brace_expression_builds_a_map_test() ->
    M = build_and_load("module Brace1\n"
                       "public { Status: int, Body: atom } Ok(int n)\n"
                       "Ok(n) -> { Status = n, Body = :ok }\n", 'Brace1'),
    ?assertEqual(#{'Status' => 200, 'Body' => ok}, M:'Ok'(200)).

%% F57.2 — a value the declared field does not accept is refused at the return.
a_wrong_value_is_refused_at_the_return_test() ->
    ?assertEqual([return_not_declared],
                 tags("module Brace2\n"
                      "public { Status: int } Ok(int n)\n"
                      "Ok(n) -> { Status = :x }\n")).

%% F57.3 — the field set is exact: a missing key is refused.
a_missing_key_is_refused_test() ->
    ?assertEqual([return_not_declared],
                 tags("module Brace3\n"
                      "public { Status: int, Body: atom } Ok(int n)\n"
                      "Ok(n) -> { Status = n }\n")).

%% F57.4 — and so is an extra one.
an_extra_key_is_refused_test() ->
    ?assertEqual([return_not_declared],
                 tags("module Brace4\n"
                      "public { Status: int } Ok(int n)\n"
                      "Ok(n) -> { Status = n, Body = :ok }\n")).

%% F57.5 — at an argument, checked against the callee's parameter.
checked_at_an_argument_test() ->
    Src = fun(V) ->
              "module Brace5\n"
              "public int Code({ Status: int } r)\n"
              "Code({ Status: s }) -> s\n"
              "public int Go(int n)\n"
              "Go(n) -> Code({ Status = " ++ V ++ " })\n"
          end,
    M = build_and_load(Src("n"), 'Brace5'),
    ?assertEqual(404, M:'Go'(404)),
    ?assertEqual([arg_not_accepted], tags(Src(":oops"))).

%% F57.6 — it has no `Kind`, so it is not the record with the same fields.
not_a_record_test() ->
    ?assertEqual([arg_not_accepted],
                 tags("module Brace6\n"
                      "record Reply { Status: int }\n"
                      "public int Code(Reply r)\n"
                      "Code(r) -> r.Status\n"
                      "public int Go(int n)\n"
                      "Go(n) -> Code({ Status = n })\n")).

%% F57.7 — a key written twice is refused; an Erlang map literal would keep
%% the last one silently.
a_duplicate_key_is_refused_test() ->
    ?assertMatch([{error, _, 'Ok', {duplicate_field, 'Status'}}],
                 errors("module Brace7\n"
                        "public { Status: int } Ok(int n)\n"
                        "Ok(n) -> { Status = n, Status = 2 }\n")).

%% F57.8 — `ToJson` writes it with no `Kind`, since the type has none.
to_json_writes_it_untagged_test() ->
    M = build_and_load("module Brace8\n"
                       "public string Body(int n)\n"
                       "Body(n) -> ToJson<{ Status: int }>({ Status = n })\n", 'Brace8'),
    ?assertEqual(#{<<"Status">> => 201}, json:decode(M:'Body'(201))).

%% F57.9 — nested, with a record inside, and taken apart by a clause head.
nested_and_destructured_test() ->
    M = build_and_load("module Brace9\n"
                       "record Order { Id: int }\n"
                       "type Problem = { Error: string, At: { Line: int }, Order: Order }\n"
                       "public Problem Bad(int n)\n"
                       "Bad(n) -> { Error = \"invalid\", At = { Line = n }, Order = Order { Id = n } }\n"
                       "public int Line(Problem p)\n"
                       "Line({ At: { Line: l } }) -> l\n", 'Brace9'),
    P = M:'Bad'(7),
    ?assertEqual(#{'Error' => <<"invalid">>, 'At' => #{'Line' => 7},
                   'Order' => #{'Kind' => 'Brace9.Order', 'Id' => 7}}, P),
    ?assertEqual(7, M:'Line'(P)).

%% F57.10 — in a switch arm and as a lambda's result, which are other sites.
in_an_arm_and_a_lambda_test() ->
    M = build_and_load("module Brace10\n"
                       "public list<{ N: int }> Wrap(list<int> xs)\n"
                       "Wrap(xs) -> List.Map(xs, (n) => n switch {\n"
                       "    0 => { N = 0 },\n"
                       "    k => { N = k }\n"
                       "})\n", 'Brace10'),
    ?assertEqual([#{'N' => 0}, #{'N' => 3}], M:'Wrap'([0, 3])).
