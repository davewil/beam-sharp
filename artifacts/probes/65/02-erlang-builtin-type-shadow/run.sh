#!/usr/bin/env bash
# Probe 65/02: may an Erlang module define a type with a built-in type's name?
# Ticket 65 says OTP 26 permitted it. This runs on whatever `erlc` is on PATH.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")"
erl -noshell -eval 'io:format("OTP ~s, erts ~s~n",[erlang:system_info(otp_release), erlang:system_info(version)]), halt().'
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
for f in shadow_integer shadow_map shadow_noauto shadow_noauto_arity shadow_bif shadow_bif_optout; do
  echo "=== $f.erl"; sed 's/^/    | /' "$f.erl"
  erlc -o "$T" +debug_info "$f.erl" 2>&1 | sed 's/^/    > /'
  echo "    erlc exit=${PIPESTATUS[0]}"
done
echo "=== run the opt-out one: whose length/1 does f/1 reach?"
erl -noshell -pa "$T" -eval 'io:format("shadow_bif_optout:f([a,b]) = ~p~n",[shadow_bif_optout:f([a,b])]), halt().'
echo
echo "=== where OTP's linter decides (installed source)"
F=$(ls /usr/lib/erlang/lib/stdlib-*/src/erl_lint.erl)
grep -n 'is_newly_introduced_builtin_type\|builtin_type, TypePair\|no_auto_import_types' "$F"
echo "=== the type list a user cannot redefine includes (erl_internal:is_type/2), e.g.:"
erl -noshell -eval '[io:format("~w/~w ~w~n",[N,A,erl_internal:is_type(N,A)]) || {N,A} <- [{integer,0},{map,0},{dynamic,0},{nonempty_binary,0},{integer,1},{option,1}]], halt().'
