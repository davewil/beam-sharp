#!/usr/bin/env bash
#
# Run the clean-room audition across every candidate CLI and mark the results.
#
#   ./run.sh [workdir]        default workdir: /tmp/bsharp-audition
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
WORKDIR="${1:-/tmp/bsharp-audition}"
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

# The answers must not be reachable from any sandbox.
if [ -n "$(find "$WORKDIR" -maxdepth 2 -name expected -type d 2>/dev/null)" ]; then
  echo "LEAK — the expectations are reachable from a worker directory"; exit 1
fi
echo "staged ${#LANES[@]} lanes in $WORKDIR; expectations not reachable; deadline ${DEADLINE}s"
echo

# ---------------------------------------------------------------------------
# Run every lane in parallel
# ---------------------------------------------------------------------------
run_lane() {
  local key="$1"
  local d="$WORKDIR/$key"
  local t0 t1 rc
  # shellcheck disable=SC2046
  # deliberate word split: lane_cmd returns a command and its flags
  t0=$(date +%s)
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
printf '%-9s %7s %7s  %s\n' "LANE" "SECS" "RESULT" "DETAIL"
for key in "${LANES[@]}"; do
  d="$WORKDIR/$key"
  secs="$(cat "$WORKDIR/$key.seconds" 2>/dev/null || echo '?')"
  if [ ! -e "$d/switchcheck" ]; then
    printf '%-9s %7s %7s  %s\n' "$key" "$secs" "none" "no deliverable (rc $(cat "$WORKDIR/$key.rc" 2>/dev/null || echo '?'))"
    continue
  fi
  chmod +x "$d/switchcheck" 2>/dev/null
  out="$("$HERE/check.sh" "$d" 2>&1)"; rc=$?
  total=$(find "$HERE/cases" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
  if [ "$rc" -eq 0 ]; then
    printf '%-9s %7s %7s  %s\n' "$key" "$secs" "$total/$total" "every case agrees"
  else
    wrong=$(printf '%s' "$out" | grep -c 'compiler says')
    printf '%-9s %7s %7s  %s\n' "$key" "$secs" "$((total - wrong))/$total" "$(printf '%s' "$out" | grep 'compiler says' | head -1 | sed 's/  */ /g')"
    printf '%s\n' "$out" | grep 'compiler says' | tail -n +2 | sed 's/^/                             /'
  fi
done
