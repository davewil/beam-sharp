#!/usr/bin/env bash
# p02: the ticket's claim, executed.  "Compile it on a machine with a different ERL_LIBS and it
# fails at the call site with error:undef".  Two separate steps: compile only (no function), then run.
cd "$(dirname "$0")"
B=./bsc.sh; mkdir -p /tmp/p02out
echo '--- A. compile only, ERL_LIBS unset'
env -u ERL_LIBS $B -o /tmp/p02out --src-root programs programs/Up; echo "exit=$?"
echo '--- B. compile + run Shout, ERL_LIBS unset'
env -u ERL_LIBS $B --src-root programs programs/Up Shout '"req"'; echo "exit=$?"
echo '--- C. compile + run Shout, ERL_LIBS=/usr/lib/elixir/lib'
ERL_LIBS=/usr/lib/elixir/lib $B --src-root programs programs/Up Shout '"req"'; echo "exit=$?"
echo '--- D. module atom is a typo (:lits), compile only, ERL_LIBS unset'
env -u ERL_LIBS $B -o /tmp/p02out --src-root programs programs/Typo; echo "exit=$?"
echo '--- E. typo, run'
env -u ERL_LIBS $B --src-root programs programs/Typo Total "[1,2]"; echo "exit=$?"
