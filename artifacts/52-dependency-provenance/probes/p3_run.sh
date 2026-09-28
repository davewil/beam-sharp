#!/bin/sh
cd "$(dirname "$0")"; ./p3_fixtures.sh >/dev/null; cd work/p3
echo "######## ERL_LIBS=libA:libB:libC:libD:libE (order A,B)"
ERL_LIBS=libA:libB:libC:libD:libE escript ../../p3_lookup.escript
echo; echo "######## ERL_LIBS=libB:libA:libC:libD:libE (order B,A) — only Q2/Q4 for shared matter"
ERL_LIBS=libB:libA:libC:libD:libE escript ../../p3_lookup.escript | sed -n '1p;/which(shared)/p;/^  shared:/p'
echo; echo "######## ERL_LIBS unset (control: what a machine with a different environment sees)"
env -u ERL_LIBS escript ../../p3_lookup.escript | sed -n '1,/-- Q3/p'
