#!/usr/bin/env bash
#
# THE AUDITION'S CHECK: does the worker's `switchcheck` say what the compiler says?
#
# Usage:  ./check.sh <dir-containing-switchcheck>
#         ./check.sh --self-test
#
# It compares TAG SETS per case against `expected/`, which `oracle.sh` recorded
# by running the reference compiler. The worker never sees `expected/`.
#
# WHY TAGS AND NOT PASS/FAIL. A checker that printed `switch_inexhaustive` for
# every input would agree with the compiler on the rejecting cases and be
# worthless. Comparing the SET means a missing diagnostic and an invented one
# both fail, and a clean program that draws any output fails too. This is the
# same shape as `compiler/bin/check-helper-agrees.sh`, for the same reason: a
# harness that can only say "no" cannot tell knowing from guessing.
#
# WHAT A FAILURE MEANS IS DELIBERATELY AMBIGUOUS, AND THAT IS THE POINT. One
# worker missing a clause is a weak worker; SEVERAL workers missing the SAME
# clause is a hole in the specification. The audition is run across models on
# the identical packet so the two can be told apart — which makes this as much a
# test of the handoff document as of the model.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run one implementation over every case; print one line per disagreement.
compare() {
  local impl="$1"
  local dir name want got bs
  for dir in "$HERE"/cases/*/; do
    name="$(basename "$dir")"
    bs="$(find "$dir" -name '*.bs' | head -1)"
    want="$(tr '\n' ' ' < "$HERE/expected/$name.tags" 2>/dev/null | sed 's/ *$//')"
    got="$("$impl" "$bs" 2>/dev/null | tr 'A-Z' 'a-z' | grep -oE '[a-z_]+' | sort -u | tr '\n' ' ' | sed 's/ *$//')"
    if [ "$want" != "$got" ]; then
      printf '%-28s compiler says [%s] — this says [%s]\n' \
             "$name" "${want:-clean}" "${got:-clean}"
    fi
  done
}

# ---------------------------------------------------------------------------
# --self-test: the check must reject a lazy implementation and accept a correct
# one. Only the pair is evidence — a check that failed everything would satisfy
# the first half and pass nothing ever again.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT

  # POSITIVE CONTROL — says nothing, ever. Passes the three clean cases by
  # accident, which is exactly the accident this check must not reward.
  printf '#!/usr/bin/env bash\nexit 0\n' > "$CTL/silent"

  # POSITIVE CONTROL — cries wolf on everything. The mirror-image failure.
  printf '#!/usr/bin/env bash\necho switch_inexhaustive\n' > "$CTL/paranoid"

  # NEGATIVE CONTROL — delegates to the reference compiler, so it is correct by
  # construction. If the check cannot pass THIS, it cannot be passed at all.
  REPO="$(cd "$HERE/../.." && pwd)"
  BSC="$REPO/compiler/_build/default/bin/bsc"
  [ -x "$BSC" ] || BSC="$REPO/compiler/_build/test/bin/bsc"
  cat > "$CTL/oracle-impl" <<SH
#!/usr/bin/env bash
f="\$1"
mod_dir="\$(dirname "\$f")"
root="\$(dirname "\$mod_dir")"
{ "$BSC" --diagnostics term --src-root "\$root" -o "\$(mktemp -d)" "\$mod_dir" 2>/dev/null || true; } \\
  | sed -n 's/.*tag => \\([a-z_][a-z_0-9]*\\).*/\\1/p' | sort -u
SH
  chmod +x "$CTL/silent" "$CTL/paranoid" "$CTL/oracle-impl"

  fail=0
  [ -n "$(compare "$CTL/silent")"   ] || { echo "SELF-TEST FAILED: the silent stub was accepted"; fail=1; }
  [ -n "$(compare "$CTL/paranoid")" ] || { echo "SELF-TEST FAILED: the cry-wolf stub was accepted"; fail=1; }
  correct="$(compare "$CTL/oracle-impl")"
  if [ -n "$correct" ]; then
    echo "SELF-TEST FAILED: a correct implementation was rejected —"
    printf '  %s\n' "$correct"
    echo "  the check is unpassable, which is worse than no check"
    fail=1
  fi

  if [ "$fail" -eq 0 ]; then
    echo "self-test: rejected the silent stub and the cry-wolf stub, accepted the"
    echo "           compiler-backed one — the check discriminates."
    exit 0
  fi
  exit 1
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
WORKDIR="${1:-.}"
IMPL="$WORKDIR/switchcheck"

[ -x "$IMPL" ] || { echo "no executable ./switchcheck in $WORKDIR — the packet asks for one"; exit 1; }
ls "$HERE"/expected/*.tags >/dev/null 2>&1 || { echo "no expectations — run ./oracle.sh first"; exit 1; }

total=$(find "$HERE"/cases -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
bad="$(compare "$IMPL")"

if [ -n "$bad" ]; then
  printf '%s\n' "$bad"
  wrong=$(printf '%s\n' "$bad" | wc -l | tr -d ' ')
  echo
  echo "$wrong of $total cases disagree with the reference compiler."
  exit 1
fi

echo "all $total cases agree with the reference compiler"
