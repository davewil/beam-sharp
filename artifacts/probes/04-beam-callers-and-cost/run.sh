#!/usr/bin/env bash
# Probe 04: what the BEAM can and cannot do about "who may call this function", and what the
# structural alternatives cost.  OTP 25 here (repo pins 28.5): absolute timings are NOT portable;
# the shape (ratios, which calls are `call` vs `call_ext`, who can bypass) is what is claimed.
set -u
erl -noshell -eval 'io:format("OTP ~s, erts ~s~n",[erlang:system_info(otp_release),erlang:system_info(version)]),halt().'
T=$(mktemp -d); cd "$T"

# ---- 1. exported vs local, and a caller restriction the loader cannot see ------------------
cat > callee.erl <<'EOS'
-module(callee).
-export([pub/1, helper/1]).          % helper/1 must be exported for ANY other module to name it
pub(X) -> helper(X) + 1.             % in-module call to an exported function
helper(X) -> X * 3.
EOS
cat > friend.erl <<'EOS'
-module(friend).  -export([go/1]).
go(X) -> callee:helper(X).
EOS
cat > stranger.erl <<'EOS'
-module(stranger). -export([go/1, dyn/1]).
go(X) -> callee:helper(X).                       % statically indistinguishable from friend:go/1
dyn(X) -> M = callee, F = list_to_atom("hel" ++ "per"), apply(M, F, [X]).   % no static name at all
EOS
erlc callee.erl friend.erl stranger.erl
echo "--- 1a. the loaded module has one export table; any module can call an exported helper"
erl -noshell -eval 'io:format("friend:go(2)=~p stranger:go(2)=~p stranger:dyn(2)=~p~n",[friend:go(2),stranger:go(2),stranger:dyn(2)]), halt().'
echo "--- 1b. erlc -S: in-module call to the exported helper/1 is a LOCAL call (call), not call_ext"
erlc -S callee.erl; grep -nE 'helper/1|func_info,\{atom,callee\},\{atom,(pub|helper)' callee.S
echo "--- 1c. remote call site in the caller is call_ext_only/call_ext:"
erlc -S stranger.erl; grep -nE 'extfunc,callee' stranger.S

# ---- 2. a RUNTIME caller guard: how much does it cost? ---------------------------------------
cat > guarded.erl <<'EOS'
-module(guarded).
-export([plain/1, guarded/1]).
plain(X) -> X * 3.
guarded(X) ->
    {current_stacktrace, [_Self, {Caller, _, _, _} | _]} = process_info(self(), current_stacktrace),
    case Caller of friend2 -> X * 3; _ -> erlang:error({not_visible, Caller}) end.
EOS
cat > friend2.erl <<'EOS'
-module(friend2). -export([plain/2, guarded/2, tail/1, body/1]).
plain(0, A) -> A;   plain(N, A) -> plain(N-1, A + guarded:plain(N)).
guarded(0, A) -> A; guarded(N, A) -> guarded(N-1, A + guarded:guarded(N)).
tail(X) -> guarded:guarded(X).              % LEGITIMATE friend, call in tail position
body(X) -> 1 + guarded:guarded(X).          % LEGITIMATE friend, call in body position
EOS
erlc guarded.erl friend2.erl
erl -noshell -eval '
R = fun({'"'"'EXIT'"'"',{Why,_}}) -> {rejected, Why}; (V) -> V end,
Med = fun(F) -> L = lists:sort([element(1, timer:tc(F)) || _ <- lists:seq(1,5)]), lists:nth(3, L) end,
N = 1000000,
P = Med(fun() -> friend2:plain(N, 0) end),
G = Med(fun() -> friend2:guarded(N, 0) end),
io:format("2a. 1e6 remote calls: plain=~p us, with stacktrace caller guard=~p us (ratio ~.1f)~n", [P, G, G/P]),
io:format("2b. friend in BODY position : ~p~n", [R(catch friend2:body(2))]),
io:format("2c. friend in TAIL position : ~p   <- tail call erases the friend frame~n", [R(catch friend2:tail(2))]),
io:format("2d. stranger (shell)        : ~p~n", [R(catch guarded:guarded(2))]),
halt().' 2>&1 | sed 's/^/   /'

# ---- 3. what Option A forces: the helper moves to its own module, so same-module -> remote -----
cat > one.erl <<'EOS'
-module(one). -export([run/2]).
run(0, A) -> A;  run(N, A) -> run(N-1, A + h(N)).
h(X) -> X * 3.
EOS
cat > two_a.erl <<'EOS'
-module(two_a). -export([run/2]).
run(0, A) -> A;  run(N, A) -> run(N-1, A + two_b:h(N)).
EOS
cat > two_b.erl <<'EOS'
-module(two_b). -export([h/1]).
h(X) -> X * 3.
EOS
erlc one.erl two_a.erl two_b.erl
erl -noshell -eval '
Med = fun(F) -> L = lists:sort([element(1, timer:tc(F)) || _ <- lists:seq(1,7)]), lists:nth(4, L) end,
N = 5000000,
L = Med(fun() -> one:run(N, 0) end),
R = Med(fun() -> two_a:run(N, 0) end),
io:format("3. 5e6 helper calls: same-module (local)=~p us, other-module (remote)=~p us, ~.2f ns extra/call~n", [L, R, (R-L)*1000/N]),
halt().' 2>&1 | sed 's/^/   /'
echo "--- 3b. bytes: helper in the same .beam vs in its own .beam (strip debug_info for a fair size)"
for f in one two_a two_b; do erlc +strip -o . $f.erl; done
ls -l one.beam two_a.beam two_b.beam | awk '{print $5, $9}'
erl -noshell -eval '
{ok,_,Cs1}=beam_lib:all_chunks("one.beam"), {ok,_,Cs2}=beam_lib:all_chunks("two_a.beam"), {ok,_,Cs3}=beam_lib:all_chunks("two_b.beam"),
io:format("chunk sizes one: ~p~n two_a: ~p~n two_b: ~p~n",[[{N,byte_size(B)}||{N,B}<-Cs1],[{N,byte_size(B)}||{N,B}<-Cs2],[{N,byte_size(B)}||{N,B}<-Cs3]]),
halt().'
