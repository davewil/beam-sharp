%%% F36 / ENG-332 — ticket 68's two declaration refusals.
%%%
%%% TICKET 68 RESOLVED TWO RULES ON 2026-09-06, and they are separate rules with
%%% separate sentences because their repairs differ in kind:
%%%
%%%   ABSORPTION      - any member `M` where `M ⊆ union(others)` is refused where
%%%                     it is written. This GENERALISES F31, which asked the same
%%%                     question of `:nothing` and `(:error, E)` alone. The
%%%                     predicate is unchanged (`absorbed/2`); the
%%%                     `failure_channel/1` filter in front of it is what goes.
%%%   INDISCRIMINABILITY - a union no clause head can take apart is refused. This
%%%                     is ticket 09 §4, built at last, with the criterion 68
%%%                     Q2(a) corrected: reachability by a CLAUSE HEAD, pattern
%%%                     or guard, not 09 §4's own "a BEAM guard", which refuses
%%%                     `list<int> | list<binary>` that the same section accepts.
%%%
%%% THE TWO RULES ARE ORDERED AND THE ORDER IS LOAD-BEARING. Absorption raises
%%% first, so indiscriminability only ever sees members that survive
%%% normalisation. That is 09 §4's own "normalise first, then check pairwise"
%%% rule, and it is what stops `:ok | atom` — 09 §4's named FALSE POSITIVE —
%%% from being reported as indiscriminable.
%%%
%%% WHY THE CONTROLS OUTNUMBER THE REFUSALS. Ticket 20:389 warns that
%%% "subsumption is not indiscriminability, and conflating them would reject a
%%% legal type", and 09 §4's stated criterion does exactly that to its own
%%% accepted example. So every accepted shape in the ticket is asserted here as
%%% a control; a wrong implementation of rule 2 passes every refusal test in
%%% this file and fails the controls.
-module(absorbed_member_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [check_only/1]).

%%% ---------------------------------------------------------------------------
%%% Helpers
%%% ---------------------------------------------------------------------------

%% A module whose only interesting feature is one type alias.
alias(Mod, Body) ->
    "module " ++ Mod ++ "\n\n"
    "type T = " ++ Body ++ "\n\n"
    "public int Go(int id)\n"
    "Go(id) -> id\n".

%% A module carrying arbitrary declarations plus a trivial function, so that
%% what is asserted is the DECLARATION pass and never a body.
decls(Mod, Decls) ->
    "module " ++ Mod ++ "\n\n" ++ Decls ++ "\n\n"
    "public int Go(int id)\n"
    "Go(id) -> id\n".

%%% ---------------------------------------------------------------------------
%%% F36.1 — ABSORPTION, outside the failure channel.
%%%
%%% The four shapes ENG-273 measured. All four resolve to a single member and
%%% reported ZERO diagnostics before this feature; all four are refused now.
%%% ---------------------------------------------------------------------------

%% Round 2's worked case, and the one that decided the message. The normalised
%% type is `binary`, so the mechanical repair is `type T = binary` — and that is
%% almost certainly NOT what the author meant. The compiler knows the type and
%% cannot know the intent, which is why the hint is a fork rather than a fix.
binary_absorbs_string_test() ->
    ?assertError({absorbed_member, _, _, none, _, _},
                 check_only(alias("A1", "binary | string"))).

%% 09 §4's own named false positive for rule 2, and rule 1's plain case: the
%% singleton is absorbed by the cofinite set it sits beside.
cofinite_atom_absorbs_a_singleton_test() ->
    ?assertError({absorbed_member, _, _, none, _, _},
                 check_only(alias("A2", "atom | :ok"))).

%% The cost round 1 accepted in as many words: "a union that is only ever
%% passed through can no longer be written un-named".
term_absorbs_int_test() ->
    ?assertError({absorbed_member, _, _, none, _, _},
                 check_only(alias("A3", "term | int"))).

%% ABSORPTION REACHES THROUGH A CONTAINER, because `is_subtype/2` does. An
%% implementation that compares only the members' outermost constructor accepts
%% this: both members are lists.
list_of_term_absorbs_list_of_int_test() ->
    ?assertError({absorbed_member, _, _, none, _, _},
                 check_only(alias("A4", "list<term> | list<int>"))).

%%% ---------------------------------------------------------------------------
%%% F36.2 — THE FAILURE-CHANNEL HINT SURVIVES.
%%%
%%% Round 2: F31's wording is "a third hint variant under that tag, not a tag of
%%% its own". Its harm sentence is a specialisation of "a member you wrote is
%%% not in the type" and its hint is too specific to lose, so the tag is one and
%%% the hint is three. These two assert the DISCRIMINATOR, not the prose: a
%%% widening that dropped the channel would still pass F36.1.
%%% ---------------------------------------------------------------------------

option_at_an_atom_top_keeps_the_nothing_hint_test() ->
    ?assertError({absorbed_member, _, _, nothing, _, _},
                 check_only(alias("A5", "option<atom>"))).

result_over_term_keeps_the_error_hint_test() ->
    ?assertError({absorbed_member, _, _, error, _, _},
                 check_only(alias("A6", "result<term, atom>"))).

%%% ---------------------------------------------------------------------------
%%% F36.3 — THE PATH. Round 3 Q5(b).
%%%
%%% No type-expression node carries a line (`bs_check.erl:595-596`), so a record
%%% with two absorbing fields gets two diagnostics on ONE line, and under F31's
%%% declaration-only wording they differ only in the member name. The path is
%%% how the position arrives, since it cannot arrive as a line number.
%%% ---------------------------------------------------------------------------

a_record_field_names_the_field_test() ->
    ?assertError({absorbed_member, _, "Job.Tag", _, _, _},
                 check_only(decls("A7", "record Job { Id: int, Tag: atom | :urgent }"))).

%% THE CONTROL FOR THE PATH, and the shape Q5 was asked about. Two `atom`-typed
%% fields in one record is ordinary; declaration-only wording cannot tell the
%% author which one to edit. Same record, same absorber, DIFFERENT field — so a
%% path hardcoded to the declaration, or to whichever field happens to be
%% first, fails exactly one of this pair.
the_path_follows_the_field_that_absorbs_test() ->
    ?assertError({absorbed_member, _, "Job.Owner", _, _, _},
                 check_only(decls("A8",
                                  "record Job { Id: int, Owner: atom | :nobody }"))).

%% A tuple component, one level down. F31 reported at the declaration for every
%% one of these; the path is what distinguishes them.
a_tuple_component_names_its_position_test() ->
    ?assertError({absorbed_member, _, "Route.x.1", _, _, _},
                 check_only(decls("A9",
                                  "public string Route((atom | :ok, int) x)\n"
                                  "Route(x) -> \"ok\""))).

%%% ---------------------------------------------------------------------------
%%% F36.4 — THE SITE. Every position a union can be written in.
%%%
%%% ENG-331 made a union writable wherever a type is — `param`, `signature` and
%%% `foreign_sig` all take a `type_expr`. Round 3 Q6(a) widened this rule to
%%% cover the BARE inline union that change created, not only the four nested
%%% positions that parsed before it.
%%% ---------------------------------------------------------------------------

a_bare_inline_union_in_a_parameter_test() ->
    ?assertError({absorbed_member, _, _, _, _, _},
                 check_only(decls("A10",
                                  "public string H(atom | :ok x)\n"
                                  "H(x) -> \"ok\""))).

a_bare_inline_union_in_a_return_test() ->
    ?assertError({absorbed_member, _, _, _, _, _},
                 check_only(decls("A11",
                                  "public atom | :ok Go2(int n)\n"
                                  "Go2(n) -> :ok"))).

a_bare_inline_union_in_a_foreign_signature_test() ->
    ?assertError({absorbed_member, _, _, _, _, _},
                 check_only(decls("A12",
                                  "using :erlang {\n"
                                  "    atom | :ok node()\n"
                                  "}"))).

%%% ---------------------------------------------------------------------------
%%% F36.5 — INDISCRIMINABILITY. Ticket 09 §4, built.
%%%
%%% The subject arrived through ticket 48, which shipped `map<K, V>` with no
%%% pattern form. So the language has a union that can be declared, passed and
%%% returned and NEVER taken apart — and this refusal is temporary by
%%% construction: `Slot` becomes legal the day a map pattern form ships.
%%% ---------------------------------------------------------------------------

two_domain_maps_cannot_be_told_apart_test() ->
    ?assertError({indiscriminable_union, _, _, _, _},
                 check_only(alias("A13", "map<string, int> | map<string, binary>"))).

%%% ---------------------------------------------------------------------------
%%% F36.6 — THE CONTROLS. Every shape ticket 68 accepts.
%%%
%%% 09 §4's LITERAL criterion — "a BEAM guard" — refuses the first of these,
%%% which 09 §4 itself lists as accepted. Q2(a) corrected the criterion to
%%% reachability by a clause head; these four are what that correction buys, and
%%% each must COMPILE.
%%% ---------------------------------------------------------------------------

%% 09 §4's own accepted example, and the one its stated criterion contradicts.
%% No guard reaches inside a container; a PATTERN does — `[h, ..]` binds the
%% element and a guard on `h` decides it.
two_lists_are_discriminable_by_pattern_test() ->
    ?assertMatch({ok, _, _}, check_only(alias("A14", "list<int> | list<binary>"))).

%% Two bare binders in DIFFERENT buckets. The guard half of the oracle is a
%% table of the BEAM's own vocabulary — `is_atom`, `is_integer` — and does not
%% go stale, because it is not the language's vocabulary.
an_atom_and_an_int_are_discriminable_by_guard_test() ->
    ?assertMatch({ok, _, _}, check_only(alias("A15", "atom | int"))).

tagged_tuples_are_discriminable_test() ->
    ?assertMatch({ok, _, _}, check_only(alias("A16", "(:a, int) | (:b, binary)"))).

%% A DOMAIN MAP IS NOT INDISCRIMINABLE ON ITS OWN. It has no pattern, but
%% `is_map` tells it from an int perfectly well. An implementation that refuses
%% every union containing a domain map passes F36.5 and fails here.
a_domain_map_beside_an_int_is_discriminable_test() ->
    ?assertMatch({ok, _, _}, check_only(alias("A17", "map<string, int> | int"))).

%% THE GUARDED-BINDER CONTROL. Two disjoint refined ints are both "an int" to
%% the bucket table and neither has a structural pattern, so an oracle that
%% knows only binder/shape refuses them. A clause head decides them with a
%% guard — which is half of Q2(a)'s criterion — and at a NESTED position that
%% is exactly how the printer already spells them: `n when n >= 10`.
disjoint_refined_ints_are_discriminable_by_guard_test() ->
    Src = decls("A18",
                "type Low = int where value >= 0 and value <= 9\n"
                "type High = int where value >= 10 and value <= 99\n"
                "type Pair = (Low | High, atom)"),
    ?assertMatch({ok, _, _}, check_only(Src)).

%% The same union NOT nested, where the printer spells each member as a
%% relational pattern instead. Both positions must reach the same verdict.
disjoint_refined_ints_at_the_top_are_discriminable_test() ->
    Src = decls("A19",
                "type Low = int where value >= 0 and value <= 9\n"
                "type High = int where value >= 10 and value <= 99\n"
                "type Span = Low | High"),
    ?assertMatch({ok, _, _}, check_only(Src)).

%% Records carry a discriminator, which is a pattern. This is the shape the
%% whole language is built around, and a rule 2 that refused it would be caught
%% by every example in the corpus — so it is asserted here where the reason is
%% written down rather than left to the corpus to notice.
two_records_are_discriminable_test() ->
    Src = decls("A20",
                "record Order { Id: int }\n"
                "record Invoice { Id: int }\n"
                "type Doc = Order | Invoice"),
    ?assertMatch({ok, _, _}, check_only(Src)).
