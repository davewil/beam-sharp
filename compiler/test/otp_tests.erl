-module(otp_tests).

-include_lib("eunit/include/eunit.hrl").

-import(bs_test_support, [compile/1, build_and_load/2, check_only/1]).

-define(OUT, "/tmp/bsc_eunit").

%%% ---------------------------------------------------------------------------
%%% Behaviours
%%% ---------------------------------------------------------------------------

counter_src() ->
    "module Counter\n"
    "behaviour GenServer\n"
    "type Request = :get | (:add, int)\n"
    "type Reply = (:reply, int, int)\n"
    "Reply HandleCall(Request request, term from, int state)\n"
    "HandleCall(:get, from, state)      -> (:reply, state, state)\n"
    "HandleCall((:add, n), from, state) -> (:reply, state + n, state + n)\n".

behaviour_decl_emits_the_attribute_test() ->
    {ok, _} = compile(counter_src()),
    {ok, {_, [{abstract_code, {_, Forms}}]}} =
        beam_lib:chunks(?OUT ++ "/Counter.beam", [abstract_code]),
    ?assert(lists:member({attribute, 0, behaviour, gen_server},
                         [F || F = {attribute, _, behaviour, _} <- Forms])).

%% Two clauses cover `:get | (:add, int)` with no catch-all.
a_behaviour_callback_is_checked_exhaustive_test() ->
    ?assertMatch({ok, _, []}, check_only(counter_src())).

a_behaviour_callback_runs_test() ->
    M = build_and_load(counter_src(), 'Counter'),
    ?assertEqual({reply, 5, 5},   M:'HandleCall'(get, self(), 5)),
    ?assertEqual({reply, 12, 12}, M:'HandleCall'({add, 7}, self(), 5)).

%% `term` contains every tuple. Without a tuple top, a tuple pattern over a
%% `term` parameter was reported unreachable — which made the OTP callback shape
%% unwritable, since `handle_cast` and `handle_info` both take one.
a_tuple_pattern_over_term_is_reachable_test() ->
    Src = "module T\natom F(term x)\nF((:add, n)) -> :tuple\nF(_) -> :other\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

%% ...and a catch-all still removes every tuple, so this stays exhaustive.
a_catch_all_still_covers_every_tuple_test() ->
    Src = "module T\natom F(term x)\nF(_) -> :other\n",
    ?assertMatch({ok, _, []}, check_only(Src)).

