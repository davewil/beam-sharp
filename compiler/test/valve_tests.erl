%%% Scenarios: compiler/features/F30-valve-short-circuit-set.md
-module(valve_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [build_and_load/2, check_only/1, errors/1,
                          run_cli/1, with_src/3]).

%%% F30 — the valve stops on an error tuple or `:nothing`.

cli(Src, Assert) ->
    case bs_test_support:built() of
        false -> ok;
        true ->
            with_src("in.bs", Src,
                     fun(Path, Root) ->
                             Assert(run_cli("--src-root " ++ Root ++ " " ++ Path))
                     end)
    end.

absent_src() ->
    "module Absent\n"
    "type Maybe = int | :nothing\n"
    "private Maybe Fetch(int id)\n"
    "Fetch(0) -> :nothing\n"
    "Fetch(n) -> n\n"
    "private Maybe Double(int v)\n"
    "Double(v) -> v * 2\n".

%% A local error-chain fixture keeps the control independent of pipe tests.
res_src() ->
    "module Res\n"
    "type Res = int | (:error, atom)\n"
    "public Res Start(int n)\n"
    "Start(n) when n > 0  -> n\n"
    "Start(n) when n <= 0 -> (:error, :bad)\n".

%%% F30.1 — option chains compile and short-circuit.

%% Running the chain detects a lowering that passes `:nothing` to the stage.
the_option_chain_compiles_and_short_circuits_test() ->
    Src = absent_src() ++
          "public Maybe Load(int id)\n"
          "Load(id) -> Fetch(id) |?> Double()\n",
    M = build_and_load(Src, 'Absent'),
    ?assertEqual(8, M:'Load'(4)),
    ?assertEqual(nothing, M:'Load'(0)).

%% Generated arms must not produce advice about author-written patterns.
the_option_chain_produces_no_diagnostics_at_all_test() ->
    Src = absent_src() ++
          "public Maybe Load(int id)\n"
          "Load(id) -> Fetch(id) |?> Double()\n",
    {ok, _, Diags} = check_only(Src),
    ?assertEqual([], Diags).

%%% F30.2 — error chains retain their return type and diagnostics.

%% A dead `:nothing` arm must not widen the return type or add diagnostics.
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

%%% F30.3 — a subject carrying both stop members stops on either.

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

%% An int-only stage requires both stop members to leave the subject.
a_subject_carrying_both_members_stops_on_either_test() ->
    Src = both_src() ++
          "public Step3 Go(int id)\n"
          "Go(id) -> Step(id) |?> Use()\n",
    M = build_and_load(Src, 'Both'),
    ?assertEqual(1, M:'Go'(1)),
    ?assertEqual(nothing, M:'Go'(2)),
    ?assertEqual({error, bad}, M:'Go'(3)).

%%% F30.4 — a return type omitting `:nothing` gets a corrected signature.

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
    cli(Src, fun(Out) ->
                     ?assert(string:find(Out, ":nothing") =/= nomatch),
                     ?assert(string:find(Out, "rc:1") =/= nomatch)
             end).

%%% F30.5 — an infallible subject is refused with both stop members named.

a_valve_over_a_subject_with_neither_member_is_still_refused_test() ->
    Src = "module W\n"
          "private int Twice(int v)\n"
          "Twice(v) -> v * 2\n"
          "public int Run(int n)\n"
          "Run(n) -> n |?> Twice()\n",
    [{error, _, 'Run', {valve_on_infallible, _}}] = errors(Src),
    cli(Src, fun(Out) ->
                     ?assert(string:find(Out, "cannot fail") =/= nomatch),
                     %% The refusal must name both stop members.
                     ?assert(string:find(Out, "(:error, _)") =/= nomatch),
                     ?assert(string:find(Out, ":nothing") =/= nomatch),
                     ?assert(string:find(Out, "Write |> instead") =/= nomatch)
             end).

%%% F30.6 — a narrowing stage does not make its subject fallible.

%% Using the stage parameter as the stop rule admits a binary residual
%% with no pattern or BEAM guard.
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

%%% F30.7 — silently skipping `:nothing` as a value is an accepted cost.
%%% Empty diagnostics record the exposure, not a desired behaviour.
%%% The deferred refusal remedy is expected to turn this test red so it
%%% identifies the change in behaviour.

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
    %% No warning and no error: this assertion records the accepted exposure.
    ?assertEqual([], Diags),
    M = build_and_load(Src, 'Tri'),
    ?assertEqual(saw_yes, M:'Go'(1)),
    ?assertEqual(saw_no,  M:'Go'(3)),
    %% `Name` is skipped; it has no clause that accepts `:nothing`.
    ?assertEqual(nothing, M:'Go'(2)).

%%% F30.8 — nested valves use distinct binders.

%% Erlang clause scope is flat: reusing a binder turns binding into a match.
nested_valves_do_not_collide_test() ->
    %% The inner valve is an argument, so its `:nothing` reaches `Add` intact.
    Src = absent_src() ++
          "private Maybe Add(int v, Maybe w)\n"
          "Add(v, :nothing) -> :nothing\n"
          "Add(v, w) -> v + w\n"
          "public Maybe Go(int a, int b)\n"
          "Go(a, b) -> Fetch(a) |?> Add(Fetch(b) |?> Double())\n",
    M = build_and_load(Src, 'Absent'),
    ?assertEqual(9, M:'Go'(3, 3)),
    %% The outer subject is `:nothing`, so the outer stage is skipped.
    ?assertEqual(nothing, M:'Go'(0, 3)).

%%% F30.9 — emitted forms omit dead stop arms and retain live ones.

%% Dialyzer rejects unreachable stop arms even when erlc accepts them.
%% Checking both absence and presence rules out omitting all stop arms.
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
    %% Keep the live `:nothing` arm while removing the dead error arm.
    ?assertNotEqual(nomatch, string:find(Abstr, "nothing")),
    ?assertEqual(nomatch, string:find(Abstr, "{atom,{9,22},error}")).

abstr_of(Mod) ->
    Beam = code:which(Mod),
    {ok, Bin} = file:read_file(filename:rootname(Beam) ++ ".abstr"),
    binary_to_list(Bin).
