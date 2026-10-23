#!/usr/bin/env bash
# PROBE 65e — what does Erlang/OTP 28.5 do when a user redefines a built-in TYPE, or names a
# MODULE like a stdlib one? Ticket 65's table says "OTP 26 permitted a user type to shadow a
# built-in type name". This runs it, and runs the module-name case the table does not mention.
# CONTROLS: a type with a fresh name (no diagnostic) and a module with a fresh name (loads).
# Every case asserts its expectation; the script exits non-zero if any fails.
#
#   source env.sh; bash artifacts/probes/65/65e_erlang_shadowing.sh
set -uo pipefail
: "${S:?source env.sh first}"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cd "$W"
PASS=0; FAIL=0
expect() { # label condition-result(0=true)
  if [ "$2" = 0 ]; then PASS=$((PASS+1)); echo "   [ok] $1"; else FAIL=$((FAIL+1)); echo "   [FAILED] $1"; fi
}
LINT="$S/otp-src/otp_src_28.5/lib/stdlib/src/erl_lint.erl"
echo "erl: OTP $(erl -noshell -eval 'io:format("~s (erts ~s)",[erlang:system_info(otp_release),erlang:system_info(version)]),halt().')"
echo "erl_lint.erl:$(grep -n 'Starting from OTP 26, redefining built-in types' "$LINT" | cut -d: -f1) — the OTP-26 comment; the default-on switch is erl_lint.erl:$(grep -n '{redefined_builtin_type,true}' "$LINT" | cut -d: -f1)"
grep -n 'local redefinition of built-in type' "$LINT" | sed 's/^/   erl_lint.erl:/'

echo "== 1. -type map() :: integer().  (a user type named like a built-in)"
cat > t1.erl <<'X'
-module(t1).
-export([f/1]).
-type map() :: integer().
-spec f(map()) -> map().
f(X) -> X + 1.
X
out="$(erlc t1.erl 2>&1)"; rc=$?; printf '%s\n' "$out" | sed 's/^/   /'
expect "erlc succeeds (exit $rc)" "$rc"
printf '%s' "$out" | grep -q 'local redefinition of built-in type: map()'; expect "a WARNING (not an error) names the redefinition" $?
r="$(erl -noshell -pa . -eval 'io:format("~p",[t1:f(1)]),halt().')"; [ "$r" = 2 ]; expect "the module runs: t1:f(1) = $r" $?

echo "== 1-control. -type amount() :: integer().  (fresh name)"
sed 's/map()/amount()/g; s/t1/t1c/' t1.erl > t1c.erl
out="$(erlc t1c.erl 2>&1)"; rc=$?
[ "$rc" = 0 ] && [ -z "$out" ]; expect "erlc exits 0 with NO output (exit $rc)" $?

echo "== 1b. same as 1, with -compile({nowarn_redefined_builtin_type, [{map,0}]}) — the opt-out exists"
{ printf -- '-module(t1b).\n-compile({nowarn_redefined_builtin_type, [{map,0}]}).\n'; sed '1d; s/t1/t1b/' t1.erl; } > t1b.erl
out="$(erlc t1b.erl 2>&1)"; rc=$?
[ "$rc" = 0 ] && [ -z "$out" ]; expect "erlc exits 0 with NO output (exit $rc)" $?

echo "== 2. a user module named lists, ahead of stdlib on the code path (-pa)"
mkdir -p u; cat > u/lists.erl <<'X'
-module(lists).
-export([sum/1]).
sum(_) -> user_lists.
X
(cd u && erlc lists.erl >/dev/null 2>&1); expect "the user's lists.erl compiles" $?
out="$(erl -noshell -pa u -eval 'io:format("~p~n", [catch lists:sum([1,2])]), halt().' 2>&1)"; rc=$?
printf '%s\n' "$out" | cut -c1-200 | head -3 | sed 's/^/   /'
printf '%s' "$out" | grep -q 'Kernel pid terminated'; expect "the VM dies at boot: 'Kernel pid terminated' (exit $rc)" $?
echo "== 2b. code:load_file(lists) after boot (the sticky-directory guard)"
r="$(erl -noshell -eval 'io:format("~p",[code:load_file(lists)]),halt().' 2>&1)"; printf '%s\n' "$r" | head -2 | sed 's/^/   /'
printf '%s' "$r" | grep -q '{error,sticky_directory}'; expect "stdlib's lists is sticky" $?
echo "== 2-control. a user module named shop_lists loads and runs"
mkdir -p u2; printf -- '-module(shop_lists).\n-export([sum/1]).\nsum(_) -> user_lists.\n' > u2/shop_lists.erl; (cd u2 && erlc shop_lists.erl)
r="$(erl -noshell -pa u2 -eval 'io:format("~p ~p",[shop_lists:sum([1]), lists:sum([1,2])]), halt().' 2>&1)"; echo "   $r"
[ "$r" = "user_lists 3" ]; expect "user module runs and stdlib lists is intact" $?
echo "--- tally: $PASS as expected, $FAIL failed"
[ "$FAIL" = 0 ]
