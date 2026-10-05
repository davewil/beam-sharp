#!/usr/bin/env bash
# P13: what name does a foreign caller's CRASH REPORT show when it goes through the alias? (thin = tail call; dup = own body)
# CLAIM: thin alias frames vanish (call_only), so the error names the Pascal function; dup names the alias.
# REFUTED IF the thin stack trace contains `score_at1_value` as a frame.
. "$(dirname "$0")/lib.sh"; build_alias_compiler || exit 1
W="$SCRATCH/p13"; rm -rf "$W"; mkdir -p "$W/src"; "$HERE/gen_sz.sh" 3 "$W/src"
for mode in thin dup; do mkdir -p "$W/o_$mode"; BS_ALIAS=$mode "$BSC_ALIAS" --src-root "$W/src" -o "$W/o_$mode" "$W/src/Sz3" >/dev/null 2>&1
  echo "== $mode: Sz3:score_at1_value(<<\"x\">>)  (a non-integer: the boundary guard refuses it)"
  erl -noshell -pa "$W/o_$mode" -eval 'try (list_to_atom("Sz3")):score_at1_value(<<"x">>) catch C:R:St -> io:format("  ~p:~p~n  ~p~n", [C, R, [{M,F,A} || {M,F,A,_} <- St]]) end, halt().'
  echo "   same call from Elixir, as the user reads it:"
  elixir -pa "$W/o_$mode" -e 'try do :Sz3.score_at1_value("x") rescue e -> IO.puts("  " <> Exception.message(e) |> String.split("\n") |> Enum.take(4) |> Enum.join("\n  ")) end' 2>&1 | head -6
done
