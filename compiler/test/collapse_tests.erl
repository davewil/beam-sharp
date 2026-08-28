%%% F31 / ENG-272 — a declared failure channel must survive normalisation.
%%%
%%% TICKET 15 §1 DECIDED THIS ON 2026-08-12 AND F18 BUILT IT AT ONE SITE. The
%%% `ValidateAs<T>` obligation got the predicate; every ordinary declaration did
%%% not, and `bs_diag.erl:280` recorded the gap in a comment rather than closing
%%% it — "met at an instantiation rather than at a declaration".
%%%
%%% THE REFUSALS CANNOT LIVE IN `examples/`, which is why this file exists at
%%% all: every example must compile, and a capability whose whole behaviour is a
%%% rejection has nowhere else to be looked at.
%%%
%%% WHAT IS ASSERTED, AND WHY IT IS NOT ONE TEST. The check has two independent
%%% axes and a test that fixed one of them would pass under a wrong
%%% implementation of the other:
%%%
%%%   the SHAPE  - which types collapse. 15 §1 names its own wrong fix ("an
%%%                implementer would write the cofinite check alone"), so
%%%                `option<option<int>>` and `result<(atom, binary), binary>`
%%%                are asserted beside `option<atom>`. Neither has an atom top.
%%%   the SITE   - where a written type is checked. Five declaration forms carry
%%%                one, and each was measured to collapse on master before this
%%%                feature; a check wired to `signature` alone passes every
%%%                shape test in this file.
-module(collapse_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [check_only/1, build_and_load/2]).

%%% ---------------------------------------------------------------------------
%%% Helpers
%%% ---------------------------------------------------------------------------

%% A module whose only interesting feature is the RETURN type of one function.
ret(Mod, Ty) -> ret(Mod, Ty, "").

ret(Mod, Ty, Extra) ->
    "module " ++ Mod ++ "\n\n" ++
        case Extra of "" -> ""; _ -> Extra ++ "\n\n" end ++
        "public " ++ Ty ++ " Go(int id)\n"
        "Go(id) -> :nothing\n".

%%% ---------------------------------------------------------------------------
%%% F31.1 — THE SHAPE. Which types collapse, and which must not.
%%% ---------------------------------------------------------------------------

%% 15 §1's worked case. `:nothing` is a singleton absorbed by a cofinite top, so
%% the declared type IS `atom` and no caller can write the failure clause.
option_at_the_atom_top_is_refused_test() ->
    ?assertError({collapsed_failure_channel, _, nothing, _, _},
                 check_only(ret("S3", "option<atom>"))).

%% CONTROL 1, and the reason the predicate is an equation rather than a case
%% list. There is no atom top anywhere here: the outer `:nothing` is absorbed by
%% the INNER union, which already contains one. An implementation that checks
%% for a cofinite atom accepts this.
nested_option_is_refused_though_no_top_is_involved_test() ->
    ?assertError({collapsed_failure_channel, _, nothing, _, _},
                 check_only(ret("S4", "option<option<int>>"))).

%% Ticket 64 / ENG-254's measured case, and this feature decides it by
%% construction: the silent collapse becomes a loud refusal.
option_at_term_is_refused_test() ->
    ?assertError({collapsed_failure_channel, _, nothing, _, _},
                 check_only(ret("S5", "option<term>"))).

%% The same, through the OTHER channel. Only the top absorbs a tuple.
result_at_term_is_refused_test() ->
    ?assertError({collapsed_failure_channel, _, error, _, _},
                 check_only(ret("S7", "result<term, binary>"))).

%% CONTROL 2. The collision is a TUPLE SHAPE, not an atom: `(:error, binary)` is
%% a subtype of `(atom, binary)` because `:error` is an atom. 15 §2 measured this
%% one and it is the second case the cofinite check cannot see.
result_whose_success_type_shadows_the_error_tuple_is_refused_test() ->
    ?assertError({collapsed_failure_channel, _, error, _, _},
                 check_only(ret("S8", "result<(atom, binary), binary>"))).

%% CONTROL 3. Keyed on the TYPE, not on the spelling `option<...>`. Ticket 09 §4
%% fixed that a name never enters the algebra, so this is the same type as S3 —
%% and it is the spelling `ToExistingAtom` is written in (`PRELUDE.md:108`).
a_hand_written_alias_of_the_same_shape_is_refused_test() ->
    ?assertError({collapsed_failure_channel, _, nothing, _, _},
                 check_only(ret("S9", "M", "type M = atom | :nothing"))).

%%% --- and the five that must keep compiling ----------------------------------
%%%
%%% ASSERTED AS A RUNNING PROGRAM, not as the absence of an error. A test that
%%% only says "no exception" goes green against a module that failed to compile
%%% for an unrelated reason, which is this repo's oldest recurring defect.

option_at_a_disjoint_type_still_compiles_test() ->
    M = build_and_load(ret("S1", "option<int>"), 'S1'),
    ?assertEqual(nothing, M:'Go'(1)).

%% `option<bool>` is three literal atoms, so nothing is absorbed.
option_at_bool_still_compiles_test() ->
    M = build_and_load(ret("S2", "option<bool>"), 'S2'),
    ?assertEqual(nothing, M:'Go'(1)).

%% 15 §2's whole reason for giving failure a payload: the tagged member survives
%% where a bare `:error` would not.
result_with_a_tagged_failure_still_compiles_test() ->
    Src = "module S6\n\npublic result<int, binary> Go(int id)\nGo(id) -> 1\n",
    M = build_and_load(Src, 'S6'),
    ?assertEqual(1, M:'Go'(1)).

%% Ticket 48's `Map.Fetch` shape, chosen BECAUSE it does not collapse. If this
%% test ever goes red the map type has lost its only way in.
the_map_fetch_shape_still_compiles_test() ->
    Src = "module S10\n\ntype F = (:ok, term) | :absent\n\n"
          "public F Go(int id)\nGo(id) -> :absent\n",
    M = build_and_load(Src, 'S10'),
    ?assertEqual(absent, M:'Go'(1)).

a_hand_written_tagged_union_still_compiles_test() ->
    Src = "module S11\n\ntype R = atom | (:error, binary)\n\n"
          "public R Go(int id)\nGo(id) -> :ok\n",
    M = build_and_load(Src, 'S11'),
    ?assertEqual(ok, M:'Go'(1)).

%%% ---------------------------------------------------------------------------
%%% F31.2 — THE SITE. Five declaration forms carry a written type, and each was
%%% measured to accept a collapsing one on master. A check wired to the
%%% signature alone passes every test above and none of these.
%%% ---------------------------------------------------------------------------

a_collapsing_signature_PARAMETER_is_refused_test() ->
    Src = "module P1\n\npublic :ok Go(option<atom> x)\nGo(x) -> :ok\n",
    ?assertError({collapsed_failure_channel, _, nothing, _, _}, check_only(Src)).

a_collapsing_RECORD_FIELD_is_refused_test() ->
    Src = "module P2\n\nrecord Box { Id: int, Note: option<atom> }\n\n"
          "public :ok Go(int id)\nGo(id) -> :ok\n",
    ?assertError({collapsed_failure_channel, _, nothing, _, _}, check_only(Src)).

%% The alias BODY, checked once where it is written rather than once per use —
%% following a `t_ref` would report the same defect at every mention of it.
a_collapsing_TYPE_ALIAS_body_is_refused_test() ->
    Src = "module P3\n\ntype M = atom | :nothing\n\n"
          "public :ok Go(int id)\nGo(id) -> :ok\n",
    ?assertError({collapsed_failure_channel, _, nothing, _, _}, check_only(Src)).

%% The FOREIGN boundary, which is where this matters most: `ToExistingAtom` is a
%% boundary function, and a collapsed failure channel on a foreign return is one
%% a caller cannot test for at the one place the value is least trusted.
a_collapsing_FOREIGN_return_is_refused_test() ->
    Src = "module P4\n\nusing :lists {\n    option<atom> last(list<atom> xs)\n}\n\n"
          "public :ok Go(int id)\nGo(id) -> :ok\n",
    ?assertError({collapsed_failure_channel, _, nothing, _, _}, check_only(Src)).

a_collapsing_FOREIGN_parameter_is_refused_test() ->
    Src = "module P5\n\nusing :lists {\n    atom last(option<atom> xs)\n}\n\n"
          "public :ok Go(int id)\nGo(id) -> :ok\n",
    ?assertError({collapsed_failure_channel, _, nothing, _, _}, check_only(Src)).

%% NESTED, because the channel is equally dead one level down. Measured on
%% master: `(option<atom>, int)` is reported by `--api` as `(atom, int)`.
a_collapsing_TUPLE_COMPONENT_is_refused_test() ->
    Src = "module P6\n\npublic (option<atom>, int) Go(int id)\n"
          "Go(id) -> (:nothing, 1)\n",
    ?assertError({collapsed_failure_channel, _, nothing, _, _}, check_only(Src)).

%% `bsc --api` resolves signatures through `exports_of/1`, which is a SECOND
%% declaration pass and does not go through `check/2` at all. Measured while
%% building this feature: the first draft refused at a compile and answered
%% `atom Go(int)` to `--api` on the same file, which is the collapse being
%% reported by one half of the compiler and printed as a fact by the other.
the_api_query_path_refuses_it_too_test() ->
    {ok, _, Decls} = bs_parser_support_parse("module A1\n\n"
                                             "public option<atom> Go(int id)\n"
                                             "Go(id) -> :nothing\n"),
    ?assertError({collapsed_failure_channel, _, nothing, _, _},
                 bs_check:exports_of(Decls)).

%% The parse half of `check_only/1`, without the check - there is no helper for
%% "parse and hand me the declarations" and this is the only test that needs one.
bs_parser_support_parse(Src) ->
    {ok, Toks, _} = bs_lexer:string(Src),
    {ok, Decls} = bs_parser:parse(Toks),
    {ok, undefined, Decls}.

%%% ---------------------------------------------------------------------------
%%% F31.3 — termination, and it is a regression test for a defect this feature
%%% shipped and then fixed.
%%%
%%% The first draft of the pass expanded a parametric alias without carrying
%%% `resolve/3`'s `Seen` chain. On a contractive alias it recursed forever:
%%% `generics_tests:a_contractive_alias_is_an_unbuilt_feature_test` did not go
%%% red, it TIMED OUT, and eunit cancelled every module after it - a suite that
%%% reported "Failed: 0" while running less than half of itself.
%%% ---------------------------------------------------------------------------

%% The declaration refusal these programs already carry (`recursive_type`) must
%% still be what arrives. Asserting the EXACT existing error, rather than merely
%% that the call returns, is what makes this a test of termination and not of a
%% new error swallowing an old one.
a_contractive_alias_terminates_and_keeps_its_own_refusal_test() ->
    ?assertError({recursive_type, 'Tree'},
                 check_only("module E\ntype Tree<T> = (T, list<Tree<T>>)\n"
                            "public atom F(Tree<int> t)\nF(t) -> :ok\n")),
    ?assertError({recursive_type, 'Nest'},
                 check_only("module E\ntype Nest = :leaf | list<Nest>\n"
                            "public atom F(Nest n)\nF(n) -> :ok\n")).

%% The same shape with a FAILURE MEMBER in it, which is the one this pass walks
%% into rather than past. `option<Tree<int>>` expands to a union whose success
%% member is the recursive alias.
a_contractive_alias_under_a_failure_member_terminates_test() ->
    ?assertError({recursive_type, 'Tree'},
                 check_only("module E\ntype Tree<T> = (T, list<Tree<T>>)\n"
                            "public option<Tree<int>> F(int n)\nF(n) -> :nothing\n")).

%%% ---------------------------------------------------------------------------
%%% F31.4 — the line, and the sentence.
%%% ---------------------------------------------------------------------------

%% No type-expression node carries a line (`t_union`, `t_generic`, `param` and
%% `field` all lack one), so the check cannot live in `resolve/3` and takes its
%% line from the enclosing declaration tuple. This asserts it arrives.
the_refusal_names_the_line_of_the_declaration_test() ->
    Src = "module L1\n\n// a comment\n\npublic option<atom> Go(int id)\n"
          "Go(id) -> :nothing\n",
    ?assertError({collapsed_failure_channel, 5, nothing, _, _}, check_only(Src)).

%% 15 §1 pins the sentence. The `tag it` hint is printed for the `:nothing`
%% channel only — see F31's recorded assumption: an absorbed `(:error, E)` is
%% ALREADY tagged, so that advice would name a form that does not fix it.
the_message_says_the_channel_did_not_survive_normalisation_test() ->
    D = bs_diag:descriptor("x.bs", {collapsed_failure_channel, 5, nothing,
                                    bs_types:atom_lit(nothing),
                                    bs_types:atom_top()}),
    S = lists:flatten(io_lib:format(element(1, bs_diag:message(D)),
                                    element(2, bs_diag:message(D)))),
    ?assert(string:find(S, "does not survive normalisation") =/= nomatch),
    ?assert(string:find(S, "tag it") =/= nomatch).

the_error_channel_is_not_told_to_tag_what_is_already_tagged_test() ->
    D = bs_diag:descriptor("x.bs", {collapsed_failure_channel, 5, error,
                                    bs_types:atom_lit(error),
                                    bs_types:atom_top()}),
    S = lists:flatten(io_lib:format(element(1, bs_diag:message(D)),
                                    element(2, bs_diag:message(D)))),
    ?assert(string:find(S, "does not survive normalisation") =/= nomatch),
    ?assertEqual(nomatch, string:find(S, "tag it")).

%%% ---------------------------------------------------------------------------
%%% F31.4 — the ValidateAs site keeps its own behaviour.
%%%
%%% 15 §1 now has ONE implementation, generalised to take the failure member as
%%% an argument. The obligation site passes the member it was already
%%% synthesising, and must still report under its own tag and its own sentence —
%%% `check-diagnostics.sh` pins that text.
%%% ---------------------------------------------------------------------------

%% The DECLARATION here must not itself collapse, or this test would be measuring
%% F31 and calling it F18 - `result<term, ValidationError>` is refused now, which
%% is what the first draft of this test wrote. The obligation's own argument is
%% the collapsing one.
the_obligation_site_still_reports_under_its_own_tag_test() ->
    Src = "module V1\n\npublic result<int, ValidationError> Go(term t)\n"
          "Go(t) -> ValidateAs<term>(t)\n",
    Errs = bs_test_support:errors(Src),
    ?assert(lists:any(fun({error, _, _, {validate_collapses, _}}) -> true;
                         (_) -> false
                      end, Errs)).
