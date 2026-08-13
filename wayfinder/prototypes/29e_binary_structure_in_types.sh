#!/usr/bin/env bash
# 29e — two local checks on ticket 29 §4, "structural binary typing outside Erlang".
#
# Part A: a *third* place erl_types trades exactness for termination, which ticket 20 did
#         not record. Ticket 20 §2 found the same-constructor union collapse and §1 found
#         the integer quantisation ladder. There is a third: t_bitstr/2 silently widens any
#         base at or above U*9 down to (B rem U) + U*8. `<<_:80,_:_*8>>` becomes
#         `<<_:64,_:_*8>>` — a type admitting values nobody declared. It is deliberate: the
#         lattice is kept finite-height so analysis terminates.
#
# Part B: Gleam's BitArray, the obvious near-miss for Erlang's `<<_:M, _:_*N>>`, carries no
#         size in its type. Measured rather than read off the compiler source.
#
# Usage:  ./29e_binary_structure_in_types.sh
# Needs:  erl (OTP 28.5 here) and gleam (1.18.1 here) on PATH.

set -u

echo "=== A. erl_types widens a bitstring base at U*9 (OTP $(erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]),halt(0).')) ==="

DIA=$(erl -noshell -eval 'io:format("~s",[code:lib_dir(dialyzer)]),halt(0).')
echo
echo "--- the rule, from ${DIA}/src/erl_types.erl:"
sed -n '/^t_bitstr(U, B) ->/,/^  ?bitstr(U, NewB)\./p' "$DIA/src/erl_types.erl" | sed 's/^/    /'
grep -n 'define(UNIT_MULTIPLIER' "$DIA/src/erl_types.erl" | sed 's/^/    /'

echo
echo "--- what it does to a declared base:"
erl -pa "$DIA/ebin" -noshell -eval '
  F = fun(U, B) ->
        T = erl_types:t_bitstr(U, B),
        S = erl_types:t_to_string(T),
        Flag = case erl_types:t_bitstr_base(T) of
                 B -> "exact";
                 _ -> "WIDENED"
               end,
        io:format("    t_bitstr(~3w, ~3w) -> ~-22ts ~s~n", [U, B, S, Flag])
      end,
  [F(8, B) || B <- [32, 64, 71, 72, 80, 200]],
  F(1, 100),
  halt(0).'

echo
echo "=== B. Gleam BitArray: is a size expressible in the type? (gleam $(gleam --version 2>/dev/null | awk '{print $2}')) ==="

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
( cd "$WORK" && gleam new bsprobe --name bsprobe >/dev/null 2>&1 )

cat > "$WORK/bsprobe/src/bsprobe.gleam" <<'GLEAM'
// A size specifier is legal in a *pattern* — Gleam took Erlang's matching construct.
pub fn first_32(b: BitArray) -> Int {
  case b {
    <<a:size(32)>> -> a
    _ -> 0
  }
}

// But is BitArray parameterised by that size? If it were, this would be legal.
pub fn sized(b: BitArray(32)) -> Int {
  first_32(b)
}
GLEAM

echo
echo "--- with the size annotation on the type:"
( cd "$WORK/bsprobe" && gleam build 2>&1 | grep -v '^ *\(Resolving\|Downloading\|Downloaded\|Added\|Compiling\)' | head -12 | sed 's/^/    /' )

# Same file with the illegal annotation removed, plus a caller passing the wrong size.
cat > "$WORK/bsprobe/src/bsprobe.gleam" <<'GLEAM'
pub fn first_32(b: BitArray) -> Int {
  case b {
    <<a:size(32)>> -> a
    _ -> 0
  }
}

// Every BitArray is the same type, so a 1-byte value is accepted here at compile time
// and the size mismatch is discovered — if at all — by the runtime match.
pub fn main() {
  echo first_32(<<1, 2, 3, 4>>)
  echo first_32(<<9>>)
}
GLEAM

echo
echo "--- passing a 1-byte BitArray where 4 bytes are matched:"
( cd "$WORK/bsprobe" && gleam run 2>&1 | grep -v '^ *\(Resolving\|Downloading\|Downloaded\|Added\|Compiling\)' | tail -6 | sed 's/^/    /' )
