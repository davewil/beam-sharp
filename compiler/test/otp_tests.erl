%%% Scenarios: compiler/features/F10-otp-callbacks.md
-module(otp_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, check_only/1]).

-define(OUT, bs_test_support:run_root()).

%%% --- Behaviours ---

%% The fixture supplies all mandatory gen_server callbacks.
counter_src() ->
    "module Counter\n"
    "behaviour GenServer\n"
    "type Request = :get | (:add, int)\n"
    "type Reply = (:reply, int, int)\n"
    "public (:ok, int) Init(int seed)\n"
    "Init(seed) -> (:ok, seed)\n"
    "public Reply HandleCall(Request request, term from, int state)\n"
    "HandleCall(:get, from, state)      -> (:reply, state, state)\n"
    "HandleCall((:add, n), from, state) -> (:reply, state + n, state + n)\n"
    "public (:noreply, int) HandleCast(term msg, int state)\n"
    "HandleCast(msg, state) -> (:noreply, state)\n".

behaviour_decl_emits_the_attribute_test() ->
    {ok, _} = compile(counter_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Counter.beam", [abstract_code]),
    ?assert(lists:member({attribute, 0, behaviour, gen_server},
                         [F || F = {attribute, _, behaviour, _} <- Forms])).

a_behaviour_callback_is_checked_exhaustive_test() ->
    ?assertMatch({ok, _, []}, check_only(counter_src())).

%%% --- Callback names ---

a_behaviour_callback_runs_under_its_otp_name_test() ->
    M = build_and_load(counter_src(), 'Counter'),
    ?assertEqual({ok, 5}, M:init(5)),
    ?assertEqual({reply, 5, 5},   M:handle_call(get, self(), 5)),
    ?assertEqual({reply, 12, 12}, M:handle_call({add, 7}, self(), 5)),
    ?assertEqual({noreply, 3}, M:handle_cast(anything, 3)).

the_beam_sharp_spelling_is_not_also_exported_test() ->
    M = build_and_load(counter_src(), 'Counter'),
    Exports = M:module_info(exports),
    ?assert(lists:member({handle_call, 3}, Exports)),
    ?assertNot(lists:member({'HandleCall', 3}, Exports)).

%% Dialyzer needs specs under the emitted callback names.
the_spec_follows_the_lowered_name_test() ->
    {ok, _} = compile(counter_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Counter.beam", [abstract_code]),
    Specs = [NA || {attribute, _, spec, {NA, _}} <- Forms],
    ?assert(lists:member({handle_call, 3}, Specs)),
    ?assertNot(lists:member({'HandleCall', 3}, Specs)).

%% Without a behaviour, the same name is an ordinary function.
without_a_behaviour_the_name_is_untouched_test() ->
    M = build_and_load("module Plain\n"
                       "public atom HandleCall(term a, term b, term c)\n"
                       "HandleCall(a, b, c) -> :ok\n", 'Plain'),
    ?assert(lists:member({'HandleCall', 3}, M:module_info(exports))),
    ?assertNot(lists:member({handle_call, 3}, M:module_info(exports))).

%% HandleCall/2 is the negative control for a lookup that ignores arity.
%% Both FormatStatus arities must still match.
arity_is_part_of_the_callback_key_test() ->
    ?assertEqual(handle_call, bs_otp:callback_name('HandleCall', 3, ['GenServer'])),
    ?assertEqual(none,        bs_otp:callback_name('HandleCall', 2, ['GenServer'])),
    ?assertEqual(format_status, bs_otp:callback_name('FormatStatus', 1, ['GenServer'])),
    ?assertEqual(format_status, bs_otp:callback_name('FormatStatus', 2, ['GenServer'])).

%% HandleCall belongs to GenServer, so Supervisor must leave its name alone.
a_callback_of_another_behaviour_is_untouched_test() ->
    M = build_and_load("module Sup2\n"
                       "behaviour Supervisor\n"
                       "public (:ok, int) Init(term args)\n"
                       "Init(args) -> (:ok, 0)\n"
                       "public atom HandleCall(term a, term b, term c)\n"
                       "HandleCall(a, b, c) -> :not_a_supervisor_callback\n", 'Sup2'),
    Exports = M:module_info(exports),
    ?assert(lists:member({init, 1}, Exports)),
    ?assert(lists:member({'HandleCall', 3}, Exports)),
    ?assertNot(lists:member({handle_call, 3}, Exports)).

a_local_call_uses_the_lowered_name_test() ->
    M = build_and_load(counter_src() ++
                       "public Reply Ask(int state)\n"
                       "Ask(state) -> HandleCall(:get, :nobody, state)\n", 'Counter'),
    ?assertEqual({reply, 9, 9}, M:'Ask'(9)).

%%% --- Mandatory callbacks ---

a_missing_mandatory_callback_is_an_error_test() ->
    Src = "module Half\n"
          "behaviour GenServer\n"
          "public (:ok, int) Init(int seed)\n"
          "Init(seed) -> (:ok, seed)\n",
    ?assertError({behaviour_not_satisfied, _, 'GenServer', _}, check_only(Src)).

the_error_names_the_missing_callbacks_in_bs_spelling_test() ->
    Src = "module Half\n"
          "behaviour GenServer\n"
          "public (:ok, int) Init(int seed)\n"
          "Init(seed) -> (:ok, seed)\n",
    try check_only(Src) of
        _ -> ?assert(false)
    catch error:{behaviour_not_satisfied, _, _, Missing} ->
        ?assertEqual([{'HandleCall', 3}, {'HandleCast', 2}], lists:sort(Missing))
    end.

%% The fixture omits the optional handle_info callback.
an_optional_callback_is_not_demanded_test() ->
    ?assertMatch({ok, _, []}, check_only(counter_src())).

a_supervisor_needs_only_init_test() ->
    M = build_and_load("module Sup\n"
                       "behaviour Supervisor\n"
                       "public (:ok, int) Init(term args)\n"
                       "Init(args) -> (:ok, 0)\n", 'Sup'),
    ?assert(lists:member({init, 1}, M:module_info(exports))).

an_unknown_behaviour_is_named_test() ->
    ?assertError({unknown_behaviour, 'GenBanana'},
                 check_only("module B\nbehaviour GenBanana\npublic atom F()\nF() -> :ok\n")).

a_tuple_pattern_over_term_is_reachable_test() ->
    Src = "module T\npublic atom F(term x)\nF((:add, n)) -> :tuple\nF(_) -> :other\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

a_catch_all_still_covers_every_tuple_test() ->
    Src = "module T\npublic atom F(term x)\nF(_) -> :other\n",
    ?assertMatch({ok, _, []}, check_only(Src)).
