#!/usr/bin/env bash
#
# A FLOATING VERSION IS A CHECKOUT THAT CANNOT BE REPRODUCED.
#
# WHY THIS EXISTS
# Until 2026-08-26 this repository named `otp-version: "28"`, `rebar3-version:
# "3"`, `node-version: "22"` and a bare `npm install -g tree-sitter-cli` — four
# floating majors — and pinned its three third-party actions to `@v4`/`@v1`,
# which are branches wearing a tag's clothes. Nothing recorded a version at all
# outside the workflow, so a clean clone had nothing to install FROM, and the
# only complete verification recipe in the repository lived in agent-specific
# session instructions rather than in a file a person could read.
#
# That is the whole of it: a green build proved that SOME OTP 28 compiled the
# tree, and a recipient reproducing it had to guess which. The clean-room
# handoff is the thing this breaks — the reader has nobody to ask.
#
# WHAT IT CHECKS
#   1. DRIFT (the default run, and it needs no toolchain at all). Every tool
#      `.tool-versions` pins is declared with the SAME EXACT STRING everywhere
#      the workflow spells it. Exact, not prefix: `28` against a pinned `28.5`
#      is the defect this gate was written for, and a gate comparing majors
#      would pass the tree it was written against forever.
#   2. Every `uses:` in the workflow names an immutable 40-character commit,
#      never a mutable tag. `@v4` is a moving reference: the code it runs today
#      is not the code it ran last week, and nothing in the repository records
#      which was which.
#   3. `--env`: the versions actually INSTALLED match the manifest, so a
#      mismatch is a clear failure BEFORE anything compiles rather than a
#      confusing one after.
#
# THE COUNT IS PART OF THE CLAIM, AND THAT IS DELIBERATE.
# Both halves of this gate are greps, and a grep that finds nothing is
# indistinguishable from a grep that agrees. This repository has been bitten by
# exactly that twice — an absence asserted over a run that never compiled, and a
# 19/19 pass over a block nothing enumerated. So every check reports how many
# tools it pinned and how many it actually compared, and a short count is a
# failure in its own right. A tool this gate does not know where to look for is
# therefore an error, never a skip: the closed table in `ci_declared` is what
# makes the count honest.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---------------------------------------------------------------------------
# The manifest.
# ---------------------------------------------------------------------------

# `name version` per pinned tool, comments and blank lines removed. Both inputs
# to every function below are parameters so --self-test drives this exact code
# over a fixture rather than over a second copy of its logic.
manifest_tools() {
  local manifest="$1"
  sed -e 's/#.*//' -e 's/[[:space:]][[:space:]]*/ /g' -e 's/^ //' -e 's/ $//' "$manifest" |
    grep -v '^$' || true
}

# WHERE THE WORKFLOW SPELLS EACH TOOL — A CLOSED TABLE ON PURPOSE.
#
# The four tools have four different spellings and none of them is the manifest
# name: `erlang` is `otp-version`, `rebar` is `rebar3-version`, `node` is
# `node-version`, and `tree-sitter` is an npm package suffix. A table that
# silently returned "nothing to compare" for an unrecognised name would turn
# every future tool into a free pass, so an unknown one exits 2 and the caller
# treats that as a finding.
ci_declared() {
  local ci="$1" tool="$2" pat
  case "$tool" in
    erlang)      pat='otp-version:[[:space:]]*"?[^"[:space:]]+' ;;
    rebar)       pat='rebar3-version:[[:space:]]*"?[^"[:space:]]+' ;;
    node)        pat='node-version:[[:space:]]*"?[^"[:space:]]+' ;;
    tree-sitter) pat='tree-sitter-cli@[^"[:space:]]+' ;;
    *)           return 2 ;;
  esac
  # `sort -u` collapses the SAME version declared in several jobs, and keeps two
  # DIFFERENT ones apart — which is the point rather than a side effect. The
  # workflow has two jobs that each install the toolchain, so a version changed
  # in one and forgotten in the other reads here as a single tool declaring two
  # things, and fails against a manifest that pins one.
  grep -oE "$pat" "$ci" |
    sed -e 's/.*[:@][[:space:]]*//' -e 's/"//g' |
    sort -u |
    tr '\n' ',' | sed -e 's/,$//' -e 's/,/ and /g'
}

# What the machine running this actually has. Same closed-table rule: an unknown
# tool exits 2 rather than reporting nothing.
#
# `erl` is invoked from a scratch directory on purpose. A stray `C.beam` in the
# working directory shadows stdlib's `c` and kills the boot with
# `{undef,[{c,erlangrc,...}]}` — this repository's own algebra probes leave that
# detritus at the root, and it has already made one gate lie.
installed_version() {
  local tool="$1" scratch root major
  case "$tool" in
    erlang)
      command -v erl >/dev/null 2>&1 || return 1
      scratch="$(mktemp -d)"
      root="$(cd "$scratch" && erl -noshell -eval 'io:format("~s",[code:root_dir()]),halt().' 2>/dev/null)" || {
        rm -rf "$scratch"; return 1
      }
      major="$(cd "$scratch" && erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]),halt().' 2>/dev/null)" || {
        rm -rf "$scratch"; return 1
      }
      rm -rf "$scratch"
      # `otp_release` is the major alone — 28 for 28.5 — so the exact version
      # comes from the release's own OTP_VERSION file. Comparing the major is
      # the defect this gate exists to catch; it must not commit it itself,
      # which is why there is NO FALLBACK to `otp_release` when the file is
      # missing: a fallback would silently start comparing majors on exactly
      # the machines where the check matters most.
      #
      # A missing file gets exit 3 and its own message rather than the
      # not-installed one, because `erl` is plainly present and being told it is
      # not would send a reader down the wrong path entirely. Some prebuilt
      # tarballs ship without it.
      [ -f "$root/releases/$major/OTP_VERSION" ] || return 3
      # OTP appends `**` to the version of a build that is not a proper release.
      # Stripped, because it is a statement about the build's provenance and not
      # part of the number — left in, it reads as `28.5** != 28.5`, which is a
      # confusing way to say the versions match.
      tr -d '[:space:]' < "$root/releases/$major/OTP_VERSION" | sed 's/\**$//'
      ;;
    rebar)
      command -v rebar3 >/dev/null 2>&1 || return 1
      rebar3 --version 2>/dev/null | awk 'NR==1{print $2}'
      ;;
    node)
      command -v node >/dev/null 2>&1 || return 1
      node --version 2>/dev/null | sed 's/^v//'
      ;;
    tree-sitter)
      command -v tree-sitter >/dev/null 2>&1 || return 1
      tree-sitter --version 2>/dev/null | awk 'NR==1{print $2}'
      ;;
    *)
      return 2
      ;;
  esac
}

# ---------------------------------------------------------------------------
# The three checks. Each prints its findings and ALWAYS ends with a
# `count <pinned> <compared>` line, which `count_violation` then judges.
# ---------------------------------------------------------------------------

drift() {
  local manifest="$1" ci="$2"
  local tool want got rc pinned=0 compared=0

  while read -r tool want; do
    [ -n "$tool" ] || continue
    pinned=$((pinned + 1))

    set +e
    got="$(ci_declared "$ci" "$tool")"
    rc=$?
    set -e

    if [ "$rc" -eq 2 ]; then
      printf '%s %s: this gate does not know where the workflow declares it, so it\n' "$tool" "$want"
      printf '           cannot be compared. Add it to the table in ci_declared.\n'
      continue
    fi
    if [ -z "$got" ]; then
      printf '%s %s: pinned by the manifest and never declared in the workflow, so\n' "$tool" "$want"
      printf '           the pin governs nothing that runs.\n'
      continue
    fi
    if [ "$got" != "$want" ]; then
      printf '%s: the manifest pins %s, the workflow declares %s\n' "$tool" "$want" "$got"
    fi
    compared=$((compared + 1))
  done <<EOF
$(manifest_tools "$manifest")
EOF

  printf 'count %d %d\n' "$pinned" "$compared"
}

# A `uses:` that names a tag runs whatever that tag points at today. The value
# is stripped of a trailing `# v4` comment first, because the comment is how a
# pinned line stays readable and must not itself be mistaken for the ref.
floating_actions() {
  local ci="$1" line ref n=0 pinned=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    n=$((n + 1))
    ref="$(printf '%s' "$line" | sed -e 's/.*uses:[[:space:]]*//' -e 's/[[:space:]]*#.*//' -e 's/[[:space:]]*$//')"
    if printf '%s' "$ref" | grep -qE '^[A-Za-z0-9._-]+/[A-Za-z0-9._/-]+@[0-9a-f]{40}$'; then
      pinned=$((pinned + 1))
    else
      printf '%s: `%s` is a mutable reference, not a commit\n' "${line%%:*}" "$ref"
    fi
  done <<EOF
$(grep -nE '^[[:space:]]*(-[[:space:]]*)?uses:[[:space:]]*' "$ci" || true)
EOF

  printf 'count %d %d\n' "$n" "$pinned"
}

# `runs-on: ubuntu-latest` IS A FLOATING INPUT IN A REPOSITORY THAT PINS
# EVERYTHING ELSE, and it became load-bearing on 2026-08-26.
#
# It was always inconsistent — OTP, rebar, node, tree-sitter and every action are
# pinned exactly, and the machine they run on was whatever GitHub rolled out that
# week. What changed is that the precompiled Erlang this repository now installs
# is keyed to the runner's OS version: the build is fetched from
# `builds.hex.pm/builds/otp/<arch>/<os_ver>/`, so `ubuntu-latest` silently
# selects which OTP tarball arrives. When `ubuntu-latest` rolls forward to an
# image hex has no build for, the toolchain either changes underneath the pin or
# the install fails — and neither is a thing to discover from a red build weeks
# later.
#
# Same shape as the check above: a name that resolves to different things on
# different days is not a pin, whether it is a git tag or a runner label.
floating_runner() {
  local ci="$1" line img n=0 pinned=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    n=$((n + 1))
    img="$(printf '%s' "$line" | sed -e 's/.*runs-on:[[:space:]]*//' -e 's/[[:space:]]*#.*//' -e 's/[[:space:]]*$//')"
    case "$img" in
      *-latest)
        printf '%s: `%s` is a floating runner image, not a pinned one\n' "${line%%:*}" "$img"
        ;;
      *)
        pinned=$((pinned + 1))
        ;;
    esac
  done <<EOF
$(grep -nE '^[[:space:]]*runs-on:[[:space:]]*' "$ci" || true)
EOF

  printf 'count %d %d\n' "$n" "$pinned"
}

# AN EXACT-LOOKING VERSION IS NOT A PIN IF THE INSTALLER READS IT AS A RANGE.
#
# setup-beam defaults to `version-type: loose`, where the version is a SPEC and
# the newest matching build wins. Measured 2026-08-26 on the first CI run after
# this repository was "pinned": `otp-version: "28.5"` installed 28.5.0.5. The
# string was exact and the pin was not, which is the same defect as `28` wearing
# a better disguise — and the drift half above cannot see it, because it compares
# what the workflow SAYS against what the manifest says, and both said 28.5.
#
# So every setup-beam step is required to carry the line that makes its versions
# literal. Counted rather than merely grepped: one step with it and one without
# is the shape this would come back as.
loose_version_specs() {
  local ci="$1" beam strict
  beam="$(grep -cE 'erlef/setup-beam@' "$ci" || true)"
  strict="$(grep -cE 'version-type:[[:space:]]*strict' "$ci" || true)"

  if [ "$beam" -gt 0 ] && [ "$strict" -lt "$beam" ]; then
    printf '%d setup-beam step(s), only %d carrying `version-type: strict`\n' "$beam" "$strict"
    printf '           Without it the version is a range and the newest match wins.\n'
  fi
  printf 'count %d %d\n' "$beam" "$strict"
}

env_drift() {
  local manifest="$1"
  local tool want got rc pinned=0 compared=0

  while read -r tool want; do
    [ -n "$tool" ] || continue
    pinned=$((pinned + 1))

    set +e
    got="$(installed_version "$tool")"
    rc=$?
    set -e

    if [ "$rc" -eq 2 ]; then
      printf '%s %s: this gate does not know how to ask that tool its version\n' "$tool" "$want"
      continue
    fi
    if [ "$rc" -eq 3 ]; then
      printf '%s %s: the tool is installed and its exact version could not be read.\n' "$tool" "$want"
      printf '           This is not a missing toolchain — do not go looking for one.\n'
      continue
    fi
    if [ "$rc" -ne 0 ] || [ -z "$got" ]; then
      printf '%s %s: pinned by the manifest and not installed here\n' "$tool" "$want"
      continue
    fi
    if [ "$got" != "$want" ]; then
      printf '%s: the manifest pins %s, this machine has %s\n' "$tool" "$want" "$got"
    fi
    compared=$((compared + 1))
  done <<EOF
$(manifest_tools "$manifest")
EOF

  printf 'count %d %d\n' "$pinned" "$compared"
}

# THE COUNT RULE. Zero comparisons is a gate that never looked; fewer
# comparisons than pins is a gate that looked at some of it and reported
# success for the rest.
count_violation() {
  local out="$1" label="$2" line d c
  line="$(printf '%s\n' "$out" | grep '^count ' | tail -1 || true)"
  if [ -z "$line" ]; then
    printf '%s: reported no count at all, so nothing here is evidence\n' "$label"
    return
  fi
  d="$(printf '%s' "$line" | awk '{print $2}')"
  c="$(printf '%s' "$line" | awk '{print $3}')"
  if [ "$d" -eq 0 ]; then
    printf '%s: nothing was enumerated, so this check passed over an empty list\n' "$label"
    return
  fi
  if [ "$c" -ne "$d" ]; then
    printf '%s: %d enumerated, only %d actually compared\n' "$label" "$d" "$c"
  fi
}

# Findings are every line that is not the trailing count.
findings() {
  printf '%s\n' "$1" | grep -v '^count ' | grep -v '^$' || true
}

# ---------------------------------------------------------------------------
# --self-test
#
# SIX CONTROLS, AND THE FIRST TWO ARE THE ONES THAT EARN THIS GATE.
#
# MAJOR-ONLY is the plausible implementation, not a silly one: a gate that
# compares `28` against a pinned `28.5` and calls it agreement passes the tree
# this gate was written against, forever, while pinning nothing.
#
# MISSING is the vacuity control. If a tool is simply absent from the workflow,
# a grep finds nothing, and "nothing" reads as "no disagreement" — the same
# shape as the absence this repository has already asserted over a run that
# never happened. It must be reported AND must shorten the count.
#
# UNKNOWN is the same hole one step out: a tool the table does not know must not
# become a free pass. FLOATING and its pinned twin separate a mutable ref from a
# commit. EMPTY drives the count rule directly, because a manifest pinning
# nothing is the one input on which every other check is green for free.
#
# And CLEAN is the discrimination half: all four agreeing, every action pinned,
# and the gate must find nothing. A check that fires on everything satisfies
# every control above and is worthless.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT

  SHA_A="11d5960a326750d5838078e36cf38b85af677262"
  SHA_B="54075bcc5e249e4758d363f27d099f55d843f124"

  cat > "$CTL/tool-versions" <<'TV'
# a comment, and a blank line below it

erlang 28.5
rebar 3.27.0
node 22.22.3
tree-sitter 0.25.10
TV

  cat > "$CTL/clean.yml" <<YML
jobs:
  one:
    runs-on: ubuntu-24.04
steps:
  - uses: actions/checkout@$SHA_A # v4
  - uses: erlef/setup-beam@$SHA_B # v1
    with:
      version-type: strict
      otp-version: "28.5"
      rebar3-version: "3.27.0"
  - uses: actions/setup-node@$SHA_A # v4
    with:
      node-version: "22.22.3"
  - run: npm install -g tree-sitter-cli@0.25.10
YML

  # MAJOR-ONLY: every version present, one of them truncated to its major.
  sed 's/otp-version: "28.5"/otp-version: "28"/' "$CTL/clean.yml" > "$CTL/major.yml"

  # MISSING: node is pinned by the manifest and never mentioned by the workflow.
  grep -v 'node-version' "$CTL/clean.yml" > "$CTL/missing.yml"

  # FLOATING: one action back on a mutable tag.
  sed "s|actions/checkout@$SHA_A # v4|actions/checkout@v4|" "$CTL/clean.yml" > "$CTL/floating.yml"

  # LATEST-RUNNER: the machine goes back to whatever GitHub ships this week,
  # while every version string in the file stays exactly as pinned. Nothing else
  # in this gate can see it.
  sed 's|runs-on: ubuntu-24.04|runs-on: ubuntu-latest|' "$CTL/clean.yml" > "$CTL/latest.yml"

  # UNKNOWN: a fifth tool the table has never heard of.
  cp "$CTL/tool-versions" "$CTL/tool-versions-unknown"
  echo "gleam 1.18.1" >> "$CTL/tool-versions-unknown"

  # EMPTY: a manifest that pins nothing at all.
  printf '# nothing pinned yet\n\n' > "$CTL/tool-versions-empty"

  # LOOSE: the version strings are exact and the installer still reads them as a
  # range. This is the defect that reddened master on 2026-08-26, and it is
  # invisible to every other control here — the manifest and the workflow agree
  # perfectly, and `28.5` installs 28.5.0.5.
  grep -v 'version-type: strict' "$CTL/clean.yml" > "$CTL/loose.yml"

  # SECOND-JOB-LOOSE: one setup-beam step pinned strictly and one not. The count
  # is what sees this; a bare grep for the line finds it and calls the file fine.
  cat "$CTL/clean.yml" > "$CTL/halfstrict.yml"
  cat >> "$CTL/halfstrict.yml" <<YML
  second-job:
    steps:
      - uses: erlef/setup-beam@$SHA_B # v1
        with:
          otp-version: "28.5"
          rebar3-version: "3.27.0"
YML

  # TWO JOBS, ONE UPDATED. The workflow has a second job that installs the same
  # toolchain, so this is not hypothetical: bump one and forget the other and
  # every version string is still present, every grep still finds something, and
  # the two halves of CI build different compilers.
  cat "$CTL/clean.yml" > "$CTL/twojobs.yml"
  cat >> "$CTL/twojobs.yml" <<YML
  second-job:
    steps:
      - uses: erlef/setup-beam@$SHA_B # v1
        with:
          otp-version: "28.4.3"
          rebar3-version: "3.27.0"
YML

  clean_out="$(drift "$CTL/tool-versions" "$CTL/clean.yml")"
  major_out="$(drift "$CTL/tool-versions" "$CTL/major.yml")"
  missing_out="$(drift "$CTL/tool-versions" "$CTL/missing.yml")"
  unknown_out="$(drift "$CTL/tool-versions-unknown" "$CTL/clean.yml")"
  empty_out="$(drift "$CTL/tool-versions-empty" "$CTL/clean.yml")"
  twojobs_out="$(drift "$CTL/tool-versions" "$CTL/twojobs.yml")"
  pinned_out="$(floating_actions "$CTL/clean.yml")"
  float_out="$(floating_actions "$CTL/floating.yml")"
  runner_ok_out="$(floating_runner "$CTL/clean.yml")"
  runner_bad_out="$(floating_runner "$CTL/latest.yml")"
  strict_out="$(loose_version_specs "$CTL/clean.yml")"
  loose_out="$(loose_version_specs "$CTL/loose.yml")"
  half_out="$(loose_version_specs "$CTL/halfstrict.yml")"

  fail=0

  if [ -n "$(findings "$clean_out")" ]; then
    echo "SELF-TEST FAILED: a manifest and a workflow that agree exactly were reported"
    echo "                  as drifting, so this gate fires on everything and would be"
    echo "                  switched off within a week"
    echo "$clean_out"
    fail=1
  fi
  if [ -n "$(count_violation "$clean_out" clean)" ]; then
    echo "SELF-TEST FAILED: four pinned tools were not four comparisons on the clean"
    echo "                  fixture, so the count rule cannot be trusted below"
    fail=1
  fi

  if ! findings "$major_out" | grep -q '^erlang: the manifest pins 28.5, the workflow declares 28$'; then
    echo "SELF-TEST FAILED: a workflow declaring the MAJOR 28 against a pinned 28.5 was"
    echo "                  not reported — which is the exact state of this repository"
    echo "                  before this gate, and a gate comparing majors passes it"
    echo "                  forever while pinning nothing"
    fail=1
  fi

  if ! findings "$missing_out" | grep -q '^node 22.22.3: pinned by the manifest and never declared'; then
    echo "SELF-TEST FAILED: a tool absent from the workflow was not reported. A grep"
    echo "                  that finds nothing is not agreement."
    fail=1
  fi
  if [ -z "$(count_violation "$missing_out" missing)" ]; then
    echo "SELF-TEST FAILED: a tool that could not be compared did not shorten the count,"
    echo "                  so a workflow declaring NOTHING would report four clean"
    echo "                  comparisons"
    fail=1
  fi

  if ! findings "$twojobs_out" | grep -q '^erlang: the manifest pins 28.5, the workflow declares 28.4.3 and 28.5$'; then
    echo "SELF-TEST FAILED: two jobs declaring DIFFERENT versions of the same tool were"
    echo "                  not reported. Every string is present and every grep finds"
    echo "                  something, so a check that stopped at the first match calls"
    echo "                  this agreement while the two halves of CI build different"
    echo "                  compilers"
    fail=1
  fi

  if ! findings "$unknown_out" | grep -q '^gleam 1.18.1: this gate does not know where'; then
    echo "SELF-TEST FAILED: a tool outside the table was skipped rather than reported,"
    echo "                  which makes every tool added after today a free pass"
    fail=1
  fi

  if [ -z "$(count_violation "$empty_out" empty)" ]; then
    echo "SELF-TEST FAILED: a manifest pinning nothing was accepted. Every check in this"
    echo "                  file is green for free on an empty list."
    fail=1
  fi

  if ! findings "$float_out" | grep -q 'actions/checkout@v4.*mutable reference'; then
    echo "SELF-TEST FAILED: an action on a mutable tag was not reported"
    fail=1
  fi
  if [ -n "$(findings "$pinned_out")" ]; then
    echo "SELF-TEST FAILED: actions pinned to a 40-character commit were reported as"
    echo "                  mutable, so the pin check does not discriminate"
    echo "$pinned_out"
    fail=1
  fi
  if [ -n "$(count_violation "$pinned_out" pinned)" ]; then
    echo "SELF-TEST FAILED: the pin check did not count three uses: lines, so it could"
    echo "                  report success over a workflow that uses no actions at all"
    fail=1
  fi

  if ! findings "$runner_bad_out" | grep -q 'ubuntu-latest.*floating runner image'; then
    echo "SELF-TEST FAILED: a job on \`ubuntu-latest\` was not reported. Every version"
    echo "                  string in that fixture is exactly pinned, so no other check"
    echo "                  here can see it — and the precompiled OTP that gets"
    echo "                  installed is selected BY the runner image."
    fail=1
  fi
  if [ -n "$(findings "$runner_ok_out")" ]; then
    echo "SELF-TEST FAILED: a pinned runner image was reported as floating, so the"
    echo "                  runner check does not discriminate"
    echo "$runner_ok_out"
    fail=1
  fi
  if [ -n "$(count_violation "$runner_ok_out" runner)" ]; then
    echo "SELF-TEST FAILED: the runner check enumerated no runs-on: lines, so it would"
    echo "                  report success over a workflow that names no machine at all"
    fail=1
  fi

  if ! findings "$loose_out" | grep -q 'only 0 carrying'; then
    echo "SELF-TEST FAILED: a setup-beam step without \`version-type: strict\` was not"
    echo "                  reported. Every version string is exact and the installer"
    echo "                  still takes the newest match — which is how a pinned 28.5"
    echo "                  installed 28.5.0.5 and reddened master"
    fail=1
  fi
  if ! findings "$half_out" | grep -q '2 setup-beam step(s), only 1'; then
    echo "SELF-TEST FAILED: one strict step and one loose step was called fine, so the"
    echo "                  check greps rather than counts and a second job can float"
    fail=1
  fi
  if [ -n "$(findings "$strict_out")" ]; then
    echo "SELF-TEST FAILED: a workflow whose setup-beam step IS strict was reported as"
    echo "                  loose, so the check does not discriminate"
    echo "$strict_out"
    fail=1
  fi

  if [ "$fail" -eq 0 ]; then
    echo "self-test: caught the major-only comparison, the tool the workflow never"
    echo "           declares, the two jobs declaring different versions of one tool,"
    echo "           the tool outside the table, the manifest pinning nothing, the"
    echo "           action on a mutable tag, the job on a floating runner image, the"
    echo "           setup-beam step reading its exact version as a range and the"
    echo "           second job that reads it loosely — and left the exactly agreeing,"
    echo "           fully pinned fixture alone"
    exit 0
  fi
  exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
MANIFEST="$ROOT/.tool-versions"
CI="$ROOT/.github/workflows/ci.yml"

[ -f "$MANIFEST" ] || {
  echo "no manifest at .tool-versions — there is nothing for a clean clone to install"
  echo "from, and no single place this repository records what it is built with."
  exit 1
}
[ -f "$CI" ] || { echo "no workflow at .github/workflows/ci.yml"; exit 1; }

MODE="${1:-drift}"
rc=0

case "$MODE" in
  drift|--drift)
    d_out="$(drift "$MANIFEST" "$CI")"
    a_out="$(floating_actions "$CI")"
    r_out="$(floating_runner "$CI")"
    v_out="$(loose_version_specs "$CI")"

    problems="$(findings "$d_out")
$(count_violation "$d_out" 'the manifest against the workflow')
$(findings "$a_out")
$(count_violation "$a_out" 'the workflow uses: lines')
$(findings "$r_out")
$(count_violation "$r_out" 'the workflow runs-on: lines')
$(findings "$v_out")"

    if [ -n "$(printf '%s\n' "$problems" | grep -v '^$' || true)" ]; then
      printf '%s\n' "$problems" | grep -v '^$'
      echo
      echo "The manifest at .tool-versions is the single source of truth for the"
      echo "toolchain. A workflow that declares a different version, or a version the"
      echo "manifest never pins, means a clean clone and CI are building different"
      echo "things — which is the whole of what the clean-room handoff cannot survive."
      rc=1
    else
      printf '%s\n' "$d_out" | grep '^count ' |
        awk '{printf "the manifest pins %d tools and the workflow declares all %d identically\n", $2, $3}'
      printf '%s\n' "$a_out" | grep '^count ' |
        awk '{printf "all %d uses: lines name an immutable commit\n", $2}'
      printf '%s\n' "$r_out" | grep '^count ' |
        awk '{printf "all %d runs-on: lines name a pinned runner image\n", $2}'
      printf '%s\n' "$v_out" | grep '^count ' |
        awk '{printf "all %d setup-beam step(s) read their versions literally\n", $2}'
    fi
    ;;

  --env)
    e_out="$(env_drift "$MANIFEST")"

    problems="$(findings "$e_out")
$(count_violation "$e_out" 'the manifest against this machine')"

    if [ -n "$(printf '%s\n' "$problems" | grep -v '^$' || true)" ]; then
      printf '%s\n' "$problems" | grep -v '^$'
      echo
      echo "This machine is not running the toolchain this repository is pinned to, so"
      echo "anything built here is not the thing CI builds. Install the pinned versions"
      echo "before compiling:"
      echo
      echo "    mise install          # reads .tool-versions"
      echo
      echo "The tree-sitter CLI is also available as an npm package, if that is how this"
      echo "machine gets it: npm install -g tree-sitter-cli@\$(awk '/^tree-sitter /{print \$2}' .tool-versions)"
      rc=1
    else
      printf '%s\n' "$e_out" | grep '^count ' |
        awk '{printf "all %d pinned tools are installed here at exactly the pinned version\n", $3}'
    fi
    ;;

  *)
    echo "usage: check-toolchain.sh [--drift | --env | --self-test]"
    exit 2
    ;;
esac

exit "$rc"
