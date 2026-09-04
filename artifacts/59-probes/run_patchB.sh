#!/usr/bin/env bash
# Ticket 59, part 3/3 -- PATCH B: widen the int-kind test to private functions
# too (matching the record tag test's current, accidentally-unconditional
# shape), applied and reverted the same way run_patchA.sh does.
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
  ( cd "$COMP" && rebar3 escriptize >/tmp/patchB_cleanup_build.log 2>&1 ) || true
}
trap cleanup EXIT

if ! git -C "$REPO" diff --quiet -- compiler/src/bs_emit.erl; then
  echo "FATAL: compiler/src/bs_emit.erl is already dirty. Not measuring against an unknown baseline."
  git -C "$REPO" diff -- compiler/src/bs_emit.erl
  exit 1
fi

say "applying patch B"
python3 - "$COMP/src/bs_emit.erl" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
s2 = s.replace(
    "guard_one(Pat, {param, TypeExpr, _}, I, Line, Ctx, Public) ->",
    "guard_one(Pat, {param, TypeExpr, _}, I, Line, Ctx, _Public) ->",
    1)
assert s2 != s, "head rename did not match"
old = """        none when Public ->
            int_guard(Pat, TypeExpr, I, Line, Ctx);
        none ->
            {Pat, []}
    end."""
new = """        none ->
            int_guard(Pat, TypeExpr, I, Line, Ctx)
    end."""
assert old in s2, "anchor not found for patch B"
s3 = s2.replace(old, new, 1)
assert s3 != s2, "case-body replace did not match"
open(p, "w").write(s3)
PY
git -C "$REPO" diff --stat compiler/src/bs_emit.erl
git -C "$REPO" diff compiler/src/bs_emit.erl

say "building the patched compiler"
( cd "$COMP" && rebar3 escriptize )

say "compiling probes against the patched compiler"
compile_mod IntPrivatePatchedB IntPrivate
compile_mod IntPrivateTwoCallers IntPrivateTwoCallers
compile_mod AttackIntPatched AttackInt

echo "--- F/1 (IntPrivate) SOURCE (.abstr), before any BEAM-level optimization ---"
grep -A6 "'F',1,$" out/IntPrivatePatchedB/IntPrivate.abstr

echo "--- F/1 (IntPrivate) COMPILED (disassembled) -- does OTP's own optimizer strip it? ---"
erl -noshell -eval '
{beam_file,_,_,_,_,Fns} = beam_disasm:file("out/IntPrivatePatchedB/IntPrivate.beam"),
{value, {function,'"'"'F'"'"',1,_,Code}} = lists:keysearch('"'"'F'"'"',2,Fns),
io:format("~p~n",[Code]), halt().'

echo "--- same question, two independent call sites (IntPrivateTwoCallers) ---"
erl -noshell -eval '
{beam_file,_,_,_,_,Fns} = beam_disasm:file("out/IntPrivateTwoCallers/IntPrivateTwoCallers.beam"),
{value, {function,'"'"'F'"'"',1,_,Code}} = lists:keysearch('"'"'F'"'"',2,Fns),
io:format("~p~n",[Code]), halt().'

echo "--- Inner/1 (AttackInt) SOURCE (.abstr) -- the realistic, non-optimizable case ---"
grep -A6 "'Inner',1,$" out/AttackIntPatched/AttackInt.abstr

say "the forged binary/float attack, AGAINST THE PATCHED COMPILER"
erl -noshell -pa "out/AttackIntPatched" -pa "$HERE" -s run_attack_int main

say "Code chunk size: unpatched (shipped) vs patched, AttackInt.beam"
erl -noshell -eval 'chunk_size:main(["out/AttackInt/AttackInt.beam"]), halt().'
erl -noshell -eval 'chunk_size:main(["out/AttackIntPatched/AttackInt.beam"]), halt().'

say "DONE with patch B. cleanup trap now reverts and rebuilds."
