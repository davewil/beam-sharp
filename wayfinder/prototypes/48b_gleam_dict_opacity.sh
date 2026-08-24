#!/usr/bin/env bash
# PROTOTYPE 48b — is Gleam's `Dict` really unmatchable, and what does its
# exhaustiveness checker say about it?
#
# Throwaway. Ticket 48, the Gleam arm of the borrow survey.
#
# Gleam is the only surveyed source that ALSO promises exhaustiveness, so it
# is the only one that had to answer 48's hard question — a map's key domain
# is unbounded, so a pattern over it never closes a residual. Ticket 48 calls
# Gleam "candidate 1 with the reasoning already done".
#
# Reasoning is not evidence, so this runs it:
#
#   1. Does Gleam actually ENFORCE exhaustiveness? (control — if it does not,
#      the whole arm is worthless and every later result is unreadable)
#   2. Is there any pattern syntax for a Dict at all?
#   3. Is the Dict type opaque — can a constructor be named?
#   4. What does a `case` over a Dict have to look like instead?
#   5. How is a key read, and what does absence cost?
#
#   ./48b_gleam_dict_opacity.sh
#
# Requires: gleam (measured on 1.18.1). Runs in a temp dir; downloads
# gleam_stdlib from Hex on first run.
set -uo pipefail

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK" || exit 1

echo "creating a scratch gleam project..."
gleam new probe48 >/dev/null 2>&1 || { echo "gleam new failed"; exit 1; }
cd probe48 || exit 1
gleam add gleam_stdlib >/dev/null 2>&1

# Replace src/probe48.gleam with one body and build. The compiler's own text
# is the evidence, so it is printed verbatim.
gleam_probe () {
    local name="$1" body="$2"
    printf '%s\n' "$body" > src/probe48.gleam
    echo "--- $name ---"
    if gleam build 2>&1 | sed 's/^/    /'; then
        echo "    BUILDS"
    else
        echo "    REFUSED (text above)"
    fi
    echo
}

echo "==============================================================="
echo "1. CONTROL — does Gleam enforce exhaustiveness at all?"
echo "==============================================================="
echo "    If this probe does NOT go red, nothing below means anything:"
echo "    an unmatchable Dict would prove nothing in a language that never"
echo "    checked coverage in the first place."

gleam_probe "a case over a custom type, one constructor MISSING" '
import gleam/io

pub type Colour {
  Red
  Green
  Blue
}

pub fn describe(c: Colour) -> String {
  case c {
    Red -> "red"
    Green -> "green"
  }
}

pub fn main() {
  io.println(describe(Red))
}
'

gleam_probe "the same case with every constructor present" '
import gleam/io

pub type Colour {
  Red
  Green
  Blue
}

pub fn describe(c: Colour) -> String {
  case c {
    Red -> "red"
    Green -> "green"
    Blue -> "blue"
  }
}

pub fn main() {
  io.println(describe(Blue))
}
'

echo "==============================================================="
echo "2. Is there ANY pattern syntax for a Dict?"
echo "==============================================================="

gleam_probe "a dict literal in pattern position" '
import gleam/dict

pub fn main() {
  let d = dict.from_list([#("a", 1)])
  case d {
    dict.from_list([#("a", v)]) -> v
    _ -> 0
  }
}
'

gleam_probe "an Erlang-style map pattern" '
import gleam/dict

pub fn main() {
  let d = dict.from_list([#("a", 1)])
  case d {
    #{"a": v} -> v
    _ -> 0
  }
}
'

echo "==============================================================="
echo "3. Is the Dict type OPAQUE — can its constructor be named?"
echo "==============================================================="

gleam_probe "naming a Dict constructor in a pattern" '
import gleam/dict.{type Dict}

pub fn size_of(d: Dict(String, Int)) -> Int {
  case d {
    Dict(inner) -> inner
  }
}

pub fn main() {
  size_of(dict.from_list([#("a", 1)]))
}
'

echo "==============================================================="
echo "4. What a case over a Dict must look like instead"
echo "==============================================================="

gleam_probe "binding the whole Dict, then querying it" '
import gleam/dict
import gleam/io
import gleam/int

pub fn main() {
  let d = dict.from_list([#("a", 1), #("b", 2)])
  // The only pattern available over a Dict is a variable. It is total by
  // construction, so exhaustiveness never has anything to say.
  let n = case d {
    everything -> dict.size(everything)
  }
  io.println("size = " <> int.to_string(n))
}
'

echo "==============================================================="
echo "5. How a key is read, and what absence costs"
echo "==============================================================="

gleam_probe "dict.get returns a Result, so absence is a value" '
import gleam/dict
import gleam/io

pub fn main() {
  let d = dict.from_list([#("a", 1)])
  case dict.get(d, "a") {
    Ok(v) -> io.println("a -> Ok " <> string_of(v))
    Error(_) -> io.println("a -> Error")
  }
  case dict.get(d, "zzz") {
    Ok(v) -> io.println("zzz -> Ok " <> string_of(v))
    Error(_) -> io.println("zzz -> Error(Nil) — absence is a VALUE, not a clause")
  }
}

fn string_of(i: Int) -> String {
  case i {
    1 -> "1"
    _ -> "?"
  }
}
'

echo "    running the last one:"
gleam run 2>&1 | sed 's/^/      /'

echo
echo "done."
