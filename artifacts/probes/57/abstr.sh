#!/usr/bin/env bash
# ABSTR probe. Reads the Arith module built by run.sh (needs a prior run.sh) and compares the emitted
# abstract format and .beam size for `Sub() -> 10 - -3`, `Mix()`.
# EXPECTED before run: base emits {op,_,'-',{integer,_,3}} for the operand `-3` (e_neg -> BEAM unary minus);
#   A and Aprod emit {integer,_,-3}; B0/Bn/Ba emit the same as base (they do not touch the parser).
#   The three .beam files' functions all return the same values (run.sh [ARITH]); .beam sizes may differ
#   by a few bytes because erlc constant-folds the operator form; EXPECTED: |size(A) - size(base)| < 64 bytes.
W=${W:-/tmp/claude-0/-home-user-beam-sharp/40070274-2489-5304-8393-d8d915b713dc/scratchpad/work/57}
fail=0
for v in base A Aprod B0 Bn Ba; do
  f=$W/run/obj/$v/Arith/Arith.abstr
  read n_op n_lit < <(erl -noshell -eval '{ok,Fs}=file:consult("'$f'"), W=fun W(T,P) when is_tuple(T) -> (case P(T) of true -> 1; false -> 0 end) + lists:sum([W(E,P)||E<-tuple_to_list(T)]); W(L,P) when is_list(L) -> lists:sum([W(E,P)||E<-L]); W(_,_) -> 0 end, U=fun({op,_,'"'"'-'"'"',{integer,_,3}}) -> true; (_) -> false end, Li=fun({integer,_,-3}) -> true; (_) -> false end, io:format("~p ~p~n",[W(Fs,U),W(Fs,Li)]), halt().')
  sz=$(stat -c %s "$W/run/obj/$v/Arith/Arith.beam")
  case $v in A|Aprod) want="op=0 lit>=1";; *) want="op>=1 lit=0";; esac
  case $v in A|Aprod) [ "$n_op" = 0 ] && [ "$n_lit" -ge 1 ] && ok=1 || ok=0;; *) [ "$n_op" -ge 1 ] && [ "$n_lit" = 0 ] && ok=1 || ok=0;; esac
  [ $ok = 1 ] && m=PASS || { m=FAIL; fail=1; }
  echo "$m $v abstract-format operand of -3: unary-op nodes=$n_op literal nodes=$n_lit (want $want); Arith.beam ${sz} bytes"
done
b=$(stat -c %s $W/run/obj/base/Arith/Arith.beam); a=$(stat -c %s $W/run/obj/A/Arith/Arith.beam)
d=$((a>b?a-b:b-a)); [ $d -lt 64 ] && echo "PASS beam size delta A vs base = $d bytes" || { echo "FAIL beam size delta $d"; fail=1; }
exit $fail
