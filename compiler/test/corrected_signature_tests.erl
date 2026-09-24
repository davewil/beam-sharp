%%% Scenarios: compiler/features/F25-corrected-signature.md
-module(corrected_signature_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [with_src/3, run_cli/1]).

%%% Corrected signatures

-define(HEADING, "the signature its clauses justify:").

-define(UNSPELLABLE, "no signature is offered: what the clauses return has no spelling as a type yet.").

lead(Declared) ->
    "If `" ++ Declared ++ "` is what you meant, fix the clause, not the signature.".

%% The clause advice precedes widening, refusal, and withholding reasons.
leads(Out, Declared) ->
    Rest = [P || M <- [?HEADING, "Widening the signature", "no signature is offered"],
                 P <- [string:str(Out, M)], P > 0],
    case string:str(Out, lead(Declared)) of
        0 -> false;
        L -> Rest =:= [] orelse L < lists:min(Rest)
    end.

%% Source discovery needs `.bs`; compilation takes the containing directory.
cli(Name, Src) ->
    with_src(Name ++ ".bs", Src,
             fun(Path, Root) ->
                     run_cli("--src-root " ++ Root ++ " " ++ filename:dirname(Path))
             end).

%%% Baseline

%% F25.1 — the correction is a whole signature, not a type fragment.
a_return_mismatch_carries_the_signature_to_paste_test() ->
    Src = "module M1\npublic int Answer(int n)\nAnswer(n) -> :oops\n",
    Out = cli("M1", Src),
    ?assert(string:find(Out, ?HEADING) =/= nomatch),
    ?assert(string:find(Out, "public int | :oops Answer(int n)") =/= nomatch),
    ?assert(leads(Out, "int")),
    ?assert(string:find(Out, "Otherwise, the signature its clauses justify:") =/= nomatch).

%% F25.2 — the uncovered residual accompanies the correction.
the_uncovered_residual_survives_beside_it_test() ->
    Src = "module M2\npublic int Answer(int n)\nAnswer(n) -> :oops\n",
    Out = cli("M2", Src),
    ?assert(string:find(Out, "not covered by the declared return type:") =/= nomatch).

%% A presence check prevents the absence check passing on empty output.
a_none_return_is_corrected_without_an_absorbed_member_test() ->
    Src = "module M10\npublic none Reject(term r)\nReject(r) -> r\n",
    Out = cli("M10", Src),
    ?assert(string:find(Out, ?HEADING) =/= nomatch),
    ?assert(string:find(Out, "public term Reject(term r)") =/= nomatch),
    ?assertEqual(nomatch, string:find(Out, "none |")),
    %% Every type contains `none`, so replacement advice would say nothing.
    ?assertEqual(nomatch, string:find(Out, "this replaces")),
    %% A `none` return forbids returning at all, so clause advice still applies.
    ?assert(leads(Out, "none")).

%%% Function-wide corrections

%% F25.3 — both diagnostics carry the same whole-function correction.
two_offending_clauses_get_one_function_wide_signature_test() ->
    Src = "module M3\npublic int Go(int n)\n"
          "Go(0) -> :zero\n"
          "Go(n) -> (:error, \"bad\")\n",
    Out = cli("M3", Src),
    Line = "public int | :zero | (:error, string) Go(int n)",
    ?assertEqual(2, count_occurrences(Out, ?HEADING)),
    ?assertEqual(2, count_occurrences(Out, Line)).

%%% Unwritable residuals

%% F25.4 — a record residual withholds the signature, not the diagnostic.
%% The discriminator belongs in the residual, but not in a pasted signature.
a_record_in_the_residual_prints_no_signature_test() ->
    Src = "module M4\n"
          "record Order   { Id: int, Total: int }\n"
          "record Invoice { Id: int, Total: int }\n"
          "public Order Make(int n)\n"
          "Make(n) -> Invoice{ Id = n, Total = 0 }\n",
    Out = cli("M4", Src),
    ?assert(string:find(Out, "returns a value its signature does not declare") =/= nomatch),
    ?assert(string:find(Out, "Kind: :'M4.Invoice'") =/= nomatch),
    ?assertEqual(nomatch, string:find(Out, ?HEADING)),
    ?assert(string:find(Out, ?UNSPELLABLE) =/= nomatch),
    ?assert(leads(Out, "Order")).

%% F25.5 — a declared record keeps its source name in the correction.
a_declared_record_is_named_not_minted_test() ->
    Src = "module M5\n"
          "record Order { Id: int, Total: int }\n"
          "public Order Make(int n)\n"
          "Make(n) -> :oops\n",
    Out = cli("M5", Src),
    ?assert(string:find(Out, "public Order | :oops Make(int n)") =/= nomatch),
    ?assertEqual(nomatch, string:find(Out, "Kind:")).

%%% Visibility

%% F25.6 — a corrected private signature stays private.
a_private_function_is_not_exported_by_the_pasted_line_test() ->
    Src = "module M6\n"
          "public int Entry(int n)\n"
          "Entry(n) -> Helper(n)\n"
          "int Helper(int n)\n"
          "Helper(n) -> :oops\n",
    Out = cli("M6", Src),
    ?assert(string:find(Out, "int | :oops Helper(int n)") =/= nomatch),
    ?assertEqual(nomatch, string:find(Out, "public int | :oops Helper")).

%%% Diagnostic terms

%% F25.7 — return mismatches belong to the contractual diagnostic subset.
return_not_declared_is_contractual_test() ->
    ?assert(lists:member(return_not_declared, bs_diag:contractual())).

%% F25.8 — the term carries the corrected signature under its own key.
the_term_carries_the_corrected_signature_test() ->
    D = term_of("M9", "module M9\npublic int Answer(int n)\nAnswer(n) -> :oops\n"),
    ?assertMatch(#{tag := return_not_declared,
                   corrected := "public int | :oops Answer(int n)"}, D).

%% F25.9 — a withheld signature has an explicit `none` and a reason.
the_term_says_none_when_no_signature_is_offered_test() ->
    Src = "module M27\n"
          "record Order   { Id: int, Total: int }\n"
          "record Invoice { Id: int, Total: int }\n"
          "public Order Make(int n)\n"
          "Make(n) -> Invoice{ Id = n, Total = 0 }\n",
    ?assertMatch(#{tag := return_not_declared, corrected := none,
                   withheld := unspellable}, term_of("M27", Src)).

%%% Corrections refused by the declaration check

-define(REFUSED, "Widening the signature to cover what the clauses return would be refused:").
-define(TELL, "no clause head can tell `map<string, int>` from `map<string, binary>`").

-define(TAG, "so if both are meant, give each a record of its own and name the pair:").
-define(RECORDS, "    record Name1 { Value: map<string, int> }\n"
                 "    record Name2 { Value: map<string, binary> }\n"
                 "    type Name = Name1 | Name2\n").
-define(BUILD, "  build each value as its record, and choose the names.\n").

returns(Type) -> "  declare the return as `" ++ Type ++ "`,\n".

pick_src(Mod, Declared) -> pick_src(Mod, Declared, "map<string, binary>").

pick_src(Mod, Declared, Rest) ->
    pick_program(Mod, "public " ++ Declared ++ " Pick(int n)", Rest).

pick_program(Mod, Signature, Rest) ->
    "module " ++ Mod ++ "\n" ++
    Signature ++ "\n"
    "Pick(1) -> Ints()\n"
    "Pick(n) -> Rest()\n"
    "private map<string, int> Ints()\n"
    "Ints() -> Ints()\n"
    "private " ++ Rest ++ " Rest()\n"
    "Rest() -> Rest()\n".

%% `-o` keeps emitted beams in the fixture directory.
%% A clean compile emits only the CLI helper's exit marker.
compile(Name, Src) ->
    with_src(Name ++ ".bs", Src,
             fun(Path, Root) ->
                     run_cli("--src-root " ++ Root ++ " -o " ++ Root ++ " "
                             ++ filename:dirname(Path))
             end).

%% F25.10 — a refused correction gives a reason and repair beside the residual.
%% Positive checks prevent the absence checks passing on empty output.
a_correction_the_declaration_check_refuses_is_not_printed_test() ->
    Out = cli("M11", pick_src("M11", "map<string, int>")),
    ?assert(string:find(Out, "not covered by the declared return type:\n"
                             "    map<string, binary>") =/= nomatch),
    ?assertEqual(nomatch, string:find(Out, ?HEADING)),
    ?assertEqual(nomatch, string:find(Out, "map<string, int> | map<string, binary> Pick")),
    ?assert(string:find(Out, ?REFUSED) =/= nomatch),
    ?assert(string:find(Out, ?TELL) =/= nomatch),
    ?assert(string:find(Out, ?TAG) =/= nomatch),
    ?assert(string:find(Out, ?RECORDS) =/= nomatch),
    ?assert(string:find(Out, returns("Name") ++ ?BUILD) =/= nomatch),
    %% Record repair needs no author-written tuple tag.
    ?assertEqual(nomatch, string:find(Out, "(:tag1")),
    ?assert(leads(Out, "map<string, int>")),
    ?assert(string:str(Out, lead("map<string, int>")) < string:str(Out, ?REFUSED)).

%% F25.11 — compile and `--api` both refuse the withheld declaration.
%% The query path checks declarations without checking function body types.
the_withheld_line_is_refused_at_both_declaration_sites_test() ->
    Src = pick_src("M12", "map<string, int> | map<string, binary>"),
    with_src("M12.bs", Src,
             fun(Path, Root) ->
                     Dir = filename:dirname(Path),
                     Compile = run_cli("--src-root " ++ Root ++ " -o " ++ Root ++ " " ++ Dir),
                     Api = run_cli("--src-root " ++ Root ++ " --api " ++ Dir),
                     ?assert(string:find(Compile, ?TELL) =/= nomatch),
                     ?assert(string:find(Api, ?TELL) =/= nomatch)
             end).

%% F25.12 — a map beside an atom remains correctable: `is_map` splits them.
a_union_a_guard_can_split_is_still_corrected_test() ->
    Line = "public map<string, int> | :oops Pick(int n)",
    Out = cli("M13", "module M13\npublic map<string, int> Pick(int n)\nPick(n) -> :oops\n"),
    ?assert(string:find(Out, Line) =/= nomatch),
    ?assertEqual(nomatch, string:find(Out, ?REFUSED)),
    ?assertEqual("rc:0\n", compile("M14", "module M14\n" ++ Line ++ "\nPick(n) -> :oops\n")).

%% F25.13 — two residual maps are refused even under a declared `int`.
%% Comparing each map only with `int` misses the indistinguishable pair.
two_maps_in_the_residual_are_refused_together_test() ->
    Out = cli("M15", pick_src("M15", "int")),
    ?assertEqual(2, count_occurrences(Out, ?REFUSED)),
    ?assertEqual(2, count_occurrences(Out, ?TELL)),
    ?assertEqual(2, count_occurrences(Out, lead("int"))),
    ?assertEqual(nomatch, string:find(Out, ?HEADING)),
    %% The whole return includes `int`, which is outside the repaired pair.
    ?assertEqual(2, count_occurrences(Out, returns("int | Name"))).

%% F25.14 — the term names the refused pair and keeps `corrected` as `none`.
the_term_names_the_pair_that_refused_the_correction_test() ->
    Refused = term_of("M16", pick_src("M16", "map<string, int>")),
    ?assertMatch(#{tag := return_not_declared, corrected := none,
                   indiscriminable := #{member := "map<string, int>",
                                        beside := "map<string, binary>",
                                        expanded := [],
                                        declarations :=
                                            ["record Name1 { Value: map<string, int> }",
                                             "record Name2 { Value: map<string, binary> }",
                                             "type Name = Name1 | Name2"],
                                        returns := "Name",
                                        no_declarations := none},
                   withheld := none, replaces := none,
                   declared := "map<string, int>"},
                 Refused),
    Printed = term_of("M17", "module M17\npublic int Answer(int n)\nAnswer(n) -> :oops\n"),
    ?assertMatch(#{corrected := "public int | :oops Answer(int n)",
                   indiscriminable := none, withheld := none, replaces := none,
                   declared := "int"},
                 Printed).

%% F25.15 — a residual that absorbs the declared type replaces it.
%% The algebra cannot express the difference between these two map types.
a_residual_that_absorbs_the_declared_type_replaces_it_test() ->
    Line = "public map<string, term> Pick(int n)",
    Out = cli("M18", pick_src("M18", "map<string, int>", "map<string, term>")),
    ?assert(string:find(Out, Line) =/= nomatch),
    ?assertEqual(nomatch, string:find(Out, "map<string, int> |")),
    ?assertEqual("rc:0\n", compile("M19", pick_program("M19", Line, "map<string, term>"))),
    ?assert(string:find(Out, "this replaces `map<string, int>`, which "
                             "`map<string, term>` contains.") =/= nomatch),
    ?assert(string:find(Out, "If `map<string, int>` is what you meant, fix the "
                             "clause, not the signature.") =/= nomatch),
    ?assertMatch(#{corrected := Line,
                   replaces := #{declared := "map<string, int>",
                                 within := "map<string, term>"}},
                 term_of("M21", pick_src("M21", "map<string, int>", "map<string, term>"))),
    ?assert(leads(Out, "map<string, int>")).

%% F25.16 — an unparseable correction is withheld despite a legal union.
%% The non-empty list residual uses pattern syntax, not type syntax.
%% Its presence rules out empty output as the cause of the missing signature.
an_unparseable_correction_is_not_printed_test() ->
    Src = "module M20\n"
          "public list<map<string, int>> Pick(int n)\n"
          "Pick(1) -> Ints()\n"
          "Pick(n) -> Bins()\n"
          "private list<map<string, int>> Ints()\n"
          "Ints() -> Ints()\n"
          "private list<map<string, binary>> Bins()\n"
          "Bins() -> Bins()\n",
    Out = cli("M20", Src),
    ?assert(string:find(Out, "not covered by the declared return type:\n"
                             "    [map<string, binary>, ..]") =/= nomatch),
    ?assertEqual(nomatch, string:find(Out, ?HEADING)),
    ?assertEqual(nomatch, string:find(Out, ?REFUSED)),
    ?assert(string:find(Out, ?UNSPELLABLE) =/= nomatch),
    ?assert(leads(Out, "list<map<string, int>>")).

%%% Withholding reasons and repair advice

%% F25.17 — the printed record declarations and return type compile.
%% The fixture uses the emitted advice so a hand-written copy cannot mask it.
the_record_advice_compiles_as_printed_test() ->
    #{indiscriminable := #{declarations := Decls, returns := Returns}} =
        term_of("M22a", pick_src("M22a", "map<string, int>")),
    Src = "module M22\n" ++
          lists:append([D ++ "\n" || D <- Decls]) ++
          "public " ++ Returns ++ " Pick(int n)\n"
          "Pick(1) -> Name1{ Value = Ints() }\n"
          "Pick(n) -> Name2{ Value = Rest() }\n"
          "private map<string, int> Ints()\n"
          "Ints() -> Ints()\n"
          "private map<string, binary> Rest()\n"
          "Rest() -> Rest()\n",
    ?assertEqual("rc:0\n", compile("M22", Src)).

%% F25.18 — absorption inside a declared union withholds the correction.
%% The atom keeps the union present; its source text cannot be split.
a_partly_absorbed_declared_union_says_why_it_is_withheld_test() ->
    Src = "module M23\n"
          "public map<string, int> | :none Pick(int n)\n"
          "Pick(0) -> :none\n"
          "Pick(1) -> Ints()\n"
          "Pick(n) -> Rest()\n"
          "private map<string, int> Ints()\n"
          "Ints() -> Ints()\n"
          "private map<string, term> Rest()\n"
          "Rest() -> Rest()\n",
    Out = cli("M23", Src),
    ?assertEqual(nomatch, string:find(Out, ?HEADING)),
    ?assert(string:find(Out, "no signature is offered: widening it would leave "
                             "`map<string, int>` absorbed by") =/= nomatch),
    ?assert(leads(Out, "map<string, int> | :none")),
    ?assertMatch(#{corrected := none,
                   withheld := #{member := "map<string, int>", absorbed_by := _}},
                 term_of("M24", re:replace(Src, "M23", "M24", [{return, list}]))).

%% F25.19 — an inline map declaration has no reproducible signature.
an_unreproducible_declared_form_says_why_it_is_withheld_test() ->
    Src = "module M25\n"
          "public { Id: int, Email: binary } FindUser(int id)\n"
          "FindUser(id) -> :not_found\n",
    Out = cli("M25", Src),
    ?assertEqual(nomatch, string:find(Out, ?HEADING)),
    ?assert(string:find(Out, "no signature is offered: the declared signature is "
                             "written in a form") =/= nomatch),
    %% Source field order differs from the algebra printer's sorted order.
    ?assert(leads(Out, "{ Id: int, Email: binary }")),
    %% Preserve source field order inside nested maps and unions too.
    Nested = cli("M34", "module M34\n"
                        "public { Id: int, Meta: { Tag: int } } Find(int id)\n"
                        "Find(id) -> :not_found\n"),
    ?assert(leads(Nested, "{ Id: int, Meta: { Tag: int } }")),
    Either = cli("M35", "module M35\n"
                        "public { Id: int, Email: binary } | :gone Find(int id)\n"
                        "Find(id) -> :not_found\n"),
    ?assert(leads(Either, "{ Id: int, Email: binary } | :gone")).

%% F25.27 — an unwritable declared form falls back to the algebra spelling.
%% Fault injection is needed because the grammar cannot produce this form.
a_declared_form_nothing_can_write_is_named_as_printed_test() ->
    ?assertEqual("int", bs_check:declared_text({t_not_a_form}, bs_types:int())).

%% F25.20 — an unnamed paste-back failure reports a compiler defect.
%% No source program is known to reach it; invalid environments inject faults
%% at the producer, and the descriptor exercises the consumer.
an_unnamed_paste_back_failure_is_reported_as_a_defect_test() ->
    ?assertEqual({withhold, {crashed, error, function_clause}},
                 bs_check:as_pasted("public Foo F(int n)", #{'Foo' => not_a_type})),
    ?assertEqual({withhold, {crashed, error, badmap}},
                 bs_check:as_pasted("public Foo F(int n)", not_an_env)),
    D = bs_diag:descriptor("m.bs", {error, 3, 'Pick',
                                    {return_not_declared,
                                     bs_types:atom_lit(oops),
                                     {"int", {withhold, {crashed, error, badmatch}}}}}),
    ?assertMatch(#{corrected := none,
                   withheld := #{class := error, reason := badmatch}}, D),
    Prose = unicode:characters_to_list(bs_diag:format(D#{line => 3, column => 1})),
    ?assert(string:find(Prose, "(badmatch in bs_check:as_pasted/2), which is a "
                               "compiler defect.") =/= nomatch).

%% F25.21 — replacement advice uses the declared alias as written.
the_replaced_type_is_named_as_the_author_wrote_it_test() ->
    Src = "module M26\n"
          "type Counts = map<string, int>\n" ++
          tl(lists:dropwhile(fun(C) -> C =/= $\n end,
                             pick_src("M26", "Counts", "map<string, term>"))),
    Out = cli("M26", Src),
    ?assert(string:find(Out, "public map<string, term> Pick(int n)") =/= nomatch),
    ?assert(string:find(Out, "this replaces `Counts`, which `map<string, term>` "
                             "contains.") =/= nomatch),
    ?assert(leads(Out, "Counts")).

%%% Residual spellings

%% F25.22 — an unwritable residual is withheld without a compiler defect.
%% The residual's `tuple` and `map` spellings have no source type form.
a_residual_with_no_surface_form_is_unspellable_not_a_defect_test() ->
    Out = cli("M28", "module M28\npublic int Go(term r)\nGo(r) -> r\n"),
    ?assertEqual(nomatch, string:find(Out, ?HEADING)),
    ?assertEqual(nomatch, string:find(Out, "compiler defect")),
    ?assert(string:find(Out, ?UNSPELLABLE) =/= nomatch).

%% F25.23 — an imported recursive name appears in a compilable correction.
%% The local declaration is a control for the same name across `using`.
a_residual_named_in_another_module_spells_the_imported_name_test() ->
    Root = bs_test_support:fixture_root(),
    Tree = "module M29\n"
           "type Tree = :leaf | (:node, Tree, Tree)\n"
           "public Tree Leaf()\n"
           "Leaf() -> :leaf\n",
    _ = bs_test_support:place(Root, "M29.bs", Tree),
    Grow = bs_test_support:place(Root, "M30.bs",
                                 "module M30\n"
                                 "using M29\n"
                                 "public int Get(int n)\n"
                                 "Get(n) -> Leaf()\n"),
    Out = run_cli("--src-root " ++ Root ++ " -o " ++ Root ++ " "
                  ++ filename:dirname(Grow)),
    ?assertEqual(nomatch, string:find(Out, "compiler defect")),
    ?assertEqual(nomatch, string:find(Out, ?UNSPELLABLE)),
    Line = "public int | :leaf | (:node, Tree, Tree) Get(int n)",
    ?assert(string:find(Out, Line) =/= nomatch),
    Root2 = bs_test_support:fixture_root(),
    _ = bs_test_support:place(Root2, "M29.bs", Tree),
    Pasted = bs_test_support:place(Root2, "M30.bs",
                                   "module M30\n"
                                   "using M29\n"
                                   ++ Line ++ "\n"
                                   "Get(n) -> Leaf()\n"),
    Again = run_cli("--src-root " ++ Root2 ++ " -o " ++ Root2 ++ " "
                    ++ filename:dirname(Pasted)),
    ?assert(string:find(Again, "rc:0") =/= nomatch),
    Local = cli("M31", "module M31\n"
                       "type Tree = :leaf | (:node, Tree, Tree)\n"
                       "public int Get(int n)\n"
                       "Get(n) -> Leaf()\n"
                       "private Tree Leaf()\n"
                       "Leaf() -> :leaf\n"),
    ?assert(string:find(Local, "public int | :leaf | (:node, Tree, Tree) Get(int n)") =/= nomatch).

%% F25.24 — a declared atom keeps the quotes needed to compile.
a_declared_atom_that_needs_quoting_is_written_quoted_test() ->
    Line = "public int | :'a b' | :oops Go(int n)",
    Out = cli("M32", "module M32\npublic int | :'a b' Go(int n)\nGo(n) -> :oops\n"),
    ?assert(string:find(Out, Line) =/= nomatch),
    ?assertEqual("rc:0\n", compile("M33", "module M33\n" ++ Line ++ "\nGo(n) -> :oops\n")).

%%% Whole diagnostic messages

%% F25.25 — clause advice precedes the widened payment signature.
a_payment_handler_leads_with_the_clause_and_keeps_the_line_test() ->
    Src = "module Payments\n"
          "record Charge { OrderId: int, AmountCents: int }\n"
          "public atom TakePayment(Charge c, bool card_ok)\n"
          "TakePayment(c, true)  -> :paid\n"
          "TakePayment(c, false) -> (:declined, c.OrderId)\n",
    ?assertEqual(
       "error: TakePayment returns a value its signature does not declare\n"
       "  not covered by the declared return type:\n"
       "    (:declined, int)\n"
       "  If `atom` is what you meant, fix the clause, not the signature.\n"
       "  Otherwise, the signature its clauses justify:\n"
       "    public atom | (:declined, int) TakePayment(Charge c, bool card_ok)\n",
       message_body(cli("Payments", Src))).

%% F25.26 — clause advice precedes refusal to widen numeric maps to text maps.
a_checkout_leads_with_the_clause_before_the_refused_widening_test() ->
    Src = "module Checkout\n"
          "public map<string, int> CartQuantities(bool signed_in,\n"
          "                                       map<string, int> session_cart,\n"
          "                                       map<string, binary> form_fields)\n"
          "CartQuantities(true, session_cart, form_fields)  -> session_cart\n"
          "CartQuantities(false, session_cart, form_fields) -> form_fields\n",
    ?assertEqual(
       "error: CartQuantities returns a value its signature does not declare\n"
       "  not covered by the declared return type:\n"
       "    map<string, binary>\n"
       "  If `map<string, int>` is what you meant, fix the clause, not the signature.\n"
       "  Widening the signature to cover what the clauses return would be refused:\n"
       "    no clause head can tell `map<string, int>` from `map<string, binary>`\n"
       "  so if both are meant, give each a record of its own and name the pair:\n"
       "    record Name1 { Value: map<string, int> }\n"
       "    record Name2 { Value: map<string, binary> }\n"
       "    type Name = Name1 | Name2\n"
       "  declare the return as `Name`,\n"
       "  build each value as its record, and choose the names.\n",
       message_body(cli("Checkout", Src))).

%%% Record repairs and source names

%% F25.28 — the repair replaces the pair inside the declared `result`.
a_named_type_takes_the_pairs_place_inside_a_result_test() ->
    Src = "module CheckoutResult\n"
          "public result<map<string, int>, atom> CartQuantities(bool signed_in,\n"
          "    result<map<string, int>, atom> session_cart,\n"
          "    map<string, binary> form_fields)\n"
          "CartQuantities(true, session_cart, form_fields)  -> session_cart\n"
          "CartQuantities(false, session_cart, form_fields) -> form_fields\n",
    ?assertEqual(
       "error: CartQuantities returns a value its signature does not declare\n"
       "  not covered by the declared return type:\n"
       "    map<string, binary>\n"
       "  If `result<map<string, int>, atom>` is what you meant, fix the clause, not the signature.\n"
       "  Widening the signature to cover what the clauses return would be refused:\n"
       "    no clause head can tell `map<string, int>` from `map<string, binary>`\n"
       "  so if both are meant, give each a record of its own and name the pair:\n"
       "    record Name1 { Value: map<string, int> }\n"
       "    record Name2 { Value: map<string, binary> }\n"
       "    type Name = Name1 | Name2\n"
       "  declare the return as `result<Name, atom>`,\n"
       "  build each value as its record, and choose the names.\n",
       message_body(cli("CheckoutResult", Src))).

%% F25.29 — refusal advice names the alias and shows its structure.
a_refused_pair_names_the_alias_the_author_wrote_test() ->
    Src = "module Dashboard\n"
          "type ViewCounts = map<string, int>\n"
          "public ViewCounts Views(bool staff, ViewCounts stored, map<string, binary> posted)\n"
          "Views(true, stored, posted)  -> stored\n"
          "Views(false, stored, posted) -> posted\n",
    ?assertEqual(
       "error: Views returns a value its signature does not declare\n"
       "  not covered by the declared return type:\n"
       "    map<string, binary>\n"
       "  If `ViewCounts` is what you meant, fix the clause, not the signature.\n"
       "  Widening the signature to cover what the clauses return would be refused:\n"
       "    no clause head can tell `ViewCounts` from `map<string, binary>`\n"
       "    (`ViewCounts` is `map<string, int>`)\n"
       "  so if both are meant, give each a record of its own and name the pair:\n"
       "    record Name1 { Value: ViewCounts }\n"
       "    record Name2 { Value: map<string, binary> }\n"
       "    type Name = Name1 | Name2\n"
       "  declare the return as `Name`,\n"
       "  build each value as its record, and choose the names.\n",
       message_body(cli("Dashboard", Src))),
    ?assertMatch(#{indiscriminable :=
                       #{member := "ViewCounts",
                         expanded := [#{name := "ViewCounts",
                                        is := "map<string, int>"}]}},
                 term_of("Dashboard2",
                         re:replace(Src, "Dashboard", "Dashboard2", [{return, list}]))).

%% F25.30 — absorption advice names the alias and shows its structure.
an_absorbed_member_is_named_as_the_author_wrote_it_test() ->
    Src = "module AnalyticsMissing\n"
          "type ViewCounts = map<string, int>\n"
          "public ViewCounts | :not_found PageViews(list<map<string, term>> rows)\n"
          "PageViews([])            -> :not_found\n"
          "PageViews([row, ..rest]) -> row\n",
    ?assertEqual(
       "error: PageViews returns a value its signature does not declare\n"
       "  not covered by the declared return type:\n"
       "    map<string, term>\n"
       "  If `ViewCounts | :not_found` is what you meant, fix the clause, not the signature.\n"
       "  no signature is offered: widening it would leave `ViewCounts` absorbed by\n"
       "  `:not_found | map<string, term>`, and a declared type may not hold an absorbed member.\n"
       "  (`ViewCounts` is `map<string, int>`)\n",
       message_body(cli("AnalyticsMissing", Src))).

%% F25.31 — a pair inside a named type gets advice without a declaration.
%% Resolution hides the written member, so a replacement cannot be checked.
a_pair_inside_a_named_type_says_why_no_declaration_is_shown_test() ->
    Src = "module Inventory\n"
          "type Stock = map<string, int> | :not_found\n"
          "public Stock StockLevels(bool cached, Stock stored, map<string, binary> csv_row)\n"
          "StockLevels(true, stored, csv_row)  -> stored\n"
          "StockLevels(false, stored, csv_row) -> csv_row\n",
    ?assertEqual(
       "error: StockLevels returns a value its signature does not declare\n"
       "  not covered by the declared return type:\n"
       "    map<string, binary>\n"
       "  If `Stock` is what you meant, fix the clause, not the signature.\n"
       "  Widening the signature to cover what the clauses return would be refused:\n"
       "    no clause head can tell `map<string, int>` from `map<string, binary>`\n"
       "  so if both are meant, give each a record of its own and name the pair.\n"
       "  No declaration is shown: `map<string, int>` is inside `Stock`,\n"
       "  and this line does not rewrite a named type.\n",
       message_body(cli("Inventory", Src))),
    %% Reverse which member of the pair sits inside the named type.
    Posted = cli("Submissions",
                 "module Submissions\n"
                 "type Posted = map<string, binary> | :missing\n"
                 "public Posted Fields(bool parsed, Posted raw, map<string, int> counts)\n"
                 "Fields(false, raw, counts) -> raw\n"
                 "Fields(true, raw, counts)  -> counts\n"),
    ?assert(string:find(Posted, "  No declaration is shown: `map<string, binary>` is inside "
                                "`Posted`,\n") =/= nomatch).

%% F25.34 — reversing the pair still replaces the first written member.
the_named_type_takes_the_place_written_first_test() ->
    Echo = cli("FormEcho",
               "module FormEcho\n"
               "public map<string, binary> CartFields(bool signed_in,\n"
               "    map<string, int> session_cart, map<string, binary> form_fields)\n"
               "CartFields(false, session_cart, form_fields) -> form_fields\n"
               "CartFields(true, session_cart, form_fields)  -> session_cart\n"),
    ?assert(string:find(Echo, "    record Name1 { Value: map<string, binary> }\n"
                              "    record Name2 { Value: map<string, int> }\n") =/= nomatch),
    ?assert(string:find(Echo, returns("Name")) =/= nomatch),
    Result = cli("FormResult",
                 "module FormResult\n"
                 "public result<map<string, binary>, atom> CartFields(bool signed_in,\n"
                 "    map<string, int> session_cart, result<map<string, binary>, atom> form_fields)\n"
                 "CartFields(false, session_cart, form_fields) -> form_fields\n"
                 "CartFields(true, session_cart, form_fields)  -> session_cart\n"),
    ?assert(string:find(Result, "    record Name1 { Value: map<string, binary> }\n"
                                "    record Name2 { Value: map<string, int> }\n") =/= nomatch),
    ?assert(string:find(Result, returns("result<Name, atom>")) =/= nomatch).

%% F25.32 — repair placeholders avoid names the module already uses.
a_placeholder_the_module_already_uses_moves_aside_test() ->
    Src = "module People\n"
          "record Name { First: binary, Last: binary }\n" ++
          tl(lists:dropwhile(fun(C) -> C =/= $\n end,
                             pick_src("People", "map<string, int>"))),
    Out = cli("People", Src),
    ?assert(string:find(Out, "    record NewName1 { Value: map<string, int> }\n"
                             "    record NewName2 { Value: map<string, binary> }\n"
                             "    type NewName = NewName1 | NewName2\n") =/= nomatch),
    ?assert(string:find(Out, returns("NewName")) =/= nomatch),
    %% Occupy the first fallback too, so one rename cannot pass this case.
    Twice = cli("People2", "module People2\n"
                           "record Name { First: binary, Last: binary }\n"
                           "type NewName = Name | :anonymous\n" ++
                           tl(lists:dropwhile(fun(C) -> C =/= $\n end,
                                              pick_src("People2", "map<string, int>")))),
    ?assert(string:find(Twice, "    type NewNewName = NewNewName1 | NewNewName2\n") =/= nomatch).

%% F25.33 — refused repair declarations report a compiler defect.
%% No source program is known to reach these paths; both producer and
%% descriptor faults are injected directly.
a_refused_declaration_is_reported_as_a_defect_test() ->
    ?assertEqual({check_failed, indiscriminable_union},
                 bs_check:declarations_pasted(
                   ["record Name1 { Value: map<string, int> | map<string, binary> }",
                    "record Name2 { Value: int }",
                    "type Name = Name1 | Name2"],
                   "public Name Pick(int n)", #{})),
    ?assertEqual({no_records, {check_failed, unwritable}},
                 bs_check:declared_records(no_function, {t_map, []}, {t_builtin, int},
                                           {top, 1, 2}, [{t_map, []}, {t_builtin, int}], #{})),
    D = bs_diag:descriptor("m.bs", {error, 3, 'Pick',
                                    {return_not_declared,
                                     bs_types:atom_lit(oops),
                                     {"int", {refused,
                                              {"int", bs_types:int()},
                                              {"atom", bs_types:atom_top()},
                                              {no_records, {check_failed, absorbed_member}}}}}}),
    ?assertMatch(#{indiscriminable := #{no_declarations := #{refused_by := absorbed_member}}}, D),
    Prose = unicode:characters_to_list(bs_diag:format(D#{line => 3, column => 1})),
    ?assert(string:find(Prose, "  No declaration is shown: checking the one this compiler would write\n"
                               "  failed (absorbed_member), which is a compiler defect.\n") =/= nomatch).

message_body(Out) ->
    Start = string:str(Out, "error: "),
    Body = string:substr(Out, Start),
    string:substr(Body, 1, string:str(Body, "rc:") - 1).

term_of(Name, Src) ->
    with_src(Name ++ ".bs", Src,
             fun(Path, Root) ->
                     {_, Stdout, _} = bs_test_support:run_cli_split_result(
                                        "--diagnostics term --src-root " ++ Root
                                        ++ " " ++ filename:dirname(Path)),
                     {ok, Tokens, _} = erl_scan:string(Stdout ++ "."),
                     {ok, Term} = erl_parse:parse_term(Tokens),
                     Term
             end).

count_occurrences(Hay, Needle) ->
    count_occurrences(Hay, Needle, 0).

count_occurrences(Hay, Needle, N) ->
    case string:find(Hay, Needle) of
        nomatch -> N;
        Rest    -> Skip = string:slice(Rest, string:length(Needle)),
                   count_occurrences(Skip, Needle, N + 1)
    end.
