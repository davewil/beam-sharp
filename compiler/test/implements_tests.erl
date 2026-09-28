%%% Scenarios: compiler/features/F64-implements.md
%%% F64 — `implements Enumerable<int> for Node { … }`: a record's own module
%%% implements a compiler-known protocol, called as `Enumerable.Reduce(v, …)`
%%% (tickets 99 and 91 Q2; ENG-458).
-module(implements_tests).

-include_lib("eunit/include/eunit.hrl").

%%% Helpers: fixtures live under module paths in an isolated source root.

in_dir(Files) ->
    Root = bs_test_support:fixture_root(),
    Paths = [bs_test_support:place(Root, N, S) || {N, S} <- Files],
    {Root, hd(Paths)}.

compile_set(Files) ->
    {Root, Main} = in_dir(Files),
    bs_test_support:run_cli("--src-root " ++ Root ++ " -o " ++ Root ++ "/out " ++ Main).

run(Files, Call) ->
    {Root, Main} = in_dir(Files),
    bs_test_support:run_cli("--src-root " ++ Root ++ " " ++ Main ++ " " ++ Call).

api(Files) ->
    {Root, Main} = in_dir(Files),
    bs_test_support:run_cli("--src-root " ++ Root ++ " --api " ++ Main).

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
lacks(Out, S) -> ?assertEqual(nomatch, string:find(Out, S)).

%% Ticket 99's own program: a tree folds over itself, the recursive call inside
%% the block naming the operation it implements.
tree() ->
    {"Tree.bs",
     "module Shop.Tree\n"
     "record Node { Value: int, Kids: list<Node> }\n"
     "implements Enumerable<int> for Node {\n"
     "    Reduce(Node n, acc, f) -> List.Fold(n.Kids, f(acc, n.Value), (a, k) => Reduce(k, a, f))\n"
     "}\n"}.

report() ->
    {"Report.bs",
     "module Shop.Report\n"
     "using Shop.Tree\n"
     "public int Total(Node t)\n"
     "Total(t) -> Enumerable.Reduce(t, 0, (a, v) => a + v)\n"
     "public int Demo()\n"
     "Demo() -> Total(Node { Value = 1, Kids = [Node { Value = 2, Kids = [] },"
     " Node { Value = 3, Kids = [Node { Value = 4, Kids = [] }] }] })\n"}.

%% F64.1 — the program compiles, and the caller folds the tree through the
%% implementation in the record's own module.
a_record_folds_through_its_implementation_test() ->
    Got = run([report(), tree()], "Demo"),
    ok_rc(Got),
    has(Got, "10").

%% F64.2 — the implementation is an export the author did not write, named for
%% the protocol, and the caller reaches it only through that export.
the_implementation_is_a_protocol_named_export_test() ->
    Tree = forms([tree()], "Shop.Tree"),
    [Exports] = [Es || {attribute, _, export, Es} <- Tree],
    ?assert(lists:member({'bs@Enumerable@Reduce@Node', 3}, Exports)),
    Report = forms([report(), tree()], "Shop.Report"),
    Calls = [{M, F} || {call, _, {remote, _, {atom, _, M}, {atom, _, F}}, _}
                           <- flatten(Report)],
    ?assert(lists:member({'Shop.Tree', 'bs@Enumerable@Reduce@Node'}, Calls)).

%% F64.3 — `--api` publishes the module's operations; the implementation is not one.
the_implementation_is_not_an_operation_test() ->
    Got = api([tree()]),
    ok_rc(Got),
    lacks(Got, "bs@").

%% F64.4 — an implementation lives in the type's own module (99 Q4).
an_implementation_in_another_module_is_refused_test() ->
    Elsewhere = {"Report.bs",
                 "module Shop.Report\n"
                 "using Shop.Leaf\n"
                 "implements Enumerable<int> for Leaf {\n"
                 "    Reduce(Leaf l, acc, f) -> f(acc, l.Value)\n"
                 "}\n"},
    Leaf = {"Leaf.bs", "module Shop.Leaf\nrecord Leaf { Value: int }\n"},
    Got = compile_set([Elsewhere, Leaf]),
    bad_rc(Got),
    has(Got, "implements Enumerable for Leaf, which is not a record this module declares").

%% F64.5 — only a protocol the compiler knows can be implemented.
an_unknown_protocol_is_refused_test() ->
    Got = compile_set([{"Shapes.bs",
                        "module Shapes\n"
                        "record Circle { R: int }\n"
                        "implements Shape for Circle {\n"
                        "    Area(Circle c) -> c.R\n"
                        "}\n"}]),
    bad_rc(Got),
    has(Got, "implements Shape, which is not a protocol"),
    has(Got, "Enumerable").

%% F64.6 — the block implements the protocol's operations, all of them and no other.
an_operation_the_protocol_lacks_is_refused_test() ->
    Got = compile_set([{"Leaf.bs",
                        "module Leaf\n"
                        "record Leaf { Value: int }\n"
                        "implements Enumerable<int> for Leaf {\n"
                        "    Reduce(Leaf l, acc, f) -> f(acc, l.Value)\n"
                        "    Count(Leaf l) -> 1\n"
                        "}\n"}]),
    bad_rc(Got),
    has(Got, "Count is not an operation of Enumerable").

a_missing_operation_is_refused_test() ->
    Got = compile_set([{"Leaf.bs",
                        "module Leaf\n"
                        "record Leaf { Value: int }\n"
                        "implements Enumerable<int> for Leaf {\n"
                        "}\n"}]),
    bad_rc(Got),
    has(Got, "implements Enumerable for Leaf without Reduce").

%% F64.7 — `Enumerable` takes its element type.
a_missing_type_argument_is_refused_test() ->
    Got = compile_set([{"Leaf.bs",
                        "module Leaf\n"
                        "record Leaf { Value: int }\n"
                        "implements Enumerable for Leaf {\n"
                        "    Reduce(Leaf l, acc, f) -> f(acc, l.Value)\n"
                        "}\n"}]),
    bad_rc(Got),
    has(Got, "Enumerable takes 1 type argument").

%% F64.8 — the block's clauses are checked against the protocol's signature, and
%% the diagnostic names the operation as written, never the export.
a_clause_is_checked_against_the_protocol_test() ->
    Got = compile_set([{"Leaf.bs",
                        "module Leaf\n"
                        "record Leaf { Value: int }\n"
                        "implements Enumerable<int> for Leaf {\n"
                        "    Reduce(Leaf l, acc, f) -> f(acc, \"x\")\n"
                        "}\n"}]),
    bad_rc(Got),
    has(Got, "Reduce"),
    lacks(Got, "bs@").

%% F64.9 — over a union of implementing records the call dispatches on the tag.
a_union_dispatches_on_the_tag_test() ->
    Shapes = {"Shapes.bs",
              "module Shapes\n"
              "record Leaf { Value: int }\n"
              "record Pair { A: int, B: int }\n"
              "type Shape = Leaf | Pair\n"
              "implements Enumerable<int> for Leaf {\n"
              "    Reduce(Leaf l, acc, f) -> f(acc, l.Value)\n"
              "}\n"
              "implements Enumerable<int> for Pair {\n"
              "    Reduce(Pair p, acc, f) -> f(f(acc, p.A), p.B)\n"
              "}\n"
              "public int Sum(Shape s)\n"
              "Sum(s) -> Enumerable.Reduce(s, 0, (a, v) => a + v)\n"
              "public int Both()\n"
              "Both() -> Sum(Leaf { Value = 5 }) * 100 + Sum(Pair { A = 3, B = 4 })\n"},
    Got = run([Shapes], "Both"),
    ok_rc(Got),
    has(Got, "507").

%% F64.10 — a record whose module does not implement the protocol is refused at
%% the call, naming the declaration it lacks.
a_record_without_an_implementation_is_refused_test() ->
    Got = compile_set([{"Plain.bs",
                        "module Plain\n"
                        "record Leaf { Value: int }\n"
                        "public int Sum(Leaf l)\n"
                        "Sum(l) -> Enumerable.Reduce(l, 0, (a, v) => a + v)\n"}]),
    bad_rc(Got),
    has(Got, "Leaf does not implement Enumerable"),
    has(Got, "implements Enumerable<").

%% F64.11 — only the protocol's operations can be called under its name.
an_unknown_operation_is_refused_at_the_call_test() ->
    Got = compile_set([report_calling("Enumerable.Count(t)"), tree()]),
    bad_rc(Got),
    has(Got, "Count is not an operation of Enumerable").

report_calling(Expr) ->
    {"Report.bs",
     "module Shop.Report\n"
     "using Shop.Tree\n"
     "public int Total(Node t)\n"
     "Total(t) -> " ++ Expr ++ "\n"}.

%% F64.12 — an implementation holds clauses, and `index.bs` holds none (F15).
an_implementation_in_index_is_refused_test() ->
    Got = compile_set([{"index.bs",
                        "module Shop.Trees\n"
                        "record Node { Value: int }\n"
                        "implements Enumerable<int> for Node {\n"
                        "    Reduce(Node n, acc, f) -> f(acc, n.Value)\n"
                        "}\n"},
                       {"total.bs",
                        "module Shop.Trees\n"
                        "public int One()\n"
                        "One() -> 1\n"}]),
    bad_rc(Got),
    has(Got, "index.bs"),
    has(Got, "Enumerable").

%% F64.13 — found building F64.1: a recursive record could not name a
%% type-prefix pattern, so ticket 99's `Reduce(Node n, …)` was refused. Plain
%% functions had the same fault.
a_recursive_record_names_a_pattern_test() ->
    Got = run([{"Rec.bs",
                "module Rec\n"
                "record Node { Value: int, Kids: list<Node> }\n"
                "public int Top(Node t)\n"
                "Top(Node n) -> n.Value\n"
                "public int Demo()\n"
                "Demo() -> Top(Node { Value = 7, Kids = [] })\n"}], "Demo"),
    ok_rc(Got),
    has(Got, "7").

%% F64.14 — the same fault left a public function over a recursive record with
%% no boundary guard, so an untagged map ran as a `Node`. The guard is back.
a_recursive_record_parameter_is_guarded_test() ->
    Got = run([{"Rec.bs",
                "module Rec\n"
                "record Node { Value: int, Kids: list<Node> }\n"
                "public :ok Go(Node t)\n"
                "Go(n) -> :ok\n"}], "Go '#{value => 1, kids => []}'"),
    has(Got, "crashed: error:function_clause").

%%% From the review of the first cut.

leaf_mod(Extra) ->
    {"Q.bs",
     "module Q\n"
     "record Leaf { Value: int }\n"
     "implements Enumerable<int> for Leaf {\n"
     "    Reduce(Leaf l, acc, f) -> f(acc, l.Value)\n"
     "}\n" ++ Extra}.

%% F64.15 — a value wearing an implementing record's tag without its fields is
%% not that record, so it is not dispatched on.
a_tag_alone_is_not_the_record_test() ->
    Fake = compile_set([leaf_mod("type Fake = { Kind: :'Q.Leaf', Name: string }\n"
                                 "public int Sum(Fake s)\n"
                                 "Sum(s) -> Enumerable.Reduce(s, 0, (a, v) => a + v)\n")]),
    bad_rc(Fake),
    has(Fake, "which is no record that implements Enumerable"),
    Open = compile_set([leaf_mod("type Wide = { Kind: :'Q.Leaf', Value: int, .. }\n"
                                 "public int Sum(Wide s)\n"
                                 "Sum(s) -> Enumerable.Reduce(s, 0, (a, v) => a + v)\n")]),
    bad_rc(Open),
    has(Open, "which is no record that implements Enumerable").

%% F64.16 — a diagnostic about the implementation, or a call to it, names the
%% operation, never the export.
no_diagnostic_prints_the_export_test() ->
    Swapped = compile_set([{"Tree.bs",
                            "module Tree\n"
                            "record Node { Value: int, Kids: list<Node> }\n"
                            "implements Enumerable<int> for Node {\n"
                            "    Reduce(Node n, acc, f) -> List.Fold(n.Kids, f(acc, n.Value), (a, k) => Reduce(a, k, f))\n"
                            "}\n"}]),
    bad_rc(Swapped),
    has(Swapped, "Reduce"),
    lacks(Swapped, "bs@"),
    Guard = compile_set([{"G.bs",
                          "module G\n"
                          "record Leaf { Value: int }\n"
                          "implements Enumerable<int> for Leaf {\n"
                          "    Reduce(Leaf l, acc, f) when Reduce(l, acc, f) > 0 -> acc\n"
                          "    Reduce(Leaf l, acc, f) -> f(acc, l.Value)\n"
                          "}\n"}]),
    bad_rc(Guard),
    lacks(Guard, "bs@").

%% F64.17 — the remaining declaration refusals.
a_second_block_for_one_record_is_refused_test() ->
    Got = compile_set([leaf_mod("implements Enumerable<int> for Leaf {\n"
                                "    Reduce(Leaf l, acc, f) -> acc\n"
                                "}\n")]),
    bad_rc(Got),
    has(Got, "implements Enumerable for Leaf a second time").

an_operation_of_the_wrong_arity_is_refused_test() ->
    Got = compile_set([{"Leaf.bs",
                        "module Leaf\n"
                        "record Leaf { Value: int }\n"
                        "implements Enumerable<int> for Leaf {\n"
                        "    Reduce(Leaf l, acc) -> acc\n"
                        "}\n"}]),
    bad_rc(Got),
    has(Got, "Enumerable.Reduce takes 3 parameters, and this clause has 2").

a_value_that_is_no_record_is_refused_at_the_call_test() ->
    Got = compile_set([{"T.bs",
                        "module T\n"
                        "public int Sum(term t)\n"
                        "Sum(t) -> Enumerable.Reduce(t, 0, (a, v) => a + v)\n"}]),
    bad_rc(Got),
    has(Got, "on term, which is no record that implements Enumerable"),
    lacks(Got, "lambda").

%% F64.18 — ticket 99 Q4 writes the refused case qualified; it parses and is refused.
a_qualified_record_elsewhere_is_refused_test() ->
    Got = compile_set([{"Report.bs",
                        "module Shop.Report\n"
                        "using Shop.Leaf\n"
                        "implements Enumerable<int> for Shop.Leaf.Leaf {\n"
                        "    Reduce(Leaf l, acc, f) -> f(acc, l.Value)\n"
                        "}\n"},
                       {"Leaf.bs", "module Shop.Leaf\nrecord Leaf { Value: int }\n"}]),
    bad_rc(Got),
    has(Got, "implements Enumerable for Shop.Leaf.Leaf, which is not a record this module declares").

%% F64.19 — a protocol's name qualifies its operations, so no module may take it.
a_module_named_for_a_protocol_is_refused_test() ->
    Got = compile_set([{"Enumerable.bs",
                        "module Enumerable\n"
                        "public int One()\n"
                        "One() -> 1\n"}]),
    bad_rc(Got),
    has(Got, "`Enumerable` is a protocol, so no module may be called it"),
    lacks(Got, "inlines at the site").

%% F64.20 — `--api` refuses what a compile refuses, and does not advise marking
%% functions `public` in a module reached through a protocol.
the_query_mode_agrees_with_a_compile_test() ->
    Nope = api([{"Leaf.bs",
                 "module Leaf\n"
                 "record Leaf { Value: int }\n"
                 "implements Enumerable<Nope> for Leaf {\n"
                 "    Reduce(Leaf l, acc, f) -> acc\n"
                 "}\n"}]),
    bad_rc(Nope),
    has(Nope, "Nope"),
    Tree = api([tree()]),
    ok_rc(Tree),
    has(Tree, "Enumerable for Node"),
    lacks(Tree, "Mark the ones").

%% F64.21 — the new diagnostics print the same term in one VM or many (ENG-349).
the_term_channel_is_the_same_in_a_batch_test_() ->
    {timeout, 120, fun the_term_channel_is_the_same_in_a_batch/0}.

the_term_channel_is_the_same_in_a_batch() ->
    Root = bs_test_support:fixture_root(),
    Arity = bs_test_support:place(Root, "a.bs",
                                  "module Ar\nrecord Leaf { Value: int }\n"
                                  "implements Enumerable<int> for Leaf {\n"
                                  "    Reduce(Leaf l, acc) -> acc\n}\n"),
    Unknown = bs_test_support:place(Root, "u.bs",
                                    "module Un\nrecord Leaf { Value: int }\n"
                                    "implements Enumerable<int> for Leaf {\n"
                                    "    Reduce(Leaf l, acc, f) -> f(acc, l.Value)\n"
                                    "    Count(Leaf l) -> 1\n}\n"),
    Call = bs_test_support:place(Root, "c.bs",
                                 "module Ca\nrecord Leaf { Value: int }\n"
                                 "implements Enumerable<int> for Leaf {\n"
                                 "    Reduce(Leaf l, acc, f) -> f(acc, l.Value)\n}\n"
                                 "public int N(Leaf l)\nN(l) -> Enumerable.Count(l)\n"),
    Entries = [{Id, ["--diagnostics", "term", "--src-root", Root, "-o",
                     filename:join(Root, "o" ++ Id), P]}
               || {Id, P} <- [{"arity", Arity}, {"unknown", Unknown}, {"call", Call}]],
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
         ?assertNotEqual(nomatch, string:find(Out, "tag =>")),
         ?assertEqual({Id, Out}, {Id, binary_to_list(Batch)})
     end || {Id, Args} <- Entries].

%% F64.22 — the operation's name passed as a value is the implementation too,
%% and a return mismatch withholds a signature, since the protocol declares it.
the_operation_as_a_value_is_the_implementation_test() ->
    Got = compile_set([{"Val.bs",
                        "module Val\n"
                        "record Node { Value: int, Kids: list<Node> }\n"
                        "implements Enumerable<int> for Node {\n"
                        "    Reduce(Node n, acc, f) -> List.Fold(n.Kids, f(acc, n.Value),"
                        " (a, k) => Step(Reduce, k, a, f))\n"
                        "}\n"
                        "private int Step(fn(Node, int, fn(int, int) -> int) -> int r, Node k,"
                        " int a, fn(int, int) -> int f)\n"
                        "Step(r, k, a, f) -> r(k, a, f)\n"}]),
    bad_rc(Got),
    has(Got, "no signature is offered: the protocol declares this operation's"),
    lacks(Got, "nothing declares"),
    lacks(Got, "bs@").

%% F64.23 — a block's type argument is a declared type, so the union checks a
%% signature gets reach it, in a compile and in `--api` alike.
an_absorbed_member_in_a_type_argument_is_refused_test() ->
    Src = {"Ab.bs",
           "module Ab\n"
           "record Leaf { Value: atom }\n"
           "implements Enumerable<atom | :ok> for Leaf {\n"
           "    Reduce(Leaf l, acc, f) -> f(acc, l.Value)\n"
           "}\n"
           "public int Sum(Leaf l)\n"
           "Sum(l) -> Enumerable.Reduce(l, 0, (a, v) => a + 1)\n"},
    [begin
         bad_rc(Got),
         has(Got, "`:ok` is absorbed by `atom`"),
         has(Got, "in Enumerable<T>")
     end || Got <- [compile_set([Src]), api([Src])]].

%% F64.24 — inside a block the operation's name is the implementation only at
%% the operation's arity: `Reduce/2` is still the module's own function.
a_written_arity_names_the_module_function_test() ->
    Got = run([{"Fv.bs",
                "module Fv\n"
                "record Leaf { Value: int }\n"
                "implements Enumerable<int> for Leaf {\n"
                "    Reduce(Leaf l, acc, f) -> f(acc, Ap(Reduce/2, l.Value))\n"
                "}\n"
                "private int Reduce(int a, int b)\n"
                "Reduce(a, b) -> a + b\n"
                "private int Ap(fn(int, int) -> int g, int x)\n"
                "Ap(g, x) -> g(x, x)\n"
                "public int Demo()\n"
                "Demo() -> Enumerable.Reduce(Leaf { Value = 5 }, 0, (a, v) => a + v)\n"}],
              "Demo"),
    ok_rc(Got),
    has(Got, "10").

flatten(Forms) -> lists:flatten([walk(F) || F <- Forms]).

walk(T) when is_tuple(T) -> [T | walk(tuple_to_list(T))];
walk(L) when is_list(L)  -> [walk(X) || X <- L];
walk(_)                  -> [].
