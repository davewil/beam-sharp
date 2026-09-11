%%% F9 — `string` and `binary` as values.
%%%
%%% Ticket 20 §4 makes `string` a REFINEMENT of `binary` rather than a second
%%% type beside it, so most of what is asserted here is containment in one
%%% direction and its absence in the other. Ticket 20 §5 puts that refinement in
%%% the opaque tier, which is what the boundary tests are about.
%%%
%%% Binary PATTERNS are not here and are not missing: ticket 30 is open, and the
%%% feature file says why in full.

-module(strings_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, check_only/1, errors/1,
                          with_src/3]).

-define(OUT, bs_test_support:run_root()).

%%% ---------------------------------------------------------------------------
%%% F9.1–F9.3 — the literal
%%% ---------------------------------------------------------------------------

%% F9.1
a_string_literal_is_an_expression_test() ->
    M = build_and_load("module Str\n"
                       "public string Greet()\n"
                       "Greet() -> \"hello\"\n", 'Str'),
    ?assertEqual(<<"hello">>, M:'Greet'()).

%% F9.3 — THE SCENARIO THAT PAID FOR ITSELF.
%%
%% Every string in the exemplars is ASCII, so an encoding fault in the emitter is
%% invisible to every other test in this file. This one caught the `.abstr` file
%% being written as bytes and read back by `erlc` as UTF-8: `"héllo"` came out
%% five bytes instead of six, having compiled and run perfectly. The fix is the
%% coding comment in `bs_emit:to_abstr/1`.
%%
%% Asserted on the BYTE COUNT as well as the value, because the two failure
%% modes — losing a byte and doubling one — both survive an equality check
%% against a literal written in the same broken encoding.
a_non_ascii_literal_keeps_its_utf8_bytes_test() ->
    M = build_and_load("module Str8\n"
                       "public string Greet()\n"
                       "Greet() -> \"h\xc3\xa9llo\"\n", 'Str8'),
    ?assertEqual(6, byte_size(M:'Greet'())),
    ?assertEqual(<<"h", 16#c3, 16#a9, "llo">>, M:'Greet'()).

%% F9.2. Ticket 29 §4: C# and TypeScript both substitute U+FFFD here and
%% beam-sharp refuses, so this asserts a DIVERGENCE and not merely a check.
an_invalid_utf8_literal_is_refused_test() ->
    Src = "module Bad\n"
          "public string Greet()\n"
          "Greet() -> \"h\xffllo\"\n",
    ?assertMatch({error, {_, bs_lexer, _}, _}, bs_lexer:string(Src)).

%% The escape set is closed on purpose, so that adding `\u` later cannot change
%% what an already-compiling program means.
an_unknown_escape_is_refused_test() ->
    ?assertMatch({error, {_, bs_lexer, _}, _}, bs_lexer:string("\"a\\qb\"")).

escapes_produce_bytes_test() ->
    M = build_and_load("module Esc\n"
                       "public string Q()\n"
                       "Q() -> \"a\\\"b\\nc\"\n", 'Esc'),
    ?assertEqual(<<"a\"b\nc">>, M:'Q'()).

%%% ---------------------------------------------------------------------------
%%% F9.4–F9.9 — the types
%%% ---------------------------------------------------------------------------

%% F9.4
string_and_binary_are_builtin_type_names_test() ->
    ?assertMatch({ok, _, []},
                 check_only("module T\n"
                            "public string Echo(string s)\n"
                            "Echo(s) -> s\n"
                            "public binary Raw(binary b)\n"
                            "Raw(b) -> b\n")).

%% F9.5 — the refinement is a SUBSET, so this direction holds...
a_string_satisfies_a_declared_binary_test() ->
    M = build_and_load("module Sub\n"
                       "public binary Bytes()\n"
                       "Bytes() -> \"hello\"\n", 'Sub'),
    ?assertEqual(<<"hello">>, M:'Bytes'()).

%% F9.6 — ...and this one does not. The absence of the entry check, made
%% observable at F5's clause-return site.
a_binary_does_not_satisfy_a_declared_string_test() ->
    [{error, _, Fn, _}] = errors("module Ent\n"
                                 "public binary Raw(binary b)\n"
                                 "Raw(b) -> b\n"
                                 "public string Text(binary b)\n"
                                 "Text(b) -> Raw(b)\n"),
    ?assertEqual('Text', Fn).

%% And the residual it reports is the fourth point of the binary part — the one
%% with no surface spelling. It is REACHABLE, which the feature file first
%% claimed it was not: a clause return reaches it where a pattern residual
%% cannot, because containment is checked in both directions and only patterns
%% are restricted to what can be written.
the_unspellable_point_prints_as_a_difference_test() ->
    Diff = bs_types:subtract(bs_types:binary_top(), bs_types:string()),
    ?assertNot(bs_types:is_none(Diff)),
    ?assertEqual("binary \\ string", bs_types:to_string(Diff)).

%% F9.7 — THE ALGEBRA IS UNCHANGED AND THE VERDICT IS REVERSED (ticket 68).
%%
%% The first assertion is what this test always said and still says: `string`
%% is `binary` refined by UTF-8, so the union IS `binary`. The reasoning that
%% went with it survives too — 09 §4 errors on INDISCRIMINABLE members, and
%% `string` is nested rather than overlapping, so that neighbouring rule still
%% correctly does not fire here.
%%
%% What changed is that a SECOND rule now does. Ticket 68 Q1(a) refuses any
%% member absorbed by the union of the others, not only a failure channel, and
%% under it `type Any = string | binary` declares a member that is not in the
%% type it declares. That rule did not exist when this test was written.
string_or_binary_absorbs_to_binary_test() ->
    ?assertEqual(bs_types:binary_top(),
                 bs_types:union(bs_types:string(), bs_types:binary_top())),
    ?assertError({absorbed_member, _, _, none, _, _},
                 check_only("module Abs\n"
                            "type Any = string | binary\n"
                            "public Any Wide()\n"
                            "Wide() -> \"x\"\n")).

%% F9.8 — the row the exemplars are actually waiting on.
list_of_string_and_a_string_field_resolve_test() ->
    M = build_and_load("module Rec\n"
                       "record Order { Id: string, Total: int }\n"
                       "public list<string> Ids()\n"
                       "Ids() -> [\"A-1\", \"B-2\"]\n"
                       "public string Which(Order o)\n"
                       "Which(o) -> o.Id\n", 'Rec'),
    ?assertEqual([<<"A-1">>, <<"B-2">>], M:'Ids'()),
    ?assertEqual(<<"z">>, M:'Which'(#{'Kind' => 'Rec.Order',
                                      'Id' => <<"z">>, 'Total' => 1})).

%% F9.9 — the residual names `string`, not `term` and not `binary`. A new algebra
%% component that quietly reports empty is this compiler's recurring failure, and
%% a residual that is exact is the observable that rules it out.
the_residual_over_a_string_union_is_exact_test() ->
    [{error, _, 'Kind', {inexhaustive, R, _}}] =
        errors("module Res\n"
               "type Payload = string | :nothing\n"
               "public atom Kind(Payload p)\n"
               "Kind(:nothing) -> :empty\n"),
    %% A product, because ticket 04 makes exhaustiveness ONE subtraction across
    %% the whole argument list rather than one per column.
    ?assertEqual("(string)", bs_types:to_pattern(R)).

%% THE MUTATION GUARD. `is_none/1` matches the `ty()` map literally, and Erlang
%% map patterns are partial — so dropping `bins := []` from its head does not
%% fail, it makes a binary-only type report EMPTY and every containment over it
%% pass vacuously. The compiler goes quieter rather than red.
%%
%% This is the assertion that goes red for that mutation, and it is stated
%% directly on the algebra because there is no boundary through which "a type
%% wrongly believed empty" can be observed — that is precisely the problem.
a_string_is_not_the_empty_type_test() ->
    ?assertNot(bs_types:is_none(bs_types:string())),
    ?assertNot(bs_types:is_none(bs_types:binary_top())),
    ?assert(bs_types:is_none(bs_types:intersect(bs_types:string(),
                                                bs_types:int()))).

%% `term` must contain both halves or it stops being the top type and every
%% residual subtracted from it is wrong in the quiet direction.
term_contains_binaries_test() ->
    ?assert(bs_types:is_subtype(bs_types:binary_top(), bs_types:term())),
    ?assert(bs_types:is_subtype(bs_types:string(), bs_types:term())),
    ?assertMatch({ok, _, []},
                 check_only("module Top\n"
                            "public term Anything(string s)\n"
                            "Anything(s) -> s\n")).

%% The containment that carries the whole refinement story, in both directions.
string_is_a_proper_subtype_of_binary_test() ->
    ?assert(bs_types:is_subtype(bs_types:string(), bs_types:binary_top())),
    ?assertNot(bs_types:is_subtype(bs_types:binary_top(), bs_types:string())).

%%% ---------------------------------------------------------------------------
%%% The two sites a new expression form reaches that nothing above exercises
%%%
%%% Added after the scenarios were written, because neither was in them and both
%%% are the first thing anyone types once literals exist. F7's lesson: run the
%%% capability's own motivating example rather than trusting that a form which
%%% works in return position works everywhere the grammar admits it.
%%% ---------------------------------------------------------------------------

%% Guards share the expression grammar, so a string literal reaches the guard
%% emitter — a different function from `expr/2`, and one that crashes on a form
%% it does not know rather than rejecting it.
a_string_literal_works_in_a_guard_test() ->
    M = build_and_load("module Gd\n"
                       "public atom Pick(string s)\n"
                       "Pick(s) when s == \"hello\" -> :hit\n"
                       "Pick(s)                   -> :miss\n", 'Gd'),
    ?assertEqual(hit, M:'Pick'(<<"hello">>)),
    ?assertEqual(miss, M:'Pick'(<<"nope">>)).

%% ...and it is UNCREDITABLE, which is the right answer rather than a gap. The
%% checker translates `var == literal` into a type operation only where the
%% literal is a member of a part it can subtract, and there is no value-level
%% singleton in the binary part (see the pattern-position note in the parser).
%% So the guard is `Possible`, the clause earns no exhaustiveness credit, and
%% dropping the catch-all is an ERROR rather than a silent pass.
a_string_guard_earns_no_exhaustiveness_credit_test() ->
    ?assertMatch([{error, _, 'Pick', {inexhaustive, _, _}}],
                 errors("module Gu\n"
                        "public atom Pick(string s)\n"
                        "Pick(s) when s == \"hello\" -> :hit\n")).

%% F5's fifth site — a body binding, which none of the scenarios above reach.
a_string_literal_binds_in_a_body_test() ->
    M = build_and_load("module Bd\n"
                       "public string Local()\n"
                       "Local() ->\n"
                       "    var s = \"x\"\n"
                       "    s\n", 'Bd'),
    ?assertEqual(<<"x">>, M:'Local'()).

%%% ---------------------------------------------------------------------------
%%% F9.10–F9.11 — the boundary
%%% ---------------------------------------------------------------------------

%% F9.10. Ticket 20 §3 measured `byte_size/1` and `bit_size/1` as O(1) guard
%% BIFs at 8 B and 8 MiB alike, so the whole binary grammar is admissible.
binary_is_admissible_as_a_foreign_return_test() ->
    M = build_and_load("module Fb\n"
                       "using :erlang {\n"
                       "    binary term_to_binary(term t)\n"
                       "    int byte_size(binary b)\n"
                       "}\n"
                       "public int Size()\n"
                       "Size() -> :erlang.byte_size(\"hello\")\n", 'Fb'),
    ?assertEqual(5, M:'Size'()).

%% F9.11. Ticket 18 §2's admissible foreign return set is "what one BEAM guard
%% decides in O(1)", and `valid_utf8` reads every byte of a value the sender
%% sizes — ticket 11's sentence at a second site.
string_is_not_admissible_as_a_foreign_return_test() ->
    {Rc, R} = refused("Fs", "module Fs\n"
                            "using :file {\n"
                            "    string read_file(term path)\n"
                            "}\n"
                            "public string Text()\n"
                            "Text() -> \"x\"\n"),
    ?assertEqual(1, Rc),
    ?assert(found("read_file returns `string`, which a guard cannot decide", R)).

%% Deeper is the same error — 18 §2 says "anything deeper is a compile error at
%% the declaration", and a bracket is exactly where an unbounded check hides.
%% No edit is offered: `binary` under the bracket needs every element inspected
%% too, which is the rest of 18 §2 (ENG-354).
a_string_nested_in_a_foreign_return_is_refused_test() ->
    {Rc, R} = refused("Fl", "module Fl\n"
                            "using :file {\n"
                            "    list<string> read_lines(term path)\n"
                            "}\n"
                            "public int N()\n"
                            "N() -> 1\n"),
    ?assertEqual(1, Rc),
    ?assert(found("read_lines returns `list<string>`, whose `string`", R)),
    ?assertNot(offers_an_edit(R)).

%% ENG-351. A `map<K, V>` is the third place a `string` hides in a foreign
%% return, and until this the check crashed on it: `bsc` printed a stack trace
%% for any foreign declaration returning a domain map, whatever its keys.
a_string_keyed_foreign_map_is_refused_by_name_test() ->
    {Rc, R} = refused("Analytics", "module Analytics\n"
                                   "using :analytics_db {\n"
                                   "    map<string, term> latest_row(binary site)\n"
                                   "}\n"
                                   "public int N()\n"
                                   "N() -> 1\n"),
    ?assertEqual(1, Rc),
    ?assert(found("latest_row returns `map<string, term>`, whose `string`", R)),
    ?assertNot(offers_an_edit(R)),
    ?assertNot(found("exception", R)).

%% The value side, so a fix that asks only the keys fails here. "Returns
%% `string`" was the only wording the check had, and it is false of a map.
a_string_valued_foreign_map_is_refused_by_name_test() ->
    {Rc, R} = refused("Sessions", "module Sessions\n"
                                  "using :session_store {\n"
                                  "    map<binary, string> flash(binary sid)\n"
                                  "}\n"
                                  "public int N()\n"
                                  "N() -> 1\n"),
    ?assertEqual(1, Rc),
    ?assert(found("flash returns `map<binary, string>`, whose `string`", R)).

%% The shape ENG-351 named beside the map: the map is inside a tuple, and the
%% walk it needs is still the map's.
a_string_keyed_map_inside_a_result_is_refused_test() ->
    {Rc, R} = refused("Cart", "module Cart\n"
                              "using :session_store {\n"
                              "    result<map<string, int>, atom> cart(binary sid)\n"
                              "}\n"
                              "public int N()\n"
                              "N() -> 1\n"),
    ?assertEqual(1, Rc),
    ?assert(found("cart returns `result<map<string, int>, atom>`,", R)),
    ?assertNot(offers_an_edit(R)).

%% A tuple member is a fixed position one guard reaches, so `binary` there is
%% admissible under the whole of 18 §2 and the edit is offered.
a_string_in_a_tuple_member_keeps_the_edit_test() ->
    {Rc, R} = refused("Users", "module Users\n"
                               "using :users_db {\n"
                               "    result<string, atom> name(int id)\n"
                               "}\n"
                               "public int N()\n"
                               "N() -> 1\n"),
    ?assertEqual(1, Rc),
    ?assert(found("name returns `result<string, atom>`, whose `string`", R)),
    ?assert(found("write `binary` where it says `string`", R)).

%% An alias of `string` is the whole return by another name, and it had the
%% edit before ENG-351 named the type as written.
an_aliased_string_keeps_the_edit_test() ->
    {Rc, R} = refused("Names", "module Names\n"
                               "type Name = string\n"
                               "using :users_db {\n"
                               "    Name who(int id)\n"
                               "}\n"
                               "public int N()\n"
                               "N() -> 1\n"),
    ?assertEqual(1, Rc),
    ?assert(found("who returns `Name`, whose `string`", R)),
    ?assert(found("write `binary` where it says `string`", R)).

%% A record field is a fixed position too: the edit names the field's `string`.
a_string_record_field_keeps_the_edit_test() ->
    {Rc, R} = refused("Acct", "module Acct\n"
                              "record Account { Id: int, Owner: string }\n"
                              "using :accounts_db {\n"
                              "    Account fetch(int id)\n"
                              "}\n"
                              "public int N()\n"
                              "N() -> 1\n"),
    ?assertEqual(1, Rc),
    ?assert(found("fetch returns `Account`, whose `string`", R)),
    ?assert(found("write `binary` where it says `string`", R)).

%% A recursive type under a list is decided only by a walk, so no edit is
%% offered even for the `string` beside it — and the position is asked of the
%% `mu` without unfolding it, which `opaque_refinement/1` cannot do.
a_string_beside_a_recursive_list_is_refused_without_an_edit_test() ->
    {Rc, R} = refused("Mix", "module Mix\n"
                             "type Tree = :leaf | (Tree, Tree)\n"
                             "using :trees {\n"
                             "    (string, list<Tree>) grow(int n)\n"
                             "}\n"
                             "public int N()\n"
                             "N() -> 1\n"),
    ?assertEqual(1, Rc),
    ?assert(found("grow returns `(string, list<Tree>)`, whose `string`", R)),
    ?assertNot(offers_an_edit(R)).

%% `map<term, term>` is the domain map one guard decides in O(1) — `is_map`,
%% and F33's `Kind` exclusion is `is_map_key` — so it is admissible under the
%% whole of 18 §2, not only the `string` slice this compiler builds. It crashed
%% the check before ENG-351 like every other domain map.
a_term_keyed_foreign_map_is_admissible_test() ->
    M = build_and_load(views_src(), 'Views'),
    ?assertEqual(#{<<"home">> => 3, <<"about">> => 1}, M:'Counts'()).

views_src() ->
    "module Views\n"
    "using :maps {\n"
    "    map<term, term> from_list(list<term> pairs)\n"
    "}\n"
    "public map<term, term> Counts()\n"
    "Counts() -> :maps.from_list([(\"home\", 3), (\"about\", 1)])\n".

%% What `bsc` prints for a program, and its exit status.
refused(Mod, Src) ->
    with_src(Mod ++ ".bs", Src,
             fun(Path, Out) ->
                 bs_test_support:run_cli_result("-o " ++ Out ++ " " ++ Path)
             end).

found(Text, R) -> string:find(R, Text) =/= nomatch.

offers_an_edit(R) ->
    found("declare it `binary`", R) orelse found("write `binary`", R).

%% PARAMETER POSITION IS NOT BARRED, and the asymmetry is the rule rather than an
%% oversight. A parameter is a value beam-sharp hands OUT, already established by
%% the signature that produced it; nothing arrives and nothing needs checking.
string_is_admissible_as_a_foreign_parameter_test() ->
    ?assertMatch({ok, _, []},
                 check_only("module Fp\n"
                            "using :erlang {\n"
                            "    int byte_size(string s)\n"
                            "}\n"
                            "public int Size()\n"
                            "Size() -> :erlang.byte_size(\"hi\")\n")).

%%% ---------------------------------------------------------------------------
%%% The CLI, because a feature is done when you can see it run
%%% ---------------------------------------------------------------------------

the_cli_prints_a_string_test() ->
    with_src("Cli.bs",
             "module Cli\n"
             "public string Greet()\n"
             "Greet() -> \"hello\"\n",
             fun(Path, Out) ->
                 {_, R} = bs_test_support:run_cli_result(
                            "-o " ++ Out ++ " " ++ Path ++ " Greet"),
                 ?assertEqual("\"hello\"\n", R)
             end).

%% A map with binary keys has no beam-sharp spelling — bare braces name atom
%% keys (ticket 48) — so the CLI prints it the way it prints any other value it
%% cannot spell, in Erlang's notation, rather than crashing on the first key.
the_cli_prints_a_binary_keyed_map_test() ->
    with_src("Views.bs", views_src(),
             fun(Path, Out) ->
                 {Rc, R} = bs_test_support:run_cli_result(
                             "-o " ++ Out ++ " " ++ Path ++ " Counts"),
                 ?assertEqual(0, Rc),
                 ?assertEqual("#{<<\"about\">> => 1,<<\"home\">> => 3}\n", R)
             end).

%%% ---------------------------------------------------------------------------
%%% The argument reader — F9's hole at the prompt
%%%
%%% Three features running had each found one here and fixed only what they
%%% tripped over. F9's is that `"zz"` typed as an argument came back an Erlang
%%% CHAR LIST, so a string changed type on a round trip: `format_value/1` prints
%%% a binary as `"zz"`, and feeding that back printed `[122, 122]`. The prompt
%%% could not show you what it had just shown you.
%%% ---------------------------------------------------------------------------

a_quoted_argument_reads_as_a_binary_test() ->
    ?assertEqual({ok, <<"zz">>}, bs_run:read_arg("\"zz\"")).

%% The round trip stated as the property rather than as an example, since that
%% is the rule `parse_compound/2` is written against.
a_string_survives_a_print_and_read_round_trip_test() ->
    Printed = lists:flatten(bs_run:format_value(<<"héllo"/utf8>>)),
    ?assertEqual({ok, <<"héllo"/utf8>>}, bs_run:read_arg(Printed)).

%% Escapes mean the same at the prompt as in a `.bs` file, which is why this
%% reads through `erl_scan` rather than stripping the quotes.
a_quoted_argument_honours_escapes_test() ->
    ?assertEqual({ok, <<"a\"b">>}, bs_run:read_arg("\"a\\\"b\"")).

%% An empty string is a binary and not the empty list, which the length guard in
%% `parse_compound/2` exists to keep apart from `""` meaning nothing at all.
an_empty_quoted_argument_is_an_empty_binary_test() ->
    ?assertEqual({ok, <<>>}, bs_run:read_arg("\"\"")).

%% The rejection an author actually sees, asserted on the text rather than the
%% term: ticket 23 makes the diagnostic the product, and F9.11's message has a
%% fix in it that the error term does not carry.
the_boundary_error_names_the_replacement_test() ->
    with_src("Fbad.bs",
             "module Fbad\n"
             "using :file {\n"
             "    string read_file(term path)\n"
             "}\n"
             "public int N()\n"
             "N() -> 1\n",
             fun(Path, Out) ->
                 {_, R} = bs_test_support:run_cli_result(
                            "-o " ++ Out ++ " " ++ Path),
                 ?assert(string:find(R, "declare it `binary`") =/= nomatch),
                 ?assert(string:find(R, "entry check") =/= nomatch)
             end).
