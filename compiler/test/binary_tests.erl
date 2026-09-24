%%% Scenarios: compiler/features/F13-binary-patterns.md
%%% Scenarios: compiler/features/F56-string-tail-after-literals.md
%%% F13 — binary patterns refine segment bindings.
-module(binary_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, check_only/1, errors/1]).

%% F13.1 — a sized segment binds an integer.
a_binary_pattern_binds_a_sized_segment_test() ->
    M = build_and_load("module Bin1\n"
                       "public int First(binary b)\n"
                       "First(<<a:8, rest>>) -> a\n"
                       "First(_) -> 0\n", 'Bin1'),
    ?assertEqual(7, M:'First'(<<7, 8, 9>>)),
    %% The empty binary cannot supply a sized segment, so the catch-all runs.
    ?assertEqual(0, M:'First'(<<>>)).

%% A multi-byte remainder distinguishes this from Erlang's bare byte segment.
an_unsized_final_segment_is_the_remainder_test() ->
    M = build_and_load("module Bin2\n"
                       "public binary Tail(binary b)\n"
                       "Tail(<<_:8, rest>>) -> rest\n"
                       "Tail(_) -> \"\"\n", 'Bin2'),
    ?assertEqual(<<8, 9, 10>>, M:'Tail'(<<7, 8, 9, 10>>)).

%%% F13.2–F13.4 — segment widths refine bindings.

%% F13.2 — an eight-bit binding satisfies an octet parameter without a guard.
a_segment_width_refines_its_binding_test() ->
    Src = "module Bin3\n"
          "type Octet = int where value >= 0 and value <= 255\n"
          "private atom Tag(Octet t)\n"
          "Tag(0) -> :zero\n"
          "Tag(>= 1) -> :nonzero\n"
          "public atom Read(binary b)\n"
          "Read(<<t:8, _>>) -> Tag(t)\n"
          "Read(_) -> :short\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% Without a width, the integer can contain values outside the octet range.
without_a_width_the_same_call_is_refused_test() ->
    Src = "module Bin4\n"
          "type Octet = int where value >= 0 and value <= 255\n"
          "private atom Tag(Octet t)\n"
          "Tag(0) -> :zero\n"
          "Tag(>= 1) -> :nonzero\n"
          "public atom Read(int t)\n"
          "Read(t) -> Tag(t)\n",
    ?assertMatch([{error, _, 'Read', {arg_not_accepted, 'Tag', 1, _, _}}],
                 errors(Src)).

%% F13.3 — a separate dispatch head reports the unhandled octet values.
a_tag_dispatch_head_names_its_residual_test() ->
    Src = "module Bin5\n"
          "type Octet = int where value >= 0 and value <= 255\n"
          "private atom Classify(Octet t)\n"
          "Classify(1) -> :method\n"
          "Classify(2) -> :header\n"
          "Classify(3) -> :body\n"
          "public atom Read(binary b)\n"
          "Read(<<t:8, _>>) -> Classify(t)\n"
          "Read(_) -> :short\n",
    [{error, _, 'Classify', {inexhaustive, Residual, _}}] = errors(Src),
    ?assertEqual("(0 | 4..255)", bs_types:to_pattern(Residual)).

%% F13.4 — four-bit dispatch reports the unhandled opcode ranges.
a_sub_byte_width_refines_its_binding_test() ->
    Src = "module Bin6\n"
          "type Nybble = int where value >= 0 and value <= 15\n"
          "private atom Op(Nybble op)\n"
          "Op(0) -> :cont\n"
          "Op(1) -> :text\n"
          "Op(2) -> :binary\n"
          "Op(8) -> :close\n"
          "Op(9) -> :ping\n"
          "Op(10) -> :pong\n"
          "public atom Read(binary b)\n"
          "Read(<<_:4, op:4, _>>) -> Op(op)\n"
          "Read(_) -> :short\n",
    [{error, _, 'Op', {inexhaustive, Residual, _}}] = errors(Src),
    ?assertEqual("(3..7 | 11..15)", bs_types:to_pattern(Residual)).

%% Binary length is open, so the catch-all also accepts unhandled tag values.
a_catch_all_over_a_binary_is_legal_test() ->
    Src = "module Bin7\n"
          "public atom Read(binary b)\n"
          "Read(<<1:8, _>>) -> :one\n"
          "Read(_) -> :other\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%%% F13.5–F13.6 — segments accept bound sizes and literal values.

%% F13.5 — an earlier binding sizes a binary segment.
a_segment_sized_by_an_earlier_binding_test() ->
    M = build_and_load("module Bin8\n"
                       "public binary Body(binary b)\n"
                       "Body(<<size:8, payload:size, _>>) -> payload\n"
                       "Body(_) -> \"\"\n", 'Bin8'),
    ?assertEqual(<<"abc">>, M:'Body'(<<3, "abcXY">>)),
    ?assertEqual(<<"ab">>,  M:'Body'(<<2, "abcXY">>)).

a_variable_sized_segment_is_typed_binary_test() ->
    Src = "module Bin9\n"
          "private int Len(binary b)\n"
          "Len(_) -> 0\n"
          "public int Body(binary b)\n"
          "Body(<<size:8, payload:size, _>>) -> Len(payload)\n"
          "Body(_) -> 0\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F13.6 — a literal segment matches without binding.
a_literal_segment_matches_a_value_test() ->
    M = build_and_load("module BinA\n"
                       "public atom Frame(binary b)\n"
                       "Frame(<<t:8, size:8, payload:size, 0xCE:8, _>>) -> :ok\n"
                       "Frame(_) -> :bad\n", 'BinA'),
    ?assertEqual(ok,  M:'Frame'(<<1, 3, "abc", 16#CE>>)),
    %% Changing only the sentinel must select the catch-all.
    ?assertEqual(bad, M:'Frame'(<<1, 3, "abc", 16#FF>>)).

a_sub_byte_literal_segment_matches_test() ->
    M = build_and_load("module BinB\n"
                       "public atom Which(binary b)\n"
                       "Which(<<_:1, 126:7, _>>) -> :extended\n"
                       "Which(<<_:1, 127:7, _>>) -> :huge\n"
                       "Which(_) -> :short\n", 'BinB'),
    ?assertEqual(extended, M:'Which'(<<126, 0, 0>>)),
    ?assertEqual(huge,     M:'Which'(<<127, 0, 0>>)),
    ?assertEqual(short,    M:'Which'(<<5, 0, 0>>)).

%%% F13.7 — hex literals work outside binary patterns.

a_hex_literal_is_an_integer_everywhere_test() ->
    M = build_and_load("module BinC\n"
                       "public int Hex()\n"
                       "Hex() -> 0xCE\n", 'BinC'),
    ?assertEqual(206, M:'Hex'()),
    M2 = build_and_load("module BinD\n"
                        "public atom Is(int n)\n"
                        "Is(0xFF) -> :max\n"
                        "Is(_) -> :other\n", 'BinD'),
    ?assertEqual(max,   M2:'Is'(255)),
    ?assertEqual(other, M2:'Is'(1)).

a_hex_literal_is_case_insensitive_test() ->
    M = build_and_load("module BinE\n"
                       "public int A()\n"
                       "A() -> 0Xce\n", 'BinE'),
    ?assertEqual(206, M:'A'()).

%%% F13.8–F13.10 — string literals match with an open residual.

%% F13.8 — a string literal matches in a pattern.
a_string_literal_matches_in_pattern_position_test() ->
    M = build_and_load("module BinF\n"
                       "public atom Greet(string s)\n"
                       "Greet(\"hello\") -> :hi\n"
                       "Greet(s) -> :other\n", 'BinF'),
    ?assertEqual(hi,    M:'Greet'(<<"hello">>)),
    ?assertEqual(other, M:'Greet'(<<"goodbye">>)).

%% F13.9 — a catch-all over string literals is legal.
a_catch_all_over_string_literals_is_legal_test() ->
    Src = "module BinG\n"
          "public atom Verb(string s)\n"
          "Verb(\"GET\") -> :get\n"
          "Verb(\"PUT\") -> :put\n"
          "Verb(_) -> :other\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F13.10 — string literals alone are not exhaustive.
string_literals_alone_are_not_exhaustive_test() ->
    Src = "module BinH\n"
          "public atom Verb(string s)\n"
          "Verb(\"GET\") -> :get\n"
          "Verb(\"PUT\") -> :put\n",
    ?assertMatch([{error, _, 'Verb', {inexhaustive, _, _}}], errors(Src)).

a_string_literal_may_be_a_segment_test() ->
    M = build_and_load("module BinP\n"
                       "public atom Verb(binary b)\n"
                       "Verb(<<\"GET\", rest>>) -> :get\n"
                       "Verb(<<\"POST\", rest>>) -> :post\n"
                       "Verb(_) -> :other\n", 'BinP'),
    ?assertEqual(get,   M:'Verb'(<<"GET /index">>)),
    ?assertEqual(post,  M:'Verb'(<<"POST /index">>)),
    %% A prefix match must not accept a substring.
    ?assertEqual(other, M:'Verb'(<<"XGET /index">>)),
    ?assertEqual(other, M:'Verb'(<<"HEAD /index">>)).

%%% F13.11 — nested generics and binary patterns parse together.

%% A single closing-shift token would swallow nested generic closers.
a_nested_generic_still_parses_test() ->
    Src = "module BinI\n"
          "public int Head(list<list<int>> xss)\n"
          "Head(_) -> 1\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

a_nested_generic_and_a_binary_pattern_coexist_test() ->
    Src = "module BinJ\n"
          "public int Head(list<list<int>> xss, binary b)\n"
          "Head(_, <<a:8, _>>) -> a\n"
          "Head(_, _) -> 1\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% yecc can emit a parser despite conflicts; assert the expected warning count.
the_grammar_has_exactly_its_named_conflicts_test() ->
    Yrl = filename:join(bs_test_support:project_root(), "src/bs_parser.yrl"),
    Out = filename:join(bs_test_support:run_root(), "conflict_check"),
    ok = filelib:ensure_dir(Out ++ "/x"),
    ?assertMatch({ok, _, [{_, [{_, yecc, {conflicts, 5, 0}}]}]},
                 yecc:file(Yrl, [{parserfile, Out ++ ".erl"}, {return, true}])).

%%% F13.12–F13.13 — malformed segments receive specific diagnostics.

%% F13.12 — an unsized segment must be last.
an_unsized_segment_must_come_last_test() ->
    Src = "module BinK\n"
          "public int First(binary b)\n"
          "First(<<rest, a:8>>) -> a\n"
          "First(_) -> 0\n",
    ?assertMatch([{error, _, _, {unsized_segment_not_last, _, _}}], errors(Src)).

%% F13.13 — a literal too wide for its segment names both numbers.
a_literal_wider_than_its_segment_is_refused_test() ->
    Src = "module BinL\n"
          "public atom Which(binary b)\n"
          "Which(<<300:8, _>>) -> :yes\n"
          "Which(_) -> :no\n",
    ?assertMatch([{error, _, _, {segment_literal_too_wide, 300, 8, _}}],
                 errors(Src)).

a_non_positive_width_is_refused_test() ->
    Src = "module BinM\n"
          "public int First(binary b)\n"
          "First(<<a:0, _>>) -> a\n"
          "First(_) -> 0\n",
    ?assertMatch([{error, _, _, {segment_width_not_positive, 0, _}}],
                 errors(Src)).

%% BEAM segment sizes must be bound earlier in the same pattern.
a_size_must_name_an_earlier_binding_test() ->
    Src = "module BinN\n"
          "public binary Body(binary b)\n"
          "Body(<<payload:size, size:8>>) -> payload\n"
          "Body(_) -> \"\"\n",
    ?assertMatch([{error, _, _, {segment_size_not_bound, size, _}}],
                 errors(Src)).

%%% ---------------------------------------------------------------------------
%%% F56 — a string pattern's tail after string-literal segments is a `string`
%%%
%%% A literal is whole UTF-8 characters, and UTF-8 resynchronises at every
%%% character boundary, so what follows literal segments in a valid string is
%%% itself valid, and `<<"typesafe:", id>>` binds `id` as a `string`. Every
%%% other segment kind before the tail can split a character, so those keep
%%% `binary`.
%%% ---------------------------------------------------------------------------

f56_record(Pattern, Param) ->
    "module Spec\n"
    "record Model { Id: string }\n"
    "public option<Model> Parse(" ++ Param ++ " spec)\n"
    "Parse(" ++ Pattern ++ ") -> Model { Id = id }\n"
    "Parse(_) -> :nothing\n".

%% F56.1 — a literal prefix: compiles, and the tail reaches a `string` field.
a_tail_after_a_string_literal_is_a_string_test() ->
    M = build_and_load(f56_record("<<\"typesafe:\", id>>", "string"), 'Spec'),
    ?assertEqual(#{'Kind' => 'Spec.Model', 'Id' => <<"jev-latest">>},
                 M:'Parse'(<<"typesafe:jev-latest">>)),
    ?assertEqual(nothing, M:'Parse'(<<"anthropic:x">>)).

%% F56.2 — several literal segments, one of them non-ASCII: still whole characters.
a_tail_after_several_literals_is_a_string_test() ->
    M = build_and_load(f56_record("<<\"h\xc3\xa9\", \":\", id>>", "string"), 'Spec'),
    ?assertEqual(#{'Kind' => 'Spec.Model', 'Id' => <<"x", 16#c3, 16#a9>>},
                 M:'Parse'(<<"h", 16#c3, 16#a9, ":x", 16#c3, 16#a9>>)).

%% F56.3 — the subject decides: over a `binary` the tail is still a `binary`.
a_tail_of_a_binary_subject_stays_binary_test() ->
    ?assertMatch([{error, _, 'Parse', {field_value_not_accepted, 'Model', 'Id', _}}],
                 errors(f56_record("<<\"typesafe:\", id>>", "binary"))).

%% F56.4 — an integer segment before the tail can split a character.
a_tail_after_an_integer_segment_stays_binary_test() ->
    ?assertMatch([{error, _, 'Parse', {field_value_not_accepted, 'Model', 'Id', _}}],
                 errors(f56_record("<<c:8, id>>", "string"))).

%% F56.5 — so can a wildcard segment.
a_tail_after_a_wildcard_segment_stays_binary_test() ->
    ?assertMatch([{error, _, 'Parse', {field_value_not_accepted, 'Model', 'Id', _}}],
                 errors(f56_record("<<_:8, id>>", "string"))).

%% F56.6 — a literal AFTER an integer segment does not restore the boundary.
a_literal_after_an_integer_segment_does_not_help_test() ->
    ?assertMatch([{error, _, 'Parse', {field_value_not_accepted, 'Model', 'Id', _}}],
                 errors(f56_record("<<c:8, \":\", id>>", "string"))).

%% F56.7 — the same rule at a switch arm, which is classified at another site.
a_switch_arm_tail_after_a_literal_is_a_string_test() ->
    M = build_and_load("module SpecArm\n"
                       "public string Id(string spec)\n"
                       "Id(spec) -> spec switch {\n"
                       "    <<\"typesafe:\", id>> => id,\n"
                       "    other                => other\n"
                       "}\n", 'SpecArm'),
    ?assertEqual(<<"jev">>, M:'Id'(<<"typesafe:jev">>)).

%% F56.8 — nested: the tail's subject is a tuple component typed `string`.
a_nested_tail_reads_its_component_type_test() ->
    M = build_and_load("module SpecPair\n"
                       "public string Id((int, string) p)\n"
                       "Id((n, <<\"a:\", id>>)) -> id\n"
                       "Id((n, s))              -> s\n", 'SpecPair'),
    ?assertEqual(<<"b">>, M:'Id'({1, <<"a:b">>})),
    ?assertMatch([{error, _, 'Id', {return_not_declared, _, _}}],
                 errors("module SpecPairB\n"
                        "public string Id((int, binary) p)\n"
                        "Id((n, <<\"a:\", id>>)) -> id\n"
                        "Id((n, s))              -> \"\"\n")).
