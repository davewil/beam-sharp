-module(corrected_signature_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [with_src/3, run_cli/1]).

%%% ---------------------------------------------------------------------------
%%% F25 — the return-mismatch diagnostic carries the signature to paste.
%%%
%%% Ticket 23 §8: "when a clause returns outside its signature, the diagnostic
%%% carries the corrected signature to paste." §2's line is that the compiler
%%% synthesises the head and never the body, and §4's membership test for the
%%% contractual subset is the same question: does it hand the agent something to
%%% write? Before this feature `return_not_declared` printed the uncovered
%%% residual and stopped, which answers what is WRONG and not what to WRITE.
%%%
%%% THE THREE TESTS THAT SHAPED THE FEATURE ARE 3, 4 AND 5, NOT 1. Test 1 is the
%%% happy path and a fix that only satisfies it is the plausible-but-wrong one:
%%% it prints a line per offending clause (test 3 fails), and it prints a mint
%%% tag for a record (test 4 fails) which is a line that LOOKS pasteable and is
%%% not.
%%% ---------------------------------------------------------------------------

-define(HEADING, "the signature its clauses justify:").
%% ENG-346 R2: a line that is withheld says why.
-define(UNSPELLABLE, "no signature is offered: what the clauses return has no spelling as a type yet.").

%% ENG-346 Round 3 (David: "all"): every return mismatch leads with the clause,
%% naming the declared type as the author wrote it. The signature states intent
%% and the compiler holds the clauses to it; widening is the alternative.
lead(Declared) ->
    "If `" ++ Declared ++ "` is what you meant, fix the clause, not the signature.".

%% The lead comes before anything else the correction says: the widened line,
%% the refused widening, or the reason a line is withheld.
leads(Out, Declared) ->
    Rest = [P || M <- [?HEADING, "Widening the signature", "no signature is offered"],
                 P <- [string:str(Out, M)], P > 0],
    case string:str(Out, lead(Declared)) of
        0 -> false;
        L -> Rest =:= [] orelse L < lists:min(Rest)
    end.

%% Two things this helper got wrong the first time, both of which made every
%% assertion below fail for the same uninformative reason — no output at all.
%% `place/3`'s second argument is the FILE NAME, so it needs the `.bs` extension
%% or nothing is a source file; and it answers the file it wrote, while F15 made
%% the DIRECTORY the unit of compilation, so what `bsc` is given is its dirname.
cli(Name, Src) ->
    with_src(Name ++ ".bs", Src,
             fun(Path, Root) ->
                     run_cli("--src-root " ++ Root ++ " " ++ filename:dirname(Path))
             end).

%%% ---------------------------------------------------------------------------
%%% 1 — the baseline
%%% ---------------------------------------------------------------------------

%% F25.1 — the line exists, and it is a whole signature rather than a type.
%% Pasting it over the declared line is the entire point, so the assertion is on
%% the line and not on the fragment: a fix that printed only `:oops | int` would
%% pass a substring check on the type and still leave the agent to assemble a
%% signature, which is the work §2 says the compiler owns.
a_return_mismatch_carries_the_signature_to_paste_test() ->
    Src = "module M1\npublic int Answer(int n)\nAnswer(n) -> :oops\n",
    Out = cli("M1", Src),
    ?assert(string:find(Out, ?HEADING) =/= nomatch),
    ?assert(string:find(Out, "public int | :oops Answer(int n)") =/= nomatch),
    %% Round 3: the clause first, the widened line as the alternative.
    ?assert(leads(Out, "int")),
    ?assert(string:find(Out, "Otherwise, the signature its clauses justify:") =/= nomatch).

%% F25.2 — today's message is not replaced. The residual answers "what is not
%% covered" and the new line answers "what to write"; they are different
%% questions and the first one is what ticket 04 made the product surface.
the_uncovered_residual_survives_beside_it_test() ->
    Src = "module M2\npublic int Answer(int n)\nAnswer(n) -> :oops\n",
    Out = cli("M2", Src),
    ?assert(string:find(Out, "not covered by the declared return type:") =/= nomatch).

%% ENG-328 / ticket 12 §4. `public none | term Reject(term r)` is a program
%% ticket 68 refuses, so printing it as the line to paste is ticket 23 §2's
%% failure mode — a line that looks pasteable and is not. Why the bottom is the
%% only declared type that reaches it: F38 §F38.3.
%%
%% Asserted at the CLI because that is where an author reads it, and as an
%% ABSENCE beside a presence: the `none |` check alone would pass over a run
%% that printed nothing at all.
a_none_return_is_corrected_without_an_absorbed_member_test() ->
    Src = "module M10\npublic none Reject(term r)\nReject(r) -> r\n",
    Out = cli("M10", Src),
    ?assert(string:find(Out, ?HEADING) =/= nomatch),
    ?assert(string:find(Out, "public term Reject(term r)") =/= nomatch),
    ?assertEqual(nomatch, string:find(Out, "none |")),
    %% ENG-346 R3 does not fire for the bottom: every type contains `none`, so
    %% "this replaces `none`" would be true of any line and say nothing.
    ?assertEqual(nomatch, string:find(Out, "this replaces")),
    %% Round 3: for the bottom the lead is the likelier fix, not a vacuous one —
    %% a function declared never to return has a clause that returns.
    ?assert(leads(Out, "none")).

%%% ---------------------------------------------------------------------------
%%% 3 — the correction is a property of the FUNCTION
%%% ---------------------------------------------------------------------------

%% F25.3 — MEASURED FIRST: two offending clauses produce two diagnostics. If each
%% carried its own correction the compiler would print two contradictory
%% pasteable lines — `int | :zero` and `int | (:error, string)` — and pasting
%% either leaves the other clause still wrong. One line, from the union of every
%% residual, attached to both diagnostics.
two_offending_clauses_get_one_function_wide_signature_test() ->
    Src = "module M3\npublic int Go(int n)\n"
          "Go(0) -> :zero\n"
          "Go(n) -> (:error, \"bad\")\n",
    Out = cli("M3", Src),
    Line = "public int | :zero | (:error, string) Go(int n)",
    ?assertEqual(2, count_occurrences(Out, ?HEADING)),
    ?assertEqual(2, count_occurrences(Out, Line)).

%%% ---------------------------------------------------------------------------
%%% 4 — the refusal, and it is the half a gate written after the code would miss
%%% ---------------------------------------------------------------------------

%% F25.4 — a record in the RESIDUAL has no writable spelling. `bs_types` renders
%% it as `{ Kind: :'M4.Invoice', Id: int, Total: int }`, which is a correct
%% description of the set and a bad thing to paste: ticket 26 §1 mints that tag
%% from the qualified module path, so pasting it hard-codes a mint instead of
%% naming `Invoice`. No signature is printed, and the ordinary message stands.
%%
%% THE TAG IS EXPECTED IN THE OUTPUT AND FORBIDDEN IN THE SIGNATURE, and the
%% first draft of this test asserted it was absent altogether — which forbids the
%% correct behaviour. The residual prints `{ Kind: :'M4.Invoice' }` on purpose:
%% ticket 04 made the residual the missing case and `to_pattern/1` renders the
%% discriminator deliberately. What F25 refuses is the pasteable line, so that is
%% what is asserted, and the residual is asserted PRESENT so the refusal is known
%% to have dropped one line rather than the whole diagnostic.
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
    %% ENG-346 R2: withheld, and it says why.
    ?assert(string:find(Out, ?UNSPELLABLE) =/= nomatch),
    %% Round 3: a withheld line still leads with the clause.
    ?assert(leads(Out, "Order")).

%% F25.5 — the mirror, and it is why the declared half is read from the SOURCE
%% AST rather than from the algebra. Here the record is the DECLARED type and the
%% residual is an atom: through the algebra the declared half would render as its
%% mint tag and this case would be refused too, which would be a refusal with no
%% cause. From source it is `Order`, and `Order | :oops` is exactly what the
%% author should paste.
a_declared_record_is_named_not_minted_test() ->
    Src = "module M5\n"
          "record Order { Id: int, Total: int }\n"
          "public Order Make(int n)\n"
          "Make(n) -> :oops\n",
    Out = cli("M5", Src),
    ?assert(string:find(Out, "public Order | :oops Make(int n)") =/= nomatch),
    ?assertEqual(nomatch, string:find(Out, "Kind:")).

%%% ---------------------------------------------------------------------------
%%% 6 — visibility
%%% ---------------------------------------------------------------------------

%% F25.6 — F12 made an unmarked signature private, so `public` is written exactly
%% where it is meant. A synthesised line that exported a private function would
%% be a worse defect than the one it fixes.
a_private_function_is_not_exported_by_the_pasted_line_test() ->
    Src = "module M6\n"
          "public int Entry(int n)\n"
          "Entry(n) -> Helper(n)\n"
          "int Helper(int n)\n"
          "Helper(n) -> :oops\n",
    Out = cli("M6", Src),
    ?assert(string:find(Out, "int | :oops Helper(int n)") =/= nomatch),
    ?assertEqual(nomatch, string:find(Out, "public int | :oops Helper")).

%%% ---------------------------------------------------------------------------
%%% 7 — the contractual subset
%%% ---------------------------------------------------------------------------

%% F25.7 — ticket 23 §4's membership test is §2's: does it hand the agent
%% something to write? It does now, so the tag joins the frozen subset. This is
%% the assertion that would fail if the descriptor were changed without the
%% promise being made.
return_not_declared_is_contractual_test() ->
    ?assert(lists:member(return_not_declared, bs_diag:contractual())).

%% F25.8 — the term channel carries it too, and as its own key. §1 makes the term
%% canonical and the prose a pure function of it, so a corrected signature that
%% existed only in the prose would be the wrong way round.
the_term_carries_the_corrected_signature_test() ->
    D = term_of("M9", "module M9\npublic int Answer(int n)\nAnswer(n) -> :oops\n"),
    ?assertMatch(#{tag := return_not_declared,
                   corrected := "public int | :oops Answer(int n)"}, D).

%% F25.9 — and `none` when there is nothing writable to say, rather than the key
%% going missing. A consumer matching on the key must not have to distinguish
%% "absent" from "refused". Read off the CLI's term channel for F25.4's record
%% residual, which is withheld in practice; since ENG-346's R2 the term also
%% carries why.
the_term_says_none_when_no_signature_is_offered_test() ->
    Src = "module M27\n"
          "record Order   { Id: int, Total: int }\n"
          "record Invoice { Id: int, Total: int }\n"
          "public Order Make(int n)\n"
          "Make(n) -> Invoice{ Id = n, Total = 0 }\n",
    ?assertMatch(#{tag := return_not_declared, corrected := none,
                   withheld := unspellable}, term_of("M27", Src)).

%%% ---------------------------------------------------------------------------
%%% 10 — a correction the declaration check refuses (ENG-346)
%%%
%%% Measured 2026-09-09: `Pick` declared `map<string, int>` and returning a
%%% `map<string, binary>` was told to paste
%%% `public map<string, int> | map<string, binary> Pick(int n)`, and pasting it
%%% got `no clause head can tell ...` from the declaration check, at a compile
%%% and at `--api`. Ticket 70 kept that union LEGAL-in-a-container and refused
%%% at the top, and put the objection in the advice — so the advice has to agree
%%% with the refusal, and it names the repair 09 §5 anticipated: tag the members.
%%%
%%% F25.12 and F25.13 are the tests that shaped the fix. F25.12 is the
%%% over-refusal control: `map<string, int> | :oops` is split by a guard, so a
%%% fix that withholds any line with a map in it fails there. F25.13 puts both
%%% maps in the RESIDUAL under a declared `int`, so a fix that only pairs each
%%% residual member against the declared type prints the refused line there.
%%%
%%% F25.15 and F25.16 came from the /code-review spec axis on the first fix,
%%% which asked the one refusal ticket 70 named instead of the declaration check
%%% the ticket asked for. Each is a printed line the compiler refused when
%%% pasted: an absorbed member, and a syntax error.
%%% ---------------------------------------------------------------------------

-define(REFUSED, "Widening the signature to cover what the clauses return would be refused:").
-define(TELL, "no clause head can tell `map<string, int>` from `map<string, binary>`").
-define(TAG, "so if both are meant, tag them, with atoms of your choosing:").
-define(SHAPE, "(:tag1, map<string, int>) | (:tag2, map<string, binary>)").

%% The ticket's program, with the declared return type as the variable, and
%% the type of the second clause's value as a second one.
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

%% A compile with `-o`, so a clean one writes no `.beam` into the working
%% directory. A clean compile prints nothing, so the answer is `"rc:0\n"`.
compile(Name, Src) ->
    with_src(Name ++ ".bs", Src,
             fun(Path, Root) ->
                     run_cli("--src-root " ++ Root ++ " -o " ++ Root ++ " "
                             ++ filename:dirname(Path))
             end).

%% F25.10 — the ticket's program. The residual still prints, the refused line
%% does not, and the diagnostic says why and what to do instead. Asserted as an
%% absence beside three presences, so a run that printed nothing fails.
a_correction_the_declaration_check_refuses_is_not_printed_test() ->
    Out = cli("M11", pick_src("M11", "map<string, int>")),
    ?assert(string:find(Out, "not covered by the declared return type:\n"
                             "    map<string, binary>") =/= nomatch),
    ?assertEqual(nomatch, string:find(Out, ?HEADING)),
    ?assertEqual(nomatch, string:find(Out, "map<string, int> | map<string, binary> Pick")),
    ?assert(string:find(Out, ?REFUSED) =/= nomatch),
    ?assert(string:find(Out, ?TELL) =/= nomatch),
    ?assert(string:find(Out, ?TAG) =/= nomatch),
    ?assert(string:find(Out, ?SHAPE) =/= nomatch),
    %% Round 2, answered in Round 3: the clause first, since the likelier
    %% mistake in a real checkout is the guest's quantities still being text.
    ?assert(leads(Out, "map<string, int>")),
    ?assert(string:str(Out, lead("map<string, int>")) < string:str(Out, ?REFUSED)).

%% F25.11 — the premise, at BOTH declaration sites. The line F25.10 withholds
%% is refused by a compile and by `--api`, which reaches the declaration check
%% through `exports_of/1` and never through `check/2`. When a map pattern ships
%% and the refusal lifts, this goes red, and so does F25.10: the correction is
%% pasted back through the same declaration check, so the line prints again.
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

%% F25.12 — the over-refusal control. A map beside an atom is told apart by
%% `is_map`, so the line prints — and pasting it compiles clean, which is the
%% claim the line makes.
a_union_a_guard_can_split_is_still_corrected_test() ->
    Line = "public map<string, int> | :oops Pick(int n)",
    Out = cli("M13", "module M13\npublic map<string, int> Pick(int n)\nPick(n) -> :oops\n"),
    ?assert(string:find(Out, Line) =/= nomatch),
    ?assertEqual(nomatch, string:find(Out, ?REFUSED)),
    ?assertEqual("rc:0\n", compile("M14", "module M14\n" ++ Line ++ "\nPick(n) -> :oops\n")).

%% F25.13 — both maps in the residual. `int` splits from each map by a guard,
%% so pairing residual members against the declared type alone finds nothing
%% and prints `int | map<string, int> | map<string, binary>`, which is refused.
%% Two offending clauses, so two diagnostics, and neither carries the line.
two_maps_in_the_residual_are_refused_together_test() ->
    Out = cli("M15", pick_src("M15", "int")),
    ?assertEqual(2, count_occurrences(Out, ?REFUSED)),
    ?assertEqual(2, count_occurrences(Out, ?TELL)),
    ?assertEqual(2, count_occurrences(Out, lead("int"))),
    ?assertEqual(nomatch, string:find(Out, ?HEADING)).

%% F25.14 — the term carries the pair under its own key, and `corrected` stays
%% `none`, because there is nothing to paste. The key is present on every
%% `return_not_declared`, as `none` when nothing refused the line (F25.9's rule:
%% a consumer never tells "absent" from "refused"). Read off the CLI's term
%% channel, since F16 makes the term canonical and the prose a function of it.
the_term_names_the_pair_that_refused_the_correction_test() ->
    Refused = term_of("M16", pick_src("M16", "map<string, int>")),
    ?assertMatch(#{tag := return_not_declared, corrected := none,
                   indiscriminable := #{member := "map<string, int>",
                                        beside := "map<string, binary>"},
                   withheld := none, replaces := none,
                   declared := "map<string, int>"},
                 Refused),
    Printed = term_of("M17", "module M17\npublic int Answer(int n)\nAnswer(n) -> :oops\n"),
    ?assertMatch(#{corrected := "public int | :oops Answer(int n)",
                   indiscriminable := none, withheld := none, replaces := none,
                   declared := "int"},
                 Printed).

%% F25.15 — a residual that ABSORBS the declared type. The algebra cannot
%% spell `map<string, term>` less `map<string, int>`, so the residual is
%% `map<string, term>`, which contains the declared type, and the line used to
%% read `map<string, int> | map<string, term>`: refused at the next compile as
%% an absorbed member. F38 dropped the declared half for the bottom alone,
%% arguing a residual is a complement and cannot absorb what was declared; this
%% is the case that argument missed. The line is the residual alone, and it
%% compiles when pasted.
a_residual_that_absorbs_the_declared_type_replaces_it_test() ->
    Line = "public map<string, term> Pick(int n)",
    Out = cli("M18", pick_src("M18", "map<string, int>", "map<string, term>")),
    ?assert(string:find(Out, Line) =/= nomatch),
    ?assertEqual(nomatch, string:find(Out, "map<string, int> |")),
    ?assertEqual("rc:0\n", compile("M19", pick_program("M19", Line, "map<string, term>"))),
    %% ENG-346 R3: it says the declared type is replaced, and where the fix is
    %% if that was not meant.
    ?assert(string:find(Out, "this replaces `map<string, int>`, which "
                             "`map<string, term>` contains.") =/= nomatch),
    ?assert(string:find(Out, "If `map<string, int>` is what you meant, fix the "
                             "clause, not the signature.") =/= nomatch),
    ?assertMatch(#{corrected := Line,
                   replaces := #{declared := "map<string, int>",
                                 within := "map<string, term>"}},
                 term_of("M21", pick_src("M21", "map<string, int>", "map<string, term>"))),
    %% Round 3 moves R3's closing sentence to the top.
    ?assert(leads(Out, "map<string, int>")).

%% F25.16 — the line is parsed before it is printed. A non-empty list residual
%% prints as `[map<string, binary>, ..]`, which is pattern syntax, so the line
%% would be a syntax error when pasted and none is printed. The union itself is
%% legal (ticket 70: one container level in), so nothing is refused either.
%% The residual is asserted present, so the absence is not a run that printed
%% nothing.
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
    %% ENG-346 R2: withheld, and it says why.
    ?assert(string:find(Out, ?UNSPELLABLE) =/= nomatch),
    ?assert(leads(Out, "list<map<string, int>>")).

%%% ---------------------------------------------------------------------------
%%% 11 — David's review round (ENG-346, 2026-09-10): R2, R3, R5
%%%
%%% R2: a withheld line says why, and a failure the paste-back does not name is
%%% reported as a compiler defect rather than hidden. R3: a line that replaces
%%% the declared type says so, naming it as the author wrote it. R5: the tag
%%% advice shows the tagged shape. Each proposal was put to David with its
%%% output before it was built (F25's review round).
%%% ---------------------------------------------------------------------------

%% F25.17 — the shape R5 prints, with its placeholder atoms, is a declaration
%% the compiler accepts once each clause returns its value inside its tag. The
%% advice is only right if following it compiles.
the_tag_shape_the_advice_shows_compiles_test() ->
    Src = "module M22\n"
          "public " ?SHAPE " Pick(int n)\n"
          "Pick(1) -> (:tag1, Ints())\n"
          "Pick(n) -> (:tag2, Rest())\n"
          "private map<string, int> Ints()\n"
          "Ints() -> Ints()\n"
          "private map<string, binary> Rest()\n"
          "Rest() -> Rest()\n",
    ?assertEqual("rc:0\n", compile("M22", Src)).

%% F25.18 — R2, one member of a declared union absorbed. `:none` keeps the
%% declared half in the line, and `map<string, int>` inside it is absorbed by
%% the `map<string, term>` residual. The author's text cannot be split, so the
%% line is withheld, and the diagnostic names the member and what absorbs it.
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

%% F25.19 — R2, a declared return the line cannot reproduce. `type_source/1`
%% answers `none` for an inline map, so F25 has always withheld this line
%% (its Out of scope), and until R2 it said nothing.
an_unreproducible_declared_form_says_why_it_is_withheld_test() ->
    Src = "module M25\n"
          "public { Id: int, Email: binary } FindUser(int id)\n"
          "FindUser(id) -> :not_found\n",
    Out = cli("M25", Src),
    ?assertEqual(nomatch, string:find(Out, ?HEADING)),
    ?assert(string:find(Out, "no signature is offered: the declared signature is "
                             "written in a form") =/= nomatch),
    %% The lead writes the inline type's fields in the author's order. The
    %% algebra's printer sorts them, `{ Email: binary, Id: int }`, which is a
    %% type the author did not write (the Round 3 review).
    ?assert(leads(Out, "{ Id: int, Email: binary }")),
    %% Nested, and inside a union — `{ … } | :gone` is the common shape of a
    %% lookup, and the printer would have reordered both.
    Nested = cli("M34", "module M34\n"
                        "public { Id: int, Meta: { Tag: int } } Find(int id)\n"
                        "Find(id) -> :not_found\n"),
    ?assert(leads(Nested, "{ Id: int, Meta: { Tag: int } }")),
    Either = cli("M35", "module M35\n"
                        "public { Id: int, Email: binary } | :gone Find(int id)\n"
                        "Find(id) -> :not_found\n"),
    ?assert(leads(Either, "{ Id: int, Email: binary } | :gone")).

%% F25.27 — the lead's fallback for a declared form nothing can write back.
%% No signature reaches it today (an inline refinement is a syntax error), so it
%% is fault injection through the test-only export: a form the grammar may gain
%% later is named as the algebra prints it, whole, rather than dropped.
a_declared_form_nothing_can_write_is_named_as_printed_test() ->
    ?assertEqual("int", bs_check:declared_text({t_not_a_form}, bs_types:int())).

%% F25.20 — R2, a failure the paste-back does not name. No program is known to
%% reach it: the review found two that did (F25.22, F25.23), and each is now a
%% named reason. So both halves are asserted below the CLI. The producer half
%% is fault injection: `as_pasted/2` is handed environments `type_env/1` never
%% builds, one whose entry resolves to nothing it can read (an atom reason)
%% and one that is not a map (a tuple reason). The consumer half is the
%% descriptor and its prose: the term carries the class and reason, and the
%% prose calls it a compiler defect instead of saying nothing.
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

%% F25.21 — R3 keeps F25's naming rule in the sentence: the declared type is
%% named as the author wrote it, `Counts`, not as the algebra expands it.
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

%%% ---------------------------------------------------------------------------
%%% 12 — the review of R2, R3 and R5 (ENG-346, 2026-09-10)
%%%
%%% The /code-review spec axis ran the build against programs the proposals did
%%% not list, and three printed a reason that was false.
%%% ---------------------------------------------------------------------------

%% F25.22 — a `term` body under `int`. The residual prints as
%% `atom | tuple | list<term> | map | binary`, and `tuple` and `map` are
%% printer spellings with no surface form, so the line resolves to nothing.
%% That was reported as a compiler defect; it is the unspellable case. (F38's
%% own example, `Grow(term r)`, is this program.)
a_residual_with_no_surface_form_is_unspellable_not_a_defect_test() ->
    Out = cli("M28", "module M28\npublic int Go(term r)\nGo(r) -> r\n"),
    ?assertEqual(nomatch, string:find(Out, ?HEADING)),
    ?assertEqual(nomatch, string:find(Out, "compiler defect")),
    ?assert(string:find(Out, ?UNSPELLABLE) =/= nomatch).

%% F25.23 — a recursive type from another module. It prints by the name its
%% author gave it, `Tree`, and a type's name does not cross a module boundary,
%% so the line does not resolve in `M30`. Unspellable here, not a defect. The
%% same type declared in the module itself prints a line (the control).
a_residual_named_in_another_module_is_unspellable_not_a_defect_test() ->
    Root = bs_test_support:fixture_root(),
    _ = bs_test_support:place(Root, "M29.bs",
                              "module M29\n"
                              "type Tree = :leaf | (:node, Tree, Tree)\n"
                              "public Tree Leaf()\n"
                              "Leaf() -> :leaf\n"),
    Grow = bs_test_support:place(Root, "M30.bs",
                                 "module M30\n"
                                 "using M29\n"
                                 "public int Get(int n)\n"
                                 "Get(n) -> Leaf()\n"),
    Out = run_cli("--src-root " ++ Root ++ " -o " ++ Root ++ " "
                  ++ filename:dirname(Grow)),
    ?assertEqual(nomatch, string:find(Out, "compiler defect")),
    ?assert(string:find(Out, ?UNSPELLABLE) =/= nomatch),
    Local = cli("M31", "module M31\n"
                       "type Tree = :leaf | (:node, Tree, Tree)\n"
                       "public int Get(int n)\n"
                       "Get(n) -> Leaf()\n"
                       "private Tree Leaf()\n"
                       "Leaf() -> :leaf\n"),
    ?assert(string:find(Local, "public int | :leaf | (:node, Tree, Tree) Get(int n)") =/= nomatch).

%% F25.24 — a declared atom that needs quoting. `type_source/1` wrote
%% `:'a b'` as `:a b`, the line was a syntax error, and the paste-back blamed
%% the residual. It is quoted now, so the line prints, and it compiles pasted.
a_declared_atom_that_needs_quoting_is_written_quoted_test() ->
    Line = "public int | :'a b' | :oops Go(int n)",
    Out = cli("M32", "module M32\npublic int | :'a b' Go(int n)\nGo(n) -> :oops\n"),
    ?assert(string:find(Out, Line) =/= nomatch),
    ?assertEqual("rc:0\n", compile("M33", "module M33\n" ++ Line ++ "\nGo(n) -> :oops\n")).

%%% ---------------------------------------------------------------------------
%%% 13 — Round 3, whole messages for programs someone would write
%%%
%%% David, 2026-09-11: "all" — every return mismatch leads with the clause. The
%%% two programs are from `wayfinder/prototypes/f25-corrected-signature-in-
%%% real-code.md` and F25's Round 3, and each message is asserted whole, since
%%% it is what the author reads: one where widening is the right fix, so the
%%% line must survive below the lead, and one where widening is refused.
%%% ---------------------------------------------------------------------------

%% F25.25 — a payment handler that declared the happy path only.
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

%% F25.26 — the checkout page from ENG-346, where the guest's quantities are
%% still text. The clause is the likelier fix; tagging is for when both
%% representations are meant.
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
       "  so if both are meant, tag them, with atoms of your choosing:\n"
       "    (:tag1, map<string, int>) | (:tag2, map<string, binary>)\n"
       "  and return each value inside its tag.\n",
       message_body(cli("Checkout", Src))).

%% The diagnostic from its `error:`, without the path and position before it
%% or the `rc:` line `run_cli/1` appends.
message_body(Out) ->
    Start = string:str(Out, "error: "),
    Body = string:substr(Out, Start),
    string:substr(Body, 1, string:str(Body, "rc:") - 1).

%% One diagnostic, so one line on stdout. Parsing it back is what proves it is
%% a term (F16).
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

%%% ---------------------------------------------------------------------------

count_occurrences(Hay, Needle) ->
    count_occurrences(Hay, Needle, 0).

count_occurrences(Hay, Needle, N) ->
    case string:find(Hay, Needle) of
        nomatch -> N;
        Rest    -> Skip = string:slice(Rest, string:length(Needle)),
                   count_occurrences(Skip, Needle, N + 1)
    end.
