%%% Scenarios: compiler/features/F59-open-field-sets.md
%%% F59 — a trailing `..` makes a field-set type open.
%%%
%%% The fixture is OpenRouter's evaluate reply, which carries `id`, `provider`
%%% and `usage.cost` beyond the keys a caller needs. `{ "model": string, .. }`
%%% names the keys it needs and admits the rest. `ValidateAs` checks the named
%%% keys and returns the value unchanged; without `..` a field set stays
%%% exact; `ToJson` refuses an open type, since it would publish keys no type
%%% declares.

-module(open_field_set_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, errors/1, check_only/1]).

tags(Src) -> [element(1, element(4, E)) || E <- errors(Src)].

reply_src() ->
    "module Open1\n"
    "type UsageWire = { \"input_tokens\": int, \"output_tokens\": int, .. }\n"
    "type ReplyWire = { \"model\": string, \"usage\": UsageWire, .. }\n"
    "public result<ReplyWire, ValidationError> Read(term t)\n"
    "Read(t) -> ValidateAs<ReplyWire>(t)\n"
    "public int Tokens(ReplyWire r)\n"
    "Tokens({ \"usage\": { \"input_tokens\": i, \"output_tokens\": o } }) -> i + o\n".

openrouter() ->
    json:decode(<<"{\"id\":\"gen-jev-test\",\"model\":\"typesafe/jev-1.13\","
                  "\"provider\":\"TypeSafe AI\","
                  "\"usage\":{\"input_tokens\":100,\"output_tokens\":20,\"cost\":0.0042}}">>).

%% F59.1 — OpenRouter's reply validates, extra keys at both levels, unchanged.
an_open_type_admits_extra_keys_test() ->
    M = build_and_load(reply_src(), 'Open1'),
    Doc = openrouter(),
    ?assertEqual(Doc, M:'Read'(Doc)),
    ?assertEqual(120, M:'Tokens'(Doc)).

%% F59.2 — a named key still has to be there, with the declared type.
a_named_key_is_still_required_test() ->
    M = build_and_load(reply_src(), 'Open1'),
    {error, #{'Path' := P1}} = M:'Read'(maps:remove(<<"model">>, openrouter())),
    ?assertEqual([], P1),
    {error, #{'Path' := P2, 'Expected' := E2}} =
        M:'Read'((openrouter())#{<<"model">> => 7}),
    ?assertEqual({[<<"[\"model\"]">>], <<"string">>}, {P2, E2}).

%% F59.3 — without `..` a field set stays exact.
without_the_marker_it_stays_exact_test() ->
    M = build_and_load("module Open3\n"
                       "public result<{ \"model\": string }, ValidationError> Read(term t)\n"
                       "Read(t) -> ValidateAs<{ \"model\": string }>(t)\n", 'Open3'),
    ?assertMatch({error, #{'Path' := []}},
                 M:'Read'(#{<<"model">> => <<"m">>, <<"id">> => <<"x">>})).

%% F59.4 — `ToJson` refuses an open type, naming where it is. The refusal is
%% raised from the obligation's site, as every `unencodable_member` is.
to_json_refuses_an_open_type_test() ->
    {'EXIT', {{unencodable_member, _, 'Body', _, Segs, _, Kind}, _}} =
        catch check_only("module Open4\n"
                         "type Inner = { \"n\": int, .. }\n"
                         "public string Body({ \"inner\": Inner } w)\n"
                         "Body(w) -> ToJson<{ \"inner\": Inner }>(w)\n"),
    ?assertEqual({["[\"inner\"]"], open_map}, {Segs, Kind}).

%% F59.5 — an exact value goes where an open type is expected; not the reverse.
exact_is_a_subtype_of_open_test() ->
    Src = fun(Param, Arg) ->
              "module Open5\n"
              "public int Code(" ++ Param ++ " r)\n"
              "Code({ Status: s }) -> s\n"
              "public int Go(" ++ Arg ++ " x)\n"
              "Go(x) -> Code(x)\n"
          end,
    ?assertMatch({ok, _, _}, check_only(Src("{ Status: int, .. }", "{ Status: int }"))),
    ?assertEqual([arg_not_accepted], tags(Src("{ Status: int }", "{ Status: int, .. }"))).

%% F59.6 — the brace expression builds an exact set, which an open type accepts.
a_brace_goes_where_an_open_type_is_expected_test() ->
    M = build_and_load("module Open6\n"
                       "public { Status: int, .. } Ok(int n)\n"
                       "Ok(n) -> { Status = n, Body = :ok }\n", 'Open6'),
    ?assertEqual(#{'Status' => 1, 'Body' => ok}, M:'Ok'(1)).

%% F59.7 — a record's field set is exact; `..` in a record is refused at the parse.
a_record_cannot_be_open_test() ->
    {ok, Toks, _} = bs_lexer:string("module Open7\nrecord R { X: int, .. }\n"),
    ?assertMatch({error, _}, bs_parser:parse(Toks)).

%% F59.8 — the type prints with its marker, in `--api` as it is written.
the_api_prints_the_marker_test_() ->
    {timeout, 60,
     fun() ->
         bs_test_support:with_src("open.bs",
             "module Open8\n"
             "public int Go({ \"model\": string, .. } w)\n"
             "Go({ \"model\": m }) -> 1\n",
             fun(Path, _Out) ->
                 {0, Output} = bs_test_support:run_cli_result("--api " ++ Path),
                 ?assertNotEqual(nomatch, string:find(Output, "{ \"model\": string, .. }"))
             end)
     end}.

%% F59.9 — a declaration path through a string key is spelled
%% `W["a"]`, as a validation path is, not Erlang's `W.<<"a">>`.
a_declaration_path_spells_a_string_key_test() ->
    {'EXIT', {{absorbed_member, _, Path, _, _, _}, _}} =
        catch check_only("module Open9\n"
                         "type W = { \"a\": atom | :x }\n"
                         "public int Go(W w)\n"
                         "Go(w) -> 1\n"),
    ?assertEqual("W[\"a\"]", Path).

%% F59.10 — a value in the open member validates although its keys also fit
%% an exact member's shape; a value in neither member is still refused.
validation_tries_the_open_member_test() ->
    M = build_and_load("module Open10\n"
                       "type E = { \"a\": int, .. } | { \"a\": string, \"b\": int }\n"
                       "public result<E, ValidationError> Read(term t)\n"
                       "Read(t) -> ValidateAs<E>(t)\n"
                       "type T = { \"a\": :x, .. } | { \"a\": :y, \"b\": int }\n"
                       "public result<T, ValidationError> Tagged(term t)\n"
                       "Tagged(t) -> ValidateAs<T>(t)\n", 'Open10'),
    InOpen = #{<<"a">> => 1, <<"b">> => 1},
    ?assertEqual(InOpen, M:'Read'(InOpen)),
    ?assertEqual(#{<<"a">> => <<"s">>, <<"b">> => 2},
                 M:'Read'(#{<<"a">> => <<"s">>, <<"b">> => 2})),
    ?assertMatch({error, _}, M:'Read'(#{<<"a">> => <<"s">>, <<"b">> => <<"s">>})),
    Tagged = #{<<"a">> => x, <<"b">> => <<"s">>},
    ?assertEqual(Tagged, M:'Tagged'(Tagged)).

%% F59.11 — the refusal names the open member, not the first map beside it.
to_json_names_the_open_member_test_() ->
    {timeout, 60,
     fun() ->
         bs_test_support:with_src("open11.bs",
             "module Open11\n"
             "type Inner = { \"k\": :x } | { \"n\": int, .. }\n"
             "public string Body(Inner w)\n"
             "Body(w) -> ToJson<Inner>(w)\n",
             fun(Path, _Out) ->
                 {_, Output} = bs_test_support:run_cli_result(Path),
                 ?assertNotEqual(nomatch, string:find(Output, "`{ \"n\": int, .. }` is open")),
                 ?assertEqual(nomatch, string:find(Output, "`{ \"k\": :x }` is open"))
             end)
     end}.
