%%% Scenarios: compiler/features/F32-reserved-qualifiers.md,
%%% compiler/features/F62-standard-signature-table.md
%%% Cross-file resolution runs through the CLI.

-module(reserved_qualifier_tests).

-include_lib("eunit/include/eunit.hrl").

%%% ---------------------------------------------------------------------------
%%% Helpers
%%% ---------------------------------------------------------------------------

in_dir(Files) ->
    Root = bs_test_support:fixture_root(),
    Paths = [bs_test_support:place(Root, N, S) || {N, S} <- Files],
    {Root, hd(Paths)}.

compile_set(Files) ->
    {_Root, Out} = compile_set_(Files),
    Out.

compile_set_(Files) ->
    {Root, Main} = in_dir(Files),
    {Root, bs_test_support:run_cli("--src-root " ++ Root ++ " -o " ++ Root
                                   ++ "/out " ++ Main)}.

run(Files, Call) ->
    {Root, Main} = in_dir(Files),
    bs_test_support:run_cli("--src-root " ++ Root ++ " " ++ Main ++ " " ++ Call).

ok_rc(Out)  -> ?assert(string:find(Out, "rc:0") =/= nomatch).
bad_rc(Out) -> ?assert(string:find(Out, "rc:1") =/= nomatch).
has(Out, S) -> ?assert(string:find(Out, S) =/= nomatch).
value(Out)  -> string:trim(hd(string:split(Out, "\n"))).

%% No import: reserved qualifiers are available without one.
caller(Body) ->
    {"P.bs", "module P\n" ++ Body}.

%% The import chunk distinguishes inlining from a call with the same result.
imports(Root, Beam) ->
    {ok, {_, [{imports, Is}]}} =
        beam_lib:chunks(Root ++ "/out/" ++ Beam ++ ".beam", [imports]),
    Is.

called_modules(Root, Beam) ->
    lists:usort([M || {M, _, _} <- imports(Root, Beam)]).

%%% ---------------------------------------------------------------------------
%%% Resolution without imports
%%% ---------------------------------------------------------------------------

list_sum_needs_no_using_test() ->
    Out = run([caller("public int Go(int n)\n"
                      "Go(n) -> List.Sum([n, n, n])\n")], "Go 2"),
    ?assertEqual("6", value(Out)).

list_length_needs_no_using_test() ->
    Out = run([caller("public int Go(int n)\n"
                      "Go(n) -> List.Length([n, n])\n")], "Go 7"),
    ?assertEqual("2", value(Out)).

list_reverse_needs_no_using_test() ->
    Out = run([caller("public int Go(int n)\n"
                      "Go(n) -> List.Sum(List.Reverse([n, n, n]))\n")], "Go 4"),
    ?assertEqual("12", value(Out)).

list_reverse_keeps_its_element_type_test() ->
    Out = compile_set([caller("public list<int> Go(list<int> xs)\n"
                              "Go(xs) -> List.Reverse(xs)\n")]),
    ok_rc(Out).

term_compare_needs_no_using_test() ->
    Out = run([caller("public atom Go(int n)\n"
                      "Go(n) -> Term.Compare(n, 5)\n")], "Go 2"),
    ?assertEqual(":lt", value(Out)).

term_compare_answers_eq_and_gt_test() ->
    Eq = run([caller("public atom Go(int n)\n"
                     "Go(n) -> Term.Compare(n, 5)\n")], "Go 5"),
    ?assertEqual(":eq", value(Eq)),
    Gt = run([caller("public atom Go(int n)\n"
                     "Go(n) -> Term.Compare(n, 5)\n")], "Go 9"),
    ?assertEqual(":gt", value(Gt)).

%% A widened `atom` leaves more than the missing arm in the residual.
term_compare_is_a_three_atom_union_test() ->
    Out = compile_set([caller(
            "public int Go(int n)\n"
            "Go(n) -> Term.Compare(n, 5) switch {\n"
            "  :lt => 1,\n"
            "  :eq => 2\n"
            "}\n")]),
    bad_rc(Out),
    has(Out, ":gt").

term_compare_with_all_three_arms_is_exhaustive_test() ->
    Out = compile_set([caller(
            "public int Go(int n)\n"
            "Go(n) -> Term.Compare(n, 5) switch {\n"
            "  :lt => 1,\n"
            "  :eq => 2,\n"
            "  :gt => 3\n"
            "}\n")]),
    ok_rc(Out).

%%% ---------------------------------------------------------------------------
%%% Inlined operations
%%% ---------------------------------------------------------------------------
%%% A clean compile and a remote-call control make absence meaningful.

%% F62.1 — ticket 96 Q1: the operation is OTP's own function, and the qualifier names
%% no module. F32 asserted `lists` absent; 96 Q1 reversed that reading.
a_reserved_qualifier_call_lowers_to_otp_not_to_a_list_module_test() ->
    {Root, Out} = compile_set_([caller("public int Go(int n)\n"
                                       "Go(n) -> List.Sum([n, n, n])\n")]),
    ok_rc(Out),
    Mods = called_modules(Root, "P"),
    ?assertNot(lists:member('List', Mods)),
    ?assert(lists:member({lists, sum, 1}, imports(Root, "P"))).

%% F62.2 — one row per operation, each read off the artefact.
every_list_row_is_a_call_into_otp_test() ->
    {Root, Out} = compile_set_([caller(
        "public int Go(list<int> xs)\n"
        "Go(xs) -> List.Sum(List.Reverse(List.Sort(List.Map(List.Filter(xs, x => x > 0), x => x + 1))))\n"
        "          + List.Length(xs) + List.Fold(xs, 0, (acc, x) => acc + x)\n")]),
    ok_rc(Out),
    Is = imports(Root, "P"),
    [?assert(lists:member(MFA, Is))
     || MFA <- [{lists, sum, 1}, {lists, reverse, 1}, {lists, sort, 1},
                {lists, map, 2}, {lists, filter, 2}, {lists, foldl, 3},
                {erlang, length, 1}]].

%% F62.3 — `List.Sort`, the first row added on the table.
list_sort_needs_no_using_test() ->
    Out = run([caller("public list<int> Go(int n)\n"
                      "Go(n) -> List.Sort([n, 1, n + 1, 0])\n")], "Go 5"),
    ?assertEqual("[0, 1, 5, 6]", value(Out)).

list_sort_keeps_its_element_type_test() ->
    Out = compile_set([caller("public list<int> Go(list<int> xs)\n"
                              "Go(xs) -> List.Sort(xs)\n")]),
    ok_rc(Out).

list_sort_of_the_wrong_argument_is_a_type_error_test() ->
    Out = compile_set([caller("public list<int> Go(int n)\n"
                              "Go(n) -> List.Sort(n)\n")]),
    bad_rc(Out),
    ?assertEqual(nomatch, string:find(Out, "never imported")).

%% F62.4 — `lists:foldl` calls its fun as (elem, acc); B#'s is (acc, elem), which
%% ticket 75 settled. An order-sensitive fold tells the two apart.
fold_keeps_the_accumulator_first_through_a_lambda_test() ->
    Out = run([caller("public list<int> Go(int n)\n"
                      "Go(n) -> List.Fold([n, n + 1, n + 2], [], (acc, x) => [x, ..acc])\n")],
              "Go 1"),
    ?assertEqual("[3, 2, 1]", value(Out)).

fold_keeps_the_accumulator_first_through_a_named_function_test() ->
    Out = run([caller("public list<int> Go(int n)\n"
                      "Go(n) -> List.Fold([n, n + 1, n + 2], [], Push)\n"
                      "list<int> Push(list<int> acc, int x)\n"
                      "Push(acc, x) -> [x, ..acc]\n")],
              "Go 1"),
    ?assertEqual("[3, 2, 1]", value(Out)).

fold_and_map_keep_their_order_with_each_other_test() ->
    Out = run([caller("public int Go(int n)\n"
                      "Go(n) -> List.Fold(List.Map([n, n], x => x * 10), n, (acc, x) => acc - x)\n")],
              "Go 1"),
    ?assertEqual("-19", value(Out)).

%% F62.5 — `List.FoldRight` is `lists:foldr/3`, from the tail, with Fold's
%% (acc, x) callback. Consing keeps the order a left fold reverses.
fold_right_starts_from_the_tail_test() ->
    Out = run([caller("public list<int> Go(int n)\n"
                      "Go(n) -> List.FoldRight([n, n + 1, n + 2], [], (acc, x) => [x, ..acc])\n")],
              "Go 1"),
    ?assertEqual("[1, 2, 3]", value(Out)).

fold_right_keeps_the_accumulator_first_through_a_named_function_and_a_pipe_test() ->
    Out = run([caller("public list<int> Go(int n)\n"
                      "Go(n) -> [n, n + 1, n + 2] |> List.FoldRight([], Push)\n"
                      "list<int> Push(list<int> acc, int x)\n"
                      "Push(acc, x) -> [x, ..acc]\n")],
              "Go 1"),
    ?assertEqual("[1, 2, 3]", value(Out)).

fold_right_is_a_call_into_otp_test() ->
    {Root, Out} = compile_set_([caller(
        "public int Go(list<int> xs)\n"
        "Go(xs) -> List.FoldRight(xs, 0, (acc, x) => acc + x)\n")]),
    ok_rc(Out),
    ?assert(lists:member({lists, foldr, 3}, imports(Root, "P"))).

%% The accumulator is typed as Fold's is: the seed joined with the callback's
%% result, so a callback returning the wrong type is refused.
fold_right_types_its_accumulator_test() ->
    Out = compile_set([caller("public int Go(list<int> xs)\n"
                              "Go(xs) -> List.FoldRight(xs, 0, (acc, x) => \"s\")\n")]),
    bad_rc(Out),
    ?assertEqual(nomatch, string:find(Out, "has no operation")).

%% A pipe supplies the list as the first argument before the emitter reorders
%% it, so the piped form must fold in the same order as the direct call.
a_piped_fold_keeps_the_accumulator_first_test() ->
    Out = run([caller("public list<int> Go(int n)\n"
                      "Go(n) -> [n, n + 1, n + 2] |> List.Fold([], (acc, x) => [x, ..acc])\n")],
              "Go 1"),
    ?assertEqual("[3, 2, 1]", value(Out)).

%% An ordinary call checks that the import chunk can reveal remote calls.
an_ordinary_qualified_call_does_emit_a_remote_call_test() ->
    {Root, Out} = compile_set_([{"P.bs",
                                 "module P\n"
                                 "using Shop.Ints\n"
                                 "public int Go(int n)\n"
                                 "Go(n) -> Shop.Ints.Sum([n], 0)\n"},
                                ints_mod()]),
    ok_rc(Out),
    ?assert(lists:member('Shop.Ints', called_modules(Root, "P"))).

a_reserved_qualifier_ships_no_module_test() ->
    {Root, Out} = compile_set_([caller("public int Go(int n)\n"
                                       "Go(n) -> List.Length([n])\n")]),
    ok_rc(Out),
    ?assertNot(filelib:is_regular(Root ++ "/out/List.beam")),
    ?assert(filelib:is_regular(Root ++ "/out/P.beam")).

%%% ---------------------------------------------------------------------------
%%% Reserved module names
%%% ---------------------------------------------------------------------------

declaring_a_module_called_list_is_refused_test() ->
    Out = compile_set([{"List.bs", "module List\n"
                                   "public int Go(int n)\n"
                                   "Go(n) -> n\n"}]),
    bad_rc(Out),
    has(Out, "reserved").

declaring_a_module_called_map_is_refused_test() ->
    Out = compile_set([{"Map.bs", "module Map\n"
                                  "public int Go(int n)\n"
                                  "Go(n) -> n\n"}]),
    bad_rc(Out),
    has(Out, "reserved").

declaring_a_module_called_term_is_refused_test() ->
    Out = compile_set([{"Term.bs", "module Term\n"
                                   "public int Go(int n)\n"
                                   "Go(n) -> n\n"}]),
    bad_rc(Out),
    has(Out, "reserved").

%% Only the bare name is reserved; a path segment remains legal.
a_reserved_name_as_a_path_segment_is_still_legal_test() ->
    Out = compile_set([{"List.bs", "module Shop.List\n"
                                   "public int Go(int n)\n"
                                   "Go(n) -> n\n"}]),
    ok_rc(Out).

a_deeply_nested_reserved_segment_is_still_legal_test() ->
    Out = compile_set([{"List.bs", "module Shop.Collections.List\n"
                                   "public int Go(int n)\n"
                                   "Go(n) -> n\n"}]),
    ok_rc(Out).

%%% ---------------------------------------------------------------------------
%%% Collisions at the call site
%%% ---------------------------------------------------------------------------

ints_mod() ->
    {"Ints.bs",
     "module Shop.Ints\n"
     "public int Sum(list<int> xs, int acc)\n"
     "Sum([], acc) -> acc\n"
     "Sum([x, ..rest], acc) -> Sum(rest, acc + x)\n"}.

shop_list_mod() ->
    {"List.bs",
     "module Shop.List\n"
     "public int Sum(list<int> xs, int acc)\n"
     "Sum([], acc) -> acc\n"
     "Sum([x, ..rest], acc) -> Sum(rest, acc + x)\n"}.

a_namespace_import_shadowing_a_reserved_qualifier_is_refused_at_the_call_test() ->
    Out = compile_set([{"R.bs",
                        "module Shop.Reports\n"
                        "using Shop\n"
                        "public int Go(int n)\n"
                        "Go(n) -> List.Sum([n, n, n], 0)\n"},
                       shop_list_mod()]),
    bad_rc(Out),
    has(Out, "reserved").

the_collision_names_both_claimants_and_prints_the_full_path_test() ->
    Out = compile_set([{"R.bs",
                        "module Shop.Reports\n"
                        "using Shop\n"
                        "public int Go(int n)\n"
                        "Go(n) -> List.Sum([n, n, n], 0)\n"},
                       shop_list_mod()]),
    has(Out, "Shop.List").

%% A namespace containing `List` is legal until a short-qualified call.
importing_a_namespace_containing_a_reserved_leaf_is_not_itself_an_error_test() ->
    Out = compile_set([{"R.bs",
                        "module Shop.Reports\n"
                        "using Shop\n"
                        "public int Go(int n)\n"
                        "Go(n) -> n\n"},
                       shop_list_mod()]),
    ok_rc(Out).

a_namespace_import_short_qualifying_a_normal_name_still_works_test() ->
    Out = run([{"R.bs",
                "module Shop.Reports\n"
                "using Shop\n"
                "public int Go(int n)\n"
                "Go(n) -> Ints.Sum([n, n, n], 0)\n"},
               ints_mod()],
              "Go 2"),
    ?assertEqual("6", value(Out)).

%% A module import exposes unqualified functions, so it creates no shadow.
the_module_tier_of_a_reserved_leaf_is_untouched_test() ->
    Out = run([{"R.bs",
                "module Shop.Reports\n"
                "using Shop.List\n"
                "public int Go(int n)\n"
                "Go(n) -> Sum([n, n, n], 0)\n"},
               shop_list_mod()],
              "Go 2"),
    ?assertEqual("6", value(Out)).

%% The full path checks that the diagnostic offers a usable correction.
the_full_path_of_a_reserved_leaf_is_always_legal_test() ->
    Out = run([{"R.bs",
                "module Shop.Reports\n"
                "using Shop.List\n"
                "public int Go(int n)\n"
                "Go(n) -> Shop.List.Sum([n, n, n], 0)\n"},
               shop_list_mod()],
              "Go 2"),
    ?assertEqual("6", value(Out)).

%%% ---------------------------------------------------------------------------
%%% Missing operations
%%% ---------------------------------------------------------------------------

an_operation_the_reserved_qualifier_lacks_is_refused_test() ->
    Out = compile_set([caller("public int Go(int n)\n"
                              "Go(n) -> List.Frobnicate([n])\n")]),
    bad_rc(Out),
    has(Out, "Frobnicate").

%% A reserved qualifier cannot be repaired by importing it.
the_missing_operation_is_not_reported_as_a_missing_import_test() ->
    Out = compile_set([caller("public int Go(int n)\n"
                              "Go(n) -> List.Frobnicate([n])\n")]),
    ?assertEqual(nomatch, string:find(Out, "never imported")),
    ?assertEqual(nomatch, string:find(Out, "using List")).

a_missing_term_operation_is_refused_the_same_way_test() ->
    Out = compile_set([caller("public int Go(int n)\n"
                              "Go(n) -> Term.Frobnicate(n, n)\n")]),
    bad_rc(Out),
    has(Out, "Frobnicate").

the_wrong_arity_of_a_known_operation_is_refused_test() ->
    Out = compile_set([caller("public int Go(int n)\n"
                              "Go(n) -> List.Sum([n], 0)\n")]),
    bad_rc(Out),
    has(Out, "Sum").

%%% ---------------------------------------------------------------------------
%%% Types at the call site
%%% ---------------------------------------------------------------------------

%% Exclude an import error so a nonzero exit observes the type mismatch.
summing_a_list_of_strings_is_a_type_error_test() ->
    Out = compile_set([caller("public int Go(list<string> xs)\n"
                              "Go(xs) -> List.Sum(xs)\n")]),
    bad_rc(Out),
    ?assertEqual(nomatch, string:find(Out, "never imported")).

%% Exclude an import error here too, to check the result type.
the_result_of_sum_is_an_int_test() ->
    Out = compile_set([caller("public string Go(list<int> xs)\n"
                              "Go(xs) -> List.Sum(xs)\n")]),
    bad_rc(Out),
    ?assertEqual(nomatch, string:find(Out, "never imported")).
