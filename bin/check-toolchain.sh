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
# AND THE FIRST CHECK INVERTED ON 2026-08-26, WHICH IS WHY THIS FILE IS SMALLER
# THAN ITS HISTORY SUGGESTS.
#
# It used to compare the manifest against version literals copied into the
# workflow, because `with:` inputs cannot read a file and the four versions had
# to appear in each of two jobs. CI now installs with `jdx/mise-action`, which
# reads `.tool-versions` directly, so THE COPIES NO LONGER EXIST — and a check
# comparing against them would have reported "4 enumerated, 0 compared" forever.
# Two checks were deleted rather than left standing: that one, and the
# `version-type: strict` check, which guarded a setup-beam input that is gone.
# A gate that keeps asking a question its subject no longer has is precisely the
# vacuity the count rule below exists to catch.
#
# WHAT IT CHECKS
#   1. The manifest is the SOLE source (the default run, and it needs no
#      toolchain at all). The workflow must install from `.tool-versions` and
#      must not re-declare any version itself. A re-introduced literal is a
#      second source of truth with nothing reconciling it against the first.
#      The installer is REQUIRED, because a workflow that installs nothing
#      declares no versions either and would satisfy "no copies" perfectly.
#   2. Every `uses:` in the workflow names an immutable 40-character commit,
#      never a mutable tag. `@v4` is a moving reference: the code it runs today
#      is not the code it ran last week, and nothing in the repository records
#      which was which.
#   3. Every `runs-on:` names a pinned image, never `*-latest`. The precompiled
#      OTP is fetched from a path keyed to the runner's OS version, so the
#      machine label selects which toolchain arrives.
#   4. `--env`: the versions actually INSTALLED match the manifest, so a
#      mismatch is a clear failure BEFORE anything compiles rather than a
#      confusing one after. This is the one check one installer reading one
#      manifest does NOT make redundant: a tool that failed to install, or a
#      system copy earlier on PATH, both leave the manifest looking satisfied.
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

# THE MANIFEST IS THE SOLE SOURCE, AND THIS CHECK INVERTED WHEN mise ARRIVED.
#
# Until 2026-08-26 the main question here was "does every version literal in the
# workflow agree with the manifest", because `with:` inputs cannot read a file
# and the four versions had to be COPIED into each of two jobs. `jdx/mise-action`
# reads `.tool-versions` directly, so the copies are gone — and with them the
# only thing `drift()` had to compare. Keeping that function would have left a
# check reporting "4 enumerated, 0 compared" forever, which is this repository's
# most-repeated failure wearing a new hat.
#
# The right question is now the opposite one: IS THERE A COPY AT ALL? A
# re-introduced literal is a second source of truth with nothing checking it
# against the first, and it would be invisible — CI would install from the
# manifest and the literal would sit there looking authoritative.
#
# THE INSTALLER IS REQUIRED, AND THAT IS WHAT STOPS THIS PASSING VACUOUSLY. A
# workflow that installs no toolchain declares no versions either, and would
# satisfy "no copies" perfectly while building on whatever the runner shipped.
manifest_is_sole_source() {
  local manifest="$1" ci="$2" tool want declared rc n=0 clean=0 mise
  mise="$(grep -cE 'jdx/mise-action@' "$ci" || true)"
  if [ "$mise" -eq 0 ]; then
    printf 'the workflow names no `jdx/mise-action` step, so nothing installs the\n'
    printf '           manifest and every pin in it governs nothing that runs.\n'
  fi

  while read -r tool want; do
    [ -n "$tool" ] || continue
    n=$((n + 1))

    set +e
    declared="$(ci_declared "$ci" "$tool")"
    rc=$?
    set -e

    if [ "$rc" -eq 2 ]; then
      printf '%s %s: this gate does not know how the workflow would spell that tool,\n' "$tool" "$want"
      printf '           so it cannot say whether a copy of it is present.\n'
      continue
    fi
    if [ -n "$declared" ]; then
      printf '%s: the workflow declares %s itself while `.tool-versions` pins %s.\n' "$tool" "$declared" "$want"
      printf '           Two places to change it is how the two come apart.\n'
      continue
    fi
    clean=$((clean + 1))
  done <<EOF
$(manifest_tools "$manifest")
EOF

  printf 'count %d %d\n' "$n" "$clean"
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

  # The clean fixture is a mise-shaped workflow: an installer, and NOT ONE
  # VERSION STRING. That is the whole point of the arrangement it now checks.
  cat > "$CTL/clean.yml" <<YML
jobs:
  one:
    runs-on: ubuntu-24.04
steps:
  - uses: actions/checkout@$SHA_A # v4
  - uses: jdx/mise-action@$SHA_B # v4.3.0
    with:
      install: true
YML

  # A COPY COMES BACK. One literal re-introduced beside the manifest — the
  # arrangement this file spent its first month policing, now forbidden outright
  # because nothing reconciles it any more.
  cat "$CTL/clean.yml" > "$CTL/copy.yml"
  cat >> "$CTL/copy.yml" <<'YML'
  - uses: erlef/setup-beam@0000000000000000000000000000000000000000 # v1
    with:
      otp-version: "28.5"
YML

  # NO INSTALLER AT ALL. This is the vacuity control and it is the one a
  # plausible implementation fails: a workflow that installs nothing declares no
  # versions either, so a check that only looked for copies would call it
  # perfect while the build ran on whatever the runner image happened to ship.
  grep -v 'mise-action' "$CTL/clean.yml" > "$CTL/noinstaller.yml"

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

  clean_out="$(manifest_is_sole_source "$CTL/tool-versions" "$CTL/clean.yml")"
  copy_out="$(manifest_is_sole_source "$CTL/tool-versions" "$CTL/copy.yml")"
  noinst_out="$(manifest_is_sole_source "$CTL/tool-versions" "$CTL/noinstaller.yml")"
  unknown_out="$(manifest_is_sole_source "$CTL/tool-versions-unknown" "$CTL/clean.yml")"
  empty_out="$(manifest_is_sole_source "$CTL/tool-versions-empty" "$CTL/clean.yml")"
  pinned_out="$(floating_actions "$CTL/clean.yml")"
  float_out="$(floating_actions "$CTL/floating.yml")"
  runner_ok_out="$(floating_runner "$CTL/clean.yml")"
  runner_bad_out="$(floating_runner "$CTL/latest.yml")"

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

  if ! findings "$copy_out" | grep -q '^erlang: the workflow declares 28.5 itself'; then
    echo "SELF-TEST FAILED: a version literal re-introduced beside the manifest was not"
    echo "                  reported. That is a second source of truth with nothing"
    echo "                  reconciling it against the first — CI installs from the"
    echo "                  manifest and the literal sits there looking authoritative."
    fail=1
  fi
  if [ -z "$(count_violation "$copy_out" copy)" ]; then
    echo "SELF-TEST FAILED: a tool carrying a copy did not shorten the count, so a"
    echo "                  workflow that re-declared ALL FOUR would still report four"
    echo "                  clean tools"
    fail=1
  fi

  if ! findings "$noinst_out" | grep -q 'no .jdx/mise-action. step'; then
    echo "SELF-TEST FAILED: a workflow that installs NOTHING was accepted. It declares"
    echo "                  no versions either, so 'no copies' is perfectly satisfied —"
    echo "                  and the build would run on whatever the runner image ships."
    echo "                  This is the vacuity this whole file exists to refuse."
    fail=1
  fi

  if ! findings "$unknown_out" | grep -q '^gleam 1.18.1: this gate does not know'; then
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

  if [ "$fail" -eq 0 ]; then
    echo "self-test: caught the version literal re-introduced beside the manifest, the"
    echo "           workflow that installs nothing at all, the tool outside the table,"
    echo "           the manifest pinning nothing, the action on a mutable tag and the"
    echo "           job on a floating runner image — and left the fixture that installs"
    echo "           from the manifest, names no version and pins everything alone"
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
    d_out="$(manifest_is_sole_source "$MANIFEST" "$CI")"
    a_out="$(floating_actions "$CI")"
    r_out="$(floating_runner "$CI")"

    problems="$(findings "$d_out")
$(count_violation "$d_out" 'the manifest against the workflow')
$(findings "$a_out")
$(count_violation "$a_out" 'the workflow uses: lines')
$(findings "$r_out")
$(count_violation "$r_out" 'the workflow runs-on: lines')"

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
        awk '{printf "the manifest pins %d tools and the workflow re-declares none of the %d\n", $2, $3}'
      printf '%s\n' "$a_out" | grep '^count ' |
        awk '{printf "all %d uses: lines name an immutable commit\n", $2}'
      printf '%s\n' "$r_out" | grep '^count ' |
        awk '{printf "all %d runs-on: lines name a pinned runner image\n", $2}'
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
