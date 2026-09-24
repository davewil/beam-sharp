%%% Scenarios: compiler/features/F58-string-keys.md
%%% F58 — a field-set key may be a string literal: `{ "input_tokens": int }`.
%%%
%%% A field's wire name lives in a structural type whose keys are the wire's
%%% strings, so `json:decode`'s output validates as it stands. A string key is
%%% a binary in the term and in the type; an atom key stays an atom, and the
%%% two never meet. Records keep PascalCase fields: a string key belongs to a
%%% field set, never to a record. The expression form `{ "model" = m.Id }` is
%%% tested here too, since the expression takes whatever keys the type does.

-module(string_key_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, errors/1, check_only/1]).

tags(Src) -> [element(1, element(4, E)) || E <- errors(Src)].

usage_src() ->
    "module Wire1\n"
    "type UsageWire = { \"input_tokens\": int, \"output_tokens\": int }\n"
    "record Usage { InputTokens: int, OutputTokens: int }\n"
    "public Usage Tokens(UsageWire u)\n"
    "Tokens({ \"input_tokens\": i, \"output_tokens\": o }) -> Usage { InputTokens = i, OutputTokens = o }\n"
    "public result<UsageWire, ValidationError> Read(term t)\n"
    "Read(t) -> ValidateAs<UsageWire>(t)\n"
    "public string Write(UsageWire u)\n"
    "Write(u) -> ToJson<UsageWire>(u)\n"
    "public UsageWire Make(int i, int o)\n"
    "Make(i, o) -> { \"input_tokens\" = i, \"output_tokens\" = o }\n".

%% F58.1 — a clause head reads the wire keys.
a_clause_head_reads_string_keys_test() ->
    M = build_and_load(usage_src(), 'Wire1'),
    ?assertEqual(#{'Kind' => 'Wire1.Usage', 'InputTokens' => 100, 'OutputTokens' => 20},
                 M:'Tokens'(#{<<"input_tokens">> => 100, <<"output_tokens">> => 20})).

%% F58.2 — `json:decode`'s output validates as it stands, and comes back unchanged.
validate_as_accepts_decoded_json_test() ->
    M = build_and_load(usage_src(), 'Wire1'),
    Doc = json:decode(<<"{\"input_tokens\":100,\"output_tokens\":20}">>),
    ?assertEqual(Doc, M:'Read'(Doc)).

%% F58.3 — a wrong value is refused with the key in the path, spelled as a map
%% entry is (F43): `["input_tokens"]`.
validate_as_names_the_string_key_test() ->
    M = build_and_load(usage_src(), 'Wire1'),
    ?assertEqual(bs_test_support:validation_error([<<"[\"input_tokens\"]">>], <<"int">>),
                 M:'Read'(#{<<"input_tokens">> => <<"many">>, <<"output_tokens">> => 20})).

%% F58.4 — `ToJson` writes the keys as they are, with no `Kind`.
to_json_writes_the_wire_keys_test() ->
    M = build_and_load(usage_src(), 'Wire1'),
    ?assertEqual(#{<<"input_tokens">> => 1, <<"output_tokens">> => 2},
                 json:decode(M:'Write'(#{<<"input_tokens">> => 1, <<"output_tokens">> => 2}))).

%% F58.5 — the brace expression builds one.
the_brace_expression_takes_string_keys_test() ->
    M = build_and_load(usage_src(), 'Wire1'),
    ?assertEqual(#{<<"input_tokens">> => 3, <<"output_tokens">> => 4}, M:'Make'(3, 4)).

%% F58.6 — and its value and key set are checked like any field set's.
the_brace_expression_is_checked_test() ->
    Src = fun(Body) ->
              "module Wire6\n"
              "public { \"model\": string } Make(string m)\n"
              "Make(m) -> " ++ Body ++ "\n"
          end,
    ?assertMatch({ok, _, _}, check_only(Src("{ \"model\" = m }"))),
    ?assertEqual([return_not_declared], tags(Src("{ \"model\" = 7 }"))),
    ?assertEqual([return_not_declared], tags(Src("{ \"modle\" = m }"))),
    ?assertEqual([duplicate_field], tags(Src("{ \"model\" = m, \"model\" = m }"))).

%% F58.7 — a string key and an atom key are different keys.
a_string_key_is_not_an_atom_key_test() ->
    ?assertEqual([arg_not_accepted],
                 tags("module Wire7\n"
                      "public int Code({ Status: int } r)\n"
                      "Code({ Status: s }) -> s\n"
                      "public int Go(int n)\n"
                      "Go(n) -> Code({ \"Status\" = n })\n")).

%% F58.8 — exhaustiveness reads a string key, and the residual prints it quoted.
%% The field's value prints `_`, exactly as it does for a name key: the head
%% printer keeps the key set and not the narrowed value.
the_residual_prints_a_string_key_test() ->
    [{error, _, 'Go', {inexhaustive, Residual, _}}] =
        errors("module Wire8\n"
               "public int Go({ \"ok\": bool } w)\n"
               "Go({ \"ok\": true }) -> 1\n"),
    ?assertEqual("({ \"ok\": _ })", bs_types:to_pattern(Residual)).

%% F58.8b — `--api` prints a string key quoted, which is how it is written.
the_api_prints_a_string_key_test_() ->
    {timeout, 60,
     fun() ->
         bs_test_support:with_src("wire.bs",
             "module Wire8b\n"
             "public int Go({ \"ok\": bool } w)\n"
             "Go({ \"ok\": b }) -> 1\n",
             fun(Path, _Out) ->
                 {0, Output} = bs_test_support:run_cli_result("--api " ++ Path),
                 ?assertNotEqual(nomatch, string:find(Output, "{ \"ok\": :false | :true }"))
             end)
     end}.

%% F58.9 — a record's fields stay PascalCase names; a string key is refused
%% there, at the parse, naming where it belongs.
a_record_refuses_a_string_field_test() ->
    {ok, Toks, _} = bs_lexer:string("module Wire9\nrecord R { \"x\": int }\n"),
    {error, {_, bs_parser, Msg}} = bs_parser:parse(Toks),
    ?assertNotEqual(nomatch, string:find(lists:flatten(Msg), "belongs in a field set")).

%% F58.10 — so is a string key in a record construction.
a_record_construction_refuses_a_string_key_test() ->
    ?assertEqual([field_set_mismatch],
                 tags("module Wire10\n"
                      "record R { X: int }\n"
                      "public R Go(int n)\n"
                      "Go(n) -> R { \"X\" = n }\n")).

%% F58.11 — a key with characters no identifier has, which is the point.
any_string_is_a_key_test() ->
    M = build_and_load("module Wire11\n"
                       "public int Go({ \"content-type\": int, \"\": int } w)\n"
                       "Go({ \"content-type\": c, \"\": e }) -> c + e\n", 'Wire11'),
    ?assertEqual(3, M:'Go'(#{<<"content-type">> => 1, <<>> => 2})).

%% F58.12 — a string-keyed field set is a dictionary where its keys and values
%% fit, as a name-keyed one is.
a_string_keyed_field_set_fits_a_dictionary_test() ->
    M = build_and_load("module Wire12\n"
                       "public map<term, term> State(string t)\n"
                       "State(t) -> { \"title\" = t }\n"
                       "public map<string, int> Counts(int n)\n"
                       "Counts(n) -> { \"a\" = n, \"b\" = 2 }\n", 'Wire12'),
    ?assertEqual(#{<<"title">> => <<"x">>}, M:'State'(<<"x">>)),
    ?assertEqual(#{<<"a">> => 1, <<"b">> => 2}, M:'Counts'(1)),
    %% A string key is not an atom key, so it does not fit `map<atom, int>`.
    ?assertEqual([return_not_declared],
                 tags("module Wire12b\n"
                      "public map<atom, int> Counts(int n)\n"
                      "Counts(n) -> { \"a\" = n }\n")).
