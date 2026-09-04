#!/usr/bin/env bash
# Ticket 59, part 2/3 -- PATCH A: narrow the record tag test to exported-only
# (the "it is a defect, narrow it" reading), applied to the shipped compiler
# for measurement, and reverted before this script returns control -- success
# or failure. Kept short and self-contained, on purpose: this machine runs
# other agents against the same compiler/src tree, and the smaller the window
# compiler/src spends patched, the smaller the chance of colliding with one of
# them.
set -euo pipefail
REPO=/home/user/beam-sharp
COMP="$REPO/compiler"
BSC="$COMP/_build/default/bin/bsc"
HERE="$REPO/artifacts/59-probes"
cd "$HERE"

say() { echo; echo "=== $* ==="; }
compile_mod() {
  local dir="$1" mod="$2"
  rm -rf "out/$dir"; mkdir -p "out/$dir"
  ( cd src && "$BSC" --src-root . -o "../out/$dir" "$mod" )
}
cleanup() {
  git -C "$REPO" checkout -- compiler/src/bs_emit.erl 2>/dev/null || true
  ( cd "$COMP" && rebar3 escriptize >/tmp/patchA_cleanup_build.log 2>&1 ) || true
}
trap cleanup EXIT

if ! git -C "$REPO" diff --quiet -- compiler/src/bs_emit.erl; then
  echo "FATAL: compiler/src/bs_emit.erl is already dirty. Not measuring against an unknown baseline."
  git -C "$REPO" diff -- compiler/src/bs_emit.erl
  exit 1
fi

say "applying patch A"
python3 - "$COMP/src/bs_emit.erl" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = """    case record_tag(TypeExpr, Ctx) of
        {ok, Tag} ->"""
new = """    case record_tag(TypeExpr, Ctx) of
        %% TICKET 59 PROBE PATCH A -- narrow the tag test to exported-only,
        %% temporarily, for measurement. NOT the shipped rule.
        {ok, _Tag} when not Public -> {Pat, []};
        {ok, Tag} ->"""
assert old in s, "anchor not found for patch A"
open(p, "w").write(s.replace(old, new, 1))
PY
git -C "$REPO" diff --stat compiler/src/bs_emit.erl

say "building the patched compiler"
( cd "$COMP" && rebar3 escriptize )

say "compiling probes against the patched compiler"
compile_mod RecUnconstrainedPatchedA RecUnconstrained
compile_mod AttackPatched Attack

echo "--- F/1 (RecUnconstrained, private, record param) -- guard gone? ---"
grep "'F',1,\[" out/RecUnconstrainedPatchedA/RecUnconstrained.abstr || {
  echo "did not find the collapsed one-line clause form -- printing what IS there:"
  grep -A6 "'F',1,$" out/RecUnconstrainedPatchedA/RecUnconstrained.abstr
}

echo "--- Inner/1 (Attack, private, record param) -- guard gone? ---"
grep "'Inner',1,\[" out/AttackPatched/Attack.abstr || {
  grep -A6 "'Inner',1,$" out/AttackPatched/Attack.abstr
}

say "Code chunk size: unpatched (shipped) vs patched, RecUnconstrained.beam"
erl -noshell -eval 'chunk_size:main(["out/RecUnconstrained/RecUnconstrained.beam"]), halt().'
erl -noshell -eval 'chunk_size:main(["out/RecUnconstrainedPatchedA/RecUnconstrained.beam"]), halt().'

say "the forged-Invoice attack, AGAINST THE PATCHED COMPILER"
erl -noshell -pa "out/AttackPatched" -pa "$HERE" -s run_attack main

say "DONE with patch A. cleanup trap now reverts and rebuilds."
