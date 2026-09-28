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

flatten(Forms) -> lists:flatten([walk(F) || F <- Forms]).

walk(T) when is_tuple(T) -> [T | walk(tuple_to_list(T))];
walk(L) when is_list(L)  -> [walk(X) || X <- L];
walk(_)                  -> [].
