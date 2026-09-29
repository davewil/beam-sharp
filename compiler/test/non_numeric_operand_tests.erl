%%% Scenarios: compiler/features/F67-non-numeric-operand.md
%%% F67 — `+ - * / %` refuse an operand with no `int` or `float` part (ticket
%%% 112 A4; ENG-551). Every test goes through `bsc`.
-module(non_numeric_operand_tests).

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

%% The prose channel: what the author reads, and what they paste from.
compile(Files) ->
    {Root, Main} = in_dir(Files),
    bs_test_support:run_cli("--src-root " ++ Root ++ " -o " ++ Root ++ "/out " ++ Main).

run(Files, Call) ->
    {Root, Main} = in_dir(Files),
    bs_test_support:run_cli("--src-root " ++ Root ++ " " ++ Main ++ " " ++ Call).

ok_rc(Out)       -> ?assertNotEqual(nomatch, string:find(Out, "rc:0")).
bad_rc(Out)      -> ?assertEqual(nomatch, string:find(Out, "rc:0")).
has(Out, S)      -> ?assertNotEqual(nomatch, string:find(Out, S)).
hasnt(Out, S)    -> ?assertEqual(nomatch, string:find(Out, S)).
tagged(Out, Tag) -> has(Out, "tag => " ++ Tag).

refused(Files) ->
    Got = diagnose(Files),
    bad_rc(Got),
    tagged(Got, "non_numeric_operand"),
    Got.

%% The template the prose advice prints on a line of its own, or `none`.
advised(Prose) ->
    case [string:trim(L) || L <- string:split(Prose, "\n", all),
                            string:prefix(string:trim(L, leading), "$\"") =/= nomatch] of
        [T]  -> T;
        []   -> none
    end.

%% Ticket 112's program: Signalbox's model key, as a C# reader writes it.
evidence() ->
    {"Evidence.bs",
     "module Evidence\n"
     "record ModelIdentity { Lab: string, Model: string, Harness: string }\n"
     "public string ModelKey(ModelIdentity id)\n"
     "ModelKey(id) -> id.Lab + \"/\" + id.Model + \"/\" + id.Harness\n"}.

%% F67.1 — the model key is refused at the operator, and the return check no
%% longer invents the `int` whose `string | int` signature compiled into a
%% `badarith` crash: that advice was the defect the ticket opened with.
the_model_key_is_refused_at_the_operator_test() ->
    Got = refused([evidence()]),
    %% One refusal for the chain: the `+`s after the first see an uninhabited
    %% operand and refuse nothing more.
    ?assertEqual(2, length(string:split(Got, "tag => non_numeric_operand", all))),
    has(Got, "op => '+'"),
    has(Got, "side => left"),
    has(Got, "type => \"string\""),
    hasnt(Got, "return_not_declared"),
    Prose = compile([evidence()]),
    hasnt(Prose, "string | int"),
    has(Prose, "Evidence.bs:4:24: error: `+` in ModelKey has `string` on its left").

%% F67.2 — the advice is the whole chain as one template, which compiles and
%% builds the key the chain meant.
the_advice_is_the_chain_as_a_template_test() ->
    Advice = advised(compile([evidence()])),
    ?assertEqual("$\"{id.Lab}/{id.Model}/{id.Harness}\"", Advice),
    Got = run([{"Evidence.bs",
                "module Evidence\n"
                "record ModelIdentity { Lab: string, Model: string, Harness: string }\n"
                "public string ModelKey(ModelIdentity id)\n"
                "ModelKey(id) -> " ++ Advice ++ "\n"
                "public string Demo()\n"
                "Demo() -> ModelKey(ModelIdentity { Lab = \"-\", Model = \"glm-5.2\","
                " Harness = \"opencode\" })\n"}],
              "Demo"),
    ok_rc(Got),
    has(Got, "\"-/glm-5.2/opencode\"").

%% F67.3 — ticket 112's table, row by row: each compiled and crashed, or was
%% silently false, before this.
two_strings_are_refused_test() ->
    Got = refused([{"Glue.bs", "module Glue\npublic int Glue(string a, string b)\n"
                               "Glue(a, b) -> a + b\n"}]),
    has(Got, "side => left").

an_atom_operand_is_refused_test() ->
    Got = refused([{"Bump.bs", "module Bump\npublic int Bump(atom a)\nBump(a) -> a + 1\n"}]),
    has(Got, "type => \"atom\""),
    has(Got, "repair => none").

%% The record is named as the author wrote it, as a template's hole names one,
%% not printed as the map it lowers to.
a_record_operand_is_refused_test() ->
    Src = [{"Rec.bs", "module Rec\nrecord Order { Id: int }\n"
                      "public int Bump(Order o)\nBump(o) -> o + 1\n"}],
    refused(Src),
    Prose = compile(Src),
    has(Prose, "`+` in Bump has `Order` on its left"),
    hasnt(Prose, "Kind").

two_lists_are_refused_test() ->
    Got = refused([{"Both.bs", "module Both\n"
                               "public list<int> Both(list<int> a, list<int> b)\n"
                               "Both(a, b) -> a - b\n"}]),
    has(Got, "op => '-'"),
    hasnt(Got, "return_not_declared").

%% F67.4 — all five operators, and a string on the right as well as the left.
every_arithmetic_operator_refuses_test() ->
    [begin
         Got = refused([{"Ops.bs", "module Ops\npublic int Op(string s)\n"
                                   "Op(s) -> 2 " ++ Op ++ " s\n"}]),
         has(Got, "op => '" ++ Op ++ "'"),
         has(Got, "side => right")
     end || Op <- ["+", "-", "*", "/", "%"]].

%% F67.5 — a guard is read, never typed, so the refusal is asked at each guard
%% site: a clause's, a switch arm's and a comprehension filter's. Each ran
%% before this and was silently false.
a_clause_guard_is_refused_test() ->
    refused([{"Big.bs", "module Big\npublic atom Big(string s)\n"
                        "Big(s) when s + 1 > 3 -> :big\nBig(s) -> :small\n"}]).

a_switch_arm_guard_is_refused_test() ->
    refused([{"Arm.bs", "module Arm\npublic atom Arm(string s)\n"
                        "Arm(s) -> s switch {\n"
                        "    x when x + 1 > 3 => :big,\n"
                        "    _ => :small\n"
                        "}\n"}]).

a_comprehension_filter_is_refused_test() ->
    refused([{"Kept.bs", "module Kept\npublic list<string> Kept(list<string> xs)\n"
                         "Kept(xs) -> [x for x in xs when x * 2 > 3]\n"}]).

%% F67.6 — the controls. An operand with a numeric part beside another part is
%% ticket 83's leave, and still compiles; `term` meets `int`; comparison is the
%% BEAM's term order and does not crash; a wholly numeric union stays F53's.
a_numeric_part_beside_another_still_compiles_test() ->
    ok_rc(compile([{"Maybe.bs", "module Maybe\npublic int Inc(int | :none a)\n"
                                "Inc(a) -> a + 1\n"}])).

a_term_operand_still_compiles_test() ->
    ok_rc(compile([{"Any.bs", "module Any\npublic int Inc(term a)\nInc(a) -> a + 1\n"}])).

%% A type variable meets `int`, since `T` may be `int`: the rule is "meets",
%% and `F(4)` ran before this and runs after it.
a_type_variable_operand_still_runs_test() ->
    Got = run([{"GenInt.bs", "module GenInt\npublic int F<T>(T a)\nF(a) -> a + 1\n"
                             "public int Demo()\nDemo() -> F(4)\n"}],
              "Demo"),
    ok_rc(Got),
    has(Got, "5").

a_comparison_over_strings_still_runs_test() ->
    Got = run([{"Less.bs", "module Less\npublic bool Less(string a, string b)\n"
                           "Less(a, b) -> a < b\n"}],
              "Less '\"a\"' '\"b\"'"),
    ok_rc(Got),
    has(Got, ":true").

a_numeric_union_stays_its_own_refusal_test() ->
    Got = diagnose([{"Owed.bs", "module Owed\npublic int Owed(int | float amount)\n"
                                "Owed(a) -> a * 100\n"}]),
    tagged(Got, "numeric_union_operand"),
    hasnt(Got, "non_numeric_operand").

%% F67.7 — a hole takes an `int` as it stands, so a string then a number is a
%% template too, and it prints what C#'s `+` would have built.
a_label_and_a_number_become_one_template_test() ->
    Src = fun(Body) -> {"Label.bs", "module Label\npublic string Label(int n)\n"
                                    "Label(n) -> " ++ Body ++ "\n"
                                    "public string Demo()\nDemo() -> Label(7)\n"} end,
    Advice = advised(compile([Src("\"n=\" + n")])),
    ?assertEqual("$\"n={n}\"", Advice),
    Got = run([Src(Advice)], "Demo"),
    ok_rc(Got),
    has(Got, "\"n=7\"").

%% F67.8 — a literal brace in the joined text is doubled, as a template spells
%% it, so the pasted form builds the same string.
a_brace_in_the_text_is_doubled_test() ->
    Src = fun(Body) -> {"Brace.bs", "module Brace\npublic string Wrap(string s)\n"
                                    "Wrap(s) -> " ++ Body ++ "\n"
                                    "public string Demo()\nDemo() -> Wrap(\"x\")\n"} end,
    Advice = advised(compile([Src("\"{\" + s + \"}\"")])),
    ?assertEqual("$\"{{{s}}}\"", Advice),
    Got = run([Src(Advice)], "Demo"),
    ok_rc(Got),
    has(Got, "\"{x}\"").

%% F67.9 — where no template is the chain's meaning, none is printed, and the
%% advice names the form instead. `1 + n + "x"` adds before it joins in C#, a
%% record has no printing, and a call is not text this advice copies.
no_template_is_printed_where_none_is_the_meaning_test() ->
    Cases = [{"Lead", "public string F(int n)\nF(n) -> 1 + n + \"x\"\n"},
             {"Recd", "record Order { Id: int }\n"
                      "public string F(Order o)\nF(o) -> \"x\" + o\n"},
             {"Call", "public string G()\nG() -> \"g\"\n"
                      "public string F(string s)\nF(s) -> G() + s\n"}],
    [begin
         Prose = compile([{M ++ ".bs", "module " ++ M ++ "\n" ++ Src}]),
         bad_rc(Prose),
         ?assertEqual(none, advised(Prose)),
         has(Prose, "Build a string with a template, `$\"")
     end || {M, Src} <- Cases].

%% F67.11 — the diagnostic prints the same term in one VM or many (ENG-349):
%% `repair` is a key no other descriptor has, and it is printed with a
%% rendered template and with `none`.
the_term_channel_is_the_same_in_a_batch_test_() ->
    {timeout, 120, fun the_term_channel_is_the_same_in_a_batch/0}.

the_term_channel_is_the_same_in_a_batch() ->
    Root = bs_test_support:fixture_root(),
    {_, EvidenceSrc} = evidence(),
    Chain = bs_test_support:place(Root, "e.bs", EvidenceSrc),
    Atom = bs_test_support:place(Root, "b.bs",
                                 "module Bu\npublic int Bump(atom a)\nBump(a) -> a + 1\n"),
    Entries = [{Id, ["--diagnostics", "term", "--src-root", Root, "-o",
                     filename:join(Root, "o" ++ Id), P]}
               || {Id, P} <- [{"chain", Chain}, {"atom", Atom}]],
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
         %% Parity that holds only because both runs failed alike is no pass.
         tagged(Out, "non_numeric_operand"),
         ?assertEqual({Id, Out}, {Id, binary_to_list(Batch)})
     end || {Id, Args} <- Entries].

%% F67.12 — arithmetic over an uninhabited operand is uninhabited, whatever
%% refused it: after `mixed_operands` the outer `+` answered `int`, and the
%% return check refused an `int` the function never made.
a_refusal_below_an_operator_is_not_reported_again_test() ->
    Got = diagnose([{"Mix.bs", "module Mix\npublic float F(int a)\n"
                               "F(a) -> (a + 2.0) + 3\n"}]),
    bad_rc(Got),
    tagged(Got, "mixed_operands"),
    hasnt(Got, "return_not_declared").

%% F67.10 — the advice is for `+`, which is how C# joins strings; a string
%% under `*` is not a join, and nothing is offered.
only_plus_offers_a_template_test() ->
    Prose = compile([{"Times.bs", "module Times\npublic int T(string s)\nT(s) -> s * 2\n"}]),
    bad_rc(Prose),
    hasnt(Prose, "template").
