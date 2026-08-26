%%% F13 — binary patterns, and the one inference behind them.
%%%
%%% Ticket 30's answer is that a binary gets NO structure in the type language.
%%% A segment's WIDTH refines the value it binds — `t:8` is `range(0, 255)` —
%%% and everything downstream of that is machinery F2 and F9 already shipped.
%%% So most of this file asserts the inference and the parse; the exhaustiveness
%%% assertions are here to prove the two halves meet, not to re-test intervals.
%%%
%%% THE RULE THIS FILE EXISTS TO PIN: the binary pattern does SHAPE and a
%%% function head does VALUE. A `_` over a binary is always legal, because a
%%% binary can always be truncated — so it also absorbs any wire value left
%%% unhandled, silently. That is ticket 30's one sharp edge, and
%%% `a_catch_all_over_a_binary_is_legal_test` is the assertion that it is a
%%% design and not a bug.

-module(binary_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, check_only/1, errors/1]).

%%% ---------------------------------------------------------------------------
%%% F13.1 — the pattern parses, runs, and binds
%%% ---------------------------------------------------------------------------

%% F13.1
a_binary_pattern_binds_a_sized_segment_test() ->
    M = build_and_load("module Bin1\n"
                       "public int First(binary b)\n"
                       "First(<<a:8, rest>>) -> a\n"
                       "First(_) -> 0\n", 'Bin1'),
    ?assertEqual(7, M:'First'(<<7, 8, 9>>)),
    %% The empty binary matches no sized segment, so the catch-all is what runs.
    %% This is the truncation case that makes `_` mandatory.
    ?assertEqual(0, M:'First'(<<>>)).

%% An unsized final segment is the REMAINDER, which is F13's §2 mechanism
%% decision and a deliberate divergence from Erlang, where a bare `<<A, B>>` is
%% two BYTES and the remainder needs `Rest/binary`. Asserted on a remainder
%% longer than one byte, because a one-byte remainder cannot tell the two
%% readings apart.
an_unsized_final_segment_is_the_remainder_test() ->
    M = build_and_load("module Bin2\n"
                       "public binary Tail(binary b)\n"
                       "Tail(<<_:8, rest>>) -> rest\n"
                       "Tail(_) -> \"\"\n", 'Bin2'),
    ?assertEqual(<<8, 9, 10>>, M:'Tail'(<<7, 8, 9, 10>>)).

%%% ---------------------------------------------------------------------------
%%% F13.2–F13.4 — the inference, and what it unlocks
%%% ---------------------------------------------------------------------------

%% F13.2 — THE NOVEL STEP, AND THE WHOLE FEATURE.
%%
%% `t:8` binds an integer known to be 0..255, so it goes into a parameter
%% declared `Octet` with NO guard and NO declaration at the binding site.
%% Measured before this feature was written: without the width, a bare `int`
%% into an `Octet` parameter is REFUSED with `int <= -1 | int >= 256` — 25c's
%% probe 2, which recorded it as "values the wire cannot produce" and concluded
%% the gap was the signature's, not the checker's. The width is what closes it.
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

%% THE CONTROL, and without it the test above proves only that something
%% compiled. The same program with the width removed must FAIL, and fail with
%% the residual naming the values a byte cannot hold.
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

%% F13.3 — the residual ticket 30's answer printed in full, run.
%% Dispatch is in a SECOND HEAD, which is where the answer puts it.
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
    [{error, _, 'Classify', {inexhaustive, Residual}}] = errors(Src),
    ?assertEqual("(0 | 4..255)", bs_types:to_pattern(Residual)).

%% F13.4 — THE SUB-BYTE PROOF, and the reason ticket 30 carries a warning.
%%
%% No language surveyed does this: Erlang has no exhaustiveness checking at all,
%% Elixir's set-theoretic machinery does not reach binaries, Gleam refuses
%% coverage over bit arrays even for a 1-bit tag with both values named, and C#
%% has no sub-byte concept. RFC 6455's opcode field is four bits, and its
%% reserved ranges are exactly what the residual must name.
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
    [{error, _, 'Op', {inexhaustive, Residual}}] = errors(Src),
    ?assertEqual("(3..7 | 11..15)", bs_types:to_pattern(Residual)).

%% TICKET 30'S SHARP EDGE, ASSERTED AS A DESIGN RATHER THAN FOUND AS A BUG.
%% A binary's residual is unconditionally open — the sender chooses the length —
%% so `_` over a binary is always legal and never reported as discarding cases.
%% The consequence, which the feature file says out loud: write the tag dispatch
%% inline in the binary patterns and the checking is SILENTLY lost.
a_catch_all_over_a_binary_is_legal_test() ->
    Src = "module Bin7\n"
          "public atom Read(binary b)\n"
          "Read(<<1:8, _>>) -> :one\n"
          "Read(_) -> :other\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%%% ---------------------------------------------------------------------------
%%% F13.5–F13.6 — the segment forms
%%% ---------------------------------------------------------------------------

%% F13.5 — a segment sized by an earlier binding. It runs, and the dependency is
%% ERASED: `payload` is a plain `binary` and nothing downstream knows its length.
%% Every language measured refuses to relate two fields of one pattern; Gleam
%% permits the segment and erases at the binding, which is what is adopted here.
a_segment_sized_by_an_earlier_binding_test() ->
    M = build_and_load("module Bin8\n"
                       "public binary Body(binary b)\n"
                       "Body(<<size:8, payload:size, _>>) -> payload\n"
                       "Body(_) -> \"\"\n", 'Bin8'),
    ?assertEqual(<<"abc">>, M:'Body'(<<3, "abcXY">>)),
    ?assertEqual(<<"ab">>,  M:'Body'(<<2, "abcXY">>)).

%% The erasure, asserted rather than assumed: `payload` is a `binary`, so a
%% function wanting a `string` must not accept it without the O(n) entry check.
%% If the size were carried in the type this would be the place it leaked.
a_variable_sized_segment_is_typed_binary_test() ->
    Src = "module Bin9\n"
          "private int Len(binary b)\n"
          "Len(_) -> 0\n"
          "public int Body(binary b)\n"
          "Body(<<size:8, payload:size, _>>) -> Len(payload)\n"
          "Body(_) -> 0\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F13.6 — a literal segment matches and binds nothing. AMQP's frame sentinel.
a_literal_segment_matches_a_value_test() ->
    M = build_and_load("module BinA\n"
                       "public atom Frame(binary b)\n"
                       "Frame(<<t:8, size:8, payload:size, 0xCE:8, _>>) -> :ok\n"
                       "Frame(_) -> :bad\n", 'BinA'),
    ?assertEqual(ok,  M:'Frame'(<<1, 3, "abc", 16#CE>>)),
    %% The sentinel is wrong, so the shape does not match and the catch-all runs.
    %% 25c calls this "the check that matters most" and ticket 30 leaves it a
    %% RUNTIME check deliberately — catching it statically is the dependent step
    %% the whole survey refuses.
    ?assertEqual(bad, M:'Frame'(<<1, 3, "abc", 16#FF>>)).

%% A SUB-BYTE LITERAL, which is the form 25b's header needs: `126:7`.
a_sub_byte_literal_segment_matches_test() ->
    M = build_and_load("module BinB\n"
                       "public atom Which(binary b)\n"
                       "Which(<<_:1, 126:7, _>>) -> :extended\n"
                       "Which(<<_:1, 127:7, _>>) -> :huge\n"
                       "Which(_) -> :short\n", 'BinB'),
    ?assertEqual(extended, M:'Which'(<<126, 0, 0>>)),
    ?assertEqual(huge,     M:'Which'(<<127, 0, 0>>)),
    ?assertEqual(short,    M:'Which'(<<5, 0, 0>>)).

%%% ---------------------------------------------------------------------------
%%% F13.7 — hex literals, which are not binary work and are needed by it
%%% ---------------------------------------------------------------------------

%% Not in ticket 30's table. The decided surface writes `0xCE:8`, and `0xCE` did
%% not lex at all: `{D}+` gave the integer `0` and then the variable `xCE`.
%% Added EVERYWHERE rather than inside segments, because a lexer that is
%% context-sensitive for one construct's benefit is worse than the gap, and
%% because a language that can match `0xCE` and not write it is absurd.
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

%% Case-insensitive in both the marker and the digits, which is what every
%% language in the survey does and what a copied constant will be written as.
a_hex_literal_is_case_insensitive_test() ->
    M = build_and_load("module BinE\n"
                       "public int A()\n"
                       "A() -> 0Xce\n", 'BinE'),
    ?assertEqual(206, M:'A'()).

%%% ---------------------------------------------------------------------------
%%% F13.8–F13.10 — string literals in pattern position, ticket 30 §4
%%% ---------------------------------------------------------------------------

%% F13.8
a_string_literal_matches_in_pattern_position_test() ->
    M = build_and_load("module BinF\n"
                       "public atom Greet(string s)\n"
                       "Greet(\"hello\") -> :hi\n"
                       "Greet(s) -> :other\n", 'BinF'),
    ?assertEqual(hi,    M:'Greet'(<<"hello">>)),
    ?assertEqual(other, M:'Greet'(<<"goodbye">>)).

%% F13.9 — THE TEST TICKET 30 §4 EXPLICITLY OWES.
%%
%% The answer says a `string`'s residual is ALWAYS open, so a catch-all is
%% required and legal — and flags that this follows from READING the openness
%% rule rather than from any behavioural test, because no partial string match
%% could be constructed until this pattern existed. So: it must be accepted, and
%% it must NOT be reported as discarding cases the compiler can name.
a_catch_all_over_string_literals_is_legal_test() ->
    Src = "module BinG\n"
          "public atom Verb(string s)\n"
          "Verb(\"GET\") -> :get\n"
          "Verb(\"PUT\") -> :put\n"
          "Verb(_) -> :other\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% F13.10 — the other half, and without it the test above proves nothing. A set
%% of string literals is never exhaustive on its own. Matches Gleam exactly.
string_literals_alone_are_not_exhaustive_test() ->
    Src = "module BinH\n"
          "public atom Verb(string s)\n"
          "Verb(\"GET\") -> :get\n"
          "Verb(\"PUT\") -> :put\n",
    ?assertMatch([{error, _, 'Verb', {inexhaustive, _}}], errors(Src)).

%% A STRING LITERAL AS A SEGMENT, which is the prefix match — `<<"GET", rest>>`.
%% Ticket 30 §4 cites Gleam permitting both `"GET" <> rest` and
%% `<<"GET", _rest:bytes>>` and treating neither as total without `_`, and this
%% is the second of those forms. It fell out of the segment grammar rather than
%% being designed, which is exactly why it needs a test of its own: a production
%% that works by accident is one nobody notices breaking.
a_string_literal_may_be_a_segment_test() ->
    M = build_and_load("module BinP\n"
                       "public atom Verb(binary b)\n"
                       "Verb(<<\"GET\", rest>>) -> :get\n"
                       "Verb(<<\"POST\", rest>>) -> :post\n"
                       "Verb(_) -> :other\n", 'BinP'),
    ?assertEqual(get,   M:'Verb'(<<"GET /index">>)),
    ?assertEqual(post,  M:'Verb'(<<"POST /index">>)),
    %% The prefix must be a PREFIX and not a substring — without this the test
    %% would pass against an emitter that matched anywhere in the binary.
    ?assertEqual(other, M:'Verb'(<<"XGET /index">>)),
    ?assertEqual(other, M:'Verb'(<<"HEAD /index">>)).

%%% ---------------------------------------------------------------------------
%%% F13.11 — the token that must not be added
%%% ---------------------------------------------------------------------------

%% MEASURED BEFORE THE FEATURE, AND IT CHANGED THE DESIGN. Ticket 30's table
%% names `<<` as the missing token and says nothing about `>>`. But
%% `list<list<int>>` PARSES AND RUNS at 297eb2a, so a `>>` lexer rule would
%% swallow it and the failure would be a syntax error in generic code that has
%% nothing to do with binaries. F13 adds `<<` only; the pattern closes on two
%% separate `'>'` tokens, which is what the lexer already emits there.
a_nested_generic_still_parses_test() ->
    Src = "module BinI\n"
          "public int Head(list<list<int>> xss)\n"
          "Head(_) -> 1\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% The two in one file, which is the case a token-level fix would pass and a
%% grammar-level one has to earn.
a_nested_generic_and_a_binary_pattern_coexist_test() ->
    Src = "module BinJ\n"
          "public int Head(list<list<int>> xss, binary b)\n"
          "Head(_, <<a:8, _>>) -> a\n"
          "Head(_, _) -> 1\n",
    ?assertMatch({ok, _, _}, check_only(Src)).

%% THE GRAMMAR PAYS NOTHING. F14 refused a nicer diagnostic rather than spend
%% two shift/reduce conflicts, and a conflict is the one thing yecc reports as a
%% warning while still emitting a parser that looks like it works. So the count
%% is asserted rather than eyeballed from a quiet build.
the_grammar_has_no_conflicts_test() ->
    Yrl = filename:join(bs_test_support:project_root(), "src/bs_parser.yrl"),
    Out = filename:join(bs_test_support:run_root(), "conflict_check"),
    ok = filelib:ensure_dir(Out ++ "/x"),
    ?assertMatch({ok, _, []},
                 yecc:file(Yrl, [{parserfile, Out ++ ".erl"}, {return, true}])).

%%% ---------------------------------------------------------------------------
%%% F13.12–F13.13 — the known-shape refusals
%%% ---------------------------------------------------------------------------

%% F13.12 — an unsized segment is the remainder, so it can only be last. This is
%% a refusal with a KNOWN SHAPE, which this repo names rather than leaving to a
%% generic parse error — the record's `Id:int` and `Notes?: int` productions
%% both do the same.
an_unsized_segment_must_come_last_test() ->
    Src = "module BinK\n"
          "public int First(binary b)\n"
          "First(<<rest, a:8>>) -> a\n"
          "First(_) -> 0\n",
    ?assertMatch([{error, _, _, {unsized_segment_not_last, _, _}}], errors(Src)).

%% F13.13 — a literal that cannot fit its width is a compile error naming BOTH
%% numbers, because the author's mistake is usually the width and not the value.
a_literal_wider_than_its_segment_is_refused_test() ->
    Src = "module BinL\n"
          "public atom Which(binary b)\n"
          "Which(<<300:8, _>>) -> :yes\n"
          "Which(_) -> :no\n",
    ?assertMatch([{error, _, _, {segment_literal_too_wide, 300, 8, _}}],
                 errors(Src)).

%% A zero or negative width is not a thing a binary can have.
a_non_positive_width_is_refused_test() ->
    Src = "module BinM\n"
          "public int First(binary b)\n"
          "First(<<a:0, _>>) -> a\n"
          "First(_) -> 0\n",
    ?assertMatch([{error, _, _, {segment_width_not_positive, 0, _}}],
                 errors(Src)).

%% A size naming something that is not bound EARLIER IN THE SAME PATTERN. The
%% left-to-right rule is what makes the lowering legal on the BEAM, and getting
%% it wrong is a silent match failure rather than an error if left to Erlang.
a_size_must_name_an_earlier_binding_test() ->
    Src = "module BinN\n"
          "public binary Body(binary b)\n"
          "Body(<<payload:size, size:8>>) -> payload\n"
          "Body(_) -> \"\"\n",
    ?assertMatch([{error, _, _, {segment_size_not_bound, size, _}}],
                 errors(Src)).
