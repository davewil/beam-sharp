#!/usr/bin/env bash
# Probe 06: finishes what 62a could not (hex.pm blocked => gleam_stdlib unavailable). No stdlib needed:
# a gleam project with an empty [dependencies] calls B# Shop:New/1 and Shop:Which/1 via @external, and RUNS them.
# Usage: 06_gleam_calls_bsharp.sh <scratch-dir> <dir-with-Shop.beam>
set -u
G=${1:?}; EBIN=${2:?}; rm -rf "$G"; mkdir -p "$G/src"
printf 'name = "caller"\nversion = "1.0.0"\n[dependencies]\n' > "$G/gleam.toml"
cat > "$G/src/caller.gleam" <<'T'
pub type Order

@external(erlang, "Shop", "New")
pub fn shop_new(id: Int) -> Order

@external(erlang, "Shop", "Which")
pub fn shop_which(o: Order) -> a

pub fn run() { shop_which(shop_new(3)) }
T
(cd "$G" && gleam build 2>&1 | tail -3)
erl -noshell -pa "$G/build/dev/erlang/caller/ebin" -pa "$EBIN" -eval 'io:format("caller:run() = ~p~n",[caller:run()]), io:format("caller:shop_new(3) = ~p~n",[caller:shop_new(3)]), halt().'
echo "=== NEGATIVE: external naming a non-existent B# function must fail at runtime (undef)"
sed -i 's/"New"/"Nwe"/' "$G/src/caller.gleam"
(cd "$G" && gleam build 2>&1 | tail -1)
erl -noshell -pa "$G/build/dev/erlang/caller/ebin" -pa "$EBIN" -eval 'try caller:shop_new(3) catch C:R -> io:format("~p:~p~n",[C,R]) end, halt().'
