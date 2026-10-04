#!/bin/bash
# Probe 07 (survey: Erlang/OTP 28 compiler, beam_ssa_type.erl sig_local_call/opt_local_call/
# sig_make_fun): for a NON-exported function the compiler joins the argument types of every call
# site and treats the result as the parameter type, so a guard the callers already satisfy is
# removed by the optimiser; for an exported function it must assume `any`; a local function that is
# captured (`fun f/1`) gets `any` for its arguments. This is why a private `is_integer` is free in
# one shape of caller and +5 bytes in another (probe 03), and it is the BEAM-level analogue of
# "private call sites are all checked": the VM itself already exploits it.
cd "$(dirname "$0")"; . ./lib.sh
W=$(mktemp -d); cd $W
cat > loc.erl <<'ERL'
-module(loc).
-export([proven/1, unproven/1, captured/1, ex/1]).
%% every caller of l1 passes a proven integer -> guard on l1 is dead
l1(N) when is_integer(N) -> N * 2.
proven(N) when is_integer(N) -> l1(N).
%% one caller passes an unknown term -> guard on l2 must stay
l2(N) when is_integer(N) -> N * 2.
unproven(X) -> l2(map_get(q, X)).
%% a local function captured as a fun: its args are `any` whatever the call sites above say
l3(N) when is_integer(N) -> N * 2.
captured(L) -> lists:map(fun l3/1, L).
%% the same guard on an EXPORTED function is never removed
ex(N) when is_integer(N) -> N * 2.
ERL
erlc loc.erl
for f in "l1 1" "l2 1" "l3 1" "ex 1"; do set -- $f; echo "--- $1/$2: is_integer tests remaining in the emitted BEAM: $(asm loc.beam $1 $2 | grep -c 'is_integer')"; done
echo; echo "--- l1/1 disassembly (guard gone, and the multiply carries the PROVEN type t_integer):"; asm loc.beam l1 1
echo "--- l2/1 disassembly (guard kept):"; asm loc.beam l2 1
