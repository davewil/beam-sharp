#!/usr/bin/env bash
# H6: over the repo's own example corpus, (B) widening the int/float kind test to private functions
#     adds guards, and (C) eliding the record tag test on private functions removes guards;
#     A is the shipped rule. Counts are real bsc output (shimmed lexer, OTP 25) with a ONE-LINE
#     patch to bs_emit:guard_one/8 per variant (patches below). Falsifier: B adds 0 or C removes 0.
# Command: ./p6_corpus_variants.sh
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
S=/tmp/claude-0/-home-user-beam-sharp/e165fddb-d743-5cdb-816c-e9e70eb257c6/scratchpad
EX=/home/user/beam-sharp/compiler/examples
declare -A BIN=( [A]=$S/bsc [B]=$S/bscB [C]=$S/bscC )
echo "A = as shipped; B = kind test on private too; C = tag test exported-only"
echo "patch B:"; diff <(sed 's/^[[:space:]]*//' "$S/bsc/src/bs_emit.erl") <(sed 's/^[[:space:]]*//' "$S/bscB/src/bs_emit.erl") | head -12
echo "patch C:"; diff "$S/bsc/src/bs_emit.erl" "$S/bscC/src/bs_emit.erl" | head -6
# modules that compile under ALL three, so the sets are comparable
MODS=()
for d in "$EX"/*/; do m=$(basename "$d"); ok=1
  for v in A B C; do (cd "$EX/.." && "${BIN[$v]}/_build/default/bin/bsc" -o "$(mktemp -d)" --src-root examples "examples/$m" >/dev/null 2>&1) || ok=0; done
  [ $ok = 1 ] && MODS+=("$m") || echo "skipped (does not compile under all three on OTP 25): $m"
done
echo "compared modules: ${MODS[*]}"
for v in A B C; do
  OUT=$(mktemp -d)
  for m in "${MODS[@]}"; do (cd "$EX/.." && "${BIN[$v]}/_build/default/bin/bsc" -o "$OUT/$m" --src-root examples "examples/$m" >/dev/null 2>&1); done
  printf '%s: ' $v; escript "$HERE/count_guards.escript" "$OUT"
done
