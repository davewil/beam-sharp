#!/usr/bin/env bash
# CLAIMS: the ticket writes `[external: elixir, app: req] using :'Elixir.Req' { ... }`. Ticket 32 decided
# `[external: erlang, "ets"] module Ets {...}`. What does the REPO's bsc (unmodified) accept today?
# REFUTED IF: AttrToday compiles (then an attribute syntax already exists and the ticket's form is real).
. "$(dirname "$0")/lib.sh"
O=$WORK/o15; mkdir -p "$O"
echo "### the ticket's own spelling, repo bsc:"; env -u ERL_LIBS bsc -o "$O" "$BS/AttrToday"; echo "[exit=$?]"
echo "### the double-quoted atom LANGUAGE.md section 11 writes (using :\"Elixir.Enum\"), repo bsc:"; env -u ERL_LIBS bsc -o "$O" "$BS/DQ"; echo "[exit=$?]"
echo "### the single-quoted form every prototype uses, repo bsc:"; env -u ERL_LIBS bsc -o "$O" "$BS/Pure"; echo "[exit=$?]"
echo "### grep: is there any attribute syntax in the grammar? ('[' as the first token of a declaration)"
echo "productions starting with '[' as a declaration: $(grep -c "^decl -> '\['" /home/user/beam-sharp/compiler/src/bs_parser.yrl)"
echo "### a NATIVE using of a module that does not exist (ticket 41: the compiler owns the B# dependency graph), repo bsc:"
env -u ERL_LIBS bsc -o "$O" "$BS/NativeMissing"; echo "[exit=$?]"
# REFUTED (for 'native using is already checked for presence') IF this exits 0.
