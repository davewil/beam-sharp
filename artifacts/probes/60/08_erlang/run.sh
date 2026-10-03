#!/bin/sh
# (Attempt 1, run.first-attempt.out: orders.erl carried -ignore_xref, so xref printed [] and I could not tell the attribute from
#  the absence of a check; section C now runs xref with and without it. Section E was a junk compiler-options grep and is dropped.)
# (Attempt 2, run.second-attempt.out: stock `undefined_function_calls` is empty even without -ignore_xref, so it never
#  checked the call; added a hand-computed query over xref's own XC/X/L sets to see what xref CAN know.)
# (Attempt 3, run.third-attempt.out: xref reads abstract code and I compiled without +debug_info, so it saw nothing. Fixed; no expectation moved.)
# Probe 60/08: Erlang/OTP 29. Does -export / -moduledoc false / -doc false / -compile / xref restrict WHO may call?
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
cd "$(dirname "$0")"; rm -rf ebin; mkdir ebin
echo "== A. erlc, +warnings_as_errors, both modules"
erlc +warnings_as_errors -o ebin src/billing.erl src/orders.erl; echo "exit=$?"
echo "== B. runtime"
erl -noshell -pa ebin -eval 'io:format("orders:total(1) = ~p~n", [orders:total(1)]),
  io:format("orders:peek(1)  = ~p~n", [try orders:peek(1) catch C:R -> {C,R} end]), halt().'
echo "== C. xref, the one analyser that sees across modules; WITH and WITHOUT the -ignore_xref attribute"
mkdir -p src2 && grep -v ignore_xref src/orders.erl > src2/orders.erl
for V in with without; do
  rm -rf ebin_x; mkdir ebin_x; erlc +debug_info -o ebin_x src/billing.erl; [ $V = with ] && erlc +debug_info -o ebin_x src/orders.erl || erlc +debug_info -o ebin_x src2/orders.erl
  echo "-- $V -ignore_xref"
  erl -noshell -eval '
    {ok,_} = xref:start(s), xref:set_default(s, [{verbose,false},{warnings,false}]),
    {ok,_} = xref:add_directory(s, "ebin_x"),
    io:format("   undefined_function_calls: ~p~n", [xref:analyze(s, undefined_function_calls)]),
    {ok, XC} = xref:q(s, "XC"), {ok, X} = xref:q(s, "X"), {ok, L} = xref:q(s, "L"),
    io:format("   external calls landing on a callee that is local-only (hand-computed from XC, X, L): ~p~n",
              [[{From, To} || {From, To} <- XC, lists:member(To, L), not lists:member(To, X)]]),
    halt().'
done
rm -rf ebin_x src2
echo "== D. what -moduledoc false / -doc false record (docs chunk)"
erl -noshell -pa ebin -eval '
  {ok, {_, [{documentation, D}]}} = beam_lib:chunks("ebin/billing.beam", [documentation]), io:format("~p~n", [D]), halt().' 2>&1 | head -12
rm -rf ebin
