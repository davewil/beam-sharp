#!/usr/bin/env bash
# P3: is a compile-time "is the foreign module reachable" check feasible in bsc?
# Builds a scratch copy of the compiler with ONE line added to bs_check:check_dir1
# (a call to bs_probe52:check/1, which is code:which/1 over the {foreign,..} decls),
# then compiles the same .bs with and without the module on ERL_LIBS.
set -u; . "$(dirname "$0")/common.sh"
G=$WORK/gen; mkdir -p $G $WORK/ebin
cp $S/gen/*.erl $G/; cp "$HERE/bs_probe52.erl" $G/
# the one-line hook, inserted after `Module = module_name(Decls),` in check_dir1
sed -i '0,/    Module = module_name(Decls),/s//    Module = module_name(Decls), bs_probe52:check(Decls),/' $G/bs_check.erl
grep -c "bs_probe52:check" $G/bs_check.erl
erlc +debug_info -o $WORK/ebin $G/*.erl 2>&1 | grep -i " error" ; cp $S/ebin/bsc.app $WORK/ebin/ 2>/dev/null
mkfake $WORK/lib
mkdir -p $WORK/Dep; cat > $WORK/Dep/dep.bs <<'EOF'
module Dep

using :fakereq {
    term new(list<(atom, term)> opts)
}
using :lists {
    int sum(list<int> xs)
}

public term Make(int n)

Make(n) -> :fakereq.new([(:n, n)])
EOF
run() { (cd $WORK && erl -noshell -pa $WORK/ebin -eval 'bsc:main(init:get_plain_arguments()), halt().' -extra Dep "$@" 2>&1); }
echo "--- module absent";  env -u ERL_LIBS bash -c "$(declare -f run); WORK=$WORK; run"
echo "--- module present"; ERL_LIBS=$WORK/lib bash -c "$(declare -f run); WORK=$WORK; run"
echo "--- micro: code:which/1 cost, 2000 calls each (OTP25, this box)"
ERL_LIBS=$WORK/lib erl -noshell -eval '
  Time = fun(M) -> {T,_} = timer:tc(fun() -> [code:which(M) || _ <- lists:seq(1,2000)] end), T/2000 end,
  io:format("present (fakereq): ~.2f us/call~nstdlib  (lists):   ~.2f us/call~nabsent  (nope):    ~.2f us/call~n",
            [Time(fakereq), Time(lists), Time(nope)]), halt().'
