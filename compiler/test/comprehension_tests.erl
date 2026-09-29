%%% Scenarios: compiler/features/F65-comprehensions.md
%%% F65 — list comprehensions, `[r for Receipt r in cs]`: a generator's pattern
%%% narrows the element type and skips what it refuses (ticket 114; ENG-571).
-module(comprehension_tests).

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

%% Ticket 114's program: a batch of charges, each settled or declined.
billing(Rest) ->
    {"Billing.bs",
     "module Shop.Billing\n"
     "record Receipt { OrderId: int, Pence: int }\n"
     "type Charge = Receipt | (:error, string)\n"
     ++ Rest}.

charges() ->
    "[Receipt { OrderId = 1, Pence = 500 }, (:error, \"declined\"),"
    " Receipt { OrderId = 3, Pence = 12500 }]".

%% F65.1 — a generator's pattern narrows the element type, so the result is
%% the declared `list<Receipt>`, and it skips the declined charge.
a_pattern_narrows_and_skips_test() ->
    Got = run([billing("public list<Receipt> Settled(list<Charge> cs)\n"
                       "Settled(cs) -> [r for Receipt r in cs]\n"
                       "public list<int> Demo()\n"
                       "Demo() -> Settled(" ++ charges() ++ ") |> List.Map(r => r.OrderId)\n")],
              "Demo"),
    ok_rc(Got),
    has(Got, "[1, 3]").

%% F65.2 — a pattern destructures as it filters.
a_pattern_destructures_test() ->
    Got = run([billing("public list<string> Declines(list<Charge> cs)\n"
                       "Declines(cs) -> [reason for (:error, reason) in cs]\n"
                       "public list<string> Demo()\n"
                       "Demo() -> Declines(" ++ charges() ++ ")\n")],
              "Demo"),
    ok_rc(Got),
    has(Got, "[\"declined\"]").

%% F65.3 — a `when` guard after the generator filters under its bindings.
a_guard_filters_test() ->
    Got = run([billing("public list<Receipt> Large(list<Charge> cs)\n"
                       "Large(cs) -> [r for Receipt r in cs when r.Pence >= 10000]\n"
                       "public list<int> Demo()\n"
                       "Demo() -> Large(" ++ charges() ++ ") |> List.Map(r => r.OrderId)\n")],
              "Demo"),
    ok_rc(Got),
    has(Got, "[3]").

%% F65.4 — the part prefix is legal at a generator's top, and narrows.
a_part_prefix_narrows_test() ->
    Got = run([{"Fr.bs",
                "module Fr\n"
                "public list<float> Fractional(list<int | float> amounts)\n"
                "Fractional(amounts) -> [f for float f in amounts]\n"
                "public list<float> Demo()\n"
                "Demo() -> Fractional([1, 2.5, 3])\n"}],
              "Demo"),
    ok_rc(Got),
    has(Got, "[2.5]").

%% F65.5 — a later generator reads an earlier binding, and a guard follows it.
two_generators_test() ->
    Got = run([{"Orders.bs",
                "module Shop.Orders\n"
                "record Line { Sku: string, Qty: int }\n"
                "record Order { Id: int, Lines: list<Line> }\n"
                "public list<(int, string)> Skus(list<Order> os)\n"
                "Skus(os) -> [(o.Id, l.Sku) for Order o in os for Line l in o.Lines"
                " when l.Qty > 0]\n"
                "public list<(int, string)> Demo()\n"
                "Demo() -> Skus([Order { Id = 1, Lines = [Line { Sku = \"a\", Qty = 1 },"
                " Line { Sku = \"b\", Qty = 0 }] },"
                " Order { Id = 2, Lines = [Line { Sku = \"c\", Qty = 2 }] }])\n"}],
              "Demo"),
    ok_rc(Got),
    has(Got, "[(1, \"a\"), (2, \"c\")]").

%% F65.6 — a comprehension is an expression, so one may be another's head.
a_nested_comprehension_test() ->
    Got = run([{"Grid.bs",
                "module Grid\n"
                "public list<list<int>> Doubled(list<list<int>> rows)\n"
                "Doubled(rows) -> [[x * 2 for x in row] for row in rows]\n"
                "public list<list<int>> Demo()\n"
                "Demo() -> Doubled([[1, 2], [3]])\n"}],
              "Demo"),
    ok_rc(Got),
    has(Got, "[[2, 4], [6]]").

%% F65.7 — a call in the head reaches another module's export.
a_head_calls_another_module_test() ->
    Got = run([billing("using Shop.Tax\n"
                       "public list<int> Vats(list<Charge> cs)\n"
                       "Vats(cs) -> [Vat(r.Pence) for Receipt r in cs]\n"
                       "public list<int> Demo()\n"
                       "Demo() -> Vats(" ++ charges() ++ ")\n"),
               {"Tax.bs", "module Shop.Tax\npublic int Vat(int p)\nVat(p) -> p / 5\n"}],
              "Demo"),
    ok_rc(Got),
    has(Got, "[100, 2500]").

refunds() ->
    billing("record Refund { OrderId: int, Pence: int }\n"
            "public list<Refund> Refunds(list<Charge> cs)\n"
            "Refunds(cs) -> [r for Refund r in cs]\n"
            "public list<Refund> Demo()\n"
            "Demo() -> Refunds(" ++ charges() ++ ")\n").

%% F65.8 — a pattern no element can match warns, as a vacuous arm does, and
%% the program still compiles.
a_vacuous_generator_warns_test() ->
    Diag = diagnose([refunds()]),
    ok_rc(Diag),
    tagged(Diag, "vacuous_generator"),
    Got = run([refunds()], "Demo"),
    ok_rc(Got),
    %% The result's own line: the warning's text says "always []" too.
    has(Got, "\n[]\nrc:0").

%% F65.9 — a guard keeps guard rules: it cannot call a user function.
a_guard_cannot_call_test() ->
    Got = diagnose([billing("private bool Big(int p)\n"
                            "Big(p) -> p >= 10000\n"
                            "public list<Receipt> Large(list<Charge> cs)\n"
                            "Large(cs) -> [r for Receipt r in cs when Big(r.Pence)]\n")]),
    bad_rc(Got),
    tagged(Got, "call_in_guard").

%% F65.10 — the guard-level operator refusals reach a comprehension's guard.
a_guard_refuses_mixed_operands_test() ->
    Got = diagnose([{"Pos.bs",
                     "module Pos\n"
                     "public list<float> Positive(list<float> xs)\n"
                     "Positive(xs) -> [f for f in xs when f > 0]\n"}]),
    bad_rc(Got),
    tagged(Got, "mixed_operands").

%% F65.11 — nothing bound inside a comprehension is visible after it.
a_binder_does_not_leak_test() ->
    Got = diagnose([billing("public int Count(list<Charge> cs)\n"
                            "Count(cs) -> List.Length([r for Receipt r in cs]) + r.Pence\n")]),
    bad_rc(Got),
    tagged(Got, "unbound_variable").

%% F65.12 — a generator may not rebind a name already bound.
a_generator_cannot_rebind_test() ->
    Got = diagnose([billing("public list<Receipt> Again(Receipt r, list<Charge> cs)\n"
                            "Again(r, cs) -> [r for Receipt r in cs]\n")]),
    bad_rc(Got),
    tagged(Got, "rebinding").

%% F65.13 — a generator draws from a list; an `int` or a `term` is refused.
a_source_must_be_a_list_test() ->
    Int = diagnose([{"Bad.bs",
                     "module Bad\n"
                     "public list<int> Each(int n)\n"
                     "Each(n) -> [x for x in n]\n"}]),
    bad_rc(Int),
    tagged(Int, "generator_not_list"),
    Term = diagnose([{"Worse.bs",
                      "module Worse\n"
                      "public list<term> Each(term t)\n"
                      "Each(t) -> [x for x in t]\n"}]),
    bad_rc(Term),
    tagged(Term, "generator_not_list").

%% F65.14 — the BEAM has no comprehension in a guard, as it has no `case`.
a_comprehension_in_a_guard_is_refused_test() ->
    Got = diagnose([{"Gd.bs",
                     "module Gd\n"
                     "public int Empty(list<int> xs)\n"
                     "Empty(xs) when [x for x in xs] == [] -> 0\n"
                     "Empty(xs) -> 1\n"}]),
    bad_rc(Got),
    tagged(Got, "comprehension_in_guard"),
    %% A switch arm's guard is checked by `arms/10`, not the clause walk.
    Arm = diagnose([{"Ga.bs",
                     "module Ga\n"
                     "public int Size(list<int> xs)\n"
                     "Size(xs) -> xs switch {\n"
                     "    ys when [y for y in ys] == [] => 0,\n"
                     "    _ => 1\n"
                     "}\n"}]),
    bad_rc(Arm),
    tagged(Arm, "comprehension_in_guard").

%% F65.15 — one Erlang comprehension, generating from the parameter.
it_lowers_to_one_comprehension_test() ->
    Forms = forms([billing("public list<Receipt> Settled(list<Charge> cs)\n"
                           "Settled(cs) -> [r for Receipt r in cs]\n")],
                  "Shop.Billing"),
    [Settled] = [F || F = {function, _, 'Settled', 1, _} <- Forms],
    Nodes = flatten([Settled]),
    ?assertMatch([_], [N || N = {lc, _, _, [{generate, _, _, {var, _, _}}]} <- Nodes]),
    ?assertEqual([], [N || N = {'case', _, _, _} <- Nodes]).

%% F65.16 — the new diagnostics print the same term in one VM or many (ENG-349).
the_term_channel_is_the_same_in_a_batch_test_() ->
    {timeout, 120, fun the_term_channel_is_the_same_in_a_batch/0}.

the_term_channel_is_the_same_in_a_batch() ->
    Root = bs_test_support:fixture_root(),
    Vacuous = bs_test_support:place(Root, "v.bs",
                                    "module Va\nrecord A { X: int }\nrecord B { X: int }\n"
                                    "public list<B> F(list<A> xs)\nF(xs) -> [b for B b in xs]\n"),
    NotList = bs_test_support:place(Root, "n.bs",
                                    "module Nl\npublic list<int> F(int n)\n"
                                    "F(n) -> [x for x in n]\n"),
    InGuard = bs_test_support:place(Root, "g.bs",
                                    "module Ig\npublic int F(list<int> xs)\n"
                                    "F(xs) when [x for x in xs] == [] -> 0\nF(xs) -> 1\n"),
    Entries = [{Id, ["--diagnostics", "term", "--src-root", Root, "-o",
                     filename:join(Root, "o" ++ Id), P]}
               || {Id, P} <- [{"vacuous_generator", Vacuous}, {"generator_not_list", NotList},
                              {"comprehension_in_guard", InGuard}]],
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

%% F65.17 — a map pattern over `map<K, V>` elements is deferred in a generator
%% as in a head, and the refusal does not claim exhaustiveness for it.
a_map_pattern_is_deferred_in_a_generator_test() ->
    Src = [{"Mp.bs",
            "module Mp\n"
            "public list<int> Values(list<map<string, int>> ms)\n"
            "Values(ms) -> [v for { \"a\": v } in ms]\n"}],
    Term = diagnose(Src),
    bad_rc(Term),
    tagged(Term, "map_pattern_deferred"),
    has(Term, "site => generator"),
    {Root, Main} = in_dir(Src),
    Human = bs_test_support:run_cli("--src-root " ++ Root ++ " " ++ Main),
    has(Human, "matching one in a generator is not built"),
    ?assertEqual(nomatch, string:find(Human, "cannot be proved exhaustive")).

%% F65.18 — `== n` in a generator matches the bound value. An Erlang
%% generator binds its pattern's names fresh, so the emitter must not write the
%% outer name there.
an_equality_pattern_matches_the_bound_value_test() ->
    Src = {"Eq.bs",
           "module Eq\n"
           "public list<int> Hits(int n, list<int> xs)\n"
           "Hits(n, xs) -> [1 for == n in xs]\n"
           "public list<(int, int)> Pairs(list<int> xs, list<int> ys)\n"
           "Pairs(xs, ys) -> [(x, x) for x in xs for == x in ys]\n"
           "public list<int> One()\n"
           "One() -> Hits(2, [1, 2, 3])\n"
           "public list<(int, int)> Two()\n"
           "Two() -> Pairs([1, 2, 3], [2, 4])\n"},
    One = run([Src], "One"),
    ok_rc(One),
    has(One, "[1]"),
    ?assertEqual(nomatch, string:find(One, "[1, 1")),
    ?assertEqual(nomatch, string:find(One, "shadowed")),
    Two = run([Src], "Two"),
    ok_rc(Two),
    has(Two, "[(2, 2)]"),
    %% Nested in a tuple, as the review measured it.
    Nested = run([{"Nm.bs",
                   "module Nm\n"
                   "public list<string> Named(int id, list<(int, string)> ps)\n"
                   "Named(id, ps) -> [s for (== id, s) in ps]\n"
                   "public list<string> Demo()\n"
                   "Demo() -> Named(1, [(1, \"a\"), (2, \"b\"), (1, \"c\")])\n"}],
                 "Demo"),
    ok_rc(Nested),
    has(Nested, "[\"a\", \"c\"]").

%% F65.19 — two generators' lowered variables do not collide.
two_relational_generators_test() ->
    Got = run([{"Rel.bs",
                "module Rel\n"
                "public list<int> Both(list<int> xs, list<int> ys)\n"
                "Both(xs, ys) -> [1 for >= 0 in xs for >= 0 in ys]\n"
                "public list<int> Demo()\n"
                "Demo() -> Both([1, -1], [2])\n"}],
              "Demo"),
    ok_rc(Got),
    has(Got, "[1]"),
    ?assertEqual(nomatch, string:find(Got, "shadowed")).

%% F65.20 — a generator's pattern may not bind one name twice.
a_generator_binds_a_name_once_test() ->
    Got = diagnose([{"Dup.bs",
                     "module Dup\n"
                     "public list<int> Same(list<(int, int)> ps)\n"
                     "Same(ps) -> [x for (x, x) in ps]\n"}]),
    bad_rc(Got),
    tagged(Got, "rebinding").

%% F65.21 — a relational pattern nested in a generator's or an arm's tuple is
%% refused as a head's is. A path cannot tell a head parameter from a subject's
%% tuple element, so the refusal is structural, as the part prefix's is.
a_nested_relational_pattern_is_refused_test() ->
    Gen = diagnose([{"Ng.bs",
                     "module Ng\n"
                     "public list<int> Kept(list<(int, int)> ps)\n"
                     "Kept(ps) -> [n for (>= 0, n) in ps]\n"}]),
    bad_rc(Gen),
    tagged(Gen, "relational_pattern_nested"),
    Arm = diagnose([{"Na.bs",
                     "module Na\n"
                     "public int Kept((int, int) p)\n"
                     "Kept(p) -> p switch {\n"
                     "    (>= 0, n) => n,\n"
                     "    _ => 0\n"
                     "}\n"}]),
    bad_rc(Arm),
    tagged(Arm, "relational_pattern_nested").

%% F65.22 — a `when` narrows the generator before it, as an arm's guard narrows
%% its pattern, so the result is the refined list its signature declares.
a_guard_narrows_its_generator_test() ->
    Got = run([{"Keep.bs",
                "module Keep\n"
                "type NonNegative = int where value >= 0\n"
                "public list<NonNegative> Kept(list<int> xs)\n"
                "Kept(xs) -> [n for int n in xs when n >= 0]\n"
                "public list<NonNegative> Demo()\n"
                "Demo() -> Kept([-1, 0, 3])\n"}],
              "Demo"),
    ok_rc(Got),
    has(Got, "[0, 3]").

%% F65.23 — each `when` narrows what the ones before it left, and a later
%% generator keeps an earlier generator's narrowing.
guards_narrow_in_turn_test() ->
    Chained = run([{"Dg.bs",
                    "module Dg\n"
                    "type Digit = int where value >= 0 and value <= 9\n"
                    "public list<Digit> Digits(list<int> xs)\n"
                    "Digits(xs) -> [n for int n in xs when n >= 0 when n <= 9]\n"
                    "public list<Digit> Demo()\n"
                    "Demo() -> Digits([-1, 0, 3, 9, 10])\n"}],
                  "Demo"),
    ok_rc(Chained),
    has(Chained, "[0, 3, 9]"),
    Each = run([{"Gr.bs",
                 "module Gr\n"
                 "type NonNegative = int where value >= 0\n"
                 "type Small = int where value <= 9\n"
                 "public list<(NonNegative, Small)> Grid(list<int> xs, list<int> ys)\n"
                 "Grid(xs, ys) -> [(n, m) for int n in xs when n >= 0"
                 " for int m in ys when m <= 9]\n"
                 "public list<(NonNegative, Small)> Demo()\n"
                 "Demo() -> Grid([-1, 2], [5, 10])\n"}],
               "Demo"),
    ok_rc(Each),
    has(Each, "[(2, 5)]").

%% F65.24 — a guard that narrows nothing still compiles and filters.
a_guard_that_narrows_nothing_compiles_test() ->
    Got = run([{"Rs.bs",
                "module Rs\n"
                "public list<(int, int)> Rising(list<int> xs, list<int> ys)\n"
                "Rising(xs, ys) -> [(x, y) for int x in xs for int y in ys when x < y]\n"
                "public list<(int, int)> Demo()\n"
                "Demo() -> Rising([1, 3], [2])\n"}],
              "Demo"),
    ok_rc(Got),
    has(Got, "[(1, 2)]").

%% F65.25 — a guard reading two generators' binders narrows neither: either
%% side of an `or` may admit the pair, so `y` is not narrowed by `y >= 0`.
a_guard_across_generators_does_not_narrow_test() ->
    Refused = diagnose([{"Ei.bs",
                         "module Ei\n"
                         "type NonNegative = int where value >= 0\n"
                         "public list<(int, NonNegative)> Either(list<int> xs, list<int> ys)\n"
                         "Either(xs, ys) -> [(x, y) for int x in xs for int y in ys"
                         " when x >= 0 or y >= 0]\n"}]),
    bad_rc(Refused),
    tagged(Refused, "return_not_declared"),
    %% The refusal is the truth: the pair with a negative `y` is kept.
    Got = run([{"Eo.bs",
                "module Eo\n"
                "public list<(int, int)> Either(list<int> xs, list<int> ys)\n"
                "Either(xs, ys) -> [(x, y) for int x in xs for int y in ys"
                " when x >= 0 or y >= 0]\n"
                "public list<(int, int)> Demo()\n"
                "Demo() -> Either([0], [-5])\n"}],
              "Demo"),
    ok_rc(Got),
    has(Got, "[(0, -5)]").

flatten(Forms) -> lists:flatten([walk(F) || F <- Forms]).

walk(T) when is_tuple(T) -> [T | walk(tuple_to_list(T))];
walk(L) when is_list(L)  -> [walk(X) || X <- L];
walk(_)                  -> [].
