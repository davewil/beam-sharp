#!/usr/bin/env bash
#
# A GATE THAT SHELLS TO A TOOL THE MANIFEST NEVER NAMED.
#
# `aeb4fd8` (2026-08-28): `check-switch-diagnostics.sh` ran `build-packet.py`
# through `python3`, and `run.sh` and `stage.sh` did too. python3 appeared in no
# manifest, no workflow step, no gate and no README, while `.tool-versions`
# opened by calling itself the only record of what this repository is built with.
# EVERY BUILD WAS GREEN THROUGHOUT, because the pinned runner image and the Xcode
# command line tools each happen to ship a python3.
#
# That is the whole shape of the class: an accident that holds on both machines a
# project is developed on is precisely the one that breaks on somebody else's —
# and the clean-room handoff is written for somebody else's. There is no red to
# notice, because the tool is there. `e517349` is the same class one step on: a
# gate shelled to python3 with no guard, so on a machine without one the failure
# arrived as a bare `python3: command not found` under a comment about packet
# staleness, sending the reader to LANGUAGE.md rather than to their PATH.
#
# `check-toolchain.sh --env` already asks whether every DECLARED tool is present.
# Nothing asked the other direction — whether every tool INVOKED is declared —
# and that is the direction the defect travels in.
#
# WHAT THIS FOUND WHEN IT WAS FIRST RUN. Three, all green on every build since
# they were written, all the aeb4fd8 shape exactly:
#
#   perl    `check-recursive-types.sh` uses `perl -e 'alarm N; exec @ARGV'` as
#           its stopwatch, three times. Its own line 16 explains the choice —
#           "timeout(1) is not on macOS; perl is" — so the dependency was
#           deliberate and simply never reached a manifest.
#   shasum  `build-handoff.sh`, `check-handoff-package.sh` and `check-tour.sh`
#           checksum the package and the published page with it.
#   tar     `check-links.sh` unpacks the built package.
#
# ---------------------------------------------------------------------------
# HOW A TOOL COUNTS AS DECLARED, AND WHY TWO OF THE THREE SETS ARE READ RATHER
# THAN LISTED.
#
#   pinned      `.tool-versions` names a PACKAGE; a package supplies BINARIES,
#               and no file in the repo maps one to the other. That map is the
#               one table below that has to be written by hand, and each row
#               carries the package it comes from so a reader can check it.
#   unpinned    read out of `check-toolchain.sh`'s own `required_unpinned` call,
#               not copied. A copy is a second source of truth with nothing
#               reconciling it, which is the arrangement `.tool-versions` says
#               this repository spent its first month policing.
#   guarded     a script that tests `command -v X` before using X has already
#               made the dependency visible and fails honestly without it. That
#               is `check-shell.sh` with shellcheck, and it is a correct answer
#               to this class rather than an exemption from it.
#   baseline    POSIX shell builtins and the coreutils every platform ships.
#
# THE BASELINE IS THE ONE JUDGEMENT CALL AND IT IS DELIBERATELY SHORT. Anything
# not on it must be declared, so the cost of a missing entry is a false red that
# gets fixed by adding a line here with a reason — never a silent green.

#
# THIS DETECTOR'S FINDINGS DEPEND ON THE HOST, in one direction. A word that is a
# parse artefact is only reported if `command -v` finds a binary of that name, so
# a machine with more binaries reports more. That is the fail-loud direction and
# CI is the strictest host - `/usr/bin/editor` exists on the ubuntu runner and
# not on macOS, which is how the case-arm bug above was found, by a red master
# under a green local pair. It also means the extraction has to be right on its
# own: the `command -v` filter is there to suppress noise, not to be the thing
# standing between this gate and a page of false positives.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# The library is linted in its own right by check-shell.sh, which enumerates
# detectors/lib without the executable test a sourced file can never pass. This
# suppresses only the note that shellcheck was not handed it here.
# shellcheck source=lib/shell-code.sh disable=SC1091
. "$ROOT/detectors/lib/shell-code.sh"

# The directories holding gate scripts. Enumerated here and asserted complete by
# `detect-unenumerated-dir.sh`, which is the gate for exactly the seam that let
# `handoff/audition-switch` sit unlinted for weeks.
GATE_DIRS=("bin" "compiler/bin" "editor/bin" "handoff/audition-switch" "detectors")

# POSIX builtins and the coreutils present on every platform this repository
# runs on. Short on purpose: see the header.
BASELINE=" [ [[ ]] awk basename break cat cd chmod cmp comm continue cp cut date
declare diff dirname echo env eval exec exit expr export false find getopts grep
hash head id kill ln local ls mkdir mktemp mv printf pwd read readonly return rm
rmdir sed seq set shift shopt sort source tail tee test times touch tr trap true
type typeset ulimit umask uname uniq unset wait wc xargs sleep command sh bash git "
# Written over several lines so it can be read; the membership test below is
# space-delimited, so the newlines have to go or every entry after the first line
# silently stops matching. That defect made this detector's first run report 92
# findings of which 3 were real — a detector that cries wolf gets switched off,
# which is the same reasoning check-shell.sh gives for keeping severity `style`
# out.
BASELINE="$(printf '%s' "$BASELINE" | tr '\n' ' ')"
KEYWORDS=" if then else elif fi for while until do done case esac function in select time coproc "

# THE ONE HAND-WRITTEN TABLE: which binaries each pinned package supplies. A
# manifest pins `erlang 28.5`; nothing in the tree says that is where `erlc`
# comes from. Each row names its package so the claim is checkable.
binaries_of_pinned() {
  local manifest="$1" pkg
  while read -r pkg _; do
    case "$pkg" in
      erlang)      printf 'erl\nerlc\nescript\ndialyzer\nerl_call\ntyper\n' ;;
      rebar)       printf 'rebar3\n' ;;
      node)        printf 'node\nnpm\nnpx\n' ;;
      tree-sitter) printf 'tree-sitter\n' ;;
      ''|\#*)      : ;;
    esac
  done < <(grep -vE '^[[:space:]]*(#|$)' "$manifest")
}

# Read, not copied: whatever `check-toolchain.sh` passes to `required_unpinned`
# outside its own self-test is the declaration.
# RETURNS 0 AND AN EMPTY LIST WHEN THE GATE HAS NO SUCH CALL. `required_unpinned`
# was added by aeb4fd8 itself, so on any tree older than 2026-08-28 the grep
# matches nothing, the pipeline fails under `pipefail`, and `set -e` killed the
# whole detector at the `declared=` line — exit 1 with NOT ONE WORD of output.
# Found by running this detector against `aeb4fd8^`, which is the one tree it
# most needed to work on.
unpinned_tools() {
  local gate="$1" out
  out="$(shell_code "$gate" |
    grep -oE 'required_unpinned[[:space:]]+[a-zA-Z0-9_. -]+' |
    sed -E 's/^required_unpinned[[:space:]]+//' |
    tr ' ' '\n' |
    grep -vE '^(bsharp-no-such-tool|sh)?$' |
    grep -v 'bsharp-no-such-tool' |
    sort -u || true)"
  printf '%s\n' "$out"
  return 0
}

# Every command this script runs, at a command position, with any `VAR=value`
# environment prefix consumed. Driven over `shell_code`, so prose, heredoc bodies
# and quoted strings are not mistaken for code — see that file for the two ways
# an earlier draft got this wrong in opposite directions.
commands_in() {
  shell_code "$1" |
    # ARITHMETIC IS NOT A COMMAND POSITION. `$(( start - 1 ))` opens with the same
    # two characters as a command substitution, so the command-position pattern
    # below reads `start` as a command — and `start` is a real binary on macOS.
    sed -E 's/\$\(\([^)]*\)\)/ /g' |
    sed -E 's/\{/ ; /g; s/\}/ ; /g' |
    grep -oE '(^|[|;&]|\([[:space:]]|\$\(|&&|\|\|)([[:space:]]*[A-Za-z_][A-Za-z0-9_]*=[^[:space:];|&()]*)*[[:space:]]*[a-zA-Z_][a-zA-Z0-9_.-]*[=[]?' |
    sed -E 's/^[^a-zA-Z_]*//; s/^([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)+//' |
    grep -vE '[=[]$' |
    sort -u
}

# Every case-arm label in a script, one alternation member per word.
#
# A CASE LABEL IS NOT A COMMAND POSITION, and `|` inside one is not a pipe. This
# has to be right or the rule is unsound in the reporting direction: in
# `_build/*|editor/node_modules/*)` the extractor sees a word after `|` and calls
# it a command. Three things the first draft got wrong, all of them found by CI
# rather than here:
#
#   the member class had no `/`, so a path glob matched nothing at all and the
#     whole arm went unprotected;
#   the match was anchored to `^`, so an arm sharing a line with its `case ... in`
#     - `case "$f" in _build/*|editor/node_modules/*) continue ;; esac` - was
#     never seen;
#   a member may be a path, and the extractor reports only its first segment, so
#     the label set has to carry that segment too.
#
# The alternation is spelled out rather than folded into one character class:
# putting whitespace in the class lets the pattern run past the arm and swallow
# an ordinary command line that happens to end in `)`, which would hide findings.
case_labels() {
  local script="$1" m arm
  m='[a-zA-Z0-9_.*/@?+-]+'
  arm="$m([[:space:]]*\|[[:space:]]*$m)*\)"
  {
    grep -oE "^[[:space:]]*\(?$arm" "$script"
    grep -oE "(^|[[:space:]])(in|;;)[[:space:]]+$arm" "$script" |
      sed -E 's/^[[:space:]]*(in|;;)[[:space:]]+//'
  } 2>/dev/null |
    tr -d ' )' | tr '|' '\n' |
    sed -E 's#/.*$##; s#\*##g' |
    grep -vE '^$' |
    sort -u | tr '\n' ' '
  return 0
}

# Report every command a script runs that is neither baseline, nor a function it
# defines, nor guarded by `command -v`, nor in the declared set. Parameters, so
# --self-test drives this function over fixtures rather than a copy of it.
undeclared_in() {
  local script="$1" declared="$2" w funcs guarded labels
  # Functions defined in the script AND in the libraries it sources. Without the
  # second half this detector reports `shell_code` — its own helper — as an
  # undeclared tool.
  funcs="$(grep -hoE '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$script" "$ROOT"/detectors/lib/*.sh 2>/dev/null | tr -d ' ()' | tr '\n' ' ')"
  guarded="$(grep -oE 'command -v [a-zA-Z0-9_.-]+' "$script" | awk '{print $3}' | tr '\n' ' ')"
  labels="$(case_labels "$script")"
  commands_in "$script" | while read -r w; do
    [ -z "$w" ] && continue
    case "$BASELINE" in *" $w "*) continue ;; esac
    case "$KEYWORDS" in *" $w "*) continue ;; esac
    case " $funcs " in *" $w "*) continue ;; esac
    case " $guarded " in *" $w "*) continue ;; esac
    case " $labels " in *" $w "*) continue ;; esac
    case " $declared " in *" $w "*) continue ;; esac
    # A word that names no binary anywhere is not a tool this repository depends
    # on; it is a parse artefact, and reporting it would be noise rather than a
    # finding.
    command -v "$w" >/dev/null 2>&1 || continue
    printf '%s: runs `%s`, which no manifest declares\n' "${script#"$ROOT"/}" "$w"
  done
}

# ---------------------------------------------------------------------------
# --self-test
#
# SEVEN CONTROLS, AND FIVE OF THEM ARE ABOUT READING SHELL RATHER THAN THE RULE.
# The rule — "an undeclared command is reported" — is nearly trivial. What is not
# trivial, and what two earlier drafts of `shell_code` got wrong in opposite
# directions, is telling code from prose in a repository whose gates are mostly
# prose. So each of those two failures gets a control of its own, and they pull
# against each other: `prose` requires silence over an English word that names a
# binary, `substitution` requires a report from inside a quoted span. A stripper
# that satisfies either one alone is one of the two drafts that shipped wrong.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT

  # `nl` is the stand-in undeclared tool: a real binary on every platform this
  # runs on, so `command -v` finds it, and on no list in this file.
  DECLARED=" cat grep "

  # POSITIVE — the defect. A gate that simply runs an undeclared tool.
  cat > "$CTL/bare.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
nl -ba somefile
SH

  # POSITIVE — the same defect reached through a command substitution inside a
  # DOUBLE-QUOTED span. This is `out="$(perl -e ...)"`, which is how
  # `check-recursive-types.sh` actually spells its stopwatch, and a stripper that
  # blanks everything inside quotes reports a clean tree over it.
  cat > "$CTL/substitution.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
out="$(nl -ba somefile)"
echo "$out"
SH

  # POSITIVE — an environment-variable prefix in front of the command, which is
  # the other spelling in check-recursive-types.sh.
  cat > "$CTL/envprefix.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
BS_NO_MEMO=1 nl -ba somefile
SH

  # NEGATIVE — prose. Every one of these words names a binary on macOS, and all
  # of them are inside a MULTI-LINE quoted string. A stripper that resets its
  # state at each newline reports every one of them.
  cat > "$CTL/prose.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "this gate will say more about the last split
  and will open a file to write what the machine does
  nl is mentioned here too and is still not run"
SH

  # NEGATIVE — a heredoc body. The B# programs the gates write are full of
  # identifiers that collide with binaries.
  cat > "$CTL/heredoc.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cat > /dev/null <<'PROG'
module Z
public int nl(int n)
nl(n) -> n
PROG
SH

  # NEGATIVE — case arms. Both spellings that were unprotected: an arm sharing a
  # line with its `case ... in`, and an arm at the start of its own line, each
  # with a path glob whose first segment names a binary. This is the exact shape
  # of `detect-split-table.sh:130`, and it turned master red.
  cat > "$CTL/casearm.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
for f in *; do
  case "$f" in _build/*|nl/generated/*) continue ;; esac
  case "$f" in
    _build/*|nl/vendor/*) continue ;;
    *) : ;;
  esac
done
SH

  # NEGATIVE — guarded. The dependency is visible and fails honestly.
  cat > "$CTL/guarded.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
command -v nl >/dev/null 2>&1 || { echo "nl is required"; exit 1; }
nl -ba somefile
SH
  chmod +x "$CTL"/*.sh

  fail=0
  expect_red() {
    if [ -z "$(undeclared_in "$CTL/$1.sh" "$DECLARED")" ]; then
      echo "SELF-TEST FAILED: $1 — $2"
      fail=1
    fi
  }
  expect_green() {
    local out; out="$(undeclared_in "$CTL/$1.sh" "$DECLARED")"
    if [ -n "$out" ]; then
      echo "SELF-TEST FAILED: $1 — $2"
      printf '  reported: %s\n' "$out"
      fail=1
    fi
  }

  expect_red bare "an undeclared tool run at a bare command position was not reported"
  expect_red substitution \
    "an undeclared tool inside \"\$( )\" was not reported. A command substitution
                  in a quoted span is CODE; a stripper that cannot see into it reports a
                  clean tree over the exact spelling check-recursive-types.sh uses"
  expect_red envprefix "an undeclared tool behind a VAR=value prefix was not reported"
  expect_green prose \
    "English words that happen to name binaries, inside a multi-line quoted
                  string, were reported as commands. That is 22 false positives on the
                  real tree and a detector nobody would leave switched on"
  expect_green heredoc "an identifier in a heredoc body was reported as a command"
  expect_green guarded "a tool guarded by \`command -v\` was reported; the guard IS the declaration"
  expect_green casearm \
    "a case-arm alternation member was reported as a command. \`|\` inside a case
                  label is not a pipe, and the member may be a path glob — this is the
                  false positive that turned master red under a green local pair"

  if [ "$fail" -eq 0 ]; then
    echo "self-test: reported the bare, substituted and prefixed calls; stayed silent on"
    echo "           prose, heredoc bodies, a guarded call and case-arm labels — it discriminates"
    exit 0
  fi
  exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
[ "${1:-}" = "" ] || { echo "usage: detect-unmanifested-tool.sh [--self-test]"; exit 2; }

MANIFEST="$ROOT/.tool-versions"
TOOLCHAIN_GATE="$ROOT/bin/check-toolchain.sh"
for f in "$MANIFEST" "$TOOLCHAIN_GATE"; do
  [ -f "$f" ] || { echo "cannot read $f — this detector is looking in the wrong place"; exit 1; }
done

declared=" $(binaries_of_pinned "$MANIFEST" | tr '\n' ' ')$(unpinned_tools "$TOOLCHAIN_GATE" | tr '\n' ' ')"

scanned=0
findings=""
for d in "${GATE_DIRS[@]}"; do
  [ -d "$ROOT/$d" ] || continue
  for s in "$ROOT/$d"/*.sh; do
    [ -x "$s" ] || continue
    scanned=$((scanned + 1))
    out="$(undeclared_in "$s" "$declared")"
    [ -n "$out" ] && findings+="$out"$'\n'
  done
done

# A run that scanned nothing is a run that found nothing, and the two look the
# same from outside. Say the count, and refuse a zero.
if [ "$scanned" -eq 0 ]; then
  echo "no gate scripts found — this detector is looking in the wrong place"
  exit 1
fi

if [ -n "$findings" ]; then
  printf '%s' "$findings"
  echo
  echo "Each of these is present on both machines this project is developed on and"
  echo "on the CI runner, so nothing goes red — which is exactly how python3 came to"
  echo "be a hard dependency of a gate while appearing in no manifest at all."
  echo "Declare it in .tool-versions (with a version, or in the note there as"
  echo "required-but-unpinned and in check-toolchain.sh's required_unpinned call),"
  echo "or guard the call with \`command -v\` so it fails by name."
  exit 1
fi

echo "$scanned gate scripts run only tools the manifest declares"
