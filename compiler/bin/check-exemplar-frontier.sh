#!/usr/bin/env bash
#
# NOTHING CATCHES THE EXEMPLARS GOING STALE AGAINST THE LANGUAGE.
#
# `examples/exemplars/README.md` has said exactly that since it was written:
#
#   "`bin/extract-exemplars.sh --check` catches the extracted files going stale
#    against the prototypes; nothing catches the prototypes going stale against
#    the *language*. That gap is exactly what let 63 clause heads rot in place."
#
# This is the missing half. `--check` proves the extracted files match the
# write-ups; it says nothing about whether the write-ups still describe a
# language the compiler has. Both can agree perfectly and both be obsolete.
#
# THE ROT HAS A DIRECTION, AND IT IS THE UNWATCHED ONE.
# A regression gate would not have caught any of this. Every failure here was
# the compiler getting BETTER while the record stood still:
#
#   * 63 nameless clause heads sat in a dialect the language had dropped, for
#     as long as it took somebody to count them.
#   * F13 shipped binary patterns on 2026-08-20. 25c stopped failing on `<` at
#     `consume.bs:14` and started failing on a destructure-and-bind pattern at
#     `consume.bs:20`. The README kept saying line 14. Twelve gates were green.
#   * The README's capability table still marked four rows `out` that F2, F13,
#     F15 and F18 had built — measured 2026-08-21, which is how this gate began.
#
# So the assertion is EQUALITY with a measured manifest, not "no worse than".
# An exemplar reaching further than `FRONTIER` records is a red, and the fix is
# to re-measure and say which capability moved it. Good news you have to notice
# is news you will eventually stop noticing.
#
# WHAT IT DOES NOT CLAIM
# `bsc` stops at the first error, so this measures the FRONT wall and nothing
# behind it. A record moving forward means one wall fell. It does not mean the
# exemplar compiles, and this gate would be lying if it were read that way.
#
# Usage:  compiler/bin/check-exemplar-frontier.sh [--update|--self-test]
#         --update     re-measure and rewrite FRONTIER's records in place
#         --self-test  build the defects this gate names and require a red

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Both inputs are parameters so --self-test drives the identical function over a
# fixture rather than over a second copy of this logic — the mistake ticket 15
# lost a session to, where the harness supplied the protection it was measuring.
EXEMPLARS="${EXEMPLAR_FRONTIER_DIR:-$HERE/examples/exemplars}"
MANIFEST="${EXEMPLAR_FRONTIER_MANIFEST:-$EXEMPLARS/FRONTIER}"
BSC="${EXEMPLAR_FRONTIER_BSC:-$HERE/_build/default/bin/bsc}"

# ---------------------------------------------------------------------------
# Measurement.
#
# Iteration is over DIRECTORIES ON DISK, never over the manifest's records. A
# loop over the manifest cannot see an exemplar nobody recorded, which is the
# same blind spot `check-gates-wired.sh` exists for one level up: an unmentioned
# thing is not outside the rule, it is the rule's blind spot.
# ---------------------------------------------------------------------------
measure() {
  local dir="$1" bsc="$2"
  local d name out file rest
  for d in "$dir"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "${d%/}")"

    # Captured, not piped. A wall makes `bsc` exit non-zero and `pipefail` would
    # hand that status to the caller, aborting the loop at the first exemplar —
    # a gate that stops at its first finding hides every one behind it.
    out="$("$bsc" --src-root "$dir" "${d%/}" 2>&1 | head -1 || true)"

    if [ -z "$out" ]; then
      printf '%s\t-\tclean\n' "$name"
      continue
    fi

    # Three diagnostic shapes reach here and all three must normalise:
    #   path/to/file.bs:13: error: msg    the common one
    #   path/to/file.bs: error: msg       whole-file errors carry no line
    #   error: msg                        module-level errors name no file
    out="${out#"$dir"/}"                       # drop the root we passed in
    out="$(printf '%s' "$out" | sed -e 's|^[^ :]*/||' -e 's|^\([^:]*\.bs\):[0-9][0-9]*:|\1:|')"

    case "$out" in
      *.bs:*) file="${out%%:*}"; rest="${out#*: }" ;;
      *)      file="-";          rest="$out"       ;;
    esac
    printf '%s\t%s\t%s\n' "$name" "$file" "$rest"
  done
}

records() { grep -v '^[[:space:]]*#' "$1" | grep -v '^[[:space:]]*$' || true; }

# ---------------------------------------------------------------------------
# Comparison. Returns the human-readable report; empty means agreement.
#
# Four distinguishable disagreements, reported as four different sentences,
# because "the file changed" is not advice and this gate's whole purpose is to
# tell somebody what moved.
# ---------------------------------------------------------------------------
compare() {
  local observed="$1" manifest="$2"
  local name obs_line man_line obs_wall man_wall

  while IFS= read -r obs_line; do
    [ -n "$obs_line" ] || continue
    name="${obs_line%%	*}"
    man_line="$(awk -F'\t' -v n="$name" '$1 == n' <<<"$manifest" | head -1)"

    if [ -z "$man_line" ]; then
      printf '%s: on disk and in no record\n' "$name"
      printf '    measured: %s\n' "${obs_line#*	}"
      printf '    An exemplar nobody recorded is an exemplar nobody is watching.\n'
      printf '    Add it with --update.\n\n'
      continue
    fi

    obs_wall="${obs_line#*	}"
    man_wall="${man_line#*	}"
    if [ "$obs_wall" != "$man_wall" ]; then
      printf '%s: the wall moved\n' "$name"
      printf '    recorded: %s\n' "$man_wall"
      printf '    measured: %s\n' "$obs_wall"
      if [ "$man_wall" != "-	clean" ] && [ "$obs_wall" = "-	clean" ]; then
        printf '    It compiles now. Something built it and the record never said so.\n\n'
      else
        printf '    Either a capability landed and moved it forward, or something\n'
        printf '    regressed. Find out which before running --update.\n\n'
      fi
    fi
  done <<<"$observed"

  while IFS= read -r man_line; do
    [ -n "$man_line" ] || continue
    name="${man_line%%	*}"
    if ! awk -F'\t' -v n="$name" '$1 == n' <<<"$observed" | grep -q .; then
      printf '%s: recorded, and not on disk\n' "$name"
      printf '    recorded: %s\n' "${man_line#*	}"
      printf '    The record outlived the exemplar. Remove it with --update.\n\n'
    fi
  done <<<"$manifest"
}

usable_bsc() {
  [ -x "$BSC" ] || {
    echo "no escript at ${BSC#"$HERE"/} — run \`rebar3 escriptize\` in compiler/ first," >&2
    echo "which is what ci.yml does before this step." >&2
    return 1
  }
}

# ---------------------------------------------------------------------------
# --self-test
#
# FOUR defects and one control, because this gate makes four separable claims
# and a check that fires on all of them indiscriminately is worthless. The
# fixtures are copies of the REAL exemplars driven by the REAL compiler: a
# synthetic `.bs` tree would exercise none of the normalisation, which is where
# this script does its work and where it would break first.
#
# Defect 1 is the important one and it is the one a regression gate misses.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  usable_bsc || { echo "SELF-TEST CANNOT RUN"; exit 1; }

  CTL="$(mktemp -d)"
  trap 'rm -rf "$CTL"' EXIT

  fresh() {
    rm -rf "$1"; mkdir -p "$1"
    cp -R "$EXEMPLARS"/25*-* "$1/"
    cp "$MANIFEST" "$1/FRONTIER"
  }
  run_gate() {
    EXEMPLAR_FRONTIER_DIR="$1" EXEMPLAR_FRONTIER_MANIFEST="$1/FRONTIER" \
      "${BASH_SOURCE[0]}" 2>&1 || true
  }

  st_fail=0
  expect_red() {
    local label="$1" needle="$2" out="$3"
    if ! grep -qF "$needle" <<<"$out"; then
      echo "SELF-TEST FAILED: $label"
      echo "  expected the report to name: $needle"
      echo "  got:"
      sed 's/^/    /' <<<"$out"
      st_fail=1
    fi
  }

  # DEFECT 1 — THE EXEMPLAR ADVANCED AND THE RECORD DID NOT.
  # This is F13's rot reproduced exactly: remove the construct 25a stops on and
  # it reaches further, while FRONTIER still names the old wall. A gate that
  # only asked "no worse than recorded" would be GREEN here, which is precisely
  # how the README came to mark four built capabilities `out`.
  fresh "$CTL/advanced"
  sed -i.bak 's/#{ error = "invalid", at = e }/:invalid/' "$CTL/advanced/25a-http-api-server/create_order.bs"
  sed -i.bak 's/#{ error = "no route" }/:no_route/'       "$CTL/advanced/25a-http-api-server/route.bs"
  rm -f "$CTL/advanced"/25a-http-api-server/*.bak
  expect_red "an exemplar that got FURTHER than its record was not reported" \
    "25a-http-api-server: the wall moved" "$(run_gate "$CTL/advanced")"

  # DEFECT 2 — THE EXEMPLAR REGRESSED.
  # beam-sharp has no `;`, and the lexer has a dedicated error saying so, which
  # makes it a clean way to move a wall backwards without inventing a construct.
  fresh "$CTL/regressed"
  printf '\n;\n' >> "$CTL/regressed/25b-websocket-handler/index.bs"
  expect_red "an exemplar that regressed was not reported" \
    "25b-websocket-handler: the wall moved" "$(run_gate "$CTL/regressed")"

  # DEFECT 3 — AN EXEMPLAR ON DISK THAT NO RECORD MENTIONS.
  # The over-informed control's mirror image, and the one a manifest-driven loop
  # cannot see: iterate the records and this directory is simply never visited,
  # so the gate reports success having measured nothing about it.
  fresh "$CTL/unrecorded"
  cp -R "$CTL/unrecorded/25a-http-api-server" "$CTL/unrecorded/25z-unrecorded"
  expect_red "an exemplar with no record was not reported" \
    "25z-unrecorded: on disk and in no record" "$(run_gate "$CTL/unrecorded")"

  # DEFECT 4 — A RECORD NAMING AN EXEMPLAR THAT IS GONE.
  # The over-informed manifest: it claims more than reality contains. A gate
  # marked only against what it was shown would pass this, since every exemplar
  # it CAN see agrees with its record.
  fresh "$CTL/vanished"
  rm -rf "$CTL/vanished/25c-event-queue-consumer"
  expect_red "a record for a vanished exemplar was not reported" \
    "25c-event-queue-consumer: recorded, and not on disk" "$(run_gate "$CTL/vanished")"

  # THE CONTROL. Without this half, a gate that reported every exemplar as
  # drifted would pass all four defects above and be worse than nothing.
  fresh "$CTL/correct"
  ctl_out="$(run_gate "$CTL/correct")"
  if ! grep -q 'every exemplar stops where' <<<"$ctl_out"; then
    echo "SELF-TEST FAILED: the untouched exemplars were reported as drifted, so this"
    echo "                  gate does not discriminate and would be muted within a week"
    sed 's/^/    /' <<<"$ctl_out"
    st_fail=1
  fi

  if [ "$st_fail" -eq 0 ]; then
    echo "self-test: caught the exemplar that advanced, the one that regressed, the one"
    echo "           no record mentions and the record whose exemplar is gone — and left"
    echo "           the untouched tree alone. All four claims discriminate."
    exit 0
  fi
  exit 1
fi

# ---------------------------------------------------------------------------
# --update
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--update" ]; then
  usable_bsc || exit 1
  observed="$(measure "$EXEMPLARS" "$BSC")"
  tmp="$(mktemp)"
  grep '^[[:space:]]*#' "$MANIFEST" > "$tmp" || true
  printf '\n%s\n' "$observed" >> "$tmp"
  mv "$tmp" "$MANIFEST"
  echo "re-measured ${MANIFEST#"$HERE"/}:"
  sed 's/^/  /' <<<"$observed"
  echo
  echo "Read the diff before committing it. Say which capability moved a wall —"
  echo "a record that moves with no explanation is the rot this gate exists to stop."
  exit 0
fi

# ---------------------------------------------------------------------------
# The real run.
# ---------------------------------------------------------------------------
[ -f "$MANIFEST" ] || { echo "no manifest at ${MANIFEST#"$HERE"/}"; exit 1; }
usable_bsc || exit 1

observed="$(measure "$EXEMPLARS" "$BSC")"
manifest="$(records "$MANIFEST")"

# A gate that loops over nothing and exits 0 is the failure mode this repo has
# already met. If neither side has a record, that is a defect in the gate.
if [ -z "$observed" ] && [ -z "$manifest" ]; then
  echo "no exemplars on disk and no records — this gate measured nothing and would"
  echo "have reported success. Check EXEMPLAR_FRONTIER_DIR."
  exit 1
fi

report="$(compare "$observed" "$manifest")"

if [ -n "$report" ]; then
  # `$(...)` strips trailing newlines, so the blank line every finding ends with
  # is gone by the time it gets here and the closing advice would run onto the
  # last sentence. Put one back rather than trusting the capture.
  printf '%s\n\n' "$report"
  echo "The exemplars are ticket 25's standing resource and the compiler moves under"
  echo "them. Re-measure with --update, and say in the commit which capability moved"
  echo "the wall — or which one stopped working."
  exit 1
fi

count="$(wc -l <<<"$manifest" | tr -d ' ')"
echo "every exemplar stops where FRONTIER says it does ($count measured)"
