#!/usr/bin/env bash
# PROBE 62d — what does a snake_case alias cost? PROTOTYPE DELTA: a scratch copy of the compiler (bs_emit.erl +~55 lines,
# $S/p62-compiler, never in the repo) that emits, per public function F, an alias snake(F) in one of four modes:
#   off (control = the real compiler) | deleg (alias calls F) | delegspec (+ -spec) | dup (full duplicate of the clauses+guards)
# Measures, over EVERY module under compiler/examples that compiles: beam bytes, Code-chunk bytes, ExpT chunk bytes, export count.
# Usage: source env.sh; ALIASBSC=<patched bsc> bash 62d_alias_cost.sh
set -uo pipefail
: "${ALIASBSC:?set ALIASBSC to the patched bsc (scratchpad/p62-compiler/_build/default/bin/bsc)}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
for m in off deleg delegspec dup; do
  mkdir -p "$W/$m"; ok=0; bad=0
  for d in "$REPO"/compiler/examples/*/; do
    n=$(basename "$d")
    if BS_ALIAS=$m "$ALIASBSC" --src-root "$REPO/compiler/examples" -o "$W/$m" "$d" >/dev/null 2>&1; then ok=$((ok+1)); else bad=$((bad+1)); fi
  done
  echo "mode=$m modules_ok=$ok modules_failed=$bad"
done
erl -noshell -eval '
Sz = fun(Dir) ->
  Fs = filelib:wildcard(Dir ++ "/*.beam"),
  lists:foldl(fun(F, {B, C, E, X, N, T}) ->
    {ok, Bin} = file:read_file(F),
    {ok, _, Ch} = beam_lib:all_chunks(F),
    CodeSz = byte_size(proplists:get_value("Code", Ch)),
    ExpSz = byte_size(proplists:get_value("ExpT", Ch)),
    TSz  = byte_size(proplists:get_value("AtU8", Ch, <<>>)),
    {ok, {_, [{exports, Ex}]}} = beam_lib:chunks(F, [exports]),
    {B + byte_size(Bin), C + CodeSz, E + ExpSz, X + length(Ex), N + 1, T + TSz}
  end, {0,0,0,0,0,0}, Fs) end,
io:format("~n~-10s ~7s ~8s ~8s ~8s ~8s ~7s~n", ["mode","beams","bytes","Code","ExpT","AtU8","exports"]),
[begin {B,C,E,X,N,T} = Sz("'"$W"'/" ++ M),
   io:format("~-10s ~7w ~8w ~8w ~8w ~8w ~7w~n", [M,N,B,C,E,T,X]) end || M <- ["off","deleg","delegspec","dup"]],
halt().'
