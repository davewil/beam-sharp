#!/usr/bin/env bash
# PROBE 64f — Erlang and Elixir at their top type (term): which lookups tell absent from present-with-sentinel?
# Treatment: the DEFAULT-ARGUMENT lookup (Map.get/2, maps:get/3 with a default) — the bare encoding.
# Control:   the TAGGED lookup (Map.fetch/2, maps:find/2) — {ok, V} | error.
set -uo pipefail
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/p.exs" <<'EX'
m = %{a: nil, b: :error, c: false, d: 5}
IO.puts("Elixir #{System.version()} / OTP #{System.otp_release()}")
IO.puts("-- Map.get/2 (bare: absence is nil) --")
for k <- [:a, :zzz], do: IO.puts("  Map.get(m, #{inspect(k)}) = #{inspect(Map.get(m, k))}   (stored nil vs absent: #{if Map.has_key?(m, k), do: "present", else: "absent"})")
IO.puts("-- Map.get/3 default :error --")
for k <- [:b, :zzz], do: IO.puts("  Map.get(m, #{inspect(k)}, :error) = #{inspect(Map.get(m, k, :error))}")
IO.puts("-- Map.fetch/2 (tagged) --")
for k <- [:a, :b, :c, :zzz], do: IO.puts("  Map.fetch(m, #{inspect(k)}) = #{inspect(Map.fetch(m, k))}")
IO.puts("-- Keyword.get / Keyword.fetch --")
kw = [a: nil]
IO.puts("  Keyword.get(kw, :a) = #{inspect(Keyword.get(kw, :a))}; Keyword.get(kw, :zzz) = #{inspect(Keyword.get(kw, :zzz))}; Keyword.fetch(kw, :a) = #{inspect(Keyword.fetch(kw, :a))}; Keyword.fetch(kw, :zzz) = #{inspect(Keyword.fetch(kw, :zzz))}")
EX
elixir "$W/p.exs"
echo
cat > "$W/e.erl" <<'ER'
-module(e).
-export([main/0]).
main() ->
    M = #{a => nothing, b => error, c => undefined, d => 5},
    io:format("Erlang/OTP ~s~n", [erlang:system_info(otp_release)]),
    io:format("-- maps:get/3 with default `nothing` (bare) --~n"),
    [io:format("  maps:get(~p, M, nothing) = ~p~n", [K, maps:get(K, M, nothing)]) || K <- [a, d, zzz]],
    io:format("-- maps:find/2 (tagged: {ok, V} | error) --~n"),
    [io:format("  maps:find(~p, M) = ~p~n", [K, maps:find(K, M)]) || K <- [a, b, c, zzz]],
    io:format("-- the idiom when you MUST use a default: a fresh reference as the sentinel --~n"),
    Ref = make_ref(),
    [io:format("  ~p -> ~s~n", [K, case maps:get(K, M, Ref) of Ref -> "absent"; _ -> "present" end]) || K <- [a, b, zzz]],
    io:format("  but its type is still term(): ~p~n", [is_reference(Ref)]),
    halt().
ER
( cd "$W" && erlc e.erl && erl -noshell -s e main )
