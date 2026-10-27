#!/usr/bin/env bash
# Hypothesis H1: Erlang's -export gives no caller-side control (any module can call an exported fn);
# H2: xref can enforce "only 'shop.orders.*' may call shop_orders_internal" as a post-hoc query, and
# the allowed caller yields no violation while the forbidden one does (falsifiable: counts must be 1 and 0).
set -e
D=$(mktemp -d); cd "$D"; erl -noshell -eval 'io:format("OTP ~s~n",[erlang:system_info(otp_release)]),halt().'
cat > shop_orders_internal.erl <<'X'
-module(shop_orders_internal).
-export([recompute/1]).
recompute(X) -> X + 1.
X
cat > shop_orders_api.erl <<'X'
-module(shop_orders_api).
-export([total/1]).
total(X) -> shop_orders_internal:recompute(X).
X
cat > other_thing.erl <<'X'
-module(other_thing).
-export([peek/1]).
-ignore_xref([{peek,1}]).
peek(X) -> shop_orders_internal:recompute(X).
X
erlc +debug_info *.erl   # run 1 used plain erlc: xref saw no edges (no abstract code); see p1_run1_no_debug_info.out
erl -noshell -eval '
{ok,_}=xref:start(s), xref:set_default(s,[{warnings,false}]),
{ok,_}=xref:add_directory(s,"."),
{ok,Edges}=xref:q(s,"E"),
Internal=[{C,Ca} || {{C,_,_},{Ca,_,_}} <- Edges, Ca==shop_orders_internal],
io:format("edges into internal: ~p~n",[Internal]),
Allowed=fun(M)-> lists:prefix("shop_orders_",atom_to_list(M)) end,
Viol=[C || {C,_} <- Internal, not Allowed(C)],
io:format("violations: ~p~n",[Viol]),
io:format("H1 check (other_thing compiled and linked despite no permission): ~p~n",[lists:member(other_thing,Viol)]),
%% H3: -ignore_xref is an attribute xref reads for its OWN warnings (unused), not for call permission
{ok,Un}=xref:analyze(s,undefined_function_calls),
io:format("undefined_function_calls: ~p~n",[Un]),
halt(case Viol of [other_thing] -> 0; _ -> 1 end).'
echo "exit=$? (0 = both hypotheses held)"
