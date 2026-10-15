#!/usr/bin/env bash
# CLAIMS: Erlang has no who-may-call construct. (1) `-export` is the only gate (callee-side, all-or-nothing);
#   erlc does NOT warn when another module calls an exported "internal" function, and does NOT check cross-module
#   calls to non-exported functions at compile time (runtime undef). (2) `-doc false` / `-moduledoc false` (OTP 27+)
#   are documentation metadata only. (3) The nearest thing to "friend" is a post-hoc xref query
#   (`{module_use, M}`), which a build must run and compare against its own allow-list.
# NOTE: the only erlc output expected is "local_only/1 is unused" -- about the callee never using its own private fn, not about the cross-module call from audit:b.
# REFUTED IF: erlc warns/errors on case A or B; or xref's module_use does not list the outsider.
# CONTROLS: erlc DOES diagnose a local call to a non-existent function and an unused unexported function (so warnings are on).
. "$(dirname "$0")/env.sh"; S=$(mktemp -d /tmp/probe60erl.XXXXXX); cd $S; mkdir ebin
cat > shop_orders_internal.erl <<'T'
-module(shop_orders_internal).
-moduledoc false.
-export([recompute_total/1]).
-export_type([pub_t/0]).
-type pub_t() :: integer().
-type hidden_t() :: integer().
-doc false.
recompute_total(L) -> lists:sum(L).
-spec local_only(hidden_t()) -> hidden_t().
local_only(X) -> X.
T
cat > shop_orders.erl <<'T'
-module(shop_orders).
-export([total/1]).
total(L) -> shop_orders_internal:recompute_total(L).
T
cat > audit.erl <<'T'
-module(audit).
-export([a/1, b/1, c/0]).
-spec c() -> shop_orders_internal:hidden_t().
a(L) -> shop_orders_internal:recompute_total(L).      %% A: exported, "internal" by convention
b(X) -> shop_orders_internal:local_only(X).            %% B: NOT exported
c() -> 1.
T
cat > ctl.erl <<'T'
-module(ctl).
-export([f/0]).
f() -> g(1).
h() -> 1.
T
echo "=== A,B,type-use: erlc +warn_all (expect: no output, exit 0)"
erlc +warn_all +debug_info -o ebin shop_orders_internal.erl shop_orders.erl audit.erl; echo "exit $?"
echo "=== CONTROL: erlc on a module with an undefined local call and an unused function (expect diagnostics)"
erlc +warn_all -o ebin ctl.erl 2>&1 | head -5
echo "=== runtime: A works (exported), B is undef"
erl -noshell -pa ebin -eval 'io:format("A=~p~nB=~p~n",[audit:a([1,2,3]), (catch audit:b(1))]), halt().'
echo "=== xref: who uses shop_orders_internal? (the only 'friend'-shaped check Erlang offers)"
erl -noshell -pa ebin -eval '
{ok,_}=xref:start(s), xref:set_default(s,[{verbose,false},{warnings,false}]),
[{ok,_}=xref:add_module(s,"ebin/"++M++".beam") || M <- ["shop_orders_internal","shop_orders","audit"]],
{ok,Users}=xref:analyze(s,{module_use,shop_orders_internal}), io:format("module_use: ~p~n",[Users]),
{ok,Undef}=xref:analyze(s,undefined_function_calls), io:format("undefined_function_calls: ~p~n",[Undef]),
Allowed=[shop_orders], io:format("violations vs allow-list ~p: ~p~n",[Allowed, Users--Allowed]), halt().'
echo "=== source citations (OTP 28 stdlib)"
L=$(erl -noshell -eval 'io:format("~s",[code:lib_dir(stdlib)]),halt().')/src
grep -n '^-moduledoc false' $L/dets_utils.erl; grep -n -B1 -A1 '^-doc hidden' $L/escript.erl | head -4
grep -n 'moduledoc' $L/erl_lint.erl | sed -n 1,6p
