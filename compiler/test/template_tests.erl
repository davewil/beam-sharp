%%% Scenarios: compiler/features/F66-template-strings.md
%%% F66 — template strings, `$"Order {o.Id} for {o.Customer}"`: one binary
%%% construction, each hole printed by the part its type names (ticket 112 A2,
%%% A3; ENG-562).
-module(template_tests).

-include_lib("eunit/include/eunit.hrl").

%%% Helpers: fixtures live under module paths in an isolated source root.

in_dir(Files) ->
    Root = bs_test_support:fixture_root(),
    Paths = [bs_test_support:place(Root, N, S) || {N, S} <- Files],
    {Root, hd(Paths)}.

%% The term channel, so a test names the diagnostic by its tag.
diagnose(Files) ->
    {Root, Main} = in_dir(Files),
    bs_test_support:run_cli("--diagnostics term --src-root " ++ Root ++ " -o " ++ Root
                            ++ "/out " ++ Main).

%% The prose channel, for a refusal that happens before any term is built.
compile(Files) ->
    {Root, Main} = in_dir(Files),
    bs_test_support:run_cli("--src-root " ++ Root ++ " -o " ++ Root ++ "/out " ++ Main).

run(Files, Call) ->
    {Root, Main} = in_dir(Files),
    bs_test_support:run_cli("--src-root " ++ Root ++ " " ++ Main ++ " " ++ Call).

%% The emitted forms of `Mod`, compiled from `Files` into a fresh directory.
forms(Files, Mod) ->
    {Root, Main} = in_dir(Files),
    Out = Root ++ "/out",
    Got = bs_test_support:run_cli("--src-root " ++ Root ++ " -o " ++ Out ++ " " ++ Main),
    ok_rc(Got),
    {ok, Forms} = file:consult(filename:join(Out, Mod ++ ".abstr")),
    Forms.

ok_rc(Out)    -> ?assertNotEqual(nomatch, string:find(Out, "rc:0")).
bad_rc(Out)   -> ?assertEqual(nomatch, string:find(Out, "rc:0")).
has(Out, S)   -> ?assertNotEqual(nomatch, string:find(Out, S)).
tagged(Out, Tag) -> has(Out, "tag => " ++ Tag).

%% Ticket 112's first program: Signalbox's model key.
evidence(Rest) ->
    {"Evidence.bs",
     "module Evidence\n"
     "record ModelIdentity { Lab: string, Model: string, Harness: string }\n"
     "public string ModelKey(ModelIdentity id)\n"
     "ModelKey(id) -> $\"{id.Lab}/{id.Model}/{id.Harness}\"\n"
     ++ Rest}.

%% Ticket 112's second: a receipt line over pence.
receipts(Rest) ->
    {"Receipts.bs",
     "module Receipts\n"
     "record Order { Id: int, Customer: string, Total: int, Status: :placed | :paid }\n"
     "public string Line(Order o)\n"
     "Line(o) -> $\"Order {o.Id} for {o.Customer}: {o.Total} pence, {o.Status}\"\n"
     ++ Rest}.

%% F66.1 — every hole a `string`: the key is the three fields joined, and
%% `id` is read only inside holes.
the_model_key_joins_three_strings_test() ->
    Got = run([evidence("public string Demo()\n"
                        "Demo() -> ModelKey(ModelIdentity { Lab = \"-\", Model = \"glm-5.2\","
                        " Harness = \"opencode\" })\n")],
              "Demo"),
    ok_rc(Got),
    has(Got, "\"-/glm-5.2/opencode\"").

%% F66.2 — an `int`, a `string` and an atom hole, each printed as it stands.
a_receipt_line_prints_each_part_test() ->
    Got = run([receipts("public string Demo()\n"
                        "Demo() -> Line(Order { Id = 42, Customer = \"Ada\", Total = 1250,"
                        " Status = :placed })\n")],
              "Demo"),
    ok_rc(Got),
    has(Got, "\"Order 42 for Ada: 1250 pence, placed\"").

%% F66.3 — a negative `int`, and a `float` in its shortest round-tripping
%% form, so `2.0` keeps its point.
numbers_print_as_written_test() ->
    Got = run([{"Nums.bs",
                "module Nums\n"
                "public string Show(int i, float f, float g)\n"
                "Show(i, f, g) -> $\"{i} {f} {g}\"\n"
                "public string Demo()\n"
                "Demo() -> Show(-5, 0.1, 2.0)\n"}],
              "Demo"),
    ok_rc(Got),
    has(Got, "\"-5 0.1 2.0\"").

%% F66.4 — `{{` and `}}` write a literal brace, beside a hole and alone.
a_doubled_brace_is_literal_test() ->
    Got = run([{"Braces.bs",
                "module Braces\n"
                "public string Show(int n)\n"
                "Show(n) -> $\"{{x}} = {n}, a}}b\"\n"
                "public string Demo()\n"
                "Demo() -> Show(3)\n"}],
              "Demo"),
    ok_rc(Got),
    has(Got, "\"{x} = 3, a}b\"").

%% F66.5 — a hole balances its braces and skips a string literal inside it,
%% so a `switch` whose arm matches `"}"` is one hole.
a_hole_balances_braces_and_skips_strings_test() ->
    Src = {"Nested.bs",
           "module Nested\n"
           "public string Say(string s)\n"
           "Say(s) -> $\"<{s switch { \"}\" => \"close\", _ => \"other\" }}>\"\n"
           "public string A()\n"
           "A() -> Say(\"}\")\n"
           "public string B()\n"
           "B() -> Say(\"x\")\n"},
    A = run([Src], "A"),
    ok_rc(A),
    has(A, "\"<close>\""),
    B = run([Src], "B"),
    ok_rc(B),
    has(B, "\"<other>\"").

%% F66.6 — a template's text takes a plain string's escapes.
text_takes_a_strings_escapes_test() ->
    Got = run([{"Esc.bs",
                "module Esc\n"
                "public atom Quoted(string s)\n"
                "Quoted(s) -> ($\"\\\"{s}\\\"\" == \"\\\"y\\\"\") switch { true => :yes, false => :no }\n"
                "public atom Demo()\n"
                "Demo() -> Quoted(\"y\")\n"}],
              "Demo"),
    ok_rc(Got),
    has(Got, "yes").

%% F66.7 — a record hole waits on `Formattable` (ticket 113, ENG-565), so it
%% is refused at the hole's own column, not the template's, and the refusal
%% says it is not built rather than that a record can never print.
a_record_hole_is_refused_test() ->
    Got = diagnose([{"Bad.bs",
                     "module Bad\n"
                     "record Money { Pence: int }\n"
                     "public string Show(Money m)\n"
                     "Show(m) -> $\"total {m}\"\n"}]),
    bad_rc(Got),
    tagged(Got, "interp_hole"),
    has(Got, "line => 4"),
    has(Got, "column => 20"),
    Prose = compile([{"Bad.bs",
                      "module Bad\n"
                      "record Money { Pence: int }\n"
                      "public string Show(Money m)\n"
                      "Show(m) -> $\"total {m}\"\n"}]),
    has(Prose, "Bad.bs:4:20: error:"),
    has(Prose, "Money"),
    has(Prose, "Formattable"),
    has(Prose, "not built").

%% F66.8's union is not told about `Formattable`: nothing will print it.
a_union_hole_is_not_told_about_formattable_test() ->
    Got = compile([{"Un.bs",
                    "module Un
"
                    "type Num = int | float
"
                    "public string Show(Num n)
"
                    "Show(n) -> $\"{n}\"
"}]),
    bad_rc(Got),
    has(Got, "switch"),
    ?assertEqual(nomatch, string:find(Got, "Formattable")).

%% F66.8 — a union spanning two parts has no one lowering, so `int | float`
%% is refused; so are a list and `term`.
a_hole_spanning_two_parts_is_refused_test() ->
    [begin
         Got = diagnose([{"Bad.bs",
                          "module Bad\n"
                          "type Num = int | float\n"
                          "public string Show(" ++ Ty ++ " n)\n"
                          "Show(n) -> $\"{n}\"\n"}]),
         bad_rc(Got),
         tagged(Got, "interp_hole")
     end || Ty <- ["Num", "list<int>", "term"]].

%% F66.9 — a template of `string` holes is a guard expression, since binary
%% construction is one.
a_string_template_is_a_guard_test() ->
    Src = {"Gs.bs",
           "module Gs\n"
           "public atom Is(string s, string p)\n"
           "Is(s, p) when s == $\"{p}!\" -> :yes\n"
           "Is(s, p) -> :no\n"
           "public atom A()\n"
           "A() -> Is(\"hi!\", \"hi\")\n"
           "public atom B()\n"
           "B() -> Is(\"hi\", \"hi\")\n"},
    A = run([Src], "A"),
    ok_rc(A),
    has(A, "yes"),
    B = run([Src], "B"),
    ok_rc(B),
    has(B, "no").

%% F66.10 — any other hole needs a BIF the BEAM will not run in a guard, so it
%% is refused at all three guard sites: a clause, a switch arm, and a
%% comprehension's `when`.
an_int_hole_in_a_guard_is_refused_test() ->
    [begin
         Got = diagnose([{"Gi.bs", "module Gi\n" ++ Src}]),
         bad_rc(Got),
         tagged(Got, "interp_in_guard")
     end || Src <- ["public atom Is(string s, int n)\n"
                    "Is(s, n) when s == $\"{n}\" -> :yes\n"
                    "Is(s, n) -> :no\n",
                    "public atom Is(string s, int n)\n"
                    "Is(s, n) -> s switch { t when t == $\"{n}\" => :yes, _ => :no }\n",
                    "public list<string> Is(list<string> ss, int n)\n"
                    "Is(ss, n) -> [t for t in ss when t == $\"{n}\"]\n"]].

%% F66.11 — a template's shape is checked where it is lexed: an empty hole, a
%% lone brace and an unclosed template are refused by name.
a_malformed_template_is_refused_test() ->
    [begin
         Got = compile([{"Mal.bs",
                         "module Mal\n"
                         "public string F(int n)\n"
                         "F(n) -> " ++ T ++ "\n"}]),
         bad_rc(Got),
         has(Got, "template")
     end || T <- ["$\"{}\"", "$\"a}b\"", "$\"a{n\"", "$\"open"]].

%% F66.12 — a hole is an expression: one that does not parse is a syntax
%% error, and a name it reads must be bound.
a_hole_is_an_expression_test() ->
    Syntax = compile([{"Hx.bs",
                       "module Hx\n"
                       "public string F(int n)\n"
                       "F(n) -> $\"{n +}\"\n"}]),
    bad_rc(Syntax),
    has(Syntax, "syntax error"),
    %% The hole's tokens run out before its expression does, which yecc would
    %% print as "before: " and nothing; the message says where it stopped.
    has(Syntax, "the hole ends before its expression does"),
    Unbound = diagnose([{"Hu.bs",
                         "module Hu\n"
                         "public string F(int n)\n"
                         "F(n) -> $\"{m}\"\n"}]),
    bad_rc(Unbound),
    tagged(Unbound, "unbound_variable").

%% F66.13 — text that is not valid UTF-8 is refused as a plain literal's is.
invalid_utf8_text_is_refused_test() ->
    Got = compile([{"Utf.bs",
                    "module Utf\n"
                    "public string F(int n)\n"
                    "F(n) -> $\"a" ++ [255] ++ "{n}\"\n"}]),
    bad_rc(Got),
    has(Got, "not valid UTF-8").

%% F66.14 — the model key is one binary construction and calls nothing; the
%% receipt line converts its `int` and atom holes with the BEAM's own BIFs.
it_lowers_to_one_binary_test() ->
    Key = [F || F = {function, _, 'ModelKey', 1, _}
                    <- forms([evidence("")], "Evidence")],
    KeyNodes = flatten(Key),
    ?assertMatch([_], [N || N = {bin, _, _} <- KeyNodes]),
    Converts = [integer_to_binary, float_to_binary, atom_to_binary],
    ?assertEqual([], [N || N = {call, _, {remote, _, _, {atom, _, F}}, _} <- KeyNodes,
                           lists:member(F, Converts)]),
    LineNodes = flatten([F || F = {function, _, 'Line', 1, _}
                                  <- forms([receipts("")], "Receipts")]),
    Called = [F || {call, _, {remote, _, {atom, _, erlang}, {atom, _, F}}, _} <- LineNodes],
    ?assertEqual(2, length([F || F <- Called, F =:= integer_to_binary])),
    ?assertEqual(1, length([F || F <- Called, F =:= atom_to_binary])).

%% F66.15 — the new diagnostics print the same term in one VM or many (ENG-349).
the_term_channel_is_the_same_in_a_batch_test_() ->
    {timeout, 120, fun the_term_channel_is_the_same_in_a_batch/0}.

the_term_channel_is_the_same_in_a_batch() ->
    Root = bs_test_support:fixture_root(),
    Hole = bs_test_support:place(Root, "h.bs",
                                 "module Ho\nrecord Money { Pence: int }\n"
                                 "public string F(Money m)\nF(m) -> $\"{m}\"\n"),
    InGuard = bs_test_support:place(Root, "g.bs",
                                    "module Ig\npublic atom F(string s, int n)\n"
                                    "F(s, n) when s == $\"{n}\" -> :yes\nF(s, n) -> :no\n"),
    Entries = [{Id, ["--diagnostics", "term", "--src-root", Root, "-o",
                     filename:join(Root, "o" ++ Id), P]}
               || {Id, P} <- [{"interp_hole", Hole}, {"interp_in_guard", InGuard}]],
    Manifest = filename:join(Root, "batch.manifest"),
    ok = file:write_file(Manifest,
                         [["entry ", Id, "\n", [["arg ", A, "\n"] || A <- Args], "end\n\n"]
                          || {Id, Args} <- Entries]),
    Results = filename:join(Root, "results"),
    {0, ""} = bs_test_support:run_cli_result("--batch " ++ Manifest ++ " " ++ Results),
    [begin
         {_, Out, _} = bs_test_support:run_cli_split_result(
                         lists:flatten(lists:join(" ", ["'" ++ A ++ "'" || A <- Args]))),
         {ok, Batch} = file:read_file(filename:join(Results, Id ++ ".stdout")),
         %% Each entry's id is the tag it provokes, so a parity that holds only
         %% because both runs failed alike is not a pass.
         tagged(Out, Id),
         ?assertEqual({Id, Out}, {Id, binary_to_list(Batch)})
     end || {Id, Args} <- Entries].

%% F66.16 — a plain string literal is unchanged: a `{` in it is a character,
%% not a hole.
a_plain_string_keeps_its_braces_test() ->
    Got = run([{"Plain.bs",
                "module Plain\n"
                "public string Demo()\n"
                "Demo() -> \"{n}\"\n"}],
              "Demo"),
    ok_rc(Got),
    has(Got, "\"{n}\"").

%% F66.17 — a module is a directory, so two files may hold a hole at the same
%% line and column; each keeps its own part. Keyed by position alone, the
%% `string` hole's note overwrote the `int` hole's and `A` crashed `badarg`.
sibling_files_keep_their_own_holes_test() ->
    Got = run([{"a.bs",
                "module Two\n"
                "public string A(int n)\n"
                "A(n) -> $\"{n}\"\n"
                "public string Demo()\n"
                "Demo() -> A(7)\n"},
               {"b.bs",
                "module Two\n"
                "public string B(string n)\n"
                "B(n) -> $\"{n}\"\n"}],
              "Demo"),
    ok_rc(Got),
    has(Got, "\"7\"").

%% F66.18 — what a hole's own source gets wrong is refused where the template
%% is lexed: a character no token spells, an unknown escape, and text after
%% the last hole that is not UTF-8.
a_holes_lex_error_is_refused_test() ->
    [begin
         Got = compile([{"Lx.bs",
                         "module Lx\n"
                         "public string F(int n)\n"
                         "F(n) -> " ++ T ++ "\n"}]),
         bad_rc(Got),
         has(Got, Says)
     end || {T, Says} <- [{"$\"{n # 1}\"", "in a template's hole"},
                          {"$\"a\\q{n}\"", "unknown escape"},
                          {"$\"{n}b" ++ [255] ++ "\"", "not valid UTF-8"}]].

%% F66.19 — a hole whose type is uninhabited adds no refusal of its own: it
%% never prints, and `raise` has already said why.
an_uninhabited_hole_adds_nothing_test() ->
    Got = run([{"Rz.bs",
                "module Rz\n"
                "public string F(int n)\n"
                "F(n) -> $\"n is {raise :boom}\"\n"
                "public string Demo()\n"
                "Demo() -> F(1)\n"}],
              "Demo"),
    ?assertEqual(nomatch, string:find(Got, "interp_hole")),
    has(Got, "boom").

flatten(Forms) -> lists:flatten([walk(F) || F <- Forms]).

walk(T) when is_tuple(T) -> [T | walk(tuple_to_list(T))];
walk(L) when is_list(L)  -> [walk(X) || X <- L];
walk(_)                  -> [].
