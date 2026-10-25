#!/usr/bin/env bash
# P4b: how often does the Module.Types crash appear? 6 runs each of scripts A and D from p4 (run p4 first to create them).
export PATH=/tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/beam/bin:$PATH LANG=C.UTF-8 ELIXIR_ERL_OPTIONS="+fnu"
cd /tmp/claude-0/-home-user-beam-sharp/4d32ff9e-1235-5fa8-9491-be9b1e51ca5e/scratchpad/65/p4
for f in a_ticket_repro.exs d_which.exs; do for i in 1 2 3 4 5 6; do
  elixir $f >o.txt 2>&1; echo "$f run$i exit=$? update!-crash=$(grep -c 'Map.update!/3 is undefined' o.txt)"; done; done
mkdir -p eb; elixirc -o eb b_compiled.ex >o.txt 2>&1; echo "elixirc b_compiled.ex update!-crash=$(grep -c 'update!' o.txt)"
