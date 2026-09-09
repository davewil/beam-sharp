-module(valve_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, check_only/1, errors/1,
                          run_cli/1, with_src/3]).

%%% ---------------------------------------------------------------------------
%%% F30 — the valve stops on the fixed pair `(:error, _) | :nothing`
%%%
%%% Ticket 49 settled the SET on 2026-08-28 and David reaffirmed the build on
%%% 2026-09-09 after the price was re-measured. This file builds nothing new
%%% into the grammar: `|?>` parses today and its precedence is settled, so every
%%% scenario below is about the arms `bs_lower` writes and the type `bs_check`
%%% reads off them.
%%%
%%% WHY THE ERROR CHAIN IS A SCENARIO AND NOT AN ASSUMPTION. The defect that
%%% adds the `:nothing` arm by REPLACING the error arm passes every new test
%%% here and breaks F14's whole feature. `nothing_only` in `check-valve.sh` is
%%% that defect, and F30.2 is what sees it.
%%% ---------------------------------------------------------------------------

cli(Src, Assert) ->
    case bs_test_support:built() of
        false -> ok;
        true ->
            with_src("in.bs", Src,
                     fun(Path, Root) ->
                             Assert(run_cli("--src-root " ++ Root ++ " " ++ Path))
                     end)
    end.

%% `:nothing` as ABSENCE. This is the shape C#'s `?.` and TypeScript's optional
%% chaining were borrowed for, and ticket 17 §4 justified the operator by them.
absent_src() ->
    "module Absent\n"
    "type Maybe = int | :nothing\n"
    "private Maybe Fetch(int id)\n"
    "Fetch(0) -> :nothing\n"
    "Fetch(n) -> n\n"
    "private Maybe Double(int v)\n"
    "Double(v) -> v * 2\n".

%% The error chain, unchanged from F14. Copied rather than imported so that a
%% change to `pipe_tests` cannot silently move F30.2's baseline.
res_src() ->
    "module Res\n"
    "type Res = int | (:error, atom)\n"
    "public Res Start(int n)\n"
    "Start(n) when n > 0  -> n\n"
    "Start(n) when n <= 0 -> (:error, :bad)\n".

%%% --- F30.1 the headline -----------------------------------------------------

%% Refused before this feature with "`:nothing | int` has no (:error, _)
%% member". The assertion is the RUN and not the compile, because a build that
%% accepted the program and lowered a two-armed switch would compile it and then
%% hand `:nothing` to a stage declared over `int`.
the_option_chain_compiles_and_short_circuits_test() ->
    Src = absent_src() ++
          "public Maybe Load(int id)\n"
          "Load(id) -> Fetch(id) |?> Double()\n",
    M = build_and_load(Src, 'Absent'),
    ?assertEqual(8, M:'Load'(4)),
    %% `:nothing` is returned UNCHANGED, which is the arm's whole job.
    ?assertEqual(nothing, M:'Load'(0)).

%% AND IT RAISES NOTHING. Both generated arms are the compiler's, so neither may
%% produce advice about a pattern the author did not write. `[]` rather than a
%% count, so it holds whichever of the two would have fired first.
the_option_chain_produces_no_diagnostics_at_all_test() ->
    Src = absent_src() ++
          "public Maybe Load(int id)\n"
          "Load(id) -> Fetch(id) |?> Double()\n",
    {ok, _, Diags} = check_only(Src),
    ?assertEqual([], Diags).

%%% --- F30.2 the error chain does not move ------------------------------------

%% F14's behaviour, asserted here as well as there. The `:nothing` arm is dead
%% over this subject and must contribute NOTHING: neither a widened return type
%% nor a diagnostic. A build that appended the arm's body type unconditionally
%% widens `Res` to `int | (:error, atom) | :nothing` and stops every valve
%% program in the corpus compiling.
the_error_chain_is_unchanged_test() ->
    Src = res_src() ++
          "private Res Charge(int v)\n"
          "Charge(v) -> v * 2\n"
          "public Res Place(int n)\n"
          "Place(n) -> Start(n) |?> Charge()\n",
    {ok, _, Diags} = check_only(Src),
    ?assertEqual([], Diags),
    M = build_and_load(Src, 'Res'),
    ?assertEqual(2, M:'Place'(1)),
    ?assertEqual({error, bad}, M:'Place'(0)).

%%% --- F30.3 a subject carrying both members ----------------------------------

both_src() ->
    "module Both\n"
    "type Step3 = (:error, :bad) | :nothing | int\n"
    "type Rest3 = int\n"
    "private Step3 Step(int id)\n"
    "Step(1) -> 1\n"
    "Step(2) -> :nothing\n"
    "Step(id) -> (:error, :bad)\n"
    "private int Use(Rest3 v)\n"
    "Use(v) -> v\n".

%% Stops on EITHER member, and the stage is handed the subject minus BOTH.
%% `Use` is declared over `int` alone: if the residual were the subject minus
%% the error member only, `:nothing` would reach argument 1 and this program
%% would be refused rather than run.
a_subject_carrying_both_members_stops_on_either_test() ->
    Src = both_src() ++
          "public Step3 Go(int id)\n"
          "Go(id) -> Step(id) |?> Use()\n",
    M = build_and_load(Src, 'Both'),
    ?assertEqual(1, M:'Go'(1)),
    ?assertEqual(nothing, M:'Go'(2)),
    ?assertEqual({error, bad}, M:'Go'(3)).

%%% --- F30.4 the migration is reported, never silent --------------------------

%% THE PRICE OF THE FEATURE, ASSERTED. A short-circuited `:nothing` is returned
%% unchanged, so the valve's type gains it and a return type that does not carry
%% `:nothing` is now wrong. F25's corrected signature prints the repair, and
%% this test exists because a build that widened the type silently would change
%% what every caller must handle without telling anybody.
a_return_type_that_omits_nothing_is_refused_with_the_corrected_signature_test() ->
    Src = "module Narrow\n"
          "type Step3 = (:error, :bad) | :nothing | int\n"
          "type Out3  = int | (:error, :bad)\n"
          "private Step3 Step(int id)\n"
          "Step(1) -> 1\n"
          "Step(2) -> :nothing\n"
          "Step(id) -> (:error, :bad)\n"
          "private int Use(int v)\n"
          "Use(v) -> v\n"
          "public Out3 Go(int id)\n"
          "Go(id) -> Step(id) |?> Use()\n",
    [{error, _, 'Go', {return_not_declared, _, _}}] = errors(Src),
    %% The signature to paste must NAME the member that was added, or the
    %% migration is a puzzle rather than a repair.
    cli(Src, fun(Out) ->
                     ?assert(string:find(Out, ":nothing") =/= nomatch),
                     ?assert(string:find(Out, "rc:1") =/= nomatch)
             end).

%%% --- F30.5 valve_on_infallible reads the meet with both members -------------

%% A subject with NEITHER member is still refused. The wording changes with the
%% meaning: the compiler now looks for two things and must say so, or it tells
%% an author their type has no error member while it was asking a wider
%% question.
a_valve_over_a_subject_with_neither_member_is_still_refused_test() ->
    Src = "module W\n"
          "private int Twice(int v)\n"
          "Twice(v) -> v * 2\n"
          "public int Run(int n)\n"
          "Run(n) -> n |?> Twice()\n",
    [{error, _, 'Run', {valve_on_infallible, _}}] = errors(Src),
    cli(Src, fun(Out) ->
                     ?assert(string:find(Out, "cannot fail") =/= nomatch),
                     %% BOTH members, because both are what it looked for.
                     ?assert(string:find(Out, "(:error, _)") =/= nomatch),
                     ?assert(string:find(Out, ":nothing") =/= nomatch),
                     ?assert(string:find(Out, "Write |> instead") =/= nomatch)
             end).

%%% --- F30.6 shape B stays refused, and this is the control -------------------

%% THE CONTROL THAT SAYS THE BUILD DID NOT REACH FOR A SIGNATURE. Ticket 49
%% refused shape B on a measurement: keying the short-circuit on the stage's
%% declared parameter type makes this compile and then fail to lower, because
%% `binary \ string` is a non-empty residual with no head and no BEAM guard.
%% An implementation that keys on the parameter passes every other scenario in
%% this file and fails only here.
a_narrowing_stage_does_not_make_an_infallible_subject_fallible_test() ->
    Src = "module SB\n"
          "private binary Bytes(binary raw)\n"
          "Bytes(b) -> b\n"
          "private string Decode(string s)\n"
          "Decode(s) -> s\n"
          "public string Run(binary raw)\n"
          "Run(raw) -> Bytes(raw) |?> Decode()\n",
    [{error, _, 'Run', {valve_on_infallible, _}}] = errors(Src),
    cli(Src, fun(Out) ->
                     ?assert(string:find(Out, "binary") =/= nomatch),
                     ?assert(string:find(Out, "cannot fail") =/= nomatch)
             end).

%%% --- F30.7 the accepted exposure, asserted rather than only described -------

%% `:nothing` MEANT AS A VALUE is short-circuited, and the author is not told.
%% Ticket 49 accepted this and David reaffirmed it on 2026-09-09 with the
%% corrected price in front of him: this program is refused LOUDLY today, so the
%% feature replaces a working diagnostic with a silent skip for this shape.
%%
%% The assertion is here so the price lives in a test rather than only in prose,
%% and so that the day somebody builds the deferred remedy — refuse
%% `:nothing`-as-value where a valve can reach it — this test goes red and names
%% what changed.
nothing_meant_as_a_value_is_skipped_and_that_is_intended_test() ->
    Src = "module Tri\n"
          "type T    = :no | :nothing | :yes\n"
          "type Rest = :no | :yes\n"
          "private T Pick(int n)\n"
          "Pick(1) -> :yes\n"
          "Pick(2) -> :nothing\n"
          "Pick(n) -> :no\n"
          "private atom Name(Rest t)\n"
          "Name(:no)  -> :saw_no\n"
          "Name(:yes) -> :saw_yes\n"
          "public atom Go(int n)\n"
          "Go(n) -> Pick(n) |?> Name()\n",
    {ok, _, Diags} = check_only(Src),
    %% No warning, no error. That IS the exposure.
    ?assertEqual([], Diags),
    M = build_and_load(Src, 'Tri'),
    ?assertEqual(saw_yes, M:'Go'(1)),
    ?assertEqual(saw_no,  M:'Go'(3)),
    %% Skipped, with `Name` never entered.
    ?assertEqual(nothing, M:'Go'(2)).

%%% --- F30.8 nested valves still number correctly -----------------------------

%% F14 synthesises two binders per stage and the counter must stay monotonic
%% with a third arm in play. Erlang's scoping is flat within a clause, so a
%% repeated name stops being a fresh binding and silently becomes a MATCH
%% against the enclosing stage's value — a wrong program with no diagnostic.
nested_valves_do_not_collide_test() ->
    %% `Add`'s second parameter is declared over `Maybe` and not `int`, because
    %% the INNER valve's value is an argument rather than a subject: only a
    %% subject is narrowed by the arms, so `:nothing` arrives at argument 2
    %% intact. Declaring it `int` is refused, correctly, and that refusal is
    %% itself the proof that the inner valve's type gained the member.
    Src = absent_src() ++
          "private Maybe Add(int v, Maybe w)\n"
          "Add(v, :nothing) -> :nothing\n"
          "Add(v, w) -> v + w\n"
          "public Maybe Go(int a, int b)\n"
          "Go(a, b) -> Fetch(a) |?> Add(Fetch(b) |?> Double())\n",
    M = build_and_load(Src, 'Absent'),
    ?assertEqual(9, M:'Go'(3, 3)),
    %% The inner valve short-circuits and the outer one is handed `:nothing` as
    %% an ARGUMENT, which is a value like any other — only the outer subject
    %% decides the outer valve.
    ?assertEqual(nothing, M:'Go'(0, 3)).

%%% --- F30.9 the emitted forms ------------------------------------------------

%% `bs_lower` writes both stop arms over every valve, because it runs before the
%% checker and has no types to ask. Over this subject the `:nothing` arm is dead,
%% and emitting it anyway is not free: `erlc` accepts it, **Dialyzer does not** —
%% *"the pattern 'nothing' can never match the type pos_integer()"* — and
%% `spec-check.sh` treats any warning as a defect in the emitted code. The
%% checker drops the arms it proved dead before the tree reaches `bs_emit`.
%%
%% Asserted in BOTH directions on purpose. The absence alone would also pass if
%% the arm were never generated at all, which is the feature not existing.
the_dead_stop_arm_is_not_emitted_test() ->
    Err = res_src() ++
          "private Res Charge(int v)\n"
          "Charge(v) -> v * 2\n"
          "public Res Place(int n)\n"
          "Place(n) -> Start(n) |?> Charge()\n",
    M1 = build_and_load(Err, 'Res'),
    ?assertEqual(nomatch, string:find(abstr_of(M1), "nothing")),

    Opt = absent_src() ++
          "public Maybe Load(int id)\n"
          "Load(id) -> Fetch(id) |?> Double()\n",
    M2 = build_and_load(Opt, 'Absent'),
    Abstr = abstr_of(M2),
    %% The live arm is there, and the arm dead over THIS subject — the error
    %% tuple — is the one that went.
    ?assertNotEqual(nomatch, string:find(Abstr, "nothing")),
    ?assertEqual(nomatch, string:find(Abstr, "{atom,{9,22},error}")).

%% The emitted abstract forms, read from beside the beam the loader just took.
abstr_of(Mod) ->
    Beam = code:which(Mod),
    {ok, Bin} = file:read_file(filename:rootname(Beam) ++ ".abstr"),
    binary_to_list(Bin).
