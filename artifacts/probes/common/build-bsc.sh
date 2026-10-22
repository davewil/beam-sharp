#!/usr/bin/env bash
# Build a SCRATCH copy of the repo compiler (never the repo) so it runs on OTP 25.
# usage: build-bsc.sh WORKDIR [PROTOTYPE.patch]
# Prints the path of the built bsc escript on the last line.
# The repo pins OTP 28.5; on OTP 25 plain `rebar3 escriptize` fails. The four
# edits below are the whole OTP-25 port (all applied to the COPY):
#   1. rebar.config: drop {xrl_opts,[{error_location,column}]}  (leex in OTP 25 has no such option)
#   2. rebar.config: drop the eunit->escriptize provider hook (not needed to build)
#   3. bs_lexer.xrl: TokenLoc -> {TokenLine,1}; add adjust_col/3 stub.  CONSEQUENCE: every
#      source column is reported as 1 (OTP 25 leex has no TokenLoc/column support). Line numbers intact.
#   4. bs_run.erl: io_lib "~kp" -> "~p" (OTP 25 has no ~k modifier). Affects only map key ordering in printed results.
set -euo pipefail
WORK=${1:?workdir}; PROTO=${2:-}
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
rm -rf "$WORK"; mkdir -p "$WORK"
cp -r "$REPO/compiler" "$WORK/compiler"
cd "$WORK/compiler"; rm -rf _build
sed -i '/^{xrl_opts/d' rebar.config
sed -i 's/{provider_hooks, \[{pre, \[{eunit, escriptize}\]}\]}\./{provider_hooks, []}./' rebar.config
sed -i 's/TokenLoc/{TokenLine,1}/g' src/bs_lexer.xrl
printf '\nadjust_col(_Chars, _Len, C) -> C.\n' >> src/bs_lexer.xrl
sed -i 's/~kp/~p/' src/bs_run.erl
if [ -n "$PROTO" ]; then patch -p1 < "$PROTO" >&2; fi
rebar3 escriptize >&2
echo "$WORK/compiler/_build/default/bin/bsc"
