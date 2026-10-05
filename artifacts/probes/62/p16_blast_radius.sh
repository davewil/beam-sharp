#!/usr/bin/env bash
# P16: size of "change B#'s own convention to snake_case functions" (ticket 62 candidate 3), measured on the real corpus + compiler.
# Counts only; no claim is made that the number is the whole cost (the grammar argument is ticket 35 / 26, quoted in the brief).
. "$(dirname "$0")/lib.sh"
find "$REPO" -name '*.bs' -not -path '*/artifacts/*' -not -path '*/_build/*' > "$SCRATCH/bsfiles2.txt"
echo ".bs files:                    $(wc -l < "$SCRATCH/bsfiles2.txt")"
echo "signature lines (pub|priv):   $(grep -hE '^(public|private) ' $(cat "$SCRATCH/bsfiles2.txt") | wc -l)"
echo "clause-head lines  Name(..)->: $(grep -hE '^[A-Z][A-Za-z0-9_]*\(.*\) *(when .*)?->' $(cat "$SCRATCH/bsfiles2.txt") | wc -l)"
echo "qualified calls   Mod.Fn(:    $(grep -ohE '\b[A-Z][A-Za-z0-9_]*\.[A-Z][A-Za-z0-9_]*\(' $(cat "$SCRATCH/bsfiles2.txt") | wc -l)"
echo "lexer rules that key on case: $(grep -nE '^\{(UPPER|LOWER)\}\{ALNUM\}\*' "$REPO/compiler/src/bs_lexer.xrl" | tr '\n' ' ')"
echo "grammar productions using uident for a function: $(grep -cE "uident" "$REPO/compiler/src/bs_parser.yrl") lines mention uident in bs_parser.yrl"
echo "bs_otp.erl callback table rows (B# name -> OTP snake name): $(grep -cE "^\s*\[?\{'[A-Z]" "$REPO/compiler/src/bs_otp.erl")"
