%%% Ticket 67 — RESERVED QUALIFIERS: `List`, `Term` AND `Map`.
%%%
%%% Every collection operation is a COMPILER-KNOWN ENTRY inlined at the site that
%%% uses it. No `List.beam` ships, no `using` is ever written for it, and a
%%% compiled program's only runtime dependency is the BEAM. That is 67's (b), and
%%% the whole difference from its (a) — a shipped module the compiler resolves
%%% through the module table — is INVISIBLE to a test that only asks what the
%%% program prints. Both spellings print `6`. So the emission is asserted on the
%%% beam's own import table, not on a value.
%%%
%%% Driven through the CLI, for `modules_tests`'s reason: the subject is what
%%% happens across files, and one parsed file cannot express it.
%%%
%%% THREE CLAUSES, THREE DIAGNOSTICS, AND THE CONTROLS THAT KEEP EACH NARROW.
%%% Each refusal below is paired with the nearest program that must still be
%%% ACCEPTED, because a check that refuses everything passes every red test in
%%% this file and is worthless:
%%%
%%%   clause 2  `module List` is refused         · `module Shop.List` is not
%%%   clause 3  `using Shop` + `List.Sum(…)`     · `using Shop` + `Ints.Sum(…)`
%%%             is refused                         is not, and neither is the
%%%                                                MODULE tier or a full path
%%%
%%% Clause 3 is namespace-tier-only by construction rather than by choice:
%%% `add_module_import/3` populates `funs`/`imported` and `add_namespace_import/3`
%%% populates `mods`, so a check written against `mods` CANNOT fire on the module
%%% tier. The two controls at the bottom of that group are what hold it there.

-module(reserved_qualifier_tests).

-include_lib("eunit/include/eunit.hrl").

%%% ---------------------------------------------------------------------------
%%% Helpers
%%% ---------------------------------------------------------------------------

%% `modules_tests`'s shape, plus the root — the emission tests need the output
%% directory, and a helper that threw it away would force a second copy.
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

%% A caller module with no `using` line at all, which is the point: a reserved
%% qualifier is reached without one.
caller(Body) ->
    {"P.bs", "module P\n" ++ Body}.

%% THE EMISSION ORACLE. `beam_lib`'s import chunk is every {M, F, A} the module
%% calls remotely; an inlined operation contributes NONE under its qualifier.
%% Asserted against the compiled artefact rather than against the printed value
%% because the value cannot tell 67's (a) from its (b).
imports(Root, Beam) ->
    {ok, {_, [{imports, Is}]}} =
        beam_lib:chunks(Root ++ "/out/" ++ Beam ++ ".beam", [imports]),
    Is.

%% The modules this beam calls into. `erlang` and `lists` are the BEAM itself and
%% are not what "no `List.beam` ships" is about.
called_modules(Root, Beam) ->
    lists:usort([M || {M, _, _} <- imports(Root, Beam)]).

%%% ---------------------------------------------------------------------------
%%% Clause 1 — the table resolves with no `using`, and is typed at the site
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

%% `Reverse` returns the list it was handed, so its result is a legal argument
%% to a function declared over that element type — which is what "typed at the
%% site with that site's ground element type" has to mean to be worth anything.
list_reverse_keeps_its_element_type_test() ->
    Out = compile_set([caller("public list<int> Go(list<int> xs)\n"
                              "Go(xs) -> List.Reverse(xs)\n")]),
    ok_rc(Out).

%% 16's universal-order escape, named at last by 67. The union is ordinary: it
%% declares, it is legal in return position, and a `switch` must cover it.
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

%% The return type is the three-atom union and not `atom`, so a `switch` over it
%% is exhaustive with three arms and inexhaustive with two. Asserting the
%% MISSING-ARM residual is what distinguishes a real union from a widened atom:
%% `atom` would leave a residual naming every other atom.
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
%%% Clause 1's whole point — INLINED, NOT CALLED
%%%
%%% This is the assertion the feature exists for. It is stated as an ABSENCE, so
%%% it is asserted against a compile that is otherwise clean (`ok_rc` first) and
%%% beside a positive control that proves the oracle can see a call at all.
%%% Without that control a build emitting nothing would pass.
%%% ---------------------------------------------------------------------------

a_reserved_qualifier_call_emits_no_remote_call_test() ->
    {Root, Out} = compile_set_([caller("public int Go(int n)\n"
                                       "Go(n) -> List.Sum([n, n, n])\n")]),
    ok_rc(Out),
    Mods = called_modules(Root, "P"),
    ?assertNot(lists:member('List', Mods)),
    ?assertNot(lists:member('lists', Mods)).

%% THE POSITIVE CONTROL FOR THE ORACLE ABOVE. An ordinary cross-module call DOES
%% appear in the import chunk, so the absence asserted above is a fact about the
%% reserved qualifier rather than about `beam_lib` returning an empty list.
an_ordinary_qualified_call_does_emit_a_remote_call_test() ->
    {Root, Out} = compile_set_([{"P.bs",
                                 "module P\n"
                                 "using Shop.Ints\n"
                                 "public int Go(int n)\n"
                                 "Go(n) -> Shop.Ints.Sum([n], 0)\n"},
                                ints_mod()]),
    ok_rc(Out),
    ?assert(lists:member('Shop.Ints', called_modules(Root, "P"))).

%% No `List.beam`, and nothing else either: the only artefact a module using a
%% reserved qualifier produces is its own.
a_reserved_qualifier_ships_no_module_test() ->
    {Root, Out} = compile_set_([caller("public int Go(int n)\n"
                                       "Go(n) -> List.Length([n])\n")]),
    ok_rc(Out),
    ?assertNot(filelib:is_regular(Root ++ "/out/List.beam")),
    ?assert(filelib:is_regular(Root ++ "/out/P.beam")).

%%% ---------------------------------------------------------------------------
%%% Clause 2 — a reserved name may not be DECLARED as a module
%%%
%%% Measured 2026-09-04 before this feature: `module List`, `module Map` and
%%% `module Term` each compiled clean in a directory of their own name. 48's
%%% reservation half was never built, so this is a build and not an extension —
%%% which is why all three names get a test rather than one standing for the set.
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

%% THE CONTROL, AND 67 Q6's ACTUAL CHOICE. Only the BARE name is burned. Q6
%% declined (i) — burning the segment — precisely so that `Shop.Collections.List`
%% stays a legal module, and a check written against the whole dotted path would
%% quietly take the option the ticket refused.
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
%%% Clause 3 — the collision, AT THE CALL SITE
%%%
%%% 67 Q6 (iii): ticket 47's rule for two user modules, applied to one more
%%% source of shadow. The import is NOT refused — only the call — so that a file
%%% may go on importing a namespace that happens to contain a `List`.
%%% ---------------------------------------------------------------------------

ints_mod() ->
    {"Ints.bs",
     "module Shop.Ints\n"
     "public int Sum(list<int> xs, int acc)\n"
     "Sum([], acc) -> acc\n"
     "Sum([x, ..rest], acc) -> Sum(rest, acc + x)\n"}.

%% A module whose LEAF is the reserved word, reachable by every tier. This is
%% `Shop.Collections.List`'s shape, kept in the tests after the corpus example
%% was renamed — the rule still has to be true of it.
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

%% BOTH CLAIMANTS, AND THE FULL PATH AS THE FIX — 47's rule, which is what makes
%% this a diagnostic rather than a refusal. A message naming only the reserved
%% word tells an author nothing they can act on.
the_collision_names_both_claimants_and_prints_the_full_path_test() ->
    Out = compile_set([{"R.bs",
                        "module Shop.Reports\n"
                        "using Shop\n"
                        "public int Go(int n)\n"
                        "Go(n) -> List.Sum([n, n, n], 0)\n"},
                       shop_list_mod()]),
    has(Out, "Shop.List").

%% CONTROL 1 — THE IMPORT ITSELF IS FINE. 67 Q6 chose the call site over the
%% import, so a file importing a namespace that contains a `List` and never
%% short-qualifying it compiles clean. A check that fired at the import would
%% pass every red test above and fail this one.
importing_a_namespace_containing_a_reserved_leaf_is_not_itself_an_error_test() ->
    Out = compile_set([{"R.bs",
                        "module Shop.Reports\n"
                        "using Shop\n"
                        "public int Go(int n)\n"
                        "Go(n) -> n\n"},
                       shop_list_mod()]),
    ok_rc(Out).

%% CONTROL 2 — A NON-RESERVED SHORT QUALIFIER IS UNTOUCHED. The namespace tier
%% still works; it is one word that cannot be its short name.
a_namespace_import_short_qualifying_a_normal_name_still_works_test() ->
    Out = run([{"R.bs",
                "module Shop.Reports\n"
                "using Shop\n"
                "public int Go(int n)\n"
                "Go(n) -> Ints.Sum([n, n, n], 0)\n"},
               ints_mod()],
              "Go 2"),
    ?assertEqual("6", value(Out)).

%% CONTROL 3 — THE MODULE TIER IS NOT THE NAMESPACE TIER. `using Shop.List`
%% brings `Sum` in UNQUALIFIED; it creates no `mods` key, so no shadow exists and
%% nothing is refused. This is the control that holds clause 3 to one tier.
the_module_tier_of_a_reserved_leaf_is_untouched_test() ->
    Out = run([{"R.bs",
                "module Shop.Reports\n"
                "using Shop.List\n"
                "public int Go(int n)\n"
                "Go(n) -> Sum([n, n, n], 0)\n"},
               shop_list_mod()],
              "Go 2"),
    ?assertEqual("6", value(Out)).

%% CONTROL 4 — THE FULL PATH IS ALWAYS LEGAL, which is exactly what the
%% diagnostic above offers as the fix. If this were refused the fix would be a
%% lie, and the message would send authors somewhere that does not compile.
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
%%% The third diagnostic — an operation the qualifier has not got
%%%
%%% The table must answer for `List.Frobnicate(x)`. Without this the name would
%%% fall through to `module_not_imported` and tell an author to `using List`,
%%% which is the one thing that can never work.
%%% ---------------------------------------------------------------------------

an_operation_the_reserved_qualifier_lacks_is_refused_test() ->
    Out = compile_set([caller("public int Go(int n)\n"
                              "Go(n) -> List.Frobnicate([n])\n")]),
    bad_rc(Out),
    has(Out, "Frobnicate").

%% AND IT MUST NOT SAY `using`. The measured refusal before this feature was
%% "List is called but never imported", hinting "add `using List`" — advice that
%% is now permanently wrong for a reserved qualifier.
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

%% THE TABLE IS KEYED BY ARITY, and that is not pedantry: `List.Sum/2` is what
%% `Shop.Collections.List` declared, so the corpus's own habit is the wrong
%% arity here. An author who writes it gets the operation's real shape.
the_wrong_arity_of_a_known_operation_is_refused_test() ->
    Out = compile_set([caller("public int Go(int n)\n"
                              "Go(n) -> List.Sum([n], 0)\n")]),
    bad_rc(Out),
    has(Out, "Sum").

%%% ---------------------------------------------------------------------------
%%% The type is the SITE's, not a widened one
%%% ---------------------------------------------------------------------------

%% `List.Sum` over a list the signature says holds strings is a type error, not a
%% silently-accepted `term`. A table entry typed `list<term> -> term` would pass
%% every green test above and this is the only test that would notice.
%%
%% `bad_rc` ALONE IS VACUOUS HERE, and it was, measured on 2026-09-04: before the
%% feature this program is refused with "List is called but never imported", so
%% the test went green while the compiler had never heard of `List.Sum` at all.
%% Excluding that string is what makes the refusal be about the TYPE — the same
%% trap `check-division.sh`'s P4 was written against, one construct over.
summing_a_list_of_strings_is_a_type_error_test() ->
    Out = compile_set([caller("public int Go(list<string> xs)\n"
                              "Go(xs) -> List.Sum(xs)\n")]),
    bad_rc(Out),
    ?assertEqual(nomatch, string:find(Out, "never imported")).

%% And the result is an `int`, so returning it where a `string` is declared is
%% refused. The pair of these two pins both ends of the entry's signature, and
%% both carry the exclusion above for the same reason.
the_result_of_sum_is_an_int_test() ->
    Out = compile_set([caller("public string Go(list<int> xs)\n"
                              "Go(xs) -> List.Sum(xs)\n")]),
    bad_rc(Out),
    ?assertEqual(nomatch, string:find(Out, "never imported")).
