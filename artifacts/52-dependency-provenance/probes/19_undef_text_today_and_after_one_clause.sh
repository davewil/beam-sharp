#!/bin/sh
# Option C's runtime half: today `bsc` prints "crashed: error:undef" (bsc.erl:640 drops the stack).
# The stack's top frame already names the missing {Module, Function}; one clause could print it.
# Prototype of that clause run on the REAL stack shape bs_run hands report_run/1.
. "$(dirname "$0")/env.sh"
echo "== today (bsc.erl:640-641 prints Class:Reason only)"
sed -n 637,642p /home/user/beam-sharp/compiler/src/bsc.erl
cat > $W/p19.escript <<'E'
#!/usr/bin/env escript
main(_) ->
    one(fun() -> 'Elixir.Greeter':hello(<<"x">>) end),            % module absent
    one(fun() -> lists:nonesuch(1) end),                           % module present, function absent
    one(fun() -> 'Elixir.Greeter.Extra':shout(<<"x">>) end).
one(F) ->
    try F() catch error:undef:St ->
        io:format("  stack head: ~p~n  proposed: ~ts~n", [hd(St), undef_text(St)]) end.
%% the proposed clause body
undef_text([{M, F, A, _} | _]) ->
    Ar = if is_list(A) -> length(A); true -> A end,
    case code:which(M) of
        non_existing -> io_lib:format("crashed: ~tp:~tp/~p is undefined -- module ~tp is not on the code path (ERL_LIBS=~s)",
                                      [M, F, Ar, M, case os:getenv("ERL_LIBS") of false -> "unset"; V -> V end]);
        _ -> io_lib:format("crashed: ~tp:~tp/~p is undefined -- the module is loaded but does not export it", [M, F, Ar])
    end.
E
echo "== ERL_LIBS unset"; env -u ERL_LIBS escript $W/p19.escript
echo "== ERL_LIBS has greeter (Extra present; the first call now succeeds, so only the non-export case is undef)"
ERL_LIBS=$W/greeter_build/dev/lib escript $W/p19.escript
