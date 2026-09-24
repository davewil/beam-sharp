%%% F9 — `string` and `binary` are values.
%%% Scenarios: compiler/features/F9-strings-and-binaries.md

-module(strings_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, check_only/1, errors/1,
                          with_src/3]).

-define(OUT, bs_test_support:run_root()).

%%% ---------------------------------------------------------------------------
%%% F9.1–F9.3 — literals produce UTF-8 binaries.
%%% ---------------------------------------------------------------------------

%% F9.1 — a string literal is an expression.
a_string_literal_is_an_expression_test() ->
    M = build_and_load("module Str\n"
                       "public string Greet()\n"
                       "Greet() -> \"hello\"\n", 'Str'),
    ?assertEqual(<<"hello">>, M:'Greet'()).

%% F9.3 — a non-ASCII literal preserves UTF-8 bytes.
%% Byte count catches encoding errors shared by source and expected literals.
a_non_ascii_literal_keeps_its_utf8_bytes_test() ->
    M = build_and_load("module Str8\n"
                       "public string Greet()\n"
                       "Greet() -> \"h\xc3\xa9llo\"\n", 'Str8'),
    ?assertEqual(6, byte_size(M:'Greet'())),
    ?assertEqual(<<"h", 16#c3, 16#a9, "llo">>, M:'Greet'()).

%% F9.2 — invalid UTF-8 is refused, without substituting replacement bytes.
an_invalid_utf8_literal_is_refused_test() ->
    Src = "module Bad\n"
          "public string Greet()\n"
          "Greet() -> \"h\xffllo\"\n",
    ?assertMatch({error, {_, bs_lexer, _}, _}, bs_lexer:string(Src)).

an_unknown_escape_is_refused_test() ->
    ?assertMatch({error, {_, bs_lexer, _}, _}, bs_lexer:string("\"a\\qb\"")).

escapes_produce_bytes_test() ->
    M = build_and_load("module Esc\n"
                       "public string Q()\n"
                       "Q() -> \"a\\\"b\\nc\"\n", 'Esc'),
    ?assertEqual(<<"a\"b\nc">>, M:'Q'()).

%%% ---------------------------------------------------------------------------
%%% F9.4–F9.9 — string refines binary.
%%% ---------------------------------------------------------------------------

%% F9.4 — `string` and `binary` are built-in types.
string_and_binary_are_builtin_type_names_test() ->
    ?assertMatch({ok, _, []},
                 check_only("module T\n"
                            "public string Echo(string s)\n"
                            "Echo(s) -> s\n"
                            "public binary Raw(binary b)\n"
                            "Raw(b) -> b\n")).

%% F9.5 — a string satisfies a binary return type.
a_string_satisfies_a_declared_binary_test() ->
    M = build_and_load("module Sub\n"
                       "public binary Bytes()\n"
                       "Bytes() -> \"hello\"\n", 'Sub'),
    ?assertEqual(<<"hello">>, M:'Bytes'()).

%% F9.6 — a binary does not satisfy a string return type.
a_binary_does_not_satisfy_a_declared_string_test() ->
    [{error, _, Fn, _}] = errors("module Ent\n"
                                 "public binary Raw(binary b)\n"
                                 "Raw(b) -> b\n"
                                 "public string Text(binary b)\n"
                                 "Text(b) -> Raw(b)\n"),
    ?assertEqual('Text', Fn).

%% A clause-return residual can lack a surface pattern spelling.
the_unspellable_point_prints_as_a_difference_test() ->
    Diff = bs_types:subtract(bs_types:binary_top(), bs_types:string()),
    ?assertNot(bs_types:is_none(Diff)),
    ?assertEqual("binary \\ string", bs_types:to_string(Diff)).

%% F9.7 — the union absorbs to binary; declaring the absorbed member fails.
string_or_binary_absorbs_to_binary_test() ->
    ?assertEqual(bs_types:binary_top(),
                 bs_types:union(bs_types:string(), bs_types:binary_top())),
    ?assertError({absorbed_member, _, _, none, _, _},
                 check_only("module Abs\n"
                            "type Any = string | binary\n"
                            "public Any Wide()\n"
                            "Wide() -> \"x\"\n")).

%% F9.8 — strings resolve in lists and record fields.
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

%% F9.9 — the residual names exactly `string`.
the_residual_over_a_string_union_is_exact_test() ->
    [{error, _, 'Kind', {inexhaustive, R, _}}] =
        errors("module Res\n"
               "type Payload = string | :nothing\n"
               "public atom Kind(Payload p)\n"
               "Kind(:nothing) -> :empty\n"),
    %% Exhaustiveness subtracts across the argument list, yielding a product.
    ?assertEqual("(string)", bs_types:to_pattern(R)).

%% A partial map match can misclassify a binary-only type as empty,
%% making containment pass vacuously; check emptiness directly.
a_string_is_not_the_empty_type_test() ->
    ?assertNot(bs_types:is_none(bs_types:string())),
    ?assertNot(bs_types:is_none(bs_types:binary_top())),
    ?assert(bs_types:is_none(bs_types:intersect(bs_types:string(),
                                                bs_types:int()))).

term_contains_binaries_test() ->
    ?assert(bs_types:is_subtype(bs_types:binary_top(), bs_types:term())),
    ?assert(bs_types:is_subtype(bs_types:string(), bs_types:term())),
    ?assertMatch({ok, _, []},
                 check_only("module Top\n"
                            "public term Anything(string s)\n"
                            "Anything(s) -> s\n")).

string_is_a_proper_subtype_of_binary_test() ->
    ?assert(bs_types:is_subtype(bs_types:string(), bs_types:binary_top())),
    ?assertNot(bs_types:is_subtype(bs_types:binary_top(), bs_types:string())).

%%% Guards and body bindings

a_string_literal_works_in_a_guard_test() ->
    M = build_and_load("module Gd\n"
                       "public atom Pick(string s)\n"
                       "Pick(s) when s == \"hello\" -> :hit\n"
                       "Pick(s)                   -> :miss\n", 'Gd'),
    ?assertEqual(hit, M:'Pick'(<<"hello">>)),
    ?assertEqual(miss, M:'Pick'(<<"nope">>)).

%% String values have no singleton type, so equality earns no coverage.
a_string_guard_earns_no_exhaustiveness_credit_test() ->
    ?assertMatch([{error, _, 'Pick', {inexhaustive, _, _}}],
                 errors("module Gu\n"
                        "public atom Pick(string s)\n"
                        "Pick(s) when s == \"hello\" -> :hit\n")).

a_string_literal_binds_in_a_body_test() ->
    M = build_and_load("module Bd\n"
                       "public string Local()\n"
                       "Local() ->\n"
                       "    var s = \"x\"\n"
                       "    s\n", 'Bd'),
    ?assertEqual(<<"x">>, M:'Local'()).

%%% ---------------------------------------------------------------------------
%%% F9.10–F9.11 — foreign returns require guard-decidable types.
%%% ---------------------------------------------------------------------------

%% F9.10 — binary is admissible as a foreign return.
binary_is_admissible_as_a_foreign_return_test() ->
    M = build_and_load("module Fb\n"
                       "using :erlang {\n"
                       "    binary term_to_binary(term t)\n"
                       "    int byte_size(binary b)\n"
                       "}\n"
                       "public int Size()\n"
                       "Size() -> :erlang.byte_size(\"hello\")\n", 'Fb'),
    ?assertEqual(5, M:'Size'()).

%% F9.11 — string is refused as a foreign return: UTF-8 needs a byte walk.
string_is_not_admissible_as_a_foreign_return_test() ->
    {Rc, R} = refused("Fs", "module Fs\n"
                            "using :file {\n"
                            "    string read_file(term path)\n"
                            "}\n"
                            "public string Text()\n"
                            "Text() -> \"x\"\n"),
    ?assertEqual(1, Rc),
    ?assert(found("read_file returns `string`, which one guard cannot decide", R)),
    ?assert(found("`string` is `binary` refined by valid UTF-8", R)).

%% The list needs an element walk before its string element is considered.
%% Replacing string with binary still leaves a list that needs a walk.
a_string_nested_in_a_foreign_return_is_refused_test() ->
    {Rc, R} = refused("Fl", "module Fl\n"
                            "using :file {\n"
                            "    list<string> read_lines(term path)\n"
                            "}\n"
                            "public int N()\n"
                            "N() -> 1\n"),
    ?assertEqual(1, Rc),
    ?assert(found("read_lines returns `list<string>`, which one guard cannot decide", R)),
    ?assert(found("declare it `list<term>`, then `ValidateAs<list<string>>`", R)),
    ?assertNot(offers_an_edit(R)).

a_string_keyed_foreign_map_is_refused_by_name_test() ->
    {Rc, R} = refused("Analytics", "module Analytics\n"
                                   "using :analytics_db {\n"
                                   "    map<string, term> latest_row(binary site)\n"
                                   "}\n"
                                   "public int N()\n"
                                   "N() -> 1\n"),
    ?assertEqual(1, Rc),
    ?assert(found("latest_row returns `map<string, term>`, which one guard cannot decide", R)),
    ?assert(found("declare it `map<term, term>`, then `ValidateAs<map<string, term>>`", R)),
    ?assertNot(offers_an_edit(R)),
    ?assertNot(found("exception", R)).

%% Checking only map keys would miss the string value restriction.
a_string_valued_foreign_map_is_refused_by_name_test() ->
    {Rc, R} = refused("Sessions", "module Sessions\n"
                                  "using :session_store {\n"
                                  "    map<binary, string> flash(binary sid)\n"
                                  "}\n"
                                  "public int N()\n"
                                  "N() -> 1\n"),
    ?assertEqual(1, Rc),
    ?assert(found("flash returns `map<binary, string>`, which one guard cannot decide", R)),
    ?assert(found("every key and value of this map would need inspecting", R)).

a_string_keyed_map_inside_a_result_is_refused_test() ->
    {Rc, R} = refused("Cart", "module Cart\n"
                              "using :session_store {\n"
                              "    result<map<string, int>, atom> cart(binary sid)\n"
                              "}\n"
                              "public int N()\n"
                              "N() -> 1\n"),
    ?assertEqual(1, Rc),
    ?assert(found("cart returns `result<map<string, int>, atom>`, which one guard cannot decide", R)),
    ?assert(found("declare the part a guard cannot decide as `term`", R)),
    ?assertNot(offers_an_edit(R)).

%% A tuple position is guard-accessible, so replacing string with binary works.
a_string_in_a_tuple_member_keeps_the_edit_test() ->
    {Rc, R} = refused("Users", "module Users\n"
                               "using :users_db {\n"
                               "    result<string, atom> name(int id)\n"
                               "}\n"
                               "public int N()\n"
                               "N() -> 1\n"),
    ?assertEqual(1, Rc),
    ?assert(found("name returns `result<string, atom>`, which one guard cannot decide", R)),
    ?assert(found("write `binary` where it says `string`", R)).

an_aliased_string_keeps_the_edit_test() ->
    {Rc, R} = refused("Names", "module Names\n"
                               "type Name = string\n"
                               "using :users_db {\n"
                               "    Name who(int id)\n"
                               "}\n"
                               "public int N()\n"
                               "N() -> 1\n"),
    ?assertEqual(1, Rc),
    ?assert(found("who returns `Name`, which one guard cannot decide", R)),
    ?assert(found("write `binary` where it says `string`", R)).

%% A named record is refused before its fields: the foreign return cannot
%% supply its compiler-defined Kind, so replacing string alone cannot help.
a_string_record_field_is_refused_as_a_record_first_test() ->
    {Rc, R} = refused("Acct", "module Acct\n"
                              "record Account { Id: int, Owner: string }\n"
                              "using :accounts_db {\n"
                              "    Account fetch(int id)\n"
                              "}\n"
                              "public int N()\n"
                              "N() -> 1\n"),
    ?assertEqual(1, Rc),
    ?assert(found("fetch returns `Account`, which one guard cannot decide", R)),
    ?assert(found("`Account` is a record, and Erlang cannot produce its `Kind`", R)),
    ?assert(found("write its fields instead, `{ Id: int, Owner: string }`", R)),
    ?assertNot(offers_an_edit(R)).

%% The list walk takes precedence over the adjacent string restriction.
a_string_beside_a_recursive_list_is_refused_as_a_list_test() ->
    {Rc, R} = refused("Mix", "module Mix\n"
                             "type Tree = :leaf | (Tree, Tree)\n"
                             "using :trees {\n"
                             "    (string, list<Tree>) grow(int n)\n"
                             "}\n"
                             "public int N()\n"
                             "N() -> 1\n"),
    ?assertEqual(1, Rc),
    ?assert(found("grow returns `(string, list<Tree>)`, which one guard cannot decide", R)),
    ?assert(found("every element of this list would need inspecting", R)),
    ?assertNot(offers_an_edit(R)).

%% Without a surrounding list, recursion itself takes precedence over string.
a_string_beside_a_recursive_member_is_refused_as_recursive_test() ->
    {Rc, R} = refused("Tup", "module Tup\n"
                             "type Tree = :leaf | (Tree, Tree)\n"
                             "using :trees {\n"
                             "    (string, Tree) grow(int n)\n"
                             "}\n"
                             "public int N()\n"
                             "N() -> 1\n"),
    ?assertEqual(1, Rc),
    ?assert(found("grow returns `(string, Tree)`, which one guard cannot decide", R)),
    ?assert(found("`Tree` is recursive", R)),
    ?assertNot(offers_an_edit(R)).

%% Unlike narrower maps, map<term, term> needs no key or value walk.
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

refused(Mod, Src) ->
    with_src(Mod ++ ".bs", Src,
             fun(Path, Out) ->
                 bs_test_support:run_cli_result("-o " ++ Out ++ " " ++ Path)
             end).

found(Text, R) -> string:find(R, Text) =/= nomatch.

offers_an_edit(R) ->
    found("declare it `binary`", R) orelse found("write `binary`", R).

%% Foreign parameters leave B# with their type established; no entry check.
string_is_admissible_as_a_foreign_parameter_test() ->
    ?assertMatch({ok, _, []},
                 check_only("module Fp\n"
                            "using :erlang {\n"
                            "    int byte_size(string s)\n"
                            "}\n"
                            "public int Size()\n"
                            "Size() -> :erlang.byte_size(\"hi\")\n")).

%%% CLI output

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

%% Binary keys have no B# value spelling, so the CLI uses Erlang notation.
the_cli_prints_a_binary_keyed_map_test() ->
    with_src("Views.bs", views_src(),
             fun(Path, Out) ->
                 {Rc, R} = bs_test_support:run_cli_result(
                             "-o " ++ Out ++ " " ++ Path ++ " Counts"),
                 ?assertEqual(0, Rc),
                 ?assertEqual("#{<<\"about\">> => 1,<<\"home\">> => 3}\n", R)
             end).

%%% Argument reader

a_quoted_argument_reads_as_a_binary_test() ->
    ?assertEqual({ok, <<"zz">>}, bs_run:read_arg("\"zz\"")).

a_string_survives_a_print_and_read_round_trip_test() ->
    Printed = lists:flatten(bs_run:format_value(<<"héllo"/utf8>>)),
    ?assertEqual({ok, <<"héllo"/utf8>>}, bs_run:read_arg(Printed)).

a_quoted_argument_honours_escapes_test() ->
    ?assertEqual({ok, <<"a\"b">>}, bs_run:read_arg("\"a\\\"b\"")).

an_empty_quoted_argument_is_an_empty_binary_test() ->
    ?assertEqual({ok, <<>>}, bs_run:read_arg("\"\"")).

%% The prose carries the replacement advice that the diagnostic term lacks.
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
