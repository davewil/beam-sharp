#!/usr/bin/env bash
# Probe 05 -- what the neighbours' lookups report when the stored value looks like "absent".
# Erlang (maps:get/3, maps:find/2), Elixir (Map.get/3, Map.fetch/2), Gleam (Result built into the prelude;
# dependency-free project, no hex needed). Elm: NOT RUN -- package.elm-lang.org is blocked, see the brief.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "# $(erl -noshell -eval 'io:format("OTP ~s",[erlang:system_info(otp_release)]),halt().')  $(elixir --version | tail -1)  $(/tmp/claude-0/gleamx/gleam --version)"

echo "=== Erlang: a value that IS the 'absent' atom, stored under k ==="
erl -noshell -eval '
M = #{k => nothing},
io:format("maps:get(k, M, nothing)   = ~p   (present, value nothing)~n", [maps:get(k, M, nothing)]),
io:format("maps:get(z, M, nothing)   = ~p   (absent)~n", [maps:get(z, M, nothing)]),
io:format("maps:find(k, M)           = ~p~n", [maps:find(k, M)]),
io:format("maps:find(z, M)           = ~p~n", [maps:find(z, M)]),
io:format("flat_size(nothing)=~p  flat_size({ok,nothing})=~p words~n", [erts_debug:flat_size(nothing), erts_debug:flat_size({ok,nothing})]),
halt().'

echo "=== Elixir: Map.get/2 vs Map.fetch/2 on %{k: nil} ==="
elixir -e '
m = %{k: nil}
IO.inspect(Map.get(m, :k),   label: "Map.get(m, :k)   present, value nil")
IO.inspect(Map.get(m, :z),   label: "Map.get(m, :z)   absent")
IO.inspect(Map.fetch(m, :k), label: "Map.fetch(m, :k)")
IO.inspect(Map.fetch(m, :z), label: "Map.fetch(m, :z)")
IO.inspect(Map.fetch(%{k: :error}, :k), label: "Map.fetch(%{k: :error}, :k)  (value is the failure atom)")
'

echo "=== Gleam: find returns Result(v, Nil); v itself a Result(Int, Nil) with value Error(Nil) ==="
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; cp -r "$HERE/gleam1" "$W/g"
( cd "$W/g" && /tmp/claude-0/gleamx/gleam build 2>&1 | tail -3
  erl -noshell -pa build/dev/erlang/gl1/ebin -eval 'io:format("gl1:main() = ~p~n",[gl1:main()]),halt().'
  echo "--- emitted Erlang for find/2:"; sed -n '/^find(/,/^describe/p' build/dev/erlang/gl1/_gleam_artefacts/gl1.erl | head -30 )
