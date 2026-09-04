#!/usr/bin/env bash
#
# Run the clean-room audition across every candidate CLI and mark the results.
#
#   ./run.sh [workdir]        default: a fresh mktemp dir, printed on start
#   ./run.sh --self-test      prove the timeout and the marking both work
#
# TWO INVARIANTS ARE LOAD-BEARING HERE, AND BOTH WERE LEARNED BY LOSING THEM.
#
#   STDIN IS CLOSED. The first run of this audition left stdin attached to the
#   parent shell. All three non-codex CLIs sat alive at ~0% CPU with their logs
#   frozen, waiting on an interactive prompt that was never coming. Nothing
#   timed out and nothing failed; the run simply never finished.
#
#   EVERY LANE HAS A DEADLINE. The second run fixed stdin and hit the other
#   half: the CLIs produced their deliverable and then never exited. `wait`
#   blocked forever, and three polling loops span on a condition that could no
#   longer become true. Work finished, harness hung.
#
# Both are invariants the Ringer harness bakes in. Reimplementing a harness
# badly, twice, in one evening is what this file exists to stop happening a
# third time.
#
# macOS has no `timeout(1)`, so the deadline is a watchdog subshell that kills
# the process group. `gtimeout` is not assumed to be installed.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# A FRESH WORKDIR PER RUN, not a fixed one. This defaulted to
# `/tmp/bsharp-audition`, so two audition runs on one machine - or a re-run after
# a killed one - shared a directory and each read the other's leftovers. That is
# ENG-318's hazard one level up. Pass a path as $1 when you want a run you can
# find again.
#
# NOT `mktemp -d -t bsharp-audition`. `-t` takes a PREFIX on BSD/macOS and a
# TEMPLATE on GNU coreutils and busybox, so that spelling works here and fails on
# Linux - `too few X's in template` under GNU, `Invalid argument` under busybox,
# both measured. This harness ships in the handoff and the recipient is likelier
# to be on Linux than on a Mac, so the explicit template is the only portable
# form. That the first fix for a scratch-sharing hazard introduced a
# platform-specific one is this repository's own recurring class, not an aside.
WORKDIR="${1:-$(mktemp -d "${TMPDIR:-/tmp}/bsharp-audition.XXXXXXXX")}"
DEADLINE="${AUDITION_TIMEOUT_S:-900}"

# --- the candidates ---------------------------------------------------------
#
# One lane per CLI, each on its own billing plan. Add a lane by adding a line:
# the key names the sandbox and the log, the rest is the command.
lane_cmd() {
  case "$1" in
    codex)   echo "codex exec --skip-git-repo-check" ;;
    copilot) echo "copilot --allow-all-tools --allow-all-paths -p" ;;
    agy)     echo "agy --dangerously-skip-permissions -p" ;;
    grok)    echo "grok --always-approve -p" ;;
  esac
}
LANES=(codex copilot agy grok)

PROMPT="$(cat <<'EOP'
You are implementing one piece of a programming language toolchain from its specification alone, as a clean-room exercise. Your working directory contains PACKET.md and a cases/ directory.

Read PACKET.md in full before starting. It carries the specification you must implement against, the hard rules, and the output contract you are marked on.

BOUNDARY: you own only your own working directory. Do NOT read, search for, or open any file outside it. Do not modify anything under cases/.

DELIVERABLE: an executable file named switchcheck in your working directory, runnable as ./switchcheck <path-to-.bs-file>, with a shebang so it runs directly.

Work autonomously and do not ask questions - there is nobody to answer them. Test your implementation against the files in cases/ before you finish.
EOP
)"

# Run one command with a deadline, stdin closed, output captured.
# Returns the command's status, or 124 if the watchdog fired.
with_deadline() {
  local secs="$1" log="$2"; shift 2
  "$@" > "$log" 2>&1 < /dev/null &
  local pid=$!
  ( sleep "$secs"; kill -TERM "$pid" 2>/dev/null; sleep 3; kill -KILL "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  local watchdog=$!
  wait "$pid"; local rc=$?
  kill "$watchdog" 2>/dev/null
  wait "$watchdog" 2>/dev/null
  return "$rc"
}

# ---------------------------------------------------------------------------
# --self-test: the harness's own two failure modes, reconstructed.
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  CTL="$(mktemp -d)"; trap 'rm -rf "$CTL"' EXIT
  fail=0

  # A process that would hang forever must be killed by the deadline.
  start=$(date +%s)
  with_deadline 3 "$CTL/hang.log" sleep 600
  waited=$(( $(date +%s) - start ))
  if [ "$waited" -gt 15 ]; then
    echo "SELF-TEST FAILED: the deadline did not fire — a hung lane would block the run"
    fail=1
  fi

  # A process that reads stdin must not block: stdin is closed, so it sees EOF.
  start=$(date +%s)
  with_deadline 20 "$CTL/stdin.log" cat
  waited=$(( $(date +%s) - start ))
  if [ "$waited" -gt 15 ]; then
    echo "SELF-TEST FAILED: a stdin reader blocked — stdin is not closed"
    fail=1
  fi

  [ "$fail" -eq 0 ] && { echo "self-test: the deadline fires and stdin is closed"; exit 0; }
  exit 1
fi

# ---------------------------------------------------------------------------
# Prepare
# ---------------------------------------------------------------------------
command -v python3 >/dev/null || { echo "python3 is needed to build the packet"; exit 1; }
python3 "$HERE/build-packet.py" >/dev/null || { echo "could not build PACKET.md"; exit 1; }
"$HERE/oracle.sh" >/dev/null || { echo "could not record expectations — is the escript built?"; exit 1; }

mkdir -p "$WORKDIR"
for key in "${LANES[@]}"; do
  d="$WORKDIR/$key"
  rm -rf "$d"; mkdir -p "$d"
  cp "$HERE/PACKET.md" "$d/PACKET.md"
  cp -R "$HERE/cases" "$d/cases"
done

# The answers must not be reachable from any sandbox — and there are two sets of
# them: `expected/` (the tags) and `heldout/` (the cases nobody is shown). The
# loop above copies only PACKET.md and cases/, so this is the assertion that the
# loop above still does what it says.
if [ -n "$(find "$WORKDIR" -maxdepth 2 -type d \( -name expected -o -name heldout \) 2>/dev/null)" ]; then
  echo "LEAK — answers or held-out cases are reachable from a worker directory"; exit 1
fi
echo "staged ${#LANES[@]} lanes in $WORKDIR; answers and held-out cases not reachable; deadline ${DEADLINE}s"
echo

# ---------------------------------------------------------------------------
# Run every lane in parallel
# ---------------------------------------------------------------------------
run_lane() {
  local key="$1"
  local d="$WORKDIR/$key"
  local t0 t1 rc
  t0=$(date +%s)
  # deliberate word split: lane_cmd returns a command and its flags.
  # The directive must sit on the line immediately above the one it covers —
  # written two lines up, it silently annotated `t0=$(date +%s)` instead and
  # suppressed nothing, which is how this stayed unlinted while looking handled.
  # shellcheck disable=SC2046
  ( cd "$d" && with_deadline "$DEADLINE" "$WORKDIR/$key.log" $(lane_cmd "$key") "$PROMPT" )
  rc=$?
  t1=$(date +%s)
  printf '%s\n' "$((t1 - t0))" > "$WORKDIR/$key.seconds"
  printf '%s\n' "$rc" > "$WORKDIR/$key.rc"
}

for key in "${LANES[@]}"; do run_lane "$key" & done
wait
echo "all lanes returned"
echo

# ---------------------------------------------------------------------------
# Mark
# ---------------------------------------------------------------------------
# A LANE THAT COULD NOT RUN IS NOT A MODEL THAT COULD NOT DO IT.
#
# Measured 2026-08-19: a lane exited after 12 seconds with `402 Payment
# Required — usage balance exhausted`. The same model had produced a 7/8 result
# an hour earlier; the intervening runs simply spent the plan's allowance.
#
# Scored as a failure that would be a lie, and a lie in the direction that
# matters — it would enter the record as evidence about the MODEL when it is
# evidence about the ACCOUNT. Plan-billed lanes are finite, and running several
# workflows at once is exactly how you discover the limit.
unavailable_reason() {
  local log="$1"
  grep -qiE '402|payment required|balance exhausted|quota|rate.?limit' "$log" 2>/dev/null && { echo "lane out of balance or rate-limited"; return 0; }
  grep -qiE 'unauthori|not logged in|authentication|invalid.*(token|credential)' "$log" 2>/dev/null && { echo "lane not authenticated"; return 0; }
  return 1
}

# TWO SCORES, AND THE SECOND IS THE ONE THAT MEANS ANYTHING.
#
# VISIBLE is the cases the lane was given; HELD-OUT is cases it never saw.
# Measured 2026-08-20: a stub that parses nothing and switches on the case
# directory name scores a perfect visible set, because this harness passes the
# case's identity in argv[1]. A real submission recovered from an earlier run
# scored 8/8 visible and 2/7 held-out — the same held-out score as that stub.
#
# Read the columns together. High visible with low held-out is a lane that
# fitted the examples, and reporting a single number would have called it a pass.
printf '%-9s %7s %8s %8s  %s\n' "LANE" "SECS" "VISIBLE" "HELD-OUT" "DETAIL"
for key in "${LANES[@]}"; do
  d="$WORKDIR/$key"
  secs="$(cat "$WORKDIR/$key.seconds" 2>/dev/null || echo '?')"
  rc="$(cat "$WORKDIR/$key.rc" 2>/dev/null || echo '?')"
  if [ ! -e "$d/switchcheck" ]; then
    if reason="$(unavailable_reason "$WORKDIR/$key.log")"; then
      printf '%-9s %7s %8s %8s  %s\n' "$key" "$secs" "n/a" "n/a" "$reason — not a capability result"
    elif [ "$rc" = "124" ] || [ "$rc" = "143" ] || [ "$rc" = "137" ]; then
      printf '%-9s %7s %8s %8s  %s\n' "$key" "$secs" "none" "none" "killed at the ${DEADLINE}s deadline with no deliverable"
    else
      printf '%-9s %7s %8s %8s  %s\n' "$key" "$secs" "none" "none" "no deliverable (rc $rc)"
    fi
    continue
  fi
  chmod +x "$d/switchcheck" 2>/dev/null
  out="$("$HERE/check.sh" "$d" 2>&1)"; rc=$?

  # Read the two scores off check.sh's own summary lines rather than recounting
  # here. The previous spelling counted 'compiler says' lines and divided by the
  # visible total, which cannot express two sets and would have reported a
  # held-out failure as a visible one.
  visible="$(printf '%s\n' "$out"  | sed -n 's/^visible  *//p'  | head -1)"
  heldout="$(printf '%s\n' "$out"  | sed -n 's/^held-out  *//p' | head -1)"
  detail="$(printf '%s\n' "$out" | grep 'compiler says' | head -1 | sed 's/  */ /g')"
  [ "$rc" -eq 0 ] && detail="every case agrees, held-out included"

  printf '%-9s %7s %8s %8s  %s\n' "$key" "$secs" "${visible:-?}" "${heldout:-?}" "$detail"
  printf '%s\n' "$out" | grep 'compiler says' | tail -n +2 | sed 's/^/                                       /'
done
