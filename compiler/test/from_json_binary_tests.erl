%%% F74 — FromJson<T> takes a binary.
%%% Scenarios: compiler/features/F74-from-json-binary.md
-module(from_json_binary_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, validation_error/2, validation_error/3]).

src() ->
    "module FbBody\n"
    "type W = { \"a\": int }\n"
    "type Named = { \"name\": string }\n"
    "public result<W, ValidationError> ReadBytes(binary body)\n"
    "ReadBytes(body) -> FromJson<W>(body)\n"
    "public result<W, ValidationError> ReadText(string body)\n"
    "ReadText(body) -> FromJson<W>(body)\n"
    "public result<W, ValidationError> Piped(binary body)\n"
    "Piped(body) -> body |> FromJson<W>()\n"
    "public result<int, ValidationError> Valved(result<binary, ValidationError> body)\n"
    "Valved(body) -> body |?> FromJson<W>() |?> Held()\n"
    "private int Held(W w)\n"
    "Held({ \"a\": a }) -> a\n"
    "public result<W, ValidationError> TwoStages(binary body)\n"
    "TwoStages(body) -> ValidateAs<string>(body) |?> FromJson<W>()\n"
    "public result<Named, ValidationError> ReadNamed(binary body)\n"
    "ReadNamed(body) -> FromJson<Named>(body)\n"
    "public string Shout(binary body)\n"
    "Shout(body) -> FromJson<Named>(body) switch {\n"
    "    (:error, e)       => \"\",\n"
    "    { \"name\": name } => $\"{name}!\"\n"
    "}\n".

loaded() -> build_and_load(src(), 'FbBody').

not_json() -> validation_error([], <<"JSON">>, not_json).

published(Src) ->
    bs_test_support:with_src("in.bs", Src, fun(Path, Root) ->
        {Rc, Out, _} = bs_test_support:run_cli_split_result(
                         "--diagnostics term --src-root " ++ Root ++ " " ++ Path),
        {Rc, [parse_term(L) || L <- string:split(string:trim(Out), "\n", all), L =/= ""]}
    end).

parse_term(S) ->
    {ok, Tokens, _} = erl_scan:string(S ++ "."),
    {ok, T} = erl_parse:parse_term(Tokens),
    T.

refused(Src) ->
    {Rc, Descs} = published(Src),
    {Rc, [D || D = #{severity := error} <- Descs]}.

%%% F74.1 — a binary argument and a string one

a_binary_and_a_string_are_both_read_test() ->
    M = loaded(),
    ?assertEqual(#{<<"a">> => 1}, M:'ReadBytes'(<<"{\"a\":1}">>)),
    ?assertEqual(#{<<"a">> => 1}, M:'ReadText'(<<"{\"a\":1}">>)).

%% What a binary is refused for is what a string is refused for.
a_binary_is_refused_as_a_string_is_test() ->
    M = loaded(),
    [?assertEqual(M:'ReadText'(Text), M:'ReadBytes'(Text))
     || Text <- [<<"{\"a\":\"x\"}">>, <<"{}">>, <<"{\"a\":1,\"a\":2}">>, <<"{\"a\":1} x">>,
                 <<"nope">>, <<>>]],
    ?assertEqual(validation_error([<<"[\"a\"]">>], <<"int">>),
                 M:'ReadBytes'(<<"{\"a\":\"x\"}">>)),
    ?assertEqual(validation_error([<<"[\"a\"]">>], <<"int">>, missing), M:'ReadBytes'(<<"{}">>)),
    ?assertEqual(validation_error([], <<"\"a\" once">>, duplicate_key),
                 M:'ReadBytes'(<<"{\"a\":1,\"a\":2}">>)).

%%% F74.2 — bytes that are not UTF-8 are text that is not JSON

bytes_that_are_not_utf8_are_not_json_test() ->
    M = loaded(),
    ?assertEqual(not_json(), M:'ReadBytes'(<<255>>)),
    ?assertEqual(not_json(), M:'ReadBytes'(<<"{\"a\":1}", 255>>)),
    ?assertEqual(not_json(), M:'ReadBytes'(<<255, "{\"a\":1}">>)),
    %% A key cut off inside a two-byte character.
    ?assertEqual(not_json(), M:'ReadBytes'(<<"{\"", 16#C3, "\":1}">>)).

%% Inside a JSON string, where the object around it is well formed.
a_bad_byte_inside_a_json_string_is_not_json_test() ->
    M = loaded(),
    ?assertEqual(not_json(), M:'ReadNamed'(<<"{\"name\":\"", 255, "\"}">>)),
    ?assertEqual(not_json(), M:'ReadNamed'(<<"{\"name\":\"", 16#E2, 16#82, "\"}">>)),
    ?assertEqual(#{<<"name">> => <<"é"/utf8>>},
                 M:'ReadNamed'(<<"{\"name\":\"", 16#C3, 16#A9, "\"}">>)).

%% OTP's decoder does not skip a byte-order mark, from a binary or a string.
a_byte_order_mark_is_not_json_test() ->
    M = loaded(),
    Marked = <<239, 187, 191, "{\"a\":1}">>,
    ?assertEqual(not_json(), M:'ReadBytes'(Marked)),
    ?assertEqual(not_json(), M:'ReadText'(Marked)).

%%% F74.3 — what is read from a binary is typed as from a string

a_string_read_from_bytes_is_a_string_to_the_program_test() ->
    M = loaded(),
    ?assertEqual(<<"ada!">>, M:'Shout'(<<"{\"name\":\"ada\"}">>)),
    ?assertEqual(<<>>, M:'Shout'(<<"{\"name\":\"", 255, "\"}">>)).

%%% F74.4 — through a pipe and through the valve

a_binary_is_piped_in_test() ->
    M = loaded(),
    ?assertEqual(#{<<"a">> => 1}, M:'Piped'(<<"{\"a\":1}">>)),
    ?assertEqual(not_json(), M:'Piped'(<<255>>)).

a_binary_goes_through_the_valve_test() ->
    M = loaded(),
    ?assertEqual(7, M:'Valved'(<<"{\"a\":7}">>)),
    ?assertEqual(not_json(), M:'Valved'(<<255>>)),
    Earlier = validation_error([], <<"binary">>),
    ?assertEqual(Earlier, M:'Valved'(Earlier)).

%% The stage a program wrote before F74 still compiles, and still answers first.
the_string_stage_written_before_still_answers_first_test() ->
    M = loaded(),
    ?assertEqual(#{<<"a">> => 1}, M:'TwoStages'(<<"{\"a\":1}">>)),
    ?assertEqual(validation_error([], <<"string">>), M:'TwoStages'(<<255>>)).

%%% F74.5 — an argument that is not a binary is still refused

an_int_is_refused_test() ->
    Src = "module FbInt\n"
          "public result<int, ValidationError> Read(int body)\n"
          "Read(body) -> FromJson<int>(body)\n",
    ?assertMatch({1, [#{tag := arg_not_accepted}]}, refused(Src)).

a_term_is_refused_test() ->
    Src = "module FbTerm\n"
          "public result<int, ValidationError> Read(term body)\n"
          "Read(body) -> FromJson<int>(body)\n",
    ?assertMatch({1, [#{tag := arg_not_accepted}]}, refused(Src)).

a_binary_or_nothing_is_refused_test() ->
    Src = "module FbMaybe\n"
          "public result<int, ValidationError> Read(option<binary> body)\n"
          "Read(body) -> FromJson<int>(body)\n",
    ?assertMatch({1, [#{tag := arg_not_accepted}]}, refused(Src)).

%% What the refusal says the argument must be.
the_refusal_names_what_was_left_over_test() ->
    Src = "module FbSays\n"
          "public result<int, ValidationError> Read(binary | int body)\n"
          "Read(body) -> FromJson<int>(body)\n",
    {1, Out} = bs_test_support:with_src("in.bs", Src, fun(Path, Root) ->
        {Rc, _, Err} = bs_test_support:run_cli_split_result("--src-root " ++ Root ++ " " ++ Path),
        {Rc, Err}
    end),
    ?assertNotEqual(nomatch, string:find(Out, "argument 1 is not covered by FromJson's declared type:\n    int\n")).

%%% F74.6 — the target is still checked as it was

a_binary_target_is_still_refused_test() ->
    Src = "module FbTarget\n"
          "public result<binary, ValidationError> Read(binary body)\n"
          "Read(body) -> FromJson<binary>(body)\n",
    ?assertMatch({1, [#{tag := undecodable_member, kind := binary}]}, refused(Src)).
