#!/bin/sh
# Probe 60/02: ticket 18 §5, "elision is exported-vs-local, one entry label per function".
# Attempt 1 (run.first-attempt.out) crashed on a typo of mine: the atom is 'Charge', not charge. Nothing else changed.
# Compiles probe 01's Acme.Billing and reads the real .beam back.
export PATH=/tmp/otp/bin:$PATH LC_ALL=C.UTF-8
BSC=/tmp/claude-0/-home-user-beam-sharp/41c7fa9e-39c6-543b-8f3d-dee4a7daa0ba/scratchpad/bsc.sh
cd "$(dirname "$0")"; rm -rf beams; mkdir beams
SRC=../01_tree/src
$BSC --src-root $SRC -o beams $SRC/Acme/Billing >/dev/null 2>&1; echo "bsc Billing exit=$?"
$BSC --src-root $SRC -o beams $SRC/Acme/Billing/Ledger >/dev/null 2>&1; echo "bsc Ledger exit=$?"
ls beams
erl -noshell -pa beams -eval '
  M = (list_to_atom("Acme.Billing")),
  F = "beams/Acme.Billing.beam",
  io:format("module_info(exports) w/o module_info: ~p~n",
            [[E || {N,_}=E <- M:module_info(exports), N =/= module_info]]),
  {ok, {M, [{exports, Ex}, {locals, Lo}]}} = beam_lib:chunks(F, [exports, locals]),
  io:format("beam_lib exports chunk: ~p~nbeam_lib locals chunk : ~p~n", [Ex, Lo]),
  {beam_file, M, Exp, _Attr, _CI, Code} = beam_disasm:file(F),
  io:format("disasm exports: ~p~n", [Exp]),
  [io:format("function ~p/~p entry-label ~p  (labels inside body: ~p)~n",
     [N, A, E, [L || {label, L} <- Is]]) || {function, N, A, E, Is} <- Code, N =/= module_info],
  Charge = hd([Is || {function, 'Charge', 1, _, Is} <- Code]),
  io:format("Charge/1 calls (local call vs call_ext):~n"),
  [io:format("   ~p~n", [I]) || I <- Charge, element(1, I) =:= call orelse element(1,I) =:= call_only orelse element(1,I) =:= call_ext orelse element(1,I) =:= call_ext_only orelse element(1, I) =:= call_last orelse element(1,I)=:= call_ext_last],
  io:format("apply from outside the module, private name: ~p~n",
     [try apply(M, list_to_atom("Round"), [123]) catch C:R -> {C,R} end]),
  io:format("apply from outside the module, public name : ~p~n",
     [catch apply(M, list_to_atom("Charge"), [123])]),
  io:format("exported Ledger.Post called by an arbitrary shell process (no caller check exists): ~p~n",
     [apply(list_to_atom("Acme.Billing.Ledger"), list_to_atom("Post"), [41])]),
  halt().' 2>&1
rm -rf beams
