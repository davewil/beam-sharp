#!/usr/bin/env bash
# 59f — CLAIM (ticket 18 §1 cost, quoted by ticket 59): "the same code un-exported has the test
# elided entirely". True for the BEAM compiler only when it can PROVE the caller's argument type.
# Under the `widen` compiler (is_integer on private fns too) we disassemble the FINAL BEAM code:
#   Scope:InnerInt  - private, sole caller ViaInt has is_integer(N)           -> test should vanish
#   Forge:Plus1     - private, fed by a list element (type unknown)           -> test should stay
#   Scope:OuterInt  - CONTROL, exported                                       -> test stays
# and, for the record tag test (shipped `cur` compiler), Scope:InnerTotal - sole caller ViaTotal
# already did `map_get('Kind',O) =:= 'Scope.Order'` - to see whether the optimiser removes THAT
# duplicate (it cannot: it has no record types).
set -uo pipefail
source "${ENV_SH:-/tmp/claude-0/-home-user-beam-sharp/5c54aeca-205c-5959-b98d-85886863a86f/scratchpad/env.sh}"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
export ERL_CRASH_DUMP=/dev/null
cd "$REPO"; build_variants
for v in widen cur; do for m in Scope Forge; do mkdir -p "$WORK/o_$v"; bsc_v $v "$PROBE/src" "$WORK/o_$v" "$PROBE/src/$m" >/dev/null; done; done
dis() { # beam fn  -> has is_integer? has map_get Kind?
  erl -noshell -eval '
   [B,F]=init:get_plain_arguments(), {beam_file,_,_,_,_,Fs}=beam_disasm:file(B),
   [{function,_,_,_,Is}] = [X || {function,N,_,_,_}=X <- Fs, atom_to_list(N)=:=F],
   Isint = lists:any(fun(I) -> is_tuple(I) andalso element(1,I)=:=test andalso element(2,I)=:=is_integer end, Is),
   Tag = lists:any(fun(I) -> is_tuple(I) andalso element(1,I)=:=test andalso element(2,I)=:=is_eq_exact end, Is),
   io:format("is_integer test: ~-5w  tag compare (is_eq_exact): ~w~n",[Isint,Tag]), halt().' -extra "$1" "$2"; }
echo "widen: Scope:InnerInt  (private, caller proves int)  $(dis "$WORK/o_widen/Scope.beam" InnerInt)"
echo "widen: Forge:Plus1     (private, list-element fed)   $(dis "$WORK/o_widen/Forge.beam" Plus1)"
echo "widen: Scope:OuterInt  (CONTROL exported)            $(dis "$WORK/o_widen/Scope.beam" OuterInt)"
echo "cur:   Scope:InnerTotal (private, caller did the tag test) $(dis "$WORK/o_cur/Scope.beam" InnerTotal)"
echo "cur:   Scope:InnerInt  (shipped: nothing emitted)    $(dis "$WORK/o_cur/Scope.beam" InnerInt)"
