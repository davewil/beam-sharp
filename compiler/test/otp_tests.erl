-module(otp_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, check_only/1]).

-define(OUT, "/tmp/bsc_eunit").

%%% ---------------------------------------------------------------------------
%%% Behaviours
%%% ---------------------------------------------------------------------------

%% A COMPLETE gen_server, which this was not until ticket 35 was resolved. It
%% carried `HandleCall` alone, so the emitted module declared a contract missing
%% two of its three mandatory callbacks — and that is what kept `spec-check.sh`
%% red on master.
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

%% Two clauses cover `:get | (:add, int)` with no catch-all.
a_behaviour_callback_is_checked_exhaustive_test() ->
    ?assertMatch({ok, _, []}, check_only(counter_src())).

%%% ---------------------------------------------------------------------------
%%% Ticket 35 — what name does a callback emit?
%%%
%%% A compiler-known table, contract-scoped and keyed by {behaviour, name,
%%% arity}. Not a derivation rule: ticket 32 measured that a snake_case mapping
%%% cannot spell a quarter of Elixir's function names, and closed it.
%%% ---------------------------------------------------------------------------

%% The callback is reachable under its OTP name, which is what `gen_server`
%% actually calls...
a_behaviour_callback_runs_under_its_otp_name_test() ->
    M = build_and_load(counter_src(), 'Counter'),
    ?assertEqual({ok, 5}, M:init(5)),
    ?assertEqual({reply, 5, 5},   M:handle_call(get, self(), 5)),
    ?assertEqual({reply, 12, 12}, M:handle_call({add, 7}, self(), 5)),
    ?assertEqual({noreply, 3}, M:handle_cast(anything, 3)).

%% ...and NOT under the beam-sharp one. The name changes rather than a wrapper
%% being emitted, which is the shipped precedent one level up: `otp_name/1`
%% renames `GenServer` to `gen_server` and does not export both.
the_beam_sharp_spelling_is_not_also_exported_test() ->
    M = build_and_load(counter_src(), 'Counter'),
    Exports = M:module_info(exports),
    ?assert(lists:member({handle_call, 3}, Exports)),
    ?assertNot(lists:member({'HandleCall', 3}, Exports)).

%% The `-spec` follows the name, or Dialyzer reads a spec for a function that
%% does not exist. This is the site `spec-check.sh` exercises end to end.
the_spec_follows_the_lowered_name_test() ->
    {ok, _} = compile(counter_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Counter.beam", [abstract_code]),
    Specs = [NA || {attribute, _, spec, {NA, _}} <- Forms],
    ?assert(lists:member({handle_call, 3}, Specs)),
    ?assertNot(lists:member({'HandleCall', 3}, Specs)).

%% CONTRACT-SCOPED, and this is the assertion that makes it a table rather than a
%% naming rule. The same name in a module that declares no behaviour is an
%% ordinary function and keeps its spelling.
without_a_behaviour_the_name_is_untouched_test() ->
    M = build_and_load("module Plain\n"
                       "public atom HandleCall(term a, term b, term c)\n"
                       "HandleCall(a, b, c) -> :ok\n", 'Plain'),
    ?assert(lists:member({'HandleCall', 3}, M:module_info(exports))),
    ?assertNot(lists:member({handle_call, 3}, M:module_info(exports))).

%% ARITY IS PART OF THE KEY, asserted on the table directly.
%%
%% It cannot be reached through source today, and finding that out is worth more
%% than the test was: `bs_check:collect/1` gathers a signature's clauses by NAME
%% ALONE, so beam-sharp has no arity overloading — two signatures sharing a name
%% each collect the other's clauses. That is a pre-existing limit, unrelated to
%% ticket 35, and it is recorded in the feature file rather than fixed here.
%%
%% The key still does work today: `FormatStatus` is a real gen_server callback at
%% both /1 and /2, so the table needs the arity to tell its own rows apart, and it
%% is what stops a future `HandleCall/2` being silently captured.
arity_is_part_of_the_callback_key_test() ->
    ?assertEqual(handle_call, bs_otp:callback_name('HandleCall', 3, ['GenServer'])),
    ?assertEqual(none,        bs_otp:callback_name('HandleCall', 2, ['GenServer'])),
    ?assertEqual(format_status, bs_otp:callback_name('FormatStatus', 1, ['GenServer'])),
    ?assertEqual(format_status, bs_otp:callback_name('FormatStatus', 2, ['GenServer'])).

%% BEHAVIOUR-SCOPED TOO, and this one IS reachable through source. `HandleCall/3`
%% is a gen_server callback and not a supervisor one, so in a `Supervisor` module
%% it is an ordinary function and keeps its spelling.
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

%% THE FOURTH NAMING SITE. A local call must agree with the export or the module
%% calls a function it does not have — and it fails at run time, not at compile
%% time, which is the quiet direction.
a_local_call_uses_the_lowered_name_test() ->
    M = build_and_load(counter_src() ++
                       "public Reply Ask(int state)\n"
                       "Ask(state) -> HandleCall(:get, :nobody, state)\n", 'Counter'),
    ?assertEqual({reply, 9, 9}, M:'Ask'(9)).

%%% ---------------------------------------------------------------------------
%%% Ticket 35 §3 — an unsatisfiable attribute is an error at the declaration
%%% ---------------------------------------------------------------------------

%% Before this, the attribute was emitted anyway and `erlc` reported the missing
%% callback against an emitted `.abstr` the author never wrote.
a_missing_mandatory_callback_is_an_error_test() ->
    Src = "module Half\n"
          "behaviour GenServer\n"
          "public (:ok, int) Init(int seed)\n"
          "Init(seed) -> (:ok, seed)\n",
    ?assertError({behaviour_not_satisfied, _, 'GenServer', _}, check_only(Src)).

%% The message names them in the spelling the AUTHOR must write, not OTP's —
%% `HandleCall/3`, which lexes, rather than `handle_call/3`, which does not.
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

%% An OPTIONAL callback is not demanded. `handle_info/2` is optional for
%% gen_server, and a module without one is complete.
an_optional_callback_is_not_demanded_test() ->
    ?assertMatch({ok, _, []}, check_only(counter_src())).

%% Supervisor's whole contract is `init/1`, so this is a complete behaviour in
%% four lines — worth asserting because it exercises a second row of the table.
a_supervisor_needs_only_init_test() ->
    M = build_and_load("module Sup\n"
                       "behaviour Supervisor\n"
                       "public (:ok, int) Init(term args)\n"
                       "Init(args) -> (:ok, 0)\n", 'Sup'),
    ?assert(lists:member({init, 1}, M:module_info(exports))).

an_unknown_behaviour_is_named_test() ->
    ?assertError({unknown_behaviour, 'GenBanana'},
                 check_only("module B\nbehaviour GenBanana\npublic atom F()\nF() -> :ok\n")).

%% `term` contains every tuple. Without a tuple top, a tuple pattern over a
%% `term` parameter was reported unreachable — which made the OTP callback shape
%% unwritable, since `handle_cast` and `handle_info` both take one.
a_tuple_pattern_over_term_is_reachable_test() ->
    Src = "module T\npublic atom F(term x)\nF((:add, n)) -> :tuple\nF(_) -> :other\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

%% ...and a catch-all still removes every tuple, so this stays exhaustive.
a_catch_all_still_covers_every_tuple_test() ->
    Src = "module T\npublic atom F(term x)\nF(_) -> :other\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

