#!/usr/bin/env bash
# 24a — Is CDuce's inexhaustive-match sample a property-test generator, or one witness?
#
# Ticket 24 §3 asks whether the sampled counter-value ticket 04 attributes to CDuce is good
# enough to generate property-test inputs from type declarations: uniform enough, hits edge
# cases, terminates on recursive types. The ticket suggests splitting it into a research
# ticket. It does not need one — ticket 29 left a cduce:0.6.0 image on this machine, so the
# question is measurable.
#
# Method: an inexhaustive `match` makes CDuce report what it could not match. Whatever it
# prints there IS the sampling machinery's output, and its shape answers all three
# sub-questions at once.
#
# Usage:  ./24a_cduce_sampling.sh
# Needs:  docker (amd64 emulation). Image built by 29a_Dockerfile.

set -u
cd "$(dirname "$0")"

IMG=cduce:0.6.0
docker build --platform linux/amd64 -q -t "$IMG" -f 29a_Dockerfile . >/dev/null || exit 1

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# No `timeout(1)` on stock macOS and no coreutils `gtimeout` here, so the watchdog is a named
# container killed from a background subshell. Needed because probe 3 exists precisely to find
# out whether sampling a recursive type terminates — an unguarded hang would be the one result
# this script cannot report.
N=0
probe() {
  N=$((N + 1))
  printf '\n--- %s\n' "$1"
  printf '%s\n' "$2" | sed 's/^/    /'
  printf '%s\n' "$2" > "$WORK/p$N.cd"
  cname="cduce24a_$$_$N"
  ( sleep 120; docker kill "$cname" >/dev/null 2>&1 ) &
  watchdog=$!
  out=$(docker run --rm --name "$cname" --platform linux/amd64 -v "$WORK:/w" "$IMG" cduce "/w/p$N.cd" 2>&1)
  rc=$?
  kill "$watchdog" >/dev/null 2>&1
  wait "$watchdog" 2>/dev/null
  if [ $rc -eq 137 ]; then
    printf '    => KILLED after 120s (did not terminate)\n'
  elif [ -z "$out" ]; then
    printf '    => (accepted, no output)\n'
  else
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi
}

echo "=== CDuce version ==="
docker run --rm --platform linux/amd64 "$IMG" cduce --version

echo
echo "=== 1. Does an inexhaustive match print a sample at all? ==="

probe "atom union, one member unhandled" \
'type Colour = `red | `green | `blue
let f (x : Colour) : Int = match x with `red -> 1 | `green -> 2;;'

probe "atom union, THREE members unhandled — one witness or all three?" \
'type Colour = `red | `green | `blue | `cyan | `magenta
let f (x : Colour) : Int = match x with `red -> 1 | `green -> 2;;'

echo
echo "=== 2. Which value does it pick from an interval? (edge case or arbitrary?) ==="

probe "interval 1--100, handled 1--50 — does it pick 51 (the edge) or something else?" \
'let f (x : 1--100) : Int = match x with 1--50 -> 1;;'

probe "interval with a hole in the middle — 1--100 minus 40--60" \
'let f (x : 1--100) : Int = match x with 1--39 -> 1 | 61--100 -> 2;;'

probe 'unbounded below — Int minus 0--10000, does it print a negative witness?' \
'let f (x : Int) : Int = match x with 0--10000 -> 1;;'

echo
echo "=== 3. Recursive types: does it terminate, and what depth does it sample to? ==="

probe "sequence of Int, only the empty case handled" \
'let f (x : [ Int* ]) : Int = match x with [] -> 0;;'

probe "recursive tree type, only the leaf handled" \
'type Tree = (`leaf, Int) | (`node, Tree, Tree)
let f (x : Tree) : Int = match x with (`leaf, Int) -> 0;;'

probe "mutually recursive, only one arm handled" \
'type A = (`a, B) | `nil
type B = (`b, A) | `nil
let f (x : A) : Int = match x with `nil -> 0;;'

echo
echo "=== 4. Product decomposition: does it enumerate the missing combinations? ==="

probe "pair of two 3-member atom unions, one combination handled" \
'type S = `open | `closed | `void
type E = `add | `remove | `ship
let f (x : (S, E)) : Int = match x with (`open, `add) -> 1;;'

echo
echo "=== 5. Is there any directive that ASKS for a sample, rather than erroring? ==="

probe "--help: look for a sampling / generation flag" \
'let f (x : Int) : Int = x;;'
docker run --rm --platform linux/amd64 "$IMG" cduce --help 2>&1 | sed 's/^/    | /'
