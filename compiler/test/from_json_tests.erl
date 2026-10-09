%%% F69 — FromJson reads JSON text into a wire type and refuses a record.
%%% Refusals use the CLI's published descriptors, not internal checker terms.
%%% Scenarios: compiler/features/F69-from-json.md
-module(from_json_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, with_src/3, validation_error/2]).

reply_src() ->
    "module FjReply\n"
    "type ReplyWire = { \"id\": option<string>, \"model\": string,\n"
    "                   \"refusal\": string | :null, .. }\n"
    "public result<ReplyWire, ValidationError> Parse(string body)\n"
    "Parse(body) -> FromJson<ReplyWire>(body)\n".

%%% F69.1 — text that is JSON and inhabits `T` comes back as the value

json_text_becomes_the_wire_value_test() ->
    M = build_and_load(reply_src(), 'FjReply'),
    ?assertEqual(#{<<"id">> => <<"gen-1">>, <<"model">> => <<"jev">>,
                   <<"refusal">> => null},
                 M:'Parse'(<<"{\"id\":\"gen-1\",\"model\":\"jev\",\"refusal\":null}">>)).

%%% F69.2 — text that is not JSON is a ValidationError at the top, expecting JSON

text_that_is_not_json_is_an_error_value_test() ->
    M = build_and_load(reply_src(), 'FjReply'),
    NotJson = validation_error([], <<"JSON">>),
    ?assertEqual(NotJson, M:'Parse'(<<"{\"model\":">>)),
    ?assertEqual(NotJson, M:'Parse'(<<>>)),
    ?assertEqual(NotJson, M:'Parse'(<<"{\"model\":\"jev\"} trailing">>)).

%%% F69.3 — JSON outside `T` is refused where `ValidateAs<T>` refuses it

json_outside_the_type_is_refused_at_its_key_test() ->
    M = build_and_load(reply_src(), 'FjReply'),
    ?assertEqual(validation_error([<<"[\"model\"]">>], <<"string">>),
                 M:'Parse'(<<"{\"model\":7,\"refusal\":null}">>)),
    ?assertMatch({error, #{'Path' := []}}, M:'Parse'(<<"[1,2]">>)).

%%% F69.4 — the one conversion is ValidateAs's: an absent option key is
%%% `:nothing`, `null` stays `:null`, and an open type keeps the wire's extras

an_absent_option_key_is_nothing_and_extras_are_kept_test() ->
    M = build_and_load(reply_src(), 'FjReply'),
    ?assertEqual(#{<<"id">> => nothing, <<"model">> => <<"jev">>,
                   <<"refusal">> => null, <<"cost">> => 0.5},
                 M:'Parse'(<<"{\"model\":\"jev\",\"refusal\":null,\"cost\":0.5}">>)),
    ?assertEqual(validation_error([<<"[\"id\"]">>], <<":nothing | string">>),
                 M:'Parse'(<<"{\"id\":null,\"model\":\"jev\",\"refusal\":null}">>)).

%%% F69.5 — one string-keyed `T` under all three obligations, and `FromJson`
%%% in a pipe

round_src() ->
    "module FjRound\n"
    "type Usage = { \"input_tokens\": int, \"output_tokens\": int }\n"
    "public result<Usage, ValidationError> Read(string body)\n"
    "Read(body) -> body |> FromJson<Usage>()\n"
    "public result<Usage, ValidationError> Check(term t)\n"
    "Check(t) -> ValidateAs<Usage>(t)\n"
    "public string Write(Usage u)\n"
    "Write(u) -> ToJson<Usage>(u)\n"
    "public result<list<int>, ValidationError> Ints(string body)\n"
    "Ints(body) -> FromJson<list<int>>(body)\n".

a_string_keyed_type_written_by_to_json_is_read_back_test() ->
    M = build_and_load(round_src(), 'FjRound'),
    U = #{<<"input_tokens">> => 3, <<"output_tokens">> => 9},
    ?assertEqual(U, M:'Read'(M:'Write'(U))),
    ?assertEqual(U, M:'Check'(U)),
    ?assertEqual([1, 2, 3], M:'Ints'(<<"[1,2,3]">>)),
    %% An exact type refuses a key it does not name, as ValidateAs does.
    ?assertMatch({error, #{'Path' := []}},
                 M:'Read'(<<"{\"input_tokens\":3,\"output_tokens\":9,\"cost\":1}">>)).

%%% The refusals, read off the published term

published(Src) ->
    with_src("in.bs", Src, fun(Path, Root) ->
        {Rc, Out, _} = bs_test_support:run_cli_split_result(
                         "--diagnostics term --src-root " ++ Root ++ " " ++ Path),
        {Rc, [parse_term(L) || L <- string:split(string:trim(Out), "\n", all), L =/= ""]}
    end).

parse_term(S) ->
    {ok, Tokens, _} = erl_scan:string(S ++ "."),
    {ok, Term} = erl_parse:parse_term(Tokens),
    Term.

the_refusal(Src) ->
    {Rc, Descs} = published(Src),
    ?assertEqual(1, Rc),
    [D] = [D || D = #{tag := undecodable_member} <- Descs],
    D.

over(Decls, Type) ->
    "module FjOver\n" ++ Decls ++
    "public result<" ++ Type ++ ", ValidationError> Read(string body)\n"
    "Read(body) -> FromJson<" ++ Type ++ ">(body)\n".

%%% F69.6 — a type holding a record is refused, wherever the record sits

a_record_is_refused_test() ->
    ?assertMatch(#{kind := record, obligation := 'FromJson', path := [],
                   member := "Order", function := 'Read'},
                 the_refusal(over("record Order { Id: int }\n", "Order"))).

a_record_inside_a_wire_type_is_refused_at_its_path_test() ->
    Decls = "record Usage { In: int }\n"
            "type Reply = { \"model\": string, \"usage\": list<Usage>, .. }\n",
    ?assertMatch(#{kind := record, path := ["[\"usage\"]", "[_]"], member := "Usage"},
                 the_refusal(over(Decls, "Reply"))).

%% `{ Kind: :invoice }` is a field set whose key happens to be `Kind`: no
%% record was declared, so nothing is deferred. It compiles, and JSON's string
%% keys fail it at run time as they fail any name key.
a_hand_tagged_field_set_is_not_a_record_test() ->
    Src = over("type Doc = { Kind: :invoice, Total: int }\n", "Doc"),
    M = build_and_load(Src, 'FjOver'),
    ?assertMatch({error, #{'Path' := []}},
                 M:'Read'(<<"{\"Kind\":\"invoice\",\"Total\":4}">>)).

%%% F69.7 — what no JSON decodes to is refused, as ToJson refuses to write it

a_tuple_is_refused_test() ->
    ?assertMatch(#{kind := tuple, path := ["[\"at\"]"], member := "(int, int)"},
                 the_refusal(over("type P = { \"at\": (int, int) }\n", "P"))).

binary_and_term_are_refused_test() ->
    ?assertMatch(#{kind := binary, path := []}, the_refusal(over("", "binary"))),
    ?assertMatch(#{kind := term, path := ["[_]"]},
                 the_refusal(over("", "map<string, term>"))).

%% A function and a process have no value in any text, so neither is read.
an_arrow_and_a_pid_are_refused_test() ->
    ?assertMatch(#{kind := arrow, path := ["[\"f\"]"]},
                 the_refusal(over("type W = { \"f\": fn(int) -> int }\n", "W"))),
    ?assertMatch(#{kind := opaque, path := ["[_]"]}, the_refusal(over("", "list<pid>"))).

%% Each kind's prose says what was found, where, and what to read instead.
the_prose_names_the_member_and_what_to_read_instead_test() ->
    Prose = fun(Decls, Type) ->
        with_src("in.bs", over(Decls, Type), fun(Path, Root) ->
            {1, _, Err} = bs_test_support:run_cli_split_result(
                            "--src-root " ++ Root ++ " " ++ Path),
            Err
        end)
    end,
    Says = fun(Err, Text) -> ?assertNotEqual({Text, nomatch}, {Text, string:find(Err, Text)}) end,
    Tuple = Prose("type P = { \"at\": (int, int) }\n", "P"),
    Says(Tuple, "error: Read calls FromJson over a type with no wire form"),
    Says(Tuple, "in [\"at\"], `(int, int)` is a tuple"),
    Says(Tuple, "Declare a field set or a list where the"),
    Says(Prose("type W = { \"f\": fn(int) -> int }\n", "W"),
         "Leave the function out of the type you read."),
    Says(Prose("", "list<pid>"), "Leave it out of the type you read"),
    Says(Prose("", "binary"), "Declare it `string`: a JSON string is always UTF-8."),
    Says(Prose("", "map<string, term>"), "Name the shape the JSON has").

%% ToJson refuses an open type because it would publish undeclared keys.
%% Reading one publishes nothing, and it is the shape a reply has.
an_open_type_is_read_and_still_not_written_test() ->
    Decls = "type W = { \"model\": string, .. }\n",
    M = build_and_load(over(Decls, "W"), 'FjOver'),
    ?assertEqual(#{<<"model">> => <<"m">>, <<"x">> => 1},
                 M:'Read'(<<"{\"model\":\"m\",\"x\":1}">>)),
    {1, Descs} = published(over(Decls, "W") ++
                           "public string Write(W w)\nWrite(w) -> ToJson<W>(w)\n"),
    ?assertMatch([#{tag := unencodable_member, kind := open_map}],
                 [D || D = #{severity := error} <- Descs]).

%%% F69.8 — the call is checked as ValidateAs's and ToJson's are

a_type_variable_is_refused_test() ->
    Src = "module FjPoly\n"
          "public result<T, ValidationError> Read<T>(string body, T like)\n"
          "Read(body, like) -> FromJson<T>(body)\n",
    {1, Descs} = published(Src),
    ?assertMatch([#{tag := obligation_over_type_variable, obligation := 'FromJson'}],
                 [D || D = #{severity := error} <- Descs]).

the_text_must_be_a_string_test() ->
    Src = "module FjArg\n"
          "public result<int, ValidationError> Read(binary body)\n"
          "Read(body) -> FromJson<int>(body)\n",
    {1, Descs} = published(Src),
    ?assertMatch([#{tag := arg_not_accepted}], [D || D = #{severity := error} <- Descs]).

one_type_and_one_argument_test() ->
    Src = "module FjArity\n"
          "public result<int, ValidationError> Read(string body)\n"
          "Read(body) -> FromJson<int, int>(body)\n",
    {1, Descs} = published(Src),
    ?assertMatch([#{tag := obligation_arity, obligation := 'FromJson'}],
                 [D || D = #{severity := error} <- Descs]).

%% A target ValidateAs cannot tell apart is refused here by the same rule.
an_indiscriminable_target_is_refused_test() ->
    Decls = "type A = { \"a\": int, .. }\ntype B = { \"b\": int, .. }\n",
    {1, Descs} = published(over(Decls, "A | B")),
    ?assertMatch([#{tag := validate_indiscriminable}],
                 [D || D = #{severity := error} <- Descs]).

%%% F69.9 — the result is `result<T, ValidationError>`, so the caller's
%%% signature must carry the failure

the_failure_is_in_the_result_type_test() ->
    Src = "module FjRet\n"
          "public int Read(string body)\n"
          "Read(body) -> FromJson<int>(body)\n",
    {1, Descs} = published(Src),
    ?assertMatch([#{tag := return_not_declared}], [D || D = #{severity := error} <- Descs]).

%%% F69.10 — the prose names the record, its path and the deferral

record_prose_src() ->
    over("record Usage { In: int }\n"
         "type Reply = { \"model\": string, \"usage\": Usage }\n", "Reply").

the_prose_names_the_record_and_the_deferral_test() ->
    with_src("in.bs", record_prose_src(), fun(Path, Root) ->
        {1, _, Err} = bs_test_support:run_cli_split_result(
                        "--src-root " ++ Root ++ " " ++ Path),
        ?assertNotEqual(nomatch, string:find(Err, "error: Read calls FromJson over a type that holds a record")),
        ?assertNotEqual(nomatch, string:find(Err, "in [\"usage\"], `Usage` is a record")),
        ?assertNotEqual(nomatch, string:find(Err, "ticket 78 Q4"))
    end).

%%% F69.11 — `bsc --api` types no body, and still reports the refusal

the_api_query_reports_the_refusal_test() ->
    with_src("in.bs", record_prose_src(), fun(Path, Root) ->
        {Rc, _, Err} = bs_test_support:run_cli_split_result(
                         "--src-root " ++ Root ++ " --api " ++ Path),
        ?assertEqual(1, Rc),
        ?assertNotEqual(nomatch, string:find(Err, "calls FromJson over a type that holds a record"))
    end).
