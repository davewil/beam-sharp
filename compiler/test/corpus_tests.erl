-module(corpus_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [project_root/0]).

%%% ---------------------------------------------------------------------------
%%% Every shipped surface form is demonstrated by a program that runs
%%%
%%% Asked for on 2026-08-14, after F6, by David: *"are there actual example bs
%%% files showing all the language capabilities as they are built?"* Measured,
%%% and the answer was no — record CONSTRUCTION, destructuring binds, `bool` and
%%% a user-declared parametric alias had all shipped with tests and no example.
%%% Construction is the sharpest of those: `shop.bs` demonstrated every record
%%% operation except building one.
%%%
%%% WHAT THIS CHECKS, AND WHAT IT DOES NOT
%%% It checks the CORPUS, not the compiler. Paired with
%%% `every_example_still_compiles_test` above it means: every surface form below
%%% appears in a file that compiles and runs. It cannot check a capability whose
%%% whole behaviour is a REJECTION — every example must compile, so the call-site
%%% check, the projection error and exact field sets are covered by tests up
%%% there and can never be covered down here. That split is the reason the
%%% language has three gated surfaces rather than one: examples must run,
%%% LANGUAGE.md's blocks must compile (or must not, if tagged `not-yet`), and the
%%% suite carries what only a rejection can show.
%%%
%%% THE LIST IS HAND-MAINTAINED, DELIBERATELY
%%% There is no way to derive it: a capability is a sentence about the language
%%% and a probe is a token, and only a person can say which token demonstrates
%%% which sentence. The cost is one row per feature; the point is that the row
%%% has to be written, so a capability cannot ship with nothing to look at.
%%% ---------------------------------------------------------------------------

%% {what it demonstrates, a regex that finds it}. Anchored on distinctive
%% tokens, so a probe fails loudly rather than matching something adjacent.
demonstrated_surface() ->
    [{"a module declaration",                    "^module "},
     {"a type alias",                            "^type [A-Z]"},
     {"a union in a type",                       "^type .*\\|"},
     {"a user-declared parametric alias",        "^type [A-Z][A-Za-z]*<"},
     {"a parametric type applied",               "<int"},
     {"a record declaration",                    "^record "},
     %% A declaration has a space before its brace (`record Order   { Id`) and a
     %% construction does not (`Order{ Id = ...`), which is what tells them apart.
     {"record construction",                     "[A-Za-z]\\{"},
     {"a width-preserving update",               " with \\{"},
     {"a field projection",                      "\\.[A-Z]"},
     {"a tag or property pattern",               "\\{ [A-Z][A-Za-z]*:"},
     {"a guard",                                 " when "},
     {"a conjunction in a guard",                "&&"},
     {"an empty-list pattern",                   "\\[\\]"},
     {"a list pattern with a rest",              "\\[[a-z]+, \\.\\."},
     {"a local binding",                         "^ +var [a-z]"},
     {"a destructuring bind",                    "^ +var \\([a-z]"},
     %% F8 / ticket 45. Anchored on a BRACKET or COMMA before the `==`, so it
     %% probes the pattern position rather than an ordinary comparison —
     %% pinned below, because `n == m` matching this would be a silent pass.
     {"a match against a bound value",           "[\\[(,] *== [a-z]"},
     {"a foreign module declaration",            "^using :"},
     {"a foreign call",                          ":[a-z]+\\.[a-z_]+\\("},
     {"an OTP behaviour",                        "^behaviour "},
     %% F10. The attribute alone was already demonstrated; a CALLBACK is a second
     %% sentence, because the behaviour line means nothing until the contract it
     %% names is actually satisfied — which is exactly the state that kept
     %% `spec-check.sh` red.
     {"an OTP callback",                         "^HandleCast\\("},
     {"bool as a declared type",                 "^bool "},
     {"an atom literal",                         ":[a-z]"},
     %% F7. Four rows, because a switch, a tuple subject, a guarded arm and the
     %% keyword atoms are four sentences about the language and not one — and the
     %% last is here because it was `LANGUAGE.md`'s prose that claimed it shipped
     %% while nothing demonstrated it, which is precisely the rot this gate is
     %% for.
     {"a switch expression",                     " switch \\{"},
     {"a tuple subject in a switch",             "\\) switch \\{"},
     {"a guard on a switch arm",                 "when [^=]+ =>"},
     {"the keyword atoms true and false",        "[^:A-Za-z](true|false)[,)]"},
     %% F9. Three rows, because the literal, the refinement and its base are
     %% three sentences. `string` and `binary` are separated deliberately: a file
     %% using only `string` would demonstrate the refinement and leave the type
     %% it refines with nothing to look at, which is the shape F3 shipped with
     %% when `shop.bs` showed every record operation except building one.
     {"a string literal",                        "\"[^\"]*\""},
     {"string as a declared type",               "(^|[<( ])string[ >)]"},
     {"binary as a declared type",               "(^|[<( ])binary[ >)]"}].

every_shipped_surface_form_has_an_example_test() ->
    Dir = project_root() ++ "/examples",
    {ok, Names} = file:list_dir(Dir),
    Corpus =
        [begin
             {ok, Bin} = file:read_file(filename:join(Dir, N)),
             %% Comments are stripped, so a form mentioned in prose does not
             %% count as demonstrated. Several of these files DISCUSS what they
             %% do not do.
             Lines = [L || L <- string:split(binary_to_list(Bin), "\n", all),
                           not lists:prefix("//", string:trim(L, leading))],
             string:join(Lines, "\n")
         end || N <- lists:sort(Names), filename:extension(N) =:= ".bs"],
    Text = string:join(Corpus, "\n"),
    Missing = [What || {What, Re} <- demonstrated_surface(),
                       re:run(Text, Re, [multiline, {capture, none}]) =:= nomatch],
    %% Named rather than counted: the failure has to say which capability nobody
    %% can look at, or it is a puzzle rather than a diagnostic.
    ?assertEqual([], Missing).

%% ...and the mirror, which is the half that rots silently. A probe matching
%% nothing would be caught above; a probe that no longer means what it says
%% would not, so the two most delicate ones are pinned against text that must
%% NOT match them.
the_construction_probe_does_not_match_a_declaration_test() ->
    ?assertEqual(nomatch,
                 re:run("record Order   { Id: int }", "[A-Za-z]\\{",
                        [multiline, {capture, none}])),
    ?assertEqual(match,
                 re:run("New(id) -> Order{ Id = id }", "[A-Za-z]\\{",
                        [multiline, {capture, none}])).

%% The third delicate probe, added with F8. `==` means exact equality in
%% EXPRESSION position too (ticket 16 fixed it as `=:=`), so the surface probe
%% for the pattern form could drift into matching an ordinary comparison and
%% report a capability demonstrated that nobody can look at.
%%
%% That is not hypothetical here: this whole feature exists because a bare name
%% in a pattern and a bare name in an expression LOOK the same and mean different
%% things. A probe that cannot tell them apart would repeat the confusion it is
%% meant to police.
the_match_probe_does_not_match_a_comparison_test() ->
    Re = "[\\[(,] *== [a-z]",
    ?assertEqual(nomatch,
                 re:run("Same(n, m) when n == m -> :yes", Re,
                        [multiline, {capture, none}])),
    ?assertEqual(match,
                 re:run("Run(head, [== head, ..rest]) -> 1", Re,
                        [multiline, {capture, none}])),
    ?assertEqual(match,
                 re:run("Pair(k, (== k, x)) -> x", Re,
                        [multiline, {capture, none}])).

