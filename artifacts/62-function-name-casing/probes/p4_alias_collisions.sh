#!/usr/bin/env bash
# Probe 4: what does erlc (OTP 25) do with the collisions a snake_case alias scheme creates?
# Run: bash p4_alias_collisions.sh     Exit 1 if any observed outcome contradicts the
# per-case expectation recorded as an *assertion on erlc's own output* (grep), and
# the control case (no collision) must compile clean.
set -u
D=$(mktemp -d); trap 'rm -rf "$D"' EXIT
fail=0
try() { # name, expect(ok|error), pattern-if-error, file-content
  local n=$1 exp=$2 pat=$3; cat > "$D/$n.erl"
  local out; out=$(cd "$D" && erlc -o "$D" "$n.erl" 2>&1); local rc=$?
  echo "--- $n (erlc rc=$rc)"; echo "$out" | sed 's/^/    /'
  if [ "$exp" = ok ]; then [ $rc -eq 0 ] || { echo "ASSERT FAIL: expected clean compile"; fail=1; }
  else [ $rc -ne 0 ] && echo "$out" | grep -q "$pat" || { echo "ASSERT FAIL: expected error matching /$pat/"; fail=1; }; fi
}
try control ok - <<'X'
-module(control).
-export(['GetId'/1, get_id/1]).
'GetId'(X) -> X.
get_id(X) -> 'GetId'(X).
X
try acronym_collision error "already defined" <<'X'
%% B# GetID and GetId both derive get_id under the acronym-aware rule
-module(acronym_collision).
-export(['GetID'/1, 'GetId'/1, get_id/1, get_id/1]).
'GetID'(X) -> X.  'GetId'(X) -> X.
get_id(X) -> 'GetID'(X).
get_id(X) -> 'GetId'(X).
X
try module_info_collision error "module_info" <<'X'
%% B# `ModuleInfo/0` -> alias module_info/0 clashes with the compiler-generated one
-module(module_info_collision).
-export(['ModuleInfo'/0, module_info/0]).
'ModuleInfo'() -> ok.
module_info() -> 'ModuleInfo'().
X
try callback_double_define error "already defined" <<'X'
%% gen_server module: bsc already lowers 'Init' to init/1 (bs_otp:callback_name).
%% An alias pass that ALSO emits init/1 for source name `Init` defines it twice.
-module(callback_double_define).
-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2]).
init(S) -> {ok, S}.
handle_call(_, _, S) -> {reply, ok, S}.
handle_cast(_, S) -> {noreply, S}.
init(S) -> {ok, S}.
X
try callback_ok ok - <<'X'
%% the same module when the alias pass SKIPS atoms already defined: clean.
-module(callback_ok).
-behaviour(gen_server).
-export([init/1, handle_call/3, handle_cast/2]).
init(S) -> {ok, S}.
handle_call(_, _, S) -> {reply, ok, S}.
handle_cast(_, S) -> {noreply, S}.
X
try arity_distinct ok - <<'X'
%% same snake name, different arities (08 default-arg ladder) is NOT a collision
-module(arity_distinct).
-export(['Get'/1, 'Get'/2, get/1, get/2]).
'Get'(A) -> 'Get'(A, 0).  'Get'(A, B) -> {A, B}.
get(A) -> 'Get'(A).  get(A, B) -> 'Get'(A, B).
X
try export_missing error "undefined" <<'X'
%% an alias exported but never defined (the bug the "one funnel" comment in bs_emit guards)
-module(export_missing).
-export(['New'/1, new/1]).
'New'(X) -> X.
X
[ $fail -eq 0 ] && echo "ALL ASSERTIONS HELD" || echo "SOME ASSERTION FAILED"
exit $fail
