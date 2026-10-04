#!/bin/sh
# Ticket 51/52 claim: ERL_LIBS alone reaches an Elixir-built dependency; a different
# ERL_LIBS gives error:undef at the call site. Fixture: Greeter (mix-built, local).
. "$(dirname "$0")/env.sh"
rm -rf $W/greet && mkdir -p $W/greet/Greet $W/greet/out && cp $FIX/bs_greet/greet.bs $W/greet/Greet/
cd $W/greet
echo "== A: ERL_LIBS unset"
env -u ERL_LIBS $BSC -o out Greet Hi '"bob"' 2>&1; echo "exit=$?"
echo "== B: ERL_LIBS = greeter's mix _build/dev/lib"
ERL_LIBS=$W/greeter_build/dev/lib $BSC -o out Greet Hi '"bob"' 2>&1; echo "exit=$?"
echo "== C: ERL_LIBS = an unrelated directory (the 'different machine' case)"
mkdir -p $W/other_libs; ERL_LIBS=$W/other_libs $BSC -o out Greet Hi '"bob"' 2>&1; echo "exit=$?"
echo "== D: compile only (is anything said at COMPILE time without the dep?)"
env -u ERL_LIBS $BSC -o out Greet; echo "exit=$? (compile alone, no run)"
