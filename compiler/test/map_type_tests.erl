%%% Scenarios: compiler/features/F33-map-type.md
%%% Two silent hazards: an empty value type does not empty a domain map;
%%% the empty map still inhabits it. Filtering map_cases/1 to named-field
%%% maps alone silently drops domain members from the validator cases.
-module(map_type_tests).

-include_lib("eunit/include/eunit.hrl").

%%% Helpers

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

%%% Type positions

map_resolves_as_a_parameter_type_test() ->
    ok_rc(compile_set([caller("public int Use(map<atom, term> x)\n"
                              "Use(x) -> 0\n")])).

map_resolves_in_return_position_test() ->
    ok_rc(compile_set([caller("public map<atom, term> Go(map<atom, term> x)\n"
                              "Go(x) -> x\n")])).

map_resolves_through_an_alias_test() ->
    ok_rc(compile_set([caller("type Assigns = map<atom, term>\n\n"
                              "public int Use(Assigns x)\n"
                              "Use(x) -> 0\n")])).

map_resolves_as_a_record_field_test() ->
    ok_rc(compile_set([caller("record Bag { Items: map<atom, term> }\n\n"
                              "public int Use(Bag b)\n"
                              "Use(b) -> 0\n")])).

%%% Arity

map_with_one_argument_is_refused_test() ->
    Out = compile_set([caller("public int Use(map<atom> x)\n"
                              "Use(x) -> 0\n")]),
    bad_rc(Out),
    has(Out, "map").

%%% Subtyping

map_passes_to_the_same_map_test() ->
    ok_rc(compile_set([caller("public int Take(map<atom, term> x)\n"
                              "Take(x) -> 0\n\n"
                              "public int Go(map<atom, term> x)\n"
                              "Go(x) -> Take(x)\n")])).

map_is_covariant_in_its_value_test() ->
    ok_rc(compile_set([caller("public int Take(map<atom, term> x)\n"
                              "Take(x) -> 0\n\n"
                              "public int Go(map<atom, int> x)\n"
                              "Go(x) -> Take(x)\n")])).

%% Value widening is one-way; accepting this would erase the value constraint.
map_is_not_contravariant_in_its_value_test() ->
    bad_rc(compile_set([caller("public int Take(map<atom, int> x)\n"
                               "Take(x) -> 0\n\n"
                               "public int Go(map<atom, term> x)\n"
                               "Go(x) -> Take(x)\n")])).

%%% Records and domain maps

%% A record carries `Kind`, which domain maps exclude.
a_record_is_not_a_domain_map_test() ->
    bad_rc(compile_set([caller("record Order { Status: int }\n\n"
                               "public int Take(map<atom, term> x)\n"
                               "Take(x) -> 0\n\n"
                               "public int Go(Order o)\n"
                               "Go(o) -> Take(o)\n")])).

%%% Pattern refusals

%% A nonzero exit alone could also be a compiler crash.
destructuring_a_domain_map_is_refused_with_a_reason_test() ->
    Out = compile_set([caller("public term Use(map<atom, term> x)\n"
                              "Use({ Status: s }) -> s\n")]),
    bad_rc(Out),
    has(Out, "map<atom, term>"),
    has(Out, "a clause head").

%% Binding the whole value wraps the map pattern; the refusal must reach it.
the_bind_whole_spelling_is_refused_too_test() ->
    Out = compile_set([caller("public term Use(map<atom, term> x)\n"
                              "Use({ Status: s } whole) -> s\n")]),
    bad_rc(Out),
    has(Out, "a clause head").

%% An unsupported arm must be an error; a vacuous_arm warning permits a build.
destructuring_a_domain_map_in_a_switch_arm_is_refused_test() ->
    Out = compile_set([caller("public term Use(map<atom, term> x)\n"
                              "Use(x) -> x switch {\n"
                              "    { Status: s } => s,\n"
                              "    _ => 0\n"
                              "}\n")]),
    bad_rc(Out),
    has(Out, "a switch arm"),
    has(Out, "the subject's type is").

%% Destructuring a record is legal beside a map parameter that only binds.
a_record_pattern_beside_a_bound_map_is_accepted_test() ->
    ok_rc(compile_set([caller("record Order { Status: int }\n\n"
                              "public int Use(Order o, map<atom, term> x)\n"
                              "Use({ Status: s }, x) -> s\n")])).

%% A record is outside the domain, so this needs the ordinary mismatch message.
a_record_pattern_against_a_domain_map_keeps_the_ordinary_message_test() ->
    Out = compile_set([caller("record Order { Status: int }\n\n"
                              "public term Use(map<atom, term> x)\n"
                              "Use(Order o) -> 1\n")]),
    bad_rc(Out),
    ?assert(string:find(Out, "destructures a map") =:= nomatch).

%%% Empty values and union absorption

%% An empty map inhabits a domain even when no value can inhabit its value type.
%% Source declarations reject empty types, so this edge uses the algebra.
a_domain_member_with_an_empty_value_is_still_inhabited_test() ->
    Dom = bs_types:map_dom(bs_types:atom_top(), bs_types:none()),
    ?assertNot(bs_types:is_none(Dom)).

%% Disjoint value types still share the empty map.
two_domain_maps_with_disjoint_values_overlap_test() ->
    A = bs_types:map_dom(bs_types:atom_top(), bs_types:int()),
    B = bs_types:map_dom(bs_types:atom_top(), bs_types:string()),
    ?assertNot(bs_types:is_none(bs_types:intersect(A, B))).

%% Alias diagnostics hide union members behind the alias name.
%% Inspect the algebra to distinguish absorption from record exclusion.
a_kindless_map_is_absorbed_by_a_domain_test() ->
    I  = bs_types:int(),
    Pt = bs_types:map_closed(#{'X' => I, 'Y' => I}),
    D  = bs_types:map_dom(bs_types:atom_top(), bs_types:term()),
    ?assertEqual("map<atom, term>",
                 bs_types:to_string(bs_types:union(Pt, D))).

a_record_survives_beside_a_domain_test() ->
    Rec = bs_types:map_closed(#{'Kind' => bs_types:atom_lit('Z.Order'),
                                'S'    => bs_types:int()}),
    D   = bs_types:map_dom(bs_types:atom_top(), bs_types:term()),
    ?assertEqual("{ Kind: :'Z.Order', S: int } | map<atom, term>",
                 bs_types:to_string(bs_types:union(Rec, D))).

validate_as_over_a_domain_map_compiles_test() ->
    Out = compile_set([caller("type Assigns = map<atom, term>\n\n"
                              "public result<Assigns, ValidationError> Go(term t)\n"
                              "Go(t) -> ValidateAs<Assigns>(t)\n")]),
    ok_rc(Out).

%%% Type printing

%% A return mismatch prints the declared map type; an argument mismatch can
%% print only the supplied type and bypass the map printer.
a_domain_map_prints_as_it_is_written_test() ->
    Out = compile_set([caller("public map<atom, int> Go(int n)\n"
                              "Go(n) -> n\n")]),
    bad_rc(Out),
    has(Out, "map<atom, int>").
