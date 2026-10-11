#!/usr/bin/env bash
# Reruns every probe for decision brief 57 from a clean scratch dir. Usage: ./run.sh [> output.txt]
# Slow parts (eunit and gates per variant, ~6 min each) are NOT here: see verify-variants.sh.
source /tmp/claude-0/env.sh
HERE=$(cd "$(dirname "$0")" && pwd); S=$(mktemp -d)
echo "== tool versions"; erl -noshell -eval 'io:format("erts ~s OTP ~s~n",[erlang:system_info(version),erlang:system_info(otp_release)]),halt().'
rebar3 version | tail -1; elixir --version | tail -1; gleam --version; elm --version
echo "== building variants into $S (A1 A2 B C C2 = prototypes, 0 = baseline from git archive HEAD)"
"$HERE/build-variants.sh" "$S"
for v in 0 A1 A2 B C C2; do
  echo; echo "################ variant $v: repro table + controls"; "$HERE/table.sh" "$S/bsc-$v" | cut -c1-135
done
for v in 0 A1 A2 B C C2; do echo; echo "################ variant $v: guards and patterns (does a guard agree with the refinement?)"; "$HERE/guards.sh" "$S/bsc-$v"; done
for v in 0 A1 A2 B C C2; do echo; echo "################ variant $v: a negative literal in value position"; [ $v = 0 ] || "$HERE/literal_arg.sh" "$S/bsc-$v"; done
for v in 0 B C2; do echo; echo "################ variant $v: residual printing and paste-back"; "$HERE/residual.sh" "$S/bsc-$v"; done
for v in 0 A2; do echo; echo "################ variant $v: the O(n)-tier diagnostic"; "$HERE/o_tier.sh" "$S/bsc-$v"; done
echo; echo "################ baseline: single-value refinement crash (no negative literal involved)"; "$HERE/baseline_singleton.sh" "$S/bsc-0"
echo; echo "################ delta program: Sign over Delta, run under C2"; "$HERE/delta_program.sh" "$S/bsc-C2"
echo; for v in 0 B C2; do echo "################ variant $v: what a negative literal is in a function body"; "$HERE/body_literal.sh" "$S/bsc-$v"; done
echo; echo "################ Erlang / Elixir survey"; "$HERE/survey_erlang_elixir.sh" 2>&1
echo; echo "################ Gleam survey"; "$HERE/survey_gleam_elm.sh" 2>&1
echo; echo "################ Elm survey"; "$HERE/survey_elm.sh" 2>&1 | head -12
echo; echo "################ prototype sizes (git diff --numstat against HEAD; all patches are standalone against HEAD)"
for p in "$HERE"/patch-*.diff; do printf '%-48s ' "$(basename $p)"; git apply --numstat "$p" | awk '{a+=$1;d+=$2} END{print "+"a" -"d}'; done
