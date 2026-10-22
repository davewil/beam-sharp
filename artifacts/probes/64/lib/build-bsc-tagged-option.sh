#!/usr/bin/env bash
# Second SCRATCH build: the OTP-25 build above PLUS the one-line prelude change that Option 1 means:
#   option<T> = T | :nothing        -->   option<T> = (:some, T) | :nothing
# in bs_check:stratum_one/0 ONLY. Built-in producers of a bare `T | :nothing` (ParseAtom, `as`, ...)
# are deliberately NOT changed, so this measures how much of the tree DEPENDS on the bare shape, not a finished feature.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$("$HERE/build-bsc-otp25.sh" | tail -1)"; BASE_WS="$(dirname "$(dirname "$(dirname "$(dirname "$(dirname "$BASE")")")")")"
WS="${BSC_WS_TAGGED:-/tmp/claude-0/ws64-tagged}"
if [ ! -x "$WS/compiler/_build/default/bin/bsc" ]; then
  rm -rf "$WS"; mkdir -p "$WS"; cp -r "$BASE_WS/compiler" "$WS/compiler"; cd "$WS/compiler"
  python3 - <<'PY'
p='src/bs_check.erl'; s=open(p).read()
old="""    #{option => {parametric, ['T'],
                 {t_union, [{t_ref, 'T'}, {t_atom, nothing}]}},"""
new="""    #{option => {parametric, ['T'],
                 {t_union, [{t_tuple, [{t_atom, some}, {t_ref, 'T'}]}, {t_atom, nothing}]}},"""
assert old in s; open(p,'w').write(s.replace(old,new))
PY
  rebar3 escriptize >"$WS/build.log" 2>&1 || { cat "$WS/build.log"; exit 1; }
fi
echo "$WS/compiler/_build/default/bin/bsc"
