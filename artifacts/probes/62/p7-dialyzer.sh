#!/usr/bin/env bash
# Probe 7: does Dialyzer treat the alias like the original?  Erlang caller passes an atom where `New(int id)` wants int.
# Variants: caller uses 'New' (control: must warn), alias WITH copied -spec, alias WITHOUT spec, and a correct call (control: must be silent).
# Needs a PLT; builds a minimal one (erts kernel stdlib) once into the scratchpad.
. "$(dirname "$0")/common.sh"
PLT=$SCR/min.plt
[ -f $PLT ] || dialyzer --build_plt --output_plt $PLT --apps erts kernel stdlib >/dev/null 2>&1
BSC_EBIN=/tmp/bsb_62_x/ebin
mkdir -p $SCR/p7; rm -rf $SCR/p7/*
for v in spec nospec; do
  mkdir -p $SCR/p7/$v
  if [ $v = spec ]; then export BS_ALIAS=wrap BS_ALIAS_SPEC=1; else export BS_ALIAS=wrap BS_ALIAS_SPEC=0; fi
  build_shop $SCR/p7/$v >/dev/null
  # bsc's beam has no debug_info; recompile the .abstr with debug_info, as README documents (+from_abstr)
  for a in $SCR/p7/$v/*.abstr; do erlc +from_abstr +debug_info -o $SCR/p7/$v $a 2>&1 | head -3; done
  cat > $SCR/p7/$v/caller.erl <<'ERL'
-module(caller).
-export([bad_pascal/0, bad_alias/0, good_alias/0]).
bad_pascal() -> 'Shop':'New'(not_an_int).
bad_alias()  -> 'Shop':new(not_an_int).
good_alias() -> 'Shop':new(3).
ERL
  (cd $SCR/p7/$v && erlc +debug_info caller.erl)
  echo "=== alias $v: dialyzer on Shop.beam + caller.beam ==="
  dialyzer --plt $PLT $SCR/p7/$v/Shop.beam $SCR/p7/$v/caller.beam 2>&1 | grep -v '^  Checking\|^  Proceeding\|^ *$' | head -30
done
echo "=== CONTROL: unpatched build (no alias): the same alias call must be reported as an unknown function ==="
unset BS_ALIAS BS_ALIAS_SPEC; mkdir -p $SCR/p7/none; BSC_EBIN=/tmp/bsbuild/ebin build_shop $SCR/p7/none >/dev/null
for a in $SCR/p7/none/*.abstr; do erlc +from_abstr +debug_info -o $SCR/p7/none $a 2>&1 | head -3; done
cp $SCR/p7/spec/caller.erl $SCR/p7/none/; (cd $SCR/p7/none && erlc +debug_info caller.erl)
dialyzer --plt $PLT $SCR/p7/none/Shop.beam $SCR/p7/none/caller.beam 2>&1 | grep -v '^  Checking\|^  Proceeding\|^ *$' | head -12
