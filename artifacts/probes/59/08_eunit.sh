#!/usr/bin/env bash
# 08 — run the repo's own eunit suite (compiler/test/*.erl) against each variant,
# on a COPY.  Caveats, all stated in the brief: OTP 25 not 28; lexer columns are
# approximate (leex on 25 has no TokenLoc) so tests asserting a column fail on EVERY
# variant including v0 — only the DIFFERENCE from v0 is a finding; the CLI tests
# run `_build/default/bin/bsc`, which here is a shell wrapper to the variant's ebin.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
SCRATCH=${SCRATCH:-/tmp/claude-0/-home-user-beam-sharp/9b30e02b-d742-5d59-8509-86bd14e28edc/scratchpad}
export PATH=/tmp/bin:$PATH
for v in ${VARIANTS:-v0 v1 v2}; do
  T=$SCRATCH/eu/$v; rm -rf "$T"; mkdir -p "$T/_build/default/bin" "$T/_build/test" "$T/tebin"
  cp -r "$REPO/compiler/test" "$REPO/compiler/examples" "$REPO/compiler/bin" "$REPO/compiler/bench" "$T/" 2>/dev/null
  mkdir -p "$T/src" && cp "$SCRATCH/var/$v/gen"/*.erl "$SCRATCH/var/$v/gen"/*.src "$T/src/" 2>/dev/null
  cp "$REPO"/compiler/src/*.xrl "$REPO"/compiler/src/*.yrl "$T/src/" 2>/dev/null || true
  cp "$SCRATCH/var/$v/bsc" "$T/_build/default/bin/bsc"
  erlc -o "$T/tebin" -pa "$SCRATCH/var/$v/ebin" "$T"/test/*.erl >/dev/null 2>&1
  ( cd "$T/_build/test" && timeout ${TMO:-900} erl -noshell -pa "$SCRATCH/var/$v/ebin" -pa "$T/tebin" -eval '
      Mods = [list_to_atom(filename:basename(F,".beam")) || F <- filelib:wildcard("'$T'/tebin/*_tests.beam")],
      R = eunit:test(Mods, [{report,{eunit_surefire,[{dir,"'$T'/report"}]}}]),
      io:format("RESULT ~p~n",[R]), halt().' > "$T/eunit.out" 2>&1 )
  echo "## $v: $(grep -c . "$T/eunit.out") lines; $(grep -o 'RESULT.*' "$T/eunit.out")"
done
