#!/usr/bin/env bash
# PROBE 65e — what does Erlang/OTP 28.5 do when a user redefines a built-in TYPE, or names a
# MODULE like a stdlib one? Ticket 65's table says "OTP 26 permitted a user type to shadow a
# built-in type name". This runs it, and runs the module-name case the table does not mention.
# CONTROLS: a type with a fresh name (no diagnostic) and a module with a fresh name (loads).
#
#   source env.sh; bash artifacts/probes/65/65e_erlang_shadowing.sh
set -uo pipefail
: "${S:?source env.sh first}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cd "$W"
echo "erl: OTP $(erl -noshell -eval 'io:format("~s (erts ~s)",[erlang:system_info(otp_release),erlang:system_info(version)]),halt().')"
echo "erl_lint.erl: $(grep -n 'Starting from OTP 26, redefining built-in types' "$S"/otp-src/otp_src_28.5/lib/stdlib/src/erl_lint.erl | cut -d: -f1) is the OTP-26 comment; warning text at the line below"
grep -n 'local redefinition of built-in type' "$S"/otp-src/otp_src_28.5/lib/stdlib/src/erl_lint.erl | sed 's/^/   erl_lint.erl:/'

echo "== 1. -type map() :: integer().  (a user type named like a built-in)"
cat > t1.erl <<'X'
-module(t1).
-export([f/1]).
-type map() :: integer().
-spec f(map()) -> map().
f(X) -> X + 1.
X
erlc t1.erl 2>&1 | sed 's/^/   /'; echo "   erlc exit=$? ; runs: $(erl -noshell -pa . -eval 'io:format("~p",[t1:f(1)]),halt().')"
echo "== 1-control. -type amount() :: integer().  (fresh name)"
sed 's/map()/amount()/g; s/t1/t1c/' t1.erl > t1c.erl; erlc t1c.erl 2>&1 | sed 's/^/   /'; echo "   erlc exit=$? (no output above = no diagnostic)"
echo "== 1b. same, with -compile(nowarn_redefined_builtin_type) — the opt-out exists"
(echo '-compile({nowarn_redefined_builtin_type, [{map,0}]}).'; sed 's/t1/t1b/' t1.erl) > t1b.erl; sed -i '1{h;d};2{G}' t1b.erl; erlc t1b.erl 2>&1 | sed 's/^/   /'; echo "   erlc exit=$?"

echo "== 2. a user module named lists, ahead of stdlib on the code path (-pa)"
mkdir -p u; cat > u/lists.erl <<'X'
-module(lists).
-export([sum/1]).
sum(_) -> user_lists.
X
(cd u && erlc lists.erl 2>&1 | sed 's/^/   erlc: /'; echo "   erlc exit=$?")
erl -noshell -pa u -eval 'io:format("   lists:sum([1,2]) = ~p~n   where is lists loaded from: ~p~n", [catch lists:sum([1,2]), code:which(lists)]), halt().' 2>&1 | head -8
echo "== 2b. code:load_file(lists) after boot (the sticky-directory guard)"
erl -noshell -eval 'io:format("   ~p~n",[code:load_file(lists)]),halt().' 2>&1
echo "== 2-control. a user module named shop_lists loads and runs"
mkdir -p u2; printf -- '-module(shop_lists).\n-export([sum/1]).\nsum(_) -> user_lists.\n' > u2/shop_lists.erl; (cd u2 && erlc shop_lists.erl)
erl -noshell -pa u2 -eval 'io:format("   shop_lists:sum([1]) = ~p ; lists:sum([1,2]) = ~p~n",[shop_lists:sum([1]), lists:sum([1,2])]), halt().' 2>&1
