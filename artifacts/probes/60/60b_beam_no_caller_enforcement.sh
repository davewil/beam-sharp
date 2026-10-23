#!/usr/bin/env bash
# PROBE 60b — can the BEAM itself enforce "who may name this function"?
# Claims under test:
#   (1) an exported function is callable by every module (control: an unexported one is not).
#   (2) a callee-side RUNTIME caller check is possible only by reading the stacktrace; it answers wrongly
#       whenever the caller's frame has been eliminated by a tail call (incl. `R = f(), R`, which erlc
#       compiles to a tail call), and it costs time per call.
# Needs: source env.sh first.  Everything is compiled (no erl_eval frames in the stack).
set -uo pipefail
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cd "$W"
cat > vis_lib.erl <<'E'
-module(vis_lib).
-export([plain/0, guarded/0]).
plain() -> ok.
%% only vis_friend is allowed; decided at RUN time from the stack
guarded() ->
    {current_stacktrace, [_Self, {Caller, _, _, _} | _]} = process_info(self(), current_stacktrace),
    case Caller of vis_friend -> allowed; _ -> {denied, Caller} end.
hidden() -> ok.            % not exported: the control
E
cat > vis_friend.erl <<'E'
-module(vis_friend).
-export([non_tail/0, naive_bind/0, tail/0, via_apply/0]).
non_tail()   -> R = vis_lib:guarded(), erlang:put(seen, R), R.   % a side effect after the call keeps the frame
naive_bind() -> R = vis_lib:guarded(), R.                 % LOOKS non-tail; erlc emits a tail call
tail()       -> vis_lib:guarded().
via_apply()  -> R = erlang:apply(vis_lib, guarded, []), erlang:put(seen, R), R.
E
cat > vis_foreign.erl <<'E'
-module(vis_foreign).
-export([call_plain/0, call_guarded/0, call_hidden/0]).
call_plain()   -> vis_lib:plain().
call_guarded() -> R = vis_lib:guarded(), erlang:put(seen, R), R.
call_hidden()  -> try vis_lib:hidden() catch error:E -> {error, E} end.
E
cat > vis_driver.erl <<'E'
-module(vis_driver).
-export([run/0]).
p(L, V) -> io:format("  ~-46s ~p~n", [L, V]).
run() ->
    io:format("(1) reach~n"),
    p("foreign -> exported plain/0", vis_foreign:call_plain()),
    p("foreign -> UNEXPORTED hidden/0 (control)", vis_foreign:call_hidden()),
    io:format("(2) runtime stack check (friend = vis_friend)~n"),
    p("friend non-tail call      want allowed", vis_friend:non_tail()),
    p("friend via apply          want allowed", vis_friend:via_apply()),
    p("foreign call              want denied ", vis_foreign:call_guarded()),
    p("friend tail call          want allowed", vis_friend:tail()),
    p("friend `R = f(), R`       want allowed", vis_friend:naive_bind()),
    io:format("(3) ns/call, 7 runs x 1e6 calls, compiled loop (median [min..max])~n"),
    _ = loop(fun vis_lib:plain/0, 1000000), _ = loop(fun vis_lib:guarded/0, 1000000),
    Rs = [{loop(fun vis_lib:plain/0, 1000000), loop(fun vis_lib:guarded/0, 1000000)} || _ <- lists:seq(1, 7)],
    Pl = lists:sort([A || {A, _} <- Rs]), Gl = lists:sort([B || {_, B} <- Rs]),
    io:format("  plain   ~.1f [~.1f..~.1f]~n  guarded ~.1f [~.1f..~.1f]~n",
      [lists:nth(4, Pl), hd(Pl), lists:last(Pl), lists:nth(4, Gl), hd(Gl), lists:last(Gl)]).
loop(F, N) -> {U, _} = timer:tc(fun() -> spin(F, N) end), U * 1000 / N.
spin(_, 0) -> ok;
spin(F, N) -> F(), spin(F, N - 1).
E
erlc vis_lib.erl vis_friend.erl vis_foreign.erl vis_driver.erl 2>&1 | grep -v -E 'hidden/0 is unused|^%|^$'
erl -noshell -pa . -eval 'vis_driver:run(), halt().'
