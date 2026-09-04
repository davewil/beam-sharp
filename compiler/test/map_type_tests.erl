%%% Ticket 48 — `map<K, V>`: THE TYPE, AND NOT YET THE PATTERN FORM.
%%%
%%% 48 Q2 is the scope line and it was chosen with the reasoning recorded, so it
%%% is asserted here rather than left to be rediscovered: `map<K, V>` can be
%%% DECLARED, PASSED, STORED and RETURNED; it cannot be DESTRUCTURED in a clause
%%% head. The expensive half of the feature is matchability, not existence —
%%% `subtract/2` is driven by residual computation, so a type no pattern narrows
%%% never reaches `m_decompose/3`.
%%%
%%% THE ALGEBRA GAINS A THIRD MEMBER KIND, NOT A WIDER PRODUCT. 48 Q1: a
%%% `{closed | open, #{atom() => ty()}}` member is a finite product keyed by
%%% atom, and `maps:keys/1` has something to enumerate. A domain member is one
%%% uniform rule over unboundedly many keys, so `same_keys/2` and `keys_subset/2`
%%% cannot decide it at all. Q7 fixes the shape — in `Descr` the named-key and
%%% domain-key maps are THE SAME CONSTRUCTOR WITH A DIFFERENT TAG VALUE, not two
%%% constructors — so this is `{dom, K, V}` beside `{closed, F}` and `{open, F}`.
%%%
%%% BOTH OF THIS FEATURE'S HAZARDS FAIL SILENT, WHICH IS WHY EACH HAS A TEST OF
%%% ITS OWN RATHER THAN BEING LEFT TO A PASSING SUITE:
%%%
%%%   * `m_empty/2` reads "any field type is `none` ⇒ the member is empty",
%%%     which is right for a NAMED field (it must be present) and WRONG for a
%%%     domain (`#{}` inhabits `map<atom, none>` vacuously). Reusing it would
%%%     make the type uninhabited and every containment over it pass vacuously —
%%%     `is_none/1`'s own comment names this class and its verification method.
%%%   * `map_cases/1` in `bs_emit` builds its worklist as
%%%     `[M || M = {closed,_} <- Members] ++ [M || M = {open,_} <- Members]`, so
%%%     a third kind is DROPPED rather than crashing, and a generated validator
%%%     would check nothing and pass everything.
%%%
%%% Driven through the CLI rather than over `bs_types` directly, for the reason
%%% CLAUDE.md gives: the subject is what a program is allowed to say, and that
%%% survives a behaviour-preserving refactor of the algebra underneath it.

-module(map_type_tests).

-include_lib("eunit/include/eunit.hrl").

%%% ---------------------------------------------------------------------------
%%% Helpers — `reserved_qualifier_tests`'s shape
%%% ---------------------------------------------------------------------------

in_dir(Files) ->
    Root = bs_test_support:fixture_root(),
    Paths = [bs_test_support:place(Root, N, S) || {N, S} <- Files],
    {Root, hd(Paths)}.

compile_set(Files) ->
    {Root, Main} = in_dir(Files),
    bs_test_support:run_cli("--src-root " ++ Root ++ " -o " ++ Root
                            ++ "/out " ++ Main).

ok_rc(Out)  -> ?assert(string:find(Out, "rc:0") =/= nomatch).
bad_rc(Out) -> ?assert(string:find(Out, "rc:1") =/= nomatch).
has(Out, S) -> ?assert(string:find(Out, S) =/= nomatch).

caller(Body) -> {"P.bs", "module P\n" ++ Body}.

%%% ---------------------------------------------------------------------------
%%% Cell 1 — the type resolves in every position Q2 grants it
%%% ---------------------------------------------------------------------------

%% The issue's own probe, verbatim. It is the one line that was refused for nine
%% days with the decision already taken.
map_resolves_as_a_parameter_type_test() ->
    ok_rc(compile_set([caller("public int Use(map<atom, term> x)\n"
                              "Use(x) -> 0\n")])).

map_resolves_in_return_position_test() ->
    ok_rc(compile_set([caller("public map<atom, term> Go(map<atom, term> x)\n"
                              "Go(x) -> x\n")])).

%% `type Assigns = map<atom, term>` is the shape ticket 48's own question was
%% written in, and an alias body is a different resolution path from a bare
%% parameter type — F6's substitution runs before `bs_types` sees anything.
map_resolves_through_an_alias_test() ->
    ok_rc(compile_set([caller("type Assigns = map<atom, term>\n\n"
                              "public int Use(Assigns x)\n"
                              "Use(x) -> 0\n")])).

%% Stored: a record field. 26 §4 closes the record, and the field's type is
%% resolved by the same walk, so this asks whether the new member survives being
%% nested rather than whether it resolves at top level.
map_resolves_as_a_record_field_test() ->
    ok_rc(compile_set([caller("record Bag { Items: map<atom, term> }\n\n"
                              "public int Use(Bag b)\n"
                              "Use(b) -> 0\n")])).

%%% ---------------------------------------------------------------------------
%%% Cell 2 — arity, and the diagnostic it earns
%%% ---------------------------------------------------------------------------

%% `list<T>` is arity-1 and says so with a dedicated error rather than falling
%% through to `unknown_generic`. `map<K, V>` is arity-2 and owes the same.
map_with_one_argument_is_refused_test() ->
    Out = compile_set([caller("public int Use(map<atom> x)\n"
                              "Use(x) -> 0\n")]),
    bad_rc(Out),
    has(Out, "map").

%%% ---------------------------------------------------------------------------
%%% Cell 3 — subtyping, which routes through `m_minus` even with no pattern form
%%% ---------------------------------------------------------------------------
%%%
%%% `is_subtype(A, B) -> is_none(subtract(A, B))` (`bs_types:431`), so EVERY
%%% parameter pass goes through map subtraction. Deferring the pattern form does
%%% not spare the subtraction cells; it only spares `m_decompose/3`.

%% Reflexive: the same domain passes to itself. If this fails, nothing can be
%% passed anywhere and the type is decorative.
map_passes_to_the_same_map_test() ->
    ok_rc(compile_set([caller("public int Take(map<atom, term> x)\n"
                              "Take(x) -> 0\n\n"
                              "public int Go(map<atom, term> x)\n"
                              "Go(x) -> Take(x)\n")])).

%% Covariant in the value: `map<atom, int>` is a `map<atom, term>`.
map_is_covariant_in_its_value_test() ->
    ok_rc(compile_set([caller("public int Take(map<atom, term> x)\n"
                              "Take(x) -> 0\n\n"
                              "public int Go(map<atom, int> x)\n"
                              "Go(x) -> Take(x)\n")])).

%% THE CONTROL FOR THE ONE ABOVE, and without it a `m_minus` that returns `[]`
%% unconditionally passes every subtyping test in this file. The widening is a
%% one-way street: a `map<atom, term>` is not a `map<atom, int>`.
map_is_not_contravariant_in_its_value_test() ->
    bad_rc(compile_set([caller("public int Take(map<atom, int> x)\n"
                               "Take(x) -> 0\n\n"
                               "public int Go(map<atom, term> x)\n"
                               "Go(x) -> Take(x)\n")])).

%%% ---------------------------------------------------------------------------
%%% Cell 4 — Q3, `Kind` absent only, and it is the boundary between the two kinds
%%% ---------------------------------------------------------------------------

%% A RECORD IS NOT A `map<K, V>`. Q3 decided the exclusion is `Kind` absent
%% only, and a record is `{closed, #{'Kind' => atom_lit(Tag), ...}}` — so the
%% exclusion is decidable by `maps:is_key('Kind', Fields)` rather than needing a
%% fourth field on the member.
%%
%% This is the cell that makes Q3 mean anything. If it passes, `map<atom, term>`
%% has quietly become "any map at all", which is `map_part()`'s `top` and the
%% imprecision 48 says this feature exists to sit between.
a_record_is_not_a_domain_map_test() ->
    bad_rc(compile_set([caller("record Order { Status: int }\n\n"
                               "public int Take(map<atom, term> x)\n"
                               "Take(x) -> 0\n\n"
                               "public int Go(Order o)\n"
                               "Go(o) -> Take(o)\n")])).

%%% ---------------------------------------------------------------------------
%%% Cell 5 — Q2's refusal, stated rather than crashed
%%% ---------------------------------------------------------------------------

%% The pattern form is DEFERRED, not absent-by-accident, so it owes a diagnostic
%% that says so. A `badmatch` from a function clause that never learned the third
%% kind would satisfy `bad_rc` while telling the author nothing.
destructuring_a_domain_map_is_refused_with_a_reason_test() ->
    Out = compile_set([caller("public term Use(map<atom, term> x)\n"
                              "Use({ Status: s }) -> s\n")]),
    bad_rc(Out),
    has(Out, "map<atom, term>").

%%% ---------------------------------------------------------------------------
%%% Cell 6 — the two silent hazards named in the header
%%% ---------------------------------------------------------------------------

%% THE ONE UNIT TEST IN THIS FILE, AND THE REASON IS THAT THE BOUNDARY CANNOT
%% REACH THIS EDGE. `map<atom, none>` is not writable in B# at all: ticket 15 §1
%% refuses an empty type at its declaration ("this refinement admits no values at
%% all"), and ticket 63 left negation with no spelling, so there is no source
%% text that puts an empty type in the value position. CLAUDE.md allows a unit
%% test exactly here — a complex algorithm whose edge the public surface cannot
%% reach.
%%
%% The edge is real even though the surface cannot spell it: `m_meet/3`
%% intersects the two value types, and `map<atom, int>` meeting
%% `map<atom, string>` produces a domain member whose value is `none`. If
%% `m_empty/2` reused the named-field rule, that member would report EMPTY and
%% the algebra would conclude the two map types are disjoint — when in fact `#{}`
%% inhabits both, which is what makes them overlap.
a_domain_member_with_an_empty_value_is_still_inhabited_test() ->
    Dom = bs_types:map_dom(bs_types:atom_top(), bs_types:none()),
    ?assertNot(bs_types:is_none(Dom)).

%% The same fact one level up, through the operation that actually produces it.
%% Two domain maps with disjoint value types still share the empty map.
two_domain_maps_with_disjoint_values_overlap_test() ->
    A = bs_types:map_dom(bs_types:atom_top(), bs_types:int()),
    B = bs_types:map_dom(bs_types:atom_top(), bs_types:string()),
    ?assertNot(bs_types:is_none(bs_types:intersect(A, B))).

%% `ValidateAs<T>` generates a deep validator by walking the members. A third
%% kind is DROPPED by `map_cases/1`'s two comprehensions rather than crashing, so
%% the generated validator would accept anything at all. Until the domain walk is
%% built, this must be an explicit refusal.
validate_as_over_a_domain_map_is_refused_test() ->
    Out = compile_set([caller("type Assigns = map<atom, term>\n\n"
                              "public term Go(term t)\n"
                              "Go(t) -> ValidateAs<Assigns>(t)\n")]),
    bad_rc(Out).

%%% ---------------------------------------------------------------------------
%%% Cell 7 — how it prints
%%% ---------------------------------------------------------------------------

%% The residual and every diagnostic that names a type read `to_string/1`. A
%% member kind with no printer prints as an Erlang term and leaks the algebra
%% into the author's error message.
%%
%% F25's corrected signature is the site that names the type the author WROTE
%% rather than the one they supplied — an argument-side diagnostic prints the
%% argument, so it would pass this test without the printer ever running.
a_domain_map_prints_as_it_is_written_test() ->
    Out = compile_set([caller("public map<atom, int> Go(int n)\n"
                              "Go(n) -> n\n")]),
    bad_rc(Out),
    has(Out, "map<atom, int>").
