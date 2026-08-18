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

# ---------------------------------------------------------------------------
# --self-test
#
# Two fixtures, because "does it fire" and "does it fire only when it should"
# are different questions and only the pair is evidence. A gate that reported
# every script as unwired would satisfy the first and be useless.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT
  mkdir -p "$CTL/bin"

  printf '#!/usr/bin/env bash\ntrue\n' > "$CTL/bin/check-wired.sh"
  printf '#!/usr/bin/env bash\ntrue\n' > "$CTL/bin/check-forgotten.sh"
  chmod +x "$CTL/bin/check-wired.sh" "$CTL/bin/check-forgotten.sh"

  # A workflow that runs one of them and has never heard of the other.
  cat > "$CTL/ci.yml" <<'YML'
steps:
  - name: A gate that is wired
    run: ./bin/check-wired.sh
YML

  out="$(unwired "$CTL/ci.yml" "$CTL/bin" || true)"

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

  if [ "$fail" -eq 0 ]; then
    echo "self-test: found the forgotten gate, left the wired one alone — the gate discriminates"
    exit 0
  fi
  echo "$out"
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

echo "every gate on disk is named by the workflow"
