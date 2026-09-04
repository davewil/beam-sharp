#!/usr/bin/env bash
# Ticket 59 probes -- reproduces every claim in the decision brief from a clean
# checkout. Patches bs_emit.erl twice, in place, to answer "what would this
# cost/break if the scope changed" -- and reverts each patch (via `git
# checkout`) before moving on. Confirms the tree is clean at both ends.
set -euo pipefail

REPO=/home/user/beam-sharp
COMP="$REPO/compiler"
BSC="$COMP/_build/default/bin/bsc"
HERE="$REPO/artifacts/59-probes"
cd "$HERE"

# However this script exits -- success, a real failure, or a self-check
# tripping -- leave compiler/src/bs_emit.erl exactly as git already has it.
# Without this, an assertion failure under `set -e` would abort mid-patch and
# hand the next reader (or the OTHER agents on this shared machine) a dirty
# compiler tree.
cleanup() {
  git -C "$REPO" checkout -- compiler/src/bs_emit.erl 2>/dev/null || true
  ( cd "$COMP" && rebar3 escriptize >/dev/null 2>&1 ) || true
}
trap cleanup EXIT

say() { echo; echo "=== $* ==="; }

require_clean() {
  if ! git -C "$REPO" diff --quiet -- compiler/src/bs_emit.erl; then
    echo "FATAL: compiler/src/bs_emit.erl is not clean. Aborting rather than measuring against"
    echo "an unknown baseline."
    git -C "$REPO" diff -- compiler/src/bs_emit.erl
    exit 1
  fi
}

build() { ( cd "$COMP" && rebar3 escriptize >/dev/null 2>&1 ); }

compile_mod() {
  local dir="$1" mod="$2"
  rm -rf "out/$dir"; mkdir -p "out/$dir"
  ( cd src && "$BSC" --src-root . -o "../out/$dir" "$mod" )
}

# This machine runs other agents concurrently against the same shared
# compiler/src tree (observed directly: a `compiler/src/bs_emit.erl` diff and
# an `artifacts/60-probes/` tree appeared mid-session that this session never
# wrote). A `rebar3 escriptize` racing against a concurrent one from another
# session could silently hand back a `bsc` built from the WRONG source. So
# every claim about what got emitted is re-checked against the .abstr text
# itself, not just against a runtime result -- a runtime result alone cannot
# distinguish "the guard fired" from "the guard was never there to begin
# with", which is exactly the failure mode a build race produces.
assert_abstr() {
  local file="$1" needle="$2" label="$3"
  if grep -qF "$needle" "$file"; then
    echo "  ok: $label"
  else
    echo "FATAL: $label -- expected to find in $file:"
    echo "  $needle"
    echo "This almost certainly means a concurrent build on this shared machine raced"
    echo "this script's rebar3 escriptize. Re-run from a quiet moment."
    exit 1
  fi
}

erlc_local() { ( cd "$HERE" && erlc -o "$HERE" "$1" >/dev/null ); }

require_clean
say "0. building the shipped compiler"
build

# ---------------------------------------------------------------------------
say "1. SUB-DECISION 1 -- which guard fires on a private function, today"
# ---------------------------------------------------------------------------
compile_mod Probe Probe
echo "--- Probe.abstr: PrivateOrder (record param, private) ---"
grep -A6 "'PrivateOrder',1," "out/Probe/Probe.abstr"
echo "--- Probe.abstr: PrivateOctet (refined-int param, private) ---"
grep -A2 "'PrivateOctet',1,\[" "out/Probe/Probe.abstr"

# ---------------------------------------------------------------------------
say "2. THE FORGED-RECORD ATTACK -- Order/Invoice, wrapped one field deep"
# ---------------------------------------------------------------------------
compile_mod Attack Attack
erlc_local run_attack.erl
echo "--- shipped compiler: forged Invoice through Outer(exported, unguarded) -> Inner(private) ---"
erl -noshell -pa "out/Attack" -pa "$HERE" -s run_attack main

say "2a. same attack, INT guard's existing exported-only scope (already shipped, unpatched)"
compile_mod AttackInt AttackInt
erlc_local run_attack_int.erl
echo "--- shipped compiler: forged binary/float through Outer(exported, unguarded) -> Inner(private) ---"
erl -noshell -pa "out/AttackInt" -pa "$HERE" -s run_attack_int main

# ---------------------------------------------------------------------------
say "3. PATCH A -- narrow the record tag test to exported-only"
# ---------------------------------------------------------------------------
cp "$COMP/src/bs_emit.erl" /tmp/bs_emit.erl.bak
python3 - "$COMP/src/bs_emit.erl" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = """    case record_tag(TypeExpr, Ctx) of
        {ok, Tag} ->"""
new = """    case record_tag(TypeExpr, Ctx) of
        {ok, _Tag} when not Public -> {Pat, []};
        {ok, Tag} ->"""
assert old in s, "anchor not found for patch A"
open(p, "w").write(s.replace(old, new, 1))
PY
build
compile_mod RecUnconstrainedPatchedA RecUnconstrained
compile_mod AttackPatched Attack
assert_abstr "out/RecUnconstrainedPatchedA/RecUnconstrained.abstr" \
  "{function,0,'F',1,[{clause,6,[{var,6,'_O'}],[],[{atom,6,ok}]}]}" \
  "patch A really removed F/1's tag guard (RecUnconstrained)"
assert_abstr "out/AttackPatched/Attack.abstr" \
  "{function,0,'Inner',1,[{clause,35,[{var,35,'_O'}],[],[{atom,35,accepted}]}]}" \
  "patch A really removed Inner/1's tag guard (Attack)"
echo "--- Code chunk size, private record-tagged F/1: before vs after narrowing ---"
erl -noshell -eval 'chunk_size:main(["out/RecUnconstrained/RecUnconstrained.beam"]), halt().'
erl -noshell -eval 'chunk_size:main(["out/RecUnconstrainedPatchedA/RecUnconstrained.beam"]), halt().'
echo "--- patched: the SAME forged-Invoice attack against Attack.bs ---"
erl -noshell -pa "out/AttackPatched" -pa "$HERE" -s run_attack main
git -C "$REPO" checkout -- compiler/src/bs_emit.erl
build
require_clean

# ---------------------------------------------------------------------------
say "4. PATCH B -- widen the int-kind test to private functions too"
# ---------------------------------------------------------------------------
python3 - "$COMP/src/bs_emit.erl" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace(
    "guard_one(Pat, {param, TypeExpr, _}, I, Line, Ctx, Public) ->",
    "guard_one(Pat, {param, TypeExpr, _}, I, Line, Ctx, _Public) ->",
    1)
old = """        none when Public ->
            int_guard(Pat, TypeExpr, I, Line, Ctx);
        none ->
            {Pat, []}
    end."""
new = """        none ->
            int_guard(Pat, TypeExpr, I, Line, Ctx)
    end."""
assert old in s, "anchor not found for patch B"
open(p, "w").write(s.replace(old, new, 1))
PY
build
compile_mod IntPrivatePatchedB IntPrivate
compile_mod IntPrivateTwoCallers IntPrivateTwoCallers
compile_mod AttackIntPatched AttackInt
assert_abstr "out/IntPrivatePatchedB/IntPrivate.abstr" \
  "{call,6,{remote,6,{atom,6,erlang},{atom,6,is_integer}},[{var,6,'N'}]}" \
  "patch B really added F/1's is_integer guard in SOURCE (IntPrivate) before any BEAM-level optimization"
assert_abstr "out/AttackIntPatched/AttackInt.abstr" \
  "{call,14,{remote,14,{atom,14,erlang},{atom,14,is_integer}},[{var,14,'N'}]}" \
  "patch B really added Inner/1's is_integer guard in SOURCE (AttackInt) before any BEAM-level optimization"
echo "--- trivial passthrough case: guard optimized away even after widening? ---"
erl -noshell -eval '
{beam_file,_,_,_,_,Fns} = beam_disasm:file("out/IntPrivatePatchedB/IntPrivate.beam"),
{value, {function,'"'"'F'"'"',1,_,Code}} = lists:keysearch('"'"'F'"'"',2,Fns),
io:format("~p~n",[Code]), halt().'
echo "--- two-caller passthrough case ---"
erl -noshell -eval '
{beam_file,_,_,_,_,Fns} = beam_disasm:file("out/IntPrivateTwoCallers/IntPrivateTwoCallers.beam"),
{value, {function,'"'"'F'"'"',1,_,Code}} = lists:keysearch('"'"'F'"'"',2,Fns),
io:format("~p~n",[Code]), halt().'
echo "--- the realistic (non-optimizable) wrapper case: forged binary/float now caught? ---"
erl -noshell -pa "out/AttackIntPatched" -pa "$HERE" -s run_attack_int main
echo "--- Code chunk size, AttackInt.beam: before vs after widening ---"
erl -noshell -eval 'chunk_size:main(["out/AttackInt/AttackInt.beam"]), halt().'
erl -noshell -eval 'chunk_size:main(["out/AttackIntPatched/AttackInt.beam"]), halt().'
git -C "$REPO" checkout -- compiler/src/bs_emit.erl
build
require_clean

say "DONE -- compiler/src/bs_emit.erl is back to the shipped version"
git -C "$REPO" status --short
