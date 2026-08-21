#!/usr/bin/env bash
#
# A VERIFICATION SCRIPT THAT NOTHING RUNS IS NOT A GATE.
#
# `ci.yml`'s closing block already states this rule in prose — "A new
# verification script belongs in this file on the day it is written" — and the
# repo has broken it twice, both times for the same reason: prose cannot check
# itself.
#
#   `check-map.sh` was written when the map was split on 2026-08-15 and was
#   NEVER WIRED IN. It ran only when somebody remembered. On the day it was
#   finally added to the workflow it was already catching two real defects per
#   run, which is what it had been failing to catch for as long as it existed.
#
#   `editor/bin/` held TWO gates the workflow had never mentioned — not
#   excluded with a reason, simply never considered. They accumulated five
#   shipped features' worth of grammar drift while every gate named in the
#   workflow stayed green.
#
# The second one is the instructive one: the workflow's own header block listed
# the checks it deliberately excluded, so an author reading it would conclude
# nothing was missing. An unmentioned check is not outside the rule; it is the
# rule's blind spot, and a blind spot is exactly the thing a human reviewer
# cannot be relied on to see.
#
# This gate is the rule as code. It enumerates what is on disk and asks the
# workflow about each one, so a gate added tomorrow is wired tomorrow or the
# build goes red naming it.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Enumerate the executable shell gates and report any the workflow never names.
# Both inputs are parameters so --self-test can drive the identical function
# over a fixture rather than over a copy of its logic.
unwired() {
  local ci="$1"; shift
  local dir script name
  for dir in "$@"; do
    [ -d "$dir" ] || continue
    for script in "$dir"/*.sh; do
      [ -e "$script" ] || continue
      [ -x "$script" ] || continue
      name="$(basename "$script")"
      # The workflow names a gate by its path, so the basename is the anchor —
      # `./bin/check-map.sh` and `./compiler/bin/spec-check.sh` both match on it
      # without this gate having to know which working-directory the step uses.
      if ! grep -qF "$name" "$ci"; then
        printf '%s: never named in %s\n' "${script#"$ROOT"/}" "${ci#"$ROOT"/}"
      fi
    done
  done
}

# A GATE NOBODY HAS SEEN FAIL IS NOT EVIDENCE EITHER, which is the same rule one
# level in. CLAUDE.md: "A gate is believed only once it has been seen to fail.
# Every gate carries a `--self-test`." That was prose too, and prose cannot check
# itself — five of the thirteen gates on disk had no self-test at all until
# 2026-08-19, including the two that guard the shipping documents.
#
# So the workflow is asked a second question about each gate: does it run that
# gate's `--self-test`? Same shape as `unwired`, same parameters, for the same
# reason — the self-test below drives this exact function over a fixture.
unproven() {
  local ci="$1"; shift
  local dir script name
  for dir in "$@"; do
    [ -d "$dir" ] || continue
    for script in "$dir"/*.sh; do
      [ -e "$script" ] || continue
      [ -x "$script" ] || continue
      name="$(basename "$script")"
      # THE ONE EXEMPTION, AND IT IS STRONGER RATHER THAN WEAKER.
      # `spec-check.sh` does not take a `--self-test` because it does not need
      # one: it corrupts a real emitted `.abstr` and REQUIRES the corruption to
      # be caught on EVERY run, not on a separate invocation somebody has to
      # remember to wire. It is the origin of this rule (ticket 15), and giving
      # it a second mechanism would leave the next reader unsure which of the
      # two is authoritative.
      case "$name" in
        spec-check.sh) continue ;;
      esac
      if ! grep -qF "$name --self-test" "$ci"; then
        printf '%s: %s\n' "${script#"$ROOT"/}" "its --self-test is never run"
      fi
    done
  done
}

# AND THE LIST OF GATES IS ITSELF A SURFACE, SO IT ROTS TOO.
#
# `.claude/end-session.md` calls itself "every step CI runs, in CI's order", and
# it is what a session reads to find out what to run. On 2026-08-21 it was found
# naming SIX of sixteen — nine missing, including a gate added the same day — so
# a session followed it, ran six gates, and believed it had run them all.
#
# THAT WAS FIXED, AND IT DRIFTED AGAIN ONE COMMIT LATER. F21 added
# `check-field-values.sh` on the same day the list was corrected, and the list
# was one short again before anything had read it. Twice in a day is not
# carelessness, it is a missing check: the two questions above are asked of the
# WORKFLOW, and nothing was asking the DOCUMENT anything at all.
#
# So the same enumeration is put to it. A gate on disk that this file does not
# name is a gate the next session will not run.
unlisted() {
  local doc="$1"; shift
  local dir script name
  for dir in "$@"; do
    [ -d "$dir" ] || continue
    for script in "$dir"/*.sh; do
      [ -e "$script" ] || continue
      [ -x "$script" ] || continue
      name="$(basename "$script")"
      if ! grep -qF "$name" "$doc"; then
        printf '%s: never named in %s\n' "${script#"$ROOT"/}" "${doc#"$ROOT"/}"
      fi
    done
  done
}

# ---------------------------------------------------------------------------
# --self-test
#
# Two fixtures, because "does it fire" and "does it fire only when it should"
# are different questions and only the pair is evidence. A gate that reported
# every script as unwired would satisfy the first and be useless.
#
# The same pair again for `unproven`, since it makes a different claim about the
# same files: a gate can be wired and still never have been shown to fail. And
# again for `unlisted`, which makes a third claim about them: a gate can be
# wired AND proven and still be absent from the list a human reads.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT
  mkdir -p "$CTL/bin"

  printf '#!/usr/bin/env bash\ntrue\n' > "$CTL/bin/check-wired.sh"
  printf '#!/usr/bin/env bash\ntrue\n' > "$CTL/bin/check-forgotten.sh"
  chmod +x "$CTL/bin/check-wired.sh" "$CTL/bin/check-forgotten.sh"

  # A third fixture: wired, but its self-test never run. That is the state
  # every gate in this repo was in until 2026-08-19, and it is invisible to
  # `unwired` — the workflow names it, so the first check is satisfied.
  printf '#!/usr/bin/env bash\ntrue\n' > "$CTL/bin/check-unproven.sh"
  chmod +x "$CTL/bin/check-unproven.sh"

  # A workflow that runs one of them and has never heard of the other, and runs
  # a third without ever asking it to prove it can fail.
  cat > "$CTL/ci.yml" <<'YML'
steps:
  - name: A gate that is wired
    run: ./bin/check-wired.sh
  - name: A gate that is wired and unproven
    run: ./bin/check-unproven.sh
  - name: A gate that proves it can fail
    run: ./bin/check-wired.sh --self-test
YML

  # A list that names one of the three. `check-wired.sh` is wired AND proven AND
  # listed; `check-unproven.sh` is wired and listed but never proven. So the
  # third check must report `check-forgotten.sh` and `check-unproven.sh` is
  # NOT a control for it — the control is `check-wired.sh`, which all three
  # checks must leave alone.
  cat > "$CTL/end-session.md" <<'DOC'
## Gates
./bin/check-wired.sh
./bin/check-unproven.sh
DOC

  out="$(unwired "$CTL/ci.yml" "$CTL/bin" || true)"
  unp="$(unproven "$CTL/ci.yml" "$CTL/bin" || true)"
  unl="$(unlisted "$CTL/end-session.md" "$CTL/bin" || true)"

  fail=0
  if ! grep -q 'check-forgotten.sh' <<<"$out"; then
    echo "SELF-TEST FAILED: the unwired gate was not reported — this check cannot fire"
    fail=1
  fi
  if grep -q 'check-wired.sh' <<<"$out"; then
    echo "SELF-TEST FAILED: a wired gate was reported as unwired, so the check does not"
    echo "                  discriminate and would be turned off within a week"
    fail=1
  fi
  if ! grep -q 'check-unproven.sh' <<<"$unp"; then
    echo "SELF-TEST FAILED: a gate whose --self-test is never run was not reported —"
    echo "                  which is the state every gate here was in until today"
    fail=1
  fi
  if grep -q 'check-wired.sh' <<<"$unp"; then
    echo "SELF-TEST FAILED: a gate whose --self-test IS run was reported as unproven,"
    echo "                  so the second check does not discriminate either"
    fail=1
  fi

  if ! grep -q 'check-forgotten.sh' <<<"$unl"; then
    echo "SELF-TEST FAILED: a gate the session list never names was not reported —"
    echo "                  which is how that list came to name six of sixteen"
    fail=1
  fi
  if grep -q 'check-wired.sh' <<<"$unl"; then
    echo "SELF-TEST FAILED: a listed gate was reported as unlisted, so the third check"
    echo "                  does not discriminate either"
    fail=1
  fi

  if [ "$fail" -eq 0 ]; then
    echo "self-test: found the forgotten gate, the unproven one and the unlisted one,"
    echo "           left the wired, proven and listed one alone — all three checks"
    echo "           discriminate"
    exit 0
  fi
  echo "$out"
  echo "$unp"
  echo "$unl"
  exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
CI="$ROOT/.github/workflows/ci.yml"
[ -f "$CI" ] || { echo "no workflow at ${CI#"$ROOT"/} — there is nothing running any gate"; exit 1; }

missing="$(unwired "$CI" "$ROOT/bin" "$ROOT/compiler/bin" "$ROOT/editor/bin" || true)"

if [ -n "$missing" ]; then
  echo "$missing"
  echo
  echo "A gate the workflow never names runs only when somebody remembers, which is"
  echo "how this repo lost five features of grammar drift. Add a step for each, or"
  echo "record the exclusion and its reason in the block at the foot of ci.yml."
  exit 1
fi

unshown="$(unproven "$CI" "$ROOT/bin" "$ROOT/compiler/bin" "$ROOT/editor/bin" || true)"

if [ -n "$unshown" ]; then
  echo "$unshown"
  echo
  echo "A gate nobody has seen fail is a claim, not a check. Give it a --self-test"
  echo "that builds the defect it names, requires a red, and requires a green on the"
  echo "correct form beside it — then run both from ci.yml."
  exit 1
fi

DOC="$ROOT/.claude/end-session.md"
[ -f "$DOC" ] || {
  echo "no session list at ${DOC#"$ROOT"/} — the file that tells a session what to run"
  echo "is gone, and a missing list cannot be checked against. Restore it rather than"
  echo "letting this check pass over nothing."
  exit 1
}

unnamed="$(unlisted "$DOC" "$ROOT/bin" "$ROOT/compiler/bin" "$ROOT/editor/bin" || true)"

if [ -n "$unnamed" ]; then
  echo "$unnamed"
  echo
  echo "A gate missing from the session list is a gate the next session does not run."
  echo "That list claims to be every step CI runs; it named six of sixteen once, was"
  echo "corrected, and was one short again one commit later. Add it there too — the"
  echo "script, ci.yml, and .claude/end-session.md are three edits, not two."
  exit 1
fi

echo "every gate on disk is named by the workflow and by the session list, and every"
echo "one proves it can fail"
