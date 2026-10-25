%%% Scenarios: compiler/features/F75-list-and-map-rows.md
%%% Each row is read at the boundary twice: what the call returns, and that the
%%% call site keeps the argument's types. A row typed at `term` would pass every
%%% value test here and fail every type test.
-module(standard_rows_tests).

-include_lib("eunit/include/eunit.hrl").

%%% Helpers

in_dir(Files) ->
    Root = bs_test_support:fixture_root(),
    Paths = [bs_test_support:place(Root, N, S) || {N, S} <- Files],
    {Root, hd(Paths)}.

compile_set_(Files) ->
    {Root, Main} = in_dir(Files),
    {Root, bs_test_support:run_cli("--src-root " ++ Root ++ " -o " ++ Root
                                   ++ "/out " ++ Main)}.

compile(Body) ->
    {_Root, Out} = compile_set_([caller(Body)]),
    Out.

run(Body, Call) ->
    {Root, Main} = in_dir([caller(Body)]),
    bs_test_support:run_cli("--src-root " ++ Root ++ " " ++ Main ++ " " ++ Call).

ok_rc(Out)  -> ?assert(string:find(Out, "rc:0") =/= nomatch).
bad_rc(Out) -> ?assert(string:find(Out, "rc:1") =/= nomatch).
has(Out, S) -> ?assert(string:find(Out, S) =/= nomatch).
value(Out)  -> string:trim(hd(string:split(Out, "\n"))).

caller(Body) -> {"P.bs", "module P\n" ++ Body}.

imports(Root, Beam) ->
    {ok, {_, [{imports, Is}]}} =
        beam_lib:chunks(Root ++ "/out/" ++ Beam ++ ".beam", [imports]),
    Is.

%%% List rows

%% F75.1 — each List row returns what its OTP function returns.
list_seq_counts_from_first_to_last_test() ->
    ?assertEqual("[1, 2, 3]",
                 value(run("public list<int> Go(int n)\n"
                           "Go(n) -> List.Seq(1, n)\n", "Go 3"))).

list_concat_appends_the_second_list_test() ->
    ?assertEqual("[1, 2, 7]",
                 value(run("public list<int> Go(int n)\n"
                           "Go(n) -> List.Concat([1, 2], [n])\n", "Go 7"))).

%% F75.2 — and keeps its argument's element types.
list_concat_joins_its_element_types_test() ->
    ok_rc(compile("public list<int | string> Go(list<int> xs, list<string> ys)\n"
                  "Go(xs, ys) -> List.Concat(xs, ys)\n")),
    bad_rc(compile("public list<int> Go(list<int> xs, list<string> ys)\n"
                   "Go(xs, ys) -> List.Concat(xs, ys)\n")).

list_zip_pairs_by_position_test() ->
    ?assertEqual("[(5, \"a\"), (2, \"b\")]",
                 value(run("public list<(int, string)> Go(int n)\n"
                           "Go(n) -> List.Zip([n, 2], [\"a\", \"b\"])\n", "Go 5"))).

list_zip_keeps_both_element_types_test() ->
    ok_rc(compile("public list<(int, string)> Go(list<int> xs, list<string> ys)\n"
                  "Go(xs, ys) -> List.Zip(xs, ys)\n")),
    bad_rc(compile("public list<(string, int)> Go(list<int> xs, list<string> ys)\n"
                   "Go(xs, ys) -> List.Zip(xs, ys)\n")).

list_contains_answers_membership_test() ->
    Body = "public bool Go(int n)\n"
           "Go(n) -> List.Contains([1, 2, 3], n)\n",
    ?assertEqual(":true", value(run(Body, "Go 2"))),
    ?assertEqual(":false", value(run(Body, "Go 9"))).

list_delete_removes_the_first_occurrence_test() ->
    ?assertEqual("[5, 1]",
                 value(run("public list<int> Go(int n)\n"
                           "Go(n) -> List.Delete([1, n, 1], 1)\n", "Go 5"))).

%% Deleting a value the list may hold does not widen the result.
list_delete_keeps_the_list_element_type_test() ->
    ok_rc(compile("public list<int> Go(list<int> xs, int n)\n"
                  "Go(xs, n) -> List.Delete(xs, n)\n")).

list_duplicate_repeats_a_value_test() ->
    ?assertEqual("[4, 4, 4]",
                 value(run("public list<int> Go(int n)\n"
                           "Go(n) -> List.Duplicate(n, 3)\n", "Go 4"))).

%%% Map rows

%% F75.3 — each Map row returns what its OTP function returns.
map_from_list_builds_a_typed_map_test() ->
    ?assertEqual("{\"a\" = 5}",
                 value(run("public map<string, int> Go(int n)\n"
                           "Go(n) -> Map.FromList([(\"a\", n)])\n", "Go 5"))).

map_to_list_keeps_key_and_value_types_test() ->
    ok_rc(compile("public list<(string, int)> Go(map<string, int> m)\n"
                  "Go(m) -> Map.ToList(m)\n")),
    ?assertEqual("[(\"a\", 5)]",
                 value(run("public list<(string, int)> Go(int n)\n"
                           "Go(n) -> Map.ToList(Map.FromList([(\"a\", n)]))\n", "Go 5"))).

map_put_adds_a_key_test() ->
    ?assertEqual("{\"a\" = 1, \"b\" = 5}",
                 value(run("public map<string, int> Go(int n)\n"
                           "Go(n) -> Map.Put(Map.FromList([(\"a\", 1)]), \"b\", n)\n",
                           "Go 5"))).

%% F75.4 — and keeps the map's key and value types.
map_put_keeps_the_map_type_test() ->
    ok_rc(compile("public map<string, int> Go(map<string, int> m, int n)\n"
                  "Go(m, n) -> Map.Put(m, \"k\", n)\n")).

%% The value joins the map's value type: `int | :x`, which `int` does not cover.
map_put_of_a_wider_value_widens_the_map_test() ->
    Out = compile("public map<string, int> Go(map<string, int> m)\n"
                  "Go(m) -> Map.Put(m, \"k\", :x)\n"),
    bad_rc(Out),
    has(Out, ":x").

map_remove_drops_a_key_test() ->
    ?assertEqual("{\"b\" = 2}",
                 value(run("public map<string, int> Go(int n)\n"
                           "Go(n) -> Map.Remove(Map.FromList([(\"a\", n), (\"b\", 2)]), \"a\")\n",
                           "Go 5"))).

map_has_answers_key_membership_test() ->
    Body = "public bool Go(int k)\n"
           "Go(k) -> Map.Has(Map.FromList([(1, \"a\")]), k)\n",
    ?assertEqual(":true", value(run(Body, "Go 1"))),
    ?assertEqual(":false", value(run(Body, "Go 2"))).

map_keys_and_values_keep_their_types_test() ->
    ok_rc(compile("public list<string> Ks(map<string, int> m)\n"
                  "Ks(m) -> Map.Keys(m)\n\n"
                  "public list<int> Vs(map<string, int> m)\n"
                  "Vs(m) -> Map.Values(m)\n")),
    ?assertEqual("[3]",
                 value(run("public list<int> Go(int n)\n"
                           "Go(n) -> Map.Values(Map.FromList([(\"a\", n)]))\n", "Go 3"))).

map_size_counts_keys_test() ->
    ?assertEqual("2",
                 value(run("public int Go(int n)\n"
                           "Go(n) -> Map.Size(Map.FromList([(1, n), (2, n)]))\n", "Go 3"))).

%% Elixir's order: the second map's value wins a shared key.
map_merge_prefers_the_second_map_test() ->
    ?assertEqual("{\"a\" = 9, \"b\" = 2}",
                 value(run("public map<string, int> Go(int n)\n"
                           "Go(n) -> Map.Merge(Map.FromList([(\"a\", 1), (\"b\", 2)]),\n"
                           "                   Map.FromList([(\"a\", n)]))\n", "Go 9"))).

map_take_keeps_only_the_named_keys_test() ->
    ?assertEqual("{\"a\" = 1}",
                 value(run("public map<string, int> Go(int n)\n"
                           "Go(n) -> Map.Take(Map.FromList([(\"a\", 1), (\"b\", n)]), [\"a\"])\n",
                           "Go 2"))).

map_drop_removes_the_named_keys_test() ->
    ?assertEqual("{\"b\" = 2}",
                 value(run("public map<string, int> Go(int n)\n"
                           "Go(n) -> Map.Drop(Map.FromList([(\"a\", 1), (\"b\", n)]), [\"a\"])\n",
                           "Go 2"))).

%% F75.4 — a field set built in place is a map: its keys are read as the algebra
%% reads a field's key, a string key as `string` and a name as its atom.
map_rows_read_a_field_set_built_in_place_test() ->
    ?assertEqual("[\"a\", \"b\"]",
                 value(run("public list<string> Go(int n)\n"
                           "Go(n) -> Map.Keys({ \"a\" = n, \"b\" = 2 })\n", "Go 1"))),
    ?assertEqual("[4, 2]",
                 value(run("public list<int> Go(int n)\n"
                           "Go(n) -> Map.Values({ \"a\" = n, \"b\" = 2 })\n", "Go 4"))),
    ok_rc(compile("public list<atom> Go(int n)\n"
                  "Go(n) -> Map.Keys({ A = n })\n")).

%% An open field set may hold `Kind`, so it is not a domain map: refused by
%% name, not crashed on, when a row solves a variable from it.
an_open_field_set_is_refused_by_a_polymorphic_row_test() ->
    Out = compile("public list<term> Go({ Name: string, .. } x)\n"
                  "Go(x) -> Map.Keys(x)\n"),
    bad_rc(Out),
    has(Out, "does not accept").

%% F75.5 — a record is not a domain map (F33), so a Map row refuses one.
a_map_row_refuses_a_record_test() ->
    Out = compile("record Order { Status: int }\n\n"
                  "public int Go(Order o)\n"
                  "Go(o) -> Map.Size(o)\n"),
    bad_rc(Out),
    has(Out, "does not accept").

%%% The artefact: every row is a call into OTP, and no B# module ships
%%%
%%% `Map.Put` and `Map.Has` are called here but not listed: erlc compiles
%%% `maps:put/3` and `maps:is_key/2` to instructions, so the import chunk never
%%% names them. Their values are tested above.

%% F75.6 — one program, every row read off the artefact.
every_row_is_a_call_into_otp_test() ->
    {Root, Out} = compile_set_([caller(
        "public int Go(int n)\n"
        "Go(n) -> List.Length(List.Concat(List.Seq(1, n), List.Duplicate(n, 2)))\n"
        "       + List.Length(List.Zip([n], [n])) + List.Length(List.Delete([n], n))\n"
        "       + Size(Map.Put(Map.FromList([(1, n)]), 2, n))\n\n"
        "private int Size(map<int, int> m)\n"
        "Size(m) -> Map.Size(Map.Merge(Map.Remove(m, 1), Map.Take(Map.Drop(m, [2]), [1])))\n"
        "         + List.Length(Map.Keys(m)) + List.Length(Map.Values(m))\n"
        "         + List.Length(Map.ToList(m))\n"
        "         + List.Length(List.Flatten([[1], [[2]]])) + List.Length(List.Insert([1], -1, 2))\n"
        "         + Map.Size(Map.Update(m, 1, 0, v => v + 1))\n\n"
        "public bool Has(int n)\n"
        "Has(n) -> List.Contains([n], n) and Map.Has(Map.FromList([(n, n)]), n)\n")]),
    ok_rc(Out),
    Is = imports(Root, "P"),
    ?assertEqual([], [M || {M, _, _} <- Is, M =:= 'List' orelse M =:= 'Map']),
    ?assertEqual([], [MFA || MFA <- [{lists, seq, 2}, {erlang, '++', 2}, {lists, zip, 3},
                {lists, member, 2}, {lists, delete, 2}, {lists, duplicate, 2},
                {maps, from_list, 1}, {maps, to_list, 1},
                {maps, remove, 2}, {maps, keys, 1},
                {maps, values, 1}, {erlang, map_size, 1}, {maps, merge, 2},
                {maps, with, 2}, {maps, without, 2},
                {lists, flatten, 1}, {maps, update_with, 4}],
                             not lists:member(MFA, Is)]).

%%% A user's polymorphic signature over `map<K, V>` (F45's erasure narrowed)

%% F75.7 — F45 erased a variable under `map<K, V>` to `term`, so the return here was
%% `map<term, term>` and refused against `map<string, int>`.
a_variable_under_a_domain_map_is_solved_test() ->
    ok_rc(compile("public map<string, int> Go(map<string, int> m)\n"
                  "Go(m) -> Same(m)\n\n"
                  "private map<K, V> Same<K, V>(map<K, V> m)\n"
                  "Same(m) -> m\n")).

%%% Ticket 118's answers: Elixir's behaviour, each time

%% F75.8 — `List.Zip` stops at the shorter list, as `Enum.zip/2` does.
list_zip_stops_at_the_shorter_list_test() ->
    ?assertEqual("[(5, :a)]",
                 value(run("public list<(int, atom)> Go(int n)\n"
                           "Go(n) -> List.Zip([n, 2], [:a])\n", "Go 5"))),
    {Root, Out} = compile_set_([caller("public list<(int, atom)> Go(int n)\n"
                                       "Go(n) -> List.Zip([n], [:a])\n")]),
    ok_rc(Out),
    ?assert(lists:member({lists, zip, 3}, imports(Root, "P"))).

%% F75.9 — `List.Flatten` flattens at every depth, and its result is the
%% element with every list member opened.
list_flatten_opens_every_depth_test() ->
    ?assertEqual("[5, 2, 3]",
                 value(run("public list<int> Go(int n)\n"
                           "Go(n) -> List.Flatten([[n, [2]], [3]])\n", "Go 5"))),
    ?assertEqual("[5]",
                 value(run("public list<int> Go(int n)\n"
                           "Go(n) -> List.Flatten([[], [n]])\n", "Go 5"))).

list_flatten_types_its_result_by_opening_every_list_test() ->
    ok_rc(compile("public list<int> Go(list<int | list<int | list<int>>> xs)\n"
                  "Go(xs) -> List.Flatten(xs)\n")),
    ok_rc(compile("type Tree = int | list<Tree>\n\n"
                  "public list<int> Go(list<Tree> ts)\n"
                  "Go(ts) -> List.Flatten(ts)\n")),
    Out = compile("public list<int> Go(list<list<string>> xs)\n"
                  "Go(xs) -> List.Flatten(xs)\n"),
    bad_rc(Out),
    has(Out, "string").

%% F75.10 — `List.Insert` takes `insert_at`'s index rules.
list_insert_takes_elixirs_index_rules_test() ->
    Body = "public list<int> Go(int i)\n"
           "Go(i) -> List.Insert([1, 2, 3], i, 9)\n",
    ?assertEqual("[1, 9, 2, 3]", value(run(Body, "Go 1"))),
    ?assertEqual("[1, 2, 3, 9]", value(run(Body, "Go 10"))),
    ?assertEqual("[1, 2, 3, 9]", value(run(Body, "Go -1"))),
    ?assertEqual("[1, 2, 9, 3]", value(run(Body, "Go -2"))),
    ?assertEqual("[9, 1, 2, 3]", value(run(Body, "Go -10"))).

list_insert_keeps_the_element_type_test() ->
    ok_rc(compile("public list<int> Go(list<int> xs, int n)\n"
                  "Go(xs, n) -> List.Insert(xs, 0, n)\n")),
    bad_rc(compile("public list<int> Go(list<int> xs)\n"
                   "Go(xs) -> List.Insert(xs, 0, :x)\n")).

%% F75.11 — `Map.Update` is `update/4`: the function on a present key, the
%% default on a missing one.
map_update_applies_or_inserts_the_default_test() ->
    Body = "public map<string, int> Go(string k)\n"
           "Go(k) -> Map.Update(Map.FromList([(\"a\", 1)]), k, 0, n => n + 1)\n",
    ?assertEqual("{\"a\" = 2}", value(run(Body, "Go '\"a\"'"))),
    ?assertEqual("{\"a\" = 1, \"b\" = 0}", value(run(Body, "Go '\"b\"'"))).

map_update_keeps_the_map_type_test() ->
    ok_rc(compile("public map<string, int> Go(map<string, int> m, string w)\n"
                  "Go(m, w) -> Map.Update(m, w, 1, n => n + 1)\n")).

%% The crash-on-missing form is one of 96 Q3's pairs and waits on ENG-324.
map_update_without_a_default_is_not_a_row_test() ->
    Out = compile("public map<string, int> Go(map<string, int> m, string w)\n"
                  "Go(m, w) -> Map.Update(m, w, n => n + 1)\n"),
    bad_rc(Out),
    has(Out, "Update").

%% F75.12 — a sought value no element or key could equal is refused, naming both.
a_sought_value_the_list_cannot_hold_is_refused_test() ->
    Out = compile("public bool Go(list<int> xs)\n"
                  "Go(xs) -> List.Contains(xs, \"x\")\n"),
    bad_rc(Out),
    has(Out, "List.Contains"),
    has(Out, "int"),
    has(Out, "\"x\"").

a_sought_key_the_map_cannot_hold_is_refused_test() ->
    [bad_rc(compile(B)) || B <-
        ["public bool Go(map<string, int> m)\nGo(m) -> Map.Has(m, 1)\n",
         "public map<string, int> Go(map<string, int> m)\nGo(m) -> Map.Remove(m, :k)\n",
         "public map<string, int> Go(map<string, int> m)\nGo(m) -> Map.Take(m, [1])\n",
         "public map<string, int> Go(map<string, int> m)\nGo(m) -> Map.Drop(m, [1])\n",
         "public list<int> Go(list<int> xs)\nGo(xs) -> List.Delete(xs, :x)\n"]].

%% The control: overlap is enough, and an empty collection says nothing.
a_sought_value_that_could_be_present_is_accepted_test() ->
    [ok_rc(compile(B)) || B <-
        ["public bool Go(list<int> xs, int n)\nGo(xs, n) -> List.Contains(xs, n)\n",
         "public bool Go(list<int | string> xs)\nGo(xs) -> List.Contains(xs, \"x\")\n",
         "public bool Go(list<term> xs)\nGo(xs) -> List.Contains(xs, \"x\")\n",
         "public bool Go(int n)\nGo(n) -> List.Contains([], n)\n",
         "public bool Go(map<string, int> m, term k)\nGo(m, k) -> Map.Has(m, k)\n",
         "public map<string, int> Go(map<string, int> m)\nGo(m) -> Map.Take(m, [\"a\"])\n"]].

%%% Inside a polymorphic function, `T` has no shape until a caller picks one
%%% (F45), so a row that opens or compares a `T` reads it at its extent.

%% F75.9 — flattening a `list<T>` may open a `T` that is a list, so it cannot
%% promise `list<T>` back; the caller's `[[n]]` would come back as `[n]`.
list_flatten_of_a_variable_element_does_not_promise_it_back_test() ->
    Out = compile("public list<list<int>> H(int n)\n"
                  "H(n) -> G([[n]])\n\n"
                  "private list<T> G<T>(list<T> xs)\n"
                  "G(xs) -> List.Flatten(xs)\n"),
    bad_rc(Out),
    has(Out, "G returns a value its signature does not declare").

%% F75.12 — a `T` may hold a string, so looking for one is not fixed in advance.
a_sought_value_against_a_variable_element_is_accepted_test() ->
    ok_rc(compile("public bool H(list<string> xs)\n"
                  "H(xs) -> C(xs)\n\n"
                  "private bool C<T>(list<T> xs)\n"
                  "C(xs) -> List.Contains(xs, \"x\")\n")).

%% An argument the row already refused has its diagnostic; a second, naming a
%% record's hidden `Kind`, would only mislead.
a_refused_collection_is_not_also_reported_as_never_found_test() ->
    Out = compile("record Pt { X: int, Y: int }\n\n"
                  "public bool Go(Pt p)\n"
                  "Go(p) -> Map.Has(p, 1)\n"),
    bad_rc(Out),
    has(Out, "does not accept"),
    ?assertEqual(nomatch, string:find(Out, "never equal")).

%% `Take` looks for each key in its list, and the message says so.
a_sought_key_list_is_named_by_its_elements_test() ->
    has(compile("public map<string, int> Go(map<string, int> m)\n"
                "Go(m) -> Map.Take(m, [1])\n"),
        "an element of argument 2 can never equal").

%% A variable is found at any depth: `list<list<T>>` flattens a `T` too.
list_flatten_of_a_nested_variable_does_not_promise_it_back_test() ->
    Out = compile("public list<list<int>> H(int n)\n"
                  "H(n) -> G([[[n]]])\n\n"
                  "private list<T> G<T>(list<list<T>> xs)\n"
                  "G(xs) -> List.Flatten(xs)\n"),
    bad_rc(Out),
    has(Out, "G returns a value its signature does not declare").

%% A plain `atom` is not a variable for Flatten's typing, though a variable is
%% checked as one.
an_atom_element_is_not_read_as_a_variable_test() ->
    ok_rc(compile("public list<atom> H(list<atom> xs)\n"
                  "H(xs) -> G(xs, 1)\n\n"
                  "private list<atom> G<T>(list<atom> xs, T y)\n"
                  "G(xs, y) -> List.Flatten(xs)\n")).

%% A variable joined with `atom` in the body is still the variable (ENG-881),
%% and a caller may make it the value sought: here `T` is `string` and the
%% answer is `:true`.
a_variable_joined_with_atom_is_not_refused_test() ->
    {Root, Main} = in_dir([caller("public bool H(int n)\n"
                                  "H(n) -> G(\"x\", [:a])\n\n"
                                  "private bool G<T>(T x, list<atom> ys)\n"
                                  "G(x, ys) -> List.Contains([x, ..ys], \"x\")\n")]),
    ?assertEqual(":true",
                 value(bs_test_support:run_cli("--src-root " ++ Root ++ " " ++ Main ++ " H 1"))).

%% With the variable kept apart from `atom`, a plain `atom` inside a polymorphic
%% function is no variable, and a string is never one of its elements.
a_plain_atom_in_a_polymorphic_function_is_refused_test() ->
    Out = compile("public bool H(int n)\n"
                  "H(n) -> G(n, [:a])\n\n"
                  "private bool G<T>(T x, list<atom> ys)\n"
                  "G(x, ys) -> List.Contains(ys, \"x\")\n"),
    bad_rc(Out),
    has(Out, "never equal").
