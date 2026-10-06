#!/usr/bin/env bash
# PROBE 62-06 — Claim (ticket 62 cand. 2): "a rule for deriving the name". What must the rule do, and where does it break?
# B# identifiers are [A-Z][a-zA-Z0-9_]* (bs_lexer.xrl:14-16), so `_`, digits, acronyms and overloaded arities all occur.
# Compiles src/Names/names.bs with the REAL bsc (GetX vs Get_x, HTTPGet vs HttpGet, Md5Sum, New2, New/1+New/2,
# ModuleInfo, Length, End, Self), derives aliases under two rules, compiles the aliased module with OTP, and enumerates
# every identifier over a small alphabet to count collisions. CONTROL: the baseline module must compile; a rule that
# never collided would print 0 groups — the exhaustive section shows both rules' numbers side by side.
set -uo pipefail
source /tmp/claude-0/-home-user-beam-sharp/5c54aeca-205c-5959-b98d-85886863a86f/scratchpad/env.sh
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT; mkdir -p "$W/ebin" "$W/o"
H=artifacts/probes/62
$BSC --src-root $H/src -o "$W/o" $H/src/Names 2>&1 | head -5
erlc -o "$W/ebin" $H/alias_xform.erl $H/alias_derive.erl
mkdir -p "$W/all"
for d in $(find compiler/examples -name '*.bs' -not -path '*/exemplars/*' -printf '%h\n' | sort -u); do
  $BSC --src-root compiler/examples -o "$W/all" "$d" >/dev/null 2>&1
done
cd "$W" && erl -noshell -pa ebin -eval 'alias_derive:main(["o"]), alias_derive:corpus("all"), halt()'
