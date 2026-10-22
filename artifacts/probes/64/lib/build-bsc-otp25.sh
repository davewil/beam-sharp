#!/usr/bin/env bash
# Builds a SCRATCH COPY of compiler/ under OTP 25 and prints the path of the
# resulting bsc escript on the last line. The repo is never modified.
# Patches applied to the COPY only (each is needed; without them OTP 25 refuses):
#   1. rebar.config: drop `{xrl_opts, [{error_location, column}]}`  (leex in OTP 25 has no such option)
#   2. bs_run.erl:   `~kp` -> `~p`                                  (the k modifier is OTP 26+)
#   3. bs_lexer.xrl: `TokenLoc` -> `{TokenLine,1}` and a stub adjust_col/3
#                    (leex in OTP 25 has no TokenLoc/column tracking). CONSEQUENCE: every token
#                    column is 1. Diagnostic COLUMNS are wrong; the checker/emitter are untouched.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../../.." && pwd)"
WS="${BSC_WS:-/tmp/claude-0/ws64-build}"
if [ ! -x "$WS/compiler/_build/default/bin/bsc" ]; then
  rm -rf "$WS"; mkdir -p "$WS"; cp -r "$REPO/compiler" "$WS/compiler"; rm -rf "$WS/compiler/_build"
  cd "$WS/compiler"
  sed -i '/^{xrl_opts/d' rebar.config
  sed -i 's/~kp/~p/' src/bs_run.erl
  sed -i 's/TokenLoc/{TokenLine,1}/g' src/bs_lexer.xrl
  printf '\nadjust_col(_Chars, Len, C) -> C + Len.\n' >> src/bs_lexer.xrl
  rebar3 escriptize >"$WS/build.log" 2>&1 || { cat "$WS/build.log"; exit 1; }
fi
echo "$WS/compiler/_build/default/bin/bsc"
