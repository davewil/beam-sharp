#!/usr/bin/env bash
# P17: existing in-repo precedent: a module declaring `behaviour GenServer` ALREADY exports snake_case names (ticket 35 / bs_otp table), Pascal absent.
# CLAIM (LANGUAGE.md §12 "Function names are exported PascalCase, exactly as written") holds for non-callback functions only.
# REFUTED IF Counter's export list still contains 'Init' / 'HandleCall' (i.e. callbacks are Pascal too).
. "$(dirname "$0")/lib.sh"
W="$SCRATCH/p17"; mkdir -p "$W"; "$BSC" --src-root "$REPO/compiler/examples" -o "$W" "$REPO/compiler/examples/Counter" >/dev/null 2>&1
erl -noshell -pa "$W" -eval 'io:format("Counter exports: ~p~n", [lists:sort([E || E={N,_} <- (list_to_atom("Counter")):module_info(exports), N =/= module_info])]), halt().'
grep -n "^public\|^behaviour" "$REPO/compiler/examples/Counter/"*.bs
