#!/usr/bin/env bash
# 29a — CDuce's integer interval algebra, measured rather than cited.
#
# Ticket 20 §5 admitted integer intervals to beam-sharp's type algebra on the argument that
# "finite unions of integer intervals are closed under union, intersection and complement with
# a decision procedure, CDuce ships exactly this, and it is nowhere near SMT". CDuce is named
# 88 times across this map and had never been run. This runs it.
#
# Method: CDuce has no "print this type" directive, but a type error prints the checker's own
# normalised form of the offending type. `let f (x : T) : Empty = x;;` therefore makes the
# checker show its working for any T. Where T really *is* empty the file typechecks and prints
# nothing, which is itself the answer.
#
# Usage:  ./29a_cduce_intervals.sh
# Needs:  docker (amd64 emulation), network on first run.

set -u
cd "$(dirname "$0")"

IMG=cduce:0.6.0
docker build --platform linux/amd64 -q -t "$IMG" -f 29a_Dockerfile . >/dev/null || exit 1

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# probe <label> <cduce source>
# Each probe gets its own filename: rewriting one path in a bind mount between container
# runs was served stale often enough to produce phantom parse errors.
N=0
probe() {
  N=$((N + 1))
  printf '\n--- %s\n' "$1"
  printf '    %s\n' "$2"
  printf '%s\n' "$2" > "$WORK/p$N.cd"
  out=$(docker run --rm --platform linux/amd64 -v "$WORK:/w" "$IMG" cduce "/w/p$N.cd" 2>&1)
  if [ -z "$out" ]; then
    printf '    => (accepted, no output)\n'
  else
    printf '%s\n' "$out" | sed 's/^/    | /'
  fi
}

echo "=== CDuce version ==="
docker run --rm --platform linux/amd64 "$IMG" cduce --version

echo
echo "=== 1. The algebra: what does the checker normalise these to? ==="

probe "union, adjacent — does it merge?" \
      'let f (x : (1--10 | 11--20)) : Empty = x;;'

probe "union, non-adjacent — does it stay a union?" \
      'let f (x : (1--10 | 20--30)) : Empty = x;;'

probe "intersection" \
      'let f (x : (1--10 & 5--20)) : Empty = x;;'

probe "intersection, disjoint — accepted means it decided Empty" \
      'let f (x : (1--10 & 20--30)) : Empty = x;;'

probe "complement of a bounded interval in Int" \
      'let f (x : (Int \ 1--10)) : Empty = x;;'

probe "difference punching a hole" \
      'let f (x : (1--30 \ 10--20)) : Empty = x;;'

probe "double complement — closed under the operation" \
      'let f (x : (Int \ (Int \ 1--10))) : Empty = x;;'

probe "an arbitrary bound: is 5--20 quantised onto a ladder?" \
      'let f (x : 5--20) : Empty = x;;'

# The space before ")" is required: CDuce comments are (* … *), so "*)" would lex as a
# comment terminator.
probe "half-open ends" \
      'let f (x : (500--2000 | 3000--* )) : Empty = x;;'

echo
echo "=== 2. Intervals in the exhaustiveness algorithm ==="

# Branches must be newline-separated; several arms on one line do not parse.
probe "inexhaustive interval clauses — what is the residual?" \
      'let f (Int -> Int)
 | 0--9 -> 1
 | 10--19 -> 2
 | 20--* -> 3
;;'

probe "exhaustive partition of a declared interval, no catch-all" \
      'let g (0--19 -> Int)
 | 0--9 -> 1
 | 10--19 -> 2
;;
print "accepted\n";;'

probe "guard-shaped partition of all of Int, no catch-all" \
      'let h (Int -> Int)
 | 1--1 -> 1
 | 2--* -> 2
 | *--0 -> 0
;;
print "accepted\n";;'

echo
echo "=== 3. Is there a solver in there? ==="
docker run --rm --platform linux/amd64 "$IMG" bash -c \
  'ldd $(which cduce) | sed "s/^/    /"; echo "    --- package dependencies:"; apt-cache depends cduce 2>/dev/null | sed "s/^/    /"'
