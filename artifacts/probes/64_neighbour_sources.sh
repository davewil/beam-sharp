#!/usr/bin/env bash
# 64_neighbour_sources.sh
# CLAIM: Erlang's maps:find returns {ok,V}|error (tagged), maps:get/3 returns V|Default (bare + sentinel);
#   Elixir's Map.fetch is exactly :maps.find and Map.get/3 is a bare-with-default; Gleam's dict.get is
#   Result(v, Nil) lowered to maps:find with error -> {error,nil}; Elm's Dict.get is Maybe v (source only, not run:
#   package.elm-lang.org is unreachable here). Prints the real source lines.
# REFUTED if any grep below prints nothing (the line moved or the claim was wrong).
. "$(dirname "$0")/env.sh"
ERL=$(dirname "$(dirname "$(readlink -f "$(which erl)")")")/lib/erlang/lib
M=$(ls -d "$ERL"/stdlib-*/src/maps.erl | head -1)
echo "## Erlang $M"; grep -n -E '^-spec find\(|^-spec get\(Key, Map, Default\)|#\{Key := Value\} -> Value|#\{\} -> Default' "$M"
EX=$(dirname "$(dirname "$(readlink -f "$(which elixir)")")")/lib/elixir/lib/elixir/lib/map.ex
echo "## Elixir $EX"; grep -n -E '@spec fetch\(map, key\)|def fetch\(map, key\)|def fetch!\(map, key\)|def get\(map, key, default|%\{\^key => value\} ->' "$EX"
W=$(bs_scratch); trap 'rm -rf "$W"' EXIT
git clone -q --depth 1 --branch v0.62.0 https://github.com/gleam-lang/stdlib.git "$W/g" 2>&1 | tail -1
echo "## Gleam stdlib v0.62.0"; grep -n -E '^pub fn get\(from: Dict|^pub type Option' "$W/g/src/gleam/dict.gleam" "$W/g/src/gleam/option.gleam" | sed "s#$W/##"
grep -n -A3 '^map_get(Map, Key)' "$W/g/src/gleam_stdlib.erl"
git clone -q --depth 1 --branch 1.0.5 https://github.com/elm/core.git "$W/e" 2>&1 | tail -1
echo "## Elm core 1.0.5 (source only)"; grep -n -E '^get : |^type Maybe' "$W/e/src/Dict.elm" "$W/e/src/Maybe.elm" | sed "s#$W/##"
