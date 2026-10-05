#!/usr/bin/env bash
# P01: re-run the ticket's own prototype 62a UNMODIFIED against the built bsc, then check each ticket-table row.
# Each row is REFUTED if the line it names is absent or different. The prototype itself is not edited.
. "$(dirname "$0")/lib.sh"
OUTF="$SCRATCH/p01_62a.out"
bash "$REPO/wayfinder/prototypes/62a_from_the_outside.sh" > "$OUTF" 2>&1
cat "$OUTF"
echo
echo "################ row-by-row check against ticket 62's text"
chk() { if grep -qE "$2" "$OUTF"; then echo "REPRODUCED      $1"; else echo "NOT REPRODUCED  $1"; fi; }
chk ":Shop.New(1) -> SYNTAX_ERROR"                     ':Shop.New\(1\) +:SYNTAX_ERROR'
chk ':"BSharp.Shop".New(1) -> SYNTAX_ERROR'            'BSharp.Shop".New\(1\) +:SYNTAX_ERROR'
chk ':"Shop.Reports".Totals(1) -> SYNTAX_ERROR'        'Shop.Reports".Totals\(1\) +:SYNTAX_ERROR'
chk ':"Elixir.Shop".New(1) -> SYNTAX_ERROR'            'Elixir.Shop".New\(1\) +:SYNTAX_ERROR'
chk ':"BSharp.Shop".new(1) -> parses'                  'BSharp.Shop".new\(1\) +:parses'
chk 'apply(:Shop, :New, [1]) -> parses (and runs)'     'apply\(:Shop, :New, \[1\]\) +:parses'
chk "Erlang 'Shop':'New'(1) works"                     "'Shop':'New'\(1\) +-> #\{'Kind' => 'Shop.Order'"
chk "record arrives as plain map, is_struct? false"    'is_struct\? +false'
chk "wrong tag -> FunctionClauseError"                 'wrong tag +\{:raised, FunctionClauseError\}'
chk "Elixir struct same fields -> FunctionClauseError" 'same fields +\{:raised, FunctionClauseError\}'
chk "Gleam part of 62a builds (ticket: 'compiles')"    'Compiled in|Compiling caller'
echo "(the Gleam row cannot reproduce here: 62a runs \`gleam new\` which adds gleam_stdlib; hex.pm is blocked. p05 re-does it with no deps.)"
