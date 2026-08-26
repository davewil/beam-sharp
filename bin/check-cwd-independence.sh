#!/usr/bin/env bash
#
# A GATE MUST GIVE THE SAME ANSWER FROM ANY DIRECTORY.
#
# The workflow runs some gates from the repo root and others under
# `working-directory: compiler`, so a script that reaches for `./something` is
# correct in exactly one of those positions and silently wrong in the other.
# "Silently" is the operative word: a gate that cannot find the files it checks
# does not report an empty tree, it reports NO VIOLATIONS, which is the same
# output as success.
#
# The repo has paid for this once already: a README change was committed from
# the wrong directory and two gates therefore did not run at all — nothing said
# so, because a gate that never ran and a gate that passed look identical from
# the outside.
#
# NO GATE IN THE TREE VIOLATES THIS TODAY, and the way that was established is
# the reason the check is shaped the way it is. Grepping for `BASH_SOURCE`
# reported `check-diagnostics.sh` as the one script of nine that did not anchor
# itself. That was WRONG — it anchors with `cd "$(dirname "$0")/.."`, which is
# the same property spelled the other way. A grep for one spelling is a gate
# that measures a habit rather than a behaviour, and it produced a false
# accusation the first time it was pointed at the tree.
#
# THE CHECK IS THEREFORE A RUN, NOT A GREP. Each gate is executed twice — once
# from the repo root, once from a directory that shares nothing with it — and
# the two verdicts must agree. That is the property; how the script spells its
# anchor is not this gate's business.
#
# ONLY THE GATES THAT NEED NO COMPILER ARE RUN. The rest would each need a
# build, which would make this the slowest gate in the suite for a property the
# fast ones already demonstrate; they are checked statically instead, and the
# split is named in the output so a reader can see which claim rests on which.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The gates that need neither a built escript nor a toolchain, and so can be run
# twice cheaply. `check-corpus.sh` is excluded because it exits 0 when the
# tree-sitter CLI is absent, so its two runs would agree for a reason that has
# nothing to do with the property being measured.
RUNNABLE=(
  "bin/check-map.sh"
  "bin/check-surface.sh"
  "bin/check-links.sh"
  "bin/check-gates-wired.sh"
  # Its DEFAULT run compares `.tool-versions` against the workflow and needs no
  # toolchain at all — which is why the default is the drift half and `--env`,
  # which does need one, is a separate mode. A gate whose cheap answer depended
  # on what happened to be installed could not be run twice like this.
  "bin/check-toolchain.sh"
  "compiler/bin/check-diagnostics.sh"
  "compiler/bin/check-no-silent-skip.sh"
)

# Run one script from two different working directories and report if the exit
# codes disagree. A parameter rather than a hardcoded list, so --self-test walks
# the same code.
verdicts_differ() {
  local script="$1"
  local elsewhere="$2"
  local from_root from_away

  ( cd "$ROOT" && "$script" >/dev/null 2>&1 ); from_root=$?
  ( cd "$elsewhere" && "$script" >/dev/null 2>&1 ); from_away=$?

  if [ "$from_root" -ne "$from_away" ]; then
    printf '%s: exit %d from the repo root, exit %d from elsewhere\n' \
           "${script#"$ROOT"/}" "$from_root" "$from_away"
  fi
}

# ---------------------------------------------------------------------------
# --self-test
#
# The positive control is a script that reads a file beside it via a RELATIVE
# path — the actual defect, not an approximation of it. The negative control is
# the same script written correctly. If the check cannot separate those two it
# is measuring something else.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  AWAY="$(mktemp -d)"
  trap 'rm -rf "$CTL" "$AWAY"' EXIT

  echo "the file this gate needs" > "$CTL/data.txt"

  # POSITIVE CONTROL — cwd-dependent. Passes from its own directory, fails from
  # anywhere else, and says nothing about why.
  cat > "$CTL/bad.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
grep -q "needs" ./data.txt
SH

  # NEGATIVE CONTROL — resolves its own location, so both runs agree.
  cat > "$CTL/good.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
grep -q "needs" "$HERE/data.txt"
SH
  chmod +x "$CTL/bad.sh" "$CTL/good.sh"

  # The controls live outside ROOT, so drive them through a local runner that is
  # the same two-cd comparison rather than a second implementation of it.
  compare() {
    local s="$1" a b
    ( cd "$CTL" && "$s" >/dev/null 2>&1 ); a=$?
    ( cd "$AWAY" && "$s" >/dev/null 2>&1 ); b=$?
    [ "$a" -ne "$b" ] && echo "differs"
    return 0
  }

  fail=0
  if [ "$(compare "$CTL/bad.sh")" != "differs" ]; then
    echo "SELF-TEST FAILED: the cwd-dependent control was not caught"
    fail=1
  fi
  if [ "$(compare "$CTL/good.sh")" = "differs" ]; then
    echo "SELF-TEST FAILED: the correct script was reported as cwd-dependent"
    fail=1
  fi

  if [ "$fail" -eq 0 ]; then
    echo "self-test: caught the relative-path script, cleared the anchored one — the gate discriminates"
    exit 0
  fi
  exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
AWAY="$(mktemp -d)"
trap 'rm -rf "$AWAY"' EXIT

problems=""
for rel in "${RUNNABLE[@]}"; do
  s="$ROOT/$rel"
  [ -x "$s" ] || continue
  out="$(verdicts_differ "$s" "$AWAY")"
  [ -n "$out" ] && problems+="$out"$'\n'
done

# The gates that need a build are checked for an anchor instead of by running.
# This is the weaker claim of the two and is labelled as such rather than
# blended into the same sentence.
#
# BOTH SPELLINGS COUNT. `${BASH_SOURCE[0]}` and `$0` resolve to the same thing
# for a script that is executed rather than sourced, and accepting only the
# first is what made this check's own first draft accuse a correct script.
static=""
for s in "$ROOT"/bin/*.sh "$ROOT"/compiler/bin/*.sh "$ROOT"/editor/bin/*.sh; do
  [ -x "$s" ] || continue
  rel="${s#"$ROOT"/}"
  case " ${RUNNABLE[*]} " in *" $rel "*) continue ;; esac
  grep -qE 'BASH_SOURCE|dirname "\$0"|dirname \$0' "$s" \
    || static+="$rel: never resolves its own location"$'\n'
done

if [ -n "$problems" ] || [ -n "$static" ]; then
  [ -n "$problems" ] && { echo "measured by running from two directories:"; printf '%s' "$problems"; }
  [ -n "$static" ] && { echo "not run here, and missing the anchor:"; printf '%s' "$static"; }
  echo
  echo "A gate that cannot find its files reports no violations, which reads exactly"
  echo "like success. Resolve paths from \${BASH_SOURCE[0]} rather than from the cwd."
  exit 1
fi

echo "${#RUNNABLE[@]} gates give the same verdict from two directories; the rest carry the anchor"
