#!/usr/bin/env bash
#
# A SELF-TEST THAT INHERITS THE RUNNER'S ENVIRONMENT INSTEAD OF BUILDING ONE.
#
# `43771f0` (2026-08-29): "`verify.sh --self-test` has failed on every push since
# aba3fb0, taking master red for two commits, and it fails for a reason that
# cannot be seen from a developer machine."
#
# `ENG-274` gave `run_stages` GitHub Actions log grouping, correctly conditioned
# on `GITHUB_ACTIONS=true`, and a self-test with one control per half: a CI case
# that must emit `::group::` markers and a local case that must not. The CI case
# set the variable explicitly. THE LOCAL CASE SET NOTHING AT ALL — so it did not
# construct a local environment, it inherited whichever one was already there. On
# a laptop that is genuinely local and the control passes. On the runner the
# variable is already `true`, so the "local" case emitted groups and the
# assertion reported them as the defect it exists to catch. THE GATE WAS ACCUSING
# THE FEATURE OF WORKING.
#
# The commit's own summary of why it slipped is the rule this detector encodes:
# "It is not a shell portability difference and it is not timing — the two
# environments simply are not the same environment, and only one of them gates
# the push."
#
# ---------------------------------------------------------------------------
# WHY THE VOCABULARY IS CLOSED, AND SHORT.
#
# The general rule — "a control must not read an environment variable it did not
# set" — reports 39 findings on this tree and none of them is this class. Almost
# every gate here has a deliberate injection seam (`CHECK_MAP_DIR=$CTL
# ./check-map.sh`), which is a variable the self-test sets ON PURPOSE and which
# nothing in any ambient environment ever sets.
#
# What makes `GITHUB_ACTIONS` different is not that it is read; it is that
# SOMEBODY ELSE SETS IT. A variable the CI runner puts in the environment is the
# only kind whose value differs between the machine a control is written on and
# the machine that gates the push. That set is knowable and small, so it is
# written out below rather than inferred.
#
# THE RULE: if the code under test reads one of these, the self-test must both
# SET it and UNSET it explicitly — one control per half. Setting alone is what
# 43771f0 shipped.
#
# ZERO FINDINGS TODAY, AND THAT IS THE EXPECTED READING. 43771f0 fixed the only
# site and its own message records the sweep: "`GITHUB_ACTIONS` is read nowhere
# else in `bin/`, `compiler/bin/`, `editor/bin/` or the workflow." This is a
# regression guard, and the `--self-test` is where its evidence lives.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/shell-code.sh
. "$ROOT/detectors/lib/shell-code.sh"

GATE_DIRS=("bin" "compiler/bin" "editor/bin" "handoff/audition-switch" "detectors")

# Variables a CI runner puts in the environment. GitHub Actions sets every
# `GITHUB_*` and `RUNNER_*` name and `CI`; the three spelled out are the ones a
# script here would plausibly branch on.
RUNNER_VARS="GITHUB_ACTIONS CI RUNNER_OS GITHUB_REF GITHUB_SHA GITHUB_WORKFLOW CONTINUOUS_INTEGRATION"

# THE REGION IS FOUND IN STRIPPED CODE AND SLICED OUT OF THE RAW FILE.
#
# The obvious version — awk from the guard line to the first `^fi$` — ends the
# region inside the first heredoc that contains a shell `fi` at column 0. Every
# self-test here writes control scripts into heredocs, so the region stopped
# several controls early and this detector reported ITSELF for a repair that was
# three lines further down. `shell_code` blanks heredoc bodies, so the `fi` it
# sees is a real one; the line NUMBERS it reports are then used to slice the raw
# file, because the assertions being read are inside the quoted strings that
# `shell_code` blanks.
# The START is found in the RAW file and the END in the stripped one, because the
# two markers live in different places. The guard reads
# `[ "${1:-}" = "--self-test" ]`, so the words `--self-test` sit INSIDE a quoted
# span — which `shell_code` blanks, taking the start marker with it. The closing
# `fi` is bare code, and stripping is what tells it from the `fi` inside a
# heredoc.
region_bounds() {
  local f="$1" start
  start="$(grep -nE '^if \[ "\$\{1:-\}" = "--self-test" \]' "$f" | head -1 | sed -E 's/:.*//')"
  [ -z "$start" ] && return 0
  shell_code "$f" | awk -v s="$start" '
    NR > s && /^fi[[:space:]]*$/ { print s" "NR; exit }
  '
  return 0
}

selftest_region() {
  local b; b="$(region_bounds "$1")"
  [ -z "$b" ] && return 0
  sed -n "${b% *},${b#* }p" "$1"
  return 0
}

# Everything that is not the self-test region: the code the controls exercise.
outside_selftest() {
  local b; b="$(region_bounds "$1")"
  if [ -z "$b" ]; then cat "$1"; return 0; fi
  sed -n "1,$(( ${b% *} - 1 ))p" "$1"
  sed -n "$(( ${b#* } + 1 )),\$p" "$1"
  return 0
}

# Report a runner variable that the code under test branches on and whose
# self-test does not construct BOTH halves. Parameters, so --self-test drives
# this exact function over fixtures.
uncontrolled_in() {
  local script="$1" vars="$2" v outside region
  outside="$(outside_selftest "$script")"
  region="$(selftest_region "$script")"
  [ -z "$region" ] && return 0
  for v in $vars; do
    # A REAL EXPANSION, not the letters. `grep -F CI` matches the word "CI" in
    # every comment that mentions the runner — 25 findings on this tree, none of
    # them a variable at all, and this detector reported ITSELF for listing the
    # names in RUNNER_VARS.
    printf '%s' "$outside" | grep -qE '\$\{?'"$v"'[}:[:space:]"]' || continue
    # A LOCAL OF THE SAME NAME IS NOT THE RUNNER'S VARIABLE. `check-gates-wired.sh`
    # and `check-toolchain.sh` both hold a `CI` naming the workflow file, and
    # reporting those is a name collision rather than a finding.
    if printf '%s' "$outside" | grep -qE "(^|[[:space:];&|(])(local[[:space:]]+)?$v="; then
      continue
    fi
    local sets unsets
    sets=0; unsets=0
    printf '%s' "$region" | grep -qE "(^|[[:space:];&|(])$v=" && sets=1
    printf '%s' "$region" | grep -qE "unset[[:space:]]+([A-Za-z_]+[[:space:]]+)*$v([[:space:]]|;|\)|$)" && unsets=1
    if [ "$sets" = "1" ] && [ "$unsets" = "0" ]; then
      printf '%s: branches on $%s and its --self-test sets it but never unsets it\n' \
             "${script#"$ROOT"/}" "$v"
    elif [ "$sets" = "0" ] && [ "$unsets" = "0" ]; then
      printf '%s: branches on $%s and its --self-test neither sets nor unsets it\n' \
             "${script#"$ROOT"/}" "$v"
    fi
  done
  return 0
}

# ---------------------------------------------------------------------------
# --self-test
#
# The positive control is 43771f0 as it shipped: a CI half that sets the variable
# and a local half that sets nothing. The negative control is the fix — the same
# script with the local half unsetting it as explicitly as the CI half sets it.
# The third control is the one that stops this from firing on every gate in the
# tree: an injection seam the self-test sets and nothing else ever sets is not
# this class, and must stay green.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT

  # POSITIVE — 43771f0 as it shipped.
  cat > "$CTL/inherited.sh" <<'SH'
#!/usr/bin/env bash
run_it() { if [ "${GITHUB_ACTIONS:-}" = "true" ]; then echo "::group::x"; fi; echo hi; }
if [ "${1:-}" = "--self-test" ]; then
  out_ci="$(GITHUB_ACTIONS=true run_it)"
  out_local="$(run_it)"
  echo "$out_ci $out_local"
  exit 0
fi
run_it
SH

  # NEGATIVE — the fix.
  cat > "$CTL/controlled.sh" <<'SH'
#!/usr/bin/env bash
run_it() { if [ "${GITHUB_ACTIONS:-}" = "true" ]; then echo "::group::x"; fi; echo hi; }
if [ "${1:-}" = "--self-test" ]; then
  out_ci="$(GITHUB_ACTIONS=true run_it)"
  out_local="$(unset GITHUB_ACTIONS; run_it)"
  echo "$out_ci $out_local"
  exit 0
fi
run_it
SH

  # NEGATIVE — an injection seam. Set by the self-test, set by nobody else.
  cat > "$CTL/seam.sh" <<'SH'
#!/usr/bin/env bash
DIR="${CHECK_THING_DIR:-.}"
look() { ls "$DIR"; }
if [ "${1:-}" = "--self-test" ]; then
  CHECK_THING_DIR=/tmp look
  exit 0
fi
look
SH
  chmod +x "$CTL"/*.sh

  fail=0
  if [ -z "$(uncontrolled_in "$CTL/inherited.sh" "$RUNNER_VARS")" ]; then
    echo "SELF-TEST FAILED: a self-test that SETS \$GITHUB_ACTIONS for one control and"
    echo "                  leaves the other to inherit the runner's value was not reported."
    echo "                  That is 43771f0 exactly, and it took master red for two commits."
    fail=1
  fi
  out="$(uncontrolled_in "$CTL/controlled.sh" "$RUNNER_VARS")"
  if [ -n "$out" ]; then
    echo "SELF-TEST FAILED: the FIXED form — set in one control, unset in the other — was"
    echo "                  reported. A detector that cannot accept the repair is one nobody"
    echo "                  can act on."
    printf '  reported: %s\n' "$out"
    fail=1
  fi
  out="$(uncontrolled_in "$CTL/seam.sh" "$RUNNER_VARS")"
  if [ -n "$out" ]; then
    echo "SELF-TEST FAILED: a deliberate injection seam was reported. Nothing in any"
    echo "                  ambient environment sets CHECK_THING_DIR, so there is no other"
    echo "                  half to construct — and the general rule that would catch it"
    echo "                  reports 39 findings on this tree, none of them this class."
    printf '  reported: %s\n' "$out"
    fail=1
  fi

  if [ "$fail" -eq 0 ]; then
    echo "self-test: reported the half-constructed environment, accepted the repair, and"
    echo "           left a deliberate injection seam alone — the detector discriminates"
    exit 0
  fi
  exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
[ "${1:-}" = "" ] || { echo "usage: detect-inherited-runner-env.sh [--self-test]"; exit 2; }

scanned=0
findings=""
for d in "${GATE_DIRS[@]}"; do
  [ -d "$ROOT/$d" ] || continue
  for s in "$ROOT/$d"/*.sh; do
    [ -x "$s" ] || continue
    scanned=$((scanned + 1))
    out="$(uncontrolled_in "$s" "$RUNNER_VARS")"
    [ -n "$out" ] && findings+="$out"$'\n'
  done
done

if [ "$scanned" -eq 0 ]; then
  echo "no gate scripts found — this detector is looking in the wrong place"
  exit 1
fi

if [ -n "$findings" ]; then
  printf '%s' "$findings"
  echo
  echo "A control that sets a runner variable for one half and lets the other half"
  echo "inherit it is green on a laptop and red on the only machine that gates the"
  echo "push — or worse, green on both while measuring nothing. Construct both halves"
  echo "as explicitly as each other."
  exit 1
fi

echo "$scanned gate scripts construct the runner variables they branch on"
