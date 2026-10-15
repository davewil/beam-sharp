#!/usr/bin/env bash
# CLAIM: the prototype's per-`using` check (bs_check:nameable/2 in 60_internal.patch) costs microseconds at most
#   -- negligible next to a ~400 ms whole-compile. Measured on the PATCHED bs_check compiled with export_all, 1e6 calls x5.
# REFUTED IF: (median nameable - median control) exceeds 10000 ns (10 us), i.e. 121 imports would cost >1 ms. (The loop runs under erl_eval, so absolute ns are inflated; only the difference means anything.)
# CONTROL: a no-op fun called the same way, to show the loop overhead.
. "$(dirname "$0")/env.sh"; D="$(cd "$(dirname "$0")" && pwd)"
T=$(mktemp -d /tmp/probe60micro.XXXXXX); cp -r "$REPO/compiler" $T/compiler; rm -rf $T/compiler/_build
( cd $T && patch -s -p1 < "$D/60_internal.patch" ) || exit 1
mkdir $T/ebin; erlc +export_all +nowarn_export_all -I $T/compiler/include -o $T/ebin $T/compiler/src/bs_check.erl 2>&1 | grep -v Warning | head -3
erl -noshell -pa $T/ebin -eval '
N=1000000,
Cases=[{'"'"'Audit'"'"','"'"'Shop.Orders.Internal'"'"'},{'"'"'Shop.Orders'"'"','"'"'Shop.Orders.Internal'"'"'},{'"'"'Shop.Billing'"'"','"'"'Shop.Internal'"'"'},{'"'"'Shop.Billing'"'"','"'"'Shop.Orders'"'"'}],
io:format("results: ~p~n",[[bs_check:nameable(S,M)||{S,M}<-Cases]]),
Run=fun(F)-> {T0,_}=timer:tc(fun()->[F(lists:nth(1+I rem 4,Cases))||I<-lists:seq(1,N)],ok end), T0*1000/N end,
Chk=[Run(fun({S,M})->bs_check:nameable(S,M) end)||_<-lists:seq(1,5)],
Ctl=[Run(fun({_,_})->ok end)||_<-lists:seq(1,5)],
io:format("nameable/2 ns/call (n=5 x 1e6): min=~w median=~w~n",[round(lists:min(Chk)),round(lists:nth(3,lists:sort(Chk)))]),
io:format("CONTROL no-op ns/call:        min=~w median=~w~n",[round(lists:min(Ctl)),round(lists:nth(3,lists:sort(Ctl)))]), halt().'
