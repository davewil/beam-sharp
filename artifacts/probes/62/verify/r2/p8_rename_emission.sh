#!/bin/sh
# PROBE 8 — "different emission": make the compiler emit snake_case ONLY (BS_ALIAS=rename patches
# bs_emit:emitted_name/3, the one place the header of bs_emit.erl says a B# name becomes an Erlang one).
# usage: p8_rename_emission.sh REPO ALIAS_EBIN OUTDIR
# EXPECTED (before run):
#   R1 Shop compiles and exports snake_case only ('which', 'new'; no 'Which'/'New').
#   R2 a module that CALLS another B# module by remote call (Shop.Billing -> Shop.Which) still
#      compiles, because bs_check records remote names only for OTP callbacks
#      (bs_check.erl remote_names/1) and the fallback in bs_emit:remote/5 is the WRITTEN name;
#   R3 ... and then FAILS AT RUN TIME with `undef` on 'Shop':'Which'/1: a one-place emission change
#      is not enough; bs_check's remote_names table must also carry the renamed name.
#   R4 an Erlang caller of the old spelling 'Shop':'New'(1) breaks (undef).
REPO=$1; EBIN=$2; OUT=$3; HERE=$(cd "$(dirname "$0")" && pwd); mkdir -p "$OUT"
BS_ALIAS=rename "$HERE/bsc-with.sh" "$EBIN" --src-root "$REPO/compiler/examples" -o "$OUT" "$REPO/compiler/examples/Shop/Billing" > "$OUT/compile.log" 2>&1; echo "compile exit=$?"
erl -noshell -pa "$OUT" -eval '
  Ex = lists:sort([N || {N,_} <- '"'"'Shop'"'"':module_info(exports), N =/= module_info, N =/= '"'"'bs@type_atoms'"'"']),
  io:format("Shop exports: ~p~n", [lists:sublist(Ex, 6)]),
  R1 = not lists:member('"'"'Which'"'"', Ex) andalso lists:member(which, Ex),
  R3 = case catch '"'"'Shop.Billing'"'"':label(#{'"'"'Kind'"'"' => '"'"'Shop.Order'"'"', '"'"'Id'"'"' => 1, '"'"'Total'"'"' => 2}) of
         {'"'"'EXIT'"'"', {undef, [{M, F, _, _} | _]}} -> io:format("Billing.label -> undef ~p:~p~n", [M, F]), true;
         Other -> io:format("Billing.label -> ~p~n", [Other]), false end,
  R4 = case catch '"'"'Shop'"'"':'"'"'New'"'"'(1) of {'"'"'EXIT'"'"', {undef, _}} -> true; _ -> false end,
  io:format("~s p8~n", [case R1 andalso R3 andalso R4 of true -> "PASS"; false -> "FAIL" end]), halt().'
